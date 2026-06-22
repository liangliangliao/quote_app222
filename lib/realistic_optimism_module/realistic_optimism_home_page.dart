import 'package:flutter/material.dart';

import 'realistic_optimism_ai_service.dart';
import 'realistic_optimism_dao.dart';
import 'realistic_optimism_models.dart';
import 'realistic_optimism_prompt_config.dart';

class RealisticOptimismHomePage extends StatefulWidget {
  final String initialInput;
  final String source;
  final String extraContext;

  const RealisticOptimismHomePage({
    super.key,
    this.initialInput = '',
    this.source = 'manual',
    this.extraContext = '',
  });

  @override
  State<RealisticOptimismHomePage> createState() => _RealisticOptimismHomePageState();
}

class _RealisticOptimismHomePageState extends State<RealisticOptimismHomePage> {
  final RealisticOptimismDao _dao = RealisticOptimismDao();
  final RealisticOptimismAiService _ai = RealisticOptimismAiService();
  final TextEditingController _inputCtrl = TextEditingController();
  bool _loading = true;
  bool _generating = false;
  String? _error;
  List<RealisticOptimismCase> _cases = <RealisticOptimismCase>[];
  List<RealisticOptimismBaselineEntry> _baselines = <RealisticOptimismBaselineEntry>[];
  Map<String, int> _counts = const <String, int>{};

