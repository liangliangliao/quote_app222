import 'package:flutter/material.dart';

import '../pages/ai_prompt_settings_page.dart';
import 'woop_action_ai_service.dart';
import 'woop_action_dao.dart';
import 'woop_action_models.dart';
import 'woop_action_prompt_config.dart';

class WoopActionSceneLaunch {
  final String scene;
  final String template;
  const WoopActionSceneLaunch({required this.scene, required this.template});
}

class WoopActionFeatureGrid extends StatelessWidget {
  final VoidCallback onGuide;
  final VoidCallback onSceneLibrary;
  final VoidCallback onManualWizard;
  final VoidCallback onTargetFilter;
  final VoidCallback onProfile;
  final VoidCallback onMetrics;
  final VoidCallback onDailyCockpit;
  final VoidCallback onWishMap;
  final VoidCallback onRadar;
  final VoidCallback onPlanLibrary;
  final VoidCallback onReviewCenter;
  final VoidCallback onPromptCenter;

  const WoopActionFeatureGrid({
    super.key,
    required this.onGuide,
    required this.onSceneLibrary,
    required this.onManualWizard,
    required this.onTargetFilter,
    required this.onProfile,
    required this.onMetrics,
    required this.onDailyCockpit,
    required this.onWishMap,
    required this.onRadar,
    required this.onPlanLibrary,
    required this.onReviewCenter,
    required this.onPromptCenter,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_FeatureItem>[
      _FeatureItem('价值引导', '从原书思想到产品原则', Icons.menu_book_outlined, onGuide),
      _FeatureItem('场景工具库', '健康/学习/关系/情绪等', Icons.apps_outlined, onSceneLibrary),
      _FeatureItem('手动 WOOP', '不用 AI 也能创建完整卡', Icons.edit_note_outlined, onManualWizard),
      _FeatureItem('目标筛选器', '继续/调整/等待/放下', Icons.balance_outlined, onTargetFilter),
      _FeatureItem('个人化配置', '价值、领域、常见障碍', Icons.person_outline, onProfile),
      _FeatureItem('行动指标', '启动率/触发率/复盘率', Icons.insights_outlined, onMetrics),
      _FeatureItem('今日驾驶舱', 'Check-in 与执行日志', Icons.today_outlined, onDailyCockpit),
      _FeatureItem('愿望地图', '继续、调整、暂存、放下', Icons.map_outlined, onWishMap),
      _FeatureItem('障碍雷达', '识别高频内在障碍', Icons.radar_outlined, onRadar),
      _FeatureItem('if–then 计划库', '集中查看行动触发器', Icons.alt_route_outlined, onPlanLibrary),
      _FeatureItem('复盘中心', '失败/完成变系统信息', Icons.rate_review_outlined, onReviewCenter),
      _FeatureItem('Prompt 配置', '设置页统一配置中心', Icons.tune_outlined, onPromptCenter),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('完整产品工作台', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('不仅生成一张 WOOP 卡，还提供愿望筛选、场景入口、障碍模式、计划库与复盘闭环。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.05,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: items.map((item) => _FeatureTile(item: item)).toList(growable: false),
        ),
      ]),
    );
  }
}

class WoopActionGuidePage extends StatelessWidget {
  const WoopActionGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WOOP 价值引导')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: const <Widget>[
          _GuideHero(),
          SizedBox(height: 14),
          _GuideBlock(
            title: '1. 本模块的理论出处',
            icon: Icons.menu_book_outlined,
            body: '本模块基于 Gabriele Oettingen 的《Rethinking Positive Thinking: Inside the New Science of Motivation》。核心不是“保持正能量”，而是把愿望、最佳结果、现实障碍与 if–then 计划连接起来。',
          ),
          _GuideBlock(
            title: '2. 不是反对梦想，而是反对停在幻想里',
            icon: Icons.auto_awesome_outlined,
            body: '积极幻想可以安慰、探索需要、帮助用户看见自己真正渴望什么；但当愿望具有可行动性时，App 会继续引导用户进入心理对照，避免“感觉已经成功”的心理达成。',
          ),
          _GuideBlock(
            title: '3. 障碍是行动入口',
            icon: Icons.warning_amber_outlined,
            body: '模块会优先追问内在障碍：拖延、害怕失败、完美主义、讨好、焦虑、羞耻、分心、冲动、错误优先级等。外部困难不会被否认，但产品聚焦用户能调整的行动入口。',
          ),
          _GuideBlock(
            title: '4. 目标筛选：继续、调整、等待、放下',
            icon: Icons.alt_route_outlined,
            body: '心理对照不是让用户对所有愿望硬扛。愿望重要且可行时继续；重要但太大时调整；低可控时进入等待与安慰；不再属于用户或代价太高时帮助有尊严地放下。',
          ),
          _GuideBlock(
            title: '5. 失败不是人格问题，而是系统反馈',
            icon: Icons.refresh_outlined,
            body: '每次没做到，都要复盘：哪个障碍出现了？原 if–then 计划为什么没有触发？下一版计划如何更低门槛、更具体？',
          ),
        ],
      ),
    );
  }
}

class WoopActionSceneLibraryPage extends StatelessWidget {
  const WoopActionSceneLibraryPage({super.key});

