import 'package:flutter/material.dart';

import '../pages/settings_page.dart';
import 'happiness_ai_service.dart';
import 'happiness_training_specs.dart';
import 'happiness_dao.dart';
import 'happiness_models.dart';
import 'happiness_seed.dart';

class HappinessModuleHomePage extends StatefulWidget {
  const HappinessModuleHomePage({super.key});

  @override
  State<HappinessModuleHomePage> createState() => _HappinessModuleHomePageState();
}

class _HappinessModuleHomePageState extends State<HappinessModuleHomePage> {
  final HappinessDao _dao = HappinessDao();
  final HappinessAiService _ai = HappinessAiService();

  int _idx = 0;
  List<HappinessAction> _actions = <HappinessAction>[];
  List<HappinessReviewEntry> _reviews = <HappinessReviewEntry>[];
  Set<String> _doneUnits = <String>{};
  Map<String, String> _prompts = <String, String>{};
  Map<String, String> _aiState = const <String, String>{'label': '读取中…'};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<HappinessAction> actions = List<HappinessAction>.from(await _dao.loadActions());
      final List<HappinessReviewEntry> reviews = List<HappinessReviewEntry>.from(await _dao.loadReviews());
      final Set<String> doneUnits = await _dao.loadCompletedUnits();
      final Map<String, String> prompts = await _dao.loadPrompts();
      final Map<String, String> aiState = await _ai.getGlobalAiState();
      if (!mounted) return;
      setState(() {
        _actions = actions;
        _reviews = reviews;
        _doneUnits = doneUnits;
        _prompts = prompts;
        _aiState = aiState;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actions = <HappinessAction>[];
        _reviews = <HappinessReviewEntry>[];
        _doneUnits = <String>{};
        _prompts = <String, String>{};
        _aiState = const <String, String>{
          'provider': 'none',
          'model': 'none',
          'label': '模块初始化失败，已回退到默认模式',
          'available': '0',
        };
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('知行合一幸福课模块初始化失败，已使用默认模式：$e')),
        );
      }
    }
  }

  Future<void> _saveAction(HappinessAction action) async {
    await _dao.saveAction(action);
    await _dao.markUnitCompleted(action.unitId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入行动中心')));
  }

  Future<void> _updateAction(HappinessAction action) async {
    await _dao.updateAction(action);
    await _load();
  }

  Future<void> _saveReview(HappinessReviewEntry review) async {
    await _dao.saveReview(review);
    await _dao.markUnitCompleted(review.unitId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存复盘')));
  }

  Future<void> _toggleActionDone(HappinessAction action, bool done) async {
    await _dao.markActionDone(action.id, done);
    await _load();
  }

  Future<void> _openUnit(HappinessUnit unit) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HappinessUnitDetailPage(
          unit: unit,
          aiState: _aiState,
          promptOverrides: _prompts,
          onSaveAction: _saveAction,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openAction(HappinessAction action) async {
    final HappinessUnit? unit = _findUnit(action.unitId);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HappinessActionDetailPage(
          action: action,
          unit: unit,
          onSaveAction: _updateAction,
          onOpenReview: unit == null
              ? null
              : () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HappinessReviewPage(
                        unit: unit,
                        prompts: _prompts,
                        onSave: _saveReview,
                      ),
                    ),
                  );
                },
        ),
      ),
    );
    await _load();
  }

  Future<void> _openScene(String sceneName) async {
    final List<HappinessUnit> units = happinessUnits.where((HappinessUnit u) => happinessScenes[sceneName]?.contains(u.id) ?? false).toList();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HappinessSceneDetailPage(
          sceneName: sceneName,
          units: units,
          onOpenUnit: _openUnit,
          onStartMission: (HappinessUnit unit) async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HappinessSceneMissionPlayPage(
                  unit: unit,
                  promptOverrides: _prompts,
                  onSaveAction: _saveAction,
                ),
              ),
            );
          },
        ),
      ),
    );
    await _load();
  }

  HappinessUnit? _findUnit(String id) {
    for (final HappinessUnit unit in happinessUnits) {
      if (unit.id == id) return unit;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      _OverviewPage(
        aiState: _aiState,
        unitDoneCount: _doneUnits.length,
        actionDoneCount: _actions.where((HappinessAction e) => e.status == 'done').length,
        inProgressCount: _actions.where((HappinessAction e) => e.status == 'doing').length,
        totalActions: _actions.length,
        reviewCount: _reviews.length,
        todayUnit: happinessUnits[(DateTime.now().day - 1) % happinessUnits.length],
        latestAction: _actions.isEmpty ? null : _actions.first,
        onOpenUnit: _openUnit,
        onOpenAction: _openAction,
        onOpenDiagnosis: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => HappinessDiagnosisPage(onOpenUnit: _openUnit)));
          await _load();
        },
        onOpenGrowth: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HappinessGrowthArchivePage(actions: _actions, reviews: _reviews, doneUnits: _doneUnits, ai: _ai, prompts: _prompts, onSaveAction: _saveAction),
            ),
          );
        },
        onOpenPromptStudio: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => HappinessPromptStudioPage(initialPrompts: _prompts)),
          );
          await _load();
        },
        onOpenSettings: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
      ),
      _CourseMapPage(doneUnits: _doneUnits, onOpenUnit: _openUnit),
      _CityPage(onOpenScene: _openScene),
      _ActionReviewPage(
        actions: _actions,
        reviews: _reviews,
        onToggleDone: _toggleActionDone,
        onOpenReview: (HappinessUnit unit) async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HappinessReviewPage(unit: unit, prompts: _prompts, onSave: _saveReview),
            ),
          );
          await _load();
        },
        onOpenAction: _openAction,
        onOpenUnit: _openUnit,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('知行合一幸福课'),
        actions: <Widget>[
          IconButton(
            tooltip: '成长档案',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HappinessGrowthArchivePage(actions: _actions, reviews: _reviews, doneUnits: _doneUnits, ai: _ai, prompts: _prompts, onSaveAction: _saveAction),
                ),
              );
            },
          ),
          IconButton(
            tooltip: '问题诊断',
            icon: const Icon(Icons.psychology_alt_outlined),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => HappinessDiagnosisPage(onOpenUnit: _openUnit)));
              await _load();
            },
          ),
          IconButton(
            tooltip: '提示词工作台',
            icon: const Icon(Icons.tune),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => HappinessPromptStudioPage(initialPrompts: _prompts)));
              await _load();
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: _loading ? const Center(child: CircularProgressIndicator()) : pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (int i) => setState(() => _idx = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: '总览'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: '课程'),
          NavigationDestination(icon: Icon(Icons.travel_explore_outlined), label: '知行城'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: '行动/复盘'),
        ],
      ),
    );
  }
}

class _OverviewPage extends StatelessWidget {
  final Map<String, String> aiState;
  final int unitDoneCount;
  final int actionDoneCount;
  final int inProgressCount;
  final int totalActions;
  final int reviewCount;
  final HappinessUnit todayUnit;
  final HappinessAction? latestAction;
  final Future<void> Function(HappinessUnit unit) onOpenUnit;
  final Future<void> Function(HappinessAction action) onOpenAction;
  final VoidCallback onOpenDiagnosis;
  final VoidCallback onOpenGrowth;
  final VoidCallback onOpenPromptStudio;
  final VoidCallback onOpenSettings;

  const _OverviewPage({
    required this.aiState,
    required this.unitDoneCount,
    required this.actionDoneCount,
    required this.inProgressCount,
    required this.totalActions,
    required this.reviewCount,
    required this.todayUnit,
    required this.latestAction,
    required this.onOpenUnit,
    required this.onOpenAction,
    required this.onOpenDiagnosis,
    required this.onOpenGrowth,
    required this.onOpenPromptStudio,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: <Color>[Color(0xFF111827), Color(0xFF374151)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('把课程真正变成行动', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('39 单元课程学习 → 知行城模拟操练 → 现实任务 → 复盘闭环', style: TextStyle(color: Colors.white70, height: 1.45)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _overviewChip('已学单元 $unitDoneCount/39'),
                  _overviewChip('进行中 $inProgressCount'),
                  _overviewChip('已完成 $actionDoneCount/$totalActions'),
                  _overviewChip('复盘 $reviewCount 次'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ListTile(
            title: const Text('AI 状态（来自全局设置）', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(aiState['label'] ?? '未配置'),
            trailing: TextButton(onPressed: onOpenSettings, child: const Text('去全局设置')),
          ),
        ),
        const SizedBox(height: 14),
        _ModuleCard(
          icon: Icons.menu_book_outlined,
          title: '今日课程',
          subtitle: '${todayUnit.id} · ${todayUnit.title}\n${todayUnit.oneLiner}',
          onTap: () => onOpenUnit(todayUnit),
        ),
        const SizedBox(height: 12),
        if (latestAction != null)
          _ModuleCard(
            icon: Icons.playlist_add_check_circle_outlined,
            title: '今天继续这个行动',
            subtitle: '${latestAction!.title}\n状态：${_statusLabel(latestAction!.status)}',
            onTap: () => onOpenAction(latestAction!),
          ),
        if (latestAction != null) const SizedBox(height: 12),
        _ModuleCard(
          icon: Icons.psychology_outlined,
          title: '问题诊断',
          subtitle: '从“怕失败、怕被拒绝、只盯结果、总想完美”这些现实问题切入',
          onTap: onOpenDiagnosis,
        ),
        const SizedBox(height: 12),
        _ModuleCard(
          icon: Icons.auto_graph_outlined,
          title: '成长档案',
          subtitle: '查看你已经学到的单元、行动进展、复盘积累与常见触发模式',
          onTap: onOpenGrowth,
        ),
        const SizedBox(height: 12),
        _ModuleCard(
          icon: Icons.tune,
          title: 'Prompt Studio',
          subtitle: '配置课程解释、行动生成、复盘、问题诊断、知行城 NPC 与成长档案归纳的提示词',
          onTap: onOpenPromptStudio,
        ),
      ],
    );
  }

  static Widget _overviewChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}

class _CourseMapPage extends StatefulWidget {
  final Set<String> doneUnits;
  final Future<void> Function(HappinessUnit unit) onOpenUnit;
  const _CourseMapPage({required this.doneUnits, required this.onOpenUnit});

  @override
  State<_CourseMapPage> createState() => _CourseMapPageState();
}

class _CourseMapPageState extends State<_CourseMapPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<int, List<HappinessUnit>> groups = <int, List<HappinessUnit>>{};
    for (final HappinessUnit unit in happinessUnits) {
      if (_filter.trim().isNotEmpty) {
        final String q = _filter.trim();
        if (!unit.id.contains(q) && !unit.title.contains(q) && !unit.summary.contains(q) && !unit.concepts.any((String c) => c.contains(q))) {
          continue;
        }
      }
      groups.putIfAbsent(unit.lecture, () => <HappinessUnit>[]).add(unit);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: '搜索单元、概念、主题',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onChanged: (String v) => setState(() => _filter = v),
        ),
        const SizedBox(height: 14),
        ...groups.entries.map((MapEntry<int, List<HappinessUnit>> entry) {
          final int lecture = entry.key;
          final List<HappinessUnit> items = entry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Lecture $lecture · ${items.length} 单元', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              ...items.map((HappinessUnit unit) => Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: widget.doneUnits.contains(unit.id) ? Colors.green.shade100 : Colors.grey.shade200,
                        child: Icon(widget.doneUnits.contains(unit.id) ? Icons.check : Icons.menu_book_outlined, color: Colors.black87),
                      ),
                      title: Text('${unit.id} ${unit.title}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${unit.oneLiner}\n概念：${unit.concepts.take(3).join('、')}', maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => widget.onOpenUnit(unit),
                    ),
                  )),
              const SizedBox(height: 10),
            ],
          );
        }),
      ],
    );
  }
}

class _CityPage extends StatelessWidget {
  final Future<void> Function(String sceneName) onOpenScene;
  const _CityPage({required this.onOpenScene});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        const Text('知行城', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('先在虚拟场景里练，再迁移到现实行动。每个场景都围绕课程理论设计。', style: TextStyle(color: Color(0xFF6B7280))),
        const SizedBox(height: 14),
        ...happinessScenes.entries.map((MapEntry<String, List<String>> entry) {
          final List<HappinessUnit> units = happinessUnits.where((HappinessUnit u) => entry.value.contains(u.id)).toList();
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${_sceneIntro(entry.key)}\n关联单元：${units.map((HappinessUnit e) => e.id).join('、')}', maxLines: 4, overflow: TextOverflow.ellipsis),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpenScene(entry.key),
            ),
          );
        }),
      ],
    );
  }
}

class _ActionReviewPage extends StatelessWidget {
  final List<HappinessAction> actions;
  final List<HappinessReviewEntry> reviews;
  final Future<void> Function(HappinessAction action, bool done) onToggleDone;
  final Future<void> Function(HappinessUnit unit) onOpenReview;
  final Future<void> Function(HappinessAction action) onOpenAction;
  final Future<void> Function(HappinessUnit unit) onOpenUnit;

  const _ActionReviewPage({
    required this.actions,
    required this.reviews,
    required this.onToggleDone,
    required this.onOpenReview,
    required this.onOpenAction,
    required this.onOpenUnit,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, HappinessUnit> unitMap = <String, HappinessUnit>{for (final HappinessUnit u in happinessUnits) u.id: u};
    final int todo = actions.where((HappinessAction e) => e.status == 'todo').length;
    final int doing = actions.where((HappinessAction e) => e.status == 'doing').length;
    final int done = actions.where((HappinessAction e) => e.status == 'done').length;
    final int skipped = actions.where((HappinessAction e) => e.status == 'skipped').length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        const Text('行动中心', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _StatPill(label: '待开始 $todo'),
            _StatPill(label: '进行中 $doing'),
            _StatPill(label: '已完成 $done'),
            _StatPill(label: '回避/跳过 $skipped'),
          ],
        ),
        const SizedBox(height: 12),
        if (actions.isEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('还没有行动。可以先从课程单元里添加默认行动，或让 AI 生成行动。'),
            ),
          ),
        if (actions.isEmpty) ...<Widget>[
          const SizedBox(height: 12),
          const Text('推荐先开始的单元', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...happinessUnits.take(4).map((HappinessUnit unit) => Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: ListTile(
                  title: Text('${unit.id} ${unit.title}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('建议动作：${unit.defaultActionTitle}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpenUnit(unit),
                ),
              )),
        ],
        ...actions.map((HappinessAction action) => Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: Text(action.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
                          child: Text(action.source),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(action.body, style: const TextStyle(height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        ChoiceChip(label: Text(_statusLabel(action.status)), selected: true, onSelected: (_) {}),
                        ActionChip(label: const Text('查看详情'), onPressed: () => onOpenAction(action)),
                        ActionChip(label: const Text('完成'), onPressed: () => onToggleDone(action, true)),
                        if (unitMap[action.unitId] != null) ActionChip(label: const Text('去复盘'), onPressed: () => onOpenReview(unitMap[action.unitId]!)),
                      ],
                    ),
                    if (action.realityVersion.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text('现实映射：${action.realityRole.isEmpty ? '' : '[${action.realityRole}] '}${action.realityVersion}', style: const TextStyle(color: Color(0xFF6B7280))),
                    ],
                    if (action.factLog.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text('事实记录：${action.factLog}', style: const TextStyle(color: Color(0xFF6B7280))),
                    ],
                    if (action.nextStepNote.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text('下一步：${action.nextStepNote}', style: const TextStyle(color: Color(0xFF374151))),
                    ],
                  ],
                ),
              ),
            )),
        const SizedBox(height: 18),
        const Text('最近复盘', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (reviews.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('还没有复盘记录。'),
            ),
          ),
        ...reviews.take(8).map((HappinessReviewEntry r) => Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ListTile(
                title: Text(r.unitTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('事实：${r.fact}\n总结：${r.aiSummary}', maxLines: 4, overflow: TextOverflow.ellipsis),
              ),
            )),
      ],
    );
  }
}

class HappinessUnitDetailPage extends StatelessWidget {
  final HappinessUnit unit;
  final Map<String, String> aiState;
  final Map<String, String> promptOverrides;
  final Future<void> Function(HappinessAction action) onSaveAction;

  const HappinessUnitDetailPage({super.key, required this.unit, required this.aiState, required this.promptOverrides, required this.onSaveAction});

