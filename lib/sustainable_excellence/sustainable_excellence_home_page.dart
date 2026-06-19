import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../realistic_optimism_module/realistic_optimism_home_page.dart';
import '../pages/ai_prompt_settings_page.dart';

import 'sustainable_excellence_ai_service.dart';
import 'sustainable_excellence_dao.dart';
import 'sustainable_excellence_models.dart';
import 'sustainable_excellence_prompt_config.dart';
import 'sustainable_excellence_pages.dart';
import 'sustainable_excellence_todo_bridge.dart';

class SustainableExcellenceHomePage extends StatefulWidget {
  final String initialInput;
  final String source;
  final String extraContext;

  const SustainableExcellenceHomePage({
    super.key,
    this.initialInput = '',
    this.source = 'manual',
    this.extraContext = '',
  });

  @override
  State<SustainableExcellenceHomePage> createState() => _SustainableExcellenceHomePageState();
}

class _SustainableExcellenceHomePageState extends State<SustainableExcellenceHomePage> {
  final SustainableExcellenceDao _dao = SustainableExcellenceDao();
  final SustainableExcellenceAiService _ai = SustainableExcellenceAiService();
  final SustainableExcellenceTodoBridge _todoBridge = SustainableExcellenceTodoBridge();
  final TextEditingController _goalCtrl = TextEditingController();
  final TextEditingController _stateCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _generating = false;
  bool _autoTodoHandled = false;
  bool _showArchived = false;
  List<SustainableExcellenceCase> _cases = <SustainableExcellenceCase>[];
  Map<String, int> _counts = const <String, int>{};
  Map<String, String> _aiState = const <String, String>{'label': '读取中…'};

  @override
  void initState() {
    super.initState();
    _goalCtrl.text = widget.initialInput;
    _searchCtrl.addListener(() { if (mounted) setState(() {}); });
    _load().then((_) => _maybeOpenOrCreateFromTodo());
  }

  @override
  void dispose() {
    _goalCtrl.dispose();
    _stateCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cases = await _dao.loadCases(includeArchived: _showArchived);
    final counts = await _dao.counts();
    final aiState = await _ai.getGlobalAiState();
    if (!mounted) return;
    setState(() {
      _cases = cases;
      _counts = counts;
      _aiState = aiState;
      _loading = false;
    });
  }

