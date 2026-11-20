import sys
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
from app.models.space import House, Room
from app.models.user import User


@pytest.fixture()
def test_ctx(tmp_path, monkeypatch):
    monkeypatch.setenv("DISABLE_MDNS", "1")
    media_dir = tmp_path / "media"
    media_dir.mkdir(parents=True, exist_ok=True)
    monkeypatch.setattr(settings, "MEDIA_DIR", media_dir)

    db_file = tmp_path / "test_lock_media.db"
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
            username="alice",
            nickname="Alice",
            password_hash=hash_password("123456"),
            role="user",
            is_active=True,
        )
        db.add(u1)
        db.commit()
        db.refresh(u1)

        h1 = House(user_id=u1.id, name="测试家", icon="🏠", sort_order=1)
        db.add(h1)
        db.commit()
        db.refresh(h1)

        r1 = Room(user_id=u1.id, house_id=h1.id, name="客厅", icon="🛋️", sort_order=1)
        db.add(r1)
        db.commit()
        db.refresh(r1)

        token = create_access_token(subject=u1.id, role=u1.role)
        house_id = h1.id
        room_id = r1.id

    app.dependency_overrides[get_db] = _override_get_db
    try:
        with TestClient(app) as client:
            yield client, token, house_id, room_id, media_dir
    finally:
        app.dependency_overrides.clear()


def test_item_optimistic_locking_conflict(test_ctx):
    client, token, house_id, room_id, _ = test_ctx
    headers = {"Authorization": f"Bearer {token}"}

    # 1. 创建物品 -> 初始 version = 1
    res_create = client.post(
        "/api/items",
        json={
            "house_id": house_id,
            "room_id": room_id,
            "name": "乐高积木",
            "quantity": 1,
        },
        headers=headers,
    )
    assert res_create.status_code == 201
    created = res_create.json()["data"]
    assert created["version"] == 1
    item_id = created["id"]

    # 2. 设备 B 使用 expected_version=1 更新 -> 成功并升至 version=2
    res_update_b = client.put(
        f"/api/items/{item_id}",
        json={"name": "乐高太空站", "quantity": 2, "expected_version": 1},
        headers=headers,
    )
    assert res_update_b.status_code == 200
    assert res_update_b.json()["data"]["version"] == 2
    assert res_update_b.json()["data"]["name"] == "乐高太空站"

    # 3. 设备 A 仍携带旧 expected_version=1 提交 -> 返回 409 Conflict 且不覆盖
    res_update_a = client.put(
        f"/api/items/{item_id}",
        json={"name": "旧名称覆盖", "quantity": 99, "expected_version": 1},
        headers=headers,
    )
    assert res_update_a.status_code == 409

    res_get = client.get(f"/api/items/{item_id}", headers=headers)
    assert res_get.status_code == 200
    assert res_get.json()["data"]["name"] == "乐高太空站"
    assert res_get.json()["data"]["quantity"] == 2
    assert res_get.json()["data"]["version"] == 2


