import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../external_data/todo_goal_pages.dart';
import '../external_data/todo_dao.dart';
import '../external_data/todo_models.dart';
import '../pages/ai_prompt_settings_page.dart';
import 'shame_transform_ai_service.dart';
import 'shame_transform_dao.dart';
import 'shame_transform_models.dart';

const _ink = Color(0xFF203A35);
const _paper = Color(0xFFF7F3EE);
const _sage = Color(0xFFD8EEE8);
const _muted = Color(0xFF6F665E);

class ShameTransformHomePage extends StatefulWidget {
  const ShameTransformHomePage({super.key});

  @override
  State<ShameTransformHomePage> createState() =>
      _ShameTransformHomePageState();
}

class _ShameTransformHomePageState extends State<ShameTransformHomePage> {
  final ShameTransformDao _dao = ShameTransformDao();
  List<ShameEvent> _events = const [];
  List<EvidenceItem> _evidence = const [];
  Map<String, int> _metrics = const {};
  Map<String, int> _compassMetrics = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait([
      _dao.listEvents(limit: 12),
      _dao.listEvidence(),
      _dao.weeklyMetrics(),
      _dao.weeklyCompassMetrics(),
    ]);
    if (!mounted) return;
    setState(() {
      _events = values[0] as List<ShameEvent>;
      _evidence = values[1] as List<EvidenceItem>;
      _metrics = values[2] as Map<String, int>;
      _compassMetrics = values[3] as Map<String, int>;
      _loading = false;
    });
  }

  Future<void> _openScene(ShameScene scene) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShameTransformFlowPage(scene: scene),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        title: const Text('足下真实自我'),
        backgroundColor: _paper,
        actions: [
          IconButton(
            tooltip: 'Todo 目标系统',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TodoGoalHomePage()),
            ),
            icon: const Icon(Icons.flag_outlined),
          ),
          IconButton(
            tooltip: '证据墙',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShameEvidenceWallPage(dao: _dao),
              ),
            ).then((_) => _load()),
            icon: const Icon(Icons.grid_view_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: '更多档案',
            onSelected: (value) {
              if (value == 'voices') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InnerVoiceLibraryPage(dao: _dao),
                  ),
                );
              } else if (value == 'goals') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GoalShameProfilesPage(dao: _dao),
                  ),
                );
              } else if (value == 'selfMap') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShameSelfMapPage(dao: _dao),
                  ),
                );
              } else if (value == 'prompts') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AiPromptSettingsPage(
                      initialModuleId: 'shame_transform',
                      initialPromptId: 'shame_global',
                    ),
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'voices', child: Text('内在批判声音卡')),
              PopupMenuItem(value: 'goals', child: Text('Todo 目标羞耻画像 V2')),
              PopupMenuItem(value: 'selfMap', child: Text('长期自我图谱')),
              PopupMenuItem(value: 'prompts', child: Text('配置本模块 AI 提示词')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
                children: [
                  _buildHero(),
                  const SizedBox(height: 14),
                  _buildWeeklyLoop(),
                  const SizedBox(height: 14),
                  _buildAffectDashboard(),
                  const SizedBox(height: 14),
                  _buildCompassDashboard(),
                  const SizedBox(height: 14),
                  _buildTodayAction(),
                  const SizedBox(height: 24),
                  _sectionTitle('现在需要什么？', '先选场景，不要求一次完成所有分析'),
                  const SizedBox(height: 12),
                  _buildPrimaryActions(),
                  const SizedBox(height: 24),
                  _sectionTitle('积极情感恢复', '找回兴趣、喜悦、连接与被看见的生命力'),
                  const SizedBox(height: 12),
                  _buildRecoveryActions(),
                  const SizedBox(height: 24),
                  _sectionTitle('深入修复与整合', '从来源、关系与责任中恢复真实自我'),
                  const SizedBox(height: 12),
                  _buildDeepActions(),
                  const SizedBox(height: 24),
                  _buildEveningReview(),
                  const SizedBox(height: 24),
                  _sectionTitle('真实骄傲资产', '记录承受的羞耻风险、恢复的情感与真实能力'),
                  const SizedBox(height: 10),
                  if (_evidence.isEmpty && _events.isEmpty)
                    _emptyEvidence()
                  else
                    ..._recentEvidenceCards(),
                ],
              ),
            ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SHAME COMPASS · TRUE PRIDE',
            style: TextStyle(
              color: Color(0xFFA9D5C7),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: 14),
          Text(
            '我可以被看见，也可以行动',
            style: TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '看见我原本在乎什么、羞耻如何让自我收缩，再用一个可承受的行动恢复兴趣、连接与真实骄傲。',
            style: TextStyle(
              color: Colors.white70,
              height: 1.55,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyLoop() {
    final actions = _metrics['actions'] ?? 0;
    final events = _metrics['events'] ?? 0;
    final evidence = _metrics['evidence'] ?? 0;
    final visibility = _metrics['visibility'] ?? 0;
    final affectRecovery = _metrics['affectRecovery'] ?? 0;
    final microJoy = _metrics['microJoy'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6DDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本周转化闭环',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metric('$events', '看见触发'),
              _arrow(),
              _metric('$actions', '完成行动'),
              _arrow(),
              _metric('$evidence', '沉淀证据'),
            ],
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('被看见训练 $visibility 次')),
              Chip(label: Text('恢复兴趣/喜悦 $affectRecovery 次')),
              Chip(label: Text('微喜悦 $microJoy 条')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
          ],
        ),
      );

  Widget _arrow() => const Icon(
        Icons.arrow_forward,
        size: 17,
        color: Color(0xFFB1A79D),
      );

  Widget _buildTodayAction() {
    final pending = _events.where((event) => !event.actionCompleted).toList();
    final event = pending.isEmpty ? null : pending.first;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8DC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white70,
            child: Icon(Icons.directions_walk, color: Color(0xFFA75035)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今日现实行动',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
                const SizedBox(height: 5),
                Text(
                  event?.minimumAction ?? '今天只做一个能证明“我不是羞耻本身”的小行动。',
                  style: const TextStyle(height: 1.45),
                ),
                if (event != null) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    onPressed: () => _completeAction(event),
                    child: const Text('我完成了，形成证据'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAffectDashboard() {
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final todayEvents =
        _events.where((event) => event.createdAt >= todayStart).toList();
    final latest = todayEvents.isEmpty ? null : todayEvents.first;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6D9),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('今日情感仪表盘',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 10),
          Text('主要情感：${latest?.emotion.isNotEmpty == true ? latest!.emotion : '等待记录'}'),
          Text('积极情感：${latest?.positiveAffect.isNotEmpty == true ? latest!.positiveAffect : '等待定位'}'),
          Text('羞耻强度：${latest?.intensity ?? 0} / 10'),
          Text('罗盘方向：${latest?.compassDirection.isNotEmpty == true ? latest!.compassDirection : '等待识别'}'),
        ],
      ),
    );
  }

  Widget _buildCompassDashboard() {
    const directions = ['退缩', '攻击自己', '回避', '攻击他人'];
    final primary = directions.fold<String>(
      '',
      (best, item) => (_compassMetrics[item] ?? 0) >
              (best.isEmpty ? -1 : (_compassMetrics[best] ?? 0))
          ? item
          : best,
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6DDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('本周羞耻罗盘',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: directions
                .map((item) => Chip(label: Text('$item ${_compassMetrics[item] ?? 0} 次')))
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            primary.isEmpty || (_compassMetrics[primary] ?? 0) == 0
                ? '记录一次触发，开始看见自动防御如何保护你。'
                : '本周更常使用“$primary”。下一步不是责怪它，而是练习一次可承受的转向。',
            style: const TextStyle(color: _muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Future<void> _completeAction(ShameEvent event) async {
    final risk = TextEditingController(text: event.compassDirection);
    final ability = TextEditingController();
    final restored = TextEditingController(text: event.positiveAffect);
    var difficulty = '中';
    var shareable = false;
    final review = await showDialog<Map<String, Object>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
            title: const Text('形成真实骄傲资产'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: risk,
                    decoration:
                        const InputDecoration(labelText: '我承受了什么羞耻风险？'),
                  ),
                  TextField(
                    controller: ability,
                    decoration:
                        const InputDecoration(labelText: '这个行动体现了什么能力？'),
                  ),
                  TextField(
                    controller: restored,
                    decoration:
                        const InputDecoration(labelText: '恢复了什么兴趣、喜悦或连接？'),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '低', label: Text('低难度')),
                      ButtonSegment(value: '中', label: Text('中难度')),
                      ButtonSegment(value: '高', label: Text('高难度')),
                    ],
                    selected: {difficulty},
                    onSelectionChanged: (value) =>
                        setDialogState(() => difficulty = value.first),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: shareable,
                    onChanged: (value) =>
                        setDialogState(() => shareable = value ?? false),
                    title: const Text('这份喜悦可以分享给安全的人'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('稍后'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, {
                  'risk': risk.text.trim(),
                  'ability': ability.text.trim(),
                  'restored': restored.text.trim(),
                  'difficulty': difficulty,
                  'shareable': shareable,
                }),
                child: const Text('保存资产'),
              ),
            ],
          ),
      ),
    );
    risk.dispose();
    ability.dispose();
    restored.dispose();
    if (review == null) return;
    await _dao.setActionCompleted(event.id, true);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _dao.saveEvidence(
      EvidenceItem(
        id: 'evidence_$now',
        createdAt: now,
        action: event.minimumAction,
        identityEvidence: event.evidenceSentence,
        valueAnchor: '我可以在不完美时行动',
        sourceEventId: event.id,
        shameRisk: '${review['risk'] ?? ''}',
        abilityReflected: '${review['ability'] ?? ''}',
        positiveAffectRestored: '${review['restored'] ?? ''}',
        difficulty: '${review['difficulty'] ?? '中'}',
        shareableJoy: review['shareable'] == true,
      ),
    );
    await _load();
  }

  Widget _buildPrimaryActions() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.03,
      children: [
        _entry(
          Icons.spa_outlined,
          '1 分钟急救',
          '强烈羞耻时先稳定身体，不急着分析',
          _sage,
          () => _openScene(ShameScene.firstAid),
        ),
        _entry(
          Icons.edit_note,
          '记录羞耻事件',
          '分开事实、解释与身份审判',
          const Color(0xFFFFE4D5),
          () => _openScene(ShameScene.eventRecord),
        ),
        _entry(
          Icons.compare_arrows,
          '健康羞耻转化',
          '从“我很差”回到责任、学习与行动',
          const Color(0xFFE2E5F7),
          () => _openScene(ShameScene.healthyTransformation),
        ),
        _entry(
          Icons.flag_outlined,
          'Todo 羞耻扫描',
          '问题树 + 羞耻阻碍 + 行动树',
          const Color(0xFFFFEDBD),
          () => _openScene(ShameScene.todoGoal),
        ),
        _entry(
          Icons.explore_outlined,
          '羞耻罗盘识别',
          '看见退缩、自责、回避或攻击',
          const Color(0xFFDDEFE9),
          () => _openScene(ShameScene.shameCompass),
        ),
        _entry(
          Icons.hide_source_outlined,
          '我正在逃避',
          '把冲动缩小为 5 分钟接触动作',
          const Color(0xFFF4DFE5),
          () => _openScene(ShameScene.avoidanceIntervention),
        ),
      ],
    );
  }

  Widget _buildRecoveryActions() => Column(
        children: [
          _recoveryTile(
            ShameScene.positiveAffectRecovery,
            Icons.emoji_objects_outlined,
            '恢复兴趣与喜悦',
            '不逼自己自信，只恢复一点好奇和生命力',
          ),
          _recoveryTile(
            ShameScene.visibilityTraining,
            Icons.visibility_outlined,
            '被看见训练',
            '从只对自己真实，到向安全关系表达',
          ),
          _recoveryTile(
            ShameScene.bodyIntimacy,
            Icons.favorite_border,
            '身体与亲密羞耻',
            '理解身体、需要、亲近、被拒绝与边界',
          ),
          Card(
            elevation: 0,
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 9),
            child: ListTile(
              onTap: _recordMicroJoy,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF1C9),
                child: Icon(Icons.wb_sunny_outlined, color: _ink),
              ),
              title: const Text(
                '微喜悦记录',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('记录稍微舒服的一刻，以及如何低成本重复'),
              trailing: const Icon(Icons.add),
            ),
          ),
        ],
      );

  Future<void> _recordMicroJoy() async {
    final moment = TextEditingController();
    final source = TextEditingController();
    final repeat = TextEditingController();
    var before = 0.0;
    var after = 1.0;
    var shareable = false;
    final record = await showDialog<MicroJoyRecord>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('记录一刻微喜悦'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: moment,
                  decoration:
                      const InputDecoration(labelText: '哪一刻稍微舒服了一点？'),
                ),
                TextField(
                  controller: source,
                  decoration:
                      const InputDecoration(labelText: '它来自什么场景或体验？'),
                ),
                TextField(
                  controller: repeat,
                  decoration:
                      const InputDecoration(labelText: '可以怎样低成本重复？'),
                ),
                const SizedBox(height: 12),
                Text('积极情感：${before.round()} → ${after.round()}'),
                RangeSlider(
                  values: RangeValues(before, after),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  onChanged: (value) => setDialogState(() {
                    before = value.start;
                    after = value.end;
                  }),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: shareable,
                  onChanged: (value) =>
                      setDialogState(() => shareable = value ?? false),
                  title: const Text('我愿意把这份喜悦分享给安全的人'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (moment.text.trim().isEmpty) return;
                final now = DateTime.now().millisecondsSinceEpoch;
                Navigator.pop(
                  dialogContext,
                  MicroJoyRecord(
                    id: 'micro_joy_$now',
                    createdAt: now,
                    moment: moment.text.trim(),
                    source: source.text.trim(),
                    repeatAction: repeat.text.trim(),
                    affectBefore: before.round(),
                    affectAfter: after.round(),
                    shareable: shareable,
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    moment.dispose();
    source.dispose();
    repeat.dispose();
    if (record == null) return;
    await _dao.saveMicroJoy(record);
    await _load();
  }

  Widget _recoveryTile(
    ShameScene scene,
    IconData icon,
    String title,
    String subtitle,
  ) =>
      Card(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 9),
        child: ListTile(
          onTap: () => _openScene(scene),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFFFF1C9),
            child: Icon(icon, color: _ink),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      );

  Widget _buildDeepActions() {
    final items = [
      (ShameScene.innerChild, Icons.child_care_outlined, '把过去的自己接回来'),
      (ShameScene.innerCritic, Icons.record_voice_over_outlined, '留下保护，拿掉羞辱'),
      (ShameScene.deniedPart, Icons.pie_chart_outline, '整合愤怒、需要、脆弱与欲望'),
      (ShameScene.relationshipBoundary, Icons.people_alt_outlined, '被羞辱、做错或不敢表达需要'),
      (ShameScene.healthyResponsibility, Icons.balance_outlined, '不自毁，也不逃避责任'),
    ];
    return Column(
      children: items
          .map(
            (item) => Card(
              elevation: 0,
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                onTap: () => _openScene(item.$1),
                leading: CircleAvatar(
                  backgroundColor: _sage,
                  child: Icon(item.$2, color: _ink),
                ),
                title: Text(
                  item.$1.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(item.$3),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildEveningReview() {
    return InkWell(
      onTap: () => _openScene(ShameScene.dailyReview),
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFDDD9EE),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          children: [
            Icon(Icons.nights_stay_outlined, color: _ink),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '每晚复盘',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  SizedBox(height: 4),
                  Text('我何时把自己等同于错误？做了什么行动？明天怎样更小一步？'),
                ],
              ),
            ),
            Icon(Icons.arrow_forward),
          ],
        ),
      ),
    );
  }

  Widget _entry(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30, color: _ink),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 2,
              style: const TextStyle(fontSize: 12, height: 1.35, color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: _muted)),
        ],
      );

  Widget _emptyEvidence() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          '完成一次最小行动后，把它变成证据：\n“我虽然感到羞耻，但我没有完全逃避。”',
          style: TextStyle(height: 1.6, color: _muted),
        ),
      );

  List<Widget> _recentEvidenceCards() {
    if (_evidence.isNotEmpty) {
      return _evidence.take(5).map((item) {
        return _evidenceCard(
          item.identityEvidence,
          item.action,
          item.createdAt,
        );
      }).toList();
    }
    return _events.take(5).map((event) {
      return _evidenceCard(
        event.evidenceSentence,
        event.minimumAction,
        event.createdAt,
      );
    }).toList();
  }

  Widget _evidenceCard(String evidence, String action, int createdAt) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_outlined, color: Color(0xFF568275)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    evidence,
                    style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${DateFormat('M月d日 HH:mm').format(DateTime.fromMillisecondsSinceEpoch(createdAt))} · $action',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF847B73)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class ShameTransformFlowPage extends StatefulWidget {
  final ShameScene scene;

  const ShameTransformFlowPage({super.key, required this.scene});

  @override
  State<ShameTransformFlowPage> createState() =>
      _ShameTransformFlowPageState();
}

