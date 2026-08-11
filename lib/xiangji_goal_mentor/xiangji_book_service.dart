import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'xiangji_book_index_service.dart';
import 'xiangji_dao.dart';
import 'xiangji_models.dart';
import 'xiangji_provider_mirror_service.dart';

class XiangjiBookImportResult {
  const XiangjiBookImportResult({
    required this.imported,
    required this.message,
    this.bookId = '',
    this.parseStatus = '',
  });

  final bool imported;
  final String message;
  final String bookId;
  final String parseStatus;
}

class XiangjiBookDeletionResult {
  const XiangjiBookDeletionResult({
    required this.localDeleted,
    required this.remoteDeletionPending,
  });

  final bool localDeleted;
  final bool remoteDeletionPending;
}

class XiangjiBookService {
  factory XiangjiBookService({
    XiangjiGoalMentorDao? dao,
    Future<Directory> Function()? documentsDirectory,
    XiangjiBookIndexService? indexService,
    XiangjiProviderMirrorService? mirrorService,
  }) {
    final resolvedDao = dao ?? XiangjiGoalMentorDao();
    return XiangjiBookService._(
      dao: resolvedDao,
      documentsDirectory:
          documentsDirectory ?? getApplicationDocumentsDirectory,
      indexService:
          indexService ?? XiangjiBookIndexService(dao: resolvedDao),
      mirrorService:
          mirrorService ?? XiangjiProviderMirrorService(dao: resolvedDao),
    );
  }

  XiangjiBookService._({
    required XiangjiGoalMentorDao dao,
    required Future<Directory> Function() documentsDirectory,
    required XiangjiBookIndexService indexService,
    required XiangjiProviderMirrorService mirrorService,
  })  : _dao = dao,
        _documentsDirectory = documentsDirectory,
        _indexService = indexService,
        _mirrorService = mirrorService;

  final XiangjiGoalMentorDao _dao;
  final Future<Directory> Function() _documentsDirectory;
  final XiangjiBookIndexService _indexService;
  final XiangjiProviderMirrorService _mirrorService;

