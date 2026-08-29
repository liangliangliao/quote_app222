import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'will_mirror_capability_catalog.dart';
import 'will_mirror_knowledge_repository.dart';
import 'will_mirror_practice_models.dart';

class WillMirrorAssistantMessage {
  const WillMirrorAssistantMessage({
    required this.role,
    required this.text,
    required this.createdAt,
    this.steps = const <String>[],
    this.theoryIds = const <String>[],
    this.caution = '',
    this.provider = 'local',
  });

  final String role;
  final String text;
  final int createdAt;
  final List<String> steps;
  final List<String> theoryIds;
  final String caution;
  final String provider;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'role': role,
        'text': text,
        'created_at': createdAt,
        'steps': steps,
        'theory_ids': theoryIds,
        'caution': caution,
        'provider': provider,
      };

  factory WillMirrorAssistantMessage.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? value) => value is List
        ? value.map((item) => item.toString()).toList(growable: false)
        : const <String>[];
    return WillMirrorAssistantMessage(
      role: (json['role'] ?? 'assistant').toString(),
      text: (json['text'] ?? '').toString(),
      createdAt: int.tryParse((json['created_at'] ?? 0).toString()) ?? 0,
      steps: strings(json['steps']),
      theoryIds: strings(json['theory_ids']),
      caution: (json['caution'] ?? '').toString(),
      provider: (json['provider'] ?? 'local').toString(),
    );
  }
}

class WillMirrorAssistantAnswer {
  const WillMirrorAssistantAnswer({
    required this.answer,
    required this.steps,
    required this.theoryIds,
    required this.caution,
    required this.capabilityId,
    required this.provider,
  });

  final String answer;
  final List<String> steps;
  final List<String> theoryIds;
  final String caution;
  final String capabilityId;
  final String provider;

  WillMirrorAssistantMessage toMessage() => WillMirrorAssistantMessage(
        role: 'assistant',
        text: answer,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        steps: steps,
        theoryIds: theoryIds,
        caution: caution,
        provider: provider,
      );
}

class WillMirrorAssistantService {
  WillMirrorAssistantService({
    WillMirrorKnowledgeRepository? knowledge,
    UnifiedAiService? ai,
  })  : _knowledge = knowledge ?? WillMirrorKnowledgeRepository(),
        _ai = ai ?? UnifiedAiService();

  final WillMirrorKnowledgeRepository _knowledge;
  final UnifiedAiService _ai;

  Future<WillMirrorAssistantAnswer> answer({
    required String question,
    WillMirrorActionPlan? plan,
    bool allowAi = false,
  }) async {
    final local = localAnswer(question, plan: plan);
    if (!allowAi) return local;
    try {
      final config = await _ai.resolveGlobalConfig();
      if (!config.available) return local;
      final passages = await _knowledge.search(question, limit: 7);
      final capabilities = WillMirrorCapabilityCatalog.search(question);
      final allowedTheoryIds = <String>{
        ...passages.map((item) => item.recordId),
        ...capabilities.expand((item) => item.theoryIds),
      };
      final payload = <String, dynamic>{
        'question': question,
        'current_step': plan == null
            ? null
            : <String, dynamic>{
                'need_type': plan.needType.value,
                'need': plan.need,
                'desired_outcome': plan.desiredOutcome,
                'obstacle': plan.obstacle,
                'today_action': plan.route.action,
                'check_in_count': plan.checkInCount,
              },
        'capabilities': capabilities
            .map(
              (item) => <String, dynamic>{
                'id': item.id,
                'title': item.title,
                'what': item.whatItIs,
                'input': item.input,
                'how_to': item.howTo,
                'output': item.output,
                'why': item.why,
                'theory_ids': item.theoryIds,
              },
            )
            .toList(growable: false),
        'knowledge': passages
            .map(
              (item) => <String, dynamic>{
                'id': item.recordId,
                'creator': item.creator,
                'section': item.sectionRef,
                'summary': item.summary,
                'product_rule': item.productRule,
                'misuse_boundary': item.misuseBoundary,
              },
            )
            .toList(growable: false),
        'required_schema': <String, dynamic>{
          'answer': 'plain Chinese string',
          'steps': <String>[],
          'theory_ids': <String>[],
          'caution': 'string',
          'capability_id': 'string',
        },
      };
      final raw = await _ai.generateText(
        prompt: jsonEncode(payload),
        purpose: 'will_mirror.v5.assistant',
        systemPrompt: _systemPrompt,
        maxTokens: 1200,
        expectJson: true,
        temperature: 0.15,
      );
      final decoded = _decodeObject(raw);
      if (decoded == null) return local;
      final answer = (decoded['answer'] ?? '').toString().trim();
      final steps = _strings(decoded['steps']).take(4).toList(growable: false);
      final theoryIds = _strings(decoded['theory_ids'])
          .where(allowedTheoryIds.contains)
          .toList(growable: false);
      final capabilityId = (decoded['capability_id'] ?? '').toString();
      if (answer.isEmpty ||
          steps.isEmpty ||
          theoryIds.isEmpty ||
          _containsForbiddenClaim(answer)) {
        return local;
      }
      return WillMirrorAssistantAnswer(
        answer: answer,
        steps: steps,
        theoryIds: theoryIds,
        caution: (decoded['caution'] ?? '').toString().trim(),
        capabilityId:
            WillMirrorCapabilityCatalog.byId(capabilityId) == null
                ? local.capabilityId
                : capabilityId,
        provider: config.label,
      );
    } catch (_) {
      return local;
    }
  }

