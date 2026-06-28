import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../external_data/todo_dao.dart';
import '../external_data/todo_models.dart';
import '../pages/ai_prompt_settings_page.dart';
import '../services/notification_service.dart';

import 'realistic_optimism_training_ai_service.dart';
import 'realistic_optimism_training_flow_page.dart';
import 'realistic_optimism_training_experience_pages.dart';
import 'realistic_optimism_training_dao.dart';
import 'realistic_optimism_training_models.dart';
import 'realistic_optimism_training_prompt_config.dart';

class RealisticOptimismTrainingHomePage extends StatefulWidget {
  final String initialInput;
  final String scene;
  final String extraContext;

  const RealisticOptimismTrainingHomePage({
    super.key,
    this.initialInput = '',
    this.scene = 'event_reframe',
    this.extraContext = '',
  });

  @override
  State<RealisticOptimismTrainingHomePage> createState() => _RealisticOptimismTrainingHomePageState();
}

class _RealisticOptimismTrainingHomePageState extends State<RealisticOptimismTrainingHomePage> {
  final RealisticOptimismTrainingDao _dao = RealisticOptimismTrainingDao();
  final RealisticOptimismTrainingAiService _ai = RealisticOptimismTrainingAiService();
  final TodoDao _todoDao = TodoDao();
  final TextEditingController _inputCtrl = TextEditingController(text: _defaultProblemTemplate);
  bool _loading = true;
  bool _generating = false;
  bool _autoSyncingDaily = false;
  bool _dailyBusy = false;
  String _problemScenario = '拖延 / 没开始';
  String _scene = 'event_reframe';
  List<RealisticOptimismTrainingRecord> _records = <RealisticOptimismTrainingRecord>[];
  List<RealisticOptimismTrainingActionEvidence> _actionEvidenceRows = <RealisticOptimismTrainingActionEvidence>[];
  List<RealisticOptimismTrainingBaseline> _baselines = <RealisticOptimismTrainingBaseline>[];
  List<Map<String, Object?>> _eventIntensityRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> _processPlanRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> _failureRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> _challengeRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> _relationshipRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> _primeRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> _antiPrimeRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> _p2Rows = <Map<String, Object?>>[];
  List<RealisticOptimismTrainingSession> _openSessions = <RealisticOptimismTrainingSession>[];
  RealisticOptimismTrainingStats _stats = const RealisticOptimismTrainingStats(records: 0, actions: 0, baselines: 0, gratitude: 0, primes: 0, identity: 0, explanationScores: 0, benefitReframes: 0, failureImmunity: 0, controlledChallenges: 0, savoring: 0, antiPrimes: 0, relationshipGratitude: 0, eventIntensity: 0, processPlans: 0, p2Artifacts: 0);

