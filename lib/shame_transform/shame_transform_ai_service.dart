import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'shame_transform_models.dart';

class ShameTransformAiService {
  final _settings = GlobalAiSettings();
  final _ai = UnifiedAiService();

  static const systemPrompt = '''你是“足下真实自我·羞耻转化行动系统”的AI引导者。你不做心理诊断或道德判决。始终区分毒性羞耻（把行为变成“我整个人有缺陷”）与健康羞耻（承认有限、责任、边界、学习与修复）。不空洞安慰，也不强化身份审判；同时坚持自我接纳与现实责任。帮助用户分离事实、解释和身份判断，外化内在批判声音，明确该承担与不该背负的部分。每次至少生成一个今天可完成、低门槛、可验证的行动和一条行动证据。关系情境中尊重边界和自主选择。若出现自伤、自杀、伤人或暴力风险，优先建议联系可信任的人、当地紧急服务或专业医疗/心理资源，停止深挖。语言温和、具体、有尊严。只输出合法JSON。''';

  Future<ShameAiResult> analyze({required String scene, required String input, int intensity = 5}) async {
    final state = await _settings.getState();
    if (state['available'] != '1') return _fallback(input);
    final prompt = '''当前场景：$scene；羞耻强度：$intensity/10。用户输入：$input
请完成：事实/解释/身份审判分离；毒性与健康羞耻区分；责任边界；2-3条可选路径；今日最小行动与更小备用版；证据句。不得替用户做唯一决定。
严格输出：{"scene":"$scene","value_anchor":"","user_input_summary":"","core_recognition":{"event_fact":"","emotion":[],"body_reaction":[],"toxic_shame_language":[],"healthy_shame_message":""},"fact_vs_story":{"facts":[],"interpretations":[],"identity_judgments":[]},"responsibility_boundary":{"user_responsibility":[],"not_user_responsibility":[],"repairable_part":[],"uncontrollable_part":[]},"reframe":{"toxic_version":"","healthy_version":"","new_identity_sentence":""},"action_options":[{"name":"","purpose":"","steps":[],"difficulty":"低","time_required":"","evidence_after_done":""}],"today_minimum_action":{"action":"","time_required":"","success_standard":"","fallback":""},"reflection_questions":[],"evidence_sentence":"","user_choice_prompt":""}''';
    try {
      final raw = await _ai.generateText(prompt: prompt, purpose: 'shame_transform.$scene', systemPrompt: systemPrompt, maxTokens: 2600, expectJson: true, temperature: .3);
      return ShameAiResult.fromJson(extractJson(raw));
    } catch (_) { return _fallback(input); }
  }

  ShameAiResult _fallback(String input) => ShameAiResult(valueAnchor: '我不是错误本身', summary: input, healthyMessage: '这件事可以提醒你看见有限、责任或边界，但不需要把整个人定义成错误。', responsibility: '确认事实，并选择一个你确实能影响的下一步', notResponsibility: '他人的全部反应、无法控制的结果，以及对整个人格的否定', healthyVersion: '我正在经历一件困难的事；我可以承担具体责任，但我不是这件事本身。', identitySentence: '我是有限但有价值的人，我可以从一个小行动重新开始。', minimumAction: '用一句不带评价的话写下刚才发生的事实', fallback: '只写下时间、地点和发生了什么', evidenceSentence: '今天我没有继续隐藏，我把羞耻还原成了一个可以处理的事实。', toxicLanguages: const ['把一次事件扩大成整个人的价值判断'], actions: const ['事实分离：写下一句事实', '责任边界：圈出一个可控部分', '现实行动：完成一个10分钟版本'], reflectionQuestions: const ['我在哪一刻把自己等同于错误？', '我真正需要承担什么？', '下一步怎样再小一点？']);
}
