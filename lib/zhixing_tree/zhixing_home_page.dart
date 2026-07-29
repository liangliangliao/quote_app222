import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'zhixing_action_page.dart';
import 'zhixing_diagnosis_page.dart';
import 'zhixing_insights_pages.dart';
import 'zhixing_models.dart';
import 'zhixing_repository.dart';

class ZhixingTreeHomePage extends StatefulWidget {
  const ZhixingTreeHomePage({super.key});

  @override
  State<ZhixingTreeHomePage> createState() => _ZhixingTreeHomePageState();
}

class _ZhixingTreeHomePageState extends State<ZhixingTreeHomePage> {
  final ZhixingRepository _repository = ZhixingRepository();
  ZhixingDashboard? _dashboard;
  bool _loading = true;
  String? _error;

  static const Color _green = Color(0xFF247A57);
  static const Color _ink = Color(0xFF17352C);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dashboard = await _repository.loadDashboard();
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openActive() async {
    final action = _dashboard?.active;
    if (action == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ZhixingActionPage(
          repository: _repository,
          initialAction: action,
        ),
      ),
    );
    await _load();
  }

  Future<void> _startDiagnosis({String initialProblem = ''}) async {
    final active = _dashboard?.active;
    if (active != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.filter_1_outlined, color: _green),
          title: const Text('一次只保留一个主要行动'),
          content: const Text(
            '你已经有一张进行中的知行卡。可以继续它，或明确结束并重新校准；系统不会让多个行动同时争夺注意力。',
            style: TextStyle(height: 1.55),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, 'new'),
              child: const Text('结束并重新诊断'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'current'),
              child: const Text('查看当前行动'),
            ),
          ],
        ),
      );
      if (!mounted || choice == null) return;
      if (choice == 'current') {
        await _openActive();
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await _repository.recalibrateAction(
        active,
        ZhixingEvidence(
          id: 'zxe_switch_${now}_${active.id.hashCode.abs()}',
          prescriptionId: active.id,
          createdAtMs: now,
          completed: false,
          predictedDiscomfort: 5,
          actualDiscomfort: 5,
          fit: '部分准确',
          scale: '合适',
          factResult: '用户主动结束当前行动，选择重新诊断一个更重要的问题。',
          learning: '当前优先级或现实条件已经改变。',
          nextStep: '重新完成六问诊断。',
        ),
      );
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ZhixingDiagnosisPage(
          repository: _repository,
          initialProblem: initialProblem,
        ),
      ),
    );
    await _load();
  }

  Future<void> _nourish(String resource) async {
    try {
      await _repository.nourish(resource);
      await _load();
      _toast('养护完成。资源帮助树恢复健康，但真正成长仍来自现实行动。');
    } catch (error) {
      final text = error.toString().replaceFirst('Bad state: ', '');
      _toast(text);
    }
  }

  Future<void> _showShop() async {
    final pack = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF8FAF8),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '用行动金币兑换养分',
                style: TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              const Text(
                '金币只能由现实行动获得，不开放充值。',
                style: TextStyle(color: Color(0xFF6D7973)),
              ),
              const SizedBox(height: 14),
              _ShopTile(
                icon: Icons.water_drop_outlined,
                color: const Color(0xFF397EB8),
                title: '1 份水',
                subtitle: '恢复、维持与复归',
                price: 8,
                onTap: () => Navigator.pop(context, 'water'),
              ),
              _ShopTile(
                icon: Icons.wb_sunny_outlined,
                color: const Color(0xFFD49A22),
                title: '1 份阳光',
                subtitle: '价值、方向与主动选择',
                price: 8,
                onTap: () => Navigator.pop(context, 'sunlight'),
              ),
              _ShopTile(
                icon: Icons.grass_outlined,
                color: const Color(0xFF8A6637),
                title: '1 份肥料',
                subtitle: '挑战、反馈与能力增长',
                price: 12,
                onTap: () => Navigator.pop(context, 'fertilizer'),
              ),
              _ShopTile(
                icon: Icons.spa_outlined,
                color: _green,
                title: '基础养护包',
                subtitle: '水 + 阳光',
                price: 25,
                onTap: () => Navigator.pop(context, 'care'),
              ),
              _ShopTile(
                icon: Icons.park_outlined,
                color: const Color(0xFF5E477D),
                title: '完整成长包',
                subtitle: '水 + 阳光 + 肥料',
                price: 40,
                onTap: () => Navigator.pop(context, 'complete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (pack == null || !mounted) return;
    try {
      await _repository.buyResourcePack(pack);
      await _load();
      _toast('兑换成功。');
    } catch (error) {
      _toast(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F6F2),
        surfaceTintColor: Colors.transparent,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('知行树', style: TextStyle(fontWeight: FontWeight.w900)),
            Text(
              '把知道变成做到',
              style: TextStyle(fontSize: 11, color: Color(0xFF718078)),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: _openMenu,
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'profile',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.radar_outlined),
                  title: Text('动态行动画像'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'evidence',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.inventory_2_outlined),
                  title: Text('行动证据库'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'thoughts',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.menu_book_outlined),
                  title: Text('思想模块与来源'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'data',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('休眠、隐私与数据'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _body(),
    );
  }

  Future<void> _openMenu(String value) async {
    Widget page;
    switch (value) {
      case 'profile':
        page = ZhixingProfilePage(repository: _repository);
        break;
      case 'evidence':
        page = ZhixingEvidencePage(repository: _repository);
        break;
      case 'thoughts':
        page = const ZhixingThoughtLibraryPage();
        break;
      case 'data':
        page = ZhixingDataSettingsPage(repository: _repository);
        break;
      default:
        return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => page),
    );
    if (changed == true || value != 'thoughts') await _load();
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline_rounded, color: Color(0xFFB54B4B), size: 44),
              const SizedBox(height: 12),
              const Text('知行树暂时无法打开', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 15),
              FilledButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    final dashboard = _dashboard!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: <Widget>[
          _treeHero(dashboard.game),
          const SizedBox(height: 14),
          dashboard.active == null
              ? _emptyActionCard()
              : _activeActionCard(dashboard.active!),
          const SizedBox(height: 14),
          _resourceCard(dashboard.game),
          const SizedBox(height: 14),
          _metricsCard(dashboard),
          const SizedBox(height: 14),
          _recentCard(dashboard),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              '产品的终点，是你逐渐不再需要它。',
              style: TextStyle(color: Color(0xFF7A867F), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _treeHero(ZhixingGameState game) {
    final progress = _levelProgress(game.xp, game.level);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFDDEFE4), Color(0xFFF2F7E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFC8DED1)),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 212,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: ZhixingTreePainter(
                      stage: game.stage,
                      condition: game.condition,
                      health: game.health,
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  top: 17,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.78),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'Lv.${game.level} ${game.levelTitle}',
                          style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${game.stageLabel} · ${_conditionLabel(game)}',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '健康 ${game.health.round()}%',
                        style: const TextStyle(color: Color(0xFF587067)),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 15,
                  top: 15,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      _MiniPill(
                        icon: Icons.monetization_on_outlined,
                        text: '${game.coins}',
                        color: const Color(0xFFA97A1E),
                      ),
                      const SizedBox(height: 7),
                      _MiniPill(
                        icon: Icons.bolt_rounded,
                        text: '${game.xp} XP',
                        color: const Color(0xFF6B568A),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 0, 17, 16),
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      game.level >= 7 ? '自主闭环持续中' : '距下一等级',
                      style: const TextStyle(color: Color(0xFF617269), fontSize: 12),
                    ),
                    Text(
                      game.level >= 7 ? 'Lv.7' : '${(_nextLevelXp(game.level) - game.xp).clamp(0, 9999)} XP',
                      style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(.75),
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyActionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0E8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.filter_1_outlined, color: _green),
              SizedBox(width: 9),
              Text(
                '今天只处理一个知行断点',
                style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Text(
            '用六个问题识别价值、认知、情绪、能力、环境和能量中的真正断点，然后生成一张现实行动卡。',
            style: TextStyle(color: Color(0xFF64726B), height: 1.52),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _startDiagnosis,
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('开始六问诊断', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _activeActionCard(ZhixingPrescription action) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: _openActive,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD8E4DD)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(.1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      action.challengeType.label,
                      style: const TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    action.status == ZhixingActionStatus.ready ? '待开始' : '行动中',
                    style: const TextStyle(color: Color(0xFF75827B), fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF75827B)),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                action.title,
                style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              Text(
                action.action,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF42574E), height: 1.48, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 13),
              Row(
                children: <Widget>[
                  const Icon(Icons.touch_app_outlined, color: Color(0xFF9B6C2D), size: 19),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '第一动作：${action.firstPhysicalAction}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF65736C), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resourceCard(ZhixingGameState game) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0E8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                '树木养分',
                style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _showShop,
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('兑换'),
              ),
            ],
          ),
          const Text(
            '水代表恢复，阳光代表方向，肥料代表挑战。三者需要平衡。',
            style: TextStyle(color: Color(0xFF75817B), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 13),
          Row(
            children: <Widget>[
              Expanded(
                child: _ResourceButton(
                  icon: Icons.water_drop_outlined,
                  label: '水',
                  count: game.water,
                  color: const Color(0xFF397EB8),
                  onTap: () => _nourish('water'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResourceButton(
                  icon: Icons.wb_sunny_outlined,
                  label: '阳光',
                  count: game.sunlight,
                  color: const Color(0xFFD49A22),
                  onTap: () => _nourish('sunlight'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResourceButton(
                  icon: Icons.grass_outlined,
                  label: '肥料',
                  count: game.fertilizer,
                  color: const Color(0xFF8A6637),
                  onTap: () => _nourish('fertilizer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricsCard(ZhixingDashboard dashboard) {
    final profile = dashboard.profile;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF213A31),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                '成长不是连续打卡',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ZhixingProfilePage(repository: _repository),
                    ),
                  );
                  _load();
                },
                child: const Text('查看画像', style: TextStyle(color: Color(0xFFA8D4BC))),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: <Widget>[
              Expanded(
                child: _Metric(
                  value: '${dashboard.game.completedCount}',
                  label: '现实完成',
                ),
              ),
              Expanded(
                child: _Metric(
                  value: '${dashboard.game.returnCount}',
                  label: '中断后复归',
                ),
              ),
              Expanded(
                child: _Metric(
                  value: '${dashboard.recentEvidence.length}',
                  label: '近期证据',
                ),
              ),
              Expanded(
                child: _Metric(
                  value: '${(profile.autonomy * 100).round()}%',
                  label: '目标自主度',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recentCard(ZhixingDashboard dashboard) {
    final finished = dashboard.recentActions
        .where(
          (item) =>
              item.status == ZhixingActionStatus.completed ||
              item.status == ZhixingActionStatus.recalibrate,
        )
        .take(3)
        .toList();
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0E8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                '最近的行动证据',
                style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ZhixingEvidencePage(repository: _repository),
                    ),
                  );
                  _load();
                },
                child: const Text('全部'),
              ),
            ],
          ),
          if (finished.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '完成第一张知行卡后，事实证据会出现在这里。',
                style: TextStyle(color: Color(0xFF75817B)),
              ),
            )
          else
            ...finished.map(
              (action) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: action.status == ZhixingActionStatus.completed
                      ? const Color(0xFFE4F1EA)
                      : const Color(0xFFFFF0E1),
                  child: Icon(
                    action.status == ZhixingActionStatus.completed
                        ? Icons.check_rounded
                        : Icons.tune_rounded,
                    color: action.status == ZhixingActionStatus.completed
                        ? _green
                        : const Color(0xFFA66A24),
                  ),
                ),
                title: Text(
                  action.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  action.status == ZhixingActionStatus.completed ? '已完成并形成证据' : '未惩罚，已进入校准',
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _conditionLabel(ZhixingGameState game) {
    if (game.dormant || game.condition == 'dormant') return '休眠保护';
    switch (game.condition) {
      case 'dry':
        return '需要水与复归';
      case 'withered':
        return '枯萎，等待低难度复归';
      case 'seed_waiting':
        return '留下种子，可重新开始';
      default:
        return '健康生长';
    }
  }

  int _nextLevelXp(int level) {
    const thresholds = <int>[0, 40, 120, 280, 520, 850, 1250, 1250];
    return thresholds[level.clamp(1, 7).toInt()];
  }

  double _levelProgress(int xp, int level) {
    if (level >= 7) return 1;
    const starts = <int>[0, 0, 40, 120, 280, 520, 850, 1250];
    const ends = <int>[0, 40, 120, 280, 520, 850, 1250, 1250];
    final start = starts[level.clamp(1, 7).toInt()];
    final end = ends[level.clamp(1, 7).toInt()];
    if (end <= start) return 1;
    return ((xp - start) / (end - start)).clamp(0, 1).toDouble();
  }
}

class ZhixingTreePainter extends CustomPainter {
  final String stage;
  final String condition;
  final double health;

  const ZhixingTreePainter({
    required this.stage,
    required this.condition,
    required this.health,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .58, size.height * .78);
    final sun = Paint()..color = const Color(0x55F5C451);
    canvas.drawCircle(Offset(size.width * .82, size.height * .2), 30, sun);

    final cloud = Paint()..color = Colors.white.withOpacity(.38);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .32, size.height * .22),
        width: 92,
        height: 27,
      ),
      cloud,
    );

    final soil = Paint()..color = const Color(0xFFB8996B).withOpacity(.42);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 9), width: size.width * .58, height: 30),
      soil,
    );

    final index = _stageIndex(stage);
    final leafHealth = (health / 100).clamp(0, 1).toDouble();
    final dry = condition == 'dry' || condition == 'withered' || condition == 'seed_waiting';
    final leafColor = dry
        ? Color.lerp(const Color(0xFFB98A45), const Color(0xFF6AA16F), leafHealth)!
        : Color.lerp(const Color(0xFF9BBF72), const Color(0xFF2F875B), leafHealth)!;
    final trunk = Paint()
      ..color = dry ? const Color(0xFF8B6546) : const Color(0xFF6E4C35)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (index == 0 || condition == 'seed_waiting') {
      canvas.drawOval(
        Rect.fromCenter(center: center.translate(0, -2), width: 22, height: 14),
        Paint()..color = const Color(0xFF785239),
      );
      if (condition != 'seed_waiting') {
        final arc = Path()
          ..moveTo(center.dx, center.dy - 6)
          ..quadraticBezierTo(center.dx + 4, center.dy - 18, center.dx + 14, center.dy - 21);
        canvas.drawPath(
          arc,
          Paint()
            ..color = const Color(0xFF4D8F5A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      }
      return;
    }

    final height = <double>[0, 52, 82, 112, 135, 154, 170][index];
    final top = center.translate(0, -height);
    trunk.strokeWidth = <double>[0, 5, 7, 10, 13, 16, 19][index];
    final trunkPath = Path()
      ..moveTo(center.dx, center.dy)
      ..cubicTo(
        center.dx - 5,
        center.dy - height * .34,
        center.dx + 5,
        center.dy - height * .68,
        top.dx,
        top.dy,
      );
    canvas.drawPath(trunkPath, trunk);

    if (index >= 2) {
      final branchCount = index + 1;
      trunk.strokeWidth = math.max(3, index * 1.5);
      for (var i = 0; i < branchCount; i++) {
        final side = i.isEven ? -1.0 : 1.0;
        final y = center.dy - height * (.32 + i * .09);
        final start = Offset(center.dx, y);
        final end = Offset(
          center.dx + side * (28 + index * 6 - i * 1.5),
          y - (23 + i * 2),
        );
        final branch = Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(
            start.dx + side * 13,
            start.dy - 5,
            end.dx,
            end.dy,
          );
        canvas.drawPath(branch, trunk);
      }
    }

    final leafPaint = Paint()..color = leafColor.withOpacity(condition == 'withered' ? .68 : .92);
    final leafCount = math.max(2, ((index * 8 + 2) * math.max(.25, leafHealth)).round());
    final crownWidth = 27.0 + index * 13;
    final crownHeight = 24.0 + index * 8;
    for (var i = 0; i < leafCount; i++) {
      final angle = i * 2.399963;
      final radius = math.sqrt((i + 1) / leafCount);
      final dx = math.cos(angle) * crownWidth * radius;
      final dy = math.sin(angle) * crownHeight * radius;
      final point = Offset(top.dx + dx, top.dy + 17 + dy);
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 13 + index, height: 7 + index * .45),
        leafPaint,
      );
      canvas.restore();
    }

    if (condition == 'withered') {
      final fallen = Paint()..color = const Color(0xFFB38346).withOpacity(.72);
      for (var i = 0; i < 6; i++) {
        final x = center.dx - 52 + i * 20.0;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, center.dy + 1 + (i % 2) * 5),
            width: 11,
            height: 5,
          ),
          fallen,
        );
      }
    }
  }

  int _stageIndex(String value) {
    const stages = <String>[
      'seed',
      'sprout',
      'sapling',
      'small_tree',
      'mature_tree',
      'great_tree',
      'ancient_tree',
    ];
    final index = stages.indexOf(value);
    return index < 0 ? 0 : index;
  }

  @override
  bool shouldRepaint(covariant ZhixingTreePainter oldDelegate) {
    return oldDelegate.stage != stage ||
        oldDelegate.condition != condition ||
        oldDelegate.health != health;
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MiniPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.8),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ResourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _ResourceButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(.09),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            children: <Widget>[
              Icon(icon, color: color),
              const SizedBox(height: 5),
              Text(
                '$label × $count',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text('点击养护', style: TextStyle(color: color.withOpacity(.8), fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;

  const _Metric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFB6C8BF), fontSize: 10),
        ),
      ],
    );
  }
}

class _ShopTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int price;
  final VoidCallback onTap;

  const _ShopTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Color(0xFFE2E9E4)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(.11),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5D8),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$price 金币',
            style: const TextStyle(color: Color(0xFF8A681D), fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
