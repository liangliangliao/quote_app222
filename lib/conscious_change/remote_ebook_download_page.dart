import 'dart:async';

import 'package:flutter/material.dart';

import 'conscious_change_dao.dart';
import 'conscious_change_import_parser.dart';
import 'remote_ebook_service.dart';

class RemoteEbookDownloadPage extends StatefulWidget {
  const RemoteEbookDownloadPage({super.key});

  @override
  State<RemoteEbookDownloadPage> createState() => _RemoteEbookDownloadPageState();
}

class _RemoteEbookDownloadPageState extends State<RemoteEbookDownloadPage> {
  final TextEditingController _controller = TextEditingController();
  final RemoteEbookRepository _repository = RemoteEbookRepository();
  final ConsciousChangeDao _dao = ConsciousChangeDao();

  bool _searching = false;
  bool _importedAny = false;
  String? _error;
  String? _activeDownloadKey;
  List<RemoteEbookCandidate> _results = const <RemoteEbookCandidate>[];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _repository.close();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    if (mounted) setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), () => _search());
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const <RemoteEbookCandidate>[];
        _error = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await _repository.searchAll(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(e);
        _searching = false;
      });
    }
  }

  Future<void> _downloadAndImport(RemoteEbookCandidate candidate) async {
    setState(() {
      _activeDownloadKey = candidate.normalizedKey;
      _error = null;
    });
    try {
      final download = await _repository.downloadToLocalCopies(candidate);
      final existing = await _dao.findDocumentBySha256(download.sha256);
      if (existing != null) {
        if (!mounted) return;
        setState(() {
          _importedAny = true;
          _activeDownloadKey = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('这本书已在书架中：${existing.title}')));
        return;
      }

      final parsed = await ConsciousChangeImportParser.parseFile(
        fileName: candidate.fileName,
        extension: candidate.fileExt,
        bytes: download.bytes,
        path: download.supportPath,
        preferBookStructure: true,
      );
      await _dao.createDocumentWithChapters(
        title: parsed.title,
        fileName: candidate.fileName,
        fileExt: candidate.fileExt,
        sourcePath: download.supportPath,
        documentType: 'book',
        importOrigin: 'remote',
        remoteSourceName: candidate.sourceLabel,
        remoteSourceBookId: candidate.sourceBookId,
        remoteSourcePageUrl: candidate.sourcePageUrl,
        remoteDownloadUrl: candidate.downloadUrl,
        licenseStatus: candidate.licenseStatus,
        downloadsPath: download.downloadsPath,
        sha256: download.sha256,
        chapters: parsed.chapters,
      );
      if (!mounted) return;
      setState(() {
        _importedAny = true;
        _activeDownloadKey = null;
      });
      final extra = download.downloadsPath.isEmpty
          ? '已导入书架；系统下载目录写入失败，已保留应用内副本。'
          : '已导入书架，并保存到 Downloads/Ebooks。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(extra)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activeDownloadKey = null;
        _error = _cleanError(e);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('下载或导入失败：${_cleanError(e)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_importedAny);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('在线下载电子书'),
          backgroundColor: const Color(0xFFF8FAFC),
          surfaceTintColor: Colors.transparent,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(_importedAny),
              child: const Text('完成'),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _buildIntroCard(),
              const SizedBox(height: 14),
              _buildSearchBox(),
              const SizedBox(height: 16),
              if (_error != null) _buildError(),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_controller.text.trim().isNotEmpty && _results.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Text('没有找到可下载并解析的电子书。可以换英文书名、作者或更短关键词再试。', style: TextStyle(color: Color(0xFF6B7280), height: 1.5)),
                )
              else ...[
                for (final item in _results) _buildCandidateCard(item),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('多数据源检索', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
          SizedBox(height: 8),
          Text(
            '支持 EPUB、TXT、HTML、FB2、RTF、DOCX、PDF 等格式。下载后会先保存到 Downloads/Ebooks，再解析进“阅读书籍”的同一数据库；PDF 仅支持文本型文件，扫描版暂不做 OCR。',
            style: TextStyle(color: Color(0xFF6B7280), height: 1.5, fontSize: 13.5),
          ),
          SizedBox(height: 8),
          Text(
            '仅接入公版、开放获取或明确授权的下载源；不接入影子图书馆下载接口。',
            style: TextStyle(color: Color(0xFF9CA3AF), height: 1.45, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return TextField(
      controller: _controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: _onQueryChanged,
      onSubmitted: (_) => _search(),
      decoration: InputDecoration(
        hintText: '输入书名、作者或关键词',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.trim().isEmpty
            ? null
            : IconButton(
                tooltip: '清空',
                icon: const Icon(Icons.close),
                onPressed: () {
                  _controller.clear();
                  _search();
                },
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), height: 1.45)),
    );
  }

  Widget _buildCandidateCard(RemoteEbookCandidate item) {
    final downloading = _activeDownloadKey == item.normalizedKey;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(item.sourceLabel, const Color(0xFFEEF2FF), const Color(0xFF4F46E5)),
              _pill(item.formatLabel, const Color(0xFFFFF7ED), const Color(0xFFC2410C)),
              _pill(_licenseLabel(item.licenseStatus), const Color(0xFFF0FDF4), const Color(0xFF15803D)),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.title, style: const TextStyle(fontSize: 17, height: 1.25, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
          if (item.author.trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(item.author, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
          ],
          if (item.language.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('语言：${item.language}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12.5)),
          ],
          if (item.rightsNote.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(item.rightsNote, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6B7280), height: 1.35, fontSize: 12.5)),
          ],
          if (item.fileExt.toLowerCase() == 'pdf') ...[
            const SizedBox(height: 7),
            const Text('PDF 将尝试提取文本；扫描版 PDF 可能无法导入正文。', style: TextStyle(color: Color(0xFFB45309), height: 1.35, fontSize: 12.5)),
          ],
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: downloading || _activeDownloadKey != null ? null : () => _downloadAndImport(item),
              icon: downloading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded),
              label: Text(downloading ? '下载并解析中…' : '下载 ${item.formatLabel} 并加入书架'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }

  String _licenseLabel(String status) {
    return switch (status) {
      'public_domain' => 'Public Domain',
      'open_access' => 'Open Access',
      'cc_license' => 'Creative Commons',
      _ => 'Authorized',
    };
  }
}

String _cleanError(Object error) {
  return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').replaceFirst(RegExp(r'^FormatException:\s*'), '').trim();
}
