import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'todo_dao.dart';
import 'todo_models.dart';
import 'todo_service.dart';
import 'todo_goal_pages.dart';
import '../sustainable_excellence/sustainable_excellence_home_page.dart';

const _todoBlue = Color(0xFF5E72C3);
const _todoBg = Color(0xFFF7F7FA);

const _todoListColors = <String>[
  '#5E72C3',
  '#497D74',
  '#C24B78',
  '#7C5CC4',
  '#4F9462',
  '#B06A2C',
  '#2E4057',
];

const _todoPhotoAssets = <String>[
  'assets/todo_bg/beach_mist.jpg',
  'assets/todo_bg/forest_light.jpg',
  'assets/todo_bg/rose_plain.jpg',
  'assets/todo_bg/night_lake.jpg',
  'assets/todo_bg/sunset_coast.jpg',
  'assets/todo_bg/deep_blue.jpg',
];

Color _hexColor(String hex, {Color fallback = _todoBlue}) {
  var s = hex.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  final v = int.tryParse(s, radix: 16);
  return v == null ? fallback : Color(v);
}

bool _todoListUsesImage(TodoListRecord? list) {
  final mode = (list?.backgroundMode ?? '').trim();
  return mode == 'asset_photo' || mode == 'local_photo';
}

Color _todoListThemeColor(TodoListRecord? list) {
  return _hexColor(list?.themeColor ?? '#5E72C3');
}

ImageProvider? _todoListBackgroundImage(TodoListRecord? list) {
  if (list == null) return null;
  if (list.backgroundMode == 'asset_photo' && list.backgroundAsset.trim().isNotEmpty) {
    return AssetImage(list.backgroundAsset.trim());
  }
  if (list.backgroundMode == 'local_photo' && list.backgroundLocalPath.trim().isNotEmpty) {
    final file = File(list.backgroundLocalPath.trim());
    if (file.existsSync()) return FileImage(file);
  }
  return null;
}

List<Shadow> _todoReadableTextShadow() => const [
      Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 2)),
      Shadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 4)),
    ];


class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final _dao = TodoDao();
  late final _service = TodoGraphService(dao: _dao);
  final _listNameCtrl = TextEditingController();
  bool _busy = false;
  String _status = '';
  List<TodoListRecord> _smartLists = [];
  List<TodoListRecord> _realLists = [];
  List<TodoGroupRecord> _groups = [];
  Map<String, String> _listGroupAssignments = {};
  bool _showSync = false;
  String _preferredTimeZone = 'Asia/Shanghai';
  TodoUnsyncedSummary _unsynced = const TodoUnsyncedSummary(lists: 0, tasks: 0, children: 0);

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(auto: true);
    });
  }

  @override
  void dispose() {
    _listNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _dao.ensureTables();
    final smartRows = await _dao.smartLists();
    final rows = await _dao.listLists();
    final groups = await _dao.listGroups();
    final assignments = await _dao.listGroupAssignments();
    final preferredTimeZone = await _dao.getPreferredTimeZone();
    final unsynced = await _dao.unsyncedSummary();
    if (!mounted) return;
    setState(() {
      _smartLists = smartRows;
      _realLists = rows;
      _groups = groups;
      _listGroupAssignments = assignments;
      _preferredTimeZone = _normalizeSupportedTimeZone(preferredTimeZone);
      _unsynced = unsynced;
    });
  }

  Future<void> _sync({bool auto = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = auto ? '正在自动同步 Microsoft To Do 数据...' : '准备同步 Microsoft To Do...';
    });
    _showSyncMessage(_status);
    try {
      final r = await _service.sync(
        listName: _listNameCtrl.text.trim(),
        onProgress: (m) {
          if (!mounted) return;
          setState(() => _status = m);
        },
      );
      await _load();
      if (!mounted) return;
      final msg = '同步成功：任务列表 ${r.lists} 个，任务 ${r.tasks} 个，步骤/附件/关联资源 ${r.children} 条。';
      setState(() => _status = msg);
      _showSyncMessage(msg);
    } catch (e) {
      await _load();
      if (!mounted) return;
      final msg = '同步失败：$e';
      setState(() => _status = msg);
      _showSyncMessage(msg, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSyncMessage(String message, {bool isError = false}) {
    if (!mounted || message.trim().isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  Future<void> _createList({String groupId = ''}) async {
    final result = await Navigator.push<Object?>(context, MaterialPageRoute(builder: (_) => TodoListEditPage(groupId: groupId)));
    await _load();
    if (!mounted) return;
    if (result is String && result.trim().isNotEmpty) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => TodoListPage(listId: result.trim())));
      if (mounted) await _load();
    }
  }

  Future<void> _createGroup() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const TodoGroupEditPage()));
    if (ok == true) await _load();
  }

  Future<void> _editGroup(TodoGroupRecord group) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => TodoGroupEditPage(group: group)));
    if (ok == true) await _load();
  }

  Future<void> _changePreferredTimeZone(String? value) async {
    if (value == null) return;
    final normalized = _normalizeSupportedTimeZone(value);
    await _dao.setPreferredTimeZone(normalized);
    if (!mounted) return;
    setState(() => _preferredTimeZone = normalized);
    _showSyncMessage('To Do 同步时区已切换为 ${_timeZoneLabel(normalized)}');
  }

  Future<void> _deleteGroup(TodoGroupRecord group) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('删除组“${group.displayName}”？'),
        content: const Text('只删除 App 本地组结构，不会删除组内列表和任务。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await _service.deleteGroup(groupId: group.groupId);
    await _load();
  }


  @override
  Widget build(BuildContext context) {
    final defaultList = _realLists.where((e) => e.wellknownListName == 'defaultList').toList();
    final groupedListIds = _listGroupAssignments.keys.toSet();
    final customLists = _realLists.where((e) => e.wellknownListName != 'defaultList' && !groupedListIds.contains(e.listId)).toList();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Microsoft To Do'),
        actions: [
          IconButton(
            tooltip: '搜索任务、步骤和备注',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TodoSearchPage())).then((_) => _load()),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: '刷新并同步全部 To Do',
            onPressed: _busy ? null : () => _sync(auto: true),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(tooltip: '新建组', onPressed: _busy ? null : _createGroup, icon: const Icon(Icons.create_new_folder_outlined)),
          IconButton(onPressed: () => setState(() => _showSync = !_showSync), icon: const Icon(Icons.tune_outlined)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _createList(),
        icon: const Icon(Icons.add),
        label: const Text('新建列表'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _sync(auto: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          children: [
            _TodoUnsyncedWarningCard(summary: _unsynced, onSync: _busy ? null : () => _sync(auto: true)),
            if (_busy || _status.isNotEmpty) _TodoSyncStatusBanner(status: _status, busy: _busy),
            if (_showSync) _SyncCard(busy: _busy, controller: _listNameCtrl, status: _status, timeZone: _preferredTimeZone, onTimeZoneChanged: _changePreferredTimeZone, onSync: () => _sync(auto: false)),
            const _NietzscheWhyQuoteCard(),
            const SizedBox(height: 10),
            _TodoGoalEntryCard(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TodoGoalHomePage())).then((_) => _load())),
            const SizedBox(height: 10),
            ..._smartLists.map((l) => _TodoNavTile(
                  icon: _smartIcon(l.listId),
                  iconColor: _smartColor(l.listId),
                  title: l.displayName,
                  count: l.taskCount == 0 ? '' : '${l.taskCount}',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoListPage(listId: l.listId))).then((_) => _load()),
                )),
            const SizedBox(height: 14),
            if (defaultList.isNotEmpty) ...[
              const Divider(height: 24),
              ...defaultList.map((l) => _TodoNavTile(
                    icon: Icons.home_outlined,
                    iconColor: _todoBlue,
                    title: l.displayName.isEmpty ? '任务' : l.displayName,
                    count: '${l.taskCount}',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoListPage(listId: l.listId))).then((_) => _load()),
                  )),
            ],
            if (_groups.isNotEmpty) ...[
              const Divider(height: 28),
              const Padding(
                padding: EdgeInsets.only(top: 6, bottom: 4),
                child: Row(
                  children: [
                    Text('组', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    SizedBox(width: 8),
                    Expanded(child: Text('App 会保存组-列表结构；当前 Microsoft Graph To Do v1.0 只开放任务列表和任务写回。', style: TextStyle(color: Color(0xFF8B8D98), fontSize: 12))),
                  ],
                ),
              ),
              ..._groups.map((g) {
                final children = _realLists.where((l) => _listGroupAssignments[l.listId] == g.groupId).toList();
                return _TodoGroupTile(
                  group: g,
                  lists: children,
                  onOpenList: (l) => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoListPage(listId: l.listId))).then((_) => _load()),
                  onAddList: () => _createList(groupId: g.groupId),
                  onEditGroup: () => _editGroup(g),
                  onDeleteGroup: () => _deleteGroup(g),
                );
              }),
            ],
            if (customLists.isNotEmpty) ...[
              const Divider(height: 28),
              const Padding(
                padding: EdgeInsets.only(top: 6, bottom: 4),
                child: Text('未分组列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              ...customLists.map((l) => Padding(
                    padding: const EdgeInsets.only(left: 18),
                    child: _TodoNavTile(
                      icon: Icons.list_alt_outlined,
                      iconColor: _todoBlue,
                      title: l.displayName,
                      count: l.taskCount == 0 ? '' : '${l.taskCount}',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoListPage(listId: l.listId))).then((_) => _load()),
                    ),
                  )),
            ],
            if (_smartLists.isEmpty && _realLists.isEmpty) const _TodoEmptyHint(text: '暂无 To Do 数据。页面会自动同步；也可以点击右上角刷新按钮立即同步。'),
          ],
        ),
      ),
    );
  }
}



