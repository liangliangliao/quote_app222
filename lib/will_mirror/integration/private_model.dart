import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/unified_ai_service.dart';
import '../ai/protocol.dart';
import '../domain/model.dart';

/// Reuses the user's host provider configuration, but deliberately does not use
/// the host's content-logging generation methods for private case records.
class HostPrivateModel implements StructuredModel {
  HostPrivateModel(
      {UnifiedAiService? host, http.Client Function()? clientFactory})
      : host = host ?? UnifiedAiService(),
        clientFactory = clientFactory ?? http.Client.new;
  final UnifiedAiService host;
  final http.Client Function() clientFactory;
  UnifiedAiResolvedConfig? _runConfig;
  @override
  Future<bool> available() async {
    _runConfig = await host.resolveGlobalConfig();
    return _runConfig!.available;
  }

  @override
  Future<String> label() async {
    final config = await host.resolveGlobalConfig();
    return config.available
        ? '${config.label} · ${config.displayModel}'
        : '尚未配置 AI 服务';
  }

  @override
  Future<Json> complete(
      {required AnalysisStage stage,
      required String system,
      required String prompt,
      required Json schema,
      required CancelToken cancel}) async {
    cancel.check();
    final config = _runConfig ?? await host.resolveGlobalConfig();
    if (!config.available)
      throw const MirrorProblem('请先在宿主 AI 设置中配置服务，已保存的课题可离线继续记录');
    final candidates =
        config.provider == 'azure' && config.endpointCandidates.isNotEmpty
            ? config.endpointCandidates
            : [config.endpoint];
    final client = clientFactory();
    cancel.onCancel(client.close);
    try {
      http.Response? response;
      var isResponses = false, isAnthropic = false;
      for (final address in candidates.take(4)) {
        cancel.check();
        final endpoint = Uri.tryParse(address);
        if (endpoint == null || endpoint.scheme != 'https')
          throw const MirrorProblem('私人课题仅通过 HTTPS 发送');
        isResponses = endpoint.path.endsWith('/responses');
        isAnthropic =
            config.provider == 'azure' && endpoint.path.contains('/anthropic/');
        final reasoning = config.provider == 'azure' &&
            UnifiedAiService.isAzureReasoningDeployment(config.deployment);
        final body = <String, dynamic>{
          'model': config.deployment,
          if (isResponses) ...{
            'store': false,
            'instructions': system,
            'input': prompt,
            'max_output_tokens': 16000,
            'text': {
              'format': {
                'type': 'json_schema',
                'name': 'will_mirror_${stage.name}',
                'strict': true,
                'schema': schema
              }
            },
          } else if (isAnthropic) ...{
            'system': system,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
            'max_tokens': 16000,
            'stream': false,
          } else ...{
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user', 'content': prompt}
            ],
            if (reasoning) 'max_completion_tokens': 16000,
            if (!reasoning) 'max_tokens': 16000,
            if (config.provider != 'azure' ||
                UnifiedAiService.azureSupportsJsonResponseFormat(
                    config.deployment))
              'response_format': {'type': 'json_object'},
          },
        };
        response = await client
            .post(endpoint,
                headers: {
                  if (isAnthropic) ...{
                    'x-api-key': config.apiKey,
                    'anthropic-version': '2023-06-01'
                  } else
                    ...config.effectiveAuthHeaders,
                  'Content-Type': 'application/json'
                },
                body: jsonEncode(body))
            .timeout(const Duration(minutes: 4));
        cancel.check();
        // Retry only unsupported Azure paths, never a charged generation,
        // authentication failure, content refusal, or rate limit.
        if (config.provider != 'azure' ||
            !{404, 405, 501}.contains(response.statusCode)) break;
      }
      if (response == null) throw const MirrorProblem('没有可用的服务地址');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final reason = switch (response.statusCode) {
          401 || 403 => '服务鉴权或访问权限不可用',
          429 => '服务达到调用限额，请稍后重试',
          400 => '当前模型不支持这次结构化请求，请检查模型设置',
          _ => 'AI 服务暂时不可用'
        };
        throw MirrorProblem('$reason（${response.statusCode}），未生成替代结论');
      }
      final raw = jsonMap(jsonDecode(utf8.decode(response.bodyBytes)));
      String output = '';
      if (isResponses) {
        if (raw['status'] == 'incomplete')
          throw const MirrorProblem('分析超出模型输出上限，请重试或调整模型');
        for (final item in (raw['output'] as List? ?? const [])) {
          if (item is! Map) continue;
          for (final part in item['content'] as List? ?? const []) {
            if (part is Map && part['type'] == 'refusal')
              throw const MirrorProblem('模型未能回答这次请求，原记录已保留');
            if (part is Map && part['type'] == 'output_text')
              output += (part['text'] as String? ?? '');
          }
        }
      } else if (isAnthropic) {
        if (raw['stop_reason'] == 'max_tokens')
          throw const MirrorProblem('模型输出被截断，请调整模型后重试');
        if (raw['stop_reason'] == 'refusal')
          throw const MirrorProblem('模型未能回答这次请求，原记录已保留');
        for (final part in raw['content'] as List? ?? const []) {
          if (part is Map && part['type'] == 'text')
            output += part['text'] as String? ?? '';
        }
      } else {
        final choices = raw['choices'] as List? ?? const [];
        if (choices.isEmpty) throw const MirrorProblem('模型没有返回分析内容');
        final choice = jsonMap(choices.first);
        if (choice['finish_reason'] == 'length')
          throw const MirrorProblem('模型输出被截断，请调整模型后重试');
        final message = jsonMap(choice['message']);
        if (message['refusal'] != null)
          throw const MirrorProblem('模型未能回答这次请求，原记录已保留');
        output = (message['content'] as String?) ?? '';
      }
      return parseStructured(output);
    } on MirrorProblem {
      rethrow;
    } catch (_) {
      cancel.check();
      throw const MirrorProblem('连接中断或响应无法读取，已保存的记录不受影响');
    } finally {
      client.close();
    }
  }
}
