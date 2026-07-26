import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'mental_health_assessment_page.dart';
import 'mental_health_content_governance_page.dart';
import 'mental_health_checkup_ai_service.dart';
import 'mental_health_checkup_catalog.dart';
import 'mental_health_checkup_engine.dart';
import 'mental_health_checkup_models.dart';
import 'mental_health_checkup_repository.dart';
import 'mental_health_checkup_trends.dart';

class MentalHealthCheckupPage extends StatefulWidget {
  final int initialTab;

  const MentalHealthCheckupPage({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<MentalHealthCheckupPage> createState() =>
      _MentalHealthCheckupPageState();
}

class _MentalHealthCheckupPageState extends State<MentalHealthCheckupPage>
    with WidgetsBindingObserver {
  final MentalHealthCheckupRepository _repository =
      MentalHealthCheckupRepository();
  final MentalHealthCheckupAiService _ai = MentalHealthCheckupAiService();
  MentalHealthCheckupCatalog? _catalog;
  MentalHealthCheckupState _state = const MentalHealthCheckupState();
  Map<String, dynamic>? _draft;
  bool _loading = true;
  String? _loadError;
  int _tabIndex = 0;
  bool _understandsNonMedical = false;
  bool _understandsSafety = false;
  bool _aiLoading = false;
  String _aiNarrative = '';
  bool _aiNarrativeUsedRemote = false;
  bool _appLockRequired = false;
  bool _appLockUnlocking = false;
  String _appLockMessage = '';
  int? _backgroundedAtMs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabIndex = widget.initialTab.clamp(0, 4).toInt();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repository.setSecureScreenEnabled(false).ignore();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || !_state.settings.appLockEnabled) return;
    if (state == AppLifecycleState.paused && !_appLockUnlocking) {
      _backgroundedAtMs = DateTime.now().millisecondsSinceEpoch;
      return;
    }
    if (state == AppLifecycleState.resumed && !_appLockUnlocking) {
      final backgroundedAtMs = _backgroundedAtMs;
      _backgroundedAtMs = null;
      if (backgroundedAtMs != null &&
          DateTime.now().millisecondsSinceEpoch - backgroundedAtMs >= 5000) {
        setState(() => _appLockRequired = true);
        WidgetsBinding.instance.addPostFrameCallback((_) => _unlockAppLock());
      }
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final seedCatalog = await MentalHealthCheckupCatalog.load();
      final state = await _repository.load(catalog: seedCatalog);
      final governedContent = await _repository.loadContentCandidates();
      final catalog = seedCatalog.withPublishedContent(governedContent);
      final draft = await _repository.loadDraft();
      try {
        await _repository.syncPlatformSettings(state);
      } catch (_) {
        // A platform reminder/privacy bridge failure must not block access to
        // the local assessment records. The next settings save retries it.
      }
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _state = state;
        _draft = draft;
        _appLockRequired = state.settings.appLockEnabled;
        _appLockMessage = '';
        _loading = false;
      });
      if (state.settings.appLockEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _unlockAppLock());
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  Future<bool> _unlockAppLock() async {
    if (_appLockUnlocking || !_state.settings.appLockEnabled) {
      return !_appLockRequired;
    }
    setState(() {
      _appLockUnlocking = true;
      _appLockMessage = '';
    });
    try {
      final available = await _repository.canAuthenticateAppLock();
      if (!available) {
        if (!mounted) return false;
        setState(() {
          _appLockRequired = true;
          _appLockMessage = '设备尚未设置PIN、图案或密码，请先在系统设置中配置设备锁。';
        });
        return false;
      }
      final authenticated = await _repository.authenticateAppLock();
      if (!mounted) return authenticated;
      setState(() {
        _appLockRequired = !authenticated;
        _appLockMessage = authenticated ? '' : '未完成设备凭据验证，记录仍保持锁定。';
      });
      return authenticated;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _appLockRequired = true;
        _appLockMessage = '无法调用系统设备锁：$error';
      });
      return false;
    } finally {
      if (mounted) setState(() => _appLockUnlocking = false);
    }
  }

  Future<void> _acceptOnboarding() async {
    if (!_understandsNonMedical || !_understandsSafety) return;
    final next = await _repository.acceptOnboarding(_state);
    await _repository.syncPlatformSettings(next);
    if (mounted) setState(() => _state = next);
  }

  Future<void> _startAssessment(
    CheckupModeSpec mode, {
    String? focusDomainId,
    Map<String, dynamic>? draft,
    CheckupAssessmentPlan? assessmentPlan,
    bool isRetest = false,
    CheckupPrescriptionPlan? retestPlan,
  }) async {
    final catalog = _catalog;
    if (catalog == null) return;
    var domainId = focusDomainId;
    if (mode.id == 'focused' && domainId == null) {
      domainId = await _chooseFocusDomain();
      if (domainId == null || !mounted) return;
    }
    final CheckupAssessmentPlan resolvedPlan;
    if (draft != null) {
      resolvedPlan = assessmentPlan ??
          CheckupAssessmentPlan.fromJson(
            Map<String, dynamic>.from(
              draft['assessment_plan'] as Map? ??
                  const <String, dynamic>{},
            ),
          );
    } else {
      final selectedPlan = await _showAssessmentPreflight(mode, domainId);
      if (selectedPlan == null || !mounted) return;
      resolvedPlan = selectedPlan;
    }
    final session = await Navigator.of(context).push<CheckupSession>(
      MaterialPageRoute(
        builder: (_) => MentalHealthAssessmentPage(
          catalog: catalog,
          mode: mode,
          repository: _repository,
          focusDomainId: domainId,
          draft: draft,
          assessmentPlan: resolvedPlan,
          history: _state.sessions,
        ),
      ),
    );
    if (session == null || !mounted) {
      final nextDraft = await _repository.loadDraft();
      if (mounted) setState(() => _draft = nextDraft);
      return;
    }
    if (isRetest && retestPlan != null) {
      await _completeRetest(retestPlan, session);
      return;
    }
    final next = await _repository.addSession(_state, session);
    if (!mounted) return;
    setState(() {
      _state = next;
      _draft = null;
      _tabIndex = 1;
      _aiNarrative = '';
      _aiNarrativeUsedRemote = false;
    });
  }

  Future<String?> _chooseFocusDomain() async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '选择本轮重点领域',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                '聚焦深入版仍会先完成安全门和功能门，然后围绕一个领域做30项轮换追问。',
                style: TextStyle(color: Color(0xFF667085), height: 1.4),
              ),
              const SizedBox(height: 12),
              for (final entry
                  in MentalHealthCheckupCatalog.domainNames.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                        _domainColor(entry.key).withValues(alpha: 0.12),
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        color: _domainColor(entry.key),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(entry.value),
                  subtitle: Text(
                    MentalHealthCheckupCatalog.domainDescriptions[entry.key] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pop(entry.key),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<CheckupAssessmentPlan?> _showAssessmentPreflight(
      CheckupModeSpec mode, String? domainId) {
    var plan = CheckupAssessmentPlan.forMode(mode, _state.settings);
    final timeOptions = <int>{5, 10, 20, 35, 60, plan.timeBudgetMinutes}
        .toList(growable: false)
      ..sort();
    return showModalBottomSheet<CheckupAssessmentPlan>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _ModeIcon(modeId: mode.id, size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            mode.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${mode.duration} · 本轮最多 ${plan.questionLimit} 题',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _InfoStrip(
                  icon: Icons.shield_outlined,
                  color: const Color(0xFFB54708),
                  title: '安全门优先',
                  text: '安全题命中或不确定时，立即停止普通课程评分和课程行动处方。',
                ),
                const SizedBox(height: 10),
                const _InfoStrip(
                  icon: Icons.offline_bolt_outlined,
                  color: Color(0xFF39715D),
                  title: '默认完全离线',
                  text: '题目、评分、课程机制候选、课程行动处方与复验均在本机完成。',
                ),
                if (domainId != null) ...<Widget>[
                  const SizedBox(height: 10),
                  _InfoStrip(
                    icon: Icons.center_focus_strong,
                    color: _domainColor(domainId),
                    title:
                        '本轮聚焦：${MentalHealthCheckupCatalog.domainNames[domainId]}',
                    text: MentalHealthCheckupCatalog
                            .domainDescriptions[domainId] ??
                        '',
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  '本轮评估偏好',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  '可用时间约 ${plan.timeBudgetMinutes} 分钟；'
                  '题量范围 ${mode.baseQuestionCount}-${mode.maxQuestionCount} 题。',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: timeOptions
                      .map(
                        (minutes) => ChoiceChip(
                          label: Text('$minutes分钟'),
                          selected: plan.timeBudgetMinutes == minutes,
                          onSelected: (_) => setSheetState(
                            () => plan =
                                plan.copyWith(timeBudgetMinutes: minutes),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 14),
                Text(
                  '本轮题量上限：${plan.questionLimit}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Slider(
                  value: plan.questionLimit.toDouble().clamp(
                        mode.baseQuestionCount.toDouble(),
                        mode.maxQuestionCount.toDouble(),
                      ).toDouble(),
                  min: mode.baseQuestionCount.toDouble(),
                  max: mode.maxQuestionCount.toDouble(),
                  divisions: mode.maxQuestionCount == mode.baseQuestionCount
                      ? null
                      : mode.maxQuestionCount - mode.baseQuestionCount,
                  label: '${plan.questionLimit}题',
                  onChanged: mode.maxQuestionCount == mode.baseQuestionCount
                      ? null
                      : (value) => setSheetState(
                            () => plan =
                                plan.copyWith(questionLimit: value.round()),
                          ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: plan.includeUncoveredCheck,
                  onChanged: (value) => setSheetState(
                    () => plan =
                        plan.copyWith(includeUncoveredCheck: value),
                  ),
                  secondary: const Icon(Icons.manage_search_outlined),
                  title: const Text('检查题目未覆盖的重要变化'),
                  subtitle: const Text('只保存“有/无”结构化信号，不保存开放题原文。'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: plan.wantsCourseAction,
                  onChanged: (value) => setSheetState(
                    () => plan = plan.copyWith(wantsCourseAction: value),
                  ),
                  secondary: const Icon(Icons.directions_run_outlined),
                  title: const Text('本轮愿意接收一项课程行动'),
                  subtitle: const Text('关闭后只生成评估报告，不生成课程行动处方。'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: plan.useLongitudinalPrioritization,
                  onChanged: _state.sessions.isEmpty
                      ? null
                      : (value) => setSheetState(
                            () => plan = plan.copyWith(
                              useLongitudinalPrioritization: value,
                            ),
                          ),
                  secondary: const Icon(Icons.timeline_outlined),
                  title: const Text('按历史风险与欠覆盖优先抽题'),
                  subtitle: Text(
                    _state.sessions.isEmpty
                        ? '首次评估暂无历史，本轮建立基线。'
                        : '综合当前风险、恶化、不确定性、欠覆盖、随机探索和用户负担。',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '按最近14天的真实情况作答，不按“理想中的自己”作答；不确定就选择不确定。进度会自动保存在本机，可稍后继续。',
                  style: TextStyle(height: 1.55, color: Color(0xFF475467)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(plan),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('按本轮设置开始体检'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resumeDraft() async {
    final draft = _draft;
    final catalog = _catalog;
    if (draft == null || catalog == null) return;
    final modeId = (draft['mode_id'] ?? 'b20').toString();
    await _startAssessment(
      catalog.modeById(modeId),
      focusDomainId: draft['focus_domain_id']?.toString(),
      draft: draft,
      assessmentPlan: CheckupAssessmentPlan.fromJson(
        Map<String, dynamic>.from(
          draft['assessment_plan'] as Map? ?? const <String, dynamic>{},
        ),
      ),
    );
  }

  Future<void> _discardDraft() async {
    await _repository.clearDraft();
    if (mounted) setState(() => _draft = null);
  }

  Future<void> _startPlan(CheckupPrescriptionRecommendation recommendation) async {
    final latest = _state.latestSession?.report;
    final catalog = _catalog;
    if (latest == null || catalog == null || !latest.safetyClear) return;
    final engine = MentalHealthCheckupEngine(catalog);
    final plan = engine.startPlan(latest, recommendation);
    final pausedExisting = _state.plans.map((item) {
      if (item.status == CheckupPlanStatus.active ||
          item.status == CheckupPlanStatus.maintenance) {
        return item.copyWith(status: CheckupPlanStatus.paused);
      }
      return item;
    }).toList(growable: false);
    final next = _state.copyWith(plans: <CheckupPrescriptionPlan>[
      plan,
      ...pausedExisting,
    ]);
    await _repository.save(next);
    await _repository.syncPlatformSettings(next);
    if (!mounted) return;
    setState(() {
      _state = next;
      _tabIndex = 2;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已从“微量”开始，一次只启用1项课程行动。')),
    );
  }

  Future<void> _recordExecution(CheckupPrescriptionPlan plan) async {
    final log = await showModalBottomSheet<CheckupExecutionLog>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ExecutionCheckInSheet(),
    );
    if (log == null) return;
    var next = await _repository.appendExecutionLog(_state, plan.id, log);
    if (log.overuseRisk >= 50) {
      CheckupPrescriptionPlan? updated;
      for (final item in next.plans) {
        if (item.id == plan.id) {
          updated = item.copyWith(status: CheckupPlanStatus.paused);
          break;
        }
      }
      if (updated != null) {
        next = await _repository.upsertPlan(next, updated);
        await _repository.syncPlatformSettings(next);
      }
    }
    if (!mounted) return;
    setState(() => _state = next);
    if (log.overuseRisk >= 50) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.pause_circle_outline,
            color: Color(0xFFC05621),
            size: 38,
          ),
          title: const Text('已暂停课程行动和提醒'),
          content: const Text(
            '本次过度化/僵化风险达到暂停阈值。请先保护睡眠、关系和现实责任；'
            '之后可在复验中减量、换方或补充评估。',
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _togglePlan(CheckupPrescriptionPlan plan) async {
    final nextPlan = plan.copyWith(
      status: plan.status == CheckupPlanStatus.paused
          ? CheckupPlanStatus.active
          : CheckupPlanStatus.paused,
    );
    final next = await _repository.upsertPlan(_state, nextPlan);
    await _repository.syncPlatformSettings(next);
    if (mounted) setState(() => _state = next);
  }

  Future<void> _rescheduleRetest(CheckupPrescriptionPlan plan) async {
    final current = DateTime.fromMillisecondsSinceEpoch(plan.nextRetestAtMs);
    final today = DateTime.now();
    final firstDate = DateTime(today.year, today.month, today.day);
    final lastDate = DateTime(today.year + 1, today.month, today.day);
    final initialDate = current.isBefore(firstDate)
        ? firstDate
        : current.isAfter(lastDate)
            ? lastDate
            : current;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: '调整下一次复验日期',
      confirmText: '保存日期',
    );
    if (selected == null || !mounted) return;
    var target = DateTime(
      selected.year,
      selected.month,
      selected.day,
      _state.settings.reminderHour,
      _state.settings.reminderMinute,
    );
    if (!target.isAfter(DateTime.now())) {
      target = DateTime.now().add(const Duration(hours: 1));
    }
    final nextPlan = plan.copyWith(
      nextRetestAtMs: target.millisecondsSinceEpoch,
    );
    final next = await _repository.upsertPlan(_state, nextPlan);
    await _repository.syncPlatformSettings(next);
    if (!mounted) return;
    setState(() => _state = next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('下一次复验已调整为 ${_date(target.millisecondsSinceEpoch)}。')),
    );
  }

  Future<void> _runRetest(CheckupPrescriptionPlan plan) async {
    final catalog = _catalog;
    if (catalog == null) return;
    await _startAssessment(
      catalog.modeById('b20'),
      isRetest: true,
      retestPlan: plan,
    );
  }

  Future<void> _completeRetest(
    CheckupPrescriptionPlan plan,
    CheckupSession session,
  ) async {
    final catalog = _catalog;
    if (catalog == null) return;
    CheckupReport? baseline;
    for (final item in _state.sessions) {
      if (item.report.id == plan.sourceReportId) {
        baseline = item.report;
        break;
      }
    }
    baseline ??= _state.latestSession?.report;
    if (baseline == null) return;
    final engine = MentalHealthCheckupEngine(catalog);
    final retest = engine.evaluateRetest(
      plan: plan,
      baseline: baseline,
      retest: session.report,
      priorRetests: _state.retests
          .where((item) => item.planId == plan.id)
          .toList(growable: false),
    );
    final updatedPlan = engine.applyRetestDecision(plan, retest);
    final next = await _repository.completeRetest(
      state: _state,
      session: session,
      retest: retest,
      updatedPlan: updatedPlan,
    );
    await _repository.syncPlatformSettings(next);
    if (!mounted) return;
    setState(() {
      _state = next;
      _draft = null;
      _tabIndex = 3;
      _aiNarrative = '';
    });
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.fact_check_outlined, size: 36),
        title: Text(retest.decision),
        content: Text(retest.reason),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAiNarrative(CheckupReport report) async {
    final scope = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.cloud_upload_outlined),
        title: const Text('选择本次 AI 解释范围'),
        content: const Text(
          '离线规则报告已经完成。你可以只发送当前结构化报告，或同时发送本机历史趋势、行动执行、复验和课程证据关系。不会发送开放题原文、install_id 或当地支持号码。AI只能解释，不能改写安全状态、评分或处方上限。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('保持离线'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('current'),
            child: const Text('仅当前报告'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop('history'),
            icon: const Icon(Icons.timeline_outlined),
            label: const Text('包含历史与证据'),
          ),
        ],
      ),
    );
    if (scope == null || !mounted) return;
    setState(() => _aiLoading = true);
    final fallback = _localNarrative(report);
    final indicatorIds = report.domains
        .expand((domain) => domain.indicatorIds)
        .toSet();
    final evidenceTraces =
        await _repository.evidenceTracesForIndicators(indicatorIds);
    final result = await _ai.explainReport(
      report,
      fallback: fallback,
      state: _state,
      catalog: _catalog,
      evidenceTraces: evidenceTraces,
      includeHistory: scope == 'history',
    );
    if (!mounted) return;
    setState(() {
      _aiLoading = false;
      _aiNarrative = result.text;
      _aiNarrativeUsedRemote = result.usedAi;
    });
  }

  Future<void> _generateAiRetestNarrative(
    CheckupRetestRecord retest,
  ) async {
    final catalog = _catalog;
    if (catalog == null) return;
    final scope = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.fact_check_outlined),
        title: const Text('解释这次复验'),
        content: const Text(
          '可以只发送本次复验，或同时包含基线、历史复验、执行日志、课程证据和调整规则。不会发送开放题原文、install_id 或当地支持号码。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('保持离线'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('current'),
            child: const Text('仅本次复验'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('history'),
            child: const Text('包含完整闭环'),
          ),
        ],
      ),
    );
    if (scope == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在生成复验解释…')),
    );
    final indicatorIds = <String>{};
    for (final session in _state.sessions) {
      if (session.report.id != retest.baselineReportId &&
          session.report.id != retest.retestReportId) {
        continue;
      }
      for (final domain in session.report.domains) {
        indicatorIds.addAll(domain.indicatorIds);
      }
    }
    final evidenceTraces =
        await _repository.evidenceTracesForIndicators(indicatorIds);
    final result = await _ai.explainRetest(
      retest,
      fallback: '${retest.decision}\n\n${retest.reason}',
      state: _state,
      catalog: catalog,
      evidenceTraces: evidenceTraces,
      includeHistory: scope == 'history',
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI课程复验解释'),
        content: SingleChildScrollView(
          child: SelectableText(result.text),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(result.usedAi ? '完成' : '本地回退 · 完成'),
          ),
        ],
      ),
    );
  }

  String _localNarrative(CheckupReport report) {
    final lowest = report.domains.where((e) => e.answered > 0).toList()
      ..sort((a, b) => a.score.compareTo(b.score));
    final buffer = StringBuffer()
      ..writeln('本轮覆盖度 ${report.coverage.toStringAsFixed(0)}%，数据质量 ${report.dataQuality.toStringAsFixed(0)}%。')
      ..writeln('安全状态：${_safetyText(report.safetyStatus)}；现实功能影响 ${report.functionImpact}/4。');
    if (lowest.isNotEmpty) {
      buffer.writeln('当前最值得关注的已覆盖领域是${lowest.take(2).map((e) => e.name).join('、')}。');
    }
    if (report.diagnoses.isNotEmpty) {
      buffer.writeln('优先验证的课程机制候选：${report.diagnoses.first.name}。这不是人格判决，也不是医学诊断。');
    }
    if (report.prescriptions.isNotEmpty) {
      buffer.writeln('当前只启动一项课程行动：${report.prescriptions.first.startingAction}');
    }
    return buffer.toString().trim();
  }

  Future<void> _exportCurrentReport(CheckupReport report) async {
    try {
      final saved = await _repository.exportReportPdf(report);
      if (!mounted || !saved) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF 报告已保存到你选择的位置。')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF 导出失败：$error')),
      );
    }
  }

  Future<void> _exportBackup() async {
    final catalog = _catalog;
    if (catalog == null) return;
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _BackupPasswordDialog(confirmPassword: true),
    );
    if (password == null || !mounted) return;
    try {
      final saved = await _repository.exportEncryptedBackup(
        catalog: catalog,
        password: password,
      );
      if (!mounted || !saved) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加密备份已保存。请将文件和密码分开保管。')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('备份导出失败：$error')),
      );
    }
  }

  Future<void> _importBackup() async {
    final catalog = _catalog;
    if (catalog == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.restore_page_outlined),
        title: const Text('导入加密备份？'),
        content: const Text(
          '系统会先在临时内存中完成密码认证、格式版本、种子版本、哈希、记录数、重复ID和关联关系预检。'
          '全部通过后才会在一个事务中替换本模块数据；失败不会修改现有数据。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('继续预检'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _BackupPasswordDialog(confirmPassword: false),
    );
    if (password == null || !mounted) return;
    try {
      final restored = await _repository.importEncryptedBackup(
        catalog: catalog,
        password: password,
      );
      if (!mounted || restored == null) return;
      var imported = restored;
      var appLockDisabledOnImport = false;
      if (imported.settings.appLockEnabled) {
        setState(() => _appLockUnlocking = true);
        var authenticated = false;
        try {
          authenticated =
              await _repository.canAuthenticateAppLock() &&
                  await _repository.authenticateAppLock();
        } catch (_) {
          authenticated = false;
        } finally {
          if (mounted) setState(() => _appLockUnlocking = false);
        }
        if (!authenticated) {
          appLockDisabledOnImport = true;
          imported = await _repository.updateSettings(
            imported,
            imported.settings.copyWith(appLockEnabled: false),
          );
        }
      }
      await _repository.syncPlatformSettings(imported);
      setState(() {
        _state = imported;
        _draft = null;
        _tabIndex = 4;
        _aiNarrative = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appLockDisabledOnImport
                ? '备份已导入；设备凭据未验证，因此应用锁保持关闭。'
                : '备份已通过预检并完成原子导入。',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败，现有数据未修改：$error')),
      );
    }
  }

  Future<void> _openLocalSettings() async {
    final settings = await Navigator.of(context)
        .push<MentalHealthCheckupSettings>(
      MaterialPageRoute(
        builder: (_) => MentalHealthCheckupLocalSettingsPage(
          initial: _state.settings,
        ),
      ),
    );
    if (settings == null || !mounted) return;
    var effectiveSettings = settings;
    String? appLockWarning;
    if (settings.appLockEnabled && !_state.settings.appLockEnabled) {
      setState(() => _appLockUnlocking = true);
      try {
        final available = await _repository.canAuthenticateAppLock();
        final authenticated =
            available && await _repository.authenticateAppLock();
        if (!authenticated) {
          effectiveSettings = settings.copyWith(appLockEnabled: false);
          appLockWarning = available
              ? '未完成设备凭据验证，应用锁没有开启；其他设置已保存。'
              : '设备尚未设置PIN、图案或密码，应用锁没有开启；其他设置已保存。';
        }
      } catch (error) {
        effectiveSettings = settings.copyWith(appLockEnabled: false);
        appLockWarning = '系统设备锁验证失败，应用锁没有开启：$error';
      } finally {
        if (mounted) setState(() => _appLockUnlocking = false);
      }
    }
    final next = await _repository.updateSettings(
      _state,
      effectiveSettings,
    );
    await _repository.syncPlatformSettings(next);
    if (!mounted) return;
    setState(() {
      _state = next;
      if (!next.settings.appLockEnabled) _appLockRequired = false;
    });
    if (appLockWarning != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appLockWarning)),
      );
    }
  }

  Future<void> _openEvidenceSearch({
    String initialQuery = '',
    int? lecture,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MentalHealthCourseEvidencePage(
          repository: _repository,
          initialQuery: initialQuery,
          initialLecture: lecture,
        ),
      ),
    );
  }

  Future<void> _openContentGovernance() async {
    final catalog = _catalog;
    if (catalog == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MentalHealthContentGovernancePage(
          catalog: catalog,
          repository: _repository,
        ),
      ),
    );
    if (!mounted) return;
    try {
      final governedContent = await _repository.loadContentCandidates();
      if (!mounted) return;
      setState(() {
        _catalog = catalog.withPublishedContent(governedContent);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正式题库刷新失败：$error')),
      );
    }
  }

  Future<void> _deleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_forever_outlined, color: Color(0xFFC62828)),
        title: const Text('删除本模块全部本地数据？'),
        content: const Text(
          '将删除体检会话、结构化回答、报告、课程行动记录、复验记录、草稿和本模块AI提示词覆盖。此操作无法撤销，不影响App其他模块，也不会删除你自行导出的外部文件。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFC62828)),
        title: const Text('最后确认'),
        content: const Text(
          '删除后无法从本机恢复。只有你此前主动导出的加密备份仍会保留在外部位置。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('返回'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除且重新初始化'),
          ),
        ],
      ),
    );
    if (finalConfirm != true) return;
    await _repository.clearAllModuleData();
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    setState(() {
      _aiNarrative = '';
      _understandsNonMedical = false;
      _understandsSafety = false;
      _tabIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF6F7FB),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('正在校验课程知识与本地规则…'),
            ],
          ),
        ),
      );
    }
    if (_loadError != null || _catalog == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('心理健康体检')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.gpp_bad_outlined, size: 54, color: Color(0xFFC62828)),
                const SizedBox(height: 14),
                const Text(
                  '课程种子校验未通过，已阻止生成新报告',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  _loadError ?? '未知错误',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF667085)),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新校验'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_appLockRequired) return _buildAppLock();
    if (!_state.onboardingAccepted) return _buildOnboarding();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FB),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('心理健康体检', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(
              '哈佛幸福课23讲 · V2.5 本地优先',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: '课程种子与来源边界',
            onPressed: _showSeedInfo,
            icon: const Icon(Icons.verified_user_outlined),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: <Widget>[
          _buildDashboard(),
          _buildReport(),
          _buildPrescription(),
          _buildRetest(),
          _buildArchive(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (value) => setState(() => _tabIndex = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety),
            label: '体检',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: '报告',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: '课程行动',
          ),
          NavigationDestination(
            icon: Icon(Icons.restart_alt_outlined),
            selectedIcon: Icon(Icons.restart_alt),
            label: '复验',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_copy_outlined),
            selectedIcon: Icon(Icons.folder_copy),
            label: '档案',
          ),
        ],
      ),
    );
  }

  Widget _buildAppLock() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F5FA),
        title: const Text('本地记录已锁定'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8ECFF),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.lock_person_outlined,
                  size: 44,
                  color: Color(0xFF4554C5),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '使用设备凭据解锁',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                '验证由Android系统完成；本模块不会接收或保存你的PIN、图案、密码或生物信息。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF667085),
                  height: 1.5,
                ),
              ),
              if (_appLockMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _appLockMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed:
                    _appLockUnlocking ? null : () => _unlockAppLock(),
                icon: _appLockUnlocking
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_open_outlined),
                label: Text(_appLockUnlocking ? '正在调用系统验证…' : '解锁本模块'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnboarding() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: <Color>[Color(0xFF4453C6), Color(0xFF7A5BA7)],
                ),
              ),
              child: const Icon(Icons.health_and_safety, size: 38, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              '不是给你贴标签，\n而是找到下一步。',
              style: TextStyle(
                fontSize: 30,
                height: 1.25,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1D2433),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '用安全门、八域评估、课程证据、行动实验和复验，把“我怎么了”转化为“现在最值得验证什么、今天做什么”。',
              style: TextStyle(fontSize: 16, height: 1.55, color: Color(0xFF596273)),
            ),
            const SizedBox(height: 24),
            const _OnboardingFeature(
              number: '01',
              title: '本地优先',
              text: '无注册、无登录；核心评估、规则报告、课程行动和复验可离线完成。',
              color: Color(0xFF39715D),
            ),
            const _OnboardingFeature(
              number: '02',
              title: '安全先于评分',
              text: '安全题命中或不确定时，停止普通课程结论，优先现实支持与人工复核。',
              color: Color(0xFFC05621),
            ),
            const _OnboardingFeature(
              number: '03',
              title: '课程机制，不是疾病诊断',
              text: '报告保留支持证据、冲突证据和替代解释，不把短期结果说成永久人格。',
              color: Color(0xFF4554C5),
            ),
            const _OnboardingFeature(
              number: '04',
              title: '行动—复验—恢复',
              text: '一次只启用1项课程行动；7天复验，按疗效与功能继续、减量、暂停、换方或维持。',
              color: Color(0xFF7A4E9D),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _understandsNonMedical,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('我理解：这不是医学疾病诊断或药物处方。'),
              onChanged: (value) =>
                  setState(() => _understandsNonMedical = value ?? false),
            ),
            CheckboxListTile(
              value: _understandsSafety,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('我理解：有立即危险时应联系当地紧急服务，而不是继续普通课程练习。'),
              onChanged: (value) =>
                  setState(() => _understandsSafety = value ?? false),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _understandsNonMedical && _understandsSafety
                  ? _acceptOnboarding
                  : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('进入心理健康体检'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final catalog = _catalog!;
    final latest = _state.latestSession?.report;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          _DashboardHero(
            latest: latest,
            activePlan: _state.activePlan,
            onPrimary: () => _startAssessment(catalog.modeById('b20')),
          ),
          if (_draft != null) ...<Widget>[
            const SizedBox(height: 14),
            _DraftCard(
              draft: _draft!,
              onResume: _resumeDraft,
              onDiscard: _discardDraft,
            ),
          ],
          const SizedBox(height: 22),
          const _SectionHeader(
            title: '选择体检方式',
            subtitle: '先按你现在的时间和目的选择；深入并不总是更好。',
          ),
          const SizedBox(height: 12),
          for (final mode in catalog.modes) ...<Widget>[
            _ModeCard(
              mode: mode,
              onTap: () => _startAssessment(mode),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          _SafetyQuickEntry(
            onTap: () => _startAssessment(catalog.modeById('safety')),
          ),
          const SizedBox(height: 22),
          const _SectionHeader(
            title: '它不是一次打分，而是一条恢复路径',
            subtitle: '每一步都保留来源、现实功能和停止条件。',
          ),
          const SizedBox(height: 12),
          const _ClosedLoopTimeline(),
          const SizedBox(height: 20),
          const _LocalPrivacyCard(),
        ],
      ),
    );
  }

  Widget _buildReport() {
    final report = _state.latestSession?.report;
    if (report == null) {
      return _EmptyTab(
        icon: Icons.analytics_outlined,
        title: '还没有体检报告',
        text: '建议先完成 B20 快速基准，建立可复验的个人基线。',
        action: '开始 B20',
        onPressed: () => _startAssessment(_catalog!.modeById('b20')),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        if (!report.safetyClear) ...<Widget>[
          _SafetyRouteCard(
            status: report.safetyStatus,
            emergencyNumber: _state.settings.emergencyNumber,
            crisisNumber: _state.settings.crisisNumber,
            onConfigure: _openLocalSettings,
          ),
          const SizedBox(height: 14),
        ],
        _ReportHero(report: report),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => _exportCurrentReport(report),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('预览完成 · 导出本地 PDF'),
        ),
        const SizedBox(height: 14),
        _MetricGrid(report: report),
        if (report.knowledgeScore != null ||
            report.attitudeScore != null ||
            report.behaviorScore != null) ...<Widget>[
          const SizedBox(height: 12),
          _KabCard(report: report),
        ],
        const SizedBox(height: 20),
        const _SectionHeader(
          title: '八域画像',
          subtitle: '只解释本轮已覆盖领域；未覆盖不等于异常。',
        ),
        const SizedBox(height: 12),
        _DomainRadarCard(domains: report.domains),
        const SizedBox(height: 12),
        for (final domain in report.domains)
          _DomainScoreTile(domain: domain),
        const SizedBox(height: 18),
        const _SectionHeader(
          title: '表层发现',
          subtitle: '事实、功能和回答质量先于原因解释。',
        ),
        const SizedBox(height: 10),
        _BulletCard(items: report.surfaceFindings),
        if (report.safetyClear) ...<Widget>[
          const SizedBox(height: 20),
          const _SectionHeader(
            title: '课程机制候选',
            subtitle: '不是医学诊断，也不是永久人格结论。',
          ),
          const SizedBox(height: 10),
          if (report.diagnoses.isEmpty)
            const _SoftMessage(
              icon: Icons.search_off_outlined,
              text: '当前覆盖或证据不足，暂不生成课程机制候选。建议完成更完整评估或继续纵向观察。',
            )
          else
            for (final diagnosis in report.diagnoses) ...<Widget>[
              _DiagnosisCard(diagnosis: diagnosis),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 10),
          const _SectionHeader(
            title: '课程行动处方',
            subtitle: '“处方”只指课程练习、现实行动、仪式和反思任务。',
          ),
          const SizedBox(height: 10),
          if (report.prescriptions.isEmpty)
            const _SoftMessage(
              icon: Icons.hourglass_empty,
              text: '本轮不分配课程行动：可能因为模式仅用于趋势、安全/覆盖不足，或当前无需增加任务。',
            )
          else
            for (final item in report.prescriptions)
              _RecommendationCard(
                recommendation: item,
                active: _state.activePlan?.prescription.prescriptionId ==
                    item.prescriptionId,
                onStart: () => _startPlan(item),
              ),
          const SizedBox(height: 20),
          _AiExplanationCard(
            loading: _aiLoading,
            narrative: _aiNarrative,
            usedRemote: _aiNarrativeUsedRemote,
            onGenerate: () => _generateAiNarrative(report),
          ),
        ],
        const SizedBox(height: 20),
        _EvidenceAndBoundaryCard(
          report: report,
          onOpenEvidence: () => _openEvidenceSearch(
            initialQuery: report.prescriptions.isNotEmpty
                ? report.prescriptions.first.evidenceLocation
                : _firstLocationId(report.courseEvidence),
            lecture: report.prescriptions.isEmpty
                ? null
                : report.prescriptions.first.lecture,
          ),
        ),
      ],
    );
  }

  Widget _buildPrescription() {
    final plan = _state.activePlan;
    final latest = _state.latestSession?.report;
    if (plan == null) {
      final recommendation = latest?.prescriptions.isNotEmpty == true
          ? latest!.prescriptions.first
          : null;
      return _EmptyTab(
        icon: Icons.route_outlined,
        title: recommendation == null ? '暂无课程行动' : '报告已给出一项课程行动',
        text: recommendation == null
            ? '课程行动不会为了“让你有事做”而自动增加。请先完成适合的评估。'
            : '${recommendation.theme}\n从微量开始，执行7天后复验。',
        action: recommendation == null ? '回到体检' : '启动微量处方',
        onPressed: recommendation == null
            ? () => setState(() => _tabIndex = 0)
            : () => _startPlan(recommendation),
      );
    }
    final days = DateTime.fromMillisecondsSinceEpoch(plan.nextRetestAtMs)
        .difference(DateTime.now())
        .inDays;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        _PlanHero(plan: plan, daysUntilRetest: days),
        const SizedBox(height: 14),
        _ActionDoseCard(plan: plan),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: plan.status == CheckupPlanStatus.paused
                    ? null
                    : () => _recordExecution(plan),
                icon: const Icon(Icons.add_task),
                label: const Text('记录本次执行'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => _togglePlan(plan),
              icon: Icon(plan.status == CheckupPlanStatus.paused
                  ? Icons.play_arrow
                  : Icons.pause),
              label: Text(plan.status == CheckupPlanStatus.paused ? '恢复' : '暂停'),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _rescheduleRetest(plan),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: Text('调整复验日 · ${_date(plan.nextRetestAtMs)}'),
          ),
        ),
        const SizedBox(height: 18),
        const _SectionHeader(
          title: '疗效不是“打卡次数”',
          subtitle: '每次同时记录完成、主观收益、现实功能和过度化。',
        ),
        const SizedBox(height: 10),
        _PlanMetrics(plan: plan),
        const SizedBox(height: 18),
        const _SectionHeader(
          title: '执行记录',
          subtitle: '不写私密原文，只保存结构化变化。',
        ),
        const SizedBox(height: 10),
        if (plan.logs.isEmpty)
          const _SoftMessage(
            icon: Icons.inbox_outlined,
            text: '还没有执行记录。完成一个可接受的最小版本后再记录，不需要追求完美。',
          )
        else
          for (final log in plan.logs) _ExecutionLogTile(log: log),
        const SizedBox(height: 18),
        _StopRuleCard(text: plan.prescription.stopRule),
      ],
    );
  }

  Widget _buildRetest() {
    final plan = _state.activePlan;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        _RetestHero(
          plan: plan,
          onRetest: plan == null ? null : () => _runRetest(plan),
          onReschedule:
              plan == null ? null : () => _rescheduleRetest(plan),
        ),
        const SizedBox(height: 18),
        const _SectionHeader(
          title: '纵向趋势',
          subtitle: '与自己过去的基线比较，不把一次波动当成最终结论。',
        ),
        const SizedBox(height: 10),
        _TrendCard(sessions: _state.sessions),
        if (_state.sessions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _TrendInsightsCard(
            insights:
                const MentalHealthCheckupTrendAnalyzer().analyze(_state.sessions),
          ),
        ],
        const SizedBox(height: 18),
        const _SectionHeader(
          title: '处方调整规则',
          subtitle: '规则在本机运行，AI不能覆盖。',
        ),
        const SizedBox(height: 10),
        _AdjustmentRulesCard(
          rules: _catalog?.prescriptionAdjustmentRules ??
              const <CheckupReferenceRule>[],
        ),
        const SizedBox(height: 18),
        const _SectionHeader(
          title: '复验记录',
          subtitle: '继续、减量、暂停、换方、重新诊断或进入维持。',
        ),
        const SizedBox(height: 10),
        if (_state.retests.isEmpty)
          const _SoftMessage(
            icon: Icons.history_toggle_off,
            text: '完成至少一个课程行动周期后，这里会显示基线—复验对比与调整决定。',
          )
        else
          for (final record in _state.retests)
            _RetestRecordCard(
              record: record,
              onExplain: () => _generateAiRetestNarrative(record),
            ),
      ],
    );
  }

  Widget _buildArchive() {
    final catalog = _catalog!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        _ArchiveSummary(state: _state),
        const SizedBox(height: 18),
        const _SectionHeader(
          title: '历史体检',
          subtitle: '报告保留当时的规则版本和课程来源。',
        ),
        const SizedBox(height: 10),
        if (_state.sessions.isEmpty)
          const _SoftMessage(
            icon: Icons.folder_open_outlined,
            text: '暂无历史记录。',
          )
        else
          for (final session in _state.sessions.take(20))
            _SessionHistoryTile(
              session: session,
              onTap: () => _showHistoricalReport(session.report),
            ),
        const SizedBox(height: 18),
        const _SectionHeader(
          title: '设置与治理',
          subtitle: '隐私、种子、AI和本地数据由你控制。',
        ),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.notifications_active_outlined,
          title: '本地提醒、静默时段与锁屏隐私',
          subtitle: _state.settings.remindersEnabled
              ? '已开启 · ${_twoDigits(_state.settings.reminderHour)}:${_twoDigits(_state.settings.reminderMinute)} · '
                  '静默 ${_twoDigits(_state.settings.quietStartHour)}:00-${_twoDigits(_state.settings.quietEndHour)}:00'
              : '默认关闭；只使用 WorkManager 本地提醒',
          onTap: _openLocalSettings,
        ),
        _SettingsTile(
          icon: Icons.manage_search_outlined,
          title: '课程原文定位与离线检索',
          subtitle: '2253 个稳定定位单元 · FTS/中文回退 · 可核对页码方法',
          onTap: _openEvidenceSearch,
        ),
        _SettingsTile(
          icon: Icons.lock_clock_outlined,
          title: '导出独立密码加密备份',
          subtitle: '系统文件选择器 · PBKDF2-SHA256 · AES-256-GCM',
          onTap: _exportBackup,
        ),
        _SettingsTile(
          icon: Icons.restore_page_outlined,
          title: '预检并导入加密备份',
          subtitle: '先验证版本、哈希、数量、重复ID与关联，再原子替换',
          onTap: _importBackup,
        ),
        _SettingsTile(
          icon: Icons.tune,
          title: '本模块 AI 提示词',
          subtitle: '编辑全局安全、报告、复验和内容候选生成 Prompt',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MentalHealthCheckupPromptPage()),
          ),
        ),
        _SettingsTile(
          icon: Icons.account_tree_outlined,
          title: '课程内容候选治理台',
          subtitle:
              '345项计划 · 正式启用 ${catalog.publishedQuestions.length} 道题 / '
              '${catalog.publishedBehaviorTasks.length} 项任务 · 独立审核与版本审计',
          onTap: _openContentGovernance,
        ),
        _SettingsTile(
          icon: Icons.verified_user_outlined,
          title: '课程种子与完整性',
          subtitle:
              '${catalog.validation.checkedFiles} 个文件通过 SHA-256 与记录数校验 · 版本 ${catalog.validation.version}',
          onTap: _showSeedInfo,
        ),
        _SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: '隐私与能力边界',
          subtitle: '安装标识 ${_shortInstallId(_state.installId)} · 无登录 · '
              'AI需单次同意',
          onTap: _showPrivacyInfo,
        ),
        _SettingsTile(
          icon: Icons.delete_forever_outlined,
          iconColor: const Color(0xFFC62828),
          title: '删除本模块全部本地数据',
          subtitle: '会话、报告、行动、复验、草稿和本模块Prompt',
          onTap: _deleteAll,
        ),
      ],
    );
  }

  Future<void> _showHistoricalReport(CheckupReport report) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.94,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: <Widget>[
            Text(
              '历史报告 · ${_date(report.createdAtMs)}',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _ReportHero(report: report),
            const SizedBox(height: 12),
            _BulletCard(items: report.surfaceFindings),
            const SizedBox(height: 12),
            for (final diagnosis in report.diagnoses)
              _DiagnosisCard(diagnosis: diagnosis),
          ],
        ),
      ),
    );
  }

  Future<void> _showSeedInfo() async {
    final catalog = _catalog;
    if (catalog == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified_user_outlined, color: Color(0xFF39715D)),
        title: const Text('课程知识完整性已验证'),
        content: Text(
          '版本：${catalog.validation.version}\n'
          '已校验文件：${catalog.validation.checkedFiles}\n'
          '指标：${catalog.indicators.length}\n'
          '指标—课程证据关系：1380\n'
          '课程原文定位单元：2253\n'
          'B20固定题：${catalog.b20Questions.length}\n'
          '课程机制模式：${catalog.diagnosisPatterns.length}\n'
          '课程行动处方：${catalog.prescriptions.length}\n\n'
          '每个种子文件在运行前校验 SHA-256 和记录数量；失败时阻止生成新报告。课程专家签发状态仍按原始种子如实显示，不会伪装成已确认。',
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPrivacyInfo() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Text('隐私与能力边界', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              SizedBox(height: 14),
              _InfoStrip(icon: Icons.person_off_outlined, color: Color(0xFF4554C5), title: '无账号', text: '不要求手机号、邮箱、姓名或云端用户档案。'),
              SizedBox(height: 10),
              _InfoStrip(icon: Icons.storage_outlined, color: Color(0xFF39715D), title: '本地事实源', text: '会话、答案、报告、行动、执行和复验写入独立SQLite表；升级走显式迁移，提交与导入使用事务。'),
              SizedBox(height: 10),
              _InfoStrip(icon: Icons.notes_outlined, color: Color(0xFF7A4E9D), title: '敏感数据最小化与加密', text: '不持久化开放题原文；用户配置的当地支持号码使用Android Keystore AES-GCM字段加密。'),
              SizedBox(height: 10),
              _InfoStrip(icon: Icons.backup_outlined, color: Color(0xFF5664D2), title: '不自动上云', text: 'Android自动备份和设备迁移已关闭；只有你主动选择位置并设置独立密码时才导出AES-GCM加密备份。'),
              SizedBox(height: 10),
              _InfoStrip(icon: Icons.auto_awesome_outlined, color: Color(0xFFB54708), title: 'AI是可选解释层', text: '离线报告先生成；只有单次明确同意后，才向用户配置的提供方发送结构化报告。'),
              SizedBox(height: 10),
              _InfoStrip(icon: Icons.medical_information_outlined, color: Color(0xFFC62828), title: '不是医疗替代', text: '不提供疾病诊断、药物建议、医疗处方或治愈承诺。安全状态异常时停止普通课程闭环。'),
            ],
          ),
        ),
      ),
    );
  }
}

