import 'package:flutter/material.dart';

import '../pages/ai_prompt_settings_page.dart';
import 'boundary_practice_prompt_config.dart';

/// Boundary Practice is intentionally implemented as an isolated product module.
/// It does not reuse state, DAOs, or flows from existing growth modules.
class BoundaryPracticeHomePage extends StatefulWidget {
  const BoundaryPracticeHomePage({super.key});

  @override
  State<BoundaryPracticeHomePage> createState() => _BoundaryPracticeHomePageState();
}

enum _BoundaryScene { family, intimacy, friendship, work, technology, self, guilt, relationship }


class _StrictModuleSpec {
  const _StrictModuleSpec({
    required this.shortTitle,
    required this.goal,
    required this.principle,
    required this.features,
    required this.liveEntry,
  });
  final String shortTitle;
  final String goal;
  final String principle;
  final List<String> features;
  final String liveEntry;
}

const List<_StrictModuleSpec> _strictSpecs = <_StrictModuleSpec>[
  _StrictModuleSpec(
    shortTitle: '1 自测',
    goal: '识别用户当前边界类型：松散、僵硬、健康或混合型。',
    principle: '来自《Set Boundaries, Find Peace》中松散边界、僵硬边界、健康边界的区分。',
    features: <String>['初始边界自测', '身体/性/智识/情绪/物质/时间六类边界评分', '家庭/亲密/朋友/工作/技术/金钱/自我管理关系领域画像', '输出风险、三个练习方向和推荐路径'],
    liveEntry: '“边界自测与画像”区：自测题 + 六类边界地图 + 关系领域滑杆。',
  ),
  _StrictModuleSpec(
    shortTitle: '2 雷达',
    goal: '把烦、累、怨、想逃、答应后后悔等情绪翻译成边界问题。',
    principle: '怨恨、焦虑、倦怠常常是边界信号；边界雷达负责识别越界和责任归位。',
    features: <String>['情绪输入', '小 b / 大 B 边界侵犯识别', '我的责任/对方责任/多承担责任/可提供支持分析'],
    liveEntry: '“边界雷达 + AI 场景教练”输入区与标准 AI 输出中的责任归位。',
  ),
  _StrictModuleSpec(
    shortTitle: '3 教练',
    goal: '把核心思想应用到家庭、亲密关系、友谊、工作、技术、自我边界等真实场景。',
    principle: '边界不是冷漠，而是帮助用户清楚、坚定、尊重地活在关系中。',
    features: <String>['家庭边界教练', '亲密关系边界教练', '友谊边界教练', '工作边界教练', '技术边界教练', '自我边界教练'],
    liveEntry: '场景 ChoiceChip：家庭/亲密关系/友谊/工作/技术/自我/内疚/关系评估。',
  ),
  _StrictModuleSpec(
    shortTitle: '4 话术',
    goal: '把模糊不满转成清楚表达，避免攻击、羞辱、冷处理和过度解释。',
    principle: '坚定表达应简短、直接、尊重、清楚；不要期待别人猜。',
    features: <String>['一句话边界', '温和版话术', '坚定版话术', '重述边界话术', '不解释版话术', '话术收藏'],
    liveEntry: '“话术生成器”区生成五类话术并可收藏。',
  ),
  _StrictModuleSpec(
    shortTitle: '5 行动',
    goal: '防止用户只说边界却不执行边界。',
    principle: '边界 = 沟通 + 行动；没有行动的边界只是愿望。',
    features: <String>['边界行动计划', '后果设定器', '执行提醒', '边界刷新'],
    liveEntry: '“行动与后果跟踪”“执行提醒与行动看板”“边界刷新触发器”。',
  ),
  _StrictModuleSpec(
    shortTitle: '6 内疚',
    goal: '帮助用户度过设边界后的心理反弹期。',
    principle: '内疚不一定说明做错，可能只是讨好、拯救或回避旧模式被打破。',
    features: <String>['内疚识别', '不适感陪伴卡', '对方反应预演', '事实 vs 解释', '情绪稳定练习'],
    liveEntry: '“不适感与内疚管理”“事实 vs 解释工作台”“对方反应预演训练器”。',
  ),
  _StrictModuleSpec(
    shortTitle: '7 成长',
    goal: '把一次次边界练习转成长期身份变化。',
    principle: '边界需要重述、刷新和长期练习；关系能否继续取决于边界是否被真实尊重。',
    features: <String>['每日边界复盘', '边界成长曲线', '关系健康档案', '边界身份建设', '关系评估与距离调整'],
    liveEntry: '“每日边界复盘打卡”“关系健康档案”“关系评估与距离调整器”。',
  ),
];


class _BoundaryPersonaSpec {
  const _BoundaryPersonaSpec({required this.name, required this.signs, required this.needs});
  final String name;
  final List<String> signs;
  final List<String> needs;
}

const List<_BoundaryPersonaSpec> _personaSpecs = <_BoundaryPersonaSpec>[
  _BoundaryPersonaSpec(name: '讨好型用户', signs: <String>['总是答应别人', '害怕让别人失望', '说“不”后内疚', '累、怨恨、想逃'], needs: <String>['学会拒绝', '减少过度解释', '承受内疚', '把责任还给别人']),
  _BoundaryPersonaSpec(name: '拯救者型用户', signs: <String>['总想解决别人的问题', '替别人收拾烂摊子', '像治疗师/父母/财务救援者', '帮助后怨恨'], needs: <String>['区分支持和拯救', '不替别人承担后果', '设置金钱/情绪/时间边界']),
  _BoundaryPersonaSpec(name: '僵硬边界型用户', signs: <String>['不求助', '不表达脆弱', '冲突时切断关系', '很难信任别人'], needs: <String>['安全表达', '区分健康边界和高墙', '低风险亲密连接']),
  _BoundaryPersonaSpec(name: '关系混乱型用户', signs: <String>['家庭/伴侣/朋友/职场边界不清', '被拉进别人情绪和责任', '不知道继续/减少/结束'], needs: <String>['边界诊断', '关系距离评估', '对话脚本', '后续行动计划']),
  _BoundaryPersonaSpec(name: '自我边界薄弱型用户', signs: <String>['冲动消费', '刷手机失控', '熬夜拖延', '反复进入伤害性关系'], needs: <String>['建立自我承诺', '小行动重建身份', '追踪自我边界执行']),
];

