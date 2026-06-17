import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SelfDiscoveryHomePage extends StatelessWidget {
  const SelfDiscoveryHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('自我发现'),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          _HeroCard(),
          const SizedBox(height: 16),
          _ModuleCard(
            icon: Icons.directions_walk_outlined,
            title: '足下一致行动系统',
            subtitle: '用最小行动制造真实证据，用真实证据重塑自我认同。',
            enabled: true,
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const FootstepConsistencyPage()),
            ),
          ),
          const SizedBox(height: 12),
          const _ModuleCard(
            icon: Icons.explore_outlined,
            title: '价值地图',
            subtitle: '预留：澄清长期价值、人生方向与选择优先级。',
          ),
          const SizedBox(height: 12),
          const _ModuleCard(
            icon: Icons.psychology_alt_outlined,
            title: '内在模式镜像',
            subtitle: '预留：识别反复出现的防御、脚本与关系模式。',
          ),
          const SizedBox(height: 12),
          const _ModuleCard(
            icon: Icons.auto_graph_outlined,
            title: '身份成长账本',
            subtitle: '预留：把长期行动沉淀为稳定的身份材料。',
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x22312E81), blurRadius: 18, offset: Offset(0, 10))],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('不是等到相信才行动', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text('而是在行动中重新相信。这里将承载 4 个自我发现子模块，先从“足下一致行动系统”开始。', style: TextStyle(color: Color(0xFFEDE9FE), height: 1.5)),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  const _ModuleCard({required this.icon, required this.title, required this.subtitle, this.enabled = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: enabled ? const Color(0xFFDDD6FE) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: enabled ? const Color(0xFFEDE9FE) : const Color(0xFFF1F5F9), child: Icon(icon, color: enabled ? const Color(0xFF6D28D9) : const Color(0xFF94A3B8))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.35)),
            ])),
            Icon(enabled ? Icons.chevron_right : Icons.lock_outline, color: const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

class FootstepConsistencyPage extends StatefulWidget {
  const FootstepConsistencyPage({super.key});

  @override
  State<FootstepConsistencyPage> createState() => _FootstepConsistencyPageState();
}

class _FootstepConsistencyPageState extends State<FootstepConsistencyPage> {
  final _goalController = TextEditingController();
  final _valueController = TextEditingController();
  final _blockController = TextEditingController();
  _FootstepPlan? _plan;

  @override
  void dispose() {
    _goalController.dispose();
    _valueController.dispose();
    _blockController.dispose();
    super.dispose();
  }

  void _generatePlan() {
    final goal = _goalController.text.trim();
    if (goal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先写下一个想做但一直拖延的事情。')));
      return;
    }
    final value = _valueController.text.trim().isEmpty ? '更接近我真正重视的生活' : _valueController.text.trim();
    final block = _blockController.text.trim().isEmpty ? '目标太大、需要动力、害怕开始后做不好' : _blockController.text.trim();
    setState(() {
      _plan = _FootstepPlan.from(goal: goal, value: value, block: block);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFF),
      appBar: AppBar(title: const Text('足下一致行动系统'), backgroundColor: const Color(0xFFFAFAFF), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          const _IntroPanel(),
          const SizedBox(height: 14),
          _InputPanel(goalController: _goalController, valueController: _valueController, blockController: _blockController, onGenerate: _generatePlan),
          if (_plan != null) ...[
            const SizedBox(height: 16),
            _PlanPanel(plan: _plan!),
          ],
        ],
      ),
    );
  }
}

class _IntroPanel extends StatelessWidget {
  const _IntroPanel();

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Text('第一子模块 · 1 美元行动设计器', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B))),
        SizedBox(height: 8),
        Text('它不要求你立刻变得自律，而是帮你把“我不想做”转化为一个小到可以开始、真实到能留下证据的行动。', style: TextStyle(color: Color(0xFF475569), height: 1.5)),
        SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Pill('价值澄清'), _Pill('失调识别'), _Pill('最小行动'), _Pill('承诺卡'), _Pill('行动后解释'),
        ]),
      ]),
    );
  }
}

class _InputPanel extends StatelessWidget {
  final TextEditingController goalController;
  final TextEditingController valueController;
  final TextEditingController blockController;
  final VoidCallback onGenerate;

