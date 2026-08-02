import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../data/dao.dart';
import '../data/kv_dao.dart';
import '../utils/deepseek_logger.dart';
import '../services/global_ai_settings.dart';
import '../services/global_ai_request_settings.dart';
import '../services/unified_ai_service.dart';
import 'action_engine/models/action_engine_models.dart';
import 'concept_engine_models.dart';

class ConceptEngineRuntimeConfig {
  final String provider; // deepseek / openai / openrouter / edenai / xgrok / gemini / azure
  final String apiKey;
  final String endpoint;
  final String model;

  /// Azure 专用：真正下发给服务端的部署名。其它服务商与 [model] 相同。
  final String deployment;

  /// 鉴权头。OpenAI 系是 `Authorization: Bearer`，Azure 是 `api-key`。
  final Map<String, String> authHeaders;
  final int timeoutSeconds;
  final int sceneCount;
  final int turnTarget;
  final int parseMinIntuitiveDescriptions;
  final int parseMinBehaviors;
  final int parseRetryCount;
  final int behaviorChainMinNodes;
  final int behaviorChainMaxNodes;
  final int parseMaxTokens;
  final int sceneMaxTokens;
  final int turnMaxTokens;
  final int replayMaxTokens;
  final int behaviorChainMaxTokens;
  final int? globalMaxOutputTokens;
  final double? globalTemperature;
  final double? globalTopP;
  final String promptExtra;
  final String parsePromptTemplate;
  final String scenePromptTemplate;
  final String turnPromptTemplate;
  final String replayPromptTemplate;
  final String behaviorChainPromptTemplate;
  final String transportMode; // direct / proxy
  final String proxyEndpoint;
  final String proxyAuthToken;

  const ConceptEngineRuntimeConfig({
    required this.provider,
    required this.apiKey,
    required this.endpoint,
    required this.model,
    String? deployment,
    this.authHeaders = const <String, String>{},
    required this.timeoutSeconds,
    required this.sceneCount,
    required this.turnTarget,
    required this.parseMinIntuitiveDescriptions,
    required this.parseMinBehaviors,
    required this.parseRetryCount,
    required this.behaviorChainMinNodes,
    required this.behaviorChainMaxNodes,
    required this.parseMaxTokens,
    required this.sceneMaxTokens,
    required this.turnMaxTokens,
    required this.replayMaxTokens,
    required this.behaviorChainMaxTokens,
    required this.globalMaxOutputTokens,
    required this.globalTemperature,
    required this.globalTopP,
    required this.promptExtra,
    required this.parsePromptTemplate,
    required this.scenePromptTemplate,
    required this.turnPromptTemplate,
    required this.replayPromptTemplate,
    required this.behaviorChainPromptTemplate,
    required this.transportMode,
    required this.proxyEndpoint,
    required this.proxyAuthToken,
  }) : deployment = deployment ?? model;

  String get providerLabel => provider == 'openai'
      ? 'OpenAI'
      : provider == 'openrouter'
          ? 'OpenRouter'
          : provider == 'edenai'
              ? 'Eden AI'
              : provider == 'xgrok'
                  ? 'xGrok'
                  : provider == 'gemini'
                      ? 'Gemini'
                      : provider == 'azure'
                          ? 'Azure'
                          : 'DeepSeek';
  bool get useProxy => transportMode == 'proxy' && proxyEndpoint.trim().isNotEmpty;

  Map<String, String> get effectiveAuthHeaders =>
      authHeaders.isNotEmpty ? authHeaders : <String, String>{'Authorization': 'Bearer $apiKey'};
}


class GatewayHealthResult {
  final bool ok;
  final int? statusCode;
  final String endpoint;
  final String message;
  final Map<String, dynamic>? body;

  const GatewayHealthResult({
    required this.ok,
    required this.endpoint,
    required this.message,
    this.statusCode,
    this.body,
  });
}

class ConceptEngineService {
  final ConfigDao _configDao = ConfigDao();
  final KeyValueDao _kvDao = KeyValueDao();
  final Random _random = Random();
  final GlobalAiSettings _globalAiSettings = GlobalAiSettings();
  final GlobalAiRequestSettings _globalAiRequestSettings = GlobalAiRequestSettings();
  final UnifiedAiService _unifiedAiService = UnifiedAiService();

  static const String transportDirect = 'direct';
  static const String transportProxy = 'proxy';

  String _normalizeProvider(String provider) {
    final p = provider.trim().toLowerCase();
    if (p == 'openai') return 'openai';
    if (p == 'openrouter') return 'openrouter';
    if (p == 'edenai') return 'edenai';
    if (p == 'xgrok' || p == 'xai' || p == 'grok') return 'xgrok';
    if (p == 'gemini' || p == 'google' || p == 'googleai') return 'gemini';
    if (p == 'azure' || p == 'azureopenai' || p == 'azure_openai' || p == 'foundry' || p == 'msfoundry') {
      return 'azure';
    }
    return 'deepseek';
  }

  String _promptKey(String base, String provider) => 'ce_prompt_${base}_${_normalizeProvider(provider)}';

  String? _legacyPromptKey(String base) {
    switch (base) {
      case 'extra':
        return 'ce_prompt_extra';
      case 'parse_template':
        return 'ce_prompt_parse_template';
      case 'scene_template':
        return 'ce_prompt_scene_template';
      case 'turn_template':
        return 'ce_prompt_turn_template';
      case 'replay_template':
        return 'ce_prompt_replay_template';
      case 'behavior_chain_template':
        return 'ce_prompt_behavior_chain_template';
      default:
        return null;
    }
  }

  Future<int> _readIntSetting(String key, int fallback) async {
    final raw = (await _kvDao.getString(key))?.trim();
    return int.tryParse(raw ?? '') ?? fallback;
  }

  Future<String> loadPromptTemplateByBase(String base, {String? provider}) async {
    final effectiveProvider = (provider?.trim().isNotEmpty == true)
        ? provider!.trim().toLowerCase()
        : (await loadRuntimeConfig()).provider;
    final providerValue = ((await _kvDao.getString(_promptKey(base, effectiveProvider))) ?? '').trim();
    if (providerValue.isNotEmpty) return providerValue;
    final legacyKey = _legacyPromptKey(base);
    if (legacyKey != null) {
      final legacyValue = ((await _kvDao.getString(legacyKey)) ?? '').trim();
      if (legacyValue.isNotEmpty) return legacyValue;
    }
    return defaultPromptTemplate(base.replaceAll('_template', ''));
  }

  Future<void> savePromptTemplateByBase({
    required String base,
    required String template,
    String? provider,
  }) async {
    final effectiveProvider = (provider?.trim().isNotEmpty == true)
        ? provider!.trim().toLowerCase()
        : (await loadRuntimeConfig()).provider;
    await _kvDao.setString(_promptKey(base, effectiveProvider), template.trim());
  }

  static String defaultPromptTemplate(String kind) {
    switch (kind) {
      case 'parse':
      case 'parse_template':
        return _defaultParsePromptStatic();
      case 'scene':
      case 'scene_template':
        return _defaultScenePromptStatic();
      case 'turn':
      case 'turn_template':
        return _defaultTurnPromptStatic();
      case 'replay':
      case 'replay_template':
        return _defaultReplayPromptStatic();
      case 'behavior_chain':
      case 'behavior_chain_template':
        return _defaultBehaviorChainPromptStatic();
      default:
        return '';
    }
  }

