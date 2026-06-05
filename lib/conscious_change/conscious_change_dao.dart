import 'package:sqflite/sqflite.dart';

import '../data/db.dart';

const String consciousChangeCoreIdea =
    '人可以改变，但真正持久的改变没有快速修复，必须通过情感、行为和认知三方面共同作用，并在时间中逐步塑造新的神经路径。理解并服从人性，通过有意识的练习、选择、简化和自我接纳，把生活从被动反应转化为主动创造。';

class CcImportedSection {
  final String title;
  final String content;
  final List<String> keywords;

  const CcImportedSection({
    required this.title,
    required this.content,
    required this.keywords,
  });
}

class CcImportedChapter {
  final String title;
  final String content;
  final List<String> keywords;
  final List<CcImportedSection> sections;

  const CcImportedChapter({
    required this.title,
    required this.content,
    required this.keywords,
    required this.sections,
  });
}

class CcLearningDocument {
  final int id;
  final String title;
  final String fileName;
  final String fileExt;
  final String sourcePath;
  final String docType;
  final String importOrigin;
  final String remoteSourceName;
  final String remoteSourceBookId;
  final String remoteSourcePageUrl;
  final String remoteDownloadUrl;
  final String licenseStatus;
  final String downloadsPath;
  final String sha256;
  final int chapterCount;
  final int orderIndex;
  final int createdAtMs;
  final int updatedAtMs;

