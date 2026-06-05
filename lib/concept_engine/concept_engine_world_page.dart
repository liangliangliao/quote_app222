import 'package:flutter/material.dart';

import 'concept_engine_dao.dart';
import 'concept_engine_models.dart';
import 'concept_engine_service.dart';
import 'concept_engine_session_page.dart';

class ConceptEngineWorldPage extends StatefulWidget {
  const ConceptEngineWorldPage({super.key});

  @override
  State<ConceptEngineWorldPage> createState() => _ConceptEngineWorldPageState();
}

class _ConceptEngineWorldPageState extends State<ConceptEngineWorldPage> {
  final _service = ConceptEngineService();
  final _dao = ConceptEngineDao();
  final _conceptCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();

  final List<Map<String, dynamic>> _zones = const [
    {
      'id': 'work',
      'title': '职场训练基地',
      'subtitle': '任务交付 / 汇报 / 责任承担',
      'domain': '职场',
      'unlockRequirement': '初始开放',
      'description': '在高压项目、延期沟通、客户冲突中练习责任感与执行力。',
      'icon': Icons.apartment_outlined,
      'color': Color(0xFFE0E7FF),
    },
    {
      'id': 'life',
      'title': '关系实验室',
      'subtitle': '边界感 / 沟通 / 情绪回应',
      'domain': '日常生活',
      'unlockRequirement': '完成 2 次职场成功训练或等级达到 Lv.2',
      'description': '在亲密关系、家庭互动和日常摩擦中练习表达与共情。',
      'icon': Icons.favorite_border,
      'color': Color(0xFFFCE7F3),
    },
    {
      'id': 'team',
      'title': '团队指挥塔',
      'subtitle': '协作 / 冲突处理 / 领导力',
      'domain': '团队协作',
      'unlockRequirement': '累计 3 次成功训练或等级达到 Lv.3',
      'description': '在多人任务、角色冲突和突发异常中练习判断与带队。',
      'icon': Icons.groups_2_outlined,
      'color': Color(0xFFDCFCE7),
    },
  ];

  int _zoneIndex = 0;
  bool _loading = false;
  String? _error;
  ConceptWorldMapData? _mapData;
  ConceptParseResult? _parse;
  List<SceneOption> _scenes = const [];

  @override
  void initState() {
    super.initState();
    _loadMap();
  }

  Future<void> _loadMap() async {
    await _dao.ensureSchema();
    final data = await _dao.getWorldMapData();
    if (!mounted) return;
    var idx = _zoneIndex;
    if (!_zoneState(_zones[_zoneIndex]['id'].toString(), data).unlocked) {
      idx = _zones.indexWhere((z) => _zoneState(z['id'].toString(), data).unlocked);
      if (idx < 0) idx = 0;
    }
    setState(() {
      _mapData = data;
      _zoneIndex = idx;
    });
  }

  ConceptWorldZoneState _zoneState(String id, [ConceptWorldMapData? map]) {
    final m = map ?? _mapData;
    if (m == null) return ConceptWorldZoneState.initial(id, unlocked: id == 'work');
    return m.stateFor(id);
  }

  Map<String, dynamic> get _zone => _zones[_zoneIndex];
  ConceptWorldZoneState get _currentZoneState => _zoneState(_zone['id'].toString());

