import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pages/ai_prompt_settings_page.dart';
import 'new_tablets_ai_service.dart';
import 'new_tablets_dao.dart';
import 'new_tablets_prompt_config.dart';

class NewTabletsHomePage extends StatefulWidget {
  const NewTabletsHomePage({super.key});

  @override
  State<NewTabletsHomePage> createState() => _NewTabletsHomePageState();
}

class _NewTabletsHomePageState extends State<NewTabletsHomePage> {
  int _tab = 0;
  final _input = TextEditingController(text: '我今天又想偷懒，不想学习，但我又觉得自己很废物。');
  final NewTabletsDao _dao = NewTabletsDao();
  final NewTabletsAiService _aiService = NewTabletsAiService();
  late NewTabletsAnalysis _analysis = NewTabletsEngine.analyze(_input.text);
  bool _loadingState = true;
  bool _aiLoading = false;
  String _aiCoachText = '';

  List<OldTablet> _oldTablets = [
    OldTablet('必须被别人认可', '学校/社会', '焦虑、讨好、比较', '削弱生命，需打碎'),
    OldTablet('不能失败', '成长环境', '拖延与完美主义', '需要降级为实验'),
    OldTablet('稳定高于一切', '家庭旧榜', '不敢冒险', '部分保留为工具'),
  ];
  List<NewTablet> _newTablets = [
    NewTablet('我重视可靠胜过情绪', '每天兑现一个小承诺', '稳定'),
    NewTablet('我重视创造胜过消费', '每天输出 200 字', '建立中'),
    NewTablet('我重视独立判断', '每天写一个自己的判断', '待强化'),
  ];
  List<SovereignCommitment> _commitments = [
    SovereignCommitment('每天学习 45 分钟', '7 天小许诺', 0.85, 1),
    SovereignCommitment('每天训练 15 分钟', '30 天中许诺', 0.70, 3),
    SovereignCommitment('每周输出一篇文章', '90 天大许诺', 0.60, 2),
  ];
  List<BadConscienceRewrite> _rewrites = [
    BadConscienceRewrite('我真废物', '我今天没有履约，需要修复承诺结构。'),
    BadConscienceRewrite('我不配休息', '我需要判断这是恢复力量，还是逃避行动。'),
    BadConscienceRewrite('我永远做不到', '我需要把承诺缩小到可兑现。'),
  ];
  List<DailyCommandRecord> _dailyCommands = <DailyCommandRecord>[];
  List<CreativeOutputRecord> _creativeOutputs = <CreativeOutputRecord>[];
  List<NewTabletsPracticeRecord> _practiceRecords = <NewTabletsPracticeRecord>[];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final state = await _dao.loadState();
    if (!mounted) return;
    setState(() {
      if (state.oldTablets.isNotEmpty) _oldTablets = state.oldTablets;
      if (state.newTablets.isNotEmpty) _newTablets = state.newTablets;
      if (state.commitments.isNotEmpty) _commitments = state.commitments;
      if (state.rewrites.isNotEmpty) _rewrites = state.rewrites;
      _dailyCommands = state.dailyCommands;
      _creativeOutputs = state.creativeOutputs;
      _practiceRecords = state.practiceRecords;
      _loadingState = false;
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _runAnalysis() {
    setState(() => _analysis = NewTabletsEngine.analyze(_input.text));
  }


  Future<void> _runAiCoach() async {
    final input = _input.text.trim();
    if (input.isEmpty) {
      _toast('请先输入一个真实状态');
      return;
    }
    setState(() {
      _aiLoading = true;
      _analysis = NewTabletsEngine.analyze(input);
      _aiCoachText = '';
    });
    final snapshot = NewTabletsState(
      oldTablets: _oldTablets,
      newTablets: _newTablets,
      commitments: _commitments,
      rewrites: _rewrites,
      dailyCommands: _dailyCommands,
      creativeOutputs: _creativeOutputs,
      practiceRecords: _practiceRecords,
    );
    final text = await _aiService.generateCoachText(userInput: input, state: snapshot);
    if (!mounted) return;
    setState(() {
      _aiLoading = false;
      _aiCoachText = text.trim();
    });
    if (text.trim().isEmpty) _toast('当前 AI 未返回内容，已保留本地规则诊断');
  }

  Future<void> _saveTodayCommand() async {
    final record = DailyCommandRecord(
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ruler: _analysis.commanders.first.name,
      oldSelf: _analysis.oldSelf,
      command: _analysis.command,
      minAction: _analysis.action,
    );
    final next = [record, ..._dailyCommands].take(60).toList(growable: false);
    await _dao.saveDailyCommands(next);
    if (!mounted) return;
    setState(() => _dailyCommands = next);
    _toast('今日命令已写入自我超克记录');
  }

  Future<void> _addOldTablet() async {
    final result = await _askFields('新增旧榜', const ['旧榜', '来源', '影响', '状态/是否增强生命']);
    if (result == null) return;
    final item = OldTablet(result[0], result[1], result[2], result[3]);
    final next = [item, ..._oldTablets];
    await _dao.saveOldTablets(next);
    setState(() => _oldTablets = next);
  }

  Future<void> _addNewTablet() async {
    final result = await _askFields('新增新榜', const ['新的生命尺度', '行动证明 / 7天实验', '状态']);
    if (result == null) return;
    final item = NewTablet(result[0], result[1], result[2]);
    final next = [item, ..._newTablets];
    await _dao.saveNewTablets(next);
    setState(() => _newTablets = next);
  }

  Future<void> _addCommitment() async {
    final result = await _askFields('新增主权承诺', const ['承诺标题', '等级与周期，例如 7 天小许诺']);
    if (result == null) return;
    final item = SovereignCommitment(result[0], result[1], 0, 0);
    final next = [item, ..._commitments];
    await _dao.saveCommitments(next);
    setState(() => _commitments = next);
  }

  Future<void> _recordCommitment(int index, bool completed) async {
    final next = List<SovereignCommitment>.from(_commitments);
    next[index] = next[index].recordResult(completed: completed);
    await _dao.saveCommitments(next);
    setState(() => _commitments = next);
    _toast(completed ? '已记录兑现：主权可靠性上升' : '已进入修复：失败是调整承诺结构的材料');
  }

  Future<void> _addRewriteFromAnalysis() async {
    final bad = _input.text.trim().isEmpty ? '我真废物' : _input.text.trim();
    final item = BadConscienceRewrite(bad, _analysis.command);
    final next = [item, ..._rewrites].take(80).toList(growable: false);
    await _dao.saveRewrites(next);
    setState(() => _rewrites = next);
    _toast('已保存坏良心 → 主权责任改写');
  }

  Future<void> _addCreativeOutput() async {
    final result = await _askFields('记录创造输出', const ['类型：文章/笔记/项目/训练/决策', '标题', '连接的新榜']);
    if (result == null) return;
    final item = CreativeOutputRecord(createdAtMs: DateTime.now().millisecondsSinceEpoch, type: result[0], title: result[1], linkedNewTablet: result[2]);
    final next = [item, ..._creativeOutputs].take(100).toList(growable: false);
    await _dao.saveCreativeOutputs(next);
    setState(() => _creativeOutputs = next);
  }


  Future<void> _startPractice(_PracticeSpec spec) async {
    final result = await _askFields(spec.title, <String>['写下当前材料 / 困扰 / 目标']);
    if (result == null) return;
    final input = result.first;
    final analysis = NewTabletsEngine.analyze('${spec.sceneHint}\n$input');
    final record = NewTabletsPracticeRecord(
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      moduleId: spec.id,
      moduleName: spec.title,
      userInput: input,
      diagnosis: analysis.diagnosis,
      command: analysis.command,
      minAction: analysis.action,
      reviewQuestion: analysis.reviewQuestions.isEmpty ? spec.reviewQuestion : analysis.reviewQuestions.first,
    );
    final next = [record, ..._practiceRecords].take(120).toList(growable: false);
    await _dao.savePracticeRecords(next);
    if (!mounted) return;
    setState(() => _practiceRecords = next);
    _toast('已生成并保存「${spec.title}」训练卡');
  }

  Future<List<String>?> _askFields(String title, List<String> labels) async {
    final ctrls = labels.map((_) => TextEditingController()).toList(growable: false);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < labels.length; i++) Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(controller: ctrls[i], decoration: InputDecoration(labelText: labels[i], border: const OutlineInputBorder())),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrls.map((e) => e.text.trim()).toList(growable: false)), child: const Text('保存')),
        ],
      ),
    );
    for (final c in ctrls) { c.dispose(); }
    if (result == null || result.any((e) => e.isEmpty)) return null;
    return result;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_today(), _architecture(), _trainingWorkbench(), _flowGuides(), _tablets(), _commitment(), _badConscience(), _flowsAndMetrics(), _sourcebookAndReport(), _coach()];
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020),
        foregroundColor: Colors.white,
        title: const Text('新榜 New Tablets'),
        actions: [
          IconButton(
            tooltip: '配置新榜 AI 提示词',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiPromptSettingsPage(initialModuleId: NewTabletsPromptConfig.moduleId, initialPromptId: NewTabletsPromptConfig.globalId))),
            icon: const Icon(Icons.tune_outlined),
          ),
          const Padding(padding: EdgeInsets.only(right: 16), child: Icon(Icons.auto_awesome)),
        ],
      ),
      body: Column(
        children: [
          _hero(),
          if (_loadingState) const LinearProgressIndicator(minHeight: 2),
          _tabs(),
          Expanded(child: pages[_tab]),
        ],
      ),
    );
  }

  Widget _hero() => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF7C2D12)]),
          border: Border.all(color: Colors.white24),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('自我超克、价值重估与主权个体训练系统', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text('识别你正在服从谁，把坏良心转化为责任，把学习与纪律导向创造。', style: TextStyle(color: Color(0xFFE5E7EB), height: 1.45)),
        ]),
      );

  Widget _tabs() {
    const items = ['今日命令', '九模块总览', '训练工作台', '流程向导', '打碎与书写', '我能许诺', '罪感到责任', '流程指标', '源书报告', 'AI导师'];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) => ChoiceChip(
          label: Text(items[i]),
          selected: _tab == i,
          onSelected: (_) => setState(() => _tab = i),
          selectedColor: const Color(0xFFF97316),
          labelStyle: TextStyle(color: _tab == i ? Colors.white : const Color(0xFFE5E7EB), fontWeight: FontWeight.w700),
          backgroundColor: const Color(0xFF111827),
        ),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: items.length,
      ),
    );
  }

  Widget _today() => _scroll([
        _section('今日超克对象', '拖延的我 / 依赖认可的我 / 被坏良心攻击的我', Icons.flag_outlined),
        _section('今日主权命令', _analysis.command, Icons.gavel_outlined),
        _section('今日最小行动', _analysis.action, Icons.bolt_outlined),
        _matrix('当前命令者检测', _analysis.commanders.map((e) => [e.name, e.state]).toList()),
        _section('防坏良心提醒', '这不是惩罚。任务是恢复力量、兑现承诺、创造价值。', Icons.health_and_safety_outlined),
        _matrix('晚间复盘', const [['冲动', '哪个冲动被你命令了？'], ['力量', '行动让你更强还是更弱？'], ['扩展', '明天这个命令可扩展到哪里？']]),
        FilledButton.icon(onPressed: _saveTodayCommand, icon: const Icon(Icons.save_alt_outlined), label: const Text('保存今日命令')),
        if (_dailyCommands.isNotEmpty) ..._dailyCommands.take(5).toList().asMap().entries.map((entry) => _dailyCommandCard(entry.key, entry.value)),
      ]);


  Widget _architecture() => _scroll([
        _matrix('九大核心模块验收总览', const [
          ['我的新榜起点', '旧榜扫描 / 新榜草案 / 价值强度评分：先回答为什么改变，而不是直接打卡。'],
          ['谁在命令我？', '冲动拆解 / 命令语生成 / 内部服从设计：把“我想/不想”拆成命令权斗争。'],
          ['今日超克', '今日旧我 / 微型超克任务 / 权力感复盘：每天把旧我变成材料。'],
          ['我能许诺', '慢许诺 / 强度等级 / 违约修复 / 可靠性仪表盘：少许诺，说到做到。'],
          ['从罪感到责任', '坏良心识别 / 责任化改写 / 休息沉沦区分 / 自我惩罚拦截。'],
          ['我正在服从谁？', '外部命令扫描 / 群体语言识别 / 自主性重估 / 群体断连练习。'],
          ['打碎与书写', '旧榜谱系追问 / 新榜写作 / 新榜 7 天实验：持续更新价值系统。'],
          ['把过去变成材料', '过去事件重估 / “我愿如此”练习 / 反怨恨训练。'],
          ['为创造而学习', '学习目的重估 / 输入—消化—输出 / 败坏胃检测。'],
        ]),
        _matrix('八个价值支柱', const [
          ['生命肯定', '这件事是在增强我的生命，还是在削弱我的生命？'],
          ['权力意志', '我现在是在扩展力量，还是在缩小自己？'],
          ['自我超克', '我现在要超克的是哪个旧的自己？'],
          ['命令自己', '现在是谁在命令我？'],
          ['价值重估', '这个价值是我创造的，还是未经审查继承来的？'],
          ['主权责任', '我能不能成为一个说到做到的人？'],
          ['坏良心转化', '我是在自我塑造，还是在自我折磨？'],
          ['创造新榜', '我想让什么成为我生命的最高尺度？'],
        ]),
        _section('Prompt 配置已接入设置页', '本模块全部全局价值层、场景层、流程层、输出格式 Prompt 均注册到设置页 AI 提示词统一配置中心；点击右上角调节图标可自由修改，并在下一次 AI 生成时生效。', Icons.tune_outlined),
      ]);



  Future<void> _runFlowGuide(_FlowGuideSpec spec) async {
    final result = await _askFields(spec.title, spec.fields);
    if (result == null) return;
    final joined = result.asMap().entries.map((e) => '${spec.fields[e.key]}：${e.value}').join('\n');
    final analysis = NewTabletsEngine.analyze('${spec.sceneHint}\n$joined');
    final record = NewTabletsPracticeRecord(
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      moduleId: spec.id,
      moduleName: spec.title,
      userInput: joined,
      diagnosis: analysis.diagnosis,
      command: spec.commandBuilder(result, analysis),
      minAction: spec.actionBuilder(result, analysis),
      reviewQuestion: spec.reviewQuestion,
    );
    final next = [record, ..._practiceRecords].take(120).toList(growable: false);
    await _dao.savePracticeRecords(next);
    if (!mounted) return;
    setState(() => _practiceRecords = next);
    _toast('已生成「${spec.title}」流程卡');
  }

  List<List<String>> _metricRows() {
    final avgReliability = _commitments.isEmpty ? 0 : (_commitments.map((e) => e.rate).reduce((a, b) => a + b) / _commitments.length * 100).round();
    final repairCount = _commitments.fold<int>(0, (sum, e) => sum + e.repairs);
    final completedDaily = _dailyCommands.where((e) => e.completed).length;
    return <List<String>>[
      ['主权指数', '承诺 ${_commitments.length} 个｜平均兑现率 $avgReliability%｜修复 $repairCount 次'],
      ['价值清晰度', '旧榜 ${_oldTablets.length} 条｜新榜 ${_newTablets.length} 条｜训练 ${_practiceRecords.length} 次'],
      ['坏良心转化率', '责任化改写 ${_rewrites.length} 条｜失败后修复次数 $repairCount'],
      ['创造输出量', '创造输出 ${_creativeOutputs.length} 条'],
      ['自我超克记录', '今日命令 ${_dailyCommands.length} 条｜已完成 $completedDaily 条'],
    ];
  }

  Future<void> _markDailyCommand(int index, bool completed) async {
    final next = List<DailyCommandRecord>.from(_dailyCommands);
    next[index] = next[index].copyWith(completed: completed);
    await _dao.saveDailyCommands(next);
    if (!mounted) return;
    setState(() => _dailyCommands = next);
  }


  String _buildReportText() {
    final metrics = _metricRows().map((e) => '- ${e[0]}：${e[1]}').join('\n');
    final old = _oldTablets.map((e) => '- ${e.value}｜${e.source}｜${e.status}').join('\n');
    final newer = _newTablets.map((e) => '- ${e.value}｜${e.proof}｜${e.status}').join('\n');
    final commitments = _commitments.map((e) => '- ${e.title}｜${e.period}｜兑现率 ${(e.rate * 100).round()}%｜修复 ${e.repairs} 次').join('\n');
    final outputs = _creativeOutputs.take(10).map((e) => '- ${e.type}：${e.title}｜${e.linkedNewTablet}').join('\n');
    final practices = _practiceRecords.take(10).map((e) => '- ${e.moduleName}：${e.command}｜${e.minAction}').join('\n');
    return '''# 新榜 New Tablets 周度主权报告

## 指标
$metrics

## 正在打碎的旧榜
${old.isEmpty ? '- 暂无' : old}

## 正在书写的新榜
${newer.isEmpty ? '- 暂无' : newer}

## 主权承诺
${commitments.isEmpty ? '- 暂无' : commitments}

## 创造输出
${outputs.isEmpty ? '- 暂无' : outputs}

## 最近训练
${practices.isEmpty ? '- 暂无' : practices}

## 下周问题
- 哪个旧榜仍在命令我？
- 哪个新榜需要用行动证明？
- 哪个承诺需要缩小而不是羞辱自己？
''';
  }


  Future<void> _copyStateJson() async {
    final raw = await _dao.exportStateJson();
    await Clipboard.setData(ClipboardData(text: raw));
    _toast('已复制新榜完整数据 JSON');
  }

  Future<void> _importStateJsonFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = (data?.text ?? '').trim();
    if (raw.isEmpty) {
      _toast('剪贴板为空');
      return;
    }
    try {
      await _dao.importStateJson(raw);
      await _loadState();
      _toast('已从剪贴板导入新榜数据');
    } catch (e) {
      _toast('导入失败：$e');
    }
  }

  Future<void> _copyReport() async {
    await Clipboard.setData(ClipboardData(text: _buildReportText()));
    _toast('已复制新榜周度主权报告');
  }

  Widget _trainingWorkbench() => _scroll([
        _section('训练工作台', '这里把产品设计方案中的九大模块变成可执行训练入口。每次训练都会保存为记录，而不是只展示理念。', Icons.dashboard_customize_outlined),
        for (final spec in _practiceSpecs)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(spec.icon, color: const Color(0xFFF97316)), const SizedBox(width: 10), Expanded(child: Text(spec.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))]),
              const SizedBox(height: 6),
              Text(spec.description, style: const TextStyle(color: Color(0xFFE5E7EB), height: 1.45)),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: FilledButton.tonal(onPressed: () => _startPractice(spec), child: const Text('开始训练'))),
            ]),
          ),
        if (_practiceRecords.isNotEmpty) _matrix('最近训练记录', _practiceRecords.take(8).map((e) => [e.moduleName, '${e.command}｜${e.minAction}']).toList()),
      ]);


  Widget _flowGuides() => _scroll([
        _section('四条关键用户流程', '这里把首次使用、每日使用、失败修复、每周价值重估做成可执行向导。每次生成的流程卡都会进入训练记录。', Icons.route_outlined),
        for (final spec in _flowGuides)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(spec.icon, color: const Color(0xFFFBBF24)), const SizedBox(width: 10), Expanded(child: Text(spec.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))]),
              const SizedBox(height: 6),
              Text(spec.description, style: const TextStyle(color: Color(0xFFE5E7EB), height: 1.45)),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: FilledButton.tonal(onPressed: () => _runFlowGuide(spec), child: const Text('启动向导'))),
            ]),
          ),
      ]);

  Widget _tablets() => _scroll([
        _matrix('旧榜页：正在打碎的价值', _oldTablets.map((e) => [e.value, '${e.source}｜${e.impact}｜${e.status}']).toList()),
        _matrix('新榜页：新的生命尺度', _newTablets.map((e) => [e.value, '${e.proof}｜${e.status}']).toList()),
        _section('新榜写作格式', '我不再把 ____ 作为最高价值。\n我把 ____ 作为新的尺度。\n我愿意为此付出的代价是 ____。\n我将通过 ____ 行动来证明它。', Icons.edit_note),
        Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _addOldTablet, icon: const Icon(Icons.playlist_remove_outlined), label: const Text('新增旧榜'))), const SizedBox(width: 10), Expanded(child: FilledButton.icon(onPressed: _addNewTablet, icon: const Icon(Icons.note_add_outlined), label: const Text('新增新榜')))]),
        const SizedBox(height: 12),
        _matrix('7 天新榜实验', const [['创造胜过消费', '每天产出 200 字'], ['身体力量', '每天训练 15 分钟'], ['独立判断', '每天写一个判断'], ['可靠', '每天兑现一个小承诺']]),
      ]);

  Widget _commitment() => _scroll([
        _matrix('主权承诺页', _commitments.map((e) => [e.title, '${e.period}｜兑现率 ${(e.rate * 100).round()}%｜修复 ${e.repairs} 次']).toList()),
        _matrix('慢许诺检查', const [['来源', '来自新榜，还是来自焦虑/群体？'], ['代价', '你愿意承担它的代价吗？'], ['尺度', '是否说得太大，需要降级？'], ['等级', '试验 1-3 天 / 小许诺 7 天 / 中许诺 30 天 / 大许诺 90 天']]),
        FilledButton.icon(onPressed: _addCommitment, icon: const Icon(Icons.add_task_outlined), label: const Text('新增主权承诺')),
        const SizedBox(height: 12),
        for (var i = 0; i < _commitments.length && i < 3; i++) _commitmentActions(i),
        _section('违约修复', '失败不是自我羞辱的材料，而是提高可靠性的材料：判断承诺过大、环境失败、身体不足，还是低级冲动夺权。', Icons.build_circle_outlined),
      ]);

  Widget _badConscience() => _scroll([
        _matrix('坏良心转化页', _rewrites.map((e) => [e.bad, e.rewrite]).toList()),
        _matrix('休息与沉沦区分', const [['休息', '之后更有力量｜有边界｜主动安排｜恢复后行动'], ['沉沦', '之后更空虚｜没有边界｜被动滑落｜继续逃避']]),
        _section('自我惩罚拦截', '“我不配吃饭/休息、必须惩罚自己”不是主权命令，而是坏良心的自我折磨。现在要恢复可行动状态，并重设小承诺。', Icons.front_hand_outlined),
        FilledButton.icon(onPressed: _addRewriteFromAnalysis, icon: const Icon(Icons.transform_outlined), label: const Text('把当前输入保存为责任化改写')),
      ]);


  Widget _flowsAndMetrics() => _scroll([
        _matrix('首次使用流程', const [
          ['1', '完成旧榜扫描，生成“我的旧榜地图”。'],
          ['2', '完成新榜草案，写出新的生命原则。'],
          ['3', '选择一个 7 天自我超克实验。'],
          ['4', '生成第一张主权承诺卡。'],
        ]),
        _matrix('每日使用流程', const [
          ['入口问题', '今天你最可能被什么支配：懒惰 / 焦虑 / 群体比较 / 坏良心 / 旧习惯 / 恐惧 / 模糊目标。'],
          ['每日输出', '今日命令 / 今日超克对象 / 今日最小行动 / 防坏良心提醒 / 晚间复盘。'],
        ]),
        _matrix('失败后的主权修复', const [
          ['不做', '不断签羞辱，不说“你失败了”。'],
          ['要做', '判断承诺过大、环境失败、身体不足，还是低级冲动夺权。'],
          ['输出', '缩小任务 / 调整环境 / 加入恢复 / 明确下次命令语。'],
        ]),
        _matrix('每周价值重估', const [
          ['旧榜', '哪个旧榜还在支配你？'],
          ['新榜', '哪个新榜被行动证明了？'],
          ['承诺', '哪个承诺太大，需要缩小？'],
          ['过去', '哪次失败被你转化成材料？'],
          ['下周', '下周你要超克哪个旧我？'],
        ]),
        FilledButton.icon(onPressed: _addCreativeOutput, icon: const Icon(Icons.create_outlined), label: const Text('记录创造输出')),
        if (_creativeOutputs.isNotEmpty) _matrix('最近创造输出', _creativeOutputs.take(5).map((e) => [e.type, '${e.title}｜${e.linkedNewTablet}']).toList()),
        _matrix('核心指标仪表盘', _metricRows()),
      ]);


  Widget _sourcebookAndReport() => _scroll([
        _section('源书底盘', '本模块的 AI 与训练结构围绕五个文本线索：〈论自我超克〉、〈论旧榜与新榜〉、《善恶的彼岸》第19节、《善恶的彼岸》第199节、《道德的谱系》第二论文。', Icons.auto_stories_outlined),
        _matrix('思想 → 产品能力映射', const [
          ['自我超克', '今日超克对象、微型超克任务、行动后权力感复盘。'],
          ['旧榜与新榜', '旧榜扫描、新榜写作、价值强度评分、每周价值重估。'],
          ['第19节', '内在意志解析器：谁在命令我、命令语生成、内部服从设计。'],
          ['第199节', '群体本能雷达：外部命令扫描、群体语言识别、断连练习。'],
          ['道德谱系第二论文', '主权承诺、坏良心转化、违约修复、可靠性仪表盘。'],
        ]),
        _matrix('安全与误用边界', const [
          ['反自虐', '不把“变强”解释成惩罚自己、剥夺休息或极端压迫。'],
          ['反支配他人', '权力意志只用于自我组织、自我增强与创造形式，不用于羞辱或控制别人。'],
          ['反坏良心', '自责语言必须转化为责任修复，不把罪感当进步动力。'],
          ['专业边界', '若出现自伤、伤害他人或急性危机，应优先寻求当地紧急服务或专业支持。'],
        ]),
        _section('周度主权报告', '把旧榜、新榜、承诺、创造输出、训练记录和指标汇总为可复制报告，用于每周价值重估或导出给自己复盘。', Icons.summarize_outlined),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: _copyReport, icon: const Icon(Icons.copy_all_outlined), label: const Text('复制周报'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: _copyStateJson, icon: const Icon(Icons.ios_share_outlined), label: const Text('导出数据'))),
        ]),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: _importStateJsonFromClipboard, icon: const Icon(Icons.system_update_alt_outlined), label: const Text('从剪贴板导入完整新榜数据 JSON')),
        const SizedBox(height: 12),
        _section('报告预览', _buildReportText(), Icons.article_outlined),
      ]);

  Widget _coach() => _scroll([
        TextField(
          controller: _input,
          minLines: 3,
          maxLines: 6,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('输入你的状态：拖延、自责、价值迷茫、群体比较、后悔或学习无输出'),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _runAnalysis, icon: const Icon(Icons.offline_bolt_outlined), label: const Text('本地快速诊断'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.icon(onPressed: _aiLoading ? null : _runAiCoach, icon: _aiLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.psychology_alt_outlined), label: Text(_aiLoading ? 'AI生成中' : 'AI导师生成'))),
        ]),
        if (_aiCoachText.isNotEmpty) _section('AI导师完整回应', _aiCoachText, Icons.auto_awesome_outlined),
        _section('1. 当前状态诊断', _analysis.diagnosis, Icons.search),
        _section('2. 尼采式映射', _analysis.mapping, Icons.menu_book_outlined),
        _matrix('3. 谁在命令你？', _analysis.commanders.map((e) => [e.name, e.state]).toList()),
        _section('4. 需要打碎的旧榜 / 超克的旧我', _analysis.oldSelf, Icons.auto_fix_high),
        _section('5. 新榜或主权命令', _analysis.command, Icons.gavel),
        _section('6. 今日最小行动', _analysis.action, Icons.task_alt),
        _section('7. 防止坏良心提醒', _analysis.guardrail, Icons.shield_outlined),
        _matrix('8. 复盘问题', _analysis.reviewQuestions.map((e) => ['问题', e]).toList()),
        _section('Prompt 配置中心', '本模块不再把提示词锁死在页面内。全局价值层、12 个场景/流程层与 3 个输出格式 Prompt 已接入设置页 AI 提示词统一配置中心，可自由保存、恢复、导入和导出。', Icons.integration_instructions_outlined),
      ]);


  Widget _dailyCommandCard(int index, DailyCommandRecord record) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(record.completed ? '已完成' : '进行中', style: TextStyle(color: record.completed ? const Color(0xFF34D399) : const Color(0xFFFBBF24), fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(record.command, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(record.minAction, style: const TextStyle(color: Color(0xFFE5E7EB))),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => _markDailyCommand(index, false), child: const Text('修复')),
            FilledButton.tonal(onPressed: () => _markDailyCommand(index, true), child: const Text('完成')),
          ]),
        ]),
      );

  Widget _commitmentActions(int index) {
    final item = _commitments[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
      child: Row(children: [
        Expanded(child: Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
        IconButton(onPressed: () => _recordCommitment(index, true), icon: const Icon(Icons.check_circle_outline, color: Color(0xFF34D399)), tooltip: '兑现'),
        IconButton(onPressed: () => _recordCommitment(index, false), icon: const Icon(Icons.build_circle_outlined, color: Color(0xFFFBBF24)), tooltip: '未兑现，进入修复'),
      ]),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFF111827),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.white24)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.white24)),
      );

  Widget _scroll(List<Widget> children) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: children);

  Widget _section(String title, String body, IconData icon) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: const Color(0xFFF97316)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(color: Color(0xFFE5E7EB), height: 1.55)),
          ])),
        ]),
      );

  Widget _matrix(String title, List<List<String>> rows) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...rows.map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 112, child: Text(r.first, style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w800))),
                Expanded(child: Text(r.length > 1 ? r[1] : '', style: const TextStyle(color: Color(0xFFE5E7EB), height: 1.45))),
              ]))),
        ]),
      );
}



