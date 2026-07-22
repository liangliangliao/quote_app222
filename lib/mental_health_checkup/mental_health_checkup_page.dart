import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'mental_health_assessment_page.dart';
import 'mental_health_checkup_ai_service.dart';
import 'mental_health_checkup_catalog.dart';
import 'mental_health_checkup_engine.dart';
import 'mental_health_checkup_models.dart';
import 'mental_health_checkup_repository.dart';

class MentalHealthCheckupPage extends StatefulWidget {
  const MentalHealthCheckupPage({super.key});

  @override
  State<MentalHealthCheckupPage> createState() =>
      _MentalHealthCheckupPageState();
}

class _MentalHealthCheckupPageState extends State<MentalHealthCheckupPage> {
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final catalog = await MentalHealthCheckupCatalog.load();
      final state = await _repository.load();
      final draft = await _repository.loadDraft();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _state = state;
        _draft = draft;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _acceptOnboarding() async {
    if (!_understandsNonMedical || !_understandsSafety) return;
    final next = await _repository.acceptOnboarding(_state);
    if (mounted) setState(() => _state = next);
  }

  Future<void> _startAssessment(
    CheckupModeSpec mode, {
    String? focusDomainId,
    Map<String, dynamic>? draft,
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
    if (draft == null) {
      final accepted = await _showAssessmentPreflight(mode, domainId);
      if (accepted != true || !mounted) return;
    }
    final session = await Navigator.of(context).push<CheckupSession>(
      MaterialPageRoute(
        builder: (_) => MentalHealthAssessmentPage(
          catalog: catalog,
          mode: mode,
          repository: _repository,
          focusDomainId: domainId,
          draft: draft,
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
                    backgroundColor: _domainColor(entry.key).withOpacity(0.12),
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

  Future<bool?> _showAssessmentPreflight(
      CheckupModeSpec mode, String? domainId) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
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
                        Text('${mode.duration} · 最多 ${mode.maxQuestionCount} 题'),
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
              const SizedBox(height: 10),
              const _InfoStrip(
                icon: Icons.lock_outline,
                color: Color(0xFF4554C5),
                title: '不保存开放题原文',
                text: '当前版本只保存结构化选项；AI深入解读必须另行确认，且只发送结构化报告。',
              ),
              if (domainId != null) ...<Widget>[
                const SizedBox(height: 10),
                _InfoStrip(
                  icon: Icons.center_focus_strong,
                  color: _domainColor(domainId),
                  title: '本轮聚焦：${MentalHealthCheckupCatalog.domainNames[domainId]}',
                  text: MentalHealthCheckupCatalog.domainDescriptions[domainId] ?? '',
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                '作答原则',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '按最近14天的真实情况作答，不按“理想中的自己”作答；不确定就选择不确定。进度会自动保存在本机，可稍后继续。',
                style: TextStyle(height: 1.55, color: Color(0xFF475467)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('开始本地体检'),
                ),
              ),
            ],
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
    final next = await _repository.appendExecutionLog(_state, plan.id, log);
    if (mounted) setState(() => _state = next);
  }

  Future<void> _togglePlan(CheckupPrescriptionPlan plan) async {
    final nextPlan = plan.copyWith(
      status: plan.status == CheckupPlanStatus.paused
          ? CheckupPlanStatus.active
          : CheckupPlanStatus.paused,
    );
    final next = await _repository.upsertPlan(_state, nextPlan);
    if (mounted) setState(() => _state = next);
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
    );
    final updatedPlan = engine.applyRetestDecision(plan, retest);
    final next = await _repository.completeRetest(
      state: _state,
      session: session,
      retest: retest,
      updatedPlan: updatedPlan,
    );
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
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.cloud_upload_outlined),
        title: const Text('是否使用你配置的AI？'),
        content: const Text(
          '离线规则报告已经完成。继续后，应用只会把结构化分数、课程机制候选、证据等级和处方字段发送给你在全局设置中选择的AI提供方；不发送开放题原文。AI只能解释，不能改写安全状态或评分。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('保持离线'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('同意本次发送'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _aiLoading = true);
    final fallback = _localNarrative(report);
    final result = await _ai.explainReport(report, fallback: fallback);
    if (!mounted) return;
    setState(() {
      _aiLoading = false;
      _aiNarrative = result.text;
      _aiNarrativeUsedRemote = result.usedAi;
    });
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
    await _repository.clearAllModuleData();
    if (!mounted) return;
    setState(() {
      _state = const MentalHealthCheckupState();
      _draft = null;
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
          _SafetyRouteCard(status: report.safetyStatus),
          const SizedBox(height: 14),
        ],
        _ReportHero(report: report),
        const SizedBox(height: 14),
        _MetricGrid(report: report),
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
        _EvidenceAndBoundaryCard(report: report),
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
        ),
        const SizedBox(height: 18),
        const _SectionHeader(
          title: '纵向趋势',
          subtitle: '与自己过去的基线比较，不把一次波动当成最终结论。',
        ),
        const SizedBox(height: 10),
        _TrendCard(sessions: _state.sessions),
        const SizedBox(height: 18),
        const _SectionHeader(
          title: '处方调整规则',
          subtitle: '规则在本机运行，AI不能覆盖。',
        ),
        const SizedBox(height: 10),
        const _AdjustmentRulesCard(),
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
          for (final record in _state.retests) _RetestRecordCard(record: record),
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
          icon: Icons.tune,
          title: '本模块 AI 提示词',
          subtitle: '编辑全局安全、报告解释和复验解释 Prompt',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MentalHealthCheckupPromptPage()),
          ),
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
          subtitle: '无登录、本地事实源、AI需单次同意、非医学诊断',
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
              _InfoStrip(icon: Icons.storage_outlined, color: Color(0xFF39715D), title: '本地事实源', text: '结构化会话、报告、行动和复验写入App现有SQLite私有数据库。'),
              SizedBox(height: 10),
              _InfoStrip(icon: Icons.notes_outlined, color: Color(0xFF7A4E9D), title: '最小化敏感文本', text: '本版本不持久化开放题原文，只保存结构化选项和变化指标。'),
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
                  value: _promptId,
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
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withOpacity(0.22)),
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
        color: color.withOpacity(0.12),
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
                    backgroundColor: color.withOpacity(0.12),
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
                  Text('规则版本 ${report.ruleVersion} · ${_date(report.createdAtMs)}'),
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
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
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
  const _EvidenceAndBoundaryCard({required this.report});

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
          ],
        ),
      );
}