  WillMirrorAssistantAnswer localAnswer(
    String question, {
    WillMirrorActionPlan? plan,
  }) {
    final clean = question.trim();
    final lower = clean.toLowerCase();
    if (_containsAny(lower, <String>['自杀', '不想活', '伤害自己', '结束生命'])) {
      return const WillMirrorAssistantAnswer(
        answer: '你现在的安全比完成任何目标都重要。这个功能不能处理危机，请先离开任务流程，立即联系当地急救/危机热线，或请一位可信任的人现在陪在你身边。',
        steps: <String>[
          '移开可能伤害自己的物品并去到有人在的地方',
          '联系当地紧急服务或危机支持热线',
          '把“我现在不安全，需要你陪我”原话发给可信任的人',
        ],
        theoryIds: <String>['SCH-B4-053-DESCRIPTION-NORM'],
        caution: '不要独自依赖本应用等待情况好转。',
        capabilityId: 'assistant',
        provider: 'local-safety',
      );
    }
    if (_containsAny(lower, <String>['诊断', '治疗', '创伤', '抑郁', '焦虑症'])) {
      return const WillMirrorAssistantAnswer(
        answer: '这里可以帮你把感受、触发情境和下一步支持需求说清楚，但不会诊断、治疗或推断童年根因。若痛苦持续、明显影响生活或涉及安全，请把记录带给合格的心理/医疗专业人员。',
        steps: <String>[
          '只写具体发生了什么和它怎样影响生活',
          '记录持续时间与安全风险',
          '选择联系可信任的人或专业支持',
        ],
        theoryIds: <String>[
          'SCH-B2-022-METAPHYSICAL-BOUNDARY',
          'SCH-B4-053-DESCRIPTION-NORM',
        ],
        caution: '结构化反思不等于心理治疗。',
        capabilityId: 'assistant',
        provider: 'local',
      );
    }
    if (plan != null &&
        _containsAny(lower, <String>['今天做什么', '下一步', '现在做', '该做什么', '怎么开始'])) {
      return WillMirrorAssistantAnswer(
        answer: '你现在不需要再学一个概念，只做当前方案这一小步：${plan.route.action}',
        steps: <String>[
          '准备开始所需的唯一材料',
          '启动 ${plan.route.minutes} 分钟计时，到点就停',
          '做到“${plan.route.successSignal}”就算完成',
          '做成或没做成都记录真实反馈',
        ],
        theoryIds: plan.route.theoryIds,
        caution: '当前动作来自你选择的路径；它是可修订实验，不是对你的固定判断。',
        capabilityId: 'practice_loop',
        provider: 'local',
      );
    }
    if (_containsAny(lower, <String>['没动力', '没毅力', '懒', '不想动', '压力', '害怕', '恐惧', '卡住'])) {
      return WillMirrorAssistantAnswer(
        answer: plan == null
            ? '先不要把它解释成“你缺少毅力”；今天没做成也不能证明你不想要。选择 2 分钟方案，让一次小行动帮助区分：是不想、不会、没资源，还是环境不允许。'
            : '今天没做成不会降低你的价值，也不能证明你不想要。先把动作缩到 2 分钟，再记录真正阻碍你的条件；这条阻碍就是下一轮要处理的数据。',
        steps: <String>[
          if (plan == null) '在首页写下一件最想解决的事' else '把当前动作缩成 2 分钟',
          '只留下一个可见痕迹，到点就停',
          '做成或没做成都记录能量与阻碍',
        ],
        theoryIds: const <String>[
          'SCH-B4-055-ACTION-CHARACTER',
          'TAL-L13-SEVEN-DAY-STRENGTH',
        ],
        caution: '行动不足必须保留能力、责任、资源和环境限制，不能自动解释为没有欲望。',
        capabilityId: 'practice_loop',
        provider: 'local',
      );
    }

    final matches = WillMirrorCapabilityCatalog.search(clean);
    final capability = matches.first;
    final answer = clean.isEmpty
        ? '你可以直接告诉我“我想完成什么”或“我卡在哪一步”。我会解释这是什么、怎么填、为什么要填，并给出下一步。'
        : '${capability.title}是${capability.whatItIs}它主要解决：${capability.problemSolved}';
    return WillMirrorAssistantAnswer(
      answer: answer,
      steps: capability.howTo.take(4).toList(growable: false),
      theoryIds: capability.theoryIds,
      caution: '${capability.why} 所有认识都保留反证与现实条件。',
      capabilityId: capability.id,
      provider: 'local',
    );
  }

  static const String _systemPrompt = '''
你是《意志之镜》V5 的操作与实践助手。只输出一个 JSON 对象。

硬规则：
1. 只使用输入中的 capabilities 与 knowledge；不得发明功能、思想家、引文或心理结论。
2. 先用通俗中文回答“这是什么、为什么、怎么做”，步骤最多四步，每步必须可操作。
3. 必须引用输入中存在的 theory_ids，并保留其 misuse_boundary。
4. 不得诊断、治疗、推断创伤或童年根因，不得宣布用户的本质、唯一真实需要或固定人格。
5. 不得使用羞耻、威胁、社会比较、连续打卡惩罚或“没有完成就是不够想要”等操控性语言。
6. 用户没行动时，必须保留能力、责任、资源与环境限制。
7. 涉及伤害、自杀或危机时，停止目标指导并建议立即寻求当地紧急支持和可信任的人陪伴。
''';

  static Map<String, dynamic>? _decodeObject(String raw) {
    var text = raw.trim();
    if (!text.startsWith('{')) {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      text = text.substring(start, end + 1);
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return null;
    }
  }

  static List<String> _strings(Object? value) => value is List
      ? value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
      : const <String>[];

  static bool _containsAny(String value, List<String> words) =>
      words.any(value.contains);

  static bool _containsForbiddenClaim(String value) => _containsAny(
        value,
        <String>['你的本质是', '真正的你就是', '唯一真实需要', '童年根因是', '诊断为'],
      );
}
