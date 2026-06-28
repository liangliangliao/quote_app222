import 'package:flutter/material.dart';

import '../pages/ai_prompt_settings_page.dart';

import 'woop_action_ai_service.dart';
import 'woop_action_dao.dart';
import 'woop_action_extra_pages.dart';
import 'woop_action_models.dart';
import 'woop_action_prompt_config.dart';
import 'woop_action_v6_pages.dart';
import 'woop_action_v7_pages.dart';

class WoopActionEngineHomePage extends StatefulWidget {
  final String initialInput;
  final String source;
  final String extraContext;

  const WoopActionEngineHomePage({
    super.key,
    this.initialInput = '',
    this.source = 'manual',
    this.extraContext = '',
  });

  @override
  State<WoopActionEngineHomePage> createState() => _WoopActionEngineHomePageState();
}

class _WoopActionEngineHomePageState extends State<WoopActionEngineHomePage> {
  final WoopActionDao _dao = WoopActionDao();
  final WoopActionAiService _ai = WoopActionAiService();
  final TextEditingController _inputCtrl = TextEditingController();
  String _selectedScene = 'auto';
  bool _loading = true;
  bool _generating = false;
  String? _error;
  List<WoopActionCard> _cards = <WoopActionCard>[];
  Map<String, int> _counts = const <String, int>{};
  Map<String, int> _tagCounts = const <String, int>{};

