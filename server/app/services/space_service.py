from typing import List, Optional
from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session
from app.models.space import House, Room
from app.models.item import Item
from app.schemas.space import HouseCreate, HouseUpdate, RoomCreate, RoomUpdate


def get_user_houses(db: Session, user_id: int) -> List[House]:
    """获取指定用户的所有有效房屋列表"""
    return (
        db.query(House)
        .filter(House.user_id == user_id, House.is_deleted == False)
        .order_by(House.sort_order.asc(), House.id.asc())
        .all()
    )


def create_user_house(db: Session, user_id: int, payload: HouseCreate) -> House:
    """创建房屋 (用户独立私有作用域)"""
    existing = (
        db.query(House)
        .filter(House.user_id == user_id, House.name == payload.name, House.is_deleted == False)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"您已创建过名为“{payload.name}”的房屋",
        )
    sort_order = payload.sort_order
    if sort_order <= 0:
        max_order = (
            db.query(func.max(House.sort_order))
            .filter(House.user_id == user_id, House.is_deleted == False)
            .scalar()
            or 0
        )
        sort_order = max_order + 1

    house = House(
        user_id=user_id,
        name=payload.name,
        icon=payload.icon,
        sort_order=sort_order,
    )
    db.add(house)
    db.commit()
    db.refresh(house)
    return house


def update_user_house(
    db: Session, user_id: int, house_id: int, payload: HouseUpdate
) -> House:
    """修改指定房屋"""
    house = (
        db.query(House)
        .filter(House.id == house_id, House.user_id == user_id, House.is_deleted == False)
        .first()
    )
    if not house:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="房屋不存在或无权操作"
        )
    if payload.name is not None and payload.name != house.name:
        conflict = (
            db.query(House)
            .filter(House.user_id == user_id, House.name == payload.name, House.is_deleted == False)
            .first()
        )
        if conflict:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"已存在同名房屋“{payload.name}”",
            )
        house.name = payload.name
    if payload.icon is not None:
        house.icon = payload.icon
    if payload.sort_order is not None:
        house.sort_order = payload.sort_order
    if payload.is_active is not None:
        house.is_active = payload.is_active

    db.commit()
    db.refresh(house)
    return house


def delete_user_house(db: Session, user_id: int, house_id: int) -> None:
    """删除房屋 (存在未删除物品时禁止删除；仅含空房间时连带清理空房间)"""
    house = (
        db.query(House)
        .filter(House.id == house_id, House.user_id == user_id, House.is_deleted == False)
        .first()
    )
    if not house:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="房屋不存在或无权操作"
        )
    active_item_count = (
        db.query(Item)
        .filter(Item.house_id == house_id, Item.user_id == user_id, Item.is_deleted == False)
        .count()
    )
    if active_item_count > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"该房屋内还有 {active_item_count} 件物品，无法直接删除；请先清理物品，或改为停用该房屋",
        )
    house.is_deleted = True
    db.query(Room).filter(Room.house_id == house_id, Room.user_id == user_id).update({"is_deleted": True})
    db.commit()


def get_user_rooms(
    db: Session, user_id: int, house_id: Optional[int] = None
) -> List[Room]:
    """获取指定用户特定房屋（或全部）下的房间列表"""
    query = db.query(Room).filter(Room.user_id == user_id, Room.is_deleted == False)
    if house_id:
        query = query.filter(Room.house_id == house_id)
    return query.order_by(Room.sort_order.asc(), Room.id.asc()).all()


