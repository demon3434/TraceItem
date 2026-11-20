import shutil
import tarfile
import tempfile
import threading
import urllib.request
from pathlib import Path

from app.core.config import settings

_MODEL_DOWNLOAD_SOURCES: tuple[tuple[str, tuple[str, ...], tuple[str, ...]], ...] = (
    (
        "sensevoice_small_int8",
        (
            "https://modelscope.cn/models/mariolux/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/master",
            "https://hf-mirror.com/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main",
        ),
        ("model.int8.onnx", "tokens.txt"),
    ),
    (
        "streaming_zipformer_zh_en_int8",
        (
            "https://modelscope.cn/models/pengzhendong/sherpa-onnx-streaming-zipformer-bilingual-zh-en/resolve/master",
            "https://hf-mirror.com/csukuangfj/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20/resolve/main",
        ),
        (
            "encoder-epoch-99-avg-1.int8.onnx",
            "decoder-epoch-99-avg-1.int8.onnx",
            "joiner-epoch-99-avg-1.int8.onnx",
            "tokens.txt",
        ),
    ),
)

_BOOTSTRAP_LOCK = threading.Lock()


def _download_with_fallback(base_urls: tuple[str, ...], fname: str, dest: Path) -> None:
    last_err: Exception | None = None
    for base in base_urls:
        url = f"{base}/{fname}"
        try:
            print(f"[ASR Bootstrap] 正在拉取 {url}", flush=True)
            req = urllib.request.Request(
                url,
                headers={"User-Agent": "TraceItem-Server/1.0"},
            )
            with urllib.request.urlopen(req, timeout=900) as resp, dest.open("wb") as out:
                shutil.copyfileobj(resp, out, length=512 * 1024)
            return
        except Exception as exc:
            last_err = exc
            print(f"[ASR Bootstrap] 源失败 ({url}): {exc}", flush=True)
    raise RuntimeError(f"所有国内镜像源均下载失败 ({fname}): {last_err}")


def _ensure_single_model(
    model_id: str,
    base_urls: tuple[str, ...],
    files: tuple[str, ...],
) -> None:
    models_dir = settings.ASR_MODELS_DIR
    models_dir.mkdir(parents=True, exist_ok=True)
    target_gz = models_dir / f"{model_id}.tar.gz"
    target_bz2 = models_dir / f"{model_id}.tar.bz2"
    if target_gz.is_file() or target_bz2.is_file():
        return

    tmp_archive = models_dir / f".{model_id}.tar.gz.tmp"
    try:
        with tempfile.TemporaryDirectory(prefix=f"asr_{model_id}_") as tmpdir:
            tmp_root = Path(tmpdir)
            for fname in files:
                _download_with_fallback(base_urls, fname, tmp_root / fname)

            print(f"[ASR Bootstrap] 正在打包 {model_id}.tar.gz ...", flush=True)
            with tarfile.open(tmp_archive, "w:gz") as tar:
                for fname in files:
                    tar.add(tmp_root / fname, arcname=fname)

        tmp_archive.replace(target_gz)
        size_mb = target_gz.stat().st_size / (1024 * 1024)
        print(f"[ASR Bootstrap] ✓ 模型 {model_id} 初始化就绪 ({size_mb:.1f} MB)", flush=True)
    except Exception as exc:
        print(f"[ASR Bootstrap] 模型 {model_id} 初始化失败: {exc}", flush=True)
        if tmp_archive.exists():
            tmp_archive.unlink(missing_ok=True)


def _run_bootstrap() -> None:
    if not _BOOTSTRAP_LOCK.acquire(blocking=False):
        return
    try:
        for model_id, base_urls, files in _MODEL_DOWNLOAD_SOURCES:
            _ensure_single_model(model_id, base_urls, files)
    finally:
        _BOOTSTRAP_LOCK.release()


def ensure_asr_models_background() -> None:
    """服务启动时在后台线程自动从国内镜像下载缺失的端侧 ASR 模型"""
    if not settings.ASR_AUTO_DOWNLOAD_MODELS:
        return
    t = threading.Thread(
        target=_run_bootstrap,
        name="asr-model-bootstrap",
        daemon=True,
    )
    t.start()
