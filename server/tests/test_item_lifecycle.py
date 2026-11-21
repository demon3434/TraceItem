import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, text
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.core.security import create_access_token, hash_password
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models.space import House, Room
from app.models.user import User


@pytest.fixture()
def isolated_env(tmp_path, monkeypatch):
    monkeypatch.setenv("DISABLE_MDNS", "1")
    media_root = tmp_path / "media"
    media_root.mkdir(parents=True, exist_ok=True)
    monkeypatch.setattr(settings, "MEDIA_DIR", media_root)

    db_file = tmp_path / "test_item_lifecycle.db"
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
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                CREATE VIRTUAL TABLE IF NOT EXISTS items_fts USING fts5(
                    item_id UNINDEXED,
                    user_id UNINDEXED,
                    name,
                    brand,
                    location_detail,
                    description,
                    tokenize = 'unicode61'
                );
                """
            )
        )

    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    def _override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = _override_get_db
    db = TestingSessionLocal()
    user = User(
        username="lifecycle_user",
        nickname="测试用户",
        password_hash=hash_password("Pass1234!"),
        role="user",
    )
    db.add(user)
    db.flush()
    house = House(user_id=user.id, name="阳光城", icon="🏠")
    db.add(house)
    db.flush()
    storage_room = Room(user_id=user.id, house_id=house.id, name="储物间", icon="📦")
    living_room = Room(user_id=user.id, house_id=house.id, name="客厅", icon="🛋️")
    db.add_all([storage_room, living_room])
    db.commit()

    token = create_access_token(str(user.id), token_version=user.token_version)
    headers = {"Authorization": f"Bearer {token}"}

    try:
        yield TestClient(app), headers, house.id, storage_room.id, living_room.id, media_root
    finally:
        db.close()
        app.dependency_overrides.clear()


def _create_dummy_media(media_root: Path, rel_path: str) -> None:
    target = media_root / rel_path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(b"fake-image-bytes")


def test_take_out_requires_image_and_preserves_storage_snapshot(isolated_env):
    client, headers, house_id, storage_room_id, living_room_id, media_root = isolated_env
    storage_img = "images/2026/11/fan_box.jpg"
    in_use_img = "images/2026/11/fan_living.jpg"
    _create_dummy_media(media_root, storage_img)
    _create_dummy_media(media_root, in_use_img)

    res = client.post(
        "/api/items",
        headers=headers,
        json={
            "house_id": house_id,
            "room_id": storage_room_id,
            "name": "格力电风扇",
            "brand": "格力",
            "quantity": 1,
            "location_detail": "顶层蓝色收纳箱",
            "attachments": [{"media_type": "image", "file_path": storage_img}],
        },
    )
    assert res.status_code == 201
    item = res.json()["data"]
    assert item["status"] == "stored"
    assert len(item["attachments"]) == 1
    assert item["attachments"][0]["file_path"] == storage_img

    # 1. 取出时未传图片附件应被拒绝
    bad_take_out = client.post(
        f"/api/items/{item['id']}/take-out",
        headers=headers,
        json={
            "house_id": house_id,
            "room_id": living_room_id,
            "location_detail": "沙发旁",
            "attachments": [{"media_type": "audio", "file_path": "audios/2026/11/note.m4a"}],
        },
    )
    assert bad_take_out.status_code == 400

    # 2. 正常取出
    take_out_res = client.post(
        f"/api/items/{item['id']}/take-out",
        headers=headers,
        json={
            "house_id": house_id,
            "room_id": living_room_id,
            "location_detail": "电视柜旁",
            "attachments": [{"media_type": "image", "file_path": in_use_img}],
        },
    )
    assert take_out_res.status_code == 200
    out_item = take_out_res.json()["data"]
    assert out_item["status"] == "in_use"
    assert out_item["room_id"] == living_room_id
    assert out_item["storage_room_id"] == storage_room_id
    assert out_item["storage_location_detail"] == "顶层蓝色收纳箱"
    assert [a["file_path"] for a in out_item["attachments"]] == [in_use_img]
    assert [a["file_path"] for a in out_item["storage_attachments"]] == [storage_img]

    # 3. 按 status 筛选
    in_use_list = client.get("/api/items?status=in_use", headers=headers)
    assert in_use_list.status_code == 200
    assert len(in_use_list.json()["data"]["items"]) == 1
    stored_list = client.get("/api/items?status=stored", headers=headers)
    assert len(stored_list.json()["data"]["items"]) == 0

    # 4. 归还（原位放回），并验证 in_use 物理文件被清理，storage 文件保留
    put_back_res = client.post(
        f"/api/items/{item['id']}/put-back",
        headers=headers,
        json={"restore_original": True},
    )
    assert put_back_res.status_code == 200
    back_item = put_back_res.json()["data"]
    assert back_item["status"] == "stored"
    assert back_item["room_id"] == storage_room_id
    assert back_item["location_detail"] == "顶层蓝色收纳箱"
    assert [a["file_path"] for a in back_item["attachments"]] == [storage_img]
    assert not (media_root / in_use_img).exists()
    assert (media_root / storage_img).exists()


def test_consumable_quantity_allows_zero(isolated_env):
    client, headers, house_id, storage_room_id, _, _ = isolated_env
    res = client.post(
        "/api/items",
        headers=headers,
        json={
            "house_id": house_id,
            "room_id": storage_room_id,
            "name": "云南白药膏药",
            "quantity": 1,
        },
    )
    assert res.status_code == 201
    item_id = res.json()["data"]["id"]

    upd = client.put(
        f"/api/items/{item_id}",
        headers=headers,
        json={"quantity": 0},
    )
    assert upd.status_code == 200
    assert upd.json()["data"]["quantity"] == 0
