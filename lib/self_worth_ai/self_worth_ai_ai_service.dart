import '../services/unified_ai_service.dart';
import 'self_worth_ai_engine.dart';
import 'self_worth_ai_prompt_config.dart';

class SelfWorthAiCoachResult {
  final String markdown;
  final String scene;
  final String outputMode;
  final bool usedAi;
  final String raw;

  const SelfWorthAiCoachResult({
    required this.markdown,
    required this.scene,
    required this.outputMode,
    required this.usedAi,
    required this.raw,
  });
}

class SelfWorthAiService {
  final UnifiedAiService _ai = UnifiedAiService();
  final SelfWorthAiPromptConfig _promptConfig = SelfWorthAiPromptConfig();
  final SelfWorthAiEngine _engine = const SelfWorthAiEngine();

  Future<SelfWorthAiCoachResult> generate({
    required String userInput,
    required String scene,
    String profileJson = '{}',
    String recentContextJson = '{}',
    SelfWorthFeatureSpec? feature,
  }) async {
    final cleanInput = userInput.trim();
    final effectiveScene = scene.trim().isEmpty ? 'external_validation' : scene.trim();
    final outputMode = _engine.outputModeForScene(effectiveScene);
    final prompt = await _promptConfig.buildPrompt(
      scene: effectiveScene,
      userInput: cleanInput,
      profileJson: profileJson,
      recentContextJson: recentContextJson,
      outputMode: outputMode,
    );
    final systemPrompt = await _promptConfig.getPrompt(SelfWorthAiPromptConfig.globalId);
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'self_worth_ai.generate_action_card',
        systemPrompt: systemPrompt,
        maxTokens: 2400,
        expectJson: false,
        temperature: 0.35,
      );
      final text = raw.trim();
      if (text.isNotEmpty) {
        return SelfWorthAiCoachResult(
          markdown: text,
          scene: effectiveScene,
          outputMode: outputMode,
          usedAi: true,
          raw: raw,
        );
      }
    } catch (_) {}
    final fallback = _engine.localActionCard(scene: effectiveScene, userInput: cleanInput, feature: feature);
    return SelfWorthAiCoachResult(
      markdown: fallback,
      scene: effectiveScene,
      outputMode: outputMode,
      usedAi: false,
      raw: fallback,
    );
  }
}
