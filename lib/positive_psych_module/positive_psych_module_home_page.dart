import 'package:flutter/material.dart';

import '../pages/settings_page.dart';
import '../sustainable_excellence/sustainable_excellence_home_page.dart';
import 'positive_psych_ai_service.dart';
import 'positive_psych_dao.dart';
import 'positive_psych_models.dart';
import 'positive_psych_seed.dart';

class PositivePsychModuleHomePage extends StatefulWidget {
  const PositivePsychModuleHomePage({super.key});

  @override
  State<PositivePsychModuleHomePage> createState() => _PositivePsychModuleHomePageState();
}

class _PositivePsychModuleHomePageState extends State<PositivePsychModuleHomePage> {
  final PositivePsychDao _dao = PositivePsychDao();
  final PositivePsychAiService _ai = PositivePsychAiService();

  int _idx = 0;
  bool _loading = true;
  bool _promptedPersona = false;
  List<PositivePsychAction> _actions = <PositivePsychAction>[];
  List<PositivePsychReview> _reviews = <PositivePsychReview>[];
  Set<String> _done = <String>{};
  Map<String, String> _aiState = const <String, String>{'label': '读取中…'};
  PositivePsychPersonaProfile? _persona;
  PositivePsychWorldState? _world;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final actions = await _dao.loadActions();
    final reviews = await _dao.loadReviews();
    final done = await _dao.loadCompletedSegments();
    final aiState = await _ai.getGlobalAiState();
    final persona = await _dao.loadPersona();
    final world = await _dao.loadWorldState();
    final syncedWorld = _syncWorld(done: done, actions: actions, reviews: reviews, current: world);
    await _dao.saveWorldState(syncedWorld);
    if (!mounted) return;
    setState(() {
      _actions = actions;
      _reviews = reviews;
      _done = done;
      _aiState = aiState;
      _persona = persona;
      _world = syncedWorld;
      _loading = false;
    });
    if (!_promptedPersona && persona == null && mounted) {
      _promptedPersona = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPersonaSheet());
    }
  }

  PositivePsychWorldState _syncWorld({
    required Set<String> done,
    required List<PositivePsychAction> actions,
    required List<PositivePsychReview> reviews,
    required PositivePsychWorldState current,
  }) {
    final nodes = <String>{...current.unlockedNodes, '解释风格学院'};
    if (done.any((e) => e.startsWith('pp_l7_'))) nodes.add('失败训练营');
    if (done.any((e) => e.startsWith('pp_l7_')) || actions.isNotEmpty) nodes.add('行动工坊');
    if (done.any((e) => e.startsWith('pp_l8_'))) nodes.add('感恩花园');
    if (done.any((e) => e.startsWith('pp_l9_')) || reviews.isNotEmpty) nodes.add('真实之镜');
    if (actions.where((e) => e.status == 'done').length >= 3) nodes.add('复盘回廊');
    if (reviews.length >= 3 || done.length >= 12) nodes.add('危机熔炉');
    final currentNode = nodes.contains(current.currentNode) ? current.currentNode : nodes.first;
    return current.copyWith(
      unlockedNodes: nodes.toList(),
      currentNode: currentNode,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _saveAction(PositivePsychAction action) async {
    await _dao.saveAction(action);
    await _dao.markSegmentCompleted(action.segmentId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入现实行动')));
  }

  Future<void> _updateAction(PositivePsychAction action) async {
    await _dao.updateAction(action);
    await _load();
  }

  Future<void> _saveReview(PositivePsychReview review) async {
    await _dao.saveReview(review);
    await _dao.markSegmentCompleted(review.segmentId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存复盘记录')));
  }

  PositivePsychSegment? _segmentById(String id) {
    for (final s in positivePsychSegments) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> _openSegment(PositivePsychSegment segment) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PositivePsychSegmentDetailPage(
        segment: segment,
        ai: _ai,
        onSaveAction: _saveAction,
        onSaveReview: _saveReview,
      ),
    ));
    await _load();
  }

  Future<void> _openAction(PositivePsychAction action) async {
    final segment = _segmentById(action.segmentId);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PositivePsychActionDetailPage(
        action: action,
        segment: segment,
        onSave: _updateAction,
        onSaveReview: _saveReview,
        ai: _ai,
      ),
    ));
    await _load();
  }


  Future<void> _openReviewDetail(PositivePsychReview review) async {
    final segment = _segmentById(review.segmentId);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PositivePsychReviewDetailPage(
        review: review,
        segment: segment,
        ai: _ai,
        onOpenSegment: segment == null ? null : () => _openSegment(segment),
      ),
    ));
    await _load();
  }

  Future<void> _openPersonaSheet() async {
    final current = _persona;
    final problemCtrl = TextEditingController(text: current?.currentProblem ?? '');
    final goalCtrl = TextEditingController(text: current?.growthGoal ?? '');
    String selfType = current?.selfType ?? 'mixed';
    String focus = current?.currentFocus ?? '工作与学习';
    String bias = current?.biasType ?? 'mixed';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('建立你的现实映射档案', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('这一步用于让虚拟世界、推荐段落和行动方案更贴近你的真实处境。'),
                    const SizedBox(height: 12),
                    _dropdownField(
                      label: '你更像哪一种起点风格？',
                      value: selfType,
                      items: const <String>['mixed', 'fault-finder', 'benefit-finder'],
                      onChanged: (v) => setSheetState(() => selfType = v),
                    ),
                    const SizedBox(height: 8),
                    _dropdownField(
                      label: '你当前最想改善的生活领域',
                      value: focus,
                      items: const <String>['工作与学习', '关系互动', '情绪恢复', '健康与日常习惯'],
                      onChanged: (v) => setSheetState(() => focus = v),
                    ),
                    const SizedBox(height: 8),
                    _dropdownField(
                      label: '你最常见的思维偏差',
                      value: bias,
                      items: const <String>['mixed', 'Magnifying', 'Minimizing', 'Making up'],
                      onChanged: (v) => setSheetState(() => bias = v),
                    ),
                    const SizedBox(height: 8),
                    _input('你最近最困扰的问题', problemCtrl),
                    const SizedBox(height: 8),
                    _input('你希望通过这个模块达成什么改变', goalCtrl),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final profile = PositivePsychPersonaProfile(
                            selfType: selfType,
                            currentFocus: focus,
                            currentProblem: problemCtrl.text.trim(),
                            biasType: bias,
                            growthGoal: goalCtrl.text.trim(),
                            updatedAt: DateTime.now().millisecondsSinceEpoch,
                          );
                          await _dao.savePersona(profile);
                          if (!mounted) return;
                          Navigator.pop(sheetContext);
                          await _load();
                        },
                        child: const Text('保存映射档案'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _OverviewPage(
        doneCount: _done.length,
        actionCount: _actions.length,
        reviewCount: _reviews.length,
        aiState: _aiState,
        todaySegment: _ai.recommendTodaySegment(completedSegments: _done, reviews: _reviews),
        latestAction: _actions.isEmpty ? null : _actions.first,
        persona: _persona,
        world: _world,
        onOpenSegment: _openSegment,
        onOpenAction: _openAction,
        onOpenSettings: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
        onOpenPersona: _openPersonaSheet,
      ),
      _CoursePage(done: _done, onOpenSegment: _openSegment),
      _WorldPage(world: _world, persona: _persona, actions: _actions, reviews: _reviews, onOpenPersona: _openPersonaSheet, onOpenSegment: _openSegment),
      _ActionPage(actions: _actions, onOpenAction: _openAction),
      _ReviewPage(reviews: _reviews, onOpenReview: _openReviewDetail, onOpenSegment: _openSegment),
      _GrowthPage(done: _done, actions: _actions, reviews: _reviews, aiState: _aiState, persona: _persona, onOpenSegment: _openSegment),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('积极心理知行课'),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology_alt_outlined),
            onPressed: _openPersonaSheet,
          ),
          IconButton(
            tooltip: 'Lecture 14-16 实践实验室',
            icon: const Icon(Icons.all_inclusive_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SustainableExcellenceHomePage(initialInput: '把 Lecture 14-16 的压力恢复、完美主义转卓越、享受过程落到今天行动', source: 'positive_psych_lecture_14_16', extraContext: '{"lecture":"14-16","themes":"stress_recovery,perfectionism,process_enjoyment"}'))),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: _loading ? const Center(child: CircularProgressIndicator()) : pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: '总览'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: '课程'),
          NavigationDestination(icon: Icon(Icons.public_outlined), label: '知行域'),
          NavigationDestination(icon: Icon(Icons.task_alt_outlined), label: '行动'),
          NavigationDestination(icon: Icon(Icons.rate_review_outlined), label: '复盘'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), label: '成长'),
        ],
      ),
    );
  }
}

class _OverviewPage extends StatelessWidget {
  final int doneCount;
  final int actionCount;
  final int reviewCount;
  final Map<String, String> aiState;
  final PositivePsychSegment todaySegment;
  final PositivePsychAction? latestAction;
  final PositivePsychPersonaProfile? persona;
  final PositivePsychWorldState? world;
  final ValueChanged<PositivePsychSegment> onOpenSegment;
  final ValueChanged<PositivePsychAction> onOpenAction;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenPersona;

