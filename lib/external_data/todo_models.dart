int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class TodoUnsyncedSummary {
  const TodoUnsyncedSummary({required this.lists, required this.tasks, required this.children});

  final int lists;
  final int tasks;
  final int children;

  int get total => lists + tasks + children;
  bool get hasAny => total > 0;

  String get label {
    final parts = <String>[];
    if (lists > 0) parts.add('列表 $lists 个');
    if (tasks > 0) parts.add('任务 $tasks 个');
    if (children > 0) parts.add('步骤 $children 条');
    return parts.isEmpty ? '无本地待同步数据' : parts.join('，');
  }
}


class TodoGroupRecord {
  const TodoGroupRecord({
    required this.groupId,
    required this.displayName,
    required this.remoteGroupId,
    required this.sortOrder,
    required this.listCount,
    required this.localStatus,
    required this.localDeleted,
    required this.syncedAtMs,
  });

  final String groupId;
  final String displayName;
  final String remoteGroupId;
  final int sortOrder;
  final int listCount;
  final String localStatus;
  final bool localDeleted;
  final int syncedAtMs;

  bool get isLocalOnly => groupId.startsWith('local_');

  factory TodoGroupRecord.fromMap(Map<String, Object?> row) => TodoGroupRecord(
        groupId: (row['group_id'] ?? '').toString(),
        displayName: (row['display_name'] ?? '').toString(),
        remoteGroupId: (row['remote_group_id'] ?? '').toString(),
        sortOrder: _toInt(row['sort_order']),
        listCount: _toInt(row['list_count']),
        localStatus: (row['local_status'] ?? '').toString(),
        localDeleted: _toInt(row['local_deleted']) == 1,
        syncedAtMs: _toInt(row['synced_at_ms']),
      );
}

class TodoListRecord {
  const TodoListRecord({
    required this.listId,
    required this.displayName,
    required this.wellknownListName,
    required this.isOwner,
    required this.isShared,
    required this.taskCount,
    required this.openTaskCount,
    required this.completedTaskCount,
    this.themeColor = '#5E72C3',
    this.backgroundMode = 'color',
    this.backgroundAsset = '',
    this.backgroundLocalPath = '',
    required this.localStatus,
    required this.localDeleted,
    required this.syncedAtMs,
  });

  final String listId;
  final String displayName;
  final String wellknownListName;
  final bool isOwner;
  final bool isShared;
  final int taskCount;
  final int openTaskCount;
  final int completedTaskCount;
  final String themeColor;
  final String backgroundMode;
  final String backgroundAsset;
  final String backgroundLocalPath;
  final String localStatus;
  final bool localDeleted;
  final int syncedAtMs;

  bool get isLocalOnly => listId.startsWith('local_');
  bool get isSmartView => listId.startsWith('smart_');

  factory TodoListRecord.fromMap(Map<String, Object?> row) => TodoListRecord(
        listId: (row['list_id'] ?? '').toString(),
        displayName: (row['display_name'] ?? '').toString(),
        wellknownListName: (row['wellknown_list_name'] ?? '').toString(),
        isOwner: _toInt(row['is_owner']) == 1,
        isShared: _toInt(row['is_shared']) == 1,
        taskCount: _toInt(row['task_count']),
        openTaskCount: _toInt(row['open_task_count']),
        completedTaskCount: _toInt(row['completed_task_count']),
        themeColor: (row['theme_color'] ?? '#5E72C3').toString(),
        backgroundMode: (row['background_mode'] ?? 'color').toString(),
        backgroundAsset: (row['background_asset'] ?? '').toString(),
        backgroundLocalPath: (row['background_local_path'] ?? '').toString(),
        localStatus: (row['local_status'] ?? '').toString(),
        localDeleted: _toInt(row['local_deleted']) == 1,
        syncedAtMs: _toInt(row['synced_at_ms']),
      );
}

class TodoTaskRecord {
  const TodoTaskRecord({
    required this.taskId,
    required this.listId,
    this.listDisplayName = '',
    required this.title,
    required this.bodyText,
    required this.bodyHtml,
    required this.bodyContentType,
    required this.status,
    required this.importance,
    required this.createdDateTime,
    required this.lastModifiedDateTime,
    required this.dueDateTime,
    required this.dueTimeZone,
    required this.startDateTime,
    required this.startTimeZone,
    required this.isReminderOn,
    required this.isMyDay,
    required this.reminderDateTime,
    required this.reminderTimeZone,
    required this.completedDateTime,
    required this.recurrenceJson,
    required this.categoriesJson,
    required this.hasAttachments,
    required this.checklistCount,
    required this.attachmentCount,
    required this.linkedResourceCount,
    required this.localStatus,
    required this.localDeleted,
    required this.syncedAtMs,
  });

