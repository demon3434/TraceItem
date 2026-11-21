<div align="center">
  <img src="docs/logo.png" width="128" alt="图觅 TraceItem Logo" />
  <h1>图觅 (TraceItem)</h1>
  <p>面向家庭与个人的轻量级多模态物品视觉收纳、空间定位与寻物系统</p>
  <p>
    <img src="https://img.shields.io/badge/Docker-Ready-blue.svg" alt="Docker Ready" />
    <img src="https://img.shields.io/badge/FastAPI-Python_3.11-009688.svg" alt="FastAPI" />
    <img src="https://img.shields.io/badge/Vue_3-Tailwind-4FC08D.svg" alt="Vue 3" />
    <img src="https://img.shields.io/badge/Flutter-Android-02569B.svg" alt="Flutter" />
    <img src="https://img.shields.io/badge/SQLite-WAL_%2B_FTS5-003B57.svg" alt="SQLite" />
  </p>
</div>

---

## ✨ 项目简介

**图觅 (TraceItem)** 是一套轻量化、私有化部署的多端家庭寻物与物品收纳管理系统，包含 **FastAPI 后端**、**Vue 3 Web 桌面端** 与 **Flutter 移动端**。

很多收纳软件要求用户一层一层建立「房屋 ➔ 房间 ➔ 橱柜 ➔ 隔层 ➔ 收纳盒」的繁琐层级，录入成本极高且容易放弃。**图觅彻底化繁为简**：
- **空间只管到房间**（如：主卧、客厅、地下室、老家车库）；
- **柜子抽屉无需建表**，直接依靠现场拍摄的照片、语音备忘或 15 秒短视频直观展现；
- 无论是找电钻、找保单、找孩子的玩具还是翻换季衣物，搜名字、听语音或翻照片即可秒级定位。

### 🌟 核心特性
- 🪶 **超轻量零依赖**：单容器即可运行全部功能！内置 SQLite 3（WAL 高性能模式 + FTS5 全文搜索），无需部署 PostgreSQL/MySQL 等庞大数据库容器，老旧电脑、玩客云、电视盒子或低功耗 NAS 均可流畅运行。
- 📷 **多模态直观留痕**：支持现场拍照 (端侧压缩)、语音备忘指引 (AAC/M4A) 与快速起播短视频 (MP4 `+faststart`)，工业化年月分片存储。
- 👨‍👩‍👧‍👦 **多成员账本隔离与上帝视角**：家庭各成员拥有专属私有空间；`admin` 管理员专享跨成员「上帝视角」紧急寻物与免压缩 `.tar` 一键安全备份。
- 📡 **局域网自动发现**：服务端内置 mDNS (`_traceitem._tcp.local.`)，手机在同一家庭 Wi-Fi 下可一键自动发现服务器地址，无需记忆复杂 IP。
- 🎨 **多巴胺温馨美学与儿童友好**：全端温润大圆角与活力多巴胺配色，支持房间 Emoji 图腾（🧸、🚀、🛋️），孩子老人即便不认字也能轻松辨认。

---

## 🚀 极速部署指南（推荐）

本系统提供打包好的多架构 Docker 容器镜像，**无需安装 Python、无需配置 Node.js，只要机器上有 Docker 就能运行**！

### 方式一：直接拉取预构建镜像（小白用户 / 家用 NAS / 玩客云 / 软路由推荐）

免去下载庞大源码与本地编译的漫长等待，两步即可拉起：

#### 第 1 步：准备部署文件
在服务器或电脑任意位置新建一个文件夹（例如 `traceitem`），并在该目录下新建 `docker-compose.yml` 文件，填入如下内容：

