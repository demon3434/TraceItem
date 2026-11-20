import hashlib
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from app.core.config import settings


@dataclass(frozen=True)
class AsrModelSpec:
    id: str
    name: str
    engine_type: str
    badge: str
    description: str
    archive_candidates: tuple[str, ...]
    approx_size_mb: int
    recommended: bool = False


_MODEL_SPECS: tuple[AsrModelSpec, ...] = (
    AsrModelSpec(
        id="sensevoice_small_int8",
        name="SenseVoiceSmall (int8)",
        engine_type="offline_sensevoice",
        badge="中文高精度",
        description="松手整句识别，普通话、方言与中英混杂准确率极高，自带标点",
        archive_candidates=(
            "sensevoice_small_int8.tar.gz",
            "sensevoice_small_int8.tar.bz2",
        ),
        approx_size_mb=230,
        recommended=True,
    ),
    AsrModelSpec(
        id="streaming_zipformer_zh_en_int8",
        name="Streaming Zipformer (int8)",
        engine_type="streaming_zipformer",
        badge="轻量实时流式",
        description="边说边实时出字，内存占用极低（约 100MB），适合低配机型",
        archive_candidates=(
            "streaming_zipformer_zh_en_int8.tar.gz",
            "streaming_zipformer_zh_en_int8.tar.bz2",
        ),
        approx_size_mb=95,
        recommended=False,
    ),
)

_SHA256_CACHE: dict[str, tuple[int, int, str]] = {}


def _compute_sha256_cached(path: Path) -> str:
    stat = path.stat()
    key = str(path)
    cached = _SHA256_CACHE.get(key)
    if cached and cached[0] == stat.st_mtime_ns and cached[1] == stat.st_size:
        return cached[2]

    digest = hashlib.sha256()
    with path.open("rb") as f:
        while chunk := f.read(1024 * 1024):
            digest.update(chunk)
    hex_val = digest.hexdigest()
    _SHA256_CACHE[key] = (stat.st_mtime_ns, stat.st_size, hex_val)
    return hex_val


def resolve_model_archive(model_id: str) -> Optional[tuple[AsrModelSpec, Path]]:
    """根据 model_id 查找对应的服务端模型归档文件"""
    models_dir = settings.ASR_MODELS_DIR
    for spec in _MODEL_SPECS:
        if spec.id != model_id:
            continue
        for filename in spec.archive_candidates:
            candidate = models_dir / filename
            if candidate.is_file():
                return spec, candidate
        return spec, models_dir / spec.archive_candidates[0]
    return None


def list_asr_models() -> list[dict]:
    """列出全部支持的端侧 ASR 模型及服务端就绪状态（零推理开销）"""
    models_dir = settings.ASR_MODELS_DIR
    result: list[dict] = []
    for spec in _MODEL_SPECS:
        found_path: Optional[Path] = None
        for filename in spec.archive_candidates:
            candidate = models_dir / filename
            if candidate.is_file():
                found_path = candidate
                break

        available = found_path is not None
        size_bytes = found_path.stat().st_size if found_path else 0
        sha256 = _compute_sha256_cached(found_path) if found_path else ""
        archive_name = found_path.name if found_path else spec.archive_candidates[0]

        result.append(
            {
                "id": spec.id,
                "name": spec.name,
                "engine_type": spec.engine_type,
                "badge": spec.badge,
                "description": spec.description,
                "archive_name": archive_name,
                "approx_size_mb": spec.approx_size_mb,
                "size_bytes": size_bytes,
                "sha256": sha256,
                "recommended": spec.recommended,
                "available_on_server": available,
                "download_path": f"/asr/models/{spec.id}/download",
            }
        )
    return result