class _ShameTransformFlowPageState extends State<ShameTransformFlowPage> {
  static const emotions = ['羞耻', '害怕', '失望', '愤怒', '内疚', '悲伤', '孤独', '麻木'];
  static const bodyReactions = ['胸闷', '脸热', '胃紧', '僵住', '想逃', '麻木', '心跳快'];
  static const deniedParts = ['愤怒的我', '想被爱的我', '脆弱的我', '想逃避的我', '有欲望的我', '想成功的我', '害怕失败的我', '想被认可的我'];

  final TextEditingController _input = TextEditingController();
  final TextEditingController _originalWant = TextEditingController();
  final TextEditingController _approachTarget = TextEditingController();
  final TextEditingController _expression = TextEditingController();
  final TextEditingController _expectedResponse = TextEditingController();
  final TextEditingController _contractionMoment = TextEditingController();
  final ShameTransformAiService _ai = ShameTransformAiService();
  final ShameTransformDao _dao = ShameTransformDao();
  final TodoDao _todoDao = TodoDao();
  final Set<String> _emotions = {};
  final Set<String> _bodyReactions = {};
  final Set<String> _positiveAffects = {};
  double _intensity = 5;
  bool _busy = false;
  ShameAiResult? _result;
  String _relationshipMode = '';
  String _deniedPart = '';
  TodoTaskRecord? _selectedTodo;
  int _visibilityLevel = 1;

