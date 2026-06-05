class OneNoteNotebookRecord {
  const OneNoteNotebookRecord({
    required this.id,
    required this.displayName,
    required this.createdTime,
    required this.lastModifiedTime,
    required this.sectionCount,
    required this.pageCount,
  });

  final String id;
  final String displayName;
  final String createdTime;
  final String lastModifiedTime;
  final int sectionCount;
  final int pageCount;

  factory OneNoteNotebookRecord.fromMap(Map<String, Object?> row) {
    return OneNoteNotebookRecord(
      id: (row['id'] ?? '').toString(),
      displayName: (row['display_name'] ?? '').toString(),
      createdTime: (row['created_time'] ?? '').toString(),
      lastModifiedTime: (row['last_modified_time'] ?? '').toString(),
      sectionCount: _toInt(row['section_count']),
      pageCount: _toInt(row['page_count']),
    );
  }
}

class OneNoteSectionRecord {
  const OneNoteSectionRecord({
    required this.id,
    required this.notebookId,
    required this.displayName,
    required this.createdTime,
    required this.lastModifiedTime,
    required this.pageCount,
  });

  final String id;
  final String notebookId;
  final String displayName;
  final String createdTime;
  final String lastModifiedTime;
  final int pageCount;

  factory OneNoteSectionRecord.fromMap(Map<String, Object?> row) {
    return OneNoteSectionRecord(
      id: (row['id'] ?? '').toString(),
      notebookId: (row['notebook_id'] ?? '').toString(),
      displayName: (row['display_name'] ?? '').toString(),
      createdTime: (row['created_time'] ?? '').toString(),
      lastModifiedTime: (row['last_modified_time'] ?? '').toString(),
      pageCount: _toInt(row['page_count']),
    );
  }
}

class OneNotePageRecord {
  const OneNotePageRecord({
    required this.id,
    required this.notebookId,
    required this.sectionId,
    required this.title,
    required this.createdTime,
    required this.lastModifiedTime,
    required this.plainText,
    required this.htmlContent,
    required this.attachmentCount,
  });

  final String id;
  final String notebookId;
  final String sectionId;
  final String title;
  final String createdTime;
  final String lastModifiedTime;
  final String plainText;
  final String htmlContent;
  final int attachmentCount;

  factory OneNotePageRecord.fromMap(Map<String, Object?> row) {
    return OneNotePageRecord(
      id: (row['id'] ?? '').toString(),
      notebookId: (row['notebook_id'] ?? '').toString(),
      sectionId: (row['section_id'] ?? '').toString(),
      title: (row['title'] ?? '').toString(),
      createdTime: (row['created_time'] ?? '').toString(),
      lastModifiedTime: (row['last_modified_time'] ?? '').toString(),
      plainText: (row['plain_text'] ?? '').toString(),
      htmlContent: (row['html_content'] ?? '').toString(),
      attachmentCount: _toInt(row['attachment_count']),
    );
  }
}

class OneNoteAttachmentRecord {
  const OneNoteAttachmentRecord({
    required this.id,
    required this.pageId,
    required this.resourceId,
    required this.fileName,
    required this.mimeType,
    required this.remoteUrl,
    required this.localPath,
    required this.sizeBytes,
  });

  final int id;
  final String pageId;
  final String resourceId;
  final String fileName;
  final String mimeType;
  final String remoteUrl;
  final String localPath;
  final int sizeBytes;

  factory OneNoteAttachmentRecord.fromMap(Map<String, Object?> row) {
    return OneNoteAttachmentRecord(
      id: _toInt(row['id']),
      pageId: (row['page_id'] ?? '').toString(),
      resourceId: (row['resource_id'] ?? '').toString(),
      fileName: (row['file_name'] ?? '').toString(),
      mimeType: (row['mime_type'] ?? '').toString(),
      remoteUrl: (row['remote_url'] ?? '').toString(),
      localPath: (row['local_path'] ?? '').toString(),
      sizeBytes: _toInt(row['size_bytes']),
    );
  }
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