  static const List<_SceneChip> _sceneChips = <_SceneChip>[
    _SceneChip('auto', '自动判断'),
    _SceneChip('wish_clarify', '愿望澄清'),
    _SceneChip('positive_fantasy', '幻想转行动'),
    _SceneChip('action_conversion', 'WOOP 行动'),
    _SceneChip('obstacle_diagnosis', '障碍诊断'),
    _SceneChip('failure_review', '失败复盘'),
    _SceneChip('waiting_comfort', '等待安慰'),
    _SceneChip('large_goal', '大目标缩小'),
    _SceneChip('drop_or_adjust', '继续/放下'),
    _SceneChip('health', '健康'),
    _SceneChip('work_study', '学习工作'),
    _SceneChip('relation', '关系沟通'),
    _SceneChip('emotion_impulse', '情绪冲动'),
    _SceneChip('daily_24h', '24小时'),
    _SceneChip('fantasy_safe_explore', '幻想安全区'),
    _SceneChip('obstacle_radar', '障碍雷达分析'),
    _SceneChip('weekly_review', '周复盘/愿望地图'),
  ];

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
      final cards = await _dao.listCards(limit: 80);
      final counts = await _dao.counts();
      final tagCounts = await _dao.obstacleTagCounts();
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _counts = counts;
        _tagCounts = tagCounts;
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
      _toast('请先写下一个愿望、幻想、障碍、失败或今天想推进的行动。');
      return;
    }
    setState(() => _generating = true);
    try {
      final result = await _ai.generateCard(
        userInput: input,
        scene: _selectedScene,
        source: widget.source,
        extraContext: widget.extraContext,
      );
      final id = await _dao.upsertCard(result.card);
      final saved = await _dao.getCard(id) ?? result.card.copyWith(id: id);
      await _load();
      if (!mounted) return;
      _inputCtrl.clear();
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => WoopActionCardDetailPage(card: saved)));
      _load();
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _quickDailyWoop() async {
    final now = DateTime.now();
    _inputCtrl.text = '今天我最想推进的一件重要小事是：。当前能量和时间有限，请帮我做一个 24 小时 WOOP，并把第一步压到 5—15 分钟。日期：${now.year}-${now.month}-${now.day}';
    setState(() => _selectedScene = 'daily_24h');
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空 WOOP 行动引擎数据？'),
        content: const Text('将删除该独立模块里的所有 WOOP 行动卡与复盘记录，不影响其他模块。该操作不可恢复。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok == true) {
      await _dao.clearAll();
      await _load();
      _toast('已清空 WOOP 行动引擎数据');
    }
  }

  void _showPromptSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AiPromptSettingsPage(
          initialModuleId: 'woop_action_engine',
          initialPromptId: WoopActionPromptConfig.globalId,
        ),
      ),
    );
  }


  Future<void> _openGuide() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WoopActionGuidePage()));
  }

  Future<void> _openSceneLibrary() async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(builder: (_) => const WoopActionSceneLibraryPage()),
    );
    if (result is WoopActionCard) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => WoopActionCardDetailPage(card: result)));
      _load();
    } else if (result is WoopActionSceneLaunch) {
      _fillTemplate(result.scene, result.template);
    }
  }


  Future<void> _openManualWizard() async {
    final saved = await Navigator.of(context).push<WoopActionCard>(
      MaterialPageRoute(builder: (_) => const WoopActionManualWizardPage()),
    );
    if (saved != null && mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => WoopActionCardDetailPage(card: saved)));
    }
    _load();
  }

  Future<void> _openTargetFilter() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WoopActionTargetFilterPage(
          onOpenCard: (card) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WoopActionCardDetailPage(card: card))),
        ),
      ),
    );
    _load();
  }


  Future<void> _openProfile() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WoopActionProfilePage()));
    _load();
  }

  Future<void> _openMetrics() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WoopActionMetricsPage()));
    _load();
  }

  Future<void> _openDailyCockpit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WoopActionDailyCockpitPage(
          onOpenCard: (card) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WoopActionCardDetailPage(card: card))),
        ),
      ),
    );
    _load();
  }

  Future<void> _openWishMap() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WoopActionWishMapPage(
          onOpenCard: (card) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WoopActionCardDetailPage(card: card))),
        ),
      ),
    );
    _load();
  }

  Future<void> _openObstacleRadar() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WoopActionObstacleRadarPage(
          onOpenCard: (card) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WoopActionCardDetailPage(card: card))),
        ),
      ),
    );
    _load();
  }

  Future<void> _openPlanLibrary() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WoopActionPlanLibraryPage(
          onOpenCard: (card) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WoopActionCardDetailPage(card: card))),
        ),
      ),
    );
    _load();
  }


  Future<void> _openReviewCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WoopActionReviewCenterPage(
          onOpenCard: (card) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WoopActionCardDetailPage(card: card))),
        ),
      ),
    );
    _load();
  }

  Future<void> _openPromptCoverage() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WoopActionPromptCoveragePage()));
  }

  void _fillTemplate(String scene, String text) {
    setState(() {
      _selectedScene = scene;
      _inputCtrl.text = text;
    });
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WOOP 行动引擎'),
        actions: <Widget>[
          IconButton(onPressed: _quickDailyWoop, icon: const Icon(Icons.today_outlined), tooltip: '24 小时 WOOP'),
          IconButton(onPressed: _showPromptSheet, icon: const Icon(Icons.tune_outlined), tooltip: '设置页配置 WOOP AI 提示词'),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'guide') _openGuide();
              if (v == 'scene') _openSceneLibrary();
              if (v == 'manual') _openManualWizard();
              if (v == 'target_filter') _openTargetFilter();
              if (v == 'profile') _openProfile();
              if (v == 'metrics') _openMetrics();
              if (v == 'daily_cockpit') _openDailyCockpit();
              if (v == 'map') _openWishMap();
              if (v == 'radar') _openObstacleRadar();
              if (v == 'plans') _openPlanLibrary();
              if (v == 'review_center') _openReviewCenter();
              if (v == 'prompt_coverage') _openPromptCoverage();
              if (v == 'clear') _clearAll();
            },
            itemBuilder: (ctx) => const <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'guide', child: Text('价值引导 / 原书思想')),
              PopupMenuItem(value: 'scene', child: Text('场景工具库')),
              PopupMenuItem(value: 'manual', child: Text('手动 WOOP 向导')),
              PopupMenuItem(value: 'target_filter', child: Text('目标筛选器')),
              PopupMenuItem(value: 'profile', child: Text('WOOP 个人化配置')),
              PopupMenuItem(value: 'metrics', child: Text('WOOP 行动指标')),
              PopupMenuItem(value: 'daily_cockpit', child: Text('今日 WOOP 驾驶舱')),
              PopupMenuItem(value: 'map', child: Text('愿望地图')),
              PopupMenuItem(value: 'radar', child: Text('障碍雷达')),
              PopupMenuItem(value: 'plans', child: Text('if–then 计划库')),
              PopupMenuItem(value: 'review_center', child: Text('复盘中心')),
              PopupMenuItem(value: 'prompt_coverage', child: Text('Prompt 覆盖检查')),
              PopupMenuDivider(),
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: <Widget>[
                      const _HeroCard(),
                      const SizedBox(height: 14),
                      WoopActionFeatureGrid(
                        onGuide: _openGuide,
                        onSceneLibrary: _openSceneLibrary,
                        onManualWizard: _openManualWizard,
                        onTargetFilter: _openTargetFilter,
                        onProfile: _openProfile,
                        onMetrics: _openMetrics,
                        onDailyCockpit: _openDailyCockpit,
                        onWishMap: _openWishMap,
                        onRadar: _openObstacleRadar,
                        onPlanLibrary: _openPlanLibrary,
                        onReviewCenter: _openReviewCenter,
                        onPromptCenter: _showPromptSheet,
                      ),
                      const SizedBox(height: 14),
                      WoopActionDeepClosurePanel(
                        onOpenCard: (card) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WoopActionCardDetailPage(card: card))),
                        onRefresh: _load,
                      ),
                      const SizedBox(height: 14),
                      WoopActionV7ClosurePanel(
                        onOpenCard: (card) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WoopActionCardDetailPage(card: card))),
                        onRefresh: _load,
                      ),
                      const SizedBox(height: 14),
                      _BuildWoopCard(
                        controller: _inputCtrl,
                        selectedScene: _selectedScene,
                        sceneChips: _sceneChips,
                        generating: _generating,
                        onSceneChanged: (v) => setState(() => _selectedScene = v),
                        onGenerate: _generate,
                        onTemplate: _fillTemplate,
                      ),
                      const SizedBox(height: 14),
                      _StatsGrid(counts: _counts),
                      const SizedBox(height: 14),
                      _WishMapPanel(counts: _counts),
                      if (_tagCounts.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        _ObstacleRadar(tagCounts: _tagCounts),
                      ],
                      const SizedBox(height: 18),
                      _SectionHeader(
                        title: '愿望—障碍—行动卡',
                        subtitle: '按最近更新排序；每张卡都独立保存 WOOP、if–then 和复盘记录。',
                        trailing: Text('${_cards.length} 张', style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 10),
                      if (_cards.isEmpty)
                        const _EmptyState()
                      else
                        for (final card in _cards) ...<Widget>[
                          _WoopCardTile(
                            card: card,
                            onTap: () async {
                              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => WoopActionCardDetailPage(card: card)));
                              _load();
                            },
                            onDone: () async {
                              await _dao.updateStatus(card.id, card.status == 'done' ? 'active' : 'done');
                              await _load();
                            },
                            onPause: () async {
                              await _dao.updateStatus(card.id, card.status == 'paused' ? 'active' : 'paused');
                              await _load();
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
    );
  }
}