  @override
  void initState() {
    super.initState();
    _scene = widget.scene;
    if (widget.initialInput.trim().isNotEmpty) {
      _inputCtrl.text = widget.initialInput.trim();
    } else if (_inputCtrl.text.trim().isEmpty) {
      _inputCtrl.text = _defaultProblemTemplate;
    }
    _load();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _dao.ensureTables();
      await _dao.seedValueSourceAnchors();
      final records = await _dao.listRecords();
      final actionEvidenceRows = await _dao.listAllActionEvidence();
      final baselines = await _dao.listBaselines();
      final stats = await _dao.stats();
      final eventIntensityRows = await _dao.listEventIntensity();
      final processPlanRows = await _dao.listProcessPlans();
      final failureRows = await _dao.listFailureImmunity();
      final challengeRows = await _dao.listControlledChallenges();
      final relationshipRows = await _dao.listRelationshipGratitude();
      final primeRows = await _dao.listPrimes();
      final antiPrimeRows = await _dao.listAntiPrimes();
      final p2Rows = await _dao.listP2Artifacts();
      final openSessions = await _dao.listOpenSessions();
      if (!mounted) return;
      setState(() {
        _records = records;
        _actionEvidenceRows = actionEvidenceRows;
        _baselines = baselines;
        _eventIntensityRows = eventIntensityRows;
        _processPlanRows = processPlanRows;
        _failureRows = failureRows;
        _challengeRows = challengeRows;
        _relationshipRows = relationshipRows;
        _primeRows = primeRows;
        _antiPrimeRows = antiPrimeRows;
        _p2Rows = p2Rows;
        _openSessions = openSessions;
        _stats = stats;
        _loading = false;
      });
      if (!_autoSyncingDaily) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted || _autoSyncingDaily) return;
          _autoSyncingDaily = true;
          try {
            await _dailyExtendSyncExecutionResults(silent: true);
          } finally {
            _autoSyncingDaily = false;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('加载失败：$e');
    }
  }

  Future<void> _generate() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) {
      _toast('请先写下一个事件、失败、拖延、目标、感恩或环境困扰。');
      return;
    }
    setState(() => _generating = true);
    try {
      final result = await _ai.generate(userInput: input, scene: _scene, extraContext: widget.extraContext.isEmpty ? _recentContextJson() : widget.extraContext);
      await _dao.upsertRecord(result.record);
      await _load();
      if (!mounted) return;
      _inputCtrl.clear();
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RealisticOptimismTrainingDetailPage(record: result.record)));
      _load();
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _p2SceneTemplate(String scene) {
    const templates = <String, String>{
      'todo_goal_bridge': '请把一个未完成待办事项转成现实主义乐观训练闭环：情绪允许、解释风格、资源发现视角、明日最小行动。',
      'daily_review': '请根据今天的记录生成晚上复盘：事件、行动证据、三件具体感恩、30秒品味、身份提醒、明日注意力启动线索。',
      'course_card': '请生成一张课程知识卡：主题是解释风格、资源发现视角、失败免疫、注意力启动线索 或感恩品味。',
      'role_model_case': '请生成一个榜样案例：如何经历失败、解释、恢复、行动，以及我今天可模仿的最小动作。',
      'proactive_reminder': '请生成主动提醒方案：触发条件、推送文案、锁屏短句、小组件文字、5分钟行动线索。',
      'monthly_report': '请生成周/月报摘要：解释风格、行动证据、失败恢复、注意力启动线索与消极启动源、感恩敏感度、身份成长。',
      'complete_reality': '请带我做完整现实感练习：我不否认的痛苦、不能美化的部分、仍然存在的好、如果失去会后悔的东西、一个具体珍惜动作。',
      'appreciation_scan': '请带我做防贬值珍惜扫描：找出正在习以为常、但失去后会后悔没有珍惜的人/能力/条件，并设计今天的珍惜动作。',
      'same_reality_interpretations': '请带我做同一现实多种解释练习：事实、当前痛苦解释、相信它会导致的行动、Tal 式替代问题、更完整解释、第一步行动。',
      'loss_resource_retention': '请带我做损失后的资源保留练习：不美化损失，但看见没有一起失去的资源、仍在的人、变清楚的价值和重新开始的一小块。',
      'priming_diagnostic': '请带我做启动源诊断：识别今天哪些应用/词语/图像/环境启动了拖延、比较、自责或无力，并设计替代注意力启动线索。',
      'identity_script_activation': '请带我做身份脚本启动练习：识别我今天被启动成了谁，明天想被启动成谁，以及要放置什么环境脚本。',
      'gratitude_time_in': '请带我做感恩静心分享：安静写下具体感恩、感官细节、身体感受、分享对象、关系表达和表达后记录。',
      'process_simulation_check': '请带我做过程模拟校验：检查我的计划有没有时间、地点、工具、第一步、干扰源、去干扰动作和完成标准。',
      'psychological_immunity_experiment': '请带我做心理免疫实验：失败前预测、失败后实际、痛苦差异、恢复差异、最坏预测是否发生、心理抗体和下次更小行动。',
    };
    return templates[scene] ?? '请生成一个日常实践产物。';
  }


  Future<void> _generateNextMissingP2Artifact() async {
    const order = <String>[
      'todo_goal_bridge',
      'daily_review',
      'course_card',
      'role_model_case',
      'proactive_reminder',
      'monthly_report',
    ];
    final existing = _p2Rows.map((row) => (row['artifact_type'] ?? '').toString()).toSet();
    final scene = order.firstWhere((item) => !existing.contains(item), orElse: () => 'monthly_report');
    await _openGuidedFlow(scene, _p2SceneTemplate(scene));
  }

  Future<void> _openTodoBridgeFromToday() async {
    try {
      final tasks = await _todoDao.listTasks('smart_myday', limit: 8);
      if (tasks.isEmpty) {
        _toast('今天没有可转入训练的未完成待办事项。');
        return;
      }
      await _openGuidedFlow('todo_goal_bridge', _todoBridgePrompt(tasks));
    } catch (e) {
      _toast('读取待办事项失败：$e');
    }
  }

  String _todoBridgePrompt(List<TodoTaskRecord> tasks) {
    final lines = tasks.take(5).map((task) {
      final parts = <String>[
        '- 标题：${task.title}',
        if (task.listDisplayName.trim().isNotEmpty) '清单：${task.listDisplayName}',
        if (task.dueDateTime.trim().isNotEmpty) '截止：${task.dueDateTime}',
        if (task.importance == 'high') '重要性：高',
        if (task.bodyText.trim().isNotEmpty) '备注：${task.bodyText.trim()}',
      ];
      return parts.join('；');
    }).join('\n');
    return '【日常实践待办事项自动桥接】以下是今天仍未完成的待办事项，请不要把它们简单判定为失败；请按最终方案转换为：情绪允许 → 事实/解释分离 → 解释风格雷达 → 问题视角/资源视角 双镜头 → 明日最小行动 → 如果-那么 → 行动证据问题 → 可复用的待办事项产物。\n$lines';
  }

  Future<void> _createReminderRuleTodo() async {
    try {
      final lists = await _todoDao.listLists();
      final listId = lists.isNotEmpty ? lists.first.listId : await _todoDao.createLocalList('现实主义乐观行动');
      await _todoDao.createLocalTask(
        listId: listId,
        title: '设置一条现实主义乐观主动提醒规则',
        bodyText: '日常实践主动提醒规则配置：\n1. 触发条件：例如待办事项逾期、睡前刷信息流、自责超过 5 分钟。\n2. 提醒文案：必须短、具体、非鸡汤。\n3. 行动线索：只给一个 5 分钟动作。\n4. 复用位置：推送 / 锁屏短句 / 小组件文字 / 待办事项顶部提示。\n5. 频率：每天、工作日、每周，或只在触发时。\n6. 关闭策略：如果连续 3 次忽略，就降低频率或重写文案。',
        status: 'notStarted',
        importance: 'normal',
        isMyDay: true,
      );
      _toast('已创建主动提醒规则配置待办事项。');
    } catch (e) {
      _toast('创建提醒规则待办事项失败：$e');
    }
  }

  Future<void> _createMonthlyReportTodo() async {
    try {
      final lists = await _todoDao.listLists();
      final listId = lists.isNotEmpty ? lists.first.listId : await _todoDao.createLocalList('现实主义乐观行动');
      final now = DateTime.now();
      final monthText = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await _todoDao.createLocalTask(
        listId: listId,
        title: '生成 $monthText 现实主义乐观周/月报',
        bodyText: '日常实践周/月报复盘清单（$monthText）：\n1. 解释风格：永久化、人格化、灾难化是否下降？\n2. 行动证据：本周期完成了多少 5 分钟行动？\n3. 失败免疫：预测痛苦与实际痛苦差距如何？恢复时间是否缩短？\n4. 注意力环境：设置了哪些 注意力启动线索，清理了哪些 消极启动源？\n5. 感恩敏感：记录了哪些具体感恩、品味和关系表达？\n6. 身份成长：五类身份各新增了哪些证据？\n7. 下周期只选择一个训练重点。',
        status: 'notStarted',
        importance: 'normal',
        isMyDay: true,
      );
      _toast('已创建周/月报复盘待办事项。');
    } catch (e) {
      _toast('创建周/月报待办事项失败：$e');
    }
  }

  Future<void> _createDailyReviewTodo() async {
    try {
      final lists = await _todoDao.listLists();
      final listId = lists.isNotEmpty ? lists.first.listId : await _todoDao.createLocalList('现实主义乐观行动');
      final today = DateTime.now();
      final dateText = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await _todoDao.createLocalTask(
        listId: listId,
        title: '今晚做一次现实主义乐观复盘',
        bodyText: '日常实践每日复盘清单（$dateText）：\n1. 今天最需要重构的一件事是什么？\n2. 我陷入了哪种解释风格？\n3. 今天完成了哪个行动证据？\n4. 三件具体感恩分别是什么？\n5. 停留 30 秒品味一个微小好体验。\n6. 生成一句“我正在成为……”身份提醒。\n7. 设置明日注意力启动线索。',
        status: 'notStarted',
        importance: 'normal',
        isMyDay: true,
      );
      _toast('已创建今晚现实主义乐观复盘待办事项。');
    } catch (e) {
      _toast('创建复盘待办事项失败：$e');
    }
  }

  Future<void> _createTodoFromLatestP2Action() async {
    if (_p2Rows.isEmpty) {
      _toast('暂无可回写待办事项的日常实践产物。');
      return;
    }
    final source = _p2Rows.first;
    final action = (source['next_action'] ?? source['summary'] ?? '').toString().trim();
    if (action.isEmpty) {
      _toast('最新日常实践产物没有可回写的下一步行动。');
      return;
    }
    try {
      final lists = await _todoDao.listLists();
      final listId = lists.isNotEmpty ? lists.first.listId : await _todoDao.createLocalList('现实主义乐观行动');
      final title = action.length > 40 ? '${action.substring(0, 40)}…' : action;
      final artifactType = (source['artifact_type'] ?? '').toString();
      final summary = (source['summary'] ?? '').toString();
      await _todoDao.createLocalTask(
        listId: listId,
        title: title,
        bodyText: '来自现实主义乐观训练日常实践产物：$artifactType\n\n摘要：$summary\n\n下一步行动：$action',
        status: 'notStarted',
        importance: 'normal',
        isMyDay: true,
      );
      _toast('已把最新日常实践行动写入“我的一天”待办事项。');
    } catch (e) {
      _toast('回写待办事项失败：$e');
    }
  }

  Future<void> _copyP2VoiceInputTemplate() async {
    const text = '现实主义乐观语音输入模板：\n1. 今天发生的客观事件是……\n2. 我现在最强烈的情绪是……身体感觉在……\n3. 我脑中自动出现的解释是……\n4. 这句话里可能有永久化/普遍化/人格化/灾难化/无力化/过滤化的是……\n5. 我还能控制的一个很小部分是……\n6. 我愿意先做的 5 分钟行动是……';
    await Clipboard.setData(const ClipboardData(text: text));
    _toast('已复制语音输入模板，可用系统语音键盘直接听写。');
  }

  Future<void> _copyLatestP2WidgetText() async {
    final source = _p2Rows.isNotEmpty ? _p2Rows.first : <String, Object?>{};
    final title = (source['title'] ?? '现实主义乐观提醒').toString().trim();
    final action = (source['next_action'] ?? source['summary'] ?? '').toString().trim();
    final text = action.isEmpty ? '我可以痛苦，也可以先做一个 5 分钟行动证据。' : action;
    await Clipboard.setData(ClipboardData(text: '$title\n$text'));
    _toast('已复制为锁屏/小组件短句');
  }

  String _buildP2OperatingDigestText() {
    const labels = <String, String>{
      'todo_goal_bridge': '待办事项桥接',
      'daily_review': '每日复盘',
      'course_card': '课程卡',
      'role_model_case': '榜样案例',
      'proactive_reminder': '主动提醒',
      'monthly_report': '周/月报',
    };
    final counts = <String, int>{for (final key in labels.keys) key: 0};
    final actions = <String>[];
    for (final row in _p2Rows) {
      final type = (row['artifact_type'] ?? '').toString();
      if (counts.containsKey(type)) counts[type] = (counts[type] ?? 0) + 1;
      final action = (row['next_action'] ?? row['summary'] ?? '').toString().trim();
      if (action.isNotEmpty && actions.length < 3) actions.add(action);
    }
    final missing = labels.entries
        .where((entry) => (counts[entry.key] ?? 0) == 0)
        .map((entry) => entry.value)
        .join('、');
    final coverage = labels.entries
        .map((entry) => '${entry.value}:${counts[entry.key] ?? 0}')
        .join('｜');
    final actionText = actions.isEmpty
        ? '1. 先创建一个待办事项转行动或明日注意力启动线索提醒'
        : actions
            .asMap()
            .entries
            .map((entry) => '${entry.key + 1}. ${entry.value}')
            .join('\n');
    final text = '日常实践摘要\n'
        '覆盖度：$coverage\n'
        '缺口：${missing.isEmpty ? '暂无，六类产物都有样本' : missing}\n'
        '最近可执行动作：\n$actionText';
    return text;
  }

  Future<void> _copyP2OperatingDigest() async {
    final text = _buildP2OperatingDigestText();
    await Clipboard.setData(ClipboardData(text: text));
    _toast('已复制 日常实践摘要');
  }

  Future<void> _createP2OperatingReviewTodo() async {
    try {
      final lists = await _todoDao.listLists();
      final listId = lists.isNotEmpty
          ? lists.first.listId
          : await _todoDao.createLocalList('现实主义乐观行动');
      await _todoDao.createLocalTask(
        listId: listId,
        title: '复盘 日常实践摘要并补齐缺口',
        bodyText: '${_buildP2OperatingDigestText()}\n\n请从缺口里只选一个，生成或执行一个日常实践产物。',
        status: 'notStarted',
        importance: 'normal',
        isMyDay: true,
      );
      _toast('已创建日常实践复盘待办事项。');
    } catch (e) {
      _toast('创建日常实践复盘待办事项失败：$e');
    }
  }

  Future<void> _sendLatestP2Reminder() async {
    final reminder = _p2Rows.cast<Map<String, Object?>>().firstWhere(
      (row) => (row['artifact_type'] ?? '').toString() == 'proactive_reminder',
      orElse: () => _p2Rows.isNotEmpty ? _p2Rows.first : <String, Object?>{},
    );
    final title = (reminder['title'] ?? '').toString().trim().isEmpty ? '现实主义乐观提醒' : (reminder['title'] ?? '').toString().trim();
    final triggerCount = reminder['dismissed_count'] is num ? (reminder['dismissed_count'] as num).toInt() : int.tryParse((reminder['dismissed_count'] ?? '0').toString()) ?? 0;
    final rawBody = (reminder['next_action'] ?? reminder['summary'] ?? '').toString().trim().isEmpty
        ? '如果开始自责，就只做一个 5 分钟行动证据。'
        : (reminder['next_action'] ?? reminder['summary']).toString().trim();
    final body = triggerCount >= 3 ? '这条提醒已经多次出现。今天不加压，只把行动缩到 2 分钟：打开材料，留下一个痕迹即可。' : rawBody;
    try {
      await NotificationService.show(title: title, body: body, payload: 'realistic_optimism_training:proactive_reminder');
      final id = (reminder['id'] ?? '').toString().trim();
      if (id.isNotEmpty) {
        await _dao.updateDailyExtensionArtifactStatus(
          id: id,
          status: (reminder['status'] ?? 'active').toString(),
          lastTriggeredAtMs: DateTime.now().millisecondsSinceEpoch,
          dismissedCount: triggerCount + 1,
          nextAction: body,
        );
      }
      _toast(triggerCount >= 3 ? '已发送降频后的 2 分钟提醒' : '已发送一条现实主义乐观提醒');
    } catch (e) {
      _toast('发送提醒失败：$e');
    }
  }

  String _shortActionTitle(String text, {int max = 34}) {
    final oneLine = text.replaceAll('\n', ' ').trim();
    if (oneLine.length <= max) return oneLine.isEmpty ? '现实主义乐观行动' : oneLine;
    return '${oneLine.substring(0, max)}…';
  }

  Future<String> _dailyExtensionListId() async {
    final lists = await _todoDao.listLists();
    final existing = lists.where((list) => list.displayName == '现实主义乐观行动').toList(growable: false);
    if (existing.isNotEmpty) return existing.first.listId;
    return _todoDao.createLocalList('现实主义乐观行动');
  }

  TodoTaskRecord? _firstOpenTask(List<TodoTaskRecord> tasks) {
    for (final task in tasks) {
      if (!task.isCompleted && task.title.trim().isNotEmpty) return task;
    }
    return null;
  }

  String _latestSafetyLevel() {
    final now = DateTime.now().millisecondsSinceEpoch;
    const l3WindowMs = 36 * 60 * 60 * 1000;
    const l4WindowMs = 7 * 24 * 60 * 60 * 1000;
    for (final session in _openSessions) {
      final level = session.level.trim();
      final age = now - session.updatedAtMs;
      if (level == 'L4' && age <= l4WindowMs) return 'L4';
      if (level == 'L3' && age <= l3WindowMs) return 'L3';
    }
    for (final record in _records.take(20)) {
      final level = record.intensityLevel.trim();
      final age = now - record.updatedAtMs;
      if (level == 'L4' && age <= l4WindowMs) return 'L4';
      if (level == 'L3' && age <= l3WindowMs) return 'L3';
      if (level == 'L1' || level == 'L2') return level;
    }
    return 'L1';
  }

  bool _isHighSafetyLevel(String level) => level == 'L3' || level == 'L4';

  Future<String> _preferredTodoTimeZone() async {
    try {
      final tz = await _todoDao.getPreferredTimeZone();
      return tz.trim().isEmpty ? 'Asia/Shanghai' : tz.trim();
    } catch (_) {
      return 'Asia/Shanghai';
    }
  }

  int _tomorrowMorningMs() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9).millisecondsSinceEpoch;
  }


  int _startOfDayMs(DateTime value) => DateTime(value.year, value.month, value.day).millisecondsSinceEpoch;
  int _endOfDayMs(DateTime value) => DateTime(value.year, value.month, value.day).add(const Duration(days: 1)).millisecondsSinceEpoch;

  bool _rowHasTimeInWindow(Map<String, Object?> row, int startMs, int endMs) {
    for (final key in <String>['scheduled_at_ms', 'completed_at_ms', 'created_at_ms']) {
      final v = row[key];
      final ms = v is num ? v.toInt() : int.tryParse((v ?? '').toString()) ?? 0;
      if (ms >= startMs && ms < endMs) return true;
    }
    return false;
  }

  bool _isTodayDailyRow(Map<String, Object?> row) {
    final type = _rowText(row, 'artifact_type');
    final now = DateTime.now();
    final todayStart = _startOfDayMs(now);
    final todayEnd = _endOfDayMs(now);
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowStart = _startOfDayMs(tomorrow);
    final tomorrowEnd = _endOfDayMs(tomorrow);
    if (type == 'proactive_reminder') {
      return _rowHasTimeInWindow(row, todayStart, tomorrowEnd);
    }
    if (type == 'todo_goal_bridge' || type == 'daily_review' || type == 'safety_support' || type == 'anti_prime_cleanup' || type == 'overdue_review') {
      return _rowHasTimeInWindow(row, todayStart, todayEnd) || _rowText(row, 'status') == 'active';
    }
    return false;
  }

  List<Map<String, Object?>> _dailyCockpitRows() => _p2Rows.where(_isTodayDailyRow).toList(growable: false);

  Future<void> _createSafetySupportDailyArtifact(String level) async {
    final pausedTodoIds = await _dao.pauseOrdinaryDailyArtifactsForSafety(level);
    for (final taskId in pausedTodoIds) {
      await _todoDao.pauseTaskReminderForSafety(taskId: taskId, safetyLevel: level);
    }
    final tz = await _preferredTodoTimeZone();
    final listId = await _dailyExtensionListId();
    final title = level == 'L4' ? '安全支持：先联系一个现实中的人' : '稳定支持：先把行动缩到最小';
    final body = level == 'L4'
        ? '当前不进入普通现实主义乐观训练，不做强行积极、强行感恩或失败挑战。\n\n现在只做安全支持：\n1. 联系一个可信任的人。\n2. 离开可能让自己受伤的环境或物品。\n3. 喝水、坐下、让身体稳定 2 分钟。\n4. 必要时寻求专业或紧急支持。'
        : '当前强度较高，先不要求自己立刻变积极。\n\n稳定支持：\n1. 只写事实，不下人格结论。\n2. 行动缩到 2 分钟。\n3. 今天只需要保留一个恢复入口。';
    final taskId = await _todoDao.createLocalTask(
      listId: listId,
      title: title,
      bodyText: body,
      status: 'notStarted',
      importance: 'high',
      isMyDay: true,
      dueTimeZone: tz,
      startTimeZone: tz,
    );
    await _dao.upsertDailyExtensionArtifact(
      artifactType: 'safety_support',
      title: title,
      triggerText: level,
      triggerCondition: '$level 强度，暂停普通日常实践',
      summary: '安全优先：不把高强度痛苦推进到普通行动、注意力启动线索 或感恩流程。',
      reuseSurface: '待办事项 / 安全支持',
      nextAction: level == 'L4' ? '联系一个可信任的人或专业支持。' : '只做 2 分钟稳定动作。',
      sourceType: 'safety_level',
      sourceId: level,
      targetType: 'todo_task',
      targetId: taskId,
      status: 'active',
      safetyLevel: level,
      timezone: tz,
      content: <String, Object?>{
        'safety_level': level,
        'todo_task_id': taskId,
        'body': body,
        'core_value': 'L3/L4 安全优先；不强行 资源发现视角、不强行感恩、不做失败挑战。',
      },
    );
    await _load();
    _toast(level == 'L4' ? '已创建安全支持待办事项，普通日常实践已暂停。' : '已创建稳定支持待办事项。');
  }

  Future<TodoTaskRecord?> _chooseOpenTodoTask(List<TodoTaskRecord> tasks) async {
    final open = tasks.where((task) => !task.isCompleted && task.title.trim().isNotEmpty).toList(growable: false);
    if (open.isEmpty) return null;
    if (!mounted) return open.first;
    return showDialog<TodoTaskRecord>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择要转成 5 分钟行动的待办事项'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: open.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final task = open[index];
              return ListTile(
                title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(task.listDisplayName.trim().isEmpty ? '未完成任务' : task.listDisplayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(ctx, task),
              );
            },
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
  }

  String _artifactAction(Map<String, Object?> row) => (row['next_action'] ?? row['summary'] ?? '').toString().trim();

  String _rowText(Map<String, Object?>? row, String key) => (row == null ? '' : (row[key] ?? '').toString()).trim();

  int _rowInt(Map<String, Object?>? row, String key) {
    if (row == null) return 0;
    final raw = row[key];
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? '').toString()) ?? 0;
  }

  Map<String, Object?>? _latestDailyArtifact(String artifactType, {Set<String>? statuses, Iterable<Map<String, Object?>>? rows}) {
    for (final row in rows ?? _p2Rows) {
      final type = _rowText(row, 'artifact_type');
      final status = _rowText(row, 'status').isEmpty ? 'active' : _rowText(row, 'status');
      if (type == artifactType && (statuses == null || statuses.contains(status))) return row;
    }
    return null;
  }

  Map<String, Object?>? _latestDailyActionArtifact({Iterable<Map<String, Object?>>? rows}) {
    return _latestDailyArtifact('todo_goal_bridge', statuses: <String>{'scheduled', 'active'}, rows: rows) ??
        _latestDailyArtifact('todo_goal_bridge', rows: rows);
  }

  Future<void> _dailyMarkLatestActionCompleted() async {
    try {
      final row = _latestDailyActionArtifact(rows: _dailyCockpitRows()) ?? _latestDailyActionArtifact();
      if (row == null) {
        _toast('还没有可完成的 5 分钟行动。请先把一个待办事项转成今日行动。');
        return;
      }
      final id = _rowText(row, 'id');
      if (id.isEmpty) {
        _toast('找不到这条行动记录，无法回流。');
        return;
      }
      final status = _rowText(row, 'status');
      if (status == 'completed') {
        _toast('这条行动已经回流为行动证据。');
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final action = _artifactAction(row).isNotEmpty ? _artifactAction(row) : '完成了一个 5 分钟行动。';
      final targetType = _rowText(row, 'target_type');
      final targetId = _rowText(row, 'target_id');
      if (targetType == 'todo_task' && targetId.isNotEmpty) {
        await _todoDao.updateTaskCompletion(taskId: targetId, completed: true);
      }
      await _dao.updateDailyExtensionArtifactStatus(
        id: id,
        status: 'completed',
        completedAtMs: now,
        mergeContent: <String, Object?>{
          'manual_execution_result': 'completed_from_daily_cockpit',
          'completed_at_ms': now,
          'completed_target_todo_id': targetId,
        },
      );
      final recordId = _rowText(row, 'linked_record_id').isNotEmpty ? _rowText(row, 'linked_record_id') : _rowText(row, 'record_id');
      await _dao.addActionEvidence(RealisticOptimismTrainingActionEvidence(
        id: 'rot_daily_manual_action_${id.hashCode.abs()}',
        recordId: recordId,
        action: action,
        evidenceText: '我完成了日常闭环里的 5 分钟行动：$action',
        completed: true,
        completedAtMs: now,
        selfEfficacyScore: 8,
        sourceType: 'daily_artifact',
        sourceId: id,
        todoTaskId: targetId,
        dailyArtifactId: id,
        createdAtMs: now,
      ));
      await _dao.addIdentityEvidence(
        id: 'rot_daily_identity_${id.hashCode.abs()}',
        recordId: recordId,
        sourceType: 'daily_action_completed',
        identityType: '行动证据积累者',
        evidenceText: '完成了一个日常 5 分钟行动：$action',
        identitySentence: '我正在成为一个不等状态完美，也能用小行动建立信心的人。',
      );
      await _load();
      _toast('已完成待办事项并回流为行动证据，同时生成身份沉淀。');
    } catch (e) {
      _toast('行动回流失败：$e');
    }
  }

  Map<String, dynamic> _buildManualFailureRecordPayload({
    required String oldAction,
    required String smallerAction,
    required String sourceRecordId,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return <String, dynamic>{
      'id': 'rot_daily_failure_${oldAction.hashCode.abs()}_$now',
      'module': 'realistic_optimism',
      'scene': 'failure_immunity',
      'raw_input': '日常行动未完成：$oldAction',
      'intensity_check': <String, dynamic>{
        'level': 'L1',
        'reason': '日常 5 分钟行动未完成，属于可恢复、可缩小的训练材料。',
        'allowed_intervention': <String>['情绪允许', '失败免疫复盘', '缩小行动'],
        'blocked_intervention': <String>['人格否定', '强迫补完全部计划'],
      },
      'user_event_summary': '日常行动没有完成，已转入失败免疫和更小行动。',
      'emotion_validation': <String, dynamic>{
        'primary_emotion': '自责',
        'validation_text': '没完成会让人自责，但这不是人格失败；它说明行动入口还需要继续缩小。',
      },
      'fact_layer': <String, dynamic>{
        'objective_facts': <String>['原行动暂未完成：$oldAction'],
        'unknowns_or_assumptions': <String>['这不等于我永远坚持不了。'],
      },
      'interpretation_style': <String, dynamic>{
        'automatic_interpretation': '我又没做到，可能说明我不行。',
        'permanence_score': 6,
        'pervasiveness_score': 5,
        'personalization_score': 7,
        'catastrophizing_score': 4,
        'helplessness_score': 5,
        'filtering_score': 5,
        'main_pattern': '人格化和永久化风险',
      },
      'fault_finder_layer': <String, dynamic>{
        'fault_finder_story': '没完成 = 我不行 = 之后也做不到。',
        'likely_emotional_effect': '更自责、更无力。',
        'likely_behavioral_effect': '更容易继续逃避。',
      },
      'benefit_finder_layer': <String, dynamic>{
        'balanced_interpretation': '这次未完成说明行动入口还不够小，环境或阻力需要重新设计；它不是对整个人的判决。',
        'not_denied_pain': '承认未完成带来的失望和自责。',
        'possible_learning': <String>['把行动缩小到 2 分钟', '降低完成标准，只要求留下痕迹'],
        'remaining_resources': <String>['我仍然可以重新开始', '系统可以把入口再缩小'],
        'possible_meaning': <String>['这次卡住可以成为恢复能力训练材料'],
      },
      'agency_layer': <String, dynamic>{
        'uncontrollable_parts': <String>['已经错过的那一次执行'],
        'influenceable_parts': <String>['环境干扰', '行动大小', '提醒方式'],
        'controllable_actions': <String>[smallerAction],
      },
      'process_action_plan': <String, dynamic>{
        'five_minute_action': smallerAction,
        'next_three_steps': <String>[smallerAction, '完成后记录一个痕迹', '晚上复盘卡点'],
        'if_then_plan': <String>['如果仍然想逃避，那么只打开材料 30 秒。'],
      },
      'failure_immunity': <String, dynamic>{
        'predicted_pain': 6,
        'actual_pain': 5,
        'predicted_recovery': '担心自己会继续自责。',
        'actual_recovery': '把行动缩小后仍保留重新开始入口。',
        'worst_case_prediction': '我可能觉得自己永远坚持不了。',
        'actual_result': '原行动未完成，但已生成更小行动。',
        'psychological_antibody': '没完成不是人格失败，而是流程需要继续缩小。',
      },
      'identity_evidence': <String, dynamic>{
        'specific_action': '没有把未完成停留在自责里，而是转成失败免疫和更小行动。',
        'proved_capacity': '失败后恢复与重新设计入口的能力',
        'identity_type': '失败后恢复者',
        'identity_sentence': '我正在成为一个没完成后也能复盘、缩小并重新开始的人。',
      },
      'final_user_message': '这次没完成不等于你失败到底。今天真正的训练是：把自责转成更小入口。',
      'provider': 'local',
      'model_label': '日常闭环本地失败免疫',
      'linked_source_record_id': sourceRecordId,
      'created_at_ms': now,
      'updated_at_ms': now,
    };
  }

  Future<void> _createPendingReviewAndTwoMinuteRestart(Map<String, Object?> row, TodoTaskRecord task, int now) async {
    final id = _rowText(row, 'id');
    final oldAction = _artifactAction(row).isEmpty ? task.title : _artifactAction(row);
    final smallerAction = '只做 2 分钟：打开相关材料，完成一个能留下痕迹的小动作；不评价质量。';
    if (id.isNotEmpty) {
      await _dao.updateDailyExtensionArtifactStatus(
        id: id,
        status: 'needs_review',
        mergeContent: <String, Object?>{
          'execution_result': 'todo_overdue_needs_review',
          'review_options': <String>['已完成，只是忘了点', '没完成，帮我拆小', '暂时跳过', '这个任务不重要了'],
          'recovery_suggestion': smallerAction,
        },
      );
    }
    final listId = await _dailyExtensionListId();
    final tz = await _preferredTodoTimeZone();
    final recoveryTaskId = await _todoDao.createLocalTask(
      listId: listId,
      title: '2 分钟恢复入口：${_shortActionTitle(task.title, max: 20)}',
      bodyText: '这个待办事项超过计划时间还没有完成，但系统不会把它判定为人格失败。\n\n原行动：$oldAction\n\n现在只保留一个恢复入口：$smallerAction\n\n你也可以回到“日常”页选择：已完成只是忘了点、没完成帮我拆小、暂时跳过、任务不重要了。',
      status: 'notStarted',
      importance: 'normal',
      isMyDay: true,
      dueTimeZone: tz,
      startTimeZone: tz,
    );
    await _dao.upsertDailyExtensionArtifact(
      artifactType: 'overdue_review',
      title: '待复盘卡片：未完成不等于失败',
      triggerText: task.title,
      triggerCondition: '日常 5 分钟行动超过计划时间仍未完成',
      summary: '先确认真实情况，再决定是补记完成、缩小行动、暂时跳过，还是取消这个任务。',
      reuseSurface: '日常驾驶舱 / 待办事项 / 失败免疫候选',
      nextAction: smallerAction,
      sourceType: 'daily_artifact',
      sourceId: id,
      targetType: 'todo_task',
      targetId: recoveryTaskId,
      status: 'needs_review',
      scheduledAtMs: now,
      safetyLevel: _latestSafetyLevel(),
      timezone: tz,
      content: <String, Object?>{
        'previous_action': oldAction,
        'source_task_id': task.taskId,
        'generated_recovery_task_id': recoveryTaskId,
        'smaller_action': smallerAction,
        'review_options': <String>['已完成，只是忘了点', '没完成，帮我拆小', '暂时跳过', '这个任务不重要了'],
        'core_value': '系统不自动把逾期等同失败；先允许人为，再给恢复入口。',
      },
    );
  }

  Future<void> _dailyShrinkLatestAction() async {
    try {
      final row = _latestDailyActionArtifact(rows: _dailyCockpitRows()) ?? _latestDailyActionArtifact();
      if (row == null) {
        _toast('还没有可缩小的行动。请先转入一个未完成待办事项。');
        return;
      }
      final oldId = _rowText(row, 'id');
      final oldAction = _artifactAction(row).isEmpty ? '打开任务材料，做最小一步。' : _artifactAction(row);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (oldId.isNotEmpty) {
        await _dao.updateDailyExtensionArtifactStatus(
          id: oldId,
          status: 'failed',
          mergeContent: <String, Object?>{
            'manual_execution_result': 'not_completed_from_daily_cockpit',
            'recovery_suggestion': '把行动缩小到 2 分钟，不做人格判决。',
          },
        );
      }
      final sourceRecordId = _rowText(row, 'linked_record_id').isNotEmpty ? _rowText(row, 'linked_record_id') : _rowText(row, 'record_id');
      final smallerAction = '只做 2 分钟：打开相关材料，完成一个能留下痕迹的小动作；不评价质量。';
      final failureRecord = RealisticOptimismTrainingRecord.fromJson(_buildManualFailureRecordPayload(
        oldAction: oldAction,
        smallerAction: smallerAction,
        sourceRecordId: sourceRecordId,
      ));
      await _dao.upsertRecord(failureRecord);
      final listId = await _dailyExtensionListId();
      final tz = await _preferredTodoTimeZone();
      final scheduledAt = DateTime.now().millisecondsSinceEpoch;
      final taskId = await _todoDao.createLocalTask(
        listId: listId,
        title: '2 分钟重新开始',
        bodyText: '来自日常闭环的温和缩小。\n\n原行动：$oldAction\n\n新的最小动作：$smallerAction\n\n完成标准：只要开始并留下一个痕迹，就算完成。',
        status: 'notStarted',
        importance: 'normal',
        isMyDay: true,
        dueTimeZone: tz,
        startTimeZone: tz,
      );
      await _dao.upsertDailyExtensionArtifact(
        artifactType: 'todo_goal_bridge',
        title: '重新缩小后的 2 分钟行动',
        triggerText: oldAction,
        triggerCondition: '日常 5 分钟行动未完成后',
        summary: '未完成不进入自责，而是进入失败免疫，并把入口缩小到 2 分钟。',
        reuseSurface: '待办事项 / 我的今天 / 失败免疫',
        nextAction: smallerAction,
        recordId: failureRecord.id,
        sourceType: 'daily_shrink',
        sourceId: oldId.isEmpty ? now.toString() : oldId,
        targetType: 'todo_task',
        targetId: taskId,
        status: 'scheduled',
        scheduledAtMs: scheduledAt,
        linkedRecordId: failureRecord.id,
        safetyLevel: _latestSafetyLevel(),
        timezone: tz,
        content: <String, Object?>{
          'previous_action': oldAction,
          'smaller_action': smallerAction,
          'generated_task_id': taskId,
          'failure_record_id': failureRecord.id,
          'core_value': '未完成进入缩小行动和失败免疫，而不是人格失败。',
        },
      );
      await _load();
      _toast('已生成完整失败免疫记录，并创建更小的 2 分钟重新开始动作。');
    } catch (e) {
      _toast('缩小行动失败：$e');
    }
  }

  void _goToWeeklyTab() {
    DefaultTabController.of(context).animateTo(4);
  }

  void _goToEnvironmentTab() {
    DefaultTabController.of(context).animateTo(5);
  }

  void _goToAdvancedTab() {
    DefaultTabController.of(context).animateTo(7);
  }

  Future<void> _runDailyLocked(Future<void> Function() action) async {
    if (_dailyBusy) {
      _toast('正在处理上一项日常闭环动作，请稍等。');
      return;
    }
    if (mounted) setState(() => _dailyBusy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _dailyBusy = false);
    }
  }

  Future<void> _supersedeOpenDailyArtifactsAndPauseTodos(String artifactType) async {
    for (final row in _p2Rows) {
      final type = _rowText(row, 'artifact_type');
      final status = _rowText(row, 'status').isEmpty ? 'active' : _rowText(row, 'status');
      if (type != artifactType || !<String>{'draft', 'active', 'scheduled', 'needs_review'}.contains(status)) continue;
      final targetType = _rowText(row, 'target_type');
      final targetId = _rowText(row, 'target_id');
      if (targetType == 'todo_task' && targetId.isNotEmpty) {
        await _todoDao.pauseTaskReminderForSafety(taskId: targetId, safetyLevel: '新版替换');
      }
    }
    await _dao.supersedeOpenDailyArtifactsByType(artifactType: artifactType);
  }

  Future<void> _dailyExtendSyncExecutionResults({bool silent = false}) async {
    var completed = 0;
    var overdue = 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in _p2Rows) {
      final id = (row['id'] ?? '').toString();
      final targetType = (row['target_type'] ?? '').toString();
      final targetId = (row['target_id'] ?? '').toString();
      final status = (row['status'] ?? 'active').toString();
      if (id.isEmpty || targetType != 'todo_task' || targetId.isEmpty || <String>{'completed', 'failed', 'superseded', 'paused_for_safety', 'abandoned', 'archived'}.contains(status)) continue;
      final task = await _todoDao.getTask(targetId);
      if (task == null) continue;
      if (task.isCompleted) {
        completed += 1;
        final action = _artifactAction(row).isEmpty ? task.title : _artifactAction(row);
        await _dao.updateDailyExtensionArtifactStatus(
          id: id,
          status: 'completed',
          completedAtMs: now,
          mergeContent: <String, Object?>{'execution_result': 'todo_completed', 'completed_task_title': task.title},
        );
        final recordId = (row['linked_record_id'] ?? row['record_id'] ?? '').toString();
        await _dao.addActionEvidence(RealisticOptimismTrainingActionEvidence(
          id: 'rot_daily_action_${targetId.hashCode.abs()}',
          recordId: recordId,
          action: action,
          evidenceText: '日常待办事项已完成：${task.title}',
          completed: true,
          completedAtMs: now,
          selfEfficacyScore: 8,
          sourceType: 'daily_artifact',
          sourceId: id,
          todoTaskId: targetId,
          dailyArtifactId: id,
          createdAtMs: now,
        ));
        await _dao.addIdentityEvidence(
          id: 'rot_daily_sync_identity_${targetId.hashCode.abs()}',
          recordId: recordId,
          sourceType: 'todo_execution_sync',
          identityType: '行动证据积累者',
          evidenceText: '完成了日常待办事项：${task.title}',
          identitySentence: '我正在成为一个能把计划执行并回流为证据的人。',
        );
      } else {
        final scheduled = row['scheduled_at_ms'] is num ? (row['scheduled_at_ms'] as num).toInt() : int.tryParse((row['scheduled_at_ms'] ?? '').toString()) ?? 0;
        if (scheduled > 0 && scheduled < now - const Duration(hours: 20).inMilliseconds) {
          overdue += 1;
          await _createPendingReviewAndTwoMinuteRestart(row, task, now);
        }
      }
    }
    if (completed + overdue > 0) await _load();
    if (!silent) _toast('执行回流完成：完成 $completed 个，待确认 $overdue 个。');
  }

  Future<void> _dailyExtendOpenEveningReviewFlow() async {
    final safetyLevel = _latestSafetyLevel();
    if (_isHighSafetyLevel(safetyLevel)) {
      await _createSafetySupportDailyArtifact(safetyLevel);
      return;
    }
    final latest = _records.isNotEmpty ? _records.first : null;
    final latestSession = _openSessions.isNotEmpty ? _openSessions.first : null;
    final text = latest?.eventSummary.trim().isNotEmpty == true
        ? latest!.eventSummary
        : latestSession?.eventText.trim().isNotEmpty == true
            ? latestSession!.eventText
            : '今晚复盘：今天最需要沉淀成证据的一件事。';
    final completedRecord = await Navigator.of(context).push<RealisticOptimismTrainingRecord>(MaterialPageRoute(builder: (_) => RotCoreBusinessFlowPage(initialText: text, initialScene: 'daily_review', extraContext: '日常实践晚间复盘：请把今日行动、未完成卡点、感恩、注意力启动线索和身份沉淀写回核心训练会话。')));
    if (completedRecord != null) {
      final row = _latestDailyArtifact('daily_review', statuses: <String>{'scheduled', 'active'}, rows: _dailyCockpitRows()) ?? _latestDailyArtifact('daily_review', statuses: <String>{'scheduled', 'active'});
      if (row != null) {
        final id = _rowText(row, 'id');
        final targetId = _rowText(row, 'target_id');
        if (_rowText(row, 'target_type') == 'todo_task' && targetId.isNotEmpty) {
          await _todoDao.updateTaskCompletion(taskId: targetId, completed: true);
        }
        if (id.isNotEmpty) {
          await _dao.updateDailyExtensionArtifactStatus(
            id: id,
            status: 'completed',
            completedAtMs: DateTime.now().millisecondsSinceEpoch,
            mergeContent: <String, Object?>{'review_record_id': completedRecord.id, 'execution_result': 'review_completed'},
          );
        }
      }
      if (completedRecord.lockScreenSentence.trim().isNotEmpty || completedRecord.dailyValueWord.trim().isNotEmpty) {
        await _dao.addAttentionPrime(
          id: 'rot_daily_review_prime_${completedRecord.id.hashCode.abs()}',
          recordId: completedRecord.id,
          valueWord: completedRecord.dailyValueWord.trim().isEmpty ? '重新开始' : completedRecord.dailyValueWord.trim(),
          reminder: completedRecord.lockScreenSentence.trim().isEmpty ? '先做一个 5 分钟行动证据。' : completedRecord.lockScreenSentence.trim(),
          widgetText: completedRecord.lockScreenSentence.trim().isEmpty ? '先做一个 5 分钟行动证据。' : completedRecord.lockScreenSentence.trim(),
          benefitQuestion: completedRecord.benefitFinderQuestion.trim().isEmpty ? '这件事里，我还剩下哪个可控点？' : completedRecord.benefitFinderQuestion.trim(),
        );
      }
    }
    await _load();
  }

  Future<void> _dailyExtendCreateRealityWeeklyReport() async {
    final now = DateTime.now();
    final weekStart = _startOfDayMs(now.subtract(Duration(days: now.weekday - 1)));
    bool inThisWeekMs(Object? raw) {
      final ms = raw is num ? raw.toInt() : int.tryParse((raw ?? '').toString()) ?? 0;
      return ms >= weekStart;
    }
    final weekP2 = _p2Rows.where((row) => inThisWeekMs(row['created_at_ms']) || inThisWeekMs(row['completed_at_ms'])).toList(growable: false);
    final actionCount = weekP2.where((row) => (row['artifact_type'] ?? '').toString() == 'todo_goal_bridge').length;
    final completedCount = _actionEvidenceRows.where((e) => e.completed && (e.completedAtMs ?? e.createdAtMs) >= weekStart).length;
    final failedCount = _failureRows.where((row) => inThisWeekMs(row['created_at_ms'])).length;
    final primeCount = _primeRows.where((row) => inThisWeekMs(row['created_at_ms'])).length;
    final antiPrimeCount = _antiPrimeRows.where((row) => inThisWeekMs(row['created_at_ms'])).length;
    final reviewCount = weekP2.where((row) => (row['artifact_type'] ?? '').toString() == 'daily_review' && (row['status'] ?? '').toString() == 'completed').length;
    final gratitudeCount = _records.where((r) => r.scene == 'daily_review' || r.scene == 'gratitude_savoring').where((r) => r.createdAtMs >= weekStart).length;
    final report = '本周日常闭环真实聚合：\n'
        '1. 待办事项转 5 分钟行动：$actionCount 个。\n'
        '2. 已完成并回流为行动证据：$completedCount 个。\n'
        '3. 未完成并转入失败免疫：$failedCount 个。\n'
        '4. 注意力启动线索：$primeCount 个，消极启动源清理：$antiPrimeCount 个。\n'
        '5. 已完成晚间复盘：$reviewCount 个，感恩/品味相关记录：$gratitudeCount 个。\n\n'
        '下周只练一个重点：每天只把一个未完成任务缩成 5 分钟行动，并在晚上回流为证据或失败免疫。';
    await _dao.upsertDailyExtensionArtifact(
      artifactType: 'monthly_report',
      title: '真实数据周报：日常闭环',
      triggerText: '来自日常闭环真实聚合',
      triggerCondition: '每周复盘',
      summary: report,
      reuseSurface: '周报 / 复盘 / 下周重点',
      nextAction: '下周只追踪一个未完成任务是否能缩成 5 分钟行动。',
      sourceType: 'daily_extension_aggregate',
      sourceId: DateTime.now().toIso8601String().substring(0, 10),
      targetType: 'report',
      status: 'completed',
      completedAtMs: DateTime.now().millisecondsSinceEpoch,
      safetyLevel: _latestSafetyLevel(),
      timezone: await _preferredTodoTimeZone(),
      content: <String, Object?>{
        'todo_bridge_count': actionCount,
        'completed_count': completedCount,
        'failed_count': failedCount,
        'prime_count': primeCount,
        'anti_prime_cleanup_count': antiPrimeCount,
        'review_count': reviewCount,
        'gratitude_or_savoring_count': gratitudeCount,
        'report': report,
        'core_value': '周报必须基于真实行动、提醒、完成和失败回流，而不是凭空生成。',
      },
    );
    await _load();
    _toast('已基于真实日常闭环数据生成周报。');
  }

  Future<void> _dailyExtendTodoIntoAction() async {
    try {
      final safetyLevel = _latestSafetyLevel();
      if (_isHighSafetyLevel(safetyLevel)) {
        await _createSafetySupportDailyArtifact(safetyLevel);
        return;
      }
      final tasks = await _todoDao.listTasks('smart_myday', limit: 24);
      final task = await _chooseOpenTodoTask(tasks);
      if (task == null) {
        _toast('今天没有选择未完成待办事项。可以先从“看清现实”记录一件真实发生的事。');
        DefaultTabController.of(context).animateTo(1);
        return;
      }
      final existing = await _dao.findOpenDailyExtensionBySource(
        artifactType: 'todo_goal_bridge',
        sourceType: 'todo_task',
        sourceId: task.taskId,
      );
      if (existing != null) {
        _toast('这个待办事项已经转成日常实践行动，不重复创建。请先同步执行结果或查看最近产物。');
        return;
      }
      final action = '今天先做 5 分钟：打开「${task.title}」相关材料，完成第一个小动作，不要求完成整个任务。';
      final sourceNote = task.bodyText.trim().isEmpty ? '' : '原备注：${task.bodyText.trim()}\n';
      final listId = await _dailyExtensionListId();
      final tz = await _preferredTodoTimeZone();
      final scheduledAt = DateTime.now().millisecondsSinceEpoch;
      final scheduledDate = DateTime.now();
      final dueIso = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day).toIso8601String();
      final newTaskId = await _todoDao.createLocalTask(
        listId: listId,
        title: '今日 5 分钟行动：${_shortActionTitle(task.title, max: 22)}',
        bodyText: '来自“日常闭环”的待办事项转行动。\n\n原待办事项：${task.title}\n$sourceNote\n训练逻辑：未完成不是人格判决；先允许情绪，再区分事实和解释，然后把行动缩小到可执行。\n\n5 分钟行动：$action\n\n如果-那么：如果今天又想逃避，就只打开材料 2 分钟，并记录卡点。\n完成标准：只要开始并留下一个行动痕迹，就算完成。\n\n回流规则：完成后回到“日常”页点击“我完成了”，会沉淀为行动证据；没完成则点击“没完成，帮我拆小”，进入失败免疫。',
        status: 'notStarted',
        importance: task.importance == 'high' ? 'high' : 'normal',
        isMyDay: true,
        dueDateTime: dueIso,
        dueTimeZone: tz,
        startTimeZone: tz,
      );
      await _dao.upsertDailyExtensionArtifact(
        artifactType: 'todo_goal_bridge',
        title: '待办事项转今日 5 分钟行动',
        triggerText: task.title,
        triggerCondition: '今日待办事项未完成或拖延',
        summary: '把未完成待办事项从“我不行”的人格判断，转成今天可启动的 5 分钟行动。',
        reuseSurface: '待办事项 / 我的今天 / 今日行动',
        nextAction: action,
        sourceType: 'todo_task',
        sourceId: task.taskId,
        targetType: 'todo_task',
        targetId: newTaskId,
        status: 'scheduled',
        scheduledAtMs: scheduledAt,
        safetyLevel: safetyLevel,
        timezone: tz,
        content: <String, Object?>{
          'source_task_id': task.taskId,
          'generated_task_id': newTaskId,
          'source_task_title': task.title,
          'source_list': task.listDisplayName,
          'five_minute_action': action,
          'if_then': '如果今天又想逃避，就只打开材料 2 分钟，并记录卡点。',
          'completion_standard': '只要开始并留下一个行动痕迹，就算完成。',
          'completion_scope': 'micro_action',
          'source_task_completion_policy': '完成 5 分钟训练待办事项不等于完成原始大任务；只记录一次真实推进。',
          'core_value': '行动证据优先于口号；未完成进入缩小行动，而不是人格失败。',
        },
      );
      await _load();
      _toast('已建立待办事项桥接：原任务 → 今日 5 分钟行动 → 执行回流。');
    } catch (e) {
      _toast('待办事项转行动失败：$e');
    }
  }

  Future<void> _dailyExtendCreateEveningReview() async {
    try {
      final safetyLevel = _latestSafetyLevel();
      if (_isHighSafetyLevel(safetyLevel)) {
        await _createSafetySupportDailyArtifact(safetyLevel);
        return;
      }
      final latest = _records.isNotEmpty ? _records.first : null;
      final latestSession = _openSessions.isNotEmpty ? _openSessions.first : null;
      final event = latest?.eventSummary.trim().isNotEmpty == true
          ? latest!.eventSummary
          : latestSession?.eventText.trim().isNotEmpty == true
              ? latestSession!.eventText
              : '今天最需要复盘的一件真实事件';
      final action = latest?.fiveMinuteAction.trim().isNotEmpty == true
          ? latest!.fiveMinuteAction
          : latestSession?.actionText.trim().isNotEmpty == true
              ? latestSession!.actionText
              : '写下一个明天 5 分钟能开始的小动作';
      final identity = latest?.identitySentence.trim().isNotEmpty == true
          ? latest!.identitySentence
          : latestSession?.identityText.trim().isNotEmpty == true
              ? latestSession!.identityText
              : '我正在成为一个能复盘、能缩小行动、能重新开始的人。';
      final prime = latest?.lockScreenSentence.trim().isNotEmpty == true
          ? latest!.lockScreenSentence
          : latestSession?.primeText.trim().isNotEmpty == true
              ? latestSession!.primeText
              : '先做一个 5 分钟行动证据，不等状态完美。';
      final now = DateTime.now();
      final dateText = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final scheduledAt = DateTime(now.year, now.month, now.day, 20).millisecondsSinceEpoch;
      final body = '今晚 8 分钟现实主义乐观复盘（$dateText）\n\n1. 真实事件：$event\n2. 我脑中的解释：有没有永久化、普遍化、人格化、灾难化、无力化或过滤化？\n3. 今天的行动证据：$action\n4. 如果没完成：卡点是什么？下一步如何缩小到 2 分钟？\n5. 今天仍值得珍惜的一点：写具体的人、物、画面或关系。\n6. 身份沉淀：$identity\n7. 明日注意力启动线索：$prime\n\n完成复盘时请回到本模块“打开真实复盘流程”，让结果写入感恩、注意力启动线索、身份和失败免疫。';
      final listId = await _dailyExtensionListId();
      final tz = await _preferredTodoTimeZone();
      await _supersedeOpenDailyArtifactsAndPauseTodos('daily_review');
      final taskId = await _todoDao.createLocalTask(
        listId: listId,
        title: '今晚 8 分钟复盘：把今天沉淀成证据',
        bodyText: body,
        status: 'notStarted',
        importance: 'normal',
        isMyDay: true,
        isReminderOn: true,
        reminderDateTime: DateTime.fromMillisecondsSinceEpoch(scheduledAt).toUtc().toIso8601String(),
        reminderTimeZone: tz,
        dueTimeZone: tz,
        startTimeZone: tz,
      );
      await _dao.upsertDailyExtensionArtifact(
        artifactType: 'daily_review',
        title: '今晚复盘清单',
        triggerText: event,
        triggerCondition: '每天晚上或一次核心训练之后',
        summary: '把今天的事件、解释、行动、未完成卡点、感恩、注意力启动线索和身份沉淀到同一张复盘清单。',
        reuseSurface: '待办事项 / 晚间复盘 / 首页提醒',
        nextAction: '今晚用 8 分钟完成复盘；完成后回到模块打开真实复盘流程。',
        sourceType: latestSession != null ? 'session' : latest != null ? 'record' : 'manual',
        sourceId: latestSession?.id ?? latest?.id ?? dateText,
        targetType: 'todo_task',
        targetId: taskId,
        status: 'scheduled',
        scheduledAtMs: scheduledAt,
        safetyLevel: safetyLevel,
        timezone: tz,
        content: <String, Object?>{
          'review_task_id': taskId,
          'review_body': body,
          'event': event,
          'action': action,
          'identity': identity,
          'prime': prime,
          'core_value': '感恩不是否认痛苦；身份由行动、恢复和复盘证据积累。',
        },
      );
      await _load();
      _toast('已创建今晚复盘提醒，并可回到模块完成真实复盘。');
    } catch (e) {
      _toast('创建今晚复盘失败：$e');
    }
  }

  Future<void> _dailyExtendSetTomorrowPrime() async {
    try {
      final safetyLevel = _latestSafetyLevel();
      if (_isHighSafetyLevel(safetyLevel)) {
        await _createSafetySupportDailyArtifact(safetyLevel);
        return;
      }
      final latest = _records.isNotEmpty ? _records.first : null;
      final latestSession = _openSessions.isNotEmpty ? _openSessions.first : null;
      final action = latest?.fiveMinuteAction.trim().isNotEmpty == true
          ? latest!.fiveMinuteAction
          : latestSession?.actionText.trim().isNotEmpty == true
              ? latestSession!.actionText
              : '打开最重要任务的材料，做 5 分钟。';
      final prime = latest?.lockScreenSentence.trim().isNotEmpty == true
          ? latest!.lockScreenSentence
          : latestSession?.primeText.trim().isNotEmpty == true
              ? latestSession!.primeText
              : '先开始 5 分钟，不等完美状态。';
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final scheduledAt = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0).millisecondsSinceEpoch;
      final remindAt = DateTime.fromMillisecondsSinceEpoch(scheduledAt).toUtc().toIso8601String();
      final tz = await _preferredTodoTimeZone();
      final body = '明日注意力启动线索：$prime\n\n触发条件：早上看到待办事项或开始自责/拖延时。\n资源发现问题：这件事里，我还剩下哪个可控点？\n5 分钟行动：$action\n环境线索：把这个提醒放在待办事项、锁屏、小组件或桌面显眼位置。\n\n如果连续忽略，请回到“日常”页点击“没完成，帮我拆小”，系统会把行动缩小。';
      final listId = await _dailyExtensionListId();
      await _supersedeOpenDailyArtifactsAndPauseTodos('proactive_reminder');
      final taskId = await _todoDao.createLocalTask(
        listId: listId,
        title: '明日注意力启动线索：${_shortActionTitle(prime, max: 26)}',
        bodyText: body,
        status: 'notStarted',
        importance: 'normal',
        isMyDay: true,
        isReminderOn: true,
        reminderDateTime: remindAt,
        reminderTimeZone: tz,
        dueTimeZone: tz,
        startTimeZone: tz,
      );
      await _dao.upsertDailyExtensionArtifact(
        artifactType: 'proactive_reminder',
        title: '明日注意力启动线索提醒',
        triggerText: prime,
        triggerCondition: '明天早上或再次进入拖延/自责时',
        summary: '把训练结果变成明天真实环境中的启动线索，而不是停留在一次分析。',
        reuseSurface: '待办事项提醒 / 锁屏 / 小组件 / 桌面线索',
        nextAction: action,
        sourceType: latestSession != null ? 'session' : latest != null ? 'record' : 'manual',
        sourceId: latestSession?.id ?? latest?.id ?? prime,
        targetType: 'todo_task',
        targetId: taskId,
        status: 'scheduled',
        scheduledAtMs: scheduledAt,
        safetyLevel: safetyLevel,
        timezone: tz,
        content: <String, Object?>{
          'prime_task_id': taskId,
          'prime': prime,
          'benefit_question': '这件事里，我还剩下哪个可控点？',
          'five_minute_action': action,
          'reminder_at_utc': remindAt,
          'timezone': tz,
          'anti_prime_followup': '如果连续忽略，就降低频率或把行动缩小到 2 分钟。',
          'core_value': '注意力会塑造体验现实；用环境线索支持行动。',
        },
      );
      await _dao.addAttentionPrime(
        id: 'rot_daily_tomorrow_prime_${taskId.hashCode.abs()}',
        recordId: latest?.id ?? '',
        valueWord: latest?.dailyValueWord.trim().isNotEmpty == true ? latest!.dailyValueWord.trim() : '开始',
        reminder: prime,
        widgetText: prime,
        benefitQuestion: '这件事里，我还剩下哪个可控点？',
        antiPrimeCleanupAction: '如果连续忽略，就把行动缩小到 2 分钟。',
      );
      await _load();
      _toast('已创建明日注意力启动线索提醒，并保存时区与目标待办事项。');
    } catch (e) {
      _toast('创建 注意力启动线索 提醒失败：$e');
    }
  }


  Future<void> _dailyCreateTinyAntiPrimeCleanup() async {
    final triggerCtrl = TextEditingController(text: '睡前短视频 / 首页社交应用 / 让我比较的人或内容');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('今天只清理一个消极启动源'),
        content: TextField(
          controller: triggerCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '今天最容易启动拖延、比较、自责或无力感的东西是什么？',
            hintText: '例如：睡前短视频、首页社交应用、某类比较内容、混乱桌面',
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('生成清理动作')),
        ],
      ),
    );
    final userTrigger = triggerCtrl.text.trim();
    triggerCtrl.dispose();
    if (ok != true) return;
    try {
      final safetyLevel = _latestSafetyLevel();
      if (_isHighSafetyLevel(safetyLevel)) {
        await _createSafetySupportDailyArtifact(safetyLevel);
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final trigger = userTrigger.isEmpty ? '最容易拖延的应用或入口' : userTrigger;
      final cleanup = '今天只清理一个消极启动源：把“$trigger”的接触门槛提高一步，例如移出首页、关闭提醒、放远手机，或把它替换成一个 5 分钟行动入口。';
      final replacement = '替代线索：在原来打开“$trigger”的位置，放一句“先做 5 分钟，不评价质量”。';
      await _dao.addAntiPrimeCleanup(
        id: 'rot_daily_antiprime_${DateTime.now().toIso8601String().substring(0, 10).hashCode.abs()}_${trigger.hashCode.abs()}',
        triggerType: '应用 / 内容 / 人物 / 环境',
        triggerName: trigger,
        effect: '容易启动比较、拖延、自责或无力感。',
        cleanupAction: cleanup,
        replacementPrime: replacement,
      );
      await _supersedeOpenDailyArtifactsAndPauseTodos('anti_prime_cleanup');
      await _dao.upsertDailyExtensionArtifact(
        artifactType: 'anti_prime_cleanup',
        title: '今日最小环境清理',
        triggerText: trigger,
        triggerCondition: '今天感到拖延、比较或无力时',
        summary: '不只添加注意力启动线索，也清理一个会启动拖延、比较或自责的入口。',
        reuseSurface: '环境页 / 今日闭环 / 桌面线索',
        nextAction: cleanup,
        sourceType: 'daily_cockpit',
        sourceId: DateTime.now().toIso8601String().substring(0, 10),
        targetType: 'environment_cleanup',
        targetId: 'daily_antiprime_$now',
        status: 'completed',
        completedAtMs: now,
        safetyLevel: safetyLevel,
        timezone: await _preferredTodoTimeZone(),
        content: <String, Object?>{
          'trigger': trigger,
          'cleanup_action': cleanup,
          'replacement_prime': replacement,
          'core_value': '注意力会塑造体验现实；清理消极启动源和设置启动线索同样重要。',
        },
      );
      await _load();
      _toast('已写入环境页：今天只清理一个最强消极启动源。');
    } catch (e) {
      _toast('环境清理失败：$e');
    }
  }


  Future<void> _dailyExtendOpenManualTodoBridge() async {
    await _openGuidedFlow('todo_goal_bridge', '我有一个任务没有完成：${_inputCtrl.text.trim().isEmpty ? _defaultProblemTemplate : _inputCtrl.text.trim()}\n请带我完成情绪允许、事实解释分离、明日 5 分钟行动和失败免疫复盘。');
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空现实主义乐观训练数据？'),
        content: const Text('将删除本独立模块中的事件重构、行动证据、基线、感恩、注意力启动线索 与身份沉淀数据。旧的“现实乐观信念行动系统”不受影响。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok == true) {
      await _dao.clearAll();
      await _load();
      _toast('已清空本独立模块数据');
    }
  }

  Future<void> _recordBaseline() async {
    double happiness = 6;
    double recovery = 5;
    double agency = 5;
    double permanence = 5;
    double gratitude = 5;
    double action = 5;
    final noteCtrl = TextEditingController(text: '这周我发现：失败后的恢复比上周快了一点，因为我更愿意把行动缩小。');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('记录本周幸福基线'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _DialogSlider(label: '总体幸福感', value: happiness, onChanged: (v) => setLocal(() => happiness = v)),
                _DialogSlider(label: '失败恢复能力', value: recovery, onChanged: (v) => setLocal(() => recovery = v)),
                _DialogSlider(label: '可影响生活程度', value: agency, onChanged: (v) => setLocal(() => agency = v)),
                _DialogSlider(label: '永久化解释频率', value: permanence, onChanged: (v) => setLocal(() => permanence = v)),
                _DialogSlider(label: '感恩敏感度', value: gratitude, onChanged: (v) => setLocal(() => gratitude = v)),
                _DialogSlider(label: '小行动稳定性', value: action, onChanged: (v) => setLocal(() => action = v)),
                TextField(
                  controller: noteCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '一句周报备注', hintText: '这周我恢复得更快/更慢，是因为……'),
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
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (ok == true) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _dao.addBaseline(RealisticOptimismTrainingBaseline(
        id: 'rot_b_$now',
        tsMs: now,
        happinessScore: happiness,
        recoveryScore: recovery,
        agencyScore: agency,
        permanenceFrequency: permanence,
        gratitudeSensitivity: gratitude,
        actionStability: action,
        note: note,
      ));
      await _load();
      _toast('已保存本周基线');
    }
  }

  Future<void> _generateWeeklyReport() async {
    final input = _baselines.isEmpty
        ? '请基于最近训练记录生成现实主义乐观周报。'
        : '请基于最近幸福基线、行动证据、解释风格和感恩记录生成现实主义乐观周报。';
    setState(() {
      _scene = 'weekly_baseline';
      _generating = true;
    });
    try {
      final result = await _ai.generate(userInput: input, scene: 'weekly_baseline', extraContext: _recentContextJson());
      await _dao.upsertRecord(result.record);
      await _load();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RealisticOptimismTrainingDetailPage(record: result.record)));
      _load();
    } catch (e) {
      _toast('生成周报失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }



  Future<void> _generateAttentionEnvironmentRecord({
    required String scene,
    required String input,
    required String successMessage,
  }) async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final result = await _ai.generate(
        userInput: input,
        scene: scene,
        extraContext: widget.extraContext.isEmpty ? _recentContextJson() : widget.extraContext,
      );
      await _dao.upsertRecord(result.record);
      await _load();
      if (!mounted) return;
      _toast(successMessage);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RealisticOptimismTrainingDetailPage(record: result.record)),
      );
      _load();
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _generateDailyAttentionCue() async {
    await _generateAttentionEnvironmentRecord(
      scene: 'prime_design',
      input: '请为今天生成注意力启动线索。要求包含：今日价值词、锁屏短句、小组件短句、一个可放进现实环境的照片/物品/便签/桌面线索、一个资源发现问题、一个今天能执行的行动线索。不要写英文术语，不要空泛鼓励。',
      successMessage: '已生成今日注意力启动线索',
    );
  }

  Future<void> _generateNegativeCueCleanup() async {
    await _generateAttentionEnvironmentRecord(
      scene: 'anti_prime_cleanup',
      input: '请为我生成消极启动源清理方案。要求识别最近最容易启动比较、拖延、自责或无力感的内容/应用/人物/场景；说明它造成的状态；给出今天只做一个的最小清理动作；再给出一个替代注意力启动线索。不要写英文术语，不要要求一次性改变全部环境。',
      successMessage: '已生成消极启动源清理方案',
    );
  }

  Future<void> _recordFailureRecoveryReview() async {
    if (_records.isEmpty) {
      _toast('请先生成一次训练记录，再记录失败恢复复盘。');
      return;
    }
    String selectedId = _records.first.id;
    double actualPain = 5;
    final resultCtrl = TextEditingController(text: '最坏结果没有完全发生，我只是暂时没有完成原计划，但写下了下一步。');
    final recoveryCtrl = TextEditingController(text: '例如：2小时后开始恢复一点行动力');
    final antibodyCtrl = TextEditingController(text: '我发现失败会痛，但不会定义整个人；我仍然能恢复一点主动性。');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('失败后实际恢复复盘'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              DropdownButtonFormField<String>(
                value: selectedId,
                decoration: const InputDecoration(labelText: '关联训练记录'),
                items: _records.take(20).map((r) => DropdownMenuItem(value: r.id, child: Text((r.eventSummary.isEmpty ? r.rawInput : r.eventSummary), maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setLocal(() => selectedId = v ?? selectedId),
              ),
              const SizedBox(height: 8),
              _DialogSlider(label: '实际痛苦程度', value: actualPain, onChanged: (v) => setLocal(() => actualPain = v)),
              TextField(controller: resultCtrl, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: '实际发生了什么', hintText: '最坏结果是否真的发生？')),
              TextField(controller: recoveryCtrl, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: '实际恢复时间/恢复信号')),
              TextField(controller: antibodyCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '心理抗体')),
            ]),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存复盘')),
          ],
        ),
      ),
    );
    final actualResult = resultCtrl.text.trim();
    final recovery = recoveryCtrl.text.trim();
    final antibody = antibodyCtrl.text.trim();
    resultCtrl.dispose();
    recoveryCtrl.dispose();
    antibodyCtrl.dispose();
    if (ok == true) {
      await _dao.addFailureRecoveryReview(recordId: selectedId, actualPain: actualPain, actualRecovery: recovery, psychologicalAntibody: antibody, actualResult: actualResult);
      await _load();
      _toast('已沉淀失败恢复复盘');
    }
  }

  Future<void> _recordChallengeReview() async {
    final challengeRecords = _records.where((r) => r.scene == 'controlled_failure_challenge').toList(growable: false);
    if (challengeRecords.isEmpty) {
      _toast('请先生成一个“可控失败挑战”，再记录执行后复盘。');
      return;
    }
    String selectedId = challengeRecords.first.id;
    double actualPain = 5;
    final resultCtrl = TextEditingController(text: '我提交了不完美版本，对方没有像我想象中那样否定我。');
    final recoveryCtrl = TextEditingController(text: '例如：30分钟后情绪下降，晚上可以继续做事');
    final lessonCtrl = TextEditingController(text: '我学到：低风险的不完美暴露可以训练恢复，而不是证明我很差。');
    final antibodyCtrl = TextEditingController(text: '我可以承受低风险的不完美暴露，最坏结果通常没有想象中巨大。');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('可控失败挑战执行后复盘'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              DropdownButtonFormField<String>(
                value: selectedId,
                decoration: const InputDecoration(labelText: '选择挑战'),
                items: challengeRecords.map((r) => DropdownMenuItem(value: r.id, child: Text((r.eventSummary.isEmpty ? r.rawInput : r.eventSummary), maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setLocal(() => selectedId = v ?? selectedId),
              ),
              const SizedBox(height: 8),
              _DialogSlider(label: '实际痛苦程度', value: actualPain, onChanged: (v) => setLocal(() => actualPain = v)),
              TextField(controller: resultCtrl, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: '实际结果', hintText: '被拒绝了吗？不完美暴露后发生了什么？')),
              TextField(controller: recoveryCtrl, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: '恢复时间/恢复信号')),
              TextField(controller: lessonCtrl, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: '学到什么')),
              TextField(controller: antibodyCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '心理抗体')),
            ]),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存挑战复盘')),
          ],
        ),
      ),
    );
    final actualResult = resultCtrl.text.trim();
    final recovery = recoveryCtrl.text.trim();
    final lesson = lessonCtrl.text.trim();
    final antibody = antibodyCtrl.text.trim();
    resultCtrl.dispose();
    recoveryCtrl.dispose();
    lessonCtrl.dispose();
    antibodyCtrl.dispose();
    if (ok == true) {
      await _dao.updateControlledChallengeReview(recordId: selectedId, actualPain: actualPain, actualResult: actualResult, recoveryTime: recovery, lesson: lesson, psychologicalAntibody: antibody);
      await _load();
      _toast('已保存可控失败挑战复盘');
    }
  }

  Future<void> _recordRelationshipGratitude() async {
    final personCtrl = TextEditingController(text: '朋友');
    final contextCtrl = TextEditingController(text: '上次我低落时，你没有急着评价我，而是陪我把事情说清楚。');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关系感恩表达'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            TextField(controller: personCtrl, decoration: const InputDecoration(labelText: '感谢对象', hintText: '例如：妈妈 / 朋友 / 过去的自己')),
            TextField(controller: contextCtrl, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: '具体感谢的事情', hintText: '对方做过什么？为什么重要？')),
          ]),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('生成并保存')),
        ],
      ),
    );
    final person = personCtrl.text.trim().isEmpty ? '你' : personCtrl.text.trim();
    final contextText = contextCtrl.text.trim().isEmpty ? '你之前给过我的支持' : contextCtrl.text.trim();
    personCtrl.dispose();
    contextCtrl.dispose();
    if (ok == true) {
      final light = '$person，今天想到你之前帮我的那件事，还是想说谢谢。';
      final concrete = '$person，$contextText。这对我很重要，我没有把它当成理所当然。谢谢你。';
      final deep = '$person，我以前可能没有认真表达过，但$contextText，让我感到被支持、被看见。我想让你知道，我记得，也很珍惜。';
      await _dao.addRelationshipGratitude(person: person, context: contextText, lightText: light, concreteText: concrete, deepText: deep, chosenAction: '可以发送、保存不发，或设为稍后表达。');
      await _load();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('已生成三种表达'),
          content: SingleChildScrollView(child: Text('轻量版：\n$light\n\n具体版：\n$concrete\n\n深度版：\n$deep')),
          actions: <Widget>[FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('完成'))],
        ),
      );
    }
  }



  static const String _defaultProblemTemplate = '今天我又没有推进重要任务，越拖越自责，担心自己永远坚持不了。';

  static const List<String> _problemScenarios = <String>[
    '拖延 / 没开始',
    '失败 / 没做好',
    '被批评 / 被否定',
    '关系不舒服',
    '焦虑 / 低落',
    '不知道下一步',
  ];

  static const Map<String, String> _problemTemplates = <String, String>{
    '拖延 / 没开始': '今天我又没有推进重要任务，越拖越自责，担心自己永远坚持不了。',
    '失败 / 没做好': '今天一件重要的事没有做好，我很怕这说明我不行，也不知道下次该怎么调整。',
    '被批评 / 被否定': '今天有人批评了我，我一直反复想，担心这说明我真的很差。',
    '关系不舒服': '今天和一个人的互动让我很难受，我担心关系变糟，也不知道该不该解释。',
    '焦虑 / 低落': '今天我状态很低，什么都不太想做，但又担心自己一直这样下去。',
    '不知道下一步': '我现在说不清具体问题，只觉得很乱、很累、很无力，不知道下一步做什么。',
  };

  static const Map<String, String> _problemScenes = <String, String>{
    '拖延 / 没开始': 'process_action',
    '失败 / 没做好': 'failure_immunity',
    '被批评 / 被否定': 'event_reframe',
    '关系不舒服': 'event_reframe',
    '焦虑 / 低落': 'emotion_container',
    '不知道下一步': 'emotion_container',
  };

  void _applyProblemScenario(String scenario) {
    setState(() {
      _problemScenario = scenario;
      _scene = _problemScenes[scenario] ?? 'event_reframe';
      _inputCtrl.text = _problemTemplates[scenario] ?? _defaultProblemTemplate;
    });
  }

  Future<void> _openGuidedFlow(String scene, String template, {RealisticOptimismTrainingSession? session}) async {
    final extra = widget.extraContext.isEmpty ? _recentContextJson() : widget.extraContext;
    final record = await Navigator.of(context).push<RealisticOptimismTrainingRecord>(
      MaterialPageRoute(
        builder: (_) => RotCoreBusinessFlowPage(
          initialScene: scene,
          initialText: template,
          extraContext: extra,
          session: session,
        ),
      ),
    );
    if (record != null && mounted) {
      await _load();
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RealisticOptimismTrainingDetailPage(record: record)));
      await _load();
    } else {
      await _load();
    }
  }

  Future<void> _openRealityRecordFlow([String initialText = '']) async {
    final extra = widget.extraContext.isEmpty ? _recentContextJson() : widget.extraContext;
    final record = await Navigator.of(context).push<RealisticOptimismTrainingRecord>(
      MaterialPageRoute(
        builder: (_) => RealisticOptimismEventWizardPage(
          initialText: initialText.trim().isEmpty ? _inputCtrl.text.trim() : initialText.trim(),
          extraContext: extra,
        ),
      ),
    );
    if (record != null && mounted) {
      await _load();
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RealisticOptimismTrainingDetailPage(record: record)));
      await _load();
    } else {
      await _load();
    }
  }


  Future<void> _continueSession(RealisticOptimismTrainingSession session) async {
    await _openGuidedFlow(session.initialScene, session.eventText, session: session);
  }

  Future<void> _abandonSession(RealisticOptimismTrainingSession session) async {
    await _dao.abandonSession(session.id);
    await _load();
    _toast('已放弃这条未完成训练草稿。');
  }

  void _showPromptSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AiPromptSettingsPage(
          initialModuleId: 'realistic_optimism_training',
          initialPromptId: 'rot_global',
        ),
      ),
    );
  }

  String _recentContextJson() {
    final recent = _records.take(8).map((r) => <String, Object?>{
      'scene': r.scene,
      'level': r.intensityLevel,
      'main_pattern': r.mainPattern,
      'action': r.fiveMinuteAction,
      'identity': r.identitySentence,
      'created_at_ms': r.createdAtMs,
    }).toList(growable: false);
    final baselines = _baselines.take(4).map((b) => <String, Object?>{
      'happiness': b.happinessScore,
      'recovery': b.recoveryScore,
      'agency': b.agencyScore,
      'permanence': b.permanenceFrequency,
      'gratitude': b.gratitudeSensitivity,
      'action': b.actionStability,
      'note': b.note,
      'ts_ms': b.tsMs,
    }).toList(growable: false);
    final openSessions = _openSessions.take(3).map((session) => <String, Object?>{
      'status': session.status,
      'step': session.currentStep,
      'level': session.level,
      'emotion': session.emotion,
      'event': session.eventText,
      'action': session.actionText,
      'updated_at_ms': session.updatedAtMs,
    }).toList(growable: false);
    return jsonEncode(<String, Object?>{'recent_records': recent, 'recent_baselines': baselines, 'open_sessions': openSessions});
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 8,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('现实问题训练'),
          actions: <Widget>[
            IconButton(tooltip: '智能提示词统一配置中心', onPressed: _showPromptSheet, icon: const Icon(Icons.psychology_alt_outlined)),
            IconButton(tooltip: '记录幸福基线', onPressed: _recordBaseline, icon: const Icon(Icons.timeline_outlined)),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'clear') _clearAll();
              },
              itemBuilder: (_) => const <PopupMenuItem<String>>[
                PopupMenuItem<String>(value: 'clear', child: Text('清空本模块数据')),
              ],
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: '开始'),
              Tab(text: '看清现实'),
              Tab(text: '记录'),
              Tab(text: '证据'),
              Tab(text: '周报'),
              Tab(text: '环境'),
              Tab(text: '日常'),
              Tab(text: '高级'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: <Widget>[
                  _dashboardTab(theme),
                  _workbenchTab(theme),
                  _recordsTab(theme),
                  _evidenceTab(theme),
                  _baselineTab(theme),
                  _environmentExpressionTab(theme),
                  _p2DeliveryTab(theme),
                  _blueprintTab(theme),
                ],
              ),
      ),
    );
  }

  Widget _dashboardTab(ThemeData theme) {
    final latest = _records.isNotEmpty ? _records.first : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        _HeroPanel(
          title: '把现实看完整：坏的是真的，但不是全部',
          subtitle: '这里不是劝你想开，而是陪你记录真实、承认痛苦、看清解释、保留可控点，并带着难受做一个勇气出马动作。',
          actionText: '记录一件真实发生的事',
          onPressed: () => _openRealityRecordFlow(),
        ),
        const SizedBox(height: 12),
        _OpenSessionsCard(
          sessions: _openSessions,
          onContinue: _continueSession,
          onAbandon: _abandonSession,
        ),
        const SizedBox(height: 12),
        const RotCoreValueGuideCard(
          title: '本模块的核心价值环境',
          body: RotCoreValueCopy.environmentBody,
          icon: Icons.tips_and_updates_outlined,
        ),
        const SizedBox(height: 12),
        const RotCoreValueGuideCard(
          title: RotCoreValueCopy.researchAnchorsTitle,
          body: RotCoreValueCopy.researchAnchorsBody,
          icon: Icons.science_outlined,
        ),
        const SizedBox(height: 12),
        _V7CockpitCard(
          onEvent: () => _openRealityRecordFlow(),
          onAction: () => _openGuidedFlow('process_action', '我的目标/任务是：推进今天一直拖延的学习/工作任务。'),
          onFailure: () => _openGuidedFlow('failure_immunity', ''),
          onEnvironment: () => _openGuidedFlow('prime_design', ''),
          onIdentity: () => _openGuidedFlow('identity_evidence', ''),
          latestAction: latest?.fiveMinuteAction ?? '',
          latestPrime: latest?.lockScreenSentence ?? '',
          latestIdentity: latest?.identitySentence ?? '',
        ),
        const SizedBox(height: 12),
        _IntensityDistributionCard(records: _records),
        const SizedBox(height: 12),
        _ProductGapFixCard(onStart: () => _openRealityRecordFlow()),
        const SizedBox(height: 12),
        const _BoundValueFlowCard(),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _MetricChip(label: '完成记录', value: '${_stats.records}'),
            _MetricChip(label: '未完成会话', value: '${_stats.openSessions}'),
            _MetricChip(label: '行动证据', value: '${_stats.actions}'),
            _MetricChip(label: '失败免疫', value: '${_stats.failureImmunity}'),
            _MetricChip(label: '注意力启动线索', value: '${_stats.primes}'),
            _MetricChip(label: '感恩', value: '${_stats.gratitude}'),
            _MetricChip(label: '身份', value: '${_stats.identity}'),
          ],
        ),
        const SizedBox(height: 14),
        if (latest != null) _LatestRecordCard(record: latest, onOpen: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RealisticOptimismTrainingDetailPage(record: latest)))),
      ],
    );
  }

  Widget _workbenchTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: <Widget>[
        const _InfoCard(
          icon: Icons.psychology_alt_outlined,
          title: '这个模块最重要的事',
          body: '先记录真实现实，再承认里面确实不好的部分；不粉饰、不鸡汤；然后看清痛苦解释，补全现实，最后做一个小到能开始的勇气出马动作。',
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          icon: Icons.flag_outlined,
          title: '完成后你会得到什么？',
          body: '你会得到：1）你记录的现实；2）它确实不好的地方；3）你当前的痛苦解释；4）更完整的现实；5）一个可控点；6）一个勇气出马动作；7）一句完整现实句。',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _openRealityRecordFlow(_inputCtrl.text.trim()),
          icon: const Icon(Icons.edit_note_outlined),
          label: const Text('记录一件真实发生的事'),
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          icon: Icons.visibility_outlined,
          title: '主线：现实记录 → 坏的承认 → 勇气出马',
          body: '下面的入口只是辅助。你不需要先理解课程机制；系统会根据你写下的现实自动调用心理免疫、过程模拟、启动源或完整现实感练习。',
        ),
        const SizedBox(height: 12),
        Text('辅助入口：按你现在的真实问题选择', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        _ModuleGrid(onSelect: (scene, template) => _openGuidedFlow(scene, template)),
        const SizedBox(height: 12),
        Text('课程机制练习：把案例和研究变成动作', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        _MechanismPracticeGrid(onSelect: (scene, template) => _openGuidedFlow(scene, template)),
        const SizedBox(height: 12),
        Text('也可以先选一个案例模板再改写', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _problemScenarios
              .map((scenario) => ChoiceChip(
                    label: Text(scenario),
                    selected: _problemScenario == scenario,
                    onSelected: (_) => _applyProblemScenario(scenario),
                  ))
              .toList(growable: false),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _inputCtrl,
          minLines: 5,
          maxLines: 10,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: '今天真实发生的事（可以直接改写）',
            helperText: '先写发生了什么，不用先积极，也不用先知道怎么解决。',
            hintText: '例如：今天我又没有推进重要任务，越拖越自责，担心自己永远坚持不了。',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _openRealityRecordFlow(_inputCtrl.text.trim()),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('按主线看清这件事'),
        ),
        const SizedBox(height: 12),
        const RotCoreValueGuideCard(
          title: '为什么这样训练？',
          body: '中心思想是：人不能控制所有外部事件，但可以通过解释方式、注意焦点、行动实践、环境启动和感恩训练，参与共同创造自己的心理现实。系统主轴是：解释塑造感受，注意塑造现实，行动塑造自我，感恩塑造世界观。',
          icon: Icons.lightbulb_outline,
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          leading: const Icon(Icons.tune_outlined),
          title: const Text('这些内部工具现在怎样工作？'),
          subtitle: const Text('不再让用户手动选择一大串工具；系统会在四个入口背后自动调用。'),
          childrenPadding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
          children: const <Widget>[
            _InfoCard(
              icon: Icons.security_outlined,
              title: '后台安全闸门',
              body: '事件强度分级会在训练开始时自动运行。L3/L4 会暂停普通重构、感恩和失败挑战，优先稳定与现实支持。',
            ),
            SizedBox(height: 8),
            _InfoCard(
              icon: Icons.radar_outlined,
              title: '后台诊断工具',
              body: '解释风格雷达、问题视角/资源视角 双镜头、事实-解释分离会作为“今日事件重构”的分析卡自动出现，不再要求普通用户先理解这些术语。',
            ),
            SizedBox(height: 8),
            _InfoCard(
              icon: Icons.badge_outlined,
              title: '后台结果生成器',
              body: '身份沉淀、行动证据会在用户完成或记录卡点后自动生成；它们是结果，不是起点。',
            ),
            SizedBox(height: 8),
            _InfoCard(
              icon: Icons.wallpaper_outlined,
              title: '已移动到其他页面的长期训练',
              body: '注意力启动线索与消极启动源 主要放在“环境”，感恩与品味放在“记录/晚上复盘”，幸福基线放在“周报”，避免挤在“看清现实”里。',
            ),
          ],
        ),
      ],
    );
  }

  Widget _recordsTab(ThemeData theme) {
    if (_records.isEmpty) {
      return const Center(child: Text('还没有现实记录，先从“看清现实”记录一件真实发生的事。'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: _records.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return const _InfoCard(
            icon: Icons.map_outlined,
            title: '我的现实地图',
            body: '这里不是普通训练记录列表，而是你一次次看清现实的地图：我承认过什么坏的现实，我识别过什么痛苦解释，我做过什么出马动作，我仍然珍惜过什么。',
          );
        }
        final item = _records[i - 1];
        return _RecordTile(
          record: item,
          onOpen: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RealisticOptimismTrainingDetailPage(record: item))),
          onDelete: () async {
            await _dao.deleteRecord(item.id);
            await _load();
          },
        );
      },
    );
  }

  Widget _evidenceTab(ThemeData theme) {
    final completedActions = _actionEvidenceRows.where((e) => e.completed).take(20).toList(growable: false);
    final unfinishedActions = _actionEvidenceRows.where((e) => !e.completed).take(20).toList(growable: false);
    final identityRecords = _records.where((r) => r.identitySentence.isNotEmpty).take(20).toList(growable: false);
    final gratitudeRecords = _records.where((r) => r.whatStillMatters.isNotEmpty || r.savoringPrompt.isNotEmpty).take(20).toList(growable: false);
    final primeRecords = _records.where((r) => r.dailyValueWord.isNotEmpty || r.antiPrimeCleanupAction.isNotEmpty).take(20).toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        const RotCoreValueGuideCard(
          title: '能力档案的核心价值',
          body: '身份不是口号，而是行动、恢复、珍惜和重新开始的证据积累。这里让用户反复看见自己不是被一次事件定义的人。',
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          icon: Icons.inventory_2_outlined,
          title: '能力证据墙：身份不是口号，而是证据积累',
          body: '这里把行动、自我效能、失败恢复、资源发现视角、感恩品味和 注意力启动线索与消极启动源 记录从训练闭环中抽取出来，帮助你看到“我做过、我恢复过、我珍惜过、我继续过”。',
        ),
        const SizedBox(height: 12),
        _IdentityTypeBreakdownCard(records: _records),
        const SizedBox(height: 12),
        _FailureImmunityInsightCard(failureRows: _failureRows, challengeRows: _challengeRows),
        const SizedBox(height: 12),
        _GratitudeSensitivityInsightCard(records: _records, relationshipRows: _relationshipRows),
        const SizedBox(height: 12),
        _EvidenceGroup(
          title: 'A. 我做成过 / 行动证据',
          empty: '暂无已完成行动证据。只有真正点击“记录行动证据”或完成闭环时，才会进入这里。',
          items: completedActions.map((e) => '${e.action}\n证据：${e.evidenceText}').toList(growable: false),
        ),
        _EvidenceGroup(
          title: 'A2. 我看见了卡点 / 未完成也能复盘',
          empty: '暂无未完成行动记录。未完成不会被当作“做成过”，而会进入失败免疫材料。',
          items: unfinishedActions.map((e) => '${e.action}\n卡点/证据：${e.evidenceText}').toList(growable: false),
        ),
        _EvidenceGroup(
          title: 'B. 我恢复过 / 失败免疫',
          empty: '暂无失败免疫记录。完成失败复盘或可控失败挑战后会出现在这里。',
          items: _records.where((r) => r.psychologicalAntibody.isNotEmpty).take(20).map((r) => '${r.psychologicalAntibody}\n下一步：${r.fiveMinuteAction}').toList(growable: false),
        ),
        _EvidenceGroup(
          title: 'C. 我能看见更多现实 / 资源发现视角',
          empty: '暂无 资源发现视角 重构记录。',
          items: _records.where((r) => r.balancedInterpretation.isNotEmpty).take(20).map((r) => '${r.balancedInterpretation}\n主模式：${r.mainPattern}').toList(growable: false),
        ),
        _EvidenceGroup(
          title: 'D. 我会珍惜 / 感恩与品味',
          empty: '暂无感恩品味记录。',
          items: gratitudeRecords.map((r) => '${r.whatStillMatters.join('、')}\n品味：${r.savoringPrompt}\n行动：${r.smallAppreciationAction}').toList(growable: false),
        ),
        _EvidenceGroup(
          title: 'E. 我在设计注意力环境 / 注意力启动线索 与 消极启动源',
          empty: '暂无注意力环境记录。',
          items: primeRecords.map((r) => '价值词：${r.dailyValueWord}\n提醒：${r.lockScreenSentence}\n清理：${r.antiPrimeCleanupAction}').toList(growable: false),
        ),
        _EvidenceGroup(
          title: 'F. 我正在成为什么样的人 / 身份沉淀',
          empty: '暂无身份沉淀记录。',
          items: identityRecords.map((r) => '${r.identityType}：${r.identitySentence}\n证明能力：${r.provedCapacity}').toList(growable: false),
        ),
      ],
    );
  }

  Widget _baselineTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        RotCoreValueGuideCard(
          title: RotCoreValueCopy.sceneTitle('weekly_baseline'),
          body: RotCoreValueCopy.sceneBody('weekly_baseline'),
          icon: Icons.show_chart_outlined,
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.show_chart_outlined,
          title: '幸福基线不是每天开心，而是恢复能力变强',
          body: '每周记录幸福感、恢复能力、可影响感、永久化频率、感恩敏感度和小行动稳定性。',
        ),
        const SizedBox(height: 12),
        _TrainingIndexCard(stats: _stats),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.icon(onPressed: _recordBaseline, icon: const Icon(Icons.add_chart_outlined), label: const Text('记录本周基线')),
            OutlinedButton.icon(onPressed: _generating ? null : _generateWeeklyReport, icon: const Icon(Icons.summarize_outlined), label: const Text('生成智能幸福基线周报')),
          ],
        ),
        const SizedBox(height: 12),
        if (_baselines.isEmpty) const Text('暂无基线记录。') else ..._baselines.map(_BaselineCard.new),
      ],
    );
  }

  Widget _environmentExpressionTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        const RotCoreValueGuideCard(
          title: '注意力环境建设的核心价值',
          body: '环境不是装饰，而是训练的外部脚手架：用注意力启动线索把注意力拉回价值和可控行动，用消极启动源清理来减少比较、拖延和无力感。',
          icon: Icons.wallpaper_outlined,
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.wallpaper_outlined,
          title: '注意力环境与关系表达管理台',
          body: '最终方案要求注意力启动线索、消极启动源清理、关系感谢表达不只生成一次，还要能被回看、复制、复用，并进入能力档案。这里集中管理这些可反复使用的现实线索。',
        ),
        const SizedBox(height: 12),
        _AttentionEnvironmentInsightCard(primeRows: _primeRows, antiPrimeRows: _antiPrimeRows),
        const SizedBox(height: 12),
        if (_generating) ...<Widget>[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
        ],
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          OutlinedButton.icon(
            onPressed: _generating ? null : _generateDailyAttentionCue,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('生成今日注意力启动线索'),
          ),
          OutlinedButton.icon(
            onPressed: _generating ? null : _generateNegativeCueCleanup,
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('生成消极启动源清理方案'),
          ),
          OutlinedButton.icon(onPressed: _recordRelationshipGratitude, icon: const Icon(Icons.volunteer_activism_outlined), label: const Text('新增关系感谢表达')),
        ]),
        const SizedBox(height: 12),
        _MapRowsGroup(
          title: '今日/历史注意力启动线索',
          empty: '暂无注意力启动线索。可通过上方按钮直接生成。',
          rows: _primeRows,
          fieldLabels: const <String, String>{'value_word': '价值词', 'reminder': '提醒语', 'widget_text': '小组件', 'benefit_question': '资源发现问题', 'anti_prime_cleanup_action': '清理动作'},
        ),
        _MapRowsGroup(
          title: '消极启动源清理记录',
          empty: '暂无消极启动源清理。',
          rows: _antiPrimeRows,
          fieldLabels: const <String, String>{'trigger_type': '类型', 'trigger_name': '触发源', 'effect': '影响', 'cleanup_action': '清理动作', 'replacement_prime': '替代注意力启动线索'},
        ),
        _RelationshipRowsGroup(rows: _relationshipRows),
      ],
    );
  }


  Widget _p2DeliveryTab(ThemeData theme) {
    final dailyRows = _dailyCockpitRows();
    final actionRow = _latestDailyActionArtifact(rows: dailyRows);
    final reviewRow = _latestDailyArtifact('daily_review', statuses: <String>{'scheduled', 'active'}, rows: dailyRows) ?? _latestDailyArtifact('daily_review', rows: dailyRows);
    final cueRow = _latestDailyArtifact('proactive_reminder', statuses: <String>{'scheduled', 'active'}, rows: dailyRows) ?? _latestDailyArtifact('proactive_reminder', rows: dailyRows);
    final antiPrimeRow = _latestDailyArtifact('anti_prime_cleanup', rows: dailyRows);
    final highSafety = _isHighSafetyLevel(_latestSafetyLevel());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        const _InfoCard(
          icon: Icons.dashboard_customize_outlined,
          title: '每日实践层',
          body: '这里不是中心思想本身，也不是任务管理器；它只负责把今天的一个过程行动、今晚的一个真实复盘、明天的一条注意力线索串回 Lecture 7–9 的主轴。',
        ),
        const SizedBox(height: 12),
        const RotCoreValueGuideCard(
          title: '日常实践必须服务中心思想',
          body: '待办完成不是为了刷任务数量，而是为了形成自我效能证据；待办没完成不是人格失败，而是心理免疫材料；晚间复盘不是写日报，而是练习解释、注意、行动和感恩。',
          icon: Icons.sync_alt_outlined,
        ),
        const SizedBox(height: 12),
        if (_dailyBusy) ...<Widget>[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
        ],
        if (highSafety) ...<Widget>[
          _InfoCard(
            icon: Icons.health_and_safety_outlined,
            title: '当前进入稳定支持模式',
            body: '最近强度为 ${_latestSafetyLevel()}。日常闭环会暂停普通 5 分钟行动、失败挑战、强行感恩和普通提醒；现在只保留安全支持、稳定身体和现实支持。',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _dailyBusy ? null : () => _runDailyLocked(() => _createSafetySupportDailyArtifact(_latestSafetyLevel())),
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('创建稳定 / 安全支持行动'),
          ),
        ] else ...<Widget>[
          _DailyActionFocusCard(
            row: actionRow,
            onCreate: () => _runDailyLocked(_dailyExtendTodoIntoAction),
            onCompleted: () => _runDailyLocked(_dailyMarkLatestActionCompleted),
            onShrink: () => _runDailyLocked(_dailyShrinkLatestAction),
          ),
          const SizedBox(height: 12),
          _DailyReviewFocusCard(
            row: reviewRow,
            onCreate: () => _runDailyLocked(_dailyExtendCreateEveningReview),
            onStart: () => _runDailyLocked(_dailyExtendOpenEveningReviewFlow),
          ),
          const SizedBox(height: 12),
          _DailyCueFocusCard(
            row: cueRow,
            onCreate: () => _runDailyLocked(_dailyExtendSetTomorrowPrime),
            onOpenEnvironment: _goToEnvironmentTab,
          ),
          const SizedBox(height: 12),
          _DailyAntiPrimeCleanupCard(
            row: antiPrimeRow,
            onCreate: () => _runDailyLocked(_dailyCreateTinyAntiPrimeCleanup),
            onOpenEnvironment: _goToEnvironmentTab,
          ),
        ],
        const SizedBox(height: 12),
        _DailyExtensionStatusCard(rows: dailyRows),
        const SizedBox(height: 12),
        _DailyFriendlyArtifactsList(rows: dailyRows),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _goToWeeklyTab,
              icon: const Icon(Icons.insights_outlined),
              label: const Text('去周报看趋势'),
            ),
            OutlinedButton.icon(
              onPressed: _goToAdvancedTab,
              icon: const Icon(Icons.tune_outlined),
              label: const Text('查看高级工具'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _blueprintTab(ThemeData theme) {
    final items = <Map<String, String>>[
      {'title': '1. 事件强度分级', 'body': 'L1/L2/L3/L4，决定当前能否进行 资源发现、感恩或失败复盘。'},
      {'title': '2. 允许自己为人', 'body': '在重构之前先承认痛苦、羞耻、失望、愤怒与拖延。'},
      {'title': '3. 解释风格雷达', 'body': '永久化、普遍化、人格化、灾难化、无力化、过滤化。'},
      {'title': '4. 问题放大视角 / 资源发现视角', 'body': '同一现实双镜头：不是说坏事是好事，而是寻找仍然存在的资源和可行动性。'},
      {'title': '5. 过程模拟行动器', 'body': '结果画面 + 时间地点工具 + 第一步 + 障碍预演 + 如果-那么 + 5分钟行动。'},
      {'title': '6. 失败免疫实验室', 'body': '预测痛苦 vs 实际痛苦，预测恢复 vs 实际恢复，沉淀心理抗体，并支持执行后补录复盘。'},
      {'title': '7. 可控失败挑战', 'body': '低风险承受不完美、拒绝、暴露和不确定性，并支持挑战执行后复盘。'},
      {'title': '8. 注意力启动线索与消极启动源', 'body': '设计注意力启动墙，同时清理消极启动源。'},
      {'title': '9. 感恩、品味与关系表达', 'body': '具体感恩、30 秒品味练习，并生成轻量/具体/深度三种关系表达。'},
      {'title': '10. 幸福基线与身份', 'body': '不是追求永远开心，而是提高恢复能力；身份来自行动、恢复、注意和感恩的证据积累。'},
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        const _HeroPanel(
          title: 'Lecture 7–9 现实主义乐观主轴',
          subtitle: '本模块必须围绕同一个中心：解释塑造感受，注意塑造现实，行动塑造自我，感恩塑造世界观。所有日常、提醒、周报和待办联动都只能服务这条主轴。',
        ),
        const SizedBox(height: 12),
        ...items.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InfoCard(icon: Icons.check_circle_outline, title: e['title']!, body: e['body']!),
            )),
        const SizedBox(height: 12),
        ExpansionTile(
          leading: const Icon(Icons.developer_mode_outlined),
          title: const Text('后台诊断沉淀（高级查看）'),
          subtitle: const Text('这些是系统自动生成的内部材料，不再放到“环境”或“看清现实”主界面里。'),
          children: <Widget>[
            _MapRowsGroup(
              title: '事件强度分级沉淀',
              empty: '暂无强度分级记录。',
              rows: _eventIntensityRows,
              fieldLabels: const <String, String>{'level': '等级', 'reason': '原因', 'allowed_interventions_json': '适合', 'blocked_interventions_json': '不适合'},
            ),
            _MapRowsGroup(
              title: '过程行动计划沉淀',
              empty: '暂无过程计划。',
              rows: _processPlanRows,
              fieldLabels: const <String, String>{'five_minute_action': '5分钟行动', 'next_three_steps_json': '三步', 'if_then_plan_json': '如果-那么'},
            ),
          ],
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          leading: const Icon(Icons.build_circle_outlined),
          title: const Text('高级工具与资料库'),
          subtitle: const Text('课程卡、榜样案例、手动同步和调试提醒不进入日常主界面；需要时在这里使用。'),
          childrenPadding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(onPressed: _dailyExtendOpenManualTodoBridge, icon: const Icon(Icons.edit_note_outlined), label: const Text('手动任务转训练')),
                OutlinedButton.icon(onPressed: () => _openGuidedFlow('course_card', '请生成一张课程知识卡：主题是解释风格 / 资源发现视角 / 失败免疫 / 注意力启动线索 / 感恩品味。'), icon: const Icon(Icons.menu_book_outlined), label: const Text('生成课程知识卡')),
                OutlinedButton.icon(onPressed: () => _openGuidedFlow('role_model_case', '请生成一个榜样案例：他/她如何经历失败、如何解释、如何恢复、如何行动，我今天能模仿哪一个最小动作？'), icon: const Icon(Icons.groups_outlined), label: const Text('生成榜样案例')),
                OutlinedButton.icon(onPressed: _copyLatestP2WidgetText, icon: const Icon(Icons.copy_outlined), label: const Text('复制锁屏/小组件文案')),
                OutlinedButton.icon(onPressed: _copyP2VoiceInputTemplate, icon: const Icon(Icons.mic_none_outlined), label: const Text('复制语音输入模板')),
                OutlinedButton.icon(onPressed: _sendLatestP2Reminder, icon: const Icon(Icons.notification_add_outlined), label: const Text('立即发送一条提醒')),
                OutlinedButton.icon(onPressed: () => _dailyExtendSyncExecutionResults(), icon: const Icon(Icons.sync_alt_outlined), label: const Text('手动检查待办回流')),
                OutlinedButton.icon(onPressed: _createTodoFromLatestP2Action, icon: const Icon(Icons.add_task_outlined), label: const Text('最近行动写回待办事项')),
              ],
            ),
            const SizedBox(height: 12),
            _P2ArtifactLibraryGroup(rows: _p2Rows),
            const SizedBox(height: 12),
            _P2DeliveryCoverageCard(
              rows: _p2Rows,
              onGenerate: (scene) => _openGuidedFlow(scene, _p2SceneTemplate(scene)),
            ),
          ],
        ),
      ],
    );
  }
}

