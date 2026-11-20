#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
AVAHI_CONF="/etc/avahi/avahi-daemon.conf"
DOCKER_NETWORK_NAME="traceitem_mdns"
DOCKER_BRIDGE_IFACE="br-traceitem"

log() { printf '[%s] %s\n' "$SCRIPT_NAME" "$*"; }
warn() { printf '[%s] WARN: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { printf '[%s] ERROR: %s\n' "$SCRIPT_NAME" "$*" >&2; exit 1; }

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "请以 root 权限运行本脚本，例如: sudo bash $SCRIPT_NAME"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "未找到命令: $1"
}

install_avahi() {
  log "正在检查并安装 Avahi 守护进程..."
  export DEBIAN_FRONTEND=noninteractive
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y avahi-daemon avahi-utils
  elif command -v yum >/dev/null 2>&1; then
    yum install -y avahi avahi-tools
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y avahi avahi-tools
  else
    warn "未能识别包管理器，请手动确认已安装 avahi-daemon"
  fi
}

ensure_docker_bridge_network() {
  log "检查并创建 Docker 网络 '${DOCKER_NETWORK_NAME}' (网桥: '${DOCKER_BRIDGE_IFACE}')..."
  if docker network inspect "$DOCKER_NETWORK_NAME" >/dev/null 2>&1; then
    local iface
    iface="$(docker network inspect -f '{{ index .Options "com.docker.network.bridge.name" }}' "$DOCKER_NETWORK_NAME" 2>/dev/null || true)"
    if [[ "$iface" != "$DOCKER_BRIDGE_IFACE" ]]; then
      die "网络 '$DOCKER_NETWORK_NAME' 已存在但网桥名称为 '$iface' (预期 '$DOCKER_BRIDGE_IFACE')，请移除旧网络后重试: docker network rm $DOCKER_NETWORK_NAME"
    fi
    log "Docker 网络 '$DOCKER_NETWORK_NAME' 配置正确。"
    return
  fi

  docker network create \
    --driver bridge \
    --label "com.docker.compose.network=${DOCKER_NETWORK_NAME}" \
    --opt "com.docker.network.bridge.name=${DOCKER_BRIDGE_IFACE}" \
    "$DOCKER_NETWORK_NAME" >/dev/null
  log "已成功创建 Docker 网络 '$DOCKER_NETWORK_NAME'。"
}

detect_uplink_iface() {
  local iface
  iface="$(ip -o route show default 2>/dev/null | awk '{print $5}' | head -n1 || true)"
  [[ -n "$iface" ]] || die "无法自动检测到默认物理网卡接口。"
  printf '%s\n' "$iface"
}

write_avahi_config() {
  local uplink_iface="$1"
  local existing_ifaces=""
  if [[ -f "$AVAHI_CONF" ]]; then
    existing_ifaces="$(grep -E '^allow-interfaces=' "$AVAHI_CONF" | cut -d'=' -f2 | tr ',' ' ' || true)"
  fi

  # 合并并去重接口列表，确保兼容共存宿主机其他业务容器的网桥（如 br-nuthollow, br-sproutmemo）
  local all_ifaces=("$uplink_iface" "$DOCKER_BRIDGE_IFACE" $existing_ifaces)
  local unique_ifaces=($(printf "%s\n" "${all_ifaces[@]}" | grep -v '^$' | sort -u))
  local allow_interfaces=$(IFS=,; echo "${unique_ifaces[*]}")
  local backup_path=""

  if [[ -f "$AVAHI_CONF" ]]; then
    backup_path="${AVAHI_CONF}.bak.$(date +%Y%m%d%H%M%S)"
    cp -a "$AVAHI_CONF" "$backup_path"
    log "已备份当前 Avahi 配置到: $backup_path"
  fi

  cat >"$AVAHI_CONF" <<EOF
[server]
use-ipv4=yes
use-ipv6=no
allow-interfaces=${allow_interfaces}

[reflector]
enable-reflector=yes
EOF

  log "已写入 Avahi 配置文件: $AVAHI_CONF"
  log "监听接口列表: ${allow_interfaces}"
}

restart_avahi() {
  log "重启并启用 avahi-daemon 守护进程..."
  systemctl enable avahi-daemon >/dev/null 2>&1 || true
  systemctl restart avahi-daemon
  systemctl --no-pager --full status avahi-daemon | sed -n '1,12p' || true
}

main() {
  require_root
  require_cmd ip
  require_cmd docker
  require_cmd systemctl

  install_avahi
  ensure_docker_bridge_network
  local uplink_iface
  uplink_iface="$(detect_uplink_iface)"
  log "检测到默认物理上行网卡: ${uplink_iface}"
  write_avahi_config "$uplink_iface"
  restart_avahi
  log "TraceItem mDNS 组播反射配置完成！请随后执行 docker compose up -d --build 启动服务。"
}

main "$@"

