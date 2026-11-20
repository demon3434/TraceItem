import json
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session, joinedload
from app.models.item import Item, ItemSyncOp, Tag, Category
from app.models.space import House, Room
from app.models.attachment import Attachment
from app.schemas.item import ItemCreate, ItemOut, ItemUpdate
from app.services.media_service import delete_physical_attachment


def resolve_tags(db: Session, user_id: int, tag_names: List[str]) -> List[Tag]:
    """解析并维护全局共享标签 (跨用户唯一复用，原子防同名冗余)"""
    tags = []
    seen = set()
    for raw_name in tag_names:
        clean = raw_name.strip()
        if not clean or clean in seen:
            continue
        seen.add(clean)
        # 全局按名称检索 (跨用户共享词库)
        tag = db.query(Tag).filter(Tag.name == clean).first()
        if not tag:
            tag = Tag(user_id=user_id, name=clean)
            db.add(tag)
            db.flush()
        tags.append(tag)
    return tags


def suggest_tags(db: Session, query_prefix: str, limit: int = 8) -> List[str]:
    """根据前缀或包含模糊检索公共标签池"""
    clean_q = query_prefix.strip()
    if not clean_q:
        tags = db.query(Tag.name).order_by(Tag.name.asc()).limit(limit).all()
        return [t[0] for t in tags]

    # 1. 优先前缀匹配
    prefix_tags = (
        db.query(Tag.name)
        .filter(Tag.name.ilike(f"{clean_q}%"))
        .order_by(Tag.name.asc())
        .limit(limit)
        .all()
    )
    results = [t[0] for t in prefix_tags]
    if len(results) < limit:
        # 2. 补充模糊匹配
        contains_tags = (
            db.query(Tag.name)
            .filter(Tag.name.ilike(f"%{clean_q}%"))
            .order_by(Tag.name.asc())
            .limit(limit)
            .all()
        )
        combined = list(dict.fromkeys(results + [t[0] for t in contains_tags]))
        return combined[:limit]
    return results


def _validate_active_space_for_item(
    db: Session, user_id: int, house_id: int, room_id: int
) -> None:
    """校验物品目标房屋与房间是否存在、未删除且均处于启用状态"""
    house = (
        db.query(House)
        .filter(House.id == house_id, House.user_id == user_id, House.is_deleted == False)
        .first()
    )
    room = (
        db.query(Room)
        .filter(Room.id == room_id, Room.user_id == user_id, Room.is_deleted == False)
        .first()
    )
    if not house or not room or room.house_id != house_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="选择的房屋或房间不存在或不匹配，请重新确认",
        )
    if not house.is_active or not room.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="所选房屋或房间已停用，无法写入物品",
        )


def create_user_item(db: Session, user_id: int, payload: ItemCreate) -> Item:
    """创建物品并绑定房屋、房间、多模态附件（支持 client_uuid 幂等防重）"""
    clean_uuid = payload.client_uuid.strip() if payload.client_uuid else None
    if clean_uuid:
        existing = (
            db.query(Item)
            .filter(Item.user_id == user_id, Item.client_uuid == clean_uuid)
            .options(
                joinedload(Item.house),
                joinedload(Item.room),
                joinedload(Item.category),
                joinedload(Item.tags),
                joinedload(Item.attachments),
            )
            .first()
        )
        if existing:
            return existing

    # 1. 校验房屋与房间归属权及启停状态
    _validate_active_space_for_item(db, user_id, payload.house_id, payload.room_id)

    # 2. 标签处理
    tags = resolve_tags(db, user_id, payload.tag_names or [])

    # 3. 创建物品实体
    item = Item(
        user_id=user_id,
        house_id=payload.house_id,
        room_id=payload.room_id,
        category_id=payload.category_id,
        name=payload.name,
        brand=payload.brand or "",
        quantity=payload.quantity,
        location_detail=payload.location_detail or "",
        description=payload.description or "",
        client_uuid=clean_uuid,
        tags=tags,
    )
    db.add(item)
    db.flush()

    # 4. 绑定多模态附件 (图片、音频、短视频)
    if payload.attachments:
        for idx, att in enumerate(payload.attachments):
            attachment = Attachment(
                item_id=item.id,
                media_type=att.media_type,
                file_path=att.file_path,
                thumbnail_path=att.thumbnail_path,
                file_size=att.file_size,
                duration_seconds=att.duration_seconds,
                width=att.width,
                height=att.height,
                display_order=att.display_order or (idx + 1),
            )
            db.add(attachment)

    db.commit()
    db.refresh(item)
    return item


