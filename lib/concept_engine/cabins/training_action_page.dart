import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../concept_engine_dao.dart';
import '../concept_engine_models.dart';
import '../concept_engine_service.dart';
import 'training_cabin_models.dart';
import 'training_result_page.dart';

class TrainingCabinActionPage extends StatefulWidget {
  final TrainingCabinRunDraft draft;

  const TrainingCabinActionPage({super.key, required this.draft});

  @override
  State<TrainingCabinActionPage> createState() => _TrainingCabinActionPageState();
}

class _TrainingCabinActionPageState extends State<TrainingCabinActionPage> {
  final _service = ConceptEngineService();
  final _dao = ConceptEngineDao();
  final _inputCtrl = TextEditingController();

  bool _loading = true;
  bool _finishing = false;
  bool _showingImpact = false;
  String? _error;
  String _sessionKey = '';
  String _selectedTone = '稳定';
  String? _selectedAction;

  ConceptEngineRuntimeConfig? _cfg;
  ConceptParseResult? _parse;
  SceneOption? _scene;
  ChallengeWorldState _state = ChallengeWorldState.initial();
  List<ChallengeMessage> _messages = const [];
  List<String> _actionTags = const [];
  List<String> _triggeredEvents = const [];
  final List<Map<String, dynamic>> _processEvents = [];
  final List<Map<String, dynamic>> _impactDecisions = [];

