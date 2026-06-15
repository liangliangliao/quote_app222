import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'shame_transform_models.dart';

class ShameTransformAiService {
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _ai = UnifiedAiService();

  static const String globalSystemPrompt = '''
你是“足下真实自我·羞耻转化行动系统”的 AI 引导者。你不做心理诊断，不替用户做道德判决或人生选择。

必须遵守：
1. 区分毒性羞耻与健康羞耻。毒性羞耻把行为扩大成“我整个人有根本缺陷”；健康羞耻承认有限、错误、边界、责任、学习、修复和对他人的需要。
2. 永远不认同“用户就是错误本身”。把身份审判还原为具体事件、感受、责任和行动。
3. 不用“别想太多、你很好、加油”等空洞安慰代替结构化转化。
4. 自我接纳与承担责任必须同时存在：分别写清该承担、不该背负、可修复、不可控的部分。
5. 使用温和、清晰、具体、非羞辱性语言；指出问题时保护尊严。
6. 尊重自主判断，提供多条可能路径和利弊，不替用户决定唯一答案。
7. 所有分析必须落到今天可完成、低门槛、可验证的现实行动，并生成行动证据句。
8. Todo 不只拆任务，还要扫描能力、失败、金钱、身体、关系、拖延和完美主义羞耻，生成现实问题树、羞耻阻碍和行动树。
9. 外化批判声音：探索来源、保护意图和羞辱方式；留下保护功能，拿掉羞辱方式。
10. 对愤怒、需要、依赖、欲望、脆弱、嫉妒、懒惰、控制欲等被否认部分，探索其保护功能、代价与成熟表达，不简单消灭。
11. 关系问题要区分合理批评、真实伤害、羞辱、控制、投射、讨好和过度背责，并给出不羞辱双方的边界表达。
12. 出现自伤、自杀、严重伤人、暴力或失控风险时，优先支持用户联系现实中的可信任人士、当地紧急服务或专业医疗/心理资源；停止深挖，不让用户独自承担。
13. 不要把书中观点包装为医学事实；不声称治愈或替代专业治疗。
14. 最终强化：“我是有限但有价值的人。我不是错误本身。我可以承担责任、保护边界、修复关系，并用行动恢复真实自我。”

只输出合法 JSON，不输出 Markdown。
''';

