import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../will_mirror_models.dart';
import '../will_mirror_vault.dart';
import 'case_ai.dart';
import 'case_analysis.dart';
import 'case_models.dart';
import 'case_reminders.dart';
import 'case_workflow.dart';

/// A single case owns every stage. Opening a card never reports a real trigger.
class WmCasePage extends StatefulWidget {
  const WmCasePage({super.key, required this.caseId, this.vault, this.link});
  final String caseId;
  final WillMirrorVault? vault;
  final WmCaseLink? link;
  @override
  State<WmCasePage> createState() => _WmCasePageState();
}

class _WmCasePageState extends State<WmCasePage> {
  late final _vault = widget.vault ?? WillMirrorVault();
  final _flow = WmWorkflow();
  final _reminders = WmReminders();
  final _tts = FlutterTts();
  WmCase? _case;
  Map<String, WmCase> _sources = {};
  int _tab = 0, _generation = 0;
  bool _busy = false;
  String? _error, _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_tts.stop());
    if (widget.vault == null) unawaited(_vault.close());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      var value = await _vault.caseFile(widget.caseId);
      // Consent authorizes one foreground run, never a restored/background run.
      if (value?.remoteAllowed == true)
        value =
            await _vault.saveCaseFile(value!.change({'remoteAllowed': false}));
      final sources = <WmCase>[];
      if (value != null) {
        sources.add(value);
        for (final id
            in value.allowedSourceCaseIds.where((id) => id != value!.id)) {
          final source = await _vault.caseFile(id);
          if (source != null) sources.add(source);
        }
      }
      if (!mounted) return;
      setState(() {
        _case = value;
        _sources = {for (final s in sources) s.id: s};
        _error = value == null ? '课题已删除或尚未迁移，请返回课题库。' : null;
      });
      final link = widget.link;
      if (link != null && value != null) {
        final seal = value.snapshots
            .where((s) =>
                s['id'] == link.snapshotId &&
                s['status'] == 'sealed' &&
                s['cycle'] == value!.cycle)
            .firstOrNull;
        final valid = seal != null &&
            value.phase != WmPhase.t3 &&
            WmWorkflow.verifySeal(seal) &&
            wmMap(seal['payload'])['triggerId'] == link.triggerId &&
            (link.principleId == null ||
                value.principleUses.any((u) =>
                    u['principleId'] == link.principleId &&
                    u['status'] == 'active'));
        setState(() {
          _tab = 2;
          _notice = valid
              ? '已打开计划对应的现场卡。条件是否出现、是否想起及是否行动，仍需你确认。'
              : '这条提醒对应的计划已过期或撤回；当前记录未被更改。';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '无法解锁课题，请返回后重试。原有数据未删除。');
    }
  }

  void _show(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _save(WmCase Function(WmCase) change) async {
    if (_busy || _case == null) return false;
    setState(() => _busy = true);
    try {
      final saved = await _vault.saveCaseFile(change(_case!));
      if (mounted)
        setState(() {
          _case = saved;
          _sources[saved.id] = saved;
        });
      return true;
    } on FormatException catch (e) {
      _show(e.message);
    } on StateError catch (_) {
      _show('记录已更新或快照受保护，请重新打开课题后操作。');
    } catch (_) {
      _show('保存未完成，请重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  Future<bool> _confirm(String title, String text,
          {String accept = '确认'}) async =>
      await showDialog<bool>(
          context: context,
          builder: (ctx) =>
              AlertDialog(title: Text(title), content: Text(text), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('返回')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(accept)),
              ])) ??
      false;

  Future<Map<String, String>?> _form(
    String title,
    Map<String, String> fields, {
    Set<String> requiredFields = const {},
    Map<String, Map<String, String>> choices = const {},
    Map<String, String> initial = const {},
    String? note,
  }) async {
    final controllers = fields.map(
        (k, v) => MapEntry(k, TextEditingController(text: initial[k] ?? '')));
    final selected =
        choices.map((k, v) => MapEntry(k, initial[k] ?? v.keys.first));
    final key = GlobalKey<FormState>();
    final result = await showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => Padding(
                  padding: EdgeInsets.fromLTRB(
                      20, 18, 20, MediaQuery.viewInsetsOf(ctx).bottom + 18),
                  child: SingleChildScrollView(
                      child: Form(
                          key: key,
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(title,
                                    style: Theme.of(ctx).textTheme.titleLarge),
                                if (note != null)
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      child: Text(note)),
                                for (final entry in choices.entries)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: DropdownButtonFormField<String>(
                                        initialValue: selected[entry.key],
                                        isExpanded: true,
                                        items: entry.value.entries
                                            .map((e) => DropdownMenuItem(
                                                value: e.key,
                                                child: Text(e.value,
                                                    overflow:
                                                        TextOverflow.ellipsis)))
                                            .toList(),
                                        onChanged: (v) => update(
                                            () => selected[entry.key] = v!),
                                      )),
                                for (final entry in fields.entries)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 14),
                                      child: TextFormField(
                                        controller: controllers[entry.key],
                                        minLines: 1,
                                        maxLines: entry.key == 'token' ? 1 : 4,
                                        maxLength: 4000,
                                        obscureText: entry.key == 'token',
                                        enableSuggestions: entry.key != 'token',
                                        autocorrect: entry.key != 'token',
                                        decoration: InputDecoration(
                                            labelText: entry.value,
                                            border: const OutlineInputBorder(),
                                            counterText: ''),
                                        validator: (v) => requiredFields
                                                    .contains(entry.key) &&
                                                (v ?? '').trim().isEmpty
                                            ? '请填写具体内容'
                                            : null,
                                      )),
                                const SizedBox(height: 18),
                                FilledButton(
                                    onPressed: () {
                                      if (key.currentState!.validate())
                                        Navigator.pop(ctx, {
                                          ...selected,
                                          ...controllers.map((k, v) =>
                                              MapEntry(k, v.text.trim()))
                                        });
                                    },
                                    child: const Text('保存')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('暂时跳过')),
                              ]))),
                )));
    // Modal closing animation may still render its controllers this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in controllers.values) {
        c.dispose();
      }
    });
    return result;
  }

  Future<List<String>?> _chooseEvidence(String title,
      {Set<String>? available, List<String> initial = const []}) async {
    final selected = initial.toSet();
    final rows = _case!.activeEvidence
        .where((e) => available == null || available.contains(e.id))
        .toList();
    return showDialog<List<String>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => AlertDialog(
                  title: Text(title),
                  content: SizedBox(
                      width: 440,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        if (rows.isEmpty) const Text('还没有可引用的证据。先记录真实经历。'),
                        for (final e in rows)
                          CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(e.text),
                              subtitle:
                                  Text('${e.kind.label} · ${e.status.label}'),
                              value: selected.contains(e.id),
                              onChanged: (v) => update(() {
                                    v == true
                                        ? selected.add(e.id)
                                        : selected.remove(e.id);
                                  })),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, selected.toList()),
                        child: const Text('采用所选'))
                  ],
                )));
  }

  Future<void> _addEvidence() async {
    final r = await _form('补充一条信息', {
      'text': '具体发生了什么，或仍不知道什么？',
      'context': '适用情境 / 信息来源（可选）'
    }, requiredFields: {
      'text'
    }, choices: {
      'kind': {
        for (final k in [
          WmFactKind.fact,
          WmFactKind.belief,
          WmFactKind.feeling,
          WmFactKind.unknown,
          WmFactKind.capability
        ])
          k.name: k.label
      },
      'status': {
        'reported': '本人报告，尚未独立核实',
        'verified': '本人已核实来源',
        'hypothesis': '只是候选解释'
      },
      'when': _timeChoices,
    });
    if (r != null) {
      final happenedAt = await _occurrence(r);
      await _save((c) => _flow.addEvidence(c,
          text: r['text']!,
          kind: WmFactKind.values.byName(r['kind']!),
          status: WmFactStatus.values.byName(r['status']!),
          context: r['context']!,
          happenedAt: happenedAt));
    }
  }

  static const _timeChoices = {
    'unknown': '实际发生时间：暂不确定',
    'now': '刚刚发生',
    'choose': '选择实际发生的日期和时间'
  };
  Future<int?> _occurrence(Map<String, String> value) async {
    if (value['when'] == 'now') return _flow.clock();
    if (value['when'] != 'choose' || !mounted) return null;
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        firstDate: DateTime(1900),
        lastDate: now,
        initialDate: now);
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(now));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute)
        .millisecondsSinceEpoch;
  }

  Future<void> _generate() async {
    final approved = await _chooseEvidence('本次允许发送给已配置 AI 的内容');
    if (approved == null || approved.isEmpty || !mounted) return;
    if (!await _confirm(
        '允许本次远程分析', '仅发送刚才勾选的信息。课题库、原则库和其他记录不随请求发送。将使用应用中已配置的 AI；之后可撤回授权。',
        accept: '允许并分析')) return;
    if (!await _save((c) => c.change({'remoteAllowed': true}))) return;
    final token = ++_generation;
    setState(() {
      _busy = true;
      _notice = '正在整理事实与候选路线…';
    });
    try {
      final endpoint = await _vault.readSetting('v28_decisions_endpoint');
      final access = await _vault.readSetting('v28_decisions_session');
      final uri = Uri.tryParse(endpoint ?? '');
      final decisions =
          uri != null && uri.scheme == 'https' && (access ?? '').isNotEmpty
              ? WmDecisionsClient(endpoint: uri, accessToken: access!)
              : null;
      final result = await WmCaseAi(decisions: decisions).generate(_case!,
          allowedEvidenceIds: approved.toSet(),
          stillAllowed: () =>
              mounted && token == _generation && _case!.remoteAllowed,
          progress: (v) {
            if (mounted && token == _generation) setState(() => _notice = v);
          });
      if (!mounted || token != _generation) return;
      var next = _flow.analyze(_case!, result.analysis);
      if (result.facets != null)
        next = _flow.rank(next,
            facets: result.facets, receipt: result.rankingReceipt);
      final saved =
          await _vault.saveCaseFile(next.change({'remoteAllowed': false}));
      if (mounted)
        setState(() {
          _case = saved;
          _sources[saved.id] = saved;
          _tab = 1;
          _notice = result.rankingReceipt ?? result.analysis.receipt;
        });
    } catch (_) {
      _show('分析未写入。已有记录仍保留，可以离线继续。');
    } finally {
      if (mounted && token == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _revokeRemote() async {
    ++_generation;
    // Revocation is allowed while generation runs. Its response is discarded.
    try {
      final saved =
          await _vault.saveCaseFile(_case!.change({'remoteAllowed': false}));
      if (mounted)
        setState(() {
          _case = saved;
          _busy = false;
          _notice = '后续远程请求已停止，未保存尚未返回的分析。已发送的请求无法收回。';
        });
    } catch (_) {
      _show('授权更新未完成，请重试。当前分析结果已弃用。');
    }
  }

  Future<void> _configureScoring() async {
    final r = await _form(
        '可选：协同评分服务', {'endpoint': 'HTTPS 代理地址', 'token': '你的服务访问令牌'},
        note: '留空即可使用本地排序。这里填写自建评分服务的访问令牌；OpenAI 密钥由服务端保管。',
        initial: {
          'endpoint': await _vault.readSetting('v28_decisions_endpoint') ?? ''
        });
    if (r == null) return;
    final uri = Uri.tryParse(r['endpoint']!);
    if (r['endpoint']!.isNotEmpty &&
        (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty)) {
      _show('请输入不含账号信息的 HTTPS 地址');
      return;
    }
    if (r['token']!.startsWith('sk-')) {
      _show('此处需要你的服务访问令牌，不能填写 OpenAI 密钥');
      return;
    }
    await _vault.writeSetting('v28_decisions_endpoint', r['endpoint']!);
    await _vault.writeSetting('v28_decisions_session', r['token']!);
    _show('已保存在加密 Vault 中。只有你授权分析时才会发送请求。');
  }

  Future<void> _assess(WmRoute route) async {
    final r = await _form(
        '核实：${route.title}',
        {
          'fact': '已核实的条件 / 风险与来源',
          'want': '这是否符合我想要的？（可填未知）',
          'skill': '身体与技能是否匹配？',
          'support': '仍需要的资源或支持'
        },
        requiredFields: {'fact'},
        note: '健康、法律、他人权利或同意方面存在风险时，暂停或先核实；理由排序不能解除这些限制。',
        choices: {
          'gate': {
            for (final g in [WmGate.verifyFirst, WmGate.blocked, WmGate.clear])
              g.name: g.label
          }
        });
    if (r != null)
      await _save((c) => _flow.assessRoute(c, route.id,
          gate: WmGate.values.byName(r['gate']!),
          fact: r['fact']!,
          wantFit: r['want']!.isEmpty ? '未知' : r['want']!,
          capability: r['skill']!.isEmpty ? '未知' : r['skill']!,
          support: r['support']!));
  }

  Future<void> _seal() async {
    final c = _case!;
    final r = await _form(
        '留下事前计划',
        {
          'trigger': '什么真实条件出现时再考虑行动？',
          'ifThen': '如果条件出现，我准备先做什么？',
          'fallback': '条件不足或不安全时，怎样暂停 / 改道？',
          'prediction': '预计会怎样？（可选）',
          'expectation': '得到之后，预计有什么感受？（可选）'
        },
        requiredFields: {'trigger', 'ifThen', 'fallback'},
        choices: {
          'route': {
            'none': '暂不选择路线',
            for (final route in c.analysis.routes) route.id: route.title
          }
        },
        note: '这是计划，真实触发和真实选择尚未发生。封存后不能用事后信息改写。');
    if (r == null) return;
    if (await _save((c) => _flow.seal(c,
        routeId: r['route'] == 'none' ? null : r['route'],
        trigger: r['trigger']!,
        ifThen: r['ifThen']!,
        fallback: r['fallback']!,
        prediction: r['prediction']!,
        expectation: r['expectation']!))) {
      await _reminders.cancel(c.id);
      _show('事前快照已封存，可在现场核实页安排提醒。');
    }
  }

  Future<void> _schedule() async {
    final c = _case!, seal = _flow.activeSeal(_case!);
    if (seal == null) {
      _show('先留下事前计划，再安排提醒');
      return;
    }
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
        initialDate: now);
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))));
    if (time == null) return;
    final at =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final p = wmMap(seal['payload']);
    final uses = c.principleUses
        .where((u) => u['cycle'] == c.cycle && u['status'] == 'active');
    final receipt = await _reminders.schedule(
        WmCaseLink(
            caseId: c.id,
            snapshotId: wmText(seal['id']),
            triggerId: wmText(p['triggerId']),
            principleId:
                uses.isEmpty ? null : wmText(uses.first['principleId'])),
        at);
    await _save((c) => c.change({
          'events': [
            ...c.events.map((e) => e.toJson()),
            WmEvent(
                id: wmId('reminder'),
                kind: 'reminder',
                phase: c.phase,
                recordedAt: _flow.clock(),
                cycle: c.cycle,
                source: 'system',
                data: {
                  'snapshotId': seal['id'],
                  'triggerId': p['triggerId'],
                  'scheduledAt': at.millisecondsSinceEpoch,
                  'receipt': receipt,
                  'delivered': 'unknown',
                  'seen': 'unknown'
                }).toJson()
          ]
        }));
    _show(receipt);
  }

  Future<void> _trigger() async {
    final r = await _form('此刻，真实条件是什么？', {'fact': '实际情况（确认触发时必填）'},
        choices: {
          'status': {
            'unconfirmed': '还没有 / 尚不确定',
            'confirmed': '条件已经出现',
            'changed': '条件发生变化',
            'expired': '机会已过去',
            'cancelled': '我选择取消'
          }
        },
        note: '提醒响起或打开页面，只说明到了查看时间。');
    if (r != null)
      await _save((c) => _flow.trigger(c, r['status']!, r['fact']!,
          happenedAt: _flow.clock()));
  }

  Future<void> _decision() async {
    final routes = _case!.analysis.routes.where((r) => r.canCommit).toList();
    if (routes.isEmpty) {
      _show('先到「理由与路线」核实可用路线；也可以暂停。');
      return;
    }
    final r = await _form('记录此刻的选择', {},
        choices: {
          'route': {for (final r in routes) r.id: r.title},
          'autonomy': {
            'unknown': '自主程度未知',
            'self_chosen': '我自己选择',
            'negotiated': '协商后的选择',
            'pressured': '受到外部压力'
          },
          'opportunity': {
            'unknown': '机会情况未知',
            'available': '有实际机会',
            'restricted': '机会受限'
          },
        },
        note: '这会记录你的决意。行动、完成和外部结果仍需分别记录。');
    if (r != null)
      await _save((c) => _flow.decide(c, r['route']!,
          autonomy: r['autonomy']!, opportunity: r['opportunity']!));
  }

  Future<void> _action(String kind) async {
    final r = await _form(kind == 'preparation' ? '记录已经做过的准备' : '记录一次真实尝试',
        {'text': '具体做了什么？留下了什么痕迹？'},
        requiredFields: {'text'},
        choices: {
          'route': {
            'none': '不归入现有路线 / 另有行动',
            for (final r in _case!.analysis.routes) r.id: r.title
          },
          'when': _timeChoices,
        },
        note: '记录实际发生的内容；后续没有完成，也不会抹去这次付出。');
    if (r != null) {
      final happenedAt = await _occurrence(r);
      await _save((c) => _flow.recordAction(c,
          kind: kind,
          text: r['text']!,
          happenedAt: happenedAt,
          routeId: r['route'] == 'none' ? null : r['route']));
    }
  }

  Future<void> _observe() async {
    final r = await _form('记录本轮现实反馈', {
      'fact': '看到的事实 / 最早出现差异的环节',
      'outcome': '外部结果（未知可留空）',
      'barrier': '实际阻碍 / 资源 / 他人因素（可选）'
    }, requiredFields: {
      'fact'
    }, choices: {
      'status': {
        'unknown': '目前仍未知',
        'completed': '行动完成',
        'partial': '只完成了一部分',
        'not_started': '还未开始',
        'blocked': '遇到阻碍',
        'redirected': '实际改走其他路线',
        'pressured': '在压力下行动'
      },
      'acquired': {
        'unknown': '想要的结果是否得到：未知',
        'yes': '已经得到',
        'partial': '只得到一部分',
        'no': '尚未得到'
      },
      'deviation': {
        'unknown': '最早差异：未知',
        'trigger': '触发条件',
        'awareness': '是否看见或想起',
        'appraisal': '现场判断',
        'decision': '实际选择',
        'attempt': '执行过程',
        'outcome': '外部结果',
        'experience': '得到后的体验'
      },
    });
    if (r != null &&
        await _save((c) => _flow.observe(c,
            status: r['status']!,
            fact: r['fact']!,
            externalOutcome: r['outcome']!.isEmpty ? '未知' : r['outcome']!,
            acquired: r['acquired']!,
            barrier: r['barrier']!,
            earliestDeviation: r['deviation']!))) {
      await _reminders.cancel(_case!.id);
      if (mounted) setState(() => _tab = 3);
    }
  }

  Future<void> _experience() async {
    final r = await _form('得到以后，实际感觉如何？', {'text': '满足、疲惫、失望或仍未知，都可以如实记录'},
        requiredFields: {'text'},
        choices: {
          'window': {
            'initial': '刚发生时',
            'routine': '日常使用一段时间后',
            'sustained': '更长时间后'
          }
        },
        note: '短期兴奋不等于长期适配。未得到的结果也不能用想象代替体验。');
    if (r != null)
      await _save((c) => _flow.followUp(c, r['text']!, window: r['window']!));
  }

  Future<void> _principle([WmPrinciple? old]) async {
    final supports = await _chooseEvidence('选择支撑这条原则的真实经历',
        available: _case!.activeEvidence
            .where((e) => e.factual && e.kind != WmFactKind.statement)
            .map((e) => e.id)
            .toSet(),
        initial: old?.evidenceIds ?? []);
    if (supports == null || supports.isEmpty || !mounted) return;
    final counters = await _chooseEvidence('有哪些反例或限制？没有可以跳过',
        available: _case!.activeEvidence
            .where((e) => e.factual)
            .map((e) => e.id)
            .toSet(),
        initial: old?.counterIds ?? []);
    if (counters == null || !mounted) return;
    final sample =
        _case!.activeEvidence.firstWhere((e) => e.id == supports.first);
    final quote = sample.text.length > 90
        ? '${sample.text.substring(0, 90)}…'
        : sample.text;
    final r = await _form(
        old == null ? '拟一条可检验的个人原则' : '修订原则，保留旧版本',
        {
          'summary': '我目前学到的',
          'condition': '什么条件下适用？',
          'action': '下次可观察的行动',
          'exception': '什么情况不适用或必须停止？',
          'context': '任务与情境范围',
          'test': '下一次怎样验证？'
        },
        requiredFields: {'summary', 'condition', 'action', 'exception', 'test'},
        initial: old == null
            ? {
                'summary': '从这次经历保留一条待检验经验：$quote',
                'condition': '任务条件与这次经历相近，且安全、资源与他人同意均已核实',
                'action': '检查「$quote」中哪些做法可用于下次的小试验，并记录实际结果',
                'exception': '条件不同或出现健康、安全、法律及他人权利风险时，先暂停、改道或求助',
                'context':
                    sample.context.isEmpty ? '仅限与这次经历可比较的具体任务' : sample.context,
                'test': '在下一次可比较情境中记录准备、尝试、结果与反例；不合适就修订或弃用',
              }
            : {
                'summary': old.summary,
                'condition': old.ifCondition,
                'action': old.thenAction,
                'exception': old.exception,
                'context': old.context,
                'test': old.nextTest
              },
        note: '这是关于具体任务的可修订经验，不是固定性格结论。保存后仍需你选择是否认可。');
    if (r != null)
      await _save((c) => _flow.principle(c,
          summary: r['summary']!,
          condition: r['condition']!,
          action: r['action']!,
          exception: r['exception']!,
          evidenceIds: supports,
          counterIds: counters,
          context: r['context']!,
          nextTest: r['test']!,
          principleId: old?.id,
          revisionReason: old == null ? '' : '本人根据经历修订'));
  }

  Future<void> _usePrinciples() async {
    final sources = await _vault.caseFiles();
    if (!mounted) return;
    final options = [
      for (final s in sources)
        for (final p in s.latestPrinciples)
          if (p.status == WmPrincipleStatus.accepted) (s, p)
    ];
    if (options.isEmpty) {
      _show('还没有本人认可的原则。先从真实经历形成候选。');
      return;
    }
    final chosen = await showModalBottomSheet<(WmCase, WmPrinciple)>(
        context: context,
        useSafeArea: true,
        builder: (ctx) => ListView(shrinkWrap: true, children: [
              const ListTile(
                  title: Text('从已认可的原则中选择'), subtitle: Text('选择前不会自动引用其他课题。')),
              for (final pair in options)
                ListTile(
                    title: Text(pair.$2.summary),
                    subtitle: Text(
                        '${pair.$2.context}\n条件：${pair.$2.ifCondition}\n例外：${pair.$2.exception}'),
                    isThreeLine: true,
                    onTap: () => Navigator.pop(ctx, pair)),
            ]));
    if (chosen == null || !mounted) return;
    final (source, p) = chosen;
    if (!await _confirm('核实适用条件',
        '条件：${p.ifCondition}\n例外：${p.exception}\n\n${source.id != _case!.id ? '本次允许引用来源课题的这条原则。授权可撤回。\n' : ''}这些条件现在适用吗？',
        accept: '适用，采用为提醒')) return;
    await _save((c) => _flow.applyPrinciple(
        source.id == c.id
            ? c
            : c.change({
                'allowedSourceCaseIds':
                    {...c.allowedSourceCaseIds, source.id}.toList()
              }),
        source,
        p,
        contextMatches: true));
  }

  Future<void> _boundary() async {
    final selected = await _chooseEvidence('选择需要判断边界的一条事实');
    if (selected == null || selected.length != 1 || !mounted) {
      if (selected != null) _show('请选择一条具体事实');
      return;
    }
    final r = await _form(
        '判断这件事的可改变部分', {'time': '针对哪个时间与任务范围？', 'next': '接下来保护什么、改变什么、寻求何种支持？'},
        requiredFields: {'time', 'next'},
        choices: {
          'class': {
            'uncertain': '未知，需要更多信息',
            'modifiable_now': '现在可改变',
            'modifiable_with_support': '需要训练 / 资源 / 支持',
            'externally_dependent': '依赖他人或外部条件',
            'irreversible_past': '已经发生、不可改写的过去',
            'hard_limit_for_task': '当前特定任务的已核实硬限制',
          }
        },
        note: '接受已经发生的事实不等于放弃改变未来，也不要求忍受侵害。可以退出、求助、维权或更换环境。');
    if (r != null)
      await _save((c) => _flow.changeability(c,
          evidenceId: selected.single,
          classification: r['class']!,
          nextStep: r['next']!,
          timeReference: r['time']!));
  }

  Future<void> _weights() async {
    const names = {
      'personal_fit': '个人适配',
      'evidence_quality': '证据质量',
      'decision_materiality': '对决策的重要性',
      'context_relevance': '当前情境相关性'
    };
    final r = await _form('调整排序权重', names,
        initial: _case!.weights
            .map((k, v) => MapEntry(k, (v * 100).toStringAsFixed(0))),
        note: '填写非负数字，保存时按总和归一。权重不会提高证据可信度，也不会解除风险限制。');
    if (r == null) return;
    final weights = r.map((k, v) => MapEntry(k, double.tryParse(v) ?? -1));
    final sum = weights.values.fold<double>(0, (a, b) => a + b);
    if (weights.values.any((v) => !v.isFinite || v < 0) || sum <= 0) {
      _show('请输入有效的非负数字，且总和大于零');
      return;
    }
    await _save(
        (c) => _flow.weights(c, weights.map((k, v) => MapEntry(k, v / sum))));
  }

  Widget _button(String label, VoidCallback action,
          {bool primary = false, bool enabled = true}) =>
      Padding(
          padding: const EdgeInsets.only(right: 8, top: 8),
          child: primary
              ? FilledButton(
                  onPressed: _busy || !enabled ? null : action,
                  child: Text(label))
              : OutlinedButton(
                  onPressed: _busy || !enabled ? null : action,
                  child: Text(label)));
  Widget _card(String title, List<Widget> children, {String? subtitle}) => Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            if (subtitle != null)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(subtitle)),
            const SizedBox(height: 8),
            ...children,
          ])));
  String _at(int? millis) => millis == null
      ? '未报告'
      : DateTime.fromMillisecondsSinceEpoch(millis)
          .toLocal()
          .toString()
          .substring(0, 16);
  String _route(String id) =>
      _case!.analysis.routes.where((r) => r.id == id).firstOrNull?.title ??
      '已变更的路线';
  String _evidenceText(List<String> ids) => ids
      .map((id) => _case!.evidence.where((e) => e.id == id).firstOrNull)
      .whereType<WmEvidence>()
      .map((e) => e.usable ? e.text : '来源已撤回')
      .join('\n');

  List<Widget> _facts(WmCase c) => [
        _card(
            '从一句话开始',
            [
              Text(c.issue),
              Wrap(children: [
                _button('补充事实 / 信念 / 未知', _addEvidence, primary: true),
                _button('授权 AI 梳理', _generate),
                _button(
                    '本地重新整理',
                    () => _save((c) =>
                        _flow.analyze(c, const WmAnalysisEngine().local(c))))
              ])
            ],
            subtitle: '已保存在本机加密空间。允许不确定，也可以先行动再回来补充。'),
        _card('目前知道什么', [
          for (final e in c.evidence)
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(e.usable ? e.text : '这条信息已撤回'),
                subtitle: Text('${e.kind.label} · ${e.status.label}'),
                children: [
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          '来源：${e.source}\n适用情境：${e.context.isEmpty ? '待补充' : e.context}\n认识时间：${_at(e.knownAt)}\n实际发生：${_at(e.happenedAt)}\n引用 ID：${e.id}')),
                  if (e.usable)
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                if (!await _confirm('撤回这条信息',
                                    '相关分析、快照内容和原则引用将清除或失效。已发送到远程服务的内容无法收回。',
                                    accept: '撤回并清除')) return;
                                ++_generation;
                                try {
                                  await _reminders.cancel(c.id);
                                  await _vault.revokeCaseEvidence(c.id, e.id);
                                  await _load();
                                } catch (_) {
                                  _show('撤回未完成，请重试');
                                }
                              },
                        child: const Text('撤回此证据及其派生内容')),
                ]),
        ]),
        _card('我可能真正想要的', [
          for (final w in c.analysis.wants)
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(w.claim),
                subtitle: const Text('候选解释，可以推翻'),
                children: [
                  Text(
                      '依据：${_evidenceText(w.evidenceIds)}\n反例：${_evidenceText(w.counterIds)}\n另一种解释：${w.alternative}\n下一步检验：${w.nextTest}')
                ]),
          if (c.analysis.wants.isEmpty) const Text('还没有候选解释；可以先补充事实。'),
          ...c.analysis.unknowns.map((v) => Text('待核实：$v')),
        ]),
        ExpansionTile(title: const Text('更多分析设置'), children: [
          _button('协同评分服务', _configureScoring),
          _button('导入旧版经历', _importLegacy)
        ]),
      ];

  Future<void> _importLegacy() async {
    final old = await _vault.evidenceForGoal(_case!.id);
    if (!mounted) return;
    final available = old
        .where((e) => !_case!.evidence.any((n) => n.legacyId == e.id))
        .toList();
    if (available.isEmpty) {
      _show('这个课题没有尚未关联的旧版经历');
      return;
    }
    final picked = await showDialog<WillMirrorLifeEvidence>(
        context: context,
        builder: (ctx) =>
            SimpleDialog(title: const Text('关联已有经历，保留原 ID'), children: [
              for (final e in available)
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, e),
                    child: Text('${e.title}\n${e.note}'))
            ]));
    if (picked != null)
      await _save((c) => _flow.addEvidence(c,
          text: '${picked.title}\n${picked.note}',
          kind: WmFactKind.observation,
          happenedAt: picked.occurredAt,
          legacyId: picked.id,
          context: picked.domain));
  }

  Widget _motive(WmMotive m, WmJson ranking) {
    final detail = wmMap(wmMap(ranking['facets'])[m.id]);
    final selections = wmMaps(ranking['selections']);
    final reason = selections.where((s) => s['motiveId'] == m.id).firstOrNull;
    return ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(m.text),
        subtitle: Text(
            '${m.safetyConcern ? '安全理由 · ' : ''}${m.feedback == 'endorsed' ? '本人认可' : '待核实的理由'}${reason == null ? '' : ' · ${wmText(reason['reason'])}'}'),
        children: [
          Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  '${m.directionByRoute.entries.map((e) => '${_route(e.key)}：${{
                        'support': '支持',
                        'oppose': '反对',
                        'conditional': '有条件',
                        'unknown': '未知'
                      }[e.value]}').join('\n')}\n依据：${_evidenceText(m.evidenceIds)}\n反证：${_evidenceText(m.counterIds)}\n失效条件：${m.falsifier.isEmpty ? '仍需补充' : m.falsifier}\n${_scoreText(detail)}')),
          Wrap(children: [
            _button(
                '符合我', () => _save((c) => _flow.feedback(c, m.id, 'endorsed'))),
            _button(
                '不符合', () => _save((c) => _flow.feedback(c, m.id, 'rejected'))),
            _button(
                '还需核实', () => _save((c) => _flow.feedback(c, m.id, 'verify')))
          ]),
        ]);
  }

  String _scoreText(WmJson detail) {
    final values = wmMap(detail['values']);
    const names = {
      'personal_fit': '个人适配',
      'evidence_quality': '证据质量',
      'decision_materiality': '决策重要性',
      'context_relevance': '情境相关性'
    };
    return '四项评分（0–4）：\n${names.entries.map((e) => '${e.value}：${values[e.key] is num ? (values[e.key] as num).toStringAsFixed(2) : '未知 / 未评分'}').join('\n')}';
  }

  List<Widget> _reasons(WmCase c) {
    final rank = c.rankings.isEmpty ? <String, dynamic>{} : c.rankings.last;
    final ids = wmStrings(rank['topIds']);
    return [
      _card(
          '此刻优先回看的理由 · 最多 5 条',
          [
            Text(c.analysis.receipt),
            if (wmStrings(rank['nearTies']).isNotEmpty)
              const Text('部分理由得分接近，次序并不稳定；应结合证据一起审议。'),
            if (rank['status'] != 'current')
              const Text('信息已变化，请重新排序；旧分数仅保留作历史。'),
            if (ids.isEmpty) const Text('证据不足，暂不强行凑齐推荐。'),
            for (final id in ids)
              if (c.analysis.motives.any((m) => m.id == id))
                _motive(c.analysis.motives.firstWhere((m) => m.id == id), rank),
            Wrap(children: [
              _button('根据当前信息重排', () => _save(_flow.rank)),
              _button('调整权重', _weights)
            ]),
            const Text('这是回看理由的顺序。评分不代表人格、行为概率或客观成功率；安全理由与重要反对理由会优先保留。'),
          ],
          subtitle:
              '来源：${rank['provider'] == 'decisions' ? 'Decisions 协同评分' : '本地可解释规则'} · 第 ${c.cycle} 轮'),
      _card('有哪些路线可以选择', [
        for (final r in c.analysis.routes)
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(r.title),
              subtitle: Text('${r.gate.label} · 难度 ${r.difficulty ?? '未知'}'),
              children: [
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        '下一步：${r.action}\n近期：${r.near}\n远期：${r.far}\n想要程度：${r.wantFit}\n身体 / 技能：${r.capabilityFit}\n外部可行性：${const {
                              'unknown': '未知',
                              'conditional': '取决于条件',
                              'verified': '本人已核实',
                              'infeasible': '当前不可行'
                            }[r.feasibility] ?? '待核实'}\n需要的条件：${r.requirement}\n风险与边界：${r.risk}\n支持：${r.support}\n什么情况需要改道：${r.falsifier}')),
                _button('核实现实条件', () => _assess(r)),
              ]),
        _button('增加另一条路线', () async {
          final r = await _form('另一种可能', {'title': '路线名称', 'action': '具体第一步'},
              requiredFields: {'title', 'action'});
          if (r != null)
            await _save((c) => _flow.addRoute(c, r['title']!, r['action']!));
        }),
        _button('封存本轮事前计划', _seal,
            primary: true, enabled: c.phase == WmPhase.t0),
      ]),
      if (c.analysis.motives.length > 5)
        ExpansionTile(
            title: const Text('再看 6–8 个不同视角'),
            subtitle: const Text('仍来自同一候选池，允许继续比较'),
            children: const WmAnalysisEngine()
                .shortlist(c)
                .take(8)
                .map((m) => _motive(m, rank))
                .toList()),
      ExpansionTile(
          title: Text('完整候选池 · ${c.analysis.motives.length} 条'),
          subtitle: const Text('不足 50 条时如实保留，不靠同义改写凑数'),
          children: c.analysis.motives.map((m) => _motive(m, rank)).toList()),
      if (c.analysis.reframes.isNotEmpty)
        _card('换一种理解，等待现实检验', [
          for (final r in c.analysis.reframes)
            ExpansionTile(
                title: Text(wmText(r['newClaim'])),
                subtitle: const Text('候选理解，尚未验证'),
                children: [
                  Text(
                      '原先理解：${r['oldBelief']}\n依据：${r['basis']}\n反证条件：${r['falsifier']}\n小试验：${r['test']}')
                ])
        ]),
    ];
  }

  String _cue(WmCase c) {
    final seal = _flow.activeSeal(c), p = wmMap(seal?['payload']);
    final uses = c.principleUses
        .where((u) => u['cycle'] == c.cycle && u['status'] == 'active');
    final principle = uses.isEmpty ? null : _sourcePrinciple(uses.first);
    final text = principle != null
        ? '如果${principle.ifCondition}，可尝试${principle.thenAction}。例外：${principle.exception}'
        : seal == null
            ? '先看真实条件，再选一个安全可行的下一步。条件不够可以暂停。'
            : '${wmText(p['ifThen'])}。条件不够时：${wmText(p['fallback'])}';
    return text.length > 120 ? '${text.substring(0, 117)}…' : text;
  }

  List<Widget> _onsite(WmCase c) => [
        if (_flow.activeSeal(c) != null)
          _card('事前留下的计划', [
            Text('真实触发条件：${wmMap(_flow.activeSeal(c)!['payload'])['trigger']}'),
            Text(_cue(c)),
            Wrap(children: [
              _button('安排提醒', _schedule),
              _button('关闭本课题提醒', () async {
                await _reminders.cancel(c.id);
                _show('已关闭提醒；计划仍保留，可随时手动查看。');
              }),
              _button('朗读现场提示', () async {
                try {
                  await _tts.setLanguage('zh-CN');
                  await _tts.speak(_cue(c));
                } catch (_) {
                  _show('设备暂不支持朗读，仍可阅读现场卡');
                }
              }),
              _button('停止朗读', () {
                _tts.stop();
              })
            ]),
          ]),
        _card(
            '先确认现场，再作选择',
            [
              Text(c.stateLabel),
              Wrap(children: [
                _button('核实真实触发', _trigger,
                    primary: true, enabled: c.latest('observation') == null),
                _button('记录我的实际选择', _decision,
                    enabled:
                        c.latest('trigger')?.data['status'] == 'confirmed' &&
                            c.latest('observation') == null)
              ]),
              _button('暂停 / 撤回计划', () async {
                if (await _save(_flow.cancelPlan))
                  await _reminders.cancel(c.id);
              }),
            ],
            subtitle: '可以重新评估、改道或不行动。原计划不会覆盖你的现场判断。'),
        _card(
            '把真实发生的事留下来',
            [
              Wrap(children: [
                _button('已经做过准备', () => _action('preparation')),
                _button('有过一次尝试', () => _action('attempt')),
                _button('记录现实反馈', _observe, primary: true)
              ]),
            ],
            subtitle: '准备、尝试、完成、外部结果分别记录。未达成目标不等于没有付出。'),
        if (c.rankings.isNotEmpty)
          ExpansionTile(
            title: const Text('此刻可重新回看的理由'),
            children: c.analysis.motives
                .where(
                    (m) => wmStrings(c.rankings.last['topIds']).contains(m.id))
                .map((m) => _motive(m, c.rankings.last))
                .toList(),
          ),
        _principleUseCard(c),
      ];

  Widget _principleUseCard(WmCase c) => _card('带到现场的个人原则', [
        _button('选择已认可的原则', _usePrinciples),
        if (c.principleUses
                .where((u) => u['cycle'] == c.cycle && u['status'] == 'active')
                .length >
            1)
          const Text('多条原则可能相互冲突。先比较条件和例外，再自行选择，不需要同时遵从。'),
        for (final u in c.principleUses.where((u) => u['cycle'] == c.cycle))
          ExpansionTile(
              title: Text(_principleTitle(u)),
              subtitle: Text(u['status'] == 'active'
                  ? '想起：${_useLabel(u['recall'])} · 应用：${_useLabel(u['application'])}'
                  : '来源或版本已失效，需重新选择'),
              children: [
                Text(_principleDetail(u)),
                Text(
                    '看见、想起、采用与结果分别记录；因果影响仍未知。${u['retrospectiveRecall'] == null ? '' : '\n事后回忆：${u['retrospectiveRecall']}'}'),
                if (u['status'] == 'active')
                  Wrap(children: [
                    _button(
                        c.phase == WmPhase.t0
                            ? '准备时回看过'
                            : c.phase == WmPhase.t1
                                ? '现场确实想起'
                                : '事后回忆曾想起',
                        () => _save((c) => _flow.checkPrinciple(
                            c, wmText(u['id']),
                            recall: 'explicitly_recalled'))),
                    _button(
                        '没有想起',
                        () => _save((c) => _flow.checkPrinciple(
                            c, wmText(u['id']),
                            recall: 'not_recalled'))),
                    _button(
                        '具体行动中用到了',
                        () => _save((c) => _flow.checkPrinciple(
                            c, wmText(u['id']),
                            application: 'applied_self_report'))),
                    _button(
                        '没有采用',
                        () => _save((c) => _flow.checkPrinciple(
                            c, wmText(u['id']),
                            application: 'not_applied'))),
                    _button('撤回来源授权', () async {
                      await _reminders.cancel(c.id);
                      await _save((c) =>
                          _flow.revokeSource(c, wmText(u['sourceCaseId'])));
                    }),
                  ]),
              ]),
      ]);

  WmPrinciple? _sourcePrinciple(WmJson u) => _sources[wmText(u['sourceCaseId'])]
      ?.principles
      .where(
          (p) => p.id == u['principleId'] && p.version == u['principleVersion'])
      .firstOrNull;
  String _principleTitle(WmJson u) => u['status'] != 'active'
      ? '原则引用已失效'
      : _sourcePrinciple(u)?.summary ?? '原则来源待核实';
  String _principleDetail(WmJson u) {
    final p = _sourcePrinciple(u);
    return p == null || u['status'] != 'active'
        ? '请重新选择有效来源。'
        : '版本 ${p.version}\n如果：${p.ifCondition}\n那么：${p.thenAction}\n例外：${p.exception}';
  }

  String _useLabel(Object? v) =>
      const {
        'unknown': '未知',
        'explicitly_recalled': '本人报告已想起',
        'not_recalled': '没有想起',
        'applied_self_report': '本人报告已采用',
        'not_applied': '没有采用',
        'context_changed': '情境已变'
      }[v] ??
      '待核实';

  List<Widget> _review(WmCase c) => [
        _card(
            '结果之后，继续认识自己',
            [
              _button('补充后续体验', _experience,
                  primary: true, enabled: c.latest('observation') != null),
              _button('整理现实边界与可改变部分', _boundary),
              _button('用新信息开始下一轮', () async {
                if (await _confirm('开始下一轮', '保留已有准备、尝试和结果。下一轮会留下新的事前快照。')) {
                  await _reminders.cancel(c.id);
                  if (await _save(_flow.nextCycle)) setState(() => _tab = 0);
                }
              }),
            ],
            subtitle: '可以努力后仍失败、受限而改道，或得到以后发现并不满足。先找具体环节与条件。'),
        _card('可检验的个人原则', [
          _button('从真实经历拟一条原则', () => _principle(), primary: true),
          for (final p in c.latestPrinciples)
            ExpansionTile(
                title: Text(p.summary),
                subtitle: Text('v${p.version} · ${p.status.label}'),
                children: [
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          '条件：${p.ifCondition}\n行动：${p.thenAction}\n例外：${p.exception}\n适用范围：${p.context}\n依据：${_evidenceText(p.evidenceIds)}\n反例：${_evidenceText(p.counterIds)}\n下次检验：${p.nextTest}\n成熟度：仍是可修订经验')),
                  if (p.status != WmPrincipleStatus.revoked)
                    Wrap(children: [
                      _button(
                          '我认可这版',
                          () => _save((c) => _flow.principleStatus(
                              c, p, WmPrincipleStatus.accepted))),
                      _button('修订 / 补充反例', () => _principle(p)),
                      _button(
                          '不适用',
                          () => _save((c) => _flow.principleStatus(
                              c, p, WmPrincipleStatus.rejected))),
                      _button(
                          '归档',
                          () => _save((c) => _flow.principleStatus(
                              c, p, WmPrincipleStatus.retired))),
                    ]),
                  Text(
                      '历史版本：${c.principles.where((v) => v.id == p.id).map((v) => 'v${v.version} ${v.status.label}').join(' → ')}'),
                ]),
        ]),
        _principleUseCard(c),
        _card('同一课题的真实历程', [
          for (final s in c.snapshots)
            ExpansionTile(
                title: Text('第 ${s['cycle']} 轮 · 事前快照'),
                subtitle: Text(s['status'] == 'redacted_due_to_revocation'
                    ? '来源已撤回，内容已清除'
                    : WmWorkflow.verifySeal(s)
                        ? '完整性核验通过 · ${s['status']}'
                        : '完整性异常'),
                children: [
                  SelectableText(const JsonEncoder.withIndent('  ').convert(s))
                ]),
          for (final e in c.events.reversed)
            ExpansionTile(
                title: Text('第 ${e.cycle} 轮 · ${_eventLabel(e.kind)}'),
                subtitle: Text('${e.phase.label} · 记录于 ${_at(e.recordedAt)}'),
                children: [
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          '实际发生：${_at(e.happenedAt)}\n${_evidenceText(e.evidenceIds)}')),
                  SelectableText(
                      const JsonEncoder.withIndent('  ').convert(e.data)),
                ]),
        ]),
      ];

  String _eventLabel(String kind) =>
      const {
        'analysis': '分析版本',
        'motive_feedback': '理由反馈',
        'route_assessment': '条件核实',
        'pause': '主动暂停',
        'trigger': '现场触发核实',
        'decision': '实际选择',
        'preparation': '已做准备',
        'attempt': '真实尝试',
        'observation': '现实结果',
        'experience': '后续体验',
        'changeability': '现实边界',
        'reminder': '提醒登记'
      }[kind] ??
      kind;

  @override
  Widget build(BuildContext context) {
    final c = _case;
    return Scaffold(
        appBar: AppBar(title: const Text('意志之镜 · 我的课题'), actions: [
          if (c != null)
            IconButton(
                tooltip: '删除这个课题',
                icon: const Icon(Icons.delete_outline),
                onPressed: _busy
                    ? null
                    : () async {
                        if (!await _confirm('删除整个课题',
                            '将删除这个课题及同一目标下的旧版经历、快照与原则，并使跨课题引用失效。此操作不可撤销。',
                            accept: '删除')) return;
                        try {
                          await _reminders.cancel(c.id);
                          await _vault.deleteCaseFile(c.id);
                          if (context.mounted) Navigator.pop(context);
                        } catch (_) {
                          _show('删除未完成，请重试');
                        }
                      })
        ]),
        body: _error != null
            ? Center(
                child: Padding(
                    padding: const EdgeInsets.all(24), child: Text(_error!)))
            : c == null
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                    child: Column(children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('第 ${c.cycle} 轮 · ${c.stateLabel}'))),
                    SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          for (final (i, label)
                              in ['事实与想要', '理由与路线', '现场核实', '回访与原则'].indexed)
                            Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                    label: Text(label),
                                    selected: _tab == i,
                                    onSelected: (_) =>
                                        setState(() => _tab = i)))
                        ])),
                    if (_busy) const LinearProgressIndicator(),
                    if (_notice != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(_notice!,
                              maxLines: 4, overflow: TextOverflow.ellipsis)),
                    if (c.remoteAllowed)
                      TextButton(
                          onPressed: _revokeRemote,
                          child: const Text('撤回远程授权 / 停止本次分析')),
                    Expanded(
                        child: ListView(
                            key: ValueKey('wm_v28_tab_$_tab'),
                            padding: const EdgeInsets.all(16),
                            children: switch (_tab) {
                              0 => _facts(c),
                              1 => _reasons(c),
                              2 => _onsite(c),
                              _ => _review(c)
                            })),
                  ])));
  }
}

