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
  final TextEditingController _inputCtrl = TextEditingController();
  bool _loading = true;
  bool _generating = false;
  String _scene = 'event_reframe';
  List<RealisticOptimismTrainingRecord> _records = <RealisticOptimismTrainingRecord>[];
  List<RealisticOptimismTrainingBaseline> _baselines = <RealisticOptimismTrainingBaseline>[];
  List<Map<String, Object?>> _eventIntensityRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> _processPlanRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> _failureRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> _challengeRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> _relationshipRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> _primeRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> _antiPrimeRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> _p2Rows = <Map<String, Object?>>[];
  RealisticOptimismTrainingStats _stats = const RealisticOptimismTrainingStats(records: 0, actions: 0, baselines: 0, gratitude: 0, primes: 0, identity: 0, explanationScores: 0, benefitReframes: 0, failureImmunity: 0, controlledChallenges: 0, savoring: 0, antiPrimes: 0, relationshipGratitude: 0, eventIntensity: 0, processPlans: 0, p2Artifacts: 0);

  @override
  void initState() {
    super.initState();
    _inputCtrl.text = widget.initialInput;
    _scene = widget.scene;
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
      final records = await _dao.listRecords();
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
      if (!mounted) return;
      setState(() {
        _records = records;
        _baselines = baselines;
        _eventIntensityRows = eventIntensityRows;
        _processPlanRows = processPlanRows;
        _failureRows = failureRows;
        _challengeRows = challengeRows;
        _relationshipRows = relationshipRows;
        _primeRows = primeRows;
        _antiPrimeRows = antiPrimeRows;
        _p2Rows = p2Rows;
        _stats = stats;
        _loading = false;
      });
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
      'todo_goal_bridge': '请把一个未完成 Todo 转成现实主义乐观训练闭环：情绪允许、解释风格、Benefit Finder、明日最小行动。',
      'daily_review': '请根据今天的记录生成晚上复盘：事件、行动证据、三件具体感恩、30秒品味、身份提醒、明日 Prime。',
      'course_card': '请生成一张课程知识卡：主题是解释风格、Benefit Finder、失败免疫、Prime 或感恩品味。',
      'role_model_case': '请生成一个榜样案例：如何经历失败、解释、恢复、行动，以及我今天可模仿的最小动作。',
      'proactive_reminder': '请生成主动提醒方案：触发条件、推送文案、锁屏短句、小组件文字、5分钟行动线索。',
      'monthly_report': '请生成周/月报摘要：解释风格、行动证据、失败恢复、Prime/Anti-Prime、感恩敏感度、身份成长。',
    };
    return templates[scene] ?? '请生成一个 P2 产物。';
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
        _toast('今天没有可转入训练的未完成 Todo。');
        return;
      }
      await _openGuidedFlow('todo_goal_bridge', _todoBridgePrompt(tasks));
    } catch (e) {
      _toast('读取 Todo 失败：$e');
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
    return '【P2 Todo 自动桥接】以下是今天仍未完成的 Todo，请不要把它们简单判定为失败；请按最终方案转换为：情绪允许 → 事实/解释分离 → 解释风格雷达 → Fault/Benefit 双镜头 → 明日最小行动 → If-Then → 行动证据问题 → 可复用的 Todo 产物。\n$lines';
  }

  Future<void> _createReminderRuleTodo() async {
    try {
      final lists = await _todoDao.listLists();
      final listId = lists.isNotEmpty ? lists.first.listId : await _todoDao.createLocalList('现实主义乐观行动');
      await _todoDao.createLocalTask(
        listId: listId,
        title: '设置一条现实主义乐观主动提醒规则',
        bodyText: 'P2 主动提醒规则配置：\n1. 触发条件：例如 Todo 逾期、睡前刷信息流、自责超过 5 分钟。\n2. 提醒文案：必须短、具体、非鸡汤。\n3. 行动线索：只给一个 5 分钟动作。\n4. 复用位置：推送 / 锁屏短句 / 小组件文字 / Todo 顶部提示。\n5. 频率：每天、工作日、每周，或只在触发时。\n6. 关闭策略：如果连续 3 次忽略，就降低频率或重写文案。',
        status: 'notStarted',
        importance: 'normal',
        isMyDay: true,
      );
      _toast('已创建主动提醒规则配置 Todo。');
    } catch (e) {
      _toast('创建提醒规则 Todo 失败：$e');
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
        bodyText: 'P2 周/月报复盘清单（$monthText）：\n1. 解释风格：永久化、人格化、灾难化是否下降？\n2. 行动证据：本周期完成了多少 5 分钟行动？\n3. 失败免疫：预测痛苦与实际痛苦差距如何？恢复时间是否缩短？\n4. 注意力环境：设置了哪些 Prime，清理了哪些 Anti-Prime？\n5. 感恩敏感：记录了哪些具体感恩、品味和关系表达？\n6. 身份成长：五类身份各新增了哪些证据？\n7. 下周期只选择一个训练重点。',
        status: 'notStarted',
        importance: 'normal',
        isMyDay: true,
      );
      _toast('已创建周/月报复盘 Todo。');
    } catch (e) {
      _toast('创建周/月报 Todo 失败：$e');
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
        bodyText: 'P2 每日复盘清单（$dateText）：\n1. 今天最需要重构的一件事是什么？\n2. 我陷入了哪种解释风格？\n3. 今天完成了哪个行动证据？\n4. 三件具体感恩分别是什么？\n5. 停留 30 秒品味一个微小好体验。\n6. 生成一句“我正在成为……”身份提醒。\n7. 设置明日 Prime。',
        status: 'notStarted',
        importance: 'normal',
        isMyDay: true,
      );
      _toast('已创建今晚现实主义乐观复盘 Todo。');
    } catch (e) {
      _toast('创建复盘 Todo 失败：$e');
    }
  }

  Future<void> _createTodoFromLatestP2Action() async {
    if (_p2Rows.isEmpty) {
      _toast('暂无可回写 Todo 的 P2 产物。');
      return;
    }
    final source = _p2Rows.first;
    final action = (source['next_action'] ?? source['summary'] ?? '').toString().trim();
    if (action.isEmpty) {
      _toast('最新 P2 产物没有可回写的下一步行动。');
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
        bodyText: '来自现实主义乐观训练 P2 产物：$artifactType\n\n摘要：$summary\n\n下一步行动：$action',
        status: 'notStarted',
        importance: 'normal',
        isMyDay: true,
      );
      _toast('已把最新 P2 下一步行动写入“我的一天”Todo。');
    } catch (e) {
      _toast('回写 Todo 失败：$e');
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
      'todo_goal_bridge': 'Todo桥接',
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
        ? '1. 先补一个 Todo 桥接或主动提醒产物'
        : actions
            .asMap()
            .entries
            .map((entry) => '${entry.key + 1}. ${entry.value}')
            .join('\n');
    final text = 'P2 运营摘要\n'
        '覆盖度：$coverage\n'
        '缺口：${missing.isEmpty ? '暂无，六类产物都有样本' : missing}\n'
        '最近可执行动作：\n$actionText';
    return text;
  }

  Future<void> _copyP2OperatingDigest() async {
    final text = _buildP2OperatingDigestText();
    await Clipboard.setData(ClipboardData(text: text));
    _toast('已复制 P2 运营摘要');
  }

  Future<void> _createP2OperatingReviewTodo() async {
    try {
      final lists = await _todoDao.listLists();
      final listId = lists.isNotEmpty
          ? lists.first.listId
          : await _todoDao.createLocalList('现实主义乐观行动');
      await _todoDao.createLocalTask(
        listId: listId,
        title: '复盘 P2 运营摘要并补齐缺口',
        bodyText: '${_buildP2OperatingDigestText()}\n\n请从缺口里只选一个，生成或执行一个 P2 产物。',
        status: 'notStarted',
        importance: 'normal',
        isMyDay: true,
      );
      _toast('已创建 P2 运营复盘 Todo。');
    } catch (e) {
      _toast('创建 P2 运营复盘 Todo 失败：$e');
    }
  }

  Future<void> _sendLatestP2Reminder() async {
    final reminder = _p2Rows.cast<Map<String, Object?>>().firstWhere(
      (row) => (row['artifact_type'] ?? '').toString() == 'proactive_reminder',
      orElse: () => _p2Rows.isNotEmpty ? _p2Rows.first : <String, Object?>{},
    );
    final title = (reminder['title'] ?? '').toString().trim().isEmpty ? '现实主义乐观提醒' : (reminder['title'] ?? '').toString().trim();
    final body = (reminder['next_action'] ?? reminder['summary'] ?? '').toString().trim().isEmpty
        ? '如果开始自责，就只做一个 5 分钟行动证据。'
        : (reminder['next_action'] ?? reminder['summary']).toString().trim();
    try {
      await NotificationService.show(title: title, body: body, payload: 'realistic_optimism_training:proactive_reminder');
      _toast('已发送一条现实主义乐观提醒');
    } catch (e) {
      _toast('发送提醒失败：$e');
    }
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空现实主义乐观训练数据？'),
        content: const Text('将删除本独立模块中的事件重构、行动证据、基线、感恩、Prime 与身份沉淀数据。旧的“现实乐观信念行动系统”不受影响。'),
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
    final noteCtrl = TextEditingController();
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


  Future<void> _recordFailureRecoveryReview() async {
    if (_records.isEmpty) {
      _toast('请先生成一次训练记录，再记录失败恢复复盘。');
      return;
    }
    String selectedId = _records.first.id;
    double actualPain = 5;
    final resultCtrl = TextEditingController();
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
    final resultCtrl = TextEditingController();
    final recoveryCtrl = TextEditingController(text: '例如：30分钟后情绪下降，晚上可以继续做事');
    final lessonCtrl = TextEditingController();
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
    final personCtrl = TextEditingController();
    final contextCtrl = TextEditingController();
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


  Future<void> _openGuidedFlow(String scene, String template) async {
    final extra = widget.extraContext.isEmpty ? _recentContextJson() : widget.extraContext;
    final record = await Navigator.of(context).push<RealisticOptimismTrainingRecord>(
      MaterialPageRoute(
        builder: (_) => RotCoreBusinessFlowPage(
          initialScene: scene,
          initialText: template,
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
    return jsonEncode(<String, Object?>{'recent_records': recent, 'recent_baselines': baselines});
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
          title: const Text('现实主义乐观训练系统'),
          actions: <Widget>[
            IconButton(tooltip: 'AI 提示词统一配置中心', onPressed: _showPromptSheet, icon: const Icon(Icons.psychology_alt_outlined)),
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
              Tab(text: '训练仪表盘'),
              Tab(text: '事件重构'),
              Tab(text: '记录档案'),
              Tab(text: '能力档案'),
              Tab(text: '幸福基线'),
              Tab(text: '环境/表达'),
              Tab(text: 'P2联动'),
              Tab(text: '设计蓝图'),
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
          title: '不是假装积极，而是训练更完整的现实观看方式',
          subtitle: '现实与情绪 → 事实与解释 → 行动与预演 → 复盘与身份；用一条主线绑定全部子功能',
          actionText: '解决今天一个实际问题',
          onPressed: () => _openGuidedFlow('event_reframe', ''),
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
          onEvent: () => _openGuidedFlow('event_reframe', ''),
          onAction: () => _openGuidedFlow('process_action', '我的目标/任务是：'),
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
        _ProductGapFixCard(onStart: () => _openGuidedFlow('event_reframe', '')),
        const SizedBox(height: 12),
        const _BoundValueFlowCard(),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _MetricChip(label: '完整会话', value: '${_stats.records}'),
            _MetricChip(label: '行动证据', value: '${_stats.actions}'),
            _MetricChip(label: '失败免疫', value: '${_stats.failureImmunity}'),
            _MetricChip(label: 'Prime', value: '${_stats.primes}'),
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
        _InfoCard(
          icon: Icons.warning_amber_rounded,
          title: '先强度分级，再决定是否重构',
          body: 'L1/L2 可进入完整训练；L3 不强行积极；L4 优先安全支持。这样避免把 Benefit Finder 做成廉价正能量。',
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _scene,
          decoration: const InputDecoration(labelText: '训练场景', border: OutlineInputBorder()),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'intensity_check', child: Text('事件强度分级')),
            DropdownMenuItem(value: 'event_reframe', child: Text('今日事件重构')),
            DropdownMenuItem(value: 'emotion_container', child: Text('允许自己为人')),
            DropdownMenuItem(value: 'explanation_radar', child: Text('解释风格雷达')),
            DropdownMenuItem(value: 'dual_lens', child: Text('Fault/Benefit 双镜头')),
            DropdownMenuItem(value: 'failure_immunity', child: Text('失败免疫复盘')),
            DropdownMenuItem(value: 'controlled_failure_challenge', child: Text('可控失败挑战')),
            DropdownMenuItem(value: 'process_action', child: Text('过程模拟行动')),
            DropdownMenuItem(value: 'prime_design', child: Text('注意力 Prime 设计')),
            DropdownMenuItem(value: 'anti_prime_cleanup', child: Text('Anti-Prime 环境清理')),
            DropdownMenuItem(value: 'gratitude_savoring', child: Text('感恩与品味训练')),
            DropdownMenuItem(value: 'identity_evidence', child: Text('身份沉淀')),
            DropdownMenuItem(value: 'weekly_baseline', child: Text('幸福基线周报')),
            DropdownMenuItem(value: 'todo_goal_bridge', child: Text('Todo/目标联动')),
            DropdownMenuItem(value: 'daily_review', child: Text('每日自动复盘')),
            DropdownMenuItem(value: 'course_card', child: Text('课程知识卡')),
            DropdownMenuItem(value: 'role_model_case', child: Text('榜样案例库')),
            DropdownMenuItem(value: 'proactive_reminder', child: Text('主动提醒文案')),
            DropdownMenuItem(value: 'monthly_report', child: Text('周/月报图表')),
          ],
          onChanged: (v) => setState(() => _scene = v ?? 'event_reframe'),
        ),
        const SizedBox(height: 12),
        RotCoreValueGuideCard(
          title: RotCoreValueCopy.sceneTitle(_scene),
          body: RotCoreValueCopy.sceneBody(_scene),
          icon: Icons.lightbulb_outline,
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.alt_route_outlined,
          title: '推荐使用“引导式训练流程”',
          body: '旧的文本框仅作为兼容入口。V12 推荐从“解决今天一个实际问题”开始：同一条业务流用 4 个阶段完成现实与情绪、事实与解释、行动与预演、复盘与身份。',
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _openGuidedFlow(_scene, _inputCtrl.text.trim()),
          icon: const Icon(Icons.account_tree_outlined),
          label: const Text('打开 V12 核心价值业务闭环'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _inputCtrl,
          minLines: 7,
          maxLines: 14,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: '写下一个真实事件、目标、失败、拖延、感恩或环境困扰',
            hintText: '例如：今天我又没有学习，我感觉自己特别废，永远坚持不了。',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _generating ? null : _generate,
          icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_outlined),
          label: Text(_generating ? '正在生成完整训练闭环……' : '快速生成（兼容旧入口）'),
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          icon: Icons.schema_outlined,
          title: '生成内容覆盖最终方案',
          body: '强度分级、情绪允许、事实-解释分离、解释风格雷达、Fault/Benefit 双镜头、5分钟行动、失败免疫、感恩品味、Prime/Anti-Prime、身份沉淀。',
        ),
      ],
    );
  }

  Widget _recordsTab(ThemeData theme) {
    if (_records.isEmpty) {
      return const Center(child: Text('还没有训练记录，先从“事件重构”生成一次。'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: _records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final item = _records[i];
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
    final actionRecords = _records.where((r) => r.fiveMinuteAction.isNotEmpty).take(20).toList(growable: false);
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
          body: '这里把行动、自我效能、失败恢复、Benefit Finder、感恩品味和 Prime / Anti-Prime 记录从训练闭环中抽取出来，帮助你看到“我做过、我恢复过、我珍惜过、我继续过”。',
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
          empty: '暂无行动证据。完成一次 5 分钟行动后会出现在这里。',
          items: actionRecords.map((r) => '${r.fiveMinuteAction}\n证据：${r.identitySentence.isEmpty ? r.provedCapacity : r.identitySentence}').toList(growable: false),
        ),
        _EvidenceGroup(
          title: 'B. 我恢复过 / 失败免疫',
          empty: '暂无失败免疫记录。完成失败复盘或可控失败挑战后会出现在这里。',
          items: _records.where((r) => r.psychologicalAntibody.isNotEmpty).take(20).map((r) => '${r.psychologicalAntibody}\n下一步：${r.fiveMinuteAction}').toList(growable: false),
        ),
        _EvidenceGroup(
          title: 'C. 我能看见更多现实 / Benefit Finder',
          empty: '暂无 Benefit Finder 重构记录。',
          items: _records.where((r) => r.balancedInterpretation.isNotEmpty).take(20).map((r) => '${r.balancedInterpretation}\n主模式：${r.mainPattern}').toList(growable: false),
        ),
        _EvidenceGroup(
          title: 'D. 我会珍惜 / 感恩与品味',
          empty: '暂无感恩品味记录。',
          items: gratitudeRecords.map((r) => '${r.whatStillMatters.join('、')}\n品味：${r.savoringPrompt}\n行动：${r.smallAppreciationAction}').toList(growable: false),
        ),
        _EvidenceGroup(
          title: 'E. 我在设计注意力环境 / Prime 与 Anti-Prime',
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
            OutlinedButton.icon(onPressed: _generating ? null : _generateWeeklyReport, icon: const Icon(Icons.summarize_outlined), label: const Text('生成 AI 幸福基线周报')),
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
          body: '环境不是装饰，而是训练的外部脚手架：用 Prime 把注意力拉回价值和可控行动，用 Anti-Prime 清理会启动比较、拖延和无力感的线索。',
          icon: Icons.wallpaper_outlined,
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.wallpaper_outlined,
          title: '注意力环境与关系表达管理台',
          body: '最终方案要求 Prime、Anti-Prime、关系感恩不只生成一次，还要能被回看、复制、复用，并进入能力档案。这里集中管理这些可反复使用的现实线索。',
        ),
        const SizedBox(height: 12),
        _AttentionEnvironmentInsightCard(primeRows: _primeRows, antiPrimeRows: _antiPrimeRows),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _scene = 'prime_design';
                _inputCtrl.text = '请为我设计今天的注意力 Prime：价值词、锁屏短句、Benefit Finder 问题和一个现实物品/照片线索。';
              });
              DefaultTabController.of(context).animateTo(1);
            },
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('AI 设计 Prime'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _scene = 'anti_prime_cleanup';
                _inputCtrl.text = '请帮我识别和清理最近削弱行动、自我效能和现实主义乐观的 Anti-Prime。';
              });
              DefaultTabController.of(context).animateTo(1);
            },
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('AI 清理 Anti-Prime'),
          ),
          OutlinedButton.icon(onPressed: _recordRelationshipGratitude, icon: const Icon(Icons.volunteer_activism_outlined), label: const Text('新增关系表达')),
        ]),
        const SizedBox(height: 12),
        _MapRowsGroup(
          title: '今日/历史 Prime 启动线索',
          empty: '暂无 Prime。可从“注意力启动墙”生成，也可以通过上方按钮进入 AI 设计。',
          rows: _primeRows,
          fieldLabels: const <String, String>{'value_word': '价值词', 'reminder': '提醒语', 'widget_text': '小组件', 'benefit_question': 'Benefit 问题', 'anti_prime_cleanup_action': '清理动作'},
        ),
        _MapRowsGroup(
          title: 'Anti-Prime 清理记录',
          empty: '暂无 Anti-Prime 清理。',
          rows: _antiPrimeRows,
          fieldLabels: const <String, String>{'trigger_type': '类型', 'trigger_name': '触发源', 'effect': '影响', 'cleanup_action': '清理动作', 'replacement_prime': '替代 Prime'},
        ),
        _RelationshipRowsGroup(rows: _relationshipRows),
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
          fieldLabels: const <String, String>{'five_minute_action': '5分钟行动', 'next_three_steps_json': '三步', 'if_then_plan_json': 'If-Then'},
        ),
      ],
    );
  }


  Widget _p2DeliveryTab(ThemeData theme) {
    void open(String scene, String input) => _openGuidedFlow(scene, input);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        const RotCoreValueGuideCard(
          title: 'P2 正式落地：从练习页走向系统联动',
          body: 'P2 不再只是生成一句提醒，而是把 Todo、每日复盘、课程知识卡、榜样案例、主动提醒和周/月报都接入同一条现实主义乐观闭环。',
          icon: Icons.hub_outlined,
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.task_alt_outlined,
          title: 'Todo / 目标系统联动',
          body: '用于把“未完成”转成：情绪允许 → 解释风格 → Fault/Benefit → 明日最小行动 → 行动证据问题。',
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          FilledButton.icon(onPressed: _openTodoBridgeFromToday, icon: const Icon(Icons.playlist_add_check_outlined), label: const Text('扫描今日 Todo 并转入训练')),
          OutlinedButton.icon(onPressed: () => open('todo_goal_bridge', '这个 Todo/目标没有完成：\n原因/卡点：\n请生成情绪允许、解释风格分析、Benefit Finder 和明日最小行动。'), icon: const Icon(Icons.task_alt_outlined), label: const Text('手动 Todo 未完成转入训练')),
          OutlinedButton.icon(onPressed: () => open('daily_review', '请根据今天的记录生成晚上复盘：事件、解释风格、行动证据、三件具体感恩、30秒品味、身份提醒、明日 Prime。'), icon: const Icon(Icons.nightlight_round), label: const Text('每日自动复盘')),
          OutlinedButton.icon(onPressed: _createDailyReviewTodo, icon: const Icon(Icons.event_note_outlined), label: const Text('创建今晚复盘 Todo')),
          OutlinedButton.icon(onPressed: () => open('monthly_report', '请基于最近记录生成周/月报图表摘要：解释风格、行动证据、失败恢复、Prime/Anti-Prime、感恩敏感度、身份成长。'), icon: const Icon(Icons.insights_outlined), label: const Text('周/月报图表')),
          OutlinedButton.icon(onPressed: _createMonthlyReportTodo, icon: const Icon(Icons.event_repeat_outlined), label: const Text('创建周/月报 Todo')),
        ]),
        const SizedBox(height: 16),
        _InfoCard(
          icon: Icons.school_outlined,
          title: '课程卡与榜样案例库',
          body: '用于把 Lecture 7–9 的知识点、榜样恢复案例和“有人也做到过”的证据接入训练，而不是停留在抽象说明。',
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          OutlinedButton.icon(onPressed: () => open('course_card', '请生成一张课程知识卡：主题是解释风格 / Benefit Finder / 失败免疫 / Prime / 感恩品味。'), icon: const Icon(Icons.menu_book_outlined), label: const Text('生成课程知识卡')),
          OutlinedButton.icon(onPressed: () => open('role_model_case', '请生成一个榜样案例：他/她如何经历失败、如何解释、如何恢复、如何行动，我今天能模仿哪一个最小动作？'), icon: const Icon(Icons.groups_outlined), label: const Text('生成榜样案例')),
          OutlinedButton.icon(onPressed: () => open('proactive_reminder', '请生成一个主动提醒方案：触发条件、推送文案、锁屏短句、小组件文字、一个 5 分钟行动线索。'), icon: const Icon(Icons.notifications_active_outlined), label: const Text('主动提醒文案')),
          OutlinedButton.icon(onPressed: _createReminderRuleTodo, icon: const Icon(Icons.rule_outlined), label: const Text('创建提醒规则 Todo')),
          OutlinedButton.icon(onPressed: _copyLatestP2WidgetText, icon: const Icon(Icons.copy_outlined), label: const Text('复制锁屏/小组件文案')),
          OutlinedButton.icon(
            onPressed: _copyP2OperatingDigest,
            icon: const Icon(Icons.summarize_outlined),
            label: const Text('复制P2运营摘要'),
          ),
          OutlinedButton.icon(
            onPressed: _createP2OperatingReviewTodo,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('创建P2复盘Todo'),
          ),
          OutlinedButton.icon(onPressed: _copyP2VoiceInputTemplate, icon: const Icon(Icons.mic_none_outlined), label: const Text('复制语音输入模板')),
          OutlinedButton.icon(onPressed: _sendLatestP2Reminder, icon: const Icon(Icons.notification_add_outlined), label: const Text('发送测试提醒')),
          OutlinedButton.icon(onPressed: _createTodoFromLatestP2Action, icon: const Icon(Icons.add_task_outlined), label: const Text('下一步行动写回 Todo')),
        ]),
        const SizedBox(height: 12),
        _P2DeliveryCoverageCard(
          rows: _p2Rows,
          onGenerate: (scene) => open(scene, _p2SceneTemplate(scene)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _generateNextMissingP2Artifact,
          icon: const Icon(Icons.auto_fix_high_outlined),
          label: const Text('一键补齐缺失 P2 产物'),
        ),
        const SizedBox(height: 12),
        _P2OperationalDigestCard(rows: _p2Rows),
        const SizedBox(height: 12),
        _P2ArtifactLibraryGroup(rows: _p2Rows),
        const SizedBox(height: 12),
        _MapRowsGroup(
          title: 'P2 产物库',
          empty: '暂无 P2 产物。生成 Todo 联动、每日复盘、课程卡、榜样案例、主动提醒或周/月报后会出现在这里。',
          rows: _p2Rows,
          fieldLabels: const <String, String>{'artifact_type': '类型', 'title': '标题', 'trigger_condition': '触发条件', 'summary': '摘要', 'reuse_surface': '复用位置', 'next_action': '下一步', 'created_at_ms': '时间'},
        ),
      ],
    );
  }

  Widget _blueprintTab(ThemeData theme) {
    final items = <Map<String, String>>[
      {'title': '1. 事件强度分级', 'body': 'L1/L2/L3/L4，决定当前能否进行 Benefit Finding、感恩或失败复盘。'},
      {'title': '2. Permission to Be Human', 'body': '在重构之前先承认痛苦、羞耻、失望、愤怒与拖延。'},
      {'title': '3. 解释风格雷达', 'body': '永久化、普遍化、人格化、灾难化、无力化、过滤化。'},
      {'title': '4. Fault Finder / Benefit Finder', 'body': '同一现实双镜头：不是说坏事是好事，而是寻找仍然存在的资源和可行动性。'},
      {'title': '5. 过程模拟行动器', 'body': '结果画面 + 时间地点工具 + 第一步 + 障碍预演 + If-Then + 5分钟行动。'},
      {'title': '6. 失败免疫实验室', 'body': '预测痛苦 vs 实际痛苦，预测恢复 vs 实际恢复，沉淀心理抗体，并支持执行后补录复盘。'},
      {'title': '7. 可控失败挑战', 'body': '低风险承受不完美、拒绝、暴露和不确定性，并支持挑战执行后复盘。'},
      {'title': '8. Prime / Anti-Prime', 'body': '设计注意力启动墙，同时清理消极启动源。'},
      {'title': '9. 感恩、品味与关系表达', 'body': '具体感恩、30秒 Savoring，并生成轻量/具体/深度三种关系表达。'},
      {'title': '10. 身份与幸福基线', 'body': '把每次行动、复盘、感恩沉淀为“我正在成为……”的证据。'},
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        const _HeroPanel(
          title: '最终版独立模块蓝图',
          subtitle: '不是升级旧模块，而是在左侧菜单新增一个独立训练系统，完整落地 Lecture 7–9 的现实主义乐观、Benefit Finder、失败免疫、注意力启动和感恩品味。',
        ),
        const SizedBox(height: 12),
        ...items.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InfoCard(icon: Icons.check_circle_outline, title: e['title']!, body: e['body']!),
            )),
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

  Future<void> _markActionDone() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _dao.addActionEvidence(RealisticOptimismTrainingActionEvidence(
      id: 'rot_a_${widget.record.id}_$now',
      recordId: widget.record.id,
      action: widget.record.fiveMinuteAction,
      evidenceText: widget.record.identitySentence.isEmpty ? '我完成了一个小行动证据。' : widget.record.identitySentence,
      completed: true,
      completedAtMs: now,
      selfEfficacyScore: 6,
      createdAtMs: now,
    ));
    await _loadActions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已记录行动证据')));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final coreRefRaw = r.payload['core_value_reference'];
    final coreRef = coreRefRaw is Map ? Map<String, dynamic>.from(coreRefRaw) : <String, dynamic>{};
    final sourceAnchor = (coreRef['source_anchor'] ?? '').toString().trim();
    final sourceHow = (coreRef['how_it_applies'] ?? '').toString().trim();
    return Scaffold(
      appBar: AppBar(title: const Text('训练闭环详情')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: r.fiveMinuteAction.isEmpty ? null : _markActionDone,
        icon: const Icon(Icons.done_all_outlined),
        label: const Text('记录行动证据'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: <Widget>[
          _DetailHeader(record: r),
          const SizedBox(height: 12),
          _DetailSection(title: '价值体系与研究锚点', icon: Icons.science_outlined, children: <Widget>[
            const RotCoreValueGuideCard(title: RotCoreValueCopy.researchAnchorsTitle, body: RotCoreValueCopy.researchAnchorsBody, icon: Icons.science_outlined),
            if (sourceAnchor.isNotEmpty) _KeyValue(label: '本次使用锚点', value: sourceAnchor),
            if (sourceHow.isNotEmpty) _KeyValue(label: '如何应用到本次事件', value: sourceHow),
          ]),
          _DetailSection(title: '0. 事件强度分级', icon: Icons.rule_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('intensity_check'), body: RotCoreValueCopy.sceneBody('intensity_check'), icon: Icons.auto_awesome_outlined),
            _KeyValue(label: '等级', value: r.intensityLevel),
            _KeyValue(label: '原因', value: r.intensityReason),
            _BulletList(title: '当前适合', items: r.allowedInterventions),
            _BulletList(title: '当前不适合', items: r.blockedInterventions),
          ]),
          if (r.intensityLevel == 'L3' || r.intensityLevel == 'L4')
            _SafetySupportCard(level: r.intensityLevel),
          _DetailSection(title: '1. 允许自己为人', icon: Icons.favorite_border, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('emotion_container'), body: RotCoreValueCopy.sceneBody('emotion_container'), icon: Icons.auto_awesome_outlined),
            _KeyValue(label: '主要情绪', value: r.primaryEmotion),
            _KeyValue(label: '情绪承认', value: r.validationText),
          ]),
          _DetailSection(title: '2. 事实-解释分离', icon: Icons.fact_check_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('event_reframe'), body: RotCoreValueCopy.sceneBody('event_reframe'), icon: Icons.auto_awesome_outlined),
            _BulletList(title: '客观事实', items: r.objectiveFacts),
            _BulletList(title: '未知/假设', items: r.unknowns),
            _KeyValue(label: '自动解释', value: r.automaticInterpretation),
          ]),
          _DetailSection(title: '3. 解释风格雷达', icon: Icons.radar_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('explanation_radar'), body: RotCoreValueCopy.sceneBody('explanation_radar'), icon: Icons.auto_awesome_outlined),
            _ScoreBar(label: '永久化', score: r.permanenceScore),
            _ScoreBar(label: '普遍化', score: r.pervasivenessScore),
            _ScoreBar(label: '人格化', score: r.personalizationScore),
            _ScoreBar(label: '灾难化', score: r.catastrophizingScore),
            _ScoreBar(label: '无力化', score: r.helplessnessScore),
            _ScoreBar(label: '过滤化', score: r.filteringScore),
            _KeyValue(label: '主模式', value: r.mainPattern),
          ]),
          _DetailSection(title: '4. Fault Finder / Benefit Finder 双镜头', icon: Icons.compare_arrows_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('dual_lens'), body: RotCoreValueCopy.sceneBody('dual_lens'), icon: Icons.auto_awesome_outlined),
            _KeyValue(label: 'Fault Finder 叙事', value: r.faultFinderStory),
            _KeyValue(label: '情绪后果', value: r.emotionalEffect),
            _KeyValue(label: '行为后果', value: r.behavioralEffect),
            _KeyValue(label: 'Benefit Finder 重构', value: r.balancedInterpretation),
            _KeyValue(label: '没有否认的痛苦', value: r.notDeniedPain),
            _BulletList(title: '可能学习', items: r.possibleLearning),
            _BulletList(title: '剩余资源', items: r.remainingResources),
            _BulletList(title: '可能意义', items: r.possibleMeaning),
          ]),
          _DetailSection(title: '5. 主动性层', icon: Icons.touch_app_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('process_action'), body: RotCoreValueCopy.sceneBody('process_action'), icon: Icons.auto_awesome_outlined),
            _BulletList(title: '不可控', items: r.uncontrollableParts),
            _BulletList(title: '可影响', items: r.influenceableParts),
            _BulletList(title: '可控制', items: r.controllableActions),
          ]),
          _DetailSection(title: '6. 过程模拟行动器', icon: Icons.directions_run_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('process_action'), body: RotCoreValueCopy.sceneBody('process_action'), icon: Icons.auto_awesome_outlined),
            _KeyValue(label: '5分钟行动', value: r.fiveMinuteAction),
            _BulletList(title: '接下来三步', items: r.nextThreeSteps),
            _BulletList(title: 'If-Then 计划', items: r.ifThenPlan),
          ]),
          _DetailSection(title: '7. 失败免疫', icon: Icons.shield_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('failure_immunity'), body: RotCoreValueCopy.sceneBody('failure_immunity'), icon: Icons.auto_awesome_outlined),
            _KeyValue(label: '预测痛苦', value: r.predictedPain == null ? '' : r.predictedPain!.toStringAsFixed(1)),
            _KeyValue(label: '实际痛苦', value: r.actualPain == null ? '' : r.actualPain!.toStringAsFixed(1)),
            _KeyValue(label: '预测恢复', value: r.predictedRecovery),
            _KeyValue(label: '实际恢复', value: r.actualRecovery),
            _KeyValue(label: '心理抗体', value: r.psychologicalAntibody),
          ]),
          _DetailSection(title: '8. 感恩与品味', icon: Icons.local_florist_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('gratitude_savoring'), body: RotCoreValueCopy.sceneBody('gratitude_savoring'), icon: Icons.auto_awesome_outlined),
            _BulletList(title: '仍然重要', items: r.whatStillMatters),
            _KeyValue(label: '30秒品味', value: r.savoringPrompt),
            _KeyValue(label: '珍惜行动', value: r.smallAppreciationAction),
          ]),
          _DetailSection(title: '9. Prime / Anti-Prime', icon: Icons.wallpaper_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('prime_design'), body: RotCoreValueCopy.sceneBody('prime_design'), icon: Icons.auto_awesome_outlined),
            _KeyValue(label: '价值词', value: r.dailyValueWord),
            _KeyValue(label: '锁屏短句', value: r.lockScreenSentence),
            _KeyValue(label: 'Benefit Finder 问题', value: r.benefitFinderQuestion),
            _KeyValue(label: 'Anti-Prime 清理', value: r.antiPrimeCleanupAction),
          ]),
          _DetailSection(title: '10. 身份沉淀', icon: Icons.badge_outlined, children: <Widget>[
            RotCoreValueGuideCard(title: RotCoreValueCopy.sceneTitle('identity_evidence'), body: RotCoreValueCopy.sceneBody('identity_evidence'), icon: Icons.auto_awesome_outlined),
            _KeyValue(label: '具体行动', value: r.specificAction),
            _KeyValue(label: '证明能力', value: r.provedCapacity),
            _KeyValue(label: '身份类型', value: r.identityType),
            _KeyValue(label: '身份提醒', value: r.identitySentence),
          ]),
          if (_actions.isNotEmpty)
            _DetailSection(title: '已记录行动证据', icon: Icons.done_all_outlined, children: _actions.map((e) => _KeyValue(label: e.completed ? '已完成' : '未完成', value: '${e.action}\n${e.evidenceText}')).toList()),
          _DetailSection(title: '最终提醒', icon: Icons.flag_outlined, children: <Widget>[
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
      const _ModuleEntry(Icons.traffic_outlined, '事件强度分级', 'L1/L2/L3/L4，先决定当前适合做什么', 'intensity_check', '请先判断这件事的强度：'),
      const _ModuleEntry(Icons.edit_note_outlined, '今日事件重构', '事实-解释分离，生成 Benefit Finder 与微行动', 'event_reframe', '今天发生了一件让我难受/失败/拖延/自责的事：'),
      const _ModuleEntry(Icons.radar_outlined, '解释风格雷达', '永久化、普遍化、人格化、灾难化、无力化、过滤化', 'explanation_radar', '我脑中最强烈的一句话是：'),
      const _ModuleEntry(Icons.compare_arrows_outlined, '双镜头训练', 'Fault Finder 与 Benefit Finder 对照', 'dual_lens', '同一件事，我想看看 Fault Finder 和 Benefit Finder 会如何解释：'),
      const _ModuleEntry(Icons.favorite_border, '允许自己为人', '先容纳情绪，再温和转向行动', 'emotion_container', '我现在最强烈的情绪是：'),
      const _ModuleEntry(Icons.shield_outlined, '失败免疫实验室', '预测痛苦、实际痛苦、恢复曲线、心理抗体', 'failure_immunity', '我经历/害怕的一次失败是：'),
      const _ModuleEntry(Icons.science_outlined, '可控失败挑战', '低风险练习承受不完美和拒绝', 'controlled_failure_challenge', '我想设计一个低风险失败挑战，主题是：'),
      const _ModuleEntry(Icons.route_outlined, '过程模拟行动器', '目标拆成时间、地点、第一步、障碍、If-Then', 'process_action', '我的目标/任务是：'),
      const _ModuleEntry(Icons.wallpaper_outlined, '注意力启动墙', '价值词、照片、榜样、锁屏短句', 'prime_design', '我今天最需要被启动的状态是：'),
      const _ModuleEntry(Icons.cleaning_services_outlined, 'Anti-Prime 清理', '识别拖延、比较和无力感的环境启动源', 'anti_prime_cleanup', '最近最容易削弱我的 App/人/环境/内容是：'),
      const _ModuleEntry(Icons.local_florist_outlined, '感恩与品味', '具体感恩、30秒 Savoring、关系表达', 'gratitude_savoring', '今天仍然有一件值得珍惜的小事：'),
      const _ModuleEntry(Icons.badge_outlined, '身份沉淀', '把实际行动转成“我正在成为……”的证据', 'identity_evidence', '我刚刚完成/恢复/珍惜/重新开始的一件小事是：'),
      const _ModuleEntry(Icons.show_chart_outlined, '幸福基线周报', '追踪恢复能力、解释风格、行动证据和感恩敏感度', 'weekly_baseline', '请根据最近记录生成本周现实主义乐观成长报告：'),
      const _ModuleEntry(Icons.task_alt_outlined, 'Todo/目标联动', 'Todo 未完成后进入情绪、解释和明日最小行动闭环', 'todo_goal_bridge', '这个 Todo/目标没有完成：'),
      const _ModuleEntry(Icons.nightlight_round, '每日自动复盘', '晚上汇总今日事件、证据、感恩、身份和明日 Prime', 'daily_review', '请根据今天的记录做一次晚上复盘：'),
      const _ModuleEntry(Icons.menu_book_outlined, '课程知识卡', '把课程概念转成练习卡', 'course_card', '请生成一张现实主义乐观课程知识卡：'),
      const _ModuleEntry(Icons.groups_outlined, '榜样案例库', '用榜样失败恢复案例补充“有人也做到过”', 'role_model_case', '请生成一个榜样案例，主题是：'),
      const _ModuleEntry(Icons.notifications_active_outlined, '主动提醒文案', '生成推送/锁屏/小组件触发式提醒', 'proactive_reminder', '请为我生成一个主动提醒：'),
      const _ModuleEntry(Icons.insights_outlined, '周/月报图表', '汇总趋势、指数和下周期重点', 'monthly_report', '请生成本月现实主义乐观训练趋势报告：'),
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
            mainAxisExtent: 160,
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
                            Text('核心价值：${RotCoreValueCopy.sceneBody(m.scene)}', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade800, height: 1.25, fontWeight: FontWeight.w600)),
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
                ? '如果你现在有伤害自己或他人的冲动、计划，或无法保证安全，请立刻联系当地紧急服务、身边可信任的人，或前往最近的急诊/安全地点。本模块此时不应继续做 Benefit Finding 或感恩训练。'
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
            'V5 继续补齐“生成后继续训练与管理视图”的部分：失败后更新实际痛苦/恢复，可控失败挑战执行后复盘，关系感恩生成三种表达。当前 Prime $primeCount｜Anti-Prime $antiPrimeCount｜关系感恩 $relationshipCount',
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
      '10+ 独立入口：强度分级、情绪容器、事件重构、雷达、双镜头、失败免疫、可控失败、过程行动、Prime、Anti-Prime、感恩品味、身份、周报',
      '独立数据表：事件强度、过程计划、解释风格、Benefit 重构、失败免疫、可控挑战、Savoring、Anti-Prime、行动证据、身份、基线',
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
          Text('当前沉淀：强度分级 ${stats.eventIntensity}｜过程计划 ${stats.processPlans}｜解释雷达 ${stats.explanationScores}｜Benefit 重构 ${stats.benefitReframes}｜失败免疫 ${stats.failureImmunity}｜Savoring ${stats.savoring}｜Anti-Prime ${stats.antiPrimes}｜P2 ${stats.p2Artifacts}', style: TextStyle(color: Colors.grey.shade700)),
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
          const Text('今天不需要在多个子功能里跳来跳去；只完成一条主线：看清现实 → 检查解释 → 做一个小行动 → 复盘证据 → 设计 Prime → 沉淀身份。', style: TextStyle(height: 1.45)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            FilledButton.icon(onPressed: onEvent, icon: const Icon(Icons.edit_note_outlined), label: const Text('开始完整会话')),
            OutlinedButton.icon(onPressed: onAction, icon: const Icon(Icons.timer_outlined), label: const Text('设计5分钟行动')),
            OutlinedButton.icon(onPressed: onFailure, icon: const Icon(Icons.shield_outlined), label: const Text('失败复盘')),
            OutlinedButton.icon(onPressed: onEnvironment, icon: const Icon(Icons.wallpaper_outlined), label: const Text('Prime提醒')),
            OutlinedButton.icon(onPressed: onIdentity, icon: const Icon(Icons.badge_outlined), label: const Text('身份沉淀')),
          ]),
          const SizedBox(height: 12),
          _CockpitLine(label: '最近5分钟行动', value: latestAction.isEmpty ? '还没有行动证据，先设计一个小到能开始的动作。' : latestAction),
          _CockpitLine(label: '最近锁屏 Prime', value: latestPrime.isEmpty ? '还没有今日 Prime，先设计一个能把你拉回价值的提醒。' : latestPrime),
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
            const Expanded(child: Text('V12 核心价值环境：一个问题解决到底', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            TextButton(onPressed: onStart, child: const Text('开始')),
          ]),
          const Divider(height: 18),
          const Text('这次不再让用户在子功能之间跳转。V12 让每个子功能都带着核心价值文案进入同一条主线：现实与情绪 → 事实与解释 → 行动与预演 → 复盘与身份。强度分级、情绪允许、解释雷达、双镜头、失败免疫、感恩、Prime、身份沉淀都挂在这条主线上。', style: TextStyle(height: 1.45)),
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
            Text('今日 Prime：${record.lockScreenSentence}', style: const TextStyle(fontWeight: FontWeight.w700)),
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
        .firstWhere((text) => text.isNotEmpty, orElse: () => '先补一个 Todo 桥接或主动提醒产物。');
    final status = rows.isEmpty
        ? '还未进入 P2 运营。先生成 Todo 桥接，再补每日复盘与主动提醒。'
        : reminders == 0
            ? '已有产物，但还缺主动提醒；优先补推送/锁屏/小组件触发规则。'
            : reports == 0
                ? '已有提醒闭环，但还缺周/月报；补一份趋势复盘，让 P2 可以持续迭代。'
                : 'P2 已形成“产物→提醒→复盘”的基础运营闭环。';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('P2 运营看板', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(label: Text('今日新增：$todayRows')),
                Chip(label: Text('7天新增：$weekRows')),
                Chip(label: Text('30天新增：$monthRows')),
                Chip(label: Text('可行动产物：$actionRows')),
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
      'todo_goal_bridge': 'Todo桥接',
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
    final next = missing.isEmpty ? '六类 P2 产物都已有样本；下一步是做周/月趋势图和自动提醒规则。' : '下一步优先生成：${labels[missing.first]}。';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('P2 交付覆盖度', style: TextStyle(fontWeight: FontWeight.w900)),
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
    final activePrimeCount = primeRows.where((row) => (row['active'] ?? 1).toString() != '0').length;
    final cleanupCount = antiPrimeRows.where((row) => (row['cleanup_action'] ?? '').toString().trim().isNotEmpty).length;
    final latestValue = primeRows.isNotEmpty ? (primeRows.first['value_word'] ?? '').toString().trim() : '';
    final latestCleanup = antiPrimeRows.isNotEmpty ? (antiPrimeRows.first['cleanup_action'] ?? '').toString().trim() : '';
    final nextAction = cleanupCount == 0
        ? '先清理一个最强 Anti-Prime：例如把最容易拖延的 App 从首页移走。'
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
            Chip(label: Text('Prime：${primeRows.length}')),
            Chip(label: Text('启用线索：$activePrimeCount')),
            Chip(label: Text('Anti-Prime 清理：$cleanupCount')),
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
      'Benefit Finder',
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
    final nextFocus = weakest.value >= 8 ? '保持当前闭环，进入 P2 周/月报复盘。' : '优先训练${weakest.key}，先补一条对应证据。';
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
          Text('指数基于当前本地记录自动估算，用于补齐 P1 指标系统；更精细的趋势图可由 P2 周/月报继续生成。', style: TextStyle(color: Colors.grey.shade700)),
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
            Text('子功能绑定方式', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text('不再把强度分级、情绪允许、解释雷达、双镜头、5分钟行动、失败免疫、感恩、Prime、身份沉淀做成彼此孤立的入口。它们现在全部嵌入同一条业务流程：', style: TextStyle(height: 1.45)),
            SizedBox(height: 10),
            Text('1. 现实与情绪：强度分级 + Permission to Be Human', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('2. 事实与解释：事实/解释分离 + 解释风格雷达 + Fault/Benefit 双镜头', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('3. 行动与预演：可控点 + 5分钟行动 + 障碍预演 + If-Then', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('4. 复盘与身份：行动证据 + 失败免疫 + 感恩品味 + Prime + 身份沉淀', style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}
