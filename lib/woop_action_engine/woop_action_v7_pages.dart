import 'package:flutter/material.dart';

import '../pages/ai_prompt_settings_page.dart';
import 'woop_action_dao.dart';
import 'woop_action_models.dart';
import 'woop_action_prompt_config.dart';

class WoopActionV7ClosurePanel extends StatelessWidget {
  final ValueChanged<WoopActionCard>? onOpenCard;
  final Future<void> Function()? onRefresh;

  const WoopActionV7ClosurePanel({super.key, this.onOpenCard, this.onRefresh});

  Future<void> _open(BuildContext context, Widget page) async {
    final result = await Navigator.of(context).push<dynamic>(MaterialPageRoute(builder: (_) => page));
    if (result is WoopActionCard) onOpenCard?.call(result);
    await onRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    final items = <_V7Item>[
      _V7Item('原书训练课', '8 个核心思想单元 + 练习进度', Icons.menu_book_outlined,
          () => _open(context, const WoopActionSourcebookCoursePage())),
      _V7Item('触发模拟器', '演练障碍出现时 if–then 是否能触发', Icons.play_circle_outline,
          () => _open(context, WoopActionTriggerSimulatorPage(onOpenCard: onOpenCard))),
      _V7Item('下一步行动队列', '把全部卡片压缩成今日 1—3 个行动', Icons.checklist_outlined,
          () => _open(context, WoopActionNextActionQueuePage(onOpenCard: onOpenCard))),
      _V7Item('覆盖验收审计', '逐项检查产品方案落地程度', Icons.fact_check_outlined,
          () => _open(context, const WoopActionAcceptanceAuditPage())),
    ];
    return _V7Panel(
      title: 'V7 产品化差距继续补齐',
      subtitle: '补齐原书课程化训练、触发演练、今日行动队列和验收审计，避免把“入口/文案”误认为完整功能。',
      children: items.map((item) => _V7Tile(item: item)).toList(growable: false),
    );
  }
}

class WoopActionSourcebookCoursePage extends StatefulWidget {
  const WoopActionSourcebookCoursePage({super.key});

  @override
  State<WoopActionSourcebookCoursePage> createState() => _WoopActionSourcebookCoursePageState();
}