class MentalHealthCheckupLocalSettingsPage extends StatefulWidget {
  final MentalHealthCheckupSettings initial;

  const MentalHealthCheckupLocalSettingsPage({
    super.key,
    required this.initial,
  });

  @override
  State<MentalHealthCheckupLocalSettingsPage> createState() =>
      _MentalHealthCheckupLocalSettingsPageState();
}

class _MentalHealthCheckupLocalSettingsPageState
    extends State<MentalHealthCheckupLocalSettingsPage> {
  late bool _remindersEnabled;
  late TimeOfDay _reminderTime;
  late int _quietStartHour;
  late int _quietEndHour;
  late bool _lockScreenPrivacy;
  late bool _secureScreen;
  late bool _appLockEnabled;
  late int _assessmentTimeBudgetMinutes;
  late int _preferredQuestionLimit;
  late bool _includeUncoveredCheck;
  late bool _wantsCourseAction;
  late bool _useLongitudinalPrioritization;
  late final TextEditingController _emergencyController;
  late final TextEditingController _crisisController;

  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    _remindersEnabled = value.remindersEnabled;
    _reminderTime = TimeOfDay(
      hour: value.reminderHour,
      minute: value.reminderMinute,
    );
    _quietStartHour = value.quietStartHour;
    _quietEndHour = value.quietEndHour;
    _lockScreenPrivacy = value.lockScreenPrivacy;
    _secureScreen = value.secureScreen;
    _appLockEnabled = value.appLockEnabled;
    _assessmentTimeBudgetMinutes = value.assessmentTimeBudgetMinutes;
    _preferredQuestionLimit = value.preferredQuestionLimit;
    _includeUncoveredCheck = value.includeUncoveredCheck;
    _wantsCourseAction = value.wantsCourseAction;
    _useLongitudinalPrioritization =
        value.useLongitudinalPrioritization;
    _emergencyController =
        TextEditingController(text: value.emergencyNumber);
    _crisisController = TextEditingController(text: value.crisisNumber);
  }

  @override
  void dispose() {
    _emergencyController.dispose();
    _crisisController.dispose();
    super.dispose();
  }

  Future<void> _toggleReminders(bool enabled) async {
    if (!enabled) {
      setState(() => _remindersEnabled = false);
      return;
    }
    final status = await Permission.notification.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() => _remindersEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('未获得通知权限；体检、报告和复验仍可完全离线使用。'),
        ),
      );
      return;
    }
    setState(() => _remindersEnabled = true);
  }

  Future<void> _pickReminderTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: '选择课程行动提醒时间',
    );
    if (value != null && mounted) setState(() => _reminderTime = value);
  }

  Future<void> _pickQuietHour({required bool start}) async {
    final initial = TimeOfDay(
      hour: start ? _quietStartHour : _quietEndHour,
      minute: 0,
    );
    final value = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: start ? '静默时段开始' : '静默时段结束',
    );
    if (value == null || !mounted) return;
    setState(() {
      if (start) {
        _quietStartHour = value.hour;
      } else {
        _quietEndHour = value.hour;
      }
    });
  }

  String _cleanNumber(String raw) =>
      raw.replaceAll(RegExp(r'[^0-9+*#]'), '');

  void _save() {
    Navigator.of(context).pop(
      widget.initial.copyWith(
        remindersEnabled: _remindersEnabled,
        reminderHour: _reminderTime.hour,
        reminderMinute: _reminderTime.minute,
        quietStartHour: _quietStartHour,
        quietEndHour: _quietEndHour,
        lockScreenPrivacy: _lockScreenPrivacy,
        secureScreen: _secureScreen,
        appLockEnabled: _appLockEnabled,
        emergencyNumber: _cleanNumber(_emergencyController.text),
        crisisNumber: _cleanNumber(_crisisController.text),
        assessmentTimeBudgetMinutes: _assessmentTimeBudgetMinutes,
        preferredQuestionLimit: _preferredQuestionLimit,
        includeUncoveredCheck: _includeUncoveredCheck,
        wantsCourseAction: _wantsCourseAction,
        useLongitudinalPrioritization:
            _useLongitudinalPrioritization,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('评估、提醒与隐私'),
          actions: <Widget>[
            TextButton(onPressed: _save, child: const Text('保存')),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            const Text(
              '默认评估偏好',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              '每次开始前仍可单独调整；模式的固定安全门和最低题量不会被跳过。',
              style: TextStyle(color: Color(0xFF667085), height: 1.45),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <int>[5, 10, 20, 35, 60]
                  .map(
                    (minutes) => ChoiceChip(
                      label: Text('$minutes分钟'),
                      selected: _assessmentTimeBudgetMinutes == minutes,
                      onSelected: (_) => setState(
                        () => _assessmentTimeBudgetMinutes = minutes,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 14),
            Text(
              '默认题量上限：$_preferredQuestionLimit',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Slider(
              value: _preferredQuestionLimit.toDouble(),
              min: 5,
              max: 120,
              divisions: 23,
              label: '$_preferredQuestionLimit题',
              onChanged: (value) => setState(
                () => _preferredQuestionLimit =
                    (value / 5).round() * 5,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeUncoveredCheck,
              onChanged: (value) =>
                  setState(() => _includeUncoveredCheck = value),
              secondary: const Icon(Icons.manage_search_outlined),
              title: const Text('检查题目未覆盖的重要变化'),
              subtitle: const Text('仅保存结构化信号，不保存开放题原文。'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _wantsCourseAction,
              onChanged: (value) =>
                  setState(() => _wantsCourseAction = value),
              secondary: const Icon(Icons.directions_run_outlined),
              title: const Text('愿意接收一项课程行动'),
              subtitle: const Text('关闭后只评估，不生成课程行动处方。'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _useLongitudinalPrioritization,
              onChanged: (value) => setState(
                () => _useLongitudinalPrioritization = value,
              ),
              secondary: const Icon(Icons.timeline_outlined),
              title: const Text('启用纵向加权抽题'),
              subtitle: const Text(
                '按风险30%、恶化25%、不确定性15%、欠覆盖20%、随机探索10%和用户负担-15%排序。',
              ),
            ),
            const Divider(height: 32),
            const Text(
              '本地提醒',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            SwitchListTile(
              value: _remindersEnabled,
              onChanged: _toggleReminders,
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('开启本地课程行动提醒'),
              subtitle: const Text(
                '默认关闭；使用 WorkManager，不依赖推送服务，拒绝权限不影响核心功能。',
              ),
            ),
            ListTile(
              enabled: _remindersEnabled,
              leading: const Icon(Icons.schedule),
              title: const Text('每日提醒时间'),
              subtitle: Text(_reminderTime.format(context)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _remindersEnabled ? _pickReminderTime : null,
            ),
            ListTile(
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('静默时段'),
              subtitle: Text(
                '${_twoDigits(_quietStartHour)}:00 - '
                '${_twoDigits(_quietEndHour)}:00',
              ),
              trailing: Wrap(
                spacing: 4,
                children: <Widget>[
                  TextButton(
                    onPressed: () => _pickQuietHour(start: true),
                    child: const Text('开始'),
                  ),
                  TextButton(
                    onPressed: () => _pickQuietHour(start: false),
                    child: const Text('结束'),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              value: _lockScreenPrivacy,
              onChanged: (value) =>
                  setState(() => _lockScreenPrivacy = value),
              secondary: const Icon(Icons.phonelink_lock_outlined),
              title: const Text('锁屏隐藏提醒内容'),
              subtitle: const Text('通知只显示中性提示，不显示分数、模式或课程机制名称。'),
            ),
            SwitchListTile(
              value: _secureScreen,
              onChanged: (value) => setState(() => _secureScreen = value),
              secondary: const Icon(Icons.screenshot_monitor_outlined),
              title: const Text('进入体检模块时阻止截图'),
              subtitle: const Text('离开本模块后自动恢复；投屏和最近任务缩略图也会被保护。'),
            ),
            SwitchListTile(
              value: _appLockEnabled,
              onChanged: (value) =>
                  setState(() => _appLockEnabled = value),
              secondary: const Icon(Icons.lock_person_outlined),
              title: const Text('使用系统设备锁保护本模块'),
              subtitle: const Text(
                '默认关闭；开启时先验证设备PIN、图案或密码。离开应用5秒后返回会重新验证。',
              ),
            ),
            const Divider(height: 32),
            const Text(
              '当地安全支持（可选）',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              '应用不会根据语言或时区猜测号码。请仅填写你已从当地官方来源核实的号码；字段使用 Android Keystore AES-GCM 加密。',
              style: TextStyle(color: Color(0xFF667085), height: 1.45),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _crisisController,
              keyboardType: TextInputType.phone,
              autofillHints: const <String>[AutofillHints.telephoneNumber],
              decoration: const InputDecoration(
                labelText: '当地危机支持号码',
                prefixIcon: Icon(Icons.support_agent),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emergencyController,
              keyboardType: TextInputType.phone,
              autofillHints: const <String>[AutofillHints.telephoneNumber],
              decoration: const InputDecoration(
                labelText: '当地紧急服务号码',
                prefixIcon: Icon(Icons.emergency_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存本地设置'),
            ),
          ],
        ),
      );
}

class MentalHealthCourseEvidencePage extends StatefulWidget {
  final MentalHealthCheckupRepository repository;
  final String initialQuery;
  final int? initialLecture;

  const MentalHealthCourseEvidencePage({
    super.key,
    required this.repository,
    this.initialQuery = '',
    this.initialLecture,
  });

  @override
  State<MentalHealthCourseEvidencePage> createState() =>
      _MentalHealthCourseEvidencePageState();
}

class _MentalHealthCourseEvidencePageState
    extends State<MentalHealthCourseEvidencePage> {
  late final TextEditingController _queryController;
  int? _lecture;
  bool _loading = false;
  bool _searched = false;
  List<CheckupCourseEvidence> _results = const <CheckupCourseEvidence>[];

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    _lecture = widget.initialLecture;
    if (widget.initialQuery.isNotEmpty || widget.initialLecture != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _searched = true;
    });
    final results = await widget.repository.searchCourseEvidence(
      _queryController.text,
      lecture: _lecture,
    );
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('课程原文定位')),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _queryController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      labelText: '指标ID、位置ID、关键词或中文原文',
                      hintText:
                          '例如 L04-C1 / L04-P034 / transformation / 情绪',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: '检索',
                        onPressed: _loading ? null : _search,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: _lecture,
                    decoration: const InputDecoration(
                      labelText: '讲次筛选',
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<int?>>[
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('全部 23 讲'),
                      ),
                      for (var value = 1; value <= 23; value++)
                        DropdownMenuItem<int?>(
                          value: value,
                          child: Text('Lecture $value'),
                        ),
                    ],
                    onChanged: (value) => setState(() => _lecture = value),
                  ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 3),
            Expanded(
              child: !_searched
                  ? const _EmptyTab(
                      icon: Icons.manage_search_outlined,
                      title: '离线核对课程证据',
                      text: '2253个定位单元已随App导入本地数据库；'
                          '英文走FTS，中文与位置ID走本地回退检索。',
                      action: '',
                      onPressed: null,
                    )
                  : _results.isEmpty
                      ? const Center(child: Text('没有找到匹配的课程定位。'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final item = _results[index];
                            return Card(
                              elevation: 0,
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  child: Text('${item.lecture}'),
                                ),
                                title: Text(
                                  item.locationId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Text(
                                  '${item.section} · 固定页 ${item.page} · '
                                  '${item.language}',
                                ),
                                childrenPadding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                children: <Widget>[
                                  SelectableText(
                                    item.text,
                                    style: const TextStyle(height: 1.55),
                                  ),
                                  const SizedBox(height: 12),
                                  _LabeledText(
                                    label: '位置方法',
                                    text: item.pageMethod,
                                  ),
                                  _LabeledText(
                                    label: '源文件',
                                    text: item.sourceFile,
                                  ),
                                  _LabeledText(
                                    label: '源SHA-256',
                                    text: item.sourceSha256,
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                          ClipboardData(
                                            text:
                                                '${item.locationId}\n${item.text}',
                                          ),
                                        );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('位置与原文已复制。'),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.copy_outlined),
                                      label: const Text('复制定位'),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      );
}

class _BackupPasswordDialog extends StatefulWidget {
  final bool confirmPassword;

  const _BackupPasswordDialog({required this.confirmPassword});

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _password.text;
    if (value.length < 10) {
      setState(() => _error = '独立备份密码至少10个字符。');
      return;
    }
    if (widget.confirmPassword && value != _confirm.text) {
      setState(() => _error = '两次输入不一致。');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        icon: const Icon(Icons.password_outlined),
        title: Text(widget.confirmPassword ? '设置独立备份密码' : '输入备份密码'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.confirmPassword
                    ? '任何同时持有文件和密码的人都能读取内容。应用不会保存或找回这个密码。'
                    : '密码错误或文件被篡改时，认证会失败且不会导入任何记录。',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                obscureText: _obscure,
                autofocus: true,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: '密码（至少10个字符）',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              if (widget.confirmPassword) ...<Widget>[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirm,
                  obscureText: _obscure,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: '再次输入',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(onPressed: _submit, child: const Text('继续')),
        ],
      );
}

class MentalHealthCheckupPromptPage extends StatefulWidget {
  const MentalHealthCheckupPromptPage({super.key});

  @override
  State<MentalHealthCheckupPromptPage> createState() =>
      _MentalHealthCheckupPromptPageState();
}

class _MentalHealthCheckupPromptPageState
    extends State<MentalHealthCheckupPromptPage> {
  final MentalHealthCheckupPromptConfig _config =
      MentalHealthCheckupPromptConfig();
  final TextEditingController _controller = TextEditingController();
  String _promptId = MentalHealthCheckupPromptConfig.globalId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _controller.text = await _config.getPrompt(_promptId);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _config.savePrompt(_promptId, _controller.text);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Prompt 已保存在本机。')));
  }

  Future<void> _reset() async {
    await _config.resetPrompt(_promptId);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('心理健康体检 · AI Prompt')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: _promptId,
                  decoration: const InputDecoration(
                    labelText: 'Prompt 层',
                    border: OutlineInputBorder(),
                  ),
                  items: MentalHealthCheckupPromptConfig.labels.entries
                      .map((entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ))
                      .toList(growable: false),
                  onChanged: (value) async {
                    if (value == null) return;
                    setState(() => _promptId = value);
                    await _load();
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : TextField(
                          controller: _controller,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            alignLabelWithHint: true,
                            labelText: '模板内容',
                            border: OutlineInputBorder(),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _loading || _saving ? null : _reset,
                      icon: const Icon(Icons.restore),
                      label: const Text('恢复默认'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading || _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _DashboardHero extends StatelessWidget {
  final CheckupReport? latest;
  final CheckupPrescriptionPlan? activePlan;
  final VoidCallback onPrimary;

  const _DashboardHero({
    required this.latest,
    required this.activePlan,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final hasReport = latest != null;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF34449A), Color(0xFF725A9C)],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x283B458E), blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _HeroChip(icon: Icons.offline_bolt, text: '离线核心'),
              _HeroChip(icon: Icons.person_off_outlined, text: '无登录'),
              _HeroChip(icon: Icons.shield_outlined, text: '安全优先'),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            hasReport ? '你的课程型健康基线' : '建立第一份课程型健康基线',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasReport
                ? '综合 ${latest!.overallScore.toStringAsFixed(0)} · 覆盖 ${latest!.coverage.toStringAsFixed(0)}% · ${_safetyText(latest!.safetyStatus)}'
                : '先看安全和现实功能，再理解八域差异；最后只选择一个最值得验证的课程行动。',
            style: const TextStyle(color: Color(0xFFE7E9FF), height: 1.5),
          ),
          if (activePlan != null) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              '进行中：${activePlan!.prescription.theme} · ${activePlan!.doseStage}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF3D4AA0),
            ),
            onPressed: onPrimary,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(hasReport ? '重新完成 B20' : '开始 B20 快速基准'),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      );
}

class _DraftCard extends StatelessWidget {
  final Map<String, dynamic> draft;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  const _DraftCard({
    required this.draft,
    required this.onResume,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final count = (draft['answers'] as List?)?.length ?? 0;
    return Card(
      elevation: 0,
      color: const Color(0xFFFFF8E7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            const CircleAvatar(
              backgroundColor: Color(0xFFFFE2A8),
              child: Icon(Icons.pending_actions, color: Color(0xFF9A6700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '继续 ${(draft['mode_name'] ?? '未完成体检')}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text('已保存 $count 个结构化答案'),
                ],
              ),
            ),
            TextButton(onPressed: onDiscard, child: const Text('放弃')),
            FilledButton(onPressed: onResume, child: const Text('继续')),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final CheckupModeSpec mode;
  final VoidCallback onTap;
  const _ModeCard({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _ModeIcon(modeId: mode.id, size: 48),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              mode.name,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            mode.duration,
                            style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        mode.useCase,
                        style: const TextStyle(height: 1.4, color: Color(0xFF475467)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          _MiniPill('${mode.baseQuestionCount}-${mode.maxQuestionCount}题'),
                          _MiniPill(mode.coverageLevel),
                          _MiniPill('行动 ${mode.actionCount}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );
}

class _ModeIcon extends StatelessWidget {
  final String modeId;
  final double size;
  const _ModeIcon({required this.modeId, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = _modeColor(modeId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(_modeIcon(modeId), color: color, size: size * 0.5),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String text;
  const _MiniPill(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F8),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF596273))),
      );
}

class _SafetyQuickEntry extends StatelessWidget {
  final VoidCallback onTap;
  const _SafetyQuickEntry({required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: const Color(0xFFFFF3F1),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFFFDAD5),
            child: Icon(Icons.shield_outlined, color: Color(0xFFB42318)),
          ),
          title: const Text('我现在只想确认是否需要优先求助', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('20-60秒安全快检 · 不生成普通课程行动'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

class _ClosedLoopTimeline extends StatelessWidget {
  const _ClosedLoopTimeline();

  @override
  Widget build(BuildContext context) {
    const steps = <_TimelineStep>[
      _TimelineStep(Icons.shield_outlined, '1 安全分流', '先判断是否应停止普通流程'),
      _TimelineStep(Icons.fact_check_outlined, '2 课程评估', '八域、功能、知行差与覆盖'),
      _TimelineStep(Icons.account_tree_outlined, '3 机制候选', '支持、冲突与替代解释'),
      _TimelineStep(Icons.route_outlined, '4 一项行动', '从微量开始，明确停止规则'),
      _TimelineStep(Icons.restart_alt, '5 七天复验', '继续、减量、暂停、换方或维持'),
    ];
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            for (var index = 0; index < steps.length; index++) ...<Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: const Color(0xFFE9ECFF),
                    child: Icon(steps[index].icon, size: 19, color: const Color(0xFF4554C5)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(steps[index].title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(steps[index].description, style: const TextStyle(color: Color(0xFF667085))),
                      ],
                    ),
                  ),
                ],
              ),
              if (index < steps.length - 1)
                Container(
                  margin: const EdgeInsets.only(left: 18, top: 5, bottom: 5),
                  alignment: Alignment.centerLeft,
                  height: 18,
                  child: const VerticalDivider(width: 1, thickness: 1),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineStep {
  final IconData icon;
  final String title;
  final String description;

  const _TimelineStep(this.icon, this.title, this.description);
}

class _LocalPrivacyCard extends StatelessWidget {
  const _LocalPrivacyCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF7F3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.phone_android, color: Color(0xFF39715D)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '默认不上传：结构化回答、报告、行动和复验保存在本机。只有你在报告页单次同意后，AI解释层才发送最小化结构化结果。',
                style: TextStyle(color: Color(0xFF315C4E), height: 1.5),
              ),
            ),
          ],
        ),
      );
}

class _ReportHero extends StatelessWidget {
  final CheckupReport report;
  const _ReportHero({required this.report});

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(report.overallScore);
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 96,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  CircularProgressIndicator(
                    value: (report.overallScore / 100).clamp(0, 1).toDouble(),
                    strokeWidth: 10,
                    backgroundColor: color.withValues(alpha: 0.12),
                    color: color,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        report.overallScore.toStringAsFixed(0),
                        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: color),
                      ),
                      const Text('已覆盖综合', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _safetyText(report.safetyStatus),
                    style: TextStyle(
                      color: _safetyColor(report.safetyStatus),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '规则 ${report.ruleVersion} · 种子 ${report.seedVersion} · '
                    '${_date(report.createdAtMs)}',
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '分数只汇总已覆盖课程领域；安全与功能不被“幸福总分”抵消。',
                    style: TextStyle(color: Color(0xFF667085), height: 1.35, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final CheckupReport report;
  const _MetricGrid({required this.report});

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Expanded(child: _MetricCard(label: '覆盖度', value: '${report.coverage.toStringAsFixed(0)}%', icon: Icons.grid_view_outlined)),
          const SizedBox(width: 8),
          Expanded(child: _MetricCard(label: '数据质量', value: '${report.dataQuality.toStringAsFixed(0)}%', icon: Icons.verified_outlined)),
          const SizedBox(width: 8),
          Expanded(child: _MetricCard(label: '功能影响', value: '${report.functionImpact}/4', icon: Icons.work_outline)),
        ],
      );
}

class _KabCard extends StatelessWidget {
  final CheckupReport report;

  const _KabCard({required this.report});

  @override
  Widget build(BuildContext context) {
    String value(double? score) =>
        score == null ? '—' : score.toStringAsFixed(0);
    return Card(
      elevation: 0,
      color: const Color(0xFFF2F4FF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.hub_outlined, color: Color(0xFF4554C5)),
                SizedBox(width: 8),
                Text(
                  '知识—态度—行为（K/A/B）',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricCard(
                    label: 'K 理论',
                    value: value(report.knowledgeScore),
                    icon: Icons.school_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: 'A 态度',
                    value: value(report.attitudeScore),
                    icon: Icons.psychology_alt_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: 'B 行为',
                    value: value(report.behaviorScore),
                    icon: Icons.directions_run_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              report.kabIntegratedScore == null
                  ? '本轮未同时覆盖 K/A/B，暂不生成加权分。'
                  : '加权分 M = K×25% + A×30% + B×45%：'
                      '${report.kabIntegratedScore!.toStringAsFixed(1)}；'
                      'A-B一致性 ${value(report.attitudeBehaviorConsistency)}，'
                      'K-B一致性 ${value(report.knowledgeBehaviorConsistency)}。',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475467),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _MetricCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 19, color: const Color(0xFF5664D2)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF667085))),
          ],
        ),
      );
}

class _DomainRadarCard extends StatelessWidget {
  final List<CheckupDomainResult> domains;
  const _DomainRadarCard({required this.domains});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: SizedBox(
            height: 285,
            child: CustomPaint(
              painter: _RadarPainter(domains),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
}

class _RadarPainter extends CustomPainter {
  final List<CheckupDomainResult> domains;
  _RadarPainter(this.domains);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.32;
    final grid = Paint()
      ..color = const Color(0xFFD7DCE8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final axis = Paint()
      ..color = const Color(0xFFE7EAF1)
      ..strokeWidth = 1;
    const count = 8;
    for (var ring = 1; ring <= 4; ring++) {
      final path = Path();
      for (var index = 0; index < count; index++) {
        final point = _point(center, radius * ring / 4, index, count);
        if (index == 0) path.moveTo(point.dx, point.dy); else path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, grid);
    }
    for (var index = 0; index < count; index++) {
      canvas.drawLine(center, _point(center, radius, index, count), axis);
    }
    final scorePath = Path();
    for (var index = 0; index < count; index++) {
      final domain = index < domains.length ? domains[index] : null;
      final ratio = domain == null || domain.answered == 0 ? 0 : domain.score / 100;
      final point = _point(center, radius * ratio.clamp(0, 1), index, count);
      if (index == 0) scorePath.moveTo(point.dx, point.dy); else scorePath.lineTo(point.dx, point.dy);
    }
    scorePath.close();
    canvas.drawPath(
      scorePath,
      Paint()..color = const Color(0x555664D2)..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      scorePath,
      Paint()..color = const Color(0xFF5664D2)..style = PaintingStyle.stroke..strokeWidth = 2.2,
    );
    for (var index = 0; index < count; index++) {
      final point = _point(center, radius + 27, index, count);
      final domain = index < domains.length ? domains[index] : null;
      final label = domain == null
          ? 'D${index + 1}'
          : '${domain.id}\n${domain.answered == 0 ? '未覆盖' : domain.score.toStringAsFixed(0)}';
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: domain?.answered == 0 ? const Color(0xFF98A2B3) : const Color(0xFF344054),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 52);
      painter.paint(canvas, point - Offset(painter.width / 2, painter.height / 2));
    }
  }

  Offset _point(Offset center, double radius, int index, int count) {
    final angle = -math.pi / 2 + index * 2 * math.pi / count;
    return center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => oldDelegate.domains != domains;
}

class _DomainScoreTile extends StatelessWidget {
  final CheckupDomainResult domain;
  const _DomainScoreTile({required this.domain});

  @override
  Widget build(BuildContext context) {
    final covered = domain.answered > 0;
    final color = covered ? _scoreColor(domain.score) : const Color(0xFF98A2B3);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 35,
                  height: 35,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(domain.id, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(domain.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                Text(covered ? domain.score.toStringAsFixed(0) : '—', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
            const SizedBox(height: 9),
            LinearProgressIndicator(
              value: covered ? domain.score / 100 : 0,
              minHeight: 7,
              borderRadius: BorderRadius.circular(9),
              backgroundColor: const Color(0xFFEEF0F5),
              color: color,
            ),
            const SizedBox(height: 6),
            Text(
              covered ? '${domain.level} · 已回答 ${domain.answered}/${domain.expected}' : '本轮未覆盖，不解释为异常',
              style: const TextStyle(fontSize: 11, color: Color(0xFF667085)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosisCard extends StatelessWidget {
  final CheckupDiagnosisResult diagnosis;
  const _DiagnosisCard({required this.diagnosis});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(diagnosis.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${diagnosis.candidateOnly ? '候选假设' : '当前较支持'} · 置信度 ${diagnosis.confidence.toStringAsFixed(0)} (${diagnosis.confidenceLevel})'),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFE9ECFF),
            child: Text(diagnosis.patternId, style: const TextStyle(color: Color(0xFF4554C5), fontSize: 11, fontWeight: FontWeight.w900)),
          ),
          children: <Widget>[
            _LabeledText(label: '机制假设', text: diagnosis.mechanism),
            _LabeledList(label: '支持证据', items: diagnosis.supportingEvidence),
            _LabeledList(label: '冲突/限制', items: diagnosis.conflictingEvidence),
            _LabeledList(label: '替代解释', items: diagnosis.alternativeHypotheses),
            const SizedBox(height: 6),
            Text(diagnosis.reviewStatus, style: const TextStyle(fontSize: 11, color: Color(0xFFB54708))),
          ],
        ),
      );
}

class _RecommendationCard extends StatelessWidget {
  final CheckupPrescriptionRecommendation recommendation;
  final bool active;
  final VoidCallback onStart;
  const _RecommendationCard({required this.recommendation, required this.active, required this.onStart});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: const Color(0xFFF2F4FF),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.route, color: Color(0xFF4554C5)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(recommendation.theme, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                  _MiniPill(recommendation.prescriptionId),
                ],
              ),
              const SizedBox(height: 12),
              _LabeledText(label: '从微量开始', text: recommendation.startingAction),
              _LabeledText(label: '剂量', text: recommendation.dose),
              _LabeledText(label: '首次复验', text: recommendation.trialPeriod),
              if (recommendation.contentCandidateId != null)
                _LabeledText(
                  label: '正式任务版本',
                  text: '${recommendation.contentCandidateId} · '
                      'v${recommendation.contentVersion ?? 1}',
                ),
              _LabeledText(label: '课程证据', text: 'Lecture ${recommendation.lecture} · ${recommendation.evidenceLocation} · ${recommendation.sourceLevel}'),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: active ? null : onStart,
                  icon: Icon(active ? Icons.check : Icons.play_arrow),
                  label: Text(active ? '正在执行' : '启动这1项课程行动'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _AiExplanationCard extends StatelessWidget {
  final bool loading;
  final String narrative;
  final bool usedRemote;
  final VoidCallback onGenerate;
  const _AiExplanationCard({required this.loading, required this.narrative, required this.usedRemote, required this.onGenerate});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(Icons.auto_awesome, color: Color(0xFF7A4E9D)),
                  SizedBox(width: 8),
                  Expanded(child: Text('AI课程解释（可选）', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                ],
              ),
              const SizedBox(height: 8),
              const Text('离线规则先完成。AI只解释结构化结果，不能更改安全状态、分数、证据等级或课程行动上限。', style: TextStyle(color: Color(0xFF667085), height: 1.45)),
              if (narrative.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF7F3FA), borderRadius: BorderRadius.circular(14)),
                  child: SelectableText(narrative, style: const TextStyle(height: 1.55)),
                ),
                const SizedBox(height: 6),
                Text(usedRemote ? '生成来源：你配置的AI提供方（本次已同意）' : '生成来源：本地模板回退', style: const TextStyle(fontSize: 11, color: Color(0xFF667085))),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: loading ? null : onGenerate,
                icon: loading
                    ? const SizedBox.square(dimension: 17, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(loading ? '正在生成…' : narrative.isEmpty ? '单次同意并深入解释' : '重新生成'),
              ),
            ],
          ),
        ),
      );
}

class _EvidenceAndBoundaryCard extends StatelessWidget {
  final CheckupReport report;
  final VoidCallback onOpenEvidence;
  const _EvidenceAndBoundaryCard({
    required this.report,
    required this.onOpenEvidence,
  });

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        child: ExpansionTile(
          leading: const Icon(Icons.menu_book_outlined),
          title: const Text('课程证据与来源边界', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${report.courseEvidence.length} 个课程定位 · C1/C2/D1/D2分开显示'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: <Widget>[
            _LabeledList(label: '本轮课程位置', items: report.courseEvidence),
            _LabeledList(label: '来源边界', items: report.sourceBoundaries),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenEvidence,
                icon: const Icon(Icons.manage_search_outlined),
                label: const Text('跳转到课程原文定位检索'),
              ),
            ),
          ],
        ),
      );
}

class _SafetyRouteCard extends StatelessWidget {
  final CheckupSafetyStatus status;
  final String emergencyNumber;
  final String crisisNumber;
  final VoidCallback onConfigure;
  const _SafetyRouteCard({
    required this.status,
    required this.emergencyNumber,
    required this.crisisNumber,
    required this.onConfigure,
  });

  Future<void> _dial(String number) async {
    final compact = number.replaceAll(RegExp(r'[^0-9+*#]'), '');
    if (compact.isEmpty) return;
    try {
      await launchUrl(Uri(scheme: 'tel', path: compact));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final alert = status == CheckupSafetyStatus.alert;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: alert ? const Color(0xFFFFEDEA) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: alert ? const Color(0xFFF2AAA2) : const Color(0xFFF6C77A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(alert ? Icons.health_and_safety : Icons.shield_outlined, color: alert ? const Color(0xFFC62828) : const Color(0xFFB54708)),
              const SizedBox(width: 8),
              Expanded(child: Text(alert ? '普通课程流程已暂停' : '安全状态需先确认', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alert
                ? '请优先联系可信任的人和当地专业/紧急支持，不要独自承担，也不要用积极练习覆盖危险。'
                : '请先完成更详细的安全确认，必要时联系当地专业支持。本轮不会生成普通课程行动处方。',
            style: const TextStyle(height: 1.55),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (crisisNumber.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => _dial(crisisNumber),
                  icon: const Icon(Icons.support_agent),
                  label: const Text('联系已设置的危机支持'),
                ),
              if (emergencyNumber.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _dial(emergencyNumber),
                  icon: const Icon(Icons.emergency_outlined),
                  label: const Text('联系已设置的紧急服务'),
                ),
              if (crisisNumber.isEmpty && emergencyNumber.isEmpty)
                OutlinedButton.icon(
                  onPressed: onConfigure,
                  icon: const Icon(Icons.add_call),
                  label: const Text('设置当地支持号码'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '应用不猜测你的国家或号码；请只保存你已核实的当地资源。'
            '号码使用 Android Keystore 字段加密。',
            style: TextStyle(fontSize: 11, color: Color(0xFF7A271A)),
          ),
        ],
      ),
    );
  }
}

class _PlanHero extends StatelessWidget {
  final CheckupPrescriptionPlan plan;
  final int daysUntilRetest;
  const _PlanHero({required this.plan, required this.daysUntilRetest});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(colors: <Color>[Color(0xFF315C4E), Color(0xFF4E8170)]),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.route, color: Colors.white),
                const SizedBox(width: 8),
                Text(plan.status == CheckupPlanStatus.paused ? '已暂停' : '当前课程行动', style: const TextStyle(color: Colors.white70)),
                const Spacer(),
                _HeroChip(icon: Icons.science_outlined, text: plan.doseStage),
              ],
            ),
            const SizedBox(height: 14),
            Text(plan.prescription.theme, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(plan.prescription.target, style: const TextStyle(color: Color(0xFFDDF2EA), height: 1.45)),
            const SizedBox(height: 16),
            Text(daysUntilRetest <= 0 ? '已到复验时间' : '$daysUntilRetest 天后复验', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _ActionDoseCard extends StatelessWidget {
  final CheckupPrescriptionPlan plan;
  const _ActionDoseCard({required this.plan});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('今天只做这一件', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text(plan.prescription.startingAction, style: const TextStyle(fontSize: 16, height: 1.55)),
              const Divider(height: 28),
              _LabeledText(label: '当前剂量', text: plan.prescription.dose),
              _LabeledText(
                label: '稳定后的进阶与防复发',
                text: plan.prescription.deepeningAction,
              ),
              _LabeledText(label: '课程位置', text: 'Lecture ${plan.prescription.lecture} · ${plan.prescription.evidenceLocation}'),
            ],
          ),
        ),
      );
}

class _PlanMetrics extends StatelessWidget {
  final CheckupPrescriptionPlan plan;
  const _PlanMetrics({required this.plan});

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  label: '执行率',
                  value: '${plan.completionRate.toStringAsFixed(0)}%',
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  label: '平均收益',
                  value: '${plan.averageBenefit.toStringAsFixed(1)}/10',
                  icon: Icons.trending_up,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  label: '自主执行',
                  value: '${plan.averageAutonomy.toStringAsFixed(0)}%',
                  icon: Icons.self_improvement_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  label: plan.hasRelapsePlan ? '已有复发预案' : '复发预案待补',
                  value:
                      '${plan.averageOveruseRisk.toStringAsFixed(0)}% 过度化',
                  icon: Icons.shield_outlined,
                ),
              ),
            ],
          ),
        ],
      );
}

class _ExecutionLogTile extends StatelessWidget {
  final CheckupExecutionLog log;
  const _ExecutionLogTile({required this.log});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: log.completed ? const Color(0xFFE1F2EA) : const Color(0xFFFEECE9),
            child: Icon(log.completed ? Icons.check : Icons.close, color: log.completed ? const Color(0xFF39715D) : const Color(0xFFB42318)),
          ),
          title: Text(log.completed ? '完成了可接受版本' : '本次未完成'),
          subtitle: Text(
            '${_date(log.createdAtMs)} · 收益 ${log.benefit.toStringAsFixed(1)}/10 '
            '· 功能 ${log.functionChange >= 0 ? '+' : ''}${log.functionChange.toStringAsFixed(0)} '
            '· 自主 ${log.autonomy.toStringAsFixed(0)}/10 '
            '· ${log.relapsePlanReady ? '已有复发预案' : '预案待补'} '
            '· 过度化 ${log.overuseRisk.toStringAsFixed(0)}%',
          ),
        ),
      );
}

class _StopRuleCard extends StatelessWidget {
  final String text;
  const _StopRuleCard({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFFFF3F1), borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.pause_circle_outline, color: Color(0xFFB42318)),
            const SizedBox(width: 10),
            Expanded(child: Text('减量/暂停规则\n$text', style: const TextStyle(height: 1.5, color: Color(0xFF7A271A)))),
          ],
        ),
      );
}

class _RetestHero extends StatelessWidget {
  final CheckupPrescriptionPlan? plan;
  final VoidCallback? onRetest;
  final VoidCallback? onReschedule;
  const _RetestHero({
    required this.plan,
    required this.onRetest,
    required this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    final due = plan == null ? null : DateTime.fromMillisecondsSinceEpoch(plan!.nextRetestAtMs);
    final isDue = due != null && !due.isAfter(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDue ? const Color(0xFFFFF4E5) : Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(isDue ? Icons.notification_important_outlined : Icons.restart_alt, size: 34, color: isDue ? const Color(0xFFB54708) : const Color(0xFF5664D2)),
          const SizedBox(height: 12),
          Text(plan == null ? '复验从课程行动之后开始' : isDue ? '已经到复验时间' : '下一次复验：${_date(plan!.nextRetestAtMs)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text(plan == null ? '先建立基线并启动一项课程行动；系统不会把重复做题误当成恢复。' : '复验重新检查目标领域、现实功能、执行率、过度化和自主性。', style: const TextStyle(color: Color(0xFF667085), height: 1.45)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: onRetest,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('完成 B20 课程复验'),
              ),
              if (plan != null)
                OutlinedButton.icon(
                  onPressed: onReschedule,
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('调整日期'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final List<CheckupSession> sessions;
  const _TrendCard({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final values = sessions.reversed.map((e) => e.report.overallScore).toList(growable: false);
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(height: 150, child: CustomPaint(painter: _TrendPainter(values), child: const SizedBox.expand())),
            const SizedBox(height: 8),
            Text(values.length < 2 ? '至少完成两次评估后显示变化轨迹。' : '共 ${values.length} 次记录 · 最近 ${values.last.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
          ],
        ),
      ),
    );
  }
}

class _TrendInsightsCard extends StatelessWidget {
  final List<CheckupTrendInsight> insights;

  const _TrendInsightsCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '纵向规则提示',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (final insight in insights)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      insight.severity == CheckupTrendSeverity.elevated
                          ? Icons.warning_amber_rounded
                          : insight.severity == CheckupTrendSeverity.attention
                              ? Icons.trending_down
                              : Icons.info_outline,
                      color:
                          insight.severity == CheckupTrendSeverity.elevated
                              ? const Color(0xFFC62828)
                              : insight.severity ==
                                      CheckupTrendSeverity.attention
                                  ? const Color(0xFFB54708)
                                  : const Color(0xFF5664D2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            insight.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            insight.message,
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> values;
  _TrendPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFFE7EAF0)..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.isEmpty) return;
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1 ? size.width / 2 : size.width * index / (values.length - 1);
      final y = size.height * (1 - values[index].clamp(0, 100) / 100);
      if (index == 0) path.moveTo(x, y); else path.lineTo(x, y);
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = const Color(0xFF5664D2));
    }
    canvas.drawPath(path, Paint()..color = const Color(0xFF5664D2)..strokeWidth = 2.5..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => oldDelegate.values != values;
}

class _AdjustmentRulesCard extends StatelessWidget {
  final List<CheckupReferenceRule> rules;

  const _AdjustmentRulesCard({required this.rules});

  @override
  Widget build(BuildContext context) {
    final rows = rules.isEmpty
        ? const <_RuleRow>[
            _RuleRow('安全不清楚', '暂停普通课程任务，转安全/人工复核'),
            _RuleRow('过度化 ≥50%', '减量、暂停或换制衡处方'),
            _RuleRow('改善 ≥10且功能改善', '维持剂量，不新增处方'),
            _RuleRow('执行 <50%', '先缩小任务、改时机和环境'),
            _RuleRow('执行 ≥70%但无改善', '重新诊断或换方'),
            _RuleRow('综合 ≥75且稳定', '进入低频维持与防复发'),
          ]
        : rules
            .map(
              (rule) => _RuleRow(
                rule.value('条件'),
                '${rule.value('处方动作')}；${rule.value('复验安排')}',
              ),
            )
            .toList(growable: false);
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            for (final row in rows) Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(width: 118, child: Text(row.condition, style: const TextStyle(fontWeight: FontWeight.w800))),
                  const Icon(Icons.arrow_forward, size: 17, color: Color(0xFF98A2B3)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(row.action, style: const TextStyle(color: Color(0xFF475467)))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleRow {
  final String condition;
  final String action;

  const _RuleRow(this.condition, this.action);
}

class _RetestRecordCard extends StatelessWidget {
  final CheckupRetestRecord record;
  final VoidCallback onExplain;
  const _RetestRecordCard({
    required this.record,
    required this.onExplain,
  });

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.fact_check_outlined, color: Color(0xFF5664D2)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(record.decision, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                  Text(_date(record.createdAtMs), style: const TextStyle(fontSize: 11, color: Color(0xFF667085))),
                ],
              ),
              const SizedBox(height: 8),
              Text(record.reason, style: const TextStyle(height: 1.45)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  _MiniPill('分数 ${record.scoreChange >= 0 ? '+' : ''}${record.scoreChange.toStringAsFixed(1)}'),
                  _MiniPill('功能 ${record.functionChange >= 0 ? '+' : ''}${record.functionChange.toStringAsFixed(1)}'),
                  _MiniPill('执行 ${record.executionRate.toStringAsFixed(0)}%'),
                  _MiniPill('自主 ${record.autonomyScore.toStringAsFixed(0)}%'),
                  _MiniPill(record.relapsePlanReady ? '复发预案已备' : '复发预案待补'),
                  _MiniPill('过度化 ${record.overuseRisk.toStringAsFixed(0)}%'),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onExplain,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('AI解释本次复验'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ArchiveSummary extends StatelessWidget {
  final MentalHealthCheckupState state;
  const _ArchiveSummary({required this.state});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: const Color(0xFF283252), borderRadius: BorderRadius.circular(22)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _ArchiveNumber(value: '${state.sessions.length}', label: '体检'),
            _ArchiveNumber(value: '${state.plans.length}', label: '课程行动'),
            _ArchiveNumber(value: '${state.retests.length}', label: '复验'),
          ],
        ),
      );
}

class _ArchiveNumber extends StatelessWidget {
  final String value;
  final String label;
  const _ArchiveNumber({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Color(0xFFC8CDE0))),
        ],
      );
}

class _SessionHistoryTile extends StatelessWidget {
  final CheckupSession session;
  final VoidCallback onTap;
  const _SessionHistoryTile({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _scoreColor(session.report.overallScore)
                .withValues(alpha: 0.12),
            child: Text(session.report.overallScore.toStringAsFixed(0), style: TextStyle(color: _scoreColor(session.report.overallScore), fontWeight: FontWeight.w900)),
          ),
          title: Text(session.modeName, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${_date(session.completedAtMs)} · 覆盖 ${session.report.coverage.toStringAsFixed(0)}% · ${_safetyText(session.report.safetyStatus)}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingsTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        child: ListTile(
          leading: Icon(icon, color: iconColor ?? const Color(0xFF5664D2)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

class _ExecutionCheckInSheet extends StatefulWidget {
  const _ExecutionCheckInSheet();

  @override
  State<_ExecutionCheckInSheet> createState() => _ExecutionCheckInSheetState();
}

class _ExecutionCheckInSheetState extends State<_ExecutionCheckInSheet> {
  bool _completed = true;
  double _effort = 5;
  double _benefit = 5;
  double _function = 0;
  double _overuse = 0;
  double _autonomy = 5;
  bool _relapsePlanReady = false;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('记录本次课程行动', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('只记录结构化变化，不需要证明自己，也不保存私密反思原文。', style: TextStyle(color: Color(0xFF667085))),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment(value: true, icon: Icon(Icons.check), label: Text('完成可接受版本')),
                  ButtonSegment(value: false, icon: Icon(Icons.close), label: Text('本次未完成')),
                ],
                selected: <bool>{_completed},
                onSelectionChanged: (value) => setState(() => _completed = value.first),
              ),
              const SizedBox(height: 16),
              _SliderField(label: '主观用力', value: _effort, min: 0, max: 10, divisions: 10, onChanged: (v) => setState(() => _effort = v)),
              _SliderField(label: '即时收益', value: _benefit, min: 0, max: 10, divisions: 10, onChanged: (v) => setState(() => _benefit = v)),
              _SliderField(label: '现实功能变化', value: _function, min: -2, max: 2, divisions: 4, onChanged: (v) => setState(() => _function = v)),
              _SliderField(label: '过度化/僵化风险', value: _overuse, min: 0, max: 10, divisions: 10, onChanged: (v) => setState(() => _overuse = v)),
              _SliderField(
                label: '自主执行（较少提醒也能完成）',
                value: _autonomy,
                min: 0,
                max: 10,
                divisions: 10,
                onChanged: (value) => setState(() => _autonomy = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _relapsePlanReady,
                onChanged: (value) =>
                    setState(() => _relapsePlanReady = value),
                secondary: const Icon(Icons.shield_outlined),
                title: const Text('已形成可执行的复发预案'),
                subtitle: const Text(
                  '只保存“已准备/未准备”；不保存私密预案原文。',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(
                    CheckupExecutionLog(
                      createdAtMs: DateTime.now().millisecondsSinceEpoch,
                      completed: _completed,
                      effort: _effort,
                      benefit: _benefit,
                      functionChange: _function,
                      overuseRisk: _overuse * 10,
                      autonomy: _autonomy,
                      relapsePlanReady: _relapsePlanReady,
                    ),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存本次记录'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SliderField extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  const _SliderField({required this.label, required this.value, required this.min, required this.max, required this.divisions, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(value.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          Slider(value: value, min: min, max: max, divisions: divisions, label: value.toStringAsFixed(0), onChanged: onChanged),
        ],
      );
}

class _OnboardingFeature extends StatelessWidget {
  final String number;
  final String title;
  final String text;
  final Color color;
  const _OnboardingFeature({required this.number, required this.title, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(number, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(text, style: const TextStyle(color: Color(0xFF667085), height: 1.45)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _InfoStrip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  const _InfoStrip({required this.icon, required this.color, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(text, style: const TextStyle(height: 1.4, color: Color(0xFF475467))),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF1D2433))),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: Color(0xFF667085), height: 1.4)),
        ],
      );
}

class _BulletCard extends StatelessWidget {
  final List<String> items;
  const _BulletCard({required this.items});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.only(top: 7),
                        child: CircleAvatar(radius: 3, backgroundColor: Color(0xFF5664D2)),
                      ),
                      const SizedBox(width: 9),
                      Expanded(child: Text(item, style: const TextStyle(height: 1.5))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
}

class _SoftMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SoftMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: const Color(0xFF667085)),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF596273), height: 1.5))),
          ],
        ),
      );
}

class _LabeledText extends StatelessWidget {
  final String label;
  final String text;
  const _LabeledText({required this.label, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF5664D2))),
            const SizedBox(height: 3),
            Text(text, style: const TextStyle(height: 1.5)),
          ],
        ),
      );
}

