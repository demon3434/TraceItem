import asyncio
import sys
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from fastapi.testclient import TestClient

from app.main import app
from app.services.mdns_discovery import (
    SERVICE_TYPE,
    ServiceDiscoveryBroadcaster,
    detect_local_ip,
    is_valid_lan_ip,
    resolve_advertise_port,
)


def test_health_and_api_health_endpoints(monkeypatch, tmp_path):
    from sqlalchemy import create_engine, event
    from sqlalchemy.orm import sessionmaker

    import app.db.init_db as init_db_module
    import app.db.session as session_module
    from app.core.config import settings

    monkeypatch.setenv("DISABLE_MDNS", "1")
    monkeypatch.setattr(settings, "DATA_DIR", tmp_path / "data")
    monkeypatch.setattr(settings, "MEDIA_DIR", tmp_path / "data" / "media")
    settings.ensure_directories()

    test_engine = create_engine(
        settings.SQLITE_URL,
        connect_args={"check_same_thread": False, "timeout": 30.0},
    )

    @event.listens_for(test_engine, "connect")
    def _set_pragma(dbapi_conn, _):
        cur = dbapi_conn.cursor()
        cur.execute("PRAGMA foreign_keys = ON;")
        cur.execute("PRAGMA journal_mode = WAL;")
        cur.execute("PRAGMA synchronous = NORMAL;")
        cur.close()

    test_session_local = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)
    monkeypatch.setattr(session_module, "engine", test_engine)
    monkeypatch.setattr(session_module, "SessionLocal", test_session_local)
    monkeypatch.setattr(init_db_module, "engine", test_engine)
    monkeypatch.setattr(init_db_module, "SessionLocal", test_session_local)

    try:
        with TestClient(app) as client:
            for path in ("/health", "/api/health"):
                res = client.get(path)
                assert res.status_code == 200, f"{path} failed: {res.text}"
                payload = res.json()
                assert payload["code"] == 0
                assert payload["message"] == "healthy"
                assert payload["data"]["status"] == "online"
                assert "server_instance_id" in payload["data"]
                assert len(payload["data"]["server_instance_id"]) >= 32

            config_res = client.get("/api/auth/config")
            assert config_res.status_code == 200
            config_payload = config_res.json()
            assert "server_instance_id" in config_payload["data"]
            assert config_payload["data"]["server_instance_id"] == payload["data"]["server_instance_id"]
    finally:
        test_engine.dispose()


def test_ip_filtering_in_docker_vs_host():
    assert not is_valid_lan_ip("127.0.0.1", in_docker=False)
    assert not is_valid_lan_ip("169.254.1.10", in_docker=False)
    assert not is_valid_lan_ip("172.17.0.2", in_docker=True)
    assert is_valid_lan_ip("172.20.10.3", in_docker=False)
    assert is_valid_lan_ip("192.168.7.186", in_docker=True)


def test_detect_local_ip_prefers_env(monkeypatch):
    monkeypatch.setenv("SERVICE_ADVERTISE_HOST", "192.168.7.186")
    assert detect_local_ip() == "192.168.7.186"


def test_resolve_advertise_port(monkeypatch):
    monkeypatch.setenv("SERVICE_ADVERTISE_PORT", "8085")
    assert resolve_advertise_port(8000) == 8085
    assert resolve_advertise_port(9000) == 9000


def test_broadcaster_start_and_stop(monkeypatch):
    monkeypatch.delenv("DISABLE_MDNS", raising=False)
    fake_zc = MagicMock()
    fake_zc.async_register_service = AsyncMock()
    fake_zc.async_unregister_service = AsyncMock()
    fake_zc.async_close = AsyncMock()

    async def _run():
        broadcaster = ServiceDiscoveryBroadcaster()
        with patch("app.services.mdns_discovery.AsyncZeroconf", return_value=fake_zc):
            started = await broadcaster.start(host="192.168.7.186", port=8085)
            assert started is True
            assert broadcaster.info is not None
            assert broadcaster.info.type == SERVICE_TYPE
            assert broadcaster.info.port == 8085
            assert broadcaster.info.properties[b"url"] == b"http://192.168.7.186:8085"
            fake_zc.async_register_service.assert_awaited_once()

            await broadcaster.stop()
            fake_zc.async_unregister_service.assert_awaited_once()
            fake_zc.async_close.assert_awaited_once()
            assert broadcaster.aiozc is None

    asyncio.run(_run())

