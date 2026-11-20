import 'dart:io';
import 'dart:typed_data';

/// 纯 Dart 实现的 MP4/MOV `moov` 前置重排工具 (+faststart)。
///
/// 仅解析顶层 Atom/Box 头并在 `moov` 位于 `mdat` 之后时，将其移至 `mdat` 之前，
/// 同时修正 `moov -> trak -> mdia -> minf -> stbl` 内的 `stco` / `co64` 偏移量。
class Mp4Faststart {
  static const _containerBoxes = {'moov', 'trak', 'mdia', 'minf', 'stbl'};

  /// 确保 [sourcePath] 的 `moov` 位于 `mdat` 之前。
  ///
  /// 若已前置或非标准 MP4，直接返回 [sourcePath]；
  /// 若需要重排：当 [inPlace] 为 true 时原地替换并返回 [sourcePath]，
  /// 否则写入 [Directory.systemTemp] 下的新临时文件并返回其路径（不修改原图库文件）。
  static Future<String> ensureMoovFirst(
    String sourcePath, {
    bool inPlace = true,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) return sourcePath;

    final raf = await file.open(mode: FileMode.read);
    try {
      final totalLen = await raf.length();
      if (totalLen < 16) return sourcePath;

      final atoms = await _scanTopLevelAtoms(raf, totalLen);
      final moovIdx = atoms.indexWhere((a) => a.type == 'moov');
      final mdatIdx = atoms.indexWhere((a) => a.type == 'mdat');
      final hasMoof = atoms.any((a) => a.type == 'moof');

      // 缺少 moov/mdat、分片 MP4 或 moov 已在 mdat 之前时无需重排
      if (moovIdx < 0 || mdatIdx < 0 || hasMoof || moovIdx < mdatIdx) {
        return sourcePath;
      }

      final moovAtom = atoms[moovIdx];
      await raf.setPosition(moovAtom.offset);
      final moovBytes = await raf.read(moovAtom.size);
      if (moovBytes.length != moovAtom.size) {
        return sourcePath;
      }

      // 将 moov 插到 mdat 之前，mdat 及中间 box 整体后移 moovAtom.size 字节
      final patchedMoov = Uint8List.fromList(moovBytes);
      _patchMoovOffsets(patchedMoov, 0, patchedMoov.length, moovAtom.size);

      final outPath = inPlace
          ? '$sourcePath.faststart.tmp'
          : '${Directory.systemTemp.path}${Platform.pathSeparator}'
              'traceitem_fs_${DateTime.now().microsecondsSinceEpoch}.mp4';
      final outFile = File(outPath);
      final sink = outFile.openWrite();

      try {
        // 1. 写入 mdat 之前的所有 box（如 ftyp、free）
        for (var i = 0; i < mdatIdx; i++) {
          await _copyRange(raf, sink, atoms[i].offset, atoms[i].size);
        }
        // 2. 写入修正偏移后的 moov
        sink.add(patchedMoov);
        // 3. 写入 mdat 及剩余 box（跳过原 moov）
        for (var i = mdatIdx; i < atoms.length; i++) {
          if (i == moovIdx) continue;
          await _copyRange(raf, sink, atoms[i].offset, atoms[i].size);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (inPlace) {
        await raf.close();
        await outFile.rename(sourcePath);
        return sourcePath;
      }
      return outPath;
    } finally {
      try {
        await raf.close();
      } catch (_) {}
    }
  }

  static Future<List<_Mp4Atom>> _scanTopLevelAtoms(
    RandomAccessFile raf,
    int totalLen,
  ) async {
    final atoms = <_Mp4Atom>[];
    var pos = 0;
    while (pos + 8 <= totalLen) {
      await raf.setPosition(pos);
      final header = await raf.read(8);
      if (header.length < 8) break;

      final bd = ByteData.sublistView(header);
      var size = bd.getUint32(0, Endian.big);
      final type = String.fromCharCodes(header.sublist(4, 8));
      var headerLen = 8;

      if (size == 1) {
        if (pos + 16 > totalLen) break;
        final ext = await raf.read(8);
        if (ext.length < 8) break;
        size = ByteData.sublistView(ext).getUint64(0, Endian.big);
        headerLen = 16;
      } else if (size == 0) {
        size = totalLen - pos;
      }

      if (size < headerLen || pos + size > totalLen) break;
      atoms.add(_Mp4Atom(type: type, offset: pos, size: size));
      pos += size;
    }
    return atoms;
  }

  static void _patchMoovOffsets(
    Uint8List buf,
    int start,
    int end,
    int delta,
  ) {
    final bd = ByteData.sublistView(buf);
    var pos = start;
    while (pos + 8 <= end) {
      var size = bd.getUint32(pos, Endian.big);
      final type = String.fromCharCodes(buf.sublist(pos + 4, pos + 8));
      var headerLen = 8;

      if (size == 1) {
        if (pos + 16 > end) break;
        size = bd.getUint64(pos + 8, Endian.big);
        headerLen = 16;
      } else if (size == 0) {
        size = end - pos;
      }

      if (size < headerLen || pos + size > end) break;
      final bodyStart = pos + headerLen;
      final boxEnd = pos + size;

      if (_containerBoxes.contains(type)) {
        _patchMoovOffsets(buf, bodyStart, boxEnd, delta);
      } else if (type == 'stco' && bodyStart + 8 <= boxEnd) {
        final count = bd.getUint32(bodyStart + 4, Endian.big);
        var entryPos = bodyStart + 8;
        for (var i = 0; i < count && entryPos + 4 <= boxEnd; i++) {
          final oldOffset = bd.getUint32(entryPos, Endian.big);
          bd.setUint32(entryPos, oldOffset + delta, Endian.big);
          entryPos += 4;
        }
      } else if (type == 'co64' && bodyStart + 8 <= boxEnd) {
        final count = bd.getUint32(bodyStart + 4, Endian.big);
        var entryPos = bodyStart + 8;
        for (var i = 0; i < count && entryPos + 8 <= boxEnd; i++) {
          final oldOffset = bd.getUint64(entryPos, Endian.big);
          bd.setUint64(entryPos, oldOffset + delta, Endian.big);
          entryPos += 8;
        }
      }

      pos = boxEnd;
    }
  }

  static Future<void> _copyRange(
    RandomAccessFile raf,
    IOSink sink,
    int offset,
    int length,
  ) async {
    await raf.setPosition(offset);
    var remaining = length;
    const chunkSize = 64 * 1024;
    while (remaining > 0) {
      final toRead = remaining > chunkSize ? chunkSize : remaining;
      final chunk = await raf.read(toRead);
      if (chunk.isEmpty) break;
      sink.add(chunk);
      remaining -= chunk.length;
    }
  }
}

class _Mp4Atom {
  final String type;
  final int offset;
  final int size;

  const _Mp4Atom({
    required this.type,
    required this.offset,
    required this.size,
  });
}

