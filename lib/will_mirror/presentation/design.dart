import 'package:flutter/material.dart';
import '../domain/model.dart';
import '../domain/provenance.dart';

const mirrorInk = Color(0xff163f43);
const mirrorTeal = Color(0xff286b69);
const mirrorGold = Color(0xffbe8b50);
const mirrorPaper = Color(0xfff6f4ed);

ThemeData mirrorTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
      seedColor: mirrorTeal,
      brightness: brightness,
      surface: brightness == Brightness.dark
          ? const Color(0xff182527)
          : mirrorPaper);
  final base = ThemeData(
      useMaterial3: true, colorScheme: scheme, brightness: brightness);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0),
    textTheme: base.textTheme.apply(fontFamily: 'sans-serif').copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontSize: 32,
            height: 1.35,
            fontWeight: FontWeight.w700,
            letterSpacing: -.7),
        headlineSmall: base.textTheme.headlineSmall
            ?.copyWith(fontSize: 23, height: 1.45, fontWeight: FontWeight.w700),
        titleLarge: base.textTheme.titleLarge
            ?.copyWith(fontSize: 20, height: 1.45, fontWeight: FontWeight.w600),
        bodyLarge:
            base.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.65),
        bodyMedium:
            base.textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.65)),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: scheme.primary))),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(48, 50),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            textStyle: const TextStyle(
                fontFamily: 'sans-serif',
                fontSize: 15,
                fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 46),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)))),
    navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        height: 74),
    dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .6), space: 28),
  );
}

String nodeTitle(MirrorNode n) {
  for (final key in [
    'summary',
    'title',
    'claim',
    'statement',
    'action',
    'description',
    'text',
    'ifThen',
    'signal',
    'detail',
    'label'
  ]) {
    final value = n.text(key);
    if (value.isNotEmpty) return value;
  }
  return kindLabel(n.kind);
}

String kindLabel(NodeKind kind) => switch (kind) {
      NodeKind.evidence => '原始记录',
      NodeKind.understanding => '事实与未知',
      NodeKind.want => '欲求候选',
      NodeKind.belief => '当时的认识',
      NodeKind.motive => '候选理由',
      NodeKind.reframe => '认识转换',
      NodeKind.route => '可能的走法',
      NodeKind.routeFit => '路线适配',
      NodeKind.graphEdge => '理由关系',
      NodeKind.conflict => '动机冲突',
      NodeKind.deliberation => '当时的审议',
      NodeKind.graphShift => '认识带来的变化',
      NodeKind.consequence => '时间中的后果',
      NodeKind.obstacle => '可能的障碍',
      NodeKind.taskRequirement => '任务要求',
      NodeKind.capability => '能力证据',
      NodeKind.supportVariant => '支持与替代',
      NodeKind.resourceConflict => '资源与取舍',
      NodeKind.tradeoff => '阶段性聚焦',
      NodeKind.preflight => '事前准备',
      NodeKind.intervention => '条件安排',
      NodeKind.interventionExecution => '真实准备',
      NodeKind.scene => '个人预演',
      NodeKind.sceneFeedback => '预演反馈',
      NodeKind.plan => '条件性预案',
      NodeKind.seal => '事前封存',
      NodeKind.trigger => '等待的条件',
      NodeKind.triggerCheck => '现实条件核实',
      NodeKind.reappraisal => '现场重估',
      NodeKind.awareness => '现场想起的理由',
      NodeKind.decision => '决意陈述',
      NodeKind.opportunity => '真实选择机会',
      NodeKind.attempt => '实际尝试',
      NodeKind.observation => '行为观察',
      NodeKind.acquisition => '实际取得',
      NodeKind.experience => '后续体验',
      NodeKind.review => '事实复盘',
      NodeKind.repair => '可做的补救',
      NodeKind.insight => '经验认识',
      NodeKind.manifestation => '经历之间的可能联系',
      NodeKind.principle => '个人原则',
      NodeKind.principleMatch => '经验与当前情境',
      NodeKind.principleApplication => '原则的实际应用',
      NodeKind.changeability => '现实可改变性',
      NodeKind.strengthMatch => '具体任务中的优势',
      NodeKind.boundaryReview => '自主与边界',
      NodeKind.recommendation => '本次理由推荐',
      NodeKind.feedback => '你的反馈',
      NodeKind.reminder => '可选提醒',
      NodeKind.permission => '使用范围',
      NodeKind.revision => '修订记录',
    };
String sourceLabel(EvidenceOrigin value) => switch (value) {
      EvidenceOrigin.selfReport => '本人记录',
      EvidenceOrigin.authorizedObservation => '授权核实',
      EvidenceOrigin.deviceEvent => '设备事件',
      EvidenceOrigin.aiHypothesis => 'AI 生成',
      EvidenceOrigin.productRule => '记录与规则',
    };