  String _contextValue(String key) {
    final raw = widget.extraContext.trim();
    if (raw.startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return (decoded[key] ?? '').toString().trim();
      } catch (_) {}
    }
    final match = RegExp(r'(?:^|[;\n])\s*' + RegExp.escape(key) + r'=([^;\n]*)').firstMatch(widget.extraContext);
    return match == null ? '' : (match.group(1) ?? '').trim();
  }

  Future<void> _maybeOpenOrCreateFromTodo() async {
    if (_autoTodoHandled || widget.source != 'todo') return;
    final sourceTodoId = _contextValue('source_todo_id');
    if (sourceTodoId.isEmpty) return;
    _autoTodoHandled = true;
    final existing = await _dao.findCaseBySourceTodo(sourceTodoId);
    if (!mounted) return;
    if (existing != null) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SustainableExcellenceCaseDetailPage(item: existing)));
      await _load();
      return;
    }
    setState(() => _generating = true);
    try {
      final seed = await _todoBridge.buildCaseSeedFromTodo(sourceTodoId);
      final result = await _ai.generateCase(
        userGoal: seed?.userGoal ?? widget.initialInput,
        userState: seed?.currentStateSummary ?? _contextValue('body'),
        source: 'todo',
        extraContext: widget.extraContext,
      );
      final item = result.fromFallback && seed != null
          ? seed.copyWith(provider: result.provider, modelLabel: result.modelLabel)
          : result.item;
      await _dao.saveCase(item);
      await _todoBridge.updateSourceTodoLinked(item);
      await _load();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SustainableExcellenceCaseDetailPage(item: item)));
      await _load();
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _generate() async {
    final goal = _goalCtrl.text.trim();
    if (goal.isEmpty) {
      _toast('请先写下一个目标、Todo、失败、拖延或完美主义困扰。');
      return;
    }
    setState(() => _generating = true);
    try {
      final result = await _ai.generateCase(
        userGoal: goal,
        userState: _stateCtrl.text.trim(),
        source: widget.source,
        extraContext: widget.extraContext,
      );
      await _dao.saveCase(result.item);
      if (widget.source == 'todo') { await _todoBridge.updateSourceTodoLinked(result.item); }
      await _load();
      if (!mounted) return;
      _goalCtrl.clear();
      _stateCtrl.clear();
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SustainableExcellenceCaseDetailPage(item: result.item)));
      await _load();
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空可持续卓越模块数据？'),
        content: const Text('将删除所有目标实验、行动证据、失败学习、恢复记录和过程记录。该操作不可恢复。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok == true) {
      await _dao.clearAll();
      await _load();
      _toast('已清空');
    }
  }

  Future<void> _showPromptSheet() async {
    final prompts = SustainableExcellencePromptConfig();
    final global = await prompts.getPrompt(SustainableExcellencePromptConfig.globalId);
    final goal = await prompts.getPrompt(SustainableExcellencePromptConfig.goalToExperimentId);
    final output = await prompts.getPrompt(SustainableExcellencePromptConfig.outputCommonId);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.45,
        maxChildSize: 0.96,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: <Widget>[
            const Text('AI 三层 Prompt（当前生效）', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            _PromptBlock(title: '全局价值层', body: global),
            _PromptBlock(title: '场景层：目标/Todo 转卓越实验', body: goal),
            _PromptBlock(title: '输出格式层', body: output),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleArchived() async {
    setState(() { _showArchived = !_showArchived; _loading = true; });
    await _load();
  }

  Future<void> _exportAll() async {
    final archive = jsonDecode(await _dao.exportFullArchiveJson());
    final prompts = jsonDecode(await SustainableExcellencePromptConfig().exportPromptsJson());
    if (archive is Map && prompts is Map) {
      archive['prompt_config'] = prompts['prompts'] ?? <String, dynamic>{};
    }
    await Clipboard.setData(ClipboardData(text: jsonEncode(archive)));
    _toast('已复制完整可持续卓越成长档案 JSON（实验 + 复盘 + 自定义 Prompt）。');
  }

  Future<void> _importAllFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = (data?.text ?? '').trim();
    if (raw.isEmpty) {
      _toast('剪贴板为空，无法导入。');
      return;
    }
    final result = await _dao.importFullArchiveJson(raw);
    var promptCount = 0;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['prompt_config'] is Map) {
        promptCount = await SustainableExcellencePromptConfig().importPromptsJson(jsonEncode(<String, dynamic>{'prompts': decoded['prompt_config']}));
      }
    } catch (_) {}
    final cases = result['cases'] ?? 0;
    final reviews = result['reviews'] ?? 0;
    if (cases <= 0 && reviews <= 0 && promptCount <= 0) {
      _toast('未识别到可持续卓越实验/复盘/Prompt JSON。');
      return;
    }
    await _load();
    _toast('已导入/合并 $cases 个实验、$reviews 份复盘、$promptCount 个 Prompt。');
  }

  bool _caseMatches(SustainableExcellenceCase item, String query) {
    if (query.trim().isEmpty) return true;
    final q = query.trim().toLowerCase();
    final logText = item.logs.map((l) => '${l.title} ${l.note}').join(' ');
    final text = '${item.title} ${item.userGoal} ${item.currentStateSummary} ${item.coachMessage} $logText'.toLowerCase();
    return text.contains(q);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final aiLabel = _aiState['label'] ?? '未配置（将使用内置策略）';
    final q = _searchCtrl.text.trim().toLowerCase();
    final visibleCases = _cases.where((e) => _caseMatches(e, q)).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: const Text('可持续卓越实验室'),
        backgroundColor: const Color(0xFFF7F7FB),
        actions: <Widget>[
          IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiPromptSettingsPage(initialModuleId: 'sustainable_excellence', initialPromptId: 'se_global'))), icon: const Icon(Icons.integration_instructions_outlined), tooltip: 'AI Prompt 配置中心'),
          IconButton(onPressed: _toggleArchived, icon: Icon(_showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined), tooltip: _showArchived ? '隐藏归档' : '查看归档'),
          IconButton(onPressed: _exportAll, icon: const Icon(Icons.ios_share_outlined), tooltip: '导出档案'),
          IconButton(onPressed: _importAllFromClipboard, icon: const Icon(Icons.upload_file_outlined), tooltip: '从剪贴板导入档案'),
          IconButton(onPressed: _clearAll, icon: const Icon(Icons.delete_sweep_outlined), tooltip: '清空数据'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: <Widget>[
                  _HeroCard(aiLabel: aiLabel),
                  const SizedBox(height: 12),
                  _StatsGrid(counts: _counts),
                  const SizedBox(height: 12),
                  _HomeActionGrid(
                    onDailyReview: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SustainableReviewPage())).then((_) => _load()),
                    onWeeklyReview: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SustainableReviewPage(reviewType: 'weekly'))).then((_) => _load()),
                  ),
                  const SizedBox(height: 12),
                  _InputCard(
                    goalCtrl: _goalCtrl,
                    stateCtrl: _stateCtrl,
                    generating: _generating,
                    onGenerate: _generate,
                  ),
                  const SizedBox(height: 12),
                  const _PrinciplesCard(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: _showArchived ? '搜索全部/归档实验' : '搜索当前实验',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const <Widget>[
                      Icon(Icons.timeline_outlined, size: 20, color: Color(0xFF4338CA)),
                      SizedBox(width: 6),
                      Text('最近的卓越实验', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (visibleCases.isEmpty)
                    const _EmptyCard()
                  else
                    for (final item in visibleCases)
                      _CaseListTile(
                        item: item,
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SustainableExcellenceCaseDetailPage(item: item)));
                          await _load();
                        },
                      ),
                ],
              ),
            ),
    );
  }
}

