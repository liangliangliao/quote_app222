import 'evidence_growth_journey_models.dart';
import 'evidence_growth_models.dart';
import 'evidence_growth_search.dart';

/// Shared by mobile and API. Retrieval is a proposal, never evidence of use.
class EvidenceGrowthKnowledgeRuntime {
  static const stages = [
    'BELIEF',
    'GOAL',
    'ACTION',
    'OUTCOME',
    'REVIEW',
    'CHANGE'
  ];
  static const lessons = <String, List<String>>{
    'BELIEF': ['区分事实与解释，形成可以被现实修正的判断。', '什么是你观察到的，什么只是推测？什么证据会改变判断？'],
    'GOAL': ['把信念连接到真正重视的方向、可观察标准和边界。', '为什么值得做？怎样知道有进展？哪些代价不能接受？'],
    'ACTION': ['把知识方法变成可执行、可撤回的小练习。', '何时、在什么情境做哪一步？预计观察到什么？'],
    'OUTCOME': ['接纳不完美，记录成功、失败、未做和意外的真实反馈。', '实际发生了什么？情绪和事实能否分开记录？'],
    'REVIEW': ['用知识比较预测与结果，区分可重复条件和偶然。', '哪条依据支持解释？还有什么解释？样本是否足够？'],
    'CHANGE': ['将学习落实为下一轮的一处改变，并校准原信念。', '保留什么、改变什么？下一轮用什么信号检验？'],
  };
  static String stage(String value) {
    if (value == 'FAILURE') return 'OUTCOME';
    if (value == 'BELIEF_CHECKPOINT') return 'BELIEF';
    if (value.endsWith('_GATE')) return 'GOAL';
    if (!stages.contains(value)) throw ArgumentError('未知学习节点');
    return value;
  }

  static GrowthModule module(String value) =>
      GrowthModuleX.parse(stage(value) == 'OUTCOME' ? 'FAILURE' : stage(value));
  static GrowthData context(GrowthJourney j, String at,
          {String question = '', GrowthData input = const {}}) =>
      {
        'stage': stage(at),
        'question': question,
        'goal': j.title,
        'current_facts': j.data['current'],
        'belief': j.data['belief'],
        'criterion': j.contract['criterion'],
        'boundary': j.contract['quality'],
        'latest_input': j.data['pending_entry'],
        'outcome': j.data['outcome'],
        'learning': j.data['learning'],
        'next_change': j.data['next_change'],
        'strategy': j.plan['strategy'],
        'readiness': j.data['readiness'],
        'input': input,
      };
  static String query(GrowthData data) {
    Iterable<String> values(Object? v) sync* {
      if (v is String && v.trim().isNotEmpty) yield v;
      if (v is Map) {
        for (final e in v.entries) {
          if (!const ['stage', 'readiness'].contains(e.key))
            yield* values(e.value);
        }
      }
      if (v is List) {
        for (final item in v) {
          yield* values(item);
        }
      }
    }

    return values(data).join(' ');
  }

  static List<EvidenceKNode> retrieve(String at, String text,
      {int limit = 16}) {
    final preferred = module(at);
    final found = EvidenceGrowthSearch.current.search(text, limit: 80);
    found.sort((a, b) => (b.score * (b.node.module == preferred ? 1.12 : 1))
        .compareTo(a.score * (a.node.module == preferred ? 1.12 : 1)));
    return found.take(limit).map((e) => e.node).toList();
  }

  static List<GrowthData> applications(GrowthJourney j, String at) =>
      growthRows(j.data['knowledge_applications'])
          .where((a) =>
              a['stage'] == stage(at) &&
              a['effective_cycle'] == j.cycle &&
              a['state'] != 'WITHDRAWN')
          .toList();
  static List<EvidenceKNode> appliedNodes(GrowthJourney j, String at) =>
      applications(j, at)
          .map((a) => EvidenceKNode.fromJson(growthMap(a['snapshot'])))
          .toList();
  static List<EvidenceKNode> evidence(GrowthJourney j, String at,
      {GrowthData input = const {}}) {
    final applied = appliedNodes(j, at);
    return applied.isNotEmpty
        ? applied
        : retrieve(at, query(context(j, at, input: input)))
            .where((n) => n.isTal)
            .take(3)
            .toList();
  }

  static GrowthData brief(EvidenceKNode n) => {
        'id': n.id,
        'module': n.module.key,
        'source_class': n.sourceClass,
        'claim': n.claim,
        'mechanism': n.mechanism,
        'triggers': n.triggers,
        'prerequisites': n.prerequisites,
        'contra_signals': n.contraSignals,
        'misuse_boundary': n.misuseBoundary,
      };
}