class _LabeledList extends StatelessWidget {
  final String label;
  final List<String> items;
  const _LabeledList({required this.label, required this.items});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF5664D2))),
            const SizedBox(height: 4),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $item', style: const TextStyle(height: 1.45)),
              ),
          ],
        ),
      );
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String action;
  final VoidCallback? onPressed;
  const _EmptyTab({required this.icon, required this.title, required this.text, required this.action, required this.onPressed});

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(color: const Color(0xFFE9ECFF), borderRadius: BorderRadius.circular(28)),
                child: Icon(icon, size: 42, color: const Color(0xFF5664D2)),
              ),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF667085), height: 1.5)),
              if (action.isNotEmpty) ...<Widget>[
                const SizedBox(height: 18),
                FilledButton(onPressed: onPressed, child: Text(action)),
              ],
            ],
          ),
        ),
      );
}

Color _modeColor(String id) {
  const colors = <String, Color>{
    'safety': Color(0xFFB42318),
    'daily': Color(0xFF39715D),
    'five_minute': Color(0xFF2E6F9E),
    'b20': Color(0xFF4554C5),
    'standard': Color(0xFF6A4C93),
    'focused': Color(0xFFA15C38),
    'comprehensive': Color(0xFF283252),
  };
  return colors[id] ?? const Color(0xFF5664D2);
}

