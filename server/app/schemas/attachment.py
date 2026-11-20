from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel


class AttachmentCreate(BaseModel):
    media_type: str  # 'image' | 'audio' | 'video'
    file_path: str
    thumbnail_path: Optional[str] = None
    file_size: int = 0
    duration_seconds: int = 0
    width: int = 0
    height: int = 0
    display_order: int = 1


class AttachmentOut(BaseModel):
    id: int
    item_id: int
    media_type: str
    file_path: str
    url: str = ""  # 映射为完整访问 URL
    thumbnail_path: Optional[str] = None
    thumbnail_url: Optional[str] = None
    file_size: int = 0
    duration_seconds: int = 0
    width: int = 0
    height: int = 0
    display_order: int = 1
    created_at: datetime

    class Config:
        from_attributes = True


class TempMediaItem(BaseModel):
    file_path: str
    thumbnail_path: Optional[str] = None


class CleanupTempMediaRequest(BaseModel):
    items: List[TempMediaItem] = []