const List<_FlowGuideSpec> _flowGuides = <_FlowGuideSpec>[
  _FlowGuideSpec(
    id: 'flow_onboarding',
    title: '首次使用：旧榜地图 → 新榜草案 → 7天实验 → 主权承诺卡',
    description: '用于第一次进入模块时完成价值初始化，而不是直接打卡。',
    fields: ['我从小被灌输的应该', '我想写入新榜的价值', '我愿意做的7天实验'],
    sceneHint: '必须 认可 目标 承诺',
    reviewQuestion: '这个新榜是否值得我付代价？',
    icon: Icons.rocket_launch_outlined,
  ),
  _FlowGuideSpec(
    id: 'flow_daily',
    title: '每日使用：今天谁最可能支配我？',
    description: '生成今日命令、今日超克对象、最小行动和晚间复盘。',
    fields: ['今天最可能支配我的力量', '今天要超克的旧我', '可执行的最小行动'],
    sceneHint: '拖延 不想 恐惧 群体 坏良心',
    reviewQuestion: '今天哪个冲动被我命令了？',
    icon: Icons.today_outlined,
  ),
  _FlowGuideSpec(
    id: 'flow_repair',
    title: '失败后的修复：不羞辱，只修复承诺结构',
    description: '判断承诺过大、环境失败、身体不足或低级冲动夺权。',
    fields: ['未兑现的承诺', '可能原因', '明天缩小后的版本'],
    sceneHint: '废物 自责 承诺 失败',
    reviewQuestion: '我是在修复，还是在惩罚自己？',
    icon: Icons.build_circle_outlined,
  ),
  _FlowGuideSpec(
    id: 'flow_weekly',
    title: '每周价值重估：旧榜、新榜、承诺与失败材料',
    description: '每周检查哪个旧榜仍在支配、哪个新榜被行动证明。',
    fields: ['本周仍在支配我的旧榜', '本周被证明的新榜', '下周要超克的旧我'],
    sceneHint: '旧榜 新榜 承诺 过去',
    reviewQuestion: '下周我让什么成为更高尺度？',
    icon: Icons.calendar_month_outlined,
  ),
];