class RealisticOptimismTrainingDetailPage extends StatefulWidget {
  final RealisticOptimismTrainingRecord record;
  const RealisticOptimismTrainingDetailPage({super.key, required this.record});

  @override
  State<RealisticOptimismTrainingDetailPage> createState() => _RealisticOptimismTrainingDetailPageState();
}

class _RealisticOptimismTrainingDetailPageState extends State<RealisticOptimismTrainingDetailPage> {
  final RealisticOptimismTrainingDao _dao = RealisticOptimismTrainingDao();
  final TodoDao _todoDao = TodoDao();
  bool _markingAction = false;
  List<RealisticOptimismTrainingActionEvidence> _actions = <RealisticOptimismTrainingActionEvidence>[];

  @override
  void initState() {
    super.initState();
    _loadActions();
  }

  Future<void> _loadActions() async {
    final list = await _dao.listActionEvidence(widget.record.id);
    if (mounted) setState(() => _actions = list);
  }


  Map<String, dynamic> _payloadMap(String key) {
    final raw = widget.record.payload[key];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  List<String> _payloadStringList(String mapKey, String fieldKey) {
    final raw = _payloadMap(mapKey)[fieldKey];
    if (raw is List) return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
    final text = (raw ?? '').toString().trim();
    return text.isEmpty ? <String>[] : <String>[text];
  }

  String _payloadText(String mapKey, String fieldKey) => (_payloadMap(mapKey)[fieldKey] ?? '').toString().trim();

  List<Widget> _realityCoreWidgets() => <Widget>[
        const RotCoreValueGuideCard(
          title: '现实记录主线',
          body: '这不是劝你想开，而是把现实看完整：坏的是真的，但不是全部；痛苦是真的，但我仍能出马一步。',
          icon: Icons.visibility_outlined,
        ),
        _KeyValue(label: '你记录的现实', value: _payloadText('reality_record', 'what_happened')),
        _KeyValue(label: '它确实不好的地方', value: _payloadText('reality_record', 'what_is_truly_bad')),
        _KeyValue(label: '不能被轻飘飘美化的部分', value: _payloadText('reality_record', 'not_to_be_beautified')),
        _KeyValue(label: '允许存在的情绪', value: _payloadText('reality_record', 'allowed_emotion')),
        _KeyValue(label: '身体感受', value: _payloadText('reality_record', 'body_signal')),
        _KeyValue(label: '当前痛苦解释', value: _payloadText('reality_record', 'pain_interpretation')),
        _BulletList(title: '即使如此仍然存在', items: _payloadStringList('reality_record', 'what_still_exists')),
        _KeyValue(label: '保留的可控点', value: _payloadText('reality_record', 'controllable_point')),
        _KeyValue(label: '勇气出马动作', value: _payloadText('reality_record', 'courage_action')),
        _KeyValue(label: '完整现实句', value: _payloadText('reality_record', 'complete_reality_sentence')),
      ];

  List<Widget> _mechanismWidgets(String scene) {
    switch (scene) {
      case 'complete_reality':
        return <Widget>[
          RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle(scene), body: RotCoreValueCopy.sceneBody(scene), icon: Icons.auto_awesome_outlined),
          _KeyValue(label: '我不否认的痛苦', value: _payloadText('complete_reality', 'pain_not_denied')),
          _KeyValue(label: '不能被轻飘飘美化的部分', value: _payloadText('complete_reality', 'not_beautified')),
          _BulletList(title: '即使如此，仍然存在', items: _payloadStringList('complete_reality', 'still_here')),
          _KeyValue(label: '如果明天失去，我会不会后悔没珍惜', value: _payloadText('complete_reality', 'if_lost_tomorrow')),
          _KeyValue(label: '今天的珍惜动作', value: _payloadText('complete_reality', 'appreciation_action')),
          _KeyValue(label: '完整现实句', value: _payloadText('complete_reality', 'complete_reality_sentence')),
        ];
      case 'appreciation_scan':
        return <Widget>[
          RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle(scene), body: RotCoreValueCopy.sceneBody(scene), icon: Icons.auto_awesome_outlined),
          _BulletList(title: '正在被我习以为常的好', items: _payloadStringList('appreciation_scan', 'currently_taken_for_granted')),
          _KeyValue(label: '如果失去会怎样', value: _payloadText('appreciation_scan', 'if_lost_tomorrow')),
          _KeyValue(label: '为什么正在贬值', value: _payloadText('appreciation_scan', 'why_depreciating')),
          _KeyValue(label: '今天的珍惜动作', value: _payloadText('appreciation_scan', 'today_appreciation_action')),
          _KeyValue(label: '提醒句', value: _payloadText('appreciation_scan', 'reminder_sentence')),
        ];
      case 'same_reality_interpretations':
        return <Widget>[
          RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle(scene), body: RotCoreValueCopy.sceneBody(scene), icon: Icons.auto_awesome_outlined),
          _BulletList(title: '同一现实的事实', items: _payloadStringList('same_reality_interpretations', 'facts')),
          _KeyValue(label: '当前痛苦解释', value: _payloadText('same_reality_interpretations', 'current_interpretation')),
          _KeyValue(label: '如果相信这个解释，我会怎么行动', value: _payloadText('same_reality_interpretations', 'action_if_believed')),
          _BulletList(title: 'Tal 式替代问题', items: _payloadStringList('same_reality_interpretations', 'tal_alternative_questions')),
          _KeyValue(label: '更完整解释', value: _payloadText('same_reality_interpretations', 'more_complete_interpretation')),
          _KeyValue(label: '第一步行动', value: _payloadText('same_reality_interpretations', 'first_action')),
        ];
      case 'loss_resource_retention':
        return <Widget>[
          RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle(scene), body: RotCoreValueCopy.sceneBody(scene), icon: Icons.auto_awesome_outlined),
          _KeyValue(label: '我失去的部分', value: _payloadText('loss_resource_retention', 'lost_part')),
          _KeyValue(label: '真的很痛的部分', value: _payloadText('loss_resource_retention', 'painful_part')),
          _BulletList(title: '没有一起失去的资源', items: _payloadStringList('loss_resource_retention', 'not_lost')),
          _BulletList(title: '仍然在的人', items: _payloadStringList('loss_resource_retention', 'people_still_here')),
          _KeyValue(label: '变清楚的价值', value: _payloadText('loss_resource_retention', 'value_clarified')),
          _KeyValue(label: '重新开始的一小块', value: _payloadText('loss_resource_retention', 'restart_piece')),
          _KeyValue(label: '不美化损失句', value: _payloadText('loss_resource_retention', 'not_beautifying_sentence')),
        ];
      case 'priming_diagnostic':
        return <Widget>[
          RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle(scene), body: RotCoreValueCopy.sceneBody(scene), icon: Icons.auto_awesome_outlined),
          _BulletList(title: '消极启动源', items: _payloadStringList('priming_diagnostic', 'negative_cues')),
          _KeyValue(label: '它把我启动成什么状态', value: _payloadText('priming_diagnostic', 'triggered_state')),
          _KeyValue(label: '我想被启动成什么状态', value: _payloadText('priming_diagnostic', 'desired_state')),
          _KeyValue(label: '要放置的注意力启动线索', value: _payloadText('priming_diagnostic', 'placed_prime')),
          _KeyValue(label: '今天的清理动作', value: _payloadText('priming_diagnostic', 'cleanup_action')),
        ];
      case 'identity_script_activation':
        return <Widget>[
          RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle(scene), body: RotCoreValueCopy.sceneBody(scene), icon: Icons.auto_awesome_outlined),
          _KeyValue(label: '今天被启动的身份脚本', value: _payloadText('identity_script_activation', 'triggered_script')),
          _KeyValue(label: '来源', value: _payloadText('identity_script_activation', 'source')),
          _KeyValue(label: '它造成的后果', value: _payloadText('identity_script_activation', 'effect')),
          _KeyValue(label: '明天想启动的身份脚本', value: _payloadText('identity_script_activation', 'desired_script')),
          _KeyValue(label: '环境脚本', value: _payloadText('identity_script_activation', 'environment_script')),
          _KeyValue(label: '微行动', value: _payloadText('identity_script_activation', 'micro_action')),
        ];
      case 'gratitude_time_in':
        return <Widget>[
          RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle(scene), body: RotCoreValueCopy.sceneBody(scene), icon: Icons.auto_awesome_outlined),
          _KeyValue(label: '安静提示', value: _payloadText('gratitude_time_in', 'quiet_prompt')),
          _BulletList(title: '具体感恩', items: _payloadStringList('gratitude_time_in', 'gratitude_items')),
          _KeyValue(label: '感官细节', value: _payloadText('gratitude_time_in', 'sensory_detail')),
          _KeyValue(label: '身体感受', value: _payloadText('gratitude_time_in', 'body_feeling')),
          _KeyValue(label: '分享对象', value: _payloadText('gratitude_time_in', 'share_person')),
          _KeyValue(label: '表达文本', value: _payloadText('gratitude_time_in', 'expression_text')),
          _KeyValue(label: '表达后记录', value: _payloadText('gratitude_time_in', 'after_sharing_record')),
        ];
      case 'process_simulation_check':
        return <Widget>[
          RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle(scene), body: RotCoreValueCopy.sceneBody(scene), icon: Icons.auto_awesome_outlined),
          _KeyValue(label: '时间', value: _payloadText('process_simulation_check', 'time')),
          _KeyValue(label: '地点', value: _payloadText('process_simulation_check', 'place')),
          _KeyValue(label: '工具/材料', value: _payloadText('process_simulation_check', 'tool')),
          _KeyValue(label: '第一动作', value: _payloadText('process_simulation_check', 'first_move')),
          _KeyValue(label: '干扰源', value: _payloadText('process_simulation_check', 'distraction')),
          _KeyValue(label: '去干扰动作', value: _payloadText('process_simulation_check', 'de_distraction_action')),
          _KeyValue(label: '完成标准', value: _payloadText('process_simulation_check', 'completion_standard')),
          _KeyValue(label: '质量校验', value: _payloadText('process_simulation_check', 'quality_check')),
        ];
      case 'psychological_immunity_experiment':
        return <Widget>[
          RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle(scene), body: RotCoreValueCopy.sceneBody(scene), icon: Icons.auto_awesome_outlined),
          _KeyValue(label: '失败前预测', value: _payloadText('psychological_immunity_experiment', 'before_prediction')),
          _KeyValue(label: '失败后实际', value: _payloadText('psychological_immunity_experiment', 'after_result')),
          _KeyValue(label: '痛苦差异', value: _payloadText('psychological_immunity_experiment', 'pain_gap')),
          _KeyValue(label: '恢复差异', value: _payloadText('psychological_immunity_experiment', 'recovery_gap')),
          _KeyValue(label: '最坏预测是否发生', value: _payloadText('psychological_immunity_experiment', 'worst_case_happened')),
          _KeyValue(label: '心理抗体', value: _payloadText('psychological_immunity_experiment', 'antibody_sentence')),
          _KeyValue(label: '下次更小尝试', value: _payloadText('psychological_immunity_experiment', 'next_smaller_attempt')),
        ];
      default:
        return <Widget>[];
    }
  }

  bool _canRecordAction(RealisticOptimismTrainingRecord r) {
    if (r.fiveMinuteAction.trim().isEmpty) return false;
    if (r.intensityLevel == 'L3' || r.intensityLevel == 'L4') return false;
    return <String>{
      'reality_record',
      'event_reframe',
      'process_action',
      'failure_immunity',
      'controlled_failure_challenge',
      'psychological_immunity_experiment',
      'same_reality_interpretations',
      'loss_resource_retention',
      'process_simulation_check',
      'complete_reality',
      'appreciation_scan',
      'gratitude_time_in',
      'todo_goal_bridge',
      'daily_review',
      'core_business_session',
    }.contains(r.scene);
  }

  String _sceneTitle(String scene) {
    switch (scene) {
      case 'reality_record':
        return '真实现实记录结果';
      case 'event_reframe':
        return '今日事件重构结果';
      case 'emotion_container':
        return '情绪容器结果';
      case 'process_action':
        return '过程模拟行动结果';
      case 'failure_immunity':
        return '失败免疫复盘结果';
      case 'controlled_failure_challenge':
        return '可控失败挑战结果';
      case 'prime_design':
        return '注意力启动线索结果';
      case 'anti_prime_cleanup':
        return '消极启动源清理结果';
      case 'gratitude_savoring':
        return '感恩与品味结果';
      case 'complete_reality':
        return '完整现实感练习结果';
      case 'appreciation_scan':
        return '防贬值珍惜扫描结果';
      case 'same_reality_interpretations':
        return '同一现实，多种解释练习结果';
      case 'loss_resource_retention':
        return '损失后的资源保留练习结果';
      case 'priming_diagnostic':
        return '启动源诊断结果';
      case 'identity_script_activation':
        return '身份脚本启动练习结果';
      case 'gratitude_time_in':
        return '感恩静心分享闭环结果';
      case 'process_simulation_check':
        return '过程模拟校验结果';
      case 'psychological_immunity_experiment':
        return '心理免疫实验结果';
      case 'identity_evidence':
        return '身份沉淀结果';
      case 'weekly_baseline':
        return '幸福基线周报结果';
      case 'monthly_report':
        return '月度成长报告结果';
      case 'todo_goal_bridge':
        return '待办事项 / 目标联动结果';
      case 'daily_review':
        return '晚间复盘结果';
      case 'course_card':
        return '课程知识卡结果';
      case 'role_model_case':
        return '榜样案例结果';
      case 'proactive_reminder':
        return 'AI 主动提醒结果';
      case 'explanation_radar':
        return '解释风格雷达结果';
      case 'dual_lens':
        return '双镜头重构结果';
      case 'intensity_check':
        return '事件强度分级结果';
      default:
        return '训练结果';
    }
  }

  String _sceneFocus(String scene) {
    switch (scene) {
      case 'reality_record':
        return '本次重点是主线：记录真实发生的事，承认它确实不好的部分，允许痛苦存在，看清痛苦解释，补全现实，最后做一个小到能开始的勇气出马动作。';
      case 'process_action':
        return '本次重点只看：目标/任务 → 可控点 → 过程路径 → 障碍预演 → 如果-那么 → 5 分钟启动 → 行动证据。失败免疫、感恩、注意力启动线索只作为后续可选延伸，不再默认平铺。';
      case 'failure_immunity':
        return '本次重点只看：失败事实 → 预测痛苦/恢复 → 实际结果/恢复 → 承受住了什么 → 心理抗体 → 下次更小行动。';
      case 'emotion_container':
        return '本次重点只看：强度分级 → 情绪命名 → 身体感受与合理性 → 一个很小的稳定动作。此时不急着重构、感恩或寻找意义。';
      case 'gratitude_savoring':
        return '本次重点只看：具体感恩 → 为什么重要 → 30 秒品味 → 珍惜/表达行动。感恩不是否认痛苦，而是补全现实。';
      case 'prime_design':
        return '本次重点只看：今日价值词 → 锁屏/小组件短句 → 资源发现问题 → 现实环境线索 → 今日行动线索。';
      case 'anti_prime_cleanup':
        return '本次重点只看：消极启动源 → 它带来的状态 → 最小清理动作 → 替代注意力启动线索。不要一次性改全部环境。';
      case 'identity_evidence':
        return '本次重点只看：实际完成/恢复/珍惜过什么 → 证明了什么能力 → 对应哪种身份成长 → 一句身份提醒。';
      case 'controlled_failure_challenge':
        return '本次重点只看：低风险失败挑战 → 执行步骤 → 安全边界 → 失败前预测 → 失败后复盘 → 心理抗体。';
      case 'todo_goal_bridge':
        return '本次重点只看：待办事项为什么卡住 → 目标价值 → 自动解释 → 5 分钟启动 → 如果-那么 → 完成后成为哪种行动证据。';
      case 'daily_review':
        return '本次重点只看：今日解释风格、行动证据、具体感恩、30 秒品味、身份提醒和明日注意力启动线索。';
      case 'complete_reality':
        return '本次重点是祖母故事功能化：我不否认痛苦，也不遗漏仍然存在的美、善、关系和珍惜动作。';
      case 'appreciation_scan':
        return '本次重点是防贬值珍惜扫描：找出正在习以为常但失去后会后悔没有珍惜的东西。';
      case 'same_reality_interpretations':
        return '本次重点是 Tal 式同一现实多种解释：事实不变，解释从终局判决转向训练、谦卑、补基础和下一步行动。';
      case 'loss_resource_retention':
        return '本次重点是火灾研究式资源保留：不美化损失，但识别没有一起失去的人、能力、价值和重新开始的一小块。';
      case 'priming_diagnostic':
        return '本次重点是 Bargh 启动实验功能化：诊断词语、应用、图像、环境如何启动我，并设计替代线索。';
      case 'identity_script_activation':
        return '本次重点是教授/足球流氓启动实验功能化：我被启动成谁，以及明天如何被启动成更有行动力的人。';
      case 'gratitude_time_in':
        return '本次重点是感恩静心分享：安静写下具体感恩、品味身体感受，并把感谢带回关系表达。';
      case 'process_simulation_check':
        return '本次重点是过程模拟校验：没有时间、地点、工具、第一动作、去干扰和完成标准，就不算有效行动计划。';
      case 'psychological_immunity_experiment':
        return '本次重点是心理免疫实验：失败前预测、失败后实际、痛苦差异、恢复差异和心理抗体。';
      case 'course_card':
        return '本次重点只看：把课程核心思想压缩成一张可复用知识卡，并连接到一个现实行动。';
      case 'role_model_case':
        return '本次重点只看：相似人物或榜样案例如何提供“有人也做到过”的外部证据。';
      case 'proactive_reminder':
        return '本次重点只看：在合适时机给出一条不过度打扰、能启动行动的 AI 主动提醒。';
      case 'weekly_baseline':
      case 'monthly_report':
        return '本次重点只看长期趋势：恢复能力、解释风格、行动证据、感恩敏感度、注意力环境和下周训练重点。';
      case 'explanation_radar':
        return '本次重点只看自动解释里的永久化、普遍化、人格化、灾难化、无力化和过滤化，以及更现实的替代表达。';
      case 'dual_lens':
        return '本次重点只看同一事件的 问题放大视角 叙事与 资源发现视角 重构，以及重构后能带来的行动。';
      case 'intensity_check':
        return '本次重点只做 L1/L2/L3/L4 安全分流，决定适合与不适合的干预，不急着进入完整训练。';
      case 'event_reframe':
      default:
        return '本次重点是完整事件重构：情绪允许 → 事实/解释分离 → 解释风格 → 双镜头 → 可控点 → 5 分钟行动 → 身份沉淀。';
    }
  }

  Set<String> _primarySections(String scene) {
    switch (scene) {
      case 'reality_record':
        return <String>{'reality_core', 'intensity', 'final'};
      case 'intensity_check':
        return <String>{'research', 'intensity', 'final'};
      case 'emotion_container':
        return <String>{'research', 'intensity', 'emotion', 'agency', 'action', 'final'};
      case 'explanation_radar':
        return <String>{'research', 'intensity', 'emotion', 'facts', 'radar', 'agency', 'action', 'final'};
      case 'dual_lens':
        return <String>{'research', 'intensity', 'emotion', 'facts', 'radar', 'dual', 'agency', 'action', 'identity', 'final'};
      case 'process_action':
        return <String>{'research', 'intensity', 'emotion', 'agency', 'action', 'identity', 'final'};
      case 'failure_immunity':
        return <String>{'research', 'intensity', 'emotion', 'facts', 'failure', 'action', 'identity', 'final'};
      case 'controlled_failure_challenge':
        return <String>{'research', 'intensity', 'emotion', 'challenge', 'failure', 'action', 'identity', 'final'};
      case 'prime_design':
      case 'anti_prime_cleanup':
        return <String>{'research', 'intensity', 'prime', 'action', 'final'};
      case 'gratitude_savoring':
        return <String>{'research', 'intensity', 'emotion', 'gratitude', 'identity', 'final'};
      case 'identity_evidence':
        return <String>{'research', 'intensity', 'action', 'identity', 'final'};
      case 'todo_goal_bridge':
        return <String>{'research', 'intensity', 'emotion', 'facts', 'radar', 'dual', 'action', 'p2', 'identity', 'final'};
      case 'daily_review':
        return <String>{'research', 'intensity', 'gratitude', 'prime', 'identity', 'p2', 'final'};
      case 'complete_reality':
      case 'appreciation_scan':
      case 'gratitude_time_in':
        return <String>{'research', 'intensity', 'emotion', 'mechanism', 'gratitude', 'identity', 'final'};
      case 'same_reality_interpretations':
      case 'loss_resource_retention':
        return <String>{'research', 'intensity', 'emotion', 'facts', 'dual', 'mechanism', 'action', 'identity', 'final'};
      case 'priming_diagnostic':
      case 'identity_script_activation':
        return <String>{'research', 'intensity', 'mechanism', 'prime', 'action', 'identity', 'final'};
      case 'process_simulation_check':
        return <String>{'research', 'intensity', 'mechanism', 'agency', 'action', 'identity', 'final'};
      case 'psychological_immunity_experiment':
        return <String>{'research', 'intensity', 'emotion', 'mechanism', 'failure', 'action', 'identity', 'final'};
      case 'course_card':
      case 'role_model_case':
        return <String>{'research', 'intensity', 'p2', 'action', 'identity', 'final'};
      case 'proactive_reminder':
        return <String>{'research', 'intensity', 'prime', 'p2', 'action', 'final'};
      case 'weekly_baseline':
      case 'monthly_report':
        return <String>{'research', 'intensity', 'failure', 'gratitude', 'prime', 'identity', 'p2', 'final'};
      case 'event_reframe':
      case 'core_business_session':
      default:
        return <String>{'research', 'intensity', 'emotion', 'facts', 'radar', 'dual', 'agency', 'action', 'identity', 'final'};
    }
  }

  Future<void> _markActionDone() async {
    if (_markingAction) return;
    if (_actions.any((a) => a.completed)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('这条行动证据已经记录过了')));
      return;
    }
    setState(() => _markingAction = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final linkedArtifacts = await _dao.listDailyArtifactsLinkedToRecord(widget.record.id);
      String linkedTodoId = '';
      String linkedArtifactId = '';
      for (final row in linkedArtifacts) {
        final type = (row['target_type'] ?? '').toString();
        final status = (row['status'] ?? '').toString();
        final targetId = (row['target_id'] ?? '').toString().trim();
        final artifactId = (row['id'] ?? '').toString().trim();
        if (type == 'todo_task' && targetId.isNotEmpty && !<String>{'completed', 'superseded', 'paused_for_safety', 'abandoned', 'archived'}.contains(status)) {
          linkedTodoId = targetId;
          linkedArtifactId = artifactId;
          await _todoDao.updateTaskCompletion(taskId: targetId, completed: true);
          if (artifactId.isNotEmpty) {
            await _dao.updateDailyExtensionArtifactStatus(
              id: artifactId,
              status: 'completed',
              completedAtMs: now,
              mergeContent: <String, Object?>{'completed_from_detail_page': true, 'completed_record_id': widget.record.id},
            );
          }
          break;
        }
      }
      await _dao.addActionEvidence(RealisticOptimismTrainingActionEvidence(
        id: 'rot_a_${widget.record.id}_$now',
        recordId: widget.record.id,
        action: widget.record.fiveMinuteAction,
        evidenceText: widget.record.identitySentence.isEmpty ? '我完成了一个小行动证据。' : widget.record.identitySentence,
        completed: true,
        completedAtMs: now,
        selfEfficacyScore: 6,
        sourceType: linkedArtifactId.isNotEmpty ? 'daily_artifact' : 'detail_record',
        sourceId: linkedArtifactId.isNotEmpty ? linkedArtifactId : widget.record.id,
        todoTaskId: linkedTodoId,
        dailyArtifactId: linkedArtifactId,
        createdAtMs: now,
      ));
      await _dao.addIdentityEvidence(
        id: 'rot_detail_identity_${widget.record.id}_$now',
        recordId: widget.record.id,
        sourceType: 'detail_action_completed',
        identityType: widget.record.identityType.isEmpty ? '行动证据积累者' : widget.record.identityType,
        evidenceText: widget.record.provedCapacity.isEmpty ? '完成了详情页中的 5 分钟行动。' : widget.record.provedCapacity,
        identitySentence: widget.record.identitySentence.isEmpty ? '我正在成为一个能把小行动沉淀成证据的人。' : widget.record.identitySentence,
      );
      await _loadActions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已记录行动证据，并同步日常闭环状态')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('记录失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _markingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final coreRefRaw = r.payload['core_value_reference'];
    final coreRef = coreRefRaw is Map ? Map<String, dynamic>.from(coreRefRaw) : <String, dynamic>{};
    final sourceAnchor = (coreRef['source_anchor'] ?? '').toString().trim();
    final sourceHow = (coreRef['how_it_applies'] ?? '').toString().trim();
    final validationRepairNote = (r.payload['validation_repair_note'] ?? '').toString().trim();
    final primarySections = _primarySections(r.scene);
    final challengePayload = _payloadMap('controlled_failure_challenge');
    final p2Payload = _payloadMap('p2_delivery');
    final canRecordAction = _canRecordAction(r);
    bool showSection(String key) => primarySections.contains(key);
    return Scaffold(
      appBar: AppBar(title: Text(_sceneTitle(r.scene))),
      floatingActionButton: canRecordAction
          ? FloatingActionButton.extended(
              onPressed: _markingAction ? null : _markActionDone,
              icon: const Icon(Icons.done_all_outlined),
              label: Text(_markingAction ? '正在记录…' : '记录行动证据'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: <Widget>[
          _DetailHeader(record: r),
          const SizedBox(height: 12),
          _InfoCard(icon: Icons.filter_alt_outlined, title: _sceneTitle(r.scene), body: _sceneFocus(r.scene)),
          const SizedBox(height: 12),
          if (showSection('reality_core')) _DetailSection(title: '现实记录主线', icon: Icons.visibility_outlined, children: _realityCoreWidgets()),
          if (showSection('research')) _DetailSection(title: '价值体系与研究锚点', icon: Icons.science_outlined, children: <Widget>[
            const RotCoreValueGuideCard(title: RotCoreValueCopy.researchAnchorsTitle, body: RotCoreValueCopy.researchAnchorsBody, icon: Icons.science_outlined),
            if (sourceAnchor.isNotEmpty) _KeyValue(label: '本次使用锚点', value: sourceAnchor),
            if (sourceHow.isNotEmpty) _KeyValue(label: '如何应用到本次事件', value: sourceHow),
            if (validationRepairNote.isNotEmpty) _KeyValue(label: 'AI 输出校验补全提示', value: validationRepairNote),
          ]),
          if (showSection('mechanism')) _DetailSection(title: '课程机制练习', icon: Icons.extension_outlined, children: _mechanismWidgets(r.scene)),
          if (showSection('intensity')) _DetailSection(title: '0. 事件强度分级', icon: Icons.rule_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('intensity_check'), body: RotCoreValueCopy.sceneBody('intensity_check'), icon: Icons.auto_awesome_outlined),
            _KeyValue(label: '等级', value: r.intensityLevel),
            _KeyValue(label: '原因', value: r.intensityReason),
            _BulletList(title: '当前适合', items: r.allowedInterventions),
            _BulletList(title: '当前不适合', items: r.blockedInterventions),
          ]),
          if (r.intensityLevel == 'L3' || r.intensityLevel == 'L4')
            _SafetySupportCard(level: r.intensityLevel),
          if (showSection('emotion')) _DetailSection(title: '1. 允许自己为人', icon: Icons.favorite_border, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('emotion_container'), body: RotCoreValueCopy.sceneBody('emotion_container'), icon: Icons.auto_awesome_outlined),
            _KeyValue(label: '主要情绪', value: r.primaryEmotion),
            _KeyValue(label: '情绪承认', value: r.validationText),
          ]),
          if (showSection('facts')) _DetailSection(title: '2. 事实-解释分离', icon: Icons.fact_check_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('event_reframe'), body: RotCoreValueCopy.sceneBody('event_reframe'), icon: Icons.auto_awesome_outlined),
            _BulletList(title: '客观事实', items: r.objectiveFacts),
            _BulletList(title: '未知/假设', items: r.unknowns),
            _KeyValue(label: '自动解释', value: r.automaticInterpretation),
          ]),
          if (showSection('radar')) _DetailSection(title: '3. 解释风格雷达', icon: Icons.radar_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('explanation_radar'), body: RotCoreValueCopy.sceneBody('explanation_radar'), icon: Icons.auto_awesome_outlined),
            _ScoreBar(label: '永久化', score: r.permanenceScore),
            _ScoreBar(label: '普遍化', score: r.pervasivenessScore),
            _ScoreBar(label: '人格化', score: r.personalizationScore),
            _ScoreBar(label: '灾难化', score: r.catastrophizingScore),
            _ScoreBar(label: '无力化', score: r.helplessnessScore),
            _ScoreBar(label: '过滤化', score: r.filteringScore),
            _KeyValue(label: '主模式', value: r.mainPattern),
          ]),
          if (showSection('dual')) _DetailSection(title: '4. 问题放大视角 / 资源发现视角 双镜头', icon: Icons.compare_arrows_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('dual_lens'), body: RotCoreValueCopy.sceneBody('dual_lens'), icon: Icons.auto_awesome_outlined),
            _KeyValue(label: '问题放大视角 叙事', value: r.faultFinderStory),
            _KeyValue(label: '情绪后果', value: r.emotionalEffect),
            _KeyValue(label: '行为后果', value: r.behavioralEffect),
            _KeyValue(label: '资源发现视角 重构', value: r.balancedInterpretation),
            _KeyValue(label: '没有否认的痛苦', value: r.notDeniedPain),
            _BulletList(title: '可能学习', items: r.possibleLearning),
            _BulletList(title: '剩余资源', items: r.remainingResources),
            _BulletList(title: '可能意义', items: r.possibleMeaning),
          ]),
          if (showSection('agency')) _DetailSection(title: '5. 主动性层', icon: Icons.touch_app_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('process_action'), body: RotCoreValueCopy.sceneBody('process_action'), icon: Icons.auto_awesome_outlined),
            _BulletList(title: '不可控', items: r.uncontrollableParts),
            _BulletList(title: '可影响', items: r.influenceableParts),
            _BulletList(title: '可控制', items: r.controllableActions),
          ]),
          if (showSection('action')) _DetailSection(title: '6. 过程模拟行动器', icon: Icons.directions_run_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('process_action'), body: RotCoreValueCopy.sceneBody('process_action'), icon: Icons.auto_awesome_outlined),
            _KeyValue(label: '5分钟行动', value: r.fiveMinuteAction),
            _BulletList(title: '接下来三步', items: r.nextThreeSteps),
            _BulletList(title: '如果-那么 计划', items: r.ifThenPlan),
          ]),
          if (showSection('challenge')) _DetailSection(title: '7. 可控失败挑战', icon: Icons.shield_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('controlled_failure_challenge'), body: RotCoreValueCopy.sceneBody('controlled_failure_challenge'), icon: Icons.auto_awesome_outlined),
            _KeyValue(label: '挑战名称', value: (challengePayload['challenge_name'] ?? '').toString()),
            _KeyValue(label: '风险等级', value: (challengePayload['risk_level'] ?? '').toString()),
            _KeyValue(label: '安全边界', value: (challengePayload['safety_boundary'] ?? '').toString()),
            _BulletList(title: '执行步骤', items: _payloadStringList('controlled_failure_challenge', 'execution_steps')),
            _BulletList(title: '失败前预测问题', items: _payloadStringList('controlled_failure_challenge', 'pre_failure_questions')),
            _BulletList(title: '失败后复盘问题', items: _payloadStringList('controlled_failure_challenge', 'post_failure_questions')),
            _KeyValue(label: '可能获得的心理抗体', value: (challengePayload['possible_antibody'] ?? '').toString()),
          ]),
          if (showSection('failure')) _DetailSection(title: '7. 失败免疫', icon: Icons.shield_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('failure_immunity'), body: RotCoreValueCopy.sceneBody('failure_immunity'), icon: Icons.auto_awesome_outlined),
            _KeyValue(label: '预测痛苦', value: r.predictedPain == null ? '' : r.predictedPain!.toStringAsFixed(1)),
            _KeyValue(label: '实际痛苦', value: r.actualPain == null ? '' : r.actualPain!.toStringAsFixed(1)),
            _KeyValue(label: '预测恢复', value: r.predictedRecovery),
            _KeyValue(label: '实际恢复', value: r.actualRecovery),
            _KeyValue(label: '心理抗体', value: r.psychologicalAntibody),
          ]),
          if (showSection('gratitude')) _DetailSection(title: '8. 感恩与品味', icon: Icons.local_florist_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('gratitude_savoring'), body: RotCoreValueCopy.sceneBody('gratitude_savoring'), icon: Icons.auto_awesome_outlined),
            _BulletList(title: '仍然重要', items: r.whatStillMatters),
            _KeyValue(label: '30秒品味', value: r.savoringPrompt),
            _KeyValue(label: '珍惜行动', value: r.smallAppreciationAction),
          ]),
          if (showSection('prime')) _DetailSection(title: '9. 注意力启动线索与消极启动源', icon: Icons.wallpaper_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('prime_design'), body: RotCoreValueCopy.sceneBody('prime_design'), icon: Icons.auto_awesome_outlined),
            _KeyValue(label: '价值词', value: r.dailyValueWord),
            _KeyValue(label: '锁屏短句', value: r.lockScreenSentence),
            _KeyValue(label: '资源发现问题', value: r.benefitFinderQuestion),
            _KeyValue(label: '消极启动源清理', value: r.antiPrimeCleanupAction),
          ]),
          if (showSection('identity')) _DetailSection(title: '10. 身份沉淀', icon: Icons.badge_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('identity_evidence'), body: RotCoreValueCopy.sceneBody('identity_evidence'), icon: Icons.auto_awesome_outlined),
            _KeyValue(label: '具体行动', value: r.specificAction),
            _KeyValue(label: '证明能力', value: r.provedCapacity),
            _KeyValue(label: '身份类型', value: r.identityType),
            _KeyValue(label: '身份提醒', value: r.identitySentence),
          ]),
          if (showSection('p2')) _DetailSection(title: '日常实践产物', icon: Icons.hub_outlined, children: <Widget>[
            _KeyValue(label: '产物类型', value: _rotFriendlyType((p2Payload['artifact_type'] ?? r.scene).toString())),
            _KeyValue(label: '标题', value: (p2Payload['title'] ?? '').toString()),
            _KeyValue(label: '触发条件', value: (p2Payload['trigger_condition'] ?? '').toString()),
            _KeyValue(label: '摘要', value: (p2Payload['summary'] ?? '').toString()),
            _BulletList(title: '内容区块', items: _payloadStringList('p2_delivery', 'sections')),
            _KeyValue(label: '下一步动作', value: (p2Payload['next_action'] ?? '').toString()),
            _KeyValue(label: '复用位置', value: (p2Payload['reuse_surface'] ?? '').toString()),
          ]),
          if (_actions.isNotEmpty)
            _DetailSection(title: '已记录行动证据', icon: Icons.done_all_outlined, children: _actions.map((e) => _KeyValue(label: e.completed ? '已完成' : '未完成', value: '${e.action}\n${e.evidenceText}')).toList()),
          if (showSection('final')) _DetailSection(title: '最终提醒', icon: Icons.flag_outlined, children: <Widget>[
            _KeyValue(label: '给用户的话', value: r.finalUserMessage),
          ]),
        ],
      ),
    );
  }
}

