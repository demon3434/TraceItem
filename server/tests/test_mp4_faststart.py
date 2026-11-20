import struct
from pathlib import Path

from app.services.mp4_faststart import ensure_moov_first


def _box(atom_type: bytes, body: bytes) -> bytes:
    return struct.pack(">I4s", 8 + len(body), atom_type) + body


def _stco(offsets: list[int]) -> bytes:
    body = struct.pack(">II", 0, len(offsets)) + b"".join(
        struct.pack(">I", o) for o in offsets
    )
    return _box(b"stco", body)


def _top_level_types(data: bytes) -> list[bytes]:
    types = []
    pos = 0
    while pos + 8 <= len(data):
        size, atom_type = struct.unpack_from(">I4s", data, pos)
        types.append(atom_type)
        pos += size
    return types


def _extract_stco_offsets(data: bytes, moov_start: int, moov_size: int) -> list[int]:
    pos = moov_start + 8
    end = moov_start + moov_size
    while pos + 8 <= end:
        size, atom_type = struct.unpack_from(">I4s", data, pos)
        if atom_type in {b"trak", b"mdia", b"minf", b"stbl"}:
            pos += 8
            continue
        if atom_type == b"stco":
            (count,) = struct.unpack_from(">I", data, pos + 12)
            return [
                struct.unpack_from(">I", data, pos + 16 + i * 4)[0]
                for i in range(count)
            ]
        pos += size
    return []


def test_ensure_moov_first_reorders_and_patches_stco(tmp_path: Path):
    ftyp = _box(b"ftyp", b"isom")
    mdat = _box(b"mdat", b"\xaa" * 64)
    mdat_data_start = len(ftyp) + 8
    stbl = _box(b"stbl", _stco([mdat_data_start, mdat_data_start + 32]))
    moov = _box(b"moov", _box(b"trak", _box(b"mdia", _box(b"minf", stbl))))

    mp4_path = tmp_path / "video.mp4"
    mp4_path.write_bytes(ftyp + mdat + moov)

    assert ensure_moov_first(mp4_path) is True
    updated = mp4_path.read_bytes()
    assert _top_level_types(updated) == [b"ftyp", b"moov", b"mdat"]
    assert _extract_stco_offsets(updated, len(ftyp), len(moov)) == [
        mdat_data_start + len(moov),
        mdat_data_start + 32 + len(moov),
    ]

    # 已前置时应返回 False 且不修改文件
    assert ensure_moov_first(mp4_path) is False
    assert mp4_path.read_bytes() == updated

