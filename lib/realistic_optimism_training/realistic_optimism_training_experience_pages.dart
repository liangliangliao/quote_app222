import 'dart:convert';

import 'package:flutter/material.dart';

import 'realistic_optimism_training_ai_service.dart';
import 'realistic_optimism_training_dao.dart';
import 'realistic_optimism_training_models.dart';


class RotCoreValueCopy {
  static const String centerTitle = '中心思想';
  static const String centerBody = '现实主义乐观不是先让人积极，而是先让人把现实说清楚：坏的、痛的、不公平的、失去的部分都可以被看见；然后区分事实和痛苦解释，不让痛苦垄断全部现实；最后带着难受保留一个可控行动、一个珍惜入口和一点继续出马的勇气。';
  static const String environmentBody = '本模块所有页面、提醒、待办和周报都只服务一条主线：记录真实 → 承认坏的现实 → 允许自己为人 → 看清痛苦解释 → 补全现实 → 做一个勇气出马动作 → 沉淀证据。日常、环境和周报只是实践层，不是中心本身。';
  static const String researchAnchorsTitle = '研究与案例锚点';
  static const String researchAnchorsBody = 'Lecture 7–9 前半段的锚点不是为了堆概念，而是共同指向一条生命实践：现实里确实有痛苦、失败、羞辱、不公平和失去；但人不必因此自暴自弃。Bandura 自我效能说明勇气来自行动证据；心理免疫说明失败后恢复会长出抗体；Tal 的失败故事说明同一现实可以有更完整解释；火灾研究说明不美化损失也能保留资源；启动实验说明环境会启动身份脚本；祖母故事说明看见坟墓也仍能看见世界之美。';

  static String stageTitle(int step) {
    switch (step) {
      case 0:
        return '核心价值：先真实，再乐观';
      case 1:
        return '核心价值：事实不等于解释';
      case 2:
        return '核心价值：行动建立自我效能';
      case 3:
      default:
        return '核心价值：行动、注意与感恩共同创造心理现实';
    }
  }

  static String stageBody(int step) {
    switch (step) {
      case 0:
        return '第一步不是找好处，而是把现实说清楚：发生了什么、哪里真的不好、哪里不能被美化。只有先真实，后面的乐观才不是鸡汤。';
      case 1:
        return '痛苦会把解释变窄。这里训练的是把“发生了什么”和“我脑中怎么解释”分开，防止 问题放大视角 把一次事件扩大成整个人生。';
      case 2:
        return '真正的乐观不是口号，而是保留一点主动性：找出可控点，预演障碍，用 5 分钟行动创造一条证据。';
      case 3:
      default:
        return '完成了就形成行动证据；没完成也不是人格判决，而是心理免疫材料。随后用注意力启动线索支持下一次行动，用具体感恩保持完整现实感。';
    }
  }

  static String sceneTitle(String scene) {
    switch (scene) {
      case 'reality_record':
        return '真实现实记录的价值';
      case 'intensity_check':
        return '事件强度分级的价值';
      case 'event_reframe':
        return '今日事件重构的价值';
      case 'emotion_container':
        return '允许自己为人的价值';
      case 'explanation_radar':
        return '解释风格雷达的价值';
      case 'dual_lens':
        return '问题放大视角 / 资源发现视角的价值';
      case 'failure_immunity':
        return '失败免疫的价值';
      case 'controlled_failure_challenge':
        return '可控失败挑战的价值';
      case 'process_action':
        return '过程模拟行动器的价值';
      case 'prime_design':
        return '注意力启动线索 的价值';
      case 'anti_prime_cleanup':
        return '消极启动源清理的价值';
      case 'gratitude_savoring':
        return '感恩与品味的价值';
      case 'complete_reality':
        return '完整现实感练习的价值';
      case 'appreciation_scan':
        return '防贬值珍惜扫描的价值';
      case 'same_reality_interpretations':
        return '同一现实，多种解释的价值';
      case 'loss_resource_retention':
        return '损失后的资源保留练习的价值';
      case 'priming_diagnostic':
        return '启动源诊断器的价值';
      case 'identity_script_activation':
        return '身份脚本启动练习的价值';
      case 'gratitude_time_in':
        return '感恩静心分享闭环的价值';
      case 'process_simulation_check':
        return '过程模拟校验器的价值';
      case 'psychological_immunity_experiment':
        return '心理免疫实验的价值';
      case 'identity_evidence':
        return '身份沉淀的价值';
      case 'weekly_baseline':
        return '幸福基线周报的价值';
      case 'todo_goal_bridge':
        return '待办事项/目标联动的价值';
      case 'daily_review':
        return '每日复盘的价值';
      case 'course_card':
        return '课程知识卡的价值';
      case 'role_model_case':
        return '榜样案例库的价值';
      case 'proactive_reminder':
        return '主动提醒的价值';
      case 'monthly_report':
        return '周/月报图表的价值';
      default:
        return '核心训练价值';
    }
  }

