import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, text
from sqlalchemy.orm import sessionmaker

from app.core.security import create_access_token, hash_password
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models.user import User


@pytest.fixture()
def isolated_client(tmp_path, monkeypatch):
    monkeypatch.setenv("DISABLE_MDNS", "1")
    db_file = tmp_path / "test_space_lifecycle.db"
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

    with TestingSessionLocal() as db:
        u1 = User(
            username="u1",
            nickname="测试成员",
            password_hash=hash_password("123456"),
            role="user",
            is_active=True,
        )
        db.add(u1)
        db.commit()
        db.refresh(u1)
        headers = {"Authorization": f"Bearer {create_access_token(str(u1.id))}"}

    app.dependency_overrides[get_db] = _override_get_db
    try:
        with TestClient(app) as client:
            yield client, headers
    finally:
        app.dependency_overrides.clear()
        engine.dispose()


def test_delete_non_empty_room_and_house_blocked(isolated_client):
    client, headers = isolated_client

    h_id = client.post("/api/houses", json={"name": "新家", "icon": "🏠"}, headers=headers).json()["data"]["id"]
    r1_id = client.post("/api/rooms", json={"house_id": h_id, "name": "客厅", "icon": "🛋️"}, headers=headers).json()["data"]["id"]
    r2_id = client.post("/api/rooms", json={"house_id": h_id, "name": "书房", "icon": "📚"}, headers=headers).json()["data"]["id"]

    item_res = client.post(
        "/api/items",
        json={"house_id": h_id, "room_id": r1_id, "name": "手电筒", "quantity": 1},
        headers=headers,
    )
    assert item_res.status_code == 201
    item_id = item_res.json()["data"]["id"]

    # 房间内有物品 -> 禁止删除房间
    del_r1 = client.delete(f"/api/rooms/{r1_id}", headers=headers)
    assert del_r1.status_code == 400
    assert "1 件物品" in del_r1.json().get("message", del_r1.json().get("detail", ""))

    # 房屋内有物品 -> 禁止删除房屋
    del_h = client.delete(f"/api/houses/{h_id}", headers=headers)
    assert del_h.status_code == 400
    assert "1 件物品" in del_h.json().get("message", del_h.json().get("detail", ""))

    # 删除物品后，允许删除 r1，也允许删除仅剩空房间 r2 的房屋
    assert client.delete(f"/api/items/{item_id}", headers=headers).status_code == 200
    assert client.delete(f"/api/rooms/{r1_id}", headers=headers).status_code == 200
    assert client.delete(f"/api/houses/{h_id}", headers=headers).status_code == 200

    # 房屋删除后 r2 也被连带软删除
    rooms = client.get("/api/rooms", headers=headers).json()["data"]
    assert rooms == []


def test_space_is_active_inheritance_and_write_guards(isolated_client):
    client, headers = isolated_client

    h_id = client.post("/api/houses", json={"name": "老宅", "icon": "🏡"}, headers=headers).json()["data"]["id"]
    r_active_id = client.post("/api/rooms", json={"house_id": h_id, "name": "卧室", "icon": "🛏️"}, headers=headers).json()["data"]["id"]
    r_paused_id = client.post("/api/rooms", json={"house_id": h_id, "name": "储藏间", "icon": "📦"}, headers=headers).json()["data"]["id"]

    # 在启用房间创建一件历史物品
    item_id = client.post(
        "/api/items",
        json={"house_id": h_id, "room_id": r_active_id, "name": "旧相册", "quantity": 1},
        headers=headers,
    ).json()["data"]["id"]

    # 单独停用储藏间
    t_room = client.patch(f"/api/rooms/{r_paused_id}/status?is_active=false", headers=headers)
    assert t_room.status_code == 200
    assert t_room.json()["data"]["is_active"] is False

    # 停用整个老宅（不应篡改卧室原有的 is_active=True）
    t_house = client.patch(f"/api/houses/{h_id}/status?is_active=false", headers=headers)
    assert t_house.status_code == 200
    assert t_house.json()["data"]["is_active"] is False

    # 1) 禁止在停用房屋下新建房间
    bad_room = client.post("/api/rooms", json={"house_id": h_id, "name": "阁楼", "icon": "🪜"}, headers=headers)
    assert bad_room.status_code == 400
    assert "停用" in bad_room.json().get("message", bad_room.json().get("detail", ""))

    # 2) 禁止在停用房屋的房间下新建物品
    bad_item = client.post(
        "/api/items",
        json={"house_id": h_id, "room_id": r_active_id, "name": "新物品", "quantity": 1},
        headers=headers,
    )
    assert bad_item.status_code == 400
    assert "停用" in bad_item.json().get("message", bad_item.json().get("detail", ""))

    # 3) 编辑位于停用空间中的历史物品（不改位置）应当成功
    ok_edit = client.put(
        f"/api/items/{item_id}",
        json={"name": "旧相册(1998)", "description": "珍贵回忆"},
        headers=headers,
    )
    assert ok_edit.status_code == 200
    assert ok_edit.json()["data"]["name"] == "旧相册(1998)"

    # 4) 尝试把物品移动到停用房间应当被拦截
    bad_move = client.put(
        f"/api/items/{item_id}",
        json={"house_id": h_id, "room_id": r_paused_id},
        headers=headers,
    )
    assert bad_move.status_code == 400

    # 5) 重新启用老宅后，卧室仍为启用，储藏间仍保持停用
    assert client.patch(f"/api/houses/{h_id}/status?is_active=true", headers=headers).status_code == 200
    rooms = {r["id"]: r["is_active"] for r in client.get(f"/api/rooms?house_id={h_id}", headers=headers).json()["data"]}
    assert rooms[r_active_id] is True
    assert rooms[r_paused_id] is False