class _ModuleGrid extends StatelessWidget {
  final void Function(String scene, String template) onSelect;
  const _ModuleGrid({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final modules = <_ModuleEntry>[
      const _ModuleEntry(Icons.edit_note_outlined, '我今天遇到不顺了', '进入今日事件重构：情绪、事实、解释、双镜头、5分钟行动', 'event_reframe', '今天发生了一件让我难受/失败/拖延/自责的事：'),
      const _ModuleEntry(Icons.favorite_border, '我现在很难受，想先缓一下', '进入允许自己为人：先承认情绪和身体感受，不急着积极', 'emotion_container', '我现在最强烈的情绪是：'),
      const _ModuleEntry(Icons.route_outlined, '我有个目标一直拖着', '进入过程模拟行动：时间、地点、第一步、障碍、如果-那么', 'process_action', '我的目标/任务是：'),
      const _ModuleEntry(Icons.shield_outlined, '我失败了，想复盘一下', '进入失败免疫：预测痛苦、实际结果、恢复和心理抗体', 'failure_immunity', '我经历/害怕的一次失败是：'),
    ];
    return LayoutBuilder(
      builder: (ctx, c) {
        final wide = c.maxWidth > 680;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: modules.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: wide ? 2 : 1,
            mainAxisExtent: 136,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (ctx, i) {
            final m = modules[i];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelect(m.scene, m.template),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(child: Icon(m.icon)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(m.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(m.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700)),
                            const SizedBox(height: 4),
                            Text('入口作用：${m.subtitle}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade800, height: 1.25, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}


class _MechanismPracticeGrid extends StatelessWidget {
  final void Function(String scene, String template) onSelect;
  const _MechanismPracticeGrid({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final modules = <_ModuleEntry>[
      const _ModuleEntry(Icons.filter_vintage_outlined, '完整现实感练习', '祖母故事：痛苦是真的，仍然存在的美也是真的', 'complete_reality', '我现在不想否认的痛苦是：'),
      const _ModuleEntry(Icons.favorite_outline, '防贬值珍惜扫描', '不被珍惜的东西，会在心理上贬值：今天先珍惜一个正在被习惯化的好', 'appreciation_scan', '我可能正在习以为常、但失去后会后悔没珍惜的是：'),
      const _ModuleEntry(Icons.compare_arrows_outlined, '同一现实，多种解释', 'Tal 失败故事：事实不变，解释改变，行动改变', 'same_reality_interpretations', '我现在想重新解释的一件失败/被否定/错过是：'),
      const _ModuleEntry(Icons.home_work_outlined, '损失后的资源保留', '火灾研究：不美化损失，只看见没一起失去的资源', 'loss_resource_retention', '我最近失去/错过/被迫放下的是：'),
      const _ModuleEntry(Icons.radar_outlined, '启动源诊断器', 'Bargh 启动实验：识别什么把我启动成拖延/比较/自责', 'priming_diagnostic', '今天最容易启动我拖延、比较、自责或无力的东西是：'),
      const _ModuleEntry(Icons.badge_outlined, '身份脚本启动', '教授/足球流氓实验：我被启动成谁，想被启动成谁', 'identity_script_activation', '今天我感觉自己被某个环境或信息启动成了：'),
      const _ModuleEntry(Icons.self_improvement_outlined, '感恩静心分享闭环', '安静写下、品味身体感受、把感谢带回关系', 'gratitude_time_in', '今天一个具体值得感谢的人/事/画面是：'),
      const _ModuleEntry(Icons.checklist_rtl_outlined, '过程模拟校验器', '没有时间地点工具第一步，就还不是行动计划', 'process_simulation_check', '我想推进的目标是：'),
      const _ModuleEntry(Icons.health_and_safety_outlined, '心理免疫实验', '失败前预测、失败后实际、恢复差异、心理抗体', 'psychological_immunity_experiment', '我害怕或刚经历的一次失败是：'),
    ];
    return LayoutBuilder(
      builder: (ctx, c) {
        final wide = c.maxWidth > 680;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: modules.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: wide ? 3 : 1,
            mainAxisExtent: 128,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (ctx, i) {
            final m = modules[i];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelect(m.scene, m.template),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(child: Icon(m.icon)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 5),
                            Text(m.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade800, height: 1.25, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ModuleEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final String scene;
  final String template;
  const _ModuleEntry(this.icon, this.title, this.subtitle, this.scene, this.template);
}


class _OpenSessionsCard extends StatelessWidget {
  final List<RealisticOptimismTrainingSession> sessions;
  final Future<void> Function(RealisticOptimismTrainingSession session) onContinue;
  final Future<void> Function(RealisticOptimismTrainingSession session) onAbandon;

  const _OpenSessionsCard({required this.sessions, required this.onContinue, required this.onAbandon});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.check_circle_outline),
          title: Text('没有未完成训练'),
          subtitle: Text('打开“解决今天一个实际问题”即可开始一条新的核心业务会话。'),
        ),
      );
    }
    final latest = sessions.first;
    final stepLabel = <String>['现实与情绪', '事实与解释', '行动与预演', '复盘与身份'][latest.currentStep.clamp(0, 3).toInt()];
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(.55),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            const Icon(Icons.pending_actions_outlined),
            const SizedBox(width: 8),
            const Expanded(child: Text('继续未完成训练', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            Chip(label: Text('${sessions.length} 条')),
          ]),
          const SizedBox(height: 8),
          Text('停在：$stepLabel｜强度：${latest.level}｜情绪：${latest.emotion.isEmpty ? '未记录' : latest.emotion}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(latest.eventText.isEmpty ? '这是一条尚未填写完整的训练草稿。' : latest.eventText, maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            FilledButton.icon(onPressed: () => onContinue(latest), icon: const Icon(Icons.play_arrow_outlined), label: const Text('继续这条会话')),
            OutlinedButton.icon(onPressed: () => onAbandon(latest), icon: const Icon(Icons.close_outlined), label: const Text('放弃草稿')),
          ]),
        ]),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionText;
  final VoidCallback? onPressed;
  const _HeroPanel({required this.title, required this.subtitle, this.actionText, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: <Color>[Colors.indigo.shade700, Colors.blueGrey.shade700]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.45)),
          if (actionText != null && onPressed != null) ...<Widget>[
            const SizedBox(height: 14),
            FilledButton.tonalIcon(onPressed: onPressed, icon: const Icon(Icons.arrow_forward), label: Text(actionText!)),
          ],
        ],
      ),
    );
  }
}



class _SafetySupportCard extends StatelessWidget {
  final String level;
  const _SafetySupportCard({required this.level});

  @override
  Widget build(BuildContext context) {
    final isL4 = level == 'L4';
    return Card(
      color: isL4 ? Colors.red.shade50 : Colors.orange.shade50,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            Icon(isL4 ? Icons.emergency_outlined : Icons.health_and_safety_outlined, color: isL4 ? Colors.red.shade700 : Colors.deepOrange.shade700),
            const SizedBox(width: 8),
            Expanded(child: Text(isL4 ? '安全优先：暂停普通训练流程' : '高强度痛苦：先稳定，不强行找好处', style: const TextStyle(fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 8),
          Text(
            isL4
                ? '如果你现在有伤害自己或他人的冲动、计划，或无法保证安全，请立刻联系当地紧急服务、身边可信任的人，或前往最近的急诊/安全地点。本模块此时不应继续做资源发现或感恩训练。建议提前在个人设置里准备：可信任联系人、安全地点、2 分钟稳定动作和当地紧急支持方式。'
                : '这类事件暂时不适合强行积极、强行感恩或快速意义化。当前更重要的是承认痛苦、降低刺激、联系现实支持，并在状态稳定后再进入解释重构。',
            style: const TextStyle(height: 1.45),
          ),
        ]),
      ),
    );
  }
}

class _MapRowsGroup extends StatelessWidget {
  final String title;
  final String empty;
  final List<Map<String, Object?>> rows;
  final Map<String, String> fieldLabels;
  const _MapRowsGroup({required this.title, required this.empty, required this.rows, required this.fieldLabels});

  String _v(Object? v) => (v ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text(empty, style: TextStyle(color: Colors.grey.shade700))
          else
            ...rows.map((row) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: fieldLabels.entries.map((e) {
                    final value = _v(row[e.key]);
                    if (value.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text('${e.value}：$value', style: const TextStyle(height: 1.35)),
                    );
                  }).toList()),
                )),
        ]),
      ),
    );
  }
}