class _WoopActionSourcebookCoursePageState extends State<WoopActionSourcebookCoursePage> {
  final WoopActionDao _dao = WoopActionDao();
  Map<String, WoopActionCourseProgress> _progress = const <String, WoopActionCourseProgress>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final progress = await _dao.courseProgressMap();
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _loading = false;
    });
  }

  Future<void> _markDone(_CourseUnit unit) async {
    final reflectionCtrl = TextEditingController();
    final reflection = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('完成：${unit.title}'),
        content: TextField(
          controller: reflectionCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '一句复盘：这个单元让我看到什么？',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, reflectionCtrl.text.trim()), child: const Text('标记完成')),
        ],
      ),
    );
    if (reflection == null) return;
    await _dao.markCourseUnitDone(unit.id, reflection: reflection);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final done = _courseUnits.where((u) => _progress[u.id]?.isDone == true).length;
    return Scaffold(
      appBar: AppBar(title: const Text('原书课程化训练')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                _V7InfoBlock(
                  icon: Icons.menu_book_outlined,
                  title: '把《Rethinking Positive Thinking》变成可练习课程',
                  body: '这不是单纯说明理论，而是把“幻想的边界、心理对照、内在障碍、if–then、反馈、放下”做成 8 个可打卡训练单元。进度只保存在 woop_action_course_progress。',
                ),
                _V7StatLine(label: '课程进度', value: '$done / ${_courseUnits.length}'),
                const SizedBox(height: 12),
                for (final unit in _courseUnits) ...<Widget>[
                  _CourseUnitTile(
                    unit: unit,
                    progress: _progress[unit.id],
                    onDone: () => _markDone(unit),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class WoopActionTriggerSimulatorPage extends StatefulWidget {
  final ValueChanged<WoopActionCard>? onOpenCard;
  const WoopActionTriggerSimulatorPage({super.key, this.onOpenCard});

  @override
  State<WoopActionTriggerSimulatorPage> createState() => _WoopActionTriggerSimulatorPageState();
}

class _WoopActionTriggerSimulatorPageState extends State<WoopActionTriggerSimulatorPage> {
  final WoopActionDao _dao = WoopActionDao();
  final TextEditingController _eventCtrl = TextEditingController();
  final TextEditingController _newObstacleCtrl = TextEditingController();
  List<WoopActionCard> _cards = const <WoopActionCard>[];
  WoopActionCard? _selected;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _eventCtrl.dispose();
    _newObstacleCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cards = await _dao.listCardsByStatuses(<String>['active'], limit: 120);
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _selected = cards.isEmpty ? null : cards.first;
      _loading = false;
    });
  }

  Future<void> _save({required bool worked}) async {
    final card = _selected;
    if (card == null) return;
    setState(() => _saving = true);
    try {
      await _dao.addPlanLog(WoopActionPlanLog(
        cardId: card.id,
        triggerText: card.planIf.isEmpty ? card.obstacle : card.planIf,
        actionText: card.planThen.isEmpty ? card.firstAction : card.planThen,
        result: worked ? 'done' : 'missed',
        note: '触发模拟器：${_eventCtrl.text.trim()} ${_newObstacleCtrl.text.trim().isEmpty ? '' : '新障碍：${_newObstacleCtrl.text.trim()}'}',
      ));
      await _dao.addReview(WoopActionReview(
        cardId: card.id,
        result: worked ? 'done' : 'blocked',
        actualEvent: _eventCtrl.text.trim(),
        obstacleAppeared: card.planIf.isEmpty ? card.obstacle : card.planIf,
        planWorked: worked ? 'worked' : 'not_worked',
        newObstacle: _newObstacleCtrl.text.trim(),
        nextAdjustment: worked ? '保持这个 if–then，并在真实场景中继续验证。' : '需要降低动作门槛或把新障碍做成下一张 WOOP。',
        note: '来自 V7 触发模拟器。',
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(worked ? '已记录：模拟中计划可触发。' : '已记录：暴露新障碍。')));
      _eventCtrl.clear();
      _newObstacleCtrl.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _selected;
    return Scaffold(
      appBar: AppBar(title: const Text('障碍触发模拟器')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                const _V7InfoBlock(
                  icon: Icons.play_circle_outline,
                  title: '在障碍出现前先演练一次',
                  body: '很多计划失败不是因为愿望不重要，而是障碍出现时动作太大、太模糊或没有触发。这里把 if–then 计划放到模拟场景中验证。',
                ),
                if (_cards.isEmpty)
                  const _V7Empty(text: '暂无行动中 WOOP 卡。先创建一张卡，再来模拟触发。')
                else ...<Widget>[
                  DropdownButtonFormField<int>(
                    value: card?.id,
                    decoration: const InputDecoration(labelText: '选择要模拟的 WOOP 卡', border: OutlineInputBorder()),
                    items: _cards.map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.title.isEmpty ? c.wish : c.title, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(growable: false),
                    onChanged: (id) {
                      final matches = _cards.where((c) => c.id == id).toList(growable: false);
                      setState(() => _selected = matches.isEmpty ? null : matches.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (card != null) _SelectedCardBlock(card: card, onOpen: () => widget.onOpenCard?.call(card)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _eventCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: '模拟一个真实触发场景', hintText: '例如：晚上 10:40，我很累，想刷短视频补偿自己。', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _newObstacleCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: '模拟中暴露的新障碍（可选）', hintText: '例如：我不是不知道该做什么，而是不愿意离开手机。', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(children: <Widget>[
                    Expanded(child: FilledButton.icon(onPressed: _saving ? null : () => _save(worked: true), icon: const Icon(Icons.check_circle_outline), label: const Text('计划可触发'))),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton.icon(onPressed: _saving ? null : () => _save(worked: false), icon: const Icon(Icons.report_problem_outlined), label: const Text('暴露新障碍'))),
                  ]),
                ],
              ],
            ),
    );
  }
}

class WoopActionNextActionQueuePage extends StatefulWidget {
  final ValueChanged<WoopActionCard>? onOpenCard;
  const WoopActionNextActionQueuePage({super.key, this.onOpenCard});

  @override
  State<WoopActionNextActionQueuePage> createState() => _WoopActionNextActionQueuePageState();
}

class _WoopActionNextActionQueuePageState extends State<WoopActionNextActionQueuePage> {
  final WoopActionDao _dao = WoopActionDao();
  bool _loading = true;
  List<WoopActionCard> _cards = const <WoopActionCard>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cards = await _dao.listCardsByStatuses(<String>['active'], limit: 200);
    cards.sort((a, b) {
      int score(WoopActionCard c) {
        var s = 0;
        if (c.importance == 'high') s += 3;
        if (c.controllability == 'high') s += 2;
        if (c.feasibility == 'high' || c.feasibility == 'medium_high') s += 2;
        if (c.firstAction.trim().isNotEmpty) s += 2;
        if (c.direction == 'continue') s += 1;
        return s;
      }
      return score(b).compareTo(score(a));
    });
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _loading = false;
    });
  }

  Future<void> _record(WoopActionCard card, bool done) async {
    await _dao.addPlanLog(WoopActionPlanLog(
      cardId: card.id,
      triggerText: card.planIf.isEmpty ? card.obstacle : card.planIf,
      actionText: card.firstAction.isEmpty ? card.planThen : card.firstAction,
      result: done ? 'done' : 'missed',
      note: done ? '来自下一步行动队列：已完成最小行动。' : '来自下一步行动队列：未启动，需要复盘真实障碍。',
    ));
    if (done) await _dao.updateStatus(card.id, 'done');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final top = _cards.take(3).toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('下一步行动队列')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: <Widget>[
                  const _V7InfoBlock(
                    icon: Icons.checklist_outlined,
                    title: '把多个愿望压缩成 1—3 个现实行动',
                    body: '原产品方案强调不是愿望越多越好，而是智慧分配精力。这里只保留今天最值得验证的少数行动，避免愿望过载。',
                  ),
                  if (top.isEmpty)
                    const _V7Empty(text: '暂无行动中卡片。')
                  else
                    for (var i = 0; i < top.length; i++) ...<Widget>[
                      _QueueCard(
                        rank: i + 1,
                        card: top[i],
                        onOpen: () => widget.onOpenCard?.call(top[i]),
                        onDone: () => _record(top[i], true),
                        onMissed: () => _record(top[i], false),
                      ),
                      const SizedBox(height: 10),
                    ],
                  const SizedBox(height: 14),
                  const Text('全部行动中卡片', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  for (final card in _cards.skip(3)) ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(card.title.isEmpty ? card.wish : card.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(card.firstAction.isEmpty ? card.planText : card.firstAction, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onOpenCard?.call(card),
                  ),
                ],
              ),
            ),
    );
  }
}

