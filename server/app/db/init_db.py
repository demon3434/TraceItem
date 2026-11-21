from sqlalchemy import text
from sqlalchemy.orm import Session
import uuid
from app.core.config import settings
from app.core.security import hash_password
from app.db.base import Base
from app.db.session import SessionLocal, engine
from app.models.user import User


def get_or_create_server_instance_id() -> str:
    """获取或初始化持久化的服务器数据库实例指纹 (UUID)"""
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS system_settings (
                    key VARCHAR(64) PRIMARY KEY,
                    value TEXT NOT NULL
                );
                """
            )
        )
        row = conn.execute(
            text("SELECT value FROM system_settings WHERE key = 'server_instance_id';")
        ).fetchone()
        if row and row[0]:
            return str(row[0])
        new_id = str(uuid.uuid4())
        conn.execute(
            text("INSERT INTO system_settings (key, value) VALUES ('server_instance_id', :val);"),
            {"val": new_id},
        )
        return new_id


def init_db() -> None:
    """初始化数据库表、FTS5 全文虚拟表及触发器，并创建默认 Admin"""
    settings.ensure_directories()

    # 1. 创建普通关系表
    Base.metadata.create_all(bind=engine)

    # 兼容性迁移：检查并升级现有数据表列与索引
    with engine.begin() as conn:
        cat_columns = [row[1] for row in conn.execute(text("PRAGMA table_info(categories);")).fetchall()]
        if cat_columns and "is_active" not in cat_columns:
            conn.execute(text("ALTER TABLE categories ADD COLUMN is_active BOOLEAN DEFAULT 1;"))
        conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS uq_tag_name ON tags(name);"))

        # 空间启停字段 is_active 兼容性迁移
        for space_tbl in ["houses", "rooms"]:
            space_cols = [row[1] for row in conn.execute(text(f"PRAGMA table_info({space_tbl});")).fetchall()]
            if space_cols and "is_active" not in space_cols:
                conn.execute(text(f"ALTER TABLE {space_tbl} ADD COLUMN is_active BOOLEAN DEFAULT 1;"))
            if space_cols:
                conn.execute(text(f"CREATE INDEX IF NOT EXISTS ix_{space_tbl}_is_active ON {space_tbl}(is_active);"))

        # 全局软删除字段 is_deleted 兼容性迁移
        tables_to_migrate = ["users", "houses", "rooms", "items", "categories", "tags"]
        for tbl in tables_to_migrate:
            cols = [row[1] for row in conn.execute(text(f"PRAGMA table_info({tbl});")).fetchall()]
            if cols and "is_deleted" not in cols:
                conn.execute(text(f"ALTER TABLE {tbl} ADD COLUMN is_deleted BOOLEAN DEFAULT 0;"))
            if cols:
                conn.execute(text(f"CREATE INDEX IF NOT EXISTS ix_{tbl}_is_deleted ON {tbl}(is_deleted);"))

        # 用户令牌版本号 token_version 兼容性迁移（改密立即失效旧会话）
        user_cols = [row[1] for row in conn.execute(text("PRAGMA table_info(users);")).fetchall()]
        if user_cols and "token_version" not in user_cols:
            conn.execute(text("ALTER TABLE users ADD COLUMN token_version INTEGER NOT NULL DEFAULT 1;"))

        # 物品乐观锁字段 version 与离线幂等键 client_uuid 兼容性迁移
        item_cols = [row[1] for row in conn.execute(text("PRAGMA table_info(items);")).fetchall()]
        if item_cols and "version" not in item_cols:
            conn.execute(text("ALTER TABLE items ADD COLUMN version INTEGER NOT NULL DEFAULT 1;"))
        if item_cols and "field_versions_json" not in item_cols:
            conn.execute(text("ALTER TABLE items ADD COLUMN field_versions_json TEXT NOT NULL DEFAULT '{}';"))
        if item_cols and "client_uuid" not in item_cols:
            conn.execute(text("ALTER TABLE items ADD COLUMN client_uuid VARCHAR(64);"))
        if item_cols:
            conn.execute(
                text("CREATE UNIQUE INDEX IF NOT EXISTS uq_item_user_client_uuid ON items(user_id, client_uuid);")
            )

    # 2. 创建并初始化 FTS5 全文索引虚拟表与同步触发器
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

        # 移除旧版仅索引 4 个原始字段的 SQL 触发器，改由 fts_indexer 维护全字段 CJK 1-gram/2-gram 索引
        conn.execute(text("DROP TRIGGER IF EXISTS trg_items_insert;"))
        conn.execute(text("DROP TRIGGER IF EXISTS trg_items_delete;"))
        conn.execute(text("DROP TRIGGER IF EXISTS trg_items_update;"))

    # 3. 创建初始默认 Admin 账号与密码规范平滑升级
    db: Session = SessionLocal()
    try:
        admin_user = (
            db.query(User)
            .filter(User.username == settings.DEFAULT_ADMIN_USERNAME)
            .first()
        )
        if not admin_user:
            admin_user = User(
                username=settings.DEFAULT_ADMIN_USERNAME,
                password_hash=hash_password(settings.DEFAULT_ADMIN_PASSWORD),
                nickname="系统管理员",
                role="admin",
                is_active=True,
            )
            db.add(admin_user)
            db.commit()
        else:
            from app.core.security import verify_password
            if verify_password("admin123456", admin_user.password_hash):
                admin_user.password_hash = hash_password(settings.DEFAULT_ADMIN_PASSWORD)
                db.commit()

        # 4. 初始化默认物品分类模板 (14 种预设场景分类入库)
        from app.models.category_template import CategoryTemplate
        from app.db.constants import DEFAULT_CATEGORY_TEMPLATES
        tpl_count = db.query(CategoryTemplate).filter(CategoryTemplate.is_deleted == False).count()
        if tpl_count == 0:
            for name, icon, order in DEFAULT_CATEGORY_TEMPLATES:
                exists = db.query(CategoryTemplate).filter(CategoryTemplate.name == name).first()
                if not exists:
                    tpl = CategoryTemplate(
                        name=name,
                        icon=icon,
                        color="#F97316",
                        sort_order=order,
                        is_active=True,
                        is_deleted=False,
                    )
                    db.add(tpl)
            db.commit()
        from app.services.fts_indexer import rebuild_all_items_fts
        rebuild_all_items_fts(db)

        # 5. 确保全局数据库实例指纹就绪
        get_or_create_server_instance_id()
    finally:
        db.close()

