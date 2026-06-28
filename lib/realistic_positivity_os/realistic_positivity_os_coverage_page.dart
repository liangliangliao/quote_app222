import 'dart:convert';

import 'package:flutter/material.dart';

import '../pages/ai_prompt_settings_page.dart';
import 'realistic_positivity_os_dao.dart';
import 'realistic_positivity_os_feature_matrix.dart';
import 'realistic_positivity_os_models.dart';
import 'realistic_positivity_os_prompt_config.dart';
import 'realistic_positivity_os_workbench_page.dart';

class RealisticPositivityOsCoveragePage extends StatefulWidget {
  final bool embedded;
  final RpoProfile profile;

  const RealisticPositivityOsCoveragePage({
    super.key,
    this.embedded = false,
    this.profile = const RpoProfile(),
  });

  @override
  State<RealisticPositivityOsCoveragePage> createState() => _RealisticPositivityOsCoveragePageState();
}

class _RealisticPositivityOsCoveragePageState extends State<RealisticPositivityOsCoveragePage> {
  final RealisticPositivityOsDao _dao = RealisticPositivityOsDao();
  bool _loading = true;
  RpoProfile _profile = const RpoProfile();
  List<RpoPracticeRecord> _records = const <RpoPracticeRecord>[];
  List<Map<String, Object?>> _assets = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _evidence = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _experiments = const <Map<String, Object?>>[];
  String _selectedScene = 'reality_lens';

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _load();
  }

  Future<void> _load() async {
    try {
      await _dao.ensureTables();
      final profile = await _dao.loadProfile();
      final records = await _dao.listRecords(limit: 1000);
      final assets = await _dao.listAssets(limit: 1000);
      final evidence = await _dao.listActionEvidence(limit: 1000);
      final experiments = await _dao.listExperiments(limit: 100);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _records = records;
        _assets = assets;
        _evidence = evidence;
        _experiments = experiments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载覆盖度审计失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      final body = const Center(child: CircularProgressIndicator());
      return widget.embedded ? body : Scaffold(body: body);
    }
    final content = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: <Widget>[
          _summaryCard(),
          const SizedBox(height: 12),
          _moduleSelector(),
          const SizedBox(height: 12),
          _selectedModuleAudit(),
          const SizedBox(height: 12),
          _fullMatrixCard(),
          const SizedBox(height: 12),
          _globalMissingCard(),
        ],
      ),
    );
    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('RPO 覆盖度审计', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: <Widget>[IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: content,
    );
  }

  Widget _summaryCard() {
    final totalFeatures = RpoFeatureMatrix.modules.fold<int>(0, (sum, m) => sum + m.features.length);
    final coveredFeatures = RpoFeatureMatrix.modules.fold<int>(0, (sum, m) => sum + _featureScores(m).where((s) => s.isCovered).length);
    final modulesWithRecords = RpoFeatureMatrix.modules.where((m) => _records.any((r) => r.sceneType == m.sceneType)).length;
    final closedActions = _evidence.where((e) => (e['status'] ?? '').toString() == 'done').length;
    final score = totalFeatures == 0 ? 0 : ((coveredFeatures / totalFeatures) * 100).round();
    return _card(
      title: '终极产品方案覆盖度审计',
      subtitle: '这不是宣传文案，而是用源码里的记录、资产、行动证据、Prompt 和长期实验来检查功能是否真的落地。',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          _metric('功能覆盖', '$coveredFeatures/$totalFeatures', Icons.check_circle_outline),
          _metric('覆盖率', '$score%', Icons.speed_outlined),
          _metric('有记录模块', '$modulesWithRecords/${RpoFeatureMatrix.modules.length}', Icons.dashboard_customize_outlined),
          _metric('已闭环行动', '$closedActions/${_evidence.length}', Icons.verified_outlined),
          _metric('长期实验', '${_experiments.length}', Icons.calendar_month_outlined),
        ]),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: score / 100, minHeight: 10, borderRadius: BorderRadius.circular(999)),
        const SizedBox(height: 10),
        Text(_coverageDiagnosis(score), style: const TextStyle(height: 1.45, color: Color(0xFF334155))),
      ]),
    );
  }

  Widget _moduleSelector() {
    return _card(
      title: '逐项审计每个子模块',
      subtitle: '每个模块检查六个层面：专用表单、Prompt、训练记录、资产沉淀、行动复盘、长期实验。',
      child: DropdownButtonFormField<String>(
        value: _selectedScene,
        isExpanded: true,
        decoration: const InputDecoration(labelText: '选择要审计的子模块', border: OutlineInputBorder()),
        items: RpoFeatureMatrix.modules
            .map((m) => DropdownMenuItem<String>(value: m.sceneType, child: Text('${m.title} · ${_moduleProgressLabel(m)}')))
            .toList(growable: false),
        onChanged: (v) => setState(() => _selectedScene = v ?? 'reality_lens'),
      ),
    );
  }

  Widget _selectedModuleAudit() {
    final spec = RpoFeatureMatrix.byScene(_selectedScene);
    final records = _records.where((r) => r.sceneType == spec.sceneType).toList(growable: false);
    final assets = _assets.where((a) => (a['asset_type'] ?? '').toString() == spec.assetType).toList(growable: false);
    final evidence = _evidence.where((e) => records.any((r) => r.id == (e['source_record_id'] ?? '').toString())).toList(growable: false);
    final scores = _featureScores(spec);
    final covered = scores.where((s) => s.isCovered).length;
    final featureScore = spec.features.isEmpty ? 0 : ((covered / spec.features.length) * 100).round();
    return _card(
      title: spec.title,
      subtitle: '${spec.courseValue}\n${spec.productGoal}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          CircleAvatar(backgroundColor: spec.color.withOpacity(.12), child: Icon(spec.icon, color: spec.color)),
          const SizedBox(width: 10),
          Expanded(child: LinearProgressIndicator(value: featureScore / 100, minHeight: 9, borderRadius: BorderRadius.circular(999))),
          const SizedBox(width: 10),
          Text('$featureScore%', style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          _metric('训练记录', '${records.length}', Icons.receipt_long_outlined),
          _metric('沉淀资产', '${assets.length}', Icons.folder_special_outlined),
          _metric('行动证据', '${evidence.length}', Icons.task_alt_outlined),
          _metric('完成行动', '${evidence.where((e) => (e['status'] ?? '').toString() == 'done').length}', Icons.verified_outlined),
        ]),
        const SizedBox(height: 12),
        const Text('设计功能逐项检查', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        for (final score in scores) _featureRow(score),
        if (spec.designBoundaries.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          const Text('安全/价值边界', style: TextStyle(fontWeight: FontWeight.w900)),
          for (final b in spec.designBoundaries) _bullet(b),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          FilledButton.icon(onPressed: () => _openWorkbench(spec.sceneType), icon: const Icon(Icons.dashboard_customize_outlined), label: const Text('进入专用工作台补记录')),
          OutlinedButton.icon(onPressed: () => _openPrompt(spec.promptId), icon: const Icon(Icons.tune_outlined), label: const Text('配置本模块 Prompt')),
          OutlinedButton.icon(onPressed: () => _createExperiment(spec.sceneType), icon: const Icon(Icons.event_note_outlined), label: const Text('创建 7 天实验')),
        ]),
      ]),
    );
  }

  Widget _fullMatrixCard() {
    return _card(
      title: '完整功能矩阵',
      subtitle: '从终极产品方案拆出的真实功能项：只有产生记录、沉淀或复盘证据，才会提高实际覆盖度。',
      child: Column(
        children: RpoFeatureMatrix.modules.map((m) {
          final scores = _featureScores(m);
          final covered = scores.where((s) => s.isCovered).length;
          final percent = scores.isEmpty ? 0 : ((covered / scores.length) * 100).round();
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _selectedScene = m.sceneType),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Row(children: <Widget>[
                Icon(m.icon, color: m.color),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Text(m.shortTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text('${covered}/${scores.length} 功能已有使用证据', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ])),
                SizedBox(width: 82, child: LinearProgressIndicator(value: percent / 100, minHeight: 8, borderRadius: BorderRadius.circular(999))),
                const SizedBox(width: 8),
                Text('$percent%', style: const TextStyle(fontWeight: FontWeight.w900)),
              ]),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _globalMissingCard() {
    final missingModules = RpoFeatureMatrix.modules.where((m) => !_records.any((r) => r.sceneType == m.sceneType)).toList(growable: false);
    final noEvidence = _evidence.where((e) => (e['status'] ?? '').toString() != 'done').length;
    final gaps = <String>[
      if (missingModules.isNotEmpty) '还有 ${missingModules.length} 个子模块没有实际训练记录：${missingModules.take(5).map((m) => m.shortTitle).join('、')}${missingModules.length > 5 ? '…' : ''}',
      if (_experiments.isEmpty) '还没有长期训练实验；ABC 改变和 Weekly Integration 仍缺少连续训练证据。',
      if (noEvidence > 0) '有 $noEvidence 个计划行动尚未完成复盘，行动闭环还不充分。',
      if (_profile.valueBindings.isEmpty) '价值绑定地图为空；Change Lab 的核心价值仍未沉淀到长期档案。',
      if (_profile.supportPeople.isEmpty && _profile.relationshipMap.isEmpty) '支持关系地图为空；社会支持和关系性感恩还未充分落地。',
      if (_profile.peakExperiences.isEmpty) '高峰体验库为空；PPEO 相关能力还需要真实记录支撑。',
    ];
    return _card(
      title: '当前源码/使用状态差距清单',
      subtitle: '这张卡会诚实显示距离终极方案仍缺什么。',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        if (gaps.isEmpty) const Text('当前核心闭环已有较完整使用证据。下一步可做更深的统计图表和多周趋势。'),
        for (final gap in gaps) _bullet(gap),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          FilledButton.icon(onPressed: () => _createFullExperiment(), icon: const Icon(Icons.auto_awesome), label: const Text('创建 14 天完整闭环实验')),
          OutlinedButton.icon(onPressed: () => _openWorkbench('onboarding'), icon: const Icon(Icons.account_tree_outlined), label: const Text('补人格地图')),
        ]),
      ]),
    );
  }

  List<_FeatureScore> _featureScores(RpoModuleFeatureSpec spec) {
    return spec.features.map((f) => _FeatureScore(f, _hasEvidenceFor(spec, f))).toList(growable: false);
  }

  bool _hasEvidenceFor(RpoModuleFeatureSpec spec, RpoFeatureSpec feature) {
    final records = _records.where((r) => r.sceneType == spec.sceneType).toList(growable: false);
    final assets = _assets.where((a) => (a['asset_type'] ?? '').toString() == spec.assetType).toList(growable: false);
    final evidence = _evidence.where((e) => records.any((r) => r.id == (e['source_record_id'] ?? '').toString())).toList(growable: false);
    bool hasRecord() => records.isNotEmpty;
    bool hasAction() => evidence.isNotEmpty || records.any((r) => r.microAction.title.trim().isNotEmpty);
    bool hasDoneAction() => evidence.any((e) => (e['status'] ?? '').toString() == 'done');
    bool hasAsset() => assets.isNotEmpty;
    final id = feature.id;
    if (id.contains('prompt')) return true;
    if (id.contains('experiment')) return _experiments.isNotEmpty;
    if (id.contains('current_trouble')) return _profile.currentTroubles.isNotEmpty || hasRecord();
    if (id.contains('emotion_pattern')) return _profile.commonEmotions.isNotEmpty || records.any((r) => r.coreValues.join().contains('情绪'));
    if (id.contains('old_question')) return _profile.commonOldQuestions.isNotEmpty || records.any((r) => r.oldQuestion.trim().isNotEmpty);
    if (id.contains('value_binding')) return _profile.valueBindings.isNotEmpty || hasAsset() || records.any((r) => r.valueBinding.isNotEmpty);
    if (id.contains('support') || id.contains('relationship') || id.contains('gratitude_person')) return _profile.supportPeople.isNotEmpty || _profile.relationshipMap.isNotEmpty || records.any((r) => r.relationshipAction.trim().isNotEmpty);
    if (id.contains('stretch')) return _profile.stretchAreas.isNotEmpty || records.any((r) => r.stretchZone.nextChallenge.trim().isNotEmpty);
    if (id.contains('gratitude') || id.contains('asset')) return _profile.gratitudeAssets.isNotEmpty || hasAsset() || hasRecord();
    if (id.contains('peak') || id.contains('ppeo') || id.contains('positive')) return _profile.peakExperiences.isNotEmpty || hasAsset() || hasRecord();
    if (id.contains('identity')) return _profile.identityEvidence.isNotEmpty || _assets.any((a) => (a['asset_type'] ?? '').toString() == 'identity_evidence') || hasDoneAction();
    if (id.contains('action') || id.contains('start') || id.contains('behavior')) return hasAction();
    if (id.contains('risk') || id.contains('safety') || id.contains('emergency') || id.contains('panic')) return records.any((r) => r.riskLevel == 'high' || r.riskLevel == 'crisis' || r.safetyNote.trim().isNotEmpty);
    if (id.contains('abc') || id.contains('affect') || id.contains('cognition')) return records.any((r) => r.abcPlan.affect.isNotEmpty || r.abcPlan.behavior.isNotEmpty || r.abcPlan.cognition.isNotEmpty);
    return hasRecord();
  }

  String _moduleProgressLabel(RpoModuleFeatureSpec spec) {
    final scores = _featureScores(spec);
    final covered = scores.where((s) => s.isCovered).length;
    return '$covered/${scores.length}';
  }

  Future<void> _openWorkbench(String sceneType) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RealisticPositivityOsWorkbenchPage(initialSceneType: sceneType, profile: _profile)));
    await _load();
  }

  Future<void> _openPrompt(String promptId) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiPromptSettingsPage(initialModuleId: RealisticPositivityOsPromptConfig.moduleId, initialPromptId: promptId)));
  }

  Future<void> _createExperiment(String sceneType) async {
    final spec = RpoFeatureMatrix.byScene(sceneType);
    final days = List<Map<String, dynamic>>.generate(7, (i) => <String, dynamic>{
          'day': i + 1,
          'scene_type': sceneType,
          'title': '${spec.shortTitle} 第 ${i + 1} 天',
          'focus': i == 0 ? spec.productGoal : spec.features[i % spec.features.length].title,
        });
    await _dao.createExperiment(
      title: '${spec.shortTitle} · 7 天真实练习',
      status: 'active',
      planJson: jsonEncode(<String, dynamic>{'type': 'single_module_7_days', 'scene_type': sceneType, 'days': days}),
    );
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已创建 ${spec.shortTitle} 7 天实验')));
  }

  Future<void> _createFullExperiment() async {
    final seq = <String>['onboarding', 'reality_lens', 'emotional_processing', 'gratitude', 'question_reframing', 'behavior_first', 'change_lab', 'abc_change', 'relational_gratitude', 'meaning_making', 'savoring_peak', 'stretch_zone', 'weekly_integration', 'weekly_integration'];
    final days = <Map<String, dynamic>>[];
    for (var i = 0; i < seq.length; i++) {
      final spec = RpoFeatureMatrix.byScene(seq[i]);
      days.add(<String, dynamic>{'day': i + 1, 'scene_type': spec.sceneType, 'title': spec.shortTitle, 'focus': spec.productGoal});
    }
    await _dao.createExperiment(
      title: 'RPO 14 天完整闭环实验',
      status: 'active',
      planJson: jsonEncode(<String, dynamic>{'type': 'full_loop_14_days', 'days': days}),
    );
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已创建 14 天完整闭环实验')));
  }

  String _coverageDiagnosis(int score) {
    if (score < 25) return '当前仍处于骨架阶段：有页面与 Prompt，但真实记录、行动闭环和档案沉淀不足。';
    if (score < 55) return '当前处于功能可用阶段：多数模块有入口，但仍需要更多专用记录、长期实验和行动完成证据。';
    if (score < 80) return '当前处于闭环增强阶段：核心模块已有使用证据，下一步重点是多周趋势、深度指标和智能调度。';
    return '当前已接近完整产品闭环：可继续补图表、通知、同伴支持和更细的长期分析。';
  }

  Widget _featureRow(_FeatureScore score) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: score.isCovered ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Icon(score.isCovered ? Icons.check_circle : Icons.radio_button_unchecked, color: score.isCovered ? const Color(0xFF16A34A) : const Color(0xFFD97706), size: 20),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(score.spec.title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(score.spec.description, style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF334155))),
          const SizedBox(height: 3),
          Text('证据要求：${score.spec.evidenceHint}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ])),
      ]),
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Icon(icon, size: 17, color: const Color(0xFF4F46E5)),
        const SizedBox(width: 6),
        Text('$label $value', style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _card({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), height: 1.38)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('•  '),
          Expanded(child: Text(text, style: const TextStyle(height: 1.38))),
        ]),
      );
}

class _FeatureScore {
  final RpoFeatureSpec spec;
  final bool isCovered;
  const _FeatureScore(this.spec, this.isCovered);
}
