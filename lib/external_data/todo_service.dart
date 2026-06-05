import 'dart:convert';

import 'package:http/http.dart' as http;

import 'onenote_service.dart';
import 'todo_dao.dart';
import 'todo_models.dart';

class TodoSyncResult {
  const TodoSyncResult({required this.lists, required this.tasks, required this.children});
  final int lists;
  final int tasks;
  final int children;
}

class TodoGraphService {
  TodoGraphService({TodoDao? dao, OneNoteAuthService? auth})
      : _dao = dao ?? TodoDao(),
        _auth = auth ?? OneNoteAuthService();

  final TodoDao _dao;
  final OneNoteAuthService _auth;
  static const String _base = 'https://graph.microsoft.com/v1.0';

  Future<TodoSyncResult> sync({String listName = '', String listId = '', void Function(String message)? onProgress}) async {
    await _dao.ensureTables();
    final token = await _auth.ensureAccessToken();
    final pendingMap = await _flushPendingLocalChanges(token, onProgress: onProgress);
    var targetListId = listId.trim();
    if (targetListId.isNotEmpty && pendingMap.containsKey(targetListId)) {
      targetListId = pendingMap[targetListId]!;
    }
    if (targetListId.isNotEmpty) {
      if (targetListId.startsWith('local_')) {
        throw Exception('当前列表仍未写回 Microsoft To Do。请先检查账号授权和网络，或在首页同步全部本地待写回内容。');
      }
      if (targetListId.startsWith('smart_')) return syncSmartView(smartListId: targetListId, onProgress: onProgress);
      onProgress?.call('正在精准读取当前 Microsoft To Do 任务列表...');
      Map<String, dynamic> list;
      try {
        list = await _requestJson(token: token, method: 'GET', url: '$_base/me/todo/lists/${Uri.encodeComponent(targetListId)}');
      } catch (e) {
        if (_looksLikeNotFound(e)) {
          await _dao.markRemoteListDeleted(targetListId);
          onProgress?.call('远端任务列表已被删除，已物理清理本地列表、任务及子结构镜像数据。');
          return const TodoSyncResult(lists: 0, tasks: 0, children: 0);
        }
        rethrow;
      }
      final r = await _syncOneList(token: token, list: list, onProgress: onProgress);
      onProgress?.call('当前任务列表同步完成：任务 ${r.tasks} 个，子结构 ${r.children} 条。');
      return r;
    }

    onProgress?.call('正在读取 Microsoft To Do 全部任务列表...');
    final lists = await _getJsonList(token, '$_base/me/todo/lists');
    var result = const TodoSyncResult(lists: 0, tasks: 0, children: 0);
    final targetName = listName.trim().toLowerCase();
    final targets = lists.where((l) {
      if (targetName.isEmpty) return true;
      return (l['displayName'] ?? '').toString().trim().toLowerCase() == targetName;
    }).toList();
    if (targets.isEmpty) {
      throw Exception(targetName.isEmpty ? '没有读取到 Microsoft To Do 任务列表。' : '没有找到名称为“$listName”的 Microsoft To Do 任务列表。');
    }
    for (final list in targets) {
      final r = await _syncOneList(token: token, list: list, onProgress: onProgress);
      result = TodoSyncResult(lists: result.lists + r.lists, tasks: result.tasks + r.tasks, children: result.children + r.children);
    }
    if (targetName.isEmpty) {
      await _dao.markRemoteListsDeleted(remoteListIds: lists.map((e) => (e['id'] ?? '').toString()).where((e) => e.isNotEmpty).toSet());
    }
    onProgress?.call('Microsoft To Do 同步完成：列表 ${result.lists} 个，任务 ${result.tasks} 个，子结构 ${result.children} 条。');
    return result;
  }

  Future<TodoSyncResult> syncSmartView({required String smartListId, void Function(String message)? onProgress}) async {
    await _dao.ensureTables();
    final title = switch (smartListId) {
      'smart_myday' => '我的一天',
      'smart_important' => '重要',
      'smart_planned' => '计划内',
      'smart_all' => '全部',
      'smart_completed' => '已完成',
      'smart_assigned' => '已分配给我',
      _ => '智能视图',
    };
    onProgress?.call('正在刷新“$title”本地智能视图...');
    if (smartListId == 'smart_all') {
      onProgress?.call('“全部”是跨列表视图。为避免在子页面误触发全量远端同步，本次只刷新本地已同步数据。');
    } else if (smartListId == 'smart_myday') {
      onProgress?.call('“我的一天”按本地标记及所选同步时区的今日到期/开始/提醒时间刷新；Microsoft To Do Graph v1.0 的 todoTask 暂未开放可读写的 My Day 标记。');
    } else {
      onProgress?.call('智能视图已刷新：当前页不会触发全量远端同步。');
    }
    return const TodoSyncResult(lists: 0, tasks: 0, children: 0);
  }

