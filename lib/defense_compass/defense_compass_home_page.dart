import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../pages/ai_prompt_settings_page.dart';
import 'defense_compass_ai_service.dart';
import 'defense_compass_content.dart';
import 'defense_compass_dao.dart';
import 'defense_compass_models.dart';
import 'defense_compass_prompt_config.dart';


class _DefenseCompassDeepFieldSpec {
  final String label;
  final String hint;

  const _DefenseCompassDeepFieldSpec(this.label, this.hint);
}

class _DefenseCompassSceneSpec {
  final String label;
  final String inputLabel;
  final String inputTemplate;
  final String outputMode;
  final String deepSubtitle;
  final List<_DefenseCompassDeepFieldSpec> deepFields;

  const _DefenseCompassSceneSpec({
    required this.label,
    required this.inputLabel,
    required this.inputTemplate,
    required this.outputMode,
    required this.deepSubtitle,
    required this.deepFields,
  });
}

class DefenseCompassHomePage extends StatefulWidget {
  final String initialInput;
  final String initialScene;

  const DefenseCompassHomePage({
    super.key,
    this.initialInput = '',
    this.initialScene = 'event_analysis',
  });

  @override
  State<DefenseCompassHomePage> createState() => _DefenseCompassHomePageState();
}

class _DefenseCompassHomePageState extends State<DefenseCompassHomePage> with SingleTickerProviderStateMixin {
  final DefenseCompassDao _dao = DefenseCompassDao();
  final DefenseCompassAiService _ai = DefenseCompassAiService();
  late final TabController _tabs;
  static const int _tabCompass = 0;
  static const int _tabAnalysis = 1;
  static const int _tabTraining = 2;
  static const int _tabAction = 3;
  static const int _tabDefenseLibrary = 4;
  static const int _tabRelationship = 5;
  static const int _tabTransitionFamily = 6;
  static const int _tabCourse = 7;
  static const int _tabStats = 8;
  static const int _tabProfile = 9;
  static const int _tabSafety = 10;

  final TextEditingController _inputCtrl = TextEditingController();
  final TextEditingController _peopleCtrl = TextEditingController();
  final TextEditingController _factsCtrl = TextEditingController();
  final TextEditingController _emotionCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();
  final TextEditingController _impulseCtrl = TextEditingController();
  final TextEditingController _avoidedCtrl = TextEditingController();
  final TextEditingController _themesCtrl = TextEditingController();
  final TextEditingController _defensesCtrl = TextEditingController();
  final TextEditingController _triggersCtrl = TextEditingController();
  final TextEditingController _avoidCtrl = TextEditingController();
  final TextEditingController _relationCtrl = TextEditingController();
  final TextEditingController _supportCtrl = TextEditingController();
  final TextEditingController _safetyCtrl = TextEditingController();

  bool _loading = true;
  bool _generating = false;
  String _scene = 'event_analysis';
  String _outputMode = 'standard';
  DefenseCompassProfile _profile = const DefenseCompassProfile();
  List<DefenseCompassSession> _sessions = const <DefenseCompassSession>[];
  List<DefenseCompassAction> _actions = const <DefenseCompassAction>[];
  List<DefenseCompassReport> _reports = const <DefenseCompassReport>[];
  Map<String, DefenseCompassCourseProgress> _courseProgress = const <String, DefenseCompassCourseProgress>{};
  DefenseCompassStats _stats = const DefenseCompassStats();
  DefenseCompassSession? _latest;
  String _lastAutoTemplate = '';

  static const Map<String, String> _sceneLabels = <String, String>{
    'event_analysis': '事件罗盘',
    'deep_event_record': '深度记录',
    'defense_identify': '防御识别',
    'anxiety_source': '焦虑来源',
    'reality_check': '现实检验',
    'affect_tolerance': '情绪承受',
    'wish_integration': '欲望整合',
    'self_limitation': '自我限制',
    'relationship_defense': '关系防御',
    'altruistic_surrender': '利他让渡',
    'transition': '转折期',
    'family_education': '家庭教育',
    'monthly_review': '月度复盘',
    'action_generation': '行动生成',
    'action_review': '行动复盘',
    'closure_audit': '闭环审计',
  };

  static const Map<String, String> _outputLabels = <String, String>{
    'standard': '标准分析卡',
    'anxiety': '焦虑来源卡',
    'reality': '现实检验卡',
    'emotion': '情绪承受卡',
    'wish': '欲望整合卡',
    'self_limitation': '自我限制突破卡',
    'relationship': '关系沟通卡',
    'altruistic': '利他让渡与边界卡',
    'transition': '转折期稳定卡',
    'family': '家庭教育回应卡',
    'action': '行动卡',
    'action_review': '行动复盘卡',
    'monthly': '月度报告',
    'closure': '闭环审计卡',
    'profile': '个人防御地图更新卡',
    'safety': '安全支持卡',
  };

  static const List<_DefenseCompassDeepFieldSpec> _defaultDeepFields = <_DefenseCompassDeepFieldSpec>[
    _DefenseCompassDeepFieldSpec('涉及的人', '例如：伴侣、父母、领导、同事、朋友'),
    _DefenseCompassDeepFieldSpec('已确认事实', '只写能被第三方观察到的事实，不写解释'),
    _DefenseCompassDeepFieldSpec('显性情绪与强度', '例如：羞耻 8/10、愤怒 6/10、焦虑 7/10'),
    _DefenseCompassDeepFieldSpec('身体反应', '例如：胸闷、胃紧、想哭、发冷、僵住'),
    _DefenseCompassDeepFieldSpec('当时冲动', '例如：想攻击、想逃、想讨好、想删掉消息'),
    _DefenseCompassDeepFieldSpec('我没有做 / 回避了什么', '例如：没有表达需求、没有确认事实、没有发作品'),
  ];

