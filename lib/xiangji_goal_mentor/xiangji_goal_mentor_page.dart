import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../xiangji_future_strategist/xiangji_home_page.dart';
import 'xiangji_book_service.dart';
import 'xiangji_dao.dart';
import 'xiangji_engine.dart';
import 'xiangji_goal_examples.dart';
import 'xiangji_goal_intelligence_service.dart';
import 'xiangji_grounded_ai_service.dart';
import 'xiangji_knowledge_repository.dart';
import 'xiangji_mentor_knowledge_page.dart';
import 'xiangji_mentor_upgrade_card.dart';
import 'xiangji_mentor_setting_page.dart';
import 'xiangji_models.dart';
import 'xiangji_operations_page.dart';
import 'xiangji_provider_mirror_service.dart';
import 'xiangji_reminder_service.dart';
import 'xiangji_unified_ai_adapter.dart';

const Color _ink = Color(0xFF20342D);
const Color _moss = Color(0xFF3D725D);
const Color _sand = Color(0xFFF5F0E6);
const Color _sage = Color(0xFFE6EFE9);

class XiangjiGoalMentorPage extends StatefulWidget {
  const XiangjiGoalMentorPage({
    super.key,
    this.dao,
    this.knowledgeRepository,
    this.engine,
  });

  final XiangjiGoalMentorDao? dao;
  final XiangjiKnowledgeRepository? knowledgeRepository;
  final XiangjiGoalMentorEngine? engine;

  @override
  State<XiangjiGoalMentorPage> createState() =>
      _XiangjiGoalMentorPageState();
}

class _XiangjiGoalMentorPageState extends State<XiangjiGoalMentorPage> {
  late final XiangjiGoalMentorDao _dao;
  late final XiangjiKnowledgeRepository _knowledge;
  late final XiangjiGoalMentorEngine _engine;
  late final XiangjiReminderService _reminders;
  late final XiangjiUnifiedAiAdapter _aiAdapter;
  late final XiangjiProviderMirrorService _providerMirror;
  late final XiangjiBookService _books;
  late final XiangjiGroundedAiService _grounded;
  late final XiangjiGoalIntelligenceService _intelligence;
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _outcomeController = TextEditingController();
  final TextEditingController _obstacleController = TextEditingController();
  final FocusNode _goalFocus = FocusNode();

  bool _loading = true;
  bool _working = false;
  String _error = '';
  int _tabIndex = 0;
  XiangjiKnowledgeCatalog? _catalog;
  XiangjiGoal? _goal;
  XiangjiDailyStep? _step;
  XiangjiGuidance? _guidance;
  XiangjiGoalDraft? _draft;
  XiangjiGoalPlanBundle? _planBundle;
  XiangjiGoalPlanRoute? _selectedPlanRoute;
  XiangjiGoalIntelligenceReceipt? _intelligenceReceipt;
  List<XiangjiGrowthEvidence> _evidence = const <XiangjiGrowthEvidence>[];
  List<XiangjiGoal> _allGoals = const <XiangjiGoal>[];
  List<Map<String, Object?>> _versions = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _events = const <Map<String, Object?>>[];
  List<XiangjiBookInfo> _importedBooks = const <XiangjiBookInfo>[];
  int _pendingRemoteDeletions = 0;
  XiangjiReminderSettings _reminderSettings =
      XiangjiReminderSettings.defaults();
  XiangjiZoomMode _zoomMode = XiangjiZoomMode.panorama;
  String _selectedMentorId = '';
  XiangjiGoalInterest _interest = XiangjiGoalInterest.create;
  XiangjiSupportTone _supportTone = XiangjiSupportTone.gentle;
  int _availableMinutes = 5;
  bool _allowPlanningAi = true;
  XiangjiMentorKnowledgeMigration? _mentorMigration;

  bool get _requiresMentorReselection =>
      _mentorMigration?.requiresReselection ?? false;

  @override
  void initState() {
    super.initState();
    _dao = widget.dao ?? XiangjiGoalMentorDao();
    _knowledge = widget.knowledgeRepository ?? XiangjiKnowledgeRepository();
    _engine = widget.engine ?? XiangjiGoalMentorEngine();
    _reminders = XiangjiReminderService(dao: _dao);
    _aiAdapter = XiangjiUnifiedAiAdapter();
    _providerMirror = XiangjiProviderMirrorService(
      dao: _dao,
      configResolver: _aiAdapter.resolveOpenAiConfig,
    );
    _books = XiangjiBookService(
      dao: _dao,
      mirrorService: _providerMirror,
    );
    _grounded = XiangjiGroundedAiService(
      dao: _dao,
      mirrorService: _providerMirror,
      generator: _aiAdapter.generate,
    );
    _intelligence = XiangjiGoalIntelligenceService(
      engine: _engine,
      generator: _aiAdapter.generate,
    );
    _reload();
  }

