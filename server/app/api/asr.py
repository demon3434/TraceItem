from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse

from app.core.deps import get_current_user
from app.models.user import User
from app.schemas.common import ApiResponse
from app.services.asr_model_catalog import list_asr_models, resolve_model_archive

router = APIRouter(prefix="/asr", tags=["端侧语音模型托管"])


def _iter_file_chunks(path, chunk_size: int = 256 * 1024):
    with path.open("rb") as f:
        while chunk := f.read(chunk_size):
            yield chunk


@router.get("/models", response_model=ApiResponse[list[dict]])
def get_asr_models(current_user: User = Depends(get_current_user)):
    """获取家庭服务器托管的端侧 ASR 模型清单（零推理开销）"""
    return ApiResponse(data=list_asr_models())


@router.get("/models/{model_id}/download")
def download_asr_model(
    model_id: str,
    current_user: User = Depends(get_current_user),
):
    """流式下载指定端侧 ASR 模型归档包"""
    resolved = resolve_model_archive(model_id)
    if resolved is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"未知模型标识: {model_id}",
        )

    spec, archive_path = resolved
    if not archive_path.is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"服务端尚未放置模型文件 ({archive_path.name})，请联系管理员上传至 data/models/asr/",
        )

    file_size = archive_path.stat().st_size
    headers = {
        "Content-Length": str(file_size),
        "Content-Disposition": f'attachment; filename="{archive_path.name}"',
        "X-Asr-Model-Id": spec.id,
    }
    return StreamingResponse(
        _iter_file_chunks(archive_path),
        media_type="application/octet-stream",
        headers=headers,
    )