class WoopActionCardDetailPage extends StatefulWidget {
  final WoopActionCard card;
  const WoopActionCardDetailPage({super.key, required this.card});

  @override
  State<WoopActionCardDetailPage> createState() => _WoopActionCardDetailPageState();
}

class _WoopActionCardDetailPageState extends State<WoopActionCardDetailPage> {
  final WoopActionDao _dao = WoopActionDao();
  final WoopActionAiService _ai = WoopActionAiService();
  late WoopActionCard _card;
  List<WoopActionReview> _reviews = <WoopActionReview>[];
  List<WoopActionPlanLog> _planLogs = <WoopActionPlanLog>[];
  bool _loading = true;
  bool _revisionBusy = false;

  @override
  void initState() {
    super.initState();
    _card = widget.card;
    _load();
  }

  Future<void> _load() async {
    final fresh = _card.id > 0 ? await _dao.getCard(_card.id) : null;
    final reviews = _card.id > 0 ? await _dao.listReviews(_card.id) : <WoopActionReview>[];
    final planLogs = _card.id > 0 ? await _dao.listPlanLogs(cardId: _card.id, limit: 40) : <WoopActionPlanLog>[];
    if (!mounted) return;
    setState(() {
      _card = fresh ?? _card;
      _reviews = reviews;
      _planLogs = planLogs;
      _loading = false;
    });
  }

  Future<void> _markStatus(String status) async {
    if (_card.id <= 0) return;
    await _dao.updateStatus(_card.id, status);
    await _load();
  }