  Future<Map<String, String>> _flushPendingLocalChanges(String token, {void Function(String message)? onProgress}) async {
    final listIdMap = <String, String>{};
    final pendingLists = await _dao.pendingLocalLists();
    if (pendingLists.isNotEmpty) {
      onProgress?.call('发现本地待写回列表 ${pendingLists.length} 个，正在先写回 Microsoft To Do...');
    }
    for (final list in pendingLists) {
      if (list.isSmartView || list.localDeleted) continue;
      try {
        if (list.listId.startsWith('local_') || list.localStatus == 'pending_create') {
          final remote = await _postJson(token, '$_base/me/todo/lists', {
            'displayName': list.displayName.trim().isEmpty ? '未命名任务列表' : list.displayName.trim(),
          });
          final remoteId = (remote['id'] ?? '').toString();
          if (remoteId.isNotEmpty) {
            await _dao.replaceLocalListId(list.listId, remote);
            listIdMap[list.listId] = remoteId;
            onProgress?.call('本地列表“${list.displayName}”已写回 Microsoft To Do。');
          }
        } else if (list.localStatus == 'pending_update') {
          final remote = await _patchJson(token, '$_base/me/todo/lists/${Uri.encodeComponent(list.listId)}', {
            'displayName': list.displayName.trim().isEmpty ? '未命名任务列表' : list.displayName.trim(),
          });
          await _dao.upsertList(remote);
          onProgress?.call('列表“${list.displayName}”的本地修改已写回 Microsoft To Do。');
        }
      } catch (e) {
        await _dao.addApiLog(
          endpoint: list.listId.startsWith('local_') ? '$_base/me/todo/lists' : '$_base/me/todo/lists/${Uri.encodeComponent(list.listId)}',
          method: list.listId.startsWith('local_') ? 'POST' : 'PATCH',
          requestParams: jsonEncode({'displayName': list.displayName}),
          errorMessage: '写回本地待同步列表失败：$e',
        );
        rethrow;
      }
    }

    final pendingTasks = await _dao.pendingLocalTasks();
    if (pendingTasks.isNotEmpty) {
      onProgress?.call('发现本地待写回任务 ${pendingTasks.length} 个，正在先写回 Microsoft To Do...');
    }
    for (final task in pendingTasks) {
      if (task.localDeleted || task.listId.startsWith('smart_')) continue;
      try {
        var current = await _dao.getTask(task.taskId) ?? task;
        var remoteListId = current.listId;
        if (remoteListId.startsWith('local_')) {
          remoteListId = await _ensureRemoteList(token, remoteListId, onProgress: onProgress);
          current = await _dao.getTask(current.taskId) ?? current;
        }
        if (remoteListId.startsWith('local_') || remoteListId.startsWith('smart_')) {
          throw Exception('任务“${current.title}”所属列表尚未写回 Microsoft To Do，无法写回任务。');
        }
        if (current.taskId.startsWith('local_') || current.localStatus == 'pending_create') {
          final newId = await _createRemoteTaskFromLocal(token: token, task: current, listId: remoteListId);
          await _pushChecklistItemsForTask(token: token, listId: remoteListId, taskId: newId);
          onProgress?.call('本地任务“${current.title}”已写回 Microsoft To Do。');
        } else if (current.localStatus == 'pending_update') {
          final newId = await _patchRemoteTaskFromLocal(token: token, task: current, listId: remoteListId);
          await _pushChecklistItemsForTask(token: token, listId: remoteListId, taskId: newId);
          onProgress?.call('任务“${current.title}”的本地修改已写回 Microsoft To Do。');
        }
      } catch (e) {
        await _dao.addApiLog(
          endpoint: 'pending-local-task-sync',
          method: 'POST/PATCH',
          requestParams: jsonEncode({'taskId': task.taskId, 'listId': task.listId, 'title': task.title}),
          errorMessage: '写回本地待同步任务失败：$e',
        );
        rethrow;
      }
    }
    return listIdMap;
  }

  Future<String> _ensureRemoteList(String token, String listId, {void Function(String message)? onProgress}) async {
    if (!listId.startsWith('local_')) return listId;
    final list = await _dao.getList(listId);
    if (list == null) throw Exception('本地列表不存在，不能写回 Microsoft To Do。');
    final remote = await _postJson(token, '$_base/me/todo/lists', {
      'displayName': list.displayName.trim().isEmpty ? '未命名任务列表' : list.displayName.trim(),
    });
    final remoteId = (remote['id'] ?? '').toString();
    if (remoteId.isEmpty) throw Exception('Microsoft To Do 创建列表成功但未返回列表 ID。');
    await _dao.replaceLocalListId(listId, remote);
    onProgress?.call('本地列表“${list.displayName}”已写回 Microsoft To Do。');
    return remoteId;
  }

  Future<String> _createRemoteTaskFromLocal({required String token, required TodoTaskRecord task, required String listId}) async {
    final payload = _taskPayloadFromRecord(task, includeClears: false, syncRecurrence: true);
    final remote = await _postJson(token, '$_base/me/todo/lists/${Uri.encodeComponent(listId)}/tasks', payload);
    await _dao.replaceLocalTaskId(task.taskId, listId, remote);
    return (remote['id'] ?? task.taskId).toString();
  }