  Future<XiangjiBookImportResult> importPrivateBook() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      type: FileType.custom,
      allowedExtensions: const <String>[
        'pdf',
        'epub',
        'docx',
        'txt',
        'md',
        'azw3',
      ],
    );
    if (picked == null || picked.files.isEmpty) {
      return const XiangjiBookImportResult(imported: false, message: '已取消导入');
    }
    final selected = picked.files.single;
    final sourcePath = selected.path;
    if (sourcePath == null || sourcePath.isEmpty) {
      return const XiangjiBookImportResult(
        imported: false,
        message: '无法读取所选文件路径',
      );
    }
    return importPrivateBookFromFile(
      File(sourcePath),
      displayName: selected.name,
      mimeType: _mimeType(selected.name),
    );
  }

  Future<XiangjiBookImportResult> importPrivateBookFromFile(
    File source, {
    required String displayName,
    String mimeType = '',
  }) async {
    if (!await source.exists()) {
      return const XiangjiBookImportResult(
        imported: false,
        message: '所选文件不存在或已被移动',
      );
    }
    final root = await _documentsDirectory();
    final directory = Directory(p.join(root.path, 'xiangji_private_books'));
    await directory.create(recursive: true);
    final safeName = p.basename(displayName).replaceAll(
          RegExp(r'[^\w\u4e00-\u9fff.() -]'),
          '_',
        );
    final target = File(
      p.join(
        directory.path,
        '${DateTime.now().millisecondsSinceEpoch}_$safeName',
      ),
    );
    try {
      await source.copy(target.path);
      final digest = await sha256.bind(target.openRead()).first;
      final contentHash = digest.toString();
      final duplicate = await _dao.activeBookByHash(contentHash);
      if (duplicate != null) {
        await target.delete();
        return XiangjiBookImportResult(
          imported: false,
          message: '这本书已存在于私人书库：${duplicate.title}',
          bookId: duplicate.id,
          parseStatus: duplicate.parseStatus,
        );
      }
      final bookId = await _dao.saveImportedBook(
        title: displayName,
        localPath: target.path,
        contentHash: contentHash,
        mimeType: mimeType.isEmpty ? _mimeType(displayName) : mimeType,
        sizeBytes: await target.length(),
      );
      try {
        final index = await _indexService.indexFile(
          file: target,
          filename: displayName,
          bookId: bookId,
          bookTitle: displayName,
        );
        await _dao.replaceBookChunks(
          bookId: bookId,
          chunks: index.chunks,
          parsedCharacters: index.parsedCharacters,
          partial: index.partial,
        );
        return XiangjiBookImportResult(
          imported: true,
          message: index.partial
              ? '已私密保存并建立部分索引（${index.chunks.length} 个可定位片段）。当前格式无法保证完整提取，严格问书会标记覆盖边界。'
              : '已私密保存并建立 ${index.chunks.length} 个可定位片段，可在本地严格问书。',
          bookId: 'local_$bookId',
          parseStatus: index.partial ? 'partial' : 'ready',
        );
      } catch (error) {
        await _dao.markBookParseFailed(bookId, error.toString());
        return XiangjiBookImportResult(
          imported: true,
          message: '文件已私密保存，但解析未完成：${_safeError(error)}',
          bookId: 'local_$bookId',
          parseStatus: 'failed',
        );
      }
    } catch (_) {
      try {
        if (await target.exists()) await target.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<XiangjiBookDeletionResult> deletePrivateBook(
    XiangjiBookInfo book,
  ) async {
    if (book.builtIn) {
      return const XiangjiBookDeletionResult(
        localDeleted: false,
        remoteDeletionPending: false,
      );
    }
    final mirror = book.providerMirror ??
        await _dao.providerMirror(
          book.id,
          provider: XiangjiProviderMirrorService.provider,
        );
    final path = book.localPath.trim();
    await _dao.markImportedBookDeleted(book.id);
    if (path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    if (mirror != null &&
        mirror.syncStatus != 'deleted' &&
        mirror.hasRemoteResources) {
      final deleted = await _mirrorService.deleteRemoteCopy(mirror);
      return XiangjiBookDeletionResult(
        localDeleted: true,
        remoteDeletionPending: deleted.syncStatus != 'deleted',
      );
    }
    return const XiangjiBookDeletionResult(
      localDeleted: true,
      remoteDeletionPending: false,
    );
  }

  /// Removes every registered private book and the narrowly scoped storage
  /// directory, including orphan files left by an interrupted import.
  Future<void> deleteAllPrivateBooks() async {
    final books = await _dao.importedBooks();
    for (final book in books) {
      await deletePrivateBook(book);
    }
    await _mirrorService.retryPendingDeletions();
    if ((await _dao.pendingProviderDeletions()).isNotEmpty) {
      throw StateError('本地内容已删除，但仍有 OpenAI 远端副本等待删除；请保留 API Key 并稍后重试。');
    }
    final root = await _documentsDirectory();
    final directory = Directory(p.join(root.path, 'xiangji_private_books'));
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<XiangjiProviderMirror> syncProviderMirror(
    XiangjiBookInfo book, {
    required int consentedAtMs,
  }) =>
      _mirrorService.syncBook(book, consentedAtMs: consentedAtMs);

  Future<int> retryPendingProviderDeletions() =>
      _mirrorService.retryPendingDeletions();

  /// Export files contain the same sensitive goal text as the database, so
  /// "clear all" must remove prior exports created inside app storage too.
  Future<int> deleteGeneratedExports() async {
    final root = await _documentsDirectory();
    var deleted = 0;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith('xiangji_export_') || !name.endsWith('.json')) {
        continue;
      }
      await entity.delete();
      deleted += 1;
    }
    return deleted;
  }

  static String _mimeType(String filename) {
    switch (p.extension(filename).toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.epub':
        return 'application/epub+zip';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.md':
        return 'text/markdown';
      case '.txt':
        return 'text/plain';
      case '.azw3':
        return 'application/vnd.amazon.ebook';
      default:
        return 'application/octet-stream';
    }
  }

  static String _safeError(Object error) {
    final value = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return value.length <= 160 ? value : '${value.substring(0, 157)}...';
  }
}