  Future<void> _generateMissions() async {
    if (!_currentZoneState.unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('该区域尚未解锁，请先完成前置训练。')));
      return;
    }
    if (_conceptCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先输入一个概念')));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _parse = null;
      _scenes = const [];
    });
    try {
      final domain = (_zone['domain'] ?? '职场').toString();
      final sessionId = 'world_${DateTime.now().millisecondsSinceEpoch}';
      final parse = await _service.parseConcept(
        concept: _conceptCtrl.text.trim(),
        domain: domain,
        goal: _goalCtrl.text.trim(),
        sessionId: sessionId,
      );
      final rawScenes = await _service.generateScenes(
        concept: _conceptCtrl.text.trim(),
        domain: domain,
        goal: _goalCtrl.text.trim(),
        parseResult: parse,
        sessionId: sessionId,
      );
      final scenes = rawScenes.map((e) => _applyZoneAnomaly(e, _currentZoneState)).toList();
      if (!mounted) return;
      setState(() {
        _parse = parse;
        _scenes = scenes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  SceneOption _applyZoneAnomaly(SceneOption scene, ConceptWorldZoneState state) {
    if (state.anomalyLevel <= 0) return scene;
    final extra = List<String>.from(scene.abnormalEvents);
    final extraFailure = List<String>.from(scene.failureCriteria);
    final extraConstraints = List<String>.from(scene.constraints);
    if (state.anomalyLevel >= 1) {
      extra.add('世界异常：局部关系失衡，对方更容易误解你的意图');
      extraConstraints.add('当前区域存在轻度异常波动，容错率下降');
    }
    if (state.anomalyLevel >= 2) {
      extra.add('世界异常：额外出现一次高压追问或协作失序');
      extraFailure.add('忽视二次追问导致局势继续恶化');
    }
    if (state.anomalyLevel >= 3) {
      extra.add('世界异常：关键角色情绪失控或资源再次缩水');
      extraFailure.add('未在极端波动下稳住局面，世界异常进一步蔓延');
    }
    return SceneOption(
      sceneId: scene.sceneId,
      title: state.anomalyLevel > 0 ? '${scene.title} · 异常版' : scene.title,
      userRole: scene.userRole,
      goal: scene.goal,
      background: scene.background,
      constraints: extraConstraints,
      keyNpcs: scene.keyNpcs,
      normalEvents: scene.normalEvents,
      abnormalEvents: extra,
      successCriteria: scene.successCriteria,
      failureCriteria: extraFailure,
      trainingFocus: scene.trainingFocus,
      estimatedTurns: scene.estimatedTurns + state.anomalyLevel,
    );
  }

  int _estimateXp(SceneOption scene) {
    return 18 + scene.abnormalEvents.length * 4 + scene.trainingFocus.length * 2 + scene.estimatedTurns + _currentZoneState.anomalyLevel * 3;
  }

  int _dangerLevel(SceneOption scene) {
    final raw = scene.abnormalEvents.length + scene.failureCriteria.length + _currentZoneState.anomalyLevel;
    if (raw >= 7) return 5;
    if (raw >= 5) return 4;
    if (raw >= 3) return 3;
    if (raw >= 2) return 2;
    return 1;
  }

  Future<void> _openMission(SceneOption scene) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConceptEngineSessionPage(
          initialConcept: _conceptCtrl.text.trim(),
          initialDomain: (_zone['domain'] ?? '职场').toString(),
          initialGoal: _goalCtrl.text.trim(),
          initialParse: _parse,
          initialScenes: _scenes,
          initialScene: scene,
          worldZoneTitle: (_zone['title'] ?? '').toString(),
          worldZoneId: (_zone['id'] ?? '').toString(),
          worldAnomalyLevel: _currentZoneState.anomalyLevel,
        ),
      ),
    );
    _loadMap();
  }

  Widget _worldProfilePanel() {
    final data = _mapData ?? ConceptWorldMapData(profile: ConceptWorldProfile.initial(), zones: const []);
    final p = data.profile;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('虚拟世界大厅', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('等级 Lv.${p.level} · 总经验 ${p.totalXp} · 连胜 ${p.streak}', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: p.xpIntoCurrentLevel / 100,
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.white12,
          ),
          const SizedBox(height: 8),
          Text('距离下一级还差 ${p.xpToNextLevel} XP · 成就 ${p.achievements.length} 枚 · 世界异常总值 ${data.totalAnomalyLevel}', style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _mapNode(int index) {
    final z = _zones[index];
    final selected = index == _zoneIndex;
    final state = _zoneState(z['id'].toString());
    final unlocked = state.unlocked;
    final color = z['color'] as Color;
    return InkWell(
      onTap: () => setState(() {
        _zoneIndex = index;
        _parse = null;
        _scenes = const [];
      }),
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unlocked ? (selected ? color : Colors.white) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? Colors.black12 : const Color(0xFFE5E7EB)),
          boxShadow: selected ? const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(unlocked ? z['icon'] as IconData : Icons.lock_outline, size: 26, color: unlocked ? null : const Color(0xFF6B7280)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: unlocked ? const Color(0xFFECFDF5) : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(unlocked ? '已解锁' : '未解锁', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: unlocked ? const Color(0xFF065F46) : const Color(0xFF6B7280))),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(z['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            Text(z['subtitle'].toString(), style: const TextStyle(color: Color(0xFF4B5563), height: 1.35)),
            const SizedBox(height: 8),
            Text(
              unlocked ? '净化 ${state.clearedCount} · 失守 ${state.failedCount} · 异常 ${state.anomalyLabel}' : '解锁条件：${z['unlockRequirement']}',
              style: TextStyle(fontSize: 12.5, color: unlocked && state.anomalyLevel > 0 ? const Color(0xFFB91C1C) : const Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _worldMapSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('世界地图与解锁树', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('先净化前置区域，再逐步解锁更复杂的现实训练世界。', style: TextStyle(color: Color(0xFF6B7280), height: 1.4)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _mapNode(0),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF9CA3AF)),
                ),
                _mapNode(1),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF9CA3AF)),
                ),
                _mapNode(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _anomalySection() {
    final data = _mapData;
    if (data == null) return const SizedBox.shrink();
    final active = data.zones.where((z) => z.anomalyLevel > 0).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: active.isEmpty ? Colors.white : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active.isEmpty ? const Color(0xFFE5E7EB) : const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('世界异常监测', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (active.isEmpty)
            const Text('当前世界稳定，没有需要优先净化的异常区域。', style: TextStyle(color: Color(0xFF4B5563), height: 1.4))
          else ...[
            const Text('以下区域存在异常波动，进入关卡时会附带额外突发事件与更高危险度。', style: TextStyle(color: Color(0xFF7F1D1D), height: 1.4)),
            const SizedBox(height: 10),
            ...active.map((z) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${_titleForZone(z.zoneId)} · 异常 ${z.anomalyLabel} · 已净化 ${z.clearedCount} 次 / 失守 ${z.failedCount} 次'),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  String _titleForZone(String zoneId) => _zones.firstWhere((z) => z['id'] == zoneId, orElse: () => _zones.first)['title'].toString();

  @override
  void dispose() {
    _conceptCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('概念实践虚拟世界'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF7F7FB),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _worldProfilePanel(),
          const SizedBox(height: 16),
          _worldMapSection(),
          const SizedBox(height: 16),
          _anomalySection(),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('为 ${_zone['title']} 生成任务关卡', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(_currentZoneState.unlocked
                    ? '当前区域异常：${_currentZoneState.anomalyLabel}。异常越高，生成的关卡越危险。'
                    : '当前区域尚未解锁：${_zone['unlockRequirement']}'),
                const SizedBox(height: 10),
                TextField(
                  controller: _conceptCtrl,
                  decoration: const InputDecoration(labelText: '训练概念', hintText: '例如：责任感 / 谈判能力 / 领导力', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _goalCtrl,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '训练目标', hintText: '例如：练习项目延期时如何承担责任并稳住客户', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _loading || !_currentZoneState.unlocked ? null : _generateMissions,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(_loading ? '正在生成关卡…' : '生成任务关卡'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          if (_parse != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('任务前情报', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _parse!.intuitiveDescriptions.take(4).map((e) => Chip(label: Text(e))).toList(),
                  ),
                ],
              ),
            ),
          ],
          if (_scenes.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('可进入的关卡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ..._scenes.map((scene) {
              final xp = _estimateXp(scene);
              final danger = _dangerLevel(scene);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4))]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(scene.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                        Chip(label: Text('+${xp} XP')),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(scene.goal, style: const TextStyle(color: Color(0xFF374151), height: 1.4)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(scene.userRole)),
                        Chip(label: Text('预计 ${scene.estimatedTurns} 回合')),
                        Chip(label: Text('危险 ${'★' * danger}')),
                        if (scene.abnormalEvents.isNotEmpty) Chip(label: Text('异常 ${scene.abnormalEvents.length} 项')),
                      ],
                    ),
                    if (scene.trainingFocus.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('训练重点：${scene.trainingFocus.join(' / ')}', style: const TextStyle(color: Color(0xFF6B7280))),
                    ],
                    if (_currentZoneState.anomalyLevel > 0) ...[
                      const SizedBox(height: 8),
                      Text('世界异常加成：当前区域异常等级 ${_currentZoneState.anomalyLevel}，本关卡已附加异常版事件。', style: const TextStyle(color: Color(0xFFB91C1C))),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _openMission(scene),
                      icon: const Icon(Icons.sports_esports_outlined),
                      label: const Text('进入关卡挑战'),
                    ),
                  ],
                ),
              );
            }),
          ] else if (_parse != null && !_loading) ...[
            const SizedBox(height: 16),
            const Text('暂未生成可进入关卡，请重试。'),
          ],
        ],
      ),
    );
  }
}
