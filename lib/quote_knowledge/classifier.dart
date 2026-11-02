import '../services/unified_ai_service.dart';
import 'batch_request.dart';
import 'models.dart';

class ClassificationUnavailable implements Exception {}

class QuoteKnowledgeClassifier {
  final UnifiedAiService ai;
  QuoteKnowledgeClassifier({UnifiedAiService? ai})
      : ai = ai ?? UnifiedAiService();
  Future<QuoteClassification> classify(
      Map<String, dynamic> quote, List<QuoteCategory> candidates) async {
    final result = await classifyBatch(BatchClassificationRequest(
        [ClassificationClaim('single', '', knowledgeInputHash(quote), quote)],
        candidates));
    return result['single'] ?? (throw const FormatException('归类未返回对应原文的依据'));
  }

  Future<Map<String, QuoteClassification>> classifyBatch(
      BatchClassificationRequest request) async {
    final prompt = request.prompt;
    final config = await ai.resolveGlobalConfig();
    if (!config.available) throw ClassificationUnavailable();
    final response = await ai
        .generateText(
            purpose: 'quote_knowledge.batch.v2',
            expectJson: true,
            maxTokens: request.outputLimit,
            temperature: .1,
            forcedProvider: config.provider,
            forcedModel: config.model,
            prompt: prompt)
        .timeout(const Duration(seconds: 110));
    return request.parse(response);
  }

  static String buildPrompt(
          Map<String, dynamic> quote, List<QuoteCategory> candidates) =>
      BatchClassificationRequest([
        ClassificationClaim('single', '', knowledgeInputHash(quote), quote)
      ], candidates)
          .prompt;
}