```yaml
services:
  traceitem:
    image: crpi-tyyqcg8a2rpatesk.cn-shanghai.personal.cr.aliyuncs.com/zixidaxian/traceitem-app:latest
    container_name: traceitem-app
    restart: unless-stopped
    ports:
      - "${HOST_PORT:-8085}:8000"
    volumes:
      - ./data:/app/data
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
    environment:
      - HOST=0.0.0.0
      - PORT=8000
      - DEBUG=False
      - SECRET_KEY=${SECRET_KEY:-traceitem-secure-secret-key-change-in-production-2026}
      - TZ=Asia/Shanghai
      - SERVICE_ADVERTISE_HOST=${SERVICE_ADVERTISE_HOST:-}
      - SERVICE_ADVERTISE_PORT=${SERVICE_ADVERTISE_PORT:-8085}
      - DEFAULT_ADMIN_USERNAME=${DEFAULT_ADMIN_USERNAME:-admin}
      - DEFAULT_ADMIN_PASSWORD=${DEFAULT_ADMIN_PASSWORD:-admin123}
      - ALLOW_PUBLIC_REGISTRATION=${ALLOW_PUBLIC_REGISTRATION:-true}
      - BACKUP_MAX_RETENTION_COUNT=${BACKUP_MAX_RETENTION_COUNT:-3}
    networks:
      - traceitem_mdns

networks:
  traceitem_mdns:
    name: traceitem_mdns
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: br-traceitem
```

> 💡 **参数与 `.env` 说明**：
> - 上方的配置天然支持 Docker Compose 的 `${变量名:-默认值}` 语法。
> - **小白用户**：无需创建 `.env`，Docker Compose 会自动应用冒号后面的默认参数（端口 `8085`、默认管理员 `admin` / `admin123`），开箱即用。
> - **需要自定义参数**：可以在同级目录下新建一个 `.env` 文件（参考 [.env.example](.env.example)），Docker Compose 会自动优先读取 `.env` 中的参数覆盖默认值。

#### 第 2 步：一键启动
在刚才放有 `docker-compose.yml` 的目录下打开终端，执行：

```bash
docker compose up -d
```

---

### 方式二：从源码本地构建部署（适合二次开发与代码贡献者）

如果你想对代码进行修改并自行编译镜像：

```bash
# 1. 克隆本仓库代码
git clone https://github.com/demon3434/TraceItem.git
cd TraceItem

# 2. 复制环境配置（可选修改）
cp .env.example .env

# 3. 本地编译并启动
docker compose up -d --build
```

---

## 💻 访问与使用说明

### 1. 打开 Web 管理界面
容器启动成功后，在电脑或手机浏览器中打开：
👉 **`http://<服务器局域网IP>:8085/`**
*(如果是在运行 Docker 的本机直接访问，打开 `http://localhost:8085/` 即可)*

> ❓ **小白答疑：怎么看服务器的局域网 IP？**
> - **Linux / 树莓派 / 玩客云**：在终端输入 `hostname -I` 或 `ip a`，通常形如 `192.168.1.xxx` 或 `192.168.7.xxx`；
> - **群晖 Synology / 威联通 QNAP / Unraid / 飞牛 fnOS**：在 NAS 系统的网络控制台或路由器管理页面直接查看；
> - **Windows**：在 CMD 中输入 `ipconfig` 查看 IPv4 地址。

### 2. 初始管理员账号
首次全新部署，系统数据库保持绝对纯净（0 测试用户、0 房屋、0 物品），并预置了系统管理员：
- **管理员账号**：`admin`
- **默认初始密码**：`admin123`

登录后，建议点击右上角「设置」修改初始密码。

### 3. 数据持久化与备份升级说明
- **数据保存在哪？** 所有物品数据、照片视频及备份记录均安全保存在当前目录下的 `./data` 文件夹中；
- **更新版本会丢数据吗？** 只要保留 `./data` 文件夹，执行更新拉取最新镜像重启，数据永久保留且绝不丢失；
- **一键备份**：管理员在 Web 端「设置」页面中，专享一键生成纯 `.tar` 备份包下载，支持随时还原。

---

## 📱 移动端与客户端配合使用

图觅支持手机多端联动：

1. **移动浏览器直接访问（免安装）**：
   手机连接家中 Wi-Fi，用移动浏览器打开 `http://<服务器局域网IP>:8085/`，界面全面适配手机触屏与多巴胺温润交互；
