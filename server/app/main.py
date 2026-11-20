from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from app.api import api_router
from app.core.config import settings
from app.db.init_db import init_db
from app.schemas.common import ApiResponse
from app.services.asr_model_bootstrap import ensure_asr_models_background
from app.services.mdns_discovery import broadcaster


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 启动时执行数据库及 FTS5 虚拟表初始化，开启 mDNS 广播并在后台自动准备 ASR 模型
    init_db()
    ensure_asr_models_background()
    await broadcaster.start(port=settings.PORT)
    yield
    await broadcaster.stop()


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.VERSION,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# 允许全端跨域访问 (Vue Web 桌面端 / Flutter 多端调试)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """全局统一业务异常拦截器，封装标准 ApiResponse 响应"""
    if isinstance(exc.detail, dict):
        return JSONResponse(
            status_code=exc.status_code,
            content=ApiResponse(
                code=exc.status_code,
                message=str(exc.detail.get("message", "请求失败")),
                data=exc.detail.get("data"),
            ).model_dump(),
        )
    return JSONResponse(
        status_code=exc.status_code,
        content=ApiResponse(
            code=exc.status_code,
            message=str(exc.detail),
            data=None,
        ).model_dump(),
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """请求参数校验错误统一格式化"""
    errors = exc.errors()
    first_error = errors[0]["msg"] if errors else "请求参数格式错误"
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=ApiResponse(
            code=422,
            message=f"参数错误: {first_error}",
            data={"details": errors},
        ).model_dump(),
    )


# 挂载全部业务子路由
app.include_router(api_router)

# 挂载多媒体物理静态文件目录
app.mount("/media", StaticFiles(directory=settings.MEDIA_DIR), name="media")


@app.get("/health", tags=["基础巡检"])
@app.get("/api/health", tags=["基础巡检"])
def health_check():
    """服务健康检查接口"""
    return ApiResponse(
        code=0,
        message="healthy",
        data={
            "app_name": settings.APP_NAME,
            "version": settings.VERSION,
            "status": "online",
        },
    )


# 挂载 Web SPA 大屏管理界面
web_dist = settings.WEB_DIST_DIR
if web_dist.exists() and (web_dist / "index.html").exists():
    from fastapi.responses import FileResponse

    if (web_dist / "assets").exists():
        app.mount("/assets", StaticFiles(directory=web_dist / "assets"), name="assets")

    @app.get("/{full_path:path}", include_in_schema=False)
    def serve_spa(full_path: str):
        target_file = web_dist / full_path
        if full_path and target_file.exists() and target_file.is_file():
            return FileResponse(target_file)
        return FileResponse(web_dist / "index.html")