class WoopActionAcceptanceAuditPage extends StatefulWidget {
  const WoopActionAcceptanceAuditPage({super.key});

  @override
  State<WoopActionAcceptanceAuditPage> createState() => _WoopActionAcceptanceAuditPageState();
}

class _WoopActionAcceptanceAuditPageState extends State<WoopActionAcceptanceAuditPage> {
  final WoopActionDao _dao = WoopActionDao();
  final WoopActionPromptConfig _prompts = WoopActionPromptConfig();
  Map<String, int> _counts = const <String, int>{};
  int _promptCount = 0;
  int _courseDone = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final counts = await _dao.counts();
    final progress = await _dao.listCourseProgress(limit: 200);
    if (!mounted) return;
    setState(() {
      _counts = counts;
      _promptCount = _prompts.allPromptIds().length;
      _courseDone = progress.where((p) => p.isDone).length;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _auditRows(counts: _counts, promptCount: _promptCount, courseDone: _courseDone);
    return Scaffold(
      appBar: AppBar(
        title: const Text('产品覆盖验收审计'),
        actions: <Widget>[
          IconButton(
            tooltip: '打开 WOOP Prompt 配置',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiPromptSettingsPage(initialModuleId: WoopActionPromptConfig.moduleId, initialPromptId: WoopActionPromptConfig.globalId))),
            icon: const Icon(Icons.tune_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                const _V7InfoBlock(
                  icon: Icons.fact_check_outlined,
                  title: '诚实区分“入口存在”和“功能闭环”',
                  body: '这页不是宣传页，而是把最初产品设计方案逐项拆成验收点：是否有独立数据、是否能编辑、是否能复盘、是否可配置 Prompt、是否需要本地编译验证。',
                ),
                for (final row in rows) ...<Widget>[
                  _AuditRowTile(row: row),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

class _CourseUnit {
  final String id;
  final String title;
  final String core;
  final String practice;
  final String review;
  const _CourseUnit(this.id, this.title, this.core, this.practice, this.review);
}

const List<_CourseUnit> _courseUnits = <_CourseUnit>[
  _CourseUnit('c1_fantasy_not_action', '1｜幻想不是行动', '单纯积极幻想会带来“心理达成”，让人像已经成功一样放松。', '写下一个你最近反复想象但没有推进的愿望。标出它给你的短期安慰和长期风险。', '我是否把“感觉积极”误当成了“已经行动”？'),
  _CourseUnit('c2_fantasy_has_value', '2｜幻想也有边界价值', '幻想可以安慰、等待、揭示需要、探索真实愿望，但不能替代行动。', '选择一个低可控场景，允许自己想象最好结果 5 分钟，然后写下一个可控小行动。', '这个幻想揭示了我真正缺什么？'),
  _CourseUnit('c3_mental_attainment', '3｜心理达成的风险', '美好画面可能提前消费奖赏，降低能量和信息开放度。', '找一个你常“想完就算做过”的目标，写下它的现实证据缺口。', '我现在需要的是更多幻想，还是一个现实证据？'),
  _CourseUnit('c4_mental_contrasting', '4｜心理对照', '先未来、后现实：先想最佳结果，再看关键障碍，愿望才会变成行动入口。', '对一个愿望写 W/O/O 三行，不写计划，先确认障碍是否真的关键。', '我找到的是内在障碍，还是只写了外部条件？'),
  _CourseUnit('c5_nonconscious_link', '5｜让障碍触发行动', '心理对照会让愿望、障碍、行动形成更自动的连接。', '把一个障碍改写成“如果 X 出现，那么我就 Y”。Y 必须小到能立刻做。', '当 X 出现时，Y 是否足够具体？'),
  _CourseUnit('c6_woop', '6｜完整 WOOP', 'Wish、Outcome、Obstacle、Plan 是一个闭环，不是愿望清单。', '创建一张完整 WOOP 卡，并在 24 小时内记录一次触发或未触发。', '这张卡最薄弱的是 W/O/O/P 哪一步？'),
  _CourseUnit('c7_applications', '7｜应用到生活领域', 'WOOP 可用于健康、学习、关系、工作和冲动行为，但要保持场景具体。', '从健康/学习/关系/情绪中选一个场景，做一个 24 小时 WOOP。', '这个场景里我最常见的内在障碍是什么？'),
  _CourseUnit('c8_life_companion', '8｜投入、调整与放下', 'WOOP 的成熟价值是智慧分配生命能量：可行目标投入，不可行目标调整或放下。', '选择一个长期目标，做价值校准审计：继续、调整、暂存还是放下。', '这个目标还属于我吗？它的代价是否仍值得？'),
];

List<_AuditRow> _auditRows({required Map<String, int> counts, required int promptCount, required int courseDone}) {
  final cards = counts['total'] ?? 0;
  final reviews = counts['reviews'] ?? 0;
  final logs = counts['plan_logs'] ?? 0;
  final checkins = counts['daily_checkins'] ?? 0;
  final experiments = counts['experiments'] ?? 0;
  return <_AuditRow>[
    _AuditRow('独立模块边界', '已落地', '使用 lib/woop_action_engine 与 woop_action_* 表；仍需本地构建验证无跨模块冲突。'),
    _AuditRow('三层 Prompt 配置中心', promptCount >= 30 ? '已落地' : '部分落地', '当前注册 $promptCount 个 WOOP Prompt，可在统一配置中心编辑。'),
    _AuditRow('WOOP 卡创建与编辑', cards > 0 ? '数据已验证' : '已落地待使用', '支持 AI 生成、手动向导、详情页复盘；仍可继续增强字段级编辑体验。'),
    _AuditRow('愿望地图与状态管理', '已落地', '支持行动中、完成、暂存、放下；可继续增加高级筛选和批量操作。'),
    _AuditRow('障碍雷达', '部分落地', '已有高频障碍统计与 AI 分析入口；后续可继续做时间趋势图。'),
    _AuditRow('if–then 计划验证', logs > 0 ? '数据已验证' : '已落地待使用', '计划库、执行日志、触发模拟器已经形成闭环。当前日志 $logs 条。'),
    _AuditRow('每日驾驶舱', checkins > 0 ? '数据已验证' : '已落地待使用', '支持每日 Check-in 与主线愿望选择。当前 Check-in $checkins 条。'),
    _AuditRow('失败复盘与新版 WOOP', reviews > 0 ? '数据已验证' : '已落地待使用', '支持复盘、记录新障碍、生成新版卡。当前复盘 $reviews 条。'),
    _AuditRow('行动实验室', experiments > 0 ? '数据已验证' : '已落地待使用', '支持把 if–then 当实验验证。当前实验 $experiments 条。'),
    _AuditRow('原书课程化训练', courseDone > 0 ? '数据已验证' : 'V7 新增待使用', '8 个核心思想单元，当前完成 $courseDone 个。'),
    _AuditRow('完整构建验证', '仍需你本地验证', '当前沙盒没有 Flutter/Dart，仍需 flutter analyze 与 flutter build apk --release。'),
    _AuditRow('100% 完整实现声明', '不应声明', '还有可继续增强项：通知触发、趋势可视化、批量管理、深度 AI 对话、多设备同步。'),
  ];
}

class _AuditRow {
  final String name;
  final String status;
  final String note;
  const _AuditRow(this.name, this.status, this.note);
}

class _V7Item {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _V7Item(this.title, this.subtitle, this.icon, this.onTap);
}

class _V7Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _V7Panel({required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), height: 1.45)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.05,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: children,
          ),
        ]),
      );
}

class _V7Tile extends StatelessWidget {
  final _V7Item item;
  const _V7Tile({required this.item});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Row(children: <Widget>[
            Icon(item.icon, color: const Color(0xFF2563EB)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ])),
          ]),
        ),
      );
}