  static const List<_SceneTemplate> templates = <_SceneTemplate>[
    _SceneTemplate('wish_clarify', '愿望澄清', '我想改变一件事，但还说不清楚。请帮我把它澄清成 24 小时、7 天、30 天三个可推进版本。', Icons.search_outlined, '用于“我想变好/变强/自由”这类模糊愿望。'),
    _SceneTemplate('positive_fantasy', '幻想转行动', '我正在想象一个很好的未来：。请先保留这个最佳结果，再帮我找出最关键的内在障碍。', Icons.auto_awesome_outlined, '防止停留在愿景板式满足感。'),
    _SceneTemplate('action_conversion', 'WOOP 行动', '我的愿望是：。最佳结果可能是：。现实中卡住我的地方是：。请生成完整 WOOP。', Icons.bolt_outlined, '标准 Wish/Outcome/Obstacle/Plan。'),
    _SceneTemplate('obstacle_diagnosis', '内在障碍诊断', '我想做：，但总说自己没时间/没状态/没资源。请帮我找真正的内在障碍。', Icons.warning_amber_outlined, '把表层借口转成可处理的心理触发点。'),
    _SceneTemplate('failure_review', '失败复盘', '我原计划是：。实际发生：。请把这次没做到当作反馈，帮我生成新版 WOOP。', Icons.refresh_outlined, '失败不是羞辱，而是下一版系统信息。'),
    _SceneTemplate('waiting_comfort', '等待与安慰', '我现在处于低可控等待中：。请帮我区分不可控部分、可控小行动和短期安慰。', Icons.hourglass_bottom_outlined, '适合等待结果、外部暂不可控场景。'),
    _SceneTemplate('large_goal', '大目标缩小', '我的长期大目标是：。请保留背后价值，并拆成 24 小时、7 天、30 天版本。', Icons.zoom_in_map_outlined, '防止宏大目标变成宏大幻想。'),
    _SceneTemplate('drop_or_adjust', '继续/调整/放下', '我长期追求这个目标：。现在很痛苦/耗竭。请判断继续、调整、暂存还是放下。', Icons.balance_outlined, '智慧配置生命能量。'),
    _SceneTemplate('health', '健康行为', '我想改善健康行为：。请聚焦情绪性进食/熬夜/运动启动/饮酒压力等内在障碍。', Icons.favorite_border, '睡眠、饮食、运动、康复等。'),
    _SceneTemplate('work_study', '学习工作', '我想完成学习/工作任务：。我最容易拖延或害怕评价。请生成 10—25 分钟启动任务。', Icons.work_outline, '论文、考试、项目、求职、深度工作。'),
    _SceneTemplate('relation', '关系沟通', '我想改善一段关系：。请只聚焦我可改变的表达、边界和行为。', Icons.forum_outlined, '亲密关系、家人、同事沟通。'),
    _SceneTemplate('emotion_impulse', '情绪与冲动', '我在这个情境会冲动/逃避：。请把冲动当成障碍触发点，生成替代动作。', Icons.self_improvement_outlined, '焦虑、愤怒、刷手机、消费、暴食等。'),
    _SceneTemplate('daily_24h', '24 小时 WOOP', '今天我最想推进的一件小事是：。请把第一步压到 5—15 分钟。', Icons.today_outlined, '日常短周期行动。'),
    _SceneTemplate('fantasy_safe_explore', '幻想安全区', '我现在只想先想象一个更好的结果：。请用幻想识别真实需要，再判断是否有可控小动作。', Icons.nights_stay_outlined, '保留幻想的安慰和探索价值。'),
    _SceneTemplate('obstacle_radar', '障碍雷达', '我最近反复卡在：。请总结高频内在障碍，并给我下周 if–then 模板。', Icons.radar_outlined, '从多张卡/多次失败中看模式。'),
    _SceneTemplate('weekly_review', '周复盘 / 愿望地图', '请帮我整理本周愿望地图：继续、调整、暂存、放下，并给下周 3 个 WOOP。', Icons.map_outlined, '长期愿望管理。'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WOOP 场景工具库')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: <Widget>[
          const _GuideBlock(
            title: '选择一个场景进入工作台',
            icon: Icons.apps_outlined,
            body: '场景层 Prompt 已接入设置页统一配置中心。这里不是简单模板，而是帮助 AI 选择不同的心理对照策略。',
          ),
          const SizedBox(height: 10),
          for (final t in templates) ...<Widget>[
            _SceneTemplateTile(template: t),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}


class WoopActionSceneFlowPage extends StatefulWidget {
  final _SceneTemplate template;
  const WoopActionSceneFlowPage({super.key, required this.template});

  @override
  State<WoopActionSceneFlowPage> createState() => _WoopActionSceneFlowPageState();
}

class _WoopActionSceneFlowPageState extends State<WoopActionSceneFlowPage> {
  final WoopActionDao _dao = WoopActionDao();
  final WoopActionAiService _ai = WoopActionAiService();
  final TextEditingController _coreCtrl = TextEditingController();
  final TextEditingController _bestCtrl = TextEditingController();
  final TextEditingController _realityCtrl = TextEditingController();
  final TextEditingController _obstacleCtrl = TextEditingController();
  final TextEditingController _boundaryCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _coreCtrl.text = widget.template.template;
  }

  @override
  void dispose() {
    _coreCtrl.dispose();
    _bestCtrl.dispose();
    _realityCtrl.dispose();
    _obstacleCtrl.dispose();
    _boundaryCtrl.dispose();
    super.dispose();
  }

  String _questionLabel() {
    switch (widget.template.scene) {
      case 'positive_fantasy':
      case 'fantasy_safe_explore':
        return '你正在想象的美好结果/画面';
      case 'failure_review':
        return '原计划与实际发生';
      case 'waiting_comfort':
        return '当前等待/低可控处境';
      case 'drop_or_adjust':
        return '长期追求但开始耗竭的目标';
      default:
        return '当前愿望或场景';
    }
  }

  String _buildInput() {
    return """场景：${widget.template.title}（${widget.template.scene}）
场景说明：${widget.template.description}
场景默认模板：${widget.template.template}

${_questionLabel()}：
${_coreCtrl.text.trim()}

愿望实现后的最佳结果/真实需要：
${_bestCtrl.text.trim()}

现实限制或外部背景：
${_realityCtrl.text.trim()}

我怀疑的内在障碍：
${_obstacleCtrl.text.trim()}

边界/注意事项：
${_boundaryCtrl.text.trim()}

请不要只给鼓励。请按该场景的心理对照策略，判断继续、调整、等待或放下，并生成可保存的结构化 WOOP 行动卡。""";
  }

  Future<void> _generate() async {
    if (_coreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先填写当前愿望或场景。'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _ai.generateCard(
        userInput: _buildInput(),
        scene: widget.template.scene,
        source: 'scene_flow',
        extraContext: '这是场景工具库中的真实交互工作流，不是简单模板填充。请优先使用用户填写的具体信息。',
      );
      final id = await _dao.upsertCard(result.card.copyWith(scene: widget.template.scene, source: 'scene_flow'));
      final saved = await _dao.getCard(id);
      if (!mounted) return;
      if (saved != null) Navigator.pop(context, saved);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.template.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          _GuideBlock(
            title: '场景工作流：${widget.template.title}',
            icon: widget.template.icon,
            body: '${widget.template.description}\n这一步会把场景信息、现实限制、内在障碍与个人化配置一起送入 WOOP AI，而不是只把模板回填到首页。',
          ),
          _TextBox(controller: _coreCtrl, label: _questionLabel(), hint: '把这件事说具体：发生在什么时候、什么对象、你真正想改变什么？'),
          _TextBox(controller: _bestCtrl, label: '最佳结果 / 真实需要', hint: '如果推进成功，最好的结果是什么？如果只是幻想，它揭示了什么需要？'),
          _TextBox(controller: _realityCtrl, label: '现实限制 / 外部背景', hint: '哪些部分不可控？哪些资源、时间、他人因素需要考虑？'),
          _TextBox(controller: _obstacleCtrl, label: '关键内在障碍猜测', hint: '拖延、完美主义、焦虑、羞耻、讨好、分心、冲动、害怕失败等。'),
          _TextBox(controller: _boundaryCtrl, label: '边界 / 注意事项', hint: '例如：不要把外部结构性困难全归咎于我；涉及健康请提醒专业帮助。'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _generate,
            icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_fix_high_outlined),
            label: Text(_busy ? '正在生成场景 WOOP…' : '生成并保存场景 WOOP'),
          ),
        ],
      ),
    );
  }
}

