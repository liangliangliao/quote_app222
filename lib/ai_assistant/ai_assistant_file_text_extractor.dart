import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:xml/xml.dart';

class AiAssistantFileTextExtractor {
  static const int maxExtractedChars = 60000;
  static const int maxBytesForText = 2 * 1024 * 1024;
  static const int maxBytesForStructured = 12 * 1024 * 1024;

  Future<String?> extract(File file, String filename, {String? mimeType, int? sizeBytes}) async {
    if (!await file.exists()) return null;
    final lower = filename.toLowerCase();
    final length = sizeBytes ?? await file.length();
    try {
      if (_isTextLike(lower, mimeType)) {
        return _limit(await _readUtf8Prefix(file, length > maxBytesForText ? maxBytesForText : length));
      }
      if (lower.endsWith('.docx')) return _extractDocx(await file.readAsBytes());
      if (lower.endsWith('.pptx')) return _extractPptx(await file.readAsBytes());
      if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) return _extractXlsx(await file.readAsBytes());
      if (lower.endsWith('.pdf')) return _extractPdfText(await file.readAsBytes());
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _isTextLike(String name, String? mimeType) {
    final mime = (mimeType ?? '').toLowerCase();
    return mime.startsWith('text/') ||
        mime.contains('json') ||
        mime.contains('xml') ||
        mime.contains('csv') ||
        name.endsWith('.txt') ||
        name.endsWith('.md') ||
        name.endsWith('.markdown') ||
        name.endsWith('.csv') ||
        name.endsWith('.json') ||
        name.endsWith('.xml') ||
        name.endsWith('.html') ||
        name.endsWith('.htm') ||
        name.endsWith('.yaml') ||
        name.endsWith('.yml') ||
        name.endsWith('.dart') ||
        name.endsWith('.js') ||
        name.endsWith('.ts') ||
        name.endsWith('.py') ||
        name.endsWith('.java') ||
        name.endsWith('.kt') ||
        name.endsWith('.swift') ||
        name.endsWith('.go') ||
        name.endsWith('.rs') ||
        name.endsWith('.sql') ||
        name.endsWith('.log');
  }

  Future<String> _readUtf8Prefix(File file, int bytesToRead) async {
    final bytes = await file.openRead(0, bytesToRead).fold<List<int>>(<int>[], (prev, chunk) => prev..addAll(chunk));
    return utf8.decode(bytes, allowMalformed: true).trim();
  }

  String? _extractDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final file = archive.findFile('word/document.xml');
    if (file == null) return null;
    final xml = utf8.decode(_archiveBytes(file), allowMalformed: true);
    final doc = XmlDocument.parse(xml);
    final buffer = StringBuffer();
    for (final paragraph in doc.findAllElements('w:p')) {
      final text = paragraph.findAllElements('w:t').map((e) => e.innerText).join('');
      if (text.trim().isNotEmpty) buffer.writeln(text.trim());
    }
    return _limit(buffer.toString());
  }

  String? _extractPptx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final slideFiles = archive.files
        .where((f) => f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (slideFiles.isEmpty) return null;
    final buffer = StringBuffer();
    for (var i = 0; i < slideFiles.length; i++) {
      final xml = utf8.decode(_archiveBytes(slideFiles[i]), allowMalformed: true);
      final doc = XmlDocument.parse(xml);
      final texts = doc.findAllElements('a:t').map((e) => e.innerText.trim()).where((e) => e.isNotEmpty).toList();
      if (texts.isEmpty) continue;
      buffer.writeln('--- Slide ${i + 1} ---');
      buffer.writeln(texts.join('\n'));
    }
    return _limit(buffer.toString());
  }

