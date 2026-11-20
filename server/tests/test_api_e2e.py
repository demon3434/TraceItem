import atexit
import os
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
os.environ.setdefault("DISABLE_MDNS", "1")

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker

import app.db.init_db as init_db_module
import app.db.session as session_module
from app.core.config import settings
from app.db.init_db import init_db
from app.db.session import get_db
from app.main import app

_orig_data_dir = settings.DATA_DIR
_orig_media_dir = settings.MEDIA_DIR
_orig_engine = session_module.engine
_orig_session_local = session_module.SessionLocal
_orig_init_engine = init_db_module.engine
_orig_init_session_local = init_db_module.SessionLocal

_tmp_dir = Path(tempfile.mkdtemp(prefix="traceitem_e2e_"))
settings.DATA_DIR = _tmp_dir / "data"
settings.MEDIA_DIR = settings.DATA_DIR / "media"
settings.ensure_directories()

_test_engine = create_engine(
    settings.SQLITE_URL,
    connect_args={"check_same_thread": False, "timeout": 30.0},
)


@event.listens_for(_test_engine, "connect")
def _set_test_sqlite_pragma(dbapi_connection, _):
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys = ON;")
    cursor.execute("PRAGMA journal_mode = WAL;")
    cursor.execute("PRAGMA synchronous = NORMAL;")
    cursor.execute("PRAGMA busy_timeout = 30000;")
    cursor.close()


_TestSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=_test_engine)

session_module.engine = _test_engine
session_module.SessionLocal = _TestSessionLocal
init_db_module.engine = _test_engine
init_db_module.SessionLocal = _TestSessionLocal


def _override_get_db():
    db = _TestSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = _override_get_db


def _cleanup_e2e_env():
    app.dependency_overrides.pop(get_db, None)
    session_module.engine = _orig_engine
    session_module.SessionLocal = _orig_session_local
    init_db_module.engine = _orig_init_engine
    init_db_module.SessionLocal = _orig_init_session_local
    settings.DATA_DIR = _orig_data_dir
    settings.MEDIA_DIR = _orig_media_dir
    _test_engine.dispose()
    shutil.rmtree(_tmp_dir, ignore_errors=True)


atexit.register(_cleanup_e2e_env)

print("=== Running End-to-End Server Verification (Isolated Temp DB) ===")
init_db()
client = TestClient(app)

# 1. Health check
res = client.get("/health")
assert res.status_code == 200, res.text
assert res.json()["data"]["status"] == "online"
print("✓ Health check passed")

# 2. Admin login
res = client.post("/api/auth/login", json={"username": "admin", "password": "admin123"})
assert res.status_code == 200, res.text
admin_token = res.json()["data"]["access_token"]
admin_headers = {"Authorization": f"Bearer {admin_token}"}
print("✓ Admin login passed")

# 2b. Verify Admin cannot create house or item (system administrator role boundary)
res = client.post("/api/houses", json={"name": "管理员违规空间", "icon": "🏠"}, headers=admin_headers)
assert res.status_code == 403, res.text
res = client.post("/api/items", json={"name": "管理员违规物品", "house_id": 1, "room_id": 1, "quantity": 1}, headers=admin_headers)
assert res.status_code == 403, res.text
print("✓ Admin strict role boundary passed: Admin cannot generate private houses or items")

# 3. Register & Login regular user
res = client.post("/api/auth/register", json={"username": "alice", "password": "123456", "nickname": "爱丽丝"})
if res.status_code != 200:
    assert "已被注册" in res.json().get("message", "")
res = client.post("/api/auth/login", json={"username": "alice", "password": "123456"})
assert res.status_code == 200, res.text
alice_token = res.json()["data"]["access_token"]
alice_headers = {"Authorization": f"Bearer {alice_token}"}
print("✓ Alice register & login passed")

# 4. Create House
res = client.post("/api/houses", json={"name": "阳光城自己家", "icon": "🏠", "sort_order": 1}, headers=alice_headers)
if res.status_code != 201:
    assert "您已创建过" in res.json().get("message", "")
    res = client.get("/api/houses", headers=alice_headers)
    house_id = res.json()["data"][0]["id"]
else:
    house_id = res.json()["data"]["id"]
print(f"✓ House created with id={house_id}")

# 5. Create Rooms
res = client.post("/api/rooms", json={"house_id": house_id, "name": "大客厅", "icon": "🛋️", "sort_order": 1}, headers=alice_headers)
if res.status_code != 201:
    res = client.get(f"/api/rooms?house_id={house_id}", headers=alice_headers)
    room_id = res.json()["data"][0]["id"]
