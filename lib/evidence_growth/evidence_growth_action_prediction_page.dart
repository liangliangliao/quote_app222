import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'evidence_growth_action_prediction.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_jev.dart';
import 'evidence_growth_journey_models.dart';

class EvidenceGrowthActionPredictionPage extends StatefulWidget {
  const EvidenceGrowthActionPredictionPage({
    super.key,
    required this.dao,
    this.journey,
  });

  final EvidenceGrowthDao dao;
  final GrowthJourney? journey;

  @override
  State<EvidenceGrowthActionPredictionPage> createState() =>
      _EvidenceGrowthActionPredictionPageState();
}

class _EvidenceGrowthActionPredictionPageState
    extends State<EvidenceGrowthActionPredictionPage> {
  static const _channel =
      MethodChannel('com.example.quote_app/mental_health_checkup');
  static const _teal = Color(0xff24766c);

  late final EvidenceGrowthActionPredictionService service;
  final plan = TextEditingController();
  final notes = TextEditingController();
  final historyNotes = TextEditingController();
  final analysisCorrection = TextEditingController();

  final appliedImprovements = <String>{};

  DateTime? scheduledAt;
  GrowthData actionProfile = {};
  final clarificationText = <String, TextEditingController>{};
  final clarificationChoice = <String, String>{};
  GrowthData result = {};
  List<GrowthData> records = [];
  bool busy = false;
  bool preparing = false;
  bool jevConfigured = false;


  @override
  void initState() {
    super.initState();
    service = EvidenceGrowthActionPredictionService(dao: widget.dao);
    _prefill();
    unawaited(reload());
  }

  void _prefill() {
    final j = widget.journey;
    if (j == null) return;
    final actionApps = growthRows(j.data['knowledge_applications'])
        .where((a) => a['stage'] == 'ACTION' && a['state'] != 'WITHDRAWN')
        .toList();
    final next = growthMap(j.data['next_change']);
    final candidate = actionApps.isNotEmpty
        ? '${actionApps.last['application'] ?? ''}'
        : '${next['next_action'] ?? j.plan['strategy'] ?? ''}';
    plan.text = candidate.trim().isNotEmpty ? candidate : j.title;

    final facts = <String>[
      if ('${j.data['current'] ?? ''}'.trim().isNotEmpty)
        '当前事实：${j.data['current']}',
      if ('${j.data['belief'] ?? ''}'.trim().isNotEmpty)
        '当前判断：${j.data['belief']}',
      if ('${j.data['pending_entry'] ?? ''}'.trim().isNotEmpty)
        '最新补充：${j.data['pending_entry']}',
      if ('${j.plan['schedule'] ?? ''}'.trim().isNotEmpty)
        '已有时间安排：${j.plan['schedule']}',
      if ('${j.plan['resource_limit'] ?? ''}'.trim().isNotEmpty)
        '资源限制：${j.plan['resource_limit']}',
    ];
    notes.text = facts.join('\n');
  }

  @override
  void dispose() {
    plan.dispose();
    notes.dispose();
    historyNotes.dispose();
    analysisCorrection.dispose();
    for (final controller in clarificationText.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> reload() async {
    final history = await service.history();
    final enabled = await widget.dao.getSetting('jev_enabled') == 'true';
    if (!mounted) return;
    setState(() {
      records = history;
      jevConfigured = enabled;
    });
  }

  Future<String> _jevKey() async {
    if (!jevConfigured || !Platform.isAndroid) return '';
    final encrypted = await widget.dao.getSetting('jev_key_encrypted');
    if (encrypted.isEmpty) return '';
    try {
      return await _channel
              .invokeMethod<String>('decryptText', {'value': encrypted}) ??
          '';
    } catch (_) {
      return '';
    }
  }

  Future<void> configureJev() async {
    final controller = TextEditingController();
    final save = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('JEV 行动预测'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    '与知识匹配共用 TypeSafe JEV 配置。预测时只发送本次行动、你填写的条件、有限个人结果摘要和 AI 结构化结果。密钥仍在 Android Keystore 加密保存。'),
                TextField(
                    controller: controller,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'TypeSafe API Key'))
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('停用并清除')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('保存'))
              ],
            ));
    final key = controller.text.trim();
    controller.dispose();
    if (save == null) return;
    if (!save) {
      await widget.dao.setSetting('jev_key_encrypted', '');
      await widget.dao.setSetting('jev_enabled', 'false');
      await reload();
      return;
    }
    if (key.isEmpty) {
      if (mounted) _message('请输入 TypeSafe API Key');
      return;
    }
    if (!Platform.isAndroid) {
      if (mounted) _message('当前平台不支持 Android Keystore，未保存密钥');
      return;
    }
    final encrypted =
        await _channel.invokeMethod<String>('encryptText', {'value': key});
    if (encrypted == null || !encrypted.startsWith('keystore-v1:')) {
      if (mounted) _message('密钥未安全保存');
      return;
    }
    await widget.dao.setSetting('jev_key_encrypted', encrypted);
    await widget.dao.setSetting('jev_enabled', 'true');
    await reload();
  }

  Future<void> chooseTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 365)),
        initialDate: scheduledAt ?? now);
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
            scheduledAt ?? now.add(const Duration(hours: 1))));
    if (time == null) return;
    setState(() {
      scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _invalidateActionProfile();
    });
  }

  GrowthData get structuredContext => {
        'applied_improvements': appliedImprovements.toList(),
      };

  String get similarHistory => historyNotes.text.trim();

  String _safeQuestionId(Object? raw) {
    var text = '$raw'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    while (text.startsWith('_')) {
      text = text.substring(1);
    }
    while (text.endsWith('_')) {
      text = text.substring(0, text.length - 1);
    }
    return text.isEmpty ? 'question' : text;
  }

  void _installActionProfile(GrowthData profile) {
    for (final controller in clarificationText.values) {
      controller.dispose();
    }
    clarificationText.clear();
    clarificationChoice.clear();
    for (final row in growthRows(profile['clarifying_questions'])) {
      final id = _safeQuestionId(row['id']);
      if ('${row['answer_type'] ?? 'text'}' == 'choice') {
        clarificationChoice[id] = '';
      } else {
        clarificationText[id] = TextEditingController();
      }
    }
    actionProfile = profile;
  }

  void _invalidateActionProfile() {
    for (final controller in clarificationText.values) {
      controller.dispose();
    }
    clarificationText.clear();
    clarificationChoice.clear();
    actionProfile = {};
  }

  GrowthData get clarificationAnswers => {
        for (final entry in clarificationText.entries)
          if (entry.value.text.trim().isNotEmpty)
            entry.key: entry.value.text.trim(),
        for (final entry in clarificationChoice.entries)
          if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
      };

  Future<void> prepareAction() async {
    if (preparing || busy || plan.text.trim().isEmpty) return;
    setState(() => preparing = true);
    try {
      final profile = await service.prepareAction(
        plan: plan.text,
        scheduledAt: scheduledAt,
        context: notes.text,
        similarHistory: similarHistory,
        analysisCorrection: analysisCorrection.text,
        structuredContext: structuredContext,
        journey: widget.journey,
      );
      if (!mounted) return;
      setState(() => _installActionProfile(profile));
      if (profile['analysis_status'] != 'READY') {
        final detail = '${profile['analysis_error_detail'] ?? ''}'.trim();
        _message(detail.isEmpty
            ? 'AI行动理解没有成功，请检查统一AI配置后重试。'
            : 'AI行动理解失败：$detail');
      }
    } catch (e) {
      if (mounted) _message('$e');
    } finally {
      if (mounted) setState(() => preparing = false);
    }
  }

  Future<void> predict() async {
    if (busy || preparing || plan.text.trim().isEmpty) return;
    if (actionProfile.isEmpty) {
      await prepareAction();
      if (actionProfile.isEmpty) return;
    }
    if (actionProfile['analysis_status'] != 'READY') {
      _message('AI还没有成功完成行动理解，请先重新调用AI分析。');
      return;
    }
    setState(() => busy = true);
    try {
      final output = await service.predict(
        plan: plan.text,
        scheduledAt: scheduledAt,
        context: notes.text,
        similarHistory: similarHistory,
        analysisCorrection:
            '${actionProfile['analysis_correction_applied'] ?? ''}',
        structuredContext: structuredContext,
        actionProfile: actionProfile,
        clarificationAnswers: clarificationAnswers,
        journey: widget.journey,
        jevApiKey: await _jevKey(),
      );
      await service.savePrediction(output);
      if (!mounted) return;
      setState(() => result = output);
      await reload();
    } catch (e) {
      if (mounted) _message('$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  Future<void> applyImprovementAndPredict() async {
    final scenario = growthMap(result['improvement_scenario']);
    final changes = growthStrings(scenario['changes']);
    if (changes.isEmpty) return;
    final revised = '${scenario['revised_plan'] ?? ''}'.trim();
    setState(() {
      appliedImprovements
        ..clear()
        ..addAll(changes);
      if (revised.isNotEmpty) plan.text = revised;
      _invalidateActionProfile();
    });
    await predict();
  }

  Future<void> recordOutcome(String id, String outcome) async {
    try {
      await service.recordOutcome(id, outcome);
      await reload();
      final latest = records.where((r) => r['id'] == id).toList();
      if (latest.isNotEmpty && mounted) {
        setState(() => result = latest.first);
      }
    } catch (e) {
      if (mounted) _message('$e');
    }
  }

  Future<void> clearHistory() async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('清空行动预测历史？'),
              content: const Text('这会删除本机保存的预测与结果，个人基线也会重新开始。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('清空'))
              ],
            ));
    if (yes != true) return;
    await service.clearHistory();
    if (mounted) setState(() => result = {});
    await reload();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  String _pct(Object? value) =>
      value is num ? '${(value.toDouble() * 100).round()}%' : '—';

  String _time(int ms) {
    if (ms <= 0) return '未指定';
    final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  String _outcome(String value) => const {
        'PENDING': '等待现实结果',
        'SUCCESS': '主预测事件达成',
        'PARTIAL': '部分达成／偏离原计划',
        'FAILED': '主预测事件未达成',
        'ON_TIME': '主预测事件达成',
        'LATE': '部分达成／延期',
        'NOT_DONE': '主预测事件未达成',
      }[value] ??
      value;

  String _factorState(GrowthData row) {
    if (row['unknown'] == true || row['display_score'] == null) return '待补充';
    final score = (row['display_score'] as num).toDouble();
    if (score >= .7) return '较稳';
    if (score >= .55) return '一般';
    return '需优先修';
  }

  String _confidenceLabel(Object? value) {
    if (value is! num) return '未知';
    final v = value.toDouble();
    if (v >= .8) return '高';
    if (v >= .6) return '中';
    return '低';
  }

  IconData _factorIcon(GrowthData row) {
    if (row['unknown'] == true || row['display_score'] == null) {
      return Icons.help_outline;
    }
    final score = (row['display_score'] as num).toDouble();
    if (score < .45) return Icons.warning_amber_rounded;
    if (score >= .65) return Icons.check_circle_outline;
    return Icons.remove_circle_outline;
  }

  String _gainText(Object? value) {
    if (value is! num) return '';
    final points = (value.toDouble() * 100).round();
    if (points <= 0) return '';
    return '+$points 个百分点';
  }

  Widget _section(String title, Widget child,
          {IconData? icon, EdgeInsetsGeometry? padding}) =>
      Card(
          elevation: 0,
          child: Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: _teal),
                        const SizedBox(width: 8)
                      ],
                      Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800))),
                    ]),
                    const SizedBox(height: 10),
                    child
                  ])));

  String _modeLabel(String mode) => const {
        'INITIATE': '启动一个行为',
        'COMPLETE': '完成一个结果',
        'SUSTAIN': '持续一段行为',
        'REFRAIN': '在一段时间内不做某行为',
        'REPEAT': '重复／习惯行动',
        'INTERACT': '与人或系统互动',
        'SEQUENCE': '多步骤行动',
        'OTHER': '其他行动',
      }[mode] ?? mode;

  Widget _inputCard() {
    return _section(
        '输入一个行动',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
              '先用一句自然语言说你准备做什么。AI 会先定义可观察行为，再按整合行为模型（IBM）提取理论构念与行为特有信念，最后交给 JEV 判断。',
              style: TextStyle(color: Colors.black54, height: 1.4)),
          const SizedBox(height: 12),
          TextField(
              controller: plan,
              enabled: !busy && !preparing,
              minLines: 2,
              maxLines: 5,
              onChanged: (_) => setState(() {
                    _invalidateActionProfile();
                    analysisCorrection.clear();
                  }),
              decoration: const InputDecoration(
                  labelText: '你接下来准备做什么？',
                  hintText: '例如：今晚给朋友打电话道歉 / 未来7天不抽烟 / 周五前提交报告 / 明早跑步30分钟',
                  border: OutlineInputBorder())),
          const SizedBox(height: 12),
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('时间／期限（可选）'),
              subtitle: Text(scheduledAt == null
                  ? '没有明确时间也可以，AI会根据行动语义判断需要补什么'
                  : _time(scheduledAt!.millisecondsSinceEpoch)),
              trailing: TextButton(
                  onPressed: busy || preparing ? null : chooseTime,
                  child: Text(scheduledAt == null ? '选择' : '修改'))),
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('补充你已经知道的事实（可选）'),
              subtitle: const Text('不需要先选固定因素；用自然语言写事实，AI会负责提取、筛选并继续追问'),
              children: [
                TextField(
                    controller: historyNotes,
                    enabled: !busy && !preparing,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: '过去真正相似的行动通常怎样？',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: notes,
                    enabled: !busy && !preparing,
                    minLines: 3,
                    maxLines: 7,
                    decoration: const InputDecoration(
                        labelText: '其他会影响这次行动的现实事实',
                        border: OutlineInputBorder())),
                const SizedBox(height: 8)
              ]),
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                  onPressed: busy || preparing || plan.text.trim().isEmpty
                      ? null
                      : prepareAction,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(preparing
                      ? 'AI 正在理解这个行动…'
                      : actionProfile.isEmpty
                          ? 'AI 先理解这个行动'
                          : '重新理解这个行动'))),
          if (preparing)
            const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator())
        ]),
        icon: Icons.edit_note_outlined);
  }

  String _constructLabel(String key) =>
      EvidenceGrowthJev.actionFactorLabels[key] ?? key;

  String _groupLabel(String key) => const {
        'INTENTION_FORMATION': 'A. 意向形成层',
        'DIRECT_BEHAVIOR': 'B. IBM 直接行为决定因素',
        'VOLITIONAL_EXTENSION': 'C. 执行意图扩展',
        'ACTION_SPECIFIC': 'D. 当前行为特有信念／条件',
      }[key] ??
      key;

  Widget _profileCard() {
    if (actionProfile.isEmpty) return const SizedBox.shrink();
    final events = growthRows(actionProfile['forecast_events']);
    final dynamicRows = growthRows(actionProfile['dynamic_factors']);
    final preserved = dynamicRows
        .where((row) => row['source'] == 'PRESERVED_BASELINE')
        .toList();
    final adaptive =
        dynamicRows.where((row) => row['source'] == 'AI_DYNAMIC').toList();
    final omittedPreserved =
        growthRows(actionProfile['omitted_preserved_factors']);
    final questions = growthRows(actionProfile['clarifying_questions']);
    final assumptions = growthStrings(actionProfile['assumptions']);
    final checks = growthStrings(actionProfile['analysis_checks']);
    final mode = '${actionProfile['action_mode'] ?? 'OTHER'}';
    final interpretation = '${actionProfile['interpretation'] ?? ''}'.trim();
    final normalized = '${actionProfile['normalized_action'] ?? ''}'.trim();
    final analysisReady = actionProfile['analysis_status'] == 'READY';
    final analysisProvider =
        '${actionProfile['analysis_provider'] ?? ''}'.trim();
    final analysisModel = '${actionProfile['analysis_model'] ?? ''}'.trim();
    final analysisError =
        '${actionProfile['analysis_error_detail'] ?? ''}'.trim();
    final analysisErrorCode =
        '${actionProfile['analysis_error_code'] ?? ''}'.trim();
    final coverage = '${actionProfile['coverage_summary'] ?? ''}'.trim();
    final appliedCorrection =
        '${actionProfile['analysis_correction_applied'] ?? ''}'.trim();
    final correction = analysisCorrection.text.trim();
    final hasUnappliedCorrection =
        correction.isNotEmpty && correction != appliedCorrection;

    Widget predictorRow(GrowthData row) {
      final reason = '${row['selection_reason'] ?? ''}'.trim();
      final evidence = '${row['evidence'] ?? ''}'.trim();
      final construct = '${row['ibm_construct'] ?? ''}'.trim();
      return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
              row['source'] == 'PRESERVED_BASELINE'
                  ? Icons.bookmark_added_outlined
                  : Icons.auto_awesome_outlined,
              size: 21,
              color: _teal),
          title: Text('${row['label'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (construct.isNotEmpty)
                  Text('理论映射：${_constructLabel(construct)}'),
                if (reason.isNotEmpty) Text('为什么保留：$reason'),
                if (evidence.isNotEmpty) Text('已提取事实：$evidence'),
              ]));
    }

    return _section(
        'AI 对这个行动的理解与选因',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 6, children: [
            Chip(label: Text(_modeLabel(mode))),
            const Chip(label: Text('IBM 理论骨架')),
            const Chip(label: Text('原型关键因素保留池')),
            const Chip(label: Text('AI 动态补充')),
            if (actionProfile['version'] == 'ibm_action_v2_fallback')
              const Chip(label: Text('通用回退'))
          ]),
          if (!analysisReady) ...[
            const SizedBox(height: 12),
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: .08),
                    border: Border.all(color: Colors.orange.shade400),
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.error_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                            child: Text('AI实际上没有完成本轮行动理解',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16)))
                      ]),
                      const SizedBox(height: 8),
                      const Text(
                          '当前看到的是“通用回退”，不是AI分析结果。因此不会把它当作已完成的理解交给JEV。',
                          style: TextStyle(height: 1.4)),
                      if (analysisProvider.isNotEmpty ||
                          analysisModel.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                            '调用配置：${[
                              analysisProvider,
                              analysisModel
                            ].where((e) => e.isNotEmpty).join(' · ')}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54))
                      ],
                      if (analysisErrorCode.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('失败类型：$analysisErrorCode',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700))
                      ],
                      if (analysisError.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text('具体原因：$analysisError',
                            style: const TextStyle(fontSize: 12))
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                              onPressed:
                                  busy || preparing ? null : prepareAction,
                              icon: const Icon(Icons.refresh),
                              label: const Text('重新调用AI理解这个行动')))
                    ]))
          ],
          if (normalized.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(analysisReady ? 'AI理解的目标行动' : '原始目标行动（AI尚未成功解析）',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(normalized,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800)),
          ],
          if (analysisReady && interpretation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(interpretation,
                style: const TextStyle(color: Colors.black54, height: 1.45)),
          ],
          if (analysisReady && coverage.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('覆盖检查：$coverage',
                style: const TextStyle(fontWeight: FontWeight.w700))
          ],
          if (analysisReady && checks.isNotEmpty) ...[
            const SizedBox(height: 12),
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('AI 本轮做了哪些分析检查',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('这里显示分析覆盖范围，不显示模型内部推理过程'),
                children: [
                  for (final item in checks)
                    ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.check_circle_outline, size: 20),
                        title: Text(item))
                ])
          ],
          if (analysisReady && assumptions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.orange.shade300),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('需要你核对的AI假设',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      const Text('这些不是事实，也不会作为已确认事实直接交给JEV。',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 6),
                      for (final item in assumptions) Text('• $item')
                    ]))
          ],
          if (analysisReady && events.isNotEmpty) ...[
            const Divider(height: 28),
            const Text('JEV 实际要预测的可观察事件',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final event in events)
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(event['primary'] == true
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked),
                  title: Text('${event['label'] ?? ''}'),
                  subtitle: event['primary'] == true
                      ? const Text('主预测事件：最终总概率以它为准')
                      : const Text('辅助预测事件'))
          ],
          if (analysisReady && preserved.isNotEmpty) ...[
            const Divider(height: 28),
            const Text('从原“上班／到场”模型中保留下来的关键因素',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
                '原来验证有价值的条件没有删除；AI按当前行动逐项筛选，只有相关的才进入本次JEV判断。',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            for (final row in preserved) predictorRow(row),
          ],
          if (analysisReady && omittedPreserved.isNotEmpty) ...[
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('本次未选入的原型因素（${omittedPreserved.length}）',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('用于核对AI有没有把本来重要的旧因素漏掉'),
                children: [
                  for (final row in omittedPreserved)
                    ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.remove_circle_outline,
                            size: 19),
                        title: Text('${row['label'] ?? ''}'),
                        subtitle: Text(
                            '理论映射：${_constructLabel('${row['ibm_construct'] ?? ''}')}'))
                ])
          ],
          if (analysisReady && adaptive.isNotEmpty) ...[
            const Divider(height: 28),
            const Text('AI 针对当前行动新增的关键因素',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
                '这些因素不是固定写死的；必须说明为什么影响当前行为，并映射回心理学理论构念。',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            for (final row in adaptive) predictorRow(row),
          ],
          if (analysisReady && questions.isNotEmpty) ...[
            const Divider(height: 28),
            const Text('还缺哪些关键事实',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('可以留空；留空时JEV把它当作不确定，而不是自动判成负面。',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 12),
            for (final row in questions) _clarifyingQuestion(row),
          ],
          if (analysisReady) ...[
          const Divider(height: 28),
          const Text('核对AI的理解',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
              '如果AI理解错了、漏掉关键条件或选错因素，请直接写出纠正；重新分析后再交给JEV。',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 10),
          TextField(
              controller: analysisCorrection,
              enabled: !busy && !preparing,
              minLines: 2,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  labelText: '哪里理解不对？还漏了什么？',
                  hintText: '例如：这不是普通跑步，我是在比赛前做恢复跑；天气和膝盖状态是决定性条件。',
                  helperText: appliedCorrection.isEmpty
                      ? '没有需要纠正的可以留空'
                      : '上一轮已应用你的修正：$appliedCorrection',
                  border: const OutlineInputBorder())),
          if (hasUnappliedCorrection) ...[
            const SizedBox(height: 6),
            const Text('你有新的修正尚未进入分析，请先重新分析。',
                style:
                    TextStyle(fontWeight: FontWeight.w700, color: Colors.orange))
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: busy || preparing ? null : prepareAction,
                    icon: const Icon(Icons.refresh),
                    label: const Text('按当前信息重新分析'))),
            const SizedBox(width: 10),
            Expanded(
                child: FilledButton.icon(
                    onPressed: busy ||
                            preparing ||
                            hasUnappliedCorrection
                        ? null
                        : predict,
                    icon: const Icon(Icons.hub_outlined),
                    label: Text(busy
                        ? '正在预测…'
                        : jevConfigured
                            ? '确认理解并交给JEV'
                            : '确认理解并开始预测')))
          ]),
          ],
          if (busy)
            const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator())
        ]),
        icon: Icons.account_tree_outlined);
  }

  Widget _clarifyingQuestion(GrowthData row) {
    final id = _safeQuestionId(row['id']);
    final question = '${row['question'] ?? ''}'.trim();
    final why = '${row['why'] ?? ''}'.trim();
    final options = growthStrings(row['options']);
    final isChoice = '${row['answer_type'] ?? 'text'}' == 'choice' &&
        options.isNotEmpty;
    return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(question, style: const TextStyle(fontWeight: FontWeight.w700)),
          if ('${row['ibm_construct'] ?? ''}'.trim().isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                    '理论构念：${_constructLabel('${row['ibm_construct']}')}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700))),
          if (why.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 6),
                child: Text(why,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54))),
          if (isChoice)
            Wrap(
                spacing: 6,
                runSpacing: 6,
                children: options
                    .map((option) => ChoiceChip(
                        label: Text(option),
                        selected: clarificationChoice[id] == option,
                        onSelected: busy
                            ? null
                            : (selected) {
                                if (selected) {
                                  setState(() =>
                                      clarificationChoice[id] = option);
                                }
                              }))
                    .toList())
          else
            TextField(
                controller: clarificationText[id] ??=
                    TextEditingController(),
                enabled: !busy,
                decoration: const InputDecoration(
                    hintText: '不知道可以留空',
                    isDense: true,
                    border: OutlineInputBorder()))
        ]));
  }
  Widget _summaryCard() {
    if (result.isEmpty) return const SizedBox.shrink();
    final available = result['estimate_available'] == true;
    final estimate = result['estimate'] as num?;
    final headline = '${result['headline'] ?? ''}'.trim();
    final reason = '${result['headline_reason'] ?? ''}'.trim();
    final risks = growthRows(result['top_risks']);
    final actions = growthStrings(result['protective_actions']);
    final jevFlow = growthMap(result['jev_workflow']);
    final source = '${result['forecast_source'] ?? ''}';
    final dominantFailure =
        '${jevFlow['dominant_failure_label'] ?? ''}'.trim();
    final missingQuestion =
        '${jevFlow['most_decisive_missing_label'] ?? ''}'.trim();
    final eventRows = growthRows(jevFlow['events']);
    final hardBlocker = jevFlow['hard_blocker'];

    return _section(
        '本次预测',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (available) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_pct(estimate),
                  style: const TextStyle(
                      fontSize: 46,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: _teal)),
              const SizedBox(width: 12),
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('${result['band']}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800))))
            ]),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: estimate!.toDouble()),
            const SizedBox(height: 10),
            Text(
                source == 'JEV_PRIMARY'
                    ? '主预测来源：JEV typed workflow'
                    : source == 'AI_FALLBACK'
                        ? '主预测来源：LLM（JEV当前不可用）'
                        : '主预测来源：个人历史基线',
                style: const TextStyle(
                    fontSize: 12, color: Colors.black54)),
            if (source == 'JEV_PRIMARY') ...[
              const SizedBox(height: 12),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: eventRows
                      .map((event) => Chip(
                          avatar: event['primary'] == true
                              ? const Icon(Icons.star, size: 16)
                              : null,
                          label: Text(
                              '${event['label'] ?? '事件'} ${_pct(event['probability'])}')))
                      .toList()),
              const SizedBox(height: 6),
              const Text(
                  '这些百分数分别对应当前行动中真实可观察的事件；AI 会根据“打电话、戒烟、提交报告、跑步、长期习惯”等不同类型动态定义事件。',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              if (hardBlocker is num && hardBlocker.toDouble() >= .6) ...[
                const SizedBox(height: 10),
                Text(
                    'JEV 检测到客观硬阻断的可能性为 ${_pct(hardBlocker)}，请先核对交通、资源、权限、时间冲突或身体条件。',
                    style: const TextStyle(fontWeight: FontWeight.w700))
              ],
              if (dominantFailure.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                    'JEV 最可能失败机制：$dominantFailure（判断把握 ${_pct(jevFlow['dominant_failure_confidence'])}）',
                    style: const TextStyle(fontWeight: FontWeight.w700))
              ],
              if (missingQuestion.isNotEmpty &&
                  jevFlow['most_decisive_missing_question'] != 'none') ...[
                const SizedBox(height: 6),
                Text(
                    'JEV 认为最值得补充的信息：$missingQuestion（判断把握 ${_pct(jevFlow['missing_question_confidence'])}）')
              ],
            ],
          ] else
            const Text('当前信息还不足以形成综合估计。'),
          if (headline.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(headline,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))
          ],
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(reason, style: const TextStyle(height: 1.45))
          ],
          if (risks.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('最关键的阻碍',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (var i = 0; i < risks.length; i++)
              Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    CircleAvatar(
                        radius: 11,
                        backgroundColor: _teal.withValues(alpha: .1),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _teal))),
                    const SizedBox(width: 9),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('${risks[i]['label']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          if ('${risks[i]['evidence'] ?? ''}'.trim().isNotEmpty)
                            Text('${risks[i]['evidence']}',
                                style: const TextStyle(
                                    color: Colors.black54, height: 1.35))
                        ]))
                  ]))
          ] else ...[
            const SizedBox(height: 14),
            const Text('目前还没有足够证据锁定前三大阻碍；未知项不会被当成负面证据。',
                style: TextStyle(color: Colors.black54))
          ],
          if (actions.isNotEmpty) ...[
            const Divider(height: 28),
            const Text('现在最值得做的事',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final action in actions)
              Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Icon(Icons.arrow_right_alt, color: _teal),
                    const SizedBox(width: 6),
                    Expanded(child: Text(action))
                  ]))
          ]
        ]),
        icon: Icons.insights_outlined);
  }

  Widget _improvementCard() {
    final scenario = growthMap(result['improvement_scenario']);
    final estimate = scenario['estimate'];
    final gain = scenario['gain'];
    final changes = growthStrings(scenario['changes']);
    if (result.isEmpty || (estimate == null && changes.isEmpty)) {
      return const SizedBox.shrink();
    }
    final current = result['estimate'];
    final explanation = '${scenario['explanation'] ?? ''}'.trim();
    final revised = '${scenario['revised_plan'] ?? ''}'.trim();

    return _section(
        '如果先修关键条件，会怎样？',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('下面是“假设这些改变真的完成”的情景模拟，不是保证。',
              style: TextStyle(color: Colors.black54)),
          if (current is num && estimate is num) ...[
            const SizedBox(height: 12),
            Row(children: [
              Text(_pct(current),
                  style: const TextStyle(
                      fontSize: 27, fontWeight: FontWeight.w800)),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward, color: _teal)),
              Text(_pct(estimate),
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: _teal)),
              if (_gainText(gain).isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(_gainText(gain),
                    style: const TextStyle(
                        color: _teal, fontWeight: FontWeight.w700))
              ]
            ])
          ],
          if (changes.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final change in changes)
              Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $change'))
          ],
          if (revised.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('更可执行的计划：$revised',
                style: const TextStyle(fontWeight: FontWeight.w700))
          ],
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(explanation)
          ],
          if (changes.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                    onPressed: busy ? null : applyImprovementAndPredict,
                    icon: const Icon(Icons.refresh),
                    label: const Text('套用这些条件并重新预测')))
          ]
        ]),
        icon: Icons.trending_up);
  }

  Widget _factorDetails() {
    if (result.isEmpty) return const SizedBox.shrink();
    final entries = growthMap(result['factors']).entries.toList();

    int compareRows(MapEntry<String, dynamic> a, MapEntry<String, dynamic> b) {
      final ar = growthMap(a.value);
      final br = growthMap(b.value);
      if (ar['unknown'] == true && br['unknown'] != true) return 1;
      if (ar['unknown'] != true && br['unknown'] == true) return -1;
      final av = ar['display_score'] as num?;
      final bv = br['display_score'] as num?;
      return (av ?? 2).compareTo(bv ?? 2);
    }

    Widget factorTile(MapEntry<String, dynamic> entry) {
      final row = growthMap(entry.value);
      final score = row['display_score'];
      final confidence = row['confidence'];
      final state = _factorState(row);
      final source = '${row['source'] ?? 'NONE'}';
      final construct = '${row['theory_construct'] ?? entry.key}';
      final mapped = row['is_dynamic'] == true
          ? ' · 归入：${_constructLabel(construct)}'
          : '';
      return ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Icon(_factorIcon(row), color: _teal),
          title: Text('${row['label'] ?? entry.key}'),
          subtitle: Text(row['unknown'] == true
              ? '待补充 · 当前证据不足$mapped'
              : '$state · $source 判断把握：${_confidenceLabel(confidence)}$mapped'),
          children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${row['evidence'] ?? ''}'),
                      if (score is num) ...[
                        const SizedBox(height: 8),
                        if (source == 'JEV' && row['jev_raw_score'] is num)
                          Text(
                              'JEV 支持评分：${(row['jev_raw_score'] as num).toStringAsFixed(1)} / 4',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700))
                        else
                          Text(
                              'LLM 支持评分：${(score.toDouble() * 100).round()} / 100',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        const Text(
                            '评分含义：0=强阻碍，2=中性／信息不足，4=强支持。它不是行动成功概率，也不是理论构念的固定权重。',
                            style: TextStyle(
                                fontSize: 12, color: Colors.black54)),
                      ],
                      if (confidence is num) ...[
                        const SizedBox(height: 5),
                        Text('$source 对上述评分的置信度：${_pct(confidence)}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54))
                      ]
                    ]))
          ]);
    }

    const groupOrder = [
      'INTENTION_FORMATION',
      'DIRECT_BEHAVIOR',
      'VOLITIONAL_EXTENSION'
    ];
    final core = entries.where((e) => growthMap(e.value)['is_dynamic'] != true);
    final dynamicRows =
        entries.where((e) => growthMap(e.value)['is_dynamic'] == true).toList()
          ..sort(compareRows);

    return Card(
        elevation: 0,
        child: ExpansionTile(
            title: const Text('查看理论模型中的决定因素',
                style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text(
                '按 IBM 的因果层级展示；执行意图明确标为扩展，不再把所有因素平铺成一组'),
            children: [
              for (final group in groupOrder) ...[
                Builder(builder: (_) {
                  final rows = core
                      .where((e) =>
                          growthMap(e.value)['theory_group'] == group)
                      .toList()
                    ..sort(compareRows);
                  if (rows.isEmpty) return const SizedBox.shrink();
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                            child: Text(_groupLabel(group),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900))),
                        if (group == 'INTENTION_FORMATION')
                          const Padding(
                              padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                              child: Text(
                                  '这些构念主要解释“意向怎样形成”，不是直接和最终行为做简单平均。',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54))),
                        if (group == 'DIRECT_BEHAVIOR')
                          const Padding(
                              padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                              child: Text(
                                  'IBM认为这些因素直接影响行为是否发生。',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54))),
                        if (group == 'VOLITIONAL_EXTENSION')
                          const Padding(
                              padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                              child: Text(
                                  '这是执行意图（if-then）扩展，用于处理“已经想做但没有真正行动”的意向—行为缺口。',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54))),
                        for (final row in rows) factorTile(row),
                      ]);
                })
              ],
              if (dynamicRows.isNotEmpty) ...[
                const Divider(),
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(_groupLabel('ACTION_SPECIFIC'),
                        style: const TextStyle(fontWeight: FontWeight.w900))),
                const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Text(
                        'AI只负责从当前行为中提取具体显著信念／现实条件，并把它们映射回IBM构念，而不是另造一套心理学因素。',
                        style:
                            TextStyle(fontSize: 12, color: Colors.black54))),
                for (final row in dynamicRows) factorTile(row),
              ]
            ]));
  }

  Widget _secondaryDetails() {
    if (result.isEmpty) return const SizedBox.shrink();
    final ai = growthMap(result['ai']);
    final jevFlow = growthMap(result['jev_workflow']);
    final baseline = growthMap(result['history_baseline']);
    final missing = growthStrings(result['missing_information']);
    final failures = growthStrings(result['failure_modes']);

    return Column(children: [
      if (missing.isNotEmpty)
        Card(
            elevation: 0,
            child: ExpansionTile(
                title: const Text('补充哪些信息会让预测更可靠',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                children: [
                  for (final item in missing)
                    ListTile(
                        dense: true,
                        leading: const Icon(Icons.help_outline, size: 20),
                        title: Text(item))
                ])),
      if (failures.isNotEmpty)
        Card(
            elevation: 0,
            child: ExpansionTile(
                title: const Text('可能的失败路径',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                children: [
                  for (final item in failures)
                    ListTile(
                        dense: true,
                        leading:
                            const Icon(Icons.alt_route_outlined, size: 20),
                        title: Text(item))
                ])),
      Card(
          elevation: 0,
          child: ExpansionTile(
              title: const Text('模型与校准信息',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('一般无需关注；用于核对 AI、JEV 与个人基线'),
              children: [
                ListTile(
                    title: const Text('主预测引擎'),
                    subtitle: Text(result['forecast_source'] == 'JEV_PRIMARY'
                        ? 'JEV 的 typed probabilistic workflow'
                        : 'JEV 不可用时才回退到 LLM'),
                    trailing: Text(result['forecast_source'] == 'JEV_PRIMARY'
                        ? 'JEV'
                        : 'LLM')),
                for (final event in growthRows(jevFlow['events']))
                  ListTile(
                      title: Text(
                          'JEV：${event['label'] ?? '预测事件'}${event['primary'] == true ? '（主）' : ''}'),
                      trailing: Text(_pct(event['probability']))),
                ListTile(
                    title: const Text('LLM 交叉判断'),
                    subtitle: const Text('用于解释、发现遗漏和提出干预，不再与 JEV 50/50 平均'),
                    trailing: Text(_pct(ai['execution_likelihood']))),
                ListTile(
                    title: const Text('个人历史基线'),
                    subtitle: Text((baseline['resolved_count'] as num? ?? 0) == 0
                        ? '尚无个人结果记录'
                        : '已记录 ${baseline['resolved_count']} 次现实结果'),
                    trailing: Text(_pct(baseline['rate']))),
                if (result['agreement'] == 'MODEL_DISAGREEMENT')
                  const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Text(
                          'AI 与 JEV 差异较大。此时优先补充事实，不要把单一数字当结论。',
                          style: TextStyle(fontWeight: FontWeight.w700))),
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('${result['calibration_note']}',
                            style:
                                const TextStyle(color: Colors.black54))))
              ]))
    ]);
  }

  Widget _outcomeCard() {
    if (result.isEmpty) return const SizedBox.shrink();
    return _section(
        '现实结果',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('当前：${_outcome((result['outcome'] ?? 'PENDING').toString())}'),
          const SizedBox(height: 8),
          const Text('行动发生后回来点一次，系统才会逐渐学到你的个人执行基线。',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(
                onPressed: () => recordOutcome(result['id'], 'SUCCESS'),
                child: const Text('主事件达成')),
            OutlinedButton(
                onPressed: () => recordOutcome(result['id'], 'PARTIAL'),
                child: const Text('部分达成／偏离计划')),
            OutlinedButton(
                onPressed: () => recordOutcome(result['id'], 'FAILED'),
                child: const Text('主事件未达成')),
          ])
        ]),
        icon: Icons.fact_check_outlined);
  }

  Widget _history() => Card(
      elevation: 0,
      child: ExpansionTile(
          title: Text('预测历史（${records.length}）'),
          subtitle: const Text('真实结果越多，个人基线越有参考价值'),
          children: [
            if (records.isNotEmpty)
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: clearHistory, child: const Text('清空历史'))),
            for (final row in records.take(20))
              ListTile(
                  title: Text('${row['plan']}',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${_pct(row['estimate'])} · ${_outcome((row['outcome'] ?? 'PENDING').toString())} · ${_time((row['scheduled_at_ms'] as num?)?.toInt() ?? 0)}'),
                  onTap: () => setState(() => result = row)),
          ]));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('行动发生可能性预测'), actions: [
          IconButton(
              tooltip: jevConfigured ? 'JEV 已配置' : '配置 JEV',
              onPressed: busy ? null : configureJev,
              icon:
                  Icon(jevConfigured ? Icons.hub : Icons.hub_outlined))
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _inputCard(),
          _profileCard(),
          if (result.isNotEmpty) ...[
            _summaryCard(),
            _improvementCard(),
            _factorDetails(),
            _secondaryDetails(),
            _outcomeCard(),
          ],
          _history(),
          const SizedBox(height: 30),
        ]));
  }
}