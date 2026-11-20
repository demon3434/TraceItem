from datetime import datetime, timezone
from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base


class Attachment(Base):
    """多模态媒体附件表 (工业化路径映射)"""
    __tablename__ = "attachments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    item_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("items.id", ondelete="CASCADE"), nullable=False, index=True
    )
    media_type: Mapped[str] = mapped_column(String(20), nullable=False)  # 'image' | 'audio' | 'video'
    file_path: Mapped[str] = mapped_column(String(255), nullable=False)  # 如 images/2026/11/img_xxx.jpg
    thumbnail_path: Mapped[str | None] = mapped_column(String(255), nullable=True)  # 封面缩略图路径
    file_size: Mapped[int] = mapped_column(Integer, default=0)
    duration_seconds: Mapped[int] = mapped_column(Integer, default=0)    # 音频或视频时长 (秒)
    width: Mapped[int] = mapped_column(Integer, default=0)
    height: Mapped[int] = mapped_column(Integer, default=0)
    display_order: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )

    item = relationship("Item", back_populates="attachments")

    @property
    def url(self) -> str:
        return f"/api/media/file/{self.file_path}"

    @property
    def thumbnail_url(self) -> str | None:
        if self.thumbnail_path:
            return f"/api/media/file/{self.thumbnail_path}"
        return None