  static String sceneBody(String scene) {
    switch (scene) {
      case 'reality_record':
        return '这是整个系统的主入口：不是先选工具，而是先记录一件真实发生的事，承认它确实不好的部分，再看清解释、补全现实、做一个勇气出马动作。';
      case 'intensity_check':
        return '先判断 L1/L2/L3/L4，决定现在适合重构、行动、稳定，还是安全优先，避免把乐观训练变成强行积极。';
      case 'event_reframe':
        return '围绕一个真实事件完成“情绪允许 → 事实解释分离 → 双镜头 → 可控行动 → 身份证据”的完整闭环。';
      case 'emotion_container':
        return '先允许情绪存在，不急着修理自己。只有情绪被承认，后面的重构和行动才不是压抑。';
      case 'explanation_radar':
        return '看见自动解释中的永久化、普遍化、人格化、灾难化、无力化、过滤化，恢复更完整的现实观看方式。';
      case 'dual_lens':
        return '问题放大视角 负责看见痛苦和风险；资源发现视角 不是否认痛苦，而是在痛苦之外找回事实、资源、学习和可控点。';
      case 'failure_immunity':
        return '失败不是人格判决，而是心理免疫材料：比较预测痛苦与实际恢复，沉淀下次更小、更稳的行动。';
      case 'controlled_failure_challenge':
        return '用低风险、不伤害自己的方式练习承受不完美、拒绝和尴尬，证明失败通常不是灾难终点。';
      case 'process_action':
        return '把目标从结果焦虑转为过程路径：第一步、障碍、如果-那么、5 分钟启动，用行动证据建立自我效能。';
      case 'prime_design':
        return '注意力会塑造体验现实：把价值词、锁屏句、环境线索放到每天可见的位置，让注意力回到可控行动。';
      case 'anti_prime_cleanup':
        return '识别会启动比较、拖延、无力感的环境线索，把它们替换成更支持行动和恢复的 注意力启动线索。';
      case 'gratitude_savoring':
        return '感恩不是假装一切都好，而是不让坏事吞掉全部现实；训练看见仍然存在的资源、关系和珍惜。';
      case 'complete_reality':
        return '把祖母故事功能化：我不否认痛苦，也不遗漏仍然存在的美、善、关系和珍惜行动。';
      case 'appreciation_scan':
        return '对应 不被珍惜的东西，会在心理上贬值：扫描正在习以为常、失去后会后悔没珍惜的东西。';
      case 'same_reality_interpretations':
        return '对应 Tal 失败故事：事实不变，但解释可以从终局判决转为训练、谦卑、补基础和未来能力来源。';
      case 'loss_resource_retention':
        return '对应火灾研究：不美化损失，而是在损失中看见没有一起失去的资源、关系、价值和重新开始。';
      case 'priming_diagnostic':
        return '对应 Bargh 启动实验：识别应用、词语、图像、环境如何启动拖延/比较/无力，并设计替代线索。';
      case 'identity_script_activation':
        return '对应教授/足球流氓启动实验：识别自己被启动成哪个身份脚本，并设计更支持行动的身份脚本。';
      case 'gratitude_time_in':
        return '对应感恩静心分享：安静写下具体感恩，品味身体感受，并把感谢带回关系表达。';
      case 'process_simulation_check':
        return '把过程模拟研究变成校验器：没有时间、地点、工具、第一步、去干扰和完成标准，就不算有效行动计划。';
      case 'psychological_immunity_experiment':
        return '把心理免疫比喻变成实验：失败前预测、失败后实际、痛苦差异、恢复差异和心理抗体。';
      case 'identity_evidence':
        return '身份不是靠口号建立，而是由一次次行动、恢复、珍惜和重新开始的证据积累出来。';
      case 'weekly_baseline':
        return '长期追踪解释风格、行动证据、失败恢复、注意力启动线索和感恩敏感度，形成下一周只练一个重点。';
      case 'todo_goal_bridge':
        return '待办事项没完成时不只显示失败，而是转入情绪允许、解释风格、资源发现视角 和明日最小行动。';
      case 'daily_review':
        return '把一天的事件、行动证据、感恩品味、身份提醒和明日注意力启动线索 自动串成复盘闭环。';
      case 'course_card':
        return '把 Lecture 7–9 前半段的核心锚点转成可读、可练、可行动的知识卡。';
      case 'role_model_case':
        return '用 Tal 失败故事、火灾研究和祖母故事训练“同一现实可以有更完整解释”的替代证据。';
      case 'proactive_reminder':
        return '把 AI 提醒落到触发条件、锁屏短句、小组件文案和一个行动线索。';
      case 'monthly_report':
        return '把周报/月报从文字总结升级为解释风格、行动证据、失败免疫和身份成长趋势。';
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
  final _badRealityCtrl = TextEditingController();
  final _notBeautifyCtrl = TextEditingController();
  final _stillHereCtrl = TextEditingController();
  final _completeRealitySentenceCtrl = TextEditingController();
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
    _eventCtrl.text = widget.initialText.trim().isEmpty ? '今天我又没有推进重要任务，越拖越自责，担心自己永远坚持不了。' : widget.initialText.trim();
    _badRealityCtrl.text = '我确实没有推进，时间已经过去了，自责和焦虑也确实存在。';
    _notBeautifyCtrl.text = '我不把它说成“这正好很好”。它确实让我失望，也影响了今天的状态。';
    _stillHereCtrl.text = '任务还在；我还有明天和现在的 5 分钟；我还可以把第一步缩小；我还没有失去重新开始的能力。';
    _completeRealitySentenceCtrl.text = '这件事确实让我难受，也有不好的部分；但它不是我全部的现实。我仍然能做一个很小的出马动作。';
    _emotionCtrl.text = '自责、焦虑，还有一点羞耻。';
    _bodyCtrl.text = '胸口紧，肩膀紧，想逃避。';
    _factCtrl.text = '今天我确实没有打开材料；任务还没有开始；现在已经晚上了。';
    _unknownCtrl.text = '我不知道明天是否一定失败，也不知道这是否代表我整个人。';
    _thoughtCtrl.text = '我永远坚持不了，我就是没有自控力。';
    _fearCtrl.text = '我担心这说明我以后也做不成重要的事。';
    _uncontrollableCtrl.text = '今天已经过去的时间、别人怎么看、过去没有开始的事实。';
    _influenceCtrl.text = '任务大小、手机距离、明天开始前的环境。';
    _controlCtrl.text = '现在只打开文件 5 分钟，不要求完成。';
    _actionCtrl.text = '打开材料，读第一段，写一句标题，5 分钟后停止。';
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[_eventCtrl, _badRealityCtrl, _notBeautifyCtrl, _stillHereCtrl, _completeRealitySentenceCtrl, _emotionCtrl, _bodyCtrl, _factCtrl, _unknownCtrl, _thoughtCtrl, _fearCtrl, _uncontrollableCtrl, _influenceCtrl, _controlCtrl, _actionCtrl]) {
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
【现实记录主线：用户逐步完成的真实材料】
事件强度初判：$_level

Step 1 记录真实：
${_eventCtrl.text.trim()}

Step 2 承认坏的现实：
这件事哪里真的不好：${_badRealityCtrl.text.trim()}
不能被轻飘飘美化的部分：${_notBeautifyCtrl.text.trim()}

Step 3 允许自己为人：
最强情绪：${_emotionCtrl.text.trim()}
身体感受：${_bodyCtrl.text.trim()}

Step 4 事实与痛苦解释分离：
客观事实：${_factCtrl.text.trim()}
未知/假设：${_unknownCtrl.text.trim()}
脑中最强一句话：${_thoughtCtrl.text.trim()}
我最担心它说明什么：${_fearCtrl.text.trim()}

Step 5 补全现实：
即使如此仍然存在：${_stillHereCtrl.text.trim()}
不可控：${_uncontrollableCtrl.text.trim()}
可影响：${_influenceCtrl.text.trim()}
可控制：${_controlCtrl.text.trim()}

Step 6 勇气出马动作：
${_actionCtrl.text.trim()}

Step 7 完整现实句草稿：
${_completeRealitySentenceCtrl.text.trim()}

请严格按“先真实，再乐观”的主线输出：记录现实 → 承认坏的部分 → 允许痛苦存在 → 看清痛苦解释 → 补全现实 → 一个勇气出马动作 → 完整现实句。不要鸡汤，不要说“一切都是最好的安排”。
''';
      final result = await _ai.generate(userInput: structuredInput, scene: 'reality_record', extraContext: widget.extraContext);
      final payload = Map<String, dynamic>.from(result.record.payload);
      payload['scene'] = 'reality_record';
      payload['user_event_summary'] = _eventCtrl.text.trim();
      payload['reality_record'] = <String, Object?>{
        'what_happened': _eventCtrl.text.trim(),
        'what_is_truly_bad': _badRealityCtrl.text.trim(),
        'not_to_be_beautified': _notBeautifyCtrl.text.trim(),
        'allowed_emotion': _emotionCtrl.text.trim(),
        'body_signal': _bodyCtrl.text.trim(),
        'pain_interpretation': _thoughtCtrl.text.trim(),
        'what_still_exists': _splitLines(_stillHereCtrl.text),
        'controllable_point': _controlCtrl.text.trim(),
        'courage_action': _actionCtrl.text.trim(),
        'complete_reality_sentence': _completeRealitySentenceCtrl.text.trim(),
      };
      final benefit = Map<String, dynamic>.from((payload['benefit_finder_layer'] is Map) ? payload['benefit_finder_layer'] as Map : const <String, dynamic>{});
      benefit['not_denied_pain'] = _badRealityCtrl.text.trim();
      benefit['balanced_interpretation'] = _completeRealitySentenceCtrl.text.trim();
      benefit['remaining_resources'] = _splitLines(_stillHereCtrl.text);
      payload['benefit_finder_layer'] = benefit;
      final action = Map<String, dynamic>.from((payload['process_action_plan'] is Map) ? payload['process_action_plan'] as Map : const <String, dynamic>{});
      action['five_minute_action'] = _actionCtrl.text.trim();
      action['next_three_steps'] = <String>[_actionCtrl.text.trim(), '完成后记录一句行动证据。', '今晚复盘：坏的是真的，但不是全部。'];
      payload['process_action_plan'] = action;
      final identity = Map<String, dynamic>.from((payload['identity_evidence'] is Map) ? payload['identity_evidence'] as Map : const <String, dynamic>{});
      identity['specific_action'] = _actionCtrl.text.trim();
      identity['proved_capacity'] = '我愿意承认现实中的坏，也仍然保留一个小行动。';
      identity['identity_type'] = '现实主义出马者';
      identity['identity_sentence'] = '我正在成为一个能看清现实、不粉饰痛苦，也不因此放弃行动的人。';
      payload['identity_evidence'] = identity;
      payload['final_user_message'] = _completeRealitySentenceCtrl.text.trim();
      final record = RealisticOptimismTrainingRecord.fromJson(payload);
      await _dao.upsertRecord(record);
      if (!mounted) return;
      Navigator.pop(context, record);
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  List<String> _splitLines(String text) => text
      .split(RegExp(r'[\n；;。]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final steps = _steps();
    return Scaffold(
      appBar: AppBar(title: const Text('记录真实现实')),
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
              label: Text(_generating ? '生成中' : _step == steps.length - 1 ? '生成完整现实结果' : '下一步'),
            ),
          ]),
        ),
        steps: steps,
      ),
    );
  }

  List<Step> _steps() => <Step>[
    Step(
      title: const Text('1. 记录真实发生的事'),
      isActive: _step >= 0,
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        _PrincipleBox(title: '先真实，再乐观', text: '这一步只描述现实：发生了什么、谁在场、你看到听到经历了什么。不急着找意义，也不急着积极。'),
        _TextBox(controller: _eventCtrl, label: '真实事件', hint: '今天发生了什么？请写具体，不需要完美。', minLines: 4, onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        _LevelCard(level: _level),
      ]),
    ),
    Step(
      title: const Text('2. 承认坏的现实'),
      isActive: _step >= 1,
      content: Column(children: <Widget>[
        _PrincipleBox(title: '坏的是真的，不能跳过', text: '现实主义乐观不是粉饰太平。请把这件事里痛的、坏的、不公平的、失去的部分说出来。'),
        _TextBox(controller: _badRealityCtrl, label: '这件事哪里真的不好', hint: '例如：我确实没有推进；被否定确实刺痛；这件事确实让我失望。', minLines: 3),
        _TextBox(controller: _notBeautifyCtrl, label: '哪一部分不能被轻飘飘美化', hint: '例如：我不把它说成“正好很好”。它确实造成了损失/羞辱/难受。', minLines: 3),
      ]),
    ),
    Step(
      title: const Text('3. 允许自己为人'),
      isActive: _step >= 2,
      content: Column(children: <Widget>[
        _PrincipleBox(title: '难受不等于不乐观', text: '羞耻、自责、失望、愤怒、害怕都可以存在。成熟的乐观不是消灭负面情绪，而是带着它继续看清现实。'),
        _TextBox(controller: _emotionCtrl, label: '最强情绪', hint: '例如：羞耻、自责、失望、愤怒、害怕、麻木', minLines: 2),
        _TextBox(controller: _bodyCtrl, label: '身体感受', hint: '例如：胸口紧、胃沉、头胀、肩膀紧', minLines: 2),
      ]),
    ),
    Step(
      title: const Text('4. 看清事实与痛苦解释'),
      isActive: _step >= 3,
      content: Column(children: <Widget>[
        _PrincipleBox(title: '事实不是解释', text: '痛苦会把解释变窄。这里不是否认痛苦，而是看清：哪些是事实，哪些是痛苦中的自动故事。'),
        _TextBox(controller: _factCtrl, label: '客观事实', hint: '只写可观察事实，不写“我很废”这类评价。', minLines: 3),
        _TextBox(controller: _unknownCtrl, label: '未知/假设', hint: '哪些是我猜的？哪些还没有证据？', minLines: 2),
        _TextBox(controller: _thoughtCtrl, label: '脑中最强的痛苦解释', hint: '例如：我永远坚持不了；我这个人就是不行。', minLines: 3),
        _TextBox(controller: _fearCtrl, label: '我最担心它说明什么', hint: '例如：说明我以后都找不到工作；说明我不值得被爱。', minLines: 2),
      ]),
    ),
    Step(
      title: const Text('5. 补全现实：坏的不是全部'),
      isActive: _step >= 4,
      content: Column(children: <Widget>[
        _PrincipleBox(title: '不让痛苦垄断全部现实', text: '这不是强行找好处，而是补全现实：什么还在？什么没有一起失去？我仍然能控制哪一小点？'),
        _TextBox(controller: _stillHereCtrl, label: '即使如此，仍然存在什么', hint: '人、关系、时间、能力、机会、身体、一点善意、一个可以重新开始的入口。', minLines: 3),
        _TextBox(controller: _uncontrollableCtrl, label: '不可控', hint: '已经发生的事、他人的全部评价、不能保证的结果。', minLines: 2),
        _TextBox(controller: _influenceCtrl, label: '可影响', hint: '准备方式、沟通方式、环境、下次尝试。', minLines: 2),
        _TextBox(controller: _controlCtrl, label: '可控制', hint: '我现在能做的小动作是什么？', minLines: 2),
      ]),
    ),
    Step(
      title: const Text('6. 勇气出马动作'),
      isActive: _step >= 5,
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        _PrincipleBox(title: '行动建立自我效能', text: '不是先感觉好再行动，而是先做一个小到能开始的动作。勇气不是没痛苦，而是带着痛苦仍然出马一步。'),
        _TextBox(controller: _actionCtrl, label: '我愿意今天开始的出马动作', hint: '例如：打开文件只改第一句话；只读第一段；把手机放远 5 分钟。', minLines: 3),
        _TextBox(controller: _completeRealitySentenceCtrl, label: '完整现实句', hint: '这件事确实让我痛，因为____；但它不是我全部的现实。我仍然能____。', minLines: 3),
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
    _goalCtrl.text = widget.initialGoal.trim().isEmpty ? '推进今天一直拖延的学习/工作任务。' : widget.initialGoal.trim();
    _whyCtrl.text = '这件事连接我的成长、自我效能和长期目标。';
    _obstacleCtrl.text = '我最容易卡在目标太大、怕做不好、刷手机、等状态变好。';
    _environmentCtrl.text = '手机在身边，桌面有点乱，任务材料没有提前打开。';
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
【过程模拟行动器】
目标/任务：${_goalCtrl.text.trim()}
为什么重要：${_whyCtrl.text.trim()}
最容易卡住：${_obstacleCtrl.text.trim()}
可投入时间：${_timeCtrl.text.trim()}
当前环境干扰：${_environmentCtrl.text.trim()}

请把目标转成真正可执行的过程：结果画面、时间地点工具、第一步、接下来三步、障碍预演、如果-那么、5分钟启动动作、完成后行动证据问题。请强调先行动再信心。
''';
      final result = await _ai.generate(userInput: input, scene: 'process_action', extraContext: widget.extraContext);
      await _dao.upsertRecord(result.record);
      if (!mounted) return;
      Navigator.pop(context, result.record);
    } catch (e) { _toast('生成失败：$e'); } finally { if (mounted) setState(() => _loading = false); }
  }