class _RelationshipRowsGroup extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  const _RelationshipRowsGroup({required this.rows});

  String _v(Map<String, Object?> row, String key) => (row[key] ?? '').toString().trim();

  Future<void> _copy(BuildContext context, String text) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制表达文案')));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('关系感恩表达库', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text('暂无关系表达。', style: TextStyle(color: Colors.grey.shade700))
          else
            ...rows.map((row) {
              final light = _v(row, 'light_text');
              final concrete = _v(row, 'concrete_text');
              final deep = _v(row, 'deep_text');
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Text('对象：${_v(row, 'person')}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (_v(row, 'context').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('具体事件：${_v(row, 'context')}')),
                  const SizedBox(height: 8),
                  _CopyLine(label: '轻量版', text: light, onCopy: () => _copy(context, light)),
                  _CopyLine(label: '具体版', text: concrete, onCopy: () => _copy(context, concrete)),
                  _CopyLine(label: '深度版', text: deep, onCopy: () => _copy(context, deep)),
                  if (_v(row, 'chosen_action').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('行动选择：${_v(row, 'chosen_action')}', style: TextStyle(color: Colors.grey.shade700))),
                ]),
              );
            }),
        ]),
      ),
    );
  }
}

class _CopyLine extends StatelessWidget {
  final String label;
  final String text;
  final VoidCallback onCopy;
  const _CopyLine({required this.label, required this.text, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Expanded(child: Text('$label：$text', style: const TextStyle(height: 1.35))),
        IconButton(tooltip: '复制$label', visualDensity: VisualDensity.compact, icon: const Icon(Icons.copy_outlined, size: 18), onPressed: onCopy),
      ]),
    );
  }
}

