<div align="center">
  <img src="docs/logo.png" width="128" alt="图觅 TraceItem Logo" />
  <h1>图觅 (TraceItem)</h1>
  <p>面向家庭与个人场景的物品视觉收纳、空间定位与多模态寻物系统</p>
</div>

---

## ✨ 项目简介

**图觅 (TraceItem)** 是一套轻量化、可自托管的多端物品管理与寻物系统，包含 **FastAPI 后端服务**、**Vue 3 Web 桌面端** 与 **Flutter 移动端**。系统以「**房屋 (House) ➔ 房间 (Room)**」的极简空间模型为核心，摒弃繁琐的橱柜层层建表，直接通过现场照片、语音备忘与短视频快速定位物品。

### 核心特性
- **轻量化存储**：内置 SQLite 3 (WAL 模式 + FTS5 全文检索)，无需部署外部数据库容器。
- **多模态留痕**：支持端侧压缩图片 (JPEG)、语音指引 (AAC/M4A) 与快速起播短视频 (MP4 `+faststart`)，按 `{type}/{YYYY}/{MM}` 工业化分片存储。
- **家庭多成员与上帝视角**：普通成员数据独立隔离；`admin` 账号专享跨成员「上帝视角」紧急寻物与无压缩 `.tar` 一键备份/清理。
- **局域网自动发现**：服务端内置 mDNS (`_traceitem._tcp.local.`) 广播，移动端支持一键自动发现家庭内网服务地址。
- **跨端常量单一数据源 (SSOT)**：共用主题、分类图标与媒体参数统一维护在 `shared/` 目录。

---

## 🚀 快速部署（Docker Compose 推荐）

> 镜像采用多阶段构建，自动在容器内编译 Web 前端并集成到服务端，**宿主机只需安装 Docker / Docker Compose，无需提前安装 Node.js 或 Python**。

### 1. 克隆仓库

```bash
git clone <你的仓库地址>
cd TraceItem
```

### 2. 配置环境变量
项目根目录提供了环境变量模板 [.env.example](.env.example)，复制一份为 `.env` 并按需修改：

```bash
cp .env.example .env
```

常用配置项说明：

| 变量名 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `HOST_PORT` | `8085` | 宿主机对外映射端口，对应访问地址 `http://<服务器IP>:8085/` |
| `SERVICE_ADVERTISE_HOST` | 留空（自动探测） | 若宿主机有多张网卡或虚拟机网桥，建议显式填写局域网 IP（如 `192.168.1.100`），便于手机端 mDNS 自动发现 |
| `SERVICE_ADVERTISE_PORT` | `8085` | mDNS 广播的对外服务端口，通常与 `HOST_PORT` 保持一致 |
| `DEFAULT_ADMIN_USERNAME` | `admin` | 首次启动自动初始化的管理员用户名 |
| `DEFAULT_ADMIN_PASSWORD` | `admin123` | 首次启动自动初始化的管理员密码（登录后请及时修改） |
| `SECRET_KEY` | 内置默认密钥 | JWT 登录令牌签名密钥，**公网/生产环境请务必修改为随机长字符串** |

### 3. （可选）配置 Linux 宿主机 mDNS 局域网自动发现
若希望手机 App 在同一家庭 WiFi 下“一键自动发现”服务端地址，需在 **Linux 宿主机**上运行一次 [scripts/setup_avahi_traceitem.sh](scripts/setup_avahi_traceitem.sh)（脚本会自动安装 `avahi-daemon`、创建 `br-traceitem` 桥接网络并开启组播反射）：

- **方式 A（已在宿主机完整克隆本仓库）**：直接在仓库根目录执行：
  ```bash
  sudo bash scripts/setup_avahi_traceitem.sh
  ```
- **方式 B（仅在宿主机放置 `docker-compose.yml` 拉取镜像部署）**：需将仓库中的 `scripts/setup_avahi_traceitem.sh` 单独上传/下载到宿主机目录后执行：
  ```bash
  sudo bash setup_avahi_traceitem.sh
  ```

> 💡 该步骤只需在宿主机执行一次；若跳过此步（或使用 Windows/macOS 宿主机），图觅服务依然可以正常使用，仅需在手机 App 首次连接时手动输入 `http://<服务器IP>:8085`。

### 4. 构建并启动容器

```bash
docker compose up -d --build
```

启动后即可访问：
- **Web 管理界面**：`http://<服务器IP>:8085/`
- **Swagger API 文档**：`http://<服务器IP>:8085/docs`
- **健康检查**：`http://<服务器IP>:8085/health`

#### 🔐 默认管理员账号
首次全新部署启动后，系统会自动初始化管理员账号：
- **用户名**：`admin`
- **默认密码**：`admin123`

> ⚠️ 请在首次登录后及时在页面右上角修改管理员密码（如需自定义初始账号密码，可在 `.env` 或 `docker-compose.yml` 中配置 `DEFAULT_ADMIN_USERNAME` 与 `DEFAULT_ADMIN_PASSWORD`）。

数据库与上传的多媒体文件会持久化保存在宿主机的 `./data` 目录中。

---

## 💻 本地源码开发指南（仅二次开发需要）

> 若仅需部署使用，请直接参考上方「快速部署」章节，无需安装以下本地开发环境。

### 1. 后端服务 (FastAPI)
需要 Python 3.11+：

```bash
cd server
pip install -r requirements.txt
python run.py
```
默认监听 `http://0.0.0.0:8000`。

### 2. Web 前端 (Vue 3 + Vite)
需要 Node.js 20+：

```bash
cd web
npm install
npm run dev
```
默认监听 `http://0.0.0.0:5173`，开发代理已将 `/api` 与 `/media` 转发至 `http://127.0.0.1:8000`。

### 3. 移动端 (Flutter)
需要 Flutter SDK (`>=3.4.0`)：

```bash
cd mobile
flutter pub get
flutter run
```

构建 Android Release APK（项目约定仅打包 `arm64-v8a` 单架构）：

```bash
cd mobile
flutter build apk --release --target-platform android-arm64
```

### 4. 跨端常量同步 (SSOT)
修改 `shared/*.json` 后，请运行同步脚本更新移动端与服务端生成文件：

```bash
python scripts/sync_shared.py
# 检查是否存在未同步漂移
python scripts/sync_shared.py --check
```

---

## 📁 目录结构

```text
TraceItem/
├── server/          # FastAPI 后端服务、SQLite FTS5 与测试
├── web/             # Vue 3 + Tailwind + shadcn-vue Web 端
├── mobile/          # Flutter + shadcn_ui 移动端
├── shared/          # 跨端共用 JSON 常量单一数据源 (SSOT)
├── scripts/         # 常量同步与 Avahi mDNS 初始化脚本
├── docs/            # Logo、架构决策记录 (ADR) 与指南文档
├── openspec/        # OpenSpec 变更提案与规范
├── .agents/         # AI Agent 技能与开发规范
├── .antigravity/    # Antigravity IDE 配置与技能
├── .claude/         # Claude Code 配置与技能
├── AGENTS.md        # 全局开发红线与约束规范
├── GLOSSARY.md      # 项目统一领域术语表
├── Dockerfile
└── docker-compose.yml
```

