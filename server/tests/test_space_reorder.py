import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker

from app.core.security import create_access_token, hash_password
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models.user import User


@pytest.fixture()
def isolated_client(tmp_path, monkeypatch):
    monkeypatch.setenv("DISABLE_MDNS", "1")
    db_file = tmp_path / "test_space_reorder.db"
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
        u1 = User(
            username="u1",
            nickname="用户一",
            password_hash=hash_password("123456"),
            role="user",
            is_active=True,
        )
        u2 = User(
            username="u2",
            nickname="用户二",
            password_hash=hash_password("123456"),
            role="user",
            is_active=True,
        )
        db.add_all([u1, u2])
        db.commit()
        db.refresh(u1)
        db.refresh(u2)
        u1_headers = {"Authorization": f"Bearer {create_access_token(str(u1.id))}"}
        u2_headers = {"Authorization": f"Bearer {create_access_token(str(u2.id))}"}

    app.dependency_overrides[get_db] = _override_get_db
    try:
        with TestClient(app) as client:
            yield client, u1_headers, u2_headers
    finally:
        app.dependency_overrides.clear()
        engine.dispose()


def test_house_and_room_reorder_and_default_append(isolated_client):
    client, u1_headers, u2_headers = isolated_client

    # 默认不传 sort_order (0) 时自动追加到末尾 1, 2, 3
    h1 = client.post("/api/houses", json={"name": "新家", "icon": "🏠"}, headers=u1_headers)
    h2 = client.post("/api/houses", json={"name": "老家", "icon": "🏡"}, headers=u1_headers)
    h3 = client.post("/api/houses", json={"name": "公寓", "icon": "🏢"}, headers=u1_headers)
    assert h1.status_code == 201
    assert h2.status_code == 201
    assert h3.status_code == 201
    h1_id, h2_id, h3_id = h1.json()["data"]["id"], h2.json()["data"]["id"], h3.json()["data"]["id"]
    assert [h1.json()["data"]["sort_order"], h2.json()["data"]["sort_order"], h3.json()["data"]["sort_order"]] == [1, 2, 3]

    # 房屋批量重排: [h3, h1, h2]
    res = client.put("/api/houses/reorder", json={"ordered_ids": [h3_id, h1_id, h2_id]}, headers=u1_headers)
    assert res.status_code == 200, res.text
    assert [h["id"] for h in res.json()["data"]] == [h3_id, h1_id, h2_id]
    assert [h["sort_order"] for h in res.json()["data"]] == [1, 2, 3]

    listed_houses = client.get("/api/houses", headers=u1_headers).json()["data"]
    assert [h["id"] for h in listed_houses] == [h3_id, h1_id, h2_id]

    # 在 h1 和 h2 下分别创建房间
    r1 = client.post("/api/rooms", json={"house_id": h1_id, "name": "客厅", "icon": "🛋️"}, headers=u1_headers).json()["data"]
    r2 = client.post("/api/rooms", json={"house_id": h1_id, "name": "书房", "icon": "📚"}, headers=u1_headers).json()["data"]
    r3 = client.post("/api/rooms", json={"house_id": h1_id, "name": "厨房", "icon": "🍳"}, headers=u1_headers).json()["data"]
    other_room = client.post("/api/rooms", json={"house_id": h2_id, "name": "院子", "icon": "🪴"}, headers=u1_headers).json()["data"]
    assert [r1["sort_order"], r2["sort_order"], r3["sort_order"]] == [1, 2, 3]

    # 房屋内房间重排: [r3, r1, r2]
    res = client.put(
        "/api/rooms/reorder",
        json={"house_id": h1_id, "ordered_ids": [r3["id"], r1["id"], r2["id"]]},
        headers=u1_headers,
    )
    assert res.status_code == 200, res.text
    assert [r["id"] for r in res.json()["data"]] == [r3["id"], r1["id"], r2["id"]]

    # 校验非法输入: 漏传、重复、跨房屋房间 ID、跨用户
    assert client.put("/api/houses/reorder", json={"ordered_ids": [h1_id, h2_id]}, headers=u1_headers).status_code == 400
    assert client.put("/api/houses/reorder", json={"ordered_ids": [h1_id, h1_id, h2_id]}, headers=u1_headers).status_code == 400
    assert client.put("/api/rooms/reorder", json={"house_id": h1_id, "ordered_ids": [r1["id"], r2["id"], other_room["id"]]}, headers=u1_headers).status_code == 400

    u2_house = client.post("/api/houses", json={"name": "他人房屋", "icon": "🏠"}, headers=u2_headers).json()["data"]
    assert client.put("/api/houses/reorder", json={"ordered_ids": [u2_house["id"], h1_id, h2_id]}, headers=u1_headers).status_code == 400
    assert client.put("/api/rooms/reorder", json={"house_id": u2_house["id"], "ordered_ids": [r1["id"]]}, headers=u1_headers).status_code == 404
