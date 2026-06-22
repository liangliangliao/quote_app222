import 'dart:convert';

import 'package:flutter/material.dart';

import 'realistic_optimism_training_ai_service.dart';
import 'realistic_optimism_training_dao.dart';
import 'realistic_optimism_training_models.dart';


class RotCoreValueCopy {
  static const String centerTitle = '中心思想';
  static const String centerBody = '不否认现实，也不让痛苦垄断全部解释权；先允许情绪，再区分事实与解释；用一个可执行小行动创造证据；把行动、恢复、感恩和 Prime 沉淀成身份。';
  static const String environmentBody = '本模块的环境建设只服务一个目标：让用户在每个入口、每个步骤、每个结果里都看见同一套价值体系，而不是在一堆孤立功能之间迷路。';
  static const String researchAnchorsTitle = '研究与案例锚点';
  static const String researchAnchorsBody = 'Seligman 解释风格、Biondi 奥运翻盘、Reivich 韧性训练、Bargh 与 Langer 的环境启动、Edison/Simonton 的失败免疫、VIA 优势与感恩品味，共同支撑本模块：现实要看清，情绪要允许，解释要重构，行动要落地，身份要由证据积累。';

  static String stageTitle(int step) {
    switch (step) {
      case 0:
        return '核心价值：先看见现实，也允许自己为人';
      case 1:
        return '核心价值：事实不等于解释';
      case 2:
        return '核心价值：行动建立自我效能';
      case 3:
      default:
        return '核心价值：完成或没完成，都能沉淀成证据';
    }
  }

  static String stageBody(int step) {
    switch (step) {
      case 0:
        return '现实主义乐观不是立刻积极，而是先判断强度，承认痛苦和身体反应。L3/L4 先稳定，L1/L2 再进入普通训练。';
      case 1:
        return '痛苦会把解释变窄。这里训练的是把“发生了什么”和“我脑中怎么解释”分开，防止 Fault Finder 把一次事件扩大成整个人生。';
      case 2:
        return '真正的乐观不是口号，而是保留一点主动性：找出可控点，预演障碍，用 5 分钟行动创造一条证据。';
      case 3:
      default:
        return '完成了就是行动证据；没完成就是失败免疫材料。最后用感恩保持完整现实感，用 Prime 设计注意力，用身份句保存成长证据。';
    }
  }

  static String sceneTitle(String scene) {
    switch (scene) {
      case 'intensity_check':
        return '事件强度分级的价值';
      case 'event_reframe':
        return '今日事件重构的价值';
      case 'emotion_container':
        return '允许自己为人的价值';
      case 'explanation_radar':
        return '解释风格雷达的价值';
      case 'dual_lens':
        return 'Fault / Benefit 双镜头的价值';
      case 'failure_immunity':
        return '失败免疫的价值';
      case 'controlled_failure_challenge':
        return '可控失败挑战的价值';
      case 'process_action':
        return '过程模拟行动器的价值';
      case 'prime_design':
        return '注意力 Prime 的价值';
      case 'anti_prime_cleanup':
        return 'Anti-Prime 清理的价值';
      case 'gratitude_savoring':
        return '感恩与品味的价值';
      case 'identity_evidence':
        return '身份沉淀的价值';
      case 'weekly_baseline':
        return '幸福基线周报的价值';
      default:
        return '核心训练价值';
    }
  }

  static String sceneBody(String scene) {
    switch (scene) {
      case 'intensity_check':
        return '先判断 L1/L2/L3/L4，决定现在适合重构、行动、稳定，还是安全优先，避免把乐观训练变成强行积极。';
      case 'event_reframe':
        return '围绕一个真实事件完成“情绪允许 → 事实解释分离 → 双镜头 → 可控行动 → 身份证据”的完整闭环。';
      case 'emotion_container':
        return '先允许情绪存在，不急着修理自己。只有情绪被承认，后面的重构和行动才不是压抑。';
      case 'explanation_radar':
        return '看见自动解释中的永久化、普遍化、人格化、灾难化、无力化、过滤化，恢复更完整的现实观看方式。';
      case 'dual_lens':
        return 'Fault Finder 负责看见痛苦和风险；Benefit Finder 不是否认痛苦，而是在痛苦之外找回事实、资源、学习和可控点。';
      case 'failure_immunity':
        return '失败不是人格判决，而是心理免疫材料：比较预测痛苦与实际恢复，沉淀下次更小、更稳的行动。';
      case 'controlled_failure_challenge':
        return '用低风险、不伤害自己的方式练习承受不完美、拒绝和尴尬，证明失败通常不是灾难终点。';
      case 'process_action':
        return '把目标从结果焦虑转为过程路径：第一步、障碍、If-Then、5 分钟启动，用行动证据建立自我效能。';
      case 'prime_design':
        return 'Focus creates reality：把价值词、锁屏句、环境线索放到每天可见的位置，让注意力回到可控行动。';
      case 'anti_prime_cleanup':
        return '识别会启动比较、拖延、无力感的环境线索，把它们替换成更支持行动和恢复的 Prime。';
      case 'gratitude_savoring':
        return '感恩不是假装一切都好，而是不让坏事吞掉全部现实；训练看见仍然存在的资源、关系和珍惜。';
      case 'identity_evidence':
        return '身份不是靠口号建立，而是由一次次行动、恢复、珍惜和重新开始的证据积累出来。';
      case 'weekly_baseline':
        return '长期追踪解释风格、行动证据、失败恢复、Prime 和感恩敏感度，形成下一周只练一个重点。';
      default:
        return centerBody;
    }
  }
}

class RotCoreValueGuideCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  const RotCoreValueGuideCard({super.key, required this.title, required this.body, this.icon = Icons.auto_awesome_outlined});

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(.62),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(body, style: const TextStyle(height: 1.45)),
            ])),
          ]),
        ),
      );
}

class RealisticOptimismEventWizardPage extends StatefulWidget {
  final String initialText;
  final String extraContext;
  const RealisticOptimismEventWizardPage({super.key, this.initialText = '', this.extraContext = ''});

  @override
  State<RealisticOptimismEventWizardPage> createState() => _RealisticOptimismEventWizardPageState();
}

class _RealisticOptimismEventWizardPageState extends State<RealisticOptimismEventWizardPage> {
  final _ai = RealisticOptimismTrainingAiService();
  final _dao = RealisticOptimismTrainingDao();
  final _eventCtrl = TextEditingController();
  final _emotionCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _factCtrl = TextEditingController();
  final _unknownCtrl = TextEditingController();
  final _thoughtCtrl = TextEditingController();
  final _fearCtrl = TextEditingController();
  final _uncontrollableCtrl = TextEditingController();
  final _influenceCtrl = TextEditingController();
  final _controlCtrl = TextEditingController();
  final _actionCtrl = TextEditingController();
  int _step = 0;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _eventCtrl.text = widget.initialText;
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[_eventCtrl, _emotionCtrl, _bodyCtrl, _factCtrl, _unknownCtrl, _thoughtCtrl, _fearCtrl, _uncontrollableCtrl, _influenceCtrl, _controlCtrl, _actionCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _level => _guessLevel('${_eventCtrl.text}\n${_thoughtCtrl.text}\n${_emotionCtrl.text}');
  bool get _isSafetyMode => _level == 'L3' || _level == 'L4';

  String _guessLevel(String text) {
    final danger = <String>['不想活', '自杀', '伤害自己', '伤害别人', '死了算了', '活不下去'];
    if (danger.any(text.contains)) return 'L4';
    final severe = <String>['创伤', '崩溃', '绝望', '重大失去', '亲人去世'];
    if (severe.any(text.contains)) return 'L3';
    final medium = <String>['失败', '羞耻', '面试', '被否定', '争吵', '自责', '拖延', '坚持不了', '分手'];
    if (medium.any(text.contains)) return 'L2';
    return 'L1';
  }

  Future<void> _complete() async {
    if (_eventCtrl.text.trim().isEmpty) {
      _toast('请先写下一个真实事件。');
      return;
    }
    setState(() => _generating = true);
    try {
      await _dao.ensureTables();
      final structuredInput = '''
【V7 事件重构 Wizard：用户逐步完成的真实训练材料】
事件强度初判：$_level

Step 1 真实事件：
${_eventCtrl.text.trim()}

Step 2 Permission to Be Human：
最强情绪：${_emotionCtrl.text.trim()}
身体感受：${_bodyCtrl.text.trim()}

Step 3 事实层：
客观事实：${_factCtrl.text.trim()}
未知/假设：${_unknownCtrl.text.trim()}

Step 4 自动解释：
脑中最强一句话：${_thoughtCtrl.text.trim()}
我最担心它说明什么：${_fearCtrl.text.trim()}

Step 5 主动性层：
不可控：${_uncontrollableCtrl.text.trim()}
可影响：${_influenceCtrl.text.trim()}
可控制：${_controlCtrl.text.trim()}

Step 6 用户愿意执行的 5 分钟行动：
${_actionCtrl.text.trim()}

请不要一次性鸡汤安慰。请基于以上用户逐步参与的材料生成最终训练结果：强度分级、情绪允许、事实-解释分离、解释风格雷达、Fault Finder/Benefit Finder、可控点、过程行动、行动证据问题、身份沉淀。
''';
      final result = await _ai.generate(userInput: structuredInput, scene: 'event_reframe', extraContext: widget.extraContext);
      await _dao.upsertRecord(result.record);
      if (!mounted) return;
      Navigator.pop(context, result.record);
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final steps = _steps();
    return Scaffold(
      appBar: AppBar(title: const Text('今日事件重构 Wizard')),
      body: Stepper(
        currentStep: _step,
        type: StepperType.vertical,
        onStepTapped: (i) => setState(() => _step = i),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(children: <Widget>[
            if (_step > 0) TextButton(onPressed: () => setState(() => _step--), child: const Text('上一步')),
            const Spacer(),
            FilledButton.icon(
              onPressed: _generating ? null : () {
                if (_step == steps.length - 1) {
                  _complete();
                } else {
                  setState(() => _step++);
                }
              },
              icon: _generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_step == steps.length - 1 ? Icons.auto_awesome_outlined : Icons.arrow_forward),
              label: Text(_generating ? '生成中' : _step == steps.length - 1 ? '生成训练结果' : '下一步'),
            ),
          ]),
        ),
        steps: steps,
      ),
    );
  }

