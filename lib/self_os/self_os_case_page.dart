import 'dart:convert';
import 'package:flutter/material.dart';
import 'self_os_ai_service.dart';
import 'self_os_engine.dart';
import 'self_os_models.dart';
import 'self_os_repository.dart';
import 'self_os_widgets.dart';
import 'self_os_workbench.dart';
import 'self_os_workbench_widgets.dart';
import 'self_os_action_focus.dart';
import 'self_os_v37_rules.dart';
import 'self_os_insights.dart';

class SelfOsCasePage extends StatefulWidget {
  const SelfOsCasePage(
      {super.key,
      required this.value,
      required this.repository,
      required this.ai,
      required this.history,
      required this.profile,
      this.initialEngine,
      this.initialWorkspace});
  final SelfOsCase value;
  final SelfOsRepository repository;
  final SelfOsAiService ai;
  final List<SelfOsCase> history;
  final SelfOsProfile profile;
  final SelfOsEngine? initialEngine;
  final int? initialWorkspace;
  @override
  State<SelfOsCasePage> createState() => _SelfOsCasePageState();
}

class _SelfOsCasePageState extends State<SelfOsCasePage> {
  late SelfOsCase _c = widget.value.copy();
  late SelfOsEngine _engine =
      widget.initialEngine ?? SelfOsEngineService.next(_c).engine;
  late SelfOsProfile _profile = SelfOsProfile.fromJson(widget.profile.toJson());
  late List<SelfOsCase> _allCases = widget.history;
  late bool _workspace = widget.initialWorkspace != null ||
      (widget.initialEngine == null &&
          !_c.retrospective &&
          !_c.reviewed &&
          _c.committedAt == null);
  late int _workspaceTab = widget.initialWorkspace ?? 0;
  bool _profileDirty = false;
  @override
  void initState() {
    super.initState();
    if (!_c.retrospective) {
      _c.v37.ensureCurrentRoute(_c.problem, _c.text('means'));
      if (_c.routeStatus == 'active' && _profile.activeCaseId.isEmpty) {
        _c.v37.routes.first.data['status'] = 'active';
        _profile.activeCaseId = _c.id;
        _profile.activeRouteId = _c.v37.routes.first.id;
        _profileDirty = true;
      }
    }
  }

  bool _saving = false,
      _busy = false,
      _allowPop = false,
      _showAllMotives = false;
  int _revision = 0, _request = 0;
  String? _error;
  String _aiProgress = '';
  List<SelfOsCase> get _history =>
      [..._allCases.where((v) => v.id != _c.id), _c];

