import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'onenote_config.dart';
import 'onenote_dao.dart';
import 'onenote_models.dart';
import 'onenote_service.dart';
import 'todo_dao.dart';
import 'todo_goal_dao.dart';
import 'todo_goal_prompt_config.dart';
import 'todo_pages.dart';

class ExternalDataSyncHomePage extends StatefulWidget {
  const ExternalDataSyncHomePage({super.key});

  @override
  State<ExternalDataSyncHomePage> createState() => _ExternalDataSyncHomePageState();
}

class _ExternalDataSyncHomePageState extends State<ExternalDataSyncHomePage> {
  final _dao = OneNoteDao();
  late final OneNoteAuthService _auth = OneNoteAuthService(dao: _dao);
  bool _busy = false;
  String _account = '';
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _dao.ensureTables();
    await TodoDao().ensureTables();
    await TodoGoalDao().ensureTables();
    final auth = await _auth.currentAuth();
    if (!mounted) return;
    setState(() => _account = (auth?['display_name'] ?? '').toString());
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _status = '正在打开 Microsoft 登录页...';
    });
    try {
      await _auth.signIn();
      await _load();
      if (!mounted) return;
      setState(() => _status = 'Microsoft 登录成功。');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '登录失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    await _auth.disconnect();
    await _load();
    if (!mounted) return;
    setState(() => _status = '已清除本地 Microsoft token。');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('外部数据同步'),
        actions: [
          IconButton(
            tooltip: '统一配置',
            onPressed: _busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MicrosoftExternalConfigPage())).then((_) => _load()),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_queue_outlined),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_account.isEmpty ? '尚未登录 Microsoft' : '已登录：$_account', style: const TextStyle(fontWeight: FontWeight.w900))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('此页只保留 Microsoft 登录/退出与 Note、To Do 两个入口。重定向 URI、Base64 SHA1、API 日志等配置已移入右上角“统一配置”。', style: TextStyle(color: Color(0xFF6B7280))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _connect,
                          icon: const Icon(Icons.login),
                          label: Text(_account.isEmpty ? '登录 Microsoft' : '重新登录'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(onPressed: _busy || _account.isEmpty ? null : _disconnect, child: const Text('退出/清除')),
                    ],
                  ),
                  if (_status.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(_status, style: const TextStyle(color: Color(0xFF374151))),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _EntryCard(
            icon: Icons.menu_book_outlined,
            title: 'Microsoft OneNote / Note',
            subtitle: '按笔记本名称或分区名称同步；按 笔记本 → 分区 → 页面 → 附件 原始结构分页展示。',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OneNoteSyncPage())),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.checklist_rtl_outlined,
            title: 'Microsoft To Do',
            subtitle: '同步任务列表 → 任务 → 检查项/附件/关联资源；支持目标价值系统、AI 自我和谐转化、今日旅程、复盘落地和写回 To Do。',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TodoHomePage())),
          ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class MicrosoftExternalConfigPage extends StatefulWidget {
  const MicrosoftExternalConfigPage({super.key});

  @override
  State<MicrosoftExternalConfigPage> createState() => _MicrosoftExternalConfigPageState();
}

