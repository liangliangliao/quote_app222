import 'dart:math';

import 'package:flutter/material.dart';

import '../pages/settings_page.dart';
import 'stress_ai_service.dart';
import 'stress_dao.dart';
import 'stress_models.dart';
import 'stress_seed.dart';

class StressModuleHomePage extends StatefulWidget {
  const StressModuleHomePage({super.key});

  @override
  State<StressModuleHomePage> createState() => _StressModuleHomePageState();
}

class _StressModuleHomePageState extends State<StressModuleHomePage> {
  final StressDao _dao = StressDao();
  final StressAiService _ai = StressAiService();

  int _idx = 0;
  bool _loading = true;
  List<StressAction> _actions = <StressAction>[];
  List<StressReviewEntry> _reviews = <StressReviewEntry>[];
  List<StressSceneSession> _sceneSessions = <StressSceneSession>[];
  Set<String> _doneUnits = <String>{};
  Map<String, String> _aiState = const <String, String>{'label': '读取中…'};
  StressInsightResult? _latestInsight;
  StressGrowthReport? _latestGrowthReport;
  StressWeeklyReport? _latestWeeklyReport;
  StressMonthlyReport? _latestMonthlyReport;
  StressProblemRoute? _latestProblemRoute;
  StressPersonaProfile? _persona;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final actions = await _dao.loadActions();
    final reviews = await _dao.loadReviews();
    final done = await _dao.loadCompletedUnits();
    final aiState = await _ai.getGlobalAiState();
    final latestInsight = await _dao.loadLatestInsight();
    final latestGrowthReport = await _dao.loadLatestGrowthReport();
    final latestWeeklyReport = await _dao.loadLatestWeeklyReport();
    final latestMonthlyReport = await _dao.loadLatestMonthlyReport();
    final persona = await _dao.loadPersona();
    final sceneSessions = await _dao.loadSceneSessions();
    if (!mounted) return;
    setState(() {
      _actions = actions;
      _reviews = reviews;
      _doneUnits = done;
      _aiState = aiState;
      _latestInsight = latestInsight;
      _latestGrowthReport = latestGrowthReport;
      _latestWeeklyReport = latestWeeklyReport;
      _latestMonthlyReport = latestMonthlyReport;
      _persona = persona;
      _sceneSessions = sceneSessions;
      _loading = false;
    });
  }

  StressUnit _findUnit(String id) {
    return stressUnits.firstWhere((e) => e.id == id, orElse: () => stressUnits.first);
  }

  String _id(String prefix) => '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}';

  Future<void> _saveAction(StressAction action) async {
    await _dao.saveAction(action);
    await _dao.markUnitCompleted(action.unitId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入行动实践')));
  }

  Future<void> _updateAction(StressAction action) async {
    await _dao.updateAction(action);
    await _load();
  }

  Future<void> _saveReview(StressReviewEntry review) async {
    await _dao.saveReview(review);
    await _dao.markUnitCompleted(review.unitId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存复盘')));
  }

  Future<void> _savePersona(StressPersonaProfile profile) async {
    await _dao.savePersona(profile);
    if (!mounted) return;
    setState(() => _persona = profile);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已更新镜像角色画像')));
  }

  Future<void> _saveSceneSession(StressSceneSession session) async {
    await _dao.saveSceneSession(session);
    await _dao.markUnitCompleted(session.unitId);
    await _load();
  }

  Future<void> _generateInsight() async {
    final result = await _ai.generateInsight(actions: _actions, reviews: _reviews);
    await _dao.saveLatestInsight(result);
    if (!mounted) return;
    setState(() => _latestInsight = result);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已生成 AI 洞察（${result.modelLabel}）')));
  }

  Future<void> _generateGrowthReport() async {
    final result = await _ai.generateGrowthReport(actions: _actions, reviews: _reviews, sessions: _sceneSessions, persona: _persona);
    await _dao.saveLatestGrowthReport(result);
    if (!mounted) return;
    setState(() => _latestGrowthReport = result);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已生成第三层成长报告（${result.modelLabel}）')));
  }


  Future<void> _generateWeeklyReport() async {
    final result = await _ai.generateWeeklyReport(actions: _actions, reviews: _reviews, sessions: _sceneSessions, persona: _persona);
    await _dao.saveLatestWeeklyReport(result);
    if (!mounted) return;
    setState(() => _latestWeeklyReport = result);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已生成周复盘（${result.modelLabel}）')));
  }

  Future<void> _generateMonthlyReport() async {
    final result = await _ai.generateMonthlyReport(actions: _actions, reviews: _reviews, sessions: _sceneSessions, persona: _persona, growthReport: _latestGrowthReport);
    await _dao.saveLatestMonthlyReport(result);
    if (!mounted) return;
    setState(() => _latestMonthlyReport = result);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已生成月度重点报告（${result.modelLabel}）')));
  }

  Future<void> _mapProblem(String problem) async {
    final result = await _ai.mapProblemToRoute(problem: problem, persona: _persona);
    if (!mounted) return;
    setState(() => _latestProblemRoute = result);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已生成问题映射（${result.modelLabel}）')));
  }

  StressAction _sceneActionFromSession(StressUnit unit, StressSceneSession session) {
    final title = '${unit.defaultActionTitle} · 场景转行动';
    final body = '来自 ${session.sceneName} 的选择：${session.choiceTitle}。\n现实映射：${session.actionHint}';
    final steps = <String>[
      '先执行：${session.actionHint.split('。').first.trim().isEmpty ? unit.defaultActionTitle : session.actionHint.split('。').first.trim()}',
      '执行后写下一条事实：做了什么、持续多久、有没有被打断。',
      '若中断，先做最小恢复动作，再回到 5 分钟版本。',
      '晚上回答：${unit.reflectionQuestion}',
    ];
    return StressAction(
      id: _id('stress_scene_action'),
      unitId: unit.id,
      unitTitle: unit.title,
      source: 'scene:${session.sceneName}',
      title: title,
      body: body,
      difficulty: 'L1-L2',
      duration: '10-20分钟',
      successCriteria: '把场景中的一个策略带回现实，并记录至少一条事实。',
      fallbackAction: '如果今天做不到完整版本，就只执行 5 分钟入口动作。',
      reviewQuestion: unit.reflectionQuestion,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      status: 'todo',
      steps: steps,
      stepMarks: List<bool>.filled(steps.length, false),
    );
  }

  int _unlockedDistrictCount() {
    final completedActions = _actions.where((e) => e.status == 'done' || e.status == 'partial').length;
    final progressScore = _doneUnits.length + completedActions + (_sceneSessions.length ~/ 2);
    return min(stressDistricts.length, max(1, 1 + (progressScore ~/ 5)));
  }

  List<StressUnit> _recommendedUnits() {
    final remaining = stressUnits.where((e) => !_doneUnits.contains(e.id)).toList();
    if (remaining.isEmpty) return stressUnits.take(3).toList();
    final persona = _persona;
    if (persona == null) return remaining.take(3).toList();
    int score(StressUnit unit) {
      var s = 0;
      for (final t in persona.stressTags) {
        if (unit.tags.any((e) => e.contains(t.replaceAll('焦虑', '')) || t.contains(e))) s += 4;
        if (unit.title.contains(t) || unit.summary.contains(t)) s += 4;
        if (unit.concepts.any((e) => e.contains(t.replaceAll('焦虑', '')) || t.contains(e))) s += 3;
      }
      if (unit.whatText.contains(persona.currentFocus) || unit.whyText.contains(persona.currentFocus)) s += 3;
      if (persona.currentFocus.contains('恢复') && unit.tags.contains('恢复')) s += 4;
      if (persona.currentFocus.contains('专注') && (unit.tags.contains('专注') || unit.title.contains('多任务'))) s += 4;
      if (persona.currentFocus.contains('拖延') && unit.tags.contains('拖延')) s += 4;
      if (persona.currentFocus.contains('边界') && (unit.tags.contains('边界') || unit.title.contains('说“不”'))) s += 4;
      return s;
    }

    remaining.sort((a, b) {
      final c = score(b).compareTo(score(a));
      if (c != 0) return c;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return remaining.take(4).toList();
  }

  StressUnit _pickTodayUnit() {
    final rec = _recommendedUnits();
    if (rec.isNotEmpty) return rec.first;
    return stressUnits[(DateTime.now().day - 1) % stressUnits.length];
  }

  Future<void> _openPersonaSetup() async {
    final profile = await Navigator.of(context).push<StressPersonaProfile>(
      MaterialPageRoute(builder: (_) => StressPersonaSetupPage(initial: _persona)),
    );
    if (profile != null) {
      await _savePersona(profile);
    }
  }

  Future<void> _openUnit(StressUnit unit) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StressUnitDetailPage(
          unit: unit,
          aiState: _aiState,
          persona: _persona,
          onOpenActionAi: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StressAiActionPage(unit: unit, ai: _ai, onSaveAction: _saveAction),
              ),
            );
          },
          onOpenScene: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StressScenePlayPage(
                  unit: unit,
                  persona: _persona,
                  onSaveScene: _saveSceneSession,
                  onCreateAction: (StressSceneSession session) async {
                    await _saveAction(_sceneActionFromSession(unit, session));
                  },
                ),
              ),
            );
          },
          onOpenReview: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StressReviewPage(unit: unit, ai: _ai, onSave: _saveReview),
              ),
            );
          },
        ),
      ),
    );
    await _load();
  }

  Future<void> _openAction(StressAction action) async {
    final unit = _findUnit(action.unitId);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StressActionDetailPage(
          action: action,
          unit: unit,
          onSaveAction: _updateAction,
          onOpenReview: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => StressReviewPage(unit: unit, ai: _ai, onSave: _saveReview)));
          },
        ),
      ),
    );
    await _load();
  }

  Future<void> _openScene(String sceneName) async {
    final ids = stressScenes[sceneName] ?? <String>[];
    final units = stressUnits.where((e) => ids.contains(e.id)).toList();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StressSceneDetailPage(
          sceneName: sceneName,
          units: units,
          persona: _persona,
          sessions: _sceneSessions.where((e) => e.sceneName == sceneName).toList(),
          onOpenUnit: _openUnit,
          onStartPlay: (StressUnit unit) async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StressScenePlayPage(
                  unit: unit,
                  persona: _persona,
                  onSaveScene: _saveSceneSession,
                  onCreateAction: (StressSceneSession session) async {
                    await _saveAction(_sceneActionFromSession(unit, session));
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
    await _load();
  }

  Future<void> _openDistrict(Map<String, dynamic> district) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StressDistrictDetailPage(
          district: district,
          sceneSessions: _sceneSessions,
          onOpenScene: _openScene,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final todayUnit = _pickTodayUnit();
    final unlockedDistricts = _unlockedDistrictCount();
    final pages = <Widget>[
      _StressOverviewPage(
        aiState: _aiState,
        doneUnits: _doneUnits.length,
        totalUnits: stressUnits.length,
        doneActions: _actions.where((e) => e.status == 'done').length,
        totalActions: _actions.length,
        reviewCount: _reviews.length,
        sceneCount: _sceneSessions.length,
        unlockedDistricts: unlockedDistricts,
        totalDistricts: stressDistricts.length,
        todayUnit: todayUnit,
        latestInsight: _latestInsight,
        latestWeeklyReport: _latestWeeklyReport,
        latestMonthlyReport: _latestMonthlyReport,
        persona: _persona,
        recommendedUnits: _recommendedUnits(),
        onOpenUnit: _openUnit,
        onOpenSettings: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
        onOpenPersona: _openPersonaSetup,
        onGoCourse: () => setState(() => _idx = 1),
        onGoWorld: () => setState(() => _idx = 2),
        onGoAction: () => setState(() => _idx = 3),
        onGoInsight: () => setState(() => _idx = 4),
        onGenerateWeekly: _generateWeeklyReport,
        onGenerateMonthly: _generateMonthlyReport,
        growthReport: _latestGrowthReport,
      ),
      _StressCoursePage(
        doneUnits: _doneUnits,
        persona: _persona,
        latestProblemRoute: _latestProblemRoute,
        onMapProblem: _mapProblem,
        onOpenUnit: _openUnit,
      ),
      _StressWorldPage(
        unlockedDistricts: unlockedDistricts,
        sessions: _sceneSessions,
        onOpenDistrict: _openDistrict,
        onOpenPersona: _openPersonaSetup,
        growthReport: _latestGrowthReport,
      ),
      _StressActionPage(actions: _actions, onOpenAction: _openAction, onOpenUnit: _openUnit),
      _StressInsightPage(
        aiState: _aiState,
        reviews: _reviews,
        latestInsight: _latestInsight,
        latestWeeklyReport: _latestWeeklyReport,
        latestMonthlyReport: _latestMonthlyReport,
        persona: _persona,
        actions: _actions,
        sessions: _sceneSessions,
        onGenerateInsight: _generateInsight,
        onGenerateGrowth: _generateGrowthReport,
        onGenerateWeekly: _generateWeeklyReport,
        onGenerateMonthly: _generateMonthlyReport,
        growthReport: _latestGrowthReport,
        onOpenUnit: _openUnit,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('压力与恢复知行实验室'),
        actions: <Widget>[
          IconButton(
            tooltip: '镜像角色',
            icon: const Icon(Icons.psychology_alt_outlined),
            onPressed: _openPersonaSetup,
          ),
          IconButton(
            tooltip: 'AI 洞察',
            icon: const Icon(Icons.insights_outlined),
            onPressed: _generateInsight,
          ),
          IconButton(
            tooltip: '成长报告',
            icon: const Icon(Icons.timeline_outlined),
            onPressed: _generateGrowthReport,
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: _loading ? const Center(child: CircularProgressIndicator()) : pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (int i) => setState(() => _idx = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '总览'),
          NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'AI学习'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: '知行城'),
          NavigationDestination(icon: Icon(Icons.playlist_add_check_outlined), selectedIcon: Icon(Icons.playlist_add_check), label: '行动实践'),
          NavigationDestination(icon: Icon(Icons.auto_graph_outlined), selectedIcon: Icon(Icons.auto_graph), label: 'AI洞察'),
        ],
      ),
    );
  }
}

class _StressOverviewPage extends StatelessWidget {
  final Map<String, String> aiState;
  final int doneUnits;
  final int totalUnits;
  final int doneActions;
  final int totalActions;
  final int reviewCount;
  final int sceneCount;
  final int unlockedDistricts;
  final int totalDistricts;
  final StressUnit todayUnit;
  final StressInsightResult? latestInsight;
  final StressGrowthReport? growthReport;
  final StressWeeklyReport? latestWeeklyReport;
  final StressMonthlyReport? latestMonthlyReport;
  final StressPersonaProfile? persona;
  final List<StressUnit> recommendedUnits;
  final Future<void> Function(StressUnit unit) onOpenUnit;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenPersona;
  final VoidCallback onGoCourse;
  final VoidCallback onGoWorld;
  final VoidCallback onGoAction;
  final VoidCallback onGoInsight;
  final Future<void> Function() onGenerateWeekly;
  final Future<void> Function() onGenerateMonthly;

  const _StressOverviewPage({
    required this.aiState,
    required this.doneUnits,
    required this.totalUnits,
    required this.doneActions,
    required this.totalActions,
    required this.reviewCount,
    required this.sceneCount,
    required this.unlockedDistricts,
    required this.totalDistricts,
    required this.todayUnit,
    required this.latestInsight,
    required this.growthReport,
    required this.latestWeeklyReport,
    required this.latestMonthlyReport,
    required this.persona,
    required this.recommendedUnits,
    required this.onOpenUnit,
    required this.onOpenSettings,
    required this.onOpenPersona,
    required this.onGoCourse,
    required this.onGoWorld,
    required this.onGoAction,
    required this.onGoInsight,
    required this.onGenerateWeekly,
    required this.onGenerateMonthly,
  });

  @override
  Widget build(BuildContext context) {
    final profile = persona;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('今日导航', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('当前模型：${aiState['label'] ?? '未配置'}', style: const TextStyle(color: Color(0xFF475569))),
              const SizedBox(height: 6),
              Text(aiState['note'] ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _QuickStat(title: '已学单元', value: '$doneUnits/$totalUnits', icon: Icons.school_outlined),
                  _QuickStat(title: '已做行动', value: '$doneActions/$totalActions', icon: Icons.playlist_add_check_outlined),
                  _QuickStat(title: '已复盘', value: '$reviewCount', icon: Icons.insights_outlined),
                  _QuickStat(title: '已模拟', value: '$sceneCount', icon: Icons.videogame_asset_outlined),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(child: Text('镜像角色画像', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  TextButton.icon(onPressed: onOpenPersona, icon: const Icon(Icons.tune), label: Text(profile == null ? '开始画像' : '调整画像')),
                ],
              ),
              const SizedBox(height: 8),
              if (profile == null)
                const Text('先做一个 1 分钟画像，系统会用你的真实压力来源来推荐单元、场景和现实行动。', style: TextStyle(height: 1.5))
              else ...<Widget>[
                Text('${profile.roleLabel} · ${profile.energyStyle}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('当前优先焦点：${profile.currentFocus}', style: const TextStyle(color: Color(0xFF475569))),
                const SizedBox(height: 6),
                Text('支持偏好：${profile.supportStyle}', style: const TextStyle(color: Color(0xFF475569))),
                const SizedBox(height: 6),
                Text('旧回路：${profile.avoidancePattern}', style: const TextStyle(color: Color(0xFF475569))),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: profile.stressTags.map((e) => Chip(label: Text(e), visualDensity: VisualDensity.compact)).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('今日推荐单元', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(todayUnit.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(todayUnit.oneLiner, style: const TextStyle(color: Color(0xFF475569))),
              const SizedBox(height: 10),
              Text(todayUnit.summary, style: const TextStyle(height: 1.5)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: todayUnit.concepts.map((e) => Chip(label: Text(e), visualDensity: VisualDensity.compact)).toList(),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: () => onOpenUnit(todayUnit), icon: const Icon(Icons.play_arrow), label: const Text('进入单元')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Text('第二层已完成，第三层开始：长期成长', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('当前已解锁城区：$unlockedDistricts / $totalDistricts。第二层重点不只是“学懂”，而是开始在镜像人生城里练策略，再把结果转成现实行动。', style: const TextStyle(height: 1.5)),
            const SizedBox(height: 10),
            ...recommendedUnits.take(3).map((unit) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 16, backgroundColor: const Color(0xFFE2E8F0), child: Text('${unit.sortOrder}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  title: Text(unit.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(unit.oneLiner, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpenUnit(unit),
                )),
          ]),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(child: _FeatureCard(title: 'AI学习', subtitle: '20 单元课程母本 + 问题筛选 + 推荐路径', icon: Icons.school_outlined, onTap: onGoCourse)),
            const SizedBox(width: 10),
            Expanded(child: _FeatureCard(title: '行动实践', subtitle: '默认行动 + AI 拆解 + 事实记录', icon: Icons.playlist_add_check_outlined, onTap: onGoAction)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(child: _FeatureCard(title: '知行城', subtitle: '分城区解锁 + 场景模拟 + 转现实行动', icon: Icons.map_outlined, onTap: onGoWorld)),
            const SizedBox(width: 10),
            Expanded(child: _FeatureCard(title: 'AI洞察', subtitle: '从行动、场景与复盘里看重复模式', icon: Icons.auto_graph_outlined, onTap: onGoInsight)),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Text('第四层推进：周报 / 月报 / 长期推荐', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(latestWeeklyReport?.headline ?? '还没有周复盘。建议先生成一次，系统会把最近的行动、场景和复盘串成一条周线。', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45)),
            if ((latestWeeklyReport?.summary ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(latestWeeklyReport!.summary, style: const TextStyle(height: 1.5)),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: <Widget>[
              FilledButton.icon(onPressed: onGenerateWeekly, icon: const Icon(Icons.calendar_view_week_outlined), label: const Text('生成周复盘')),
              OutlinedButton.icon(onPressed: onGenerateMonthly, icon: const Icon(Icons.calendar_month_outlined), label: const Text('生成月度重点')),
              TextButton.icon(onPressed: onGoInsight, icon: const Icon(Icons.auto_graph), label: const Text('查看完整洞察')),
            ]),
            if (latestMonthlyReport != null) ...<Widget>[
              const SizedBox(height: 10),
              Text('月度重点：${latestMonthlyReport!.nextMonthFocus}', style: const TextStyle(color: Color(0xFF475569), height: 1.45)),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Text('第三层推进：长期成长与个性化剧情', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(growthReport?.storyTitle ?? '还没有第三层成长报告。你可以先生成一份，看看自己当前处在哪条成长剧情线上。', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45)),
            if ((growthReport?.storyBody ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(growthReport!.storyBody, style: const TextStyle(height: 1.5)),
            ],
            const SizedBox(height: 10),
            _GrowthCurveCard(points: growthReport?.curve ?? buildStressGrowthCurve(actions: const <StressAction>[], reviews: const <StressReviewEntry>[], sessions: const <StressSceneSession>[])),
            const SizedBox(height: 10),
            Text('本月重点：${growthReport?.monthFocus ?? '先完成一次“模拟 → 现实行动 → 复盘”的完整闭环。'}', style: const TextStyle(color: Color(0xFF475569), height: 1.45)),
          ]),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('最新 AI 洞察', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(latestInsight?.summary ?? '还没有 AI 洞察。先完成一条行动与一次复盘，系统会更容易识别你的真实模式。', style: const TextStyle(height: 1.5)),
              if (latestInsight != null && latestInsight!.patterns.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                ...latestInsight!.patterns.take(3).map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(Icons.circle, size: 8, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e, style: const TextStyle(height: 1.45))),
                        ],
                      ),
                    )),
              ],
              const SizedBox(height: 8),
              TextButton.icon(onPressed: onOpenSettings, icon: const Icon(Icons.tune), label: const Text('查看模型 / 设置')),
            ],
          ),
        ),
      ],
    );
  }
}

class _StressCoursePage extends StatefulWidget {
  final Set<String> doneUnits;
  final StressPersonaProfile? persona;
  final StressProblemRoute? latestProblemRoute;
  final Future<void> Function(String problem) onMapProblem;
  final Future<void> Function(StressUnit unit) onOpenUnit;

  const _StressCoursePage({required this.doneUnits, required this.persona, required this.latestProblemRoute, required this.onMapProblem, required this.onOpenUnit});

  @override
  State<_StressCoursePage> createState() => _StressCoursePageState();
}

class _StressCoursePageState extends State<_StressCoursePage> {
  String _selectedTag = '全部';

  List<String> get _allTags {
    final set = <String>{'全部'};
    for (final unit in stressUnits) {
      set.addAll(unit.tags);
    }
    final persona = widget.persona;
    if (persona != null) set.addAll(persona.stressTags);
    return set.toList();
  }

  List<StressUnit> get _units {
    Iterable<StressUnit> items = stressUnits;
    if (_selectedTag != '全部') {
      items = items.where((e) => e.tags.contains(_selectedTag) || e.title.contains(_selectedTag) || e.summary.contains(_selectedTag) || e.concepts.any((c) => c.contains(_selectedTag)));
    }
    return items.toList();
  }

  List<StressUnit> get _recommended {
    final persona = widget.persona;
    if (persona == null) return stressUnits.take(3).toList();
    final rest = stressUnits.where((e) => !widget.doneUnits.contains(e.id)).toList();
    rest.sort((a, b) {
      int score(StressUnit u) {
        var s = 0;
        for (final t in persona.stressTags) {
          if (u.title.contains(t) || u.summary.contains(t) || u.concepts.any((e) => e.contains(t)) || u.tags.any((e) => t.contains(e) || e.contains(t))) s += 4;
        }
        if (u.whatText.contains(persona.currentFocus) || u.whyText.contains(persona.currentFocus)) s += 3;
        return s;
      }

      final c = score(b).compareTo(score(a));
      if (c != 0) return c;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return rest.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final units = _units;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (widget.persona != null) ...<Widget>[
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const Text('问题驱动推荐路径', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('基于你的镜像角色「${widget.persona!.roleLabel}」和当前焦点「${widget.persona!.currentFocus}」，优先建议先学下面这些单元。', style: const TextStyle(height: 1.5)),
              const SizedBox(height: 10),
              ..._recommended.map((unit) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.subdirectory_arrow_right),
                    title: Text(unit.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(unit.oneLiner, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => widget.onOpenUnit(unit),
                  )),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        _SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Text('第四层问题映射引擎', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('先说“你现在卡在哪里”，系统再把问题映射到最相关的课程单元。', style: TextStyle(height: 1.5)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const <String>['总觉得事情太多', '休息了也恢复不了', '总被消息打断', '开始不了一直拖延', '不会拒绝别人', '总觉得没有时间']
                  .map((problem) => Chip(label: Text(problem), visualDensity: VisualDensity.compact))
                  .toList(),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final buttons = <Widget>[];
            for (final problem in const <String>['总觉得事情太多', '休息了也恢复不了', '总被消息打断', '开始不了一直拖延', '不会拒绝别人', '总觉得没有时间']) {
              buttons.add(Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: FilledButton.tonal(
                  onPressed: () => widget.onMapProblem(problem),
                  child: Text(problem),
                ),
              ));
            }
            return Wrap(children: buttons);
          },
        ),
        if (widget.latestProblemRoute != null) ...<Widget>[
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text('问题映射：${widget.latestProblemRoute!.problem}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(widget.latestProblemRoute!.summary, style: const TextStyle(height: 1.5)),
              const SizedBox(height: 10),
              ...widget.latestProblemRoute!.recommendedUnitIds.take(3).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final unitId = entry.value;
                final unit = stressUnits.firstWhere((e) => e.id == unitId, orElse: () => stressUnits.first);
                final reason = i < widget.latestProblemRoute!.reasons.length ? widget.latestProblemRoute!.reasons[i] : '先从这一段开始。';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 15, backgroundColor: const Color(0xFFE2E8F0), child: Text('${unit.sortOrder}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  title: Text(unit.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(reason, maxLines: 3, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => widget.onOpenUnit(unit),
                );
              }),
              const SizedBox(height: 8),
              Text('快速起步：${widget.latestProblemRoute!.quickStart}', style: const TextStyle(color: Color(0xFF475569), height: 1.45)),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        const Text('按问题筛选', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _allTags
                .map((tag) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(tag),
                        selected: _selectedTag == tag,
                        onSelected: (_) => setState(() => _selectedTag = tag),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        ...units.map((unit) {
          final index = stressUnits.indexOf(unit);
          final done = widget.doneUnits.contains(unit.id);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: done ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
                child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ),
              title: Text(unit.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Text('${unit.oneLiner}\n${unit.summary}', maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: unit.tags.take(3).map((e) => Chip(label: Text(e), visualDensity: VisualDensity.compact)).toList(),
                  ),
                ]),
              ),
              trailing: done ? const Icon(Icons.check_circle, color: Color(0xFF16A34A)) : const Icon(Icons.chevron_right),
              onTap: () => widget.onOpenUnit(unit),
            ),
          );
        }),
      ],
    );
  }
}

