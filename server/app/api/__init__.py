from fastapi import APIRouter

from app.api.admin import router as admin_router
from app.api.asr import router as asr_router
from app.api.auth import router as auth_router
from app.api.category_templates import router as category_templates_router
from app.api.houses import router as houses_router
from app.api.items import router as items_router
from app.api.media import router as media_router
from app.api.rooms import router as rooms_router
from app.api.search import router as search_router

api_router = APIRouter(prefix="/api")

api_router.include_router(auth_router)
api_router.include_router(houses_router)
api_router.include_router(rooms_router)
api_router.include_router(items_router)
api_router.include_router(media_router)
api_router.include_router(search_router)
api_router.include_router(admin_router)
api_router.include_router(asr_router)
api_router.include_router(category_templates_router)

__all__ = ["api_router"]