  List<String> _splitLines(String text) => text
      .split(RegExp(r'[\n；;。]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('过程模拟行动器')),
    body: ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      _PrincipleBox(title: '过程模拟优于结果幻想', text: '不只是想象成功，而是把目标拆成第一步、环境、障碍和 如果-那么。'),
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
  void initState() { super.initState(); _themeCtrl.text = '提交一个不完美版本，或主动复盘一次失败。'; _fearCtrl.text = '我害怕别人觉得我不行，也害怕这证明我真的没能力。'; _recoveryCtrl.text = '我预测会难受 2 小时，但可能会慢慢下降。'; _actualCtrl.text = '实际结果：最坏结果没有完全发生，我在复盘后恢复了一点行动力。'; _antibodyCtrl.text = '失败会痛，但不会定义我整个人；我可以通过复盘恢复主动性。'; _load(); }

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
【失败免疫实验室：失败前预测】
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

  List<String> _splitLines(String text) => text
      .split(RegExp(r'[\n；;。]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

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
  void initState() { super.initState(); _focusCtrl.text = '先做一个小行动证据，不等状态完美。'; _antiCtrl.text = '睡前刷短视频、桌面杂乱、打开任务前先看消息。'; _load(); }
  Future<void> _load() async { await _dao.ensureTables(); final p=await _dao.listPrimes(); final a=await _dao.listAntiPrimes(); if(mounted)setState((){_primes=p;_anti=a;}); }
  @override
  void dispose(){_focusCtrl.dispose();_antiCtrl.dispose();super.dispose();}

  Future<void> _generatePrime() async {
    if (_focusCtrl.text.trim().isEmpty) { _toast('请写下今天最需要被启动的状态。'); return; }
    setState(() => _loading = true);
    try {
      final result = await _ai.generate(userInput: '【注意力启动墙】今天最需要被启动的状态：${_focusCtrl.text.trim()}\n请生成今日价值词、锁屏短句、现实注意力启动线索、资源发现问题、今日行动线索。', scene: 'prime_design', extraContext: widget.extraContext);
      await _dao.upsertRecord(result.record);
      await _load();
    } catch(e){ _toast('生成失败：$e'); } finally { if(mounted)setState(()=>_loading=false); }
  }
  Future<void> _generateAntiPrime() async {
    if (_antiCtrl.text.trim().isEmpty) { _toast('请写下一个消极启动源。'); return; }
    setState(() => _loading = true);
    try {
      final result = await _ai.generate(userInput: '【消极启动源 环境清理】消极启动源：${_antiCtrl.text.trim()}\n请识别影响状态、清理动作、替代注意力启动线索和今天最小环境改造动作。', scene: 'anti_prime_cleanup', extraContext: widget.extraContext);
      await _dao.upsertRecord(result.record);
      await _load();
    } catch(e){ _toast('生成失败：$e'); } finally { if(mounted)setState(()=>_loading=false); }
  }

  void _toast(String text)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context)=>DefaultTabController(length: 2, child: Scaffold(
    appBar: AppBar(title: const Text('注意力启动线索与消极启动源 环境墙'), bottom: const TabBar(tabs: <Widget>[Tab(text:'今日注意力启动线索'),Tab(text:'消极启动源清理')]),),
    body: TabBarView(children: <Widget>[
      ListView(padding: const EdgeInsets.all(16), children: <Widget>[
        _PrincipleBox(title: '注意力会塑造体验现实', text: '你反复看到什么，就更容易相信什么、选择什么。这里不是记录，而是设计每日环境。'),
        _TextBox(controller: _focusCtrl, label: '今天最需要被启动的状态', hint: '行动、勇气、感恩、失败恢复、关系珍惜……', minLines: 2),
        FilledButton.icon(onPressed: _loading?null:_generatePrime, icon: const Icon(Icons.wallpaper_outlined), label: const Text('设计今日注意力启动线索')),
        const SizedBox(height: 12),
        ..._primes.map((r)=>_SimpleRowCard(title: (r['value_word']??'注意力启动线索').toString(), subtitle: '${r['reminder']??''}\n${r['benefit_question']??''}')),
      ]),
      ListView(padding: const EdgeInsets.all(16), children: <Widget>[
        _PrincipleBox(title: '清理会削弱你的启动源', text: '不是一次改变全部环境，只移除一个最强拖延、比较或无力感入口。'),
        _TextBox(controller: _antiCtrl, label: '消极启动源', hint: '应用、人、信息流、桌面、睡前手机、比较内容……', minLines: 3),
        FilledButton.icon(onPressed: _loading?null:_generateAntiPrime, icon: const Icon(Icons.cleaning_services_outlined), label: const Text('生成清理动作')),
        const SizedBox(height: 12),
        ..._anti.map((r)=>_SimpleRowCard(title: (r['trigger_name']??'消极启动源').toString(), subtitle: '影响：${r['effect']??''}\n清理：${r['cleanup_action']??''}\n替代：${r['replacement_prime']??''}')),
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
    return '问题放大视角 会把这件事讲成：$story\n它会让你更无力、更羞耻，也更容易停止行动。';
  }

  String _benefitPreview() {
    final fact = _factCtrl.text.trim().isEmpty ? _eventCtrl.text.trim() : _factCtrl.text.trim();
    final action = _actionCtrl.text.trim().isEmpty ? _actionExamples[_scenario]! : _actionCtrl.text.trim();
    return '资源发现视角 不是说这件事是好事，而是承认：$fact\n同时保留一个可控点：$action';
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
【今日一件事：零门槛现实主义乐观训练】

用户不是来听鸡汤，而是来完成一个小训练闭环。请严格围绕“承认痛苦，但不让痛苦垄断全部解释权；行动建立自我效能；身份由证据积累”来输出。

1. 当前场景：$_scenario
2. 事件强度初判：$_level
3. 真实事件：${_eventCtrl.text.trim()}
4. 最强情绪：$_emotion，强度 ${_intensity.round()}/10，身体感受：$_body
5. 事实层：${_factCtrl.text.trim()}
6. 脑中故事/自动解释：${_storyCtrl.text.trim()}
7. 问题放大视角 预览：${_faultPreview()}
8. 资源发现视角 预览：${_benefitPreview()}
9. 用户愿意做的 5 分钟行动：${_actionCtrl.text.trim()}
10. 今日仍值得珍惜/品味的一点：${_gratitudeCtrl.text.trim()}
11. 今日注意力启动线索：${_primeCtrl.text.trim()}

输出必须让用户感觉“我知道下一步怎么做”：
- 先承认情绪，不要劝“别难过”。
- 明确区分事实和解释。
- 标出永久化/普遍化/人格化/灾难化/无力化/过滤化里最明显的 1-3 个。
- 问题放大视角 要说明它如何让用户更无力。
- 资源发现视角 必须承认痛苦，不得说“一切都是最好的安排”。
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

  List<String> _splitLines(String text) => text
      .split(RegExp(r'[\n；;。]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

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
            title: '双镜头：问题放大视角 / 资源发现视角',
            subtitle: '资源发现视角 不是说坏事是好事，而是在坏事中保留一个可控点。',
            child: Column(children: <Widget>[
              _LensPreviewCard(title: '问题放大视角 会怎么讲', body: _faultPreview(), icon: Icons.search_off_outlined),
              _LensPreviewCard(title: '资源发现视角 可以怎么回应', body: _benefitPreview(), icon: Icons.manage_search_outlined),
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
              _TextBox(controller: _primeCtrl, label: '今日注意力启动线索 / 锁屏提醒', hint: '例如：先做一个行动证据。', minLines: 2),
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
      _primeCtrl.text = '今日注意力启动线索：先做一个行动证据，不等状态完美。';
      _identityCtrl.text = '我正在成为一个能承认痛苦但仍能行动的人。';
      _emotion = value == '被批评/被否定' ? '羞耻' : value == '关系不舒服' ? '难过' : value == '情绪低落' ? '低落' : '自责';
      _body = value == '情绪低落' ? '没力气' : value == '关系不舒服' ? '胃沉' : '胸口紧';
    });
  }

  String _faultPreview() {
    final story = _storyCtrl.text.trim().isEmpty ? _storyExamples[_scenario]! : _storyCtrl.text.trim();
    return '问题放大视角 会把这件事讲成：$story。它会让你更无力、更羞耻，也更容易停止行动。';
  }

  String _benefitPreview() {
    final action = _actionCtrl.text.trim().isEmpty ? _actionExamples[_scenario]! : _actionCtrl.text.trim();
    return '资源发现视角 不说坏事是好事，而是在承认痛苦后保留一个可控点：$action';
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
问题放大视角 预览：${_faultPreview()}
资源发现视角 预览：${_benefitPreview()}
不可控：${_uncontrollableCtrl.text.trim()}
可影响：${_influenceCtrl.text.trim()}
可控制：${_controlCtrl.text.trim()}

四、过程行动
5分钟行动：${_actionCtrl.text.trim()}
障碍预演：${_obstacleCtrl.text.trim()}
如果-那么：${_ifThenCtrl.text.trim()}

五、感恩/注意力启动线索/身份
今日仍值得珍惜：${_gratitudeCtrl.text.trim()}
今日注意力启动线索：${_primeCtrl.text.trim()}
身份句草稿：${_identityCtrl.text.trim()}

输出要求：
1. 先承认情绪，不劝“别难过”。
2. 明确区分事实和解释。
3. 标出最明显的解释风格陷阱。
4. 问题放大视角 必须说明它如何造成无力。
5. 资源发现视角 必须承认痛苦，不得说“一切都是最好的安排”。
6. 必须输出一个非常具体的 5 分钟行动、三步过程和 如果-那么。
7. 必须输出完成后要记录的行动证据问题。
8. 必须输出今日注意力启动线索、感恩/品味动作和“我正在成为一个……”身份句。
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

  List<String> _splitLines(String text) => text
      .split(RegExp(r'[\n；;。]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

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
            _TextBox(controller: _factCtrl, label: '事实层', hint: '例如：今天我没有打开材料；任务还没有开始；现在已经晚上了。', minLines: 3),
            _TextBox(controller: _unknownCtrl, label: '未知/假设', hint: '哪些只是猜测？哪些还没有证据？', minLines: 2),
            _TextBox(controller: _storyCtrl, label: '脑中故事 / 自动解释', hint: '例如：我永远坚持不了。', minLines: 3),
            _TextBox(controller: _fearCtrl, label: '我担心它说明什么', hint: '它好像在定义我什么？预测什么未来？', minLines: 2),
          ]),
        ),
        Step(
          title: const Text('4. 双镜头 + 主动性'),
          isActive: _step >= 3,
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _PrincipleBox(title: '同一现实，不同解释', text: '资源发现视角 不是否认坏事，而是在坏事中保留资源、学习和可行动部分。'),
            _PreviewCard(title: '问题放大视角 镜头', text: _faultPreview(), icon: Icons.search_off_outlined),
            _PreviewCard(title: '资源发现视角 镜头', text: _benefitPreview(), icon: Icons.auto_awesome_outlined),
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
            _TextBox(controller: _obstacleCtrl, label: '障碍预演', hint: '例如：我可能刷手机、害怕做不好、等状态变好才开始。', minLines: 2),
            _TextBox(controller: _ifThenCtrl, label: '如果-那么', hint: '例如：如果我又想逃避，就只做 2 分钟，并把手机放到远处。', minLines: 2),
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
          title: const Text('7. 感恩 / 注意力启动线索 / 身份整合'),
          isActive: _step >= 6,
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _PrincipleBox(title: '把好东西留住，把身份证据沉淀下来', text: '感恩不是否认痛苦；注意力启动线索不是口号；身份不是夸奖，而是来自你刚刚做过/复盘过的证据。'),
            _TextBox(controller: _gratitudeCtrl, label: '今天仍值得珍惜的一点', hint: '具体到一个人、一件事、一个身体感受、一个机会。', minLines: 2),
            _TextBox(controller: _primeCtrl, label: '明天提醒我的 注意力启动线索', hint: '一句能把我拉回行动和现实的短句。', minLines: 2),
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

/// V15：面向用户可理解性的「现实问题解决」核心业务流。
///
/// 设计原则：不新增用户需要理解的新理论；把最终方案中的子功能全部绑定在一条简明主线：
/// 现实与情绪 → 事实与解释 → 行动与预演 → 复盘与身份。
class RotCoreBusinessFlowPage extends StatefulWidget {
  final String initialText;
  final String initialScene;
  final String extraContext;
  final RealisticOptimismTrainingSession? session;

  const RotCoreBusinessFlowPage({
    super.key,
    this.initialText = '',
    this.initialScene = 'event_reframe',
    this.extraContext = '',
    this.session,
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
  String _sessionId = '';
  int _sessionCreatedAtMs = 0;
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
    final existing = widget.session;
    if (existing != null) {
      _restoreSession(existing);
    } else {
      final now = DateTime.now().millisecondsSinceEpoch;
      _sessionId = 'rot_session_${now}_${widget.initialScene.hashCode.abs()}';
      _sessionCreatedAtMs = now;
      _entryScene = _sceneLabel(widget.initialScene);
      _applyEntryScene(_entryScene, overwriteEvent: widget.initialText.trim().isEmpty);
      if (widget.initialText.trim().isNotEmpty) {
        _eventCtrl.text = widget.initialText.trim();
        _factCtrl.text = '可观察事实：${widget.initialText.trim().replaceAll('\n', ' ')}';
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveDraft(status: 'draft'));
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
      case 'process_simulation_check':
      case 'same_reality_interpretations':
      case 'loss_resource_retention':
      case 'todo_goal_bridge':
        return '拖延卡住';
      case 'failure_immunity':
      case 'controlled_failure_challenge':
      case 'psychological_immunity_experiment':
        return '失败复盘';
      case 'daily_review':
        return '今天一件事';
      case 'emotion_container':
        return '情绪低落';
      case 'gratitude_savoring':
      case 'complete_reality':
      case 'appreciation_scan':
      case 'gratitude_time_in':
        return '今天一件事';
      case 'priming_diagnostic':
      case 'identity_script_activation':
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


  String _sceneFocusInstruction(String scene) {
    switch (scene) {
      case 'emotion_container':
        return '只做情绪允许、身体确认、稳定动作；不要急着 Benefit Finding、感恩或身份拔高。';
      case 'process_action':
        return '只重点输出目标澄清、过程路径、障碍预演、如果-那么、5 分钟启动和行动证据。';
      case 'failure_immunity':
        return '只重点输出失败前预测、实际结果、承受住的部分、心理抗体和下一次更小行动。';
      case 'controlled_failure_challenge':
        return '只重点输出低风险挑战、执行步骤、安全边界、失败前预测和失败后复盘。';
      case 'gratitude_savoring':
        return '只重点输出具体感恩、30 秒品味、珍惜行动和关系表达，不否认痛苦。';
      case 'prime_design':
        return '只重点输出价值词、锁屏短句、现实 注意力启动线索、资源发现问题和行动线索。';
      case 'anti_prime_cleanup':
        return '只重点输出消极启动源、影响、最小清理动作和替代注意力启动线索。';
      case 'todo_goal_bridge':
        return '只重点把 待办事项/目标转为价值、解释检查、5 分钟行动、如果-那么 和完成证据。';
      case 'daily_review':
        return '只重点输出今日解释风格、行动证据、三件具体感恩、明日注意力启动线索和身份提醒。';
      case 'complete_reality':
        return '只重点输出祖母故事式完整现实：不否认痛苦、不美化痛苦、仍然看见还在的好和珍惜动作。';
      case 'appreciation_scan':
        return '只重点输出防贬值扫描：正在习以为常的好、失去后的后悔感、今天的珍惜动作。';
      case 'same_reality_interpretations':
        return '只重点输出同一事实、当前痛苦解释、Tal 式替代问题、更完整解释和第一步行动。';
      case 'loss_resource_retention':
        return '只重点输出损失、痛处、没有失去的资源、仍在的人、变清楚的价值和重新开始的一小块。';
      case 'priming_diagnostic':
        return '只重点输出消极启动源、被启动状态、想被启动成的状态、替代启动线索和清理动作。';
      case 'identity_script_activation':
        return '只重点输出今天被启动的身份脚本、来源、后果、明天要启动的身份脚本和环境线索。';
      case 'gratitude_time_in':
        return '只重点输出安静写下具体感恩、感官和身体感受、分享对象、表达文本和分享后记录。';
      case 'process_simulation_check':
        return '只重点输出时间、地点、工具、第一动作、干扰源、去干扰动作和完成标准，过滤结果幻想。';
      case 'psychological_immunity_experiment':
        return '只重点输出失败前预测、失败后实际、痛苦差异、恢复差异、最坏预测和心理抗体。';
      case 'course_card':
      case 'role_model_case':
      case 'proactive_reminder':
      case 'monthly_report':
        return '只重点输出可复用的日常实践产物，不展示完整事件重构大报告。';
      case 'event_reframe':
      default:
        return '输出完整事件重构闭环：强度、情绪、事实解释、解释风格、双镜头、可控点、行动、身份。';
    }
  }



  String _closureStepTitle() {
    switch (widget.initialScene) {
      case 'emotion_container':
        return '4. 稳定与是否继续';
      case 'process_action':
      case 'process_simulation_check':
      case 'same_reality_interpretations':
      case 'loss_resource_retention':
      case 'todo_goal_bridge':
        return '4. 行动证据';
      case 'failure_immunity':
      case 'controlled_failure_challenge':
      case 'psychological_immunity_experiment':
        return '4. 恢复与心理抗体';
      case 'gratitude_savoring':
      case 'complete_reality':
      case 'appreciation_scan':
      case 'gratitude_time_in':
      case 'daily_review':
        return '4. 感恩、品味与明日线索';
      case 'prime_design':
      case 'anti_prime_cleanup':
      case 'priming_diagnostic':
      case 'identity_script_activation':
        return '4. 环境线索';
      default:
        return '4. 复盘与身份';
    }
  }

  String _closureGuideTitle() {
    switch (widget.initialScene) {
      case 'emotion_container':
        return '先稳定，不强行积极';
      case 'process_action':
      case 'process_simulation_check':
      case 'same_reality_interpretations':
      case 'loss_resource_retention':
      case 'todo_goal_bridge':
        return '用行动证据收尾';
      case 'failure_immunity':
      case 'controlled_failure_challenge':
      case 'psychological_immunity_experiment':
        return '失败复盘不是自我审判';
      case 'gratitude_savoring':
      case 'complete_reality':
      case 'appreciation_scan':
      case 'gratitude_time_in':
      case 'daily_review':
        return '把好的东西留久一点';
      case 'prime_design':
      case 'anti_prime_cleanup':
      case 'priming_diagnostic':
      case 'identity_script_activation':
        return '让环境帮助你回到价值和行动';
      default:
        return RotCoreValueCopy.stageTitle(3);
    }
  }

  String _closureGuideBody() {
    switch (widget.initialScene) {
      case 'emotion_container':
        return '如果强度还高，只记录稳定动作和现实支持；是否继续重构由状态决定。';
      case 'process_action':
      case 'process_simulation_check':
      case 'same_reality_interpretations':
      case 'loss_resource_retention':
      case 'todo_goal_bridge':
        return '只判断：这个 5 分钟动作是否完成？如果没完成，卡点是什么，下一步如何再缩小？';
      case 'failure_immunity':
      case 'controlled_failure_challenge':
      case 'psychological_immunity_experiment':
        return '记录预测、实际、恢复和承受住的部分，把失败变成心理抗体。';
      case 'gratitude_savoring':
      case 'complete_reality':
      case 'appreciation_scan':
      case 'gratitude_time_in':
      case 'daily_review':
        return '具体感恩、30 秒品味和明日注意力启动线索 用来补全现实，不是否认痛苦。';
      case 'prime_design':
      case 'anti_prime_cleanup':
      case 'priming_diagnostic':
      case 'identity_script_activation':
        return '只选择一个最小环境动作，不要求一次性改变全部环境。';
      default:
        return RotCoreValueCopy.stageBody(3);
    }
  }

  bool get _showGratitudeField => <String>{'event_reframe', 'gratitude_savoring', 'complete_reality', 'appreciation_scan', 'gratitude_time_in', 'daily_review', 'core_business_session'}.contains(widget.initialScene);
  bool get _showPrimeField => <String>{'event_reframe', 'prime_design', 'anti_prime_cleanup', 'priming_diagnostic', 'identity_script_activation', 'daily_review', 'todo_goal_bridge', 'core_business_session'}.contains(widget.initialScene);
  bool get _showIdentityField => widget.initialScene != 'emotion_container' && widget.initialScene != 'prime_design' && widget.initialScene != 'anti_prime_cleanup' && widget.initialScene != 'priming_diagnostic';
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
      _primeCtrl.text = '今日注意力启动线索：先做一个行动证据，不等状态完美。';
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
    return '问题放大视角 会把现实收缩成：“$story”。它通常会放大永久化、普遍化、人格化或灾难化，让人更无力，也更难行动。';
  }

  String _benefitLens() {
    final action = _actionCtrl.text.trim().isEmpty ? _actionExamples[_entryScene]! : _actionCtrl.text.trim();
    return '资源发现视角 不说坏事是好事，而是在承认痛苦之后问：这件事里还有什么事实、资源、学习、关系或可控点？今天先用这个小动作保留主动性：$action';
  }


  void _restoreSession(RealisticOptimismTrainingSession session) {
    _sessionId = session.id;
    _sessionCreatedAtMs = session.createdAtMs;
    _step = session.currentStep.clamp(0, 3).toInt();
    _entryScene = session.entryScene.isEmpty ? _sceneLabel(session.initialScene) : session.entryScene;
    _emotion = session.emotion.isEmpty ? '自责' : session.emotion;
    _body = session.bodySignal.isEmpty ? '胸口紧' : session.bodySignal;
    _intensity = session.intensity;
    _completedAction = session.actionCompleted;
    _eventCtrl.text = session.eventText;
    _factCtrl.text = session.factText;
    _unknownCtrl.text = session.unknownText;
    _interpretationCtrl.text = session.interpretationText;
    _controllableCtrl.text = session.controllableText;
    _actionCtrl.text = session.actionText;
    _obstacleCtrl.text = session.obstacleText;
    _ifThenCtrl.text = session.ifThenText;
    _evidenceCtrl.text = session.evidenceText;
    _gratitudeCtrl.text = session.gratitudeText;
    _primeCtrl.text = session.primeText;
    _identityCtrl.text = session.identityText;
  }

  RealisticOptimismTrainingSession _toSession({String status = 'active', int? currentStep, String linkedRecordId = ''}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final created = _sessionCreatedAtMs == 0 ? now : _sessionCreatedAtMs;
    final id = _sessionId.isEmpty ? 'rot_session_${now}_${widget.initialScene.hashCode.abs()}' : _sessionId;
    _sessionId = id;
    _sessionCreatedAtMs = created;
    return RealisticOptimismTrainingSession(
      id: id,
      status: status,
      currentStep: currentStep ?? _step,
      initialScene: widget.initialScene,
      entryScene: _entryScene,
      level: _level,
      intensity: _intensity,
      emotion: _emotion,
      bodySignal: _body,
      eventText: _eventCtrl.text.trim(),
      factText: _factCtrl.text.trim(),
      unknownText: _unknownCtrl.text.trim(),
      interpretationText: _interpretationCtrl.text.trim(),
      controllableText: _controllableCtrl.text.trim(),
      actionText: _actionCtrl.text.trim(),
      obstacleText: _obstacleCtrl.text.trim(),
      ifThenText: _ifThenCtrl.text.trim(),
      actionCompleted: _completedAction,
      evidenceText: _evidenceCtrl.text.trim(),
      gratitudeText: _gratitudeCtrl.text.trim(),
      primeText: _primeCtrl.text.trim(),
      identityText: _identityCtrl.text.trim(),
      linkedRecordId: linkedRecordId,
      createdAtMs: created,
      updatedAtMs: now,
    );
  }

  Future<void> _saveDraft({String status = 'active', int? currentStep, bool silent = true}) async {
    try {
      await _dao.ensureTables();
      final session = _toSession(status: _safetyMode ? 'safety_routed' : status, currentStep: currentStep);
      await _dao.upsertSession(session);
      if (!silent) _toast('已保存训练草稿，可在首页继续。');
    } catch (e) {
      if (!silent) _toast('保存草稿失败：$e');
    }
  }


  List<String> _splitLines(String text) => text
      .split(RegExp(r'[\n；;。]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  Map<String, dynamic> _buildDeterministicPayload({required String provider, required String modelLabel}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final eventText = _eventCtrl.text.trim();
    final factLines = _splitLines(_factCtrl.text.trim());
    final unknownLines = _splitLines(_unknownCtrl.text.trim());
    final actionText = _actionCtrl.text.trim();
    final evidenceText = _evidenceCtrl.text.trim();
    final gratitudeText = _gratitudeCtrl.text.trim();
    final primeText = _primeCtrl.text.trim();
    final identityText = _identityCtrl.text.trim();
    final sourceAnchor = _completedAction ? 'ROT_EXPLAIN_SAME_REALITY + ROT_GRATITUDE_FULL_REALITY' : 'ROT_ACTION_EFFICACY_IMMUNITY + ROT_ATTENTION_PRIMING';
    return <String, dynamic>{
      'module': 'realistic_optimism_training',
      'scene': widget.initialScene,
      'id': 'rot_${now}_${eventText.hashCode.abs()}',
      'raw_input': _buildTrainingInput(),
      'user_event_summary': eventText,
      'core_value_reference': <String, dynamic>{
        'source_anchor': sourceAnchor,
        'how_it_applies': _completedAction
            ? '本次会话把事件从事实/解释分离推进到小行动、感恩、注意力启动线索 与身份沉淀。'
            : '本次会话把未完成转为失败免疫材料：看见卡点、缩小行动、保留重新开始的线索。',
      },
      'intensity_check': <String, dynamic>{
        'level': _level,
        'reason': '用户在会话中记录强度为 ${_intensity.round()}/10，情绪为 $_emotion，身体感受为 $_body。',
        'allowed_intervention': _safetyMode ? <String>['情绪稳定', '现实支持', '安全行动'] : <String>['情绪允许', '事实解释分离', '行动预演', '复盘沉淀'],
        'blocked_intervention': _safetyMode ? <String>['强行积极', '强行感恩', '失败挑战'] : <String>['空泛鸡汤', '否认痛苦'],
      },
      'emotion_validation': <String, dynamic>{
        'primary_emotion': _emotion,
        'validation_text': '你现在的$_emotion和$_body是可以理解的；这不是人格失败，而是这件事真的触动了你。我们先允许情绪，再看事实、解释和可控点。',
      },
      'fact_layer': <String, dynamic>{
        'objective_facts': factLines.isEmpty ? <String>[eventText] : factLines,
        'unknowns_or_assumptions': unknownLines.isEmpty ? <String>['别人的全部想法、未来会怎样、这件事是否代表我整个人。'] : unknownLines,
      },
      'interpretation_style': <String, dynamic>{
        'automatic_interpretation': _interpretationCtrl.text.trim(),
        'permanence_score': _interpretationCtrl.text.contains('永远') || _interpretationCtrl.text.contains('一直') ? 8 : 4,
        'pervasiveness_score': _interpretationCtrl.text.contains('都') || _interpretationCtrl.text.contains('什么') ? 7 : 4,
        'personalization_score': _interpretationCtrl.text.contains('我不行') || _interpretationCtrl.text.contains('废') || _interpretationCtrl.text.contains('很差') ? 8 : 5,
        'catastrophizing_score': _interpretationCtrl.text.contains('完了') || _interpretationCtrl.text.contains('肯定') ? 8 : 4,
        'helplessness_score': _interpretationCtrl.text.contains('没办法') || _interpretationCtrl.text.contains('无法') ? 8 : 4,
        'filtering_score': 6,
        'main_pattern': '会话内识别：永久化/普遍化/人格化/灾难化/无力化/过滤化的组合需要被检查。',
      },
      'fault_finder_layer': <String, dynamic>{
        'fault_finder_story': _faultLens(),
        'likely_emotional_effect': '更容易陷入$_emotion、自责、逃避或无力。',
        'likely_behavioral_effect': '更容易拖延、放弃复盘，或用自我攻击替代行动调整。',
      },
      'benefit_finder_layer': <String, dynamic>{
        'balanced_interpretation': _benefitLens(),
        'not_denied_pain': '痛苦没有被否认：情绪=$_emotion，强度=${_intensity.round()}/10，身体感受=$_body。',
        'possible_learning': <String>['识别自动解释和事实之间的差距。', '把行动缩小到今天可开始。', '把完成或未完成都转为证据。'],
        'remaining_resources': <String>['你已经把问题写出来。', '你仍然能选择一个可控点。', '你可以用注意力启动线索 支持明天继续。'],
        'possible_meaning': <String>['这次会话训练的是：痛苦存在时，仍然保留解释权和行动权。'],
      },
      'agency_layer': <String, dynamic>{
        'uncontrollable_parts': <String>['过去已经发生的部分。', '他人的全部想法。', '短期内无法保证的结果。'],
        'influenceable_parts': <String>['行动门槛', '环境线索', '复盘方式', '明天的启动方式'],
        'controllable_actions': <String>[if (_controllableCtrl.text.trim().isNotEmpty) _controllableCtrl.text.trim(), if (actionText.isNotEmpty) actionText],
      },
      'process_action_plan': <String, dynamic>{
        'five_minute_action': actionText,
        'next_three_steps': <String>[actionText, '完成后写一句证据。', '明天用注意力启动线索 重新启动。'],
        'if_then_plan': _splitLines(_ifThenCtrl.text.trim()).isEmpty ? <String>['如果想逃避，就把行动缩小到 2 分钟。'] : _splitLines(_ifThenCtrl.text.trim()),
      },
      'failure_immunity': <String, dynamic>{
        'predicted_pain': _intensity,
        'actual_pain': _completedAction ? null : _intensity,
        'predicted_recovery': '行动前担心自己会继续卡住。',
        'actual_recovery': _completedAction ? '完成一个小行动后，恢复一点主动感。' : '通过复盘把行动缩小，保留重新开始的入口。',
        'worst_case_prediction': _obstacleCtrl.text.trim(),
        'actual_result': _completedAction ? '完成或准备立刻完成 5 分钟行动。' : '本次未完成，但已记录卡点并进入失败免疫。',
        'psychological_antibody': _completedAction ? '行动证据比口号更可靠。' : (evidenceText.isEmpty ? '没完成不是人格失败，而是流程需要继续缩小。' : evidenceText),
      },
      'gratitude_or_savoring': <String, dynamic>{
        'what_still_matters': gratitudeText.isEmpty ? <String>['我仍然可以从一个小动作重新开始。'] : <String>[gratitudeText],
        'savoring_prompt': '停留 30 秒，看见这件仍值得珍惜的具体事实：${gratitudeText.isEmpty ? '我还可以重新开始' : gratitudeText}',
        'small_appreciation_action': '把这件具体事实写下来或向相关的人表达一句感谢。',
      },
      'prime': <String, dynamic>{
        'daily_value_word': '行动证据',
        'lock_screen_sentence': primeText.isEmpty ? '先做一个小行动证据，不等状态完美。' : primeText,
        'benefit_finder_question': '这件事里，我还剩下哪一个可控点？',
        'anti_prime_cleanup_action': _obstacleCtrl.text.trim().isEmpty ? '移除一个最强干扰入口。' : _obstacleCtrl.text.trim(),
      },
      'identity_evidence': <String, dynamic>{
        'specific_action': actionText,
        'proved_capacity': evidenceText.isEmpty ? '我愿意把问题推进到一个小行动。' : evidenceText,
        'identity_type': _completedAction ? '行动证据积累者' : '失败后恢复者',
        'identity_sentence': identityText.isEmpty ? '我正在成为一个承认现实、允许情绪，并用行动证据重新开始的人。' : identityText,
      },
      'final_user_message': _completedAction ? '本次训练完成：你用一个真实问题完成了现实、解释、行动、复盘和身份沉淀。' : '本次训练完成：未完成也不是终点，它已经成为失败免疫和下一步缩小行动的材料。',
      'provider': provider,
      'model_label': modelLabel,
      'created_at_ms': now,
      'updated_at_ms': now,
    };
  }


  Map<String, dynamic> _buildSafetyPayload({required String provider, required String modelLabel}) {
    final payload = _buildDeterministicPayload(provider: provider, modelLabel: modelLabel);
    payload['benefit_finder_layer'] = <String, dynamic>{
      'balanced_interpretation': '当前不适合做积极重构或意义寻找。先把安全、稳定和现实支持放在第一位。',
      'not_denied_pain': '痛苦没有被否认：当前强度为 ${_intensity.round()}/10，系统识别为 $_level。',
      'possible_learning': <String>[],
      'remaining_resources': <String>['可以先联系现实中的可信任的人。', '可以先远离危险物品或高风险场景。', '可以先做呼吸、坐下、喝水等稳定动作。'],
      'possible_meaning': <String>[],
    };
    payload['process_action_plan'] = <String, dynamic>{
      'five_minute_action': _level == 'L4' ? '现在先让自己不要独处，并联系当地紧急服务、危机热线或可信任的人。' : '先做 2 分钟稳定动作：坐下、喝水、慢慢呼吸，并给一个可信任的人发消息。',
      'next_three_steps': _level == 'L4'
          ? <String>['不要独处。', '联系当地紧急服务/危机热线/可信任的人。', '远离可能用于伤害自己的物品或场景。']
          : <String>['坐下并把双脚放在地面。', '喝水或慢呼吸 2 分钟。', '联系一个现实支持者。'],
      'if_then_plan': <String>['如果冲动继续升高，就立刻联系现实支持或当地紧急服务，而不是继续做普通训练。'],
    };
    payload['failure_immunity'] = <String, dynamic>{
      'predicted_pain': null,
      'actual_pain': null,
      'predicted_recovery': '',
      'actual_recovery': '',
      'worst_case_prediction': '',
      'actual_result': '',
      'psychological_antibody': '',
    };
    payload['gratitude_or_savoring'] = <String, dynamic>{
      'what_still_matters': <String>[],
      'savoring_prompt': '',
      'small_appreciation_action': '',
    };
    payload['prime'] = <String, dynamic>{
      'daily_value_word': '安全',
      'lock_screen_sentence': '',
      'benefit_finder_question': '',
      'anti_prime_cleanup_action': '先远离会加剧冲动、绝望或失控感的环境线索。',
    };
    payload['identity_evidence'] = <String, dynamic>{
      'specific_action': '',
      'proved_capacity': '',
      'identity_type': '',
      'identity_sentence': '',
    };
    payload['final_user_message'] = _level == 'L4'
        ? '现在最重要的不是完成训练，而是保证安全。请立刻联系当地紧急服务、危机热线或身边可信任的人，并尽量不要独处。'
        : '现在先不要求自己积极，也不寻找意义。请先稳定身体、联系现实支持，等强度下降后再决定是否继续训练。';
    return payload;
  }

  bool _isEmptyValue(Object? value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Iterable) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return false;
  }

  void _mergeMissing(Map<String, dynamic> target, Map<String, dynamic> fallback) {
    for (final entry in fallback.entries) {
      final existing = target[entry.key];
      final incoming = entry.value;
      if (existing is Map && incoming is Map) {
        final merged = Map<String, dynamic>.from(existing);
        _mergeMissing(merged, Map<String, dynamic>.from(incoming));
        target[entry.key] = merged;
      } else if (_isEmptyValue(existing)) {
        target[entry.key] = incoming;
      }
    }
  }

  Map<String, dynamic> _asMap(Object? raw) => raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  void _overrideMap(Map<String, dynamic> target, String key, Map<String, dynamic> values) {
    final base = _asMap(target[key]);
    for (final entry in values.entries) {
      if (!_isEmptyValue(entry.value)) base[entry.key] = entry.value;
    }
    target[key] = base;
  }

  Map<String, dynamic> _mergeAiWithSessionPayload(Map<String, dynamic> aiPayload, Map<String, dynamic> deterministicPayload) {
    final merged = Map<String, dynamic>.from(aiPayload);
    _mergeMissing(merged, deterministicPayload);
    merged['id'] = deterministicPayload['id'];
    merged['scene'] = widget.initialScene;
    merged['raw_input'] = deterministicPayload['raw_input'];
    merged['user_event_summary'] = deterministicPayload['user_event_summary'];
    merged['provider'] = aiPayload['provider'] ?? deterministicPayload['provider'];
    merged['model_label'] = aiPayload['model_label'] ?? deterministicPayload['model_label'];
    merged['created_at_ms'] = deterministicPayload['created_at_ms'];
    merged['updated_at_ms'] = deterministicPayload['updated_at_ms'];

    _overrideMap(merged, 'intensity_check', _asMap(deterministicPayload['intensity_check']));
    _overrideMap(merged, 'emotion_validation', _asMap(deterministicPayload['emotion_validation']));
    _overrideMap(merged, 'fact_layer', _asMap(deterministicPayload['fact_layer']));
    final deterministicStyle = _asMap(deterministicPayload['interpretation_style']);
    final style = _asMap(merged['interpretation_style']);
    final automatic = (deterministicStyle['automatic_interpretation'] ?? '').toString().trim();
    if (automatic.isNotEmpty) style['automatic_interpretation'] = automatic;
    for (final key in <String>['permanence_score', 'pervasiveness_score', 'personalization_score', 'catastrophizing_score', 'helplessness_score', 'filtering_score', 'main_pattern']) {
      if (_isEmptyValue(style[key]) && !_isEmptyValue(deterministicStyle[key])) style[key] = deterministicStyle[key];
    }
    merged['interpretation_style'] = style;
    _overrideMap(merged, 'agency_layer', _asMap(deterministicPayload['agency_layer']));
    _overrideMap(merged, 'process_action_plan', _asMap(deterministicPayload['process_action_plan']));
    if (_identityCtrl.text.trim().isNotEmpty) {
      final identity = _asMap(merged['identity_evidence']);
      identity['identity_sentence'] = _identityCtrl.text.trim();
      merged['identity_evidence'] = identity;
    }
    return merged;
  }

  Future<void> _finish() async {
    if (_eventCtrl.text.trim().isEmpty) {
      _toast('先写一句今天发生了什么，或你现在卡在哪里。');
      setState(() => _step = 0);
      return;
    }
    if (_safetyMode) {
      setState(() => _busy = true);
      try {
        await _dao.ensureTables();
        final payload = _buildSafetyPayload(provider: 'local', modelLabel: '安全分流');
        final record = RealisticOptimismTrainingRecord.fromJson(payload);
        await _dao.upsertRecord(record);
        final session = _toSession(status: 'safety_routed', currentStep: 0, linkedRecordId: record.id);
        await _dao.upsertSession(session);
        if (!mounted) return;
        _toast('当前是 $_level：已进入安全支持结果页，不强行进入普通积极重构。');
        Navigator.pop(context, record);
      } catch (e) {
        _toast('保存安全分流失败：$e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await _dao.ensureTables();
      final result = await _ai.generate(userInput: _buildTrainingInput(), scene: widget.initialScene, extraContext: widget.extraContext);
      final aiRecord = result.record;
      final deterministicPayload = _buildDeterministicPayload(provider: aiRecord.provider, modelLabel: aiRecord.modelLabel);
      final mergedPayload = _mergeAiWithSessionPayload(aiRecord.payload, deterministicPayload);
      final record = RealisticOptimismTrainingRecord.fromJson(mergedPayload);
      await _dao.upsertRecord(record);
      final completedSession = _toSession(status: 'completed', currentStep: 3, linkedRecordId: record.id);
      await _dao.upsertSession(completedSession);
      await _dao.completeSession(sessionId: completedSession.id, recordId: record.id);
      await _dao.upsertDeterministicArtifactsFromSession(session: completedSession, recordId: record.id);
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
【最终方案一致性业务流：围绕中心思想、核心价值体系与确定性沉淀】
本模块只围绕最终方案中的核心链路，不新增额外理论：
不否认现实；允许情绪；区分事实和解释；不让痛苦垄断解释权；用 5 分钟行动创造证据；失败用于心理免疫；用注意力启动线索 设计注意力；用感恩保持完整现实感；用身份句沉淀证据。

一、现实与情绪
当前 AI scene：${widget.initialScene}
入口类型：$_entryScene
场景重点：${_sceneFocusInstruction(widget.initialScene)}
强度分级：$_level
事件：${_eventCtrl.text.trim()}
情绪：$_emotion，强度 ${_intensity.round()}/10，身体感受：$_body

二、事实与解释
事实层：${_factCtrl.text.trim()}
未知/假设：${_unknownCtrl.text.trim()}
自动解释：${_interpretationCtrl.text.trim()}
问题放大视角 预览：${_faultLens()}
资源发现视角 预览：${_benefitLens()}

三、行动与预演
可控点：${_controllableCtrl.text.trim()}
5 分钟行动：${_actionCtrl.text.trim()}
障碍预演：${_obstacleCtrl.text.trim()}
如果-那么：${_ifThenCtrl.text.trim()}

四、复盘与沉淀
行动是否完成：${_completedAction ? '已完成/准备完成' : '暂未完成'}
行动证据：${_evidenceCtrl.text.trim()}
今天仍值得珍惜：${_gratitudeCtrl.text.trim()}
今日注意力启动线索：${_primeCtrl.text.trim()}
身份句：${_identityCtrl.text.trim()}

输出必须符合最终方案，但要围绕入口类型“$_entryScene”突出本场景重点：情绪容器只重点稳定情绪；过程行动只重点过程路径；失败复盘只重点心理免疫；事件重构才展示完整重构闭环。不要把所有内部工具平铺成同等重要结果。语言必须简单、可执行、非鸡汤。
''';

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final steps = _steps();
    return Scaffold(
      appBar: AppBar(
        title: const Text('解决今天一个实际问题'),
        actions: <Widget>[
          IconButton(
            tooltip: '保存草稿',
            onPressed: () => _saveDraft(status: 'active', silent: false),
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: Column(children: <Widget>[
        _CoreFlowHeader(step: _step, level: _level),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: RotCoreValueGuideCard(
            title: '这套训练帮你做什么？',
            body: '把一个让你失败、拖延、自责、焦虑或关系不舒服的事件，转成一个更清楚的事实判断、一个不鸡汤的解释、一个 5 分钟行动，以及一条行动或恢复证据。',
            icon: Icons.explore_outlined,
          ),
        ),
        Expanded(
          child: Stepper(
            currentStep: _step,
            type: StepperType.vertical,
            onStepTapped: (i) async {
              setState(() => _step = i);
              await _saveDraft(currentStep: i);
            },
            controlsBuilder: (context, details) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(children: <Widget>[
                if (_step > 0) TextButton(onPressed: () async { setState(() => _step--); await _saveDraft(currentStep: _step); }, child: const Text('上一步')),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _busy ? null : () async {
                    if (_step == steps.length - 1) {
                      await _finish();
                    } else if (_step == 0 && _safetyMode) {
                      await _saveDraft(status: 'safety_routed', currentStep: 0);
                      _toast('当前为 $_level，先做稳定与现实支持，不进入普通重构。');
                    } else {
                      setState(() => _step++);
                      await _saveDraft(currentStep: _step);
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
            _TextBox(controller: _eventCtrl, label: '今天这一件事', hint: '例如：今天我又没有推进重要任务，越拖越自责。', minLines: 3, onChanged: (_) => setState(() {})),
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
            _TextBox(controller: _factCtrl, label: '事实层', hint: '例如：今天我没有打开材料；任务还没有开始；现在已经晚上了。', minLines: 2),
            _TextBox(controller: _unknownCtrl, label: '未知 / 假设', hint: '例如：我不知道明天是否一定失败，也不知道别人是否真的否定我。', minLines: 2),
            _TextBox(controller: _interpretationCtrl, label: '脑中自动解释', hint: '例如：我永远坚持不了，我就是没有自控力。', minLines: 2, onChanged: (_) => setState(() {})),
            _PreviewCard(title: '问题放大视角 镜头', text: _faultLens(), icon: Icons.search_off_outlined),
            _PreviewCard(title: '资源发现视角 镜头', text: _benefitLens(), icon: Icons.auto_awesome_outlined),
          ]),
        ),
        Step(
          title: const Text('3. 行动与预演'),
          isActive: _step >= 2,
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.stageTitle(2), body: RotCoreValueCopy.stageBody(2), icon: Icons.directions_run_outlined),
            _PrincipleBox(title: '行动建立自我效能', text: '真正的乐观不是口号，而是今天仍然能做一个小动作。动作越小，越容易形成证据。'),
            _TextBox(controller: _controllableCtrl, label: '现在可控的一点', hint: '例如：我现在能控制的是把任务缩小到只打开文件 5 分钟。', minLines: 2),
            _TextBox(controller: _actionCtrl, label: '5 分钟行动', hint: '例如：打开文件，读第一段，写下一个标题，5 分钟就停止。', minLines: 2, onChanged: (_) => setState(() {})),
            _TextBox(controller: _obstacleCtrl, label: '障碍预演', hint: '例如：我可能刷手机、害怕做不好、等状态变好才开始。', minLines: 2),
            _TextBox(controller: _ifThenCtrl, label: '如果-那么', hint: '例如：如果我又想逃避，就只做 2 分钟，并把手机放到远处。', minLines: 2),
          ]),
        ),
        Step(
          title: Text(_closureStepTitle()),
          isActive: _step >= 3,
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            RotCoreValueGuideCard(title: _closureGuideTitle(), body: _closureGuideBody(), icon: Icons.badge_outlined),
            _PrincipleBox(title: '完成或没完成，都能进入下一步', text: _closureGuideBody()),
            SwitchListTile(
              value: _completedAction,
              onChanged: (v) => setState(() => _completedAction = v),
              title: const Text('我完成了 / 准备立刻完成这个 5 分钟行动'),
              subtitle: Text(_actionCtrl.text.trim().isEmpty ? '先完成一个小动作。' : _actionCtrl.text.trim()),
            ),
            _TextBox(controller: _evidenceCtrl, label: _completedAction ? '行动证据' : '没完成时的卡点', hint: _completedAction ? '例如：我完成了 5 分钟行动，证明我不必等状态完美也能开始。' : '例如：我卡在目标太大，下一步缩小到只打开文件 2 分钟。', minLines: 2),
            if (_showGratitudeField) _TextBox(controller: _gratitudeCtrl, label: '今天仍值得珍惜的一点', hint: '例如：虽然今天拖延了，但我仍然愿意把问题写出来。', minLines: 2),
            if (_showPrimeField) _TextBox(controller: _primeCtrl, label: '明天提醒自己的 注意力启动线索', hint: '例如：先打开文件 2 分钟，不等状态完美。', minLines: 2),
            if (_showIdentityField) _TextBox(controller: _identityCtrl, label: '身份沉淀', hint: '例如：我正在成为一个能在拖延后重新开始的人。', minLines: 2),
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
            const Expanded(child: Text('一个问题，走完 4 步', style: TextStyle(fontWeight: FontWeight.w900))),
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