  Future<ConceptEngineRuntimeConfig> loadRuntimeConfig() async {
    final globalState = await _globalAiSettings.getState();
    final provider = _normalizeProvider(globalState['provider'] ?? 'deepseek');
    final resolved = await _unifiedAiService.resolveGlobalConfig(
      forcedProvider: provider,
      forcedModel: (globalState['model'] ?? '').trim(),
    );

    final requestConfig = await _globalAiRequestSettings.getConfig();
    final timeoutSeconds = requestConfig.timeoutSeconds ?? await _readIntSetting('ce_timeout_seconds', 60);
    final sceneCount = await _readIntSetting('ce_scene_count', 3);
    final turnTarget = await _readIntSetting('ce_turn_target', 6);
    final parseMinIntuitiveDescriptions = await _readIntSetting('ce_parse_min_intuitive', 10);
    final parseMinBehaviors = await _readIntSetting('ce_parse_min_behaviors', 10);
    final parseRetryCount = await _readIntSetting('ce_parse_retry_count', 2);
    final behaviorChainMinNodes = await _readIntSetting('ce_behavior_chain_min_nodes', 4);
    final behaviorChainMaxNodesRaw = await _readIntSetting('ce_behavior_chain_max_nodes', 8);
    final behaviorChainMaxNodes = behaviorChainMaxNodesRaw < behaviorChainMinNodes ? behaviorChainMinNodes : behaviorChainMaxNodesRaw;
    final parseMaxTokens = await _readIntSetting('ce_parse_max_tokens', 3200);
    final sceneMaxTokens = await _readIntSetting('ce_scene_max_tokens', 4000);
    final turnMaxTokens = await _readIntSetting('ce_turn_max_tokens', 2500);
    final replayMaxTokens = await _readIntSetting('ce_replay_max_tokens', 3500);
    final behaviorChainMaxTokens = await _readIntSetting('ce_behavior_chain_max_tokens', 2200);

    final promptExtra = ((await _kvDao.getString(_promptKey('extra', provider))) ??
            (await _kvDao.getString('ce_prompt_extra')) ??
            '')
        .trim();
    final parsePromptTemplate = await loadPromptTemplateByBase('parse_template', provider: provider);
    final scenePromptTemplate = await loadPromptTemplateByBase('scene_template', provider: provider);
    final turnPromptTemplate = await loadPromptTemplateByBase('turn_template', provider: provider);
    final replayPromptTemplate = await loadPromptTemplateByBase('replay_template', provider: provider);
    final behaviorChainPromptTemplate = await loadPromptTemplateByBase('behavior_chain_template', provider: provider);

    final transportMode = (((await _kvDao.getString('ce_transport_mode')) ?? transportDirect).trim().toLowerCase() == transportProxy)
        ? transportProxy
        : transportDirect;
    final proxyEndpoint = ((await _kvDao.getString('ce_proxy_endpoint')) ?? '').trim();
    final proxyAuthToken = ((await _kvDao.getString('ce_proxy_token')) ?? '').trim();

    return ConceptEngineRuntimeConfig(
      provider: provider,
      apiKey: resolved.apiKey,
      endpoint: resolved.endpoint,
      model: resolved.model,
      deployment: resolved.deployment,
      authHeaders: resolved.effectiveAuthHeaders,
      timeoutSeconds: timeoutSeconds < 15 ? 15 : timeoutSeconds,
      sceneCount: sceneCount.clamp(2, 5).toInt(),
      turnTarget: turnTarget.clamp(4, 12).toInt(),
      parseMinIntuitiveDescriptions: parseMinIntuitiveDescriptions.clamp(3, 30).toInt(),
      parseMinBehaviors: parseMinBehaviors.clamp(3, 30).toInt(),
      parseRetryCount: parseRetryCount.clamp(1, 4).toInt(),
      behaviorChainMinNodes: behaviorChainMinNodes.clamp(2, 12).toInt(),
      behaviorChainMaxNodes: behaviorChainMaxNodes.clamp(2, 16).toInt(),
      parseMaxTokens: parseMaxTokens.clamp(500, 12000).toInt(),
      sceneMaxTokens: sceneMaxTokens.clamp(500, 12000).toInt(),
      turnMaxTokens: turnMaxTokens.clamp(500, 12000).toInt(),
      replayMaxTokens: replayMaxTokens.clamp(500, 12000).toInt(),
      behaviorChainMaxTokens: behaviorChainMaxTokens.clamp(500, 12000).toInt(),
      globalMaxOutputTokens: requestConfig.maxOutputTokens,
      globalTemperature: requestConfig.temperature,
      globalTopP: requestConfig.topP,
      promptExtra: promptExtra,
      parsePromptTemplate: parsePromptTemplate,
      scenePromptTemplate: scenePromptTemplate,
      turnPromptTemplate: turnPromptTemplate,
      replayPromptTemplate: replayPromptTemplate,
      behaviorChainPromptTemplate: behaviorChainPromptTemplate,
      transportMode: transportMode,
      proxyEndpoint: proxyEndpoint,
      proxyAuthToken: proxyAuthToken,
    );
  }

  Future<String> loadBehaviorChainPromptTemplate({String? provider}) async {
    return loadPromptTemplateByBase('behavior_chain_template', provider: provider);
  }

  Future<void> saveBehaviorChainPromptTemplate({
    required String template,
    String? provider,
  }) async {
    await savePromptTemplateByBase(
      base: 'behavior_chain_template',
      template: template,
      provider: provider,
    );
  }