  List<Step> _steps() => <Step>[
    Step(
      title: const Text('1. 事件强度分级'),
      isActive: _step >= 0,
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        _PrincipleBox(title: '先决定当前适合做什么', text: '不是所有痛苦都马上进入 Benefit Finding。L3 不强行积极，L4 安全优先。'),
        _TextBox(controller: _eventCtrl, label: '真实事件', hint: '今天发生了什么？请写具体，不需要完美。', minLines: 4, onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        _LevelCard(level: _level),
      ]),
    ),
    Step(
      title: const Text('2. 允许自己为人'),
      isActive: _step >= 1,
      content: Column(children: <Widget>[
        _PrincipleBox(title: '先承认痛苦，不急着积极', text: '负面情绪不是人格失败。它说明这件事对你有影响。'),
        _TextBox(controller: _emotionCtrl, label: '最强情绪', hint: '例如：羞耻、自责、失望、愤怒、害怕、麻木', minLines: 2),
        _TextBox(controller: _bodyCtrl, label: '身体感受', hint: '例如：胸口紧、胃沉、头胀、肩膀紧', minLines: 2),
      ]),
    ),
    Step(
      title: const Text('3. 事实-解释分离'),
      isActive: _step >= 2,
      content: Column(children: <Widget>[
        _PrincipleBox(title: '事实不是解释', text: '事实是发生了什么；解释是我如何理解它。训练从这里开始。'),
        _TextBox(controller: _factCtrl, label: '客观事实', hint: '只写可观察事实，不写“我很废”这类评价。', minLines: 3),
        _TextBox(controller: _unknownCtrl, label: '未知/假设', hint: '哪些是我猜的？哪些还没有证据？', minLines: 3),
      ]),
    ),
    Step(
      title: const Text('4. 自动解释与解释风格'),
      isActive: _step >= 3,
      content: Column(children: <Widget>[
        _PrincipleBox(title: '不让痛苦垄断全部解释权', text: '这里检查永久化、普遍化、人格化、灾难化、无力化、过滤化。'),
        _TextBox(controller: _thoughtCtrl, label: '脑中最强一句话', hint: '例如：我永远坚持不了；我这个人就是不行。', minLines: 3),
        _TextBox(controller: _fearCtrl, label: '我最担心它说明什么', hint: '例如：说明我以后都找不到工作；说明我不值得被爱。', minLines: 3),
      ]),
    ),
    Step(
      title: const Text('5. 主动性层'),
      isActive: _step >= 4,
      content: Column(children: <Widget>[
        _PrincipleBox(title: '从被事件定义到主动回应', text: '把现实拆成不可控、可影响、可控制，找回一个很小的主动性。'),
        _TextBox(controller: _uncontrollableCtrl, label: '不可控', hint: '已经发生的事、他人的全部评价、不能保证的结果。', minLines: 2),
        _TextBox(controller: _influenceCtrl, label: '可影响', hint: '准备方式、沟通方式、环境、下次尝试。', minLines: 2),
        _TextBox(controller: _controlCtrl, label: '可控制', hint: '我现在能做的小动作是什么？', minLines: 2),
      ]),
    ),
    Step(
      title: const Text('6. 5 分钟行动与身份证据'),
      isActive: _step >= 5,
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        _PrincipleBox(title: '行动建立自我效能', text: '自信不是喊出来的，而是由小行动证据积累出来的。'),
        _TextBox(controller: _actionCtrl, label: '我愿意今天开始的 5 分钟行动', hint: '例如：打开文件只改第一句话；只读第一段；把手机放远。', minLines: 3),
        if (_isSafetyMode) _SafetyNotice(level: _level),
      ]),
    ),
  ];
}

class ProcessActionPlannerPage extends StatefulWidget {
  final String initialGoal;
  final String extraContext;
  const ProcessActionPlannerPage({super.key, this.initialGoal = '', this.extraContext = ''});

  @override
  State<ProcessActionPlannerPage> createState() => _ProcessActionPlannerPageState();
}

class _ProcessActionPlannerPageState extends State<ProcessActionPlannerPage> {
  final _ai = RealisticOptimismTrainingAiService();
  final _dao = RealisticOptimismTrainingDao();
  final _goalCtrl = TextEditingController();
  final _whyCtrl = TextEditingController();
  final _obstacleCtrl = TextEditingController();
  final _timeCtrl = TextEditingController(text: '5 分钟');
  final _environmentCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _goalCtrl.text = widget.initialGoal;
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[_goalCtrl, _whyCtrl, _obstacleCtrl, _timeCtrl, _environmentCtrl]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _run() async {
    if (_goalCtrl.text.trim().isEmpty) { _toast('请先写下目标或任务。'); return; }
    setState(() => _loading = true);
    try {
      final input = '''
【V7 过程模拟行动器】
目标/任务：${_goalCtrl.text.trim()}
为什么重要：${_whyCtrl.text.trim()}
最容易卡住：${_obstacleCtrl.text.trim()}
可投入时间：${_timeCtrl.text.trim()}
当前环境干扰：${_environmentCtrl.text.trim()}

请把目标转成真正可执行的过程：结果画面、时间地点工具、第一步、接下来三步、障碍预演、If-Then、5分钟启动动作、完成后行动证据问题。请强调先行动再信心。
''';
      final result = await _ai.generate(userInput: input, scene: 'process_action', extraContext: widget.extraContext);
      await _dao.upsertRecord(result.record);
      if (!mounted) return;
      Navigator.pop(context, result.record);
    } catch (e) { _toast('生成失败：$e'); } finally { if (mounted) setState(() => _loading = false); }
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('过程模拟行动器')),
    body: ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      _PrincipleBox(title: '过程模拟优于结果幻想', text: '不只是想象成功，而是把目标拆成第一步、环境、障碍和 If-Then。'),
      _TextBox(controller: _goalCtrl, label: '目标/任务', hint: '例如：写简历、学习英语、运动20分钟', minLines: 3),
      _TextBox(controller: _whyCtrl, label: '为什么重要', hint: '这个目标连接了什么价值？', minLines: 2),
      _TextBox(controller: _obstacleCtrl, label: '最容易卡住的地方', hint: '怕做不好、手机干扰、目标太大、没有状态……', minLines: 3),
      _TextBox(controller: _timeCtrl, label: '今天最多能投入多久', hint: '例如：5 分钟 / 15 分钟', minLines: 1),
      _TextBox(controller: _environmentCtrl, label: '当前环境干扰', hint: '例如：手机、床、杂乱桌面、消息提醒', minLines: 2),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: _loading ? null : _run, icon: _loading ? const SizedBox(width: 16,height:16,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.route_outlined), label: Text(_loading ? '生成中' : '生成过程行动计划')),
    ]),
  );
}

class FailureImmunityLabPage extends StatefulWidget {
  final String extraContext;
  const FailureImmunityLabPage({super.key, this.extraContext = ''});

  @override
  State<FailureImmunityLabPage> createState() => _FailureImmunityLabPageState();
}

class _FailureImmunityLabPageState extends State<FailureImmunityLabPage> with SingleTickerProviderStateMixin {
  final _ai = RealisticOptimismTrainingAiService();
  final _dao = RealisticOptimismTrainingDao();
  final _themeCtrl = TextEditingController();
  final _fearCtrl = TextEditingController();
  final _recoveryCtrl = TextEditingController();
  final _actualCtrl = TextEditingController();
  final _antibodyCtrl = TextEditingController();
  double _predictedPain = 7;
  double _actualPain = 5;
  bool _loading = false;
  List<Map<String, Object?>> _antibodies = <Map<String, Object?>>[];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    await _dao.ensureTables();
    final rows = await _dao.listFailureImmunity(limit: 50);
    if (mounted) setState(() => _antibodies = rows);
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[_themeCtrl, _fearCtrl, _recoveryCtrl, _actualCtrl, _antibodyCtrl]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _createPrediction() async {
    if (_themeCtrl.text.trim().isEmpty) { _toast('请先写下失败或挑战主题。'); return; }
    setState(() => _loading = true);
    try {
      final input = '''
【V7 失败免疫实验室：失败前预测】
失败/挑战主题：${_themeCtrl.text.trim()}
我最害怕什么：${_fearCtrl.text.trim()}
预测痛苦：$_predictedPain/10
预测恢复：${_recoveryCtrl.text.trim()}

请只做失败前预测与心理免疫设计：区分事件失败和人格失败，写出安全边界、预测痛苦、预测恢复、执行后要复盘的问题，以及可能训练出的心理抗体。不要美化失败。
''';
      final result = await _ai.generate(userInput: input, scene: 'failure_immunity', extraContext: widget.extraContext);
      await _dao.upsertRecord(result.record);
      if (!mounted) return;
      Navigator.pop(context, result.record);
    } catch (e) { _toast('生成失败：$e'); } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _saveRecoveryReview() async {
    if (_actualCtrl.text.trim().isEmpty && _antibodyCtrl.text.trim().isEmpty) { _toast('请写下实际结果或心理抗体。'); return; }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _dao.addFailureRecoveryReview(recordId: 'manual_failure_lab_$now', actualPain: _actualPain, actualRecovery: _actualCtrl.text.trim(), psychologicalAntibody: _antibodyCtrl.text.trim(), actualResult: _actualCtrl.text.trim());
    await _load();
    _toast('已保存失败后恢复复盘');
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(title: const Text('失败免疫实验室'), bottom: const TabBar(tabs: <Widget>[Tab(text:'失败前预测'), Tab(text:'失败后复盘'), Tab(text:'心理抗体库')])),
      body: TabBarView(children: <Widget>[
        ListView(padding: const EdgeInsets.all(16), children: <Widget>[
          _PrincipleBox(title: '失败是心理免疫训练材料', text: '不是美化失败，而是预测痛苦、执行、复盘恢复，发现自己能承受什么。'),
          _TextBox(controller: _themeCtrl, label: '失败/挑战主题', hint: '例如：提出一个可能被拒绝的请求；提交不完美版本；复盘面试失败', minLines: 3),
          _TextBox(controller: _fearCtrl, label: '我最害怕什么', hint: '最坏想象、别人怎么看、它说明什么', minLines: 3),
          _SliderField(label: '预测痛苦', value: _predictedPain, onChanged: (v) => setState(() => _predictedPain = v)),
          _TextBox(controller: _recoveryCtrl, label: '预测多久恢复', hint: '例如：我担心会难受一整天/一周', minLines: 2),
          FilledButton.icon(onPressed: _loading ? null : _createPrediction, icon: const Icon(Icons.shield_outlined), label: const Text('生成失败前预测')),
        ]),
        ListView(padding: const EdgeInsets.all(16), children: <Widget>[
          _PrincipleBox(title: '用实际结果修正想象中的失败', text: '比较预测痛苦和实际痛苦，比较预测恢复和实际恢复。'),
          _SliderField(label: '实际痛苦', value: _actualPain, onChanged: (v) => setState(() => _actualPain = v)),
          _TextBox(controller: _actualCtrl, label: '实际结果/恢复时间', hint: '发生了什么？多久开始下降？最坏结果真的发生了吗？', minLines: 4),
          _TextBox(controller: _antibodyCtrl, label: '这次训练出的心理抗体', hint: '例如：我可以承受不完美暴露，痛苦会来但会下降。', minLines: 3),
          FilledButton.icon(onPressed: _saveRecoveryReview, icon: const Icon(Icons.done_all_outlined), label: const Text('保存恢复复盘')),
        ]),
        ListView(padding: const EdgeInsets.all(16), children: <Widget>[
          _PrincipleBox(title: '心理抗体库', text: '这里保存“我失败过，但恢复过”的证据。'),
          if (_antibodies.isEmpty) const _EmptyText('还没有心理抗体。先完成一次失败前预测或失败后复盘。'),
          ..._antibodies.map((row) => _SimpleRowCard(title: (row['psychological_antibody'] ?? '心理抗体').toString(), subtitle: '实际痛苦：${row['actual_pain'] ?? '-'}｜实际恢复：${row['actual_recovery'] ?? ''}')),
        ]),
      ]),
    ),
  );
}

