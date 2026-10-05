import 'dart:convert';

import '../beautiful_enemy/beautiful_enemy.dart';
import '../services/unified_ai_service.dart';
import 'enemy_ai_oracle.dart';
import 'enemy_persona_prompt.dart';

/// 让模型以敌人的声音说一句话：对话回复，或者对刚发生的事的插话。
///
/// 模型只是增强。不可用、超时、抛错都返回 null，模块会退回 [PersonaLines] 里的
/// 本地台词；模型说出来的话还要过模块的 DraftValidator.validateLine（禁区、
/// 长度、粗口只在 3 档）。这里只负责把模型的输出清理成一句话。
class EnemyAiTalker implements EnemyTalker {
  EnemyAiTalker({EnemyAiCall? call, Future<bool> Function()? isAvailable})
      : _call = call ?? _defaultCall,
        _isAvailable = isAvailable ?? _defaultAvailability;

  final EnemyAiCall _call;
  final Future<bool> Function() _isAvailable;

  static const int historyTurns = 8;
  static const int historyClip = 80;

  static const String systemPrompt = '${EnemyPersonaPrompt.core}\n'
      '\n'
      '【这一轮的任务】你不是在出判词，是在说话。\n'
      '- 只输出你要说的那一句话本身：纯文本，不要 JSON、不要 markdown、不要括号旁白、不要「敌人：」前缀。\n'
      '- 对话回复不超过 90 字；对刚发生的事插话不超过 60 字。\n'
      '- 只能使用证据摘要里的事实和用户刚说的话。没有证据的事，不说；不猜他的动机和情绪。\n'
      '- 强度决定语气。0 档：平静克制，只报事实。1 档：冷静挑刺。2 档：强硬，允许讽刺。'
      '3 档：最重，允许粗口作语气词，但只冲着行为、借口、局面，不冲着他这个人。\n'
      '- 无证据不开口；只评行为不评人。绝不：威胁、恐吓、孤立、愧疚绑架；'
      '涉及外貌、出身、学历、家人、疾病、经济状况；说「你就是……的人」「你永远……」。\n'
      '- 他若流露想伤害自己或绝望，立刻放下角色，温和回应，鼓励他联系身边可信的人或当地的求助渠道。';

  static Future<String> _defaultCall({
    required String prompt,
    required String systemPrompt,
    required String purpose,
  }) {
    return UnifiedAiService().generateText(
      prompt: prompt,
      purpose: purpose,
      systemPrompt: systemPrompt,
      maxTokens: 300,
      expectJson: false,
      temperature: 0.9,
    );
  }

  static Future<bool> _defaultAvailability() async {
    try {
      final UnifiedAiResolvedConfig config = await UnifiedAiService().resolveGlobalConfig();
      return config.available;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> talk({
    required Map<String, dynamic> digest,
    required List<EnemyMessage> history,
    required String situation,
    required String userText,
    required int intensity,
    required String address,
    required int nowMs,
  }) async {
    if (!await _isAvailable()) return null;
    try {
      final String raw = await _call(
        prompt: buildPrompt(
          digest: digest,
          history: history,
          situation: situation,
          userText: userText,
          intensity: intensity,
          address: address,
        ),
        systemPrompt: systemPrompt,
        purpose: 'beautiful_enemy.talk',
      );
      final String cleaned = clean(raw);
      return cleaned.isEmpty ? null : cleaned;
    } catch (_) {
      return null;
    }
  }

  static String buildPrompt({
    required Map<String, dynamic> digest,
    required List<EnemyMessage> history,
    required String situation,
    required String userText,
    required int intensity,
    required String address,
  }) {
    final Iterable<EnemyMessage> recent =
        history.length > historyTurns ? history.skip(history.length - historyTurns) : history;
    final String lines = recent.map((EnemyMessage m) {
      final String who = m.fromEnemy ? '敌人' : '用户';
      final String t = m.text.length > historyClip ? '${m.text.substring(0, historyClip)}…' : m.text;
      return '- $who：${t.replaceAll('\n', ' ')}';
    }).join('\n');
    return '情境：$situation\n'
        '用户刚说：${userText.trim().isEmpty ? '（没有，是你主动开口）' : userText.trim()}\n'
        '近期对话（旧到新）：\n${lines.isEmpty ? '- （还没有）' : lines}\n'
        '证据摘要（JSON）：\n${jsonEncode(digest)}\n'
        '强度：$intensity\n'
        '称呼：$address\n'
        '只输出你要说的那句话。';
  }

  /// 把模型的输出清理成一句话：去代码围栏、角色前缀、旁白括号、外层引号。
  static String clean(String raw) {
    String t = raw.trim();
    t = t.replaceAll(RegExp(r'```[a-zA-Z]*'), '').replaceAll('```', '');
    t = t.replaceAll(RegExp(r'[（(][^）)]{0,30}[）)]'), '');
    t = t.replaceFirst(RegExp(r'^\s*(美丽的敌人|敌人)\s*[:：]\s*'), '');
    t = t.trim();
    const List<List<String>> wrappers = <List<String>>[
      <String>['"', '"'],
      <String>['“', '”'],
      <String>['「', '」'],
    ];
    for (final List<String> w in wrappers) {
      if (t.length >= 2 && t.startsWith(w[0]) && t.endsWith(w[1])) {
        t = t.substring(1, t.length - 1).trim();
        break;
      }
    }
    return t.replaceAll(RegExp(r'\n{2,}'), '\n').trim();
  }
}