  Future<void> _deleteCard() async {
    if (_card.id <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这张 WOOP 卡？'),
        content: const Text('会同时删除该卡的复盘记录，只影响 WOOP 行动引擎独立模块。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await _dao.deleteCard(_card.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _addReview({required String result}) async {
    final actualCtrl = TextEditingController();
    final obstacleCtrl = TextEditingController();
    final adjustmentCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(result == 'done' ? '完成复盘' : '障碍/失败复盘'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(controller: actualCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '实际发生了什么？')),
              TextField(controller: obstacleCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '哪个障碍出现了？')),
              TextField(controller: adjustmentCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '下一版计划要怎么调整？')),
              TextField(controller: noteCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '补充记录')),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    final actual = actualCtrl.text.trim();
    final obstacle = obstacleCtrl.text.trim();
    final adjustment = adjustmentCtrl.text.trim();
    final note = noteCtrl.text.trim();
    actualCtrl.dispose();
    obstacleCtrl.dispose();
    adjustmentCtrl.dispose();
    noteCtrl.dispose();
    if (saved == true && _card.id > 0) {
      await _dao.addReview(WoopActionReview(
        cardId: _card.id,
        result: result,
        actualEvent: actual,
        obstacleAppeared: obstacle,
        planWorked: result == 'done' ? '计划触发或部分触发' : '原计划没有完全覆盖真实障碍',
        newObstacle: obstacle,
        nextAdjustment: adjustment,
        note: note,
      ));
      await _load();
    }
  }


  Future<void> _generateRevisionFromFeedback() async {
    if (_card.id <= 0) return;
    setState(() => _revisionBusy = true);
    try {
      final latest = _reviews.isNotEmpty ? _reviews.first : null;
      final latestText = latest == null
          ? '还没有详细复盘；请基于原卡推测可能需要缩小行动。'
          : '实际发生：${latest.actualEvent}\n出现障碍：${latest.obstacleAppeared}\n下一版调整：${latest.nextAdjustment}\n补充：${latest.note}';
      final input = '''请基于下面这张 WOOP 行动卡和最新复盘，生成一个“新版 WOOP”。不要羞辱用户，要把失败当作反馈，识别原计划未覆盖的真实障碍，并把 if–then 计划改得更低门槛、更具体。

原愿望：${_card.wish}
原最佳结果：${_card.outcome}
原障碍：${_card.obstacle}
原计划：${_card.planText}

最新复盘：$latestText''';
      final result = await _ai.generateCard(
        userInput: input,
        scene: 'failure_review',
        source: 'review_revision',
        extraContext: 'source_card_id=${_card.id}',
      );
      final id = await _dao.upsertCard(result.card.copyWith(status: 'active'));
      final saved = await _dao.getCard(id) ?? result.card.copyWith(id: id);
      await _load();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => WoopActionCardDetailPage(card: saved)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('生成新版 WOOP 失败：$e'), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _revisionBusy = false);
    }
  }




  Future<void> _logPlanExecution(String result) async {
    if (_card.id <= 0) return;
    await _dao.addPlanLog(WoopActionPlanLog(
      cardId: _card.id,
      triggerText: _card.planIf,
      actionText: _card.planThen.trim().isEmpty ? _card.firstAction : _card.planThen,
      result: result,
      note: result == 'done'
          ? '详情页记录：if–then 计划已执行。'
          : '详情页记录：if–then 未完全触发，建议做障碍复盘。',
    ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(_card.status);
    return Scaffold(
      appBar: AppBar(
        title: Text(_card.title.isEmpty ? 'WOOP 行动卡' : _card.title),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') {
                _deleteCard();
              } else {
                _markStatus(v);
              }
            },
            itemBuilder: (ctx) => const <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'active', child: Text('设为行动中')),
              PopupMenuItem(value: 'done', child: Text('设为完成')),
              PopupMenuItem(value: 'paused', child: Text('设为暂存')),
              PopupMenuItem(value: 'dropped', child: Text('设为放下')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'delete', child: Text('删除该卡')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[color.withOpacity(0.14), const Color(0xFFFFFFFF)],
                    ),
                    border: Border.all(color: color.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _Pill(text: _sceneLabel(_card.scene), icon: Icons.psychology_alt_outlined),
                          _Pill(text: _directionLabel(_card.direction), icon: Icons.alt_route_outlined),
                          _Pill(text: _statusLabel(_card.status), icon: Icons.flag_outlined),
                          if (_card.fromFallback) const _Pill(text: '内置策略', icon: Icons.offline_bolt_outlined),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(_card.currentJudgement, style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF374151), fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      _ScoreRow(card: _card),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _DetailBlock(title: 'W｜愿望', body: _card.wish, icon: Icons.track_changes_outlined),
                _DetailBlock(title: 'O｜最佳结果', body: _card.outcome, icon: Icons.auto_awesome_outlined),
                _DetailBlock(title: 'O｜关键内在障碍', body: _card.obstacle, icon: Icons.warning_amber_outlined, chips: _card.obstacleTags),
                _DetailBlock(title: 'P｜如果—那么计划', body: _card.planText, icon: Icons.bolt_outlined),
                _DetailBlock(title: '第一步行动', body: _card.firstAction, icon: Icons.directions_run_outlined),
                _DetailBlock(title: '复盘问题', body: _card.reviewQuestion, icon: Icons.rate_review_outlined),
                if (_card.reminder.trim().isNotEmpty) _DetailBlock(title: '提醒', body: _card.reminder, icon: Icons.info_outline),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(child: FilledButton.icon(onPressed: () => _addReview(result: 'done'), icon: const Icon(Icons.check_circle_outline), label: const Text('完成复盘'))),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton.icon(onPressed: () => _addReview(result: 'blocked'), icon: const Icon(Icons.refresh_outlined), label: const Text('障碍复盘'))),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _revisionBusy ? null : _generateRevisionFromFeedback,
                    icon: _revisionBusy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_fix_high_outlined),
                    label: Text(_revisionBusy ? '正在基于反馈生成新版 WOOP…' : '基于复盘/当前卡生成新版 WOOP'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(child: OutlinedButton.icon(onPressed: () => _logPlanExecution('done'), icon: const Icon(Icons.playlist_add_check_outlined), label: const Text('记录已执行'))),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton.icon(onPressed: () => _logPlanExecution('missed'), icon: const Icon(Icons.error_outline), label: const Text('记录未触发'))),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionHeader(title: 'if–then 执行日志', subtitle: '记录计划是否真的在障碍出现时触发。', trailing: Text('${_planLogs.length} 条')),
                const SizedBox(height: 10),
                if (_planLogs.isEmpty)
                  const _MiniEmpty(text: '还没有执行日志。障碍出现时记录一次，能帮助验证计划是否太大、太模糊或触发条件不准。')
                else
                  for (final l in _planLogs) ...<Widget>[
                    _PlanLogTile(log: l),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 20),
                _SectionHeader(title: '复盘记录', subtitle: '完成或失败都变成下一版系统信息。', trailing: Text('${_reviews.length} 条')),
                const SizedBox(height: 10),
                if (_reviews.isEmpty)
                  const _MiniEmpty(text: '还没有复盘。完成或遇到障碍后，在这里记录真实发生了什么。')
                else
                  for (final r in _reviews) ...<Widget>[
                    _ReviewTile(review: r),
                    const SizedBox(height: 10),
                  ],
                if (_card.aiResponse.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _DetailBlock(title: 'AI 原始输出', body: _card.aiResponse, icon: Icons.article_outlined),
                ],
              ],
            ),
    );
  }
}