class _BoundaryPracticeHomePageState extends State<BoundaryPracticeHomePage> {
  final TextEditingController _situationController = TextEditingController(
    text: '我妈每天都问我和老公有没有吵架，我不说她就说我结婚以后不把她当妈了。',
  );
  final TextEditingController _actionTargetController = TextEditingController(text: '今晚 20:30 给妈妈打电话时');
  final TextEditingController _guiltFactController = TextEditingController(text: '我拒绝了朋友临时提出的帮忙请求');
  final TextEditingController _guiltStoryController = TextEditingController(text: '我这样很自私，他会不喜欢我');
  final BoundaryPracticePromptConfig _promptConfig = BoundaryPracticePromptConfig();
  _BoundaryScene _scene = _BoundaryScene.family;
  String _selectedPersona = '讨好型用户';
  String _profile = '混合型：松散边界 + 讨好/拯救倾向';
  Map<String, double> _scores = const {
    '身体': 72,
    '性': 68,
    '智识': 61,
    '情绪': 38,
    '物质': 46,
    '时间': 34,
    '技术': 52,
    '自我': 41,
  };
  _BoundaryOutput? _output;
  String _promptPreview = '';
  final List<_BoundaryReview> _reviews = <_BoundaryReview>[];
  final List<String> _favoriteScripts = <String>[];
  final List<_BoundaryActionPlan> _actionPlans = <_BoundaryActionPlan>[];
  final List<_RelationshipRecord> _relationships = <_RelationshipRecord>[
    const _RelationshipRecord(
      name: '妈妈',
      domain: '家庭',
      violation: '过度追问婚姻隐私',
      expressedBoundary: '婚姻细节由小家庭内部处理',
      response: '质疑与情绪施压',
      distance: '保持联系但降低隐私开放度',
      nextStep: '固定每周一次分享近况，追问时结束话题',
    ),
  ];
  final Map<String, bool> _dailyReview = <String, bool>{
    '今天我清楚表达了一个“不”或限制': false,
    '今天我没有用过度解释换取理解': false,
    '今天我用行动维护了边界': false,
    '今天我尊重了别人的边界': false,
    '今天我对一个自我承诺守信': false,
  };
  final Map<String, bool> _assessmentAnswers = <String, bool>{
    '我很难拒绝别人': true,
    '我经常答应后又怨恨': true,
    '我会过度解释自己的决定': true,
    '我害怕别人失望或生气': true,
    '我经常替别人承担后果': false,
    '我遇到冲突会突然切断关系': false,
    '我很难求助或表达脆弱': false,
    '我能接受别人对我说“不”': false,
  };
  String _selectedReaction = '说你自私';
  String _selectedRefreshEvent = '换工作后';
  double _repairEvidence = 40;
  double _respectConsistency = 35;
  double _safetyRisk = 20;
  final Map<String, double> _domainScores = <String, double>{
    '家庭': 36,
    '亲密关系': 48,
    '朋友': 54,
    '工作': 42,
    '社交媒体与技术': 57,
    '金钱': 44,
    '自我管理': 39,
  };

