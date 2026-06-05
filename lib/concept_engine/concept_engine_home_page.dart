import 'package:flutter/material.dart';

import 'concept_engine_dao.dart';
import 'concept_engine_models.dart';
import 'concept_engine_detail_page.dart';
import 'concept_engine_service.dart';
import 'concept_engine_session_page.dart';
import 'concept_engine_world_page.dart';
import 'cabins/training_hub_page.dart';
import 'action_engine/pages/action_engine_home_page.dart';
import 'cabins/training_growth_archive_page.dart';

class ConceptEngineHomePage extends StatefulWidget {
  const ConceptEngineHomePage({super.key});

  @override
  State<ConceptEngineHomePage> createState() => _ConceptEngineHomePageState();
}

class _ConceptEngineHomePageState extends State<ConceptEngineHomePage> {
  final _dao = ConceptEngineDao();
  final _service = ConceptEngineService();
  final _searchCtrl = TextEditingController();

  List<ConceptEngineSessionRecord> _recent = const [];
  bool _loading = true;
  ConceptEngineRuntimeConfig? _runtimeConfig;
  ConceptWorldProfile? _worldProfile;
  ConceptWorldMapData? _worldMapData;
  String _providerFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _dao.ensureSchema();
    final rows = await _dao.listRecent(limit: 50);
    final cfg = await _service.loadRuntimeConfig();
    if (!mounted) return;
    final profile = await _dao.getWorldProfile();
    final mapData = await _dao.getWorldMapData();
    setState(() {
      _recent = rows;
      _runtimeConfig = cfg;
      _worldProfile = profile;
      _worldMapData = mapData;
      _loading = false;
    });
  }

  Future<void> _openSession({ConceptEngineSessionRecord? fromRecord}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConceptEngineSessionPage(
          initialConcept: fromRecord?.concept,
          initialDomain: fromRecord?.domain,
          initialGoal: fromRecord?.goal,
        ),
      ),
    );
    _load();
  }


  Future<void> _openWorldHall() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ConceptEngineWorldPage()),
    );
    _load();
  }

  Future<void> _openTrainingHub() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TrainingHubPage()),
    );
    _load();
  }


  Future<void> _openActionEngine() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ActionEngineHomePage()),
    );
    _load();
  }

  Widget _providerChip(String label, String provider) {
    final isOpenAi = provider == 'openai';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isOpenAi ? const Color(0xFFCCFBF1) : const Color(0xFFE0E7FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '当前模型：$label',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: isOpenAi ? const Color(0xFF115E59) : const Color(0xFF3730A3),
        ),
      ),
    );
  }

  Widget _metaChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151))),
      );

  List<ConceptEngineSessionRecord> get _filteredRecent {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _recent.where((e) {
      if (_providerFilter != 'all' && e.provider != _providerFilter) return false;
      if (query.isEmpty) return true;
      final hay = '${e.concept} ${e.domain} ${e.goal} ${e.sceneTitle} ${e.summary} ${e.model}'.toLowerCase();
      return hay.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = _filteredRecent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('概念实践引擎'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF7F7FB),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSession(),
        icon: const Icon(Icons.play_arrow),
        label: const Text('开始新练习'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.extension_outlined, color: cs.primary),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '把抽象概念练成现实能力',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '输入概念 → 生成直观解释 → 进入虚拟情境 → 多轮互动挑战 → 获得评分与复盘。\n\n本模块支持在设置页中选择 DeepSeek、OpenAI、OpenRouter 或 Eden AI，并统一读取对应密钥与模型配置。',
                    style: TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  if (_runtimeConfig != null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _providerChip(_runtimeConfig!.providerLabel, _runtimeConfig!.provider),
                        _metaChip(_runtimeConfig!.model),
                        _metaChip(_runtimeConfig!.transportMode == ConceptEngineService.transportProxy ? '后端网关代理' : '客户端直连'),
                        _metaChip('场景 ${_runtimeConfig!.sceneCount}'),
                        _metaChip('目标轮次 ${_runtimeConfig!.turnTarget}'),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _openActionEngine,
                        icon: const Icon(Icons.account_tree_outlined),
                        label: const Text('进入概念行动引擎'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openSession(),
                        icon: const Icon(Icons.bolt),
                        label: const Text('开始普通练习（旧模式）'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openTrainingHub,
                        icon: const Icon(Icons.fitness_center_outlined),
                        label: const Text('进入训练舱模式'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openWorldHall,
                        icon: const Icon(Icons.travel_explore_outlined),
                        label: const Text('查看世界成长'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrainingGrowthArchivePage())).then((_) => _load()),
                        icon: const Icon(Icons.insights_outlined),
                        label: const Text('训练成长档案'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '推荐优先体验新的概念行动引擎：概念 → 行动树 → 行动拆解 → 行动链 → 执行 → 反馈。正常情况下可直接顺畅推进，只有真的卡住时才进入异常处理。',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280), height: 1.45),
                  ),
                  if (_worldProfile != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('世界进度', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text('等级 Lv.${_worldProfile!.level} · 经验 ${_worldProfile!.totalXp} · 连胜 ${_worldProfile!.streak}'),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: _worldProfile!.xpIntoCurrentLevel / 100,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '成就 ${_worldProfile!.achievements.length} 枚 · 总闯关 ${_worldProfile!.totalRuns} 次 · 世界异常 ${_worldMapData?.totalAnomalyLevel ?? 0}',
                            style: const TextStyle(color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('练习记录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: '搜索概念、目标、场景、模型',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('全部提供商'),
                          selected: _providerFilter == 'all',
                          onSelected: (_) => setState(() => _providerFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('DeepSeek'),
                          selected: _providerFilter == 'deepseek',
                          onSelected: (_) => setState(() => _providerFilter = 'deepseek'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('OpenAI'),
                          selected: _providerFilter == 'openai',
                          onSelected: (_) => setState(() => _providerFilter = 'openai'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('OpenRouter'),
                          selected: _providerFilter == 'openrouter',
                          onSelected: (_) => setState(() => _providerFilter = 'openrouter'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Eden AI'),
                          selected: _providerFilter == 'edenai',
                          onSelected: (_) => setState(() => _providerFilter = 'edenai'),
                        ),
                        const SizedBox(width: 12),
                        Text('共 ${list.length} 条', style: const TextStyle(color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (list.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text('当前筛选条件下还没有练习记录。'),
              )
            else
              ...list.map((e) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Color(0x11000000), blurRadius: 14, offset: Offset(0, 4)),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    title: Row(
                      children: [
                        Expanded(child: Text(e.concept, style: const TextStyle(fontWeight: FontWeight.w700))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: e.provider == 'openai' ? const Color(0xFFCCFBF1) : const Color(0xFFE0E7FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(e.providerLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${e.domain.isEmpty ? '未分类' : e.domain} · ${e.sceneTitle}\n${e.resultLabel} · ${e.totalScore}分 · ${e.model.isEmpty ? '未记录模型' : e.model}\n${e.summary}',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Wrap(
                      spacing: 0,
                      children: [
                        IconButton(
                          tooltip: '按原主题再练一次',
                          onPressed: () => _openSession(fromRecord: e),
                          icon: const Icon(Icons.refresh),
                        ),
                        IconButton(
                          tooltip: '查看详情',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ConceptEngineDetailPage(record: e)),
                            );
                          },
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ConceptEngineDetailPage(record: e)),
                      );
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