  static const Map<String, _DefenseCompassSceneSpec> _sceneSpecs = <String, _DefenseCompassSceneSpec>{
    'event_analysis': _DefenseCompassSceneSpec(
      label: '事件罗盘',
      inputLabel: '写下一个真实事件',
      outputMode: 'standard',
      deepSubtitle: '补齐事件、事实、情绪、身体、冲动和回避行为字段。',
      deepFields: _defaultDeepFields,
      inputTemplate: '请帮我分析一个真实事件。\n发生了什么：\n我当时最强烈的情绪是：\n我真正想要的是：\n我最害怕的是：\n我实际做了什么 / 没有做什么：',
    ),
    'deep_event_record': _DefenseCompassSceneSpec(
      label: '深度记录',
      inputLabel: '写下一个需要深度结构化拆解的事件',
      outputMode: 'standard',
      deepSubtitle: '深度记录会优先保留事实、解释、情绪、身体、冲动和回避字段。',
      deepFields: _defaultDeepFields,
      inputTemplate: '请帮我做一次深度结构化记录。\n事件背景：\n我最想弄清楚的是：\n我希望最后能得到一个现实行动：',
    ),
    'defense_identify': _DefenseCompassSceneSpec(
      label: '防御识别',
      inputLabel: '写下一个让你反复困扰的反应',
      outputMode: 'standard',
      deepSubtitle: '补充触发、情绪和行为，有助于识别可能的防御机制。',
      deepFields: _defaultDeepFields,
      inputTemplate: '请帮我识别可能的防御机制。\n最近的具体事件是：\n我当时的反应是：\n我事后觉得不理解自己的地方是：\n我希望知道这个反应保护了我什么、限制了我什么：',
    ),
    'anxiety_source': _DefenseCompassSceneSpec(
      label: '焦虑来源',
      inputLabel: '写下你最害怕发生的后果',
      outputMode: 'anxiety',
      deepSubtitle: '补充恐惧对象、内在禁令和现实后果，帮助区分焦虑来源。',
      deepFields: <_DefenseCompassDeepFieldSpec>[
        _DefenseCompassDeepFieldSpec('涉及的人/权威', '例如：父母、伴侣、领导、同事、孩子'),
        _DefenseCompassDeepFieldSpec('已确认现实后果', '事实层面已经发生或确定会发生什么'),
        _DefenseCompassDeepFieldSpec('最强情绪与强度', '例如：内疚 8/10、恐惧 7/10'),
        _DefenseCompassDeepFieldSpec('身体警报', '身体如何提醒你危险'),
        _DefenseCompassDeepFieldSpec('最想控制/逃开的冲动', '例如：解释、道歉、消失、攻击、讨好'),
        _DefenseCompassDeepFieldSpec('我正在避免承认', '例如：我其实很想赢/很生气/很依赖'),
      ],
      inputTemplate: '请帮我分析这个防御背后的焦虑来源。\n我最害怕发生的是：\n我觉得自己“不应该”的是：\n现实中真正可能发生的后果是：\n我害怕自己一旦承认就会：\n我希望知道这是超我焦虑、现实焦虑、本能强度焦虑、情感不快，还是自我综合冲突：',
    ),
    'reality_check': _DefenseCompassSceneSpec(
      label: '现实检验',
      inputLabel: '写下你目前的判断、猜测或担心',
      outputMode: 'reality',
      deepSubtitle: '把事实、解释、害怕版本、希望版本和缺失信息拆开。',
      deepFields: <_DefenseCompassDeepFieldSpec>[
        _DefenseCompassDeepFieldSpec('涉及的人/情境', '谁、在哪里、什么关系'),
        _DefenseCompassDeepFieldSpec('已确认事实', '只写已经确认的事实'),
        _DefenseCompassDeepFieldSpec('我现在的情绪', '这个判断让我有什么情绪'),
        _DefenseCompassDeepFieldSpec('身体反应', '身体哪里紧张或有反应'),
        _DefenseCompassDeepFieldSpec('我最想立刻做的事', '例如：质问、退出、解释、拉黑'),
        _DefenseCompassDeepFieldSpec('我还没有验证的信息', '哪些仍只是猜测'),
      ],
      inputTemplate: '请帮我做一次现实检验。\n我现在认为发生了什么：\n我已经确认的事实是：\n我自己的解释/猜测是：\n我最害怕的版本是：\n我最希望的版本是：\n我想知道如何低风险验证现实：',
    ),
    'affect_tolerance': _DefenseCompassSceneSpec(
      label: '情绪承受',
      inputLabel: '写下你现在最强烈的情绪',
      outputMode: 'emotion',
      deepSubtitle: '情绪承受场景优先稳定，不急着深挖原因。',
      deepFields: <_DefenseCompassDeepFieldSpec>[
        _DefenseCompassDeepFieldSpec('此刻是否有人在场', '独处/和谁在一起/是否安全'),
        _DefenseCompassDeepFieldSpec('触发事实', '刚刚发生了什么'),
        _DefenseCompassDeepFieldSpec('最强情绪与强度', '例如：羞耻 9/10、愤怒 8/10'),
        _DefenseCompassDeepFieldSpec('身体位置', '情绪在身体哪里'),
        _DefenseCompassDeepFieldSpec('最想立刻做的冲动', '例如：攻击、逃走、讨好、伤害自己、删除'),
        _DefenseCompassDeepFieldSpec('我愿意先暂停多久', '例如：90 秒、3 分钟、10 分钟'),
      ],
      inputTemplate: '请帮我做一次情绪承受练习。\n我现在最强烈的情绪是：\n强度 0-10 分是：\n身体哪里有反应：\n我最想立刻做的冲动是：\n我希望先稳住自己，而不是马上行动：',
    ),
    'wish_integration': _DefenseCompassSceneSpec(
      label: '欲望整合',
      inputLabel: '写下一个你不太敢承认的愿望',
      outputMode: 'wish',
      deepSubtitle: '区分愿望、行动、价值和现实限制。',
      deepFields: <_DefenseCompassDeepFieldSpec>[
        _DefenseCompassDeepFieldSpec('这个愿望涉及谁', '这个愿望想从谁那里得到什么'),
        _DefenseCompassDeepFieldSpec('现实事实', '当前现实条件是什么'),
        _DefenseCompassDeepFieldSpec('承认愿望时的情绪', '例如：内疚、羞耻、害怕、兴奋'),
        _DefenseCompassDeepFieldSpec('身体反应', '承认它时身体如何变化'),
        _DefenseCompassDeepFieldSpec('我怕自己会做什么', '害怕冲动失控或被看见'),
        _DefenseCompassDeepFieldSpec('我不敢表达的是', '一句原始但真实的话'),
      ],
      inputTemplate: '请帮我做欲望整合。\n我可能真正想要的是：\n我觉得自己“不应该”想要它，因为：\n如果我承认这个愿望，我害怕：\n我的价值或现实限制是：\n我希望把它转化成一个成熟表达或小请求：',
    ),
    'self_limitation': _DefenseCompassSceneSpec(
      label: '自我限制',
      inputLabel: '写下一个你正在回避或放弃的领域',
      outputMode: 'self_limitation',
      deepSubtitle: '区分真的不喜欢，还是为了避免失败、比较或羞辱而退出。',
      deepFields: <_DefenseCompassDeepFieldSpec>[
        _DefenseCompassDeepFieldSpec('涉及的人/比较对象', '我会和谁比较，或怕谁评价'),
        _DefenseCompassDeepFieldSpec('已发生事实', '我实际回避/退出了什么'),
        _DefenseCompassDeepFieldSpec('想到这个领域的情绪', '羞耻、害怕、嫉妒、无力等'),
        _DefenseCompassDeepFieldSpec('身体反应', '一想到尝试，身体如何反应'),
        _DefenseCompassDeepFieldSpec('我最想逃开的后果', '例如：失败、丢脸、被嫉妒、被攻击'),
        _DefenseCompassDeepFieldSpec('我已经放弃/拖延了什么', '具体行动或机会'),
      ],
      inputTemplate: '请帮我分析一个自我限制场景。\n我正在回避/放弃的领域是：\n我表面上的理由是：\n我可能真正害怕的是：\n我曾经因为失败、比较或羞辱受过影响吗：\n我希望设计一个最小恢复行动：',
    ),
    'relationship_defense': _DefenseCompassSceneSpec(
      label: '关系防御',
      inputLabel: '写下一段关系冲突',
      outputMode: 'relationship',
      deepSubtitle: '关系场景重点区分对方事实、我的解释、投射、边界和需求。',
      deepFields: <_DefenseCompassDeepFieldSpec>[
        _DefenseCompassDeepFieldSpec('对方是谁', '伴侣、父母、朋友、同事、孩子等'),
        _DefenseCompassDeepFieldSpec('对方实际做了什么', '只写事实，不写“他就是……”'),
        _DefenseCompassDeepFieldSpec('我真正的情绪', '委屈、愤怒、害怕、嫉妒、失望等'),
        _DefenseCompassDeepFieldSpec('身体反应', '身体哪里紧、热、冷或想躲'),
        _DefenseCompassDeepFieldSpec('我想攻击/逃避/讨好的冲动', '最自动的关系反应'),
        _DefenseCompassDeepFieldSpec('我没有表达的需求/边界', '一句真实但尚未说出口的话'),
      ],
      inputTemplate: '请帮我分析一段关系防御。\n对方实际做了什么：\n我认为对方是什么意思：\n我有什么证据：\n我真正的情绪可能是：\n我真正的需求可能是：\n我希望生成一句不攻击、不讨好、不压抑的表达：',
    ),
    'altruistic_surrender': _DefenseCompassSceneSpec(
      label: '利他让渡',
      inputLabel: '写下一个“我总是在帮别人实现愿望，却很难为自己争取”的真实事件',
      outputMode: 'altruistic',
      deepSubtitle: '把“我替别人承担什么”与“我自己的被转移愿望”分开。',
      deepFields: <_DefenseCompassDeepFieldSpec>[
        _DefenseCompassDeepFieldSpec('这件事里涉及的人', '我正在帮助/推动/照顾谁'),
        _DefenseCompassDeepFieldSpec('我为对方承担/争取了什么', '具体做了什么，不评价好坏'),
        _DefenseCompassDeepFieldSpec('这件事是否也代表我的愿望', '我自己是否也想要类似东西'),
        _DefenseCompassDeepFieldSpec('为自己争取时的身体/情绪', '内疚、羞耻、害怕、自责或身体反应'),
        _DefenseCompassDeepFieldSpec('我如果为自己争取会害怕什么', '被说自私、被拒绝、失去关系等'),
        _DefenseCompassDeepFieldSpec('我最小可以收回的一点责任', '今天可以少承担/多表达的一点点'),
      ],
      inputTemplate: '请帮我分析一个“利他让渡”场景。\n我总是为别人承担/争取的是：\n这件事其实是否也是我自己的愿望：\n我为别人做这件事时的感受是：\n如果换成我为自己争取，我最害怕的是：\n我希望最后能得到一个小边界行动：',
    ),
    'transition': _DefenseCompassSceneSpec(
      label: '转折期',
      inputLabel: '写下你当前的人生转折或身份变化',
      outputMode: 'transition',
      deepSubtitle: '转折期重点看身份变化、本能强度、理智化、禁欲主义和稳定行动。',
      deepFields: <_DefenseCompassDeepFieldSpec>[
        _DefenseCompassDeepFieldSpec('转折涉及哪些人/环境', '毕业、换工作、分手、婚育、家庭变化等'),
        _DefenseCompassDeepFieldSpec('已经发生的变化', '客观变化是什么'),
        _DefenseCompassDeepFieldSpec('转折带来的主要情绪', '焦虑、兴奋、空虚、失控、悲伤等'),
        _DefenseCompassDeepFieldSpec('身体/生活节律变化', '睡眠、饮食、精力、身体紧张'),
        _DefenseCompassDeepFieldSpec('我反复想但没有行动的是', '抽象问题或卡住点'),
        _DefenseCompassDeepFieldSpec('我正在回避的具体下一步', '一个小现实选择或实验'),
      ],
      inputTemplate: '请帮我分析人生转折期中的防御。\n我正在经历的变化是：\n我最近最强烈的冲突是：\n我是否在理智化、禁欲或频繁认同：\n我最需要稳定下来的现实部分是：\n我希望设计一个身份探索小实验：',
    ),
    'family_education': _DefenseCompassSceneSpec(
      label: '家庭教育',
      inputLabel: '写下孩子/家庭中的一个具体行为场景',
      outputMode: 'family',
      deepSubtitle: '家庭教育场景避免简单贴标签，先理解孩子行为的防御功能。',
      deepFields: <_DefenseCompassDeepFieldSpec>[
        _DefenseCompassDeepFieldSpec('孩子/家庭成员', '年龄、关系、谁参与'),
        _DefenseCompassDeepFieldSpec('表面行为事实', '孩子实际做了什么'),
        _DefenseCompassDeepFieldSpec('孩子可能的情绪', '害怕、羞耻、嫉妒、失望、愤怒等'),
        _DefenseCompassDeepFieldSpec('身体/生活线索', '睡眠、食欲、哭闹、沉默、攻击等'),
        _DefenseCompassDeepFieldSpec('家长的自动反应', '想批评、惩罚、讲道理、放任、焦虑'),
        _DefenseCompassDeepFieldSpec('希望既保护又引导的地方', '你希望孩子发展哪种能力'),
      ],
      inputTemplate: '请从《自我与防御机制》的儿童/家庭教育视角分析。\n孩子/家庭成员的表面行为：\n发生场景：\n我目前的反应：\n这可能在保护孩子免受什么不快：\n我希望既不粗暴压制也不完全放任的回应是：',
    ),
    'monthly_review': _DefenseCompassSceneSpec(
      label: '月度复盘',
      inputLabel: '写下本月你最想复盘的主题',
      outputMode: 'monthly',
      deepSubtitle: '月度复盘会综合近期记录，也可以补充本月主题。',
      deepFields: _defaultDeepFields,
      inputTemplate: '请帮我做月度成长复盘。\n本月最常见的触发场景是：\n本月最常见的情绪是：\n我觉得自己重复出现的防御是：\n我完成过的现实行动是：\n下个月我最想练习的是：',
    ),
    'action_generation': _DefenseCompassSceneSpec(
      label: '行动生成',
      inputLabel: '写下你想转化为行动的困境',
      outputMode: 'action',
      deepSubtitle: '行动生成会把觉察转成低风险、可执行、可复盘的小行动。',
      deepFields: _defaultDeepFields,
      inputTemplate: '请帮我把这个困境转化为现实行动。\n我现在卡住的是：\n我已经理解到的防御/焦虑是：\n我害怕行动后发生的是：\n我希望行动足够小、可在 10 分钟内完成：',
    ),
    'action_review': _DefenseCompassSceneSpec(
      label: '行动复盘',
      inputLabel: '写下你完成、延后或跳过某个行动后的感受',
      outputMode: 'action_review',
      deepSubtitle: '行动复盘会检查防御是否松动、行动是否需要降级。',
      deepFields: _defaultDeepFields,
      inputTemplate: '请帮我复盘一个行动。\n原本的小行动是：\n我完成/延后/跳过了：\n行动前的情绪是：\n行动后的情绪是：\n我发现的防御变化是：\n下一步是否需要降级或调整：',
    ),
    'closure_audit': _DefenseCompassSceneSpec(
      label: '闭环审计',
      inputLabel: '写下你想检查这个模块是否帮助你形成闭环的地方',
      outputMode: 'closure',
      deepSubtitle: '闭环审计检查事件、分析、行动、复盘、档案、月报之间的断点。',
      deepFields: _defaultDeepFields,
      inputTemplate: '请帮我做自我防御罗盘闭环审计。\n我最近记录过的事件/分析是：\n我生成过但没有完成的行动是：\n我完成但没有复盘的行动是：\n我的个人防御地图是否需要更新：\n我希望得到下一步补齐动作：',
    ),
  };

