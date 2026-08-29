import 'dart:async';

import 'package:flutter/material.dart';

import 'will_mirror_assistant_page.dart';
import 'will_mirror_capability_catalog.dart';
import 'will_mirror_evidence_page.dart';
import 'will_mirror_experiment_page.dart';
import 'will_mirror_goal_workspace_page.dart';
import 'will_mirror_guide_page.dart';
import 'will_mirror_knowledge_repository.dart';
import 'will_mirror_models.dart';
import 'will_mirror_practice_coordinator.dart';
import 'will_mirror_practice_models.dart';
import 'will_mirror_practice_page.dart';
import 'will_mirror_profile_page.dart';
import 'will_mirror_support_pages.dart';
import 'will_mirror_vault.dart';
import 'will_mirror_widgets.dart';

class WillMirrorHomePage extends StatefulWidget {
  const WillMirrorHomePage({
    super.key,
    this.vault,
    this.knowledge,
  });

  static const Key primaryInputKey = ValueKey<String>('wm_v5_primary_input');
  static const Key primaryActionKey = ValueKey<String>('wm_v5_primary_action');
  static const Key assistantKey = ValueKey<String>('wm_v5_assistant_fab');

  final WillMirrorVault? vault;
  final WillMirrorKnowledgeRepository? knowledge;

  @override
  State<WillMirrorHomePage> createState() => _WillMirrorHomePageState();
}

class _WillMirrorHomePageState extends State<WillMirrorHomePage> {
  late final bool _ownsVault = widget.vault == null;
  late final bool _ownsKnowledge = widget.knowledge == null;
  late final WillMirrorVault _vault = widget.vault ?? WillMirrorVault();
  late final WillMirrorKnowledgeRepository _knowledge =
      widget.knowledge ?? WillMirrorKnowledgeRepository();
  final TextEditingController _quickInput = TextEditingController();

  WillMirrorNeedType _quickType = WillMirrorNeedType.goal;
  WillMirrorActionPlan? _plan;
  WillMirrorGoal? _goal;
  List<WillMirrorWhyNode> _nodes = const <WillMirrorWhyNode>[];
  List<WillMirrorLifeEvidence> _evidence = const <WillMirrorLifeEvidence>[];
  List<WillMirrorHypothesis> _hypotheses = const <WillMirrorHypothesis>[];
  List<WillMirrorObservation> _observations = const <WillMirrorObservation>[];
  WillMirrorExperiment? _experiment;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _quickInput.dispose();
    if (_ownsVault) unawaited(_vault.close());
    if (_ownsKnowledge) unawaited(_knowledge.close());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final goal = await _vault.activeGoal();
      var plan = await _vault.activeActionPlan();
      plan ??= goal == null ? null : await _vault.actionPlan(goal.id);
      final nodes = goal == null
          ? const <WillMirrorWhyNode>[]
          : await _vault.whyNodes(goal.id);
      final evidence = goal == null
          ? const <WillMirrorLifeEvidence>[]
          : await _vault.evidenceForGoal(goal.id);
      final hypotheses = goal == null
          ? const <WillMirrorHypothesis>[]
          : await _vault.hypotheses(goal.id);
      final experiment = await _vault.activeExperiment();
      final observations = plan == null
          ? const <WillMirrorObservation>[]
          : await _vault.observations(plan.experimentId);
      if (!mounted) return;
      setState(() {
        _goal = goal;
        _plan = plan;
        _nodes = nodes;
        _evidence = evidence;
        _hypotheses = hypotheses;
        _experiment = experiment;
        _observations = observations;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<T?> _open<T>(Widget page) async {
    final result = await Navigator.of(context).push<T>(
      MaterialPageRoute<T>(builder: (_) => page),
    );
    await _load();
    return result;
  }

  Future<void> _startPractice({String? text, WillMirrorNeedType? type}) async {
    final initial = (text ?? _quickInput.text).trim();
    if (initial.isEmpty) {
      _show('先用一句话说出目标或问题');
      return;
    }
    final created = await _open<bool>(
      WillMirrorPracticePage(
        vault: _vault,
        initialText: initial,
        initialType: type ?? _quickType,
      ),
    );
    if (created == true) _quickInput.clear();
  }

  Future<void> _openAssistant() async {
    await _open<void>(
      WillMirrorAssistantPage(
        vault: _vault,
        knowledge: _knowledge,
        plan: _plan,
      ),
    );
  }

  Future<void> _startFocus() async {
    final plan = _plan;
    if (plan == null) return;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => _WillMirrorFocusPage(plan: plan)),
    );
    if (completed == true && mounted) await _checkIn(true);
  }

