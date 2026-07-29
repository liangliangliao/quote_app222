import 'package:flutter/material.dart';

import 'zhixing_action_page.dart';
import 'zhixing_ai_service.dart';
import 'zhixing_engine.dart';
import 'zhixing_models.dart';
import 'zhixing_repository.dart';

class ZhixingDiagnosisPage extends StatefulWidget {
  final ZhixingRepository repository;
  final String initialProblem;

  const ZhixingDiagnosisPage({
    super.key,
    required this.repository,
    this.initialProblem = '',
  });

  @override
  State<ZhixingDiagnosisPage> createState() => _ZhixingDiagnosisPageState();
}

class _ZhixingDiagnosisPageState extends State<ZhixingDiagnosisPage> {
  late final PageController _pages;
  late final TextEditingController _problemController;
  late final TextEditingController _noteController;
  late final ZhixingAiService _ai;
  final ZhixingEngine _engine = ZhixingEngine();
  final Set<String> _values = <String>{};

  int _step = 0;
  String _autonomy = 'partly';
  String _clarity = 'vague';
  String _barrier = 'thought';
  String _discomfort = 'moderate';
  String _experience = 'sometimes';
  String _phase = 'start';
  double _minutes = 10;
  bool _generating = false;
  String _generationStatus = '';

  static const int _stepCount = 7;
  static const Color _green = Color(0xFF247A57);
  static const Color _ink = Color(0xFF17352C);

  @override
  void initState() {
    super.initState();
    _pages = PageController();
    _problemController = TextEditingController(text: widget.initialProblem);
    _noteController = TextEditingController();
    _ai = ZhixingAiService(engine: _engine);
  }