class _TodoGoalEntryCard extends StatelessWidget {
  const _TodoGoalEntryCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FF),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE0E7FF)),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 6))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.auto_awesome, color: _todoBlue, size: 32),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('To Do 目标价值系统', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF22223B))),
              SizedBox(height: 6),
              Text('围绕目标价值体系，把任务转化为方向感、自我和谐、沿途体验、今日最小行动和每日复盘。', style: TextStyle(color: Color(0xFF4B5563), height: 1.4)),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Color(0xFF6B7280)),
        ]),
      ),
    );
  }
}

class _TodoGoalTransformButton extends StatelessWidget {
  const _TodoGoalTransformButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('按核心价值重新理解这个任务', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF22223B))),
        const SizedBox(height: 5),
        const Text('AI 会先判断它是否通向你真正关心的生活，再提炼方向、深层意义、沿途价值，并生成今天5分钟内能开始的最小行动。', style: TextStyle(color: Color(0xFF4B5563), height: 1.35)),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: onTap, icon: const Icon(Icons.auto_awesome), label: const Text('AI 按核心价值转化'))),
      ]),
    );
  }
}



class _TodoSustainableExcellenceButton extends StatelessWidget {
  const _TodoSustainableExcellenceButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('转入可持续卓越实验室', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF134E4A))),
        const SizedBox(height: 5),
        const Text('把这个 Todo 转为“压力—恢复—失败学习—过程享受”的行动实验，支持执行页、失败复盘和下一步 Todo 写回。', style: TextStyle(color: Color(0xFF0F766E), height: 1.35)),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: onTap, icon: const Icon(Icons.all_inclusive), label: const Text('进入卓越实验'))),
      ]),
    );
  }
}

class _TodoUnsyncedWarningCard extends StatelessWidget {
  const _TodoUnsyncedWarningCard({required this.summary, this.onSync});

  final TodoUnsyncedSummary summary;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasAny) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFC24D), width: 1.2),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 5))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('存在本地待同步修改', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF7C2D12))),
            const SizedBox(height: 4),
            Text('${summary.label} 已保存在本地，但尚未成功写回 Microsoft To Do。同步前请不要误以为远端已经更新。', style: const TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF7C2D12))),
            if (onSync != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: onSync, icon: const Icon(Icons.cloud_upload_outlined), label: const Text('立即写回并同步')),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _TodoSyncStatusBanner extends StatelessWidget {
  const _TodoSyncStatusBanner({required this.status, required this.busy, this.compact = false});
  final String status;
  final bool busy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isError = status.contains('失败') || status.toLowerCase().contains('error') || status.toLowerCase().contains('exception');
    final isSuccess = status.contains('成功') || status.contains('完成');
    final Widget icon = busy
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : Icon(isError ? Icons.error_outline : (isSuccess ? Icons.check_circle_outline : Icons.info_outline), color: isError ? Colors.red.shade700 : (isSuccess ? Colors.green.shade700 : _todoBlue));
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 0 : 12),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isError ? Colors.red.shade200 : (isSuccess ? Colors.green.shade200 : const Color(0xFFE5E7EB))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: icon),
          const SizedBox(width: 10),
          Expanded(child: Text(status.isEmpty ? '准备同步 Microsoft To Do 数据...' : status, style: const TextStyle(fontSize: 14, height: 1.35))),
        ],
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({required this.busy, required this.controller, required this.status, required this.timeZone, required this.onTimeZoneChanged, required this.onSync});
  final bool busy;
  final TextEditingController controller;
  final String status;
  final String timeZone;
  final ValueChanged<String?>? onTimeZoneChanged;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('同步 Microsoft To Do 数据', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('留空同步全部真实任务列表；填写任务列表名称时，只同步该列表。', style: TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: '任务列表名称（可选）', hintText: '例如：任务 / 收拾收拾 / 列表1', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            _TimeZoneDropdown(
              value: timeZone,
              onChanged: busy ? null : onTimeZoneChanged,
            ),
            const SizedBox(height: 6),
            const Text('该时区会用于 To Do 读写请求和本地“我的一天/计划内”日期判断；中国时区请选择 Asia/Shanghai。', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12, height: 1.35)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : onSync,
              icon: const Icon(Icons.cloud_sync_outlined),
              label: const Text('开始同步 To Do'),
            ),
            if (status.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(status),
            ],
          ],
        ),
      ),
    );
  }
}


class _NietzscheWhyQuoteCard extends StatelessWidget {
  const _NietzscheWhyQuoteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF24243E), Color(0xFF5E72C3)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _todoBlue.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -4,
            top: -18,
            child: Text('Warum', style: TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.08), letterSpacing: -2)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 34, height: 2, color: Colors.white.withOpacity(0.65)),
                  const SizedBox(width: 10),
                  Text('尼采 · 《偶像的黄昏》', style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 12, letterSpacing: 1.2)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('有了生命的“为什么”，\n几乎就能承受一切“如何”。', style: TextStyle(color: Colors.white, fontSize: 22, height: 1.35, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text('Hat man sein warum? des Lebens, so verträgt man sich fast mit jedem wie?', style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 13, height: 1.35, fontStyle: FontStyle.italic)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodoNavTile extends StatelessWidget {
  const _TodoNavTile({required this.icon, required this.iconColor, required this.title, required this.count, required this.onTap});
  final IconData icon;
  final Color iconColor;
  final String title;
  final String count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
      trailing: count.isEmpty ? null : Text(count, style: const TextStyle(fontSize: 18, color: Color(0xFF6B7280))),
      onTap: onTap,
    );
  }
}

class _TodoGroupTile extends StatelessWidget {
  const _TodoGroupTile({
    required this.group,
    required this.lists,
    required this.onOpenList,
    required this.onAddList,
    required this.onEditGroup,
    required this.onDeleteGroup,
  });

  final TodoGroupRecord group;
  final List<TodoListRecord> lists;
  final ValueChanged<TodoListRecord> onOpenList;
  final VoidCallback onAddList;
  final VoidCallback onEditGroup;
  final VoidCallback onDeleteGroup;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: const Color(0xFFF8F8FB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE7E7EE))),
      child: ExpansionTile(
        leading: const Icon(Icons.folder_outlined, color: _todoBlue),
        title: Text(group.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        subtitle: Text('${lists.length} 个列表', style: const TextStyle(color: Color(0xFF8B8D98))),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'add') onAddList();
            if (value == 'edit') onEditGroup();
            if (value == 'delete') onDeleteGroup();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'add', child: Text('在此组中新建列表')),
            PopupMenuItem(value: 'edit', child: Text('修改组名称')),
            PopupMenuItem(value: 'delete', child: Text('删除组')),
          ],
        ),
        children: [
          if (lists.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Align(alignment: Alignment.centerLeft, child: Text('此组暂无列表。', style: TextStyle(color: Color(0xFF8B8D98)))),
            ),
          ...lists.map((l) => ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 42, right: 16),
                leading: const Icon(Icons.list_alt_outlined, color: _todoBlue),
                title: Text(l.displayName, style: const TextStyle(fontSize: 17)),
                trailing: l.taskCount == 0 ? null : Text('${l.taskCount}', style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
                onTap: () => onOpenList(l),
              )),
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 42, right: 16),
            leading: const Icon(Icons.add, color: _todoBlue),
            title: const Text('在此组中新建列表'),
            onTap: onAddList,
          ),
        ],
      ),
    );
  }
}

