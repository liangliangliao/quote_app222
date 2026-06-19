import 'package:flutter/material.dart';

import 'cognitive_consistency_dao.dart';

class CcSourcebookCaseListPage extends StatefulWidget {
  const CcSourcebookCaseListPage({super.key});

  @override
  State<CcSourcebookCaseListPage> createState() => _CcSourcebookCaseListPageState();
}

class _CcSourcebookCaseListPageState extends State<CcSourcebookCaseListPage> {
  final _dao = CognitiveConsistencyDao();
  late Future<List<Map<String, dynamic>>> _future;
  final _searchCtrl = TextEditingController();
  String _stageFilter = '';
  String _quickFilter = '';

  @override
  void initState() {
    super.initState();
    _future = _dao.allSourcebookCaseDetails(limit: 300);
  }

  void _reload({String stage = ''}) {
    setState(() {
      _stageFilter = stage;
      _future = _dao.allSourcebookCaseDetails(limit: 300, stage: stage);
    });
  }

  static Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
  static List<dynamic> _list(dynamic value) => value is List ? List<dynamic>.from(value) : const <dynamic>[];
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static String _text(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is List) return value.map(_text).where((e) => e.isNotEmpty).join('、');
    if (value is Map) return value.entries.map((e) => '${e.key}：${_text(e.value)}').where((e) => !e.endsWith('：')).join('\n');
    return value.toString().trim();
  }

  List<Map<String, dynamic>> _applyLocalFilters(List<Map<String, dynamic>> cases) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return cases.where((detail) {
      final blob = _text(detail).toLowerCase();
      if (query.isNotEmpty && !blob.contains(query)) return false;
      if (_quickFilter == 'method' && _list(detail['resolutionMethodUsages']).isEmpty) return false;
      if (_quickFilter == 'evidence' && _list(detail['evidence']).isEmpty) return false;
      if (_quickFilter == 'contract' && _map(detail['commitmentContract']).isEmpty) return false;
      return true;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('源书案例档案')),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _filterChip('全部', ''),
              _filterChip('认知地图', 'structure_map'),
              _filterChip('矛盾分流', 'conflict_router'),
              _filterChip('心理功能', 'psychological_function'),
              _filterChip('价值分层', 'value_layering'),
              _filterChip('行动契约', 'action_contract'),
              _filterChip('复盘整合', 'review_integration'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Column(children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: '搜索案例、方法、价值、证据', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(label: const Text('全部'), selected: _quickFilter.isEmpty, onSelected: (_) => setState(() => _quickFilter = '')),
              ChoiceChip(label: const Text('使用过方法'), selected: _quickFilter == 'method', onSelected: (_) => setState(() => _quickFilter = 'method')),
              ChoiceChip(label: const Text('有行动契约'), selected: _quickFilter == 'contract', onSelected: (_) => setState(() => _quickFilter = 'contract')),
              ChoiceChip(label: const Text('有行动证据'), selected: _quickFilter == 'evidence', onSelected: (_) => setState(() => _quickFilter = 'evidence')),
            ]),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              final allCases = snapshot.data ?? const <Map<String, dynamic>>[];
              final cases = _applyLocalFilters(allCases);
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (cases.isEmpty) return const Center(child: Text('暂无符合条件的源书案例。'));
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: cases.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _caseCard(cases[i]),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _filterChip(String label, String stage) {
    final selected = _stageFilter == stage;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => _reload(stage: stage)),
    );
  }

  Widget _caseCard(Map<String, dynamic> detail) {
    final c = _map(detail['case']);
    final nodes = _list(detail['nodes']);
    final edges = _list(detail['edges']);
    final evidence = _list(detail['evidence']);
    final protectedSelf = _list(detail['protectedSelfImage']);
    final defenses = _list(detail['defensePatterns']);
    final methodUsages = _list(detail['resolutionMethodUsages']);
    final stage = _text(c['current_stage']).isEmpty ? 'structure_map' : _text(c['current_stage']);
    final summary = _text(c['event_summary']).isEmpty ? _text(c['session_id']) : _text(c['event_summary']);
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.folder_copy_outlined),
        title: Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('阶段：$stage｜确认：${_text(c['user_confirmation']).isEmpty ? 'pending' : _text(c['user_confirmation'])}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          _nextStep(stage),
          if (nodes.isNotEmpty) _section('认知节点', nodes.take(12).map(_text).where((e) => e.isNotEmpty).toList()),
          if (edges.isNotEmpty) _section('关系边', edges.take(12).map(_text).where((e) => e.isNotEmpty).toList()),
          if (_map(detail['valueLayers']).isNotEmpty) _section('价值分层', [_text(detail['valueLayers'])]),
          if (protectedSelf.isNotEmpty) _section('被保护的自我形象', protectedSelf.map(_text).where((e) => e.isNotEmpty).toList()),
          if (defenses.isNotEmpty) _section('防御/自我辩护模式', defenses.map(_text).where((e) => e.isNotEmpty).toList()),
          if (methodUsages.isNotEmpty) _section('使用过的解决方法', methodUsages.map(_text).where((e) => e.isNotEmpty).toList()),
          if (evidence.isNotEmpty) _section('行动证据', evidence.take(8).map(_text).where((e) => e.isNotEmpty).toList()),
        ],
      ),
    );
  }

  Widget _nextStep(String stage) {
    final next = stage == 'structure_map'
        ? '下一步：矛盾类型分流'
        : stage == 'conflict_router'
            ? '下一步：心理功能分析'
            : stage == 'psychological_function'
                ? '下一步：价值分层'
                : stage == 'value_layering'
                    ? '下一步：选择路径并签行动契约'
                    : stage == 'action_contract'
                        ? '下一步：执行/调整行动契约'
                        : '下一步：归档或生成下一轮实验';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE))),
      child: Text(next, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8))),
    );
  }

  Widget _section(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        ...items.map((e) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $e', style: const TextStyle(height: 1.35)))),
      ]),
    );
  }
}