  Future<String> _patchRemoteTaskFromLocal({required String token, required TodoTaskRecord task, required String listId}) async {
    final payload = _taskPayloadFromRecord(task, includeClears: true, syncRecurrence: task.recurrenceJson.trim().isNotEmpty);
    final url = '$_base/me/todo/lists/${Uri.encodeComponent(listId)}/tasks/${Uri.encodeComponent(task.taskId)}';
    Map<String, dynamic> remote;
    try {
      remote = await _patchJson(token, url, payload);
    } catch (e) {
      if (!_looksLikeRecurrenceDateBug(e)) rethrow;
      await _dao.addApiLog(
        endpoint: url,
        method: 'PATCH',
        requestParams: jsonEncode(payload),
        errorMessage: 'Pending task recurrence PATCH Edm.Date error; fallback to create replacement task: $e',
      );
      return _replaceRemoteTaskAfterRecurrencePatchFailure(token: token, task: task, payload: payload, originalUrl: url);
    }
    await _dao.upsertTask(remote, listId: listId);
    return task.taskId;
  }

  Future<void> _pushChecklistItemsForTask({required String token, required String listId, required String taskId}) async {
    final items = await _dao.pendingChecklistItems(taskId: taskId);
    for (final item in items) {
      if (item.childType != 'checklistItem') continue;
      if (item.localDeleted) {
        if (!item.childId.startsWith('local_')) {
          await _delete(token, '$_base/me/todo/lists/${Uri.encodeComponent(listId)}/tasks/${Uri.encodeComponent(taskId)}/checklistItems/${Uri.encodeComponent(item.childId)}');
        }
        await _dao.removeChecklistItem(taskId: taskId, childId: item.childId);
        continue;
      }
      if (item.childId.startsWith('local_')) {
        final remote = await _postJson(
          token,
          '$_base/me/todo/lists/${Uri.encodeComponent(listId)}/tasks/${Uri.encodeComponent(taskId)}/checklistItems',
          {'displayName': item.title.trim().isEmpty ? '下一步' : item.title.trim(), 'isChecked': item.isChecked},
        );
        remote['list_id'] = listId;
        await _dao.replaceLocalChecklistItemId(taskId: taskId, oldChildId: item.childId, remote: remote);
      } else {
        await _patchJson(
          token,
          '$_base/me/todo/lists/${Uri.encodeComponent(listId)}/tasks/${Uri.encodeComponent(taskId)}/checklistItems/${Uri.encodeComponent(item.childId)}',
          {'displayName': item.title.trim().isEmpty ? '下一步' : item.title.trim(), 'isChecked': item.isChecked},
        );
      }
    }
  }

  Map<String, dynamic> _taskPayloadFromRecord(TodoTaskRecord task, {required bool includeClears, required bool syncRecurrence}) {
    return _taskPayload(
      title: task.title,
      bodyText: task.bodyText,
      status: task.status.trim().isEmpty ? 'notStarted' : task.status,
      importance: task.importance.trim().isEmpty ? 'normal' : task.importance,
      dueDateTime: task.dueDateTime,
      dueTimeZone: task.dueTimeZone.trim().isEmpty ? 'Asia/Shanghai' : task.dueTimeZone,
      startDateTime: task.startDateTime,
      startTimeZone: task.startTimeZone.trim().isEmpty ? 'Asia/Shanghai' : task.startTimeZone,
      isReminderOn: task.isReminderOn,
      reminderDateTime: task.reminderDateTime,
      reminderTimeZone: task.reminderTimeZone.trim().isEmpty ? 'Asia/Shanghai' : task.reminderTimeZone,
      recurrenceJson: task.recurrenceJson,
      categoriesJson: task.categoriesJson,
      includeClears: includeClears,
      syncRecurrence: syncRecurrence,
    );
  }
  Future<TodoSyncResult> _syncOneList({required String token, required Map<String, dynamic> list, void Function(String message)? onProgress}) async {
    final listId = (list['id'] ?? '').toString();
    if (listId.isEmpty) return const TodoSyncResult(lists: 0, tasks: 0, children: 0);
    await _dao.upsertList(list);
    final listTitle = (list['displayName'] ?? '未命名任务列表').toString();
    onProgress?.call('正在读取任务列表“$listTitle”的任务...');
    final taskMap = <String, Map<String, dynamic>>{};
    void addTasks(List<Map<String, dynamic>> rows) {
      for (final row in rows) {
        final id = (row['id'] ?? '').toString();
        if (id.isNotEmpty) taskMap[id] = row;
      }
    }

    addTasks(await _getJsonList(
      token,
      '$_base/me/todo/lists/${Uri.encodeComponent(listId)}/tasks?\$top=100',
    ));

    // Microsoft To Do 客户端会把已完成任务放在独立分组里；为保证首页“已完成”
    // 智能视图能拿到远端已完成任务，这里额外按 status=completed 再拉取一次，
    // 再用任务 id 去重。若某些账号/租户暂不支持该过滤，失败不会影响普通同步。
    try {
      addTasks(await _getJsonList(
        token,
        '$_base/me/todo/lists/${Uri.encodeComponent(listId)}/tasks?\$top=100&\$filter=status%20eq%20%27completed%27',
      ));
    } catch (e) {
      await _dao.addApiLog(
        endpoint: '$_base/me/todo/lists/${Uri.encodeComponent(listId)}/tasks?\$filter=status eq completed',
        method: 'GET',
        errorMessage: '读取已完成任务过滤视图失败，已继续普通同步：$e',
      );
    }

    final tasks = taskMap.values.toList();
    var taskCount = 0;
    var childCount = 0;
    var idx = 0;
    for (final task in tasks) {
      idx++;
      final taskId = (task['id'] ?? '').toString();
      if (taskId.isEmpty) continue;
      onProgress?.call('正在同步“$listTitle”任务 $idx/${tasks.length}：${task['title'] ?? ''}');
      await _dao.upsertTask(task, listId: listId);
      taskCount++;
      childCount += await _syncTaskChildren(token: token, listId: listId, taskId: taskId);
    }
    await _dao.markRemoteTasksDeletedForList(listId: listId, remoteTaskIds: taskMap.keys.toSet());
    return TodoSyncResult(lists: 1, tasks: taskCount, children: childCount);
  }