String contentSourceLabel(MirrorNode node,
        {MirrorNode? Function(String)? resolve}) =>
    aiContentOrigin(node, resolve: resolve) ??
    (node.kind == NodeKind.plan ? '你确认的预案' : sourceLabel(node.origin));

class AiOriginLabel extends StatelessWidget {
  const AiOriginLabel(
      {super.key,
      required this.node,
      this.resolve,
      this.showHumanSource = false});
  final MirrorNode node;
  final MirrorNode? Function(String)? resolve;
  final bool showHumanSource;

  @override
  Widget build(BuildContext context) {
    final ai = aiContentOrigin(node, resolve: resolve);
    if (ai == null && !showHumanSource) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(children: [
        MirrorTag(ai ?? sourceLabel(node.origin),
            icon: ai == null ? Icons.edit_note : Icons.auto_awesome_outlined)
      ]),
    );
  }
}

String phaseLabel(TimePhase value) => switch (value) {
      TimePhase.t0 => '事前',
      TimePhase.t1 => '现场',
      TimePhase.t2 => '事后',
      TimePhase.t3 => '后续',
      TimePhase.unknown => '时点未知'
    };
String statusLabel(NodeStatus value) => switch (value) {
      NodeStatus.active => '已记录',
      NodeStatus.draft => '待审议',
      NodeStatus.accepted => '你已认可',
      NodeStatus.rejected => '你已否定',
      NodeStatus.stale => '来源变化，待复核',
      NodeStatus.retracted => '已撤回',
      NodeStatus.retired => '已归档'
    };
