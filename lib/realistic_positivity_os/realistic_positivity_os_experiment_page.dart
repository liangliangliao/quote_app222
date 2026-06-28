import 'dart:convert';

import 'package:flutter/material.dart';

import 'realistic_positivity_os_dao.dart';
import 'realistic_positivity_os_feature_matrix.dart';
import 'realistic_positivity_os_models.dart';
import 'realistic_positivity_os_workbench_page.dart';

class RealisticPositivityOsExperimentPage extends StatefulWidget {
  final bool embedded;
  final RpoProfile profile;

  const RealisticPositivityOsExperimentPage({
    super.key,
    this.embedded = false,
    this.profile = const RpoProfile(),
  });

  @override
  State<RealisticPositivityOsExperimentPage> createState() => _RealisticPositivityOsExperimentPageState();
}

class _RealisticPositivityOsExperimentPageState extends State<RealisticPositivityOsExperimentPage> {
  final RealisticPositivityOsDao _dao = RealisticPositivityOsDao();
  bool _loading = true;
  RpoProfile _profile = const RpoProfile();
  List<Map<String, Object?>> _experiments = const <Map<String, Object?>>[];

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _load();
  }

  Future<void> _load() async {
    try {
      await _dao.ensureTables();
      final profile = await _dao.loadProfile();
      final experiments = await _dao.listExperiments(limit: 200);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _experiments = experiments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载长期实验失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      final body = const Center(child: CircularProgressIndicator());
      return widget.embedded ? body : Scaffold(body: body);
    }
    final content = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: <Widget>[
          _hero(),
          const SizedBox(height: 12),
          _templatesCard(),
          const SizedBox(height: 12),
          _experimentsCard(),
        ],
      ),
    );
    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('RPO 长期实验', style: TextStyle(fontWeight: FontWeight.w900)), backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
      body: content,
    );
  }

  Widget _hero() {
    return _card(
      title: '连续训练实验',
      subtitle: '终极方案要求 App 不只是生成单次行动卡，还要让 Lecture 9–10 的价值系统变成多日训练闭环。',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const <Widget>[
        _StaticBullet('7 天单模块实验：适合补齐某个薄弱模块，如感恩、价值绑定或 Stretch。'),
        _StaticBullet('14 天完整闭环实验：覆盖人格地图、真实看见、情绪、感恩、问题、行为、改变、关系、高峰体验与周整合。'),
        _StaticBullet('每天都有对应子模块、训练焦点、工作台入口和完成复盘。'),
      ]),
    );
  }

  Widget _templatesCard() {
    return _card(
      title: '创建训练实验',
      subtitle: '选择一个连续训练模板，把设计方案从“功能入口”推进到“长期训练路径”。',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          FilledButton.icon(onPressed: _createFullLoop14, icon: const Icon(Icons.auto_awesome), label: const Text('创建 14 天完整闭环')),
          OutlinedButton.icon(onPressed: _createGratitude7, icon: const Icon(Icons.volunteer_activism_outlined), label: const Text('7 天感恩 Freshness')),
          OutlinedButton.icon(onPressed: _createChange7, icon: const Icon(Icons.psychology_alt_outlined), label: const Text('7 天价值绑定')),
          OutlinedButton.icon(onPressed: _createBehavior7, icon: const Icon(Icons.play_circle_outline), label: const Text('7 天行为优先')),
        ]),
      ]),
    );
  }

  Widget _experimentsCard() {
    return _card(
      title: '我的长期训练实验',
      subtitle: '每个实验都能进入对应子模块工作台，完成后写一句复盘，沉淀为行动证据。',
      child: _experiments.isEmpty
          ? const Text('暂无实验。请先创建一个 7 天或 14 天实验。')
          : Column(children: _experiments.map(_experimentTile).toList(growable: false)),
    );
  }

  Widget _experimentTile(Map<String, Object?> row) {
    final id = (row['id'] ?? '').toString();
    final title = (row['title'] ?? '').toString();
    final status = (row['status'] ?? '').toString();
    final plan = _decodeMap((row['plan_json'] ?? '{}').toString());
    final progress = _decodeMap((row['progress_json'] ?? '{}').toString());
    final days = _decodeDays(plan['days']);
    final done = days.where((d) => progress['day_${d.day}'] != null).length;
    final percent = days.isEmpty ? 0.0 : done / days.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
          Chip(label: Text(status), visualDensity: VisualDensity.compact),
        ]),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: percent, minHeight: 9, borderRadius: BorderRadius.circular(999)),
        const SizedBox(height: 6),
        Text('进度：$done/${days.length} 天', style: const TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 10),
        for (final day in days) _dayRow(id, day, progress['day_${day.day}']),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          OutlinedButton.icon(onPressed: () => _toggleStatus(id, status == 'active' ? 'paused' : 'active'), icon: const Icon(Icons.pause_circle_outline), label: Text(status == 'active' ? '暂停' : '恢复')),
          TextButton.icon(onPressed: () => _deleteExperiment(id), icon: const Icon(Icons.delete_outline), label: const Text('删除')),
        ]),
      ]),
    );
  }

  Widget _dayRow(String experimentId, _RpoExperimentDay day, dynamic progress) {
    final spec = RpoFeatureMatrix.byScene(day.sceneType);
    final done = progress != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: done ? const Color(0xFFF0FDF4) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: done ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        CircleAvatar(radius: 16, backgroundColor: spec.color.withOpacity(.12), child: Text('${day.day}', style: TextStyle(fontSize: 12, color: spec.color, fontWeight: FontWeight.w900))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(day.title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(day.focus, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35)),
          if (done) ...<Widget>[
            const SizedBox(height: 4),
            Text('复盘：${_limit(progress.toString(), 80)}', style: const TextStyle(fontSize: 12, color: Color(0xFF166534))),
          ],
        ])),
        Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          IconButton(tooltip: '进入工作台', onPressed: () => _openWorkbench(day.sceneType), icon: const Icon(Icons.open_in_new)),
          if (!done) IconButton(tooltip: '标记完成', onPressed: () => _markDayDone(experimentId, day), icon: const Icon(Icons.check_circle_outline)),
        ]),
      ]),
    );
  }

  Future<void> _createFullLoop14() async {
    final seq = <String>['onboarding', 'reality_lens', 'emotional_processing', 'gratitude', 'question_reframing', 'behavior_first', 'change_lab', 'abc_change', 'relational_gratitude', 'meaning_making', 'savoring_peak', 'stretch_zone', 'weekly_integration', 'weekly_integration'];
    await _createPlan('RPO 14 天完整闭环实验', 'full_loop_14_days', seq);
  }

  Future<void> _createGratitude7() async => _createPlan('7 天感恩 Freshness 实验', 'gratitude_7_days', List<String>.filled(7, 'gratitude'));
  Future<void> _createChange7() async => _createPlan('7 天价值绑定拆解实验', 'change_7_days', List<String>.filled(7, 'change_lab'));
  Future<void> _createBehavior7() async => _createPlan('7 天行为优先启动实验', 'behavior_7_days', List<String>.filled(7, 'behavior_first'));

  Future<void> _createPlan(String title, String type, List<String> scenes) async {
    final days = <Map<String, dynamic>>[];
    for (var i = 0; i < scenes.length; i++) {
      final spec = RpoFeatureMatrix.byScene(scenes[i]);
      final feature = spec.features.isEmpty ? spec.productGoal : spec.features[i % spec.features.length].title;
      days.add(<String, dynamic>{'day': i + 1, 'scene_type': spec.sceneType, 'title': spec.shortTitle, 'focus': feature});
    }
    await _dao.createExperiment(
      title: title,
      status: 'active',
      planJson: jsonEncode(<String, dynamic>{'type': type, 'days': days}),
    );
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已创建：$title')));
  }

  Future<void> _markDayDone(String experimentId, _RpoExperimentDay day) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('完成第 ${day.day} 天'),
        content: TextField(
          controller: ctrl,
          minLines: 4,
          maxLines: 8,
          decoration: InputDecoration(border: const OutlineInputBorder(), hintText: '今天完成后，我看见了什么新的现实、行动证据或人格变化？\n训练焦点：${day.focus}'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('保存完成')),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null) return;
    final exp = _experiments.firstWhere((e) => (e['id'] ?? '').toString() == experimentId, orElse: () => const <String, Object?>{});
    final progress = _decodeMap((exp['progress_json'] ?? '{}').toString());
    progress['day_${day.day}'] = <String, dynamic>{'scene_type': day.sceneType, 'title': day.title, 'reflection': text, 'completed_at_ms': DateTime.now().millisecondsSinceEpoch};
    await _dao.updateExperimentProgress(id: experimentId, progress: progress);
    await _dao.addActionEvidence(sourceRecordId: experimentId, actionTitle: '长期实验第 ${day.day} 天：${day.title}', status: 'done', evidenceText: '完成 ${day.focus}', reflection: text);
    await _load();
  }

  Future<void> _toggleStatus(String id, String status) async {
    await _dao.updateExperimentStatus(id: id, status: status);
    await _load();
  }

  Future<void> _deleteExperiment(String id) async {
    await _dao.deleteExperiment(id);
    await _load();
  }

  Future<void> _openWorkbench(String scene) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RealisticPositivityOsWorkbenchPage(initialSceneType: scene, profile: _profile)));
    await _load();
  }

  Map<String, dynamic> _decodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {}
    return <String, dynamic>{};
  }

  List<_RpoExperimentDay> _decodeDays(dynamic raw) {
    if (raw is! List) return const <_RpoExperimentDay>[];
    return raw.whereType<Map>().map((m) => _RpoExperimentDay.fromMap(m.map((key, value) => MapEntry(key.toString(), value)))).toList(growable: false);
  }

  Widget _card({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), height: 1.38)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  String _limit(String text, int max) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.runes.length <= max) return clean;
    return String.fromCharCodes(clean.runes.take(max)) + '…';
  }
}

class _RpoExperimentDay {
  final int day;
  final String sceneType;
  final String title;
  final String focus;

  const _RpoExperimentDay({required this.day, required this.sceneType, required this.title, required this.focus});

  factory _RpoExperimentDay.fromMap(Map<String, dynamic> map) => _RpoExperimentDay(
        day: int.tryParse((map['day'] ?? '1').toString()) ?? 1,
        sceneType: (map['scene_type'] ?? 'reality_lens').toString(),
        title: (map['title'] ?? '').toString(),
        focus: (map['focus'] ?? '').toString(),
      );
}

class _StaticBullet extends StatelessWidget {
  final String text;
  const _StaticBullet(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('•  '),
          Expanded(child: Text(text, style: const TextStyle(height: 1.38))),
        ]),
      );
}
