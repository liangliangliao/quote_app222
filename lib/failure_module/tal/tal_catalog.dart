import 'dart:convert';
import 'package:flutter/services.dart';

class TalMethod {
  TalMethod(Map<String, dynamic> data) : data = Map.unmodifiable(data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get name => data['name'] as String;
  String get exercise => data['exercise'] as String;
  String get limit => data['limit'] as String;
  List<String> get sources => List<String>.from(data['source_ids'] as List);
  String get provenance => switch (data['provenance']) {
        '课堂理论' => 'tal_lecture',
        '本人访谈' => 'tal_autobiography',
        // SPIRE is a book framework. Turning it into this app's conditions check
        // must not be presented as a named original exercise.
        '著作理论' => 'product_extension',
        _ => 'tal_original_exercise',
      };
  String get attribution => '${data['provenance']} · ${sources.join(' / ')}';
}

class TalCatalog {
  static const approvedMethodIds = {
    'prp',
    'explore_failures',
    'learn_to_fail',
    'permission_to_be_human',
    'three_ms',
    'benefit_finding',
    'unbundling',
    'abc_change',
    'stretch_zone',
    'five_minute_takeoff',
    'creating_rituals',
    'three_rs',
    'mvi',
    'spire',
    'trial_error',
  };
  TalCatalog.fromJson(
      Map<String, dynamic> catalog, Map<String, dynamic> routing)
      : methods = {
          for (final m in catalog['methods'] as List)
            (m as Map)['id'] as String: TalMethod(Map<String, dynamic>.from(m))
        },
        sources = Map<String, dynamic>.from(catalog['sources'] as Map),
        cases = (catalog['cases'] as List)
            .map((e) => Map<String, dynamic>.unmodifiable(e as Map))
            .toList(),
        rules = (routing['rules'] as List)
            .map((e) => Map<String, dynamic>.unmodifiable(e as Map))
            .toList();
  final Map<String, TalMethod> methods;
  final Map<String, dynamic> sources;
  final List<Map<String, dynamic>> cases, rules;

  static TalCatalog? _cached;
  static Future<TalCatalog> load() async {
    if (_cached != null) return _cached!;
    final data = await Future.wait([
      rootBundle
          .loadString('assets/failure_module/tal/method_case_catalog.json'),
      rootBundle.loadString('assets/failure_module/tal/routing_rules.json'),
    ]);
    final catalog = TalCatalog.fromJson(
        jsonDecode(data[0]) as Map<String, dynamic>,
        jsonDecode(data[1]) as Map<String, dynamic>);
    _cached = catalog;
    return catalog;
  }

  List<Map<String, dynamic>> storiesFor(String? methodId) {
    const preferred = ['C18', 'C01', 'C05', 'C06', 'C09', 'C11', 'C12'];
    final stories = cases
        .where((c) =>
            methodId == null ||
            (c['mapped_method_ids'] as List).contains(methodId))
        .toList();
    int rank(Map<String, dynamic> c) {
      final i = preferred.indexOf(c['id'] as String);
      return i < 0 ? 99 : i;
    }

    stories.sort((a, b) => rank(a).compareTo(rank(b)));
    return stories;
  }
}

class TalRecommendation {
  const TalRecommendation(this.method, this.basis);
  final TalMethod method;
  final List<String> basis;
  String get uncertainty => '这是依据你选择的情况提出的候选方法，尚不能确定原因或效果。';
  String get whenToSwitch => '不适用、你不愿继续，或实测没有帮助时，可以拒绝、调整或换方法。';
}

class TalRoute {
  const TalRoute(this.route, this.methods, {this.offlineOnly = true});
  final String route;
  final List<TalRecommendation> methods;
  final bool offlineOnly;
}

/// Product rules operate only on user-confirmed signals, not inferred motives.
class TalRouter {
  const TalRouter(this.catalog);
  final TalCatalog catalog;