  Future<int> _syncTaskChildren({required String token, required String listId, required String taskId}) async {
    int count = 0;
    final base = '$_base/me/todo/lists/${Uri.encodeComponent(listId)}/tasks/${Uri.encodeComponent(taskId)}';
    final specs = <String, String>{
      'checklistItem': '$base/checklistItems',
      'attachment': '$base/attachments',
      'linkedResource': '$base/linkedResources',
    };
    for (final e in specs.entries) {
      try {
        final rows = await _getJsonList(token, e.value);
        await _dao.replaceChildren(listId: listId, taskId: taskId, childType: e.key, rows: rows);
        count += rows.length;
      } catch (err) {
        await _dao.addApiLog(endpoint: e.value, method: 'GET', errorMessage: err.toString());
      }
    }
    return count;
  }

  Future<String> createGroup({required String displayName}) async {
    return _dao.createLocalGroup(displayName);
  }

  Future<void> updateGroup({required String groupId, required String displayName}) async {
    await _dao.updateLocalGroup(groupId, displayName);
  }

  Future<void> deleteGroup({required String groupId}) async {
    await _dao.removeGroup(groupId);
  }

  Future<String> createList({
    required String displayName,
    bool writeBack = false,
    String groupId = '',
    String themeColor = '#5E72C3',
    String backgroundMode = 'color',
    String backgroundAsset = '',
    String backgroundLocalPath = '',
  }) async {
    final localId = await _dao.createLocalList(
      displayName,
      themeColor: themeColor,
      backgroundMode: backgroundMode,
      backgroundAsset: backgroundAsset,
      backgroundLocalPath: backgroundLocalPath,
    );
    if (groupId.trim().isNotEmpty) {
      await _dao.assignListToGroup(listId: localId, groupId: groupId.trim());
    }
    if (!writeBack) return localId;
    final token = await _auth.ensureAccessToken();
    final remote = await _postJson(token, '$_base/me/todo/lists', {'displayName': displayName.trim().isEmpty ? '未命名任务列表' : displayName.trim()});
    await _dao.replaceLocalListId(localId, remote);
    final remoteId = (remote['id'] ?? localId).toString();
    if (groupId.trim().isNotEmpty) {
      await _dao.assignListToGroup(listId: remoteId, groupId: groupId.trim());
    }
    return remoteId;
  }


  Future<String> updateList({
    required String listId,
    required String displayName,
    bool writeBack = false,
    String themeColor = '#5E72C3',
    String backgroundMode = 'color',
    String backgroundAsset = '',
    String backgroundLocalPath = '',
  }) async {
    if (listId.startsWith('smart_')) throw Exception('智能视图不是 Microsoft To Do 真实列表，不能重命名。');
    await _dao.updateLocalList(listId, displayName);
    await _dao.updateListAppearance(
      listId: listId,
      themeColor: themeColor,
      backgroundMode: backgroundMode,
      backgroundAsset: backgroundAsset,
      backgroundLocalPath: backgroundLocalPath,
    );
    if (!writeBack) return listId;
    final token = await _auth.ensureAccessToken();
    if (listId.startsWith('local_')) {
      return _ensureRemoteList(token, listId);
    }
    final remote = await _patchJson(token, '$_base/me/todo/lists/${Uri.encodeComponent(listId)}', {'displayName': displayName.trim().isEmpty ? '未命名任务列表' : displayName.trim()});
    await _dao.upsertList(remote);
    return (remote['id'] ?? listId).toString();
  }


  Future<void> deleteList({required String listId, bool writeBack = false}) async {
    if (listId.startsWith('smart_')) throw Exception('智能视图不是 Microsoft To Do 真实列表，不能删除。');
    if (writeBack && !listId.startsWith('local_')) {
      final token = await _auth.ensureAccessToken();
      await _delete(token, '$_base/me/todo/lists/${Uri.encodeComponent(listId)}');
    }
    // v26 起不再把本地删除长期保留成 local_deleted 僵尸数据：
    // 远端删除成功或仅本地删除时，列表、任务、步骤/附件/关联资源都物理清理。
    await _dao.removeList(listId);
  }

