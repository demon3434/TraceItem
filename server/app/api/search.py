from typing import List
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.item import ItemOut
from app.services.search_service import search_items_fts

router = APIRouter(prefix="/search", tags=["全文检索与寻物"])


@router.get("", response_model=ApiResponse[List[ItemOut]])
def search_items(
    q: str = Query(..., min_length=1, description="检索关键词 (名称/品牌/存放细节/备忘)"),
    limit: int = Query(50, ge=1, le=100, description="最大返回条目数"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    普通用户私有全文检索 (基于 SQLite FTS5 + BM25 权重排序)
    严格隔离数据，仅检索当前登录用户自身录入的物品
    """
    items = search_items_fts(
        db=db,
        query_text=q,
        user_id=current_user.id,
        limit=limit,
    )
    return ApiResponse(data=[ItemOut.model_validate(it) for it in items])

