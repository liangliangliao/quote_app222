import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/quote_insight.dart';
import 'cognitive_models.dart';
import 'cognitive_preferences.dart';
import 'cognitive_mode.dart';
import 'concept_meaning_diagram.dart';

/// Persisted inside the existing analysis text column; legacy text stays readable.
class MovieCognition {
  final String narrative, overview, boundary;
  final CognitiveAnalysis? cognition;
  final List<Map<String, String>> scenes;
  final List<CognitiveExample> analogies;
  final List<String> concepts, characters;
  const MovieCognition({
    required this.narrative,
    required this.overview,
    required this.boundary,
    required this.scenes,
    required this.analogies,
    required this.concepts,
    required this.characters,
    this.cognition,
  });

  static MovieCognition parse(String raw, String overview,
      {bool requireDepth = false}) {
    final m = insightObject(
      raw
          .trim()
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), ''),
    );
    final narrative = insightText(m, 'narrative');
    final boundary = insightText(m, 'boundary');
    if (narrative.isEmpty || boundary.isEmpty) {
      throw const FormatException('电影分析缺少解读或边界，请重试');
    }
    final scenes = <Map<String, String>>[];
    for (final item in (m['scenes'] is List ? m['scenes'] as List : const [])) {
      final scene = insightObject(item);
      final excerpt = insightText(scene, 'excerpt');
      final interpretation = insightText(scene, 'interpretation');
      if (interpretation.isEmpty) continue;
      scenes.add({
        'excerpt': excerpt,
        'concept': insightText(scene, 'concept'),
        'interpretation': interpretation,
        for (final key in [
          'observed',
          'retained',
          'omitted',
          'judgment',
          'alternative',
          'test',
        ])
          key: insightText(scene, key),
        'status': excerpt.runes.length >= 2 && overview.contains(excerpt)
            ? 'provided_synopsis'
            : 'unverified_inference',
      });
    }
    final analysis = CognitiveAnalysis.fromJson(m, overview);
    if (requireDepth &&
        (analysis.abstractions.isEmpty ||
            scenes.where((s) => s['status'] == 'provided_synopsis').any((s) => [
                  'retained',
                  'judgment',
                  'alternative',
                  'test'
                ].any((k) => s[k]?.isNotEmpty != true)) ||
            analysis.abstractions.any((a) =>
                a.observed.isEmpty ||
                a.retained.isEmpty ||
                a.omitted.isEmpty ||
                a.counterExample.isEmpty) ||
            (overview.trim().isNotEmpty &&
                (scenes.isEmpty ||
                    scenes
                        .every((s) => s['status'] != 'provided_synopsis'))))) {
      throw const FormatException('电影分析缺少有材料支持的情节或概念抽象过程，请重新分析');
    }
    return MovieCognition(
      narrative: narrative,
      overview: overview,
      boundary: boundary,
      scenes: scenes,
      analogies: analysis.examples,
      cognition: analysis,
      concepts: analysis.concepts,
      characters: (m['characters'] is List ? m['characters'] as List : const [])
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .take(12)
          .toList(),
    );
  }

  String encode() => jsonEncode({
        'cognitive_movie_version': 1,
        'narrative': narrative,
        'overview': overview,
        'boundary': boundary,
        'scenes': scenes,
        'concepts': concepts,
        'characters': characters,
        'examples': analogies.map((e) => e.toJson()).toList(),
        'abstractions':
            cognition?.abstractions.map((a) => a.toJson()).toList() ?? [],
        'concept_scopes':
            cognition?.scopes.map((s) => s.toJson()).toList() ?? [],
      });
  static MovieCognition? decode(String raw) {
    final m = insightObject(raw);
    if (m['cognitive_movie_version'] != 1) return null;
    try {
      return parse(raw, insightText(m, 'overview'));
    } catch (_) {
      return null;
    }
  }

  static const instructions = '''请同时保留完整电影解读，并按情节→概念→现实类比组织。
分析不能只是长篇复述简介。narrative依次解释：影片呈现的问题、具体行为和情境、抽出的概念、在相似中辨认的决定性差异、人物判断的根据、可能反例、现实迁移的条件。缺少材料就保留未知，仍深入分析能支持的部分。
每个scenes条目补充observed（从摘录可描述的行为）、retained（抽象时保留的规定）、omitted（省略的个别处境）、judgment（有条件结论）、alternative（竞争解释）、test（何种材料能区分解释）。不得把“反抗”“希望”之类标签当分析。
同时返回abstractions:[{term,definition,observed,retained,omitted,counter_example}]。
concept_scopes仅在可定义同一论域的外延关系时提供[{relation_type,relation_scope:"extension",universe,set_a,set_b,criterion_a,criterion_b,basis,justification,intersection,only_a,only_b,illustration}]；类型仅equal/partition/siblings/overlap/subset/superset/disjoint，示意必须illustration:true，不适合则[]。
只能逐字引用输入 overview 作为“所给简介材料”；它不等于已核对的影片事实。
没有提供的台词、镜头、人物行为只能标为未核实推测；不得补写为事实。
人物分析是解读而非心理诊断。现实例子必须标为模拟，解释它与电影的共同点、差异和失效条件。
只返回 JSON：{"abstractions":[{"term":"关键概念","definition":"含义与边界","observed":"对应的简介材料或明确的模拟","retained":"抽出的共同规定","omitted":"省略的具体处境","counter_example":"非成员或反例"}],"concept_scopes":[],"narrative":"完整解读，区分材料与解释","boundary":"局限、未知和待核对的情节",
"scenes":[{"excerpt":"逐字摘自 overview 或空字符串","concept":"概念","interpretation":"暂定解释","observed":"摘录对应的具体行为或明确未知","retained":"抽出的共同规定","omitted":"省略的处境","judgment":"有条件判断","alternative":"其他可能解释","test":"可区分解释的观察"}],
"concepts":["概念"],"characters":["人物的暂定理解及其依据"],
"examples":[{"situation":"模拟现实情境","connection":"对应及共同点","boundary":"差异与失效条件"}]}''';
}