class WmCaseLibraryPage extends StatefulWidget {
  const WmCaseLibraryPage({super.key, required this.vault});
  final WillMirrorVault vault;
  @override
  State<WmCaseLibraryPage> createState() => _WmCaseLibraryPageState();
}

class _WmCaseLibraryPageState extends State<WmCaseLibraryPage> {
  List<WillMirrorGoal>? _goals;
  List<WmCase> _cases = [];
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final goals = await widget.vault.goals();
      final cases = await widget.vault.caseFiles();
      if (mounted)
        setState(() {
          _goals = goals;
          _cases = cases;
        });
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法读取加密课题库');
    }
  }

  Future<void> _open(WillMirrorGoal goal) async {
    try {
      var c = await widget.vault.caseFile(goal.id);
      if (c == null) {
        c = WmWorkflow().start(goal.id, goal.text, createdAt: goal.createdAt);
        await widget.vault.saveCaseFile(c);
      }
      if (!mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) =>
                  WmCasePage(caseId: goal.id, vault: widget.vault)));
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('打开未完成，请重试。原有记录仍保留。')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('我的课题与经历')),
      body: _error != null
          ? Center(child: Text(_error!))
          : _goals == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(16), children: [
                  const Text('每个课题保留多轮准备、行动与现实反馈。旧版目标沿用原 ID，打开后可按需关联已有经历。'),
                  if (_goals!.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('还没有课题，从首页的一句话开始。')),
                  for (final g in _goals!)
                    Card(
                        child: ListTile(
                            title: Text(g.text),
                            subtitle: Text(_cases
                                    .where((c) => c.id == g.id)
                                    .firstOrNull
                                    ?.stateLabel ??
                                '已有目标 · 可继续为完整课题'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _open(g))),
                ]));
}
