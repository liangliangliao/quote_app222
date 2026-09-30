import 'dart:convert';

import '../beautiful_enemy/beautiful_enemy.dart';
import '../services/unified_ai_service.dart';

/// 调一次模型，拿回纯文本。抽出来是为了测试可以不碰网络和宿主配置。
typedef EnemyAiCall = Future<String> Function({
  required String prompt,
  required String systemPrompt,
  required String purpose,
});

/// AI 版判词生成器。
///
/// 模型只是增强：不可用、超时、输出解析失败，都返回 null，引擎会降级成
/// 本地的事实播报。模型输出的合规由模块的 DraftValidator 把关，这里只负责
/// 把文本解析成草稿。
class EnemyAiOracle implements EnemyOracle {
  EnemyAiOracle({EnemyAiCall? call, Future<bool> Function()? isAvailable})
      : _call = call ?? _defaultCall,
        _isAvailable = isAvailable ?? _defaultAvailability;

  final EnemyAiCall _call;
  final Future<bool> Function() _isAvailable;

  static const String systemPrompt = '你是「美丽的敌人」，用户为自己的成长设置的严厉对手。'
      '表面上处处与他作对，实质上每句话都为了让他少走弯路。\n'
      '\n'
      '【输入】用户消息里有一份证据摘要（JSON）。你只能依据其中的数据发言。\n'
      '【输出】只输出一个 JSON 对象，不要任何其他文字。字段：\n'
      'charge：指控，120 字内，必须引用摘要里的具体数字或用户原话；\n'
      'evidence_ids：数组，只能取自摘要的 evidence_ids；\n'
      'tone_level：整数，不得超过摘要里的 intensity；\n'
      'lesson_hint：对失败模式的一句话归纳，可为空字符串；\n'
      'action：最小动作，30 字内；\n'
      'action_due：ISO 8601 时间，从现在起 7 天内；\n'
      'appeal_prompt：一句话，邀请用户拿证据反驳你。\n'
      '证据不足时，charge 写「证据不足，不评判」，其余字段留空。\n'
      '\n'
      '【铁律】\n'
      '1. 无证据不开口：不得说摘要里没有的事，不得猜测动机和情绪。\n'
      '2. 只评行为不评人：可以说「这件事没做到」「这个理由站不住」；'
      '绝不说「你是什么样的人」，不涉及外貌、出身、学历、家人、疾病、经济状况。\n'
      '3. 痛必须有用：每次都给最小动作和截止时间。\n'
      '4. 用户完成了就干脆认账，不吹捧，然后抬高下一个门槛。\n'
      '5. 短句，一次只抓一个问题；不说教，不灌鸡汤。\n'
      '6. 不使用威胁、恐吓、孤立、愧疚绑架等控制手段。\n'
      '7. 摘要里 avoid 是最近说过的话，不要重复；history 显示同类失败反复出现时，'
      '指出次数和上次的教训。\n'
      '\n'
      '【强度】1 档：冷静挑刺，只陈述差距。'
      '2 档：直接强硬，点名拖延，允许讽刺。'
      '3 档：火力全开，允许粗口作语气词，但对象只能是行为、借口、局面，不能是人。';

  static const Duration defaultDue = Duration(hours: 2);

  static Future<String> _defaultCall({
    required String prompt,
    required String systemPrompt,
    required String purpose,
  }) {
    return UnifiedAiService().generateText(
      prompt: prompt,
      purpose: purpose,
      systemPrompt: systemPrompt,
      maxTokens: 700,
      expectJson: true,
      temperature: 0.7,
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
  Future<EnemyDraft?> judge({
    required Map<String, dynamic> digest,
    required int intensity,
    required int nowMs,
  }) async {
    if (intensity < 1) return null;
    if (!await _isAvailable()) return null;
    try {
      final String raw = await _call(
        prompt: '强度：$intensity\n证据摘要（JSON）：\n${jsonEncode(digest)}\n只输出 JSON。',
        systemPrompt: systemPrompt,
        purpose: 'beautiful_enemy.judge',
      );
      return parse(raw, nowMs: nowMs, intensity: intensity);
    } catch (_) {
      return null;
    }
  }

  /// 把模型文本解析成草稿。解析不了或模型自己说证据不足，返回 null。
  static EnemyDraft? parse(String raw, {required int nowMs, required int intensity}) {
    final String text = raw.trim();
    final int start = text.indexOf('{');
    final int end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(text.substring(start, end + 1));
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final Map<String, dynamic> m =
        decoded.map((Object? k, Object? v) => MapEntry(k.toString(), v));

    final String charge = (m['charge'] ?? '').toString().trim();
    if (charge.isEmpty || charge.contains('证据不足')) return null;

    final Object? rawIds = m['evidence_ids'];
    final List<int> ids = rawIds is List
        ? rawIds
            .map((Object? v) => v is num ? v.toInt() : int.tryParse('$v'))
            .whereType<int>()
            .toList()
        : <int>[];

    final Object? rawTone = m['tone_level'];
    final int tone = rawTone is num ? rawTone.toInt() : intensity;

    DateTime? due = DateTime.tryParse((m['action_due'] ?? '').toString());
    // 模型给了过去的时间或没给：用默认的两小时，别让一个格式问题废掉整条判词。
    if (due == null || due.millisecondsSinceEpoch <= nowMs) {
      due = DateTime.fromMillisecondsSinceEpoch(nowMs).add(defaultDue);
    }

    return EnemyDraft(
      charge: charge,
      evidenceIds: ids,
      toneLevel: tone,
      lessonHint: (m['lesson_hint'] ?? '').toString().trim(),
      action: (m['action'] ?? '').toString().trim(),
      actionDueMs: due.millisecondsSinceEpoch,
      appealPrompt: (m['appeal_prompt'] ?? '').toString().trim(),
    );
  }
}