class _StressWorldPage extends StatelessWidget {
  final int unlockedDistricts;
  final List<StressSceneSession> sessions;
  final StressGrowthReport? growthReport;
  final Future<void> Function(Map<String, dynamic> district) onOpenDistrict;
  final VoidCallback onOpenPersona;

  const _StressWorldPage({required this.unlockedDistricts, required this.sessions, required this.onOpenDistrict, required this.onOpenPersona, required this.growthReport});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Text('知行城第二层：分城区推进', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('你已解锁 $unlockedDistricts / ${stressDistricts.length} 个城区。每个城区先在虚拟世界里练策略，再把结果转成现实任务。', style: const TextStyle(height: 1.5)),
            const SizedBox(height: 8),
            TextButton.icon(onPressed: onOpenPersona, icon: const Icon(Icons.psychology_alt_outlined), label: const Text('调整镜像角色画像')),
          ]),
        ),
        const SizedBox(height: 12),
        if (growthReport != null) ...<Widget>[
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const Text('当前剧情主线', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(growthReport!.storyTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(growthReport!.nextQuest, style: const TextStyle(height: 1.5)),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        ...List<Widget>.generate(stressDistricts.length, (int index) {
          final district = stressDistricts[index];
          final unlocked = index < unlockedDistricts;
          final sceneNames = (district['scenes'] as List).cast<String>();
          final played = sessions.where((e) => sceneNames.contains(e.sceneName)).length;
          return Opacity(
            opacity: unlocked ? 1 : 0.55,
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: unlocked ? const Color(0xFFE0F2FE) : const Color(0xFFE5E7EB),
                  child: Icon(unlocked ? Icons.map_outlined : Icons.lock_outline, color: const Color(0xFF0F172A)),
                ),
                title: Text('${district['name']}'),
                subtitle: Text('${district['subtitle']}\n场景数：${sceneNames.length} · 已模拟：$played'),
                trailing: const Icon(Icons.chevron_right),
                onTap: unlocked ? () => onOpenDistrict(district) : null,
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _StressActionPage extends StatelessWidget {
  final List<StressAction> actions;
  final Future<void> Function(StressAction action) onOpenAction;
  final Future<void> Function(StressUnit unit) onOpenUnit;

  const _StressActionPage({required this.actions, required this.onOpenAction, required this.onOpenUnit});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.playlist_add_check_outlined, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              const Text('还没有行动实践', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('第二层功能已经支持“从知行城模拟结果一键转成现实行动”。你也可以先进入任一课程单元，点击“AI 拆解行动”。', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => onOpenUnit(stressUnits.first), child: const Text('从第一单元开始')),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        Color color = const Color(0xFF64748B);
        if (action.status == 'done') {
          color = const Color(0xFF16A34A);
        } else if (action.status == 'doing') {
          color = const Color(0xFF2563EB);
        } else if (action.status == 'partial') {
          color = const Color(0xFFF59E0B);
        } else if (action.status == 'failed') {
          color = const Color(0xFFDC2626);
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(Icons.flag_outlined, color: color)),
            title: Text(action.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('${action.unitTitle}\n状态：${action.status} · ${action.duration}\n来源：${action.source}', maxLines: 3, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onOpenAction(action),
          ),
        );
      },
    );
  }
}

class _StressInsightPage extends StatelessWidget {
  final Map<String, String> aiState;
  final List<StressReviewEntry> reviews;
  final StressInsightResult? latestInsight;
  final StressWeeklyReport? latestWeeklyReport;
  final StressMonthlyReport? latestMonthlyReport;
  final StressGrowthReport? growthReport;
  final StressPersonaProfile? persona;
  final List<StressAction> actions;
  final List<StressSceneSession> sessions;
  final Future<void> Function() onGenerateInsight;
  final Future<void> Function() onGenerateWeekly;
  final Future<void> Function() onGenerateMonthly;
  final Future<void> Function() onGenerateGrowth;
  final Future<void> Function(StressUnit unit) onOpenUnit;

  const _StressInsightPage({
    required this.aiState,
    required this.reviews,
    required this.latestInsight,
    required this.latestWeeklyReport,
    required this.latestMonthlyReport,
    required this.growthReport,
    required this.persona,
    required this.actions,
    required this.sessions,
    required this.onGenerateInsight,
    required this.onGenerateWeekly,
    required this.onGenerateMonthly,
    required this.onGenerateGrowth,
    required this.onOpenUnit,
  });

  @override
  Widget build(BuildContext context) {
    final latestScene = sessions.isNotEmpty ? sessions.first : null;
    final latestReview = reviews.isNotEmpty ? reviews.first : null;
    final recommendedUnitId = latestWeeklyReport?.recommendedUnitId ?? latestMonthlyReport?.recommendedUnitId ?? latestScene?.unitId ?? 'S01';
    final focusUnit = stressUnits.firstWhere((e) => e.id == recommendedUnitId, orElse: () => stressUnits.first);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Text('AI 洞察与长期复盘中心', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('当前模型：${aiState['label'] ?? '未配置'}', style: const TextStyle(color: Color(0xFF475569))),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: <Widget>[
              FilledButton.icon(onPressed: onGenerateInsight, icon: const Icon(Icons.auto_awesome), label: const Text('重新生成洞察')),
              FilledButton.icon(onPressed: onGenerateWeekly, icon: const Icon(Icons.calendar_view_week_outlined), label: const Text('生成周复盘')),
              OutlinedButton.icon(onPressed: onGenerateMonthly, icon: const Icon(Icons.calendar_month_outlined), label: const Text('生成月重点')),
              OutlinedButton.icon(onPressed: onGenerateGrowth, icon: const Icon(Icons.timeline_outlined), label: const Text('生成成长报告')),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Text('今日洞察', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(latestInsight?.summary ?? '还没有 AI 洞察。先完成一条行动与一次复盘，系统会更容易识别你的真实模式。', style: const TextStyle(height: 1.5)),
            const SizedBox(height: 10),
            Text('当前最值得优先处理的一点：${latestInsight?.nextFocus ?? '先完成一次“场景模拟 → 现实行动 → 事实记录”的完整闭环。'}', style: const TextStyle(height: 1.45)),
            const SizedBox(height: 6),
            Text('今日微行动：${latestInsight?.todayAction ?? '把一条现有行动缩小到 5~10 分钟版本。'}', style: const TextStyle(color: Color(0xFF475569), height: 1.45)),
            if (latestInsight != null && latestInsight!.patterns.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              ...latestInsight!.patterns.take(3).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('• $e', style: const TextStyle(height: 1.45)),
                  )),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Text('第四层周复盘', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(latestWeeklyReport?.headline ?? '还没有周复盘。建议先生成一次，让系统把这周的行动、场景和复盘串起来。', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45)),
            if ((latestWeeklyReport?.summary ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(latestWeeklyReport!.summary, style: const TextStyle(height: 1.5)),
            ],
            if (latestWeeklyReport != null) ...<Widget>[
              const SizedBox(height: 10),
              if (latestWeeklyReport!.wins.isNotEmpty) Text('本周做对了：${latestWeeklyReport!.wins.join('；')}', style: const TextStyle(height: 1.45)),
              const SizedBox(height: 6),
              if (latestWeeklyReport!.blockers.isNotEmpty) Text('本周阻碍：${latestWeeklyReport!.blockers.join('；')}', style: const TextStyle(height: 1.45, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              Text('下周主线：${latestWeeklyReport!.nextFocus}', style: const TextStyle(height: 1.45)),
              const SizedBox(height: 6),
              Text('建议下一步：${latestWeeklyReport!.nextAction}', style: const TextStyle(height: 1.45, color: Color(0xFF475569))),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Text('第四层月度重点', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(latestMonthlyReport?.headline ?? '还没有月度重点报告。建议等积累更多行动与复盘后生成。', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45)),
            if ((latestMonthlyReport?.summary ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(latestMonthlyReport!.summary, style: const TextStyle(height: 1.5)),
            ],
            if (latestMonthlyReport != null) ...<Widget>[
              const SizedBox(height: 10),
              if (latestMonthlyReport!.shifts.isNotEmpty) Text('本月变化：${latestMonthlyReport!.shifts.join('；')}', style: const TextStyle(height: 1.45)),
              const SizedBox(height: 6),
              if (latestMonthlyReport!.loops.isNotEmpty) Text('旧回路：${latestMonthlyReport!.loops.join('；')}', style: const TextStyle(height: 1.45, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              Text('下月重点：${latestMonthlyReport!.nextMonthFocus}', style: const TextStyle(height: 1.45)),
              const SizedBox(height: 6),
              Text('下月实验：${latestMonthlyReport!.nextExperiment}', style: const TextStyle(height: 1.45, color: Color(0xFF475569))),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Text('第三层成长剧情与曲线', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(growthReport?.storyTitle ?? '还没有第三层成长报告。你可以继续生成成长报告来查看长期剧情。', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45)),
            if ((growthReport?.storyBody ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(growthReport!.storyBody, style: const TextStyle(height: 1.5)),
            ],
            const SizedBox(height: 10),
            _GrowthCurveCard(points: growthReport?.curve ?? buildStressGrowthCurve(actions: actions, reviews: reviews, sessions: sessions)),
          ]),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Text('近期线索回看', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (latestScene != null) ...<Widget>[
              Text('最近一次知行城选择：${latestScene.choiceTitle}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(latestScene.feedback, style: const TextStyle(height: 1.45)),
              const SizedBox(height: 8),
            ],
            if (latestReview != null)
              Text('最近一次复盘里的核心感受：${latestReview.feeling.isEmpty ? '未填写' : latestReview.feeling}', style: const TextStyle(color: Color(0xFF475569), height: 1.45))
            else
              const Text('还没有复盘记录。', style: TextStyle(height: 1.45)),
            const SizedBox(height: 10),
            Text('当前最值得回到的单元：${focusUnit.title}', style: const TextStyle(height: 1.45)),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: () => onOpenUnit(focusUnit), icon: const Icon(Icons.menu_book_outlined), label: const Text('回到最相关单元')),
          ]),
        ),
      ],
    );
  }
}

class StressUnitDetailPage extends StatelessWidget {
  final StressUnit unit;
  final Map<String, String> aiState;
  final StressPersonaProfile? persona;
  final Future<void> Function() onOpenActionAi;
  final Future<void> Function() onOpenScene;
  final Future<void> Function() onOpenReview;

  const StressUnitDetailPage({
    super.key,
    required this.unit,
    required this.aiState,
    required this.persona,
    required this.onOpenActionAi,
    required this.onOpenScene,
    required this.onOpenReview,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${unit.sortOrder}. ${unit.title}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _SectionCard(child: _TextSection(title: '课程母本', body: unit.fullContent)),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const Text('核心概念', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: unit.concepts.map((e) => Chip(label: Text(e))).toList()),
              if (persona != null) ...<Widget>[
                const SizedBox(height: 12),
                Text('与你当前画像最相关的焦点：${persona!.currentFocus}', style: const TextStyle(color: Color(0xFF475569))),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          _SectionCard(child: _TextSection(title: '是什么', body: unit.whatText)),
          const SizedBox(height: 12),
          _SectionCard(child: _TextSection(title: '为什么重要', body: unit.whyText)),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const Text('怎样做', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...unit.howSteps.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('• $e', style: const TextStyle(height: 1.5)),
                  )),
            ]),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const Text('具体案例分析', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...unit.courseCases.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('课程案例：$e', style: const TextStyle(height: 1.5)))),
              ...unit.lifeCases.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('现实案例：$e', style: const TextStyle(height: 1.5)))),
            ]),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const Text('第二层落地', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('知行城场景：${unit.scene}。建议先在场景里试一次，再把你最想选的策略转成现实行动。', style: const TextStyle(height: 1.5)),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: <Widget>[
                FilledButton.icon(onPressed: onOpenActionAi, icon: const Icon(Icons.auto_awesome), label: const Text('AI 拆解行动')),
                OutlinedButton.icon(onPressed: onOpenScene, icon: const Icon(Icons.videogame_asset_outlined), label: const Text('进入场景模拟')),
                OutlinedButton.icon(onPressed: onOpenReview, icon: const Icon(Icons.edit_note_outlined), label: const Text('直接写复盘')),
              ]),
              const SizedBox(height: 10),
              Text('当前模块模型：${aiState['label'] ?? '未配置'}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ]),
          ),
        ],
      ),
    );
  }
}

