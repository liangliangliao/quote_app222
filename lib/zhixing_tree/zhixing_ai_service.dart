import 'dart:convert';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'zhixing_engine.dart';
import 'zhixing_models.dart';

class ZhixingAiResult {
  final ZhixingPrescription prescription;
  final bool fromFallback;
  final String provider;
  final String modelLabel;

  const ZhixingAiResult({
    required this.prescription,
    required this.fromFallback,
    required this.provider,
    required this.modelLabel,
  });
}

class ZhixingAiService {
  final ZhixingEngine engine;
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _ai = UnifiedAiService();

  ZhixingAiService({ZhixingEngine? engine}) : engine = engine ?? ZhixingEngine();

  Future<Map<String, String>> getGlobalAiState() async {
    try {
      return await _settings.getState();
    } catch (_) {
      return <String, String>{
        'provider': 'none',
        'model': 'none',
        'label': '未配置（使用本地知行策略）',
        'available': '0',
      };
    }
  }

  Future<ZhixingAiResult> generate({
    required ZhixingDiagnosis diagnosis,
    required ZhixingActionProfile profile,
    String historySummary = '',
  }) async {
    final local = engine.generateLocal(diagnosis: diagnosis, profile: profile);
    if (local.isSafetyRoute) {
      return ZhixingAiResult(
        prescription: local,
        fromFallback: true,
        provider: 'local-safety',
        modelLabel: '本地安全路由',
      );
    }

    final state = await getGlobalAiState();
    if ((state['available'] ?? '0') != '1') {
      return ZhixingAiResult(
        prescription: local,
        fromFallback: true,
        provider: 'local',
        modelLabel: '内置知行策略',
      );
    }

    try {
      final raw = await _ai.generateText(
        purpose: 'zhixing_tree.generate_prescription',
        systemPrompt: _systemPrompt,
        prompt: _buildPrompt(
          diagnosis: diagnosis,
          profile: profile,
          local: local,
          historySummary: historySummary,
        ),
        maxTokens: 2600,
        expectJson: true,
        temperature: .25,
      );
      final parsed = _parseJson(raw);
      if (parsed == null) throw const FormatException('AI 未返回有效 JSON');
      final refined = _mergeValidated(local, parsed).copyWith(
        provider: state['provider'] ?? 'ai',
        modelLabel: state['label'] ?? state['model'] ?? '统一 AI',
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      return ZhixingAiResult(
        prescription: refined,
        fromFallback: false,
        provider: refined.provider,
        modelLabel: refined.modelLabel,
      );
    } catch (_) {
      return ZhixingAiResult(
        prescription: local,
        fromFallback: true,
        provider: 'local',
        modelLabel: '内置知行策略',
      );
    }
  }

  String _buildPrompt({
    required ZhixingDiagnosis diagnosis,
    required ZhixingActionProfile profile,
    required ZhixingPrescription local,
    required String historySummary,
  }) {
    final payload = <String, dynamic>{
      'diagnosis': diagnosis.toJson(),
      'dynamic_profile': profile.toJson(),
      'local_safe_baseline': local.toJson(),
      'recent_effectiveness_summary': historySummary.trim(),
    };
    return '''
请基于下面的结构化数据，把“本地安全基线”精炼为一张个体化知行卡。

约束：
1. 保留 baseline 的 challenge_type、difficulty、risk、奖励数值与安全路由，不得提高风险强度。
2. 一次只给一个主要现实行动；行动必须真实、可控、可在当前资源下验证。
3. 必须包含 trigger、first_physical_action 和 success_evidence。
4. 任务奖励可控行动，不奖励录用、点赞、销售额等外部结果。
5. 不要求情绪消失后再行动；但不能要求忍受现实伤害。
6. 不把未行动归因于懒惰，不做人格诊断，不用羞耻、惩罚或思想家权威压迫用户。
7. 不伪造引语，不把综合建议写成任何思想家的原话。
8. 如果信息不足，保留本地基线，不得编造用户经历。
9. 输出简体中文的单个 JSON 对象，不要 Markdown，不要解释。

JSON 字段：
{
  "title": "不超过24字",
  "value": "一个自主价值",
  "action": "一个现实行动，不超过120字",
  "trigger": "明确情境或时间触发",
  "first_physical_action": "第一个身体动作",
  "success_evidence": "客观完成证据",
  "stuck_shrink": "30秒到5分钟缩小方案",
  "stuck_adapt": "环境/工具/支持调整",
  "stuck_carry": "允许不适存在的最低动作",
  "stuck_reconsider": "检查目标/风险/资源/恢复",
  "match_rationale": "为什么当前组合适配",
  "match_boundary": "最重要的误用边界",
  "assistants": ["最多2项辅助思想"]
}

输入：
${jsonEncode(payload)}
''';
  }

  Map<String, dynamic>? _parseJson(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('```')) {
      text = text
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .replaceAll('```', '')
          .trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) text = text.substring(start, end + 1);
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  ZhixingPrescription _mergeValidated(
    ZhixingPrescription baseline,
    Map<String, dynamic> map,
  ) {
    final currentMatch = baseline.thoughtMatch;
    final assistants = _stringList(map['assistants'], maxItems: 2);
    final match = ZhixingThoughtMatch(
      dominant: currentMatch.dominant,
      executionTool: currentMatch.executionTool,
      assistants: assistants.isEmpty ? currentMatch.assistants : assistants,
      balancing: currentMatch.balancing,
      rationale: _safeText(
        map['match_rationale'],
        currentMatch.rationale,
        maxLength: 180,
      ),
      boundary: _safeText(
        map['match_boundary'],
        currentMatch.boundary,
        maxLength: 180,
      ),
      confidence: currentMatch.confidence,
      sources: currentMatch.sources,
    );
    return baseline.copyWith(
      title: _safeText(map['title'], baseline.title, maxLength: 28),
      value: _safeText(map['value'], baseline.value, maxLength: 16),
      action: _singleAction(map['action'], baseline.action),
      trigger: _safeText(map['trigger'], baseline.trigger, maxLength: 80),
      firstPhysicalAction: _safeText(
        map['first_physical_action'],
        baseline.firstPhysicalAction,
        maxLength: 80,
      ),
      successEvidence: _safeText(
        map['success_evidence'],
        baseline.successEvidence,
        maxLength: 100,
      ),
      stuckShrink: _safeText(
        map['stuck_shrink'],
        baseline.stuckShrink,
        maxLength: 120,
      ),
      stuckAdapt: _safeText(
        map['stuck_adapt'],
        baseline.stuckAdapt,
        maxLength: 120,
      ),
      stuckCarry: _safeText(
        map['stuck_carry'],
        baseline.stuckCarry,
        maxLength: 120,
      ),
      stuckReconsider: _safeText(
        map['stuck_reconsider'],
        baseline.stuckReconsider,
        maxLength: 120,
      ),
      thoughtMatch: match,
    );
  }

  String _singleAction(Object? value, String fallback) {
    var text = _safeText(value, fallback, maxLength: 160);
    text = text
        .replaceAll(RegExp(r'^\s*[-*•]\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\n+'), '；')
        .trim();
    if (text.isEmpty) return fallback;
    return text;
  }

  String _safeText(
    Object? value,
    String fallback, {
    required int maxLength,
  }) {
    var text = value?.toString().trim() ?? '';
    if (text.length < 2) return fallback;
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > maxLength) text = text.substring(0, maxLength);
    return text;
  }

  List<String> _stringList(Object? value, {required int maxItems}) {
    if (value is! List) return const <String>[];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .take(maxItems)
        .toList();
  }

  static const String _systemPrompt = '''
你是“知行树”的行动路由引擎。你的目标不是展示理论知识，而是保护用户主体性，把当前知行断点编译成一个安全、现实、可验证的下一步行动。

统一价值：
- 不把知道误认为做到，不把所有不行动归因于懒惰。
- 不把情绪消失设为行动资格，不把失败等同人格失败。
- 行动必须自主、具体、可控；能力来自现实掌握经验。
- 环境、资源、恢复与求助都是行动系统的一部分。
- 最高目标是用户逐步独立完成知—行—反馈闭环并减少产品依赖。

匹配采用三层：主导思想处理核心断点；执行工具产生动作；制衡思想防止极端化。理论隐藏在后台，前台始终保持一个判断、一张知行卡和一个开始按钮。

安全边界：不进行临床诊断，不替代医疗、心理、法律或重大财务专业意见；不以接纳要求忍受伤害；不以自我克服压迫疲劳、创伤或高风险用户。
''';
}