  @override
  void initState() {
    super.initState();
    _selectedAction = widget.draft.descriptor.quickActionChips.first;
    _selectedTone = widget.draft.descriptor.toneOptions.first;
    _bootstrap();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  String _ensureSessionKey() {
    if (_sessionKey.isEmpty) {
      _sessionKey = 'cabin_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    }
    return _sessionKey;
  }

  Future<void> _logStageEvent(String stage, Map<String, dynamic> payload) async {
    final event = {
      'stage': stage,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
    };
    _processEvents.add(event);
    await _dao.logCabinStageEvent(
      sessionKey: _ensureSessionKey(),
      cabinType: widget.draft.descriptor.id,
      stage: stage,
      payload: payload,
    );
  }

  Future<void> _logBootstrapProcess() async {
    await _logStageEvent('intro_prep_snapshot', {
      'concept': widget.draft.concept,
      'goal': widget.draft.goal,
      'domain': widget.draft.domain,
      'selected_attitude': widget.draft.selectedAttitude,
      'mind_prompts': widget.draft.selectedMindPrompts,
      'prep': {
        'selected_facts': widget.draft.prepState.selectedFacts,
        'ranked_risks': widget.draft.prepState.rankedRisks,
        'ordered_actions': widget.draft.prepState.orderedActions,
        'expression_blocks': widget.draft.prepState.expressionBlocks,
        'final_attitude': widget.draft.prepState.finalAttitude,
      },
    });
  }

  Map<String, dynamic> _buildProcessSummary() {
    return {
      'selected_attitude': widget.draft.selectedAttitude,
      'mind_prompts': widget.draft.selectedMindPrompts,
      'prep': {
        'selected_facts': widget.draft.prepState.selectedFacts,
        'ranked_risks': widget.draft.prepState.rankedRisks,
        'ordered_actions': widget.draft.prepState.orderedActions,
        'expression_blocks': widget.draft.prepState.expressionBlocks,
        'final_attitude': widget.draft.prepState.finalAttitude,
      },
      'impact_decisions': _impactDecisions,
      'process_event_count': _processEvents.length,
      'turn_count': _state.turnNo,
    };
  }

  Future<void> _bootstrap() async {
    try {
      await _dao.ensureSchema();
      final cfg = await _service.loadRuntimeConfig();
      String? softError;
      ConceptParseResult parse;
      try {
        parse = await _service.parseConcept(
          concept: widget.draft.concept,
          domain: widget.draft.domain,
          goal: widget.draft.goal,
          sessionId: _ensureSessionKey(),
        );
      } catch (e) {
        parse = _buildLocalFallbackParse();
        softError = '概念解析较慢，已切换为本地训练脚本。';
      }

      SceneOption? scene;
      try {
        final scenes = await _service.generateScenes(
          concept: widget.draft.concept,
          domain: widget.draft.domain,
          goal: widget.draft.goal,
          parseResult: parse,
          sessionId: _ensureSessionKey(),
        );
        scene = scenes.isNotEmpty ? scenes.first : null;
      } catch (e) {
        scene = _buildLocalFallbackScene();
        softError = softError ?? '场景生成超时，已使用本地默认场景继续训练。';
      }

      scene ??= _buildLocalFallbackScene();
      if (!mounted) return;

      final opening = _buildOpening(scene, isFallback: softError != null);
      await _logBootstrapProcess();
      setState(() {
        _cfg = cfg;
        _parse = parse;
        _scene = scene;
        _messages = [ChallengeMessage(role: 'assistant', content: opening, createdAt: DateTime.now())];
        _loading = false;
        _error = softError;
      });
    } catch (e) {
      if (!mounted) return;
      final fallbackScene = _buildLocalFallbackScene();
      setState(() {
        _loading = false;
        _parse = _buildLocalFallbackParse();
        _scene = fallbackScene;
        _messages = [ChallengeMessage(role: 'assistant', content: _buildOpening(fallbackScene, isFallback: true), createdAt: DateTime.now())];
        _error = '初始化较慢，已切换为本地训练脚本。';
      });
    }
  }

  ConceptParseResult _buildLocalFallbackParse() {
    return ConceptParseResult(
      concept: widget.draft.concept,
      domain: widget.draft.domain,
      definitions: ['这是一次围绕${widget.draft.concept}的现实行动训练。'],
      intuitiveDescriptions: widget.draft.prepState.selectedFacts,
      behaviors: widget.draft.prepState.orderedActions,
      misunderstandings: widget.draft.prepState.rankedRisks,
      directions: const [],
    );
  }

  SceneOption _buildLocalFallbackScene() {
    return SceneOption(
      sceneId: 'local_${widget.draft.descriptor.id}',
      title: '${widget.draft.descriptor.title}·本地默认场景',
      userRole: widget.draft.descriptor.roleLabel,
      goal: widget.draft.goal,
      background: widget.draft.descriptor.sceneNarration,
      constraints: widget.draft.prepState.rankedRisks.take(3).toList(),
      keyNpcs: const [
        SceneNpc(name: '现实压力', role: '环境', motivation: '推动你尽快行动', attitude: '持续施压'),
      ],
      normalEvents: widget.draft.prepState.orderedActions.take(3).toList(),
      abnormalEvents: widget.draft.prepState.rankedRisks.take(2).toList(),
      successCriteria: const ['推进明显增加', '风险没有继续升级', '形成现实可执行下一步'],
      failureCriteria: const ['持续拖延', '过度防御', '没有形成下一步动作'],
      trainingFocus: widget.draft.prepState.expressionBlocks.take(3).toList(),
      estimatedTurns: 6,
    );
  }

  String _buildOpening(SceneOption scene, {bool isFallback = false}) {
    return [
      '【行动舱启动】',
      '场景：${scene.title}',
      '你的角色：${scene.userRole}',
      '目标：${scene.goal}',
      '你选择的态度：${widget.draft.selectedAttitude}',
      '关键事实：${widget.draft.prepState.selectedFacts.join('；')}',
      '风险优先级：${widget.draft.prepState.rankedRisks.take(3).join(' > ')}',
      '计划顺序：${widget.draft.prepState.orderedActions.take(3).join(' → ')}',
      if (scene.abnormalEvents.isNotEmpty) '潜在突发：${scene.abnormalEvents.take(2).join('；')}',
      isFallback ? '当前使用本地训练脚本，你仍可以继续行动训练。' : '请直接输入你的第一步动作或要说的话。',
    ].join('\n');
  }

  String _effectiveRawInput(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if ((_selectedAction ?? '').trim().isNotEmpty) {
      return '我先执行：${_selectedAction!.trim()}';
    }
    return '';
  }

  ChallengeTurnResult _buildLocalFallbackTurn({required SceneOption scene, required String userInput}) {
    final lower = userInput.toLowerCase();
    int trust = 0, risk = 0, time = -6, progress = 0, tension = 0, stability = 0;
    final tags = <String>[];
    final impacts = <String>[];

    final action = (_selectedAction ?? '').trim();
    if (action.isNotEmpty) tags.add(action);
    if (_selectedTone.trim().isNotEmpty) tags.add('tone_${_selectedTone.trim()}');

    final positive = action.contains('开始') || action.contains('方案') || action.contains('责任') || action.contains('边界') || action.contains('推进') || lower.contains('先') || lower.contains('开始') || lower.contains('承担');
    final avoidant = lower.contains('以后') || lower.contains('再说') || lower.contains('先等等') || lower.contains('不想') || lower.contains('解释不清') || action.contains('防御');

    if (positive) {
      trust += 6;
      risk -= 5;
      progress += 12;
      tension -= 2;
      stability += 4;
    }
    if (avoidant) {
      trust -= 6;
      risk += 8;
      progress -= 2;
      tension += 6;
      stability -= 4;
      impacts.add('你这一轮出现了回避倾向，现实压力没有真正下降。');
    }

    switch (widget.draft.descriptor.type) {
      case TrainingCabinType.delayReport:
        if (userInput.contains('承担') || action.contains('责任')) {
          trust += 5;
          progress += 6;
        }
        if (userInput.contains('时间') || userInput.contains('今天') || userInput.contains('18 点')) {
          risk -= 4;
          progress += 5;
        }
        break;
      case TrainingCabinType.boundaryExpression:
        if (userInput.contains('不能') || userInput.contains('边界') || action.contains('边界')) {
          progress += 7;
          stability += 3;
        }
        if (userInput.contains('理解')) {
          trust += 3;
        }
        break;
      case TrainingCabinType.selfDisciplineStart:
        if (userInput.contains('第一步') || userInput.contains('3 分钟') || action.contains('开始第一步')) {
          progress += 10;
          tension -= 3;
        }
        if (userInput.contains('干扰') || action.contains('切断干扰')) {
          risk -= 3;
          stability += 3;
        }
        break;
    }

    final next = _state.copyWith(
      trustScore: (_state.trustScore + trust).clamp(0, 100).toInt(),
      riskScore: (_state.riskScore + risk).clamp(0, 100).toInt(),
      timeLeft: (_state.timeLeft + time).clamp(0, 100).toInt(),
      goalProgress: (_state.goalProgress + progress).clamp(0, 100).toInt(),
      teamStability: (_state.teamStability + stability).clamp(0, 100).toInt(),
      emotionTension: (_state.emotionTension + tension).clamp(0, 100).toInt(),
      turnNo: _state.turnNo + 1,
    );

    final finished = next.goalProgress >= 85 || next.timeLeft <= 0 || next.riskScore >= 90;
    final merged = next.copyWith(
      finished: finished,
      finishReason: finished
          ? (next.goalProgress >= 85
              ? 'goal_achieved'
              : next.timeLeft <= 0
                  ? 'time_exhausted'
                  : 'risk_exploded')
          : '',
    );

    final reply = [
      '【本地训练脚本继续】',
      '你这一轮已经把行动往前推进了。',
      if (positive) '你的表达/动作具有推进性，局势开始产生变化。',
      if (avoidant) '但你刚才仍然带有一点回避或拖延倾向，需要下一轮更直接。',
      if (impacts.isEmpty) '下一轮请继续把态度、动作和现实下一步说得更具体。',
      ...impacts,
    ].join('\n');

    return ChallengeTurnResult(
      assistantReply: reply,
      state: merged,
      actionTags: tags,
      triggeredEvents: impacts,
    );
  }

  ReplayResult _buildLocalReplay({required SceneOption scene}) {
    final total = ((_state.goalProgress * 0.45) + ((100 - _state.riskScore) * 0.25) + (_state.trustScore * 0.15) + (_state.teamStability * 0.15)).round().clamp(0, 100);
    final label = total >= 85
        ? '优秀成功'
        : total >= 70
            ? '基础成功'
            : total >= 50
                ? '可恢复失败'
                : '严重失败';
    final dims = {
      '沟通表达': (_state.trustScore + (100 - _state.emotionTension)) ~/ 2,
      '风险控制': 100 - _state.riskScore,
      '推进执行': _state.goalProgress,
      '稳定度': (_state.teamStability + (100 - _state.emotionTension)) ~/ 2,
    };
    return ReplayResult(
      totalScore: total,
      resultLabel: label,
      summary: '因模型响应较慢，本次结算使用本地复盘脚本生成。你已经完成一轮可继续的现实行动训练。',
      strengths: [
        if (_state.goalProgress >= 40) '你已经形成了可执行的下一步。',
        if (_state.trustScore >= 50) '你的表达仍保持了一定现实可信度。',
      ],
      mistakes: [
        if (_state.riskScore >= 60) '你的风险控制还不够稳，需要更快进入关键动作。',
        if (_state.emotionTension >= 60) '在压力上升时，你还需要更稳定的节奏。',
      ],
      turningPoints: [
        '本地脚本已记录你的关键过程，可在详情页继续复看。',
      ],
      rootCauses: ['本轮主要阻力在于把正确想法转成现实一步动作的速度仍然偏慢。'],
      ignoredSignals: [if (_triggeredEvents.isNotEmpty) ..._triggeredEvents.take(2) else '你需要更早识别局势中的压力信号。'],
      betterActions: const [
        ReplayActionSuggestion(problem: '动作仍偏抽象', betterAction: '把下一步说成具体动作和时点', examplePhrase: '我现在先做第一步，并在 10 分钟后回看结果。'),
      ],
      nextTrainingFocus: ['更快进入关键动作', '让表达更具体', '在压力里维持节奏'],
      dimensionScores: dims,
    );
  }

  Future<void> _submitTurn() async {

    final scene = _scene;
    final raw = _effectiveRawInput(_inputCtrl.text.trim());
    if (scene == null || _loading || _finishing) return;
    if (raw.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请至少输入一句行动，或先选择一个动作标签。')));
      }
      return;
    }

    final previousImpactCount = _triggeredEvents.length;
    final stateBefore = _state.toJson();
    final userMsg = ChallengeMessage(
      role: 'user',
      content: '态度：$_selectedTone；动作：${_selectedAction ?? ''}。\n$raw',
      createdAt: DateTime.now(),
    );

    setState(() {
      _inputCtrl.clear();
      _loading = true;
      _error = null;
      _messages = [..._messages, userMsg];
    });

    try {
      await _logStageEvent('action_turn_submitted', {
        'round': _state.turnNo + 1,
        'selected_tone': _selectedTone,
        'selected_action': _selectedAction ?? '',
        'selected_attitude': widget.draft.selectedAttitude,
        'raw_input': raw,
        'state_before': stateBefore,
      });
      final res = await _service.runTurn(
        scene: scene,
        state: _state,
        history: _messages,
        userInput: userMsg.content,
        sessionId: _ensureSessionKey(),
      );
      if (!mounted) return;

      await _logStageEvent('action_turn_result', {
        'round': res.state.turnNo,
        'selected_tone': _selectedTone,
        'selected_action': _selectedAction ?? '',
        'assistant_reply': res.assistantReply,
        'state_before': stateBefore,
        'state_after': res.state.toJson(),
        'new_impacts_count': res.triggeredEvents.length,
      });
      setState(() {
        _state = res.state;
        _actionTags = [..._actionTags, ...res.actionTags];
        _triggeredEvents = [..._triggeredEvents, ...res.triggeredEvents];
        _messages = [..._messages, ChallengeMessage(role: 'assistant', content: res.assistantReply, createdAt: DateTime.now())];
        _loading = false;
      });

      final newImpacts = _triggeredEvents.skip(previousImpactCount).toList();
      if (newImpacts.isNotEmpty) {
        await _showImpactOverlay(newImpacts);
      }

      if (res.state.finished) {
        await _finish();
      }
    } on TimeoutException catch (e) {
      if (!mounted) return;
      final fallback = _buildLocalFallbackTurn(scene: scene, userInput: userMsg.content);
      await _logStageEvent('action_turn_result', {
        'round': fallback.state.turnNo,
        'selected_tone': _selectedTone,
        'selected_action': _selectedAction ?? '',
        'assistant_reply': fallback.assistantReply,
        'state_before': stateBefore,
        'state_after': fallback.state.toJson(),
        'new_impacts_count': fallback.triggeredEvents.length,
        'fallback': true,
      });
      setState(() {
        _state = fallback.state;
        _actionTags = [..._actionTags, ...fallback.actionTags];
        _triggeredEvents = [..._triggeredEvents, ...fallback.triggeredEvents];
        _messages = [..._messages, ChallengeMessage(role: 'assistant', content: fallback.assistantReply, createdAt: DateTime.now())];
        _loading = false;
        _error = '模型响应超时，已自动切换为本地训练脚本继续本轮。';
      });
      final newImpacts = _triggeredEvents.skip(previousImpactCount).toList();
      if (newImpacts.isNotEmpty) {
        await _showImpactOverlay(newImpacts);
      }
      if (fallback.state.finished) {
        await _finish();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _finish() async {
    final scene = _scene;
    if (scene == null || _finishing) return;
    setState(() {
      _finishing = true;
      _loading = true;
      _error = null;
    });

    try {
      final replay = await _service.analyzeReplay(
        concept: widget.draft.concept,
        domain: widget.draft.domain,
        goal: widget.draft.goal,
        scene: scene,
        state: _state,
        history: _messages,
        sessionId: _ensureSessionKey(),
      );
      await _dao.ensureSchema();
      final insertedId = await _dao.insertSession(
        concept: widget.draft.concept,
        domain: widget.draft.domain,
        goal: widget.draft.goal,
        sceneTitle: scene.title,
        provider: _cfg?.provider ?? 'deepseek',
        model: _cfg?.model ?? '',
        transportMode: _cfg?.transportMode ?? ConceptEngineService.transportDirect,
        sessionKey: _sessionKey,
        cabinType: widget.draft.descriptor.id,
        processData: _buildProcessSummary(),
        replay: replay,
        state: _state,
        scene: scene,
        history: _messages,
        actionTags: _actionTags,
        triggeredEvents: _triggeredEvents,
      );
      final reward = await _dao.applyReplayReward(
        replay: replay,
        domain: widget.draft.domain,
        sceneTitle: scene.title,
      );
      await _logStageEvent('result_summary', {
        'result_label': replay.resultLabel,
        'total_score': replay.totalScore,
        'summary': replay.summary,
        'xp_gained': reward.xpGained,
        'level_after': reward.profile.level,
        'unlocked_achievements': reward.unlockedAchievements,
      });
      if (!mounted) return;

      final completed = TrainingCabinCompletedRun(
        draft: widget.draft,
        scene: scene,
        finalState: _state,
        replay: replay,
        messages: _messages,
        actionTags: _actionTags,
        triggeredEvents: _triggeredEvents,
        provider: _cfg?.provider ?? 'deepseek',
        model: _cfg?.model ?? '',
        transportMode: _cfg?.transportMode ?? ConceptEngineService.transportDirect,
        sessionKey: _sessionKey,
        reward: reward,
        recordId: insertedId > 0 ? insertedId : null,
      );

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TrainingCabinResultPage(run: completed)),
      );
    } on TimeoutException catch (_) {
      final replay = _buildLocalReplay(scene: scene);
      await _dao.ensureSchema();
      final insertedId = await _dao.insertSession(
        concept: widget.draft.concept,
        domain: widget.draft.domain,
        goal: widget.draft.goal,
        sceneTitle: scene.title,
        provider: _cfg?.provider ?? 'deepseek',
        model: _cfg?.model ?? '',
        transportMode: _cfg?.transportMode ?? ConceptEngineService.transportDirect,
        sessionKey: _sessionKey,
        cabinType: widget.draft.descriptor.id,
        processData: _buildProcessSummary(),
        replay: replay,
        state: _state,
        scene: scene,
        history: _messages,
        actionTags: _actionTags,
        triggeredEvents: _triggeredEvents,
      );
      final reward = await _dao.applyReplayReward(
        replay: replay,
        domain: widget.draft.domain,
        sceneTitle: scene.title,
      );
      if (!mounted) return;
      final completed = TrainingCabinCompletedRun(
        draft: widget.draft,
        scene: scene,
        finalState: _state,
        replay: replay,
        messages: _messages,
        actionTags: _actionTags,
        triggeredEvents: _triggeredEvents,
        provider: _cfg?.provider ?? 'deepseek',
        model: _cfg?.model ?? '',
        transportMode: _cfg?.transportMode ?? ConceptEngineService.transportDirect,
        sessionKey: _sessionKey,
        reward: reward,
        recordId: insertedId > 0 ? insertedId : null,
      );
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TrainingCabinResultPage(run: completed)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _finishing = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _showImpactOverlay(List<String> impacts) async {
    if (_showingImpact || !mounted) return;
    HapticFeedback.mediumImpact();
    _showingImpact = true;
    final decision = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImpactSheet(
        descriptor: widget.draft.descriptor,
        impacts: impacts,
        state: _state,
      ),
    );
    _showingImpact = false;
    if (decision != null) {
      _impactDecisions.add(decision);
      await _logStageEvent('impact_decision', decision);
      final suggestedPhrase = (decision['suggested_phrase'] ?? '').toString().trim();
      final suggestedTone = (decision['tone'] ?? '').toString().trim();
      final suggestedAction = (decision['action'] ?? '').toString().trim();
      if (mounted) {
        setState(() {
          if (suggestedTone.isNotEmpty) _selectedTone = suggestedTone;
          if (suggestedAction.isNotEmpty) _selectedAction = suggestedAction;
          if (suggestedPhrase.isNotEmpty) {
            final old = _inputCtrl.text.trim();
            _inputCtrl.text = old.isEmpty ? suggestedPhrase : '$old\n$suggestedPhrase';
          }
        });
      }
    }
  }

  List<String> _delayReportSuggestedPhrases() => const [
        '我先直接说明结果：当前交付会延期。',
        '这部分责任由我先承担。',
        '我先说清影响范围，再给修复方案。',
        '今天 18 点前我给你明确修复时间表。',
        '现在最重要的是先止损并保证下一次更新。',
      ];

  Widget _buildDelayReportHighFidelityPanel() {
    final facts = widget.draft.prepState.selectedFacts.take(3).toList();
    final risks = widget.draft.prepState.rankedRisks.take(3).toList();
    final pressureLevel = _state.riskScore >= 75
        ? '高压解释阶段'
        : _state.timeLeft <= 30
            ? '时间压缩阶段'
            : _state.goalProgress < 35
                ? '开场承担阶段'
                : '补救与承诺阶段';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.sensors_outlined),
          const SizedBox(width: 8),
          const Expanded(child: Text('延期汇报高保真压力板', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(999)),
            child: Text(pressureLevel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
          ),
        ]),
        const SizedBox(height: 10),
        const Text(
          '像现实中的延期汇报一样，这一舱更强调：先承担、说清影响、给出时点、顶住追问。',
          style: TextStyle(color: Color(0xFF4B5563), height: 1.45),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ...facts.map((e) => _chip('关键事实：$e', const Color(0xFFDBEAFE))),
          ...risks.map((e) => _chip('优先风险：$e', const Color(0xFFFEE2E2))),
        ]),
        const SizedBox(height: 12),
        const Text('推荐现实结构', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(widget.draft.prepState.expressionBlocks.join(' → '), style: const TextStyle(color: Color(0xFF374151))),
        const SizedBox(height: 12),
        const Text('一句话模板（点击可填入输入框）', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _delayReportSuggestedPhrases()
              .map((e) => ActionChip(
                    label: Text(e, style: const TextStyle(fontSize: 12.5)),
                    onPressed: () {
                      final old = _inputCtrl.text.trim();
                      final next = old.isEmpty ? e : '$old\n$e';
                      setState(() => _inputCtrl.text = next);
                    },
                  ))
              .toList(),
        ),
      ]),
    );
  }


  List<String> _boundarySuggestedPhrases() => const [
        '我理解你现在很需要支持，但这件事我不能答应。',
        '我可以在这个范围内支持你，但不会接下全部责任。',
        '我想把边界说清楚，这样我们后面不会继续失衡。',
        '这不是我不在乎你，而是我不能再继续这样安排。',
        '我会保持尊重，但我的边界不会因为压力而改变。',
      ];

  Widget _buildBoundaryHighFidelityPanel() {
    final facts = widget.draft.prepState.selectedFacts.take(3).toList();
    final risks = widget.draft.prepState.rankedRisks.take(3).toList();
    final relationPressure = _state.emotionTension >= 70
        ? '关系施压升级'
        : _state.trustScore <= 35
            ? '误解加深阶段'
            : _state.goalProgress < 35
                ? '边界开场阶段'
                : '重复施压阶段';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.shield_outlined),
          const SizedBox(width: 8),
          const Expanded(child: Text('边界表达高保真压力板', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFFCE7F3), borderRadius: BorderRadius.circular(999)),
            child: Text(relationPressure, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9D174D))),
          ),
        ]),
        const SizedBox(height: 10),
        const Text(
          '这一舱更强调：不靠消失或解释过度来维持关系，而是温和、稳定、清楚地把边界说完整。',
          style: TextStyle(color: Color(0xFF4B5563), height: 1.45),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ...facts.map((e) => _chip('边界事实：$e', const Color(0xFFFCE7F3))),
          ...risks.map((e) => _chip('压力点：$e', const Color(0xFFFFEDD5))),
        ]),
        const SizedBox(height: 12),
        const Text('推荐现实结构', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(widget.draft.prepState.expressionBlocks.join(' → '), style: const TextStyle(color: Color(0xFF374151))),
        const SizedBox(height: 12),
        const Text('一句话模板（点击可填入输入框）', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _boundarySuggestedPhrases()
              .map((e) => ActionChip(
                    label: Text(e, style: const TextStyle(fontSize: 12.5)),
                    onPressed: () {
                      final old = _inputCtrl.text.trim();
                      final next = old.isEmpty ? e : '$old\n$e';
                      setState(() => _inputCtrl.text = next);
                    },
                  ))
              .toList(),
        ),
      ]),
    );
  }

  List<String> _selfDisciplineMicroActions() => const [
        '我先只做第一步，不讨论最终质量。',
        '先关掉一个干扰源，再开始 3 分钟。',
        '现在立刻进入最小动作，不等更好的状态。',
        '先完成一个微小闭环，再决定下一步。',
        '我的任务不是想清楚，而是启动并保持。',
      ];

  Widget _buildSelfDisciplineHighFidelityPanel() {
    final facts = widget.draft.prepState.selectedFacts.take(3).toList();
    final risks = widget.draft.prepState.rankedRisks.take(3).toList();
    final executionPhase = _state.goalProgress >= 60
        ? '推进保持阶段'
        : _state.timeLeft <= 40
            ? '拖延回潮阶段'
            : _state.turnNo == 0
                ? '启动第一步阶段'
                : '抗干扰阶段';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.directions_run_outlined),
          const SizedBox(width: 8),
          const Expanded(child: Text('自律启动高保真推进板', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(999)),
            child: Text(executionPhase, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9))),
          ),
        ]),
        const SizedBox(height: 10),
        const Text(
          '这一舱更强调：切断借口、先做第一步、压低完美标准，并在阻力里把行动继续下去。',
          style: TextStyle(color: Color(0xFF4B5563), height: 1.45),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ...facts.map((e) => _chip('启动事实：$e', const Color(0xFFEDE9FE))),
          ...risks.map((e) => _chip('拖延风险：$e', const Color(0xFFFEF3C7))),
        ]),
        const SizedBox(height: 12),
        const Text('你的最小行动链', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(widget.draft.prepState.orderedActions.take(4).join(' → '), style: const TextStyle(color: Color(0xFF374151))),
        const SizedBox(height: 12),
        const Text('快速推进模板（点击可填入输入框）', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _selfDisciplineMicroActions()
              .map((e) => ActionChip(
                    label: Text(e, style: const TextStyle(fontSize: 12.5)),
                    onPressed: () {
                      final old = _inputCtrl.text.trim();
                      final next = old.isEmpty ? e : '$old\n$e';
                      setState(() => _inputCtrl.text = next);
                    },
                  ))
              .toList(),
        ),
      ]),
    );
  }

  Widget _statusTile(String label, int value, Color color) {
    return Container(
      width: 104,
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(height: 4),
        Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft.descriptor;
    return Scaffold(
      appBar: AppBar(
        title: Text('${d.title} · 行动舱'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            onPressed: (_scene != null && !_finishing) ? _finish : null,
            icon: const Icon(Icons.flag_outlined),
            tooltip: '结束并结算',
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F7FB),
      body: _loading && _scene == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(14)),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('阶段 3 / 6 · 现实行动模拟', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('当前态度：${widget.draft.selectedAttitude} · 会话 ID：${_sessionKey.isEmpty ? _ensureSessionKey() : _sessionKey}', style: const TextStyle(color: Color(0xFF6B7280))),
                    const SizedBox(height: 12),
                    Wrap(children: [
                      _statusTile('信任', _state.trustScore, const Color(0xFFDBEAFE)),
                      _statusTile('风险', _state.riskScore, const Color(0xFFFEE2E2)),
                      _statusTile('时间', _state.timeLeft, const Color(0xFFFEF3C7)),
                      _statusTile('推进', _state.goalProgress, const Color(0xFFDCFCE7)),
                      _statusTile('张力', _state.emotionTension, const Color(0xFFFCE7F3)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 12),
                if (d.type == TrainingCabinType.delayReport) ...[
                  _buildDelayReportHighFidelityPanel(),
                  const SizedBox(height: 12),
                ],
                if (d.type == TrainingCabinType.boundaryExpression) ...[
                  _buildBoundaryHighFidelityPanel(),
                  const SizedBox(height: 12),
                ],
                if (d.type == TrainingCabinType.selfDisciplineStart) ...[
                  _buildSelfDisciplineHighFidelityPanel(),
                  const SizedBox(height: 12),
                ],
                if (_scene != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_scene!.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text('目标：${_scene!.goal}', style: const TextStyle(color: Color(0xFF4B5563))),
                      if (_scene!.abnormalEvents.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _scene!.abnormalEvents.take(3).map((e) => _chip(e, const Color(0xFFFFEDD5))).toList(),
                        ),
                      ],
                    ]),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('对话与行动', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    for (final msg in _messages)
                      Align(
                        alignment: msg.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 520),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: msg.role == 'user' ? const Color(0xFFDBEAFE) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(msg.content, style: const TextStyle(height: 1.45)),
                        ),
                      ),
                  ]),
                ),
                if (_triggeredEvents.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Expanded(child: Text('冲击与异常', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                        _chip('累计 ${_triggeredEvents.length}', const Color(0xFFFFEDD5)),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: _triggeredEvents.map((e) => _chip(e, const Color(0xFFFEF2F2))).toList()),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('本轮操作', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    const Text('选择态度语气'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: d.toneOptions
                          .map((e) => ChoiceChip(label: Text(e), selected: _selectedTone == e, onSelected: (_) => setState(() => _selectedTone = e)))
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text('选择这一步要做的动作'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: d.quickActionChips
                          .map((e) => ChoiceChip(label: Text(e), selected: _selectedAction == e, onSelected: (_) => setState(() => _selectedAction = e)))
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _inputCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: d.type == TrainingCabinType.selfDisciplineStart
                            ? '输入你现在要执行的第一步动作、你想切断的借口，或你准备怎么继续推进。'
                            : '输入你这一轮准备说的话，或你要执行的下一步动作。',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: (_loading || _finishing) ? null : _submitTurn,
                          icon: const Icon(Icons.send),
                          label: Text(_loading ? '处理中…' : '提交这一轮'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: '复制当前会话快照',
                        onPressed: () async {
                          final payload = {
                            'sessionKey': _sessionKey,
                            'cabin': d.title,
                            'state': _state.toJson(),
                            'messages': _messages.map((e) => e.toJson()).toList(),
                            'triggered_events': _triggeredEvents,
                          };
                          await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(payload)));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制当前会话快照')));
                          }
                        },
                        icon: const Icon(Icons.copy_all_outlined),
                      ),
                    ]),
                  ]),
                ),
              ],
            ),
    );
  }

  Widget _chip(String text, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(fontSize: 12.5)),
      );
}