class TodoListPage extends StatefulWidget {
  const TodoListPage({super.key, required this.listId});
  final String listId;

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  final _dao = TodoDao();
  late final _service = TodoGraphService(dao: _dao);
  TodoListRecord? _list;
  final List<TodoTaskRecord> _tasks = [];
  String _filter = 'all';
  bool _loading = false;
  bool _syncing = false;
  String _status = '';
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 50;
  TodoUnsyncedSummary _unsynced = const TodoUnsyncedSummary(lists: 0, tasks: 0, children: 0);

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }


  Future<void> _loadInitial() async {
    final l = await _dao.getList(widget.listId);
    final unsynced = await _dao.unsyncedSummary(listId: widget.listId);
    if (!mounted) return;
    setState(() {
      _list = l;
      _unsynced = unsynced;
    });
    await _loadMore(reset: true);
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (reset) {
        _tasks.clear();
        _offset = 0;
        _hasMore = true;
      }
      final rows = await _dao.listTasks(widget.listId, filter: _filter, limit: _limit, offset: _offset);
      if (!mounted) return;
      setState(() {
        _tasks.addAll(rows);
        _offset += rows.length;
        _hasMore = rows.length == _limit;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncCurrentList({bool auto = false}) async {
    if (_syncing) return;
    var l = _list;
    l ??= await _dao.getList(widget.listId);
    final isSmart = l?.isSmartView ?? widget.listId.startsWith('smart_');
    final targetName = isSmart ? '智能视图“${l?.displayName ?? '当前页'}”' : '任务列表“${l?.displayName ?? widget.listId}”';
    if (!mounted) return;
    setState(() {
      _syncing = true;
      _status = '正在同步当前页：$targetName...';
    });
    _showSyncMessage(_status);
    try {
      final r = isSmart
          ? await _service.syncSmartView(
              smartListId: widget.listId,
              onProgress: (m) {
                if (!mounted) return;
                setState(() => _status = m);
              },
            )
          : await _service.sync(
              listId: widget.listId,
              onProgress: (m) {
                if (!mounted) return;
                setState(() => _status = m);
              },
            );
      if (!isSmart) {
        final stillExists = await _dao.getList(widget.listId);
        if (stillExists == null && mounted) {
          Navigator.pop(context);
          return;
        }
      }
      await _loadInitial();
      if (!mounted) return;
      final msg = isSmart
          ? '已刷新当前智能视图：${l?.displayName ?? ''}。'
          : '同步成功：任务列表 ${r.lists} 个，任务 ${r.tasks} 个，步骤/附件/关联资源 ${r.children} 条。';
      setState(() => _status = msg);
      _showSyncMessage(msg);
    } catch (e) {
      await _loadInitial();
      if (!mounted) return;
      final msg = '同步失败：$e';
      setState(() => _status = msg);
      _showSyncMessage(msg, isError: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _showSyncMessage(String message, {bool isError = false}) {
    if (!mounted || message.trim().isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  Future<void> _editList() async {
    final l = _list;
    if (l == null) return;
    final result = await Navigator.push<Object?>(context, MaterialPageRoute(builder: (_) => TodoListEditPage(list: l)));
    if (!mounted || result == null) return;
    if (result is String && result.trim().isNotEmpty && result.trim() != widget.listId) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TodoListPage(listId: result.trim())));
      return;
    }
    await _loadInitial();
  }

  Future<void> _deleteList() async {
    final l = _list;
    if (l == null) return;
    final writeBack = await _confirmWriteBack('删除任务列表', '会先在本地标记删除。选择“同时写回”会继续删除 Microsoft To Do 远端列表。');
    if (writeBack == null) return;
    await _service.deleteList(listId: l.listId, writeBack: writeBack);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _addTask() async {
    final result = await Navigator.of(context).push<Object?>(MaterialPageRoute(builder: (_) => TodoTaskEditPage(listId: widget.listId)));
    if (!mounted) return;
    if (result != null) {
      final stillExists = await _dao.getList(widget.listId);
      if (stillExists == null && mounted) {
        Navigator.pop(context);
        return;
      }
      await _loadInitial();
      if (!mounted) return;
      _showSyncMessage('任务已保存，已停留在当前列表。');
    }
  }


  Future<void> _toggleTaskCompleted(TodoTaskRecord task) async {
    if (_syncing || _loading) return;
    final targetCompleted = !task.isCompleted;
    try {
      await _service.setTaskCompleted(task: task, completed: targetCompleted, writeBack: true);
      await _loadInitial();
      if (!mounted) return;
      _showSyncMessage(targetCompleted ? '已标记为完成，并已同步到 Microsoft To Do。' : '已恢复为未完成，并已同步到 Microsoft To Do。');
    } catch (e) {
      await _loadInitial();
      if (!mounted) return;
      _showSyncMessage('完成状态同步失败：$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _list;
    final visibleTasks = _tasks;
    final themeColor = _todoListThemeColor(l);
    final image = _todoListBackgroundImage(l);
    final usesImage = image != null;
    final titleStyle = TextStyle(
      color: Colors.white,
      fontSize: 34,
      fontWeight: FontWeight.w500,
      shadows: usesImage ? _todoReadableTextShadow() : null,
    );
    return Scaffold(
      extendBodyBehindAppBar: usesImage,
      backgroundColor: themeColor,
      appBar: AppBar(
        backgroundColor: usesImage ? Colors.transparent : themeColor,
        foregroundColor: Colors.white,
        title: const SizedBox.shrink(),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '刷新并同步当前页',
            onPressed: _syncing ? null : () => _syncCurrentList(),
            icon: const Icon(Icons.refresh),
          ),
          if (!(l?.isSmartView ?? false)) IconButton(onPressed: _editList, icon: const Icon(Icons.more_vert)),
          if (!(l?.isSmartView ?? false)) IconButton(onPressed: _deleteList, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      floatingActionButton: (l?.isSmartView ?? false) ? null : FloatingActionButton(onPressed: _addTask, child: const Icon(Icons.add)),
      body: _TodoListBackground(
        color: themeColor,
        image: image,
        child: RefreshIndicator(
          onRefresh: () => _syncCurrentList(),
          child: ListView(
            padding: EdgeInsets.fromLTRB(14, usesImage ? 112 : 10, 14, 96),
            children: [
              Text(l?.displayName ?? '任务', style: titleStyle),
              if (l?.isSmartView ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _smartViewNote(l!.listId),
                    style: TextStyle(color: Colors.white.withOpacity(0.82), shadows: usesImage ? _todoReadableTextShadow() : null),
                  ),
                ),
              _TodoUnsyncedWarningCard(summary: _unsynced, onSync: _syncing ? null : () => _syncCurrentList()),
              if (_syncing || _status.isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _TodoSyncStatusBanner(status: _status, busy: _syncing, compact: true),
              ),
              const SizedBox(height: 28),
              ...visibleTasks.map((t) => _TaskCard(task: t, onToggleCompleted: () => _toggleTaskCompleted(t), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoTaskDetailPage(taskId: t.taskId))).then((_) => _loadInitial()))),
              if (_tasks.isEmpty && !_loading) Padding(padding: const EdgeInsets.only(top: 40), child: _TodoEmptyHint(text: widget.listId == 'smart_completed' ? '暂无已完成任务。' : '这个页面暂无未完成任务。')),
              if (_loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: Colors.white))) else if (_hasMore) OutlinedButton.icon(onPressed: () => _loadMore(), icon: const Icon(Icons.expand_more), label: const Text('加载更多任务')),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmWriteBack(String title, String message) async {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('仅本地')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('同时写回')),
        ],
      ),
    );
  }
}


class _TodoListBackground extends StatelessWidget {
  const _TodoListBackground({required this.color, required this.child, this.image});
  final Color color;
  final ImageProvider? image;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final img = image;
    return Container(
      decoration: BoxDecoration(
        color: color,
        image: img == null
            ? null
            : DecorationImage(
                image: img,
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.24), BlendMode.darken),
              ),
      ),
      child: Container(
        decoration: img == null
            ? null
            : const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66000000), Color(0x11000000), Color(0x33000000)],
                ),
              ),
        child: child,
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onTap, required this.onToggleCompleted});
  final TodoTaskRecord task;
  final VoidCallback onTap;
  final VoidCallback onToggleCompleted;

  @override
  Widget build(BuildContext context) {
    final meta = _taskMeta(task);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1.5,
      color: const Color(0xFFFFFFFF),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withOpacity(0.16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        tileColor: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: IconButton(
          tooltip: task.isCompleted ? '标记为未完成' : '标记为已完成',
          onPressed: onToggleCompleted,
          icon: Icon(task.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, color: task.isCompleted ? _todoBlue : Colors.grey, size: 33),
        ),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 18, decoration: task.isCompleted ? TextDecoration.lineThrough : null, color: task.isCompleted ? Colors.grey : const Color(0xFF202124)),
        ),
        subtitle: meta.isEmpty ? null : Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF5F6368), fontSize: 14)),
        trailing: Icon(task.importance == 'high' ? Icons.star : Icons.star_border, color: task.importance == 'high' ? Colors.amber.shade700 : Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

class TodoSearchPage extends StatefulWidget {
  const TodoSearchPage({super.key});

  @override
  State<TodoSearchPage> createState() => _TodoSearchPageState();
}

class _TodoSearchPageState extends State<TodoSearchPage> {
  final _dao = TodoDao();
  final _ctrl = TextEditingController();
  final List<TodoTaskRecord> _results = [];
  bool _loading = false;
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    setState(() {
      _query = q;
      _loading = q.isNotEmpty;
      if (q.isEmpty) _results.clear();
    });
    if (q.isEmpty) return;
    try {
      final rows = await _dao.searchTasks(q);
      if (!mounted) return;
      setState(() {
        _results
          ..clear()
          ..addAll(rows);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openTask(TodoTaskRecord task) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => TodoTaskDetailPage(taskId: task.taskId)));
    if (_query.isNotEmpty) await _search();
  }

  @override
  Widget build(BuildContext context) {
    final showEmpty = _query.isEmpty && !_loading;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '搜索',
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _search(),
          onChanged: (_) {
            if (_ctrl.text.trim().isEmpty) {
              setState(() {
                _query = '';
                _results.clear();
              });
            }
          },
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              tooltip: '清空',
              onPressed: () {
                _ctrl.clear();
                setState(() {
                  _query = '';
                  _results.clear();
                });
              },
              icon: const Icon(Icons.close),
            ),
          IconButton(
            tooltip: '搜索',
            onPressed: _loading ? null : _search,
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: showEmpty
          ? const _TodoSearchEmpty()
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
                  ? const _TodoSearchEmpty(text: '没有找到匹配内容。可在任务标题、步骤和备注内搜索')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final t = _results[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          leading: Icon(t.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, color: t.isCompleted ? _todoBlue : Colors.grey),
                          title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18)),
                          subtitle: Text(_searchSubtitle(t), maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: t.importance == 'high' ? const Icon(Icons.star, color: Colors.amber) : null,
                          onTap: () => _openTask(t),
                        );
                      },
                    ),
    );
  }
}