class EnvironmentWallPage extends StatefulWidget {
  final String extraContext;
  const EnvironmentWallPage({super.key, this.extraContext = ''});

  @override
  State<EnvironmentWallPage> createState() => _EnvironmentWallPageState();
}

class _EnvironmentWallPageState extends State<EnvironmentWallPage> {
  final _dao = RealisticOptimismTrainingDao();
  final _ai = RealisticOptimismTrainingAiService();
  final _focusCtrl = TextEditingController();
  final _antiCtrl = TextEditingController();
  bool _loading = false;
  List<Map<String, Object?>> _primes = <Map<String, Object?>>[];
  List<Map<String, Object?>> _anti = <Map<String, Object?>>[];

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { await _dao.ensureTables(); final p=await _dao.listPrimes(); final a=await _dao.listAntiPrimes(); if(mounted)setState((){_primes=p;_anti=a;}); }
  @override
  void dispose(){_focusCtrl.dispose();_antiCtrl.dispose();super.dispose();}

  Future<void> _generatePrime() async {
    if (_focusCtrl.text.trim().isEmpty) { _toast('请写下今天最需要被启动的状态。'); return; }
    setState(() => _loading = true);
    try {
      final result = await _ai.generate(userInput: '【V7 注意力启动墙】今天最需要被启动的状态：${_focusCtrl.text.trim()}\n请生成今日价值词、锁屏短句、现实 Prime、Benefit Finder 问题、今日行动线索。', scene: 'prime_design', extraContext: widget.extraContext);
      await _dao.upsertRecord(result.record);
      await _load();
    } catch(e){ _toast('生成失败：$e'); } finally { if(mounted)setState(()=>_loading=false); }
  }
  Future<void> _generateAntiPrime() async {
    if (_antiCtrl.text.trim().isEmpty) { _toast('请写下一个消极启动源。'); return; }
    setState(() => _loading = true);
    try {
      final result = await _ai.generate(userInput: '【V7 Anti-Prime 环境清理】消极启动源：${_antiCtrl.text.trim()}\n请识别影响状态、清理动作、替代 Prime 和今天最小环境改造动作。', scene: 'anti_prime_cleanup', extraContext: widget.extraContext);
      await _dao.upsertRecord(result.record);
      await _load();
    } catch(e){ _toast('生成失败：$e'); } finally { if(mounted)setState(()=>_loading=false); }
  }

  void _toast(String text)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context)=>DefaultTabController(length: 2, child: Scaffold(
    appBar: AppBar(title: const Text('Prime / Anti-Prime 环境墙'), bottom: const TabBar(tabs: <Widget>[Tab(text:'今日 Prime'),Tab(text:'Anti-Prime 清理')]),),
    body: TabBarView(children: <Widget>[
      ListView(padding: const EdgeInsets.all(16), children: <Widget>[
        _PrincipleBox(title: 'Focus creates reality', text: '你反复看到什么，就更容易相信什么、选择什么。这里不是记录，而是设计每日环境。'),
        _TextBox(controller: _focusCtrl, label: '今天最需要被启动的状态', hint: '行动、勇气、感恩、失败恢复、关系珍惜……', minLines: 2),
        FilledButton.icon(onPressed: _loading?null:_generatePrime, icon: const Icon(Icons.wallpaper_outlined), label: const Text('设计今日 Prime')),
        const SizedBox(height: 12),
        ..._primes.map((r)=>_SimpleRowCard(title: (r['value_word']??'Prime').toString(), subtitle: '${r['reminder']??''}\n${r['benefit_question']??''}')),
      ]),
      ListView(padding: const EdgeInsets.all(16), children: <Widget>[
        _PrincipleBox(title: '清理会削弱你的启动源', text: '不是一次改变全部环境，只移除一个最强拖延、比较或无力感入口。'),
        _TextBox(controller: _antiCtrl, label: '消极启动源', hint: 'App、人、信息流、桌面、睡前手机、比较内容……', minLines: 3),
        FilledButton.icon(onPressed: _loading?null:_generateAntiPrime, icon: const Icon(Icons.cleaning_services_outlined), label: const Text('生成清理动作')),
        const SizedBox(height: 12),
        ..._anti.map((r)=>_SimpleRowCard(title: (r['trigger_name']??'Anti-Prime').toString(), subtitle: '影响：${r['effect']??''}\n清理：${r['cleanup_action']??''}\n替代：${r['replacement_prime']??''}')),
      ]),
    ]),
  ));
}

class IdentityEvidenceWallPage extends StatelessWidget {
  final List<RealisticOptimismTrainingRecord> records;
  const IdentityEvidenceWallPage({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<RealisticOptimismTrainingRecord>>{};
    for (final r in records) {
      final key = r.identityType.isEmpty ? '未分类身份' : r.identityType;
      groups.putIfAbsent(key, () => <RealisticOptimismTrainingRecord>[]).add(r);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('身份与能力证据墙')),
      body: ListView(padding: const EdgeInsets.all(16), children: <Widget>[
        _PrincipleBox(title: '身份由证据积累', text: '不是“我很棒”的口号，而是“我做过、恢复过、珍惜过、继续过”的证据链。'),
        if (groups.isEmpty) const _EmptyText('还没有身份沉淀。先完成一次事件重构或 5 分钟行动。'),
        ...groups.entries.map((e) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(e.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...e.value.take(8).map((r)=>ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.badge_outlined), title: Text(r.identitySentence.isEmpty ? '我正在积累新的证据。' : r.identitySentence), subtitle: Text('行动：${r.specificAction.isEmpty ? r.fiveMinuteAction : r.specificAction}', maxLines: 3, overflow: TextOverflow.ellipsis))),
        ])))),
      ]),
    );
  }
}

class RotTodayOneThingPage extends StatefulWidget {
  final String initialText;
  final String extraContext;
  const RotTodayOneThingPage({super.key, this.initialText = '', this.extraContext = ''});

  @override
  State<RotTodayOneThingPage> createState() => _RotTodayOneThingPageState();
}

class _RotTodayOneThingPageState extends State<RotTodayOneThingPage> {
  final _ai = RealisticOptimismTrainingAiService();
  final _dao = RealisticOptimismTrainingDao();
  final _eventCtrl = TextEditingController();
  final _factCtrl = TextEditingController();
  final _storyCtrl = TextEditingController();
  final _actionCtrl = TextEditingController();
  final _gratitudeCtrl = TextEditingController();
  final _primeCtrl = TextEditingController();
  String _scenario = '拖延/没开始';
  String _emotion = '自责';
  String _body = '胸口紧';
  double _intensity = 5;
  bool _loading = false;

  static const Map<String, String> _exampleEvents = <String, String>{
    '拖延/没开始': '今天我又没有学习/推进任务，脑子里一直说自己坚持不了。',
    '失败/没做好': '今天一件重要的事没有做好，我很怕这说明我不行。',
    '被批评/被否定': '今天有人批评了我，我一直在想是不是我真的很差。',
    '关系不舒服': '今天和一个人互动后我很难受，担心关系变糟。',
    '情绪低落': '今天我状态很低，什么都不想做，也有点看不到希望。',
    '不知道从哪开始': '今天我说不清发生了什么，只是感觉很乱、很累、很无力。',
  };

  static const Map<String, String> _storyExamples = <String, String>{
    '拖延/没开始': '我永远坚持不了，我就是没有自控力。',
    '失败/没做好': '这次失败说明我不适合做这件事。',
    '被批评/被否定': '别人这么说，说明我真的很差。',
    '关系不舒服': '关系变成这样，可能都是我的问题。',
    '情绪低落': '我现在这样，说明以后也不会好起来。',
    '不知道从哪开始': '我太混乱了，什么都处理不好。',
  };

  static const Map<String, String> _actionExamples = <String, String>{
    '拖延/没开始': '只打开材料/文件，做 5 分钟，不要求完成。',
    '失败/没做好': '写下这次失败暴露的 1 个具体环节和 1 个下次可调整动作。',
    '被批评/被否定': '把批评拆成“事实部分”和“评价部分”，只处理一个可改进点。',
    '关系不舒服': '先不急着解释关系，只写一条温和、具体、不攻击的信息草稿。',
    '情绪低落': '站起来喝水/整理桌面 2 分钟，再做一个小到不能再小的动作。',
    '不知道从哪开始': '只写下现在最困扰我的一件事，不解决，只命名。',
  };

