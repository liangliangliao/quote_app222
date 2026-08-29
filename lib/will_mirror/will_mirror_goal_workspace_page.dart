import 'dart:async';

import 'package:flutter/material.dart';

import 'will_mirror_evidence_page.dart';
import 'will_mirror_models.dart';
import 'will_mirror_reasoning_engine.dart';
import 'will_mirror_vault.dart';
import 'will_mirror_widgets.dart';

class WillMirrorGoalWorkspacePage extends StatefulWidget {
  const WillMirrorGoalWorkspacePage({super.key, this.vault});

  final WillMirrorVault? vault;

  @override
  State<WillMirrorGoalWorkspacePage> createState() =>
      _WillMirrorGoalWorkspacePageState();
}

class _WillMirrorGoalWorkspacePageState
    extends State<WillMirrorGoalWorkspacePage> {
  late final bool _ownsVault = widget.vault == null;
  late final WillMirrorVault _vault = widget.vault ?? WillMirrorVault();
  final WillMirrorReasoningEngine _engine = WillMirrorReasoningEngine();
  WillMirrorGoal? _goal;
  List<WillMirrorWhyNode> _nodes = const <WillMirrorWhyNode>[];
  List<WillMirrorProbe> _probes = const <WillMirrorProbe>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_ownsVault) unawaited(_vault.close());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final goal = await _vault.activeGoal();
      final nodes = goal == null
          ? const <WillMirrorWhyNode>[]
          : await _vault.whyNodes(goal.id);
      final probes = goal == null
          ? const <WillMirrorProbe>[]
          : await _vault.probes(goal.id);
      if (!mounted) return;
      setState(() {
        _goal = goal;
        _nodes = nodes;
        _probes = probes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('无法打开私密 Vault：$error');
    }
  }

  Future<void> _createGoal() async {
    final text = TextEditingController();
    var domain = '人生方向';
    var desire = 75.0;
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('今天你最想要什么？'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: text,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: '例如：我要100万元 / 我想辞职创业 / 我想建立一段亲密关系',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: domain,
                  decoration: const InputDecoration(
                    labelText: '领域',
                    border: OutlineInputBorder(),
                  ),
                  items: const <String>[
                    '人生方向',
                    '金钱',
                    '工作/事业',
                    '亲密关系',
                    '家庭',
                    '学习/成长',
                    '健康',
                    '创造/贡献',
                  ]
                      .map((item) =>
                          DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => domain = value ?? domain),
                ),
                const SizedBox(height: 12),
                Text('当前欲望强度 ${desire.round()}/100'),
                Slider(
                  value: desire,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: (value) =>
                      setDialogState(() => desire = value),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (text.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('建立表象目标'),
            ),
          ],
        ),
      ),
    );
    if (created != true) {
      text.dispose();
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final goal = WillMirrorGoal(
      id: WillMirrorIds.next('goal'),
      text: text.text.trim(),
      domain: domain,
      baselineDesire: desire.round(),
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );
    text.dispose();
    try {
      await _vault.saveGoal(goal);
      await _vault.saveWhyNode(
        WillMirrorWhyNode(
          id: WillMirrorIds.next('why'),
          goalId: goal.id,
          parentId: null,
          nodeType: 'surface_goal',
          text: goal.text,
          depth: 0,
          createdAt: now,
        ),
      );
      await _load();
    } catch (error) {
      _message('加密保存失败：$error');
    }
  }

  Future<void> _addWhy(WillMirrorWhyNode parent) async {
    final controller = TextEditingController();
    var mode = 'child';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('为什么这很重要？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                parent.text,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: WillMirrorPalette.ink,
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment(value: 'child', label: Text('继续这一链')),
                  ButtonSegment(value: 'parallel', label: Text('并行原因')),
                ],
                selected: <String>{mode},
                onSelectionChanged: (value) =>
                    setDialogState(() => mode = value.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '写下这一层真实答案；如果不知道，可以写“不知道”。',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('加入 Why Tree'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) {
      controller.dispose();
      return;
    }
    final isRoot = parent.parentId == null;
    final parallel = mode == 'parallel';
    final parentId = parallel
        ? (isRoot ? parent.id : parent.parentId)
        : parent.id;
    final depth = parallel
        ? (isRoot ? 1 : parent.depth)
        : parent.depth + 1;
    final node = WillMirrorWhyNode(
      id: WillMirrorIds.next('why'),
      goalId: parent.goalId,
      parentId: parentId,
      nodeType: 'motive',
      text: controller.text.trim(),
      depth: depth,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    controller.dispose();
    try {
      await _vault.saveWhyNode(node);
      await _load();
    } catch (error) {
      _message('保存 Why 节点失败：$error');
    }
  }

  Future<void> _createHypothesis(String initialLabel) async {
    final controller = TextEditingController(text: initialLabel);
    var type = WillMirrorHypothesisType.motive;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('建立一个可反驳的候选'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '候选主题',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<WillMirrorHypothesisType>(
                initialValue: type,
                decoration: const InputDecoration(
                  labelText: '当前结论层级',
                  border: OutlineInputBorder(),
                ),
                items: WillMirrorHypothesisType.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) =>
                    setDialogState(() => type = value ?? type),
              ),
              const SizedBox(height: 10),
              const Text(
                '建议先从“具体动机候选”开始；只有经过跨人生行动、代价与反证，才升级为经验性格候选。',
                style: TextStyle(fontSize: 12, color: WillMirrorPalette.muted),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('建立候选'),
            ),
          ],
        ),
      ),
    );
    final goal = _goal;
    if (saved != true || goal == null) {
      controller.dispose();
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final hypothesis = WillMirrorHypothesis(
      id: WillMirrorIds.next('hypothesis'),
      goalId: goal.id,
      label: controller.text.trim(),
      type: type,
      status: 'candidate',
      confidenceBand: WillMirrorConfidenceBand.insufficient,
      explanation: '由 Deep Why 结构生成，等待跨人生行动、代价、反证与现实实验。',
      counterSearchCompleted: false,
      counterSearchNote: '',
      createdAt: now,
      updatedAt: now,
    );
    controller.dispose();
    try {
      await _vault.saveHypothesis(hypothesis);
      _message('已建立“${hypothesis.label}”候选；下一步请去认识档案连接支持与反证。');
    } catch (error) {
      _message('建立候选失败：$error');
    }
  }

  Future<void> _recordProbe(WillMirrorProbeType type) async {
    final goal = _goal;
    if (goal == null) return;
    final answer = TextEditingController();
    var baseline = goal.baselineDesire.toDouble();
    var after = goal.baselineDesire.toDouble();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(type.label),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  type.questionFor(goal.text),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text('探针前 ${baseline.round()}/100'),
                Slider(
                  value: baseline,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: (value) =>
                      setDialogState(() => baseline = value),
                ),
                Text('代入条件后 ${after.round()}/100'),
                Slider(
                  value: after,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: (value) =>
                      setDialogState(() => after = value),
                ),
                TextField(
                  controller: answer,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '你观察到什么？',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('保存变量实验'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) {
      answer.dispose();
      return;
    }
    final probe = WillMirrorProbe(
      id: WillMirrorIds.next('probe'),
      goalId: goal.id,
      nodeId: null,
      type: type,
      baseline: baseline.round(),
      after: after.round(),
      answer: answer.text.trim(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    answer.dispose();
    try {
      await _vault.saveProbe(probe);
      await _load();
      final interpretation =
          _engine.interpretProbe(probe, allProbes: <WillMirrorProbe>[
        probe,
        ..._probes,
      ]);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('只解释变化，不判定真假'),
          content: Text(
            <String>[
              interpretation.summary,
              ...interpretation.cautions,
              if (interpretation.nextProbe != null)
                '下一步必须补做：${interpretation.nextProbe!.label}',
            ].join('\n\n'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (error) {
      _message('保存变量实验失败：$error');
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final goal = _goal;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      appBar: AppBar(
        title: const Text('表象与 Deep Why'),
        backgroundColor: const Color(0xFFFAFBF9),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : goal == null
              ? _emptyGoal()
              : _workspace(goal),
    );
  }

  Widget _emptyGoal() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.filter_vintage_outlined,
              size: 58,
              color: WillMirrorPalette.forest,
            ),
            const SizedBox(height: 16),
            const Text(
              '先从一句真实的话开始',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              '系统会先把它当作“表象目标”，不会立即宣布你真正需要什么。',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5, color: WillMirrorPalette.muted),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _createGoal,
              icon: const Icon(Icons.add),
              label: const Text('写下今天最想要的'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _workspace(WillMirrorGoal goal) {
    final surface = _engine.analyzeSurfaceGoal(goal);
    final boundary = _engine.assessBoundary(_nodes);
    final candidates = _engine.deriveCandidates(_nodes);
    final root = _nodes.where((node) => node.parentId == null).firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
      children: <Widget>[
        WillMirrorSectionCard(
          color: WillMirrorPalette.cream,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const WillMirrorBadge(label: '表象目标'),
                  const Spacer(),
                  Text(
                    goal.baselineDesire > 0
                        ? '${goal.baselineDesire}/100'
                        : '未主动量化',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                goal.text,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: WillMirrorPalette.ink,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '${surface.object} · ${goal.domain}',
                style: const TextStyle(color: WillMirrorPalette.muted),
              ),
              const SizedBox(height: 12),
              const Text('尚不知道', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              ...surface.unknowns.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('• $item'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Deep Why Tree',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: root == null ? null : () => _addWhy(root),
              icon: const Icon(Icons.call_split),
              label: const Text('增加分支'),
            ),
          ],
        ),
        const Text(
          '纵向尽量挖深，横向尽量铺广；没有固定三问或五问。',
          style: TextStyle(fontSize: 12, color: WillMirrorPalette.muted),
        ),
        const SizedBox(height: 10),
        ..._nodes.map(_nodeCard),
        const SizedBox(height: 6),
        WillMirrorSectionCard(
          color: boundary.shouldContinueWhy
              ? WillMirrorPalette.sage
              : WillMirrorPalette.cream,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    boundary.shouldContinueWhy
                        ? Icons.south_outlined
                        : Icons.travel_explore_outlined,
                    color: WillMirrorPalette.forest,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      boundary.shouldContinueWhy
                          ? '为什么仍有信息增益'
                          : '已到候选边界：Why → Where Else',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...boundary.reasons.map((reason) => Text('• $reason')),
              const SizedBox(height: 8),
              Text(
                boundary.nextAction,
                style: const TextStyle(
                  height: 1.4,
                  color: WillMirrorPalette.muted,
                ),
              ),
              if (!boundary.shouldContinueWhy) ...<Widget>[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WillMirrorEvidencePage(
                        vault: _vault,
                        goal: goal,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text('到整个人生寻找重复与反例'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          '变量探针',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          '探针只隔离变量，不认证“真正目标”。Opposition 必须与 Removal 成对。',
          style: TextStyle(fontSize: 12, color: WillMirrorPalette.muted),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: WillMirrorProbeType.values
              .map(
                (type) => ActionChip(
                  label: Text(type.label),
                  onPressed: () => _recordProbe(type),
                ),
              )
              .toList(growable: false),
        ),
        if (_probes.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          ..._probes.take(4).map((probe) {
            final interpretation =
                _engine.interpretProbe(probe, allProbes: _probes);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: WillMirrorSectionCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${probe.type.label} · ${probe.baseline} → ${probe.after}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      interpretation.summary,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: WillMirrorPalette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 18),
        const Text(
          '当前候选（尚非结论）',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (candidates.isEmpty)
          OutlinedButton.icon(
            onPressed: () => _createHypothesis(''),
            icon: const Icon(Icons.add),
            label: const Text('手动建立一个可反驳候选'),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: candidates
                .map(
                  (candidate) => ActionChip(
                    avatar: const Icon(Icons.science_outlined, size: 17),
                    label: Text(
                      '${candidate.label} · ${candidate.matchedNodeIds.length}处',
                    ),
                    onPressed: () => _createHypothesis(candidate.label),
                  ),
                )
                .toList(growable: false),
          ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _createGoal,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('换一个当前欲望（保留旧证据）'),
        ),
        const SizedBox(height: 14),
        const WillMirrorGuardrail(),
      ],
    );
  }

  Widget _nodeCard(WillMirrorWhyNode node) {
    return Padding(
      padding: EdgeInsets.only(left: node.depth * 18.0, bottom: 8),
      child: WillMirrorSectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: node.depth == 0 ? WillMirrorPalette.cream : Colors.white,
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 12,
              backgroundColor: WillMirrorPalette.sage,
              child: Text(
                '${node.depth}',
                style: const TextStyle(
                  fontSize: 10,
                  color: WillMirrorPalette.forest,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                node.text,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: WillMirrorPalette.ink,
                ),
              ),
            ),
            IconButton(
              tooltip: '继续追问或分叉',
              onPressed: () => _addWhy(node),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