class _TodoSearchEmpty extends StatelessWidget {
  const _TodoSearchEmpty({this.text = '你想查找什么内容？可在任务、步骤和笔记内搜索'});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 120, color: _todoBlue.withOpacity(0.55)),
            const SizedBox(height: 18),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Color(0xFF6B7280), height: 1.45)),
          ],
        ),
      ),
    );
  }
}

String _searchSubtitle(TodoTaskRecord t) {
  final parts = <String>[];
  final meta = _taskMeta(t);
  if (meta.isNotEmpty) parts.add(meta);
  if (t.bodyText.trim().isNotEmpty) parts.add(t.bodyText.trim());
  return parts.isEmpty ? '点击查看任务详情' : parts.join(' · ');
}

class TodoGroupEditPage extends StatefulWidget {
  const TodoGroupEditPage({super.key, this.group});
  final TodoGroupRecord? group;

  @override
  State<TodoGroupEditPage> createState() => _TodoGroupEditPageState();
}

class _TodoGroupEditPageState extends State<TodoGroupEditPage> {
  final _nameCtrl = TextEditingController();
  late final _service = TodoGraphService();
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.group?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _status = '正在保存组结构...';
    });
    try {
      final g = widget.group;
      if (g == null) {
        await _service.createGroup(displayName: _nameCtrl.text);
      } else {
        await _service.updateGroup(groupId: g.groupId, displayName: _nameCtrl.text);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '保存失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.group == null ? '新建 To Do 组' : '修改 To Do 组')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('组用于在 App 内按 Microsoft To Do 的侧栏结构组织列表。当前 Graph To Do v1.0 未开放远端组字段，因此组结构先保存到本地。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
          const SizedBox(height: 12),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '组名称', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _busy ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('保存')),
          if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_status)),
        ],
      ),
    );
  }
}

class TodoListEditPage extends StatefulWidget {
  const TodoListEditPage({super.key, this.list, this.groupId = ''});
  final TodoListRecord? list;
  final String groupId;

  @override
  State<TodoListEditPage> createState() => _TodoListEditPageState();
}

class _TodoListEditPageState extends State<TodoListEditPage> {
  final _nameCtrl = TextEditingController();
  late final _service = TodoGraphService();
  bool _writeBack = true;
  bool _busy = false;
  String _status = '';
  String _themeColor = '#5E72C3';
  String _backgroundMode = 'color';
  String _backgroundAsset = '';
  String _backgroundLocalPath = '';

  @override
  void initState() {
    super.initState();
    final l = widget.list;
    _nameCtrl.text = l?.displayName ?? '';
    final rawThemeColor = l?.themeColor ?? '#5E72C3';
    final rawBackgroundMode = l?.backgroundMode ?? 'color';
    _themeColor = rawThemeColor.trim().isEmpty ? '#5E72C3' : rawThemeColor;
    _backgroundMode = rawBackgroundMode.trim().isEmpty ? 'color' : rawBackgroundMode;
    _backgroundAsset = l?.backgroundAsset ?? '';
    _backgroundLocalPath = l?.backgroundLocalPath ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocalBackground() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final bgDir = Directory(p.join(dir.path, 'ms_todo_backgrounds'));
      if (!await bgDir.exists()) await bgDir.create(recursive: true);
      final ext = p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path);
      final fileName = 'todo_bg_${DateTime.now().millisecondsSinceEpoch}$ext';
      final saved = await File(picked.path).copy(p.join(bgDir.path, fileName));
      if (!mounted) return;
      setState(() {
        _backgroundMode = 'local_photo';
        _backgroundLocalPath = saved.path;
        _backgroundAsset = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '导入背景图片失败：$e');
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _status = '正在保存...';
    });
    try {
      final l = widget.list;
      String resultListId;
      if (l == null) {
        resultListId = await _service.createList(
          displayName: _nameCtrl.text,
          writeBack: _writeBack,
          groupId: widget.groupId,
          themeColor: _themeColor,
          backgroundMode: _backgroundMode,
          backgroundAsset: _backgroundAsset,
          backgroundLocalPath: _backgroundLocalPath,
        );
      } else {
        resultListId = await _service.updateList(
          listId: l.listId,
          displayName: _nameCtrl.text,
          writeBack: _writeBack,
          themeColor: _themeColor,
          backgroundMode: _backgroundMode,
          backgroundAsset: _backgroundAsset,
          backgroundLocalPath: _backgroundLocalPath,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, resultListId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '保存失败：本地列表名称/外观已保存为待同步状态，但写回 Microsoft To Do 未成功。请在首页黄色提示处重试同步。原始错误：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ImageProvider? get _previewImage {
    if (_backgroundMode == 'asset_photo' && _backgroundAsset.trim().isNotEmpty) return AssetImage(_backgroundAsset.trim());
    if (_backgroundMode == 'local_photo' && _backgroundLocalPath.trim().isNotEmpty) {
      final f = File(_backgroundLocalPath.trim());
      if (f.existsSync()) return FileImage(f);
    }
    return null;
  }

  void _selectMode(String mode) {
    setState(() {
      _backgroundMode = mode;
      if (mode == 'asset_photo') {
        _backgroundAsset = _backgroundAsset.trim().isEmpty ? _todoPhotoAssets.first : _backgroundAsset;
        _backgroundLocalPath = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final image = _previewImage;
    final color = _hexColor(_themeColor);
    final title = _nameCtrl.text.trim().isEmpty ? '未命名列表' : _nameCtrl.text.trim();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(title: Text(widget.list == null ? '新建列表' : '修改列表')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: widget.list == null,
            decoration: const InputDecoration(
              labelText: '列表名称',
              hintText: '输入列表名称',
              prefixIcon: Icon(Icons.playlist_add_outlined),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
          ),
          if (widget.groupId.trim().isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8, left: 4),
              child: Text('将创建到当前组中。', style: TextStyle(color: Color(0xFF6B7280))),
            ),
          const SizedBox(height: 16),
          _ListAppearancePreviewCompact(title: title, color: color, image: image),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text('外观', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton.icon(onPressed: _pickLocalBackground, icon: const Icon(Icons.photo_library_outlined), label: const Text('本地图片')),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(label: const Text('颜色'), selected: _backgroundMode == 'color', onSelected: (_) => _selectMode('color')),
              ChoiceChip(label: const Text('照片'), selected: _backgroundMode == 'asset_photo', onSelected: (_) => _selectMode('asset_photo')),
              ChoiceChip(label: const Text('自定义'), selected: _backgroundMode == 'local_photo', onSelected: (_) => _pickLocalBackground()),
            ],
          ),
          const SizedBox(height: 14),
          if (_backgroundMode == 'color')
            _ColorPickerRow(selected: _themeColor, onSelected: (c) => setState(() => _themeColor = c)),
          if (_backgroundMode == 'asset_photo')
            _PhotoPickerRow(
              selected: _backgroundAsset.trim().isEmpty ? _todoPhotoAssets.first : _backgroundAsset,
              onSelected: (asset) => setState(() {
                _backgroundMode = 'asset_photo';
                _backgroundAsset = asset;
                _backgroundLocalPath = '';
              }),
            ),
          if (_backgroundMode == 'local_photo')
            _LocalPhotoPicker(
              path: _backgroundLocalPath,
              onPick: _pickLocalBackground,
              onClear: () => setState(() {
                _backgroundMode = 'color';
                _backgroundLocalPath = '';
              }),
            ),
          const SizedBox(height: 18),
          Card(
            elevation: 0,
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              title: const Text('同时写回 Microsoft To Do'),
              subtitle: const Text('只同步列表名称；颜色和背景图片保存在 App 本地。'),
              value: _writeBack,
              onChanged: _busy ? null : (v) => setState(() => _writeBack = v),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_busy ? '保存中...' : '保存'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
          if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_status, style: TextStyle(color: _status.contains('失败') ? Colors.red.shade700 : const Color(0xFF6B7280)))),
        ],
      ),
    );
  }
}