class _ClosureActionsCard extends StatelessWidget {
  final VoidCallback onFailureReview;
  final VoidCallback onChallengeReview;
  final VoidCallback onRelationshipGratitude;
  final int primeCount;
  final int antiPrimeCount;
  final int relationshipCount;

  const _ClosureActionsCard({
    required this.onFailureReview,
    required this.onChallengeReview,
    required this.onRelationshipGratitude,
    required this.primeCount,
    required this.antiPrimeCount,
    required this.relationshipCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('闭环补全操作', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            'V5 继续补齐“生成后继续训练与管理视图”的部分：失败后更新实际痛苦/恢复，可控失败挑战执行后复盘，关系感恩生成三种表达。当前 注意力启动线索 $primeCount｜消极启动源 $antiPrimeCount｜关系感恩 $relationshipCount',
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            OutlinedButton.icon(onPressed: onFailureReview, icon: const Icon(Icons.healing_outlined), label: const Text('记录失败后恢复')),
            OutlinedButton.icon(onPressed: onChallengeReview, icon: const Icon(Icons.science_outlined), label: const Text('挑战执行复盘')),
            OutlinedButton.icon(onPressed: onRelationshipGratitude, icon: const Icon(Icons.volunteer_activism_outlined), label: const Text('关系感恩表达')),
          ]),
        ]),
      ),
    );
  }
}

