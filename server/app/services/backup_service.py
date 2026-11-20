import hashlib
import io
import json
import os
import shutil
import tarfile
import threading
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Tuple
from fastapi import HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import engine
from app.models.backup import BackupRecord
from app.models.item import Item
from app.models.attachment import Attachment

# 并发备份互斥锁 (防范同时重复提交)
_backup_lock = threading.Lock()


def format_bytes(size: int) -> str:
    """人类可读的文件大小格式化"""
    for unit in ["B", "KB", "MB", "GB"]:
        if size < 1024.0:
            return f"{size:.2f} {unit}"
        size /= 1024.0
    return f"{size:.2f} TB"


def create_manual_tar_backup(db: Session) -> BackupRecord:
    """
    Admin 手动一键生成无压缩纯 TAR 备份包 (ADR 0006)
    1. 获取并发互斥锁，防范重复点击
    2. 执行 VACUUM INTO 生成瞬时一致性 SQLite 快照
    3. 将快照 items.db、manifest.json 与 media/ 媒体文件写入纯 .tar 流 (零压缩，零 CPU 算力损耗)
    4. 记录到 backup_records 并返回
    """
    if not _backup_lock.acquire(blocking=False):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="已有备份打包任务正在后台进行中，请勿重复提交",
        )

    now = datetime.now()
    timestamp_str = now.strftime("%Y%m%d_%H%M%S")
    backup_filename = f"backup_{timestamp_str}.tar"
    backup_tar_path = settings.MEDIA_BACKUPS_DIR / backup_filename
    temp_db_snapshot = settings.DATA_DIR / f"temp_snapshot_{timestamp_str}.db"

    try:
        # 1. 生成 SQLite 一致性快照到临时文件
        if temp_db_snapshot.exists():
            temp_db_snapshot.unlink()

        # VACUUM INTO 要求路径安全转义
        safe_snapshot_path = str(temp_db_snapshot).replace("'", "''")
        db.execute(text(f"VACUUM INTO '{safe_snapshot_path}';"))

        # 2. 统计物品与附件总数，准备内部时间戳与数据版本清单
        item_count = db.query(Item).count()
        attachment_count = db.query(Attachment).count()

        # 标准内部元数据与版本时间戳 (独立于文件名，作为还原校验依据)
        version_data = {
            "app_name": "物迹",
            "app_version": settings.VERSION,
            "schema_version": "1.0",
            "backup_time": now.isoformat(),
            "timestamp": int(now.timestamp()),
            "item_count": item_count,
            "attachment_count": attachment_count,
            "database_file": "items.db",
            "format": "tar (uncompressed)",
        }
        version_bytes = json.dumps(version_data, ensure_ascii=False, indent=2).encode("utf-8")

        # 向下兼容 manifest.json
        manifest_data = {
            "app_name": "物迹",
            "version": settings.VERSION,
            "backup_at": now.isoformat(),
            "timestamp": int(now.timestamp()),
            "item_count": item_count,
            "attachment_count": attachment_count,
            "format": "tar (uncompressed)",
        }
        manifest_bytes = json.dumps(manifest_data, ensure_ascii=False, indent=2).encode("utf-8")

        # 3. 极速纯 TAR 打包 (无压缩，零 CPU 消耗，适合低功耗设备)
        with tarfile.open(backup_tar_path, "w") as tar:
            # 写入核心时间戳与数据版本文件 version.json
            tarinfo_version = tarfile.TarInfo(name="version.json")
            tarinfo_version.size = len(version_bytes)
            tarinfo_version.mtime = int(now.timestamp())
            tar.addfile(tarinfo_version, io.BytesIO(version_bytes))

            # 兼容写入 manifest.json
            tarinfo_manifest = tarfile.TarInfo(name="manifest.json")
            tarinfo_manifest.size = len(manifest_bytes)
            tarinfo_manifest.mtime = int(now.timestamp())
            tar.addfile(tarinfo_manifest, io.BytesIO(manifest_bytes))

            # 加入数据库快照 items.db
            tar.add(temp_db_snapshot, arcname="items.db")

            # 加入多媒体物理文件 (排除 backups 目录自身)
            for sub_dir in ["images", "audios", "videos", "thumbnails"]:
                dir_path = settings.MEDIA_DIR / sub_dir
                if dir_path.exists():
                    tar.add(dir_path, arcname=f"media/{sub_dir}")

        # 4. 计算 SHA256 校验哈希与文件大小
        sha256_hash = hashlib.sha256()
        with open(backup_tar_path, "rb") as f:
            while chunk := f.read(1024 * 1024):
                sha256_hash.update(chunk)
        file_sha256 = sha256_hash.hexdigest()
        file_size = os.path.getsize(backup_tar_path)

        # 5. 持久化记录
        record = BackupRecord(
            filename=backup_filename,
            file_size=file_size,
            sha256=file_sha256,
            item_count=item_count,
            attachment_count=attachment_count,
            created_at=now,
        )
        db.add(record)
        db.commit()
        db.refresh(record)
        return record
    finally:
        if temp_db_snapshot.exists():
            try:
                temp_db_snapshot.unlink()
            except Exception:
                pass
        _backup_lock.release()


