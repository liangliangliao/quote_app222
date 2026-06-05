import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'conscious_change_dao.dart';

class CcParsedDocument {
  final String title;
  final String plainText;
  final List<CcImportedChapter> chapters;

  const CcParsedDocument({
    required this.title,
    required this.plainText,
    required this.chapters,
  });
}

class ConsciousChangeImportParser {
  static const List<String> supportedExtensions = <String>[
    'txt',
    'md',
    'markdown',
    'docx',
    'epub',
    'html',
    'htm',
    'xhtml',
    'rtf',
    'fb2',
    'doc',
    'pdf',
  ];

  static const List<String> supportedBookExtensions = <String>[
    'epub',
    'txt',
    'md',
    'markdown',
    'docx',
    'html',
    'htm',
    'xhtml',
    'rtf',
    'fb2',
    'doc',
    'pdf',
  ];

  static Future<CcParsedDocument> parseFile({
    required String fileName,
    required String extension,
    Uint8List? bytes,
    String? path,
    bool preferBookStructure = false,
  }) async {
    final lowerExt = extension.toLowerCase().replaceFirst('.', '');
    final data = bytes ?? (path == null ? null : await File(path).readAsBytes());
    if (data == null || data.isEmpty) {
      throw const FormatException('文件内容为空，无法导入。');
    }

    if (preferBookStructure) {
      return _parseBookFile(fileName: fileName, extension: lowerExt, data: data);
    }

    final rawText = switch (lowerExt) {
      'txt' || 'md' || 'markdown' => _decodeText(data),
      'docx' => _extractDocxText(data),
      'epub' => _extractEpubText(data),
      'html' || 'htm' || 'xhtml' => _htmlToStructuredText(_decodeText(data)),
      'rtf' => _extractRtfText(data),
      'fb2' => _extractFb2Text(data),
      'pdf' => _extractPdfText(data),
      'doc' => throw const FormatException('当前无法直接解析老式 .doc 二进制文档；请先在 Word/WPS 中另存为 .docx 后再导入。'),
      _ => throw FormatException('暂不支持 .$lowerExt 文件。当前支持 txt、md、docx、epub、html、rtf、fb2、pdf。'),
    };

    final normalized = _normalizeText(rawText);
    if (normalized.trim().isEmpty) {
      throw const FormatException('未能从文档中读取到有效文本。');
    }

    final chapters = _splitChapters(normalized);
    if (chapters.isEmpty) {
      throw const FormatException('未识别到有效课程内容。请确认文档包含正文文字，或使用“第……章 / 第……节 / # 标题”等目录标题格式。');
    }

    return CcParsedDocument(
      title: _deriveTitle(fileName, normalized),
      plainText: normalized,
      chapters: chapters,
    );
  }

  static CcParsedDocument _parseBookFile({
    required String fileName,
    required String extension,
    required Uint8List data,
  }) {
    final lowerExt = extension.toLowerCase().replaceFirst('.', '');
    if (lowerExt == 'doc') {
      throw const FormatException('当前无法直接解析老式 .doc 二进制文档；请先在 Word/WPS 中另存为 .docx 后再导入。');
    }

    if (lowerExt == 'epub') {
      return _parseEpubAsReaderBook(fileName: fileName, data: data);
    }

    final rawText = switch (lowerExt) {
      'txt' || 'md' || 'markdown' => _decodeText(data),
      'docx' => _extractDocxText(data),
      'html' || 'htm' || 'xhtml' => _htmlToStructuredText(_decodeText(data)),
      'rtf' => _extractRtfText(data),
      'fb2' => _extractFb2Text(data),
      'pdf' => _extractPdfText(data),
      _ => throw FormatException('暂不支持 .$lowerExt 文件。当前支持 txt、md、docx、epub、html、rtf、fb2、pdf。'),
    };
    final normalized = _normalizeText(rawText);
    final chapters = _splitBookChaptersFromStructuredText(normalized, fallbackTitle: _deriveTitle(fileName, normalized));
    if (chapters.isEmpty) {
      throw const FormatException('未能从电子书中读取到有效正文。');
    }
    return CcParsedDocument(
      title: _deriveTitle(fileName, normalized),
      plainText: normalized,
      chapters: chapters,
    );
  }

  static CcParsedDocument _parseEpubAsReaderBook({
    required String fileName,
    required Uint8List data,
  }) {
    // 电子书阅读模式：不再依赖 EPUB 自带 TOC 是否完善，也不再把全书硬塞成一个
    // “本章内容”。这里按 OPF spine 的真实阅读顺序读取每个 XHTML，然后结合：
    // 1) EPUB nav/toc 目录；2) HTML h1-h6；3) 书中大写独立标题；
    // 生成可翻页的阅读单元。这样即使某些 EPUB 的 toc.ncx 只有 Chapter 1，
    // 也能像阅读器一样按正文中的大标题继续拆分。
    final archive = ZipDecoder().decodeBytes(data, verify: false);
    final byName = <String, ArchiveFile>{for (final file in archive.files) file.name: file};
    final package = _readEpubPackage(byName);
    final title = _deriveEpubTitle(fileName, package, byName, fileName);
    final tocItems = _normalizeTocLevelsForReader(_extractEpubTocItems(byName, package));

    final spine = <String>[];
    if (package.spineNames.isNotEmpty) {
      spine.addAll(package.spineNames);
    } else {
      spine.addAll(
        byName.keys
            .where((name) => RegExp(r'\.(xhtml|html|htm)$', caseSensitive: false).hasMatch(name))
            .where((name) => !RegExp(r'(nav|toc\.ncx)$', caseSensitive: false).hasMatch(name))
            .toList()
          ..sort(),
      );
    }

    final tocByFile = <String, List<_EpubTocItem>>{};
    for (final item in tocItems) {
      final file = _stripFragment(item.href);
      if (file.isEmpty || item.title.trim().isEmpty) continue;
      tocByFile.putIfAbsent(file, () => <_EpubTocItem>[]).add(item);
    }

    final blocks = <_EpubTextBlock>[];
    final seen = <String>{};
    for (final rawName in spine) {
      final name = _stripFragment(rawName);
      if (name.isEmpty || !seen.add(name)) continue;
      final file = byName[name];
      if (file == null || file.isFile != true) continue;
      final html = utf8.decode(_archiveFileBytes(file), allowMalformed: true);
      blocks.addAll(_extractEpubHtmlBlocks(
        html,
        fileName: name,
        tocItems: tocByFile[name] ?? const <_EpubTocItem>[],
      ));
    }

    // 有些 EPUB 的目录项没有进入 spine，补充读取这些正文文件。
    for (final item in tocItems) {
      final name = _stripFragment(item.href);
      if (name.isEmpty || seen.contains(name)) continue;
      final file = byName[name];
      if (file == null || file.isFile != true) continue;
      final html = utf8.decode(_archiveFileBytes(file), allowMalformed: true);
      seen.add(name);
      blocks.addAll(_extractEpubHtmlBlocks(
        html,
        fileName: name,
        tocItems: tocByFile[name] ?? <_EpubTocItem>[item],
      ));
    }

    final chapters = _splitEpubBlocksToBookChapters(blocks, fallbackTitle: title);
    if (chapters.isEmpty) {
      final fallback = _extractEpubText(data).trim();
      if (fallback.isEmpty) throw const FormatException('未能从 EPUB 中读取到有效正文。');
      return CcParsedDocument(
        title: title,
        plainText: fallback,
        chapters: _splitBookChaptersFromStructuredText(fallback, fallbackTitle: title),
      );
    }

    final plainText = chapters.map((chapter) => chapter.content).where((e) => e.trim().isNotEmpty).join('\n\n');
    return CcParsedDocument(title: title, plainText: plainText, chapters: chapters);
  }