class SustainableExcellenceCaseDetailPage extends StatefulWidget {
  final SustainableExcellenceCase item;
  const SustainableExcellenceCaseDetailPage({super.key, required this.item});

  @override
  State<SustainableExcellenceCaseDetailPage> createState() => _SustainableExcellenceCaseDetailPageState();
}

class _SustainableExcellenceCaseDetailPageState extends State<SustainableExcellenceCaseDetailPage> {
  final SustainableExcellenceDao _dao = SustainableExcellenceDao();
  final SustainableExcellenceTodoBridge _todoBridge = SustainableExcellenceTodoBridge();
  late SustainableExcellenceCase _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  Future<void> _reload() async {
    final items = await _dao.loadCases(includeArchived: true);
    SustainableExcellenceCase latest = _item;
    for (final candidate in items) {
      if (candidate.id == _item.id) {
        latest = candidate;
        break;
      }
    }
    if (!mounted) return;
    setState(() => _item = latest);
  }

  Future<void> _selectExperiment(SustainableActionExperiment exp) async {
    await _dao.selectExperiment(_item.id, exp.type);
    await _reload();
    _toast('已选择：${exp.title}');
  }



  Future<void> _runExperiment(SustainableActionExperiment exp) async {
    await _dao.selectExperiment(_item.id, exp.type);
    await _todoBridge.markSourceTodoStage(_item, '已选择行动实验：${exp.title}');
    await _reload();
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => SustainableExperimentRunnerPage(item: _item, experiment: exp)));
    if (changed == true) await _reload();
  }

  Future<void> _writeNextTodo() async {
    try {
      final id = await _todoBridge.writeCaseNextTodo(_item);
      await _reload();
      _toast('已写回 Todo：$id');
    } catch (e) {
      _toast('写回 Todo 失败：$e');
    }
  }

  Future<void> _writeExperimentTodo(SustainableActionExperiment exp) async {
    try {
      final id = await _todoBridge.writeExperimentTodo(_item, exp);
      await _reload();
      _toast('已创建行动 Todo：$id');
    } catch (e) {
      _toast('创建 Todo 失败：$e');
    }
  }

  Future<void> _archive() async {
    await _dao.archiveCase(_item.id);
    await _todoBridge.markSourceTodoStage(_item, '已归档可持续卓越实验');
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _restore() async {
    await _dao.restoreCase(_item.id);
    await _todoBridge.markSourceTodoStage(_item, '已恢复可持续卓越实验');
    await _reload();
    _toast('已恢复归档实验');
  }

  Future<void> _exportCase() async {
    await Clipboard.setData(ClipboardData(text: sustainableCasesToString(<SustainableExcellenceCase>[_item])));
    _toast('已复制当前实验 JSON');
  }

  Future<void> _deleteCase() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这个卓越实验？'),
        content: const Text('会删除该实验及其成长证据记录。该操作不可恢复。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await _dao.deleteCase(_item.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _record(String type) async {
    final noteCtrl = TextEditingController();
    final detailCtrl = TextEditingController();
    final labels = _logLabels(type);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(labels.$1),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(labels.$2, style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(labelText: labels.$3, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detailCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: labels.$4, border: const OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存证据')),
        ],
      ),
    );
    final note = noteCtrl.text.trim();
    final detail = detailCtrl.text.trim();
    noteCtrl.dispose();
    detailCtrl.dispose();
    if (ok == true) {
      final selected = _item.selectedExperimentType.trim().isEmpty
          ? (_item.actionExperiments.isEmpty ? '' : _item.actionExperiments.first.type)
          : _item.selectedExperimentType;
      final log = SustainableEvidenceLog(
        id: 'selog_${DateTime.now().microsecondsSinceEpoch}',
        caseId: _item.id,
        experimentType: selected,
        type: type,
        title: labels.$1,
        note: note.isEmpty ? labels.$5 : note,
        details: detail.isEmpty ? <String>[] : detail.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await _dao.addLog(_item.id, log);
      await _todoBridge.markSourceTodoStage(_item, '新增成长证据：${labels.$1}');
      await _reload();
      _toast('已保存成长证据');
    }
  }



  Future<void> _deleteLog(SustainableEvidenceLog log) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条成长证据？'),
        content: Text(log.title),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await _dao.deleteLog(_item.id, log.id);
      await _reload();
      _toast('已删除证据');
    }
  }

  (String, String, String, String, String) _logLabels(String type) {
    switch (type) {
      case 'failure_learning':
        return ('记录失败学习', '失败不是自我判决，而是行动系统的反馈。', '实际发生了什么？', '我学到的一个可改变变量', '这次失败暴露了一个可以调整的变量。');
      case 'recovery':
        return ('记录恢复', '恢复不是懒惰，而是长期卓越的一部分。', '我做了什么恢复？', '恢复后状态有什么变化？', '我为下一轮行动补充了恢复。');
      case 'process':
        return ('记录过程体验', '不强迫快乐，只寻找 1% 的意义、掌控或能力感。', '过程中哪一刻值得看见？', '它连接到什么长期价值？', '我看见了过程中的一个积极证据。');
      case 'restart':
        return ('记录重新开始', '卓越不是无错直线，而是可以重新进入螺旋。', '我从哪里重新开始？', '这次我要缩小或改变什么？', '我完成了一次重新开始。');
      default:
        return ('记录行动证据', '完成、尝试、部分完成都算行动证据。', '我实际做了什么？', '哪个条件帮助我行动？', '我积累了一条行动证据。');
    }
  }

  bool _caseMatches(SustainableExcellenceCase item, String query) {
    if (query.trim().isEmpty) return true;
    final q = query.trim().toLowerCase();
    final logText = item.logs.map((l) => '${l.title} ${l.note}').join(' ');
    final text = '${item.title} ${item.userGoal} ${item.currentStateSummary} ${item.coachMessage} $logText'.toLowerCase();
    return text.contains(q);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showJson() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AiPromptSettingsPage(
          initialModuleId: 'sustainable_excellence',
          initialPromptId: 'se_output_common',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedType = _item.selectedExperimentType;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: const Text('卓越实验详情'),
        backgroundColor: const Color(0xFFF7F7FB),
        actions: <Widget>[
          IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SustainablePerfectionismTrainingPage(item: _item))).then((_) => _reload()), icon: const Icon(Icons.balance_outlined), tooltip: '完美主义训练'),
          IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SustainableProcessTrainingPage(item: _item))).then((_) => _reload()), icon: const Icon(Icons.spa_outlined), tooltip: '过程享受训练'),
          IconButton(onPressed: _showJson, icon: const Icon(Icons.data_object_outlined), tooltip: '输出格式 Prompt 配置'),
          PopupMenuButton<String>(
            onSelected: (v) { if (v == 'archive') _archive(); if (v == 'restore') _restore(); if (v == 'export') _exportCase(); if (v == 'delete') _deleteCase(); },
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              if (_item.isArchived) const PopupMenuItem(value: 'restore', child: Text('恢复归档')) else const PopupMenuItem(value: 'archive', child: Text('归档实验')),
              const PopupMenuItem(value: 'export', child: Text('导出当前实验')),
              const PopupMenuItem(value: 'delete', child: Text('删除实验')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          _DetailHero(item: _item),
          const SizedBox(height: 12),
          const _LectureSourceCard(),
          const SizedBox(height: 12),
          _QuickRecordBar(onRecord: _record),
          const SizedBox(height: 12),
          _SpiralStageCard(item: _item),
          const SizedBox(height: 12),
          _DetailToolBar(
            onWriteTodo: _writeNextTodo,
            onPerfectionism: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SustainablePerfectionismTrainingPage(item: _item))).then((_) => _reload()),
            onProcess: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SustainableProcessTrainingPage(item: _item))).then((_) => _reload()),
            onOptimism: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RealisticOptimismHomePage(initialInput: _item.userGoal, source: 'sustainable_excellence', extraContext: 'from_case=${_item.id}; mode=${_item.spiralStage}'))),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '当前模式识别',
            icon: Icons.radar_outlined,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _StatusPill(label: '压力', value: _item.modeDetection.pressureLevel),
                _StatusPill(label: '恢复', value: _item.modeDetection.recoveryLevel),
                _StatusPill(label: '完美主义', value: _item.modeDetection.perfectionismLevel),
                _StatusPill(label: '失败恐惧', value: _item.modeDetection.failureFearLevel),
                _StatusPill(label: '过程连接', value: _item.modeDetection.processConnectionLevel),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '价值重构：保留什么，调整什么',
            icon: Icons.balance_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MiniTitle('需要保留'),
                _BulletList(_item.valueMapping.preserve),
                const SizedBox(height: 8),
                _MiniTitle('需要调整'),
                _BulletList(_item.valueMapping.adjust),
                const Divider(height: 20),
                Text(_item.valueMapping.coreReframe, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.45, color: Color(0xFF4338CA))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '阻碍分析：把模糊痛苦变成可改变量',
            icon: Icons.psychology_alt_outlined,
            child: Column(children: _item.obstacleAnalysis.map((e) => _ObstacleTile(item: e)).toList()),
          ),
          const SizedBox(height: 12),
          Row(
            children: const <Widget>[
              Icon(Icons.science_outlined, color: Color(0xFF4338CA)),
              SizedBox(width: 6),
              Expanded(child: Text('三个可选行动实验', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 8),
          for (final exp in _item.actionExperiments)
            _ExperimentCard(
              exp: exp,
              selected: selectedType == exp.type,
              onSelect: () => _selectExperiment(exp),
              onRun: () => _runExperiment(exp),
              onWriteTodo: () => _writeExperimentTodo(exp),
            ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '压力—恢复节律',
            icon: Icons.self_improvement_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _InfoLine(label: '推荐节律', text: _item.recoveryPlan.recommendedRhythm),
                const SizedBox(height: 8),
                _MiniTitle('微恢复'),
                _BulletList(_item.recoveryPlan.microRecovery),
                const SizedBox(height: 8),
                _MiniTitle('中恢复'),
                _BulletList(_item.recoveryPlan.mediumRecovery),
                const SizedBox(height: 8),
                _MiniTitle('深恢复'),
                _BulletList(_item.recoveryPlan.deepRecovery),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '失败学习预案',
            icon: Icons.replay_circle_filled_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _InfoLine(label: '可能失败类型', text: _item.failureLearning.possibleFailureType),
                _InfoLine(label: '如果失败', text: _item.failureLearning.ifFailedThen),
                _InfoLine(label: '学习问题', text: _item.failureLearning.learningQuestion),
                _InfoLine(label: '下一轮更小实验', text: _item.failureLearning.nextSmallerExperiment),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '享受过程：寻找 1% 的体验',
            icon: Icons.spa_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _InfoLine(label: '意义连接', text: _item.processEnjoyment.meaningConnection),
                _InfoLine(label: '1% 体验', text: _item.processEnjoyment.onePercentExperience),
                _InfoLine(label: '行动中提醒', text: _item.processEnjoyment.duringActionReminder),
                _InfoLine(label: '行动后复盘', text: _item.processEnjoyment.afterActionReflection),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Todo 写回建议',
            icon: Icons.assignment_turned_in_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _InfoLine(label: '下一步', text: _item.todoWriteback.nextTodoTitle),
                _BulletList(_item.todoWriteback.nextTodoSteps),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: _item.todoWriteback.evidenceTags.map((e) => _ChipText(e)).toList()),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _writeNextTodo, icon: const Icon(Icons.add_task_outlined), label: Text(_item.linkedTodoTaskId.isEmpty ? '真正写回 Todo' : '再次生成下一步 Todo'))),
                if (_item.linkedTodoTaskId.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('已关联 Todo：${_item.linkedTodoTaskId}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '成长证据时间线',
            icon: Icons.history_edu_outlined,
            child: _item.logs.isEmpty
                ? const Text('还没有证据。完成一次行动、失败学习、恢复或过程记录后，这里会形成你的卓越螺旋。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45))
                : Column(children: _item.logs.map((e) => _LogTile(log: e, onDelete: () => _deleteLog(e))).toList()),
          ),
        ],
      ),
    );
  }
}



