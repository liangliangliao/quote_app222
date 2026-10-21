import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'self_os_ai_service.dart';
import 'self_os_case_page.dart';
import 'self_os_guide_page.dart';
import 'self_os_guidance.dart';
import 'self_os_engine.dart';
import 'self_os_models.dart';
import 'self_os_repository.dart';
import 'self_os_widgets.dart';
import 'self_os_insights.dart';
import 'self_os_v37_rules.dart';
import 'self_os_progress.dart';
import 'self_os_learning.dart';

class SelfOsHomePage extends StatefulWidget {
  const SelfOsHomePage({super.key, this.repository, this.ai});
  final SelfOsRepository? repository;
  final SelfOsAiService? ai;
  @override
  State<SelfOsHomePage> createState() => _SelfOsHomePageState();
}

class _SelfOsHomePageState extends State<SelfOsHomePage> {
  late final _repository = widget.repository ?? SelfOsRepository();
  late final _ai = widget.ai ?? SelfOsAiService();
  List<SelfOsCase> _cases = [];
  SelfOsProfile _profile = SelfOsProfile();
  bool _loading = true;
  String? _error;
  int _tab = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (widget.repository == null) _repository.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cases = await _repository.loadCases();
      final profile = await _repository.loadProfile();
      if (!mounted) return;
      setState(() {
        _cases = cases;
        _profile = profile;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _error = '本地记录暂时无法读取，原有数据已保留。请重试。';
          _loading = false;
        });
    }
  }

  Future<void> _open(SelfOsCase c,
      {SelfOsEngine? engine, int? workspace}) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => engine == null && workspace == null
            ? SelfOsGuidePage(
                value: c,
                repository: _repository,
                ai: _ai,
                history: _cases,
                profile: _profile)
            : SelfOsCasePage(
                value: c,
                repository: _repository,
                ai: _ai,
                history: _cases,
                profile: _profile,
                initialEngine: engine,
                initialWorkspace: workspace)));
    if (mounted) await _load();
  }

  Future<void> _create({bool retrospective = false}) async {
    final values = await osEditDialog(context,
        title: retrospective ? '我刚刚做了一件事' : '我现在面临一个选择',
        labels: {'problem': retrospective ? '发生了什么？' : '说说眼前的问题或选择'},
        requiredFields: {'problem'},
        hint: '从一件真实的小事开始。我们会一起理清，再找到可以验证的一小步。');
    if (values == null || !mounted) return;
    final c =
        SelfOsCase(problem: values['problem']!, retrospective: retrospective);
    try {
      await _repository.saveCase(c);
      if (mounted) await _open(c);
    } catch (_) {
      if (mounted) osMessage(context, '保存失败，请重试。');
    }
  }

  Future<void> _delete(SelfOsCase c) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('删除这个案例？'),
                content: const Text('将删除这个案例及其行动证据。由它提炼的个人原则会标明来源已删除。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('保留')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('删除'))
                ]));
    if (yes != true) return;
    try {
      await _repository.deleteCase(c.id);
      await _load();
    } catch (_) {
      if (mounted) osMessage(context, '删除失败，记录仍保留。');
    }
  }

  Future<void> _editManual() async {
    final values = await osEditDialog(context,
        title: '我的使用说明书',
        labels: const {
          'values': '长期重视什么 / 暂时被什么吸引',
          'means': '适合我的目标与手段',
          'cognition': '常见认识遗漏与有效纠错方法',
          'belief': '有证据的信念 / 仍待验证的信念',
          'motivation': '有效动机与现场条件',
          'strengths': '已验证优势（注明证据和情境）',
          'limits': '已验证硬限制（注明依据）',
          'trainable': '当前不足但可训练',
          'unknown': '尚未验证的能力',
          'misfit': '高度不适配的条件',
          'costs': '愿意承担与不愿承担的代价',
          'protection': '优势部署与弱点防护',
        },
        initial: _profile.manual,
        hint: '这些是可修正的自我知识。当前不足不会自动变成永久限制。');
    if (values == null) return;
    final draft = SelfOsProfile.fromJson(_profile.toJson())
      ..manual.addAll(values);
    try {
      await _repository.saveProfile(draft);
      if (mounted) setState(() => _profile = draft);
    } catch (_) {
      if (mounted) osMessage(context, '说明书保存失败，请重试。');
    }
  }

  Future<void> _principle(SelfOsObservation evidence) async {
    final values = await osEditDialog(context,
        title: '从证据提炼一条原则',
        labels: const {
          'condition': '什么情境下适用？',
          'rule': '我准备怎样选择？',
          'notApplicable': '哪些情境不适用？',
          'exception': '哪些新信息出现时要重审？'
        },
        initial: {'rule': evidence.review.learning},
        requiredFields: {'condition', 'rule', 'notApplicable', 'exception'},
        hint: '来源：${evidence.review.context}。这是一条待持续验证的个人原则。');
    if (values == null) return;
    final draft = SelfOsProfile.fromJson(_profile.toJson());
    draft.principles.add({
      ...values,
      'id': selfOsId(),
      'evidenceIds': [evidence.review.id],
      'createdAt': DateTime.now().toIso8601String()
    });
    try {
      await _repository.saveProfile(draft);
      if (mounted) {
        setState(() => _profile = draft);
        osMessage(context, '已保存到个人决策宪法');
      }
    } catch (_) {
      if (mounted) osMessage(context, '原则保存失败，请重试。');
    }
  }

  Future<void> _export() async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('导出 Self OS 记录'),
                content:
                    const Text('导出内容包含你在本模块记录的个人选择和复盘，将以明文复制到剪贴板。请保存到可信的位置。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('复制记录'))
                ]));
    if (yes != true) return;
    await Clipboard.setData(ClipboardData(
        text: jsonEncode({
      'product': 'Self OS',
      'version': '3.7',
      'exportedAt': DateTime.now().toIso8601String(),
      'cases': _cases.map((c) => c.toJson()).toList(),
      'profile': _profile.toJson()
    })));
    if (mounted) osMessage(context, 'Self OS 记录已复制');
  }

  @override
  Widget build(BuildContext context) => SelfOsTheme(
          child: Scaffold(
        appBar: AppBar(
            title: const Text('成为自己',
                style: TextStyle(fontWeight: FontWeight.w700)),
            actions: [
              const Center(
                  child: Text('SELF OS  /  3.7',
                      style: TextStyle(
                          fontSize: 11, letterSpacing: 1.2, color: osForest))),
              const SizedBox(width: 8),
              IconButton(
                  tooltip: '导出本模块记录',
                  onPressed: _loading || _error != null ? null : _export,
                  icon: const Icon(Icons.ios_share_outlined))
            ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              TextButton(
                                  onPressed: _load, child: const Text('重新读取'))
                            ])))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 880),
                            child: ListView(
                                key: ValueKey('self_os_tab_$_tab'),
                                padding:
                                    const EdgeInsets.fromLTRB(20, 8, 20, 24),
                                children: [
                                  _today,
                                  _caseList,
                                  _self,
                                  _routes
                                ][_tab]())))),
        bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (v) => setState(() => _tab = v),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore),
                  label: '此刻'),
              NavigationDestination(
                  icon: Icon(Icons.layers_outlined), label: '我的案例'),
              NavigationDestination(
                  icon: Icon(Icons.fingerprint), label: '逐渐认识自己'),
              NavigationDestination(icon: Icon(Icons.alt_route), label: '人生路线')
            ]),
      ));

  List<Widget> _today() {
    final observations = SelfOsEngineService.observations(_cases);
    final pending = _cases.where((c) => !c.reviewed).toList();
    return [
      Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
              color: osForest, borderRadius: BorderRadius.circular(24)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.blur_circular, color: Color(0xFFD9DDAC), size: 30),
              SizedBox(width: 10),
              Flexible(
                  child: Text('一份持续生长的自我认识',
                      style: TextStyle(
                          color: Color(0xFFD9DDAC),
                          fontSize: 12,
                          letterSpacing: 1)))
            ]),
            const SizedBox(height: 22),
            const Text('看见更多可能，\n选择自己的生活。',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    height: 1.4,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text('说出眼前的困惑，一次理清一点。\n找到可试的一小步，让现实带回答案。',
                style: TextStyle(color: Color(0xFFD4E0D7), height: 1.7)),
            const SizedBox(height: 24),
            Wrap(spacing: 24, runSpacing: 12, children: [
              _heroStat('${observations.length}', '真实行动证据'),
              _heroStat('${_cases.expand((c) => c.acceptedDesires).length}',
                  '当前欲求假设'),
              _heroStat('${_profile.principles.length}', '个人决策原则')
            ]),
          ])),
      _entry('01', '我现在面临一个选择', '从一个念头、问题或目标开始', Icons.north_east,
          () => _create()),
      _entry('02', '我刚刚做了一件事', '把真实行动变成可复用的新证据', Icons.history,
          () => _create(retrospective: true)),
      _entry('03', '看看我逐渐认识出的自己', '欲求、动机、认识与个人使用说明书', Icons.fingerprint,
          () => setState(() => _tab = 2)),
      const SizedBox(height: 16),
      ..._guidance(pending),
      if (pending.length >= 3)
        OsSection(
            title: '这些选择，正在争夺同一份精力',
            subtitle: '有 ${pending.length} 个案例尚在进行。先选定一条主路线，其他可以保留、延期或实验。',
            children: [
              TextButton.icon(
                  onPressed: () => setState(() => _tab = 3),
                  icon: const Icon(Icons.alt_route),
                  label: const Text('前往人生路线，明确取舍'))
            ]),
      if (pending.isNotEmpty)
        OsSection(
            title: '此刻，下一步',
            subtitle: SelfOsGuidance.next(pending.first),
            children: [
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(pending.first.problem,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: const Text('继续上次停下的地方'),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () => _open(pending.first))
            ]),
      OsSection(
          title: '现实带来的新证据',
          subtitle: '一次行为是一个字母。跨情境的重复证据，才逐渐形成模式。',
          children: observations.isEmpty
              ? [
                  const OsNote('还没有行动证据。记录一次真实行动，再看看预期与现实有什么不同。',
                      icon: Icons.spa_outlined)
                ]
              : observations.take(3).map(_evidence).toList()),
      const Text('欲求 → 认识 → 动机 → 信念 → 决意 → 行动 → 现实反馈',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Color(0xFF6D7C70))),
    ];
  }

  Widget _insightCard(
          String title, List<String> values, String empty) =>
      OsSection(
          title: title,
          children: values.isEmpty
              ? [Text(empty)]
              : values.map((s) => OsNote(s)).toList());

  List<Widget> _guidance(List<SelfOsCase> pending) {
    final nextCases = _cases
        .where((c) =>
            !c.reviewed ||
            ['calibrate', 'verify', 'reentry']
                .contains(SelfOsProgress.next(c).kind))
        .toList();
    int rank(SelfOsCase c) =>
        const {
          'reconsider': 0,
          'hold': 1,
          'verify': 2,
          'prepare': 3,
          'calibrate': 4,
          'reentry': 5,
          'retrieve': 6,
          'ask': 7,
          'experiment': 8,
        }[SelfOsProgress.next(c).kind] ??
        9;
    nextCases.sort((a, b) => rank(a).compareTo(rank(b)));
    final nextCase = nextCases.where((c) => rank(c) < 9).firstOrNull;
    final next = nextCase == null ? null : SelfOsProgress.next(nextCase);
    final attention = pending
        .where((c) => SelfOsV37Rules.attentionBreaks(
                c.motives.map((m) => m.toJson()).toList())
            .isNotEmpty)
        .toList();
    Widget card(SelfOsCase c, String title, String detail, int tab,
            IconData icon) =>
        OsSection(title: title, subtitle: detail, children: [
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, color: osForest),
              title:
                  Text(c.problem, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => _open(c, workspace: tab))
        ]);
    return [
      for (final warning in SelfOsInsights.pathGuard(_cases, _profile))
        OsNote(warning),
      if (nextCase != null && next != null)
        OsSection(title: next.title, subtitle: next.reason, children: [
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.near_me_outlined, color: osForest),
              title: Text(nextCase.problem,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => _open(nextCase, workspace: next.workspace)),
        ]),
      if (attention.isNotEmpty)
        card(attention.first, '相信的理由，进入现场了吗？', '看看注意前景与行动连接，让双向动机都被看见。', 2,
            Icons.center_focus_strong),
      if (_profile.strengths.isNotEmpty && pending.isNotEmpty)
        card(pending.first, '把力量用在合适的位置', '结合行动证据，找到恰当使用与过度使用的边界。', 4,
            Icons.spa_outlined),
    ];
  }

  Widget _heroStat(String value, String label) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600)),
        Text(label,
            style: const TextStyle(color: Color(0xFFD4E0D7), fontSize: 11))
      ]);
  Widget _entry(String number, String title, String detail, IconData icon,
          VoidCallback onTap) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onTap,
                  child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(children: [
                        Text(number,
                            style:
                                const TextStyle(color: osGold, fontSize: 13)),
                        const SizedBox(width: 15),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              const SizedBox(height: 5),
                              Text(detail,
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFF68786E)))
                            ])),
                        const SizedBox(width: 10),
                        Icon(icon, size: 20, color: osForest)
                      ])))));

  List<Widget> _caseList() => [
        Row(children: [
          const Expanded(
              child: Text('每一个选择，都有来处。',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700))),
          IconButton(
              tooltip: '新建案例',
              onPressed: () => _create(),
              icon: const Icon(Icons.add_circle_outline))
        ]),
        const SizedBox(height: 16),
        TextField(
            decoration: const InputDecoration(
                labelText: '搜索问题、目标或新认识', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _query = v.trim())),
        const SizedBox(height: 16),
        if (_cases.isEmpty) const OsNote('从「此刻」记录一个选择，案例会在这里持续积累。'),
        for (final c in _cases.where((c) =>
            '${c.problem} ${c.text('goal')} ${c.reviews.map((r) => r.learning).join(' ')}'
                .contains(_query)))
          OsSection(
              title: c.problem,
              subtitle:
                  '${osDate(c.updatedAt)} · ${c.statusLabel} · ${c.evidenceLevel} · 第 ${c.round} 轮',
              trailing: IconButton(
                  tooltip: '删除案例',
                  onPressed: () => _delete(c),
                  icon: const Icon(Icons.delete_outline, size: 20)),
              children: [
                Text(SelfOsGuidance.next(c),
                    style: const TextStyle(height: 1.5)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                    onPressed: () => _open(c),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('继续这个案例'))
              ]),
      ];

  Widget _evidence(SelfOsObservation o) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${osDate(o.review.createdAt)} · ${o.review.context}',
            style: const TextStyle(color: osGold, fontSize: 12)),
        const SizedBox(height: 5),
        Text(o.review.learning,
            style: const TextStyle(fontWeight: FontWeight.w600, height: 1.5)),
        Text('真实结果：${o.review.result}',
            style: const TextStyle(fontSize: 13, height: 1.6)),
        if (o.review.predictionError != null)
          Text(
              '不适预测误差 ${o.review.predictionError! >= 0 ? '+' : ''}${o.review.predictionError!.toStringAsFixed(1)} / 10（预测 − 实际）',
              style: const TextStyle(fontSize: 12, color: osForest)),
        Wrap(spacing: 8, children: [
          TextButton(
              onPressed: () => _open(_cases.firstWhere((c) => c.id == o.caseId),
                  engine: SelfOsEngine.mirror),
              child: const Text('查看证据链')),
          TextButton(
              onPressed: () => _principle(o), child: const Text('提炼为我的原则'))
        ]),
      ]));

  List<Widget> _self() {
    final obs = SelfOsEngineService.observations(_cases);
    final pairs = obs.where((o) => o.review.predictionError != null).toList();
    final patterns = SelfOsEngineService.patterns(_cases);
    final conflicts = SelfOsEngineService.conflicts(_cases);
    final calibration = SelfOsEngineService.actionCalibrationError(_cases);
    final evidenceIds = obs.map((o) => o.review.id).toSet();
    final coverage = [
      _cases.any((c) => c.acceptedDesires.isNotEmpty),
      _profile.manual.entries.any((e) =>
          ['strengths', 'limits', 'trainable', 'unknown', 'misfit']
              .contains(e.key) &&
          e.value.isNotEmpty),
      obs.any((o) => (o.review.notes['actualCost'] ?? '').isNotEmpty),
      _profile.tradeoffs.isNotEmpty,
      pairs.isNotEmpty
    ].where((v) => v).length;
    return [
      const Text('我不是一个固定的答案。',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      OsNote('获得性格 · 证据覆盖 $coverage / 5：欲求、能力、代价、取舍、预测。仅表示已有记录的维度，不是人格分数。'),
      OsSection(
          title: '从现实中修订过的认识',
          subtitle: '每条都保留原来的预期、实际观察和适用范围。以后分析会优先参考这些具体经历。',
          children: SelfOsLearning.history(_cases).isEmpty
              ? [const Text('完成一次实际反馈并确认它的含义后，认识会出现在这里。')]
              : SelfOsLearning.history(_cases)
                  .take(5)
                  .map((e) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(osText(e['conclusion'])),
                      subtitle: Text('实际：${e['actual']}\n适用范围：${e['scope']}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          _open(_cases.firstWhere((c) => c.id == e['caseId']))))
                  .toList()),
      OsSection(
          title: '个人使用说明书',
          subtitle: '用可追溯的行动记录，持续修订你的个人模型。',
          trailing: IconButton(
              tooltip: '编辑使用说明书',
              onPressed: _editManual,
              icon: const Icon(Icons.edit_outlined)),
          children: [
            for (final e in const {
              'values': '欲求模型',
              'means': '目标与手段',
              'cognition': '认知模式',
              'belief': '信念模型',
              'motivation': '动机模型',
              'strengths': '已验证优势',
              'limits': '已验证硬限制',
              'trainable': '当前可训练的不足',
              'unknown': '尚未验证',
              'misfit': '高度不适配',
              'costs': '真实代价边界',
              'protection': '获得性格 · 条件安排'
            }.entries)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.value,
                            style:
                                const TextStyle(fontSize: 12, color: osGold)),
                        const SizedBox(height: 3),
                        Text(
                            (_profile.manual[e.key] ?? '').isEmpty
                                ? '仍待记录和验证'
                                : _profile.manual[e.key]!,
                            style: const TextStyle(height: 1.5))
                      ])),
          ]),
      OsSection(
          title: '经验性格 · 重复模式',
          subtitle: '仅使用你确认可归纳的证据。至少 3 次行动、2 种情境、2 个案例才展示候选模式；环境和反证始终需要一起考虑。',
          children: patterns.isEmpty
              ? [const Text('目前样本不足，继续积累真实选择，不急着给自己下定义。')]
              : patterns.map((v) => OsNote(v)).toList()),
      _fingerprints('个人动机指纹', SelfOsEngineService.motiveFingerprint(_cases),
          '自报实际影响选择的次数 / 已反馈次数。反方动机同样保留；不等同于因果有效率。'),
      _fingerprints('认知指纹', SelfOsEngineService.cognitiveFingerprint(_cases),
          '自报有帮助的次数 / 已反馈次数；未反馈不计入分母。'),
      _insightCard('个人决意指纹', SelfOsInsights.decisionFingerprint(_cases),
          '回看有实际过程证据的决意，尚未完成的决定保持未知。'),
      _insightCard('认识准备指纹', SelfOsInsights.interventionFingerprint(_cases),
          '记录准备前后的变化，再接上真实行动反馈。'),
      _insightCard('稳定变化的候选证据', SelfOsInsights.stableChanges(_cases),
          '需要至少 3 次、2 个案例、2 种情境，并检查 K / M / Att / E / T / Skill 的替代解释。'),
      OsSection(title: '我的力量 · 从行动中验证', children: [
        if (_profile.strengths.isEmpty)
          const Text('自评是一条线索。把具体力量与真实案例相连，逐步找到使用的分寸。'),
        for (final s in _profile.strengths)
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.title),
              subtitle: Text(SelfOsInsights.strength(s, _cases).confidence),
              trailing: const Icon(Icons.arrow_forward),
              onTap: _cases.isEmpty
                  ? null
                  : () => _open(_cases.first, workspace: 4)),
        if (_cases.isNotEmpty)
          TextButton(
              onPressed: () => _open(_cases.first, workspace: 4),
              child: const Text('打开力量实验室'))
      ]),
      OsSection(
          title: '预测校准',
          subtitle: '只比较行动前已保存的预测与真实反馈，未记录的值保持未知。',
          children: [
            if (calibration != null)
              OsNote(
                  '现场行动概率的平均绝对误差 ${calibration.toStringAsFixed(1)} 个百分点。完成按 100、未行动按 0 观察；部分行动不计入。若保存了 P2，使用调整后的预测。'),
            Text(pairs.isEmpty
                ? '还没有成对的不适预测与实际记录。'
                : '${pairs.length} 次配对记录：预测平均 ${SelfOsEngineService.average(pairs.map((o) => o.review.predictedDiscomfort))!.toStringAsFixed(1)} / 10，实际平均 ${SelfOsEngineService.average(pairs.map((o) => o.review.scores['actualDiscomfort']))!.toStringAsFixed(1)} / 10。'),
            for (final o in obs.take(10))
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                      '${o.review.context}\n计划 ${_number(osMap(o.review.snapshot['scores'])['planProbability'])} / 现场 ${_number(osMap(o.review.snapshot['scores'])['actionProbability'])} → ${{
                        'done': '完成',
                        'partial': '部分行动',
                        'notDone': '未行动'
                      }[o.review.outcome]}',
                      style: const TextStyle(height: 1.5))),
          ]),
      OsSection(
          title: '欲求冲突矩阵',
          subtitle: '同一对欲求在真实冲突中，各自被保住了多少次。结果仍需结合情境解释。',
          children: conflicts.isEmpty
              ? [const Text('复盘中同时记录「保住」与「让位」的欲求，即可形成冲突比较。')]
              : [
                  Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(2),
                        2: FlexColumnWidth(1.3)
                      },
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        const TableRow(children: [
                          Padding(
                              padding: EdgeInsets.all(6), child: Text('欲求 A')),
                          Padding(
                              padding: EdgeInsets.all(6), child: Text('欲求 B')),
                          Padding(
                              padding: EdgeInsets.all(6), child: Text('A : B'))
                        ]),
                        for (final pair in conflicts)
                          TableRow(children: [
                            Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(pair.first)),
                            Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(pair.second)),
                            Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                    '${pair.firstWins} : ${pair.secondWins}'))
                          ]),
                      ]),
                ]),
      OsSection(
          title: '代价接受校准',
          subtitle: '口头接受与遭遇后的选择分别记录。',
          children: obs.isEmpty
              ? [const Text('行动复盘后，这里会呈现真实代价和取舍。')]
              : obs
                  .take(12)
                  .map((o) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                          '${o.review.context}\n口头接受 ${_number(osMap(o.review.snapshot['scores'])['costAcceptance'])} → 实际接受 ${_number(o.review.scores['actualCostAcceptance'])}\n真实代价：${o.review.notes['actualCost']?.isNotEmpty == true ? o.review.notes['actualCost'] : '未记录'}\n保住「${o.review.notes['servedDesire'] ?? '未记录'}」 / 让位「${o.review.notes['sacrificedDesire'] ?? '未记录'}」',
                          style: const TextStyle(height: 1.5))))
                  .toList()),
      OsSection(
          title: '个人决策宪法',
          subtitle: '从具体证据提炼适用条件，也保留例外。',
          children: _profile.principles.isEmpty
              ? [const Text('在新证据下点击「提炼为我的原则」，建立自己的选择依据。')]
              : _profile.principles
                  .map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('当 ${p['condition']}',
                                style: const TextStyle(color: osGold)),
                            Text(osText(p['rule']),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, height: 1.6)),
                            Text('不适用：${p['notApplicable'] ?? '尚未补充'}'),
                            Text('重审条件：${p['exception']}'),
                            Text(
                                osStrings(p['evidenceIds'])
                                        .any(evidenceIds.contains)
                                    ? '来自真实行动证据 · 仍可修正'
                                    : '来源证据已删除 · 需要重新验证',
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF68786E))),
                            TextButton(
                                onPressed: () async {
                                  final values = await osEditDialog(context,
                                      title: '修订个人原则',
                                      labels: const {
                                        'condition': '适用情境',
                                        'rule': '原则',
                                        'notApplicable': '不适用情境',
                                        'exception': '重审条件'
                                      },
                                      initial: {
                                        'condition': osText(p['condition']),
                                        'rule': osText(p['rule']),
                                        'notApplicable':
                                            osText(p['notApplicable']),
                                        'exception': osText(p['exception'])
                                      },
                                      requiredFields: {
                                        'condition',
                                        'rule',
                                        'notApplicable',
                                        'exception'
                                      });
                                  if (values == null) return;
                                  final draft = SelfOsProfile.fromJson(
                                      jsonDecode(
                                          jsonEncode(_profile.toJson())));
                                  draft.principles
                                      .firstWhere((v) => v['id'] == p['id'])
                                      .addAll(values);
                                  try {
                                    await _repository.saveProfile(draft);
                                    if (mounted)
                                      setState(() => _profile = draft);
                                  } catch (_) {
                                    if (mounted) osMessage(context, '保存失败');
                                  }
                                },
                                child: const Text('修订原则'))
                          ])))
                  .toList()),
      OsSection(
          title: '可追溯的行动证据',
          children: obs.isEmpty
              ? [const Text('这里会保留每一次行动的新认识。')]
              : obs.take(20).map(_evidence).toList()),
    ];
  }

  String _number(dynamic value) =>
      value is num ? '${value.toStringAsFixed(0)}%' : '未记录';
  Widget _fingerprints(
          String title, List<SelfOsFingerprint> values, String subtitle) =>
      OsSection(
          title: title,
          subtitle: subtitle,
          children: values.isEmpty
              ? [const Text('还没有足够的现场反馈。')]
              : values
                  .map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${f.label}  ${f.helped}/${f.total}${f.total < 3 ? ' · 样本少' : ''}'),
                            const SizedBox(height: 7),
                            LinearProgressIndicator(
                                value: f.rate / 100,
                                borderRadius: BorderRadius.circular(4))
                          ])))
                  .toList());

  List<Widget> _routes() => [
        const Text('人生是一条线。',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const OsNote('时间、精力与资源有限。选定当前主线，也为延期、实验和主动舍弃留出位置。'),
        for (final warning in SelfOsInsights.pathGuard(_cases, _profile))
          OsNote(warning),
        if (_cases.isEmpty)
          _entry(
              '+', '从一个现实选择开始', '让路线有具体问题和证据作为依据', Icons.add, () => _create()),
        for (final c in _cases)
          OsSection(
              title: c.text('goal').isEmpty ? c.problem : c.text('goal'),
              subtitle:
                  '通常价值 ${_number(c.scores['generalValue'])} · 个人适配 ${_number(c.scores['personalFit'])} · ${c.reviews.length} 条行动证据',
              children: [
                for (final r in c.v37.routes)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.title),
                      subtitle: Text(
                          '${selfOsRouteStates[r.status]} · ${osMechanisms[r.mechanism]}\n${r.fit.values.whereType<double>().length}/6 项个人适配已有记录'),
                      trailing: Icon(
                          r.status == 'active' ? Icons.flag : Icons.alt_route,
                          color: osForest),
                      onTap: () => _open(c, workspace: 0)),
                if (c.v37.routes.isEmpty)
                  Text('${selfOsRouteStates[c.routeStatus]} · 历史案例，打开后补充路线结构'),
                TextButton.icon(
                    onPressed: () => _open(c, workspace: 0),
                    icon: const Icon(Icons.hub_outlined),
                    label: const Text('比较可能性与真实取舍')),
              ]),
        OsSection(
            title: '真实取舍记录',
            children: _profile.tradeoffs.isEmpty
                ? [const Text('调整路线时，记录你保住什么，以及愿意为此舍弃什么。')]
                : _profile.tradeoffs.reversed
                    .take(12)
                    .map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                            '${t['title']} → ${selfOsRouteStates[t['to']] ?? t['to']}\n依据：${t['reason']}\n让位：${t['sacrifice']}',
                            style: const TextStyle(height: 1.6))))
                    .toList()),
      ];
}
