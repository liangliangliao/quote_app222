import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Default thought concept taxonomy (tree) for "弹出念头" tagging.
///
/// Design goals:
/// - Stable UID per node (dot-separated path) for future horizontal/vertical expansion.
/// - Lazy-load friendly (parent_uid query).
/// - Metadata extensible via JSON.

const int kThoughtTaxonomyId = 1;
const String kThoughtTaxonomyCode = 'thought_tree';
const String kThoughtTaxonomyName = '念头概念树';
/// Update this when you change [thoughtTaxonomySeed].
const String kThoughtTaxonomyContentVer = '2026.01.04';

class ThoughtSeedNode {
  final String uid;
  final String title;
  final String kind;
  final int order;
  final Map<String, dynamic> meta;

  const ThoughtSeedNode(this.uid, this.title, this.kind, this.order, [this.meta = const {}]);
}

String? _parentUidOf(String uid) {
  final i = uid.lastIndexOf('.');
  if (i <= 0) return null;
  return uid.substring(0, i);
}

String _slugOf(String uid) {
  final i = uid.lastIndexOf('.');
  return i < 0 ? uid : uid.substring(i + 1);
}

int _depthOf(String uid) => '.'.allMatches(uid).length;

/// Ensure taxonomy tables exist and seed the default taxonomy once.
Future<void> ensureThoughtTaxonomy(Database db) async {
  // Taxonomy meta
  await db.execute('''
    CREATE TABLE IF NOT EXISTS vision_taxonomy (
      id INTEGER PRIMARY KEY,
      code TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      content_ver TEXT NOT NULL,
      updated_ts INTEGER NOT NULL
    )
  ''');

  // Tree nodes
  await db.execute('''
    CREATE TABLE IF NOT EXISTS vision_node (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      taxonomy_id INTEGER NOT NULL,
      uid TEXT NOT NULL,
      parent_uid TEXT,
      slug TEXT NOT NULL,
      title TEXT NOT NULL,
      node_kind TEXT NOT NULL,
      description TEXT,
      display_order INTEGER NOT NULL DEFAULT 0,
      depth INTEGER NOT NULL DEFAULT 0,
      has_children INTEGER NOT NULL DEFAULT 0,
      children_count INTEGER NOT NULL DEFAULT 0,
      metadata_json TEXT NOT NULL DEFAULT '{}',
      is_active INTEGER NOT NULL DEFAULT 1,
      UNIQUE(taxonomy_id, uid)
    )
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_vision_node_children ON vision_node(taxonomy_id, parent_uid, display_order, id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_vision_node_uid ON vision_node(taxonomy_id, uid)');

  // Optional extensible properties
  await db.execute('''
    CREATE TABLE IF NOT EXISTS vision_property_def (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      namespace TEXT NOT NULL,
      key TEXT NOT NULL,
      value_type TEXT NOT NULL,
      default_json TEXT NOT NULL DEFAULT 'null',
      schema_json TEXT NOT NULL DEFAULT '{}',
      UNIQUE(namespace, key)
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS vision_node_property (
      taxonomy_id INTEGER NOT NULL,
      node_uid TEXT NOT NULL,
      prop_id INTEGER NOT NULL,
      value_json TEXT NOT NULL,
      PRIMARY KEY (taxonomy_id, node_uid, prop_id)
    )
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_vision_node_property_node ON vision_node_property(taxonomy_id, node_uid)');

  // Thought <-> node mapping (multi-select)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS vision_thought_node (
      thought_id TEXT NOT NULL,
      node_uid TEXT NOT NULL,
      PRIMARY KEY (thought_id, node_uid)
    )
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_vision_thought_node_thought ON vision_thought_node(thought_id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_vision_thought_node_uid ON vision_thought_node(node_uid)');

  // Seed only once
  final existing = await db.query(
    'vision_taxonomy',
    columns: ['id', 'content_ver'],
    where: 'id = ?',
    whereArgs: [kThoughtTaxonomyId],
    limit: 1,
  );
  if (existing.isNotEmpty) return;

  // Pre-compute children counts and has_children.
  final childCount = <String, int>{};
  for (final n in thoughtTaxonomySeed) {
    final p = _parentUidOf(n.uid);
    if (p == null) continue;
    childCount[p] = (childCount[p] ?? 0) + 1;
  }

  await db.transaction((txn) async {
    await txn.insert('vision_taxonomy', {
      'id': kThoughtTaxonomyId,
      'code': kThoughtTaxonomyCode,
      'name': kThoughtTaxonomyName,
      'content_ver': kThoughtTaxonomyContentVer,
      'updated_ts': DateTime.now().millisecondsSinceEpoch,
    });

    final batch = txn.batch();
    for (final n in thoughtTaxonomySeed) {
      final p = _parentUidOf(n.uid);
      final c = childCount[n.uid] ?? 0;
      batch.insert('vision_node', {
        'taxonomy_id': kThoughtTaxonomyId,
        'uid': n.uid,
        'parent_uid': p,
        'slug': _slugOf(n.uid),
        'title': n.title,
        'node_kind': n.kind,
        'description': null,
        'display_order': n.order,
        'depth': _depthOf(n.uid),
        'children_count': c,
        'has_children': c > 0 ? 1 : 0,
        'metadata_json': jsonEncode(n.meta),
        'is_active': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  });
}

/// Seed content: the full concept tree provided by the user.
///
/// NOTE: UIDs are stable API for future versions.
const List<ThoughtSeedNode> thoughtTaxonomySeed = <ThoughtSeedNode>[
  ThoughtSeedNode('mind', '心智现象（Mind / Mental phenomena）', 'root', 1),
  ThoughtSeedNode('mind.cognition', '信息处理系统（Cognition）', 'group', 1),
  ThoughtSeedNode('mind.cognition.marr', 'Marr三层解释框架（科学分析层级）', 'framework', 1),
  ThoughtSeedNode('mind.cognition.marr.computational', '计算层（Computational：这个系统“要解决什么问题”）', 'layer', 1),
  ThoughtSeedNode('mind.cognition.marr.computational.prediction_error_reduction', '预测与误差最小化（prediction / error reduction）', 'concept', 1),
  ThoughtSeedNode('mind.cognition.marr.computational.reward_utility_maximization', '价值最大化（reward / utility maximization）', 'concept', 2),
  ThoughtSeedNode('mind.cognition.marr.computational.safety_threat_management', '生存与风险管理（safety / threat management）', 'concept', 3),
  ThoughtSeedNode('mind.cognition.marr.computational.social_coordination', '社会协调（affiliation / status / cooperation）', 'concept', 4),
  ThoughtSeedNode('mind.cognition.marr.computational.self_coherence_identity_maintenance', '自我一致性（self-coherence / identity maintenance）', 'concept', 5),

  ThoughtSeedNode('mind.cognition.marr.algorithmic', '算法层（Algorithmic：用什么表征与运算来做）', 'layer', 2),
  ThoughtSeedNode('mind.cognition.marr.algorithmic.representations', '表征（Representations：脑中“是什么形式”）', 'category', 1),
  ThoughtSeedNode('mind.cognition.marr.algorithmic.representations.proposition', '命题/陈述（proposition：A=…、A会…）', 'concept', 1),
  ThoughtSeedNode('mind.cognition.marr.algorithmic.representations.imagery', '图像/意象（imagery：画面/声音/动作感）', 'concept', 2),
  ThoughtSeedNode('mind.cognition.marr.algorithmic.representations.affect_appraisal', '情绪-评估（affect/appraisal：好坏、危险度）', 'concept', 3),
  ThoughtSeedNode('mind.cognition.marr.algorithmic.representations.interoception', '身体内感受标记（interoception：胸闷=危险信号）', 'concept', 4),

  ThoughtSeedNode('mind.cognition.marr.algorithmic.operations', '运算（Operations：对表征做什么）', 'category', 2),
  ThoughtSeedNode('mind.cognition.marr.algorithmic.operations.inference', '推断（inference：所以…/因此…）', 'concept', 1),
  ThoughtSeedNode('mind.cognition.marr.algorithmic.operations.attribution', '归因（attribution：因为他…/因为我…）', 'concept', 2),
  ThoughtSeedNode('mind.cognition.marr.algorithmic.operations.comparison', '比较（comparison：比别人…）', 'concept', 3),
  ThoughtSeedNode('mind.cognition.marr.algorithmic.operations.planning', '规划（planning：下一步…）', 'concept', 4),
  ThoughtSeedNode('mind.cognition.marr.algorithmic.operations.evaluation', '评估（evaluation：好/坏/对/错）', 'concept', 5),
  ThoughtSeedNode('mind.cognition.marr.algorithmic.operations.reappraisal', '再评价（reappraisal：换个解释）', 'concept', 6),

  ThoughtSeedNode('mind.cognition.marr.implementational', '实现层（Implementational：由什么生理与神经机制支撑）', 'layer', 3),
  ThoughtSeedNode('mind.cognition.marr.implementational.attention_networks', '注意网络（alerting / orienting / executive control）', 'concept', 1),
  ThoughtSeedNode('mind.cognition.marr.implementational.memory_systems', '记忆系统（工作记忆 / 情景记忆 / 语义记忆）', 'concept', 2),
  ThoughtSeedNode('mind.cognition.marr.implementational.reward_threat_systems', '奖赏与威胁系统（dopamine、杏仁核等相关回路）', 'concept', 3),
  ThoughtSeedNode('mind.cognition.marr.implementational.interoceptive_pathways', '躯体/内感受通路（心率、呼吸、胃部紧张的反馈）', 'concept', 4),

  ThoughtSeedNode('mind.cognition.phenomenology', '现象学层（Phenomenology：主观体验里我们称之为“念头”）', 'layer', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode', '念头（Thought episode：一次可切分的心理事件）', 'group', 1),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel', '1）载体/呈现通道（最直观：你“怎么体验到它”）', 'dimension', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.inner_speech', '内言/脑内句子（Inner speech）', 'category', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.inner_speech.narrative_sentence', '叙事句： “我就是不行”', 'example', 1, {'example': '我就是不行'}),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.inner_speech.judgment_sentence', '判断句： “他在针对我”', 'example', 2, {'example': '他在针对我'}),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.inner_speech.imperative_sentence', '指令句： “赶紧解释/马上回”', 'example', 3, {'example': '赶紧解释/马上回'}),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.inner_speech.question_sentence', '疑问句： “他是不是讨厌我？”', 'example', 4, {'example': '他是不是讨厌我？'}),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.inner_speech.self_blame_rhetorical', '反问/自责： “我怎么又这样？”', 'example', 5, {'example': '我怎么又这样？'}),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.imagery', '意象/脑内电影（Imagery）', 'category', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.imagery.visual', '视觉：脑中闪过“被批评/出丑”的画面', 'example', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.imagery.auditory', '听觉：回放对方语气、某句话', 'example', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.imagery.motor', '动作/运动意象：想象自己冲出去/逃离', 'example', 3),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.imagery.tactile_scene', '触觉/场景感：想象现场气氛压迫', 'example', 4),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.somatic_marker', '身体标记（Somatic marker / interoceptive cue）', 'category', 3),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.somatic_marker.chest_heart', '胸闷/心跳快：像“危险警报”', 'example', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.somatic_marker.stomach_nausea', '胃紧/恶心：像“要出事”', 'example', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.somatic_marker.shoulder_jaw', '肩颈紧/咬牙：像“准备对抗”', 'example', 3),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.action_urge', '冲动/动作倾向（Action urge）', 'category', 4),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.action_urge.flee', '逃：想躲/取消/不看消息', 'example', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.action_urge.fight', '斗：想回怼/争辩', 'example', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.action_urge.fawn', '讨好：想解释/道歉/连发', 'example', 3),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.action_urge.freeze', '冻结：脑空白/僵住', 'example', 4),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.channel.action_urge.check', '检查：想反复确认/搜证据', 'example', 5),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure', '2）结构（命题结构：念头“句法”上长什么样）', 'dimension', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.subject', '主体指向（Subject）', 'category', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.subject.self', '自我： “我…”', 'concept', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.subject.other', '他人： “他/她…”', 'concept', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.subject.world_rules', '世界/规则： “事情/社会…”', 'concept', 3),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.subject.we_relationship', '我们/关系： “我们…”', 'concept', 4),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.predicate', '谓词类型（Predicate：在断言什么）', 'category', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.predicate.fact', '事实： “他还没回消息”', 'concept', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.predicate.possibility', '可能性： “也许他在忙”', 'concept', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.predicate.prediction', '预测： “他会离开我”', 'concept', 3),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.predicate.value_judgment', '价值判断： “这太糟/太不公平”', 'concept', 4),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.predicate.ability_judgment', '能力判断： “我做不到/我能搞定”', 'concept', 5),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.predicate.norm_obligation', '规范/义务： “我必须/应该…”', 'concept', 6),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.quantifiers', '量词与绝对化（Quantifiers）', 'category', 3),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.quantifiers.always_never', '总是/从来： “我总是搞砸”', 'concept', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.quantifiers.only_if', '只有…才…： “只有完美才安全”', 'concept', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.quantifiers.one_equals_all', '一次=全部： “这次错=我不行”', 'concept', 3),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.if_counterfactual', '条件与反事实（If / Counterfactual）', 'category', 4),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.if_counterfactual.conditional_threat', '条件威胁： “万一…就完了”', 'concept', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.if_counterfactual.counterfactual_self_blame', '反事实自责： “要是当时…就好了”', 'concept', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.structure.if_counterfactual.exchange_condition', '交换条件： “如果他爱我就应该…”', 'concept', 3),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.generation', '3）生成方式（加工模式：快还是慢、自动还是费力）', 'dimension', 3),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.generation.automatic', '自动念头（fast/automatic，偏System 1）', 'category', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.generation.automatic.cue_trigger', '线索触发：看到皱眉→“不满意”', 'concept', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.generation.automatic.affect_driven', '情绪驱动解释：焦虑→“要出事”', 'concept', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.generation.automatic.habit_script', '习惯脚本：冲突→立刻讨好/回避', 'concept', 3),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.generation.controlled', '控制念头（slow/controlled，偏System 2）', 'category', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.generation.controlled.evidence_check', '证据核查： “我有哪些证据？”', 'concept', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.generation.controlled.alternative_explanation', '备选解释： “他可能只是累”', 'concept', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.generation.controlled.planning_simulation', '计划推演： “我下一步怎么沟通更好”', 'concept', 3),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.accessibility_attention', '4）意识可及性与注意（你能不能抓住它）', 'dimension', 4),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.accessibility_attention.focal', '焦点意识：当下清楚听见那句话', 'concept', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.accessibility_attention.background', '背景意识：隐隐在，但不成句', 'concept', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.accessibility_attention.preconscious', '前意识：稍微一留意就能说出来', 'concept', 3),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.accessibility_attention.implicit', '隐性加工：说不清，但身体/行为被推着走', 'concept', 4),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.time_perspective', '5）时间指向与视角（它站在哪个时间/谁的镜头）', 'dimension', 5),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.time_perspective.past_rumination', '过去：反刍/回放（“我当时怎么那样…”）', 'concept', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.time_perspective.present_appraisal', '现在：即时评估（“他这表情=…”）', 'concept', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.time_perspective.future_worry', '未来：担忧/预演（“等会肯定翻车”）', 'concept', 3),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.time_perspective.perspective_first_person', '视角：第一人称(我在经历)', 'concept', 4),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.time_perspective.perspective_observer', '视角：旁观者(我像被看)', 'concept', 5),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.content_domains', '6）内容领域（念头在谈什么主题）', 'dimension', 6),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.content_domains.safety_risk', '安全/风险（健康、钱、稳定、失控）', 'concept', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.content_domains.relationship_belonging', '关系/归属（被爱、被回应、被抛下）', 'concept', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.content_domains.status_evaluation', '地位/评价（面子、被看不起、比较）', 'concept', 3),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.content_domains.competence_achievement', '能力/成就（胜任、失败、完美主义）', 'concept', 4),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.content_domains.morality_fairness', '道德/公平（对错、边界、被侵犯）', 'concept', 5),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.content_domains.autonomy_control', '自主/控制（我能不能做主）', 'concept', 6),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.content_domains.meaning_value', '意义/价值（我活着为了什么、贡献/超越）', 'concept', 7),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.appraisal_dimensions', '7）情绪评估维度（Appraisal：科学里常用的“情绪生成变量”）', 'dimension', 7),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.appraisal_dimensions.novelty', '新奇性（novelty）： “突然发生/没预料”', 'concept', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.appraisal_dimensions.valence', '愉快度（valence）： “喜欢/讨厌”', 'concept', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.appraisal_dimensions.goal_relevance', '目标相关性（goal relevance）： “这对我重要”', 'concept', 3),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.appraisal_dimensions.goal_congruence', '目标一致性（goal congruence）： “顺/不顺我的目标”', 'concept', 4),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.appraisal_dimensions.certainty', '确定性（certainty）： “我不确定→焦虑上升”', 'concept', 5),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.appraisal_dimensions.controllability', '可控性（controllability）： “我能不能影响它”', 'concept', 6),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.appraisal_dimensions.agency', '责任归属（agency）： “是我/是他/是环境”', 'concept', 7),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.appraisal_dimensions.norm_compatibility', '规范一致性（norm compatibility）： “合不合规矩/道德”', 'concept', 8),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.appraisal_dimensions.coping_potential', '资源评估（coping potential）： “我扛不扛得住”', 'concept', 9),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.epistemic_stance', '8）认识论状态（Epistemic stance：我把它当事实还是假设）', 'dimension', 8),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.epistemic_stance.certain_belief', '确信信念： “他就是讨厌我”', 'concept', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.epistemic_stance.hypothetical_guess', '假设猜测： “也许他不舒服”', 'concept', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.epistemic_stance.doubt_uncertain', '怀疑/不确定： “我搞不清”', 'concept', 3),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.epistemic_stance.need_evidence', '需要证据： “我得确认一下”', 'concept', 4),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.epistemic_stance.value_stance', '价值立场： “我认为这样不该”', 'concept', 5),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.function_purpose', '9）功能目的（它想“帮你完成什么任务”）', 'dimension', 9),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.function_purpose.threat_alert', '威胁预警（保护安全）： “万一…”', 'concept', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.function_purpose.resource_organization', '资源组织（提高效率）： “列步骤/排优先级”', 'concept', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.function_purpose.social_navigation', '社会导航（维持关系/地位）： “他怎么看我”', 'concept', 3),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.function_purpose.self_protection', '自我保护（防羞耻/防否定）： “先否定自己免得被否定”', 'concept', 4),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.function_purpose.boundary_maintenance', '边界维护（公平与尊重）： “不能这样对我”', 'concept', 5),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.function_purpose.emotion_regulation', '情绪调节（安抚/麻木/宣泄）： “算了不想管”', 'concept', 6),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.distortions', '10）偏差与失真类型（Cognitive distortions：常见“思维误差”）', 'dimension', 10),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.distortions.catastrophizing', '灾难化： “完了”', 'concept', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.distortions.mind_reading', '读心术： “他肯定觉得我…”', 'concept', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.distortions.fortune_telling', '预言： “一定会失败”', 'concept', 3),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.distortions.labeling', '贴标签： “我就是废/他就是烂”', 'concept', 4),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.distortions.overgeneralization', '以偏概全： “总是/从来”', 'concept', 5),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.distortions.personalization', '个人化： “都怪我”', 'concept', 6),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.distortions.black_white', '非黑即白： “要么完美要么失败”', 'concept', 7),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.distortions.emotional_reasoning', '情绪化推理： “我感觉糟→事情一定糟”', 'concept', 8),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.policy', '11）行为策略输出（Policy：它最后让你倾向怎么做）', 'dimension', 11),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.policy.approach_communicate', '趋近/沟通：问清楚、尝试修复', 'concept', 1),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.policy.avoid_procrastinate', '回避/拖延：先躲开、不面对', 'concept', 2),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.policy.confront_argue', '对抗/争辩：攻击、反击', 'concept', 3),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.policy.please_explain', '讨好/解释：迎合、道歉、证明', 'concept', 4),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.policy.freeze_withdraw', '冻结/断联：僵住、撤退', 'concept', 5),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.policy.check_control', '检查/控制：反复确认、搜证据', 'concept', 6),

  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.surface_cues', '12）直观“表层语言线索”（一眼识别：它属于哪类）', 'dimension', 12),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.surface_cues.threat_words', '威胁词： “万一/要是/完了/糟了”', 'concept', 1, {'words': ['万一', '要是', '完了', '糟了']}),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.surface_cues.must_words', '必须词： “应该/必须/不能/得”', 'concept', 2, {'words': ['应该', '必须', '不能', '得']}),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.surface_cues.absolute_words', '绝对词： “总是/从来/一定”', 'concept', 3, {'words': ['总是', '从来', '一定']}),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.surface_cues.mindreading_words', '读心词： “他肯定/他就是觉得”', 'concept', 4, {'words': ['他肯定', '他就是觉得']}),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.surface_cues.identity_words', '身份词： “我就是…（没用/不配）”', 'concept', 5, {'words': ['我就是…（没用/不配）']}),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.surface_cues.fairness_words', '公平词： “凭什么/不应该”', 'concept', 6, {'words': ['凭什么', '不应该']}),
  ThoughtSeedNode('mind.cognition.phenomenology.thought_episode.surface_cues.withdrawal_words', '退缩词： “算了/不想了/随便”', 'concept', 7, {'words': ['算了', '不想了', '随便']}),
];