  Future<String> createTask({
    required String listId,
    required String title,
    required String bodyText,
    required String status,
    required String importance,
    String dueDateTime = '',
    String dueTimeZone = 'Asia/Shanghai',
    String startDateTime = '',
    String startTimeZone = 'Asia/Shanghai',
    bool isReminderOn = false,
    String reminderDateTime = '',
    String reminderTimeZone = 'Asia/Shanghai',
    String recurrenceJson = '',
    String categoriesJson = '',
    bool isMyDay = false,
    bool writeBack = false,
  }) async {
    var effectiveListId = listId;
    String? token;
    if (writeBack) {
      if (effectiveListId.startsWith('smart_')) throw Exception('智能视图不能直接新建远端任务，请先选择一个真实列表。');
      token = await _auth.ensureAccessToken();
      if (effectiveListId.startsWith('local_')) {
        effectiveListId = await _ensureRemoteList(token, effectiveListId);
      }
    }
    final localId = await _dao.createLocalTask(
      listId: effectiveListId,
      title: title,
      bodyText: bodyText,
      status: status,
      importance: importance,
      dueDateTime: dueDateTime,
      dueTimeZone: dueTimeZone,
      startDateTime: startDateTime,
      startTimeZone: startTimeZone,
      isReminderOn: isReminderOn,
      reminderDateTime: reminderDateTime,
      reminderTimeZone: reminderTimeZone,
      recurrenceJson: recurrenceJson,
      categoriesJson: categoriesJson,
      isMyDay: isMyDay,
    );
    if (!writeBack) return localId;
    token ??= await _auth.ensureAccessToken();
    final current = await _dao.getTask(localId);
    if (current == null) return localId;
    return _createRemoteTaskFromLocal(token: token, task: current, listId: effectiveListId);
  }


  Future<String> updateTask({
    required TodoTaskRecord task,
    required String title,
    required String bodyText,
    required String status,
    required String importance,
    required String dueDateTime,
    required String dueTimeZone,
    required String startDateTime,
    required String startTimeZone,
    required bool isReminderOn,
    required String reminderDateTime,
    required String reminderTimeZone,
    required String recurrenceJson,
    required String categoriesJson,
    required bool isMyDay,
    bool writeBack = false,
  }) async {
    await _dao.updateLocalTask(
      taskId: task.taskId,
      title: title,
      bodyText: bodyText,
      status: status,
      importance: importance,
      dueDateTime: dueDateTime,
      dueTimeZone: dueTimeZone,
      startDateTime: startDateTime,
      startTimeZone: startTimeZone,
      isReminderOn: isReminderOn,
      reminderDateTime: reminderDateTime,
      reminderTimeZone: reminderTimeZone,
      recurrenceJson: recurrenceJson,
      categoriesJson: categoriesJson,
      isMyDay: isMyDay,
    );
    if (!writeBack) return task.taskId;
    if (task.listId.startsWith('smart_')) throw Exception('智能视图任务不能直接更新远端，请先在真实列表中编辑。');
    final token = await _auth.ensureAccessToken();
    var remoteListId = task.listId;
    if (remoteListId.startsWith('local_')) {
      remoteListId = await _ensureRemoteList(token, remoteListId);
    }
    final currentAfterLocalSave = await _dao.getTask(task.taskId);
    final taskForRemote = currentAfterLocalSave ?? task;
    if (taskForRemote.taskId.startsWith('local_') || taskForRemote.localStatus == 'pending_create') {
      return _createRemoteTaskFromLocal(token: token, task: taskForRemote, listId: remoteListId);
    }
    final recurrenceChanged = recurrenceJson.trim() != taskForRemote.recurrenceJson.trim();
    final shouldSyncRecurrence = recurrenceChanged || (taskForRemote.localStatus != 'synced' && recurrenceJson.trim().isNotEmpty);
    final payload = _taskPayload(
      title: title,
      bodyText: bodyText,
      status: status,
      importance: importance,
      dueDateTime: dueDateTime,
      dueTimeZone: dueTimeZone,
      startDateTime: startDateTime,
      startTimeZone: startTimeZone,
      isReminderOn: isReminderOn,
      reminderDateTime: reminderDateTime,
      reminderTimeZone: reminderTimeZone,
      recurrenceJson: recurrenceJson,
      categoriesJson: categoriesJson,
      includeClears: true,
      syncRecurrence: shouldSyncRecurrence,
    );
    final url = '$_base/me/todo/lists/${Uri.encodeComponent(remoteListId)}/tasks/${Uri.encodeComponent(taskForRemote.taskId)}';
    Map<String, dynamic> remote;
    try {
      remote = await _patchJson(token, url, payload);
    } catch (e) {
      if (!shouldSyncRecurrence || !_looksLikeRecurrenceDateBug(e)) rethrow;
      await _dao.addApiLog(
        endpoint: url,
        method: 'PATCH',
        requestParams: jsonEncode(payload),
        errorMessage: 'Graph recurrence PATCH Edm.Date error; fallback to create replacement task: $e',
      );
      final replacementId = await _replaceRemoteTaskAfterRecurrencePatchFailure(
        token: token,
        task: taskForRemote,
        payload: payload,
        originalUrl: url,
      );
      return replacementId;
    }
    await _dao.upsertTask(remote, listId: remoteListId);
    return taskForRemote.taskId;
  }

