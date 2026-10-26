import 'self_os_engine.dart';
import 'self_os_models.dart';

const osRepresentationFormats = {
  'chain': '因果链',
  'timeline': '时间节点',
  'range': '数值范围',
  'scene': '场景变化',
  'counterfactual': '反事实比较',
};
const osRepresentationTasks = {
  'discomfort': '眼前不适与延迟后果',
  'reward': '即时奖励与累积成本',
  'conflict': '回避冲突与问题积累',
  'opportunity': '显著收益与机会成本',
  'abstract': '抽象目标与现实行动链',
  'repetition': '重复小行为的累积后果',
};
const osRepresentationWindows = {
  'now': '现在梳理',
  'evening': '提前准备',
  'before30': '行动前 30 分钟',
  'onsite': '行动现场',
};
const osRepresentationEffects = {
  'unknown': '未使用 / 还不能判断',
  'helped': '有帮助',
  'notHelped': '没有观察到帮助',
  'harmed': '产生反作用',
};

class OsRepresentationPattern {
  OsRepresentationPattern(this.format, this.task, this.window);
  final String format, task, window;
  final List<Map<String, dynamic>> observations = [];
  Iterable<Map<String, dynamic>> get attributable =>
      observations.where((o) => o['attribution'] == 'considered');
  Iterable<Map<String, dynamic>> get usable =>
      attributable.where((o) => o['understanding'] != 'unknown');
  int get total => usable.length;
  int get helped => usable.where((o) => o['understanding'] == 'helped').length;
  int get harmed => usable.where((o) => o['understanding'] == 'harmed').length;
  int get available =>
      attributable.where((o) => o['availability'] == 'helped').length;
  int get availabilityTotal =>
      attributable.where((o) => o['availability'] != 'unknown').length;
  int get acted => attributable.where((o) => o['action'] == 'helped').length;
  int get actionTotal =>
      attributable.where((o) => o['action'] != 'unknown').length;
  int get cases => usable.map((o) => o['caseId']).toSet().length;
  int get contexts => usable.map((o) => o['context']).toSet().length;
  // An explicit conservative product rule, not causal identification or an AI
  // probability. Other tasks/windows never silently supply missing samples.
  bool get eligible => total >= 3 && cases >= 2 && contexts >= 2;
  double get score => total == 0 ? 0 : (helped - harmed) / total;
  Map<String, dynamic> toJson() => {
        'format': format,
        'task': task,
        'window': window,
        'samples': total,
        'helpedUnderstanding': helped,
        'harmedUnderstanding': harmed,
        'helpedAvailability': available,
        'availabilitySamples': availabilityTotal,
        'helpedAction': acted,
        'actionSamples': actionTotal,
        'excludedOrUnknown': observations.length - total,
        'cases': cases,
        'contexts': contexts,
        'eligible': eligible,
        'observations': observations,
      };
}

/// Learns only from explicitly adopted expressions frozen BEFORE an action and
/// the user's observed effects AFTER it. AI suggestions and P2 changes are not
/// observations. The review is the source of truth, so edits/deletes need no
/// second cache and repeated saves cannot inflate sample counts.
class SelfOsRepresentationLearning {
  static Map<String, dynamic>? validateChoice(dynamic raw) {
    final r = osMap(raw);
    if (!osRepresentationFormats.containsKey(r['format']) ||
        !osRepresentationTasks.containsKey(r['task']) ||
        !osRepresentationWindows.containsKey(r['window'])) return null;
    return {
      'format': r['format'],
      'task': r['task'],
      'window': r['window'],
    };
  }

  static void adopt(SelfOsCase c,
      {required Map<String, dynamic> choice,
      required String content,
      required String source}) {
    final valid = validateChoice(choice);
    if (valid == null || content.trim().isEmpty || source.trim().isEmpty)
      throw const FormatException('请确认表达方式、问题结构、使用时点、内容与依据');
    if (c.reviewed || c.retrospective)
      throw const FormatException('行动后不能补写事前表达，请在下一轮尝试');
    c.beginCognition();
    final before = osClone(c.cognitiveSnapshot());
    c.fields['k2'] = content.trim();
    for (final key in ['format', 'task', 'window']) {
      c.fields['representation.$key'] = osText(valid[key]);
    }
    final uses = osMaps(c.v37.settings['representationUses'])
        .where((u) => u['round'] == c.round)
        .toList();
    final previous = uses
        .where((u) =>
            u['format'] == valid['format'] &&
            u['task'] == valid['task'] &&
            u['window'] == valid['window'])
        .firstOrNull;
    if (previous != null) uses.remove(previous);
    uses.add({
      ...valid,
      'id': previous?['id'] ?? selfOsId(),
      'round': c.round,
      'content': content.trim(),
      'source': source,
      'before': previous?['before'] ?? before,
      'after': osClone(c.cognitiveSnapshot()),
      'recordedAt': DateTime.now().toIso8601String(),
    });
    c.v37.settings['representationUses'] = uses;
  }

