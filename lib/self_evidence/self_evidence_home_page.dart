import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/kv_dao.dart';
import '../pages/ai_prompt_settings_page.dart';
import 'self_evidence_ai_service.dart';
import 'self_evidence_prompt_config.dart';

class SelfEvidenceHomePage extends StatefulWidget {
  const SelfEvidenceHomePage({super.key});

  @override
  State<SelfEvidenceHomePage> createState() => _SelfEvidenceHomePageState();
}

class _SelfEvidenceHomePageState extends State<SelfEvidenceHomePage> with TickerProviderStateMixin {
  static const String _stateKey = 'self_evidence.state.v1';
  late final TabController _tab;
  final KeyValueDao _kv = KeyValueDao();
  final SelfEvidenceAiService _aiService = SelfEvidenceAiService();
  final TextEditingController _labelCtrl = TextEditingController(text: '我没有自律');
  final TextEditingController _eventCtrl = TextEditingController(text: '我今天一直拖延，不想打开项目。');
  final TextEditingController _actionCtrl = TextEditingController(text: '打开任务页面并做 5 分钟');
  final TextEditingController _durationCtrl = TextEditingController(text: '5');
  final List<_EvidenceCard> _cards = <_EvidenceCard>[];
  String _scene = 'procrastination';
  String _coach = '';
  bool _freeChoice = true;
  bool _externalReward = false;
  bool _externalPressure = false;
  bool _overcameInterference = true;
  double _difficulty = 6;
  bool _loading = true;
  bool _generating = false;
  String _lastCoachSource = '本地行动引擎';

  static const Map<String, String> _sceneLabels = <String, String>{
    'procrastination': '拖延与无法行动',
    'self_denial': '低自尊与自我否定',
    'choice': '选择困难与目标摇摆',
    'interference': '外界干扰与情绪触发',
    'review': '完成行动后的复盘',
    'reward': '奖励/监督/打卡依赖',
    'willpower': '目标坚持与意志力训练',
  };

  static const List<_ModuleSpec> _modules = <_ModuleSpec>[
    _ModuleSpec('自我标签诊断', Icons.label_outline, '把“我没有自律”等结论改写为待验证自我假设。', ['采集 3 个旧标签', '审查支持/反证证据', '转成今日行动问题']),
    _ModuleSpec('行为证据账本', Icons.inventory_2_outlined, '每次真实行动都沉淀为自我认知证据卡。', ['记录行为、情绪、时长', '计算启发式证据强度', '归类自律/勇气/恢复力']),
    _ModuleSpec('第三人称观察者镜像', Icons.visibility_outlined, '像观察别人一样观察自己，减少自我攻击。', ['观察者推断', '自我攻击转事实', '平衡判断']),
    _ModuleSpec('情境控制变量分析', Icons.tune_outlined, '分析睡眠、诱惑、压力、奖励、任务大小等变量。', ['奖励/压力识别', '失败情境复盘', '下一次变量调整']),
    _ModuleSpec('行动实验室', Icons.science_outlined, '用 30 秒到 5 分钟的小行动制造反标签证据。', ['最小行为证据', '反标签实验', '干扰后恢复训练']),
    _ModuleSpec('选择与偏好重建', Icons.alt_route_outlined, '把选择转化为偏好证据，而不是永久判决。', ['价值选择卡', '选择后小动作', '7 天证据再判断']),
    _ModuleSpec('情绪与态度澄清', Icons.psychology_outlined, '区分身体唤起、外部线索、解释与可观察事实。', ['情绪命名前检查', '情绪—情境分离表', '30 秒回归动作']),
    _ModuleSpec('AI 自我知觉教练', Icons.auto_awesome, '五种模式：证据侦探、观察者镜像、情境分析、行动实验、身份更新。', ['反内省绝对主义', '行为证据优先', '反过度心理化']),
    _ModuleSpec('周期性自我认知报告', Icons.summarize_outlined, '每日证据、每周观察者报告、每月身份证据更新。', ['今日自我证据', '本周观察者报告', '旧标签更新']),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 7, vsync: this);
    _coach = _buildCoachOutput();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _labelCtrl.dispose();
    _eventCtrl.dispose();
    _actionCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final raw = await _kv.getString(_stateKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['cards'] is List) {
          _cards.addAll((decoded['cards'] as List).whereType<Map>().map(_EvidenceCard.fromJson));
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async => _kv.setString(_stateKey, jsonEncode(<String, Object?>{'cards': _cards.map((e) => e.toJson()).toList()}));

  double _evidenceStrength() {
    var score = 42.0;
    if (_freeChoice) score += 16;
    if (!_externalReward) score += 10; else score -= 8;
    if (!_externalPressure) score += 10; else score -= 10;
    score += math.min(_difficulty, 8) * 3;
    if (_overcameInterference) score += 12;
    return score.clamp(0, 100).toDouble();
  }

  void _generateCoach() => setState(() {
        _coach = _buildCoachOutput();
        _lastCoachSource = '本地行动引擎';
      });

  Future<void> _generateCoachWithAi() async {
    final fallback = _buildCoachOutput();
    setState(() => _generating = true);
    try {
      final result = await _aiService.generate(
        userInput: _eventCtrl.text.trim(),
        scene: _scene,
        profileJson: jsonEncode(<String, Object?>{
          'old_label': _labelCtrl.text.trim(),
          'planned_action': _actionCtrl.text.trim(),
          'difficulty': _difficulty.round(),
          'free_choice': _freeChoice,
          'external_reward': _externalReward,
          'external_pressure': _externalPressure,
          'overcame_interference': _overcameInterference,
        }),
        recentContextJson: jsonEncode(<String, Object?>{
          'evidence_cards': _cards.take(10).map((e) => e.toJson()).toList(growable: false),
        }),
        fallback: fallback,
      );
      if (!mounted) return;
      setState(() {
        _coach = result.markdown;
        _lastCoachSource = result.usedAi ? 'AI 生成（使用统一配置中心 Prompt）' : '本地行动引擎';
      });
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _openPromptSettings([String? promptId]) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AiPromptSettingsPage(
        initialModuleId: SelfEvidencePromptConfig.moduleId,
        initialPromptId: promptId ?? SelfEvidencePromptConfig.globalId,
      ),
    ));
  }

