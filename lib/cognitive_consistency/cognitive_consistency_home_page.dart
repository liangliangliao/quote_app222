import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../pages/ai_prompt_settings_page.dart';
import '../external_data/todo_goal_dao.dart';
import '../external_data/todo_goal_models.dart';
import '../shame_transform/shame_transform_dao.dart';
import '../shame_transform/shame_transform_models.dart';
import 'cognitive_consistency_ai_service.dart';
import 'cognitive_consistency_dao.dart';
import 'cognitive_consistency_models.dart';
import 'cognitive_consistency_prompt_config.dart';
import 'cognitive_consistency_sourcebook_case_list_page.dart';

class CognitiveConsistencyHomePage extends StatefulWidget {
  const CognitiveConsistencyHomePage({
    super.key,
    this.initialGoal = '',
    this.initialContext = '',
    this.initialValues = '',
    this.sourceType = '',
    this.sourceId = '',
    this.initialTabIndex = 0,
  });

  final String initialGoal;
  final String initialContext;
  final String initialValues;
  final String sourceType;
  final String sourceId;
  final int initialTabIndex;

  @override
  State<CognitiveConsistencyHomePage> createState() => _CognitiveConsistencyHomePageState();
}

class _CognitiveConsistencyHomePageState extends State<CognitiveConsistencyHomePage> with SingleTickerProviderStateMixin {
  final _dao = CognitiveConsistencyDao();
  final _ai = CognitiveConsistencyAiService();
  final _goalDao = TodoGoalDao();
  final _shameDao = ShameTransformDao();
  final _promptConfig = CognitiveConsistencyPromptConfig();
  late final TabController _tabs;

  final _goalCtrl = TextEditingController();
  final _contextCtrl = TextEditingController();
  final _valuesCtrl = TextEditingController();
  final _doneCtrl = TextEditingController();
  final _reflectionCtrl = TextEditingController();
  final _hesitationCtrl = TextEditingController();
  final _rewardCtrl = TextEditingController();
  final _selfExplanationCtrl = TextEditingController();
  final _factsCtrl = TextEditingController();
  final _valueLabelCtrl = TextEditingController();
  final _valueWhyCtrl = TextEditingController();
  final _identityCtrl = TextEditingController();
  final _valueActionCtrl = TextEditingController();
  final _actualMinutesCtrl = TextEditingController();
  final _specialCtrl = TextEditingController();
  final _specialField1Ctrl = TextEditingController();
  final _specialField2Ctrl = TextEditingController();
  final _specialField3Ctrl = TextEditingController();
  final _specialField4Ctrl = TextEditingController();
  final _beliefCtrl = TextEditingController();
  final _actualBehaviorCtrl = TextEditingController();
  final _selfImageCtrl = TextEditingController();
  final _consequenceCtrl = TextEditingController();
  final _emotionCtrl = TextEditingController();
  final _currentExplanationCtrl = TextEditingController();
  final _avoidedInfoCtrl = TextEditingController();
  final _infoActualResultCtrl = TextEditingController();
  final _infoCatastropheCtrl = TextEditingController();
  final _infoRepairActionCtrl = TextEditingController();
  String _infoResultType = 'ambiguous';

  bool _busy = false;
  bool _preActionBusy = false;
  bool _rewardBusy = false;
  bool _selfCheckBusy = false;
  bool _reportBusy = false;
  bool _valueInsightBusy = false;
  bool _specialBusy = false;
  bool _changed = false;
  bool _writeBackToTodo = true;
  bool _markTodoCompleted = false;
  String _status = '';
  String _preActionGuidance = '';
  String _report = '';
  String _todoWriteBackStatus = '';
  String _reportRange = 'last30';
  String _valueInsight = '';
  String _activeReportId = '';
  String _activeValueInsightId = '';
  String _specialSceneKey = 'choice_recheck';
  CcPlanResult? _plan;
  CcPlanResult? _rewardPlan;
  CcPlanResult? _selfCheckPlan;
  CcPlanResult? _specialPlan;
  List<CcEvidenceRecord> _evidence = <CcEvidenceRecord>[];
  List<CcEvidenceRecord> _allEvidence = <CcEvidenceRecord>[];
  List<CcValueProfile> _valueProfiles = <CcValueProfile>[];
  List<CcEvidenceValueLink> _valueLinks = <CcEvidenceValueLink>[];
  List<CcReportRecord> _reports = <CcReportRecord>[];
  List<CcSession> _sessions = <CcSession>[];
  List<CcValueRelationInsightRecord> _valueRelationHistory = <CcValueRelationInsightRecord>[];
  List<CcEffectivePatternRecord> _effectivePatterns = <CcEffectivePatternRecord>[];
  Map<String, dynamic> _modernProfile = <String, dynamic>{};
  List<CcVerificationTask> _verificationTasks = <CcVerificationTask>[];
  final Set<String> _selectedValueIds = <String>{};
  bool _initialValueLinksEnsured = false;
  String? _evidenceFilter;
  String _editingValueId = '';
  String _activeRewardSource = '';
  String _activeSourceType = '';
  String _activeSourceId = '';
  String _activeSessionGoal = '';
  String _activeSessionContext = '';
  String _activeSessionValues = '';
  int _timerInitialSeconds = 180;
  int _secondsLeft = 180;
  int _timerStartedAtMs = 0;
  int _difficultyScore = 2;
  int _beforeDiscomfortScore = 5;
  int _beforeGuiltScore = 4;
  int _beforeAnxietyScore = 4;
  int _beforeShameScore = 2;
  int _beforeDefensivenessScore = 4;
  int _beforeAvoidanceScore = 5;
  int _beforeActionWillingnessScore = 4;
  int _afterDiscomfortScore = 3;
  int _afterGuiltScore = 2;
  int _afterAnxietyScore = 2;
  int _afterShameScore = 1;
  int _afterDefensivenessScore = 2;
  int _afterAvoidanceScore = 3;
  int _afterClarityScore = 5;
  int _afterResponsibilityScore = 5;
  int _afterActionWillingnessScore = 5;
  bool _preTemperatureLogged = false;
  Map<String, List<CcDissonanceTemperatureLog>> _temperatureByEvidenceId = <String, List<CcDissonanceTemperatureLog>>{};
  Map<String, CcV18SessionDetails> _v18DetailsBySessionId = <String, CcV18SessionDetails>{};
  Map<String, Map<String, dynamic>> _sourcebookDetailsBySessionId = <String, Map<String, dynamic>>{};
  List<CcDailyConsistencyReview> _dailyReviews = <CcDailyConsistencyReview>[];
  List<CcValueConsistencySnapshot> _valueSnapshots = <CcValueConsistencySnapshot>[];
  Map<String, CcTemperatureReviewItem> _temperatureReviewByEvidenceId = <String, CcTemperatureReviewItem>{};
  List<CcInformationContactResult> _informationContactResults = <CcInformationContactResult>[];
  List<CcIdentityTransitionRecord> _identityTransitions = <CcIdentityTransitionRecord>[];
  Map<String, CcInformationContactResult> _informationContactByEvidenceId = <String, CcInformationContactResult>{};
  Map<String, CcIdentityTransitionRecord> _identityTransitionByEvidenceId = <String, CcIdentityTransitionRecord>{};
  Map<String, int> _selfIntegrityStats = <String, int>{};
  String _v18TypeFilter = '';
  String _v18IntensityFilter = '';
  String _v18TemperatureFilter = '';
  String _v18VerificationFilter = '';
  String _v18SpecialFilter = '';
  String _editingDailyDateLabel = '';
  final _dailyClosestCtrl = TextEditingController();
  final _dailyDissonanceCtrl = TextEditingController();
  final _dailyRationalizationCtrl = TextEditingController();
  final _dailyGrowthCtrl = TextEditingController();
  final _dailyRepairCtrl = TextEditingController();
  final _dailyTomorrowCtrl = TextEditingController();
  final _resolutionSituationCtrl = TextEditingController();
  String _selectedCategory = 'start';
  String _resolutionMethodFilter = 'all';
  String _activeResolutionMethodUsageId = '';
  String _activeResolutionMethodWorkflowId = '';
  String _activeSourcebookDraftSessionId = '';
  String _lastDissonanceDiagnosisType = '';
  List<String> _recommendedResolutionMethodIds = <String>[];
  List<Map<String, dynamic>> _resolutionMethodUsages = <Map<String, dynamic>>[];
  Timer? _timer;

  static const Map<String, String> _categoryLabels = <String, String>{
    'start': '启动证据',
    'courage': '勇气证据',
    'learning': '学习证据',
    'responsibility': '责任证据',
    'recovery': '回来证据',
    'discomfort': '面对不适',
    'review': '复盘证据',
    'information': '现实信息证据',
    'identity': '新身份证据',
  };


