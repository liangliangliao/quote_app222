import 'package:flutter/material.dart';

import 'zhixing_models.dart';
import 'zhixing_repository.dart';

class ZhixingActionPage extends StatefulWidget {
  final ZhixingRepository repository;
  final ZhixingPrescription initialAction;

  const ZhixingActionPage({
    super.key,
    required this.repository,
    required this.initialAction,
  });

  @override
  State<ZhixingActionPage> createState() => _ZhixingActionPageState();
}

class _ZhixingActionPageState extends State<ZhixingActionPage> {
  late ZhixingPrescription _action;
  bool _busy = false;

  static const Color _green = Color(0xFF247A57);
  static const Color _ink = Color(0xFF17352C);

  @override
  void initState() {
    super.initState();
    _action = widget.initialAction;
  }

  Future<void> _begin() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.beginAction(_action);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!mounted) return;
      setState(() {
        _action = _action.copyWith(
          status: ZhixingActionStatus.started,
          startedAtMs: _action.startedAtMs ?? now,
          updatedAtMs: now,
        );
      });
      _toast('已经开始。现在只看第一身体动作。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showStuck() async {
    final strategy = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAF8),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '我卡住了',
                style: TextStyle(color: _ink, fontSize: 23, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                '卡住不是失败。选择当前真正需要的一种调整。',
                style: TextStyle(color: Color(0xFF6B7771), height: 1.45),
              ),
              const SizedBox(height: 14),
              _StuckTile(
                icon: Icons.compress_rounded,
                color: const Color(0xFF3F7CAC),
                title: '缩小',
                subtitle: _action.stuckShrink,
                onTap: () => Navigator.pop(context, 'shrink'),
              ),
              _StuckTile(
                icon: Icons.tune_rounded,
                color: const Color(0xFF9B6C2D),
                title: '顺势',
                subtitle: _action.stuckAdapt,
                onTap: () => Navigator.pop(context, 'adapt'),
              ),
              _StuckTile(
                icon: Icons.waves_rounded,
                color: const Color(0xFF7A57A1),
                title: '带着它做',
                subtitle: _action.stuckCarry,
                onTap: () => Navigator.pop(context, 'carry'),
              ),
              _StuckTile(
                icon: Icons.alt_route_rounded,
                color: const Color(0xFFB54B4B),
                title: '重新判断',
                subtitle: _action.stuckReconsider,
                onTap: () => Navigator.pop(context, 'reconsider'),
              ),
            ],
          ),
        ),
      ),
    );
    if (strategy == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.repository.applyStuckStrategy(_action, strategy);
      if (!mounted) return;
      setState(() => _action = updated);
      _toast(strategy == 'reconsider' ? '已暂停硬推，回到目标与条件检查。' : '已调整为当前可承受版本。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish({required bool completed}) async {
    if (_busy) return;
    final evidence = await showModalBottomSheet<ZhixingEvidence>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF8FAF8),
      builder: (_) => _FeedbackSheet(
        action: _action,
        completed: completed,
      ),
    );
    if (evidence == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (completed) {
        final reward = await widget.repository.completeAction(_action, evidence);
        if (!mounted) return;
        if (_action.isSafetyRoute) {
          await _showSafetyRecorded();
        } else {
          await _showReward(reward);
        }
      } else {
        await widget.repository.recalibrateAction(_action, evidence);
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.tune_rounded, color: _green, size: 34),
            title: const Text('这不是惩罚，而是校准'),
            content: const Text(
              '未完成不会扣金币、不会降级，也不要求补偿。你的反馈已用于调整下一张知行卡。',
              style: TextStyle(height: 1.55),
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      _toast('保存反馈失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showReward(ZhixingRewardResult reward) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          reward.returnBonus ? Icons.restore_rounded : Icons.eco_rounded,
          color: _green,
          size: 38,
        ),
        title: Text(reward.returnBonus ? '欢迎复归' : '现实行动已经成为证据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (reward.alreadySettled)
              const Text('这张卡已经结算过，本次没有重复发放奖励。')
            else ...<Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _RewardPill(icon: Icons.bolt_rounded, text: '+${reward.grantedXp} 经验'),
                  const SizedBox(width: 8),
                  _RewardPill(icon: Icons.monetization_on_outlined, text: '+${reward.grantedCoins} 金币'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                reward.returnBonus
                    ? '系统额外奖励了复归能力。中断之后重新开始，比维持完美连续更重要。'
                    : '奖励的是你可控制的现实行动，而不是外部结果。',
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.5, color: Color(0xFF617068)),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: () => Navigator.pop(context),
            child: const Text('看看知行树'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSafetyRecorded() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.health_and_safety_outlined,
          color: Color(0xFFB54B4B),
          size: 38,
        ),
        title: const Text('已经连接到现实支持'),
        content: const Text(
          '这条联系记录已保存，但不会进入经验、金币或树木成长结算。请继续遵循真实支持人员给出的安全安排。',
          style: TextStyle(height: 1.55),
        ),
        actions: <Widget>[
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB54B4B)),
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final safety = _action.isSafetyRoute;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F3),
        surfaceTintColor: Colors.transparent,
        title: const Text('今日知行卡'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _Tag(
                        text: _action.challengeType.label,
                        color: safety ? const Color(0xFFB54B4B) : _green,
                      ),
                      const SizedBox(width: 8),
                      _Tag(
                        text: _action.difficulty.label,
                        color: const Color(0xFF476E8E),
                      ),
                      const Spacer(),
                      Text(
                        _statusLabel(_action.status),
                        style: const TextStyle(
                          color: Color(0xFF69766F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_action.safetyMessage.isNotEmpty)
                    _SafetyBanner(message: _action.safetyMessage),
                  if (_action.safetyMessage.isNotEmpty) const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: safety
                            ? const <Color>[Color(0xFFFFF1ED), Color(0xFFFFFAF8)]
                            : const <Color>[Color(0xFFE5F2EA), Color(0xFFF7FBF8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: safety ? const Color(0xFFF0C7BC) : const Color(0xFFCDE2D6),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _action.title,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 24,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '服务于：${_action.value}',
                          style: TextStyle(
                            color: safety ? const Color(0xFFA14141) : _green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          '唯一现实行动',
                          style: TextStyle(
                            color: Color(0xFF69766F),
                            fontSize: 12,
                            letterSpacing: .8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _action.action,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 19,
                            height: 1.52,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ActionField(
                    icon: Icons.schedule_rounded,
                    title: '触发条件',
                    body: _action.trigger,
                    color: const Color(0xFF3F7CAC),
                  ),
                  const SizedBox(height: 10),
                  _ActionField(
                    icon: Icons.touch_app_outlined,
                    title: '第一身体动作',
                    body: _action.firstPhysicalAction,
                    color: const Color(0xFF9B6C2D),
                  ),
                  const SizedBox(height: 10),
                  _ActionField(
                    icon: Icons.fact_check_outlined,
                    title: '完成证据',
                    body: _action.successEvidence,
                    color: _green,
                  ),
                  const SizedBox(height: 16),
                  _thoughtCard(),
                  if (!safety) ...<Widget>[
                    const SizedBox(height: 14),
                    _rewardCard(),
                  ],
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '${_action.provider} · ${_action.modelLabel}',
                      style: const TextStyle(
                        color: Color(0xFF8A958F),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _bottomBar(safety),
          ],
        ),
      ),
    );
  }

  Widget _thoughtCard() {
    final match = _action.thoughtMatch;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E8E3)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.hub_outlined, color: _green),
        title: const Text(
          '思想匹配',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          match.dominant,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: <Widget>[
          _MatchRow(label: '主导思想', value: match.dominant),
          _MatchRow(label: '执行工具', value: match.executionTool),
          if (match.assistants.isNotEmpty)
            _MatchRow(label: '辅助思想', value: match.assistants.join('；')),
          _MatchRow(label: '制衡思想', value: match.balancing),
          _MatchRow(label: '为什么适配', value: match.rationale),
          _MatchRow(label: '误用边界', value: match.boundary),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const Icon(Icons.analytics_outlined, size: 17, color: Color(0xFF78857F)),
              const SizedBox(width: 6),
              Text(
                '匹配置信度 ${(match.confidence * 100).round()}% · 启发式而非临床诊断',
                style: const TextStyle(color: Color(0xFF78857F), fontSize: 12),
              ),
            ],
          ),
          if (match.sources.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '来源类型：${match.sources.join('；')}',
              style: const TextStyle(color: Color(0xFF78857F), fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rewardCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E3AE)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.eco_outlined, color: Color(0xFF9B772D)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '完成可获得 ${_action.rewardXp} 经验、${_action.rewardCoins} 金币'
              '${_resourceRewardText()}',
              style: const TextStyle(color: Color(0xFF5D4A1C), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _resourceRewardText() {
    final values = <String>[];
    if (_action.rewardWater > 0) values.add('${_action.rewardWater} 水');
    if (_action.rewardSunlight > 0) values.add('${_action.rewardSunlight} 阳光');
    if (_action.rewardFertilizer > 0) values.add('${_action.rewardFertilizer} 肥料');
    return values.isEmpty ? '' : '、${values.join('、')}';
  }

  Widget _bottomBar(bool safety) {
    final ready = _action.status == ZhixingActionStatus.ready;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F7F3),
        border: Border(top: BorderSide(color: Color(0xFFE0E7E2))),
      ),
      child: SafeArea(
        top: false,
        child: ready
            ? FilledButton.icon(
                onPressed: _busy ? null : _begin,
                style: FilledButton.styleFrom(
                  backgroundColor: safety ? const Color(0xFFB54B4B) : _green,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                ),
                icon: Icon(safety ? Icons.support_agent_rounded : Icons.play_arrow_rounded),
                label: Text(
                  safety ? '现在开始联系真实支持' : '开始行动',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              )
            : Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _showStuck,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: _green,
                        side: const BorderSide(color: _green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('我卡住了', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _busy ? null : () => _finish(completed: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: safety ? const Color(0xFFB54B4B) : _green,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        safety ? '已联系到支持' : '完成并记录证据',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    enabled: !_busy,
                    tooltip: '更多',
                    onSelected: (value) {
                      if (value == 'recalibrate') _finish(completed: false);
                    },
                    itemBuilder: (_) => const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'recalibrate',
                        child: Text('未完成，重新校准'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  String _statusLabel(ZhixingActionStatus status) {
    switch (status) {
      case ZhixingActionStatus.ready:
        return '待开始';
      case ZhixingActionStatus.started:
        return '行动中';
      case ZhixingActionStatus.blocked:
        return '已调整';
      case ZhixingActionStatus.completed:
        return '已完成';
      case ZhixingActionStatus.recalibrate:
        return '待校准';
    }
  }
}

class _FeedbackSheet extends StatefulWidget {
  final ZhixingPrescription action;
  final bool completed;

  const _FeedbackSheet({
    required this.action,
    required this.completed,
  });

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final TextEditingController _fact = TextEditingController();
  final TextEditingController _learning = TextEditingController();
  final TextEditingController _next = TextEditingController();
  double _predicted = 5;
  double _actual = 5;
  String _fit = '部分准确';
  String _scale = '合适';

  @override
  void initState() {
    super.initState();
    _fact.text = widget.completed ? widget.action.successEvidence : '';
  }

  @override
  void dispose() {
    _fact.dispose();
    _learning.dispose();
    _next.dispose();
    super.dispose();
  }

  void _submit() {
    if (_fact.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请记录一条事实结果。')),
      );
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    Navigator.of(context).pop(
      ZhixingEvidence(
        id: 'zxe_${now}_${widget.action.id.hashCode.abs()}',
        prescriptionId: widget.action.id,
        createdAtMs: now,
        completed: widget.completed,
        predictedDiscomfort: _predicted,
        actualDiscomfort: _actual,
        fit: _fit,
        scale: _scale,
        factResult: _fact.text.trim(),
        learning: _learning.text.trim(),
        nextStep: _next.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 4, 18, 18 + bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.completed ? '记录行动证据' : '重新校准，不惩罚',
                style: const TextStyle(
                  color: Color(0xFF17352C),
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                '最多三组问题。记录事实，不做人格审判。',
                style: TextStyle(color: Color(0xFF69766F)),
              ),
              const SizedBox(height: 20),
              const _QuestionTitle('1 · 行动前预测与实际不适'),
              _LabeledSlider(
                label: '行动前预测',
                value: _predicted,
                onChanged: (value) => setState(() => _predicted = value),
              ),
              _LabeledSlider(
                label: '实际经历',
                value: _actual,
                onChanged: (value) => setState(() => _actual = value),
              ),
              const SizedBox(height: 15),
              const _QuestionTitle('2 · 匹配是否准确，任务大小如何'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: <String>['准确', '部分准确', '不准确']
                    .map(
                      (value) => ChoiceChip(
                        label: Text(value),
                        selected: _fit == value,
                        onSelected: (_) => setState(() => _fit = value),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: <String>['太小', '合适', '太大']
                    .map(
                      (value) => ChoiceChip(
                        label: Text(value),
                        selected: _scale == value,
                        onSelected: (_) => setState(() => _scale = value),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              const _QuestionTitle('3 · 事实、学习与下一步'),
              const SizedBox(height: 9),
              TextField(
                controller: _fact,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '事实发生了什么？',
                  hintText: '只写可观察事实',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _learning,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '学到了什么？（选填）',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _next,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '下一步怎样保持、缩小或调整？（选填）',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF247A57),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  widget.completed
                      ? (widget.action.isSafetyRoute ? '保存联系记录' : '保存证据并领取奖励')
                      : '保存校准，不扣奖励',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 78,
          child: Text(label, style: const TextStyle(color: Color(0xFF607068))),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 10,
            divisions: 10,
            activeColor: const Color(0xFF247A57),
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 24,
          child: Text(
            value.round().toString(),
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _QuestionTitle extends StatelessWidget {
  final String text;

  const _QuestionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF17352C),
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _StuckTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _StuckTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE3E9E5)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _ActionField extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _ActionField({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE1E8E3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF6B7771),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF17352C),
                    fontSize: 15,
                    height: 1.42,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  final String label;
  final String value;

  const _MatchRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF718078),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF29453B),
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  final String message;

  const _SafetyBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECE8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9B8AC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.health_and_safety_outlined, color: Color(0xFFB54B4B)),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF713B37),
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _RewardPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6D8),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: const Color(0xFF9B772D)),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