  @override
  void initState() {
    super.initState();
    _eventCtrl.text = widget.initialText.trim();
    if (_eventCtrl.text.isEmpty) {
      _eventCtrl.text = _exampleEvents[_scenario]!;
    }
    _storyCtrl.text = _storyExamples[_scenario]!;
    _actionCtrl.text = _actionExamples[_scenario]!;
    _factCtrl.text = '今天确实发生/没有发生的是：${_eventCtrl.text.replaceAll('\n', ' ')}';
    _gratitudeCtrl.text = '今天至少还有一件没有完全消失的东西：我还可以从一个很小动作开始。';
    _primeCtrl.text = '先做一个行动证据，不等状态完美。';
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[_eventCtrl, _factCtrl, _storyCtrl, _actionCtrl, _gratitudeCtrl, _primeCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _level {
    final text = '${_eventCtrl.text}\n${_storyCtrl.text}'.toLowerCase();
    if (text.contains('不想活') || text.contains('自杀') || text.contains('伤害自己') || text.contains('活不下去')) return 'L4';
    if (text.contains('绝望') || text.contains('创伤') || text.contains('重大失去') || _intensity >= 9) return 'L3';
    if (_intensity >= 6 || _scenario != '不知道从哪开始') return 'L2';
    return 'L1';
  }

  void _applyScenario(String value) {
    setState(() {
      _scenario = value;
      _eventCtrl.text = _exampleEvents[value]!;
      _storyCtrl.text = _storyExamples[value]!;
      _actionCtrl.text = _actionExamples[value]!;
      _factCtrl.text = '今天确实发生/没有发生的是：${_eventCtrl.text.replaceAll('\n', ' ')}';
      _emotion = value == '被批评/被否定' ? '羞耻' : value == '关系不舒服' ? '难过' : value == '情绪低落' ? '低落' : '自责';
    });
  }

  String _faultPreview() {
    final story = _storyCtrl.text.trim().isEmpty ? _storyExamples[_scenario]! : _storyCtrl.text.trim();
    return 'Fault Finder 会把这件事讲成：$story\n它会让你更无力、更羞耻，也更容易停止行动。';
  }

  String _benefitPreview() {
    final fact = _factCtrl.text.trim().isEmpty ? _eventCtrl.text.trim() : _factCtrl.text.trim();
    final action = _actionCtrl.text.trim().isEmpty ? _actionExamples[_scenario]! : _actionCtrl.text.trim();
    return 'Benefit Finder 不是说这件事是好事，而是承认：$fact\n同时保留一个可控点：$action';
  }

  Future<void> _complete() async {
    if (_eventCtrl.text.trim().isEmpty) {
      _toast('先写一句话就够：今天发生了什么，或我现在卡在哪里。');
      return;
    }
    setState(() => _loading = true);
    try {
      await _dao.ensureTables();
      final input = '''
【V8 今日一件事：零门槛现实主义乐观训练】

用户不是来听鸡汤，而是来完成一个小训练闭环。请严格围绕“承认痛苦，但不让痛苦垄断全部解释权；行动建立自我效能；身份由证据积累”来输出。

1. 当前场景：$_scenario
2. 事件强度初判：$_level
3. 真实事件：${_eventCtrl.text.trim()}
4. 最强情绪：$_emotion，强度 ${_intensity.round()}/10，身体感受：$_body
5. 事实层：${_factCtrl.text.trim()}
6. 脑中故事/自动解释：${_storyCtrl.text.trim()}
7. Fault Finder 预览：${_faultPreview()}
8. Benefit Finder 预览：${_benefitPreview()}
9. 用户愿意做的 5 分钟行动：${_actionCtrl.text.trim()}
10. 今日仍值得珍惜/品味的一点：${_gratitudeCtrl.text.trim()}
11. 今日 Prime：${_primeCtrl.text.trim()}

输出必须让用户感觉“我知道下一步怎么做”：
- 先承认情绪，不要劝“别难过”。
- 明确区分事实和解释。
- 标出永久化/普遍化/人格化/灾难化/无力化/过滤化里最明显的 1-3 个。
- Fault Finder 要说明它如何让用户更无力。
- Benefit Finder 必须承认痛苦，不得说“一切都是最好的安排”。
- 给出一个今天 5 分钟内能开始的动作。
- 给出完成后要记录的一句行动证据。
- 生成一句“我正在成为一个……”身份句。
- 如果是 L3/L4，暂停普通 Benefit Finding 和感恩，优先稳定与现实支持。
''';
      final result = await _ai.generate(userInput: input, scene: 'event_reframe', extraContext: widget.extraContext);
      await _dao.upsertRecord(result.record);
      if (!mounted) return;
      Navigator.pop(context, result.record);
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final level = _level;
    return Scaffold(
      appBar: AppBar(title: const Text('从今天一件事开始')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: <Widget>[
          _PrincipleBox(
            title: '你不用知道怎么开始，先选一个最像的场景',
            text: '这不是让你“想开点”。今天只完成一个闭环：承认情绪 → 看清事实和解释 → 找一个可控点 → 做一个 5 分钟行动证据。',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                const Text('1｜我现在最像哪一种？', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _exampleEvents.keys.map((e) => ChoiceChip(
                    label: Text(e),
                    selected: _scenario == e,
                    onSelected: (_) => _applyScenario(e),
                  )).toList(growable: false),
                ),
                const SizedBox(height: 10),
                Text('系统已先帮你填了一个可修改示例。你可以直接改几个字，也可以直接用它体验完整流程。', style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          _LevelCard(level: level),
          if (level == 'L3' || level == 'L4') _SafetyNotice(level: level),
          const SizedBox(height: 10),
          _TrainingSection(
            number: '2',
            title: '一句话写下现实事件',
            subtitle: '不要分析，不要评价，只写“发生了什么/我卡在哪里”。',
            child: _TextBox(controller: _eventCtrl, label: '今天这件事', hint: '例如：今天我又没有学习，我感觉自己特别废。', minLines: 3, onChanged: (_) => setState(() {})),
          ),
          _TrainingSection(
            number: '3',
            title: '先允许自己为人',
            subtitle: '负面情绪不是错误，它说明这件事对你有影响。',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Wrap(spacing: 8, runSpacing: 8, children: <String>['自责','羞耻','失望','害怕','愤怒','低落','麻木','焦虑'].map((e) => ChoiceChip(label: Text(e), selected: _emotion == e, onSelected: (_) => setState(() => _emotion = e))).toList()),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: <String>['胸口紧','胃沉','肩膀紧','头胀','想逃避','没力气'].map((e) => ChoiceChip(label: Text(e), selected: _body == e, onSelected: (_) => setState(() => _body = e))).toList()),
              _SliderField(label: '情绪强度', value: _intensity, onChanged: (v) => setState(() => _intensity = v)),
            ]),
          ),
          _TrainingSection(
            number: '4',
            title: '事实 ≠ 解释',
            subtitle: '这一步体现核心思想：不否认现实，但不让痛苦垄断全部解释权。',
            child: Column(children: <Widget>[
              _TextBox(controller: _factCtrl, label: '事实层', hint: '客观发生了什么？哪些是可观察的？', minLines: 3, onChanged: (_) => setState(() {})),
              _TextBox(controller: _storyCtrl, label: '脑中故事 / 自动解释', hint: '脑子里最刺痛的一句话是什么？', minLines: 3, onChanged: (_) => setState(() {})),
            ]),
          ),
          _TrainingSection(
            number: '5',
            title: '双镜头：Fault Finder / Benefit Finder',
            subtitle: 'Benefit Finder 不是说坏事是好事，而是在坏事中保留一个可控点。',
            child: Column(children: <Widget>[
              _LensPreviewCard(title: 'Fault Finder 会怎么讲', body: _faultPreview(), icon: Icons.search_off_outlined),
              _LensPreviewCard(title: 'Benefit Finder 可以怎么回应', body: _benefitPreview(), icon: Icons.manage_search_outlined),
            ]),
          ),
          _TrainingSection(
            number: '6',
            title: '选择一个小到能开始的 5 分钟行动',
            subtitle: '行动建立自我效能。今天不是证明你很强，而是证明你可以开始。',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Wrap(spacing: 8, runSpacing: 8, children: <String>[
                '只打开文件/材料', '只写三行', '只读第一段', '发一条温和信息草稿', '把手机放远5分钟', '整理桌面2分钟'
              ].map((e) => ActionChip(label: Text(e), onPressed: () => setState(() => _actionCtrl.text = e))).toList()),
              const SizedBox(height: 10),
              _TextBox(controller: _actionCtrl, label: '我的 5 分钟行动', hint: '必须小到今天能开始。', minLines: 2, onChanged: (_) => setState(() {})),
            ]),
          ),
          _TrainingSection(
            number: '7',
            title: '把好东西留住一点，把身份落到证据上',
            subtitle: '感恩不是否认痛苦；身份不是口号，而是“我做过”的证据。',
            child: Column(children: <Widget>[
              _TextBox(controller: _gratitudeCtrl, label: '今天仍值得珍惜/品味的一点', hint: '可以很小：一杯水、一束光、一个人、一点恢复。', minLines: 2),
              _TextBox(controller: _primeCtrl, label: '今日 Prime / 锁屏提醒', hint: '例如：先做一个行动证据。', minLines: 2),
            ]),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _complete,
            icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline),
            label: Text(_loading ? '正在生成你的训练结果……' : level == 'L3' || level == 'L4' ? '生成稳定支持卡' : '完成今日一件事训练'),
          ),
          const SizedBox(height: 10),
          Text('完成后你会得到：情绪承认、事实/解释分离、解释风格雷达、双镜头重构、5分钟行动、行动证据问题、身份句。', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
        ],
      ),
    );
  }
}

class _TrainingSection extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final Widget child;
  const _TrainingSection({required this.number, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          CircleAvatar(radius: 14, child: Text(number)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade700, height: 1.35)),
          ])),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    ),
  );
}

class _LensPreviewCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  const _LensPreviewCard({required this.title, required this.body, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).dividerColor)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Icon(icon),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(height: 1.4)),
      ])),
    ]),
  );
}


class RotConnectedTrainingSessionPage extends StatefulWidget {
  final String initialText;
  final String extraContext;
  const RotConnectedTrainingSessionPage({super.key, this.initialText = '', this.extraContext = ''});

  @override
  State<RotConnectedTrainingSessionPage> createState() => _RotConnectedTrainingSessionPageState();
}

class _RotConnectedTrainingSessionPageState extends State<RotConnectedTrainingSessionPage> {
  final _ai = RealisticOptimismTrainingAiService();
  final _dao = RealisticOptimismTrainingDao();

