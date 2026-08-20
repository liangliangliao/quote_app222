import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/services/global_ai_settings.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_agent_service.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_database.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_privacy_guard.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  const guard = XiangjiCloudPrivacyGuard();

  test('persisted problem identity does not disable configured AI', () {
    final assessment = guard.assess(
      task: '我想在三个月内验证自己是否适合转岗，请帮我比较路线。',
      additionalContext: const <String, Object?>{
        'problem_id': 'problem-146',
        'campaign_id': 'campaign-main',
        'situation_model_id': 'situation-2',
      },
    );
    expect(assessment.containsSensitiveCategory, isFalse);
  });

  test('strongly sensitive categories require explicit consent', () {
    final assessment = guard.assess(
      task: '这是我的确诊病历和手术方案，请结合它帮我安排接下来的工作。',
    );
    expect(assessment.containsSensitiveCategory, isTrue);
    expect(assessment.sensitiveCategories, contains('医疗健康'));
  });

  test('direct identifiers are redacted recursively before cloud use', () {
    final sanitized = guard.sanitize(<String, Object?>{
      'message': '联系邮箱 user@example.com，手机号 13812345678。',
      'profile': <String, Object?>{
        'name': '姓名：张三',
        'id': '身份证 11010519491231002X',
      },
    });
    final text = sanitized.value.toString();
    expect(text, isNot(contains('user@example.com')));
    expect(text, isNot(contains('13812345678')));
    expect(text, isNot(contains('张三')));
    expect(text, isNot(contains('11010519491231002X')));
    expect(sanitized.redactedCount, 4);
  });

  group('agent cloud routing regression', () {
    late Database database;
    late XiangjiDao dao;
    late _RecordingAi ai;
    late XiangjiAgentService service;

    setUp(() async {
      database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      dao = XiangjiDao(database: database);
      await dao.ensureSchema(database);
      await dao.createProblem(
        id: 'problem-146',
        rawEventId: 'event-146',
        rawQuestion: '我想验证转岗方向',
        contextText: '我想验证转岗方向',
      );
      ai = _RecordingAi();
      service = XiangjiAgentService(
        dao: dao,
        ai: ai,
        settings: _ConfiguredAiSettings(),
      );
    });

    tearDown(() => database.close());

    test('normal persisted problem invokes configured model without consent',
        () async {
      final result = await service.run(
        const XiangjiAgentRequest(
          requestId: 'request-normal',
          task: '请比较三条转岗验证路线。',
          agent: XiangjiAgentId.personalScienceLearner,
          problemId: 'problem-146',
          authorizedSensitiveContext: false,
        ),
      );
      expect(ai.callCount, 1);
      expect(result.localOnly, isFalse);
      expect(result.runStatus, 'success');
      expect(result.provider, 'deepseek');
    });

    test('detected sensitive category stays local until consent', () async {
      final result = await service.run(
        const XiangjiAgentRequest(
          requestId: 'request-sensitive',
          task: '请结合我的确诊病历和手术方案安排工作。',
          agent: XiangjiAgentId.personalScienceLearner,
          problemId: 'problem-146',
          authorizedSensitiveContext: false,
        ),
      );
      expect(ai.callCount, 0);
      expect(result.localOnly, isTrue);
      expect(result.runStatus, 'sensitive_consent_required');
      expect(result.sensitiveCategories, contains('医疗健康'));
    });
  });
}

class _ConfiguredAiSettings extends GlobalAiSettings {
  @override
  Future<Map<String, String>> getState() async => const <String, String>{
        'available': '1',
        'provider': 'deepseek',
        'model': 'deepseek-v4-pro',
      };
}

class _RecordingAi extends UnifiedAiService {
  int callCount = 0;

  @override
  Future<String> generateChatMessages({
    required List<UnifiedAiChatMessage> messages,
    String purpose = 'ai_assistant.chat',
    int maxTokens = 2200,
    String? forcedProvider,
    String? forcedModel,
    bool expectJson = false,
    double? temperature,
  }) async {
    callCount++;
    return '{"method_effects": []}';
  }
}
