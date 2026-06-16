import '../services/unified_ai_service.dart';
import '../utils/deepseek_logger.dart';
import 'shame_transform_models.dart';
import 'shame_transform_prompt_config.dart';

class ShameTransformAiService {
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
    final config = await _ai.resolveGlobalConfig();
    if (!config.available) {
      return _fallback(
        scene,
        input,
        emotions,
        bodyReactions,
        provider: config.provider,
        modelLabel: config.label,
        reason: '当前全局 AI 提供商 ${config.label} 没有可用密钥。请在设置页完成全局 AI 配置。',
      );
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
    String raw = '';
    try {
      raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'shame_transform.${scene.key}',
        systemPrompt: systemPrompt,
        maxTokens: scene == ShameScene.todoGoal ? 5200 : 3400,
        expectJson: true,
        temperature: 0.3,
      );
      if (raw.trim().isEmpty) {
        return _fallback(
          scene,
          input,
          emotions,
          bodyReactions,
          provider: config.provider,
          modelLabel: config.label,
          reason: 'AI 接口返回了空内容。请到日志页查看 ${config.label} 请求记录。',
        );
      }
      try {
        final result = ShameAiResult.fromJson(
          extractJsonObject(raw),
          scene,
        ).copyWithSource(
          usedFallback: false,
          provider: config.provider,
          modelLabel: config.label,
          rawResponse: raw,
        );
        if (result.hasMeaningfulAiContent) return result;
      } catch (_) {
        // Continue with one JSON normalization attempt below.
      }
      final repairedRaw = await _repairJson(
        raw: raw,
        scene: scene,
        config: config,
      );
      if (repairedRaw.trim().isNotEmpty) {
        final repaired = ShameAiResult.fromJson(
          extractJsonObject(repairedRaw),
          scene,
        ).copyWithSource(
          usedFallback: false,
          provider: config.provider,
          modelLabel: config.label,
          rawResponse: repairedRaw,
        );
        if (repaired.hasMeaningfulAiContent) return repaired;
      }
      return _fallback(
        scene,
        input,
        emotions,
        bodyReactions,
        provider: config.provider,
        modelLabel: config.label,
        reason: 'AI 已返回内容，但缺少事件事实、健康改写、最小行动或证据句，自动修复后仍无法完整解析。',
        rawResponse: raw,
      );
    } catch (error, stackTrace) {
      await DeepSeekLogger.logError(
        module: 'shame_transform.${scene.key}',
        endpoint: config.endpoint,
        error: error,
        stackTrace: stackTrace,
        provider: config.provider,
        model: config.model,
      );
      return _fallback(
        scene,
        input,
        emotions,
        bodyReactions,
        provider: config.provider,
        modelLabel: config.label,
        reason: 'AI 请求或结果解析失败：$error',
        rawResponse: raw,
      );
    }
  }

  Future<String> _repairJson({
    required String raw,
    required ShameScene scene,
    required UnifiedAiResolvedConfig config,
  }) async {
    try {
      final template = await _prompts.getPrompt(
        ShameTransformPromptConfig.jsonRepairId,
      );
      final repairPrompt = _prompts.render(template, {
        'scene': scene.title,
        'scene_key': scene.key,
        'raw_response': raw,
      });
      return await _ai.generateText(
        prompt: repairPrompt,
        purpose: 'shame_transform.${scene.key}.json_repair',
        maxTokens: scene == ShameScene.todoGoal ? 5200 : 3400,
        expectJson: true,
        temperature: 0.1,
        forcedProvider: config.provider,
        forcedModel: config.model,
      );
    } catch (_) {
      return '';
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
  }) async {
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
    List<String> bodyReactions, {
    required String provider,
    required String modelLabel,
    required String reason,
    String rawResponse = '',
  }) {
    final isGoal = scene == ShameScene.todoGoal;
    return ShameAiResult(
      scene: scene,
      valueAnchor: '我不是错误本身，也不是羞耻里的自动防御反应本身',
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
          shameExposureLevel: '低',
          compassRisk: '攻击自己',
          truePrideAfterDone: '我承受了看见事实的不舒服，没有继续用身份审判吞没自己。',
        ),
        ShameActionOption(
          name: '现实修复',
          purpose: '承担可控责任',
          steps: ['圈出一个可控部分', '完成10分钟版本'],
          difficulty: '低',
          timeRequired: '10分钟',
          evidenceAfterDone: '我可以不完美地行动。',
          shameExposureLevel: '低',
          compassRisk: '回避',
          truePrideAfterDone: '我带着不完美推进了现实，而不是等到完全不怕才行动。',
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
      originalPositiveAffects: const ['表达', '连接', '行动欲望'],
      originalDesire: '你可能原本想表达、靠近、完成或获得回应；这需要由你确认。',
      blockingPoint: '积极情感在评价、失败、拒绝或没有回应的瞬间被打断。',
      shameTrigger: '事件被解释为“我整个人不好”的瞬间。',
      selfContractions: const ['想退缩', '想回避', '自责'],
      compassPrimary: isGoal ? '回避' : '攻击自己',
      compassSecondary: '退缩',
      compassEvidence: const ['出现身份化自责或想隐藏/拖延的倾向'],
      compassShortFunction: '短期减少暴露、失败或被评价的痛感。',
      compassLongCost: '长期可能减少连接、学习、表达和真实行动机会。',
      compassTurningDirection: '从自动防御转向一个低风险、可验证的小行动。',
      interestRecoveryAction: '用2分钟接触原本想做的事情，不评价成果。',
      joyRecoveryAction: '记录一个身体上稍微放松或舒服的瞬间。',
      connectionAction: '向安全对象或 AI 表达一句真实感受，不要求解释完整。',
      exposureLevel: '低',
      affectRecoveryWhy: '羞耻会切断兴趣、喜悦和连接；小行动让积极情感重新有入口。',
      minimumShameRisk: '承受一点点不完美、被看见或面对现实的风险。',
      minimumTruePrideStandard: '不是结果完美，而是带着羞耻仍完成一次现实推进。',
      truePrideAction: isGoal ? '把目标改写成一个10分钟可完成的任务' : '写下一句不带评价的事实',
      difficultyCarried: '承受了羞耻和不想面对的感觉。',
      abilityReflected: '事实分离、情绪承受、低风险行动的能力。',
      positiveAffectRestored: '行动感、表达感或一点点连接。',
      truePrideSentence: '我不是等到完全不羞耻才行动，而是在羞耻中完成了一步真实推进。',
      safetyNote: '无明显紧急风险；如出现自伤、伤人或现实危险，请优先联系可信任的人、当地紧急服务或专业支持。',
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
      usedFallback: true,
      provider: provider,
      modelLabel: modelLabel,
      fallbackReason: reason,
      rawResponse: rawResponse,
    );
  }
}
