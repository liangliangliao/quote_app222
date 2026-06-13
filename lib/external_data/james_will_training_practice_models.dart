import 'dart:convert';

import 'james_will_training_models.dart';

class JamesWillPracticeOption {
  final String title;
  final String whenHelpful;
  final String tradeoff;
  final String firstExperiment;
  final String referenceCase;

  const JamesWillPracticeOption({
    required this.title,
    required this.whenHelpful,
    required this.tradeoff,
    required this.firstExperiment,
    required this.referenceCase,
  });

  factory JamesWillPracticeOption.fromJson(Map<String, dynamic> json) => JamesWillPracticeOption(
        title: willTextValue(json['title'], '低风险 5 分钟实验'),
        whenHelpful: willTextValue(json['whenHelpful'], '当目标仍然模糊、但用户愿意获得真实反馈时适用。'),
        tradeoff: willTextValue(json['tradeoff'], '短期会有一点不舒服，但能换来真实反馈。'),
        firstExperiment: willTextValue(json['firstExperiment'], '执行一次 5 分钟版本，然后复盘。'),
        referenceCase: willTextValue(json['referenceCase'] ?? json['example'], '例如：先打开资料读第一段，而不是要求自己完成全部学习。'),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'whenHelpful': whenHelpful,
        'tradeoff': tradeoff,
        'firstExperiment': firstExperiment,
        'referenceCase': referenceCase,
      };
}

class JamesWillPracticeSession {
  final String id;
  final String ideaId;
  final String userNeed;
  final String userContext;
  final String needUnderstanding;
  final List<String> guidingQuestions;
  final List<JamesWillPracticeOption> options;
  final List<String> practiceStages;
  final String choicePrompt;
  final String selectedOptionTitle;
  final String userCommitment;
  final String practiceFeedback;
  final int currentStage;
  final String status;
  final int createdAtMs;
  final int updatedAtMs;