class _MicrosoftExternalConfigPageState extends State<MicrosoftExternalConfigPage> {
  final _dao = OneNoteDao();
  final _todoDao = TodoDao();
  final _promptConfig = TodoGoalPromptConfig();
  final _redirectCtrl = TextEditingController();
  final _goalSystemPromptCtrl = TextEditingController();
  final _goalTaskPromptCtrl = TextEditingController();
  final _goalReviewPromptCtrl = TextEditingController();
  final _goalSolutionPromptCtrl = TextEditingController();
  List<Map<String, Object?>> _noteLogs = [];
  List<Map<String, Object?>> _todoLogs = [];
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _redirectCtrl.dispose();
    _goalSystemPromptCtrl.dispose();
    _goalTaskPromptCtrl.dispose();
    _goalReviewPromptCtrl.dispose();
    _goalSolutionPromptCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _dao.ensureTables();
    await _todoDao.ensureTables();
    final uri = await _dao.getRedirectUri();
    final promptTemplates = await _promptConfig.load();
    final noteLogs = await _dao.recentApiLogs(limit: 30);
    final todoLogs = await _todoDao.recentApiLogs(limit: 30);
    if (!mounted) return;
    setState(() {
      _redirectCtrl.text = uri;
      _goalSystemPromptCtrl.text = promptTemplates.systemPrompt;
      _goalTaskPromptCtrl.text = promptTemplates.taskPrompt;
      _goalReviewPromptCtrl.text = promptTemplates.reviewPrompt;
      _goalSolutionPromptCtrl.text = promptTemplates.solutionPrompt;
      _noteLogs = noteLogs;
      _todoLogs = todoLogs;
    });
  }

  Future<void> _copyRedirectUri() async {
    final value = _redirectCtrl.text.trim().isEmpty ? OneNoteConfig.defaultRedirectUri : _redirectCtrl.text.trim();
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    setState(() => _status = '已复制重定向 URI：$value');
  }

  Future<void> _saveRedirectUri() async {
    try {
      await _dao.saveRedirectUri(_redirectCtrl.text.trim());
      await OneNoteAuthService(dao: _dao).disconnect();
      await _load();
      if (!mounted) return;
      setState(() => _status = '已保存重定向 URI，并已清除旧 token。请返回外部数据同步页重新登录。');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '保存失败：$e');
    }
  }

  Future<void> _resetRedirectUri() async {
    await _dao.resetRedirectUri();
    await OneNoteAuthService(dao: _dao).disconnect();
    await _load();
    if (!mounted) return;
    setState(() => _status = '已恢复默认重定向 URI，并已清除旧 token。');
  }


  Future<void> _saveGoalAiPrompts() async {
    await _promptConfig.save(TodoGoalPromptTemplates(
      systemPrompt: _goalSystemPromptCtrl.text,
      taskPrompt: _goalTaskPromptCtrl.text,
      reviewPrompt: _goalReviewPromptCtrl.text,
      solutionPrompt: _goalSolutionPromptCtrl.text,
    ));
    await _load();
    if (!mounted) return;
    setState(() => _status = '已保存 To Do 目标实践系统的 AI 提示词配置。');
  }

  Future<void> _resetGoalAiPrompts() async {
    await _promptConfig.reset();
    await _load();
    if (!mounted) return;
    setState(() => _status = '已恢复 To Do 目标实践系统默认 AI 提示词。');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Microsoft 同步配置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Microsoft 重定向 URI 配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('登录失败 invalid_request 时，通常是这里的重定向 URI 与 Microsoft Entra 中登记的不完全一致。修改后会清除旧 token。', style: TextStyle(color: Color(0xFF6B7280))),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _redirectCtrl,
                    decoration: const InputDecoration(labelText: '重定向 URI / Redirect URI', hintText: OneNoteConfig.defaultRedirectUri, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  SelectableText('默认 Base64 SHA1：${OneNoteConfig.releaseBase64Sha1}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(onPressed: _copyRedirectUri, icon: const Icon(Icons.copy), label: const Text('复制 URI')),
                      OutlinedButton.icon(onPressed: _saveRedirectUri, icon: const Icon(Icons.save_outlined), label: const Text('保存 URI')),
                      TextButton.icon(onPressed: _resetRedirectUri, icon: const Icon(Icons.restore), label: const Text('恢复默认')),
                    ],
                  ),
                  if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_status)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('当前应用配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  SizedBox(height: 8),
                  _KeyValue(label: 'Client ID', value: OneNoteConfig.clientId),
                  _KeyValue(label: 'Package name', value: OneNoteConfig.packageName),
                  _KeyValue(label: 'Base64 SHA1', value: OneNoteConfig.releaseBase64Sha1),
                  _KeyValue(label: '需要的 Microsoft Graph 权限', value: 'User.Read、Notes.Read、Tasks.Read、Tasks.ReadWrite、offline_access'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _GoalAiPromptConfigCard(
            systemCtrl: _goalSystemPromptCtrl,
            taskCtrl: _goalTaskPromptCtrl,
            reviewCtrl: _goalReviewPromptCtrl,
            solutionCtrl: _goalSolutionPromptCtrl,
            onSave: _saveGoalAiPrompts,
            onReset: _resetGoalAiPrompts,
          ),
          const SizedBox(height: 12),
          _LogsTile(title: 'OneNote 最近 API 日志', logs: _noteLogs),
          _LogsTile(title: 'Microsoft To Do 最近 API 日志', logs: _todoLogs),
        ],
      ),
    );
  }
}