  Future<void> _checkIn(bool didAct) async {
    final plan = _plan;
    if (plan == null) return;
    final draft = await showModalBottomSheet<_CheckInDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CheckInSheet(didAct: didAct),
    );
    if (draft == null) return;
    try {
      final result = await WillMirrorPracticeCoordinator(vault: _vault).checkIn(
        plan: plan,
        didAct: didAct,
        energy: draft.energy,
        realMe: draft.realMe,
        persistence: draft.persistence,
        satisfaction: draft.satisfaction,
        note: draft.note,
      );
      if (!mounted) return;
      _show(
        result.completedExperiment
            ? '七次现实反馈已收齐。现在可以复盘并开始下一轮。'
            : didAct
                ? '已把今天的行动变成现实证据'
                : '已记下阻碍；没有把它判成失败',
      );
      await _load();
    } catch (error) {
      if (mounted) _show('记录失败：$error');
    }
  }

  Future<void> _openEvidence(WillMirrorEvidenceType type) async {
    final goal = _goal;
    if (goal == null) {
      _show('请先从首页说出一个目标或问题');
      return;
    }
    await _open<void>(
      WillMirrorEvidencePage(vault: _vault, goal: goal, initialType: type),
    );
  }

  void _show(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      appBar: AppBar(
        title: const Text('意志之镜'),
        backgroundColor: const Color(0xFFFAFBF9),
        actions: <Widget>[
          IconButton(
            tooltip: '怎么用',
            onPressed: () => _open<void>(const WillMirrorGuidePage()),
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: '数据与隐私',
            onPressed: () => _open<void>(
              WillMirrorPrivacyPage(vault: _vault, knowledge: _knowledge),
            ),
            icon: const Icon(Icons.shield_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: WillMirrorHomePage.assistantKey,
        onPressed: _openAssistant,
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('问助手'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: <Widget>[
                  if (_error != null) ...<Widget>[
                    WillMirrorSectionCard(
                      color: WillMirrorPalette.rose,
                      child: Text(
                        '私密 Vault 暂不可用：$_error\n\n为避免泄露，系统不会回退到明文存储。',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_plan == null || _plan!.status != 'active')
                    _startCard()
                  else
                    _todayCard(_plan!),
                  if (_plan != null && _plan!.status == 'completed') ...<Widget>[
                    const SizedBox(height: 12),
                    _completedCard(_plan!),
                  ],
                  const SizedBox(height: 14),
                  _helpRow(),
                  const SizedBox(height: 18),
                  _progressCard(),
                  const SizedBox(height: 18),
                  _advancedTools(),
                  const SizedBox(height: 18),
                  const WillMirrorGuardrail(),
                ],
              ),
      ),
    );
  }

  Widget _startCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF315D4D), Color(0xFF5F7768)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '今天，你想解决什么？',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            '说一句就够。接下来我会帮你把知识变成今天能完成的第一步。',
            style: TextStyle(color: Color(0xFFE7F0EA), height: 1.45),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            children: WillMirrorNeedType.values.map((type) {
              return ChoiceChip(
                label: Text(type.shortLabel),
                selected: _quickType == type,
                onSelected: (_) => setState(() => _quickType = type),
                selectedColor: Colors.white,
                backgroundColor: const Color(0x335F7768),
                labelStyle: TextStyle(
                  color: _quickType == type
                      ? WillMirrorPalette.forest
                      : Colors.white,
                ),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 12),
          TextField(
            key: WillMirrorHomePage.primaryInputKey,
            controller: _quickInput,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(color: WillMirrorPalette.ink),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: _quickType == WillMirrorNeedType.goal
                  ? '例如：我想完成作品集初稿'
                  : '例如：我总是拖延，不知道怎么开始',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: WillMirrorHomePage.primaryActionKey,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: WillMirrorPalette.forest,
              ),
              onPressed: _startPractice,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('带我做到今天第一步'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _todayCard(WillMirrorActionPlan plan) {
    return WillMirrorSectionCard(
      color: WillMirrorPalette.sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '现在只做这一件事',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
              ),
              WillMirrorBadge(label: '${plan.route.minutes} 分钟'),
            ],
          ),
          const SizedBox(height: 6),
          Text(plan.need, style: const TextStyle(color: WillMirrorPalette.muted)),
          if (plan.revisionNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('根据上次反馈调整：${plan.revisionNote}'),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            plan.route.action,
            style: const TextStyle(fontSize: 17, height: 1.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                const TextSpan(
                  text: '做到这里就算完成：',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: plan.route.successSignal),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: plan.route.theoryIds.map((id) {
              return WillMirrorBadge(
                label: WillMirrorTheoryCatalog.find(id)?.shortLabel ?? id,
                icon: Icons.menu_book_outlined,
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _startFocus,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('开始 ${plan.route.minutes} 分钟'),
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton(
                  onPressed: () => _checkIn(true),
                  child: const Text('我已经做了，记录结果'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => _checkIn(false),
                  child: const Text('没做成，记录阻碍'),
                ),
              ),
            ],
          ),
          const Text(
            '没有连续打卡惩罚。做成与没做成都会变成下一步依据。',
            style: TextStyle(fontSize: 11, color: WillMirrorPalette.muted),
          ),
        ],
      ),
    );
  }

  Widget _completedCard(WillMirrorActionPlan plan) {
    return WillMirrorSectionCard(
      color: WillMirrorPalette.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('这一轮已经有结果', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            '记录 ${plan.checkInCount} 次，其中 ${plan.completedCount} 次采取了行动。数字不用于给你打分，只用于回看现实发生了什么。',
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => _startPractice(text: plan.need, type: plan.needType),
            child: const Text('根据结果开始下一轮'),
          ),
        ],
      ),
    );
  }

  Widget _helpRow() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _SmallAction(
            icon: Icons.auto_stories_outlined,
            title: '看完整案例',
            subtitle: '含七天测试数据',
            onTap: () => _open<void>(const WillMirrorExamplesPage()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SmallAction(
            icon: Icons.map_outlined,
            title: '怎么用',
            subtitle: '流程图与逐项说明',
            onTap: () => _open<void>(const WillMirrorGuidePage()),
          ),
        ),
      ],
    );
  }

  Widget _progressCard() {
    return WillMirrorSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('现实进展', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          if (_goal == null)
            const Text('还没有实践记录。完成第一步后，这里会显示真实产出而不是抽象标签。')
          else ...<Widget>[
            Text(_goal!.text, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            Text(
              '${_observations.length} 次现实反馈 · ${_evidence.length} 条人生证据 · ${_nodes.length} 个动机/阻碍线索',
              style: const TextStyle(color: WillMirrorPalette.muted),
            ),
            if (_plan != null) ...<Widget>[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_plan!.checkInCount / 7).clamp(0, 1).toDouble(),
                minHeight: 7,
                borderRadius: BorderRadius.circular(99),
                color: WillMirrorPalette.forest,
                backgroundColor: WillMirrorPalette.line,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _advancedTools() {
    return WillMirrorSectionCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        title: const Text('进阶工具', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: const Text('需要深入分析时再打开；新用户不必先学会这些'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: <Widget>[
          WillMirrorEntryTile(
            icon: Icons.account_tree_outlined,
            title: '目标、Deep Why 与变量探针',
            subtitle: '输入目标与具体变化；得到动机树、边界提示和待验证变量',
            onTap: () => _open<void>(WillMirrorGoalWorkspacePage(vault: _vault)),
          ),
          const SizedBox(height: 8),
          WillMirrorEntryTile(
            icon: Icons.self_improvement_outlined,
            title: 'Real-Me · 最像自己',
            subtitle: '记录具体时刻、能量和条件；产出兴趣/优势候选证据',
            onTap: () => _openEvidence(WillMirrorEvidenceType.realMe),
          ),
          const SizedBox(height: 8),
          WillMirrorEntryTile(
            icon: Icons.directions_walk_outlined,
            title: '行动镜 · 实际选择',
            subtitle: '记录做过什么、持续多久、真实代价和外部限制',
            onTap: () => _openEvidence(WillMirrorEvidenceType.action),
          ),
          const SizedBox(height: 8),
          WillMirrorEntryTile(
            icon: Icons.grid_view_outlined,
            title: '支持—反证—限制矩阵',
            subtitle: _hypotheses.isEmpty
                ? '没有反证不发布性格结论；产出可修订候选'
                : '${_hypotheses.length} 个候选，继续连接支持、反证与情境限制',
            onTap: () => _open<void>(
              WillMirrorProfilePage(vault: _vault, knowledge: _knowledge),
            ),
          ),
          const SizedBox(height: 8),
          WillMirrorEntryTile(
            icon: Icons.science_outlined,
            title: '七日现实实验明细',
            subtitle: _experiment == null
                ? '建立低风险实验并记录能量、持续性和满足感'
                : _experiment!.title,
            onTap: () => _open<void>(WillMirrorExperimentPage(vault: _vault)),
          ),
          const SizedBox(height: 8),
          WillMirrorEntryTile(
            icon: Icons.menu_book_outlined,
            title: '理论证据与误用边界',
            subtitle: '查看每条功能依据、证据等级、原始定位与不能怎样解释',
            onTap: () => _open<void>(WillMirrorKnowledgePage(knowledge: _knowledge)),
          ),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WillMirrorSectionCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: WillMirrorPalette.forest),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: WillMirrorPalette.muted),
          ),
        ],
      ),
    );
  }
}

