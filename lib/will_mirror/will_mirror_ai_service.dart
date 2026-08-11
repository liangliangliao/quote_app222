import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'will_mirror_models.dart';
import 'will_mirror_reasoning_engine.dart';
import 'will_mirror_vault.dart';

class WillMirrorAiService {
  WillMirrorAiService({
    UnifiedAiService? ai,
    WillMirrorReasoningEngine? engine,
    WillMirrorVault? vault,
  })  : _ai = ai ?? UnifiedAiService(),
        _engine = engine ?? WillMirrorReasoningEngine(),
        _vault = vault;

  final UnifiedAiService _ai;
  final WillMirrorReasoningEngine _engine;
  final WillMirrorVault? _vault;

  /// Calls the globally selected provider only after the UI has obtained an
  /// explicit, per-run user confirmation. The caller passes only already-linked
  /// evidence rather than the entire private vault.
  Future<WillMirrorGroundedInference> generateGrounded({
    required WillMirrorHypothesis hypothesis,
    required WillMirrorEvidenceMatrix matrix,
    required WillMirrorRetrievalBundle retrieval,
  }) async {
    final fallback = _engine.localInference(
      hypothesis: hypothesis,
      matrix: matrix,
      retrieval: retrieval,
    );
    final config = await _ai.resolveGlobalConfig();
    if (!config.available || retrieval.counter.isEmpty) return fallback;

    final allowedUserIds = <String>{
      ...matrix.supports.map((item) => item.id),
      ...matrix.counterevidence.map((item) => item.id),
      ...matrix.limits.map((item) => item.id),
    };
    final allowedKbIds = retrieval.all.map((item) => item.recordId).toSet();
    final promptPayload = <String, dynamic>{
      'hypothesis': hypothesis.toJson(),
      'current_local_matrix': <String, dynamic>{
        'confidence_band': matrix.band.value,
        'blocked_reasons': matrix.blockedReasons,
        'support': matrix.supports.map(_minimalEvidence).toList(),
        'counter': matrix.counterevidence.map(_minimalEvidence).toList(),
        'limits': matrix.limits.map(_minimalEvidence).toList(),
      },
      'kb_support': retrieval.support.map(_minimalPassage).toList(),
      'kb_counter': retrieval.counter.map(_minimalPassage).toList(),
      'kb_boundary': retrieval.boundary.map(_minimalPassage).toList(),
      'required_output_schema': <String, dynamic>{
        'conclusion': 'string',
        'support_evidence_ids': <String>[],
        'counter_evidence_ids': <String>[],
        'kb_passage_ids': <String>[],
        'confidence_band': <String>[
          'insufficient',
          'low',
          'medium',
          'high',
          'high_with_limits',
        ],
        'uncertainty': <String>[],
        'next_action': 'string',
        'guardrail': 'string',
      },
    };
    const systemPrompt = '''
你是《意志之镜》V4.0 的证据约束推理器。只输出一个 JSON 对象。

硬规则：
1. 严格区分作者原文/研究证据与 C 级产品推导，不得制造引文。
2. 只能引用输入中出现的 user evidence id 与 kb passage id。
3. 结论必须同时呈现支持、反证或情境限制；没有反证检索不得输出经验性格级结论。
4. 不得声称发现用户的物自身、本质、唯一真正需要、童年根因或心理诊断。
5. 不显示百分比人格结论，只能使用规定的 confidence_band。
6. 行动不足不能自动解释为没有欲望，必须保留资源、能力、责任和环境限制。
7. 输出必须包含不确定性、下一步现实检验以及“暂定模型”护栏。
''';

    try {
      final raw = await _ai.generateText(
        prompt: jsonEncode(promptPayload),
        purpose: 'will_mirror.v4.grounded_inference',
        systemPrompt: systemPrompt,
        maxTokens: 1800,
        expectJson: true,
        temperature: 0.1,
      );
      final decoded = _decodeObject(raw);
      if (decoded == null) return fallback;
      final supportIds = _strings(decoded['support_evidence_ids'])
          .where(allowedUserIds.contains)
          .toList(growable: false);
      final counterIds = _strings(decoded['counter_evidence_ids'])
          .where(allowedUserIds.contains)
          .toList(growable: false);
      final kbIds = _strings(decoded['kb_passage_ids'])
          .where(allowedKbIds.contains)
          .toList(growable: false);
      final citedCounterKb = retrieval.counter
          .any((item) => kbIds.contains(item.recordId));
      final conclusion = (decoded['conclusion'] ?? '').toString().trim();
      final nextAction = (decoded['next_action'] ?? '').toString().trim();
      if (conclusion.isEmpty ||
          nextAction.isEmpty ||
          supportIds.isEmpty ||
          kbIds.isEmpty ||
          !citedCounterKb) {
        return fallback;
      }
      var band = parseWillMirrorConfidenceBand(decoded['confidence_band']);
      if (!matrix.canPublishCharacterClaim || retrieval.counter.isEmpty) {
        band = WillMirrorConfidenceBand.insufficient;
      }
      var guardrail = (decoded['guardrail'] ?? '').toString().trim();
      if (!guardrail.contains('暂定') || !guardrail.contains('本质')) {
        guardrail = WillMirrorReasoningEngine.metaphysicalGuardrail;
      }
      final result = WillMirrorGroundedInference(
        conclusion: conclusion,
        supportEvidenceIds: supportIds,
        counterEvidenceIds: counterIds,
        kbPassageIds: kbIds,
        band: band,
        uncertainty: _strings(decoded['uncertainty']),
        nextAction: nextAction,
        guardrail: '$guardrail ${WillMirrorReasoningEngine.scopeGuardrail}',
        provider: config.provider,
        model: config.label,
      );
      await _vault?.saveInferenceRun(
        engine: 'will_pattern',
        input: promptPayload,
        output: result.toJson(),
        kbVersion: WillMirrorReasoningEngine.kbVersion,
        modelVersion: config.label,
        promptVersion: WillMirrorReasoningEngine.promptVersion,
      );
      return result;
    } catch (_) {
      return fallback;
    }
  }

  static Map<String, dynamic> _minimalEvidence(WillMirrorLifeEvidence item) {
    return <String, dynamic>{
      'id': item.id,
      'type': item.type.value,
      'title': item.title,
      'note': item.note,
      'life_stage': item.lifeStage,
      'domain': item.domain,
      'duration': item.duration,
      'cost_level': item.costLevel,
      'externally_requested': item.externallyRequested,
      'audience_present': item.audiencePresent,
    };
  }

  static Map<String, dynamic> _minimalPassage(
    WillMirrorKnowledgePassage item,
  ) {
    return <String, dynamic>{
      'passage_id': item.recordId,
      'source': '${item.creator} · ${item.workPart} ${item.sectionRef}',
      'evidence_level': item.evidenceLevel.value,
      'summary': item.summary,
      'product_rule': item.productRule,
      'misuse_boundary': item.misuseBoundary,
      'relations': item.relations.map((relation) => relation.value).toList(),
    };
  }

  static Map<String, dynamic>? _decodeObject(String raw) {
    var text = raw.trim();
    if (!text.startsWith('{')) {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      text = text.substring(start, end + 1);
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return null;
    }
  }

  static List<String> _strings(Object? value) => value is List
      ? value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
      : const <String>[];
}
