from typing import List, Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from app.db.constants import DEFAULT_CATEGORY_TEMPLATES
from app.models.item import Category, Item
from app.models.category_template import CategoryTemplate
from app.schemas.item import CategoryCreate, CategoryUpdate
from app.schemas.category_template import CategoryTemplateCreate, CategoryTemplateUpdate


def get_active_category_templates(db: Session) -> List[CategoryTemplate]:
    """获取所有处于激活且未软删除的分类模板 (按 sort_order 升序)"""
    return (
        db.query(CategoryTemplate)
        .filter(CategoryTemplate.is_deleted == False, CategoryTemplate.is_active == True)
        .order_by(CategoryTemplate.sort_order.asc(), CategoryTemplate.id.asc())
        .all()
    )


def get_all_category_templates(db: Session, include_inactive: bool = True) -> List[CategoryTemplate]:
    """获取管理员视角的全部非软删除分类模板"""
    query = db.query(CategoryTemplate).filter(CategoryTemplate.is_deleted == False)
    if not include_inactive:
        query = query.filter(CategoryTemplate.is_active == True)
    return query.order_by(CategoryTemplate.sort_order.asc(), CategoryTemplate.id.asc()).all()


def create_category_template(db: Session, data: CategoryTemplateCreate) -> CategoryTemplate:
    """创建新的分类模板"""
    exists = (
        db.query(CategoryTemplate)
        .filter(CategoryTemplate.name == data.name, CategoryTemplate.is_deleted == False)
        .first()
    )
    if exists:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="同名分类模板已存在")

    tpl = CategoryTemplate(
        name=data.name,
        icon=data.icon,
        color=data.color,
        sort_order=data.sort_order,
        is_active=True,
        is_deleted=False,
    )
    db.add(tpl)
    db.commit()
    db.refresh(tpl)
    return tpl


def update_category_template(
    db: Session, template_id: int, data: CategoryTemplateUpdate
) -> CategoryTemplate:
    """更新分类模板信息 (名称/图标/排序/状态)"""
    tpl = db.query(CategoryTemplate).filter(
        CategoryTemplate.id == template_id, CategoryTemplate.is_deleted == False
    ).first()
    if not tpl:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="分类模板不存在")

    if data.name and data.name != tpl.name:
        dup = db.query(CategoryTemplate).filter(
            CategoryTemplate.name == data.name,
            CategoryTemplate.id != template_id,
            CategoryTemplate.is_deleted == False,
        ).first()
        if dup:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="已存在同名分类模板")
        tpl.name = data.name

    if data.icon is not None:
        tpl.icon = data.icon
    if data.color is not None:
        tpl.color = data.color
    if data.sort_order is not None:
        tpl.sort_order = data.sort_order
    if data.is_active is not None:
        tpl.is_active = data.is_active

    db.commit()
    db.refresh(tpl)
    return tpl


def toggle_category_template_status(db: Session, template_id: int, is_active: bool) -> CategoryTemplate:
    """切换分类模板启用/停用状态"""
    tpl = db.query(CategoryTemplate).filter(
        CategoryTemplate.id == template_id, CategoryTemplate.is_deleted == False
    ).first()
    if not tpl:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="分类模板不存在")
    tpl.is_active = is_active
    db.commit()
    db.refresh(tpl)
    return tpl


def delete_category_template(db: Session, template_id: int) -> bool:
    """软删除分类模板 (标记 is_deleted = True)"""
    tpl = db.query(CategoryTemplate).filter(
        CategoryTemplate.id == template_id, CategoryTemplate.is_deleted == False
    ).first()
    if not tpl:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="分类模板不存在")
    tpl.is_deleted = True
    db.commit()
    return True


def seed_user_default_categories(db: Session, user_id: int) -> List[Category]:
    """为新注册用户批量克隆当前激活的全局分类模板"""
    templates = get_active_category_templates(db)
    if not templates:
        templates_data = DEFAULT_CATEGORY_TEMPLATES
    else:
        templates_data = [(t.name, t.icon, t.sort_order) for t in templates]

    created: List[Category] = []
    for name, icon, order in templates_data:
        exists = (
            db.query(Category)
            .filter(Category.user_id == user_id, Category.name == name)
            .first()
        )
        if not exists:
            cat = Category(
                user_id=user_id,
                name=name,
                icon=icon,
                sort_order=order,
                is_active=True,
                is_deleted=False,
            )
            db.add(cat)
            created.append(cat)
    db.commit()
    for c in created:
        db.refresh(c)
    return created