  static const List<String> _quickInputs = <String>[
    '今天同事没有回复我消息，我马上觉得他是不是讨厌我。我表面说无所谓，但心里很焦虑，也有点生气。',
    '我明明想展示自己的作品，但看到别人做得更好就不想发了。我告诉自己是不感兴趣，其实好像怕丢脸。',
    '我总是帮朋友争取机会，可轮到自己开口要资源时就很内疚，好像那样很自私。',
    '我被领导批评后表面很冷静，回来一直想辞职。我说自己不在乎，但身体很紧。',
    '我最近一直在想人生意义和未来方向，但越想越不行动，很多具体事情都停住了。',
  ];


  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 11, vsync: this);
    _scene = _sceneSpecs.containsKey(widget.initialScene) ? widget.initialScene : 'event_analysis';
    final spec = _specFor(_scene);
    _outputMode = spec.outputMode;
    if (widget.initialInput.trim().isEmpty) {
      _lastAutoTemplate = spec.inputTemplate;
      _inputCtrl.text = spec.inputTemplate;
    } else {
      _lastAutoTemplate = '';
      _inputCtrl.text = widget.initialInput.trim();
    }
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _inputCtrl.dispose();
    _peopleCtrl.dispose();
    _factsCtrl.dispose();
    _emotionCtrl.dispose();
    _bodyCtrl.dispose();
    _impulseCtrl.dispose();
    _avoidedCtrl.dispose();
    _themesCtrl.dispose();
    _defensesCtrl.dispose();
    _triggersCtrl.dispose();
    _avoidCtrl.dispose();
    _relationCtrl.dispose();
    _supportCtrl.dispose();
    _safetyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _dao.ensureTables();
      final profile = await _dao.loadProfile();
      final sessions = await _dao.listSessions(limit: 120);
      final actions = await _dao.listActions(limit: 160);
      final reports = await _dao.listReports(limit: 36);
      final courseProgress = await _dao.listCourseProgress();
      final stats = await _dao.stats();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _sessions = sessions;
        _actions = actions;
        _reports = reports;
        _courseProgress = courseProgress;
        _stats = stats;
        _latest = sessions.isNotEmpty ? sessions.first : null;
        _themesCtrl.text = profile.currentThemes.join('，');
        _defensesCtrl.text = profile.commonDefenses;
        _triggersCtrl.text = profile.commonTriggers;
        _avoidCtrl.text = profile.avoidedDomains;
        _relationCtrl.text = profile.relationshipPatterns;
        _supportCtrl.text = profile.supportResources;
        _safetyCtrl.text = profile.safetyNotes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('自我防御罗盘加载失败：$e');
    }
  }

  Future<void> _saveProfile() async {
    final themes = _themesCtrl.text
        .split(RegExp(r'[,，;；\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    await _dao.saveProfile(DefenseCompassProfile(
      currentThemes: themes,
      commonDefenses: _defensesCtrl.text.trim(),
      commonTriggers: _triggersCtrl.text.trim(),
      avoidedDomains: _avoidCtrl.text.trim(),
      relationshipPatterns: _relationCtrl.text.trim(),
      supportResources: _supportCtrl.text.trim(),
      safetyNotes: _safetyCtrl.text.trim(),
    ));
    await _load();
    _toast('自我防御罗盘档案已保存');
  }

  String _composedInput() {
    final base = _inputCtrl.text.trim();
    final fields = _specFor(_scene).deepFields;
    String label(int index, String fallback) => index < fields.length ? fields[index].label : fallback;
    final parts = <String>[];
    if (base.isNotEmpty) parts.add('自由记录：$base');
    if (_peopleCtrl.text.trim().isNotEmpty) parts.add("${label(0, '涉及的人')}：${_peopleCtrl.text.trim()}");
    if (_factsCtrl.text.trim().isNotEmpty) parts.add("${label(1, '已确认事实')}：${_factsCtrl.text.trim()}");
    if (_emotionCtrl.text.trim().isNotEmpty) parts.add("${label(2, '显性情绪/强度')}：${_emotionCtrl.text.trim()}");
    if (_bodyCtrl.text.trim().isNotEmpty) parts.add("${label(3, '身体反应')}：${_bodyCtrl.text.trim()}");
    if (_impulseCtrl.text.trim().isNotEmpty) parts.add("${label(4, '当时冲动')}：${_impulseCtrl.text.trim()}");
    if (_avoidedCtrl.text.trim().isNotEmpty) parts.add("${label(5, '我没有做/回避了什么')}：${_avoidedCtrl.text.trim()}");
    return parts.isEmpty ? base : parts.join('\n');
  }


  bool _hasStructuredRecord() =>
      _peopleCtrl.text.trim().isNotEmpty ||
      _factsCtrl.text.trim().isNotEmpty ||
      _emotionCtrl.text.trim().isNotEmpty ||
      _bodyCtrl.text.trim().isNotEmpty ||
      _impulseCtrl.text.trim().isNotEmpty ||
      _avoidedCtrl.text.trim().isNotEmpty;

  Future<void> _generate({String? forceScene, String? forceInput, String? forceOutputMode}) async {
    if (_generating) return;
    final input = (forceInput ?? _composedInput()).trim();
    if (input.isEmpty) {
      _toast('请先写下一个真实事件、情绪、关系或行动困难。');
      return;
    }
    final scene = forceScene ?? ((_hasStructuredRecord() && _scene == 'event_analysis') ? 'deep_event_record' : _scene);
    final mode = forceOutputMode ?? _outputMode;
    setState(() => _generating = true);
    try {
      final recent = await _dao.recentContextJson();
      final record = await _ai.generate(
        scene: scene,
        userInput: input,
        profile: _profile,
        recentContextJson: recent,
        outputMode: mode,
      );
      await _dao.insertSession(record);
      await _load();
      if (!mounted) return;
      _tabs.animateTo(_tabAnalysis);
    } catch (e) {
      _toast('AI 分析失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _monthlyReview() async {
    final context = await _dao.recentContextJson(limit: 40);
    await _generate(
      forceScene: 'monthly_review',
      forceOutputMode: 'monthly',
      forceInput: '请基于以下自我防御罗盘近期记录生成月度成长报告：$context',
    );
  }

  Future<void> _profileUpdateSuggestion() async {
    final context = await _dao.recentContextJson(limit: 60);
    await _generate(
      forceScene: 'profile_update',
      forceOutputMode: 'profile',
      forceInput: '请基于以下自我防御罗盘近期记录，生成个人防御地图更新建议，但不要自动改写档案：$context',
    );
  }

  Future<void> _closureAudit() async {
    final context = await _dao.recentContextJson(limit: 80);
    await _generate(
      forceScene: 'closure_audit',
      forceOutputMode: 'closure',
      forceInput: '请基于以下自我防御罗盘数据做产品闭环审计，指出事件、分析、行动、复盘、档案、月报中还缺什么，并给下一步补齐动作：$context',
    );
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空自我防御罗盘数据？'),
        content: const Text('将删除该独立模块中的事件分析、行动与档案；不影响其他模块。此操作不可恢复。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok == true) {
      await _dao.clearAll();
      await _load();
      _toast('已清空自我防御罗盘数据');
    }
  }

  void _openPromptSettings() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const AiPromptSettingsPage(
        initialModuleId: DefenseCompassPromptConfig.moduleId,
        initialPromptId: DefenseCompassPromptConfig.globalId,
      ),
    ));
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  _DefenseCompassSceneSpec _specFor(String scene) => _sceneSpecs[scene] ?? _sceneSpecs['event_analysis']!;

  bool _isAutoTemplateText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return true;
    if (_lastAutoTemplate.trim().isNotEmpty && trimmed == _lastAutoTemplate.trim()) return true;
    if (_quickInputs.any((q) => q.trim() == trimmed)) return true;
    return _sceneSpecs.values.any((spec) => spec.inputTemplate.trim() == trimmed);
  }

  void _applySceneRoute(
    String scene, {
    String? inputTemplate,
    String? outputMode,
    bool replaceInput = true,
    bool appendInput = false,
  }) {
    final spec = _specFor(scene);
    final template = inputTemplate ?? spec.inputTemplate;
    setState(() {
      _scene = scene;
      _outputMode = outputMode ?? spec.outputMode;
      if (!_outputLabels.containsKey(_outputMode)) {
        _outputMode = spec.outputMode;
      }
      if (replaceInput) {
        _lastAutoTemplate = template;
        _inputCtrl.text = template;
      } else if (appendInput) {
        final current = _inputCtrl.text.trimRight();
        final merged = current.isEmpty ? template : '$current\n\n--- ${spec.label}模板 ---\n$template';
        _lastAutoTemplate = '';
        _inputCtrl.text = merged;
      }
    });
  }

  Future<void> _selectScene(String scene) async {
    if (scene == _scene) return;
    final spec = _specFor(scene);
    final current = _inputCtrl.text;
    if (_isAutoTemplateText(current)) {
      _applySceneRoute(scene);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('切换到“${spec.label}”？'),
        content: const Text('当前输入框里已有你编辑过的内容。为了避免误删，可以保留、替换为新场景模板，或把新模板追加到当前内容后面。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, 'keep'), child: const Text('保留当前内容')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'append'), child: const Text('追加模板')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'replace'), child: const Text('替换为模板')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'replace') {
      _applySceneRoute(scene);
    } else if (choice == 'append') {
      _applySceneRoute(scene, replaceInput: false, appendInput: true);
    } else {
      setState(() {
        _scene = scene;
        _outputMode = spec.outputMode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      appBar: AppBar(
        title: const Text('自我防御罗盘'),
        backgroundColor: const Color(0xFFF8F6F1),
        surfaceTintColor: Colors.transparent,
        actions: <Widget>[
          IconButton(onPressed: _openPromptSettings, tooltip: 'AI Prompt', icon: const Icon(Icons.tune_outlined)),
          IconButton(onPressed: _loading ? null : _load, tooltip: '刷新', icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const <Tab>[
            Tab(text: '罗盘'),
            Tab(text: '分析'),
            Tab(text: '训练'),
            Tab(text: '行动'),
            Tab(text: '防御库'),
            Tab(text: '关系'),
            Tab(text: '转折/家庭'),
            Tab(text: '课程'),
            Tab(text: '仪表盘'),
            Tab(text: '档案'),
            Tab(text: '安全'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: <Widget>[
                _buildCompassTab(),
                _buildAnalysisTab(),
                _buildTrainingTab(),
                _buildActionTab(),
                _buildDefenseLibraryTab(),
                _buildRelationshipTab(),
                _buildTransitionFamilyTab(),
                _buildCourseTab(),
                _buildStatsTab(),
                _buildProfileTab(),
                _buildSafetyTab(),
              ],
            ),
    );
  }

  Widget _buildCompassTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _heroCard(),
        const SizedBox(height: 12),
        _sectionCard(
          title: '今日自我罗盘',
          subtitle: '从真实事件进入：看见愿望、禁令、现实压力与防御。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sceneLabels.entries.map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _scene == e.key,
                      onSelected: (_) { _selectScene(e.key); },
                    )).toList(growable: false),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _outputMode,
                decoration: const InputDecoration(labelText: '输出卡片格式', border: OutlineInputBorder()),
                items: _outputLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(growable: false),
                onChanged: (v) => setState(() => _outputMode = v ?? 'standard'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _inputCtrl,
                minLines: 6,
                maxLines: 12,
                decoration: InputDecoration(
                  labelText: _specFor(_scene).inputLabel,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('深度结构化记录（可选）· ${_specFor(_scene).label}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(_specFor(_scene).deepSubtitle),
                children: <Widget>[
                  _textField(_peopleCtrl, _specFor(_scene).deepFields[0].label, _specFor(_scene).deepFields[0].hint),
                  _textField(_factsCtrl, _specFor(_scene).deepFields[1].label, _specFor(_scene).deepFields[1].hint),
                  _textField(_emotionCtrl, _specFor(_scene).deepFields[2].label, _specFor(_scene).deepFields[2].hint),
                  _textField(_bodyCtrl, _specFor(_scene).deepFields[3].label, _specFor(_scene).deepFields[3].hint),
                  _textField(_impulseCtrl, _specFor(_scene).deepFields[4].label, _specFor(_scene).deepFields[4].hint),
                  _textField(_avoidedCtrl, _specFor(_scene).deepFields[5].label, _specFor(_scene).deepFields[5].hint),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickInputs.map((q) => ActionChip(
                      label: Text(q.length > 20 ? '${q.substring(0, 20)}…' : q),
                      onPressed: () => setState(() { _lastAutoTemplate = q; _inputCtrl.text = q; }),
                    )).toList(growable: false),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _generating ? null : _generate,
                      icon: _generating
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.psychology_alt_outlined),
                      label: Text(_generating ? '分析中…' : '生成自我防御分析'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(onPressed: _monthlyReview, icon: const Icon(Icons.summarize_outlined), label: const Text('月报')),
                ],
              ),
            ],
          ),
        ),
        if (_latest != null) ...<Widget>[
          const SizedBox(height: 12),
          _sessionCard(_latest!, compact: true),
        ],
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2F2A24),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.explore_outlined, color: Colors.white, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '基于《自我与防御机制》的 AI 自我整合训练系统',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '看见防御，不羞辱自己；理解防御，不被防御控制。每次练习都从现实事件出发，经过焦虑来源、防御假设、保护/代价分析，最后落到一个小行动。',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <Widget>[
              _LightChip('自我三方地图'),
              _LightChip('防御动机引擎'),
              _LightChip('现实检验'),
              _LightChip('情绪承受'),
              _LightChip('现实行动'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisTab() {
    if (_sessions.isEmpty) {
      return _emptyState('还没有分析记录', '先在“罗盘”页输入一个真实事件，生成第一张自我防御分析卡。');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _sessionCard(_sessions[i]),
    );
  }

  Widget _sessionCard(DefenseCompassSession s, {bool compact = false}) {
    final time = DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(s.createdAtMs));
    return _sectionCard(
      title: '${_sceneLabels[s.scene] ?? s.scene} · $time',
      subtitle: s.eventSummary,
      trailing: _riskPill(s.riskLevel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _chipWrap('情绪', s.emotions),
          _chipWrap('隐性情绪', s.hiddenEmotions),
          _chipWrap('本我愿望', s.idWishes),
          _chipWrap('超我禁令', s.superegoProhibitions),
          _kv('主要焦虑来源', s.primaryAnxietySource),
          _chipWrap('可能防御', s.defenseMechanisms),
          if (!compact) ...<Widget>[
            _kv('事实', s.facts),
            _kv('解释', s.interpretation),
            _kv('外部现实', s.externalReality),
            _kv('保护功能', s.protectiveFunction),
            _kv('长期代价', s.longTermCost),
            _kv('现实检验', s.realityCheck),
          ],
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFFBF3), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE7DCC9))),
            child: Text(s.aiResponse.trim().isEmpty ? s.microAction : s.aiResponse, style: const TextStyle(height: 1.45)),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(child: Text('小行动：${s.microAction}', style: const TextStyle(fontWeight: FontWeight.w600))),
              IconButton(onPressed: () => _copyToInput(s.userInput), icon: const Icon(Icons.edit_note_outlined), tooltip: '复制到输入框'),
            ],
          ),
        ],
      ),
    );
  }

  void _copyToInput(String text) {
    _tabs.animateTo(_tabCompass);
    setState(() {
      _lastAutoTemplate = '';
      _inputCtrl.text = text;
    });
  }


  Widget _buildTrainingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _sectionCard(
          title: '现实行动训练中心',
          subtitle: '把终极产品方案中的七类现实行动落成可点击训练：现实检验、情绪承受、欲望整合、边界、能力恢复、关系修复、转折期稳定。',
          child: const Text('选择一个训练，系统会自动切换到对应场景、输出格式和输入模板；你可以直接生成 AI 引导，也可以先手动补充真实事件。', style: TextStyle(height: 1.45)),
        ),
        const SizedBox(height: 12),
        ...DefenseCompassContent.trainings.map((t) => _trainingCard(t)),
      ],
    );
  }

  Widget _trainingCard(DefenseCompassTrainingItem t) {
    return _sectionCard(
      title: t.title,
      subtitle: t.subtitle,
      trailing: Chip(label: Text(_actionTypeLabel(t.actionType))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _kv('完成标准', t.doneStandard),
          _kv('复盘问题', t.reviewQuestion),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () => _startTraining(t),
                icon: const Icon(Icons.play_arrow_outlined),
                label: const Text('开始训练'),
              ),
              OutlinedButton.icon(
                onPressed: () => _addActionFromTemplate(t),
                icon: const Icon(Icons.add_task_outlined),
                label: const Text('加入行动清单'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _startTraining(DefenseCompassTrainingItem t) {
    _tabs.animateTo(_tabCompass);
    _applySceneRoute(t.scene, inputTemplate: t.promptSeed, outputMode: t.outputMode);
  }

  Future<void> _addActionFromTemplate(DefenseCompassTrainingItem t) async {
    await _dao.insertAction(DefenseCompassAction(
      actionType: t.actionType,
      actionText: '${t.title}：${t.doneStandard}',
      difficulty: 'low',
      status: 'open',
    ));
    await _load();
    _toast('已加入行动清单：${t.title}');
    _tabs.animateTo(_tabAction);
  }

  Future<void> _createManualAction() async {
    final textCtrl = TextEditingController();
    var type = 'reality_check';
    var difficulty = 'low';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('新增现实行动'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: '行动类型'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'reality_check', child: Text('现实检验')),
                    DropdownMenuItem(value: 'affect_tolerance', child: Text('情绪承受')),
                    DropdownMenuItem(value: 'wish_integration', child: Text('欲望整合')),
                    DropdownMenuItem(value: 'boundary', child: Text('边界行动')),
                    DropdownMenuItem(value: 'capacity_recovery', child: Text('能力恢复')),
                    DropdownMenuItem(value: 'relationship_repair', child: Text('关系修复')),
                    DropdownMenuItem(value: 'transition_experiment', child: Text('转折期实验')),
                  ],
                  onChanged: (v) => setLocal(() => type = v ?? 'reality_check'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: difficulty,
                  decoration: const InputDecoration(labelText: '难度'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'low', child: Text('低：5-10分钟')),
                    DropdownMenuItem(value: 'medium', child: Text('中：需要一点勇气')),
                    DropdownMenuItem(value: 'high', child: Text('高：建议拆小')),
                  ],
                  onChanged: (v) => setLocal(() => difficulty = v ?? 'low'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: textCtrl,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: '行动内容', hintText: '例如：写下事实/猜测各3条，再向对方确认一个低风险事实。', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
          ],
        ),
      ),
    );
    if (saved == true && textCtrl.text.trim().isNotEmpty) {
      await _dao.insertAction(DefenseCompassAction(actionType: type, actionText: textCtrl.text.trim(), difficulty: difficulty, status: 'open'));
      await _load();
      _toast('已新增现实行动');
    }
  }

  Widget _buildActionTab() {
    final open = _actions.where((a) => a.status == 'open' || a.status == 'deferred').toList(growable: false);
    final done = _actions.where((a) => a.status == 'completed').toList(growable: false);
    final skipped = _actions.where((a) => a.status == 'skipped').toList(growable: false);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _sectionCard(
          title: '现实行动转化系统',
          subtitle: '分析必须落到行动：现实检验、情绪承受、愿望表达、边界、能力恢复、关系修复。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(label: Text('现实检验')),
                  Chip(label: Text('情绪承受')),
                  Chip(label: Text('欲望表达')),
                  Chip(label: Text('边界行动')),
                  Chip(label: Text('能力恢复')),
                  Chip(label: Text('关系修复')),
                  Chip(label: Text('转折实验')),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: _createManualAction, icon: const Icon(Icons.add_outlined), label: const Text('手动新增行动')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (open.isEmpty) _emptyInline('当前没有待完成行动。生成分析后，小行动会自动进入这里。'),
        ...open.map(_actionTile),
        const SizedBox(height: 12),
        _sectionTitle('已完成行动'),
        if (done.isEmpty) _emptyInline('完成行动后会在这里形成身份与现实证据。'),
        ...done.map(_actionTile),
        const SizedBox(height: 12),
        _sectionTitle('已跳过 / 暂不适合行动'),
        if (skipped.isEmpty) _emptyInline('如果某个行动暂时不安全或过大，可以标记为跳过，并在复盘中写下原因。'),
        ...skipped.map(_actionTile),
      ],
    );
  }

  Widget _actionTile(DefenseCompassAction a) {
    final done = a.status == 'completed';
    final skipped = a.status == 'skipped';
    final deferred = a.status == 'deferred';
    final bg = done
        ? const Color(0xFFEFF7EF)
        : skipped
            ? const Color(0xFFF4F0EA)
            : deferred
                ? const Color(0xFFFFF7E6)
                : Colors.white;
    return Card(
      elevation: 0,
      color: bg,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: done ? const Color(0xFFCFE6CF) : const Color(0xFFE6DED2))),
      child: ListTile(
        leading: Checkbox(value: done, onChanged: (_) => _toggleAction(a)),
        title: Text(a.actionText, style: TextStyle(decoration: done || skipped ? TextDecoration.lineThrough : null)),
        subtitle: Text('${_actionTypeLabel(a.actionType)} · ${_actionStatusLabel(a.status)} · 难度 ${a.difficulty}${a.afterEmotion.trim().isEmpty ? '' : '；完成后情绪：${a.afterEmotion}'}${a.reflection.trim().isEmpty ? '' : '；复盘：${a.reflection}'}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'review') {
              await _reviewAction(a);
            } else {
              await _dao.updateAction(a.copyWith(status: value));
              await _load();
            }
          },
          itemBuilder: (_) => const <PopupMenuEntry<String>>[
            PopupMenuItem(value: 'review', child: Text('复盘')),
            PopupMenuItem(value: 'open', child: Text('设为待行动')),
            PopupMenuItem(value: 'completed', child: Text('设为已完成')),
            PopupMenuItem(value: 'deferred', child: Text('设为延后')),
            PopupMenuItem(value: 'skipped', child: Text('设为跳过')),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAction(DefenseCompassAction a) async {
    await _dao.updateAction(a.copyWith(status: a.status == 'completed' ? 'open' : 'completed'));
    await _load();
  }

  Future<void> _reviewAction(DefenseCompassAction a) async {
    final ctrl = TextEditingController(text: a.reflection);
    final emotionCtrl = TextEditingController(text: a.afterEmotion);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('行动复盘'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(controller: ctrl, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: '完成后发生了什么？防御有没有松动一点？')),
            const SizedBox(height: 8),
            TextField(controller: emotionCtrl, decoration: const InputDecoration(labelText: '完成后的情绪')),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (saved == true) {
      await _dao.updateAction(a.copyWith(reflection: ctrl.text.trim(), afterEmotion: emotionCtrl.text.trim(), status: 'completed'));
      await _load();
    }
  }

  Widget _buildDefenseLibraryTab() {
    final grouped = <String, List<DefenseCompassLibraryItem>>{};
    for (final item in DefenseCompassContent.defenses) {
      grouped.putIfAbsent(item.group, () => <DefenseCompassLibraryItem>[]).add(item);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _sectionCard(
          title: '防御机制库 · 保护功能 × 现实代价 × 替代练习',
          subtitle: '覆盖《自我与防御机制》终极版产品方案中的内部冲突、外部现实、关系防御和发展阶段四大类机制。',
          child: const Text('点击任一机制，可把它带入 AI 防御识别场景；这里的机制不是诊断标签，而是帮助观察自我如何保护自己的假设。', style: TextStyle(height: 1.45)),
        ),
        const SizedBox(height: 12),
        ...grouped.entries.map((entry) => _sectionCard(
              title: entry.key,
              subtitle: '每个机制都显示：出现信号、保护功能、长期代价和现实练习。',
              child: Column(
                children: entry.value.map(_defenseLibraryTile).toList(growable: false),
              ),
            )),
      ],
    );
  }

  Widget _defenseLibraryTile(DefenseCompassLibraryItem item) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(item.oneLine),
      childrenPadding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
      children: <Widget>[
        _kv('出现信号', item.signals),
        _kv('保护了什么', item.protects),
        _kv('可能限制什么', item.costs),
        _kv('替代练习', item.practice),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () {
                  _tabs.animateTo(_tabCompass);
                  _applySceneRoute(
                    item.scene,
                    outputMode: item.outputMode,
                    inputTemplate: item.sampleInput.isEmpty ? '我想检查自己是否可能存在“${item.name}”这种防御。最近的具体事件是：' : item.sampleInput,
                  );
                },
                icon: const Icon(Icons.psychology_alt_outlined),
                label: const Text('用 AI 分析'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await _dao.insertAction(DefenseCompassAction(actionType: _inferActionTypeFromScene(item.scene), actionText: '${item.name}练习：${item.practice}', difficulty: 'low', status: 'open'));
                  await _load();
                  _toast('已加入行动：${item.name}练习');
                },
                icon: const Icon(Icons.add_task_outlined),
                label: const Text('加入练习'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _inferActionTypeFromScene(String scene) {
    if (scene == 'reality_check') return 'reality_check';
    if (scene == 'affect_tolerance') return 'affect_tolerance';
    if (scene == 'wish_integration') return 'wish_integration';
    if (scene == 'self_limitation') return 'capacity_recovery';
    if (scene == 'relationship_defense') return 'relationship_repair';
    if (scene == 'altruistic_surrender') return 'boundary';
    if (scene == 'transition') return 'transition_experiment';
    return 'micro_action';
  }

  Widget _buildRelationshipTab() {
    final cards = <Map<String, String>>[
      <String, String>{
        'title': '投射检查器',
        'subtitle': '把“他一定……”拆成事实、猜测、我的情绪与可验证信息。',
        'scene': 'relationship_defense',
        'mode': 'relationship',
        'input': '请帮我做关系中的投射检查。\n对方实际做了什么：\n我认为对方是什么意思：\n我有什么证据：\n我担心自己真正的情绪/需求是：',
      },
      <String, String>{
        'title': '认同攻击者检查',
        'subtitle': '检查我是否正在用曾经伤害我的方式对待别人。',
        'scene': 'relationship_defense',
        'mode': 'relationship',
        'input': '请帮我检查是否存在认同攻击者。\n我害怕/讨厌的对象是：\n我现在对别人做了什么：\n这是否像对方曾经对我的方式：',
      },
      <String, String>{
        'title': '利他性让渡与边界',
        'subtitle': '把交给别人的愿望收回一点点。',
        'scene': 'altruistic_surrender',
        'mode': 'altruistic',
        'input': '请帮我分析利他性让渡。\n我总是为别人争取的是：\n这些是否也是我自己的愿望：\n我为自己争取时最内疚的是：',
      },
      <String, String>{
        'title': '关系沟通句生成',
        'subtitle': '生成不攻击、不讨好、不压抑的表达。',
        'scene': 'relationship_defense',
        'mode': 'relationship',
        'input': '请帮我生成一句关系沟通话。\n事实：\n我的感受：\n我的需求：\n我想设置的边界：',
      },
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _sectionCard(
          title: '关系防御工作台',
          subtitle: '覆盖产品方案中的投射、认同攻击者、利他性让渡、关系沟通和边界练习。',
          child: const Text('关系中的防御往往不是“谁有病”，而是自我在处理依赖、敌意、嫉妒、罪疚和失爱恐惧。这里先区分事实与猜测，再转成可表达的话。', style: TextStyle(height: 1.45)),
        ),
        const SizedBox(height: 12),
        ...cards.map((c) => _shortcutCard(c)),
      ],
    );
  }

  Widget _buildTransitionFamilyTab() {
    final cards = <Map<String, String>>[
      <String, String>{
        'title': '人生转折期分析',
        'subtitle': '毕业、分手、换工作、中年、婚育、更年期等阶段的自我重组。',
        'scene': 'transition',
        'mode': 'transition',
        'input': '请帮我分析人生转折期中的防御。\n我正在经历的变化：\n我最近最强烈的冲突：\n我反复思考但没有行动的是：',
      },
      <String, String>{
        'title': '理智化落地',
        'subtitle': '把抽象人生问题落到一个 10 分钟现实实验。',
        'scene': 'transition',
        'mode': 'transition',
        'input': '请帮我把理智化落地。\n我反复想的抽象问题是：\n背后可能的情绪是：\n今天能做的最小实验是：',
      },
      <String, String>{
        'title': '禁欲主义检查',
        'subtitle': '区分价值性节制和对所有享乐/身体需求的恐惧。',
        'scene': 'transition',
        'mode': 'transition',
        'input': '请帮我检查禁欲主义。\n我最近拒绝的享受/身体需求是：\n我害怕它会带来的后果：\n一个安全照顾动作可能是：',
      },
      <String, String>{
        'title': '儿童/家庭教育防御理解',
        'subtitle': '理解孩子的否认、自我限制和认同攻击者，不粗暴压制也不完全放任。',
        'scene': 'family_education',
        'mode': 'family',
        'input': '请从《自我与防御机制》的儿童防御视角分析。\n孩子的表面行为：\n发生场景：\n家长目前的反应：\n我希望既保护又引导孩子的是：',
      },
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _sectionCard(
          title: '青春期 / 人生转折 / 家庭教育',
          subtitle: '把发展阶段原则落地：同一防御在儿童、青春期、成人和转折期中的意义不同。',
          child: const Text('本区不是诊断儿童或成人，而是帮助看见阶段压力、本能强度变化、身份摇摆、理智化、禁欲主义与家庭回应方式。', style: TextStyle(height: 1.45)),
        ),
        const SizedBox(height: 12),
        ...cards.map((c) => _shortcutCard(c)),
      ],
    );
  }

  Widget _shortcutCard(Map<String, String> c) {
    return _sectionCard(
      title: c['title'] ?? '',
      subtitle: c['subtitle'] ?? '',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          FilledButton.icon(
            onPressed: () {
              _tabs.animateTo(_tabCompass);
              _applySceneRoute(
                c['scene'] ?? 'event_analysis',
                outputMode: c['mode'] ?? _specFor(c['scene'] ?? 'event_analysis').outputMode,
                inputTemplate: c['input'] ?? _specFor(c['scene'] ?? 'event_analysis').inputTemplate,
              );
            },
            icon: const Icon(Icons.psychology_alt_outlined),
            label: const Text('进入 AI 引导'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await _dao.insertAction(DefenseCompassAction(actionType: _inferActionTypeFromScene(c['scene'] ?? ''), actionText: "${c['title']}：补充真实事件并完成一次 AI 引导。", difficulty: 'low', status: 'open'));
              await _load();
              _toast("已加入行动：${c['title']}");
            },
            icon: const Icon(Icons.add_task_outlined),
            label: const Text('加入行动'),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: DefenseCompassContent.courseCards.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        if (i == 0) {
          return _sectionCard(
            title: '课程进度闭环',
            subtitle: '学习不是停在概念，而是每节课都可转成一个现实练习，并记录完成进度。',
            child: Text('已完成 ${_stats.completedCourseCount}/${DefenseCompassContent.courseCards.length} 节。每节课可以标记完成，也可以一键生成“课程案例转练习”AI 引导。', style: const TextStyle(height: 1.45)),
          );
        }
        final index = i - 1;
        final c = DefenseCompassContent.courseCards[index];
        final courseId = 'course_${index + 1}_${c.title.hashCode}';
        final progress = _courseProgress[courseId];
        final done = progress?.completed == true;
        return _sectionCard(
          title: '${index + 1}. ${c.title}',
          subtitle: c.subtitle,
          trailing: Chip(label: Text(done ? '已完成' : '未完成')),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(c.body, style: const TextStyle(height: 1.45)),
              const SizedBox(height: 10),
              ...c.practices.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[const Text('• '), Expanded(child: Text(p))]),
                  )),
              if ((progress?.note ?? '').trim().isNotEmpty) _kv('学习备注', progress!.note),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () => _coursePractice(index, c),
                    icon: const Icon(Icons.psychology_alt_outlined),
                    label: const Text('转成现实练习'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _toggleCourseProgress(courseId, done, c),
                    icon: Icon(done ? Icons.undo_outlined : Icons.check_circle_outline),
                    label: Text(done ? '取消完成' : '标记完成'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _coursePractice(int index, DefenseCompassCourseCard c) async {
    await _generate(
      forceScene: 'course_practice',
      forceOutputMode: 'action',
      forceInput: '''请把《自我与防御机制》课程第 ${index + 1} 节“${c.title}”转化为我的现实行动练习。
课程要点：${c.subtitle}
内容：${c.body}
练习方向：${c.practices.join('；')}
请输出一个足够小、可执行、可复盘的行动。''',
    );
  }

  Future<void> _toggleCourseProgress(String courseId, bool done, DefenseCompassCourseCard c) async {
    await _dao.upsertCourseProgress(DefenseCompassCourseProgress(
      courseId: courseId,
      completed: !done,
      note: done ? '' : '已学习：${c.title}；下一步可转成现实练习。',
    ));
    await _load();
    _toast(done ? '已取消完成' : '课程已标记完成');
  }

  Widget _buildStatsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _sectionCard(
          title: '长期模式仪表盘',
          subtitle: '不是评价好坏，而是观察防御是否更灵活、行动是否恢复。',
          child: Row(
            children: <Widget>[
              Expanded(child: _statBox('分析', _stats.sessionCount.toString())),
              Expanded(child: _statBox('行动', _stats.actionCount.toString())),
              Expanded(child: _statBox('完成', _stats.completedActionCount.toString())),
              Expanded(child: _statBox('报告', _stats.reportCount.toString())),
              Expanded(child: _statBox('课程', '${_stats.completedCourseCount}/${DefenseCompassContent.courseCards.length}')),
              Expanded(child: _statBox('完成率', _stats.actionCount == 0 ? '0%' : '${((_stats.completedActionCount / _stats.actionCount) * 100).round()}%')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _countCard('常见防御机制', _stats.defenseCounts),
        const SizedBox(height: 12),
        _countCard('主要焦虑来源', _stats.anxietyCounts),
        const SizedBox(height: 12),
        _countCard('使用场景', _stats.sceneCounts.map((k, v) => MapEntry(_sceneLabels[k] ?? k, v))),
        const SizedBox(height: 12),
        _countCard('行动类型', _stats.actionTypeCounts.map((k, v) => MapEntry(_actionTypeLabel(k), v))),
        const SizedBox(height: 12),
        _countCard('行动状态', _stats.actionStatusCounts.map((k, v) => MapEntry(_actionStatusLabel(k), v))),
        const SizedBox(height: 12),
        _buildReportsPanel(),
        const SizedBox(height: 12),
        _buildClosedLoopPanel(),
        const SizedBox(height: 12),
        _sectionCard(
          title: '成长指标说明',
          subtitle: '终极产品方案中的核心指标。',
          child: const Text('重点观察：现实检验次数、情绪承受练习、愿望表达、边界行动、能力恢复、关系修复和行动完成率。数值不是评分，而是自我逐渐扩大选择的证据。', style: TextStyle(height: 1.45)),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _monthlyReview, icon: const Icon(Icons.summarize_outlined), label: const Text('基于近期记录生成月度成长报告')),
      ],
    );
  }

  Widget _countCard(String title, Map<String, int> data) {
    return _sectionCard(
      title: title,
      subtitle: data.isEmpty ? '暂无数据' : '按最近记录统计',
      child: data.isEmpty
          ? _emptyInline('积累更多分析后，这里会显示长期模式。')
          : Column(
              children: data.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: <Widget>[
                        Expanded(child: Text(e.key)),
                        SizedBox(width: 160, child: LinearProgressIndicator(value: e.value / (data.values.first <= 0 ? 1 : data.values.first))),
                        const SizedBox(width: 8),
                        Text('${e.value}'),
                      ],
                    ),
                  )).toList(growable: false),
            ),
    );
  }

  Future<void> _autoFillProfileFromStats() async {
    final topDefenses = _stats.defenseCounts.keys.take(5).join('，');
    final topTriggers = _sessions.map((s) => s.facts.trim().isEmpty ? s.eventSummary : s.facts).where((e) => e.trim().isNotEmpty).take(5).join('\n');
    final topAnxiety = _stats.anxietyCounts.keys.take(3).join('，');
    final relation = _sessions
        .where((s) => s.scene == 'relationship_defense' || s.scene == 'altruistic_surrender')
        .map((s) => s.eventSummary)
        .where((e) => e.trim().isNotEmpty)
        .take(4)
        .join('\n');
    final avoided = _sessions
        .where((s) => s.scene == 'self_limitation' || s.defenseMechanisms.any((d) => d.contains('自我限制')))
        .map((s) => s.longTermCost.trim().isEmpty ? s.eventSummary : s.longTermCost)
        .where((e) => e.trim().isNotEmpty)
        .take(4)
        .join('\n');
    setState(() {
      if (topDefenses.isNotEmpty) _defensesCtrl.text = topDefenses;
      if (topTriggers.isNotEmpty) _triggersCtrl.text = topTriggers;
      if (avoided.isNotEmpty) _avoidCtrl.text = avoided;
      if (relation.isNotEmpty) _relationCtrl.text = relation;
      if (topAnxiety.isNotEmpty) _themesCtrl.text = topAnxiety;
    });
    await _saveProfile();
  }

  Widget _buildReportsPanel() {
    return _sectionCard(
      title: '月度/阶段成长报告库',
      subtitle: _reports.isEmpty ? '暂无已保存报告' : '月报会在生成后自动保存为独立模块报告记录。',
      child: _reports.isEmpty
          ? _emptyInline('点击下方“生成月度成长报告”后，报告会出现在这里。')
          : Column(
              children: _reports.take(6).map((r) => ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(r.title.trim().isEmpty ? '月度成长报告' : r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${r.periodLabel} · ${DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(r.createdAtMs))}'),
                    children: <Widget>[
                      Align(alignment: Alignment.centerLeft, child: Text(r.content, style: const TextStyle(height: 1.45))),
                    ],
                  )).toList(growable: false),
            ),
    );
  }

  Widget _buildClosedLoopPanel() {
    final open = _actions.where((a) => a.status == 'open').length;
    final completed = _actions.where((a) => a.status == 'completed').length;
    final reviewed = _actions.where((a) => a.reflection.trim().isNotEmpty).length;
    final profileAge = _profile.updatedAtMs == 0 ? '未保存' : DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(_profile.updatedAtMs));
    return _sectionCard(
      title: '产品闭环覆盖检查',
      subtitle: '事件 → 分析 → 行动 → 复盘 → 档案更新 → 月报，全部在独立模块内闭环。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _kv('1. 事件与分析记录', '${_sessions.length} 条'),
          _kv('2. 待行动', '$open 条'),
          _kv('3. 已完成行动', '$completed 条'),
          _kv('4. 已复盘行动', '$reviewed 条'),
          _kv('5. 个人防御地图更新时间', profileAge),
          _kv('6. 已保存报告', '${_reports.length} 份'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(onPressed: _profileUpdateSuggestion, icon: const Icon(Icons.map_outlined), label: const Text('生成档案更新建议')),
              OutlinedButton.icon(onPressed: _monthlyReview, icon: const Icon(Icons.summarize_outlined), label: const Text('生成月报')),
              OutlinedButton.icon(onPressed: _closureAudit, icon: const Icon(Icons.fact_check_outlined), label: const Text('闭环审计')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _sectionCard(
          title: '个人防御地图',
          subtitle: '这些信息只服务于本独立模块，让 AI 更了解你的常见模式。',
          child: Column(
            children: <Widget>[
              _textField(_themesCtrl, '当前主题', '例如：关系投射、害怕失败、过度自责'),
              _textField(_defensesCtrl, '常见防御', '例如：投射、自我限制、理智化、转向自身'),
              _textField(_triggersCtrl, '常见触发', '例如：被批评、被忽视、被比较、权威压力'),
              _textField(_avoidCtrl, '回避/能力受限领域', '例如：公开表达、竞争、亲密、谈钱、创作'),
              _textField(_relationCtrl, '关系模式', '例如：为别人争取、自己沉默；害怕被控制所以先控制'),
              _textField(_supportCtrl, '支持资源', '可信任的人、专业资源、稳定练习'),
              _textField(_safetyCtrl, '安全备注', '不用于诊断，仅记录需要避免的高风险触发或支持方式'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(onPressed: _saveProfile, icon: const Icon(Icons.save_outlined), label: const Text('保存档案')),
                  OutlinedButton.icon(onPressed: _autoFillProfileFromStats, icon: const Icon(Icons.insights_outlined), label: const Text('从统计自动填充')),
                  OutlinedButton.icon(onPressed: _profileUpdateSuggestion, icon: const Icon(Icons.auto_fix_high_outlined), label: const Text('AI 建议')),
                  OutlinedButton.icon(onPressed: _clearAll, icon: const Icon(Icons.delete_outline), label: const Text('清空')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _sectionCard(
          title: '安全边界与非诊断声明',
          subtitle: '防御有保护作用；高风险状态下不做深度解释。',
          child: const Text(
            '本模块不是医疗、心理治疗或危机干预服务。AI 只提供自我观察假设和行动练习，不做诊断。\n\n如果出现自伤、伤人、极端绝望、现实感严重异常、持续失眠或功能严重受损，请优先联系当地紧急服务、专业心理/精神科资源，或让身边可信任的人陪同处理。\n\n在风险较高时，模块会停止深挖防御，转向安全步骤：远离危险工具/环境、联系具体的人、寻求专业支持。',
            style: TextStyle(height: 1.55),
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '防御拆除节奏',
          subtitle: '目标不是粗暴拆除防御，而是让自我更强、更灵活。',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('1. 先命名情绪，再分析机制。'),
              Text('2. 先验证现实，再做关系判断。'),
              Text('3. 先做小行动，再追求彻底改变。'),
              Text('4. 若承受不了，允许暂停深挖，回到稳定练习。'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required String subtitle, required Widget child, Widget? trailing}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFFE8E0D3))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                if (trailing != null) trailing,
              ],
            ),
            if (subtitle.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.black54, height: 1.35)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _textField(TextEditingController ctrl, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        minLines: 1,
        maxLines: 4,
        decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _chipWrap(String label, List<String> values) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: values.map((v) => Chip(label: Text(v))).toList(growable: false)),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, height: 1.4),
          children: <TextSpan>[
            TextSpan(text: '$label：', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _riskPill(String risk) {
    final color = risk == 'crisis' || risk == 'high'
        ? Colors.red.shade50
        : risk == 'medium'
            ? Colors.orange.shade50
            : Colors.green.shade50;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text('风险 $risk', style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _statBox(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8F6F1), borderRadius: BorderRadius.circular(16)),
      child: Column(children: <Widget>[Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), Text(label)]),
    );
  }

  Widget _emptyState(String title, String subtitle) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.explore_off_outlined, size: 56, color: Colors.black38),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      );

  Widget _emptyInline(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text, style: const TextStyle(color: Colors.black54)),
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      );

  String _actionStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return '已完成';
      case 'skipped':
        return '已跳过';
      case 'deferred':
        return '已延后';
      case 'open':
      default:
        return '待行动';
    }
  }

  String _actionTypeLabel(String type) {
    switch (type) {
      case 'reality_check':
        return '现实检验';
      case 'affect_tolerance':
        return '情绪承受';
      case 'wish_integration':
        return '欲望整合';
      case 'boundary':
        return '边界行动';
      case 'capacity_recovery':
        return '能力恢复';
      case 'relationship_repair':
        return '关系修复';
      case 'transition_experiment':
        return '转折实验';
      default:
        return '小行动';
    }
  }
}

class _LightChip extends StatelessWidget {
  final String label;
  const _LightChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

class _DefenseGroup {
  final String title;
  final List<List<String>> items;
  const _DefenseGroup(this.title, this.items);
}
