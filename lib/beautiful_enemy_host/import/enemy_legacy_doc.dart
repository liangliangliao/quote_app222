import 'dart:typed_data';
import 'package:enough_convert/enough_convert.dart';

/// Word 97–2003：按 OLE 流和 Word piece table 读取正文，避免扫描二进制时
/// 混入已删除文字、元数据或乱码。旧于 Word 97、加密或损坏文档明确拒绝。
String extractEnemyLegacyDoc(Uint8List data) {
  final ole = _CompoundDocument(data);
  final word = ole.stream('WordDocument');
  if (word.length < 154) throw const FormatException('Word 文档损坏，请另存为 .docx。');
  final w = ByteData.sublistView(word);
  if (w.getUint16(0, Endian.little) != 0xa5ec ||
      w.getUint16(2, Endian.little) < 0xc1) {
    throw const FormatException('此旧版 Word 格式无法读取，请另存为 .docx。');
  }
  final flags = w.getUint16(10, Endian.little);
  if (flags & 0x8100 != 0) throw const FormatException('请先移除 Word 文档密码再导入。');
  final table = ole.stream(flags & 0x200 != 0 ? '1Table' : '0Table');
  int p = 32;
  p += 2 + w.getUint16(p, Endian.little) * 2;
  p += 2 + w.getUint16(p, Endian.little) * 4;
  final pairs = w.getUint16(p, Endian.little);
  if (pairs <= 33) throw const FormatException('Word 文档没有可读取的正文。');
  p += 2 + 33 * 8;
  final start = w.getUint32(p, Endian.little);
  final length = w.getUint32(p + 4, Endian.little);
  final clx = ByteData.sublistView(table, start, start + length);
  p = 0;
  while (p < clx.lengthInBytes && clx.getUint8(p) == 1) {
    p += 3 + clx.getUint16(p + 1, Endian.little);
  }
  if (p >= clx.lengthInBytes || clx.getUint8(p) != 2) {
    throw const FormatException('Word 正文索引无法读取，请另存为 .docx。');
  }
  final pieceLength = clx.getUint32(p + 1, Endian.little);
  if (pieceLength < 4 || (pieceLength - 4) % 12 != 0)
    throw const FormatException('Word 正文索引损坏。');
  final count = (pieceLength - 4) ~/ 12;
  p += 5;
  final bodyChars = w.getUint32(76, Endian.little);
  final out = StringBuffer();
  for (int i = 0; i < count; i++) {
    final from = clx.getUint32(p + i * 4, Endian.little);
    if (from >= bodyChars) break;
    final end = clx.getUint32(p + (i + 1) * 4, Endian.little);
    final chars = (end > bodyChars ? bodyChars : end) - from;
    final fc = clx.getUint32(p + (count + 1) * 4 + i * 8 + 2, Endian.little);
    final compressed = fc & 0x40000000 != 0;
    final offset = compressed ? (fc & 0x3fffffff) ~/ 2 : fc & 0x3fffffff;
    if (compressed) {
      out.write(const Windows1252Codec()
          .decode(word.sublist(offset, offset + chars)));
    } else {
      out.write(String.fromCharCodes(List.generate(
          chars, (j) => w.getUint16(offset + j * 2, Endian.little))));
    }
    if (out.length > 60000) throw const FormatException('正文超过 60000 字，请精简后导入。');
  }
  return out
      .toString()
      .replaceAll('\r', '\n')
      .replaceAll('\u0007', '\t')
      .replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f]'), '');
}

class _CompoundDocument {
  _CompoundDocument(this.bytes) {
    if (bytes.length < 512 || _u32(0) != 0xe011cfd0 || _u32(4) != 0xe11ab1a1) {
      throw const FormatException('不是有效的 .doc 文件，请在 Word 中另存为 .docx。');
    }
    final shift = _u16(30);
    if ((shift != 9 && shift != 12) || _u16(32) != 6)
      throw const FormatException('Word 容器损坏。');
    sectorSize = 1 << shift;
    final fatSectors = <int>[];
    for (int i = 0; i < 109; i++) {
      final n = _u32(76 + i * 4);
      if (n < 0xfffffffa) fatSectors.add(n);
    }
    int next = _u32(68);
    final seen = <int>{};
    while (next < 0xfffffffa && seen.add(next)) {
      final part = ByteData.sublistView(_sector(next));
      for (int i = 0; i < sectorSize ~/ 4 - 1; i++) {
        final n = part.getUint32(i * 4, Endian.little);
        if (n < 0xfffffffa) fatSectors.add(n);
      }
      next = part.getUint32(sectorSize - 4, Endian.little);
    }
    for (final n in fatSectors) {
      final part = ByteData.sublistView(_sector(n));
      for (int i = 0; i < sectorSize; i += 4) {
        fat.add(part.getUint32(i, Endian.little));
      }
    }
    directory = _chain(_u32(48), fat, false);
  }
  final Uint8List bytes;
  late final int sectorSize;
  final List<int> fat = [];
  late final Uint8List directory;
  int _u16(int p) => ByteData.sublistView(bytes).getUint16(p, Endian.little);
  int _u32(int p) => ByteData.sublistView(bytes).getUint32(p, Endian.little);
  Uint8List _sector(int n) =>
      Uint8List.sublistView(bytes, (n + 1) * sectorSize, (n + 2) * sectorSize);

  Uint8List _chain(int first, List<int> allocation, bool mini,
      [Uint8List? root]) {
    final out = BytesBuilder(copy: false);
    final seen = <int>{};
    int n = first;
    while (n < 0xfffffffa) {
      if (n >= allocation.length || !seen.add(n))
        throw const FormatException('Word 容器链损坏。');
      out.add(mini
          ? Uint8List.sublistView(root!, n * 64, (n + 1) * 64)
          : _sector(n));
      if (out.length > 24 * 1024 * 1024)
        throw const FormatException('Word 正文流过大。');
      n = allocation[n];
    }
    return out.takeBytes();
  }

  Uint8List stream(String name) {
    final d = ByteData.sublistView(directory);
    int? rootStart;
    int? found;
    for (int p = 0; p + 128 <= directory.length; p += 128) {
      final len = d.getUint16(p + 64, Endian.little);
      if (d.getUint8(p + 66) == 5)
        rootStart = d.getUint32(p + 116, Endian.little);
      if (len < 2 || len > 64) continue;
      final key = String.fromCharCodes(List.generate(
          len ~/ 2 - 1, (i) => d.getUint16(p + i * 2, Endian.little)));
      if (key == name) found = p;
    }
    if (found == null) throw FormatException('Word 缺少 $name 正文流。');
    final first = d.getUint32(found + 116, Endian.little);
    final size = d.getUint64(found + 120, Endian.little);
    Uint8List result;
    if (size < _u32(56)) {
      if (rootStart == null) throw const FormatException('Word 缺少正文容器。');
      final miniFatBytes = _chain(_u32(60), fat, false);
      final miniData = ByteData.sublistView(miniFatBytes);
      final miniFat = List.generate(miniFatBytes.length ~/ 4,
          (i) => miniData.getUint32(i * 4, Endian.little));
      result = _chain(first, miniFat, true, _chain(rootStart, fat, false));
    } else {
      result = _chain(first, fat, false);
    }
    return Uint8List.sublistView(result, 0, size);
  }
}