  @override
  Widget build(BuildContext context) {
    final HappinessAction defaultAction = HappinessAction(
      id: 'default_${unit.id}_${DateTime.now().millisecondsSinceEpoch}',
      unitId: unit.id,
      unitTitle: unit.title,
      source: 'default',
      title: unit.defaultActionTitle,
      body: actionPlanFor(unit, 'standard').intro,
      difficulty: 'Easy',
      duration: '10-20分钟',
      successCriteria: '完成一次和本单元概念直接相关的现实动作。',
      fallbackAction: '如果太难，就把动作缩小到 5 分钟版本。',
      reviewQuestion: unit.reflectionQuestion,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      planNote: actionPlanFor(unit, 'standard').steps.first,
      obstacleNote: actionPlanFor(unit, 'standard').fallbackAction,
      nextStepNote: actionPlanFor(unit, 'standard').steps.last,
      steps: actionPlanFor(unit, 'standard').steps,
      stepMarks: List<bool>.filled(actionPlanFor(unit, 'standard').steps.length, false),
    );

    return Scaffold(
      appBar: AppBar(title: Text('${unit.id} ${unit.title}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HappinessAiActionPage(unit: unit, promptOverrides: promptOverrides, onSaveAction: onSaveAction),
          ),
        ),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('AI 生成行动'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: <Widget>[
          Text(unit.oneLiner, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(unit.summary, style: const TextStyle(height: 1.6)),
          const SizedBox(height: 12),
          _SectionBox(title: '课程完整学习内容（完整复制版）', child: SelectableText(unit.fullContent, style: const TextStyle(height: 1.75))),
          const SizedBox(height: 14),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              title: const Text('AI 状态（来自全局设置）', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(aiState['label'] ?? '未配置'),
              trailing: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
                child: const Text('去全局设置'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionBox(title: '核心概念', child: Wrap(spacing: 8, runSpacing: 8, children: unit.concepts.map((String e) => Chip(label: Text(e))).toList())),
          const SizedBox(height: 12),
          _SectionBox(
            title: '概念深度分析：从抽象回到经验直观',
            child: Column(children: unit.concepts.map((String concept) => _ConceptLensCard(unit: unit, concept: concept)).toList()),
          ),
          const SizedBox(height: 12),
          _SectionBox(title: '是什么', child: Text(unit.whatText, style: const TextStyle(height: 1.6))),
          const SizedBox(height: 12),
          _SectionBox(title: '为什么重要', child: Text(unit.whyText, style: const TextStyle(height: 1.6))),
          const SizedBox(height: 12),
          _SectionBox(
            title: '怎样做',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[for (int i = 0; i < unit.howSteps.length; i++) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${i + 1}. ${unit.howSteps[i]}', style: const TextStyle(height: 1.5)))],
            ),
          ),
          const SizedBox(height: 12),
          _SectionBox(
            title: '课程案例',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: unit.courseCases.map((String e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('• $e', style: const TextStyle(height: 1.5)))).toList()),
          ),
          const SizedBox(height: 12),
          _SectionBox(
            title: '现实案例',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: unit.lifeCases.map((String e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('• $e', style: const TextStyle(height: 1.5)))).toList()),
          ),
          const SizedBox(height: 12),
          _SectionBox(
            title: '单元训练焦点',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _trainingFocusFor(unit).map((String e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $e', style: const TextStyle(height: 1.55)),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _SectionBox(
            title: '行为链模板（按本段原内容落地）',
            child: Builder(builder: (context) {
              final HappinessBehaviorSpec spec = behaviorSpecFor(unit);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _BehaviorChainTile(title: '触发情境', text: spec.trigger),
                  _BehaviorChainTile(title: '自动想法', text: spec.thought),
                  _BehaviorChainTile(title: '情绪/身体', text: spec.body),
                  _BehaviorChainTile(title: '旧行为', text: spec.oldPattern),
                  _BehaviorChainTile(title: '新行为', text: spec.newPattern),
                  _BehaviorChainTile(title: '事实记录', text: spec.fact),
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
          _SectionBox(
            title: '知行城虚拟操练',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('对应场景：${unit.scene}', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(_sceneMission(unit), style: const TextStyle(height: 1.6)),
                const SizedBox(height: 10),
                Text(_sceneIntro(unit.scene), style: const TextStyle(color: Color(0xFF6B7280), height: 1.5)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('训练步骤：${sceneFlowFor(unit)}', style: const TextStyle(height: 1.55)),
                      const SizedBox(height: 8),
                      const Text('训练链分解', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      ..._sceneChainStepsFor(unit).asMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('${entry.key + 1}. ${entry.value}', style: const TextStyle(height: 1.5, color: Color(0xFF374151))),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HappinessSceneMissionPlayPage(unit: unit, promptOverrides: promptOverrides, onSaveAction: onSaveAction),
                    ),
                  ),
                  icon: const Icon(Icons.vrpano_outlined),
                  label: const Text('进入场景任务'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionBox(
            title: '现实行动',
            child: Builder(builder: (context) {
              final List<_ActionDraft> variants = _actionVariantsFor(unit);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(unit.defaultActionTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(unit.defaultActionBody, style: const TextStyle(height: 1.6)),
                  const SizedBox(height: 12),
                  const Text('行动梯度（与本段概念一致）', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ...variants.map((e) => _ActionVariantCard(
                        draft: e,
                        onSave: () => onSaveAction(HappinessAction(
                          id: '${e.level}_${unit.id}_${DateTime.now().millisecondsSinceEpoch}',
                          unitId: unit.id,
                          unitTitle: unit.title,
                          source: 'default',
                          title: e.title,
                          body: e.body,
                          difficulty: e.difficulty,
                          duration: e.duration,
                          successCriteria: e.successCriteria,
                          fallbackAction: e.fallbackAction,
                          reviewQuestion: unit.reflectionQuestion,
                          createdAt: DateTime.now().millisecondsSinceEpoch,
                          planNote: e.steps.isNotEmpty ? e.steps.first : _trainingFocusFor(unit).first,
                          obstacleNote: e.fallbackAction,
                          nextStepNote: e.steps.length > 1 ? e.steps.last : behaviorSpecFor(unit).newPattern,
                          steps: e.steps,
                          stepMarks: List<bool>.filled(e.steps.length, false),
                        )),
                      )),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      FilledButton.icon(onPressed: () => onSaveAction(defaultAction), icon: const Icon(Icons.add_task), label: const Text('使用默认行动')),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HappinessAiActionPage(unit: unit, promptOverrides: promptOverrides, onSaveAction: onSaveAction))),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('让 AI 生成行动'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HappinessCustomActionPage(unit: unit, onSaveAction: onSaveAction))),
                        icon: const Icon(Icons.edit_note_outlined),
                        label: const Text('我自己定义行动'),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class HappinessDiagnosisPage extends StatefulWidget {
  final Future<void> Function(HappinessUnit unit) onOpenUnit;
  const HappinessDiagnosisPage({super.key, required this.onOpenUnit});

  @override
  State<HappinessDiagnosisPage> createState() => _HappinessDiagnosisPageState();
}

class _HappinessDiagnosisPageState extends State<HappinessDiagnosisPage> {
  final TextEditingController _ctrl = TextEditingController();
  List<HappinessUnit> _results = <HappinessUnit>[];
  String _analysis = '从现实问题切入课程，不必先把全部内容学完。';
  final List<String> _chips = const <String>['怕失败', '怕被拒绝', '总想完美', '总盯结果', '工作没意义', '不知道怎么行动'];

  @override
  void initState() {
    super.initState();
    _results = happinessUnits.take(6).toList();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _search([String? quick]) {
    final String q = (quick ?? _ctrl.text).trim();
    if (q.isEmpty) {
      setState(() {
        _results = happinessUnits.take(6).toList();
        _analysis = '从现实问题切入课程，不必先把全部内容学完。';
      });
      return;
    }
    final List<MapEntry<HappinessUnit, int>> scored = <MapEntry<HappinessUnit, int>>[];
    for (final HappinessUnit unit in happinessUnits) {
      int score = 0;
      if (unit.title.contains(q) || unit.summary.contains(q) || unit.oneLiner.contains(q) || unit.fullContent.contains(q)) score += 3;
      for (final String c in unit.concepts) {
        if (c.contains(q)) score += 2;
      }
      for (final String t in unit.tags) {
        if (q.contains(t) || t.contains(q)) score += 2;
      }
      if (q.contains('失败') && unit.tags.contains('失败')) score += 3;
      if (q.contains('完美') && unit.tags.contains('完美主义')) score += 3;
      if (q.contains('结果') && unit.tags.contains('过程')) score += 2;
      if (q.contains('意义') && (unit.tags.contains('calling') || unit.tags.contains('意义'))) score += 3;
      if (score > 0) scored.add(MapEntry<HappinessUnit, int>(unit, score));
    }
    scored.sort((MapEntry<HappinessUnit, int> a, MapEntry<HappinessUnit, int> b) => b.value.compareTo(a.value));
    setState(() {
      _results = scored.take(8).map((MapEntry<HappinessUnit, int> e) => e.key).toList();
      _analysis = _diagnosisAnalysis(q, _results.isEmpty ? null : _results.first);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('问题诊断')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              hintText: '例如：我很怕被拒绝 / 我总觉得做得不够好',
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: _chips.map((String c) => ActionChip(label: Text(c), onPressed: () => _search(c))).toList()),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_analysis, style: const TextStyle(height: 1.6)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('推荐单元', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ..._results.map((HappinessUnit unit) => Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: ListTile(
                  title: Text('${unit.id} ${unit.title}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${unit.oneLiner}\n下一步：${unit.defaultActionTitle}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => widget.onOpenUnit(unit),
                ),
              )),
        ],
      ),
    );
  }
}

class HappinessAiActionPage extends StatefulWidget {
  final HappinessUnit unit;
  final Map<String, String> promptOverrides;
  final Future<void> Function(HappinessAction action) onSaveAction;
  const HappinessAiActionPage({super.key, required this.unit, required this.promptOverrides, required this.onSaveAction});

  @override
  State<HappinessAiActionPage> createState() => _HappinessAiActionPageState();
}

class _HappinessAiActionPageState extends State<HappinessAiActionPage> {
  final TextEditingController _concernCtrl = TextEditingController();
  bool _smaller = true;
  bool _avoidSocial = false;
  bool _loading = false;
  HappinessAiResult? _result;
  final HappinessAiService _ai = HappinessAiService();
  late int _actionCount;

  @override
  void initState() {
    super.initState();
    _actionCount = int.tryParse(widget.promptOverrides['action_count'] ?? '3') ?? 3;
    if (_actionCount < 1) _actionCount = 1;
    if (_actionCount > 5) _actionCount = 5;
  }

  @override
  void dispose() {
    _concernCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    final HappinessAiResult res = await _ai.generateActions(
      unit: widget.unit,
      concern: _concernCtrl.text,
      smaller: _smaller,
      avoidSocial: _avoidSocial,
      extraPrompt: widget.promptOverrides['action_generate'] ?? '',
      count: _actionCount,
    );
    if (!mounted) return;
    setState(() {
      _result = res;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 生成行动')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('${widget.unit.id} ${widget.unit.title}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(widget.unit.summary, style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 8),
                  Text('核心概念：${widget.unit.concepts.join('、')}', style: const TextStyle(color: Color(0xFF6B7280), height: 1.45)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _concernCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: '我当前最真实的困扰',
              hintText: '例如：我明天要做汇报，但很怕讲不好；我总想再改，迟迟交不出去',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(value: _smaller, onChanged: (bool v) => setState(() => _smaller = v), title: const Text('更小一步'), subtitle: const Text('优先生成今天就能开始的动作')),
          SwitchListTile(value: _avoidSocial, onChanged: (bool v) => setState(() => _avoidSocial = v), title: const Text('尽量低社交暴露'), subtitle: const Text('如果你目前不适合高社交风险，可开启')),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: <Widget>[
                  const Expanded(child: Text('本次生成行动数量', style: TextStyle(fontWeight: FontWeight.w700))),
                  DropdownButton<int>(
                    value: _actionCount,
                    items: const <int>[1, 2, 3, 4, 5].map((int e) => DropdownMenuItem<int>(value: e, child: Text('$e 条'))).toList(),
                    onChanged: (int? v) => setState(() => _actionCount = v ?? 3),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _loading ? null : _generate,
            icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
            label: const Text('生成行动'),
          ),
          if (_result != null) ...<Widget>[
            const SizedBox(height: 16),
            Text('共生成 ${_result!.actions.length} 条行动方案', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ..._result!.actions.asMap().entries.map((entry) => Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(entry.value.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    if (entry.key == 0) Text('来源：${_result!.provider} · ${_result!.modelLabel}', style: const TextStyle(color: Color(0xFF6B7280))),
                    const SizedBox(height: 10),
                    Text(entry.value.body, style: const TextStyle(height: 1.6)),
                    if (entry.value.steps.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      const Text('具体步骤', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      ...entry.value.steps.asMap().entries.map((step) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('${step.key + 1}. ${step.value}', style: const TextStyle(height: 1.5)),
                      )),
                    ],
                    const SizedBox(height: 10),
                    Text('耗时：${entry.value.duration} · 难度：${entry.value.difficulty}'),
                    const SizedBox(height: 6),
                    Text('成功标准：${entry.value.successCriteria}'),
                    const SizedBox(height: 6),
                    Text('失败替代动作：${entry.value.fallbackAction}'),
                    const SizedBox(height: 6),
                    Text('复盘问题：${entry.value.reviewQuestion}'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: () async {
                            await widget.onSaveAction(entry.value);
                            if (mounted) Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.add_task),
                          label: const Text('采纳并保存'),
                        ),
                        if (entry.key == 0) OutlinedButton(onPressed: _generate, child: const Text('再生成一组')),
                      ],
                    ),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }
}

class HappinessCustomActionPage extends StatefulWidget {
  final HappinessUnit unit;
  final Future<void> Function(HappinessAction action) onSaveAction;
  const HappinessCustomActionPage({super.key, required this.unit, required this.onSaveAction});

  @override
  State<HappinessCustomActionPage> createState() => _HappinessCustomActionPageState();
}

class _HappinessCustomActionPageState extends State<HappinessCustomActionPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _fallbackCtrl;
  late final TextEditingController _reviewCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.unit.defaultActionTitle);
    _bodyCtrl = TextEditingController(text: widget.unit.defaultActionBody);
    _fallbackCtrl = TextEditingController(text: '如果做不到，就把动作缩小到 5 分钟版本。');
    _reviewCtrl = TextEditingController(text: widget.unit.reflectionQuestion);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _fallbackCtrl.dispose();
    _reviewCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自定义行动')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('你可以把课程概念翻译成更适合自己的行动。重点不是写得漂亮，而是写得具体、可做、可复盘。', style: const TextStyle(height: 1.5)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _titleCtrl, decoration: InputDecoration(labelText: '行动标题', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
          const SizedBox(height: 12),
          TextField(controller: _bodyCtrl, maxLines: 5, decoration: InputDecoration(labelText: '行动内容', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
          const SizedBox(height: 12),
          TextField(controller: _fallbackCtrl, maxLines: 3, decoration: InputDecoration(labelText: '失败替代动作', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
          const SizedBox(height: 12),
          TextField(controller: _reviewCtrl, maxLines: 3, decoration: InputDecoration(labelText: '复盘问题', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () async {
              final HappinessAction action = HappinessAction(
                id: 'user_${DateTime.now().millisecondsSinceEpoch}',
                unitId: widget.unit.id,
                unitTitle: widget.unit.title,
                source: 'user_custom',
                title: _titleCtrl.text.trim(),
                body: _bodyCtrl.text.trim(),
                difficulty: 'Medium',
                duration: '10-20分钟',
                successCriteria: '完成你自己定义的这个动作。',
                fallbackAction: _fallbackCtrl.text.trim(),
                reviewQuestion: _reviewCtrl.text.trim(),
                createdAt: DateTime.now().millisecondsSinceEpoch,
                planNote: _trainingFocusFor(widget.unit).first,
                obstacleNote: behaviorSpecFor(widget.unit).oldPattern,
                nextStepNote: behaviorSpecFor(widget.unit).newPattern,
              );
              await widget.onSaveAction(action);
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('保存到行动中心'),
          ),
        ],
      ),
    );
  }
}

class HappinessReviewPage extends StatefulWidget {
  final HappinessUnit unit;
  final Map<String, String> prompts;
  final Future<void> Function(HappinessReviewEntry review) onSave;
  const HappinessReviewPage({super.key, required this.unit, required this.prompts, required this.onSave});

  @override
  State<HappinessReviewPage> createState() => _HappinessReviewPageState();
}

class _HappinessReviewPageState extends State<HappinessReviewPage> {
  final TextEditingController _factCtrl = TextEditingController();
  final TextEditingController _feelingCtrl = TextEditingController();
  final TextEditingController _thoughtCtrl = TextEditingController();
  final TextEditingController _actionCtrl = TextEditingController();
  final TextEditingController _outcomeCtrl = TextEditingController();
  final HappinessAiService _ai = HappinessAiService();
  bool _saving = false;

  @override
  void dispose() {
    _factCtrl.dispose();
    _feelingCtrl.dispose();
    _thoughtCtrl.dispose();
    _actionCtrl.dispose();
    _outcomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final String summary = await _ai.generateReviewSummary(
      unit: widget.unit,
      fact: _factCtrl.text.trim(),
      feeling: _feelingCtrl.text.trim(),
      thought: _thoughtCtrl.text.trim(),
      action: _actionCtrl.text.trim(),
      outcome: _outcomeCtrl.text.trim(),
      extraPrompt: widget.prompts['review'] ?? '',
    );
    final HappinessReviewEntry review = HappinessReviewEntry(
      id: 'review_${DateTime.now().millisecondsSinceEpoch}',
      unitId: widget.unit.id,
      unitTitle: widget.unit.title,
      fact: _factCtrl.text.trim(),
      feeling: _feelingCtrl.text.trim(),
      thought: _thoughtCtrl.text.trim(),
      action: _actionCtrl.text.trim(),
      outcome: _outcomeCtrl.text.trim(),
      aiSummary: summary,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await widget.onSave(review);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('复盘中心')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('建议按“事实 → 情绪 → 想法 → 行为 → 结果”来写。写清楚之后，AI 会基于课程单元帮你生成一段更贴近本课概念的总结。', style: const TextStyle(height: 1.5)),
            ),
          ),
          const SizedBox(height: 12),
          _reviewField(_factCtrl, '事实', '今天真实发生了什么？'),
          const SizedBox(height: 12),
          _reviewField(_feelingCtrl, '情绪', '你当时最明显的感受是什么？'),
          const SizedBox(height: 12),
          _reviewField(_thoughtCtrl, '想法', '你脑中最自动的一句话是什么？'),
          const SizedBox(height: 12),
          _reviewField(_actionCtrl, '行为', '你做了什么，或你是怎么回避的？'),
          const SizedBox(height: 12),
          _reviewField(_outcomeCtrl, '结果', '最后结果怎样？'),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('生成总结并保存复盘'),
          ),
        ],
      ),
    );
  }

  Widget _reviewField(TextEditingController c, String label, String hint) {
    return TextField(
      controller: c,
      maxLines: 4,
      decoration: InputDecoration(labelText: label, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
    );
  }
}

class HappinessPromptStudioPage extends StatefulWidget {
  final Map<String, String> initialPrompts;
  const HappinessPromptStudioPage({super.key, required this.initialPrompts});

  @override
  State<HappinessPromptStudioPage> createState() => _HappinessPromptStudioPageState();
}

class _HappinessPromptStudioPageState extends State<HappinessPromptStudioPage> {
  late final TextEditingController _explainCtrl;
  late final TextEditingController _actionCtrl;
  late final TextEditingController _reviewCtrl;
  late final TextEditingController _diagnosisCtrl;
  late final TextEditingController _npcCtrl;
  late final TextEditingController _historyCtrl;
  late final TextEditingController _nextActionCtrl;
  late final TextEditingController _actionCountCtrl;
  final HappinessDao _dao = HappinessDao();

  @override
  void initState() {
    super.initState();
    _explainCtrl = TextEditingController(text: widget.initialPrompts['course_explain'] ?? '请优先用通俗、具体、非空泛的方式解释课程概念，并让概念回到现实经验。');
    _actionCtrl = TextEditingController(text: widget.initialPrompts['action_generate'] ?? '请基于该段课程原内容生成可执行、可观察、可记录、可复盘的现实行动，并给出清晰具体的步骤，避免空泛建议。');
    _reviewCtrl = TextEditingController(text: widget.initialPrompts['review'] ?? '请先区分事实和解释，再点出最相关概念，最后给一个更小一步的下一次行动。');
    _diagnosisCtrl = TextEditingController(text: widget.initialPrompts['diagnosis'] ?? '请先识别用户现实问题属于失败、完美主义、过程失配、意义缺失中的哪一类，并说明原因。');
    _npcCtrl = TextEditingController(text: widget.initialPrompts['npc'] ?? '请在虚拟场景里用具体情境、有限提示和问题引导用户，而不是直接说教。');
    _historyCtrl = TextEditingController(text: widget.initialPrompts['history'] ?? '请基于历史行动和复盘，识别当前最集中的训练主题、最常卡住的环节，并给出下一轮最适合的动作类型。');
    _nextActionCtrl = TextEditingController(text: widget.initialPrompts['next_action'] ?? '请基于历史行动和复盘，为下一轮生成一条最适合继续推进的动作，优先给出具体步骤和现实记录点。');
    _actionCountCtrl = TextEditingController(text: widget.initialPrompts['action_count'] ?? '3');
  }

  @override
  void dispose() {
    _explainCtrl.dispose();
    _actionCtrl.dispose();
    _reviewCtrl.dispose();
    _diagnosisCtrl.dispose();
    _npcCtrl.dispose();
    _historyCtrl.dispose();
    _nextActionCtrl.dispose();
    _actionCountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prompt Studio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('这里仅配置本模块的提示词风格，不管理模型、版本或 API key。这些统一走已有 App 的全局 AI 设置。你可以把它理解成：模型层统一，提示词层个性化。'),
            ),
          ),
          const SizedBox(height: 12),
          _promptField(_explainCtrl, '课程解释提示词'),
          const SizedBox(height: 12),
          _promptField(_actionCtrl, '行动生成提示词'),
          const SizedBox(height: 12),
          _promptField(_reviewCtrl, '复盘提示词'),
          const SizedBox(height: 12),
          _promptField(_diagnosisCtrl, '问题诊断提示词'),
          const SizedBox(height: 12),
          _promptField(_npcCtrl, '知行城 NPC 提示词'),
          const SizedBox(height: 12),
          _promptField(_historyCtrl, '成长档案历史归纳提示词'),
          const SizedBox(height: 12),
          _promptField(_nextActionCtrl, '下一轮动作推荐提示词'),
          const SizedBox(height: 12),
          TextField(
            controller: _actionCountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '默认生成行动数量（1-5）',
              helperText: 'AI 生成行动页默认会读取这里的数量',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () async {
              final int count = ((int.tryParse(_actionCountCtrl.text.trim()) ?? 3).clamp(1, 5) as int);
              await _dao.savePrompts(<String, String>{
                'course_explain': _explainCtrl.text.trim(),
                'action_generate': _actionCtrl.text.trim(),
                'review': _reviewCtrl.text.trim(),
                'diagnosis': _diagnosisCtrl.text.trim(),
                'npc': _npcCtrl.text.trim(),
                'history': _historyCtrl.text.trim(),
                'next_action': _nextActionCtrl.text.trim(),
                'action_count': '$count',
              });
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存模块提示词')));
              Navigator.of(context).pop();
            },
            child: const Text('保存'),
          ),
          TextButton(
            onPressed: () {
              _explainCtrl.text = '请优先用通俗、具体、非空泛的方式解释课程概念，并让概念回到现实经验。';
              _actionCtrl.text = '请基于该段课程原内容生成可执行、可观察、可记录、可复盘的现实行动，并给出清晰具体的步骤，避免空泛建议。';
              _reviewCtrl.text = '请先区分事实和解释，再点出最相关概念，最后给一个更小一步的下一次行动。';
              _diagnosisCtrl.text = '请先识别用户现实问题属于失败、完美主义、过程失配、意义缺失中的哪一类，并说明原因。';
              _npcCtrl.text = '请在虚拟场景里用具体情境、有限提示和问题引导用户，而不是直接说教。';
              _historyCtrl.text = '请基于历史行动和复盘，识别当前最集中的训练主题、最常卡住的环节，并给出下一轮最适合的动作类型。';
              _nextActionCtrl.text = '请基于历史行动和复盘，为下一轮生成一条最适合继续推进的动作，优先给出具体步骤和现实记录点。';
              _actionCountCtrl.text = '3';
            },
            child: const Text('恢复默认'),
          ),
        ],
      ),
    );
  }

  Widget _promptField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      maxLines: 5,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
    );
  }
}

class _SectionBox extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionBox({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BehaviorChainTile extends StatelessWidget {
  final String title;
  final String text;
  const _BehaviorChainTile({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Color(0xFF111827), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, height: 1.55),
                children: <TextSpan>[
                  TextSpan(text: '$title：', style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConceptLensCard extends StatelessWidget {
  final HappinessUnit unit;
  final String concept;
  const _ConceptLensCard({required this.unit, required this.concept});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(concept, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          Text('概念内涵：${conceptConnotationFor(unit, concept)}', style: const TextStyle(height: 1.55)),
          const SizedBox(height: 8),
          Text('概念外延：${conceptExtensionFor(unit, concept)}', style: const TextStyle(height: 1.55)),
          const SizedBox(height: 8),
          Text('经验直观（详细）：${_experienceCue(unit, concept)}', style: const TextStyle(height: 1.55)),
          const SizedBox(height: 8),
          Text('现实里的常见表现：${_realWorldCue(unit, concept)}', style: const TextStyle(height: 1.55)),
          const SizedBox(height: 8),
          Text('概念一致动作（先做什么）', style: const TextStyle(height: 1.55, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ...conceptPracticeStepsFor(unit, concept).asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${entry.key + 1}. ${entry.value}', style: const TextStyle(height: 1.55)),
          )),
        ],
      ),
    );
  }
}


class _ActionDraft {
  final String level;
  final String title;
  final String body;
  final List<String> steps;
  final String difficulty;
  final String duration;
  final String successCriteria;
  final String fallbackAction;
  final String recordFocus;
  const _ActionDraft({required this.level, required this.title, required this.body, required this.steps, required this.difficulty, required this.duration, required this.successCriteria, required this.fallbackAction, required this.recordFocus});
}

List<_ActionDraft> _actionVariantsFor(HappinessUnit unit) {
  final HappinessActionPlanSpec easy = actionPlanFor(unit, 'easy');
  final HappinessActionPlanSpec standard = actionPlanFor(unit, 'standard');
  final HappinessActionPlanSpec stretch = actionPlanFor(unit, 'stretch');
  return <_ActionDraft>[
    _ActionDraft(
      level: 'easy',
      title: '最小一步 · ${unit.defaultActionTitle}',
      body: easy.intro,
      steps: easy.steps,
      difficulty: 'Easy',
      duration: '5-10分钟',
      successCriteria: easy.successCriteria,
      fallbackAction: easy.fallbackAction,
      recordFocus: easy.recordFocus,
    ),
    _ActionDraft(
      level: 'standard',
      title: '标准训练 · ${unit.defaultActionTitle}',
      body: standard.intro,
      steps: standard.steps,
      difficulty: 'Medium',
      duration: '10-20分钟',
      successCriteria: standard.successCriteria,
      fallbackAction: standard.fallbackAction,
      recordFocus: standard.recordFocus,
    ),
    _ActionDraft(
      level: 'stretch',
      title: '突破版本 · ${unit.defaultActionTitle}',
      body: stretch.intro,
      steps: stretch.steps,
      difficulty: 'Hard',
      duration: '20-30分钟',
      successCriteria: stretch.successCriteria,
      fallbackAction: stretch.fallbackAction,
      recordFocus: stretch.recordFocus,
    ),
  ];
}

class _ActionVariantCard extends StatelessWidget {
  final _ActionDraft draft;
  final VoidCallback onSave;
  const _ActionVariantCard({required this.draft, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: Text(draft.title, style: const TextStyle(fontWeight: FontWeight.w800))),
            _StatPill(label: '${draft.difficulty} · ${draft.duration}'),
          ]),
          const SizedBox(height: 8),
          Text(draft.body, style: const TextStyle(height: 1.55)),
          const SizedBox(height: 10),
          const Text('具体步骤', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ...draft.steps.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${entry.key + 1}. ${entry.value}', style: const TextStyle(height: 1.5)),
          )),
          const SizedBox(height: 6),
          Text('事实记录重点：${draft.recordFocus}', style: const TextStyle(height: 1.45, color: Color(0xFF374151))),
          const SizedBox(height: 6),
          Text('成功标准：${draft.successCriteria}', style: const TextStyle(height: 1.45, color: Color(0xFF374151))),
          const SizedBox(height: 4),
          Text('失败替代动作：${draft.fallbackAction}', style: const TextStyle(height: 1.45, color: Color(0xFF6B7280))),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(onPressed: onSave, icon: const Icon(Icons.add_task), label: const Text('保存这条行动')),
          ),
        ],
      ),
    );
  }
}

class _GrowthStatCard extends StatelessWidget {
  final String title;
  final String value;
  const _GrowthStatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.of(context).size.width - 42) / 2,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  const _StatPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
      child: Text(label),
    );
  }
}

class _MissionChoice {
  final String title;
  final String subtitle;
  final bool healthy;
  final String feedback;
  const _MissionChoice({required this.title, required this.subtitle, required this.healthy, required this.feedback});
}

List<_MissionChoice> _missionChoices(HappinessUnit unit) {
  final String firstConcept = unit.concepts.isEmpty ? unit.title : unit.concepts.first;
  switch (unit.id) {
    case 'L14-4':
      return <_MissionChoice>[
        _MissionChoice(title: '用一次失利给整条路下结论', subtitle: '把这次失手解释成“我这条路不行”或“我就是不行”。', healthy: false, feedback: '这会让一次节点性的挫折被放大成人格判断，也遮住了它逼出来的新能力。'),
        _MissionChoice(title: '先把这次失败放回长期尺度', subtitle: '不急着评价人格，先问三年后它更像终局还是一个节点。', healthy: true, feedback: '这更贴本段原意：先拉长时间，再看这次失败逼你长出了什么。'),
        _MissionChoice(title: '写下被逼出来的新能力，再继续上场', subtitle: '把失败后更清楚、更稳、更会的一点写出来。', healthy: true, feedback: '你把失利从“证明我不行”改成了“暴露了我下一步该练什么”。'),
      ];
    case 'L14-5':
      return <_MissionChoice>[
        _MissionChoice(title: '先找谁该负责，急着自证或归责', subtitle: '把错误先处理成责任战，而不是学习材料。', healthy: false, feedback: '这会让人更想隐藏问题，也更难形成试错文化。'),
        _MissionChoice(title: '先把错误改写成复盘对象', subtitle: '问发生了什么、学到了什么、机制怎么改。', healthy: true, feedback: '这更贴本段原意：保留责任，但先把系统的学习价值拿回来。'),
        _MissionChoice(title: '同时保留责任与学习', subtitle: '不甩锅也不羞辱，把错误变成下一次更稳的机制。', healthy: true, feedback: '你既没有逃避责任，也没有停在责备。'),
      ];
    case 'L14-6':
      return <_MissionChoice>[
        _MissionChoice(title: '做一次就急着下结论', subtitle: '样本太少，却已经开始给自己或事情定性。', healthy: false, feedback: '你把样本量问题误判成能力问题，于是尝试密度永远上不去。'),
        _MissionChoice(title: '先记录上场次数，不急着评价', subtitle: '把注意力先放在“我到底试了几次”。', healthy: true, feedback: '这更贴本段核心：提高成功率前先提高尝试密度。'),
        _MissionChoice(title: '提高一次尝试配额，再找模式', subtitle: '不只多做，还要从几次尝试里看共通规律。', healthy: true, feedback: '你开始把注意力从单次成败转向样本规律。'),
      ];
    case 'L15-1':
      return <_MissionChoice>[
        _MissionChoice(title: '一出小差错就立刻过度补偿', subtitle: '想马上解释、遮住、证明自己其实没有这么不完美。', healthy: false, feedback: '这样会不断把“不完美”重新包装成羞耻对象。'),
        _MissionChoice(title: '允许一处小偏差存在，同时继续推进', subtitle: '不急着把痕迹抹掉，先把重要事情继续做下去。', healthy: true, feedback: '这更贴本段原意：允许现实存在，而不被它夺走节奏。'),
        _MissionChoice(title: '区分修问题和掩盖痕迹', subtitle: '只修真的影响事情的那一点，不为维护形象做过度补偿。', healthy: true, feedback: '你开始把解决问题和维持完美形象分开。'),
      ];
    case 'L15-2':
      return <_MissionChoice>[
        _MissionChoice(title: '因为第一轮笨拙，就怀疑自己不适合', subtitle: '把练习阶段的生涩误解成能力证据。', healthy: false, feedback: '这样会让训练在真正开始前就结束。'),
        _MissionChoice(title: '接受笨拙练习，留下第一版', subtitle: '不求像老手，只求让生涩出现在现实里。', healthy: true, feedback: '这更贴本段原意：很多次不够好，本来就是学习机制。'),
        _MissionChoice(title: '做两轮小练习，看微小变化', subtitle: '不是追求一下变好，而是让大脑看到练习真的会带来微调。', healthy: true, feedback: '你开始把注意力放回有没有在练、有没有更顺一点。'),
      ];
    case 'L15-3':
      return <_MissionChoice>[
        _MissionChoice(title: '继续怪新环境，不看旧剧本', subtitle: '以为环境换了，旧问题就该自动消失。', healthy: false, feedback: '这样会让旧模式披着新环境的外壳继续运行。'),
        _MissionChoice(title: '先识别旧剧本已经迁移过来了', subtitle: '先看见“我又是怎么把旧紧绷带进来的”。', healthy: true, feedback: '这更贴本段核心：你开始区分环境变化和模式迁移。'),
        _MissionChoice(title: '给旧剧本命名，再做一个反方向小动作', subtitle: '命名后，不停在理解里，还要做一个不按旧剧本的小动作。', healthy: true, feedback: '你不只是看见了模式，还开始练不被它完全带走。'),
      ];
    case 'L15-4':
      return <_MissionChoice>[
        _MissionChoice(title: '把高要求和完美主义继续绑在一起', subtitle: '一放松一点就怕自己会失去 ambition。', healthy: false, feedback: '这会让你误把焦虑和控制当成上进。'),
        _MissionChoice(title: '保留抱负，放松路径控制', subtitle: '目标可以高，但路径允许现实波动和学习。', healthy: true, feedback: '这更贴本段原意：修正的不是 ambition，而是你对偏差的态度。'),
        _MissionChoice(title: '把目标改写成卓越版而非完美版', subtitle: '继续认真，但不要求零误差和一次到位。', healthy: true, feedback: '你把上进和完美主义拆开了。'),
      ];
    case 'L15-5':
      return <_MissionChoice>[
        _MissionChoice(title: '继续把第一版关在抽屉里', subtitle: '因为还不够像样，所以不让现实看见。', healthy: false, feedback: '这会让你永远没有可反馈样本。'),
        _MissionChoice(title: '先交一版草稿', subtitle: '允许第一版存在，先让现实世界看见一个版本。', healthy: true, feedback: '这更贴本段原意：没有不够圆的圆，就没有后面更好的圆。'),
        _MissionChoice(title: '限定修改轮次后发出', subtitle: '优化可以有，但不能无限期拖住输出。', healthy: true, feedback: '你把改进留给现实反馈，而不是留给无止境内耗。'),
      ];
    case 'L15-15':
      return <_MissionChoice>[
        _MissionChoice(title: '让旧剧本自动接管', subtitle: '等情绪过去、等状态更好、等自己自然改变。', healthy: false, feedback: '旧剧本越不被点名，越容易继续主导。'),
        _MissionChoice(title: '先给旧剧本起名字', subtitle: '把它从“我就是这样”变成“这个剧本又来了”。', healthy: true, feedback: '这更贴本段原意：先看见它，才谈得上不被它牵着走。'),
        _MissionChoice(title: '点名后立刻做一个小反动作', subtitle: '识别之后，不停在理解里，而是给旧剧本一个反方向小动作。', healthy: true, feedback: '你把觉察和行动绑在了一起。'),
      ];
    case 'L16-2':
      return <_MissionChoice>[
        _MissionChoice(title: '只因为结果想要，就继续硬扛', subtitle: '不看过程对自己造成什么，只盯终点。', healthy: false, feedback: '这会让事情即使有意义，也越来越像长期消耗。'),
        _MissionChoice(title: '把结果分和过程分分开看', subtitle: '先承认“我想要它”和“我喜欢这样去做”是两件事。', healthy: true, feedback: '这更贴本段原意：幸福来自结果契合，也来自过程契合。'),
        _MissionChoice(title: '先调高一个过程环节的契合度', subtitle: '不急着推翻整件事，先改一个过程细节。', healthy: true, feedback: '你开始把幸福放回路径，而不是全押给未来结果。'),
      ];
    case 'L16-10':
      return <_MissionChoice>[
        _MissionChoice(title: '继续对着问题硬扛', subtitle: '只盯问题本身，没让自己的优势真正参与进来。', healthy: false, feedback: '这样会让优势继续停留在“知道自己有什么”。'),
        _MissionChoice(title: '先判断哪个优势最适合上场', subtitle: '不是盲目努力，而是先选更贴合自己的工具。', healthy: true, feedback: '这更贴本段原意：优势不是标签，而是问题解决工具。'),
        _MissionChoice(title: '把优势翻译成一个现实动作', subtitle: '让优势变成一个别人能看见、自己能执行的动作。', healthy: true, feedback: '你把“了解自己”推进成了“用自己去解决现实问题”。'),
      ];
    case 'L14-4':
      return <_MissionChoice>[
        _MissionChoice(title: '用一次失利给整条路下结论', subtitle: '把这次失手解释成“我这条路不行”或“我就是不行”。', healthy: false, feedback: '这会让一次节点性的挫折被放大成人格判断，也遮住了它逼出来的新能力。'),
        _MissionChoice(title: '先把这次失败放回长期尺度', subtitle: '不急着评价人格，先问三年后它更像终局还是一个节点。', healthy: true, feedback: '这更贴本段原意：先拉长时间，再看这次失败逼你长出了什么。'),
        _MissionChoice(title: '写下被逼出来的新能力，再继续上场', subtitle: '把失败后更清楚、更稳、更会的一点写出来。', healthy: true, feedback: '你把失利从“证明我不行”改成了“暴露了我下一步该练什么”。'),
      ];
    case 'L14-5':
      return <_MissionChoice>[
        _MissionChoice(title: '先找谁该负责，急着自证或归责', subtitle: '把错误先处理成责任战，而不是学习材料。', healthy: false, feedback: '这会让人更想隐藏问题，也更难形成试错文化。'),
        _MissionChoice(title: '先把错误改写成复盘对象', subtitle: '问发生了什么、学到了什么、机制怎么改。', healthy: true, feedback: '这更贴本段原意：保留责任，但先把系统的学习价值拿回来。'),
        _MissionChoice(title: '同时保留责任与学习', subtitle: '不甩锅也不羞辱，把错误变成下一次更稳的机制。', healthy: true, feedback: '你既没有逃避责任，也没有停在责备。'),
      ];
    case 'L14-6':
      return <_MissionChoice>[
        _MissionChoice(title: '做一次就急着下结论', subtitle: '样本太少，却已经开始给自己或事情定性。', healthy: false, feedback: '你把样本量问题误判成能力问题，于是尝试密度永远上不去。'),
        _MissionChoice(title: '先记录上场次数，不急着评价', subtitle: '把注意力先放在“我到底试了几次”。', healthy: true, feedback: '这更贴本段核心：提高成功率前先提高尝试密度。'),
        _MissionChoice(title: '提高一次尝试配额，再找模式', subtitle: '不只多做，还要从几次尝试里看共通规律。', healthy: true, feedback: '你开始把注意力从单次成败转向样本规律。'),
      ];
    case 'L15-1':
      return <_MissionChoice>[
        _MissionChoice(title: '一出小差错就立刻过度补偿', subtitle: '想马上解释、遮住、证明自己其实没有这么不完美。', healthy: false, feedback: '这样会不断把“不完美”重新包装成羞耻对象。'),
        _MissionChoice(title: '允许一处小偏差存在，同时继续推进', subtitle: '不急着把痕迹抹掉，先把重要事情继续做下去。', healthy: true, feedback: '这更贴本段原意：允许现实存在，而不被它夺走节奏。'),
        _MissionChoice(title: '区分修问题和掩盖痕迹', subtitle: '只修真的影响事情的那一点，不为维护形象做过度补偿。', healthy: true, feedback: '你开始把解决问题和维持完美形象分开。'),
      ];
    case 'L15-2':
      return <_MissionChoice>[
        _MissionChoice(title: '因为第一轮笨拙，就怀疑自己不适合', subtitle: '把练习阶段的生涩误解成能力证据。', healthy: false, feedback: '这样会让训练在真正开始前就结束。'),
        _MissionChoice(title: '接受笨拙练习，留下第一版', subtitle: '不求像老手，只求让生涩出现在现实里。', healthy: true, feedback: '这更贴本段原意：很多次不够好，本来就是学习机制。'),
        _MissionChoice(title: '做两轮小练习，看微小变化', subtitle: '不是追求一下变好，而是让大脑看到练习真的会带来微调。', healthy: true, feedback: '你开始把注意力放回有没有在练、有没有更顺一点。'),
      ];
    case 'L15-3':
      return <_MissionChoice>[
        _MissionChoice(title: '继续怪新环境，不看旧剧本', subtitle: '以为环境换了，旧问题就该自动消失。', healthy: false, feedback: '这样会让旧模式披着新环境的外壳继续运行。'),
        _MissionChoice(title: '先识别旧剧本已经迁移过来了', subtitle: '先看见“我又是怎么把旧紧绷带进来的”。', healthy: true, feedback: '这更贴本段核心：你开始区分环境变化和模式迁移。'),
        _MissionChoice(title: '给旧剧本命名，再做一个反方向小动作', subtitle: '命名后，不停在理解里，还要做一个不按旧剧本的小动作。', healthy: true, feedback: '你不只是看见了模式，还开始练不被它完全带走。'),
      ];
    case 'L15-4':
      return <_MissionChoice>[
        _MissionChoice(title: '把高要求和完美主义继续绑在一起', subtitle: '一放松一点就怕自己失去 ambition。', healthy: false, feedback: '这会让你误把焦虑和控制当成上进。'),
        _MissionChoice(title: '保留抱负，放松路径控制', subtitle: '目标可以高，但路径允许现实波动和学习。', healthy: true, feedback: '这更贴本段原意：修正的不是 ambition，而是你对偏差的态度。'),
        _MissionChoice(title: '把目标改写成卓越版而非完美版', subtitle: '继续认真，但不要求零误差和一次到位。', healthy: true, feedback: '你把上进和完美主义拆开了。'),
      ];
    case 'L15-5':
      return <_MissionChoice>[
        _MissionChoice(title: '继续把第一版关在抽屉里', subtitle: '因为还不够像样，所以不让现实看见。', healthy: false, feedback: '这会让你永远没有可反馈样本。'),
        _MissionChoice(title: '先交一版草稿', subtitle: '允许第一版存在，先让现实世界看见一个版本。', healthy: true, feedback: '这更贴本段原意：没有不够圆的圆，就没有后面更好的圆。'),
        _MissionChoice(title: '限定修改轮次后发出', subtitle: '优化可以有，但不能无限期拖住输出。', healthy: true, feedback: '你把改进留给现实反馈，而不是留给无止境内耗。'),
      ];
    case 'L15-15':
      return <_MissionChoice>[
        _MissionChoice(title: '让旧剧本自动接管', subtitle: '等情绪过去、等状态更好、等自己自然改变。', healthy: false, feedback: '旧剧本越不被点名，越容易继续主导。'),
        _MissionChoice(title: '先给旧剧本起名字', subtitle: '把它从“我就是这样”变成“这个剧本又来了”。', healthy: true, feedback: '这更贴本段原意：先看见它，才谈得上不被它牵着走。'),
        _MissionChoice(title: '点名后立刻做一个小反动作', subtitle: '识别之后，不停在理解里，而是给旧剧本一个反方向小动作。', healthy: true, feedback: '你把觉察和行动绑在了一起。'),
      ];
    case 'L16-2':
      return <_MissionChoice>[
        _MissionChoice(title: '只因为结果想要，就继续硬扛', subtitle: '不看过程对自己造成什么，只盯终点。', healthy: false, feedback: '这会让事情即使有意义，也越来越像长期消耗。'),
        _MissionChoice(title: '把结果分和过程分分开看', subtitle: '先承认“我想要它”和“我喜欢这样去做”是两件事。', healthy: true, feedback: '这更贴本段原意：幸福来自结果契合，也来自过程契合。'),
        _MissionChoice(title: '先调高一个过程环节的契合度', subtitle: '不急着推翻整件事，先改一个过程细节。', healthy: true, feedback: '你开始把幸福放回路径，而不是全押给未来结果。'),
      ];
    case 'L16-10':
      return <_MissionChoice>[
        _MissionChoice(title: '继续对着问题硬扛', subtitle: '只盯问题本身，没让自己的优势真正参与进来。', healthy: false, feedback: '这样会让优势继续停留在“知道自己有什么”。'),
        _MissionChoice(title: '先判断哪个优势最适合上场', subtitle: '不是盲目努力，而是先选更贴合自己的工具。', healthy: true, feedback: '这更贴本段原意：优势不是标签，而是问题解决工具。'),
        _MissionChoice(title: '把优势翻译成一个现实动作', subtitle: '让优势变成一个别人能看见、自己能执行的动作。', healthy: true, feedback: '你把“了解自己”推进成了“用自己去解决现实问题”。'),
      ];
    case 'L15-6':
      return <_MissionChoice>[
        _MissionChoice(
          title: '沿用旧剧本：继续想把曲线掰回直线',
          subtitle: '你会急着纠正、急着证明自己没偏离，于是过度控制或索性撤退。',
          healthy: false,
          feedback: '你把一次波动直接解释成整条路出问题，于是更想控制、重来或干脆放弃。这会暂时减轻不适，却会继续喂养“直线思维”。',
        ),
        _MissionChoice(
          title: '用螺旋视角命名这次波动',
          subtitle: '先判断这更像绕路、停顿、回撤还是重练，再决定下一步。',
          healthy: true,
          feedback: '这条路径更接近本段原意：你先把波动放回成长曲线，再决定动作，因此不会因为一次不顺就整条否定自己。',
        ),
        _MissionChoice(
          title: '按卓越而非完美的标准推进一次',
          subtitle: '不要求无瑕，只要求认真推进关键部分并允许一处不完美存在。',
          healthy: true,
          feedback: '你没有用“必须完美”卡住行动，而是保持认真同时允许曲线存在。这更像追求卓越，而不是完美主义。',
        ),
      ];
    case 'L14-3':
      return <_MissionChoice>[
        _MissionChoice(
          title: '跟着灾难化往下滚',
          subtitle: '把“不顺”自动放大成“完了、丢脸、以后都不行”。',
          healthy: false,
          feedback: '你让模糊的大恐惧继续主导自己，所以越来越像只能退。问题不是事情本身，而是你把最坏情况脑补成了全局性灾难。',
        ),
        _MissionChoice(
          title: '先把最坏结果写具体',
          subtitle: '不急着压情绪，先把“最坏到底是什么”拆成几个可验证事件。',
          healthy: true,
          feedback: '这条路径更接近本段思路：你先把灾难化拆成具体后果，于是大脑开始从“完了”回到“可以分析”。',
        ),
        _MissionChoice(
          title: '写出应对动作后再迈最小一步',
          subtitle: '先问“即使不顺我怎么处理”，再决定做一小步。',
          healthy: true,
          feedback: '你没有追求保证成功，而是在明确可承受性后仍然行动，这就是从灾难化回到现实。',
        ),
      ];
    case 'L15-18':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续等状态更好、想得更清楚',
          subtitle: '看起来是在准备，其实是在用分析拖开真实行动。',
          healthy: false,
          feedback: '你把自己继续留在脑内，旧剧本会觉得“再等等更安全”，但这也意味着你依旧没有和现实接触。',
        ),
        _MissionChoice(
          title: '先做一个 5 分钟的真实接触动作',
          subtitle: '不等完全想通，先用最小现实动作打破冻结。',
          healthy: true,
          feedback: '这条路径更贴近本段核心：先让行为发生，再让态度慢慢被现实修正。',
        ),
        _MissionChoice(
          title: '先承受一次反馈 / 拒绝，再记录事实',
          subtitle: '不急着解释或补救，先把反馈原样接住。',
          healthy: true,
          feedback: '你没有让旧防御立刻接管，而是通过真实接触训练了承受力，这就是“用行为改变态度”。',
        ),
      ];
    case 'L14-1':
      return <_MissionChoice>[
        _MissionChoice(
          title: '先别做，等更像样一点再说',
          subtitle: '你想先把自己练到不那么笨拙，再进入现实。',
          healthy: false,
          feedback: '这会让你暂时少一点羞耻，但也让你继续错过真实反馈。你不是在学习，而是在保护自己不要看见生涩。',
        ),
        _MissionChoice(
          title: '先做出第一份样本',
          subtitle: '只做一个可学习样本，不要求成熟，不要求漂亮。',
          healthy: true,
          feedback: '这更接近本段原意：失败不是例外，而是学习机制。你不是在证明价值，而是在积累样本。',
        ),
        _MissionChoice(
          title: '做完后只记录学到什么',
          subtitle: '不急着评价自己，先把这次练习里的反馈写出来。',
          healthy: true,
          feedback: '你把注意力从“我怎么样”转向“我学到了什么”，这正是从失败中学习的关键转向。',
        ),
      ];
    case 'L14-2':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续沉默，先别让自己暴露出来',
          subtitle: '你决定再等等，等一个更安全、更确定的时机。',
          healthy: false,
          feedback: '你暂时保住了安全感，但也再次确认了“出现很危险”。这会让评价焦虑继续长大。',
        ),
        _MissionChoice(
          title: '在安全场景里先出现一次',
          subtitle: '不做大暴露，只做一次真实表达、提问或请求。',
          healthy: true,
          feedback: '这更接近本段原意：不是逼自己一下子很勇敢，而是停止长期消失，开始有一次真实出现。',
        ),
        _MissionChoice(
          title: '出现后只记录真实反馈',
          subtitle: '不按脑补评分，先记现实里真正发生了什么。',
          healthy: true,
          feedback: '你把评价焦虑从脑补拉回现实证据，这会逐步松动“别人一定会怎么看我”的旧剧本。',
        ),
      ];
    case 'L15-20':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续用责骂推动自己',
          subtitle: '你觉得只有对自己狠一点，才不会松掉。',
          healthy: false,
          feedback: '短期看像在逼自己，长期却更容易带来羞耻、回避和更低的恢复力。',
        ),
        _MissionChoice(
          title: '像对朋友那样对自己说一句话',
          subtitle: '不粉饰，不纵容，只把语气改成真实又善意。',
          healthy: true,
          feedback: '这更接近本段原意：不是降低要求，而是修正你对自己长期残酷的双重标准。',
        ),
        _MissionChoice(
          title: '带着更善意的语气继续行动',
          subtitle: '改写完之后，不停在安慰里，而是继续推进下一步。',
          healthy: true,
          feedback: '真正的自我慈悲不会让你躺平，而是让你有力气继续做该做的事。',
        ),
      ];
    case 'L16-8':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续硬撑，把今天熬过去',
          subtitle: '你不去管过程里有没有活力，只求把结果推完。',
          healthy: false,
          feedback: '这会让你越来越把自己活成执行机器，而不是一个在过程中也能被滋养的人。',
        ),
        _MissionChoice(
          title: '选一个优势进场',
          subtitle: '先判断今天最适合调哪一项优势，而不是只靠硬撑。',
          healthy: true,
          feedback: '这更接近本段原意：优势不是挂在墙上的标签，而是用来改变过程体验的。',
        ),
        _MissionChoice(
          title: '用优势做出一个具体动作',
          subtitle: '例如用真诚发起一次沟通，用爱学习查清一个问题。',
          healthy: true,
          feedback: '你开始把优势真正带进现实问题，这才是 VIA 从知道到做到的关键。',
        ),
      ];
    case 'L15-22':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续跟着情绪和混乱跑',
          subtitle: '越急越乱，越乱越想一下子把一切修到完美。',
          healthy: false,
          feedback: '你没有停下来，所以旧模式继续滚大，事情和情绪会一起失控。',
        ),
        _MissionChoice(
          title: '先完成 Permission，再决定第一件事',
          subtitle: '先承认这很难、我是普通人，再回到下一件最小任务。',
          healthy: true,
          feedback: '你没有再用完美主义攻击自己，而是先把自己拉回人性和现实，这能迅速降低内部对抗。',
        ),
        _MissionChoice(
          title: '完整做一次 Three Ps 后再继续',
          subtitle: '允许自己、寻找益处、拉远视角，然后再动手。',
          healthy: true,
          feedback: '这条路径更接近课程原意：你不是直接压情绪，而是通过三步恢复到可行动状态。',
        ),
      ];
    case 'L15-7':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续只盯缺口和问题',
          subtitle: '你会自然滑向“哪里还不够”，越看越像整个人都有问题。',
          healthy: false,
          feedback: '这会让你继续被半杯空带走，难以看到真实进展，也更难把反馈当作资料而不是判决。',
        ),
        _MissionChoice(
          title: '先识别我现在是防御还是在学习',
          subtitle: '先不解释，先判断自己此刻更像在保护面子还是吸收信息。',
          healthy: true,
          feedback: '这更贴近本段原意：你先看见了防御，而不是让它自动接管整个场景。',
        ),
        _MissionChoice(
          title: '先写 2 条已经存在的有效部分，再看问题',
          subtitle: '把注意力从“半杯空”拉回更完整的现实。',
          healthy: true,
          feedback: '你没有否认问题，但也不再只剩问题。这会让反馈更容易进入学习，而不是直接进入羞耻。',
        ),
      ];
    case 'L15-10':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续把关系想成必须没有失望',
          subtitle: '一有落差就马上怀疑关系本身或怀疑对方。',
          healthy: false,
          feedback: '这会让你把“关系里有负面”误解成“关系错了”，从而越来越难进入修复。',
        ),
        _MissionChoice(
          title: '先承认关系里出现了真实落差',
          subtitle: '不急着判死刑，先把失望说清楚。',
          healthy: true,
          feedback: '这更接近本段原意：关系的关键不是没有矛盾，而是能不能处理矛盾。',
        ),
        _MissionChoice(
          title: '把期待从完美改成可修复',
          subtitle: '把“不能有问题”换成“出现问题后我如何回应”。',
          healthy: true,
          feedback: '你开始从理想化模板退回真实关系，也更可能进入沟通和修复。',
        ),
      ];
    case 'L16-3':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续只盯工资、头衔或下一站',
          subtitle: '这会让你越来越像在赶路，而不是在活。',
          healthy: false,
          feedback: '你会越来越难感受到过程中的价值，也更容易陷入“到了下一站才会好”。',
        ),
        _MissionChoice(
          title: '先判断我现在更像 job、career 还是 calling',
          subtitle: '先看清当前驱动，再决定怎么调整。',
          healthy: true,
          feedback: '这更贴近课程原意：不是先做巨大决定，而是先识别你正用哪种工作叙事活着。',
        ),
        _MissionChoice(
          title: '给当前任务补一层真实意义',
          subtitle: '不粉饰，而是找出它真正服务了谁、为什么值得。',
          healthy: true,
          feedback: '你开始从差事和赛跑视角里松动出来，让过程多一点意义支点。',
        ),
      ];
    case 'L16-5':
      return <_MissionChoice>[
        _MissionChoice(
          title: '因为局部枯燥就否定整条路',
          subtitle: '你会把“这一段不爽”误判成“整体没意义”。',
          healthy: false,
          feedback: '这会让你对 calling 产生不现实期待，好像真正适合的事就不该有任何重复和枯燥。',
        ),
        _MissionChoice(
          title: '区分整体在乎与局部无聊',
          subtitle: '允许使命里也有重复、准备和琐碎。',
          healthy: true,
          feedback: '这更贴近本段原意：calling 不等于每一分钟都兴奋，而是整体上知道自己为什么在做。',
        ),
        _MissionChoice(
          title: '带着整体意义完成一个枯燥环节',
          subtitle: '不要求喜欢它，但让它服务于更大的在乎。',
          healthy: true,
          feedback: '你没有再把局部无聊等同于整条路错误，而是练习承载它。',
        ),
      ];
    case 'L16-6':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续把当前角色只看成差事',
          subtitle: '你会越来越机械，也越来越难从自己的位置上看见价值。',
          healthy: false,
          feedback: '这会让工作越来越只剩消耗，而看不见你其实正在服务的真实对象和链条。',
        ),
        _MissionChoice(
          title: '重写我这份角色的社会价值版本',
          subtitle: '先不换工作，先换叙事。',
          healthy: true,
          feedback: '这更接近课程原意：calling 很多时候不只取决于职业本身，也取决于你怎么理解它。',
        ),
        _MissionChoice(
          title: '让新的意义版本落到一个具体动作',
          subtitle: '把“我服务了谁”翻译成今天的一件事。',
          healthy: true,
          feedback: '你开始把意义从脑内解释带回现实行为，而不是只停在想法层。',
        ),
      ];
    case 'L15-11':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续加压，逼自己更狠一点',
          subtitle: '你相信只有高压才能把表现推上去。',
          healthy: false,
          feedback: '这会短期让你更紧，但长期会更耗、更反复，也更难稳定持续。',
        ),
        _MissionChoice(
          title: '先把节奏改成可持续推进',
          subtitle: '不追爆冲，先保住稳定而真实的推进。',
          healthy: true,
          feedback: '这更贴近本段原意：长期表现更强，往往来自可持续而不是持续自我压榨。',
        ),
        _MissionChoice(
          title: '只推进关键部分，不把每一处都硬推到底',
          subtitle: '把有限精力放到最关键的现实步骤上。',
          healthy: true,
          feedback: '你开始从“高压驱动”转向“关键推进”，更容易形成长期表现。',
        ),
      ];
    case 'L15-12':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续拿外部模板要求自己',
          subtitle: '看到别人或理想模板后，立刻把它当成自己必须达到的标准。',
          healthy: false,
          feedback: '这会让你活在被灌输的完美标准里，而不是活在真实生活里。',
        ),
        _MissionChoice(
          title: '先识别这是谁的模板，不急着照单全收',
          subtitle: '把媒体、文化和自己真正的需要分开。',
          healthy: true,
          feedback: '这更贴近本段原意：你开始看见模板如何塑造了你，而不再直接被它牵着走。',
        ),
        _MissionChoice(
          title: '把标准拉回真实人类版本',
          subtitle: '不追一个超模、电影或完美神话的版本。',
          healthy: true,
          feedback: '你开始从理想化模板退回真实生活，也更可能获得稳定幸福。',
        ),
      ];
    case 'L15-14':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续每一块都想做到完美',
          subtitle: '结果每一处都耗很多，真正关键的反而推不动。',
          healthy: false,
          feedback: '这会继续让你被完美主义牵走，最终花了很多力气，却没换来真正关键的推进。',
        ),
        _MissionChoice(
          title: '先抓最关键的 20%',
          subtitle: '把时间和精力优先给最重要的部分。',
          healthy: true,
          feedback: '这更贴近课程原意：不是摆烂，而是把有限精力放在真正重要的地方。',
        ),
        _MissionChoice(
          title: '允许其他部分先够好完成',
          subtitle: '让“够好”替代“全部最好”。',
          healthy: true,
          feedback: '你开始练习优先级，而不是继续让所有任务都要求同等完美。',
        ),
      ];
    case 'L15-17':
      return <_MissionChoice>[
        _MissionChoice(
          title: '因为老问题又来就判自己没变',
          subtitle: '你会把“问题还在”直接解释成“我根本没成长”。',
          healthy: false,
          feedback: '这会让你继续用完美主义来对付自己的问题，于是又回到内部战争。',
        ),
        _MissionChoice(
          title: '承认它还会来，但我仍然行动',
          subtitle: '接纳问题存在，不等于向问题投降。',
          healthy: true,
          feedback: '这更接近本段原意：主动接纳不是放弃，而是停止把改变设成“必须彻底消失”的项目。',
        ),
        _MissionChoice(
          title: '带着旧问题做一个新动作',
          subtitle: '让行动比“彻底治好”先发生。',
          healthy: true,
          feedback: '你开始从“等我好了再做”转向“问题还在，我也能继续做”。',
        ),
      ];
    case 'L15-19':
      return <_MissionChoice>[
        _MissionChoice(
          title: '直接硬上场，沿用旧紧张状态',
          subtitle: '你希望现实自己突然表现更稳。',
          healthy: false,
          feedback: '这会让你把一切都压在现场表现上，而没有提前给自己一个更稳的进入状态。',
        ),
        _MissionChoice(
          title: '先做短可视化，再进入场景',
          subtitle: '先在内在模拟器里练一个更稳版本。',
          healthy: true,
          feedback: '这更贴近本段原意：你先让大脑体验一次更好的进入方式，而不再只靠临场硬撑。',
        ),
        _MissionChoice(
          title: '可视化后立刻去做一个现实动作',
          subtitle: '不让练习停在想象里。',
          healthy: true,
          feedback: '你把状态准备和现实动作接起来了，这才会让可视化真正服务行动。',
        ),
      ];
    case 'L15-21':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续说教和急着纠正对方',
          subtitle: '你很想让对方快点变好，于是开始控制。',
          healthy: false,
          feedback: '这往往会让对方更防御，也让支持关系变成新的压力来源。',
        ),
        _MissionChoice(
          title: '先讲自己的故事，不急着教训',
          subtitle: '用分享代替控制。',
          healthy: true,
          feedback: '这更贴近本段原意：帮助别人更有效的，不是说教，而是示范和经验分享。',
        ),
        _MissionChoice(
          title: '奖励对方的尝试和过程',
          subtitle: '不只盯结果。',
          healthy: true,
          feedback: '你开始支持对方的成长过程，而不是只盯他有没有立刻达到结果。',
        ),
      ];
    case 'L15-23':
      return <_MissionChoice>[
        _MissionChoice(
          title: '一乱就急着把所有事都救回来',
          subtitle: '越急越乱，越乱越想一下子控制一切。',
          healthy: false,
          feedback: '这会让混乱再叠一层内部攻击，结果更难恢复。',
        ),
        _MissionChoice(
          title: '先尊重现实负荷，再收束下一步',
          subtitle: '承认此刻就是乱的，然后先处理最关键的一件。',
          healthy: true,
          feedback: '这更贴近本段原意：不是假装轻松，而是在真实混乱中恢复行动能力。',
        ),
        _MissionChoice(
          title: '用微复原把自己从补偿式硬冲里拉回来',
          subtitle: '不再靠更急更狠来证明自己没失控。',
          healthy: true,
          feedback: '你开始把现实接纳、恢复和行动重新串起来，而不是继续用控制掩盖混乱。',
        ),
      ];
    case 'L16-1':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续只看终点，不看过程',
          subtitle: '你会觉得只要最后到了，现在怎么熬都无所谓。',
          healthy: false,
          feedback: '这会让今天的一切都变成等待，而不是生活本身。',
        ),
        _MissionChoice(
          title: '先把注意力从终点拉回今天的过程',
          subtitle: '先看今天这一步是怎么走的。',
          healthy: true,
          feedback: '这更贴近本段原意：你开始从“只盯结果”转向“过程也有价值”。',
        ),
        _MissionChoice(
          title: '在过程里加一个观察点',
          subtitle: '不只追结果，也记录过程感受。',
          healthy: true,
          feedback: '你开始训练自己在路上活，而不是只在终点短暂停留。',
        ),
      ];
    case 'L16-9':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续模糊地活，不知道什么时候最像自己',
          subtitle: '你忙了一天，却分不清哪里是真活，哪里只是表演。',
          healthy: false,
          feedback: '这会让你越来越靠外部标准定义自己，而不是从活力感辨认真实自我。',
        ),
        _MissionChoice(
          title: '抓一个“这才是我”的时刻',
          subtitle: '先别追求完整答案，只抓一个真实瞬间。',
          healthy: true,
          feedback: '这更贴近本段原意：真正的我常出现在最活、最自然、最不必演的时候。',
        ),
        _MissionChoice(
          title: '反推那个时刻用了什么方式出现',
          subtitle: '从活力感回到可重复的行动方式。',
          healthy: true,
          feedback: '你开始把“真实自我”从抽象感受，转成可观察、可重复的现实线索。',
        ),
      ];

    case 'L15-8':
      return <_MissionChoice>[
        _MissionChoice(
          title: '一完成就立刻冲向下一站',
          subtitle: '你会把松一口气错当成幸福，然后继续把幸福往后推。',
          healthy: false,
          feedback: '这会让你越来越活在下一站，过程里几乎没有真正的满足停留。',
        ),
        _MissionChoice(
          title: '先停留 2 分钟整合过程收获',
          subtitle: '不急着奔向下一任务，先看见已经完成的东西。',
          healthy: true,
          feedback: '这更贴近本段原意：你在练“过程里也有价值”，而不再只靠终点松气活着。',
        ),
        _MissionChoice(
          title: '把完成感写成现实证据',
          subtitle: '用一句事实说明今天已经推进了什么。',
          healthy: true,
          feedback: '你开始把注意力从“还没到下一站”拉回“这一站我已经做了什么”。',
        ),
      ];
    case 'L15-9':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续全有或全无',
          subtitle: '要么死控，要么彻底放掉，中间地带不存在。',
          healthy: false,
          feedback: '这会继续放大羞耻和反弹，让你越来越难建立稳定节奏。',
        ),
        _MissionChoice(
          title: '练一次适度版本',
          subtitle: '不极端控制，也不彻底放任。',
          healthy: true,
          feedback: '这更贴近本段原意：真正要练的是中间地带和自我接纳。',
        ),
        _MissionChoice(
          title: '把一次偏差留在局部偏差',
          subtitle: '不因为一点偏离就把整天都判掉。',
          healthy: true,
          feedback: '你开始从“全盘作废”回到“局部调整”，这对身体、自尊和持续性都更健康。',
        ),
      ];
    case 'L15-13':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续只夸结果或聪明',
          subtitle: '你会更想维持形象，而不是进入挑战。',
          healthy: false,
          feedback: '这会让你把注意力放在“我要显得厉害”，而不是“我要继续学”。',
        ),
        _MissionChoice(
          title: '改夸过程与努力',
          subtitle: '让注意力回到尝试、投入和学习本身。',
          healthy: true,
          feedback: '这更贴近本段原意：你在强化成长型思维，而不是固定型标签。',
        ),
        _MissionChoice(
          title: '选一个更能学到东西的任务',
          subtitle: '不选最容易成功的那个，选更能长能力的那个。',
          healthy: true,
          feedback: '你开始把“看起来聪明”换成“真实学习”。',
        ),
      ];
    case 'L15-16':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续只奖励结果',
          subtitle: '这样会让行动越来越绑在成败和形象上。',
          healthy: false,
          feedback: '你会越来越怕失败，因为只要没成，就像一切都不算数。',
        ),
        _MissionChoice(
          title: '奖励今天的尝试与过程',
          subtitle: '把注意力重新放回出现、练习和投入。',
          healthy: true,
          feedback: '这更贴近本段原意：真正要强化的是行动过程，而不只是最终结果。',
        ),
        _MissionChoice(
          title: '给自己记一次“我试了”',
          subtitle: '哪怕结果一般，也把这次尝试留档。',
          healthy: true,
          feedback: '你开始训练大脑把“尝试本身”也当成值得强化的经验。',
        ),
      ];
    case 'L16-4':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续只按钱、头衔、下一站驱动',
          subtitle: '这样很容易越来越像在赶路。',
          healthy: false,
          feedback: '你会越来越把自己活成任务推进器，而不是一个知道自己为什么在做的人。',
        ),
        _MissionChoice(
          title: '先识别当前主要驱动力',
          subtitle: '不急着改变人生，先看清自己现在主要被什么推着走。',
          healthy: true,
          feedback: '这更贴近本段原意：先识别工作取向，再谈调整。',
        ),
        _MissionChoice(
          title: '把动机落到今天一个更真实的动作',
          subtitle: '从动机罗盘回到现实任务。',
          healthy: true,
          feedback: '你开始让动机不只停留在分析层，而是进入具体选择。',
        ),
      ];
    case 'L16-7':
      return <_MissionChoice>[
        _MissionChoice(
          title: '继续只看物质回报',
          subtitle: '这会让工作越来越薄，只剩消耗与交换。',
          healthy: false,
          feedback: '你会更难看见这件事在现实世界里的真实价值链。',
        ),
        _MissionChoice(
          title: '找出现实里已经存在的价值链',
          subtitle: '不是自我粉饰，而是识别真正的社会贡献。',
          healthy: true,
          feedback: '这更贴近本段原意：意义不是凭空编，而是把真实价值看见。',
        ),
        _MissionChoice(
          title: '把价值链翻成今天一件更有意识的动作',
          subtitle: '让意义进入行为，而不是只停在解释。',
          healthy: true,
          feedback: '你开始把“意义视角”带回现实动作，这才会真正改变体验。',
        ),
      ];
    default:
      return <_MissionChoice>[
        _MissionChoice(
          title: '沿用旧剧本：先躲、先拖、先等更稳',
          subtitle: '这通常会暂时减压，但也会把“$firstConcept”继续留在脑内，不会真正训练出来。',
          healthy: false,
          feedback: '你暂时减轻了不适，但也把自己继续锁在旧模式里。对 ${unit.title} 来说，真正关键的不是再想清楚一点，而是让自己出现一次。',
        ),
        _MissionChoice(
          title: '做一个和本段概念一致的最小动作',
          subtitle: '把课程原内容翻译成今天就能做的小步，而不是等状态完美。',
          healthy: true,
          feedback: '这条路径更接近课程原意：你没有把概念停在理解层，而是把它压缩成了一个真实动作。',
        ),
        _MissionChoice(
          title: '先用本段方法处理自动想法，再决定行动',
          subtitle: '例如最坏情况重估、Three Ps、优势介入或“够好原则”等。',
          healthy: true,
          feedback: '你没有直接被自动想法牵走，而是先用本段课程提供的方法把自己拉回可分析、可承受、可行动的层面。',
        ),
      ];
  }
}

