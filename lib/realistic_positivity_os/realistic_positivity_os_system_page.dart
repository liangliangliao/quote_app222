import 'dart:convert';

import 'package:flutter/material.dart';

import '../pages/ai_prompt_settings_page.dart';
import 'realistic_positivity_os_dao.dart';
import 'realistic_positivity_os_feature_matrix.dart';
import 'realistic_positivity_os_models.dart';
import 'realistic_positivity_os_prompt_config.dart';
import 'realistic_positivity_os_workbench_page.dart';

/// RPO V5 系统层页面。
///
/// 目的：把终极产品方案中此前仍偏“隐性”的四个产品层补成真实入口：
/// 1. 课程思想层；2. 成长路径层；3. 资产/关系/旧问题库层；4. 安全计划层。
/// 该页面只读写 realistic_positivity_os_* 数据，不融合其他模块。
class RealisticPositivityOsSystemPage extends StatefulWidget {
  final bool embedded;
  final RpoProfile profile;

  const RealisticPositivityOsSystemPage({super.key, this.embedded = false, this.profile = const RpoProfile()});

  @override
  State<RealisticPositivityOsSystemPage> createState() => _RealisticPositivityOsSystemPageState();
}

class _RealisticPositivityOsSystemPageState extends State<RealisticPositivityOsSystemPage> {
  final RealisticPositivityOsDao _dao = RealisticPositivityOsDao();
  bool _loading = true;
  RpoProfile _profile = const RpoProfile();
  List<RpoPracticeRecord> _records = const <RpoPracticeRecord>[];
  List<Map<String, Object?>> _assets = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _evidence = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _experiments = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _checkins = const <Map<String, Object?>>[];