def list_backup_records(db: Session) -> List[BackupRecord]:
    """
    获取所有历史备份记录列表并与磁盘上的物理 .tar 文件保持实时同步：
    1. 扫描 /data/media/backups/ 物理目录
    2. 若磁盘存在但 DB 缺失（如数据库被恢复回档后），自动读取包内 version.json/manifest.json 补全
    3. 淘汰 DB 中指向已不存在磁盘物理文件的幻影记录
    4. 严格按照备份生成时间倒序排列 (确保最新的备份包恒定展示在第一行)
    """
    settings.MEDIA_BACKUPS_DIR.mkdir(parents=True, exist_ok=True)
    existing_tars = {
        p.name: p for p in settings.MEDIA_BACKUPS_DIR.iterdir()
        if p.is_file() and p.name.endswith(".tar")
    }

    db_records = db.query(BackupRecord).all()
    db_record_map = {r.filename: r for r in db_records}

    # 1. 清理数据库中物理文件已被删除的残留记录
    for r in db_records:
        if r.filename not in existing_tars:
            db.delete(r)

    # 2. 对磁盘上存在但数据库缺失的 tar 文件（如数据库被恢复回档后），自动读取内部时间戳文件补入
    for fname, tar_path in existing_tars.items():
        if fname not in db_record_map:
            try:
                meta = validate_tar_archive(tar_path)
                f_size = tar_path.stat().st_size
                backup_at_str = meta.get("backup_time") or meta.get("backup_at")
                if backup_at_str:
                    try:
                        c_at = datetime.fromisoformat(backup_at_str)
                        if c_at.tzinfo is not None:
                            c_at = c_at.astimezone().replace(tzinfo=None)
                    except Exception:
                        c_at = datetime.fromtimestamp(tar_path.stat().st_mtime)
                elif meta.get("timestamp"):
                    c_at = datetime.fromtimestamp(meta["timestamp"])
                else:
                    c_at = datetime.fromtimestamp(tar_path.stat().st_mtime)

                new_rec = BackupRecord(
                    filename=fname,
                    file_size=f_size,
                    sha256="",
                    item_count=meta.get("item_count") or 0,
                    attachment_count=meta.get("attachment_count") or 0,
                    created_at=c_at,
                )
                db.add(new_rec)
            except Exception:
                pass

    db.commit()
    return db.query(BackupRecord).order_by(BackupRecord.created_at.desc(), BackupRecord.id.desc()).all()


def delete_backup_record(db: Session, record_id: int) -> bool:
    """删除指定的历史备份记录并清理磁盘上的 .tar 文件"""
    record = db.query(BackupRecord).filter(BackupRecord.id == record_id).first()
    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="指定的备份记录不存在"
        )
    # 删除磁盘物理文件
    tar_path = settings.MEDIA_BACKUPS_DIR / record.filename
    if tar_path.exists():
        try:
            tar_path.unlink()
        except Exception:
            pass

    db.delete(record)
    db.commit()
    return True


def prune_historical_backups(db: Session, keep_latest: int = 3) -> int:
    """清理历史过期备份，仅保留最新的 N 份 (ADR 0006 防止磁盘膨胀，默认 3 份)"""
    records = db.query(BackupRecord).order_by(BackupRecord.created_at.desc(), BackupRecord.id.desc()).all()
    if len(records) <= keep_latest:
        return 0

    to_delete = records[keep_latest:]
    deleted_count = 0
    for rec in to_delete:
        tar_path = settings.MEDIA_BACKUPS_DIR / rec.filename
        if tar_path.exists():
            try:
                tar_path.unlink()
            except Exception:
                pass
        db.delete(rec)
        deleted_count += 1

    db.commit()
    return deleted_count


# ==========================================
# TAR 恢复引擎与外部导入支持 (平实命名与兼容解耦)
# ==========================================

def validate_tar_archive(tar_path: Path) -> Dict[str, Any]:
    """校验 TAR 归档包的合法性，返回内部时间戳与数据版本元数据 (兼容 items.db 与旧版 antusuoji.db)"""
    if not tar_path.exists():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="备份文件不存在")
    if not tarfile.is_tarfile(tar_path):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="文件不是有效的 TAR 归档包")

    with tarfile.open(tar_path, "r") as tar:
        names = tar.getnames()
        has_db = any(n in names for n in ["items.db", "./items.db", "antusuoji.db", "./antusuoji.db"])
        if not has_db:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="TAR 包内未找到核心数据库快照 (items.db)，判定为非法归档"
            )

        metadata: Dict[str, Any] = {}
        # 依次加载 manifest.json 与专门的 version.json
        for m_name in ["manifest.json", "./manifest.json", "version.json", "./version.json"]:
            if m_name in names:
                f = tar.extractfile(m_name)
                if f:
                    try:
                        data = json.loads(f.read().decode("utf-8"))
                        metadata.update(data)
                    except Exception:
                        pass
        return metadata