class WoopActionWishMapPage extends StatefulWidget {
  final ValueChanged<WoopActionCard>? onOpenCard;
  const WoopActionWishMapPage({super.key, this.onOpenCard});

  @override
  State<WoopActionWishMapPage> createState() => _WoopActionWishMapPageState();
}

class _WoopActionWishMapPageState extends State<WoopActionWishMapPage> {
  final WoopActionDao _dao = WoopActionDao();
  bool _loading = true;
  List<WoopActionCard> _cards = <WoopActionCard>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cards = await _dao.listCards(limit: 240);
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _loading = false;
    });
  }

  Future<void> _setStatus(WoopActionCard card, String status) async {
    await _dao.updateStatus(card.id, status);
    await _load();
  }

  List<WoopActionCard> _byStatus(String status) => _cards.where((c) => c.status == status).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('愿望地图'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: '行动中'),
              Tab(text: '已完成'),
              Tab(text: '暂存'),
              Tab(text: '已放下'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: <Widget>[
                  _WishMapList(cards: _byStatus('active'), onOpen: widget.onOpenCard, onStatus: _setStatus),
                  _WishMapList(cards: _byStatus('done'), onOpen: widget.onOpenCard, onStatus: _setStatus),
                  _WishMapList(cards: _cards.where((c) => c.status == 'paused' || c.status == 'archived').toList(growable: false), onOpen: widget.onOpenCard, onStatus: _setStatus),
                  _WishMapList(cards: _byStatus('dropped'), onOpen: widget.onOpenCard, onStatus: _setStatus),
                ],
              ),
      ),
    );
  }
}

class WoopActionObstacleRadarPage extends StatefulWidget {
  final ValueChanged<WoopActionCard>? onOpenCard;
  const WoopActionObstacleRadarPage({super.key, this.onOpenCard});

  @override
  State<WoopActionObstacleRadarPage> createState() => _WoopActionObstacleRadarPageState();
}

class _WoopActionObstacleRadarPageState extends State<WoopActionObstacleRadarPage> {
  final WoopActionDao _dao = WoopActionDao();
  final WoopActionAiService _ai = WoopActionAiService();
  bool _loading = true;
  bool _generating = false;
  Map<String, int> _tagCounts = const <String, int>{};
  List<WoopActionCard> _cards = <WoopActionCard>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tags = await _dao.obstacleTagCounts(limit: 240);
    final cards = await _dao.listCards(limit: 80);
    if (!mounted) return;
    setState(() {
      _tagCounts = tags;
      _cards = cards;
      _loading = false;
    });
  }

  Future<void> _generateRadarCard() async {
    setState(() => _generating = true);
    try {
      final history = await _dao.historySummaryJson(limit: 120);
      final result = await _ai.generateCard(
        userInput: '请基于我的 WOOP 历史记录生成障碍雷达分析：识别高频内在障碍、表层借口与真实障碍的差异，并给出未来 7 天最该使用的 3 条 if–then 模板。',
        scene: 'obstacle_radar',
        source: 'obstacle_radar_page',
        extraContext: history,
      );
      final id = await _dao.upsertCard(result.card.copyWith(scene: 'obstacle_radar'));
      final saved = await _dao.getCard(id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已生成障碍雷达分析卡'), behavior: SnackBarBehavior.floating));
      if (saved != null) widget.onOpenCard?.call(saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('生成失败：$e'), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final max = _tagCounts.values.isEmpty ? 1 : _tagCounts.values.reduce((a, b) => a > b ? a : b);
    return Scaffold(
      appBar: AppBar(title: const Text('障碍雷达')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: <Widget>[
                const _GuideBlock(
                  title: '从“我做不到”变成“系统哪里没覆盖”',
                  icon: Icons.radar_outlined,
                  body: '障碍雷达统计你的高频内在障碍，并帮助下一版 if–then 计划更精准。它对应原书中“负面反馈可以被心理对照利用”的思想。',
                ),
                const SizedBox(height: 12),
                if (_tagCounts.isEmpty)
                  const _EmptyPanel(text: '还没有足够的障碍标签。先生成并复盘几张 WOOP 卡，障碍雷达会逐渐变得有用。')
                else
                  for (final entry in _tagCounts.entries) ...<Widget>[
                    Row(children: <Widget>[
                      SizedBox(width: 104, child: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                      Expanded(child: LinearProgressIndicator(value: entry.value / max, minHeight: 8, backgroundColor: const Color(0xFFF3F4F6))),
                      const SizedBox(width: 8),
                      Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ]),
                    const SizedBox(height: 12),
                  ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _generating ? null : _generateRadarCard,
                  icon: _generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_fix_high_outlined),
                  label: Text(_generating ? '正在生成 AI 障碍雷达…' : '基于历史生成 AI 障碍雷达分析卡'),
                ),
                const SizedBox(height: 18),
                Text('最近卡片样本 ${_cards.length} 张', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                for (final card in _cards.take(12)) ...<Widget>[
                  _CompactCardLine(card: card, onTap: () => widget.onOpenCard?.call(card)),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

class WoopActionPlanLibraryPage extends StatefulWidget {
  final ValueChanged<WoopActionCard>? onOpenCard;
  const WoopActionPlanLibraryPage({super.key, this.onOpenCard});

  @override
  State<WoopActionPlanLibraryPage> createState() => _WoopActionPlanLibraryPageState();
}

class _WoopActionPlanLibraryPageState extends State<WoopActionPlanLibraryPage> {
  final WoopActionDao _dao = WoopActionDao();
  bool _loading = true;
  List<WoopActionCard> _cards = <WoopActionCard>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cards = await _dao.listCards(limit: 220);
    if (!mounted) return;
    setState(() {
      _cards = cards.where((c) => c.planText.trim().isNotEmpty || c.firstAction.trim().isNotEmpty).toList(growable: false);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('if–then 计划库')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: <Widget>[
                const _GuideBlock(
                  title: '让障碍成为行动按钮',
                  icon: Icons.alt_route_outlined,
                  body: '这里集中查看所有“如果—那么”计划。真正的行动不是每次临时靠意志力，而是提前给软弱、焦虑、冲动、拖延时的自己铺路。',
                ),
                const SizedBox(height: 12),
                if (_cards.isEmpty)
                  const _EmptyPanel(text: '还没有 if–then 计划。先生成一张 WOOP 行动卡。')
                else
                  for (final card in _cards) ...<Widget>[
                    _PlanLibraryTile(card: card, onTap: () => widget.onOpenCard?.call(card)),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
    );
  }
}

class WoopActionPromptCoveragePage extends StatelessWidget {
  const WoopActionPromptCoveragePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WOOP Prompt 覆盖检查')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: <Widget>[
          const _GuideBlock(
            title: '统一配置中心',
            icon: Icons.tune_outlined,
            body: '本模块所有全局价值层、场景层、输出格式 Prompt 都注册在设置页 AI 提示词统一配置中心，保存后下一次生成立即生效。',
          ),
          const SizedBox(height: 12),
          for (final id in WoopActionPromptConfig.allIds) ...<Widget>[
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Color(0xFF059669)),
              title: Text(id, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('可在设置页统一配置中心编辑 / 导出 / 导入 / 恢复默认'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiPromptSettingsPage(initialModuleId: WoopActionPromptConfig.moduleId, initialPromptId: id))),
            ),
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _WishMapList extends StatelessWidget {
  final List<WoopActionCard> cards;
  final ValueChanged<WoopActionCard>? onOpen;
  final Future<void> Function(WoopActionCard card, String status) onStatus;
  const _WishMapList({required this.cards, required this.onOpen, required this.onStatus});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('这里还没有愿望卡。')));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: cards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final card = cards[index];
        return _WishMapCard(card: card, onOpen: onOpen, onStatus: onStatus);
      },
    );
  }
}

class _WishMapCard extends StatelessWidget {
  final WoopActionCard card;
  final ValueChanged<WoopActionCard>? onOpen;
  final Future<void> Function(WoopActionCard card, String status) onStatus;
  const _WishMapCard({required this.card, required this.onOpen, required this.onStatus});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onOpen?.call(card),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(card.title.trim().isEmpty ? card.wish : card.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('方向：${_directionLabel(card.direction)} · 重要性 ${_levelLabel(card.importance)} · 可行性 ${_levelLabel(card.feasibility)} · 可控性 ${_levelLabel(card.controllability)} · 代价 ${_levelLabel(card.cost)}', style: const TextStyle(color: Color(0xFF6B7280), height: 1.35)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            OutlinedButton(onPressed: () => onStatus(card, 'active'), child: const Text('继续')),
            OutlinedButton(onPressed: () => onStatus(card, 'paused'), child: const Text('暂存')),
            OutlinedButton(onPressed: () => onStatus(card, 'dropped'), child: const Text('放下')),
            OutlinedButton(onPressed: () => onStatus(card, 'done'), child: const Text('完成')),
          ]),
        ]),
      ),
    );
  }
}

class _SceneTemplateTile extends StatelessWidget {
  final _SceneTemplate template;
  const _SceneTemplateTile({required this.template});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final saved = await Navigator.of(context).push<WoopActionCard>(
          MaterialPageRoute(builder: (_) => WoopActionSceneFlowPage(template: template)),
        );
        if (saved != null) Navigator.pop(context, saved);
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(14)), child: Icon(template.icon, color: const Color(0xFF4F46E5))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(template.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(template.description, style: const TextStyle(color: Color(0xFF6B7280), height: 1.35)),
            const SizedBox(height: 8),
            Text(template.template, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151), height: 1.35)),
          ])),
          const Icon(Icons.chevron_right_outlined),
        ]),
      ),
    );
  }
}