  Future<String> _replaceRemoteTaskAfterRecurrencePatchFailure({
    required String token,
    required TodoTaskRecord task,
    required Map<String, dynamic> payload,
    required String originalUrl,
  }) async {
    final createUrl = '$_base/me/todo/lists/${Uri.encodeComponent(task.listId)}/tasks';
    final createPayload = Map<String, dynamic>.from(payload)
      ..removeWhere((_, value) => value == null);

    final remote = await _postJson(token, createUrl, createPayload);
    final newTaskId = (remote['id'] ?? '').toString();
    if (newTaskId.isEmpty) {
      throw Exception('重复规则 PATCH 失败后已尝试新建替代任务，但 Microsoft Graph 未返回新任务 ID。');
    }

    try {
      await _delete(token, originalUrl);
    } catch (e) {
      await _dao.addApiLog(
        endpoint: originalUrl,
        method: 'DELETE',
        errorMessage: 'Fallback replacement task was created ($newTaskId), but deleting the old task failed: $e',
      );
    }

    await _dao.replaceTaskWithRemoteDroppingChildren(
      oldTaskId: task.taskId,
      listId: task.listId,
      remote: remote,
    );
    return newTaskId;
  }



  Future<void> setTaskCompleted({
    required TodoTaskRecord task,
    required bool completed,
    bool writeBack = true,
  }) async {
    await _dao.updateTaskCompletion(taskId: task.taskId, completed: completed);
    if (!writeBack) return;
    if (task.listId.startsWith('smart_')) return;
    final token = await _auth.ensureAccessToken();
    var remoteListId = task.listId;
    if (remoteListId.startsWith('local_')) {
      remoteListId = await _ensureRemoteList(token, remoteListId);
    }
    final current = await _dao.getTask(task.taskId) ?? task;
    if (current.taskId.startsWith('local_') || current.localStatus == 'pending_create') {
      await _createRemoteTaskFromLocal(token: token, task: current, listId: remoteListId);
      return;
    }
    final payload = <String, dynamic>{'status': completed ? 'completed' : 'notStarted'};
    final remote = await _patchJson(
      token,
      '$_base/me/todo/lists/${Uri.encodeComponent(remoteListId)}/tasks/${Uri.encodeComponent(current.taskId)}',
      payload,
    );
    await _dao.upsertTask(remote, listId: remoteListId);
  }


  Future<void> deleteTask({required TodoTaskRecord task, bool writeBack = false}) async {
    if (writeBack && !task.taskId.startsWith('local_') && !task.listId.startsWith('local_')) {
      final token = await _auth.ensureAccessToken();
      await _delete(token, '$_base/me/todo/lists/${Uri.encodeComponent(task.listId)}/tasks/${Uri.encodeComponent(task.taskId)}');
    }
    // v26 起任务删除使用物理级联删除，避免计划内/全部/重要/我的一天/已完成等视图被僵尸数据污染。
    await _dao.removeTask(task.taskId);
  }


  Future<void> saveChecklistItems({
    required String listId,
    required String taskId,
    required List<Map<String, dynamic>> items,
    bool writeBack = false,
  }) async {
    for (final item in items) {
      final childId = (item['childId'] ?? '').toString();
      final title = (item['title'] ?? '').toString().trim();
      final isChecked = item['isChecked'] == true;
      final deleted = item['deleted'] == true;
      if (childId.isEmpty && title.isEmpty) continue;
      if (deleted) {
        if (childId.isNotEmpty && writeBack && !childId.startsWith('local_') && !taskId.startsWith('local_') && !listId.startsWith('local_')) {
          final token = await _auth.ensureAccessToken();
          await _delete(token, '$_base/me/todo/lists/${Uri.encodeComponent(listId)}/tasks/${Uri.encodeComponent(taskId)}/checklistItems/${Uri.encodeComponent(childId)}');
        }
        if (childId.isNotEmpty) {
          await _dao.removeChecklistItem(taskId: taskId, childId: childId);
        }
        continue;
      }
      final localChildId = await _dao.upsertLocalChecklistItem(
        listId: listId,
        taskId: taskId,
        childId: childId,
        title: title.isEmpty ? '下一步' : title,
        isChecked: isChecked,
      );
      if (!writeBack || taskId.startsWith('local_') || listId.startsWith('local_') || listId.startsWith('smart_')) continue;
      final token = await _auth.ensureAccessToken();
      if (localChildId.startsWith('local_')) {
        final remote = await _postJson(
          token,
          '$_base/me/todo/lists/${Uri.encodeComponent(listId)}/tasks/${Uri.encodeComponent(taskId)}/checklistItems',
          {'displayName': title.isEmpty ? '下一步' : title, 'isChecked': isChecked},
        );
        remote['list_id'] = listId;
        await _dao.replaceLocalChecklistItemId(taskId: taskId, oldChildId: localChildId, remote: remote);
      } else {
        await _patchJson(
          token,
          '$_base/me/todo/lists/${Uri.encodeComponent(listId)}/tasks/${Uri.encodeComponent(taskId)}/checklistItems/${Uri.encodeComponent(localChildId)}',
          {'displayName': title.isEmpty ? '下一步' : title, 'isChecked': isChecked},
        );
      }
    }
  }
  Map<String, dynamic> _taskPayload({
    required String title,
    required String bodyText,
    required String status,
    required String importance,
    required String dueDateTime,
    required String dueTimeZone,
    required String startDateTime,
    required String startTimeZone,
    required bool isReminderOn,
    required String reminderDateTime,
    required String reminderTimeZone,
    required String recurrenceJson,
    required String categoriesJson,
    required bool includeClears,
    bool syncRecurrence = true,
  }) {
    final payload = <String, dynamic>{
      'title': title.trim().isEmpty ? '未命名任务' : title.trim(),
      'body': {'content': _textToHtml(bodyText), 'contentType': 'html'},
      'status': status,
      'importance': importance,
      'isReminderOn': isReminderOn,
    };
    _putDateTime(payload, 'dueDateTime', dueDateTime, dueTimeZone, includeClears);
    _putDateTime(payload, 'startDateTime', startDateTime, startTimeZone, includeClears);
    _putDateTime(payload, 'reminderDateTime', reminderDateTime, reminderTimeZone, includeClears);
    if (syncRecurrence) {
      if (recurrenceJson.trim().isNotEmpty) {
        payload['recurrence'] = _recurrencePayload(
          recurrenceJson: recurrenceJson,
          dueDateTime: dueDateTime,
          dueTimeZone: dueTimeZone,
        );
      } else if (includeClears) {
        payload['recurrence'] = null;
      }
    }
    if (categoriesJson.trim().isNotEmpty) {
      payload['categories'] = _parseCategories(categoriesJson);
    } else if (includeClears) {
      payload['categories'] = <String>[];
    }
    return payload;
  }

