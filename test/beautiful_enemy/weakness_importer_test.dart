import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:enough_convert/enough_convert.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/beautiful_enemy_host/enemy_weakness_importer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const importer = EnemyWeaknessImporter();
  test('TXT 支持 UTF-8、UTF-16 LE/BE 和 GBK 中文', () async {
    const text = '我害怕失败，常常拖延。\n我希望开始行动。';
    final variants = <Uint8List>[
      Uint8List.fromList(utf8.encode(text)),
      Uint8List.fromList(const GbkCodec().encode(text)),
      for (final little in [true, false])
        Uint8List.fromList([
          ...(little ? [255, 254] : [254, 255]),
          for (final c in text.codeUnits)
            ...(little ? [c & 255, c >> 8] : [c >> 8, c & 255]),
        ]),
    ];
    for (final bytes in variants) {
      expect(await importer.extract(name: '弱点.TXT', bytes: bytes), text);
    }
  });
  test('DOCX 正文保留中文段落、制表符、换行，忽略元数据', () async {
    const xml =
        '<w:document xmlns:w="urn:test"><w:body><w:p><w:r><w:t>拖延</w:t><w:tab/><w:t>回避</w:t><w:br/><w:t>希望改变</w:t></w:r></w:p><w:p><w:r><w:t>保留优势</w:t></w:r></w:p></w:body></w:document>';
    final archive = Archive()
      ..addFile(ArchiveFile(
          'word/document.xml', utf8.encode(xml).length, utf8.encode(xml)))
      ..addFile(ArchiveFile('docProps/core.xml', 8, utf8.encode('metadata')));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
    expect(await importer.extract(name: '弱点.docx', bytes: bytes),
        '拖延\t回避\n希望改变\n保留优势');
  });
  test('旧版 DOC 按正文 piece table 读取，不把已删除内容当成弱点', () async {
    final bytes = legacyDoc('我害怕失败，会拖延求职。');
    final text = await importer.extract(name: '弱点.doc', bytes: bytes);
    expect(text, '我害怕失败，会拖延求职。');
    expect(text, isNot(contains('已删除')));
  });
  test('空文档、超限、损坏、加密、扫描件都给明确错误，不能静默存乱码', () async {
    await expectLater(importer.extract(name: '空.txt', bytes: Uint8List(0)),
        throwsFormatException);
    await expectLater(
        importer.extract(
            name: '大.txt',
            bytes: Uint8List(EnemyWeaknessImporter.maxBytes + 1)),
        throwsFormatException);
    await expectLater(
        importer.extract(name: '损坏.doc', bytes: Uint8List.fromList([1, 2, 3])),
        throwsFormatException);
    final encrypted = legacyDoc('拖延');
    ByteData.sublistView(encrypted)
        .setUint16(3 * 512 + 10, 0x100, Endian.little);
    await expectLater(importer.extract(name: '加密.doc', bytes: encrypted),
        throwsFormatException);
    expect(
        () => EnemyWeaknessImporter.validateText(' '), throwsFormatException);
    expect(() => EnemyWeaknessImporter.validateText('文字\u0000乱码'),
        throwsFormatException);
    expect(() => EnemyWeaknessImporter.validateText('长' * 60001),
        throwsFormatException);
  });
  test('PDF 使用本机原生提取通道；无路径时临时文件在完成后清理', () async {
    String? tempPath;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('read_pdf_text'),
            (call) async {
      expect(call.method, 'getPDFtext');
      tempPath = (call.arguments as Map)['path'] as String;
      expect(File(tempPath!).existsSync(), isTrue);
      return '我有时回避困难，想学习小步行动。';
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('read_pdf_text'), null));
    expect(
        await importer.extract(
            name: '弱点.pdf', bytes: Uint8List.fromList(utf8.encode('%PDF-1.4'))),
        contains('回避困难'));
    expect(File(tempPath!).existsSync(), isFalse);
  });
}

/// 最小 Word 97 OLE 容器：正文和历史残留并存，用 piece table 指定正文范围。
Uint8List legacyDoc(String text) {
  final bytes = Uint8List(19 * 512);
  final d = ByteData.sublistView(bytes);
  void u16(int p, int value) => d.setUint16(p, value, Endian.little);
  void u32(int p, int value) => d.setUint32(p, value, Endian.little);
  u32(0, 0xe011cfd0);
  u32(4, 0xe11ab1a1);
  u16(30, 9);
  u16(32, 6);
  u32(48, 0);
  u32(56, 4096);
  u32(60, 0xfffffffe);
  u32(68, 0xfffffffe);
  for (int i = 0; i < 109; i++) {
    u32(76 + i * 4, i == 0 ? 1 : 0xffffffff);
  }
  for (int i = 0; i < 128; i++) {
    u32(1024 + i * 4, 0xffffffff);
  }
  u32(1024, 0xfffffffe);
  u32(1028, 0xfffffffd);
  for (int i = 2; i < 18; i++) {
    u32(1024 + i * 4, i == 9 || i == 17 ? 0xfffffffe : i + 1);
  }
  void directory(int index, String name, int first, int size) {
    final start = 512 + index * 128;
    for (int i = 0; i < name.length; i++) {
      u16(start + i * 2, name.codeUnitAt(i));
    }
    u16(start + 64, (name.length + 1) * 2);
    bytes[start + 66] = index == 0 ? 5 : 2;
    u32(start + 116, first);
    u32(start + 120, size);
  }

  directory(0, 'Root Entry', 0xfffffffe, 0);
  directory(1, 'WordDocument', 2, 4096);
  directory(2, '0Table', 10, 4096);
  const w = 3 * 512;
  u16(w, 0xa5ec);
  u16(w + 2, 0xc1);
  u16(w + 32, 14);
  u16(w + 62, 22);
  u32(w + 76, text.length);
  u16(w + 152, 34);
  u32(w + 154 + 33 * 8, 0);
  u32(w + 158 + 33 * 8, 21);
  for (int i = 0; i < text.length; i++) {
    u16(w + 512 + i * 2, text.codeUnitAt(i));
  }
  const old = '已删除的旧文字';
  for (int i = 0; i < old.length; i++) {
    u16(w + 800 + i * 2, old.codeUnitAt(i));
  }
  const t = 11 * 512;
  bytes[t] = 2;
  u32(t + 1, 16);
  u32(t + 5, 0);
  u32(t + 9, text.length);
  u32(t + 15, 512);
  return bytes;
}