class _ImpactSheet extends StatefulWidget {
  final TrainingCabinDescriptor descriptor;
  final List<String> impacts;
  final ChallengeWorldState state;

  const _ImpactSheet({required this.descriptor, required this.impacts, required this.state});

  @override
  State<_ImpactSheet> createState() => _ImpactSheetState();
}

class _ImpactSheetState extends State<_ImpactSheet> {
  Timer? _timer;
  int _secondsLeft = 12;
  String? _selectedDecision;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
      } else {
        if (_secondsLeft <= 4) HapticFeedback.selectionClick();
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<Map<String, String>> _decisionOptions() {
    switch (widget.descriptor.type) {
      case TrainingCabinType.boundaryExpression:
        return const [
          {
            'label': '先确认关系，再清楚立边界',
            'action': '明确边界',
            'tone': '温和',
            'phrase': '我理解你现在很需要支持，但这件事我不能答应。'
          },
          {
            'label': '停止过度解释，重复边界',
            'action': '重申立场',
            'tone': '边界清晰',
            'phrase': '我已经把边界说清楚了，这个决定不会因为压力而改变。'
          },
          {
            'label': '缩小支持范围，避免全盘接下',
            'action': '明确边界',
            'tone': '平稳',
            'phrase': '我能支持你的范围是这个部分，但不会接下全部责任。'
          },
        ];
      case TrainingCabinType.selfDisciplineStart:
        return const [
          {
            'label': '立即锁定最小行动并开始',
            'action': '开始第一步',
            'tone': '坚定',
            'phrase': '现在先做第一步，不讨论最后做得怎样。'
          },
          {
            'label': '先切断一个干扰源',
            'action': '切断干扰',
            'tone': '抗干扰',
            'phrase': '先把一个干扰源关掉，然后立刻开始 3 分钟。'
          },
          {
            'label': '压低标准，先完成微小闭环',
            'action': '降低标准',
            'tone': '稳定',
            'phrase': '我现在的任务不是完美，而是先完成一个最小闭环。'
          },
        ];
      case TrainingCabinType.delayReport:
      default:
        return const [
          {
            'label': '先承担，再说明影响范围',
            'action': '确认责任',
            'tone': '承担',
            'phrase': '这件事我先承担责任，我先把影响范围说清楚。'
          },
          {
            'label': '直接给补救时点',
            'action': '给出方案',
            'tone': '坚定',
            'phrase': '今天 18 点前我给你明确修复时间表，并同步下一次更新时间。'
          },
          {
            'label': '先止损，再解释原因边界',
            'action': '收束局面',
            'tone': '稳定',
            'phrase': '现在先止损最重要，原因边界我会在方案后面讲清楚。'
          },
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final descriptor = widget.descriptor;
    final impacts = widget.impacts;
    final state = widget.state;
    final options = _decisionOptions();
    final color = descriptor.type == TrainingCabinType.delayReport
        ? const Color(0xFF7C2D12)
        : descriptor.type == TrainingCabinType.boundaryExpression
            ? const Color(0xFF9D174D)
            : const Color(0xFF6D28D9);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.priority_high_rounded, color: color),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('冲击层触发', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
                child: Text('$_secondsLeft 秒', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _secondsLeft / 12,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
              color: color,
              backgroundColor: const Color(0xFFF3F4F6),
            ),
            const SizedBox(height: 10),
            Text(
              descriptor.type == TrainingCabinType.delayReport
                  ? '局势开始像现实中的延期汇报那样变得更紧。现在你必须做一个快速现实决断。'
                  : descriptor.type == TrainingCabinType.boundaryExpression
                      ? '关系压力正在升高。先做一个快速边界决断，再继续应对。'
                      : '阻力正在回潮。先做一个快速行动决断，再继续推进。',
              style: const TextStyle(color: Color(0xFF4B5563), height: 1.45),
            ),
            const SizedBox(height: 12),
            ...impacts.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $e', style: const TextStyle(color: Color(0xFF111827), height: 1.4)),
                )),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _miniPill('风险 ${state.riskScore}'),
              _miniPill('信任 ${state.trustScore}'),
              _miniPill('剩余时间 ${state.timeLeft}'),
              _miniPill('推进 ${state.goalProgress}'),
            ]),
            const SizedBox(height: 14),
            const Text('快速决断（先选一个，系统会把建议动作写回本轮输入）', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...options.map((option) {
              final selected = _selectedDecision == option['label'];
              return GestureDetector(
                onTap: () => setState(() => _selectedDecision = option['label']),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.08) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: selected ? color : const Color(0xFFE5E7EB), width: selected ? 1.6 : 1),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(option['label'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(option['phrase'] ?? '', style: const TextStyle(color: Color(0xFF6B7280), height: 1.35)),
                      ]),
                    ),
                    if (selected) Icon(Icons.check_circle, color: color),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _selectedDecision == null
                    ? null
                    : () {
                        final picked = options.firstWhere((e) => e['label'] == _selectedDecision);
                        Navigator.of(context).pop({
                          'quick_decision': picked['label'] ?? '',
                          'decision_label': picked['label'] ?? '',
                          'suggested_phrase': picked['phrase'] ?? '',
                          'tone': picked['tone'] ?? '',
                          'action': picked['action'] ?? '',
                          'impact_count': impacts.length,
                          'seconds_left': _secondsLeft,
                        });
                      },
                icon: const Icon(Icons.flash_on_outlined),
                label: const Text('锁定这个快速决断'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniPill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(fontSize: 12.5)),
      );
}