  final _eventCtrl = TextEditingController();
  final _factCtrl = TextEditingController();
  final _unknownCtrl = TextEditingController();
  final _storyCtrl = TextEditingController();
  final _fearCtrl = TextEditingController();
  final _uncontrollableCtrl = TextEditingController();
  final _influenceCtrl = TextEditingController();
  final _controlCtrl = TextEditingController();
  final _actionCtrl = TextEditingController();
  final _obstacleCtrl = TextEditingController();
  final _ifThenCtrl = TextEditingController();
  final _evidenceCtrl = TextEditingController();
  final _notDoneCtrl = TextEditingController();
  final _gratitudeCtrl = TextEditingController();
  final _primeCtrl = TextEditingController();
  final _identityCtrl = TextEditingController();

  int _step = 0;
  String _scenario = '拖延/没开始';
  String _emotion = '自责';
  String _body = '胸口紧';
  double _intensity = 5;
  bool _generating = false;
  bool _savingEvidence = false;
  bool _actionCompleted = false;
  RealisticOptimismTrainingRecord? _record;

  static const List<String> _scenarios = <String>['拖延/没开始', '失败/没做好', '被批评/被否定', '关系不舒服', '情绪低落', '不知道从哪开始'];
  static const List<String> _emotions = <String>['自责', '羞耻', '失望', '害怕', '愤怒', '难过', '低落', '麻木', '焦虑'];
  static const List<String> _bodies = <String>['胸口紧', '胃沉', '头胀', '肩膀紧', '呼吸浅', '没力气', '想逃避'];

  static const Map<String, String> _exampleEvents = <String, String>{
    '拖延/没开始': '今天我又没有推进重要任务，越拖越自责。',
    '失败/没做好': '今天一件重要的事没有做好，我很怕这说明我不行。',
    '被批评/被否定': '今天有人批评了我，我一直在想是不是我真的很差。',
    '关系不舒服': '今天和一个人互动后我很难受，担心关系变糟。',
    '情绪低落': '今天我状态很低，什么都不想做。',
    '不知道从哪开始': '今天我说不清发生了什么，只是感觉很乱、很累、很无力。',
  };

  static const Map<String, String> _storyExamples = <String, String>{
    '拖延/没开始': '我永远坚持不了，我就是没有自控力。',
    '失败/没做好': '这次失败说明我不适合做这件事。',
    '被批评/被否定': '别人这么说，说明我真的很差。',
    '关系不舒服': '关系变成这样，可能都是我的问题。',
    '情绪低落': '我现在这样，说明以后也不会好起来。',
    '不知道从哪开始': '我太混乱了，什么都处理不好。',
  };

  static const Map<String, String> _actionExamples = <String, String>{
    '拖延/没开始': '只打开材料/文件，做 5 分钟，不要求完成。',
    '失败/没做好': '写下这次失败暴露的 1 个具体环节和 1 个下次可调整动作。',
    '被批评/被否定': '把批评拆成“事实部分”和“评价部分”，只处理一个可改进点。',
    '关系不舒服': '写一条温和、具体、不攻击的信息草稿，先不发送。',
    '情绪低落': '站起来喝水/整理桌面 2 分钟，再做一个小到不能再小的动作。',
    '不知道从哪开始': '只写下现在最困扰我的一件事，不解决，只命名。',
  };

  @override
  void initState() {
    super.initState();
    _applyScenario(_scenario, overwriteEvent: widget.initialText.trim().isEmpty);
    if (widget.initialText.trim().isNotEmpty) {
      _eventCtrl.text = widget.initialText.trim();
      _factCtrl.text = '今天可观察到的事实是：${widget.initialText.trim().replaceAll('\n', ' ')}';
    }
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _eventCtrl,
      _factCtrl,
      _unknownCtrl,
      _storyCtrl,
      _fearCtrl,
      _uncontrollableCtrl,
      _influenceCtrl,
      _controlCtrl,
      _actionCtrl,
      _obstacleCtrl,
      _ifThenCtrl,
      _evidenceCtrl,
      _notDoneCtrl,
      _gratitudeCtrl,
      _primeCtrl,
      _identityCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _level {
    final text = '${_eventCtrl.text}\n${_storyCtrl.text}\n$_emotion'.toLowerCase();
    if (text.contains('不想活') || text.contains('自杀') || text.contains('伤害自己') || text.contains('活不下去')) return 'L4';
    if (text.contains('绝望') || text.contains('创伤') || text.contains('重大失去') || _intensity >= 9) return 'L3';
    if (_intensity >= 6 || _scenario != '不知道从哪开始') return 'L2';
    return 'L1';
  }

  bool get _safetyMode => _level == 'L3' || _level == 'L4';

  void _applyScenario(String value, {bool overwriteEvent = true}) {
    setState(() {
      _scenario = value;
      if (overwriteEvent) _eventCtrl.text = _exampleEvents[value]!;
      _storyCtrl.text = _storyExamples[value]!;
      _actionCtrl.text = _actionExamples[value]!;
      _factCtrl.text = '今天可观察到的事实是：${_eventCtrl.text.replaceAll('\n', ' ')}';
      _unknownCtrl.text = '别人的全部想法、未来会怎样、这件事是否代表我整个人。';
      _fearCtrl.text = '我担心它说明我不够好，或者以后也会这样。';
      _uncontrollableCtrl.text = '已经发生的部分、别人的全部评价、不能保证的结果。';
      _influenceCtrl.text = '我可以影响准备方式、沟通方式、环境和下一次尝试。';
      _controlCtrl.text = '我现在能控制的是先做一个很小动作。';
      _obstacleCtrl.text = '目标太大、害怕做不好、手机/消息干扰、等状态变好。';
      _ifThenCtrl.text = '如果我又想逃避，就只做 2 分钟，不要求完成。';
      _gratitudeCtrl.text = '今天仍然值得珍惜的是：我还可以从一个小动作重新开始。';
      _primeCtrl.text = '今日 Prime：先做一个行动证据，不等状态完美。';
      _identityCtrl.text = '我正在成为一个能承认痛苦但仍能行动的人。';
      _emotion = value == '被批评/被否定' ? '羞耻' : value == '关系不舒服' ? '难过' : value == '情绪低落' ? '低落' : '自责';
      _body = value == '情绪低落' ? '没力气' : value == '关系不舒服' ? '胃沉' : '胸口紧';
    });
  }

  String _faultPreview() {
    final story = _storyCtrl.text.trim().isEmpty ? _storyExamples[_scenario]! : _storyCtrl.text.trim();
    return 'Fault Finder 会把这件事讲成：$story。它会让你更无力、更羞耻，也更容易停止行动。';
  }

  String _benefitPreview() {
    final action = _actionCtrl.text.trim().isEmpty ? _actionExamples[_scenario]! : _actionCtrl.text.trim();
    return 'Benefit Finder 不说坏事是好事，而是在承认痛苦后保留一个可控点：$action';
  }

  Future<void> _generateRecord() async {
    if (_eventCtrl.text.trim().isEmpty) {
      _toast('先写一句话就够：今天发生了什么，或我现在卡在哪里。');
      setState(() => _step = 0);
      return;
    }
    if (_safetyMode) {
      setState(() => _step = 1);
      _toast('当前更适合先稳定和寻求现实支持，不强行进入普通积极重构。');
      return;
    }
    setState(() => _generating = true);
    try {
      await _dao.ensureTables();
      final input = _buildTrainingInput();
      final result = await _ai.generate(userInput: input, scene: 'event_reframe', extraContext: widget.extraContext);
      await _dao.upsertRecord(result.record);
      setState(() {
        _record = result.record;
        _step = 5;
        if (_evidenceCtrl.text.trim().isEmpty) {
          _evidenceCtrl.text = '我完成了一个小动作，这证明我不需要等状态完美也能重新开始。';
        }
      });
      _toast('已生成训练记录。现在不要急着结束，继续完成“执行/复盘”。');
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _buildTrainingInput() => """
【V9 串联式现实主义乐观训练会话】
本次不是单次 AI 分析，而是一个完整业务流程。请严格让输出支持后续“执行、复盘、身份沉淀”。

一、场景与强度
场景：$_scenario
强度初判：$_level
事件：${_eventCtrl.text.trim()}
情绪：$_emotion，强度 ${_intensity.round()}/10，身体感受：$_body

二、事实与解释
事实层：${_factCtrl.text.trim()}
未知/假设：${_unknownCtrl.text.trim()}
自动解释：${_storyCtrl.text.trim()}
最担心它说明：${_fearCtrl.text.trim()}

三、双镜头与主动性
Fault Finder 预览：${_faultPreview()}
Benefit Finder 预览：${_benefitPreview()}
不可控：${_uncontrollableCtrl.text.trim()}
可影响：${_influenceCtrl.text.trim()}
可控制：${_controlCtrl.text.trim()}

四、过程行动
5分钟行动：${_actionCtrl.text.trim()}
障碍预演：${_obstacleCtrl.text.trim()}
If-Then：${_ifThenCtrl.text.trim()}

五、感恩/Prime/身份
今日仍值得珍惜：${_gratitudeCtrl.text.trim()}
今日 Prime：${_primeCtrl.text.trim()}
身份句草稿：${_identityCtrl.text.trim()}

输出要求：
1. 先承认情绪，不劝“别难过”。
2. 明确区分事实和解释。
3. 标出最明显的解释风格陷阱。
4. Fault Finder 必须说明它如何造成无力。
5. Benefit Finder 必须承认痛苦，不得说“一切都是最好的安排”。
6. 必须输出一个非常具体的 5 分钟行动、三步过程和 If-Then。
7. 必须输出完成后要记录的行动证据问题。
8. 必须输出今日 Prime、感恩/品味动作和“我正在成为一个……”身份句。
""";

  Future<void> _saveEvidenceAndFinish() async {
    final record = _record;
    if (record == null) {
      await _generateRecord();
      return;
    }
    setState(() => _savingEvidence = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _dao.addActionEvidence(RealisticOptimismTrainingActionEvidence(
        id: 'rot_act_${record.id}_$now',
        recordId: record.id,
        action: _actionCtrl.text.trim().isEmpty ? record.fiveMinuteAction : _actionCtrl.text.trim(),
        evidenceText: _actionCompleted
            ? (_evidenceCtrl.text.trim().isEmpty ? '我完成了一个小动作，积累了一条行动证据。' : _evidenceCtrl.text.trim())
            : (_notDoneCtrl.text.trim().isEmpty ? '我还没完成，但我已经看见了卡点，下一步会把行动缩小。' : _notDoneCtrl.text.trim()),
        completed: _actionCompleted,
        completedAtMs: _actionCompleted ? now : null,
        selfEfficacyScore: _actionCompleted ? 6 : 3,
        createdAtMs: now,
      ));
      if (!_actionCompleted) {
        await _dao.addFailureRecoveryReview(
          recordId: record.id,
          actualPain: _intensity,
          actualResult: _notDoneCtrl.text.trim().isEmpty ? '行动暂未完成，主要卡在：${_obstacleCtrl.text.trim()}' : _notDoneCtrl.text.trim(),
          actualRecovery: '把行动缩小到 2 分钟，并保留下一次开始的线索。',
          psychologicalAntibody: '没完成不是人格失败，而是流程需要继续缩小；我仍然可以重新开始。',
        );
      }
      if (!mounted) return;
      Navigator.pop(context, record);
    } catch (e) {
      _toast('保存复盘失败：$e');
    } finally {
      if (mounted) setState(() => _savingEvidence = false);
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('今日完整训练会话')),
      body: Column(
        children: <Widget>[
          _SessionProgressHeader(step: _step, level: _level, safetyMode: _safetyMode),
          Expanded(
            child: Stepper(
              currentStep: _step,
              type: StepperType.vertical,
              onStepTapped: (i) => setState(() => _step = i),
              controlsBuilder: (context, details) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(children: <Widget>[
                  if (_step > 0) TextButton(onPressed: () => setState(() => _step--), child: const Text('上一步')),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _generating || _savingEvidence ? null : _next,
                    icon: _generating || _savingEvidence
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(_step >= 6 ? Icons.check_circle_outline : Icons.arrow_forward),
                    label: Text(_label),
                  ),
                ]),
              ),
              steps: _steps(),
            ),
          ),
        ],
      ),
    );
  }

