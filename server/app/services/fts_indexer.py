import re
from sqlalchemy import text
from sqlalchemy.orm import Session, joinedload

from app.models.item import Item

_CJK_RUN_RE = re.compile(r"[\u4e00-\u9fa5]+")


def cjk_index_text(raw: str | None) -> str:
    """将文本中的连续汉字展开为 原词 + 单字 + 双字 空格分隔索引串，兼容 unicode61 全子串检索"""
    text_val = (raw or "").strip()
    if not text_val:
        return ""
    tokens: list[str] = [text_val]
    for match in _CJK_RUN_RE.finditer(text_val):
        seg = match.group(0)
        if len(seg) <= 1:
            continue
        for ch in seg:
            tokens.append(ch)
        for i in range(len(seg) - 1):
            tokens.append(seg[i : i + 2])
    return " ".join(tokens)


def _insert_item_fts_row(db: Session, item: Item) -> None:
    house_name = item.house.name if item.house else ""
    room_name = item.room.name if item.room else ""
    category_name = item.category.name if item.category else ""
    tag_names = " ".join(t.name for t in (item.tags or []) if t.name)

    db.execute(
        text(
            """
            INSERT INTO items_fts(item_id, user_id, name, brand, location_detail, description)
            VALUES (:item_id, :user_id, :name, :brand, :location_detail, :description)
            """
        ),
        {
            "item_id": item.id,
            "user_id": item.user_id,
            "name": cjk_index_text(item.name),
            "brand": cjk_index_text(item.brand),
            "location_detail": cjk_index_text(
                f"{house_name} {room_name} {item.location_detail or ''}"
            ),
            "description": cjk_index_text(
                f"{category_name} {tag_names} {item.description or ''}"
            ),
        },
    )


def sync_item_fts(db: Session, item_id: int) -> None:
    """同步单条物品到 FTS5 索引（含房屋、房间、分类、标签与 CJK 子串展开）"""
    db.execute(
        text("DELETE FROM items_fts WHERE item_id = :item_id"),
        {"item_id": item_id},
    )
    item = (
        db.query(Item)
        .filter(Item.id == item_id, Item.is_deleted == False)
        .options(
            joinedload(Item.house),
            joinedload(Item.room),
            joinedload(Item.category),
            joinedload(Item.tags),
        )
        .first()
    )
    if item is not None:
        _insert_item_fts_row(db, item)
    db.commit()


def rebuild_all_items_fts(db: Session) -> None:
    """全量重建 items_fts 索引（启动或空间/分类改名后调用）"""
    db.execute(text("DELETE FROM items_fts"))
    items = (
        db.query(Item)
        .filter(Item.is_deleted == False)
        .options(
            joinedload(Item.house),
            joinedload(Item.room),
            joinedload(Item.category),
            joinedload(Item.tags),
        )
        .all()
    )
    for item in items:
        _insert_item_fts_row(db, item)
    db.commit()