class _SafetyRouteCard extends StatelessWidget {
  final CheckupSafetyStatus status;
  const _SafetyRouteCard({required this.status});

  Future<void> _launch(String value) async {
    try { await launchUrl(Uri.parse(value)); } catch (_) {}
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
                ? '请优先联系可信任的人和当地专业/紧急支持，不要独自承担，也不要用积极练习覆盖危险。若你在加拿大或美国，可拨打或短信 988；如有立即危险，请拨打当地紧急号码（加拿大/美国 911）。'
                : '请先完成更详细的安全确认，必要时联系当地专业支持。本轮不会生成普通课程行动处方。',
            style: const TextStyle(height: 1.55),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(onPressed: () => _launch('tel:988'), icon: const Icon(Icons.call), label: const Text('拨打 988')),
              OutlinedButton.icon(onPressed: () => _launch('sms:988'), icon: const Icon(Icons.sms_outlined), label: const Text('短信 988')),
              OutlinedButton.icon(onPressed: () => _launch('tel:911'), icon: const Icon(Icons.emergency_outlined), label: const Text('紧急 911')),
            ],
          ),
          const SizedBox(height: 8),
          const Text('988/911按钮适用于加拿大或美国；其他地区请联系当地危机热线或紧急服务。', style: TextStyle(fontSize: 11, color: Color(0xFF7A271A))),
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
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Expanded(child: _MetricCard(label: '执行率', value: '${plan.completionRate.toStringAsFixed(0)}%', icon: Icons.check_circle_outline)),
          const SizedBox(width: 8),
          Expanded(child: _MetricCard(label: '平均收益', value: '${plan.averageBenefit.toStringAsFixed(1)}/10', icon: Icons.trending_up)),
          const SizedBox(width: 8),
          Expanded(child: _MetricCard(label: '过度化', value: '${plan.averageOveruseRisk.toStringAsFixed(0)}%', icon: Icons.speed_outlined)),
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
          subtitle: Text('${_date(log.createdAtMs)} · 收益 ${log.benefit.toStringAsFixed(1)}/10 · 功能 ${log.functionChange >= 0 ? '+' : ''}${log.functionChange.toStringAsFixed(0)} · 过度化 ${log.overuseRisk.toStringAsFixed(0)}%'),
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
  const _RetestHero({required this.plan, required this.onRetest});

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
          FilledButton.icon(onPressed: onRetest, icon: const Icon(Icons.fact_check_outlined), label: const Text('完成 B20 课程复验')),
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
  const _AdjustmentRulesCard();

  @override
  Widget build(BuildContext context) {
    const rows = <_RuleRow>[
      _RuleRow('安全不清楚', '暂停普通课程任务，转安全/人工复核'),
      _RuleRow('过度化 ≥50%', '减量、暂停或换制衡处方'),
      _RuleRow('改善 ≥10且功能改善', '维持剂量，不新增处方'),
      _RuleRow('执行 <50%', '先缩小任务、改时机和环境'),
      _RuleRow('执行 ≥70%但无改善', '重新诊断或换方'),
      _RuleRow('综合 ≥75且稳定', '进入低频维持与防复发'),
    ];
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
  const _RetestRecordCard({required this.record});

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
                  _MiniPill('过度化 ${record.overuseRisk.toStringAsFixed(0)}%'),
                ],
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
            backgroundColor: _scoreColor(session.report.overallScore).withOpacity(0.12),
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
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
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
  final VoidCallback onPressed;
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
              const SizedBox(height: 18),
              FilledButton(onPressed: onPressed, child: Text(action)),
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