class _FlowGuideSpec {
  final String id;
  final String title;
  final String description;
  final List<String> fields;
  final String sceneHint;
  final String reviewQuestion;
  final IconData icon;
  const _FlowGuideSpec({required this.id, required this.title, required this.description, required this.fields, required this.sceneHint, required this.reviewQuestion, required this.icon});

  String commandBuilder(List<String> values, NewTabletsAnalysis analysis) => analysis.command;
  String actionBuilder(List<String> values, NewTabletsAnalysis analysis) => values.isEmpty ? analysis.action : values.last;
}

const List<_PracticeSpec> _practiceSpecs = <_PracticeSpec>[
  _PracticeSpec('start', '我的新榜起点', '旧榜扫描、新榜草案与价值强度评分。', '别人认可 必须 成功', '这个价值来自哪里？', Icons.flag_circle_outlined),
  _PracticeSpec('will', '谁在命令我？', '拆解内在冲动，把模糊愿望改写成主权命令。', '偷懒 拖延 不想 手机', '刚才是谁在命令你？', Icons.psychology_alt_outlined),
  _PracticeSpec('overcome', '今日超克', '选择今天要超克的旧我，生成 5-30 分钟最小行动。', '拖延 逃避 无法开始', '哪个旧我被超克了一点？', Icons.bolt_outlined),
  _PracticeSpec('promise', '我能许诺', '慢许诺、承诺降级、履约条件与失败修复。', '目标 计划 承诺 每天 30天', '这个承诺是否过大？', Icons.verified_outlined),
  _PracticeSpec('conscience', '从罪感到责任', '识别坏良心，把自责改写成主权责任。', '废物 不配 自责 惩罚', '我是在修复，还是在惩罚？', Icons.transform_outlined),
  _PracticeSpec('herd', '我正在服从谁？', '识别父母、社会、同龄人、算法和群体标准。', '别人 大家 父母 社会 认可', '这个目标是谁给我的？', Icons.groups_2_outlined),
  _PracticeSpec('rewrite', '打碎与书写', '旧榜谱系追问与新榜写作。', '必须 不能 认可 失败', '我愿意为新榜付什么代价？', Icons.edit_note),
  _PracticeSpec('past', '把过去变成材料', '过去事件重估、反怨恨与未来赋义。', '过去 后悔 浪费 当初', '未来行动如何重新赋义过去？', Icons.history_edu_outlined),
  _PracticeSpec('forge', '为创造而学习', '输入—消化—输出与败坏胃检测。', '学习 阅读 看课 没有输出 信息', '今天的输出是什么？', Icons.auto_fix_high_outlined),
];