  const _InputPanel({required this.goalController, required this.valueController, required this.blockController, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('把一个拖延事件放进系统', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _Field(controller: goalController, label: '我最近一直想做但没做的事情', hint: '例如：学习心理学 / 开始运动 / 投简历'),
        _Field(controller: valueController, label: '这件事背后我可能重视的价值', hint: '例如：成长、健康、选择权、责任、自由'),
        _Field(controller: blockController, label: '我现在卡住的理由或逃避解释', hint: '例如：太累、怕失败、目标太大、没有动力'),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onGenerate, icon: const Icon(Icons.auto_awesome), label: const Text('生成 1 美元行动'))),
      ]),
    );
  }
}

class _PlanPanel extends StatelessWidget {
  final _FootstepPlan plan;
  const _PlanPanel({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _ResultCard('一、你现在的核心冲突', plan.conflict, Icons.compare_arrows_outlined),
      _ResultCard('二、这不是失败，而是改变入口', plan.entry, Icons.lightbulb_outline),
      _ResultCard('三、你的 1 美元行动', plan.action, Icons.directions_run_outlined, accent: const Color(0xFF059669)),
      _ResultCard('四、行动前承诺语', '我现在不是为了证明自己彻底改变，而是为了给自己一个新的证据：${plan.evidence}。', Icons.fact_check_outlined),
      _ResultCard('五、行动中提醒语', '现在不需要证明你有多强，只需要完成这个最小动作。', Icons.timer_outlined),
      _ResultCard('六、行动后解释', '这次行动虽然很小，但它说明${plan.afterMeaning}。它打破了“${plan.oldStory}”。它支持我成为${plan.identity}。', Icons.badge_outlined),
      _ResultCard('七、下一步', plan.nextStep, Icons.trending_up_outlined),
      _ResultCard('八、风险提醒', '不要用完美主义否定这个小行动，也不要把它夸大成“我已经彻底改变”。它只是一个小证据，但它是真实的。', Icons.health_and_safety_outlined, accent: const Color(0xFFD97706)),
    ]);
  }
}

class _FootstepPlan {
  final String conflict;
  final String entry;
  final String action;
  final String evidence;
  final String afterMeaning;
  final String oldStory;
  final String identity;
  final String nextStep;

  const _FootstepPlan({required this.conflict, required this.entry, required this.action, required this.evidence, required this.afterMeaning, required this.oldStory, required this.identity, required this.nextStep});

  factory _FootstepPlan.from({required String goal, required String value, required String block}) {
    final action = '现在先打开与“$goal”有关的第一个入口，只做 3 分钟；结束后写一句：这个小动作和“$value”有什么关系。';
    return _FootstepPlan(
      conflict: '你可能重视“$value”，也知道“$goal”对你有意义，但当前行为被“$block”卡住。冲突点不在于你完全不想改变，而在于旧解释正在把行动门槛抬得太高。',
      entry: '认知失调说明旧自我和新方向正在摩擦。现在不需要靠自责降低不舒服，而是用一个足够小、足够真实的行动，让行为稍微靠近价值。',
      action: action,
      evidence: '我可以在动力不足时，仍然为“$goal”启动 3 分钟',
      afterMeaning: '我不是只能停在“$block”里，我已经让行为朝“$value”移动了一小步',
      oldStory: '必须有强烈动力或完整计划才可以开始',
      identity: '一个能用小行动靠近自己价值的人',
      nextStep: '明天重复同一个 3 分钟动作；如果阻力明显下降，只轻微升级到 5 分钟，不增加多个任务。',
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final Color accent;

  const _ResultCard(this.title, this.content, this.icon, {this.accent = const Color(0xFF7C3AED)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _GlassPanel(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 18, backgroundColor: accent.withOpacity(0.12), child: Icon(icon, size: 19, color: accent)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF111827))),
            const SizedBox(height: 6),
            Text(content, style: const TextStyle(color: Color(0xFF475569), height: 1.5)),
          ])),
        ]),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  const _Field({required this.controller, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: 3,
        decoration: InputDecoration(labelText: label, hintText: hint, filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0)))),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFEDE9FE))),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(color: Color(0xFF5B21B6), fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