  @override
  void dispose() {
    _pages.dispose();
    _problemController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_step == 0 && _problemController.text.trim().length < 2) {
      _toast('请先写下一个具体的“知道但还没有做到”。');
      return;
    }
    if (_step < _stepCount - 1) {
      setState(() => _step += 1);
      await _pages.animateToPage(
        _step,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _generate();
  }

  Future<void> _back() async {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step -= 1);
    await _pages.animateToPage(
      _step,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _generate() async {
    if (_generating) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final problem = _problemController.text.trim();
    final risk = _engine.detectRisk(problem, discomfort: _discomfort);
    final diagnosis = ZhixingDiagnosis(
      id: 'zxd_${now}_${problem.hashCode.abs()}',
      createdAtMs: now,
      problem: problem,
      autonomy: _autonomy,
      clarity: _clarity,
      barrier: _barrier,
      discomfort: _discomfort,
      experience: _experience,
      phase: _phase,
      availableMinutes: _minutes.round(),
      values: _values.toList(),
      note: _noteController.text.trim(),
      risk: risk,
    );
    setState(() {
      _generating = true;
      _generationStatus = '正在识别行动断点与安全边界…';
    });
    try {
      await widget.repository.saveDiagnosis(diagnosis);
      final oldProfile = await widget.repository.loadProfile();
      final profile = _engine.profileAfterDiagnosis(oldProfile, diagnosis);
      await widget.repository.saveProfile(profile);
      if (mounted) {
        setState(() => _generationStatus = '正在匹配主导思想、执行工具与制衡思想…');
      }
      final recent = await widget.repository.listActions(limit: 8);
      final summary = recent
          .map((item) =>
              '${item.challengeType.label}:${item.status.code}:${item.thoughtMatch.dominant}')
          .join('；');
      final result = await _ai.generate(
        diagnosis: diagnosis,
        profile: profile,
        historySummary: summary,
      );
      if (mounted) {
        setState(() => _generationStatus = '正在生成唯一的现实行动与完成证据…');
      }
      await widget.repository.saveAction(result.prescription);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ZhixingActionPage(
            repository: widget.repository,
            initialAction: result.prescription,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _toast('知行卡生成失败：$error');
      setState(() => _generating = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F3),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: _generating ? null : _back,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('六问知行诊断'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_step + 1}/$_stepCount',
                style: const TextStyle(
                  color: _green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / _stepCount,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFDCE7E0),
                    color: _green,
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    _problemStep(),
                    _choiceStep(
                      eyebrow: '问题 1 · 价值自主度',
                      title: '这是你真正愿意做的目标吗？',
                      body: '先确认方向，再谈效率。系统不会让你更高效地执行一个并不认同的目标。',
                      value: _autonomy,
                      options: const <_Choice>[
                        _Choice('yes', '是，我自己认同', '即使没人评价，我仍愿意为它投入。', Icons.favorite_outline),
                        _Choice('partly', '部分认同', '有自己的需要，也混合了责任或外界期待。', Icons.balance_outlined),
                        _Choice('no', '主要不是', '更多是证明、取悦、逃避羞耻或别人要求。', Icons.people_outline),
                      ],
                      onChanged: (value) => setState(() => _autonomy = value),
                    ),
                    _choiceStep(
                      eyebrow: '问题 2 · 行动清晰度',
                      title: '你知道下一步具体是什么吗？',
                      body: '“改变人生”不是动作。一个合格的下一步能被摄像机看到，或留下客观证据。',
                      value: _clarity,
                      options: const <_Choice>[
                        _Choice('clear', '清楚', '我能说出时间、第一动作与完成标准。', Icons.visibility_outlined),
                        _Choice('vague', '大概知道', '有方向，但第一动作和完成证据仍模糊。', Icons.blur_on_outlined),
                        _Choice('none', '不知道', '目标太大、选项太多，或缺少必要信息。', Icons.help_outline_rounded),
                      ],
                      onChanged: (value) => setState(() => _clarity = value),
                    ),
                    _choiceStep(
                      eyebrow: '问题 3 · 主要断点',
                      title: '现在最主要的阻碍是什么？',
                      body: '相同的“不行动”可能来自完全不同的机制。只选最核心的一项。',
                      value: _barrier,
                      compact: true,
                      options: const <_Choice>[
                        _Choice('thought', '思想与解释', '灾难化、绝对化、完美主义或反复分析。', Icons.psychology_outlined),
                        _Choice('emotion', '情绪与不适', '恐惧、焦虑、羞耻或需要情绪先消失。', Icons.waves_outlined),
                        _Choice('ability', '能力与经验', '技能、练习或“我做得到”的证据不足。', Icons.fitness_center_outlined),
                        _Choice('environment', '环境与机会', '时间、工具、权限、支持或干扰问题。', Icons.domain_outlined),
                        _Choice('energy', '疲劳与恢复', '睡眠不足、过载、注意力或身体资源下降。', Icons.battery_1_bar_outlined),
                        _Choice('meaning', '意义与方向', '目标不自主、价值冲突或不值得继续。', Icons.explore_outlined),
                      ],
                      onChanged: (value) => setState(() => _barrier = value),
                    ),
                    _choiceStep(
                      eyebrow: '问题 4 · 当前承受范围',
                      title: '此刻的不适强度如何？',
                      body: '这用于决定任务强度，不是要求你证明坚强。无法承受时，安全与支持优先。',
                      value: _discomfort,
                      options: const <_Choice>[
                        _Choice('mild', '轻微', '能注意到，但不明显妨碍行动。', Icons.sentiment_satisfied_alt_outlined),
                        _Choice('moderate', '中等', '有阻力，但小步行动仍可承受。', Icons.sentiment_neutral_outlined),
                        _Choice('strong', '强烈', '明显回避，需要更小、更柔和的分级任务。', Icons.warning_amber_rounded),
                        _Choice('unbearable', '无法承受', '已经超出普通自助行动的安全范围。', Icons.health_and_safety_outlined),
                      ],
                      onChanged: (value) => setState(() => _discomfort = value),
                    ),
                    _choiceStep(
                      eyebrow: '问题 5 · 掌握经验',
                      title: '过去完成过类似行动吗？',
                      body: '自信不靠口号产生。真实完成史决定当前阶梯应从哪里开始。',
                      value: _experience,
                      options: const <_Choice>[
                        _Choice('never', '几乎没有', '需要从最小掌握经验开始。', Icons.looks_one_outlined),
                        _Choice('sometimes', '偶尔完成', '已经有证据，但还不稳定。', Icons.stacked_line_chart_outlined),
                        _Choice('success', '多次完成', '可以尝试略高一级并获取反馈。', Icons.verified_outlined),
                      ],
                      onChanged: (value) => setState(() => _experience = value),
                    ),
                    _choiceStep(
                      eyebrow: '问题 6 · 断裂发生的位置',
                      title: '你主要卡在开始、持续，还是复归？',
                      body: '中断后重新开始是一种独立能力，甚至比连续打卡更重要。',
                      value: _phase,
                      options: const <_Choice>[
                        _Choice('start', '无法开始', '知道方向，却迟迟没有第一动作。', Icons.play_circle_outline_rounded),
                        _Choice('sustain', '难以持续', '能开始，但仪式、环境或恢复不足。', Icons.repeat_rounded),
                        _Choice('return', '中断后难复归', '一次中断容易变成全面放弃。', Icons.restore_rounded),
                      ],
                      onChanged: (value) => setState(() => _phase = value),
                    ),
                    _resourceStep(),
                  ],
                ),
              ),
              _bottomBar(),
            ],
          ),
          if (_generating) _generatingOverlay(),
        ],
      ),
    );
  }

  Widget _problemStep() {
    const allValues = <String>[
      '成长',
      '健康',
      '学习',
      '创造',
      '关系',
      '家庭',
      '自由',
      '责任',
      '真诚',
      '贡献',
      '意义',
      '专业',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: <Widget>[
        const _Eyebrow('表达 · 一个当前问题'),
        const SizedBox(height: 10),
        const Text(
          '你知道应该做、但还没有做的是什么？',
          style: TextStyle(
            color: _ink,
            fontSize: 27,
            height: 1.22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '只写当前最重要的一件事。系统会把复杂理论隐藏在后台，最终只生成一张知行卡。',
          style: TextStyle(color: Color(0xFF65736D), fontSize: 15, height: 1.55),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _problemController,
          minLines: 5,
          maxLines: 8,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: '例如：我知道需要找工作，但一想到被拒绝就迟迟不投递……',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: _green, width: 1.6),
            ),
            contentPadding: const EdgeInsets.all(18),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '它主要服务于哪些价值？（可多选）',
          style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allValues.map((value) {
            final selected = _values.contains(value);
            return FilterChip(
              selected: selected,
              label: Text(value),
              checkmarkColor: Colors.white,
              selectedColor: _green,
              labelStyle: TextStyle(
                color: selected ? Colors.white : const Color(0xFF4B5E56),
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color: selected ? _green : const Color(0xFFD5E0D9),
              ),
              backgroundColor: Colors.white,
              onSelected: (enabled) {
                setState(() {
                  if (enabled) {
                    _values.add(value);
                  } else {
                    _values.remove(value);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _choiceStep({
    required String eyebrow,
    required String title,
    required String body,
    required String value,
    required List<_Choice> options,
    required ValueChanged<String> onChanged,
    bool compact = false,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: <Widget>[
        _Eyebrow(eyebrow),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 27,
            height: 1.22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: const TextStyle(
            color: Color(0xFF65736D),
            fontSize: 15,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 20),
        ...options.map(
          (option) => Padding(
            padding: EdgeInsets.only(bottom: compact ? 9 : 12),
            child: _ChoiceCard(
              option: option,
              selected: option.value == value,
              compact: compact,
              onTap: () => onChanged(option.value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _resourceStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: <Widget>[
        const _Eyebrow('校准 · 当前现实资源'),
        const SizedBox(height: 10),
        const Text(
          '今天真正可用多少时间？',
          style: TextStyle(
            color: _ink,
            fontSize: 27,
            height: 1.22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '行动尺度必须服从现实条件。时间少不等于失败，只意味着任务要更小。',
          style: TextStyle(color: Color(0xFF65736D), fontSize: 15, height: 1.55),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    '可用时间',
                    style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
                  ),
                  Text(
                    '${_minutes.round()} 分钟',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _green,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _minutes,
                min: 1,
                max: 60,
                divisions: 59,
                activeColor: _green,
                label: '${_minutes.round()} 分钟',
                onChanged: (value) => setState(() => _minutes = value),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('1 分钟', style: TextStyle(color: Color(0xFF78857F))),
                  Text('60 分钟', style: TextStyle(color: Color(0xFF78857F))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _noteController,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: '还有哪些必须考虑的现实条件？（选填）',
            hintText: '例如：只有手机、需要照顾家人、今晚很疲劳……',
            alignLabelWithHint: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: _green),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F2ED),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.verified_user_outlined, color: _green),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '你的行动、情绪与树木数据默认保存在本机。AI 只接收生成本次知行卡所需的最小上下文。',
                  style: TextStyle(color: _ink, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        decoration: const BoxDecoration(
          color: Color(0xFFF4F7F3),
          border: Border(top: BorderSide(color: Color(0xFFE3E9E5))),
        ),
        child: Row(
          children: <Widget>[
            if (_step > 0)
              TextButton.icon(
                onPressed: _generating ? null : _back,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('上一步'),
              ),
            if (_step > 0) const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _generating ? null : _next,
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(
                  _step == _stepCount - 1
                      ? Icons.auto_awesome_outlined
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(
                  _step == _stepCount - 1 ? '生成一张知行卡' : '继续',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _generatingOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xEAF4F7F3),
        child: Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x1A17352C),
                  blurRadius: 30,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(color: _green, strokeWidth: 4),
                ),
                const SizedBox(height: 18),
                const Text(
                  '正在把“知道”编译成“做到”',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _generationStatus,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF68766F), height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Choice {
  final String value;
  final String title;
  final String description;
  final IconData icon;

  const _Choice(this.value, this.title, this.description, this.icon);
}

class _ChoiceCard extends StatelessWidget {
  final _Choice option;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.option,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE4F1EA) : Colors.white,
      borderRadius: BorderRadius.circular(compact ? 16 : 18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.all(compact ? 13 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 16 : 18),
            border: Border.all(
              color: selected ? const Color(0xFF247A57) : const Color(0xFFE1E8E3),
              width: selected ? 1.7 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: compact ? 38 : 44,
                height: compact ? 38 : 44,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF247A57) : const Color(0xFFF0F4F1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  option.icon,
                  color: selected ? Colors.white : const Color(0xFF51645B),
                  size: compact ? 20 : 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      option.title,
                      style: const TextStyle(
                        color: Color(0xFF17352C),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      option.description,
                      style: const TextStyle(
                        color: Color(0xFF68766F),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? const Color(0xFF247A57) : const Color(0xFFC4CEC8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final String text;

  const _Eyebrow(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF247A57),
        fontSize: 12,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
