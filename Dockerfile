# ==========================================
# 阶段 1：构建 Web 前端 (在构建机原生架构下运行，避免 ARM 交叉编译耗时)
# ==========================================
FROM --platform=$BUILDPLATFORM docker.m.daocloud.io/library/node:20-slim AS web-builder

WORKDIR /build

COPY web/package*.json ./web/
RUN cd web && npm config set registry https://registry.npmmirror.com && npm ci

COPY shared ./shared
COPY web ./web
RUN cd web && npm run build

# ==========================================
# 阶段 2：Python FastAPI 服务端 + 静态资源运行镜像
# ==========================================
FROM docker.m.daocloud.io/library/python:3.11-slim

WORKDIR /app

# 配置国内 Debian 镜像源并安装依赖及北京时区 (UTC+8)
RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources 2>/dev/null || true \
    && apt-get update && apt-get install -y --no-install-recommends curl tzdata gcc libc6-dev libjpeg62-turbo-dev zlib1g-dev \
    && ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && dpkg-reconfigure -f noninteractive tzdata \
    && rm -rf /var/lib/apt/lists/*

ENV TZ=Asia/Shanghai

# 安装 Python 依赖 (使用阿里云镜像源)
COPY server/requirements.txt ./
RUN pip install -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com --no-cache-dir -r requirements.txt

# 拷贝服务端与阶段 1 编译出的 Web SPA 静态资源
COPY server/app ./app
COPY server/run.py ./
COPY --from=web-builder /build/web/dist ./web/dist

# 确保多媒体工业化目录存在
RUN mkdir -p /app/data/media/images \
    /app/data/media/audios \
    /app/data/media/videos \
    /app/data/media/thumbnails \
    /app/data/media/backups

ENV PYTHONUNBUFFERED=1
ENV HOST=0.0.0.0
ENV PORT=8000

EXPOSE 8000

CMD ["python", "run.py"]
