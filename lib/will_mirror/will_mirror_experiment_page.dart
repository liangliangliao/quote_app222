import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'will_mirror_models.dart';
import 'will_mirror_vault.dart';
import 'will_mirror_widgets.dart';

class WillMirrorExperimentPage extends StatefulWidget {
  const WillMirrorExperimentPage({super.key, this.vault});

  final WillMirrorVault? vault;

  @override
  State<WillMirrorExperimentPage> createState() =>
      _WillMirrorExperimentPageState();
}

class _WillMirrorExperimentPageState extends State<WillMirrorExperimentPage> {
  late final bool _ownsVault = widget.vault == null;
  late final WillMirrorVault _vault = widget.vault ?? WillMirrorVault();
  WillMirrorGoal? _goal;
  List<WillMirrorHypothesis> _hypotheses = const <WillMirrorHypothesis>[];
  List<WillMirrorExperiment> _experiments = const <WillMirrorExperiment>[];
  final Map<String, List<WillMirrorObservation>> _observations =
      <String, List<WillMirrorObservation>>{};
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
      final hypotheses = goal == null
          ? const <WillMirrorHypothesis>[]
          : await _vault.hypotheses(goal.id);
      final experiments = await _vault.experiments();
      final observations = <String, List<WillMirrorObservation>>{};
      for (final experiment in experiments) {
        observations[experiment.id] = await _vault.observations(experiment.id);
      }
      if (!mounted) return;
      setState(() {
        _goal = goal;
        _hypotheses = hypotheses;
        _experiments = experiments;
        _observations
          ..clear()
          ..addAll(observations);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('读取现实实验失败：$error');
    }
  }

  Future<void> _createExperiment() async {
    if (_hypotheses.isEmpty) {
      _message('请先从 Deep Why 建立一个可反驳候选。');
      return;
    }
    var hypothesis = _hypotheses.first;
    final title = TextEditingController(
      text: '7日“${hypothesis.label}”低风险实验',
    );
    final protocol = TextEditingController(
      text: _defaultProtocol(hypothesis.label),
    );
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('让生活检验假说'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<WillMirrorHypothesis>(
                  initialValue: hypothesis,
                  decoration: const InputDecoration(
                    labelText: '要验证的候选',
                    border: OutlineInputBorder(),
                  ),
                  items: _hypotheses
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      hypothesis = value;
                      title.text = '7日“${value.label}”低风险实验';
                      protocol.text = _defaultProtocol(value.label);
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: '实验名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: protocol,
                  minLines: 4,
                  maxLines: 9,
                  decoration: const InputDecoration(
                    labelText: '低风险协议',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '实验不是证明本质。避免高风险辞职、借贷、伤害关系或停止治疗等不可逆行为。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: WillMirrorPalette.muted,
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
              onPressed: () {
                if (title.text.trim().isEmpty || protocol.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('开始7日实验'),
            ),
          ],
        ),
      ),
    );
    if (created != true) {
      title.dispose();
      protocol.dispose();
      return;
    }
    final now = DateTime.now();
    final experiment = WillMirrorExperiment(
      id: WillMirrorIds.next('experiment'),
      hypothesisId: hypothesis.id,
      title: title.text.trim(),
      protocol: protocol.text.trim(),
      startAt: now.millisecondsSinceEpoch,
      endAt: now.add(const Duration(days: 7)).millisecondsSinceEpoch,
      status: WillMirrorExperimentStatus.active,
      createdAt: now.millisecondsSinceEpoch,
    );
    title.dispose();
    protocol.dispose();
    try {
      for (final old in _experiments.where(
        (item) => item.status == WillMirrorExperimentStatus.active,
      )) {
        await _vault.saveExperiment(
          old.copyWith(status: WillMirrorExperimentStatus.abandoned),
        );
      }
      await _vault.saveExperiment(experiment);
      await _load();
    } catch (error) {
      _message('创建实验失败：$error');
    }
  }