  static List<Map<String, dynamic>> uses(Map<String, dynamic> snapshot) {
    if (snapshot['committedAt'] == null) return [];
    final settings = osMap(osMap(snapshot['v37'])['settings']);
    final seen = <String>{};
    return osMaps(settings['representationUses']).where((u) {
      final id = osText(u['id']);
      return u['round'] == snapshot['round'] &&
          validateChoice(u) != null &&
          id.isNotEmpty &&
          osText(u['content']).isNotEmpty &&
          seen.add(id);
    }).toList();
  }

  static void saveFeedback(SelfOsReview review, Map<String, String> notes) {
    final accepted = <String, String>{};
    for (final use in uses(review.snapshot)) {
      final prefix = 'representation.${use['id']}';
      final effects = <String, String>{};
      for (final dimension in ['understanding', 'availability', 'action']) {
        final effect = notes['$prefix.$dimension'] ?? 'unknown';
        if (!osRepresentationEffects.containsKey(effect))
          throw const FormatException('请选择有效的实际作用，无法判断时保持未知');
        effects[dimension] = effect;
      }
      final observation = (notes['$prefix.observation'] ?? '').trim();
      final attribution = notes['$prefix.attribution'] ?? 'unknown';
      final conditions = (notes['$prefix.conditions'] ?? '').trim();
      if (!['unknown', 'contextOnly', 'considered'].contains(attribution))
        throw const FormatException('请确认其他条件的影响');
      if (effects.values.any((v) => v != 'unknown') && observation.isEmpty)
        throw const FormatException('请记录实际观察，不能仅根据行动成败推断表达有效');
      if (attribution == 'considered' && conditions.isEmpty)
        throw const FormatException('请说明知识、环境、身体状态等其他变化及适用范围');
      for (final e in effects.entries) {
        accepted['$prefix.${e.key}'] = e.value;
      }
      accepted.addAll({
        '$prefix.observation': observation,
        '$prefix.attribution': attribution,
        '$prefix.conditions': conditions,
      });
    }
    // Validate the complete form first; a rejected row never partially writes.
    review.notes.addAll(accepted);
  }

  static List<OsRepresentationPattern> patterns(List<SelfOsCase> history) {
    final groups = <String, OsRepresentationPattern>{};
    for (final o in SelfOsEngineService.observations(history)) {
      final review = o.review;
      final seen = <String>{};
      for (final use in uses(review.snapshot)) {
        final key = '${use['format']}.${use['task']}.${use['window']}';
        // One actual review contributes at most one sample to a comparison.
        if (!seen.add(key)) continue;
        final prefix = 'representation.${use['id']}';
        final observation = review.notes['$prefix.observation']?.trim() ?? '';
        final conditions = review.notes['$prefix.conditions']?.trim() ?? '';
        String effect(String dimension) {
          final v = review.notes['$prefix.$dimension'];
          return observation.isNotEmpty &&
                  osRepresentationEffects.containsKey(v)
              ? v!
              : 'unknown';
        }

        groups
            .putIfAbsent(
                key,
                () => OsRepresentationPattern(
                    use['format'], use['task'], use['window']))
            .observations
            .add({
          'caseId': o.caseId,
          'reviewId': review.id,
          'useId': use['id'],
          'context': review.context,
          'recordedAt': review.createdAt.toIso8601String(),
          'understanding': effect('understanding'),
          'availability': effect('availability'),
          'action': effect('action'),
          'attribution': conditions.isNotEmpty
              ? review.notes['$prefix.attribution'] ?? 'unknown'
              : 'unknown',
          'observation': observation,
          'conditions': conditions,
        });
      }
    }
    return groups.values.toList()
      ..sort((a, b) {
        final effect = b.score.compareTo(a.score);
        if (effect != 0) return effect;
        final count = b.total.compareTo(a.total);
        return count != 0 ? count : a.format.compareTo(b.format);
      });
  }

  static OsRepresentationPattern? recommend(
          List<SelfOsCase> history, String task, String window) =>
      patterns(history)
          .where((p) =>
              p.task == task && p.window == window && p.eligible && p.score > 0)
          .firstOrNull;

  static Map<String, dynamic> context(SelfOsCase c, List<SelfOsCase> history) {
    final task = c.text('representation.task');
    final window = c.text('representation.window');
    final recommended = recommend(history, task, window);
    return {
      'selection': {
        'format': c.text('representation.format'),
        'task': task,
        'window': window,
      },
      'recommendedFormat': recommended?.format,
      'recommendationBasis':
          '同类问题和时点，至少3条实际复盘、2个案例和2种情境；按理解帮助减反作用排序。自报关联，不是因果证明。',
      'patterns': patterns(history)
          .where((p) =>
              (task.isEmpty || p.task == task) &&
              (window.isEmpty || p.window == window))
          .take(30)
          .map((p) =>
              {...p.toJson(), 'observations': p.observations.take(12).toList()})
          .toList(),
      'insufficientEvidence': recommended == null,
    };
  }
}
