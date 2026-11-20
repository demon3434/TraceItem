# 图觅 (TraceItem) 局域网服务自动发现指南 (mDNS + Avahi 组播反射)

本文档说明如何让容器化部署的 TraceItem 后端在家庭局域网中被 Flutter 移动端一键自动发现。

## 1. 工作原理

- **后端广播**：`server/app/services/mdns_discovery.py` 在 FastAPI 启动时通过 `AsyncZeroconf` 广播 `_traceitem._tcp.local.` 服务记录，TXT 属性携带 `host`、`mappedPort`（默认 `8085`）、`url` 与 `name`。
- **容器桥接打通**：Docker 默认桥接网段与物理局域网隔离组播报文（`224.0.0.251:5353`）。通过固定网桥名 `br-traceitem`（`traceitem_mdns`）并在宿主机开启 `avahi-daemon` 的 `enable-reflector=yes`，即可将容器内 mDNS 广播反射至家庭 WiFi。
- **移动端发现**：手机端在登录页服务配置或「系统设置 -> 内外网地址配置」点击「自动发现内网服务」后，扫描 `_traceitem._tcp` 并自动填充 `http://<宿主机IP>:<端口>`。

## 2. 宿主机一次性初始化

在 Linux NAS / 服务器宿主机执行：

```bash
sudo bash scripts/setup_avahi_traceitem.sh
```

若宿主机存在多张网卡，建议在 `.env` 或 `docker-compose.yml` 中显式设置 `SERVICE_ADVERTISE_HOST=<宿主机局域网IP>`（例如 `192.168.7.186`）与 `SERVICE_ADVERTISE_PORT=8085`。

## 3. 验证广播是否生效

```bash
avahi-browse -atr | grep -i traceitem
```