class _GoalAiPromptConfigCard extends StatelessWidget {
  const _GoalAiPromptConfigCard({
    required this.systemCtrl,
    required this.taskCtrl,
    required this.reviewCtrl,
    required this.solutionCtrl,
    required this.onSave,
    required this.onReset,
  });

  final TextEditingController systemCtrl;
  final TextEditingController taskCtrl;
  final TextEditingController reviewCtrl;
  final TextEditingController solutionCtrl;
  final VoidCallback onSave;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('To Do 目标实践系统 AI 提示词', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text(
              '这里统一配置 Microsoft To Do 目标转化、今日实践和复盘落地所使用的 AI 提示词。可使用占位符：{{VALUE_SYSTEM}}、{{TASK_TITLE}}、{{TASK_BODY}}、{{TASK_LIST}}、{{TASK_IMPORTANCE}}、{{TASK_DUE}}、{{TASK_STATUS}}、{{GOAL_TITLE}}、{{DEEP_MEANING}}、{{PROCESS_VALUE}}、{{ACTION_TITLE}}、{{COMPLETED_TEXT}}、{{USER_REFLECTION}}；独立方案请求还支持 {{RESULT_GOAL}}、{{VALUE_GOAL}}、{{PROCESS_GOAL}}、{{CORE_VALUES}}、{{OBSTACLE_SUMMARY}}、{{TODAY_ACTION}}。',
              style: TextStyle(color: Color(0xFF6B7280), height: 1.45),
            ),
            const SizedBox(height: 10),
            _PromptEditorTile(title: '系统提示词', subtitle: '控制 AI 的身份、语气和输出格式。', controller: systemCtrl, minLines: 4, maxLines: 10),
            _PromptEditorTile(title: '任务转目标提示词', subtitle: '用于把 Microsoft To Do 任务转化为方向、意义、过程价值和今日最小行动。', controller: taskCtrl, minLines: 8, maxLines: 18),
            _PromptEditorTile(title: '独立问题解决方案提示词', subtitle: '用于把目标当作现实问题来定义、推导、比较方案、生成问题树和参考案例；AI只做决策支持，不替用户选择。', controller: solutionCtrl, minLines: 8, maxLines: 18),
            _PromptEditorTile(title: '每日复盘提示词', subtitle: '用于把完成/未完成记录转化为过程洞察和明日最小一步。', controller: reviewCtrl, minLines: 8, maxLines: 18),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(onPressed: onSave, icon: const Icon(Icons.save_outlined), label: const Text('保存提示词')),
                OutlinedButton.icon(onPressed: onReset, icon: const Icon(Icons.restore), label: const Text('恢复默认')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptEditorTile extends StatelessWidget {
  const _PromptEditorTile({required this.title, required this.subtitle, required this.controller, required this.minLines, required this.maxLines});

  final String title;
  final String subtitle;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        children: [
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class OneNoteSyncPage extends StatefulWidget {
  const OneNoteSyncPage({super.key});

  @override
  State<OneNoteSyncPage> createState() => _OneNoteSyncPageState();
}

class _OneNoteSyncPageState extends State<OneNoteSyncPage> {
  final _dao = OneNoteDao();
  late final _auth = OneNoteAuthService(dao: _dao);
  late final _sync = OneNoteSyncService(dao: _dao, auth: _auth);
  final _notebookCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  bool _busy = false;
  String _status = '';
  List<OneNoteNotebookRecord> _notebooks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notebookCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _dao.ensureTables();
    final notebooks = await _dao.listNotebooks();
    if (!mounted) return;
    setState(() => _notebooks = notebooks);
  }

  Future<void> _startSync() async {
    final notebook = _notebookCtrl.text.trim();
    final section = _sectionCtrl.text.trim();
    if (notebook.isEmpty && section.isEmpty) {
      setState(() => _status = '请输入笔记本名称或分区名称。为提升效率，不会默认读取所有笔记本。');
      return;
    }
    setState(() {
      _busy = true;
      _status = '准备同步 OneNote...';
    });
    try {
      final result = await _sync.syncByNames(
        notebookName: notebook,
        sectionName: section,
        onProgress: (m) {
          if (!mounted) return;
          setState(() => _status = m);
        },
      );
      await _load();
      if (!mounted) return;
      setState(() => _status = '同步完成：笔记本 ${result.notebooks} 个，分区 ${result.sections} 个，页面 ${result.pages} 个，附件 ${result.attachments} 个。');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '同步失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Microsoft OneNote')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('按名称同步 OneNote 数据', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('为提升同步效率，必须输入笔记本名称或分区名称。输入笔记本名称时，只读取该笔记本；同时输入分区名称时，只读取该笔记本下的目标分区。', style: TextStyle(color: Color(0xFF6B7280))),
                  const SizedBox(height: 12),
                  TextField(controller: _notebookCtrl, decoration: const InputDecoration(labelText: '笔记本名称（可选，但建议填写）', hintText: '例如：App测试日记', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: _sectionCtrl, decoration: const InputDecoration(labelText: '分区名称（可选）', hintText: '例如：2026 / 日记 / 工作', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  FilledButton.icon(onPressed: _busy ? null : _startSync, icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_sync), label: const Text('开始同步 OneNote')),
                  if (_status.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)), child: Text(_status)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [const Expanded(child: Text('已同步 OneNote 结构', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), Text('${_notebooks.length} 个笔记本', style: const TextStyle(color: Color(0xFF6B7280)))]),
          const SizedBox(height: 8),
          if (_notebooks.isEmpty)
            const _EmptyHint(text: '暂无已同步数据。请先登录 Microsoft，并输入笔记本名称或分区名称同步。')
          else
            ..._notebooks.map((n) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(n.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('分区 ${n.sectionCount} 个 · 页面 ${n.pageCount} 个\n最后修改：${_formatTime(n.lastModifiedTime)}'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OneNoteNotebookPage(notebookId: n.id))),
                  ),
                )),
        ],
      ),
    );
  }
}

class OneNoteNotebookPage extends StatefulWidget {
  const OneNoteNotebookPage({super.key, required this.notebookId});
  final String notebookId;