  String get _label {
    if (_generating) return '生成中';
    if (_savingEvidence) return '保存中';
    if (_step == 4) return '生成行动计划';
    if (_step == 6) return '完成会话';
    return '下一步';
  }

  void _next() {
    if (_step == 4) {
      _generateRecord();
      return;
    }
    if (_step == 6) {
      _saveEvidenceAndFinish();
      return;
    }
    if (_step == 1 && _safetyMode) {
      _toast('当前为 $_level，建议停留在稳定与现实支持，不进入普通重构。');
      return;
    }
    setState(() => _step++);
  }

  List<Step> _steps() => <Step>[
        Step(
          title: const Text('1. 从今天一件事开始'),
          isActive: _step >= 0,
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _PrincipleBox(title: '主线不是“想开”，而是完成训练闭环', text: '今天只处理一件事：承认现实 → 区分事实和解释 → 找回一个小行动 → 记录一条证据。'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _scenarios.map((s) => ChoiceChip(label: Text(s), selected: _scenario == s, onSelected: (_) => _applyScenario(s))).toList()),
            const SizedBox(height: 12),
            _TextBox(controller: _eventCtrl, label: '今天这一件事', hint: '写一句话就够，不需要完整，不需要漂亮。', minLines: 4, onChanged: (_) => setState(() {})),
            const SizedBox(height: 10),
            _LevelCard(level: _level),
          ]),
        ),
        Step(
          title: const Text('2. 允许自己为人'),
          isActive: _step >= 1,
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _PrincipleBox(title: '先承认痛苦，不急着重构', text: '负面情绪不是人格失败。它说明这件事对你有影响。'),
            Wrap(spacing: 8, runSpacing: 8, children: _emotions.map((e) => ChoiceChip(label: Text(e), selected: _emotion == e, onSelected: (_) => setState(() => _emotion = e))).toList()),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: _bodies.map((b) => ChoiceChip(label: Text(b), selected: _body == b, onSelected: (_) => setState(() => _body = b))).toList()),
            Slider(value: _intensity, min: 0, max: 10, divisions: 10, label: _intensity.round().toString(), onChanged: (v) => setState(() => _intensity = v)),
            if (_safetyMode) _SafetyNotice(level: _level),
          ]),
        ),
        Step(
          title: const Text('3. 事实 ≠ 解释'),
          isActive: _step >= 2,
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _PrincipleBox(title: '不让痛苦垄断全部解释权', text: '事实是发生了什么；解释是你脑中如何讲这个故事。这里开始训练解释风格。'),
            _TextBox(controller: _factCtrl, label: '事实层', hint: '只写可观察事实。', minLines: 3),
            _TextBox(controller: _unknownCtrl, label: '未知/假设', hint: '哪些只是猜测？哪些还没有证据？', minLines: 2),
            _TextBox(controller: _storyCtrl, label: '脑中故事 / 自动解释', hint: '例如：我永远坚持不了。', minLines: 3),
            _TextBox(controller: _fearCtrl, label: '我担心它说明什么', hint: '它好像在定义我什么？预测什么未来？', minLines: 2),
          ]),
        ),
        Step(
          title: const Text('4. 双镜头 + 主动性'),
          isActive: _step >= 3,
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _PrincipleBox(title: '同一现实，不同解释', text: 'Benefit Finder 不是否认坏事，而是在坏事中保留资源、学习和可行动部分。'),
            _PreviewCard(title: 'Fault Finder 镜头', text: _faultPreview(), icon: Icons.search_off_outlined),
            _PreviewCard(title: 'Benefit Finder 镜头', text: _benefitPreview(), icon: Icons.auto_awesome_outlined),
            _TextBox(controller: _uncontrollableCtrl, label: '不可控', hint: '已经发生的事、他人的全部评价、无法保证的结果。', minLines: 2),
            _TextBox(controller: _influenceCtrl, label: '可影响', hint: '环境、准备方式、沟通方式、下一次尝试。', minLines: 2),
            _TextBox(controller: _controlCtrl, label: '可控制', hint: '现在能做的小动作。', minLines: 2),
          ]),
        ),
        Step(
          title: const Text('5. 过程行动计划'),
          isActive: _step >= 4,
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _PrincipleBox(title: '行动建立自我效能', text: '自信不是喊出来的。先设计一个小到能开始的动作，再用完成后的证据建立信心。'),
            _TextBox(controller: _actionCtrl, label: '今天 5 分钟行动', hint: '小到不能再小，今天就能开始。', minLines: 3),
            _TextBox(controller: _obstacleCtrl, label: '障碍预演', hint: '我可能卡在哪里？', minLines: 2),
            _TextBox(controller: _ifThenCtrl, label: 'If-Then', hint: '如果我又想逃避，就……', minLines: 2),
            if (_record != null) _PreviewCard(title: '已生成训练记录', text: '现在请继续完成执行/复盘，不要只停在分析结果。', icon: Icons.check_circle_outline),
          ]),
        ),
        Step(
          title: const Text('6. 执行 / 复盘'),
          isActive: _step >= 5,
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _PrincipleBox(title: '这里才是真正的闭环', text: '生成建议不是结束。完成或未完成，都要转成证据：我做了什么？卡在哪里？下一步如何缩小？'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('我已经完成了这个 5 分钟行动'),
              subtitle: Text(_actionCtrl.text.trim().isEmpty ? '完成一个小动作即可。' : _actionCtrl.text.trim()),
              value: _actionCompleted,
              onChanged: (v) => setState(() => _actionCompleted = v),
            ),
            if (_actionCompleted)
              _TextBox(controller: _evidenceCtrl, label: '行动证据', hint: '这个小动作证明了什么能力？', minLines: 3)
            else
              _TextBox(controller: _notDoneCtrl, label: '如果还没完成，卡点是什么？', hint: '不是人格失败，只是流程还需要缩小。', minLines: 3),
          ]),
        ),
        Step(
          title: const Text('7. 感恩 / Prime / 身份整合'),
          isActive: _step >= 6,
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _PrincipleBox(title: '把好东西留住，把身份证据沉淀下来', text: '感恩不是否认痛苦；Prime 不是口号；身份不是夸奖，而是来自你刚刚做过/复盘过的证据。'),
            _TextBox(controller: _gratitudeCtrl, label: '今天仍值得珍惜的一点', hint: '具体到一个人、一件事、一个身体感受、一个机会。', minLines: 2),
            _TextBox(controller: _primeCtrl, label: '明天提醒我的 Prime', hint: '一句能把我拉回行动和现实的短句。', minLines: 2),
            _TextBox(controller: _identityCtrl, label: '身份句', hint: '我正在成为一个……的人。', minLines: 2),
          ]),
        ),
      ];
}

class _SessionProgressHeader extends StatelessWidget {
  final int step;
  final String level;
  final bool safetyMode;
  const _SessionProgressHeader({required this.step, required this.level, required this.safetyMode});

  @override
  Widget build(BuildContext context) {
    final labels = <String>['事件', '情绪', '解释', '双镜头', '行动', '复盘', '身份'];
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            const Icon(Icons.route_outlined),
            const SizedBox(width: 8),
            const Expanded(child: Text('一个会话串起全部子功能', style: TextStyle(fontWeight: FontWeight.w900))),
            Chip(label: Text(level), backgroundColor: safetyMode ? Colors.red.withOpacity(.12) : null),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: <Widget>[
              for (int i = 0; i < labels.length; i++) ...<Widget>[
                Chip(
                  label: Text(labels[i]),
                  avatar: Icon(i < step ? Icons.check : i == step ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 16),
                ),
                if (i != labels.length - 1) const Icon(Icons.chevron_right, size: 18),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;
  const _PreviewCard({required this.title, required this.text, required this.icon});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(height: 1.45)),
            ])),
          ]),
        ),
      );
}

class _TextBox extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int minLines;
  final ValueChanged<String>? onChanged;
  const _TextBox({required this.controller, required this.label, required this.hint, this.minLines = 2, this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: controller, minLines: minLines, maxLines: minLines + 4, onChanged: onChanged, decoration: InputDecoration(labelText: label, hintText: hint, alignLabelWithHint: true, border: const OutlineInputBorder())),
  );
}

class _PrincipleBox extends StatelessWidget {
  final String title;
  final String text;
  const _PrincipleBox({required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.65), borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(text, style: const TextStyle(height: 1.4))]),
  );
}

class _LevelCard extends StatelessWidget {
  final String level;
  const _LevelCard({required this.level});
  @override
  Widget build(BuildContext context) {
    final text = level == 'L4' ? '安全优先：暂停普通训练流程，先寻求现实支持。' : level == 'L3' ? '高强度痛苦：先稳定，不强行找好处或感恩。' : level == 'L2' ? '中度痛苦：先承认情绪，再温和重构。' : '轻度挫折：可以进入完整训练闭环。';
    return Card(color: level == 'L4' || level == 'L3' ? Theme.of(context).colorScheme.errorContainer : null, child: Padding(padding: const EdgeInsets.all(12), child: Row(children: <Widget>[CircleAvatar(child: Text(level)), const SizedBox(width: 12), Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)))])));
  }
}

