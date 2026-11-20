from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class CategoryTemplateBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=80, description="分类名称")
    icon: str = Field("📦", max_length=20, description="分类图标 Emoji")
    color: str = Field("#F97316", max_length=30, description="主题色")
    sort_order: int = Field(0, description="排序优先级")


class CategoryTemplateCreate(CategoryTemplateBase):
    pass


class CategoryTemplateUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=80)
    icon: Optional[str] = Field(None, max_length=20)
    color: Optional[str] = Field(None, max_length=30)
    sort_order: Optional[int] = None
    is_active: Optional[bool] = None


class CategoryTemplateStatusUpdate(BaseModel):
    is_active: bool


class CategoryReorderPayload(BaseModel):
    ordered_ids: List[int] = Field(..., min_length=1, description="按期望顺序排列的 ID 列表")


class CategoryTemplateOut(CategoryTemplateBase):
    id: int
    is_active: bool
    is_deleted: bool
    created_at: datetime

    class Config:
        from_attributes = True