  @override
  void initState() {
    super.initState();
    _inputCtrl.text = widget.initialInput;
    _load();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _dao.ensureTables();
      final cases = await _dao.listCases(limit: 50);
      final baselines = await _dao.listBaselines(limit: 14);
      final counts = await _dao.counts();
      if (!mounted) return;
      setState(() {
        _cases = cases;
        _baselines = baselines;
        _counts = counts;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _generate() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) {
      _toast('请先写下一个目标、失败、拖延、担忧或限制性信念。');
      return;
    }
    setState(() => _generating = true);
    try {
      final result = await _ai.generateCase(
        userInput: input,
        source: widget.source,
        extraContext: widget.extraContext,
      );
      await _dao.upsertCase(result.item);
      await _load();
      if (!mounted) return;
      _inputCtrl.clear();
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RealisticOptimismCaseDetailPage(item: result.item)));
      _load();
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
        title: const Text('清空现实乐观模块数据？'),
        content: const Text('将删除所有信念案例、行动日志、失败复盘和基线记录。该操作不可恢复。'),
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

  Future<void> _recordBaseline() async {
    double mood = 6;
    double esteem = 6;
    double efficacy = 5;
    int cope = 0;
    int avoid = 0;
    bool minAction = false;
    bool review = false;
    bool optimism = false;
    final noteCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('记录今日基线'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _DialogSlider(label: '情绪基线', value: mood, onChanged: (v) => setLocal(() => mood = v)),
                _DialogSlider(label: '自尊感', value: esteem, onChanged: (v) => setLocal(() => esteem = v)),
                _DialogSlider(label: '自我效能', value: efficacy, onChanged: (v) => setLocal(() => efficacy = v)),
                Row(children: <Widget>[
                  Expanded(child: _SmallCounter(label: 'cope 次数', value: cope, onMinus: () => setLocal(() => cope = (cope - 1).clamp(0, 99).toInt()), onPlus: () => setLocal(() => cope++))),
                  const SizedBox(width: 8),
                  Expanded(child: _SmallCounter(label: 'avoid 次数', value: avoid, onMinus: () => setLocal(() => avoid = (avoid - 1).clamp(0, 99).toInt()), onPlus: () => setLocal(() => avoid++))),
                ]),
                CheckboxListTile(
                  value: minAction,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setLocal(() => minAction = v ?? false),
                  title: const Text('今天完成过最小行动'),
                ),
                CheckboxListTile(
                  value: review,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setLocal(() => review = v ?? false),
                  title: const Text('今天做过失败/阻碍复盘'),
                ),
                CheckboxListTile(
                  value: optimism,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setLocal(() => optimism = v ?? false),
                  title: const Text('今天使用过现实乐观解释'),
                ),
                TextField(
                  controller: noteCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '一句记录', hintText: '今天我更愿意面对的是……'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
          ],
        ),
      ),
    );
    final baselineNote = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (saved == true) {
      await _dao.addBaseline(RealisticOptimismBaselineEntry(
        tsMs: DateTime.now().millisecondsSinceEpoch,
        moodScore: mood,
        selfEsteemScore: esteem,
        selfEfficacyScore: efficacy,
        copeCount: cope,
        avoidCount: avoid,
        minimumActionDone: minAction,
        failureReviewDone: review,
        realisticOptimismUsed: optimism,
        note: baselineNote,
      ));
      await _load();
      _toast('已记录基线');
    }
  }

  void _showPromptSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: const <Widget>[
            Text('AI 三层 Prompt', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 12),
            _PromptBlock(title: '全局价值层', body: RealisticOptimismPromptConfig.globalValuePrompt),
            _PromptBlock(title: '场景层', body: '限制性信念扫描、解释风格雷达、双镜头重构、注意力 Prime、过程模拟行动器、失败解释、cope训练、基线复盘已合并到模块生成链路中。'),
            _PromptBlock(title: '输出格式层', body: RealisticOptimismPromptConfig.outputFormatPrompt),
          ],
        ),
      ),
    );
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('现实主义乐观训练系统'),
        actions: <Widget>[
          IconButton(onPressed: _recordBaseline, icon: const Icon(Icons.insights_outlined), tooltip: '记录基线'),
          IconButton(onPressed: _showPromptSheet, icon: const Icon(Icons.integration_instructions_outlined), tooltip: '查看Prompt'),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') _clearAll();
            },
            itemBuilder: (ctx) => const <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'clear', child: Text('清空该模块所有数据')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(text: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
                    children: <Widget>[
                      const _HeroCard(),
                      const SizedBox(height: 14),
                      _BuildCaseCard(
                        controller: _inputCtrl,
                        generating: _generating,
                        onGenerate: _generate,
                      ),
                      const SizedBox(height: 14),
                      _Dashboard(counts: _counts, baselines: _baselines),
                      const SizedBox(height: 14),
                      const _ValueSystemMap(),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          const Expanded(child: Text('最近的AI 行动闭环', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                          TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('刷新')),
                        ],
                      ),
                      if (_cases.isEmpty)
                        const _EmptyHistory()
                      else
                        ..._cases.map((e) => _CaseListTile(
                              item: e,
                              onTap: () async {
                                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RealisticOptimismCaseDetailPage(item: e)));
                                _load();
                              },
                              onDelete: () async {
                                await _dao.deleteCase(e.id);
                                await _load();
                              },
                            )),
                    ],
                  ),
                ),
    );
  }
}

class RealisticOptimismCaseDetailPage extends StatefulWidget {
  final RealisticOptimismCase item;
  const RealisticOptimismCaseDetailPage({super.key, required this.item});

  @override
  State<RealisticOptimismCaseDetailPage> createState() => _RealisticOptimismCaseDetailPageState();
}

