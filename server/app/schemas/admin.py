from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class AdminUserOut(BaseModel):
    id: int
    username: str
    nickname: str
    role: str
    is_active: bool
    created_at: datetime
    house_count: int = 0
    room_count: int = 0
    item_count: int = 0

    class Config:
        from_attributes = True


class AdminUserCreate(BaseModel):
    username: str = Field(..., min_length=2, max_length=50)
    password: Optional[str] = Field(default="", max_length=100)
    nickname: Optional[str] = Field("", max_length=50)


class AdminUserStatusUpdate(BaseModel):
    is_active: bool


class AdminUserPasswordReset(BaseModel):
    new_password: str = Field(..., min_length=6, max_length=100)


class AdminPasswordChange(BaseModel):
    old_password: str = Field(..., min_length=1)
    new_password: str = Field(..., min_length=6, max_length=100)


class AdminSystemStats(BaseModel):
    total_users: int
    total_items: int
    total_houses: int
    total_rooms: int
    media_storage_bytes: int
    media_storage_display: str
    last_backup_time: Optional[datetime] = None
    total_backups: int


# ==========================================
# 多维托底寻物级联选项与过滤
# ==========================================

class GodViewCascadingRoom(BaseModel):
    id: int
    name: str
    icon: Optional[str] = None


class GodViewCascadingHouse(BaseModel):
    id: int
    name: str
    icon: Optional[str] = None
    rooms: List[GodViewCascadingRoom] = []


class GodViewCascadingUser(BaseModel):
    id: int
    username: str
    nickname: str
    houses: List[GodViewCascadingHouse] = []


class GodViewFilterCategory(BaseModel):
    id: int
    name: str
    icon: Optional[str] = None


class GodViewFilterOptions(BaseModel):
    users: List[GodViewCascadingUser] = []
    categories: List[GodViewFilterCategory] = []
    tags: List[str] = []


# ==========================================
# 孤儿多媒体与导入恢复
# ==========================================

class OrphanMediaStats(BaseModel):
    orphan_count: int
    orphan_size_bytes: int
    orphan_size_display: str
    orphan_files: List[str] = []


class SoftDeletedMediaStats(BaseModel):
    deleted_item_count: int
    attachment_count: int
    total_size_bytes: int
    total_size_display: str


class ImportedBackupRecord(BaseModel):
    filename: str
    file_size: int
    file_size_display: str
    is_valid: bool
    backup_at: Optional[str] = None
    item_count: Optional[int] = None
    attachment_count: Optional[int] = None
    error_message: Optional[str] = None


class ImportRestoreRequest(BaseModel):
    filename: str


