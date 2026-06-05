import 'dart:convert';


import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'belief_action_models.dart';

class BeliefActionAIService {
  final GlobalAiSettings _globalAiSettings = GlobalAiSettings();
  final UnifiedAiService _unifiedAiService = UnifiedAiService();

  /// 根据关键词生成行动模板。
  ///
  /// provider:
  /// - 'local'：本地规则生成（不联网）
  /// - 其他值：统一走设置页中的全局 AI 提供方 / 模型配置
  Future<BeliefActionTemplate> generate({
    required String provider,
    required String conceptId,
    required String conceptTitle,
    required String keywords,
    required String scene,
    required String mode,
  }) async {
    if (provider == 'local') {
      return _genLocal(conceptId: conceptId, conceptTitle: conceptTitle, keywords: keywords, scene: scene, mode: mode);
    }
    final t = await _genUnified(conceptId: conceptId, conceptTitle: conceptTitle, keywords: keywords, scene: scene, mode: mode);
    if (t != null) return t;
    return _genLocal(conceptId: conceptId, conceptTitle: conceptTitle, keywords: keywords, scene: scene, mode: mode);
  }

  BeliefActionTemplate _genLocal({
    required String conceptId,
    required String conceptTitle,
    required String keywords,
    required String scene,
    required String mode,
  }) {
    final kid = keywords.trim().isEmpty ? '关键词缺失' : keywords.trim();
    final sc = scene.trim().isEmpty ? '通用场景' : scene.trim();

    return BeliefActionTemplate(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      conceptId: conceptId,
      title: 'AI模板（本地）: $sc · $kid',
      version: '基础版',
      categoryPath: '$sc/AI生成/参考模板',
      mode: mode,
      operationalDefinition: '把“$conceptTitle”翻译为在【$sc】中可执行的动作：遇到【$kid】时，先做一个最小动作，再用证据复盘一致性。',
      successCriteria: '完成≥1次行动；写下证据；概念一致性评分≥4（或能解释为何不一致）。',
      actionChecklist: [
        '把问题写成一句话：在【$sc】中，我现在卡在【$kid】',
        '选一个 10–30 分钟的最小行动（能产生证据）',
        '执行并记录证据（次数/时长/反馈/产出）',
        '复盘：行动是否体现了“$conceptTitle”？哪里偏了？',
        '给下一次迭代：要改情境、改脚本还是改强化？',
      ],
      refSegmentKeys: const [],
      learningTags: const ['强化', '刺激控制', '自我监测'],
      changePath: '触发→最小替代行为→即时反馈→记录→迭代。',
    );
  }

  Future<BeliefActionTemplate?> _genUnified({
    required String conceptId,
    required String conceptTitle,
    required String keywords,
    required String scene,
    required String mode,
  }) async {
    try {
      final state = await _globalAiSettings.getState();
      if (state['available'] != '1') return null;
      final prompt = _buildPrompt(conceptId: conceptId, conceptTitle: conceptTitle, keywords: keywords, scene: scene, mode: mode);
      final text = await _unifiedAiService.generateText(
        prompt: prompt,
        purpose: 'belief_lab.generate',
        systemPrompt: '你是一个把“概念→现实行动”转写为模板的助手。你必须输出严格 JSON，不要输出多余文本。',
        maxTokens: 1200,
        expectJson: true,
        temperature: 0.3,
      );
      if (text.trim().isEmpty) return null;
      final m = jsonDecode(text);
      if (m is! Map<String, dynamic>) return null;
      return BeliefActionTemplate.fromJson(m);
    } catch (_) {
      return null;
    }
  }

  String _buildPrompt({
    required String conceptId,
    required String conceptTitle,
    required String keywords,
    required String scene,
    required String mode,
  }) {
    final kid = keywords.trim().isEmpty ? '（用户未提供关键词）' : keywords.trim();
    final sc = scene.trim().isEmpty ? '（用户未提供场景）' : scene.trim();
    final m = mode == 'planned' ? 'planned' : 'quick';

    return '''请根据以下信息生成一个“行动模板”，并严格输出一段 JSON（不要任何解释文字）：

概念：$conceptTitle
conceptId：$conceptId
场景：$sc
关键词：$kid
模式：$m（planned=计划模式，需要关联目标；quick=非计划模式，当下试验）

JSON 必须符合：
{
  "id": "ai_<timestamp_or_uuid>",
  "conceptId": "...",
  "title": "...",
  "version": "基础版|进阶版",
  "categoryPath": "领域/子领域/用途",
  "mode": "planned|quick",
  "operationalDefinition": "用1-3句话把概念翻译成现实可执行动作",
  "successCriteria": "用可观察的方式说明如何验证概念与行动一致",
  "actionChecklist": ["步骤1", "步骤2", "步骤3", "步骤4", "步骤5"],
  "refSegmentKeys": ["L6#21", "..."],
  "learningTags": ["刺激控制", "强化", "自我监测"],
  "changePath": "如果涉及坏习惯，给出触发→替代→强化→复盘的路径"
}

注意：
- 步骤要具体、常见、可执行。
- successCriteria 必须能让用户在现实中评分验证。
- refSegmentKeys 可以为空数组，但不要乱编不存在的编号（不确定就留空）。
''';
  }

}

