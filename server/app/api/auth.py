from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.deps import get_current_user, get_db
from app.core.security import create_access_token, hash_password, verify_password
from app.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.user import (
    TokenOut,
    UserLoginRequest,
    UserOut,
    UserRegisterRequest,
    UserUpdateRequest,
)

router = APIRouter(prefix="/auth", tags=["用户认证与账号"])


@router.post("/register", response_model=ApiResponse[UserOut])
def register(
    payload: UserRegisterRequest,
    db: Session = Depends(get_db),
):
    """注册新的家庭普通成员 (受系统公开注册开关控制)"""
    if not settings.ALLOW_PUBLIC_REGISTRATION:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="系统已关闭公开注册通道，请联系管理员分配家庭成员账号",
        )

    existing_user = db.scalar(
        select(User).where(User.username == payload.username.strip())
    )
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"用户名“{payload.username}”已被注册",
        )

    user = User(
        username=payload.username.strip(),
        password_hash=hash_password(payload.password),
        nickname=payload.nickname.strip() if payload.nickname else payload.username.strip(),
        role="user",
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # 自动克隆注入 14 套居家日常全场景预设分类模板
    from app.services.category_service import seed_user_default_categories
    seed_user_default_categories(db, user.id)

    return ApiResponse(data=UserOut.model_validate(user), message="注册成功")


@router.post("/login", response_model=ApiResponse[TokenOut])
async def login(
    request: Request,
    db: Session = Depends(get_db),
):
    """
    用户登录接口 (自适应兼容 JSON 载荷与 OAuth2 表单规范)
    """
    content_type = request.headers.get("content-type", "")
    username = ""
    password = ""

    if "application/json" in content_type:
        body = await request.json()
        username = body.get("username", "")
        password = body.get("password", "")
    else:
        form = await request.form()
        username = form.get("username", "")
        password = form.get("password", "")

    username = username.strip() if isinstance(username, str) else ""
    if not username or not password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="请输入用户名和密码",
        )

    user = db.scalar(select(User).where(User.username == username))
    if not user or not verify_password(password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="该账号已被停用，请联系管理员",
        )

    access_token = create_access_token(
        subject=user.id,
        role=user.role,
        token_version=user.token_version or 1,
        extra_claims={
            "username": user.username,
            "nickname": user.nickname,
        },
    )

    user_out = UserOut.model_validate(user)
    token_out = TokenOut(
        access_token=access_token,
        token_type="bearer",
        user=user_out,
    )
    return ApiResponse(data=token_out, message="登录成功")


@router.get("/me", response_model=ApiResponse[UserOut])
def get_me(
    current_user: User = Depends(get_current_user),
):
    """获取当前登录用户信息"""
    return ApiResponse(data=UserOut.model_validate(current_user))


@router.put("/me", response_model=ApiResponse[UserOut])
def update_me(
    payload: UserUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """修改当前登录用户基本信息或密码"""
    if payload.nickname is not None:
        current_user.nickname = payload.nickname.strip()
    if payload.password:
        current_user.password_hash = hash_password(payload.password)
        current_user.token_version = (current_user.token_version or 1) + 1

    db.commit()
    db.refresh(current_user)
    return ApiResponse(data=UserOut.model_validate(current_user), message="更新成功")


@router.get("/users", response_model=ApiResponse[List[UserOut]])
def list_active_users(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """获取所有启用的家庭成员列表 (用于 Admin 或成员信息展示)"""
    users = db.scalars(
        select(User).where(User.is_active == True).order_by(User.id.asc())
    ).all()
    return ApiResponse(data=[UserOut.model_validate(u) for u in users])


@router.get("/config", response_model=ApiResponse[dict])
def get_auth_config():
    """获取公开认证配置 (如是否开放注册)"""
    return ApiResponse(data={
        "allow_public_registration": settings.ALLOW_PUBLIC_REGISTRATION,
    })


