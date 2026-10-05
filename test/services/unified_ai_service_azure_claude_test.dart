import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/services/unified_ai_service.dart';

void main() {
  group('Azure token 参数兼容', () {
    test('GPT-5 及以上版本与 o 系列使用 max_completion_tokens', () {
      for (final model in <String>[
        'gpt-5.6-chat',
        'gpt5-mini',
        'gpt-6-luna',
        'gpt6luna',
        'my-gpt-10-preview',
        'o3-mini',
        'o6',
      ]) {
        expect(
          UnifiedAiService.isAzureReasoningDeployment(model),
          isTrue,
          reason: model,
        );
      }
    });

    test('旧 GPT 与非 OpenAI 模型继续使用 max_tokens', () {
      for (final model in <String>[
        'gpt-35-turbo',
        'gpt-4.1',
        'gpt-4o',
        'grok-4',
        'claude-sonnet-5-5',
      ]) {
        expect(
          UnifiedAiService.isAzureReasoningDeployment(model),
          isFalse,
          reason: model,
        );
      }
    });
  });

  group('Azure Claude / Anthropic Messages API', () {
    test('识别 Claude 部署名', () {
      expect(UnifiedAiService.isAzureClaudeDeployment('claude-sonnet-5-5'), isTrue);
      expect(UnifiedAiService.isAzureClaudeDeployment('CLAUDE-OPUS-5-5'), isTrue);
      expect(UnifiedAiService.isAzureClaudeDeployment('grok-4'), isFalse);
    });

    test('解析 Anthropic Messages 非流式 content blocks', () {
      final raw = jsonEncode(<String, dynamic>{
        'type': 'message',
        'role': 'assistant',
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'text', 'text': 'Azure Claude '},
          <String, dynamic>{'type': 'text', 'text': '调用成功'},
        ],
      });
      expect(UnifiedAiService.extractText(raw), 'Azure Claude 调用成功');
    });

    test('解析 Anthropic SSE text_delta', () {
      expect(
        UnifiedAiService.extractTextFromDecoded(<String, dynamic>{
          'type': 'content_block_delta',
          'delta': <String, dynamic>{'type': 'text_delta', 'text': '你'},
        }),
        '你',
      );
    });
  });
}
