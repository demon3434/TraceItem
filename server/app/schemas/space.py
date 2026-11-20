from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class HouseCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=80)
    icon: str = Field("🏠", max_length=20)  # Emoji 图标
    sort_order: int = Field(0)


class HouseUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=80)
    icon: Optional[str] = Field(None, max_length=20)
    sort_order: Optional[int] = None
    is_active: Optional[bool] = None


class HouseOut(BaseModel):
    id: int
    user_id: int
    name: str
    icon: str
    sort_order: int
    is_active: bool = True
    created_at: datetime

    class Config:
        from_attributes = True


class RoomCreate(BaseModel):
    house_id: int
    name: str = Field(..., min_length=1, max_length=80)
    icon: str = Field("🛋️", max_length=20)  # Emoji 图标
    sort_order: int = Field(0)


class RoomUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=80)
    icon: Optional[str] = Field(None, max_length=20)
    sort_order: Optional[int] = None
    is_active: Optional[bool] = None


class RoomOut(BaseModel):
    id: int
    user_id: int
    house_id: int
    name: str
    icon: str
    sort_order: int
    is_active: bool = True
    created_at: datetime

    class Config:
        from_attributes = True


class HouseReorderPayload(BaseModel):
    ordered_ids: List[int] = Field(..., min_length=1, description="按期望顺序排列的房屋 ID 列表")


class RoomReorderPayload(BaseModel):
    house_id: int = Field(..., description="所属房屋 ID")
    ordered_ids: List[int] = Field(..., min_length=1, description="按期望顺序排列的房间 ID 列表")