IconData _modeIcon(String id) {
  const icons = <String, IconData>{
    'safety': Icons.shield_outlined,
    'daily': Icons.monitor_heart_outlined,
    'five_minute': Icons.timer_outlined,
    'b20': Icons.fact_check_outlined,
    'standard': Icons.dashboard_customize_outlined,
    'focused': Icons.center_focus_strong,
    'comprehensive': Icons.hub_outlined,
  };
  return icons[id] ?? Icons.assignment_outlined;
}

Color _domainColor(String id) {
  const colors = <String, Color>{
    'D1': Color(0xFF8E5C7C),
    'D2': Color(0xFF4D7094),
    'D3': Color(0xFF5D60B5),
    'D4': Color(0xFF8A6A2E),
    'D5': Color(0xFF3F7A67),
    'D6': Color(0xFF397D8B),
    'D7': Color(0xFFA35D50),
    'D8': Color(0xFF76529B),
  };
  return colors[id] ?? const Color(0xFF5664D2);
}

Color _scoreColor(double score) {
  if (score >= 75) return const Color(0xFF39715D);
  if (score >= 60) return const Color(0xFFB37A17);
  if (score >= 40) return const Color(0xFFD0662B);
  return const Color(0xFFB42318);
}

Color _safetyColor(CheckupSafetyStatus status) {
  switch (status) {
    case CheckupSafetyStatus.clear:
      return const Color(0xFF39715D);
    case CheckupSafetyStatus.uncertain:
      return const Color(0xFFB54708);
    case CheckupSafetyStatus.alert:
      return const Color(0xFFC62828);
  }
}

String _safetyText(CheckupSafetyStatus status) {
  switch (status) {
    case CheckupSafetyStatus.clear:
      return '安全门 clear';
    case CheckupSafetyStatus.uncertain:
      return '安全状态待确认';
    case CheckupSafetyStatus.alert:
      return '安全分流已触发';
  }
}

String _date(int milliseconds) {
  if (milliseconds <= 0) return '—';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _shortInstallId(String value) {
  if (value.length <= 14) return value.isEmpty ? '待生成' : value;
  return '${value.substring(0, 10)}…${value.substring(value.length - 4)}';
}

String _firstLocationId(List<String> values) {
  final match = RegExp(r'L\d{2}-P\d{3}').firstMatch(values.join(' '));
  return match?.group(0) ?? '';
}