class _ListAppearancePreviewCompact extends StatelessWidget {
  const _ListAppearancePreviewCompact({required this.title, required this.color, this.image});
  final String title;
  final Color color;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final usesImage = image != null;
    return Container(
      height: 152,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        image: image == null
            ? null
            : DecorationImage(
                image: image!,
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.26), BlendMode.darken),
              ),
        boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 14, offset: Offset(0, 7))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.arrow_back, color: Colors.white.withOpacity(0.92)),
              const Spacer(),
              Icon(Icons.more_vert, color: Colors.white.withOpacity(0.92)),
            ]),
            const Spacer(),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, shadows: usesImage ? _todoReadableTextShadow() : _todoReadableTextShadow())),
            const SizedBox(height: 10),
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: const Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(9)),
              child: const Row(children: [
                Icon(Icons.radio_button_unchecked, color: Colors.grey),
                SizedBox(width: 10),
                Expanded(child: Text('任务示例', style: TextStyle(fontSize: 15, color: Color(0xFF202124)))),
                Icon(Icons.star_border, color: Colors.grey),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorPickerRow extends StatelessWidget {
  const _ColorPickerRow({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _todoListColors.map((hex) {
        final active = selected.toUpperCase() == hex.toUpperCase();
        return InkWell(
          onTap: () => onSelected(hex),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _hexColor(hex),
              shape: BoxShape.circle,
              border: Border.all(color: active ? Colors.black87 : Colors.white, width: active ? 3 : 2),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 3))],
            ),
            child: active ? const Icon(Icons.check, color: Colors.white) : null,
          ),
        );
      }).toList(),
    );
  }
}

class _PhotoPickerRow extends StatelessWidget {
  const _PhotoPickerRow({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _todoPhotoAssets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final asset = _todoPhotoAssets[i];
          final active = selected == asset;
          return InkWell(
            onTap: () => onSelected(asset),
            borderRadius: BorderRadius.circular(32),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: active ? Colors.black87 : Colors.white, width: active ? 3 : 2),
                image: DecorationImage(image: AssetImage(asset), fit: BoxFit.cover),
                boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 3))],
              ),
              child: active ? const Icon(Icons.check_circle, color: Colors.white) : null,
            ),
          );
        },
      ),
    );
  }
}

class _LocalPhotoPicker extends StatelessWidget {
  const _LocalPhotoPicker({required this.path, required this.onPick, required this.onClear});
  final String path;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final has = path.trim().isNotEmpty && File(path.trim()).existsSync();
    return Row(
      children: [
        if (has)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(File(path.trim()), width: 72, height: 72, fit: BoxFit.cover),
          )
        else
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: const Color(0xFFE9EAF2), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.image_outlined),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(has ? '更换本地图片' : '从本地导入背景图片'),
          ),
        ),
        if (has) IconButton(onPressed: onClear, icon: const Icon(Icons.close), tooltip: '移除自定义图片'),
      ],
    );
  }
}

class TodoTaskDetailPage extends StatefulWidget {
  const TodoTaskDetailPage({super.key, required this.taskId});
  final String taskId;

  @override
  State<TodoTaskDetailPage> createState() => _TodoTaskDetailPageState();
}

class _TodoTaskDetailPageState extends State<TodoTaskDetailPage> {
  final _dao = TodoDao();
  late final _service = TodoGraphService(dao: _dao);
  late String _taskId;
  bool _loading = true;
  TodoTaskRecord? _task;
  List<TodoChildRecord> _checklist = [];
  List<TodoChildRecord> _attachments = [];
  List<TodoChildRecord> _links = [];

  @override
  void initState() {
    super.initState();
    _taskId = widget.taskId;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final currentTaskId = _taskId;
    final t = await _dao.getTask(currentTaskId);
    final c = t == null ? <TodoChildRecord>[] : await _dao.listChildren(currentTaskId, 'checklistItem');
    final a = t == null ? <TodoChildRecord>[] : await _dao.listChildren(currentTaskId, 'attachment');
    final l = t == null ? <TodoChildRecord>[] : await _dao.listChildren(currentTaskId, 'linkedResource');
    if (!mounted || currentTaskId != _taskId) return;
    setState(() {
      _loading = false;
      _task = t;
      _checklist = c;
      _attachments = a;
      _links = l;
    });
  }

  Future<void> _edit() async {
    final t = _task;
    if (t == null) return;
    final result = await Navigator.push<Object?>(context, MaterialPageRoute(builder: (_) => TodoTaskEditPage(listId: t.listId, task: t)));
    if (result is String && result.trim().isNotEmpty) {
      _taskId = result.trim();
    }
    if (result != null) await _load();
  }

  Future<void> _delete() async {
    final t = _task;
    if (t == null) return;
    final writeBack = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除任务'),
        content: const Text('会先在本地标记删除。选择“同时写回”会继续删除 Microsoft To Do 远端任务。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('仅本地')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('同时写回')),
        ],
      ),
    );
    if (writeBack == null) return;
    await _service.deleteTask(task: t, writeBack: writeBack);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = _task;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const SizedBox.shrink(), actions: [IconButton(onPressed: _edit, icon: const Icon(Icons.edit_outlined)), IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline))]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : t == null
              ? _TodoTaskMissingView(onRetry: _load)
              : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(t.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, size: 42, color: t.isCompleted ? _todoBlue : Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t.title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500))),
                  Icon(t.importance == 'high' ? Icons.star : Icons.star_border, size: 34, color: t.importance == 'high' ? Colors.amber.shade700 : Colors.grey),
                ]),
                const SizedBox(height: 14),
                _TodoGoalTransformButton(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoGoalHomePage(initialTaskId: t.taskId))).then((_) => _load()),
                ),
                const SizedBox(height: 10),
                _TodoSustainableExcellenceButton(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SustainableExcellenceHomePage(
                        initialInput: t.title,
                        source: 'todo',
                        extraContext: jsonEncode(<String, Object?>{
                          'source_todo_id': t.taskId,
                          'source_list_id': t.listId,
                          'body': t.bodyText,
                          'checklist': _checklist.map((e) => e.title).toList(),
                          'due_date_time': t.dueDateTime,
                          'due_time_zone': t.dueTimeZone,
                          'reminder_on': t.isReminderOn,
                          'reminder_date_time': t.reminderDateTime,
                          'reminder_time_zone': t.reminderTimeZone,
                          'importance': t.importance,
                          'recurrence_json': t.recurrenceJson,
                          'categories_json': t.categoriesJson,
                          'is_my_day': t.isMyDay,
                        }),
                      ),
                    ),
                  ).then((_) => _load()),
                ),

                if (_checklist.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ..._checklist.map((s) => ListTile(
                        leading: Icon(s.isChecked ? Icons.check_circle : Icons.radio_button_unchecked, color: s.isChecked ? _todoBlue : Colors.grey),
                        title: Text(s.title, style: TextStyle(decoration: s.isChecked ? TextDecoration.lineThrough : null)),
                      )),
                ],
                const SizedBox(height: 12),
                _InfoRow(icon: Icons.list_alt_outlined, label: '所属列表：${t.listDisplayName.trim().isEmpty ? t.listId : t.listDisplayName.trim()}', enabled: true),
                _InfoRow(icon: Icons.wb_sunny_outlined, label: t.isMyDay ? '已添加到“我的一天”' : '添加到“我的一天”', enabled: t.isMyDay),
                _InfoRow(icon: Icons.notifications_none, label: t.isReminderOn ? '提醒我：${_todoDateTimeLabel(t.reminderDateTime, withTime: true)}' : '提醒我', enabled: t.isReminderOn),
                _InfoRow(icon: Icons.calendar_month_outlined, label: t.dueDateTime.isEmpty ? '到期' : '到期：${_todoDateTimeLabel(t.dueDateTime, withTime: true)}', enabled: t.dueDateTime.isNotEmpty),
                _InfoRow(icon: Icons.repeat, label: t.recurrenceJson.isEmpty ? '重复' : '重复：${_recurrenceLabel(t.recurrenceJson)}', enabled: t.recurrenceJson.isNotEmpty),
                if (_attachments.isNotEmpty) _ChildSection(title: '附件', children: _attachments) else const _InfoRow(icon: Icons.attach_file, label: '添加文件', enabled: false),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(4)),
                  child: SelectableText(t.bodyText.isEmpty ? '添加备注' : t.bodyText, style: const TextStyle(fontSize: 17, height: 1.55)),
                ),
                const SizedBox(height: 20),
                Text('创建于 ${_formatRawTime(t.createdDateTime)}', style: const TextStyle(color: Color(0xFF8B8D98))),
                if (_links.isNotEmpty) _ChildSection(title: '关联资源', children: _links),
              ],
            ),
    );
  }
}


class _TodoTaskMissingView extends StatelessWidget {
  const _TodoTaskMissingView({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync_problem_outlined, size: 48, color: Color(0xFF8B8D98)),
            const SizedBox(height: 12),
            const Text('任务已更新，正在使用新的远端任务 ID。', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('如果刚刚修改了重复规则，App 可能已按 Microsoft Graph 的限制创建了替代任务并删除旧任务。请返回列表刷新后重新打开。', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () { onRetry(); }, icon: const Icon(Icons.refresh), label: const Text('重新读取')),
          ],
        ),
      ),
    );
  }
}

