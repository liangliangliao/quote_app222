import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'evidence_growth_action_prediction.dart';
import 'evidence_growth_behavior_theories.dart';
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
  final selectedTheoryIds = <String>{};
  final theoryFactorSelections = <String, String>{};
  final theoryFactorSelectionSources = <String, String>{};

  DateTime? scheduledAt;
  GrowthData actionProfile = {};
  final clarificationText = <String, TextEditingController>{};
  final clarificationChoice = <String, String>{};
  GrowthData result = {};
  List<GrowthData> records = [];
  bool busy = false;
  bool preparing = false;
  bool jevConfigured = false;
  bool theorySelectionManuallyEdited = false;
  GrowthData theorySelectionAnalysis = {};


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
    theoryFactorSelections.clear();
    theoryFactorSelectionSources.clear();
    for (final row in growthRows(profile['clarifying_questions'])) {
      final id = _safeQuestionId(row['id']);
      if ('${row['answer_type'] ?? 'text'}' == 'choice') {
        clarificationChoice[id] = '';
      } else {
        clarificationText[id] = TextEditingController();
      }
    }
    for (final row in growthRows(profile['theory_factor_questionnaire'])) {
      final id = '${row['id'] ?? ''}';
      final option = '${row['auto_option_id'] ?? ''}';
      if (id.isNotEmpty && row['auto_selected'] == true && option.isNotEmpty) {
        theoryFactorSelections[id] = option;
        theoryFactorSelectionSources[id] = 'AUTO_LLM_JEV';
      }
    }
    final profileTheories = growthStrings(profile['selected_theories']);
    if (profileTheories.isNotEmpty) {
      selectedTheoryIds
        ..clear()
        ..addAll(profileTheories);
    }
    theorySelectionManuallyEdited =
        '${profile['theory_selection_mode'] ?? 'AUTO'}' == 'MANUAL';
    theorySelectionAnalysis =
        growthMap(profile['theory_selection_analysis']);
    actionProfile = profile;
  }

  void _invalidateActionProfile({bool clearTheoryAnalysis = false}) {
    for (final controller in clarificationText.values) {
      controller.dispose();
    }
    clarificationText.clear();
    clarificationChoice.clear();
    theoryFactorSelections.clear();
    theoryFactorSelectionSources.clear();
    if (clearTheoryAnalysis) theorySelectionAnalysis = {};
    actionProfile = {};
  }

  GrowthData get clarificationAnswers => {
        for (final entry in clarificationText.entries)
          if (entry.value.text.trim().isNotEmpty)
            entry.key: entry.value.text.trim(),
        for (final entry in clarificationChoice.entries)
          if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
      };

  GrowthData get theoryFactorAnswers => {
        for (final row in growthRows(actionProfile['theory_factor_questionnaire']))
          if ('${row['id'] ?? ''}'.isNotEmpty &&
              theoryFactorSelections['${row['id']}']?.isNotEmpty == true)
            '${row['id']}': {
              'option_id': theoryFactorSelections['${row['id']}'],
              'option_label': EvidenceBehaviorTheoryCatalog.option(
                      '${row['id']}',
                      theoryFactorSelections['${row['id']}']!)?['label'] ??
                  '',
              'confirmed_by_user': true,
              'prefill_source':
                  theoryFactorSelectionSources['${row['id']}'] ?? 'MANUAL',
              'prefill_confidence':
                  theoryFactorSelectionSources['${row['id']}'] ==
                          'AUTO_LLM_JEV'
                      ? row['auto_confidence']
                      : null,
            }
      };

  int get missingTheoryFactorCount {
    var missing = 0;
    for (final row in growthRows(actionProfile['theory_factor_questionnaire'])) {
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) continue;
      if (theoryFactorSelections[id]?.isNotEmpty != true) missing++;
    }
    return missing;
  }

  Future<void> rematchTheories() async {
    if (busy || preparing || plan.text.trim().isEmpty) return;
    setState(() {
      theorySelectionManuallyEdited = false;
      selectedTheoryIds.clear();
      _invalidateActionProfile(clearTheoryAnalysis: true);
    });
    await prepareAction();
  }

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
        selectedTheoryIds: selectedTheoryIds.toList(),
        autoSelectTheories: !theorySelectionManuallyEdited,
        jevApiKey: await _jevKey(),
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
    if (!jevConfigured) {
      _message('最终预测要求 LLM + JEV 共同参与。请先配置JEV；当前AI分析可以继续查看，但不会生成正式最终预测。');
      return;
    }
    final jevKey = await _jevKey();
    if (jevKey.isEmpty) {
      _message('JEV已启用，但密钥无法读取。为避免生成“伪联合预测”，本次不会继续；请重新配置JEV。');
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
        selectedTheoryIds: selectedTheoryIds.toList(),
        theoryFactorAnswers: theoryFactorAnswers,
        journey: widget.journey,
        jevApiKey: jevKey,
        requireJev: true,
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

  String _evidenceStateLabel(Object? value) => const {
        'adverse': '已有不利证据',
        'mixed': '证据混合／不稳定',
        'supportive': '已有支持证据',
        'insufficient': '证据不足',
      }['$value'] ??
      '未分类';

  String _bottleneckLabel(Object? value) {
    if (value is! num) return '未判断';
    final v = value.toDouble();
    if (v >= .80) return '强瓶颈信号';
    if (v >= .65) return '较可能是瓶颈';
    if (v >= .50) return '边界判断／需要验证';
    return '目前更偏向非瓶颈';
  }

  String _weaknessClassLabel(Object? value) => const {
        'RECURRING_WEAKNESS': '相似失败中反复出现',
        'CURRENT_BOTTLENECK': '本次关键瓶颈',
      }['$value'] ??
      '待验证';

  String _coverageStatusLabel(Object? value) => const {
        'RISK': '已发现风险',
        'SUPPORT': '已有支持',
        'KNOWN': '已有事实',
        'UNKNOWN': '证据不足',
        'NOT_RELEVANT_OR_NOT_SELECTED': '当前未进入重点',
      }['$value'] ??
      '$value';

  String _dynamicPredictiveRoleLabel(Object? value) => const {
        'high_value': 'JEV：高增量预测价值',
        'moderate_value': 'JEV：中等预测价值',
        'low_value': 'JEV：低预测价值',
        'duplicate': 'JEV：与现有因素重复',
        'outcome_or_step': 'JEV：属于结果/步骤，不是预测因素',
        'insufficient': 'JEV：证据不足',
      }['$value'] ??
      'JEV：未裁决';

  String _theoryRoleLabel(Object? value) => const {
        'key_blocker': 'JEV：关键阻碍',
        'secondary_risk': 'JEV：次要风险',
        'protective': 'JEV：保护因素',
        'low_relevance': 'JEV：当前相关性较低',
        'uncertain': 'JEV：作用不确定',
      }['$value'] ??
      'JEV：未判断';

  String _conclusionTypeLabel(Object? value) => const {
        'CORE_WEAKNESS': '核心弱点假设',
        'INTERACTION': '因素交互',
        'PROTECTIVE': '保护模式',
        'UNCERTAINTY': '关键未知',
      }['$value'] ??
      '综合结论';

  String _epistemicLabel(Object? value) => const {
        'STRONG': '证据较强',
        'MODERATE': '中等支持',
        'TENTATIVE': '暂定假设',
      }['$value'] ??
      '暂定假设';

  String _jointDecisionModeLabel(Object? value) => const {
        'LLM_JEV_JOINT': '完整联合决策',
        'LLM_JEV_DISAGREEMENT_OR_INSUFFICIENT': '双方已参与但存在分歧/证据不足',
        'JEV_FIRST_PASS_ONLY': 'JEV仅完成初判',
        'LLM_ONLY_DEGRADED': '仅LLM降级分析',
      }['$value'] ??
      '$value';

  String _theoryPatternLabel(Object? value) => const {
        'intention_not_formed': '意向尚未真正形成',
        'intention_behavior_gap': '意向—行为转化断裂',
        'capability_opportunity_gap': '能力／机会条件成为主要限制',
        'automatic_motivation_conflict': '自动性动机与反思目标冲突',
        'self_regulation_maintenance_gap': '自我调节／维持恢复环节薄弱',
        'multi_factor_conflict': '多因素共同冲突',
        'no_major_theory_blocker': '暂未发现主要理论阻碍',
        'insufficient_evidence': '证据不足，无法形成单一模式',
      }['$value'] ??
      '$value';

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

  Widget _theorySelector() {
    final rows = EvidenceBehaviorTheoryCatalog.theories.values.toList();
    final recommendations =
        growthRows(theorySelectionAnalysis['recommendations']);

    GrowthData recommendationFor(String id) {
      for (final row in recommendations) {
        if ('${row['theory_id'] ?? ''}' == id) return row;
      }
      return {};
    }

    String roleLabel(String role) => const {
          'PRIMARY': '主要',
          'COMPLEMENTARY': '互补',
          'NOT_NEEDED': '当前非必要',
        }[role] ??
        role;

    final selectionSummary =
        '${theorySelectionAnalysis['selection_summary'] ?? ''}'.trim();
    final selectionStatus =
        '${theorySelectionAnalysis['status'] ?? ''}'.trim();

    return ExpansionTile(
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        title: const Text('选择行为预测理论／扩展',
            style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(selectedTheoryIds.isEmpty
            ? '尚未匹配。点击下方分析后，AI会按当前行动自动勾选最适合的一套或多套理论。'
            : '当前已选 ${selectedTheoryIds.length} 个 · ${theorySelectionManuallyEdited ? '用户已手动调整' : 'AI自动匹配，可继续修改'}'),
        children: [
          if (theorySelectionAnalysis.isNotEmpty) ...[
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    border: Border.all(color: _teal.withValues(alpha: .25)),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.auto_awesome, size: 18, color: _teal),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                                theorySelectionManuallyEdited
                                    ? 'AI匹配结果仍保留供参考；当前以你的手动选择为准'
                                    : selectionStatus == 'AI'
                                        ? 'AI已根据当前行动自动匹配理论'
                                        : 'AI理论匹配当前不可用，已使用通用后备组合',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)))
                      ]),
                      if (selectionSummary.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(selectionSummary,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                height: 1.4))
                      ]
                    ])),
            const SizedBox(height: 10),
          ],
          Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final theory in rows)
                      Builder(builder: (_) {
                        final id = '${theory['id']}';
                        final rec = recommendationFor(id);
                        final suitability = rec['suitability'];
                        return FilterChip(
                            label: Text(suitability is num
                                ? '${theory['short_name']} ${_pct(suitability)}'
                                : '${theory['short_name']}'),
                            selected: selectedTheoryIds.contains(id),
                            onSelected: busy || preparing
                                ? null
                                : (selected) {
                                    if (!selected &&
                                        selectedTheoryIds.length == 1 &&
                                        selectedTheoryIds.contains(id)) {
                                      _message('至少保留一套理论；如需更换，请先勾选另一套再取消当前理论。');
                                      return;
                                    }
                                    setState(() {
                                      theorySelectionManuallyEdited = true;
                                      if (selected) {
                                        selectedTheoryIds.add(id);
                                      } else {
                                        selectedTheoryIds.remove(id);
                                      }
                                      _invalidateActionProfile();
                                    });
                                  });
                      })
                  ])),
          const SizedBox(height: 10),
          if (plan.text.trim().isNotEmpty)
            Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                    onPressed: busy || preparing ? null : rematchTheories,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('按当前行动重新自动匹配理论'))),
          if (selectedTheoryIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final theory in rows)
              if (selectedTheoryIds.contains('${theory['id']}'))
                Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Builder(builder: (_) {
                      final id = '${theory['id']}';
                      final rec = recommendationFor(id);
                      final reason = '${rec['reason'] ?? ''}'.trim();
                      final role = '${rec['role'] ?? ''}'.trim();
                      final suitability = rec['suitability'];
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text('${theory['name']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800))),
                              if (suitability is num)
                                Text(
                                    '${role.isEmpty ? '' : '${roleLabel(role)} · '}${_pct(suitability)}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: _teal,
                                        fontWeight: FontWeight.w700))
                            ]),
                            Text('${theory['description']}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                            Text('适用重点：${theory['scope']}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                            if (reason.isNotEmpty)
                              Text('本次匹配理由：$reason',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w700)),
                          ]);
                    }))
          ],
          if (recommendations.isNotEmpty)
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('查看AI对全部理论的适配分析',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle:
                    const Text('适配度只表示“当前行动是否值得用这个理论分析”，不是行为成功概率'),
                children: [
                  for (final rec in recommendations)
                    Builder(builder: (_) {
                      final id = '${rec['theory_id'] ?? ''}';
                      final theory =
                          EvidenceBehaviorTheoryCatalog.theories[id];
                      final reason = '${rec['reason'] ?? ''}'.trim();
                      final needs = growthStrings(rec['matched_needs']);
                      return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                              selectedTheoryIds.contains(id)
                                  ? Icons.check_circle_outline
                                  : Icons.radio_button_unchecked,
                              color: selectedTheoryIds.contains(id)
                                  ? _teal
                                  : Colors.black38),
                          title: Text(
                              '${theory?['name'] ?? id} · ${_pct(rec['suitability'])}'),
                          subtitle: Text(
                              '${roleLabel('${rec['role'] ?? ''}')}${reason.isEmpty ? '' : ' · $reason'}${needs.isEmpty ? '' : ' · 关注：${needs.join('、')}'}'));
                    })
                ]),
          const SizedBox(height: 4),
          const Text(
              '说明：AI自动匹配的是理论“适配度”，不是行为概率。你可以取消、增加或替换任何理论；一旦手动修改，以你的选择为准。',
              style: TextStyle(
                  fontSize: 11, color: Colors.black54, height: 1.4)),
        ]);
  }

  Widget _inputCard() {
    return _section(
        '输入一个行动',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
              '先描述你准备做什么。AI会根据行动类型、核心阻碍与需要解释的问题自动匹配最适合的一套或多套理论；你可以随时取消、增加或改选。理论确定后，LLM/JEV再辅助预填各理论的标准选项。',
              style: TextStyle(color: Colors.black54, height: 1.4)),
          const SizedBox(height: 12),
          TextField(
              controller: plan,
              enabled: !busy && !preparing,
              minLines: 2,
              maxLines: 5,
              onChanged: (_) => setState(() {
                    if (!theorySelectionManuallyEdited) {
                      selectedTheoryIds.clear();
                    }
                    _invalidateActionProfile(clearTheoryAnalysis: true);
                    analysisCorrection.clear();
                  }),
              decoration: const InputDecoration(
                  labelText: '你接下来准备做什么？',
                  hintText: '例如：今晚给朋友打电话道歉 / 未来7天不抽烟 / 周五前提交报告 / 明早跑步30分钟',
                  border: OutlineInputBorder())),
          const SizedBox(height: 8),
          _theorySelector(),
          const SizedBox(height: 8),
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
                      ? 'AI 正在理解行动并匹配理论…'
                      : actionProfile.isEmpty
                          ? 'AI理解行动并自动匹配理论'
                          : '重新分析行动与理论'))),
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

  String _theoryShortName(String id) =>
      '${EvidenceBehaviorTheoryCatalog.theories[id]?['short_name'] ?? id}';

  String _factorOptionLabel(GrowthData row, String optionId) {
    for (final option in growthRows(row['options'])) {
      if ('${option['id'] ?? ''}' == optionId) {
        return '${option['label'] ?? optionId}';
      }
    }
    return optionId;
  }

  Widget _theoryQuestionnaire(List<GrowthData> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final missing = missingTheoryFactorCount;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(height: 28),
      Row(children: [
        const Expanded(
            child: Text('理论关键因素与标准选项',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
        if (missing > 0)
          Text('待选 $missing',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: Colors.orange))
        else
          const Text('已完成',
              style: TextStyle(fontWeight: FontWeight.w800, color: _teal))
      ]),
      const SizedBox(height: 4),
      const Text(
          '相同构念只显示一次。AI/JEV只能帮助预填；你可以修改。未选择的项目不会被当作中性或0分，而是作为“缺失/未知证据”交给最终判断。',
          style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4)),
      if (missing > 0) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
            onPressed: busy
                ? null
                : () {
                    setState(() {
                      for (final row in rows) {
                        final id = '${row['id'] ?? ''}';
                        if (id.isEmpty ||
                            theoryFactorSelections[id]?.isNotEmpty == true) {
                          continue;
                        }
                        final hasUnknown = growthRows(row['options'])
                            .any((o) => o['id'] == 'unknown');
                        if (hasUnknown) {
                          theoryFactorSelections[id] = 'unknown';
                          theoryFactorSelectionSources[id] = 'MANUAL_UNKNOWN';
                        }
                      }
                    });
                  },
            icon: const Icon(Icons.help_outline),
            label: const Text('把所有未选项设为“不清楚”'))
      ],
      const SizedBox(height: 10),
      for (final row in rows)
        Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.black.withValues(alpha: .08)),
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Builder(builder: (_) {
                  final id = '${row['id'] ?? ''}';
                  final selected = theoryFactorSelections[id] ?? '';
                  final source = theoryFactorSelectionSources[id] ?? '';
                  final theories = growthStrings(row['theory_ids']);
                  final llm = growthMap(row['llm_suggestion']);
                  final jev = growthMap(row['jev_suggestion']);
                  final llmOption = '${llm['option_id'] ?? ''}';
                  final jevOption = '${jev['option_id'] ?? ''}';
                  final auto = row['auto_selected'] == true;
                  final autoConfidence = row['auto_confidence'];
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Text('${row['label'] ?? id}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15))),
                              if (theories.isNotEmpty)
                                Flexible(
                                    child: Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        alignment: WrapAlignment.end,
                                        children: [
                                      for (final theory in theories)
                                        Chip(
                                            visualDensity:
                                                VisualDensity.compact,
                                            label: Text(
                                                _theoryShortName(theory),
                                                style: const TextStyle(
                                                    fontSize: 10)))
                                    ]))
                            ]),
                        const SizedBox(height: 3),
                        Text('${row['question'] ?? ''}',
                            style: const TextStyle(height: 1.35)),
                        const SizedBox(height: 8),
                        if (auto) ...[
                          Text(
                              'LLM + JEV 一致，自动预填：${_factorOptionLabel(row, '${row['auto_option_id']}')} · 把握 ${_pct(autoConfidence)}',
                              style: const TextStyle(
                                  color: _teal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                        ] else if (llmOption.isNotEmpty ||
                            jevOption.isNotEmpty) ...[
                          Text(
                              '未达到自动选择条件：${[
                                if (llmOption.isNotEmpty)
                                  'LLM→${_factorOptionLabel(row, llmOption)} ${_pct(llm['confidence'])}',
                                if (jevOption.isNotEmpty)
                                  'JEV→${_factorOptionLabel(row, jevOption)} ${_pct(jev['confidence'])}'
                              ].join('；')}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                          const SizedBox(height: 5),
                        ],
                        if (source.startsWith('MANUAL') &&
                            selected.isNotEmpty) ...[
                          const Text('用户已手动确认／修改',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _teal,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                        ],
                        Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final option in growthRows(row['options']))
                                ChoiceChip(
                                    label: Text('${option['label'] ?? ''}'),
                                    selected:
                                        selected == '${option['id'] ?? ''}',
                                    onSelected: busy
                                        ? null
                                        : (yes) {
                                            if (!yes) return;
                                            setState(() {
                                              theoryFactorSelections[id] =
                                                  '${option['id'] ?? ''}';
                                              theoryFactorSelectionSources[id] =
                                                  'MANUAL';
                                            });
                                          })
                            ]),
                        if ('${llm['evidence'] ?? ''}'.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('AI提取证据：${llm['evidence']}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black54))
                        ]
                      ]);
                })))
    ]);
  }

  Widget _profileCard() {
    if (actionProfile.isEmpty) return const SizedBox.shrink();
    final events = growthRows(actionProfile['forecast_events']);
    final dynamicRows = growthRows(actionProfile['dynamic_factors']);
    final preserved = dynamicRows
        .where((row) => row['source'] == 'PRESERVED_BASELINE')
        .toList();
    final adaptive = dynamicRows
        .where((row) => row['source'] == 'AI_JEV_DYNAMIC')
        .toList();
    final rejectedDynamic =
        growthRows(actionProfile['rejected_dynamic_factors']);
    final dynamicSelection =
        growthMap(actionProfile['dynamic_factor_selection_status']);
    final omittedPreserved =
        growthRows(actionProfile['omitted_preserved_factors']);
    final questions = growthRows(actionProfile['clarifying_questions']);
    final theoryQuestionnaire =
        growthRows(actionProfile['theory_factor_questionnaire']);
    final coveredPreserved =
        growthRows(actionProfile['theory_covered_preserved_factors']);
    final selectedTheoryDetails =
        growthRows(actionProfile['selected_theory_details']);
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
    final analysisStages = growthRows(actionProfile['analysis_stages']);
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
      final llmRelevance = row['predictive_relevance'];
      final counterfactual =
          '${row['counterfactual_effect'] ?? ''}'.trim();
      final jevRole = '${row['jev_predictive_role'] ?? ''}'.trim();
      final jevConfidence = row['jev_role_confidence'];
      final failurePath = '${row['failure_path'] ?? ''}'.trim();
      final whyNew =
          '${row['why_not_existing_factor'] ?? ''}'.trim();
      return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
              row['source'] == 'PRESERVED_BASELINE'
                  ? Icons.bookmark_added_outlined
                  : Icons.hub_outlined,
              size: 21,
              color: _teal),
          title: Text('${row['label'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (construct.isNotEmpty)
                  Text('理论映射：${_constructLabel(construct)}'),
                if (row['source'] == 'AI_JEV_DYNAMIC' && jevRole.isNotEmpty)
                  Text(
                      '${_dynamicPredictiveRoleLabel(jevRole)}'
                      '${jevConfidence is num ? ' · 自报置信度 ${_pct(jevConfidence)}' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                if (llmRelevance is num)
                  Text(
                      'LLM增量预测价值自评：${_pct(llmRelevance)}'
                      '${counterfactual.isNotEmpty ? ' · 反事实影响：$counterfactual' : ''}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black54)),
                if (reason.isNotEmpty) Text('为什么候选：$reason'),
                if (failurePath.isNotEmpty)
                  Text('失败路径：$failurePath'),
                if (whyNew.isNotEmpty)
                  Text('为什么不是已有因素的重复：$whyNew'),
                if (evidence.isNotEmpty) Text('已提取事实：$evidence'),
              ]));
    }

    return _section(
        '行为理解与关键预测因素筛选',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 6, children: [
            Chip(label: Text(_modeLabel(mode))),
            for (final theory in selectedTheoryDetails)
              Chip(label: Text('${theory['short_name'] ?? theory['id']}')),
            const Chip(label: Text('原型补充因素')),
            const Chip(label: Text('LLM+JEV 动态筛选')),
            if (actionProfile['analysis_status'] != 'READY')
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
          if (analysisReady) ...[
            const SizedBox(height: 12),
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    border: Border.all(color: _teal.withValues(alpha: .35)),
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.check_circle_outline,
                            color: _teal, size: 20),
                        const SizedBox(width: 7),
                        const Expanded(
                            child: Text('AI已完成本轮行动理解',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900))),
                        if (analysisProvider.isNotEmpty ||
                            analysisModel.isNotEmpty)
                          Flexible(
                              child: Text(
                                  [analysisProvider, analysisModel]
                                      .where((e) => e.isNotEmpty)
                                      .join(' · '),
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54)))
                      ]),
                      if (analysisStages.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final stage in analysisStages)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(children: [
                                const Icon(Icons.check,
                                    size: 16, color: _teal),
                                const SizedBox(width: 6),
                                Expanded(
                                    child:
                                        Text('${stage['label'] ?? ''}'))
                              ]))
                      ]
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
          if (analysisReady && theoryQuestionnaire.isNotEmpty)
            _theoryQuestionnaire(theoryQuestionnaire),
          if (analysisReady && coveredPreserved.isNotEmpty) ...[
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                    '原型因素中已有 ${coveredPreserved.length} 项被所选理论覆盖'),
                subtitle: const Text('这些因素不会重复显示为第二套选项'),
                children: [
                  for (final row in coveredPreserved)
                    ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.merge_type, size: 19),
                        title: Text('${row['label'] ?? ''}'),
                        subtitle: Text(
                            '已由理论构念覆盖：${_constructLabel('${row['ibm_construct'] ?? ''}')}'))
                ])
          ],
          if (analysisReady && preserved.isNotEmpty) ...[
            const Divider(height: 28),
            const Text('理论尚未覆盖的原型补充因素',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
                '只有“当前行动相关、且所选理论没有重复覆盖”的旧因素才会作为补充保留。',
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
          if (analysisReady &&
              (adaptive.isNotEmpty ||
                  rejectedDynamic.isNotEmpty ||
                  dynamicSelection.isNotEmpty)) ...[
            const Divider(height: 28),
            Row(children: [
              const Expanded(
                  child: Text('LLM + JEV 针对当前行动筛出的高价值因素',
                      style: TextStyle(fontWeight: FontWeight.w800))),
              if ('${dynamicSelection['status'] ?? ''}' ==
                  'LLM_JEV_JOINT')
                const Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('联合筛选',
                        style: TextStyle(fontSize: 10)))
            ]),
            const SizedBox(height: 4),
            const Text(
                'LLM先提出候选，JEV再独立判断它是否真的具有“增量预测价值”：必须是行为发生前的上游因素、与当前行动高度相关、不是已有理论的换名，也不是目标行为/操作步骤本身。',
                style: TextStyle(
                    fontSize: 12, color: Colors.black54, height: 1.4)),
            if (dynamicSelection.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                  '候选 ${dynamicSelection['candidate_count'] ?? 0} 个 · 通过 ${dynamicSelection['selected_count'] ?? 0} 个 · 淘汰 ${dynamicSelection['rejected_count'] ?? 0} 个'
                  '${dynamicSelection['jev_status'] == 'JEV' ? '' : ' · JEV未完成裁决，因此候选不会升级为关键因素'}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black54))
            ],
            if (adaptive.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final row in adaptive) predictorRow(row),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                  '当前没有行动特异候选通过LLM+JEV联合门槛。此时应主要依赖理论问卷、原型因素和现实事实，而不是为了“显得具体”强行增加新因素。',
                  style: TextStyle(
                      fontSize: 12, color: Colors.black54, height: 1.4))
            ],
            if (rejectedDynamic.isNotEmpty)
              ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                      '查看被JEV淘汰的候选（${rejectedDynamic.length}）',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text(
                      '用于核对：低价值、重复、结果/步骤型因素不会再进入最终预测'),
                  children: [
                    for (final row in rejectedDynamic)
                      ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${row['label'] ?? ''}'),
                          subtitle: Text(
                              '${_dynamicPredictiveRoleLabel(row['jev_predictive_role'])}'
                              '${row['selection_reason'] == null ? '' : ' · LLM候选原因：${row['selection_reason']}'}'))
                  ])
          ],
          if (analysisReady && questions.isNotEmpty) ...[
            const Divider(height: 28),
            const Text('LLM + JEV 认为最值得补充的高信息事实',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
                '这里只保留“答案不同会显著改变预测或关键瓶颈判断”的问题；不会为了精细化计划而追问无关紧要的分钟数或微步骤。可以留空，留空按未知处理。',
                style: TextStyle(
                    fontSize: 12, color: Colors.black54, height: 1.4)),
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
                        : (jevConfigured ? predict : configureJev),
                    icon: const Icon(Icons.hub_outlined),
                    label: Text(busy
                        ? '正在预测…'
                        : jevConfigured
                            ? 'LLM分析后交给JEV最终裁决'
                            : '先配置JEV再进行最终预测')))
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
    final dominantDisplayable =
        jevFlow['dominant_failure_displayable'] == true;
    final dominantEvidence =
        '${jevFlow['dominant_failure_evidence'] ?? ''}'.trim();
    final dominantSource =
        '${jevFlow['dominant_failure_source'] ?? ''}'.trim();
    final historyBaseline = growthMap(result['history_baseline']);
    final forecastProvenance =
        growthMap(result['forecast_provenance']);
    final jevFirstPassStatus =
        '${forecastProvenance['jev_first_pass_status'] ?? ''}';
    final jevFinalStatus =
        '${forecastProvenance['jev_final_adjudication_status'] ?? ''}';
    final jointDecisionMode =
        '${forecastProvenance['joint_decision_mode'] ?? ''}';
    final jointDecisionComplete =
        forecastProvenance['joint_decision_complete'] == true;
    final theoryCompleteness =
        growthMap(result['theory_input_completeness']);
    final theoryTotal = (theoryCompleteness['total'] as num?)?.toInt() ?? 0;
    final theoryKnown =
        (theoryCompleteness['known_answers'] as num?)?.toInt() ?? 0;
    final theoryUnknown =
        (theoryCompleteness['explicit_unknown'] as num?)?.toInt() ?? 0;
    final theoryMissing =
        (theoryCompleteness['unselected_missing'] as num?)?.toInt() ?? 0;
    final theoryResponseCoverage =
        (theoryCompleteness['response_coverage'] as num?)?.toDouble();
    final diagnostic = growthMap(result['diagnostic_summary']);
    final directSupports = growthRows(diagnostic['supports']);
    final theorySupports = growthRows(diagnostic['theory_supports']);
    final supportByKey = <String, GrowthData>{};
    for (final item in [...directSupports, ...theorySupports]) {
      final key = '${item['key'] ?? item['label'] ?? ''}'.trim();
      if (key.isEmpty) continue;
      supportByKey.putIfAbsent(key, () => item);
    }
    final diagnosticSupports = supportByKey.values.toList();
    final diagnosticUnknowns = growthRows(diagnostic['unknowns']);
    final usesJevBottleneck =
        diagnostic['uses_jev_bottleneck_judgement'] == true;
    final behaviorDiagnosis = growthMap(result['behavior_diagnosis']);
    final diagnosisHeadline =
        '${behaviorDiagnosis['headline'] ?? ''}'.trim();
    final weaknessRows = growthRows(behaviorDiagnosis['key_weaknesses']);
    final failureChainRows = growthRows(behaviorDiagnosis['failure_chain']);
    final coverageRows = growthRows(behaviorDiagnosis['coverage']);
    final coverageSummary =
        growthMap(behaviorDiagnosis['coverage_summary']);
    final reviewBlueprint =
        growthMap(behaviorDiagnosis['review_blueprint']);
    final reviewQuestions = growthStrings(reviewBlueprint['questions']);
    final theoryFeedback =
        growthMap(behaviorDiagnosis['theory_feedback_analysis']);
    final theoryFactorRows = growthRows(theoryFeedback['factor_rows']);
    final theoryConclusions = growthRows(theoryFeedback['core_conclusions']);
    final theoryInteractions = growthRows(theoryFeedback['interactions']);
    final theoryUnknowns = growthStrings(theoryFeedback['unknowns']);
    final theoryPattern =
        '${theoryFeedback['llm_integrated_pattern'] ?? ''}'.trim();
    final theoryPatternExplanation =
        '${theoryFeedback['pattern_explanation'] ?? ''}'.trim();
    final jevTheoryPattern =
        growthMap(theoryFeedback['jev_integrated_pattern']);
    final theoryById = <String, GrowthData>{
      for (final row in theoryFactorRows)
        if ('${row['factor_id'] ?? ''}'.isNotEmpty)
          '${row['factor_id']}': row
    };

    return _section(
        '本次预测',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (behaviorDiagnosis.isNotEmpty) ...[
            const Text('行为诊断结论（核心）',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text(
                '这里的目标不是只给一个百分比，而是找出这次行动最可能先断在哪里、哪些弱点正在反复出现，以及下一次复盘要验证什么。',
                style: TextStyle(
                    fontSize: 12, color: Colors.black54, height: 1.4)),
            if (diagnosisHeadline.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(diagnosisHeadline,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900))
            ],
            if (theoryFeedback.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: Text(
                        jointDecisionComplete
                            ? 'LLM + JEV 最终联合判断'
                            : jevFirstPassStatus == 'JEV' &&
                                    jevFinalStatus == 'JEV'
                                ? 'LLM ↔ JEV 联合裁决：尚未形成一致结论'
                                : '当前不是完整的 LLM + JEV 联合判断',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900))),
                Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                        '已确认 ${theoryFeedback['confirmed_factor_count'] ?? theoryFactorRows.length} 项',
                        style: const TextStyle(fontSize: 10)))
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                        'LLM：${theoryFeedback['status'] == 'AI_SYNTHESIS' ? '已参与' : '降级/本地'}',
                        style: const TextStyle(fontSize: 10))),
                Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                        'JEV初判：${jevFirstPassStatus == 'JEV' ? '已参与' : '未参与'}',
                        style: const TextStyle(fontSize: 10))),
                Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                        'JEV终裁：${jevFinalStatus == 'JEV' ? '已参与' : '未参与'}',
                        style: const TextStyle(fontSize: 10))),
              ]),
              const SizedBox(height: 3),
              Text(
                  jointDecisionComplete
                      ? '证据链：用户输入与理论问卷 → LLM跨因素综合 → JEV逐条独立裁决 → 只保留双方共同支持的最终结论。'
                      : jevFirstPassStatus == 'JEV' && jevFinalStatus == 'JEV'
                          ? 'LLM与JEV都已实际参与，但JEV最终质量判断没有确认足够一致；因此不强行输出“共同结论”。'
                          : 'JEV没有完整参与最终决策，本页只能视为降级分析，不能标记为LLM+JEV联合结论。',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black54, height: 1.4)),
              if (theoryPattern.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('综合模式：$theoryPattern',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900)),
              ],
              if (theoryPatternExplanation.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(theoryPatternExplanation,
                    style: const TextStyle(
                        fontSize: 12, height: 1.45))
              ],
              if ('${jevTheoryPattern['choice'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                    'JEV独立模式判断：${_theoryPatternLabel(jevTheoryPattern['choice'])} · 自报置信度 ${_pct(jevTheoryPattern['confidence'])}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black54))
              ],
              if (theoryConclusions.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (var i = 0; i < theoryConclusions.length; i++)
                  Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: _teal.withValues(alpha: .28)),
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      child: Text(
                                          '${i + 1}. ${theoryConclusions[i]['title'] ?? ''}',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900))),
                                  const SizedBox(width: 6),
                                  Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(
                                          _conclusionTypeLabel(
                                              theoryConclusions[i]['type']),
                                          style:
                                              const TextStyle(fontSize: 9)))
                                ]),
                            Text(
                                '${_epistemicLabel(theoryConclusions[i]['epistemic_status'])}'
                                '${growthStrings(theoryConclusions[i]['theory_ids']).isEmpty ? '' : ' · 理论：${growthStrings(theoryConclusions[i]['theory_ids']).join(' + ')}'}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black54)),
                            const SizedBox(height: 7),
                            const Text('直接依据：你确认的理论因素',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            for (final factorId
                                in growthStrings(
                                    theoryConclusions[i]['factor_ids']))
                              if (theoryById[factorId] != null)
                                Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 5),
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('• '),
                                          Expanded(
                                              child: Text(
                                                  '${theoryById[factorId]!['factor_label']}：${theoryById[factorId]!['option_label']}'
                                                  ' · ${_theoryRoleLabel(theoryById[factorId]!['jev_role'])}'
                                                  '${theoryById[factorId]!['jev_role_confidence'] is num ? ' ${_pct(theoryById[factorId]!['jev_role_confidence'])}' : ''}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      height: 1.35)))
                                        ])),
                            if ('${theoryConclusions[i]['mechanism'] ?? ''}'.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                  '综合机制：${theoryConclusions[i]['mechanism']}',
                                  style: const TextStyle(
                                      fontSize: 12, height: 1.4))
                            ],
                            if ('${theoryConclusions[i]['why_key'] ?? ''}'.trim().isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                  '为什么抓住重点：${theoryConclusions[i]['why_key']}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      height: 1.4))
                            ],
                            if ('${theoryConclusions[i]['counterevidence'] ?? ''}'.trim().isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                  '反证／替代解释：${theoryConclusions[i]['counterevidence']}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                      height: 1.4))
                            ],
                            if ('${theoryConclusions[i]['correction'] ?? ''}'.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                  '优先改正：${theoryConclusions[i]['correction']}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      height: 1.4))
                            ],
                            if ('${theoryConclusions[i]['review_focus'] ?? ''}'.trim().isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                  '复盘要验证：${theoryConclusions[i]['review_focus']}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                      height: 1.4))
                            ],
                          ]))
              ] else ...[
                const SizedBox(height: 10),
                const Text(
                    '本次理论反馈尚不足以形成可靠的跨因素综合结论；不会为了“看起来深入”而强行制造一个根因。',
                    style: TextStyle(
                        fontSize: 12, color: Colors.black54, height: 1.4))
              ],
              if (theoryFactorRows.isNotEmpty)
                ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('查看全部已确认理论因素与JEV角色',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text(
                        '用于核对综合结论有没有遗漏或错误使用你的问卷反馈'),
                    children: [
                      for (final row in theoryFactorRows)
                        ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                                '${row['factor_label'] ?? row['factor_id']}：${row['option_label'] ?? ''}'),
                            subtitle: Text(
                                '理论：${growthStrings(row['theory_ids']).join(' + ')}'
                                '${row['selection_source'] == 'AUTO_LLM_JEV' ? ' · 最初由LLM+JEV预填，提交时进入本次反馈' : ' · 用户选择'}'),
                            trailing: Text(
                                '${_theoryRoleLabel(row['jev_role'])}'
                                '${row['jev_role_confidence'] is num ? '\n${_pct(row['jev_role_confidence'])}' : ''}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 10)))
                    ]),
              if (theoryInteractions.isNotEmpty)
                ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('查看因素之间的交互关系',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('重点不只是哪个因素低，而是它们怎样组合起来影响行动'),
                    children: [
                      for (final row in theoryInteractions)
                        ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('${row['label'] ?? ''}'),
                            subtitle:
                                Text('${row['description'] ?? ''}'))
                    ]),
              if (theoryUnknowns.isNotEmpty)
                ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('仍限制综合结论的未知信息',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    children: [
                      for (final item in theoryUnknowns)
                        ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.help_outline),
                            title: Text(item))
                    ]),
            ],
            if (weaknessRows.isNotEmpty)
              ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('查看通用行为瓶颈辅助校验',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text(
                      '这是IBM/通用执行因素的辅助结果，不覆盖上面的理论反馈综合结论'),
                  children: [
                    for (var i = 0; i < weaknessRows.length; i++)
                      ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                              radius: 11,
                              child: Text('${i + 1}',
                                  style: const TextStyle(fontSize: 10))),
                          title: Text('${weaknessRows[i]['label'] ?? ''}'),
                          subtitle: Text(
                              '${_weaknessClassLabel(weaknessRows[i]['classification'])} · ${weaknessRows[i]['current_evidence'] ?? ''}'))
                  ])
            else if (theoryConclusions.isEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                  '目前既没有形成可靠的理论综合结论，也没有通用瓶颈达到关键阈值；需要补充事实，而不是强行下结论。',
                  style: TextStyle(color: Colors.black54, height: 1.4))
            ],
            if (failureChainRows.isNotEmpty)
              ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('查看可能的失败链',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('按行动过程排序，帮助定位“最先从哪里开始断”'),
                  children: [
                    for (final row in failureChainRows)
                      ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                              radius: 11,
                              child: Text('${row['order'] ?? ''}',
                                  style: const TextStyle(fontSize: 10))),
                          title: Text(
                              '${row['stage'] ?? ''} → ${row['label'] ?? ''}'),
                          subtitle: Text(
                              '${row['evidence'] ?? ''}'.trim().isEmpty
                                  ? '${row['mechanism'] ?? ''}'
                                  : '${row['evidence']}'))
                  ]),
            if (coverageRows.isNotEmpty)
              ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                      '分析覆盖：扫描 ${coverageSummary['domains_scanned'] ?? coverageRows.length} 个诊断域',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                      '已有事实 ${coverageSummary['domains_with_evidence'] ?? 0} · 证据不足 ${coverageSummary['domains_unknown'] ?? 0}；未知项保留未知，不由模型猜。'),
                  children: [
                    for (final row in coverageRows)
                      ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${row['label'] ?? ''}'),
                          trailing: Text(
                              _coverageStatusLabel(row['status']),
                              style: const TextStyle(fontSize: 11)))
                  ]),
            if (reviewQuestions.isNotEmpty)
              ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('为下一次复盘保存的问题',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('现实结果回来后，不只记成功/失败，还要更新“弱点假设”'),
                  children: [
                    for (var i = 0; i < reviewQuestions.length; i++)
                      ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Text('${i + 1}.'),
                          title: Text(reviewQuestions[i]))
                  ]),
            const Divider(height: 30),
            const Text('行动发生概率（辅助参考）',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(
                '决策状态：${_jointDecisionModeLabel(jointDecisionMode)}'
                '${source == 'JEV_FINAL_SYNTHESIS' ? ' · 概率来自JEV最终联合裁决' : source == 'JEV_PRIMARY' ? ' · 概率来自JEV第一阶段主事件判断' : ' · 当前概率不是JEV正式判断'}',
                style: const TextStyle(
                    fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 8),
          ],
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
                source == 'JEV_FINAL_SYNTHESIS'
                    ? '主预测来源：JEV最终联合裁决（已读取LLM综合 + 理论问卷 + 用户事实）'
                    : source == 'JEV_PRIMARY'
                        ? '主预测来源：JEV第一阶段 typed workflow'
                        : source == 'AI_FALLBACK'
                            ? '主预测来源：LLM（JEV当前不可用）'
                            : '主预测来源：个人历史基线',
                style: const TextStyle(
                    fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 5),
            Text(
                source == 'JEV_FINAL_SYNTHESIS'
                    ? '这个总百分数由JEV在最终裁决阶段重新判断：它同时读取用户输入、已确认理论问卷、JEV第一阶段结果与LLM综合分析；不是把两个模型的数字做平均。'
                    : source == 'JEV_PRIMARY'
                        ? '这个总百分数来自JEV第一阶段对“主预测事件”的直接概率判断，不是把下面各因素评分做加权平均。'
                        : '这个总百分数不是由下面各因素评分简单相加得到。',
                style: const TextStyle(
                    fontSize: 11, color: Colors.black54)),
            if (source == 'HISTORY_ONLY') ...[
              const SizedBox(height: 4),
              Text(
                  '当前没有可用模型概率，因此使用同类个人历史基线；同类真实结果 ${historyBaseline['resolved_count'] ?? 0} 次。',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black54))
            ] else ...[
              const SizedBox(height: 4),
              Text(
                  '同类个人历史 ${historyBaseline['resolved_count'] ?? 0} 次已作为模型输入证据；程序不再用未经验证的固定权重二次混合历史概率。',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black54))
            ],
            if (theoryTotal > 0) ...[
              const SizedBox(height: 6),
              Text(
                  '理论问卷信息：已明确回答 $theoryKnown / $theoryTotal；明确“不清楚” $theoryUnknown；未选择 $theoryMissing；作答覆盖 ${_pct(theoryResponseCoverage)}。',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black54)),
              if (theoryMissing > 0)
                const Text(
                    '未选择项没有被赋任何分数或权重，只增加信息不确定性；不会直接把最终概率拉高或拉低。',
                    style: TextStyle(
                        fontSize: 11, color: Colors.black54))
            ],
            if (source == 'JEV_PRIMARY' || source == 'JEV_FINAL_SYNTHESIS') ...[
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
              if (dominantDisplayable && dominantFailure.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                    'JEV 当前最有证据支持的风险路径：$dominantFailure',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                    '这是“当前证据最支持的风险路径”，不是已经证明的心理原因。JEV 自报选择置信度：${_pct(jevFlow['dominant_failure_confidence'])}'
                    '${dominantSource == 'USER_THEORY_OPTION' ? ' · 直接依据包含：你确认的理论选项' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
                if (dominantEvidence.isNotEmpty)
                  Text('已知证据：$dominantEvidence',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54))
              ] else if (source == 'JEV_PRIMARY' || source == 'JEV_FINAL_SYNTHESIS') ...[
                const SizedBox(height: 10),
                const Text(
                    'JEV 目前没有同时满足“有不利证据 + 能构成现实瓶颈”的单一风险路径，因此不强行给出原因标签。',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700))
              ],
              if (missingQuestion.isNotEmpty &&
                  jevFlow['most_decisive_missing_question'] != 'none') ...[
                const SizedBox(height: 6),
                Text(
                    'JEV 认为最值得补充的信息：$missingQuestion（JEV自报选择置信度 ${_pct(jevFlow['missing_question_confidence'])}）')
              ],
            ],
          ] else
            const Text('当前信息还不足以形成综合估计。'),
          if (headline.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('AI交叉解释（辅助理解，不覆盖JEV结论）',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(headline,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))
          ],
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(reason, style: const TextStyle(height: 1.45))
          ],
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(
                child: Text('当前行动瓶颈：证据 → 机制 → JEV判断',
                    style: TextStyle(fontWeight: FontWeight.w900))),
            if (usesJevBottleneck)
              const Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('JEV瓶颈诊断',
                      style: TextStyle(fontSize: 10)))
          ]),
          const SizedBox(height: 5),
          Text(
              '${diagnostic['rule'] ?? '关键阻碍需要同时有当前不利证据与现实瓶颈判断；不会因为某项分数低就自动判为关键原因。'}',
              style: const TextStyle(
                  fontSize: 12, color: Colors.black54, height: 1.4)),
          const SizedBox(height: 10),
          if (risks.isNotEmpty)
            for (var i = 0; i < risks.length; i++)
              Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: _teal.withValues(alpha: .22)),
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                  radius: 11,
                                  backgroundColor:
                                      _teal.withValues(alpha: .1),
                                  child: Text('${i + 1}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: _teal))),
                              const SizedBox(width: 9),
                              Expanded(
                                  child: Text('${risks[i]['label']}',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900))),
                            ]),
                        const SizedBox(height: 7),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                  _evidenceStateLabel(
                                      risks[i]['evidence_status']),
                                  style: const TextStyle(fontSize: 10))),
                          if (risks[i]['bottleneck_probability'] is num)
                            Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                    'JEV：${_bottleneckLabel(risks[i]['bottleneck_probability'])} ${_pct(risks[i]['bottleneck_probability'])}',
                                    style:
                                        const TextStyle(fontSize: 10))),
                          Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                  risks[i]['diagnostic_basis'] ==
                                          'JEV_BOTTLENECK'
                                      ? '按瓶颈证据排序'
                                      : 'JEV不可用·候选项',
                                  style: const TextStyle(fontSize: 10)))
                        ]),
                        if ('${risks[i]['evidence'] ?? ''}'.trim().isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text('你提供/确认的证据：${risks[i]['evidence']}',
                              style: const TextStyle(
                                  fontSize: 12, height: 1.4))
                        ],
                        if ('${risks[i]['mechanism'] ?? ''}'.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('它可能怎样影响行动：${risks[i]['mechanism']}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  height: 1.4))
                        ],
                        if ('${risks[i]['intervention'] ?? ''}'.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('优先改什么：${risks[i]['intervention']}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  height: 1.4))
                        ],
                        if ('${risks[i]['verification'] ?? ''}'.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('如何验证它是不是真关键：${risks[i]['verification']}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                  height: 1.4))
                        ]
                      ]))
          else
            const Text(
                '目前没有因素同时达到“已有不利/混合证据”与“JEV判断为现实瓶颈”的条件，所以这里不强行列出前三大阻碍。',
                style: TextStyle(color: Colors.black54, height: 1.4)),
          if (diagnosticSupports.isNotEmpty) ...[
            const SizedBox(height: 10),
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('当前已经在支持你的因素（${diagnosticSupports.length}）',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text(
                    '这里现在显示全部已识别的支持因素，不再只截取前3项；理论问卷中被JEV判为保护因素的项目也会纳入。'),
                children: [
                  for (final item in diagnosticSupports)
                    ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.shield_outlined,
                            color: _teal),
                        title: Text('${item['label'] ?? ''}'),
                        subtitle: Text(
                            '${item['evidence'] ?? ''}'.trim().isEmpty
                                ? '已有支持证据'
                                : '${item['evidence']}'
                                  '${item['jev_role'] == 'protective' && item['jev_role_confidence'] is num ? ' · JEV角色：保护因素 ${_pct(item['jev_role_confidence'])}' : ''}'))
                ])
          ],
          if (diagnosticUnknowns.isNotEmpty) ...[
            const SizedBox(height: 4),
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('还不能判断、最需要补事实的因素',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('未知不是中性，更不是负面；先补事实再判断'),
                children: [
                  for (final item in diagnosticUnknowns)
                    ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.help_outline),
                        title: Text('${item['label'] ?? ''}'),
                        subtitle:
                            Text('${item['next_check'] ?? ''}'))
                ])
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
    final diagnosis = growthMap(result['behavior_diagnosis']);
    final theoryFeedback =
        growthMap(diagnosis['theory_feedback_analysis']);
    final theoryFactorRows = growthRows(theoryFeedback['factor_rows']);
    final jointConclusions = growthRows(theoryFeedback['core_conclusions']);
    final jointFactorIds = <String>{
      for (final row in jointConclusions)
        ...growthStrings(row['factor_ids'])
    };

    int compareRows(MapEntry<String, dynamic> a, MapEntry<String, dynamic> b) {
      final ar = growthMap(a.value);
      final br = growthMap(b.value);
      if (ar['unknown'] == true && br['unknown'] != true) return 1;
      if (ar['unknown'] != true && br['unknown'] == true) return -1;
      final ab = (ar['bottleneck_probability'] as num?)?.toDouble();
      final bb = (br['bottleneck_probability'] as num?)?.toDouble();
      if (ab != null || bb != null) {
        final compared = (bb ?? -1).compareTo(ab ?? -1);
        if (compared != 0) return compared;
      }
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
      final evidenceState = _evidenceStateLabel(row['evidence_status']);
      final bottleneck = row['bottleneck_probability'];
      final rawBottleneck = row['raw_bottleneck_probability'];
      final bottleneckConflict = row['bottleneck_evidence_conflict'] == true;
      final construct = '${row['theory_construct'] ?? entry.key}';
      final group = '${row['theory_group'] ?? ''}';
      final directBottleneckApplicable = row['is_dynamic'] == true ||
          group == 'DIRECT_BEHAVIOR' ||
          group == 'VOLITIONAL_EXTENSION';
      final mapped = row['is_dynamic'] == true
          ? ' · 归入：${_constructLabel(construct)}'
          : '';
      return ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Icon(_factorIcon(row), color: _teal),
          title: Text('${row['label'] ?? entry.key}'),
          subtitle: Text(row['unknown'] == true
              ? '证据不足 · 不把未知当中性或阻碍$mapped'
              : directBottleneckApplicable && bottleneck is num
                  ? '$evidenceState · JEV第一阶段独立瓶颈判断：${_bottleneckLabel(bottleneck)} ${_pct(bottleneck)}$mapped'
                  : directBottleneckApplicable &&
                          bottleneckConflict &&
                          rawBottleneck is num
                      ? '$evidenceState · 瓶颈值与证据冲突，未采纳$mapped'
                      : !directBottleneckApplicable
                          ? '$evidenceState · 上游意向形成因素；不再计算“直接行为瓶颈”$mapped'
                          : source == 'USER_CONFIRMED_THEORY'
                              ? '$evidenceState · 用户确认标准选项$mapped'
                              : '$state · $source$mapped'),
          children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${row['evidence'] ?? ''}'),
                      const SizedBox(height: 7),
                      Text('证据状态：$evidenceState',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                      if (directBottleneckApplicable &&
                          bottleneck is num) ...[
                        const SizedBox(height: 3),
                        Text(
                            'JEV第一阶段独立瓶颈判断：${_pct(bottleneck)} · ${_bottleneckLabel(bottleneck)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        const Text(
                            '这个数值直接来自JEV对“该直接/执行因素当前是否构成现实瓶颈”的typed noul。它读取用户事实、理论问卷与行动上下文，但不是LLM+JEV加权综合分，也不是因果效应大小、理论权重或最终行动成功概率。',
                            style: TextStyle(
                                fontSize: 12, color: Colors.black54))
                      ] else if (directBottleneckApplicable &&
                          bottleneckConflict &&
                          rawBottleneck is num) ...[
                        const SizedBox(height: 3),
                        Text(
                            'JEV原始瓶颈值：${_pct(rawBottleneck)}（与当前证据状态冲突，未采纳）',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.orange)),
                        const SizedBox(height: 3),
                        const Text(
                            '规则：支持性证据或证据不足时，不应同时判成“当前瓶颈”。原始JEV值只保留用于审计，不进入关键阻碍排序或最终瓶颈结论。',
                            style: TextStyle(
                                fontSize: 12, color: Colors.black54))
                      ] else if (!directBottleneckApplicable) ...[
                        const SizedBox(height: 3),
                        const Text(
                            '该因素属于意向形成/上游解释层。它应通过用户理论答案、JEV理论角色与最终LLM+JEV联合结论判断其作用，而不是用“直接行为瓶颈百分比”表达。',
                            style: TextStyle(
                                fontSize: 12, color: Colors.black54))
                      ],
                      if ('${row['mechanism'] ?? ''}'.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text('机制说明：${row['mechanism']}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54))
                      ],
                      if ('${row['intervention'] ?? ''}'.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text('可控改进：${row['intervention']}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700))
                      ],
                      if (score is num) ...[
                        const SizedBox(height: 8),
                        if (source == 'USER_CONFIRMED_THEORY')
                          Text(
                              '标准选项序位：${row['ordinal_level'] ?? '—'} / 4',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700))
                        else if (source == 'JEV' && row['jev_raw_score'] is num)
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
                        Text(
                            source == 'USER_CONFIRMED_THEORY'
                                ? '这里只表示选项顺序：0更偏阻碍、4更偏支持；相邻等级不假设等距。它仅用于展示和分级排序，不是行动概率、理论权重或回归系数。'
                                : '评分含义：0=强阻碍，2=中性／信息不足，4=强支持。它不是行动成功概率，也不是理论构念的固定权重。',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                      ],
                      if (confidence is num && source == 'JEV') ...[
                        const SizedBox(height: 5),
                        Text(
                            'JEV 对这个typed评分的自报置信度：${_pct(confidence)}。这不是统计置信区间，也不是历史验证准确率。',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54))
                      ]
                    ]))
          ]);
    }

    Widget theoryFactorTile(GrowthData row) {
      final factorId = '${row['factor_id'] ?? ''}';
      final theories = growthStrings(row['theory_ids']);
      final option = '${row['option_label'] ?? ''}'.trim();
      final role = '${row['jev_role'] ?? ''}'.trim();
      final roleConfidence = row['jev_role_confidence'];
      final inJointConclusion = jointFactorIds.contains(factorId);
      final selectionSource = '${row['selection_source'] ?? ''}';
      return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Icon(
              role == 'protective'
                  ? Icons.shield_outlined
                  : role == 'key_blocker'
                      ? Icons.warning_amber_outlined
                      : Icons.psychology_alt_outlined,
              color: _teal),
          title: Text('${row['factor_label'] ?? factorId}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (option.isNotEmpty) Text('你确认：$option'),
                if (theories.isNotEmpty)
                  Text('来源理论：${theories.join(' + ')}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black54)),
                Text(
                    '${_theoryRoleLabel(role)}'
                    '${roleConfidence is num ? ' · 自报置信度 ${_pct(roleConfidence)}' : ''}',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700)),
                Text(
                    inJointConclusion
                        ? '最终LLM+JEV联合结论：已纳入'
                        : '最终LLM+JEV联合结论：未提升为关键联合因素',
                    style: TextStyle(
                        fontSize: 11,
                        color: inJointConclusion ? _teal : Colors.black54)),
                if (selectionSource.isNotEmpty)
                  Text(
                      selectionSource == 'AUTO_LLM_JEV'
                          ? '选项来源：LLM+JEV预填后由用户提交确认'
                          : '选项来源：用户选择/确认',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black54)),
              ]));
    }

    const groupOrder = [
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
            title: const Text('查看决定因素证据与JEV判断',
                style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text(
                '分两层看：①全部用户确认的理论因素及JEV角色；②真正直接影响行为/执行的因素才显示JEV第一阶段瓶颈判断。瓶颈数值不是LLM+JEV综合分。'),
            children: [
              if (theoryFactorRows.isNotEmpty) ...[
                const Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Text('A. 用户确认的理论关键因素（全量）',
                        style: TextStyle(fontWeight: FontWeight.w900))),
                const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Text(
                        '这里应覆盖已选理论问卷中所有已确认因素。重点看：你的实际选项、所属理论、JEV对当前行动的角色判断，以及它是否进入最终LLM+JEV联合结论。',
                        style: TextStyle(
                            fontSize: 12, color: Colors.black54, height: 1.4))),
                for (final row in theoryFactorRows) theoryFactorTile(row),
                const Divider(),
              ],
              const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('B. 直接行为／执行决定因素',
                      style: TextStyle(fontWeight: FontWeight.w900))),
              const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Text(
                      '只有对最终行为有直接执行意义的因素（IBM直接行为因素、执行意图，以及通过筛选的行动特异因素）才适合显示“当前瓶颈”判断。意向形成层因素不再用瓶颈百分比表达。',
                      style: TextStyle(
                          fontSize: 12, color: Colors.black54, height: 1.4))),
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
                        '这里仅显示已经通过LLM候选生成 + JEV增量预测价值筛选的行动特异因素，并映射回既有理论构念。',
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