import 'package:flutter/material.dart';

import 'cognitive_consistency_dao.dart';
import 'cognitive_consistency_home_page.dart';

class CcSourceEvidenceStatusCard extends StatelessWidget {
  const CcSourceEvidenceStatusCard({
    super.key,
    required this.sourceType,
    required this.sourceId,
    required this.initialGoal,
    required this.initialContext,
    this.initialValues = '',
  });

  final String sourceType;
  final String sourceId;
  final String initialGoal;
  final String initialContext;
  final String initialValues;

  Future<Map<String, dynamic>> _load() async {
    final dao = CognitiveConsistencyDao();
    final map = await dao.evidenceStatusForSources(<({String sourceType, String sourceId})>[(sourceType: sourceType, sourceId: sourceId)]);
    final item = map['$sourceType|$sourceId'];
    final count = item?.count ?? 0;
    final latestAt = item?.latestAtMs ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    var triggerType = '';
    var message = '';
    var recommendedTab = '1';
    var severity = 0;
    if (count == 0) {
      triggerType = 'no_evidence';
      message = '该行动节点还没有一致行动证据，建议先生成一个 1 美元行动。';
      recommendedTab = '1';
      severity = 2;
    } else if (count >= 3) {
      triggerType = 'many_evidence_review';
      message = '已有多条一致行动证据，建议进入复盘，把有效模式转成下一步。';
      recommendedTab = '3';
      severity = 1;
    } else if (latestAt > 0 && now - latestAt > const Duration(days: 7).inMilliseconds) {
      triggerType = 'stale_evidence';
      message = '超过 7 天没有新证据，建议用诚实校验或奖励降噪找回行动入口。';
      recommendedTab = '5';
      severity = 2;
    } else {
      triggerType = 'continue_small_action';
      message = '已有行动证据，下一次卡住时可继续生成最小行动。';
      recommendedTab = '2';
      severity = 0;
    }
    await dao.saveTriggerSuggestion(
      sourceType: sourceType,
      sourceId: sourceId,
      triggerType: triggerType,
      message: message,
      recommendedTab: recommendedTab,
      severity: severity,
    );
    return <String, dynamic>{
      'count': count,
      'latest': item?.latestAction ?? '',
      'latestAtMs': latestAt,
      'values': item?.values ?? const <String>[],
      'trigger': message,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (sourceType.trim().isEmpty || sourceId.trim().isEmpty) return const SizedBox.shrink();
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (context, snapshot) {
        final count = (snapshot.data?['count'] as int?) ?? 0;
        final latest = (snapshot.data?['latest'] ?? '').toString();
        final values = (snapshot.data?['values'] as List<String>?) ?? const <String>[];
        final has = count > 0;
        final color = has ? const Color(0xFF2563EB) : const Color(0xFF64748B);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: has ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: has ? const Color(0xFFBFDBFE) : const Color(0xFFE5E7EB)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(has ? Icons.verified_outlined : Icons.sync_alt_outlined, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(has ? '一致行动证据 $count 条' : '暂无一致行动证据', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
              TextButton(
                onPressed: () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CognitiveConsistencyHomePage(
                        initialTabIndex: has ? 4 : 1,
                        initialGoal: initialGoal,
                        initialContext: initialContext,
                        initialValues: initialValues,
                        sourceType: sourceType,
                        sourceId: sourceId,
                      ),
                    ),
                  );
                  if (changed == true && context.mounted) (context as Element).markNeedsBuild();
                },
                child: Text(has ? '复盘/继续' : '生成证据'),
              ),
            ]),
            if (values.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('关联价值：${values.take(3).join('、')}', style: const TextStyle(fontSize: 12, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w700))),
            if (latest.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('最近证据：$latest', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.35))),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '智能触发：${(snapshot.data?['trigger'] ?? '').toString().isEmpty ? (has ? '已有行动证据，下一次卡住时可继续生成最小行动。' : '该行动树节点还没有证据，建议先生成一个 1 美元行动。') : snapshot.data?['trigger']}',
                style: TextStyle(fontSize: 12, color: color, height: 1.35),
              ),
            ),
          ]),
        );
      },
    );
  }
}
