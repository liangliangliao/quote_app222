import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_ai_service.dart';
import 'package:quote_app/self_os/self_os_models.dart';

void main() {
  test('停止等待后不再启动下一批 AI 动机请求', () async {
    var calls = 0;
    var cancelled = false;
    final ai = SelfOsAiService(generate: (
        {required prompt,
        required purpose,
        required systemPrompt,
        required maxTokens}) async {
      calls++;
      cancelled = true;
      return '{"motives":[]}';
    });
    await expectLater(
        ai.motives(SelfOsCase(problem: '一个选择'), [],
            isCancelled: () => cancelled),
        throwsA(isA<SelfOsAiCancelled>()));
    expect(calls, 1);
  });

  test('未来情境缺少五个时间尺度时显式报错', () async {
    final ai = SelfOsAiService(
        generate: (
                {required prompt,
                required purpose,
                required systemPrompt,
                required maxTokens}) async =>
            jsonEncode({
              'suggestions': [
                {'field': 'futureNow', 'value': '可能得到反馈', 'reason': '模拟'}
              ]
            }));
    await expectLater(ai.suggest(SelfOsCase(problem: '一个选择'), [], 'future'),
        throwsFormatException);
  });
  test('独立欲求分析不带 Why Tree，自我解释不会覆盖独立视角', () async {
    String sent = '';
    final ai = SelfOsAiService(generate: (
        {required prompt,
        required purpose,
        required systemPrompt,
        required maxTokens}) async {
      sent = prompt;
      expect(purpose, 'self_os.desires');
      expect(systemPrompt, contains('一次行为'));
      return jsonEncode({
        'desires': List.generate(
            5,
            (i) => {
                  'title': '候选$i',
                  'support': '原始输入',
                  'counter': '尚无真实行动',
                  'question': '愿意承担什么代价？',
                  'confidence': 50
                })
      });
    });
    final c = SelfOsCase(problem: '明天面试不想去')
      ..addWhy(SelfOsWhyNode(answer: '不能暴露给独立分析的自我解释'));
    final result = await ai.discover(c, []);
    expect(result, hasLength(5));
    expect(result.every((d) => d.verdict == 'pending'), isTrue);
    expect(sent, isNot(contains('不能暴露给独立分析')));
    expect(result.first.source, 'AI 独立假设');
  });
  test('不完整 AI 响应显式失败，不伪装成本地分析结果', () async {
    final ai = SelfOsAiService(
        generate: (
                {required prompt,
                required purpose,
                required systemPrompt,
                required maxTokens}) async =>
            '{"desires":[{"title":"唯一真相"}]}');
    await expectLater(
        ai.discover(SelfOsCase(problem: '选择'), []), throwsFormatException);
    expect(() => SelfOsAiService.parse('not json'), throwsFormatException);
    expect(
        SelfOsAiService.parse(
            '```json\n{"suggestions":[]}\n```')['suggestions'],
        isEmpty);
  });
  test('动机分三批形成60个双向候选，AI生成事实不直接升级为事实', () async {
    var calls = 0;
    final ai = SelfOsAiService(generate: (
        {required prompt,
        required purpose,
        required systemPrompt,
        required maxTokens}) async {
      final batch = calls++;
      return jsonEncode({
        'motives': List.generate(
            20,
            (i) => {
                  'title': '动机-$batch-$i',
                  'type': i.isEven ? '长期目标' : '即时收益',
                  'side': i.isEven ? 'for' : 'against',
                  'layer': '直观 / 现场',
                  'kind': '事实',
                  'reason': '假定后果进入眼前的选择',
                  'predicted': 80
                })
      });
    });
    final progress = <int>[];
    final result =
        await ai.motives(SelfOsCase(problem: '面试'), [], progress: progress.add);
    expect(calls, 3);
    expect(progress, [1, 2, 3]);
    expect(result, hasLength(60));
    expect(result.where((m) => m.side == 'against'), hasLength(30));
    expect(result.every((m) => !m.selected && m.kind == '概率推断'), isTrue);
  });
  test('建议只接受已知字段，不能注入实际结果或篡改用户概率', () async {
    final ai = SelfOsAiService(
        generate: (
                {required prompt,
                required purpose,
                required systemPrompt,
                required maxTokens}) async =>
            jsonEncode({
              'suggestions': [
                {'field': 'actualResult', 'value': '你成功了', 'reason': '编造'},
                {'field': 'actionProbability', 'value': '100', 'reason': '编造'},
                {
                  'field': 'firstAction',
                  'value': '先把双脚落地',
                  'reason': '用户希望先走一小步',
                  'kind': '事实'
                }
              ]
            }));
    final suggestions =
        await ai.suggest(SelfOsCase(problem: '起床'), [], 'action');
    expect(suggestions, hasLength(1));
    expect(suggestions.single['field'], 'firstAction');
    expect(suggestions.single['kind'], '概率推断');
  });
}