  void _saveEvidenceCard() {
    final card = _EvidenceCard(
      createdAt: DateTime.now(),
      oldLabel: _labelCtrl.text.trim().isEmpty ? '未命名旧标签' : _labelCtrl.text.trim(),
      behavior: _actionCtrl.text.trim().isEmpty ? '最小行动' : _actionCtrl.text.trim(),
      durationMinutes: int.tryParse(_durationCtrl.text.trim()) ?? 5,
      difficulty: _difficulty.round(),
      freeChoice: _freeChoice,
      externalReward: _externalReward,
      externalPressure: _externalPressure,
      overcameInterference: _overcameInterference,
      strength: _evidenceStrength().round(),
      scene: _sceneLabels[_scene] ?? _scene,
    );
    setState(() => _cards.insert(0, card));
    _save();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已生成一张行为证据卡'), behavior: SnackBarBehavior.floating));
  }

  String _buildCoachOutput() {
    final label = _labelCtrl.text.trim().isEmpty ? '我做不到' : _labelCtrl.text.trim();
    final event = _eventCtrl.text.trim().isEmpty ? '当前没有补充情境' : _eventCtrl.text.trim();
    final action = _actionCtrl.text.trim().isEmpty ? '立刻完成一个 3 分钟最小动作' : _actionCtrl.text.trim();
    final sceneName = _sceneLabels[_scene] ?? '自我知觉训练';
    return '''【1. 当前自我判断】
你现在的判断更接近：“$label”。当前场景：$sceneName。现实材料：$event

【2. 这不是最终事实，而是待验证假设】
这句话先不当成终身结论，而当成“待验证自我假设”。自我描述需要回到行为、情境、自由选择、奖励压力和重复证据。

【3. 已有行为证据】
支持证据：请列出最近 7 天哪些具体行为让你相信它。
反驳证据：哪怕只有 30 秒，是否出现过“我不想做但仍做了一点”“被干扰后又回来”“无人监督仍选择目标”的行为？

【4. 情境控制变量】
重点检查：任务是否过大、下一步是否模糊、是否疲劳/睡眠不足、手机是否在旁边、是否有人监督、是否为了奖励或避免惩罚、是否有噪声/他人语言/消息触发。

【5. 第三人称观察者推断】
如果一个观察者看到你处在这些阻力中仍愿意做一点，他不会合理推断“这个人完全没救”，更可能推断：这个人启动成本偏高，但正在制造恢复行动的证据。

【6. 更准确的新解释】
把“$label”改写为：我现在不是完全没有能力，而是在特定情境下容易启动困难；我可以通过低门槛重复行动削弱旧标签。

【7. 今日最小行为证据】
请完成：$action。时间控制在 30 秒到 5 分钟内，目标不是证明你已经彻底改变，而是制造一条反证。

【8. 行动完成后的记录方式】
记录：行为名称、时间、持续时长、难度、当时情绪、是否自由选择、是否有外部奖励、是否有外部压力、是否克服干扰、它能证明的品质。

【9. 基于证据的新自我陈述】
完成后写：我不能仅凭一次行动证明自己已经完全改变，但今天我在当前情境下完成了“$action”，这说明“$label”这个旧标签并不绝对。

【10. 下一步】
现在先不要继续分析，启动计时器，完成第一步：$action。''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('自我证据 Self Evidence'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [IconButton(tooltip: 'AI 提示词统一配置', onPressed: () => _openPromptSettings(), icon: const Icon(Icons.tune_outlined))],
        bottom: TabBar(controller: _tab, isScrollable: true, tabs: const [
          Tab(text: '首页'), Tab(text: '标签诊断'), Tab(text: '行动实验室'), Tab(text: 'AI教练'), Tab(text: '证据账本'), Tab(text: '报告'), Tab(text: 'Prompt体系'),
        ]),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : TabBarView(controller: _tab, children: [_home(), _diagnosis(), _lab(), _coachTab(), _ledger(), _reports(), _prompts()]),
    );
  }

  Widget _home() => ListView(padding: const EdgeInsets.all(16), children: [
    _hero(), const SizedBox(height: 12),
    _section('今天你要制造哪一条自我证据？', '旧标签：${_labelCtrl.text}\n反证行动：${_actionCtrl.text}\n观察者问题：如果别人看到你完成这个行动，他会如何重新判断你？'),
    _strengthCard(),
    _moduleGrid(),
  ]);

  Widget _diagnosis() => ListView(padding: const EdgeInsets.all(16), children: [
    _section('自我标签诊断', '不要直接问“我到底是不是这样的人”，先把标签转成可验证、可行动、可更新的自我假设。'),
    TextField(controller: _labelCtrl, decoration: const InputDecoration(labelText: '当前旧标签 / 待验证假设', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    TextField(controller: _eventCtrl, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: '最近支持或反驳这个标签的行为证据', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: _generateCoach, icon: const Icon(Icons.psychology_alt_outlined), label: const Text('转成行为证据问题')),
    const SizedBox(height: 12), _markdown(_coach),
  ]);

  Widget _lab() => ListView(padding: const EdgeInsets.all(16), children: [
    _section('行动实验室', '用 30 秒到 5 分钟的真实行动制造新证据，而不是等待信心出现。'),
    DropdownButtonFormField<String>(value: _scene, decoration: const InputDecoration(labelText: '场景', border: OutlineInputBorder()), items: _sceneLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) => setState(() => _scene = v ?? _scene)),
    const SizedBox(height: 12),
    TextField(controller: _actionCtrl, decoration: const InputDecoration(labelText: '今日最小行为证据', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    TextField(controller: _durationCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '持续时长（分钟）', border: OutlineInputBorder())),
    Slider(value: _difficulty, min: 1, max: 10, divisions: 9, label: '难度 ${_difficulty.round()}/10', onChanged: (v) => setState(() => _difficulty = v)),
    SwitchListTile(value: _freeChoice, onChanged: (v) => setState(() => _freeChoice = v), title: const Text('这是自由选择的行动')),
    SwitchListTile(value: _externalReward, onChanged: (v) => setState(() => _externalReward = v), title: const Text('存在明显外部奖励')),
    SwitchListTile(value: _externalPressure, onChanged: (v) => setState(() => _externalPressure = v), title: const Text('存在明显外部压力/监督')),
    SwitchListTile(value: _overcameInterference, onChanged: (v) => setState(() => _overcameInterference = v), title: const Text('克服了干扰或不适')),
    _strengthCard(),
    FilledButton.icon(onPressed: _saveEvidenceCard, icon: const Icon(Icons.add_card_outlined), label: const Text('完成后生成行为证据卡')),
  ]);

  Widget _coachTab() => ListView(padding: const EdgeInsets.all(16), children: [
    _section('AI 自我知觉教练', '不急着安慰、不空喊激励、不把用户标签化；始终回到行为、情境、证据、选择和下一步行动。'),
    DropdownButtonFormField<String>(value: _scene, decoration: const InputDecoration(labelText: '调用场景 Prompt', border: OutlineInputBorder()), items: _sceneLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) => setState(() => _scene = v ?? _scene)),
    const SizedBox(height: 12),
    TextField(controller: _eventCtrl, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: '输入现实事件 / 自我判断 / 干扰情境', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: _generating ? null : _generateCoachWithAi, icon: Icon(_generating ? Icons.hourglass_top : Icons.auto_awesome), label: Text(_generating ? '正在生成...' : '生成 10 段式自我证据教练输出')),
    const SizedBox(height: 6),
    Text('生成来源：$_lastCoachSource', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
    const SizedBox(height: 12), _markdown(_coach),
  ]);

  Widget _ledger() => ListView(padding: const EdgeInsets.all(16), children: [
    _section('行为证据账本', '这里不是普通打卡，而是“我是什么样的人”的行为证据账本。证据强度为启发式评分，不是心理诊断。'),
    if (_cards.isEmpty) _section('暂无证据卡', '先去行动实验室完成一个 30 秒到 5 分钟行动。'),
    ..._cards.map(_cardWidget),
  ]);

  Widget _reports() {
    final count = _cards.length;
    final free = _cards.where((c) => c.freeChoice && !c.externalReward && !c.externalPressure).length;
    final recovery = _cards.where((c) => c.overcameInterference).length;
    final avg = count == 0 ? 0 : (_cards.map((c) => c.strength).reduce((a, b) => a + b) / count).round();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _section('今日自我证据', '完成行动数：$count\n低外部奖励/低压力行动：$free\n干扰后恢复证据：$recovery\n平均证据强度：$avg/100'),
      _section('本周观察者报告', count == 0 ? '如果一个观察者看不到任何行动证据，他只能建议你先制造一条最小证据。' : '如果一个观察者看到你已经记录 $count 条行为证据，其中 $recovery 条包含干扰后恢复，他可以合理推断：旧标签正在被真实行动削弱。'),
      _section('身份证据更新', '旧标签：${_labelCtrl.text}\n本月行为证据：$count 次最小行动\n新自我判断：我正在通过重复行动训练自己，而不是靠空洞口号定义自己。'),
    ]);
  }

  Widget _prompts() => ListView(padding: const EdgeInsets.all(16), children: [
    _section('AI 提示词统一配置中心', '本模块所有 AI 提示词均已注册到：设置 → AI 提示词统一配置中心 → 自我证据 Self Evidence。全局价值层、九大模块层、七个场景层、输出格式层都可自由覆盖；下一次 AI 调用立即生效。'),
    FilledButton.icon(onPressed: () => _openPromptSettings(), icon: const Icon(Icons.tune_outlined), label: const Text('打开统一配置中心')),
    const SizedBox(height: 12),
    _section('全局价值层 Prompt', SelfEvidencePromptConfig.globalValuePrompt),
    _section('模块层 Prompt', SelfEvidencePromptConfig.modulePrompts.entries.map((e) => '• ${SelfEvidencePromptConfig.labels[e.key]}：${e.value}').join('\n')),
    _section('场景层 Prompt', SelfEvidencePromptConfig.scenePrompts.entries.map((e) => '• ${SelfEvidencePromptConfig.labels[e.key]}：${e.value}').join('\n')),
    _section('输出格式 Prompt', SelfEvidencePromptConfig.outputPrompt),
  ]);

  Widget _hero() => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF2563EB)])), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('用行动看见真实的自己', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
    SizedBox(height: 8),
    Text('基于自我知觉理论：先制造行为证据，再通过情境分析、观察者推断和重复行动重建自我认知。', style: TextStyle(color: Colors.white70, height: 1.45)),
  ]));

  Widget _moduleGrid() => GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 360, mainAxisExtent: 190, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: _modules.length, itemBuilder: (_, i) => Card(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFFE5E7EB))), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(_modules[i].icon, color: const Color(0xFF0F766E)), const SizedBox(width: 8), Expanded(child: Text(_modules[i].title, style: const TextStyle(fontWeight: FontWeight.w900)))]), const SizedBox(height: 8), Text(_modules[i].subtitle, style: const TextStyle(color: Color(0xFF64748B), height: 1.35)), const Spacer(), Text(_modules[i].actions.join(' · '), style: const TextStyle(fontSize: 12, color: Color(0xFF334155))) ]))));

  Widget _strengthCard() => _section('今日证据强度（启发式）', '自由度：${_freeChoice ? '高' : '低'}\n外部奖励：${_externalReward ? '有' : '低/无'}\n外部压力：${_externalPressure ? '有' : '低/无'}\n困难程度：${_difficulty.round()}/10\n干扰恢复：${_overcameInterference ? '是' : '未记录'}\n自我证明力：${_evidenceStrength().round()}/100');

  Widget _cardWidget(_EvidenceCard c) => Card(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFFE5E7EB))), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c.behavior, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text('${c.createdAt.toLocal()} · ${c.durationMinutes} 分钟 · 难度 ${c.difficulty}/10 · 证据强度 ${c.strength}/100', style: const TextStyle(color: Color(0xFF64748B))), const SizedBox(height: 8), Text('观察者推断：这个人虽然仍受“${c.oldLabel}”影响，但已经用“${c.behavior}”制造了反证。'), const SizedBox(height: 8), Wrap(spacing: 8, children: [Chip(label: Text(c.freeChoice ? '自由选择' : '非自由选择')), Chip(label: Text(c.externalReward ? '有奖励' : '低奖励')), Chip(label: Text(c.externalPressure ? '有压力' : '低压力')), Chip(label: Text(c.overcameInterference ? '克服干扰' : '未克服干扰'))])])));

  Widget _section(String title, String body) => Card(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFFE5E7EB))), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(body, style: const TextStyle(color: Color(0xFF334155), height: 1.45))])));

  Widget _markdown(String text) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))), child: Text(text, style: const TextStyle(height: 1.5, color: Color(0xFF1E293B))));
}

class _ModuleSpec {
  final String title;
  final IconData icon;
  final String subtitle;
  final List<String> actions;
  const _ModuleSpec(this.title, this.icon, this.subtitle, this.actions);
}

class _EvidenceCard {
  final DateTime createdAt;
  final String oldLabel;
  final String behavior;
  final int durationMinutes;
  final int difficulty;
  final bool freeChoice;
  final bool externalReward;
  final bool externalPressure;
  final bool overcameInterference;
  final int strength;
  final String scene;

  const _EvidenceCard({required this.createdAt, required this.oldLabel, required this.behavior, required this.durationMinutes, required this.difficulty, required this.freeChoice, required this.externalReward, required this.externalPressure, required this.overcameInterference, required this.strength, required this.scene});

  factory _EvidenceCard.fromJson(Map<dynamic, dynamic> json) => _EvidenceCard(
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    oldLabel: json['old_label']?.toString() ?? '',
    behavior: json['behavior']?.toString() ?? '',
    durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 5,
    difficulty: (json['difficulty'] as num?)?.toInt() ?? 5,
    freeChoice: json['free_choice'] == true,
    externalReward: json['external_reward'] == true,
    externalPressure: json['external_pressure'] == true,
    overcameInterference: json['overcame_interference'] == true,
    strength: (json['strength'] as num?)?.toInt() ?? 50,
    scene: json['scene']?.toString() ?? '',
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'created_at': createdAt.toIso8601String(),
    'old_label': oldLabel,
    'behavior': behavior,
    'duration_minutes': durationMinutes,
    'difficulty': difficulty,
    'free_choice': freeChoice,
    'external_reward': externalReward,
    'external_pressure': externalPressure,
    'overcame_interference': overcameInterference,
    'strength': strength,
    'scene': scene,
  };
}
