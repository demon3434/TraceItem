import math
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_db
from app.models.item import Category, Item, Tag
from app.models.user import User
from app.schemas.common import ApiResponse, PaginatedData, PaginationMeta
from app.schemas.category_template import CategoryReorderPayload
from app.schemas.item import (
    CategoryCreate,
    CategoryOut,
    CategoryUpdate,
    ItemCreate,
    ItemOut,
    ItemPutBackPayload,
    ItemTakeOutPayload,
    ItemUpdate,
    TagOut,
)
from app.services.item_lifecycle_service import put_back_item, take_out_item
from app.services.category_service import (
    create_user_category,
    delete_user_category,
    get_user_categories,
    get_user_categories_paginated,
    reorder_user_categories,
    update_user_category,
)
from app.services.fts_indexer import rebuild_all_items_fts, sync_item_fts
from app.services.item_service import (
    create_user_item,
    delete_user_item,
    get_user_item_by_id,
    get_user_items,
    suggest_tags,
    update_user_item,
)

router = APIRouter(prefix="/items", tags=["物品管理与录入"])


@router.get("", response_model=ApiResponse[PaginatedData[ItemOut]])
def list_items(
    house_id: Optional[int] = Query(None, description="按房屋筛选"),
    room_id: Optional[int] = Query(None, description="按房间筛选"),
    category_id: Optional[int] = Query(None, description="按分类筛选"),
    item_status: Optional[str] = Query(None, alias="status", description="按状态筛选: stored | in_use"),
    page: int = Query(1, ge=1, description="当前页码"),
    page_size: int = Query(30, ge=1, le=500, description="每页数量"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """分页拉取当前登录用户的私有物品列表"""
    skip = (page - 1) * page_size
    items, total = get_user_items(
        db=db,
        user_id=current_user.id,
        house_id=house_id,
        room_id=room_id,
        category_id=category_id,
        item_status=item_status,
        skip=skip,
        limit=page_size,
    )
    total_pages = math.ceil(total / page_size) if total > 0 else 0
    data = PaginatedData(
        items=[ItemOut.model_validate(it) for it in items],
        pagination=PaginationMeta(
            page=page,
            page_size=page_size,
            total=total,
            total_pages=total_pages,
        ),
    )
    return ApiResponse(data=data)


@router.get("/categories", response_model=ApiResponse[List[CategoryOut]])
def list_categories(
    include_inactive: bool = Query(False, description="是否包含已停用的分类"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """获取用户的分类列表 (可过滤已停用分类)"""
    cats = get_user_categories(db, current_user.id, include_inactive=include_inactive)
    return ApiResponse(data=[CategoryOut.model_validate(c) for c in cats])


@router.get("/categories/paginated", response_model=ApiResponse[PaginatedData[CategoryOut]])
def list_categories_paginated(
    page: int = Query(1, ge=1, description="当前页码"),
    page_size: int = Query(6, ge=1, le=100, description="每页数量"),
    include_inactive: bool = Query(True, description="是否包含已停用的分类"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """分页获取用户的私有分类列表 (用于管理弹出层，支持大数据量后端分页)"""
    items, total = get_user_categories_paginated(
        db, current_user.id, page=page, page_size=page_size, include_inactive=include_inactive
    )
    total_pages = math.ceil(total / page_size) if total > 0 else 0
    data = PaginatedData(
        items=[CategoryOut.model_validate(c) for c in items],
        pagination=PaginationMeta(
            page=page,
            page_size=page_size,
            total=total,
            total_pages=total_pages,
        ),
    )
    return ApiResponse(data=data)


@router.post("/categories", response_model=ApiResponse[CategoryOut], status_code=status.HTTP_201_CREATED)
def create_category(
    payload: CategoryCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """创建自定义分类"""
    cat = create_user_category(db, current_user.id, payload)
    return ApiResponse(data=CategoryOut.model_validate(cat), message="分类创建成功")


@router.put("/categories/reorder", response_model=ApiResponse[List[CategoryOut]])
def reorder_categories(
    payload: CategoryReorderPayload,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """批量重置当前用户的分类展示次序"""
    cats = reorder_user_categories(db, current_user.id, payload.ordered_ids)
    return ApiResponse(
        data=[CategoryOut.model_validate(c) for c in cats],
        message="分类排序已更新",
    )


@router.put("/categories/{category_id}", response_model=ApiResponse[CategoryOut])
def update_category(
    category_id: int,
    payload: CategoryUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """修改自定义分类信息 (名称、Emoji、排序或启用状态)"""
    cat = update_user_category(db, current_user.id, category_id, payload)
    rebuild_all_items_fts(db)
    return ApiResponse(data=CategoryOut.model_validate(cat), message="分类修改成功")


@router.patch("/categories/{category_id}/status", response_model=ApiResponse[CategoryOut])
def toggle_category_status(
    category_id: int,
    is_active: bool = Query(..., description="启用或停用状态"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """切换分类启用/停用状态"""
    cat = update_user_category(
        db, current_user.id, category_id, CategoryUpdate(is_active=is_active)
    )
    status_text = "启用" if is_active else "停用"
    return ApiResponse(data=CategoryOut.model_validate(cat), message=f"分类已成功{status_text}")


@router.delete("/categories/{category_id}", response_model=ApiResponse[None])
def delete_category(
    category_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """删除分类 (安全解绑关联物品，绝不级联物理删除物品)"""
    delete_user_category(db, current_user.id, category_id)
    return ApiResponse(data=None, message="分类已成功删除，关联物品已自动解绑")


@router.get("/tags/suggest", response_model=ApiResponse[List[str]])
def suggest_tags_endpoint(
    q: str = Query("", description="输入前缀或关键词"),
    limit: int = Query(8, ge=1, le=20, description="返回建议条数"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """跨用户公共标签实时补全建议端点"""
    suggestions = suggest_tags(db, query_prefix=q, limit=limit)
    return ApiResponse(data=suggestions)


@router.get("/tags", response_model=ApiResponse[List[TagOut]])
def list_tags(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """获取用户已创建的所有标签"""
    tags = (
        db.query(Tag)
        .filter(Tag.user_id == current_user.id)
        .order_by(Tag.name.asc())
        .all()
    )
    return ApiResponse(data=[TagOut.model_validate(t) for t in tags])


@router.get("/{item_id}", response_model=ApiResponse[ItemOut])
def get_item(
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """获取单件物品详情"""
    item = get_user_item_by_id(db, current_user.id, item_id)
    return ApiResponse(data=ItemOut.model_validate(item))


@router.post("", response_model=ApiResponse[ItemOut], status_code=status.HTTP_201_CREATED)
def create_item(
    payload: ItemCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """创建并收纳新物品 (系统管理员禁止产生私有物品数据)"""
    if current_user.role == "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="系统管理员账号专用于全局审计与数据备份，禁止创建私有物品数据，请使用家庭成员账号录入。"
        )
    item = create_user_item(db, current_user.id, payload)
    sync_item_fts(db, item.id)
    return ApiResponse(data=ItemOut.model_validate(item), message="物品收纳登记成功")


@router.put("/{item_id}", response_model=ApiResponse[ItemOut])
def update_item(
    item_id: int,
    payload: ItemUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """修改物品信息"""
    item = update_user_item(db, current_user.id, item_id, payload)
    sync_item_fts(db, item.id)
    return ApiResponse(data=ItemOut.model_validate(item), message="物品信息修改成功")


@router.post("/{item_id}/take-out", response_model=ApiResponse[ItemOut])
def take_out_item_endpoint(
    item_id: int,
    payload: ItemTakeOutPayload,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """将已收纳物品取出使用，记录当前位置与使用中实拍附件"""
    item = take_out_item(db, current_user.id, item_id, payload)
    sync_item_fts(db, item.id)
    return ApiResponse(data=ItemOut.model_validate(item), message="物品已标记为取出使用")


@router.post("/{item_id}/put-back", response_model=ApiResponse[ItemOut])
def put_back_item_endpoint(
    item_id: int,
    payload: ItemPutBackPayload,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """将使用中物品归还收纳，清理使用中附件并恢复或更新收纳位置"""
    item = put_back_item(db, current_user.id, item_id, payload)
    sync_item_fts(db, item.id)
    return ApiResponse(data=ItemOut.model_validate(item), message="物品已归还收纳")


@router.delete("/{item_id}", response_model=ApiResponse[None])
def delete_item(
    item_id: int,
    expected_version: Optional[int] = Query(None, ge=1, description="乐观锁期望版本号"),
    force: bool = Query(False, description="冲突时强制删除"),
    client_op_uuid: Optional[str] = Query(None, max_length=64, description="离线删除幂等键"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """删除物品 (支持离线版本校验与 client_op_uuid 幂等)"""
    delete_user_item(
        db,
        current_user.id,
        item_id,
        expected_version=expected_version,
        force=force,
        client_op_uuid=client_op_uuid,
    )
    sync_item_fts(db, item_id)
    return ApiResponse(data=None, message="物品及附件已彻底删除")

