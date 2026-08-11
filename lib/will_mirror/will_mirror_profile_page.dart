import 'dart:async';

import 'package:flutter/material.dart';

import 'will_mirror_ai_service.dart';
import 'will_mirror_evidence_page.dart';
import 'will_mirror_knowledge_repository.dart';
import 'will_mirror_models.dart';
import 'will_mirror_reasoning_engine.dart';
import 'will_mirror_vault.dart';
import 'will_mirror_widgets.dart';

class WillMirrorProfilePage extends StatefulWidget {
  const WillMirrorProfilePage({super.key, this.vault, this.knowledge});

  final WillMirrorVault? vault;
  final WillMirrorKnowledgeRepository? knowledge;

  @override
  State<WillMirrorProfilePage> createState() => _WillMirrorProfilePageState();
}

class _WillMirrorProfilePageState extends State<WillMirrorProfilePage> {
  late final bool _ownsVault = widget.vault == null;
  late final bool _ownsKnowledge = widget.knowledge == null;
  late final WillMirrorVault _vault = widget.vault ?? WillMirrorVault();
  late final WillMirrorKnowledgeRepository _knowledge =
      widget.knowledge ?? WillMirrorKnowledgeRepository();
  WillMirrorGoal? _goal;
  List<WillMirrorHypothesis> _hypotheses = const <WillMirrorHypothesis>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_ownsVault) unawaited(_vault.close());
    if (_ownsKnowledge) unawaited(_knowledge.close());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final goal = await _vault.activeGoal();
      final hypotheses = goal == null
          ? const <WillMirrorHypothesis>[]
          : await _vault.hypotheses(goal.id);
      if (!mounted) return;
      setState(() {
        _goal = goal;
        _hypotheses = hypotheses;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('读取认识档案失败：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      appBar: AppBar(
        title: const Text('获得性格 · 认识档案'),
        backgroundColor: const Color(0xFFFAFBF9),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                const WillMirrorGuardrail(),
                const SizedBox(height: 16),
                const Text(
                  '这不是人格标签库，而是版本化、可反驳的自我认识。',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: WillMirrorPalette.ink,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  '候选只有经过跨人生行动、真实代价、强制反证和现实实验，才可能逐步升级。',
                  style: TextStyle(
                    height: 1.45,
                    color: WillMirrorPalette.muted,
                  ),
                ),
                const SizedBox(height: 16),
                if (_goal == null)
                  const WillMirrorSectionCard(
                    child: Text('请先在“当前欲望 / Why Tree”建立表象目标。'),
                  )
                else if (_hypotheses.isEmpty)
                  const WillMirrorSectionCard(
                    color: WillMirrorPalette.cream,
                    child: Text(
                      '还没有候选。请先展开 Deep Why，并把汇聚主题建立为“具体动机候选”。',
                      style: TextStyle(height: 1.5),
                    ),
                  )
                else
                  ..._hypotheses.map(
                    (hypothesis) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: WillMirrorSectionCard(
                        onTap: () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => WillMirrorHypothesisDetailPage(
                                vault: _vault,
                                knowledge: _knowledge,
                                goal: _goal!,
                                hypothesis: hypothesis,
                              ),
                            ),
                          );
                          await _load();
                        },
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: WillMirrorPalette.sage,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.account_tree_outlined,
                                color: WillMirrorPalette.forest,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    hypothesis.label,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${hypothesis.type.label} · ${hypothesis.confidenceBand.label}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: WillMirrorPalette.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class WillMirrorHypothesisDetailPage extends StatefulWidget {
  const WillMirrorHypothesisDetailPage({
    super.key,
    required this.vault,
    required this.knowledge,
    required this.goal,
    required this.hypothesis,
  });

  final WillMirrorVault vault;
  final WillMirrorKnowledgeRepository knowledge;
  final WillMirrorGoal goal;
  final WillMirrorHypothesis hypothesis;

  @override
  State<WillMirrorHypothesisDetailPage> createState() =>
      _WillMirrorHypothesisDetailPageState();
}

class _WillMirrorHypothesisDetailPageState
    extends State<WillMirrorHypothesisDetailPage> {
  final WillMirrorReasoningEngine _engine = WillMirrorReasoningEngine();
  late WillMirrorHypothesis _hypothesis = widget.hypothesis;
  List<WillMirrorLifeEvidence> _evidence = const <WillMirrorLifeEvidence>[];
  List<WillMirrorHypothesisEvidence> _links =
      const <WillMirrorHypothesisEvidence>[];
  List<WillMirrorProbe> _probes = const <WillMirrorProbe>[];
  List<WillMirrorObservation> _observations = const <WillMirrorObservation>[];
  WillMirrorRetrievalBundle? _retrieval;
  WillMirrorEvidenceMatrix? _matrix;
  WillMirrorGroundedInference? _inference;
  bool _loading = true;
  bool _runningAi = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final evidence = await widget.vault.evidenceForGoal(widget.goal.id);
      final links = await widget.vault.links(_hypothesis.id);
      final probes = await widget.vault.probes(widget.goal.id);
      final experiments =
          await widget.vault.experiments(hypothesisId: _hypothesis.id);
      final observations = <WillMirrorObservation>[];
      for (final experiment in experiments) {
        observations.addAll(await widget.vault.observations(experiment.id));
      }
      final retrieval =
          await widget.knowledge.retrieveForHypothesis(_hypothesis.label);
      final matrix = _engine.buildEvidenceMatrix(
        hypothesis: _hypothesis,
        evidence: evidence,
        links: links,
        probes: probes,
        observations: observations,
      );
      if (_hypothesis.confidenceBand != matrix.band) {
        _hypothesis = _hypothesis.copyWith(
          confidenceBand: matrix.band,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await widget.vault.saveHypothesis(_hypothesis);
      }
      if (!mounted) return;
      setState(() {
        _evidence = evidence;
        _links = links;
        _probes = probes;
        _observations = observations;
        _retrieval = retrieval;
        _matrix = matrix;
        _inference = _engine.localInference(
          hypothesis: _hypothesis,
          matrix: matrix,
          retrieval: retrieval,
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('构建证据矩阵失败：$error');
    }
  }

  Future<void> _captureFor(WillMirrorRelation relation) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => WillMirrorEvidencePage(
          vault: widget.vault,
          goal: widget.goal,
          initialType: relation == WillMirrorRelation.contradicts
              ? WillMirrorEvidenceType.counterexample
              : null,
          hypothesis: _hypothesis,
          relation: relation,
        ),
      ),
    );
    if (saved == true || mounted) await _load();
  }

  Future<void> _linkExisting() async {
    final linkedIds = _links.map((item) => item.evidenceId).toSet();
    final available =
        _evidence.where((item) => !linkedIds.contains(item.id)).toList();
    if (available.isEmpty) {
      _message('没有尚未连接的证据，请先新增一条。');
      return;
    }
    final selection = await showModalBottomSheet<(String, WillMirrorRelation)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: <Widget>[
              const Text(
                '选择证据，再指定它与候选的关系',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ...available.map(
                (item) => Card(
                  child: ExpansionTile(
                    title: Text(item.title),
                    subtitle: Text('${item.type.label} · ${item.lifeStage}'),
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        children: <WillMirrorRelation>[
                          WillMirrorRelation.supports,
                          WillMirrorRelation.contradicts,
                          WillMirrorRelation.limits,
                        ]
                            .map(
                              (relation) => ActionChip(
                                label: Text(relation.label),
                                onPressed: () => Navigator.pop(
                                  context,
                                  (item.id, relation),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selection == null) return;
    try {
      await widget.vault.linkEvidence(
        WillMirrorHypothesisEvidence(
          hypothesisId: _hypothesis.id,
          evidenceId: selection.$1,
          relation: selection.$2,
          weight: 1,
          contextLimit: '',
        ),
      );
      await _load();
    } catch (error) {
      _message('连接证据失败：$error');
    }
  }

  Future<void> _markCounterSearch() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('主动寻找反例'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '请写明你搜索过哪些相反情境：高风险、家庭责任、结构化环境、无人要求、遭遇失败或资源不足等。没有找到也要留下搜索范围。',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: '搜索过的情境与当前结果',
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
              if (controller.text.trim().length < 8) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('确认已主动检索'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      controller.dispose();
      return;
    }
    _hypothesis = _hypothesis.copyWith(
      counterSearchCompleted: true,
      counterSearchNote: controller.text.trim(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    controller.dispose();
    try {
      await widget.vault.saveHypothesis(_hypothesis);
      await _load();
    } catch (error) {
      _message('保存反证检索失败：$error');
    }
  }

  Future<void> _changeLevel() async {
    final selected = await showDialog<WillMirrorHypothesisType>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('调整候选层级'),
        children: WillMirrorHypothesisType.values
            .map(
              (type) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, type),
                child: ListTile(
                  title: Text(type.label),
                  subtitle: Text(
                    switch (type) {
                      WillMirrorHypothesisType.motive => '只解释当前具体目标',
                      WillMirrorHypothesisType.stableWant => '在多个情境重复的意欲候选',
                      WillMirrorHypothesisType.empiricalCharacter =>
                        '必须跨至少三阶段、有行动并完成反证',
                    },
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
    if (selected == null || selected == _hypothesis.type) return;
    _hypothesis = _hypothesis.copyWith(
      type: selected,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await widget.vault.saveHypothesis(_hypothesis);
      await _load();
    } catch (error) {
      _message('更新候选层级失败：$error');
    }
  }

  Future<void> _runAi() async {
    final matrix = _matrix;
    final retrieval = _retrieval;
    if (matrix == null || retrieval == null) return;
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('是否调用云端 AI？'),
        content: const Text(
          '默认完全本地。本次若继续，只发送你已明确连接到该候选的最小证据，以及短篇理论摘要与 passage ID；不会发送整个 Vault、其他目标或完整知识库。AI 输出仍要经过 ID 白名单、反证和边界校验。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保持纯本地'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('本次允许发送'),
          ),
        ],
      ),
    );
    if (consent != true) return;
    setState(() => _runningAi = true);
    final result = await WillMirrorAiService(vault: widget.vault).generateGrounded(
      hypothesis: _hypothesis,
      matrix: matrix,
      retrieval: retrieval,
    );
    if (!mounted) return;
    setState(() {
      _runningAi = false;
      _inference = result;
    });
    if (result.provider == 'local') {
      _message('未配置可用 AI，已安全回退为本地证据综合。');
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final matrix = _matrix;
    final inference = _inference;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      appBar: AppBar(
        title: Text(_hypothesis.label),
        backgroundColor: const Color(0xFFFAFBF9),
        actions: <Widget>[
          IconButton(
            tooltip: '调整候选层级',
            onPressed: _changeLevel,
            icon: const Icon(Icons.layers_outlined),
          ),
        ],
      ),
      body: _loading || matrix == null || inference == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      WillMirrorBadge(label: _hypothesis.type.label),
                      const SizedBox(width: 7),
                      WillMirrorBadge(
                        label: matrix.band.label,
                        color: matrix.band ==
                                WillMirrorConfidenceBand.insufficient
                            ? WillMirrorPalette.rose
                            : WillMirrorPalette.sage,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  WillMirrorSectionCard(
                    color: WillMirrorPalette.cream,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          '当前暂定模型',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          inference.conclusion,
                          style: const TextStyle(height: 1.5),
                        ),
                        if (inference.uncertainty.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          const Text(
                            '仍不确定',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          ...inference.uncertainty.map((item) => Text('• $item')),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          '下一步：${inference.nextAction}',
                          style: const TextStyle(
                            color: WillMirrorPalette.forest,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _matrixSection(
                    '支持',
                    matrix.supports,
                    WillMirrorPalette.sage,
                    '还没有明确支持该候选的人生证据。',
                  ),
                  const SizedBox(height: 10),
                  _matrixSection(
                    '反证',
                    matrix.counterevidence,
                    WillMirrorPalette.rose,
                    '尚未连接真正可能推翻该候选的反例。',
                  ),
                  const SizedBox(height: 10),
                  _matrixSection(
                    '情境限制',
                    matrix.limits,
                    WillMirrorPalette.cream,
                    '尚未写明它在什么条件下不成立或让位。',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ActionChip(
                        avatar: const Icon(Icons.link, size: 17),
                        label: const Text('连接已有证据'),
                        onPressed: _linkExisting,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 17),
                        label: const Text('新增支持'),
                        onPressed: () => _captureFor(WillMirrorRelation.supports),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.gavel_outlined, size: 17),
                        label: const Text('新增反证'),
                        onPressed: () =>
                            _captureFor(WillMirrorRelation.contradicts),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.rule_outlined, size: 17),
                        label: const Text('新增限制'),
                        onPressed: () => _captureFor(WillMirrorRelation.limits),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  WillMirrorSectionCard(
                    color: _hypothesis.counterSearchCompleted
                        ? WillMirrorPalette.sage
                        : WillMirrorPalette.rose,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _hypothesis.counterSearchCompleted
                              ? '反证检索已留痕'
                              : '硬门禁：尚未完成主动反证检索',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _hypothesis.counterSearchCompleted
                              ? _hypothesis.counterSearchNote
                              : '在完成前，系统不会发布经验性格级结论。',
                          style: const TextStyle(height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _markCounterSearch,
                          child: Text(
                            _hypothesis.counterSearchCompleted
                                ? '重新检索并更新'
                                : '现在主动寻找反例',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '理论依据与误用边界',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 9),
                  ...(_retrieval?.all ?? const <WillMirrorKnowledgePassage>[])
                      .take(6)
                      .map(_passageCard),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _runningAi ? null : _runAi,
                    icon: _runningAi
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(
                      _runningAi
                          ? '正在做证据约束分析…'
                          : '可选：调用全局 AI 做证据约束分析',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '本次输出：${inference.provider} · ${inference.model}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: WillMirrorPalette.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  WillMirrorGuardrail(compact: false),
                ],
              ),
            ),
    );
  }

  Widget _matrixSection(
    String title,
    List<WillMirrorLifeEvidence> items,
    Color color,
    String empty,
  ) {
    return WillMirrorSectionCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          if (items.isEmpty)
            Text(empty, style: const TextStyle(color: WillMirrorPalette.muted))
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• ${item.title}（${item.lifeStage}）'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _passageCard(WillMirrorKnowledgePassage item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: WillMirrorSectionCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${item.creator} · ${item.workPart} ${item.sectionRef}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                WillMirrorBadge(label: item.evidenceLevel.value),
              ],
            ),
            const SizedBox(height: 7),
            Text(item.summary, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 6),
            Text(
              '边界：${item.misuseBoundary}',
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: WillMirrorPalette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