class TodoTaskEditPage extends StatefulWidget {
  const TodoTaskEditPage({super.key, required this.listId, this.task});
  final String listId;
  final TodoTaskRecord? task;

  @override
  State<TodoTaskEditPage> createState() => _TodoTaskEditPageState();
}

class _TodoTaskEditPageState extends State<TodoTaskEditPage> {
  final _dao = TodoDao();
  late final _service = TodoGraphService(dao: _dao);
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _dueCtrl = TextEditingController();
  final _reminderCtrl = TextEditingController();
  final _tzCtrl = TextEditingController(text: 'Asia/Shanghai');
  final _recurrenceCtrl = TextEditingController();
  final List<_StepEditItem> _steps = [];
  String _statusValue = 'notStarted';
  bool _isMyDay = false;
  bool _isImportant = false;
  bool _isReminderOn = false;
  bool _writeBack = true;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadPreferredTimeZone();
    final t = widget.task;
    if (t != null) {
      _titleCtrl.text = t.title;
      _noteCtrl.text = t.bodyText;
      _dueCtrl.text = t.dueDateTime;
      _reminderCtrl.text = t.reminderDateTime;
      _tzCtrl.text = t.dueTimeZone.isNotEmpty ? t.dueTimeZone : (t.reminderTimeZone.isNotEmpty ? t.reminderTimeZone : 'Asia/Shanghai');
      _isReminderOn = t.isReminderOn;
      _isMyDay = t.isMyDay;
      _isImportant = t.importance == 'high';
      _recurrenceCtrl.text = t.recurrenceJson;
      _statusValue = _safeStatus(t.status);
      _loadSteps(t.taskId);
    }
  }

  Future<void> _loadPreferredTimeZone() async {
    final preferred = await _dao.getPreferredTimeZone();
    if (!mounted) return;
    final t = widget.task;
    final current = t == null
        ? preferred
        : (t.dueTimeZone.isNotEmpty
            ? t.dueTimeZone
            : (t.reminderTimeZone.isNotEmpty ? t.reminderTimeZone : preferred));
    setState(() => _tzCtrl.text = _normalizeSupportedTimeZone(current));
  }

  Future<void> _setPreferredTimeZone(String timeZone) async {
    final normalized = _normalizeSupportedTimeZone(timeZone);
    _tzCtrl.text = normalized;
    await _dao.setPreferredTimeZone(normalized);
  }

  Future<void> _loadSteps(String taskId) async {
    final rows = await _dao.listChildren(taskId, 'checklistItem');
    if (!mounted) return;
    setState(() {
      _steps
        ..clear()
        ..addAll(rows.map((e) => _StepEditItem(childId: e.childId, title: e.title, isChecked: e.isChecked)));
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _dueCtrl.dispose();
    _reminderCtrl.dispose();
    _tzCtrl.dispose();
    _recurrenceCtrl.dispose();
    for (final s in _steps) {
      s.controller.dispose();
    }
    super.dispose();
  }

  void _addStep() {
    setState(() => _steps.add(_StepEditItem(title: '')));
  }

  DateTime _initialPickerDate(String raw) {
    final parsed = _parseGraphLocalDateTime(raw);
    return parsed ?? DateTime.now();
  }

  Future<void> _pickDueDateTime() async {
    final picked = await _pickDateTime(initial: _initialPickerDate(_dueCtrl.text), title: '选择截止日期和时间');
    if (picked == null) return;
    setState(() {
      _dueCtrl.text = _graphDateTimeText(picked);
      final recurrenceType = _recurrenceChoice(_recurrenceCtrl.text);
      if (recurrenceType != null) {
        _recurrenceCtrl.text = _buildRecurrenceJson(recurrenceType);
      }
    });
  }

  Future<void> _pickReminderDateTime() async {
    final picked = await _pickDateTime(initial: _initialPickerDate(_reminderCtrl.text), title: '选择提醒时间');
    if (picked == null) return;
    setState(() {
      _isReminderOn = true;
      _reminderCtrl.text = _graphDateTimeText(picked);
    });
  }

  Future<DateTime?> _pickDateTime({required DateTime initial, required String title}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 20, 12, 31),
      helpText: title,
      cancelText: '取消',
      confirmText: '下一步',
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: '选择时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickRecurrence() async {
    if (_dueCtrl.text.trim().isEmpty) {
      final picked = await _pickDateTime(initial: DateTime.now(), title: '重复任务需要先选择截止日期');
      if (picked == null) return;
      setState(() => _dueCtrl.text = _graphDateTimeText(picked));
    }
    if (!mounted) return;
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('重复', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
            ListTile(leading: const Icon(Icons.block), title: const Text('不重复'), onTap: () => Navigator.pop(context, 'none')),
            ListTile(leading: const Icon(Icons.repeat), title: const Text('每天'), onTap: () => Navigator.pop(context, 'daily')),
            ListTile(leading: const Icon(Icons.business_center_outlined), title: const Text('工作日'), onTap: () => Navigator.pop(context, 'workdays')),
            ListTile(leading: const Icon(Icons.calendar_view_week_outlined), title: const Text('每周'), onTap: () => Navigator.pop(context, 'weekly')),
            ListTile(leading: const Icon(Icons.calendar_month_outlined), title: const Text('每月'), onTap: () => Navigator.pop(context, 'monthly')),
            ListTile(leading: const Icon(Icons.event_repeat), title: const Text('每年'), onTap: () => Navigator.pop(context, 'yearly')),
            ListTile(leading: const Icon(Icons.data_object), title: const Text('自定义 recurrence JSON'), onTap: () => Navigator.pop(context, 'custom')),
          ],
        ),
      ),
    );
    if (value == null) return;
    if (value == 'none') {
      setState(() => _recurrenceCtrl.clear());
      return;
    }
    if (value == 'custom') {
      final custom = await _editRecurrenceJson();
      if (custom != null) setState(() => _recurrenceCtrl.text = custom);
      return;
    }
    setState(() => _recurrenceCtrl.text = _buildRecurrenceJson(value));
  }

  Future<String?> _editRecurrenceJson() async {
    final ctrl = TextEditingController(text: _recurrenceCtrl.text);
    try {
      return showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('自定义重复 JSON'),
          content: TextField(
            controller: ctrl,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: '{\n  "pattern": {...},\n  "range": {...}\n}',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('确定')),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
  }

  String _buildRecurrenceJson(String type) {
    final due = _parseGraphLocalDateTime(_dueCtrl.text) ?? DateTime.now();
    final patternType = type == 'monthly' ? 'absoluteMonthly' : (type == 'yearly' ? 'absoluteYearly' : (type == 'workdays' ? 'weekly' : type));
    final pattern = <String, dynamic>{
      'type': patternType,
      'interval': 1,
    };
    if (patternType == 'weekly') {
      pattern['daysOfWeek'] = type == 'workdays'
          ? <String>['monday', 'tuesday', 'wednesday', 'thursday', 'friday']
          : <String>[_graphWeekday(due.weekday)];
      pattern['firstDayOfWeek'] = 'sunday';
    } else if (patternType == 'absoluteMonthly') {
      pattern['dayOfMonth'] = due.day;
    } else if (patternType == 'absoluteYearly') {
      pattern['dayOfMonth'] = due.day;
      pattern['month'] = due.month;
    }
    final range = <String, dynamic>{
      'type': 'noEnd',
      'startDate': _graphDateOnly(due),
      'recurrenceTimeZone': _tzCtrl.text.trim().isEmpty ? 'Asia/Shanghai' : _tzCtrl.text.trim(),
    };
    return const JsonEncoder.withIndent('  ').convert({'pattern': pattern, 'range': range});
  }

  Future<void> _clearDueDate() async {
    setState(() {
      _dueCtrl.clear();
      _recurrenceCtrl.clear();
    });
  }

  Future<void> _clearReminder() async {
    setState(() {
      _isReminderOn = false;
      _reminderCtrl.clear();
    });
  }

  Future<void> _clearRecurrence() async {
    setState(() => _recurrenceCtrl.clear());
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _status = '正在先保存本地...';
    });
    try {
      await _setPreferredTimeZone(_tzCtrl.text);
      final t = widget.task;
      final importance = _isImportant ? 'high' : 'normal';
      final recurrence = _recurrenceCtrl.text.trim();
      String savedTaskId;
      if (t == null) {
        savedTaskId = await _service.createTask(
          listId: widget.listId,
          title: _titleCtrl.text,
          bodyText: _noteCtrl.text,
          status: _statusValue,
          importance: importance,
          dueDateTime: _dueCtrl.text,
          dueTimeZone: _tzCtrl.text,
          isReminderOn: _isReminderOn,
          reminderDateTime: _reminderCtrl.text,
          reminderTimeZone: _tzCtrl.text,
          recurrenceJson: recurrence,
          categoriesJson: '',
          isMyDay: _isMyDay,
          writeBack: _writeBack,
        );
      } else {
        savedTaskId = await _service.updateTask(
          task: t,
          title: _titleCtrl.text,
          bodyText: _noteCtrl.text,
          status: _statusValue,
          importance: importance,
          dueDateTime: _dueCtrl.text,
          dueTimeZone: _tzCtrl.text,
          startDateTime: t.startDateTime,
          startTimeZone: t.startTimeZone,
          isReminderOn: _isReminderOn,
          reminderDateTime: _reminderCtrl.text,
          reminderTimeZone: _tzCtrl.text,
          recurrenceJson: recurrence,
          categoriesJson: t.categoriesJson,
          isMyDay: _isMyDay,
          writeBack: _writeBack,
        );
      }
      final savedTaskRecord = await _dao.getTask(savedTaskId);
      final effectiveListId = savedTaskRecord?.listId ?? widget.listId;
      final taskWasReplacedOnRemote = t != null && savedTaskId != t.taskId;
      await _service.saveChecklistItems(
        listId: effectiveListId,
        taskId: savedTaskId,
        writeBack: _writeBack,
        items: taskWasReplacedOnRemote
            ? _steps.where((s) => !s.deleted).map((s) => s.toCreateMap()).toList()
            : _steps.map((s) => s.toMap()).toList(),
      );
      if (!mounted) return;
      Navigator.pop(context, savedTaskId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '保存失败：本地任务内容已保存为待同步状态，但写回 Microsoft To Do 未成功。请在首页或当前列表的黄色提示处重试同步。原始错误：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(widget.task == null ? '新建 To Do 任务' : '修改 To Do 任务')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: IconButton(
                tooltip: _statusValue == 'completed' ? '标记为未完成' : '标记为已完成',
                onPressed: _busy ? null : () => setState(() => _statusValue = _statusValue == 'completed' ? 'notStarted' : 'completed'),
                icon: Icon(_statusValue == 'completed' ? Icons.check_circle : Icons.radio_button_unchecked, size: 34, color: _statusValue == 'completed' ? _todoBlue : Colors.grey),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(child: TextField(controller: _titleCtrl, style: const TextStyle(fontSize: 28), decoration: const InputDecoration(hintText: '任务标题', border: InputBorder.none))),
            IconButton(onPressed: _busy ? null : () => setState(() => _isImportant = !_isImportant), icon: Icon(_isImportant ? Icons.star : Icons.star_border, size: 34, color: _isImportant ? Colors.amber.shade700 : Colors.grey)),
          ]),
          ..._steps.where((s) => !s.deleted).map((s) => Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Row(children: [
                  Checkbox(value: s.isChecked, onChanged: _busy ? null : (v) => setState(() => s.isChecked = v ?? false)),
                  Expanded(child: TextField(controller: s.controller, decoration: const InputDecoration(hintText: '步骤', border: UnderlineInputBorder()))),
                  IconButton(onPressed: _busy ? null : () => setState(() => s.deleted = true), icon: const Icon(Icons.close)),
                ]),
              )),
          TextButton.icon(onPressed: _busy ? null : _addStep, icon: const Icon(Icons.add), label: const Text('下一步')),
          const SizedBox(height: 12),
          _SwitchRow(icon: Icons.wb_sunny_outlined, title: '添加到“我的一天”', value: _isMyDay, onChanged: _busy ? null : (v) => setState(() => _isMyDay = v)),
          const Padding(padding: EdgeInsets.fromLTRB(14, 0, 14, 8), child: Text('My Day 标记会保存在本地智能视图；Microsoft Graph v1.0 的 To Do todoTask 目前没有开放可读写 My Day 字段，个人账户也不能用 Planner beta My Day 接口稳定同步。', style: TextStyle(color: Color(0xFF8B8D98), fontSize: 12))),
          _TodoActionRow(
            icon: Icons.notifications_none,
            title: _isReminderOn && _reminderCtrl.text.trim().isNotEmpty ? '提醒我：${_todoDateTimeLabel(_reminderCtrl.text, withTime: true)}' : '提醒我',
            enabled: _isReminderOn && _reminderCtrl.text.trim().isNotEmpty,
            onTap: _busy ? null : _pickReminderDateTime,
            onClear: _busy || !_isReminderOn ? null : _clearReminder,
          ),
          _TodoActionRow(
            icon: Icons.calendar_month_outlined,
            title: _dueCtrl.text.trim().isEmpty ? '到期' : '到期：${_todoDateTimeLabel(_dueCtrl.text, withTime: true)}',
            enabled: _dueCtrl.text.trim().isNotEmpty,
            onTap: _busy ? null : _pickDueDateTime,
            onClear: _busy || _dueCtrl.text.trim().isEmpty ? null : _clearDueDate,
          ),
          _TodoActionRow(
            icon: Icons.repeat,
            title: _recurrenceCtrl.text.trim().isEmpty ? '重复' : '重复：${_recurrenceLabel(_recurrenceCtrl.text)}',
            enabled: _recurrenceCtrl.text.trim().isNotEmpty,
            onTap: _busy ? null : _pickRecurrence,
            onClear: _busy || _recurrenceCtrl.text.trim().isEmpty ? null : _clearRecurrence,
          ),
          _TodoTextRow(icon: Icons.attach_file, child: const Text('添加文件（当前支持同步读取附件；新增附件需后续单独接入文件选择与上传）', style: TextStyle(color: Color(0xFF8B8D98)))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(4)),
            child: TextField(controller: _noteCtrl, maxLines: 8, decoration: const InputDecoration(hintText: '添加备注', border: InputBorder.none)),
          ),
          const SizedBox(height: 10),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('更多同步字段'),
            children: [
              DropdownButtonFormField<String>(
                value: _statusValue,
                decoration: const InputDecoration(labelText: '状态', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'notStarted', child: Text('未开始')),
                  DropdownMenuItem(value: 'inProgress', child: Text('进行中')),
                  DropdownMenuItem(value: 'completed', child: Text('已完成')),
                  DropdownMenuItem(value: 'waitingOnOthers', child: Text('等待他人')),
                  DropdownMenuItem(value: 'deferred', child: Text('已延期')),
                ],
                onChanged: _busy ? null : (v) => setState(() => _statusValue = v ?? 'notStarted'),
              ),
              const SizedBox(height: 10),
              _TimeZoneDropdown(
                value: _normalizeSupportedTimeZone(_tzCtrl.text),
                onChanged: _busy
                    ? null
                    : (v) async {
                        if (v == null) return;
                        setState(() => _tzCtrl.text = v);
                        await _setPreferredTimeZone(v);
                      },
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('会保存为 To Do 同步时区；Graph 读写请求会带 Prefer: outlook.timezone。中国时区请选择 Asia/Shanghai。', style: TextStyle(color: Color(0xFF8B8D98), fontSize: 12)),
              ),
            ],
          ),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('同时写回 Microsoft To Do'), subtitle: const Text('会先保存本地数据库，再调用 Microsoft Graph 写回。'), value: _writeBack, onChanged: _busy ? null : (v) => setState(() => _writeBack = v)),
          FilledButton.icon(onPressed: _busy ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('保存')),
          if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_status)),
        ],
      ),
    );
  }
}