class StressAiActionPage extends StatefulWidget {
  final StressUnit unit;
  final StressAiService ai;
  final Future<void> Function(StressAction action) onSaveAction;

  const StressAiActionPage({super.key, required this.unit, required this.ai, required this.onSaveAction});

  @override
  State<StressAiActionPage> createState() => _StressAiActionPageState();
}

class _StressAiActionPageState extends State<StressAiActionPage> {
  final TextEditingController _concernCtrl = TextEditingController();
  bool _loading = false;
  StressActionPlanResult? _result;

  @override
  void dispose() {
    _concernCtrl.dispose();
    super.dispose();
  }

  String _id(String prefix) => '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}';

  Future<void> _generate() async {
    setState(() => _loading = true);
    final result = await widget.ai.generateActionPlan(unit: widget.unit, concern: _concernCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final result = _result ?? StressActionPlanResult.fallback(widget.unit, concern: _concernCtrl.text.trim());
    final steps = result.weekChain.isNotEmpty ? result.weekChain : widget.unit.howSteps;
    final action = StressAction(
      id: _id('stress_action'),
      unitId: widget.unit.id,
      unitTitle: widget.unit.title,
      source: result.provider,
      title: widget.unit.defaultActionTitle,
      body: result.todayMinimalAction.trim().isEmpty ? widget.unit.defaultActionBody : result.todayMinimalAction,
      difficulty: 'L1-L2',
      duration: '10-30分钟',
      successCriteria: '完成至少一条最小动作，并写下一条事实记录。',
      fallbackAction: result.recoveryAction,
      reviewQuestion: result.reviewQuestion.trim().isEmpty ? widget.unit.reflectionQuestion : result.reviewQuestion,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      status: 'todo',
      steps: steps,
      stepMarks: List<bool>.filled(steps.length, false),
    );
    await widget.onSaveAction(action);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI 拆解行动 · ${widget.unit.sortOrder}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _concernCtrl,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '你当前最想解决的现实困扰',
              hintText: '例如：我一休息就忍不住刷工作消息；我总拖着不开始；我明明很忙却没成果。',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _loading ? null : _generate, icon: const Icon(Icons.auto_awesome), label: Text(_loading ? '生成中…' : '生成行动拆解')),
          if (_result != null) ...<Widget>[
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text('问题判断（${_result!.modelLabel}）', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(_result!.problemJudgment, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 12),
                const Text('今天最小行动', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(_result!.todayMinimalAction, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 12),
                const Text('本周行为链', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ..._result!.weekChain.map((e) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $e'))),
                const SizedBox(height: 12),
                const Text('失败后的恢复动作', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(_result!.recoveryAction, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 12),
                Text('复盘问题：${_result!.reviewQuestion}', style: const TextStyle(height: 1.5)),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: _save, icon: const Icon(Icons.playlist_add_check), label: const Text('加入行动实践')),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class StressActionDetailPage extends StatefulWidget {
  final StressAction action;
  final StressUnit unit;
  final Future<void> Function(StressAction action) onSaveAction;
  final Future<void> Function() onOpenReview;

  const StressActionDetailPage({super.key, required this.action, required this.unit, required this.onSaveAction, required this.onOpenReview});

  @override
  State<StressActionDetailPage> createState() => _StressActionDetailPageState();
}

class _StressActionDetailPageState extends State<StressActionDetailPage> {
  late TextEditingController _factCtrl;
  late TextEditingController _obstacleCtrl;
  late TextEditingController _nextCtrl;
  late List<bool> _stepMarks;
  late String _status;

  @override
  void initState() {
    super.initState();
    _factCtrl = TextEditingController(text: widget.action.factLog);
    _obstacleCtrl = TextEditingController(text: widget.action.obstacleNote);
    _nextCtrl = TextEditingController(text: widget.action.nextStepNote);
    _stepMarks = List<bool>.from(widget.action.stepMarks.isEmpty ? List<bool>.filled(widget.action.steps.length, false) : widget.action.stepMarks);
    if (_stepMarks.length < widget.action.steps.length) {
      _stepMarks.addAll(List<bool>.filled(widget.action.steps.length - _stepMarks.length, false));
    }
    _status = widget.action.status;
  }

  @override
  void dispose() {
    _factCtrl.dispose();
    _obstacleCtrl.dispose();
    _nextCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updated = widget.action.copyWith(
      status: _status,
      factLog: _factCtrl.text.trim(),
      obstacleNote: _obstacleCtrl.text.trim(),
      nextStepNote: _nextCtrl.text.trim(),
      stepMarks: _stepMarks,
    );
    await widget.onSaveAction(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('行动已更新')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.action.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(widget.unit.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(widget.action.body, style: const TextStyle(height: 1.5)),
              const SizedBox(height: 8),
              Text('成功判据：${widget.action.successCriteria}'),
              const SizedBox(height: 4),
              Text('失败补救：${widget.action.fallbackAction}'),
            ]),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const Text('行动步骤', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...List<Widget>.generate(widget.action.steps.length, (int index) {
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: index < _stepMarks.length ? _stepMarks[index] : false,
                  title: Text(widget.action.steps[index]),
                  onChanged: (v) => setState(() => _stepMarks[index] = v ?? false),
                );
              }),
            ]),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: '当前状态', border: OutlineInputBorder()),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: 'todo', child: Text('待开始')),
              DropdownMenuItem(value: 'doing', child: Text('进行中')),
              DropdownMenuItem(value: 'partial', child: Text('部分完成')),
              DropdownMenuItem(value: 'done', child: Text('已完成')),
              DropdownMenuItem(value: 'failed', child: Text('失败 / 中断')),
              DropdownMenuItem(value: 'skipped', child: Text('跳过')),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'todo'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _factCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '事实记录', hintText: '今天具体做了什么？有哪些可观察事实？', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _obstacleCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '最大阻碍', hintText: '例如：想看消息、太累、环境太吵、怕出错。', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _nextCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '下一步微调', hintText: '例如：明天先做 5 分钟版本；先关 30 分钟通知。', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: <Widget>[
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('保存行动')),
            OutlinedButton.icon(onPressed: widget.onOpenReview, icon: const Icon(Icons.edit_note_outlined), label: const Text('去写复盘')),
          ]),
        ],
      ),
    );
  }
}