String timeLabel(DateTime? date) {
  if (date == null) return '未知';
  final d = date.toLocal();
  return '${d.month}月${d.day}日 ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

const valueLabels = <String, String>{
  'wish': '愿望表述',
  'want_fit': '欲求与真实过程',
  'want_alignment': '个人欲求适配',
  'want': '欲求认识',
  'verify': '先核实',
  'variable': '状态变化',
  'value': '价值判断',
  'used': '本人报告实际使用',
  'unscored': '未评分',
  'unrecorded': '未记录',
  'unknown_or_mixed': '未知或多机制',
  'undecided': '尚未决定',
  'uncontrollable_loss': '不可控损失',
  'training': '练习',
  'trainable': '可以训练',
  'tradeoffs': '取舍代价',
  'too_strong': '过于强烈',
  'time_shift': '调整时点',
  'threshold': '达到条件才出现',
  'supported': '当前来源有支持',
  'strategy': '策略',
  'start_friction': '启动阻力',
  'stable_reported': '本人报告相对稳定',
  'skip': '跳过',
  'skill_gap': '任务技能差距',
  'self_report': '本人记录',
  'self_concordance': '自主认可',
  'selected_cases': '本人选择课题',
  'scoring': '候选评分',
  'scored': '本次量规评分',
  'rules': '来源规则摘要',
  'retrospective': '事后回述',
  'retire': '归档',
  'response': '应对',
  'resources_access': '资源与使用机会',
  'resources': '资源条件',
  'repeated': '重复发生',
  'relatable': '有共鸣',
  'rejected': '已否定',
  'reject': '否定',
  'refused': '未获评分',
  'refuse': '拒绝',
  'recalled_after': '事后才回忆得知',
  'recalled': '本人报告想起',
  'random_event': '偶发条件',
  'prospective': '事前意向',
  'presented': '已呈现，是否注意未知',
  'present': '当前处境',
  'prediction': '条件性预测',
  'personal_fit': '个体欲求相关性',
  'pause': '暂停',
  'past': '过去',
  'outcome_want_fit': '结果与真实体验之间',
  'outcome': '结果反馈',
  'other_agent': '他人的选择',
  'original': '原先路线',
  'option_generation': '路线形成',
  'one_off': '一次性',
  'obstacle': '实际或可能障碍',
  'observation_reliability': '观察可靠性',
  'noticed_at_trigger': '现场才注意到',
  'noticed': '本人确认注意到',
  'not_observed': '未观察到影响',
  'not_known': '当时不知道',
  'motive_conflict': '理由冲突',
  'moral': '真实责任',
  'minor': '影响较小',
  'method': '可检验方法',
  'metaphysical': '不可实证信念',
  'long_horizon': '长时间影响',
  'later': '稍后',
  'known_tradeoff': '当时已知代价',
  'known_before': '事前已知',
  'knowledge': '当时认识',
  'internal': '个人内部',
  'interacting': '内外条件共同作用',
  'intention_attempt': '决意与尝试之间',
  'information': '信息方面',
  'inaccurate': '不准确',
  'important': '重要取舍',
  'health_physical': '身体与健康',
  'goal_means': '目标与手段',
  'fit': '实际适配',
  'fiction': '自愿想象',
  'feeling': '本人感受',
  'external_outcome': '外部结果',
  'external': '外部条件',
  'explicit': '本人明确表达',
  'experience': '真实体验',
  'execution': '执行过程',
  'evidence_quality': '事实依据质量',
  'event': '事件原文',
  'epistemic_information': '认识与信息',
  'environment_institution': '环境与制度',
  'environment_adjustment': '调整环境',
  'emotional': '情绪负担',
  'emotion_self_regulation': '情绪与调节',
  'edit': '修改',
  'device': '设备记录',
  'deliberation_access': '进入意识与审议机会',
  'deliberation': '正反审议',
  'decisions': '四维在线量规',
  'decision_materiality': '本次取舍重要性',
  'decision': '决意陈述',
  'cumulative': '逐次累积',
  'cross_case': '跨课题参考',
  'critical': '关键条件',
  'counter': '相反证据',
  'correction': '更正记录',
  'contextual': '情境中的个人线索',
  'context_relevance': '当前情境相关性',
  'context_dependent': '依赖情境',
  'context_coverage': '情境覆盖',
  'context': '当前情境',
  'condition': '现实条件',
  'collaboration': '协作',
  'choice_availability': '真实可选机会',
  'challenged': '受到质疑',
  'causal': '因果解释',
  'case_only': '仅本课题',
  'capability_skill': '身体与技能',
  'capability': '任务能力',
  'boundary': '现实边界',
  'belief': '认识或信念',
  'autonomy': '自主条件',
  'authorized_observation': '授权观察',
  'attempt_start': '尝试启动',
  'attempt_action': '尝试与行动完成之间',
  'at_trigger': '现场决意',
  'assistive_tool': '辅助工具',
  'approved': '已认可预演',
  'anticipated': '预期后悔',
  'analysis': '课题分析',
  'alternatives': '其他解释',
  'alternative': '换一条路线',
  'alternate_route': '替代路线',
  'action_outcome': '行动与外部结果之间',
  'action': '实际行动',
  'accept': '认可',
  'ability': '具体能力',
  'unknown': '未知',
  'unclear': '尚不清楚',
  'unverified': '待核实',
  'tentative': '初步候选',
  'individual': '当前个人线索',
  'generic': '一般性假设',
  'reported': '本人报告',
  'observed': '已有观察',
  'verified': '已核实',
  'hypothesized': '待检验假设',
  'contradicted': '已有反证',
  'intuitive': '直观理由',
  'abstract': '抽象理由',
  'mixed': '同时包含',
  'approach': '趋近',
  'avoid': '回避',
  'now': '当下',
  'next_episode': '下次机会',
  'near': '近期',
  'long': '长远',
  'supports': '支持',
  'opposes': '反对',
  'conditional': '有条件',
  'uncertain': '待核实',
  'clear': '当前已核实的门槛允许',
  'verify_first': '先核实',
  'blocked': '存在硬性限制',
  'infeasible': '目前不可实施',
  'high': '较多支持',
  'partial': '部分／混合',
  'low': '较少支持',
  'promotes': '可能促进',
  'harms': '可能损害',
  'verified_fit': '已核实适配',
  'fit_with_support': '有支持条件时适配',
  'mismatch_for_this_task': '当前任务不适配',
  'prohibited_due_to_safety': '安全条件不允许',
  'reversible': '可撤回',
  'partly_reversible': '部分可撤回',
  'irreversible': '不可逆',
  'temporary': '暂时',
  'recoverable': '可恢复',
  'perceived_permanent': '担心永久失去，尚待核实',
  'direct': '可直接改变',
  'indirect': '可间接影响',
  'shared': '需要协作',
  'none': '当前无法控制',
  'irreversible_past': '已经发生的过去',
  'modifiable_now': '当前可以改变',
  'modifiable_with_support': '获得支持后可能改变',
  'hard_limit_for_task': '已核实的任务限制',
  'externally_dependent': '依赖外部或对方自主',
  'completed': '已完成行动',
  'changed': '已改变',
  'not_performed': '未行动',
  'pending': '等待后续结果',
  'achieved': '已取得预期结果',
  'not_achieved': '未取得预期结果',
  'acquired': '实际取得',
  'partly_acquired': '部分取得',
  'not_acquired': '尚未取得',
  'initial': '初次体验',
  'routine': '进入日常',
  'sustained': '持续经历',
  'custom': '自定义窗口',
  'executed': '确实做了',
  'partly_executed': '做了一部分',
  'not_executed': '没有实施',
  'preparation': '实际准备',
  'departed': '已出发',
  'arrived': '已到达',
  'attempted': '已开始尝试',
  'started_blocked': '尝试后受阻',
  'not_started': '没有启动',
  'yes': '有真实机会',
  'no': '没有真实机会',
  'reasonably_free': '相对自主',
  'pressured': '存在压力',
  'coerced': '被迫',
  'strong': '有较多来源',
  'limited': '证据有限',
  'insufficient': '证据不足',
  'social_symbol': '社会象征／榜样',
  'anticipated_outcome': '预期得到的结果',
  'process_preference': '日常过程的偏好',
  'lived_evidence': '亲身经历',
  'compatible': '可以兼容',
  'independent': '相互独立',
  'competing': '争夺同一资源',
  'strictly_exclusive': '当前窗口互斥',
  'prerequisite': '前置条件',
  'parallel': '并行',
  'sequence': '先后安排',
  'reduce': '减量',
  'defer': '暂缓',
  'switch': '换手段',
  'drop': '本人确认放弃',
  'retain': '保留',
  'insufficient_evidence': '目前证据不足',
  'multiple_contexts': '多个情境的初步支持',
  'needs_review': '需要重新检验',
  'expression_possible': '可能是不同表达',
  'multi_motive_possible': '可能同时有多个理由',
  'context_modulated': '可能随条件不同',
  'contradictory_evidence': '反向证据',
  'independent_facet': '保留为独立经历',
  'demonstrated_strength': '已有真实表现',
  'trainable_gap': '可训练的差距',
  'variable_state': '当下状态波动',
  'task_mismatch': '此项任务存在差距',
  'facts': '事实卡',
  'future': '可能的未来',
  'future_obstacle': '未来与障碍',
  'process': '未来、障碍与应对',
  'fact': '事实',
  'plausible': '可能解释',
  'hypothetical': '假设画面',
  'requires_belief': '依赖这项认识',
  'activated_by': '在该条件下进入意识',
  'substitutes_for': '可作为替代',
  'approach_approach': '两个想要之间',
  'avoid_avoid': '两个不愿承受之间',
  'approach_avoid': '同一路线同时吸引与抗拒',
  'double_approach_avoid': '多路线各有得失',
  'cross_time': '当下与未来之间',
  'unconfirmed': '还未确认',
  'confirmed': '已由本人确认',
  'expired': '原窗口已过',
  'cancelled': '已取消',
  'scheduled': '已安排',
  'denied': '未获通知权限',
  'failed': '提醒未安排成功',
  'opened': '已打开',
  'explicitly_recalled': '本人确认当时想起',
  'context_changed': '现场条件有变化',
  'applied_self_report': '本人确认采用',
  'applied_verified': '授权来源核实采用',
  'not_applied': '没有采用',
  'accepted': '本人认可',
  'declined': '本人拒绝',
  'proposed': '候选',
  'delivered': '已投递',
  'not_applicable': '当前不适用',
  'applicable': '当前相关',
  'rational_weighing': '理性权衡',
  'external_chance': '外部偶然',
  'internal_impulse': '内部冲动',
  'value_shift': '价值或心境变化',
  'effort_to_maintain': '努力维持观念',
  'required_by_rule': '规则要求的前置条件',
  'supported_contribution': '有证据支持可能贡献',
  'interest_only': '仅表达兴趣',
  'planned': '已有计划',
  'experienced': '已有真实体验',
  'considered': '正在考虑',
};
String humanValue(String value) => valueLabels[value] ?? value;

class MirrorCard extends StatelessWidget {
  const MirrorCard(
      {super.key,
      required this.child,
      this.color,
      this.padding = const EdgeInsets.all(20),
      this.onTap});
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: color ?? Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(padding: padding, child: child)));
}

class MirrorTag extends StatelessWidget {
  const MirrorTag(this.text, {super.key, this.icon, this.emphasis = false});
  final String text;
  final IconData? icon;
  final bool emphasis;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: emphasis ? c.primaryContainer : c.surfaceContainer,
            borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14), const SizedBox(width: 5)],
          Flexible(
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(height: 1.35)))
        ]));
  }
}

class MirrorEmpty extends StatelessWidget {
  const MirrorEmpty(
      {super.key,
      required this.title,
      required this.body,
      this.action,
      this.icon = Icons.waves_outlined});
  final String title, body;
  final Widget? action;
  final IconData icon;
  @override
  Widget build(BuildContext context) => MirrorCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(body),
        if (action != null) ...[const SizedBox(height: 16), action!]
      ]));
}