class _LectureSourceCard extends StatelessWidget {
  const _LectureSourceCard();
  @override
  Widget build(BuildContext context) => _SectionCard(
        title: '理论来源：哈佛积极心理 Lecture 14–16',
        icon: Icons.school_outlined,
        child: const _BulletList(<String>[
          'Lecture 14：压力不是敌人，缺乏恢复才是问题；失败必须被转化为学习。',
          'Lecture 15：完美主义不是高标准，而是对失败的僵硬恐惧；卓越允许反馈和修正。',
          'Lecture 16：目标重要，但不能把幸福全部推迟到终点；要在有意义的过程中寻找 1% 的体验。',
        ]),
      );
}

class _HomeActionGrid extends StatelessWidget {
  final VoidCallback onDailyReview;
  final VoidCallback onWeeklyReview;
  const _HomeActionGrid({required this.onDailyReview, required this.onWeeklyReview});

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Expanded(child: _HomeActionButton(icon: Icons.today_outlined, title: '每日复盘', subtitle: '行动/失败/恢复/过程', onTap: onDailyReview)),
          const SizedBox(width: 8),
          Expanded(child: _HomeActionButton(icon: Icons.summarize_outlined, title: '周度报告', subtitle: '重复模式与下周变量', onTap: onWeeklyReview)),
        ],
      );
}

