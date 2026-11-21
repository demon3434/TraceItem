from datetime import datetime
from typing import Literal, Optional
from pydantic import BaseModel, Field, model_validator
from app.schemas.attachment import AttachmentCreate, AttachmentOut
from app.schemas.space import HouseOut, RoomOut


class CategoryCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=80)
    icon: str = Field("📦", max_length=20)
    sort_order: int = Field(0)
    is_active: bool = Field(True)


class CategoryUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=80)
    icon: Optional[str] = Field(None, max_length=20)
    sort_order: Optional[int] = None
    is_active: Optional[bool] = None


class CategoryOut(BaseModel):
    id: int
    name: str
    icon: str
    sort_order: int
    is_active: bool = True

    class Config:
        from_attributes = True


class TagCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=80)


class TagOut(BaseModel):
    id: int
    name: str

    class Config:
        from_attributes = True


class ItemCreate(BaseModel):
    house_id: int
    room_id: int
    category_id: Optional[int] = None
    name: str = Field(..., min_length=1, max_length=120)
    brand: Optional[str] = Field("", max_length=120)
    quantity: int = Field(1, ge=0)
    location_detail: Optional[str] = Field("", description="可选柜子/抽屉细节备注")
    description: Optional[str] = Field("", description="备忘说明")
    tag_names: Optional[list[str]] = Field(default_factory=list)
    attachments: Optional[list[AttachmentCreate]] = Field(default_factory=list)
    client_uuid: Optional[str] = Field(None, max_length=64, description="离线幂等键")


class ItemUpdate(BaseModel):
    house_id: Optional[int] = None
    room_id: Optional[int] = None
    category_id: Optional[int] = None
    name: Optional[str] = Field(None, min_length=1, max_length=120)
    brand: Optional[str] = None
    quantity: Optional[int] = Field(None, ge=0)
    location_detail: Optional[str] = None
    description: Optional[str] = None
    tag_names: Optional[list[str]] = None
    attachments: Optional[list[AttachmentCreate]] = None
    expected_version: Optional[int] = Field(None, ge=1, description="乐观锁期望版本号")
    changed_fields: Optional[dict] = Field(None, description="离线增量修改的标量字段")
    added_attachments: Optional[list[AttachmentCreate]] = Field(None, description="离线增量新增附件")
    removed_attachment_paths: Optional[list[str]] = Field(None, description="离线增量移除的附件 file_path")
    client_op_uuid: Optional[str] = Field(None, max_length=64, description="离线变更操作幂等键")
    force_overwrite: bool = Field(False, description="冲突仲裁时强制以本机修改覆盖")


class ItemOut(BaseModel):
    id: int
    user_id: int
    house_id: int
    room_id: int
    category_id: Optional[int] = None
    name: str
    brand: str
    quantity: int
    location_detail: str
    description: str
    status: Literal["stored", "in_use"] = "stored"
    storage_house_id: Optional[int] = None
    storage_room_id: Optional[int] = None
    storage_location_detail: str = ""
    status_updated_at: Optional[datetime] = None
    client_uuid: Optional[str] = None
    version: int = 1
    created_at: datetime
    updated_at: datetime

    # 展开字段
    house: Optional[HouseOut] = None
    room: Optional[RoomOut] = None
    category: Optional[CategoryOut] = None
    tags: list[TagOut] = []
    attachments: list[AttachmentOut] = []
    storage_attachments: list[AttachmentOut] = []

    # 空间路径辅助展示
    path_display: Optional[str] = None  # 如 "阳光城 > 客厅"
    storage_path_display: Optional[str] = None

    @model_validator(mode="after")
    def _partition_attachments_by_status(self) -> "ItemOut":
        if self.storage_attachments:
            return self
        all_atts = list(self.attachments)
        storage_atts = [a for a in all_atts if (a.scene or "storage") == "storage"]
        self.storage_attachments = storage_atts
        if self.status == "in_use":
            self.attachments = [a for a in all_atts if a.scene == "in_use"]
        else:
            self.attachments = storage_atts
        return self

    class Config:
        from_attributes = True


class ItemTakeOutPayload(BaseModel):
    house_id: int
    room_id: int
    location_detail: str = ""
    attachments: list[AttachmentCreate] = Field(..., min_length=1)
    expected_version: Optional[int] = Field(None, ge=1)
    client_op_uuid: Optional[str] = Field(None, max_length=64)


class ItemPutBackPayload(BaseModel):
    restore_original: bool = True
    house_id: Optional[int] = None
    room_id: Optional[int] = None
    location_detail: Optional[str] = None
    added_storage_attachments: Optional[list[AttachmentCreate]] = None
    removed_attachment_paths: Optional[list[str]] = None
    expected_version: Optional[int] = Field(None, ge=1)
    client_op_uuid: Optional[str] = Field(None, max_length=64)


class GodViewItemOut(ItemOut):
    """Admin 上帝视角专享扩展字段"""
    owner_username: str = ""
    owner_nickname: str = ""