class _V7InfoBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _V7InfoBlock({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFBFDBFE))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Icon(icon, color: const Color(0xFF1D4ED8)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(height: 1.5, color: Color(0xFF1E3A8A))),
          ])),
        ]),
      );
}

class _V7StatLine extends StatelessWidget {
  final String label;
  final String value;
  const _V7StatLine({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Row(children: <Widget>[
          Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _V7Empty extends StatelessWidget {
  final String text;
  const _V7Empty({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Text(text, style: const TextStyle(color: Color(0xFF6B7280))),
      );
}

class _CourseUnitTile extends StatelessWidget {
  final _CourseUnit unit;
  final WoopActionCourseProgress? progress;
  final VoidCallback onDone;
  const _CourseUnitTile({required this.unit, required this.progress, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final done = progress?.isDone == true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: done ? const Color(0xFF86EFAC) : const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(child: Text(unit.title, style: const TextStyle(fontWeight: FontWeight.w900))),
          TextButton(onPressed: done ? null : onDone, child: Text(done ? '已完成' : '标记完成')),
        ]),
        Text(unit.core, style: const TextStyle(height: 1.45)),
        const SizedBox(height: 8),
        Text('练习：${unit.practice}', style: const TextStyle(color: Color(0xFF374151), height: 1.45)),
        const SizedBox(height: 6),
        Text('复盘：${unit.review}', style: const TextStyle(color: Color(0xFF6B7280), height: 1.45)),
        if ((progress?.reflection ?? '').isNotEmpty) ...<Widget>[
          const Divider(height: 18),
          Text('我的复盘：${progress!.reflection}', style: const TextStyle(color: Color(0xFF166534), height: 1.45)),
        ],
      ]),
    );
  }
}

class _SelectedCardBlock extends StatelessWidget {
  final WoopActionCard card;
  final VoidCallback onOpen;
  const _SelectedCardBlock({required this.card, required this.onOpen});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFFDE68A))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: Text(card.title.isEmpty ? card.wish : card.title, style: const TextStyle(fontWeight: FontWeight.w900))),
            TextButton(onPressed: onOpen, child: const Text('打开卡片')),
          ]),
          Text('如果：${card.planIf.isEmpty ? card.obstacle : card.planIf}', style: const TextStyle(height: 1.45)),
          Text('那么：${card.planThen.isEmpty ? card.firstAction : card.planThen}', style: const TextStyle(height: 1.45)),
        ]),
      );
}

