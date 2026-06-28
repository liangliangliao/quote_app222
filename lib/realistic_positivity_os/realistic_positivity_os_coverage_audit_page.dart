import 'package:flutter/material.dart';

import 'realistic_positivity_os_dao.dart';
import 'realistic_positivity_os_prompt_config.dart';

class RpoCoverageSpec {
  final String id;
  final String title;
  final String designRequirement;
  final String evidenceRule;
  final IconData icon;

  const RpoCoverageSpec({
    required this.id,
    required this.title,
    required this.designRequirement,
    required this.evidenceRule,
    required this.icon,
  });
}

/// RPO V4 产品设计覆盖审计页。
///
/// 目的：把用户指出的“未完全实现”显性化，按终极版产品方案逐项核验源码入口、
/// 数据沉淀和用户激活情况，避免只凭口头说“已完成”。
class RealisticPositivityOsCoverageAuditPage extends StatefulWidget {
  const RealisticPositivityOsCoverageAuditPage({super.key});

  @override
  State<RealisticPositivityOsCoverageAuditPage> createState() => _RealisticPositivityOsCoverageAuditPageState();
}

class _RealisticPositivityOsCoverageAuditPageState extends State<RealisticPositivityOsCoverageAuditPage> {
  final RealisticPositivityOsDao _dao = RealisticPositivityOsDao();
  Map<String, int> _counts = const <String, int>{};
  bool _loading = true;