  void _putDateTime(Map<String, dynamic> payload, String key, String value, String timeZone, bool includeClears) {
    final v = _normalizeGraphDateTime(value);
    if (v.isNotEmpty) {
      payload[key] = {'dateTime': v, 'timeZone': timeZone.trim().isEmpty ? 'Asia/Shanghai' : timeZone.trim()};
    } else if (includeClears) {
      payload[key] = null;
    }
  }

  String _normalizeGraphDateTime(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    final normalized = s.contains(' ') && !s.contains('T') ? s.replaceFirst(' ', 'T') : s;
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return normalized;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)}T${two(parsed.hour)}:${two(parsed.minute)}:${two(parsed.second)}';
  }

  Map<String, dynamic> _recurrencePayload({
    required String recurrenceJson,
    required String dueDateTime,
    required String dueTimeZone,
  }) {
    dynamic decoded;
    try {
      decoded = jsonDecode(recurrenceJson);
    } catch (_) {
      throw Exception('重复 recurrence JSON 格式不正确，请输入有效 JSON 或留空。');
    }
    if (decoded is! Map) {
      throw Exception('重复 recurrence JSON 必须是对象，格式为 {"pattern": {...}, "range": {...}}。');
    }

    final rawPattern = decoded['pattern'];
    final rawRange = decoded['range'];
    if (rawPattern is! Map || rawRange is! Map) {
      throw Exception('重复 recurrence JSON 必须同时包含 pattern 和 range。');
    }

    final pattern = Map<String, dynamic>.from(rawPattern);
    final range = Map<String, dynamic>.from(rawRange);

    pattern.remove('@odata.type');
    range.remove('@odata.type');
    _removeEmptyValues(pattern);
    _removeEmptyValues(range);

    final type = (pattern['type'] ?? '').toString().trim();
    if (type.isEmpty) throw Exception('重复 pattern.type 不能为空。');

    final interval = int.tryParse((pattern['interval'] ?? '1').toString()) ?? 1;
    pattern['interval'] = interval < 1 ? 1 : interval;

    if (type == 'daily') {
      pattern.remove('daysOfWeek');
      pattern.remove('firstDayOfWeek');
      pattern.remove('index');
      pattern.remove('dayOfMonth');
      pattern.remove('month');
    } else if (type == 'weekly') {
      final days = pattern['daysOfWeek'];
      if (days is! List || days.isEmpty) {
        final due = _parseLocalDateTime(dueDateTime) ?? DateTime.now();
        pattern['daysOfWeek'] = <String>[_graphWeekday(due.weekday)];
      }
      pattern['firstDayOfWeek'] = (pattern['firstDayOfWeek'] ?? 'sunday').toString();
      pattern.remove('index');
      pattern.remove('dayOfMonth');
      pattern.remove('month');
    } else if (type == 'absoluteMonthly') {
      final due = _parseLocalDateTime(dueDateTime) ?? DateTime.now();
      final day = int.tryParse((pattern['dayOfMonth'] ?? '').toString()) ?? due.day;
      pattern['dayOfMonth'] = day.clamp(1, 31);
      pattern.remove('daysOfWeek');
      pattern.remove('firstDayOfWeek');
      pattern.remove('index');
      pattern.remove('month');
    } else if (type == 'absoluteYearly') {
      final due = _parseLocalDateTime(dueDateTime) ?? DateTime.now();
      final day = int.tryParse((pattern['dayOfMonth'] ?? '').toString()) ?? due.day;
      final month = int.tryParse((pattern['month'] ?? '').toString()) ?? due.month;
      pattern['dayOfMonth'] = day.clamp(1, 31);
      pattern['month'] = month.clamp(1, 12);
      pattern.remove('daysOfWeek');
      pattern.remove('firstDayOfWeek');
      pattern.remove('index');
    }

    final due = _parseLocalDateTime(dueDateTime) ?? DateTime.now();
    final rangeType = (range['type'] ?? 'noEnd').toString().trim();
    range['type'] = <String>{'noEnd', 'endDate', 'numbered'}.contains(rangeType) ? rangeType : 'noEnd';
    range['startDate'] = _dateOnly((range['startDate'] ?? '').toString(), fallback: due);
    final tz = (range['recurrenceTimeZone'] ?? dueTimeZone).toString().trim();
    range['recurrenceTimeZone'] = tz.isEmpty ? 'Asia/Shanghai' : tz;

    if (range['type'] == 'noEnd') {
      range.remove('endDate');
      range.remove('numberOfOccurrences');
    } else if (range['type'] == 'endDate') {
      range['endDate'] = _dateOnly((range['endDate'] ?? '').toString(), fallback: due);
      range.remove('numberOfOccurrences');
    } else if (range['type'] == 'numbered') {
      final count = int.tryParse((range['numberOfOccurrences'] ?? '').toString()) ?? 1;
      range['numberOfOccurrences'] = count < 1 ? 1 : count;
      range.remove('endDate');
    }

    return {'pattern': pattern, 'range': range};
  }

  void _removeEmptyValues(Map<String, dynamic> value) {
    value.removeWhere((_, v) {
      if (v == null) return true;
      if (v is String && v.trim().isEmpty) return true;
      if (v is List && v.isEmpty) return true;
      return false;
    });
  }

  DateTime? _parseLocalDateTime(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final normalized = s.contains(' ') && !s.contains('T') ? s.replaceFirst(' ', 'T') : s;
    return DateTime.tryParse(normalized);
  }

  String _dateOnly(String raw, {required DateTime fallback}) {
    final s = raw.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return s;
    final parsed = _parseLocalDateTime(s);
    final dt = parsed ?? fallback;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  String _graphWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      case DateTime.saturday:
        return 'saturday';
      default:
        return 'sunday';
    }
  }

  List<String> _parseCategories(String raw) {
    final s = raw.trim();
    if (s.startsWith('[')) {
      final decoded = jsonDecode(s);
      if (decoded is List) return decoded.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  String _textToHtml(String text) {
    final escaped = const HtmlEscape().convert(text);
    return escaped.replaceAll('\n', '<br>');
  }

  Future<List<Map<String, dynamic>>> _getJsonList(String token, String url) async {
    final out = <Map<String, dynamic>>[];
    String? nextUrl = url;
    while (nextUrl != null && nextUrl.isNotEmpty) {
      final obj = await _requestJson(token: token, method: 'GET', url: nextUrl);
      final value = obj['value'];
      if (value is List) {
        for (final item in value) {
          if (item is Map) out.add(Map<String, dynamic>.from(item));
        }
      }
      nextUrl = obj['@odata.nextLink']?.toString();
    }
    return out;
  }

  bool _looksLikeNotFound(Object e) {
    final text = e.toString().toLowerCase();
    return text.contains('404') || text.contains('notfound') || text.contains('not found') || text.contains('erroritemnotfound');
  }

  bool _looksLikeRecurrenceDateBug(Object e) {
    final text = e.toString().toLowerCase();
    return text.contains('microsoft.odata.edm.date') || text.contains('recurrence.range.startdate') || text.contains('recurrence.range.enddate');
  }

  Future<Map<String, dynamic>> _postJson(String token, String url, Map<String, dynamic> payload) => _requestJson(token: token, method: 'POST', url: url, payload: payload);
  Future<Map<String, dynamic>> _patchJson(String token, String url, Map<String, dynamic> payload) => _requestJson(token: token, method: 'PATCH', url: url, payload: payload);

  Future<void> _delete(String token, String url) async {
    final resp = await http.delete(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
    final body = _decodeBody(resp.bodyBytes);
    await _dao.addApiLog(endpoint: url, method: 'DELETE', statusCode: resp.statusCode, responseBody: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) throw Exception('Microsoft To Do 删除失败：${resp.statusCode} $body');
  }

  Future<Map<String, dynamic>> _requestJson({required String token, required String method, required String url, Map<String, dynamic>? payload}) async {
    try {
      final uri = Uri.parse(url);
      final preferredTimeZone = await _dao.getPreferredTimeZone();
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Prefer': 'outlook.timezone="${preferredTimeZone.trim().isEmpty ? 'Asia/Shanghai' : preferredTimeZone.trim()}"',
      };
      late final http.Response resp;
      if (method == 'POST') {
        resp = await http.post(uri, headers: headers, body: jsonEncode(payload ?? <String, dynamic>{}));
      } else if (method == 'PATCH') {
        resp = await http.patch(uri, headers: headers, body: jsonEncode(payload ?? <String, dynamic>{}));
      } else {
        resp = await http.get(uri, headers: headers);
      }
      final body = _decodeBody(resp.bodyBytes);
      await _dao.addApiLog(endpoint: url, method: method, requestParams: payload == null ? null : jsonEncode(payload), responseBody: body, statusCode: resp.statusCode);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('Microsoft To Do API 请求失败：${resp.statusCode} $body');
      }
      if (body.trim().isEmpty) return <String, dynamic>{};
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      await _dao.addApiLog(endpoint: url, method: method, requestParams: payload == null ? null : jsonEncode(payload), errorMessage: e.toString());
      rethrow;
    }
  }
}

String _decodeBody(List<int> bytes) => utf8.decode(bytes, allowMalformed: true);
