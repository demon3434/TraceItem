import os
import time
from pathlib import Path
from typing import List, Optional, Tuple
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.core.config import settings
from app.core.security import hash_password, verify_password
from app.models.attachment import Attachment
from app.models.backup import BackupRecord
from app.models.item import Category, Item, Tag
from app.models.space import House, Room
from app.models.user import User
from app.schemas.admin import (
    AdminSystemStats,
    AdminUserCreate,
    AdminUserOut,
    GodViewCascadingHouse,
    GodViewCascadingRoom,
    GodViewCascadingUser,
    GodViewFilterCategory,
    GodViewFilterOptions,
    OrphanMediaStats,
    SoftDeletedMediaStats,
)
from app.services.backup_service import format_bytes
from app.services.category_service import seed_user_default_categories
from app.services.media_service import delete_physical_attachment


def list_admin_users(db: Session) -> List[AdminUserOut]:
    """获取所有用户列表及其关联资产统计计数"""
    users = db.scalars(select(User).order_by(User.id.asc())).all()

    # 聚合统计各用户的房屋数、房间数、物品数
    house_counts = dict(
        db.query(House.user_id, func.count(House.id))
        .group_by(House.user_id)
        .all()
    )
    room_counts = dict(
        db.query(Room.user_id, func.count(Room.id))
        .group_by(Room.user_id)
        .all()
    )
    item_counts = dict(
        db.query(Item.user_id, func.count(Item.id))
        .group_by(Item.user_id)
        .all()
    )

    out: List[AdminUserOut] = []
    for u in users:
        u_out = AdminUserOut(
            id=u.id,
            username=u.username,
            nickname=u.nickname or u.username,
            role=u.role,
            is_active=u.is_active,
            created_at=u.created_at,
            house_count=house_counts.get(u.id, 0),
            room_count=room_counts.get(u.id, 0),
            item_count=item_counts.get(u.id, 0),
        )
        out.append(u_out)
    return out


def create_managed_user(db: Session, payload: AdminUserCreate) -> User:
    """管理员代开家庭成员账号并自动注入14套默认分类 (密码不填默认 123456)"""
    existing = db.scalar(select(User).where(User.username == payload.username.strip()))
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"用户名“{payload.username}”已存在",
        )

    raw_pwd = payload.password.strip() if (payload.password and payload.password.strip()) else "123456"

    user = User(
        username=payload.username.strip(),
        password_hash=hash_password(raw_pwd),
        nickname=payload.nickname.strip() if payload.nickname else payload.username.strip(),
        role="user",
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # 注入全场景默认分类模板
    seed_user_default_categories(db, user.id)
    return user


def update_user_active_status(db: Session, user_id: int, is_active: bool, current_admin_id: int) -> User:
    """修改指定用户的账号启用/冻结状态 (禁止管理员自我冻结)"""
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在",
        )
    if user.id == current_admin_id and not is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="系统管理员不能冻结自己的当前账号",
        )

    user.is_active = is_active
    db.commit()
    db.refresh(user)
    return user


def reset_user_password(db: Session, user_id: int, new_password: str) -> User:
    """管理员重置指定成员密码"""
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在",
        )

    user.password_hash = hash_password(new_password)
    user.token_version = (user.token_version or 1) + 1
    db.commit()
    db.refresh(user)
    return user


def init_user_password(db: Session, user_id: int) -> User:
    """管理员一键初始化成员密码为默认密码 123456"""
    return reset_user_password(db, user_id, "123456")


def get_system_stats(db: Session) -> AdminSystemStats:
    """获取系统运行指标、多媒体存储占用与最新备份时间"""
    total_users = db.scalar(select(func.count(User.id))) or 0
    total_items = db.scalar(select(func.count(Item.id))) or 0
    total_houses = db.scalar(select(func.count(House.id))) or 0
    total_rooms = db.scalar(select(func.count(Room.id))) or 0
    total_backups = db.scalar(select(func.count(BackupRecord.id))) or 0

    latest_backup = db.scalar(
        select(BackupRecord).order_by(BackupRecord.id.desc()).limit(1)
    )
    last_backup_time = latest_backup.created_at if latest_backup else None

    # 计算多媒体存储占用 (递归统计 settings.MEDIA_DIR)
    total_bytes = 0
    media_dir = settings.MEDIA_DIR
    if media_dir.exists():
        for root, _, files in os.walk(media_dir):
            for f in files:
                fp = os.path.join(root, f)
                try:
                    total_bytes += os.path.getsize(fp)
                except OSError:
                    pass

    # 格式化显示存储体积
    if total_bytes < 1024 * 1024:
        display_str = f"{total_bytes / 1024:.1f} KB"
    elif total_bytes < 1024 * 1024 * 1024:
        display_str = f"{total_bytes / (1024 * 1024):.1f} MB"
    else:
        display_str = f"{total_bytes / (1024 * 1024 * 1024):.2f} GB"

    return AdminSystemStats(
        total_users=total_users,
        total_items=total_items,
        total_houses=total_houses,
        total_rooms=total_rooms,
        media_storage_bytes=total_bytes,
        media_storage_display=display_str,
        last_backup_time=last_backup_time,
        total_backups=total_backups,
    )


