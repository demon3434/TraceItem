import math
from typing import List, Optional
from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session, joinedload

from app.core.config import settings
from app.core.deps import get_current_admin, get_db
from app.models.backup import BackupRecord
from app.models.item import Item
from app.models.user import User
from app.schemas.admin import (
    AdminPasswordChange,
    AdminSystemStats,
    AdminUserCreate,
    AdminUserOut,
    AdminUserPasswordReset,
    AdminUserStatusUpdate,
    GodViewFilterOptions,
    ImportedBackupRecord,
    ImportRestoreRequest,
    OrphanMediaStats,
    SoftDeletedMediaStats,
)
from app.schemas.backup import BackupPruneRequest, BackupRecordOut
from app.schemas.common import ApiResponse, PaginatedData, PaginationMeta
from app.schemas.item import GodViewItemOut
from app.services.admin_service import (
    change_admin_password,
    clean_orphan_media,
    create_managed_user,
    get_god_view_filter_options,
    get_soft_deleted_media_stats,
    get_system_stats,
    god_view_advanced_search,
    init_user_password,
    list_admin_users,
    purge_soft_deleted_items,
    reset_user_password,
    scan_orphan_media,
    update_user_active_status,
)
from app.services.backup_service import (
    create_manual_tar_backup,
    delete_backup_record,
    list_backup_records,
    prune_historical_backups,
    restore_tar_archive,
    scan_import_backups,
)
from app.services.search_service import god_view_search_fts

router = APIRouter(prefix="/admin", tags=["Admin特权-上帝视角与TAR备份"])


# ==========================================
# 1. 上帝视角全库穿透检索 (ADR 0005 & ADR 0007)
# ==========================================

