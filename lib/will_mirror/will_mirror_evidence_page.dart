import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'will_mirror_models.dart';
import 'will_mirror_vault.dart';
import 'will_mirror_widgets.dart';

class WillMirrorEvidencePage extends StatefulWidget {
  const WillMirrorEvidencePage({
    super.key,
    required this.goal,
    this.vault,
    this.initialType,
    this.hypothesis,
    this.relation,
  });

  final WillMirrorGoal goal;
  final WillMirrorVault? vault;
  final WillMirrorEvidenceType? initialType;
  final WillMirrorHypothesis? hypothesis;
  final WillMirrorRelation? relation;

  @override
  State<WillMirrorEvidencePage> createState() =>
      _WillMirrorEvidencePageState();
}

class _WillMirrorEvidencePageState extends State<WillMirrorEvidencePage> {
  late final bool _ownsVault = widget.vault == null;
  late final WillMirrorVault _vault = widget.vault ?? WillMirrorVault();
  List<WillMirrorLifeEvidence> _evidence = const <WillMirrorLifeEvidence>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (widget.initialType != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _capture(widget.initialType!);
        });
      }
    });
  }

  @override
  void dispose() {
    if (_ownsVault) unawaited(_vault.close());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await _vault.evidenceForGoal(widget.goal.id);
      if (!mounted) return;
      setState(() {
        _evidence = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('读取私密证据失败：$error')),
      );
    }
  }

  Future<void> _capture(WillMirrorEvidenceType type) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => WillMirrorEvidenceCapturePage(
          vault: _vault,
          goal: widget.goal,
          type: type,
          hypothesis: widget.hypothesis,
          relation: widget.relation,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      appBar: AppBar(
        title: const Text('人生证据库'),
        backgroundColor: const Color(0xFFFAFBF9),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                const WillMirrorGuardrail(compact: true),
                const SizedBox(height: 14),
                Text(
                  widget.hypothesis == null
                      ? '记录一种真实发生过的证据'
                      : '为“${widget.hypothesis!.label}”补充${widget.relation?.label ?? ''}证据',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: WillMirrorPalette.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: WillMirrorEvidenceType.values
                      .map(
                        (type) => ActionChip(
                          avatar: Icon(_iconFor(type), size: 17),
                          label: Text(type.label),
                          onPressed: () => _capture(type),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 18),
                if (_evidence.isEmpty)
                  const WillMirrorSectionCard(
                    color: WillMirrorPalette.cream,
                    child: Text(
                      '还没有人生证据。先记录一个 Real-Me 时刻或今天真正发生的行动；系统不会仅凭一次回答宣布你的性格。',
                      style: TextStyle(
                        height: 1.5,
                        color: WillMirrorPalette.muted,
                      ),
                    ),
                  )
                else
                  ..._evidence.map(_evidenceCard),
              ],
            ),
    );
  }

  Widget _evidenceCard(WillMirrorLifeEvidence item) {
    final date = DateFormat('yyyy-MM-dd').format(
      DateTime.fromMillisecondsSinceEpoch(item.occurredAt),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WillMirrorSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(_iconFor(item.type),
                    size: 19, color: WillMirrorPalette.forest),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: WillMirrorPalette.ink,
                    ),
                  ),
                ),
                WillMirrorBadge(label: item.type.label),
              ],
            ),
            if (item.note.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                item.note,
                style: const TextStyle(
                  height: 1.45,
                  color: WillMirrorPalette.muted,
                ),
              ),
            ],
            const SizedBox(height: 9),
            Text(
              '$date · ${item.lifeStage} · ${item.domain} · 强度 ${item.intensity}/10 · 代价 ${item.costLevel}/10',
              style: const TextStyle(
                fontSize: 11,
                color: WillMirrorPalette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(WillMirrorEvidenceType type) => switch (type) {
        WillMirrorEvidenceType.realMe => Icons.self_improvement_outlined,
        WillMirrorEvidenceType.action => Icons.directions_walk_outlined,
        WillMirrorEvidenceType.pain => Icons.bolt_outlined,
        WillMirrorEvidenceType.cost => Icons.balance_outlined,
        WillMirrorEvidenceType.counterexample => Icons.gavel_outlined,
      };
}

class WillMirrorEvidenceCapturePage extends StatefulWidget {
  const WillMirrorEvidenceCapturePage({
    super.key,
    required this.vault,
    required this.goal,
    required this.type,
    this.hypothesis,
    this.relation,
  });

  final WillMirrorVault vault;
  final WillMirrorGoal goal;
  final WillMirrorEvidenceType type;
  final WillMirrorHypothesis? hypothesis;
  final WillMirrorRelation? relation;

  @override
  State<WillMirrorEvidenceCapturePage> createState() =>
      _WillMirrorEvidenceCapturePageState();
}

class _WillMirrorEvidenceCapturePageState
    extends State<WillMirrorEvidenceCapturePage> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  String _lifeStage = '当前阶段';
  String _domain = '日常生活';
  int _intensity = 6;
  int _duration = 2;
  int _cost = 2;
  int _energyBefore = 5;
  int _energyAfter = 6;
  int _repeatWish = 6;
  bool _audience = false;
  bool _requested = false;
  bool _reward = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title.text = switch (widget.type) {
      WillMirrorEvidenceType.realMe => '',
      WillMirrorEvidenceType.action => '',
      WillMirrorEvidenceType.pain => '失去选择权',
      WillMirrorEvidenceType.cost => '时间与精力代价',
      WillMirrorEvidenceType.counterexample => '',
    };
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请写下具体发生了什么')),
      );
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now().millisecondsSinceEpoch;
    final evidence = WillMirrorLifeEvidence(
      id: WillMirrorIds.next('evidence'),
      goalId: widget.goal.id,
      type: widget.type,
      title: _title.text.trim(),
      note: _note.text.trim(),
      lifeStage: _lifeStage,
      domain: _domain,
      intensity: _intensity,
      duration: _duration,
      costLevel: _cost,
      audiencePresent: _audience,
      externallyRequested: _requested,
      rewardPresent: _reward,
      energyBefore: _energyBefore,
      energyAfter: _energyAfter,
      repeatWish: _repeatWish,
      occurredAt: now,
      createdAt: now,
    );
    try {
      await widget.vault.saveEvidence(evidence);
      final hypothesis = widget.hypothesis;
      if (hypothesis != null) {
        await widget.vault.linkEvidence(
          WillMirrorHypothesisEvidence(
            hypothesisId: hypothesis.id,
            evidenceId: evidence.id,
            relation: widget.relation ?? WillMirrorRelation.supports,
            weight: _weightFor(widget.type),
            contextLimit: widget.relation == WillMirrorRelation.limits
                ? _note.text.trim()
                : '',
          ),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('安全保存失败：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      appBar: AppBar(
        title: Text(widget.type.label),
        backgroundColor: const Color(0xFFFAFBF9),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Text(
            widget.type.prompt,
            style: const TextStyle(
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: WillMirrorPalette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _helperFor(widget.type),
            style: const TextStyle(
              color: WillMirrorPalette.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _title,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: '具体事实/选择',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 8,
            maxLength: 1200,
            decoration: const InputDecoration(
              labelText: '发生经过与限制条件',
              hintText: '只写你确实知道的事实；不知道的原因可以明确写“不知道”。',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _lifeStage,
                  decoration: const InputDecoration(
                    labelText: '人生阶段',
                    border: OutlineInputBorder(),
                  ),
                  items: const <String>[
                    '童年',
                    '求学阶段',
                    '早期工作',
                    '职业转换',
                    '关系经历',
                    '家庭阶段',
                    '当前阶段',
                  ]
                      .map((item) =>
                          DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _lifeStage = value ?? _lifeStage),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _domain,
                  decoration: const InputDecoration(
                    labelText: '领域',
                    border: OutlineInputBorder(),
                  ),
                  items: const <String>[
                    '日常生活',
                    '学习',
                    '工作/事业',
                    '亲密关系',
                    '家庭',
                    '金钱',
                    '健康',
                    '创造/贡献',
                  ]
                      .map((item) =>
                          DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _domain = value ?? _domain),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _slider('事件强度', _intensity,
              (value) => setState(() => _intensity = value)),
          _slider('持续性（一次→长期）', _duration,
              (value) => setState(() => _duration = value)),
          _slider('真实代价', _cost, (value) => setState(() => _cost = value)),
          if (widget.type == WillMirrorEvidenceType.realMe) ...<Widget>[
            _slider('做之前能量', _energyBefore,
                (value) => setState(() => _energyBefore = value)),
            _slider('做之后能量', _energyAfter,
                (value) => setState(() => _energyAfter = value)),
            _slider('希望再次做', _repeatWish,
                (value) => setState(() => _repeatWish = value)),
          ],
          const Divider(height: 26),
          SwitchListTile(
            value: _requested,
            contentPadding: EdgeInsets.zero,
            title: const Text('有人要求我这样做'),
            onChanged: (value) => setState(() => _requested = value),
          ),
          SwitchListTile(
            value: _audience,
            contentPadding: EdgeInsets.zero,
            title: const Text('当时有观众或会被别人知道'),
            onChanged: (value) => setState(() => _audience = value),
          ),
          SwitchListTile(
            value: _reward,
            contentPadding: EdgeInsets.zero,
            title: const Text('当时有明确外部奖励'),
            onChanged: (value) => setState(() => _reward = value),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_outline),
            label: Text(_saving ? '正在加密保存…' : '加密保存到本机 Vault'),
          ),
        ],
      ),
    );
  }

  Widget _slider(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: <Widget>[
        SizedBox(width: 128, child: Text('$label · $value')),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (next) => onChanged(next.round()),
          ),
        ),
      ],
    );
  }

  static double _weightFor(WillMirrorEvidenceType type) => switch (type) {
        WillMirrorEvidenceType.action => 1,
        WillMirrorEvidenceType.cost => 0.9,
        WillMirrorEvidenceType.counterexample => 1,
        WillMirrorEvidenceType.realMe => 0.6,
        WillMirrorEvidenceType.pain => 0.7,
      };

  static String _helperFor(WillMirrorEvidenceType type) => switch (type) {
        WillMirrorEvidenceType.realMe =>
          '记录主动/被迫、观众、奖励和能量变化。它只是候选证据，不会单独证明性格。',
        WillMirrorEvidenceType.action =>
          '区分“嘴上想做”与最终真实选择，同时记录资源、能力、责任和环境限制。',
        WillMirrorEvidenceType.pain =>
          '尽量区分被否定、被忽视、被比较、别人不同意、别人真正阻止、失去选择权、关系失去、失败或资源不足。',
        WillMirrorEvidenceType.cost =>
          '可记录时间、金钱、舒适、机会、社会认可、关系风险和学习努力。',
        WillMirrorEvidenceType.counterexample =>
          '请寻找真正可能推翻当前候选的经历，而不是无关的小例外。强反例不会被多个弱支持证据淹没。',
      };
}