  String? _extractXlsx(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final buffer = StringBuffer();
    for (final tableName in excel.tables.keys) {
      final table = excel.tables[tableName];
      if (table == null) continue;
      buffer.writeln('--- Sheet: $tableName ---');
      var rowCount = 0;
      for (final row in table.rows) {
        final values = row.map((cell) => (cell?.value ?? '').toString().trim()).toList();
        if (values.any((v) => v.isNotEmpty)) buffer.writeln(values.join('\t'));
        rowCount++;
        if (rowCount >= 1000 || buffer.length > maxExtractedChars) break;
      }
      if (buffer.length > maxExtractedChars) break;
    }
    final text = buffer.toString().trim();
    return text.isEmpty ? null : _limit(text);
  }

  String? _extractPdfText(Uint8List bytes) {
    final combined = StringBuffer();
    final raw = latin1.decode(bytes, allowInvalid: true);
    combined.write(_extractPdfTextFromString(raw));

    // Try flate-compressed streams. This improves extraction for many text PDFs.
    final streamPattern = RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream');
    for (final match in streamPattern.allMatches(raw)) {
      final start = match.start;
      final headerStart = raw.lastIndexOf('<<', start);
      final headerEnd = raw.indexOf('>>', headerStart >= 0 ? headerStart : 0);
      final header = (headerStart >= 0 && headerEnd > headerStart && headerEnd < start) ? raw.substring(headerStart, headerEnd) : '';
      if (!header.contains('/FlateDecode')) continue;
      final streamContent = match.group(1);
      if (streamContent == null) continue;
      final data = Uint8List.fromList(latin1.encode(streamContent));
      try {
        final inflated = ZLibDecoder().decodeBytes(data, verify: false);
        final text = latin1.decode(inflated, allowInvalid: true);
        final extracted = _extractPdfTextFromString(text);
        if (extracted.trim().isNotEmpty) {
          combined.writeln();
          combined.write(extracted);
        }
      } catch (_) {}
      if (combined.length > maxExtractedChars) break;
    }
    final text = combined.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? null : _limit(text);
  }

  String _extractPdfTextFromString(String raw) {
    final buffer = StringBuffer();
    final paren = RegExp(r'\((?:\\.|[^\\)]){1,1200}\)');
    for (final match in paren.allMatches(raw)) {
      var text = match.group(0) ?? '';
      if (text.length <= 2) continue;
      text = text.substring(1, text.length - 1);
      text = _decodePdfEscapes(text);
      if (_looksReadable(text)) buffer.write('$text ');
      if (buffer.length > maxExtractedChars) break;
    }
    final hex = RegExp(r'<([0-9A-Fa-f]{4,})>');
    for (final match in hex.allMatches(raw)) {
      final value = match.group(1) ?? '';
      final decoded = _decodePdfHex(value);
      if (decoded != null && _looksReadable(decoded)) buffer.write('$decoded ');
      if (buffer.length > maxExtractedChars) break;
    }
    return buffer.toString();
  }

  String _decodePdfEscapes(String text) {
    return text
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\n')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\');
  }

  String? _decodePdfHex(String hex) {
    try {
      final bytes = <int>[];
      for (var i = 0; i + 1 < hex.length; i += 2) {
        bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
      }
      if (bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff) {
        final codes = <int>[];
        for (var i = 2; i + 1 < bytes.length; i += 2) {
          codes.add((bytes[i] << 8) + bytes[i + 1]);
        }
        return String.fromCharCodes(codes);
      }
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  bool _looksReadable(String text) {
    final t = text.trim();
    if (t.length < 2) return false;
    final readable = RegExp(r'[A-Za-z0-9\u4e00-\u9fa5]').allMatches(t).length;
    return readable >= (t.length * 0.35).ceil();
  }

  List<int> _archiveBytes(ArchiveFile file) {
    final content = file.content;
    if (content is List<int>) return content;
    if (content is Uint8List) return content;
    return <int>[];
  }

  String _limit(String text) {
    final value = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    if (value.length <= maxExtractedChars) return value;
    return '${value.substring(0, maxExtractedChars)}\n…（文件内容已截断）';
  }
}
