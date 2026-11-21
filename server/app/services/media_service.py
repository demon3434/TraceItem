import io
import os
import uuid
from datetime import datetime
from pathlib import Path
from typing import List, Optional, Tuple
from fastapi import HTTPException, UploadFile, status
from PIL import Image, ImageOps
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.attachment import Attachment
from app.services.mp4_faststart import ensure_moov_first


def generate_industrial_path(media_type: str, ext: str) -> Tuple[str, Path]:
    """
    生成符合现代工业化标准的相对存储路径与绝对物理路径
    格式：{type}/{YYYY}/{MM}/{uuid}.{ext}
    """
    now = datetime.now()
    year_str = now.strftime("%Y")
    month_str = now.strftime("%m")
    unique_id = uuid.uuid4().hex[:16]
    file_name = f"{media_type[:3]}_{unique_id}{ext}"

    rel_path = f"{media_type}s/{year_str}/{month_str}/{file_name}"
    abs_path = settings.MEDIA_DIR / rel_path
    abs_path.parent.mkdir(parents=True, exist_ok=True)
    return rel_path, abs_path


def process_and_save_image(file: UploadFile) -> Tuple[str, Optional[str], int, int, int]:
    """
    保存并规范化 JPEG 物品照片：
    - 等比缩放 (长边限制 1600px)
    - 统一转码为 JPEG 质量 82%
    - 生成 300px 极速小缩略图
    返回：(rel_path, thumb_rel_path, file_size, width, height)
    """
    contents = file.file.read()
    try:
        img = Image.open(io.BytesIO(contents))
        # 修正移动端 EXIF 拍摄角度
        img = ImageOps.exif_transpose(img)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="无效的图片文件，请重新上传",
        )

    # 统一转换为 RGB
    if img.mode != "RGB":
        img = img.convert("RGB")

    orig_w, orig_h = img.size
    long_edge = max(orig_w, orig_h)

    # 1. 主图等比压缩
    if long_edge > settings.IMAGE_MAX_LONG_EDGE:
        ratio = settings.IMAGE_MAX_LONG_EDGE / long_edge
        new_w = max(1, int(orig_w * ratio))
        new_h = max(1, int(orig_h * ratio))
        img_resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    else:
        new_w, new_h = orig_w, orig_h
        img_resized = img

    rel_path, abs_path = generate_industrial_path("image", ".jpg")
    img_resized.save(
        abs_path,
        format="JPEG",
        quality=settings.IMAGE_JPEG_QUALITY,
        optimize=True,
    )
    file_size = os.path.getsize(abs_path)

    # 2. 生成高清小缩略图 (长边 600px，LANCZOS 锐利重采样，体积约 25~45KB)
    target_thumb_edge = min(600, max(new_w, new_h))
    thumb_ratio = target_thumb_edge / max(new_w, new_h)
    thumb_w = max(1, int(new_w * thumb_ratio))
    thumb_h = max(1, int(new_h * thumb_ratio))
    img_thumb = img_resized.resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)

    thumb_rel_path = rel_path.replace("images/", "thumbnails/images/").replace(".jpg", "_thumb.jpg")
    thumb_abs_path = settings.MEDIA_DIR / thumb_rel_path
    thumb_abs_path.parent.mkdir(parents=True, exist_ok=True)
    img_thumb.save(thumb_abs_path, format="JPEG", quality=82, optimize=True)

    return rel_path, thumb_rel_path, file_size, new_w, new_h


def save_audio_attachment(file: UploadFile) -> Tuple[str, int]:
    """保存 AAC / M4A 语音备忘录"""
    ext = Path(file.filename or "audio.m4a").suffix.lower()
    if ext not in [".m4a", ".aac", ".mp3", ".ogg"]:
        ext = ".m4a"

    rel_path, abs_path = generate_industrial_path("audio", ext)
    contents = file.file.read()
    with open(abs_path, "wb") as f:
        f.write(contents)
    file_size = len(contents)
    return rel_path, file_size


