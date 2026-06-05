import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/kv_dao.dart';
import 'behavior_action_chain_page.dart';
import 'concept_engine_dao.dart';
import 'concept_engine_detail_page.dart';
import 'concept_engine_models.dart';
import 'concept_engine_service.dart';

class ConceptEngineSessionPage extends StatefulWidget {
  final String? initialConcept;
  final String? initialDomain;
  final String? initialGoal;
  final ConceptParseResult? initialParse;
  final List<SceneOption>? initialScenes;
  final SceneOption? initialScene;
  final String? worldZoneTitle;
  final String? worldZoneId;
  final int worldAnomalyLevel;

  const ConceptEngineSessionPage({
    super.key,
    this.initialConcept,
    this.initialDomain,
    this.initialGoal,
    this.initialParse,
    this.initialScenes,
    this.initialScene,
    this.worldZoneTitle,
    this.worldZoneId,
    this.worldAnomalyLevel = 0,
  });

  @override
  State<ConceptEngineSessionPage> createState() => _ConceptEngineSessionPageState();
}

class _ConceptEngineSessionPageState extends State<ConceptEngineSessionPage> {
  final _service = ConceptEngineService();
  final _dao = ConceptEngineDao();
  final _kvDao = KeyValueDao();

  final _conceptCtrl = TextEditingController();
  final _domainCtrl = TextEditingController(text: '职场');
  final _goalCtrl = TextEditingController();
  final _turnCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  ConceptEngineRuntimeConfig? _runtimeConfig;
  ConceptParseResult? _parse;
  List<SceneOption> _scenes = const [];
  SceneOption? _selectedScene;
  ChallengeWorldState _state = ChallengeWorldState.initial();
  List<ChallengeMessage> _messages = <ChallengeMessage>[];
  ReplayResult? _replay;
  List<String> _actionTags = <String>[];
  List<String> _triggeredEvents = <String>[];
  ConceptEngineSessionRecord? _lastSavedRecord;
  ConceptWorldRewardResult? _worldReward;
  bool _saved = false;
  String _sessionKey = '';

