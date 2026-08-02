import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'xiangji_book_service.dart';
import 'xiangji_dao.dart';
import 'xiangji_engine.dart';
import 'xiangji_knowledge_repository.dart';
import 'xiangji_models.dart';
import 'xiangji_reminder_service.dart';

const Color _ink = Color(0xFF20342D);
const Color _moss = Color(0xFF3D725D);
const Color _sand = Color(0xFFF5F0E6);
const Color _sage = Color(0xFFE6EFE9);

class XiangjiGoalMentorPage extends StatefulWidget {
  const XiangjiGoalMentorPage({super.key});

  @override
  State<XiangjiGoalMentorPage> createState() =>
      _XiangjiGoalMentorPageState();
}

class _XiangjiGoalMentorPageState extends State<XiangjiGoalMentorPage> {
  final XiangjiGoalMentorDao _dao = XiangjiGoalMentorDao();
  final XiangjiKnowledgeRepository _knowledge = XiangjiKnowledgeRepository();
  final XiangjiGoalMentorEngine _engine = XiangjiGoalMentorEngine();
  late final XiangjiReminderService _reminders =
      XiangjiReminderService(dao: _dao);
  late final XiangjiBookService _books = XiangjiBookService(dao: _dao);
  final TextEditingController _goalController = TextEditingController();
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
  List<XiangjiGrowthEvidence> _evidence = const <XiangjiGrowthEvidence>[];
  List<XiangjiGoal> _allGoals = const <XiangjiGoal>[];
  List<Map<String, Object?>> _versions = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _events = const <Map<String, Object?>>[];
  List<XiangjiBookInfo> _importedBooks = const <XiangjiBookInfo>[];
  XiangjiReminderSettings _reminderSettings =
      XiangjiReminderSettings.defaults();
  XiangjiZoomMode _zoomMode = XiangjiZoomMode.panorama;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _goalController.dispose();
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
      final catalog = await _knowledge.load();
      final goal = await _dao.activeGoal();
      if (goal != null) await _dao.markGoalSeen(goal.id);
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
      XiangjiGuidance? guidance;
      if (goal != null) {
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
        _guidance = guidance;
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
      _showMessage('先写下此刻最不想忘记的目标，哪怕它还很模糊。');
      return;
    }
    final safety = _engine.assessSafety(text);
    if (safety.highRisk) {
      await _showSafetyDialog(safety.message);
      return;
    }
    setState(() => _working = true);
    try {
      final draft = _engine.buildDraft(text, _catalog!);
      if (!mounted) return;
      setState(() => _draft = draft);
    } catch (error) {
      _showMessage(_cleanError(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
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
    final regenerated = _engine.buildDraft(result.first, _catalog!);
    final parsedValues = result[2]
        .split(RegExp('[、,，]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(5)
        .toList();
    if (!mounted) return;
    setState(() {
      _draft = regenerated.copyWith(
        whyText: result[1].isEmpty ? regenerated.whyText : result[1],
        higherValues: parsedValues.isEmpty ? regenerated.higherValues : parsedValues,
        successDefinition: result[3].isEmpty ? regenerated.successDefinition : result[3],
        scopeText: result[4].isEmpty ? regenerated.scopeText : result[4],
      );
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
      );
      if (!mounted) return;
      setState(() => _draft = null);
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
      _engine.createStep(goal.originalText, guidance),
      trigger: 'next_step_generated',
    );
    await _reload();
  }

  Future<void> _openLostMode() async {
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
        _engine.createStep(updated.originalText, guidance),
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
        content: Text('将删除“${book.title}”的本地文件与元数据。内置授权书库不受影响。'),
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
      await _books.deletePrivateBook(book);
      await _reload();
      _showMessage('私人书籍文件和本地元数据已删除。');
    } catch (error) {
      _showMessage('删除未完成：${_cleanError(error)}');
    } finally {
      if (mounted) setState(() => _working = false);
    }
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
        content: const Text('这会删除目标、版本、行动、成长证据、校准记录、提醒设置、私人书籍和应用内历史导出文件。此操作无法撤销。'),
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

  Future<void> _showSafetyDialog(String message) {
    return showDialog<void>(
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
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          _buildGoalSeedCard(),
          const SizedBox(height: 14),
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
        const SizedBox(height: 20),
        TextField(
          controller: _goalController,
          focusNode: _goalFocus,
          minLines: 3,
          maxLines: 6,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: '例如：我不想再忘记自己真正想完成的那件事……',
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
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _working ? null : _createDraft,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Text('帮我形成目标火种'),
          ),
        ),
        if (_draft != null) ...<Widget>[
          const SizedBox(height: 24),
          _buildDraftCard(_draft!),
        ],
        const SizedBox(height: 20),
        const _BoundaryNote(),
      ],
    );
  }

  Widget _buildDraftCard(XiangjiGoalDraft draft) {
    return _SectionCard(
      color: _sand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.local_fire_department_outlined, color: Color(0xFFA25D32)),
              SizedBox(width: 8),
              Text('目标火种卡草案', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            ],
          ),
          const SizedBox(height: 14),
          Text(draft.originalText, style: const TextStyle(fontSize: 20, height: 1.45, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 12),
          Text(draft.whyText, style: const TextStyle(height: 1.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: draft.higherValues.map((value) => _Pill(text: value)).toList(),
          ),
          const SizedBox(height: 10),
          Text('成功定义：${draft.successDefinition}', style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 4),
          Text('当前范围：${draft.scopeText}', style: const TextStyle(fontSize: 13, height: 1.4)),
          const Divider(height: 28),
          Text('当前主要导师 · ${draft.guidance.mentorName}', style: const TextStyle(color: _moss, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const _ContentTypeLabel(text: '根据本地知识库转述'),
          const SizedBox(height: 6),
          Text(draft.guidance.coreJudgment, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 12),
          Text('探索行动：${draft.step.actionText}', style: const TextStyle(fontWeight: FontWeight.w600, height: 1.45)),
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
                  setState(() => _draft = null);
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
          const Text('私人文件默认只保存在设备。未完成受控解析、来源定位和授权前，不会用于思想家观点生成。', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 10),
          if (_importedBooks.isEmpty)
            const _EmptyState(icon: Icons.menu_book_outlined, title: '尚未导入私人书籍', message: '支持 PDF、EPUB、DOCX、TXT、Markdown 和 AZW3。')
          else
            ..._importedBooks.map(
              (book) => Card(
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: _sand, child: Icon(Icons.lock_outline, color: _moss)),
                  title: Text(book.title),
                  subtitle: const Text('本地私密 · 尚未索引，不参与严格生成'),
                  trailing: IconButton(
                    tooltip: '删除本地书籍',
                    onPressed: () => _deletePrivateBook(book),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
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

  Future<void> _showBookDetails(XiangjiBookInfo book) {
    final status = book.sourceStatus == 'primary_source_opened'
        ? '原始来源已打开并完成定位审计'
        : book.sourceStatus == 'secondary_teaching_source'
            ? '教学性二手来源，使用时保留来源边界'
            : book.sourceStatus == 'public_substitute_verified'
                ? '已验证的公共替代来源'
                : book.sourceStatus;
    return showModalBottomSheet<void>(
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
                subtitle: Text('内置知识与来源可离线使用；没有依据时停止，不凭模型记忆补写。'),
                trailing: Icon(Icons.check_circle, color: _moss),
              ),
              _BoundaryNote(),
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
  const _SectionCard({required this.child, this.color = Colors.white});

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