class _PracticeSpec {
  final String id;
  final String title;
  final String description;
  final String sceneHint;
  final String reviewQuestion;
  final IconData icon;
  const _PracticeSpec(this.id, this.title, this.description, this.sceneHint, this.reviewQuestion, this.icon);
}

class NewTabletsEngine {
  static NewTabletsAnalysis analyze(String input) {
    final text = input.trim();
    final shame = RegExp('废物|不配|羞耻|内疚|自责|惩罚|罪').hasMatch(text);
    final herd = RegExp('别人|大家|父母|社会|同龄|必须|买房|稳定|认可').hasMatch(text);
    final past = RegExp('过去|后悔|浪费|当初|倒霉').hasMatch(text);
    final studyNoOutput = RegExp('学很多|看课|阅读|信息|没有输出|不行动').hasMatch(text);
    final procrastination = RegExp('偷懒|拖延|不想|逃避|无法开始|手机').hasMatch(text) || text.isEmpty;

    if (shame) return _shame(text, procrastination: procrastination);
    if (herd) return _herd(text);
    if (past) return _past(text);
    if (studyNoOutput) return _study(text);
    if (procrastination) return _procrastination(text);
    return _values(text);
  }

  static NewTabletsAnalysis _procrastination(String text) => NewTabletsAnalysis(
    diagnosis: '你不是单纯“不努力”，而是多个冲动在争夺命令权：即时舒服、逃避失败和成长意志同时存在。问题是更高意志还没有形成可执行命令。',
    mapping: '《善恶的彼岸》第 19 节的“命令与服从” + 〈论自我超克〉。',
    commanders: const [Commander('偷懒冲动', '正在追求立刻舒服'), Commander('逃避冲动', '试图避免失败感'), Commander('成长意志', '需要变成具体命令'), Commander('主权自我', '可以重新发令')],
    oldSelf: '用拖延逃避开始行动的旧我。',
    command: '现在放下手机，打开材料，只做 25 分钟第一轮理解，不追求完美。',
    action: '手机放到 2 米外；打开学习材料；计时 25 分钟；结束写 3 句话总结。',
    guardrail: '这不是为了羞辱自己，而是训练身体服从一个清楚的小命令。',
    reviewQuestions: const ['哪个冲动刚才被你命令了？', '这 25 分钟让你更强还是更弱？', '明天可以把命令扩展到哪里？'],
  );