  Future<ActionConcept> generateActionConceptTreeOverview({
    required String concept,
    required String domain,
    required String goal,
    required List<String> dimensions,
    String? sessionId,
  }) async {
    final cfg = await loadRuntimeConfig();
    _ensureAuth(cfg);

    final payload = {
      'concept': concept,
      'domain': domain,
      'goal': goal,
      'dimensions': dimensions,
      'min_action_count': 10,
    };

    final attempts = <Map<String, dynamic>>[
      {
        'prompt': _systemPromptFor(template: '', fallback: _defaultActionTreeOverviewPrompt(), cfg: cfg),
        'tokens': 1800,
        'timeout': max(cfg.timeoutSeconds, 120),
        'logModule': 'concept_engine.action_tree.overview',
        'useJsonResponseFormat': true,
        'modelOverride': null,
      },
      {
        'prompt': _systemPromptFor(template: '', fallback: _defaultActionTreeOverviewFastPrompt(), cfg: cfg),
        'tokens': 1300,
        'timeout': max(cfg.timeoutSeconds, 75),
        'logModule': 'concept_engine.action_tree.overview.fast_retry',
        'useJsonResponseFormat': true,
        'modelOverride': null,
      },
      {
        'prompt': _systemPromptFor(template: '', fallback: _defaultActionTreeOverviewFastPrompt(), cfg: cfg),
        'tokens': 1200,
        'timeout': max(cfg.timeoutSeconds, 75),
        'logModule': 'concept_engine.action_tree.overview.plain_retry',
        'useJsonResponseFormat': false,
        'modelOverride': null,
      },
    ];
    Object? lastError;

    for (final attempt in attempts) {
      try {
        final content = await _postForJson(
          cfg: cfg,
          systemPrompt: attempt['prompt'] as String,
          userPayload: payload,
          maxTokens: attempt['tokens'] as int,
          logModule: attempt['logModule'] as String,
          sessionId: sessionId,
          timeoutOverrideSeconds: attempt['timeout'] as int,
          useJsonResponseFormat: attempt['useJsonResponseFormat'] as bool,
          modelOverride: attempt['modelOverride'] as String?,
        );
        return ActionConcept.fromJson(content);
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('生成行动树概览失败');
  }

  Future<ActionDirection> expandActionDirection({
    required String concept,
    required String domain,
    required String goal,
    required List<String> dimensions,
    required ActionDirection direction,
    String? sessionId,
  }) async {
    final cfg = await loadRuntimeConfig();
    _ensureAuth(cfg);
    final payload = {
      'concept': concept,
      'domain': domain,
      'goal': goal,
      'dimensions': dimensions,
      'direction': direction.toJson(),
    };
    final prompts = [
      _systemPromptFor(template: '', fallback: _defaultActionDirectionExpandPrompt(), cfg: cfg),
      _systemPromptFor(template: '', fallback: _defaultActionDirectionExpandFastPrompt(), cfg: cfg),
    ];
    final tokenCandidates = [2200, 1600];
    final timeoutCandidates = [max(cfg.timeoutSeconds, 75), max(cfg.timeoutSeconds, 50)];
    Object? lastError;
    for (var i = 0; i < prompts.length; i++) {
      try {
        final content = await _postForJson(
          cfg: cfg,
          systemPrompt: prompts[i],
          userPayload: payload,
          maxTokens: tokenCandidates[i],
          logModule: i == 0 ? 'concept_engine.action_tree.expand' : 'concept_engine.action_tree.expand.fast_retry',
          sessionId: sessionId,
          timeoutOverrideSeconds: timeoutCandidates[i],
        );
        return ActionDirection.fromJson(content);
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('展开行动方向失败');
  }


  Future<ActionDirection> expandActionDirectionMorePaths({
    required String concept,
    required String domain,
    required String goal,
    required List<String> dimensions,
    required ActionDirection direction,
    String? sessionId,
  }) async {
    final cfg = await loadRuntimeConfig();
    _ensureAuth(cfg);
    final payload = {
      'concept': concept,
      'domain': domain,
      'goal': goal,
      'dimensions': dimensions,
      'direction': direction.toJson(),
      'target': 'more_paths',
    };
    final prompts = [
      _systemPromptFor(template: '', fallback: _defaultActionDirectionMorePathsPrompt(), cfg: cfg),
      _systemPromptFor(template: '', fallback: _defaultActionDirectionMorePathsFastPrompt(), cfg: cfg),
    ];
    final tokenCandidates = [1800, 1300];
    final timeoutCandidates = [max(cfg.timeoutSeconds, 60), max(cfg.timeoutSeconds, 45)];
    Object? lastError;
    for (var i = 0; i < prompts.length; i++) {
      try {
        final content = await _postForJson(
          cfg: cfg,
          systemPrompt: prompts[i],
          userPayload: payload,
          maxTokens: tokenCandidates[i],
          logModule: i == 0 ? 'concept_engine.action_tree.more_paths' : 'concept_engine.action_tree.more_paths.fast_retry',
          sessionId: sessionId,
          timeoutOverrideSeconds: timeoutCandidates[i],
        );
        return ActionDirection.fromJson(content);
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('扩展更多实现路径失败');
  }

  Future<List<ActionStep>> expandCustomActionStep({
    required String concept,
    required String domain,
    required String goal,
    required List<String> dimensions,
    required String customStep,
    String? sessionId,
  }) async {
    final cfg = await loadRuntimeConfig();
    _ensureAuth(cfg);
    final payload = {
      'concept': concept,
      'domain': domain,
      'goal': goal,
      'dimensions': dimensions,
      'custom_step': customStep,
    };
    final content = await _postForJson(
      cfg: cfg,
      systemPrompt: _systemPromptFor(template: '', fallback: _defaultCustomStepExpandPrompt(), cfg: cfg),
      userPayload: payload,
      maxTokens: 1200,
      logModule: 'concept_engine.action_tree.expand_custom',
      sessionId: sessionId,
      timeoutOverrideSeconds: max(cfg.timeoutSeconds, 45),
    );
    return ((content['steps'] as List?) ?? const [])
        .map((e) => ActionStep.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ConceptParseResult> parseConcept({
    required String concept,
    required String domain,
    required String goal,
    String? sessionId,
  }) async {
    final cfg = await loadRuntimeConfig();
    _ensureAuth(cfg);

    final systemPrompt = _systemPromptFor(
      template: cfg.parsePromptTemplate,
      fallback: _defaultParsePrompt(),
      cfg: cfg,
    );

    Map<String, dynamic>? lastContent;
    Object? lastError;
    for (var i = 0; i < cfg.parseRetryCount; i++) {
      try {
        final content = await _postForJson(
          cfg: cfg,
          systemPrompt: systemPrompt,
          userPayload: {
            'concept': concept,
            'domain': domain,
            'goal': goal,
          },
          maxTokens: cfg.parseMaxTokens,
          logModule: i == 0 ? 'concept_engine.parse' : 'concept_engine.parse.retry_${i + 1}',
          sessionId: sessionId,
        );
        lastContent = content;
        if (_parseHasEnoughExamples(content, cfg)) {
          return ConceptParseResult.fromJson(content);
        }
      } catch (e) {
        lastError = e;
      }
    }

    if (lastContent != null) {
      return ConceptParseResult.fromJson(lastContent!);
    }
    throw lastError ?? Exception('概念解析失败');
  }


  Future<BehaviorActionChain> generateBehaviorActionChain({
    required String concept,
    required String domain,
    required String goal,
    required String behavior,
    String? sessionId,
  }) async {
    final cfg = await loadRuntimeConfig();
    _ensureAuth(cfg);

    final systemPrompt = _systemPromptFor(
      template: cfg.behaviorChainPromptTemplate,
      fallback: _defaultBehaviorChainPromptStatic(),
      cfg: cfg,
    );

    final content = await _postForJson(
      cfg: cfg,
      systemPrompt: systemPrompt,
      userPayload: {
        'concept': concept,
        'domain': domain,
        'goal': goal,
        'behavior': behavior,
      },
      maxTokens: cfg.behaviorChainMaxTokens,
      logModule: 'concept_engine.behavior_chain',
      sessionId: sessionId,
      timeoutOverrideSeconds: max(cfg.timeoutSeconds, 45),
    );

    final chain = BehaviorActionChain.fromJson({
      ...content,
      'concept': content['concept'] ?? concept,
      'domain': content['domain'] ?? domain,
      'goal': content['goal'] ?? goal,
      'behavior': content['behavior'] ?? behavior,
      'chain_id': (content['chain_id'] ?? '').toString().trim().isEmpty
          ? 'bac_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
          : content['chain_id'],
      'title': (content['title'] ?? content['chain_title'] ?? '').toString().trim().isEmpty
          ? '行为行动链'
          : (content['title'] ?? content['chain_title']),
      'summary': (content['summary'] ?? '').toString(),
      'created_at': content['created_at'] ?? DateTime.now().toIso8601String(),
    });

    final normalizedNodes = <BehaviorActionNode>[];
    final sourceNodes = chain.nodes.take(cfg.behaviorChainMaxNodes).toList();
    for (var i = 0; i < sourceNodes.length; i++) {
      final node = sourceNodes[i];
      normalizedNodes.add(node.copyWith(
        id: node.id.trim().isEmpty ? 'node_${i + 1}' : node.id,
        title: node.title.trim().isEmpty ? '节点 ${i + 1}' : node.title,
        detail: node.detail.trim(),
        status: _normalizeBehaviorNodeStatus(node.status),
      ));
    }

    return chain.copyWith(nodes: normalizedNodes);
  }

  String _normalizeBehaviorNodeStatus(String raw) {
    switch (raw.trim()) {
      case '进行中':
      case '失败':
      case '成功':
      case '未开始':
        return raw.trim();
      default:
        return '未开始';
    }
  }

  bool _parseHasEnoughExamples(Map<String, dynamic> content, ConceptEngineRuntimeConfig cfg) {
    int countFor(String key) {
      final raw = content[key];
      if (raw is! List) return 0;
      return raw.where((e) => e.toString().trim().isNotEmpty).map((e) => e.toString().trim()).toSet().length;
    }

    return countFor('intuitive_descriptions') >= cfg.parseMinIntuitiveDescriptions &&
        countFor('behaviors') >= cfg.parseMinBehaviors;
  }

  Future<List<SceneOption>> generateScenes({
    required String concept,
    required String domain,
    required String goal,
    required ConceptParseResult parseResult,
    String? sessionId,
  }) async {
    final cfg = await loadRuntimeConfig();
    _ensureAuth(cfg);

    final systemPrompt = _systemPromptFor(
      template: cfg.scenePromptTemplate,
      fallback: _defaultScenePrompt(),
      cfg: cfg,
    );

    final content = await _postForJson(
      cfg: cfg,
      systemPrompt: systemPrompt,
      userPayload: {
        'concept': concept,
        'domain': domain,
        'goal': goal,
        'parse_result': parseResult.toJson(),
        'scene_count': cfg.sceneCount,
      },
      maxTokens: cfg.sceneMaxTokens,
      logModule: 'concept_engine.scenes',
      sessionId: sessionId,
    );
    return ((content['scenes'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => SceneOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ChallengeTurnResult> runTurn({
    required SceneOption scene,
    required ChallengeWorldState state,
    required List<ChallengeMessage> history,
    required String userInput,
    String? sessionId,
  }) async {
    final cfg = await loadRuntimeConfig();
    _ensureAuth(cfg);

    final trimmedHistory = history.length <= 8 ? history : history.sublist(history.length - 8);

    final systemPrompt = _systemPromptFor(
      template: cfg.turnPromptTemplate,
      fallback: _defaultTurnPrompt(),
      cfg: cfg,
    );

    final payload = {
      'scene': scene.toJson(),
      'state': state.toJson(),
      'history': trimmedHistory.map((e) => e.toJson()).toList(),
      'user_input': userInput,
      'turn_target': cfg.turnTarget,
    };

    final content = await _postForJson(
      cfg: cfg,
      systemPrompt: systemPrompt,
      userPayload: payload,
      maxTokens: cfg.turnMaxTokens,
      logModule: 'concept_engine.turn',
      sessionId: sessionId,
    );

    final delta = Map<String, dynamic>.from((content['state_delta'] ?? const {}) as Map);
    final nextState = _applyDelta(state, delta).copyWith(
      turnNo: state.turnNo + 1,
      finished: content['finished'] == true,
      finishReason: (content['finish_reason'] ?? '').toString(),
    );

    final autoFinished = nextState.goalProgress >= 85 || nextState.timeLeft <= 0 || nextState.riskScore >= 90;
    final mergedState = nextState.copyWith(
      finished: nextState.finished || autoFinished,
      finishReason: nextState.finished
          ? nextState.finishReason
          : autoFinished
              ? (nextState.goalProgress >= 85
                  ? 'goal_achieved'
                  : nextState.timeLeft <= 0
                      ? 'time_exhausted'
                      : 'risk_exploded')
              : '',
    );

    return ChallengeTurnResult(
      assistantReply: (content['assistant_reply'] ?? '').toString(),
      state: mergedState,
      actionTags: ((content['action_tags'] as List?) ?? const []).map((e) => e.toString()).toList(),
      triggeredEvents: ((content['triggered_events'] as List?) ?? const []).map((e) => e.toString()).toList(),
    );
  }

  Future<ReplayResult> analyzeReplay({
    required String concept,
    required String domain,
    required String goal,
    required SceneOption scene,
    required ChallengeWorldState state,
    required List<ChallengeMessage> history,
    String? sessionId,
  }) async {
    final cfg = await loadRuntimeConfig();
    _ensureAuth(cfg);

    final systemPrompt = _systemPromptFor(
      template: cfg.replayPromptTemplate,
      fallback: _defaultReplayPrompt(),
      cfg: cfg,
    );

    final content = await _postForJson(
      cfg: cfg,
      systemPrompt: systemPrompt,
      userPayload: {
        'concept': concept,
        'domain': domain,
        'goal': goal,
        'scene': scene.toJson(),
        'final_state': state.toJson(),
        'history': history.map((e) => e.toJson()).toList(),
      },
      maxTokens: cfg.replayMaxTokens,
      logModule: 'concept_engine.replay',
      sessionId: sessionId,
    );
    return ReplayResult.fromJson(content);
  }

  String _systemPromptFor({
    required String template,
    required String fallback,
    required ConceptEngineRuntimeConfig cfg,
  }) {
    final raw = template.trim().isEmpty ? fallback : template.trim();
    return _renderPrompt(raw, cfg);
  }

  String _renderPrompt(String template, ConceptEngineRuntimeConfig cfg) {
    return template
        .replaceAll('{{sceneCount}}', cfg.sceneCount.toString())
        .replaceAll('{{turnTarget}}', cfg.turnTarget.toString())
        .replaceAll('{{provider}}', cfg.provider)
        .replaceAll('{{providerLabel}}', cfg.providerLabel)
        .replaceAll('{{transportMode}}', cfg.transportMode)
        .replaceAll('{{parseMinIntuitive}}', cfg.parseMinIntuitiveDescriptions.toString())
        .replaceAll('{{parseMinBehaviors}}', cfg.parseMinBehaviors.toString())
        .replaceAll('{{behaviorChainMinNodes}}', cfg.behaviorChainMinNodes.toString())
        .replaceAll('{{behaviorChainMaxNodes}}', cfg.behaviorChainMaxNodes.toString())
        .replaceAll('{{promptExtra}}', cfg.promptExtra)
        .replaceAll('{{promptExtraLine}}', cfg.promptExtra.isEmpty ? '' : '附加业务约束：${cfg.promptExtra}');
  }

  String _defaultParsePrompt() => _defaultParsePromptStatic();
  String _defaultScenePrompt() => _defaultScenePromptStatic();
  String _defaultTurnPrompt() => _defaultTurnPromptStatic();
  String _defaultReplayPrompt() => _defaultReplayPromptStatic();

  static String _defaultParsePromptStatic() => '''
你是“概念实践引擎”的概念解析器。
当前模型提供商：{{providerLabel}}。
当前传输模式：{{transportMode}}。
任务：把用户给出的抽象概念，转成现实可训练结构。
请只输出 json。
输出 schema:
{
  "concept": "string",
  "domain": "string",
  "definitions": ["string"],
  "intuitive_descriptions": ["string"],
  "behaviors": ["string"],
  "misunderstandings": ["string"],
  "directions": [
    {
      "name": "string",
      "domain": "string",
      "difficulty": "入门|进阶|高压",
      "why_fit": "string",
      "training_focus": ["string"]
    }
  ]
}
要求：
1. definitions 提供 2-4 条即可，聚焦核心含义，不要同义反复。
2. intuitive_descriptions 至少提供 {{parseMinIntuitive}} 条，必须与概念高度一致，贴近日常经验、现实处境或真实对话，像人在生活里会遇到的现象，不要写空泛口号。
3. behaviors 至少提供 {{parseMinBehaviors}} 条，必须是可观察、可执行、可识别的现实动作或表达，且与概念高度一致，避免重复。
4. misunderstandings 必须指出常见误区。
5. 至少提供 4 个 directions。
{{promptExtraLine}}
''';

  static String _defaultScenePromptStatic() => '''
你是“概念实践引擎”的场景设计器。
当前模型提供商：{{providerLabel}}。
当前传输模式：{{transportMode}}。
任务：根据概念、领域和训练目标，生成多个训练场景。
请只输出 json。
输出 schema:
{
  "scenes": [
    {
      "scene_id": "string",
      "title": "string",
      "user_role": "string",
      "goal": "string",
      "background": "string",
      "constraints": ["string"],
      "key_npcs": [{"name": "string", "role": "string", "motivation": "string", "attitude": "string"}],
      "normal_events": ["string"],
      "abnormal_events": ["string"],
      "success_criteria": ["string"],
      "failure_criteria": ["string"],
      "training_focus": ["string"],
      "estimated_turns": 6
    }
  ]
}
要求：
1. 返回 {{sceneCount}} 个场景。
2. 场景必须在目标、角色、约束和异常事件上有明显差异。
3. 每个场景至少包含 1 个异常事件。
4. 输出合法 json。
{{promptExtraLine}}
''';

  static String _defaultTurnPromptStatic() => '''
你是“概念实践引擎”的虚拟场景教练。
当前模型提供商：{{providerLabel}}。
当前传输模式：{{transportMode}}。
你的任务：
1. 根据当前场景、世界状态和用户动作，推进场景；
2. 保持角色一致性；
3. 输出 json。
输出 schema:
{
  "assistant_reply": "string",
  "state_delta": {
    "trust_score": 0,
    "risk_score": 0,
    "time_left": 0,
    "goal_progress": 0,
    "team_stability": 0,
    "emotion_tension": 0
  },
  "action_tags": ["string"],
  "triggered_events": ["string"],
  "finished": false,
  "finish_reason": "string"
}
规则：
1. 分值变化请保持温和，通常在 -18 到 +18 之间。
2. 如果用户动作有助于推进目标，提高 goal_progress 并适度降低 risk_score。
3. 如果用户甩锅、拖延、含糊或激化冲突，应提高 risk_score 或 emotion_tension。
4. 当 goal_progress >= 85 且 risk_score <= 55 时可判定为完成。
5. time_left 每轮通常下降 4-12。
6. 建议在 {{turnTarget}} 轮左右收束，不要无故拖长。
7. 输出必须是合法 json。
{{promptExtraLine}}
''';


  static String _defaultActionTreePrompt() => r'''
你是“概念行动引擎”的行动树生成器。
请只输出 json。
任务：根据用户输入的概念、目标、语境、维度，生成一个“概念 -> 至少10个行动 -> 每个行动继续细化为具体可执行行为”的行动树。
原则：
1. 条条大路通罗马，同一个概念可以有多种行动路径。
2. 优先生成现实中能马上执行的动作，而不是空泛建议。
3. 正常情况下行动可以顺畅推进，不要默认加入阻力。
4. 只有关键步骤才可以打 importance=important 或 critical，并可选 linked_cabin_type：delayReport / boundaryExpression / selfDisciplineStart。
5. 如果用户提供了 dimensions，请尽量覆盖这些维度；如果没有，自动从不同维度生成。
6. directions 至少 10 个，每个 direction 至少 1 个 module，每个 module 至少 3 个 steps。
7. steps 要具体到屏幕上或现实中真能做的行为，可以允许顺序不同、方法不同、细节不同。
8. 允许自定义步骤，所以不要把步骤写死成唯一正确方法。
输出 schema:
{
  "concept": "string",
  "short_description": "string",
  "dimensions": ["string"],
  "generated_by_ai": true,
  "generation_note": "string",
  "directions": [
    {
      "id": "string",
      "title": "string",
      "description": "string",
      "modules": [
        {
          "id": "string",
          "title": "string",
          "steps": [
            {
              "id": "string",
              "text": "string",
              "minimal_version": "string",
              "importance": "normal|important|critical",
              "linked_cabin_type": "string or omitted",
              "tags": ["string"]
            }
          ]
        }
      ]
    }
  ]
}
要求：
- 直接输出合法 json。
- directions 至少 10 个。
- 每个 action 的步骤要尽量具体、接近真实动作。
{{promptExtraLine}}
''';

  static String _defaultActionTreeFastPrompt() => r'''
你是“概念行动引擎”的快速行动树生成器。
请只输出 json，并保持精简。
目标：围绕用户给出的概念、目标、语境、维度，快速生成一棵可执行行动树。
硬性要求：
1. directions 至少 10 个。
2. 每个 direction 只需要 1 个 module。
3. 每个 module 至少 3 个具体 steps。
4. steps 必须接近现实动作，允许多种做法，不要写成唯一正确答案。
5. 默认按正常顺畅执行设计，不要主动制造阻力；只有关键步骤可打 importance=important 或 critical。
输出 schema:
{
  "concept": "string",
  "short_description": "string",
  "dimensions": ["string"],
  "generated_by_ai": true,
  "generation_note": "string",
  "directions": [
    {
      "id": "string",
      "title": "string",
      "description": "string",
      "modules": [
        {
          "id": "string",
          "title": "string",
          "steps": [
            {
              "id": "string",
              "text": "string",
              "minimal_version": "string",
              "importance": "normal|important|critical",
              "linked_cabin_type": "delayReport|boundaryExpression|selfDisciplineStart",
              "tags": ["string"]
            }
          ]
        }
      ]
    }
  ]
}
要求：
- 直接输出合法 json。
- 尽量短句，不要解释，不要额外说明。
{{promptExtraLine}}
''';

  static String _defaultActionTreeOverviewPrompt() => r'''
你是“概念行动引擎”的行动树概览生成器。
请只输出 json。
任务：根据用户输入的概念、目标、语境、维度，先生成一棵“概念 -> 至少10个行动方向”的概览树。
要求：
1. 这一步只需要生成行动方向概览，不要展开成很多步骤。
2. 每个 direction 提供 title、description、reality_meaning、observable_changes、experience_fact、fact_done_signal、preview_module_count、preview_step_count。
3. 所有 direction 都设置 needs_expansion=true。
4. 尽量覆盖用户输入的 dimensions；如果没有则自动补充不同维度。
5. 允许多条路径实现同一个概念，条条大路通罗马。
输出 schema:
{
  "concept": "string",
  "short_description": "string",
  "dimensions": ["string"],
  "generated_by_ai": true,
  "generation_note": "string",
  "directions": [
    {
      "id": "string",
      "title": "string",
      "description": "string",
      "reality_meaning": "string",
      "observable_changes": ["string"],
      "experience_fact": "string",
      "fact_done_signal": "string",
      "needs_expansion": true,
      "preview_module_count": 1,
      "preview_step_count": 3,
      "modules": []
    }
  ]
}
要求：
- directions 至少 10 个。
- 不要输出抽象标题后就结束，每个 direction 都要先把概念压到一个“现实里意味着什么”和“会看到什么变化”，再压到一个可直接想象的经验事实。
- experience_fact 必须像一个已经发生的现实片段，尽量有时间/场景/动作/结果，不要写成大道理。
- 输出合法 json。
{{promptExtraLine}}
''';

  static String _defaultActionTreeOverviewFastPrompt() => r'''
你是“概念行动引擎”的快速概览生成器。
请只输出 json，并保持精简。
要求：
1. 至少 10 个 direction。
2. 每个 direction 至少包含：title / description / reality_meaning / observable_changes / experience_fact / fact_done_signal / preview counts。
3. 所有 direction 都设置 needs_expansion=true。
4. 不展开长步骤，但要先把方向压到一个“现实里会看到什么”的经验事实。
输出 schema 与概览版相同。
{{promptExtraLine}}
''';

  static String _defaultActionDirectionExpandPrompt() => r'''
你是“概念行动引擎”的行动方向展开器。
请只输出 json。
任务：把给定的一个行动方向展开成“概念一路下沉到经验事实，再让事实发生的动作”。
要求：
1. 至少生成 2 个 modules。
2. 每个 module 至少 3 个 steps。
3. 每个 module 必须先给出：
   - reality_meaning：这一层在现实里意味着什么
   - observable_changes：如果这一层真的成立，你会看到什么变化
   - experience_fact：把概念压到最后，会变成一个什么具体、直观、可直接想象的经验事实
   - fact_done_signal：做到什么程度算这个经验事实已经发生
4. 每个 step 必须是现实中可以直接执行的动作，避免抽象词，优先写成“打开什么/写什么/发给谁/做几分钟/做到什么算完成”。
5. 每个 step 尽量补充 direct_instruction、execution_hint、done_signal、example，让用户可以拿来直接照做。
6. 只有关键步骤可以标 importance=important 或 critical，并可选 linked_cabin_type：delayReport / boundaryExpression / selfDisciplineStart。
输出 schema:
{
  "id": "string",
  "title": "string",
  "description": "string",
  "reality_meaning": "string",
  "observable_changes": ["string"],
  "experience_fact": "string",
  "fact_done_signal": "string",
  "needs_expansion": false,
  "preview_module_count": 0,
  "preview_step_count": 0,
  "modules": [
    {
      "id": "string",
      "title": "string",
      "reality_meaning": "string",
      "observable_changes": ["string"],
      "experience_fact": "string",
      "fact_done_signal": "string",
      "steps": [
        {
          "id": "string",
          "text": "string",
          "minimal_version": "string",
          "direct_instruction": "string",
          "execution_hint": "string",
          "done_signal": "string",
          "example": "string",
          "importance": "normal|important|critical",
          "linked_cabin_type": "delayReport|boundaryExpression|selfDisciplineStart",
          "tags": ["string"]
        }
      ]
    }
  ]
}
- 输出合法 json。
{{promptExtraLine}}
''';

  static String _defaultActionDirectionExpandFastPrompt() => r'''
你是“概念行动引擎”的快速方向展开器。
请只输出 json，并保持精简。
要求：
1. 至少 2 个 modules。
2. 每个 module 至少 3 个 steps。
3. 每个 module 仍需带：reality_meaning / observable_changes / experience_fact / fact_done_signal。
4. steps 用短句描述现实动作，尽量直接到可以立刻照做。
5. 尽量补 direct_instruction、done_signal 或 example。
6. 关键步骤才打 importance。
{{promptExtraLine}}
''';



  static String _defaultActionDirectionMorePathsPrompt() => r'''
你是“概念行动引擎”的实现路径扩展器。
请只输出 json。
任务：在已有行动方向基础上补充更多实现路径。条条大路通罗马，但每条路径都要先压到一个经验事实，再落到现实动作。
要求：
1. 生成 1-3 个新增 modules，每个 module 表示一种新的实现路径或新的执行次序。
2. 每个 module 至少 3 个 steps。
3. 每个 module 需要带：reality_meaning / observable_changes / experience_fact / fact_done_signal。
4. steps 必须是现实中可执行的具体行为，优先写清：现在做什么、对谁做、在哪里做、做到什么算完成。
5. 尽量补 direct_instruction、execution_hint、done_signal、example。
6. 自动识别关键步骤，并尽量标 importance 与 linked_cabin_type。
7. 不要简单重复已有 wording。
输出 schema:
{
  "id": "string",
  "title": "string",
  "description": "string",
  "reality_meaning": "string",
  "observable_changes": ["string"],
  "experience_fact": "string",
  "fact_done_signal": "string",
  "needs_expansion": false,
  "preview_module_count": 0,
  "preview_step_count": 0,
  "modules": [
    {
      "id": "string",
      "title": "string",
      "reality_meaning": "string",
      "observable_changes": ["string"],
      "experience_fact": "string",
      "fact_done_signal": "string",
      "steps": [
        {
          "id": "string",
          "text": "string",
          "minimal_version": "string",
          "direct_instruction": "string",
          "execution_hint": "string",
          "done_signal": "string",
          "example": "string",
          "importance": "normal|important|critical",
          "linked_cabin_type": "delayReport|boundaryExpression|selfDisciplineStart",
          "tags": ["string"]
        }
      ]
    }
  ]
}
{{promptExtraLine}}
''';

  static String _defaultActionDirectionMorePathsFastPrompt() => r'''
你是“概念行动引擎”的快速实现路径扩展器。
请只输出 json。
要求：
1. 生成 1-2 个新增 modules。
2. 每个 module 至少 3 个 steps。
3. 每个 module 仍需带：reality_meaning / observable_changes / experience_fact / fact_done_signal。
4. 只保留结构化动作，但要足够具体，可直接照做。
5. 尽量补 done_signal 或 example。
6. 自动标记关键步骤。
{{promptExtraLine}}
''';
  static String _defaultCustomStepExpandPrompt() => r'''
你是“概念行动引擎”的自定义步骤扩展器。
请只输出 json。
任务：根据用户写下的一个自定义步骤，先把它压到一个经验事实，再补充 3-5 个更细小、更可执行的现实动作。
原则：
1. 不要把方法写死，允许不同路径。
2. 默认按正常顺畅执行，不要主动制造阻力。
3. 先给出：
   - reality_meaning
   - observable_changes
   - experience_fact
   - fact_done_signal
4. 每个步骤必须是现实中今天就能做的动作，优先写成“现在打开什么/写什么/发给谁/做几分钟/做到什么算完成”。
5. 尽量补充 direct_instruction、execution_hint、done_signal、example。
输出 schema:
{
  "reality_meaning": "string",
  "observable_changes": ["string"],
  "experience_fact": "string",
  "fact_done_signal": "string",
  "steps": [
    {
      "id": "string",
      "text": "string",
      "minimal_version": "string",
      "direct_instruction": "string",
      "execution_hint": "string",
      "done_signal": "string",
      "example": "string",
      "importance": "normal|important|critical",
      "linked_cabin_type": "delayReport|boundaryExpression|selfDisciplineStart",
      "tags": ["string"]
    }
  ]
}
{{promptExtraLine}}
''';


  static String _defaultBehaviorChainPromptStatic() => '''
你是“概念实践引擎”的行为行动链生成器。
当前模型提供商：{{providerLabel}}。
当前传输模式：{{transportMode}}。
任务：根据用户当前选择的一条“行为表现”，把它展开为一条现实可执行的行动链。
请只输出 json。
输出 schema:
{
  "chain_id": "string",
  "title": "string",
  "summary": "string",
  "nodes": [
    {
      "id": "string",
      "title": "string",
      "detail": "string",
      "status": "未开始"
    }
  ]
}
要求：
1. nodes 至少 {{behaviorChainMinNodes}} 个，最多 {{behaviorChainMaxNodes}} 个。
2. 每个节点都必须是现实中可执行、顺序清晰的动作，而不是空泛口号。
3. detail 要写清楚这一步具体怎么做、做到什么算进入下一步。
4. 初始 status 统一写“未开始”。
5. 行动链必须紧扣 behavior，不要偏题，不要展开成完全不同的目标。
6. 输出合法 json。
{{promptExtraLine}}
''';


  static String _defaultReplayPromptStatic() => '''
你是“概念实践引擎”的深度复盘教练。
当前模型提供商：{{providerLabel}}。
当前传输模式：{{transportMode}}。
请只输出 json。
输出 schema:
{
  "total_score": 0,
  "result_label": "优秀成功|基础成功|可恢复失败|严重失败",
  "summary": "string",
  "strengths": ["string"],
  "mistakes": ["string"],
  "turning_points": ["string"],
  "root_causes": ["string"],
  "ignored_signals": ["string"],
  "better_actions": [
    {"problem": "string", "better_action": "string", "example_phrase": "string"}
  ],
  "next_training_focus": ["string"]
}
要求：
1. 必须基于对话历史和最终状态来评估。
2. 分数 0-100。
3. 评价要具体，不要空话。
4. 输出合法 json。
{{promptExtraLine}}
''';

  Future<Map<String, dynamic>> _postForJson({
    required ConceptEngineRuntimeConfig cfg,
    required String systemPrompt,
    required Map<String, dynamic> userPayload,
    required int maxTokens,
    required String logModule,
    String? sessionId,
    int? timeoutOverrideSeconds,
    bool useJsonResponseFormat = true,
    String? modelOverride,
  }) async {
    final traceId = _newTraceId();
    if (cfg.useProxy) {
      return _postViaProxy(
        cfg: cfg,
        systemPrompt: systemPrompt,
        userPayload: userPayload,
        maxTokens: maxTokens,
        logModule: logModule,
        traceId: traceId,
        sessionId: sessionId,
        timeoutOverrideSeconds: timeoutOverrideSeconds,
        useJsonResponseFormat: useJsonResponseFormat,
        modelOverride: modelOverride,
      );
    }
    return _postDirect(
      cfg: cfg,
      systemPrompt: systemPrompt,
      userPayload: userPayload,
      maxTokens: maxTokens,
      logModule: logModule,
      traceId: traceId,
      sessionId: sessionId,
      timeoutOverrideSeconds: timeoutOverrideSeconds,
      useJsonResponseFormat: useJsonResponseFormat,
      modelOverride: modelOverride,
    );
  }

  Future<Map<String, dynamic>> _postDirect({
    required ConceptEngineRuntimeConfig cfg,
    required String systemPrompt,
    required Map<String, dynamic> userPayload,
    required int maxTokens,
    required String logModule,
    required String traceId,
    String? sessionId,
    int? timeoutOverrideSeconds,
    bool useJsonResponseFormat = true,
    String? modelOverride,
  }) async {
    final effectiveTimeoutSeconds = timeoutOverrideSeconds ?? cfg.timeoutSeconds;
    final uri = Uri.parse(cfg.endpoint);
    final isResponsesApi = cfg.provider == 'openai' && uri.path.contains('/responses');
    // Azure 的调用地址里已经带上了部署名，请求体要下发部署名而不是
    // 设置页展示用的“资源名/部署名”限定写法。
    final defaultModel = cfg.provider == 'azure' ? cfg.deployment : cfg.model;
    final effectiveModel = (modelOverride?.trim().isNotEmpty == true) ? modelOverride!.trim() : defaultModel;
    final effectiveMaxTokens = cfg.globalMaxOutputTokens == null || cfg.globalMaxOutputTokens! <= 0
        ? maxTokens
        : cfg.globalMaxOutputTokens!.clamp(64, 64000).toInt();
    // Azure OpenAI 的 gpt-5 / o 系列只认 max_completion_tokens，且不接受自定义
    // temperature / top_p；Foundry 上的 Claude / Grok 则不支持 json_object。
    final azureReasoning = cfg.provider == 'azure' && UnifiedAiService.isAzureReasoningDeployment(effectiveModel);
    final allowJsonResponseFormat = useJsonResponseFormat &&
        (cfg.provider != 'azure' || UnifiedAiService.azureSupportsJsonResponseFormat(effectiveModel));
    final allowSamplingParams = !azureReasoning;

    final body = isResponsesApi
        ? {
            'model': effectiveModel,
            'input': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': jsonEncode(userPayload)},
            ],
            'max_output_tokens': effectiveMaxTokens,
            if (cfg.globalTemperature != null) 'temperature': cfg.globalTemperature,
            if (cfg.globalTopP != null) 'top_p': cfg.globalTopP,
          }
        : {
            'model': effectiveModel,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': jsonEncode(userPayload)},
            ],
            if (allowSamplingParams && cfg.globalTemperature != null) 'temperature': cfg.globalTemperature,
            if (allowSamplingParams && cfg.globalTopP != null) 'top_p': cfg.globalTopP,
            if (allowJsonResponseFormat) 'response_format': {'type': 'json_object'},
            if (azureReasoning) 'max_completion_tokens': effectiveMaxTokens,
            if (!azureReasoning) 'max_tokens': effectiveMaxTokens,
          };

    final headers = {
      ...cfg.effectiveAuthHeaders,
      'Content-Type': 'application/json',
      if (cfg.provider == 'openrouter') 'X-OpenRouter-Title': 'Quote App',
      'X-Concept-Engine-Trace-Id': traceId,
      if (sessionId?.isNotEmpty == true) 'X-Concept-Engine-Session-Id': sessionId!,
    };

    await DeepSeekLogger.logRequest(
      provider: cfg.providerLabel,
      module: logModule,
      endpoint: cfg.endpoint,
      headers: headers,
      body: body,
      model: effectiveModel,
      traceId: traceId,
      sessionId: sessionId,
    );

    try {
      final res = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(Duration(seconds: effectiveTimeoutSeconds));

      await DeepSeekLogger.logResponse(
        provider: cfg.providerLabel,
        module: logModule,
        endpoint: cfg.endpoint,
        statusCode: res.statusCode,
        body: res.body,
        model: effectiveModel,
        traceId: traceId,
        sessionId: sessionId,
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('${cfg.providerLabel} 请求失败：${res.statusCode} ${res.body}');
      }
      final decoded = jsonDecode(res.body);
      final content = _extractMessageContent(decoded);
      final normalized = _extractFirstJsonObject(content);
      return _decodeLenientJsonMap(normalized);
    } catch (e, st) {
      await DeepSeekLogger.logError(
        provider: cfg.providerLabel,
        module: logModule,
        endpoint: cfg.endpoint,
        error: e,
        stackTrace: st,
        model: effectiveModel,
        traceId: traceId,
        sessionId: sessionId,
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _postViaProxy({
    required ConceptEngineRuntimeConfig cfg,
    required String systemPrompt,
    required Map<String, dynamic> userPayload,
    required int maxTokens,
    required String logModule,
    required String traceId,
    String? sessionId,
    int? timeoutOverrideSeconds,
    bool useJsonResponseFormat = true,
    String? modelOverride,
  }) async {
    final effectiveTimeoutSeconds = timeoutOverrideSeconds ?? cfg.timeoutSeconds;
    final uri = Uri.parse(cfg.proxyEndpoint);
    final effectiveModel = (modelOverride?.trim().isNotEmpty == true) ? modelOverride!.trim() : cfg.model;
    final effectiveMaxTokens = cfg.globalMaxOutputTokens == null || cfg.globalMaxOutputTokens! <= 0
        ? maxTokens
        : cfg.globalMaxOutputTokens!.clamp(64, 64000).toInt();
    final body = {
      'route': 'concept_engine_json_task',
      'provider': cfg.provider,
      'target_endpoint': cfg.endpoint,
      'model': effectiveModel,
      if (useJsonResponseFormat) 'response_format': 'json_object',
      'max_tokens': effectiveMaxTokens,
      'system_prompt': systemPrompt,
      if (cfg.globalTemperature != null) 'temperature': cfg.globalTemperature,
      if (cfg.globalTopP != null) 'top_p': cfg.globalTopP,
      'user_payload': userPayload,
      'module': logModule,
      'trace_id': traceId,
      if (sessionId?.isNotEmpty == true) 'session_id': sessionId,
    };
    final headers = {
      'Content-Type': 'application/json',
      if (cfg.proxyAuthToken.trim().isNotEmpty) 'Authorization': 'Bearer ${cfg.proxyAuthToken.trim()}',
      'X-Concept-Engine-Trace-Id': traceId,
      if (sessionId?.isNotEmpty == true) 'X-Concept-Engine-Session-Id': sessionId!,
    };

    await DeepSeekLogger.logRequest(
      provider: '${cfg.providerLabel}-Proxy',
      module: '$logModule.proxy',
      endpoint: cfg.proxyEndpoint,
      headers: headers,
      body: body,
      model: effectiveModel,
      traceId: traceId,
      sessionId: sessionId,
    );

    try {
      final res = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(Duration(seconds: effectiveTimeoutSeconds));

      await DeepSeekLogger.logResponse(
        provider: '${cfg.providerLabel}-Proxy',
        module: '$logModule.proxy',
        endpoint: cfg.proxyEndpoint,
        statusCode: res.statusCode,
        body: res.body,
        model: cfg.model,
        traceId: traceId,
        sessionId: sessionId,
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('AI网关请求失败：${res.statusCode} ${res.body}');
      }
      final decoded = jsonDecode(res.body);
      final mapped = _extractProxyPayload(decoded);
      return mapped;
    } catch (e, st) {
      await DeepSeekLogger.logError(
        provider: '${cfg.providerLabel}-Proxy',
        module: '$logModule.proxy',
        endpoint: cfg.proxyEndpoint,
        error: e,
        stackTrace: st,
        model: cfg.model,
        traceId: traceId,
        sessionId: sessionId,
      );
      rethrow;
    }
  }


  Future<GatewayHealthResult> testGatewayHealth() async {
    final cfg = await loadRuntimeConfig();
    final endpoint = cfg.proxyEndpoint.trim();
    if (endpoint.isEmpty) {
      return const GatewayHealthResult(
        ok: false,
        endpoint: '',
        message: '未配置 AI 网关地址',
      );
    }
    final traceId = _newTraceId();
    final healthUrl = _deriveHealthUrl(endpoint);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (cfg.proxyAuthToken.trim().isNotEmpty) 'Authorization': 'Bearer ${cfg.proxyAuthToken.trim()}',
      'X-Concept-Engine-Trace-Id': traceId,
    };

    await DeepSeekLogger.logRequest(
      provider: 'AI-Gateway',
      module: 'concept_engine.gateway.health',
      endpoint: healthUrl,
      headers: headers,
      method: 'GET',
      body: const {'ping': true},
      model: cfg.model,
      traceId: traceId,
    );

    try {
      final res = await http.get(Uri.parse(healthUrl), headers: headers).timeout(Duration(seconds: min(cfg.timeoutSeconds, 20)));
      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {
        decoded = {'raw': res.body};
      }
      await DeepSeekLogger.logResponse(
        provider: 'AI-Gateway',
        module: 'concept_engine.gateway.health',
        endpoint: healthUrl,
        statusCode: res.statusCode,
        body: decoded,
        model: cfg.model,
        traceId: traceId,
      );
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      return GatewayHealthResult(
        ok: ok,
        endpoint: healthUrl,
        statusCode: res.statusCode,
        message: ok ? 'AI 网关连接正常' : 'AI 网关返回异常状态：${res.statusCode}',
        body: decoded is Map<String, dynamic> ? decoded : null,
      );
    } catch (e, st) {
      await DeepSeekLogger.logError(
        provider: 'AI-Gateway',
        module: 'concept_engine.gateway.health',
        endpoint: healthUrl,
        error: e,
        stackTrace: st,
        model: cfg.model,
        traceId: traceId,
      );
      return GatewayHealthResult(
        ok: false,
        endpoint: healthUrl,
        message: 'AI 网关连接失败：$e',
      );
    }
  }

  String _deriveHealthUrl(String proxyEndpoint) {
    try {
      final uri = Uri.parse(proxyEndpoint);
      var path = uri.path;
      if (path.endsWith('/api/concept-engine/proxy')) {
        path = path.substring(0, path.length - '/api/concept-engine/proxy'.length) + '/healthz';
      } else if (path.endsWith('/concept-engine/proxy')) {
        path = path.substring(0, path.length - '/concept-engine/proxy'.length) + '/healthz';
      } else if (path.endsWith('/proxy')) {
        path = path.substring(0, path.length - '/proxy'.length) + '/healthz';
      } else {
        path = '/healthz';
      }
      return uri.replace(path: path, query: '').toString();
    } catch (_) {
      return proxyEndpoint;
    }
  }

  Map<String, dynamic> _extractProxyPayload(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      if (decoded['json'] is Map) {
        return Map<String, dynamic>.from(decoded['json'] as Map);
      }
      if (decoded['result'] is Map) {
        return Map<String, dynamic>.from(decoded['result'] as Map);
      }
      if (decoded['data'] is Map) {
        return Map<String, dynamic>.from(decoded['data'] as Map);
      }
      if (decoded['content'] is String) {
        final normalized = _extractFirstJsonObject(decoded['content'].toString());
        return _decodeLenientJsonMap(normalized);
      }
      if (decoded.containsKey('assistant_reply') || decoded.containsKey('scenes') || decoded.containsKey('concept')) {
        return decoded;
      }
    }
    final normalized = _extractFirstJsonObject(decoded.toString());
    return _decodeLenientJsonMap(normalized);
  }

  String _extractMessageContent(dynamic decoded) {
    try {
      final direct = _extractDirectContent(decoded);
      if (direct.trim().isNotEmpty) return direct.trim();

      final candidates = <String>[];
      void collect(dynamic node) {
        if (node == null) return;
        if (node is String) {
          final s = node.trim();
          if (s.isNotEmpty) candidates.add(s);
          return;
        }
        if (node is List) {
          for (final item in node) {
            collect(item);
          }
          return;
        }
        if (node is Map) {
          const preferredKeys = ['content', 'text', 'output_text', 'reasoning_content', 'message'];
          for (final key in preferredKeys) {
            if (node.containsKey(key)) {
              collect(node[key]);
            }
          }
          node.forEach((key, value) {
            if (!preferredKeys.contains(key.toString())) {
              collect(value);
            }
          });
        }
      }

      collect(decoded);

      for (final candidate in candidates) {
        final normalized = candidate
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        if (normalized.contains('{') && normalized.contains('}')) {
          return normalized;
        }
      }

      for (final candidate in candidates) {
        if (candidate.trim().isNotEmpty) return candidate.trim();
      }

      throw Exception('模型返回内容为空');
    } catch (e) {
      throw Exception('解析模型响应失败：$e');
    }
  }

  String _extractDirectContent(dynamic decoded) {
    if (decoded is Map && decoded['output'] is List) {
      final out = decoded['output'] as List;
      for (final item in out) {
        if (item is Map && item['content'] is List) {
          final list = item['content'] as List;
          final buf = StringBuffer();
          for (final part in list) {
            if (part is Map) {
              if (part['type'] == 'output_text' && part['text'] != null) {
                buf.write(part['text'].toString());
              } else if (part['type'] == 'text' && part['text'] != null) {
                buf.write(part['text'].toString());
              }
            }
          }
          final s = buf.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }
    }

    if (decoded is Map) {
      final choices = decoded['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map) {
          final msg = first['message'];
          if (msg is Map) {
            final content = msg['content'];
            if (content is String && content.trim().isNotEmpty) return content;
            if (content is List) {
              final buf = StringBuffer();
              for (final item in content) {
                if (item is Map) {
                  if (item['type'] == 'text' && item['text'] != null) {
                    buf.write(item['text'].toString());
                  } else if (item['text'] != null) {
                    buf.write(item['text'].toString());
                  }
                } else if (item is String) {
                  buf.write(item);
                }
              }
              final s = buf.toString().trim();
              if (s.isNotEmpty) return s;
            }
            final reasoning = msg['reasoning_content'];
            if (reasoning is String && reasoning.trim().isNotEmpty) return reasoning;
            if (reasoning is List) {
              final buf = StringBuffer();
              for (final item in reasoning) {
                if (item is Map && item['text'] != null) {
                  buf.write(item['text'].toString());
                } else if (item is String) {
                  buf.write(item);
                }
              }
              final s = buf.toString().trim();
              if (s.isNotEmpty) return s;
            }
          }
          final text = first['text'];
          if (text is String && text.trim().isNotEmpty) return text;
        }
      }
    }
    return '';
  }

  Map<String, dynamic> _decodeLenientJsonMap(String raw) {
    final attempts = <String>[
      raw,
      _normalizeJsonCandidate(raw),
      _repairPossiblyMalformedJson(_normalizeJsonCandidate(raw)),
    ];
    Object? lastError;
    for (final candidate in attempts) {
      final trimmed = candidate.trim();
      if (trimmed.isEmpty) continue;
      try {
        return Map<String, dynamic>.from(jsonDecode(trimmed) as Map);
      } catch (e) {
        lastError = e;
      }
    }
    throw FormatException('无法解析模型 JSON：$lastError');
  }

  String _normalizeJsonCandidate(String raw) {
    var s = raw
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll("‘", "'")
        .replaceAll("’", "'")
        .trim();
    s = s.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
    return s;
  }

  String _repairPossiblyMalformedJson(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;

    final out = StringBuffer();
    final stack = <String>[];
    var inString = false;
    var escaped = false;

    for (final rune in s.runes) {
      final ch = String.fromCharCode(rune);
      if (escaped) {
        out.write(ch);
        escaped = false;
        continue;
      }
      if (ch == '\\') {
        out.write(ch);
        escaped = true;
        continue;
      }
      if (ch == '"') {
        out.write(ch);
        inString = !inString;
        continue;
      }
      if (inString) {
        out.write(ch);
        continue;
      }
      if (ch == '{') {
        stack.add('}');
        out.write(ch);
        continue;
      }
      if (ch == '[') {
        stack.add(']');
        out.write(ch);
        continue;
      }
      if (ch == '}' || ch == ']') {
        if (stack.isEmpty) {
          out.write(ch);
          continue;
        }
        if (stack.last == ch) {
          stack.removeLast();
          out.write(ch);
          continue;
        }
        if (stack.contains(ch)) {
          while (stack.isNotEmpty && stack.last != ch) {
            out.write(stack.removeLast());
          }
          if (stack.isNotEmpty && stack.last == ch) {
            stack.removeLast();
            out.write(ch);
          }
          continue;
        }
        out.write(ch);
        continue;
      }
      out.write(ch);
    }

    if (inString) {
      out.write('"');
    }
    while (stack.isNotEmpty) {
      out.write(stack.removeLast());
    }

    return out.toString().replaceAll(RegExp(r',\s*([}\]])'), r'$1').trim();
  }

  String _extractFirstJsonObject(String raw) {
    final cleaned = _normalizeJsonCandidate(raw);
    final start = cleaned.indexOf('{');
    if (start < 0) {
      throw Exception('未找到合法 json：$raw');
    }
    final end = cleaned.lastIndexOf('}');
    if (end > start) {
      return cleaned.substring(start, end + 1);
    }
    return cleaned.substring(start);
  }

  ChallengeWorldState _applyDelta(ChallengeWorldState current, Map<String, dynamic> delta) {
    int clampInt(int base, String key) {
      final dv = int.tryParse((delta[key] ?? '0').toString()) ?? 0;
      return (base + dv).clamp(0, 100).toInt();
    }

    final timeDelta = int.tryParse((delta['time_left'] ?? '-6').toString()) ?? -6;
    return current.copyWith(
      trustScore: clampInt(current.trustScore, 'trust_score'),
      riskScore: clampInt(current.riskScore, 'risk_score'),
      timeLeft: (current.timeLeft + timeDelta).clamp(0, 100).toInt(),
      goalProgress: clampInt(current.goalProgress, 'goal_progress'),
      teamStability: clampInt(current.teamStability, 'team_stability'),
      emotionTension: clampInt(current.emotionTension, 'emotion_tension'),
    );
  }

  void _ensureAuth(ConceptEngineRuntimeConfig cfg) {
    if (cfg.useProxy) return;
    if (cfg.apiKey.trim().isEmpty) {
      throw Exception('请先到设置页面填写${cfg.providerLabel}密钥。');
    }
  }

  String _newTraceId() {
    final now = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final rnd = _random.nextInt(1 << 20).toRadixString(36).padLeft(4, '0');
    return 'ce_$now$rnd';
  }
}