class _SafetyNotice extends StatelessWidget {
  final String level;
  const _SafetyNotice({required this.level});
  @override
  Widget build(BuildContext context) => Card(color: Theme.of(context).colorScheme.errorContainer, child: const Padding(padding: EdgeInsets.all(12), child: Text('当前不适合强行 Benefit Finding、强行感恩或要求自己马上行动。请优先稳定情绪、联系可信任的人，必要时寻求专业或紧急支持。')));
}

class _SliderField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _SliderField({required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text('$label：${value.round()}/10', style: const TextStyle(fontWeight: FontWeight.w800)), Slider(value: value, min: 0, max: 10, divisions: 10, label: value.round().toString(), onChanged: onChanged)]);
}

class _SimpleRowCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SimpleRowCard({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Card(child: ListTile(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(subtitle, maxLines: 5, overflow: TextOverflow.ellipsis)));
}

class _EmptyText extends StatelessWidget {
  final String text;
  const _EmptyText(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(18), child: Center(child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700))));
}

/// V12：围绕中心思想与核心价值体系的「价值环境化」业务流。
///
/// 设计原则：不新增用户需要理解的新理论；把最终方案中的子功能全部绑定在一条简明主线：
/// 现实与情绪 → 事实与解释 → 行动与预演 → 复盘与身份。
class RotCoreBusinessFlowPage extends StatefulWidget {
  final String initialText;
  final String initialScene;
  final String extraContext;

  const RotCoreBusinessFlowPage({
    super.key,
    this.initialText = '',
    this.initialScene = 'event_reframe',
    this.extraContext = '',
  });

  @override
  State<RotCoreBusinessFlowPage> createState() => _RotCoreBusinessFlowPageState();
}

class _RotCoreBusinessFlowPageState extends State<RotCoreBusinessFlowPage> {
  final RealisticOptimismTrainingAiService _ai = RealisticOptimismTrainingAiService();
  final RealisticOptimismTrainingDao _dao = RealisticOptimismTrainingDao();

  final TextEditingController _eventCtrl = TextEditingController();
  final TextEditingController _factCtrl = TextEditingController();
  final TextEditingController _interpretationCtrl = TextEditingController();
  final TextEditingController _unknownCtrl = TextEditingController();
  final TextEditingController _controllableCtrl = TextEditingController();
  final TextEditingController _actionCtrl = TextEditingController();
  final TextEditingController _obstacleCtrl = TextEditingController();
  final TextEditingController _ifThenCtrl = TextEditingController();
  final TextEditingController _evidenceCtrl = TextEditingController();
  final TextEditingController _gratitudeCtrl = TextEditingController();
  final TextEditingController _primeCtrl = TextEditingController();
  final TextEditingController _identityCtrl = TextEditingController();

  int _step = 0;
  bool _busy = false;
  bool _completedAction = true;
  double _intensity = 5;
  String _emotion = '自责';
  String _body = '胸口紧';
  String _entryScene = '今天一件事';

  static const List<String> _entryScenes = <String>[
    '今天一件事',
    '拖延卡住',
    '失败复盘',
    '被否定',
    '关系不舒服',
    '情绪低落',
  ];

  static const List<String> _emotions = <String>['自责', '焦虑', '羞耻', '失望', '害怕', '难过', '愤怒', '低落', '麻木'];
  static const List<String> _bodies = <String>['胸口紧', '胃沉', '头胀', '肩膀紧', '呼吸浅', '没力气', '想逃避'];

  static const Map<String, String> _eventExamples = <String, String>{
    '今天一件事': '今天有一件事让我卡住了，我想用现实主义乐观训练处理它。',
    '拖延卡住': '今天我又没有推进重要任务，越拖越自责。',
    '失败复盘': '今天一件重要的事没有做好，我很怕这说明我不行。',
    '被否定': '今天有人批评或否定了我，我一直在反复想。',
    '关系不舒服': '今天和一个人的互动让我不舒服，我担心关系变糟。',
    '情绪低落': '今天我状态很低，什么都不太想做。',
  };

  static const Map<String, String> _interpretationExamples = <String, String>{
    '今天一件事': '这件事可能说明我又不够好，之后也会继续这样。',
    '拖延卡住': '我永远坚持不了，我就是没有自控力。',
    '失败复盘': '这次失败说明我不适合做这件事。',
    '被否定': '别人这么说，说明我真的很差。',
    '关系不舒服': '关系变成这样，可能都是我的问题。',
    '情绪低落': '我现在这样，说明以后也不会好起来。',
  };

  static const Map<String, String> _actionExamples = <String, String>{
    '今天一件事': '只做一个能在 5 分钟内开始的小动作，不要求完成全部。',
    '拖延卡住': '只打开材料或文件，做 5 分钟，不要求完成。',
    '失败复盘': '写下这次失败暴露的 1 个具体环节和 1 个下次可调整动作。',
    '被否定': '把批评拆成“事实部分”和“评价部分”，只处理一个可改进点。',
    '关系不舒服': '写一条温和、具体、不攻击的信息草稿，先不发送。',
    '情绪低落': '站起来喝水或整理桌面 2 分钟，再做一个小到不能再小的动作。',
  };