class MovieCognitionView extends StatefulWidget {
  final String text;
  const MovieCognitionView({super.key, required this.text});
  @override
  State<MovieCognitionView> createState() => _MovieCognitionViewState();
}

class _MovieCognitionViewState extends State<MovieCognitionView> {
  int _tab = 0;
  Widget _card(String title, String body) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SelectableText(body, style: const TextStyle(height: 1.6)),
            ],
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    CognitivePreferenceStore.instance.load();
    return ValueListenableBuilder<CognitivePreferences>(
      valueListenable: CognitivePreferenceStore.instance,
      builder: (context, _, __) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final m = MovieCognition.decode(widget.text);
    final enabled = CognitivePreferenceStore.enabledInBuild &&
        CognitivePreferenceStore.instance.value.enabled;
    if (!enabled)
      return SelectableText(
        m?.narrative ?? widget.text,
        style: const TextStyle(fontSize: 14, height: 1.55),
      );
    if (m == null)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI 解读 · 未经外部核对'),
          const SizedBox(height: 8),
          SelectableText(m?.narrative ?? widget.text),
        ],
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('AI 暂定解读 · 简介材料、解释与模拟类比分开呈现'),
        Wrap(
          spacing: 6,
          children: ['情节', '概念', '人物', '现实关联']
              .asMap()
              .entries
              .map(
                (e) => ChoiceChip(
                  selectedColor: const Color(0xffe9d8b9),
                  backgroundColor: const Color(0xfffffcf6),
                  side: const BorderSide(color: Color(0xffded4c5)),
                  label: Text(e.value),
                  selected: _tab == e.key,
                  onSelected: (_) => setState(() => _tab = e.key),
                ),
              )
              .toList(),
        ),
        if (_tab == 0) ...[
          _card(
            '所给简介 · 尚未外部核对',
            m.overview.isEmpty ? '暂无情节材料，不据此补写镜头或台词。' : m.overview,
          ),
          ...m.scenes.map(
            (s) => _card(
              s['status'] == 'provided_synopsis'
                  ? '简介摘录 → ${s['concept']}'
                  : '待核对推测 → ${s['concept']}',
              '${s['excerpt']}\n一种理解：${s['interpretation']}'
              '${s['retained']?.isNotEmpty == true ? '\n抽出的共同规定：${s['retained']}' : ''}'
              '${s['judgment']?.isNotEmpty == true ? '\n判断：${s['judgment']}' : ''}'
              '${s['alternative']?.isNotEmpty == true ? '\n其他解释：${s['alternative']}' : ''}'
              '${s['test']?.isNotEmpty == true ? '\n怎样检验：${s['test']}' : ''}',
            ),
          ),
          ExpansionTile(
            expansionAnimationStyle: cognitiveExpansionStyle(context),
            title: const Text('完整解读'),
            children: [SelectableText(m.narrative)],
          ),
        ],
        if (_tab == 1) ...[
          ConceptAnalysisView(
            abstractions: m.cognition?.abstractions ?? [],
            scopes: m.cognition?.scopes ?? [],
          ),
          Wrap(
            spacing: 6,
            children: m.concepts.map((c) => Chip(label: Text(c))).toList(),
          ),
          ...m.scenes.map(
            (s) => _card(
              s['concept']!,
              '${s['interpretation']}\n返回情节：${s['excerpt']}',
            ),
          ),
        ],
        if (_tab == 2) ...[
          if (m.characters.isEmpty) const Text('尚无有根据的人物分析。'),
          ...m.characters.map((c) => _card('人物理解 · 暂定', c)),
        ],
        if (_tab == 3) ...[
          if (m.analogies.isEmpty) const Text('尚无可用的现实类比。'),
          ...m.analogies.map(
            (e) => _card(
              '模拟情境 · 非影片事实',
              '${e.situation}\n共同点：${e.connection}\n差异与局限：${e.boundary}',
            ),
          ),
        ],
        _card('适用边界与未知', m.boundary),
      ],
    );
  }
}