  @override
  State<OneNoteNotebookPage> createState() => _OneNoteNotebookPageState();
}

class _OneNoteNotebookPageState extends State<OneNoteNotebookPage> {
  final _dao = OneNoteDao();
  OneNoteNotebookRecord? _notebook;
  List<OneNoteSectionRecord> _sections = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final n = await _dao.getNotebook(widget.notebookId);
    final s = await _dao.listSections(widget.notebookId);
    if (!mounted) return;
    setState(() {
      _notebook = n;
      _sections = s;
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = _notebook;
    return Scaffold(
      appBar: AppBar(title: Text(n?.displayName ?? 'OneNote 笔记本')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (n != null)
            Card(child: ListTile(leading: const Icon(Icons.menu_book_outlined), title: Text(n.displayName), subtitle: Text('分区 ${n.sectionCount} 个 · 页面 ${n.pageCount} 个'))),
          const SizedBox(height: 12),
          const Text('分区', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_sections.isEmpty)
            const _EmptyHint(text: '这个笔记本下暂未同步到分区。')
          else
            ..._sections.map((s) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(s.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('页面 ${s.pageCount} 个 · 最后修改：${_formatTime(s.lastModifiedTime)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OneNoteSectionPage(sectionId: s.id))),
                  ),
                )),
        ],
      ),
    );
  }
}

class OneNoteSectionPage extends StatefulWidget {
  const OneNoteSectionPage({super.key, required this.sectionId});
  final String sectionId;

