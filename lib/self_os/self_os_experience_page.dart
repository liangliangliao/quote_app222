import 'package:flutter/material.dart';
import 'self_os_models.dart';
import 'self_os_repository.dart';
import 'self_os_principles.dart';
import 'self_os_reality.dart';
import 'self_os_experience_widgets.dart';
import 'self_os_widgets.dart';
import 'self_os_workbench_widgets.dart';
import 'self_os_principle_link.dart';
import 'self_os_experience_reminders.dart';
import 'self_os_ai_service.dart';

class SelfOsExperiencePage extends StatefulWidget {
  const SelfOsExperiencePage(
      {super.key,
      required this.value,
      required this.profile,
      required this.history,
      required this.repository,
      this.initialApplicationId,
      this.ai});
  final SelfOsCase value;
  final SelfOsProfile profile;
  final List<SelfOsCase> history;
  final SelfOsRepository repository;
  final String? initialApplicationId;
  final SelfOsAiService? ai;
  @override
  State<SelfOsExperiencePage> createState() => _SelfOsExperiencePageState();
}

class _SelfOsExperiencePageState extends State<SelfOsExperiencePage> {
  late SelfOsCase _c = widget.value.copy();
  late SelfOsProfile _p =
      SelfOsProfile.fromJson(osClone(widget.profile.toJson()));
  late List<SelfOsCase> _others =
      widget.history.where((c) => c.id != _c.id).map((c) => c.copy()).toList();
  List<SelfOsCase> get _history => [..._others, _c];
  bool _busy = false;
  bool _unavailable = false;
  String? _error;
  List<Map<String, dynamic>> _candidates = [];

