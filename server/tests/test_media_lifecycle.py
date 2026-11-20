import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.core.security import create_access_token, hash_password
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models.attachment import Attachment
from app.models.item import Item
from app.models.space import House, Room
from app.models.user import User


@pytest.fixture()
def lifecycle_env(tmp_path, monkeypatch):
    monkeypatch.setenv("DISABLE_MDNS", "1")
    media_dir = tmp_path / "media"
    for sub in ["images", "audios", "videos", "thumbnails", "backups"]:
        (media_dir / sub).mkdir(parents=True, exist_ok=True)
    monkeypatch.setattr(settings, "MEDIA_DIR", media_dir)

    db_file = tmp_path / "test_media_lifecycle.db"
    engine = create_engine(
        f"sqlite:///{db_file}",
        connect_args={"check_same_thread": False},
    )

    @event.listens_for(engine, "connect")
    def _set_pragma(dbapi_conn, _):
        cur = dbapi_conn.cursor()
        cur.execute("PRAGMA foreign_keys = ON;")
        cur.execute("PRAGMA journal_mode = WAL;")
        cur.execute("PRAGMA synchronous = NORMAL;")
        cur.close()

    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    def _override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    with TestingSessionLocal() as db:
        admin = User(
            username="admin_test",
            nickname="管理员",
            password_hash=hash_password("123456"),
            role="admin",
            is_active=True,
        )
        member = User(
            username="member_test",
            nickname="成员",
            password_hash=hash_password("123456"),
            role="user",
            is_active=True,
        )
        db.add_all([admin, member])
        db.commit()
        db.refresh(admin)
        db.refresh(member)
        house = House(user_id=member.id, name="测试房屋", icon="🏠")
        db.add(house)
        db.commit()
        db.refresh(house)
        room = Room(user_id=member.id, house_id=house.id, name="客厅", icon="🛋️")
        db.add(room)
        db.commit()
        db.refresh(room)

        admin_headers = {"Authorization": f"Bearer {create_access_token(str(admin.id))}"}
        member_headers = {"Authorization": f"Bearer {create_access_token(str(member.id))}"}
        ids = {"member_id": member.id, "house_id": house.id, "room_id": room.id}

    app.dependency_overrides[get_db] = _override_get_db
    try:
        with TestClient(app) as client:
            yield client, TestingSessionLocal, media_dir, admin_headers, member_headers, ids
    finally:
        app.dependency_overrides.clear()
        engine.dispose()


def test_orphan_grace_period_protection(lifecycle_env):
    client, _, media_dir, admin_headers, _, _ = lifecycle_env
    sub = media_dir / "images" / "2026" / "11"
    sub.mkdir(parents=True, exist_ok=True)
    fresh = sub / "fresh.jpg"
    stale = sub / "stale.jpg"
    fresh.write_bytes(b"fresh-bytes")
    stale.write_bytes(b"stale-bytes")

    old_ts = time.time() - 7200
    os.utime(stale, (old_ts, old_ts))

    res = client.get("/api/admin/media/orphans", headers=admin_headers)
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["orphan_count"] == 1
    assert "images/2026/11/stale.jpg" in data["orphan_files"]

    clean_res = client.post("/api/admin/media/orphans/clean", headers=admin_headers)
    assert clean_res.status_code == 200
    assert clean_res.json()["data"]["cleaned_count"] == 1
    assert not stale.exists()
    assert fresh.exists()

    force_res = client.post(
        "/api/admin/media/orphans/clean?min_age_seconds=0",
        headers=admin_headers,
    )
    assert force_res.status_code == 200
    assert force_res.json()["data"]["cleaned_count"] == 1
    assert not fresh.exists()