  const JamesWillPracticeSession({
    required this.id,
    required this.ideaId,
    required this.userNeed,
    required this.userContext,
    required this.needUnderstanding,
    required this.guidingQuestions,
    required this.options,
    required this.practiceStages,
    required this.choicePrompt,
    required this.selectedOptionTitle,
    required this.userCommitment,
    required this.practiceFeedback,
    required this.currentStage,
    required this.status,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  factory JamesWillPracticeSession.local({required JamesWillActionIdea idea, required String userNeed, String userContext = ''}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final options = <JamesWillPracticeOption>[
      JamesWillPracticeOption(
        title: 'A. 最小行动实验',
        whenHelpful: '当你真正需要的是先打破停滞、获得一次现实反馈时。',
        tradeoff: '优点是门槛最低；缺点是短期结果很小，需要复盘才能看到价值。',
        firstExperiment: idea.minimumAction,
        referenceCase: '例如目标是学习时，不要求学完一章，只打开资料读第一段。',
      ),
      JamesWillPracticeOption(
        title: 'B. 注意力拉回实验',
        whenHelpful: '当你最大困难不是不知道做什么，而是经常被逃避观念拉走时。',
        tradeoff: '优点是训练詹姆斯意义上的努力性注意；缺点是需要承认分心并反复拉回。',
        firstExperiment: '开始 5 分钟，中途每次分心就记录一次“拉回”。',
        referenceCase: '例如读书时想刷手机，不批评自己，只把“继续下一行”重新放回心里。',
      ),
      JamesWillPracticeOption(
        title: 'C. 7 天封存实验',
        whenHelpful: '当你反复犹豫、反复推翻决定，真正需要一段执行期时。',
        tradeoff: '优点是减少空想；缺点是 7 天内不再反复审判目标，只记录执行反馈。',
        firstExperiment: '把“要不要做”封存 7 天，每天只执行一个最小版本。',
        referenceCase: '例如不再每天问“我要不要学”，而是 7 天后再根据日志评估。',
      ),
    ];
    return JamesWillPracticeSession(
      id: 'practice_${now}_${idea.id.hashCode.abs()}',
      ideaId: idea.id,
      userNeed: userNeed.trim(),
      userContext: userContext.trim(),
      needUnderstanding: '你现在需要的可能不是一个标准答案，而是把“${idea.originalGoal}”转成一次可撤回、可观察、可复盘的真实实践。',
      guidingQuestions: const <String>[
        '我真正需要解决的是目标不清、行动太大、害怕失败，还是缺少反馈？',
        '继续等待会增加真实信息，还是只是在逃避不确定感？',
        '哪一个选项最符合我的当前处境，并且代价最小？',
        '我愿意先实验 3-7 天，再根据反馈判断吗？',
      ],
      options: options,
      practiceStages: const <String>[
        '澄清真实需要：先区分“我想要什么”和“我现在卡在哪里”。',
        '打开多种可能：至少比较 3 条路径，不让 AI 直接替我选。',
        '用户自行选择：选一条最符合当前处境的低风险实验。',
        '执行第一身体动作：只做最小行动或 5 分钟版本。',
        '复盘反馈：记录阻碍观念、主导观念、拉回次数和下一次调整。',
      ],
      choicePrompt: '请不要问“哪个是标准答案”，而是问：哪条路径最符合我当下的真实需要、风险最小、最能产生反馈？',
      selectedOptionTitle: '',
      userCommitment: '',
      practiceFeedback: '',
      currentStage: 1,
      status: 'draft',
      createdAtMs: now,
      updatedAtMs: now,
    );
  }

  factory JamesWillPracticeSession.fromAiJson({required Map<String, dynamic> json, required JamesWillPracticeSession fallback}) {
    final opts = <JamesWillPracticeOption>[];
    final rawOptions = json['possibleDirections'] ?? json['options'] ?? json['practiceOptions'];
    if (rawOptions is List) {
      for (final item in rawOptions) {
        if (item is Map) opts.add(JamesWillPracticeOption.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return fallback.copyWith(
      needUnderstanding: willTextValue(json['needUnderstanding'], fallback.needUnderstanding),
      guidingQuestions: willStringListFromJson(json['guidingQuestions']).isEmpty ? fallback.guidingQuestions : willStringListFromJson(json['guidingQuestions']),
      options: opts.isEmpty ? fallback.options : opts,
      practiceStages: willStringListFromJson(json['practiceStages'] ?? json['process']).isEmpty ? fallback.practiceStages : willStringListFromJson(json['practiceStages'] ?? json['process']),
      choicePrompt: willTextValue(json['choicePrompt'], fallback.choicePrompt),
      status: 'guided',
    );
  }

  factory JamesWillPracticeSession.fromMap(Map<String, Object?> map) {
    final opts = <JamesWillPracticeOption>[];
    try {
      final decoded = jsonDecode((map['options_json'] ?? '[]').toString());
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) opts.add(JamesWillPracticeOption.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    } catch (_) {}
    return JamesWillPracticeSession(
      id: (map['practice_id'] ?? '').toString(),
      ideaId: (map['idea_id'] ?? '').toString(),
      userNeed: (map['user_need'] ?? '').toString(),
      userContext: (map['user_context'] ?? '').toString(),
      needUnderstanding: (map['need_understanding'] ?? '').toString(),
      guidingQuestions: willStringListFromJson(map['guiding_questions_json']),
      options: opts,
      practiceStages: willStringListFromJson(map['practice_stages_json']),
      choicePrompt: (map['choice_prompt'] ?? '').toString(),
      selectedOptionTitle: (map['selected_option_title'] ?? '').toString(),
      userCommitment: (map['user_commitment'] ?? '').toString(),
      practiceFeedback: (map['practice_feedback'] ?? '').toString(),
      currentStage: willIntValue(map['current_stage'], 1).clamp(1, 5).toInt(),
      status: (map['status'] ?? 'draft').toString(),
      createdAtMs: willIntValue(map['created_at_ms']),
      updatedAtMs: willIntValue(map['updated_at_ms']),
    );
  }

  JamesWillPracticeSession copyWith({
    String? needUnderstanding,
    List<String>? guidingQuestions,
    List<JamesWillPracticeOption>? options,
    List<String>? practiceStages,
    String? choicePrompt,
    String? selectedOptionTitle,
    String? userCommitment,
    String? practiceFeedback,
    int? currentStage,
    String? status,
  }) {
    return JamesWillPracticeSession(
      id: id,
      ideaId: ideaId,
      userNeed: userNeed,
      userContext: userContext,
      needUnderstanding: needUnderstanding ?? this.needUnderstanding,
      guidingQuestions: guidingQuestions ?? this.guidingQuestions,
      options: options ?? this.options,
      practiceStages: practiceStages ?? this.practiceStages,
      choicePrompt: choicePrompt ?? this.choicePrompt,
      selectedOptionTitle: selectedOptionTitle ?? this.selectedOptionTitle,
      userCommitment: userCommitment ?? this.userCommitment,
      practiceFeedback: practiceFeedback ?? this.practiceFeedback,
      currentStage: currentStage ?? this.currentStage,
      status: status ?? this.status,
      createdAtMs: createdAtMs,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'practice_id': id,
        'idea_id': ideaId,
        'user_need': userNeed,
        'user_context': userContext,
        'need_understanding': needUnderstanding,
        'guiding_questions_json': willStringListToJson(guidingQuestions),
        'options_json': jsonEncode(options.map((e) => e.toJson()).toList()),
        'practice_stages_json': willStringListToJson(practiceStages),
        'choice_prompt': choicePrompt,
        'selected_option_title': selectedOptionTitle,
        'user_commitment': userCommitment,
        'practice_feedback': practiceFeedback,
        'current_stage': currentStage,
        'status': status,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };
}
