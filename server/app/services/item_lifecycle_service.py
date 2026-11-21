from datetime import datetime, timezone
from typing import List, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.attachment import Attachment
from app.models.item import Item, ItemSyncOp
from app.schemas.item import ItemPutBackPayload, ItemTakeOutPayload
from app.services.item_service import _validate_active_space_for_item, get_user_item_by_id
from app.services.media_service import delete_physical_attachment


def _check_sync_op_or_version(
    db: Session,
    user_id: int,
    item: Item,
    expected_version: int | None,
    client_op_uuid: str | None,
) -> bool:
    """校验离线幂等键与乐观锁版本；若幂等命中返回 True"""
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
            return True
    if expected_version is not None and item.version != expected_version:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"该物品已在其他设备上被修改（当前版本 v{item.version}，提交版本 v{expected_version}），请刷新后再试",
        )
    return False


def take_out_item(
    db: Session,
    user_id: int,
    item_id: int,
    payload: ItemTakeOutPayload,
) -> Item:
    """将已收纳物品标记为取出使用，保存原收纳位置快照并写入 in_use 组附件"""
    item = get_user_item_by_id(db, user_id, item_id)
    if _check_sync_op_or_version(db, user_id, item, payload.expected_version, payload.client_op_uuid):
        return item

    if item.status == "in_use":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该物品当前已处于取出使用状态",
        )

    has_image = any(att.media_type == "image" for att in payload.attachments)
    if not has_image:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="取出使用时必须至少提交 1 张当前实拍照片",
        )

    _validate_active_space_for_item(db, user_id, payload.house_id, payload.room_id)

    item.storage_house_id = item.house_id
    item.storage_room_id = item.room_id
    item.storage_location_detail = item.location_detail or ""

    item.house_id = payload.house_id
    item.room_id = payload.room_id
    item.location_detail = payload.location_detail or ""
    item.status = "in_use"
    item.status_updated_at = datetime.now(timezone.utc)
    item.version = (item.version or 1) + 1

    for idx, att in enumerate(payload.attachments):
        db.add(
            Attachment(
                item_id=item.id,
                media_type=att.media_type,
                scene="in_use",
                file_path=att.file_path,
                thumbnail_path=att.thumbnail_path,
                file_size=att.file_size,
                duration_seconds=att.duration_seconds,
                width=att.width,
                height=att.height,
                display_order=att.display_order or (idx + 1),
            )
        )

    if payload.client_op_uuid:
        db.add(ItemSyncOp(user_id=user_id, item_id=item.id, client_op_uuid=payload.client_op_uuid))

    db.commit()
    db.refresh(item)
    return item


def put_back_item(
    db: Session,
    user_id: int,
    item_id: int,
    payload: ItemPutBackPayload,
) -> Item:
    """将使用中物品归还收纳，恢复/更新收纳位置并销毁全部 in_use 组附件"""
    item = get_user_item_by_id(db, user_id, item_id)
    if _check_sync_op_or_version(db, user_id, item, payload.expected_version, payload.client_op_uuid):
        return item

    if item.status != "in_use":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该物品当前未处于取出使用状态",
        )

    if payload.restore_original:
        target_house_id = item.storage_house_id or item.house_id
        target_room_id = item.storage_room_id or item.room_id
        target_detail = item.storage_location_detail or ""
    else:
        target_house_id = payload.house_id if payload.house_id is not None else (item.storage_house_id or item.house_id)
        target_room_id = payload.room_id if payload.room_id is not None else (item.storage_room_id or item.room_id)
        target_detail = (
            payload.location_detail
            if payload.location_detail is not None
            else (item.storage_location_detail or "")
        )

    _validate_active_space_for_item(db, user_id, target_house_id, target_room_id)

    files_to_delete: List[Tuple[str, str | None]] = []
    for att_row in list(item.attachments):
        if att_row.scene == "in_use":
            files_to_delete.append((att_row.file_path, att_row.thumbnail_path))
            db.delete(att_row)

    removed_set = set(payload.removed_attachment_paths or [])
    if removed_set:
        for att_row in list(item.attachments):
            if (att_row.scene or "storage") == "storage" and att_row.file_path in removed_set:
                files_to_delete.append((att_row.file_path, att_row.thumbnail_path))
                db.delete(att_row)

    if payload.added_storage_attachments:
        existing_storage_paths = {
            a.file_path
            for a in item.attachments
            if (a.scene or "storage") == "storage" and a.file_path not in removed_set
        }
        max_order = max(
            (a.display_order or 0 for a in item.attachments if (a.scene or "storage") == "storage"),
            default=0,
        )
        for att in payload.added_storage_attachments:
            if att.file_path in existing_storage_paths:
                continue
            max_order += 1
            db.add(
                Attachment(
                    item_id=item.id,
                    media_type=att.media_type,
                    scene="storage",
                    file_path=att.file_path,
                    thumbnail_path=att.thumbnail_path,
                    file_size=att.file_size,
                    duration_seconds=att.duration_seconds,
                    width=att.width,
                    height=att.height,
                    display_order=att.display_order or max_order,
                )
            )

    item.house_id = target_house_id
    item.room_id = target_room_id
    item.location_detail = target_detail
    item.storage_house_id = None
    item.storage_room_id = None
    item.storage_location_detail = ""
    item.status = "stored"
    item.status_updated_at = datetime.now(timezone.utc)
    item.version = (item.version or 1) + 1

    if payload.client_op_uuid:
        db.add(ItemSyncOp(user_id=user_id, item_id=item.id, client_op_uuid=payload.client_op_uuid))

    db.commit()
    db.refresh(item)

    for fp, tp in files_to_delete:
        delete_physical_attachment(fp, tp)

    return item