class _PlanLibraryTile extends StatelessWidget {
  final WoopActionCard card;
  final VoidCallback onTap;
  const _PlanLibraryTile({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(card.wish, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
            child: Text(card.planText.isEmpty ? card.firstAction : card.planText, style: const TextStyle(height: 1.45, color: Color(0xFF111827), fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Text('障碍：${card.obstacle}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6B7280))),
        ]),
      ),
    );
  }
}

class _CompactCardLine extends StatelessWidget {
  final WoopActionCard card;
  final VoidCallback onTap;
  const _CompactCardLine({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
      title: Text(card.wish, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(card.obstacle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_outlined),
      onTap: onTap,
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final _FeatureItem item;
  const _FeatureTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Row(children: <Widget>[
          Icon(item.icon, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280))),
          ])),
        ]),
      ),
    );
  }
}

class _GuideHero extends StatelessWidget {
  const _GuideHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: const LinearGradient(colors: <Color>[Color(0xFF111827), Color(0xFF4338CA)])),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text('梦想给方向，现实给力量，障碍给入口，计划让行动发生。', style: TextStyle(color: Colors.white, fontSize: 20, height: 1.4, fontWeight: FontWeight.w900)),
        SizedBox(height: 10),
        Text('这不是目标打卡工具，而是把积极幻想转成现实行动的 AI 自我调节系统。', style: TextStyle(color: Color(0xFFE0E7FF), height: 1.45)),
      ]),
    );
  }
}

class _GuideBlock extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  const _GuideBlock({required this.title, required this.body, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[Icon(icon, color: const Color(0xFF4F46E5)), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)))]),
        const SizedBox(height: 10),
        Text(body, style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
      ]),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String text;
  const _EmptyPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Text(text, style: const TextStyle(color: Color(0xFF6B7280), height: 1.45)),
    );
  }
}

class _FeatureItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _FeatureItem(this.title, this.subtitle, this.icon, this.onTap);
}

class _SceneTemplate {
  final String scene;
  final String title;
  final String template;
  final IconData icon;
  final String description;
  const _SceneTemplate(this.scene, this.title, this.template, this.icon, this.description);
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

class WoopActionManualWizardPage extends StatefulWidget {
  final ValueChanged<WoopActionCard>? onSaved;
  const WoopActionManualWizardPage({super.key, this.onSaved});

  @override
  State<WoopActionManualWizardPage> createState() => _WoopActionManualWizardPageState();
}

class _WoopActionManualWizardPageState extends State<WoopActionManualWizardPage> {
  final WoopActionDao _dao = WoopActionDao();
  final TextEditingController _wishCtrl = TextEditingController();
  final TextEditingController _outcomeCtrl = TextEditingController();
  final TextEditingController _obstacleCtrl = TextEditingController();
  final TextEditingController _ifCtrl = TextEditingController();
  final TextEditingController _thenCtrl = TextEditingController();
  final TextEditingController _firstCtrl = TextEditingController();
  String _importance = 'high';
  String _feasibility = 'medium';
  String _controllability = 'medium';
  String _cost = 'medium';
  String _belongs = 'clear';
  String _direction = 'continue';
  bool _saving = false;

