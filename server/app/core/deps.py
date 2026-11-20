from typing import Generator, Optional
from fastapi import Depends, HTTPException, Query, Request, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.db.session import get_db
from app.models.user import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")


def _resolve_user_from_token(token: str, db: Session) -> User:
    """校验 JWT 并返回激活用户（供标准 Bearer 与媒体查询参数复用）"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="认证凭据无效或已过期，请重新登录",
        headers={"WWW-Authenticate": "Bearer"},
    )
    payload = decode_access_token(token)
    if payload is None:
        raise credentials_exception

    user_id_str = payload.get("sub")
    if user_id_str is None:
        raise credentials_exception

    try:
        user_id = int(user_id_str)
    except ValueError:
        raise credentials_exception

    user = db.scalar(select(User).where(User.id == user_id))
    if user is None:
        raise credentials_exception
    if payload.get("tv") != (user.token_version or 1):
        raise credentials_exception
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="当前用户账号已被停用",
        )
    return user


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    """获取当前已鉴权登录用户"""
    return _resolve_user_from_token(token, db)


def get_current_user_media(
    request: Request,
    token: Optional[str] = Query(None, description="媒体直链可选鉴权令牌"),
    db: Session = Depends(get_db),
) -> User:
    """媒体资源鉴权：优先读取 Authorization Bearer，回退读取 ?token= 查询参数"""
    auth_header = request.headers.get("Authorization", "")
    resolved_token = ""
    if auth_header.lower().startswith("bearer "):
        resolved_token = auth_header[7:].strip()
    elif token:
        resolved_token = token.strip()

    if not resolved_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="访问媒体资源需要登录鉴权",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return _resolve_user_from_token(resolved_token, db)


def get_current_admin(
    current_user: User = Depends(get_current_user),
) -> User:
    """获取当前 Admin 管理员特权用户"""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="需要管理员特权方可访问此接口",
        )
    return current_user