class StressReviewPage extends StatefulWidget {
  final StressUnit unit;
  final StressAiService ai;
  final Future<void> Function(StressReviewEntry review) onSave;

  const StressReviewPage({super.key, required this.unit, required this.ai, required this.onSave});

  @override
  State<StressReviewPage> createState() => _StressReviewPageState();
}

class _StressReviewPageState extends State<StressReviewPage> {
  final TextEditingController _factCtrl = TextEditingController();
  final TextEditingController _feelingCtrl = TextEditingController();
  final TextEditingController _thoughtCtrl = TextEditingController();
  final TextEditingController _actionCtrl = TextEditingController();
  final TextEditingController _outcomeCtrl = TextEditingController();
  bool _aiLoading = false;
  String _aiSummary = '';

  @override
  void dispose() {
    _factCtrl.dispose();
    _feelingCtrl.dispose();
    _thoughtCtrl.dispose();
    _actionCtrl.dispose();
    _outcomeCtrl.dispose();
    super.dispose();
  }

  String _id(String prefix) => '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}';

  Future<void> _genAi() async {
    setState(() => _aiLoading = true);
    final text = await widget.ai.summarizeReview(
      unit: widget.unit,
      fact: _factCtrl.text.trim(),
      feeling: _feelingCtrl.text.trim(),
      action: _actionCtrl.text.trim(),
      outcome: _outcomeCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _aiSummary = text;
      _aiLoading = false;
    });
  }

  Future<void> _save() async {
    final review = StressReviewEntry(
      id: _id('stress_review'),
      unitId: widget.unit.id,
      unitTitle: widget.unit.title,
      fact: _factCtrl.text.trim(),
      feeling: _feelingCtrl.text.trim(),
      thought: _thoughtCtrl.text.trim(),
      action: _actionCtrl.text.trim(),
      outcome: _outcomeCtrl.text.trim(),
      aiSummary: _aiSummary,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await widget.onSave(review);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('复盘 · ${widget.unit.sortOrder}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('核心复盘问题：${widget.unit.reflectionQuestion}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(controller: _factCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '事实', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _feelingCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '感受', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _thoughtCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '当时的想法', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _actionCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '我采取的动作', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _outcomeCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '结果', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: <Widget>[
            FilledButton.icon(onPressed: _aiLoading ? null : _genAi, icon: const Icon(Icons.auto_awesome), label: Text(_aiLoading ? '生成中…' : 'AI 总结这次复盘')),
            OutlinedButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('保存复盘')),
          ]),
          if (_aiSummary.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _SectionCard(child: _TextSection(title: 'AI 复盘摘要', body: _aiSummary)),
          ],
        ],
      ),
    );
  }
}