class _BuildWoopCard extends StatelessWidget {
  final TextEditingController controller;
  final String selectedScene;
  final List<_SceneChip> sceneChips;
  final bool generating;
  final ValueChanged<String> onSceneChanged;
  final VoidCallback onGenerate;
  final void Function(String scene, String text) onTemplate;

  const _BuildWoopCard({
    required this.controller,
    required this.selectedScene,
    required this.sceneChips,
    required this.generating,
    required this.onSceneChanged,
    required this.onGenerate,
    required this.onTemplate,
  });



  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x10000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('把愿望转成行动', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('写下一个愿望、幻想、障碍、失败或今天想推进的事。AI 会按《Rethinking Positive Thinking》的心理对照与 WOOP 生成行动卡。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: '例如：我想本周完成论文第一稿，但一想到写不好就拖延。',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final chip in sceneChips)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(chip.label),
                      selected: selectedScene == chip.value,
                      onSelected: (_) => onSceneChanged(chip.value),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => onTemplate('daily_24h', '今天我最想推进的一件重要小事是：。请帮我做一个 24 小时 WOOP，把第一步压到 5—15 分钟。'),
                icon: const Icon(Icons.today_outlined, size: 18),
                label: const Text('24小时 WOOP'),
              ),
              OutlinedButton.icon(
                onPressed: () => onTemplate('weekly_review', '请基于我最近的愿望和卡点，帮我整理愿望地图：哪些继续、哪些调整、哪些暂存、哪些可以放下。'),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('愿望地图'),
              ),
              OutlinedButton.icon(
                onPressed: () => onTemplate('obstacle_radar', '我最近反复卡在这些障碍上：。请帮我做障碍雷达分析，并生成下一周最应该使用的 if–then 模板。'),
                icon: const Icon(Icons.radar_outlined, size: 18),
                label: const Text('障碍雷达'),
              ),
              OutlinedButton.icon(
                onPressed: () => onTemplate('fantasy_safe_explore', '我现在暂时不想马上行动，只想先想象一个更好的结果：。请帮我用幻想识别真实需要，再判断有没有一个可控小动作。'),
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('幻想安全区'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: generating ? null : onGenerate,
              icon: generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_outlined),
              label: Text(generating ? '正在生成 WOOP 行动卡…' : '生成 WOOP 行动卡'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();



  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF111827), Color(0xFF4338CA), Color(0xFF0EA5E9)],
        ),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x33111827), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.psychology_alt_outlined, color: Colors.white, size: 30),
              SizedBox(width: 10),
              Expanded(child: Text('WOOP 行动引擎', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
            ],
          ),
          SizedBox(height: 12),
          Text('梦想给方向，现实给力量，障碍给入口，计划让行动发生。', style: TextStyle(color: Colors.white, fontSize: 16, height: 1.45, fontWeight: FontWeight.w700)),
          SizedBox(height: 10),
          Text('基于《Rethinking Positive Thinking》：不让用户停留在积极幻想里，而是用心理对照识别内在障碍，用 if–then 计划触发现实行动。', style: TextStyle(color: Color(0xFFE0F2FE), height: 1.5)),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, int> counts;
  const _StatsGrid({required this.counts});



  @override
  Widget build(BuildContext context) {
    final items = <_StatItem>[
      _StatItem('总行动卡', counts['total'] ?? 0, Icons.style_outlined),
      _StatItem('行动中', counts['active'] ?? 0, Icons.bolt_outlined),
      _StatItem('已完成', counts['done'] ?? 0, Icons.check_circle_outline),
      _StatItem('复盘', counts['reviews'] ?? 0, Icons.rate_review_outlined),
      _StatItem('执行日志', counts['planLogs'] ?? 0, Icons.playlist_add_check_outlined),
      _StatItem('Check-in', counts['checkins'] ?? 0, Icons.today_outlined),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.35,
      children: <Widget>[
        for (final item in items)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Row(children: <Widget>[
              Icon(item.icon, color: const Color(0xFF4F46E5)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                Text('${item.value}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ])),
            ]),
          ),
      ],
    );
  }
}