class _HomeActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _HomeActionButton({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Row(children: <Widget>[
            Icon(icon, color: const Color(0xFF4338CA)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ])),
          ]),
        ),
      );
}

class _SpiralStageCard extends StatelessWidget {
  final SustainableExcellenceCase item;
  const _SpiralStageCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final labels = <String>['目标', '实验', '行动', '失败/卡住', '恢复', '反馈', '修正', '再行动'];
    final active = SustainableSpiralStage.label(item.spiralStage);
    return _SectionCard(
      title: '卓越螺旋状态机',
      icon: Icons.all_inclusive,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Wrap(spacing: 6, runSpacing: 6, children: labels.map((e) => _ChipText(e == active ? '● $e' : e)).toList()),
        const SizedBox(height: 10),
        _InfoLine(label: '当前阶段', text: active),
        _InfoLine(label: '下一阶段', text: SustainableSpiralStage.label(item.nextRecommendedStage)),
        _InfoLine(label: '完成轮次', text: '${item.spiralCycleCount} 轮'),
      ]),
    );
  }
}

class _DetailToolBar extends StatelessWidget {
  final VoidCallback onWriteTodo;
  final VoidCallback onPerfectionism;
  final VoidCallback onProcess;
  final VoidCallback onOptimism;
  const _DetailToolBar({required this.onWriteTodo, required this.onPerfectionism, required this.onProcess, required this.onOptimism});
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _ActionChipButton(icon: Icons.add_task_outlined, label: '写回 Todo', onTap: onWriteTodo),
          _ActionChipButton(icon: Icons.balance_outlined, label: '完美主义训练', onTap: onPerfectionism),
          _ActionChipButton(icon: Icons.spa_outlined, label: '过程享受训练', onTap: onProcess),
          _ActionChipButton(icon: Icons.psychology_alt_outlined, label: '现实乐观联动', onTap: onOptimism),
        ],
      );
}