class StressDistrictDetailPage extends StatelessWidget {
  final Map<String, dynamic> district;
  final List<StressSceneSession> sceneSessions;
  final Future<void> Function(String sceneName) onOpenScene;

  const StressDistrictDetailPage({super.key, required this.district, required this.sceneSessions, required this.onOpenScene});

  @override
  Widget build(BuildContext context) {
    final sceneNames = (district['scenes'] as List).cast<String>();
    return Scaffold(
      appBar: AppBar(title: Text('${district['name']}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _SectionCard(child: _TextSection(title: '城区说明', body: '${district['subtitle']}\n你可以先选一个最贴近现实的问题场景，先模拟，再带回现实。')),
          const SizedBox(height: 12),
          ...sceneNames.map((sceneName) {
            final count = sceneSessions.where((e) => e.sceneName == sceneName).length;
            final unitIds = stressScenes[sceneName] ?? <String>[];
            final titles = stressUnits.where((u) => unitIds.contains(u.id)).map((e) => e.sortOrder.toString()).join('、');
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: const Color(0xFFE0F2FE), child: Text('$count', style: const TextStyle(fontWeight: FontWeight.bold))),
                title: Text(sceneName),
                subtitle: Text('关联单元：$titles\n已模拟：$count 次'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpenScene(sceneName),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class StressSceneDetailPage extends StatelessWidget {
  final String sceneName;
  final List<StressUnit> units;
  final StressPersonaProfile? persona;
  final List<StressSceneSession> sessions;
  final Future<void> Function(StressUnit unit) onOpenUnit;
  final Future<void> Function(StressUnit unit) onStartPlay;

  const StressSceneDetailPage({
    super.key,
    required this.sceneName,
    required this.units,
    required this.persona,
    required this.sessions,
    required this.onOpenUnit,
    required this.onStartPlay,
  });

  @override
  Widget build(BuildContext context) {
    final latest = sessions.isNotEmpty ? sessions.first : null;
    return Scaffold(
      appBar: AppBar(title: Text(sceneName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const Text('场景说明', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('这是知行城里的「$sceneName」。你将在低风险环境里先练一次决策，然后把最有效的选择转成现实行动。', style: const TextStyle(height: 1.5)),
              if (persona != null) ...<Widget>[
                const SizedBox(height: 10),
                Text('当前镜像角色：${persona!.roleLabel} · ${persona!.currentFocus}', style: const TextStyle(color: Color(0xFF475569))),
              ],
              if (latest != null) ...<Widget>[
                const SizedBox(height: 10),
                Text('你最近一次在这个场景里的选择：${latest.choiceTitle}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(latest.feedback, style: const TextStyle(height: 1.45)),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          ...units.map((unit) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text('${unit.sortOrder}. ${unit.title}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(unit.oneLiner),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                      OutlinedButton.icon(onPressed: () => onOpenUnit(unit), icon: const Icon(Icons.menu_book_outlined), label: const Text('看单元')),
                      FilledButton.icon(onPressed: () => onStartPlay(unit), icon: const Icon(Icons.play_arrow), label: const Text('开始模拟')),
                    ]),
                  ]),
                ),
              )),
        ],
      ),
    );
  }
}

class StressScenePlayPage extends StatefulWidget {
  final StressUnit unit;
  final StressPersonaProfile? persona;
  final Future<void> Function(StressSceneSession session) onSaveScene;
  final Future<void> Function(StressSceneSession session) onCreateAction;

  const StressScenePlayPage({super.key, required this.unit, required this.persona, required this.onSaveScene, required this.onCreateAction});

  @override
  State<StressScenePlayPage> createState() => _StressScenePlayPageState();
}

class _StressScenePlayPageState extends State<StressScenePlayPage> {
  String _feedback = '';
  String _actionHint = '';
  int _focus = 60;
  int _recovery = 50;
  int _pressure = 55;
  _SceneChoice? _selected;

  String get _scenarioBackground {
    final role = widget.persona?.roleLabel ?? '学习者';
    final focus = widget.persona?.currentFocus ?? '先恢复再推进';
    final support = widget.persona?.supportStyle ?? '需要先看清问题再行动';
    final tempo = widget.persona?.changeTempo ?? '适合从小动作慢慢推进';
    final avoidance = widget.persona?.avoidancePattern ?? '容易被任务过大与过多压住';
    return '你当前以「$role」身份进入 ${widget.unit.scene}。你最近最重要的焦点是“$focus”。你的支持偏好更接近“$support”，改变节奏更像“$tempo”，旧回路则常常是“$avoidance”。现在系统把你放进一个与「${widget.unit.title}」相关的典型现实压力点：你需要先在虚拟世界里做一次低风险决策，再把它带回现实。';
  }

  List<_SceneChoice> get _choices {
    final title = widget.unit.title;
    return <_SceneChoice>[
      _SceneChoice(
        title: '按旧模式继续硬撑',
        subtitle: '先不调整结构，继续把自己往前推。',
        focusDelta: -12,
        recoveryDelta: -10,
        pressureDelta: 14,
        feedback: '结果：短期像是在推进，实际上系统更紧了。对应「$title」：如果一直硬撑却不恢复，压力会从刺激变成慢性损耗。',
        actionHint: '今天只做一件事：在一项高消耗任务后明确安排 10 分钟恢复，不再无缝硬接下一件事。',
      ),
      _SceneChoice(
        title: '先做一个最小动作',
        subtitle: '不求完整解决，只先打开一个 5–10 分钟入口。',
        focusDelta: 12,
        recoveryDelta: 4,
        pressureDelta: -6,
        feedback: '结果：你开始从“想很多”转向“做一点”。这更接近课程里的最小行动入口。',
        actionHint: '把今天最卡的一件事缩成 5 分钟版本，并只记录一个事实：你做了什么。',
      ),
      _SceneChoice(
        title: '先删掉一个同时进行的任务',
        subtitle: '给当前最重要的一件事腾出空间。',
        focusDelta: 10,
        recoveryDelta: 8,
        pressureDelta: -10,
        feedback: '结果：系统噪音下降了。对应课程提醒：很多问题不是再加什么，而是先删一点过量生活。',
        actionHint: '今天删掉或推迟一件非核心任务，只保留最重要的一件主任务。',
      ),
      _SceneChoice(
        title: '先恢复再继续',
        subtitle: '去散步、静息、喝水，或做一段干净恢复。',
        focusDelta: 8,
        recoveryDelta: 16,
        pressureDelta: -12,
        feedback: '结果：恢复值明显上升。对应课程提醒：压力不是敌人，缺乏恢复才是。',
        actionHint: '先做一个 10 分钟干净恢复，然后再回到 5~10 分钟版本的任务。',
      ),
    ];
  }

  Future<void> _applyChoice(_SceneChoice choice) async {
    setState(() {
      _selected = choice;
      _focus = (_focus + choice.focusDelta).clamp(0, 100);
      _recovery = (_recovery + choice.recoveryDelta).clamp(0, 100);
      _pressure = (_pressure + choice.pressureDelta).clamp(0, 100);
      _feedback = choice.feedback;
      _actionHint = choice.actionHint;
    });
    final session = StressSceneSession(
      id: 'stress_scene_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}',
      unitId: widget.unit.id,
      unitTitle: widget.unit.title,
      sceneName: widget.unit.scene,
      choiceTitle: choice.title,
      feedback: choice.feedback,
      actionHint: choice.actionHint,
      focus: _focus,
      recovery: _recovery,
      pressure: _pressure,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await widget.onSaveScene(session);
  }

  Future<void> _createAction() async {
    final choice = _selected;
    if (choice == null) return;
    final session = StressSceneSession(
      id: 'stress_scene_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}',
      unitId: widget.unit.id,
      unitTitle: widget.unit.title,
      sceneName: widget.unit.scene,
      choiceTitle: choice.title,
      feedback: choice.feedback,
      actionHint: choice.actionHint,
      focus: _focus,
      recovery: _recovery,
      pressure: _pressure,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await widget.onCreateAction(session);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已把场景选择转成现实行动')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('知行城 · ${widget.unit.scene}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(widget.unit.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(_scenarioBackground, style: const TextStyle(height: 1.5)),
              const SizedBox(height: 12),
              _MeterRow(label: '专注值', value: _focus, color: const Color(0xFF2563EB)),
              const SizedBox(height: 6),
              _MeterRow(label: '恢复值', value: _recovery, color: const Color(0xFF16A34A)),
              const SizedBox(height: 6),
              _MeterRow(label: '压力值', value: _pressure, color: const Color(0xFFDC2626)),
            ]),
          ),
          const SizedBox(height: 12),
          ..._choices.map((choice) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(choice.title),
                  subtitle: Text(choice.subtitle),
                  trailing: _selected?.title == choice.title ? const Icon(Icons.check_circle, color: Color(0xFF16A34A)) : const Icon(Icons.chevron_right),
                  onTap: () => _applyChoice(choice),
                ),
              )),
          if (_feedback.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _SectionCard(child: _TextSection(title: '结果反馈', body: _feedback)),
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                const Text('带回现实', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(_actionHint, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: <Widget>[
                  FilledButton.icon(onPressed: _createAction, icon: const Icon(Icons.playlist_add_check), label: const Text('转成现实行动')),
                  OutlinedButton.icon(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.check), label: const Text('先记住这个策略')),
                ]),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class StressPersonaSetupPage extends StatefulWidget {
  final StressPersonaProfile? initial;

  const StressPersonaSetupPage({super.key, required this.initial});

  @override
  State<StressPersonaSetupPage> createState() => _StressPersonaSetupPageState();
}

class _StressPersonaSetupPageState extends State<StressPersonaSetupPage> {
  late String _role;
  late String _focus;
  late String _energyStyle;
  late String _supportStyle;
  late String _changeTempo;
  late String _avoidancePattern;
  late Set<String> _tags;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial ?? StressPersonaProfile.initial();
    _role = _mapBackRole(initial.roleLabel);
    _focus = stressFocusOptions.contains(initial.currentFocus) ? initial.currentFocus : stressFocusOptions.first;
    _energyStyle = stressEnergyStyles.contains(initial.energyStyle) ? initial.energyStyle : stressEnergyStyles.first;
    _supportStyle = stressSupportStyles.contains(initial.supportStyle) ? initial.supportStyle : stressSupportStyles.first;
    _changeTempo = stressChangeTempos.contains(initial.changeTempo) ? initial.changeTempo : stressChangeTempos.first;
    _avoidancePattern = stressAvoidancePatterns.contains(initial.avoidancePattern) ? initial.avoidancePattern : stressAvoidancePatterns.first;
    _tags = initial.stressTags.toSet();
  }

  String _mapBackRole(String label) {
    if (label.contains('学生')) return '学生';
    if (label.contains('职场')) return '职场人';
    if (label.contains('创作者')) return '创作者';
    return '多角色';
  }

  String _roleLabel(String role) {
    switch (role) {
      case '学生':
        return '高压学生';
      case '职场人':
        return '高负荷职场人';
      case '创作者':
        return '多线创作者';
      default:
        return '多角色学习者';
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_tags.contains(tag)) {
        _tags.remove(tag);
      } else {
        _tags.add(tag);
      }
    });
  }

  void _save() {
    final profile = StressPersonaProfile(
      role: _role,
      roleLabel: _roleLabel(_role),
      stressTags: _tags.isEmpty ? <String>['恢复不足'] : _tags.toList(),
      currentFocus: _focus,
      energyStyle: _energyStyle,
      supportStyle: _supportStyle,
      changeTempo: _changeTempo,
      avoidancePattern: _avoidancePattern,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('镜像角色画像')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const Text('你的现实身份', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stressPersonaRoles
                    .map((role) => ChoiceChip(label: Text(role), selected: _role == role, onSelected: (_) => setState(() => _role = role)))
                    .toList(),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const Text('你最近最常见的压力来源', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stressPersonaTags
                    .map((tag) => FilterChip(label: Text(tag), selected: _tags.contains(tag), onSelected: (_) => _toggleTag(tag)))
                    .toList(),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const Text('当前最想优先修复的一点', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...stressFocusOptions.map((focus) => RadioListTile<String>(
                    value: focus,
                    groupValue: _focus,
                    title: Text(focus),
                    onChanged: (v) => setState(() => _focus = v ?? stressFocusOptions.first),
                  )),
            ]),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const Text('你更像哪种能量模式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...stressEnergyStyles.map((style) => RadioListTile<String>(
                    value: style,
                    groupValue: _energyStyle,
                    title: Text(style),
                    onChanged: (v) => setState(() => _energyStyle = v ?? stressEnergyStyles.first),
                  )),
            ]),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const Text('第三层：你更需要怎样的支持', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...stressSupportStyles.map((style) => RadioListTile<String>(
                    value: style,
                    groupValue: _supportStyle,
                    title: Text(style),
                    onChanged: (v) => setState(() => _supportStyle = v ?? stressSupportStyles.first),
                  )),
            ]),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const Text('第三层：你更适合怎样改变', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...stressChangeTempos.map((style) => RadioListTile<String>(
                    value: style,
                    groupValue: _changeTempo,
                    title: Text(style),
                    onChanged: (v) => setState(() => _changeTempo = v ?? stressChangeTempos.first),
                  )),
            ]),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const Text('第三层：你最容易掉回哪条旧回路', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...stressAvoidancePatterns.map((style) => RadioListTile<String>(
                    value: style,
                    groupValue: _avoidancePattern,
                    title: Text(style),
                    onChanged: (v) => setState(() => _avoidancePattern = v ?? stressAvoidancePatterns.first),
                  )),
            ]),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('保存画像并更新推荐路径')),
        ],
      ),
    );
  }
}