  /// Narrow literal matches supply visible user quotations, never hidden causes.
  /// Safety / physical readiness / benefit-finding consent still require a choice.
  static Map<String, String> observedSignals(String text) {
    final patterns = <String, RegExp>{
      'catastrophizing':
          RegExp(r'一辈子.{0,12}(没希望|没用|失败|完了)|永远.{0,8}(失败|没希望)|一无是处'),
      'self_condemnation': RegExp(r'我.{0,4}(真没用|是废物|是失败者)|责怪自己|很自责|很羞耻'),
      'fatigue_or_sleep_concern': RegExp(r'睡眠不足|没睡够|很疲劳|很累|有点困|很困'),
      'overloaded': RegExp(r'任务太多|事情太多|承担太多|负担过重|过载'),
      'prior_method_not_helped': RegExp(
          r'(五分钟法|五分鐘法|5分钟法).{0,25}(没用|没有用|无效|没帮助|没有帮助)|先前的方法.{0,12}(没用|无效|没有帮助)'),
      'cannot_repeat': RegExp(r'难以持续|很难坚持|难以坚持|偶尔能做|经常忘记'),
      'valued_positive_trait_linked_to_negative_trait':
          RegExp(r'(怕|担心).{0,8}失去.{0,12}(责任心|雄心|认真|竞争力|品质)'),
      'goal_no_longer_fits': RegExp(r'目标不合适|目标已不适合|我决定退出目标|这份工作不适合'),
    };
    final result = <String, String>{};
    for (final sentence in text.split(RegExp(r'[。！？\n]'))) {
      if (RegExp(r'不是|并不|不觉得|不认为|没有说').hasMatch(sentence)) continue;
      for (final e in patterns.entries) {
        final match = e.value.firstMatch(sentence);
        if (match != null) result.putIfAbsent(e.key, () => match.group(0)!);
      }
    }
    return result;
  }

  TalRoute route(Set<String> signals,
      {Set<String> rejected = const {}, Set<String> notHelped = const {}}) {
    final offline = !signals.contains('consented_ai');
    if (signals.contains('crisis_warning'))
      return const TalRoute('safety_exit', []);
    if (signals.contains('kindling_aborted') ||
        signals.contains('no_confirmed_missed')) {
      return TalRoute('do_not_trigger_failure', [], offlineOnly: offline);
    }
    if (signals.contains('goal_no_longer_fits') ||
        signals.contains('rational_decline')) {
      return TalRoute('review_goal_no_failure_label', [], offlineOnly: offline);
    }
    final rules = [...catalog.rules]
      ..sort((a, b) => (b['priority'] as int).compareTo(a['priority'] as int));
    final result = <TalRecommendation>[];
    bool allowed(String id) {
      if (rejected.contains(id)) return false;
      if (notHelped.contains(id) && !signals.contains('user_asks_to_retry'))
        return false;
      if (id == 'five_minute_takeoff' &&
          (signals.contains('prior_method_not_helped') &&
                  !signals.contains('user_asks_to_retry') ||
              signals.contains('fatigue_or_sleep_concern') ||
              signals.contains('overloaded'))) return false;
      if ((id == 'learn_to_fail' || id == 'stretch_zone') &&
          !signals.contains('challenge_is_safe')) return false;
      return true;
    }

    for (final rule in rules) {
      final all = List<String>.from(rule['if_all'] as List? ?? []);
      final any = List<String>.from(rule['if_any'] as List? ?? []);
      if (all.any((s) => !signals.contains(s)) ||
          any.isNotEmpty && !any.any(signals.contains)) continue;
      for (final id in List<String>.from(rule['suggest'] as List)) {
        final method = catalog.methods[id];
        if (method == null ||
            !allowed(id) ||
            result.any((r) => r.method.id == id)) continue;
        result.add(TalRecommendation(
            method, [...all, ...any.where(signals.contains)]));
        if (result.length == 2)
          return TalRoute('suggest', result, offlineOnly: offline);
      }
    }
    if (result.isEmpty && allowed('explore_failures')) {
      result.add(TalRecommendation(
          catalog.methods['explore_failures']!, const ['可选择记录，也可以不分析；原因尚不清楚']));
    }
    return TalRoute('suggest', result, offlineOnly: offline);
  }
}
