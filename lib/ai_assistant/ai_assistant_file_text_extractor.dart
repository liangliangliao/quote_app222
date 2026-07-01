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
      if (lower.endsWith('.epub') || lower.endsWith('.kepub')) return _extractEpub(await file.readAsBytes());
      if (lower.endsWith('.fb2')) return _extractFb2(await file.readAsBytes());
      if (lower.endsWith('.mobi') || lower.endsWith('.azw') || lower.endsWith('.azw3')) {
        return _extractBinaryEbookText(await file.readAsBytes());
      }
      if (_isTextLike(lower, mimeType)) {
        final text = await _readUtf8Prefix(file, length > maxBytesForText ? maxBytesForText : length);
        return _looksLikeBinaryOrGarbled(text) ? null : _limit(text);
      }
      if (lower.endsWith('.doc')) return _extractLegacyDoc(await file.readAsBytes());
      if (lower.endsWith('.rtf')) return _extractRtf(await file.readAsBytes());
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
        name.endsWith('.xhtml') ||
        name.endsWith('.opf') ||
        name.endsWith('.kepub') ||
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

  String? _extractEpub(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytesForStructured) return null;
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final contentFiles = archive.files
        .where((f) {
          final name = f.name.toLowerCase();
          return name.endsWith('.xhtml') ||
              name.endsWith('.html') ||
              name.endsWith('.htm') ||
              name.endsWith('.xml') ||
              name.endsWith('.opf');
        })
        .where((f) => f.isFile)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (contentFiles.isEmpty) return null;
    final buffer = StringBuffer();
    for (final file in contentFiles) {
      final raw = utf8.decode(_archiveBytes(file), allowMalformed: true);
      final extracted = _extractMarkupText(raw);
      if (extracted.trim().isEmpty) continue;
      buffer.writeln('--- ${file.name} ---');
      buffer.writeln(extracted);
      if (buffer.length > maxExtractedChars) break;
    }
    final text = _cleanExtractedBlock(buffer.toString());
    return text.isEmpty ? null : _limit(text);
  }

  String? _extractFb2(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytesForStructured) return null;
    final raw = utf8.decode(bytes, allowMalformed: true);
    final text = _cleanExtractedBlock(_extractMarkupText(raw));
    return text.isEmpty ? null : _limit(text);
  }

  String? _extractBinaryEbookText(Uint8List bytes) {
    // MOBI/AZW/AZW3 are binary ebook containers. Without a full Palm/MOBI
    // parser, safely extract only readable runs and drop low-signal metadata or
    // garbled fragments. This gives file-based Q&A a useful fallback while
    // avoiding the xAI mojibake problem caused by raw binary injection.
    if (bytes.isEmpty || bytes.length > maxBytesForStructured) return null;
    final merged = <String>[
      _extractUtf16LeRuns(bytes),
      _extractAsciiRuns(bytes),
    ]
        .expand((c) => c.split(RegExp(r'\n+')))
        .map(_cleanExtractedLine)
        .where((line) => line.length >= 12 && _looksReadable(line) && !_looksLikeBinaryOrGarbled(line))
        .toSet()
        .join('\n');
    final text = _cleanExtractedBlock(merged);
    return text.isEmpty ? null : _limit(text);
  }

  String? _extractLegacyDoc(Uint8List bytes) {
    // Older .doc files are binary OLE containers. We cannot fully parse every
    // Word binary structure locally, but extracting readable UTF-16LE/ASCII
    // runs gives the assistant useful context without sending mojibake or
    // NUL-filled binary data to providers such as xAI/OpenRouter/Eden AI.
    if (bytes.isEmpty || bytes.length > maxBytesForStructured) return null;
    final candidates = <String>[];
    final utf16 = _extractUtf16LeRuns(bytes);
    if (utf16.trim().isNotEmpty) candidates.add(utf16);
    final ascii = _extractAsciiRuns(bytes);
    if (ascii.trim().isNotEmpty) candidates.add(ascii);
    final merged = candidates
        .expand((c) => c.split(RegExp(r'\n+')))
        .map(_cleanExtractedLine)
        .where((line) => _looksReadable(line) && !_looksLikeBinaryOrGarbled(line))
        .toSet()
        .join('\n');
    return merged.trim().isEmpty ? null : _limit(merged);
  }

  String? _extractRtf(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytesForStructured) return null;
    final raw = latin1.decode(bytes, allowInvalid: true);
    final decoded = raw
        .replaceAllMapped(RegExp(r"\\'([0-9A-Fa-f]{2})"), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
        .replaceAll(RegExp(r'\\par[d]?'), '\n')
        .replaceAll(RegExp(r'\\[a-zA-Z]+-?\d* ?'), '')
        .replaceAll(RegExp(r'[{}]'), ' ');
    final text = decoded
        .split(RegExp(r'\n+'))
        .map(_cleanExtractedLine)
        .where((line) => _looksReadable(line) && !_looksLikeBinaryOrGarbled(line))
        .join('\n');
    return text.trim().isEmpty ? null : _limit(text);
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


  String _extractMarkupText(String raw) {
    var text = raw
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), ' ')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), ' ')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</h[1-6]\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>', caseSensitive: false), ' ');
    text = _decodeHtmlEntities(text);
    return text;
  }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.tryParse(m.group(1) ?? '') ?? 32))
        .replaceAllMapped(RegExp(r'&#x([0-9A-Fa-f]+);'), (m) => String.fromCharCode(int.tryParse(m.group(1) ?? '', radix: 16) ?? 32));
  }

  String _cleanExtractedBlock(String text) {
    return text
        .split(RegExp(r'\n+'))
        .map(_cleanExtractedLine)
        .where((line) => _looksReadable(line) && !_looksLikeBinaryOrGarbled(line))
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  bool _looksReadable(String text) {
    final t = text.trim();
    if (t.length < 2) return false;
    final readable = RegExp(r'[A-Za-z0-9\u4e00-\u9fa5]').allMatches(t).length;
    return readable >= (t.length * 0.35).ceil();
  }

  bool _looksLikeBinaryOrGarbled(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    final sample = t.length > 4000 ? t.substring(0, 4000) : t;
    final bad = RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\uFFFD]').allMatches(sample).length;
    if (bad >= 8 || bad > sample.length * 0.03) return true;
    final readable = RegExp(r'[A-Za-z0-9\u4e00-\u9fa5]').allMatches(sample).length;
    return sample.length > 80 && readable < sample.length * 0.12;
  }

  String _extractUtf16LeRuns(Uint8List bytes) {
    final buffer = StringBuffer();
    final run = <int>[];
    void flush() {
      if (run.length >= 4) buffer.writeln(String.fromCharCodes(run));
      run.clear();
    }
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final code = bytes[i] | (bytes[i + 1] << 8);
      if (code == 9 || code == 10 || code == 13 || (code >= 32 && code <= 0xd7ff) || (code >= 0xe000 && code <= 0xfffd)) {
        run.add(code);
      } else {
        flush();
      }
      if (buffer.length > maxExtractedChars) break;
    }
    flush();
    return buffer.toString();
  }

  String _extractAsciiRuns(Uint8List bytes) {
    final buffer = StringBuffer();
    final run = StringBuffer();
    void flush() {
      if (run.length >= 6) buffer.writeln(run.toString());
      run.clear();
    }
    for (final b in bytes) {
      if (b == 9 || b == 10 || b == 13 || (b >= 32 && b <= 126)) {
        run.writeCharCode(b);
      } else {
        flush();
      }
      if (buffer.length > maxExtractedChars) break;
    }
    flush();
    return buffer.toString();
  }

  String _cleanExtractedLine(String line) {
    return line.replaceAll(RegExp(r'[\u0000-\u001F\uFFFD]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
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
