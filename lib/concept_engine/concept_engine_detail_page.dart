import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'concept_engine_dao.dart';
import 'concept_engine_models.dart';
import 'concept_engine_session_page.dart';
import 'concept_engine_service.dart';

class ConceptEngineDetailPage extends StatelessWidget {
  final ConceptEngineSessionRecord? record;
  final int? recordId;

  const ConceptEngineDetailPage({super.key, this.record, this.recordId})
      : assert(record != null || recordId != null, 'record 和 recordId 至少传一个');

  Widget _chip(String text, {Color? bg, Color? fg}) => Container(
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bg ?? const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: TextStyle(fontSize: 12.5, color: fg)),
      );

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }

  Widget _statTile(String label, int value, Color color) {
    return Container(
      width: 104,
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (record != null) {
      return _buildScaffold(context, record!);
    }
    return FutureBuilder<ConceptEngineSessionRecord?>(
      future: ConceptEngineDao().getById(recordId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final loaded = snapshot.data;
        if (loaded == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('练习详情')),
            body: const Center(child: Text('未找到这条练习记录')),
          );
        }
        return _buildScaffold(context, loaded);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, ConceptEngineSessionRecord record) {
    final replay = record.replayOrNull;
    final state = record.stateOrNull;
    final scene = record.sceneOrNull;
    final messages = record.history;
    final process = record.processMap;
    final dt = DateFormat('yyyy-MM-dd HH:mm').format(record.createdAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('练习详情'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: jsonEncode(record.toMap())));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制练习记录 JSON'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: '复制记录 JSON',
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ConceptEngineSessionPage(
                    initialConcept: record.concept,
                    initialDomain: record.domain,
                    initialGoal: record.goal,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('再练一次'),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F7FB),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(record.concept, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('${record.totalScore}分', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${record.domain.isEmpty ? '未分类' : record.domain} · ${record.sceneTitle} · $dt', style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(record.providerLabel,
                        bg: record.provider == 'openai' ? const Color(0xFFCCFBF1) : const Color(0xFFE0E7FF),
                        fg: record.provider == 'openai' ? const Color(0xFF115E59) : const Color(0xFF3730A3)),
                    if (record.model.isNotEmpty) _chip(record.model),
                    _chip(record.transportMode == ConceptEngineService.transportProxy ? '后端网关代理' : '客户端直连'),
                    if (record.sessionKey.isNotEmpty) _chip('会话 ${record.sessionKey}'),
                    if (record.cabinType.isNotEmpty) _chip('训练舱 ${record.cabinType}'),
                    _chip(record.resultLabel, bg: const Color(0xFF111827), fg: Colors.white),
                  ],
                ),
                if (record.goal.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('训练目标：${record.goal}', style: const TextStyle(height: 1.45)),
                ],
                const SizedBox(height: 12),
                Text(record.summary, style: const TextStyle(height: 1.45)),
              ],
            ),
          ),
          if (scene != null) ...[
            const SizedBox(height: 16),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('场景信息', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(scene.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('${scene.userRole} · ${scene.goal}', style: const TextStyle(height: 1.45)),
                  if (scene.background.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(scene.background, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
                  ],
                  if (scene.trainingFocus.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('训练重点', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(children: scene.trainingFocus.map(_chip).toList()),
                  ],
                ],
              ),
            ),
          ],
          if (state != null) ...[
            const SizedBox(height: 16),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('最终状态', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(children: [
                    _statTile('信任', state.trustScore, Colors.blue),
                    _statTile('风险', state.riskScore, Colors.red),
                    _statTile('剩余时间', state.timeLeft, Colors.orange),
                    _statTile('目标推进', state.goalProgress, Colors.green),
                    _statTile('团队稳定', state.teamStability, Colors.teal),
                    _statTile('情绪张力', state.emotionTension, Colors.purple),
                  ]),
                  if (state.finishReason.isNotEmpty)
                    Text('结束原因：${state.finishReason}', style: const TextStyle(color: Color(0xFF6B7280))),
                  if (record.triggeredEvents.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('触发事件', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(children: record.triggeredEvents.map((e) => _chip(e, bg: const Color(0xFFFEE2E2), fg: const Color(0xFF991B1B))).toList()),
                  ],
                  if (record.actionTags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('动作标签', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(children: record.actionTags.map((e) => _chip(e, bg: const Color(0xFFE0F2FE), fg: const Color(0xFF0C4A6E))).toList()),
                  ],
                ],
              ),
            ),
          ],
          if (process.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('训练舱过程摘要', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if ((process['selected_attitude'] ?? '').toString().isNotEmpty)
                    Text('进入态度：${process['selected_attitude']}', style: const TextStyle(height: 1.45)),
                  if (process['prep'] is Map) ...[
                    const SizedBox(height: 10),
                    const Text('准备台结果', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(const JsonEncoder.withIndent('  ').convert(process['prep']), style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
                  ],
                  if ((process['impact_decision'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('冲击层快速决断', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('${process['impact_decision']}', style: const TextStyle(height: 1.45)),
                  ],
                ],
              ),
            ),
          ],
          if (replay != null) ...[
            const SizedBox(height: 16),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('复盘结果', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(replay.summary, style: const TextStyle(height: 1.45)),
                  if (replay.rootCauses.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('根本原因', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    ...replay.rootCauses.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• $e'),
                        )),
                  ],
                  if (replay.ignoredSignals.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('忽略的信号', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    ...replay.ignoredSignals.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• $e'),
                        )),
                  ],
                  if (replay.betterActions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('更优替代动作', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    ...replay.betterActions.map((e) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('问题：${e.problem}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text('更优动作：${e.betterAction}'),
                              if (e.examplePhrase.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text('示例表达：${e.examplePhrase}', style: const TextStyle(color: Color(0xFF4B5563))),
                              ],
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ],
          if (messages.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('对话回放', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ...messages.map((m) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: m.role == 'user' ? const Color(0xFFE0F2FE) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.role == 'user' ? '你' : '系统/NPC', style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(m.content, style: const TextStyle(height: 1.45)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