  Future<void> _recordObservation(WillMirrorExperiment experiment) async {
    var energy = 5.0;
    var realMe = 5.0;
    var persistence = 5.0;
    var satisfaction = 5.0;
    final note = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('今天生活给了什么反馈？'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _dialogSlider('能量', energy,
                    (value) => setDialogState(() => energy = value)),
                _dialogSlider('最像自己', realMe,
                    (value) => setDialogState(() => realMe = value)),
                _dialogSlider('自然持续性', persistence,
                    (value) => setDialogState(() => persistence = value)),
                _dialogSlider('满足残差', satisfaction,
                    (value) => setDialogState(() => satisfaction = value)),
                const SizedBox(height: 8),
                TextField(
                  controller: note,
                  minLines: 3,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: '只记录真实发生的事实、反例与限制',
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
              child: const Text('加密保存观察'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) {
      note.dispose();
      return;
    }
    final observation = WillMirrorObservation(
      id: WillMirrorIds.next('observation'),
      experimentId: experiment.id,
      energy: energy.round(),
      realMe: realMe.round(),
      persistence: persistence.round(),
      satisfaction: satisfaction.round(),
      note: note.text.trim(),
      observedAt: DateTime.now().millisecondsSinceEpoch,
    );
    note.dispose();
    try {
      await _vault.saveObservation(observation);
      await _load();
    } catch (error) {
      _message('保存实验观察失败：$error');
    }
  }

  Future<void> _finish(WillMirrorExperiment experiment) async {
    try {
      await _vault.saveExperiment(
        experiment.copyWith(status: WillMirrorExperimentStatus.completed),
      );
      await _load();
    } catch (error) {
      _message('更新实验状态失败：$error');
    }
  }

  Widget _dialogSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: <Widget>[
        SizedBox(width: 92, child: Text('$label ${value.round()}')),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final active = _experiments
        .where((item) => item.status == WillMirrorExperimentStatus.active)
        .firstOrNull;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      appBar: AppBar(
        title: const Text('本周现实实验'),
        backgroundColor: const Color(0xFFFAFBF9),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createExperiment,
        icon: const Icon(Icons.add),
        label: const Text('新建7日实验'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: <Widget>[
                const WillMirrorGuardrail(compact: true),
                const SizedBox(height: 14),
                if (_goal == null)
                  const WillMirrorSectionCard(
                    child: Text('请先建立当前欲望和候选。'),
                  )
                else if (active == null)
                  const WillMirrorSectionCard(
                    color: WillMirrorPalette.cream,
                    child: Text(
                      '当前没有进行中的实验。选择一个候选，用 7 天低风险行动观察能量、最像自己、持续性、满足与反例。',
                      style: TextStyle(height: 1.5),
                    ),
                  )
                else
                  _experimentCard(active, highlighted: true),
                if (_experiments.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  const Text(
                    '实验历史',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 9),
                  ..._experiments
                      .where((item) => item.id != active?.id)
                      .map((item) => _experimentCard(item)),
                ],
              ],
            ),
    );
  }

  Widget _experimentCard(
    WillMirrorExperiment experiment, {
    bool highlighted = false,
  }) {
    final observations =
        _observations[experiment.id] ?? const <WillMirrorObservation>[];
    final start = DateFormat('MM-dd').format(
      DateTime.fromMillisecondsSinceEpoch(experiment.startAt),
    );
    final end = DateFormat('MM-dd').format(
      DateTime.fromMillisecondsSinceEpoch(experiment.endAt),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WillMirrorSectionCard(
        color: highlighted ? WillMirrorPalette.sage : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    experiment.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                WillMirrorBadge(label: experiment.status.label),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '$start → $end · 已记录 ${observations.length} 天',
              style: const TextStyle(
                fontSize: 12,
                color: WillMirrorPalette.muted,
              ),
            ),
            const SizedBox(height: 10),
            Text(experiment.protocol, style: const TextStyle(height: 1.45)),
            if (observations.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              const Divider(),
              ...observations.take(3).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '能量 ${item.energy} · 最像自己 ${item.realMe} · 持续 ${item.persistence} · 满足 ${item.satisfaction}${item.note.isEmpty ? '' : ' · ${item.note}'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: WillMirrorPalette.muted,
                        ),
                      ),
                    ),
                  ),
            ],
            if (experiment.status == WillMirrorExperimentStatus.active) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _recordObservation(experiment),
                      icon: const Icon(Icons.add_chart),
                      label: const Text('记录今天'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _finish(experiment),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _defaultProtocol(String label) =>
      '连续 7 天，在一个低风险、可撤回的生活领域中，主动安排一次与“$label”有关的小选择。每天记录：实际做了什么、有没有观众/奖励、行动后能量、最像自己的程度、是否自然愿意继续、满足以后还缺什么，以及任何反例或条件限制。第 7 天只更新暂定模型，不把结果解释为本质证明。';
}

extension _FirstOrNullExperiment<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