  const _OverviewPage({
    required this.doneCount,
    required this.actionCount,
    required this.reviewCount,
    required this.aiState,
    required this.todaySegment,
    required this.latestAction,
    required this.persona,
    required this.world,
    required this.onOpenSegment,
    required this.onOpenAction,
    required this.onOpenSettings,
    required this.onOpenPersona,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroCard(
          title: '今日驾驶舱',
          subtitle: '把课程、虚拟操练、现实行动和复盘串成一条线。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(todaySegment.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(todaySegment.subtitle, style: const TextStyle(color: Color(0xFF4B5563))),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(onPressed: () => onOpenSegment(todaySegment), icon: const Icon(Icons.play_arrow), label: const Text('进入今日段落')),
                  OutlinedButton.icon(onPressed: onOpenPersona, icon: const Icon(Icons.person_outline), label: const Text('更新现实映射')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '阶段任务路线',
          subtitle: '把推荐段落拆成一条可以连续推进的训练闭环。',
          child: Builder(builder: (context) {
            final route = _trainingPathForPersona(persona);
            final target = _segmentByCode(route['segment'] as String);
            final tasks = <Map<String, String>>[
              {'title': '第 1 步｜读懂概念', 'desc': '先进入推荐段落，抓住它正在修正的自动模式。'},
              {'title': '第 2 步｜进入知行域', 'desc': '去对应节点做一次剧情训练，把理解推进成选择。'},
              {'title': '第 3 步｜带回现实', 'desc': '用一个最小动作验证新的解释是否真的改变了行为。'},
              {'title': '第 4 步｜写复盘', 'desc': '回到复盘页检查 3M，并沉淀下一轮要保留的动作。'},
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (target != null)
                  OutlinedButton.icon(
                    onPressed: () => onOpenSegment(target),
                    icon: const Icon(Icons.flag_outlined),
                    label: Text('从 ${target.title} 开始'),
                  ),
                const SizedBox(height: 8),
                ...tasks.map((t) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t['title']!, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(t['desc']!),
                      ],
                    ),
                  ),
                )),
              ],
            );
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _MetricCard(label: '已学习段落', value: '$doneCount / ${positivePsychSegments.length}')),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(label: '现实行动', value: '$actionCount')),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(label: '复盘记录', value: '$reviewCount')),
          ],
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '现实映射档案',
          subtitle: '让推荐更贴近你当前的处境。',
          child: persona == null
              ? Row(
                  children: [
                    const Expanded(child: Text('还没有建立档案。建议先填写你的当前困扰、目标与常见偏差。')),
                    TextButton(onPressed: onOpenPersona, child: const Text('去建立')),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前焦点：${persona!.currentFocus}'),
                    const SizedBox(height: 6),
                    Text('常见偏差：${persona!.biasType}'),
                    const SizedBox(height: 6),
                    Text('当前问题：${persona!.currentProblem.isEmpty ? '未填写' : persona!.currentProblem}'),
                    if (persona!.growthGoal.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('成长目标：${persona!.growthGoal}'),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '知行域状态',
          subtitle: '虚拟世界用于先模拟，再落回真实生活。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前节点：${world?.currentNode ?? '解释风格学院'}'),
              const SizedBox(height: 6),
              Text('已解锁：${world?.unlockedNodes.join('、') ?? '解释风格学院'}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '模型状态',
          subtitle: '复用宿主 App 的全局模型设置。',
          child: Row(
            children: [
              Expanded(child: Text(aiState['label'] ?? '未配置')),
              TextButton(onPressed: onOpenSettings, child: const Text('去设置')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (latestAction != null)
          _HeroCard(
            title: '最近行动',
            subtitle: latestAction!.segmentTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(latestAction!.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(latestAction!.body, maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                OutlinedButton(onPressed: () => onOpenAction(latestAction!), child: const Text('继续推进')),
              ],
            ),
          ),
      ],
    );
  }
}

class _CoursePage extends StatelessWidget {
  final Set<String> done;
  final ValueChanged<PositivePsychSegment> onOpenSegment;
  const _CoursePage({required this.done, required this.onOpenSegment});

  @override
  Widget build(BuildContext context) {
    final groups = <int, List<PositivePsychSegment>>{};
    for (final seg in positivePsychSegments) {
      groups.putIfAbsent(seg.lecture, () => <PositivePsychSegment>[]).add(seg);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: groups.entries.map((entry) {
        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ExpansionTile(
            title: Text('Lecture ${entry.key} · ${entry.value.length} 段', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(entry.key == 7 ? '乐观 / 认知重构 / 失败与恢复' : entry.key == 8 ? '找益 / 感恩 / 注意力' : '真实 / 感恩表达 / 复盘与项目'),
            children: entry.value.map((seg) {
              final learned = done.contains(seg.id);
              return ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: learned ? const Color(0xFFDCFCE7) : const Color(0xFFE5E7EB),
                  child: Text('${seg.indexInLecture}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ),
                title: Text(seg.title),
                subtitle: Text(seg.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: learned ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.chevron_right),
                onTap: () => onOpenSegment(seg),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _WorldPage extends StatelessWidget {
  final PositivePsychWorldState? world;
  final PositivePsychPersonaProfile? persona;
  final List<PositivePsychAction> actions;
  final List<PositivePsychReview> reviews;
  final VoidCallback onOpenPersona;
  final ValueChanged<PositivePsychSegment> onOpenSegment;
  const _WorldPage({required this.world, required this.persona, required this.actions, required this.reviews, required this.onOpenPersona, required this.onOpenSegment});

  static const List<Map<String, String>> _nodeDefs = <Map<String, String>>[
    {'name': '解释风格学院', 'desc': '围绕乐观、解释风格和认知疗法建立基本地图。'},
    {'name': '失败训练营', 'desc': '在安全场景中训练如何面对失败、恢复与重启。'},
    {'name': '行动工坊', 'desc': '把抽象理论变成具体行为链和现实任务。'},
    {'name': '感恩花园', 'desc': '练习注意力重定向、日常感恩与表达。'},
    {'name': '真实之镜', 'desc': '同时看见痛苦和美好，练习更完整的现实感。'},
    {'name': '复盘回廊', 'desc': '把经验上升成可迁移的理解。'},
    {'name': '危机熔炉', 'desc': '把挫折与危机转成成长整合。'},
  ];

  @override
  Widget build(BuildContext context) {
    final unlocked = world?.unlockedNodes.toSet() ?? <String>{'解释风格学院'};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroCard(
          title: '知行域',
          subtitle: '这是课程理论在虚拟世界中的训练空间。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前节点：${world?.currentNode ?? '解释风格学院'}'),
              const SizedBox(height: 8),
              Text(persona == null
                  ? '先建立现实映射档案，系统才会更容易把虚拟场景贴近你的真实问题。'
                  : '系统将优先围绕「${persona!.currentFocus}」和「${persona!.currentProblem.isEmpty ? persona!.growthGoal : persona!.currentProblem}」来推荐训练场景。'),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: onOpenPersona, icon: const Icon(Icons.tune), label: const Text('更新现实映射')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '节点解锁进度',
          subtitle: '知行域不是一次性全开，而是随着学习、行动和复盘逐步解锁。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildWorldUnlockMap(unlocked, actions, reviews).map((step) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (step['unlocked'] == 'true') ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon((step['unlocked'] == 'true') ? Icons.lock_open_outlined : Icons.lock_outline, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(step['body'] ?? ''),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '推荐训练路线',
          subtitle: '按你当前焦点，把课程、知行域和现实行动串成一条主线。',
          child: Builder(builder: (context) {
            final route = _trainingPathForPersona(persona);
            final targetSeg = _segmentByCode(route['segment'] as String);
            final steps = (route['steps'] as List<String>);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(route['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('优先节点：${route['node']}'),
                const SizedBox(height: 8),
                ...steps.map((e) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('• $e'),
                    )),
                if (targetSeg != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => onOpenSegment(targetSeg),
                    icon: const Icon(Icons.alt_route),
                    label: Text('从 ${targetSeg.title} 开始'),
                  ),
                ],
              ],
            );
          }),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '节点任务面板',
          subtitle: '每个节点都对应一类训练主题与现实迁移任务。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildNodeMissions(persona).map((m) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Material(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  title: Text(m['title']!),
                  subtitle: Text(m['desc']!),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpenSegment(_segmentByCode(m['segment']!)!),
                ),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '当前节点剧情树',
          subtitle: '每个节点都按“自动反应 → 重新理解 → 现实迁移”三步训练。',
          child: Builder(builder: (context) {
            final currentNode = world?.currentNode ?? '解释风格学院';
            final steps = _nodeStoryTree(currentNode);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: steps.map((step) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step['title']!, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(step['desc']!),
                    ],
                  ),
                ),
              )).toList(),
            );
          }),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '当前节点分支训练',
          subtitle: '在同一个节点里，也可以按不同问题走不同训练分支。',
          child: Column(
            children: _nodeBranchChoices(world?.currentNode ?? '解释风格学院', persona).map((branch) => Card(
              child: ListTile(
                title: Text(branch['title'] ?? ''),
                subtitle: Text(branch['body'] ?? ''),
                trailing: const Icon(Icons.alt_route_outlined),
                onTap: () {
                  final seg = _segmentByCode(branch['segment'] ?? '');
                  if (seg != null) onOpenSegment(seg);
                },
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '多分支任务树',
          subtitle: '每个节点都不只是一条线，而是围绕不同问题分成几种训练分支。',
          child: Builder(builder: (context) {
            final currentNode = world?.currentNode ?? '解释风格学院';
            final branches = _buildNodeTaskTree(currentNode, persona, actions, reviews);
            return Column(
              children: branches.map((b) => Card(
                child: ListTile(
                  title: Text(b['title'] ?? ''),
                  subtitle: Text(b['body'] ?? ''),
                  trailing: const Icon(Icons.account_tree_outlined),
                  onTap: () {
                    final seg = _segmentByCode(b['segment'] ?? '');
                    if (seg != null) onOpenSegment(seg);
                  },
                ),
              )).toList(),
            );
          }),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '现实联动提示',
          subtitle: '把知行域里的训练拉回行动与复盘，避免只停在虚拟世界。',
          child: Builder(builder: (context) {
            final currentNode = world?.currentNode ?? '解释风格学院';
            final guide = _nodeRealityBridge(currentNode, actions, reviews);
            final seg = _segmentByCode(guide['segment'] ?? '');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guide['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(guide['body'] ?? ''),
                if (seg != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => onOpenSegment(seg),
                    icon: const Icon(Icons.link_outlined),
                    label: Text('去做对应训练：${seg.title}'),
                  ),
                ],
              ],
            );
          }),
        ),
        const SizedBox(height: 12),
        ..._nodeDefs.map((node) {
          final enabled = unlocked.contains(node['name']);
          final related = _segmentsForScene(node['name']!);
          return Card(
            color: enabled ? Colors.white : const Color(0xFFF3F4F6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: enabled ? const Color(0xFFDBEAFE) : const Color(0xFFE5E7EB),
                        child: Icon(enabled ? Icons.public : Icons.lock_outline, color: Colors.black87),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(node['name']!, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(node['desc']!),
                          ],
                        ),
                      ),
                      Icon(enabled ? Icons.check_circle_outline : Icons.lock_outline),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                    child: Text('节点任务：${_nodeMissionSummary(node['name']!, persona)}'),
                  ),
                  if (related.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('绑定段落', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: related.take(4).map((seg) => ActionChip(
                        label: Text('L${seg.lecture}-${seg.indexInLecture}'),
                        onPressed: enabled ? () => onOpenSegment(seg) : null,
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ActionPage extends StatelessWidget {
  final List<PositivePsychAction> actions;
  final ValueChanged<PositivePsychAction> onOpenAction;
  const _ActionPage({required this.actions, required this.onOpenAction});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const Center(child: Text('还没有行动记录。先去课程页打开一个段落，再生成现实行动。'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: actions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final a = actions[i];
        final color = a.status == 'done' ? const Color(0xFFDCFCE7) : a.status == 'doing' ? const Color(0xFFDBEAFE) : Colors.white;
        return Material(
          color: color,
          borderRadius: BorderRadius.circular(18),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text(a.title),
            subtitle: Text('${a.segmentTitle}\n${a.body}', maxLines: 3, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onOpenAction(a),
          ),
        );
      },
    );
  }
}

class _ReviewPage extends StatelessWidget {
  final List<PositivePsychReview> reviews;
  final ValueChanged<PositivePsychReview> onOpenReview;
  final ValueChanged<PositivePsychSegment> onOpenSegment;
  const _ReviewPage({required this.reviews, required this.onOpenReview, required this.onOpenSegment});

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const Center(child: Text('还没有复盘。完成一次行动后，回来把经验写下来。'));
    final groups = _buildReviewBuckets(reviews);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroCard(
          title: '复盘轨迹总览',
          subtitle: '按段落聚合回看，帮助你看到哪些主题已经开始沉淀为经验。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: groups.map((group) {
              final seg = _segmentByCode((group['segmentId'] ?? '').toString());
              final items = group['items'] as List<PositivePsychReview>;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text((group['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
                          Text('${items.length} 条', style: const TextStyle(color: Color(0xFF6B7280))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text((group['summary'] ?? '').toString()),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _reviewTrackForSegment(items).map((e) => Chip(label: Text(e))).toList(),
                      ),
                      if (seg != null) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => onOpenSegment(seg),
                          icon: const Icon(Icons.menu_book_outlined),
                          label: const Text('回到对应段落继续训练'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      ...items.take(3).map((r) => Card(
                        child: ListTile(
                          title: Text(r.result.isEmpty ? r.segmentTitle : r.result, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('事实：${r.fact}\n总结：${r.summary}', maxLines: 4, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => onOpenReview(r),
                        ),
                      )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _GrowthPage extends StatelessWidget {
  final Set<String> done;
  final List<PositivePsychAction> actions;
  final List<PositivePsychReview> reviews;
  final Map<String, String> aiState;
  final PositivePsychPersonaProfile? persona;
  final ValueChanged<PositivePsychSegment> onOpenSegment;
  const _GrowthPage({required this.done, required this.actions, required this.reviews, required this.aiState, required this.persona, required this.onOpenSegment});

  @override
  Widget build(BuildContext context) {
    final lecture7 = done.where((e) => e.startsWith('pp_l7_')).length;
    final lecture8 = done.where((e) => e.startsWith('pp_l8_')).length;
    final lecture9 = done.where((e) => e.startsWith('pp_l9_')).length;
    final doneActions = actions.where((e) => e.status == 'done').length;
    final optimismScore = ((lecture7 / 15) * 100).round();
    final gratitudeScore = ((lecture8 / 12) * 100).round();
    final recoveryScore = (((doneActions + reviews.length) / 12) * 100).clamp(0, 100).round();
    final consistencyScore = actions.isEmpty ? 0 : ((doneActions / actions.length) * 100).round();
    final recommendations = _recommendedSegments(done: done, persona: persona);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroCard(
          title: '成长画像（阶段版）',
          subtitle: '先以行为事实和已完成训练为主，不做病理化判断。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前模型：${aiState['label'] ?? '未配置'}。'),
              const SizedBox(height: 8),
              if (persona != null) Text('当前训练焦点：${persona!.currentFocus} / 偏差：${persona!.biasType}'),
              if (persona != null) const SizedBox(height: 8),
              Text('课程完成：Lecture 7 已学 $lecture7 / 15，Lecture 8 已学 $lecture8 / 12，Lecture 9 已学 $lecture9 / 10。'),
              const SizedBox(height: 8),
              Text('行动推进：共 ${actions.length} 条，完成 $doneActions 条。'),
              const SizedBox(height: 8),
              Text('复盘次数：${reviews.length}。'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _MetricCard(label: '乐观解释倾向', value: '$optimismScore')),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(label: '感恩敏感度', value: '$gratitudeScore')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _MetricCard(label: '恢复与复盘', value: '$recoveryScore')),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(label: '行动一致性', value: '$consistencyScore')),
          ],
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '37 段掌握热力图',
          subtitle: '绿色代表已完成，灰色代表尚未深学。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _lectureHeatRow('Lecture 7', 15, done, 'pp_l7_'),
              const SizedBox(height: 8),
              _lectureHeatRow('Lecture 8', 12, done, 'pp_l8_'),
              const SizedBox(height: 8),
              _lectureHeatRow('Lecture 9', 10, done, 'pp_l9_'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '训练闭环追踪',
          subtitle: '看你目前更偏向停在哪一步。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('课程学习：${done.length} 段已点亮。'),
              const SizedBox(height: 6),
              Text('行动创建：${actions.length} 条。'),
              const SizedBox(height: 6),
              Text('行动完成：$doneActions 条。'),
              const SizedBox(height: 6),
              Text('复盘沉淀：${reviews.length} 条。'),
              const SizedBox(height: 8),
              Text(actions.isEmpty ? '你现在最该补的是：把一段课程真正转成现实行动。' : reviews.length < doneActions ? '你现在最该补的是：完成行动后及时复盘，把经验升成理解。' : '你已经开始形成闭环，下一步建议把训练迁移到更真实、更困难的场景。'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '训练路径推荐',
          subtitle: '把下一轮训练拆成更容易执行的连续路径。',
          child: Builder(builder: (context) {
            final route = _trainingPathForPersona(persona);
            final steps = (route['steps'] as List<String>);
            final targetSeg = _segmentByCode(route['segment'] as String);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(route['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...steps.map((e) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('• $e'),
                    )),
                if (targetSeg != null) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => onOpenSegment(targetSeg),
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text('打开推荐起点：${targetSeg.title}'),
                  ),
                ],
              ],
            );
          }),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '阶段任务系统',
          subtitle: '把下一轮训练拆成阶段任务，而不是只给一个建议。',
          child: Column(
            children: _buildStageMissions(done: done, actions: actions, reviews: reviews, persona: persona).map((mission) => Card(
              child: ListTile(
                title: Text(mission['title'] ?? ''),
                subtitle: Text(mission['body'] ?? ''),
                trailing: const Icon(Icons.route_outlined),
                onTap: () {
                  final seg = _segmentByCode(mission['segment'] ?? '');
                  if (seg != null) onOpenSegment(seg);
                },
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '阶段里程碑地图',
          subtitle: '把训练拆成看得见的阶段，不只知道下一步，还知道自己到了哪一步。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildStageMap(done: done, actions: actions, reviews: reviews).map((milestone) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (milestone['done'] == 'true') ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon((milestone['done'] == 'true') ? Icons.check_circle : Icons.radio_button_unchecked, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(milestone['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(milestone['body'] ?? ''),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '阶段解锁机制',
          subtitle: '每做完一层，就解锁更真实、更复杂的一层训练。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildUnlockLadder(done: done, actions: actions, reviews: reviews, persona: persona).map((step) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (step['ready'] == 'true') ? const Color(0xFFDBEAFE) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(step['body'] ?? ''),
                    const SizedBox(height: 6),
                    Text('解锁条件：${step['gate'] ?? ''}', style: const TextStyle(color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '训练路线解锁图',
          subtitle: '把课程—知行域—行动—复盘串成一条连续路线，而不是零散完成。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildTrainingRouteMap(done: done, actions: actions, reviews: reviews, persona: persona).map((step) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (step['active'] == 'true') ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(step['body'] ?? ''),
                    const SizedBox(height: 6),
                    Text('当前状态：${step['state'] ?? ''}', style: const TextStyle(color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: '下一轮建议',
          subtitle: '按你的当前焦点、偏差和未完成进度做优先推荐。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: recommendations.isEmpty
                ? const [Text('37 段都已学习过。现在建议回到现实行动与复盘，做第二轮深化。')]
                : recommendations.map((seg) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(seg.title),
                      subtitle: Text(seg.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onOpenSegment(seg),
                    ),
                  )).toList(),
          ),
        ),
      ],
    );
  }
}

class PositivePsychSegmentDetailPage extends StatelessWidget {
  final PositivePsychSegment segment;
  final PositivePsychAiService ai;
  final ValueChanged<PositivePsychAction> onSaveAction;
  final ValueChanged<PositivePsychReview> onSaveReview;
  const PositivePsychSegmentDetailPage({super.key, required this.segment, required this.ai, required this.onSaveAction, required this.onSaveReview});

  Future<void> _generateActions(BuildContext context) async {
    final ctrl = TextEditingController();
    final concern = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('你的当前困扰'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '例如：我最近总因为工作中的小失误否定自己',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, ''), child: const Text('跳过')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()), child: const Text('生成行动')),
        ],
      ),
    );
    if (!context.mounted) return;
    final result = await ai.generateActionOptions(segment: segment, userConcern: concern ?? '');
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('行动建议 · ${result.modelLabel}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...result.actions.map((a) => Card(
                    child: ListTile(
                      title: Text(a.title),
                      subtitle: Text(a.body, maxLines: 4, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onSaveAction(a);
                      },
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openScene(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PositivePsychScenePage(segment: segment)));
  }

  Future<void> _quickReview(BuildContext context) async {
    final fact = TextEditingController();
    final thought = TextEditingController();
    final feeling = TextEditingController();
    final action = TextEditingController();
    final result = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _input('事实', fact),
              const SizedBox(height: 8),
              _input('想法', thought),
              const SizedBox(height: 8),
              _input('感受', feeling),
              const SizedBox(height: 8),
              _input('行动', action),
              const SizedBox(height: 8),
              _input('结果', result),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final review = PositivePsychReview(
                    id: 'ppr_${DateTime.now().millisecondsSinceEpoch}',
                    segmentId: segment.id,
                    segmentTitle: segment.title,
                    fact: fact.text.trim(),
                    thought: thought.text.trim(),
                    feeling: feeling.text.trim(),
                    action: action.text.trim(),
                    result: result.text.trim(),
                    summary: ai.buildReviewSummary(segment: segment, fact: fact.text.trim(), thought: thought.text.trim(), feeling: feeling.text.trim(), action: action.text.trim(), result: result.text.trim()),
                    createdAt: DateTime.now().millisecondsSinceEpoch,
                  );
                  Navigator.pop(sheetContext);
                  onSaveReview(review);
                },
                child: const Text('保存复盘'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(segment.title)),
      backgroundColor: const Color(0xFFF5F6FA),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroCard(title: '原文与课程内容', subtitle: segment.subtitle, child: Text(segment.originalText, style: const TextStyle(height: 1.6))),
          const SizedBox(height: 12),
          _HeroCard(
            title: '核心概念',
            subtitle: '每段至少提炼多个核心概念，并回到直观经验。',
            child: Wrap(spacing: 8, runSpacing: 8, children: segment.concepts.map((e) => Chip(label: Text(e))).toList()),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '深度理解',
            subtitle: '是什么 / 为什么 / 怎样做 / 案例',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('是什么：${segment.whatText}'),
                const SizedBox(height: 8),
                Text('为什么：${segment.whyText}'),
                const SizedBox(height: 8),
                const Text('怎样做：', style: TextStyle(fontWeight: FontWeight.w700)),
                ...segment.howSteps.map((e) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('• '), Expanded(child: Text(e))]),
                    )),
                const SizedBox(height: 10),
                const Text('案例：', style: TextStyle(fontWeight: FontWeight.w700)),
                ...segment.cases.map((e) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('• $e'),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '概念落地',
            subtitle: '把抽象概念落到经验直观。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: segment.concepts.map((c) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• $c：${_conceptHint(c)}'),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '适用问题与现实场景',
            subtitle: '判断这段内容什么时候最值得拿出来用。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _segmentApplicationScenarios(segment).map((e) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• $e'),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '训练教练提示',
            subtitle: '把这段内容和你眼下最真实的问题对上。',
            child: Text(ai.buildCoachNote(segment)),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '默认现实动作',
            subtitle: '这是本段最小可执行版本。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(segment.defaultActionTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(segment.defaultActionBody),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '行为链执行器',
            subtitle: '把本段概念压缩成可以立即落地的一条执行链。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('触发条件：当你再次遇到与「${segment.title}」相关的真实情境时。'),
                const SizedBox(height: 6),
                Text('最小动作：先完成 ${segment.howSteps.isNotEmpty ? segment.howSteps.first : '一个最小观察动作'}。'),
                const SizedBox(height: 6),
                Text('证据记录：至少留下 1 条事实记录，而不是只写感受。'),
                const SizedBox(height: 6),
                Text('回退动作：如果卡住，就只做第一步，然后当天补一个更完整解释。'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '多行动模板',
            subtitle: '每段至少一个行动，这里提供最小 / 标准 / 挑战三个版本。',
            child: Column(
              children: ai.previewActionOptions(segment: segment).map((a) => Card(
                child: ListTile(
                  title: Text(a.title),
                  subtitle: Text(a.body, maxLines: 3, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.add_task),
                  onTap: () => onSaveAction(a),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '行为链模板',
            subtitle: '从触发条件到记录复盘，把概念落实到经验。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _behaviorChainForSegment(segment).map((e) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• $e'),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '知行域绑定',
            subtitle: '这一段在虚拟世界和现实世界中的落点。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前节点：${segment.scene}'),
                const SizedBox(height: 8),
                Text('关联主题：${segment.concepts.join('、')}'),
                const SizedBox(height: 8),
                Text('现实落点：${segment.defaultActionTitle}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '现实联动提示',
            subtitle: '不要只停在理解或场景预演，要把它拉回现实闭环。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _segmentRealityLinkTips(segment).map((e) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• $e'),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '专属训练路径',
            subtitle: '把本段内容接到虚拟操练与现实落地。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _segmentTrainingPath(segment).map((e) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• $e'),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '段落级专属训练模板',
            subtitle: '这不是通用鸡汤，而是把本段内容压成几个可执行动作。',
            child: Column(
              children: _segmentSpecificPracticeCards(segment).map((item) => Card(
                child: ListTile(
                  title: Text(item['title'] ?? ''),
                  subtitle: Text(item['body'] ?? ''),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '训练入口',
            subtitle: '理论—虚拟操练—现实行动—复盘闭环',
            child: Column(
              children: [
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _generateActions(context), icon: const Icon(Icons.task_alt), label: const Text('生成现实行动'))),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _openScene(context), icon: const Icon(Icons.public), label: Text('进入虚拟场景：${segment.scene}'))),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _quickReview(context), icon: const Icon(Icons.rate_review_outlined), label: const Text('直接写一条复盘'))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PositivePsychScenePage extends StatefulWidget {
  final PositivePsychSegment segment;
  const PositivePsychScenePage({super.key, required this.segment});

  @override
  State<PositivePsychScenePage> createState() => _PositivePsychScenePageState();
}

class _PositivePsychScenePageState extends State<PositivePsychScenePage> {
  String _feedback = '你现在进入了一个用于训练课程概念的虚拟场景。请选择一条最接近你当前风格的路径。';
  int _stage = 1;

  void _choose(String type) {
    final seg = widget.segment;
    if (_stage == 1) {
      if (type == 'problem') {
        _feedback = '第一步里你选择了只盯着问题。世界会变窄，注意力更容易锁死在威胁、失败或自责上。';
      } else if (type == 'resource') {
        _feedback = '第一步里你选择了只看资源。你会舒服一点，但如果跳过真实困难，训练会停留在表面。';
      } else {
        _feedback = '第一步里你选择了完整现实。你开始同时看见问题和资源，这会为下一步行动留下空间。';
      }
      _stage = 2;
    } else {
      if (type == 'problem') {
        _feedback = '第二步里你继续留在旧模式中，于是剧情卡在解释层。课程提醒你：${seg.whyText}';
      } else if (type == 'resource') {
        _feedback = '第二步里你试图安慰自己，但仍缺少真实行动。现在最需要的是把理解转成一个可执行动作。';
      } else {
        _feedback = '第二步里你把完整现实推进成了下一步行动。现实交接任务已经出现：${seg.defaultActionTitle}。请把它带回现实，然后再回来复盘。';
      }
      _stage = 3;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.segment.scene)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroCard(title: '场景任务', subtitle: widget.segment.title, child: Text('场景目标：${_sceneMissionText(widget.segment)}')),
          const SizedBox(height: 12),
          _HeroCard(
            title: '节点剧情脚本',
            subtitle: '先在虚拟世界里把课程逻辑走一遍，再带回现实。',
            child: Column(
              children: _sceneEpisodes(widget.segment).map((e) => Card(
                child: ListTile(
                  title: Text(e['title'] ?? ''),
                  subtitle: Text(e['body'] ?? ''),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '场景校准提示',
            subtitle: '先在虚拟世界里练习完整现实，再把它迁移到现实情境。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('先分清：事实是什么、自动解释是什么、你真正能做的下一步是什么。'),
                const SizedBox(height: 8),
                Text('如果你发现自己只盯着威胁，说明可能正在收窄现实。'),
                const SizedBox(height: 8),
                Text('如果你只想赶快安慰自己，也要记得把行动补上。'),
                const SizedBox(height: 8),
                Text('最理想的路径是：承认问题，同时看见资源，再推进一个现实动作。'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '场景训练检查点',
            subtitle: '做的过程中，随时用这几个检查点避免重新滑回自动反应。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildSceneCheckpoints(widget.segment, _stage).map((item) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• $item'),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_stage == 1 ? '第一步：你现在最容易如何理解这个情境？' : _stage == 2 ? '第二步：接下来你会如何回应？' : '现实交接：带着一个行动返回现实。', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (_stage < 3) ...[
                    SizedBox(width: double.infinity, child: FilledButton(onPressed: () => _choose('problem'), child: Text(_stage == 1 ? '只盯着问题 / 缺点 / 威胁' : '继续解释、继续卡住'))),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => _choose('resource'), child: Text(_stage == 1 ? '只看资源 / 安慰 / 好处' : '先安慰自己，但还不行动'))),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => _choose('full'), child: Text(_stage == 1 ? '同时看见问题与资源，并决定下一步' : '把理解推进成一个现实动作'))),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)),
                      child: Text('现实任务：${widget.segment.defaultActionTitle}\n${widget.segment.defaultActionBody}'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(title: '场景反馈', subtitle: '这一轮先做成两步式剧情操练，重点是把解释与回应分开训练。', child: Text(_feedback)),
        ],
      ),
    );
  }
}

class PositivePsychActionDetailPage extends StatefulWidget {
  final PositivePsychAction action;
  final PositivePsychSegment? segment;
  final ValueChanged<PositivePsychAction> onSave;
  final ValueChanged<PositivePsychReview> onSaveReview;
  final PositivePsychAiService ai;
  const PositivePsychActionDetailPage({super.key, required this.action, required this.segment, required this.onSave, required this.onSaveReview, required this.ai});

  @override
  State<PositivePsychActionDetailPage> createState() => _PositivePsychActionDetailPageState();
}

class _PositivePsychActionDetailPageState extends State<PositivePsychActionDetailPage> {
  late TextEditingController _factCtrl;
  late TextEditingController _obstacleCtrl;
  late TextEditingController _nextCtrl;
  late String _status;

  @override
  void initState() {
    super.initState();
    _factCtrl = TextEditingController(text: widget.action.factLog);
    _obstacleCtrl = TextEditingController(text: widget.action.obstacleNote);
    _nextCtrl = TextEditingController(text: widget.action.nextStepNote);
    _status = widget.action.status;
  }

  Future<void> _save() async {
    final updated = widget.action.copyWith(status: _status, factLog: _factCtrl.text.trim(), obstacleNote: _obstacleCtrl.text.trim(), nextStepNote: _nextCtrl.text.trim());
    await Future<void>.sync(() => widget.onSave(updated));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('行动已更新')));
  }

  Future<void> _openReview() async {
    final seg = widget.segment;
    if (seg == null) return;
    final thought = TextEditingController();
    final feeling = TextEditingController();
    final result = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _input('这次事件里，我当时怎么想？', thought),
              const SizedBox(height: 8),
              _input('我当时感觉如何？', feeling),
              const SizedBox(height: 8),
              _input('结果如何？', result),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final review = PositivePsychReview(
                    id: 'ppr_${DateTime.now().millisecondsSinceEpoch}',
                    segmentId: seg.id,
                    segmentTitle: seg.title,
                    fact: _factCtrl.text.trim(),
                    thought: thought.text.trim(),
                    feeling: feeling.text.trim(),
                    action: widget.action.title,
                    result: result.text.trim(),
                    summary: widget.ai.buildReviewSummary(segment: seg, fact: _factCtrl.text.trim(), thought: thought.text.trim(), feeling: feeling.text.trim(), action: widget.action.title, result: result.text.trim()),
                    createdAt: DateTime.now().millisecondsSinceEpoch,
                  );
                  Navigator.pop(sheetContext);
                  widget.onSaveReview(review);
                },
                child: const Text('保存这次复盘'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.action.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroCard(title: widget.action.segmentTitle, subtitle: '现实行动详情', child: Text(widget.action.body)),
          const SizedBox(height: 12),
          _HeroCard(
            title: '行为链',
            subtitle: '把概念落实成步骤。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...widget.action.steps.map((e) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('• '), Expanded(child: Text(e))]),
                    )),
                const SizedBox(height: 10),
                Text('成功标准：${widget.action.successCriteria}'),
                const SizedBox(height: 6),
                Text('卡住时的回退动作：${widget.action.fallbackAction}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '执行中引导',
            subtitle: '执行时不要只看结果，先照着行为链过一遍。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildActionExecutionGuide(widget.action, widget.segment).map((item) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• $item'),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '证据记录器',
            subtitle: '把行动留下证据，帮助自己从“感觉做了”走向“知道做了什么”。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildEvidenceChecklist(widget.action, widget.segment).map((item) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• $item'),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '执行表单进度',
            subtitle: '不是填得越多越好，而是让执行过程留下清晰证据。',
            child: Builder(builder: (context) {
              final completedCount = <bool>[
                _status == 'done',
                _factCtrl.text.trim().isNotEmpty,
                _obstacleCtrl.text.trim().isNotEmpty,
                _nextCtrl.text.trim().isNotEmpty,
              ].where((e) => e).length;
              final progress = completedCount / 4;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('当前进度：$completedCount / 4。建议至少完成状态、事实记录和下一步。'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('填入事实模板'),
                        onPressed: () => setState(() => _factCtrl.text = _factCtrl.text.trim().isEmpty ? '时间 / 场景 / 我实际做了什么：' : _factCtrl.text),
                      ),
                      ActionChip(
                        label: const Text('填入障碍模板'),
                        onPressed: () => setState(() => _obstacleCtrl.text = _obstacleCtrl.text.trim().isEmpty ? '我卡住在：\n触发我的自动想法是：' : _obstacleCtrl.text),
                      ),
                      ActionChip(
                        label: const Text('填入下一步模板'),
                        onPressed: () => setState(() => _nextCtrl.text = _nextCtrl.text.trim().isEmpty ? '下一次我先做的最小动作是：' : _nextCtrl.text),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '结构化复盘提示',
            subtitle: '先把事实、解释、情绪、行动和结果分开，再去看偏差。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.ai.buildReviewQuestions(
                segment: widget.segment ?? _segmentByCode(widget.action.segmentId) ?? positivePsychSegments.first,
                fact: _factCtrl.text,
                thought: _obstacleCtrl.text.isEmpty ? _nextCtrl.text : _obstacleCtrl.text,
              ).map((q) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• $q'),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '3M 检查与替代解释',
            subtitle: '检查这次行动里，你是否又掉回了夸大、缩小或编造式推断。',
            child: Builder(builder: (context) {
              final thoughtText = _obstacleCtrl.text.isEmpty ? _nextCtrl.text : _obstacleCtrl.text;
              final tags = widget.ai.detectBiasTags(thoughtText);
              final alt = widget.segment == null
                  ? '先分清事实、解释、情绪和下一步动作。'
                  : widget.ai.buildAlternativeInterpretation(
                      segment: widget.segment!,
                      fact: _factCtrl.text,
                      thought: thoughtText,
                      feeling: '',
                    );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tags.isEmpty ? '暂未识别出明显 3M 线索。' : '当前可能出现的偏差：${tags.join('、')}'),
                  const SizedBox(height: 8),
                  Text('替代解释：$alt'),
                  const SizedBox(height: 8),
                  Text('复盘提示：${widget.action.reviewQuestion}'),
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('执行记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'todo', label: Text('待做')),
                      ButtonSegment(value: 'doing', label: Text('进行中')),
                      ButtonSegment(value: 'done', label: Text('已完成')),
                    ],
                    selected: <String>{_status},
                    onSelectionChanged: (s) => setState(() => _status = s.first),
                  ),
                  const SizedBox(height: 10),
                  _input('事实记录：发生了什么？我实际做了什么？', _factCtrl),
                  const SizedBox(height: 8),
                  _input('障碍记录：哪里卡住了？', _obstacleCtrl),
                  const SizedBox(height: 8),
                  _input('下一步：下一次准备怎么做？', _nextCtrl),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(onPressed: _save, child: const Text('保存行动')),
                      OutlinedButton(onPressed: _openReview, child: const Text('基于这次行动写复盘')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '迁移到下一轮',
            subtitle: '别把这次行动只当成一次完成，而要把它迁移到下一次真实场景。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildNextMigrationHints(widget.action, widget.segment).map((item) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• $item'),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}



class PositivePsychReviewDetailPage extends StatelessWidget {
  final PositivePsychReview review;
  final PositivePsychSegment? segment;
  final PositivePsychAiService ai;
  final VoidCallback? onOpenSegment;
  const PositivePsychReviewDetailPage({super.key, required this.review, required this.segment, required this.ai, this.onOpenSegment});

  @override
  Widget build(BuildContext context) {
    final tags = ai.detectBiasTags(review.thought);
    final alt = segment == null
        ? '先把事实、解释、情绪和行动分开，再写一个更完整版本。'
        : ai.buildAlternativeInterpretation(segment: segment!, fact: review.fact, thought: review.thought, feeling: review.feeling);
    return Scaffold(
      appBar: AppBar(title: const Text('复盘详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroCard(title: review.segmentTitle, subtitle: '把一次经验沉淀成可迁移理解', child: Text(review.summary)),
          const SizedBox(height: 12),
          _HeroCard(
            title: '复盘结构',
            subtitle: '先还原事实，再看解释与偏差。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('事实：${review.fact}'),
                const SizedBox(height: 6),
                Text('想法：${review.thought}'),
                const SizedBox(height: 6),
                Text('情绪：${review.feeling}'),
                const SizedBox(height: 6),
                Text('行动：${review.action}'),
                const SizedBox(height: 6),
                Text('结果：${review.result}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '3M 检查',
            subtitle: tags.isEmpty ? '本次没有明显识别到 3M 线索。' : '识别到：${tags.join('、')}',
            child: Text('替代解释：$alt'),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            title: '下一轮迁移',
            subtitle: '不要只停留在理解，给下一次留下一个动作。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...ai.buildReviewQuestions(segment: segment ?? positivePsychSegments.first, fact: review.fact, thought: review.thought).take(4).map((q) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('• $q'),
                    )),
                if (onOpenSegment != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: onOpenSegment, icon: const Icon(Icons.menu_book_outlined), label: const Text('回到对应段落继续训练')),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}


List<Map<String, String>> _buildStageMissions({
  required Set<String> done,
  required List<PositivePsychAction> actions,
  required List<PositivePsychReview> reviews,
  required PositivePsychPersonaProfile? persona,
}) {
  final route = _trainingPathForPersona(persona);
  final doneActions = actions.where((e) => e.status == 'done').length;
  final cards = <Map<String, String>>[];
  if (done.length < 10) {
    cards.add({
      'title': '阶段 1｜先建立概念地图',
      'body': '先完成 8-10 段基础学习，尤其优先补 ${route['segment']} 对应的主题，让后面的行动与复盘有抓手。',
      'segment': '${route['segment']}',
    });
  }
  if (actions.isEmpty) {
    cards.add({
      'title': '阶段 2｜把一个概念压成现实动作',
      'body': '你现在最需要的不是再看更多内容，而是从推荐段落里挑一个最小动作，真正开始一次现实验证。',
      'segment': '${route['segment']}',
    });
  } else if (doneActions < actions.length) {
    cards.add({
      'title': '阶段 2｜把已创建行动真正做完',
      'body': '你已经进入行动阶段，但还有动作停留在待做或进行中。优先把未完成动作推进到事实记录。',
      'segment': '${route['segment']}',
    });
  }
  if (reviews.length < doneActions) {
    cards.add({
      'title': '阶段 3｜把经验升成理解',
      'body': '你已经在做行动，但复盘次数还不够。每完成一次动作，就立刻做一次 3M 检查和替代解释。',
      'segment': 'pp_l7_8',
    });
  }
  cards.add({
    'title': '阶段 4｜进入下一轮迁移',
    'body': '把当前最稳的一次训练，迁移到更真实或更困难的场景里，形成第二轮知行合一。',
    'segment': '${route['segment']}',
  });
  return cards;
}

List<Map<String, String>> _nodeBranchChoices(String node, PositivePsychPersonaProfile? persona) {
  final focus = persona?.currentFocus ?? '当前生活';
  switch (node) {
    case '解释风格学院':
      return <Map<String, String>>[
        {'title': '分支 A｜失败后不把自己整体否定', 'body': '适合在 $focus 中一出错就全盘否定自己的时候使用。', 'segment': 'pp_l7_7'},
        {'title': '分支 B｜先分清事实和解释', 'body': '适合自动想法很快、情绪一下子冲上来的时候。', 'segment': 'pp_l7_1'},
      ];
    case '行动工坊':
      return <Map<String, String>>[
        {'title': '分支 A｜从最小动作开始', 'body': '适合总在想，但迟迟不开始的人。', 'segment': 'pp_l7_2'},
        {'title': '分支 B｜用预演降低启动阻力', 'body': '适合明知该做，却总在真实场景前退缩的人。', 'segment': 'pp_l7_5'},
      ];
    case '感恩花园':
      return <Map<String, String>>[
        {'title': '分支 A｜从理所当然里重新看见价值', 'body': '适合关系、资源和日常美好正在被忽略的时候。', 'segment': 'pp_l8_9'},
        {'title': '分支 B｜把感谢说具体', 'body': '适合想修复连接、表达珍惜的时候。', 'segment': 'pp_l9_4'},
      ];
    case '复盘回廊':
      return <Map<String, String>>[
        {'title': '分支 A｜检查 3M 偏差', 'body': '适合行动后脑中还在自动下结论的时候。', 'segment': 'pp_l7_8'},
        {'title': '分支 B｜把积极与消极体验分开处理', 'body': '适合同一段经历里既有痛苦又有值得重温的部分。', 'segment': 'pp_l9_6'},
      ];
    default:
      return <Map<String, String>>[
        {'title': '分支 A｜先练完整现实', 'body': '适合只盯着单一面向时使用。', 'segment': 'pp_l9_1'},
        {'title': '分支 B｜先补一个现实动作', 'body': '适合理解很多但迟迟不做的时候。', 'segment': 'pp_l7_2'},
      ];
  }
}


List<String> _buildSceneCheckpoints(PositivePsychSegment segment, int stage) {
  final base = <String>[
    '先提醒自己：这个场景是拿来训练理解与回应的，不是拿来证明你是否完美。',
    '只要能把事实、解释和下一步分开，就已经在推进训练。',
  ];
  if (stage == 1) {
    base.add('第一步只问自己：我现在最自然的自动解释是什么？');
  } else if (stage == 2) {
    base.add('第二步开始补完整现实：问题是什么、资源是什么、下一步是什么。');
  } else {
    base.add('第三步别停在场景里，直接把「${segment.defaultActionTitle}」迁移回现实。');
  }
  return base;
}

List<Map<String, Object>> _buildReviewBuckets(List<PositivePsychReview> reviews) {
  final map = <String, List<PositivePsychReview>>{};
  for (final review in reviews) {
    map.putIfAbsent(review.segmentId, () => <PositivePsychReview>[]).add(review);
  }
  final entries = map.entries.map((entry) {
    final items = [...entry.value]..sort((a,b)=>b.createdAt.compareTo(a.createdAt));
    return <String, Object>{
      'segmentId': entry.key,
      'title': items.first.segmentTitle,
      'summary': '最近一次复盘：${items.first.summary}',
      'items': items,
    };
  }).toList();
  entries.sort((a,b) => ((b['items'] as List<PositivePsychReview>).first.createdAt).compareTo(((a['items'] as List<PositivePsychReview>).first.createdAt)));
  return entries;
}

List<String> _reviewTrackForSegment(List<PositivePsychReview> reviews) {
  final tags = <String>{};
  for (final review in reviews) {
    if (review.fact.isNotEmpty) tags.add('有事实记录');
    if (review.summary.isNotEmpty) tags.add('有复盘总结');
    if (review.thought.isNotEmpty) tags.add('有自动想法');
    if (review.result.isNotEmpty) tags.add('有结果回看');
  }
  if (reviews.length >= 2) tags.add('已形成连续样本');
  return tags.toList();
}

List<Map<String, String>> _buildNodeTaskTree(String node, PositivePsychPersonaProfile? persona, List<PositivePsychAction> actions, List<PositivePsychReview> reviews) {
  final hasDoneAction = actions.any((e) => e.status == 'done');
  final hasReview = reviews.isNotEmpty;
  final base = _nodeBranchChoices(node, persona);
  return <Map<String, String>>[
    {
      'title': '分支 1｜概念识别',
      'body': '先在当前节点识别自动解释或注意力偏差，别急着进入评价。',
      'segment': base.first['segment'] ?? 'pp_l7_1',
    },
    {
      'title': '分支 2｜现实动作压缩',
      'body': hasDoneAction ? '你已经有完成动作的经验，可以把当前节点训练迁移到更真实的场景。' : '把当前节点的理解压成一个最小动作，避免停在理解层。',
      'segment': base.length > 1 ? base[1]['segment'] ?? 'pp_l7_2' : 'pp_l7_2',
    },
    {
      'title': '分支 3｜复盘与迁移',
      'body': hasReview ? '你已经有复盘样本，下一步是把有效做法迁移到下一轮。' : '动作之后立刻进入复盘，检查 3M 并补替代解释。',
      'segment': node == '感恩花园' ? 'pp_l9_6' : 'pp_l7_8',
    },
  ];
}

List<Map<String, String>> _buildTrainingRouteMap({
  required Set<String> done,
  required List<PositivePsychAction> actions,
  required List<PositivePsychReview> reviews,
  required PositivePsychPersonaProfile? persona,
}) {
  final route = _trainingPathForPersona(persona);
  final doneActions = actions.where((e) => e.status == 'done').length;
  return <Map<String, String>>[
    {
      'title': '路线 1｜点亮起点段落',
      'body': '先完成推荐起点段落，建立本轮训练的概念抓手。',
      'state': done.contains(route['segment']) ? '已点亮' : '待点亮',
      'active': (!done.contains(route['segment'])).toString(),
    },
    {
      'title': '路线 2｜进入知行域节点',
      'body': '带着当前问题进入对应节点，完成一次自动反应 → 重新理解的训练。',
      'state': done.isNotEmpty ? '可进入' : '先补课程',
      'active': (done.isNotEmpty && actions.isEmpty).toString(),
    },
    {
      'title': '路线 3｜完成现实动作与证据',
      'body': '把节点训练压成现实动作，并留下事实证据。',
      'state': doneActions > 0 ? '已有证据' : '待完成',
      'active': (actions.isNotEmpty && doneActions == 0).toString(),
    },
    {
      'title': '路线 4｜进入复盘与迁移',
      'body': '完成 3M 检查与替代解释，再把有效做法迁移到下一轮。',
      'state': reviews.isNotEmpty ? '已进入复盘' : '待进入',
      'active': (doneActions > 0 && reviews.isEmpty).toString(),
    },
  ];
}

List<String> _buildActionExecutionGuide(PositivePsychAction action, PositivePsychSegment? segment) {
  final segTitle = segment?.title ?? action.segmentTitle;
  return <String>[
    '开始前先提醒自己：这次不是证明我行不行，而是围绕「$segTitle」做一次训练。',
    '执行时先完成最小动作，不要一上来就要求完整、漂亮、彻底。',
    '中途卡住时，不要直接判定失败，先启用回退动作：${action.fallbackAction}',
    '一做完就立刻写事实记录，先写发生了什么，再写你怎么解释它。',
    '如果情绪很大，先做 3M 检查，再决定下一步，而不是直接给自己下结论。',
  ];
}

List<Map<String, String>> _nodeStoryTree(String node) {
  switch (node) {
    case '解释风格学院':
      return <Map<String, String>>[
        {'title': '步骤 1｜自动反应出现', 'desc': '你先注意到自己已经把一次小事件解释成更大的失败。'},
        {'title': '步骤 2｜重新理解', 'desc': '把事实、解释和情绪分开，尝试补一个更完整的解释。'},
        {'title': '步骤 3｜现实迁移', 'desc': '回到现实中做一次“事实-解释分栏”记录。'},
      ];
    case '行动工坊':
      return <Map<String, String>>[
        {'title': '步骤 1｜概念落地', 'desc': '把抽象道理压缩成一个最小动作，而不是继续想。'},
        {'title': '步骤 2｜执行预演', 'desc': '先预演什么时候做、做第一步是什么、卡住了怎么办。'},
        {'title': '步骤 3｜现实迁移', 'desc': '当天完成一次最小动作，并留下事实记录。'},
      ];
    case '感恩花园':
      return <Map<String, String>>[
        {'title': '步骤 1｜发现理所当然', 'desc': '先看见你平时最容易忽略的人、关系或片刻。'},
        {'title': '步骤 2｜具体表达', 'desc': '把感谢说具体，而不是停在抽象感谢。'},
        {'title': '步骤 3｜现实迁移', 'desc': '完成一条具体感恩表达或一次积极体验重温。'},
      ];
    case '复盘回廊':
      return <Map<String, String>>[
        {'title': '步骤 1｜还原经历', 'desc': '先把事实、解释、情绪、行动拆开，不混成一团。'},
        {'title': '步骤 2｜检查 3M', 'desc': '确认自己是不是在夸大、缩小或编造式推断。'},
        {'title': '步骤 3｜现实迁移', 'desc': '写下下一轮要保留的一个动作，而不是只做总结。'},
      ];
    default:
      return <Map<String, String>>[
        {'title': '步骤 1｜看见自动反应', 'desc': '先看见自己默认会怎么解释或回应。'},
        {'title': '步骤 2｜补一个更完整版本', 'desc': '尝试同时容纳问题、资源和行动空间。'},
        {'title': '步骤 3｜现实迁移', 'desc': '把新理解变成一个最小现实动作。'},
      ];
  }
}

Map<String, Object> _trainingPathForPersona(PositivePsychPersonaProfile? persona) {
  final focus = persona?.currentFocus ?? '工作与学习';
  final bias = persona?.biasType ?? 'mixed';
  if (bias == 'Magnifying') {
    return <String, Object>{
      'title': '先校准解释，再恢复行动空间',
      'node': '解释风格学院',
      'segment': 'pp_l7_7',
      'steps': <String>['先识别自己是否把一次事件夸大成整体失败。', '在知行域里先走“完整现实”路线，而不是继续自责。', '回到现实后，完成一次 3M 检查并补一个替代解释。'],
    };
  }
  if (bias == 'Minimizing') {
    return <String, Object>{
      'title': '同时看见问题与资源，恢复平衡注意力',
      'node': '感恩花园',
      'segment': 'pp_l8_4',
      'steps': <String>['先承认你正在忽略什么积极面。', '在知行域里练习从理所当然里重新看见价值。', '回到现实后，对一个人或一件事做具体欣赏表达。'],
    };
  }
  if (bias == 'Making up') {
    return <String, Object>{
      'title': '分清事实、推断和情绪，再做行动判断',
      'node': '真实之镜',
      'segment': 'pp_l7_6',
      'steps': <String>['先把事件、解释、情绪、行动拆开。', '在知行域里体验从感受跳到结论会怎样扭曲现实。', '回到现实后写出一个更完整、更有证据的解释。'],
    };
  }
  if (focus.contains('关系')) {
    return <String, Object>{
      'title': '从关系中的忽略与理所当然，走向表达与连接',
      'node': '感恩花园',
      'segment': 'pp_l9_4',
      'steps': <String>['先识别一个你已经习惯忽略其价值的人。', '进入感恩花园完成一次具体感谢的预演。', '回到现实里发出一条具体而真实的感谢表达。'],
    };
  }
  if (focus.contains('情绪')) {
    return <String, Object>{
      'title': '把情绪波动变成恢复训练，而不是自我否定',
      'node': '复盘回廊',
      'segment': 'pp_l7_9',
      'steps': <String>['先记录一次情绪起伏后的自动解释。', '在复盘回廊练习更快恢复，而不是要求自己不难受。', '回到现实后完成一次复盘，比较恢复前后的差异。'],
    };
  }
  return <String, Object>{
    'title': '从课程理解走向现实训练的基础路径',
    'node': '行动工坊',
    'segment': 'pp_l7_2',
    'steps': <String>['先选一个最小可执行动作。', '在知行域里练习如何把理解推进成行为。', '回到现实里完成记录、复盘和下一步安排。'],
  };
}

String _nodeMissionSummary(String node, PositivePsychPersonaProfile? persona) {
  final focus = persona?.currentFocus ?? '当前生活';
  switch (node) {
    case '解释风格学院':
      return '围绕 $focus，训练“先看事实，再看解释”的基本能力。';
    case '失败训练营':
      return '把最近一次挫折变成训练样本，避免一失败就停住。';
    case '行动工坊':
      return '把抽象概念压缩成最小动作，并安排现实执行。';
    case '感恩花园':
      return '练习从理所当然里重新看见价值，并做一次具体表达。';
    case '真实之镜':
      return '同时写下问题与资源，避免只看一半现实。';
    case '复盘回廊':
      return '把一次行动后的经验沉淀成可迁移理解。';
    case '危机熔炉':
      return '把危机视为整合训练，而不是单纯挫败。';
  }
  return '把课程内容变成一个现实训练任务。';
}

List<String> _segmentTrainingPath(PositivePsychSegment segment) {
  return <String>[
    '先读原文，抓住这段最核心的概念：${segment.concepts.take(2).join('、')}。',
    '进入虚拟场景「${segment.scene}」，先体验不同解释或回应会怎样改变后续路径。',
    '从多行动模板里选一个最小版或标准版动作，立即带回现实。',
    '行动后做 3M 检查，再写一个更完整的替代解释。',
    '把这次经验沉淀成下一轮更稳定的行为链。',
  ];
}

List<String> _segmentApplicationScenarios(PositivePsychSegment segment) {
  final items = <String>[
    '当你在现实里再次遇到与「${segment.title}」相关的情境时，可以先用这段做观察框架。',
    '最适合拿来处理“自动反应太快、但又想更清楚地理解自己”的时刻。',
  ];
  if (segment.lecture == 7) {
    items.add('常见于失败、自责、拖延、担心做不好、对一次挫折下整体结论等场景。');
  } else if (segment.lecture == 8) {
    items.add('常见于忽视已有资源、对关系习以为常、只盯着负面信息等场景。');
  } else {
    items.add('常见于需要表达感谢、整合痛苦经验、把一次体验变成长期成长线索的场景。');
  }
  return items;
}

String _sceneMissionText(PositivePsychSegment segment) {
  return '场景目标：先在虚拟世界里体验“不同解释 / 不同回应会让世界怎样变化”，再把本段的现实任务「${segment.defaultActionTitle}」带回日常。';
}

List<Map<String, String>> _buildNodeMissions(PositivePsychPersonaProfile? persona) {
  final focus = persona?.currentFocus ?? '工作与学习';
  return <Map<String, String>>[
    {'title': '解释风格学院｜改写一个自动解释', 'desc': '把最近一个不顺事件写成悲观版、找益版与完整现实版三种解释。更适合当前焦点：$focus。', 'segment': 'pp_l7_1'},
    {'title': '失败训练营｜把失败变成训练样本', 'desc': '挑一个最近的挫折，写下它训练了你什么心理免疫力。', 'segment': 'pp_l7_3'},
    {'title': '行动工坊｜把概念压缩成最小动作', 'desc': '把一个抽象道理压缩成 5 分钟内可开始的行为链。', 'segment': 'pp_l7_2'},
    {'title': '感恩花园｜找回一个被忽略的价值', 'desc': '从理所当然里重新看见一个人、一件事或一个片刻。', 'segment': 'pp_l8_9'},
    {'title': '真实之镜｜同时写问题与资源', 'desc': '用双栏法同时看见痛苦和美好，练习完整现实。', 'segment': 'pp_l9_1'},
    {'title': '复盘回廊｜检查 3M 并重写解释', 'desc': '把一次行动后的想法做 3M 检查，并补一个替代解释。', 'segment': 'pp_l7_8'},
  ];
}


List<Map<String, String>> _segmentSpecificPracticeCards(PositivePsychSegment segment) {
  if (segment.id == 'pp_l7_1') {
    return <Map<String, String>>[
      {'title': '解释重写', 'body': '把一个不顺事件写成自动解释版、完整现实版和下一步行动版。'},
      {'title': '事实-解释分栏', 'body': '左边只写事实，右边写解释，练习不要把两者混在一起。'},
    ];
  }
  if (segment.id == 'pp_l7_7' || segment.id == 'pp_l7_8') {
    return <Map<String, String>>[
      {'title': '3M 点名练习', 'body': '先识别这次更像夸大、缩小还是编造，再补一个更贴近证据的解释。'},
      {'title': '更大画面练习', 'body': '强迫自己补写被忽略的证据、资源和进展，避免隧道视野。'},
    ];
  }
  if (segment.id == 'pp_l8_9' || segment.id == 'pp_l9_4') {
    return <Map<String, String>>[
      {'title': '具体感谢表达', 'body': '不要只说“谢谢”，而要说清楚对方做了什么、为什么重要。'},
      {'title': '微小时刻采样', 'body': '从一天里挑 1 个微小时刻，重温而不是快速掠过。'},
    ];
  }
  if (segment.id == 'pp_l9_6' || segment.id == 'pp_l9_7') {
    return <Map<String, String>>[
      {'title': '负面理解', 'body': '对痛苦经历做书写和分析，允许自己先当一个真实的人。'},
      {'title': '积极重播', 'body': '对一个美好片刻不做过度分析，而是回放和重温。'},
    ];
  }
  return <Map<String, String>>[
    {'title': '最小现实动作', 'body': segment.defaultActionBody},
    {'title': '概念回到现实', 'body': '把这段课程放进你最近一个真实事件里，用它来重写理解和下一步。'},
  ];
}

List<Map<String, String>> _sceneEpisodes(PositivePsychSegment segment) {
  return <Map<String, String>>[
    {
      'title': '剧情一：自动反应出现',
      'body': '你在「${segment.scene}」里遇到一个与现实相似的情境。第一反应往往会暴露你原本的解释风格。'
    },
    {
      'title': '剧情二：选择如何理解',
      'body': '你可以只盯问题、只想赶快舒服一点，或者同时看见问题与资源。不同理解会打开不同后续路径。'
    },
    {
      'title': '剧情三：把理解推进成动作',
      'body': '真正的训练不是停在想明白，而是把它推进成一个现实动作：${segment.defaultActionTitle}。'
    },
  ];
}


List<String> _segmentRealityLinkTips(PositivePsychSegment segment) {
  return <String>[
    '先在知行域里预演一次，再回到现实里做 ${segment.defaultActionTitle}。',
    '做完后至少写 1 条事实记录，不要只停在“我感觉好一点/不好一点”。',
    '如果这次很快又被自动想法带走，优先回到 ${segment.lecture == 7 ? '3M 检查与替代解释' : '具体表达与复盘'}。',
    '下一轮不是换新道理，而是把这次已经有效的一小步再重复一次。',
  ];
}

Map<String, String> _nodeRealityBridge(String node, List<PositivePsychAction> actions, List<PositivePsychReview> reviews) {
  final openActions = actions.where((e) => e.status != 'done').length;
  final needsReview = actions.where((e) => e.status == 'done').length > reviews.length;
  if (node == '解释风格学院') {
    return {
      'title': '从解释校准走向现实记录',
      'body': openActions > 0
          ? '你已经有待推进的动作了。下一步不要再换理解，先把一次事实—解释分栏真正写完。'
          : '先去做一次“事实—解释分栏”或“3M 检查”，把自动想法落到纸面。',
      'segment': 'pp_l7_1',
    };
  }
  if (node == '感恩花园') {
    return {
      'title': '把感谢从感觉推进成表达',
      'body': '知行域里的感恩训练要回到现实里，至少完成一次具体而真实的感谢表达。',
      'segment': 'pp_l9_4',
    };
  }
  if (node == '复盘回廊') {
    return {
      'title': '把经验升成理解',
      'body': needsReview
          ? '你已经完成了一些动作，下一步先补复盘，而不是继续堆新任务。'
          : '把一次最近的经历拆成事实、解释、情绪、行动、结果，再做 3M 检查。',
      'segment': 'pp_l7_8',
    };
  }
  if (node == '行动工坊') {
    return {
      'title': '把最小动作做实',
      'body': '不要在节点里停留太久，优先把一个动作推进到完成，并留下证据记录。',
      'segment': 'pp_l7_2',
    };
  }
  return {
    'title': '先选一个最小迁移动作',
    'body': '当前最重要的不是理解更多，而是把当前节点最小地带回现实，做一条事实记录。',
    'segment': 'pp_l9_1',
  };
}


List<Map<String, String>> _buildWorldUnlockMap(Set<String> unlocked, List<PositivePsychAction> actions, List<PositivePsychReview> reviews) {
  final doneActions = actions.where((e) => e.status == 'done').length;
  return <Map<String, String>>[
    {
      'title': '第 1 层｜解释风格学院',
      'body': '默认开启。先学会把事实和解释分开。',
      'unlocked': unlocked.contains('解释风格学院').toString(),
    },
    {
      'title': '第 2 层｜行动工坊 / 失败训练营',
      'body': '至少创建 1 条行动后解锁，让理解开始推动现实动作。',
      'unlocked': (unlocked.contains('行动工坊') || actions.isNotEmpty).toString(),
    },
    {
      'title': '第 3 层｜感恩花园 / 真实之镜',
      'body': '完成 1 条行动或 1 条复盘后，更适合进入关系、感恩和完整现实训练。',
      'unlocked': (unlocked.contains('感恩花园') || doneActions > 0 || reviews.isNotEmpty).toString(),
    },
    {
      'title': '第 4 层｜复盘回廊 / 危机熔炉',
      'body': '至少完成 2 条复盘后，进入更深的整合与迁移训练。',
      'unlocked': (unlocked.contains('复盘回廊') || reviews.length >= 2).toString(),
    },
  ];
}

List<Map<String, String>> _buildUnlockLadder({
  required Set<String> done,
  required List<PositivePsychAction> actions,
  required List<PositivePsychReview> reviews,
  required PositivePsychPersonaProfile? persona,
}) {
  final doneActions = actions.where((e) => e.status == 'done').length;
  final route = _trainingPathForPersona(persona);
  return <Map<String, String>>[
    {
      'title': '解锁 1｜从理解走到动作',
      'body': actions.isEmpty ? '你现在最该解锁的是第一条现实行动。建议从「${route['title']}」开始。' : '你已经开始把理解转成动作了，可以继续补执行证据。',
      'gate': '至少创建 1 条行动',
      'ready': (actions.isEmpty).toString(),
    },
    {
      'title': '解锁 2｜从动作走到证据',
      'body': doneActions == 0 ? '下一层不是再看更多内容，而是把一条行动真正做完，并留下事实证据。' : '你已经开始留下证据了，下一步是把经验沉淀成复盘。',
      'gate': '至少完成 1 条行动',
      'ready': (actions.isNotEmpty && doneActions == 0).toString(),
    },
    {
      'title': '解锁 3｜从证据走到复盘',
      'body': reviews.isEmpty ? '完成动作后马上进入复盘，别让经验停留在“做过”。' : '你已经有复盘了，下一层是把复盘迁移到下一轮场景。',
      'gate': '至少完成 1 条复盘',
      'ready': (doneActions > 0 && reviews.isEmpty).toString(),
    },
    {
      'title': '解锁 4｜从复盘走到连续训练',
      'body': (done.length >= 10 && doneActions >= 2 && reviews.length >= 2)
          ? '你已经开始形成长期训练闭环，可以进入更复杂、更真实的场景。'
          : '当课程、行动、复盘都不再是单点事件时，就会真正形成你的训练系统。',
      'gate': '至少 10 段学习 + 2 条完成行动 + 2 条复盘',
      'ready': ((reviews.isNotEmpty) && !(done.length >= 10 && doneActions >= 2 && reviews.length >= 2)).toString(),
    },
  ];
}

List<String> _buildExecutionCheckpoints(PositivePsychAction action, PositivePsychSegment? segment, String status) {
  final segTitle = segment?.title ?? action.segmentTitle;
  return <String>[
    '开始前先确认：这次是训练，不是证明“我到底行不行”。',
    '执行中优先盯最小动作，不要一上来就要求自己完整做到。',
    '如果当前状态是“${status == 'done' ? '已完成' : status == 'doing' ? '进行中' : '待做'}”，那下一步最重要的是把事实写具体。',
    '一旦冒出“我又不行了”“这说明我就是……”之类的句子，立即停下来做 3M 检查。',
    '完成和未完成都能成为训练样本，只要你把与「$segTitle」相关的事实、障碍和下一步留了下来。',
  ];
}

PositivePsychSegment? _segmentByCode(String code) {
  for (final s in positivePsychSegments) {
    if (s.id == code) return s;
  }
  return null;
}

List<PositivePsychSegment> _segmentsForScene(String scene) {
  final exact = positivePsychSegments.where((s) => s.scene == scene).toList();
  if (exact.isNotEmpty) return exact;
  if (scene.contains('行动')) return positivePsychSegments.where((s) => s.scene.contains('行动')).toList();
  if (scene.contains('失败')) return positivePsychSegments.where((s) => s.scene.contains('失败')).toList();
  if (scene.contains('感恩')) return positivePsychSegments.where((s) => s.scene.contains('感恩')).toList();
  if (scene.contains('真实')) return positivePsychSegments.where((s) => s.scene.contains('真实')).toList();
  return positivePsychSegments.where((s) => s.lecture == 7).take(4).toList();
}

List<String> _behaviorChainForSegment(PositivePsychSegment segment) {
  final trigger = '触发：当你在${segment.scene}对应的现实情境里再次遇到类似问题时。';
  final firstStep = segment.howSteps.isNotEmpty ? '最小动作：${segment.howSteps.first}' : '最小动作：先写下事实。';
  final second = segment.howSteps.length > 1 ? '展开步骤：${segment.howSteps[1]}' : '展开步骤：补一个更完整的解释。';
  return <String>[
    trigger,
    firstStep,
    second,
    '证据记录：写 1 条事实、1 条新解释、1 个下一步动作。',
    '卡住预案：把动作缩短到 5 分钟，只完成第一步。',
    '复盘问题：${segment.reflectionQuestion}',
  ];
}

Widget _lectureHeatRow(String title, int total, Set<String> done, String prefix) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: List.generate(total, (i) {
          final idx = i + 1;
          final doneFlag = done.contains('$prefix$idx');
          return Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: doneFlag ? const Color(0xFF86EFAC) : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$idx', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          );
        }),
      ),
    ],
  );
}

List<PositivePsychSegment> _recommendedSegments({required Set<String> done, PositivePsychPersonaProfile? persona}) {
  final remain = positivePsychSegments.where((s) => !done.contains(s.id)).toList();
  if (remain.isEmpty) return const <PositivePsychSegment>[];
  int score(PositivePsychSegment seg) {
    var v = 0;
    if (persona != null) {
      if (persona.biasType == 'Magnifying' && seg.lecture == 7) v += 3;
      if (persona.biasType == 'Minimizing' && seg.lecture == 8) v += 3;
      if (persona.biasType == 'Making up' && (seg.id == 'pp_l7_6' || seg.id == 'pp_l7_7' || seg.id == 'pp_l7_8')) v += 4;
      if (persona.currentFocus.contains('关系') && (seg.lecture == 8 || seg.lecture == 9)) v += 2;
      if (persona.currentFocus.contains('情绪') && seg.lecture == 7) v += 2;
      if (persona.currentFocus.contains('健康') && (seg.id == 'pp_l8_1' || seg.id == 'pp_l8_9')) v += 2;
    }
    v += 50 - seg.indexInLecture;
    return v;
  }
  remain.sort((a,b)=>score(b).compareTo(score(a)));
  return remain.take(3).toList();
}

Widget _input(String label, TextEditingController ctrl) {
  return TextField(
    controller: ctrl,
    maxLines: 4,
    decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
  );
}

Widget _dropdownField({
  required String label,
  required String value,
  required List<String> items,
  required ValueChanged<String> onChanged,
}) {
  return InputDecorator(
    decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    ),
  );
}

String _conceptHint(String concept) {
  if (concept.contains('乐观')) return '不是空泛正能量，而是遇事时更接近完整现实、并保留行动空间的解释方式。';
  if (concept.contains('感恩')) return '不是礼貌表达，而是主动把注意力从理所当然转向已经拥有的价值。';
  if (concept.contains('认知')) return '先分清事件、解释、情绪和行动，再决定如何重构。';
  if (concept.contains('失败')) return '把失败看成训练样本，而不是人格定论。';
  if (concept.contains('恢复')) return '重点不是永不受挫，而是更快回到行动。';
  return '把这个概念放回你最近的一个真实事件里，问自己：它在那次经历中具体出现在哪里？';
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _HeroCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  const _MetricCard({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}


List<Map<String, String>> _buildStageMap({
  required Set<String> done,
  required List<PositivePsychAction> actions,
  required List<PositivePsychReview> reviews,
}) {
  final doneActions = actions.where((e) => e.status == 'done').length;
  return <Map<String, String>>[
    {
      'title': '里程碑 1｜点亮基础课程地图',
      'body': '至少完成 6 段以上课程学习，开始知道哪些概念对应哪些现实问题。',
      'done': (done.length >= 6).toString(),
    },
    {
      'title': '里程碑 2｜第一次把概念变成现实动作',
      'body': '不是理解了就算，而是真正创建并执行一次现实行动。',
      'done': (actions.isNotEmpty).toString(),
    },
    {
      'title': '里程碑 3｜第一次把动作做完并留下事实证据',
      'body': '从“我好像做了”走向“我知道自己具体做了什么”。',
      'done': (doneActions > 0).toString(),
    },
    {
      'title': '里程碑 4｜第一次做 3M 检查与替代解释',
      'body': '开始把失败、自责或自动想法转成更完整的解释。',
      'done': (reviews.isNotEmpty).toString(),
    },
    {
      'title': '里程碑 5｜形成连续训练闭环',
      'body': '课程、行动、复盘三者开始真正连起来，而不是单点发生。',
      'done': ((done.length >= 10) && (doneActions >= 2) && (reviews.length >= 2)).toString(),
    },
  ];
}

List<String> _buildEvidenceChecklist(PositivePsychAction action, PositivePsychSegment? segment) {
  final seg = segment?.title ?? action.segmentTitle;
  return <String>[
    '先记录一条事实：你究竟在什么时间、什么场景里做了与「$seg」相关的动作。',
    '补一条行为证据：你真正完成了哪个最小动作，而不是只写“我有在努力”。',
    '如果没做完，也要留下证据：到底是没开始、做到一半停住，还是被什么障碍打断。',
    '行动后立刻写一句新的解释：这次经历最值得保留的不是评价自己，而是下一轮可复用的线索。',
  ];
}

List<String> _buildNextMigrationHints(PositivePsychAction action, PositivePsychSegment? segment) {
  final segTitle = segment?.title ?? action.segmentTitle;
  return <String>[
    '下次遇到类似「$segTitle」场景时，先直接复用这次的最小动作，而不是重新想一套。',
    '优先迁移到更真实一点、但仍可控的场景，不要一下子跳到最难版本。',
    '如果这次最有效的是某一句替代解释，就把它提前写成提醒语，下次直接使用。',
    '迁移成功后，继续做一次事实记录和 3M 检查，形成第二轮训练样本。',
  ];
}
