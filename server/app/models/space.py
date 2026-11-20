from datetime import datetime, timezone
from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base


class House(Base):
    """房屋表 (用户独立私有作用域)"""
    __tablename__ = "houses"
    __table_args__ = (
        UniqueConstraint("user_id", "name", name="uq_house_user_name"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    icon: Mapped[str] = mapped_column(String(20), default="🏠")  # 空间 Emoji 图标
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )

    # 关联
    owner = relationship("User", back_populates="houses")
    rooms = relationship("Room", back_populates="house", cascade="all, delete-orphan")
    items = relationship("Item", back_populates="house", cascade="all, delete-orphan")


class Room(Base):
    """房间/空间表 (橱柜免配置，拍照直观展现)"""
    __tablename__ = "rooms"
    __table_args__ = (
        UniqueConstraint("user_id", "house_id", "name", name="uq_room_user_house_name"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    house_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("houses.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    icon: Mapped[str] = mapped_column(String(20), default="🛋️")  # 房间 Emoji 图标 (如 🧸, 🚀)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )

    # 关联
    owner = relationship("User", back_populates="rooms")
    house = relationship("House", back_populates="rooms")
    items = relationship("Item", back_populates="room", cascade="all, delete-orphan")

