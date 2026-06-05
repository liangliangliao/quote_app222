
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../utils/deepseek_logger.dart';

class OpenAIService {
  final String endpoint; // e.g., https://api.openai.com/v1/responses or /chat/completions
  final String apiKey;
  final String model;

  OpenAIService({required this.endpoint, required this.apiKey, required this.model});

  Future<String> generateQuote(String prompt) async {
    final uri = Uri.parse(endpoint.isEmpty ? 'https://api.openai.com/v1/responses' : endpoint);
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json'
    };

    Map<String, dynamic> body;
    if (uri.path.endsWith('/chat/completions')) {
      body = {
        'model': model.isEmpty ? 'gpt-5' : model,
        'messages': [
          {'role': 'system', 'content': '你是一位擅长输出简短、积极、鼓舞人心的名人名言的助手。请只输出中文名人名言正文，不要多余解释。'},
          {'role': 'user', 'content': prompt}
        ]
      };
    } else {
      // Responses API: text / multi-modal unified
      body = {
        'model': model.isEmpty ? 'gpt-5' : model,
        'input': [
          {'role': 'system', 'content': '你是一位擅长输出简短、积极、鼓舞人心的名人名言的助手。请只输出中文名人名言正文，不要多余解释。'},
          {'role': 'user', 'content': prompt}
        ]
      };
    }

    try {
      await DeepSeekLogger.logRequest(
        provider: 'OpenAI',
        module: 'openai_service.generate_quote',
        endpoint: uri.toString(),
        headers: headers,
        body: body,
        model: model,
      );
      final res = await http.post(uri, headers: headers, body: jsonEncode(body));
      await DeepSeekLogger.logResponse(
        provider: 'OpenAI',
        module: 'openai_service.generate_quote',
        endpoint: uri.toString(),
        statusCode: res.statusCode,
        body: res.body,
        model: model,
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('OpenAI API 调用失败，状态码: ${res.statusCode}，响应: ${res.body}');
      }
      final data = jsonDecode(res.body);

      // Responses API
      if (data is Map && data['output'] is List) {
      final out = data['output'] as List;
      for (final item in out) {
        if (item is Map && item['content'] is List && (item['content'] as List).isNotEmpty) {
          final first = (item['content'] as List).first;
          if (first is Map && first['type'] == 'output_text') {
            final text = first['text']?.toString() ?? '';
            if (text.trim().isNotEmpty) return text.trim();
          }
        }
      }
    }
      // Chat Completions API
      if (data is Map && data['choices'] is List && data['choices'].isNotEmpty) {
      final msg = data['choices'][0]['message'];
      final content = (msg is Map) ? (msg['content'] ?? '') : '';
      return content.toString().trim();
    }
      // Fallback: known field
      if (data is Map && data['content'] != null) {
      return data['content'].toString().trim();
    }
      throw Exception('未知返回结构: ${res.body.substring(0, res.body.length > 300 ? 300 : res.body.length)}');
    } catch (e, st) {
      await DeepSeekLogger.logError(
        provider: 'OpenAI',
        module: 'openai_service.generate_quote',
        endpoint: uri.toString(),
        error: e,
        stackTrace: st,
        model: model,
      );
      rethrow;
    }
  }
}