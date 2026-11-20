from datetime import datetime, timezone
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Table,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base

# 物品-标签关联表
item_tags = Table(
    "item_tags",
    Base.metadata,
    Column("item_id", Integer, ForeignKey("items.id", ondelete="CASCADE"), primary_key=True),
    Column("tag_id", Integer, ForeignKey("tags.id", ondelete="CASCADE"), primary_key=True),
)


class Category(Base):
    """物品分类表"""
    __tablename__ = "categories"
    __table_args__ = (
        UniqueConstraint("user_id", "name", name="uq_category_user_name"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    icon: Mapped[str] = mapped_column(String(20), default="📦")
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, index=True)

    owner = relationship("User", back_populates="categories")
    items = relationship("Item", back_populates="category")


class Tag(Base):
    """物品标签表 (全局公共名词池，name全局唯一)"""
    __tablename__ = "tags"
    __table_args__ = (
        UniqueConstraint("name", name="uq_tag_name"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    name: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, index=True)

    owner = relationship("User", back_populates="tags")
    items = relationship("Item", secondary=item_tags, back_populates="tags")


class Item(Base):
    """物品核心表"""
    __tablename__ = "items"
    __table_args__ = (
        UniqueConstraint("user_id", "client_uuid", name="uq_item_user_client_uuid"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    house_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("houses.id", ondelete="CASCADE"), nullable=False, index=True
    )
    room_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("rooms.id", ondelete="CASCADE"), nullable=False, index=True
    )
    category_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("categories.id", ondelete="SET NULL"), nullable=True, index=True
    )

    name: Mapped[str] = mapped_column(String(120), nullable=False, index=True)
    brand: Mapped[str] = mapped_column(String(120), default="")
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    location_detail: Mapped[str] = mapped_column(Text, default="")  # 可选具体位置描述 (抽屉/层架)
    description: Mapped[str] = mapped_column(Text, default="")      # 备忘说明
    client_uuid: Mapped[str | None] = mapped_column(String(64), nullable=True)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    field_versions_json: Mapped[str] = mapped_column(Text, default="{}", nullable=False)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, index=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # 关联
    owner = relationship("User", back_populates="items")
    house = relationship("House", back_populates="items")
    room = relationship("Room", back_populates="items")
    category = relationship("Category", back_populates="items")
    tags = relationship("Tag", secondary=item_tags, back_populates="items")
    attachments = relationship(
        "Attachment",
        back_populates="item",
        cascade="all, delete-orphan",
        order_by="Attachment.display_order.asc()",
    )

    @property
    def path_display(self) -> str:
        house_name = self.house.name if self.house else ""
        room_name = self.room.name if self.room else ""
        if house_name and room_name:
            return f"{house_name} > {room_name}"
        return house_name or room_name or ""


class ItemSyncOp(Base):
    """离线编辑/删除操作幂等记录表"""
    __tablename__ = "item_sync_ops"
    __table_args__ = (
        UniqueConstraint("user_id", "client_op_uuid", name="uq_sync_op_user_uuid"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    item_id: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    client_op_uuid: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )

