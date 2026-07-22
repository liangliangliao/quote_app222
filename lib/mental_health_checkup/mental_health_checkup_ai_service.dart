import 'dart:convert';

import '../data/kv_dao.dart';
import '../services/unified_ai_service.dart';
import 'mental_health_checkup_models.dart';

class MentalHealthCheckupPromptConfig {
  static const String moduleId = 'mental_health_checkup';
  static const String globalId = 'global';
  static const String reportId = 'report';
  static const String retestId = 'retest';

  static const Map<String, String> labels = <String, String>{
    globalId: '全局价值与安全 Prompt',
    reportId: '课程体检报告 Prompt',
    retestId: '复验与处方调整 Prompt',
  };

  static const String defaultGlobalPrompt = r'''
你是“哈佛幸福课23讲心理健康体检”的课程型解释助手。你只能在应用已经计算完成的结构化结果上做解释和行动转化，不能修改分数、安全状态、证据等级、诊断候选、处方上限或复验规则。

必须遵守：
1. 本系统不是医学疾病诊断，不是真实医疗处方，不提供药物建议，不承诺治愈。
2. “课程型诊断”只表示最值得继续验证的课程机制假设；证据不足时必须明确说“候选假设”。
3. “课程处方”只指课程中已有依据的练习、行动、生活仪式和反思任务。
4. C1是课程直接内容，C2是课程机制推导，D1是产品测量/剂量参数，D2是安全与功能分流。不得混淆。
5. 必须同时保留支持证据、冲突证据和至少两种替代解释。
6. 不把高完成率直接当疗效；同时检查现实功能、过度化、疲劳、睡眠、关系和自主性。
7. 若 safety_status 不是 clear，只能重申应用的安全路线，不得生成普通课程任务，不得用积极练习覆盖风险。
8. 语言温和、具体、不羞辱、不贴永久人格标签；每次最多建议一个当前行动。
''';

  static const String defaultReportPrompt = r'''
请根据 {{report_json}} 生成一份便于用户理解的课程型体检解释。严格使用以下结构：

【本轮能说明什么】说明模式、覆盖度、数据质量和结论强度。
【先看安全与功能】准确复述安全状态和现实功能影响。
【八域画像】解释最低的1-3个已覆盖领域，也指出至少一个保留能力或反证。
【当前优先验证的课程机制】区分确定事实、候选机制和替代解释。
【为什么不是人格判决】说明时间线、环境、身体基础和现实情境仍可能改变解释。
【一项课程行动处方】只能复述结构化结果中已经批准的处方；说明微量、疗程、证据位置和停止规则。
【如何判断有效】同时使用指标、现实功能、执行率、过度化和自主性。
【复验计划】说明何时复验以及继续、减量、暂停、换方或维持的条件。
【来源边界】逐项说明 C1/C2/D1/D2，不把课程机制说成医学结论。

只输出中文，不制造新量表、新阈值、新诊断或新处方。
''';

  static const String defaultRetestPrompt = r'''
请根据 {{retest_json}} 解释本次复验。先复述规则引擎给出的 decision 和 reason，再解释分数变化、现实功能、执行率和过度化风险之间的关系。不得推翻规则引擎决策；不得因为完成率高就宣告恢复；结尾只给一个最小下一步。
''';

  final KeyValueDao _kv;

  MentalHealthCheckupPromptConfig({KeyValueDao? keyValueDao})
      : _kv = keyValueDao ?? KeyValueDao();

  static String _key(String id) => 'ai_prompt.$moduleId.$id';

  String defaultFor(String id) {
    switch (id) {
      case reportId:
        return defaultReportPrompt;
      case retestId:
        return defaultRetestPrompt;
      case globalId:
      default:
        return defaultGlobalPrompt;
    }
  }

  Future<String> getPrompt(String id) async {
    final value = (await _kv.getString(_key(id)))?.trim() ?? '';
    return value.isEmpty ? defaultFor(id) : value;
  }

  Future<void> savePrompt(String id, String value) async {
    final normalized = value.trim();
    await _kv.setString(_key(id), normalized.isEmpty ? defaultFor(id) : normalized);
  }

  Future<void> resetPrompt(String id) =>
      _kv.setString(_key(id), defaultFor(id));

  Future<String> buildReportPrompt(CheckupReport report) async {
    final template = await getPrompt(reportId);
    return template.replaceAll('{{report_json}}', jsonEncode(report.toJson()));
  }

  Future<String> buildRetestPrompt(CheckupRetestRecord retest) async {
    final template = await getPrompt(retestId);
    return template.replaceAll('{{retest_json}}', jsonEncode(retest.toJson()));
  }
}

class MentalHealthCheckupAiResult {
  final String text;
  final bool usedAi;

  const MentalHealthCheckupAiResult({
    required this.text,
    required this.usedAi,
  });
}

class MentalHealthCheckupAiService {
  final UnifiedAiService _ai;
  final MentalHealthCheckupPromptConfig prompts;

  MentalHealthCheckupAiService({
    UnifiedAiService? ai,
    MentalHealthCheckupPromptConfig? promptConfig,
  })  : _ai = ai ?? UnifiedAiService(),
        prompts = promptConfig ?? MentalHealthCheckupPromptConfig();

  Future<MentalHealthCheckupAiResult> explainReport(
    CheckupReport report, {
    required String fallback,
  }) async {
    if (!report.safetyClear) {
      return MentalHealthCheckupAiResult(text: fallback, usedAi: false);
    }
    try {
      final prompt = await prompts.buildReportPrompt(report);
      final systemPrompt = await prompts.getPrompt(
        MentalHealthCheckupPromptConfig.globalId,
      );
      final value = await _ai.generateText(
        prompt: prompt,
        purpose: 'mental_health_checkup.explain_report',
        systemPrompt: systemPrompt,
        maxTokens: 3000,
        expectJson: false,
        temperature: 0.2,
      );
      if (value.trim().isNotEmpty) {
        return MentalHealthCheckupAiResult(
          text: value.trim(),
          usedAi: true,
        );
      }
    } catch (_) {}
    return MentalHealthCheckupAiResult(text: fallback, usedAi: false);
  }

  Future<MentalHealthCheckupAiResult> explainRetest(
    CheckupRetestRecord retest, {
    required String fallback,
  }) async {
    try {
      final prompt = await prompts.buildRetestPrompt(retest);
      final systemPrompt = await prompts.getPrompt(
        MentalHealthCheckupPromptConfig.globalId,
      );
      final value = await _ai.generateText(
        prompt: prompt,
        purpose: 'mental_health_checkup.explain_retest',
        systemPrompt: systemPrompt,
        maxTokens: 1800,
        expectJson: false,
        temperature: 0.2,
      );
      if (value.trim().isNotEmpty) {
        return MentalHealthCheckupAiResult(
          text: value.trim(),
          usedAi: true,
        );
      }
    } catch (_) {}
    return MentalHealthCheckupAiResult(text: fallback, usedAi: false);
  }
}