class _HeroCard extends StatelessWidget {
  final String aiLabel;
  const _HeroCard({required this.aiLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: <Color>[Color(0xFF312E81), Color(0xFF4338CA), Color(0xFF0EA5E9)]),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x334338CA), blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.all_inclusive, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('可持续卓越实验室', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 12),
          const Text('把目标转化为实验，把失败转化为学习，把压力转化为节律，把过程重新连接到意义。', style: TextStyle(color: Colors.white, fontSize: 14.5, height: 1.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <Widget>[
              _HeroPill('压力需要恢复'),
              _HeroPill('失败是数据'),
              _HeroPill('卓越不是完美'),
              _HeroPill('享受过程'),
            ],
          ),
          const SizedBox(height: 10),
          Text('AI：$aiLabel', style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 12)),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String text;
  const _HeroPill(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white.withOpacity(0.18))),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
      );
}

class _StatsGrid extends StatelessWidget {
  final Map<String, int> counts;
  const _StatsGrid({required this.counts});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: _StatCard(label: '目标实验', value: counts['cases'] ?? 0, icon: Icons.flag_outlined)),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(label: '行动证据', value: counts['action'] ?? 0, icon: Icons.directions_run_outlined)),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(label: '失败学习', value: counts['failure_learning'] ?? 0, icon: Icons.replay_outlined)),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(label: '恢复记录', value: counts['recovery'] ?? 0, icon: Icons.self_improvement_outlined)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x11000000), blurRadius: 14, offset: Offset(0, 6))]),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 18, color: const Color(0xFF4338CA)),
            const SizedBox(height: 4),
            Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          ],
        ),
      );
}