class _StepEditItem {
  _StepEditItem({this.childId = '', required String title, this.isChecked = false, this.deleted = false}) : controller = TextEditingController(text: title);
  final String childId;
  final TextEditingController controller;
  bool isChecked;
  bool deleted;
  Map<String, dynamic> toMap() => {'childId': childId, 'title': controller.text, 'isChecked': isChecked, 'deleted': deleted};
  Map<String, dynamic> toCreateMap() => {'childId': '', 'title': controller.text, 'isChecked': isChecked, 'deleted': false};
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.enabled});
  final IconData icon;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(4)),
      child: Row(children: [Icon(icon, color: enabled ? _todoBlue : Colors.grey), const SizedBox(width: 14), Expanded(child: Text(label, style: TextStyle(fontSize: 16, color: enabled ? _todoBlue : const Color(0xFF8B8D98))))]),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.icon, required this.title, required this.value, required this.onChanged});
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(4)),
      child: SwitchListTile(secondary: Icon(icon, color: value ? _todoBlue : Colors.grey), title: Text(title), value: value, onChanged: onChanged),
    );
  }
}

class _TodoActionRow extends StatelessWidget {
  const _TodoActionRow({required this.icon, required this.title, required this.enabled, required this.onTap, this.onClear});
  final IconData icon;
  final String title;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(4)),
      child: ListTile(
        leading: Icon(icon, color: enabled ? _todoBlue : Colors.grey),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, color: enabled ? _todoBlue : const Color(0xFF8B8D98))),
        trailing: onClear == null ? null : IconButton(icon: const Icon(Icons.close), onPressed: onClear),
        onTap: onTap,
      ),
    );
  }
}

class _TodoTextRow extends StatelessWidget {
  const _TodoTextRow({required this.icon, required this.child});
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(4)),
      child: Row(children: [Icon(icon, color: Colors.grey), const SizedBox(width: 14), Expanded(child: child)]),
    );
  }
}