class _GrowthCurveCard extends StatelessWidget {
  final List<StressGrowthPoint> points;

  const _GrowthCurveCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final safePoints = points.isEmpty
        ? buildStressGrowthCurve(actions: const <StressAction>[], reviews: const <StressReviewEntry>[], sessions: const <StressSceneSession>[])
        : points;
    final maxScore = safePoints.map((e) => e.score).fold<int>(1, (prev, e) => e > prev ? e : prev);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: safePoints.map((p) {
        final ratio = ((p.score <= 0 ? 0.0 : p.score / maxScore).clamp(0.0, 1.0) as num).toDouble();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox(width: 44, child: Text(p.label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${p.score}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text('学 ${p.learned} · 行 ${p.acted} · 复 ${p.reviewed} · 模 ${p.simulated}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ]),
        );
      }).toList(),
    );
  }
}

class _TextSection extends StatelessWidget {
  final String title;
  final String body;

  const _TextSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(body, style: const TextStyle(height: 1.55)),
    ]);
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x11000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _QuickStat({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Icon(icon, color: const Color(0xFF475569)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      ]),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _FeatureCard({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x11000000), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Icon(icon, color: const Color(0xFF334155)),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4)),
        ]),
      ),
    );
  }
}

class _MeterRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MeterRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(width: 58, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: value / 100, minHeight: 10, backgroundColor: const Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation<Color>(color)),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.right)),
      ],
    );
  }
}

class _SceneChoice {
  final String title;
  final String subtitle;
  final int focusDelta;
  final int recoveryDelta;
  final int pressureDelta;
  final String feedback;
  final String actionHint;

  const _SceneChoice({
    required this.title,
    required this.subtitle,
    required this.focusDelta,
    required this.recoveryDelta,
    required this.pressureDelta,
    required this.feedback,
    required this.actionHint,
  });
}