  @override
  void dispose() {
    _input.dispose();
    _originalWant.dispose();
    _approachTarget.dispose();
    _expression.dispose();
    _expectedResponse.dispose();
    _contractionMoment.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    if (_input.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先写下一点具体内容。')),
      );
      return;
    }
    setState(() => _busy = true);
    final result = await _ai.analyze(
      scene: widget.scene,
      input: _composedInput(),
      intensity: _intensity.round(),
      emotions: _emotions.toList(),
      bodyReactions: _bodyReactions.toList(),
      relationshipMode: _relationshipMode,
      deniedPart: _deniedPart,
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
    });
  }

  String _composedInput() {
    final details = <String>[
      _input.text.trim(),
      if (_positiveAffects.isNotEmpty)
        '用户选择的积极情感：${_positiveAffects.join('、')}',
      if (_originalWant.text.trim().isNotEmpty)
        '我原本想要：${_originalWant.text.trim()}',
      if (_approachTarget.text.trim().isNotEmpty)
        '我原本想靠近：${_approachTarget.text.trim()}',
      if (_expression.text.trim().isNotEmpty)
        '我原本想表达：${_expression.text.trim()}',
      if (_expectedResponse.text.trim().isNotEmpty)
        '我期待的回应：${_expectedResponse.text.trim()}',
      if (_contractionMoment.text.trim().isNotEmpty)
        '我开始缩回去的时刻：${_contractionMoment.text.trim()}',
      if (widget.scene == ShameScene.visibilityTraining)
        '本次被看见训练等级：$_visibilityLevel级',
    ];
    return details.join('\n');
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final eventId = 'shame_$now';
    await _dao.saveEvent(
      ShameEvent(
        id: eventId,
        createdAt: now,
        intensity: _intensity.round(),
        scene: widget.scene,
        eventFact: result.eventFact.isEmpty ? _input.text.trim() : result.eventFact,
        emotion: result.emotions.join('、'),
        bodyReaction: result.bodyReactions.join('、'),
        toxicLanguage: result.toxicLanguages.join('；'),
        sourceVoice: result.sourceVoice,
        healthyRewrite: result.healthyVersion,
        userResponsibility: result.userResponsibilities.join('；'),
        notUserResponsibility: result.notUserResponsibilities.join('；'),
        minimumAction: result.minimumAction,
        fallbackAction: result.fallbackAction,
        evidenceSentence: result.evidenceSentence,
        linkedGoalId: _selectedTodo?.taskId ?? '',
        positiveAffect: result.originalPositiveAffects.join('、'),
        blockingPoint: result.blockingPoint,
        compassDirection: result.compassPrimary,
      ),
    );
    if (widget.scene == ShameScene.innerCritic) {
      await _dao.saveInnerVoice(
        InnerVoice(
          id: 'voice_$now',
          createdAt: now,
          voiceText: result.toxicLanguages.join('；'),
          sourceGuess: result.sourceVoice,
          protectionIntent: result.protectionIntent,
          toxicMethod: result.toxicVersion,
          healthyRewrite: result.healthyVersion,
        ),
      );
    }
    if (widget.scene == ShameScene.todoGoal) {
      await _dao.saveGoalProfile(
        GoalShameProfile(
          id: 'goal_shame_$now',
          createdAt: now,
          goalText: _input.text.trim(),
          shameTriggers: result.toxicLanguages.join('；'),
          nonShameGoal: result.healthyVersion,
          problemTreeJson: jsonEncode(result.problemTree),
          actionTreeJson: jsonEncode(result.actionTree),
          dailyAction: result.minimumAction,
          evidenceSentence: result.evidenceSentence,
          positiveAffect: result.originalPositiveAffects.join('、'),
          shameRisks: result.prideShameRisk,
          compassRisks:
              [result.compassPrimary, result.compassSecondary].join(' + '),
        ),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存。完成最小行动后，可在首页沉淀为证据。')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        title: Text(widget.scene.title),
        backgroundColor: _paper,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (widget.scene == ShameScene.firstAid) _firstAidGrounding(),
          if (widget.scene == ShameScene.relationshipBoundary)
            _relationshipBranch(),
          if (widget.scene == ShameScene.deniedPart) _deniedPartPicker(),
          if (widget.scene == ShameScene.todoGoal) _todoPicker(),
          if (widget.scene == ShameScene.visibilityTraining)
            _visibilityLevelPicker(),
          Text(
            widget.scene.inputPrompt,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _input,
            minLines: 4,
            maxLines: 9,
            decoration: InputDecoration(
              hintText: _hintForScene(),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (widget.scene != ShameScene.firstAid) ...[
            const SizedBox(height: 16),
            _positiveAffectInput(),
          ],
          const SizedBox(height: 16),
          Text(
            '当前羞耻强度 ${_intensity.round()} / 10',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Slider(
            value: _intensity,
            min: 0,
            max: 10,
            divisions: 10,
            activeColor: const Color(0xFF4D776C),
            onChanged: (value) => setState(() => _intensity = value),
          ),
          _choiceSection('可能的情绪', emotions, _emotions),
          const SizedBox(height: 12),
          _choiceSection('身体反应', bodyReactions, _bodyReactions),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _analyze,
            style: FilledButton.styleFrom(
              backgroundColor: _ink,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              _busy ? '正在把身份审判还原为现实问题…' : '开始结构化转化',
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 22),
            ShameResultView(result: _result!),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _save,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('保存转化与今日行动'),
            ),
            if (widget.scene == ShameScene.todoGoal && _selectedTodo != null)
              OutlinedButton.icon(
                onPressed: _writeMinimumActionToTodo,
                icon: const Icon(Icons.playlist_add),
                label: const Text('把最小行动写回所选 Todo'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _todoPicker() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6DDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.task_alt, color: _ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _selectedTodo == null
                  ? '可从已同步的 Microsoft To Do 中选择目标'
                  : '${_selectedTodo!.listDisplayName} · ${_selectedTodo!.title}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _searchTodo,
            child: Text(_selectedTodo == null ? '选择' : '更换'),
          ),
        ],
      ),
    );
  }

  Widget _positiveAffectInput() {
    const affects = ['兴趣', '喜悦', '表达', '连接', '能力', '亲密', '被看见'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8DFC4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '积极情感被阻断 · 轻量定位',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: affects
                .map(
                  (affect) => FilterChip(
                    label: Text(affect),
                    selected: _positiveAffects.contains(affect),
                    onSelected: (selected) => setState(() {
                      selected
                          ? _positiveAffects.add(affect)
                          : _positiveAffects.remove(affect);
                    }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          _compactField(_originalWant, '1. 我原本想要什么？'),
          _compactField(_approachTarget, '2. 我原本想靠近谁或什么？'),
          _compactField(_expression, '3. 我原本想表达什么？'),
          _compactField(_expectedResponse, '4. 我期待怎样的回应？'),
          _compactField(_contractionMoment, '5. 哪一刻我突然想隐藏、逃跑或反击？'),
        ],
      ),
    );
  }

  Widget _compactField(TextEditingController controller, String label) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Colors.white,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Widget _visibilityLevelPicker() {
    const labels = ['只给自己看', '向 AI 表达', '向安全的人表达一句', '现实关系中小展示'];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE9E7F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '选择本次被看见训练等级',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...List.generate(labels.length, (index) {
            final level = index + 1;
            return RadioListTile<int>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: level,
              groupValue: _visibilityLevel,
              onChanged: (value) =>
                  setState(() => _visibilityLevel = value ?? 1),
              title: Text('$level级 · ${labels[index]}'),
              subtitle: Text('羞耻风险：${level <= 2 ? '低' : level == 3 ? '中' : '高'}'),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _searchTodo() async {
    final queryController = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('搜索 Microsoft To Do'),
        content: TextField(
          controller: queryController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入任务标题关键词',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, queryController.text),
            child: const Text('搜索'),
          ),
        ],
      ),
    );
    queryController.dispose();
    if (query == null || query.trim().isEmpty || !mounted) return;
    final tasks = await _todoDao.searchTasks(query, limit: 50);
    if (!mounted) return;
    final selected = await showModalBottomSheet<TodoTaskRecord>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: tasks.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(28),
                child: Text('没有找到匹配任务。请先在外部数据同步中同步 Microsoft To Do。'),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: tasks.length,
                itemBuilder: (_, index) {
                  final task = tasks[index];
                  return ListTile(
                    title: Text(task.title),
                    subtitle: Text(task.listDisplayName),
                    trailing: task.isCompleted
                        ? const Icon(Icons.check_circle_outline)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, task),
                  );
                },
              ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedTodo = selected;
      _input.text = [
        selected.title,
        if (selected.bodyText.trim().isNotEmpty) selected.bodyText.trim(),
      ].join('\n');
    });
  }

  Future<void> _writeMinimumActionToTodo() async {
    final task = _selectedTodo;
    final result = _result;
    if (task == null || result == null) return;
    await _todoDao.upsertLocalChecklistItem(
      listId: task.listId,
      taskId: task.taskId,
      title: result.minimumAction,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已作为检查步骤写回 Todo，等待下次同步。')),
    );
  }

  String _hintForScene() => switch (widget.scene) {
        ShameScene.todoGoal => '例如：我要开始找工作，不然我就是废物。',
        ShameScene.relationshipBoundary => '写下对方说了什么、你做了什么，以及你真正想表达的需要。',
        ShameScene.innerChild => '不需要强迫回忆；只写自然浮现、你愿意处理的部分。',
        ShameScene.healthyResponsibility => '尽量描述行为和影响，不使用“坏人、废物”等身份词。',
        _ => '尽量写具体事件；不需要写得完整或正确。',
      };

  Widget _firstAidGrounding() => Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _sage,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '先不分析，只回到当下',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            SizedBox(height: 8),
            Text(
              '双脚踩地，缓慢呼气三次。看见身边 3 个物体，然后提醒自己：发生了一件痛苦的事，不等于我就是这件事。',
              style: TextStyle(height: 1.55),
            ),
            SizedBox(height: 8),
            Text(
              '如果你正有伤害自己或他人的危险，请先联系身边可信任的人、当地紧急服务或专业医疗支持。',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
      );

  Widget _relationshipBranch() {
    const modes = ['我被羞辱了', '我做错了', '我不敢表达需要'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '先选择关系分支',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: modes
                .map(
                  (mode) => ChoiceChip(
                    label: Text(mode),
                    selected: _relationshipMode == mode,
                    onSelected: (_) => setState(() => _relationshipMode = mode),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _deniedPartPicker() => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择一个想理解的部分',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: deniedParts
                  .map(
                    (part) => ChoiceChip(
                      label: Text(part),
                      selected: _deniedPart == part,
                      onSelected: (_) => setState(() => _deniedPart = part),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      );

  Widget _choiceSection(
    String title,
    List<String> options,
    Set<String> selected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: options
              .map(
                (option) => FilterChip(
                  label: Text(option),
                  selected: selected.contains(option),
                  onSelected: (value) => setState(() {
                    value ? selected.add(option) : selected.remove(option);
                  }),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class ShameResultView extends StatelessWidget {
  final ShameAiResult result;

  const ShameResultView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _card('核心锚点', result.valueAnchor, Icons.anchor),
        _card(
          '积极情感被阻断',
          '原本积极情感：${result.originalPositiveAffects.join('、')}\n'
              '原本想要：${result.originalDesire}\n'
              '阻断点：${result.blockingPoint}\n'
              '羞耻触发：${result.shameTrigger}\n'
              '自我收缩：${result.selfContraction}',
          Icons.bolt_outlined,
        ),
        _card(
          '事实 / 解释 / 身份审判',
          _threeLayers(),
          Icons.call_split,
        ),
        if (result.shamePatterns.isNotEmpty)
          _card(
            '可能的羞耻模式',
            '${result.shamePatterns.join('、')}\n\n这是理解当前反应的可能路径，不是对你的诊断或标签。',
            Icons.category_outlined,
          ),
        _card(
          '羞耻罗盘',
          '主方向：${result.compassPrimary}\n'
              '次方向：${result.compassSecondary}\n'
              '依据：${result.compassEvidence.join('；')}\n\n'
              '短期保护：${result.compassShortTermFunction}\n'
              '长期代价：${result.compassLongTermCost}\n'
              '转向行动：${result.compassTurningAction}',
          Icons.explore_outlined,
        ),
        _card(
          '毒性羞耻 → 健康羞耻',
          '原声音：${result.toxicVersion}\n\n健康改写：${result.healthyVersion}\n\n${result.identitySentence}',
          Icons.compare_arrows,
        ),
        _card(
          '这是谁的声音？',
          '${result.sourceVoice}\n\n它可能想保护：${result.protectionIntent}',
          Icons.record_voice_over_outlined,
        ),
        _card(
          '责任边界',
          '我承担：${result.userResponsibilities.join('；')}\n\n我不背负：${result.notUserResponsibilities.join('；')}\n\n可修复：${result.repairableParts.join('；')}\n\n需要接纳：${result.uncontrollableParts.join('；')}',
          Icons.balance,
        ),
        if (result.boundarySentence.trim().isNotEmpty)
          _card('边界 / 修复表达', result.boundarySentence, Icons.forum_outlined),
        if (result.problemTree.isNotEmpty)
          _treeCard('现实问题树与羞耻阻碍', result.problemTree),
        if (result.actionTree.isNotEmpty)
          _treeCard('行动树', result.actionTree),
        if (result.actionOptions.isNotEmpty) _actionOptions(),
        _card(
          '今日最小行动',
          '${result.minimumAction}\n\n时间：${result.minimumTime}\n完成标准：${result.successStandard}\n更小版本：${result.fallbackAction}',
          Icons.directions_walk,
        ),
        _card(
          '真实骄傲预演',
          '行动：${result.prideAction}\n'
              '承受风险：${result.prideShameRisk}\n'
              '体现能力：${result.prideAbility}\n'
              '恢复情感：${result.pridePositiveAffect}\n\n'
              '${result.healthyPrideSentence}\n'
              '提醒：${result.falsePrideWarning}',
          Icons.workspace_premium_outlined,
        ),
        _card('行动后证据', result.evidenceSentence, Icons.verified_outlined),
        if (result.reflectionQuestions.isNotEmpty)
          _card(
            '今晚复盘',
            result.reflectionQuestions
                .asMap()
                .entries
                .map((entry) => '${entry.key + 1}. ${entry.value}')
                .join('\n'),
            Icons.nights_stay_outlined,
          ),
        if (result.userChoicePrompt.trim().isNotEmpty)
          _card('由你选择', result.userChoicePrompt, Icons.touch_app_outlined),
      ],
    );
  }

  String _threeLayers() {
    final facts = result.facts.map((item) => '事实：$item');
    final interpretations = result.interpretations.map((item) => '解释：$item');
    final judgments = result.identityJudgments.map((item) => '身份审判：$item');
    return [...facts, ...interpretations, ...judgments].join('\n');
  }

  Widget _actionOptions() => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8DFD5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.alt_route, size: 20, color: Color(0xFF557A70)),
                SizedBox(width: 8),
                Text('可选行动路径', style: TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 10),
            ...result.actionOptions.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${option.name} · 难度${option.difficulty} · '
                      '羞耻暴露${option.shameExposureLevel} · ${option.timeRequired}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(option.purpose, style: const TextStyle(color: _muted)),
                    ...option.steps.map((step) => Text('• $step')),
                    Text(
                      '完成证据：${option.evidenceAfterDone}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF568275)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _treeCard(String title, List<Map<String, dynamic>> nodes) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EEE8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          ...nodes.map(
            (node) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Text(
                '• ${node['problem'] ?? node['action_area'] ?? node['title'] ?? '行动节点'}\n  ${node['not_identity_judgment'] ?? node['value'] ?? node['why_it_matters'] ?? ''}',
                style: const TextStyle(height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, String text, IconData icon) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8DFD5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF557A70)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              text.trim().isEmpty ? '信息不足，请由你确认，而不是由 AI 武断判断。' : text,
              style: const TextStyle(height: 1.55, color: Color(0xFF504A45)),
            ),
          ],
        ),
      );
}

class ShameEvidenceWallPage extends StatefulWidget {
  final ShameTransformDao dao;

  const ShameEvidenceWallPage({super.key, required this.dao});

  @override
  State<ShameEvidenceWallPage> createState() => _ShameEvidenceWallPageState();
}

class _ShameEvidenceWallPageState extends State<ShameEvidenceWallPage> {
  List<EvidenceItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.dao.listEvidence();
    if (mounted) setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(title: const Text('真实骄傲资产库'), backgroundColor: _paper),
      body: _items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  '真实骄傲只记录真实行动。\n先完成一个最小行动，再回来写下：我承受了什么风险、体现了什么能力？',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.6, color: _muted),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: _items.length,
              itemBuilder: (_, index) {
                final item = _items[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('yyyy年M月d日').format(
                          DateTime.fromMillisecondsSinceEpoch(item.createdAt),
                        ),
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.identityEvidence,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text('我做了：${item.action}'),
                      if (item.shameRisk.isNotEmpty)
                        Text('承受的羞耻风险：${item.shameRisk}'),
                      if (item.abilityReflected.isNotEmpty)
                        Text('体现的能力：${item.abilityReflected}'),
                      if (item.positiveAffectRestored.isNotEmpty)
                        Text('恢复的积极情感：${item.positiveAffectRestored}'),
                      Text('行动难度：${item.difficulty}'),
                      if (item.shareableJoy)
                        const Text('喜悦分享：可以向安全的人分享'),
                      const SizedBox(height: 5),
                      Text(
                        item.valueAnchor,
                        style: const TextStyle(color: Color(0xFF568275)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class InnerVoiceLibraryPage extends StatelessWidget {
  final ShameTransformDao dao;

  const InnerVoiceLibraryPage({super.key, required this.dao});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        title: const Text('内在批判声音卡'),
        backgroundColor: _paper,
      ),
      body: FutureBuilder<List<InnerVoice>>(
        future: dao.listInnerVoices(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final voices = snapshot.data!;
          if (voices.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  '还没有声音卡。先完成一次“内在批判声音外化”：保留它想保护你的功能，拿掉羞辱方式。',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.6, color: _muted),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: voices.length,
            itemBuilder: (_, index) {
              final voice = voices[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '“${voice.voiceText}”',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('可能来源：${voice.sourceGuess}'),
                    Text('想保护：${voice.protectionIntent}'),
                    Text('羞辱方式：${voice.toxicMethod}'),
                    const Divider(height: 22),
                    Text(
                      '新的表达：${voice.healthyRewrite}',
                      style: const TextStyle(
                        color: Color(0xFF477166),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class GoalShameProfilesPage extends StatelessWidget {
  final ShameTransformDao dao;

  const GoalShameProfilesPage({super.key, required this.dao});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        title: const Text('目标羞耻画像'),
        backgroundColor: _paper,
        actions: [
          IconButton(
            tooltip: '打开 Todo 目标系统',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TodoGoalHomePage()),
            ),
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<GoalShameProfile>>(
        future: dao.listGoalProfiles(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final profiles = snapshot.data!;
          if (profiles.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  '还没有目标羞耻画像。通过“Todo 羞耻扫描”把目标从人格审判中拿出来，生成问题树、行动树和今日行动。',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.6, color: _muted),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: profiles.length,
            itemBuilder: (_, index) {
              final profile = profiles[index];
              final problems = _decodeTree(profile.problemTreeJson);
              final actions = _decodeTree(profile.actionTreeJson);
              return ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                backgroundColor: Colors.white,
                collapsedBackgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: Text(
                  profile.goalText,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text('今日：${profile.dailyAction}'),
                children: [
                  _profileSection('触发的羞耻', profile.shameTriggers),
                  _profileSection('目标背后的积极情感', profile.positiveAffect),
                  _profileSection('主要羞耻风险', profile.shameRisks),
                  _profileSection('羞耻罗盘风险', profile.compassRisks),
                  _profileSection('非羞耻化目标', profile.nonShameGoal),
                  _profileSection(
                    '问题树',
                    problems
                        .map((node) => '• ${node['problem'] ?? node['title'] ?? '问题节点'}')
                        .join('\n'),
                  ),
                  _profileSection(
                    '羞耻暴露行动梯度',
                    actions.map(_actionTreeSummary).join('\n\n'),
                  ),
                  _profileSection('完成后证据', profile.evidenceSentence),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static List<Map<String, dynamic>> _decodeTree(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String _actionTreeSummary(Map<String, dynamic> node) {
    final title = node['action_area'] ?? node['title'] ?? '行动节点';
    final rawActions = node['actions'];
    if (rawActions is! List || rawActions.isEmpty) return '• $title';
    final children = rawActions.map((raw) {
      if (raw is Map) {
        final action = Map<String, dynamic>.from(raw);
        final actionTitle = action['title'] ?? action['action'] ?? '小行动';
        final exposure = action['shame_exposure_level'] ?? '待确认';
        final risk = action['shame_risk'] ?? '';
        final pride = action['healthy_pride_sentence'] ??
            action['evidence_sentence'] ??
            '';
        return '  - $actionTitle｜暴露：$exposure'
            '${risk.toString().isEmpty ? '' : '｜风险：$risk'}'
            '${pride.toString().isEmpty ? '' : '\n    真实骄傲：$pride'}';
      }
      return '  - $raw';
    }).join('\n');
    return '• $title\n$children';
  }

  Widget _profileSection(String title, String content) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                content.trim().isEmpty ? '等待补充' : content,
                style: const TextStyle(height: 1.45, color: _muted),
              ),
            ],
          ),
        ),
      );
}

class ShameSelfMapPage extends StatelessWidget {
  final ShameTransformDao dao;

  const ShameSelfMapPage({super.key, required this.dao});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(title: const Text('长期自我图谱'), backgroundColor: _paper),
      body: FutureBuilder<List<SelfMapDimension>>(
        future: dao.selfMap(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final dimensions = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Text(
                '自我不是一次分析的结论，而是在羞耻与真实骄傲经验中持续形成。',
                style: TextStyle(color: _muted, height: 1.5),
              ),
              const SizedBox(height: 14),
              ...dimensions.map(
                (dimension) => Card(
                  elevation: 0,
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text(
                      dimension.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '成长等级 ${dimension.growthLevel}/5 · '
                      '${dimension.evidenceCount} 条真实骄傲',
                    ),
                    childrenPadding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      LinearProgressIndicator(
                        value: dimension.growthLevel / 5,
                        color: const Color(0xFF568275),
                        backgroundColor: const Color(0xFFE4ECE9),
                      ),
                      const SizedBox(height: 12),
                      _selfMapLine('常见罗盘', dimension.commonCompass),
                      _selfMapLine('最近旧脚本', dimension.oldScript),
                      _selfMapLine('新的健康脚本', dimension.newScript),
                      _selfMapLine('最近真实骄傲', dimension.latestPride),
                      _selfMapLine(
                        '积累',
                        '${dimension.eventCount} 次触发 · '
                            '${dimension.evidenceCount} 次行动证据',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _selfMapLine(String title, String content) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('$title：$content', style: const TextStyle(height: 1.45)),
        ),
      );
}