  static List<_EpubTextBlock> _extractEpubHtmlBlocks(
    String html, {
    required String fileName,
    required List<_EpubTocItem> tocItems,
  }) {
    var source = html
        .replaceAll(RegExp(r'<\s*(script|style)[^>]*>.*?<\s*/\s*\1\s*>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '<br/>');

    final fragmentHeadings = <String, _EpubTocItem>{};
    for (final item in tocItems) {
      final href = item.href.trim();
      final hashIndex = href.indexOf('#');
      if (hashIndex < 0 || hashIndex == href.length - 1) continue;
      final fragment = Uri.decodeComponent(href.substring(hashIndex + 1)).trim();
      if (fragment.isNotEmpty) fragmentHeadings[fragment] = item;
    }

    try {
      final doc = XmlDocument.parse(source);
      final blocks = <_EpubTextBlock>[];
      final emitted = <XmlElement>{};

      void addElement(XmlElement element) {
        if (emitted.contains(element)) return;
        emitted.add(element);
        final local = element.name.local.toLowerCase();
        if (!_isEpubBlockTag(local)) return;
        final isHeadingElement = local == 'h1' || local == 'h2' || local == 'h3' || local == 'h4' || local == 'h5' || local == 'h6';

        // 内容完整优先：EPUB 正文大多是 body/div/section 里的 p/li。
        // 旧逻辑只要元素有 block 祖先就跳过，导致 div 里的所有段落都被丢掉，
        // 最终只剩少量标题或重复片段。这里只跳过带有子 block 的容器，保留真正的
        // 段落、列表项、引用等叶子内容。
        final hasNestedBlock = element.children.whereType<XmlElement>().any((child) => _isEpubBlockTag(child.name.local.toLowerCase()));
        final isContainer = local == 'div' || local == 'section' || local == 'article' || local == 'body';
        if (!isHeadingElement && (isContainer || local == 'li') && hasNestedBlock) {
          return;
        }
        final rawText = _decodeHtmlEntities(element.innerText)
            .replaceAll(RegExp(r'[\t\r\n]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (rawText.isEmpty) return;
        final id = element.getAttribute('id') ?? element.getAttribute('name') ?? '';
        final tocItem = id.isEmpty ? null : fragmentHeadings[id];
        final className = (element.getAttribute('class') ?? '').toLowerCase();
        final role = (element.getAttribute('role') ?? '').toLowerCase();
        final isHeadingTag = RegExp(r'^h[1-6]$').hasMatch(local);
        final headingLevel = isHeadingTag
            ? int.tryParse(local.substring(1))
            : tocItem?.level;
        final links = element.descendants.whereType<XmlElement>().where((e) => e.name.local.toLowerCase() == 'a').toList();
        final linkText = links.map((e) => e.innerText).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        final isLinkOnly = links.isNotEmpty && _normalizeForCompare(linkText) == _normalizeForCompare(rawText);
        final looksToc = className.contains('toc') || className.contains('nav') || role.contains('doc-toc') || role.contains('navigation');
        blocks.add(_EpubTextBlock(
          text: tocItem?.title.trim().isNotEmpty == true ? tocItem!.title.trim() : rawText,
          explicitHeadingLevel: headingLevel,
          fileName: fileName,
          isLinkOnly: isLinkOnly,
          looksLikeTocEntry: looksToc || isLinkOnly,
        ));
      }

      for (final element in doc.descendants.whereType<XmlElement>()) {
        addElement(element);
      }
      if (blocks.isNotEmpty) return _dedupeAdjacentBlocks(blocks);
    } catch (_) {
      // 继续走宽松 HTML 正则兜底。
    }

    final text = _htmlToStructuredText(source);
    final blocks = <_EpubTextBlock>[];
    for (final raw in text.split('\n')) {
      final line = _cleanLine(raw);
      if (line.trim().isEmpty) continue;
      final level = _markdownHeadingLevel(raw);
      final title = _markdownHeadingTitle(raw);
      blocks.add(_EpubTextBlock(
        text: title ?? line,
        explicitHeadingLevel: level > 0 ? level : null,
        fileName: fileName,
      ));
    }
    return _dedupeAdjacentBlocks(blocks);
  }

  static bool _isEpubBlockTag(String local) {
    return const <String>{
      'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'p', 'div', 'section', 'article', 'li', 'blockquote', 'dt', 'dd', 'td', 'th', 'caption',
    }.contains(local);
  }

  static List<_EpubTextBlock> _dedupeAdjacentBlocks(List<_EpubTextBlock> blocks) {
    final result = <_EpubTextBlock>[];
    String last = '';
    for (final block in blocks) {
      final key = _normalizeForCompare(block.text);
      if (key.isEmpty) continue;
      if (key == last) continue;
      result.add(block);
      last = key;
    }
    return result;
  }

  static List<CcImportedChapter> _splitEpubBlocksToBookChapters(List<_EpubTextBlock> blocks, {required String fallbackTitle}) {
    if (blocks.isEmpty) return const <CcImportedChapter>[];

    // 非标准 EPUB 的最大问题是：toc/nav 不完整，正文里又混有目录页链接、
    // 封面/版权页、连续大写标题、以及没有 h1/h2 标签的显示标题。
    // 这里采用“内容完整优先”的阅读器式策略：
    // 1) 先按 spine 顺序保留全部正文 block；
    // 2) 目录页、版权页、前言、正文段落全部保留；
    // 3) 再按显式标题/大写显示标题/短标题切分；
    // 4) 如果标题识别失败或章节过长，按自然段兜底分页，保证正文不丢失。
    // 保证完整性：阅读书籍模式不能删除目录页、版权页、前言或任何正文段落。
    // 旧版本会在这里剔除目录列表和疑似导航内容，遇到不标准 EPUB 时会把前面大段
    // 内容误删。现在只做断行标题合并和空行清理；目录条目不会作为分页起点，但仍保留
    // 在阅读内容里，做到从 EPUB spine 第一份正文到最后一份正文完整呈现。
    final expanded = _mergeBrokenUppercaseHeadingBlocks(blocks)
        .map((block) => block.copyWith(text: _cleanLine(block.text)))
        .where((block) => block.text.trim().isNotEmpty)
        .toList();
    if (expanded.isEmpty) return const <CcImportedChapter>[];

    final candidates = <int>[];
    for (var i = 0; i < expanded.length; i++) {
      final block = expanded[i];
      if (_isEpubHeadingBlock(
        block,
        previous: i > 0 ? expanded[i - 1] : null,
        next: i + 1 < expanded.length ? expanded[i + 1] : null,
      )) {
        candidates.add(i);
      }
    }

    final starts = _validateReaderHeadingStarts(expanded, candidates);

    // 如果有效标题仍然很少，使用 spine 文件边界兜底；如果文件本身也很少，
    // 后面会再按自然段长度兜底分页。
    if (starts.length < 2) {
      starts.clear();
      String lastFile = '';
      for (var i = 0; i < expanded.length; i++) {
        final file = expanded[i].fileName;
        if (file != lastFile) {
          starts.add(i);
          lastFile = file;
        }
      }
    }

    if (starts.isEmpty) {
      final content = expanded.map((e) => e.text).join('\n\n');
      return _splitLongReaderUnit(title: fallbackTitle, content: content, startIndex: 0);
    }

    final units = <CcImportedChapter>[];
    if (starts.first > 0) {
      final lead = expanded.sublist(0, starts.first).map((e) => e.text).join('\n\n').trim();
      if (lead.length >= 20) {
        units.addAll(_splitLongReaderUnit(
          title: _deriveFrontMatterTitle(lead),
          content: lead,
          startIndex: units.length,
        ));
      }
    }

    for (var si = 0; si < starts.length; si++) {
      final start = starts[si];
      final end = si + 1 < starts.length ? starts[si + 1] : expanded.length;
      if (start < 0 || start >= expanded.length || end <= start) continue;
      final headingBlock = expanded[start];
      var title = _normalizeHeading(headingBlock.text).trim();
      if (title.isEmpty) title = '第 ${units.length + 1} 页';

      final bodyBlocks = expanded
          .sublist(start + 1, end)
          .where((e) => e.text.trim().isNotEmpty)
          .toList();
      final body = bodyBlocks.map((e) => e.text).join('\n\n').trim();
      final content = body.isEmpty ? title : '$title\n\n$body';
      units.addAll(_splitLongReaderUnit(title: title, content: content, startIndex: units.length));
    }

    // 去除相邻重复页，但绝不因标题重复而删除带正文的页。
    final result = <CcImportedChapter>[];
    String lastContentKey = '';
    for (final unit in units) {
      final content = unit.content.trim();
      if (content.isEmpty) continue;
      final key = _normalizeForCompare(content.length > 280 ? content.substring(0, 280) : content);
      if (key.isNotEmpty && key == lastContentKey) continue;
      result.add(_bookChapter(title: unit.title, content: unit.content, index: result.length));
      lastContentKey = key;
    }
    return result;
  }

  static List<_EpubTextBlock> _stripEpubTocListingBlocks(List<_EpubTextBlock> blocks) {
    if (blocks.isEmpty) return const <_EpubTextBlock>[];
    final result = <_EpubTextBlock>[];
    var insideTocList = false;
    var tocCandidateCount = 0;
    var bodyAfterTocCount = 0;

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final text = _normalizeHeading(block.text).trim();
      if (text.isEmpty) continue;

      if (_looksLikeContentsTitleForImport(text)) {
        // 保留目录页标题本身，但后面的目录链接列表不再作为正文分页依据。
        result.add(block.copyWith(text: text, explicitHeadingLevel: block.explicitHeadingLevel ?? 1));
        insideTocList = true;
        tocCandidateCount = 0;
        bodyAfterTocCount = 0;
        continue;
      }

      final strictTocLine = block.looksLikeTocEntry || block.isLinkOnly || _looksLikeTocPageNumberLine(text);
      final looseTocLine = _looksLikeTocListLine(text);
      if (insideTocList) {
        if (strictTocLine || (tocCandidateCount < 3 && looseTocLine)) {
          tocCandidateCount++;
          continue;
        }
        final looksHeading = _looksLikeBookFrontMatterTitle(text) || _looksLikeMajorUppercaseHeading(text) || _looksLikeNumberedContentTitle(text) || _looksLikeBookDisplayTitle(text);
        if (looksHeading) {
          // 目录链接列表结束，当前标题可能是真正文档章节，例如 PREFACE。
          insideTocList = false;
          result.add(block);
          continue;
        }
        bodyAfterTocCount++;
        if (bodyAfterTocCount > 2 || text.length > 120) {
          insideTocList = false;
          result.add(block);
        }
        // 目录列表中少量非链接噪声跳过。
        continue;
      }

      // 在非目录页里，纯链接条目通常是侧栏/页内导航，不应该进入正文。
      if ((block.looksLikeTocEntry || block.isLinkOnly || _looksLikeTocPageNumberLine(text)) &&
          i + 1 < blocks.length && _looksLikeTocListLine(blocks[i + 1].text)) {
        continue;
      }
      result.add(block.copyWith(text: text));
    }
    return _dedupeAdjacentBlocks(result);
  }

  static bool _looksLikeTocListLine(String text) {
    final t = _normalizeHeading(text).trim();
    if (t.isEmpty || t.length > 120) return false;
    if (_looksLikeContentsTitleForImport(t)) return true;
    if (RegExp(r'\.{2,}\s*\d+$').hasMatch(t)) return true;
    if (RegExp(r'\s+\d{1,4}$').hasMatch(t) && !RegExp(r'[.!?。！？]$').hasMatch(t)) return true;
    if (_looksLikeMajorUppercaseHeading(t) || _looksLikeBookFrontMatterTitle(t) || _looksLikeNumberedContentTitle(t)) return true;
    // ReadEra 类阅读器常见的目录条目是短标题，不带句号，标题式大小写。
    return _looksLikeBookDisplayTitle(t);
  }

  static bool _looksLikeTocPageNumberLine(String text) {
    final t = _normalizeHeading(text).trim();
    if (t.isEmpty || t.length > 140) return false;
    if (RegExp(r'\.{2,}\s*\d+$').hasMatch(t)) return true;
    if (RegExp(r'\s+\d{1,4}$').hasMatch(t) && !RegExp(r'[.!?。！？]$').hasMatch(t)) return true;
    return false;
  }

  static List<int> _validateReaderHeadingStarts(List<_EpubTextBlock> blocks, List<int> candidates) {
    if (candidates.isEmpty) return <int>[];
    final raw = candidates.toSet().toList()..sort();
    final starts = <int>[];
    for (var ci = 0; ci < raw.length; ci++) {
      final index = raw[ci];
      final block = blocks[index];
      final nextIndex = ci + 1 < raw.length ? raw[ci + 1] : blocks.length;
      final bodyLength = _segmentBodyLength(blocks, index + 1, nextIndex);
      final nextIsImmediate = nextIndex - index <= 2;
      final strongHeading = block.explicitHeadingLevel != null ||
          _looksLikeContentsTitleForImport(block.text) ||
          _looksLikeBookFrontMatterTitle(block.text) ||
          _looksLikeMajorUppercaseHeading(block.text) ||
          _looksLikeNumberedContentTitle(block.text);

      // 目录页条目、标题簇中的空标题，不作为独立分页起点。
      if ((block.looksLikeTocEntry || block.isLinkOnly) && !_looksLikeContentsTitleForImport(block.text)) continue;
      if (nextIsImmediate && bodyLength < 80 && !strongHeading) continue;
      if (bodyLength < 30 && ci + 1 < raw.length && !strongHeading) continue;
      starts.add(index);
    }

    // 如果连续标题太密集，说明仍然把目录列表识别成了章节；保留第一个和有正文的标题。
    final filtered = <int>[];
    for (var i = 0; i < starts.length; i++) {
      final current = starts[i];
      final next = i + 1 < starts.length ? starts[i + 1] : blocks.length;
      final bodyLength = _segmentBodyLength(blocks, current + 1, next);
      final clustered = i + 1 < starts.length && starts[i + 1] - current <= 2;
      if (clustered && bodyLength < 80 && !_looksLikeMajorUppercaseHeading(blocks[current].text)) {
        continue;
      }
      filtered.add(current);
    }
    return filtered;
  }

  static int _segmentBodyLength(List<_EpubTextBlock> blocks, int start, int end) {
    if (start >= end || start >= blocks.length) return 0;
    final safeEnd = end > blocks.length ? blocks.length : end;
    var length = 0;
    for (var i = start; i < safeEnd; i++) {
      final text = blocks[i].text.trim();
      if (text.isEmpty) continue;
      if (blocks[i].looksLikeTocEntry || blocks[i].isLinkOnly) continue;
      length += text.length;
    }
    return length;
  }

  static bool _looksLikeBookDisplayTitle(String title) {
    final t = _normalizeHeading(title).trim();
    if (t.length < 3 || t.length > 110) return false;
    if (RegExp(r'[.!?。！？；;:]$').hasMatch(t)) return false;
    final words = RegExp(r"[A-Za-z0-9]+|[\u4e00-\u9fff]+").allMatches(t).length;
    if (words == 0 || words > 12) return false;
    if (t.contains(',')) return false;
    final letters = RegExp(r'[A-Za-z]').allMatches(t).length;
    if (letters == 0) return true;
    final firstLetters = RegExp(r'\b[A-Z][A-Za-z0-9\-]*').allMatches(t).length;
    final lowerStarts = RegExp(r'\b[a-z][A-Za-z0-9\-]*').allMatches(t).length;
    return firstLetters >= 1 && lowerStarts <= 1;
  }

  static List<CcImportedChapter> _splitLongReaderUnit({required String title, required String content, required int startIndex}) {
    final normalized = _normalizeText(content).trim();
    if (normalized.isEmpty) return const <CcImportedChapter>[];
    const maxChars = 3600;
    if (normalized.length <= maxChars) {
      return [_bookChapter(title: title, content: normalized, index: startIndex)];
    }
    final paragraphs = normalized.split(RegExp(r'\n{2,}')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final result = <CcImportedChapter>[];
    final buffer = StringBuffer();
    var page = 0;
    void flush() {
      final text = buffer.toString().trim();
      if (text.isEmpty) return;
      final pageTitle = page == 0 ? title : '$title · ${page + 1}';
      result.add(_bookChapter(title: pageTitle, content: text, index: startIndex + result.length));
      buffer.clear();
      page++;
    }
    for (final paragraph in paragraphs) {
      if (buffer.isNotEmpty && buffer.length + paragraph.length > maxChars) flush();
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write(paragraph);
    }
    flush();
    return result;
  }

  static List<_EpubTextBlock> _mergeBrokenUppercaseHeadingBlocks(List<_EpubTextBlock> blocks) {
    final result = <_EpubTextBlock>[];
    var i = 0;
    while (i < blocks.length) {
      var current = blocks[i];
      var text = current.text.trim();
      while (i + 1 < blocks.length && _endsWithSoftHyphenBreak(text) && _looksLikeUppercaseContinuation(blocks[i + 1].text)) {
        final next = blocks[i + 1];
        text = text.replaceFirst(RegExp(r'[\-–—]\s*$'), '') + next.text.trim();
        current = current.copyWith(text: text);
        i++;
      }
      result.add(current.copyWith(text: text));
      i++;
    }
    return result;
  }

  static bool _endsWithSoftHyphenBreak(String text) => RegExp(r'[\-–—]\s*$').hasMatch(text.trim());

  static bool _looksLikeUppercaseContinuation(String text) {
    final t = _cleanLine(text);
    if (t.isEmpty || t.length > 40) return false;
    return _uppercaseLetterRatio(t) >= 0.72;
  }

  static bool _isEpubHeadingBlock(_EpubTextBlock block, {_EpubTextBlock? previous, _EpubTextBlock? next}) {
    final text = _normalizeHeading(block.text).trim();
    if (text.isEmpty || text.length > 140) return false;
    if (_isKeywordMarkerLine(text) || _isOriginalContentMarkerLine(text)) return false;
    if (block.explicitHeadingLevel != null && block.explicitHeadingLevel! >= 1 && block.explicitHeadingLevel! <= 6) {
      return true;
    }
    if (_looksLikeContentsTitleForImport(text)) return true;
    if (_looksLikeBookFrontMatterTitle(text)) return true;
    if (_looksLikeNumberedContentTitle(text)) return true;
    if (block.looksLikeTocEntry || block.isLinkOnly) return false;
    if (_looksLikeMajorUppercaseHeading(text)) return true;
    if (_looksLikeBookDisplayTitle(text)) {
      // 标题式大小写只能作为弱信号：需要附近不是普通段落，避免把短句误判为标题。
      final previousText = previous == null ? '' : previous.text.trim();
      final nextText = next == null ? '' : next.text.trim();
      final previousLooksBody = previousText.length > 120 || RegExp(r'[.!?。！？]$').hasMatch(previousText);
      final nextLooksUseful = nextText.length >= 20 || _looksLikeMajorUppercaseHeading(nextText) || _looksLikeBookDisplayTitle(nextText);
      return !previousLooksBody && nextLooksUseful;
    }
    return false;
  }

  static bool _looksLikeContentsTitleForImport(String title) {
    final t = title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return t == 'contents' || t == 'table of contents' || t == '目录' || t == '目錄';
  }

  static bool _looksLikeBookFrontMatterTitle(String title) {
    final t = title.trim().toLowerCase();
    return const <String>{
      'preface', 'foreword', 'introduction', 'acknowledgments', 'acknowledgements',
      'bibliography', 'references', 'index', 'appendix', 'copyright', 'title page',
      '前言', '序言', '导言', '引言', '绪论', '后记', '附录', '参考文献',
    }.contains(t);
  }

  static bool _looksLikeMajorUppercaseHeading(String title) {
    final t = title.trim();
    if (t.length < 3 || t.length > 96) return false;
    if (RegExp(r'[。！？!?；;，,。]$').hasMatch(t)) return false;
    final letters = RegExp(r'[A-Za-z]').allMatches(t).length;
    if (letters < 3) return false;
    final ratio = _uppercaseLetterRatio(t);
    if (ratio < 0.72) return false;
    final lowerWords = RegExp(r'\b[a-z]{2,}\b').allMatches(t).length;
    if (lowerWords > 0) return false;
    return true;
  }

  static double _uppercaseLetterRatio(String text) {
    var letters = 0;
    var upper = 0;
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      if (RegExp(r'[A-Za-z]').hasMatch(ch)) {
        letters++;
        if (ch.toUpperCase() == ch) upper++;
      }
    }
    if (letters == 0) return 0;
    return upper / letters;
  }

  static String _deriveFrontMatterTitle(String content) {
    final first = content.split('\n').map(_cleanLine).firstWhere((e) => e.trim().isNotEmpty, orElse: () => '开篇');
    if (_looksLikeBookFrontMatterTitle(first) || _looksLikeContentsTitleForImport(first) || _looksLikeMajorUppercaseHeading(first)) return first;
    return '开篇';
  }

  static String _deriveEpubTitle(String fileName, _EpubPackage package, Map<String, ArchiveFile> byName, String text) {
    try {
      final root = package.rootfile.isEmpty ? null : byName[package.rootfile];
      if (root != null) {
        final opf = XmlDocument.parse(utf8.decode(_archiveFileBytes(root), allowMalformed: true));
        for (final e in opf.descendants.whereType<XmlElement>()) {
          if (e.name.local.toLowerCase() == 'title') {
            final title = e.innerText.replaceAll(RegExp(r'\s+'), ' ').trim();
            if (title.isNotEmpty) return title;
          }
        }
      }
    } catch (_) {}
    return _deriveTitle(fileName, text);
  }

  static List<_EpubTocItem> _normalizeTocLevelsForReader(List<_EpubTocItem> items) {
    final filtered = items.where((item) => item.title.trim().isNotEmpty).toList();
    if (filtered.isEmpty) return const <_EpubTocItem>[];
    final minLevel = filtered.map((e) => e.level <= 0 ? 1 : e.level).reduce((a, b) => a < b ? a : b);
    return [
      for (final item in filtered)
        _EpubTocItem(
          href: item.href,
          title: item.title,
          level: ((item.level <= 0 ? 1 : item.level) - minLevel + 1).clamp(1, 6).toInt(),
        ),
    ];
  }

  static String _htmlToReaderStructuredText(String html, List<_EpubTocItem> tocForFile) {
    var decorated = html;
    final inserted = <String>{};
    final noFragment = <_EpubTocItem>[];
    for (final item in tocForFile) {
      final href = item.href.trim();
      final hashIndex = href.indexOf('#');
      if (hashIndex < 0 || hashIndex == href.length - 1) {
        noFragment.add(item);
        continue;
      }
      final fragment = Uri.decodeComponent(href.substring(hashIndex + 1)).trim();
      if (fragment.isEmpty) {
        noFragment.add(item);
        continue;
      }
      final marker = '\n${_tocHeadingMarker(item)} ${item.title}\n';
      final pattern = RegExp(
        r'''<([a-zA-Z][a-zA-Z0-9:_-]*)([^>]*(?:id|name)\s*=\s*["']''' + RegExp.escape(fragment) + r'''["'][^>]*)>''',
        caseSensitive: false,
      );
      var matched = false;
      decorated = decorated.replaceFirstMapped(pattern, (m) {
        matched = true;
        inserted.add(_normalizeForCompare(item.title));
        return '$marker${m.group(0)}';
      });
      if (!matched) noFragment.add(item);
    }

    var text = _collapseAdjacentDuplicateHeadings(_htmlToStructuredText(decorated)).trim();
    if (noFragment.isNotEmpty) {
      final first = noFragment.first;
      if (!_textStartsWithSameHeading(text, first.title) && !inserted.contains(_normalizeForCompare(first.title))) {
        text = '${_tocHeadingMarker(first)} ${first.title}\n\n$text';
      }
    }
    return _normalizeText(text);
  }

  static List<CcImportedChapter> _splitBookChaptersFromStructuredText(String text, {required String fallbackTitle}) {
    final normalized = _normalizeText(text);
    if (normalized.trim().isEmpty) return const <CcImportedChapter>[];
    final rawLines = normalized.split('\n');
    final headings = <_Heading>[];
    for (var i = 0; i < rawLines.length; i++) {
      final level = _markdownHeadingLevel(rawLines[i]);
      if (level <= 0) continue;
      final title = _markdownHeadingTitle(rawLines[i]);
      if (title == null || title.trim().isEmpty) continue;
      headings.add(_Heading(i, title));
    }

    if (headings.length >= 2) {
      final levels = headings.map((h) => _markdownHeadingLevel(rawLines[h.lineIndex])).toSet().toList()..sort();
      final selectedLevel = levels.first;
      final selected = headings.where((h) => _markdownHeadingLevel(rawLines[h.lineIndex]) == selectedLevel).toList();
      if (selected.length >= 2) {
        final chapters = <CcImportedChapter>[];
        for (var i = 0; i < selected.length; i++) {
          final heading = selected[i];
          final start = heading.lineIndex + 1;
          final end = i + 1 < selected.length ? selected[i + 1].lineIndex : rawLines.length;
          final content = _cleanContent(rawLines.sublist(start, end));
          final finalContent = content.trim().isEmpty ? heading.title : content;
          chapters.add(_bookChapter(title: heading.title, content: finalContent, index: chapters.length));
        }
        return chapters.where((c) => c.content.trim().isNotEmpty).toList();
      }
    }

    final lines = rawLines.map(_cleanLine).toList();
    final fallback = _normalizeHeading(fallbackTitle).trim().isEmpty ? _deriveChapterFallbackTitle(lines) : _normalizeHeading(fallbackTitle);
    return [_bookChapter(title: fallback, content: _stripLeadingDuplicateTitle(normalized, fallback), index: 0)];
  }

  static CcImportedChapter _bookChapter({required String title, required String content, required int index}) {
    final safeTitle = _normalizeHeading(title).trim().isEmpty ? '第 ${index + 1} 页' : _normalizeHeading(title);
    final safeContent = _normalizeText(content).trim().isEmpty ? safeTitle : _normalizeText(content);
    return CcImportedChapter(
      title: safeTitle,
      content: safeContent,
      keywords: const <String>[],
      sections: [
        CcImportedSection(
          title: safeTitle,
          content: safeContent,
          keywords: const <String>[],
        ),
      ],
    );
  }

  static String _stripLeadingDuplicateTitle(String content, String title) {
    final lines = _normalizeText(content).split('\n');
    final titleKey = _normalizeForCompare(title);
    if (lines.isNotEmpty && titleKey.isNotEmpty) {
      final first = _markdownHeadingTitle(lines.first) ?? _cleanLine(lines.first);
      if (_normalizeForCompare(first) == titleKey) {
        return _cleanContent(lines.sublist(1));
      }
    }
    return _cleanContent(lines);
  }

  static String _readerTitleForFile(String fileName, String structured, List<_EpubTocItem> items, int index) {
    if (items.isNotEmpty && items.first.title.trim().isNotEmpty) return items.first.title.trim();
    for (final line in structured.split('\n')) {
      final heading = _markdownHeadingTitle(line);
      if (heading != null && heading.trim().isNotEmpty) return heading.trim();
    }
    final first = structured.split('\n').map(_cleanLine).firstWhere((line) => line.trim().isNotEmpty && line.trim().length <= 80, orElse: () => '');
    if (first.isNotEmpty) return first;
    final pathTitle = _titleFromEpubPath(fileName);
    return pathTitle.isEmpty ? '第 $index 页' : pathTitle;
  }

  static String _decodeText(Uint8List data) {
    final utf8Text = utf8.decode(data, allowMalformed: true).replaceFirst(RegExp(r'^\uFEFF'), '');
    // 如果 UTF-8 解码后出现大量替换字符，保底按 latin1 解码，避免空白或乱码完全不可读。
    final replacementCount = '�'.allMatches(utf8Text).length;
    if (replacementCount > utf8Text.length / 20) {
      return latin1.decode(data, allowInvalid: true).replaceFirst(RegExp(r'^\uFEFF'), '');
    }
    return utf8Text;
  }

  static String _extractDocxText(Uint8List data) {
    final archive = ZipDecoder().decodeBytes(data, verify: false);
    ArchiveFile? documentXml;
    for (final f in archive.files) {
      if (f.name == 'word/document.xml') {
        documentXml = f;
        break;
      }
    }
    if (documentXml == null) {
      throw const FormatException('未找到 Word 正文内容。');
    }

    final xmlText = utf8.decode(_archiveFileBytes(documentXml), allowMalformed: true);
    final doc = XmlDocument.parse(xmlText);
    final paragraphs = <String>[];
    for (final p in doc.descendants.whereType<XmlElement>().where((e) => e.name.local == 'p')) {
      final buffer = StringBuffer();
      for (final e in p.descendants.whereType<XmlElement>()) {
        final local = e.name.local;
        if (local == 't') {
          buffer.write(e.innerText);
        } else if (local == 'tab') {
          buffer.write(' ');
        } else if (local == 'br' || local == 'cr') {
          buffer.write('\n');
        }
      }
      final text = buffer.toString().trimRight();
      if (text.trim().isEmpty) {
        paragraphs.add(text);
        continue;
      }
      final prefix = _docxHeadingPrefix(_docxParagraphStyle(p));
      paragraphs.add(prefix == null ? text : '$prefix $text');
    }
    return paragraphs.join('\n');
  }

  static String _docxParagraphStyle(XmlElement paragraph) {
    for (final style in paragraph.descendants.whereType<XmlElement>().where((e) => e.name.local == 'pStyle')) {
      for (final attr in style.attributes) {
        if (attr.name.local == 'val') return attr.value;
      }
    }
    return '';
  }

  static String? _docxHeadingPrefix(String style) {
    final s = style.toLowerCase().replaceAll(RegExp(r'[_\-\s]+'), '');
    if (s.isEmpty) return null;
    if (s.contains('heading1') || s.contains('title1') || s == '1') return '#';
    if (s.contains('heading2') || s.contains('title2') || s == '2') return '##';
    if (s.contains('heading3') || s.contains('title3') || s == '3') return '###';
    return null;
  }

  static String _extractEpubText(Uint8List data) {
    final archive = ZipDecoder().decodeBytes(data, verify: false);
    final byName = <String, ArchiveFile>{for (final file in archive.files) file.name: file};
    final package = _readEpubPackage(byName);
    final tocItems = _extractEpubTocItems(byName, package);
    final normalizedTocItems = _normalizeTocLevels(tocItems);

    final candidates = <String>[];
    if (package.spineNames.isNotEmpty) {
      candidates.addAll(package.spineNames);
    } else if (normalizedTocItems.isNotEmpty) {
      candidates.addAll(normalizedTocItems.map((item) => _stripFragment(item.href)).where((name) => byName.containsKey(name)));
    } else {
      candidates.addAll(
        byName.keys
            .where((name) => RegExp(r'\.(xhtml|html|htm)$', caseSensitive: false).hasMatch(name))
            .where((name) => !RegExp(r'(nav|toc|cover|titlepage|copyright)', caseSensitive: false).hasMatch(name)),
      );
      candidates.sort();
    }

    final tocByFile = <String, List<_EpubTocItem>>{};
    for (final item in normalizedTocItems) {
      final file = _stripFragment(item.href);
      if (file.isEmpty || item.title.trim().isEmpty) continue;
      tocByFile.putIfAbsent(file, () => <_EpubTocItem>[]).add(item);
    }

    final seen = <String>{};
    final parts = <String>[];
    for (final rawName in candidates) {
      final name = _stripFragment(rawName);
      if (name.isEmpty || !seen.add(name)) continue;
      final file = byName[name];
      if (file == null || file.isFile != true) continue;
      final html = utf8.decode(_archiveFileBytes(file), allowMalformed: true);
      final tocForFile = tocByFile[name] ?? const <_EpubTocItem>[];
      final text = _htmlToStructuredTextWithToc(html, tocForFile).trim();
      if (text.isEmpty) continue;
      parts.add(text);
    }

    // 有些 EPUB 的目录项没有进入 spine，补充读取这些正文文件，避免目录项丢失。
    for (final item in normalizedTocItems) {
      final name = _stripFragment(item.href);
      if (name.isEmpty || seen.contains(name)) continue;
      final file = byName[name];
      if (file == null || file.isFile != true) continue;
      final html = utf8.decode(_archiveFileBytes(file), allowMalformed: true);
      final text = _htmlToStructuredTextWithToc(html, tocByFile[name] ?? <_EpubTocItem>[item]).trim();
      if (text.isEmpty) continue;
      seen.add(name);
      parts.add(text);
    }

    if (parts.isEmpty) {
      throw const FormatException('未能从 epub 中读取到正文。');
    }
    return parts.join('\n\n');
  }

  static List<_EpubTocItem> _normalizeTocLevels(List<_EpubTocItem> items) {
    if (items.isEmpty) return const <_EpubTocItem>[];
    var contentItems = items
        .where((item) => item.title.trim().isNotEmpty && !_looksLikeNonContentTocTitle(item.title))
        .toList();
    if (contentItems.isEmpty) return const <_EpubTocItem>[];

    final firstMinLevel = contentItems.map((item) => item.level <= 0 ? 1 : item.level).reduce((a, b) => a < b ? a : b);
    final rootLevelItems = contentItems.where((item) => (item.level <= 0 ? 1 : item.level) == firstMinLevel).toList();
    final directChildCount = contentItems.where((item) => (item.level <= 0 ? 1 : item.level) == firstMinLevel + 1).length;
    // 很多 EPUB 的 nav.xhtml 会把书名作为唯一一级目录节点，真正章节放在其子节点下。
    // 这种情况下跳过该容器节点，避免把书名或章节中的某个子标题误当成唯一“章”。
    if (rootLevelItems.length == 1 && directChildCount >= 2) {
      final root = rootLevelItems.first;
      final rootHrefFile = _stripFragment(root.href);
      final childSameFileCount = contentItems
          .where((item) => item != root && _stripFragment(item.href) == rootHrefFile)
          .length;
      final looksLikeContainer = childSameFileCount == 0 || !_looksLikeNumberedContentTitle(root.title);
      if (looksLikeContainer) {
        contentItems = contentItems.where((item) => item != root).toList();
      }
    }

    final minLevel = contentItems.map((item) => item.level <= 0 ? 1 : item.level).reduce((a, b) => a < b ? a : b);
    return [
      for (final item in contentItems)
        _EpubTocItem(
          href: item.href,
          title: item.title,
          level: ((item.level <= 0 ? 1 : item.level) - minLevel + 1).clamp(1, 6).toInt(),
        ),
    ];
  }

  static bool _looksLikeNumberedContentTitle(String title) {
    final t = title.trim();
    return RegExp(r'^(第\s*[一二三四五六七八九十百千万零〇两0-9]+\s*(章|节|篇|讲|课)|Chapter\s+[0-9IVXLC]+|Lecture\s+[0-9IVXLC]+|Lesson\s+[0-9IVXLC]+|[0-9]+[\.、\s])', caseSensitive: false).hasMatch(t);
  }

  static String _htmlToStructuredTextWithToc(String html, List<_EpubTocItem> tocForFile) {
    var decorated = html;
    final insertedTitles = <String>{};
    final noFragmentItems = <_EpubTocItem>[];

    for (final item in tocForFile) {
      final href = item.href.trim();
      final hashIndex = href.indexOf('#');
      if (hashIndex < 0 || hashIndex == href.length - 1) {
        noFragmentItems.add(item);
        continue;
      }
      final fragment = Uri.decodeComponent(href.substring(hashIndex + 1)).trim();
      if (fragment.isEmpty) {
        noFragmentItems.add(item);
        continue;
      }
      final marker = '\n${_tocHeadingMarker(item)} ${item.title}\n';
      final pattern = RegExp(
        r'''<([a-zA-Z][a-zA-Z0-9:_-]*)([^>]*(?:id|name)\s*=\s*["']''' + RegExp.escape(fragment) + r'''["'][^>]*)>''',
        caseSensitive: false,
      );
      var matched = false;
      decorated = decorated.replaceFirstMapped(pattern, (m) {
        matched = true;
        insertedTitles.add(_normalizeForCompare(item.title));
        return '$marker${m.group(0)}';
      });
      if (!matched) noFragmentItems.add(item);
    }

    var text = _collapseAdjacentDuplicateHeadings(_htmlToStructuredText(decorated)).trim();
    final prefixLines = <String>[];
    for (final item in noFragmentItems) {
      final normalized = _normalizeForCompare(item.title);
      if (normalized.isEmpty || insertedTitles.contains(normalized) || _textStartsWithSameHeading(text, item.title)) continue;
      prefixLines.add('${_tocHeadingMarker(item)} ${item.title}');
      insertedTitles.add(normalized);
      // 同一个文件没有锚点时，通常只有一个可靠入口。多个无锚点目录项无法稳定切分正文，
      // 避免连续插入多个空标题导致最后一个标题吞掉整页内容。
      break;
    }
    if (prefixLines.isNotEmpty) {
      text = '${prefixLines.join('\n')}\n\n$text';
    }
    return text;
  }

  static String _collapseAdjacentDuplicateHeadings(String text) {
    final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final result = <String>[];
    String lastHeading = '';
    var lastHeadingLine = -999;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final headingTitle = _markdownHeadingTitle(line) ?? _genericChapterTitle(line) ?? _genericSectionTitle(line);
      final normalized = headingTitle == null ? '' : _normalizeForCompare(headingTitle);
      if (normalized.isNotEmpty && normalized == lastHeading && i - lastHeadingLine <= 2) {
        continue;
      }
      if (normalized.isNotEmpty) {
        lastHeading = normalized;
        lastHeadingLine = i;
      }
      result.add(line);
    }
    return result.join('\n');
  }

  static String _tocHeadingMarker(_EpubTocItem item) {
    final level = item.level <= 1 ? 1 : (item.level >= 6 ? 6 : item.level);
    return '#'.padRight(level, '#');
  }

  static _EpubPackage _readEpubPackage(Map<String, ArchiveFile> byName) {
    try {
      final containerFile = byName['META-INF/container.xml'];
      if (containerFile == null) return const _EpubPackage.empty();
      final container = XmlDocument.parse(utf8.decode(_archiveFileBytes(containerFile), allowMalformed: true));
      final rootfile = container.descendants
          .whereType<XmlElement>()
          .firstWhere((e) => e.name.local == 'rootfile')
          .getAttribute('full-path');
      if (rootfile == null || !byName.containsKey(rootfile)) return const _EpubPackage.empty();
      final baseDir = rootfile.contains('/') ? rootfile.substring(0, rootfile.lastIndexOf('/') + 1) : '';
      final opf = XmlDocument.parse(utf8.decode(_archiveFileBytes(byName[rootfile]!), allowMalformed: true));
      final manifest = <String, String>{};
      final mediaTypes = <String, String>{};
      final navCandidates = <String>[];
      var ncxId = '';
      for (final item in opf.descendants.whereType<XmlElement>().where((e) => e.name.local == 'item')) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        if (id == null || href == null) continue;
        final fullHref = _normalizeZipPath('$baseDir$href');
        manifest[id] = fullHref;
        mediaTypes[id] = item.getAttribute('media-type') ?? '';
        final props = item.getAttribute('properties') ?? '';
        if (props.split(RegExp(r'\s+')).contains('nav')) navCandidates.add(fullHref);
        if ((item.getAttribute('media-type') ?? '').contains('ncx')) ncxId = id;
      }

      final spineNames = <String>[];
      final spineElements = opf.descendants.whereType<XmlElement>().where((e) => e.name.local == 'itemref').toList();
      for (final itemref in spineElements) {
        final idref = itemref.getAttribute('idref');
        final href = idref == null ? null : manifest[idref];
        if (href != null && byName.containsKey(href) && RegExp(r'\.(xhtml|html|htm)$', caseSensitive: false).hasMatch(href)) {
          spineNames.add(href);
        }
      }
      final spineElement = opf.descendants.whereType<XmlElement>().where((e) => e.name.local == 'spine').firstOrNull;
      final tocAttr = spineElement?.getAttribute('toc');
      final tocNames = <String>[
        ...navCandidates,
        if (tocAttr != null && manifest[tocAttr] != null) manifest[tocAttr]!,
        if (ncxId.isNotEmpty && manifest[ncxId] != null) manifest[ncxId]!,
      ];
      return _EpubPackage(rootfile: rootfile, baseDir: baseDir, manifest: manifest, spineNames: spineNames, tocNames: _dedupeStrings(tocNames));
    } catch (_) {
      return const _EpubPackage.empty();
    }
  }

  static List<_EpubTocItem> _extractEpubTocItems(Map<String, ArchiveFile> byName, _EpubPackage package) {
    final result = <_EpubTocItem>[];
    for (final tocName in package.tocNames) {
      final file = byName[tocName];
      if (file == null || file.isFile != true) continue;
      final raw = utf8.decode(_archiveFileBytes(file), allowMalformed: true);
      final baseDir = tocName.contains('/') ? tocName.substring(0, tocName.lastIndexOf('/') + 1) : '';
      if (tocName.toLowerCase().endsWith('.ncx')) {
        result.addAll(_extractNcxTocItems(raw, baseDir));
      } else {
        result.addAll(_extractNavTocItems(raw, baseDir));
      }
    }
    if (result.isNotEmpty) return _dedupeTocItems(result);

    // 兜底：有些 EPUB 没有规范 TOC，但文件名或 spine 顺序仍然可靠。
    return [
      for (final name in package.spineNames)
        _EpubTocItem(href: name, title: _titleFromEpubPath(name), level: 1),
    ];
  }

  static List<_EpubTocItem> _extractNavTocItems(String html, String baseDir) {
    try {
      final doc = XmlDocument.parse(html);
      final navs = doc.descendants.whereType<XmlElement>().where((e) {
        if (e.name.local.toLowerCase() != 'nav') return false;
        final type = (e.getAttribute('type') ?? e.getAttribute('epub:type') ?? '').toLowerCase();
        return type.contains('toc') || type.isEmpty;
      }).toList();
      final root = navs.firstOrNull ?? doc.rootElement;
      final items = <_EpubTocItem>[];

      void walkOl(XmlElement parent, int level) {
        final containers = parent.name.local.toLowerCase() == 'ol'
            ? <XmlElement>[parent]
            : parent.children.whereType<XmlElement>().where((e) => e.name.local.toLowerCase() == 'ol').toList();
        for (final ol in containers) {
          for (final li in ol.children.whereType<XmlElement>().where((e) => e.name.local.toLowerCase() == 'li')) {
            XmlElement? link;
            for (final child in li.children.whereType<XmlElement>()) {
              final local = child.name.local.toLowerCase();
              if (local == 'a' || local == 'span') {
                link = child;
                break;
              }
            }
            final href = link?.getAttribute('href') ?? '';
            final title = link?.innerText.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
            if (href.isNotEmpty && title.isNotEmpty && !_looksLikeNonContentTocTitle(title)) {
              items.add(_EpubTocItem(href: _resolveEpubHref(baseDir, href), title: title, level: level));
            }
            for (final child in li.children.whereType<XmlElement>().where((e) => e.name.local.toLowerCase() == 'ol')) {
              walkOl(child, level + 1);
            }
          }
        }
      }

      walkOl(root, 1);
      if (items.isEmpty) {
        for (final a in root.descendants.whereType<XmlElement>().where((e) => e.name.local.toLowerCase() == 'a')) {
          final href = a.getAttribute('href') ?? '';
          final title = a.innerText.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (href.isEmpty || title.isEmpty || _looksLikeNonContentTocTitle(title)) continue;
          items.add(_EpubTocItem(href: _resolveEpubHref(baseDir, href), title: title, level: 1));
        }
      }
      return items;
    } catch (_) {
      final items = <_EpubTocItem>[];
      for (final m in RegExp(r'''<a[^>]+href=["']([^"']+)["'][^>]*>(.*?)</a>''', caseSensitive: false, dotAll: true).allMatches(html)) {
        final href = m.group(1) ?? '';
        final title = _decodeHtmlEntities(_stripHtmlTags(m.group(2) ?? '')).replaceAll(RegExp(r'\s+'), ' ').trim();
        if (href.isEmpty || title.isEmpty || _looksLikeNonContentTocTitle(title)) continue;
        items.add(_EpubTocItem(href: _resolveEpubHref(baseDir, href), title: title, level: 1));
      }
      return items;
    }
  }

  static List<_EpubTocItem> _extractNcxTocItems(String xmlText, String baseDir) {
    try {
      final doc = XmlDocument.parse(xmlText);
      final items = <_EpubTocItem>[];

      void walkNavPoint(XmlElement navPoint, int level) {
        final label = navPoint.children.whereType<XmlElement>().where((e) => e.name.local == 'navLabel').firstOrNull;
        final textEl = label?.descendants.whereType<XmlElement>().where((e) => e.name.local == 'text').firstOrNull;
        final contentEl = navPoint.children.whereType<XmlElement>().where((e) => e.name.local == 'content').firstOrNull;
        final title = textEl?.innerText.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
        final src = contentEl?.getAttribute('src') ?? '';
        if (title.isNotEmpty && src.isNotEmpty && !_looksLikeNonContentTocTitle(title)) {
          items.add(_EpubTocItem(href: _resolveEpubHref(baseDir, src), title: title, level: level));
        }
        for (final child in navPoint.children.whereType<XmlElement>().where((e) => e.name.local == 'navPoint')) {
          walkNavPoint(child, level + 1);
        }
      }

      final navMap = doc.descendants.whereType<XmlElement>().where((e) => e.name.local == 'navMap').firstOrNull;
      final roots = (navMap ?? doc.rootElement).children.whereType<XmlElement>().where((e) => e.name.local == 'navPoint');
      for (final root in roots) {
        walkNavPoint(root, 1);
      }
      return items;
    } catch (_) {
      return const <_EpubTocItem>[];
    }
  }

  static String _resolveEpubHref(String baseDir, String href) {
    final clean = href.trim();
    if (clean.isEmpty) return '';
    if (clean.startsWith('#')) return _normalizeZipPath(baseDir) + clean;
    return _normalizeZipPath('$baseDir$clean');
  }


  static String _normalizeZipPath(String path) {
    var clean = path.trim().replaceAll('\\', '/');
    if (clean.isEmpty) return '';

    var fragment = '';
    final hashIndex = clean.indexOf('#');
    if (hashIndex >= 0) {
      fragment = clean.substring(hashIndex);
      clean = clean.substring(0, hashIndex);
    }

    final segments = <String>[];
    for (final rawPart in clean.split('/')) {
      final part = rawPart.trim();
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (segments.isNotEmpty) segments.removeLast();
        continue;
      }
      segments.add(part);
    }
    return segments.join('/') + fragment;
  }

