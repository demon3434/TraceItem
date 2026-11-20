import os
import struct
from pathlib import Path
from typing import List, NamedTuple

_CONTAINER_BOXES = {b"moov", b"trak", b"mdia", b"minf", b"stbl"}


class _Mp4Atom(NamedTuple):
    atom_type: bytes
    offset: int
    size: int


def _scan_top_level_atoms(f, total_len: int) -> List[_Mp4Atom]:
    """扫描 MP4 顶层 Atom/Box 列表"""
    atoms: List[_Mp4Atom] = []
    pos = 0
    while pos + 8 <= total_len:
        f.seek(pos)
        header = f.read(8)
        if len(header) < 8:
            break
        size, atom_type = struct.unpack(">I4s", header)
        header_len = 8

        if size == 1:
            if pos + 16 > total_len:
                break
            ext = f.read(8)
            if len(ext) < 8:
                break
            (size,) = struct.unpack(">Q", ext)
            header_len = 16
        elif size == 0:
            size = total_len - pos

        if size < header_len or pos + size > total_len:
            break
        atoms.append(_Mp4Atom(atom_type=atom_type, offset=pos, size=size))
        pos += size
    return atoms


def _patch_moov_offsets(buf: bytearray, start: int, end: int, delta: int) -> None:
    """递归修正 moov 内 stco / co64 的 chunk 偏移量"""
    pos = start
    while pos + 8 <= end:
        size, atom_type = struct.unpack_from(">I4s", buf, pos)
        header_len = 8

        if size == 1:
            if pos + 16 > end:
                break
            (size,) = struct.unpack_from(">Q", buf, pos + 8)
            header_len = 16
        elif size == 0:
            size = end - pos

        if size < header_len or pos + size > end:
            break

        body_start = pos + header_len
        box_end = pos + size

        if atom_type in _CONTAINER_BOXES:
            _patch_moov_offsets(buf, body_start, box_end, delta)
        elif atom_type == b"stco" and body_start + 8 <= box_end:
            (count,) = struct.unpack_from(">I", buf, body_start + 4)
            entry_pos = body_start + 8
            for _ in range(count):
                if entry_pos + 4 > box_end:
                    break
                (old_offset,) = struct.unpack_from(">I", buf, entry_pos)
                struct.pack_into(">I", buf, entry_pos, old_offset + delta)
                entry_pos += 4
        elif atom_type == b"co64" and body_start + 8 <= box_end:
            (count,) = struct.unpack_from(">I", buf, body_start + 4)
            entry_pos = body_start + 8
            for _ in range(count):
                if entry_pos + 8 > box_end:
                    break
                (old_offset,) = struct.unpack_from(">Q", buf, entry_pos)
                struct.pack_into(">Q", buf, entry_pos, old_offset + delta)
                entry_pos += 8

        pos = box_end


def _copy_range(src, dst, offset: int, length: int) -> None:
    src.seek(offset)
    remaining = length
    chunk_size = 64 * 1024
    while remaining > 0:
        chunk = src.read(min(chunk_size, remaining))
        if not chunk:
            break
        dst.write(chunk)
        remaining -= len(chunk)


def ensure_moov_first(file_path: Path) -> bool:
    """
    检查并确保 MP4/MOV 文件的 moov atom 位于 mdat 之前（+faststart）。
    返回 True 表示执行了重排；False 表示已前置或无需处理。
    """
    if not file_path.exists():
        return False

    total_len = file_path.stat().st_size
    if total_len < 16:
        return False

    with open(file_path, "rb") as f:
        atoms = _scan_top_level_atoms(f, total_len)
        moov_idx = next((i for i, a in enumerate(atoms) if a.atom_type == b"moov"), -1)
        mdat_idx = next((i for i, a in enumerate(atoms) if a.atom_type == b"mdat"), -1)
        has_moof = any(a.atom_type == b"moof" for a in atoms)

        if moov_idx < 0 or mdat_idx < 0 or has_moof or moov_idx < mdat_idx:
            return False

        moov_atom = atoms[moov_idx]
        f.seek(moov_atom.offset)
        moov_bytes = bytearray(f.read(moov_atom.size))
        if len(moov_bytes) != moov_atom.size:
            return False

        _patch_moov_offsets(moov_bytes, 0, len(moov_bytes), moov_atom.size)

        tmp_path = file_path.with_suffix(file_path.suffix + ".faststart.tmp")
        with open(tmp_path, "wb") as out:
            for i in range(mdat_idx):
                _copy_range(f, out, atoms[i].offset, atoms[i].size)
            out.write(moov_bytes)
            for i in range(mdat_idx, len(atoms)):
                if i == moov_idx:
                    continue
                _copy_range(f, out, atoms[i].offset, atoms[i].size)

    os.replace(tmp_path, file_path)
    return True

