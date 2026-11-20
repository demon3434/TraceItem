from typing import List, Tuple
from sqlalchemy import text
from sqlalchemy.orm import Session, joinedload
from app.models.item import Category, Item
from app.models.space import House, Room


def _parse_terms(query_text: str) -> List[str]:
    cleaned = query_text.strip().replace("'", "''").replace('"', '""')
    return [t for t in cleaned.split() if t]


def _build_fts_match_expr(terms: List[str]) -> str:
    return " AND ".join(f'"{t}"*' for t in terms)


def _apply_like_terms(query_obj, terms: List[str]):
    query_obj = (
        query_obj.outerjoin(House, Item.house_id == House.id)
        .outerjoin(Room, Item.room_id == Room.id)
        .outerjoin(Category, Item.category_id == Category.id)
    )
    for term in terms:
        like_expr = f"%{term}%"
        query_obj = query_obj.filter(
            (Item.name.like(like_expr))
            | (Item.brand.like(like_expr))
            | (Item.location_detail.like(like_expr))
            | (Item.description.like(like_expr))
            | (House.name.like(like_expr))
            | (Room.name.like(like_expr))
            | (Category.name.like(like_expr))
        )
    return query_obj


def search_items_fts(
    db: Session,
    query_text: str,
    user_id: int,
    limit: int = 50,
) -> List[Item]:
    """
    普通用户私有全文检索 (基于 SQLite FTS5 虚拟表 + BM25 排序)
    支持空格分隔多关键词 AND 联合检索，仅检索属于当前 user_id 的物品
    """
    terms = _parse_terms(query_text)
    if not terms:
        return []

    fts_sql = text(
        """
        SELECT item_id
        FROM items_fts
        WHERE user_id = :user_id AND items_fts MATCH :query
        ORDER BY rank
        LIMIT :limit
        """
    )
    match_expr = _build_fts_match_expr(terms)
    rows = db.execute(
        fts_sql,
        {"user_id": user_id, "query": match_expr, "limit": limit},
    ).fetchall()

    item_ids = [row[0] for row in rows]
    if not item_ids:
        q = db.query(Item).filter(Item.user_id == user_id, Item.is_deleted == False)
        q = _apply_like_terms(q, terms)
        return (
            q.options(
                joinedload(Item.house),
                joinedload(Item.room),
                joinedload(Item.tags),
                joinedload(Item.attachments),
            )
            .limit(limit)
            .all()
        )

    items = (
        db.query(Item)
        .filter(Item.id.in_(item_ids), Item.is_deleted == False)
        .options(
            joinedload(Item.house),
            joinedload(Item.room),
            joinedload(Item.tags),
            joinedload(Item.attachments),
        )
        .all()
    )
    item_map = {item.id: item for item in items}
    return [item_map[i_id] for i_id in item_ids if i_id in item_map]


def god_view_search_fts(
    db: Session,
    query_text: str,
    limit: int = 50,
) -> List[Tuple[Item, str, str]]:
    """
    Admin 上帝视角全库穿透检索 (ADR 0005 & ADR 0007)
    支持空格分隔多关键词 AND 联合检索，返回 (Item, 属主用户名, 属主昵称)
    """
    terms = _parse_terms(query_text)
    if not terms:
        return []

    fts_sql = text(
        """
        SELECT item_id
        FROM items_fts
        WHERE items_fts MATCH :query
        ORDER BY rank
        LIMIT :limit
        """
    )
    match_expr = _build_fts_match_expr(terms)
    rows = db.execute(fts_sql, {"query": match_expr, "limit": limit}).fetchall()
    item_ids = [row[0] for row in rows]

    if not item_ids:
        q = db.query(Item).filter(Item.is_deleted == False)
        q = _apply_like_terms(q, terms)
        items = (
            q.options(
                joinedload(Item.house),
                joinedload(Item.room),
                joinedload(Item.tags),
                joinedload(Item.attachments),
                joinedload(Item.owner),
            )
            .limit(limit)
            .all()
        )
    else:
        items = (
            db.query(Item)
            .filter(Item.id.in_(item_ids), Item.is_deleted == False)
            .options(
                joinedload(Item.house),
                joinedload(Item.room),
                joinedload(Item.tags),
                joinedload(Item.attachments),
                joinedload(Item.owner),
            )
            .all()
        )
        item_map = {item.id: item for item in items}
        items = [item_map[i_id] for i_id in item_ids if i_id in item_map]

    results = []
    for it in items:
        owner_name = it.owner.username if it.owner else "未知"
        owner_nick = it.owner.nickname if (it.owner and it.owner.nickname) else owner_name
        results.append((it, owner_name, owner_nick))
    return results