def test_media_endpoint_requires_auth(test_ctx):
    client, token, _, _, media_dir = test_ctx
    sample_dir = media_dir / "images" / "2026" / "11"
    sample_dir.mkdir(parents=True, exist_ok=True)
    sample_file = sample_dir / "sample.jpg"
    sample_file.write_bytes(b"\xff\xd8\xff\xe0test-jpeg")

    rel = "images/2026/11/sample.jpg"

    # 无 token -> 401
    res_no_auth = client.get(f"/api/media/file/{rel}")
    assert res_no_auth.status_code == 401

    # 无效 token -> 401
    res_bad_auth = client.get(
        f"/api/media/file/{rel}",
        headers={"Authorization": "Bearer invalid.jwt.token"},
    )
    assert res_bad_auth.status_code == 401

    # Header Bearer -> 200
    res_header_ok = client.get(
        f"/api/media/file/{rel}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_header_ok.status_code == 200
    assert res_header_ok.content == b"\xff\xd8\xff\xe0test-jpeg"

    # Query ?token= -> 200
    res_query_ok = client.get(f"/api/media/file/{rel}?token={token}")
    assert res_query_ok.status_code == 200
    assert res_query_ok.content == b"\xff\xd8\xff\xe0test-jpeg"


def test_create_item_idempotent_with_client_uuid(test_ctx):
    client, token, house_id, room_id, _ = test_ctx
    headers = {"Authorization": f"Bearer {token}"}
    body = {
        "house_id": house_id,
        "room_id": room_id,
        "name": "离线手电筒",
        "quantity": 1,
        "client_uuid": "offline-uuid-12345",
    }

    r1 = client.post("/api/items", json=body, headers=headers)
    assert r1.status_code == 201
    id1 = r1.json()["data"]["id"]

    # 弱网重试提交相同 client_uuid -> 返回同一条记录而不重复创建
    r2 = client.post("/api/items", json=body, headers=headers)
    assert r2.status_code == 201
    id2 = r2.json()["data"]["id"]
    assert id1 == id2


def test_field_level_three_way_merge_and_conflict(test_ctx):
    client, token, house_id, room_id, _ = test_ctx
    headers = {"Authorization": f"Bearer {token}"}

    r_create = client.post(
        "/api/items",
        json={"house_id": house_id, "room_id": room_id, "name": "露营灯", "quantity": 1},
        headers=headers,
    )
    assert r_create.status_code == 201
    item_id = r_create.json()["data"]["id"]

    # 设备 B 修改 name -> version=2 (field_versions["name"] = 2)
    r_b = client.put(
        f"/api/items/{item_id}",
        json={"name": "LED露营灯", "expected_version": 1},
        headers=headers,
    )
    assert r_b.status_code == 200
    assert r_b.json()["data"]["version"] == 2

    # 设备 A 离线仅修改不重叠的 quantity (expected_version=1) -> 自动三向合并成功 -> version=3
    r_a_merge = client.put(
        f"/api/items/{item_id}",
        json={
            "expected_version": 1,
            "changed_fields": {"quantity": 4},
            "client_op_uuid": "op-merge-1",
        },
        headers=headers,
    )
    assert r_a_merge.status_code == 200
    merged = r_a_merge.json()["data"]
    assert merged["version"] == 3
    assert merged["name"] == "LED露营灯"
    assert merged["quantity"] == 4

    # 幂等重试同一 client_op_uuid -> 不重复递增版本
    r_a_retry = client.put(
        f"/api/items/{item_id}",
        json={
            "expected_version": 1,
            "changed_fields": {"quantity": 4},
            "client_op_uuid": "op-merge-1",
        },
        headers=headers,
    )
    assert r_a_retry.status_code == 200
    assert r_a_retry.json()["data"]["version"] == 3

    # 设备 C 离线修改重叠字段 name (expected_version=1) -> 返回 409 + conflict_fields
    r_c_conflict = client.put(
        f"/api/items/{item_id}",
        json={
            "expected_version": 1,
            "changed_fields": {"name": "强光灯"},
            "client_op_uuid": "op-conflict-1",
        },
        headers=headers,
    )
    assert r_c_conflict.status_code == 409
    body_c = r_c_conflict.json()
    assert body_c["data"]["conflict_fields"] == ["name"]
    assert body_c["data"]["latest_item"]["name"] == "LED露营灯"


def test_offline_delete_version_guard_and_idempotency(test_ctx):
    client, token, house_id, room_id, _ = test_ctx
    headers = {"Authorization": f"Bearer {token}"}

    r_create = client.post(
        "/api/items",
        json={"house_id": house_id, "room_id": room_id, "name": "旧电池", "quantity": 2},
        headers=headers,
    )
    item_id = r_create.json()["data"]["id"]

    # 其他端先更新到 v2
    r_upd = client.put(
        f"/api/items/{item_id}",
        json={"quantity": 5, "expected_version": 1},
        headers=headers,
    )
    assert r_upd.status_code == 200

    # 离线携带旧版本 expected_version=1 删除 -> 409 拦截
    r_del_conflict = client.delete(
        f"/api/items/{item_id}?expected_version=1&client_op_uuid=del-op-1",
        headers=headers,
    )
    assert r_del_conflict.status_code == 409
    assert r_del_conflict.json()["data"]["conflict_fields"] == ["__delete__"]

    # 用户确认强制删除 -> 成功且幂等重试返回 200
    r_del_force = client.delete(
        f"/api/items/{item_id}?expected_version=1&force=true&client_op_uuid=del-op-1",
        headers=headers,
    )
    assert r_del_force.status_code == 200
    r_del_retry = client.delete(
        f"/api/items/{item_id}?expected_version=1&force=true&client_op_uuid=del-op-1",
        headers=headers,
    )
    assert r_del_retry.status_code == 200


def test_password_change_invalidates_existing_tokens(test_ctx):
    client, token, _, _, _ = test_ctx
    old_headers = {"Authorization": f"Bearer {token}"}

    # 旧 token 改密前可正常访问
    assert client.get("/api/auth/me", headers=old_headers).status_code == 200

    # 修改密码 -> token_version 递增，旧 token 立即返回 401
    r_pwd = client.put(
        "/api/auth/me",
        json={"password": "newpassword123"},
        headers=old_headers,
    )
    assert r_pwd.status_code == 200
    assert client.get("/api/auth/me", headers=old_headers).status_code == 401

    # 使用新密码重新登录 -> 获得新 token 可正常访问
    r_login = client.post(
        "/api/auth/login",
        json={"username": "alice", "password": "newpassword123"},
    )
    assert r_login.status_code == 200
    new_token = r_login.json()["data"]["access_token"]
    assert client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {new_token}"},
    ).status_code == 200

