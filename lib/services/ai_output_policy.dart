import 'dart:convert';
import 'package:http/http.dart' as http;

/// The app never supplies an optional output quota. Anthropic Messages is the
/// protocol exception: it requires max_tokens. Use the service's model capacity,
/// never a task budget, and never retry a paid generation to discover it.
class AiOutputPolicy {
  static const label = '应用不设置输出 Token 上限';
  static final _capacities = <String, int>{};

  static int? metadataCapacity(dynamic raw) {
    if (raw is! Map) return null;
    final value = raw['max_tokens'] ??
        raw['max_output_tokens'] ??
        (raw['limits'] is Map ? raw['limits']['max_output_tokens'] : null);
    return value is num && value > 0 ? value.toInt() : null;
  }

  static Future<int> anthropicCapacity(
      Uri messages, Map<String, String> headers, String model,
      {http.Client? client}) async {
    final key = '${messages.origin}${messages.path}:$model';
    if (_capacities[key] case final cached?) return cached;
    final ownClient = client ?? http.Client();
    try {
      final segments =
          messages.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty || segments.removeLast() != 'messages') {
        throw ArgumentError('Expected a Messages API endpoint');
      }
      final response = await ownClient
          .get(messages.replace(pathSegments: [...segments, 'models', model]),
              headers: headers)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final capacity =
            metadataCapacity(jsonDecode(utf8.decode(response.bodyBytes)));
        if (capacity != null) return _capacities[key] = capacity;
      }
    } catch (_) {
      // Some Foundry deployments do not expose the Models API. Only use a
      // published capacity for a recognized version, not an arbitrary budget.
    } finally {
      if (client == null) ownClient.close();
    }
    final normalized = model.toLowerCase().replaceAll('.', '-');
    final int? published = RegExp(r'claude-(?:sonnet|haiku|opus)-4-5(?:-|$)')
            .hasMatch(normalized)
        ? 64000
        : RegExp(r'claude-opus-4-[678](?:-|$)|claude-(?:opus|sonnet|haiku)-5-5(?:-|$)|claude-fable-5-1(?:-|$)')
                .hasMatch(normalized)
            ? 128000
            : RegExp(r'claude-(?:opus-4-1|opus-4)(?:-|$)').hasMatch(normalized)
                ? 32000
                : RegExp(r'claude-(?:sonnet-4|3-7-sonnet)(?:-|$)')
                        .hasMatch(normalized)
                    ? 64000
                    : RegExp(r'claude-3-5-(?:sonnet|haiku)')
                            .hasMatch(normalized)
                        ? 8192
                        : RegExp(r'claude-3-(?:opus|sonnet|haiku)')
                                .hasMatch(normalized)
                            ? 4096
                            : null;
    if (published != null) return _capacities[key] = published;
    throw StateError(
        'Claude Messages 必须填写模型容量，但服务未返回该部署的最大输出能力；请核对模型或服务地址。应用不会代填任务额度。');
  }
}