  static NewTabletsAnalysis _shame(String text, {bool procrastination = false}) => NewTabletsAnalysis(
    diagnosis: '你正在把一次失败解释成“我这个人有罪/无价值”。这属于坏良心语言；它会消耗行动能力，而不是增加可靠性。',
    mapping: '《道德的谱系》第二论文：从罪责、坏良心转向主权责任。',
    commanders: const [Commander('坏良心', '正在攻击整个人'), Commander('自我惩罚冲动', '想用痛苦还债'), Commander('主权责任', '需要修复承诺结构'), Commander('生命肯定', '要求恢复可行动状态')],
    oldSelf: '用自我羞辱代替现实修复的旧我。',
    command: '我今天没有履行承诺；我不惩罚自己，我要找出原因并重设一个可兑现小承诺。',
    action: '写下失败原因：承诺过大/环境失败/身体不足/逃避夺权；选择一项，明天降级为 10-25 分钟任务。',
    guardrail: '任务不是赎罪，而是重新变得可靠；不使用“不配休息/不配吃饭”等自我折磨。',
    reviewQuestions: const ['我把失败解释成事实，还是解释成本质否定？', '承诺结构哪里需要修复？', '明天最小可兑现版本是什么？'],
  );

  static NewTabletsAnalysis _herd(String text) => NewTabletsAnalysis(
    diagnosis: '你可能正在把父母、同龄人、社会评价或算法比较放在最高位置。外部标准未必全错，但必须降级为工具，而不是你的新榜。',
    mapping: '《善恶的彼岸》第 199 节：群体本能与外部命令雷达。',
    commanders: const [Commander('群体比较', '要求你像别人'), Commander('家庭旧榜', '用安全感发令'), Commander('焦虑', '把不服从解释成失败'), Commander('独立判断', '需要夺回尺度')],
    oldSelf: '把“大家都这样”当作最高价值的旧我。',
    command: '我可以使用外部标准，但不让它成为最高价值；我用生命增强、自主性、创造性和可承担性重新评估。',
    action: '今天 2 小时不看社交媒体；写 5 行：如果没有别人评价，我还会追求什么？',
    guardrail: '断连不是逃避现实，而是暂时撤回被群体夺走的判断权。',
    reviewQuestions: const ['这个目标是谁给我的？', '它增强我，还是让我更像别人？', '我是否愿意为它付代价？'],
  );