def create_user_room(db: Session, user_id: int, payload: RoomCreate) -> Room:
    """创建预设房间 (橱柜免配置，拍照直观展现)"""
    # 校验房屋属权
    house = (
        db.query(House)
        .filter(House.id == payload.house_id, House.user_id == user_id, House.is_deleted == False)
        .first()
    )
    if not house:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="所属房屋不存在或无权访问"
        )
    if not house.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="所属房屋已停用，请先启用后再新建房间"
        )

    existing = (
        db.query(Room)
        .filter(
            Room.user_id == user_id,
            Room.house_id == payload.house_id,
            Room.name == payload.name,
            Room.is_deleted == False,
        )
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"该房屋下已有同名房间“{payload.name}”",
        )

    sort_order = payload.sort_order
    if sort_order <= 0:
        max_order = (
            db.query(func.max(Room.sort_order))
            .filter(
                Room.user_id == user_id,
                Room.house_id == payload.house_id,
                Room.is_deleted == False,
            )
            .scalar()
            or 0
        )
        sort_order = max_order + 1

    room = Room(
        user_id=user_id,
        house_id=payload.house_id,
        name=payload.name,
        icon=payload.icon,
        sort_order=sort_order,
    )
    db.add(room)
    db.commit()
    db.refresh(room)
    return room


def update_user_room(
    db: Session, user_id: int, room_id: int, payload: RoomUpdate
) -> Room:
    """修改指定房间"""
    room = (
        db.query(Room).filter(Room.id == room_id, Room.user_id == user_id, Room.is_deleted == False).first()
    )
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="房间不存在或无权操作"
        )

    if payload.name is not None and payload.name != room.name:
        conflict = (
            db.query(Room)
            .filter(
                Room.user_id == user_id,
                Room.house_id == room.house_id,
                Room.name == payload.name,
                Room.is_deleted == False,
            )
            .first()
        )
        if conflict:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"该房屋下已存在同名房间“{payload.name}”",
            )
        room.name = payload.name
    if payload.icon is not None:
        room.icon = payload.icon
    if payload.sort_order is not None:
        room.sort_order = payload.sort_order
    if payload.is_active is not None:
        room.is_active = payload.is_active

    db.commit()
    db.refresh(room)
    return room


def delete_user_room(db: Session, user_id: int, room_id: int) -> None:
    """删除指定房间 (存在未删除物品时禁止删除)"""
    room = (
        db.query(Room).filter(Room.id == room_id, Room.user_id == user_id, Room.is_deleted == False).first()
    )
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="房间不存在或无权操作"
        )
    active_item_count = (
        db.query(Item)
        .filter(Item.room_id == room_id, Item.user_id == user_id, Item.is_deleted == False)
        .count()
    )
    if active_item_count > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"该房间内还有 {active_item_count} 件物品，无法直接删除；请先迁移/删除物品，或改为停用该房间",
        )
    room.is_deleted = True
    db.commit()


def reorder_user_houses(
    db: Session, user_id: int, ordered_ids: List[int]
) -> List[House]:
    """原子批量更新当前用户的房屋展示顺序"""
    if len(ordered_ids) != len(set(ordered_ids)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="房屋排序列表包含重复 ID",
        )
    houses = get_user_houses(db, user_id)
    house_map = {h.id: h for h in houses}
    if set(ordered_ids) != set(house_map.keys()):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="房屋排序列表与当前有效房屋集合不匹配",
        )
    for idx, house_id in enumerate(ordered_ids, start=1):
        house_map[house_id].sort_order = idx
    db.commit()
    return get_user_houses(db, user_id)


def reorder_user_rooms(
    db: Session, user_id: int, house_id: int, ordered_ids: List[int]
) -> List[Room]:
    """原子批量更新指定房屋下房间的展示顺序"""
    house = (
        db.query(House)
        .filter(House.id == house_id, House.user_id == user_id, House.is_deleted == False)
        .first()
    )
    if not house:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="所属房屋不存在或无权操作"
        )
    if len(ordered_ids) != len(set(ordered_ids)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="房间排序列表包含重复 ID",
        )
    rooms = get_user_rooms(db, user_id, house_id)
    room_map = {r.id: r for r in rooms}
    if set(ordered_ids) != set(room_map.keys()):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="房间排序列表存在无效、跨房屋或缺失的房间 ID",
        )
    for idx, room_id in enumerate(ordered_ids, start=1):
        room_map[room_id].sort_order = idx
    db.commit()
    return get_user_rooms(db, user_id, house_id)