def get_user_categories(
    db: Session, user_id: int, include_inactive: bool = False
) -> List[Category]:
    """获取用户的所有分类，默认过滤掉已删除和已停用的分类"""
    query = db.query(Category).filter(Category.user_id == user_id, Category.is_deleted == False)
    if not include_inactive:
        query = query.filter(Category.is_active == True)  # noqa: E712
    return query.order_by(Category.sort_order.asc(), Category.id.asc()).all()


def get_user_categories_paginated(
    db: Session,
    user_id: int,
    page: int = 1,
    page_size: int = 6,
    include_inactive: bool = True,
) -> tuple[List[Category], int]:
    """分页获取用户的分类列表，附带总数统计 (用于分类管理弹出层)"""
    query = db.query(Category).filter(Category.user_id == user_id, Category.is_deleted == False)
    if not include_inactive:
        query = query.filter(Category.is_active == True)  # noqa: E712
    total = query.count()
    items = (
        query.order_by(Category.sort_order.asc(), Category.id.asc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return items, total


def create_user_category(
    db: Session, user_id: int, payload: CategoryCreate
) -> Category:
    """创建新的私有分类"""
    clean_name = payload.name.strip()
    existing = (
        db.query(Category)
        .filter(Category.user_id == user_id, Category.name == clean_name)
        .first()
    )
    if existing:
        if not existing.is_active and payload.is_active:
            existing.is_active = True
            existing.icon = payload.icon or existing.icon
            existing.sort_order = payload.sort_order or existing.sort_order
            db.commit()
            db.refresh(existing)
        return existing

    cat = Category(
        user_id=user_id,
        name=clean_name,
        icon=payload.icon or "📦",
        sort_order=payload.sort_order,
        is_active=payload.is_active,
    )
    db.add(cat)
    db.commit()
    db.refresh(cat)
    return cat


def update_user_category(
    db: Session, user_id: int, category_id: int, payload: CategoryUpdate
) -> Category:
    """更新分类信息 (名称、Emoji、排序或启用状态)"""
    cat = (
        db.query(Category)
        .filter(Category.id == category_id, Category.user_id == user_id)
        .first()
    )
    if not cat:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="指定的分类不存在",
        )

    if payload.name is not None:
        clean_name = payload.name.strip()
        if clean_name != cat.name:
            dup = (
                db.query(Category)
                .filter(Category.user_id == user_id, Category.name == clean_name)
                .first()
            )
            if dup:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"已存在同名分类“{clean_name}”",
                )
            cat.name = clean_name

    if payload.icon is not None:
        cat.icon = payload.icon.strip() or "📦"
    if payload.sort_order is not None:
        cat.sort_order = payload.sort_order
    if payload.is_active is not None:
        cat.is_active = payload.is_active

    db.commit()
    db.refresh(cat)
    return cat


def delete_user_category(db: Session, user_id: int, category_id: int) -> None:
    """
    删除分类：安全解绑关联的物品 (置空 category_id)，
    绝不级联物理删除物品实体
    """
    cat = (
        db.query(Category)
        .filter(Category.id == category_id, Category.user_id == user_id)
        .first()
    )
    if not cat:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="指定的分类不存在",
        )

    # 1. 解绑所有属于该分类的物品
    db.query(Item).filter(
        Item.user_id == user_id, Item.category_id == category_id
    ).update({"category_id": None}, synchronize_session="fetch")

    # 2. 软删除分类实体
    cat.is_deleted = True
    db.commit()


def reorder_category_templates(db: Session, ordered_ids: List[int]) -> List[CategoryTemplate]:
    """批量按 ID 顺序更新系统分类模板的 sort_order"""
    templates = (
        db.query(CategoryTemplate)
        .filter(CategoryTemplate.id.in_(ordered_ids), CategoryTemplate.is_deleted == False)
        .all()
    )
    tpl_map = {t.id: t for t in templates}
    for order, tpl_id in enumerate(ordered_ids, start=1):
        if tpl_id in tpl_map:
            tpl_map[tpl_id].sort_order = order
    db.commit()
    return get_all_category_templates(db, include_inactive=True)


def reorder_user_categories(db: Session, user_id: int, ordered_ids: List[int]) -> List[Category]:
    """批量按 ID 顺序更新用户私有分类的 sort_order"""
    categories = (
        db.query(Category)
        .filter(
            Category.id.in_(ordered_ids),
            Category.user_id == user_id,
            Category.is_deleted == False,
        )
        .all()
    )
    cat_map = {c.id: c for c in categories}
    for order, cat_id in enumerate(ordered_ids, start=1):
        if cat_id in cat_map:
            cat_map[cat_id].sort_order = order
    db.commit()
    return get_user_categories(db, user_id, include_inactive=True)

