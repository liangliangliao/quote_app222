import 'package:flutter/material.dart';

import 'evidence_growth_action_prediction.dart';
import 'evidence_growth_action_review.dart';
import 'evidence_growth_forecast_science.dart';
import 'evidence_growth_journey_models.dart';

class EvidenceGrowthActionReviewPage extends StatefulWidget {
  const EvidenceGrowthActionReviewPage({
    super.key,
    required this.prediction,
    required this.service,
    required this.jevApiKey,
  });
  final GrowthData prediction;
  final EvidenceGrowthActionPredictionService service;
  final String jevApiKey;
  @override
  State<EvidenceGrowthActionReviewPage> createState() =>
      _ActionReviewPageState();
}

class _ActionReviewPageState extends State<EvidenceGrowthActionReviewPage> {
  final fields = <String, TextEditingController>{};
  final verdicts = <String, String>{};
  final observedFactors = <String>{};
  String selectedOutcome = 'UNOBSERVED';
  bool? primaryEventObserved;
  DateTime observedAt = DateTime.now();
  bool busy = false;
  String status = '';
  GrowthData latest = {};
  static const labels = {
    'timeline': '实际发生了什么？按先后写下可观察的事实（必填）',
    'breakpoint': '行动在哪里继续或中断？当时的事件、感受、念头是什么？',
    'intervention_done': '哪些改进真的落实了？哪些没有？',
    'learning': '这次使你理解了什么理论关系？',
    'attitude_before': '行动前，你对这件事原先怎样看？',
    'attitude_after': '现在怎样看？支持这个变化的事实是什么？',
    'next_change': '下一次想检验的一个改变（可选）',
  };