  @override
  void dispose() {
    _wishCtrl.dispose();
    _outcomeCtrl.dispose();
    _obstacleCtrl.dispose();
    _ifCtrl.dispose();
    _thenCtrl.dispose();
    _firstCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final wish = _wishCtrl.text.trim();
    if (wish.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请至少填写愿望 W。'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final obstacle = _obstacleCtrl.text.trim();
      final card = WoopActionCard(
        createdAtMs: now,
        updatedAtMs: now,
        source: 'manual_wizard',
        scene: 'manual_woop',
        title: wish.length > 18 ? '${wish.substring(0, 18)}…' : wish,
        rawInput: wish,
        currentJudgement: '这是一张手动创建的 WOOP 行动卡。请用复盘记录检验障碍和 if–then 是否真实有效。',
        wish: wish,
        outcome: _outcomeCtrl.text.trim(),
        obstacle: obstacle,
        obstacleType: obstacle.isEmpty ? '待识别' : '手动障碍',
        obstacleTags: obstacle.isEmpty ? const <String>['待识别'] : const <String>['手动障碍'],
        planIf: _ifCtrl.text.trim().isEmpty ? obstacle : _ifCtrl.text.trim(),
        planThen: _thenCtrl.text.trim(),
        firstAction: _firstCtrl.text.trim(),
        reviewQuestion: '这张手动 WOOP 的障碍是否真实出现？if–then 行动是否足够小、足够具体？',
        reminder: '手动创建后建议至少做一次完成/障碍复盘，验证计划是否覆盖真实障碍。',
        feasibility: _feasibility,
        importance: _importance,
        controllability: _controllability,
        cost: _cost,
        belongsToUser: _belongs,
        direction: _direction,
        status: 'active',
        provider: 'manual',
        modelLabel: '手动 WOOP 向导',
        fromFallback: true,
      );
      final id = await _dao.upsertCard(card);
      final saved = await _dao.getCard(id) ?? card.copyWith(id: id);
      if (!mounted) return;
      widget.onSaved?.call(saved);
      Navigator.pop(context, saved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('手动 WOOP 向导')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          const _GuideBlock(
            title: '不用 AI 也能创建完整 WOOP',
            icon: Icons.edit_note_outlined,
            body: '这页把产品从“AI 生成器”补成“真实自我调节工具”：用户可以自己填写 W/O/O/P，再用复盘验证障碍与计划。',
          ),
          _TextBox(controller: _wishCtrl, label: 'W｜愿望', hint: '例如：本周完成论文第一稿'),
          _TextBox(controller: _outcomeCtrl, label: 'O｜最佳结果', hint: '例如：我会从焦虑中出来，看到自己真正推进了'),
          _TextBox(controller: _obstacleCtrl, label: 'O｜关键内在障碍', hint: '例如：害怕写得不好，所以迟迟不开始'),
          _TextBox(controller: _ifCtrl, label: 'P｜如果触发条件', hint: '例如：我开始担心写得不好'),
          _TextBox(controller: _thenCtrl, label: 'P｜那么行动', hint: '例如：打开文档，只写 10 分钟粗糙版本'),
          _TextBox(controller: _firstCtrl, label: '今日第一步', hint: '例如：今晚 8:30 写第一个小标题下 5 句话'),
          const SizedBox(height: 8),
          _SegmentPicker(title: '重要性', value: _importance, onChanged: (v) => setState(() => _importance = v)),
          _SegmentPicker(title: '可行性', value: _feasibility, onChanged: (v) => setState(() => _feasibility = v)),
          _SegmentPicker(title: '可控性', value: _controllability, onChanged: (v) => setState(() => _controllability = v)),
          _SegmentPicker(title: '代价', value: _cost, onChanged: (v) => setState(() => _cost = v)),
          _BelongsPicker(value: _belongs, onChanged: (v) => setState(() => _belongs = v)),
          _DirectionPicker(value: _direction, onChanged: (v) => setState(() => _direction = v)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
            label: Text(_saving ? '正在保存…' : '保存手动 WOOP 卡'),
          ),
        ],
      ),
    );
  }
}

class WoopActionTargetFilterPage extends StatefulWidget {
  final ValueChanged<WoopActionCard>? onOpenCard;
  const WoopActionTargetFilterPage({super.key, this.onOpenCard});

  @override
  State<WoopActionTargetFilterPage> createState() => _WoopActionTargetFilterPageState();
}

class _WoopActionTargetFilterPageState extends State<WoopActionTargetFilterPage> {
  final WoopActionDao _dao = WoopActionDao();
  final WoopActionAiService _ai = WoopActionAiService();
  final TextEditingController _goalCtrl = TextEditingController();
  String _importance = 'high';
  String _feasibility = 'medium';
  String _controllability = 'medium';
  String _cost = 'medium';
  String _belongs = 'clear';
  bool _busy = false;

  @override
  void dispose() {
    _goalCtrl.dispose();
    super.dispose();
  }

  String get _direction {
    if (_belongs == 'probably_not' || _cost == 'high' && _importance != 'high') return 'drop';
    if (_controllability == 'low') return 'wait';
    if (_feasibility == 'low' || _cost == 'high' || _belongs == 'unclear') return 'adjust';
    return 'continue';
  }