else:
    room_id = res.json()["data"]["id"]
print(f"✓ Room created with id={room_id}")

# 6. Create Category
res = client.post("/api/items/categories", json={"name": "常备药品", "icon": "💊"}, headers=alice_headers)
cat_id = res.json()["data"]["id"]
print(f"✓ Category created with id={cat_id}")

# 6b. Verify Paginated Categories
res = client.get("/api/items/categories/paginated?page=1&page_size=5", headers=alice_headers)
assert res.status_code == 200, res.text
page_data = res.json()["data"]
assert "pagination" in page_data
assert page_data["pagination"]["page"] == 1
assert page_data["pagination"]["page_size"] == 5
assert page_data["pagination"]["total"] >= 1
print(f"✓ Paginated categories passed: page 1 of {page_data['pagination']['total_pages']}, total {page_data['pagination']['total']}")

# 7. Create Item
res = client.post(
    "/api/items",
    json={
        "house_id": house_id,
        "room_id": room_id,
        "category_id": cat_id,
        "name": "感冒灵颗粒",
        "brand": "999",
        "quantity": 3,
        "location_detail": "电视柜左侧抽屉",
        "description": "家庭应急感冒药",
        "tag_names": ["常备", "应急"],
        "attachments": [],
    },
    headers=alice_headers,
)
assert res.status_code == 201, res.text
item_id = res.json()["data"]["id"]
assert res.json()["data"]["path_display"] == "阳光城自己家 > 大客厅"
print(f"✓ Item created with id={item_id}, path_display='{res.json()['data']['path_display']}'")

# 8. User private FTS5 Search
res = client.get("/api/search?q=感冒灵", headers=alice_headers)
assert res.status_code == 200, res.text
items = res.json()["data"]
assert len(items) >= 1
assert items[0]["name"] == "感冒灵颗粒"
print("✓ Alice private FTS5 search passed")

# 9. Admin God-View Search
res = client.get("/api/admin/god-view/search?q=感冒灵", headers=admin_headers)
assert res.status_code == 200, res.text
god_items = res.json()["data"]
assert len(god_items) >= 1
assert god_items[0]["owner_username"] == "alice"
assert god_items[0]["owner_nickname"] == "爱丽丝"
print(f"✓ Admin God-View search passed: item owned by {god_items[0]['owner_username']} ({god_items[0]['owner_nickname']})")

# 10. Admin TAR Backup
res = client.post("/api/admin/backups", headers=admin_headers)
assert res.status_code == 201, res.text
backup_record = res.json()["data"]
print(f"✓ Admin TAR backup created: {backup_record['filename']}, size={backup_record['file_size_display']}")

# 11. List Backups
res = client.get("/api/admin/backups", headers=admin_headers)
assert res.status_code == 200, res.text
backups = res.json()["data"]
assert len(backups) >= 1
print("✓ Admin list backups passed")

# 12. Admin List Users and Stats
res = client.get("/api/admin/users", headers=admin_headers)
assert res.status_code == 200, res.text
users_list = res.json()["data"]
assert len(users_list) >= 2
alice_in_list = next((u for u in users_list if u["username"] == "alice"), None)
assert alice_in_list is not None
assert alice_in_list["house_count"] >= 1
assert alice_in_list["item_count"] >= 1
print(f"✓ Admin list users passed: Alice has {alice_in_list['item_count']} items")

# 13. Admin Managed User Creation (with default password 123456)
import time
unique_user = f"grandpa_{int(time.time())}"
res = client.post(
    "/api/admin/users",
    json={"username": unique_user, "nickname": "老爷爷"},
    headers=admin_headers,
)
assert res.status_code == 201, res.text
grandpa_id = res.json()["data"]["id"]
print("✓ Admin managed user creation with default password passed")

# 13b. Verify login with default password 123456
res = client.post("/api/auth/login", json={"username": unique_user, "password": "123456"})
assert res.status_code == 200, res.text

# 14. Admin Freeze Account and Verify Login Block
res = client.patch(
    f"/api/admin/users/{grandpa_id}/status",
    json={"is_active": False},
    headers=admin_headers,
)
assert res.status_code == 200, res.text
assert res.json()["data"]["is_active"] is False

res = client.post("/api/auth/login", json={"username": unique_user, "password": "123456"})
assert res.status_code == 403, res.text
assert "已被停用" in res.json().get("message", "")
print("✓ Admin account freeze passed: login blocked with 403")