def save_video_attachment(
    video_file: UploadFile,
    poster_file: Optional[UploadFile] = None,
) -> Tuple[str, Optional[str], int]:
    """保存 x265 / MP4 空间短视频与首帧海报"""
    ext = Path(video_file.filename or "video.mp4").suffix.lower()
    if ext not in [".mp4", ".mov", ".mkv"]:
        ext = ".mp4"

    rel_path, abs_path = generate_industrial_path("video", ext)
    video_contents = video_file.file.read()
    with open(abs_path, "wb") as f:
        f.write(video_contents)
    if ext in [".mp4", ".mov"]:
        try:
            ensure_moov_first(abs_path)
        except Exception:
            pass
    file_size = abs_path.stat().st_size

    thumb_rel_path = None
    if poster_file:
        try:
            poster_contents = poster_file.file.read()
            p_img = Image.open(io.BytesIO(poster_contents))
            p_img = ImageOps.exif_transpose(p_img)
            if p_img.mode != "RGB":
                p_img = p_img.convert("RGB")

            thumb_rel_path = rel_path.replace("videos/", "thumbnails/videos/").replace(ext, "_poster.jpg")
            thumb_abs_path = settings.MEDIA_DIR / thumb_rel_path
            thumb_abs_path.parent.mkdir(parents=True, exist_ok=True)
            p_img.save(thumb_abs_path, format="JPEG", quality=80, optimize=True)
        except Exception:
            pass

    return rel_path, thumb_rel_path, file_size


def delete_physical_attachment(rel_path: str, thumb_rel_path: Optional[str] = None) -> None:
    """物理级联硬删除多媒体附件与缩略图 (ADR 0003)"""
    try:
        abs_path = settings.MEDIA_DIR / rel_path
        if abs_path.exists():
            abs_path.unlink()
    except Exception:
        pass

    if thumb_rel_path:
        try:
            thumb_abs_path = settings.MEDIA_DIR / thumb_rel_path
            if thumb_abs_path.exists():
                thumb_abs_path.unlink()
        except Exception:
            pass


_ALLOWED_MEDIA_ROOTS = ("images/", "audios/", "videos/", "thumbnails/")


def _normalize_and_validate_media_rel_path(raw_path: Optional[str]) -> Optional[str]:
    """规范化相对媒体路径并校验其严格位于允许的 MEDIA_DIR 子目录沙箱内"""
    if not raw_path:
        return None
    norm = raw_path.replace("\\", "/").strip()
    for prefix in ("/api/media/file/", "api/media/file/"):
        if norm.startswith(prefix):
            norm = norm[len(prefix):]
            break
    norm = norm.lstrip("/")
    if not norm or not norm.startswith(_ALLOWED_MEDIA_ROOTS):
        return None
    try:
        sub_root = (settings.MEDIA_DIR / norm.split("/", 1)[0]).resolve()
        target = (settings.MEDIA_DIR / norm).resolve()
        target.relative_to(sub_root)
    except Exception:
        return None
    return norm


def _is_media_path_referenced(db: Session, norm_path: str) -> bool:
    """校验路径是否仍被 Attachment 表引用"""
    return (
        db.query(Attachment.id)
        .filter((Attachment.file_path == norm_path) | (Attachment.thumbnail_path == norm_path))
        .first()
        is not None
    )


def cleanup_unreferenced_temp_media(
    db: Session,
    items: List[Tuple[str, Optional[str]]],
) -> int:
    """安全清理未入库的临时附件与缩略图（沙箱 + DB 零引用双重校验）"""
    cleaned_count = 0
    for raw_file, raw_thumb in items:
        norm_file = _normalize_and_validate_media_rel_path(raw_file)
        if not norm_file or _is_media_path_referenced(db, norm_file):
            continue

        norm_thumb = _normalize_and_validate_media_rel_path(raw_thumb)
        if norm_thumb and _is_media_path_referenced(db, norm_thumb):
            norm_thumb = None

        abs_file = (settings.MEDIA_DIR / norm_file).resolve()
        existed = abs_file.exists() and abs_file.is_file()
        delete_physical_attachment(norm_file, norm_thumb)
        if existed and not abs_file.exists():
            cleaned_count += 1
    return cleaned_count

