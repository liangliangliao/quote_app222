import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'xiangji_dao.dart';
import 'xiangji_models.dart';

class XiangjiBookImportResult {
  const XiangjiBookImportResult({
    required this.imported,
    required this.message,
  });

  final bool imported;
  final String message;
}

class XiangjiBookService {
  XiangjiBookService({XiangjiGoalMentorDao? dao})
      : _dao = dao ?? XiangjiGoalMentorDao();

  final XiangjiGoalMentorDao _dao;

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
    final source = File(sourcePath);
    if (!await source.exists()) {
      return const XiangjiBookImportResult(
        imported: false,
        message: '所选文件不存在或已被移动',
      );
    }
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'xiangji_private_books'));
    await directory.create(recursive: true);
    final safeName = p.basename(sourcePath).replaceAll(
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
      await _dao.saveImportedBook(
        title: selected.name,
        localPath: target.path,
        contentHash: digest.toString(),
      );
    } catch (_) {
      try {
        if (await target.exists()) await target.delete();
      } catch (_) {}
      rethrow;
    }
    return const XiangjiBookImportResult(
      imported: true,
      message: '已私密保存到本地。尚未完成受控解析前，不会用于思想家观点生成。',
    );
  }

  Future<void> deletePrivateBook(XiangjiBookInfo book) async {
    if (book.builtIn) return;
    final path = book.localPath.trim();
    if (path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await _dao.markImportedBookDeleted(book.id);
  }
}
