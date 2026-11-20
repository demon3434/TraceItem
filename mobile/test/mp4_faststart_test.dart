import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:traceitem_mobile/core/mp4_faststart.dart';

Uint8List _box(String type, Uint8List body) {
  final total = 8 + body.length;
  final out = Uint8List(total);
  ByteData.sublistView(out).setUint32(0, total, Endian.big);
  out.setRange(4, 8, type.codeUnits);
  out.setRange(8, total, body);
  return out;
}

Uint8List _stco(List<int> offsets) {
  final body = Uint8List(8 + offsets.length * 4);
  final bd = ByteData.sublistView(body);
  bd.setUint32(4, offsets.length, Endian.big);
  for (var i = 0; i < offsets.length; i++) {
    bd.setUint32(8 + i * 4, offsets[i], Endian.big);
  }
  return _box('stco', body);
}

List<int> _readStcoOffsets(Uint8List data, int moovStart, int moovSize) {
  final end = moovStart + moovSize;
  var pos = moovStart + 8;
  while (pos + 8 <= end) {
    final bd = ByteData.sublistView(data);
    final size = bd.getUint32(pos, Endian.big);
    final type = String.fromCharCodes(data.sublist(pos + 4, pos + 8));
    if (type == 'trak' || type == 'mdia' || type == 'minf' || type == 'stbl') {
      pos += 8;
      continue;
    }
    if (type == 'stco') {
      final count = bd.getUint32(pos + 12, Endian.big);
      return List.generate(
        count,
        (i) => bd.getUint32(pos + 16 + i * 4, Endian.big),
      );
    }
    pos += size;
  }
  return [];
}

List<String> _topLevelTypes(Uint8List data) {
  final types = <String>[];
  var pos = 0;
  final bd = ByteData.sublistView(data);
  while (pos + 8 <= data.length) {
    final size = bd.getUint32(pos, Endian.big);
    types.add(String.fromCharCodes(data.sublist(pos + 4, pos + 8)));
    pos += size;
  }
  return types;
}

void main() {
  test('moves trailing moov before mdat and shifts stco offsets', () async {
    final tmpDir = await Directory.systemTemp.createTemp('mp4_fs_test_');
    try {
      final ftyp = _box('ftyp', Uint8List.fromList([0, 0, 0, 1]));
      final mdat = _box('mdat', Uint8List(100));
      final mdatDataStart = ftyp.length + 8;

      final stbl = _box('stbl', _stco([mdatDataStart, mdatDataStart + 40]));
      final moov = _box('moov', _box('trak', _box('mdia', _box('minf', stbl))));

      final file = File('${tmpDir.path}/sample.mp4');
      await file.writeAsBytes([...ftyp, ...mdat, ...moov]);

      final resultPath = await Mp4Faststart.ensureMoovFirst(file.path);
      expect(resultPath, file.path);

      final updated = await file.readAsBytes();
      expect(_topLevelTypes(updated), ['ftyp', 'moov', 'mdat']);

      final offsets = _readStcoOffsets(updated, ftyp.length, moov.length);
      expect(offsets, [
        mdatDataStart + moov.length,
        mdatDataStart + 40 + moov.length,
      ]);

      // 再次调用应幂等跳过
      await Mp4Faststart.ensureMoovFirst(file.path);
      expect(await file.readAsBytes(), updated);
    } finally {
      await tmpDir.delete(recursive: true);
    }
  });
}