  static NewTabletsAnalysis _past(String text) => NewTabletsAnalysis(
    diagnosis: '过去的损失需要被承认，但继续怨恨会让过去第二次支配你。你不能改变事实，却能用未来行动重新决定它的意义。',
    mapping: '〈论旧榜与新榜〉中的“拯救过去”与命运肯定。',
    commanders: const [Commander('怨恨', '反复回到无法改变之处'), Commander('后悔', '消耗当前力量'), Commander('未来创造', '可以重新赋义'), Commander('主权自我', '从当下重新发令')],
    oldSelf: '把过去当作终审判决的旧我。',
    command: '过去不是可更改对象；我用接下来的行动让它成为新榜的材料。',
    action: '写下：损失 3 条、训练出的感知 1 条、未来 7 天可补回的行动 1 个；今天先执行 20 分钟。',
    guardrail: '这不是廉价正能量；是承认真损失之后，把剩余力量夺回来。',
    reviewQuestions: const ['我还在让哪段过去命令我？', '它能转化成哪种能力？', '今天从哪里重新开始？'],
  );

  static NewTabletsAnalysis _study(String text) => NewTabletsAnalysis(
    diagnosis: '你可能处在“败坏胃”状态：输入很多，但没有消化和输出。学习若不服务创造，就容易变成焦虑和逃避。',
    mapping: '〈论旧榜与新榜〉：为了创造而学习；精神也需要消化。',
    commanders: const [Commander('信息饥饿', '要求继续囤积'), Commander('逃避行动', '用学习替代作品'), Commander('创造意志', '要求输出'), Commander('独立判断', '要求用自己的话表达')],
    oldSelf: '用学习囤积逃避创造的旧我。',
    command: '今天停止新增输入，把已学内容转成一个可见输出。',
    action: '用 30 分钟写一页笔记/200 字文章/项目小提交/给别人讲 3 分钟，四选一。',
    guardrail: '输出不是为了比较优越，而是为了让知识变成你的力量。',
    reviewQuestions: const ['今天的输入被我消化了吗？', '它服务哪条新榜？', '我的输出是什么？'],
  );