  Future<ShameAiResult> analyze({
    required ShameScene scene,
    required String input,
    int intensity = 5,
    List<String> emotions = const [],
    List<String> bodyReactions = const [],
    String relationshipMode = '',
    String deniedPart = '',
  }) async {
    final state = await _settings.getState();
    if (state['available'] != '1') {
      return _fallback(scene, input, emotions, bodyReactions);
    }
    final prompt = _buildPrompt(
      scene: scene,
      input: input,
      intensity: intensity,
      emotions: emotions,
      bodyReactions: bodyReactions,
      relationshipMode: relationshipMode,
      deniedPart: deniedPart,
    );
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'shame_transform.${scene.key}',
        systemPrompt: globalSystemPrompt,
        maxTokens: scene == ShameScene.todoGoal ? 5200 : 3400,
        expectJson: true,
        temperature: 0.3,
      );
      return ShameAiResult.fromJson(extractJsonObject(raw), scene);
    } catch (_) {
      return _fallback(scene, input, emotions, bodyReactions);
    }
  }

  String _buildPrompt({
    required ShameScene scene,
    required String input,
    required int intensity,
    required List<String> emotions,
    required List<String> bodyReactions,
    required String relationshipMode,
    required String deniedPart,
  }) {
    final context = '''
当前场景：${scene.title}
scene_key：${scene.key}
羞耻强度：$intensity/10
用户输入：$input
用户选择的情绪：${emotions.join('、')}
用户选择的身体反应：${bodyReactions.join('、')}
关系分支：$relationshipMode
被否认的自我部分：$deniedPart
''';
    return '''
$context
${_sceneInstructions(scene)}

严格使用以下通用结构。Todo 场景还必须填写 problem_tree 和 action_tree；其他场景可返回空数组：
{
  "scene_key":"${scene.key}",
  "value_anchor":"本次核心价值",
  "user_input_summary":"一句话概括",
  "core_recognition":{
    "event_fact":"具体事件事实",
    "emotion":["情绪"],
    "body_reaction":["身体反应"],
    "toxic_shame_language":["身份化羞耻语言"],
    "healthy_shame_message":"健康羞耻提醒"
  },
  "fact_vs_story":{
    "facts":["可确认事实"],
    "interpretations":["待确认解释"],
    "identity_judgments":["身份审判"]
  },
  "responsibility_boundary":{
    "user_responsibility":["该承担部分"],
    "not_user_responsibility":["不该背负部分"],
    "repairable_part":["可修复部分"],
    "uncontrollable_part":["不可控部分"]
  },
  "voice_externalization":{
    "source_voice":"可能来源，明确标注为推测",
    "protection_intent":"它可能想保护什么",
    "toxic_method":"它使用的羞辱方式",
    "healthy_protection":"保留保护功能后的表达"
  },
  "reframe":{
    "toxic_version":"毒性版本",
    "healthy_version":"健康改写",
    "new_identity_sentence":"新身份语言"
  },
  "boundary_sentence":"适用于本场景的一句边界或修复表达",
  "action_options":[
    {"name":"路径名称","purpose":"目的","steps":["步骤"],"difficulty":"低/中/高","time_required":"时间","evidence_after_done":"证据"}
  ],
  "today_minimum_action":{
    "action":"今日最小行动",
    "time_required":"时间",
    "success_standard":"完成标准",
    "fallback":"更小备用版"
  },
  "reflection_questions":["复盘问题1","复盘问题2","复盘问题3"],
  "evidence_sentence":"证据墙句子",
  "user_choice_prompt":"邀请用户从多条路径中选择",
  "problem_tree":[],
  "action_tree":[]
}
''';
  }

  String _sceneInstructions(ShameScene scene) => switch (scene) {
        ShameScene.firstAid => '''
用户正处于强烈羞耻。不要长篇分析：先承认痛苦，打断“我整个人有问题”，强调“发生了一件事≠我就是这件事”，给一个30秒到2分钟的落地动作和一个按钮式下一步。''',
        ShameScene.eventRecord => '''
结构化拆分客观事实、情绪、身体反应、毒性解释、可能来源、健康提醒、责任边界和今日行动。来源只能作为可能性，不能武断归因。''',
        ShameScene.healthyTransformation => '''
把一句毒性羞耻语言依次转换为事实层、感受层、毒性羞耻层、健康羞耻层、责任层、行动层和新身份语言。''',
        ShameScene.innerChild => '''
识别当前事件与过去场景的相似感，说明孩子可能如何把外界失控内化成“是我不好”；指出当时可能需要的保护、解释、安慰、公平或陪伴；生成成人自我回应和今天的小保护行动，避免煽情与诱导记忆。''',
        ShameScene.innerCritic => '''
原样提取批判声音，识别完美主义、灾难化、读心、非黑即白、应该化、身份化或过度责任；探索可能来源和保护意图；保留保护功能，拿掉羞辱方式。''',
        ShameScene.deniedPart => '''
探索该部分何时出现、想保护什么、最怕什么、过度方式的代价，以及如何用更成熟方式表达。不要把愤怒、需要、欲望或脆弱本身定义为坏。''',
        ShameScene.relationshipBoundary => '''
根据关系分支区分事实、感受、合理批评、羞辱、控制、冷暴力、误会、真实伤害或投射；明确双方责任和边界；行动选项中必须给出温和版、清晰版、坚定版三种表达，不简单劝和或劝断。''',
        ShameScene.healthyResponsibility => '''
避免“我就是坏人”和“我完全没问题”两个极端。明确行为事实、影响、责任、不需要做的身份审判、道歉或补救、系统调整和防止重复的最小步骤。''',
        ShameScene.todoGoal => '''
识别表层目标及能力、失败、金钱、身体、关系、拖延、完美主义等羞耻；生成非羞耻化目标。problem_tree 至少5项，每项含 problem、possible_causes、not_identity_judgment。action_tree 至少5个行动方向，每项含 action_area、value、actions；动作必须具体、可绑定Todo、带时间和证据句。''',
        ShameScene.dailyReview => '''
复盘触发点、自动羞耻语言、哪怕一点点不同反应、完成的现实行动；未完成时分析阻碍并缩小下一步，不打分审判；生成今日证据句与明日最小行动。''',
      };

  ShameAiResult _fallback(
    ShameScene scene,
    String input,
    List<String> emotions,
    List<String> bodyReactions,
  ) {
    final isGoal = scene == ShameScene.todoGoal;
    return ShameAiResult(
      scene: scene,
      valueAnchor: '我不是错误本身',
      summary: input,
      eventFact: input,
      emotions: emotions,
      bodyReactions: bodyReactions,
      toxicLanguages: const ['把一次事件扩大成整个人的价值判断'],
      healthyMessage: '这件事可以提醒我承担、学习或保护边界，但不需要审判整个人。',
      facts: [input],
      interpretations: const ['别人一定会否定我——这是需要核实的解释'],
      identityJudgments: const ['我整个人都不行'],
      userResponsibilities: const ['确认事实，并选择一个自己能影响的下一步'],
      notUserResponsibilities: const ['他人的全部反应、不可控结果和对整个人格的否定'],
      repairableParts: const ['把任务缩小，获取反馈，完成一个现实步骤'],
      uncontrollableParts: const ['他人的想法和最终结果'],
      toxicVersion: '这件事没做好，所以我没有价值。',
      healthyVersion: '我正在经历困难；我可以承担具体责任，但我不是这件事本身。',
      identitySentence: '我是有限但有价值的人，我可以从一个小行动重新开始。',
      sourceVoice: '这可能是过去的评价、比较或失败经验留下的声音，需要由你确认。',
      protectionIntent: '它可能想避免再次失败或被拒绝。',
      boundarySentence: '我愿意听具体反馈，但不接受对我整个人的羞辱性评价。',
      actionOptions: const [
        ShameActionOption(
          name: '事实分离',
          purpose: '停止身份化',
          steps: ['写下一句不带评价的事实'],
          difficulty: '低',
          timeRequired: '2分钟',
          evidenceAfterDone: '我能看见事实，而不是立刻相信羞耻。',
        ),
        ShameActionOption(
          name: '现实修复',
          purpose: '承担可控责任',
          steps: ['圈出一个可控部分', '完成10分钟版本'],
          difficulty: '低',
          timeRequired: '10分钟',
          evidenceAfterDone: '我可以不完美地行动。',
        ),
      ],
      minimumAction: isGoal ? '把目标改写成一个10分钟可完成的任务' : '写下一句不带评价的事实',
      minimumTime: isGoal ? '10分钟' : '2分钟',
      successStandard: '完成并留下可见记录即可，不要求感觉立刻变好。',
      fallbackAction: '只写下时间、地点和发生了什么。',
      reflectionQuestions: const [
        '我在哪一刻把自己等同于错误？',
        '我真正需要承担什么？',
        '下一步怎样再小一点？',
      ],
      evidenceSentence: '今天我没有继续隐藏，我把羞耻还原成了一个可以处理的现实问题。',
      userChoicePrompt: '你想先做“事实分离”，还是“现实修复”？',
      problemTree: isGoal
          ? const [
              {
                'problem': '目标仍然过大或模糊',
                'possible_causes': ['缺少下一步定义', '完美主义阻止开始'],
                'not_identity_judgment': '目标不清楚不等于你没有能力。',
              },
              {
                'problem': '害怕结果或评价',
                'possible_causes': ['拒绝敏感', '过去失败经验'],
                'not_identity_judgment': '害怕不等于不能行动。',
              },
            ]
          : const [],
      actionTree: isGoal
          ? const [
              {
                'action_area': '现实澄清',
                'value': '把人格审判还原为现实问题',
                'actions': ['写下目标完成标准', '定义10分钟下一步'],
              },
              {
                'action_area': '低风险暴露',
                'value': '允许不完美地行动',
                'actions': ['完成一个低风险版本', '向可信任的人获取反馈'],
              },
            ]
          : const [],
    );
  }
}