# 15. Admin Unfreeze and Reset Password
res = client.patch(
    f"/api/admin/users/{grandpa_id}/status",
    json={"is_active": True},
    headers=admin_headers,
)
assert res.status_code == 200, res.text

# 修改密码为 newpassword888
res = client.post(
    f"/api/admin/users/{grandpa_id}/reset-password",
    json={"new_password": "newpassword888"},
    headers=admin_headers,
)
assert res.status_code == 200, res.text

res = client.post("/api/auth/login", json={"username": unique_user, "password": "newpassword888"})
assert res.status_code == 200, res.text

# 15b. Test Init Password back to 123456
res = client.post(f"/api/admin/users/{grandpa_id}/init-password", headers=admin_headers)
assert res.status_code == 200, res.text

res = client.post("/api/auth/login", json={"username": unique_user, "password": "123456"})
assert res.status_code == 200, res.text
print("✓ Admin init password to 123456 passed")

# 16. Admin Panoramic Items
res = client.get("/api/admin/god-view/items?page=1&page_size=10", headers=admin_headers)
assert res.status_code == 200, res.text
p_items = res.json()["data"]["items"]
assert len(p_items) >= 1
print(f"✓ Admin panoramic items inspection passed: {len(p_items)} items on page 1")

# 17. Admin System Stats
res = client.get("/api/admin/stats", headers=admin_headers)
assert res.status_code == 200, res.text
stats = res.json()["data"]
assert stats["total_users"] >= 2
assert stats["total_items"] >= 1
print(f"✓ Admin system stats passed: {stats['total_users']} users, {stats['total_items']} items, {stats['media_storage_display']} storage")

# 18. Auth Config
res = client.get("/api/auth/config")
assert res.status_code == 200, res.text
assert "allow_public_registration" in res.json()["data"]
print("✓ Auth config endpoint passed")

# 19. Admin Self Password Change
res = client.put(
    "/api/admin/password",
    json={"old_password": "admin123", "new_password": "newadminpwd999"},
    headers=admin_headers,
)
assert res.status_code == 200, res.text
# Verify login with new password
res = client.post("/api/auth/login", json={"username": "admin", "password": "newadminpwd999"})
assert res.status_code == 200, res.text
# Change it back to original default password
new_admin_token = res.json()["data"]["access_token"]
new_admin_headers = {"Authorization": f"Bearer {new_admin_token}"}
res = client.put(
    "/api/admin/password",
    json={"old_password": "newadminpwd999", "new_password": "admin123"},
    headers=new_admin_headers,
)
assert res.status_code == 200, res.text
print("✓ Admin self password update passed")

# 20. Multi-Dimensional God-View Filter Options & Advanced Search
res = client.get("/api/admin/god-view/filter-options", headers=admin_headers)
assert res.status_code == 200, res.text
filter_opts = res.json()["data"]
assert "users" in filter_opts
assert "categories" in filter_opts
assert "tags" in filter_opts
assert len(filter_opts["users"]) >= 1

res = client.get("/api/admin/god-view/advanced-search?keyword=感冒灵", headers=admin_headers)
assert res.status_code == 200, res.text
adv_data = res.json()["data"]
assert adv_data["pagination"]["total"] >= 1
assert adv_data["items"][0]["name"] == "感冒灵颗粒"
print("✓ Admin multi-dimensional advanced search passed")

# 21. Global Soft Delete Verification
# Create temporary item
res = client.post(
    "/api/items",
    json={
        "house_id": house_id,
        "room_id": room_id,
        "name": "待软删除测试物品",
        "quantity": 1,
    },
    headers=alice_headers,
)
assert res.status_code == 201, res.text
temp_item_id = res.json()["data"]["id"]

# Delete item
res = client.delete(f"/api/items/{temp_item_id}", headers=alice_headers)
assert res.status_code == 200, res.text

# Verify item does not appear in normal list
res = client.get("/api/items", headers=alice_headers)
item_names = [it["name"] for it in res.json()["data"]["items"]]
assert "待软删除测试物品" not in item_names

# Verify item does not appear in search
res = client.get("/api/search?q=待软删除", headers=alice_headers)
assert len(res.json()["data"]) == 0

# Verify item does not appear in admin god-view search
res = client.get("/api/admin/god-view/search?q=待软删除", headers=admin_headers)
assert len(res.json()["data"]) == 0
print("✓ Global soft delete verification passed: item marked deleted and invisible in queries")