String _missionScenario(HappinessUnit unit, {String role = '通用', String realVersion = ''}) {
  final String course = unit.courseCases.isNotEmpty ? unit.courseCases.first : unit.summary;
  final String life = unit.lifeCases.isNotEmpty ? unit.lifeCases.first : unit.summary;
  final String mapped = realVersion.trim().isEmpty ? '你可以先把它换成自己的现实版本，例如：$life' : '你当前输入的现实版本是：${realVersion.trim()}';
  return '场景原型来自这一段课程：$course。角色身份：$role。$mapped。此刻你最可能掉进的旧模式，是“${behaviorSpecFor(unit).oldPattern}”。面对这个场景，你会怎么回应？';
}

String _missionRecovery(HappinessUnit unit, bool healthyPath) {
  if (healthyPath) return '接下来不要只停在“我懂了”，而是立刻把刚才这条更健康路径迁移到现实中的一个动作：${unit.defaultActionTitle}。';
  if (unit.tags.contains('完美主义')) return '就算刚才选了旧路径，也不要再用完美主义骂自己。先承认：这就是旧剧本，然后把动作缩到最小一步。';
  if (unit.tags.contains('失败')) return '退缩或失手不是终局。把标准降到“再出现一次”，而不是“下次必须漂亮”。';
  if (unit.tags.contains('calling') || unit.tags.contains('意义')) return '先别急着把整条路判错，先把视角从“现在没感觉”拉回“这件事真实的价值和下一步是什么”。';
  return '恢复不是一下子拉满自己，而是先回到可行动状态，再做一个与本段概念一致的小动作。';
}