  @override
  void dispose() {
    _goalController.dispose();
    _outcomeController.dispose();
    _obstacleController.dispose();
    _goalFocus.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }
    try {
      try {
        await _books.retryPendingProviderDeletions();
      } catch (_) {}
      final catalog = await _knowledge.load();
      final goal = await _dao.activeGoal();
      if (goal != null) await _dao.markGoalSeen(goal.id);
      final mentorMigration = goal == null
          ? null
          : await _dao.ensureMentorKnowledgeCompatibility(
              goal: goal,
              validMentorIds:
                  catalog.systems.map((item) => item.id).toSet(),
              targetKnowledgeVersion: catalog.version,
            );
      final step = goal == null ? null : await _dao.currentStep(goal.id);
      final evidence =
          goal == null ? const <XiangjiGrowthEvidence>[] : await _dao.evidenceForGoal(goal.id);
      final goals = await _dao.allGoals();
      final versions = goal == null
          ? const <Map<String, Object?>>[]
          : await _dao.goalVersions(goal.id);
      final events = goal == null
          ? const <Map<String, Object?>>[]
          : await _dao.stateEvents(goal.id);
      final settings = await _dao.reminderSettings();
      final imported = await _dao.importedBooks();
      final receiptJson = goal == null
          ? null
          : await _dao.latestGoalIntelligenceReceipt(goal.id);
      final pendingRemoteDeletions =
          (await _dao.pendingProviderDeletions()).length;
      XiangjiGuidance? guidance;
      if (goal != null && mentorMigration == null) {
        guidance = _engine.guidanceFor(
          '${goal.originalText} ${step?.status ?? ''}',
          catalog,
          currentSystemId: goal.primaryThinkerId,
          actionText: step?.actionText ?? '',
        );
      }
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _goal = goal;
        _step = step;
        _evidence = evidence;
        _allGoals = goals;
        _versions = versions;
        _events = events;
        _reminderSettings = settings;
        _importedBooks = imported;
        _pendingRemoteDeletions = pendingRemoteDeletions;
        _guidance = guidance;
        _intelligenceReceipt = receiptJson == null
            ? null
            : XiangjiGoalIntelligenceReceipt.fromJson(receiptJson);
        _mentorMigration = mentorMigration;
        _selectedMentorId = goal == null
            ? (catalog.system(_selectedMentorId)?.id ?? '')
            : mentorMigration == null
                ? goal.primaryThinkerId
                : '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cleanError(error);
      });
    }
  }

  Future<void> _createDraft() async {
    final text = _goalController.text.trim();
    if (text.isEmpty || _catalog == null) {
      _showMessage('先写一句你想解决的问题、想实现的目标，或想改变的现状。');
      return;
    }
    final safety = _engine.assessSafety(text);
    if (safety.highRisk) {
      await _showSafetyDialog(safety.message);
      return;
    }
    setState(() => _working = true);
    try {
      final bundle = await _intelligence.generate(
        need: text,
        desiredOutcome: _outcomeController.text,
        obstacle: _obstacleController.text,
        profile: XiangjiGoalSupportProfile(
          interest: _interest,
          tone: _supportTone,
          minutes: _availableMinutes,
        ),
        catalog: _catalog!,
        allowAi: _allowPlanningAi,
        preferredMentorId: _selectedMentorId,
      );
      final selected = bundle.routes.first;
      if (!mounted) return;
      setState(() {
        _planBundle = bundle;
        _selectedPlanRoute = selected;
        _draft = selected.draft;
        _selectedMentorId = selected.mentorId;
        _intelligenceReceipt = bundle.receipt;
      });
    } catch (error) {
      _showMessage(_cleanError(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _selectPlanRoute(XiangjiGoalPlanRoute route) {
    setState(() {
      _selectedPlanRoute = route;
      _draft = route.draft;
      _selectedMentorId = route.mentorId;
    });
  }

  Future<void> _chooseExample() async {
    final example = await showModalBottomSheet<XiangjiGoalExample>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: <Widget>[
            const ListTile(
              title: Text('用一个跑通的案例开始', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('会填入真实目标、期望结果、阻碍和轻量偏好；你可以随时修改。'),
            ),
            ...xiangjiGoalExamples.map(
              (item) => Card(
                child: ExpansionTile(
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('案例产出：${item.expectedOutput}'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: <Widget>[
                    Align(alignment: Alignment.centerLeft, child: Text('输入：${item.need}')),
                    const SizedBox(height: 8),
                    ...item.sevenDayTrace.map((trace) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Align(alignment: Alignment.centerLeft, child: Text(trace, style: const TextStyle(fontSize: 12))),
                    )),
                    const SizedBox(height: 4),
                    Align(alignment: Alignment.centerLeft, child: Text('复盘：${item.review}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, item),
                        child: const Text('用这个案例填写'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (example == null || !mounted) return;
    setState(() {
      _goalController.text = example.need;
      _outcomeController.text = example.desiredOutcome;
      _obstacleController.text = example.obstacle;
      _interest = example.interest;
      _supportTone = example.tone;
      _availableMinutes = example.minutes;
      _draft = null;
      _planBundle = null;
      _selectedPlanRoute = null;
    });
    _goalFocus.requestFocus();
  }

  Future<void> _openGoalAssistant() async {
    final controller = TextEditingController();
    XiangjiGoalAssistantAnswer? answer;
    var asking = false;
    var allowAi = true;
    final catalog = _catalog;
    if (catalog == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> ask([String? shortcut]) async {
            if (shortcut != null) controller.text = shortcut;
            if (asking) return;
            setSheetState(() => asking = true);
            final result = await _intelligence.answer(
              question: controller.text,
              catalog: catalog,
              goal: _goal,
              step: _step ?? _draft?.step,
              guidance: _guidance ?? _draft?.guidance,
              allowAi: allowAi,
            );
            if (!context.mounted) return;
            setSheetState(() {
              answer = result;
              asking = false;
            });
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              4,
              18,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('目标导师助手', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  const Text('问怎么填、怎么选、为什么这样做，或卡住后怎么继续。', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <String>[
                      '我现在该做什么？',
                      '我卡住了怎么办？',
                      '为什么这样设计？',
                      '思想依据在哪里？',
                    ].map((text) => ActionChip(label: Text(text), onPressed: () => ask(text))).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '直接提问',
                      hintText: '例如：这个成功标准应该怎么填？',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: allowAi,
                    onChanged: (value) => setSheetState(() => allowAi = value),
                    title: const Text('本次允许 AI 补充回答'),
                    subtitle: const Text('未配置或回答不合格时，本地操作助手自动接管。'),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: asking ? null : ask,
                      icon: const Icon(Icons.send_outlined),
                      label: Text(asking ? '正在回答…' : '回答这个问题'),
                    ),
                  ),
                  if (answer != null) ...<Widget>[
                    const SizedBox(height: 16),
                    _SectionCard(
                      color: _sage,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(answer!.modeLabel, style: const TextStyle(color: _moss, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text(answer!.text, style: const TextStyle(height: 1.55)),
                          if (answer!.sourceLabels.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 10),
                            Text('依据：${answer!.sourceLabels.join('；')}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
  }

  Future<void> _openMentorKnowledge() async {
    final catalog = _catalog;
    if (catalog == null) return;
    final enabled = await _dao.featureEnabled('goal_first_v21');
    if (!mounted) return;
    if (!enabled && !_requiresMentorReselection) {
      _showMessage('目标优先导师层当前未进入本机灰度范围。');
      return;
    }
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => XiangjiMentorKnowledgePage(
          catalog: catalog,
          selectedMentorId: _selectedMentorId,
          onEvent: (eventName, properties) => _dao.recordAnalyticsEvent(
            eventName,
            goalId: _goal?.id,
            properties: properties,
          ),
          onSelect: (thinkerId) async {
            final mentor = catalog.system(thinkerId);
            if (mentor == null) throw StateError('导师知识资产不存在');
            final goal = _goal;
            if (goal == null) {
              if (!mounted) return;
              setState(() {
                _selectedMentorId = thinkerId;
                _draft = null;
              });
              return;
            }
            setState(() => _working = true);
            try {
              final resolvingKnowledgeUpgrade = _requiresMentorReselection;
              final guidance = _engine.guidanceFor(
                goal.originalText,
                catalog,
                currentSystemId: thinkerId,
              );
              final updated = await _dao.changeMentor(
                goal: goal,
                guidance: guidance,
                reason: resolvingKnowledgeUpgrade
                    ? '知识库升级后由用户重新选择导师'
                    : '用户主动更换导师',
                reasonCode: resolvingKnowledgeUpgrade
                    ? 'knowledge_upgrade_reselected'
                    : 'user_changed',
                kbVersion: catalog.version,
              );
              final next = _engine.createStep(
                updated.originalText,
                guidance,
                system: mentor,
              );
              if (updated.state == XiangjiGoalState.active ||
                  updated.state == XiangjiGoalState.feedback ||
                  updated.state == XiangjiGoalState.calibrating ||
                  updated.state == XiangjiGoalState.paused) {
                await _dao.replaceCurrentStep(
                  updated,
                  next,
                  trigger: 'mentor_changed',
                );
              }
              await _reload();
            } finally {
              if (mounted) setState(() => _working = false);
            }
          },
        ),
      ),
    );
  }

  Future<void> _openMentorSetting() async {
    if (!await _ensureCurrentMentorCompatible()) return;
    final goal = _goal;
    final catalog = _catalog;
    if (goal == null || catalog == null) return;
    final mentor = catalog.system(goal.primaryThinkerId);
    if (mentor == null || mentor.settingSteps.length != 8) {
      _showMessage('当前导师的 8 步目标设定资产不完整。');
      return;
    }
    final progress = await _dao.mentorSettingProgress(goal.id);
    final rawAnswers = progress['answers'];
    final answers = <String, String>{};
    if (rawAnswers is Map) {
      for (final entry in rawAnswers.entries) {
        answers[entry.key.toString()] = entry.value.toString();
      }
    }
    if (!mounted) return;
    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => XiangjiMentorSettingPage(
          mentor: mentor,
          initialAnswers: answers,
          onProgress: (stepIndex, values, completed) =>
              _dao.saveMentorSettingProgress(
            goalId: goal.id,
            thinkerId: mentor.id,
            stepIndex: stepIndex,
            answers: values,
            completed: completed,
          ),
        ),
      ),
    );
    if (result != null) {
      _showMessage('8 步目标设定已完成并仅保存在本机。');
    }
  }

  Future<void> _openFutureStrategist() async {
    final enabled = await _dao.featureEnabled('future_strategist_bridge');
    if (!mounted) return;
    if (!enabled) {
      _showMessage('深度战略空间当前未进入本机灰度范围。');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const XiangjiFutureStrategistHomePage(),
      ),
    );
  }

  Future<void> _openOperations() async {
    final catalog = _catalog;
    if (catalog == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => XiangjiOperationsPage(
          dao: _dao,
          catalog: catalog,
        ),
      ),
    );
  }

  Future<void> _editDraft() async {
    final current = _draft;
    if (current == null || _catalog == null) return;
    final original = TextEditingController(text: current.originalText);
    final why = TextEditingController(text: current.whyText);
    final values = TextEditingController(text: current.higherValues.join('、'));
    final success = TextEditingController(text: current.successDefinition);
    final scope = TextEditingController(text: current.scopeText);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('按你的原话修改'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: original,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '目标原话',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: why,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '为什么对你重要',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: values,
                decoration: const InputDecoration(
                  labelText: '高层价值（用、分隔）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: success,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '怎样算向前走了一步',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: scope,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '当前范围',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              <String>[
                original.text.trim(),
                why.text.trim(),
                values.text.trim(),
                success.text.trim(),
                scope.text.trim(),
              ],
            ),
            child: const Text('保存修改'),
          ),
        ],
      ),
    );
    original.dispose();
    why.dispose();
    values.dispose();
    success.dispose();
    scope.dispose();
    if (result == null || result.first.isEmpty) return;
    final safety = _engine.assessSafety(result.join(' '));
    if (safety.highRisk) {
      await _showSafetyDialog(safety.message);
      return;
    }
    final regenerated = _engine.buildDraft(
      result.first,
      _catalog!,
      selectedMentorId: current.guidance.systemId,
    );
    final parsedValues = result[2]
        .split(RegExp('[、,，]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(5)
        .toList();
    if (!mounted) return;
    final updatedDraft = regenerated.copyWith(
      whyText: result[1].isEmpty ? regenerated.whyText : result[1],
      higherValues: parsedValues.isEmpty ? regenerated.higherValues : parsedValues,
      successDefinition: result[3].isEmpty ? regenerated.successDefinition : result[3],
      scopeText: result[4].isEmpty ? regenerated.scopeText : result[4],
    );
    final currentRoute = _selectedPlanRoute;
    setState(() {
      _draft = updatedDraft;
      if (currentRoute != null) {
        _selectedPlanRoute = XiangjiGoalPlanRoute(
          id: currentRoute.id,
          title: currentRoute.title,
          promise: currentRoute.promise,
          mentorId: updatedDraft.guidance.systemId,
          mentorName: updatedDraft.guidance.mentorName,
          understanding: updatedDraft.whyText,
          blindSpot: currentRoute.blindSpot,
          output: currentRoute.output,
          whyItWorks: currentRoute.whyItWorks,
          successSignal: updatedDraft.successDefinition,
          draft: updatedDraft,
          applications: currentRoute.applications,
        );
      }
      _goalController.text = result.first;
    });
  }

  Future<void> _confirmDraft() async {
    final draft = _draft;
    if (draft == null || _catalog == null) return;
    setState(() => _working = true);
    try {
      await _dao.createAndActivateGoal(
        draft,
        kbVersion: _catalog!.version,
        intelligenceReceipt: _planBundle?.receipt.toJson(),
      );
      if (!mounted) return;
      setState(() {
        _draft = null;
        _planBundle = null;
        _selectedPlanRoute = null;
      });
      await _reload();
      if (!mounted) return;
      final enable = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('让目标保持在场？'),
          content: const Text('向己可以每天轻轻提醒一次你的目标原话或今日一步，不记录断签，也不会用比较催促你。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('以后再说'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('每天 09:00 提醒'),
            ),
          ],
        ),
      );
      if (enable == true) {
        _reminderSettings = await _reminders.update(
          enabled: true,
          timeOfDay: '09:00',
          quietStart: _reminderSettings.quietStart,
          quietEnd: _reminderSettings.quietEnd,
        );
        if (mounted) setState(() {});
      }
    } catch (error) {
      _showMessage(
        _cleanError(error).contains('GOAL_ACTIVE_CONFLICT')
            ? '当前已有一个主目标。请先通过目标校准重选，或完成并归档这段旅程。'
            : _cleanError(error),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _markStarted() async {
    final step = _step;
    if (step == null) return;
    await _dao.markStepStarted(step.id);
    _showMessage('已经开始。只需要完成最低标准，不用把今天变成一次证明。');
    await _reload();
  }

  Future<void> _shrinkStep() async {
    final goal = _goal;
    final step = _step;
    if (goal == null || step == null) return;
    setState(() => _working = true);
    try {
      await _dao.replaceCurrentStep(
        goal,
        _engine.shrinkStep(step),
        trigger: 'step_shrunk',
      );
      await _reload();
      _showMessage('已缩小。方向没有改变，只降低了启动负担。');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _replaceStep() async {
    final goal = _goal;
    final step = _step;
    if (goal == null || step == null) return;
    setState(() => _working = true);
    try {
      await _dao.replaceCurrentStep(
        goal,
        _engine.alternativeStep(goal, step),
        trigger: 'method_changed',
      );
      await _reload();
      _showMessage('已换一种推进方式。目标保留，方法可以改变。');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _submitCheckin(XiangjiCheckinResult result) async {
    final goal = _goal;
    final step = _step;
    if (goal == null || step == null) return;
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.prompt),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: result == XiangjiCheckinResult.blocked
                ? '例如：精力不足、缺少信息、时间窗口消失……'
                : result == XiangjiCheckinResult.noLongerRelevant
                    ? '例如：目标改变、路径不再匹配，或现实条件已经变化……'
                    : '完成了什么、学到了什么，或调整了什么？',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;
    final safety = _engine.assessSafety(note);
    if (safety.highRisk) {
      await _showSafetyDialog(safety.message);
      return;
    }
    final evidenceType = await _chooseEvidenceType(result.defaultEvidenceType);
    if (evidenceType == null) return;
    final summary = _engine.evidenceSummary(
      step: step,
      resultType: result.value,
      userText: note,
    );
    final evidenceId = await _dao.addCheckinAndEvidenceDraft(
      goal: goal,
      step: step,
      resultType: result.value,
      userText: note,
      evidenceType: evidenceType.value,
      evidenceSummary: summary,
    );
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('确认成长证据'),
        content: Text(summary),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('不保存'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认保存'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _dao.confirmEvidence(evidenceId);
    } else {
      await _dao.discardEvidenceDraft(evidenceId);
    }
    await _reload();
    if ((result == XiangjiCheckinResult.blocked ||
            result == XiangjiCheckinResult.noLongerRelevant) &&
        mounted) {
      final calibrate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('不把受阻解释成失败'),
          content: const Text('要不要用四个很短的判断，看看应继续、改法、缩小、暂停还是重选？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('暂时不用'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('开始校准'),
            ),
          ],
        ),
      );
      if (calibrate == true) await _openCalibration();
    }
  }

  Future<XiangjiEvidenceType?> _chooseEvidenceType(
    XiangjiEvidenceType suggested,
  ) {
    return showDialog<XiangjiEvidenceType>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('这更像哪一种成长证据？'),
        children: XiangjiEvidenceType.values
            .map(
              (type) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, type),
                child: Row(
                  children: <Widget>[
                    Icon(
                      type == suggested
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: type == suggested ? _moss : Colors.black38,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(type.label)),
                    if (type == suggested)
                      const Text(
                        '建议',
                        style: TextStyle(color: _moss, fontSize: 12),
                      ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> _generateNextStep() async {
    final goal = _goal;
    final guidance = _guidance;
    if (goal == null || guidance == null) return;
    await _dao.replaceCurrentStep(
      goal,
      _engine.createStep(
        goal.originalText,
        guidance,
        system: _catalog?.system(goal.primaryThinkerId),
      ),
      trigger: 'next_step_generated',
    );
    await _reload();
  }

  Future<void> _openLostMode() async {
    if (!await _ensureCurrentMentorCompatible()) return;
    final goal = _goal;
    final catalog = _catalog;
    if (goal == null || catalog == null) return;
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('先不增加任务'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('你原来最不想忘记的是：\n“${goal.originalText}”'),
            const SizedBox(height: 12),
            const Text('我们只确认你现在迷失在哪一层。'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '用一句话说说此刻发生了什么',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('看清当前一层'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (input == null || input.isEmpty) return;
    final safety = _engine.assessSafety(input);
    if (safety.highRisk) {
      await _showSafetyDialog(safety.message);
      return;
    }
    final previousGuidance = _guidance;
    final guidance = _engine.guidanceFor(
      '${goal.originalText} $input',
      catalog,
      currentSystemId: goal.primaryThinkerId,
      actionText: _step?.actionText ?? '',
    );
    await _dao.saveGuidance(
      goal: goal,
      userInput: input,
      guidance: guidance,
      zoomMode: XiangjiZoomMode.detail,
      kbVersion: catalog.version,
    );
    if (!mounted) return;
    var relayText = '';
    if (previousGuidance != null &&
        previousGuidance.systemId != guidance.systemId) {
      relayText = '导师接力：${previousGuidance.mentorName} 已帮你看见“${previousGuidance.mechanismLabel}”；'
          '你刚才的描述把当前问题转为“${guidance.mechanismLabel}”，因此由 ${guidance.mentorName} 接手。'
          '交接点仍是你的目标原话，不另起一套任务。';
    }
    setState(() {
      _guidance = guidance;
      _zoomMode = XiangjiZoomMode.detail;
    });
    final shrink = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                guidance.mechanismLabel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(guidance.coreJudgment),
              const SizedBox(height: 12),
              Text(
                '当前视角：${guidance.mentorName}',
                style: const TextStyle(color: _moss, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text('边界：${guidance.boundaryNote}'),
              if (relayText.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _sage,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    relayText,
                    style: const TextStyle(height: 1.45),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.compress),
                  label: const Text('把当前一步再缩小'),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('先只看清问题，不增加动作'),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
    if (shrink == true) await _shrinkStep();
  }

  Future<void> _openCalibration() async {
    if (!await _ensureCurrentMentorCompatible()) return;
    final goal = _goal;
    if (goal == null) return;
    final decision = await Navigator.of(context).push<XiangjiCalibrationDecision>(
      MaterialPageRoute(
        builder: (_) => XiangjiCalibrationPage(goal: goal, engine: _engine),
      ),
    );
    if (decision == null) return;
    final oldStep = _step;
    await _dao.applyCalibration(goal, decision);
    if (decision.result == XiangjiCalibrationResult.pause ||
        decision.result == XiangjiCalibrationResult.reselect) {
      if (_reminderSettings.enabled) {
        _reminderSettings = await _reminders.update(
          enabled: false,
          timeOfDay: _reminderSettings.timeOfDay,
          quietStart: _reminderSettings.quietStart,
          quietEnd: _reminderSettings.quietEnd,
        );
      }
    } else if (oldStep != null) {
      final refreshed = await _dao.goalById(goal.id);
      if (refreshed != null) {
        var stepGoal = refreshed;
        XiangjiDailyStep next;
        if (decision.result == XiangjiCalibrationResult.reduceScope) {
          stepGoal = await _dao.updateGoalVersion(
            goal: refreshed,
            originalText: refreshed.originalText,
            whyText: refreshed.whyText,
            higherValues: refreshed.higherValues,
            successDefinition: refreshed.successDefinition,
            scopeText: '未来 24 小时内，只保留一个由自己控制、可留下证据的行动。',
          );
          next = _engine.shrinkStep(oldStep);
        } else if (decision.result == XiangjiCalibrationResult.changeMethod) {
          next = _engine.alternativeStep(stepGoal, oldStep);
        } else {
          next = _engine.createStep(
            stepGoal.originalText,
            _guidance ??
                _engine.guidanceFor(
                  stepGoal.originalText,
                  _catalog!,
                  currentSystemId: stepGoal.primaryThinkerId,
                ),
            system: _catalog!.system(stepGoal.primaryThinkerId),
          );
        }
        await _dao.replaceCurrentStep(
          stepGoal,
          next,
          trigger: decision.result.value,
        );
      }
    }
    await _reload();
    _showMessage('${decision.result.label}：${decision.result.description}');
  }

  Future<void> _editActiveGoal() async {
    if (!await _ensureCurrentMentorCompatible()) return;
    final goal = _goal;
    if (goal == null) return;
    final original = TextEditingController(text: goal.originalText);
    final why = TextEditingController(text: goal.whyText);
    final values = TextEditingController(text: goal.higherValues.join('、'));
    final success = TextEditingController(text: goal.successDefinition);
    final scope = TextEditingController(text: goal.scopeText);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建一个新目标版本'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: original,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '目标原话'),
              ),
              TextField(
                controller: why,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '为什么重要'),
              ),
              TextField(
                controller: values,
                decoration: const InputDecoration(labelText: '高层价值（用、分隔）'),
              ),
              TextField(
                controller: success,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '怎样算向前走了一步'),
              ),
              TextField(
                controller: scope,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '当前范围'),
              ),
              const SizedBox(height: 8),
              const Text(
                '保存后会创建新版本，旧版本不会被静默覆盖。',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              <String>[
                original.text.trim(),
                why.text.trim(),
                values.text.trim(),
                success.text.trim(),
                scope.text.trim(),
              ],
            ),
            child: const Text('保存新版本'),
          ),
        ],
      ),
    );
    original.dispose();
    why.dispose();
    values.dispose();
    success.dispose();
    scope.dispose();
    if (result == null || result.first.isEmpty) return;
    final safety = _engine.assessSafety(result.join(' '));
    if (safety.highRisk) {
      await _showSafetyDialog(safety.message);
      return;
    }
    final parsedValues = result[2]
        .split(RegExp('[、,，]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(5)
        .toList();
    final updated = await _dao.updateGoalVersion(
      goal: goal,
      originalText: result[0],
      whyText: result[1].isEmpty ? goal.whyText : result[1],
      higherValues: parsedValues.isEmpty ? goal.higherValues : parsedValues,
      successDefinition: result[3].isEmpty ? goal.successDefinition : result[3],
      scopeText: result[4].isEmpty ? goal.scopeText : result[4],
    );
    final catalog = _catalog;
    if (catalog != null) {
      final guidance = _engine.guidanceFor(
        '${updated.originalText} ${updated.whyText}',
        catalog,
        currentSystemId: updated.primaryThinkerId,
      );
      await _dao.saveGuidance(
        goal: updated,
        userInput: updated.originalText,
        guidance: guidance,
        zoomMode: XiangjiZoomMode.panorama,
        kbVersion: catalog.version,
      );
      await _dao.replaceCurrentStep(
        updated,
        _engine.createStep(
          updated.originalText,
          guidance,
          system: catalog.system(updated.primaryThinkerId),
        ),
        trigger: 'goal_version_changed',
      );
    }
    await _reload();
  }

  Future<void> _togglePause() async {
    final goal = _goal;
    if (goal == null) return;
    if (goal.state == XiangjiGoalState.paused) {
      await _dao.transitionGoal(
        goal,
        XiangjiGoalState.active,
        trigger: 'user_resumed',
        reason: '用户选择重新连接目标',
      );
    } else if (goal.state == XiangjiGoalState.active) {
      await _dao.transitionGoal(
        goal,
        XiangjiGoalState.paused,
        trigger: 'user_paused',
        reason: '用户选择暂停推进并保留目标',
      );
      if (_reminderSettings.enabled) {
        _reminderSettings = await _reminders.update(
          enabled: false,
          timeOfDay: _reminderSettings.timeOfDay,
          quietStart: _reminderSettings.quietStart,
          quietEnd: _reminderSettings.quietEnd,
        );
      }
    } else {
      _showMessage('当前处于${goal.state.label}，请先用目标校准判断是否暂停。');
      return;
    }
    await _reload();
  }

  Future<void> _completeGoal() async {
    final goal = _goal;
    if (goal == null ||
        (goal.state != XiangjiGoalState.active &&
            goal.state != XiangjiGoalState.feedback)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认这段目标已经完成？'),
        content: const Text('完成后不会立刻制造更高目标。向己会先保留成果、能力和过程价值。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('再想想')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认完成')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _dao.transitionGoal(
      goal,
      XiangjiGoalState.completed,
      trigger: 'goal_completed',
      reason: '用户确认目标完成，进入成果整合',
    );
    await _reload();
  }

  Future<void> _archiveCompletedGoal() async {
    final goal = _goal;
    if (goal == null || goal.state != XiangjiGoalState.completed) return;
    await _dao.transitionGoal(
      goal,
      XiangjiGoalState.archived,
      trigger: 'goal_archived',
      reason: '成果已经整合，用户选择结束这段旅程',
    );
    if (_reminderSettings.enabled) {
      _reminderSettings = await _reminders.update(
        enabled: false,
        timeOfDay: _reminderSettings.timeOfDay,
        quietStart: _reminderSettings.quietStart,
        quietEnd: _reminderSettings.quietEnd,
      );
    }
    await _reload();
  }

  Future<void> _showHistoricalGoal(XiangjiGoal goal) async {
    final versions = await _dao.goalVersions(goal.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.86,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(child: Text('历史目标', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
                  _Pill(text: goal.state.label),
                ],
              ),
              const SizedBox(height: 10),
              Text(goal.originalText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.4)),
              const SizedBox(height: 18),
              Text('全部版本 · ${versions.length}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...versions.map(
                (version) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text((version['original_text'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
                        const SizedBox(height: 7),
                        Text(
                          '为什么：${version['why_text'] ?? ''}\n'
                          '高层价值：${_versionValues(version['higher_values_json'])}\n'
                          '成功定义：${version['success_definition'] ?? ''}\n'
                          '范围：${version['scope_text'] ?? ''}\n'
                          '${_dateText(_intValue(version['created_at_ms']))}',
                          style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeZoom(XiangjiZoomMode mode) async {
    final goal = _goal;
    final guidance = _guidance;
    final catalog = _catalog;
    if (goal == null || guidance == null || catalog == null) return;
    setState(() => _zoomMode = mode);
    try {
      await _dao.saveGuidance(
        goal: goal,
        userInput: goal.originalText,
        guidance: guidance,
        zoomMode: mode,
        kbVersion: catalog.version,
      );
    } catch (_) {}
  }

  Future<void> _toggleReminder(bool enabled) async {
    if (_goal == null && enabled) {
      _showMessage('先确认一个主目标，再开启目标守护提醒。');
      return;
    }
    setState(() => _working = true);
    try {
      _reminderSettings = await _reminders.update(
        enabled: enabled,
        timeOfDay: _reminderSettings.timeOfDay,
        quietStart: _reminderSettings.quietStart,
        quietEnd: _reminderSettings.quietEnd,
      );
      if (mounted) setState(() {});
    } catch (error) {
      _showMessage('提醒设置失败：${_cleanError(error)}');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOfDay(_reminderSettings.timeOfDay, fallbackHour: 9),
      helpText: '选择每日目标守护时间',
    );
    if (picked == null) return;
    final value = _formatTime(picked);
    try {
      _reminderSettings = await _reminders.update(
        enabled: _reminderSettings.enabled,
        timeOfDay: value,
        quietStart: _reminderSettings.quietStart,
        quietEnd: _reminderSettings.quietEnd,
      );
      if (mounted) setState(() {});
      if (_reminderSettings.timeOfDay != value) {
        _showMessage('所选时间在安静时段内，已顺延到 ${_reminderSettings.timeOfDay}。');
      }
    } catch (error) {
      _showMessage('提醒时间保存失败：${_cleanError(error)}');
    }
  }

  Future<void> _pickQuietHours() async {
    final start = await showTimePicker(
      context: context,
      initialTime: _timeOfDay(_reminderSettings.quietStart, fallbackHour: 22),
      helpText: '安静时段从什么时候开始？',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: _timeOfDay(_reminderSettings.quietEnd, fallbackHour: 8),
      helpText: '安静时段到什么时候结束？',
    );
    if (end == null) return;
    final selectedTime = _reminderSettings.timeOfDay;
    try {
      _reminderSettings = await _reminders.update(
        enabled: _reminderSettings.enabled,
        timeOfDay: selectedTime,
        quietStart: _formatTime(start),
        quietEnd: _formatTime(end),
      );
      if (mounted) setState(() {});
      if (_reminderSettings.timeOfDay != selectedTime) {
        _showMessage('原提醒时间落在新的安静时段内，已顺延到 ${_reminderSettings.timeOfDay}。');
      }
    } catch (error) {
      _showMessage('安静时段保存失败：${_cleanError(error)}');
    }
  }

  TimeOfDay _timeOfDay(String value, {required int fallbackHour}) {
    final parts = value.split(':');
    final hour = (int.tryParse(parts.first) ?? fallbackHour).clamp(0, 23).toInt();
    final minute = (parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0)
        .clamp(0, 59)
        .toInt();
    return TimeOfDay(
      hour: hour,
      minute: minute,
    );
  }

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _importPrivateBook() async {
    setState(() => _working = true);
    try {
      final result = await _books.importPrivateBook();
      _showMessage(result.message);
      if (result.imported) await _reload();
    } catch (error) {
      _showMessage('导入失败：${_cleanError(error)}');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deletePrivateBook(XiangjiBookInfo book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除本地书籍？'),
        content: Text(
          book.providerMirror?.hasRemoteResources ?? false
              ? '将立即停止检索“${book.title}”，删除本地文件与索引，并请求删除 OpenAI 文件和向量库。远端失败时会明确显示“处理中”并保留重试记录。'
              : '将删除“${book.title}”的本地文件、索引与元数据。内置授权书库不受影响。',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      final result = await _books.deletePrivateBook(book);
      await _reload();
      _showMessage(
        result.remoteDeletionPending
            ? '本地内容已删除；OpenAI 远端副本删除处理中，系统会继续重试。'
            : '私人书籍、本地索引和远端镜像已删除。',
      );
    } catch (error) {
      _showMessage('删除未完成：${_cleanError(error)}');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _syncPrivateBook(XiangjiBookInfo book) async {
    final providerMirrorEnabled =
        await _dao.featureEnabled('provider_mirror');
    if (!mounted) return;
    if (!providerMirrorEnabled) {
      _showMessage('远端书库镜像当前未进入本机灰度范围，可继续使用纯本地索引。');
      return;
    }
    if (!book.isLocallySearchable) {
      _showMessage('这本书尚未完成可检索解析。');
      return;
    }
    var legalUseConfirmed = false;
    final consented = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('同步到 OpenAI 远端书库？'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('对象：“${book.title}”'),
                const SizedBox(height: 10),
                const Text(
                  '将上传带本地来源 ID 与定位的可检索文本镜像，用于 OpenAI Vector Store 检索；不会上传目标历史。文件与向量库默认保留到你手动删除。OpenAI API 业务数据默认不用于训练，除非你的账户明确选择共享。存储与调用可能产生费用。你也可以取消并继续使用纯本地索引。',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 10),
                const Text(
                  '删除方式：本应用会删除向量库关联、文件和向量库；失败时显示“处理中”并可重试。',
                  style: TextStyle(height: 1.45),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: legalUseConfirmed,
                  onChanged: (value) => setDialogState(
                    () => legalUseConfirmed = value ?? false,
                  ),
                  title: const Text('我确认拥有这本书的合法使用权，并同意上述处理'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('保持纯本地'),
            ),
            FilledButton(
              onPressed: legalUseConfirmed
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('同意并同步'),
            ),
          ],
        ),
      ),
    );
    if (consented != true) return;
    setState(() => _working = true);
    try {
      final mirror = await _books.syncProviderMirror(
        book,
        consentedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await _reload();
      if (mirror.syncStatus == 'ready') {
        _showMessage('OpenAI 远端镜像已就绪，内容哈希校验通过。');
      } else if (mirror.syncStatus == 'processing') {
        _showMessage('OpenAI 正在建立索引；稍后点击“刷新同步”即可继续检查。');
      } else {
        _showMessage('远端同步未完成：${mirror.lastError}');
      }
    } catch (error) {
      _showMessage('远端同步未完成：${_cleanError(error)}');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _askPrivateBook(XiangjiBookInfo book) async {
    if (!book.isLocallySearchable) {
      _showMessage('这本书尚未完成可检索解析。');
      return;
    }
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('严格问书 · ${book.title}'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '只允许本书的可回定位片段进入回答。远端镜像就绪时先由 OpenAI Vector Store 检索；否则只发送本地命中的有限片段，不发送整本书。引用不一致会直接拦截。',
                style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.45),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '你想核对什么？',
                  hintText: '例如：这本书如何区分自己的目标与外部期待？',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: const Text('检索并校验'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (query == null || query.trim().isEmpty) return;
    final safety = _engine.assessSafety(query);
    if (safety.highRisk) {
      await _showSafetyDialog(safety.message);
      return;
    }
    setState(() => _working = true);
    try {
      final answer = await _grounded.ask(
        query: query,
        allowedBookIds: <String>[book.id],
        goalId: _goal?.id,
        goalContext: _goal?.originalText ?? '',
        kbVersion: _catalog?.version ?? '',
      );
      if (!mounted) return;
      await _showGroundedAnswer(answer);
    } on XiangjiGroundingException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('严格问书未完成：${_cleanError(error)}');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _showGroundedAnswer(XiangjiGroundedAnswer answer) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            children: <Widget>[
              const Text(
                '严格问书结果',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '${_sourceModeLabel(answer.sourceMode)} · ${answer.modelLabel}',
                style: const TextStyle(color: _moss, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              _ContentTypeLabel(text: _contentTypeLabel(answer.contentType)),
              const SizedBox(height: 8),
              SelectableText(answer.text, style: const TextStyle(height: 1.6)),
              const SizedBox(height: 12),
              Text(
                '边界：${answer.boundary}',
                style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.45),
              ),
              const Divider(height: 30),
              const Text('已通过本地校验的来源', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...answer.citations.map(
                (citation) => Card(
                  color: _sand,
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(citation.bookTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(citation.locator, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 7),
                        SelectableText('“${citation.excerpt}”', style: const TextStyle(height: 1.45)),
                        const SizedBox(height: 5),
                        Text(citation.sourceId, style: const TextStyle(fontSize: 11, color: Colors.black45)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    final data = await _dao.exportJson();
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      p.join(
        directory.path,
        'xiangji_export_${DateTime.now().millisecondsSinceEpoch}.json',
      ),
    );
    await file.writeAsString(data, flush: true);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出完成'),
        content: SelectableText(
          'JSON 已保存到应用私有目录。为避免意外泄露，只有你明确选择时才会复制：\n${file.path}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: data));
              if (!context.mounted) return;
              Navigator.pop(context);
              _showMessage('已按你的选择复制 JSON。');
            },
            child: const Text('复制 JSON'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('完成')),
        ],
      ),
    );
  }

  Future<void> _deleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除向己的全部数据？'),
        content: const Text('这会先停止私人书籍检索并删除本地索引，再删除已授权的 OpenAI 文件与向量库，最后清除目标、版本、行动、成长证据、校准、提醒和历史导出。若远端删除失败，清除会停在“处理中”而不会谎称完成。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      await _reminders.cancelAndRemoveTask();
      await _books.deleteAllPrivateBooks();
      await _books.deleteGeneratedExports();
      await _dao.deleteAllData();
      _goalController.clear();
      _draft = null;
      _tabIndex = 0;
      await _reload();
      _showMessage('向己的目标数据、私人书籍、历史导出和提醒已清除。');
    } catch (error) {
      _showMessage('清除未完成：${_cleanError(error)}');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _showSafetyDialog(String message) async {
    try {
      await _dao.recordAnalyticsEvent(
        'safety_escalated',
        goalId: _goal?.id,
        properties: const <String, Object?>{'risk_category': 'crisis_gate'},
      );
    } catch (_) {}
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.health_and_safety_outlined, color: Colors.red),
        title: const Text('先确保安全'),
        content: Text(message),
        actions: <Widget>[
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('我知道了')),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _ensureCurrentMentorCompatible() async {
    if (!_requiresMentorReselection) return true;
    _showMessage('目标和历史已保留；请先为 V2.1 知识库重新选择一位导师。');
    await _openMentorKnowledge();
    return false;
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('FormatException: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _moss,
          brightness: Theme.of(context).brightness,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _moss,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFCFBF8),
        appBar: AppBar(
          titleSpacing: 8,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('向己', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              Text('智能目标导师', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: '目标导师助手',
              onPressed: _working ? null : _openGoalAssistant,
              icon: const Icon(Icons.support_agent_outlined),
            ),
            IconButton(
              tooltip: '刷新',
              onPressed: _working ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Stack(
          children: <Widget>[
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error.isNotEmpty)
              _ErrorView(message: _error, onRetry: _reload)
            else
              IndexedStack(
                index: _tabIndex,
                children: <Widget>[
                  _buildToday(),
                  _buildGoalTab(),
                  _buildLibraryTab(),
                  _buildMeTab(),
                ],
              ),
            if (_working)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.08),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: (value) => setState(() => _tabIndex = value),
          destinations: const <NavigationDestination>[
            NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: '今天'),
            NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: '目标'),
            NavigationDestination(icon: Icon(Icons.local_library_outlined), selectedIcon: Icon(Icons.local_library), label: '书库'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
          ],
        ),
      ),
    );
  }

  Widget _buildToday() {
    if (_goal == null) return _buildOnboarding();
    if (_requiresMentorReselection) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            _buildGoalSeedCard(),
            const SizedBox(height: 14),
            _buildMentorKnowledgeUpgradeCard(),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          _buildGoalSeedCard(),
          const SizedBox(height: 14),
          if (_intelligenceReceipt != null) ...<Widget>[
            _buildIntelligenceReceipt(_intelligenceReceipt!),
            const SizedBox(height: 14),
          ],
          _buildTodayStepCard(),
          const SizedBox(height: 14),
          if (_guidance != null) _buildMentorCard(_guidance!),
          if (_goal!.state != XiangjiGoalState.completed) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openLostMode,
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text('我现在卡住了'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openCalibration,
                    icon: const Icon(Icons.tune),
                    label: const Text('重新想想目标'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOnboarding() {
    const starters = <String>[
      '我现在没有目标',
      '我曾经有目标，但忘了为什么出发',
      '我知道目标，但走不动了',
      '我只知道自己不想继续这样生活',
    ];
    XiangjiGoal? reselected;
    for (final item in _allGoals) {
      if (item.state == XiangjiGoalState.reselecting) {
        reselected = item;
        break;
      }
    }
    final selectedMentor = _catalog?.system(_selectedMentorId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF315D4D), Color(0xFF5F8068)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.north_east_rounded, color: Colors.white, size: 30),
              SizedBox(height: 26),
              Text(
                '此刻，你最不想忘记的目标是什么？',
                style: TextStyle(color: Colors.white, fontSize: 25, height: 1.35, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 10),
              Text(
                '不需要人生问卷。先说一句真实的话，向己只帮你形成一个目标火种。',
                style: TextStyle(color: Color(0xFFE9F1EC), fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
        if (reselected != null) ...<Widget>[
          const SizedBox(height: 16),
          _SectionCard(
            color: _sage,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('具体路径可以改变，价值不必丢失', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('上一次校准后，你选择重选“${reselected.originalText}”。新目标仍可以服务这些价值：'),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: reselected.higherValues.map((value) => _Pill(text: value)).toList(),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _chooseExample,
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('不知道怎么填？先用一个完整案例'),
        ),
        const SizedBox(height: 12),
        const Text('1. 你现在想解决什么？', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text('只要一句真实的话；可以是目标、问题、困难或想要的改变。', style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 10),
        TextField(
          controller: _goalController,
          focusNode: _goalFocus,
          minLines: 3,
          maxLines: 6,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: '例如：我想恢复写作，但总担心写不好。',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: starters
              .map(
                (text) => ActionChip(
                  label: Text(text),
                  onPressed: () {
                    _goalController.text = text;
                    _goalController.selection = TextSelection.collapsed(offset: text.length);
                    _goalFocus.requestFocus();
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _outcomeController,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '希望得到什么结果？（可不填）',
            hintText: '例如：七天内留下三次真实写作痕迹',
            helperText: '用看得见的结果描述；不知道时由导师帮你形成。',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _obstacleController,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '现在最可能卡在哪里？（可不填）',
            hintText: '例如：早晨时间不稳定，而且担心写得差',
            helperText: '只写事实；不会把阻碍解释成性格缺陷。',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        const Text('2. 选一种你愿意开始的方式', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text('这不是人格测验，只决定本轮例子、语气和行动大小。', style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: XiangjiGoalInterest.values.map((value) => ChoiceChip(
            label: Text(value.label),
            selected: _interest == value,
            onSelected: (_) => setState(() => _interest = value),
          )).toList(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: XiangjiSupportTone.values.map((value) => ChoiceChip(
            label: Text(value.label),
            selected: _supportTone == value,
            onSelected: (_) => setState(() => _supportTone = value),
          )).toList(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: <int>[2, 5, 10, 15, 20].map((value) => ChoiceChip(
            label: Text('$value 分钟'),
            selected: _availableMinutes == value,
            onSelected: (_) => setState(() => _availableMinutes = value),
          )).toList(),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          color: _sage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('导师可选，不选也能开始', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(
                selectedMentor == null
                    ? '系统会从知识库选择三条不同思想路径，先给你比较，再由你确认。'
                    : '你偏好 ${selectedMentor.displayName}；系统仍会提供另外两条可比较路径。',
                style: const TextStyle(fontSize: 12, height: 1.45),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _openMentorKnowledge,
                  icon: const Icon(Icons.account_tree_outlined),
                  label: Text(selectedMentor == null ? '我想先选思想家' : '查看或更换思想家'),
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _allowPlanningAi,
                onChanged: (value) => setState(() => _allowPlanningAi = value),
                title: const Text('本次允许 AI 结合情境形成方案'),
                subtitle: const Text('自动隐藏邮箱、手机号和证件号；AI 不可用时，本地知识规则立即接管并说明原因。'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _working ? null : _createDraft,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Text('生成三条现实路径'),
          ),
        ),
        if (_planBundle != null) ...<Widget>[
          const SizedBox(height: 20),
          _buildIntelligenceReceipt(_planBundle!.receipt),
          const SizedBox(height: 14),
          _buildPlanRoutePicker(_planBundle!),
        ],
        if (_draft != null) ...<Widget>[
          const SizedBox(height: 14),
          _buildDraftCard(_draft!),
        ],
        const SizedBox(height: 20),
        const _BoundaryNote(),
      ],
    );
  }

  Widget _buildMentorKnowledgeUpgradeCard() {
    final migration = _mentorMigration!;
    return XiangjiMentorUpgradeCard(
      fromThinkerId: migration.fromThinkerId,
      onReselect: _openMentorKnowledge,
    );
  }

  Widget _buildIntelligenceReceipt(XiangjiGoalIntelligenceReceipt receipt) {
    final mode = receipt.aiUsed
        ? 'AI 已参与 · ${receipt.model}'
        : receipt.aiRequested
            ? 'AI 未完成 · 本地知识规则已接管'
            : '本地知识规则';
    return _SectionCard(
      color: receipt.aiUsed ? const Color(0xFFE8EEF8) : _sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(receipt.aiUsed ? Icons.auto_awesome : Icons.offline_bolt_outlined, color: _moss),
              const SizedBox(width: 8),
              Expanded(child: Text(mode, style: const TextStyle(fontWeight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 8),
          Text('它做了什么：${receipt.situationSummary}', style: const TextStyle(height: 1.45)),
          if (receipt.blindSpotQuestion.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text('它提醒你核对：${receipt.blindSpotQuestion}', style: const TextStyle(height: 1.45)),
          ],
          if (receipt.fallbackReason.isNotEmpty) ...<Widget>[
            const SizedBox(height: 7),
            Text(receipt.fallbackReason, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
          const SizedBox(height: 7),
          Text(
            '处理模式：${receipt.provider} · 已约束 ${receipt.knowledgeIds.length} 条知识依据',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanRoutePicker(XiangjiGoalPlanBundle bundle) {
    return _SectionCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('3. 选一条今天愿意走的路径', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('三条都来自现有知识库，但解决角度、产出和投入不同。没有“正确人格”答案。', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 10),
          ...bundle.routes.map((route) => Card(
            margin: const EdgeInsets.only(bottom: 9),
            color: _selectedPlanRoute?.id == route.id ? _sage : Colors.white,
            child: ListTile(
              onTap: () => _selectPlanRoute(route),
              leading: Icon(
                _selectedPlanRoute?.id == route.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: _moss,
              ),
              title: Text(route.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text('${route.promise}\n导师：${route.mentorName}\n本轮产出：${route.output}'),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDraftCard(XiangjiGoalDraft draft) {
    final route = _selectedPlanRoute;
    return _SectionCard(
      color: _sand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.local_fire_department_outlined, color: Color(0xFFA25D32)),
              SizedBox(width: 8),
              Text('你的现实行动方案', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            ],
          ),
          const SizedBox(height: 14),
          Text(draft.originalText, style: const TextStyle(fontSize: 20, height: 1.45, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 12),
          Text(route?.understanding ?? draft.whyText, style: const TextStyle(height: 1.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: draft.higherValues.map((value) => _Pill(text: value)).toList(),
          ),
          const SizedBox(height: 10),
          Text('做到哪里算完成：${route?.successSignal ?? draft.successDefinition}', style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 4),
          Text('你会留下：${route?.output ?? draft.step.evidenceRule}', style: const TextStyle(fontSize: 13, height: 1.4)),
          const Divider(height: 28),
          Text('当前主要导师 · ${draft.guidance.mentorName}', style: const TextStyle(color: _moss, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const _ContentTypeLabel(text: '根据本地知识库转述'),
          const SizedBox(height: 6),
          Text(draft.guidance.coreJudgment, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 12),
          Text('今天只做：${draft.step.actionText}', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45)),
          const SizedBox(height: 6),
          Text('为什么是这一步：${route?.whyItWorks ?? draft.guidance.actionDerivation}', style: const TextStyle(height: 1.45)),
          if (route != null && route.applications.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            ...route.applications.map((application) => ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 10),
              title: Text('${application.mentorName} · ${application.concept}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('展开看：概念怎样推出这项行动'),
              children: <Widget>[
                _InfoRow(label: '知识来源', value: application.locator),
                _InfoRow(label: '用于你的情况', value: application.caseApplication),
                _InfoRow(label: '推导理由', value: application.whyThisAction),
                _InfoRow(label: '理论边界', value: application.boundary),
              ],
            )),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _confirmDraft, child: const Text('就是这个')),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextButton(onPressed: _editDraft, child: const Text('不太准确')),
              TextButton(
                onPressed: () {
                  setState(() {
                    _draft = null;
                    _planBundle = null;
                    _selectedPlanRoute = null;
                  });
                  _goalFocus.requestFocus();
                },
                child: const Text('我想继续说'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalSeedCard() {
    final goal = _goal!;
    final latestEvidence = _evidence.isEmpty ? null : _evidence.first;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF294F43), Color(0xFF527360)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x1A1C3B31), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.local_fire_department_outlined, color: Color(0xFFFFD4A6)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('我的目标火种', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              ),
              _Pill(
                text: goal.state.label,
                background: Colors.white.withValues(alpha: 0.16),
                foreground: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            goal.originalText,
            style: const TextStyle(color: Colors.white, fontSize: 23, height: 1.35, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(goal.whyText, style: const TextStyle(color: Color(0xFFE3EEE8), height: 1.5)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: goal.higherValues
                .map(
                  (value) => _Pill(
                    text: value,
                    background: Colors.white.withValues(alpha: 0.14),
                    foreground: Colors.white,
                  ),
                )
                .toList(),
          ),
          if (latestEvidence != null) ...<Widget>[
            const Divider(height: 26, color: Colors.white24),
            const Text('最近成长证据', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Text(latestEvidence.summary, style: const TextStyle(color: Colors.white, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _buildTodayStepCard() {
    final goal = _goal!;
    final step = _step;
    if (goal.state == XiangjiGoalState.completed) {
      return _SectionCard(
        color: _sand,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.celebration_outlined, color: _moss, size: 30),
            const SizedBox(height: 10),
            const Text('先整合，不急着寻找下一个目标', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            const Text('看看这段经历已经形成了什么能力，以及你是否需要巩固、分享、扩展、休息或结束。', style: TextStyle(height: 1.45)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _archiveCompletedGoal,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('归档这段旅程'),
            ),
          ],
        ),
      );
    }
    if (goal.state == XiangjiGoalState.paused) {
      return _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.pause_circle_outline, color: _moss, size: 30),
            const SizedBox(height: 10),
            const Text('目标正在暂停', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('暂停不等于放弃，也不会收到行动催促。准备好时再重新连接。'),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _togglePause,
              icon: const Icon(Icons.play_arrow),
              label: const Text('重新连接目标'),
            ),
          ],
        ),
      );
    }
    final actionable = step != null &&
        (step.status == 'ready' || step.status == 'in_progress');
    if (!actionable) {
      return _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('今天的一步', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              step == null ? '还没有生成当前行动。' : '上一轮已经留下反馈。现在只生成一个新的可控行动。',
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _guidance == null ? null : _generateNextStep,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('生成下一步'),
            ),
          ],
        ),
      );
    }
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.directions_walk_outlined, color: _moss),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('今天的一步', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              _Pill(text: step.status == 'in_progress' ? '已开始' : '待开始'),
            ],
          ),
          const SizedBox(height: 14),
          Text(step.actionText, style: const TextStyle(fontSize: 20, height: 1.4, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 14),
          _InfoRow(icon: Icons.bolt_outlined, label: '触发点', text: step.triggerContext),
          _InfoRow(icon: Icons.check_circle_outline, label: '最低完成', text: step.minimumDone),
          _InfoRow(icon: Icons.visibility_outlined, label: '完成证据', text: step.evidenceRule),
          _InfoRow(icon: Icons.shield_outlined, label: '为什么可控', text: step.controllabilityReason),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: step.status == 'in_progress' ? null : _markStarted,
              icon: const Icon(Icons.play_arrow),
              label: Text(step.status == 'in_progress' ? '已经开始' : '现在开始'),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              TextButton.icon(onPressed: _shrinkStep, icon: const Icon(Icons.compress), label: const Text('再缩小一点')),
              TextButton.icon(onPressed: _replaceStep, icon: const Icon(Icons.swap_horiz), label: const Text('换一种方式')),
              TextButton.icon(onPressed: () => _submitCheckin(XiangjiCheckinResult.notStarted), icon: const Icon(Icons.schedule_outlined), label: const Text('尚未开始')),
              TextButton.icon(onPressed: () => _submitCheckin(XiangjiCheckinResult.blocked), icon: const Icon(Icons.event_busy_outlined), label: const Text('今天条件不允许')),
              TextButton.icon(onPressed: () => _submitCheckin(XiangjiCheckinResult.partiallyCompleted), icon: const Icon(Icons.timelapse), label: const Text('部分完成')),
              TextButton.icon(onPressed: () => _submitCheckin(XiangjiCheckinResult.completed), icon: const Icon(Icons.done_all), label: const Text('已经完成')),
              TextButton.icon(onPressed: () => _submitCheckin(XiangjiCheckinResult.noLongerRelevant), icon: const Icon(Icons.alt_route_outlined), label: const Text('这一步已不再适用')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMentorCard(XiangjiGuidance guidance) {
    return _SectionCard(
      color: _sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('当前主要导师 · 一次只显示一位', style: TextStyle(color: _moss, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(guidance.mentorName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 4),
          const Text('这是当前最匹配的一个视角，不代表唯一正确答案。', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          const _ContentTypeLabel(text: '根据本地知识库转述'),
          const SizedBox(height: 7),
          Text(guidance.coreJudgment, style: const TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(guidance.selectionReason, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 8),
          Text('理论边界：${guidance.boundaryNote}', style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.45)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _openMentorSetting,
                icon: const Icon(Icons.route_outlined),
                label: const Text('8 步目标设定'),
              ),
              OutlinedButton.icon(
                onPressed: _openMentorKnowledge,
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('导师知识与更换'),
              ),
            ],
          ),
          const Divider(height: 26),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: XiangjiZoomMode.values
                  .map(
                    (mode) => Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        selected: mode == _zoomMode,
                        onSelected: (_) => _changeZoom(mode),
                        label: Text(mode.label),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              guidance.textFor(_zoomMode),
              key: ValueKey<XiangjiZoomMode>(_zoomMode),
              style: const TextStyle(height: 1.55),
            ),
          ),
          if (_zoomMode == XiangjiZoomMode.action) ...<Widget>[
            const SizedBox(height: 8),
            const _ContentTypeLabel(text: '知识库应用推导'),
          ],
          if (_zoomMode == XiangjiZoomMode.evidence) ...<Widget>[
            const SizedBox(height: 12),
            ...guidance.sources.map(_buildSourceTile),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceTile(XiangjiSourceCitation source) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD2DED6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _ContentTypeLabel(text: '根据本书转述'),
          const SizedBox(height: 6),
          Text('${source.bookTitle} · ${source.author}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(source.locator, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          Text('${source.claim}：${source.summary}', style: const TextStyle(height: 1.4)),
          if (source.boundary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text('边界：${source.boundary}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalTab() {
    final goal = _goal;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: <Widget>[
          if (goal == null)
            const _EmptyState(
              icon: Icons.flag_outlined,
              title: '现在没有激活的主目标',
              message: '回到“今天”，用一句话形成新的目标火种。历史目标仍保留在下方。',
            )
          else ...<Widget>[
            if (_requiresMentorReselection) ...<Widget>[
              _buildMentorKnowledgeUpgradeCard(),
              const SizedBox(height: 14),
            ],
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(child: Text('当前目标', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                      _Pill(text: goal.state.label),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(goal.originalText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.4)),
                  const SizedBox(height: 8),
                  Text(goal.whyText, style: const TextStyle(height: 1.45)),
                  const SizedBox(height: 10),
                  Text('成功定义：${goal.successDefinition}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 5),
                  Text('当前范围：${goal.scopeText}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      if (goal.state != XiangjiGoalState.completed)
                        OutlinedButton.icon(onPressed: _editActiveGoal, icon: const Icon(Icons.edit_outlined), label: const Text('编辑并保留版本')),
                      if (goal.state == XiangjiGoalState.active || goal.state == XiangjiGoalState.paused)
                        OutlinedButton.icon(
                          onPressed: _togglePause,
                          icon: Icon(goal.state == XiangjiGoalState.paused ? Icons.play_arrow : Icons.pause),
                          label: Text(goal.state == XiangjiGoalState.paused ? '恢复' : '暂停'),
                        ),
                      if (goal.state != XiangjiGoalState.completed)
                        OutlinedButton.icon(onPressed: _openCalibration, icon: const Icon(Icons.tune), label: const Text('目标校准')),
                      if (goal.state == XiangjiGoalState.active || goal.state == XiangjiGoalState.feedback)
                        OutlinedButton.icon(onPressed: _completeGoal, icon: const Icon(Icons.celebration_outlined), label: const Text('标记完成')),
                      if (goal.state == XiangjiGoalState.completed)
                        OutlinedButton.icon(onPressed: _archiveCompletedGoal, icon: const Icon(Icons.archive_outlined), label: const Text('归档')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text('版本历史 · ${_versions.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                subtitle: const Text('旧版本只读保留，不会被静默覆盖。'),
                children: _versions
                    .map(
                      (version) => Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    (version['original_text'] ?? '').toString(),
                                    style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _intValue(version['id']) == goal.versionId
                                    ? const _Pill(text: '当前')
                                    : const _Pill(text: '只读'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '为什么：${version['why_text'] ?? ''}\n'
                              '高层价值：${_versionValues(version['higher_values_json'])}\n'
                              '成功定义：${version['success_definition'] ?? ''}\n'
                              '范围：${version['scope_text'] ?? ''}\n'
                              '${_dateText(_intValue(version['created_at_ms']))}',
                              style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.45),
                            ),
                            const Divider(height: 22),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('成长证据', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (_evidence.isEmpty)
                    const Text('还没有已确认的证据。完成、调整、求助、休息和合理退出都可以成为证据。')
                  else
                    ..._evidence.map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(backgroundColor: _sage, child: Icon(Icons.eco_outlined, color: _moss)),
                        title: Text(item.summary),
                        subtitle: Text(_dateText(item.createdAtMs)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('状态轨迹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ..._events.take(8).map(
                    (event) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.radio_button_checked, size: 17, color: _moss),
                      title: Text('${_stateLabel(event['from_state'])} → ${_stateLabel(event['to_state'])}'),
                      subtitle: Text('${event['reason'] ?? ''}\n${_dateText(_intValue(event['created_at_ms']))}'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_allGoals.where((item) => !item.isActive).isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            const Text('历史目标', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ..._allGoals.where((item) => !item.isActive).map(
              (item) => Card(
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(item.originalText, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${item.state.label} · ${_dateText(item.updatedAtMs)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showHistoricalGoal(item),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLibraryTab() {
    final catalog = _catalog!;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: <Widget>[
          _SectionCard(
            color: _sand,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.verified_user_outlined, color: _moss, size: 30),
                const SizedBox(height: 10),
                Text('受控本地知识库 V${catalog.version}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('${catalog.books.length} 部登记来源 · ${catalog.systems.length} 套思想与行动体系', style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 10),
                const Text('本地母库决定可用导师、节点和来源。模型通用记忆不会被当成思想依据；覆盖不足时会停止确定性生成。', style: TextStyle(height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            color: _sage,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '目标优先导师层（默认）',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '${catalog.systems.length} 位导师 · '
                  '${catalog.primaryThemeCount} 个 L1 核心主题 · '
                  '${catalog.secondaryThemeCount} 个 L2 补充主题 · '
                  '${catalog.evidenceCount} 条可回定位依据',
                  style: const TextStyle(height: 1.45),
                ),
                const SizedBox(height: 6),
                const Text(
                  '默认只展开目标核心；深层模块和原典依据按需进入，辅助短画像默认隐藏。',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _openMentorKnowledge,
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('查看导师知识路径'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              const Expanded(child: Text('我的私人书籍', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              FilledButton.tonalIcon(
                onPressed: _working ? null : _importPrivateBook,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('导入'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('导入后在设备内解析为可定位短片段。严格问书只使用本轮允许书籍；远端镜像必须另行授权，且内容哈希一致才可检索。', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 10),
          if (_pendingRemoteDeletions > 0)
            Card(
              color: Colors.orange.shade50,
              child: ListTile(
                leading: const Icon(Icons.sync_problem_outlined, color: Colors.orange),
                title: Text('$_pendingRemoteDeletions 个 OpenAI 远端副本删除处理中'),
                subtitle: const Text('本地内容已停止检索；请保留 API Key，系统会继续重试。'),
                trailing: TextButton(
                  onPressed: _working
                      ? null
                      : () async {
                          setState(() => _working = true);
                          try {
                            await _books.retryPendingProviderDeletions();
                            await _reload();
                          } finally {
                            if (mounted) setState(() => _working = false);
                          }
                        },
                  child: const Text('重试'),
                ),
              ),
            ),
          if (_importedBooks.isEmpty)
            const _EmptyState(icon: Icons.menu_book_outlined, title: '尚未导入私人书籍', message: '支持 PDF、EPUB、DOCX、TXT、Markdown 和 AZW3。')
          else
            ..._importedBooks.map(
              (book) {
                final mirrorReady =
                    book.providerMirror?.isReadyFor(book.contentHash) ?? false;
                final mirrorStatus = _mirrorStatus(book);
                return Card(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const CircleAvatar(backgroundColor: _sand, child: Icon(Icons.lock_outline, color: _moss)),
                        title: Text(book.title),
                        subtitle: Text(
                          '${_bookParseStatus(book)}\n$mirrorStatus',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
                        child: Row(
                          children: <Widget>[
                            OutlinedButton.icon(
                              onPressed: _working || !book.isLocallySearchable
                                  ? null
                                  : () => _askPrivateBook(book),
                              icon: const Icon(Icons.manage_search_outlined),
                              label: const Text('严格问书'),
                            ),
                            const SizedBox(width: 8),
                            if (!mirrorReady &&
                                book.providerMirror?.syncStatus != 'delete_pending')
                              FilledButton.tonalIcon(
                                onPressed: _working || !book.isLocallySearchable
                                    ? null
                                    : () => _syncPrivateBook(book),
                                icon: const Icon(Icons.cloud_upload_outlined),
                                label: Text(
                                  book.providerMirror?.syncStatus == 'processing'
                                      ? '刷新同步'
                                      : '同步 OpenAI',
                                ),
                              ),
                            const Spacer(),
                            IconButton(
                              tooltip: '删除本地与远端书籍副本',
                              onPressed: _working ? null : () => _deletePrivateBook(book),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 22),
          const Text('内置来源', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...catalog.books.map(
            (book) => Card(
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: _sage, child: Icon(Icons.auto_stories_outlined, color: _moss)),
                title: Text(book.title),
                subtitle: Text('${book.author}\n${book.edition}', maxLines: 2, overflow: TextOverflow.ellipsis),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showBookDetails(book),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBookDetails(XiangjiBookInfo book) async {
    final status = book.sourceStatus == 'primary_source_opened'
        ? '原始来源已打开并完成定位审计'
        : book.sourceStatus == 'secondary_teaching_source'
            ? '教学性二手来源，使用时保留来源边界'
            : book.sourceStatus == 'public_substitute_verified'
                ? '已验证的公共替代来源'
                : book.sourceStatus;
    try {
      await _dao.recordAnalyticsEvent(
        'source_opened',
        goalId: _goal?.id,
        properties: <String, Object?>{'source_id': book.id},
      );
    } catch (_) {}
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(book.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(book.author, style: const TextStyle(color: _moss, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text('版本：${book.edition}'),
              const SizedBox(height: 6),
              Text('状态：$status'),
              const SizedBox(height: 6),
              Text('内容哈希：${book.contentHash.isEmpty ? '未登记' : book.contentHash}'),
              const SizedBox(height: 14),
              const _ContentTypeLabel(text: '受控本地来源'),
              const SizedBox(height: 8),
              const Text('界面只展示回答所需的有限转述和定位，不导出连续长段原文。'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
      children: <Widget>[
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('目标守护提醒', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('每天最多一次主动提醒。不显示断签、排名或落后。'),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('每日轻提醒'),
                subtitle: Text(_reminderSettings.enabled ? '已开启 · ${_reminderSettings.timeOfDay}' : '已关闭'),
                value: _reminderSettings.enabled,
                onChanged: _working ? null : _toggleReminder,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: const Text('提醒时间'),
                subtitle: Text(_reminderSettings.timeOfDay),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickReminderTime,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bedtime_outlined),
                title: const Text('安静时段'),
                subtitle: Text('${_reminderSettings.quietStart} — ${_reminderSettings.quietEnd}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _working ? null : _pickQuietHours,
              ),
              if (_goal != null)
                OutlinedButton.icon(
                  onPressed: _reminders.sendPreview,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('发送一条预览提醒'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _SectionCard(
          color: _sage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('知识运行模式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.offline_bolt_outlined, color: _moss),
                title: Text('本地严格模式'),
                subtitle: Text('私人书籍在设备内解析与检索；只发送命中的有限片段，没有依据时停止。'),
                trailing: Icon(Icons.check_circle, color: _moss),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.cloud_outlined, color: _moss),
                title: Text('OpenAI 镜像（逐书授权）'),
                subtitle: Text('仅在哈希一致且索引就绪时参与检索；可删除并保留无正文审计。'),
              ),
              _BoundaryNote(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          color: _sand,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '需要处理复杂问题或战略决断？',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                '保留现有“未来军师”的真问题、战役、行动验算、Provider 生命周期与个人战史能力。',
                style: TextStyle(height: 1.45),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openFutureStrategist,
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('进入深度问题与战略空间'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('数据与隐私', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('目标原话、行动和证据默认只保存在本机应用数据库；分析事件不记录完整原话。', style: TextStyle(height: 1.45)),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.monitor_heart_outlined),
                title: const Text('本机发布诊断'),
                subtitle: const Text('查看知识门槛、灰度开关、聚合事件与删除重试；不显示用户原话'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openOperations,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.download_outlined),
                title: const Text('导出我的向己数据'),
                subtitle: const Text('生成可读 JSON；复制需要再次明确选择'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _exportData,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_forever_outlined, color: Colors.red.shade700),
                title: Text('清除全部向己数据', style: TextStyle(color: Colors.red.shade700)),
                subtitle: const Text('包括私人书籍和提醒任务'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _deleteAllData,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _bookParseStatus(XiangjiBookInfo book) {
    switch (book.parseStatus) {
      case 'ready':
        return '本地可检索 · ${book.chunkCount} 个片段 · ${book.parsedCharacters} 字';
      case 'partial':
        return '本地部分索引 · ${book.chunkCount} 个片段 · 严格回答会提示覆盖边界';
      case 'failed':
        return '解析未完成 · ${book.parseError.isEmpty ? '可删除后重新导入' : book.parseError}';
      case 'pending':
        return '正在建立本地索引';
      default:
        return '本地状态：${book.parseStatus.isEmpty ? '未知' : book.parseStatus}';
    }
  }

  String _mirrorStatus(XiangjiBookInfo book) {
    final mirror = book.providerMirror;
    if (mirror == null) return 'OpenAI 镜像：未授权（纯本地）';
    if (mirror.syncStatus == 'ready' &&
        !mirror.isReadyFor(book.contentHash)) {
      return 'OpenAI 镜像：哈希不一致，已禁止检索';
    }
    switch (mirror.syncStatus) {
      case 'ready':
        return 'OpenAI 镜像：已就绪且哈希一致';
      case 'processing':
      case 'uploading':
        return 'OpenAI 镜像：正在建立索引';
      case 'failed':
        return 'OpenAI 镜像：同步失败 · ${mirror.lastError}';
      case 'delete_pending':
        return 'OpenAI 镜像：删除处理中';
      case 'deleted':
        return 'OpenAI 镜像：已删除';
      default:
        return 'OpenAI 镜像：${mirror.syncStatus}';
    }
  }

  static String _sourceModeLabel(String mode) {
    switch (mode) {
      case 'provider_mirror':
        return 'OpenAI 镜像检索';
      case 'local_index_after_remote_failure':
        return '远端失败后安全降级到本地索引';
      case 'local_index_no_model':
        return '纯本地检索（未调用模型）';
      default:
        return '本地严格索引';
    }
  }

  static String _contentTypeLabel(String value) {
    switch (value) {
      case 'direct_quote':
        return '原书短摘录';
      case 'source_paraphrase':
        return '根据本书转述';
      case 'multi_source_synthesis':
        return '多书综合';
      case 'kb_application':
        return '知识库应用推导';
      case 'ai_contextual_inference':
        return '结合情境的 AI 推断';
      default:
        return value;
    }
  }

  String _dateText(int milliseconds) {
    if (milliseconds <= 0) return '';
    final value = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    return int.tryParse((value ?? '0').toString()) ?? 0;
  }

  String _versionValues(Object? raw) {
    try {
      final decoded = jsonDecode((raw ?? '[]').toString());
      if (decoded is List) {
        return decoded.map((item) => item.toString()).join('、');
      }
    } catch (_) {}
    return '';
  }

  String _stateLabel(Object? value) {
    if (value == null || value.toString().isEmpty) return '开始';
    return parseXiangjiGoalState(value).label;
  }
}

class XiangjiCalibrationPage extends StatefulWidget {
  const XiangjiCalibrationPage({
    required this.goal,
    required this.engine,
    super.key,
  });

  final XiangjiGoal goal;
  final XiangjiGoalMentorEngine engine;

  @override
  State<XiangjiCalibrationPage> createState() => _XiangjiCalibrationPageState();
}

class _CalibrationQuestion {
  const _CalibrationQuestion({
    required this.layer,
    required this.question,
    required this.options,
  });

  final String layer;
  final String question;
  final List<MapEntry<String, String>> options;
}

class _XiangjiCalibrationPageState extends State<XiangjiCalibrationPage> {
  static const List<_CalibrationQuestion> _questions = <_CalibrationQuestion>[
    _CalibrationQuestion(
      layer: '价值层',
      question: '目标背后的价值，现在仍然是你真心认同的吗？',
      options: <MapEntry<String, String>>[
        MapEntry<String, String>('yes', '仍然重要'),
        MapEntry<String, String>('uncertain', '我还不确定'),
        MapEntry<String, String>('no', '已经不再认同'),
      ],
    ),
    _CalibrationQuestion(
      layer: '目标层',
      question: '这个具体目标，仍是承载那项价值的合适路径吗？',
      options: <MapEntry<String, String>>[
        MapEntry<String, String>('yes', '仍然合适'),
        MapEntry<String, String>('uncertain', '需要再验证'),
        MapEntry<String, String>('no', '这条路径不再适合'),
      ],
    ),
    _CalibrationQuestion(
      layer: '路径层',
      question: '你正在使用的方法，得到过现实反馈的支持吗？',
      options: <MapEntry<String, String>>[
        MapEntry<String, String>('effective', '有一些有效反馈'),
        MapEntry<String, String>('uncertain', '证据还不够'),
        MapEntry<String, String>('ineffective', '反复显示无效'),
      ],
    ),
    _CalibrationQuestion(
      layer: '行动层',
      question: '当前一步与你现在的时间、精力和条件适配吗？',
      options: <MapEntry<String, String>>[
        MapEntry<String, String>('fit', '基本适配'),
        MapEntry<String, String>('too_big', '这一步仍然太大'),
        MapEntry<String, String>('conditions_unavailable', '当前条件暂不允许'),
      ],
    ),
  ];

  final List<String> _answers = <String>[];
  int _index = 0;
  XiangjiCalibrationDecision? _decision;

  void _answer(String value) {
    if (_answers.length > _index) {
      _answers[_index] = value;
    } else {
      _answers.add(value);
    }
    if (_index < _questions.length - 1) {
      setState(() => _index += 1);
      return;
    }
    final decision = widget.engine.calibrationDecision(
      goal: widget.goal,
      valueAnswer: _answers[0],
      goalAnswer: _answers[1],
      methodAnswer: _answers[2],
      actionAnswer: _answers[3],
    );
    setState(() => _decision = decision);
  }

  @override
  Widget build(BuildContext context) {
    final decision = _decision;
    return Scaffold(
      backgroundColor: const Color(0xFFFCFBF8),
      appBar: AppBar(title: const Text('目标校准')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: decision == null ? _buildQuestion(context) : _buildResult(context, decision),
        ),
      ),
    );
  }

  Widget _buildQuestion(BuildContext context) {
    final question = _questions[_index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LinearProgressIndicator(value: (_index + 1) / _questions.length, color: _moss),
        const SizedBox(height: 28),
        _Pill(text: '${question.layer} · ${_index + 1}/${_questions.length}'),
        const SizedBox(height: 20),
        Text(
          question.question,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _ink,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        const Text('没有“正确答案”。这里只判断目标、方法与现实是否仍然匹配。', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 28),
        ...question.options.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _answer(option.key),
              child: Text(option.value, style: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
        const Spacer(),
        if (_index > 0)
          TextButton.icon(
            onPressed: () => setState(() => _index -= 1),
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回上一层'),
          ),
      ],
    );
  }

  Widget _buildResult(
    BuildContext context,
    XiangjiCalibrationDecision decision,
  ) {
    return ListView(
      children: <Widget>[
        Center(child: _Pill(text: decision.result.label)),
        const SizedBox(height: 16),
        Text(
          decision.result.description,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _ink,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 24),
        _SectionCard(
          child: Column(
            children: <Widget>[
              _AssessmentRow(label: '价值', text: decision.valueAssessment),
              _AssessmentRow(label: '目标', text: decision.goalAssessment),
              _AssessmentRow(label: '路径', text: decision.methodAssessment),
              _AssessmentRow(label: '行动', text: decision.actionAssessment),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          color: _sage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('无论选择什么，保留这些高层价值', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: decision.retainedValues.map((value) => _Pill(text: value)).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.pop(context, decision),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Text('确认这次校准'),
          ),
        ),
        TextButton(
          onPressed: () => setState(() {
            _decision = null;
            _index = 0;
            _answers.clear();
          }),
          child: const Text('重新判断'),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.color = Colors.white,
  });

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x0F20342D)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x0A20342D), blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    this.background = const Color(0xFFDDE9E1),
    this.foreground = _moss,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.text});

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: _moss),
          const SizedBox(width: 8),
          SizedBox(width: 68, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}

class _ContentTypeLabel extends StatelessWidget {
  const _ContentTypeLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '内容类型：$text',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE9E0C8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF6C5931), fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _BoundaryNote extends StatelessWidget {
  const _BoundaryNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.info_outline, size: 17, color: Colors.black54),
        SizedBox(width: 7),
        Expanded(
          child: Text(
            '向己是目标指导工具，不替代医疗、心理治疗、危机干预、法律或财务专业服务。',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _AssessmentRow extends StatelessWidget {
  const _AssessmentRow({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Pill(text: label),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        children: <Widget>[
          Icon(icon, size: 34, color: _moss),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 5),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, height: 1.4)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