  static const List<RpoCoverageSpec> _specs = <RpoCoverageSpec>[
    RpoCoverageSpec(id: 'onboarding', title: 'Onboarding 人格地图', designRequirement: '当前困扰、感恩资产、情绪模式、旧问题、价值绑定、支持关系、Stretch 方向。', evidenceRule: '有 onboarding 记录或档案字段沉淀。', icon: Icons.account_tree_outlined),
    RpoCoverageSpec(id: 'reality_lens', title: 'Reality Lens 真实看见', designRequirement: '事实/解释/情绪分离，完整现实重构，可控 1%。', evidenceRule: '有 reality_lens 训练记录。', icon: Icons.visibility_outlined),
    RpoCoverageSpec(id: 'question_reframing', title: 'Question Reframing 问题重构', designRequirement: '旧问题识别、坏问题分类、好问题转换、个人旧问题库。', evidenceRule: '有 question_reframing 记录。', icon: Icons.help_outline),
    RpoCoverageSpec(id: 'gratitude', title: 'Gratitude 感恩训练', designRequirement: '三层感恩、freshness、感官化 replay、感恩资产库。', evidenceRule: '有 gratitude 记录或 gratitude_asset。', icon: Icons.volunteer_activism_outlined),
    RpoCoverageSpec(id: 'relational_gratitude', title: 'Relational Gratitude 关系感恩', designRequirement: '感恩信、电话/拜访、pay it forward、关系边界。', evidenceRule: '有 relational_gratitude 记录。', icon: Icons.groups_outlined),
    RpoCoverageSpec(id: 'emotional_processing', title: 'Permission to be Human 情绪处理', designRequirement: '情绪命名、Permission Card、Active Acceptance、压抑检测。', evidenceRule: '有 emotional_processing 记录。', icon: Icons.favorite_border),
    RpoCoverageSpec(id: 'meaning_making', title: 'Meaning-Making 痛苦整合', designRequirement: '负面经验书写、反刍中断、分享支持计划、非强行意义化。', evidenceRule: '有 meaning_making 记录。', icon: Icons.edit_note_outlined),
    RpoCoverageSpec(id: 'savoring_peak', title: 'Savoring / Peak Experience', designRequirement: '积极经验 replay、PPEO、高峰体验卡、积极经验库。', evidenceRule: '有 savoring_peak 记录或 peak_experience。', icon: Icons.auto_awesome_outlined),
    RpoCoverageSpec(id: 'change_lab', title: 'Change Lab 价值绑定拆解', designRequirement: '我真的想改变吗、隐藏收益、保留价值/放下痛苦形式。', evidenceRule: '有 change_lab 记录或 value_binding。', icon: Icons.psychology_alt_outlined),
    RpoCoverageSpec(id: 'abc_change', title: 'ABC Change 改变计划', designRequirement: 'Affect / Behavior / Cognition 三层 7/14 天实验。', evidenceRule: '有 abc_change 记录。', icon: Icons.schema_outlined),
    RpoCoverageSpec(id: 'behavior_first', title: 'Behavior First 行为优先', designRequirement: '2–10 分钟启动、低动力模式、身体反馈、新身份证据。', evidenceRule: '有 behavior_first 记录。', icon: Icons.directions_run_outlined),
    RpoCoverageSpec(id: 'stretch_zone', title: 'Stretch Zone 成长挑战', designRequirement: 'comfort/stretch/panic 三圈检测、挑战阶梯、panic 降级。', evidenceRule: '有 stretch_zone 记录。', icon: Icons.trending_up),
    RpoCoverageSpec(id: 'weekly_integration', title: 'Weekly Integration 每周整合', designRequirement: '人格证据复盘、下周一个核心实验、非打卡统计。', evidenceRule: '有 weekly_integration 记录。', icon: Icons.calendar_month_outlined),
    RpoCoverageSpec(id: 'safety_support', title: 'Safety Support 安全支持', designRequirement: '危机识别、panic 降级、建议真实支持/专业帮助。', evidenceRule: '有 crisis/high 风险记录。', icon: Icons.health_and_safety_outlined),
    RpoCoverageSpec(id: 'identity_evidence', title: '新身份证据库', designRequirement: '把小行动转化为身份叙事，降低 quick fix 倾向。', evidenceRule: '有行动证据或 identity_evidence 资产。', icon: Icons.verified_outlined),
    RpoCoverageSpec(id: 'action_experiments', title: '行动实验生命周期', designRequirement: '行动卡 → 7/14 天实验 → check-in → ready_review/completed。', evidenceRule: '有 action_experiments。', icon: Icons.assignment_turned_in_outlined),
    RpoCoverageSpec(id: 'checkins', title: '每日 Check-in / 复盘', designRequirement: '记录行动、情绪、区间、下一次调整。', evidenceRule: '有 checkins。', icon: Icons.fact_check_outlined),
    RpoCoverageSpec(id: 'profile_archive', title: '成长档案与资产库', designRequirement: '感恩资产、高峰体验、价值绑定、关系地图、行动证据长期沉淀。', evidenceRule: '有 assets。', icon: Icons.folder_special_outlined),
    RpoCoverageSpec(id: 'prompt_center', title: 'AI Prompt 统一配置中心', designRequirement: '所有全局/场景/输出/安全/档案 Prompt 可自由配置。', evidenceRule: '注册的 RPO Prompt 数量。', icon: Icons.tune_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _dao.ensureTables();
    final counts = await _dao.coverageCounts();
    if (!mounted) return;
    setState(() {
      _counts = counts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final activated = _specs.where((s) => (_counts[s.id] ?? 0) > 0).length;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('RPO 产品设计覆盖审计', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: <Widget>[IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: <Widget>[
          _section(
            title: '覆盖度不是口头完成，而是源码入口 + 数据沉淀 + 用户激活',
            subtitle: '这里按终极产品方案逐项核验。灰色代表已有源码入口但用户尚未激活；绿色代表已有真实数据沉淀。',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              LinearProgressIndicator(value: activated / _specs.length),
              const SizedBox(height: 8),
              Text('已激活 $activated / ${_specs.length} 项 · Prompt 注册 ${RealisticPositivityOsPromptConfig.allIds.length} 个', style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 12),
          for (final spec in _specs) _coverageTile(spec),
        ],
      ),
    );
  }

  Widget _coverageTile(RpoCoverageSpec spec) {
    final count = _counts[spec.id] ?? 0;
    final active = count > 0;
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          CircleAvatar(backgroundColor: active ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9), child: Icon(spec.icon, color: active ? const Color(0xFF15803D) : const Color(0xFF64748B))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Row(children: <Widget>[
              Expanded(child: Text(spec.title, style: const TextStyle(fontWeight: FontWeight.w900))),
              Chip(label: Text(active ? '已激活 $count' : '待激活'), visualDensity: VisualDensity.compact),
            ]),
            const SizedBox(height: 4),
            Text('设计要求：${spec.designRequirement}', style: const TextStyle(height: 1.35)),
            const SizedBox(height: 4),
            Text('核验证据：${spec.evidenceRule}', style: const TextStyle(color: Color(0xFF64748B), height: 1.35)),
          ])),
        ]),
      ),
    );
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
}