String _diagnosisAnalysis(String q, HappinessUnit? best) {
  if (q.contains('失败') || q.contains('拒绝')) {
    return '你现在更像是卡在“失败 / 评价 / 回避”这条线上：不是单纯不会做，而是担心一旦不顺，就会被定义成不够好。先练让自己重新出现，再慢慢提高承受力。推荐先从 ${best?.id ?? '相关单元'} 开始。';
  }
  if (q.contains('完美')) {
    return '你现在更像是被完美主义卡住：目标本身未必有问题，问题在于你把偏差、瑕疵、失败都解释成了自我价值问题。先别急着“治好”，先看见并做一个更小动作。推荐先从 ${best?.id ?? '相关单元'} 开始。';
  }
  if (q.contains('结果') || q.contains('意义')) {
    return '你现在更像是卡在“只盯结果 / 过程失配 / 意义变薄”这条线上。要补的不是更硬扛，而是重新看见过程、优势和意义。推荐先从 ${best?.id ?? '相关单元'} 开始。';
  }
  return '你现在的问题很可能不是单一症状，而是多个模式叠加。先挑一个最贴近你的单元进入，不求一次解决，只求开始一条更真实的训练路径。';
}

String _statusLabel(String status) {
  switch (status) {
    case 'doing':
      return '进行中';
    case 'done':
      return '已完成';
    case 'skipped':
      return '回避/跳过';
    default:
      return '待开始';
  }
}


