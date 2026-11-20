from typing import Generic, Optional, TypeVar
from pydantic import BaseModel, Field

T = TypeVar("T")


class ApiResponse(BaseModel, Generic[T]):
    """统一 API Envelope 响应结构"""
    code: int = Field(0, description="状态码：0 为成功，其余为 HTTP/业务错误码")
    message: str = Field("ok", description="提示或错误消息")
    data: Optional[T] = Field(None, description="业务数据载荷")


class PaginationMeta(BaseModel):
    page: int = 1
    page_size: int = 20
    total: int = 0
    total_pages: int = 0


class PaginatedData(BaseModel, Generic[T]):
    items: list[T]
    pagination: PaginationMeta