class _InputCard extends StatelessWidget {
  final TextEditingController goalCtrl;
  final TextEditingController stateCtrl;
  final bool generating;
  final VoidCallback onGenerate;
  const _InputCard({required this.goalCtrl, required this.stateCtrl, required this.generating, required this.onGenerate});

  @override
  Widget build(BuildContext context) => _SectionCard(
        title: '把一个目标/Todo 转成卓越实验',
        icon: Icons.auto_fix_high_outlined,
        child: Column(
          children: <Widget>[
            TextField(
              controller: goalCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '目标 / Todo / 困扰',
                hintText: '例如：我想找工作，但一直拖延；我想完成项目，但害怕不完美。',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: stateCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '当前状态（可选）',
                hintText: '例如：最近压力大、睡眠差、怕失败、反复准备、只盯结果。',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: generating ? null : onGenerate,
                icon: generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.science_outlined),
                label: Text(generating ? '正在生成卓越实验…' : '生成可持续卓越实验'),
              ),
            ),
          ],
        ),
      );
}

class _PrinciplesCard extends StatelessWidget {
  const _PrinciplesCard();

  @override
  Widget build(BuildContext context) => _SectionCard(
        title: '模块核心价值体系',
        icon: Icons.hub_outlined,
        child: Column(
          children: const <Widget>[
            _PrincipleLine(title: '压力—恢复', text: '压力不是敌人，缺乏恢复才是敌人。'),
            _PrincipleLine(title: '失败—学习', text: '失败不是成功的反面，而是学习的组成。'),
            _PrincipleLine(title: '卓越—非完美主义', text: '保留高标准，放下自我审判和无错幻想。'),
            _PrincipleLine(title: '目标—过程', text: '目标重要，但幸福和意义不能全部推迟到终点。'),
          ],
        ),
      );
}

class _PrincipleLine extends StatelessWidget {
  final String title;
  final String text;
  const _PrincipleLine({required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(width: 7, height: 7, margin: const EdgeInsets.only(top: 7), decoration: const BoxDecoration(color: Color(0xFF4338CA), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text('$title：$text', style: const TextStyle(height: 1.4))),
          ],
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Text('还没有实验。先输入一个目标或 Todo，把它转化为可执行、可失败、可恢复、可复盘的卓越螺旋。', style: TextStyle(color: Color(0xFF6B7280), height: 1.5)),
      );
}

class _CaseListTile extends StatelessWidget {
  final SustainableExcellenceCase item;
  final VoidCallback onTap;
  const _CaseListTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.all_inclusive, color: Color(0xFF4338CA)),
          ),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(item.currentStateSummary, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('${item.logs.length}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4338CA))),
              const Text('证据', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ],
          ),
        ),
      );
}

class _DetailHero extends StatelessWidget {
  final SustainableExcellenceCase item;
  const _DetailHero({required this.item});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, height: 1.25)),
            const SizedBox(height: 10),
            Text(item.currentStateSummary, style: TextStyle(color: Colors.white.withOpacity(0.86), height: 1.5)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
              child: Text(item.coachMessage.isEmpty ? '先选一个实验，配一个恢复，失败也要留下学习证据。' : item.coachMessage, style: const TextStyle(color: Colors.white, height: 1.5, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
            Text('阶段：${SustainableSpiralStage.label(item.spiralStage)} · 下一步：${SustainableSpiralStage.label(item.nextRecommendedStage)} · 模型：${item.modelLabel}', style: TextStyle(color: Colors.white.withOpacity(0.62), fontSize: 12)),
          ],
        ),
      );
}

class _QuickRecordBar extends StatelessWidget {
  final Future<void> Function(String type) onRecord;
  const _QuickRecordBar({required this.onRecord});
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _ActionChipButton(icon: Icons.directions_run_outlined, label: '行动证据', onTap: () => onRecord('action')),
          _ActionChipButton(icon: Icons.replay_outlined, label: '失败学习', onTap: () => onRecord('failure_learning')),
          _ActionChipButton(icon: Icons.self_improvement_outlined, label: '恢复', onTap: () => onRecord('recovery')),
          _ActionChipButton(icon: Icons.spa_outlined, label: '过程体验', onTap: () => onRecord('process')),
          _ActionChipButton(icon: Icons.restart_alt_outlined, label: '重新开始', onTap: () => onRecord('restart')),
        ],
      );
}

