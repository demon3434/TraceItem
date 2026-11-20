import logging
import os
import socket
from typing import Optional

from zeroconf import IPVersion, ServiceInfo
from zeroconf.asyncio import AsyncZeroconf

logger = logging.getLogger("TraceItem.mdns_discovery")

SERVICE_TYPE = "_traceitem._tcp.local."
SERVICE_NAME = "TraceItem-Server"


def is_running_in_docker() -> bool:
    """判断当前服务是否运行在 Docker 容器内"""
    return os.path.exists("/.dockerenv") or os.path.exists("/run/.containerenv")


def is_valid_lan_ip(ip: str, in_docker: Optional[bool] = None) -> bool:
    """校验是否为有效的宿主机局域网 IPv4 地址"""
    if not ip:
        return False
    if ip.startswith("127.") or ip.startswith("169.254."):
        return False
    if in_docker is None:
        in_docker = is_running_in_docker()
    # 容器内过滤 Docker 默认 172.x 桥接网段，避免向手机端广播容器内网 IP
    if in_docker and ip.startswith("172."):
        return False
    return True


def detect_local_ip() -> str:
    """
    智能探测宿主机真实的局域网 IPv4 地址：
    - 优先读取显式环境变量 (SERVICE_ADVERTISE_HOST, MDNS_HOST, HOST_IP)
    - 容器内自动过滤 172.x 内部网桥 IP
    """
    env_host = (
        os.getenv("SERVICE_ADVERTISE_HOST")
        or os.getenv("MDNS_HOST")
        or os.getenv("HOST_IP")
    )
    if env_host and env_host.strip():
        return env_host.strip()

    in_docker = is_running_in_docker()

    for target in (("8.8.8.8", 80), ("192.168.255.255", 1)):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.connect(target)
                ip = s.getsockname()[0]
                if is_valid_lan_ip(ip, in_docker=in_docker):
                    return ip
        except Exception:
            pass

    try:
        ip = socket.gethostbyname(socket.gethostname())
        if is_valid_lan_ip(ip, in_docker=in_docker):
            return ip
    except Exception:
        pass

    return "127.0.0.1"


def resolve_advertise_port(port: Optional[int] = None) -> int:
    """解析对外通告的端口（Docker 部署默认映射宿主机 8085）"""
    env_port = (
        os.getenv("SERVICE_ADVERTISE_PORT")
        or os.getenv("HOST_PORT")
        or os.getenv("WEB_PORT")
    )
    if port is None or port == 8000:
        if env_port and str(env_port).strip().isdigit():
            return int(env_port.strip())
        return 8085 if is_running_in_docker() else 8000
    return int(port)


class ServiceDiscoveryBroadcaster:
    """基于 AsyncZeroconf 的 mDNS / DNS-SD 异步局域网广播服务"""

    def __init__(self) -> None:
        self.aiozc: Optional[AsyncZeroconf] = None
        self.info: Optional[ServiceInfo] = None
        self.active_host: Optional[str] = None
        self.active_port: Optional[int] = None

    async def start(
        self,
        host: Optional[str] = None,
        port: Optional[int] = None,
    ) -> bool:
        await self.stop()

        if os.getenv("DISABLE_MDNS", "").strip() in ("1", "true", "TRUE"):
            return False

        if not host or host in ("0.0.0.0", "127.0.0.1"):
            host = detect_local_ip()

        resolved_port = resolve_advertise_port(port)
        self.active_host = host.strip()
        self.active_port = resolved_port

        try:
            self.aiozc = AsyncZeroconf(ip_version=IPVersion.V4Only)
            ip_bytes = socket.inet_aton(self.active_host)
            instance_name = f"{SERVICE_NAME}.{SERVICE_TYPE}"

            properties = {
                b"host": self.active_host.encode("utf-8"),
                b"mappedPort": str(self.active_port).encode("utf-8"),
                b"url": f"http://{self.active_host}:{self.active_port}".encode("utf-8"),
                b"name": "图觅".encode("utf-8"),
                b"version": b"1.0",
                b"path": b"/api",
            }

            self.info = ServiceInfo(
                type_=SERVICE_TYPE,
                name=instance_name,
                addresses=[ip_bytes],
                port=self.active_port,
                properties=properties,
                server=f"{SERVICE_NAME.lower()}.local.",
            )

            await self.aiozc.async_register_service(self.info, allow_name_change=True)
            logger.info(
                "mDNS 局域网广播已启动: %s -> http://%s:%s",
                instance_name,
                self.active_host,
                self.active_port,
            )
            return True
        except Exception as exc:
            logger.warning("mDNS 广播启动失败 (不影响 HTTP 服务): %s", exc)
            await self.stop()
            return False

    async def stop(self) -> None:
        if self.aiozc:
            try:
                if self.info:
                    await self.aiozc.async_unregister_service(self.info)
            except Exception as exc:
                logger.warning("mDNS 注销广播异常: %s", exc)
            finally:
                try:
                    await self.aiozc.async_close()
                except Exception as exc:
                    logger.warning("mDNS 关闭 AsyncZeroconf 异常: %s", exc)
                self.aiozc = None
                self.info = None
                self.active_host = None
                self.active_port = None


broadcaster = ServiceDiscoveryBroadcaster()