HappinessUnit? _unitById(String id) {
  for (final HappinessUnit unit in happinessUnits) {
    if (unit.id == id) return unit;
  }
  return null;
}

String _growthNarrative({required List<HappinessAction> actions, required List<HappinessReviewEntry> reviews}) {
  if (actions.isEmpty && reviews.isEmpty) {
    return '你还在起步阶段。先完成一两个课程单元、保存几条行动、写几次复盘，这里会逐渐显示你自己的成长轨迹。';
  }
  final int done = actions.where((HappinessAction e) => e.status == 'done').length;
  final int doing = actions.where((HappinessAction e) => e.status == 'doing').length;
  if (done > 0 && reviews.isNotEmpty) {
    return '你已经不只是停在“懂了”，而是开始把课程往现实里搬。真正值得保持的，不是一次做得多完美，而是你已经开始形成：学习 → 行动 → 记录 → 复盘 的节奏。';
  }
  if (doing > 0) {
    return '你现在已经有行动在推进中了。接下来最关键的不是加很多新任务，而是把现有动作做完、写下事实，再用复盘把经验回扣到概念。';
  }
  return '你已经开始建立训练痕迹。下一步建议把“行动”与“复盘”绑得更紧，让每一次尝试都沉淀成可复用的经验。';
}


String _historyInsight(List<HappinessAction> actions, List<HappinessReviewEntry> reviews) {
  if (actions.isEmpty && reviews.isEmpty) return '现在还没有足够的历史样本。先保存几条行动、完成几次复盘，这里会开始归纳你的旧模式与更有效的新动作。';
  final List<HappinessAction> done = actions.where((a) => a.status == 'done').toList();
  final List<HappinessAction> skipped = actions.where((a) => a.status == 'skipped').toList();
  final List<HappinessAction> doing = actions.where((a) => a.status == 'doing').toList();
  final unitIds = <String, int>{};
  for (final a in actions) { unitIds[a.unitId] = (unitIds[a.unitId] ?? 0) + 1; }
  final hottest = unitIds.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
  final focus = hottest.isEmpty ? '当前还没有明显聚焦单元' : '你最近最常围绕 ${hottest.first.key} 反复训练，说明这个主题正在成为你当前最需要处理的现实议题。';
  final statusLine = skipped.isNotEmpty
      ? '你现在最需要防的不是“做得不够好”，而是被不适感带回回避。最近有 ${skipped.length} 条动作停在回避/跳过。'
      : done.isNotEmpty
          ? '你已经有 ${done.length} 条动作完成，这说明你正在形成“出现—记录—调整”的节奏。'
          : doing.isNotEmpty
              ? '你目前有 ${doing.length} 条动作处于推进中，重点是把它们做完并留下事实记录。'
              : '你已经开始保存动作，下一步重点是让动作真正落地并进入复盘。';
  final reviewLine = reviews.isNotEmpty
      ? '最近复盘说明你已经不只是停在理解层，而是在开始把经验反推回概念。'
      : '下一步建议至少完成一次复盘，让经验真正沉淀下来。';
  return '$focus\n\n$statusLine\n\n$reviewLine';
}