  @override
  void initState() {
    super.initState();
    latest = widget.prediction;
    final observations = growthMap(
      growthMap(latest['diagnostic_review'])['user_observations'],
    );
    for (final key in labels.keys) {
      fields[key] = TextEditingController(text: '${observations[key] ?? ''}');
    }
    for (final e in growthMap(observations['hypothesis_verdicts']).entries) {
      verdicts[e.key] = '${e.value}';
    }
    observedFactors.addAll(growthStrings(observations['observed_factor_ids']));
    final outcome = '${latest['outcome']}';
    if (const {
      'SUCCESS',
      'FAILED',
      'PARTIAL',
      'CANCELLED',
      'UNOBSERVED',
    }.contains(outcome)) selectedOutcome = outcome;
    primaryEventObserved = latest['primary_event_observed'] as bool?;
    if (latest['outcome_at_ms'] is num)
      observedAt = DateTime.fromMillisecondsSinceEpoch(
          (latest['outcome_at_ms'] as num).toInt());
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  GrowthData get observations => {
        for (final e in fields.entries) e.key: e.value.text.trim(),
        'hypothesis_verdicts': {
          ...verdicts,
          for (final id in observedFactors) id: 'SUPPORTED',
        },
        'observed_factor_ids': observedFactors.toList(),
      };

  Future<void> save({required bool analyze}) async {
    if (busy) return;
    if (fields['timeline']!.text.trim().isEmpty) {
      setState(() => status = '请先写下实际发生了什么。');
      return;
    }
    setState(() {
      busy = true;
      status = '正在保存实际观察…';
    });
    try {
      await widget.service.recordOutcome(
        '${latest['id']}',
        selectedOutcome,
        observedAt: observedAt,
        primaryEventObserved: selectedOutcome == 'SUCCESS'
            ? true
            : selectedOutcome == 'FAILED'
                ? false
                : primaryEventObserved,
        observations: observations,
      );
      await widget.service.saveReview('${latest['id']}', {
        'status': 'DRAFT',
        'user_observations': observations,
      });
      latest = (await widget.service.history()).firstWhere(
        (r) => r['id'] == latest['id'],
      );
      if (analyze) {
        if (mounted) setState(() => status = '观察已保存，LLM与JEV正在复盘…');
        final reviewed = await EvidenceGrowthActionReview().analyze(
          prediction: latest,
          observations: observations,
          jevApiKey: widget.jevApiKey,
        );
        await widget.service.saveReview('${latest['id']}', reviewed);
        latest = (await widget.service.history()).firstWhere(
          (r) => r['id'] == latest['id'],
        );
        if (reviewed['status'] != 'COMPLETE') {
          if (mounted) setState(() => status = '观察与LLM复盘已保存；JEV尚未成功，稍后可重试。');
          return;
        }
      }
      if (mounted) Navigator.pop(context, latest);
    } catch (e) {
      if (mounted)
        setState(
          () =>
              status = '未完成：${'$e'.replaceFirst('Bad state: ', '')}。已保存的观察仍保留。',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roots = growthRows(
      growthMap(latest['scientific_report'])['roots_and_experiments'],
    );
    final factors = growthRows(
      growthMap(
        growthMap(latest['behavior_diagnosis'])['theory_feedback_analysis'],
      )['factor_rows'],
    );
    final contract = growthMap(latest['event_contract']);
    return Scaffold(
      appBar: AppBar(title: const Text('现实结果与原因复盘')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '本次冻结的标准：${contract['success_criterion'] ?? latest['plan']}\n观察窗口：${contract['observation_window'] ?? '旧版未记录'}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule),
            label: Text(
                '实际观察时间：${observedAt.toLocal().toString().substring(0, 16)}\n补记时请选择当时确认结果的时间'),
            onPressed: busy
                ? null
                : () async {
                    final day = await showDatePicker(
                        context: context,
                        initialDate: observedAt,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now());
                    if (day == null || !context.mounted) return;
                    final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(observedAt));
                    if (time == null || !mounted) return;
                    final chosen = DateTime(
                        day.year, day.month, day.day, time.hour, time.minute);
                    setState(() {
                      if (chosen.isAfter(DateTime.now())) {
                        status = '实际观察时间不能在未来';
                      } else {
                        observedAt = chosen;
                        status = '';
                      }
                    });
                  },
          ),
          DropdownButtonFormField<String>(
            initialValue: selectedOutcome,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '实际结果'),
            items: const {
              'SUCCESS': '主事件达成',
              'FAILED': '窗口结束，主事件未达成',
              'PARTIAL': '部分完成／偏离计划',
              'UNOBSERVED': '尚未观察／无法观察',
              'CANCELLED': '合理取消或改目标',
            }
                .entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: busy
                ? null
                : (v) => setState(() {
                      selectedOutcome = v!;
                      primaryEventObserved = null;
                    }),
          ),
          if (selectedOutcome == 'PARTIAL')
            DropdownButtonFormField<String>(
              initialValue: primaryEventObserved == true
                  ? 'yes'
                  : primaryEventObserved == false
                      ? 'no'
                      : 'unknown',
              decoration: const InputDecoration(labelText: '部分完成时，原主事件标准是否达成？'),
              items: const [
                DropdownMenuItem(value: 'yes', child: Text('达成')),
                DropdownMenuItem(value: 'no', child: Text('未达成')),
                DropdownMenuItem(value: 'unknown', child: Text('不确定，不计入校准')),
              ],
              onChanged: busy
                  ? null
                  : (v) => setState(
                        () => primaryEventObserved = v == 'yes'
                            ? true
                            : v == 'no'
                                ? false
                                : null,
                      ),
            ),
          for (final e in labels.entries)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextField(
                controller: fields[e.key],
                enabled: !busy,
                minLines: 2,
                maxLines: 5,
                maxLength: 1800,
                decoration: InputDecoration(
                  labelText: e.value,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          if (roots.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('原假设经现实观察后怎样变化？一次结果不能证实因果。'),
            ),
          for (final row in roots)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: DropdownButtonFormField<String>(
                initialValue: verdicts['${row['id']}'] ?? 'UNRESOLVED',
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: EvidenceForecastScience.text(row['title'], 80),
                ),
                items: const [
                  DropdownMenuItem(value: 'SUPPORTED', child: Text('观察增加了支持')),
                  DropdownMenuItem(value: 'WEAKENED', child: Text('观察削弱了假设')),
                  DropdownMenuItem(value: 'UNRESOLVED', child: Text('仍无法判断')),
                ],
                onChanged: busy
                    ? null
                    : (v) => setState(() => verdicts['${row['id']}'] = v!),
              ),
            ),
          if (factors.isNotEmpty)
            ExpansionTile(
              title: const Text('哪些阻碍实际出现在断点之前？'),
              subtitle: const Text('只勾选这次确实观察到的，不照抄模型判断'),
              children: [
                for (final row in factors)
                  CheckboxListTile(
                    title: Text('${row['factor_label']}'),
                    value: observedFactors.contains('${row['factor_id']}'),
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                              if (v == true) {
                                observedFactors.add('${row['factor_id']}');
                              } else {
                                observedFactors.remove('${row['factor_id']}');
                              }
                            }),
                  ),
              ],
            ),
          if (status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(status),
            ),
          if (busy) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : () => save(analyze: true),
            child: const Text('保存观察并由LLM＋JEV复盘'),
          ),
          TextButton(
            onPressed: busy ? null : () => save(analyze: false),
            child: const Text('先保存观察，稍后分析'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
