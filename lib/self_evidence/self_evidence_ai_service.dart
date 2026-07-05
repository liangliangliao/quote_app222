import '../services/unified_ai_service.dart';
import 'self_evidence_prompt_config.dart';

class SelfEvidenceCoachResult {
  final String markdown;
  final bool usedAi;
  final String raw;

  const SelfEvidenceCoachResult({required this.markdown, required this.usedAi, required this.raw});
}

class SelfEvidenceAiService {
  final UnifiedAiService _ai = UnifiedAiService();
  final SelfEvidencePromptConfig _promptConfig = SelfEvidencePromptConfig();

  Future<SelfEvidenceCoachResult> generate({required String userInput, required String scene, String profileJson = '{}', String recentContextJson = '{}', required String fallback}) async {
    final prompt = await _promptConfig.buildPrompt(scene: scene, userInput: userInput, profileJson: profileJson, recentContextJson: recentContextJson);
    final systemPrompt = await _promptConfig.getPrompt(SelfEvidencePromptConfig.globalId);
    try {
      final raw = await _ai.generateText(prompt: prompt, purpose: 'self_evidence.generate_coach', systemPrompt: systemPrompt, maxTokens: 2600, expectJson: false, temperature: 0.35);
      final text = raw.trim();
      if (text.isNotEmpty) return SelfEvidenceCoachResult(markdown: text, usedAi: true, raw: raw);
    } catch (_) {}
    return SelfEvidenceCoachResult(markdown: fallback, usedAi: false, raw: fallback);
  }
}