Map<String, String>? _nextActionRecommendation(List<HappinessAction> actions, List<HappinessReviewEntry> reviews) {
  final Map<String, int> unitCount = <String, int>{};
  for (final a in actions) {
    unitCount[a.unitId] = (unitCount[a.unitId] ?? 0) + 1;
  }
  for (final r in reviews) {
    unitCount[r.unitId] = (unitCount[r.unitId] ?? 0) + 1;
  }
  if (unitCount.isEmpty) return null;
  final hottest = unitCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final HappinessUnit? unit = _unitById(hottest.first.key);
  if (unit == null) return null;
  final List<_ActionDraft> variants = _actionVariantsFor(unit);
  final HappinessAction? doing = actions.where((a) => a.unitId == unit.id && a.status == 'doing').cast<HappinessAction?>().firstWhere((e) => e != null, orElse: () => null);
  final HappinessAction? skipped = actions.where((a) => a.unitId == unit.id && a.status == 'skipped').cast<HappinessAction?>().firstWhere((e) => e != null, orElse: () => null);
  if (doing != null) {
    return <String, String>{
      'unitId': unit.id,
      'title': '先完成一条正在推进的动作',
      'subtitle': '你在 $unit.id 已经有进行中的训练。先把它做完，再决定是否加新动作。',
      'actionTitle': doing.title,
      'body': '建议先回到行动中心，把这条动作补完，并写下事实记录。',
    };
  }
  if (skipped != null) {
    return <String, String>{
      'unitId': unit.id,
      'title': '先回到一个更小一步的版本',
      'subtitle': '你在 $unit.id 曾出现回避/跳过，下一轮更适合从最小一步重启。',
      'actionTitle': variants.first.title,
      'body': variants.first.body,
    };
  }
  return <String, String>{
    'unitId': unit.id,
    'title': '下一轮最适合继续加深的单元：${unit.id}',
    'subtitle': '这个主题是你最近最常接触的练习点，适合继续做一次更具体的动作。',
    'actionTitle': variants.length > 1 ? variants[1].title : variants.first.title,
    'body': variants.length > 1 ? variants[1].body : variants.first.body,
  };
}

HappinessAction? _recommendedActionDraft(Map<String, String>? rec) {
  if (rec == null) return null;
  final HappinessUnit? unit = _unitById(rec['unitId'] ?? '');
  if (unit == null) return null;
  final List<_ActionDraft> variants = _actionVariantsFor(unit);
  _ActionDraft chosen = variants.length > 1 ? variants[1] : variants.first;
  if ((rec['actionTitle'] ?? '') == variants.first.title) chosen = variants.first;
  return HappinessAction(
    id: 'history_rec_${unit.id}_${DateTime.now().millisecondsSinceEpoch}',
    unitId: unit.id,
    unitTitle: unit.title,
    source: 'history_recommend',
    title: chosen.title,
    body: chosen.body,
    difficulty: chosen.difficulty,
    duration: chosen.duration,
    successCriteria: chosen.successCriteria,
    fallbackAction: chosen.fallbackAction,
    reviewQuestion: unit.reflectionQuestion,
    createdAt: DateTime.now().millisecondsSinceEpoch,
    planNote: chosen.steps.isNotEmpty ? chosen.steps.first : _trainingFocusFor(unit).first,
    obstacleNote: chosen.fallbackAction,
    nextStepNote: chosen.steps.length > 1 ? chosen.steps.last : behaviorSpecFor(unit).newPattern,
    steps: chosen.steps,
    stepMarks: List<bool>.filled(chosen.steps.length, false),
  );
}

String _sceneIntro(String sceneName) {
  switch (sceneName) {
    case '跌倒训练场':
      return '这里专门练“失败不是例外，而是学习机制”。你会在反复尝试、跌倒、恢复中理解成长的真实路径。';
    case '拒绝广场':
      return '这里练“面对评价、承受拒绝、继续出现”。重点不是一次就顺，而是你能否在不确定中仍然行动。';
    case '决策大厅':
      return '这里练“最坏情况重估”和“过程契合”。你要把脑中的灾难化，拉回可分析、可承受、可学习。';
    case '镜像大厅':
      return '这里练“看见自己的自动剧本”。你会识别防御、全有或全无、自我苛责，以及如何改写它们。';
    case '关系剧场':
      return '这里练“在不完美关系里沟通、修复、继续相处”。不是没有冲突，而是学会面对冲突。';
    case '复原室':
      return '这里练困难时刻的恢复力，重点是 Three Ps、自我接纳和从混乱中恢复秩序。';
    case '使命工坊':
      return '这里练“工作与人生如何从差事/事业转向更有意义的投入方式”。';
    case '优势实验室':
      return '这里练 VIA 与优势迁移：找到真正的我，并让优势直接服务于现实问题。';
    default:
      return '这里是知行城中的训练场景，用于把课程概念先在虚拟世界里练熟。';
  }
}

String _sceneMission(HappinessUnit unit) {
  final String caseHint = unit.courseCases.isNotEmpty ? unit.courseCases.first : unit.summary;
  return '先在 ${unit.scene} 里把本段核心矛盾放进一个接近现实的训练场景：$caseHint 然后再迁移到现实动作“${unit.defaultActionTitle}”。';
}

String _autoThought(HappinessUnit unit) {
  final HappinessConceptLens lens = conceptLensFor(unit, unit.concepts.first);
  final String s = lens.experience;
  final int idx = s.indexOf('。');
  return idx > 0 ? s.substring(0, idx + 1) : s;
}

String _bodyCue(HappinessUnit unit) {
  if (unit.tags.contains('完美主义')) return '常见是肩颈绷紧、胃里发沉、脑子开始反复重放细节，然后拖着不交或过度修正。';
  if (unit.tags.contains('失败')) return '常见是胸口一紧、脸发热、想先消失一下，或者先用拖延把自己从风险里挪开。';
  if (unit.tags.contains('关系')) return '常见是心里堵住、喉咙紧、既想解释自己又想躲开对话。';
  if (unit.tags.contains('calling') || unit.tags.contains('意义')) return '常见是整个人发空、提不起劲，只想赶紧熬到结果或下一个阶段。';
  return '常见是心里先紧一下，注意力变窄，只想先摆脱眼前这个场景。';
}

String _oldPattern(HappinessUnit unit) {
  if (unit.tags.contains('完美主义')) return '旧行为通常是：反复打磨、不敢提交、过度检查，或者因为怕做不到完美而拖着不开始。';
  if (unit.tags.contains('失败')) return '旧行为通常是：为了不失败先少试、先不试，或者一旦失败就把整个人从场上撤下来。';
  if (unit.tags.contains('关系')) return '旧行为通常是：防御、解释、冷掉或把对方判成“不够好”，而不是进入修复。';
  if (unit.tags.contains('calling') || unit.tags.contains('意义')) return '旧行为通常是：只盯结果、只盯下一站，越来越感受不到当下过程里真实的价值和活力。';
  return '旧行为通常是：一直停在脑内分析，不真正把概念翻译成现实动作。';
}