class _WishMapPanel extends StatelessWidget {
  final Map<String, int> counts;
  const _WishMapPanel({required this.counts});



  @override
  Widget build(BuildContext context) {
    final active = counts['active'] ?? 0;
    final done = counts['done'] ?? 0;
    final paused = counts['paused'] ?? 0;
    final dropped = counts['dropped'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('愿望地图', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('WOOP 不是让所有愿望都硬扛。这里把愿望分成行动中、完成、暂存和放下，帮助你把有限精力投向真正重要且可行的目标。', style: TextStyle(color: Color(0xFF166534), height: 1.45)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MiniTag(text: '行动中 $active'),
              _MiniTag(text: '已完成 $done'),
              _MiniTag(text: '暂存 $paused'),
              _MiniTag(text: '已放下 $dropped'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ObstacleRadar extends StatelessWidget {
  final Map<String, int> tagCounts;
  const _ObstacleRadar({required this.tagCounts});



  @override
  Widget build(BuildContext context) {
    final max = tagCounts.values.isEmpty ? 1 : tagCounts.values.reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('障碍雷达', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('这里统计你最常见的内在障碍，帮助你看见“我如何挡住了我”。', style: TextStyle(color: Color(0xFF92400E), height: 1.45)),
          const SizedBox(height: 12),
          for (final entry in tagCounts.entries.take(8)) ...<Widget>[
            Row(children: <Widget>[
              SizedBox(width: 92, child: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: entry.value / max, minHeight: 8, backgroundColor: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _WoopCardTile extends StatelessWidget {
  final WoopActionCard card;
  final VoidCallback onTap;
  final VoidCallback onDone;
  final VoidCallback onPause;

  const _WoopCardTile({required this.card, required this.onTap, required this.onDone, required this.onPause});



  @override
  Widget build(BuildContext context) {
    final color = _statusColor(card.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB)), boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 6))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.bolt_outlined, color: color)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(card.title.isEmpty ? card.wish : card.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(_sceneLabel(card.scene), style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w700)),
            ])),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'done') onDone();
                if (v == 'pause') onPause();
              },
              itemBuilder: (ctx) => <PopupMenuEntry<String>>[
                PopupMenuItem(value: 'done', child: Text(card.status == 'done' ? '设回行动中' : '标记完成')),
                PopupMenuItem(value: 'pause', child: Text(card.status == 'paused' ? '恢复行动中' : '暂存')),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          _SmallLine(icon: Icons.track_changes_outlined, text: card.wish),
          _SmallLine(icon: Icons.warning_amber_outlined, text: card.obstacle),
          _SmallLine(icon: Icons.alt_route_outlined, text: card.planText),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            _MiniTag(text: _statusLabel(card.status)),
            _MiniTag(text: _directionLabel(card.direction)),
            if (card.obstacleType.trim().isNotEmpty) _MiniTag(text: card.obstacleType),
            if (card.fromFallback) const _MiniTag(text: '内置'),
          ]),
        ]),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final List<String> chips;
  const _DetailBlock({required this.title, required this.body, required this.icon, this.chips = const <String>[]});



  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[Icon(icon, size: 20, color: const Color(0xFF4F46E5)), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)))]),
        const SizedBox(height: 10),
        Text(body.trim().isEmpty ? '未填写' : body.trim(), style: const TextStyle(height: 1.55, color: Color(0xFF374151))),
        if (chips.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[for (final chip in chips) _MiniTag(text: chip)]),
        ],
      ]),
    );
  }
}


