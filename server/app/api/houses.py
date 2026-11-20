from typing import List
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.space import HouseCreate, HouseOut, HouseReorderPayload, HouseUpdate
from app.services.space_service import (
    create_user_house,
    delete_user_house,
    get_user_houses,
    reorder_user_houses,
    update_user_house,
)

router = APIRouter(prefix="/houses", tags=["空间-房屋管理"])


@router.get("", response_model=ApiResponse[List[HouseOut]])
def list_houses(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """获取当前登录用户的所有私有房屋列表"""
    houses = get_user_houses(db, current_user.id)
    return ApiResponse(data=[HouseOut.model_validate(h) for h in houses])


@router.post("", response_model=ApiResponse[HouseOut], status_code=status.HTTP_201_CREATED)
def create_house(
    payload: HouseCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """创建新房屋 (私有独立作用域，系统管理员禁止产生私有空间)"""
    if current_user.role == "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="系统管理员账号专用于全局审计与数据备份，禁止创建私有房屋数据，请使用家庭成员账号录入。"
        )
    house = create_user_house(db, current_user.id, payload)
    return ApiResponse(data=HouseOut.model_validate(house), message="房屋创建成功")


@router.put("/reorder", response_model=ApiResponse[List[HouseOut]])
def reorder_houses(
    payload: HouseReorderPayload,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """原子批量更新当前用户的房屋展示顺序"""
    houses = reorder_user_houses(db, current_user.id, payload.ordered_ids)
    return ApiResponse(
        data=[HouseOut.model_validate(h) for h in houses],
        message="房屋顺序已更新",
    )


@router.put("/{house_id}", response_model=ApiResponse[HouseOut])
def update_house(
    house_id: int,
    payload: HouseUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """更新指定房屋名称、Emoji 图标、排序或启停状态"""
    house = update_user_house(db, current_user.id, house_id, payload)
    return ApiResponse(data=HouseOut.model_validate(house), message="房屋更新成功")


@router.patch("/{house_id}/status", response_model=ApiResponse[HouseOut])
def toggle_house_status(
    house_id: int,
    is_active: bool = Query(..., description="启用或停用状态"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """快速启用或停用指定房屋"""
    house = update_user_house(db, current_user.id, house_id, HouseUpdate(is_active=is_active))
    status_text = "启用" if is_active else "停用"
    return ApiResponse(data=HouseOut.model_validate(house), message=f"房屋已{status_text}")


@router.delete("/{house_id}", response_model=ApiResponse[None])
def delete_house(
    house_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """删除空房屋 (存在未删除物品时禁止删除)"""
    delete_user_house(db, current_user.id, house_id)
    return ApiResponse(data=None, message="房屋已成功删除")