  final String taskId;
  final String listId;
  final String listDisplayName;
  final String title;
  final String bodyText;
  final String bodyHtml;
  final String bodyContentType;
  final String status;
  final String importance;
  final String createdDateTime;
  final String lastModifiedDateTime;
  final String dueDateTime;
  final String dueTimeZone;
  final String startDateTime;
  final String startTimeZone;
  final bool isReminderOn;
  final bool isMyDay;
  final String reminderDateTime;
  final String reminderTimeZone;
  final String completedDateTime;
  final String recurrenceJson;
  final String categoriesJson;
  final bool hasAttachments;
  final int checklistCount;
  final int attachmentCount;
  final int linkedResourceCount;
  final String localStatus;
  final bool localDeleted;
  final int syncedAtMs;

  bool get isLocalOnly => taskId.startsWith('local_');
  bool get isCompleted => status == 'completed';

  factory TodoTaskRecord.fromMap(Map<String, Object?> row) => TodoTaskRecord(
        taskId: (row['task_id'] ?? '').toString(),
        listId: (row['list_id'] ?? '').toString(),
        listDisplayName: (row['list_display_name'] ?? '').toString(),
        title: (row['title'] ?? '').toString(),
        bodyText: (row['body_text'] ?? '').toString(),
        bodyHtml: (row['body_html'] ?? '').toString(),
        bodyContentType: (row['body_content_type'] ?? '').toString(),
        status: (row['status'] ?? '').toString(),
        importance: (row['importance'] ?? '').toString(),
        createdDateTime: (row['created_date_time'] ?? '').toString(),
        lastModifiedDateTime: (row['last_modified_date_time'] ?? '').toString(),
        dueDateTime: (row['due_date_time'] ?? '').toString(),
        dueTimeZone: (row['due_time_zone'] ?? '').toString(),
        startDateTime: (row['start_date_time'] ?? '').toString(),
        startTimeZone: (row['start_time_zone'] ?? '').toString(),
        isReminderOn: _toInt(row['is_reminder_on']) == 1,
        isMyDay: _toInt(row['is_my_day']) == 1,
        reminderDateTime: (row['reminder_date_time'] ?? '').toString(),
        reminderTimeZone: (row['reminder_time_zone'] ?? '').toString(),
        completedDateTime: (row['completed_date_time'] ?? '').toString(),
        recurrenceJson: (row['recurrence_json'] ?? '').toString(),
        categoriesJson: (row['categories_json'] ?? '').toString(),
        hasAttachments: _toInt(row['has_attachments']) == 1,
        checklistCount: _toInt(row['checklist_count']),
        attachmentCount: _toInt(row['attachment_count']),
        linkedResourceCount: _toInt(row['linked_resource_count']),
        localStatus: (row['local_status'] ?? '').toString(),
        localDeleted: _toInt(row['local_deleted']) == 1,
        syncedAtMs: _toInt(row['synced_at_ms']),
      );
}

class TodoChildRecord {
  const TodoChildRecord({
    required this.id,
    required this.listId,
    required this.taskId,
    required this.childType,
    required this.childId,
    required this.title,
    required this.content,
    required this.isChecked,
    required this.remoteUrl,
    required this.localPath,
    required this.rawJson,
    required this.localStatus,
    required this.localDeleted,
  });

  final int id;
  final String listId;
  final String taskId;
  final String childType;
  final String childId;
  final String title;
  final String content;
  final bool isChecked;
  final String remoteUrl;
  final String localPath;
  final String rawJson;
  final String localStatus;
  final bool localDeleted;

  bool get isLocalOnly => childId.startsWith('local_');

  factory TodoChildRecord.fromMap(Map<String, Object?> row) => TodoChildRecord(
        id: _toInt(row['id']),
        listId: (row['list_id'] ?? '').toString(),
        taskId: (row['task_id'] ?? '').toString(),
        childType: (row['child_type'] ?? '').toString(),
        childId: (row['child_id'] ?? '').toString(),
        title: (row['title'] ?? '').toString(),
        content: (row['content'] ?? '').toString(),
        isChecked: _toInt(row['is_checked']) == 1,
        remoteUrl: (row['remote_url'] ?? '').toString(),
        localPath: (row['local_path'] ?? '').toString(),
        rawJson: (row['raw_json'] ?? '').toString(),
        localStatus: (row['local_status'] ?? '').toString(),
        localDeleted: _toInt(row['local_deleted']) == 1,
      );
}