  Future<void> _generate() async {
    final goal = _goalCtrl.text.trim();
    if (goal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先写下要筛选的目标。'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _busy = true);
    try {
      final input = '''请做目标筛选：
目标：$goal
我的初步评分：重要性 $_importance，可行性 $_feasibility，可控性 $_controllability，代价 $_cost，是否属于我 $_belongs。
请根据《Rethinking Positive Thinking》的心理对照思想，判断继续、调整、等待还是放下，并生成下一步 WOOP。''';
      final result = await _ai.generateCard(userInput: input, scene: 'drop_or_adjust', source: 'target_filter');
      final id = await _dao.upsertCard(result.card.copyWith(
        direction: _direction,
        importance: _importance,
        feasibility: _feasibility,
        controllability: _controllability,
        cost: _cost,
        belongsToUser: _belongs,
      ));
      final saved = await _dao.getCard(id);
      if (!mounted) return;
      if (saved != null) widget.onOpenCard?.call(saved);
      Navigator.pop(context, saved);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final direction = _direction;
    return Scaffold(
      appBar: AppBar(title: const Text('目标筛选器')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          const _GuideBlock(
            title: '不是所有愿望都要硬扛',
            icon: Icons.balance_outlined,
            body: '这里把“重要性、可行性、可控性、代价、归属感”显性化，帮助用户判断继续、调整、等待或有尊严地放下。',
          ),
          _TextBox(controller: _goalCtrl, label: '要筛选的愿望/目标', hint: '例如：三个月内彻底转行成功'),
          _SegmentPicker(title: '重要性', value: _importance, onChanged: (v) => setState(() => _importance = v)),
          _SegmentPicker(title: '可行性', value: _feasibility, onChanged: (v) => setState(() => _feasibility = v)),
          _SegmentPicker(title: '可控性', value: _controllability, onChanged: (v) => setState(() => _controllability = v)),
          _SegmentPicker(title: '代价', value: _cost, onChanged: (v) => setState(() => _cost = v)),
          _BelongsPicker(value: _belongs, onChanged: (v) => setState(() => _belongs = v)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Text('当前建议方向：${_directionText(direction)}\n${_directionReason(direction)}', style: const TextStyle(height: 1.5, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _generate,
            icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_fix_high_outlined),
            label: Text(_busy ? '正在生成筛选结果…' : '生成目标筛选 WOOP'),
          ),
        ],
      ),
    );
  }
}

class WoopActionDailyCockpitPage extends StatefulWidget {
  final ValueChanged<WoopActionCard>? onOpenCard;
  const WoopActionDailyCockpitPage({super.key, this.onOpenCard});

  @override
  State<WoopActionDailyCockpitPage> createState() => _WoopActionDailyCockpitPageState();
}

class _WoopActionDailyCockpitPageState extends State<WoopActionDailyCockpitPage> {
  final WoopActionDao _dao = WoopActionDao();
  final WoopActionAiService _ai = WoopActionAiService();
  bool _loading = true;
  bool _busy = false;
  List<WoopActionCard> _activeCards = <WoopActionCard>[];
  List<WoopActionDailyCheckIn> _checkIns = <WoopActionDailyCheckIn>[];
  List<WoopActionPlanLog> _logs = <WoopActionPlanLog>[];
  String _energy = 'medium';
  final TextEditingController _moodCtrl = TextEditingController();
  final TextEditingController _mainWishCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _moodCtrl.dispose();
    _mainWishCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    final active = await _dao.listCards(status: 'active', limit: 80);
    final checkins = await _dao.listDailyCheckIns(limit: 20);
    final logs = await _dao.listPlanLogs(limit: 30);
    if (!mounted) return;
    setState(() {
      _activeCards = active;
      _checkIns = checkins;
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _saveCheckIn() async {
    await _dao.addDailyCheckIn(WoopActionDailyCheckIn(
      dateKey: _todayKey,
      energy: _energy,
      mood: _moodCtrl.text.trim(),
      mainWish: _mainWishCtrl.text.trim(),
      note: _noteCtrl.text.trim(),
    ));
    _moodCtrl.clear();
    _mainWishCtrl.clear();
    _noteCtrl.clear();
    await _load();
  }

  Future<void> _logPlan(WoopActionCard card, String result) async {
    await _dao.addPlanLog(WoopActionPlanLog(
      cardId: card.id,
      triggerText: card.planIf,
      actionText: card.planThen.isEmpty ? card.firstAction : card.planThen,
      result: result,
      note: result == 'done' ? '今日驾驶舱快速记录：计划已执行。' : '今日驾驶舱快速记录：计划未完全执行，需要复盘障碍。',
    ));
    await _load();
  }

  Future<void> _generateDaily() async {
    setState(() => _busy = true);
    try {
      final contextJson = await _dao.dailyCockpitJson(limit: 80);
      final result = await _ai.generateCard(
        userInput: '请基于今日驾驶舱状态，为今天生成一个 24 小时 WOOP：只选一个主线愿望、一个关键障碍和一个 5—15 分钟第一步。',
        scene: 'daily_24h',
        source: 'daily_cockpit',
        extraContext: contextJson,
      );
      final id = await _dao.upsertCard(result.card.copyWith(scene: 'daily_24h', status: 'active'));
      final saved = await _dao.getCard(id);
      await _load();
      if (saved != null) widget.onOpenCard?.call(saved);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('今日 WOOP 驾驶舱')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: <Widget>[
                  const _GuideBlock(
                    title: '每天只让一个障碍变成行动按钮',
                    icon: Icons.today_outlined,
                    body: '今日驾驶舱不是待办清单，而是把今天最重要的愿望压缩为一个 if–then 计划，并记录计划有没有真正触发。',
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                      const Text('今日 Check-in', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      _SegmentPicker(title: '今日能量', value: _energy, onChanged: (v) => setState(() => _energy = v)),
                      _TextBox(controller: _moodCtrl, label: '情绪/状态', hint: '例如：有点焦虑，但想推进一点'),
                      _TextBox(controller: _mainWishCtrl, label: '今天主线愿望', hint: '例如：完成报告第一版'),
                      _TextBox(controller: _noteCtrl, label: '备注', hint: '今天最可能出现的障碍或现实限制'),
                      FilledButton.icon(onPressed: _saveCheckIn, icon: const Icon(Icons.save_outlined), label: const Text('保存今日 Check-in')),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _generateDaily,
                    icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_outlined),
                    label: Text(_busy ? '正在生成今日 WOOP…' : '基于历史生成今日 24 小时 WOOP'),
                  ),
                  const SizedBox(height: 18),
                  Text('行动中计划 ${_activeCards.length} 张', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (_activeCards.isEmpty)
                    const _EmptyPanel(text: '暂无行动中 WOOP 卡。可以先生成今日 24 小时 WOOP。')
                  else
                    for (final card in _activeCards.take(8)) ...<Widget>[
                      _DailyPlanTile(card: card, onOpen: () => widget.onOpenCard?.call(card), onLog: (result) => _logPlan(card, result)),
                      const SizedBox(height: 10),
                    ],
                  const SizedBox(height: 18),
                  Text('最近执行日志 ${_logs.length} 条', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (_logs.isEmpty) const _EmptyPanel(text: '还没有 if–then 执行日志。') else for (final log in _logs.take(10)) _PlanLogLine(log: log),
                  const SizedBox(height: 18),
                  Text('最近 Check-in ${_checkIns.length} 条', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (_checkIns.isEmpty) const _EmptyPanel(text: '还没有每日 Check-in。') else for (final c in _checkIns.take(8)) _CheckInLine(checkIn: c),
                ],
              ),
            ),
    );
  }
}

class WoopActionReviewCenterPage extends StatefulWidget {
  final ValueChanged<WoopActionCard>? onOpenCard;
  const WoopActionReviewCenterPage({super.key, this.onOpenCard});

  @override
  State<WoopActionReviewCenterPage> createState() => _WoopActionReviewCenterPageState();
}

class _WoopActionReviewCenterPageState extends State<WoopActionReviewCenterPage> {
  final WoopActionDao _dao = WoopActionDao();
  final WoopActionAiService _ai = WoopActionAiService();
  bool _loading = true;
  bool _busy = false;
  List<WoopActionReview> _reviews = <WoopActionReview>[];
  List<WoopActionPlanLog> _logs = <WoopActionPlanLog>[];
  List<WoopActionCard> _cards = <WoopActionCard>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reviews = await _dao.listRecentReviews(limit: 80);
    final logs = await _dao.listPlanLogs(limit: 80);
    final cards = await _dao.listCards(limit: 120);
    if (!mounted) return;
    setState(() {
      _reviews = reviews;
      _logs = logs;
      _cards = cards;
      _loading = false;
    });
  }

  Future<void> _generateWeeklyReview() async {
    setState(() => _busy = true);
    try {
      final history = await _dao.historySummaryJson(limit: 160);
      final daily = await _dao.dailyCockpitJson(limit: 100);
      final result = await _ai.generateCard(
        userInput: '请基于本周 WOOP 卡、复盘和 if–then 执行日志，生成周复盘/愿望地图：继续、调整、暂存、放下，并给下周 3 条 if–then。',
        scene: 'weekly_review',
        source: 'review_center',
        extraContext: '$history\n$daily',
      );
      final id = await _dao.upsertCard(result.card.copyWith(scene: 'weekly_review', status: 'active'));
      final saved = await _dao.getCard(id);
      await _load();
      if (saved != null) widget.onOpenCard?.call(saved);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('复盘中心')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                const _GuideBlock(
                  title: '把失败和完成都变成下一版系统信息',
                  icon: Icons.rate_review_outlined,
                  body: '集中查看复盘、执行日志和愿望卡，生成周复盘/愿望地图。这里对应原书中“心理对照帮助利用负面反馈”的机制。',
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _generateWeeklyReview,
                  icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_fix_high_outlined),
                  label: Text(_busy ? '正在生成周复盘…' : '生成周复盘 / 愿望地图卡'),
                ),
                const SizedBox(height: 18),
                Text('最近 WOOP 卡 ${_cards.length} 张', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                for (final card in _cards.take(10)) ...<Widget>[_CompactCardLine(card: card, onTap: () => widget.onOpenCard?.call(card)), const SizedBox(height: 8)],
                const SizedBox(height: 18),
                Text('最近复盘 ${_reviews.length} 条', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (_reviews.isEmpty) const _EmptyPanel(text: '还没有完成/障碍复盘。') else for (final r in _reviews.take(12)) _ReviewCenterLine(review: r),
                const SizedBox(height: 18),
                Text('最近 if–then 执行日志 ${_logs.length} 条', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (_logs.isEmpty) const _EmptyPanel(text: '还没有执行日志。') else for (final log in _logs.take(12)) _PlanLogLine(log: log),
              ],
            ),
    );
  }
}


class WoopActionProfilePage extends StatefulWidget {
  const WoopActionProfilePage({super.key});

  @override
  State<WoopActionProfilePage> createState() => _WoopActionProfilePageState();
}

class _WoopActionProfilePageState extends State<WoopActionProfilePage> {
  final WoopActionDao _dao = WoopActionDao();
  final TextEditingController _valuesCtrl = TextEditingController();
  final TextEditingController _domainsCtrl = TextEditingController();
  final TextEditingController _obstaclesCtrl = TextEditingController();
  final TextEditingController _windowCtrl = TextEditingController();
  final TextEditingController _boundaryCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _valuesCtrl.dispose();
    _domainsCtrl.dispose();
    _obstaclesCtrl.dispose();
    _windowCtrl.dispose();
    _boundaryCtrl.dispose();
    super.dispose();
  }

  List<String> _lines(String text) => text
      .split(RegExp(r'[,，;；\n]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  Future<void> _load() async {
    final profile = await _dao.getProfile();
    if (!mounted) return;
    setState(() {
      _valuesCtrl.text = profile.userValues;
      _domainsCtrl.text = profile.lifeDomains.join('\n');
      _obstaclesCtrl.text = profile.commonObstacles.join('\n');
      _windowCtrl.text = profile.preferredActionWindow;
      _boundaryCtrl.text = profile.supportBoundary;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _dao.saveProfile(WoopActionProfile(
        userValues: _valuesCtrl.text.trim(),
        lifeDomains: _lines(_domainsCtrl.text),
        commonObstacles: _lines(_obstaclesCtrl.text),
        preferredActionWindow: _windowCtrl.text.trim(),
        supportBoundary: _boundaryCtrl.text.trim(),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存 WOOP 个人化配置。'), behavior: SnackBarBehavior.floating));
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WOOP 个人化配置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                const _GuideBlock(
                  title: '让 AI 不只生成通用 WOOP，而是贴合你的长期价值和常见障碍',
                  icon: Icons.person_outline,
                  body: '这里保存的内容会作为 WOOP 行动引擎独立上下文注入 AI Prompt，不进入其他模块。用于覆盖产品方案中的“长期愿望地图、内在障碍模式、个人边界与专业帮助提醒”。',
                ),
                _TextBox(controller: _valuesCtrl, label: '长期价值 / 真正重视的方向', hint: '例如：健康、创造、家庭连接、自由、稳定、学习成长'),
                _TextBox(controller: _domainsCtrl, label: '主要生活领域（每行一个）', hint: '健康\n学习\n工作\n关系\n情绪管理'),
                _TextBox(controller: _obstaclesCtrl, label: '常见内在障碍（每行一个）', hint: '完美主义\n报复性熬夜\n害怕评价\n分心逃避'),
                _TextBox(controller: _windowCtrl, label: '偏好的最小行动窗口', hint: '例如：5 分钟启动；晚上 8:30 前；早上先做最难任务'),
                _TextBox(controller: _boundaryCtrl, label: '边界 / 专业帮助提醒', hint: '例如：不要把外部结构性困难完全归因于我；健康问题提醒看医生'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                  label: Text(_saving ? '正在保存…' : '保存个人化配置'),
                ),
              ],
            ),
    );
  }
}

class WoopActionMetricsPage extends StatefulWidget {
  const WoopActionMetricsPage({super.key});

  @override
  State<WoopActionMetricsPage> createState() => _WoopActionMetricsPageState();
}

class _WoopActionMetricsPageState extends State<WoopActionMetricsPage> {
  final WoopActionDao _dao = WoopActionDao();
  bool _loading = true;
  Map<String, int> _counts = const <String, int>{};
  List<WoopActionPlanLog> _logs = <WoopActionPlanLog>[];
  List<WoopActionReview> _reviews = <WoopActionReview>[];
  List<WoopActionDailyCheckIn> _checkIns = <WoopActionDailyCheckIn>[];
  Map<String, int> _tags = const <String, int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final counts = await _dao.counts();
    final logs = await _dao.listPlanLogs(limit: 200);
    final reviews = await _dao.listRecentReviews(limit: 200);
    final checkIns = await _dao.listDailyCheckIns(limit: 120);
    final tags = await _dao.obstacleTagCounts(limit: 240);
    if (!mounted) return;
    setState(() {
      _counts = counts;
      _logs = logs;
      _reviews = reviews;
      _checkIns = checkIns;
      _tags = tags;
      _loading = false;
    });
  }

  String _percent(int a, int b) {
    if (b <= 0) return '0%';
    return '${((a / b) * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final doneLogs = _logs.where((l) => l.result == 'done').length;
    final missedLogs = _logs.where((l) => l.result != 'done').length;
    final totalCards = _counts['total'] ?? 0;
    final reviewedCardsRate = _percent(_reviews.map((r) => r.cardId).toSet().length, totalCards);
    return Scaffold(
      appBar: AppBar(title: const Text('WOOP 行动指标')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: <Widget>[
                  const _GuideBlock(
                    title: '衡量“现实行动”，而不是衡量情绪鸡血',
                    icon: Icons.insights_outlined,
                    body: '产品方案强调第一行动启动率、复盘率、障碍识别深度和反馈利用度。这里把 WOOP 卡、if–then 执行日志、复盘与 Check-in 统一为可观察指标。',
                  ),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.55,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: <Widget>[
                      _MetricTile(title: 'WOOP 卡总数', value: '$totalCards', caption: '愿望进入行动系统'),
                      _MetricTile(title: '行动中', value: '${_counts['active'] ?? 0}', caption: '当前投入目标'),
                      _MetricTile(title: '完成卡', value: '${_counts['done'] ?? 0}', caption: '产生现实证据'),
                      _MetricTile(title: '复盘覆盖率', value: reviewedCardsRate, caption: '不是失败羞辱，而是系统学习'),
                      _MetricTile(title: 'if–then 触发率', value: _percent(doneLogs, _logs.length), caption: '$doneLogs 已执行 / $missedLogs 未触发'),
                      _MetricTile(title: '每日 Check-in', value: '${_checkIns.length}', caption: 'WOOP 作为生活伴侣'),
                      _MetricTile(title: '行动实验', value: '${_counts['experiments'] ?? 0}', caption: '验证 if–then 是否覆盖真实障碍'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('高频内在障碍', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (_tags.isEmpty)
                    const _EmptyPanel(text: '还没有足够的障碍标签。创建几张 WOOP 卡并复盘后，这里会显示模式。')
                  else
                    for (final e in _tags.entries) ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: const Icon(Icons.radar_outlined, color: Color(0xFF4F46E5)),
                      title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                      trailing: Text('${e.value} 次', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  const SizedBox(height: 18),
                  const Text('改进建议', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  _EmptyPanel(text: _logs.isEmpty
                      ? '下一步：进入“今日驾驶舱”或卡片详情页，开始记录 if–then 是否真实触发。'
                      : doneLogs < missedLogs
                          ? '当前未触发/卡住多于已执行，建议把计划改得更小、更具体，或重新识别真正障碍。'
                          : '当前 if–then 触发情况较好，建议继续做复盘，找出最有效的触发时刻和行动窗口。'),
                ],
              ),
            ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String caption;
  const _MetricTile({required this.title, required this.value, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF374151))),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.25)),
      ]),
    );
  }
}

class _TextBox extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  const _TextBox({required this.controller, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        minLines: 2,
        maxLines: 5,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        ),
      ),
    );
  }
}

class _SegmentPicker extends StatelessWidget {
  final String title;
  final String value;
  final ValueChanged<String> onChanged;
  const _SegmentPicker({required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: <Widget>[
          ChoiceChip(label: const Text('高'), selected: value == 'high', onSelected: (_) => onChanged('high')),
          ChoiceChip(label: const Text('中'), selected: value == 'medium', onSelected: (_) => onChanged('medium')),
          ChoiceChip(label: const Text('低'), selected: value == 'low', onSelected: (_) => onChanged('low')),
        ]),
      ]),
    );
  }
}

