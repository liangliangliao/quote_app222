import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/quote_insight.dart';
import 'cognitive_models.dart';
import 'cognitive_preferences.dart';
import 'cognitive_mode.dart';

/// Persisted inside the existing analysis text column; legacy text stays readable.
class MovieCognition {
  final String narrative, overview, boundary;
  final List<Map<String, String>> scenes;
  final List<CognitiveExample> analogies;
  final List<String> concepts, characters;
  const MovieCognition(
      {required this.narrative,
      required this.overview,
      required this.boundary,
      required this.scenes,
      required this.analogies,
      required this.concepts,
      required this.characters});

  static MovieCognition parse(String raw, String overview) {
    final m = insightObject(raw
        .trim()
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), ''));
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
        'status': excerpt.runes.length >= 2 && overview.contains(excerpt)
            ? 'provided_synopsis'
            : 'unverified_inference'
      });
    }
    final analysis = CognitiveAnalysis.fromJson(m, overview);
    return MovieCognition(
        narrative: narrative,
        overview: overview,
        boundary: boundary,
        scenes: scenes,
        analogies: analysis.examples,
        concepts: analysis.concepts,
        characters:
            (m['characters'] is List ? m['characters'] as List : const [])
                .whereType<String>()
                .where((s) => s.trim().isNotEmpty)
                .take(12)
                .toList());
  }

  String encode() => jsonEncode({
        'cognitive_movie_version': 1,
        'narrative': narrative,
        'overview': overview,
        'boundary': boundary,
        'scenes': scenes,
        'concepts': concepts,
        'characters': characters,
        'examples': analogies.map((e) => e.toJson()).toList()
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
只能逐字引用输入 overview 作为“所给简介材料”；它不等于已核对的影片事实。
没有提供的台词、镜头、人物行为只能标为未核实推测；不得补写为事实。
人物分析是解读而非心理诊断。现实例子必须标为模拟，解释它与电影的共同点、差异和失效条件。
只返回 JSON：{"narrative":"完整解读，区分材料与解释","boundary":"局限、未知和待核对的情节",
"scenes":[{"excerpt":"逐字摘自 overview 或空字符串","concept":"概念","interpretation":"暂定解释"}],
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SelectableText(body, style: const TextStyle(height: 1.6))
          ])));
  @override
  Widget build(BuildContext context) {
    CognitivePreferenceStore.instance.load();
    return ValueListenableBuilder<CognitivePreferences>(
        valueListenable: CognitivePreferenceStore.instance,
        builder: (context, _, __) => _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    final m = MovieCognition.decode(widget.text);
    final enabled = CognitivePreferenceStore.enabledInBuild &&
        CognitivePreferenceStore.instance.value.enabled;
    if (!enabled)
      return SelectableText(m?.narrative ?? widget.text,
          style: const TextStyle(fontSize: 14, height: 1.55));
    if (m == null)
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('AI 解读 · 未经外部核对'),
        const SizedBox(height: 8),
        SelectableText(m?.narrative ?? widget.text)
      ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('AI 暂定解读 · 简介材料、解释与模拟类比分开呈现'),
      Wrap(
          spacing: 6,
          children: ['情节', '概念', '人物', '现实关联']
              .asMap()
              .entries
              .map((e) => ChoiceChip(
                  label: Text(e.value),
                  selected: _tab == e.key,
                  onSelected: (_) => setState(() => _tab = e.key)))
              .toList()),
      if (_tab == 0) ...[
        _card('所给简介 · 尚未外部核对',
            m.overview.isEmpty ? '暂无情节材料，不据此补写镜头或台词。' : m.overview),
        ...m.scenes.map((s) => _card(
            s['status'] == 'provided_synopsis'
                ? '简介摘录 → ${s['concept']}'
                : '待核对推测 → ${s['concept']}',
            '${s['excerpt']}\n一种理解：${s['interpretation']}')),
        ExpansionTile(
            expansionAnimationStyle: cognitiveExpansionStyle(context),
            title: const Text('完整解读'),
            children: [SelectableText(m.narrative)]),
      ],
      if (_tab == 1) ...[
        Wrap(
            spacing: 6,
            children: m.concepts.map((c) => Chip(label: Text(c))).toList()),
        ...m.scenes.map((s) => _card(
            s['concept']!, '${s['interpretation']}\n返回情节：${s['excerpt']}')),
      ],
      if (_tab == 2) ...[
        if (m.characters.isEmpty) const Text('尚无有根据的人物分析。'),
        ...m.characters.map((c) => _card('人物理解 · 暂定', c))
      ],
      if (_tab == 3) ...[
        if (m.analogies.isEmpty) const Text('尚无可用的现实类比。'),
        ...m.analogies.map((e) => _card('模拟情境 · 非影片事实',
            '${e.situation}\n共同点：${e.connection}\n差异与局限：${e.boundary}'))
      ],
      _card('适用边界与未知', m.boundary),
    ]);
  }
}