def restore_tar_archive(tar_path: Path, db: Session) -> Dict[str, Any]:
    """
    执行 TAR 恢复：
    1. 校验 TAR 结构与核心数据库 (兼容 items.db 与 antusuoji.db)
    2. 产生当前状态的安全防护快照
    3. 利用 SQLite Online Backup API 安全热替换当前数据库 (零文件锁冲突)
    4. 解压并覆盖多媒体文件 media/
    5. 重建 FTS5 虚拟索引并校验完整性
    """
    import sqlite3
    manifest = validate_tar_archive(tar_path)

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    safety_bak = settings.DATA_DIR / f"pre_restore_{ts}.db"
    temp_extract_db = settings.DATA_DIR / f"temp_extract_{ts}.db"

    try:
        # 1. 解压数据库到临时文件 (优先 items.db，向下兼容 antusuoji.db)
        with tarfile.open(tar_path, "r") as tar:
            db_member = None
            for cand in ["items.db", "./items.db", "antusuoji.db", "./antusuoji.db"]:
                try:
                    db_member = tar.getmember(cand)
                    break
                except KeyError:
                    pass
            if not db_member:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="TAR 包中未找到核心数据库文件"
                )

            with tar.extractfile(db_member) as src, open(temp_extract_db, "wb") as dst:
                shutil.copyfileobj(src, dst)

        # 2. 产生安全快照并利用 SQLite Backup API 安全注入
        if settings.DB_PATH.exists():
            with closing(sqlite3.connect(settings.DB_PATH)) as cur_conn, closing(sqlite3.connect(safety_bak)) as bak_conn:
                cur_conn.backup(bak_conn)

        # 恢复数据库: 从临时解压 db 写入目标 items.db
        with closing(sqlite3.connect(temp_extract_db)) as src_conn, closing(sqlite3.connect(settings.DB_PATH)) as dst_conn:
            src_conn.backup(dst_conn)

        # 3. 解压 media 附件目录
        with tarfile.open(tar_path, "r") as tar:
            for member in tar.getmembers():
                m_name = member.name.lstrip("./")
                if m_name.startswith("media/"):
                    rel_path = m_name[len("media/"):]
                    if not rel_path:
                        continue
                    target_path = settings.MEDIA_DIR / rel_path
                    if member.isdir():
                        target_path.mkdir(parents=True, exist_ok=True)
                    elif member.isfile():
                        target_path.parent.mkdir(parents=True, exist_ok=True)
                        with tar.extractfile(member) as src, open(target_path, "wb") as dst:
                            shutil.copyfileobj(src, dst)

    finally:
        if temp_extract_db.exists():
            try:
                temp_extract_db.unlink()
            except Exception:
                pass

    # 4. 重建 FTS5 与表结构检查
    from app.db.init_db import init_db
    init_db()

    with engine.begin() as conn:
        try:
            conn.execute(text("INSERT INTO items_fts(items_fts) VALUES('rebuild');"))
        except Exception:
            pass

    return {
        "status": "success",
        "message": "TAR 备份数据恢复完毕，FTS5 全文索引已重新构建",
        "safety_backup": str(safety_bak.name),
        "manifest": manifest,
    }


def scan_import_backups() -> List[Dict[str, Any]]:
    """扫描服务器指定导入目录 /data/media/backups/import/ 下的 TAR 归档"""
    import_dir = settings.MEDIA_BACKUPS_IMPORT_DIR
    import_dir.mkdir(parents=True, exist_ok=True)
    results = []
    for entry in import_dir.iterdir():
        if entry.is_file() and entry.name.endswith(".tar"):
            size = entry.stat().st_size
            size_display = format_bytes(size)
            try:
                manifest = validate_tar_archive(entry)
                results.append({
                    "filename": entry.name,
                    "file_size": size,
                    "file_size_display": size_display,
                    "is_valid": True,
                    "backup_at": manifest.get("backup_at"),
                    "item_count": manifest.get("item_count"),
                    "attachment_count": manifest.get("attachment_count"),
                    "error_message": None,
                })
            except Exception as e:
                err_msg = getattr(e, "detail", str(e))
                results.append({
                    "filename": entry.name,
                    "file_size": size,
                    "file_size_display": size_display,
                    "is_valid": False,
                    "backup_at": None,
                    "item_count": None,
                    "attachment_count": None,
                    "error_message": err_msg,
                })
    return sorted(results, key=lambda x: x["filename"], reverse=True)
