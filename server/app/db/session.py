from typing import Generator
from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session, sessionmaker
from app.core.config import settings

# 创建 SQLite 连接引擎 (支持多线程/FastAPI 并发)
engine = create_engine(
    settings.SQLITE_URL,
    connect_args={"check_same_thread": False, "timeout": 30.0},
    echo=settings.DEBUG,
)


@event.listens_for(engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    """
    无条件执行全局硬约束 PRAGMA：
    1. 激活外键级联检查 (PRAGMA foreign_keys = ON)
    2. 开启 WAL 高并发写入模式 (PRAGMA journal_mode = WAL)
    3. 提升写入性能并确保崩溃安全性 (PRAGMA synchronous = NORMAL)
    """
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys = ON;")
    cursor.execute("PRAGMA journal_mode = WAL;")
    cursor.execute("PRAGMA synchronous = NORMAL;")
    cursor.execute("PRAGMA busy_timeout = 30000;")
    cursor.close()


SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db() -> Generator[Session, None, None]:
    """FastAPI 依赖注入数据库会话生成器"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