# ==========================================
# 管理员改密与多维级联寻物 (只读)
# ==========================================

def change_admin_password(db: Session, admin_id: int, old_password: str, new_password: str) -> None:
    """系统管理员修改自身登录密码"""
    admin = db.get(User, admin_id)
    if not admin:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="管理员账号不存在")
    if not verify_password(old_password, admin.password_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="原管理员密码校验失败，无法修改")
    admin.password_hash = hash_password(new_password)
    db.commit()


def get_god_view_filter_options(db: Session) -> GodViewFilterOptions:
    """拉取托底寻物的级联筛选项 (用户 -> 房屋 -> 房间，分类池与全局标签)"""
    users = db.query(User).filter(User.is_deleted == False).order_by(User.id.asc()).all()
    user_options: List[GodViewCascadingUser] = []
    for u in users:
        houses = (
            db.query(House)
            .filter(House.user_id == u.id, House.is_deleted == False)
            .order_by(House.sort_order.asc(), House.id.asc())
            .all()
        )
        house_options: List[GodViewCascadingHouse] = []
        for h in houses:
            rooms = (
                db.query(Room)
                .filter(Room.house_id == h.id, Room.is_deleted == False)
                .order_by(Room.sort_order.asc(), Room.id.asc())
                .all()
            )
            room_options = [GodViewCascadingRoom(id=r.id, name=r.name, icon=r.icon) for r in rooms]
            house_options.append(GodViewCascadingHouse(id=h.id, name=h.name, icon=h.icon, rooms=room_options))
        user_options.append(GodViewCascadingUser(id=u.id, username=u.username, nickname=u.nickname or u.username, houses=house_options))

    # 所有有效分类 (去重)
    categories = db.query(Category).filter(Category.is_deleted == False).all()
    seen_cats = set()
    cat_options: List[GodViewFilterCategory] = []
    for c in categories:
        if c.name not in seen_cats:
            seen_cats.add(c.name)
            cat_options.append(GodViewFilterCategory(id=c.id, name=c.name, icon=c.icon))
    cat_options.sort(key=lambda x: x.name)

    # 所有有效标签
    tags = db.query(Tag.name).filter(Tag.is_deleted == False).distinct().order_by(Tag.name.asc()).all()
    tag_options = [t[0] for t in tags]

    return GodViewFilterOptions(users=user_options, categories=cat_options, tags=tag_options)