  @override
  void initState() {
    super.initState();
    if ((widget.initialConcept ?? '').trim().isNotEmpty) _conceptCtrl.text = widget.initialConcept!.trim();
    if ((widget.initialDomain ?? '').trim().isNotEmpty) _domainCtrl.text = widget.initialDomain!.trim();
    if ((widget.initialGoal ?? '').trim().isNotEmpty) _goalCtrl.text = widget.initialGoal!.trim();
    if (widget.initialParse != null) {
      _parse = widget.initialParse;
      _restoreSavedBehaviors();
    }
    if (widget.initialScenes != null) _scenes = List<SceneOption>.from(widget.initialScenes!);
    _loadRuntimeConfig();
    if (widget.initialScene != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startScene(widget.initialScene!);
      });
    }
  }

  String _ensureSessionKey() {
    if (_sessionKey.isEmpty) {
      _sessionKey = 'ces_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    }
    return _sessionKey;
  }

  Future<void> _loadRuntimeConfig() async {
    try {
      final cfg = await _service.loadRuntimeConfig();
      if (!mounted) return;
      setState(() => _runtimeConfig = cfg);
    } catch (_) {}
  }

  @override
  void dispose() {
    _conceptCtrl.dispose();
    _domainCtrl.dispose();
    _goalCtrl.dispose();
    _turnCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _parseConcept() async {
    if (_conceptCtrl.text.trim().isEmpty) {
      _toast('请先输入一个概念');
      return;
    }
    await _loadRuntimeConfig();
    setState(() {
      _loading = true;
      _error = null;
      _parse = null;
      _scenes = const [];
      _selectedScene = null;
      _messages = <ChallengeMessage>[];
      _state = ChallengeWorldState.initial();
      _replay = null;
      _lastSavedRecord = null;
      _saved = false;
      _worldReward = null;
      _sessionKey = '';
    });
    try {
      final parse = await _service.parseConcept(
        concept: _conceptCtrl.text.trim(),
        domain: _domainCtrl.text.trim(),
        goal: _goalCtrl.text.trim(),
        sessionId: _ensureSessionKey(),
      );
      final effectiveParse = await _mergeBehaviorOverrides(parse);
      if (!mounted) return;
      setState(() => _parse = effectiveParse);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  String _behaviorStorageKey({String? concept, String? domain}) {
    final c = (concept ?? _conceptCtrl.text).trim();
    final d = (domain ?? _domainCtrl.text).trim();
    final raw = '${c.toLowerCase()}||${d.toLowerCase()}';
    return 'ce_behavior_list_${base64Url.encode(utf8.encode(raw)).replaceAll('=', '')}';
  }

  List<String> _normalizedBehaviors(List<String> items) {
    final seen = <String>{};
    final result = <String>[];
    for (final item in items) {
      final text = item.trim();
      if (text.isEmpty) continue;
      if (seen.add(text)) result.add(text);
    }
    return result;
  }

  Future<ConceptParseResult> _mergeBehaviorOverrides(ConceptParseResult parse) async {
    final saved = await _kvDao.getString(_behaviorStorageKey(concept: parse.concept, domain: parse.domain));
    if ((saved ?? '').trim().isEmpty) return parse;
    try {
      final decoded = jsonDecode(saved!);
      if (decoded is! List) return parse;
      final savedList = _normalizedBehaviors(decoded.map((e) => e.toString()).toList());
      if (savedList.isEmpty) return parse;
      return parse.copyWith(behaviors: savedList);
    } catch (_) {
      return parse;
    }
  }

  Future<void> _restoreSavedBehaviors() async {
    final parse = _parse;
    if (parse == null) return;
    final merged = await _mergeBehaviorOverrides(parse);
    if (!mounted) return;
    if (jsonEncode(merged.behaviors) != jsonEncode(parse.behaviors)) {
      setState(() => _parse = merged);
    }
  }

  Future<void> _saveBehaviors() async {
    final parse = _parse;
    if (parse == null) return;
    final normalized = _normalizedBehaviors(parse.behaviors);
    setState(() => _parse = parse.copyWith(behaviors: normalized));
    await _kvDao.setString(_behaviorStorageKey(), jsonEncode(normalized));
    _toast('行为表现已保存');
  }

  Future<String?> _showBehaviorEditorDialog({
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入行为表现，例如：先在日历里固定训练时间，再按时到场。',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value?.trim();
  }

  Future<void> _addCustomBehavior() async {
    final parse = _parse;
    if (parse == null) return;
    final value = await _showBehaviorEditorDialog(title: '新增自定义行为表现');
    if (value == null || value.isEmpty) return;
    setState(() {
      _parse = parse.copyWith(behaviors: _normalizedBehaviors([...parse.behaviors, value]));
    });
    await _saveBehaviors();
  }

  Future<void> _editBehavior(int index) async {
    final parse = _parse;
    if (parse == null || index < 0 || index >= parse.behaviors.length) return;
    final value = await _showBehaviorEditorDialog(title: '编辑行为表现', initialValue: parse.behaviors[index]);
    if (value == null || value.isEmpty) return;
    final items = List<String>.from(parse.behaviors);
    items[index] = value;
    setState(() => _parse = parse.copyWith(behaviors: _normalizedBehaviors(items)));
    await _saveBehaviors();
  }

  Future<void> _removeBehavior(int index) async {
    final parse = _parse;
    if (parse == null || index < 0 || index >= parse.behaviors.length) return;
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除行为表现'),
            content: Text('确认删除这条行为表现吗？\n\n${parse.behaviors[index]}'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('删除')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    final items = List<String>.from(parse.behaviors)..removeAt(index);
    setState(() => _parse = parse.copyWith(behaviors: items));
    await _saveBehaviors();
  }

  Future<void> _openBehaviorActionChain(String behavior) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BehaviorActionChainPage(
          concept: _conceptCtrl.text.trim(),
          domain: _domainCtrl.text.trim(),
          goal: _goalCtrl.text.trim(),
          behavior: behavior,
          sessionId: _ensureSessionKey(),
        ),
      ),
    );
  }

  Future<void> _generateScenes() async {
    final parse = _parse;
    if (parse == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _scenes = const [];
      _selectedScene = null;
      _messages = <ChallengeMessage>[];
      _state = ChallengeWorldState.initial();
      _replay = null;
      _lastSavedRecord = null;
      _saved = false;
      _worldReward = null;
    });
    try {
      final scenes = await _service.generateScenes(
        concept: _conceptCtrl.text.trim(),
        domain: _domainCtrl.text.trim(),
        goal: _goalCtrl.text.trim(),
        parseResult: parse,
        sessionId: _ensureSessionKey(),
      );
      if (!mounted) return;
      setState(() => _scenes = scenes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startScene(SceneOption scene) {
    final opening = [
      '你当前的角色：${scene.userRole}',
      '目标：${scene.goal}',
      '背景：${scene.background}',
      if (scene.constraints.isNotEmpty) '限制：${scene.constraints.join('；')}',
      if (scene.abnormalEvents.isNotEmpty) '潜在突发：${scene.abnormalEvents.join('；')}',
      '请直接输入你的第一步动作或你准备说的话。',
    ].join('\n');

    setState(() {
      _selectedScene = scene;
      _state = ChallengeWorldState.initial();
      _messages = [
        ChallengeMessage(role: 'assistant', content: opening, createdAt: DateTime.now()),
      ];
      _replay = null;
      _lastSavedRecord = null;
      _worldReward = null;
      _saved = false;
      _actionTags = <String>[];
      _triggeredEvents = <String>[];
    });
  }

  Future<void> _sendTurn() async {
    final scene = _selectedScene;
    if (scene == null) return;
    final text = _turnCtrl.text.trim();
    if (text.isEmpty) return;

    final userMsg = ChallengeMessage(role: 'user', content: text, createdAt: DateTime.now());
    setState(() {
      _turnCtrl.clear();
      _loading = true;
      _error = null;
      _messages = [..._messages, userMsg];
    });

    try {
      final res = await _service.runTurn(
        scene: scene,
        state: _state,
        history: _messages,
        userInput: text,
        sessionId: _ensureSessionKey(),
      );
      if (!mounted) return;
      setState(() {
        _state = res.state;
        _actionTags.addAll(res.actionTags);
        _triggeredEvents.addAll(res.triggeredEvents);
        _messages = [
          ..._messages,
          ChallengeMessage(role: 'assistant', content: res.assistantReply, createdAt: DateTime.now()),
        ];
      });

      if (res.state.finished) {
        await _finishChallenge();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _finishChallenge() async {
    final scene = _selectedScene;
    if (scene == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final replay = await _service.analyzeReplay(
        concept: _conceptCtrl.text.trim(),
        domain: _domainCtrl.text.trim(),
        goal: _goalCtrl.text.trim(),
        scene: scene,
        state: _state,
        history: _messages,
        sessionId: _ensureSessionKey(),
      );
      if (!mounted) return;
      setState(() => _replay = replay);
      await _saveReplayIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveReplayIfNeeded() async {
    if (_saved || _replay == null || _selectedScene == null) return;
    try {
      await _dao.ensureSchema();
      final insertedId = await _dao.insertSession(
        concept: _conceptCtrl.text.trim(),
        domain: _domainCtrl.text.trim(),
        goal: _goalCtrl.text.trim(),
        sceneTitle: _selectedScene!.title,
        provider: _runtimeConfig?.provider ?? 'deepseek',
        model: _runtimeConfig?.model ?? '',
        transportMode: _runtimeConfig?.transportMode ?? ConceptEngineService.transportDirect,
        sessionKey: _sessionKey,
        replay: _replay!,
        state: _state,
        scene: _selectedScene,
        history: _messages,
        actionTags: _actionTags,
        triggeredEvents: _triggeredEvents,
      );
      final reward = await _dao.applyReplayReward(
        replay: _replay!,
        domain: _domainCtrl.text.trim(),
        sceneTitle: _selectedScene?.title ?? '',
        zoneId: widget.worldZoneId,
      );
      if (insertedId > 0) {
        final latest = await _dao.getById(insertedId);
        if (latest != null && mounted) {
          setState(() {
            _lastSavedRecord = latest;
            _worldReward = reward;
            _saved = true;
          });
          return;
        }
      }
      if (mounted) {
        setState(() {
          _worldReward = reward;
          _saved = true;
        });
      } else {
        _saved = true;
      }
    } catch (_) {}
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }

  Widget _chip(String text) => Container(
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12.5)),
      );

  Widget _statTile(String label, int value, Color color) {
    return Container(
      width: 104,
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }


  Widget _rewardChip(String text, {Color bg = const Color(0xFFECFDF5), Color fg = const Color(0xFF065F46)}) => Container(
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg)),
      );

  Widget _providerChip() {
    final cfg = _runtimeConfig;
    final isOpenAi = cfg?.provider == 'openai';
    final label = cfg?.providerLabel ?? '未加载';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isOpenAi ? const Color(0xFFCCFBF1) : const Color(0xFFE0E7FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '当前提供商：$label',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: isOpenAi ? const Color(0xFF115E59) : const Color(0xFF3730A3),
        ),
      ),
    );
  }

  Widget _infoChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151))),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('概念实践引擎'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loading ? null : _finishChallenge,
            icon: const Icon(Icons.flag_outlined),
            tooltip: '结束并复盘',
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F7FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _providerChip(),
                  const SizedBox(width: 8),
                  _infoChip(_runtimeConfig?.model.isNotEmpty == true ? _runtimeConfig!.model : '未配置模型'),
                  const SizedBox(width: 8),
                  _infoChip(_runtimeConfig?.transportMode == ConceptEngineService.transportProxy ? '后端网关代理' : '客户端直连'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (widget.worldZoneTitle != null) ...[
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前世界区域：${widget.worldZoneTitle}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      widget.worldAnomalyLevel <= 0
                          ? '当前区域状态稳定，你可以按常规危险度进入训练。'
                          : '当前区域异常等级 ${widget.worldAnomalyLevel}，后续关卡会附带更多突发情况与更高危险度。',
                      style: const TextStyle(color: Color(0xFF4B5563), height: 1.4),
                    ),
                    if (widget.worldAnomalyLevel > 0) ...[
                      const SizedBox(height: 8),
                      Wrap(children: List.generate(widget.worldAnomalyLevel, (i) => _rewardChip('异常波动 ${i + 1}', bg: const Color(0xFFFEE2E2), fg: const Color(0xFFB91C1C)))),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. 先定义本次练习', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _conceptCtrl,
                    decoration: const InputDecoration(
                      labelText: '概念',
                      hintText: '例如：责任感、边界感、领导力',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _domainCtrl,
                    decoration: const InputDecoration(
                      labelText: '领域',
                      hintText: '例如：职场、亲密关系、团队协作',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _goalCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '训练目标',
                      hintText: '例如：项目延期时，我想练如何主动说明问题并给出补救方案',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _loading ? null : _parseConcept,
                        icon: const Icon(Icons.psychology_alt_outlined),
                        label: const Text('解析概念'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loading || _parse == null ? null : _generateScenes,
                        icon: const Icon(Icons.view_in_ar_outlined),
                        label: const Text('生成场景'),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                ],
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_parse != null) ...[
              const SizedBox(height: 16),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('2. 解析结果', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    if (_parse!.definitions.isNotEmpty) ...[
                      const Text('概念定义', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ..._parse!.definitions.take(3).map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• $e'),
                          )),
                    ],
                    const SizedBox(height: 12),
                    const Text('直观语言', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(children: _parse!.intuitiveDescriptions.map(_chip).toList()),
                    const SizedBox(height: 10),
                    const Text('行为表现', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _addCustomBehavior,
                          icon: const Icon(Icons.add),
                          label: const Text('新增自定义行为'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _saveBehaviors,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('保存行为表现'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_parse!.behaviors.length, (index) {
                      final behavior = _parse!.behaviors[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          title: Text(behavior, style: const TextStyle(height: 1.42)),
                          subtitle: const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text('点击进入行为行动链页，基于该行为生成可执行节点。'),
                          ),
                          trailing: SizedBox(
                            width: 128,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: '编辑',
                                  onPressed: () => _editBehavior(index),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: '删除',
                                  onPressed: () => _removeBehavior(index),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                          onTap: () => _openBehaviorActionChain(behavior),
                        ),
                      );
                    }),
                    if (_parse!.misunderstandings.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('常见误区', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ..._parse!.misunderstandings.take(4).map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• $e', style: const TextStyle(color: Color(0xFF6B7280))),
                          )),
                    ],
                    if (_parse!.directions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('推荐方向', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ..._parse!.directions.take(4).map((d) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: const Color(0xFFF9FAFB),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${d.name} · ${d.difficulty}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(d.whyFit, style: const TextStyle(color: Color(0xFF6B7280))),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ],
            if (_scenes.isNotEmpty) ...[
              const SizedBox(height: 16),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('3. 选择一个场景开始挑战', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    ..._scenes.map((scene) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _selectedScene?.sceneId == scene.sceneId
                                  ? Theme.of(context).colorScheme.primary
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: ListTile(
                            title: Text(scene.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${scene.userRole}\n${scene.goal}', maxLines: 3, overflow: TextOverflow.ellipsis),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _startScene(scene),
                          ),
                        )),
                  ],
                ),
              ),
            ],
            if (_selectedScene != null) ...[
              const SizedBox(height: 16),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('4. 场景挑战：${_selectedScene!.title}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Wrap(
                      children: [
                        _statTile('信任', _state.trustScore, Colors.blue),
                        _statTile('风险', _state.riskScore, Colors.red),
                        _statTile('剩余时间', _state.timeLeft, Colors.orange),
                      ],
                    ),
                    Wrap(
                      children: [
                        _statTile('目标推进', _state.goalProgress, Colors.green),
                        _statTile('团队稳定', _state.teamStability, Colors.teal),
                        _statTile('情绪张力', _state.emotionTension, Colors.purple),
                      ],
                    ),
                    if (_triggeredEvents.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('已触发事件', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Wrap(children: _triggeredEvents.take(8).map(_chip).toList()),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListView.builder(
                        itemCount: _messages.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (_, i) {
                          final msg = _messages[i];
                          final mine = msg.role == 'user';
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              constraints: const BoxConstraints(maxWidth: 320),
                              decoration: BoxDecoration(
                                color: mine ? const Color(0xFF111827) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                msg.content,
                                style: TextStyle(color: mine ? Colors.white : const Color(0xFF111827), height: 1.4),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _turnCtrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '输入你的动作 / 你要说的话',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _loading || _replay != null ? null : _sendTurn,
                            icon: const Icon(Icons.send),
                            label: const Text('发送本轮动作'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _finishChallenge,
                            icon: const Icon(Icons.flag_outlined),
                            label: const Text('结束并复盘'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (_replay != null) ...[
              const SizedBox(height: 16),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('5. 结果与复盘', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text('${_replay!.totalScore}分', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_replay!.resultLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_sessionKey.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '练习会话ID：$_sessionKey',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              final snapshot = jsonEncode({
                                'session_key': _sessionKey,
                                'provider': _runtimeConfig?.provider,
                                'model': _runtimeConfig?.model,
                                'transport_mode': _runtimeConfig?.transportMode,
                                'concept': _conceptCtrl.text.trim(),
                                'domain': _domainCtrl.text.trim(),
                                'goal': _goalCtrl.text.trim(),
                                'scene': _selectedScene?.toJson(),
                                'state': _state.toJson(),
                                'messages': _messages.map((e) => e.toJson()).toList(),
                                'replay': _replay?.toJson(),
                              });
                              Clipboard.setData(ClipboardData(text: snapshot));
                              _toast('已复制本次练习快照 JSON');
                            },
                            child: const Text('复制快照'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(_replay!.summary, style: const TextStyle(height: 1.45)),
                    const SizedBox(height: 12),
                    const Text('做得好的地方', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    ..._replay!.strengths.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• $e'),
                        )),
                    const SizedBox(height: 10),
                    const Text('需要修正的地方', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    ..._replay!.mistakes.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• $e'),
                        )),
                    if (_replay!.ignoredSignals.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('被忽略的信号', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      ..._replay!.ignoredSignals.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• $e'),
                          )),
                    ],
                    if (_replay!.betterActions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('更优替代动作', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      ..._replay!.betterActions.map((e) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.problem, style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(e.betterAction),
                                const SizedBox(height: 6),
                                Text('示例：${e.examplePhrase}', style: const TextStyle(color: Color(0xFF4B5563))),
                              ],
                            ),
                          )),
                    ],

                    if (_worldReward != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF111827), Color(0xFF1F2937)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.worldZoneTitle == null ? '虚拟世界结算' : '虚拟世界结算 · ${widget.worldZoneTitle}',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _rewardChip('+${_worldReward!.xpGained} XP', bg: const Color(0xFFDCFCE7), fg: const Color(0xFF166534)),
                                _rewardChip('Lv.${_worldReward!.profile.level}', bg: const Color(0xFFE0E7FF), fg: const Color(0xFF3730A3)),
                                _rewardChip('总经验 ${_worldReward!.profile.totalXp}', bg: const Color(0xFFFFF7ED), fg: const Color(0xFF9A3412)),
                                _rewardChip('连胜 ${_worldReward!.profile.streak}', bg: const Color(0xFFFCE7F3), fg: const Color(0xFF9D174D)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '训练总场次 ${_worldReward!.profile.totalRuns} · 成功通关 ${_worldReward!.profile.successfulRuns} · 距离下一等级还差 ${_worldReward!.profile.xpToNextLevel} XP',
                              style: const TextStyle(color: Colors.white70, height: 1.4),
                            ),
                            if (_worldReward!.unlockedAchievements.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              const Text('新解锁成就', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Wrap(
                                children: _worldReward!.unlockedAchievements
                                    .map((e) => _rewardChip('🏆 $e', bg: const Color(0xFFFEF3C7), fg: const Color(0xFF92400E)))
                                    .toList(),
                              ),
                            ],
                            if (_worldReward!.unlockedZones.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              const Text('新解锁区域', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Wrap(
                                children: _worldReward!.unlockedZones
                                    .map((e) => _rewardChip('🗺 $e', bg: const Color(0xFFDBEAFE), fg: const Color(0xFF1D4ED8)))
                                    .toList(),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Text('当前区域异常等级：${_worldReward!.anomalyLevelAfter}', style: const TextStyle(color: Colors.white70)),
                            if (_worldReward!.worldEvents.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              const Text('世界事件', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              ..._worldReward!.worldEvents.map((e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text('• $e', style: const TextStyle(color: Colors.white70, height: 1.35)),
                                  )),
                            ],
                          ],
                        ),
                      ),
                    ],

                    if (_replay!.nextTrainingFocus.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('下一轮建议', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Wrap(children: _replay!.nextTrainingFocus.map(_chip).toList()),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              if (widget.worldZoneTitle != null) {
                                Navigator.of(context).pop();
                                return;
                              }
                              setState(() {
                                _selectedScene = null;
                                _messages = <ChallengeMessage>[];
                                _state = ChallengeWorldState.initial();
                                _replay = null;
                                _lastSavedRecord = null;
                                _worldReward = null;
                                _triggeredEvents = <String>[];
                                _actionTags = <String>[];
                              });
                            },
                            icon: Icon(widget.worldZoneTitle == null ? Icons.refresh : Icons.map_outlined),
                            label: Text(widget.worldZoneTitle == null ? '换个场景再练' : '返回世界大厅'),
                          ),
                        ),
                      ],
                    ),
                    if (_lastSavedRecord != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ConceptEngineDetailPage(record: _lastSavedRecord!),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history_edu_outlined),
                          label: const Text('查看本次练习详情'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