  static String _stripFragment(String href) => href.split('#').first.trim();

  static bool _textStartsWithSameHeading(String text, String title) {
    final first = text.split('\n').map((e) => _cleanLine(e)).firstWhere((e) => e.trim().isNotEmpty, orElse: () => '');
    final a = _normalizeHeading(first);
    final b = _normalizeHeading(title);
    if (a.isEmpty || b.isEmpty) return false;
    return a == b || a.contains(b) || b.contains(a) || _normalizeForCompare(a) == _normalizeForCompare(b);
  }

  static String _normalizeForCompare(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\t\n\r，。！？!?；;：:、,.（）()\[\]【】「」“”‘’"\-—_]+'), '')
        .trim();
  }

  static bool _looksLikeSectionTitle(String title) {
    final t = title.trim();
    return RegExp(r'(节|小节|Section|SECTION|[0-9]+\.[0-9]+)').hasMatch(t);
  }

  static bool _looksLikeNonContentTocTitle(String title) {
    final t = title.trim().toLowerCase();
    return RegExp(r'^(封面|版权|目录|contents?|table of contents|cover|copyright|title page|扉页)$', caseSensitive: false).hasMatch(t);
  }

  static String _titleFromEpubPath(String path) {
    final base = path.split('/').last.replaceAll(RegExp(r'\.(xhtml|html|htm)$', caseSensitive: false), '');
    return base.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  }