2. **Flutter Android 客户端**：
   - 首次打开 App，若尚未配置地址，在登录页点击「服务器设置」，输入 `http://<服务器局域网IP>:8085`；
   - **换服务器 IP / 重部署自动识别**：客户端内置实例指纹守卫，即便服务器重置或切换网络，客户端会自动识别并安全重置离线缓存，杜绝旧数据残留。

### （进阶可选）开启家庭局域网自动发现 (mDNS)
若希望手机 App 在同一 Wi-Fi 下点击「自动发现内网服务」即可秒搜到服务器而无需手动打字输入 IP：
- **Linux 宿主机**上仅需执行一次初始化脚本：
  ```bash
  sudo bash scripts/setup_avahi_traceitem.sh
  ```
- *注：此项为进阶可选功能，若不配置也完全不影响使用，手动输入一次 IP 即可长期保存。*

---

## 🛠️ 本地源码开发指南（开发者专用）

> 仅当您希望为本项目贡献代码或二次开发时参考。

### 1. 后端服务 (FastAPI)
- 环境要求：Python 3.11+
```bash
cd server
pip install -r requirements.txt
python run.py
```
默认监听 `http://0.0.0.0:8000`，API 文档查看 `http://127.0.0.1:8000/docs`。

### 2. Web 前端 (Vue 3 + Tailwind CSS + shadcn-vue)
- 环境要求：Node.js 20+
```bash
cd web
npm install
npm run dev
```
开发模式监听 `http://localhost:5173`，代理已自动配置转发 `/api` 与 `/media` 至 `8000` 端口。

### 3. 移动端 (Flutter)
- 环境要求：Flutter SDK (`>=3.4.0`)
```bash
cd mobile
flutter pub get
flutter run
```
打包 Android Release APK（本仓库严格遵循 ARMv8 单架构标准）：
```bash
cd mobile
flutter build apk --release --target-platform android-arm64
```

### 4. 跨端常量单一数据源 (SSOT)
跨端共用的分类图标、空间 Emoji 与多巴胺主题配置统一存放在 `shared/*.json`。修改后请运行同步脚本更新生成文件：
```bash
python scripts/sync_shared.py
# 验证零漂移
python scripts/sync_shared.py --check
```

### 5. 开发规范与代码约束
所有贡献与修改必须遵循本仓库最高优先级准则 [`AGENTS.md`](AGENTS.md)：
- **单文件严格 <500 行**：任何 `.py`、`.vue`、`.dart` 文件严禁超标，逻辑必须下沉到独立 Service/Widget；
- **严禁浏览器原生弹窗**：禁止调用原生 `alert()` / `confirm()`，全端统一使用 `shadcn` 温润对话框与悬浮 Toast；
- **全端图标统一**：全端 100% 采用 Lucide 图标体系。

---

## 📂 仓库目录全景

```text
TraceItem/
├── server/          # FastAPI 后端服务、SQLite WAL+FTS5 引擎、数据模型与测试
├── web/             # Vue 3 + Tailwind CSS + shadcn-vue 桌面端
├── mobile/          # Flutter + shadcn_ui 移动客户端 (iOS / Android)
├── shared/          # 跨端常量单一数据源 JSON (分类/主题/Emoji)
├── scripts/         # 常量同步 (sync_shared.py) 与 Avahi mDNS 辅助脚本
├── docs/            # 架构设计决策 (ADR)、指南与静态素材
├── openspec/        # OpenSpec 规范标准库与变更历史归档
├── docker-compose.yml           # 本地多阶段构建 Docker Compose
├── docker-compose.aliyun.yml    # 阿里云预构建镜像直接运行 Compose
├── Dockerfile                   # 多阶段容器构建描述
├── AGENTS.md                    # 项目开发红线与全局硬性约束
└── GLOSSARY.md                  # 统一领域术语表
```

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 开源，欢迎家庭用户个人部署使用，也欢迎提交 Pull Request 共同改进！