  Future<bool> _save({bool notify = false}) async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      if (_profileDirty) {
        await widget.repository.saveCaseAndProfile(_c, _profile);
        _profileDirty = false;
      } else {
        await widget.repository.saveCase(_c);
      }
      if (!mounted) return false;
      setState(() {
        _saving = false;
        _error = null;
      });
      if (notify) osMessage(context, '案例已保存到本机');
      return true;
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = '保存失败，填写内容仍在当前页面。请重试保存。';
        });
      return false;
    }
  }

  void _pop() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _leave() async {
    if (_saving) return;
    _request++;
    if (_busy) setState(() => _busy = false);
    if (await _save() && mounted) _pop();
  }

  Future<void> _switch(SelfOsEngine engine) async {
    if (_busy || _saving || (engine == _engine && !_workspace)) return;
    FocusScope.of(context).unfocus();
    if (await _save() && mounted)
      setState(() {
        _engine = engine;
        _workspace = false;
      });
  }

  Future<void> _openWorkspace(int tab) async {
    if (_busy || _saving) return;
    if (await _save() && mounted)
      setState(() {
        _workspace = true;
        _workspaceTab = tab;
      });
  }

  Widget _workbenchLink(String label, int tab) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
          onPressed: () => _openWorkspace(tab),
          icon: const Icon(Icons.hub_outlined),
          label: Text(label)));

  Future<void> _updateProfile(SelfOsProfile profile) async {
    try {
      await widget.repository.saveProfile(profile);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      if (mounted) osMessage(context, '个人模型保存失败，原有记录仍保留');
    }
  }

  Future<void> _routeState(OsRoute route, String status) async {
    final v = await osRecordEditor(context,
        title: status == 'active' ? '收束为当前主线' : '调整路线投入方式',
        note: '主线只有一条。承认其他路径的真实价值，记录改变的依据；旧主线可以保留或按证据修订。',
        fields: const [
          OsInput('reason', '依据哪些真实信息作出选择？', required: true),
          OsInput('sacrifice', '让位的未来仍有什么真实价值？', required: true),
          OsInput('opportunityCost', '我将失去、减少或推迟什么？', required: true),
          OsInput('trigger', '这次转向主要由什么推动？',
              options: {
                'evidence': '新的能力、结果、代价或现实机会证据',
                'novelty': '新鲜感',
                'comparison': '别人的成功 / 羡慕',
                'escape': '逃离当前不适',
                'unknown': '仍不确定'
              },
              required: true),
          OsInput('accepted', '我已比较原主线，并接受机会成本', kind: 'bool'),
          OsInput('reviewWhen', '什么新证据出现时复审？', required: true),
        ]);
    if (v == null || !mounted) return;
    if (!await _save() || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.transitionRoute(_c, route.id, status, v);
      final cases = await widget.repository.loadCases();
      final profile = await widget.repository.loadProfile();
      if (mounted)
        setState(() {
          _allCases = cases;
          _c = cases.firstWhere((c) => c.id == _c.id);
          _profile = profile;
          _revision++;
        });
    } catch (e) {
      if (mounted)
        osMessage(context, e is FormatException ? e.message : '路线未保存，请重试');
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _runAi(String task) async {
    if (_busy || _saving || !await _save() || !mounted) return;
    final ticket = ++_request;
    final input = _c.copy();
    setState(() {
      _busy = true;
      _error = null;
      _aiProgress = task == 'motives' ? '搜索动机空间 · 第 1 / 3 批' : '结合当前材料提出候选…';
    });
    try {
      if (task.startsWith('v37.')) {
        final value = await widget.ai
            .analyseV37(input, _history, _profile, task.substring(4));
        if (!mounted || ticket != _request) return;
        _c.v37.pendingProposal = value.data;
      } else if (task == 'desires') {
        final values = await widget.ai.discover(input, _history);
        if (!mounted || ticket != _request) return;
        final titles = _c.desires.map((d) => d.title).toSet();
        _c.desires.addAll(values.where((d) => titles.add(d.title)));
      } else if (task == 'motives') {
        final values = await widget.ai.motives(input, _history,
            isCancelled: () => !mounted || ticket != _request,
            progress: (batch) {
              if (mounted && ticket == _request)
                setState(() => _aiProgress = '动机搜索已完成 $batch / 3 批，正在去重与排序');
            });
        if (!mounted || ticket != _request) return;
        // Preserve the user's selections, edits and counter-motives.
        final titles = _c.motives.map((m) => m.title).toSet();
        _c.motives.addAll(values.where((m) => titles.add(m.title)));
      } else {
        final values = await widget.ai.suggest(input, _history, task);
        if (!mounted || ticket != _request) return;
        _c.suggestions[task] = values;
      }
      setState(() {
        _busy = false;
        _revision++;
      });
      await _save();
    } catch (e) {
      if (mounted && ticket == _request)
        setState(() {
          _busy = false;
          _error = e is FormatException
              ? e.message
              : 'AI 暂时不可用。请检查应用设置中的模型、API 配置或网络后重试；也可以继续手动记录，已保存内容不受影响。';
        });
    }
  }

  Widget _field(String key, String label, {String? hint, int lines = 2}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
            key: ValueKey('self_os_field_${key}_$_revision'),
            initialValue: _c.text(key),
            decoration: InputDecoration(
                labelText: label, hintText: hint, counterText: ''),
            minLines: lines,
            maxLines: lines + 3,
            maxLength: 6000,
            onChanged: (v) {
              if (key == 'k2' || key == 'newInformation') _c.beginCognition();
              if (key == 'newInformation')
                _c.v37.settings['newInformationReviewed'] = false;
              _c.fields[key] = v;
            }),
      );
  Widget _score(String key, String label, {double max = 100, String? help}) =>
      OsScore(
          label: label,
          value: _c.scores[key],
          max: max,
          help: help,
          onChanged: (v) => setState(() {
                if (v == null) {
                  _c.scores.remove(key);
                } else {
                  _c.scores[key] = v;
                }
              }));
  Widget _choice(String key, String label, Map<String, String> values) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
              key: ValueKey('self_os_choice_${key}_$_revision'),
              isExpanded: true,
              initialValue:
                  values.containsKey(_c.text(key)) ? _c.text(key) : null,
              decoration: InputDecoration(labelText: label),
              items: values.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _c.fields[key] = v ?? '')));
  Widget _aiButton(String label, String task) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
          onPressed: _busy || _saving ? null : () => _runAi(task),
          icon: const Icon(Icons.auto_awesome_outlined, size: 18),
          label: Text(label)));

  List<Widget> _suggestions(String task) => (_c.suggestions[task] ?? [])
      .map((s) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFF4F5EE),
              borderRadius: BorderRadius.circular(12)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AI 候选 · ${s['kind']}',
                style: const TextStyle(color: osGold, fontSize: 12)),
            const SizedBox(height: 6),
            Text(osText(s['value']), style: const TextStyle(height: 1.6)),
            Text('依据：${s['reason']}',
                style: const TextStyle(fontSize: 12, height: 1.5)),
            TextButton(
                onPressed: () async {
                  final field = osText(s['field']);
                  if (_c.text(field).trim().isNotEmpty) {
                    final yes = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                                title: const Text('替换这项已有内容？'),
                                content: Text('候选内容：${s['value']}'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('保留原内容')),
                                  FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('采用候选'))
                                ]));
                    if (yes != true || !mounted) return;
                  }
                  setState(() {
                    _c.fields[field] = osText(s['value']);
                    _revision++;
                  });
                },
                child: const Text('采用到草稿，再由我修订')),
          ])))
      .toList();

  @override
  Widget build(BuildContext context) => SelfOsTheme(
          child: PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          appBar: AppBar(
              leading: IconButton(
                  tooltip: '保存并返回',
                  onPressed: _saving ? null : _leave,
                  icon: const Icon(Icons.arrow_back)),
              title: Text(_workspace ? '选择的地图' : _engine.label),
              actions: [
                TextButton(
                    onPressed:
                        _saving || _busy ? null : () => _save(notify: true),
                    child: Text(_saving ? '保存中' : '保存'))
              ]),
          body: Column(children: [
            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                          key: const ValueKey('open_workbench'),
                          label: const Text('选择的地图'),
                          selected: _workspace,
                          onSelected: _busy || _saving
                              ? null
                              : (_) => _openWorkspace(_workspaceTab))),
                  ...SelfOsEngine.values
                      .map((e) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                              label: Text('${e.index + 1}  ${e.label}'),
                              selected: e == _engine && !_workspace,
                              onSelected:
                                  _busy || _saving ? null : (_) => _switch(e))))
                      .toList()
                ])),
            if (_busy)
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(children: [
                    const LinearProgressIndicator(),
                    Row(children: [
                      Expanded(
                          child: Text(_aiProgress,
                              style: const TextStyle(fontSize: 12))),
                      TextButton(
                          onPressed: () => setState(() {
                                _request++;
                                _busy = false;
                              }),
                          child: const Text('停止等待'))
                    ])
                  ])),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: OsNote(_error!, icon: Icons.error_outline)),
            Expanded(
                child: AbsorbPointer(
                    absorbing: _busy || _saving,
                    child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 820),
                            child: ListView(
                                key: ValueKey(_workspace
                                    ? 'self_os_workbench'
                                    : 'self_os_engine_${_engine.name}'),
                                padding:
                                    const EdgeInsets.fromLTRB(20, 18, 20, 30),
                                children: [
                                  Text(_c.problem,
                                      style: const TextStyle(
                                          fontSize: 22,
                                          height: 1.4,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 10),
                                  Text(
                                      '第 ${_c.round} 轮 · ${_c.evidenceLevel} · ${_c.statusLabel}',
                                      style: const TextStyle(
                                          fontSize: 12, color: osGold)),
                                  const SizedBox(height: 14),
                                  OsNote(SelfOsEngineService.next(_c).reason,
                                      icon: Icons.route_outlined),
                                  if (_workspace)
                                    SelfOsWorkbench(
                                      value: _c,
                                      profile: _profile,
                                      history: _history,
                                      initialSection: _workspaceTab,
                                      onChanged: () async {
                                        setState(() {});
                                        return _save();
                                      },
                                      onAi: _runAi,
                                      onEngine: _switch,
                                      onRouteState: _routeState,
                                      onProfile: _updateProfile,
                                    )
                                  else
                                    ...[
                                      _desire,
                                      _motivation,
                                      _cognition,
                                      _action,
                                      _mirror
                                    ][_engine.index](),
                                  if (!_workspace &&
                                      _engine != SelfOsEngine.mirror)
                                    FilledButton.icon(
                                        onPressed: () => _switch(SelfOsEngine
                                            .values[_engine.index + 1]),
                                        icon: const Icon(Icons.arrow_forward,
                                            size: 18),
                                        label: Text(
                                            '保存并前往${SelfOsEngine.values[_engine.index + 1].label}')),
                                  const SizedBox(height: 16),
                                  const Text(
                                      '点击 AI 按钮时，将当前材料及本模块相关历史交给应用设置中的 AI 服务。所有候选由你确认；手动记录随时可用。',
                                      style: TextStyle(
                                          fontSize: 11,
                                          height: 1.5,
                                          color: Color(0xFF6D7C70))),
                                ]))))),
          ]),
        ),
      ));

  List<Widget> _desire() => [
        _workbenchLink('把欲求带入选择空间', 0),
        OsSection(
            title: '先辨别阻塞，再决定方向',
            subtitle: '欲求、手段、认识、环境，可以给出完全不同的下一步。',
            children: [
              DropdownButtonFormField<String>(
                  initialValue: _c.blocker,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '当前更接近哪一种情况？'),
                  items: selfOsBlockers.entries
                      .map((e) => DropdownMenuItem(
                          value: e.key,
                          child:
                              Text(e.value, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _c.blocker = v ?? 'unknown')),
              const SizedBox(height: 14),
              _aiButton('帮助辨别阻塞原因', 'diagnosis'),
              ..._suggestions('diagnosis'),
              _field('blockerSuggestion', '诊断依据与仍待确认的问题'),
              _field('goal', '表面目标是什么？', hint: '例如：参加明天的面试'),
              _field('means', '它是实现什么欲求的手段？'),
              _field('alternativeMeans', '还有哪些可能适合我的路径？'),
              _choice('ownership', 'Should / Could / Mine', const {
                'should': '别人或社会认为我应该',
                'could': '别人能做到，我也想试试',
                'mine': '我愿意长期承担代价的选择',
                'unknown': '暂时无法确定'
              }),
            ]),
        OsSection(
            title: '当前欲求假设',
            subtitle: '来源、支持、反证和置信度一起保留。可以确认、拒绝或修改。置信度是候选估计。',
            children: [
              _aiButton('AI 独立分析 · 5–10 个候选', 'desires'),
              if (_c.desires.isEmpty)
                const OsNote('还没有假设。可以让 AI 从原始问题独立分析，也可以先写下自己的理解。'),
              ..._c.desires.map(_desireCard),
              TextButton.icon(
                  onPressed: () => _editDesire(),
                  icon: const Icon(Icons.add),
                  label: const Text('添加我的欲求假设')),
            ]),
        OsSection(
            title: 'Why Tree · 我的理解',
            subtitle: '继续追问、分支或合并已有理由。删除节点即回退，其他理由会保留。',
            children: [
              for (final node in _c.whyTree)
                Container(
                    margin: EdgeInsets.only(
                        left: node.parents.isEmpty ? 0 : 12, bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        border: Border(
                            left: BorderSide(
                                color: node.parents.length > 1
                                    ? osGold
                                    : const Color(0xFFBDCEC0),
                                width: 3))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (node.parents.isNotEmpty)
                            Text(
                                '${node.parents.length > 1 ? '合并' : '追问'}：${_c.whyTree.where((n) => node.parents.contains(n.id)).map((n) => n.answer).join(' + ')}',
                                style: const TextStyle(
                                    fontSize: 11, color: osGold)),
                          Text(node.question,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF68786E))),
                          Text(node.answer,
                              style: const TextStyle(height: 1.6)),
                          Wrap(children: [
                            TextButton(
                                onPressed: () => _addWhy([node.id]),
                                child: const Text('继续追问')),
                            TextButton(
                                onPressed: () async {
                                  final values = await osEditDialog(context,
                                      title: '修订理由',
                                      labels: const {'answer': '我的回答'},
                                      initial: {'answer': node.answer},
                                      requiredFields: {'answer'});
                                  if (values != null && mounted)
                                    setState(
                                        () => node.answer = values['answer']!);
                                },
                                child: const Text('修订')),
                            TextButton(
                                onPressed: () =>
                                    setState(() => _c.removeWhy(node.id)),
                                child: const Text('回退此节点'))
                          ]),
                        ])),
              TextButton.icon(
                  onPressed: () => _addWhy([]),
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('新增理由 / 合并分支')),
              _aiButton('对照 AI 与我的两种视角', 'compare'),
              ..._suggestions('compare'),
              _field('perspectiveComparison', '重合、独有与冲突'),
            ]),
        OsSection(title: '适配与真实代价', children: [
          _field('costs', '如果要付出这些代价，我仍愿意吗？', hint: '等待、失败、持续学习、减少娱乐、搬迁、不确定性…'),
          _score('desireStrength', '当前欲求强度'),
          _score('costAcceptance', '口头代价接受度'),
          if (_c.scores['desireStrength'] != null &&
              _c.scores['costAcceptance'] != null)
            OsNote(
                '目标可信度的暂估：${(_c.scores['desireStrength']! * _c.scores['costAcceptance']! / 100).round()} / 100（主观欲求强度 × 口头代价接受度）。等待真实选择校准。'),
          _score('goalFit', '目标与深层欲求的匹配'),
          _score('generalValue', '通常意义上的价值'),
          _score('personalFit', '对我的个人适配'),
          _field('fitEvidence', '能力、偏好与条件的支持 / 反证'),
        ]),
      ];

  Widget _desireCard(SelfOsDesire d) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: d.accepted ? const Color(0xFFEEF4EB) : const Color(0xFFF7F7F2),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(d.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16))),
          IconButton(
              tooltip: '修改欲求假设',
              onPressed: () => _editDesire(d),
              icon: const Icon(Icons.edit_outlined, size: 18))
        ]),
        Text(
            '${d.source} · 候选置信 ${d.confidence == null ? '未知' : '${d.confidence!.round()}%'}',
            style: const TextStyle(fontSize: 12, color: osGold)),
        const SizedBox(height: 8),
        Text(
            '支持：${d.support.isEmpty ? '尚无记录' : d.support}\n反证 / 缺失：${d.counter.isEmpty ? '尚未检验' : d.counter}\n待验证：${d.question.isEmpty ? '需要一次现实检验' : d.question}',
            style: const TextStyle(height: 1.6, fontSize: 13)),
        Wrap(
            spacing: 6,
            children: const {
              'pending': '待验证',
              'accepted': '暂时认可',
              'rejected': '不认同'
            }
                .entries
                .map((e) => ChoiceChip(
                    label: Text(e.value),
                    selected: d.verdict == e.key,
                    onSelected: (_) => setState(() => d.verdict = e.key)))
                .toList()),
        DropdownButtonFormField<String>(
            initialValue: const [
              'uncompared',
              'overlap',
              'partial',
              'aiOnly',
              'userOnly',
              'conflict'
            ].contains(d.comparison)
                ? d.comparison
                : 'uncompared',
            decoration: const InputDecoration(labelText: '与我的 Why Tree 对照'),
            isExpanded: true,
            items: const {
              'uncompared': '尚未对照',
              'overlap': '重合',
              'partial': '部分重合',
              'aiOnly': 'AI 独有',
              'userOnly': '我的理解独有',
              'conflict': '存在冲突'
            }
                .entries
                .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => d.comparison = v ?? 'uncompared')),
      ]));

  Future<void> _editDesire([SelfOsDesire? desire]) async {
    final d = desire ?? SelfOsDesire();
    final values = await osEditDialog(context,
        title: desire == null ? '添加欲求假设' : '修订欲求假设',
        labels: const {
          'title': '我可能真正想要什么',
          'support': '支持证据',
          'counter': '反证 / 缺失信息',
          'question': '待验证问题',
          'confidence': '候选置信度 0–100（可留空）'
        },
        initial: {
          'title': d.title,
          'support': d.support,
          'counter': d.counter,
          'question': d.question,
          'confidence': d.confidence?.round().toString() ?? ''
        },
        requiredFields: {
          'title'
        });
    if (values == null || !mounted) return;
    setState(() {
      d.title = values['title']!;
      d.support = values['support']!;
      d.counter = values['counter']!;
      d.question = values['question']!;
      d.confidence = osNumber(values['confidence']);
      if (desire == null) {
        _c.desires.add(d);
      } else if (d.source == 'AI 独立假设') {
        d.source = 'AI 假设 · 用户修订';
      }
    });
  }

  Future<void> _addWhy(List<String> parents) async {
    final node = await showDialog<SelfOsWhyNode>(
        context: context,
        builder: (_) => _WhyDialog(nodes: _c.whyTree, parents: parents));
    if (node != null && mounted) setState(() => _c.addWhy(node));
  }

  List<Widget> _motivation() {
    final fingerprint = SelfOsEngineService.motiveFingerprint(_history);
    final sorted = [..._c.motives]..sort((a, b) {
        if (a.selected != b.selected) return a.selected ? -1 : 1;
        return SelfOsEngineService.motiveRank(b, fingerprint)
            .compareTo(SelfOsEngineService.motiveRank(a, fingerprint));
      });
    return [
      OsSection(
          title: '让正反动机同时在场',
          subtitle: '不想做的理由同样值得理解。候选先聚类，再由你选择最可能在现场生效的几项。',
          children: [
            _aiButton('AI 搜索 60 个动机 · 分 3 批生成', 'motives'),
            Text(
                '已选正方 ${_c.motives.where((m) => m.selected && m.side == 'for').length} 项 / 反方 ${_c.motives.where((m) => m.selected && m.side == 'against').length} 项 · 共 ${_c.motives.length} 个候选',
                style: const TextStyle(fontSize: 12, color: osGold)),
            const SizedBox(height: 8),
            for (final side in ['for', 'against']) ...[
              Text(side == 'for' ? '为什么想做' : '为什么不想做',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              ...(_showAllMotives
                      ? sorted.where((m) => m.side == side)
                      : sorted.where((m) => m.side == side).take(8))
                  .map((m) {
                final history =
                    fingerprint.where((f) => f.label == m.type).toList();
                return Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                        color: m.selected
                            ? const Color(0xFFEEF4EB)
                            : const Color(0xFFF8F8F4),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                              value: m.selected,
                              onChanged: (v) =>
                                  setState(() => m.selected = v ?? false),
                              title: Text(m.title),
                              subtitle: Text(
                                  '${m.type} · ${m.layer}\n${m.kind} · ${m.source}',
                                  style: const TextStyle(fontSize: 11)),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true),
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(m.reason,
                                  style: const TextStyle(
                                      fontSize: 12, height: 1.5))),
                          Padding(
                              padding: const EdgeInsets.fromLTRB(14, 5, 14, 0),
                              child: Text(
                                  '候选预测 ${m.predicted == null ? '未知' : '${m.predicted!.round()}%'} · 历史影响 ${history.isEmpty ? '暂无' : '${history.first.helped}/${history.first.total} 次'}',
                                  style: const TextStyle(
                                      fontSize: 11, color: osGold))),
                          TextButton(
                              onPressed: () => _editMotive(m.side, m),
                              child: const Text('编辑 / 可信度与现场在场度')),
                        ]));
              }),
              TextButton.icon(
                  onPressed: () => _editMotive(side),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(side == 'for' ? '添加正方动机' : '添加反方动机')),
            ],
            if (_c.motives.length > 16)
              TextButton(
                  onPressed: () =>
                      setState(() => _showAllMotives = !_showAllMotives),
                  child: Text(_showAllMotives ? '收起候选' : '展开全部候选')),
            const OsNote(
                '历史反馈达到 3 次的类型优先按个人实证排序；不足时参考候选预测。反方动机也会影响选择，历史比例不代表一定能完成行动。'),
          ]),
      OsSection(
          title: '把未来搬到现在',
          subtitle: '同时看见做与不做的可能后果。以下内容是模拟，不是已经发生的事实。',
          children: [
            _aiButton('展开五个时间尺度的双向情境', 'future'),
            ..._suggestions('future'),
            for (final e in const {
              'futureNow': '现在',
              'futureToday': '今天',
              'future7': '7 天后',
              'future30': '30 天后',
              'futureLong': '长期重复后'
            }.entries)
              _field(e.key, '${e.value} · 做 / 不做的可能后果')
          ]),
      OsSection(title: '信念与环境', children: [
        _field('belief', '我现在相信什么？依据是什么？'),
        _score('beliefCredibility', '信念的证据可信度'),
        _field('environment', '怎样让有效动机在现场重新出现？', hint: '提醒位置、物品准备、约定、路线、即时反馈…')
      ]),
    ];
  }

  Future<void> _editMotive(String side, [SelfOsMotive? existing]) async {
    final m = existing ?? SelfOsMotive(side: side, selected: true);
    final values = await osEditDialog(context,
        title: side == 'for' ? '正方动机' : '反方动机',
        labels: const {
          'title': '具体动机',
          'type': '动机类型',
          'reason': '因果机制与事实依据',
          'layer': '表现层：理性 / 现场 / 环境',
          'kind': '性质：事实 / 概率推断 / 想象模拟',
          'predicted': '预测有效度 0–100',
          'credibility': '可信度 0–100',
          'vividness': '鲜明度 0–100',
          'presence': '现场在场度 0–100'
        },
        initial: {
          'title': m.title,
          'type': m.type,
          'reason': m.reason,
          'layer': m.layer,
          'kind': m.kind,
          'predicted': m.predicted?.round().toString() ?? '',
          'credibility': m.credibility?.round().toString() ?? '',
          'vividness': m.vividness?.round().toString() ?? '',
          'presence': m.presence?.round().toString() ?? ''
        },
        requiredFields: {'title', 'reason'},
        hint: '数字是候选估计；没有依据可留空。标为事实时，请在依据中写明来源。');
    if (values == null || !mounted) return;
    setState(() {
      m.title = values['title']!;
      m.type = values['type']!.isEmpty ? '即时收益' : values['type']!;
      m.reason = values['reason']!;
      m.layer = values['layer']!;
      m.kind = ['事实', '概率推断', '想象模拟'].contains(values['kind'])
          ? values['kind']!
          : '概率推断';
      m.predicted = osNumber(values['predicted']);
      m.credibility = osNumber(values['credibility']);
      m.vividness = osNumber(values['vividness']);
      m.presence = osNumber(values['presence']);
      if (existing == null)
        _c.motives.add(m);
      else
        m.source = '用户修订';
    });
  }

  List<Widget> _cognition() => [
        _workbenchLink('进入证据台账与因果地平线', 1),
        if (_c.blocker != 'cognition')
          OsNote(
              '当前阻塞判断：${selfOsBlockers[_c.blocker]}。先检验原因；如果目标、手段或环境不合适，可以直接调整它们。'),
        OsSection(
            title: '从 K1 到 K2',
            subtitle: '把事实、解释与遗漏分开，改变的是认识的完整性。',
            children: [
              if (_c.text('knowledgeSource').isNotEmpty)
                OsNote('这一轮的认识起点来自${_c.text('knowledgeSource')}，可以结合新情况继续修订。'),
              _field('k1', 'K1 · 行动之前，我怎样理解事实与后果？'),
              _field('facts', '能确认的事实及来源'),
              _field('interpretations', '推论、担心与想象'),
              _field('missingFacts', '还缺哪些信息或长期后果？'),
              _field('distortion', '认识、冲动或环境怎样让行为偏离欲求？'),
              _aiButton('寻找认识遗漏与低成本验证', 'cognition'),
              ..._suggestions('cognition'),
              _choice('cognitiveOperation', '这次采用的认知操作',
                  {for (final v in selfOsCognitiveOperations) v: v}),
              _field('k2', 'K2 · 更完整、仍可被现实修正的新认识'),
              _score('cognitiveCompleteness', '认识完整度 · 我的暂估'),
              _score('revisedProbability', '认识调整后的现场行动概率 P2'),
              if (_c.scores['actionProbability'] != null &&
                  _c.scores['revisedProbability'] != null)
                OsNote(
                    '认知杠杆的主观变化：${(_c.scores['revisedProbability']! - _c.scores['actionProbability']!).toStringAsFixed(0)} 个百分点。仍需真实行动反馈，不能当作实证效果。'),
            ]),
        OsSection(
            title: '现实校准实验室',
            subtitle: '与其无限争论，不如让一个安全、短时的小实验提供信息。',
            children: [
              _field('experiment', '准备做什么小实验？',
                  hint: '例如：只去现场了解 10 分钟，允许按新信息调整'),
              _field('experimentPrediction', '事前预测什么？怎样观察或衡量？'),
              _score('predictedDiscomfort', '行动前预测不适', max: 10),
              _field('proxyExperience', '代理经验：他人在哪个节点仍可回头？',
                  hint: '注明真实来源；虚构案例必须标记为模拟')
            ]),
      ];

  List<Widget> _action() => [
        OsNote(
            '${SelfOsV37Rules.gate(_c.v37).label}：${SelfOsV37Rules.gate(_c.v37).reasons.first}'),
        _workbenchLink('检查认识、冲突与现场观念', 2),
        OsSection(
            title: '计划时的我 / 现场的我',
            subtitle: '两种时刻分别估计。留空就保持未知，不用一个百分比代替证据。',
            children: [
              _score('planProbability', '计划时行动概率 P(plan)'),
              _score('actionProbability', '行动现场概率 P(action)'),
              if (_c.temporalGap != null)
                OsNote(
                    'Temporal Gap = ${_c.temporalGap!.toStringAsFixed(0)} 个百分点${_c.temporalGap! >= 25 ? '。优先调整现场条件，而非增加口头承诺。' : '。后续用真实行动校准。'}'),
              _field('planState', '做计划时的身体、情绪与环境'),
              _field('actionState', '到现场时可能有什么不同？'),
              _field('resistance', '先预演阻力：会出现什么念头、感觉或诱惑？'),
              _score('predictedDiscomfort', '事前预测不适', max: 10),
            ]),
        OsSection(
            title: '我的行动现场协议',
            subtitle: '平静时决定，冲突时执行；出现重要新信息时，允许重新选择。',
            children: [
              _aiButton('辅助设计现场与 Ritual', 'action'),
              ..._suggestions('action'),
              _field('trigger', '何时、何地、什么信号出现时开始？', lines: 1),
              _field('firstAction', '第一个最小动作', hint: '具体到能马上做的动作', lines: 1),
              _field('ritual', 'Ritual 步骤 · 每行一步',
                  hint: '双脚落地\n开灯\n穿衣\n走到门口', lines: 4),
              _field('environment', '提前安排什么环境？'),
              _field('precommitment', '我的预先承诺 / 外部约定'),
              _field('reconsiderWhen', '哪些新信息出现时应该重审？'),
              _field('newInformation', '现在出现了什么重要新信息？'),
              if (_c.committedAt != null)
                const OsNote('本轮协议已保存快照。若修改了预测或动作，请重新确认协议；复盘会使用最近确认的快照。'),
              FilledButton.icon(
                  key: const ValueKey('self_os_commit'),
                  onPressed: _c.reviewed
                      ? null
                      : () async {
                          try {
                            _c.commit();
                            if (await _save() && mounted) {
                              setState(() {});
                              osMessage(context, '行动协议已确认，事前预测已留存');
                            }
                          } on FormatException catch (e) {
                            osMessage(context, e.message);
                          }
                        },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('确认行动协议，保存事前预测')),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                  onPressed:
                      _c.committedAt == null || _c.reviewed ? null : _ritual,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('进入现场 · 按协议一步步执行')),
            ]),
        if (_profile.principles.isNotEmpty)
          OsSection(
              title: '带上自己的决策原则',
              subtitle: '先判断适用条件，也留意例外。',
              children: _profile.principles
                  .take(8)
                  .map((p) => OsNote(
                      '当 ${p['condition']}：${p['rule']}\n重审：${p['exception']}'))
                  .toList()),
      ];

  Future<void> _ritual() async {
    if (_c.commitment == null) return;
    if (_c.text('newInformation').trim().isNotEmpty &&
        !_c.v37.flag('newInformationReviewed')) {
      await _openWorkspace(1);
      return;
    }
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
            builder: (_) =>
                SelfOsActionFocus(snapshot: osClone(_c.commitment!))));
    if (result == null || !mounted) return;
    _c.v37.decisionTraces.add({
      'id': selfOsId(),
      'round': _c.round,
      'kind': 'field',
      'cue': osMap(osMap(_c.commitment!['v37'])['settings'])['holdCue'],
      ...result
    });
    _c.v37.settings['holdResult'] = result;
    if (result['result'] == 'reconsider') {
      final v = await osEditDialog(context,
          title: '先记录重要新信息',
          labels: const {'information': '现实发生了什么变化？'},
          requiredFields: {'information'});
      if (!mounted) return;
      _c.beginCognition();
      _c.fields['newInformation'] = v?['information'] ?? '现场出现重要变化，尚待补充与核验';
      _c.v37.settings['newInformationReviewed'] = false;
      await _save();
      if (mounted) await _openWorkspace(1);
    } else {
      await _save();
      if (mounted && result['result'] == 'review')
        await _switch(SelfOsEngine.mirror);
    }
  }

  List<Widget> _mirror() {
    final current = _c.reviews.where((r) => r.round == _c.round).toList();
    final snapshot = _c.commitment ?? _c.evidenceSnapshot();
    final motives = osMaps(snapshot['motives']);
    final effective = _c
        .text('review.effectiveMotives')
        .split(',')
        .where((v) => v.isNotEmpty)
        .toSet();
    if (current.isNotEmpty)
      return [
        _reviewCard(current.single),
        FilledButton.icon(
            onPressed: () async {
              _c.nextRound();
              _c.fields.removeWhere((k, _) => k.startsWith('review.'));
              _c.scores.removeWhere((k, _) => k.startsWith('review.'));
              if (await _save() && mounted)
                setState(() {
                  _engine = SelfOsEngineService.next(_c).engine;
                  _revision++;
                });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('带着新认识，开始下一轮验证')),
        const SizedBox(height: 16),
        for (final r
            in _c.reviews.where((r) => r.round != _c.round).toList().reversed)
          _reviewCard(r),
      ];
    return [
      OsSection(
          title: '行动之镜 · 只解释这一次',
          subtitle: _c.commitment == null
              ? '这次没有已确认的事前预测，预测校准会保持未知。不要根据结果补写预测。'
              : '复盘使用确认协议时的快照。把结果与事前认识放在一起看。',
          children: [
            _choice('review.outcome', '真实行动是什么？', const {
              'done': '做了，完成这一步',
              'partial': '做了一部分',
              'notDone': '这次没有行动'
            }),
            _field('review.context', '具体情境（身体、时间、地点、外部限制）'),
            _field('review.result', '真实结果：发生了什么？'),
            _field('review.actualMotives', '现场突然变强或消失的动机'),
            _field('review.environment', '什么条件放大或削弱了动机？'),
            _field('review.decision', '计划如何被执行或推翻？有新信息吗？'),
            _score('review.actualDiscomfort', '实际开始 10 分钟后的不适', max: 10),
            _score('review.endDiscomfort', '结束后的不适', max: 10),
            _score('review.regret', '这次的后悔程度', max: 10),
            _score('review.satisfaction', '这次的满意程度', max: 10),
          ]),
      OsSection(title: '结果最终服务了什么？', children: [
        _field('review.servedDesire', '最终保住 / 获得了哪个欲求？', lines: 1),
        _field('review.sacrificedDesire', '冲突中让位的另一个欲求', lines: 1),
        _field('review.actualCost', '真实遭遇的代价，以及我的选择'),
        _score('review.actualCostAcceptance', '实际遭遇后的代价接受度'),
        _score('review.alignment', '欲求与行为一致性 · 自评'),
        _field('review.distortion', '错误认识或环境强迫是否影响了解释？'),
        _choice('review.evidenceUse', '校正情境后，这条证据可用于归纳吗？', const {
          'usable': '可以，已考虑认识偏差与外部限制',
          'contextOnly': '仅解释这一次，外部限制较强',
          'uncertain': '还不确定，暂不进入重复模式'
        }),
        _choice('review.capability', '这次对能力的证据更接近', const {
          'strength': '已验证优势的一条证据',
          'limit': '硬限制的证据（需注明依据）',
          'trainable': '当前不足，可以训练',
          'unknown': '仍未验证',
          'misfit': '这条路径或条件不适配'
        }),
      ]),
      OsSection(
          title: '让个人指纹逐渐准确',
          subtitle: '只记录你确实观察到的反馈。不确定时保持未记录。',
          children: [
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('我能反馈哪些动机在现场起作用'),
                value: _c.text('review.motiveFeedback') == 'yes',
                onChanged: (v) => setState(() =>
                    _c.fields['review.motiveFeedback'] = v ? 'yes' : 'no')),
            if (_c.text('review.motiveFeedback') == 'yes') ...[
              if (motives.isEmpty)
                const OsNote('当前没有选入协议的动机，可以在上面的现场动机中补充文字观察。'),
              for (final m in motives)
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: effective.contains(m['id']),
                    onChanged: (v) => setState(() {
                          if (v == true) {
                            effective.add(m['id']);
                          } else {
                            effective.remove(m['id']);
                          }
                          _c.fields['review.effectiveMotives'] =
                              effective.join(',');
                        }),
                    title: Text(
                        '${m['side'] == 'against' ? '反方' : '正方'} · ${m['title']}'),
                    subtitle: const Text('这项动机在现场实际影响了选择')),
            ],
            _choice('review.cognitionFeedback', '这次认知操作对真实行动有帮助吗？', const {
              'unknown': '还不能判断',
              'helped': '有帮助',
              'notHelped': '没有观察到帮助'
            }),
          ]),
      OsSection(
          title: '什么条件真正发生了变化？',
          subtitle: '对照事前快照，记录行动当时的条件。未填写的维度保持未知；结果变好本身不能证明性格改变。',
          children: [
            for (final e in const {
              'knowledgeAtAction': 'K · 行动时实际知道并相信什么？',
              'motivationChange': 'M · 哪些动机变强、变弱或退出？',
              'attentionChange': 'Att · 哪个观念真正占据前景？',
              'environmentAtAction': 'E · 行动时的环境与限制',
              'stateAtAction': 'T · 行动时的身体状态与时点',
              'skillAtAction': 'Skill · 行动时可用的技能'
            }.entries)
              _field('review.${e.key}', e.value),
            _choice('review.jamesMode', '回看这次决意，最接近哪种过程？', osJamesModes),
            _field('review.decisionProcessEvidence', '有哪些实际过程支持这个判断？'),
            _choice('review.holdEffect', '现场那一条提示实际有帮助吗？', const {
              'unknown': '没有使用 / 不能判断',
              'helped': '帮助保持了关键观念',
              'notHelped': '没有观察到帮助',
              'harmed': '反而分散了注意'
            }),
            if (_profile.strengths.isNotEmpty) ...[
              _choice('review.strengthId', '这次实际使用了哪项力量？', {
                'none': '没有使用 / 不确定',
                for (final s in _profile.strengths) s.id: s.title
              }),
              _choice('review.strengthEffect', '力量的实际影响', const {
                'unknown': '无法判断',
                'helped': '有帮助',
                'notHelped': '没有帮助',
                'harmed': '产生了负作用'
              }),
              _choice('review.strengthUsage', '这次使用的程度', const {
                'unknown': '不能判断',
                'underuse': '使用不足',
                'optimal': '恰当使用',
                'overuse': '过度使用'
              }),
            ],
          ]),
      OsSection(
          title: '稳定变化 · 留给重复证据回答',
          subtitle: '可选。只有跨案例、跨情境的重复观察，且逐项检查其他解释后，才形成待验证的稳定变化。',
          children: [
            _field('review.patternClaim', '本次要检验的同一条模式是什么？'),
            for (final key in ['K', 'M', 'Att', 'E', 'T', 'Skill'])
              _choice('review.control.$key', '$key 条件的对照结论', const {
                'unknown': '未核对 / 不确定',
                'stable': '有对照，未观察到变化',
                'changed': '有变化，不能排除这种解释'
              }),
            _field(
                'review.alternativeExplanationCheck', '支持以上对照的具体记录，以及仍未排除的解释'),
          ]),
      OsSection(
          title: 'K1 → 行动 → 结果 → K3',
          subtitle: '每次复盘至少留下一条可复用的新证据。',
          children: [
            if (_c.commitment != null)
              OsNote(
                  '当时的认识 K1：${osText(osMap(snapshot['fields'])['k1']).isEmpty ? '未记录' : osMap(snapshot['fields'])['k1']}\n候选新认识 K2：${osText(osMap(snapshot['fields'])['k2']).isEmpty ? '未记录' : osMap(snapshot['fields'])['k2']}'),
            _field('review.regretKnowledge', '现在知道了什么，是当时没有充分知道的？'),
            _field('review.learning', 'K3 · 这次现实提供的新证据',
                hint: '例如：焦虑很强时，我仍能先完成 10 分钟；或这条路径的代价超出预期。'),
            FilledButton.icon(
                key: const ValueKey('self_os_save_review'),
                onPressed: _submitReview,
                icon: const Icon(Icons.auto_stories_outlined),
                label: const Text('保存复盘与新证据')),
          ]),
      for (final r in _c.reviews.reversed) _reviewCard(r),
    ];
  }

  Future<void> _submitReview() async {
    final snapshot = _c.commitment ??
        {
          ..._c.evidenceSnapshot(),
          'scores': <String, dynamic>{},
          'predictionSource': '未留存事前预测'
        };
    final review = SelfOsReview(
        round: _c.round,
        outcome: _c.text('review.outcome'),
        result: _c.text('review.result').trim(),
        learning: _c.text('review.learning').trim(),
        context: _c.text('review.context').trim(),
        snapshot: osMap(jsonDecode(jsonEncode(snapshot))),
        notes: {
          for (final e
              in _c.fields.entries.where((e) => e.key.startsWith('review.')))
            e.key.substring(7): e.value
        },
        scores: {
          for (final e
              in _c.scores.entries.where((e) => e.key.startsWith('review.')))
            e.key.substring(7): e.value
        },
        effectiveMotives: _c
            .text('review.effectiveMotives')
            .split(',')
            .where((v) => v.isNotEmpty)
            .toList(),
        motiveFeedbackRecorded: _c.text('review.motiveFeedback') == 'yes');
    try {
      _c.addReview(review);
      final strengthId = review.notes['strengthId'];
      final strengthEffect = review.notes['strengthEffect'];
      for (final s in _profile.strengths.where((s) => s.id == strengthId)) {
        if (['helped', 'notHelped', 'harmed'].contains(strengthEffect)) {
          final observations = s.observations;
          observations.removeWhere((o) => o['reviewId'] == review.id);
          observations.add({
            'reviewId': review.id,
            'effect': strengthEffect,
            'usage': review.notes['strengthUsage'] ?? 'unknown'
          });
          s.data['observations'] = observations;
          _profileDirty = true;
        }
      }
      if (await _save() && mounted) {
        setState(() {});
        osMessage(context, '已留下新证据，可在「逐渐认识自己」中查看');
      }
    } on FormatException catch (e) {
      osMessage(context, e.message);
    }
  }

  Widget _reviewCard(SelfOsReview r) {
    final fields = osMap(r.snapshot['fields']);
    final scores = osMap(r.snapshot['scores']);
    return OsSection(
        title: '第 ${r.round} 轮 · ${osDate(r.createdAt)} 的新证据',
        subtitle: '${r.context} · ${{
          'done': '已行动',
          'partial': '部分行动',
          'notDone': '未行动'
        }[r.outcome]}',
        children: [
          Text(r.learning,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 17, height: 1.6)),
          const SizedBox(height: 12),
          Text(
              'K1：${osText(fields['k1']).isEmpty ? '未记录' : fields['k1']}\nK2：${osText(fields['k2']).isEmpty ? '未记录' : fields['k2']}\n实际结果：${r.result}\nK3：${r.learning}',
              style: const TextStyle(height: 1.7)),
          Text(
              '计划预测 ${scores['planProbability'] ?? '未知'} / 现场预测 ${scores['actionProbability'] ?? '未知'}',
              style: const TextStyle(height: 1.8, color: osGold, fontSize: 12)),
          if (r.predictionError != null)
            OsNote(
                '不适预测 ${r.predictedDiscomfort!.toStringAsFixed(1)} / 实际 ${r.scores['actualDiscomfort']!.toStringAsFixed(1)} → 误差 ${r.predictionError!.toStringAsFixed(1)} / 10（预测 − 实际）'),
          for (final e in const {
            'actualMotives': '现场动机',
            'environment': '环境条件',
            'decision': '决意与执行',
            'actualCost': '真实代价',
            'servedDesire': '服务的欲求',
            'sacrificedDesire': '让位的欲求',
            'distortion': '失真与强迫校正',
            'regretKnowledge': '后悔带来的新认识'
          }.entries)
            if ((r.notes[e.key] ?? '').isNotEmpty)
              Text('${e.value}：${r.notes[e.key]}',
                  style: const TextStyle(height: 1.6, fontSize: 13)),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('查看这次变化的来源'),
            children: [
              for (final a in SelfOsInsights.attribution(r))
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${a['source']} · ${a['level']}'),
                    subtitle: Text(a['evidence']!))
            ],
          ),
          const OsNote('这是一条带有具体情境的行为证据，不是对你性格或永久能力的判定。'),
        ]);
  }
}