class _QueueCard extends StatelessWidget {
  final int rank;
  final WoopActionCard card;
  final VoidCallback onOpen;
  final VoidCallback onDone;
  final VoidCallback onMissed;
  const _QueueCard({required this.rank, required this.card, required this.onOpen, required this.onDone, required this.onMissed});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            CircleAvatar(radius: 14, child: Text('$rank')),
            const SizedBox(width: 10),
            Expanded(child: Text(card.title.isEmpty ? card.wish : card.title, style: const TextStyle(fontWeight: FontWeight.w900))),
            IconButton(onPressed: onOpen, icon: const Icon(Icons.open_in_new)),
          ]),
          Text(card.firstAction.isEmpty ? card.planText : card.firstAction, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 10),
          Row(children: <Widget>[
            Expanded(child: FilledButton(onPressed: onDone, child: const Text('完成并记录'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton(onPressed: onMissed, child: const Text('未启动'))),
          ]),
        ]),
      );
}

class _AuditRowTile extends StatelessWidget {
  final _AuditRow row;
  const _AuditRowTile({required this.row});

  Color _color(String status) {
    if (status.contains('已落地') || status.contains('数据已验证')) return const Color(0xFF16A34A);
    if (status.contains('部分') || status.contains('待使用') || status.contains('V7')) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: Text(row.name, style: const TextStyle(fontWeight: FontWeight.w900))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: _color(row.status).withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
              child: Text(row.status, style: TextStyle(color: _color(row.status), fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(row.note, style: const TextStyle(color: Color(0xFF6B7280), height: 1.45)),
        ]),
      );
}