  static List<String> _dedupeStrings(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final v = value.trim();
      if (v.isEmpty) continue;
      if (seen.add(v)) result.add(v);
    }
    return result;
  }

  static List<_EpubTocItem> _dedupeTocItems(Iterable<_EpubTocItem> values) {
    final seen = <String>{};
    final result = <_EpubTocItem>[];
    for (final item in values) {
      final key = _stripFragment(item.href);
      if (key.isEmpty || item.title.trim().isEmpty) continue;
      if (seen.add('$key|${item.title}|${item.level}')) result.add(item);
    }
    return result;
  }


  static String _extractPdfText(Uint8List data) {
    // Lightweight, dependency-free PDF text extraction. It works for many text-based PDFs
    // by reading content streams and decoding common text operators (Tj/TJ). Scanned PDFs
    // or PDFs with complex embedded fonts still need OCR and will fail gracefully.
    final raw = latin1.decode(data, allowInvalid: true);
    final parts = <String>[];

    for (final match in RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream').allMatches(raw)) {
      final streamText = match.group(1);
      if (streamText == null || streamText.isEmpty) continue;
      final start = match.start;
      final headerStart = raw.lastIndexOf('<<', start);
      final headerEnd = raw.lastIndexOf('>>', start);
      final header = headerStart >= 0 && headerEnd >= headerStart ? raw.substring(headerStart, headerEnd + 2).toLowerCase() : '';
      Uint8List streamBytes = latin1.encode(streamText);
      if (header.contains('flatedecode')) {
        try {
          streamBytes = Uint8List.fromList(zlib.decode(streamBytes));
        } catch (_) {
          continue;
        }
      } else if (header.contains('dctdecode') || header.contains('jp')) {
        continue;
      }
      final decoded = latin1.decode(streamBytes, allowInvalid: true);
      final text = _extractPdfTextOperators(decoded).trim();
      if (text.isNotEmpty) parts.add(text);
    }

    if (parts.isEmpty) {
      final fallback = _extractPdfTextOperators(raw).trim();
      if (fallback.isNotEmpty) parts.add(fallback);
    }

    final normalized = _normalizeText(parts.join('\n\n'));
    if (normalized.trim().length < 24) {
      throw const FormatException('未能从 PDF 中提取到有效正文。扫描版 PDF 暂不支持 OCR，请改用 EPUB/TXT/HTML，或先用 OCR 工具转成文本。');
    }
    return normalized;
  }

  static String _extractPdfTextOperators(String content) {
    final buffer = StringBuffer();
    for (final match in RegExp(r'\((?:\\.|[^\\()])*\)\s*Tj', dotAll: true).allMatches(content)) {
      final token = match.group(0) ?? '';
      final start = token.indexOf('(');
      final end = token.lastIndexOf(')');
      if (start >= 0 && end > start) buffer.writeln(_decodePdfLiteralString(token.substring(start + 1, end)));
    }
    for (final match in RegExp(r'\[(.*?)\]\s*TJ', dotAll: true).allMatches(content)) {
      final body = match.group(1) ?? '';
      final line = RegExp(r'\((?:\\.|[^\\()])*\)', dotAll: true).allMatches(body).map((m) {
        final token = m.group(0) ?? '';
        return _decodePdfLiteralString(token.substring(1, token.length - 1));
      }).join('');
      if (line.trim().isNotEmpty) buffer.writeln(line);
    }
    for (final match in RegExp(r'<([0-9A-Fa-f\s]+)>\s*Tj', dotAll: true).allMatches(content)) {
      final line = _decodePdfHexString(match.group(1) ?? '');
      if (line.trim().isNotEmpty) buffer.writeln(line);
    }
    return buffer.toString();
  }

  static String _decodePdfLiteralString(String value) {
    final out = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final ch = value[i];
      if (ch != '\\') {
        out.write(ch);
        continue;
      }
      if (i + 1 >= value.length) break;
      final next = value[++i];
      switch (next) {
        case 'n':
          out.write('\n');
          break;
        case 'r':
          out.write('\n');
          break;
        case 't':
          out.write(' ');
          break;
        case 'b':
        case 'f':
          break;
        case '(':
        case ')':
        case '\\':
          out.write(next);
          break;
        default:
          if (RegExp(r'[0-7]').hasMatch(next)) {
            var octal = next;
            var consumed = 0;
            while (i + 1 < value.length && consumed < 2 && RegExp(r'[0-7]').hasMatch(value[i + 1])) {
              octal += value[++i];
              consumed++;
            }
            final code = int.tryParse(octal, radix: 8);
            if (code != null) out.writeCharCode(code);
          } else {
            out.write(next);
          }
      }
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _decodePdfHexString(String hex) {
    final clean = hex.replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) return '';
    final bytes = <int>[];
    for (var i = 0; i < clean.length - 1; i += 2) {
      final b = int.tryParse(clean.substring(i, i + 2), radix: 16);
      if (b != null) bytes.add(b);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final units = <int>[];
      for (var i = 2; i + 1 < bytes.length; i += 2) {
        units.add((bytes[i] << 8) | bytes[i + 1]);
      }
      return String.fromCharCodes(units).replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return latin1.decode(bytes, allowInvalid: true).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _extractFb2Text(Uint8List data) {
    final xmlText = _decodeText(data);
    final doc = XmlDocument.parse(xmlText);
    final lines = <String>[];
    void walk(XmlNode node) {
      if (node is XmlElement) {
        final local = node.name.local.toLowerCase();
        if (local == 'title') {
          final title = node.innerText.trim();
          if (title.isNotEmpty) lines.add('# $title');
          return;
        }
        if (local == 'subtitle') {
          final title = node.innerText.trim();
          if (title.isNotEmpty) lines.add('## $title');
          return;
        }
        if (local == 'p') {
          final text = node.innerText.trim();
          if (text.isNotEmpty) lines.add(text);
          return;
        }
      }
      for (final child in node.children) {
        walk(child);
      }
    }
    walk(doc.rootElement);
    return lines.join('\n\n');
  }

  static String _extractRtfText(Uint8List data) {
    var text = _decodeText(data);
    text = text.replaceAll(RegExp(r"\\par[d]?\b"), '\n');
    text = text.replaceAll(RegExp(r"\\line\b"), '\n');
    text = text.replaceAllMapped(RegExp(r"\\'([0-9a-fA-F]{2})"), (m) {
      final value = int.tryParse(m.group(1)!, radix: 16);
      return value == null ? '' : String.fromCharCode(value);
    });
    text = text.replaceAll(RegExp(r'\\[a-zA-Z]+-?\d* ?'), '');
    text = text.replaceAll(RegExp(r'[{}]'), '');
    return text;
  }

  static String _htmlToStructuredText(String html) {
    var value = html;
    value = value.replaceAll(RegExp(r'<\s*(script|style)[^>]*>.*?<\s*/\s*\1\s*>', caseSensitive: false, dotAll: true), '');
    value = value.replaceAllMapped(RegExp(r'<\s*h([1-6])[^>]*>(.*?)<\s*/\s*h\1\s*>', caseSensitive: false, dotAll: true), (m) {
      final level = int.tryParse(m.group(1) ?? '1') ?? 1;
      final marker = '#'.padRight(level, '#');
      return '\n$marker ${_stripHtmlTags(m.group(2) ?? '')}\n';
    });
    value = value.replaceAll(RegExp(r'<\s*(p|div|section|article|li|br|tr)[^>]*>', caseSensitive: false), '\n');
    value = value.replaceAll(RegExp(r'<\s*/\s*(p|div|section|article|li|tr|td|th|blockquote)\s*>', caseSensitive: false), '\n');
    value = _stripHtmlTags(value);
    return _decodeHtmlEntities(value);
  }

  static String _stripHtmlTags(String value) => value.replaceAll(RegExp(r'<[^>]+>', dotAll: true), ' ');

  static String _decodeHtmlEntities(String value) {
    const named = <String, String>{
      '&nbsp;': ' ',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
    };
    var result = value;
    named.forEach((k, v) => result = result.replaceAll(k, v));
    result = result.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1)!);
      return code == null ? '' : String.fromCharCode(code);
    });
    result = result.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m.group(1)!, radix: 16);
      return code == null ? '' : String.fromCharCode(code);
    });
    return result;
  }

  static Uint8List _archiveFileBytes(ArchiveFile file) {
    final raw = file.content;
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    return Uint8List.fromList(List<int>.from(raw as Iterable<dynamic>));
  }

  static String _normalizeText(String text) {
    return _decodeHtmlEntities(text)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u3000', ' ')
        .replaceAll(RegExp(r'[\t ]+'), ' ')
        .split('\n')
        .map((line) => line.trimRight())
        .join('\n')
        .replaceAll(RegExp(r'\n{4,}'), '\n\n\n')
        .trim();
  }

  static String _deriveTitle(String fileName, String text) {
    final base = fileName.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
    if (base.isNotEmpty) return base;
    final firstLine = text
        .split('\n')
        .map((e) => _cleanLine(e).trim())
        .firstWhere((e) => e.isNotEmpty, orElse: () => '导入课程');
    return firstLine.length > 32 ? firstLine.substring(0, 32) : firstLine;
  }

  static List<CcImportedChapter> _splitChapters(String text) {
    final rawLines = text.split('\n');
    final allLines = rawLines.map(_cleanLine).toList();
    final headings = <_Heading>[];

    // 1) 优先识别明确章标题：第……章、Chapter/Lecture/Lesson 等。
    // 这能避免把电子书封面、书名、目录页误当作正文第一章。
    for (var i = 0; i < allLines.length; i++) {
      final title = _chapterTitle(allLines[i]);
      if (title != null) headings.add(_Heading(i, title, _extractInlineKeywords(allLines[i])));
    }

    // 2) 没有明确章标题时，使用电子书/Markdown/HTML 的一级标题作为章。
    // EPUB 导入时会从 nav.xhtml / toc.ncx 目录注入 # 标题，所以这里能覆盖
    // 很多没有“第……章”字样的电子书。
    if (headings.isEmpty) {
      final markdownChapters = <_Heading>[];
      for (var i = 0; i < rawLines.length; i++) {
        final level = _markdownHeadingLevel(rawLines[i]);
        if (level == 1) {
          final title = _markdownHeadingTitle(rawLines[i]);
          if (title != null && !_looksLikeNonContentTocTitle(title)) {
            markdownChapters.add(_Heading(i, title, _extractInlineKeywords(title)));
          }
        }
      }
      if (markdownChapters.length >= 2) headings.addAll(markdownChapters);
    }

    // 3) 如果没有一级标题，但存在多个二级标题，则把二级标题提升为章。
    if (headings.isEmpty) {
      final h2Chapters = <_Heading>[];
      for (var i = 0; i < rawLines.length; i++) {
        final level = _markdownHeadingLevel(rawLines[i]);
        if (level == 2) {
          final title = _markdownHeadingTitle(rawLines[i]);
          if (title != null && !_looksLikeNonContentTocTitle(title)) h2Chapters.add(_Heading(i, title));
        }
      }
      if (h2Chapters.length >= 2) headings.addAll(h2Chapters);
    }

    // 4) 兜底识别“独立短标题”：要求标题前后有空行，避免把普通短句误当章。
    if (headings.isEmpty) {
      final generic = <_Heading>[];
      for (var i = 0; i < allLines.length; i++) {
        final title = _genericChapterTitle(allLines[i]);
        if (title == null) continue;
        final prevBlank = i == 0 || allLines[i - 1].trim().isEmpty;
        final nextNotBlank = i + 1 < allLines.length && allLines[i + 1].trim().isNotEmpty;
        if (prevBlank && nextNotBlank) generic.add(_Heading(i, title));
      }
      if (generic.length >= 2) headings.addAll(generic);
    }

    if (headings.isEmpty) {
      final sectionResult = _splitSectionResult(allLines);
      final sections = sectionResult.sections.isEmpty
          ? <CcImportedSection>[_parseSectionBlock(title: '导入内容', lines: allLines)]
          : sectionResult.sections;
      final validSections = sections.where((s) => s.content.trim().isNotEmpty || s.keywords.isNotEmpty).toList();
      if (validSections.isEmpty) return const <CcImportedChapter>[];
      final content = validSections.map((s) => s.content.trim()).where((s) => s.isNotEmpty).join('\n\n');
      final keywords = _dedupeKeywords([for (final s in validSections) ...s.keywords]);
      return [
        CcImportedChapter(
          title: _deriveChapterFallbackTitle(allLines),
          content: content,
          keywords: keywords.isNotEmpty ? keywords : extractKeywords(content, max: 16),
          sections: validSections,
        ),
      ];
    }

    final chapters = <CcImportedChapter>[];
    for (var i = 0; i < headings.length; i++) {
      final heading = headings[i];
      final start = heading.lineIndex + 1;
      final end = i + 1 < headings.length ? headings[i + 1].lineIndex : allLines.length;
      final rawChapterLines = allLines.sublist(start, end);
      final sectionResult = _splitSectionResult(rawChapterLines);
      final sections = sectionResult.sections.isEmpty
          ? <CcImportedSection>[_parseSectionBlock(title: '本章内容', lines: rawChapterLines)]
          : sectionResult.sections;
      final validSections = sections.where((section) => section.content.trim().isNotEmpty || section.keywords.isNotEmpty).toList();
      final chapterContent = validSections
          .map((section) => section.content.trim())
          .where((content) => content.isNotEmpty)
          .join('\n\n')
          .trim();
      final chapterKeywordCandidates = <String>[
        ...heading.keywords,
        for (final section in validSections) ...section.keywords,
      ];
      if (chapterContent.trim().isEmpty && validSections.isEmpty) continue;
      chapters.add(CcImportedChapter(
        title: heading.title,
        content: chapterContent.isEmpty ? heading.title : chapterContent,
        keywords: _dedupeKeywords(chapterKeywordCandidates.isEmpty ? extractKeywords('${heading.title}\n$chapterContent', max: 16) : chapterKeywordCandidates),
        sections: validSections.isEmpty
            ? [
                CcImportedSection(
                  title: '本章内容',
                  content: chapterContent.isEmpty ? heading.title : chapterContent,
                  keywords: heading.keywords,
                ),
              ]
            : validSections,
      ));
    }
    return chapters;
  }

  static int _markdownHeadingLevel(String line) {
    final match = RegExp(r'^\s*(#{1,6})\s+(.+?)\s*$').firstMatch(line);
    return match == null ? 0 : (match.group(1) ?? '').length;
  }

  static String? _markdownHeadingTitle(String line) {
    final match = RegExp(r'^\s*#{1,6}\s+(.+?)\s*$').firstMatch(line);
    if (match == null) return null;
    final title = _normalizeHeading(match.group(1) ?? '');
    if (title.isEmpty || title.length > 120) return null;
    if (_isKeywordMarkerLine(title) || _isOriginalContentMarkerLine(title)) return null;
    return title;
  }

  static _SectionSplitResult _splitSectionResult(List<String> chapterLines) {
    final headings = <_Heading>[];
    for (var i = 0; i < chapterLines.length; i++) {
      final title = _sectionTitle(chapterLines[i]);
      if (title != null) headings.add(_Heading(i, title, _extractInlineKeywords(chapterLines[i])));
    }

    if (headings.isEmpty) {
      final generic = <_Heading>[];
      for (var i = 0; i < chapterLines.length; i++) {
        final title = _genericSectionTitle(chapterLines[i]);
        if (title == null) continue;
        final prevBlank = i == 0 || chapterLines[i - 1].trim().isEmpty;
        final nextNotBlank = i + 1 < chapterLines.length && chapterLines[i + 1].trim().isNotEmpty;
        if (prevBlank && nextNotBlank) generic.add(_Heading(i, title));
      }
      if (generic.length >= 2) headings.addAll(generic);
    }

    if (headings.isEmpty) {
      final section = _parseSectionBlock(title: '本章内容', lines: chapterLines);
      return _SectionSplitResult(
        cleanContent: section.content,
        sections: section.content.trim().isEmpty && section.keywords.isEmpty ? const <CcImportedSection>[] : [section],
      );
    }

    final sections = <CcImportedSection>[];
    final leadLines = chapterLines.sublist(0, headings.first.lineIndex);
    final lead = _parseSectionBlock(title: '本章导读', lines: leadLines);
    if (lead.content.trim().length >= 20) sections.add(lead);

    for (var i = 0; i < headings.length; i++) {
      final heading = headings[i];
      final start = heading.lineIndex + 1;
      final end = i + 1 < headings.length ? headings[i + 1].lineIndex : chapterLines.length;
      final blockLines = chapterLines.sublist(start, end);
      final section = _parseSectionBlock(title: heading.title, lines: blockLines, inlineKeywords: heading.keywords);
      if (section.content.trim().isNotEmpty || section.keywords.isNotEmpty) sections.add(section);
    }

    final cleanContent = sections.map((section) => section.content.trim()).where((content) => content.isNotEmpty).join('\n\n').trim();
    return _SectionSplitResult(cleanContent: cleanContent, sections: sections);
  }

  static CcImportedSection _parseSectionBlock({
    required String title,
    required List<String> lines,
    List<String> inlineKeywords = const <String>[],
  }) {
    final keywordIndex = lines.indexWhere(_isKeywordMarkerLine);
    final originalIndex = lines.indexWhere(_isOriginalContentMarkerLine);

    final keywords = <String>[...inlineKeywords];
    if (keywordIndex >= 0) {
      final inline = _keywordTextOnMarkerLine(lines[keywordIndex]);
      if (inline.isNotEmpty && inline != lines[keywordIndex].trim()) keywords.addAll(_splitKeywordText(inline));

      final start = keywordIndex + 1;
      var end = lines.length;
      for (var i = start; i < lines.length; i++) {
        if (_isOriginalContentMarkerLine(lines[i])) {
          end = i;
          break;
        }
        if (lines[i].trim().isEmpty) {
          end = i;
          break;
        }
      }
      if (start < end) {
        final keywordLines = lines.sublist(start, end).where((line) => line.trim().isNotEmpty);
        for (final line in keywordLines) {
          keywords.addAll(_splitKeywordText(line));
        }
      }
    }

    final contentLines = <String>[];
    if (originalIndex >= 0) {
      contentLines.addAll(lines.sublist(originalIndex + 1));
    } else {
      final keywordEnd = keywordIndex >= 0 ? _keywordBlockEnd(lines, keywordIndex) : -1;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (_isKeywordMarkerLine(line) || _isOriginalContentMarkerLine(line)) continue;
        if (keywordIndex >= 0 && i > keywordIndex && i < keywordEnd) continue;
        contentLines.add(line);
      }
    }

    final content = _cleanContent(contentLines);
    final finalKeywords = _dedupeKeywords(keywords.isNotEmpty ? keywords : extractKeywords('$title\n$content', max: 20));
    return CcImportedSection(title: title, content: content.isEmpty ? title : content, keywords: finalKeywords);
  }

  static int _keywordBlockEnd(List<String> lines, int keywordIndex) {
    for (var i = keywordIndex + 1; i < lines.length; i++) {
      if (_isOriginalContentMarkerLine(lines[i]) || lines[i].trim().isEmpty) return i;
    }
    return lines.length;
  }

  static String _cleanLine(String line) {
    return line
        .replaceAll(RegExp(r'[\t ]+'), ' ')
        .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*'), '')
        .replaceAll(RegExp(r'^[\-—–•·]+\s*'), '')
        .replaceAll(RegExp(r'^>+\s*'), '')
        .trimRight()
        .trimLeft();
  }

  static String _cleanContent(List<String> lines) {
    final joined = lines.join('\n');
    return joined
        .replaceAll(RegExp(r'\n[ \t]+'), '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _deriveChapterFallbackTitle(List<String> lines) {
    final firstTitle = lines.map(_cleanLine).firstWhere((line) => line.isNotEmpty && line.length <= 60, orElse: () => '导入内容');
    return firstTitle;
  }

  static String? _chapterTitle(String line) {
    final trimmed = _cleanLine(line);
    if (trimmed.isEmpty || trimmed.length > 110) return null;
    final patterns = <RegExp>[
      RegExp(r'^第\s*[一二三四五六七八九十百千万零〇两0-9]+\s*(?:章节|章|讲|课|篇|部分|单元)\s*[：:、.\-—]?\s*(.*)$'),
      RegExp(r'^(Chapter|CHAPTER|Lecture|LECTURE|Lesson|LESSON)\s+[0-9IVXLC]+\s*[:：.\-—]?\s*(.*)$'),
      RegExp(r'^[卷册部篇]\s*[一二三四五六七八九十百千万零〇两0-9]+\s*[：:、.\-—]?\s*(.*)$'),
    ];
    for (final pattern in patterns) {
      if (pattern.hasMatch(trimmed)) return _normalizeHeading(trimmed);
    }
    return null;
  }

  static String? _sectionTitle(String line) {
    final trimmed = _cleanLine(line);
    if (trimmed.isEmpty || trimmed.length > 110) return null;
    if (_isKeywordMarkerLine(trimmed) || _isOriginalContentMarkerLine(trimmed)) return null;
    final patterns = <RegExp>[
      RegExp(r'^第\s*[一二三四五六七八九十百千万零〇两0-9]+\s*(?:小节|节)\s*[：:、.\-—]?\s*(.*)$'),
      RegExp(r'^[（(]\s*[一二三四五六七八九十百千万零〇两0-9]+\s*[）)]\s*[^。！？!?]{1,80}$'),
      RegExp(r'^[一二三四五六七八九十百千万零〇两]+[、.]\s*[^。！？!?]{1,80}$'),
      RegExp(r'^[0-9]+\.[0-9]+(?:\.[0-9]+)?\s*[、.\-—]?\s*[^。！？!?]{1,90}$'),
      RegExp(r'^[0-9]{1,2}[、)]\s*[^。！？!?]{1,90}$'),
      RegExp(r'^(Section|SECTION)\s+[0-9IVXLC]+\s*[:：.\-—]?\s*(.*)$'),
    ];
    for (final pattern in patterns) {
      if (pattern.hasMatch(trimmed)) return _normalizeHeading(trimmed);
    }
    return null;
  }

  static String? _genericChapterTitle(String line) {
    final trimmed = _cleanLine(line);
    if (trimmed.isEmpty || trimmed.length > 80) return null;
    if (_isKeywordMarkerLine(trimmed) || _isOriginalContentMarkerLine(trimmed)) return null;
    if (RegExp(r'[。！？!?；;，,]$').hasMatch(trimmed)) return null;
    if (RegExp(r'^(序言|前言|导言|绪论|引言|结语|后记)$').hasMatch(trimmed)) return trimmed;
    if (RegExp(r'^[0-9]{1,3}\s+[A-Za-z\u4e00-\u9fa5][^。！？!?]{1,60}$').hasMatch(trimmed)) return trimmed;
    // 兼容电子书常见目录：HTML/EPUB 的 h1 标题、Markdown 一级标题，
    // 往往只是一个短标题，并不一定写“第……章”。
    if (trimmed.length >= 3 && trimmed.length <= 60 &&
        RegExp(r'[A-Za-z\u4e00-\u9fa5]').hasMatch(trimmed) &&
        !RegExp(r'^(该节|该章|本节|本章|关键|原文|正文|课程内容)').hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }

  static String? _genericSectionTitle(String line) {
    final trimmed = _cleanLine(line);
    if (trimmed.isEmpty || trimmed.length > 70) return null;
    if (_isKeywordMarkerLine(trimmed) || _isOriginalContentMarkerLine(trimmed)) return null;
    if (RegExp(r'^[A-Za-z\u4e00-\u9fa5][A-Za-z0-9\u4e00-\u9fa5\s“”《》：:、\-—]{2,68}$').hasMatch(trimmed) && !RegExp(r'[。！？!?]$').hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }

  static String _normalizeHeading(String line) {
    return _cleanLine(line)
        .replaceFirst(RegExp(r'\s*(关键词|关键字|关联字|核心词|Keywords?)\s*[:：].*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*[:：、.\-—]\s*$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _isKeywordMarkerLine(String line) {
    return RegExp(r'(该节\s*主要\s*)?(关键词|关键字|关联字|核心词|Keywords?)', caseSensitive: false).hasMatch(_cleanLine(line));
  }

  static bool _isOriginalContentMarkerLine(String line) {
    return RegExp(r'(该节\s*对应\s*)?(原文\s*直译\s*内容|课程\s*内容|正文\s*内容)').hasMatch(_cleanLine(line));
  }

  static String _keywordTextOnMarkerLine(String line) {
    final match = RegExp(r'(?:关键词|关键字|关联字|核心词|Keywords?)\s*[:：：、]?\s*(.*)$', caseSensitive: false).firstMatch(_cleanLine(line));
    return match == null ? '' : (match.group(1) ?? '').trim();
  }

  static List<String> _extractInlineKeywords(String line) {
    final raw = _keywordTextOnMarkerLine(line);
    if (raw.isEmpty || raw == _cleanLine(line)) return const <String>[];
    return _splitKeywordText(raw);
  }

  static List<String> _splitKeywordText(String raw) {
    return _dedupeKeywords(raw
        .replaceAll(RegExp(r'^[：:、,，；;\s]+'), '')
        .split(RegExp(r'[,，、/;；|｜\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty));
  }

  static List<String> extractKeywords(String text, {int max = 8}) {
    final stopWords = <String>{
      '我们', '你们', '他们', '自己', '一个', '一种', '因为', '所以', '但是', '如果', '这个', '那个',
      '可以', '没有', '不是', '进行', '通过', '需要', '如何', '什么', '以及', '并且', '或者', '这些',
      '那些', '内容', '课程', '本章', '导入', '学习', '时候', '已经', '仍然', '真正', '必须', '逐步',
      '标题', '名称', '关键字', '关键词', '关联字', '第一章', '第二章', '第三章', '第四章', '第五章',
      '原文', '直译', '主要', '对应', '该节', '该章', '相关', '小节', '章节', '本节',
    };
    final counts = <String, int>{};
    final normalized = text.replaceAll(RegExp(r'[\n\r\t]+'), ' ');

    for (final match in RegExp(r'[\u4e00-\u9fa5]{2,8}|[A-Za-z][A-Za-z\-]{2,}').allMatches(normalized)) {
      final raw = match.group(0)!.trim();
      if (raw.length < 2 || raw.length > 16) continue;
      if (stopWords.contains(raw)) continue;
      if (RegExp(r'^第[一二三四五六七八九十百千万零〇两0-9]+[章节节小节]').hasMatch(raw)) continue;
      counts[raw] = (counts[raw] ?? 0) + 1;
    }

    final titleCandidates = text
        .split(RegExp(r'[\n。！？!?；;，,：:、（）()\[\]【】\s]+'))
        .map((e) => e.trim())
        .where((e) => e.length >= 2 && e.length <= 8 && !stopWords.contains(e))
        .take(8);
    for (final candidate in titleCandidates) {
      counts[candidate] = (counts[candidate] ?? 0) + 3;
    }

    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.length.compareTo(b.key.length);
      });
    return entries.map((e) => e.key).take(max).toList();
  }

  static List<String> _dedupeKeywords(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final keyword = value
          .trim()
          .replaceAll(RegExp(r'^(关键词|关键字|关联字|核心词|Keywords?)\s*[:：、]?', caseSensitive: false), '')
          .replaceAll(RegExp(r'^[:：、,，]+|[:：、,，]+$'), '')
          .trim();
      if (keyword.length < 2 || keyword.length > 24) continue;
      if (seen.add(keyword)) result.add(keyword);
    }
    return result;
  }
}

class _Heading {
  final int lineIndex;
  final String title;
  final List<String> keywords;

  const _Heading(this.lineIndex, this.title, [this.keywords = const <String>[]]);
}

class _SectionSplitResult {
  final String cleanContent;
  final List<CcImportedSection> sections;

  const _SectionSplitResult({required this.cleanContent, required this.sections});
}


class _EpubPackage {
  final String rootfile;
  final String baseDir;
  final Map<String, String> manifest;
  final List<String> spineNames;
  final List<String> tocNames;

  const _EpubPackage({
    required this.rootfile,
    required this.baseDir,
    required this.manifest,
    required this.spineNames,
    required this.tocNames,
  });

  const _EpubPackage.empty()
      : rootfile = '',
        baseDir = '',
        manifest = const <String, String>{},
        spineNames = const <String>[],
        tocNames = const <String>[];
}

class _EpubTocItem {
  final String href;
  final String title;
  final int level;

  const _EpubTocItem({required this.href, required this.title, this.level = 1});
}


class _EpubTextBlock {
  final String text;
  final int? explicitHeadingLevel;
  final String fileName;
  final bool isLinkOnly;
  final bool looksLikeTocEntry;

  const _EpubTextBlock({
    required this.text,
    required this.fileName,
    this.explicitHeadingLevel,
    this.isLinkOnly = false,
    this.looksLikeTocEntry = false,
  });

  _EpubTextBlock copyWith({
    String? text,
    int? explicitHeadingLevel,
    String? fileName,
    bool? isLinkOnly,
    bool? looksLikeTocEntry,
  }) {
    return _EpubTextBlock(
      text: text ?? this.text,
      explicitHeadingLevel: explicitHeadingLevel ?? this.explicitHeadingLevel,
      fileName: fileName ?? this.fileName,
      isLinkOnly: isLinkOnly ?? this.isLinkOnly,
      looksLikeTocEntry: looksLikeTocEntry ?? this.looksLikeTocEntry,
    );
  }
}


extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