  @override
  void initState() {
    super.initState();
    _entryScene = _sceneLabel(widget.initialScene);
    _applyEntryScene(_entryScene, overwriteEvent: widget.initialText.trim().isEmpty);
    if (widget.initialText.trim().isNotEmpty) {
      _eventCtrl.text = widget.initialText.trim();
      _factCtrl.text = '可观察事实：${widget.initialText.trim().replaceAll('\n', ' ')}';
    }
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _eventCtrl,
      _factCtrl,
      _interpretationCtrl,
      _unknownCtrl,
      _controllableCtrl,
      _actionCtrl,
      _obstacleCtrl,
      _ifThenCtrl,
      _evidenceCtrl,
      _gratitudeCtrl,
      _primeCtrl,
      _identityCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _sceneLabel(String scene) {
    switch (scene) {
      case 'process_action':
        return '拖延卡住';
      case 'failure_immunity':
      case 'controlled_failure_challenge':
        return '失败复盘';
      case 'emotion_container':
        return '情绪低落';
      case 'gratitude_savoring':
      case 'prime_design':
      case 'anti_prime_cleanup':
      case 'identity_evidence':
      case 'event_reframe':
      case 'intensity_check':
      case 'explanation_radar':
      case 'dual_lens':
      default:
        return '今天一件事';
    }
  }

  void _applyEntryScene(String value, {bool overwriteEvent = true}) {
    setState(() {
      _entryScene = value;
      if (overwriteEvent) _eventCtrl.text = _eventExamples[value]!;
      _factCtrl.text = '可观察事实：${_eventCtrl.text.replaceAll('\n', ' ')}';
      _unknownCtrl.text = '别人的全部想法、未来会怎样、这件事是否代表我整个人。';
      _interpretationCtrl.text = _interpretationExamples[value]!;
      _controllableCtrl.text = '我现在能控制的是：先做一个很小、今天能开始的动作。';
      _actionCtrl.text = _actionExamples[value]!;
      _obstacleCtrl.text = '我可能卡在：目标太大、害怕做不好、手机干扰、等状态变好。';
      _ifThenCtrl.text = '如果我又想逃避，就把行动缩小到 2 分钟，只求开始。';
      _evidenceCtrl.text = '我愿意用一个小行动证明：我不需要等状态完美，也能重新开始。';
      _gratitudeCtrl.text = '今天仍然值得珍惜的是：我还可以从一个小动作重新开始。';
      _primeCtrl.text = '今日 Prime：先做一个行动证据，不等状态完美。';
      _identityCtrl.text = '我正在成为一个承认现实、允许情绪、并用小行动创造证据的人。';
      _emotion = value == '被否定' ? '羞耻' : value == '关系不舒服' ? '难过' : value == '情绪低落' ? '低落' : '自责';
      _body = value == '情绪低落' ? '没力气' : value == '关系不舒服' ? '胃沉' : '胸口紧';
      _intensity = value == '情绪低落' ? 6 : 5;
    });
  }

  String get _level {
    final text = '${_eventCtrl.text}\n${_interpretationCtrl.text}\n$_emotion';
    if (text.contains('不想活') || text.contains('自杀') || text.contains('伤害自己') || text.contains('活不下去')) return 'L4';
    if (text.contains('绝望') || text.contains('创伤') || text.contains('重大失去') || _intensity >= 9) return 'L3';
    if (_intensity >= 6 || _entryScene != '今天一件事') return 'L2';
    return 'L1';
  }

  bool get _safetyMode => _level == 'L3' || _level == 'L4';

  String _faultLens() {
    final story = _interpretationCtrl.text.trim().isEmpty ? _interpretationExamples[_entryScene]! : _interpretationCtrl.text.trim();
    return 'Fault Finder 会把现实收缩成：“$story”。它通常会放大永久化、普遍化、人格化或灾难化，让人更无力，也更难行动。';
  }

  String _benefitLens() {
    final action = _actionCtrl.text.trim().isEmpty ? _actionExamples[_entryScene]! : _actionCtrl.text.trim();
    return 'Benefit Finder 不说坏事是好事，而是在承认痛苦之后问：这件事里还有什么事实、资源、学习、关系或可控点？今天先用这个小动作保留主动性：$action';
  }

  Future<void> _finish() async {
    if (_eventCtrl.text.trim().isEmpty) {
      _toast('先写一句今天发生了什么，或你现在卡在哪里。');
      setState(() => _step = 0);
      return;
    }
    if (_safetyMode) {
      _toast('当前是 $_level：请先停在稳定与现实支持，不强行进入普通重构。');
      setState(() => _step = 0);
      return;
    }
    setState(() => _busy = true);
    try {
      await _dao.ensureTables();
      final result = await _ai.generate(userInput: _buildTrainingInput(), scene: 'event_reframe', extraContext: widget.extraContext);
      final record = result.record;
      await _dao.upsertRecord(record);
      final now = DateTime.now().millisecondsSinceEpoch;
      await _dao.addActionEvidence(RealisticOptimismTrainingActionEvidence(
        id: 'rot_v10_action_${record.id}_$now',
        recordId: record.id,
        action: _actionCtrl.text.trim().isEmpty ? record.fiveMinuteAction : _actionCtrl.text.trim(),
        evidenceText: _completedAction
            ? (_evidenceCtrl.text.trim().isEmpty ? '我完成了一个小行动，积累了一条行动证据。' : _evidenceCtrl.text.trim())
            : '我还没有完成行动，但我已经看见卡点：${_obstacleCtrl.text.trim()}。下一步会把行动缩小。',
        completed: _completedAction,
        completedAtMs: _completedAction ? now : null,
        selfEfficacyScore: _completedAction ? 6 : 3,
        createdAtMs: now,
      ));
      if (!_completedAction) {
        await _dao.addFailureRecoveryReview(
          recordId: record.id,
          actualPain: _intensity,
          actualResult: '行动暂未完成，主要卡点：${_obstacleCtrl.text.trim()}',
          actualRecovery: '把行动缩小到 2 分钟，并保留重新开始的线索。',
          psychologicalAntibody: '没完成不是人格失败，而是流程需要继续缩小；我仍然可以重新开始。',
        );
      }
      if (!mounted) return;
      Navigator.pop(context, record);
    } catch (e) {
      _toast('保存完整训练失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _buildTrainingInput() => '''
【V12 核心价值环境化业务流：围绕中心思想和核心价值体系】
本模块只围绕最终方案中的核心链路，不新增额外理论：
不否认现实；允许情绪；区分事实和解释；不让痛苦垄断解释权；用 5 分钟行动创造证据；失败用于心理免疫；用 Prime 设计注意力；用感恩保持完整现实感；用身份句沉淀证据。

一、现实与情绪
入口类型：$_entryScene
强度分级：$_level
事件：${_eventCtrl.text.trim()}
情绪：$_emotion，强度 ${_intensity.round()}/10，身体感受：$_body

二、事实与解释
事实层：${_factCtrl.text.trim()}
未知/假设：${_unknownCtrl.text.trim()}
自动解释：${_interpretationCtrl.text.trim()}
Fault Finder 预览：${_faultLens()}
Benefit Finder 预览：${_benefitLens()}

三、行动与预演
可控点：${_controllableCtrl.text.trim()}
5 分钟行动：${_actionCtrl.text.trim()}
障碍预演：${_obstacleCtrl.text.trim()}
If-Then：${_ifThenCtrl.text.trim()}

四、复盘与沉淀
行动是否完成：${_completedAction ? '已完成/准备完成' : '暂未完成'}
行动证据：${_evidenceCtrl.text.trim()}
今天仍值得珍惜：${_gratitudeCtrl.text.trim()}
今日 Prime：${_primeCtrl.text.trim()}
身份句：${_identityCtrl.text.trim()}

输出必须完整覆盖最终方案：强度分级、情绪允许、事实-解释分离、解释风格雷达、Fault/Benefit 双镜头、可控点、过程行动、失败免疫、感恩品味、Prime、身份沉淀。语言必须简单、可执行、非鸡汤。
''';

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final steps = _steps();
    return Scaffold(
      appBar: AppBar(title: const Text('解决今天一个实际问题')),
      body: Column(children: <Widget>[
        _CoreFlowHeader(step: _step, level: _level),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: RotCoreValueGuideCard(
            title: RotCoreValueCopy.researchAnchorsTitle,
            body: RotCoreValueCopy.researchAnchorsBody,
            icon: Icons.science_outlined,
          ),
        ),
        Expanded(
          child: Stepper(
            currentStep: _step,
            type: StepperType.vertical,
            onStepTapped: (i) => setState(() => _step = i),
            controlsBuilder: (context, details) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(children: <Widget>[
                if (_step > 0) TextButton(onPressed: () => setState(() => _step--), child: const Text('上一步')),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _busy ? null : () {
                    if (_step == steps.length - 1) {
                      _finish();
                    } else if (_step == 0 && _safetyMode) {
                      _toast('当前为 $_level，先做稳定与现实支持，不进入普通重构。');
                    } else {
                      setState(() => _step++);
                    }
                  },
                  icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_step == steps.length - 1 ? Icons.check_circle_outline : Icons.arrow_forward),
                  label: Text(_busy ? '保存中' : _step == steps.length - 1 ? '完成并沉淀' : '下一步'),
                ),
              ]),
            ),
            steps: steps,
          ),
        ),
      ]),
    );
  }

  List<Step> _steps() => <Step>[
        Step(
          title: const Text('1. 现实与情绪'),
          isActive: _step >= 0,
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const _CoreValueNotice(),
            RotCoreValueGuideCard(title: RotCoreValueCopy.stageTitle(0), body: RotCoreValueCopy.stageBody(0), icon: Icons.favorite_border),
            _PrincipleBox(title: '今天只处理一个真实问题', text: '不是把所有事情想明白，也不是强迫自己积极。先承认：发生了什么？我现在有什么情绪？'),
            Wrap(spacing: 8, runSpacing: 8, children: _entryScenes.map((s) => ChoiceChip(label: Text(s), selected: _entryScene == s, onSelected: (_) => _applyEntryScene(s))).toList()),
            const SizedBox(height: 10),
            _TextBox(controller: _eventCtrl, label: '今天这一件事', hint: '一句话就够：发生了什么，或我卡在哪里。', minLines: 3, onChanged: (_) => setState(() {})),
            Wrap(spacing: 8, runSpacing: 8, children: _emotions.map((e) => ChoiceChip(label: Text(e), selected: _emotion == e, onSelected: (_) => setState(() => _emotion = e))).toList()),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _bodies.map((b) => ChoiceChip(label: Text(b), selected: _body == b, onSelected: (_) => setState(() => _body = b))).toList()),
            _SliderField(label: '情绪强度', value: _intensity, onChanged: (v) => setState(() => _intensity = v)),
            _LevelCard(level: _level),
            if (_safetyMode) _SafetyNotice(level: _level),
          ]),
        ),
        Step(
          title: const Text('2. 事实与解释'),
          isActive: _step >= 1,
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.stageTitle(1), body: RotCoreValueCopy.stageBody(1), icon: Icons.fact_check_outlined),
            _PrincipleBox(title: '事实不等于解释', text: '痛苦会让解释变窄。这里不是否认痛苦，而是把事实、未知和脑中故事分开。'),
            _TextBox(controller: _factCtrl, label: '事实层', hint: '只写可观察事实。', minLines: 2),
            _TextBox(controller: _unknownCtrl, label: '未知 / 假设', hint: '哪些还没有证据？', minLines: 2),
            _TextBox(controller: _interpretationCtrl, label: '脑中自动解释', hint: '例如：我永远坚持不了。', minLines: 2, onChanged: (_) => setState(() {})),
            _PreviewCard(title: 'Fault Finder 镜头', text: _faultLens(), icon: Icons.search_off_outlined),
            _PreviewCard(title: 'Benefit Finder 镜头', text: _benefitLens(), icon: Icons.auto_awesome_outlined),
          ]),
        ),
        Step(
          title: const Text('3. 行动与预演'),
          isActive: _step >= 2,
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.stageTitle(2), body: RotCoreValueCopy.stageBody(2), icon: Icons.directions_run_outlined),
            _PrincipleBox(title: '行动建立自我效能', text: '真正的乐观不是口号，而是今天仍然能做一个小动作。动作越小，越容易形成证据。'),
            _TextBox(controller: _controllableCtrl, label: '现在可控的一点', hint: '我现在能控制的是……', minLines: 2),
            _TextBox(controller: _actionCtrl, label: '5 分钟行动', hint: '小到今天能开始，不要求完成全部。', minLines: 2, onChanged: (_) => setState(() {})),
            _TextBox(controller: _obstacleCtrl, label: '障碍预演', hint: '我可能卡在哪里？', minLines: 2),
            _TextBox(controller: _ifThenCtrl, label: 'If-Then', hint: '如果我又想逃避，就……', minLines: 2),
          ]),
        ),
        Step(
          title: const Text('4. 复盘与身份'),
          isActive: _step >= 3,
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.stageTitle(3), body: RotCoreValueCopy.stageBody(3), icon: Icons.badge_outlined),
            _PrincipleBox(title: '完成或没完成，都进入闭环', text: '完成了，就是行动证据；没完成，不是人格失败，而是失败免疫材料。最后把它沉淀成 Prime、感恩和身份句。'),
            SwitchListTile(
              value: _completedAction,
              onChanged: (v) => setState(() => _completedAction = v),
              title: const Text('我完成了 / 准备立刻完成这个 5 分钟行动'),
              subtitle: Text(_actionCtrl.text.trim().isEmpty ? '先完成一个小动作。' : _actionCtrl.text.trim()),
            ),
            _TextBox(controller: _evidenceCtrl, label: _completedAction ? '行动证据' : '没完成时的卡点', hint: _completedAction ? '这个小动作证明了什么？' : '卡在哪里？下一步如何缩小？', minLines: 2),
            _TextBox(controller: _gratitudeCtrl, label: '今天仍值得珍惜的一点', hint: '不是强行感恩，而是不让坏事吞掉全部现实。', minLines: 2),
            _TextBox(controller: _primeCtrl, label: '明天提醒自己的 Prime', hint: '一句会把注意力拉回可控行动的话。', minLines: 2),
            _TextBox(controller: _identityCtrl, label: '身份沉淀', hint: '我正在成为一个……的人。', minLines: 2),
          ]),
        ),
      ];
}

class _CoreValueNotice extends StatelessWidget {
  const _CoreValueNotice();

  @override
  Widget build(BuildContext context) => const RotCoreValueGuideCard(
        title: RotCoreValueCopy.centerTitle,
        body: RotCoreValueCopy.centerBody,
        icon: Icons.lightbulb_outline,
      );
}

class _CoreFlowHeader extends StatelessWidget {
  final int step;
  final String level;
  const _CoreFlowHeader({required this.step, required this.level});

  @override
  Widget build(BuildContext context) {
    final labels = <String>['现实情绪', '事实解释', '行动预演', '复盘身份'];
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            const Icon(Icons.account_tree_outlined),
            const SizedBox(width: 8),
            const Expanded(child: Text('一个问题，一条业务闭环', style: TextStyle(fontWeight: FontWeight.w900))),
            Chip(label: Text(level)),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: <Widget>[
              for (int i = 0; i < labels.length; i++) ...<Widget>[
                Chip(label: Text(labels[i]), avatar: Icon(i < step ? Icons.check : i == step ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 16)),
                if (i != labels.length - 1) const Icon(Icons.chevron_right, size: 18),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