def god_view_advanced_search(
    db: Session,
    user_id: Optional[int] = None,
    house_id: Optional[int] = None,
    room_id: Optional[int] = None,
    category_id: Optional[int] = None,
    tag_name: Optional[str] = None,
    keyword: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    page: int = 1,
    page_size: int = 20,
) -> Tuple[List[Item], int]:
    """Admin 上帝视角多维组合高级寻物 (严格只读，过滤 is_deleted=False)"""
    query = db.query(Item).filter(Item.is_deleted == False)

    if user_id:
        query = query.filter(Item.user_id == user_id)
    if house_id:
        query = query.filter(Item.house_id == house_id)
    if room_id:
        query = query.filter(Item.room_id == room_id)
    if category_id:
        query = query.filter(Item.category_id == category_id)
    if tag_name and tag_name.strip():
        query = query.filter(Item.tags.any(Tag.name == tag_name.strip()))
    if keyword and keyword.strip():
        kw = f"%{keyword.strip()}%"
        query = query.filter(
            (Item.name.ilike(kw))
            | (Item.brand.ilike(kw))
            | (Item.location_detail.ilike(kw))
            | (Item.description.ilike(kw))
        )
    if start_date:
        try:
            sd = datetime.fromisoformat(start_date.strip())
            query = query.filter(Item.created_at >= sd)
        except Exception:
            pass
    if end_date:
        try:
            ed = datetime.fromisoformat(end_date.strip())
            query = query.filter(Item.created_at <= ed)
        except Exception:
            pass

    total = query.count()
    items = (
        query.options(
            joinedload(Item.house),
            joinedload(Item.room),
            joinedload(Item.category),
            joinedload(Item.tags),
            joinedload(Item.attachments),
            joinedload(Item.owner),
        )
        .order_by(Item.updated_at.desc(), Item.id.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return items, total


# ==========================================
# 孤儿附件物理扫描与清理
# ==========================================

def get_all_orphan_files(db: Session, min_age_seconds: int = 3600) -> List[Tuple[str, Path, int]]:
    """扫描所有磁盘孤儿多媒体文件 (返回 (rel_path, abs_path, file_size))，默认保留 3600s 保护期防误删在编文件"""
    valid_paths = set()
    for att in db.query(Attachment.file_path, Attachment.thumbnail_path).all():
        if att[0]:
            valid_paths.add(att[0].replace("\\", "/").strip("/"))
        if att[1]:
            valid_paths.add(att[1].replace("\\", "/").strip("/"))

    now = time.time()
    orphan_files: List[Tuple[str, Path, int]] = []
    for sub in ["images", "audios", "videos", "thumbnails"]:
        sub_dir = settings.MEDIA_DIR / sub
        if not sub_dir.exists():
            continue
        for root, _, files in os.walk(sub_dir):
            for f in files:
                abs_p = Path(root) / f
                try:
                    rel_p = abs_p.relative_to(settings.MEDIA_DIR).as_posix()
                    if rel_p not in valid_paths:
                        st = abs_p.stat()
                        if min_age_seconds > 0 and (now - st.st_mtime) < min_age_seconds:
                            continue
                        orphan_files.append((rel_p, abs_p, st.st_size))
                except Exception:
                    pass
    return orphan_files


def scan_orphan_media(db: Session, min_age_seconds: int = 3600) -> OrphanMediaStats:
    """统计当前多媒体孤儿文件数量与总体积"""
    orphans = get_all_orphan_files(db, min_age_seconds=min_age_seconds)
    total_bytes = sum(sz for _, _, sz in orphans)
    rel_files = [rel for rel, _, _ in orphans][:50]
    return OrphanMediaStats(
        orphan_count=len(orphans),
        orphan_size_bytes=total_bytes,
        orphan_size_display=format_bytes(total_bytes),
        orphan_files=rel_files,
    )


def clean_orphan_media(db: Session, min_age_seconds: int = 3600) -> Tuple[int, int]:
    """物理清理所有磁盘孤儿多媒体文件并移除空目录"""
    orphans = get_all_orphan_files(db, min_age_seconds=min_age_seconds)
    deleted_count = 0
    reclaimed_bytes = 0
    for _, abs_p, sz in orphans:
        try:
            if abs_p.exists():
                abs_p.unlink()
                deleted_count += 1
                reclaimed_bytes += sz
        except Exception:
            pass

    for sub in ["images", "audios", "videos", "thumbnails"]:
        sub_dir = settings.MEDIA_DIR / sub
        if sub_dir.exists():
            for root, dirs, _ in os.walk(sub_dir, topdown=False):
                for d in dirs:
                    dp = Path(root) / d
                    try:
                        if not any(dp.iterdir()):
                            dp.rmdir()
                    except Exception:
                        pass
    return deleted_count, reclaimed_bytes


# ==========================================
# 已软删除物品媒体审计与彻底清理
# ==========================================

def _query_soft_deleted_items(db: Session, older_than_days: int = 0) -> List[Item]:
    query = db.query(Item).options(joinedload(Item.attachments)).filter(Item.is_deleted == True)
    if older_than_days > 0:
        cutoff = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=older_than_days)
        query = query.filter(Item.updated_at <= cutoff)
    return query.all()


def _calc_attachment_disk_bytes(att: Attachment) -> int:
    total = 0
    for rel in (att.file_path, att.thumbnail_path):
        if not rel:
            continue
        p = settings.MEDIA_DIR / rel
        if p.exists() and p.is_file():
            try:
                total += p.stat().st_size
            except Exception:
                pass
    return total if total > 0 else (att.file_size or 0)


def get_soft_deleted_media_stats(db: Session, older_than_days: int = 0) -> SoftDeletedMediaStats:
    """统计已软删除物品及其关联物理附件占用的空间"""
    items = _query_soft_deleted_items(db, older_than_days=older_than_days)
    att_count = 0
    total_bytes = 0
    for item in items:
        for att in item.attachments:
            att_count += 1
            total_bytes += _calc_attachment_disk_bytes(att)
    return SoftDeletedMediaStats(
        deleted_item_count=len(items),
        attachment_count=att_count,
        total_size_bytes=total_bytes,
        total_size_display=format_bytes(total_bytes),
    )


def purge_soft_deleted_items(db: Session, older_than_days: int = 0) -> Tuple[int, int, int]:
    """彻底清理已软删除物品的数据库记录及其关联物理附件"""
    items = _query_soft_deleted_items(db, older_than_days=older_than_days)
    purged_items = len(items)
    deleted_attachments = 0
    reclaimed_bytes = 0

    for item in items:
        for att in list(item.attachments):
            reclaimed_bytes += _calc_attachment_disk_bytes(att)
            delete_physical_attachment(att.file_path, att.thumbnail_path)
            deleted_attachments += 1
        item.tags.clear()
        db.delete(item)

    if purged_items > 0:
        db.commit()
    return purged_items, deleted_attachments, reclaimed_bytes