class _PlanLogTile extends StatelessWidget {
  final WoopActionPlanLog log;
  const _PlanLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final d = DateTime.fromMillisecondsSinceEpoch(
      log.createdAtMs == 0 ? DateTime.now().millisecondsSinceEpoch : log.createdAtMs,
    );
    final ok = log.result == 'done';
    final resultText = ok ? '已执行' : '未触发';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Icon(
            ok ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: ok ? const Color(0xFF059669) : const Color(0xFFD97706),
          ),
          const SizedBox(width: 6),
          Text(
            '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          Text(resultText, style: const TextStyle(color: Color(0xFF6B7280))),
        ]),
        if (log.triggerText.trim().isNotEmpty) _ReviewLine(label: '触发条件', value: log.triggerText),
        if (log.actionText.trim().isNotEmpty) _ReviewLine(label: '执行动作', value: log.actionText),
        if (log.note.trim().isNotEmpty) _ReviewLine(label: '补充', value: log.note),
      ]),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final WoopActionReview review;
  const _ReviewTile({required this.review});



  @override
  Widget build(BuildContext context) {
    final d = DateTime.fromMillisecondsSinceEpoch(review.createdAtMs == 0 ? DateTime.now().millisecondsSinceEpoch : review.createdAtMs);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Icon(review.result == 'done' ? Icons.check_circle_outline : Icons.refresh_outlined, size: 18, color: review.result == 'done' ? const Color(0xFF059669) : const Color(0xFFD97706)),
          const SizedBox(width: 6),
          Text('${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          Text(review.result == 'done' ? '完成' : '障碍', style: const TextStyle(color: Color(0xFF6B7280))),
        ]),
        if (review.actualEvent.trim().isNotEmpty) _ReviewLine(label: '实际发生', value: review.actualEvent),
        if (review.obstacleAppeared.trim().isNotEmpty) _ReviewLine(label: '出现障碍', value: review.obstacleAppeared),
        if (review.nextAdjustment.trim().isNotEmpty) _ReviewLine(label: '下一版调整', value: review.nextAdjustment),
        if (review.note.trim().isNotEmpty) _ReviewLine(label: '补充', value: review.note),
      ]),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  final String label;
  final String value;
  const _ReviewLine({required this.label, required this.value});



  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text('$label：$value', style: const TextStyle(height: 1.45, color: Color(0xFF374151))),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final WoopActionCard card;
  const _ScoreRow({required this.card});



  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
      _Pill(text: '重要性 ${_levelLabel(card.importance)}', icon: Icons.priority_high_outlined),
      _Pill(text: '可行性 ${_levelLabel(card.feasibility)}', icon: Icons.timeline_outlined),
      _Pill(text: '可控性 ${_levelLabel(card.controllability)}', icon: Icons.tune_outlined),
      _Pill(text: '代价 ${_levelLabel(card.cost)}', icon: Icons.balance_outlined),
      _Pill(text: '归属 ${_belongsLabel(card.belongsToUser)}', icon: Icons.person_outline),
    ]);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _SectionHeader({required this.title, required this.subtitle, this.trailing});



  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), height: 1.35)),
      ])),
      if (trailing != null) trailing!,
    ]);
  }
}

