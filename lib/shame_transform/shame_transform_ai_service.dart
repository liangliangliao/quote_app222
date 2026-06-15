import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'shame_transform_models.dart';
import 'shame_transform_prompt_config.dart';

class ShameTransformAiService {
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _ai = UnifiedAiService();
  final ShameTransformPromptConfig _prompts = ShameTransformPromptConfig();

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
    final prompt = await _buildPrompt(
      scene: scene,
      input: input,
      intensity: intensity,
      emotions: emotions,
      bodyReactions: bodyReactions,
      relationshipMode: relationshipMode,
      deniedPart: deniedPart,
    );
    final variables = _variables(
      scene: scene,
      input: input,
      intensity: intensity,
      emotions: emotions,
      bodyReactions: bodyReactions,
      relationshipMode: relationshipMode,
      deniedPart: deniedPart,
    );
    final systemPrompt = _prompts.render(
      await _prompts.getPrompt(ShameTransformPromptConfig.globalId),
      variables,
    );
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'shame_transform.${scene.key}',
        systemPrompt: systemPrompt,
        maxTokens: scene == ShameScene.todoGoal ? 5200 : 3400,
        expectJson: true,
        temperature: 0.3,
      );
      return ShameAiResult.fromJson(extractJsonObject(raw), scene);
    } catch (_) {
      return _fallback(scene, input, emotions, bodyReactions);
    }
  }

  Future<String> _buildPrompt({
    required ShameScene scene,
    required String input,
    required int intensity,
    required List<String> emotions,
    required List<String> bodyReactions,
    required String relationshipMode,
    required String deniedPart,
  }) {
    final variables = _variables(
      scene: scene,
      input: input,
      intensity: intensity,
      emotions: emotions,
      bodyReactions: bodyReactions,
      relationshipMode: relationshipMode,
      deniedPart: deniedPart,
    );
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
    final scenePrompt = _prompts.render(
      await _prompts.getPrompt(
        ShameTransformPromptConfig.scenePromptId(scene),
      ),
      variables,
    );
    final commonOutput = _prompts.render(
      await _prompts.getPrompt(ShameTransformPromptConfig.commonOutputId),
      variables,
    );
    final specializedOutput = scene == ShameScene.firstAid
        ? _prompts.render(
            await _prompts
                .getPrompt(ShameTransformPromptConfig.firstAidOutputId),
            variables,
          )
        : scene == ShameScene.todoGoal
            ? _prompts.render(
                await _prompts
                    .getPrompt(ShameTransformPromptConfig.actionTreeOutputId),
                variables,
              )
            : '';
    return '''
$context
$scenePrompt
$commonOutput
$specializedOutput
''';
  }

  Map<String, String> _variables({
    required ShameScene scene,
    required String input,
    required int intensity,
    required List<String> emotions,
    required List<String> bodyReactions,
    required String relationshipMode,
    required String deniedPart,
  }) =>
      {
        'scene': scene.title,
        'scene_key': scene.key,
        'intensity': '$intensity',
        'user_input': input,
        'emotions': emotions.join('、'),
        'body_reactions': bodyReactions.join('、'),
        'relationship_mode': relationshipMode,
        'denied_part': deniedPart,
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
      shamePatterns: const ['身份化羞耻'],
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