List<String> _trainingFocusFor(HappinessUnit unit) {
  final HappinessBehaviorSpec spec = behaviorSpecFor(unit);
  switch (unit.id) {
    case 'L14-4':
      return <String>['最容易被触发的情境：一次落选、失误、项目受挫后，想立刻给整条路下结论的时候。','最自动的旧想法：这次都这样了，说明我这条路不行，或者我就是不行。','这一段真正要练的新动作：把这次挫折放回长期尺度，提炼它逼出来的新能力。','事实记录重点：这次失败到底让我更清楚了什么、练出了什么，而不是我有多糟。'];
    case 'L14-5':
      return <String>['最容易被触发的情境：团队、关系或项目里有人犯错、自己出错、事情失控时。','最自动的旧想法：先找责任人，先证明不是我，先避免羞耻。','这一段真正要练的新动作：把错误从责备对象改成复盘对象。','事实记录重点：问题机制是什么、学到了什么、下次如何避免重复。'];
    case 'L14-6':
      return <String>['最容易被触发的情境：做一两次没结果，就很想放弃的时候。','最自动的旧想法：如果有效，早该有感觉了；如果我适合，就不会失败这么多。','这一段真正要练的新动作：先追踪尝试次数和样本量，再谈能力判断。','事实记录重点：本周到底上场几次、共通卡点是什么，而不是只看成没成。'];
    case 'L15-1':
      return <String>['最容易被触发的情境：出现一个小差错、小瑕疵、小偏差时。','最自动的旧想法：赶紧遮住、解释、补偿，不然太不像样。','这一段真正要练的新动作：允许一处小偏差存在，同时继续推进重要事情。','事实记录重点：我有没有在修问题，还是其实在掩盖不完美痕迹。'];
    case 'L15-2':
      return <String>['最容易被触发的情境：第一次做、还不熟练、明显很生涩的时候。','最自动的旧想法：如果我是适合的，我就不该这么笨拙。','这一段真正要练的新动作：允许练习阶段的不够好存在，先留下样本。','事实记录重点：我今天练了什么、和第一次相比哪里稍微顺了一点。'];
    case 'L15-3':
      return <String>['最容易被触发的情境：换环境、换角色、换赛道后，熟悉的紧绷又出现时。','最自动的旧想法：环境换了，为什么我还是这么难受。','这一段真正要练的新动作：识别旧剧本已经迁移进来了，再做一个小反动作。','事实记录重点：我最常重复的旧剧本是什么，它今天又在哪个新场景出现了。'];
    case 'L15-4':
      return <String>['最容易被触发的情境：面对大目标、重要任务、野心和要求都很高的时候。','最自动的旧想法：如果我放松一点，就说明我没有 ambition。','这一段真正要练的新动作：保留抱负，放松“路径必须毫无偏差”的要求。','事实记录重点：我今天是在认真追求卓越，还是在用完美主义换安全感。'];
    case 'L15-5':
      return <String>['最容易被触发的情境：准备发出第一版、提交粗稿、让别人看见初稿时。','最自动的旧想法：再等等，还不够像样；第一版不能太丢脸。','这一段真正要练的新动作：先交一版，再把改进留给现实反馈。','事实记录重点：我是不是终于让现实看见了第一版，而不是继续卡在脑内修稿。'];
    case 'L15-15':
      return <String>['最容易被触发的情境：旧模式刚要启动，但还没有完全接管的时候。','最自动的旧想法：我就是会这样；这没什么好说的。','这一段真正要练的新动作：先点名旧剧本，再做一个与它相反的小动作。','事实记录重点：我今天最早是在什么时候看见旧剧本的，它后来有没有完全接管我。'];
    case 'L16-2':
      return <String>['最容易被触发的情境：结果很诱人，但过程让我越来越耗的时候。','最自动的旧想法：只要终点值得，过程再不舒服都得扛。','这一段真正要练的新动作：把结果契合和过程契合分开评估，再调一个过程环节。','事实记录重点：结果分是多少，过程分是多少，哪一个过程细节最值得调整。'];
    case 'L16-3':
      return <String>['最容易被触发的情境：谈到工作、学习、长期投入时，感到自己只是一直在往前冲。','最自动的旧想法：反正就是干活、升下一步、拿结果。','这一段真正要练的新动作：区分自己当前更偏差事、事业还是召唤，再看能否往 calling 拉近一点。','事实记录重点：我最近最常被什么推着走，我期待的究竟是工资、头衔还是更深的实现感。'];
    case 'L16-5':
      return <String>['最容易被触发的情境：一件本来很重要的事里出现重复、琐碎、枯燥部分时。','最自动的旧想法：如果这真是我的 calling，我就不该觉得烦。','这一段真正要练的新动作：把局部枯燥和整体意义拆开，允许两者同时存在。','事实记录重点：我接纳的是哪个必要但不喜欢的环节，它为什么仍值得承受。'];
    case 'L16-6':
      return <String>['最容易被触发的情境：觉得自己的工作只是重复任务、难以看见意义的时候。','最自动的旧想法：这不就是在做杂事 / 打工 / 扛责任吗。','这一段真正要练的新动作：把工作价值链重新写出来，看见它真实服务了谁、连接了什么。','事实记录重点：我今天重新看见了哪一层真实价值，它有没有让事情更有连接感。'];
    case 'L14-4':
      return <String>['最容易被触发的情境：一次落选、失误、项目受挫后，想立刻给整条路下结论的时候。','最自动的旧想法：这次都这样了，说明我这条路不行，或者我就是不行。','这一段真正要练的新动作：把这次挫折放回长期尺度，提炼它逼出来的新能力。','事实记录重点：这次失败到底让我更清楚了什么、练出了什么，而不是我有多糟。'];
    case 'L14-5':
      return <String>['最容易被触发的情境：团队、关系或项目里有人犯错、自己出错、事情失控时。','最自动的旧想法：先找责任人，先证明不是我，先避免羞耻。','这一段真正要练的新动作：把错误从责备对象改成复盘对象。','事实记录重点：问题机制是什么、学到了什么、下次如何避免重复。'];
    case 'L14-6':
      return <String>['最容易被触发的情境：做一两次没结果，就很想放弃的时候。','最自动的旧想法：如果有效，早该有感觉了；如果我适合，就不会失败这么多。','这一段真正要练的新动作：先追踪尝试次数和样本量，再谈能力判断。','事实记录重点：本周到底上场几次、共通卡点是什么，而不是只看成没成。'];
    case 'L15-1':
      return <String>['最容易被触发的情境：出现一个小差错、小瑕疵、小偏差时。','最自动的旧想法：赶紧遮住、解释、补偿，不然太不像样。','这一段真正要练的新动作：允许一处小偏差存在，同时继续推进重要事情。','事实记录重点：我有没有在修问题，还是其实在掩盖不完美痕迹。'];
    case 'L15-2':
      return <String>['最容易被触发的情境：第一次做、还不熟练、明显很生涩的时候。','最自动的旧想法：如果我是适合的，我就不该这么笨拙。','这一段真正要练的新动作：允许练习阶段的不够好存在，先留下样本。','事实记录重点：我今天练了什么、和第一次相比哪里稍微顺了一点。'];
    case 'L15-3':
      return <String>['最容易被触发的情境：换环境、换角色、换赛道后，熟悉的紧绷又出现时。','最自动的旧想法：环境换了，为什么我还是这么难受。','这一段真正要练的新动作：识别旧剧本已经迁移进来了，再做一个小反动作。','事实记录重点：我最常重复的旧剧本是什么，它今天又在哪个新场景出现了。'];
    case 'L15-4':
      return <String>['最容易被触发的情境：面对大目标、重要任务、野心和要求都很高的时候。','最自动的旧想法：如果我放松一点，就说明我没有 ambition。','这一段真正要练的新动作：保留抱负，放松“路径必须毫无偏差”的要求。','事实记录重点：我今天是在认真追求卓越，还是在用完美主义换安全感。'];
    case 'L15-5':
      return <String>['最容易被触发的情境：准备发出第一版、提交粗稿、让别人看见初稿时。','最自动的旧想法：再等等，还不够像样；第一版不能太丢脸。','这一段真正要练的新动作：先交一版，再把改进留给现实反馈。','事实记录重点：我是不是终于让现实看见了第一版，而不是继续卡在脑内修稿。'];
    case 'L15-15':
      return <String>['最容易被触发的情境：旧模式刚要启动，但还没有完全接管的时候。','最自动的旧想法：我就是会这样；这没什么好说的。','这一段真正要练的新动作：先点名旧剧本，再做一个与它相反的小动作。','事实记录重点：我今天最早是在什么时候看见旧剧本的，它后来有没有完全接管我。'];
    case 'L16-2':
      return <String>['最容易被触发的情境：结果很诱人，但过程让我越来越耗的时候。','最自动的旧想法：只要终点值得，过程再不舒服都得扛。','这一段真正要练的新动作：把结果契合和过程契合分开评估，再调一个过程环节。','事实记录重点：结果分是多少，过程分是多少，哪一个过程细节最值得调整。'];
    case 'L16-3':
      return <String>['最容易被触发的情境：谈到工作、学习、长期投入时，感到自己只是一直在往前冲。','最自动的旧想法：反正就是干活、升下一步、拿结果。','这一段真正要练的新动作：区分自己当前更偏差事、事业还是召唤，再看能否往 calling 拉近一点。','事实记录重点：我最近最常被什么推着走，我期待的究竟是工资、头衔还是更深的实现感。'];
    case 'L16-5':
      return <String>['最容易被触发的情境：一件本来很重要的事里出现重复、琐碎、枯燥部分时。','最自动的旧想法：如果这真是我的 calling，我就不该觉得烦。','这一段真正要练的新动作：把局部枯燥和整体意义拆开，允许两者同时存在。','事实记录重点：我接纳的是哪个必要但不喜欢的环节，它为什么仍值得承受。'];
    case 'L16-6':
      return <String>['最容易被触发的情境：觉得自己的工作只是重复任务、难以看见意义的时候。','最自动的旧想法：这不就是在做杂事 / 打工 / 扛责任吗。','这一段真正要练的新动作：把工作价值链重新写出来，看见它真实服务了谁、连接了什么。','事实记录重点：我今天重新看见了哪一层真实价值，它有没有让事情更有连接感。'];
    case 'L15-6':
      return <String>[
        '最容易被触发的情境：进展不顺、计划被打断、被追问、被看见瑕疵时。',
        '最自动的旧想法：怎么不是一路顺着上去？是不是我不适合。',
        '这一段真正要练的新动作：先给波动命名，再决定最小恢复动作，不立刻把整条路判错。',
        '事实记录重点：这次更像绕路、停顿、回撤还是重练；我真正做了哪一步继续上场。',
      ];
    case 'L14-3':
      return <String>[
        '最容易被触发的情境：主动发出请求、表达需求、公开提交、做一个带风险的决定前。',
        '最自动的旧想法：如果不顺就完了、很丢脸、以后都不行。',
        '这一段真正要练的新动作：把最坏结果写具体，再写应对动作，再做一小步。',
        '事实记录重点：脑补最坏和真实结果之间差了多少；我真正承受不了的到底是什么。',
      ];
    case 'L15-18':
      return <String>[
        '最容易被触发的情境：明知该做却想继续准备、继续想、继续拖的时候。',
        '最自动的旧想法：再等等、再想清楚、再改好一点再说。',
        '这一段真正要练的新动作：先做一个真实接触动作，让现实反馈先发生。',
        '事实记录重点：我从“想做”到“真的做”的那一秒，最卡的是什么。',
      ];
    case 'L15-22':
      return <String>[
        '最容易被触发的情境：迟到、讲砸、计划乱掉、临时被打断、连续不顺的时候。',
        '最自动的旧想法：我怎么又这样、现在全乱了、必须马上把一切修好。',
        '这一段真正要练的新动作：先做 Three Ps，再只处理下一件最小现实任务。',
        '事实记录重点：哪一个 P 最帮助我恢复；我恢复行动能力靠的是哪一步。',
      ];
    case 'L14-1':
      return <String>[
        '最容易被触发的情境：第一次做、还很生涩、明显不熟练、容易丢脸的时候。',
        '最自动的旧想法：我这么笨拙，是不是根本不适合。',
        '这一段真正要练的新动作：不证明自己厉害，只完成第一份可学习样本。',
        '事实记录重点：这次到底学到了什么，下次最值得调整的一步是什么。',
      ];
    case 'L14-2':
      return <String>[
        '最容易被触发的情境：会议发言、表达需求、提问、请求帮助、公开出现时。',
        '最自动的旧想法：别人会不会觉得我很蠢、很烦、很差。',
        '这一段真正要练的新动作：先在一个安全但真实的场景里出现一次，而不是继续消失。',
        '事实记录重点：真正发生了什么，别人真的像我脑补的那样评价我了吗。',
      ];
    case 'L15-20':
      return <String>[
        '最容易被触发的情境：犯错、进展不顺、被指出问题、没达到自己期待的时候。',
        '最自动的旧想法：怎么又这样、你怎么这么差、这都做不好。',
        '这一段真正要练的新动作：把那句责骂改写成你会对朋友说的话。',
        '事实记录重点：原句是什么，改写后情绪有没有一点变化，我是否更愿意继续行动。',
      ];
    case 'L16-8':
      return <String>[
        '最容易被触发的情境：做事发空、只剩硬撑、过程没有活力的时候。',
        '最自动的旧想法：反正就是得做完，过程没什么好说的。',
        '这一段真正要练的新动作：选一个优势，让它直接进入今天的一件具体事情。',
        '事实记录重点：优势具体做了什么动作，它有没有让过程更像真实的我。',
      ];
    case 'L16-10':
      return <String>[
        '最容易被触发的情境：问题反复出现、硬扛没用、又回到旧剧本的时候。',
        '最自动的旧想法：我是不是就改不了；我是不是又不行。',
        '这一段真正要练的新动作：选一个优势，让它具体参与解决一个现实问题。',
        '事实记录重点：优势不是标签，而是在现实里帮我做了什么动作。',
      ];

    case 'L15-8':
      return <String>[
        '最容易被触发的情境：任务完成、节点结束、终于过关的时候。',
        '最自动的旧想法：终于松口气了；赶紧去下一个，不然会落后。',
        '这一段真正要练的新动作：先停留，整合过程里的真实收获，再进入下一站。',
        '事实记录重点：我完成后有没有立刻逃向下一站；过程里已有的价值是什么。',
      ];
    case 'L15-9':
      return <String>[
        '最容易被触发的情境：计划偏了一点、饮食破了一次、自律断了一天的时候。',
        '最自动的旧想法：既然已经偏了，那就全完了。',
        '这一段真正要练的新动作：练一次适度版本，把偏差留在局部而不是整天作废。',
        '事实记录重点：我是如何从“全盘作废”拉回“局部调整”的。',
      ];
    case 'L15-13':
      return <String>[
        '最容易被触发的情境：评价自己、评价孩子、评价伴侣或同事表现的时候。',
        '最自动的旧想法：要夸厉害、夸聪明、夸结果。',
        '这一段真正要练的新动作：把注意力改到努力、过程和学习上。',
        '事实记录重点：改夸过程之后，对方和我自己的感受有没有变化。',
      ];
    case 'L15-16':
      return <String>[
        '最容易被触发的情境：尝试了但结果一般、刚开始练、还没看见成效的时候。',
        '最自动的旧想法：结果不够好，就说明这次不算数。',
        '这一段真正要练的新动作：把“出现、尝试、投入”本身也当成值得强化的经验。',
        '事实记录重点：今天哪一个尝试本身就值得被记录，而不必等到它完美。',
      ];
    case 'L15-11':
      return <String>[
        '最容易被触发的情境：靠硬压自己往前推、觉得只有更狠才会更有效的时候。',
        '最自动的旧想法：只要我再逼一点，表现就会更好。',
        '这一段真正要练的新动作：把高压推进改成可持续推进，先保住节奏而不是燃尽自己。',
        '事实记录重点：今天哪一个动作更可持续，它和“爆冲—崩掉”有什么不同。',
      ];
    case 'L15-12':
      return <String>[
        '最容易被触发的情境：刷到完美模板、看到别人表现、看到影视或媒体叙事时。',
        '最自动的旧想法：别人都可以那样，我也应该那样。',
        '这一段真正要练的新动作：识别外部模板正在如何塑造我的标准，再把标准拉回真实人类版本。',
        '事实记录重点：今天是哪一个模板让我开始自我否定，我把它拆掉了多少。',
      ];
    case 'L15-14':
      return <String>[
        '最容易被触发的情境：任务很多、材料很多、总觉得每一块都必须做到最好的时候。',
        '最自动的旧想法：如果不是每一块都顾到，我就不算认真。',
        '这一段真正要练的新动作：先抓最关键的 20%，让“够好完成”优先于“全都完美”。',
        '事实记录重点：我今天真正推动结果的是哪几个关键动作，而不是我做了多少无效打磨。',
      ];
    case 'L15-17':
      return <String>[
        '最容易被触发的情境：又看到老问题出现、觉得自己怎么还这样的时候。',
        '最自动的旧想法：如果我还会这样，说明我根本没变。',
        '这一段真正要练的新动作：承认旧问题会回来，但我仍然可以带着它继续行动。',
        '事实记录重点：今天我不是有没有彻底摆脱问题，而是在问题还在时我仍然做了什么。',
      ];
    case 'L15-19':
      return <String>[
        '最容易被触发的情境：即将面对让自己紧张的公开场景、表达场景或评价场景之前。',
        '最自动的旧想法：我怕一上场就失控或表现得很差。',
        '这一段真正要练的新动作：先用可视化和呼吸把自己带进更稳的状态，再去行动。',
        '事实记录重点：状态切换前后，我的身体和想法有什么变化。',
      ];
    case 'L15-21':
      return <String>[
        '最容易被触发的情境：看到重要的人被完美主义困住，很想立刻纠正或替他解决时。',
        '最自动的旧想法：我必须马上把他讲明白，不然他会一直这样。',
        '这一段真正要练的新动作：减少说教和控制，多示范、分享和奖励对方的过程。',
        '事实记录重点：今天我是更像在支持对方，还是更像在控制对方快点变好。',
      ];
    case 'L15-23':
      return <String>[
        '最容易被触发的情境：时间被打乱、节奏崩掉、同时有多件事挤在一起的时候。',
        '最自动的旧想法：全乱了，我得立刻把一切救回来。',
        '这一段真正要练的新动作：先尊重现实负荷，做一轮微复原，再重新排下一步。',
        '事实记录重点：混乱发生后，我是更急着控制，还是先恢复再安排。',
      ];
    case 'L16-1':
      return <String>[
        '最容易被触发的情境：一谈到目标就只看终点、不看过程感受的时候。',
        '最自动的旧想法：只要最后到了，过程怎样无所谓。',
        '这一段真正要练的新动作：把注意力从终点稍微拉回今天的过程体验。',
        '事实记录重点：今天哪一个时刻，我把幸福从未来终点拉回了一点过程。',
      ];
    case 'L16-9':
      return <String>[
        '最容易被触发的情境：今天做了很多事，却分不清什么时候最像自己、什么时候只是在表演的时候。',
        '最自动的旧想法：我是不是该更像别人那样才算好。',
        '这一段真正要练的新动作：捕捉一个“这才是我”的时刻，并反推当时用了什么方式出现。',
        '事实记录重点：那个时刻我在做什么、为什么更有生命力。',
      ];
    case 'L16-4':
      return <String>[
        '最容易被触发的情境：忙着赶 KPI、赶晋升、赶下一站的时候。',
        '最自动的旧想法：先到下一层再说，现在没空看过程。',
        '这一段真正要练的新动作：先识别当前驱动力，再做一个更贴真实价值的动作。',
        '事实记录重点：今天主导我的到底是差事、事业还是召唤逻辑。',
      ];
    case 'L16-7':
      return <String>[
        '最容易被触发的情境：一想到工作只剩赚钱、消耗、应付时。',
        '最自动的旧想法：这不就是为了钱，还有什么好说的。',
        '这一段真正要练的新动作：找出真实价值链，并让它落到一个今天的行为。',
        '事实记录重点：我看见了哪条真实价值链，它如何改变了我的参与方式。',
      ];
    default:
      final String firstConcept = unit.concepts.isEmpty ? unit.title : unit.concepts.first;
      return <String>[
        '最容易被触发的情境：${spec.trigger}',
        '最自动的旧想法：${spec.thought}',
        '这一段真正要练的不是“懂”，而是把“$firstConcept”落实成新动作：${spec.newPattern}',
        '这次记录重点不要写抽象评价，优先记：${spec.fact}',
      ];
  }
}

String _sceneChainFor(HappinessUnit unit) {
  final HappinessBehaviorSpec spec = behaviorSpecFor(unit);
  switch (unit.id) {
    case 'L14-1':
      return '先允许自己以生涩版本进入场景；再做出第一份可学习样本；最后把“我学到了什么”而不是“我看起来怎样”带回行动中心。';
    case 'L14-2':
      return '先选一个低风险但真实的出现机会；再承受一次被看见；最后把现实反馈而不是脑补评价保存回行动中心。';
    case 'L14-3':
      return '先把“完了”拆成几个具体后果；再写应对动作和可承受性；最后把评估后的最小一步迁移回现实。';
    case 'L14-4':
      return '先把一次失利从人格结论改回长期节点；再提炼被逼出来的新能力；最后把其中一个能力迁移成现实动作。';
    case 'L14-5':
      return '先把错误从归责对象改成复盘对象；再写清问题机制和学习点；最后把避免重复的一步动作保存回行动中心。';
    case 'L14-6':
      return '先追踪样本量，而不是急着评价自己；再在场景里提高一次上场密度；最后把尝试次数和共通规律带回现实。';
    case 'L15-1':
      return '先允许小偏差出现；再区分“修问题”和“掩盖不完美”；最后在不做过度补偿的情况下继续推进正事。';
    case 'L15-2':
      return '先接受笨拙练习日；再做两轮小练习看微小变化；最后把“生涩”保存成成长区的事实证据。';
    case 'L15-3':
      return '先在场景里认出旧剧本又迁移过来了；再给它命名；最后带着识别后的清醒做一个不按旧剧本的小动作。';
    case 'L15-4':
      return '先把抱负和完美主义拆开；再把目标改写成卓越版；最后带着高标准但非零误差的路径进入现实动作。';
    case 'L15-5':
      return '先在场景里交出第一版；再限制修改轮次；最后把“先输出再优化”的路径迁移成今天的现实动作。';
    case 'L15-6':
      return '先给波动命名；再判断它在成长曲线里的位置；最后按卓越而非完美的标准继续推进一次。';
    case 'L15-7':
      return '先看见自己是掉进了防御、半杯空还是全有或全无；再把反馈转成一个具体修正；最后记录学习姿态有没有回来。';
    case 'L15-8':
      return '先停在结果后面不急着冲下一站；再提炼过程里真正得到的东西；最后把这种停留保存成下一轮训练的基础。';
    case 'L15-9':
      return '先阻止“偏一点=全完了”的自动化摆动；再做一次适度版本；最后把局部调整而不是全盘作废带回现实。';
    case 'L15-10':
      return '先把失望具体到事件和需求；再从理想模板退回真实关系；最后把一个修复动作迁移回现实。';
    case 'L15-11':
      return '先识别自己是不是又在用高压推自己；再把任务压回可持续节奏；最后只推进关键部分，并在行动中心继续追踪是否保住了节律。';
    case 'L15-12':
      return '先指出当前正在影响你的外部模板；再把标准拉回真实人类版本；最后把新的标准翻成一个今天能执行的小动作。';
    case 'L15-13':
      return '先识别自己又在夸结果还是夸人设；再改成夸过程与努力；最后观察这种改变如何影响自己和别人。';
    case 'L15-14':
      return '先找出最关键的20%；再放下其他部分的完美执念；最后把“够好完成”保存成可复盘的现实动作。';
    case 'L15-15':
      return '先识别旧剧本启动的最早时刻；再给它命名；最后用一个小反动作阻断它继续接管。';
    case 'L15-16':
      return '先把一次尝试从“结果一般”改看成“值得强化的出现”；再明确要奖励哪一步；最后继续做下一次更稳的尝试。';
    case 'L15-17':
      return '先承认老问题又来了；再决定带着它仍要做的一个动作；最后把“问题仍在时我也能行动”的事实带回行动中心。';
    case 'L15-18':
      return '先停止继续准备和继续想；再完成一个真实接触动作；最后把现实反馈原样带回行动中心。';
    case 'L15-19':
      return '先在场景里做短可视化和状态切换；再进入现实感更强的模拟路径；最后把更稳的进入方式迁移成现实动作。';
    case 'L15-20':
      return '先听见那句内在责骂；再把它改写成会对朋友说的话；最后带着新语气继续行动一次。';
    case 'L15-21':
      return '先看见自己想控制或说教的冲动；再改用分享、示范和奖励过程的路径；最后把这种支持方式带回现实关系。';
    case 'L15-22':
      return '先做 Permission；再做 Positive；再做 Perspective；最后只处理下一件最小现实任务。';
    case 'L15-23':
      return '先承认现实确实乱了；再做一次微复原；最后只选下一件最关键的现实动作，并继续追踪恢复节奏。';
    case 'L16-1':
      return '先从终点执念里退半步；再给过程加一个观察点；最后把“今天怎么走”保存为下一轮的行动线索。';
    case 'L16-2':
      return '先在场景里区分结果分和过程分；再挑一个过程环节做调节；最后把更高过程契合度的版本带回现实。';
    case 'L16-3':
      return '先区分自己当前更偏差事、事业还是召唤；再挑一个环节往 calling 靠近一点；最后把这种调整带回日常工作。';
    case 'L16-4':
      return '先看清自己最近的主要驱动力和期待结构；再识别是否总在等下一个阶段；最后把一个驱动结构调整成更可持续的版本。';
    case 'L16-5':
      return '先承认 calling 里也会有枯燥部分；再把局部枯燥和整体意义放在一起；最后继续承担那个必要环节。';
    case 'L16-6':
      return '先把工作从任务层面拉到价值链层面；再写出它服务了谁、连接了什么；最后把新的意义视角迁移回现实任务。';
    case 'L16-7':
      return '先区分粉饰和真实价值发现；再写出这件事真实支持了什么系统；最后把看见价值后的动作带回现实。';
    case 'L16-8':
      return '先判断哪个优势最适合今天这件事；再让优势通过一个现实动作上场；最后记录过程是否更像真正的我。';
    case 'L16-9':
      return '先抓住一个最有活力的场景瞬间；再反推那时你是怎样出现的；最后把这种“真实自我”的出现方式迁移回现实。';
    case 'L16-10':
      return '先判断当前问题最适合哪个优势上场；再把优势翻译成一个会被现实看见的动作；最后把这次优势介入保存回行动中心。';
    default:
      return '进入场景后，先把现实版本说清楚，再识别旧剧本“${spec.oldPattern}”，然后选择一条更符合本段概念的新路径“${spec.newPattern}”，最后把它保存为现实动作并在行动中心继续追踪。';
  }
}

String _microAction(HappinessUnit unit) => '把“${unit.defaultActionTitle}”缩成 5 分钟版本：只做最小的一步，只求出现，不求漂亮。';
String _stretchAction(HappinessUnit unit) => '在完成一次标准动作后，再增加一点真实暴露、反馈、不确定性或持续时间，让训练更贴近现实。';

String _conceptDefinition(HappinessUnit unit, String concept) => conceptLensFor(unit, concept).definition;
String _experienceCue(HappinessUnit unit, String concept) => conceptLensFor(unit, concept).experience;
String _realWorldCue(HappinessUnit unit, String concept) => conceptLensFor(unit, concept).realWorld;
String _practiceCue(HappinessUnit unit, String concept) => conceptLensFor(unit, concept).practice;

class HappinessGrowthArchivePage extends StatefulWidget {
  final List<HappinessAction> actions;
  final List<HappinessReviewEntry> reviews;
  final Set<String> doneUnits;
  final HappinessAiService ai;
  final Map<String, String> prompts;
  final Future<void> Function(HappinessAction action) onSaveAction;
  const HappinessGrowthArchivePage({super.key, required this.actions, required this.reviews, required this.doneUnits, required this.ai, required this.prompts, required this.onSaveAction});

  @override
  State<HappinessGrowthArchivePage> createState() => _HappinessGrowthArchivePageState();
}

class _HappinessGrowthArchivePageState extends State<HappinessGrowthArchivePage> {
  late String _historyText;
  bool _historyLoading = false;
  bool _nextActionLoading = false;
  HappinessAction? _aiRecommendedAction;