  static const List<String> _principles = <String>[
    '边界不是控制别人，而是定义自己如何参与关系。',
    '健康边界 = 清楚沟通 + 行动跟进。',
    '内疚不一定是错误信号，也可能是旧模式正在被打破。',
    '我有边界，别人也有边界。',
    '不设边界会带来怨恨、倦怠、逃避和自我背叛。',
  ];

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _situationController.dispose();
    _actionTargetController.dispose();
    _guiltFactController.dispose();
    _guiltStoryController.dispose();
    super.dispose();
  }

  void _runAssessment() {
    final s = _situationController.text;
    final checkedLoose = _assessmentAnswers.entries.where((e) => e.value && (e.key.contains('拒绝') || e.key.contains('怨恨') || e.key.contains('解释') || e.key.contains('失望'))).length;
    final loose = _hits(s, const ['不敢', '内疚', '答应', '借钱', '害怕', '失望', '帮忙', '随叫随到']) + checkedLoose;
    final rigid = _hits(s, const ['断联', '拉黑', '不信任', '不求助', '消失', '切断']);
    final rescue = _hits(s, const ['收拾', '解决', '替他', '替她', '救', '承担', '后果']) + (_assessmentAnswers['我经常替别人承担后果'] == true ? 2 : 0);
    final self = _hits(s, const ['熬夜', '拖延', '消费', '刷手机', '控制不住']);
    final Map<String, double> next = Map<String, double>.from(_scores);
    next['情绪'] = (72 - loose * 9 - rescue * 5).clamp(18, 92).toDouble();
    next['时间'] = (70 - loose * 8 - self * 4).clamp(16, 90).toDouble();
    next['物质'] = (68 - _hits(s, const ['钱', '借', '财务', '消费']) * 12).clamp(18, 88).toDouble();
    next['技术'] = (76 - _hits(s, const ['手机', '短视频', '消息', '社交媒体', '通知']) * 13).clamp(18, 90).toDouble();
    next['自我'] = (74 - self * 14 - loose * 4).clamp(16, 90).toDouble();
    String type;
    if (rigid > loose && rigid > 0) {
      type = '僵硬边界型：用高墙、突然切断或不求助保护自己';
    } else if (rescue >= 2) {
      type = '拯救者型：容易替别人承担情绪、金钱或后果';
    } else if (loose >= 2) {
      type = '松散边界型：容易讨好、过度解释、答应后怨恨';
    } else {
      type = '健康边界发展型：已有觉察，重点是行动跟进与复盘';
    }
    setState(() {
      _profile = type;
      _scores = next;
    });
    _generate();
  }

  int _hits(String input, List<String> words) => words.where(input.contains).length;

  Future<void> _generate() async {
    final output = _BoundaryCoach.generate(
      scene: _scene,
      situation: _situationController.text.trim(),
      actionTarget: _actionTargetController.text.trim(),
    );
    final prompt = await _promptConfig.buildPrompt(
      scene: _BoundaryCoach.sceneKey(_scene),
      userInput: _situationController.text.trim(),
      profileJson: '{\"profile\":\"$_profile\",\"persona\":\"$_selectedPersona\",\"scores\":${_scores.length}}',
      contextJson: '{\"action_target\":\"${_actionTargetController.text.trim()}\"}',
      recentContextJson: '{\"review_count\":${_reviews.length}}',
    );
    if (!mounted) return;
    setState(() {
      _output = output;
      _promptPreview = prompt;
    });
  }

  void _openPromptSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AiPromptSettingsPage(
          initialModuleId: BoundaryPracticePromptConfig.moduleId,
          initialPromptId: BoundaryPracticePromptConfig.globalId,
        ),
      ),
    );
  }

  void _saveReview() {
    final output = _output;
    if (output == null) return;
    setState(() {
      _reviews.insert(
        0,
        _BoundaryReview(
          time: DateTime.now(),
          sceneName: output.sceneName,
          action: output.todayAction,
          script: output.recommendedLine,
        ),
      );
      _actionPlans.insert(
        0,
        _BoundaryActionPlan(
          target: _BoundaryCoach.sceneName(_scene),
          script: output.recommendedLine,
          consequence: output.consequence,
          dueText: _actionTargetController.text.trim().isEmpty ? '今天' : _actionTargetController.text.trim(),
        ),
      );
      _dailyReview['今天我清楚表达了一个“不”或限制'] = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存到边界复盘与行动看板')));
  }

  void _favoriteCurrentScript() {
    final line = _output?.recommendedLine.trim();
    if (line == null || line.isEmpty) return;
    setState(() {
      if (!_favoriteScripts.contains(line)) _favoriteScripts.insert(0, line);
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已收藏话术')));
  }

  void _togglePlanStep(int index, int stepIndex, bool value) {
    final plan = _actionPlans[index];
    setState(() {
      _actionPlans[index] = plan.copyWithStep(stepIndex, value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final output = _output;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EE),
      appBar: AppBar(
        title: const Text('边界练习场 · Boundary Practice'),
        backgroundColor: const Color(0xFFF7F4EE),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _heroCard(),
          const SizedBox(height: 12),
          _strictSevenModuleNavigator(),
          const SizedBox(height: 12),
          _oneToOneFeatureMatrix(),
          const SizedBox(height: 12),
          _linkedWorkflowPanel(),
          const SizedBox(height: 12),
          _moduleDepthCard(),
          const SizedBox(height: 12),
          _sectionCard(title: '三、目标用户画像选择', icon: Icons.person_search_outlined, children: [
            _personaSelector(),
          ]),
          const SizedBox(height: 12),
          _sectionCard(title: '一、边界自测与画像', icon: Icons.radar_outlined, children: [
            Text(_profile, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            _BoundaryMap(scores: _scores),
            const SizedBox(height: 10),
            _assessmentChecklist(),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: const [
              _Tag('三类边界画像'), _Tag('六类边界评分'), _Tag('关系领域画像'), _Tag('推荐训练路径'),
            ]),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: _runAssessment, icon: const Icon(Icons.psychology_alt_outlined), label: const Text('根据当前输入重新自测')),
          ]),
          const SizedBox(height: 12),
          _sectionCard(title: '二、边界雷达 + AI 场景教练', icon: Icons.online_prediction_outlined, children: [
            _sceneSelector(),
            const SizedBox(height: 10),
            TextField(
              controller: _situationController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '输入现实处境 / 情绪信号',
                hintText: '例如：我答应同事帮他做报告，但我很烦……',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _actionTargetController,
              decoration: const InputDecoration(
                labelText: '今日最小行动发生的时间 / 对象 / 场景',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: _generate, icon: const Icon(Icons.auto_awesome), label: const Text('生成边界诊断、话术与行动计划')),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _openPromptSettings, icon: const Icon(Icons.tune_outlined), label: const Text('到设置页自由配置本模块全部 AI 提示词')),
          ]),
          if (output != null) ...[
            const SizedBox(height: 12),
            _sectionCard(title: '三、话术生成器', icon: Icons.record_voice_over_outlined, children: [
              _kv('一句话边界', output.recommendedLine),
              _kv('温和版话术', output.gentleLine),
              _kv('坚定版话术', output.firmLine),
              _kv('不解释版', output.noExplainLine),
              _kv('重述版', output.repeatLine),
              OutlinedButton.icon(onPressed: _favoriteCurrentScript, icon: const Icon(Icons.bookmark_add_outlined), label: const Text('收藏当前推荐话术')),
              if (_favoriteScripts.isNotEmpty) ...[
                const Divider(height: 24),
                _kv('已收藏话术', _favoriteScripts.take(3).join('\n')),
              ],
            ]),
            const SizedBox(height: 12),
            _sectionCard(title: '四、行动与后果跟踪', icon: Icons.checklist_rtl_outlined, children: [
              _numbered(output.actionPlan),
              const Divider(height: 24),
              _kv('合理后果', output.consequence),
              _kv('边界刷新提醒', '换工作、结婚、生孩子、搬家、收入变化、关系修复或对方持续不尊重后，请重新生成新版边界。'),
            ]),
            const SizedBox(height: 12),
            _sectionCard(title: '四-补充：执行提醒与行动看板', icon: Icons.notifications_active_outlined, children: [
              _actionBoard(),
            ]),
            const SizedBox(height: 12),
            _sectionCard(title: '五、不适感与内疚管理', icon: Icons.favorite_border_outlined, children: [
              _numbered(output.guiltCards),
              const SizedBox(height: 8),
              _kv('对方反应预演', output.reactionPlan),
              const Divider(height: 24),
              _guiltWorkbench(),
            ]),
            const SizedBox(height: 12),
            _sectionCard(title: '五-补充：对方反应预演训练器', icon: Icons.theater_comedy_outlined, children: [
              _reactionTrainer(),
            ]),
            const SizedBox(height: 12),
            _sectionCard(title: '六、标准 AI 输出结构', icon: Icons.article_outlined, children: [
              _aiOutput(output),
              const SizedBox(height: 10),
              FilledButton.icon(onPressed: _saveReview, icon: const Icon(Icons.save_outlined), label: const Text('保存本次边界复盘')),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('查看本次三层 Prompt 拼接预览'),
                children: [SelectableText(_promptPreview)],
              ),
            ]),
          ],
          const SizedBox(height: 12),
          _sectionCard(title: '七、边界复盘与成长系统', icon: Icons.show_chart_outlined, children: [
            _growthSystem(),
          ]),
          const SizedBox(height: 12),
          _sectionCard(title: '七-补充：每日边界复盘打卡', icon: Icons.fact_check_outlined, children: [
            _dailyReviewChecklist(),
          ]),
          const SizedBox(height: 12),
          _sectionCard(title: '边界地图：关系领域评分', icon: Icons.map_outlined, children: [
            _domainScoreBoard(),
          ]),
          const SizedBox(height: 12),
          _sectionCard(title: '八、关系健康档案与边界刷新', icon: Icons.people_alt_outlined, children: [
            _relationshipArchive(),
          ]),
          const SizedBox(height: 12),
          _sectionCard(title: '九、关系评估与距离调整器', icon: Icons.social_distance_outlined, children: [
            _relationshipEvaluator(),
          ]),
          const SizedBox(height: 12),
          _sectionCard(title: 'AI 三层 Prompt 体系（模块内置）', icon: Icons.layers_outlined, children: const [
            _PromptBlock(title: '全局价值层', text: '识别边界问题、清楚表达需要、制定现实行动、承受不适；坚持“边界不是控制别人，而是定义自己如何参与”。'),
            _PromptBlock(title: '场景层', text: '家庭、亲密关系、友谊、工作、技术、自我、内疚管理、关系评估八类场景分别约束分析重点。'),
            _PromptBlock(title: '输出格式层', text: '固定输出：问题概括、边界议题、责任归位、话术、反应预案、行动跟进、内疚管理、今日最小行动、复盘与安全提醒。'),
          ]),
        ],
      ),
    );
  }

  Widget _heroCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF40513B), Color(0xFF7A5C37)]),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('把“我应该学会拒绝”变成真实、稳定、可执行的生活方式', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 10),
          const Text('产品闭环：识别问题 → 生成话术 → 执行动作 → 管理内疚 → 复盘成长。', style: TextStyle(color: Color(0xFFEDE7D7), height: 1.45)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: _principles.map((e) => _Pill(e)).toList()),
        ]),
      );


  Widget _strictSevenModuleNavigator() => _sectionCard(
        title: '严格按产品设计方案落地的七大模块导航',
        icon: Icons.account_tree_outlined,
        children: [
          const Text(
            '本区按原产品方案的七大模块逐项呈现：每个模块都有目标、书中思想、子功能和本页可操作入口，避免把方案简化成单一聊天页。',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 12),
          DefaultTabController(
            length: _strictSpecs.length,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  isScrollable: true,
                  labelColor: const Color(0xFF40513B),
                  unselectedLabelColor: const Color(0xFF6B7280),
                  tabs: [for (final spec in _strictSpecs) Tab(text: spec.shortTitle)],
                ),
                SizedBox(
                  height: 330,
                  child: TabBarView(
                    children: [
                      for (final spec in _strictSpecs)
                        ListView(
                          padding: const EdgeInsets.only(top: 12),
                          children: [
                            _kv('模块目标', spec.goal),
                            _kv('对应核心思想', spec.principle),
                            const Text('子功能', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF40513B))),
                            const SizedBox(height: 4),
                            for (final feature in spec.features)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('• $feature', style: const TextStyle(height: 1.35)),
                              ),
                            const SizedBox(height: 8),
                            _kv('本页已落地入口', spec.liveEntry),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );



  int get _workflowCompletedCount {
    final steps = <bool>[
      _situationController.text.trim().isNotEmpty,
      _output != null,
      _favoriteScripts.isNotEmpty,
      _actionPlans.isNotEmpty,
      _actionPlans.any((p) => p.communicated || p.consequenceDone),
      _reviews.isNotEmpty,
      _dailyReview.values.where((v) => v).length >= 3,
    ];
    return steps.where((v) => v).length;
  }

  Widget _linkedWorkflowPanel() {
    final output = _output;
    final steps = <_FlowStepView>[
      _FlowStepView('1 识别问题', _situationController.text.trim().isNotEmpty, _situationController.text.trim().isEmpty ? '先输入现实处境或情绪信号。' : _situationController.text.trim()),
      _FlowStepView('2 生成诊断', output != null, output?.problem ?? '点击“生成边界诊断、话术与行动计划”。'),
      _FlowStepView('3 选定话术', _favoriteScripts.isNotEmpty, _favoriteScripts.isEmpty ? '收藏一条你准备真实使用的话术。' : _favoriteScripts.first),
      _FlowStepView('4 建立行动', _actionPlans.isNotEmpty, _actionPlans.isEmpty ? '保存本次边界复盘后自动生成行动卡。' : '${_actionPlans.first.target} · ${_actionPlans.first.dueText}'),
      _FlowStepView('5 执行后果', _actionPlans.any((p) => p.communicated || p.consequenceDone), '在行动看板勾选“已清楚表达 / 已执行后果”。'),
      _FlowStepView('6 管理内疚', _guiltFactController.text.trim().isNotEmpty && _guiltStoryController.text.trim().isNotEmpty, '用“事实 vs 解释”把内疚从责任中分离。'),
      _FlowStepView('7 复盘成长', _reviews.isNotEmpty && _dailyReview.values.where((v) => v).length >= 3, '完成保存复盘与每日打卡，形成身份化证据。'),
    ];
    return _sectionCard(
      title: 'MVP 核心闭环：识别 → 话术 → 行动 → 内疚 → 复盘',
      icon: Icons.sync_alt_outlined,
      children: [
        LinearProgressIndicator(value: _workflowCompletedCount / steps.length, minHeight: 10, backgroundColor: const Color(0xFFEDE7D7), color: const Color(0xFF40513B)),
        const SizedBox(height: 10),
        Text('当前闭环进度：$_workflowCompletedCount/${steps.length}', style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        for (final step in steps)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(step.done ? Icons.check_circle : Icons.radio_button_unchecked, color: step.done ? const Color(0xFF40513B) : const Color(0xFF9CA3AF)),
            title: Text(step.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(step.detail, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }

  Widget _oneToOneFeatureMatrix() => _sectionCard(
        title: '十二、产品功能总表逐项对应',
        icon: Icons.rule_folder_outlined,
        children: const [
          _PromptBlock(title: '边界自测', text: '三类边界画像、六类边界评分、关系领域评分 → 对应“边界自测与画像”“边界地图：关系领域评分”。'),
          _PromptBlock(title: '边界雷达', text: '情绪识别、越界诊断、责任归位 → 对应“边界雷达 + AI 场景教练”和标准输出的责任归位。'),
          _PromptBlock(title: 'AI 场景教练', text: '家庭、伴侣、朋友、职场、技术、自我边界 → 对应场景选择器八类场景。'),
          _PromptBlock(title: '话术生成器', text: '一句话边界、温和版、坚定版、重述版 → 对应“话术生成器”。'),
          _PromptBlock(title: '行动跟踪', text: '行动计划、后果设定、执行提醒、边界刷新 → 对应行动计划、行动看板、刷新触发器。'),
          _PromptBlock(title: '内疚管理', text: '内疚识别、不适陪伴、反应预演 → 对应内疚管理、事实 vs 解释、反应预演训练器。'),
          _PromptBlock(title: '成长系统', text: '每日复盘、关系档案、成长曲线、身份建设 → 对应复盘打卡、关系健康档案、成长系统。'),
        ],
      );

  Widget _moduleDepthCard() => _sectionCard(title: '十五、关键页面设计逐项落地', icon: Icons.dashboard_customize_outlined, children: const [
        _PromptBlock(title: '首页：今日边界练习', text: '今日边界提醒、今日最小行动、最近一次边界复盘、当前最需要练习的关系、AI 快速入口。'),
        _PromptBlock(title: '边界地图页', text: '六类边界雷达图、家庭/伴侣/朋友/工作/技术/自我评分、当前主要模式、推荐训练路径。'),
        _PromptBlock(title: '场景教练页', text: '我想处理家庭/伴侣/朋友/工作/手机社交媒体/自我边界问题。'),
        _PromptBlock(title: '话术页', text: '一句话边界、温和版、坚定版、不解释版、重述版、对方反应预案。'),
        _PromptBlock(title: '行动计划页', text: '我要对谁设边界、我要说什么、什么时候说、接受/无视/内疚时怎么办、复盘时间。'),
        _PromptBlock(title: '复盘页', text: '我说了吗、是否说清楚、是否过度解释、对方怎么回应、是否行动跟进、现在感觉、下次调整。'),
      ]);

  Widget _sceneSelector() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _BoundaryScene.values.map((scene) {
          final selected = _scene == scene;
          return ChoiceChip(
            selected: selected,
            label: Text(_BoundaryCoach.sceneName(scene)),
            onSelected: (_) => setState(() => _scene = scene),
          );
        }).toList(),
      );

  Widget _sectionCard({required String title, required IconData icon, required List<Widget> children}) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFFE7DDCC))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, color: const Color(0xFF6F4E27)), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)))]),
            const SizedBox(height: 12),
            ...children,
          ]),
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF40513B))),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(height: 1.45)),
        ]),
      );

  Widget _numbered(List<String> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (var i = 0; i < items.length; i++) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${i + 1}. ${items[i]}', style: const TextStyle(height: 1.45)))],
      );

  Widget _aiOutput(_BoundaryOutput o) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _kv('1. 你现在遇到的边界问题', o.problem),
        _kv('边界侵犯级别', o.violationLevel),
        _kv('2. 核心边界议题', o.issues.join('、')),
        _kv('3. 责任归位', '你的责任：${o.userResponsibility}\n对方的责任：${o.otherResponsibility}\n你正在多承担：${o.overResponsibility}\n可提供但不牺牲自己的支持：${o.support}'),
        _kv('4-6. 推荐 / 温和 / 坚定话术', '${o.recommendedLine}\n${o.gentleLine}\n${o.firmLine}'),
        _kv('7. 如果对方这样回应', o.reactionPlan),
        _kv('8. 行动跟进', o.consequence),
        _kv('9. 内疚管理', o.guiltCards.join('\n')),
        _kv('10. 今日最小行动', o.todayAction),
        _kv('11. 复盘问题', '我是否清楚表达了？\n我是否过度解释或道歉了？\n我是否用行动维护了边界？'),
        _kv('12. 安全提醒', '如果涉及暴力、胁迫、严重控制、自伤、他伤、性侵犯、严重职场骚扰或违法风险，请优先保护安全，并寻求可信赖的人、专业机构或当地紧急服务支持。'),
      ]);

  Widget _personaSelector() {
    final current = _personaSpecs.firstWhere((p) => p.name == _selectedPersona, orElse: () => _personaSpecs.first);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final p in _personaSpecs) ChoiceChip(label: Text(p.name), selected: _selectedPersona == p.name, onSelected: (_) => setState(() => _selectedPersona = p.name)),
      ]),
      const SizedBox(height: 10),
      _kv('典型表现', current.signs.join('；')),
      _kv('核心需求', current.needs.join('；')),
      _kv('与训练流的连接', '画像会进入本模块 Prompt 上下文，并影响你优先关注的边界类型、话术强度、行动后果和内疚管理策略。'),
    ]);
  }

  Widget _assessmentChecklist() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('初始边界自测题', style: TextStyle(fontWeight: FontWeight.w900)),
        for (final entry in _assessmentAnswers.entries) CheckboxListTile(
          value: entry.value,
          onChanged: (v) => setState(() => _assessmentAnswers[entry.key] = v ?? false),
          title: Text(entry.key),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ]);

  Widget _guiltWorkbench() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('内疚识别：事实 vs 解释', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        TextField(controller: _guiltFactController, decoration: const InputDecoration(labelText: '事实：发生了什么', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: _guiltStoryController, decoration: const InputDecoration(labelText: '解释：我脑中如何评价这件事', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        _kv('责任重估', '事实不等于解释。你需要负责清楚表达与尊重行动，不需要负责让所有人立刻满意。'),
      ]);

  Widget _reactionTrainer() {
    final responses = <String, String>{
      '质疑你': '我理解你有不同看法，但我的决定没有改变。',
      '生气': '我愿意在彼此尊重时继续谈，现在我们先暂停。',
      '说你自私': '这不是不在乎你，而是我需要保护自己的边界。',
      '讨价还价': '我不会继续协商这个底线。',
      '冷处理': '我会给你时间消化，但我不会因为沉默撤回边界。',
      '继续越界': '我已经说明边界了，现在我会执行刚才说过的行动。',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, children: responses.keys.map((k) => ChoiceChip(label: Text(k), selected: _selectedReaction == k, onSelected: (_) => setState(() => _selectedReaction = k))).toList()),
      const SizedBox(height: 8),
      _kv('可直接回应', responses[_selectedReaction] ?? ''),
    ]);
  }

  Widget _relationshipEvaluator() {
    final score = (_repairEvidence + _respectConsistency - _safetyRisk).clamp(0, 100).round();
    final advice = _safetyRisk > 70
        ? '优先安全：暂停单独沟通，记录证据，寻求可信赖的人、专业机构或当地紧急服务。'
        : score >= 65
            ? '可以修复：给出清楚观察周期，看对方是否持续尊重边界。'
            : score >= 35
                ? '降低距离：减少隐私、金钱或情绪承接，只保留低风险互动。'
                : '暂停或退出：如果表达和行动多次无效，请把精力转回安全与自我恢复。';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _slider('对方是否有真实行为改变证据', _repairEvidence, (v) => setState(() => _repairEvidence = v)),
      _slider('对方是否持续尊重边界', _respectConsistency, (v) => setState(() => _respectConsistency = v)),
      _slider('安全/控制/羞辱/胁迫风险', _safetyRisk, (v) => setState(() => _safetyRisk = v)),
      _kv('关系距离建议（$score/100）', advice),
    ]);
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label：${value.round()}'),
        Slider(value: value, min: 0, max: 100, divisions: 20, label: value.round().toString(), onChanged: onChanged),
      ]);

  Widget _relationshipArchive() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _kv('关系健康档案字段', '关系对象、主要越界类型、已表达边界、对方反应、我采取过的行动、当前关系距离、是否值得修复、是否需要降级/暂停/结束。'),
        for (final r in _relationships) Card(
          elevation: 0,
          color: const Color(0xFFF7F4EE),
          child: ListTile(
            title: Text('${r.name} · ${r.domain}', style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text('越界：${r.violation}\n已表达：${r.expressedBoundary}\n反应：${r.response}\n距离：${r.distance}\n下一步：${r.nextStep}'),
          ),
        ),
        _kv('边界刷新触发器', '换工作、结婚、生孩子、搬家、收入变化、关系修复、对方持续不尊重、自己容量显著变化。'),
        Wrap(spacing: 8, children: ['换工作后', '结婚后', '生孩子后', '收入变化后', '对方持续不尊重后'].map((e) => ChoiceChip(label: Text(e), selected: _selectedRefreshEvent == e, onSelected: (_) => setState(() => _selectedRefreshEvent = e))).toList()),
        _kv('刷新后的边界草案', '$_selectedRefreshEvent，我需要重新说明我的时间、情绪和责任边界。接下来我会先表达一次，如果仍被无视，我会降低互动强度或执行预设后果。'),
        _kv('七天执行计划', '第1天识别情绪信号；第2天写一句话边界；第3天预演对方反应；第4天执行最小行动；第5天管理内疚；第6天重述或执行后果；第7天复盘并更新身份表述。'),
        _kv('关系距离建议', '不是只能忍耐或断联，可选择：保持但限频、只谈低风险话题、减少金钱/情绪承接、暂停联系、在高风险时优先安全和正式支持。'),
      ]);

  Widget _actionBoard() {
    if (_actionPlans.isEmpty) {
      return const Text('保存一次边界复盘后，行动看板会生成“已表达 / 已执行后果 / 已复盘”三步追踪，避免边界只停留在话术层面。');
    }
    return Column(
      children: [
        for (var i = 0; i < _actionPlans.length; i++) Card(
          elevation: 0,
          color: const Color(0xFFF7F4EE),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_actionPlans[i].target} · ${_actionPlans[i].dueText}', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(_actionPlans[i].script),
              const SizedBox(height: 6),
              Text('后果：${_actionPlans[i].consequence}', style: const TextStyle(color: Color(0xFF6F4E27))),
              CheckboxListTile(value: _actionPlans[i].communicated, onChanged: (v) => _togglePlanStep(i, 0, v ?? false), title: const Text('已清楚表达'), dense: true, contentPadding: EdgeInsets.zero),
              CheckboxListTile(value: _actionPlans[i].consequenceDone, onChanged: (v) => _togglePlanStep(i, 1, v ?? false), title: const Text('必要时已执行后果'), dense: true, contentPadding: EdgeInsets.zero),
              CheckboxListTile(value: _actionPlans[i].reviewed, onChanged: (v) => _togglePlanStep(i, 2, v ?? false), title: const Text('已完成复盘'), dense: true, contentPadding: EdgeInsets.zero),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _dailyReviewChecklist() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final entry in _dailyReview.entries) CheckboxListTile(
          value: entry.value,
          onChanged: (v) => setState(() => _dailyReview[entry.key] = v ?? false),
          title: Text(entry.key),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        _kv('今日身份沉淀', _dailyReview.values.where((v) => v).length >= 3 ? '我是一个正在用行动维护清晰关系的人。' : '今天先完成一个最小行动，不用一次变成完美有边界的人。'),
      ]);

  Widget _domainScoreBoard() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final entry in _domainScores.entries) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${entry.key}：${entry.value.round()}'),
          Slider(
            value: entry.value,
            min: 0,
            max: 100,
            divisions: 20,
            label: entry.value.round().toString(),
            onChanged: (v) => setState(() => _domainScores[entry.key] = v),
          ),
        ]),
        _kv('优先练习领域', (_domainScores.entries.toList()..sort((a, b) => a.value.compareTo(b.value))).first.key),
      ]);

  Widget _growthSystem() {
    if (_reviews.isEmpty) {
      return const Text('保存一次 AI 输出后，这里会形成关系健康档案、行动证据和身份化成长记录。每日复盘问题：今天我哪里说了“不”？哪里过度解释了？哪里尊重了别人和自己的边界？');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('成长曲线：已记录 ${_reviews.length} 次边界练习；过度解释减少、边界重述、自我守信天数可持续追踪。', style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      for (final r in _reviews.take(5)) ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(backgroundColor: Color(0xFFE7DDCC), child: Icon(Icons.flag_outlined, color: Color(0xFF40513B))),
        title: Text('${r.sceneName} · ${r.action}', maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(r.script, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
      const SizedBox(height: 8),
      const Text('身份建设：我不是在讨好中证明爱；我是一个尊重自己容量、资源和关系清晰度的人。'),
    ]);
  }
}

class _BoundaryCoach {
  static String sceneKey(_BoundaryScene scene) => switch (scene) {
        _BoundaryScene.family => 'family',
        _BoundaryScene.intimacy => 'intimacy',
        _BoundaryScene.friendship => 'friendship',
        _BoundaryScene.work => 'work',
        _BoundaryScene.technology => 'technology',
        _BoundaryScene.self => 'self',
        _BoundaryScene.guilt => 'guilt',
        _BoundaryScene.relationship => 'relationship',
      };

  static String sceneName(_BoundaryScene scene) => switch (scene) {
        _BoundaryScene.family => '家庭',
        _BoundaryScene.intimacy => '亲密关系',
        _BoundaryScene.friendship => '友谊',
        _BoundaryScene.work => '工作',
        _BoundaryScene.technology => '技术/社媒',
        _BoundaryScene.self => '自我边界',
        _BoundaryScene.guilt => '内疚管理',
        _BoundaryScene.relationship => '关系评估',
      };

  static _BoundaryOutput generate({required _BoundaryScene scene, required String situation, required String actionTarget}) {
    final cfg = _SceneConfig.of(scene);
    final subject = _extractSubject(scene, situation);
    final issue = cfg.issues;
    final request = _extractRequest(situation, cfg.defaultRequest);
    final violationLevel = _classifyViolation(situation);
    final recommended = '${cfg.address(subject)}，${cfg.care}，但我${cfg.boundaryVerb}$request。${cfg.followUp}';
    final gentle = '${cfg.address(subject)}，我知道这件事对你重要。现在我需要先确认自己的容量，所以我不会马上答应$request。我们可以${cfg.supportOption}。';
    final firm = '${cfg.address(subject)}，我已经说过我不会继续$request。如果这个边界继续被无视，我会${cfg.consequenceAction}。';
    return _BoundaryOutput(
      sceneName: sceneName(scene),
      problem: '这是一个${sceneName(scene)}边界问题：你已经出现烦、累、内疚、想逃或答应后后悔的信号，需要把模糊不满转成清楚表达和行动。',
      violationLevel: violationLevel,
      issues: issue,
      userResponsibility: '清楚表达你的需要、限制和下一步行动，并检查自己是否在过度解释、讨好、冷处理或控制。',
      otherResponsibility: cfg.otherResponsibility,
      overResponsibility: cfg.overResponsibility,
      support: cfg.support,
      recommendedLine: recommended,
      gentleLine: gentle,
      firmLine: firm,
      noExplainLine: '不行，我现在不方便$request。',
      repeatLine: '我理解你不习惯这个变化，但我的决定没有改变。',
      actionPlan: [
        '我要对谁设边界：$subject。',
        '我要说什么：先使用“一句话边界”，不要解释超过三分钟。',
        '我什么时候说：${actionTarget.isEmpty ? '今天选择一个低干扰时间' : actionTarget}。',
        '如果对方接受：感谢对方理解，并把新的互动方式具体化。',
        '如果对方无视：重述一次边界，然后执行后果。',
        '如果我内疚：先稳定自己，不用撤回边界换取对方舒服。',
      ],
      consequence: '如果对方继续无视，你可以先转换话题一次；若仍继续，就${cfg.consequenceAction}。关键是让行动和边界一致。',
      guiltCards: const [
        '我可以不舒服，但不撤回边界。',
        '别人的失望不等于我的错误。',
        '我不需要用过度解释换取理解。',
      ],
      reactionPlan: '对方质疑：我理解你有不同感受，但我的决定没有改变。\n对方生气：我愿意在彼此尊重时继续谈，现在先暂停。\n对方说我自私：这不是不在乎你，而是我需要保护自己的边界。\n对方讨价还价：我不会继续协商这个底线。\n对方继续越界：我会执行刚才说过的行动。',
      todayAction: '${actionTarget.isEmpty ? '今天' : actionTarget}只说一句边界句，不补充长篇解释，并在结束后记录一次复盘。',
    );
  }

  static String _classifyViolation(String s) {
    final severe = ['暴力', '威胁', '胁迫', '性骚扰', '性侵犯', '控制', '跟踪', '羞辱', '霸凌', '违法', '自伤', '他伤'];
    final chronic = ['每次', '总是', '长期', '反复', '持续', '多年'];
    if (severe.any(s.contains)) {
      return '大 B 边界侵犯：可能涉及安全、权力压迫、严重控制、暴力/胁迫/骚扰或违法风险，优先安全、记录证据并寻求可信赖的人、专业机构或当地紧急服务支持。';
    }
    if (chronic.any(s.contains)) {
      return '大 B 倾向：这是反复或长期模式，不宜只靠一次温和沟通，需要清楚后果、关系距离调整和持续观察行为证据。';
    }
    return '小 b 边界侵犯：偏日常轻微或中度越界，优先使用清楚沟通、重述边界和一致行动。';
  }

  static String _extractSubject(_BoundaryScene scene, String s) {
    final pairs = <String, String>{'妈': '妈', '妈妈': '妈妈', '爸': '爸', '老板': '老板', '同事': '同事', '朋友': '朋友', '伴侣': '伴侣', '老公': '老公', '老婆': '老婆', '哥哥': '哥哥', '姐姐': '姐姐'};
    for (final e in pairs.entries) {
      if (s.contains(e.key)) return e.value;
    }
    return switch (scene) { _BoundaryScene.work => '对方', _BoundaryScene.self => '自己', _ => '对方' };
  }

  static String _extractRequest(String s, String fallback) {
    if (s.contains('借钱')) return '借钱';
    if (s.contains('加班')) return '无条件加班';
    if (s.contains('手机') || s.contains('短视频')) return '让手机占用我们的相处和休息时间';
    if (s.contains('问') || s.contains('追问')) return '详细讨论这些私人细节';
    if (s.contains('帮')) return '承担这件超出我容量的帮忙';
    if (s.contains('熬夜')) return '继续熬夜透支自己';
    return fallback;
  }
}

class _SceneConfig {
  const _SceneConfig({required this.issues, required this.care, required this.boundaryVerb, required this.defaultRequest, required this.followUp, required this.otherResponsibility, required this.overResponsibility, required this.support, required this.supportOption, required this.consequenceAction});
  final List<String> issues;
  final String care;
  final String boundaryVerb;
  final String defaultRequest;
  final String followUp;
  final String otherResponsibility;
  final String overResponsibility;
  final String support;
  final String supportOption;
  final String consequenceAction;
  String address(String subject) => subject == '自己' ? '我' : subject;

  static _SceneConfig of(_BoundaryScene scene) => switch (scene) {
        _BoundaryScene.family => const _SceneConfig(issues: ['家庭边界', '情绪边界', '时间边界', '隐私边界'], care: '我知道你关心我', boundaryVerb: '不会继续', defaultRequest: '把我的私人生活全部开放给你', followUp: '我会分享近况，但具体问题我会自己处理。', otherResponsibility: '管理自己的不安、失望或需求，不用亲情施压。', overResponsibility: '用顺从、分享隐私或牺牲资源来证明爱。', support: '可以固定联系和表达关心，但不开放所有隐私或承担所有后果。', supportOption: '约一个固定时间聊近况', consequenceAction: '结束这次通话或改天再聊'),
        _BoundaryScene.intimacy => const _SceneConfig(issues: ['亲密关系边界', '情绪边界', '物质边界', '技术边界'], care: '我在乎我们的关系', boundaryVerb: '需要重新协商', defaultRequest: '靠猜测维持关系', followUp: '我们需要把期待说清楚并形成具体协议。', otherResponsibility: '表达需要、尊重协议，并承担自己的行为影响。', overResponsibility: '用忍耐、追问或控制来维持亲密。', support: '可以一起协商家务、金钱、手机、性生活和冲突规则。', supportOption: '一起定一个明确协议', consequenceAction: '暂停这次讨论并约定再谈时间'),
        _BoundaryScene.friendship => const _SceneConfig(issues: ['友谊边界', '情绪边界', '时间边界', '物质边界'], care: '我珍惜我们的友谊', boundaryVerb: '不能继续', defaultRequest: '无限承接情绪或随叫随到', followUp: '我能支持你，但不能充当治疗师或救援者。', otherResponsibility: '寻找多元支持、尊重朋友的时间和资源。', overResponsibility: '替朋友消化情绪、收拾烂摊子或承担财务风险。', support: '可以倾听一段时间、推荐资源或约定互惠联系。', supportOption: '把聊天控制在一个可承受的时间', consequenceAction: '降低互动频率'),
        _BoundaryScene.work => const _SceneConfig(issues: ['工作边界', '时间边界', '职责边界', '尊严边界'], care: '我会对工作负责', boundaryVerb: '需要先确认优先级，不能默认接受', defaultRequest: '超出职责和时间容量的任务', followUp: '请帮我确认优先级、截止时间和资源。', otherResponsibility: '清楚分配任务、尊重下班时间和正式流程。', overResponsibility: '用无条件可用证明自己是好员工。', support: '可以提供专业协作，但不牺牲所有休息和职责边界。', supportOption: '重新排优先级', consequenceAction: '把任务退回并抄送负责人'),
        _BoundaryScene.technology => const _SceneConfig(issues: ['技术边界', '注意力边界', '时间边界', '亲密关系边界'], care: '我需要保护注意力和休息', boundaryVerb: '不会继续', defaultRequest: '被消息、短视频或通知牵着走', followUp: '我会设置静音、限时和无手机时段。', otherResponsibility: '尊重离线时间和当面相处规则。', overResponsibility: '把即时回复当成关系证明。', support: '可以约定回复窗口和无手机陪伴时间。', supportOption: '约定一个固定回复窗口', consequenceAction: '关闭通知并把手机放到另一个房间'),
        _BoundaryScene.self => const _SceneConfig(issues: ['自我边界', '时间边界', '物质边界', '身体边界'], care: '我想对自己守信', boundaryVerb: '不再默认允许自己', defaultRequest: '继续重复这个伤害自己的旧模式', followUp: '我今天只做一个最小可执行行动。', otherResponsibility: '他人不需要替我执行我的自我承诺。', overResponsibility: '用自责代替行动修复。', support: '可以请求陪伴或环境支持，但行动由我执行。', supportOption: '请一个人见证我的七天计划', consequenceAction: '启动预设替代行为并记录失败修复'),
        _BoundaryScene.guilt => const _SceneConfig(issues: ['内疚管理', '情绪边界', '责任边界'], care: '我可以善良', boundaryVerb: '不需要因为内疚撤回', defaultRequest: '用自我牺牲证明关系', followUp: '我会先稳定自己，再决定是否需要重述边界。', otherResponsibility: '处理自己的失望，而不是把失望变成施压。', overResponsibility: '把对方不舒服等同于自己做错。', support: '可以表达理解，但不牺牲底线。', supportOption: '给对方一点时间消化', consequenceAction: '暂停回应，24小时后再复盘'),
        _BoundaryScene.relationship => const _SceneConfig(issues: ['关系评估', '边界执行历史', '关系距离'], care: '我愿意看事实而不是只看承诺', boundaryVerb: '需要观察行为证据后再决定是否继续', defaultRequest: '忽视边界后只用口头道歉恢复原状', followUp: '关系能否继续，要看边界是否被真实尊重。', otherResponsibility: '用持续行为改变证明尊重，而不是只解释。', overResponsibility: '无限给机会、替对方合理化或忽视安全风险。', support: '可以给出清楚条件和观察期限。', supportOption: '设一个具体观察周期', consequenceAction: '降低关系距离或暂停联系'),
      };
}

class _BoundaryOutput {
  const _BoundaryOutput({required this.sceneName, required this.problem, required this.violationLevel, required this.issues, required this.userResponsibility, required this.otherResponsibility, required this.overResponsibility, required this.support, required this.recommendedLine, required this.gentleLine, required this.firmLine, required this.noExplainLine, required this.repeatLine, required this.actionPlan, required this.consequence, required this.guiltCards, required this.reactionPlan, required this.todayAction});
  final String sceneName;
  final String problem;
  final String violationLevel;
  final List<String> issues;
  final String userResponsibility;
  final String otherResponsibility;
  final String overResponsibility;
  final String support;
  final String recommendedLine;
  final String gentleLine;
  final String firmLine;
  final String noExplainLine;
  final String repeatLine;
  final List<String> actionPlan;
  final String consequence;
  final List<String> guiltCards;
  final String reactionPlan;
  final String todayAction;
}

class _FlowStepView {
  const _FlowStepView(this.title, this.done, this.detail);
  final String title;
  final bool done;
  final String detail;
}

class _BoundaryActionPlan {
  const _BoundaryActionPlan({
    required this.target,
    required this.script,
    required this.consequence,
    required this.dueText,
    this.communicated = false,
    this.consequenceDone = false,
    this.reviewed = false,
  });
  final String target;
  final String script;
  final String consequence;
  final String dueText;
  final bool communicated;
  final bool consequenceDone;
  final bool reviewed;

  _BoundaryActionPlan copyWithStep(int index, bool value) {
    return _BoundaryActionPlan(
      target: target,
      script: script,
      consequence: consequence,
      dueText: dueText,
      communicated: index == 0 ? value : communicated,
      consequenceDone: index == 1 ? value : consequenceDone,
      reviewed: index == 2 ? value : reviewed,
    );
  }
}

class _RelationshipRecord {
  const _RelationshipRecord({
    required this.name,
    required this.domain,
    required this.violation,
    required this.expressedBoundary,
    required this.response,
    required this.distance,
    required this.nextStep,
  });
  final String name;
  final String domain;
  final String violation;
  final String expressedBoundary;
  final String response;
  final String distance;
  final String nextStep;
}

class _BoundaryReview {
  const _BoundaryReview({required this.time, required this.sceneName, required this.action, required this.script});
  final DateTime time;
  final String sceneName;
  final String action;
  final String script;
}

class _BoundaryMap extends StatelessWidget {
  const _BoundaryMap({required this.scores});
  final Map<String, double> scores;
  @override
  Widget build(BuildContext context) => Column(
        children: scores.entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(width: 44, child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700))),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: e.value / 100, minHeight: 10, backgroundColor: const Color(0xFFEDE7D7), color: Color.lerp(const Color(0xFFC7522A), const Color(0xFF40513B), e.value / 100)))),
            const SizedBox(width: 8),
            Text(e.value.round().toString()),
          ]),
        )).toList(),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white24)), child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)));
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Chip(label: Text(text), backgroundColor: const Color(0xFFF7F4EE), side: const BorderSide(color: Color(0xFFE7DDCC)));
}

class _PromptBlock extends StatelessWidget {
  const _PromptBlock({required this.title, required this.text});
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('$title：$text', style: const TextStyle(height: 1.45)));
}