  static final List<Map<String, dynamic>> _dissonanceResolutionMethods = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'behavior_alignment',
      'title': '改变行为：用最小行动重建一致',
      'shortTitle': '行为一致化',
      'category': '直接降低失调',
      'source': 'Festinger 认知失调降低机制 / 产品行动契约',
      'supportLevel': 'direct_mechanism',
      'sceneKey': 'hypocrisy_change',
      'when': '当你认同某个价值，但现实行为一直偏离它；例如想成长却持续逃避、拖延、沉迷。',
      'core': '不先争论自己到底是不是“自律/负责/努力”，而是先留下一个足够小、可完成、可观察的行动证据。',
      'risk': '行动设计过大，会重新变成逃避、自责和二次失调。',
      'quickAction': '选择一个 5-15 分钟的小行动，今天完成并写入证据账本。',
      'steps': <String>[
        '写出我认同的价值或标准。',
        '写出最近一次具体偏离行为，不做人格评价。',
        '把行动缩小到今天 5-15 分钟可完成。',
        '完成后记录：这条证据支持了什么新的自我理解。',
      ],
    },
    <String, dynamic>{
      'id': 'belief_reframe',
      'title': '改变解释：把自我辩护改成更准确的整合解释',
      'shortTitle': '解释重评',
      'category': '直接降低失调',
      'source': '失调降低机制 / 源书动态整合 / 价值分层',
      'supportLevel': 'theoretical_translation',
      'sceneKey': 'value_layering',
      'when': '当你不停解释、证明、合理化，或者把承认问题等同于否定整个人。',
      'core': '保留真实价值，修正过度僵硬的身份信念，把外围解释放回可检验的位置。',
      'risk': '解释重评不是给自己找更漂亮的借口，必须连接现实检验和行动证据。',
      'quickAction': '写出一句：我仍然重视____，同时承认____，今天从____开始。',
      'steps': <String>[
        '区分核心价值、身份信念、外围解释。',
        '找出最像自我辩护的一句话。',
        '把它改写为更准确、更可行动的表达。',
        '用一个现实小行动检验新解释。',
      ],
    },
    <String, dynamic>{
      'id': 'add_integrating_cognition',
      'title': '添加新认知：把冲突放进更大的意义结构',
      'shortTitle': '补充整合认知',
      'category': '直接降低失调',
      'source': '认知一致性理论 / 平衡与整合',
      'supportLevel': 'theoretical_translation',
      'sceneKey': 'cognitive_structure_map',
      'when': '当两个想法看似互相矛盾，但你需要更完整地理解现实，而不是粗暴删除其中一个。',
      'core': '加入新的事实、限制条件、情境差异和成长意义，让结构更完整，而不是强行否认冲突。',
      'risk': '新认知如果脱离事实，也可能变成新的合理化。',
      'quickAction': '补充一个以前忽略的事实，并标注它支持、反对或限制哪个旧判断。',
      'steps': <String>[
        '列出当前冲突的两个认知节点。',
        '补充第三个事实或情境条件。',
        '判断它让冲突变弱、变清楚，还是需要进一步验证。',
        '形成一句新的整合性表达。',
      ],
    },
    <String, dynamic>{
      'id': 'reduce_rigidity',
      'title': '降低绝对化：把“必须如此”改成可调整标准',
      'shortTitle': '去绝对化',
      'category': '直接降低失调',
      'source': '重要性调节 / 自我标准地图',
      'supportLevel': 'theoretical_translation',
      'sceneKey': 'self_standard_map',
      'when': '当你用过度僵硬的标准审判自己：我必须成功、不能犯错、不能后退。',
      'core': '保留标准中的价值，降低羞辱性、绝对化和不可行动部分。',
      'risk': '降低重要性不等于摆烂，而是把标准改到能执行、能复盘。',
      'quickAction': '把一句“我必须/我完了”改成一句“我重视____，下一步是____”。',
      'steps': <String>[
        '写出正在审判自己的标准。',
        '判断它来自价值、家庭、群体、理想自我还是恐惧。',
        '保留价值，删除羞辱性绝对化。',
        '生成一个更现实的新标准。',
      ],
    },
    <String, dynamic>{
      'id': 'information_contact',
      'title': '接触反方证据：打破选择性信息回避',
      'shortTitle': '现实接触',
      'category': '现实检验',
      'source': '选择性信息接触 / 现实检验',
      'supportLevel': 'direct_mechanism',
      'sceneKey': 'information_avoidance',
      'when': '当你只看支持自己说法的信息，回避账单、反馈、结果、反对证据。',
      'core': '把可怕信息降级为最小接触任务，让现实重新进入系统。',
      'risk': '一次性接触太多信息会导致崩溃和二次回避。',
      'quickAction': '只看一个数据、一个反馈或一个反方证据，并记录真实结果。',
      'steps': <String>[
        '写出我正在回避的信息。',
        '写出我害怕它说明什么。',
        '选择一个最低风险的接触方式。',
        '记录实际结果与想象灾难的差异。',
      ],
    },
    <String, dynamic>{
      'id': 'counter_attitudinal_experiment',
      'title': '反态度小实验：证明旧信念不是绝对事实',
      'shortTitle': '反态度实验',
      'category': '现实检验',
      'source': '反态度行为 / 角色扮演与态度改变 / 行动证据',
      'supportLevel': 'direct_mechanism',
      'sceneKey': 'counter_attitudinal_experiment',
      'when': '当你被“我做不到、我没有行动力、我不敢表达”这类旧信念困住。',
      'core': '设计一个与旧信念相反、低风险、可观察的小行为，用事实松动旧信念。',
      'risk': '实验不是证明你彻底改变，而是证明旧信念不是 100% 绝对。',
      'quickAction': '做一个 5-15 分钟反方向行动，完成后给旧信念松动程度打分。',
      'steps': <String>[
        '写出限制性旧信念。',
        '说明它保护了什么。',
        '设计一个相反方向的小行为。',
        '行动后记录：旧信念哪里被松动了。',
      ],
    },
    <String, dynamic>{
      'id': 'choice_recheck',
      'title': '重新评估选择：区分坚持、修正、暂停和退出',
      'shortTitle': '选择再评估',
      'category': '现实检验',
      'source': '决策后失调 / 沉没成本复盘',
      'supportLevel': 'direct_mechanism',
      'sceneKey': 'choice_recheck',
      'when': '当你已经做出选择，却反复证明自己没选错，或者因为投入太多不敢转向。',
      'core': '把“证明过去正确”改成“判断今天是否仍有现实价值”。',
      'risk': '为了减少后悔而继续投入，可能扩大损失。',
      'quickAction': '列出继续、调整、暂停、退出四条路径，并做一个低成本验证。',
      'steps': <String>[
        '写出已选择项与未选择项。',
        '列出新证据，而不是只重复当初理由。',
        '判断继续是否创造新价值。',
        '选择一个低成本验证行动。',
      ],
    },
    <String, dynamic>{
      'id': 'responsibility_repair',
      'title': '责任修复：把内疚转成可修复行动',
      'shortTitle': '责任修复',
      'category': '修复整合',
      'source': '责任—后果雷达 / 行动修复',
      'supportLevel': 'theoretical_translation',
      'sceneKey': 'responsibility_radar',
      'when': '当你在后悔、内疚、过度自责或逃避责任之间摇摆。',
      'core': '区分真实责任、非本人责任、过度背责和可修复部分，只对可修复部分行动。',
      'risk': '全怪自己会瘫痪，全怪环境会逃避。',
      'quickAction': '写出一个可补偿、可道歉、可修正、可预防的小行动。',
      'steps': <String>[
        '列事实后果，不扩展人格评价。',
        '区分可选择、可预见、可控制部分。',
        '标出真实责任与过度背责。',
        '执行一个修复性小行动。',
      ],
    },
    <String, dynamic>{
      'id': 'interpersonal_balance',
      'title': '人际平衡：区分人、观点、关系和边界',
      'shortTitle': '人际平衡',
      'category': '修复整合',
      'source': 'Heider / Newcomb 平衡理论',
      'supportLevel': 'direct_mechanism',
      'sceneKey': 'interpersonal_balance',
      'when': '当关系、观点、价值或群体身份纠缠在一起，让你无法表达真实态度。',
      'core': '看清“我—他人—对象/观点/事件”的三角结构，选择沟通、边界或接受局部不一致。',
      'risk': '为了关系压抑真实，或为了立场否定整个人，都会扩大失衡。',
      'quickAction': '完成一次低风险澄清：我尊重你，但我对这件事的看法是____。',
      'steps': <String>[
        '写出我对对方的态度。',
        '写出我和对方共同涉及的对象/观点。',
        '标出失衡点。',
        '选择沟通澄清或边界表达小行动。',
      ],
    },
    <String, dynamic>{
      'id': 'self_integrity',
      'title': '自我完整性：先保护核心价值，再面对现实',
      'shortTitle': '自我完整性',
      'category': '修复整合',
      'source': '自我完整性 / 真实自我桥接 / 产品核心价值体系',
      'supportLevel': 'product_extension',
      'sceneKey': 'identity_conflict',
      'when': '当现实反馈威胁自尊，让你想逃避、否认、攻击或合理化。',
      'core': '先确认自己不等于一次失败，再从核心价值出发面对一个现实事实。',
      'risk': '只做自我安慰、不接触现实，会变成新的防御。',
      'quickAction': '写出一个不依赖成功的核心价值，然后面对一个小事实。',
      'steps': <String>[
        '确认我不是这一次失败本身。',
        '写出仍值得保留的核心价值。',
        '面对一个小现实事实。',
        '留下一个新身份证据行动。',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 10, vsync: this, initialIndex: widget.initialTabIndex.clamp(0, 9).toInt());
    _goalCtrl.text = widget.initialGoal;
    _contextCtrl.text = widget.initialContext;
    _valuesCtrl.text = widget.initialValues;
    if (widget.initialTabIndex == 5 && widget.initialContext.trim().isNotEmpty) {
      _rewardCtrl.text = '我可能正在依赖的外部推动/压力：\n${widget.initialContext}';
    }
    if (widget.initialTabIndex == 6 && widget.initialContext.trim().isNotEmpty) {
      _selfExplanationCtrl.text = '我对这件事的当前解释：\n${widget.initialContext}';
      _factsCtrl.text = widget.initialGoal;
    }
    if (widget.initialTabIndex == 2 && widget.initialContext.trim().isNotEmpty) {
      _specialCtrl.text = widget.initialContext;
      _specialSceneKey = 'hypocrisy_change';
      if (widget.sourceType == 'shame_transform_result') {
        _specialField1Ctrl.text = widget.initialValues.trim().isEmpty ? '真实自我/健康责任' : widget.initialValues.trim();
        _specialField2Ctrl.text = '见补充背景中的羞耻/真实自我事件与价值—行为距离';
        _specialField4Ctrl.text = '执行补充背景中的今日最小行动，并保存为一致行动证据';
      }
    }
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabs.dispose();
    _goalCtrl.dispose();
    _contextCtrl.dispose();
    _valuesCtrl.dispose();
    _doneCtrl.dispose();
    _reflectionCtrl.dispose();
    _hesitationCtrl.dispose();
    _rewardCtrl.dispose();
    _selfExplanationCtrl.dispose();
    _factsCtrl.dispose();
    _valueLabelCtrl.dispose();
    _valueWhyCtrl.dispose();
    _identityCtrl.dispose();
    _valueActionCtrl.dispose();
    _actualMinutesCtrl.dispose();
    _specialCtrl.dispose();
    _specialField1Ctrl.dispose();
    _specialField2Ctrl.dispose();
    _specialField3Ctrl.dispose();
    _specialField4Ctrl.dispose();
    _beliefCtrl.dispose();
    _actualBehaviorCtrl.dispose();
    _selfImageCtrl.dispose();
    _consequenceCtrl.dispose();
    _emotionCtrl.dispose();
    _currentExplanationCtrl.dispose();
    _avoidedInfoCtrl.dispose();
    _infoActualResultCtrl.dispose();
    _infoCatastropheCtrl.dispose();
    _infoRepairActionCtrl.dispose();
    _dailyClosestCtrl.dispose();
    _dailyDissonanceCtrl.dispose();
    _dailyRationalizationCtrl.dispose();
    _dailyGrowthCtrl.dispose();
    _dailyRepairCtrl.dispose();
    _dailyTomorrowCtrl.dispose();
    _resolutionSituationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _dao.ensureTables();
    await _promptConfig.ensureCurrentVersion();
    final evidence = await _dao.recentEvidence(limit: 80, category: _evidenceFilter);
    final allEvidence = await _dao.recentEvidence(limit: 300);
    var profiles = await _dao.listValueProfiles();
    if (!_initialValueLinksEnsured) {
      final inferredLabels = _extractValueLabelsFromText(widget.initialValues);
      if (inferredLabels.isNotEmpty) {
        final ensured = await _dao.ensureValueProfilesForLabels(inferredLabels, priorityBase: 200);
        final sourceType = widget.sourceType.trim();
        final sourceId = widget.sourceId.trim();
        if (sourceType.isNotEmpty && sourceId.isNotEmpty && ensured.isNotEmpty) {
          await _dao.replaceSourceValueLinks(
            sourceType: sourceType,
            sourceId: sourceId,
            values: ensured,
            relationType: 'inferred_initial',
          );
        }
        profiles = await _dao.listValueProfiles();
        _selectedValueIds.addAll(ensured.map((e) => e.valueId));
      }
      _initialValueLinksEnsured = true;
    }
    final reports = await _dao.recentReports(limit: 8);
    final sessions = await _dao.recentSessions(limit: 60);
    final valueLinks = await _dao.listEvidenceValueLinks(limit: 3000);
    final valueRelationHistory = await _dao.recentValueRelationInsights(limit: 8);
    final effectivePatterns = await _dao.recentEffectivePatterns(limit: 12);
    final modernProfile = await _dao.modernPatternProfile();
    final verificationTasks = await _dao.recentVerificationTasks(limit: 20);
    final temperatureByEvidenceId = await _dao.temperatureLogsForEvidenceIds(allEvidence.map((e) => e.evidenceId));
    final temperatureReviewByEvidenceId = await _dao.temperatureReviewsForEvidenceIds(allEvidence.map((e) => e.evidenceId));
    final informationContactResults = await _dao.recentInformationContactResults(limit: 40);
    final identityTransitions = await _dao.recentIdentityTransitions(limit: 40);
    final informationContactByEvidenceId = await _dao.informationContactResultsForEvidenceIds(allEvidence.map((e) => e.evidenceId));
    final identityTransitionByEvidenceId = await _dao.identityTransitionsForEvidenceIds(allEvidence.map((e) => e.evidenceId));
    final selfIntegrityStats = await _dao.selfIntegrityStats();
    final v18DetailsBySessionId = await _dao.v18DetailsForSessionIds(allEvidence.map((e) => e.sessionId));
    final sourcebookDetailsBySessionId = await _dao.sourcebookCaseDetailsForSessionIds(sessions.map((s) => s.sessionId));
    final dailyReviews = await _dao.recentDailyConsistencyReviews(limit: 14);
    final valueSnapshots = await _dao.buildValueConsistencySnapshots();
    final resolutionMethodUsages = await _dao.recentResolutionMethodUsages(limit: 30);
    if (!mounted) return;
    setState(() {
      _evidence = evidence;
      _allEvidence = allEvidence;
      _valueProfiles = profiles;
      final profileIds = profiles.map((v) => v.valueId).toSet();
      _selectedValueIds.removeWhere((id) => !profileIds.contains(id));
      _reports = reports;
      _sessions = sessions;
      _valueLinks = valueLinks;
      _valueRelationHistory = valueRelationHistory;
      _effectivePatterns = effectivePatterns;
      _modernProfile = modernProfile;
      _verificationTasks = verificationTasks;
      _temperatureByEvidenceId = temperatureByEvidenceId;
      _temperatureReviewByEvidenceId = temperatureReviewByEvidenceId;
      _informationContactResults = informationContactResults;
      _identityTransitions = identityTransitions;
      _informationContactByEvidenceId = informationContactByEvidenceId;
      _identityTransitionByEvidenceId = identityTransitionByEvidenceId;
      _selfIntegrityStats = selfIntegrityStats;
      _v18DetailsBySessionId = v18DetailsBySessionId;
      _sourcebookDetailsBySessionId = sourcebookDetailsBySessionId;
      _dailyReviews = dailyReviews;
      _valueSnapshots = valueSnapshots;
      _resolutionMethodUsages = resolutionMethodUsages;
    });
  }

  Future<void> _generate() async {
    if (_goalCtrl.text.trim().isEmpty && _contextCtrl.text.trim().isEmpty) {
      _toast('请至少输入一个目标、困扰或失调事件。');
      return;
    }
    setState(() {
      _busy = true;
      _status = '正在把目标转化为 1 美元行动...';
    });
    try {
      final result = await _ai.generateTargetToAction(
        userGoal: _goalCtrl.text,
        userContext: _contextCtrl.text,
        userValues: _valuesCtrl.text,
        sourceType: _activeSourceType.trim().isNotEmpty ? _activeSourceType : widget.sourceType,
        sourceId: _activeSourceId.trim().isNotEmpty ? _activeSourceId : widget.sourceId,
        rewardSource: _activeRewardSource,
        originScene: 'target_to_action',
      );
      await _linkPlanSessionValues(result);
      if (_activeResolutionMethodUsageId.trim().isNotEmpty && result.sessionId.trim().isNotEmpty) {
        await _dao.updateResolutionMethodUsage(
          usageId: _activeResolutionMethodUsageId,
          sessionId: result.sessionId,
          caseId: 'case_${result.sessionId}',
          methodWorkflowId: _activeResolutionMethodWorkflowId,
          dissonanceType: _lastDissonanceDiagnosisType,
          status: 'analysis_generated',
        );
      }
      if (!mounted) return;
      setState(() {
        _applyPlan(
          result,
          rewardSource: _activeRewardSource,
          sourceType: _activeSourceType.trim().isNotEmpty ? _activeSourceType : widget.sourceType,
          sourceId: _activeSourceId.trim().isNotEmpty ? _activeSourceId : widget.sourceId,
        );
        _status = result.usedFallback ? '已生成本地兜底方案；配置可用 AI 后会自动调用模型。' : 'AI 已生成 1 美元行动方案，并已保存 session 链路。';
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '生成失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  String _structuredDissonanceInput() {
    final lines = <String>[];
    final base = _contextCtrl.text.trim().isEmpty ? _goalCtrl.text.trim() : _contextCtrl.text.trim();
    if (base.isNotEmpty) lines.add('基础事件：$base');
    if (_goalCtrl.text.trim().isNotEmpty && _contextCtrl.text.trim().isNotEmpty) lines.add('关联目标：${_goalCtrl.text.trim()}');
    if (_beliefCtrl.text.trim().isNotEmpty) lines.add('我认为自己应该/相信：${_beliefCtrl.text.trim()}');
    if (_actualBehaviorCtrl.text.trim().isNotEmpty) lines.add('我实际做了：${_actualBehaviorCtrl.text.trim()}');
    if (_selfImageCtrl.text.trim().isNotEmpty) lines.add('我想维护的自我形象：${_selfImageCtrl.text.trim()}');
    if (_consequenceCtrl.text.trim().isNotEmpty) lines.add('现实后果：${_consequenceCtrl.text.trim()}');
    if (_emotionCtrl.text.trim().isNotEmpty) lines.add('主要情绪：${_emotionCtrl.text.trim()}');
    if (_currentExplanationCtrl.text.trim().isNotEmpty) lines.add('我现在如何解释自己：${_currentExplanationCtrl.text.trim()}');
    if (_avoidedInfoCtrl.text.trim().isNotEmpty) lines.add('我最不想面对/正在回避的信息：${_avoidedInfoCtrl.text.trim()}');
    return lines.join('\n');
  }

  Future<void> _analyzeDissonance() async {
    final event = _structuredDissonanceInput();
    if (event.isEmpty) {
      _toast('请先输入一个失调、拖延、逃避或自我矛盾事件。');
      return;
    }
    setState(() {
      _busy = true;
      _status = '正在识别价值—行为—解释之间的认知失调...';
    });
    try {
      final result = await _ai.generateDissonanceAnalysis(
        userEvent: event,
        userValues: _valuesCtrl.text,
        sourceType: _activeSourceType.trim().isNotEmpty ? _activeSourceType : widget.sourceType,
        sourceId: _activeSourceId.trim().isNotEmpty ? _activeSourceId : widget.sourceId,
        originScene: 'dissonance_analysis',
      );
      await _linkPlanSessionValues(result);
      await _bindActiveResolutionMethodUsageToPlan(result);
      if (!mounted) return;
      setState(() {
        _applyPlan(
          result,
          rewardSource: _activeRewardSource,
          sourceType: _activeSourceType.trim().isNotEmpty ? _activeSourceType : widget.sourceType,
          sourceId: _activeSourceId.trim().isNotEmpty ? _activeSourceId : widget.sourceId,
        );
        _status = result.usedFallback ? '已生成本地失调分析兜底方案。' : 'AI 已完成认知失调分析，并已保存 session 链路。';
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '分析失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const Map<String, String> _specialSceneLabels = <String, String>{
    'choice_recheck': '选择后合理化',
    'sunk_cost': '沉没成本',
    'hypocrisy_change': '价值—行为距离',
    'group_culture': '群体/关系/文化失调',
    'vicarious_dissonance': '替代性失调',
    'responsibility_radar': '责任—后果雷达',
    'self_standard_map': '自我标准地图',
    'information_avoidance': '信息回避挑战',
    'identity_conflict': '身份冲突重构',
    'cognitive_structure_map': '认知结构地图',
    'conflict_type_router': '矛盾类型分流器',
    'psychological_function': '心理功能分析器',
    'value_layering': '核心/外围分层',
    'interpersonal_balance': '人际平衡分析',
    'counter_attitudinal_experiment': '反态度行为实验',
  };

  List<Map<String, String>> _specialFieldMeta(String key) {
    switch (key) {
      case 'choice_recheck':
        return const [
          {'label': '已选择项', 'hint': '我已经选择/正在维护的方向'},
          {'label': '未选择项/替代路径', 'hint': '我当时放弃或正在贬低的选择'},
          {'label': '当初理由', 'hint': '我当初为什么这样选'},
          {'label': '现在的新证据', 'hint': '现在出现了哪些支持/反对证据'},
        ];
      case 'sunk_cost':
        return const [
          {'label': '已投入内容', 'hint': '时间、金钱、情感、身份承诺或痛苦'},
          {'label': '继续成本', 'hint': '继续下去还要付出什么'},
          {'label': '退出/暂停成本', 'hint': '停止或转向会失去什么'},
          {'label': '可迁移成果', 'hint': '即使转向仍能保留的经验/能力/资源'},
        ];
      case 'hypocrisy_change':
        return const [
          {'label': '我认同的价值', 'hint': '健康、学习、诚实、责任、自律等'},
          {'label': '最近一次没做到', 'hint': '具体行为，不写人格评价'},
          {'label': '为什么重要', 'hint': '这个价值对我为什么重要'},
          {'label': '今天可修复的小行动', 'hint': '5-30分钟内能做什么'},
        ];
      case 'group_culture':
        return const [
          {'label': '我的个人价值', 'hint': '我真正重视什么'},
          {'label': '家庭/群体/文化标准', 'hint': '他们/我们默认要求什么'},
          {'label': '我害怕失去什么', 'hint': '关系、面子、认同、归属或安全感'},
          {'label': '可尝试的边界表达', 'hint': '不粗暴切断关系的小行动'},
        ];
      case 'vicarious_dissonance':
        return const [
          {'label': '我认同的群体/对象', 'hint': '我们的人、支持的人、团队或圈子'},
          {'label': '他们做了什么', 'hint': '让我不舒服的行为/言论'},
          {'label': '我感到的责任或不适', 'hint': '我为什么像是自己也被卷入'},
          {'label': '我想保留的价值表达', 'hint': '不过度背责但不合理化的行动'},
        ];
      case 'responsibility_radar':
        return const [
          {'label': '事件事实/后果', 'hint': '发生了什么，造成了什么结果'},
          {'label': '当时可选路径', 'hint': '当时是否有其他选择'},
          {'label': '我认为自己要负责的部分', 'hint': '我觉得我哪里有责任'},
          {'label': '我可能过度背负或逃避的部分', 'hint': '全怪自己/全怪环境的倾向'},
        ];
      case 'self_standard_map':
        return const [
          {'label': '我正在评价自己的句子', 'hint': '例如：我是不是太失败/太差'},
          {'label': '这个标准来自哪里', 'hint': '家庭、社会、群体、理想自我或个人价值'},
          {'label': '它让我怎么行动或卡住', 'hint': '这个标准带来的行为影响'},
          {'label': '我想调整成的新标准', 'hint': '更真实、不过度羞辱、可行动的标准'},
        ];
      case 'information_avoidance':
        return const [
          {'label': '我正在回避的信息', 'hint': '账单、成绩、体检、反馈、结果、反对证据等'},
          {'label': '我害怕看到的结果', 'hint': '如果结果不好，我害怕它说明什么'},
          {'label': '它威胁的自我形象/价值', 'hint': '例如负责、聪明、健康、自律、被认可'},
          {'label': '今天最小接触行动', 'hint': '只看一个数据、打开一个页面、询问一个反馈'},
        ];
      case 'identity_conflict':
        return const [
          {'label': '旧身份', 'hint': '例如逃避者、讨好者、受害者、只幻想的人'},
          {'label': '新身份', 'hint': '例如行动者、负责者、有边界的人、真实的人'},
          {'label': '旧身份在保护什么', 'hint': '避免失败、羞耻、冲突、失控或失去关系'},
          {'label': '新身份最小行动', 'hint': '今天能留下的新身份小证据'},
        ];
      case 'cognitive_structure_map':
        return const [
          {'label': '我说/相信/重视什么', 'hint': '把表层想法、价值或判断写出来'},
          {'label': '我实际做了什么', 'hint': '具体行为，不写人格评价'},
          {'label': '我希望维持的自我形象', 'hint': '理性、努力、善良、负责、没选错等'},
          {'label': '现实反馈或关系证据', 'hint': '现实结果、他人反馈、数据或后果'},
        ];
      case 'conflict_type_router':
        return const [
          {'label': '当前矛盾事件', 'hint': '纠结、后悔、拖延、冲突或内耗'},
          {'label': '最冲突的两部分', 'hint': '例如价值 vs 行为、自我形象 vs 现实反馈'},
          {'label': '最刺痛的情绪', 'hint': '内疚、焦虑、羞耻、愤怒、后悔等'},
          {'label': '我希望得到的方向', 'hint': '继续、调整、退出、沟通、验证、行动'},
        ];
      case 'psychological_function':
        return const [
          {'label': '当前想法/行为/态度', 'hint': '我一直这样想/这样做/这样解释'},
          {'label': '它短期帮我避免了什么', 'hint': '失败感、羞耻、焦虑、冲突、不确定'},
          {'label': '它曾经有什么好处', 'hint': '曾经保护过我什么'},
          {'label': '它现在带来的代价', 'hint': '限制行动、关系、成长、现实感或责任'},
        ];
      case 'value_layering':
        return const [
          {'label': '我真正不想放弃的核心价值', 'hint': '成长、诚实、责任、自由、尊严、健康、关系等'},
          {'label': '我对自己的身份定义', 'hint': '我必须证明自己没错/我不能失败/我是努力的人'},
          {'label': '我现在给出的解释或理由', 'hint': '太晚了、没状态、别人也这样、已经投入很多'},
          {'label': '今天可以验证的小行动', 'hint': '一个 5-15 分钟、可完成的行动'},
        ];
      case 'interpersonal_balance':
        return const [
          {'label': '我与对方的关系/态度', 'hint': '喜欢、尊重、依赖、反感、矛盾等'},
          {'label': '我们共同涉及的对象/观点/事件', 'hint': '这件事、某个价值、某个选择或某个第三方'},
          {'label': '我对这个对象的态度', 'hint': '支持、反对、重视、讨厌、犹豫'},
          {'label': '对方对这个对象的态度', 'hint': '他/她/他们怎么看'},
        ];
      case 'counter_attitudinal_experiment':
        return const [
          {'label': '限制性旧信念', 'hint': '例如我没有行动力/我不敢表达/我坚持不了'},
          {'label': '这个信念保护了什么', 'hint': '避免失败、避免被评价、避免失望'},
          {'label': '一个相反方向的小行为', 'hint': '5-15 分钟内可以做的低风险动作'},
          {'label': '行动后观察问题', 'hint': '这次行动能说明旧信念哪里不是绝对事实'},
        ];
      default:
        return const [];
    }
  }

  String _structuredSpecialInput() {
    final meta = _specialFieldMeta(_specialSceneKey);
    final ctrls = [_specialField1Ctrl, _specialField2Ctrl, _specialField3Ctrl, _specialField4Ctrl];
    final lines = <String>[
      '专项类型：${_specialSceneLabels[_specialSceneKey] ?? _specialSceneKey}',
    ];
    for (var i = 0; i < meta.length && i < ctrls.length; i++) {
      final text = ctrls[i].text.trim();
      if (text.isNotEmpty) lines.add("${meta[i]['label'] ?? ''}：$text");
    }
    if (_specialCtrl.text.trim().isNotEmpty) lines.add('补充背景：${_specialCtrl.text.trim()}');
    return lines.join('\n');
  }

  int _filledSpecialRequiredCount() {
    final fields = <TextEditingController>[_specialField1Ctrl, _specialField2Ctrl, _specialField3Ctrl, _specialField4Ctrl];
    return fields.where((c) => c.text.trim().isNotEmpty).length;
  }

  String _specialValidationMessage() {
    final meta = _specialFieldMeta(_specialSceneKey);
    if (meta.isEmpty) return '';
    final filled = _filledSpecialRequiredCount();
    if (filled >= 2) return '';
    final first = meta.isNotEmpty ? (meta[0]['label'] ?? '第一个核心字段') : '第一个核心字段';
    final second = meta.length > 1 ? (meta[1]['label'] ?? '第二个核心字段') : '第二个核心字段';
    return '请至少填写两个核心字段：$first、$second。补充背景不能替代专项核心字段。';
  }

  Future<void> _analyzeSpecialScene() async {
    final validationMessage = _specialValidationMessage();
    if (validationMessage.isNotEmpty) {
      _toast(validationMessage);
      return;
    }
    final structured = _structuredSpecialInput();
    final input = structured.trim().isEmpty
        ? (_contextCtrl.text.trim().isEmpty ? _goalCtrl.text.trim() : _contextCtrl.text.trim())
        : structured.trim();
    if (input.isEmpty) {
      _toast('请先描述一个选择、投入、价值没做到、关系群体冲突或替代性失调事件。');
      return;
    }
    setState(() {
      _specialBusy = true;
      _status = '正在进行${_specialSceneLabels[_specialSceneKey] ?? '专项'}分析...';
    });
    try {
      final result = await _ai.generateSpecialSceneAnalysis(
        sceneKey: _specialSceneKey,
        userInput: input,
        userValues: _valuesCtrl.text,
        sourceType: _activeSourceType.trim().isNotEmpty ? _activeSourceType : widget.sourceType,
        sourceId: _activeSourceId.trim().isNotEmpty ? _activeSourceId : widget.sourceId,
      );
      await _linkPlanSessionValues(result);
      await _bindActiveResolutionMethodUsageToPlan(result);
      if (!mounted) return;
      setState(() {
        _specialPlan = result;
        _applyPlan(
          result,
          sourceType: _activeSourceType.trim().isNotEmpty ? _activeSourceType : widget.sourceType,
          sourceId: _activeSourceId.trim().isNotEmpty ? _activeSourceId : widget.sourceId,
        );
        _status = result.usedFallback ? '已生成专项本地兜底方案。' : 'AI 已完成${_specialSceneLabels[_specialSceneKey] ?? '专项'}分析。';
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '专项分析失败：$e');
    } finally {
      if (mounted) setState(() => _specialBusy = false);
    }
  }

  Future<void> _buildPreActionGuidance() async {
    final plan = _plan;
    if (plan == null) {
      _toast('请先生成一个 1 美元行动。');
      return;
    }
    setState(() {
      _preActionBusy = true;
      _preActionGuidance = '正在生成行动前抗犹豫引导...';
    });
    try {
      final text = await _ai.generatePreActionGuidance(
        oneDollarAction: plan.oneDollarAction,
        hesitation: _hesitationCtrl.text,
        valueLink: plan.valueLink,
      );
      if (!mounted) return;
      setState(() => _preActionGuidance = text);
    } finally {
      if (mounted) setState(() => _preActionBusy = false);
    }
  }


  Future<void> _linkPlanSessionValues(CcPlanResult result) async {
    final sid = result.sessionId.trim();
    if (sid.isEmpty) return;
    final linked = _effectiveValueProfilesForEvidence(result);
    if (linked.isNotEmpty) {
      await _dao.mergeSourceValueLinks(
        sourceType: 'cc_session',
        sourceId: sid,
        values: linked,
        relationType: 'session_values',
      );
    }
    final sourceType = _activeSourceType.trim().isNotEmpty ? _activeSourceType.trim() : widget.sourceType.trim();
    final sourceId = _activeSourceId.trim().isNotEmpty ? _activeSourceId.trim() : widget.sourceId.trim();
    if (sourceType.isNotEmpty && sourceId.isNotEmpty) {
      await _dao.saveActionTraceLink(fromType: sourceType, fromId: sourceId, toType: 'cc_session', toId: sid, relationType: 'source_generated_session');
    }
    if (_activeValueInsightId.trim().isNotEmpty) {
      await _dao.updateValueRelationInsightLink(insightId: _activeValueInsightId, linkedSessionId: sid);
      await _dao.saveActionTraceLink(fromType: 'value_relation_insight', fromId: _activeValueInsightId, toType: 'cc_session', toId: sid, relationType: 'insight_generated_session');
    }
  }

  Future<void> _recordPreActionTemperature() async {
    final plan = _plan;
    if (plan == null || plan.sessionId.trim().isEmpty) {
      _toast('请先设为当前行动，再记录行动前温度。');
      return;
    }
    await _dao.saveDissonanceTemperatureLog(
      sessionId: plan.sessionId,
      phase: 'before',
      discomfortScore: _beforeDiscomfortScore,
      guiltScore: _beforeGuiltScore,
      anxietyScore: _beforeAnxietyScore,
      shameScore: _beforeShameScore,
      defensivenessScore: _beforeDefensivenessScore,
      avoidanceUrgeScore: _beforeAvoidanceScore,
      actionWillingnessScore: _beforeActionWillingnessScore,
      note: '行动开始前独立记录：不适/内疚/焦虑/羞耻/防御/逃避冲动/行动意愿',
    );
    setState(() => _preTemperatureLogged = true);
    _toast('已记录行动前失调温度。完成行动后保存证据时会记录行动后温度。');
  }

  String _todayLabel() {
    final now = DateTime.now();
    return '${now.year}-${_two(now.month)}-${_two(now.day)}';
  }

  Future<void> _saveDailyConsistencyReview() async {
    if (_dailyClosestCtrl.text.trim().isEmpty &&
        _dailyDissonanceCtrl.text.trim().isEmpty &&
        _dailyRepairCtrl.text.trim().isEmpty &&
        _dailyTomorrowCtrl.text.trim().isEmpty) {
      _toast('至少填写今天的一个价值行动、一个失调或明天一个行动。');
      return;
    }
    await _dao.saveDailyConsistencyReview(
      dateLabel: _editingDailyDateLabel.trim().isNotEmpty ? _editingDailyDateLabel.trim() : _todayLabel(),
      closestValueAction: _dailyClosestCtrl.text,
      mainDissonance: _dailyDissonanceCtrl.text,
      rationalizationUsed: _dailyRationalizationCtrl.text,
      growthReframe: _dailyGrowthCtrl.text,
      repairActionDone: _dailyRepairCtrl.text,
      tomorrowAction: _dailyTomorrowCtrl.text,
    );
    _dailyClosestCtrl.clear();
    _dailyDissonanceCtrl.clear();
    _dailyRationalizationCtrl.clear();
    _dailyGrowthCtrl.clear();
    _dailyRepairCtrl.clear();
    _dailyTomorrowCtrl.clear();
    _editingDailyDateLabel = '';
    _changed = true;
    await _load();
    _toast('已保存今日一致性复盘，并进入报告/价值地图统计。');
  }


  int _todayStartMs() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  }

  Future<void> _generateDailyReviewDraft() async {
    setState(() => _busy = true);
    try {
      final todayStart = _todayStartMs();
      final todayEvidenceRows = _allEvidence.where((e) => e.createdAtMs >= todayStart).toList(growable: false);
      final recent = _allEvidence
          .take(8)
          .map((e) => '完成：${e.completedAction}；价值：${e.valueLink}；新解释：${e.newStory}')
          .join('\n');
      final todayEvidenceText = todayEvidenceRows.isEmpty
          ? '今天暂无行动证据，请生成缺失复盘：诚实说明今天还缺少可见行动证据，并给出一个今天或明天可补做的最小一致性行动。'
          : todayEvidenceRows
              .map((e) => '今日完成：${e.completedAction}；价值：${e.valueLink}；新解释：${e.newStory}')
              .join('\n');
      final draft = await _ai.generateDailyReviewDraft(
        userValues: _valuesCtrl.text,
        todayEvidence: _dailyClosestCtrl.text.trim().isNotEmpty ? _dailyClosestCtrl.text : todayEvidenceText,
        todayDissonance: _dailyDissonanceCtrl.text,
        recentEvidence: recent,
      );
      if (!mounted) return;
      setState(() {
        _dailyClosestCtrl.text = draft.closestValueAction;
        _dailyDissonanceCtrl.text = draft.mainDissonance;
        _dailyRationalizationCtrl.text = draft.rationalizationUsed;
        _dailyGrowthCtrl.text = draft.growthReframe;
        _dailyRepairCtrl.text = draft.repairActionDone;
        _dailyTomorrowCtrl.text = draft.tomorrowAction;
      });
      _toast(todayEvidenceRows.isEmpty ? '已生成缺失复盘草稿：今天暂无行动证据，请重点补一个最小行动。' : '已生成今日一致性复盘草稿，可修改后保存。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteDailyReview(CcDailyConsistencyReview review) async {
    await _dao.deleteDailyConsistencyReview(review.reviewId);
    if (_editingDailyDateLabel == review.dateLabel) _editingDailyDateLabel = '';
    await _load();
    _toast('已删除该复盘。');
  }

  void _editDailyReview(CcDailyConsistencyReview review) {
    setState(() {
      _dailyClosestCtrl.text = review.closestValueAction;
      _dailyDissonanceCtrl.text = review.mainDissonance;
      _dailyRationalizationCtrl.text = review.rationalizationUsed;
      _dailyGrowthCtrl.text = review.growthReframe;
      _dailyRepairCtrl.text = review.repairActionDone;
      _dailyTomorrowCtrl.text = review.tomorrowAction;
      _editingDailyDateLabel = review.dateLabel;
    });
    _toast('已载入该日复盘，修改后保存会覆盖当天主复盘。');
  }

  Future<void> _deleteInformationContactResult(CcInformationContactResult item) async {
    await _dao.deleteInformationContactResult(item.resultId);
    await _load();
    _toast('已删除该信息接触结果。');
  }

  Future<void> _deleteIdentityTransitionRecord(CcIdentityTransitionRecord item) async {
    await _dao.deleteIdentityTransitionRecord(item.transitionId);
    await _load();
    _toast('已删除该身份转换记录。');
  }

  Future<void> _editInformationContactResult(CcInformationContactResult item) async {
    final avoidedCtrl = TextEditingController(text: item.avoidedInformation);
    final fearedCtrl = TextEditingController(text: item.fearedResult);
    final actualCtrl = TextEditingController(text: item.actualResult);
    final catastropheCtrl = TextEditingController(text: item.catastrophizingCheck);
    final repairCtrl = TextEditingController(text: item.repairAction);
    var resultType = item.resultType.trim().isEmpty ? 'ambiguous' : item.resultType.trim();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('编辑信息接触结果'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: avoidedCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '原本回避的信息')),
              TextField(controller: fearedCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '原本害怕的结果')),
              DropdownButtonFormField<String>(
                value: resultType,
                items: const [
                  DropdownMenuItem(value: 'better', child: Text('好于预期')),
                  DropdownMenuItem(value: 'worse', child: Text('确实不好')),
                  DropdownMenuItem(value: 'ambiguous', child: Text('仍然模糊')),
                ],
                onChanged: (v) => setDialogState(() => resultType = v ?? resultType),
                decoration: const InputDecoration(labelText: '结果类型'),
              ),
              TextField(controller: actualCtrl, maxLines: 3, decoration: const InputDecoration(labelText: '看到的真实结果')),
              TextField(controller: catastropheCtrl, maxLines: 3, decoration: const InputDecoration(labelText: '灾难化校验')),
              TextField(controller: repairCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '下一步修复/补充信息行动')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存')),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _dao.updateInformationContactResult(CcInformationContactResult(
        resultId: item.resultId,
        sessionId: item.sessionId,
        evidenceId: item.evidenceId,
        avoidedInformation: avoidedCtrl.text,
        fearedResult: fearedCtrl.text,
        actualResult: actualCtrl.text,
        resultType: resultType,
        catastrophizingCheck: catastropheCtrl.text,
        repairAction: repairCtrl.text,
        discomfortBefore: item.discomfortBefore,
        discomfortAfter: item.discomfortAfter,
        sourceType: item.sourceType,
        sourceId: item.sourceId,
        originScene: item.originScene,
        createdAtMs: item.createdAtMs,
      ));
      await _load();
      _toast('已更新信息接触结果。');
    }
    avoidedCtrl.dispose();
    fearedCtrl.dispose();
    actualCtrl.dispose();
    catastropheCtrl.dispose();
    repairCtrl.dispose();
  }

  Future<void> _editIdentityTransitionRecord(CcIdentityTransitionRecord item) async {
    final oldCtrl = TextEditingController(text: item.oldIdentity);
    final newCtrl = TextEditingController(text: item.newIdentity);
    final protectionCtrl = TextEditingController(text: item.oldProtection);
    final fearCtrl = TextEditingController(text: item.fearOfLoss);
    final actionCtrl = TextEditingController(text: item.newIdentityAction);
    final sentenceCtrl = TextEditingController(text: item.postActionIdentitySentence);
    final nextCtrl = TextEditingController(text: item.nextIdentityAction);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑身份转换档案'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: oldCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '旧身份')),
            TextField(controller: newCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '新身份')),
            TextField(controller: protectionCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '旧身份保护什么')),
            TextField(controller: fearCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '害怕失去什么')),
            TextField(controller: actionCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '本次新身份行动')),
            TextField(controller: sentenceCtrl, maxLines: 3, decoration: const InputDecoration(labelText: '行动后身份解释')),
            TextField(controller: nextCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '下一个新身份证据行动')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存')),
        ],
      ),
    );
    if (saved == true) {
      await _dao.updateIdentityTransitionRecord(CcIdentityTransitionRecord(
        transitionId: item.transitionId,
        sessionId: item.sessionId,
        evidenceId: item.evidenceId,
        oldIdentity: oldCtrl.text,
        newIdentity: newCtrl.text,
        oldProtection: protectionCtrl.text,
        fearOfLoss: fearCtrl.text,
        newIdentityAction: actionCtrl.text,
        postActionIdentitySentence: sentenceCtrl.text,
        nextIdentityAction: nextCtrl.text,
        sourceType: item.sourceType,
        sourceId: item.sourceId,
        originScene: item.originScene,
        createdAtMs: item.createdAtMs,
      ));
      await _load();
      _toast('已更新身份转换档案。');
    }
    oldCtrl.dispose();
    newCtrl.dispose();
    protectionCtrl.dispose();
    fearCtrl.dispose();
    actionCtrl.dispose();
    sentenceCtrl.dispose();
    nextCtrl.dispose();
  }

  Future<void> _quickCreateTodoActionFromText(String title, String detail, {String actionType = 'value', Future<void> Function(String stepId)? afterCreated}) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      _toast('没有可写入的行动。');
      return;
    }
    var goals = await _goalDao.listGoals(limit: 80);
    if (!mounted) return;
    if (goals.isEmpty) {
      _toast('当前没有可写入的 Todo 目标。请先创建一个目标。');
      return;
    }
    var selectedGoalId = goals.first.goalId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('写入 Todo'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cleanTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (detail.trim().isNotEmpty) Text(detail, maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedGoalId,
              items: goals.map((g) => DropdownMenuItem(value: g.goalId, child: Text(g.goalTitle, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setDialogState(() => selectedGoalId = v ?? selectedGoalId),
              decoration: const InputDecoration(labelText: '写入哪个目标'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('写入')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final goal = goals.firstWhere((g) => g.goalId == selectedGoalId, orElse: () => goals.first);
    final stepId = await _goalDao.createActionStep(
      goalId: selectedGoalId,
      sourceTaskId: goal.sourceTaskId,
      title: cleanTitle,
      minimumStandard: detail.trim().isEmpty ? cleanTitle : detail.trim(),
      simplifiedStandard: detail.trim().isEmpty ? cleanTitle : detail.trim(),
      recommendedStandard: cleanTitle,
      stretchStandard: '如果状态允许，轻微升级；如果阻力变大，回到最小充分行动。',
      difficultyScore: 2,
      zoneType: 'comfort',
      plannedDate: _goalDao.todayDate(),
      actionType: actionType,
      experienceIntention: '来自足下一致行动的后续闭环推荐。',
      completionQuestion: '我是否完成了这个后续行动，并留下现实证据？',
    );
    await _dao.saveActionTraceLink(fromType: 'cc_followup_action', fromId: cleanTitle, toType: 'todo_goal_step', toId: stepId, relationType: 'followup_written_to_todo');
    if (afterCreated != null) {
      await afterCreated(stepId);
    }
    _toast('已写入 Todo。');
  }

  Future<void> _saveEvidence() async {
    final plan = _plan;
    if (plan == null) {
      _toast('请先生成一个 1 美元行动。');
      return;
    }
    if (_doneCtrl.text.trim().isEmpty) {
      _toast('请填写你实际完成了什么。');
      return;
    }
    setState(() => _busy = true);
    try {
      final explanation = await _ai.generatePostActionExplanation(
        userGoal: _goalCtrl.text,
        plannedAction: plan.oneDollarAction,
        completedAction: _doneCtrl.text,
        userReflection: _reflectionCtrl.text,
        valueLink: _effectiveValueLink(plan),
        oldStory: plan.oldStory,
        v18Context: _postActionV18Context(plan),
      );
      final endedAt = DateTime.now().millisecondsSinceEpoch;
      final effortMinutes = _actualEffortMinutes();
      final sourceType = _activeSourceType.trim().isNotEmpty ? _activeSourceType : widget.sourceType;
      final sourceId = _activeSourceId.trim().isNotEmpty ? _activeSourceId : widget.sourceId;
      final evidenceId = await _dao.saveEvidence(
        sessionId: plan.sessionId,
        userGoal: _effectiveGoal(),
        plannedAction: plan.oneDollarAction,
        completedAction: _doneCtrl.text,
        userReflection: _reflectionCtrl.text,
        evidenceLabel: plan.evidenceLabel,
        valueLink: _effectiveValueLink(plan),
        oldStory: plan.oldStory,
        newStory: explanation,
        evidenceCategory: _selectedCategory,
        identityDirection: _effectiveIdentityDirection(plan),
        rewardSource: _activeRewardSource,
        sourceType: sourceType,
        sourceId: sourceId,
        dissonanceReductionMode: plan.dissonanceReductionMode,
        effortMinutes: effortMinutes,
        difficultyScore: _difficultyScore,
        startedAtMs: _timerStartedAtMs,
        endedAtMs: endedAt,
      );
      if (plan.sessionId.trim().isNotEmpty) {
        final boundPendingBefore = _preTemperatureLogged
            ? await _dao.bindLatestPendingBeforeTemperature(sessionId: plan.sessionId, evidenceId: evidenceId)
            : 0;
        if (boundPendingBefore <= 0) {
          await _dao.saveDissonanceTemperatureLog(
            sessionId: plan.sessionId,
            evidenceId: evidenceId,
            phase: 'before',
            discomfortScore: _beforeDiscomfortScore,
            guiltScore: _beforeGuiltScore,
            anxietyScore: _beforeAnxietyScore,
            shameScore: _beforeShameScore,
            defensivenessScore: _beforeDefensivenessScore,
            avoidanceUrgeScore: _beforeAvoidanceScore,
            actionWillingnessScore: _beforeActionWillingnessScore,
            note: '行动前失调温度：不适/内疚/焦虑/羞耻/防御/逃避冲动/行动意愿',
          );
        }
        await _dao.saveDissonanceTemperatureLog(
          sessionId: plan.sessionId,
          evidenceId: evidenceId,
          phase: 'after',
          discomfortScore: _afterDiscomfortScore,
          guiltScore: _afterGuiltScore,
          anxietyScore: _afterAnxietyScore,
          shameScore: _afterShameScore,
          defensivenessScore: _afterDefensivenessScore,
          avoidanceUrgeScore: _afterAvoidanceScore,
          clarityScore: _afterClarityScore,
          responsibilityScore: _afterResponsibilityScore,
          actionWillingnessScore: _afterActionWillingnessScore,
          note: '行动后失调温度：不适/内疚/焦虑/羞耻/防御/逃避冲动/清醒感/责任感/行动意愿',
        );
        final logsForEvidence = await _dao.temperatureLogsForEvidence(evidenceId);
        CcDissonanceTemperatureLog? beforeLog;
        CcDissonanceTemperatureLog? afterLog;
        for (final log in logsForEvidence) {
          if (log.phase == 'before' && beforeLog == null) beforeLog = log;
          if (log.phase == 'after' && afterLog == null) afterLog = log;
        }
        final tempReview = await _ai.generateTemperatureReview(
          plannedAction: plan.oneDollarAction,
          completedAction: _doneCtrl.text,
          before: beforeLog,
          after: afterLog,
          dissonanceTypes: plan.dissonanceTypes,
          growthExplanation: plan.growthExplanation,
        ).timeout(const Duration(seconds: 12), onTimeout: () => 'AI 温度复盘超时：已先保存真实行动证据。请稍后在证据卡中重新生成温度复盘，或用本次前后温度手动判断下一步。');
        final discomfortDrop = (beforeLog?.discomfortScore ?? _beforeDiscomfortScore) - (afterLog?.discomfortScore ?? _afterDiscomfortScore);
        final avoidanceDrop = (beforeLog?.avoidanceUrgeScore ?? _beforeAvoidanceScore) - (afterLog?.avoidanceUrgeScore ?? _afterAvoidanceScore);
        final clarityRise = (afterLog?.clarityScore ?? _afterClarityScore) - (beforeLog?.clarityScore ?? 0);
        await _dao.saveTemperatureReviewItem(
          sessionId: plan.sessionId,
          evidenceId: evidenceId,
          reviewText: tempReview,
          repairMode: (discomfortDrop > 0 || avoidanceDrop > 0 || clarityRise > 0) ? 'action_repair' : 'needs_verification',
          nextCoolingAction: plan.nextStep,
        );
        _preTemperatureLogged = false;
      }
      if (plan.informationAvoidanceBranches.hasContent || _selectedCategory == 'information' || _infoActualResultCtrl.text.trim().isNotEmpty) {
        await _dao.saveInformationContactResult(
          sessionId: plan.sessionId,
          evidenceId: evidenceId,
          avoidedInformation: plan.informationAvoidanceBranches.avoidedInformation,
          fearedResult: plan.informationAvoidanceBranches.fearedResult,
          actualResult: _infoActualResultCtrl.text,
          resultType: _infoResultType,
          catastrophizingCheck: _infoCatastropheCtrl.text,
          repairAction: _infoRepairActionCtrl.text.trim().isNotEmpty ? _infoRepairActionCtrl.text : plan.informationAvoidanceBranches.nextInformationAction,
          sourceType: sourceType,
          sourceId: sourceId,
          originScene: 'information_contact_after_action',
          discomfortBefore: _beforeDiscomfortScore,
          discomfortAfter: _afterDiscomfortScore,
        );
      }
      if (plan.identityDialogue.hasContent || _selectedCategory == 'identity') {
        await _dao.saveIdentityTransitionRecord(
          sessionId: plan.sessionId,
          evidenceId: evidenceId,
          oldIdentity: plan.identityDialogue.oldIdentity,
          newIdentity: plan.identityDialogue.newIdentity,
          oldProtection: plan.identityDialogue.oldIdentityProtection,
          fearOfLoss: plan.identityDialogue.fearOfLoss,
          newIdentityAction: plan.identityDialogue.newIdentityAction.trim().isNotEmpty ? plan.identityDialogue.newIdentityAction : _doneCtrl.text,
          postActionIdentitySentence: plan.identityDialogue.postActionIdentitySentence.trim().isNotEmpty ? plan.identityDialogue.postActionIdentitySentence : explanation,
          nextIdentityAction: plan.nextStep,
          sourceType: sourceType,
          sourceId: sourceId,
          originScene: 'identity_transition_after_action',
        );
      }
      final linkedValues = _effectiveValueProfilesForEvidence(plan);
      await _dao.replaceEvidenceValueLinks(
        evidenceId: evidenceId,
        values: linkedValues,
        relationType: _selectedValueProfiles().isNotEmpty ? 'selected' : 'inferred',
      );
      await _dao.mergeSourceValueLinks(
        sourceType: sourceType,
        sourceId: sourceId,
        values: linkedValues,
        relationType: _selectedValueProfiles().isNotEmpty ? 'selected' : 'inferred',
      );
      if (plan.sessionId.trim().isNotEmpty) {
        await _dao.updateSessionStatus(plan.sessionId, 'evidence_saved');
      }
      final activeReportId = _activeReportId.trim().isNotEmpty
          ? _activeReportId.trim()
          : (sourceType == 'cc_report' ? sourceId.trim() : '');
      if (activeReportId.isNotEmpty) {
        await _dao.updateReportAdoption(
          reportId: activeReportId,
          suggestedAction: plan.oneDollarAction,
          adoptedEvidenceId: evidenceId,
        );
        await _dao.updateReportActionLink(
          reportId: activeReportId,
          sessionId: plan.sessionId,
          todoStepId: sourceType == 'todo_goal_step' ? sourceId : '',
          evidenceId: evidenceId,
          status: 'evidence_saved',
          suggestedAction: plan.oneDollarAction,
        );
      }
      if (plan.sessionId.trim().isNotEmpty) {
        await _dao.saveActionTraceLink(fromType: 'cc_session', fromId: plan.sessionId, toType: 'evidence', toId: evidenceId, relationType: 'session_saved_evidence');
      }
      if (sourceType.trim().isNotEmpty && sourceId.trim().isNotEmpty) {
        await _dao.saveActionTraceLink(fromType: sourceType, fromId: sourceId, toType: 'evidence', toId: evidenceId, relationType: 'source_saved_evidence');
      }
      if (_activeValueInsightId.trim().isNotEmpty) {
        await _dao.updateValueRelationInsightLink(insightId: _activeValueInsightId, linkedEvidenceId: evidenceId);
        await _dao.saveActionTraceLink(fromType: 'value_relation_insight', fromId: _activeValueInsightId, toType: 'evidence', toId: evidenceId, relationType: 'insight_validated_by_evidence');
      }
      if (_activeResolutionMethodUsageId.trim().isNotEmpty) {
        await _dao.updateResolutionMethodUsage(
          usageId: _activeResolutionMethodUsageId,
          sessionId: plan.sessionId,
          caseId: plan.sessionId.trim().isNotEmpty ? 'case_${plan.sessionId}' : '',
          evidenceId: evidenceId,
          status: 'evidence_saved',
          producedEvidence: true,
          reducedDissonance: _afterClarityScore >= _beforeActionWillingnessScore || _afterDiscomfortScore < _beforeDiscomfortScore,
        );
        _activeResolutionMethodUsageId = '';
        _activeResolutionMethodWorkflowId = '';
      }
      await _syncTrueSelfEvidenceIfNeeded(
        plan: plan,
        evidenceId: evidenceId,
        completedAction: _doneCtrl.text,
        explanation: explanation,
        sourceType: sourceType,
        sourceId: sourceId,
      );
      await _writeBackToTodoIfNeeded(
        plan: plan,
        evidenceId: evidenceId,
        sourceType: sourceType,
        sourceId: sourceId,
        explanation: explanation,
        effortMinutes: effortMinutes,
      );
      _reflectionCtrl.clear();
      _infoActualResultCtrl.clear();
      _infoCatastropheCtrl.clear();
      _infoRepairActionCtrl.clear();
      _infoResultType = 'ambiguous';
      _changed = true;
      await _load();
      if (!mounted) return;
      _tabs.animateTo(4);
      _toast(_todoWriteBackStatus.isEmpty ? '已写入身份证据账本，并保留 session / 来源链路。' : '已写入身份证据账本。$_todoWriteBackStatus');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveValueProfile() async {
    if (_valueLabelCtrl.text.trim().isEmpty) {
      _toast('请填写一个价值名称。');
      return;
    }
    final editingId = _editingValueId.trim();
    final oldPriority = editingId.isEmpty ? _valueProfiles.length + 1 : _priorityForValue(editingId);
    await _dao.saveValueProfile(
      valueId: editingId,
      valueLabel: _valueLabelCtrl.text.trim(),
      why: _valueWhyCtrl.text.trim(),
      identityDirection: _identityCtrl.text.trim(),
      exampleAction: _valueActionCtrl.text.trim(),
      priority: oldPriority,
    );
    if (_valuesCtrl.text.trim().isEmpty) _valuesCtrl.text = _valueLabelCtrl.text.trim();
    _clearValueEditForm();
    await _load();
    _toast(editingId.isEmpty ? '已保存到价值罗盘。' : '已更新价值罗盘。');
  }

  Future<void> _deleteValue(String id) async {
    setState(() { _selectedValueIds.remove(id); _valueInsight = ''; });
    await _dao.deleteValueProfile(id);
    await _load();
  }

  Future<void> _analyzeExternalReward() async {
    final text = _rewardCtrl.text.trim();
    if (text.isEmpty) {
      _toast('请描述你当前依赖的打卡、奖励、监督或惩罚机制。');
      return;
    }
    setState(() => _rewardBusy = true);
    try {
      final result = await _ai.generateExternalRewardAnalysis(
        rewardContext: text,
        userGoal: _goalCtrl.text,
        userValues: _valuesCtrl.text,
        sourceType: _toolSourceType('external_reward_detox'),
        sourceId: _toolSourceId(),
        originScene: 'external_reward_detox',
      );
      await _linkPlanSessionValues(result);
      if (!mounted) return;
      setState(() => _rewardPlan = result);
    } finally {
      if (mounted) setState(() => _rewardBusy = false);
    }
  }

  Future<void> _runSelfDeceptionCheck() async {
    if (_selfExplanationCtrl.text.trim().isEmpty) {
      _toast('请先写下你正在使用的解释。');
      return;
    }
    setState(() => _selfCheckBusy = true);
    try {
      final result = await _ai.generateSelfDeceptionCheck(
        userExplanation: _selfExplanationCtrl.text,
        knownFacts: _factsCtrl.text,
        userValues: _valuesCtrl.text,
        sourceType: _toolSourceType('self_deception_check'),
        sourceId: _toolSourceId(),
        originScene: 'self_deception_check',
      );
      await _linkPlanSessionValues(result);
      if (!mounted) return;
      setState(() => _selfCheckPlan = result);
    } finally {
      if (mounted) setState(() => _selfCheckBusy = false);
    }
  }

  Future<void> _buildReport() async {
    setState(() {
      _reportBusy = true;
      _report = '正在生成价值一致性报告...';
    });
    try {
      final text = await _ai.generateWeeklyReport(
        _valuesCtrl.text,
        periodLabel: _reportRangeLabel(),
        sinceAtMs: _reportSinceAtMs(),
      );
      await _load();
      if (!mounted) return;
      setState(() => _report = text);
    } finally {
      if (mounted) setState(() => _reportBusy = false);
    }
  }

  void _toggleTimer() {
    if (_timer != null) {
      _timer?.cancel();
      setState(() => _timer = null);
      return;
    }
    setState(() {
      if (_secondsLeft <= 0) _secondsLeft = _timerInitialSeconds;
      if (_timerStartedAtMs <= 0) _timerStartedAtMs = DateTime.now().millisecondsSinceEpoch;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _timer = null;
          _secondsLeft = 0;
        });
        _toast('计时结束：现在记录一个真实证据，而不是评价整个人生。');
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  void _resetTimer() {
    setState(() => _resetTimerInternal());
  }

  void _resetTimerInternal() {
    _timer?.cancel();
    _timer = null;
    _secondsLeft = _timerInitialSeconds;
    _timerStartedAtMs = 0;
    _actualMinutesCtrl.clear();
  }

  void _setTimerDuration(int seconds) {
    setState(() {
      _timerInitialSeconds = seconds;
      _resetTimerInternal();
    });
  }

  int _actualEffortMinutes() {
    final manual = int.tryParse(_actualMinutesCtrl.text.trim());
    if (manual != null && manual > 0) return manual.clamp(1, 600).toInt();
    final elapsed = _timerInitialSeconds - _secondsLeft;
    if (elapsed > 0) return ((elapsed + 59) ~/ 60).clamp(1, 600).toInt();
    return 1;
  }


  void _applyPlan(
    CcPlanResult result, {
    String rewardSource = '',
    String sourceType = '',
    String sourceId = '',
  }) {
    _plan = result;
    _doneCtrl.text = result.oneDollarAction;
    _selectedCategory = _normalizeCategory(result.evidenceCategory);
    _preActionGuidance = '';
    _activeRewardSource = rewardSource;
    _activeSourceType = sourceType.trim().isNotEmpty ? sourceType.trim() : widget.sourceType;
    _activeSourceId = sourceId.trim().isNotEmpty ? sourceId.trim() : widget.sourceId;
    _activeSessionGoal = '';
    _activeSessionContext = '';
    _activeSessionValues = '';
    _todoWriteBackStatus = '';
    _preTemperatureLogged = false;
    _resetTimerInternal();
  }

  void _activatePlan(
    CcPlanResult result, {
    String rewardSource = '',
    String sourceType = '',
    String sourceId = '',
    bool jumpToRunner = true,
  }) {
    setState(() => _applyPlan(result, rewardSource: rewardSource, sourceType: sourceType, sourceId: sourceId));
    if (jumpToRunner) _tabs.animateTo(3);
  }

  void _activateActionVariant(
    CcPlanResult plan,
    String action,
    String label,
    String category, {
    String rewardSource = '',
    String sourceType = '',
    String sourceId = '',
    bool jumpToRunner = true,
  }) {
    final clean = action.trim();
    if (clean.isEmpty) return;
    final variant = plan.copyWith(
      oneDollarAction: clean,
      evidenceLabel: label,
      evidenceCategory: _normalizeCategory(category),
      nextStep: clean,
    );
    _activatePlan(variant, rewardSource: rewardSource, sourceType: sourceType, sourceId: sourceId, jumpToRunner: jumpToRunner);
    _toast('已把“$label”设为当前行动，可计时、写入 Todo 或保存证据。');
  }

  void _activateSession(CcSession session) {
    setState(() {
      _goalCtrl.text = session.userGoal;
      _contextCtrl.text = session.userContext;
      _valuesCtrl.text = session.userValues;
      _activeSessionGoal = session.userGoal;
      _activeSessionContext = session.userContext;
      _activeSessionValues = session.userValues;
      _applyPlan(
        session.result,
        rewardSource: session.rewardSource,
        sourceType: session.sourceType.trim().isNotEmpty ? session.sourceType : 'cc_session',
        sourceId: session.sourceId.trim().isNotEmpty ? session.sourceId : session.sessionId,
      );
      _activeSessionGoal = session.userGoal;
      _activeSessionContext = session.userContext;
      _activeSessionValues = session.userValues;
    });
    _tabs.animateTo(3);
  }

  String _effectiveGoal() {
    if (_goalCtrl.text.trim().isNotEmpty) return _goalCtrl.text.trim();
    if (_activeSessionGoal.trim().isNotEmpty) return _activeSessionGoal.trim();
    final plan = _plan;
    if (plan != null && plan.valueLink.trim().isNotEmpty) return plan.valueLink.trim();
    return '足下一致行动';
  }

  bool get _hasTodoWriteBackSource {
    final sourceType = _activeSourceType.trim().isNotEmpty ? _activeSourceType : widget.sourceType;
    final sourceId = _activeSourceId.trim().isNotEmpty ? _activeSourceId : widget.sourceId;
    return sourceId.trim().isNotEmpty && (sourceType == 'todo_goal_step' || sourceType == 'todo_problem_node');
  }

  bool get _canCreateTodoStepFromCurrentPlan => _plan != null;

  String _toolSourceType(String toolScene) {
    final inherited = _activeSourceType.trim().isNotEmpty ? _activeSourceType.trim() : widget.sourceType.trim();
    return inherited.isNotEmpty ? inherited : toolScene;
  }

  String _toolSourceId() {
    final inherited = _activeSourceId.trim().isNotEmpty ? _activeSourceId.trim() : widget.sourceId.trim();
    return inherited;
  }

  List<String> _extractValueLabelsFromText(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return const <String>[];
    const presets = <String>[
      '成长', '自由', '责任', '健康', '学习', '创造', '自律', '勇气', '真实自我', '关系',
      '复盘', '体验过程', '活在当下', '努力', '自我慈悲', '选择权', '长期主义', '诚实', '边界'
    ];
    final found = <String>{};
    for (final label in presets) {
      if (raw.contains(label)) found.add(label);
    }
    for (final token in raw.split(RegExp(r'[、，,;；|\n]+'))) {
      final cleaned = token.trim();
      if (cleaned.isEmpty) continue;
      if (cleaned.length <= 8 && !cleaned.contains('：') && !cleaned.contains(':') && !cleaned.contains('？') && !cleaned.contains('?')) {
        found.add(cleaned);
      }
    }
    return found.toList(growable: false);
  }


  String _truncate(String text, int max) {
    final clean = text.trim();
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max)}…';
  }

  CcActionVariant _primaryActionVariantForPlan(CcPlanResult plan) {
    final action = plan.oneDollarAction.trim();
    final variants = <CcActionVariant>[
      plan.minimumActionVariant,
      plan.correctiveActionVariant,
      plan.evidenceActionVariant,
    ].where((v) => v.hasContent).toList(growable: false);
    for (final v in variants) {
      if (v.displayText.trim() == action || v.displayTitle.trim() == action || action.contains(v.displayTitle.trim())) return v;
    }
    if (_selectedCategory == 'information' && plan.evidenceActionVariant.hasContent) return plan.evidenceActionVariant;
    if (_selectedCategory == 'responsibility' && plan.correctiveActionVariant.hasContent) return plan.correctiveActionVariant;
    if (plan.minimumActionVariant.hasContent) return plan.minimumActionVariant;
    return CcActionVariant(actionType: 'one_dollar', label: '1美元行动', title: plan.oneDollarAction, rawText: plan.oneDollarAction, completionCriteria: plan.nextStep, linkedValue: plan.valueLink);
  }

  String _todoActionTypeForVariant(CcActionVariant variant) {
    final type = variant.actionType.trim();
    if (_selectedCategory == 'information') return 'information_contact_action';
    if (_selectedCategory == 'identity') return 'identity_proof_action';
    switch (type) {
      case 'minimum':
        return 'minimum_consistency_action';
      case 'corrective':
        return 'corrective_repair_action';
      case 'evidence':
        return 'evidence_action';
      case 'information':
        return 'information_contact_action';
      case 'identity':
        return 'identity_proof_action';
      default:
        return 'value';
    }
  }

  String _todoBriefInsight(CcPlanResult plan) {
    final lines = <String>[];
    if (plan.dissonanceTypes.trim().isNotEmpty) lines.add('失调类型：${plan.dissonanceTypes}');
    if (plan.growthExplanation.trim().isNotEmpty) lines.add('成长性解释：${plan.growthExplanation}');
    if (plan.selfIntegrityCard.trim().isNotEmpty) lines.add('自我完整：${_truncate(plan.selfIntegrityCard, 100)}');
    lines.add('下次验证：${plan.verificationQuestion.trim().isEmpty ? '观察行动后不适/逃避是否下降。' : plan.verificationQuestion}');
    return lines.take(5).join('\n');
  }

  String _todoDetailedInsight(CcPlanResult plan) {
    return _modernTodoInsight(plan);
  }

  Future<void> _createTodoStepFromCurrentPlan() async {
    final plan = _plan;
    if (plan == null) return;
    final actionVariant = _primaryActionVariantForPlan(plan);
    setState(() => _busy = true);
    try {
      TodoGoalActionStep? parent;
      final sourceType = _activeSourceType.trim().isNotEmpty ? _activeSourceType.trim() : widget.sourceType.trim();
      final sourceId = _activeSourceId.trim().isNotEmpty ? _activeSourceId.trim() : widget.sourceId.trim();
      if (sourceType == 'todo_goal_step' && sourceId.isNotEmpty) {
        parent = await _goalDao.getActionStep(sourceId);
      }
      var goals = await _goalDao.listGoals(limit: 80);
      if (parent != null && !goals.any((g) => g.goalId == parent!.goalId)) {
        final parentGoal = await _goalDao.getGoal(parent!.goalId);
        if (parentGoal != null) goals = <TodoGoalProfile>[parentGoal, ...goals];
      }
      if (!mounted) return;
      if (goals.isEmpty && parent == null) {
        _toast('当前没有可写入的 Todo 目标。请先在 Todo 目标系统中创建一个目标。');
        return;
      }
      var selectedGoalId = parent?.goalId ?? (goals.isNotEmpty ? goals.first.goalId : '');
      var selectedDate = _goalDao.todayDate();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            String tomorrowDate() {
              final d = DateTime.now().add(const Duration(days: 1));
              String two(int v) => v.toString().padLeft(2, '0');
              return '${d.year}-${two(d.month)}-${two(d.day)}';
            }
            final allGoals = parent == null
                ? goals
                : <TodoGoalProfile>[
                    ...goals.where((g) => g.goalId == parent!.goalId),
                    ...goals.where((g) => g.goalId != parent!.goalId),
                  ];
            if (allGoals.isNotEmpty && !allGoals.any((g) => g.goalId == selectedGoalId)) selectedGoalId = allGoals.first.goalId;
            return AlertDialog(
              title: const Text('写入 Todo 行动'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('把当前 1 美元行动写入目标系统，作为今天/明天可执行的行动节点。'),
                  const SizedBox(height: 12),
                  Text('行动：${actionVariant.todoTitle}', style: const TextStyle(fontWeight: FontWeight.w800, height: 1.4)),
                  if (actionVariant.steps.isNotEmpty) Text("步骤：${actionVariant.steps.join(' → ')}", style: const TextStyle(height: 1.4)),
                  if (actionVariant.completionCriteria.trim().isNotEmpty) Text('完成标准：${actionVariant.completionCriteria}', style: const TextStyle(height: 1.4)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedGoalId.isEmpty ? null : selectedGoalId,
                    items: allGoals.map((g) => DropdownMenuItem(value: g.goalId, child: Text(g.goalTitle, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setDialogState(() => selectedGoalId = v ?? selectedGoalId),
                    decoration: const InputDecoration(labelText: '写入哪个 Todo 目标'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedDate,
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: _goalDao.todayDate(), child: const Text('今天')),
                      DropdownMenuItem(value: tomorrowDate(), child: const Text('明天')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedDate = v ?? selectedDate),
                    decoration: const InputDecoration(labelText: '计划日期'),
                  ),
                ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
                FilledButton(onPressed: selectedGoalId.trim().isEmpty ? null : () => Navigator.pop(dialogContext, true), child: const Text('写入')),
              ],
            );
          },
        ),
      );
      if (confirmed != true || selectedGoalId.trim().isEmpty) return;
      TodoGoalProfile? goal;
      for (final g in goals) {
        if (g.goalId == selectedGoalId) {
          goal = g;
          break;
        }
      }
      if (goal == null && parent == null) {
        _toast('未找到目标，无法写入。');
        return;
      }
      final newStepId = await _goalDao.createActionStep(
        goalId: selectedGoalId,
        sourceTaskId: parent?.sourceTaskId ?? goal?.sourceTaskId ?? '',
        title: actionVariant.todoTitle,
        minimumStandard: actionVariant.completionCriteria.trim().isNotEmpty ? actionVariant.completionCriteria : (actionVariant.steps.isNotEmpty ? actionVariant.steps.first : actionVariant.todoTitle),
        simplifiedStandard: actionVariant.steps.isNotEmpty ? actionVariant.steps.join(' → ') : actionVariant.displayText,
        recommendedStandard: plan.nextStep.trim().isEmpty ? (actionVariant.completionCriteria.trim().isNotEmpty ? actionVariant.completionCriteria : actionVariant.displayText) : plan.nextStep,
        stretchStandard: '如果状态允许，再轻微升级；如果阻力变大，回到最小充分行动。对应价值：${actionVariant.linkedValue.trim().isEmpty ? plan.valueLink : actionVariant.linkedValue}',
        difficultyScore: (_difficultyScore <= 0 ? 2 : _difficultyScore).clamp(1, 5).toInt(),
        zoneType: 'comfort',
        plannedDate: selectedDate,
        parentStepId: parent?.stepId ?? '',
        sourceNodeId: parent?.sourceNodeId ?? '',
        actionType: _todoActionTypeForVariant(actionVariant),
        experienceIntention: '来自足下一致行动：${actionVariant.label.isEmpty ? '结构化行动' : actionVariant.label}。用最小行动制造真实证据，并在行动后解释为身份线索。',
        completionQuestion: actionVariant.completionCriteria.trim().isEmpty ? '我是否完成了这个 1 美元行动，并留下了一个真实证据？' : actionVariant.completionCriteria,
      );
      final linkedValues = _effectiveValueProfilesForEvidence(plan);
      if (linkedValues.isNotEmpty) {
        await _dao.replaceSourceValueLinks(
          sourceType: 'todo_goal_step',
          sourceId: newStepId,
          values: linkedValues,
          relationType: 'created_from_cc_action',
        );
      }
      await _dao.saveActionTraceLink(fromType: 'cc_session', fromId: plan.sessionId, toType: 'todo_goal_step', toId: newStepId, relationType: 'session_written_to_todo');
      if (_activeValueInsightId.trim().isNotEmpty) {
        await _dao.saveActionTraceLink(fromType: 'value_relation_insight', fromId: _activeValueInsightId, toType: 'todo_goal_step', toId: newStepId, relationType: 'insight_written_to_todo');
      }
      final activeReportId = _activeReportId.trim();
      if (activeReportId.isNotEmpty) {
        await _dao.updateReportActionLink(
          reportId: activeReportId,
          sessionId: plan.sessionId,
          todoStepId: newStepId,
          status: 'todo_step_created',
          suggestedAction: plan.oneDollarAction,
        );
      }
      if (!mounted) return;
      setState(() {
        _activeSourceType = 'todo_goal_step';
        _activeSourceId = newStepId;
        _writeBackToTodo = true;
        _todoWriteBackStatus = '当前行动已切换绑定到新建 Todo 行动，后续保存证据会回写这条 Todo。';
      });
      _changed = true;
      _toast('已把当前 1 美元行动写入 Todo 行动；后续证据将绑定到新建 Todo。');
    } catch (e) {
      _toast('写入 Todo 失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isNegatedSignal(String text) {
    final t = text.trim();
    if (t.isEmpty) return true;
    if (RegExp(r'^(无|没有|无需|不需要|未发现|暂无|不明显)').hasMatch(t)) return true;
    if (RegExp(r'(无明显|没有明显|未发现明显|不构成|不建议|无需进入|不需要进入|没有发现)').hasMatch(t)) return true;
    return false;
  }

  bool _shouldSyncTrueSelfEvidence(CcPlanResult plan) {
    if (plan.usedFallback) return false;
    if (plan.rawResponse.contains('shouldSyncTrueSelf')) return plan.shouldSyncTrueSelf;
    if (plan.shouldSyncTrueSelf) return true;
    final scene = plan.recommendedShameScene.trim();
    final pride = plan.truePrideSentence.trim();
    final shameText = [plan.shameSignal, plan.toxicShameLanguage, plan.healthyShameReframe].join(' ').trim();
    final hasExplicitScene = scene.isNotEmpty && !_isNegatedSignal(scene) && scene != '不需要' && scene != '无';
    final hasPride = pride.isNotEmpty && !_isNegatedSignal(pride) && !pride.contains('不需要');
    final hasStrongShame = !_isNegatedSignal(shameText) &&
        RegExp(r'强烈羞耻|身份审判|内在批判|过度自责|毒性羞耻|想隐藏|攻击自己|真实骄傲|人格否定').hasMatch(shameText);
    return hasExplicitScene || hasPride || hasStrongShame;
  }

  Future<void> _syncTrueSelfEvidenceIfNeeded({
    required CcPlanResult plan,
    required String evidenceId,
    required String completedAction,
    required String explanation,
    String sourceType = '',
    String sourceId = '',
  }) async {
    if (!_shouldSyncTrueSelfEvidence(plan)) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final prideSentence = plan.truePrideSentence.trim().isNotEmpty
        ? plan.truePrideSentence.trim()
        : '我在失调、阻力或羞耻风险中完成了一步真实行动，这是一条真实骄傲证据。';
    final shameEvidenceId = 'cc_shame_${now}_${evidenceId.hashCode.abs()}';
    final item = EvidenceItem(
      id: shameEvidenceId,
      createdAt: now,
      action: completedAction.trim().isEmpty ? plan.oneDollarAction : completedAction.trim(),
      identityEvidence: explanation.trim().isEmpty ? plan.postActionExplanation : explanation.trim(),
      valueAnchor: _effectiveValueLink(plan),
      sourceEventId: plan.sessionId,
      shameRiskCarried: plan.toxicShameLanguage.trim().isEmpty ? plan.shameSignal : plan.toxicShameLanguage,
      compassTurn: plan.recommendedShameScene.trim().isEmpty ? '一致行动 → 真实骄傲' : plan.recommendedShameScene,
      positiveAffectRestored: '真实骄傲、选择感、责任感',
      abilityReflected: plan.identityDirection.trim().isEmpty ? '在不舒服中仍然完成最小行动' : plan.identityDirection,
      truePrideSentence: prideSentence,
    );
    try {
      await _shameDao.saveEvidence(item);
      await _dao.saveTrueSelfLink(
        ccSessionId: plan.sessionId,
        ccEvidenceId: evidenceId,
        shameEventId: sourceType == 'shame_transform_result' ? sourceId : '',
        shameEvidenceId: shameEvidenceId,
        linkType: sourceType == 'shame_transform_result' ? 'true_self_result_cc_evidence_backlink' : 'cc_evidence_to_true_pride',
        truePrideSentence: prideSentence,
      );
    } catch (e) {
      _todoWriteBackStatus = '${_todoWriteBackStatus} 真实自我同步未完成，但一致行动证据已保存：$e';
    }
  }


  String _postActionV18Context(CcPlanResult plan) {
    final parts = <String>[];
    if (plan.dissonanceTypes.trim().isNotEmpty) parts.add('失调类型：${plan.dissonanceTypes}');
    if (plan.dissonanceIntensityScore > 0 || plan.dissonanceIntensityLevel.trim().isNotEmpty) {
      parts.add('失调强度：${plan.dissonanceIntensityLevel} ${plan.dissonanceIntensityScore}/24；来源：${plan.dissonanceIntensityMainSources}');
    }
    if (plan.defensiveExplanation.trim().isNotEmpty) parts.add('防御性解释：${plan.defensiveExplanation}');
    if (plan.growthExplanation.trim().isNotEmpty) parts.add('成长性解释：${plan.growthExplanation}');
    if (plan.selfIntegrityCard.trim().isNotEmpty) parts.add('自我完整卡：${plan.selfIntegrityCard}');
    if (plan.informationAvoidanceBranches.hasContent) parts.add('信息回避结果分支：${plan.informationAvoidanceBranches.displayText}');
    if (plan.identityDialogue.hasContent) parts.add('身份冲突对话：${plan.identityDialogue.displayText}');
    parts.add('行动前温度：不适$_beforeDiscomfortScore/10、内疚$_beforeGuiltScore/10、焦虑$_beforeAnxietyScore/10、羞耻$_beforeShameScore/10、防御$_beforeDefensivenessScore/10、逃避$_beforeAvoidanceScore/10、意愿$_beforeActionWillingnessScore/10。');
    parts.add('行动后温度：不适$_afterDiscomfortScore/10、内疚$_afterGuiltScore/10、焦虑$_afterAnxietyScore/10、羞耻$_afterShameScore/10、防御$_afterDefensivenessScore/10、逃避$_afterAvoidanceScore/10、清醒$_afterClarityScore/10、责任$_afterResponsibilityScore/10、意愿$_afterActionWillingnessScore/10。');
    return parts.where((e) => e.trim().isNotEmpty).join('\n');
  }

  String _modernTodoInsight(CcPlanResult plan) {
    final parts = <String>[];
    if (plan.notUserResponsibility.trim().isNotEmpty || plan.userResponsibility.trim().isNotEmpty) {
      parts.add('责任边界：我负责「${plan.userResponsibility}」；不背负「${plan.notUserResponsibility}」');
    }
    if (plan.adjustedStandard.trim().isNotEmpty) parts.add('自我标准：${plan.adjustedStandard}');
    if (plan.rationalizationTypes.trim().isNotEmpty) parts.add('合理化风险：${plan.rationalizationTypes}');
    if (plan.sunkCostCheck.trim().isNotEmpty) parts.add('沉没成本检查：${plan.sunkCostCheck}');
    if (plan.hypocrisyInduction.trim().isNotEmpty) parts.add('价值—行为距离：${plan.hypocrisyInduction}');
    if (plan.groupConflict.trim().isNotEmpty) parts.add('群体/文化冲突：${plan.groupConflict}');
    if (plan.vicariousDissonance.trim().isNotEmpty) parts.add('替代性失调：${plan.vicariousDissonance}');
    if (plan.dissonanceTypes.trim().isNotEmpty) parts.add('V18失调类型：${plan.dissonanceTypes}');
    if (plan.dissonanceIntensityScore > 0 || plan.dissonanceIntensityLevel.trim().isNotEmpty) parts.add('V18失调强度：${plan.dissonanceIntensityLevel} ${plan.dissonanceIntensityScore}/24 ${plan.dissonanceIntensityMainSources}');
    if (plan.defensiveExplanation.trim().isNotEmpty) parts.add('防御性解释：${plan.defensiveExplanation}');
    if (plan.growthExplanation.trim().isNotEmpty) parts.add('成长性解释：${plan.growthExplanation}');
    if (plan.selfIntegrityCard.trim().isNotEmpty) parts.add('自我完整卡：${plan.selfIntegrityCard}');
    if (plan.informationAvoidanceBranches.hasContent) parts.add('信息回避挑战：${plan.informationAvoidanceBranches.displayText}');
    else if (plan.informationAvoidance.trim().isNotEmpty) parts.add('信息回避挑战：${plan.informationAvoidance}');
    if (plan.identityDialogue.hasContent) parts.add('身份冲突重构：${plan.identityDialogue.displayText}');
    else if (plan.identityConflict.trim().isNotEmpty) parts.add('身份冲突重构：${plan.identityConflict}');
    if (plan.minimumActionVariant.hasContent || plan.correctiveActionVariant.hasContent || plan.evidenceActionVariant.hasContent || plan.minimumAction.trim().isNotEmpty || plan.correctiveAction.trim().isNotEmpty || plan.evidenceAction.trim().isNotEmpty) {
      parts.add('三类行动组：最小行动「${plan.minimumActionVariant.hasContent ? plan.minimumActionVariant.displayText : plan.minimumAction}」；修正行动「${plan.correctiveActionVariant.hasContent ? plan.correctiveActionVariant.displayText : plan.correctiveAction}」；证据行动「${plan.evidenceActionVariant.hasContent ? plan.evidenceActionVariant.displayText : plan.evidenceAction}」');
    }
    final tempChange = '行动前不适$_beforeDiscomfortScore/10、逃避$_beforeAvoidanceScore/10；行动后不适$_afterDiscomfortScore/10、逃避$_afterAvoidanceScore/10、清醒$_afterClarityScore/10。';
    parts.add('失调温度变化：$tempChange');
    if (plan.todoWriteBackInsight.trim().isNotEmpty) parts.add(plan.todoWriteBackInsight.trim());
    return parts.join('\n');
  }

  Future<void> _writeBackToTodoIfNeeded({
    required CcPlanResult plan,
    required String evidenceId,
    required String sourceType,
    required String sourceId,
    required String explanation,
    required int effortMinutes,
  }) async {
    _todoWriteBackStatus = '';
    if (!_writeBackToTodo || sourceId.trim().isEmpty) return;
    try {
      final modernInsight = _todoBriefInsight(plan);
      final modernDetail = _todoDetailedInsight(plan);
      if (sourceType == 'todo_goal_step') {
        final step = await _goalDao.getActionStep(sourceId.trim());
        if (step == null) {
          _todoWriteBackStatus = '但未找到对应 Todo 今日行动，未回写。';
          return;
        }
        await _goalDao.recordActionEffort(
          step: step,
          effortMinutes: effortMinutes,
          painScore: _difficultyScore,
          gainScore: plan.valueLink.trim().isEmpty ? 0 : 3,
          returnKind: _selectedCategory == 'recovery' ? 'break' : '',
          attentionReturnCount: _selectedCategory == 'recovery' ? 1 : 0,
          obstacle: [plan.oldStory, plan.honestReframe].where((e) => e.trim().isNotEmpty).join('\n'),
          strategyUsed: ['足下一致行动：${_primaryActionVariantForPlan(plan).displayText}', modernInsight].where((e) => e.trim().isNotEmpty).join('\n'),
          smallProgress: _doneCtrl.text,
          timeInLearning: [explanation, modernInsight, '完整一致行动详情：\n$modernDetail'].where((e) => e.trim().isNotEmpty).join('\n'),
        );
        await _goalDao.addReflection(
          goalId: step.goalId,
          stepId: step.stepId,
          whatDone: _doneCtrl.text,
          whyDone: plan.valueLink,
          processExperience: _reflectionCtrl.text,
          obstacle: plan.oldStory,
          tomorrowNextStep: plan.nextStep,
          aiSummary: '来自足下一致行动证据 $evidenceId：$explanation${modernInsight.trim().isEmpty ? '' : '\n一致行动简版摘要：$modernInsight'}',
          moodScore: 0,
          meaningScore: plan.valueLink.trim().isEmpty ? 0 : 3,
          processScore: 3,
          cognition: [plan.dissonancePoint, modernInsight].where((e) => e.trim().isNotEmpty).join('\n'),
          coreValue: plan.valueLink,
          actionExperiment: _primaryActionVariantForPlan(plan).displayText,
          actionEvidence: plan.evidenceLabel,
          reviewMode: 'cognitive_consistency',
        );
        if (_markTodoCompleted) await _goalDao.completeStep(step.stepId);
        _todoWriteBackStatus = _markTodoCompleted ? '已回写 Todo 努力账本、复盘，并标记今日行动完成。' : '已回写 Todo 努力账本与复盘，今日行动保持进行中。';
      } else if (sourceType == 'todo_problem_node') {
        final node = await _goalDao.getProblemNode(sourceId.trim());
        if (node == null) {
          _todoWriteBackStatus = '但未找到对应问题树节点，未回写。';
          return;
        }
        await _goalDao.recordProblemNodeEffort(
          node: node,
          effortMinutes: effortMinutes,
          painScore: _difficultyScore,
          gainScore: plan.valueLink.trim().isEmpty ? 0 : 3,
          returnKind: _selectedCategory == 'recovery' ? 'break' : '',
          attentionReturnCount: _selectedCategory == 'recovery' ? 1 : 0,
          obstacle: [plan.oldStory, plan.honestReframe].where((e) => e.trim().isNotEmpty).join('\n'),
          strategyUsed: ['足下一致行动：${_primaryActionVariantForPlan(plan).displayText}', modernInsight].where((e) => e.trim().isNotEmpty).join('\n'),
          smallProgress: _doneCtrl.text,
          timeInLearning: [explanation, modernInsight, '完整一致行动详情：\n$modernDetail'].where((e) => e.trim().isNotEmpty).join('\n'),
        );
        if (_markTodoCompleted) await _goalDao.updateProblemNodeStatus(node.nodeId, 'completed', completionNote: '由足下一致行动证据 $evidenceId 完成：${_doneCtrl.text}${modernInsight.trim().isEmpty ? '' : '\n$modernInsight'}');
        _todoWriteBackStatus = _markTodoCompleted ? '已回写问题树节点努力，并标记节点完成。' : '已回写问题树节点努力，节点保持进行中。';
      }
    } catch (e) {
      _todoWriteBackStatus = '但回写 Todo/问题树失败：$e';
    }
  }

  Future<void> _generateActionFromReport(CcReportRecord report) async {
    setState(() {
      _reportBusy = true;
      _status = '正在根据报告生成下一步 1 美元行动...';
    });
    try {
      final inheritedSourceType = _activeSourceType.trim().isNotEmpty ? _activeSourceType.trim() : widget.sourceType.trim();
      final inheritedSourceId = _activeSourceId.trim().isNotEmpty ? _activeSourceId.trim() : widget.sourceId.trim();
      final result = await _ai.generateTargetToAction(
        userGoal: '根据${report.periodLabel}价值一致性报告生成下一步最小充分行动',
        userContext: report.reportText,
        userValues: report.userValues.trim().isEmpty ? _valuesCtrl.text : report.userValues,
        sourceType: inheritedSourceType.isNotEmpty ? inheritedSourceType : 'cc_report',
        sourceId: inheritedSourceId.isNotEmpty ? inheritedSourceId : report.reportId,
        originScene: 'report_next_action',
      );
      await _dao.updateReportAdoption(reportId: report.reportId, suggestedAction: result.oneDollarAction);
      await _dao.saveReportActionLink(
        reportId: report.reportId,
        sessionId: result.sessionId,
        status: 'suggested',
        suggestedAction: result.oneDollarAction,
      );
      await _linkPlanSessionValues(result);
      if (!mounted) return;
      setState(() {
        _activeReportId = report.reportId;
        _goalCtrl.text = '根据${report.periodLabel}报告继续行动';
        _contextCtrl.text = report.reportText;
        if (report.userValues.trim().isNotEmpty) _valuesCtrl.text = report.userValues;
        _applyPlan(
          result,
          sourceType: inheritedSourceType.isNotEmpty ? inheritedSourceType : 'cc_report',
          sourceId: inheritedSourceId.isNotEmpty ? inheritedSourceId : report.reportId,
        );
        _status = result.usedFallback
            ? '已根据报告生成本地兜底行动。若本页来自 Todo/问题树，保存证据时会追踪这份报告建议是否被执行。'
            : '已根据报告生成下一步行动。若本页来自 Todo/问题树，保存证据时会追踪这份报告建议是否被执行。';
      });
      _tabs.animateTo(3);
      await _load();
    } finally {
      if (mounted) setState(() => _reportBusy = false);
    }
  }

  List<CcValueProfile> _selectedValueProfiles() {
    final selected = _valueProfiles.where((v) => _selectedValueIds.contains(v.valueId)).toList(growable: false);
    selected.sort((a, b) => a.priority.compareTo(b.priority));
    return selected;
  }

  String _joinClean(Iterable<String> parts, {String separator = '、'}) {
    return parts.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().join(separator);
  }

  String _composeSelectedValuesText(List<CcValueProfile> selected) {
    if (selected.isEmpty) return '';
    final labels = _joinClean(selected.map((e) => e.valueLabel));
    final identities = _joinClean(selected.map((e) => e.identityDirection));
    final whys = selected
        .where((e) => e.why.trim().isNotEmpty)
        .map((e) => '${e.valueLabel}：${e.why.trim()}')
        .join('\n');
    final actions = selected
        .where((e) => e.exampleAction.trim().isNotEmpty)
        .map((e) => '${e.valueLabel}：${e.exampleAction.trim()}')
        .join('\n');
    return [
      if (labels.isNotEmpty) '多价值组合：$labels',
      if (identities.isNotEmpty) '身份方向：$identities',
      if (whys.isNotEmpty) '为什么重要：\n$whys',
      if (actions.isNotEmpty) '可选最小行动：\n$actions',
    ].join('\n');
  }

  String _selectedExampleActionsText(List<CcValueProfile> selected) {
    final actions = selected.where((e) => e.exampleAction.trim().isNotEmpty).map((e) => e.exampleAction.trim()).toList(growable: false);
    if (actions.isEmpty) return '';
    return actions.length == 1 ? actions.first : '从这些价值中选择一个最小行动：${actions.join('；')}';
  }

  void _applySelectedValuesToRadar({bool jumpToRadar = true}) {
    final selected = _selectedValueProfiles();
    if (selected.isEmpty) {
      _toast('请先在价值罗盘中勾选一个或多个价值。');
      return;
    }
    final composed = _composeSelectedValuesText(selected);
    final exampleActions = _selectedExampleActionsText(selected);
    setState(() {
      _valuesCtrl.text = composed;
      if (_goalCtrl.text.trim().isEmpty && exampleActions.isNotEmpty) {
        _goalCtrl.text = exampleActions;
      }
      _status = '已带入 ${selected.length} 个价值：${_joinClean(selected.map((e) => e.valueLabel))}。';
    });
    if (jumpToRadar) _tabs.animateTo(1);
  }

  Future<void> _generateFromSelectedValues() async {
    _applySelectedValuesToRadar(jumpToRadar: false);
    if (_selectedValueProfiles().isEmpty) return;
    _tabs.animateTo(1);
    await _generate();
  }

  String _effectiveValueLink(CcPlanResult plan) {
    if (plan.valueLink.trim().isNotEmpty) return plan.valueLink.trim();
    if (_activeSessionValues.trim().isNotEmpty) return _activeSessionValues.trim();
    return _valuesCtrl.text.trim();
  }

  String _effectiveIdentityDirection(CcPlanResult plan) {
    if (plan.identityDirection.trim().isNotEmpty) return plan.identityDirection.trim();
    final selectedIdentities = _joinClean(_selectedValueProfiles().map((e) => e.identityDirection));
    if (selectedIdentities.isNotEmpty) return selectedIdentities;
    return '';
  }

  List<CcValueProfile> _effectiveValueProfilesForEvidence(CcPlanResult plan) {
    final selected = _selectedValueProfiles();
    if (selected.isNotEmpty) return selected;
    final text = [
      _valuesCtrl.text,
      _activeSessionValues,
      plan.valueLink,
      plan.identityDirection,
      plan.believedValue,
      plan.coreConflict,
    ].join('\n').toLowerCase();
    final matched = _valueProfiles.where((value) {
      final label = value.valueLabel.trim().toLowerCase();
      final identity = value.identityDirection.trim().toLowerCase();
      return (label.isNotEmpty && text.contains(label)) || (identity.isNotEmpty && text.contains(identity));
    }).toList(growable: false);
    return matched;
  }

  Map<String, List<CcEvidenceValueLink>> _linksByEvidenceId() {
    final map = <String, List<CcEvidenceValueLink>>{};
    for (final link in _valueLinks) {
      map.putIfAbsent(link.evidenceId, () => <CcEvidenceValueLink>[]).add(link);
    }
    return map;
  }

  List<CcEvidenceRecord> _evidenceForValue(CcValueProfile value) {
    final linkedEvidenceIds = _valueLinks
        .where((link) => link.valueId == value.valueId)
        .map((link) => link.evidenceId)
        .toSet();
    if (linkedEvidenceIds.isNotEmpty) {
      return _allEvidence.where((e) => linkedEvidenceIds.contains(e.evidenceId)).toList(growable: false);
    }
    final label = value.valueLabel.trim().toLowerCase();
    final identity = value.identityDirection.trim().toLowerCase();
    if (label.isEmpty && identity.isEmpty) return <CcEvidenceRecord>[];
    return _allEvidence.where((e) {
      final text = '${e.valueLink}\n${e.identityDirection}\n${e.userGoal}'.toLowerCase();
      return (label.isNotEmpty && text.contains(label)) || (identity.isNotEmpty && text.contains(identity));
    }).toList(growable: false);
  }

  Iterable<String> _valueLabelsFromText(String text) sync* {
    final raw = text.trim();
    if (raw.isEmpty) return;
    final lines = raw.split('\n');
    for (final line in lines) {
      var current = line.trim();
      if (current.startsWith('多价值组合：')) current = current.substring('多价值组合：'.length);
      if (current.startsWith('价值：')) current = current.substring('价值：'.length);
      if (current.startsWith('身份方向：')) continue;
      if (current.startsWith('为什么重要：')) continue;
      if (current.startsWith('可选最小行动：')) continue;
      if (current.contains('：') && !current.contains('、') && !current.contains(',')) {
        current = current.split('：').first.trim();
      }
      for (final part in current.split(RegExp(r'[、，,;；/\|]+'))) {
        final value = part.trim();
        if (value.isNotEmpty && value.length <= 24) yield value;
      }
    }
  }

  Map<String, int> _valueCountsForEvidence(List<CcEvidenceRecord> records) {
    final recordIds = records.map((e) => e.evidenceId).toSet();
    final counts = <String, int>{};
    for (final link in _valueLinks) {
      if (!recordIds.contains(link.evidenceId)) continue;
      final key = link.valueLabel.trim();
      if (key.isNotEmpty) counts[key] = (counts[key] ?? 0) + 1;
    }
    if (counts.isNotEmpty) return counts;
    for (final e in records) {
      for (final label in _valueLabelsFromText(e.valueLink)) {
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> _scanSelectedValueRelations() async {
    final selected = _selectedValueProfiles();
    if (selected.length < 2) {
      _toast('请至少勾选两个价值，再扫描协同与冲突。');
      return;
    }
    final fallback = _composeValueRelationInsight(selected);
    setState(() {
      _valueInsightBusy = true;
      _valueInsight = '正在结合当前目标、上下文和行动证据扫描多价值协同/冲突...';
    });
    try {
      final recent = _allEvidence.take(8).map((e) => '- ${e.completedAction}｜价值：${e.valueLink}｜旧解释：${e.oldStory}').join('\n');
      final text = await _ai.generateValueRelationInsight(
        selectedValues: _composeSelectedValuesText(selected),
        userGoal: _goalCtrl.text,
        userContext: _contextCtrl.text,
        recentEvidence: recent.isEmpty ? '暂无' : recent,
      );
      final finalText = text.trim().isEmpty ? fallback : text.trim();
      final insightId = await _dao.saveValueRelationInsight(
        selectedValues: selected,
        userGoal: _goalCtrl.text,
        userContext: _contextCtrl.text,
        insightText: finalText,
      );
      _activeValueInsightId = insightId;
      if (!mounted) return;
      setState(() => _valueInsight = finalText);
      await _load();
    } catch (_) {
      final insightId = await _dao.saveValueRelationInsight(
        selectedValues: selected,
        userGoal: _goalCtrl.text,
        userContext: _contextCtrl.text,
        insightText: fallback,
      );
      _activeValueInsightId = insightId;
      if (mounted) setState(() => _valueInsight = fallback);
      await _load();
    } finally {
      if (mounted) setState(() => _valueInsightBusy = false);
    }
  }

  String _composeValueRelationInsight(List<CcValueProfile> selected) {
    final labels = selected.map((e) => e.valueLabel.trim()).where((e) => e.isNotEmpty).toList(growable: false);
    final identities = _joinClean(selected.map((e) => e.identityDirection));
    final actions = selected.map((e) => e.exampleAction.trim()).where((e) => e.isNotEmpty).toList(growable: false);
    final pairTips = <String>[];
    void tip(String a, String b, String text) {
      final hasA = labels.any((v) => v.contains(a));
      final hasB = labels.any((v) => v.contains(b));
      if (hasA && hasB) pairTips.add('「$a × $b」：$text');
    }
    tip('成长', '健康', '避免用高强度成长牺牲睡眠和身体；行动要小到不会破坏恢复。');
    tip('责任', '自由', '把责任拆成清楚边界内的一小步，让“我选择承担”替代“我被迫承担”。');
    tip('学习', '创造', '先学一个概念，再产出一个微作品或一句自己的解释，避免只输入不输出。');
    tip('自律', '真实自我', '自律不能变成自我攻击；用真实可承受的小行动替代羞耻驱动。');
    tip('勇气', '安全', '勇气不是盲目冒险，可以选择可逆、低成本、可撤回的暴露行动。');
    tip('自由', '健康', '自由不是透支身体；真正的自由需要能量、睡眠和清醒选择。');
    final evidenceCounts = <String>[];
    for (final value in selected) {
      final rows = _evidenceForValue(value);
      evidenceCounts.add('${value.valueLabel}：${rows.length}条证据');
    }
    final buffer = StringBuffer();
    buffer.writeln('【多价值组合】${labels.join('、')}');
    if (identities.isNotEmpty) buffer.writeln('【共同身份方向】$identities');
    buffer.writeln('【协同点】这些价值不必同时做大，可以压缩成一个“共同服务多个价值”的小行动。');
    if (pairTips.isEmpty) {
      buffer.writeln('【可能冲突】没有识别到固定冲突模板。建议选择一个主价值，再选择一个护栏价值：主价值决定行动方向，护栏价值限制行动代价。');
    } else {
      buffer.writeln('【可能冲突与护栏】');
      for (final item in pairTips) buffer.writeln('- $item');
    }
    if (actions.isNotEmpty) buffer.writeln('【可组合的最小行动】${actions.join('；')}');
    buffer.writeln('【已有证据】${evidenceCounts.join('；')}');
    buffer.writeln('【1美元行动原则】只设计一个可在5分钟内开始的动作；它可以优先服务一个价值，同时不伤害另一个价值。');
    return buffer.toString().trim();
  }

  int _priorityForValue(String valueId) {
    for (final value in _valueProfiles) {
      if (value.valueId == valueId) return value.priority;
    }
    return _valueProfiles.length + 1;
  }

  void _editValue(CcValueProfile value) {
    setState(() {
      _editingValueId = value.valueId;
      _valueLabelCtrl.text = value.valueLabel;
      _valueWhyCtrl.text = value.why;
      _identityCtrl.text = value.identityDirection;
      _valueActionCtrl.text = value.exampleAction;
    });
  }

  void _clearValueEditForm() {
    _editingValueId = '';
    _valueLabelCtrl.clear();
    _valueWhyCtrl.clear();
    _identityCtrl.clear();
    _valueActionCtrl.clear();
  }

  int? _reportSinceAtMs() {
    final now = DateTime.now();
    if (_reportRange == 'last7') return now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    if (_reportRange == 'last30') return now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    if (_reportRange == 'thisMonth') return DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    return null;
  }

  String _reportRangeLabel() {
    if (_reportRange == 'last7') return '最近7天';
    if (_reportRange == 'last30') return '最近30天';
    if (_reportRange == 'thisMonth') return '本月';
    return '全部行动证据';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }


  Future<void> _clearAllModuleData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空足下一致行动数据？'),
        content: const Text('这会删除本模块内的价值档案、AI session、行动证据、报告、价值洞察、有效模式、触发建议和追踪链路。Todo 原目标/行动本身不会被删除。此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _dao.clearAllCognitiveConsistencyData();
      _timer?.cancel();
      _goalCtrl.text = widget.initialGoal;
      _contextCtrl.text = widget.initialContext;
      _valuesCtrl.text = widget.initialValues;
      _doneCtrl.clear();
      _reflectionCtrl.clear();
      _hesitationCtrl.clear();
      _rewardCtrl.clear();
      _selfExplanationCtrl.clear();
      _factsCtrl.clear();
      _valueLabelCtrl.clear();
      _valueWhyCtrl.clear();
      _identityCtrl.clear();
      _valueActionCtrl.clear();
      _actualMinutesCtrl.clear();
      if (!mounted) return;
      setState(() {
        _status = '已清空足下一致行动模块数据。';
        _preActionGuidance = '';
        _report = '';
        _todoWriteBackStatus = '';
        _valueInsight = '';
        _activeReportId = '';
        _activeValueInsightId = '';
        _plan = null;
        _rewardPlan = null;
        _selfCheckPlan = null;
        _evidence = <CcEvidenceRecord>[];
        _allEvidence = <CcEvidenceRecord>[];
        _valueProfiles = <CcValueProfile>[];
        _valueLinks = <CcEvidenceValueLink>[];
        _reports = <CcReportRecord>[];
        _sessions = <CcSession>[];
        _valueRelationHistory = <CcValueRelationInsightRecord>[];
        _effectivePatterns = <CcEffectivePatternRecord>[];
        _selectedValueIds.clear();
        _initialValueLinksEnsured = true;
        _editingValueId = '';
        _activeRewardSource = '';
        _activeSourceType = '';
        _activeSourceId = '';
        _activeSessionGoal = '';
        _activeSessionContext = '';
        _activeSessionValues = '';
        _changed = true;
      });
      _toast('已清空本模块数据。');
    } catch (e) {
      _toast('清空失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markEffectivePattern(CcEvidenceRecord evidence) async {
    try {
      await _dao.saveEffectivePattern(evidence: evidence);
      await _load();
      if (!mounted) return;
      setState(() => _changed = true);
      _toast('已沉淀为有效模式，后续可在证据账本中复用。');
    } catch (e) {
      _toast('标记有效模式失败：$e');
    }
  }

  Future<void> _openEvidenceTrace(CcEvidenceRecord evidence) async {
    final traceFuture = _dao.traceLinksFor(type: 'evidence', id: evidence.evidenceId);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('行动追踪链路'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<CcActionTraceLink>>(
            future: traceFuture,
            builder: (context, snapshot) {
              final rows = snapshot.data ?? const <CcActionTraceLink>[];
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (rows.isEmpty) {
                return const Text('暂无追踪链路。新的报告、session、Todo、证据和有效模式会逐步沉淀到这里。');
              }
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rows.map((link) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('• ${link.fromType}:${link.fromId}  →  ${link.toType}:${link.toId}\n  关系：${link.relationType.isEmpty ? '关联' : link.relationType}', style: const TextStyle(height: 1.35)),
                  )).toList(growable: false),
                ),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('关闭'))],
      ),
    );
  }

  Widget _effectivePatternsCard() {
    if (_effectivePatterns.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('有效模式库', style: TextStyle(fontWeight: FontWeight.w900)),
            SizedBox(height: 6),
            Text('把某条行动证据标记为有效模式后，它会沉淀到这里，帮助你复用“曾经真的有效”的行动方式。', style: TextStyle(height: 1.45, color: Color(0xFF6B7280))),
          ]),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome_outlined, color: Color(0xFF7C3AED)),
            const SizedBox(width: 8),
            Expanded(child: Text('有效模式库 ${_effectivePatterns.length} 条', style: const TextStyle(fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 8),
          ..._effectivePatterns.take(5).map((p) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEDE9FE))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.actionTemplate.isEmpty ? '一条有效行动模式' : p.actionTemplate, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.35)),
              if (p.valueLabels.isNotEmpty) Text('价值：${p.valueLabels}', style: const TextStyle(fontSize: 12, color: Color(0xFF5B21B6))),
              if (p.oldStory.isNotEmpty) Text('曾打破：${p.oldStory}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
              if (p.successReason.isNotEmpty) Text('有效原因：${p.successReason}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
            ]),
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_changed);
        return false;
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('足下认知一致性'),
        actions: [
          IconButton(
            tooltip: 'AI 提示词配置',
            icon: const Icon(Icons.tune_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AiPromptSettingsPage(initialModuleId: 'cognitive_consistency', initialPromptId: 'cc_global'),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: '价值罗盘'),
            Tab(text: '失调雷达'),
            Tab(text: '专项场景'),
            Tab(text: '行动陪伴'),
            Tab(text: '证据账本'),
            Tab(text: '奖励降噪'),
            Tab(text: '诚实校验'),
            Tab(text: '一致性报告'),
            Tab(text: '源书工作台'),
            Tab(text: '解决方法'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildValueCompassTab(),
          _buildRadarTab(),
          _buildSpecialScenesTab(),
          _buildRunnerTab(),
          _buildEvidenceTab(),
          _buildRewardTab(),
          _buildSelfCheckTab(),
          _buildReportTab(),
          _buildSourcebookWorkbenchTab(),
          _buildDissonanceResolutionMethodsTab(),
        ],
      ),
    ));
  }

  Widget _featureAccessCard() {
    final items = <({String label, IconData icon, int tab})>[
      (label: '失调雷达', icon: Icons.radar_outlined, tab: 1),
      (label: '专项场景', icon: Icons.alt_route_outlined, tab: 2),
      (label: '行动陪伴', icon: Icons.timer_outlined, tab: 3),
      (label: '证据账本', icon: Icons.inventory_2_outlined, tab: 4),
      (label: '奖励降噪', icon: Icons.card_giftcard_outlined, tab: 5),
      (label: '诚实校验', icon: Icons.fact_check_outlined, tab: 6),
      (label: '一致性报告', icon: Icons.assessment_outlined, tab: 7),
      (label: '源书工作台', icon: Icons.hub_outlined, tab: 8),
      (label: '解决方法', icon: Icons.psychology_alt_outlined, tab: 9),
    ];
    return Card(
      color: const Color(0xFFFFFBEB),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('功能入口', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('顶部标签栏可以左右滑动。也可以从这里直接进入源书工作台、解决方法、失调雷达、专项场景、奖励降噪、诚实校验、价值报告等功能。', style: TextStyle(height: 1.45, color: Color(0xFF6B7280))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...items.map((item) => OutlinedButton.icon(
                onPressed: () => _tabs.animateTo(item.tab),
                icon: Icon(item.icon, size: 18),
                label: Text(item.label),
              )),
              OutlinedButton.icon(
                onPressed: _clearAllModuleData,
                icon: const Icon(Icons.delete_forever_outlined, size: 18),
                label: const Text('清空本模块数据'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB91C1C)),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  bool _isSuggestedValueSelected(String label) {
    final target = label.trim();
    if (target.isEmpty) return false;
    return _valueProfiles.any((profile) =>
      profile.valueLabel.trim() == target && _selectedValueIds.contains(profile.valueId));
  }

  Future<void> _toggleSuggestedValue(String label, bool checked) async {
    final target = label.trim();
    if (target.isEmpty) return;
    final existing = _valueProfiles.where((profile) => profile.valueLabel.trim() == target).toList(growable: false);
    if (checked) {
      var valueId = existing.isNotEmpty ? existing.first.valueId : '';
      if (valueId.isEmpty) {
        valueId = await _dao.saveValueProfile(
          valueLabel: target,
          why: '',
          identityDirection: '',
          exampleAction: '',
          priority: _valueProfiles.length + 1,
        );
        await _load();
      }
      if (!mounted) return;
      setState(() {
        _selectedValueIds.add(valueId);
        _valueLabelCtrl.text = target;
        _valueInsight = '';
        _status = '已选择价值：$target。可以继续勾选其他价值，然后带入失调雷达或直接生成行动。';
      });
    } else {
      if (!mounted) return;
      setState(() {
        for (final profile in existing) {
          _selectedValueIds.remove(profile.valueId);
        }
        _valueInsight = '';
        _status = '已取消选择价值：$target。';
      });
    }
  }


  Future<void> _selectAllSuggestedValues(List<String> labels) async {
    final ids = <String>[];
    var created = false;
    for (final raw in labels) {
      final target = raw.trim();
      if (target.isEmpty) continue;
      final existing = _valueProfiles.where((profile) => profile.valueLabel.trim() == target).toList(growable: false);
      if (existing.isNotEmpty) {
        ids.add(existing.first.valueId);
      } else {
        final id = await _dao.saveValueProfile(
          valueLabel: target,
          why: '',
          identityDirection: '',
          exampleAction: '',
          priority: _valueProfiles.length + ids.length + 1,
        );
        ids.add(id);
        created = true;
      }
    }
    if (created) {
      await _load();
    }
    if (!mounted) return;
    setState(() {
      _selectedValueIds.addAll(ids);
      _valueInsight = '';
      _status = '已批量选择 ${ids.length} 个预设价值。可以扫描协同/冲突、带入失调雷达，或直接生成 1 美元行动。';
    });
  }

  void _openWorkbenchScene(String sceneKey) {
    setState(() {
      _specialSceneKey = sceneKey;
      _specialPlan = null;
      _specialField1Ctrl.clear();
      _specialField2Ctrl.clear();
      _specialField3Ctrl.clear();
      _specialField4Ctrl.clear();
    });
    _tabs.animateTo(2);
  }

  Widget _workbenchSceneButton({
    required String sceneKey,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openWorkbenchScene(sceneKey),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Icon(icon, color: const Color(0xFF4F46E5)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(subtitle, style: const TextStyle(height: 1.4, color: Color(0xFF64748B))),
                ]),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }



  String _newResolutionWorkflowId(String methodId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'mw_${now}_${(methodId.trim() + _resolutionSituationCtrl.text.trim()).hashCode.abs()}';
  }

  String _sourcebookSupportLabel(String level) {
    switch (level.trim()) {
      case 'direct_mechanism':
        return '原书直接机制';
      case 'theoretical_translation':
        return '源书理论转译';
      case 'product_extension':
        return '产品化扩展';
      default:
        return '理论转译';
    }
  }

  String _diagnoseDissonanceType(String input) {
    final text = input.toLowerCase();
    bool hasAny(List<String> keys) => keys.any((k) => text.contains(k.toLowerCase()));
    if (hasAny(['不敢看', '回避信息', '反馈', '现实', '证据', '结果'])) return 'selective_information_avoidance';
    if (hasAny(['后悔', '选择', '沉没成本', '投入', '放弃', '选错'])) return 'post_decision_or_sunk_cost';
    if (hasAny(['关系', '对方', '边界', '沟通', '家人', '朋友'])) return 'interpersonal_balance_conflict';
    if (hasAny(['内疚', '责任', '亏欠', '伤害', '补救', '道歉'])) return 'responsibility_consequence_conflict';
    if (hasAny(['自尊', '羞耻', '身份', '价值感', '我不配', '否定自己'])) return 'self_integrity_threat';
    if (hasAny(['旧信念', '我不行', '做不到', '没能力', '不可能'])) return 'counter_attitudinal_belief_lock';
    if (hasAny(['必须', '一定', '完了', '标准', '应该', '失败'])) return 'rigid_self_standard_conflict';
    if (hasAny(['拖延', '逃避', '没做', '行动', '沉迷', '执行', '自律'])) return 'value_behavior_gap';
    if (hasAny(['解释', '借口', '合理化', '证明'])) return 'defensive_explanation_loop';
    return 'mixed_cognitive_dissonance';
  }

  String _diagnosisLabel(String type) {
    switch (type.trim()) {
      case 'selective_information_avoidance': return '选择性信息回避';
      case 'post_decision_or_sunk_cost': return '决策后失调/沉没成本';
      case 'interpersonal_balance_conflict': return '人际三角失衡';
      case 'responsibility_consequence_conflict': return '责任—后果失调';
      case 'self_integrity_threat': return '自我完整性受威胁';
      case 'counter_attitudinal_belief_lock': return '旧信念锁定';
      case 'rigid_self_standard_conflict': return '僵硬自我标准冲突';
      case 'value_behavior_gap': return '价值—行为距离';
      case 'defensive_explanation_loop': return '防御性解释循环';
      default: return '混合型认知失调';
    }
  }

  List<String> _methodCombinationForDiagnosis(String type) {
    switch (type.trim()) {
      case 'self_integrity_threat':
        return const <String>['self_integrity', 'information_contact', 'counter_attitudinal_experiment', 'behavior_alignment'];
      case 'selective_information_avoidance':
        return const <String>['self_integrity', 'information_contact', 'add_integrating_cognition', 'behavior_alignment'];
      case 'post_decision_or_sunk_cost':
        return const <String>['choice_recheck', 'belief_reframe', 'behavior_alignment'];
      case 'interpersonal_balance_conflict':
        return const <String>['interpersonal_balance', 'belief_reframe', 'behavior_alignment'];
      case 'value_behavior_gap':
        return const <String>['behavior_alignment', 'counter_attitudinal_experiment', 'belief_reframe'];
      default:
        return const <String>['add_integrating_cognition', 'belief_reframe', 'behavior_alignment'];
    }
  }

  Future<void> _bindActiveResolutionMethodUsageToPlan(CcPlanResult result, {String status = 'analysis_generated'}) async {
    final usageId = _activeResolutionMethodUsageId.trim();
    if (usageId.isEmpty || result.sessionId.trim().isEmpty) return;
    await _dao.updateResolutionMethodUsage(
      usageId: usageId,
      sessionId: result.sessionId,
      caseId: 'case_${result.sessionId}',
      methodWorkflowId: _activeResolutionMethodWorkflowId,
      dissonanceType: _lastDissonanceDiagnosisType,
      status: status,
    );
  }

  Future<void> _startFullSourcebookCaseDraft() async {
    final summary = _structuredDissonanceInput().trim().isEmpty
        ? (_resolutionSituationCtrl.text.trim().isEmpty ? '新的认知失调案例' : _resolutionSituationCtrl.text.trim())
        : _structuredDissonanceInput().trim();
    final sid = await _dao.createSourcebookCaseDraft(
      eventSummary: summary,
      sourceType: _activeSourceType.trim().isNotEmpty ? _activeSourceType : widget.sourceType,
      sourceId: _activeSourceId.trim().isNotEmpty ? _activeSourceId : widget.sourceId,
      initialStage: 'input',
    );
    _activeSourcebookDraftSessionId = sid;
    await _load();
    if (!mounted) return;
    _tabs.animateTo(1);
    _toast('已创建源书案例草稿，请从失调事件输入开始推进。');
  }

  List<Map<String, dynamic>> _filteredResolutionMethods() {
    final filter = _resolutionMethodFilter.trim();
    final methods = _dissonanceResolutionMethods.where((m) {
      if (filter.isEmpty || filter == 'all') return true;
      final category = _methodText(m, 'category');
      final id = _methodText(m, 'id');
      final scene = _methodText(m, 'sceneKey');
      final text = '${_methodText(m, 'title')} ${_methodText(m, 'when')} ${_methodText(m, 'core')}'.toLowerCase();
      switch (filter) {
        case 'action':
          return id.contains('behavior') || id.contains('counter') || scene.contains('experiment') || text.contains('行动');
        case 'explanation':
          return id.contains('reframe') || id.contains('add_') || text.contains('解释') || text.contains('认知');
        case 'reality':
          return id.contains('information') || id.contains('choice') || scene.contains('information') || text.contains('证据') || text.contains('现实');
        case 'relationship':
          return id.contains('interpersonal') || scene.contains('interpersonal') || text.contains('关系');
        case 'identity':
          return id.contains('self') || scene.contains('identity') || text.contains('身份') || text.contains('自我');
        default:
          return category.contains(filter) || id.contains(filter);
      }
    }).toList(growable: false);
    if (_recommendedResolutionMethodIds.isEmpty) return methods;
    final order = <String, int>{for (var i = 0; i < _recommendedResolutionMethodIds.length; i++) _recommendedResolutionMethodIds[i]: i};
    methods.sort((a, b) => (order[_methodText(a, 'id')] ?? 99).compareTo(order[_methodText(b, 'id')] ?? 99));
    return methods;
  }

  int _scoreResolutionMethod(Map<String, dynamic> method, String input) {
    final id = _methodText(method, 'id');
    final scene = _methodText(method, 'sceneKey');
    final text = input.toLowerCase();
    var score = 0;
    void hit(List<String> keys, int value) {
      for (final k in keys) {
        if (text.contains(k.toLowerCase())) score += value;
      }
    }
    if (id == 'behavior_alignment') hit(['拖延', '逃避', '没做', '行动', '自律', '努力', '沉迷', '执行'], 4);
    if (id == 'belief_reframe') hit(['解释', '借口', '合理化', '证明', '否定自己', '自责'], 4);
    if (id == 'add_integrating_cognition') hit(['矛盾', '冲突', '一方面', '另一方面', '复杂', '不知道'], 3);
    if (id == 'reduce_rigidity') hit(['必须', '一定', '完了', '应该', '标准', '不配', '失败'], 4);
    if (id == 'information_contact') hit(['不敢看', '回避信息', '反方', '证据', '现实', '害怕知道'], 5);
    if (id == 'counter_attitudinal_experiment') hit(['旧信念', '我不行', '做不到', '没能力', '不可能', '实验'], 5);
    if (id == 'choice_recheck') hit(['后悔', '选择', '沉没成本', '投入', '放弃', '选错'], 5);
    if (id == 'responsibility_repair') hit(['内疚', '责任', '亏欠', '补救', '道歉', '伤害'], 5);
    if (id == 'interpersonal_balance') hit(['关系', '对方', '边界', '沟通', '人际', '朋友', '家人'], 5);
    if (id == 'self_integrity') hit(['自尊', '羞耻', '自我', '身份', '价值感', '完整'], 5);
    if (score == 0 && (_methodText(method, 'when') + _methodText(method, 'core')).contains(input.trim())) score += 1;
    if (scene == _specialSceneKey) score += 1;
    return score;
  }

  void _recommendResolutionMethods() {
    final input = _resolutionSituationCtrl.text.trim().isEmpty
        ? [_goalCtrl.text, _contextCtrl.text, _specialCtrl.text].where((e) => e.trim().isNotEmpty).join('\n')
        : _resolutionSituationCtrl.text.trim();
    if (input.trim().isEmpty) {
      _toast('请先描述当前认知失调、矛盾或卡住点。');
      return;
    }
    final diagnosis = _diagnoseDissonanceType(input);
    final scored = _dissonanceResolutionMethods
        .map((m) => <String, dynamic>{'id': _methodText(m, 'id'), 'score': _scoreResolutionMethod(m, input)})
        .where((m) => (m['score'] as int) > 0)
        .toList(growable: false)
      ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    final ids = scored.take(3).map((m) => (m['id'] ?? '').toString()).where((e) => e.isNotEmpty).toList(growable: false);
    setState(() {
      _lastDissonanceDiagnosisType = diagnosis;
      _recommendedResolutionMethodIds = ids.isEmpty ? _methodCombinationForDiagnosis(diagnosis).take(3).toList(growable: false) : ids;
      _resolutionMethodFilter = 'all';
    });
    _toast('已识别为：${_diagnosisLabel(diagnosis)}，并推荐 ${_recommendedResolutionMethodIds.length} 个解决方法。');
  }

  Widget _buildDissonanceResolutionMethodsTab() {
    final methods = _filteredResolutionMethods();
    final recommended = _recommendedResolutionMethodIds
        .map((id) => _dissonanceResolutionMethods.where((m) => _methodText(m, 'id') == id).toList(growable: false))
        .where((list) => list.isNotEmpty)
        .map((list) => list.first)
        .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFFFFFBEB),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.psychology_alt_outlined, color: Color(0xFFD97706)), SizedBox(width: 8), Expanded(child: Text('认知失调解决引擎', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)))]),
              const SizedBox(height: 8),
              const Text(
                '这里不只是方法目录，而是“诊断当前失调 → 推荐方法 → 生成行动契约/Todo → 留下证据 → 复盘方法有效性”的统一入口。',
                style: TextStyle(height: 1.45, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _resolutionSituationCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '当前卡住点 / 认知失调描述',
                  hintText: '例如：我明明重视成长，却总是逃避；我害怕看现实反馈；我后悔之前投入太多又不甘心放弃……',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(onPressed: _recommendResolutionMethods, icon: const Icon(Icons.auto_awesome_outlined), label: const Text('诊断并推荐方法')),
                OutlinedButton.icon(onPressed: () => setState(() => _recommendedResolutionMethodIds = <String>[]), icon: const Icon(Icons.clear_all_outlined), label: const Text('清空推荐')),
              ]),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _methodFilterChip('all', '全部'),
                  _methodFilterChip('action', '行动导向'),
                  _methodFilterChip('explanation', '解释/认知'),
                  _methodFilterChip('reality', '现实检验'),
                  _methodFilterChip('relationship', '关系边界'),
                  _methodFilterChip('identity', '身份/自我'),
                ],
              ),
            ]),
          ),
        ),
        if (recommended.isNotEmpty) ...[
          const SizedBox(height: 10),
          _infoCard('推荐优先使用的方法', '当前诊断：${_diagnosisLabel(_lastDissonanceDiagnosisType)}。下面 1-3 个方法是根据失调类型与关键词做出的本地推荐。它不是替你决定，而是帮你减少盲目选择，最终仍由你判断。', Icons.recommend_outlined),
          _resolutionMethodCombinationCard(),
          ...recommended.map(_dissonanceResolutionMethodCard),
          const Divider(height: 24),
        ],
        const SizedBox(height: 10),
        ...methods.map(_dissonanceResolutionMethodCard),
        const SizedBox(height: 10),
        _resolutionMethodUsageHistoryCard(),
      ],
    );
  }

  Widget _methodFilterChip(String value, String label) {
    return FilterChip(
      selected: _resolutionMethodFilter == value,
      label: Text(label),
      onSelected: (_) => setState(() => _resolutionMethodFilter = value),
    );
  }

  Widget _resolutionMethodUsageHistoryCard() {
    if (_resolutionMethodUsages.isEmpty) {
      return _emptyCard('方法使用档案', '你使用某个解决方法、写入 Todo、生成行动契约或完成复盘后，会在这里沉淀为长期方法画像。');
    }
    return Card(
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.history_edu_outlined, color: Color(0xFF475569)), SizedBox(width: 8), Expanded(child: Text('最近使用的方法', style: TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 8),
          ..._resolutionMethodUsages.take(8).map((u) {
            final title = (u['method_title'] ?? u['method_id'] ?? '').toString();
            final status = (u['status'] ?? '').toString();
            final score = (u['effect_score'] ?? 0).toString();
            final usageId = (u['usage_id'] ?? '').toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('状态：$status　效果评分：$score/10', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                if (((u['review_text'] ?? '').toString()).trim().isNotEmpty) Text((u['review_text'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(onPressed: usageId.isEmpty ? null : () => _reviewResolutionMethodUsage(u), icon: const Icon(Icons.rate_review_outlined, size: 16), label: const Text('复盘')),
                ),
              ]),
            );
          }),
        ]),
      ),
    );
  }


  Widget _resolutionMethodCombinationCard() {
    if (_lastDissonanceDiagnosisType.trim().isEmpty) return const SizedBox.shrink();
    final ids = _methodCombinationForDiagnosis(_lastDissonanceDiagnosisType);
    final titles = ids.map((id) {
      final found = _dissonanceResolutionMethods.where((m) => _methodText(m, 'id') == id).toList(growable: false);
      return found.isEmpty ? id : _methodText(found.first, 'shortTitle');
    }).where((e) => e.trim().isNotEmpty).toList(growable: false);
    if (titles.isEmpty) return const SizedBox.shrink();
    return Card(
      color: const Color(0xFFF0FDF4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.schema_outlined, color: Color(0xFF059669)), SizedBox(width: 8), Expanded(child: Text('推荐方法组合', style: TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 6),
          Text('类型：${_diagnosisLabel(_lastDissonanceDiagnosisType)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(titles.join(' → '), style: const TextStyle(height: 1.45, color: Color(0xFF166534))),
          const SizedBox(height: 6),
          const Text('组合意义：先降低自我威胁和盲区，再进入现实检验或小行动，最后把方法落实为行动证据。', style: TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.35)),
        ]),
      ),
    );
  }

  Widget _dissonanceResolutionMethodCard(Map<String, dynamic> method) {
    final title = _methodText(method, 'title');
    final shortTitle = _methodText(method, 'shortTitle');
    final category = _methodText(method, 'category');
    final source = _methodText(method, 'source');
    final supportLevel = _methodText(method, 'supportLevel');
    final when = _methodText(method, 'when');
    final core = _methodText(method, 'core');
    final risk = _methodText(method, 'risk');
    final quickAction = _methodText(method, 'quickAction');
    final methodId = _methodText(method, 'id');
    final isRecommended = _recommendedResolutionMethodIds.contains(methodId);
    final steps = _methodSteps(method);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isRecommended ? const Color(0xFFFFFBEB) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(isRecommended ? Icons.recommend_outlined : Icons.auto_fix_high_outlined, color: isRecommended ? const Color(0xFFD97706) : const Color(0xFF4F46E5)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title.isEmpty ? shortTitle : title, style: const TextStyle(fontWeight: FontWeight.w900)),
              if (category.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(category, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
            ])),
          ]),
          if (source.isNotEmpty) _miniLine('理论来源', source),
          _miniLine('来源性质', _sourcebookSupportLabel(supportLevel)),
          if (when.isNotEmpty) _miniLine('适用场景', when),
          if (core.isNotEmpty) _miniLine('核心机制', core),
          if (risk.isNotEmpty) _miniLine('风险提醒', risk),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('操作步骤', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            ...steps.take(6).toList().asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('${e.key + 1}. ${e.value}', style: const TextStyle(height: 1.35)),
            )),
          ],
          if (quickAction.isNotEmpty) _miniLine('最小行动', quickAction),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: () => _useDissonanceResolutionMethod(method),
              icon: const Icon(Icons.open_in_new_outlined),
              label: const Text('使用此方法'),
            ),
            OutlinedButton.icon(
              onPressed: quickAction.isEmpty ? null : () => _writeResolutionMethodToTodo(method),
              icon: const Icon(Icons.playlist_add_outlined),
              label: const Text('写入 Todo'),
            ),
            OutlinedButton.icon(
              onPressed: quickAction.isEmpty ? null : () => _createResolutionMethodContract(method),
              icon: const Icon(Icons.assignment_turned_in_outlined),
              label: const Text('生成行动契约'),
            ),
          ]),
        ]),
      ),
    );
  }

  String _methodText(Map<String, dynamic> method, String key) {
    return (method[key] ?? '').toString().trim();
  }

  List<String> _methodSteps(Map<String, dynamic> method) {
    final raw = method['steps'];
    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
    }
    return const <String>[];
  }

  Future<void> _useDissonanceResolutionMethod(Map<String, dynamic> method) async {
    final sceneKey = _methodText(method, 'sceneKey').isEmpty ? 'cognitive_structure_map' : _methodText(method, 'sceneKey');
    final title = _methodText(method, 'title');
    final methodId = _methodText(method, 'id');
    final workflowId = _newResolutionWorkflowId(methodId);
    _activeResolutionMethodWorkflowId = workflowId;
    final usageId = await _dao.saveResolutionMethodUsage(
      methodId: methodId,
      methodTitle: title,
      sourceType: _activeSourceType.trim().isNotEmpty ? _activeSourceType : widget.sourceType,
      sourceId: _activeSourceId.trim().isNotEmpty ? _activeSourceId : widget.sourceId,
      selectedReason: _resolutionSituationCtrl.text,
      enteredSceneKey: sceneKey,
      methodWorkflowId: workflowId,
      dissonanceType: _lastDissonanceDiagnosisType.trim().isEmpty ? _diagnoseDissonanceType(_resolutionSituationCtrl.text) : _lastDissonanceDiagnosisType,
      sourcebookSupportLevel: _methodText(method, 'supportLevel'),
      status: 'entered_scene',
    );
    _activeResolutionMethodUsageId = usageId;
    _prefillSpecialFieldsForResolutionMethod(method, sceneKey);
    await _load();
    if (!mounted) return;
    _tabs.animateTo(2);
    _toast('已进入对应专项场景：${_specialSceneLabels[sceneKey] ?? sceneKey}');
  }

  void _prefillSpecialFieldsForResolutionMethod(Map<String, dynamic> method, String sceneKey) {
    final title = _methodText(method, 'title');
    final when = _methodText(method, 'when');
    final core = _methodText(method, 'core');
    final risk = _methodText(method, 'risk');
    final quickAction = _methodText(method, 'quickAction');
    final situation = _resolutionSituationCtrl.text.trim();
    setState(() {
      _specialSceneKey = sceneKey;
      _specialPlan = null;
      _specialCtrl.text = [
        if (situation.isNotEmpty) '当前失调：$situation',
        if (title.isNotEmpty) '我想使用的方法：$title',
        if (when.isNotEmpty) '适用场景：$when',
        if (core.isNotEmpty) '核心机制：$core',
        if (risk.isNotEmpty) '风险提醒：$risk',
        if (quickAction.isNotEmpty) '最小行动：$quickAction',
      ].join('\n');
      switch (sceneKey) {
        case 'counter_attitudinal_experiment':
          _specialField1Ctrl.text = situation.isNotEmpty ? situation : '限制性旧信念';
          _specialField2Ctrl.text = core;
          _specialField3Ctrl.text = quickAction;
          _specialField4Ctrl.text = '完成后观察：旧信念是否松动？现实发生了什么？';
          break;
        case 'interpersonal_balance':
          _specialField1Ctrl.text = situation;
          _specialField2Ctrl.text = '共同涉及的观点/事件';
          _specialField3Ctrl.text = '我对该对象的态度';
          _specialField4Ctrl.text = '对方对该对象的态度/我需要表达的边界';
          break;
        case 'value_layering':
          _specialField1Ctrl.text = core;
          _specialField2Ctrl.text = '我正在保护的身份定义';
          _specialField3Ctrl.text = risk;
          _specialField4Ctrl.text = quickAction;
          break;
        case 'information_avoidance':
          _specialField1Ctrl.text = situation;
          _specialField2Ctrl.text = '我回避的反方证据/现实反馈';
          _specialField3Ctrl.text = risk;
          _specialField4Ctrl.text = quickAction;
          break;
        case 'choice_recheck':
        case 'sunk_cost':
          _specialField1Ctrl.text = situation;
          _specialField2Ctrl.text = '我已经投入/不甘心放弃的部分';
          _specialField3Ctrl.text = risk;
          _specialField4Ctrl.text = quickAction;
          break;
        case 'responsibility_radar':
          _specialField1Ctrl.text = situation;
          _specialField2Ctrl.text = '我真实可负责的部分';
          _specialField3Ctrl.text = '我可能过度背责/逃避的部分';
          _specialField4Ctrl.text = quickAction;
          break;
        case 'hypocrisy_change':
          _specialField1Ctrl.text = core.isNotEmpty ? core : '我认同的价值';
          _specialField2Ctrl.text = situation;
          _specialField3Ctrl.text = when;
          _specialField4Ctrl.text = quickAction;
          break;
        case 'self_standard_map':
          _specialField1Ctrl.text = situation;
          _specialField2Ctrl.text = '这个标准来自：价值、家庭/社会期待或理想自我';
          _specialField3Ctrl.text = risk;
          _specialField4Ctrl.text = quickAction.isEmpty ? '把标准改写为可行动的新标准' : quickAction;
          break;
        case 'identity_conflict':
          _specialField1Ctrl.text = '旧身份/旧解释：$situation';
          _specialField2Ctrl.text = '新身份：更真实、更可行动的我';
          _specialField3Ctrl.text = core;
          _specialField4Ctrl.text = quickAction;
          break;
        case 'cognitive_structure_map':
          _specialField1Ctrl.text = core;
          _specialField2Ctrl.text = situation;
          _specialField3Ctrl.text = risk;
          _specialField4Ctrl.text = quickAction;
          break;
        default:
          _specialField1Ctrl.text = core;
          _specialField2Ctrl.text = when;
          _specialField3Ctrl.text = risk;
          _specialField4Ctrl.text = quickAction;
      }
    });
  }

  Future<void> _writeResolutionMethodToTodo(Map<String, dynamic> method) async {
    final methodId = _methodText(method, 'id');
    final title = _methodText(method, 'title');
    final quickAction = _methodText(method, 'quickAction');
    if (quickAction.isEmpty) {
      _toast('这个方法还没有可写入的最小行动。');
      return;
    }
    final usageId = await _dao.saveResolutionMethodUsage(
      methodId: methodId,
      methodTitle: title,
      sourceType: _activeSourceType.trim().isNotEmpty ? _activeSourceType : widget.sourceType,
      sourceId: _activeSourceId.trim().isNotEmpty ? _activeSourceId : widget.sourceId,
      selectedReason: _resolutionSituationCtrl.text,
      enteredSceneKey: _methodText(method, 'sceneKey'),
      methodWorkflowId: _newResolutionWorkflowId(methodId),
      dissonanceType: _lastDissonanceDiagnosisType.trim().isEmpty ? _diagnoseDissonanceType(_resolutionSituationCtrl.text) : _lastDissonanceDiagnosisType,
      sourcebookSupportLevel: _methodText(method, 'supportLevel'),
      status: 'todo_requested',
    );
    await _quickCreateTodoActionFromText(
      quickAction,
      title.isEmpty ? '认知失调解决方法' : title,
      actionType: 'dissonance_resolution_method',
      afterCreated: (stepId) async {
        await _dao.updateResolutionMethodUsage(usageId: usageId, todoStepId: stepId, status: 'todo_created');
        await _dao.saveActionTraceLink(fromType: 'cc_resolution_method', fromId: methodId, toType: 'todo_goal_step', toId: stepId, relationType: 'method_written_to_todo');
      },
    );
    await _load();
  }

  Future<void> _createResolutionMethodContract(Map<String, dynamic> method) async {
    final methodId = _methodText(method, 'id');
    final title = _methodText(method, 'title');
    final quickAction = _methodText(method, 'quickAction');
    final usageId = await _dao.saveResolutionMethodUsage(
      methodId: methodId,
      methodTitle: title,
      sourceType: _activeSourceType.trim().isNotEmpty ? _activeSourceType : widget.sourceType,
      sourceId: _activeSourceId.trim().isNotEmpty ? _activeSourceId : widget.sourceId,
      selectedReason: _resolutionSituationCtrl.text,
      enteredSceneKey: _methodText(method, 'sceneKey'),
      methodWorkflowId: _newResolutionWorkflowId(methodId),
      dissonanceType: _lastDissonanceDiagnosisType.trim().isEmpty ? _diagnoseDissonanceType(_resolutionSituationCtrl.text) : _lastDissonanceDiagnosisType,
      sourcebookSupportLevel: _methodText(method, 'supportLevel'),
      status: 'contract_requested',
    );
    await _dao.createSourcebookContractFromMethod(
      methodId: methodId,
      methodTitle: title,
      minimalAction: quickAction,
      coreValue: _methodText(method, 'core'),
      currentBehavior: _resolutionSituationCtrl.text,
      completionStandard: '完成这个方法对应的最小行动，并记录它是否降低了失调。',
      fallbackPlan: '如果阻力太大，把行动缩小到 2 分钟版本，但仍要留下一个现实证据。',
      reflectionQuestions: '这个方法是否帮助我更接近事实、价值和行动？它有没有变成新的合理化？',
      usageId: usageId,
    );
    await _load();
    _tabs.animateTo(8);
    _toast('已生成源书行动契约，可在源书工作台/案例列表中继续推进。');
  }

  Future<void> _reviewResolutionMethodUsage(Map<String, dynamic> usage) async {
    final usageId = (usage['usage_id'] ?? '').toString();
    if (usageId.trim().isEmpty) return;
    final reviewCtrl = TextEditingController(text: (usage['review_text'] ?? '').toString());
    final riskCtrl = TextEditingController(text: (usage['risk_note'] ?? '').toString());
    final nextCtrl = TextEditingController(text: (usage['next_use_suggestion'] ?? '').toString());
    var score = int.tryParse((usage['effect_score'] ?? '0').toString()) ?? 0;
    var reduced = ((usage['reduced_dissonance'] ?? 0).toString() == '1');
    var produced = ((usage['produced_evidence'] ?? 0).toString() == '1');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('复盘方法有效性'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text((usage['method_title'] ?? usage['method_id'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TextField(controller: reviewCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '这个方法如何影响了本次失调？', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: riskCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '有没有被误用成合理化/逃避？', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: nextCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '下次是否继续使用/如何调整？', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(children: [const Text('效果评分'), Expanded(child: Slider(value: score.toDouble(), min: 0, max: 10, divisions: 10, label: '$score', onChanged: (v) => setDialogState(() => score = v.round())))]),
            CheckboxListTile(value: reduced, onChanged: (v) => setDialogState(() => reduced = v ?? reduced), title: const Text('它确实降低/转化了失调')),
            CheckboxListTile(value: produced, onChanged: (v) => setDialogState(() => produced = v ?? produced), title: const Text('它产生了现实行动证据')),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存复盘')),
          ],
        ),
      ),
    );
    if (saved == true) {
      var evidenceId = (usage['evidence_id'] ?? '').toString().trim();
      if (produced && evidenceId.isEmpty) {
        final methodTitle = (usage['method_title'] ?? usage['method_id'] ?? '认知失调解决方法').toString();
        final sessionId = (usage['session_id'] ?? '').toString();
        evidenceId = await _dao.saveEvidence(
          sessionId: sessionId,
          userGoal: _resolutionSituationCtrl.text.trim().isEmpty ? methodTitle : _resolutionSituationCtrl.text.trim(),
          plannedAction: methodTitle,
          completedAction: '完成方法复盘：$methodTitle',
          userReflection: reviewCtrl.text.trim().isEmpty ? '该方法产生了现实行动证据。' : reviewCtrl.text.trim(),
          evidenceLabel: '方法复盘证据：$methodTitle',
          valueLink: _valuesCtrl.text,
          oldStory: '旧解释：只能靠想清楚才能改变。',
          newStory: '新证据：我可以选择一种方法，行动或检验后再复盘其效果。',
          evidenceCategory: 'review',
          identityDirection: 'method_based_integrator',
          rewardSource: 'dissonance_resolution_method_review',
          sourceType: 'cc_resolution_method_usage',
          sourceId: usageId,
          dissonanceReductionMode: reduced ? 'method_review_with_evidence' : 'method_review_needs_more_evidence',
          effortMinutes: 1,
          difficultyScore: 1,
        );
      }
      await _dao.updateResolutionMethodUsage(
        usageId: usageId,
        evidenceId: evidenceId,
        status: 'reviewed',
        reviewText: reviewCtrl.text,
        riskNote: riskCtrl.text,
        nextUseSuggestion: nextCtrl.text,
        effectScore: score,
        reducedDissonance: reduced,
        producedEvidence: produced,
      );
      if (_activeResolutionMethodUsageId == usageId) {
        _activeResolutionMethodUsageId = '';
        _activeResolutionMethodWorkflowId = '';
      }
      await _load();
      _toast('已保存方法复盘${evidenceId.isNotEmpty ? '，并写入证据账本。' : '。'}');
    }
    reviewCtrl.dispose();
    riskCtrl.dispose();
    nextCtrl.dispose();
  }

  Widget _buildSourcebookWorkbenchTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFFEEF2FF), Color(0xFFFFFBEB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Color(0xFFC7D2FE)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('源书工作台：从矛盾信号到行动一致', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B))),
            SizedBox(height: 8),
            Text('基于《Theories of Cognitive Consistency: A Sourcebook》：不把矛盾当作失败，也不急着合理化，而是把信念、行为、自我形象、关系和现实反馈放在一起，区分自我保护与现实修正，最后落到一个可执行承诺。', style: TextStyle(height: 1.5, color: Color(0xFF475569))),
          ]),
        ),
        const SizedBox(height: 12),
        _infoCard('完整闭环', '发现不一致 → 绘制认知结构 → 判断矛盾类型 → 识别自我辩护 → 分析心理功能 → 区分核心价值/身份信念/外围解释 → 接触反方证据 → 设计反态度小实验 → 签订一致性行动契约 → 保存证据并复盘整合。', Icons.route_outlined, emphasize: true),
        _sourcebookFlowCard(),
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(onPressed: _startFullSourcebookCaseDraft, icon: const Icon(Icons.play_circle_outline), label: const Text('开始一个完整源书案例')),
              OutlinedButton.icon(onPressed: _showAllSourcebookCases, icon: const Icon(Icons.folder_open_outlined), label: const Text('查看全部源书案例')),
              OutlinedButton.icon(onPressed: () => _tabs.animateTo(9), icon: const Icon(Icons.psychology_alt_outlined), label: const Text('查看解决方法')),
            ]),
          ),
        ),
        _sourcebookRecentCaseCard(),
        _infoCard('解决方法已单独成库', '如果你现在不是想从理论流程开始，而是想直接选择一种处理认知失调的方法，可以进入“解决方法”Tab。每个方法都会跳转到对应专项场景，并继续连接行动契约、Todo 与证据账本。', Icons.auto_fix_high_outlined),
        _infoCard('AI 的角色边界', 'AI 不替你做最终选择，也不把你定义为懒惰、失败或自欺。它提供结构化分析、多种解释、判断标准、低风险现实检验和最小行动，最终选择权交还给你。', Icons.psychology_alt_outlined),
        const SizedBox(height: 6),
        const Text('核心功能入口', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        _workbenchSceneButton(
          sceneKey: 'cognitive_structure_map',
          icon: Icons.account_tree_outlined,
          title: '认知结构地图',
          subtitle: '把信念、态度、行为、自我形象、关系和现实反馈拆成节点，看到哪里一致、哪里冲突。',
        ),
        _workbenchSceneButton(
          sceneKey: 'conflict_type_router',
          icon: Icons.call_split_outlined,
          title: '矛盾类型分流器',
          subtitle: '区分信念冲突、价值—行为冲突、自我—现实冲突、角色冲突、决策后失调。',
        ),
        _workbenchSceneButton(
          sceneKey: 'psychological_function',
          icon: Icons.shield_outlined,
          title: '心理功能分析器',
          subtitle: '不只判断想法对错，而是看它保护了什么、回避了什么、过去怎样帮助你、现在怎样限制你。',
        ),
        _workbenchSceneButton(
          sceneKey: 'value_layering',
          icon: Icons.layers_outlined,
          title: '核心价值 / 身份信念 / 外围解释',
          subtitle: '保留真正核心价值，松动过度僵硬的身份信念，检验临时解释与借口。',
        ),
        _workbenchSceneButton(
          sceneKey: 'choice_recheck',
          icon: Icons.alt_route_outlined,
          title: '决策后失调工作台',
          subtitle: '处理选择后的后悔、沉没成本、努力合理化和“必须证明我没选错”的冲动。',
        ),
        _workbenchSceneButton(
          sceneKey: 'information_avoidance',
          icon: Icons.visibility_outlined,
          title: '选择性信息接触训练',
          subtitle: '识别只看支持性证据的循环，把反方证据降级成低风险现实接触行动。',
        ),
        _workbenchSceneButton(
          sceneKey: 'interpersonal_balance',
          icon: Icons.people_alt_outlined,
          title: '人际平衡分析器',
          subtitle: '分析“我—他人—对象/观点/事件”三角关系，区分人、观点、边界和沟通。',
        ),
        _workbenchSceneButton(
          sceneKey: 'counter_attitudinal_experiment',
          icon: Icons.science_outlined,
          title: '反态度行为实验',
          subtitle: '用一个 5-15 分钟的小行动证明旧自我叙事不是绝对事实。',
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('行动与档案闭环', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(onPressed: () => _tabs.animateTo(3), icon: const Icon(Icons.timer_outlined, size: 18), label: const Text('一致性行动契约')),
                OutlinedButton.icon(onPressed: () => _tabs.animateTo(4), icon: const Icon(Icons.inventory_2_outlined, size: 18), label: const Text('一致性成长档案')),
                OutlinedButton.icon(onPressed: () => _tabs.animateTo(7), icon: const Icon(Icons.assessment_outlined, size: 18), label: const Text('长期报告')),
                OutlinedButton.icon(onPressed: () => _tabs.animateTo(1), icon: const Icon(Icons.radar_outlined, size: 18), label: const Text('快速失调雷达')),
              ]),
            ]),
          ),
        ),
      ],
    );
  }


  Widget _sourcebookFlowCard() {
    const stages = <String>['输入事件', '认知地图', '矛盾分流', '自我辩护', '心理功能', '价值分层', '现实检验', '行动契约', '复盘整合'];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.schema_outlined, color: Color(0xFF4F46E5)), SizedBox(width: 8), Text('源书连续流程引擎', style: TextStyle(fontWeight: FontWeight.w900))]),
          const SizedBox(height: 8),
          const Text('每个分析结果都会保存为一个 sourcebook case，并同步沉淀认知节点、冲突边、价值分层、用户选择、行动契约与验证任务。', style: TextStyle(height: 1.45, color: Color(0xFF475569))),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: stages.map(_pill).toList()),
        ]),
      ),
    );
  }

  Widget _sourcebookRecentCaseCard() {
    const sourcebookKeys = <String>{
      'cognitive_structure_map', 'conflict_type_router', 'psychological_function', 'value_layering',
      'interpersonal_balance', 'counter_attitudinal_experiment', 'choice_recheck', 'sunk_cost',
      'information_avoidance', 'identity_conflict', 'dissonance_analysis', 'target_to_action'
    };
    final cases = _sessions.where((s) => sourcebookKeys.contains(s.sceneType)).take(5).toList(growable: false);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.folder_copy_outlined, color: Color(0xFF0F766E)), SizedBox(width: 8), Text('最近源书案例档案', style: TextStyle(fontWeight: FontWeight.w900))]),
          const SizedBox(height: 8),
          if (cases.isEmpty)
            const Text('暂无源书案例。点击下方任一入口，生成后会自动进入案例档案。', style: TextStyle(color: Color(0xFF6B7280)))
          else
            ...cases.map((s) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${_specialSceneLabels[s.sceneType] ?? s.sceneType}｜${s.userGoal}', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(_sourcebookIntegratedText(s.result), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Wrap(spacing: 4, children: [
                IconButton(tooltip: '打开完整案例档案', icon: const Icon(Icons.folder_open_outlined), onPressed: () => _showSourcebookCaseDetail(s.result)),
                IconButton(tooltip: '进入场景继续分析', icon: const Icon(Icons.chevron_right), onPressed: () {
                  setState(() {
                    _specialSceneKey = s.sceneType;
                    _specialPlan = s.result;
                    _applyPlan(s.result);
                  });
                  _tabs.animateTo(2);
                }),
              ]),
              onTap: () => _showSourcebookCaseDetail(s.result),
            )),
        ]),
      ),
    );
  }


  Future<void> _showAllSourcebookCases() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const CcSourcebookCaseListPage()),
    );
    if (mounted) await _load();
  }

  Widget _buildValueCompassTab() {
    const suggestions = <String>['成长', '自由', '责任', '健康', '学习', '创造', '勇气', '真实自我', '选择权', '复盘'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _heroCard(),
        const SizedBox(height: 12),
        _featureAccessCard(),
        const SizedBox(height: 12),
        _emptyCard('价值罗盘', '这里记录长期价值与身份方向。上方功能入口可直接进入奖励降噪、诚实校验和一致性报告；下方预设价值标签也支持直接多选，会自动保存为价值档案并带入 AI。'),
        _valueBehaviorConsistencyMapCard(),
        _selectedValuesPanel(),
        Card(
          color: const Color(0xFFFFFFFF),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.checklist_outlined, color: Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                const Expanded(child: Text('预设价值（可多选）', style: TextStyle(fontWeight: FontWeight.w900))),
                TextButton(
                  onPressed: () => _selectAllSuggestedValues(suggestions),
                  child: const Text('全选预设'),
                ),
              ]),
              const SizedBox(height: 6),
              const Text('点击任意价值即可选中/取消；选中多个价值后，上方“多价值选择”面板会显示组合，并支持扫描协同/冲突、带入失调雷达、直接生成 1 美元行动。', style: TextStyle(height: 1.45, color: Color(0xFF6B7280))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions.map((v) {
                  final selected = _isSuggestedValueSelected(v);
                  return FilterChip(
                    label: Text(selected ? '✓ $v' : v),
                    selected: selected,
                    showCheckmark: true,
                    selectedColor: const Color(0xFFE0E7FF),
                    backgroundColor: const Color(0xFFFFFFFF),
                    side: BorderSide(color: selected ? const Color(0xFF4F46E5) : const Color(0xFFD1D5DB)),
                    onSelected: (checked) async => _toggleSuggestedValue(v, checked),
                  );
                }).toList(),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        TextField(controller: _valueLabelCtrl, decoration: const InputDecoration(labelText: '价值名称', hintText: '例如：成长、自由、责任、健康', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _valueWhyCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '为什么这对我重要', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _identityCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '它支持我成为什么样的人', hintText: '例如：能持续积累能力的人', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _valueActionCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '这个价值对应的一个最小行动', hintText: '例如：读一页并写一句理解', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _saveValueProfile, icon: const Icon(Icons.explore_outlined), label: Text(_editingValueId.isEmpty ? '保存到价值罗盘' : '更新价值档案')),
        if (_editingValueId.isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => setState(_clearValueEditForm), icon: const Icon(Icons.close), label: const Text('取消编辑')),
        ],
        const SizedBox(height: 18),
        if (_valueProfiles.isEmpty)
          _emptyCard('暂无价值档案', '先保存一个价值，再在“失调雷达”中把目标连接到它。')
        else
          ..._valueProfiles.map(_valueProfileCard),
      ],
    );
  }


  Widget _valueBehaviorConsistencyMapCard() {
    if (_valueProfiles.isEmpty && _valueSnapshots.isEmpty) return const SizedBox.shrink();
    final snapshots = _valueSnapshots.isNotEmpty
        ? _valueSnapshots.take(10).toList(growable: false)
        : _valueProfiles.take(8).map((v) => CcValueConsistencySnapshot(valueId: v.valueId, valueLabel: v.valueLabel)).toList(growable: false);
    final rows = snapshots.map((v) {
      return DataRow(cells: [
        DataCell(Text(v.valueLabel)),
        DataCell(Text('${v.beliefStrength <= 0 ? '-' : v.beliefStrength}')),
        DataCell(Text('${v.evidenceCount}')),
        DataCell(Text('${v.dissonanceCount}')),
        DataCell(Text('${v.repairCount}')),
        DataCell(Text(v.averageIntensity <= 0 ? '-' : '${v.averageIntensity}/24')),
        DataCell(Text(v.averageDiscomfortDrop == 0 ? '-' : '${v.averageDiscomfortDrop}')),
        DataCell(Text(v.trend)),
      ]);
    }).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.map_outlined, color: Color(0xFF2563EB)), SizedBox(width: 8), Expanded(child: Text('价值—行为一致性地图', style: TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 6),
          const Text('现在由 DAO 聚合失调类型、强度、温度变化、行动证据和价值链接，不再只靠文本粗略匹配。它回答：这个价值是否真正进入行动，还是仍停留在口号里。', style: TextStyle(height: 1.45, color: Color(0xFF6B7280))),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('价值')),
                DataColumn(label: Text('认同')),
                DataColumn(label: Text('证据')),
                DataColumn(label: Text('失调')),
                DataColumn(label: Text('修复')),
                DataColumn(label: Text('强度')),
                DataColumn(label: Text('降温')),
                DataColumn(label: Text('趋势')),
              ],
              rows: rows,
            ),
          ),
          const SizedBox(height: 8),
          ...snapshots.take(3).where((v) => v.latestDissonance.isNotEmpty || v.latestRepair.isNotEmpty || v.topRationalization.isNotEmpty).map((v) => Text('• ${v.valueLabel}：${v.latestDissonance.isEmpty ? '' : '最近失调「${v.latestDissonance}」'}${v.latestRepair.isEmpty ? '' : '；最近修复「${v.latestRepair}」'}${v.topRationalization.isEmpty ? '' : '；高频解释「${v.topRationalization}」'}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.35))),
        ]),
      ),
    );
  }

  Widget _selectedValuesPanel() {
    final selected = _selectedValueProfiles();
    final labels = _joinClean(selected.map((e) => e.valueLabel));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: selected.isEmpty ? const Color(0xFFF8FAFC) : const Color(0xFFEFF6FF),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(selected.isEmpty ? Icons.check_box_outline_blank : Icons.checklist_rtl, color: const Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected.isEmpty ? '多价值选择' : '已选择 ${selected.length} 个价值',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            TextButton(
              onPressed: selected.isEmpty ? null : () => setState(() { _selectedValueIds.clear(); _valueInsight = ''; }),
              child: const Text('清空'),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            selected.isEmpty ? '勾选下方多个价值后，可以把它们作为一个价值组合带入失调雷达。适合处理“成长+健康”“责任+自由”“学习+真实自我”等多价值冲突或多价值协同。' : labels,
            style: const TextStyle(height: 1.45),
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: selected.map((v) => Chip(label: Text(v.valueLabel))).toList()),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: () => _applySelectedValuesToRadar(),
                icon: const Icon(Icons.radar_outlined),
                label: const Text('带入失调雷达'),
              ),
              OutlinedButton.icon(
                onPressed: _scanSelectedValueRelations,
                icon: const Icon(Icons.schema_outlined),
                label: const Text('扫描协同/冲突'),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : () => _generateFromSelectedValues(),
                icon: const Icon(Icons.bolt_outlined),
                label: const Text('直接生成行动'),
              ),
            ]),
            if (_valueInsight.isNotEmpty) ...[
              const SizedBox(height: 10),
              _readOnlyBlock(_valueInsight),
            ],
            if (_valueRelationHistory.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('历史价值协同/冲突分析', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ..._valueRelationHistory.take(3).map((item) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.selectedValueLabels, style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          if (item.linkedSessionId.isNotEmpty) _pill('已生成 session'),
                          if (item.linkedEvidenceId.isNotEmpty) _pill('已被证据验证'),
                        ]),
                        if (item.linkedSessionId.isNotEmpty || item.linkedEvidenceId.isNotEmpty) const SizedBox(height: 6),
                        Text(item.insightText, maxLines: 5, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.4)),
                      ]),
                    ),
                  )),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _valueProfileCard(CcValueProfile v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Checkbox(
              value: _selectedValueIds.contains(v.valueId),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _selectedValueIds.add(v.valueId);
                  _valueInsight = '';
                } else {
                  _selectedValueIds.remove(v.valueId);
                  _valueInsight = '';
                }
              }),
            ),
            const Icon(Icons.explore_outlined, color: Color(0xFF4F46E5)),
            const SizedBox(width: 8),
            Expanded(child: Text(v.valueLabel, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            IconButton(tooltip: '编辑', onPressed: () => _editValue(v), icon: const Icon(Icons.edit_outlined)),
            IconButton(tooltip: '删除', onPressed: () => _deleteValue(v.valueId), icon: const Icon(Icons.delete_outline)),
          ]),
          if (v.why.isNotEmpty) _miniLine('为什么', v.why),
          if (v.identityDirection.isNotEmpty) _miniLine('身份方向', v.identityDirection),
          if (v.exampleAction.isNotEmpty) _miniLine('最小行动', v.exampleAction),
          _valueEvidenceSummary(v),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedValueIds
                    ..clear()
                    ..add(v.valueId);
                  _valuesCtrl.text = _composeSelectedValuesText(<CcValueProfile>[v]);
                  if (_goalCtrl.text.trim().isEmpty && v.exampleAction.trim().isNotEmpty) _goalCtrl.text = v.exampleAction;
                });
                _tabs.animateTo(1);
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('用于生成行动'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildRadarTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _emptyCard('认知失调雷达', '把“我相信什么—我实际做了什么—我如何解释自己”拆开，再压成一个最小充分行动。'),
        if (widget.sourceType.isNotEmpty)
          _infoCard('外部来源', '来源：${widget.sourceType}\nID：${widget.sourceId}\n该行动完成后，证据会保留来源字段，并在来源页面显示一致行动证据状态；来自 Todo/问题树时还能回写努力账本、复盘和可选标记完成。', Icons.link_outlined),
        TextField(
          controller: _goalCtrl,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '目标 / 想做但一直拖延的事情',
            hintText: '例如：我想开始学习心理学，但总是刷视频',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _contextCtrl,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: '当前状态 / 阻力 / 内耗事件',
            hintText: '例如：一想到开始就觉得太难，觉得做一点没意义',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _valuesCtrl,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '你希望连接的价值或身份方向（可选）',
            hintText: '例如：成长、自由、责任、健康、选择权',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        _structuredDissonanceRecorderCard(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _generate,
                icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                label: Text(_busy ? '生成中...' : '生成 1 美元行动'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _analyzeDissonance,
                icon: const Icon(Icons.compare_arrows_outlined),
                label: const Text('失调分析'),
              ),
            ),
          ],
        ),
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_status, style: const TextStyle(color: Color(0xFF6B7280))),
        ],
        const SizedBox(height: 16),
        if (_plan != null) _planCard(_plan!),
      ],
    );
  }


  Widget _structuredDissonanceRecorderCard() {
    return Card(
      color: const Color(0xFFF8FAFC),
      child: ExpansionTile(
        leading: const Icon(Icons.fact_check_outlined, color: Color(0xFF4F46E5)),
        title: const Text('结构化认知失调记录器', style: TextStyle(fontWeight: FontWeight.w900)),
        subtitle: const Text('把“发生了什么”拆成行为、信念、价值、自我形象、后果、情绪和回避信息。'),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          const Text('这些字段会自动拼接进“失调分析”，帮助 AI 输出失调类型、强度、自我完整卡片和三类修复行动。', style: TextStyle(height: 1.45, color: Color(0xFF6B7280))),
          const SizedBox(height: 10),
          TextField(controller: _beliefCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '我认为自己应该/相信', hintText: '例如：我应该自律、负责、真实面对现实', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _actualBehaviorCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '我实际做了什么', hintText: '例如：刷了一天短视频、回避了消息、没有开始任务', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _selfImageCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '我想维护的自我形象', hintText: '例如：我是能行动的人、负责的人、诚实的人', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _consequenceCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '现实后果', hintText: '例如：目标没推进、关系被拖住、身体更疲惫', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _emotionCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '主要情绪', hintText: '例如：内疚、焦虑、烦躁、羞耻、防御、逃避冲动', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _currentExplanationCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '我现在如何解释自己', hintText: '例如：我太累了、没办法、以后再说、都已经这样了', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _avoidedInfoCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '我最不想面对/正在回避的信息', hintText: '例如：账单、体重、成绩、反馈、真实进度、反对证据', border: OutlineInputBorder())),
        ],
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFFEEF2FF), Color(0xFFF8FAFC)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: Color(0xFFC7D2FE)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('不是等到相信才行动，而是在行动中重新相信。', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B))),
          SizedBox(height: 8),
          Text('用最小行动制造真实证据，再用真实证据重塑自我解释。外部奖励只是脚手架，最终要回到价值、选择和身份。', style: TextStyle(height: 1.45, color: Color(0xFF4B5563))),
        ],
      ),
    );
  }

  Widget _planCard(CcPlanResult plan, {String rewardSource = '', String sourceType = '', String sourceId = ''}) {
    return Column(
      children: [
        if (plan.eventSummary.trim().isNotEmpty) _infoCard('事件简述', plan.eventSummary, Icons.article_outlined),
        _infoCard('一、你现在的核心冲突', plan.coreConflict, Icons.compare_arrows_outlined),
        if (_hasStructuredRadar(plan)) _structuredRadarCard(plan),
        if (_hasV18GrowthConsistency(plan)) _v18GrowthConsistencyCard(plan),
        if (_hasActionSet(plan)) _actionSetCard(plan),
        if (_hasModernResponsibility(plan)) _responsibilityBoundaryCard(plan),
        if (_hasSelfStandards(plan)) _selfStandardsCard(plan),
        if (_hasRationalizationMap(plan)) _rationalizationMapCard(plan),
        if (_hasSourcebookStructuredResult(plan)) _sourcebookStructuredResultCard(plan),
        if (_hasSpecialStructuredResult(plan)) _specialStructuredResultCard(plan),
        if (_hasTrueSelfBridge(plan)) _trueSelfBridgeCard(plan),
        _infoCard('二、这不是失败，而是改变入口', plan.changeEntry, Icons.door_front_door_outlined),
        _infoCard('三、你的 1 美元行动', plan.oneDollarAction, Icons.bolt_outlined, emphasize: true),
        _infoCard('四、行动前承诺语', plan.preCommitment, Icons.edit_note_outlined),
        _infoCard('五、行动中提醒语', plan.inActionReminder, Icons.notifications_active_outlined),
        _infoCard('六、行动后解释', plan.postActionExplanation, Icons.psychology_alt_outlined),
        _infoCard('七、下一步', plan.nextStep, Icons.trending_up_outlined),
        _infoCard('八、风险提醒', plan.riskReminder, Icons.warning_amber_outlined),
        if (plan.rewardRisk.trim().isNotEmpty) _infoCard('外部奖励风险', plan.rewardRisk, Icons.card_giftcard_outlined),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: () => _activatePlan(plan, rewardSource: rewardSource, sourceType: sourceType, sourceId: sourceId), icon: const Icon(Icons.play_arrow), label: const Text('设为当前行动并进入陪伴'))),
        ]),
        if (plan.sessionId.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: () => _confirmSourcebookAnalysis(plan, 'confirmed'), icon: const Icon(Icons.check_circle_outline, size: 18), label: const Text('确认分析基本准确')),
            OutlinedButton.icon(onPressed: () => _confirmSourcebookAnalysis(plan, 'partial'), icon: const Icon(Icons.tune_outlined, size: 18), label: const Text('部分准确，后续修正')),
            OutlinedButton.icon(onPressed: () => _confirmSourcebookAnalysis(plan, 'needs_revision'), icon: const Icon(Icons.edit_note_outlined, size: 18), label: const Text('需要重新修正')),
          ]),
        ],
      ],
    );
  }

  bool _hasStructuredRadar(CcPlanResult p) {
    return p.believedValue.trim().isNotEmpty || p.actualBehavior.trim().isNotEmpty || p.selfExplanation.trim().isNotEmpty || p.dissonancePoint.trim().isNotEmpty;
  }

  Widget _structuredRadarCard(CcPlanResult p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.radar_outlined, color: Color(0xFF4F46E5)), SizedBox(width: 8), Text('雷达结构：价值—行为—解释', style: TextStyle(fontWeight: FontWeight.w900))]),
          const SizedBox(height: 8),
          if (p.believedValue.isNotEmpty) _miniLine('我相信/重视', p.believedValue),
          if (p.actualBehavior.isNotEmpty) _miniLine('我实际做了', p.actualBehavior),
          if (p.selfExplanation.isNotEmpty) _miniLine('我如何解释', p.selfExplanation),
          if (p.dissonancePoint.isNotEmpty) _miniLine('不一致点', p.dissonancePoint),
          if (p.protectiveExplanation.isNotEmpty) _miniLine('保护性解释', p.protectiveExplanation),
          if (p.avoidanceExplanation.isNotEmpty) _miniLine('可能逃避', p.avoidanceExplanation),
          if (p.repairAction.isNotEmpty) _miniLine('修复动作', p.repairAction),
        ]),
      ),
    );
  }


  bool _hasV18GrowthConsistency(CcPlanResult p) {
    return p.dissonanceTypes.trim().isNotEmpty ||
        p.dissonanceIntensityLevel.trim().isNotEmpty ||
        p.dissonanceIntensityScore > 0 ||
        p.simultaneousAccessibility.trim().isNotEmpty ||
        p.defensiveExplanation.trim().isNotEmpty ||
        p.shortTermProtection.trim().isNotEmpty ||
        p.growthExplanation.trim().isNotEmpty ||
        p.selfIntegrityCard.trim().isNotEmpty ||
        p.informationAvoidance.trim().isNotEmpty ||
        p.identityConflict.trim().isNotEmpty;
  }

  bool _hasActionSet(CcPlanResult p) {
    return p.minimumAction.trim().isNotEmpty || p.correctiveAction.trim().isNotEmpty || p.evidenceAction.trim().isNotEmpty || p.dailyReviewSeed.trim().isNotEmpty;
  }

  Widget _v18GrowthConsistencyCard(CcPlanResult p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFF5F3FF),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.psychology_alt_outlined, color: Color(0xFF7C3AED)), SizedBox(width: 8), Expanded(child: Text('V18：自我完整 · 成长性一致 · 认知重构', style: TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 8),
          if (p.dissonanceTypes.trim().isNotEmpty) _miniLine('失调类型', p.dissonanceTypes),
          if (p.dissonanceIntensityScore > 0 || p.dissonanceIntensityLevel.trim().isNotEmpty)
            _miniLine('失调强度', '${p.dissonanceIntensityLevel.trim().isEmpty ? '未分级' : p.dissonanceIntensityLevel} · ${p.dissonanceIntensityScore}/24${p.dissonanceIntensityMainSources.trim().isEmpty ? '' : ' · 主要来源：${p.dissonanceIntensityMainSources}'}'),
          if (p.dissonanceTemperature.trim().isNotEmpty) _miniLine('失调温度计', p.dissonanceTemperature),
          if (p.simultaneousAccessibility.trim().isNotEmpty) _miniLine('矛盾同时可及', p.simultaneousAccessibility),
          if (p.defensiveExplanation.trim().isNotEmpty || p.growthExplanation.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDDD6FE))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('防御性一致 vs 成长性一致', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF5B21B6))),
                const SizedBox(height: 6),
                if (p.defensiveExplanation.trim().isNotEmpty) _miniLine('防御性解释', p.defensiveExplanation),
                if (p.shortTermProtection.trim().isNotEmpty) _miniLine('短期保护', p.shortTermProtection),
                if (p.longTermCost.trim().isNotEmpty) _miniLine('长期代价', p.longTermCost),
                if (p.growthExplanation.trim().isNotEmpty) _miniLine('成长性解释', p.growthExplanation),
              ]),
            ),
          ],
          if (p.selfIntegrityCard.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE68A))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('自我完整卡片', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF92400E))),
                const SizedBox(height: 6),
                _structuredSelfIntegrityText(p.selfIntegrityCard),
              ]),
            ),
          ],
          if (p.informationAvoidance.trim().isNotEmpty) _miniLine('信息回避挑战', p.informationAvoidance),
          if (p.identityConflict.trim().isNotEmpty) _miniLine('身份冲突重构', p.identityConflict),
        ]),
      ),
    );
  }



  Widget _structuredSelfIntegrityText(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    String pick(String label) {
      final re = RegExp('${RegExp.escape(label)}[：:](.*?)(?=我承认[：:]|我不等于[：:]|我仍然重视[：:]|我下一步证明[：:]|\$)', dotAll: true);
      final m = re.firstMatch(text);
      return m == null ? '' : (m.group(1) ?? '').trim();
    }
    final acknowledge = pick('我承认');
    final notEqual = pick('我不等于');
    final stillValue = pick('我仍然重视');
    final nextProof = pick('我下一步证明');
    if ([acknowledge, notEqual, stillValue, nextProof].every((e) => e.isEmpty)) {
      return Text(text, style: const TextStyle(height: 1.45));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (acknowledge.isNotEmpty) _miniLine('我承认', acknowledge),
      if (notEqual.isNotEmpty) _miniLine('我不等于', notEqual),
      if (stillValue.isNotEmpty) _miniLine('我仍然重视', stillValue),
      if (nextProof.isNotEmpty) _miniLine('我下一步证明', nextProof),
    ]);
  }

  Widget _actionVariantLine(CcPlanResult p, String label, CcActionVariant variant, String category) {
    final action = variant.displayText.trim().isNotEmpty ? variant.displayText.trim() : variant.rawText.trim();
    if (action.isEmpty) return const SizedBox.shrink();
    final title = variant.displayTitle.trim().isNotEmpty ? variant.displayTitle.trim() : label;
    final steps = variant.steps.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFA7F3D0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _miniLine(label, title),
        if (steps.isNotEmpty) _miniLine('步骤', steps.join(' → ')),
        if (variant.completionCriteria.trim().isNotEmpty) _miniLine('完成标准', variant.completionCriteria),
        if (variant.linkedValue.trim().isNotEmpty) _miniLine('对应价值', variant.linkedValue),
        if (steps.isEmpty && variant.completionCriteria.trim().isEmpty && variant.linkedValue.trim().isEmpty && action != title) _miniLine('行动详情', action),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: () => _activateActionVariant(p, action, label, category),
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('设为当前行动'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              _activateActionVariant(p, action, label, category, jumpToRunner: false);
              _createTodoStepFromCurrentPlan();
            },
            icon: const Icon(Icons.playlist_add_outlined),
            label: const Text('写入 Todo'),
          ),
        ]),
      ]),
    );
  }

  Widget _actionSetCard(CcPlanResult p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFECFDF5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.account_tree_outlined, color: Color(0xFF059669)), SizedBox(width: 8), Text('三类一致性行动组', style: TextStyle(fontWeight: FontWeight.w900))]),
          const SizedBox(height: 8),
          if (p.minimumActionVariant.hasContent || p.minimumAction.trim().isNotEmpty) _actionVariantLine(p, '最小行动', p.minimumActionVariant.hasContent ? p.minimumActionVariant : CcActionVariant(actionType: 'minimum', label: '最小行动', rawText: p.minimumAction), 'start'),
          if (p.correctiveActionVariant.hasContent || p.correctiveAction.trim().isNotEmpty) _actionVariantLine(p, '修正行动', p.correctiveActionVariant.hasContent ? p.correctiveActionVariant : CcActionVariant(actionType: 'corrective', label: '修正行动', rawText: p.correctiveAction), 'responsibility'),
          if (p.evidenceActionVariant.hasContent || p.evidenceAction.trim().isNotEmpty) _actionVariantLine(p, '证据行动', p.evidenceActionVariant.hasContent ? p.evidenceActionVariant : CcActionVariant(actionType: 'evidence', label: '证据行动', rawText: p.evidenceAction), 'information'),
          if (p.dailyReviewSeed.trim().isNotEmpty) _miniLine('每日复盘种子', p.dailyReviewSeed),
        ]),
      ),
    );
  }

  bool _hasModernResponsibility(CcPlanResult p) {
    return p.freedomOfChoice.trim().isNotEmpty ||
        p.negativeConsequence.trim().isNotEmpty ||
        p.foreseeability.trim().isNotEmpty ||
        p.responsibilityFeeling.trim().isNotEmpty ||
        p.userResponsibility.trim().isNotEmpty ||
        p.notUserResponsibility.trim().isNotEmpty ||
        p.repairablePart.trim().isNotEmpty;
  }

  bool _hasSelfStandards(CcPlanResult p) {
    return p.personalStandard.trim().isNotEmpty ||
        p.normativeStandard.trim().isNotEmpty ||
        p.familyOrGroupStandard.trim().isNotEmpty ||
        p.idealSelfStandard.trim().isNotEmpty ||
        p.adjustedStandard.trim().isNotEmpty;
  }

  bool _hasRationalizationMap(CcPlanResult p) {
    return p.rationalizationTypes.trim().isNotEmpty ||
        p.protectiveFunction.trim().isNotEmpty ||
        p.longTermCost.trim().isNotEmpty ||
        p.honestReframe.trim().isNotEmpty;
  }


  Map<String, dynamic> _planJson(CcPlanResult p) {
    final raw = p.rawResponse.trim();
    if (raw.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final decoded = jsonDecode(raw.substring(start, end + 1));
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _mapDyn(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
  List<dynamic> _listDyn(dynamic value) => value is List ? value : const <dynamic>[];

  String _textDyn(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is List) return value.map(_textDyn).where((e) => e.isNotEmpty).join('、');
    if (value is Map) {
      return value.entries.map((e) => '${e.key}：${_textDyn(e.value)}').where((e) => !e.endsWith('：')).join('\n');
    }
    return value.toString().trim();
  }

  Map<String, dynamic> _sourcebookMap(CcPlanResult p) {
    final parsed = _planJson(p);
    final sourcebook = _mapDyn(parsed['sourcebookAnalysis']);
    final merged = <String, dynamic>{...(sourcebook.isEmpty ? parsed : sourcebook)};
    final detail = _sourcebookDetailsBySessionId[p.sessionId.trim()];
    if (detail != null && detail.isNotEmpty) {
      final caseMap = _mapDyn(detail['case']);
      if (caseMap.isNotEmpty) {
        merged['currentStage'] = _textDyn(caseMap['current_stage']).isNotEmpty ? _textDyn(caseMap['current_stage']) : merged['currentStage'];
        merged['userConfirmation'] = _textDyn(caseMap['user_confirmation']);
        merged['integratedSelfStatement'] = _textDyn(caseMap['integrated_self_statement']).isNotEmpty ? _textDyn(caseMap['integrated_self_statement']) : merged['integratedSelfStatement'];
      }
      final nodes = _listDyn(detail['nodes']);
      final edges = _listDyn(detail['edges']);
      if (nodes.isNotEmpty || edges.isNotEmpty) {
        merged['cognitiveStructureMap'] = <String, dynamic>{'nodes': nodes, 'edges': edges};
      }
      final vl = _mapDyn(detail['valueLayers']);
      if (vl.isNotEmpty) {
        merged['valueLayers'] = <String, dynamic>{
          'coreValues': _textDyn(vl['core_values']),
          'identityBeliefs': _textDyn(vl['identity_beliefs']),
          'peripheralExplanations': _textDyn(vl['peripheral_explanations']),
          'keepItems': _textDyn(vl['keep_items']),
          'loosenItems': _textDyn(vl['loosen_items']),
          'testItems': _textDyn(vl['test_items']),
          'integratedStatement': _textDyn(vl['integrated_statement']),
        };
      }
      final choices = _listDyn(detail['choices']);
      if (choices.isNotEmpty) merged['userChoiceOptions'] = choices;
      final interpersonal = _mapDyn(detail['interpersonalBalance']);
      if (interpersonal.isNotEmpty) merged['interpersonalBalance'] = interpersonal;
      final experiment = _mapDyn(detail['counterExperiment']);
      if (experiment.isNotEmpty) merged['counterAttitudinalExperiment'] = experiment;
      final contract = _mapDyn(detail['commitmentContract']);
      if (contract.isNotEmpty) merged['commitmentAction'] = contract;
      final protectedSelf = _listDyn(detail['protectedSelfImage']);
      if (protectedSelf.isNotEmpty) merged['protectedSelfImage'] = protectedSelf;
      final defensePatterns = _listDyn(detail['defensePatterns']);
      if (defensePatterns.isNotEmpty) merged['defensePatterns'] = defensePatterns;
      final confirmations = _listDyn(detail['confirmations']);
      if (confirmations.isNotEmpty) merged['confirmations'] = confirmations;
      final evidence = _listDyn(detail['evidence']);
      if (evidence.isNotEmpty) merged['caseEvidence'] = evidence;
      final verification = _listDyn(detail['verificationTasks']);
      if (verification.isNotEmpty) merged['caseVerificationTasks'] = verification;
    }
    return merged;
  }

  String _sourcebookIntegratedText(CcPlanResult p) {
    final m = _sourcebookMap(p);
    final layers = _mapDyn(m['valueLayers']);
    final direct = _textDyn(m['integratedSelfStatement']);
    if (direct.isNotEmpty) return direct;
    final layered = _textDyn(layers['integratedStatement']);
    if (layered.isNotEmpty) return layered;
    return p.honestReframe.trim().isNotEmpty ? p.honestReframe.trim() : p.postActionExplanation;
  }

  bool _hasSourcebookStructuredResult(CcPlanResult p) {
    final m = _sourcebookMap(p);
    return _mapDyn(m['cognitiveStructureMap']).isNotEmpty ||
        _mapDyn(m['conflictTypeRouting']).isNotEmpty ||
        _mapDyn(m['psychologicalFunction']).isNotEmpty ||
        _mapDyn(m['valueLayers']).isNotEmpty ||
        _mapDyn(m['alternativeInterpretations']).isNotEmpty ||
        _listDyn(m['userChoiceOptions']).isNotEmpty ||
        _mapDyn(m['interpersonalBalance']).isNotEmpty ||
        _mapDyn(m['counterAttitudinalExperiment']).isNotEmpty ||
        _mapDyn(m['commitmentAction']).isNotEmpty ||
        _listDyn(m['protectedSelfImage']).isNotEmpty ||
        _listDyn(m['defensePatterns']).isNotEmpty ||
        _listDyn(m['realityTestingQuestions']).isNotEmpty ||
        _textDyn(m['integratedSelfStatement']).isNotEmpty;
  }

  Widget _sourcebookStructuredResultCard(CcPlanResult p) {
    final m = _sourcebookMap(p);
    final map = _mapDyn(m['cognitiveStructureMap']);
    final nodes = _listDyn(map['nodes']);
    final edges = _listDyn(map['edges']);
    final routing = _mapDyn(m['conflictTypeRouting']);
    final function = _mapDyn(m['psychologicalFunction']);
    final layers = _mapDyn(m['valueLayers']);
    final alternatives = _mapDyn(m['alternativeInterpretations']);
    final interpersonal = _mapDyn(m['interpersonalBalance']);
    final experiment = _mapDyn(m['counterAttitudinalExperiment']);
    final contract = _mapDyn(m['commitmentAction']);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFFFFBEB),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.hub_outlined, color: Color(0xFFD97706)), SizedBox(width: 8), Expanded(child: Text('V25 认知失调解决引擎结果', style: TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 8),
          if (_listDyn(m['protectedSelfImage']).isNotEmpty) _miniLine('被保护的自我形象', _textDyn(m['protectedSelfImage'])),
          if (_listDyn(m['defensePatterns']).isNotEmpty) _miniLine('自我辩护/防御模式', _textDyn(m['defensePatterns'])),
          if (nodes.isNotEmpty) _sourcebookNodeStatusCard(p, nodes),
          if (edges.isNotEmpty) _sourcebookEdgeStatusCard(p, edges),
          if (_listDyn(routing['types']).isNotEmpty) _sourcebookSubCard('矛盾类型分流', Icons.call_split_outlined, _listDyn(routing['types']).map((e) => _textDyn(e)).where((e) => e.isNotEmpty).toList()),
          if (function.isNotEmpty) _sourcebookKeyValueCard('心理功能分析', function),
          if (layers.isNotEmpty) _sourcebookKeyValueCard('核心价值 / 身份信念 / 外围解释', layers),
          if (alternatives.isNotEmpty) _sourcebookKeyValueCard('三种可能解释', alternatives),
          if (_listDyn(m['realityTestingQuestions']).isNotEmpty) _sourcebookSubCard('现实检验问题', Icons.fact_check_outlined, _listDyn(m['realityTestingQuestions']).map(_textDyn).where((e) => e.isNotEmpty).toList()),
          if (_listDyn(m['userChoiceOptions']).isNotEmpty) _sourcebookChoiceOptionsCard(p, _listDyn(m['userChoiceOptions'])),
          if (interpersonal.isNotEmpty) _sourcebookInterpersonalCard(p, interpersonal),
          if (experiment.isNotEmpty) _sourcebookCounterExperimentCard(p, experiment),
          if (contract.isNotEmpty) _sourcebookContractCard(p, contract),
          if (_listDyn(m['reflectionQuestions']).isNotEmpty) _sourcebookSubCard('复盘问题', Icons.rate_review_outlined, _listDyn(m['reflectionQuestions']).map(_textDyn).where((e) => e.isNotEmpty).toList()),
          if (_sourcebookIntegratedText(p).trim().isNotEmpty) _miniLine('新的整合性表达', _sourcebookIntegratedText(p)),
        ]),
      ),
    );
  }


  Widget _sourcebookNodeStatusCard(CcPlanResult p, List<dynamic> nodes) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.account_tree_outlined, size: 18, color: Color(0xFFD97706)), SizedBox(width: 6), Text('认知结构节点｜可确认/修正', style: TextStyle(fontWeight: FontWeight.w900))]),
        const SizedBox(height: 6),
        ...nodes.take(10).map((raw) {
          final n = _mapDyn(raw);
          final id = _textDyn(n['node_id']);
          final title = _textDyn(n['label']).isNotEmpty ? _textDyn(n['label']) : _textDyn(n['nodeType']);
          final content = _textDyn(n['content']).isNotEmpty ? _textDyn(n['content']) : _textDyn(raw);
          final status = _textDyn(n['user_status']).isEmpty ? 'ai_generated' : _textDyn(n['user_status']);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _miniLine('$title｜$status', content),
              if (id.isNotEmpty) Wrap(spacing: 6, runSpacing: 4, children: [
                TextButton.icon(onPressed: () => _updateNodeStatus(id, 'confirmed'), icon: const Icon(Icons.check, size: 16), label: const Text('准确')),
                TextButton.icon(onPressed: () => _editSourcebookNodeDialog(n), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('需修正')),
                TextButton.icon(onPressed: () => _updateNodeStatus(id, 'rejected'), icon: const Icon(Icons.close, size: 16), label: const Text('不成立')),
              ]),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _sourcebookEdgeStatusCard(CcPlanResult p, List<dynamic> edges) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.compare_arrows_outlined, size: 18, color: Color(0xFFD97706)), SizedBox(width: 6), Text('冲突/一致关系边｜可确认/修正', style: TextStyle(fontWeight: FontWeight.w900))]),
        const SizedBox(height: 6),
        ...edges.take(10).map((raw) {
          final e = _mapDyn(raw);
          final id = _textDyn(e['edge_id']);
          final from = _textDyn(e['from_label']).isNotEmpty ? _textDyn(e['from_label']) : _textDyn(e['from']);
          final to = _textDyn(e['to_label']).isNotEmpty ? _textDyn(e['to_label']) : _textDyn(e['to']);
          final relation = _textDyn(e['relation_type']).isNotEmpty ? _textDyn(e['relation_type']) : _textDyn(e['relationType']);
          final desc = _textDyn(e['description']);
          final status = _textDyn(e['user_status']).isEmpty ? 'ai_generated' : _textDyn(e['user_status']);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _miniLine('$from → $to｜$relation｜$status', desc),
              if (id.isNotEmpty) Wrap(spacing: 6, runSpacing: 4, children: [
                TextButton.icon(onPressed: () => _updateEdgeStatus(id, 'confirmed'), icon: const Icon(Icons.check, size: 16), label: const Text('准确')),
                TextButton.icon(onPressed: () => _editSourcebookEdgeDialog(e), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('需修正')),
                TextButton.icon(onPressed: () => _updateEdgeStatus(id, 'rejected'), icon: const Icon(Icons.close, size: 16), label: const Text('不成立')),
              ]),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _sourcebookChoiceOptionsCard(CcPlanResult p, List<dynamic> options) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.touch_app_outlined, size: 18, color: Color(0xFFD97706)), SizedBox(width: 6), Text('用户自主选择区｜AI 给方向，选择权交还给用户', style: TextStyle(fontWeight: FontWeight.w900))]),
        const SizedBox(height: 6),
        ...options.map((raw) {
          final m = _mapDyn(raw);
          final id = _textDyn(m['choice_id']);
          final label = _textDyn(m['label']).isNotEmpty ? _textDyn(m['label']) : '可选方向';
          final desc = _textDyn(m['description']);
          final action = _textDyn(m['next_action']).isNotEmpty ? _textDyn(m['next_action']) : _textDyn(m['nextAction']);
          final selected = _textDyn(m['selected']) == '1' || m['selected'] == 1 || m['selected'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: selected ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _miniLine(selected ? '已选择：$label' : label, desc),
              if (action.isNotEmpty) _miniLine('下一步', action),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (id.isNotEmpty) TextButton.icon(onPressed: () => _selectSourcebookChoice(id), icon: const Icon(Icons.check_circle_outline, size: 16), label: const Text('选择这个方向')),
                if (action.isNotEmpty) TextButton.icon(onPressed: () => _quickCreateTodoActionFromText(action, label, actionType: 'sourcebook_choice_action'), icon: const Icon(Icons.playlist_add_outlined, size: 16), label: const Text('写入 Todo')),
              ]),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _sourcebookContractCard(CcPlanResult p, Map<String, dynamic> data) {
    final id = _textDyn(data['contract_id']);
    final action = _textDyn(data['minimal_repair_action']).isNotEmpty ? _textDyn(data['minimal_repair_action']) : _textDyn(data['minimalRepairAction']);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('一致性行动契约｜可执行、可完成、可复盘', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF92400E))),
        const SizedBox(height: 6),
        _sourcebookKeyValueCard('契约内容', data),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (action.isNotEmpty) TextButton.icon(onPressed: () => _activateSourcebookContract(p, data), icon: const Icon(Icons.play_arrow_outlined, size: 16), label: const Text('设为当前行动')),
          if (action.isNotEmpty) TextButton.icon(onPressed: () => _quickCreateTodoActionFromText(action, '源书行动契约', actionType: 'sourcebook_contract'), icon: const Icon(Icons.playlist_add_outlined, size: 16), label: const Text('写入 Todo')),
          if (id.isNotEmpty) TextButton.icon(onPressed: () => _completeSourcebookContractDialog(id, action), icon: const Icon(Icons.task_alt_outlined, size: 16), label: const Text('完成并写入证据')),
          if (id.isNotEmpty) TextButton.icon(onPressed: () => _reviewIncompleteSourcebookContractDialog(id, status: 'failed'), icon: const Icon(Icons.report_problem_outlined, size: 16), label: const Text('未完成复盘')),
          if (id.isNotEmpty) TextButton.icon(onPressed: () => _reviewIncompleteSourcebookContractDialog(id, status: 'adjusted'), icon: const Icon(Icons.tune_outlined, size: 16), label: const Text('调整/降级')),
        ]),
      ]),
    );
  }

  Widget _sourcebookCounterExperimentCard(CcPlanResult p, Map<String, dynamic> data) {
    final id = _textDyn(data['experiment_id']);
    final action = _textDyn(data['experiment_action']).isNotEmpty ? _textDyn(data['experiment_action']) : _textDyn(data['experimentAction']);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('反态度行为实验｜用小行动松动旧信念', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF92400E))),
        const SizedBox(height: 6),
        _sourcebookKeyValueCard('实验内容', data),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (action.isNotEmpty) TextButton.icon(onPressed: () => _quickCreateTodoActionFromText(action, '反态度行为实验', actionType: 'counter_attitudinal_experiment'), icon: const Icon(Icons.playlist_add_outlined, size: 16), label: const Text('写入 Todo')),
          if (id.isNotEmpty) TextButton.icon(onPressed: () => _reviewCounterExperimentDialog(id), icon: const Icon(Icons.rate_review_outlined, size: 16), label: const Text('实验复盘')),
        ]),
      ]),
    );
  }

  Widget _sourcebookInterpersonalCard(CcPlanResult p, Map<String, dynamic> data) {
    final id = _textDyn(data['record_id']);
    final action = _textDyn(data['boundary_action']).isNotEmpty ? _textDyn(data['boundary_action']) : _textDyn(data['boundaryAction']);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('人际平衡分析｜从三角失衡走向边界/沟通行动', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF92400E))),
        const SizedBox(height: 6),
        _sourcebookKeyValueCard('人际结构', data),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (action.isNotEmpty) TextButton.icon(onPressed: () => _quickCreateTodoActionFromText(action, '人际边界/沟通行动', actionType: 'interpersonal_balance_action'), icon: const Icon(Icons.playlist_add_outlined, size: 16), label: const Text('写入沟通/边界行动')),
          if (id.isNotEmpty) TextButton.icon(onPressed: () => _completeInterpersonalActionDialog(id), icon: const Icon(Icons.task_alt_outlined, size: 16), label: const Text('记录沟通结果')),
        ]),
      ]),
    );
  }

  Widget _sourcebookSubCard(String title, IconData icon, List<String> lines) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 18, color: const Color(0xFFD97706)), const SizedBox(width: 6), Text(title, style: const TextStyle(fontWeight: FontWeight.w900))]),
        const SizedBox(height: 6),
        ...lines.map((e) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $e', style: const TextStyle(height: 1.35)))),
      ]),
    );
  }

  Widget _sourcebookKeyValueCard(String title, Map<String, dynamic> data) {
    final entries = data.entries.where((e) => _textDyn(e.value).isNotEmpty).toList(growable: false);
    if (entries.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF92400E))),
        const SizedBox(height: 6),
        ...entries.map((e) => _miniLine(e.key.toString(), _textDyn(e.value))),
      ]),
    );
  }


  Future<void> _updateNodeStatus(String nodeId, String status) async {
    await _dao.updateSourcebookNodeUserStatus(nodeId: nodeId, status: status);
    _toast(status == 'confirmed' ? '已确认该节点准确。' : status == 'rejected' ? '已标记该节点不成立。' : '已标记该节点需要修正。');
    await _load();
  }

  Future<void> _updateEdgeStatus(String edgeId, String status) async {
    await _dao.updateSourcebookEdgeUserStatus(edgeId: edgeId, status: status);
    _toast(status == 'confirmed' ? '已确认该关系准确。' : status == 'rejected' ? '已标记该关系不成立。' : '已标记该关系需要修正。');
    await _load();
  }


  Future<void> _editSourcebookNodeDialog(Map<String, dynamic> node) async {
    final id = _textDyn(node['node_id']);
    if (id.isEmpty) return;
    final labelCtrl = TextEditingController(text: _textDyn(node['label']));
    final typeCtrl = TextEditingController(text: _textDyn(node['node_type']).isNotEmpty ? _textDyn(node['node_type']) : _textDyn(node['nodeType']));
    final contentCtrl = TextEditingController(text: _textDyn(node['content']));
    final noteCtrl = TextEditingController(text: _textDyn(node['user_note']));
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修正认知节点'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: '节点标题')),
          const SizedBox(height: 8),
          TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: '节点类型 belief/value/behavior/self/relation/evidence')),
          const SizedBox(height: 8),
          TextField(controller: contentCtrl, maxLines: 3, decoration: const InputDecoration(labelText: '用户修正版内容')),
          const SizedBox(height: 8),
          TextField(controller: noteCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '修正原因/备注')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存修正')),
        ],
      ),
    );
    if (ok == true) {
      await _dao.updateSourcebookNodeUserStatus(nodeId: id, status: 'revised', note: noteCtrl.text, label: labelCtrl.text, content: contentCtrl.text, nodeType: typeCtrl.text);
      _toast('已保存节点修正版。');
      await _load();
    }
    labelCtrl.dispose(); typeCtrl.dispose(); contentCtrl.dispose(); noteCtrl.dispose();
  }

  Future<void> _editSourcebookEdgeDialog(Map<String, dynamic> edge) async {
    final id = _textDyn(edge['edge_id']);
    if (id.isEmpty) return;
    final relationCtrl = TextEditingController(text: _textDyn(edge['relation_type']).isNotEmpty ? _textDyn(edge['relation_type']) : _textDyn(edge['relationType']));
    final descCtrl = TextEditingController(text: _textDyn(edge['description']));
    final noteCtrl = TextEditingController(text: _textDyn(edge['user_note']));
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修正关系边'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: relationCtrl, decoration: const InputDecoration(labelText: '关系类型 consistent / inconsistent / uncertain')),
          const SizedBox(height: 8),
          TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: '用户修正版关系说明')),
          const SizedBox(height: 8),
          TextField(controller: noteCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '修正原因/备注')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存修正')),
        ],
      ),
    );
    if (ok == true) {
      await _dao.updateSourcebookEdgeUserStatus(edgeId: id, status: 'revised', note: noteCtrl.text, relationType: relationCtrl.text, description: descCtrl.text);
      _toast('已保存关系边修正版。');
      await _load();
    }
    relationCtrl.dispose(); descCtrl.dispose(); noteCtrl.dispose();
  }

  Future<void> _selectSourcebookChoice(String choiceId) async {
    await _dao.selectSourcebookChoice(choiceId);
    _toast('已选择该方向，并把案例推进到行动契约阶段。');
    await _load();
  }

  Future<void> _activateSourcebookContract(CcPlanResult p, Map<String, dynamic> data) async {
    final action = _textDyn(data['minimal_repair_action']).isNotEmpty ? _textDyn(data['minimal_repair_action']) : _textDyn(data['minimalRepairAction']);
    final coreValue = _textDyn(data['core_value']).isNotEmpty ? _textDyn(data['core_value']) : _textDyn(data['coreValue']);
    if (action.isEmpty) {
      _toast('行动契约里还没有可执行行动。');
      return;
    }
    final activated = p.copyWith(
      oneDollarAction: action,
      valueLink: coreValue.isNotEmpty ? coreValue : p.valueLink,
      evidenceLabel: '完成源书一致性行动契约',
      evidenceCategory: 'responsibility',
      oldStory: _textDyn(data['current_inconsistent_behavior']).isNotEmpty ? _textDyn(data['current_inconsistent_behavior']) : p.oldStory,
    );
    final contractId = _textDyn(data['contract_id']);
    if (contractId.isNotEmpty) {
      await _dao.updateSourcebookContractStatus(contractId: contractId, status: 'in_progress');
    }
    _activatePlan(activated, sourceType: 'cc_sourcebook_contract', sourceId: contractId);
    await _load();
  }

  Future<void> _completeSourcebookContractDialog(String contractId, String defaultAction) async {
    final actionCtrl = TextEditingController(text: defaultAction);
    final reflectionCtrl = TextEditingController();
    final minutesCtrl = TextEditingController(text: '3');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('完成源书行动契约'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: actionCtrl, maxLines: 3, decoration: const InputDecoration(labelText: '实际完成的行动')),
          const SizedBox(height: 8),
          TextField(controller: reflectionCtrl, maxLines: 3, decoration: const InputDecoration(labelText: '复盘：它如何连接价值与行为？')),
          const SizedBox(height: 8),
          TextField(controller: minutesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '行动分钟数')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存证据')),
        ],
      ),
    );
    if (ok != true) return;
    await _dao.completeSourcebookContractAsEvidence(
      contractId: contractId,
      completedAction: actionCtrl.text,
      reflection: reflectionCtrl.text,
      effortMinutes: int.tryParse(minutesCtrl.text.trim()) ?? 0,
      difficultyScore: _difficultyScore,
    );
    actionCtrl.dispose();
    reflectionCtrl.dispose();
    minutesCtrl.dispose();
    _toast('已完成行动契约，并写入行动证据账本。');
    await _load();
  }


  Future<void> _reviewIncompleteSourcebookContractDialog(String contractId, {required String status}) async {
    final reflectionCtrl = TextEditingController();
    final fallbackCtrl = TextEditingController(text: status == 'adjusted' ? '降级为 2 分钟版本，先完成最小可见动作。' : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(status == 'adjusted' ? '调整/降级行动契约' : '未完成行动契约复盘'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: reflectionCtrl, maxLines: 3, decoration: const InputDecoration(labelText: '发生了什么？阻力/失调信号是什么？')),
          const SizedBox(height: 8),
          if (status == 'adjusted') TextField(controller: fallbackCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '新的降级/替代方案')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存复盘')),
        ],
      ),
    );
    if (ok != true) return;
    await _dao.markSourcebookContractIncomplete(contractId: contractId, status: status, reflection: reflectionCtrl.text, fallbackPlan: fallbackCtrl.text);
    reflectionCtrl.dispose(); fallbackCtrl.dispose();
    _toast(status == 'adjusted' ? '已记录调整/降级，并写入学习证据。' : '已记录未完成复盘，并写入学习证据。');
    await _load();
  }

  Future<void> _reviewCounterExperimentDialog(String experimentId) async {
    final resultCtrl = TextEditingController();
    final beliefCtrl = TextEditingController();
    var score = 5;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('反态度实验复盘'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: resultCtrl, maxLines: 3, decoration: const InputDecoration(labelText: '实验结果观察')),
            const SizedBox(height: 8),
            TextField(controller: beliefCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '新的更准确自我信念')),
            const SizedBox(height: 8),
            Text('旧信念松动程度：$score/10'),
            Slider(value: score.toDouble(), min: 0, max: 10, divisions: 10, label: '$score', onChanged: (v) => setDialogState(() => score = v.round())),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存复盘')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _dao.updateCounterAttitudinalExperimentReview(experimentId: experimentId, result: resultCtrl.text, beliefShiftScore: score, updatedBelief: beliefCtrl.text);
    resultCtrl.dispose();
    beliefCtrl.dispose();
    _toast('已保存反态度实验复盘。');
    await _load();
  }

  Future<void> _completeInterpersonalActionDialog(String recordId) async {
    final resultCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('记录人际沟通/边界结果'),
        content: TextField(controller: resultCtrl, maxLines: 4, decoration: const InputDecoration(labelText: '对方反应、关系变化、边界是否更清楚')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    await _dao.updateInterpersonalBalanceAction(recordId: recordId, status: 'completed', result: resultCtrl.text);
    resultCtrl.dispose();
    _toast('已保存人际平衡行动结果。');
    await _load();
  }

  void _showSourcebookCaseDetail(CcPlanResult p) {
    final detail = _sourcebookDetailsBySessionId[p.sessionId.trim()] ?? const <String, dynamic>{};
    final m = _sourcebookMap(p);
    final nodes = _listDyn(m['cognitiveStructureMap'] is Map ? _mapDyn(m['cognitiveStructureMap'])['nodes'] : detail['nodes']);
    final edges = _listDyn(m['cognitiveStructureMap'] is Map ? _mapDyn(m['cognitiveStructureMap'])['edges'] : detail['edges']);
    final evidence = _listDyn(m['caseEvidence']);
    final verifications = _listDyn(m['caseVerificationTasks']);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('源书案例详情'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _miniLine('当前阶段', _textDyn(m['currentStage']).isEmpty ? 'structure_map' : _textDyn(m['currentStage'])),
            _miniLine('用户确认', _textDyn(m['userConfirmation']).isEmpty ? 'pending' : _textDyn(m['userConfirmation'])),
            _miniLine('事件摘要', p.eventSummary.isNotEmpty ? p.eventSummary : p.coreConflict),
            if (nodes.isNotEmpty) _sourcebookSubCard('认知节点', Icons.account_tree_outlined, nodes.take(20).map(_textDyn).where((e) => e.isNotEmpty).toList()),
            if (edges.isNotEmpty) _sourcebookSubCard('关系边', Icons.compare_arrows_outlined, edges.take(20).map(_textDyn).where((e) => e.isNotEmpty).toList()),
            if (_mapDyn(m['valueLayers']).isNotEmpty) _sourcebookKeyValueCard('价值分层', _mapDyn(m['valueLayers'])),
            if (_listDyn(m['userChoiceOptions']).isNotEmpty) _sourcebookChoiceOptionsCard(p, _listDyn(m['userChoiceOptions'])),
            if (_mapDyn(m['commitmentAction']).isNotEmpty) _sourcebookContractCard(p, _mapDyn(m['commitmentAction'])),
            if (evidence.isNotEmpty) _sourcebookSubCard('行动证据', Icons.inventory_2_outlined, evidence.map(_textDyn).where((e) => e.isNotEmpty).toList()),
            if (verifications.isNotEmpty) _sourcebookSubCard('现实验证任务', Icons.fact_check_outlined, verifications.map(_textDyn).where((e) => e.isNotEmpty).toList()),
            if (_sourcebookIntegratedText(p).isNotEmpty) _miniLine('整合性表达', _sourcebookIntegratedText(p)),
          ])),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('关闭'))],
      ),
    );
  }

  Future<void> _confirmSourcebookAnalysis(CcPlanResult plan, String level) async {
    final sid = plan.sessionId.trim();
    if (sid.isEmpty) {
      _toast('当前分析还没有生成 session，无法确认。');
      return;
    }
    await _dao.saveSourcebookConfirmation(sessionId: sid, confirmationLevel: level);
    if (!mounted) return;
    _toast(level == 'confirmed' ? '已确认分析基本准确。' : level == 'partial' ? '已记录：部分准确，后续可修正。' : '已记录：需要重新修正。');
    await _load();
  }

  bool _hasSpecialStructuredResult(CcPlanResult p) {
    return p.choicePaths.trim().isNotEmpty ||
        p.sunkCostCheck.trim().isNotEmpty ||
        p.hypocrisyInduction.trim().isNotEmpty ||
        p.groupConflict.trim().isNotEmpty ||
        p.vicariousDissonance.trim().isNotEmpty ||
        p.informationAvoidance.trim().isNotEmpty ||
        p.identityConflict.trim().isNotEmpty ||
        p.todoWriteBackInsight.trim().isNotEmpty ||
        p.dissonanceReductionMode.trim().isNotEmpty ||
        p.verificationQuestion.trim().isNotEmpty;
  }

  String _reductionModeLabel(String mode) {
    switch (mode.trim()) {
      case 'action_repair':
        return '行动型修复';
      case 'responsibility_repair':
        return '责任修复';
      case 'relationship_repair':
        return '关系修复';
      case 'value_alignment':
        return '价值对齐';
      case 'avoidance_risk':
        return '仍有逃避风险';
      case 'explanation_only':
      default:
        return '解释型缓解';
    }
  }

  Widget _specialStructuredResultCard(CcPlanResult p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.account_tree_outlined, color: Color(0xFF334155)), SizedBox(width: 8), Expanded(child: Text('专项结构化结果', style: TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 8),
          if (p.choicePaths.isNotEmpty) _miniLine('继续/调整/暂停/转向四路径', p.choicePaths),
          if (p.sunkCostCheck.isNotEmpty) _miniLine('沉没成本检查', p.sunkCostCheck),
          if (p.hypocrisyInduction.isNotEmpty) _miniLine('价值—行为距离', p.hypocrisyInduction),
          if (p.groupConflict.isNotEmpty) _miniLine('群体/关系/文化冲突', p.groupConflict),
          if (p.vicariousDissonance.isNotEmpty) _miniLine('替代性失调', p.vicariousDissonance),
          if (p.todoWriteBackInsight.isNotEmpty) _miniLine('Todo/问题树回写摘要', p.todoWriteBackInsight),
          if (p.informationAvoidance.isNotEmpty) _informationAvoidanceBranchCard(p),
          if (p.identityConflict.isNotEmpty) _identityDialogueCard(p),
          if (p.dissonanceReductionMode.isNotEmpty) _miniLine('降低失调方式', _reductionModeLabel(p.dissonanceReductionMode)),
          if (p.verificationQuestion.isNotEmpty) _miniLine('现实验证任务', '${p.verificationQuestion}${p.verificationSuccessSignal.isNotEmpty ? '\n成功信号：${p.verificationSuccessSignal}' : ''}'),
        ]),
      ),
    );
  }


  Widget _informationAvoidanceBranchCard(CcPlanResult p) {
    final b = p.informationAvoidanceBranches;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFBFDBFE))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('信息回避挑战结果分支', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8))),
        const SizedBox(height: 6),
        if (b.avoidedInformation.trim().isNotEmpty) _miniLine('正在回避的信息', b.avoidedInformation),
        if (b.fearedResult.trim().isNotEmpty) _miniLine('害怕看到的结果', b.fearedResult),
        _miniLine('最小接触行动', b.smallestContactAction.trim().isNotEmpty ? b.smallestContactAction : p.informationAvoidance),
        if (b.betterThanExpected.trim().isNotEmpty) _miniLine('如果结果比想象好', b.betterThanExpected),
        if (b.worseThanExpected.trim().isNotEmpty) _miniLine('如果结果确实不好', b.worseThanExpected),
        if (b.ambiguous.trim().isNotEmpty) _miniLine('如果结果仍然模糊', b.ambiguous),
        if (b.nextInformationAction.trim().isNotEmpty) _miniLine('下一步信息行动', b.nextInformationAction),
      ]),
    );
  }

  Widget _identityDialogueCard(CcPlanResult p) {
    final d = p.identityDialogue;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFFDF4FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF0ABFC))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('旧身份—新身份对话', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFA21CAF))),
        const SizedBox(height: 6),
        if (d.oldIdentity.trim().isNotEmpty) _miniLine('旧身份', d.oldIdentity),
        if (d.oldIdentityVoice.trim().isNotEmpty) _miniLine('旧身份声音', d.oldIdentityVoice),
        if (d.oldIdentityProtection.trim().isNotEmpty) _miniLine('旧身份的保护', d.oldIdentityProtection),
        if (d.newIdentity.trim().isNotEmpty) _miniLine('新身份', d.newIdentity),
        if (d.newIdentityVoice.trim().isNotEmpty) _miniLine('新身份声音', d.newIdentityVoice),
        if (d.fearOfLoss.trim().isNotEmpty) _miniLine('害怕失去', d.fearOfLoss),
        _miniLine('今日新身份证据', d.newIdentityAction.trim().isNotEmpty ? d.newIdentityAction : (p.minimumActionVariant.hasContent ? p.minimumActionVariant.displayText : (p.minimumAction.trim().isNotEmpty ? p.minimumAction : p.oneDollarAction))),
        if (d.postActionIdentitySentence.trim().isNotEmpty) _miniLine('行动后解释语', d.postActionIdentitySentence),
        if (!d.hasContent && p.identityConflict.trim().isNotEmpty) _miniLine('身份冲突重构', p.identityConflict),
      ]),
    );
  }

  bool _hasTrueSelfBridge(CcPlanResult p) {
    return _shouldSyncTrueSelfEvidence(p);
  }

  Widget _responsibilityBoundaryCard(CcPlanResult p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFF0FDF4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.balance_outlined, color: Color(0xFF047857)), SizedBox(width: 8), Text('责任—后果雷达', style: TextStyle(fontWeight: FontWeight.w900))]),
          const SizedBox(height: 8),
          if (p.freedomOfChoice.isNotEmpty) _miniLine('自由选择', p.freedomOfChoice),
          if (p.negativeConsequence.isNotEmpty) _miniLine('不想要的后果', p.negativeConsequence),
          if (p.foreseeability.isNotEmpty) _miniLine('可预见性', p.foreseeability),
          if (p.responsibilityFeeling.isNotEmpty) _miniLine('责任感', p.responsibilityFeeling),
          if (p.repairability.isNotEmpty) _miniLine('可修复性', p.repairability),
          if (p.notUserResponsibility.isNotEmpty) _miniLine('不属于我的责任', p.notUserResponsibility),
          if (p.userResponsibility.isNotEmpty) _miniLine('需要适度负责', p.userResponsibility),
          if (p.overBlameRisk.isNotEmpty) _miniLine('过度自责风险', p.overBlameRisk),
          if (p.avoidanceRisk.isNotEmpty) _miniLine('逃避责任风险', p.avoidanceRisk),
          if (p.repairablePart.isNotEmpty) _miniLine('现在可修复部分', p.repairablePart),
        ]),
      ),
    );
  }

  Widget _selfStandardsCard(CcPlanResult p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFEFF6FF),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.rule_outlined, color: Color(0xFF2563EB)), SizedBox(width: 8), Text('自我标准地图', style: TextStyle(fontWeight: FontWeight.w900))]),
          const SizedBox(height: 8),
          if (p.personalStandard.isNotEmpty) _miniLine('个人标准', p.personalStandard),
          if (p.normativeStandard.isNotEmpty) _miniLine('规范/道德标准', p.normativeStandard),
          if (p.familyOrGroupStandard.isNotEmpty) _miniLine('家庭/群体/文化标准', p.familyOrGroupStandard),
          if (p.idealSelfStandard.isNotEmpty) _miniLine('理想自我标准', p.idealSelfStandard),
          if (p.adjustedStandard.isNotEmpty) _miniLine('更成熟的新标准', p.adjustedStandard),
        ]),
      ),
    );
  }

  Widget _rationalizationMapCard(CcPlanResult p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFFFFBEB),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.psychology_outlined, color: Color(0xFFB45309)), SizedBox(width: 8), Text('合理化识别器 2.0', style: TextStyle(fontWeight: FontWeight.w900))]),
          const SizedBox(height: 8),
          if (p.rationalizationTypes.isNotEmpty) _miniLine('可能类型', p.rationalizationTypes),
          if (p.protectiveFunction.isNotEmpty) _miniLine('保护功能', p.protectiveFunction),
          if (p.longTermCost.isNotEmpty) _miniLine('长期代价', p.longTermCost),
          if (p.honestReframe.isNotEmpty) _miniLine('诚实但不羞辱的改写', p.honestReframe),
        ]),
      ),
    );
  }

  Widget _trueSelfBridgeCard(CcPlanResult p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFFDF2F8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.favorite_border_outlined, color: Color(0xFFBE185D)), SizedBox(width: 8), Expanded(child: Text('足下真实自我联动', style: TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 8),
          if (p.shameSignal.isNotEmpty) _miniLine('羞耻/身份审判信号', p.shameSignal),
          if (p.toxicShameLanguage.isNotEmpty) _miniLine('可能的毒性羞耻语言', p.toxicShameLanguage),
          if (p.healthyShameReframe.isNotEmpty) _miniLine('健康羞耻改写', p.healthyShameReframe),
          if (p.recommendedShameScene.isNotEmpty) _miniLine('建议真实自我场景', p.recommendedShameScene),
          if (p.trueSelfBridgeReason.isNotEmpty) _miniLine('联动理由', p.trueSelfBridgeReason),
          if (p.truePrideSentence.isNotEmpty) _miniLine('可沉淀真实骄傲', p.truePrideSentence),
          const SizedBox(height: 6),
          const Text('保存行动证据时，如果这里存在羞耻/身份审判信号，系统会同步写入足下真实自我的真实骄傲证据墙，并保留追踪链路。', style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF9D174D))),
        ]),
      ),
    );
  }

  Widget _infoCard(String title, String body, IconData icon, {bool emphasize = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: emphasize ? const Color(0xFFFFFBEB) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: emphasize ? const Color(0xFFB45309) : const Color(0xFF4F46E5)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(body.trim().isEmpty ? '暂无' : body, style: const TextStyle(height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSpecialSceneFields() {
    final meta = _specialFieldMeta(_specialSceneKey);
    final ctrls = [_specialField1Ctrl, _specialField2Ctrl, _specialField3Ctrl, _specialField4Ctrl];
    if (meta.isEmpty) return const <Widget>[];
    final widgets = <Widget>[];
    for (var i = 0; i < meta.length && i < ctrls.length; i++) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: ctrls[i],
          minLines: i == 0 ? 1 : 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: meta[i]['label'] ?? '',
            hintText: meta[i]['hint'] ?? '',
            border: const OutlineInputBorder(),
          ),
        ),
      ));
    }
    return widgets;
  }

  Widget _buildSpecialScenesTab() {
    final sceneHint = <String, String>{
      'choice_recheck': '描述一个你已经选择、但现在不断想证明“我没选错”的事情。',
      'sunk_cost': '描述一个已经投入很多、不甘心暂停或转向的项目/关系/职业/目标。',
      'hypocrisy_change': '写下一个你认同的价值，以及最近一次没有做到的具体行为。',
      'group_culture': '描述家庭、朋友、团队、社会评价或文化角色和你个人价值的冲突。',
      'vicarious_dissonance': '描述一个“我们的人/我支持的人/我的群体”做了让你不舒服的事。',
      'responsibility_radar': '描述一个后悔、内疚、伤害、承诺失败、过度自责或责任逃避事件。',
      'self_standard_map': '描述一个你正在用某种标准评价、审判或否定自己的情境。',
      'information_avoidance': '描述你不敢看的结果、反馈、账单、数据、成绩、体检、消息或反对证据。',
      'identity_conflict': '描述旧身份和新身份的拉扯，例如逃避者与行动者、讨好者与有边界的人。',
      'cognitive_structure_map': '把信念、行为、自我形象、关系和现实反馈放到同一张地图里看。',
      'conflict_type_router': '把当前矛盾分流为信念冲突、价值—行为冲突、自我冲突、角色冲突、决策后失调等。',
      'psychological_function': '分析某个想法/行为正在保护什么、回避什么、维持什么，以及未来代价。',
      'value_layering': '区分核心价值、身份信念和外围解释，避免把临时借口误当成人生真理。',
      'interpersonal_balance': '分析“我—他人—对象/观点/事件”的三角关系，寻找可承受的人际平衡。',
      'counter_attitudinal_experiment': '设计一个低风险反态度行为，用行动证明旧自我叙事不是绝对事实。',
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _emptyCard('现代认知失调专项场景', '把 v14 里已接入的责任—后果、自我标准、合理化类型和真实自我桥接，拆成可反复使用的专项流程：选择后合理化、沉没成本、虚伪诱导、群体文化失调、替代性失调、责任—后果雷达、自我标准地图、信息回避挑战、身份冲突重构。'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _specialSceneLabels.entries
              .map((e) => ChoiceChip(
                    label: Text(e.value),
                    selected: _specialSceneKey == e.key,
                    onSelected: (_) => setState(() {
                      _specialSceneKey = e.key;
                      _specialPlan = null;
                      _specialField1Ctrl.clear();
                      _specialField2Ctrl.clear();
                      _specialField3Ctrl.clear();
                      _specialField4Ctrl.clear();
                    }),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        ..._buildSpecialSceneFields(),
        TextField(
          controller: _specialCtrl,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: '补充背景（可选）',
            hintText: sceneHint[_specialSceneKey] ?? '描述一个认知失调事件',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _specialBusy ? null : _analyzeSpecialScene,
          icon: _specialBusy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.psychology_alt_outlined),
          label: Text(_specialBusy ? '分析中...' : '开始${_specialSceneLabels[_specialSceneKey] ?? '专项'}分析'),
        ),
        const SizedBox(height: 12),
        if (_specialPlan != null) _planCard(_specialPlan!, sourceType: _toolSourceType(_specialSceneKey), sourceId: _toolSourceId()),
        const SizedBox(height: 18),
        _specialHistorySection(),
        const SizedBox(height: 18),
        _verificationTasksSection(),
      ],
    );
  }

  Widget _verificationTasksSection() {
    if (_verificationTasks.isEmpty) return _emptyCard('专项验证任务', '专项分析会自动生成 3-7 天后的现实验证任务：不是只分析一次，而是回到现实中检验判断是否有效。');
    String dueText(int ms) {
      if (ms <= 0) return '未设置';
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${dt.month}/${dt.day}';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('专项验证任务', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      ..._verificationTasks.take(10).map((task) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(task.status == 'open' ? Icons.pending_actions_outlined : Icons.task_alt_outlined, color: const Color(0xFF0F766E)),
              title: Text(task.question, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('到期：${dueText(task.dueAtMs)}｜状态：${task.status}${task.successSignal.isNotEmpty ? '\n成功信号：${task.successSignal}' : ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
              trailing: task.status == 'open'
                  ? TextButton(
                      onPressed: () => _completeVerificationTask(task),
                      child: const Text('验证'),
                    )
                  : const Icon(Icons.check_circle_outline),
            ),
          )),
    ]);
  }

  Future<void> _completeVerificationTask(CcVerificationTask task) async {
    final ctrl = TextEditingController(text: task.resultNote);
    var status = 'verified';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('记录现实验证结果'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: '验证结论', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'verified', child: Text('有效：行动确实降低失调')),
                  DropdownMenuItem(value: 'partial', child: Text('部分有效：还需要调整')),
                  DropdownMenuItem(value: 'invalid', child: Text('无效：策略需要重做')),
                  DropdownMenuItem(value: 'adjust', child: Text('需要调整下一步行动')),
                  DropdownMenuItem(value: 'exit', child: Text('需要退出/停止投入')),
                  DropdownMenuItem(value: 'need_info', child: Text('需要补充现实信息')),
                ],
                onChanged: (v) => setDialogState(() => status = v ?? 'verified'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '现实反馈',
                  hintText: '例如：边界表达后关系没有崩；暂停三天后发现损失可控；小行动确实缩小了价值—行为距离。',
                  border: OutlineInputBorder(),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存验证')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _dao.completeVerificationTask(taskId: task.taskId, resultNote: ctrl.text, status: status);
    ctrl.dispose();
    await _load();
    _toast('已记录专项验证结果，并反哺价值地图/报告趋势。');
  }

  Widget _specialHistorySection() {
    final keys = _specialSceneLabels.keys.toSet();
    final rows = _sessions.where((s) => keys.contains(s.sceneType)).toList(growable: false);
    if (rows.isEmpty) return _emptyCard('专项历史', '完成一次专项分析后，这里会按类型保留记录，可继续设为当前行动或查看四路径/责任边界。');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('专项历史', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      ...rows.take(12).map((s) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.history_outlined, color: Color(0xFF4F46E5)),
              title: Text('${_specialSceneLabels[s.sceneType] ?? s.sceneType} · ${s.status}', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(s.result.coreConflict, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() {
                _specialSceneKey = s.sceneType;
                _specialPlan = s.result;
                _applyPlan(s.result, sourceType: s.sourceType, sourceId: s.sourceId);
              }),
            ),
          )),
    ]);
  }

  Widget _buildRunnerTab() {
    final plan = _plan;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (plan == null)
          _emptyCard('还没有 1 美元行动', '请先在“失调雷达”中生成一个行动。')
        else ...[
          _infoCard('当前动作', plan.oneDollarAction, Icons.bolt_outlined, emphasize: true),
          _infoCard('行动前承诺', plan.preCommitment, Icons.verified_user_outlined),
          if (_activeSourceType.isNotEmpty || _activeRewardSource.isNotEmpty)
            _infoCard('当前行动链路', [
              if (_activeSourceType.isNotEmpty) '来源：$_activeSourceType ${_activeSourceId.isNotEmpty ? '· $_activeSourceId' : ''}',
              if (_activeRewardSource.isNotEmpty) '外部奖励上下文：$_activeRewardSource',
            ].join('\n'), Icons.hub_outlined),
          TextField(
            controller: _hesitationCtrl,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '我现在的犹豫/阻力（可选）', hintText: '例如：我觉得做一点没意义、怕开始后坚持不了', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: _preActionBusy ? null : _buildPreActionGuidance, icon: const Icon(Icons.support_agent_outlined), label: Text(_preActionBusy ? '生成中...' : '生成行动前抗犹豫引导')),
          if (_preActionGuidance.isNotEmpty) ...[
            const SizedBox(height: 10),
            _readOnlyBlock(_preActionGuidance),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(label: const Text('30秒'), selected: _timerInitialSeconds == 30, onSelected: (_) => _setTimerDuration(30)),
            ChoiceChip(label: const Text('3分钟'), selected: _timerInitialSeconds == 180, onSelected: (_) => _setTimerDuration(180)),
            ChoiceChip(label: const Text('5分钟'), selected: _timerInitialSeconds == 300, onSelected: (_) => _setTimerDuration(300)),
            ChoiceChip(label: const Text('10分钟'), selected: _timerInitialSeconds == 600, onSelected: (_) => _setTimerDuration(600)),
          ]),
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF4F46E5), width: 4),
                color: const Color(0xFFF8FAFC),
              ),
              child: Center(
                child: Text(_timeText(_secondsLeft), style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B))),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(plan.inActionReminder, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: FilledButton.icon(onPressed: _toggleTimer, icon: Icon(_timer == null ? Icons.play_arrow : Icons.pause), label: Text(_timer == null ? '开始计时' : '暂停'))),
              const SizedBox(width: 10),
              OutlinedButton.icon(onPressed: _resetTimer, icon: const Icon(Icons.restart_alt), label: const Text('重置')),
            ],
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(labelText: '证据分类', border: OutlineInputBorder()),
            items: _categoryLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _selectedCategory = _normalizeCategory(v ?? 'start')),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _actualMinutesCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '实际投入分钟（可选，留空按计时器；未计时默认1分钟）', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: Text('主观难度：$_difficultyScore/5')), const Text('越难越需要降级')]),
          Slider(value: _difficultyScore.toDouble(), min: 0, max: 5, divisions: 5, label: '$_difficultyScore', onChanged: (v) => setState(() => _difficultyScore = v.round())),
          TextField(
            controller: _doneCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '我实际完成了什么', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reflectionCtrl,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: '行动体验 / 阻力 / 看到的证据', hintText: '例如：虽然只做了3分钟，但我打开了书，并写下了一句话。', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          if (_hasTodoWriteBackSource) ...[
            _todoWriteBackOptionsCard(),
            const SizedBox(height: 8),
          ],
          if (_canCreateTodoStepFromCurrentPlan) ...[
            OutlinedButton.icon(
              onPressed: _busy ? null : _createTodoStepFromCurrentPlan,
              icon: const Icon(Icons.playlist_add_outlined),
              label: const Text('把当前 1 美元行动写入 Todo 行动'),
            ),
            const SizedBox(height: 8),
          ],
          if (plan.informationAvoidanceBranches.hasContent || _selectedCategory == 'information') ...[
            _informationContactResultCard(plan),
            const SizedBox(height: 8),
          ],
          _dissonanceTemperatureInputCard(),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _busy ? null : _saveEvidence, icon: const Icon(Icons.library_add_check_outlined), label: Text(_busy ? '保存中...' : '写入身份证据账本')),
          const SizedBox(height: 12),
          _dailyConsistencyReviewCard(),
        ],
      ],
    );
  }



  Widget _dailyConsistencyReviewCard() {
    return Card(
      color: const Color(0xFFFFFBEB),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.today_outlined, color: Color(0xFFB45309)), SizedBox(width: 8), Expanded(child: Text('每日一致性复盘', style: TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 6),
          const Text('每天不只问“做完了吗”，还要问：今天行为和价值哪里靠近、哪里断裂、我用了什么解释、明天用哪个最小行动回来。', style: TextStyle(height: 1.45, color: Color(0xFF78350F))),
          const SizedBox(height: 10),
          TextField(controller: _dailyClosestCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '今天最接近价值的行动', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _dailyDissonanceCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '今天最明显的失调', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _dailyRationalizationCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '今天使用的解释/合理化', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _dailyGrowthCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '更成长性的解释', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _dailyRepairCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '今天的修复/回来行动', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _dailyTomorrowCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '明天一个最小一致性行动', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: _busy ? null : _generateDailyReviewDraft, icon: const Icon(Icons.auto_awesome_outlined), label: const Text('AI生成草稿')),
            FilledButton.icon(onPressed: _saveDailyConsistencyReview, icon: const Icon(Icons.save_outlined), label: const Text('保存/覆盖今日复盘')),
          ]),
          if (_dailyReviews.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('最近复盘', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            ..._dailyReviews.take(3).map((r) => Text('• ${r.dateLabel}：${r.closestValueAction.isEmpty ? r.mainDissonance : r.closestValueAction}${r.tomorrowAction.isEmpty ? '' : '｜明天：${r.tomorrowAction}'}', style: const TextStyle(height: 1.35))),
          ],
        ]),
      ),
    );
  }

  Widget _dissonanceTemperatureInputCard() {
    Widget sliderLine({required String label, required int value, required ValueChanged<int> onChanged}) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))), Text('$value/10', style: const TextStyle(color: Color(0xFF6B7280)))]),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          label: '$value',
          onChanged: (v) => setState(() => onChanged(v.round())),
        ),
      ]);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.thermostat_outlined, color: Color(0xFFEA580C)), SizedBox(width: 8), Expanded(child: Text('失调温度计：行动前后复盘', style: TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 6),
          const Text('可以先单独记录“行动前温度”，完成后保存证据时再记录行动后温度。系统会比较前后变化，判断这次是行动型修复还是只是解释型缓解。', style: TextStyle(height: 1.45, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          sliderLine(label: '行动前不适', value: _beforeDiscomfortScore, onChanged: (v) => _beforeDiscomfortScore = v),
          sliderLine(label: '行动前内疚', value: _beforeGuiltScore, onChanged: (v) => _beforeGuiltScore = v),
          sliderLine(label: '行动前焦虑', value: _beforeAnxietyScore, onChanged: (v) => _beforeAnxietyScore = v),
          sliderLine(label: '行动前羞耻', value: _beforeShameScore, onChanged: (v) => _beforeShameScore = v),
          sliderLine(label: '行动前防御感', value: _beforeDefensivenessScore, onChanged: (v) => _beforeDefensivenessScore = v),
          sliderLine(label: '行动前逃避冲动', value: _beforeAvoidanceScore, onChanged: (v) => _beforeAvoidanceScore = v),
          sliderLine(label: '行动前行动意愿', value: _beforeActionWillingnessScore, onChanged: (v) => _beforeActionWillingnessScore = v),
          OutlinedButton.icon(
            onPressed: _preTemperatureLogged ? null : _recordPreActionTemperature,
            icon: const Icon(Icons.thermostat_auto_outlined),
            label: Text(_preTemperatureLogged ? '已记录行动前温度' : '先记录行动前温度'),
          ),
          const Divider(height: 18),
          sliderLine(label: '行动后不适', value: _afterDiscomfortScore, onChanged: (v) => _afterDiscomfortScore = v),
          sliderLine(label: '行动后内疚', value: _afterGuiltScore, onChanged: (v) => _afterGuiltScore = v),
          sliderLine(label: '行动后焦虑', value: _afterAnxietyScore, onChanged: (v) => _afterAnxietyScore = v),
          sliderLine(label: '行动后羞耻', value: _afterShameScore, onChanged: (v) => _afterShameScore = v),
          sliderLine(label: '行动后防御感', value: _afterDefensivenessScore, onChanged: (v) => _afterDefensivenessScore = v),
          sliderLine(label: '行动后逃避冲动', value: _afterAvoidanceScore, onChanged: (v) => _afterAvoidanceScore = v),
          sliderLine(label: '行动后清醒感', value: _afterClarityScore, onChanged: (v) => _afterClarityScore = v),
          sliderLine(label: '行动后责任感', value: _afterResponsibilityScore, onChanged: (v) => _afterResponsibilityScore = v),
          sliderLine(label: '行动后行动意愿', value: _afterActionWillingnessScore, onChanged: (v) => _afterActionWillingnessScore = v),
        ]),
      ),
    );
  }

  Widget _todoWriteBackOptionsCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFF0FDF4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.sync_alt_outlined, color: Color(0xFF047857)), SizedBox(width: 8), Text('Todo / 问题树双向回写', style: TextStyle(fontWeight: FontWeight.w900))]),
          const SizedBox(height: 4),
          Text('来源：${_activeSourceType.isNotEmpty ? _activeSourceType : widget.sourceType} · ${_activeSourceId.isNotEmpty ? _activeSourceId : widget.sourceId}', style: const TextStyle(fontSize: 12, color: Color(0xFF047857))),
          CheckboxListTile(
            value: _writeBackToTodo,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _writeBackToTodo = v ?? true),
            title: Text(_activeSourceType == 'todo_problem_node' ? '保存证据后，写回问题树节点努力记录' : '保存证据后，写回 Todo 目标努力账本和复盘'),
          ),
          CheckboxListTile(
            value: _markTodoCompleted,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _markTodoCompleted = v ?? false),
            title: const Text('同时标记对应行动/问题节点完成'),
            subtitle: const Text('建议只有在确实完成验收标准时再勾选。'),
          ),
          if (_todoWriteBackStatus.isNotEmpty) Text(_todoWriteBackStatus, style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }


  Widget _informationContactResultCard(CcPlanResult plan) {
    final branches = plan.informationAvoidanceBranches;
    String branchText() {
      switch (_infoResultType) {
        case 'better':
          return branches.betterThanExpected.isEmpty ? '结果好于预期：保留事实证据，不继续灾难化。' : branches.betterThanExpected;
        case 'worse':
          return branches.worseThanExpected.isEmpty ? '结果确实不好：只处理一个最小修复动作，不把结果等同于整个人失败。' : branches.worseThanExpected;
        case 'ambiguous':
        default:
          return branches.ambiguous.isEmpty ? '结果仍然模糊：补充一个低成本信息源，不用马上下结论。' : branches.ambiguous;
      }
    }

    Widget chip(String value, String label) => ChoiceChip(
          label: Text(label),
          selected: _infoResultType == value,
          onSelected: (_) => setState(() => _infoResultType = value),
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFF0FDF4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.travel_explore_outlined, color: Color(0xFF15803D)), SizedBox(width: 8), Expanded(child: Text('信息回避结果记录', style: TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 6),
          Text(
            branches.avoidedInformation.isEmpty ? '记录这次现实信息接触的真实结果：不是继续想象，而是把事实带回系统。' : '回避的信息：${branches.avoidedInformation}',
            style: const TextStyle(height: 1.4, color: Color(0xFF166534)),
          ),
          if (branches.fearedResult.isNotEmpty) Text('原来害怕：${branches.fearedResult}', style: const TextStyle(height: 1.4, color: Color(0xFF166534))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            chip('better', '好于预期'),
            chip('worse', '确实不好'),
            chip('ambiguous', '仍然模糊'),
          ]),
          const SizedBox(height: 8),
          _infoNote(branchText()),
          const SizedBox(height: 8),
          TextField(
            controller: _infoActualResultCtrl,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '我实际看到的结果', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _infoCatastropheCtrl,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '它是否验证了我原来的灾难化想象？', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _infoRepairActionCtrl,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '下一步最小修复/补充信息行动',
              hintText: branches.nextInformationAction.isEmpty ? null : branches.nextInformationAction,
              border: const OutlineInputBorder(),
            ),
          ),
        ]),
      ),
    );
  }

  String _infoResultTypeLabel(String type) {
    switch (type.trim()) {
      case 'better':
        return '好于预期';
      case 'worse':
        return '确实不好';
      case 'ambiguous':
      default:
        return '仍然模糊';
    }
  }

  Widget _infoNote(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE))),
      child: Text(text, style: const TextStyle(height: 1.4, color: Color(0xFF1E3A8A))),
    );
  }

  List<CcEvidenceRecord> _advancedFilteredEvidence(List<CcEvidenceRecord> records) {
    if (_v18TypeFilter.isEmpty && _v18IntensityFilter.isEmpty && _v18TemperatureFilter.isEmpty && _v18VerificationFilter.isEmpty && _v18SpecialFilter.isEmpty) {
      return records;
    }
    final verificationBySession = <String, String>{
      for (final task in _verificationTasks) task.sessionId: task.status,
    };
    return records.where((e) {
      final details = _v18DetailsBySessionId[e.sessionId];
      if (_v18TypeFilter.isNotEmpty) {
        final hasType = details != null && details.dissonanceTypes.any((t) => t.contains(_v18TypeFilter) || _v18TypeFilter.contains(t));
        if (!hasType) return false;
      }
      if (_v18IntensityFilter.isNotEmpty) {
        final level = details?.intensityLevel ?? '';
        if (!level.contains(_v18IntensityFilter)) return false;
      }
      if (_v18TemperatureFilter.isNotEmpty) {
        final logs = _temperatureByEvidenceId[e.evidenceId] ?? const <CcDissonanceTemperatureLog>[];
        final before = logs.where((l) => l.phase == 'before').toList();
        final after = logs.where((l) => l.phase == 'after').toList();
        final hasPair = before.isNotEmpty && after.isNotEmpty;
        final discomfortDrop = hasPair ? before.last.discomfortScore - after.last.discomfortScore : 0;
        final avoidanceDrop = hasPair ? before.last.avoidanceUrgeScore - after.last.avoidanceUrgeScore : 0;
        if (_v18TemperatureFilter == 'cooling' && !(hasPair && (discomfortDrop > 0 || avoidanceDrop > 0))) return false;
        if (_v18TemperatureFilter == 'heating' && !(hasPair && (discomfortDrop < 0 || avoidanceDrop < 0))) return false;
        if (_v18TemperatureFilter == 'no_pair' && hasPair) return false;
      }
      if (_v18VerificationFilter.isNotEmpty) {
        final status = verificationBySession[e.sessionId] ?? '';
        if (_v18VerificationFilter == 'none') {
          if (status.isNotEmpty) return false;
        } else if (status != _v18VerificationFilter) {
          return false;
        }
      }
      if (_v18SpecialFilter.isNotEmpty) {
        final hasInfo = _informationContactByEvidenceId.containsKey(e.evidenceId) || e.evidenceCategory == 'information';
        final hasIdentity = _identityTransitionByEvidenceId.containsKey(e.evidenceId) || e.evidenceCategory == 'identity';
        final hasIntegrity = details != null && (details.selfAcknowledge.isNotEmpty || details.selfNotEqual.isNotEmpty || details.selfStillValue.isNotEmpty || details.selfNextProof.isNotEmpty);
        final hasTempReview = _temperatureReviewByEvidenceId.containsKey(e.evidenceId);
        if (_v18SpecialFilter == 'information' && !hasInfo) return false;
        if (_v18SpecialFilter == 'identity' && !hasIdentity) return false;
        if (_v18SpecialFilter == 'integrity' && !hasIntegrity) return false;
        if (_v18SpecialFilter == 'temp_review' && !hasTempReview) return false;
        if (_v18SpecialFilter == 'missing_temp_review' && hasTempReview) return false;
      }
      return true;
    }).toList(growable: false);
  }

  Widget _evidenceAdvancedFilterPanel() {
    final typeOptions = _v18DetailsBySessionId.values
        .expand((d) => d.dissonanceTypes)
        .where((t) => t.trim().isNotEmpty)
        .toSet()
        .take(8)
        .toList(growable: false);
    final hasAnyAdvanced = _v18TypeFilter.isNotEmpty || _v18IntensityFilter.isNotEmpty || _v18TemperatureFilter.isNotEmpty || _v18VerificationFilter.isNotEmpty || _v18SpecialFilter.isNotEmpty;

    Widget section(String title, List<Widget> chips) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF4B5563))),
          const SizedBox(height: 4),
          Wrap(spacing: 8, runSpacing: 6, children: chips),
          const SizedBox(height: 8),
        ]);

    ChoiceChip chip({required String label, required bool selected, required VoidCallback onTap}) {
      return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => setState(onTap));
    }

    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.filter_alt_outlined, size: 18, color: Color(0xFF475569)),
            const SizedBox(width: 6),
            const Expanded(child: Text('V18 高级筛选', style: TextStyle(fontWeight: FontWeight.w900))),
            if (hasAnyAdvanced)
              TextButton(
                onPressed: () => setState(() {
                  _v18TypeFilter = '';
                  _v18IntensityFilter = '';
                  _v18TemperatureFilter = '';
                  _v18VerificationFilter = '';
                  _v18SpecialFilter = '';
                }),
                child: const Text('清空'),
              ),
          ]),
          const SizedBox(height: 8),
          if (typeOptions.isNotEmpty)
            section('失调类型', [
              chip(label: '全部', selected: _v18TypeFilter.isEmpty, onTap: () => _v18TypeFilter = ''),
              ...typeOptions.map((t) => chip(label: t, selected: _v18TypeFilter == t, onTap: () => _v18TypeFilter = t)),
            ]),
          section('强度等级', [
            chip(label: '全部', selected: _v18IntensityFilter.isEmpty, onTap: () => _v18IntensityFilter = ''),
            ...['低', '中', '高', '深层身份型'].map((v) => chip(label: v, selected: _v18IntensityFilter == v, onTap: () => _v18IntensityFilter = v)),
          ]),
          section('温度变化', [
            chip(label: '全部', selected: _v18TemperatureFilter.isEmpty, onTap: () => _v18TemperatureFilter = ''),
            chip(label: '已降温', selected: _v18TemperatureFilter == 'cooling', onTap: () => _v18TemperatureFilter = 'cooling'),
            chip(label: '升温/更难', selected: _v18TemperatureFilter == 'heating', onTap: () => _v18TemperatureFilter = 'heating'),
            chip(label: '缺少前后配对', selected: _v18TemperatureFilter == 'no_pair', onTap: () => _v18TemperatureFilter = 'no_pair'),
          ]),
          section('验证状态', [
            chip(label: '全部', selected: _v18VerificationFilter.isEmpty, onTap: () => _v18VerificationFilter = ''),
            chip(label: '无验证任务', selected: _v18VerificationFilter == 'none', onTap: () => _v18VerificationFilter = 'none'),
            chip(label: '待验证', selected: _v18VerificationFilter == 'open', onTap: () => _v18VerificationFilter = 'open'),
            chip(label: '有效', selected: _v18VerificationFilter == 'verified', onTap: () => _v18VerificationFilter = 'verified'),
            chip(label: '部分有效', selected: _v18VerificationFilter == 'partial', onTap: () => _v18VerificationFilter = 'partial'),
            chip(label: '无效', selected: _v18VerificationFilter == 'invalid', onTap: () => _v18VerificationFilter = 'invalid'),
            chip(label: '需调整', selected: _v18VerificationFilter == 'adjust', onTap: () => _v18VerificationFilter = 'adjust'),
          ]),
          section('专项证据', [
            chip(label: '全部', selected: _v18SpecialFilter.isEmpty, onTap: () => _v18SpecialFilter = ''),
            chip(label: '信息回避', selected: _v18SpecialFilter == 'information', onTap: () => _v18SpecialFilter = 'information'),
            chip(label: '身份转换', selected: _v18SpecialFilter == 'identity', onTap: () => _v18SpecialFilter = 'identity'),
            chip(label: '自我完整', selected: _v18SpecialFilter == 'integrity', onTap: () => _v18SpecialFilter = 'integrity'),
            chip(label: '有温度复盘', selected: _v18SpecialFilter == 'temp_review', onTap: () => _v18SpecialFilter = 'temp_review'),
            chip(label: '缺温度复盘', selected: _v18SpecialFilter == 'missing_temp_review', onTap: () => _v18SpecialFilter = 'missing_temp_review'),
          ]),
        ]),
      ),
    );
  }

  Widget _buildEvidenceTab() {
    final visibleEvidence = _advancedFilteredEvidence(_evidence);
    final totalMinutes = visibleEvidence.fold<int>(0, (sum, e) => sum + e.effortMinutes);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _emptyCard('身份证据账本', '当前筛选下共有 ${visibleEvidence.length} 条证据，累计约 $totalMinutes 分钟。系统更重视真实证据、回来次数和价值靠近，而不是完美连续打卡。'),
          _evidenceDashboard(),
          _effectivePatternsCard(),
          _evidenceTrendCard(),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(label: const Text('全部'), selected: _evidenceFilter == null, onSelected: (_) async { setState(() => _evidenceFilter = null); await _load(); }),
            ..._categoryLabels.entries.map((e) => ChoiceChip(label: Text(e.value), selected: _evidenceFilter == e.key, onSelected: (_) async { setState(() => _evidenceFilter = e.key); await _load(); })),
          ]),
          const SizedBox(height: 8),
          _evidenceAdvancedFilterPanel(),
          const SizedBox(height: 12),
          if (visibleEvidence.isEmpty)
            _emptyCard('暂无行动证据', '完成一个 1 美元行动后，这里会记录“我做到了什么、它打破了什么旧解释、它支持我成为什么样的人”。')
          else
            ...visibleEvidence.map((e) => _evidenceCard(e)),
        ],
      ),
    );
  }


  String _temperatureDeltaSummary(String evidenceId) {
    final logs = _temperatureByEvidenceId[evidenceId] ?? const <CcDissonanceTemperatureLog>[];
    final before = logs.where((l) => l.phase == 'before').toList();
    final after = logs.where((l) => l.phase == 'after').toList();
    if (before.isEmpty && after.isEmpty) return '';
    if (before.isEmpty || after.isEmpty) return '温度记录未成对：${before.length}条行动前 / ${after.length}条行动后';
    final b = before.first;
    final a = after.first;
    final discomfortDrop = b.discomfortScore - a.discomfortScore;
    final avoidanceDrop = b.avoidanceUrgeScore - a.avoidanceUrgeScore;
    final clarityRise = a.clarityScore - b.clarityScore;
    final willingRise = a.actionWillingnessScore - b.actionWillingnessScore;
    final mode = discomfortDrop > 0 || avoidanceDrop > 0 || clarityRise > 0 || willingRise > 0 ? '行动型修复' : '仍需继续验证';
    return '不适 ${b.discomfortScore}→${a.discomfortScore}（${discomfortDrop >= 0 ? '下降' : '上升'}${discomfortDrop.abs()}）｜逃避 ${b.avoidanceUrgeScore}→${a.avoidanceUrgeScore}｜清醒 ${b.clarityScore}→${a.clarityScore}｜意愿 ${b.actionWillingnessScore}→${a.actionWillingnessScore}｜$mode';
  }

  Widget _evidenceV18Card(CcEvidenceRecord e) {
    final details = _v18DetailsBySessionId[e.sessionId];
    final temp = _temperatureDeltaSummary(e.evidenceId);
    final tempReview = _temperatureReviewByEvidenceId[e.evidenceId];
    final infoResult = _informationContactByEvidenceId[e.evidenceId];
    final identityRecord = _identityTransitionByEvidenceId[e.evidenceId];
    if (details == null && temp.isEmpty && tempReview == null && infoResult == null && identityRecord == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDDD6FE))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.psychology_alt_outlined, size: 18, color: Color(0xFF7C3AED)), SizedBox(width: 6), Expanded(child: Text('V18 失调修复证据', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF5B21B6))))]),
        const SizedBox(height: 6),
        if (details != null && details.dissonanceTypes.isNotEmpty) _miniLine('修复的失调', details.dissonanceTypes.join('、')),
        if (details != null && (details.intensityScore > 0 || details.intensityLevel.isNotEmpty)) _miniLine('失调强度', '${details.intensityLevel.isEmpty ? '未分级' : details.intensityLevel} · ${details.intensityScore}/24${details.intensitySources.isEmpty ? '' : ' · ${details.intensitySources}'}'),
        if (details != null && details.defensiveExplanation.isNotEmpty) _miniLine('松动的防御解释', details.defensiveExplanation),
        if (details != null && details.growthExplanation.isNotEmpty) _miniLine('成长性解释', details.growthExplanation),
        if (details != null && (details.selfAcknowledge.isNotEmpty || details.selfNotEqual.isNotEmpty || details.selfStillValue.isNotEmpty || details.selfNextProof.isNotEmpty)) ...[
          const SizedBox(height: 4),
          const Text('自我完整证据', style: TextStyle(fontWeight: FontWeight.w800)),
          if (details.selfAcknowledge.isNotEmpty) _miniLine('我承认', details.selfAcknowledge),
          if (details.selfNotEqual.isNotEmpty) _miniLine('我不等于', details.selfNotEqual),
          if (details.selfStillValue.isNotEmpty) _miniLine('我仍然重视', details.selfStillValue),
          if (details.selfNextProof.isNotEmpty) _miniLine('下一步证明', details.selfNextProof),
        ],
        if (temp.isNotEmpty) _miniLine('温度变化', temp),
        if (tempReview != null && tempReview.reviewText.trim().isNotEmpty) _miniLine('AI 温度复盘', tempReview.reviewText),
        if (infoResult != null) ...[
          const SizedBox(height: 4),
          const Text('信息接触结果', style: TextStyle(fontWeight: FontWeight.w800)),
          if (infoResult.avoidedInformation.isNotEmpty) _miniLine('原本回避', infoResult.avoidedInformation),
          if (infoResult.fearedResult.isNotEmpty) _miniLine('原本害怕', infoResult.fearedResult),
          if (infoResult.actualResult.isNotEmpty) _miniLine('真实结果', infoResult.actualResult),
          if (infoResult.resultType.isNotEmpty) _miniLine('结果类型', _infoResultTypeLabel(infoResult.resultType)),
          if (infoResult.catastrophizingCheck.isNotEmpty) _miniLine('灾难化校验', infoResult.catastrophizingCheck),
          if (infoResult.repairAction.isNotEmpty) _miniLine('下一步修复', infoResult.repairAction),
        ],
        if (identityRecord != null) ...[
          const SizedBox(height: 4),
          const Text('身份转换证据', style: TextStyle(fontWeight: FontWeight.w800)),
          if (identityRecord.oldIdentity.isNotEmpty) _miniLine('旧身份', identityRecord.oldIdentity),
          if (identityRecord.newIdentity.isNotEmpty) _miniLine('新身份', identityRecord.newIdentity),
          if (identityRecord.oldProtection.isNotEmpty) _miniLine('旧身份保护', identityRecord.oldProtection),
          if (identityRecord.fearOfLoss.isNotEmpty) _miniLine('害怕失去', identityRecord.fearOfLoss),
          if (identityRecord.newIdentityAction.isNotEmpty) _miniLine('本次新身份行动', identityRecord.newIdentityAction),
          if (identityRecord.postActionIdentitySentence.isNotEmpty) _miniLine('行动后身份解释', identityRecord.postActionIdentitySentence),
          if (identityRecord.nextIdentityAction.isNotEmpty) _miniLine('下一个身份证据', identityRecord.nextIdentityAction),
        ],
      ]),
    );
  }

  Widget _evidenceCard(CcEvidenceRecord e) {
    final dt = DateTime.fromMillisecondsSinceEpoch(e.createdAtMs);
    final linkedValues = _linksByEvidenceId()[e.evidenceId] ?? const <CcEvidenceValueLink>[];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_outlined, color: Color(0xFF059669)),
                const SizedBox(width: 8),
                Expanded(child: Text(e.evidenceLabel.isEmpty ? '一条真实行动证据' : e.evidenceLabel, style: const TextStyle(fontWeight: FontWeight.w900))),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _pill(_categoryLabels[e.evidenceCategory] ?? '启动证据'),
              _pill('${e.effortMinutes} 分钟'),
              _pill('难度 ${e.difficultyScore}/5'),
              if (e.sourceType.isNotEmpty) _pill('来源 ${e.sourceType}'),
            ]),
            if (linkedValues.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: linkedValues.map((link) => _pill('价值强关联 ${link.valueLabel}')).toList()),
            ],
            const SizedBox(height: 8),
            Text('完成：${e.completedAction}', style: const TextStyle(height: 1.4)),
            if (e.valueLink.isNotEmpty) Text('价值：${e.valueLink}', style: const TextStyle(color: Color(0xFF4B5563))),
            if (e.identityDirection.isNotEmpty) Text('身份：${e.identityDirection}', style: const TextStyle(color: Color(0xFF4B5563))),
            if (e.oldStory.isNotEmpty) Text('打破旧解释：${e.oldStory}', style: const TextStyle(color: Color(0xFF92400E))),
            if (e.newStory.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(e.newStory, style: const TextStyle(height: 1.45)),
            ],
            _evidenceV18Card(e),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: () => _markEffectivePattern(e),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('标记有效模式'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openEvidenceTrace(e),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('查看链路'),
              ),
            ]),
            const SizedBox(height: 8),
            Text('${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }


  Widget _evidenceDashboard() {
    if (_evidence.isEmpty) return const SizedBox.shrink();
    final totalMinutes = _evidence.fold<int>(0, (sum, e) => sum + e.effortMinutes);
    final recovery = _evidence.where((e) => e.evidenceCategory == 'recovery').length;
    final discomfort = _evidence.where((e) => e.evidenceCategory == 'discomfort').length;
    final sourceLinked = _evidence.where((e) => e.sourceType.trim().isNotEmpty).length;
    final oldStoryCounts = <String, int>{};
    for (final e in _evidence) {
      final key = e.oldStory.trim();
      if (key.isNotEmpty) oldStoryCounts[key] = (oldStoryCounts[key] ?? 0) + 1;
    }
    final oldStories = oldStoryCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topOldStory = oldStories.isEmpty ? '暂无；下一次记录“它打破了什么旧解释”。' : '${oldStories.first.key}（${oldStories.first.value}次）';
    final valueCounts = _valueCountsForEvidence(_evidence);
    final values = valueCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topValues = values.take(3).map((e) => '${e.key}×${e.value}').join('、');
    final linkedValueCount = _valueLinks.where((link) => _evidence.any((e) => e.evidenceId == link.evidenceId)).length;
    return Card(
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.insights_outlined, color: Color(0xFF4F46E5)), SizedBox(width: 8), Text('身份成长仪表盘', style: TextStyle(fontWeight: FontWeight.w900))]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill('证据 ${_evidence.length} 条'),
            _pill('累计 $totalMinutes 分钟'),
            _pill('回来 $recovery 次'),
            _pill('面对不适 $discomfort 次'),
            _pill('来源链路 $sourceLinked 条'),
            _pill('价值强关联 $linkedValueCount 条'),
          ]),
          const SizedBox(height: 10),
          _miniLine('最常被打破的旧解释', topOldStory),
          _miniLine('最常连接的价值', topValues.isEmpty ? '暂无明确价值连接。' : topValues),
        ]),
      ),
    );
  }

  Widget _evidenceTrendCard() {
    if (_allEvidence.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final dayCounts = <String, int>{};
    final sourceCounts = <String, int>{};
    for (var i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      dayCounts['${_two(d.month)}-${_two(d.day)}'] = 0;
    }
    for (final e in _allEvidence) {
      final dt = DateTime.fromMillisecondsSinceEpoch(e.createdAtMs);
      if (now.difference(dt).inDays <= 6) {
        final key = '${_two(dt.month)}-${_two(dt.day)}';
        dayCounts[key] = (dayCounts[key] ?? 0) + 1;
      }
      final src = e.sourceType.trim().isEmpty ? '独立模块' : e.sourceType.trim();
      sourceCounts[src] = (sourceCounts[src] ?? 0) + 1;
    }
    final maxDay = dayCounts.values.fold<int>(1, (m, v) => v > m ? v : m);
    final valueCounts = _valueCountsForEvidence(_allEvidence);
    final values = valueCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final sources = sourceCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      margin: const EdgeInsets.only(top: 10, bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.show_chart_outlined, color: Color(0xFF4F46E5)), SizedBox(width: 8), Text('最近趋势与系统融合', style: TextStyle(fontWeight: FontWeight.w900))]),
          const SizedBox(height: 10),
          ...dayCounts.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  SizedBox(width: 48, child: Text(e.key, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                  Expanded(child: LinearProgressIndicator(value: e.value / maxDay)),
                  const SizedBox(width: 8),
                  Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              )),
          const SizedBox(height: 8),
          _miniLine('价值靠近 Top3', values.isEmpty ? '暂无明确价值。' : values.take(3).map((e) => '${e.key}×${e.value}').join('、')),
          _miniLine('来源转化', sources.take(3).map((e) => '${e.key}×${e.value}').join('、')),
        ]),
      ),
    );
  }

  Widget _valueEvidenceSummary(CcValueProfile value) {
    final label = value.valueLabel.trim();
    final identity = value.identityDirection.trim();
    if (label.isEmpty && identity.isEmpty) return const SizedBox.shrink();
    final rows = _evidenceForValue(value);
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text('证据沉淀：暂无。可以先把这个价值用于生成行动。', style: TextStyle(color: Color(0xFF6B7280))),
      );
    }
    final minutes = rows.fold<int>(0, (sum, e) => sum + e.effortMinutes);
    final latest = rows.first.completedAction;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 6, children: [_pill('关联证据 ${rows.length} 条'), _pill('累计 $minutes 分钟')]),
        const SizedBox(height: 6),
        Text('最近证据：$latest', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF4B5563))),
      ]),
    );
  }

  Widget _conversionDashboardCard() {
    final totalSessions = _sessions.length;
    final savedSessions = _sessions.where((s) => s.status == 'evidence_saved').length;
    final linkedEvidence = _allEvidence.where((e) => e.sessionId.trim().isNotEmpty).length;
    final todoEvidence = _allEvidence.where((e) => e.sourceType == 'todo_goal_step' || e.sourceType == 'todo_problem_node').length;
    final rate = totalSessions == 0 ? '暂无' : '${((savedSessions / totalSessions) * 100).round()}%';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.route_outlined, color: Color(0xFF4F46E5)), SizedBox(width: 8), Text('系统闭环转化', style: TextStyle(fontWeight: FontWeight.w900))]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill('最近方案 $totalSessions 个'),
            _pill('已成证据 $savedSessions 个'),
            _pill('转化率 $rate'),
            _pill('有 session 链路 $linkedEvidence 条'),
            _pill('Todo/问题树来源 $todoEvidence 条'),
          ]),
          const SizedBox(height: 8),
          const Text('目标不是让 AI 多生成方案，而是让方案真正进入行动、留下证据，再回到 Todo / 问题树 / 报告继续迭代。', style: TextStyle(color: Color(0xFF64748B), height: 1.4)),
        ]),
      ),
    );
  }

  Widget _sessionCard(CcSession session) {
    final dt = DateTime.fromMillisecondsSinceEpoch(session.updatedAtMs == 0 ? session.createdAtMs : session.updatedAtMs);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.account_tree_outlined, color: Color(0xFF4F46E5)),
            const SizedBox(width: 8),
            Expanded(child: Text('${session.sceneType} · ${session.status}', style: const TextStyle(fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 8),
          if (session.userGoal.isNotEmpty) Text('目标：${session.userGoal}', maxLines: 2, overflow: TextOverflow.ellipsis),
          Text('1美元行动：${session.result.oneDollarAction}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.35)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill('${dt.year}-${_two(dt.month)}-${_two(dt.day)}'),
            if (session.result.provider.isNotEmpty) _pill(session.result.provider),
            if (session.result.modelLabel.isNotEmpty) _pill(session.result.modelLabel),
            OutlinedButton.icon(onPressed: () => _activateSession(session), icon: const Icon(Icons.play_arrow), label: const Text('继续执行')),
          ]),
        ]),
      ),
    );
  }

  Widget _buildRewardTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _emptyCard('外部奖励降噪', '不是否定打卡、积分、监督和奖惩，而是防止它们过强，导致行动被解释成“我只是为了外部理由才做”。这里会把外部理由逐步转回价值、选择和身份。'),
        TextField(controller: _rewardCtrl, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: '我当前依赖的外部理由', hintText: '例如：不打卡就焦虑、只为了积分、没人监督就不做、必须重罚自己才动', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _rewardBusy ? null : _analyzeExternalReward, icon: const Icon(Icons.card_giftcard_outlined), label: Text(_rewardBusy ? '分析中...' : '分析奖励依赖并生成降噪行动')),
        const SizedBox(height: 12),
        if (_rewardPlan != null) _planCard(_rewardPlan!, rewardSource: _rewardCtrl.text.trim(), sourceType: _toolSourceType('external_reward_detox'), sourceId: _toolSourceId()),
      ],
    );
  }

  Widget _buildSelfCheckTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _emptyCard('自我欺骗与合理化校验', '认知失调既能帮助成长，也可能让人为了舒服而扭曲事实。这里不审判用户，而是区分：保护自己、承认困难、逃避责任、合理化不行动。'),
        TextField(controller: _selfExplanationCtrl, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: '我现在正在使用的解释', hintText: '例如：这件事本来就不重要；我只是状态不好；以后再说也没关系', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _factsCtrl, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: '相关事实 / 行为证据', hintText: '只写事实：我做了什么、没做什么、发生了什么', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _selfCheckBusy ? null : _runSelfDeceptionCheck, icon: const Icon(Icons.fact_check_outlined), label: Text(_selfCheckBusy ? '校验中...' : '进行诚实但不羞辱的校验')),
        const SizedBox(height: 12),
        if (_selfCheckPlan != null) _planCard(_selfCheckPlan!, sourceType: _toolSourceType('self_deception_check'), sourceId: _toolSourceId()),
      ],
    );
  }

  Widget _modernPatternProfileCard() {
    final data = _modernProfile;
    final sceneCounts = (data['sceneCounts'] is Map) ? Map<String, dynamic>.from(data['sceneCounts'] as Map) : <String, dynamic>{};
    final rationalizationCounts = (data['rationalizationCounts'] is Map) ? Map<String, dynamic>.from(data['rationalizationCounts'] as Map) : <String, dynamic>{};
    final standardCounts = (data['standardCounts'] is Map) ? Map<String, dynamic>.from(data['standardCounts'] as Map) : <String, dynamic>{};
    final triggerCounts = (data['triggerCounts'] is Map) ? Map<String, dynamic>.from(data['triggerCounts'] as Map) : <String, dynamic>{};
    final reductionModeCounts = (data['reductionModeCounts'] is Map) ? Map<String, dynamic>.from(data['reductionModeCounts'] as Map) : <String, dynamic>{};
    final verificationCounts = (data['verificationCounts'] is Map) ? Map<String, dynamic>.from(data['verificationCounts'] as Map) : <String, dynamic>{};
    final dissonanceTypeCounts = (data['dissonanceTypeCounts'] is Map) ? Map<String, dynamic>.from(data['dissonanceTypeCounts'] as Map) : <String, dynamic>{};
    final intensityLevelCounts = (data['intensityLevelCounts'] is Map) ? Map<String, dynamic>.from(data['intensityLevelCounts'] as Map) : <String, dynamic>{};
    final temperatureCounts = (data['temperatureCounts'] is Map) ? Map<String, dynamic>.from(data['temperatureCounts'] as Map) : <String, dynamic>{};
    final temperatureDelta = (data['temperatureDelta'] is Map) ? Map<String, dynamic>.from(data['temperatureDelta'] as Map) : <String, dynamic>{};
    final informationResultCounts = (data['informationResultCounts'] is Map) ? Map<String, dynamic>.from(data['informationResultCounts'] as Map) : <String, dynamic>{};
    final temperatureRepairModeCounts = (data['temperatureRepairModeCounts'] is Map) ? Map<String, dynamic>.from(data['temperatureRepairModeCounts'] as Map) : <String, dynamic>{};
    final topOldIdentityCounts = (data['topOldIdentityCounts'] is Map) ? Map<String, dynamic>.from(data['topOldIdentityCounts'] as Map) : <String, dynamic>{};
    final topNewIdentityCounts = (data['topNewIdentityCounts'] is Map) ? Map<String, dynamic>.from(data['topNewIdentityCounts'] as Map) : <String, dynamic>{};
    final last7 = (data['last7'] is Map) ? Map<String, dynamic>.from(data['last7'] as Map) : <String, dynamic>{};
    final last30 = (data['last30'] is Map) ? Map<String, dynamic>.from(data['last30'] as Map) : <String, dynamic>{};
    final sourcebookCoreValueCounts = (data['sourcebookCoreValueCounts'] is Map) ? Map<String, dynamic>.from(data['sourcebookCoreValueCounts'] as Map) : <String, dynamic>{};
    final sourcebookIdentityBeliefCounts = (data['sourcebookIdentityBeliefCounts'] is Map) ? Map<String, dynamic>.from(data['sourcebookIdentityBeliefCounts'] as Map) : <String, dynamic>{};
    final sourcebookPeripheralExplanationCounts = (data['sourcebookPeripheralExplanationCounts'] is Map) ? Map<String, dynamic>.from(data['sourcebookPeripheralExplanationCounts'] as Map) : <String, dynamic>{};
    final sourcebookChoiceCounts = (data['sourcebookChoiceCounts'] is Map) ? Map<String, dynamic>.from(data['sourcebookChoiceCounts'] as Map) : <String, dynamic>{};
    final sourcebookSelectedChoiceCounts = (data['sourcebookSelectedChoiceCounts'] is Map) ? Map<String, dynamic>.from(data['sourcebookSelectedChoiceCounts'] as Map) : <String, dynamic>{};
    final sourcebookContractStatusCounts = (data['sourcebookContractStatusCounts'] is Map) ? Map<String, dynamic>.from(data['sourcebookContractStatusCounts'] as Map) : <String, dynamic>{};
    final sourcebookCounterOldBeliefCounts = (data['sourcebookCounterOldBeliefCounts'] is Map) ? Map<String, dynamic>.from(data['sourcebookCounterOldBeliefCounts'] as Map) : <String, dynamic>{};
    final sourcebookInterpersonalImbalanceCounts = (data['sourcebookInterpersonalImbalanceCounts'] is Map) ? Map<String, dynamic>.from(data['sourcebookInterpersonalImbalanceCounts'] as Map) : <String, dynamic>{};
    final sourcebookProtectedSelfCounts = (data['sourcebookProtectedSelfCounts'] is Map) ? Map<String, dynamic>.from(data['sourcebookProtectedSelfCounts'] as Map) : <String, dynamic>{};
    final sourcebookDefensePatternCounts = (data['sourcebookDefensePatternCounts'] is Map) ? Map<String, dynamic>.from(data['sourcebookDefensePatternCounts'] as Map) : <String, dynamic>{};
    final sourcebookTriggerStatusCounts = (data['sourcebookTriggerStatusCounts'] is Map) ? Map<String, dynamic>.from(data['sourcebookTriggerStatusCounts'] as Map) : <String, dynamic>{};
    final resolutionMethodCounts = (data['resolutionMethodCounts'] is Map) ? Map<String, dynamic>.from(data['resolutionMethodCounts'] as Map) : <String, dynamic>{};
    final resolutionMethodStatusCounts = (data['resolutionMethodStatusCounts'] is Map) ? Map<String, dynamic>.from(data['resolutionMethodStatusCounts'] as Map) : <String, dynamic>{};
    final resolutionMethodDissonanceCounts = (data['resolutionMethodDissonanceCounts'] is Map) ? Map<String, dynamic>.from(data['resolutionMethodDissonanceCounts'] as Map) : <String, dynamic>{};
    final resolutionMethodSupportCounts = (data['resolutionMethodSupportCounts'] is Map) ? Map<String, dynamic>.from(data['resolutionMethodSupportCounts'] as Map) : <String, dynamic>{};
    final sessions = (data['sessions'] ?? 0).toString();
    final events = (data['events'] ?? 0).toString();
    final evidence = (data['evidence'] ?? 0).toString();
    final trueSelfLinks = (data['trueSelfLinks'] ?? 0).toString();
    final selfIntegrityCount = (data['selfIntegrityCount'] ?? 0).toString();
    final growthReframeCount = (data['growthReframeCount'] ?? 0).toString();
    final dailyReviewCount = (data['dailyReviewCount'] ?? 0).toString();
    final identityTransitionCount = (data['identityTransitionCount'] ?? 0).toString();
    final informationRepairActionCount = (data['informationRepairActionCount'] ?? 0).toString();
    final sourcebookCaseCount = (data['sourcebookCaseCount'] ?? 0).toString();
    final resolutionMethodTodoCount = (data['resolutionMethodTodoCount'] ?? 0).toString();
    final resolutionMethodEvidenceCount = (data['resolutionMethodEvidenceCount'] ?? 0).toString();
    final resolutionMethodContractCount = (data['resolutionMethodContractCount'] ?? 0).toString();
    final resolutionMethodAverageEffect = (data['resolutionMethodAverageEffect'] ?? 0).toString();
    final repairedSessions = (data['repairedSessions'] ?? 0).toString();
    final ratio = (data['actionRepairRatio'] ?? 0).toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFFF0F9FF),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.analytics_outlined, color: Color(0xFF0369A1)), SizedBox(width: 8), Expanded(child: Text('现代认知失调长期画像', style: TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill('方案 $sessions'),
            _pill('失调事件 $events'),
            _pill('行动证据 $evidence'),
            _pill('已行动方案 $repairedSessions'),
            _pill('行动修复率 $ratio%'),
            _pill('真实自我联动 $trueSelfLinks'),
            _pill('自我完整卡 $selfIntegrityCount'),
            _pill('成长性改写 $growthReframeCount'),
            _pill('每日复盘 $dailyReviewCount'),
            _pill('身份转换 $identityTransitionCount'),
            _pill('信息后续行动 $informationRepairActionCount'),
            _pill('源书案例 $sourcebookCaseCount'),
            _pill('方法转Todo $resolutionMethodTodoCount'),
            _pill('方法行动契约 $resolutionMethodContractCount'),
            _pill('方法产生证据 $resolutionMethodEvidenceCount'),
            _pill('方法平均效果 $resolutionMethodAverageEffect'),
          ]),
          const SizedBox(height: 10),
          if (last7.isNotEmpty) _mapPills('最近7天趋势', last7, maxItems: 5),
          if (last30.isNotEmpty) _mapPills('最近30天趋势', last30, maxItems: 5),
          if (sceneCounts.isNotEmpty) _mapPills('专项/场景分布', sceneCounts),
          if (reductionModeCounts.isNotEmpty) _mapPills('解释型/行动型降低失调', reductionModeCounts, maxItems: 8),
          if (verificationCounts.isNotEmpty) _mapPills('现实验证任务', verificationCounts, maxItems: 8),
          if (dissonanceTypeCounts.isNotEmpty) _mapPills('失调类型图谱', dissonanceTypeCounts, maxItems: 10),
          if (intensityLevelCounts.isNotEmpty) _mapPills('失调强度分布', intensityLevelCounts, maxItems: 8),
          if (temperatureCounts.isNotEmpty) _mapPills('失调温度计记录', temperatureCounts, maxItems: 8),
          if (temperatureDelta.isNotEmpty) _mapPills('失调温度前后变化', temperatureDelta, maxItems: 6),
          if (temperatureRepairModeCounts.isNotEmpty) _mapPills('温度复盘模式', temperatureRepairModeCounts, maxItems: 8),
          if (informationResultCounts.isNotEmpty) _mapPills('信息接触结果类型', informationResultCounts, maxItems: 8),
          if (topOldIdentityCounts.isNotEmpty) _mapPills('常见旧身份', topOldIdentityCounts, maxItems: 6),
          if (topNewIdentityCounts.isNotEmpty) _mapPills('常见新身份', topNewIdentityCounts, maxItems: 6),
          if (_selfIntegrityStats.isNotEmpty) _mapPills('自我完整长期画像', _selfIntegrityStats, maxItems: 8),
          if (sourcebookProtectedSelfCounts.isNotEmpty) _mapPills('高频被保护自我形象', sourcebookProtectedSelfCounts, maxItems: 8),
          if (sourcebookDefensePatternCounts.isNotEmpty) _mapPills('高频自我辩护/防御模式', sourcebookDefensePatternCounts, maxItems: 8),
          if (sourcebookCoreValueCounts.isNotEmpty) _mapPills('源书高频核心价值', sourcebookCoreValueCounts, maxItems: 8),
          if (sourcebookIdentityBeliefCounts.isNotEmpty) _mapPills('源书高频身份信念', sourcebookIdentityBeliefCounts, maxItems: 8),
          if (sourcebookPeripheralExplanationCounts.isNotEmpty) _mapPills('源书高频外围解释', sourcebookPeripheralExplanationCounts, maxItems: 8),
          if (sourcebookChoiceCounts.isNotEmpty) _mapPills('源书可选方向分布', sourcebookChoiceCounts, maxItems: 8),
          if (sourcebookSelectedChoiceCounts.isNotEmpty) _mapPills('源书已选择路径', sourcebookSelectedChoiceCounts, maxItems: 8),
          if (sourcebookContractStatusCounts.isNotEmpty) _mapPills('源书行动契约状态', sourcebookContractStatusCounts, maxItems: 8),
          if (sourcebookCounterOldBeliefCounts.isNotEmpty) _mapPills('反态度实验旧信念', sourcebookCounterOldBeliefCounts, maxItems: 8),
          if (sourcebookInterpersonalImbalanceCounts.isNotEmpty) _mapPills('人际失衡高频点', sourcebookInterpersonalImbalanceCounts, maxItems: 8),
          if (sourcebookTriggerStatusCounts.isNotEmpty) _mapPills('源书触发建议状态', sourcebookTriggerStatusCounts, maxItems: 8),
          if (resolutionMethodCounts.isNotEmpty) _mapPills('认知失调解决方法使用', resolutionMethodCounts, maxItems: 10),
          if (resolutionMethodStatusCounts.isNotEmpty) _mapPills('解决方法闭环状态', resolutionMethodStatusCounts, maxItems: 8),
          if (resolutionMethodDissonanceCounts.isNotEmpty) _mapPills('方法—失调类型分布', resolutionMethodDissonanceCounts, maxItems: 8),
          if (resolutionMethodSupportCounts.isNotEmpty) _mapPills('方法来源性质', resolutionMethodSupportCounts, maxItems: 8),
          if (rationalizationCounts.isNotEmpty) _mapPills('常见合理化', rationalizationCounts, maxItems: 8),
          if (standardCounts.isNotEmpty) _mapPills('自我标准触发', standardCounts),
          if (triggerCounts.isNotEmpty) _mapPills('责任—后果风险', triggerCounts),
          const SizedBox(height: 6),
          const Text('这里不是人格标签，而是帮助用户长期看见：自己更常通过解释缓解失调，还是通过行动修复失调；最常被哪种标准审判；最常用哪种合理化。', style: TextStyle(fontSize: 12, color: Color(0xFF075985), height: 1.45)),
        ]),
      ),
    );
  }

  Widget _mapPills(String title, Map<String, dynamic> map, {int maxItems = 6}) {
    final entries = map.entries.toList()
      ..sort((a, b) => (int.tryParse(b.value.toString()) ?? 0).compareTo(int.tryParse(a.value.toString()) ?? 0));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 5),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: entries.take(maxItems).map((e) => _pill('${e.key} ${e.value}')).toList(),
        ),
      ]),
    );
  }

  Future<void> _forceUpgradePrompts() async {
    await _promptConfig.ensureCurrentVersion(force: true);
    if (!mounted) return;
    _toast('已恢复/升级为 V25 认知失调解决引擎 Prompt，并备份旧自定义模板。');
  }

  Widget _buildReportTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('价值一致性报告', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('报告会根据最近行动证据，识别价值靠近、主要失调点、最有效的 1 美元行动与下周最小充分行动，并归档到本地报告历史。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _forceUpgradePrompts,
              icon: const Icon(Icons.upgrade_outlined),
              label: const Text('一键升级/恢复 V24 解法中心 Prompt 模板'),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(label: const Text('最近7天'), selected: _reportRange == 'last7', onSelected: (_) => setState(() => _reportRange = 'last7')),
            ChoiceChip(label: const Text('最近30天'), selected: _reportRange == 'last30', onSelected: (_) => setState(() => _reportRange = 'last30')),
            ChoiceChip(label: const Text('本月'), selected: _reportRange == 'thisMonth', onSelected: (_) => setState(() => _reportRange = 'thisMonth')),
            ChoiceChip(label: const Text('全部'), selected: _reportRange == 'all', onSelected: (_) => setState(() => _reportRange = 'all')),
          ]),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _reportBusy ? null : _buildReport,
            icon: _reportBusy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.summarize_outlined),
            label: Text(_reportBusy ? '生成中...' : '生成并保存${_reportRangeLabel()}报告'),
          ),
          const SizedBox(height: 16),
          if (_report.isNotEmpty) _readOnlyBlock(_report) else _emptyCard('还没有生成报告', '先完成几条行动证据，再生成会更准确。'),
          const SizedBox(height: 18),
          _modernPatternProfileCard(),
          _dailyReviewHistoryCard(),
          _informationContactHistoryCard(),
          _identityTransitionHistoryCard(),
          const SizedBox(height: 18),
          const Text('历史报告', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (_reports.isEmpty)
            _emptyCard('暂无历史报告', '生成报告后，这里会保留最近几次价值一致性报告。')
          else
            ..._reports.map(_reportCard),
          const SizedBox(height: 18),
          const Text('最近 AI 方案链路', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _conversionDashboardCard(),
          if (_sessions.isEmpty)
            _emptyCard('暂无 session 链路', '每次 AI 生成方案都会保留 session；行动证据会反向关联 session，方便复盘哪些方案真正进入执行。')
          else
            ..._sessions.map(_sessionCard),
        ],
      ),
    );
  }



  Widget _informationContactHistoryCard() {
    if (_informationContactResults.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFFF0FDF4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.travel_explore_outlined, color: Color(0xFF15803D)), SizedBox(width: 8), Expanded(child: Text('信息接触历史', style: TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 8),
          ..._informationContactResults.take(6).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ${_infoResultTypeLabel(r.resultType)}｜回避：${r.avoidedInformation.isEmpty ? '未填' : r.avoidedInformation}｜真实结果：${r.actualResult.isEmpty ? '未填' : r.actualResult}｜修复：${r.repairAction.isEmpty ? '未填' : r.repairAction}',
                      style: const TextStyle(height: 1.35),
                    ),
                    const SizedBox(height: 4),
                    Wrap(spacing: 8, children: [
                      TextButton.icon(onPressed: () => _editInformationContactResult(r), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('编辑')),
                      TextButton.icon(onPressed: () => _deleteInformationContactResult(r), icon: const Icon(Icons.delete_outline, size: 16), label: const Text('删除')),
                      if (r.repairAction.trim().isNotEmpty) TextButton.icon(onPressed: () => _quickCreateTodoActionFromText(r.repairAction, '信息接触后的最小修复行动', actionType: 'information_contact_action'), icon: const Icon(Icons.playlist_add_outlined, size: 16), label: const Text('写入Todo')),
                    ]),
                  ],
                ),
              )),
        ]),
      ),
    );
  }

  Widget _identityTransitionHistoryCard() {
    if (_identityTransitions.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFFF5F3FF),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.switch_account_outlined, color: Color(0xFF7C3AED)), SizedBox(width: 8), Expanded(child: Text('身份转换档案', style: TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 8),
          ..._identityTransitions.take(6).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• 旧身份：${r.oldIdentity.isEmpty ? '未填' : r.oldIdentity} → 新身份：${r.newIdentity.isEmpty ? '未填' : r.newIdentity}｜行动：${r.newIdentityAction.isEmpty ? '未填' : r.newIdentityAction}｜证据解释：${r.postActionIdentitySentence.isEmpty ? '未填' : r.postActionIdentitySentence}',
                      style: const TextStyle(height: 1.35),
                    ),
                    const SizedBox(height: 4),
                    Wrap(spacing: 8, children: [
                      TextButton.icon(onPressed: () => _editIdentityTransitionRecord(r), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('编辑')),
                      TextButton.icon(onPressed: () => _deleteIdentityTransitionRecord(r), icon: const Icon(Icons.delete_outline, size: 16), label: const Text('删除')),
                      if (r.nextIdentityAction.trim().isNotEmpty || r.newIdentityAction.trim().isNotEmpty) TextButton.icon(onPressed: () => _quickCreateTodoActionFromText(r.nextIdentityAction.trim().isNotEmpty ? r.nextIdentityAction : r.newIdentityAction, '身份转换后的下一条身份证据行动', actionType: 'identity_proof_action'), icon: const Icon(Icons.playlist_add_outlined, size: 16), label: const Text('写入Todo')),
                    ]),
                  ],
                ),
              )),
        ]),
      ),
    );
  }

  Widget _dailyReviewHistoryCard() {
    if (_dailyReviews.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFFFFFBEB),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.event_note_outlined, color: Color(0xFFB45309)), SizedBox(width: 8), Expanded(child: Text('最近每日一致性复盘', style: TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 8),
          ..._dailyReviews.take(7).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('• ${r.dateLabel}｜靠近价值：${r.closestValueAction.isEmpty ? '未填' : r.closestValueAction}｜主要失调：${r.mainDissonance.isEmpty ? '未填' : r.mainDissonance}｜明日行动：${r.tomorrowAction.isEmpty ? '未填' : r.tomorrowAction}', style: const TextStyle(height: 1.35)),
                  Wrap(spacing: 8, children: [
                    TextButton.icon(onPressed: () => _editDailyReview(r), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('编辑')),
                    TextButton.icon(onPressed: () => _deleteDailyReview(r), icon: const Icon(Icons.delete_outline, size: 16), label: const Text('删除')),
                  ]),
                ]),
              )),
        ]),
      ),
    );
  }

  Widget _reportCard(CcReportRecord r) {
    final dt = DateTime.fromMillisecondsSinceEpoch(r.createdAtMs);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.description_outlined, color: Color(0xFF4F46E5)), const SizedBox(width: 8), Expanded(child: Text('${r.periodLabel} · ${dt.year}-${_two(dt.month)}-${_two(dt.day)}', style: const TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 8),
          Text(r.reportText, maxLines: 8, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.45)),
          if (r.suggestedAction.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('已生成建议行动：${r.suggestedAction}', style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.w700, height: 1.4)),
          ],
          if (r.adoptedEvidenceId.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('已被执行并沉淀证据：${r.adoptedEvidenceId}', style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w700, height: 1.4)),
          ],
          const SizedBox(height: 8),
          _reportActionTraceCard(r.reportId),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _reportBusy ? null : () => _generateActionFromReport(r),
              icon: const Icon(Icons.playlist_add_check_outlined),
              label: const Text('根据这份报告生成下一步行动'),
            ),
          ),
        ]),
      ),
    );
  }


  Widget _reportActionTraceCard(String reportId) {
    return FutureBuilder<List<CcReportActionLink>>(
      future: _dao.reportActionLinks(reportId, limit: 8),
      builder: (context, snapshot) {
        final links = snapshot.data ?? const <CcReportActionLink>[];
        if (links.isEmpty) {
          return const Text('采纳链路：暂无。生成下一步行动并写入 Todo / 保存证据后会自动出现。', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35));
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('报告采纳链路', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(height: 6),
            ...links.take(4).map((l) => Text('状态：${l.status} · session:${l.sessionId.isEmpty ? '-' : l.sessionId} · todo:${l.todoStepId.isEmpty ? '-' : l.todoStepId} · evidence:${l.evidenceId.isEmpty ? '-' : l.evidenceId}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.35))),
          ]),
        );
      },
    );
  }

  Widget _emptyCard(String title, String body) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(color: Color(0xFF6B7280), height: 1.45)),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyBlock(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SelectableText(text, style: const TextStyle(height: 1.5)),
    );
  }

  Widget _miniLine(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Color(0xFF111827), height: 1.4),
          children: [
            TextSpan(text: '$label：', style: const TextStyle(fontWeight: FontWeight.w900)),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
    );
  }

  String _timeText(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${_two(m)}:${_two(s)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _normalizeCategory(String raw) => _categoryLabels.containsKey(raw) ? raw : 'start';
}