def test_cleanup_temp_media_sandbox_and_zero_ref(lifecycle_env):
    client, SessionLocal, media_dir, _, member_headers, ids = lifecycle_env
    img_dir = media_dir / "images" / "2026" / "11"
    thumb_dir = media_dir / "thumbnails" / "images" / "2026" / "11"
    img_dir.mkdir(parents=True, exist_ok=True)
    thumb_dir.mkdir(parents=True, exist_ok=True)

    temp_img = img_dir / "temp1.jpg"
    temp_thumb = thumb_dir / "temp1_thumb.jpg"
    temp_img.write_bytes(b"temp")
    temp_thumb.write_bytes(b"temp-thumb")

    saved_img = img_dir / "saved.jpg"
    saved_thumb = thumb_dir / "saved_thumb.jpg"
    saved_img.write_bytes(b"saved")
    saved_thumb.write_bytes(b"saved-thumb")

    backup_file = media_dir / "backups" / "keep.tar"
    backup_file.write_bytes(b"backup")
    outside_file = media_dir.parent / "outside.txt"
    outside_file.write_text("keep", encoding="utf-8")

    with SessionLocal() as db:
        item = Item(
            user_id=ids["member_id"],
            house_id=ids["house_id"],
            room_id=ids["room_id"],
            name="已保存物品",
        )
        db.add(item)
        db.commit()
        db.refresh(item)
        db.add(
            Attachment(
                item_id=item.id,
                media_type="image",
                file_path="images/2026/11/saved.jpg",
                thumbnail_path="thumbnails/images/2026/11/saved_thumb.jpg",
                file_size=5,
            )
        )
        db.commit()

    res = client.post(
        "/api/media/cleanup-temp",
        headers=member_headers,
        json={
            "items": [
                {
                    "file_path": "/api/media/file/images/2026/11/temp1.jpg",
                    "thumbnail_path": "thumbnails/images/2026/11/temp1_thumb.jpg",
                },
                {
                    "file_path": "images/2026/11/saved.jpg",
                    "thumbnail_path": "thumbnails/images/2026/11/saved_thumb.jpg",
                },
                {"file_path": "backups/keep.tar"},
                {"file_path": "../../outside.txt"},
            ]
        },
    )
    assert res.status_code == 200
    assert res.json()["data"]["cleaned_count"] == 1
    assert not temp_img.exists()
    assert not temp_thumb.exists()
    assert saved_img.exists()
    assert saved_thumb.exists()
    assert backup_file.exists()
    assert outside_file.exists()


def test_soft_deleted_item_media_audit_and_purge(lifecycle_env):
    client, SessionLocal, media_dir, admin_headers, _, ids = lifecycle_env
    img_dir = media_dir / "images" / "2026" / "11"
    thumb_dir = media_dir / "thumbnails" / "images" / "2026" / "11"
    img_dir.mkdir(parents=True, exist_ok=True)
    thumb_dir.mkdir(parents=True, exist_ok=True)

    soft_img = img_dir / "soft.jpg"
    soft_thumb = thumb_dir / "soft_thumb.jpg"
    soft_img.write_bytes(b"0123456789")
    soft_thumb.write_bytes(b"01234")

    with SessionLocal() as db:
        item = Item(
            user_id=ids["member_id"],
            house_id=ids["house_id"],
            room_id=ids["room_id"],
            name="已删除物品",
            is_deleted=True,
        )
        db.add(item)
        db.commit()
        db.refresh(item)
        db.add(
            Attachment(
                item_id=item.id,
                media_type="image",
                file_path="images/2026/11/soft.jpg",
                thumbnail_path="thumbnails/images/2026/11/soft_thumb.jpg",
                file_size=10,
            )
        )
        db.commit()

    stats_res = client.get("/api/admin/media/soft-deleted", headers=admin_headers)
    assert stats_res.status_code == 200
    stats = stats_res.json()["data"]
    assert stats["deleted_item_count"] == 1
    assert stats["attachment_count"] == 1
    assert stats["total_size_bytes"] == 15

    purge_res = client.post("/api/admin/media/soft-deleted/purge", headers=admin_headers)
    assert purge_res.status_code == 200
    purged = purge_res.json()["data"]
    assert purged["purged_items"] == 1
    assert purged["deleted_attachments"] == 1
    assert purged["reclaimed_bytes"] == 15
    assert not soft_img.exists()
    assert not soft_thumb.exists()

    with SessionLocal() as db:
        assert db.query(Item).filter(Item.is_deleted == True).count() == 0
        assert db.query(Attachment).count() == 0

