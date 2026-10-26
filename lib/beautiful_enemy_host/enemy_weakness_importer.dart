import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:enough_convert/enough_convert.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:xml/xml.dart';
import '../beautiful_enemy/src/domain/growth_profile.dart';
import 'import/enemy_legacy_doc.dart';

/// 只在本机提取，不调用 AI、不上传原文件。提取结果必须经用户预览确认。
class EnemyWeaknessImporter {
  const EnemyWeaknessImporter();
  static const int maxBytes = 12 * 1024 * 1024;
  static const List<String> extensions = ['txt', 'doc', 'docx', 'pdf'];

  Future<String> extract(
      {required String name, Uint8List? bytes, String? path}) async {
    final extension = name.split('.').last.toLowerCase();
    if (!extensions.contains(extension))
      throw const FormatException('请选择 txt、Word（doc/docx）或 pdf 文件。');
    if (path != null && await File(path).length() > maxBytes ||
        (bytes?.length ?? 0) > maxBytes) {
      throw const FormatException('文件不能超过 12 MB。');
    }
    final data =
        bytes ?? (path == null ? null : await File(path).readAsBytes());
    if (data == null || data.isEmpty)
      throw const FormatException('文件为空或无法读取，请重新选择。');
    if (data.length > maxBytes) throw const FormatException('文件不能超过 12 MB。');
    try {
      final String text;
      if (extension == 'pdf') {
        Directory? temp;
        try {
          String? pdfPath = path;
          if (pdfPath == null) {
            temp = await Directory.systemTemp.createTemp('enemy_profile_');
            pdfPath = '${temp.path}/profile.pdf';
            await File(pdfPath).writeAsBytes(data);
          }
          text = await ReadPdfText.getPDFtext(pdfPath);
        } finally {
          if (temp != null) await temp.delete(recursive: true);
        }
      } else {
        text = parseBytes(extension, data);
      }
      return validateText(text);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw FormatException(extension == 'pdf'
          ? 'PDF 无法读取。请移除密码；扫描件请先识别文字，或改为 txt/Word 后导入。'
          : '文档无法读取或已经损坏，请另存为 txt 或 .docx 后重试。');
    }
  }

  static String parseBytes(String extension, Uint8List data) {
    if (extension == 'doc') return extractEnemyLegacyDoc(data);
    if (extension == 'docx') {
      final archive = ZipDecoder().decodeBytes(data);
      final file = archive.findFile('word/document.xml');
      if (file == null || file.size > 2 * 1024 * 1024)
        throw const FormatException('Word 正文缺失或过大。');
      final xml = XmlDocument.parse(utf8.decode(file.content as List<int>));
      return xml.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'p')
          .map((p) => p.descendants
              .whereType<XmlElement>()
              .map((e) => switch (e.name.local) {
                    't' => e.innerText,
                    'tab' => '\t',
                    'br' => '\n',
                    _ => '',
                  })
              .join())
          .join('\n');
    }
    if (extension != 'txt') throw const FormatException('不支持此文档格式。');
    if (data.length >= 2 &&
        (data[0] == 0xff && data[1] == 0xfe ||
            data[0] == 0xfe && data[1] == 0xff)) {
      if (data.length.isOdd) throw const FormatException('TXT 编码不完整。');
      final little = data[0] == 0xff;
      return String.fromCharCodes(List.generate(
          (data.length - 2) ~/ 2,
          (i) => ByteData.sublistView(data)
              .getUint16(2 + i * 2, little ? Endian.little : Endian.big)));
    }
    try {
      return utf8.decode(data).replaceFirst('\ufeff', '');
    } on FormatException {
      return const GbkCodec().decode(data);
    }
  }

  static String validateText(String raw) {
    final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (text.isEmpty) throw const FormatException('未提取到文字。扫描 PDF 请先识别文字后导入。');
    if (text.length > EnemyGrowthProfile.maxTextChars)
      throw const FormatException('正文不能超过 60000 字，请精简后导入。');
    if (RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\ufffd]').hasMatch(text)) {
      throw const FormatException('提取结果存在乱码，请另存为 UTF-8 txt 或 .docx 后重试。');
    }
    return text;
  }
}
