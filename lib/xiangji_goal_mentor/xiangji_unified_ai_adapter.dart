import '../services/unified_ai_service.dart';
import 'xiangji_grounded_ai_service.dart';
import 'xiangji_provider_mirror_service.dart';

/// Keeps Xiangji's reusable grounding core independent from the host app's AI
/// and background-plugin graph. The production page injects this adapter at
/// the composition boundary.
class XiangjiUnifiedAiAdapter {
  XiangjiUnifiedAiAdapter({UnifiedAiService? service})
      : _service = service ?? UnifiedAiService();

  final UnifiedAiService _service;

  Future<XiangjiOpenAiConfig> resolveOpenAiConfig() async {
    final resolved = await _service.resolveGlobalConfig(
      forcedProvider: 'openai',
    );
    if (!resolved.available || resolved.apiKey.trim().isEmpty) {
      throw StateError('请先在全局 AI 设置中配置 OpenAI API Key。');
    }
    final endpoint = Uri.tryParse(resolved.endpoint);
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host != 'api.openai.com') {
      throw StateError('首发远端书库只允许 OpenAI 官方 API 端点。');
    }
    var path = endpoint.path;
    for (final suffix in const <String>['/responses', '/chat/completions']) {
      if (path.endsWith(suffix)) {
        path = path.substring(0, path.length - suffix.length);
      }
    }
    if (path.isEmpty) path = '/v1';
    final apiBase = Uri(
      scheme: endpoint.scheme,
      host: endpoint.host,
      port: endpoint.hasPort ? endpoint.port : null,
      path: path,
    ).toString();
    return XiangjiOpenAiConfig(
      apiKey: resolved.apiKey,
      model: resolved.model,
      apiBase: apiBase,
    );
  }

  Future<XiangjiGeneratedText> generate({
    required String systemPrompt,
    required String prompt,
    String? forcedProvider,
  }) async {
    final config = await _service.resolveGlobalConfig(
      forcedProvider: forcedProvider,
    );
    if (!config.available) {
      return const XiangjiGeneratedText(
        text: '',
        provider: 'local',
        modelLabel: '本地检索',
      );
    }
    final result = await _service.generateText(
      prompt: prompt,
      purpose: 'xiangji_goal_mentor.grounded_guidance',
      systemPrompt: systemPrompt,
      maxTokens: 1500,
      expectJson: true,
      forcedProvider: forcedProvider,
      temperature: 0.1,
    );
    return XiangjiGeneratedText(
      text: result,
      provider: config.provider,
      modelLabel: config.label,
    );
  }
}