class _PromptBlock extends StatelessWidget {
  final String title;
  final String body;
  const _PromptBlock({required this.title, required this.body});



  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(body, style: const TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFF374151))),
      ]),
    );
  }
}

class _SmallLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SmallLine({required this.icon, required this.text});



  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Icon(icon, size: 17, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.35, color: Color(0xFF374151)))),
      ]),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String text;
  const _MiniTag({required this.text});



  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Pill({required this.text, required this.icon});



  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.86), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[Icon(icon, size: 15, color: const Color(0xFF4F46E5)), const SizedBox(width: 5), Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();



  @override
  Widget build(BuildContext context) {
    return const _MiniEmpty(text: '还没有 WOOP 行动卡。先写下一个愿望，系统会帮你从积极幻想进入心理对照，再生成 if–then 计划。');
  }
}

class _MiniEmpty extends StatelessWidget {
  final String text;
  const _MiniEmpty({required this.text});



  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Text(text, style: const TextStyle(color: Color(0xFF6B7280), height: 1.45)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _ErrorState({required this.text, required this.onRetry});



  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          const Icon(Icons.error_outline, size: 42, color: Color(0xFFDC2626)),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ]),
      ),
    );
  }
}

class _SceneChip {
  final String value;
  final String label;
  const _SceneChip(this.value, this.label);
}

class _StatItem {
  final String label;
  final int value;
  final IconData icon;
  const _StatItem(this.label, this.value, this.icon);
}

Color _statusColor(String status) {
  switch (status) {
    case 'done':
      return const Color(0xFF059669);
    case 'paused':
      return const Color(0xFFD97706);
    case 'dropped':
    case 'archived':
      return const Color(0xFF6B7280);
    default:
      return const Color(0xFF4F46E5);
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'done':
      return '已完成';
    case 'paused':
      return '暂存';
    case 'dropped':
      return '已放下';
    case 'archived':
      return '已归档';
    default:
      return '行动中';
  }
}

String _directionLabel(String direction) {
  switch (direction) {
    case 'adjust':
      return '调整';
    case 'wait':
      return '等待';
    case 'drop':
      return '放下';
    default:
      return '继续';
  }
}

String _sceneLabel(String scene) {
  switch (scene) {
    case 'wish_clarify':
      return '愿望澄清';
    case 'positive_fantasy':
      return '幻想转行动';
    case 'obstacle_diagnosis':
      return '障碍诊断';
    case 'failure_review':
      return '失败复盘';
    case 'waiting_comfort':
      return '等待安慰';
    case 'large_goal':
      return '大目标缩小';
    case 'drop_or_adjust':
      return '继续/调整/放下';
    case 'health':
      return '健康行为';
    case 'work_study':
      return '学习工作';
    case 'relation':
      return '关系沟通';
    case 'emotion_impulse':
      return '情绪冲动';
    case 'daily_24h':
      return '24小时 WOOP';
    case 'fantasy_safe_explore':
      return '幻想安全区';
    case 'obstacle_radar':
      return '障碍雷达';
    case 'weekly_review':
      return '周复盘/愿望地图';
    default:
      return 'WOOP 行动';
  }
}

String _levelLabel(String value) {
  switch (value) {
    case 'high':
      return '高';
    case 'low':
      return '低';
    default:
      return '中';
  }
}

String _belongsLabel(String value) {
  switch (value) {
    case 'clear':
      return '清晰';
    case 'probably_not':
      return '可能不是';
    default:
      return '不清晰';
  }
}
