from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.space import RoomCreate, RoomOut, RoomReorderPayload, RoomUpdate
from app.services.space_service import (
    create_user_room,
    delete_user_room,
    get_user_rooms,
    reorder_user_rooms,
    update_user_room,
)

router = APIRouter(prefix="/rooms", tags=["空间-房间管理"])


@router.get("", response_model=ApiResponse[List[RoomOut]])
def list_rooms(
    house_id: Optional[int] = Query(None, description="指定所属房屋ID，缺省则拉取全部房间"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """获取当前登录用户的房间列表 (橱柜免配置原则)"""
    rooms = get_user_rooms(db, current_user.id, house_id)
    return ApiResponse(data=[RoomOut.model_validate(r) for r in rooms])


@router.post("", response_model=ApiResponse[RoomOut], status_code=status.HTTP_201_CREATED)
def create_room(
    payload: RoomCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """在指定房屋下创建预设功能房间 (系统管理员禁止产生私有空间)"""
    if current_user.role == "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="系统管理员账号专用于全局审计与数据备份，禁止创建私有房间数据，请使用家庭成员账号录入。"
        )
    room = create_user_room(db, current_user.id, payload)
    return ApiResponse(data=RoomOut.model_validate(room), message="房间创建成功")


@router.put("/reorder", response_model=ApiResponse[List[RoomOut]])
def reorder_rooms(
    payload: RoomReorderPayload,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """原子批量更新指定房屋下的房间展示顺序"""
    rooms = reorder_user_rooms(db, current_user.id, payload.house_id, payload.ordered_ids)
    return ApiResponse(
        data=[RoomOut.model_validate(r) for r in rooms],
        message="房间顺序已更新",
    )


@router.put("/{room_id}", response_model=ApiResponse[RoomOut])
def update_room(
    room_id: int,
    payload: RoomUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """更新房间名称、Emoji 图标、排序或启停状态"""
    room = update_user_room(db, current_user.id, room_id, payload)
    return ApiResponse(data=RoomOut.model_validate(room), message="房间更新成功")


@router.patch("/{room_id}/status", response_model=ApiResponse[RoomOut])
def toggle_room_status(
    room_id: int,
    is_active: bool = Query(..., description="启用或停用状态"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """快速启用或停用指定房间"""
    room = update_user_room(db, current_user.id, room_id, RoomUpdate(is_active=is_active))
    status_text = "启用" if is_active else "停用"
    return ApiResponse(data=RoomOut.model_validate(room), message=f"房间已{status_text}")


@router.delete("/{room_id}", response_model=ApiResponse[None])
def delete_room(
    room_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """删除指定空房间 (存在未删除物品时禁止删除)"""
    delete_user_room(db, current_user.id, room_id)
    return ApiResponse(data=None, message="房间已成功删除")