  @override
  State<OneNoteSectionPage> createState() => _OneNoteSectionPageState();
}

class _OneNoteSectionPageState extends State<OneNoteSectionPage> {
  final _dao = OneNoteDao();
  OneNoteSectionRecord? _section;
  final List<OneNotePageRecord> _pages = [];
  bool _loading = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 30;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final s = await _dao.getSection(widget.sectionId);
    if (!mounted) return;
    setState(() => _section = s);
    await _loadMore(reset: true);
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (reset) {
        _pages.clear();
        _offset = 0;
        _hasMore = true;
      }
      final rows = await _dao.listPages(widget.sectionId, limit: _limit, offset: _offset);
      if (!mounted) return;
      setState(() {
        _pages.addAll(rows);
        _offset += rows.length;
        _hasMore = rows.length == _limit;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _section;
    return Scaffold(
      appBar: AppBar(title: Text(s?.displayName ?? 'OneNote 分区')),
      body: RefreshIndicator(
        onRefresh: () => _loadMore(reset: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (s != null) Card(child: ListTile(leading: const Icon(Icons.folder_outlined), title: Text(s.displayName), subtitle: Text('页面 ${s.pageCount} 个'))),
            const SizedBox(height: 12),
            const Text('页面', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (_pages.isEmpty && !_loading)
              const _EmptyHint(text: '这个分区下暂未同步到页面。')
            else
              ..._pages.map((p) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(p.title.isEmpty ? '未命名页面' : p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${_summary(p.plainText)}\n附件 ${p.attachmentCount} 个 · ${_formatTime(p.lastModifiedTime)}', maxLines: 3, overflow: TextOverflow.ellipsis),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OneNotePageDetailPage(pageId: p.id))),
                    ),
                  )),
            if (_loading)
              const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
            else if (_hasMore)
              OutlinedButton.icon(onPressed: () => _loadMore(), icon: const Icon(Icons.expand_more), label: const Text('加载更多页面')),
          ],
        ),
      ),
    );
  }
}

class OneNotePageDetailPage extends StatefulWidget {
  const OneNotePageDetailPage({super.key, required this.pageId});
  final String pageId;

  @override
  State<OneNotePageDetailPage> createState() => _OneNotePageDetailPageState();
}

class _OneNotePageDetailPageState extends State<OneNotePageDetailPage> {
  final _dao = OneNoteDao();
  OneNotePageRecord? _page;
  List<OneNoteAttachmentRecord> _attachments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _dao.getPage(widget.pageId);
    final a = await _dao.listAttachments(widget.pageId);
    if (!mounted) return;
    setState(() {
      _page = p;
      _attachments = a;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _page;
    return Scaffold(
      appBar: AppBar(title: Text(p?.title.isNotEmpty == true ? p!.title : 'OneNote 页面')),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(p.title.isEmpty ? '未命名页面' : p.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('创建：${_formatTime(p.createdTime)}\n修改：${_formatTime(p.lastModifiedTime)}', style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 16),
                SelectableText(p.plainText.isEmpty ? '此页面没有可显示的文字内容。若原页面主要是图片/音频，请查看下方附件。' : p.plainText, style: const TextStyle(fontSize: 16, height: 1.55)),
                const SizedBox(height: 18),
                if (_attachments.isNotEmpty) ...[
                  const Text('附件', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ..._attachments.map((a) => _AttachmentTile(attachment: a)),
                ],
              ],
            ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment});
  final OneNoteAttachmentRecord attachment;

  @override
  Widget build(BuildContext context) {
    final isImage = attachment.mimeType.startsWith('image/') && File(attachment.localPath).existsSync();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(_iconForMime(attachment.mimeType)), const SizedBox(width: 10), Expanded(child: Text(attachment.fileName, maxLines: 1, overflow: TextOverflow.ellipsis)), Text(_formatBytes(attachment.sizeBytes), style: const TextStyle(color: Color(0xFF6B7280)))]),
            if (isImage) ...[
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(attachment.localPath), fit: BoxFit.cover)),
            ] else ...[
              const SizedBox(height: 6),
              Text(attachment.localPath, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForMime(String mime) {
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (mime.contains('pdf')) return Icons.picture_as_pdf_outlined;
    return Icons.attach_file;
  }
}

class _LogsTile extends StatelessWidget {
  const _LogsTile({required this.title, required this.logs});
  final String title;
  final List<Map<String, Object?>> logs;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(title),
      children: logs.isEmpty
          ? [const ListTile(title: Text('暂无日志'))]
          : logs
              .map((l) => ListTile(
                    dense: true,
                    title: Text((l['endpoint'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('HTTP ${l['status_code'] ?? '-'}  ${l['error_message'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(label, style: const TextStyle(color: Color(0xFF6B7280))), subtitle: SelectableText(value));
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(14)), child: Text(text, style: const TextStyle(color: Color(0xFF6B7280))));
}

String _summary(String text) {
  final s = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.length <= 70) return s;
  return '${s.substring(0, 70)}...';
}

String _formatTime(String raw) {
  if (raw.trim().isEmpty) return '-';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '-';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