  static const List<_CourseConcept> _concepts = <_CourseConcept>[
    _CourseConcept('realistic_positivity', '现实主义积极', '积极不是否认困难，而是在承认困难的同时恢复现实完整性。', 'reality_lens', RealisticPositivityOsPromptConfig.sceneRealityLensId),
    _CourseConcept('question_create_reality', '问题创造现实', '你问什么问题，就会把注意力放到什么现实上。', 'question_reframing', RealisticPositivityOsPromptConfig.sceneQuestionReframingId),
    _CourseConcept('gratitude_appreciate', '感恩与 Appreciate', '感谢会让被欣赏之物在心理现实中增长。', 'gratitude', RealisticPositivityOsPromptConfig.sceneGratitudeId),
    _CourseConcept('relational_gratitude', '关系性感恩', '感恩应从内心体验进入真实表达，形成 upward spiral。', 'relational_gratitude', RealisticPositivityOsPromptConfig.sceneRelationalGratitudeId),
    _CourseConcept('permission_to_be_human', 'Permission to be human', '先允许情绪存在，不用积极语言覆盖痛苦。', 'emotional_processing', RealisticPositivityOsPromptConfig.sceneEmotionalProcessingId),
    _CourseConcept('active_acceptance', 'Active Acceptance', '接纳不是沉溺，接纳后要选择一个最小有效行动。', 'emotional_processing', RealisticPositivityOsPromptConfig.sceneEmotionalProcessingId),
    _CourseConcept('meaning_making', '痛苦经验 Meaning-making', '负面经验需要表达、书写、分析和支持，而不是封闭反刍。', 'meaning_making', RealisticPositivityOsPromptConfig.sceneMeaningMakingId),
    _CourseConcept('savoring', '积极经验 Savoring', '积极经验更适合重温、描述、保存和行动化。', 'savoring_peak', RealisticPositivityOsPromptConfig.sceneSavoringPeakId),
    _CourseConcept('no_quick_fix', '反 Quick Fix', '真正改变来自长期练习和人格训练，而不是速成承诺。', 'weekly_integration', RealisticPositivityOsPromptConfig.sceneWeeklyIntegrationId),
    _CourseConcept('value_binding', '价值绑定拆解', '旧模式常保护珍贵价值，目标是保留价值，放下痛苦形式。', 'change_lab', RealisticPositivityOsPromptConfig.sceneChangeLabId),
    _CourseConcept('abc_change', 'ABC 改变模型', '改变要同时处理 Affect 情绪、Behavior 行为和 Cognition 认知。', 'abc_change', RealisticPositivityOsPromptConfig.sceneAbcChangeId),
    _CourseConcept('behavior_first', '行为优先', '不等动力，先做 2–10 分钟行动，行为会塑造态度。', 'behavior_first', RealisticPositivityOsPromptConfig.sceneBehaviorFirstId),
    _CourseConcept('stretch_zone', 'Stretch Zone', '成长发生在可承受的不适中，Panic Zone 要降级和求助。', 'stretch_zone', RealisticPositivityOsPromptConfig.sceneStretchZoneId),
    _CourseConcept('peak_ppeo', 'Peak Experience / PPEO', '高峰体验要 replay、write、act，让积极经验进入长期生命秩序。', 'savoring_peak', RealisticPositivityOsPromptConfig.sceneSavoringPeakId),
  ];

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _load();
  }

  Future<void> _load() async {
    await _dao.ensureTables();
    final profile = await _dao.loadProfile();
    final records = await _dao.listRecords(limit: 1000);
    final assets = await _dao.listAssets(limit: 1000);
    final evidence = await _dao.listActionEvidence(limit: 1000);
    final experiments = await _dao.listExperiments(limit: 200);
    final checkins = await _dao.listCheckIns(limit: 1000);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _records = records;
      _assets = assets;
      _evidence = evidence;
      _experiments = experiments;
      _checkins = checkins;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      final body = const Center(child: CircularProgressIndicator());
      return widget.embedded ? body : Scaffold(body: body);
    }
    final body = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: <Widget>[
          _osSummary(),
          const SizedBox(height: 12),
          _growthPath(),
          const SizedBox(height: 12),
          _courseLayer(),
          const SizedBox(height: 12),
          _assetHub(),
          const SizedBox(height: 12),
          _safetyPlan(),
        ],
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('RPO 系统层', style: TextStyle(fontWeight: FontWeight.w900)), backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
      body: body,
    );
  }

  Widget _osSummary() {
    final activatedModules = RpoFeatureMatrix.modules.where((m) => _records.any((r) => r.sceneType == m.sceneType)).length;
    return _section(
      title: 'V5 系统层补全：课程 → 路径 → 资产 → 安全',
      subtitle: '这里补的是终极产品方案中不能只靠行动卡承载的产品层：课程思想层、成长路径、个人资产库、安全计划和长期证据调用。',
      child: Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
        _metric('已激活模块', '$activatedModules/${RpoFeatureMatrix.modules.length}', Icons.dashboard_customize_outlined),
        _metric('课程概念', '${_concepts.length}', Icons.school_outlined),
        _metric('资产库', '${_assets.length}', Icons.folder_special_outlined),
        _metric('行动证据', '${_evidence.length}', Icons.verified_outlined),
        _metric('实验/Check-in', '${_experiments.length}/${_checkins.length}', Icons.fact_check_outlined),
      ]),
    );
  }

  Widget _growthPath() {
    final stages = <_StageSpec>[
      _StageSpec('看见', '从 fault finder 转向完整现实。', Icons.visibility_outlined, _countScenes(<String>['onboarding', 'reality_lens', 'question_reframing']), <String>['onboarding', 'reality_lens', 'question_reframing']),
      _StageSpec('接纳', '允许情绪，表达痛苦，避免强迫积极。', Icons.favorite_border, _countScenes(<String>['emotional_processing', 'meaning_making', 'crisis']), <String>['emotional_processing', 'meaning_making']),
      _StageSpec('感恩', '恢复 appreciation、freshness 与真实关系表达。', Icons.volunteer_activism_outlined, _countScenes(<String>['gratitude', 'relational_gratitude', 'savoring_peak']), <String>['gratitude', 'relational_gratitude', 'savoring_peak']),
      _StageSpec('行动', '用 ABC、行为优先和价值绑定拆解进入改变。', Icons.directions_run_outlined, _countScenes(<String>['change_lab', 'abc_change', 'behavior_first']), <String>['change_lab', 'abc_change', 'behavior_first']),
      _StageSpec('整合', '用 Stretch、实验、Check-in 和周整合形成身份。', Icons.all_inclusive, _countScenes(<String>['stretch_zone', 'weekly_integration']) + _experiments.length + _checkins.length, <String>['stretch_zone', 'weekly_integration']),
    ];
    return _section(
      title: '用户成长路径：看见 → 接纳 → 感恩 → 行动 → 整合',
      subtitle: '终极方案不是功能列表，而是人格训练路径。每个阶段都显示已产生多少真实证据，并给出下一步入口。',
      child: Column(children: stages.map(_stageTile).toList(growable: false)),
    );
  }

  Widget _courseLayer() {
    return _section(
      title: '课程思想层：不是搬运课程，而是把概念变成练习入口',
      subtitle: '每个课程概念都直接连到对应工作台和可编辑 Prompt，保证 AI 始终围绕《哈佛积极心理学》Lecture 9–10 的核心价值系统。',
      child: Column(children: _concepts.map(_conceptTile).toList(growable: false)),
    );
  }

  Widget _assetHub() {
    final byType = <String, List<Map<String, Object?>>>{};
    for (final item in _assets) {
      final type = (item['asset_type'] ?? 'asset').toString();
      byType.putIfAbsent(type, () => <Map<String, Object?>>[]).add(item);
    }
    final profileBlocks = <_ProfileBlock>[
      _ProfileBlock('旧问题库', _profile.commonOldQuestions, Icons.help_outline),
      _ProfileBlock('价值绑定', _profile.valueBindings.map((e) => '${e.oldPattern} → ${e.boundValue} → ${e.healthyExpression}').toList(growable: false), Icons.psychology_alt_outlined),
      _ProfileBlock('支持关系', <String>[..._profile.supportPeople, ..._profile.relationshipMap], Icons.people_alt_outlined),
      _ProfileBlock('感恩资产', _profile.gratitudeAssets, Icons.volunteer_activism_outlined),
      _ProfileBlock('高峰体验', _profile.peakExperiences, Icons.auto_awesome_outlined),
      _ProfileBlock('新身份证据', _profile.identityEvidence, Icons.verified_outlined),
    ];
    return _section(
      title: '成长档案与资产库：AI 可调用的长期证据',
      subtitle: '终极方案要求 AI 不要每次从零开始。这里集中呈现感恩资产、高峰体验、价值绑定、旧问题、支持关系和行动证据。',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        for (final block in profileBlocks) _profileBlockTile(block),
        if (byType.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          const Text('数据库资产', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          for (final entry in byType.entries) _assetTypeTile(entry.key, entry.value),
        ],
        if (byType.isEmpty && profileBlocks.every((b) => b.items.isEmpty)) const Text('暂无成长资产。请先完成一次训练并点击“沉淀到人格地图”。'),
      ]),
    );
  }

  Widget _safetyPlan() {
    final supports = <String>[..._profile.supportPeople, ..._profile.relationshipMap].where((e) => e.trim().isNotEmpty).toList(growable: false);
    return _section(
      title: '安全计划与 Panic Zone 降级',
      subtitle: '终极方案要求：当用户进入 panic / crisis，不继续做积极重构或成长挑战，而是先恢复安全并连接真实支持。',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        _bullet('Panic Zone 时，目标从“成长”切换为“恢复安全”。'),
        _bullet('高风险信号下，不做感恩练习、不做意义化、不做 stretch challenge。'),
        _bullet('优先联系可信任的人、专业人士或当地紧急服务。'),
        const SizedBox(height: 8),
        Text('已记录支持对象：${supports.isEmpty ? '暂无，请在人格地图补充。' : supports.take(8).join('，')}', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          FilledButton.icon(onPressed: () => _openWorkbench('crisis'), icon: const Icon(Icons.health_and_safety_outlined), label: const Text('进入安全支持工作台')),
          OutlinedButton.icon(onPressed: () => _openPrompt(RealisticPositivityOsPromptConfig.sceneSafetyId), icon: const Icon(Icons.tune_outlined), label: const Text('配置安全 Prompt')),
        ]),
      ]),
    );
  }

  int _countScenes(List<String> scenes) => _records.where((r) => scenes.contains(r.sceneType)).length;

  Widget _stageTile(_StageSpec spec) {
    final value = (spec.evidenceCount / 5).clamp(0.0, 1.0).toDouble();
    final nextScene = spec.scenes.firstWhere((scene) => !_records.any((r) => r.sceneType == scene), orElse: () => spec.scenes.first);
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            Icon(spec.icon, color: const Color(0xFF4F46E5)),
            const SizedBox(width: 10),
            Expanded(child: Text(spec.title, style: const TextStyle(fontWeight: FontWeight.w900))),
            Chip(label: Text('${spec.evidenceCount} 证据'), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 4),
          Text(spec.subtitle, style: const TextStyle(color: Color(0xFF64748B), height: 1.35)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: value, minHeight: 8, borderRadius: BorderRadius.circular(999)),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(onPressed: () => _openWorkbench(nextScene), icon: const Icon(Icons.arrow_forward), label: Text('下一步：$nextScene'))),
        ]),
      ),
    );
  }

  Widget _conceptTile(_CourseConcept concept) {
    final records = _records.where((e) => e.sceneType == concept.sceneType).length;
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: ListTile(
        title: Text(concept.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('${concept.description}\n对应模块：${concept.sceneType} · 已有 $records 条训练证据'),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          itemBuilder: (_) => const <PopupMenuEntry<String>>[
            PopupMenuItem(value: 'workbench', child: Text('进入练习')),
            PopupMenuItem(value: 'prompt', child: Text('配置 Prompt')),
          ],
          onSelected: (v) {
            if (v == 'prompt') {
              _openPrompt(concept.promptId);
            } else {
              _openWorkbench(concept.sceneType);
            }
          },
        ),
      ),
    );
  }

  Widget _profileBlockTile(_ProfileBlock block) {
    final items = block.items.where((e) => e.trim().isNotEmpty).toList(growable: false);
    return ExpansionTile(
      leading: Icon(block.icon, color: const Color(0xFF4F46E5)),
      title: Text(block.title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text('${items.length} 条'),
      children: items.isEmpty
          ? <Widget>[const ListTile(title: Text('暂无'))]
          : items.take(20).map((e) => ListTile(dense: true, title: Text(e))).toList(growable: false),
    );
  }

  Widget _assetTypeTile(String type, List<Map<String, Object?>> items) {
    return ExpansionTile(
      leading: const Icon(Icons.folder_special_outlined, color: Color(0xFF4F46E5)),
      title: Text('$type · ${items.length}', style: const TextStyle(fontWeight: FontWeight.w900)),
      children: items.take(20).map((e) {
        final tags = _decodeList(e['tags_json']).join('，');
        return ListTile(
          dense: true,
          title: Text((e['title'] ?? '').toString()),
          subtitle: Text('${(e['content'] ?? '').toString()}${tags.isEmpty ? '' : '\n#$tags'}'),
          isThreeLine: true,
        );
      }).toList(growable: false),
    );
  }

  List<String> _decodeList(Object? raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList(growable: false);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.map((e) => e.toString()).toList(growable: false);
      } catch (_) {}
    }
    return const <String>[];
  }

  Widget _section({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), height: 1.35)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Chip(
        avatar: Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
        label: Text('$label $value'),
        backgroundColor: const Color(0xFFF8FAFC),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      );

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[const Text('• ', style: TextStyle(fontWeight: FontWeight.w900)), Expanded(child: Text(text, style: const TextStyle(height: 1.35)))]),
      );

  void _openWorkbench(String scene) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RealisticPositivityOsWorkbenchPage(initialSceneType: scene, profile: _profile))).then((_) => _load());
  }

  void _openPrompt(String promptId) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiPromptSettingsPage(initialModuleId: RealisticPositivityOsPromptConfig.moduleId, initialPromptId: promptId)));
  }
}

class _CourseConcept {
  final String id;
  final String title;
  final String description;
  final String sceneType;
  final String promptId;
  const _CourseConcept(this.id, this.title, this.description, this.sceneType, this.promptId);
}

class _StageSpec {
  final String title;
  final String subtitle;
  final IconData icon;
  final int evidenceCount;
  final List<String> scenes;
  const _StageSpec(this.title, this.subtitle, this.icon, this.evidenceCount, this.scenes);
}

class _ProfileBlock {
  final String title;
  final List<String> items;
  final IconData icon;
  const _ProfileBlock(this.title, this.items, this.icon);
}