class _ImplementationAuditCard extends StatelessWidget {
  final RealisticOptimismTrainingStats stats;
  const _ImplementationAuditCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      '10+ 独立入口：强度分级、情绪容器、事件重构、雷达、双镜头、失败免疫、可控失败、过程行动、注意力启动线索、消极启动源、感恩品味、身份、周报',
      '独立数据表：事件强度、过程计划、解释风格、资源视角重构、失败免疫、可控挑战、品味练习、消极启动源、行动证据、身份、基线',
      'Prompt 配置中心：全局价值层 + 所有场景层 + 输出格式层均可自由编辑',
      '长期闭环：记录 → 证据墙 → 幸福基线 → AI 周报 → 下一周训练重点',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('功能完整度审计', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...items.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[const Text('✓  '), Expanded(child: Text(e, style: const TextStyle(height: 1.35)))]),
              )),
          const SizedBox(height: 8),
          Text('当前沉淀：强度分级 ${stats.eventIntensity}｜过程计划 ${stats.processPlans}｜解释雷达 ${stats.explanationScores}｜资源视角重构 ${stats.benefitReframes}｜失败免疫 ${stats.failureImmunity}｜品味练习 ${stats.savoring}｜消极启动源 ${stats.antiPrimes}｜日常实践 ${stats.p2Artifacts}', style: TextStyle(color: Colors.grey.shade700)),
        ]),
      ),
    );
  }
}



class _V7CockpitCard extends StatelessWidget {
  final VoidCallback onEvent;
  final VoidCallback onAction;
  final VoidCallback onFailure;
  final VoidCallback onEnvironment;
  final VoidCallback onIdentity;
  final String latestAction;
  final String latestPrime;
  final String latestIdentity;
  const _V7CockpitCard({required this.onEvent, required this.onAction, required this.onFailure, required this.onEnvironment, required this.onIdentity, required this.latestAction, required this.latestPrime, required this.latestIdentity});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('今日训练驾驶舱', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('今天不需要在多个子功能里跳来跳去；只完成一条主线：看清现实 → 检查解释 → 做一个过程行动 → 复盘证据 → 设计注意力线索 → 具体感恩不遗漏好的部分。', style: TextStyle(height: 1.45)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            FilledButton.icon(onPressed: onEvent, icon: const Icon(Icons.edit_note_outlined), label: const Text('开始完整会话')),
            OutlinedButton.icon(onPressed: onAction, icon: const Icon(Icons.timer_outlined), label: const Text('设计5分钟行动')),
            OutlinedButton.icon(onPressed: onFailure, icon: const Icon(Icons.shield_outlined), label: const Text('失败复盘')),
            OutlinedButton.icon(onPressed: onEnvironment, icon: const Icon(Icons.wallpaper_outlined), label: const Text('注意力启动线索提醒')),
            OutlinedButton.icon(onPressed: onIdentity, icon: const Icon(Icons.badge_outlined), label: const Text('身份沉淀')),
          ]),
          const SizedBox(height: 12),
          _CockpitLine(label: '最近5分钟行动', value: latestAction.isEmpty ? '还没有行动证据，先设计一个小到能开始的动作。' : latestAction),
          _CockpitLine(label: '最近锁屏 注意力启动线索', value: latestPrime.isEmpty ? '还没有今日注意力启动线索，先设计一个能把你拉回价值的提醒。' : latestPrime),
          _CockpitLine(label: '最近身份句', value: latestIdentity.isEmpty ? '还没有身份沉淀，完成一次行动后再生成。' : latestIdentity),
        ]),
      ),
    );
  }
}

class _CockpitLine extends StatelessWidget {
  final String label;
  final String value;
  const _CockpitLine({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      SizedBox(width: 112, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
      Expanded(child: Text(value, maxLines: 3, overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _ProductGapFixCard extends StatelessWidget {
  final VoidCallback onStart;
  const _ProductGapFixCard({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            const Icon(Icons.construction_outlined),
            const SizedBox(width: 8),
            const Expanded(child: Text('这个模块的作用：训练一种更完整的现实观看方式', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            TextButton(onPressed: onStart, child: const Text('开始')),
          ]),
          const Divider(height: 18),
          const Text('当你失败、拖延、自责、焦虑或关系不舒服时，这里不是把坏事说成好事，而是帮你看见同一现实里的事实、解释、行动可能、环境启动和仍值得珍惜的部分。', style: TextStyle(height: 1.45)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: const <Widget>[
            Chip(label: Text('不是鸡汤')),
            Chip(label: Text('不是孤立子功能')),
            Chip(label: Text('同一会话流转')),
            Chip(label: Text('必须进入复盘')),
            Chip(label: Text('证据连接身份')),
          ]),
        ]),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label $value', style: const TextStyle(fontWeight: FontWeight.w800)));
  }
}

class _LatestRecordCard extends StatelessWidget {
  final RealisticOptimismTrainingRecord record;
  final VoidCallback onOpen;
  const _LatestRecordCard({required this.record, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(record.intensityLevel.replaceAll('L', ''))),
        title: Text(record.eventSummary.isEmpty ? record.rawInput : record.eventSummary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(record.identitySentence.isEmpty ? record.fiveMinuteAction : record.identitySentence, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.open_in_new),
        onTap: onOpen,
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final RealisticOptimismTrainingRecord record;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  const _RecordTile({required this.record, required this.onOpen, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: _levelColor(record.intensityLevel).withOpacity(.16), child: Text(record.intensityLevel, style: TextStyle(color: _levelColor(record.intensityLevel), fontWeight: FontWeight.w900))),
        title: Text(record.eventSummary.isEmpty ? record.rawInput : record.eventSummary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('主模式：${record.mainPattern.isEmpty ? '未识别' : record.mainPattern}\n5分钟行动：${record.fiveMinuteAction}', maxLines: 3, overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        onTap: onOpen,
        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final RealisticOptimismTrainingRecord record;
  const _DetailHeader({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _levelColor(record.intensityLevel).withOpacity(.10), borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            Chip(label: Text(record.intensityLevel, style: const TextStyle(fontWeight: FontWeight.w900))),
            const SizedBox(width: 8),
            Chip(label: Text(record.primaryEmotion.isEmpty ? '情绪待命名' : record.primaryEmotion)),
          ]),
          const SizedBox(height: 8),
          Text(record.rawInput, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1.4)),
          if (record.lockScreenSentence.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text('今日注意力启动线索：${record.lockScreenSentence}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _DetailSection({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(children: <Widget>[Icon(icon), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)))]),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final String label;
  final String value;
  const _KeyValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(height: 1.45)),
      ]),
    );
  }
}

class _BulletList extends StatelessWidget {
  final String title;
  final List<String> items;
  const _BulletList({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        ...items.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                const Text('•  '),
                Expanded(child: Text(e, style: const TextStyle(height: 1.38))),
              ]),
            )),
      ]),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final int score;
  const _ScoreBar({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    final v = score.clamp(0, 10) / 10.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(children: <Widget>[
        SizedBox(width: 74, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
        Expanded(child: LinearProgressIndicator(value: v, minHeight: 9, borderRadius: BorderRadius.circular(8))),
        const SizedBox(width: 10),
        Text('$score/10'),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _InfoCard({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(body, style: const TextStyle(height: 1.45)),
          ])),
        ]),
      ),
    );
  }
}


class _EvidenceGroup extends StatelessWidget {
  final String title;
  final String empty;
  final List<String> items;
  const _EvidenceGroup({required this.title, required this.empty, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text(empty, style: TextStyle(color: Colors.grey.shade700))
            else
              ...items.map((e) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(e, style: const TextStyle(height: 1.4)),
                  )),
          ],
        ),
      ),
    );
  }
}



String _rotRowText(Map<String, Object?>? row, String key) => (row == null ? '' : (row[key] ?? '').toString()).trim();

int _rotRowInt(Map<String, Object?>? row, String key) {
  if (row == null) return 0;
  final raw = row[key];
  if (raw is num) return raw.toInt();
  return int.tryParse((raw ?? '').toString()) ?? 0;
}

String _rotFriendlyStatus(String status) {
  switch (status) {
    case 'completed':
      return '已回流为证据';
    case 'failed':
      return '已进入失败免疫';
    case 'scheduled':
      return '已安排，等待执行';
    case 'active':
      return '已生成，待使用';
    case 'archived':
      return '已归档';
    case 'superseded':
      return '已被新版替换';
    case 'paused_for_safety':
      return '安全模式已暂停';
    case 'needs_review':
      return '待确认，不自动判定失败';
    default:
      return status.trim().isEmpty ? '待使用' : status;
  }
}

String _rotFriendlyType(String type) {
  switch (type) {
    case 'reality_record':
      return '真实现实记录';
    case 'todo_goal_bridge':
      return '行动桥接';
    case 'daily_review':
      return '晚间复盘';
    case 'proactive_reminder':
      return '明日注意力线索';
    case 'anti_prime_cleanup':
      return '环境清理';
    case 'monthly_report':
      return '周期报告';
    case 'safety_support':
      return '安全支持';
    case 'overdue_review':
      return '待复盘卡片';
    case 'course_card':
      return '课程知识卡';
    case 'role_model_case':
      return '榜样案例';
    case 'complete_reality':
      return '完整现实感练习';
    case 'appreciation_scan':
      return '防贬值珍惜扫描';
    case 'same_reality_interpretations':
      return '同一现实，多种解释';
    case 'loss_resource_retention':
      return '损失后的资源保留';
    case 'priming_diagnostic':
      return '启动源诊断';
    case 'identity_script_activation':
      return '身份脚本启动';
    case 'gratitude_time_in':
      return '感恩静心分享';
    case 'process_simulation_check':
      return '过程模拟校验';
    case 'psychological_immunity_experiment':
      return '心理免疫实验';
    default:
      return type.trim().isEmpty ? '日常产物' : type;
  }
}

String _rotFormatMs(int ms) {
  if (ms <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.month}/${dt.day} ${two(dt.hour)}:${two(dt.minute)}';
}

String _rotActionText(Map<String, Object?>? row, String fallback) {
  final action = _rotRowText(row, 'next_action');
  if (action.isNotEmpty) return action;
  final summary = _rotRowText(row, 'summary');
  if (summary.isNotEmpty) return summary;
  return fallback;
}

class _DailyActionFocusCard extends StatelessWidget {
  final Map<String, Object?>? row;
  final VoidCallback onCreate;
  final VoidCallback onCompleted;
  final VoidCallback onShrink;

  const _DailyActionFocusCard({
    required this.row,
    required this.onCreate,
    required this.onCompleted,
    required this.onShrink,
  });

  @override
  Widget build(BuildContext context) {
    final action = _rotActionText(row, '还没有今日行动。先从一个未完成待办中生成一个 5 分钟动作。');
    final title = _rotRowText(row, 'title').isEmpty ? '今日只做一个行动证据' : _rotRowText(row, 'title');
    final status = _rotFriendlyStatus(_rotRowText(row, 'status'));
    final scheduled = _rotFormatMs(_rotRowInt(row, 'scheduled_at_ms'));
    final hasAction = row != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: const <Widget>[
            Icon(Icons.check_circle_outline),
            SizedBox(width: 8),
            Expanded(child: Text('1. 今日行动证据', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
          ]),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(action, style: const TextStyle(height: 1.45)),
          if (hasAction) ...<Widget>[
            const SizedBox(height: 8),
            Text('状态：$status${scheduled.isEmpty ? '' : '｜计划：$scheduled'}', style: const TextStyle(color: Color(0xFF6B7280))),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.playlist_add_check_outlined), label: Text(hasAction ? '更新 5 分钟行动' : '生成 5 分钟行动')),
            OutlinedButton.icon(onPressed: hasAction ? onCompleted : null, icon: const Icon(Icons.done_all_outlined), label: const Text('我完成了')),
            OutlinedButton.icon(onPressed: hasAction ? onShrink : null, icon: const Icon(Icons.compress_outlined), label: const Text('没完成，帮我拆小')),
          ]),
          const SizedBox(height: 8),
          const Text('完成会进入行动证据；没完成会进入失败免疫并生成更小入口。', style: TextStyle(height: 1.35, color: Color(0xFF6B7280))),
        ]),
      ),
    );
  }
}

class _DailyReviewFocusCard extends StatelessWidget {
  final Map<String, Object?>? row;
  final VoidCallback onCreate;
  final VoidCallback onStart;

  const _DailyReviewFocusCard({required this.row, required this.onCreate, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final summary = _rotActionText(row, '今晚用 8 分钟复盘：行动证据、未完成卡点、一个具体感恩、一个可回味时刻、明日注意力线索。');
    final status = _rotFriendlyStatus(_rotRowText(row, 'status'));
    final scheduled = _rotFormatMs(_rotRowInt(row, 'scheduled_at_ms'));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: const <Widget>[
            Icon(Icons.nightlight_round),
            SizedBox(width: 8),
            Expanded(child: Text('2. 今晚 8 分钟复盘', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
          ]),
          const SizedBox(height: 8),
          Text(summary, style: const TextStyle(height: 1.45)),
          if (row != null) ...<Widget>[
            const SizedBox(height: 8),
            Text('状态：$status${scheduled.isEmpty ? '' : '｜计划：$scheduled'}', style: const TextStyle(color: Color(0xFF6B7280))),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.rate_review_outlined), label: const Text('开始今晚复盘')),
            OutlinedButton.icon(onPressed: onCreate, icon: const Icon(Icons.alarm_add_outlined), label: Text(row == null ? '安排复盘提醒' : '重新安排提醒')),
          ]),
        ]),
      ),
    );
  }
}

