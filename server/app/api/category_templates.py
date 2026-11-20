from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_admin, get_db
from app.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.category_template import (
    CategoryReorderPayload,
    CategoryTemplateCreate,
    CategoryTemplateOut,
    CategoryTemplateStatusUpdate,
    CategoryTemplateUpdate,
)
from app.services.category_service import (
    create_category_template,
    delete_category_template,
    get_all_category_templates,
    reorder_category_templates,
    toggle_category_template_status,
    update_category_template,
)

router = APIRouter(prefix="/admin/category-templates", tags=["Admin Category Templates"])


@router.get("", response_model=ApiResponse[List[CategoryTemplateOut]])
def list_templates(
    include_inactive: bool = True,
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员获取系统级分类模板列表 (默认含停用分类，排除软删除)"""
    templates = get_all_category_templates(db, include_inactive=include_inactive)
    return ApiResponse(
        data=[CategoryTemplateOut.model_validate(t) for t in templates],
        message="获取分类模板列表成功",
    )


@router.post("", response_model=ApiResponse[CategoryTemplateOut], status_code=status.HTTP_201_CREATED)
def create_template(
    payload: CategoryTemplateCreate,
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员创建新分类模板"""
    tpl = create_category_template(db, payload)
    return ApiResponse(
        data=CategoryTemplateOut.model_validate(tpl),
        message="创建分类模板成功",
    )


@router.put("/reorder", response_model=ApiResponse[List[CategoryTemplateOut]])
def reorder_templates(
    payload: CategoryReorderPayload,
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员批量重置分类模板展示次序"""
    templates = reorder_category_templates(db, payload.ordered_ids)
    return ApiResponse(
        data=[CategoryTemplateOut.model_validate(t) for t in templates],
        message="分类模板顺序已更新",
    )


@router.put("/{template_id}", response_model=ApiResponse[CategoryTemplateOut])
def update_template(
    template_id: int,
    payload: CategoryTemplateUpdate,
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员修改分类模板 (名称、图标、排序、状态)"""
    tpl = update_category_template(db, template_id, payload)
    return ApiResponse(
        data=CategoryTemplateOut.model_validate(tpl),
        message="更新分类模板成功",
    )


@router.patch("/{template_id}/status", response_model=ApiResponse[CategoryTemplateOut])
def toggle_template_status(
    template_id: int,
    payload: CategoryTemplateStatusUpdate,
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员切换分类模板启停状态"""
    tpl = toggle_category_template_status(db, template_id, payload.is_active)
    return ApiResponse(
        data=CategoryTemplateOut.model_validate(tpl),
        message="分类模板状态已更新",
    )


@router.delete("/{template_id}", response_model=ApiResponse[None])
def delete_template(
    template_id: int,
    admin_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员软删除分类模板 (新用户不再派生此分类)"""
    delete_category_template(db, template_id)
    return ApiResponse(data=None, message="分类模板已软删除")