class _RealisticOptimismCaseDetailPageState extends State<RealisticOptimismCaseDetailPage> {
  final RealisticOptimismDao _dao = RealisticOptimismDao();
  List<RealisticOptimismActionLog> _logs = <RealisticOptimismActionLog>[];
  List<RealisticOptimismFailureReview> _reviews = <RealisticOptimismFailureReview>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await _dao.listActionLogs(widget.item.id);
    final reviews = await _dao.listFailureReviews(widget.item.id);
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _reviews = reviews;
      _loading = false;
    });
  }

  Future<void> _recordAction(String status) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == 'done' ? '记录完成' : '记录阻碍/失败'),
        content: TextField(
          controller: noteCtrl,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: status == 'done' ? '完成后我观察到……' : '没有完成的具体条件是……',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (ok == true) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _dao.addActionLog(RealisticOptimismActionLog(
        id: 'ro_log_${now}_${widget.item.id.hashCode.abs()}',
        caseId: widget.item.id,
        status: status,
        note: note,
        createdAtMs: now,
      ));
      await _load();
      _toast(status == 'done' ? '已记录完成证据' : '已记录阻碍，建议继续做失败复盘');
    }
  }

  Future<void> _addFailureReview() async {
    final eventCtrl = TextEditingController(text: widget.item.possibleFailure);
    final explainCtrl = TextEditingController(text: widget.item.nonHelpfulExplanation);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('失败解释重构'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: eventCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '事实：发生了什么？', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: explainCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '原始解释：我怎么理解失败？', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('生成复盘记录')),
        ],
      ),
    );
    final event = eventCtrl.text.trim();
    final explanation = explainCtrl.text.trim();
    eventCtrl.dispose();
    explainCtrl.dispose();
    if (ok == true) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _dao.addFailureReview(RealisticOptimismFailureReview(
        id: 'ro_review_${now}_${widget.item.id.hashCode.abs()}',
        caseId: widget.item.id,
        event: event,
        originalExplanation: explanation,
        permanentFlag: _hasAny(explanation, const <String>['永远', '总是', '从来', '一直']),
        globalFlag: _hasAny(explanation, const <String>['什么都', '全部', '所有', '一切']),
        personalizationFlag: _hasAny(explanation, const <String>['我就是', '说明我', '我是', '我没有']),
        catastropheFlag: _hasAny(explanation, const <String>['完了', '彻底', '没救', '崩了']),
        realisticExplanation: widget.item.realisticExplanation,
        feedback: widget.item.feedbackValue,
        nextAdjustment: widget.item.nextAdjustment,
        createdAtMs: now,
      ));
      await _load();
      _toast('已保存失败复盘');
    }
  }

  bool _hasAny(String s, List<String> keys) => keys.any(s.contains);

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(title: Text(item.title.isEmpty ? 'AI 行动闭环' : item.title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _recordAction('done'),
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('记录行动'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: <Widget>[
          _DetailHeader(item: item),
          const SizedBox(height: 12),
          if (item.displayCards.isNotEmpty) _DisplayCards(cards: item.displayCards),
          const SizedBox(height: 12),
          _Section(title: '1. Permission to Be Human + 事实-解释分离', icon: Icons.wallpaper_outlined, children: <Widget>[
            _KeyValue(label: '旧信念', value: item.oldBelief),
            _KeyValue(label: '新现实乐观信念', value: item.newRealisticBelief),
            _BulletList(title: '事实', items: item.facts),
            _BulletList(title: '解释', items: item.interpretations),
            _BulletList(title: '隐含假设', items: item.hiddenAssumptions),
            _BulletList(title: '行为影响', items: item.behaviorEffects),
          ]),
          _Section(title: '2. 解释风格雷达器', icon: Icons.balance_outlined, children: <Widget>[
            _BulletList(title: '可控因素', items: item.controllableFactors),
            _BulletList(title: '不可控因素', items: item.uncontrollableFactors),
            _BulletList(title: '资源', items: item.resources),
            _BulletList(title: '风险', items: item.risks),
            _BulletList(title: '现实约束', items: item.realityConstraints),
            _BulletList(title: '提高概率的做法', items: item.probabilityImprovers),
          ]),
          _Section(title: '3. Fault Finder / Benefit Finder 双镜头', icon: Icons.auto_awesome_outlined, children: <Widget>[
            _KeyValue(label: '需要启动的状态', value: item.neededState),
            _KeyValue(label: '手机/壁纸提醒语', value: item.phonePrompt),
            _BulletList(title: '积极启动线索', items: item.positiveCues),
            _BulletList(title: '环境改变', items: item.environmentChanges),
            _BulletList(title: '反启动清理', items: item.antiPrimingCleanup),
          ]),
          _Section(title: '4. 今日过程模拟行动器', icon: Icons.play_circle_outline, children: <Widget>[
            _KeyValue(label: '最小行动', value: item.todayMinimumAction),
            _KeyValue(label: '时间', value: item.actionTime),
            _KeyValue(label: '地点', value: item.actionPlace),
            _KeyValue(label: '最小成功标准', value: item.minimumSuccessStandard),
            _KeyValue(label: 'If-Then 应对计划', value: item.ifThenPlan),
            _KeyValue(label: '可能阻碍', value: item.possibleObstacle),
            _KeyValue(label: '兜底动作', value: item.fallbackAction),
            Row(
              children: <Widget>[
                Expanded(child: FilledButton.icon(onPressed: () => _recordAction('done'), icon: const Icon(Icons.check), label: const Text('完成了'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: () => _recordAction('blocked'), icon: const Icon(Icons.flag_outlined), label: const Text('遇到阻碍'))),
              ],
            ),
          ]),
          _Section(title: '5. 失败免疫 / 心理抗体', icon: Icons.replay_circle_filled_outlined, children: <Widget>[
            _KeyValue(label: '可能失败', value: item.possibleFailure),
            _KeyValue(label: '非有益解释', value: item.nonHelpfulExplanation),
            _KeyValue(label: '现实解释', value: item.realisticExplanation),
            _KeyValue(label: '反馈价值', value: item.feedbackValue),
            _KeyValue(label: '下一轮调整', value: item.nextAdjustment),
            OutlinedButton.icon(onPressed: _addFailureReview, icon: const Icon(Icons.edit_note_outlined), label: const Text('写一次失败复盘')),
          ]),
          _Section(title: '6. Prime / 感恩 / 身份沉淀', icon: Icons.directions_run_outlined, children: <Widget>[
            _KeyValue(label: '回避模式', value: item.avoidPattern),
            _KeyValue(label: '舒适区行动', value: item.comfortZoneAction),
            _KeyValue(label: '伸展区行动', value: item.stretchZoneAction),
            _KeyValue(label: '恐慌区行动', value: item.panicZoneAction),
            _KeyValue(label: '推荐但不强迫', value: item.recommendedAction),
            _KeyValue(label: '行动后的自我知觉', value: item.selfPerceptionAfterAction),
            _BulletList(title: '可选行动', items: item.options),
            _KeyValue(label: '反思问题', value: item.reflectionQuestion),
          ]),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
          if (!_loading) _LogsAndReviews(logs: _logs, reviews: _reviews),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(colors: <Color>[Color(0xFF111827), Color(0xFF4338CA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('现实主义乐观训练系统', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text('识别限制性信念 → 校准现实 → 重构期待 → 设计注意力 Prime → 过程模拟行动器 → 失败复盘 → 提高幸福/自尊基线。', style: TextStyle(color: Colors.white70, height: 1.45)),
            SizedBox(height: 12),
            Text('相信不是替代行动，而是启动行动。', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _BuildCaseCard extends StatelessWidget {
  final TextEditingController controller;
  final bool generating;
  final VoidCallback onGenerate;
  const _BuildCaseCard({required this.controller, required this.generating, required this.onGenerate});

  @override
  Widget build(BuildContext context) => _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('今日事件重构', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('写下今天的失败、拖延、被批评、自责、冲突或低落目标。AI 会先做强度分级，再完成情绪允许、事实-解释分离、双镜头重构和 5 分钟行动。', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: '例如：我想学习英语，但过去失败太多次，总觉得自己坚持不了。',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: generating ? null : onGenerate,
                icon: generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                label: Text(generating ? '正在生成安全分级与行动闭环……' : '生成现实主义乐观闭环'),
              ),
            ),
          ],
        ),
      );
}

class _Dashboard extends StatelessWidget {
  final Map<String, int> counts;
  final List<RealisticOptimismBaselineEntry> baselines;
  const _Dashboard({required this.counts, required this.baselines});

  @override
  Widget build(BuildContext context) {
    final latest = baselines.isEmpty ? null : baselines.first;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('现实主义乐观仪表盘', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MetricPill(label: '案例', value: '${counts['cases'] ?? 0}'),
              _MetricPill(label: '行动证据', value: '${counts['actions'] ?? 0}'),
              _MetricPill(label: '失败复盘', value: '${counts['reviews'] ?? 0}'),
              _MetricPill(label: '基线记录', value: '${counts['baselines'] ?? 0}'),
            ],
          ),
          const SizedBox(height: 12),
          if (latest == null)
            const Text('还没有基线记录。建议每天记录一次：情绪、自尊、自我效能、cope/avoid 次数。', style: TextStyle(color: Colors.black54))
          else
            Text('最近基线：情绪 ${latest.moodScore.toStringAsFixed(0)} / 自尊 ${latest.selfEsteemScore.toStringAsFixed(0)} / 效能 ${latest.selfEfficacyScore.toStringAsFixed(0)} · cope ${latest.copeCount} · avoid ${latest.avoidCount}', style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }
}

class _ValueSystemMap extends StatelessWidget {
  const _ValueSystemMap();
  @override
  Widget build(BuildContext context) {
    const items = <_MapItem>[
      _MapItem(Icons.wallpaper_outlined, '情绪容器', '允许自己为人：先承认痛苦，再进入重构。'),
      _MapItem(Icons.balance_outlined, '解释风格雷达', '识别永久化、普遍化、人格化、灾难化、无力化、过滤化。'),
      _MapItem(Icons.school_outlined, '双镜头重构', '从 Fault Finder 转向 Benefit Finder。'),
      _MapItem(Icons.auto_awesome_outlined, '注意力 Prime', '设计价值词、提醒语、行动线索和 Benefit Finder 问题。'),
      _MapItem(Icons.play_circle_outline, '过程模拟行动器', '时间、地点、工具、前三步、障碍和 If-Then。'),
      _MapItem(Icons.replay_circle_filled_outlined, '失败免疫实验室', '预测-实际对比，生成心理抗体。'),
      _MapItem(Icons.directions_run_outlined, '感恩与品味', '具体感恩、30 秒 Savoring 与关系表达。'),
      _MapItem(Icons.insights_outlined, '身份沉淀/幸福基线', '行动证据、身份提醒与每周心理能力趋势。'),
    ];
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('10 个核心训练入口', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...items.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(e.icon, size: 22, color: const Color(0xFF4338CA)),
                    const SizedBox(width: 10),
                    Expanded(child: Text.rich(TextSpan(children: <InlineSpan>[TextSpan(text: '${e.title}：', style: const TextStyle(fontWeight: FontWeight.w800)), TextSpan(text: e.body)]))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _MapItem {
  final IconData icon;
  final String title;
  final String body;
  const _MapItem(this.icon, this.title, this.body);
}

class _CaseListTile extends StatelessWidget {
  final RealisticOptimismCase item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _CaseListTile({required this.item, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.black.withOpacity(0.035),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ListTile(
          onTap: onTap,
          title: Text(item.title.isEmpty ? '现实乐观过程模拟行动器' : item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(item.newRealisticBelief.isEmpty ? item.oldBelief : item.newRealisticBelief, maxLines: 2, overflow: TextOverflow.ellipsis),
          leading: const CircleAvatar(backgroundColor: Color(0xFFE0E7FF), child: Icon(Icons.psychology_alt_outlined, color: Color(0xFF4338CA))),
          trailing: PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') onDelete();
            },
            itemBuilder: (ctx) => const <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ),
      );
}

class _DetailHeader extends StatelessWidget {
  final RealisticOptimismCase item;
  const _DetailHeader({required this.item});
  @override
  Widget build(BuildContext context) => _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(item.title.isEmpty ? '现实乐观过程模拟行动器' : item.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(item.coreProblem.isEmpty ? item.originalInput : item.coreProblem, style: const TextStyle(color: Colors.black87, height: 1.45)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              _MetricPill(label: '风险', value: item.riskLevel),
              _MetricPill(label: '来源', value: item.source),
              _MetricPill(label: '模型', value: item.modelLabel),
            ]),
          ],
        ),
      );
}

class _DisplayCards extends StatelessWidget {
  final List<Map<String, dynamic>> cards;
  const _DisplayCards({required this.cards});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 140,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (ctx, i) {
            final c = cards[i];
            return Container(
              width: 240,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.black.withOpacity(0.045)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text((c['title'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Expanded(child: Text((c['content'] ?? '').toString(), maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87, height: 1.35))),
              ]),
            );
          },
        ),
      );
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Section({required this.title, required this.icon, required this.children});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(children: <Widget>[Icon(icon, color: const Color(0xFF4338CA)), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)))]),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );
}

class _KeyValue extends StatelessWidget {
  final String label;
  final String value;
  const _KeyValue({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF374151))),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(height: 1.45)),
      ]),
    );
  }
}