class _BelongsPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _BelongsPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('是否属于用户本人', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: <Widget>[
          ChoiceChip(label: const Text('清晰属于我'), selected: value == 'clear', onSelected: (_) => onChanged('clear')),
          ChoiceChip(label: const Text('不清晰'), selected: value == 'unclear', onSelected: (_) => onChanged('unclear')),
          ChoiceChip(label: const Text('可能不是'), selected: value == 'probably_not', onSelected: (_) => onChanged('probably_not')),
        ]),
      ]),
    );
  }
}

class _DirectionPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _DirectionPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('建议方向', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: <Widget>[
          ChoiceChip(label: const Text('继续'), selected: value == 'continue', onSelected: (_) => onChanged('continue')),
          ChoiceChip(label: const Text('调整'), selected: value == 'adjust', onSelected: (_) => onChanged('adjust')),
          ChoiceChip(label: const Text('等待'), selected: value == 'wait', onSelected: (_) => onChanged('wait')),
          ChoiceChip(label: const Text('放下'), selected: value == 'drop', onSelected: (_) => onChanged('drop')),
        ]),
      ]),
    );
  }
}

class _DailyPlanTile extends StatelessWidget {
  final WoopActionCard card;
  final VoidCallback onOpen;
  final ValueChanged<String> onLog;
  const _DailyPlanTile({required this.card, required this.onOpen, required this.onLog});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        InkWell(onTap: onOpen, child: Text(card.wish, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
        const SizedBox(height: 8),
        Text(card.planText.isEmpty ? card.firstAction : card.planText, style: const TextStyle(height: 1.45, color: Color(0xFF374151))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: <Widget>[
          OutlinedButton.icon(onPressed: () => onLog('done'), icon: const Icon(Icons.check_circle_outline, size: 18), label: const Text('已执行')),
          OutlinedButton.icon(onPressed: () => onLog('missed'), icon: const Icon(Icons.refresh_outlined, size: 18), label: const Text('未触发/卡住')),
        ]),
      ]),
    );
  }
}