# 22. Orphan Media Scan & Clean
res = client.get("/api/admin/media/orphans", headers=admin_headers)
assert res.status_code == 200, res.text
orphan_data = res.json()["data"]
assert "orphan_count" in orphan_data
assert "orphan_size_display" in orphan_data

res = client.post("/api/admin/media/orphans/clean", headers=admin_headers)
assert res.status_code == 200, res.text
assert "cleaned_count" in res.json()["data"]
print("✓ Orphan media scan & clean passed")

# 23. Import Scan & TAR Restore
res = client.get("/api/admin/backups/import-scan", headers=admin_headers)
assert res.status_code == 200, res.text

# Restore from latest backup record
res = client.post(f"/api/admin/backups/{backup_record['id']}/restore", headers=admin_headers)
assert res.status_code == 200, res.text
assert res.json()["data"]["status"] == "success"
print("✓ TAR disaster recovery restore passed")

# 24. Category Template Governance & Dynamic User Seeding
res = client.get("/api/admin/category-templates", headers=admin_headers)
assert res.status_code == 200, res.text
tpls = res.json()["data"]
assert len(tpls) >= 14
print(f"✓ Category templates listed: {len(tpls)} templates found")

# Create a new custom template
custom_tpl_name = f"乐高手办_{int(time.time())}"
res = client.post(
    "/api/admin/category-templates",
    json={"name": custom_tpl_name, "icon": "🤖", "color": "#10B981", "sort_order": 99},
    headers=admin_headers,
)
assert res.status_code == 201, res.text
tpl_id = res.json()["data"]["id"]
assert res.json()["data"]["name"] == custom_tpl_name

# Toggle template status
res = client.patch(
    f"/api/admin/category-templates/{tpl_id}/status",
    json={"is_active": True},
    headers=admin_headers,
)
assert res.status_code == 200, res.text
assert res.json()["data"]["is_active"] is True

# Provision a new user and verify the new template was copied into their private categories
new_tpl_user = f"lego_fan_{int(time.time())}"
res = client.post(
    "/api/admin/users",
    json={"username": new_tpl_user, "nickname": "乐高迷"},
    headers=admin_headers,
)
assert res.status_code == 201, res.text
# Login as this new user and verify their categories
res = client.post("/api/auth/login", json={"username": new_tpl_user, "password": "123456"})
assert res.status_code == 200, res.text
u_token = res.json()["data"]["access_token"]
u_headers = {"Authorization": f"Bearer {u_token}"}
res = client.get("/api/items/categories", headers=u_headers)
assert res.status_code == 200, res.text
u_cat_names = [c["name"] for c in res.json()["data"]]
assert custom_tpl_name in u_cat_names
print("✓ Dynamic category template seeding for new user passed")

# Delete template
res = client.delete(f"/api/admin/category-templates/{tpl_id}", headers=admin_headers)
assert res.status_code == 200, res.text
print("✓ Category template CRUD & soft-delete passed")

# Test Admin category templates reorder
res = client.get("/api/admin/category-templates", headers=admin_headers)
assert res.status_code == 200, res.text
all_tpls = res.json()["data"]
if len(all_tpls) >= 2:
    rev_ids = [t["id"] for t in reversed(all_tpls[:3])] + [t["id"] for t in all_tpls[3:]]
    res = client.put(
        "/api/admin/category-templates/reorder",
        json={"ordered_ids": rev_ids},
        headers=admin_headers,
    )
    assert res.status_code == 200, res.text
    reordered_tpls = res.json()["data"]
    assert reordered_tpls[0]["id"] == rev_ids[0]
    print("✓ Admin category templates reorder passed")

# Test User private categories reorder
res = client.get("/api/items/categories", headers=alice_headers)
assert res.status_code == 200, res.text
alice_cats = res.json()["data"]
if len(alice_cats) >= 2:
    rev_cat_ids = [c["id"] for c in reversed(alice_cats[:3])] + [c["id"] for c in alice_cats[3:]]
    res = client.put(
        "/api/items/categories/reorder",
        json={"ordered_ids": rev_cat_ids},
        headers=alice_headers,
    )
    assert res.status_code == 200, res.text
    reordered_cats = res.json()["data"]
    assert reordered_cats[0]["id"] == rev_cat_ids[0]
    print("✓ User private categories reorder passed")

print("=== All Server End-to-End Tests Passed Successfully! ===")