class _BulletList extends StatelessWidget {
  final String title;
  final List<String> items;
  const _BulletList({required this.title, required this.items});
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF374151))),
        const SizedBox(height: 4),
        ...items.map((e) => Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('• $e', style: const TextStyle(height: 1.35)))),
      ]),
    );
  }
}

class _LogsAndReviews extends StatelessWidget {
  final List<RealisticOptimismActionLog> logs;
  final List<RealisticOptimismFailureReview> reviews;
  const _LogsAndReviews({required this.logs, required this.reviews});
  @override
  Widget build(BuildContext context) => _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('行动证据与复盘记录', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            if (logs.isEmpty && reviews.isEmpty) const Text('还没有记录。完成一次最小行动，或把一次失败转成反馈资料。', style: TextStyle(color: Colors.black54)),
            ...logs.take(8).map((e) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(e.status == 'done' ? Icons.check_circle_outline : Icons.flag_outlined, color: e.status == 'done' ? Colors.green : Colors.orange),
                  title: Text(e.status == 'done' ? '完成证据' : '阻碍记录'),
                  subtitle: Text(e.note.isEmpty ? _timeText(e.createdAtMs) : '${e.note}\n${_timeText(e.createdAtMs)}'),
                )),
            ...reviews.take(8).map((e) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.replay_circle_filled_outlined, color: Color(0xFF4338CA)),
                  title: Text(e.event.isEmpty ? '失败复盘' : e.event, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('原解释：${e.originalExplanation}\n新解释：${e.realisticExplanation}', maxLines: 3, overflow: TextOverflow.ellipsis),
                )),
          ],
        ),
      );
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  const _SurfaceCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: <BoxShadow>[BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: child,
      );
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  const _MetricPill({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(999)),
        child: Text('$label $value', style: const TextStyle(color: Color(0xFF3730A3), fontWeight: FontWeight.w800)),
      );
}

class _PromptBlock extends StatelessWidget {
  final String title;
  final String body;
  const _PromptBlock({required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.045), borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(height: 1.4)),
          ]),
        ),
      );
}

class _DialogSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _DialogSlider({required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text('$label：${value.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
        Slider(value: value, min: 1, max: 10, divisions: 9, label: value.toStringAsFixed(0), onChanged: onChanged),
      ]);
}

class _SmallCounter extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _SmallCounter({required this.label, required this.value, required this.onMinus, required this.onPlus});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
        child: Column(children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            IconButton(onPressed: onMinus, icon: const Icon(Icons.remove), visualDensity: VisualDensity.compact),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
            IconButton(onPressed: onPlus, icon: const Icon(Icons.add), visualDensity: VisualDensity.compact),
          ]),
        ]),
      );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.035), borderRadius: BorderRadius.circular(20)),
        child: const Text('还没有AI 行动闭环。先从一个“我做不到/我失败了/我拖延了”的真实句子开始。', style: TextStyle(color: Colors.black54)),
      );
}

class _ErrorState extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _ErrorState({required this.text, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ]),
        ),
      );
}

String _timeText(int ms) {
  if (ms <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}