class _PlanLogLine extends StatelessWidget {
  final WoopActionPlanLog log;
  const _PlanLogLine({required this.log});

  @override
  Widget build(BuildContext context) {
    final ok = log.result == 'done';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Icon(ok ? Icons.check_circle_outline : Icons.error_outline, color: ok ? const Color(0xFF059669) : const Color(0xFFD97706)),
      title: Text(log.actionText.isEmpty ? '执行记录' : log.actionText, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${_dateLabel(log.createdAtMs)} · ${log.note}', maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}

class _CheckInLine extends StatelessWidget {
  final WoopActionDailyCheckIn checkIn;
  const _CheckInLine({required this.checkIn});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: const Icon(Icons.today_outlined, color: Color(0xFF4F46E5)),
      title: Text(checkIn.mainWish.isEmpty ? '今日 Check-in' : checkIn.mainWish, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${checkIn.dateKey} · 能量 ${_levelLabel(checkIn.energy)} · ${checkIn.mood} ${checkIn.note}', maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}

class _ReviewCenterLine extends StatelessWidget {
  final WoopActionReview review;
  const _ReviewCenterLine({required this.review});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: const Icon(Icons.rate_review_outlined, color: Color(0xFF4F46E5)),
      title: Text(review.result == 'done' ? '完成复盘' : '障碍复盘', style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${_dateLabel(review.createdAtMs)} · ${review.actualEvent} ${review.obstacleAppeared} ${review.nextAdjustment}', maxLines: 3, overflow: TextOverflow.ellipsis),
    );
  }
}

String _directionText(String direction) {
  switch (direction) {
    case 'adjust':
      return '调整';
    case 'wait':
      return '等待与安慰';
    case 'drop':
      return '有尊严地放下';
    default:
      return '继续行动';
  }
}

String _directionReason(String direction) {
  switch (direction) {
    case 'adjust':
      return '价值可能重要，但当前版本过大、代价过高或归属不清，适合缩小为可验证版本。';
    case 'wait':
      return '当前可控性较低，适合先稳定情绪、识别需要，并寻找一个可控小动作。';
    case 'drop':
      return '目标可能不再属于你，或代价与价值不匹配，适合设计放下或替代愿望。';
    default:
      return '目标重要且具有推进空间，适合进入 WOOP 并立即执行第一步。';
  }
}

String _dateLabel(int ms) {
  if (ms <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