  const CcLearningDocument({
    required this.id,
    required this.title,
    required this.fileName,
    required this.fileExt,
    required this.sourcePath,
    this.docType = 'course',
    this.importOrigin = 'local',
    this.remoteSourceName = '',
    this.remoteSourceBookId = '',
    this.remoteSourcePageUrl = '',
    this.remoteDownloadUrl = '',
    this.licenseStatus = '',
    this.downloadsPath = '',
    this.sha256 = '',
    required this.chapterCount,
    required this.orderIndex,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  factory CcLearningDocument.fromMap(Map<String, Object?> row) {
    return CcLearningDocument(
      id: (row['id'] as num).toInt(),
      title: (row['title'] ?? '').toString(),
      fileName: (row['file_name'] ?? '').toString(),
      fileExt: (row['file_ext'] ?? '').toString(),
      sourcePath: (row['source_path'] ?? '').toString(),
      docType: (row['doc_type'] ?? 'course').toString(),
      importOrigin: (row['import_origin'] ?? 'local').toString(),
      remoteSourceName: (row['remote_source_name'] ?? '').toString(),
      remoteSourceBookId: (row['remote_source_book_id'] ?? '').toString(),
      remoteSourcePageUrl: (row['remote_source_page_url'] ?? '').toString(),
      remoteDownloadUrl: (row['remote_download_url'] ?? '').toString(),
      licenseStatus: (row['license_status'] ?? '').toString(),
      downloadsPath: (row['downloads_path'] ?? '').toString(),
      sha256: (row['sha256'] ?? '').toString(),
      chapterCount: ((row['chapter_count'] ?? 0) as num).toInt(),
      orderIndex: ((row['order_index'] ?? 0) as num).toInt(),
      createdAtMs: ((row['created_at_ms'] ?? 0) as num).toInt(),
      updatedAtMs: ((row['updated_at_ms'] ?? 0) as num).toInt(),
    );
  }
}

class CcLearningChapter {
  final int id;
  final int documentId;
  final int chapterIndex;
  final String title;
  final String content;
  final List<String> keywords;
  final String documentTitle;

  const CcLearningChapter({
    required this.id,
    required this.documentId,
    required this.chapterIndex,
    required this.title,
    required this.content,
    required this.keywords,
    this.documentTitle = '',
  });

  factory CcLearningChapter.fromMap(Map<String, Object?> row) {
    return CcLearningChapter(
      id: (row['id'] as num).toInt(),
      documentId: ((row['document_id'] ?? 0) as num).toInt(),
      chapterIndex: ((row['chapter_index'] ?? 0) as num).toInt(),
      title: (row['title'] ?? '').toString(),
      content: (row['content'] ?? '').toString(),
      keywords: _splitKeywordCsv((row['keyword_csv'] ?? '').toString()),
      documentTitle: (row['document_title'] ?? '').toString(),
    );
  }
}

class CcLearningSection {
  final int id;
  final int chapterId;
  final int sectionIndex;
  final String title;
  final String content;
  final List<String> keywords;

  const CcLearningSection({
    required this.id,
    required this.chapterId,
    required this.sectionIndex,
    required this.title,
    required this.content,
    required this.keywords,
  });

  factory CcLearningSection.fromMap(Map<String, Object?> row) {
    return CcLearningSection(
      id: (row['id'] as num).toInt(),
      chapterId: ((row['chapter_id'] ?? 0) as num).toInt(),
      sectionIndex: ((row['section_index'] ?? 0) as num).toInt(),
      title: (row['title'] ?? '').toString(),
      content: (row['content'] ?? '').toString(),
      keywords: _splitKeywordCsv((row['keyword_csv'] ?? '').toString()),
    );
  }
}

class CcChapterDetail {
  final CcLearningChapter chapter;
  final List<CcLearningSection> sections;

  const CcChapterDetail({required this.chapter, required this.sections});
}


class CcReadingPosition {
  final int documentId;
  final int chapterId;
  final int sectionId;
  final String documentTitle;
  final String chapterTitle;
  final String sectionTitle;
  final String documentType;
  final int sectionIndex;
  final double scrollOffset;
  final String epubCfi;
  final int updatedAtMs;

  const CcReadingPosition({
    required this.documentId,
    required this.chapterId,
    required this.sectionId,
    required this.documentTitle,
    required this.chapterTitle,
    required this.sectionTitle,
    this.documentType = 'course',
    required this.sectionIndex,
    required this.scrollOffset,
    this.epubCfi = '',
    required this.updatedAtMs,
  });

  factory CcReadingPosition.fromMap(Map<String, Object?> row) {
    return CcReadingPosition(
      documentId: ((row['document_id'] ?? 0) as num).toInt(),
      chapterId: ((row['chapter_id'] ?? 0) as num).toInt(),
      sectionId: ((row['section_id'] ?? 0) as num).toInt(),
      documentTitle: (row['document_title'] ?? '').toString(),
      chapterTitle: (row['chapter_title'] ?? '').toString(),
      sectionTitle: (row['section_title'] ?? '').toString(),
      documentType: (row['document_type'] ?? row['doc_type'] ?? 'course').toString(),
      sectionIndex: ((row['section_index'] ?? 0) as num).toInt(),
      scrollOffset: ((row['scroll_offset'] ?? 0) as num).toDouble(),
      epubCfi: (row['epub_cfi'] ?? '').toString(),
      updatedAtMs: ((row['updated_at_ms'] ?? 0) as num).toInt(),
    );
  }
}


class CcSectionDetail {
  final CcLearningChapter chapter;
  final CcLearningSection section;
  final CcLearningSection? previousSection;
  final CcLearningSection? nextSection;
  final List<CcLearningSection> chapterSections;
  final int currentIndex;

  const CcSectionDetail({
    required this.chapter,
    required this.section,
    this.previousSection,
    this.nextSection,
    this.chapterSections = const <CcLearningSection>[],
    this.currentIndex = 0,
  });
}

class CcSearchHit {
  final int documentId;
  final int chapterId;
  final int? sectionId;
  final String documentTitle;
  final String chapterTitle;
  final String sectionTitle;
  final String sentence;
  final String query;
  final int offset;

  const CcSearchHit({
    required this.documentId,
    required this.chapterId,
    required this.sectionId,
    required this.documentTitle,
    required this.chapterTitle,
    required this.sectionTitle,
    required this.sentence,
    required this.query,
    required this.offset,
  });
}

class ConsciousChangeDao {
  Future<Database> _database() async {
    final db = await AppDatabase.instance();
    await ensureSchema(db: db);
    return db;
  }

  Future<void> ensureSchema({Database? db}) async {
    final database = db ?? await AppDatabase.instance();
    await database.execute('''
      CREATE TABLE IF NOT EXISTS cc_learning_documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        file_name TEXT,
        file_ext TEXT,
        source_path TEXT,
        doc_type TEXT NOT NULL DEFAULT 'course',
        import_origin TEXT NOT NULL DEFAULT 'local',
        remote_source_name TEXT,
        remote_source_book_id TEXT,
        remote_source_page_url TEXT,
        remote_download_url TEXT,
        license_status TEXT,
        downloads_path TEXT,
        sha256 TEXT,
        core_idea TEXT NOT NULL,
        chapter_count INTEGER NOT NULL DEFAULT 0,
        order_index INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    try {
      await database.execute("ALTER TABLE cc_learning_documents ADD COLUMN doc_type TEXT NOT NULL DEFAULT 'course'");
    } catch (_) {
      // Column already exists on upgraded databases.
    }
    try {
      await database.execute('ALTER TABLE cc_learning_documents ADD COLUMN order_index INTEGER NOT NULL DEFAULT 0');
    } catch (_) {
      // Column already exists on upgraded databases.
    }
    for (final statement in const <String>[
      "ALTER TABLE cc_learning_documents ADD COLUMN import_origin TEXT NOT NULL DEFAULT 'local'",
      'ALTER TABLE cc_learning_documents ADD COLUMN remote_source_name TEXT',
      'ALTER TABLE cc_learning_documents ADD COLUMN remote_source_book_id TEXT',
      'ALTER TABLE cc_learning_documents ADD COLUMN remote_source_page_url TEXT',
      'ALTER TABLE cc_learning_documents ADD COLUMN remote_download_url TEXT',
      'ALTER TABLE cc_learning_documents ADD COLUMN license_status TEXT',
      'ALTER TABLE cc_learning_documents ADD COLUMN downloads_path TEXT',
      'ALTER TABLE cc_learning_documents ADD COLUMN sha256 TEXT',
    ]) {
      try {
        await database.execute(statement);
      } catch (_) {
        // Column already exists on upgraded databases.
      }
    }
    await database.execute('''
      CREATE TABLE IF NOT EXISTS cc_learning_chapters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        chapter_index INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        keyword_csv TEXT,
        created_at_ms INTEGER NOT NULL,
        FOREIGN KEY(document_id) REFERENCES cc_learning_documents(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS cc_learning_sections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chapter_id INTEGER NOT NULL,
        section_index INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        keyword_csv TEXT,
        FOREIGN KEY(chapter_id) REFERENCES cc_learning_chapters(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS cc_learning_reading_positions (
        document_id INTEGER PRIMARY KEY,
        chapter_id INTEGER NOT NULL,
        section_id INTEGER NOT NULL,
        section_index INTEGER NOT NULL DEFAULT 0,
        scroll_offset REAL NOT NULL DEFAULT 0,
        epub_cfi TEXT,
        updated_at_ms INTEGER NOT NULL,
        FOREIGN KEY(document_id) REFERENCES cc_learning_documents(id) ON DELETE CASCADE
      )
    ''');
    try {
      await database.execute('ALTER TABLE cc_learning_reading_positions ADD COLUMN epub_cfi TEXT');
    } catch (_) {
      // Column already exists on upgraded databases.
    }
    try {
      await database.execute("UPDATE cc_learning_documents SET doc_type = 'book' WHERE lower(file_ext) IN ('epub', 'fb2') AND (doc_type IS NULL OR doc_type = '' OR doc_type = 'course')");
    } catch (_) {
      // Ignore migration failures on older schemas; normal schema creation above will cover new installs.
    }
    await database.execute('CREATE INDEX IF NOT EXISTS idx_cc_docs_updated ON cc_learning_documents(updated_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_cc_chapter_doc_order ON cc_learning_chapters(document_id, chapter_index)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_cc_section_chapter_order ON cc_learning_sections(chapter_id, section_index)');
  }

  Future<int> createDocumentWithChapters({
    required String title,
    required String fileName,
    required String fileExt,
    required String sourcePath,
    String documentType = 'course',
    String importOrigin = 'local',
    String? remoteSourceName,
    String? remoteSourceBookId,
    String? remoteSourcePageUrl,
    String? remoteDownloadUrl,
    String? licenseStatus,
    String? downloadsPath,
    String? sha256,
    required List<CcImportedChapter> chapters,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction<int>((txn) async {
      final maxOrderRows = await txn.rawQuery('SELECT COALESCE(MAX(order_index), -1) + 1 AS next_order FROM cc_learning_documents');
      final nextOrder = ((maxOrderRows.first['next_order'] ?? 0) as num).toInt();
      final documentId = await txn.insert('cc_learning_documents', {
        'title': title.trim().isEmpty ? fileName : title.trim(),
        'file_name': fileName,
        'file_ext': fileExt,
        'source_path': sourcePath,
        'doc_type': documentType.trim().isEmpty ? 'course' : documentType.trim(),
        'import_origin': importOrigin.trim().isEmpty ? 'local' : importOrigin.trim(),
        'remote_source_name': remoteSourceName?.trim(),
        'remote_source_book_id': remoteSourceBookId?.trim(),
        'remote_source_page_url': remoteSourcePageUrl?.trim(),
        'remote_download_url': remoteDownloadUrl?.trim(),
        'license_status': licenseStatus?.trim(),
        'downloads_path': downloadsPath?.trim(),
        'sha256': sha256?.trim(),
        'core_idea': consciousChangeCoreIdea,
        'chapter_count': chapters.length,
        'order_index': nextOrder,
        'created_at_ms': now,
        'updated_at_ms': now,
      });

      for (var i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        final chapterId = await txn.insert('cc_learning_chapters', {
          'document_id': documentId,
          'chapter_index': i,
          'title': chapter.title,
          'content': chapter.content,
          'keyword_csv': _joinKeywords(chapter.keywords),
          'created_at_ms': now,
        });
        final sections = chapter.sections.isEmpty
            ? [
                CcImportedSection(
                  title: '本章内容',
                  content: chapter.content,
                  keywords: chapter.keywords,
                ),
              ]
            : chapter.sections;
        for (var j = 0; j < sections.length; j++) {
          final section = sections[j];
          await txn.insert('cc_learning_sections', {
            'chapter_id': chapterId,
            'section_index': j,
            'title': section.title,
            'content': section.content,
            'keyword_csv': _joinKeywords(section.keywords),
          });
        }
      }
      return documentId;
    });
  }

  Future<List<CcLearningDocument>> listDocuments({String? documentType}) async {
    final db = await _database();
    final type = documentType?.trim();
    final rows = await db.query(
      'cc_learning_documents',
      where: type == null || type.isEmpty ? null : 'doc_type = ?',
      whereArgs: type == null || type.isEmpty ? null : [type],
      orderBy: 'order_index ASC, updated_at_ms DESC, id DESC',
    );
    return rows.map(CcLearningDocument.fromMap).toList();
  }

  Future<CcLearningDocument?> findDocumentBySha256(String sha256) async {
    final value = sha256.trim();
    if (value.isEmpty) return null;
    final db = await _database();
    final rows = await db.query(
      'cc_learning_documents',
      where: 'sha256 = ?',
      whereArgs: [value],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CcLearningDocument.fromMap(rows.first);
  }

  Future<CcLearningDocument?> getDocument(int documentId) async {
    final db = await _database();
    final rows = await db.query(
      'cc_learning_documents',
      where: 'id = ?',
      whereArgs: [documentId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CcLearningDocument.fromMap(rows.first);
  }

  Future<int?> getFirstSectionIdForDocument(int documentId) async {
    final db = await _database();
    final rows = await db.rawQuery('''
      SELECT s.id AS id
      FROM cc_learning_sections s
      JOIN cc_learning_chapters c ON c.id = s.chapter_id
      WHERE c.document_id = ?
      ORDER BY c.chapter_index ASC, s.section_index ASC, s.id ASC
      LIMIT 1
    ''', [documentId]);
    if (rows.isEmpty) return null;
    return ((rows.first['id'] ?? 0) as num).toInt();
  }

  Future<int?> getFirstSectionIdForChapter(int chapterId) async {
    final db = await _database();
    final rows = await db.query(
      'cc_learning_sections',
      columns: ['id'],
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
      orderBy: 'section_index ASC, id ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ((rows.first['id'] ?? 0) as num).toInt();
  }

  Future<List<CcLearningChapter>> listChapters(int documentId) async {
    final db = await _database();
    final rows = await db.query(
      'cc_learning_chapters',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'chapter_index ASC, id ASC',
    );
    return rows.map(CcLearningChapter.fromMap).toList();
  }

  Future<CcChapterDetail?> getChapterDetail(int chapterId) async {
    final db = await _database();
    final rows = await db.rawQuery('''
      SELECT c.*, d.title AS document_title
      FROM cc_learning_chapters c
      LEFT JOIN cc_learning_documents d ON d.id = c.document_id
      WHERE c.id = ?
      LIMIT 1
    ''', [chapterId]);
    if (rows.isEmpty) return null;
    final sections = await db.query(
      'cc_learning_sections',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
      orderBy: 'section_index ASC, id ASC',
    );
    return CcChapterDetail(
      chapter: CcLearningChapter.fromMap(rows.first),
      sections: sections.map(CcLearningSection.fromMap).toList(),
    );
  }


  Future<CcSectionDetail?> getSectionDetail(int sectionId) async {
    final db = await _database();
    final sectionRows = await db.query(
      'cc_learning_sections',
      where: 'id = ?',
      whereArgs: [sectionId],
      limit: 1,
    );
    if (sectionRows.isEmpty) return null;
    final section = CcLearningSection.fromMap(sectionRows.first);
    final chapterRows = await db.rawQuery('''
      SELECT c.*, d.title AS document_title
      FROM cc_learning_chapters c
      LEFT JOIN cc_learning_documents d ON d.id = c.document_id
      WHERE c.id = ?
      LIMIT 1
    ''', [section.chapterId]);
    if (chapterRows.isEmpty) return null;

    final currentChapter = CcLearningChapter.fromMap(chapterRows.first);
    final documentTypeRows = await db.query(
      'cc_learning_documents',
      columns: ['doc_type'],
      where: 'id = ?',
      whereArgs: [currentChapter.documentId],
      limit: 1,
    );
    final documentType = documentTypeRows.isEmpty
        ? 'course'
        : (documentTypeRows.first['doc_type'] ?? 'course').toString();
    final allRows = documentType == 'book'
        ? await db.rawQuery('''
            SELECT s.*
            FROM cc_learning_sections s
            JOIN cc_learning_chapters c ON c.id = s.chapter_id
            WHERE c.document_id = ?
            ORDER BY c.chapter_index ASC, s.section_index ASC, s.id ASC
          ''', [currentChapter.documentId])
        : await db.query(
            'cc_learning_sections',
            where: 'chapter_id = ?',
            whereArgs: [section.chapterId],
            orderBy: 'section_index ASC, id ASC',
          );
    final sections = allRows.map(CcLearningSection.fromMap).toList();
    var currentIndex = sections.indexWhere((item) => item.id == section.id);
    if (currentIndex < 0) currentIndex = 0;

    final previousSection = currentIndex > 0 ? sections[currentIndex - 1] : null;
    final nextSection = currentIndex < sections.length - 1 ? sections[currentIndex + 1] : null;

    return CcSectionDetail(
      chapter: currentChapter,
      section: section,
      previousSection: previousSection,
      nextSection: nextSection,
      chapterSections: sections,
      currentIndex: currentIndex,
    );
  }

  Future<void> deleteDocument(int documentId) async {
    final db = await _database();
    await db.transaction((txn) async {
      await txn.delete('cc_learning_reading_positions', where: 'document_id = ?', whereArgs: [documentId]);
      final chapterRows = await txn.query(
        'cc_learning_chapters',
        columns: ['id'],
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
      for (final row in chapterRows) {
        final chapterId = (row['id'] as num).toInt();
        await txn.delete('cc_learning_sections', where: 'chapter_id = ?', whereArgs: [chapterId]);
      }
      await txn.delete('cc_learning_chapters', where: 'document_id = ?', whereArgs: [documentId]);
      await txn.delete('cc_learning_documents', where: 'id = ?', whereArgs: [documentId]);
    });
  }


  Future<void> clearAllDocuments({String? documentType}) async {
    final db = await _database();
    final type = documentType?.trim();
    await db.transaction((txn) async {
      if (type == null || type.isEmpty) {
        await txn.delete('cc_learning_reading_positions');
        await txn.delete('cc_learning_sections');
        await txn.delete('cc_learning_chapters');
        await txn.delete('cc_learning_documents');
        return;
      }
      final docRows = await txn.query(
        'cc_learning_documents',
        columns: ['id'],
        where: 'doc_type = ?',
        whereArgs: [type],
      );
      for (final row in docRows) {
        final documentId = ((row['id'] ?? 0) as num).toInt();
        await txn.delete('cc_learning_reading_positions', where: 'document_id = ?', whereArgs: [documentId]);
        final chapterRows = await txn.query(
          'cc_learning_chapters',
          columns: ['id'],
          where: 'document_id = ?',
          whereArgs: [documentId],
        );
        for (final chapterRow in chapterRows) {
          final chapterId = ((chapterRow['id'] ?? 0) as num).toInt();
          await txn.delete('cc_learning_sections', where: 'chapter_id = ?', whereArgs: [chapterId]);
        }
        await txn.delete('cc_learning_chapters', where: 'document_id = ?', whereArgs: [documentId]);
        await txn.delete('cc_learning_documents', where: 'id = ?', whereArgs: [documentId]);
      }
    });
  }

  Future<void> deleteChapter(int chapterId) async {
    final db = await _database();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'cc_learning_chapters',
        columns: ['document_id'],
        where: 'id = ?',
        whereArgs: [chapterId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final documentId = ((rows.first['document_id'] ?? 0) as num).toInt();
      await txn.delete('cc_learning_reading_positions', where: 'chapter_id = ?', whereArgs: [chapterId]);
      await txn.delete('cc_learning_sections', where: 'chapter_id = ?', whereArgs: [chapterId]);
      await txn.delete('cc_learning_chapters', where: 'id = ?', whereArgs: [chapterId]);
      final remaining = await txn.query(
        'cc_learning_chapters',
        columns: ['id'],
        where: 'document_id = ?',
        whereArgs: [documentId],
        orderBy: 'chapter_index ASC, id ASC',
      );
      for (var i = 0; i < remaining.length; i++) {
        await txn.update(
          'cc_learning_chapters',
          {'chapter_index': i},
          where: 'id = ?',
          whereArgs: [remaining[i]['id']],
        );
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.update(
        'cc_learning_documents',
        {'chapter_count': remaining.length, 'updated_at_ms': now},
        where: 'id = ?',
        whereArgs: [documentId],
      );
    });
  }

  Future<void> reorderDocuments(List<int> orderedDocumentIds) async {
    final db = await _database();
    await db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < orderedDocumentIds.length; i++) {
        await txn.update(
          'cc_learning_documents',
          {'order_index': i, 'updated_at_ms': now},
          where: 'id = ?',
          whereArgs: [orderedDocumentIds[i]],
        );
      }
    });
  }

  Future<void> reorderChapters(int documentId, List<int> orderedChapterIds) async {
    final db = await _database();
    await db.transaction((txn) async {
      for (var i = 0; i < orderedChapterIds.length; i++) {
        await txn.update(
          'cc_learning_chapters',
          {'chapter_index': i},
          where: 'id = ? AND document_id = ?',
          whereArgs: [orderedChapterIds[i], documentId],
        );
      }
      await txn.update(
        'cc_learning_documents',
        {'updated_at_ms': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [documentId],
      );
    });
  }

  Future<void> saveReadingPosition({
    required int sectionId,
    required double scrollOffset,
  }) async {
    final db = await _database();
    final rows = await db.rawQuery('''
      SELECT d.id AS document_id, d.doc_type AS document_type, c.id AS chapter_id, s.id AS section_id, s.section_index AS section_index
      FROM cc_learning_sections s
      JOIN cc_learning_chapters c ON c.id = s.chapter_id
      JOIN cc_learning_documents d ON d.id = c.document_id
      WHERE s.id = ?
      LIMIT 1
    ''', [sectionId]);
    if (rows.isEmpty) return;
    final row = rows.first;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 每个导入文件独立保存阅读位置。
    // 不再清理同模块其它文件的阅读记录，避免课程目录/阅读书籍之间以及不同文件之间互相覆盖。
    await db.insert(
      'cc_learning_reading_positions',
      {
        'document_id': ((row['document_id'] ?? 0) as num).toInt(),
        'chapter_id': ((row['chapter_id'] ?? 0) as num).toInt(),
        'section_id': ((row['section_id'] ?? 0) as num).toInt(),
        'section_index': ((row['section_index'] ?? 0) as num).toInt(),
        'scroll_offset': scrollOffset.isFinite ? scrollOffset : 0,
        'epub_cfi': '',
        'updated_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveEpubReadingPosition({
    required int documentId,
    required String epubCfi,
  }) async {
    final db = await _database();
    final rows = await db.rawQuery('''
      SELECT d.id AS document_id, d.doc_type AS document_type, c.id AS chapter_id, s.id AS section_id, s.section_index AS section_index
      FROM cc_learning_documents d
      JOIN cc_learning_chapters c ON c.document_id = d.id
      JOIN cc_learning_sections s ON s.chapter_id = c.id
      WHERE d.id = ?
      ORDER BY c.chapter_index ASC, s.section_index ASC, s.id ASC
      LIMIT 1
    ''', [documentId]);
    if (rows.isEmpty) return;
    final row = rows.first;
    final now = DateTime.now().millisecondsSinceEpoch;
    // EPUB 旧阅读器路径也按文件独立保存阅读位置。
    await db.insert(
      'cc_learning_reading_positions',
      {
        'document_id': ((row['document_id'] ?? 0) as num).toInt(),
        'chapter_id': ((row['chapter_id'] ?? 0) as num).toInt(),
        'section_id': ((row['section_id'] ?? 0) as num).toInt(),
        'section_index': ((row['section_index'] ?? 0) as num).toInt(),
        'scroll_offset': 0,
        'epub_cfi': epubCfi,
        'updated_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<CcReadingPosition?> getReadingPositionForDocument(int documentId) async {
    final db = await _database();
    final rows = await db.rawQuery('''
      SELECT
        p.document_id AS document_id,
        p.chapter_id AS chapter_id,
        p.section_id AS section_id,
        p.section_index AS section_index,
        p.scroll_offset AS scroll_offset,
        p.epub_cfi AS epub_cfi,
        p.updated_at_ms AS updated_at_ms,
        d.title AS document_title,
        d.doc_type AS document_type,
        c.title AS chapter_title,
        s.title AS section_title
      FROM cc_learning_reading_positions p
      JOIN cc_learning_documents d ON d.id = p.document_id
      JOIN cc_learning_chapters c ON c.id = p.chapter_id
      JOIN cc_learning_sections s ON s.id = p.section_id
      WHERE p.document_id = ?
      LIMIT 1
    ''', [documentId]);
    if (rows.isEmpty) return null;
    return CcReadingPosition.fromMap(rows.first);
  }


  Future<Map<int, CcReadingPosition>> getReadingPositionsForDocuments(List<int> documentIds) async {
    if (documentIds.isEmpty) return <int, CcReadingPosition>{};
    final db = await _database();
    final placeholders = List.filled(documentIds.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT
        p.document_id AS document_id,
        p.chapter_id AS chapter_id,
        p.section_id AS section_id,
        p.section_index AS section_index,
        p.scroll_offset AS scroll_offset,
        p.epub_cfi AS epub_cfi,
        p.updated_at_ms AS updated_at_ms,
        d.title AS document_title,
        d.doc_type AS document_type,
        c.title AS chapter_title,
        s.title AS section_title
      FROM cc_learning_reading_positions p
      JOIN cc_learning_documents d ON d.id = p.document_id
      JOIN cc_learning_chapters c ON c.id = p.chapter_id
      JOIN cc_learning_sections s ON s.id = p.section_id
      WHERE p.document_id IN ($placeholders)
    ''', documentIds);
    final result = <int, CcReadingPosition>{};
    for (final row in rows) {
      final position = CcReadingPosition.fromMap(row);
      result[position.documentId] = position;
    }
    return result;
  }

  Future<CcReadingPosition?> getLatestReadingPosition({String? documentType}) async {
    final db = await _database();
    final args = <Object?>[];
    final typeWhere = documentType == null || documentType.trim().isEmpty ? '' : 'WHERE d.doc_type = ?';
    if (typeWhere.isNotEmpty) args.add(documentType!.trim());
    final rows = await db.rawQuery('''
      SELECT
        p.document_id AS document_id,
        p.chapter_id AS chapter_id,
        p.section_id AS section_id,
        p.section_index AS section_index,
        p.scroll_offset AS scroll_offset,
        p.epub_cfi AS epub_cfi,
        p.updated_at_ms AS updated_at_ms,
        d.title AS document_title,
        d.doc_type AS document_type,
        c.title AS chapter_title,
        s.title AS section_title
      FROM cc_learning_reading_positions p
      JOIN cc_learning_documents d ON d.id = p.document_id
      JOIN cc_learning_chapters c ON c.id = p.chapter_id
      JOIN cc_learning_sections s ON s.id = p.section_id
      $typeWhere
      ORDER BY p.updated_at_ms DESC
      LIMIT 1
    ''', args);
    if (rows.isEmpty) return null;
    return CcReadingPosition.fromMap(rows.first);
  }

  Future<List<CcSearchHit>> search(String rawQuery, {int limit = 40, String? documentType}) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return const <CcSearchHit>[];
    final db = await _database();
    final rows = await db.rawQuery('''
      SELECT
        d.id AS document_id,
        d.title AS document_title,
        c.id AS chapter_id,
        c.title AS chapter_title,
        s.id AS section_id,
        s.title AS section_title,
        s.content AS section_content,
        s.keyword_csv AS section_keywords,
        c.keyword_csv AS chapter_keywords
      FROM cc_learning_sections s
      JOIN cc_learning_chapters c ON c.id = s.chapter_id
      JOIN cc_learning_documents d ON d.id = c.document_id
      ${documentType == null || documentType.trim().isEmpty ? '' : 'WHERE d.doc_type = ?'}
      ORDER BY d.updated_at_ms DESC, c.chapter_index ASC, s.section_index ASC
    ''', documentType == null || documentType.trim().isEmpty ? const <Object?>[] : <Object?>[documentType.trim()]);
    final hits = <CcSearchHit>[];
    for (final row in rows) {
      if (hits.length >= limit) break;
      final rawContent = (row['section_content'] ?? '').toString();
      final content = _contentForSearch(rawContent);
      final sectionTitle = (row['section_title'] ?? '').toString();
      final sectionKeywords = (row['section_keywords'] ?? '').toString();
      final chapterTitle = (row['chapter_title'] ?? '').toString();
      final chapterKeywords = (row['chapter_keywords'] ?? '').toString();
      final matchedContent = _findBestMatchingSentence(content, query);
      var offset = matchedContent?.offset ?? -1;
      var sentence = matchedContent?.sentence ?? '';
      if (matchedContent != null) {
        // 精确匹配优先，精确未命中时使用顺序字符、短语片段与字符覆盖度做语义近似匹配。
      } else if (_containsIgnoreCase(sectionTitle, query)) {
        offset = 0;
        sentence = sectionTitle;
      } else if (_containsIgnoreCase(sectionKeywords, query)) {
        offset = 0;
        sentence = '关键字：$sectionKeywords';
      } else if (_containsIgnoreCase(chapterTitle, query)) {
        offset = 0;
        sentence = chapterTitle;
      } else if (_containsIgnoreCase(chapterKeywords, query)) {
        offset = 0;
        sentence = '章节关键字：$chapterKeywords';
      } else {
        continue;
      }
      hits.add(CcSearchHit(
        documentId: ((row['document_id'] ?? 0) as num).toInt(),
        chapterId: ((row['chapter_id'] ?? 0) as num).toInt(),
        sectionId: row['section_id'] == null ? null : (row['section_id'] as num).toInt(),
        documentTitle: (row['document_title'] ?? '').toString(),
        chapterTitle: chapterTitle,
        sectionTitle: sectionTitle,
        sentence: sentence,
        query: query,
        offset: offset,
      ));
    }
    return hits;
  }
}



class _SentenceMatch {
  final String sentence;
  final int offset;
  final double score;

  const _SentenceMatch({required this.sentence, required this.offset, required this.score});
}

class _SentencePiece {
  final String text;
  final int offset;

  const _SentencePiece(this.text, this.offset);
}

_SentenceMatch? _findBestMatchingSentence(String content, String query) {
  final q = query.trim();
  if (content.trim().isEmpty || q.isEmpty) return null;

  final directOffset = _indexOfIgnoreCase(content, q);
  if (directOffset >= 0) {
    return _SentenceMatch(
      sentence: _extractMatchedSentence(content, q, directOffset),
      offset: directOffset,
      score: 1,
    );
  }

  _SentenceMatch? best;
  for (final piece in _splitSentences(content)) {
    final score = _semanticSentenceScore(piece.text, q);
    if (score < 0.72) continue;
    if (best == null || score > best.score) {
      best = _SentenceMatch(sentence: piece.text.trim(), offset: piece.offset, score: score);
    }
  }
  return best;
}

List<_SentencePiece> _splitSentences(String content) {
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final result = <_SentencePiece>[];
  var start = 0;
  final buffer = StringBuffer();
  for (var i = 0; i < normalized.length; i++) {
    final ch = normalized[i];
    if (buffer.isEmpty && ch.trim().isNotEmpty) start = i;
    buffer.write(ch);
    final shouldBreak = RegExp(r'[。！？!?；;\n]').hasMatch(ch) || buffer.length >= 180;
    if (shouldBreak) {
      final text = buffer.toString().trim();
      if (text.isNotEmpty) result.add(_SentencePiece(text, start));
      buffer.clear();
    }
  }
  final rest = buffer.toString().trim();
  if (rest.isNotEmpty) result.add(_SentencePiece(rest, start));
  return result.isEmpty && normalized.trim().isNotEmpty ? <_SentencePiece>[_SentencePiece(normalized.trim(), 0)] : result;
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

String _contentForSearch(String content) {
  final normalized = content
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  if (normalized.isEmpty) return '';
  final lines = normalized.split('\n');
  final originalIndex = lines.indexWhere((line) => RegExp(r'原文\s*直译\s*内容').hasMatch(line.trim()));
  if (originalIndex >= 0) return lines.sublist(originalIndex + 1).join('\n').trim();

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
      if (trimmed.isEmpty) skippingKeywords = false;
      continue;
    }
    result.add(line);
  }
  return result.join('\n').trim();
}

String _joinKeywords(List<String> keywords) {
  return keywords
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .join(',');
}

List<String> _splitKeywordCsv(String csv) {
  return csv
      .split(RegExp(r'[,，、\s]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

int _indexOfIgnoreCase(String source, String query) {
  if (query.isEmpty) return -1;
  final direct = source.indexOf(query);
  if (direct >= 0) return direct;
  return source.toLowerCase().indexOf(query.toLowerCase());
}


bool _containsIgnoreCase(String source, String query) {
  if (query.trim().isEmpty) return false;
  return source.contains(query) || source.toLowerCase().contains(query.toLowerCase());
}

String _extractMatchedSentence(String content, String query, int offset) {
  if (content.isEmpty) return '';
  final punctuation = RegExp(r'[。！？!?；;\n\r]');
  var start = offset;
  while (start > 0 && !punctuation.hasMatch(content[start - 1])) {
    start--;
  }
  var end = offset + query.length;
  while (end < content.length && !punctuation.hasMatch(content[end])) {
    end++;
  }
  if (end < content.length) end++;
  final sentence = content.substring(start, end).trim();
  if (sentence.length <= 180) return sentence;
  final localOffset = (offset - start).clamp(0, sentence.length);
  final windowStart = (localOffset - 70).clamp(0, sentence.length);
  final windowEnd = (localOffset + query.length + 90).clamp(0, sentence.length);
  return '${windowStart > 0 ? '…' : ''}${sentence.substring(windowStart, windowEnd)}${windowEnd < sentence.length ? '…' : ''}';
}