  @override
  void initState() {
    super.initState();
    _historyText = _historyInsight(widget.actions, widget.reviews);
  }

  Future<void> _generateAiHistory() async {
    setState(() => _historyLoading = true);
    try {
      final text = await widget.ai.generateHistoryInsight(
        actions: widget.actions,
        reviews: widget.reviews,
        extraPrompt: widget.prompts['history'] ?? '',
      );
      if (!mounted) return;
      setState(() => _historyText = text);
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _generateAiNextAction() async {
    setState(() => _nextActionLoading = true);
    try {
      final HappinessAction action = await widget.ai.generateNextRecommendedAction(
        actions: widget.actions,
        reviews: widget.reviews,
        extraPrompt: widget.prompts['next_action'] ?? '',
      );
      if (!mounted) return;
      setState(() => _aiRecommendedAction = action);
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _nextActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, int> tagCount = <String, int>{};
    for (final HappinessAction action in widget.actions) {
      final HappinessUnit? unit = _unitById(action.unitId);
      if (unit != null) {
        for (final String tag in unit.tags) {
          tagCount[tag] = (tagCount[tag] ?? 0) + 1;
        }
      }
    }
    final List<MapEntry<String, int>> topTags = tagCount.entries.toList()..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
    final int retryCount = widget.actions.where((HappinessAction e) => e.status == 'doing' || e.status == 'done').length;

    return Scaffold(
      appBar: AppBar(title: const Text('成长档案')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _GrowthStatCard(title: '已学单元', value: '${widget.doneUnits.length}/39'),
              _GrowthStatCard(title: '已保存行动', value: '${widget.actions.length}'),
              _GrowthStatCard(title: '完成复盘', value: '${widget.reviews.length}'),
              _GrowthStatCard(title: '再次上场次数', value: '$retryCount'),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('本模块里你最常接触的主题', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (topTags.isEmpty)
                    const Text('还没有足够数据。先完成几条行动与复盘，这里会逐渐显示你的主题分布。')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: topTags.take(8).map((MapEntry<String, int> e) => _StatPill(label: '${e.key} · ${e.value}')).toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('课程覆盖进度', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _StatPill(label: 'Lecture 14 · ${widget.doneUnits.where((e) => e.startsWith('L14')).length}/6'),
                      _StatPill(label: 'Lecture 15 · ${widget.doneUnits.where((e) => e.startsWith('L15')).length}/23'),
                      _StatPill(label: 'Lecture 16 · ${widget.doneUnits.where((e) => e.startsWith('L16')).length}/10'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('把 39 单元真正活出来，不只在于“看过多少”，还在于有没有把每段的概念变成现实动作、复盘和再次上场。', style: const TextStyle(height: 1.55, color: Color(0xFF374151))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('全文接入状态', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _StatPill(label: '已接入全文 · ${happinessUnits.length}/${happinessUnits.length}'),
                      _StatPill(label: '当前已学 · ${widget.doneUnits.length}/${happinessUnits.length}'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('39 段课程全文已经全部接入模块学习系统；后续仍应继续做逐字校对与逐单元加厚，确保页面呈现与训练逻辑都完全贴合课程原内容。', style: TextStyle(height: 1.55, color: Color(0xFF374151))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(child: Text('经验归纳', style: TextStyle(fontWeight: FontWeight.w800))),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: _historyLoading ? null : _generateAiHistory,
                            icon: _historyLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                            label: const Text('AI 归纳'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _nextActionLoading ? null : _generateAiNextAction,
                            icon: _nextActionLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.route_outlined),
                            label: const Text('AI 推荐动作'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(_historyText, style: const TextStyle(height: 1.65)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_aiRecommendedAction != null) ...<Widget>[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('AI 推荐动作', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text(_aiRecommendedAction!.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(_aiRecommendedAction!.body, style: const TextStyle(height: 1.55)),
                    const SizedBox(height: 8),
                    ..._aiRecommendedAction!.steps.take(4).toList().asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${entry.key + 1}. ${entry.value}', style: const TextStyle(height: 1.45, color: Color(0xFF374151))),
                    )),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () async {
                        await widget.onSaveAction(_aiRecommendedAction!);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存 AI 推荐动作')));
                      },
                      icon: const Icon(Icons.add_task),
                      label: const Text('保存 AI 推荐动作'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Builder(builder: (context) {
            final rec = _nextActionRecommendation(widget.actions, widget.reviews);
            final draft = _recommendedActionDraft(rec);
            if (rec == null || draft == null) return const SizedBox.shrink();
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('下一轮动作建议', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text(rec['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(rec['subtitle'] ?? '', style: const TextStyle(height: 1.55)),
                    const SizedBox(height: 8),
                    Text('推荐动作：${draft.title}', style: const TextStyle(height: 1.55, color: Color(0xFF374151))),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () async {
                        await widget.onSaveAction(draft);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存到行动中心')));
                      },
                      icon: const Icon(Icons.recommend_outlined),
                      label: const Text('保存推荐动作'),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('最近变化提示', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(_growthNarrative(actions: widget.actions, reviews: widget.reviews), style: const TextStyle(height: 1.65)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HappinessActionDetailPage extends StatefulWidget {
  final HappinessAction action;
  final HappinessUnit? unit;
  final Future<void> Function(HappinessAction action) onSaveAction;
  final Future<void> Function()? onOpenReview;
  const HappinessActionDetailPage({super.key, required this.action, required this.unit, required this.onSaveAction, this.onOpenReview});

  @override
  State<HappinessActionDetailPage> createState() => _HappinessActionDetailPageState();
}

class _HappinessActionDetailPageState extends State<HappinessActionDetailPage> {
  late HappinessAction _action;
  late final TextEditingController _factCtrl;
  late final TextEditingController _planCtrl;
  late final TextEditingController _obstacleCtrl;
  late final TextEditingController _nextStepCtrl;
  late List<bool> _stepMarks;

  @override
  void initState() {
    super.initState();
    _action = widget.action;
    _factCtrl = TextEditingController(text: widget.action.factLog);
    _planCtrl = TextEditingController(text: widget.action.planNote);
    _obstacleCtrl = TextEditingController(text: widget.action.obstacleNote);
    _nextStepCtrl = TextEditingController(text: widget.action.nextStepNote);
    _stepMarks = widget.action.stepMarks.isNotEmpty
        ? List<bool>.from(widget.action.stepMarks)
        : List<bool>.filled(widget.action.steps.length, false);
  }

  @override
  void dispose() {
    _factCtrl.dispose();
    _planCtrl.dispose();
    _obstacleCtrl.dispose();
    _nextStepCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveStatus(String status) async {
    _action = _action.copyWith(
      status: status,
      factLog: _factCtrl.text.trim(),
      planNote: _planCtrl.text.trim(),
      obstacleNote: _obstacleCtrl.text.trim(),
      nextStepNote: _nextStepCtrl.text.trim(),
      stepMarks: _stepMarks,
    );
    await widget.onSaveAction(_action);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _savePhase(String message) async {
    _action = _action.copyWith(
      factLog: _factCtrl.text.trim(),
      planNote: _planCtrl.text.trim(),
      obstacleNote: _obstacleCtrl.text.trim(),
      nextStepNote: _nextStepCtrl.text.trim(),
      stepMarks: _stepMarks,
    );
    await widget.onSaveAction(_action);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('行动详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_action.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                  const SizedBox(height: 8),
                  Text('来源：${_action.source} · 当前状态：${_statusLabel(_action.status)}', style: const TextStyle(color: Color(0xFF6B7280))),
                  const SizedBox(height: 12),
                  Text(_action.body, style: const TextStyle(height: 1.65)),
                  if (_action.steps.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    const Text('具体执行步骤', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ..._action.steps.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${entry.key + 1}. ${entry.value}', style: const TextStyle(height: 1.55)),
                    )),
                  ],
                  const SizedBox(height: 12),
                  Text('成功标准：${_action.successCriteria}', style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 6),
                  Text('失败替代动作：${_action.fallbackAction}', style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 6),
                  Text('复盘问题：${_action.reviewQuestion}', style: const TextStyle(height: 1.5)),
                  if (_action.realityVersion.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text('现实映射：${_action.realityRole.isEmpty ? '' : '[${_action.realityRole}] '}${_action.realityVersion}', style: const TextStyle(height: 1.5, color: Color(0xFF6B7280))),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('本次执行提醒', style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text('开始前先看：${_action.planNote.isEmpty ? '先完成第一步，不追求一步做到位。' : _action.planNote}', style: const TextStyle(height: 1.5)),
                        const SizedBox(height: 4),
                        Text('最可能卡住：${_action.obstacleNote.isEmpty ? '如果卡住，就缩回最小一步。' : _action.obstacleNote}', style: const TextStyle(height: 1.5, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_action.steps.isNotEmpty)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('执行清单', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ..._action.steps.asMap().entries.map((entry) => CheckboxListTile(
                      value: entry.key < _stepMarks.length ? _stepMarks[entry.key] : false,
                      onChanged: (v) async {
                        setState(() {
                          if (entry.key >= _stepMarks.length) {
                            _stepMarks = List<bool>.filled(_action.steps.length, false);
                          }
                          _stepMarks[entry.key] = v ?? false;
                        });
                        await _savePhase('已保存执行清单');
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(entry.value, style: const TextStyle(height: 1.45)),
                    )),
                    Text('已完成步骤：${_stepMarks.where((e) => e).length}/${_action.steps.length}', style: const TextStyle(color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('状态推进', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ChoiceChip(label: const Text('待开始'), selected: _action.status == 'todo', onSelected: (_) => _saveStatus('todo')),
                      ChoiceChip(label: const Text('进行中'), selected: _action.status == 'doing', onSelected: (_) => _saveStatus('doing')),
                      ChoiceChip(label: const Text('已完成'), selected: _action.status == 'done', onSelected: (_) => _saveStatus('done')),
                      ChoiceChip(label: const Text('回避/跳过'), selected: _action.status == 'skipped', onSelected: (_) => _saveStatus('skipped')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('行动前：计划与触发点', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _planCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: '我准备在什么具体情境里做这条行动？',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _obstacleCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: '我最可能在哪一步卡住？如果卡住，最小替代动作是什么？',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => _savePhase('已保存行动前计划'), child: const Text('保存行动前计划')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('行动中：事实记录', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _factCtrl,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: '今天真实发生了什么？你做了什么？结果怎样？尽量写事实，不急着评价。',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton(onPressed: () => _savePhase('已保存事实记录'), child: const Text('保存事实记录')),
                      if (widget.onOpenReview != null) OutlinedButton(onPressed: widget.onOpenReview, child: const Text('去复盘')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('行动后：下一步闭环', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nextStepCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: '下一次我愿意更具体地怎么做？',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => _savePhase('已保存下一步'), child: const Text('保存下一步')),
                ],
              ),
            ),
          ),
          if (widget.unit != null) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ListTile(
                title: const Text('对应课程单元', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${widget.unit!.id} ${widget.unit!.title}\n${widget.unit!.oneLiner}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HappinessSceneDetailPage extends StatelessWidget {
  final String sceneName;
  final List<HappinessUnit> units;
  final Future<void> Function(HappinessUnit unit) onOpenUnit;
  final Future<void> Function(HappinessUnit unit) onStartMission;
  const HappinessSceneDetailPage({super.key, required this.sceneName, required this.units, required this.onOpenUnit, required this.onStartMission});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(sceneName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: <Color>[Color(0xFF111827), Color(0xFF374151)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(sceneName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                const SizedBox(height: 8),
                Text(_sceneIntro(sceneName), style: const TextStyle(color: Colors.white70, height: 1.55)),
                const SizedBox(height: 10),
                Text('这一场景适合练：${units.expand((HappinessUnit e) => e.concepts).toSet().take(6).join('、')}', style: const TextStyle(color: Colors.white70, height: 1.55)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (units.isNotEmpty)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('训练链总览', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ..._sceneChainStepsFor(units.first).asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${entry.key + 1}. ${entry.value}', style: const TextStyle(height: 1.55)),
                    )),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text('场景任务', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...units.map((HappinessUnit unit) => _SceneTaskCard(unit: unit, onOpenUnit: onOpenUnit, onStartMission: onStartMission)),
        ],
      ),
    );
  }
}


List<String> _sceneChainStepsFor(HappinessUnit unit) {
  final raw = _sceneChainFor(unit);
  final parts = raw.split('；').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (parts.isNotEmpty) return parts;
  return <String>[raw];
}

class HappinessSceneMissionPlayPage extends StatefulWidget {
  final HappinessUnit unit;
  final Map<String, String> promptOverrides;
  final Future<void> Function(HappinessAction action) onSaveAction;
  const HappinessSceneMissionPlayPage({super.key, required this.unit, required this.promptOverrides, required this.onSaveAction});

  @override
  State<HappinessSceneMissionPlayPage> createState() => _HappinessSceneMissionPlayPageState();
}

class _HappinessSceneMissionPlayPageState extends State<HappinessSceneMissionPlayPage> {
  int _step = 0;
  String? _resultText;
  bool _healthyPath = false;
  final TextEditingController _realVersionCtrl = TextEditingController();
  String _role = '职场';

  @override
  void dispose() {
    _realVersionCtrl.dispose();
    super.dispose();
  }

  List<_MissionChoice> get _choices => _missionChoices(widget.unit);

  void _choose(_MissionChoice choice) {
    setState(() {
      _step = 1;
      _healthyPath = choice.healthy;
      _resultText = choice.feedback;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String mapped = _realVersionCtrl.text.trim();
    final String scenarioText = _missionScenario(widget.unit, role: _role, realVersion: mapped);
    final HappinessAction missionAction = HappinessAction(
      id: 'scene_${widget.unit.id}_${DateTime.now().millisecondsSinceEpoch}',
      unitId: widget.unit.id,
      unitTitle: widget.unit.title,
      source: 'scene_transfer',
      title: widget.unit.defaultActionTitle,
      body: mapped.isEmpty ? '把场景里练过的新路径搬回今天的现实版本。' : '把场景里练过的新路径搬回这个现实版本：[$_role] $mapped',
      steps: <String>[
        '先把现实情境写成一句具体事件：${mapped.isEmpty ? widget.unit.oneLiner : mapped}',
        '写下你在这个情境里最自动的旧反应：${behaviorSpecFor(widget.unit).oldPattern}',
        '从场景里挑一条更健康路径，翻译成今天能完成的一步现实动作。',
        '在今天就执行这一步，不等完全不紧张才开始。',
        '做完后记录事实：我做了什么，对方或现实怎么回应，我接下来怎么继续。',
      ],
      difficulty: 'Easy',
      duration: '10-20分钟',
      successCriteria: '把虚拟场景里学到的东西转成一次现实动作。',
      fallbackAction: '如果现实一步太大，就先做 5 分钟版本。',
      reviewQuestion: widget.unit.reflectionQuestion,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      realityRole: _role,
      realityVersion: mapped,
      planNote: '场景原型：${widget.unit.scene}；现实进入点：${mapped.isEmpty ? widget.unit.oneLiner : mapped}',
      obstacleNote: behaviorSpecFor(widget.unit).oldPattern,
      nextStepNote: _missionRecovery(widget.unit, _healthyPath),
      stepMarks: List<bool>.filled(5, false),
    );

    return Scaffold(
      appBar: AppBar(title: Text('${widget.unit.scene} · 任务')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('先把场景换成你的现实版本', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <String>['学生', '职场', '关系', '家庭', '个人成长'].map((String e) => ChoiceChip(label: Text(e), selected: _role == e, onSelected: (_) => setState(() => _role = e))).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _realVersionCtrl,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '例如：下周要做部门汇报，我一想到会被领导追问就开始反复改稿，不敢定稿。',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(widget.unit.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                  const SizedBox(height: 8),
                  Text(scenarioText, style: const TextStyle(height: 1.65)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('当前训练链：${_sceneChainFor(widget.unit)}', style: const TextStyle(height: 1.6)),
            ),
          ),
          const SizedBox(height: 12),
          if (_step == 0) ...<Widget>[
            const Text('你现在会怎么做？', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ..._choices.map((_MissionChoice choice) => Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: ListTile(
                    title: Text(choice.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(choice.subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _choose(choice),
                  ),
                )),
          ] else ...<Widget>[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(_healthyPath ? '这条路径更接近课程思路' : '这是常见旧路径，但也是训练素材', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(_resultText ?? '', style: const TextStyle(height: 1.6)),
                    const SizedBox(height: 10),
                    Text('恢复提示：${_missionRecovery(widget.unit, _healthyPath)}', style: const TextStyle(color: Color(0xFF6B7280), height: 1.5)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('迁移到现实', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('这次训练要迁移的不是抽象感受，而是：${_trainingFocusFor(widget.unit).take(2).join('；')}', style: const TextStyle(height: 1.55, color: Color(0xFF374151))),
                    const SizedBox(height: 10),
                    const SizedBox(height: 8),
                    Text('现在把虚拟场景里学到的东西带回现实，执行这一步：${widget.unit.defaultActionTitle}', style: const TextStyle(height: 1.6)),
                    const SizedBox(height: 8),
                    if (mapped.isNotEmpty) Text('现实映射：[$_role] $mapped', style: const TextStyle(color: Color(0xFF6B7280), height: 1.5)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('迁移清单', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          ...missionAction.steps.asMap().entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('${entry.key + 1}. ${entry.value}', style: const TextStyle(height: 1.5)),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: () async {
                            await widget.onSaveAction(missionAction);
                            if (mounted) Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.add_task),
                          label: const Text('保存为现实行动'),
                        ),
                        OutlinedButton(
                          onPressed: () => setState(() {
                            _step = 0;
                            _resultText = null;
                          }),
                          child: const Text('重新选择路径'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SceneTaskCard extends StatelessWidget {
  final HappinessUnit unit;
  final Future<void> Function(HappinessUnit unit) onOpenUnit;
  final Future<void> Function(HappinessUnit unit) onStartMission;
  const _SceneTaskCard({required this.unit, required this.onOpenUnit, required this.onStartMission});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${unit.id} ${unit.title}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            Text(_sceneMission(unit), style: const TextStyle(height: 1.55)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(onPressed: () => onStartMission(unit), icon: const Icon(Icons.vrpano_outlined), label: const Text('开始模拟训练')),
                OutlinedButton.icon(onPressed: () => onOpenUnit(unit), icon: const Icon(Icons.menu_book_outlined), label: const Text('查看课程单元')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ModuleCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