const List<String> _supportedGraphTimeZones = <String>[
  'Asia/Shanghai',
  'UTC',
  'America/New_York',
  'America/Los_Angeles',
  'Europe/London',
  'Europe/Paris',
  'Europe/Berlin',
  'Asia/Singapore',
  'Asia/Taipei',
  'Asia/Tokyo',
  'Asia/Seoul',
];

String _normalizeSupportedTimeZone(String timeZone) {
  final value = timeZone.trim();
  switch (value) {
    case 'China Standard Time':
      return 'Asia/Shanghai';
    case 'Eastern Standard Time':
      return 'America/New_York';
    case 'Pacific Standard Time':
      return 'America/Los_Angeles';
    case 'W. Europe Standard Time':
    case 'Romance Standard Time':
      return 'Europe/Paris';
  }
  return _supportedGraphTimeZones.contains(value) ? value : 'Asia/Shanghai';
}

String _timeZoneLabel(String timeZone) {
  switch (timeZone) {
    case 'Asia/Shanghai':
      return '中国时区 UTC+08:00（Asia/Shanghai）';
    case 'UTC':
      return 'UTC / 世界协调时';
    case 'America/New_York':
      return '北美东部时区（America/New_York）';
    case 'America/Los_Angeles':
      return '北美太平洋时区（America/Los_Angeles）';
    case 'Europe/London':
      return '英国时区（Europe/London）';
    case 'Europe/Paris':
      return '欧洲中部时区（Europe/Paris）';
    case 'Europe/Berlin':
      return '德国时区（Europe/Berlin）';
    case 'Asia/Singapore':
      return '新加坡时区 UTC+08:00（Asia/Singapore）';
    case 'Asia/Taipei':
      return '台北时区 UTC+08:00（Asia/Taipei）';
    case 'Asia/Tokyo':
      return '日本时区 UTC+09:00（Asia/Tokyo）';
    case 'Asia/Seoul':
      return '韩国时区 UTC+09:00（Asia/Seoul）';
    default:
      return timeZone;
  }
}

class _TimeZoneDropdown extends StatelessWidget {
  const _TimeZoneDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = _normalizeSupportedTimeZone(value);
    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '时区', border: OutlineInputBorder()),
      items: _supportedGraphTimeZones
          .map((tz) => DropdownMenuItem<String>(value: tz, child: Text(_timeZoneLabel(tz), overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _ChildSection extends StatelessWidget {
  const _ChildSection({required this.title, required this.children});
  final String title;
  final List<TodoChildRecord> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...children.map((c) => Card(
              child: ListTile(
                leading: Icon(c.childType == 'checklistItem' ? (c.isChecked ? Icons.check_box : Icons.check_box_outline_blank) : Icons.link_outlined),
                title: Text(c.title.isEmpty ? c.content : c.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: c.remoteUrl.isEmpty ? null : SelectableText(c.remoteUrl),
              ),
            )),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _TodoEmptyHint extends StatelessWidget {
  const _TodoEmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: const TextStyle(color: Color(0xFF6B7280))),
    );
  }
}

IconData _smartIcon(String listId) {
  switch (listId) {
    case 'smart_myday':
      return Icons.wb_sunny_outlined;
    case 'smart_important':
      return Icons.star_border;
    case 'smart_planned':
      return Icons.calendar_month_outlined;
    case 'smart_all':
      return Icons.all_inclusive;
    case 'smart_completed':
      return Icons.check_circle_outline;
    case 'smart_assigned':
      return Icons.person_outline;
    default:
      return Icons.list_alt_outlined;
  }
}

Color _smartColor(String listId) {
  switch (listId) {
    case 'smart_important':
      return Colors.pink.shade700;
    case 'smart_planned':
      return Colors.teal.shade700;
    case 'smart_all':
      return Colors.red.shade700;
    case 'smart_completed':
      return Colors.brown.shade700;
    case 'smart_assigned':
      return Colors.green.shade700;
    default:
      return _todoBlue;
  }
}

String _summary(String text) {
  final s = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.length <= 70) return s;
  return '${s.substring(0, 70)}...';
}

String _smartViewNote(String listId) {
  switch (listId) {
    case 'smart_myday':
      return '本地视图：包含手动加入“我的一天”的未完成任务，以及今天开始/截止/提醒的未完成任务。';
    case 'smart_important':
      return '本地智能视图：重要程度为“重要”的未完成任务。';
    case 'smart_planned':
      return '本地智能视图：存在开始/截止/提醒时间的未完成任务。';
    case 'smart_all':
      return '本地智能视图：所有已同步的未完成任务。';
    case 'smart_completed':
      return '本地智能视图：所有已完成任务；全量同步会额外读取 Microsoft To Do 已完成任务及其步骤/附件/关联资源。';
    case 'smart_assigned':
      return 'Microsoft Graph To Do v1.0 当前未返回 To Do App 的“已分配给我”视图数据，此处保留同名入口。';
    default:
      return '本地智能视图';
  }
}

String _taskMeta(TodoTaskRecord t) {
  final out = <String>[];
  if (t.listDisplayName.trim().isNotEmpty) out.add('列表：${t.listDisplayName.trim()}');
  if (t.isMyDay) out.add('☼ 我的一天');
  if (t.checklistCount > 0) out.add('第 0 步，共 ${t.checklistCount} 步');
  if (t.dueDateTime.isNotEmpty) out.add('${_todoDateTimeLabel(t.dueDateTime, withTime: true)} 到期');
  if (t.isReminderOn && t.reminderDateTime.isNotEmpty) out.add('${_todoDateTimeLabel(t.reminderDateTime, withTime: true)} 提醒');
  if (t.localStatus != 'synced') out.add(_localStatusName(t.localStatus));
  return out.join(' · ');
}

String _localStatusName(String s) {
  switch (s) {
    case 'synced':
      return '已同步';
    case 'pending_create':
      return '本地新增待写回';
    case 'pending_update':
      return '本地修改待写回';
    case 'pending_delete':
      return '本地删除待写回';
    case 'remote_deleted':
      return '远端已删除';
    case 'virtual':
      return '本地智能视图';
    case 'virtual_limited':
      return '本地智能视图';
    default:
      return s.isEmpty ? '-' : s;
  }
}

String _safeStatus(String v) {
  const values = <String>{'notStarted', 'inProgress', 'completed', 'waitingOnOthers', 'deferred'};
  return values.contains(v) ? v : 'notStarted';
}

String _shortDate(String raw) {
  if (raw.trim().isEmpty) return '';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final local = dt.toLocal();
  return '${local.month}月${local.day}日';
}

String _todoDateTimeLabel(String raw, {bool withTime = false}) {
  if (raw.trim().isEmpty) return '';
  final dt = _parseGraphLocalDateTime(raw);
  if (dt == null) return raw;
  final weekday = const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][dt.weekday - 1];
  final base = '${dt.month}月${dt.day}日$weekday';
  if (!withTime) return base;
  final hm = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  return '$base $hm';
}

String? _recurrenceChoice(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  try {
    final decoded = jsonDecode(s);
    if (decoded is Map) {
      final pattern = decoded['pattern'];
      if (pattern is Map) {
        final type = (pattern['type'] ?? '').toString();
        switch (type) {
          case 'daily':
            return 'daily';
          case 'weekly':
            final days = pattern['daysOfWeek'];
            if (days is List) {
              final set = days.map((e) => e.toString()).toSet();
              if (set.containsAll(<String>{'monday', 'tuesday', 'wednesday', 'thursday', 'friday'}) && !set.contains('saturday') && !set.contains('sunday')) {
                return 'workdays';
              }
            }
            return 'weekly';
          case 'absoluteMonthly':
            return 'monthly';
          case 'absoluteYearly':
            return 'yearly';
        }
      }
    }
  } catch (_) {}
  return null;
}

String _recurrenceLabel(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '重复';
  try {
    final decoded = jsonDecode(s);
    if (decoded is Map) {
      final pattern = decoded['pattern'];
      if (pattern is Map) {
        final type = (pattern['type'] ?? '').toString();
        switch (type) {
          case 'daily':
            return '每天';
          case 'weekly':
            final days = pattern['daysOfWeek'];
            if (days is List) {
              final set = days.map((e) => e.toString()).toSet();
              if (set.containsAll(<String>{'monday', 'tuesday', 'wednesday', 'thursday', 'friday'}) && !set.contains('saturday') && !set.contains('sunday')) {
                return '工作日';
              }
            }
            return '每周';
          case 'absoluteMonthly':
            return '每月';
          case 'absoluteYearly':
            return '每年';
        }
      }
    }
  } catch (_) {}
  return _summary(s);
}

DateTime? _parseGraphLocalDateTime(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final normalized = s.contains(' ') && !s.contains('T') ? s.replaceFirst(' ', 'T') : s;
  return DateTime.tryParse(normalized);
}

String _graphDateTimeText(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)}T${two(dt.hour)}:${two(dt.minute)}:00';
}

String _graphDateOnly(DateTime dt) {
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

String _formatRawTime(String raw) {
  if (raw.trim().isEmpty) return '-';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