class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionChipButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(icon, size: 18, color: const Color(0xFF4338CA)),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        onPressed: onTap,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x0D000000), blurRadius: 18, offset: Offset(0, 8))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(children: <Widget>[Icon(icon, color: const Color(0xFF4338CA)), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)))]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _StatusPill extends StatelessWidget {
  final String label;
  final String value;
  const _StatusPill({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
        child: Text('$label：$value', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
      );
}

class _MiniTitle extends StatelessWidget {
  final String text;
  const _MiniTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF111827)));
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  const _BulletList(this.items);
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('暂无', style: TextStyle(color: Color(0xFF9CA3AF)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((e) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('• ', style: TextStyle(color: Color(0xFF4338CA), fontWeight: FontWeight.w900)),
            Expanded(child: Text(e, style: const TextStyle(height: 1.42))),
          ],
        ),
      )).toList(),
    );
  }
}

class _ObstacleTile extends StatelessWidget {
  final SustainableObstacleAnalysis item;
  const _ObstacleTile({required this.item});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(item.obstacle, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(item.evidence, style: const TextStyle(color: Color(0xFF6B7280), height: 1.4)),
          const SizedBox(height: 6),
          Text('可改变量：${item.changeableVariable}', style: const TextStyle(color: Color(0xFF4338CA), fontWeight: FontWeight.w800, height: 1.4)),
        ]),
      );
}

class _ExperimentCard extends StatelessWidget {
  final SustainableActionExperiment exp;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onRun;
  final VoidCallback onWriteTodo;
  const _ExperimentCard({required this.exp, required this.selected, required this.onSelect, required this.onRun, required this.onWriteTodo});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF4338CA) : const Color(0xFFE5E7EB), width: selected ? 1.5 : 1),
          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x0D000000), blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(exp.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
              if (selected) const Icon(Icons.check_circle, color: Color(0xFF4338CA)),
            ],
          ),
          const SizedBox(height: 6),
          Text(exp.suitableWhen, style: const TextStyle(color: Color(0xFF6B7280), height: 1.4)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: <Widget>[_ChipText(exp.timeRequired), _ChipText(exp.type)]),
          const SizedBox(height: 10),
          _MiniTitle('行动步骤'),
          _BulletList(exp.steps),
          const SizedBox(height: 8),
          _InfoLine(label: '可能失败点', text: exp.failurePoint),
          _InfoLine(label: '失败学习', text: exp.failureLearningMethod),
          _InfoLine(label: '行动前恢复', text: exp.recoveryBefore),
          _InfoLine(label: '行动后恢复', text: exp.recoveryAfter),
          _InfoLine(label: '过程锚点', text: exp.processAnchor),
          const SizedBox(height: 10),
          Row(children: <Widget>[
            Expanded(child: OutlinedButton.icon(onPressed: onSelect, icon: const Icon(Icons.touch_app_outlined), label: Text(selected ? '已选择' : '选择'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(onPressed: onRun, icon: const Icon(Icons.play_arrow_outlined), label: const Text('开始行动'))),
          ]),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: TextButton.icon(onPressed: onWriteTodo, icon: const Icon(Icons.add_task_outlined), label: const Text('把这个实验写成 Todo'))),
        ]),
      );
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String text;
  const _InfoLine({required this.label, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: Color(0xFF111827), height: 1.45, fontSize: 14),
            children: <TextSpan>[
              TextSpan(text: '$label：', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4338CA))),
              TextSpan(text: text.isEmpty ? '暂无' : text),
            ],
          ),
        ),
      );
}

class _ChipText extends StatelessWidget {
  final String text;
  const _ChipText(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 12, fontWeight: FontWeight.w800)),
      );
}

class _LogTile extends StatelessWidget {
  final SustainableEvidenceLog log;
  final VoidCallback onDelete;
  const _LogTile({required this.log, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final time = DateTime.fromMillisecondsSinceEpoch(log.createdAtMs);
    final timeText = '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[Expanded(child: Text(log.title, style: const TextStyle(fontWeight: FontWeight.w900))), Text(timeText, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))), IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 18), tooltip: '删除')]),
        const SizedBox(height: 5),
        Text(log.note, style: const TextStyle(height: 1.45)),
        if (log.details.isNotEmpty) ...<Widget>[const SizedBox(height: 5), _BulletList(log.details)],
      ]),
    );
  }
}

class _PromptBlock extends StatelessWidget {
  final String title;
  final String body;
  const _PromptBlock({required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
            IconButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: body)),
              icon: const Icon(Icons.copy, size: 18),
              tooltip: '复制',
            ),
          ]),
          SelectableText(body, style: const TextStyle(fontSize: 12.5, height: 1.45)),
        ]),
      );
}
