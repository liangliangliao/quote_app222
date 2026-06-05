import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:epub_view/epub_view.dart' as epub;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'conscious_change_dao.dart';
import 'conscious_change_import_parser.dart';
import 'remote_ebook_download_page.dart';

enum _CcLibraryMode { courses, books }

extension _CcLibraryModeX on _CcLibraryMode {
  String get documentType => this == _CcLibraryMode.books ? 'book' : 'course';
  String get title => this == _CcLibraryMode.books ? '阅读书籍' : '课程目录';
}

class ConsciousChangeHomePage extends StatelessWidget {
  const ConsciousChangeHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConsciousChangeLearningPage()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.menu_book_outlined, color: Color(0xFF4F46E5)),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '学习模块',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                        ),
                        SizedBox(height: 8),
                        Text(
                          consciousChangeCoreIdea,
                          style: TextStyle(color: Color(0xFF6B7280), height: 1.55, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class ConsciousChangeLearningPage extends StatefulWidget {
  const ConsciousChangeLearningPage({super.key});

  @override
  State<ConsciousChangeLearningPage> createState() => _ConsciousChangeLearningPageState();
}

class _ConsciousChangeLearningPageState extends State<ConsciousChangeLearningPage> {
  final ConsciousChangeDao _dao = ConsciousChangeDao();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _importing = false;
  bool _searching = false;
  _CcLibraryMode _libraryMode = _CcLibraryMode.courses;
  String? _error;
  List<CcLearningDocument> _documents = const <CcLearningDocument>[];
  Map<int, List<CcLearningChapter>> _chaptersByDocument = const <int, List<CcLearningChapter>>{};
  Map<int, CcReadingPosition> _readingPositionsByDocument = const <int, CcReadingPosition>{};
  final Set<int> _expandedDocumentIds = <int>{};
  List<CcSearchHit> _searchHits = const <CcSearchHit>[];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() {
        _error = null;
      });
    }
    try {
      await _dao.ensureSchema();
      final docs = await _dao.listDocuments(documentType: _libraryMode.documentType);
      final chapterMap = <int, List<CcLearningChapter>>{};
      for (final doc in docs) {
        chapterMap[doc.id] = await _dao.listChapters(doc.id);
      }
      final readingPositions = await _dao.getReadingPositionsForDocuments(docs.map((d) => d.id).toList());
      if (!mounted) return;
      setState(() {
        _documents = docs;
        _chaptersByDocument = chapterMap;
        _readingPositionsByDocument = readingPositions;
        _loading = false;
      });
      await _runSearch(_searchController.text, immediate: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _importLearningFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _libraryMode == _CcLibraryMode.books
            ? ConsciousChangeImportParser.supportedBookExtensions
            : ConsciousChangeImportParser.supportedExtensions,
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      setState(() {
        _importing = true;
        _error = null;
      });

      var success = 0;
      final failures = <String>[];
      for (final file in result.files) {
        final extension = (file.extension ?? file.name.split('.').last).toLowerCase();
        try {
          final fileBytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
          final persistedPath = _libraryMode == _CcLibraryMode.books && extension == 'epub' && fileBytes != null
              ? await _persistImportedBookFile(fileName: file.name, extension: extension, bytes: fileBytes)
              : (file.path ?? '');
          final parsed = await ConsciousChangeImportParser.parseFile(
            fileName: file.name,
            extension: extension,
            bytes: fileBytes,
            path: file.path,
            preferBookStructure: _libraryMode == _CcLibraryMode.books,
          );
          await _dao.createDocumentWithChapters(
            title: parsed.title,
            fileName: file.name,
            fileExt: extension,
            sourcePath: persistedPath,
            documentType: _libraryMode.documentType,
            chapters: parsed.chapters,
          );
          success++;
        } catch (e) {
          failures.add('${file.name}：${_cleanError(e)}');
        }
      }
      if (!mounted) return;
      final message = failures.isEmpty
          ? '已导入 $success 个文件。'
          : "已导入 $success 个文件，失败 ${failures.length} 个：${failures.take(2).join('；')}";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：${_cleanError(e)}')),
      );
    } finally {
      if (mounted) setState(() { _importing = false; });
    }
  }


  Future<String> _persistImportedBookFile({
    required String fileName,
    required String extension,
    required Uint8List bytes,
  }) async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/conscious_change_books');
    if (!await dir.exists()) await dir.create(recursive: true);
    final safeBase = fileName
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-\u4e00-\u9fa5]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/${stamp}_${safeBase.isEmpty ? 'book' : safeBase}.$extension');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 260), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String value, {bool immediate = false}) async {
    final query = value.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _searchHits = const <CcSearchHit>[];
        _searching = false;
      });
      return;
    }
    if (!immediate && mounted) setState(() { _searching = true; });
    final hits = await _dao.search(query, documentType: _libraryMode.documentType);
    if (!mounted) return;
    setState(() {
      _searchHits = hits;
      _searching = false;
    });
  }

  Future<void> _openRemoteEbookDownload() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RemoteEbookDownloadPage()),
    );
    if (changed == true && mounted) {
      await _load(showLoading: false);
    }
  }

  Future<void> _deleteDocument(CcLearningDocument document) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_libraryMode == _CcLibraryMode.books ? '删除书籍' : '删除课程'),
        content: Text(_libraryMode == _CcLibraryMode.books ? '确定删除「${document.title}」吗？该书籍下的目录与正文也会一起删除。' : '确定删除「${document.title}」吗？该课程下的章节与小节也会一起删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await _dao.deleteDocument(document.id);
    await _load();
  }

  Future<void> _clearAllCourses() async {
    if (_documents.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_libraryMode == _CcLibraryMode.books ? '清空全部书籍' : '清空全部课程'),
        content: Text(_libraryMode == _CcLibraryMode.books ? '确定清空所有已导入书籍吗？该操作会删除书籍目录、正文和阅读位置，且无法撤销。' : '确定清空所有已导入课程吗？该操作会删除所有章节、小节和阅读位置，且无法撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok != true) return;
    await _dao.clearAllDocuments(documentType: _libraryMode.documentType);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_libraryMode == _CcLibraryMode.books ? '已清空所有书籍内容' : '已清空所有课程内容')));
    await _load();
  }

  Future<void> _deleteChapter(CcLearningChapter chapter) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除章节'),
        content: Text('确定删除「${chapter.title}」吗？该章节下的全部小节和内容也会删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await _dao.deleteChapter(chapter.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除章节')));
    await _load();
  }

  Future<void> _showChapterActions(CcLearningChapter chapter) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                chapter.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
              title: const Text('删除该章全部内容', style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w800)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'delete') await _deleteChapter(chapter);
  }

  Future<void> _continueReading(CcReadingPosition position) async {
    // 最近阅读必须和正常入口保持同一条阅读链路。
    // 书籍模块现在使用导入阶段生成的应用内阅读单元和目录，
    // 不能再从最近阅读跳到 epub_view，否则会重新出现只有 Chapter 1 的错误目录。
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConsciousChangeSectionDetailPage(
          sectionId: position.sectionId,
          initialScrollOffset: position.scrollOffset,
          readerMode: position.documentType == 'book',
        ),
      ),
    );
    if (mounted) await _load(showLoading: false);
  }

  Future<void> _reorderDocuments(int oldIndex, int newIndex) async {
    final documents = List<CcLearningDocument>.from(_documents);
    if (oldIndex < 0 || oldIndex >= documents.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, documents.length - 1).toInt();
    final moved = documents.removeAt(oldIndex);
    documents.insert(newIndex, moved);
    setState(() {
      _documents = documents;
    });
    await _dao.reorderDocuments(documents.map((d) => d.id).toList());
  }

  Future<void> _reorderChaptersForDocument(CcLearningDocument doc, int oldIndex, int newIndex) async {
    final chapters = List<CcLearningChapter>.from(_chaptersByDocument[doc.id] ?? const <CcLearningChapter>[]);
    if (oldIndex < 0 || oldIndex >= chapters.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, chapters.length - 1).toInt();
    final moved = chapters.removeAt(oldIndex);
    chapters.insert(newIndex, moved);
    setState(() {
      _chaptersByDocument = <int, List<CcLearningChapter>>{
        ..._chaptersByDocument,
        doc.id: chapters,
      };
    });
    await _dao.reorderChapters(doc.id, chapters.map((c) => c.id).toList());
  }

  Future<void> _openBookDocument(CcLearningDocument document) async {
    final saved = await _dao.getReadingPositionForDocument(document.id);
    // v26：阅读书籍不再直接进入 epub_view。部分 EPUB 自带 toc.ncx/nav.xhtml
    // 只有一个 Chapter 1，epub_view 只能按这个错误目录显示，无法按书中大写标题分页。
    // 导入时已经按 OPF spine + HTML 大标题生成了阅读单元，这里统一进入应用内
    // 沉浸式阅读页，从而保证目录和上下滑翻页都基于我们提取出的真实阅读单元。
    final sectionId = saved?.sectionId ?? await _dao.getFirstSectionIdForDocument(document.id);
    if (sectionId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('这本书暂时没有可阅读内容，请删除后重新导入。')));
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConsciousChangeSectionDetailPage(
          sectionId: sectionId,
          initialScrollOffset: saved?.scrollOffset ?? 0,
          readerMode: true,
        ),
      ),
    );
    if (mounted) await _load(showLoading: false);
  }

  Future<void> _openEpubReader(CcLearningDocument document, {String initialCfi = ''}) async {
    final path = document.sourcePath.trim();
    if (path.isEmpty || !await File(path).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到原始 EPUB 文件。请删除这条记录后重新导入该电子书。')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConsciousChangeEpubReaderPage(
          document: document,
          initialCfi: initialCfi,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openBookChapter(CcLearningChapter chapter) async {
    CcLearningDocument? document;
    for (final item in _documents) {
      if (item.id == chapter.documentId) {
        document = item;
        break;
      }
    }
    // EPUB 书籍章节也直接打开应用内阅读单元，不再跳回 epub_view。
    final sectionId = await _dao.getFirstSectionIdForChapter(chapter.id);
    if (sectionId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('该章节暂无可阅读内容')));
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ConsciousChangeSectionDetailPage(sectionId: sectionId, readerMode: true)),
    );
    if (mounted) await _load();
  }

  Future<void> _openChapter(int chapterId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ConsciousChangeChapterSectionsPage(chapterId: chapterId)),
    );
    if (mounted) await _load();
  }

  Future<void> _openSearchHit(CcSearchHit hit) async {
    if (hit.sectionId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConsciousChangeSectionDetailPage(
            sectionId: hit.sectionId!,
            initialQuery: hit.query,
            readerMode: _libraryMode == _CcLibraryMode.books,
          ),
        ),
      );
      if (mounted) await _load();
    } else {
      await _openChapter(hit.chapterId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 104),
                      children: [
                        _buildSearchField(),
                        if (_searchController.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildSearchResults(),
                        ],
                        const SizedBox(height: 18),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _cleanError(_error!),
                            style: const TextStyle(color: Color(0xFFB91C1C), height: 1.45),
                          ),
                        ],
                        const SizedBox(height: 22),
                        _buildCourseHeader(),
                        const SizedBox(height: 8),
                        _buildCourseList(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestReadingFab(CcReadingPosition position) {
    return Positioned(
      right: 18,
      bottom: 22 + MediaQuery.of(context).padding.bottom,
      child: SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _continueReading(position),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF4F46E5), size: 28),
                  const SizedBox(width: 5),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 170),
                    child: Text(
                      '继续：${position.sectionTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w900, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildCoreIdea() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('核心思想', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF374151))),
        SizedBox(height: 7),
        Text(
          consciousChangeCoreIdea,
          style: TextStyle(color: Color(0xFF6B7280), height: 1.62, fontSize: 14.5),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('搜索中…', style: TextStyle(color: Color(0xFF6B7280))),
      );
    }
    if (_searchHits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('暂未找到匹配内容', style: TextStyle(color: Color(0xFF6B7280))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final hit in _searchHits.take(12)) _buildSearchHit(hit),
      ],
    );
  }

  Widget _buildSearchHit(CcSearchHit hit) {
    return InkWell(
      onTap: () => _openSearchHit(hit),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hit.sectionTitle.isEmpty ? hit.chapterTitle : hit.sectionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 5),
            RichText(
              text: buildHighlightSpan(
                hit.sentence,
                hit.query,
                const TextStyle(color: Color(0xFF4B5563), height: 1.45, fontSize: 14),
                const TextStyle(color: Color(0xFF111827), backgroundColor: Color(0xFFFFF3A3), fontWeight: FontWeight.w900),
                fallbackHighlight: hit.sentence,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseHeader() {
    final isBooks = _libraryMode == _CcLibraryMode.books;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildModeSwitch()),
            Text('${_documents.length} 个', style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(width: 4),
            IconButton(
              tooltip: isBooks ? '清空全部书籍' : '清空全部课程',
              onPressed: _documents.isEmpty || _importing ? null : _clearAllCourses,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
            if (isBooks)
              IconButton(
                tooltip: '在线检索下载电子书',
                onPressed: _importing ? null : _openRemoteEbookDownload,
                icon: const Icon(Icons.cloud_download_outlined),
              ),
            IconButton(
              tooltip: isBooks ? '批量导入电子书' : '批量导入课程',
              onPressed: _importing ? null : _importLearningFile,
              icon: _importing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(isBooks ? Icons.library_add_outlined : Icons.upload_file_outlined),
            ),
          ],
        ),
        if (isBooks) ...[
          const SizedBox(height: 6),
          const Text(
            '电子书按导入文件独立保存上次阅读位置；点击书籍标题或播放按钮会从该书上次位置继续阅读。',
            style: TextStyle(color: Color(0xFF6B7280), height: 1.45, fontSize: 12.5),
          ),
        ],
      ],
    );
  }

  Widget _buildModeSwitch() {
    Widget item(_CcLibraryMode mode) {
      final active = _libraryMode == mode;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: active
              ? null
              : () async {
                  setState(() {
                    _libraryMode = mode;
                    _documents = const <CcLearningDocument>[];
                    _chaptersByDocument = <int, List<CcLearningChapter>>{};
                    _readingPositionsByDocument = const <int, CcReadingPosition>{};
                    _expandedDocumentIds.clear();
                    _searchController.clear();
                    _searchHits = const <CcSearchHit>[];
                  });
                  await _load(showLoading: false);
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF111827) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              mode.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: active ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 270),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [item(_CcLibraryMode.courses), item(_CcLibraryMode.books)],
      ),
    );
  }


  void _toggleDocumentExpanded(int documentId, bool expanded) {
    setState(() {
      if (expanded) {
        _expandedDocumentIds.remove(documentId);
      } else {
        _expandedDocumentIds.add(documentId);
      }
    });
  }

  String _documentSubtitle(CcLearningDocument doc, int chapterCount) {
    if (_libraryMode == _CcLibraryMode.books) {
      final ext = doc.fileExt.trim().isEmpty ? 'BOOK' : doc.fileExt.toUpperCase();
      final source = doc.importOrigin == 'remote' && doc.remoteSourceName.trim().isNotEmpty
          ? '远程下载 · ${doc.remoteSourceName}'
          : '本地导入';
      final saved = doc.downloadsPath.trim().isNotEmpty ? ' · 已保存到下载目录' : '';
      return '$source · $ext · ${doc.fileName}$saved';
    }
    return '$chapterCount 章 · ${doc.fileName}';
  }

  Widget _buildDocumentReadingPosition(CcReadingPosition position) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 2, 6, 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _continueReading(position),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              const Icon(Icons.play_circle_fill_rounded, size: 22, color: Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('上次阅读位置', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      position.sectionTitle.isEmpty ? position.chapterTitle : position.sectionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, color: Color(0xFF111827), fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseList() {
    if (_documents.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          _libraryMode == _CcLibraryMode.books
              ? '还没有导入书籍。点击右上角书籍导入图标，可批量导入 EPUB、TXT、HTML、FB2、PDF 等电子书；书籍会单独进入阅读书籍模块。'
              : '还没有导入课程。点击右上角导入图标，可批量导入 txt、md、docx 等课程文档。',
          style: const TextStyle(color: Color(0xFF6B7280), height: 1.5),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: _documents.length,
        onReorder: _reorderDocuments,
        proxyDecorator: (child, index, animation) => Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8))],
            ),
            child: child,
          ),
        ),
        itemBuilder: (context, index) {
          final doc = _documents[index];
          return ReorderableDelayedDragStartListener(
            key: ValueKey('cc_doc_${doc.id}'),
            index: index,
            child: Column(
              children: [
                _buildDocument(doc, documentIndex: index),
                if (index != _documents.length - 1) const Divider(height: 1, indent: 14, endIndent: 14),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocument(CcLearningDocument doc, {required int documentIndex}) {
    final chapters = _chaptersByDocument[doc.id] ?? const <CcLearningChapter>[];
    final expanded = _expandedDocumentIds.contains(doc.id);
    final savedPosition = _readingPositionsByDocument[doc.id];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (_libraryMode == _CcLibraryMode.books) {
                _openBookDocument(doc);
              } else {
                _toggleDocumentExpanded(doc.id, expanded);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  InkResponse(
                    onTap: () => _toggleDocumentExpanded(doc.id, expanded),
                    radius: 22,
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(expanded ? Icons.expand_less : Icons.chevron_right, color: const Color(0xFF6B7280)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                        const SizedBox(height: 3),
                        Text(
                          _documentSubtitle(doc, chapters.length),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  if (_libraryMode == _CcLibraryMode.books)
                    IconButton(
                      tooltip: '开始/继续阅读',
                      onPressed: () => _openBookDocument(doc),
                      icon: const Icon(Icons.play_circle_outline, color: Color(0xFF4F46E5)),
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(Icons.drag_indicator, size: 22, color: Color(0xFF9CA3AF)),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'delete') _deleteDocument(doc);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(_libraryMode == _CcLibraryMode.books ? '删除书籍' : '删除课程'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            if (_libraryMode == _CcLibraryMode.courses && savedPosition != null)
              _buildDocumentReadingPosition(savedPosition),
            if (_libraryMode == _CcLibraryMode.books && chapters.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(30, 8, 6, 10),
                child: Text('点击书籍标题会从该书上次位置继续阅读；点击左侧箭头可展开目录，点击目录项可跳转。', style: TextStyle(color: Color(0xFF6B7280))),
              )
            else if (chapters.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(30, 8, 6, 10),
                child: Text('未识别到章节目录。', style: TextStyle(color: Color(0xFF6B7280))),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: chapters.length,
                onReorder: (oldIndex, newIndex) => _reorderChaptersForDocument(doc, oldIndex, newIndex),
                proxyDecorator: (child, index, animation) => Material(
                  color: Colors.transparent,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 8))],
                    ),
                    child: child,
                  ),
                ),
                itemBuilder: (context, index) {
                  final chapter = chapters[index];
                  return InkWell(
                    key: ValueKey('cc_chapter_${chapter.id}'),
                    onTap: () => _libraryMode == _CcLibraryMode.books ? _openBookChapter(chapter) : _openChapter(chapter.id),
                    onLongPress: () => _showChapterActions(chapter),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(30, 10, 4, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              chapter.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, height: 1.35, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: Icon(Icons.drag_indicator, size: 22, color: Color(0xFF9CA3AF)),
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 22, color: Color(0xFF6B7280)),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }


}


class ConsciousChangeEpubReaderPage extends StatefulWidget {
  final CcLearningDocument document;
  final String initialCfi;

  const ConsciousChangeEpubReaderPage({
    super.key,
    required this.document,
    this.initialCfi = '',
  });

  @override
  State<ConsciousChangeEpubReaderPage> createState() => _ConsciousChangeEpubReaderPageState();
}

class _ConsciousChangeEpubReaderPageState extends State<ConsciousChangeEpubReaderPage> {
  final ConsciousChangeDao _dao = ConsciousChangeDao();
  late final epub.EpubController _controller;
  String? _error;
  Timer? _saveTimer;

  static const Color _readerBackground = Color(0xFF000000);
  static const Color _readerText = Color(0xFFF7F7F7);
  static const Color _readerSecondaryText = Color(0xFFBDBDBD);

  @override
  void initState() {
    super.initState();
    _enterTransparentSystemBars();
    final file = File(widget.document.sourcePath);
    _controller = epub.EpubController(
      document: epub.EpubDocument.openFile(file),
      epubCfi: widget.initialCfi.trim().isEmpty ? null : widget.initialCfi.trim(),
    );
    _saveTimer = Timer.periodic(const Duration(seconds: 8), (_) => _savePosition());
  }

  @override
  void dispose() {
    _savePosition();
    _saveTimer?.cancel();
    _controller.dispose();
    _restoreDefaultSystemBars();
    super.dispose();
  }

  void _enterTransparentSystemBars() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  void _restoreDefaultSystemBars() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  Future<void> _savePosition() async {
    try {
      final cfi = _controller.generateEpubCfi();
      await _dao.saveEpubReadingPosition(
        documentId: widget.document.id,
        epubCfi: cfi == null || cfi.trim().isEmpty ? widget.initialCfi : cfi.trim(),
      );
    } catch (_) {
      // 阅读器刚加载时可能尚未生成 CFI，忽略即可，退出或下次翻页时会再次保存。
    }
  }

  bool _looksLikeContentsTitle(String title) {
    final normalized = title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return false;
    return normalized == 'contents' ||
        normalized == 'table of contents' ||
        normalized.contains('table of contents') ||
        normalized.contains('目录') ||
        normalized.contains('目錄') ||
        normalized.contains('contents');
  }

  Future<void> _jumpToBookContentsPage() async {
    try {
      final toc = _controller.tableOfContents();
      var targetIndex = -1;
      for (var i = 0; i < toc.length; i++) {
        final dynamic item = toc[i];
        final title = ((item.title ?? '') as String).trim();
        if (_looksLikeContentsTitle(title)) {
          targetIndex = i;
          break;
        }
      }
      if (targetIndex >= 0) {
        final dynamic chapter = toc[targetIndex];
        await _controller.scrollTo(
          index: (chapter.startIndex as num).toInt(),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: 0,
        );
        await _savePosition();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有在 EPUB 目录中找到“目录页”，已打开目录导航。')),
      );
      _showTableOfContents();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目录页尚未加载完成，请稍后再试。')),
      );
    }
  }

  void _showTableOfContents() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Theme(
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF111111),
            colorScheme: const ColorScheme.dark(
              surface: Color(0xFF111111),
              primary: Colors.white,
            ),
            textTheme: ThemeData.dark().textTheme.apply(
                  bodyColor: _readerText,
                  displayColor: _readerText,
                ),
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.76,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 2, 20, 12),
                  child: Text(
                    '目录',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                Expanded(
                  child: epub.EpubViewTableOfContents(
                    controller: _controller,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
                    itemBuilder: (context, index, chapter, itemCount) {
                      final dynamic tocChapter = chapter;
                      final title = ((tocChapter.title ?? '') as String).replaceAll(RegExp(r'\s+'), ' ').trim();
                      final isContents = _looksLikeContentsTitle(title);
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                        leading: isContents
                            ? const Icon(Icons.toc, size: 18, color: Colors.white)
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(color: _readerSecondaryText, fontSize: 12),
                              ),
                        title: Text(
                          title.isEmpty ? '未命名章节' : title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isContents ? Colors.white : const Color(0xFFE8E8E8),
                            fontWeight: isContents ? FontWeight.w800 : FontWeight.w500,
                            height: 1.25,
                          ),
                        ),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await _controller.scrollTo(
                            index: (tocChapter.startIndex as num).toInt(),
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            alignment: 0,
                          );
                          await _savePosition();
                        },
                      );
                    },
                    loader: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  epub.EpubViewBuilders<epub.DefaultBuilderOptions> _readerBuilders() {
    return epub.EpubViewBuilders<epub.DefaultBuilderOptions>(
      options: const epub.DefaultBuilderOptions(
        chapterPadding: EdgeInsets.fromLTRB(24, 78, 24, 48),
        paragraphPadding: EdgeInsets.fromLTRB(18, 8, 18, 12),
        textStyle: TextStyle(
          color: _readerText,
          fontSize: 21,
          height: 1.62,
          letterSpacing: 0.15,
          fontFamily: 'QuoteSong',
        ),
      ),
      chapterDividerBuilder: (chapter) {
        final title = (chapter.Title ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
        if (title.isEmpty) return const SizedBox(height: 28);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 42, 24, 18),
          child: Text(
            title,
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              height: 1.25,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        );
      },
      loaderBuilder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
      errorBuilder: (context, error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '电子书打开失败：${_cleanError(error.toString())}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.55),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overlayStyle = SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    );
    final topInset = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: _readerBackground,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            Positioned.fill(
              child: _error == null
                  ? Theme(
                      data: ThemeData.dark().copyWith(
                        scaffoldBackgroundColor: _readerBackground,
                        canvasColor: _readerBackground,
                        colorScheme: const ColorScheme.dark(
                          surface: _readerBackground,
                          primary: Colors.white,
                        ),
                        textTheme: ThemeData.dark().textTheme.apply(
                              bodyColor: _readerText,
                              displayColor: _readerText,
                            ),
                      ),
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(
                          color: _readerText,
                          fontSize: 21,
                          height: 1.62,
                          letterSpacing: 0.15,
                          fontFamily: 'QuoteSong',
                        ),
                        child: ColorFiltered(
                          // 部分 EPUB 自带深色 CSS，epub_view 会尊重原书样式，导致黑底模式下文字变成深灰。
                          // 这里仅增强非透明像素亮度，黑底仍保持黑色，避免出现“黑字叠黑底”。
                          colorFilter: const ColorFilter.matrix(<double>[
                            3.2, 0, 0, 0, 0,
                            0, 3.2, 0, 0, 0,
                            0, 0, 3.2, 0, 0,
                            0, 0, 0, 1, 0,
                          ]),
                          child: epub.EpubView(
                            controller: _controller,
                            builders: _readerBuilders(),
                            onDocumentLoaded: (_) => _savePosition(),
                            onChapterChanged: (_) => _savePosition(),
                            onDocumentError: (error) {
                              if (!mounted) return;
                              setState(() {
                                _error = error.toString();
                              });
                            },
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '电子书打开失败：${_cleanError(_error!)}\n\n请确认导入的是标准 EPUB 文件；如果是旧记录，请删除后重新导入。',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, height: 1.55),
                        ),
                      ),
                    ),
            ),
            Positioned(
              left: 8,
              top: topInset + 6,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    tooltip: '返回',
                    icon: const Icon(Icons.arrow_back, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 8)]),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  IconButton(
                    tooltip: '目录导航',
                    icon: const Icon(Icons.menu_book_outlined, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 8)]),
                    onPressed: _showTableOfContents,
                  ),
                  IconButton(
                    tooltip: '回到目录页',
                    icon: const Icon(Icons.toc, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 8)]),
                    onPressed: _jumpToBookContentsPage,
                  ),
                  const Spacer(),
                  epub.EpubViewActualChapter(
                    controller: _controller,
                    loader: const SizedBox.shrink(),
                    builder: (chapterValue) {
                      final title = chapterValue?.chapter?.Title?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
                      if (title.isEmpty) return const SizedBox.shrink();
                      return ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.48),
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: _readerSecondaryText,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConsciousChangeChapterSectionsPage extends StatefulWidget {
  final int chapterId;

  const ConsciousChangeChapterSectionsPage({super.key, required this.chapterId});

  @override
  State<ConsciousChangeChapterSectionsPage> createState() => _ConsciousChangeChapterSectionsPageState();
}

class _ConsciousChangeChapterSectionsPageState extends State<ConsciousChangeChapterSectionsPage> {
  final ConsciousChangeDao _dao = ConsciousChangeDao();

  bool _loading = true;
  String? _error;
  CcChapterDetail? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await _dao.getChapterDetail(widget.chapterId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openSection(int sectionId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ConsciousChangeSectionDetailPage(sectionId: sectionId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('章节小节'),
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : detail == null
              ? Center(child: Text(_error == null ? '未找到章节内容' : '加载失败：${_cleanError(_error!)}'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                  children: [
                    Text(detail.chapter.documentTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(detail.chapter.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827), height: 1.25)),
                    const SizedBox(height: 24),
                    const Text('本章小节', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                    const SizedBox(height: 8),
                    if (detail.sections.isEmpty)
                      const Text('本章暂无小节。', style: TextStyle(color: Color(0xFF6B7280)))
                    else
                      for (final section in detail.sections)
                        InkWell(
                          onTap: () => _openSection(section.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(section.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.35, color: Color(0xFF111827))),
                                ),
                                const Icon(Icons.chevron_right, color: Color(0xFF6B7280)),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
    );
  }
}


typedef _EdgePageDragCanStart = bool Function(bool draggingUp, double totalDeltaY);
typedef _EdgePageDragStart = void Function(bool draggingUp, double globalDy);
typedef _EdgePageDragUpdate = void Function(double deltaY, double velocityY);
typedef _EdgePageDragEnd = void Function(double velocityY, bool cancelled);

class _EdgePageDragGestureRecognizer extends OneSequenceGestureRecognizer {
  _EdgePageDragGestureRecognizer({super.debugOwner});

  _EdgePageDragCanStart? canStart;
  _EdgePageDragStart? onStart;
  _EdgePageDragUpdate? onUpdate;
  _EdgePageDragEnd? onEnd;

  int? _pointer;
  Offset? _startPosition;
  bool _accepted = false;
  bool _rejected = false;
  VelocityTracker? _velocityTracker;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _startPosition = event.position;
    _accepted = false;
    _rejected = false;
    _velocityTracker = VelocityTracker.withKind(event.kind)..addPosition(event.timeStamp, event.position);
    startTrackingPointer(event.pointer, event.transform);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      _velocityTracker?.addPosition(event.timeStamp, event.position);
      final start = _startPosition;
      if (start == null || _rejected) return;
      final delta = event.position - start;
      final vertical = delta.dy.abs();
      final horizontal = delta.dx.abs();

      if (!_accepted) {
        // 关键点：在正文已经到顶部/底部且用户向外拖动时，必须在
        // ScrollView 之前抢下这个手势。否则内层正文会继续消费拖动，
        // 造成自动滚动、抖动、闪屏和回到初始位置。
        if (vertical < 6 || vertical < horizontal * 1.15) {
          if (horizontal > 12 && horizontal > vertical * 1.35) {
            _reject(event.pointer);
          }
          return;
        }
        final draggingUp = delta.dy < 0;
        if (canStart?.call(draggingUp, delta.dy) != true) {
          _reject(event.pointer);
          return;
        }
        _accepted = true;
        resolve(GestureDisposition.accepted);
        onStart?.call(draggingUp, start.dy);
      }

      final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0;
      onUpdate?.call(delta.dy, velocity);
      return;
    }

    if (event is PointerUpEvent) {
      final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0;
      if (_accepted) {
        onEnd?.call(velocity, false);
      } else {
        resolve(GestureDisposition.rejected);
      }
      stopTrackingPointer(event.pointer);
      _reset();
      return;
    }

    if (event is PointerCancelEvent) {
      if (_accepted) onEnd?.call(0, true);
      stopTrackingPointer(event.pointer);
      _reset();
    }
  }

  void _reject(int pointer) {
    _rejected = true;
    resolve(GestureDisposition.rejected);
    stopTrackingPointer(pointer);
    _reset();
  }

  @override
  void acceptGesture(int pointer) {
    _accepted = true;
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer == _pointer) {
      _rejected = true;
      stopTrackingPointer(pointer);
      _reset();
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'edgePageDrag';

  void _reset() {
    _pointer = null;
    _startPosition = null;
    _accepted = false;
    _rejected = false;
    _velocityTracker = null;
  }
}

enum _PageEdge { top, bottom }

class _ScrollBoundaryState {
  final bool canScroll;
  final bool isAtTop;
  final bool isAtBottom;

  const _ScrollBoundaryState({
    required this.canScroll,
    required this.isAtTop,
    required this.isAtBottom,
  });
}


class _ReaderScrollBehavior extends ScrollBehavior {
  const _ReaderScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

class ConsciousChangeSectionDetailPage extends StatefulWidget {
  final int sectionId;
  final String initialQuery;
  final double initialScrollOffset;
  final bool readerMode;

  const ConsciousChangeSectionDetailPage({
    super.key,
    required this.sectionId,
    this.initialQuery = '',
    this.initialScrollOffset = 0,
    this.readerMode = false,
  });

  @override
  State<ConsciousChangeSectionDetailPage> createState() => _ConsciousChangeSectionDetailPageState();
}

class _ConsciousChangeSectionDetailPageState extends State<ConsciousChangeSectionDetailPage> with SingleTickerProviderStateMixin {
  final ConsciousChangeDao _dao = ConsciousChangeDao();
  final Map<int, ScrollController> _scrollControllers = <int, ScrollController>{};
  final Map<int, double> _dragFrozenScrollOffsets = <int, double>{};
  final ValueNotifier<double> _dragOffsetListenable = ValueNotifier<double>(0);

  AnimationController? _pageTurnController;
  Offset? _tapDownPosition;
  Offset? _lastPointerPosition;
  Offset? _pageDragStartPosition;
  DateTime? _tapDownAt;
  DateTime? _lastPointerAt;
  bool _tapMoved = false;
  bool _gestureStartedAtTop = false;
  bool _gestureStartedAtBottom = false;
  bool _gestureContentScrollable = false;
  bool _ignoreNextQuickTap = false;
  bool _turningPage = false;
  bool _pageDragActive = false;
  bool _edgeDragInnerScrollLocked = false;
  bool _textSelecting = false;
  bool _pinningReaderScroll = false;
  double _dragOffsetY = 0;
  double _dragVelocityY = 0;
  int? _dragTargetPage;
  Timer? _boundaryTipTimer;
  Timer? _saveReadingDebounce;
  Timer? _postDragPinTimer;
  int? _postDragPinPageIndex;
  double? _postDragPinOffset;

  bool _loading = true;
  bool _showKeywords = false;
  String? _error;
  String _highlightQuery = '';
  String _highlightSentence = '';
  int? _highlightPageIndex;
  String _boundaryTip = '';
  CcSectionDetail? _detail;
  List<CcLearningSection> _sections = const <CcLearningSection>[];
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _enterReadingSystemBars();
    _pageTurnController = AnimationController(vsync: this);
    _highlightQuery = widget.initialQuery.trim();
    _load();
  }

  @override
  void dispose() {
    _saveCurrentReadingPositionNow();
    _restoreLearningSystemBars();
    _pageTurnController?.dispose();
    _dragOffsetListenable.dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    _boundaryTipTimer?.cancel();
    _saveReadingDebounce?.cancel();
    _postDragPinTimer?.cancel();
    super.dispose();
  }

  void _enterReadingSystemBars() {
    final lightIcons = widget.readerMode;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle((lightIcons ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: lightIcons ? Brightness.light : Brightness.dark,
      systemNavigationBarIconBrightness: lightIcons ? Brightness.light : Brightness.dark,
    ));
  }

  void _restoreLearningSystemBars() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  Future<void> _load() async {
    try {
      final detail = await _dao.getSectionDetail(widget.sectionId);
      if (!mounted) return;
      final sections = detail?.chapterSections.isNotEmpty == true
          ? detail!.chapterSections
          : detail == null
              ? const <CcLearningSection>[]
              : <CcLearningSection>[detail.section];
      final initialIndex = detail == null ? 0 : detail.currentIndex.clamp(0, sections.isEmpty ? 0 : sections.length - 1).toInt();
      setState(() {
        _detail = detail;
        _sections = sections;
        _currentPage = initialIndex;
        _highlightPageIndex = _highlightQuery.isEmpty ? null : initialIndex;
        _loading = false;
      });
      if (_highlightQuery.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _activateHighlight(_highlightQuery, pageIndex: initialIndex));
      } else if (widget.initialScrollOffset > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToInitialReadingOffset(initialIndex));
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSaveReadingPosition(initialIndex, 0));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  ScrollController _scrollControllerFor(int pageIndex) {
    return _scrollControllers.putIfAbsent(pageIndex, () => ScrollController());
  }


  void _jumpToInitialReadingOffset(int pageIndex) {
    if (!mounted || pageIndex < 0 || pageIndex >= _sections.length) return;
    final controller = _scrollControllerFor(pageIndex);
    if (!controller.hasClients) return;
    final position = controller.position;
    final target = widget.initialScrollOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    controller.jumpTo(target);
    _scheduleSaveReadingPosition(pageIndex, target);
  }

  void _scheduleSaveReadingPosition(int pageIndex, double offset) {
    if (pageIndex < 0 || pageIndex >= _sections.length) return;
    final sectionId = _sections[pageIndex].id;
    final safeOffset = offset.isFinite ? offset.clamp(0.0, double.infinity).toDouble() : 0.0;
    _saveReadingDebounce?.cancel();
    _saveReadingDebounce = Timer(const Duration(milliseconds: 420), () {
      _dao.saveReadingPosition(sectionId: sectionId, scrollOffset: safeOffset);
    });
  }

  void _saveCurrentReadingPositionNow() {
    if (_sections.isEmpty || _currentPage < 0 || _currentPage >= _sections.length) return;
    final controller = _scrollControllers[_currentPage];
    final offset = controller != null && controller.hasClients ? controller.position.pixels : 0.0;
    _dao.saveReadingPosition(sectionId: _sections[_currentPage].id, scrollOffset: offset);
  }

  // 阅读正文滚动位置只能由用户正常滚动或关键词/搜索定位改变。
  // 之前在边界翻页期间通过 jumpTo 反复锁定 ScrollController，
  // 会造成用户松手后正文自动滚动、闪屏或像页面刷新。
  // 现在翻页只移动外层整页，正文内部不再在拖拽期间被程序反复改动。
  void _handleReaderScrollChanged(int pageIndex, ScrollController controller) {}

  void _startPostDragScrollPin(int pageIndex, double offset) {}

  CcLearningSection? get _currentSection {
    if (_sections.isEmpty || _currentPage < 0 || _currentPage >= _sections.length) return null;
    return _sections[_currentPage];
  }

  void _activateHighlight(String query, {int? pageIndex}) {
    final value = query.trim();
    final targetPage = pageIndex ?? _currentPage;
    if (value.isEmpty || targetPage < 0 || targetPage >= _sections.length) return;
    final section = _sections[targetPage];
    final content = _displayCourseContent(section.content);
    final match = _findBestReadableBlock(content, value);
    setState(() {
      _highlightQuery = value;
      _highlightSentence = match?.text ?? '';
      _highlightPageIndex = targetPage;
      _showKeywords = false;
    });
    if (match != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMatchedText(targetPage, content, match.text));
    }
  }

  void _clearHighlight() {
    if (_highlightQuery.isEmpty && _highlightSentence.isEmpty && _highlightPageIndex == null) return;
    setState(() {
      _highlightQuery = '';
      _highlightSentence = '';
      _highlightPageIndex = null;
    });
  }

  void _handleTextSelectionChanged(TextSelection selection, SelectionChangedCause? cause) {
    _textSelecting = !selection.isCollapsed;
  }

  void _setDragOffset(double value) {
    final normalized = value.abs() <= 0.5 ? 0.0 : value;
    _dragOffsetY = normalized;
    if ((_dragOffsetListenable.value - normalized).abs() > 0.1) {
      _dragOffsetListenable.value = normalized;
    } else if (normalized == 0 && _dragOffsetListenable.value != 0) {
      _dragOffsetListenable.value = 0;
    }
  }


  bool _canStartEdgePageDrag(bool draggingUp, double totalDeltaY) {
    if (_turningPage || _textSelecting || _sections.isEmpty) return false;
    final controller = _scrollControllers[_currentPage];
    if (controller == null || !controller.hasClients) return true;

    final position = controller.position;
    final canScroll = position.maxScrollExtent > position.minScrollExtent + 2;
    if (!canScroll) return true;

    // 解决“到页面底部后偶尔滑动没反应”的根因：
    // 用户刚滚到边界附近时，ScrollView 的像素位置可能还差十几到几十像素
    // 才等于 maxScrollExtent/minScrollExtent。旧逻辑在第一次 move 时判定
    // “还没到底”就直接 reject，之后即使本次手势继续把正文滚到底，外层
    // 翻页识别器也已经退出，所以必须反复重试。
    // 这里允许“已经很靠近边界，且本次拖动方向继续指向边界”的手势直接
    // 由外层翻页接管；接管后只移动整页，不再改正文 scroll offset。
    final viewport = position.viewportDimension <= 0 ? MediaQuery.of(context).size.height : position.viewportDimension;
    final tolerance = (viewport * 0.075).clamp(42.0, 86.0).toDouble();
    final dragDistance = totalDeltaY.abs();
    if (draggingUp) {
      final distanceToBottom = (position.maxScrollExtent - position.pixels).clamp(0.0, double.infinity).toDouble();
      return distanceToBottom <= tolerance + dragDistance;
    }
    final distanceToTop = (position.pixels - position.minScrollExtent).clamp(0.0, double.infinity).toDouble();
    return distanceToTop <= tolerance + dragDistance;
  }

  void _beginEdgePageDrag(bool draggingUp, double globalDy) {
    if (_turningPage) return;
    _postDragPinTimer?.cancel();
    _postDragPinPageIndex = null;
    _postDragPinOffset = null;
    _tapMoved = true;
    _pageDragActive = true;
    _edgeDragInnerScrollLocked = true;
    _dragVelocityY = 0;
    _dragTargetPage = null;
    _pageDragStartPosition = Offset(0, globalDy);
    _dragFrozenScrollOffsets.clear();
    _freezeCurrentReaderAtBoundary(draggingUp ? _PageEdge.bottom : _PageEdge.top);
    _setDragOffset(0);
  }

  void _updateEdgePageDrag(double deltaY, double velocityY) {
    if (!_pageDragActive || _turningPage) return;
    _dragVelocityY = velocityY;
    final screenHeight = MediaQuery.of(context).size.height;
    final target = _targetPageForDrag(deltaY);
    final atBoundary = target == null;
    final clampedOffset = deltaY.clamp(-screenHeight, screenHeight).toDouble();
    final nextOffset = atBoundary ? clampedOffset * 0.28 : clampedOffset;
    final normalizedOffset = nextOffset.abs() <= 0.5 ? 0.0 : nextOffset;
    _dragTargetPage = normalizedOffset == 0 ? null : target;
    _setDragOffset(normalizedOffset);
  }

  void _endEdgePageDrag(double velocityY, bool cancelled) {
    if (!_pageDragActive && _dragOffsetY.abs() <= 0.5) return;
    _dragVelocityY = velocityY;
    _finishPageDrag(cancelled: cancelled);
  }

  void _showReaderDirectory() {
    if (!widget.readerMode || _sections.isEmpty) return;
    _ignorePageTapOnce();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 2, 20, 12),
                child: Text('目录', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                  itemCount: _sections.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF242424)),
                  itemBuilder: (context, index) {
                    final section = _sections[index];
                    final selected = index == _currentPage;
                    return ListTile(
                      dense: true,
                      leading: Text('${index + 1}', style: TextStyle(color: selected ? Colors.white : const Color(0xFF9CA3AF), fontWeight: selected ? FontWeight.w900 : FontWeight.w500)),
                      title: Text(
                        section.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: selected ? Colors.white : const Color(0xFFE5E7EB), fontWeight: selected ? FontWeight.w900 : FontWeight.w600, height: 1.25),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _currentPage = index;
                          _showKeywords = false;
                          _highlightQuery = '';
                          _highlightSentence = '';
                          _highlightPageIndex = null;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final controller = _scrollControllers[index];
                          if (controller != null && controller.hasClients) controller.jumpTo(0);
                          _scheduleSaveReadingPosition(index, 0);
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleReaderPageTap() {
    if (_ignoreNextQuickTap) {
      _ignoreNextQuickTap = false;
      return;
    }
    if (_highlightQuery.isNotEmpty || _highlightSentence.isNotEmpty || _highlightPageIndex != null) {
      _clearHighlight();
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    _postDragPinTimer?.cancel();
    _postDragPinPageIndex = null;
    _postDragPinOffset = null;
    _tapDownPosition = event.position;
    _lastPointerPosition = event.position;
    _pageDragStartPosition = null;
    _tapDownAt = DateTime.now();
    _lastPointerAt = _tapDownAt;
    _tapMoved = false;
    _dragVelocityY = 0;
    if (_dragOffsetY.abs() <= 0.5 && !_pageDragActive) {
      _dragFrozenScrollOffsets.clear();
    }

    final currentScroll = _scrollControllers[_currentPage];
    if (currentScroll != null && currentScroll.hasClients) {
      final position = currentScroll.position;
      _gestureContentScrollable = position.maxScrollExtent > position.minScrollExtent + 2;
      _gestureStartedAtTop = position.pixels <= position.minScrollExtent + 8;
      _gestureStartedAtBottom = position.pixels >= position.maxScrollExtent - 8;
    } else {
      _gestureContentScrollable = false;
      _gestureStartedAtTop = true;
      _gestureStartedAtBottom = true;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_ignoreNextQuickTap || _turningPage || _textSelecting) return;
    final start = _tapDownPosition;
    final startedAt = _tapDownAt;
    if (start == null || startedAt == null) return;

    final now = DateTime.now();
    final elapsedMs = now.difference(startedAt).inMilliseconds;
    // 长按后更可能是文字选择，不抢手势。
    // 但如果页面已经停留在一次未完成翻页的半页位置，用户再次按住继续
    // 拖动时必须继续跟手，不能因为超过长按时间而忽略。
    if (!_pageDragActive && _dragOffsetY.abs() <= 0.5 && elapsedMs > 420) return;
    final deltaFromStart = event.position - start;
    final vertical = deltaFromStart.dy.abs();
    final horizontal = deltaFromStart.dx.abs();
    if (deltaFromStart.distance > 9) _tapMoved = true;
    var activatedPageDragThisMove = false;

    final previousPosition = _lastPointerPosition;
    final previousAt = _lastPointerAt;
    final instantVelocity = previousPosition != null && previousAt != null
        ? (event.position.dy - previousPosition.dy) /
            now.difference(previousAt).inMilliseconds.clamp(1, 1000) *
            1000
        : 0.0;
    _lastPointerPosition = event.position;
    _lastPointerAt = now;

    if (!_pageDragActive) {
      // 越接近短视频翻页，越需要在边缘处尽早跟手移动。
      final movingVertically = vertical >= 4 && vertical >= horizontal * 1.05;
      if (!movingVertically) return;

      final draggingUp = deltaFromStart.dy < 0;
      final draggingDown = deltaFromStart.dy > 0;
      final boundary = _currentScrollBoundaryState();
      final contentCanScroll = boundary.canScroll || _gestureContentScrollable;
      final canDragToNext = draggingUp && (!contentCanScroll || boundary.isAtBottom);
      final canDragToPrevious = draggingDown && (!contentCanScroll || boundary.isAtTop);

      // 长内容优先让正文滚动。只有正文已经到达顶部/底部后，才接管为外层整页翻页。
      // 接管后正文不再被程序 jumpTo，也不会重建；用户看到的正文画面保持不变。
      if (!canDragToNext && !canDragToPrevious) return;

      final startedAtBoundary = !contentCanScroll ||
          (draggingUp && _gestureStartedAtBottom) ||
          (draggingDown && _gestureStartedAtTop);
      _pageDragActive = true;
      _edgeDragInnerScrollLocked = true;
      activatedPageDragThisMove = true;
      _pageDragStartPosition = startedAtBoundary ? start : event.position;
      _setDragOffset(0);
      _dragVelocityY = 0;
      _dragFrozenScrollOffsets.clear();
      _freezeCurrentReaderAtBoundary(draggingUp ? _PageEdge.bottom : _PageEdge.top);
    } else {
      // 平滑瞬时速度，避免极短时间内的抖动被误判为快速翻页。
      _dragVelocityY = _dragVelocityY == 0
          ? instantVelocity
          : _dragVelocityY * 0.58 + instantVelocity * 0.42;
    }

    if (activatedPageDragThisMove) {
      _dragVelocityY = instantVelocity;
    }

    final pageStart = _pageDragStartPosition ?? start;
    final rawOffset = event.position.dy - pageStart.dy;
    if (rawOffset.abs() < 0.5) return;
    final screenHeight = MediaQuery.of(context).size.height;
    if (_edgeDragInnerScrollLocked) {
      _freezeCurrentReaderAtBoundary(rawOffset < 0 ? _PageEdge.bottom : _PageEdge.top);
    }
    final target = _targetPageForDrag(rawOffset);
    final atBoundary = target == null;
    final clampedOffset = rawOffset.clamp(-screenHeight, screenHeight).toDouble();
    final nextOffset = atBoundary ? clampedOffset * 0.28 : clampedOffset;
    final normalizedOffset = nextOffset.abs() <= 0.5 ? 0.0 : nextOffset;
    final normalizedTarget = normalizedOffset == 0 ? null : target;
    _dragTargetPage = normalizedTarget;
    _setDragOffset(normalizedOffset);
    if (normalizedOffset != 0) {
      _rememberFrozenScrollOffsetsForDrag(normalizedOffset, normalizedTarget);
    }
    // 拖动过程中不 setState。上一页/当前页/下一页已经预加载，
    // 只更新外层位移，避免正文 SelectableText/ScrollView 被重建造成闪屏。
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_ignoreNextQuickTap) {
      _ignoreNextQuickTap = false;
      _resetPointerTracking();
      return;
    }
    if (_textSelecting) {
      _resetPointerTracking();
      return;
    }

    final start = _tapDownAt;
    final startPosition = _tapDownPosition;
    if (_pageDragActive) {
      _finishPageDrag();
      _resetPointerTracking(keepDrag: true);
      return;
    }

    _resetPointerTracking();
    if (start == null || startPosition == null) return;

    final elapsedMs = DateTime.now().difference(start).inMilliseconds;
    final movedDistance = (event.position - startPosition).distance;
    if (_tapMoved || elapsedMs > 300 || movedDistance > 8) return;
    if (_highlightQuery.isNotEmpty || _highlightSentence.isNotEmpty || _highlightPageIndex != null) {
      _clearHighlight();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    // Android 在滚动边界或文本选择场景下可能触发 PointerCancel。
    // 对翻页而言，这等价于一次未完成的松手：页面回到当前小节，
    // 正文内部位置继续固定在触发翻页的顶部/底部。
    if (_pageDragActive) {
      _finishPageDrag(cancelled: true);
      _resetPointerTracking(keepDrag: true);
      return;
    }
    _resetPointerTracking();
  }

  void _resetPointerTracking({bool keepDrag = false}) {
    _tapDownAt = null;
    _tapDownPosition = null;
    _lastPointerAt = null;
    _lastPointerPosition = null;
    _tapMoved = false;
    if (!keepDrag) {
      _pageDragActive = false;
      _pageDragStartPosition = null;
      _gestureStartedAtTop = false;
      _gestureStartedAtBottom = false;
      _gestureContentScrollable = false;
      _dragTargetPage = null;
      _setDragOffset(0);
      _dragVelocityY = 0;
      _edgeDragInnerScrollLocked = false;
    }
  }


  double _edgeBoundaryTolerance(ScrollMetrics position) {
    final viewport = position.viewportDimension <= 0 ? MediaQuery.of(context).size.height : position.viewportDimension;
    return (viewport * 0.055).clamp(28.0, 58.0).toDouble();
  }

  _ScrollBoundaryState _currentScrollBoundaryState() {
    final controller = _scrollControllers[_currentPage];
    if (controller == null || !controller.hasClients) {
      return const _ScrollBoundaryState(canScroll: false, isAtTop: true, isAtBottom: true);
    }
    final position = controller.position;
    final canScroll = position.maxScrollExtent > position.minScrollExtent + 2;
    if (!canScroll) {
      return const _ScrollBoundaryState(canScroll: false, isAtTop: true, isAtBottom: true);
    }
    return _ScrollBoundaryState(
      canScroll: true,
      isAtTop: position.pixels <= position.minScrollExtent + _edgeBoundaryTolerance(position),
      isAtBottom: position.pixels >= position.maxScrollExtent - _edgeBoundaryTolerance(position),
    );
  }

  int? _targetPageForDrag(double offsetY) {
    if (offsetY < 0) {
      final target = _currentPage + 1;
      return target < _sections.length ? target : null;
    }
    if (offsetY > 0) {
      final target = _currentPage - 1;
      return target >= 0 ? target : null;
    }
    return null;
  }

  Future<void> _finishPageDrag({bool cancelled = false}) async {
    if (_turningPage) return;
    final screenHeight = MediaQuery.of(context).size.height;
    final targetPage = _dragTargetPage;
    final dragDistance = _dragOffsetY.abs();
    final dragSpeed = _dragVelocityY.abs();
    // v28：适当提高翻页灵敏度。仍需明确拖动或快速上滑，但阈值比 v27 更接近短视频翻页。
    final shouldCommit = !cancelled &&
        targetPage != null &&
        (dragDistance >= screenHeight * 0.30 ||
            (dragDistance >= screenHeight * 0.105 && dragSpeed >= 900));

    if (targetPage == null && _dragOffsetY.abs() > 34) {
      _showBoundaryMessage(_dragOffsetY > 0 ? '已经是本章第一节' : '已经是本章最后一节');
    }

    if (!shouldCommit) {
      // 与短视频翻页一致：未超过阈值时，只让外层整页回到当前页；
      // 不再额外 jumpTo 正文滚动位置，避免松手后出现类似“重新加载”的闪屏。
      await _animateDragTo(0, commitPage: null, durationMs: 120);
      return;
    }

    final exitOffset = targetPage > _currentPage ? -screenHeight : screenHeight;
    await _animateDragTo(exitOffset, commitPage: targetPage, durationMs: 185);
  }


  double _currentReaderOffset() {
    final controller = _scrollControllers[_currentPage];
    if (controller == null || !controller.hasClients) return 0;
    return controller.position.pixels.clamp(controller.position.minScrollExtent, controller.position.maxScrollExtent).toDouble();
  }

  void _freezeCurrentReaderAtBoundary(_PageEdge edge) {
    // 只记录进入外层翻页时当前正文的位置，不做 jumpTo。
    // 用户已在底部/顶部看到什么，就保持什么；翻页失败时也不改正文滚动位置。
    final controller = _scrollControllers[_currentPage];
    if (controller == null || !controller.hasClients) return;
    final position = controller.position;
    _dragFrozenScrollOffsets.putIfAbsent(
      _currentPage,
      () => position.pixels.clamp(position.minScrollExtent, position.maxScrollExtent).toDouble(),
    );
  }

  double _readerBoundaryOffsetForDrag(double dragOffsetY) {
    final controller = _scrollControllers[_currentPage];
    if (controller == null || !controller.hasClients) return 0;
    final position = controller.position;
    if (position.maxScrollExtent <= position.minScrollExtent + 2) return 0;
    return (dragOffsetY < 0 ? position.maxScrollExtent : position.minScrollExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
  }

  void _rememberFrozenScrollOffsetsForDrag(double dragOffsetY, int? targetPage) {
    if (dragOffsetY.abs() <= 0.5) return;
    _dragFrozenScrollOffsets[_currentPage] ??= _currentReaderOffset();
    if (targetPage != null && targetPage >= 0 && targetPage < _sections.length) {
      _dragFrozenScrollOffsets[targetPage] = 0;
    }
  }

  void _pinCurrentScrollForPageDrag(double dragOffsetY) {
    // 禁止在翻页拖动中通过 jumpTo 锁位置。
    // jumpTo 会和 ScrollView 手势/布局竞争，是正文抖动和闪屏的根源。
  }

  void _restoreCurrentScrollAfterFailedDrag(double restoreOffset) {
    // 翻页失败只回收外层页面位移，绝不恢复/修改正文 ScrollController。
  }

  Future<void> _animateDragTo(double targetOffset, {required int? commitPage, required int durationMs}) async {
    final controller = _pageTurnController;
    if (controller == null || !mounted) return;
    _turningPage = true;
    final begin = _dragOffsetY;
    final tween = Tween<double>(begin: begin, end: targetOffset).chain(CurveTween(curve: Curves.easeOutCubic));
    void listener() {
      if (!mounted) return;
      _setDragOffset(tween.evaluate(controller));
    }
    controller
      ..stop()
      ..duration = Duration(milliseconds: durationMs)
      ..reset()
      ..addListener(listener);
    await controller.forward();
    controller.removeListener(listener);
    if (!mounted) return;
    _setDragOffset(0);
    setState(() {
      if (commitPage != null) {
        _currentPage = commitPage;
        _showKeywords = false;
        _highlightQuery = '';
        _highlightSentence = '';
        _highlightPageIndex = null;
      }
      _dragVelocityY = 0;
      _dragTargetPage = null;
      _pageDragActive = false;
      _edgeDragInnerScrollLocked = false;
      _turningPage = false;
      _dragFrozenScrollOffsets.clear();
    });
    if (commitPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final sc = _scrollControllers[commitPage];
        if (sc != null && sc.hasClients) sc.jumpTo(0);
        _scheduleSaveReadingPosition(commitPage, 0);
      });
    }
  }

  bool _handleReaderScrollNotification(ScrollNotification notification, int pageIndex) {
    // 只记录阅读进度，不在滚动通知里 jumpTo、锁定或启动翻页。
    if (pageIndex == _currentPage && notification.metrics.axis == Axis.vertical) {
      _scheduleSaveReadingPosition(pageIndex, notification.metrics.pixels);
    }
    return false;
  }

  void _ignorePageTapOnce() {
    _ignoreNextQuickTap = true;
  }

  void _scrollToMatchedText(int pageIndex, String content, String matchedText) {
    final controller = _scrollControllerFor(pageIndex);
    if (!controller.hasClients || content.trim().isEmpty || matchedText.trim().isEmpty) return;
    var offset = content.indexOf(matchedText);
    if (offset < 0) {
      final normalizedMatch = _normalizeSemantic(matchedText);
      final blocks = _splitReadableBlocks(content);
      var cursor = 0;
      for (final block in blocks) {
        if (_normalizeSemantic(block) == normalizedMatch || _semanticSentenceScore(block, matchedText) >= 0.72) {
          offset = content.indexOf(block, cursor);
          break;
        }
        final next = content.indexOf(block, cursor);
        if (next >= 0) cursor = next + block.length;
      }
    }
    if (offset < 0) offset = 0;

    final section = pageIndex >= 0 && pageIndex < _sections.length ? _sections[pageIndex] : _currentSection;
    final viewportWidth = MediaQuery.of(context).size.width - 48;
    final topPadding = section == null ? MediaQuery.of(context).padding.top + 120 : _readerTopPadding(context, section);
    final prefix = content.substring(0, offset.clamp(0, content.length).toInt());
    final painter = TextPainter(
      text: TextSpan(text: prefix, style: _readerBaseTextStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: viewportWidth <= 0 ? 1 : viewportWidth);

    final position = controller.position;
    final targetLineTop = topPadding + painter.height;
    final target = (targetLineTop - position.viewportDimension * 0.46)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutCubic,
    );
  }

  void _showBoundaryMessage(String message) {
    if (_boundaryTip == message) return;
    _boundaryTipTimer?.cancel();
    setState(() { _boundaryTip = message; });
    _boundaryTipTimer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      setState(() { _boundaryTip = ''; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final overlayStyle = widget.readerMode
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarContrastEnforced: false,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarContrastEnforced: false,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarIconBrightness: Brightness.dark,
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: widget.readerMode ? Colors.black : const Color(0xFFF8FAFC),
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : detail == null || _sections.isEmpty
                ? Center(child: Text(_error == null ? '未找到小节内容' : '加载失败：${_cleanError(_error!)}'))
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: _handlePointerDown,
                          onPointerMove: _handlePointerMove,
                          onPointerUp: _handlePointerUp,
                          onPointerCancel: _handlePointerCancel,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: _handleReaderPageTap,
                            child: SizedBox.expand(child: _buildSwipePager()),
                          ),
                        ),
                      ),
                      _buildBoundaryTip(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSwipePager() {
    final screenHeight = MediaQuery.of(context).size.height;
    final current = _currentPage.clamp(0, _sections.length - 1).toInt();
    final previous = current > 0 ? current - 1 : null;
    final next = current + 1 < _sections.length ? current + 1 : null;

    // 参考短视频翻页：上一页/当前页/下一页始终预加载为独立整屏页面。
    // 拖动时只改变外层页面位置，正文 ScrollView 本身不重建、不跳动。
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
        if (previous != null)
          _buildAnimatedReaderPage(
            _sections[previous],
            previous,
            (offset) => -screenHeight + (offset > 0 ? offset : 0),
            isPreview: true,
          ),
        if (next != null)
          _buildAnimatedReaderPage(
            _sections[next],
            next,
            (offset) => screenHeight + (offset < 0 ? offset : 0),
            isPreview: true,
          ),
        _buildAnimatedReaderPage(
          _sections[current],
          current,
          (offset) => offset,
        ),
          _buildAnimatedTransitionSeam(),
        ],
      ),
    );
  }

  Widget _buildAnimatedReaderPage(
    CcLearningSection section,
    int pageIndex,
    double Function(double offset) topForOffset, {
    bool isPreview = false,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final pageChild = SizedBox(
      height: screenHeight,
      child: ClipRect(
        child: RepaintBoundary(
          child: ColoredBox(
            color: widget.readerMode ? Colors.black : const Color(0xFFF8FAFC),
            child: _buildReaderPage(
              section,
              pageIndex,
              isPreview: isPreview,
            ),
          ),
        ),
      ),
    );

    return ValueListenableBuilder<double>(
      valueListenable: _dragOffsetListenable,
      child: pageChild,
      builder: (context, offset, child) {
        return Positioned.fill(
          child: Transform.translate(
            offset: Offset(0, topForOffset(offset)),
            child: child!,
          ),
        );
      },
    );
  }

  Widget _buildAnimatedTransitionSeam() {
    final screenHeight = MediaQuery.of(context).size.height;
    return ValueListenableBuilder<double>(
      valueListenable: _dragOffsetListenable,
      builder: (context, offset, _) {
        if (offset.abs() <= 0.5) return const SizedBox.shrink();
        final seamTop = offset < 0 ? screenHeight + offset : offset;
        return Positioned(
          top: seamTop - 10,
          left: 0,
          right: 0,
          height: 20,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (widget.readerMode ? Colors.black : const Color(0xFFF8FAFC)).withOpacity(0.00),
                    (widget.readerMode ? Colors.black : const Color(0xFFF8FAFC)).withOpacity(0.96),
                    (widget.readerMode ? Colors.white : Colors.black).withOpacity(0.10),
                    (widget.readerMode ? Colors.black : const Color(0xFFF8FAFC)).withOpacity(0.96),
                    (widget.readerMode ? Colors.black : const Color(0xFFF8FAFC)).withOpacity(0.00),
                  ],
                  stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _readerTopPadding(BuildContext context, CcLearningSection section) {
    final topInset = MediaQuery.of(context).padding.top;
    final width = MediaQuery.of(context).size.width;
    final usableTitleWidth = (width - 74).clamp(180.0, 520.0).toDouble();
    final painter = TextPainter(
      text: TextSpan(
        text: section.title,
        style: const TextStyle(fontSize: 15.5, height: 1.32, fontWeight: FontWeight.w900),
      ),
      maxLines: 4,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: usableTitleWidth);
    // 让正文始终从悬浮标题区下方开始，避免标题与第一行正文重叠。
    return topInset + 52 + painter.height + 42;
  }

  double _readerBottomPadding(BuildContext context) {
    return MediaQuery.of(context).padding.bottom + 128;
  }

  TextStyle get _readerBaseTextStyle => TextStyle(
        color: widget.readerMode ? const Color(0xFFF8FAFC) : const Color(0xFF1F2937),
        height: widget.readerMode ? 1.68 : 2.08,
        fontSize: widget.readerMode ? 19.5 : 19,
        letterSpacing: widget.readerMode ? 0.1 : 0.2,
        fontFamily: widget.readerMode ? 'serif' : null,
      );

  TextStyle get _readerHighlightTextStyle => TextStyle(
        color: widget.readerMode ? Colors.black : const Color(0xFF111827),
        backgroundColor: const Color(0xFFFFF3A3),
        fontWeight: FontWeight.w900,
        height: widget.readerMode ? 1.68 : 2.08,
        fontSize: widget.readerMode ? 19.5 : 19,
        letterSpacing: widget.readerMode ? 0.1 : 0.2,
        fontFamily: widget.readerMode ? 'serif' : null,
      );

  Widget _buildReaderPage(
    CcLearningSection section,
    int pageIndex, {
    bool isPreview = false,
  }) {
    final displayContent = widget.readerMode ? section.content.trim() : _displayCourseContent(section.content);
    final active = _highlightPageIndex == pageIndex;
    final topPadding = _readerTopPadding(context, section);
    final bottomPadding = _readerBottomPadding(context);
    final baseStyle = _readerBaseTextStyle;
    final highlightStyle = _readerHighlightTextStyle;
    final hasHighlight = active && (_highlightQuery.trim().isNotEmpty || _highlightSentence.trim().isNotEmpty);

    final textWidget = hasHighlight
        ? SelectableText.rich(
            buildHighlightSpan(
              displayContent,
              _highlightQuery,
              baseStyle,
              highlightStyle,
              fallbackHighlight: _highlightSentence,
            ),
            textAlign: TextAlign.start,
            enableInteractiveSelection: !isPreview,
            selectionControls: materialTextSelectionControls,
            onSelectionChanged: _handleTextSelectionChanged,
            showCursor: false,
          )
        : SelectableText(
            displayContent,
            style: baseStyle,
            textAlign: TextAlign.start,
            enableInteractiveSelection: !isPreview,
            selectionControls: materialTextSelectionControls,
            onSelectionChanged: _handleTextSelectionChanged,
            showCursor: false,
          );

    // 正文始终走同一套 ScrollView + SelectableText 渲染路径。
    // 边界翻页时不替换正文、不 jumpTo、不重建当前页内容；
    // 拖动和回弹只作用在外层整页位移上，正文保持用户当时看到的画面。
    return Container(
      color: widget.readerMode ? Colors.black : const Color(0xFFF8FAFC),
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: isPreview ? (_) => true : (notification) => _handleReaderScrollNotification(notification, pageIndex),
            child: AbsorbPointer(
              absorbing: isPreview,
              child: ScrollConfiguration(
                behavior: const _ReaderScrollBehavior(),
                child: SingleChildScrollView(
                  key: ValueKey(isPreview ? 'cc_preview_$pageIndex' : 'cc_reader_$pageIndex'),
                  primary: false,
                  controller: isPreview ? null : _scrollControllerFor(pageIndex),
                  physics: isPreview
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(24, topPadding, 24, bottomPadding),
                  child: textWidget,
                ),
              ),
            ),
          ),
          _buildTopFloatingBarForSection(section, pageIndex),
        ],
      ),
    );
  }

  Widget _buildTopFloatingBarForSection(CcLearningSection section, int pageIndex) {
    final keywords = section.keywords.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final isCurrentPage = pageIndex == _currentPage;
    return Positioned(
      top: 0,
      left: 8,
      right: 8,
      child: SafeArea(
        bottom: false,
        child: IgnorePointer(
          ignoring: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.readerMode)
                    _floatingIconButton(
                      tooltip: '目录',
                      icon: Icons.menu_book_outlined,
                      onTap: isCurrentPage ? _showReaderDirectory : null,
                    )
                  else
                    _floatingIconButton(
                      tooltip: isCurrentPage && _showKeywords ? '隐藏关键字' : '显示关键字',
                      icon: isCurrentPage && _showKeywords ? Icons.visibility_off_outlined : Icons.sell_outlined,
                      onTap: (!isCurrentPage || keywords.isEmpty)
                          ? null
                          : () {
                              _ignorePageTapOnce();
                              setState(() { _showKeywords = !_showKeywords; });
                            },
                    ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Text(
                        section.title,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 15.5,
                          height: 1.32,
                          color: widget.readerMode ? const Color(0xFFF8FAFC) : const Color(0xFF111827),
                          fontWeight: FontWeight.w900,
                          shadows: widget.readerMode
                              ? const [Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 0))]
                              : const [
                                  Shadow(color: Colors.white, blurRadius: 8, offset: Offset(0, 0)),
                                  Shadow(color: Colors.white, blurRadius: 10, offset: Offset(0, 0)),
                                ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (isCurrentPage && _showKeywords && keywords.isNotEmpty) ...[
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.32),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(left: 44, right: 6, bottom: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final keyword in keywords)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (_) => _ignorePageTapOnce(),
                            onTap: () => _activateHighlight(keyword, pageIndex: pageIndex),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xEEF3F4FF),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: const Color(0xFFD8DDFC)),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2)),
                                ],
                              ),
                              child: Text(
                                keyword,
                                style: const TextStyle(
                                  color: Color(0xFF4F46E5),
                                  fontSize: 14.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _floatingIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 42, height: 42),
      splashRadius: 22,
      onPressed: onTap == null
          ? null
          : () {
              _ignorePageTapOnce();
              onTap();
            },
      icon: Icon(
        icon,
        size: 22,
        color: onTap == null
            ? const Color(0xFF9CA3AF)
            : (widget.readerMode ? const Color(0xFFF8FAFC) : const Color(0xFF111827)),
        shadows: widget.readerMode
            ? const [Shadow(color: Colors.black, blurRadius: 9, offset: Offset(0, 0))]
            : const [
                Shadow(color: Colors.white, blurRadius: 9, offset: Offset(0, 0)),
                Shadow(color: Colors.white, blurRadius: 10, offset: Offset(0, 0)),
              ],
      ),
    );
  }

  Widget _buildBoundaryTip() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _boundaryTip.isEmpty ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.72),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                _boundaryTip,
                style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


String _displayCourseContent(String content) {
  final normalized = content
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  if (normalized.isEmpty) return '';
  final lines = normalized.split('\n');
  final originalIndex = lines.indexWhere((line) => RegExp(r'原文\s*直译\s*内容').hasMatch(line.trim()));
  if (originalIndex >= 0) {
    return lines.sublist(originalIndex + 1).join('\n').trim();
  }

  final result = <String>[];
  var skippingKeywords = false;
  for (final line in lines) {
    final trimmed = line.trim();
    final isKeywordLine = RegExp(r'(关键词|关键字|关联字|核心词|Keywords?)', caseSensitive: false).hasMatch(trimmed);
    if (isKeywordLine) {
      skippingKeywords = true;
      continue;
    }
    if (skippingKeywords) {
      if (trimmed.isEmpty) {
        skippingKeywords = false;
      }
      continue;
    }
    result.add(line);
  }
  return result.join('\n').trim();
}

TextSpan buildHighlightSpan(
  String text,
  String query,
  TextStyle baseStyle,
  TextStyle highlightStyle, {
  String fallbackHighlight = '',
}) {
  if (text.isEmpty) return TextSpan(text: text, style: baseStyle);
  final q = query.trim();
  if (q.isNotEmpty) {
    final exact = _highlightExact(text, q, baseStyle, highlightStyle);
    if (exact != null) return exact;
  }

  final fallback = fallbackHighlight.trim();
  if (fallback.isNotEmpty) {
    final fallbackExact = _highlightExact(text, fallback, baseStyle, highlightStyle);
    if (fallbackExact != null) return fallbackExact;
    if (_normalizeSemantic(text) == _normalizeSemantic(fallback)) {
      return TextSpan(text: text, style: highlightStyle);
    }
  }

  if (q.isNotEmpty && _semanticSentenceScore(text, q) >= 0.72) {
    return TextSpan(text: text, style: highlightStyle);
  }
  return TextSpan(text: text, style: baseStyle);
}

TextSpan? _highlightExact(String text, String query, TextStyle baseStyle, TextStyle highlightStyle) {
  final q = query.trim();
  if (q.isEmpty) return null;
  final lowerText = text.toLowerCase();
  final lowerQuery = q.toLowerCase();
  if (!lowerText.contains(lowerQuery)) return null;
  final children = <TextSpan>[];
  var start = 0;
  while (start < text.length) {
    final index = lowerText.indexOf(lowerQuery, start);
    if (index < 0) {
      children.add(TextSpan(text: text.substring(start), style: baseStyle));
      break;
    }
    if (index > start) {
      children.add(TextSpan(text: text.substring(start, index), style: baseStyle));
    }
    children.add(TextSpan(text: text.substring(index, index + q.length), style: highlightStyle));
    start = index + q.length;
  }
  return TextSpan(children: children, style: baseStyle);
}

class _ReadableBlockMatch {
  final int index;
  final String text;
  final double score;

  const _ReadableBlockMatch({required this.index, required this.text, required this.score});
}

_ReadableBlockMatch? _findBestReadableBlock(String content, String query) {
  final value = query.trim();
  if (content.trim().isEmpty || value.isEmpty) return null;
  final blocks = _splitReadableBlocks(content);
  for (var i = 0; i < blocks.length; i++) {
    if (_containsIgnoreCase(blocks[i], value)) {
      return _ReadableBlockMatch(index: i, text: blocks[i], score: 1);
    }
  }

  _ReadableBlockMatch? best;
  for (var i = 0; i < blocks.length; i++) {
    final score = _semanticSentenceScore(blocks[i], value);
    if (score < 0.72) continue;
    if (best == null || score > best.score) {
      best = _ReadableBlockMatch(index: i, text: blocks[i], score: score);
    }
  }
  return best;
}

double _semanticSentenceScore(String sentence, String query) {
  final s = _normalizeSemantic(sentence);
  final q = _normalizeSemantic(query);
  if (s.isEmpty || q.isEmpty) return 0;
  if (s.contains(q)) return 1;

  var queryIndex = 0;
  for (var i = 0; i < s.length && queryIndex < q.length; i++) {
    if (s[i] == q[queryIndex]) queryIndex++;
  }
  final orderedCoverage = queryIndex / q.length;

  final bigrams = <String>[];
  for (var i = 0; i < q.length - 1; i++) {
    bigrams.add(q.substring(i, i + 2));
  }
  final phraseCoverage = bigrams.isEmpty
      ? 0.0
      : bigrams.where((pair) => s.contains(pair)).length / bigrams.length;

  final chars = q.split('').toSet();
  final charCoverage = chars.isEmpty ? 0.0 : chars.where((ch) => s.contains(ch)).length / chars.length;
  return orderedCoverage * 0.55 + phraseCoverage * 0.35 + charCoverage * 0.10;
}

String _normalizeSemantic(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\t\n\r，。！？!?；;：:、,.（）()\[\]【】「」“”‘’"\-—_]+'), '')
      .trim();
}

List<String> _splitReadableBlocks(String content) {
  final normalized = content
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  if (normalized.isEmpty) return const <String>[];

  final result = <String>[];
  for (final rawParagraph in normalized.split(RegExp(r'\n+'))) {
    final paragraph = rawParagraph.trim();
    if (paragraph.isEmpty) continue;
    if (paragraph.length <= 150) {
      result.add(paragraph);
      continue;
    }
    final buffer = StringBuffer();
    for (var i = 0; i < paragraph.length; i++) {
      final ch = paragraph[i];
      buffer.write(ch);
      final sentenceEnd = RegExp(r'[。！？!?；;]').hasMatch(ch) && buffer.length >= 28;
      final tooLong = buffer.length >= 170;
      if (sentenceEnd || tooLong) {
        final piece = buffer.toString().trim();
        if (piece.isNotEmpty) result.add(piece);
        buffer.clear();
      }
    }
    final rest = buffer.toString().trim();
    if (rest.isNotEmpty) result.add(rest);
  }
  return result.isEmpty ? <String>[normalized] : result;
}

bool _containsIgnoreCase(String source, String query) {
  if (query.trim().isEmpty) return false;
  return source.contains(query) || source.toLowerCase().contains(query.toLowerCase());
}

String _cleanError(Object e) {
  return e.toString().replaceFirst('FormatException: ', '').replaceFirst('Exception: ', '');
}