  Future<bool> _save(SelfOsCase c, SelfOsProfile p) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await widget.repository.saveCaseAndProfile(c, p);
      if (!mounted) return true;
      setState(() {
        _c = c;
        _p = p;
        _error = null;
      });
      return true;
    } catch (e) {
      if (e is SelfOsStaleWrite) {
        _candidates = [];
        try {
          await _refresh();
          if (mounted) setState(() => _error = '资料或权限已有更新，旧操作未覆盖新记录。请核对后继续。');
        } catch (_) {
          if (mounted) setState(() => _unavailable = true);
        }
        return false;
      }
      if (mounted) setState(() => _error = '保存失败，原有记录仍在。请重试这项操作。');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _change(void Function(SelfOsCase, SelfOsProfile) action) async {
    try {
      final c = _c.copy(), p = SelfOsProfile.fromJson(osClone(_p.toJson()));
      action(c, p);
      await _save(c, p);
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _create() async {
    final p = await osCreatePrinciple(context, _history,
        currentCaseId: _c.id, initialReviewId: _c.reviews.lastOrNull?.id);
    if (p != null) await _change((c, profile) => profile.principles.add(p));
  }

  Future<void> _suggest() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await _refresh()) return;
      final caseVersion = _c.storageRevision,
          profileVersion = _p.storageRevision;
      final candidates = await (widget.ai ?? SelfOsAiService())
          .principleCandidates(_c, _history);
      if (!mounted || !await _refresh()) return;
      if (_c.storageRevision != caseVersion ||
          _p.storageRevision != profileVersion) {
        setState(() {
          _candidates = [];
          _error = '资料授权已更新，这次旧候选未采用。请重新核对。';
        });
        return;
      }
      if (mounted)
        setState(() {
          _candidates = candidates;
          if (candidates.isEmpty) _error = '尚未找到可复用的个人原则，可以先做一次低风险尝试。';
        });
    } catch (e) {
      if (mounted)
        setState(() => _error = e is FormatException
            ? e.message
            : '暂时无法整理候选。原有记录已保留，你可以手动提炼或稍后重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _refresh() async {
    final cases = await widget.repository.loadCases();
    final profile = await widget.repository.loadProfile();
    if (!mounted) return false;
    final current = cases.where((c) => c.id == _c.id).firstOrNull;
    if (current == null) {
      setState(() {
        _unavailable = true;
        _candidates = [];
      });
      return false;
    }
    setState(() {
      _c = current;
      _p = profile;
      _others = cases.where((c) => c.id != _c.id).toList();
    });
    return true;
  }

  Widget _candidate(Map<String, dynamic> p) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('候选 · 如果 ${p['condition']}，那么 ${p['rule']}'),
        Text('可比与差异：${p['comparability']}\n反例检查：${p['counterSearch']}'),
        if (osStrings(p['unknowns']).isNotEmpty)
          Text('尚待核实：${osStrings(p['unknowns']).join('；')}'),
        Wrap(children: [
          TextButton(
              onPressed: () => osPrincipleSources(context, p, _history),
              child: const Text('先看出处与反例')),
          TextButton(
              onPressed: _p.principles.any((item) => item['id'] == p['id'])
                  ? null
                  : () => _change(
                      (c, profile) => profile.principles.add(osClone(p))),
              child: const Text('保留候选，继续审阅')),
        ]),
      ]));

  Future<void> _remind(Map<String, dynamic> application) async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)));
    if (date == null || !mounted) return;
    final time =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null || !mounted) return;
    final at =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!at.isAfter(DateTime.now())) {
      osMessage(context, '请选择未来的时刻，也可以直接在工作台核对。');
      return;
    }
    final draft = _c.copy(),
        profile = SelfOsProfile.fromJson(osClone(_p.toJson()));
    profile.experienceSettings['remindersEnabled'] = true;
    final list = SelfOsPrinciples.applications(draft);
    final a = list.firstWhere((a) => a['id'] == application['id']);
    a.addAll({
      'reminderAt': at.toIso8601String(),
      'reminderStatus': 'requested',
      'deliveryStatus': 'unknown'
    });
    draft.v37.settings['principleApplications'] = list;
    if (!await _save(draft, profile) || !mounted) return;
    setState(() => _busy = true);
    var scheduled = false;
    try {
      scheduled = await SelfOsExperienceReminders.schedule(
          osText(a['id']),
          OsPrincipleLink(
              _c.id, osText(a['principleId']), osText(a['triggerId'])),
          at);
    } catch (_) {
      /* Permission/platform/network-independent failure stays unknown. */
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final updated = _c.copy(), entries = SelfOsPrinciples.applications(_c);
    entries.firstWhere((item) => item['id'] == a['id'])['reminderStatus'] =
        scheduled ? 'scheduled' : 'unavailable';
    updated.v37.settings['principleApplications'] = entries;
    final saved = await _save(updated, _p);
    if (!saved && scheduled)
      await SelfOsExperienceReminders.cancel(osText(a['id']));
    if (mounted && saved)
      osMessage(
          context,
          scheduled
              ? '提醒已安排。系统可能延迟，现场核对仍可在这里完成。'
              : '本机通知暂不可用；你的原则和现场操作仍保存在工作台。');
  }

  Future<void> _cancelReminder(String id) async {
    await SelfOsExperienceReminders.cancel(id);
    await _change((c, p) {
      final entries = SelfOsPrinciples.applications(c);
      entries.firstWhere((a) => a['id'] == id)['reminderStatus'] = 'cancelled';
      c.v37.settings['principleApplications'] = entries;
    });
  }

  Future<void> _choose(Map<String, dynamic> p) async {
    final values = await osRecordEditor(context,
        title: '这一次，条件还合适吗？',
        initial: const {'contextMatches': false, 'safe': false},
        note: '如果 ${p['condition']}，那么 ${p['rule']}。\n'
            '不适用：${p['notApplicable']}\n先核对：${p['riskGate']}\n'
            '重审：${p['exception']}\n可以跳过；这只记录事前选择。',
        fields: const [
          OsInput('contextMatches', '已核对本次条件，适用且没有遇到例外', kind: 'bool'),
          OsInput('safe', '已核对安全、资格与他人自主边界', kind: 'bool'),
          OsInput('opposingReason', '仍值得保留的反方或现实风险（可以未知）'),
        ]);
    if (values == null) return;
    await _change((c, profile) => SelfOsPrinciples.choose(c, p, _history,
        contextMatches: values['contextMatches'] == true,
        safe: values['safe'] == true,
        opposingReason: osText(values['opposingReason'])));
  }

  Future<void> _checkIn(Map<String, dynamic> a) async {
    final snapshot = osMap(a['principleSnapshot']);
    final values = await osRecordEditor(context,
        title: '现场核对 · 可以改道',
        initial: const {'recall': 'unknown'},
        note: '先核对新事实：${snapshot['riskGate']}\n'
            '不适用：${snapshot['notApplicable']}\n重审：${snapshot['exception']}\n'
            '打开卡片只表示打开，不代表想起或实际应用。',
        fields: const [
          OsInput('recall', '这时实际上怎样？',
              options: osPrincipleRecall, required: true),
          OsInput('newInformation', '新事实、风险或条件变化（没有可留空）'),
        ]);
    if (values != null)
      await _change((c, p) => SelfOsPrinciples.checkIn(
          c, osText(a['id']), osText(values['recall']),
          newInformation: osText(values['newInformation'])));
  }

  Future<void> _review(Map<String, dynamic> a, SelfOsReview r) async {
    final values = await osRecordEditor(context,
        title: '方法与结果，分开看看',
        initial: const {
          'use': 'unknown',
          'attempt': 'unknown',
          'effect': 'unknown'
        },
        note: '实际记录：${r.result}\n事后认识：${r.learning}\n'
            '合理退出与准备仍有价值。结果好不等于原则必然有效；事后想起不倒填为现场已知。',
        fields: const [
          OsInput('use', '实际采用了这条原则吗？',
              options: osPrincipleUse, required: true),
          OsInput('preparation', '真正做过的准备（没有或未知也可以）'),
          OsInput('attempt', '实际尝试到了哪一步？',
              options: {
                'unknown': '还不清楚',
                'completed': '完成了本次尝试',
                'blocked': '已尝试，途中受阻',
                'rerouted': '根据新信息合理改道',
                'not_started': '本次未开始尝试',
              },
              required: true),
          OsInput('effect', '方法起了什么作用？（个人反馈）',
              options: {
                'unknown': '不能判断',
                'helped': '感觉有帮助，原因仍待验证',
                'not_helped': '本次没有帮助',
                'harmed': '出现了新负担或反作用',
              },
              required: true),
          OsInput('counter', '这是反例，需要重审旧条件', kind: 'bool'),
        ]);
    if (values != null)
      await _change((c, p) => SelfOsPrinciples.review(c, p, osText(a['id']),
          c.reviews.firstWhere((review) => review.id == r.id),
          use: osText(values['use']),
          attempt: osText(values['attempt']),
          preparation: osText(values['preparation']),
          effect: osText(values['effect']),
          counterExample: values['counter'] == true));
  }

  Future<void> _withdraw({String? reviewId}) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(reviewId == null ? '停止跨案例复用？' : '撤回这条经验依据？'),
                content: const Text('相关原则与派生提示会停止使用并清除旧解释。原案例复盘仍可查看。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('保留')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('撤回'))
                ]));
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.withdrawExperience(_c.id, reviewId: reviewId);
      final cases = await widget.repository.loadCases();
      final profile = await widget.repository.loadProfile();
      if (mounted)
        setState(() {
          _c = cases.firstWhere((c) => c.id == _c.id);
          _others = cases.where((c) => c.id != _c.id).toList();
          _p = profile;
          _error = null;
        });
    } catch (_) {
      if (mounted) setState(() => _error = '撤回未完成，请重试；不会把失败记成已撤回。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reality([Map<String, dynamic>? previous]) async {
    final ids = {
      for (final r in _c.reviews)
        if (r.notes['experienceWithdrawn'] != 'yes') r.id: '实做：${r.result}',
      for (final e in _c.v37.evidence)
        if (e.reliableAt(DateTime.now())) e.id: e.claim,
    };
    final values = await osRecordEditor(context,
        title: '把现实拆成一个可核实的问题',
        initial: {
          ...?previous,
          'task': previous?['task'] ?? _c.problem,
          'classification': previous?['classification'] ?? 'uncertain',
          'safetyConcern': previous?['safetyConcern'] ??
              SelfOsReality.hasSafetyConcern(_c.problem)
        },
        note: '判断的是某事实在这次任务与资源下能否干预。缺证据保留未知；不对整个人下永久结论。',
        fields: [
          const OsInput('fact', '具体发生了什么？（事实与猜测分开）', required: true),
          OsInput('routeId', '这个限制只针对哪条路线？', options: {
            '': '本任务通用 / 暂未区分路线',
            for (final r in _c.v37.routes) r.id: r.title,
          }),
          const OsInput('task', '这次想完成什么任务？', required: true),
          const OsInput('classification', '目前更接近哪种情况？',
              options: osChangeability, required: true),
          OsInput('sourceId', '核对依据（没有就保留未知）', options: {'': '暂缺可靠依据', ...ids}),
          const OsInput('happenedAt', '若为过去事实，实际发生于何时？', kind: 'datetime'),
          const OsInput('reason', '这个依据怎样支持判断？还有什么未知？'),
          const OsInput('support', '需要的训练、工具、资源或协作与同意'),
          const OsInput('nextAction', '仍可做的一小步 / 补救 / 核实动作', required: true),
          const OsInput('reviewAt', '什么条件变化或何时重新核对？', required: true),
          const OsInput('safetyConcern', '涉及伤害、强迫、不公或安全威胁', kind: 'bool'),
          const OsInput('ownAction', '涉及他人时：我能做的沟通与边界'),
          const OsInput('otherChoice', '需要尊重的对方自主决定'),
          const OsInput('obligation', '需核实的契约或法定义务与适当求助渠道'),
        ]);
    if (values == null) return;
    await _change((c, p) {
      final entry = SelfOsReality.assess(c, {
        ...values,
        'evidenceIds': [
          if (osText(values['sourceId']).isNotEmpty) values['sourceId']
        ]
      });
      c.v37.settings['changeabilityAssessments'] = [
        ...osMaps(c.v37.settings['changeabilityAssessments']),
        entry
      ];
    });
  }

  Widget _application(Map<String, dynamic> a) {
    final snapshot = osMap(a['principleSnapshot']);
    final review = _c.reviews.where((r) => r.round == a['round']).firstOrNull;
    final cue = osText(snapshot['rule']);
    return OsSection(
        title: '第 ${a['round']} 轮 · 原则 v${a['principleVersion']}',
        children: [
          if (a['stale'] == true)
            const Text('来源已撤回，旧提示已停止使用。')
          else ...[
            if (a['exposureStatus'] == 'cancelled')
              const Text('提示已暂停。保留当时版本供回顾，重新选择前先核对条件。')
            else
              Semantics(
                  label: '现场短提示',
                  child: Text(
                      cue.length > 72 ? '${cue.substring(0, 72)}…' : cue,
                      style: const TextStyle(fontSize: 19, height: 1.6))),
            Text(
                '事前：${a['exposureStatus'] == 'declined' ? '已暂停' : '选择检验'}\n'
                '现场：${osPrincipleRecall[a['recallStatus']]}\n'
                '实际采用：${osPrincipleUse[a['applicationStatus']]}',
                style: const TextStyle(height: 1.7)),
            if (a['atT2'] != null)
              Text('实际准备：${a['preparation']}\n实际尝试：${const {
                        'unknown': '未知',
                        'completed': '完成本次尝试',
                        'blocked': '途中受阻',
                        'rerouted': '合理改道',
                        'not_started': '未开始尝试',
                      }[a['attemptStatus']] ?? '未知'}\n'
                  '作用：${a['reportedEffect'] == 'unknown' ? '尚不能判断' : '保留个人反馈，因果仍待验证'}'),
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('完整条件、来源与时间记录'),
                children: [
                  Text(
                      '如果 ${snapshot['condition']}\n不适用：${snapshot['notApplicable']}\n'
                      '先核对：${snapshot['riskGate']}\n重审：${snapshot['exception']}\n'
                      'T0 ${a['atT0']}\nT1 ${a['atT1'] ?? '未知 / 未登记'}\nT2 ${a['atT2'] ?? '待反馈'}'),
                  TextButton(
                      onPressed: () =>
                          osPrincipleSources(context, snapshot, _history),
                      child: const Text('查看原始经历与反例')),
                ]),
            if (a['atT2'] == null &&
                !['declined', 'cancelled'].contains(a['exposureStatus']))
              Wrap(spacing: 8, children: [
                if (review == null && a['round'] == _c.round)
                  FilledButton(
                      onPressed: _busy ? null : () => _checkIn(a),
                      child: const Text('到现场了，核对一下')),
                if (review == null && a['round'] == _c.round)
                  TextButton(
                      onPressed: _busy ? null : () => _remind(a),
                      child: const Text('设一个提醒（可选）')),
                if (a['reminderStatus'] == 'scheduled')
                  TextButton(
                      onPressed:
                          _busy ? null : () => _cancelReminder(osText(a['id'])),
                      child: const Text('关闭这个提醒')),
                if (review != null)
                  FilledButton(
                      onPressed: _busy ? null : () => _review(a, review),
                      child: const Text('对照真实复盘，记录采用情况')),
                TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await SelfOsExperienceReminders.cancel(
                                osText(a['id']));
                            await _change((c, p) =>
                                SelfOsPrinciples.pause(c, osText(a['id'])));
                          },
                    child: const Text('暂停 / 不适用')),
              ]),
          ],
        ]);
  }

  @override
  Widget build(BuildContext context) {
    final eligible = SelfOsPrinciples.eligible(_p, _history, _c);
    final apps = SelfOsPrinciples.applications(_c);
    final hasCurrentApplication = apps.any((a) =>
        a['round'] == _c.round &&
        a['atT2'] == null &&
        a['stale'] != true &&
        !['declined', 'cancelled'].contains(a['exposureStatus']));
    final matches = SelfOsReality.opportunities(_history, _c);
    final target =
        apps.where((a) => a['id'] == widget.initialApplicationId).firstOrNull;
    return SelfOsTheme(
        child: Scaffold(
            appBar: AppBar(title: const Text('让经验帮到这一次')),
            body: _unavailable
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('记录已更新或暂时不可用。请返回重新打开，旧操作不会覆盖新的事实或权限。'))
                : AbsorbPointer(
                    absorbing: _busy,
                    child: ListView(
                        key: const ValueKey('experience_page'),
                        padding: const EdgeInsets.all(20),
                        children: [
                          if (_error != null) OsNote(_error!),
                          if (_busy) const LinearProgressIndicator(),
                          if (target != null) _application(target),
                          if (!hasCurrentApplication)
                            OsSection(
                                title: _c.reviewed ? '先保留这次经验' : '先选一条适用的方法',
                                subtitle: '可跳过，可改道。旧经验只是帮助判断的线索。',
                                children: [
                                  if (eligible.isEmpty)
                                    const Text(
                                        '尚未找到可复用且已认可的原则。先保留未知，也可以做一次低风险尝试。'),
                                  if (!_c.reviewed && eligible.isNotEmpty) ...[
                                    Text(
                                        '如果 ${eligible.first['condition']}，那么 ${eligible.first['rule']}'),
                                    TextButton(
                                        onPressed: () =>
                                            _choose(eligible.first),
                                        child: const Text('核对条件，选入本轮')),
                                    if (eligible.length > 1)
                                      ExpansionTile(
                                          title: const Text('其他原则与可能冲突'),
                                          subtitle: const Text(
                                              '一次先检验一条；不相容时分别检查条件，允许保留不同生活方向。'),
                                          children: [
                                            for (final p in eligible.skip(1))
                                              ListTile(
                                                  title:
                                                      Text(osText(p['rule'])),
                                                  subtitle: Text(
                                                      '适用：${p['condition']}'),
                                                  onTap: () => _choose(p))
                                          ]),
                                  ],
                                  TextButton.icon(
                                      onPressed: _create,
                                      icon: const Icon(Icons.add),
                                      label: const Text('从真实经历提炼一条候选')),
                                  if (_c.v37.settings['allowRemoteAnalysis'] !=
                                      false)
                                    TextButton.icon(
                                        onPressed: _suggest,
                                        icon: const Icon(
                                            Icons.auto_awesome_outlined),
                                        label: const Text('请 AI 从允许的经历整理候选')),
                                  if (_candidates.isNotEmpty)
                                    _candidate(_candidates.first),
                                  if (_candidates.length > 1)
                                    ExpansionTile(
                                        title: const Text('查看其他候选（也可以全部跳过）'),
                                        children: _candidates
                                            .skip(1)
                                            .map(_candidate)
                                            .toList()),
                                ]),
                          for (final a in apps.reversed
                              .where((a) => a['id'] != target?['id']))
                            _application(a),
                          SelfOsPrincipleLibrary(
                              profile: _p,
                              cases: _history,
                              onSave: (p) => _save(_c.copy(), p)),
                          OsSection(title: '现实里，下一步还能改变什么？', children: [
                            const Text(
                                '先看事实和来源，再考虑补救、支持或替代路径。情绪可以存在，接纳过去不免除责任。'),
                            TextButton(
                                onPressed: _reality,
                                child: const Text('核对一个现实障碍')),
                            for (final a in SelfOsReality.currentAssessments(_c)
                                .reversed)
                              ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title: Text(
                                      osChangeability[a['classification']] ??
                                          '待核实'),
                                  subtitle: Text(osText(a['fact'])),
                                  children: [
                                    Text(
                                        '依据：${osText(a['reason']).isEmpty ? '尚缺可靠依据' : a['reason']}\n'
                                        '下一步：${osStrings(a['safeAlternatives']).join('；')}\n'
                                        '需要支持：${a['support']}\n复核条件：${a['reviewAt']}\n'
                                        '自己的行动：${a['ownAction']}\n他人自主决定：${a['otherChoice']}\n义务核实：${a['obligation']}'),
                                    const Text('过去若采取另一做法会怎样仍不确定；不由结果判定人格。'),
                                    TextButton(
                                        onPressed: () => _reality(a),
                                        child: const Text('有了新证据，重新核实此事实')),
                                  ]),
                          ]),
                          OsSection(
                              title: '把已有能力用在具体任务上',
                              subtitle: '当前表现、可训练差距和暂时状态分开。新兴趣可以低成本探索。',
                              children: [
                                if (matches.isEmpty)
                                  const Text(
                                      '还没有获准使用的任务能力证据。不做天赋排名，也不据此认定你做不到。'),
                                for (final m in matches.take(3))
                                  ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      title: Text(
                                          osTaskFit[m['classification']] ??
                                              '未知'),
                                      subtitle: Text(osText(m['task'])),
                                      children: [
                                        Text(
                                            '情境：${m['context']}\n实做：${m['performance']}\n${m['nextStep']}'),
                                        Text('来源：${m['evidenceId']}'),
                                      ]),
                                const Text('任务要求、安全资格、工具与他人同意先核实；当前差距与个人价值无关。'),
                              ]),
                          OsSection(title: '这些经验怎样使用', children: [
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('经验提醒'),
                                subtitle:
                                    const Text('只在主动设置的时刻提醒。关闭后取消本模块已安排的经验提醒。'),
                                value:
                                    _p.experienceSettings['remindersEnabled'] ==
                                        true,
                                onChanged: (v) => _change((c, p) =>
                                    p.experienceSettings['remindersEnabled'] =
                                        v)),
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('允许本案例远程 AI 分析'),
                                subtitle: const Text('关闭后仍可在本机记录、修改原则与完成现场核对。'),
                                value: _c.v37.settings['allowRemoteAnalysis'] !=
                                    false,
                                onChanged: (v) => _change((c, p) =>
                                    c.v37.settings['allowRemoteAnalysis'] = v)),
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('允许本案例经验用于其他案例'),
                                subtitle:
                                    const Text('只复用本模块的经历；撤回后相关原则和提示需重新建立。'),
                                value: _c.v37.flag('shareExperience'),
                                onChanged: (v) => v
                                    ? _change((c, p) => c
                                        .v37.settings['shareExperience'] = true)
                                    : _withdraw()),
                            for (final r in _c.reviews)
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(r.context),
                                  subtitle: Text(
                                      r.notes['experienceWithdrawn'] == 'yes'
                                          ? '已撤回经验复用'
                                          : r.learning),
                                  trailing:
                                      r.notes['experienceWithdrawn'] == 'yes'
                                          ? null
                                          : IconButton(
                                              tooltip: '撤回这条经验',
                                              icon: const Icon(Icons.link_off),
                                              onPressed: () =>
                                                  _withdraw(reviewId: r.id))),
                          ]),
                        ]))));
  }
}