def get_user_items(
    db: Session,
    user_id: int,
    house_id: Optional[int] = None,
    room_id: Optional[int] = None,
    category_id: Optional[int] = None,
    skip: int = 0,
    limit: int = 30,
) -> Tuple[List[Item], int]:
    """分页获取用户的私有物品列表 (仅展示未删除物品)"""
    query = db.query(Item).filter(Item.user_id == user_id, Item.is_deleted == False)
    if house_id:
        query = query.filter(Item.house_id == house_id)
    if room_id:
        query = query.filter(Item.room_id == room_id)
    if category_id:
        query = query.filter(Item.category_id == category_id)

    total = query.count()
    items = (
        query.options(
            joinedload(Item.house),
            joinedload(Item.room),
            joinedload(Item.category),
            joinedload(Item.tags),
            joinedload(Item.attachments),
        )
        .order_by(Item.updated_at.desc(), Item.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return items, total


def get_user_item_by_id(db: Session, user_id: int, item_id: int) -> Item:
    """获取指定物品详情 (过滤已删除物品)"""
    item = (
        db.query(Item)
        .filter(Item.id == item_id, Item.user_id == user_id, Item.is_deleted == False)
        .options(
            joinedload(Item.house),
            joinedload(Item.room),
            joinedload(Item.tags),
            joinedload(Item.attachments),
        )
        .first()
    )
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="物品不存在或无权访问"
        )
    return item


def update_user_item(
    db: Session, user_id: int, item_id: int, payload: ItemUpdate
) -> Item:
    """修改物品信息（支持乐观锁校验、增量字段级三向合并与 client_op_uuid 幂等）"""
    item = get_user_item_by_id(db, user_id, item_id)

    if payload.client_op_uuid:
        existing_op = (
            db.query(ItemSyncOp)
            .filter(
                ItemSyncOp.user_id == user_id,
                ItemSyncOp.client_op_uuid == payload.client_op_uuid,
            )
            .first()
        )
        if existing_op:
            return item

    is_delta = (
        payload.changed_fields is not None
        or payload.added_attachments is not None
        or payload.removed_attachment_paths is not None
    )
    field_versions: dict = {}
    try:
        field_versions = json.loads(item.field_versions_json or "{}")
    except Exception:
        field_versions = {}

    if payload.expected_version is not None and item.version != payload.expected_version and not payload.force_overwrite:
        if is_delta:
            cf = payload.changed_fields or {}
            conflict_fields = [
                k for k in cf.keys() if int(field_versions.get(k, 1)) > payload.expected_version
            ]
            if conflict_fields:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail={
                        "message": f"存在并发修改冲突（{', '.join(conflict_fields)}）",
                        "data": {
                            "conflict_fields": conflict_fields,
                            "latest_item": ItemOut.model_validate(item).model_dump(mode="json"),
                        },
                    },
                )
        else:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"该物品已在其他设备上被修改（当前版本 v{item.version}，提交版本 v{payload.expected_version}），请刷新最新内容后再试",
            )

    touched_fields: set[str] = set()
    cf = payload.changed_fields if payload.changed_fields is not None else {}

    def _pick(key: str, direct_val):
        if payload.changed_fields is not None:
            return (key in cf, cf.get(key))
        return (direct_val is not None, direct_val)

    has_house, val_house = _pick("house_id", payload.house_id)
    has_room, val_room = _pick("room_id", payload.room_id)
    if (has_house and val_house is not None) or (has_room and val_room is not None):
        target_house_id = int(val_house) if has_house and val_house is not None else item.house_id
        target_room_id = int(val_room) if has_room and val_room is not None else item.room_id
        if target_house_id != item.house_id or target_room_id != item.room_id:
            _validate_active_space_for_item(db, user_id, target_house_id, target_room_id)
            if target_house_id != item.house_id:
                touched_fields.add("house_id")
            if target_room_id != item.room_id:
                touched_fields.add("room_id")
        item.house_id = target_house_id
        item.room_id = target_room_id

    for attr_name, direct_val in [
        ("name", payload.name),
        ("brand", payload.brand),
        ("quantity", payload.quantity),
        ("location_detail", payload.location_detail),
        ("description", payload.description),
        ("category_id", payload.category_id),
    ]:
        present, new_val = _pick(attr_name, direct_val)
        if present and (new_val is not None or attr_name == "category_id"):
            if getattr(item, attr_name) != new_val:
                touched_fields.add(attr_name)
            setattr(item, attr_name, new_val)

    has_tags, val_tags = _pick("tag_names", payload.tag_names)
    if has_tags and val_tags is not None:
        item.tags = resolve_tags(db, user_id, list(val_tags))
        touched_fields.add("tag_names")

    if payload.added_attachments is not None or payload.removed_attachment_paths is not None:
        removed_set = set(payload.removed_attachment_paths or [])
        if removed_set:
            for att_row in list(item.attachments):
                if att_row.file_path in removed_set:
                    delete_physical_attachment(att_row.file_path, att_row.thumbnail_path)
                    db.delete(att_row)
            db.flush()
            touched_fields.add("attachments")
        existing_paths = {a.file_path for a in item.attachments if a.file_path not in removed_set}
        max_order = max((a.display_order or 0 for a in item.attachments), default=0)
        for att in (payload.added_attachments or []):
            if att.file_path in existing_paths:
                continue
            max_order += 1
            db.add(
                Attachment(
                    item_id=item.id,
                    media_type=att.media_type,
                    file_path=att.file_path,
                    thumbnail_path=att.thumbnail_path,
                    file_size=att.file_size,
                    duration_seconds=att.duration_seconds,
                    width=att.width,
                    height=att.height,
                    display_order=att.display_order or max_order,
                )
            )
            touched_fields.add("attachments")
    elif payload.attachments is not None:
        old_paths = {(a.file_path, a.thumbnail_path) for a in item.attachments}
        new_file_paths = {att.file_path for att in payload.attachments}
        db.query(Attachment).filter(Attachment.item_id == item.id).delete()
        for idx, att in enumerate(payload.attachments):
            db.add(
                Attachment(
                    item_id=item.id,
                    media_type=att.media_type,
                    file_path=att.file_path,
                    thumbnail_path=att.thumbnail_path,
                    file_size=att.file_size,
                    duration_seconds=att.duration_seconds,
                    width=att.width,
                    height=att.height,
                    display_order=att.display_order or (idx + 1),
                )
            )
        for old_file, old_thumb in old_paths:
            if old_file not in new_file_paths:
                delete_physical_attachment(old_file, old_thumb)
        touched_fields.add("attachments")

    item.version = (item.version or 1) + 1
    for f in touched_fields:
        field_versions[f] = item.version
    item.field_versions_json = json.dumps(field_versions)
    if payload.client_op_uuid:
        db.add(ItemSyncOp(user_id=user_id, item_id=item.id, client_op_uuid=payload.client_op_uuid))
    db.commit()
    db.refresh(item)
    return item


def delete_user_item(
    db: Session,
    user_id: int,
    item_id: int,
    expected_version: Optional[int] = None,
    force: bool = False,
    client_op_uuid: Optional[str] = None,
) -> None:
    """全局软删除物品（支持离线删除版本校验与 client_op_uuid 幂等）"""
    if client_op_uuid:
        existing_op = (
            db.query(ItemSyncOp)
            .filter(
                ItemSyncOp.user_id == user_id,
                ItemSyncOp.client_op_uuid == client_op_uuid,
            )
            .first()
        )
        if existing_op:
            return
    item = get_user_item_by_id(db, user_id, item_id)
    if expected_version is not None and not force and item.version != expected_version:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "message": f"该物品在离线期间已被他人更新（当前 v{item.version}），请确认是否仍要删除",
                "data": {
                    "conflict_fields": ["__delete__"],
                    "latest_item": ItemOut.model_validate(item).model_dump(mode="json"),
                },
            },
        )
    item.is_deleted = True
    if client_op_uuid:
        db.add(ItemSyncOp(user_id=user_id, item_id=item.id, client_op_uuid=client_op_uuid))
    db.commit()
