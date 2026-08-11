import 'dart:convert';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'zhixing_engines.dart';
import 'zhixing_knowledge_repository.dart';
import 'zhixing_models.dart';
import 'zhixing_prompt_config.dart';

class ZxAiService {
  final UnifiedAiService _ai = UnifiedAiService();
  final GlobalAiSettings _settings = GlobalAiSettings();
  final ZxPromptConfig _prompts = ZxPromptConfig();
  final ZxActionGenerator _validator = const ZxActionGenerator();

  Future<Map<String, String>> providerState() => _settings.getState();

  /// AI is optional and may only improve wording. The local prescription is
  /// returned unchanged whenever the provider is unavailable or validation
  /// fails.
  Future<ZxActionPrescription> enhanceAction({
    required ZxActionPrescription local,
    required ZxSituationInput input,
    required ZxDiagnosisResult diagnosis,
    required ZxMatchResult match,
    required ZxKnowledgeRepository knowledge,
  }) async {
    if (!diagnosis.safety.actionAllowed) return local;
    final provider = await providerState();
    if (provider['available'] != '1') return local;
    final systemPrompt = await _prompts.actionPrompt();
    final evidence = local.evidenceLocators
        .map(knowledge.evidenceByLocator)
        .whereType<ZxEvidenceItem>()
        .map(
          (item) => <String, String>{
            'locator': item.locator,
            'summary': item.summary,
            'boundary': item.boundary,
          },
        )
        .toList(growable: false);
    final payload = <String, Object?>{
      'safety': diagnosis.safety.toJson(),
      'diagnosis': diagnosis.toJson(),
      'primary_lens': <String, Object?>{
        'lens_id': match.primary.id,
        'thinker': match.primary.thinker,
        'name': match.primary.name,
        'mechanism': match.primary.mechanism,
        'methods': match.primary.methods,
        'contraindications': match.primary.contraindications,
        'evidence_links': match.primary.evidenceLinks,
      },
      'local_prescription': local.toJson(),
      'user_context': input.toJson(),
      'evidence': evidence,
    };
    try {
      final raw = await _ai.generateText(
        prompt: jsonEncode(payload),
        purpose: 'zhixing_tree.action_wording',
        systemPrompt: systemPrompt,
        maxTokens: 900,
        expectJson: true,
        temperature: 0.2,
      );
      final map = _parseObject(raw);
      if (map == null) return local;
      final main = (map['main_action'] ?? '').toString().trim();
      final lower =
          (map['lower_load_alternative'] ?? '').toString().trim();
      final challenge =
          (map['challenge_alternative'] ?? '').toString().trim();
      if (main.isEmpty) return local;
      final candidate = local.copyWith(
        mainAction: main,
        lowerLoadAlternative:
            lower.isEmpty ? local.lowerLoadAlternative : lower,
        challengeAlternative:
            challenge.isEmpty ? local.challengeAlternative : challenge,
      );
      final invalidLocators = candidate.evidenceLocators
          .where((locator) => knowledge.evidenceByLocator(locator) == null)
          .toList();
      if (invalidLocators.isNotEmpty || _validator.validate(candidate).isNotEmpty) {
        return local;
      }
      return candidate;
    } catch (_) {
      return local;
    }
  }

  Future<ZxCandidateLens?> proposeExpansion({
    required String gap,
    required String userContext,
  }) async {
    final provider = await providerState();
    if (provider['available'] != '1') return null;
    try {
      final raw = await _ai.generateText(
        prompt: jsonEncode(<String, String>{
          'knowledge_gap': gap.trim(),
          'user_context': userContext.trim(),
        }),
        purpose: 'zhixing_tree.expansion_candidate',
        systemPrompt: await _prompts.expansionPrompt(),
        maxTokens: 900,
        expectJson: true,
        temperature: 0.15,
      );
      final map = _parseObject(raw);
      if (map == null) return null;
      final concept = (map['concept'] ?? '').toString().trim();
      if (concept.isEmpty) return null;
      return ZxCandidateLens(
        gap: (map['gap'] ?? gap).toString(),
        concept: concept,
        thinker: (map['thinker'] ?? '').toString(),
        work: (map['work'] ?? '').toString(),
        sourceUri: (map['source_uri'] ?? '').toString(),
        addedValue: (map['added_value'] ?? '').toString(),
        risks: (map['risks'] ?? '尚未人工审阅，禁止进入核心规则。').toString(),
        status: 'candidate',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _parseObject(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}