class _WhyDialog extends StatefulWidget {
  const _WhyDialog({required this.nodes, required this.parents});
  final List<SelfOsWhyNode> nodes;
  final List<String> parents;
  @override
  State<_WhyDialog> createState() => _WhyDialogState();
}

class _WhyDialogState extends State<_WhyDialog> {
  late final _parents = widget.parents.toSet();
  final _answer = TextEditingController();
  String _question = '为什么这对我重要？';
  bool _invalid = false;
  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('继续理解我的欲求'),
          content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('连接已有理由（多选可合并，留空建立新分支）'),
                    Wrap(
                        spacing: 6,
                        children: widget.nodes
                            .map((n) => FilterChip(
                                label: Text(n.answer,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                selected: _parents.contains(n.id),
                                onSelected: (v) => setState(() {
                                      if (v) {
                                        _parents.add(n.id);
                                      } else {
                                        _parents.remove(n.id);
                                      }
                                    })))
                            .toList()),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                        initialValue: _question,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '追问'),
                        items: [
                          '为什么这对我重要？',
                          '如果没人知道，我还想要吗？',
                          '换一种手段，我仍能得到什么？',
                          '真实代价出现时，我还愿意吗？'
                        ]
                            .map((q) => DropdownMenuItem(
                                value: q,
                                child: Text(q,
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _question = v!)),
                    const SizedBox(height: 14),
                    TextField(
                        controller: _answer,
                        minLines: 2,
                        maxLines: 5,
                        maxLength: 2000,
                        decoration: InputDecoration(
                            labelText: '我的回答',
                            errorText: _invalid ? '请写下一个理由' : null)),
                  ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            FilledButton(
                onPressed: () {
                  if (_answer.text.trim().isEmpty) {
                    setState(() => _invalid = true);
                    return;
                  }
                  Navigator.pop(
                      context,
                      SelfOsWhyNode(
                          answer: _answer.text.trim(),
                          question: _question,
                          parents: _parents.toList()));
                },
                child: const Text('加入 Why Tree'))
          ]);
}
