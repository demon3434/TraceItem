import mimetypes
from pathlib import Path
from typing import Optional
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.deps import get_current_user, get_current_user_media, get_db
from app.models.user import User
from app.schemas.attachment import AttachmentCreate, CleanupTempMediaRequest
from app.schemas.common import ApiResponse
from app.services.media_service import (
    cleanup_unreferenced_temp_media,
    process_and_save_image,
    save_audio_attachment,
    save_video_attachment,
)

router = APIRouter(prefix="/media", tags=["多媒体附件流水线"])


@router.post("/upload/image", response_model=ApiResponse[AttachmentCreate])
def upload_image(
    file: UploadFile = File(..., description="JPEG/PNG 现场拍摄照片"),
    current_user: User = Depends(get_current_user),
):
    """
    上传现场照片：
    - 服务端等比限制长边 1600px，JPEG 质量 82% 归一化转码
    - 自动生成 300px 极速小缩略图并按年月工业化分片存储
    """
    rel_path, thumb_rel, size, w, h = process_and_save_image(file)
    att = AttachmentCreate(
        media_type="image",
        file_path=rel_path,
        thumbnail_path=thumb_rel,
        file_size=size,
        duration_seconds=0,
        width=w,
        height=h,
        display_order=1,
    )
    return ApiResponse(data=att, message="照片处理并上传成功")


@router.post("/upload/audio", response_model=ApiResponse[AttachmentCreate])
def upload_audio(
    file: UploadFile = File(..., description="AAC/M4A 语音指引备忘"),
    duration_seconds: int = 0,
    current_user: User = Depends(get_current_user),
):
    """上传语音指引备忘录 (AAC/M4A 单声道，限长 120 秒)"""
    if duration_seconds > settings.AUDIO_MAX_DURATION_SECONDS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"语音时长超过最大限制 ({settings.AUDIO_MAX_DURATION_SECONDS}秒)",
        )
    rel_path, size = save_audio_attachment(file)
    att = AttachmentCreate(
        media_type="audio",
        file_path=rel_path,
        thumbnail_path=None,
        file_size=size,
        duration_seconds=duration_seconds,
        width=0,
        height=0,
        display_order=2,
    )
    return ApiResponse(data=att, message="语音备忘录上传成功")


@router.post("/upload/video", response_model=ApiResponse[AttachmentCreate])
def upload_video(
    video: UploadFile = File(..., description="x265/MP4 空间短视频"),
    poster: Optional[UploadFile] = File(None, description="可选首帧封面图"),
    duration_seconds: int = 0,
    width: int = 0,
    height: int = 0,
    current_user: User = Depends(get_current_user),
):
    """上传空间寻路短视频 (x265 编码，FastStart MOOV 前置，限长 60 秒)"""
    if duration_seconds > settings.VIDEO_MAX_DURATION_SECONDS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"短视频时长超过最大限制 ({settings.VIDEO_MAX_DURATION_SECONDS}秒)",
        )
    rel_path, thumb_rel, size = save_video_attachment(video, poster)
    att = AttachmentCreate(
        media_type="video",
        file_path=rel_path,
        thumbnail_path=thumb_rel,
        file_size=size,
        duration_seconds=duration_seconds,
        width=width,
        height=height,
        display_order=3,
    )
    return ApiResponse(data=att, message="空间短视频上传成功")


@router.get("/file/{file_path:path}")
def serve_media_file(
    file_path: str,
    current_user: User = Depends(get_current_user_media),
):
    """
    安全流式分发媒体文件与缩略图 (支持 JWT 鉴权、HTTP Range 视频拖拽 Seek 与 HTTP 强缓存)
    """
    safe_base = settings.MEDIA_DIR.resolve()
    target = (settings.MEDIA_DIR / file_path).resolve()

    # 路径安全沙箱防穿越校验
    if not str(target).startswith(str(safe_base)):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="非法越界访问请求"
        )

    if not target.exists() or not target.is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="媒体文件不存在"
        )

    mime_type, _ = mimetypes.guess_type(target.name)
    if not mime_type:
        mime_type = "application/octet-stream"

    stat_res = target.stat()
    etag = f'"{stat_res.st_mtime_ns}-{stat_res.st_size}"'
    headers = {
        "Cache-Control": "public, max-age=31536000, immutable",
        "ETag": etag,
    }

    return FileResponse(
        path=target,
        media_type=mime_type,
        filename=target.name,
        headers=headers,
    )


@router.post("/cleanup-temp", response_model=ApiResponse[dict])
def cleanup_temp_media(
    payload: CleanupTempMediaRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """安全回收客户端编辑会话放弃或替换的未入库临时附件（严格沙箱 + DB 零引用校验）"""
    pairs = [(item.file_path, item.thumbnail_path) for item in payload.items]
    cleaned = cleanup_unreferenced_temp_media(db, pairs)
    return ApiResponse(
        data={"cleaned_count": cleaned},
        message=f"已清理 {cleaned} 份临时附件",
    )

