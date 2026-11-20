import os
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    APP_NAME: str = "图觅"
    VERSION: str = "1.0.0"
    DEBUG: bool = False
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # 安全与 JWT 配置
    SECRET_KEY: str = "traceitem-secure-secret-key-change-in-production-2026"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_DAYS: int = 30

    # 默认 Admin 初始账户
    DEFAULT_ADMIN_USERNAME: str = "admin"
    DEFAULT_ADMIN_PASSWORD: str = "admin123"

    # 是否允许访客公开注册 (关闭后仅 Admin 可开户)
    ALLOW_PUBLIC_REGISTRATION: bool = True

    # 数据与多媒体存储路径 (工业化标准)
    BASE_DIR: Path = Path(__file__).resolve().parent.parent.parent
    DATA_DIR: Path = BASE_DIR / "data"
    MEDIA_DIR: Path = DATA_DIR / "media"

    @property
    def DB_PATH(self) -> Path:
        return self.DATA_DIR / "items.db"

    @property
    def SQLITE_URL(self) -> str:
        return f"sqlite:///{self.DB_PATH.as_posix()}"

    @property
    def MEDIA_IMAGES_DIR(self) -> Path:
        return self.MEDIA_DIR / "images"

    @property
    def MEDIA_AUDIOS_DIR(self) -> Path:
        return self.MEDIA_DIR / "audios"

    @property
    def MEDIA_VIDEOS_DIR(self) -> Path:
        return self.MEDIA_DIR / "videos"

    @property
    def MEDIA_THUMBNAILS_DIR(self) -> Path:
        return self.MEDIA_DIR / "thumbnails"

    @property
    def MEDIA_BACKUPS_DIR(self) -> Path:
        return self.MEDIA_DIR / "backups"

    @property
    def MEDIA_BACKUPS_IMPORT_DIR(self) -> Path:
        return self.MEDIA_BACKUPS_DIR / "import"

    @property
    def ASR_MODELS_DIR(self) -> Path:
        return self.DATA_DIR / "models" / "asr"

    @property
    def WEB_DIST_DIR(self) -> Path:
        p1 = self.BASE_DIR.parent / "web" / "dist"
        if p1.exists():
            return p1
        return self.BASE_DIR / "web" / "dist"

    # 媒体附件限制规范 (ADR 0003 & SSOT)
    IMAGE_MAX_LONG_EDGE: int = 1600
    IMAGE_JPEG_QUALITY: int = 82
    AUDIO_MAX_DURATION_SECONDS: int = 120
    VIDEO_MAX_DURATION_SECONDS: int = 60
    MAX_IMAGE_ATTACHMENTS: int = 9
    MAX_VIDEO_ATTACHMENTS: int = 3
    MAX_AUDIO_ATTACHMENTS: int = 3

    # 历史备份保留数量默认上限 (ADR 0006, 默认保留最近 3 份)
    BACKUP_MAX_RETENTION_COUNT: int = 3

    # 端侧 ASR 模型自动初始化下载（国内 hf-mirror 通道）
    ASR_AUTO_DOWNLOAD_MODELS: bool = True
    ASR_MIRROR_BASE_URL: str = "https://hf-mirror.com"

    def ensure_directories(self) -> None:
        """确保所有工业化分片存储目录存在"""
        for path in [
            self.DATA_DIR,
            self.MEDIA_DIR,
            self.MEDIA_IMAGES_DIR,
            self.MEDIA_AUDIOS_DIR,
            self.MEDIA_VIDEOS_DIR,
            self.MEDIA_THUMBNAILS_DIR,
            self.MEDIA_BACKUPS_DIR,
            self.MEDIA_BACKUPS_IMPORT_DIR,
            self.ASR_MODELS_DIR,
        ]:
            path.mkdir(parents=True, exist_ok=True)

        # 兼容性迁移：若存在旧数据库 antusuoji.db 则自动重命名迁移为 items.db
        old_db = self.DATA_DIR / "antusuoji.db"
        new_db = self.DB_PATH
        if old_db.exists() and not new_db.exists():
            try:
                old_db.rename(new_db)
                for ext in ["-wal", "-shm"]:
                    old_f = self.DATA_DIR / f"antusuoji.db{ext}"
                    new_f = self.DATA_DIR / f"items.db{ext}"
                    if old_f.exists() and not new_f.exists():
                        old_f.rename(new_f)
            except Exception:
                pass


settings = Settings()
settings.ensure_directories()