class _DailyCueFocusCard extends StatelessWidget {
  final Map<String, Object?>? row;
  final VoidCallback onCreate;
  final VoidCallback onOpenEnvironment;

  const _DailyCueFocusCard({required this.row, required this.onCreate, required this.onOpenEnvironment});

  @override
  Widget build(BuildContext context) {
    final cue = _rotRowText(row, 'trigger_text').isNotEmpty ? _rotRowText(row, 'trigger_text') : '明天还没有注意力启动线索。';
    final action = _rotActionText(row, '打开最重要任务材料，只做 5 分钟。');
    final scheduled = _rotFormatMs(_rotRowInt(row, 'scheduled_at_ms'));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: const <Widget>[
            Icon(Icons.notifications_active_outlined),
            SizedBox(width: 8),
            Expanded(child: Text('3. 明日注意力启动线索', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
          ]),
          const SizedBox(height: 8),
          Text('提醒句：$cue', style: const TextStyle(height: 1.45)),
          const SizedBox(height: 4),
          Text('配套行动：$action', style: const TextStyle(height: 1.45)),
          if (scheduled.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text('计划提醒：$scheduled', style: const TextStyle(color: Color(0xFF6B7280))),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.tips_and_updates_outlined), label: Text(row == null ? '生成明日线索' : '重新生成明日线索')),
            OutlinedButton.icon(onPressed: onOpenEnvironment, icon: const Icon(Icons.wallpaper_outlined), label: const Text('去环境页管理')),
          ]),
        ]),
      ),
    );
  }
}

class _DailyAntiPrimeCleanupCard extends StatelessWidget {
  final Map<String, Object?>? row;
  final VoidCallback onCreate;
  final VoidCallback onOpenEnvironment;

  const _DailyAntiPrimeCleanupCard({required this.row, required this.onCreate, required this.onOpenEnvironment});

  @override
  Widget build(BuildContext context) {
    final action = _rotActionText(row, '把最容易拖延的应用从首页移走，或把手机放到离手 2 米外。');
    final status = _rotFriendlyStatus(_rotRowText(row, 'status'));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: const <Widget>[
            Icon(Icons.cleaning_services_outlined),
            SizedBox(width: 8),
            Expanded(child: Text('4. 今日最小环境清理', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
          ]),
          const SizedBox(height: 8),
          Text(action, style: const TextStyle(height: 1.45)),
          if (row != null) ...<Widget>[
            const SizedBox(height: 8),
            Text('状态：$status', style: const TextStyle(color: Color(0xFF6B7280))),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.cleaning_services_outlined), label: Text(row == null ? '生成今日清理动作' : '重新生成清理动作')),
            OutlinedButton.icon(onPressed: onOpenEnvironment, icon: const Icon(Icons.wallpaper_outlined), label: const Text('去环境页查看')),
          ]),
          const SizedBox(height: 8),
          const Text('只清理一个最强消极启动源，不要求一次性改变全部环境。', style: TextStyle(height: 1.35, color: Color(0xFF6B7280))),
        ]),
      ),
    );
  }
}

class _DailyFriendlyArtifactsList extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  const _DailyFriendlyArtifactsList({required this.rows});

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.where((row) {
      final type = _rotRowText(row, 'artifact_type');
      return type == 'todo_goal_bridge' || type == 'daily_review' || type == 'proactive_reminder' || type == 'anti_prime_cleanup' || type == 'safety_support' || type == 'overdue_review';
    }).take(6).toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('最近已安排的日常闭环', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (visibleRows.isEmpty)
            const Text('暂无安排。先生成一个今日 5 分钟行动、今晚复盘或明日注意力启动线索。', style: TextStyle(height: 1.4, color: Color(0xFF6B7280)))
          else
            ...visibleRows.map((row) {
              final type = _rotFriendlyType(_rotRowText(row, 'artifact_type'));
              final title = _rotRowText(row, 'title').isEmpty ? type : _rotRowText(row, 'title');
              final status = _rotFriendlyStatus(_rotRowText(row, 'status'));
              final action = _rotActionText(row, '暂无下一步动作。');
              final when = _rotFormatMs(_rotRowInt(row, 'scheduled_at_ms'));
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text('$type｜$title\n状态：$status${when.isEmpty ? '' : '｜计划：$when'}\n下一步：$action', style: const TextStyle(height: 1.4)),
              );
            }),
        ]),
      ),
    );
  }
}

class _DailyExtensionStatusCard extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  const _DailyExtensionStatusCard({required this.rows});

  int _count(String type) => rows.where((row) => (row['artifact_type'] ?? '').toString() == type).length;

  @override
  Widget build(BuildContext context) {
    final todo = _count('todo_goal_bridge');
    final review = _count('daily_review');
    final reminder = _count('proactive_reminder');
    final antiPrime = _count('anti_prime_cleanup');
    final completed = rows.where((row) => (row['status'] ?? '').toString() == 'completed').length;
    final failed = rows.where((row) => (row['status'] ?? '').toString() == 'failed').length;
    final scheduled = rows.where((row) => (row['status'] ?? '').toString() == 'scheduled' || (row['status'] ?? '').toString() == 'active' || (row['status'] ?? '').toString() == 'needs_review').length;
    final latestAction = rows
        .map((row) => (row['next_action'] ?? row['summary'] ?? '').toString().trim())
        .firstWhere((text) => text.isNotEmpty, orElse: () => '先把一个未完成任务缩小成 5 分钟行动。');
    final status = todo == 0
        ? '第一步：先把一个未完成待办事项或卡住的任务转成 5 分钟行动。'
        : completed > 0 && review > 0 && reminder > 0
            ? '闭环已经产生真实证据：至少有一个行动完成并回流，晚间复盘和明日线索也已建立。'
            : review > 0 && reminder > 0
                ? '今日闭环已安排，等待行动完成与证据回流；现在还不能把它说成已经形成能力。'
                : review == 0
                    ? '第二步：安排或开始今晚复盘，把行动、卡点、感恩和身份沉淀到一起。'
                    : antiPrime == 0
                    ? '第四步：清理一个最强消极启动源，让注意力环境不再只靠意志硬扛。'
                    : '今日闭环已安排，等待完成与证据回流。';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('日常闭环状态', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(label: Text('行动桥接：$todo')),
                Chip(label: Text('晚间复盘：$review')),
                Chip(label: Text('明日线索：$reminder')),
                Chip(label: Text('环境清理：$antiPrime')),
                Chip(label: Text('待执行：$scheduled')),
                Chip(label: Text('行动证据：$completed')),
                Chip(label: Text('失败免疫：$failed')),
              ],
            ),
            const SizedBox(height: 8),
            Text(status, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 8),
            const Text('闭环判定：只有“完成并回流”为行动证据后，才算形成真实证据；未完成会进入失败免疫和更小行动，而不是人格失败。', style: TextStyle(height: 1.4, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            Text('最近下一步：$latestAction', style: const TextStyle(height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _P2ArtifactLibraryGroup extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  const _P2ArtifactLibraryGroup({required this.rows});

  @override
  Widget build(BuildContext context) {
    final libraryRows = rows.where((row) {
      final type = (row['artifact_type'] ?? '').toString();
      return type == 'course_card' || type == 'role_model_case';
    }).toList(growable: false);
    if (libraryRows.isEmpty) {
      return const _InfoCard(
        icon: Icons.local_library_outlined,
        title: '课程卡 / 榜样案例库',
        body: '暂无课程卡或榜样案例。先生成至少一张课程知识卡或一个榜样案例，就会在这里形成可复用资料库。',
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '课程卡 / 榜样案例库',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ...libraryRows.take(6).map((row) {
              final type = (row['artifact_type'] ?? '').toString() == 'course_card'
                  ? '课程卡'
                  : '榜样案例';
              final title = (row['title'] ?? '').toString().trim().isEmpty
                  ? type
                  : (row['title'] ?? '').toString().trim();
              final summary =
                  (row['summary'] ?? row['next_action'] ?? '').toString().trim();
              final reuse = (row['reuse_surface'] ?? '').toString().trim();
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  '$type｜$title${summary.isEmpty ? '' : '\n$summary'}${reuse.isEmpty ? '' : '\n复用位置：$reuse'}',
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _P2OperationalDigestCard extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  const _P2OperationalDigestCard({required this.rows});

  int _createdAt(Map<String, Object?> row) {
    final raw = row['created_at_ms'];
    if (raw is int) return raw;
    return int.tryParse((raw ?? '').toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final dayMs = const Duration(days: 1).inMilliseconds;
    final todayRows = rows.where((row) => nowMs - _createdAt(row) <= dayMs).length;
    final weekRows = rows.where((row) => nowMs - _createdAt(row) <= dayMs * 7).length;
    final monthRows = rows.where((row) => nowMs - _createdAt(row) <= dayMs * 30).length;
    final actionRows = rows.where((row) {
      return (row['next_action'] ?? row['summary'] ?? '').toString().trim().isNotEmpty;
    }).length;
    final reminders = rows.where((row) {
      return (row['artifact_type'] ?? '').toString() == 'proactive_reminder';
    }).length;
    final reports = rows.where((row) {
      return (row['artifact_type'] ?? '').toString() == 'monthly_report';
    }).length;
    final nextAction = rows
        .map((row) => (row['next_action'] ?? row['summary'] ?? '').toString().trim())
        .firstWhere((text) => text.isNotEmpty, orElse: () => '先创建一个待办事项转行动或明日注意力启动线索提醒。');
    final status = rows.isEmpty
        ? '还没有日常实践产物。先把一个未完成待办事项转成 5 分钟行动。'
        : reminders == 0
            ? '已有产物，但还缺主动提醒；优先补推送/锁屏/小组件触发规则。'
            : reports == 0
                ? '已有提醒闭环，但还缺周/月报；补一份趋势复盘，让日常实践可以持续回到主轴。'
                : '日常实践已有样本；下一步不是堆数量，而是确认它们是否真的服务解释、行动、注意和感恩。';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('日常实践看板', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(label: Text('今日新增：$todayRows')),
                Chip(label: Text('7天新增：$weekRows')),
                Chip(label: Text('30天新增：$monthRows')),
                Chip(label: Text('可行动延伸：$actionRows')),
              ],
            ),
            const SizedBox(height: 8),
            Text(status),
            const SizedBox(height: 8),
            Text('最近可执行动作：$nextAction'),
          ],
        ),
      ),
    );
  }
}

class _P2DeliveryCoverageCard extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  final ValueChanged<String> onGenerate;
  const _P2DeliveryCoverageCard({required this.rows, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    const labels = <String, String>{
      'todo_goal_bridge': '待办事项桥接',
      'daily_review': '每日复盘',
      'course_card': '课程卡',
      'role_model_case': '榜样案例',
      'proactive_reminder': '主动提醒',
      'monthly_report': '周/月报',
    };
    final counts = <String, int>{for (final key in labels.keys) key: 0};
    for (final row in rows) {
      final type = (row['artifact_type'] ?? '').toString();
      if (counts.containsKey(type)) counts[type] = (counts[type] ?? 0) + 1;
    }
    final missing = labels.keys.where((key) => (counts[key] ?? 0) == 0).toList(growable: false);
    final completed = labels.length - missing.length;
    final next = missing.isEmpty ? '日常实践资料已有样本；下一步是让它们回到解释、行动、注意和感恩主轴。' : '下一步优先生成：${labels[missing.first]}。';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('日常实践覆盖度', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('已覆盖 $completed / ${labels.length} 类产物'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: labels.entries
                .map((entry) => Chip(label: Text('${entry.value}：${counts[entry.key] ?? 0}')))
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
          Text(next),
          if (missing.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: missing.take(3).map((scene) {
                return OutlinedButton.icon(
                  onPressed: () => onGenerate(scene),
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text('补${labels[scene]}'),
                );
              }).toList(growable: false),
            ),
          ],
        ]),
      ),
    );
  }
}

class _IntensityDistributionCard extends StatelessWidget {
  final List<RealisticOptimismTrainingRecord> records;
  const _IntensityDistributionCard({required this.records});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{'L1': 0, 'L2': 0, 'L3': 0, 'L4': 0};
    for (final record in records) {
      final level = record.intensityLevel.trim().toUpperCase();
      counts[level] = (counts[level] ?? 0) + 1;
    }
    final safetyCount = (counts['L3'] ?? 0) + (counts['L4'] ?? 0);
    final safetyText = safetyCount == 0
        ? '目前没有高强度/安全风险记录；普通训练可以继续保持强度分级。'
        : '已有 $safetyCount 条 L3/L4 记录；这些记录应优先稳定与现实支持，不进入普通积极重构。';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('事件强度分级分布', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            for (final level in <String>['L1', 'L2', 'L3', 'L4']) Chip(label: Text('$level：${counts[level] ?? 0}')),
          ]),
          const SizedBox(height: 8),
          Text(safetyText),
        ]),
      ),
    );
  }
}

class _GratitudeSensitivityInsightCard extends StatelessWidget {
  final List<RealisticOptimismTrainingRecord> records;
  final List<Map<String, Object?>> relationshipRows;
  const _GratitudeSensitivityInsightCard({required this.records, required this.relationshipRows});

  @override
  Widget build(BuildContext context) {
    final concrete = records.where((r) => r.whatStillMatters.any((e) => e.trim().length >= 6)).length;
    final savoring = records.where((r) => r.savoringPrompt.trim().isNotEmpty).length;
    final appreciation = records.where((r) => r.smallAppreciationAction.trim().isNotEmpty).length;
    final relationships = relationshipRows.where((row) => (row['person'] ?? '').toString().trim().isNotEmpty).length;
    final totalSignals = concrete + savoring + appreciation + relationships;
    final nextAction = totalSignals == 0
        ? '先写一件非常具体的小好事：包括画面、为什么重要、今天如何表达珍惜。'
        : relationships == 0
            ? '下一步补一次关系表达：选择一个人，生成轻量/具体/深度三种感谢。'
            : '保持具体：下一条感恩必须包含对象、细节、重要性和珍惜行动。';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('感恩敏感度快照', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            Chip(label: Text('具体感恩：$concrete')),
            Chip(label: Text('30秒品味：$savoring')),
            Chip(label: Text('珍惜行动：$appreciation')),
            Chip(label: Text('关系表达：$relationships')),
          ]),
          const SizedBox(height: 8),
          Text('下一步：$nextAction'),
        ]),
      ),
    );
  }
}

class _AttentionEnvironmentInsightCard extends StatelessWidget {
  final List<Map<String, Object?>> primeRows;
  final List<Map<String, Object?>> antiPrimeRows;
  const _AttentionEnvironmentInsightCard({required this.primeRows, required this.antiPrimeRows});

  @override
  Widget build(BuildContext context) {
    final activeprimeCount = primeRows.where((row) => (row['active'] ?? 1).toString() != '0').length;
    final cleanupCount = antiPrimeRows.where((row) => (row['cleanup_action'] ?? '').toString().trim().isNotEmpty).length;
    final latestValue = primeRows.isNotEmpty ? (primeRows.first['value_word'] ?? '').toString().trim() : '';
    final latestCleanup = antiPrimeRows.isNotEmpty ? (antiPrimeRows.first['cleanup_action'] ?? '').toString().trim() : '';
    final nextAction = cleanupCount == 0
        ? '先清理一个最强 消极启动源：例如把最容易拖延的 应用 从首页移走。'
        : latestCleanup.isNotEmpty
            ? '今天继续执行：$latestCleanup'
            : '补一条具体清理动作，让注意力环境从提醒走向行动。';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('注意力环境指数快照', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            Chip(label: Text('注意力启动线索：${primeRows.length}')),
            Chip(label: Text('启用线索：$activeprimeCount')),
            Chip(label: Text('消极启动源清理：$cleanupCount')),
            if (latestValue.isNotEmpty) Chip(label: Text('最新价值词：$latestValue')),
          ]),
          const SizedBox(height: 8),
          Text('最小环境改造：$nextAction'),
        ]),
      ),
    );
  }
}

class _FailureImmunityInsightCard extends StatelessWidget {
  final List<Map<String, Object?>> failureRows;
  final List<Map<String, Object?>> challengeRows;
  const _FailureImmunityInsightCard({required this.failureRows, required this.challengeRows});

  double? _num(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final painGaps = <double>[];
    var antibodyCount = 0;
    for (final row in failureRows) {
      final predicted = _num(row['predicted_pain']);
      final actual = _num(row['actual_pain']);
      if (predicted != null && actual != null) painGaps.add(predicted - actual);
      if ((row['psychological_antibody'] ?? '').toString().trim().isNotEmpty) antibodyCount++;
    }
    for (final row in challengeRows) {
      final predicted = _num(row['predicted_pain']);
      final actual = _num(row['actual_pain']);
      if (predicted != null && actual != null) painGaps.add(predicted - actual);
      if ((row['psychological_antibody'] ?? '').toString().trim().isNotEmpty) antibodyCount++;
    }
    final avgGap = painGaps.isEmpty ? 0 : painGaps.reduce((a, b) => a + b) / painGaps.length;
    final insight = painGaps.isEmpty
        ? '还缺少“预测痛苦 vs 实际痛苦”的对照数据。下一次失败复盘后，补录实际痛苦与恢复时间。'
        : avgGap >= 0
            ? '平均看，实际痛苦比预测低 ${avgGap.toStringAsFixed(1)} 分；这可以成为“我比想象中更能承受”的心理抗体。'
            : '平均看，实际痛苦比预测高 ${avgGap.abs().toStringAsFixed(1)} 分；下次需要更早降低风险、缩小挑战或寻求现实支持。';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('失败免疫指数快照', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            Chip(label: Text('失败复盘：${failureRows.length}')),
            Chip(label: Text('可控挑战：${challengeRows.length}')),
            Chip(label: Text('心理抗体：$antibodyCount')),
            Chip(label: Text('痛苦差距样本：${painGaps.length}')),
          ]),
          const SizedBox(height: 8),
          Text(insight),
        ]),
      ),
    );
  }
}

class _IdentityTypeBreakdownCard extends StatelessWidget {
  final List<RealisticOptimismTrainingRecord> records;
  const _IdentityTypeBreakdownCard({required this.records});

  @override
  Widget build(BuildContext context) {
    final targets = <String>[
      '现实主义乐观者',
      '行动证据积累者',
      '失败后恢复者',
      '资源发现视角',
      '感恩与珍惜者',
    ];
    final counts = <String, int>{for (final target in targets) target: 0};
    for (final record in records) {
      final type = record.identityType.trim();
      if (type.isEmpty) continue;
      final matched = targets.firstWhere(
        (target) => type.contains(target) || target.contains(type),
        orElse: () => type,
      );
      counts[matched] = (counts[matched] ?? 0) + 1;
    }
    final weakest = targets.reduce((a, b) => (counts[a] ?? 0) <= (counts[b] ?? 0) ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('五类身份成长证据', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: targets.map((target) => Chip(label: Text('$target：${counts[target] ?? 0}'))).toList(growable: false),
          ),
          const SizedBox(height: 8),
          Text('建议补齐：$weakest。下一次训练后，优先生成一条对应的身份提醒。'),
        ]),
      ),
    );
  }
}

class _TrainingIndexCard extends StatelessWidget {
  final RealisticOptimismTrainingStats stats;
  const _TrainingIndexCard({required this.stats});

  double _score(int numerator, int denominator) {
    if (denominator <= 0) return 0;
    return (numerator / denominator * 10).clamp(0, 10).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final records = stats.records == 0 ? 1 : stats.records;
    final explanationIndex = _score(stats.benefitReframes + stats.explanationScores, records * 2);
    final actionIndex = _score(stats.actions + stats.processPlans, records * 2);
    final failureIndex = _score(stats.failureImmunity + stats.controlledChallenges, records * 2);
    final attentionIndex = _score(stats.primes + stats.antiPrimes, records * 2);
    final gratitudeIndex = _score(stats.gratitude + stats.savoring + stats.relationshipGratitude, records * 3);
    final identityIndex = _score(stats.identity, records);
    final indexMap = <String, double>{
      '解释风格': explanationIndex,
      '行动证据': actionIndex,
      '失败免疫': failureIndex,
      '注意力环境': attentionIndex,
      '感恩敏感': gratitudeIndex,
      '身份成长': identityIndex,
    };
    final weakest = indexMap.entries.reduce((a, b) => a.value <= b.value ? a : b);
    final nextFocus = weakest.value >= 8 ? '保持当前闭环，进入周/月报复盘。' : '优先训练${weakest.key}，先补一条对应证据。';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('训练指数快照', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            _SmallScore(label: '解释风格', value: explanationIndex),
            _SmallScore(label: '行动证据', value: actionIndex),
            _SmallScore(label: '失败免疫', value: failureIndex),
            _SmallScore(label: '注意力环境', value: attentionIndex),
            _SmallScore(label: '感恩敏感', value: gratitudeIndex),
            _SmallScore(label: '身份成长', value: identityIndex),
          ]),
          const SizedBox(height: 8),
          Text('下一个训练重点：$nextFocus', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('指数基于当前本地记录自动估算；更精细的趋势图可由周/月报继续生成。', style: TextStyle(color: Colors.grey.shade700)),
        ]),
      ),
    );
  }
}

class _BaselineCard extends StatelessWidget {
  final RealisticOptimismTrainingBaseline baseline;
  const _BaselineCard(this.baseline);

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(baseline.tsMs);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text('${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} 基线', style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _SmallScore(label: '幸福', value: baseline.happinessScore),
          _SmallScore(label: '恢复', value: baseline.recoveryScore),
          _SmallScore(label: '可影响', value: baseline.agencyScore),
          _SmallScore(label: '永久化频率', value: baseline.permanenceFrequency),
          _SmallScore(label: '感恩敏感', value: baseline.gratitudeSensitivity),
          _SmallScore(label: '行动稳定', value: baseline.actionStability),
          if (baseline.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(baseline.note)),
        ]),
      ),
    );
  }
}

class _SmallScore extends StatelessWidget {
  final String label;
  final double value;
  const _SmallScore({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: <Widget>[SizedBox(width: 88, child: Text(label)), Expanded(child: LinearProgressIndicator(value: value.clamp(0, 10) / 10)), const SizedBox(width: 8), Text(value.toStringAsFixed(1))]),
      );
}

class _DialogSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _DialogSlider({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text('$label：${value.toStringAsFixed(1)}'),
      Slider(value: value, min: 0, max: 10, divisions: 10, label: value.toStringAsFixed(1), onChanged: onChanged),
    ]);
  }
}

class _PromptBlock extends StatelessWidget {
  final String title;
  final String body;
  const _PromptBlock({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          SelectableText(body, style: const TextStyle(fontSize: 13, height: 1.42)),
        ]),
      ),
    );
  }
}

Color _levelColor(String level) {
  switch (level) {
    case 'L4':
      return Colors.red.shade700;
    case 'L3':
      return Colors.deepOrange.shade700;
    case 'L2':
      return Colors.amber.shade800;
    default:
      return Colors.green.shade700;
  }
}

class _BoundValueFlowCard extends StatelessWidget {
  const _BoundValueFlowCard();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const <Widget>[
            Text('课程主轴如何落到功能里', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text('所有子功能都只是 Lecture 7–9 主轴的不同落点，不是彼此竞争的功能堆叠。强度分级、情绪允许、解释雷达、双镜头、行动、环境、感恩和证据都必须服务同一条生命实践：', style: TextStyle(height: 1.45)),
            SizedBox(height: 10),
            Text('1. 解释塑造感受：强度分级 + 情绪允许 + 事实/解释分离', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('2. 行动塑造自我：过程模拟 + 5分钟行动 + 行动证据', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('3. 注意塑造现实：注意力启动线索 + 消极启动源清理', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('4. 感恩塑造世界观：具体感恩 + 30秒品味 + 关系表达', style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}