@router.get("/god-view/search", response_model=ApiResponse[List[GodViewItemOut]])
def god_view_search(
    q: str = Query(..., min_length=1, description="穿透检索公用/应急物品关键词"),
    limit: int = Query(50, ge=1, le=100, description="最大返回条目数"),
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    Admin 上帝视角全库穿透检索：
    紧急情况下跨所有家庭成员检索公用物品，透出物品归属成员、存放房屋与房间
    """
    results = god_view_search_fts(db=db, query_text=q, limit=limit)
    out_items: List[GodViewItemOut] = []
    for it, uname, unick in results:
        g_out = GodViewItemOut.model_validate(it)
        g_out.owner_username = uname
        g_out.owner_nickname = unick
        out_items.append(g_out)

    return ApiResponse(data=out_items)


@router.get("/god-view/items", response_model=ApiResponse[PaginatedData[GodViewItemOut]])
def god_view_items(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Admin 上帝视角全库物品总览与分页巡检"""
    skip = (page - 1) * page_size
    query = db.query(Item)
    total = query.count()
    items = (
        query.options(
            joinedload(Item.house),
            joinedload(Item.room),
            joinedload(Item.tags),
            joinedload(Item.attachments),
            joinedload(Item.owner),
        )
        .order_by(Item.updated_at.desc(), Item.id.desc())
        .offset(skip)
        .limit(page_size)
        .all()
    )

    out_items: List[GodViewItemOut] = []
    for it in items:
        g_out = GodViewItemOut.model_validate(it)
        g_out.owner_username = it.owner.username if it.owner else "未知"
        g_out.owner_nickname = it.owner.nickname if (it.owner and it.owner.nickname) else g_out.owner_username
        out_items.append(g_out)

    total_pages = math.ceil(total / page_size) if total > 0 else 0
    return ApiResponse(
        data=PaginatedData(
            items=out_items,
            pagination=PaginationMeta(
                page=page, page_size=page_size, total=total, total_pages=total_pages
            ),
        )
    )


# ==========================================
# 2. 零算力损耗纯 TAR 备份与管理 (ADR 0006)
# ==========================================

@router.get("/backups", response_model=ApiResponse[List[BackupRecordOut]])
def list_backups(
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取所有历史备份记录列表"""
    records = list_backup_records(db)
    return ApiResponse(data=[BackupRecordOut.model_validate(r) for r in records])


@router.post("/backups", response_model=ApiResponse[BackupRecordOut], status_code=status.HTTP_201_CREATED)
def create_backup(
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    Admin 手动一键触发生成 TAR 纯打包备份
    - VACUUM INTO 生成瞬时一致性 SQLite 镜像
    - 纯 .tar 流串联媒体分片，零 CPU 算力损耗
    """
    record = create_manual_tar_backup(db)
    return ApiResponse(data=BackupRecordOut.model_validate(record), message="TAR 备份包生成完毕")


@router.delete("/backups/{record_id}", response_model=ApiResponse[None])
def delete_backup(
    record_id: int,
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """删除指定的历史备份记录并清理本地磁盘 .tar 文件"""
    delete_backup_record(db, record_id)
    return ApiResponse(data=None, message="备份记录与归档文件已删除")


@router.post("/backups/prune", response_model=ApiResponse[int])
def prune_backups(
    payload: BackupPruneRequest,
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """淘汰清理过期的历史备份，防范磁盘膨胀"""
    deleted_count = prune_historical_backups(db, keep_latest=payload.keep_latest)
    return ApiResponse(data=deleted_count, message=f"已成功清理 {deleted_count} 份过期备份文件")


@router.get("/backups/{record_id}/download")
def download_backup(
    record_id: int,
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """下载指定的 TAR 备份文件"""
    record = db.query(BackupRecord).filter(BackupRecord.id == record_id).first()
    if not record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="备份记录不存在")

    tar_path = settings.MEDIA_BACKUPS_DIR / record.filename
    if not tar_path.exists():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="磁盘上的备份归档文件已遗失")

    return FileResponse(
        path=tar_path,
        media_type="application/x-tar",
        filename=record.filename,
    )


# ==========================================
# 3. 家庭成员账号治理与系统监控指标
# ==========================================

@router.get("/users", response_model=ApiResponse[List[AdminUserOut]])
def get_users_list(
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取所有家庭成员账号列表及资产统计"""
    users = list_admin_users(db)
    return ApiResponse(data=users)


@router.post("/users", response_model=ApiResponse[AdminUserOut], status_code=status.HTTP_201_CREATED)
def create_user(
    payload: AdminUserCreate,
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员受管开户并自动配置初始分类模板"""
    user = create_managed_user(db, payload)
    return ApiResponse(
        data=AdminUserOut(
            id=user.id,
            username=user.username,
            nickname=user.nickname,
            role=user.role,
            is_active=user.is_active,
            created_at=user.created_at,
            house_count=0,
            room_count=0,
            item_count=0,
        ),
        message="家庭成员账号已创建",
    )


@router.patch("/users/{user_id}/status", response_model=ApiResponse[AdminUserOut])
def toggle_user_status(
    user_id: int,
    payload: AdminUserStatusUpdate,
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """启用或冻结家庭成员账号"""
    user = update_user_active_status(
        db, user_id=user_id, is_active=payload.is_active, current_admin_id=admin_user.id
    )
    users = list_admin_users(db)
    target = next((u for u in users if u.id == user.id), None)
    return ApiResponse(
        data=target,
        message="账号状态已更新" if payload.is_active else "账号已冻结",
    )


@router.post("/users/{user_id}/reset-password", response_model=ApiResponse[None])
def reset_password(
    user_id: int,
    payload: AdminUserPasswordReset,
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员重置家庭成员密码"""
    reset_user_password(db, user_id=user_id, new_password=payload.new_password)
    return ApiResponse(data=None, message="密码重置成功")


@router.post("/users/{user_id}/init-password", response_model=ApiResponse[None])
def init_password(
    user_id: int,
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员一键初始化成员密码为默认 123456"""
    init_user_password(db, user_id=user_id)
    return ApiResponse(data=None, message="密码已恢复为默认初始密码 (123456)")



@router.get("/stats", response_model=ApiResponse[AdminSystemStats])
def get_stats(
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取系统运行指标与存储占用概览"""
    stats_data = get_system_stats(db)
    return ApiResponse(data=stats_data)


# ==========================================
# 4. 管理员改密与多维托底寻物 (严格只读)
# ==========================================

@router.put("/password", response_model=ApiResponse[None])
def admin_change_password(
    payload: AdminPasswordChange,
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员修改自己的登录口令"""
    change_admin_password(
        db, admin_id=admin_user.id, old_password=payload.old_password, new_password=payload.new_password
    )
    return ApiResponse(data=None, message="管理员密码已成功修改")


@router.get("/god-view/filter-options", response_model=ApiResponse[GodViewFilterOptions])
def get_filter_options(
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取多维组合寻物的级联筛选项 (严格只读)"""
    options = get_god_view_filter_options(db)
    return ApiResponse(data=options)


@router.get("/god-view/advanced-search", response_model=ApiResponse[PaginatedData[GodViewItemOut]])
def god_view_advanced_search_endpoint(
    user_id: Optional[int] = Query(None, description="成员ID"),
    house_id: Optional[int] = Query(None, description="房屋ID"),
    room_id: Optional[int] = Query(None, description="房间ID"),
    category_id: Optional[int] = Query(None, description="分类ID"),
    tag_name: Optional[str] = Query(None, description="标签名称"),
    keyword: Optional[str] = Query(None, description="关键词"),
    start_date: Optional[str] = Query(None, description="起始录入日期"),
    end_date: Optional[str] = Query(None, description="结束录入日期"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Admin 上帝视角多维组合托底寻物 (严格只读，支持级联筛选与分页)"""
    items, total = god_view_advanced_search(
        db,
        user_id=user_id,
        house_id=house_id,
        room_id=room_id,
        category_id=category_id,
        tag_name=tag_name,
        keyword=keyword,
        start_date=start_date,
        end_date=end_date,
        page=page,
        page_size=page_size,
    )
    out_items: List[GodViewItemOut] = []
    for it in items:
        g_out = GodViewItemOut.model_validate(it)
        g_out.owner_username = it.owner.username if it.owner else "未知"
        g_out.owner_nickname = it.owner.nickname if (it.owner and it.owner.nickname) else g_out.owner_username
        out_items.append(g_out)

    total_pages = math.ceil(total / page_size) if total > 0 else 0
    return ApiResponse(
        data=PaginatedData(
            items=out_items,
            pagination=PaginationMeta(page=page, page_size=page_size, total=total, total_pages=total_pages),
        )
    )


# ==========================================
# 5. 孤儿附件审计与清理
# ==========================================

@router.get("/media/orphans", response_model=ApiResponse[OrphanMediaStats])
def get_orphan_media(
    min_age_seconds: int = Query(3600, ge=0, description="孤儿文件保护期（秒），默认 3600s 防误删在编文件"),
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """扫描多媒体磁盘中的孤儿无引用文件"""
    stats = scan_orphan_media(db, min_age_seconds=min_age_seconds)
    return ApiResponse(data=stats)


@router.post("/media/orphans/clean", response_model=ApiResponse[dict])
def clean_orphans(
    min_age_seconds: int = Query(3600, ge=0, description="孤儿文件保护期（秒），默认 3600s 防误删在编文件"),
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """一键物理清理多媒体孤儿文件并释放磁盘"""
    cnt, bytes_freed = clean_orphan_media(db, min_age_seconds=min_age_seconds)
    return ApiResponse(
        data={"cleaned_count": cnt, "reclaimed_bytes": bytes_freed},
        message=f"已成功清理 {cnt} 份孤儿附件",
    )


@router.get("/media/soft-deleted", response_model=ApiResponse[SoftDeletedMediaStats])
def get_soft_deleted_media(
    older_than_days: int = Query(0, ge=0, description="仅统计软删除超过指定天数的物品，0 表示全部"),
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """统计已软删除物品及关联媒体文件占用"""
    stats = get_soft_deleted_media_stats(db, older_than_days=older_than_days)
    return ApiResponse(data=stats)


@router.post("/media/soft-deleted/purge", response_model=ApiResponse[dict])
def purge_soft_deleted(
    older_than_days: int = Query(0, ge=0, description="仅彻底清理软删除超过指定天数的物品，0 表示全部"),
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """彻底清理已软删除物品记录及物理附件释放磁盘空间"""
    purged_items, del_atts, bytes_freed = purge_soft_deleted_items(db, older_than_days=older_than_days)
    return ApiResponse(
        data={
            "purged_items": purged_items,
            "deleted_attachments": del_atts,
            "reclaimed_bytes": bytes_freed,
        },
        message=f"已彻底清理 {purged_items} 件已删除物品及 {del_atts} 份附件",
    )


# ==========================================
# 6. 三模 TAR 灾难恢复引擎
# ==========================================

@router.post("/backups/{record_id}/restore", response_model=ApiResponse[dict])
def restore_from_record(
    record_id: int,
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """从指定的历史备份快照恢复系统"""
    rec = db.query(BackupRecord).filter(BackupRecord.id == record_id).first()
    if not rec:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="备份记录不存在")
    tar_path = settings.MEDIA_BACKUPS_DIR / rec.filename
    result = restore_tar_archive(tar_path, db)
    return ApiResponse(data=result, message="灾难恢复成功")


@router.post("/backups/restore-upload", response_model=ApiResponse[dict])
async def restore_from_upload(
    file: UploadFile = File(...),
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """通过浏览器上传 TAR 备份归档文件恢复系统"""
    if not file.filename.endswith(".tar"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="仅支持 .tar 归档文件")
    temp_tar = settings.DATA_DIR / f"upload_restore_{file.filename}"
    try:
        with open(temp_tar, "wb") as f:
            while chunk := await file.read(1024 * 1024):
                f.write(chunk)
        result = restore_tar_archive(temp_tar, db)
        return ApiResponse(data=result, message="上传备份文件并恢复成功")
    finally:
        if temp_tar.exists():
            temp_tar.unlink()


@router.get("/backups/import-scan", response_model=ApiResponse[List[ImportedBackupRecord]])
def scan_imported_backups_endpoint(
    admin_user: User = Depends(get_current_admin),
):
    """扫描 /data/media/backups/import/ 目录下的外部上传 TAR 归档"""
    records = scan_import_backups()
    return ApiResponse(data=[ImportedBackupRecord(**r) for r in records])


@router.post("/backups/import-restore", response_model=ApiResponse[dict])
def restore_from_import_endpoint(
    payload: ImportRestoreRequest,
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """从服务器导入目录选定 TAR 文件执行灾难恢复"""
    tar_path = settings.MEDIA_BACKUPS_IMPORT_DIR / payload.filename
    result = restore_tar_archive(tar_path, db)
    return ApiResponse(data=result, message="从服务器导入目录恢复成功")