  static NewTabletsAnalysis _values(String text) => NewTabletsAnalysis(
    diagnosis: '你正在寻找行动背后的价值尺度。先不要急着打卡，先识别哪些目标是继承来的旧榜，哪些是你愿意承担代价的新榜。',
    mapping: '〈论旧榜与新榜〉：价值重估与创造新榜。',
    commanders: const [Commander('旧榜', '提供未经审查的标准'), Commander('借来的欲望', '模仿他人的成功'), Commander('生命增强', '寻找更强的方向'), Commander('创造意志', '要求现实实验')],
    oldSelf: '不知道为什么努力、只被外部评价推动的旧我。',
    command: '我不再把未经审查的标准当作最高价值；我只把愿意承担代价的价值写入新榜。',
    action: '写 1 条新榜，并配一个 7 天实验：每天 15-30 分钟，用行动证明它。',
    guardrail: '价值重估不是空想人生意义，而是把新的尺度落到可验证行动。',
    reviewQuestions: const ['这个价值来自我，还是来自外界？', '它增强生命还是削弱生命？', '我愿意为它付什么代价？'],
  );
}


class NewTabletsAnalysis {
  final String diagnosis;
  final String mapping;
  final List<Commander> commanders;
  final String oldSelf;
  final String command;
  final String action;
  final String guardrail;
  final List<String> reviewQuestions;
  const NewTabletsAnalysis({required this.diagnosis, required this.mapping, required this.commanders, required this.oldSelf, required this.command, required this.action, required this.guardrail, required this.reviewQuestions});
}

class Commander { final String name; final String state; const Commander(this.name, this.state); }