class _WillMirrorFocusPage extends StatefulWidget {
  const _WillMirrorFocusPage({required this.plan});

  final WillMirrorActionPlan plan;

  @override
  State<_WillMirrorFocusPage> createState() => _WillMirrorFocusPageState();
}

class _WillMirrorFocusPageState extends State<_WillMirrorFocusPage> {
  Timer? _timer;
  late int _remaining = widget.plan.route.minutes * 60;
  bool _running = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    if (_remaining == 0) {
      setState(() => _remaining = widget.plan.route.minutes * 60);
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        timer.cancel();
        setState(() {
          _remaining = 0;
          _running = false;
        });
      } else {
        setState(() => _remaining -= 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      appBar: AppBar(title: const Text('只做这一小步')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                widget.plan.route.action,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 21, height: 1.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 28),
              Text(
                '$minutes:$seconds',
                style: const TextStyle(
                  fontSize: 58,
                  fontWeight: FontWeight.w300,
                  color: WillMirrorPalette.forest,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.plan.route.successSignal,
                textAlign: TextAlign.center,
                style: const TextStyle(color: WillMirrorPalette.muted, height: 1.45),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _toggle,
                icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                label: Text(_running ? '暂停' : _remaining == 0 ? '重新开始' : '开始'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('已经留下痕迹，记录结果'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('先退出，不记为失败'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckInDraft {
  const _CheckInDraft({
    required this.energy,
    required this.realMe,
    required this.persistence,
    required this.satisfaction,
    required this.note,
  });

  final int energy;
  final int realMe;
  final int persistence;
  final int satisfaction;
  final String note;
}

class _CheckInSheet extends StatefulWidget {
  const _CheckInSheet({required this.didAct});

  final bool didAct;

  @override
  State<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<_CheckInSheet> {
  final TextEditingController _note = TextEditingController();
  int _energy = 5;
  int _realMe = 5;
  int _persistence = 5;
  int _satisfaction = 5;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.didAct ? '今天生活给了什么反馈？' : '是什么挡住了今天？',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              widget.didAct
                  ? '只记录事实，不给自己打分。'
                  : '没做成不等于不想要；资源、能力、责任和环境都可能参与。',
              style: const TextStyle(color: WillMirrorPalette.muted),
            ),
            const SizedBox(height: 16),
            _ThreeChoice(
              title: '这次之后的能量',
              values: const <(String, int)>[('更低', 3), ('差不多', 5), ('更高', 7)],
              selected: _energy,
              onChanged: (value) => setState(() => _energy = value),
            ),
            const SizedBox(height: 12),
            _ThreeChoice(
              title: '做这件事时有多像自己',
              values: const <(String, int)>[('不太像', 3), ('说不准', 5), ('很像', 7)],
              selected: _realMe,
              onChanged: (value) => setState(() => _realMe = value),
            ),
            const SizedBox(height: 12),
            _ThreeChoice(
              title: '如果条件合适，还愿意自然继续吗',
              values: const <(String, int)>[('不太愿意', 3), ('说不准', 5), ('愿意', 7)],
              selected: _persistence,
              onChanged: (value) => setState(() => _persistence = value),
            ),
            const SizedBox(height: 12),
            _ThreeChoice(
              title: '这一步有没有带来想要的变化',
              values: const <(String, int)>[('没有', 3), ('说不准', 5), ('有一些', 7)],
              selected: _satisfaction,
              onChanged: (value) => setState(() => _satisfaction = value),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: widget.didAct ? '具体发生了什么？（可不填）' : '真正的阻碍是什么？（可不填）',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  _CheckInDraft(
                    energy: _energy,
                    realMe: _realMe,
                    persistence: _persistence,
                    satisfaction: _satisfaction,
                    note: _note.text,
                  ),
                ),
                child: const Text('保存为现实证据'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreeChoice extends StatelessWidget {
  const _ThreeChoice({
    required this.title,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<(String, int)> values;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          children: values.map((item) {
            return ChoiceChip(
              label: Text(item.$1),
              selected: selected == item.$2,
              onSelected: (_) => onChanged(item.$2),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}
