import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/kv_dao.dart';
import '../pages/settings_page.dart';
import 'xiangji_database.dart';
import 'xiangji_models.dart';
import 'xiangji_repository.dart';
import 'xiangji_rev4_models.dart';
import 'xiangji_state_machine.dart';
import 'xiangji_strategist_monitor_service.dart';
import 'xiangji_ui_support.dart';

class XiangjiEpistemicWorldPage extends StatefulWidget {
  const XiangjiEpistemicWorldPage({super.key, required this.dao});

  final XiangjiDao dao;

  @override
  State<XiangjiEpistemicWorldPage> createState() =>
      _XiangjiEpistemicWorldPageState();
}

class _XiangjiEpistemicWorldPageState
    extends State<XiangjiEpistemicWorldPage> {
  bool _loading = true;
  List<Map<String, Object?>> _experiences = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _claims = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _debts = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _concepts = const <Map<String, Object?>>[];
  List<XiangjiCognitiveExperienceDraft> _cognitiveChanges =
      const <XiangjiCognitiveExperienceDraft>[];
  List<Map<String, Object?>> _conflicts = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _learningMoments =
      const <Map<String, Object?>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Widget _cognitiveChangeRows() {
    if (_cognitiveChanges.isEmpty && _learningMoments.isEmpty) {
      return const XiangjiEmptyState(
        title: '认识还没有发生可见变化',
        message: '当军师区分体验与解释、比较案例或被新现实修订时，这里会记录“怎样变了”。',
        icon: Icons.auto_awesome_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final change in _cognitiveChanges)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: Text(change.headline),
              subtitle: Text(change.userMessage),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final detail in change.details.entries)
                        XiangjiLabeledValue(
                          label: detail.key,
                          value: detail.value,
                        ),
                      if (change.methodText.isNotEmpty)
                        XiangjiLabeledValue(
                          label: '这次使用的方法',
                          value: change.methodText,
                        ),
                      if (change.transferPrompt.isNotEmpty)
                        XiangjiLabeledValue(
                          label: '可选迁移练习',
                          value: change.transferPrompt,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _experienceInterpretationRows() {
    if (_experiences.isEmpty && _claims.isEmpty && _debts.isEmpty) {
      return const XiangjiEmptyState(
        title: '暂无经验与解释',
        message: '用户原话、真实体验与当前解释会分层出现，解释不会伪装成外部事实。',
        icon: Icons.visibility_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('实际发生 / 真实体验',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final row in _experiences)
          _plainTile(
            icon: Icons.visibility_outlined,
            title: (row['content'] ?? '').toString(),
            subtitle: row['is_user_wording'] == 1
                ? '按你的原话保留'
                : '从原话中提取，仍可由你纠正',
          ),
        const SizedBox(height: 12),
        const Text('用户解释 / 军师当前判断',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final row in _claims)
          _plainTile(
            icon: Icons.psychology_alt_outlined,
            title: (row['text'] ?? '').toString(),
            subtitle:
                '${_claimKind((row['claim_type'] ?? '').toString())} · ${_epistemicLabel((row['epistemic_status'] ?? '').toString())}',
          ),
        if (_debts.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('仍会改变判断的未知',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final row in _debts)
            _plainTile(
              icon: Icons.help_outline,
              title: (row['description'] ?? '').toString(),
              subtitle:
                  '${_impactLabel((row['decision_impact'] ?? '').toString())}；需要补清：${row['grounding_gap'] ?? ''}',
            ),
        ],
      ],
    );
  }

  Widget _conceptBoundaryRows() {
    if (_concepts.isEmpty) {
      return const XiangjiEmptyState(
        title: '暂无需要审查的个人概念',
        message: '概念会连回具体实例、反例、适用边界与仍未解释的细节，不会成为关于你的永久标签。',
        icon: Icons.category_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final row in _concepts)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              leading: const Icon(Icons.category_outlined),
              title: Text((row['name'] ?? '当前概念').toString()),
              subtitle: Text((row['definition'] ?? '').toString()),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                XiangjiLabeledValue(
                  label: '支持它的具体例子 / 可观察判据',
                  value: _naturalList(row['observable_criteria_json']),
                ),
                XiangjiLabeledValue(
                  label: '支持材料',
                  value: _naturalList(row['support_refs_json']),
                ),
                XiangjiLabeledValue(
                  label: '反例',
                  value: _naturalList(row['counterexample_refs_json']),
                ),
                XiangjiLabeledValue(
                  label: '适用边界',
                  value: (row['applicability_boundary'] ?? '').toString().trim().isEmpty
                      ? '只适用于当前问题与已记录情境'
                      : row['applicability_boundary'].toString(),
                ),
                XiangjiLabeledValue(
                  label: '仍未解释的细节',
                  value: _naturalList(row['unexplained_details_json']),
                ),
                XiangjiLabeledValue(
                  label: '这版为什么改变',
                  value: (row['change_reason'] ?? '').toString(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _realityConflictRows() {
    if (_conflicts.isEmpty && _learningMoments.isEmpty) {
      return const XiangjiEmptyState(
        title: '当前没有现实冲突',
        message: '当预测或旧解释连续不能说明现实时，这里会明确显示冲突、回溯与修订。',
        icon: Icons.compare_arrows_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final row in _conflicts)
          _plainTile(
            icon: Icons.compare_arrows_outlined,
            title: '现实正在挑战你的旧解释',
            subtitle:
                '${row['mismatch_pattern'] ?? ''}\n影响：${row['impact'] ?? ''}\n当前处理：${_conflictStatus((row['status'] ?? '').toString())}',
          ),
        for (final row in _learningMoments)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('这次认识怎样改变了？'),
              subtitle: Text((row['revised_model'] ?? '').toString()),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                XiangjiLabeledValue(
                  label: '旧认识',
                  value: (row['old_model'] ?? '').toString(),
                ),
                XiangjiLabeledValue(
                  label: '新现实',
                  value: (row['new_reality'] ?? '').toString(),
                ),
                XiangjiLabeledValue(
                  label: '修订后的理解',
                  value: (row['revised_model'] ?? '').toString(),
                ),
                XiangjiLabeledValue(
                  label: '可以迁移的方法',
                  value: (row['method_learned'] ?? '').toString(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _plainTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) =>
      Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(icon, color: XiangjiPalette.pine),
          title: Text(title),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(subtitle),
          ),
        ),
      );

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object?>(<Future<Object?>>[
        widget.dao.allExperiences(),
        widget.dao.allClaims(),
        widget.dao.debts(openOnly: false),
        widget.dao.conceptVersions(),
        widget.dao.cognitiveExperiences(limit: 300),
        widget.dao.conceptRealityConflicts(limit: 300),
        widget.dao.learningMoments(limit: 300),
      ]);
      if (!mounted) return;
      setState(() {
        _experiences = values[0] as List<Map<String, Object?>>;
        _claims = values[1] as List<Map<String, Object?>>;
        _debts = values[2] as List<Map<String, Object?>>;
        _concepts = values[3] as List<Map<String, Object?>>;
        _cognitiveChanges =
            values[4] as List<XiangjiCognitiveExperienceDraft>;
        _conflicts = values[5] as List<Map<String, Object?>>;
        _learningMoments = values[6] as List<Map<String, Object?>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      xiangjiShowMessage(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: XiangjiPalette.mist,
        appBar: AppBar(
          title: const Text('我的认识世界'),
          backgroundColor: XiangjiPalette.mist,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '认识变化'),
              Tab(text: '经验与解释'),
              Tab(text: '概念边界'),
              Tab(text: '现实冲突'),
            ],
          ),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _cognitiveChangeRows(),
                  _experienceInterpretationRows(),
                  _conceptBoundaryRows(),
                  _realityConflictRows(),
                ],
              ),
      ),
    );
  }

  String _naturalList(Object? raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is List) {
        final values = decoded
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
        return values.isEmpty ? '当前没有已确认材料' : values.join('；');
      }
    } catch (_) {}
    final value = (raw ?? '').toString().trim();
    return value.isEmpty ? '当前没有已确认材料' : value;
  }

  String _claimKind(String value) => switch (value.toLowerCase()) {
        'user_interpretation' => '你的解释',
        'prediction' => '尚待现实检验的预测',
        'ai_inference' => '军师当前推断',
        'causal_hypothesis' => '候选原因',
        _ => '当前可修订判断',
      };

  String _epistemicLabel(String value) => switch (value.toUpperCase()) {
        'SUPPORTED' => '当前有较强现实支持',
        'PROVISIONAL' => '当前材料暂时支持',
        'EPISTEMIC_DEBT' => '仍有会改变判断的关键未知',
        'UNRESOLVED' => '现实根据仍不足',
        _ => '当前理解仍可修订',
      };

  String _impactLabel(String value) => switch (value.toLowerCase()) {
        'critical' => '会直接改变重大决定',
        'high' => '很可能改变下一步',
        'medium' => '可能影响路线',
        _ => '当前影响较低',
      };

  String _conflictStatus(String value) => switch (value.toUpperCase()) {
        'MISMATCH_DETECTED' => '已发现不一致，正在回溯',
        'UNDER_REVIEW' => '正在比较旧解释与新现实',
        'REFINED' => '旧解释已经收窄边界',
        'SUPERSEDED' => '旧解释已被新版本替代',
        'RETAINED_WITH_SCOPE' => '旧解释只在更小范围内保留',
        _ => '等待现实复核',
      };
}

class XiangjiHistoryPage extends StatefulWidget {
  const XiangjiHistoryPage({super.key, required this.dao});

  final XiangjiDao dao;

  @override
  State<XiangjiHistoryPage> createState() => _XiangjiHistoryPageState();
}

class _XiangjiHistoryPageState extends State<XiangjiHistoryPage> {
  bool _loading = true;
  List<Map<String, Object?>> _reviews = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _rules = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _aiErrors = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _learning = const <Map<String, Object?>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object?>(<Future<Object?>>[
        widget.dao.battleReviews(),
        widget.dao.personalRules(),
        widget.dao.aiErrors(),
        widget.dao.learningMoments(limit: 300),
      ]);
      if (!mounted) return;
      setState(() {
        _reviews = values[0] as List<Map<String, Object?>>;
        _rules = values[1] as List<Map<String, Object?>>;
        _aiErrors = values[2] as List<Map<String, Object?>>;
        _learning = values[3] as List<Map<String, Object?>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      xiangjiShowMessage(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: XiangjiPalette.mist,
        appBar: AppBar(
          title: const Text('战史与个人兵法'),
          backgroundColor: XiangjiPalette.mist,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '战史'),
              Tab(text: '个人兵法'),
              Tab(text: '军师怎样修正'),
              Tab(text: '认识变化'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _historyRows(
                    _reviews,
                    empty: '战役关闭时必须先形成复盘，之后会出现在这里。',
                    title: (row) => '一次战役现实复盘',
                    subtitle: (row) => _reviewOutcome(row['outcome_json']),
                    details: (row) => <MapEntry<String, String>>[
                      MapEntry(
                        '战前怎样理解',
                        _reviewModel(row['prewar_model_json']),
                      ),
                      MapEntry(
                        '采用和比较过的路线',
                        _reviewStrategies(row['strategy_json']),
                      ),
                      MapEntry(
                        '关键转折点',
                        _naturalJsonList(row['turning_points_json']),
                      ),
                      MapEntry('现实结果', _reviewOutcome(row['outcome_json'])),
                      MapEntry(
                        '下一次可以迁移的教训',
                        _naturalJsonList(row['lessons_json']),
                      ),
                    ],
                  ),
                  _historyRows(
                    _rules,
                    empty: '多事件支持、反例检查和明确确认后，个人规律才会稳定化。',
                    title: (row) => (row['rule_text'] ?? '一条暂时规律').toString(),
                    subtitle: (row) =>
                        '适用范围：${row['scope'] ?? '仍需更多案例确认'}',
                    details: (row) => <MapEntry<String, String>>[
                      MapEntry('支持它的现实',
                          (row['support_summary'] ?? '').toString()),
                      MapEntry('反例与边界',
                          (row['counterexample_summary'] ?? '').toString()),
                      MapEntry('怎样继续验证',
                          (row['validation_plan'] ?? '').toString()),
                    ],
                  ),
                  _historyRows(
                    _aiErrors,
                    empty: '被现实结果反驳的 AI 判断会留下可追溯失误记录。',
                    title: (row) =>
                        (row['impact'] ?? '军师判断被现实修订').toString(),
                    subtitle: (row) =>
                        (row['correction'] ?? '旧判断保留，新版本继续求解').toString(),
                    details: (row) => <MapEntry<String, String>>[
                      MapEntry('现实怎样发现问题',
                          _discoverySource((row['discovered_by'] ?? '').toString())),
                      MapEntry('修订', (row['correction'] ?? '').toString()),
                    ],
                  ),
                  _historyRows(
                    _learning,
                    empty: '当新现实改变旧认识时，会形成一条可迁移的学习记录。',
                    title: (row) => '这次认识怎样改变了？',
                    subtitle: (row) => (row['revised_model'] ?? '').toString(),
                    details: (row) => <MapEntry<String, String>>[
                      MapEntry('旧认识', (row['old_model'] ?? '').toString()),
                      MapEntry('新现实', (row['new_reality'] ?? '').toString()),
                      MapEntry('修订后的理解',
                          (row['revised_model'] ?? '').toString()),
                      MapEntry('可以迁移的方法',
                          (row['method_learned'] ?? '').toString()),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _historyRows(
    List<Map<String, Object?>> rows, {
    required String empty,
    required String Function(Map<String, Object?> row) title,
    required String Function(Map<String, Object?> row) subtitle,
    required List<MapEntry<String, String>> Function(
      Map<String, Object?> row,
    ) details,
  }) {
    if (rows.isEmpty) {
      return XiangjiEmptyState(
        title: '暂无记录',
        message: empty,
        icon: Icons.history_edu_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = rows[index];
        return ExpansionTile(
          collapsedBackgroundColor: Colors.white,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            title(row).trim().isEmpty ? '记录 ${index + 1}' : title(row),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(subtitle(row)),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final detail in details(row))
                    XiangjiLabeledValue(
                      label: detail.key,
                      value: detail.value,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _discoverySource(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('reality')) return '行动后的现实结果与事前预测不一致';
    if (lower.contains('user')) return '你直接纠正了军师的理解';
    return '新的可追溯现实材料触发了复核';
  }

  String _naturalJsonList(Object? raw) {
    try {
      final value = raw is String ? jsonDecode(raw) : raw;
      if (value is List) {
        final items = value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
        return items.isEmpty ? '当前没有已确认记录' : items.join('；');
      }
    } catch (_) {}
    return '当前没有已确认记录';
  }

  String _reviewModel(Object? raw) {
    try {
      final value = raw is String ? jsonDecode(raw) : raw;
      if (value is Map) {
        return <String>[
          if ((value['north_star'] ?? '').toString().trim().isNotEmpty)
            '核心目标：${value['north_star']}',
          if ((value['war_worthiness'] ?? '').toString().trim().isNotEmpty)
            '为什么值得投入：${value['war_worthiness']}',
          if ((value['victory_criteria'] ?? '').toString().trim().isNotEmpty)
            '胜利判据：${value['victory_criteria']}',
          if ((value['exit_criteria'] ?? '').toString().trim().isNotEmpty)
            '退出判据：${value['exit_criteria']}',
        ].join('；');
      }
    } catch (_) {}
    return '战前模型已保留，但当前没有可呈现摘要';
  }

  String _reviewStrategies(Object? raw) {
    try {
      final value = raw is String ? jsonDecode(raw) : raw;
      if (value is List) {
        final names = value
            .whereType<Map>()
            .map((item) => (item['name'] ?? '').toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
        return names.isEmpty ? '当前没有路线摘要' : names.join('；');
      }
    } catch (_) {}
    return '当前没有路线摘要';
  }

  String _reviewOutcome(Object? raw) {
    try {
      final value = raw is String ? jsonDecode(raw) : raw;
      if (value is Map) {
        final reality = (value['reality'] ?? '').toString().trim();
        final outcome = switch ((value['classification'] ?? '')
            .toString()
            .toUpperCase()) {
          'WON' => '达到胜利判据',
          'LOST' => '没有达到胜利判据',
          'RETREAT' => '按退出条件停止投入',
          _ => '战役已经结束并进入复盘',
        };
        return reality.isEmpty ? outcome : '$outcome；现实记录：$reality';
      }
    } catch (_) {}
    return '战役已经结束并进入复盘';
  }
}

class XiangjiSettingsPage extends StatefulWidget {
  const XiangjiSettingsPage({
    super.key,
    required this.dao,
    required this.repository,
  });

  final XiangjiDao dao;
  final XiangjiRepository repository;

  @override
  State<XiangjiSettingsPage> createState() => _XiangjiSettingsPageState();
}

class _XiangjiSettingsPageState extends State<XiangjiSettingsPage> {
  static const String _plainLanguageKey = 'xiangji_plain_language_v1';
  static const String _monitorKey = 'xiangji_monitor_enabled_v1';
  static const String _methodTrainingKey = 'xiangji_method_training_v1';
  static const String _cloudSensitiveKey =
      'xiangji_sensitive_cloud_authorized_v1';

  final KeyValueDao _kv = KeyValueDao();
  bool _plainLanguage = false;
  bool _monitorEnabled = true;
  bool _methodTrainingEnabled = false;
  bool _sensitiveCloudAuthorized = false;
  bool _loading = true;
  bool _working = false;
  String _lastExportPath = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait<String?>(<Future<String?>>[
      _kv.getString(_plainLanguageKey),
      _kv.getString(_monitorKey),
      _kv.getString(_cloudSensitiveKey),
      _kv.getString(_methodTrainingKey),
    ]);
    if (!mounted) return;
    setState(() {
      _plainLanguage = values[0] == '1';
      _monitorEnabled = values[1] != '0';
      _sensitiveCloudAuthorized = values[2] == '1';
      _methodTrainingEnabled = values[3] == '1';
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) =>
      _kv.setString(key, value ? '1' : '0');

  Future<String> _export() async {
    final snapshot = await widget.dao.exportSnapshot();
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'xiangji', 'exports'));
    await directory.create(recursive: true);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final file = File(p.join(directory.path, 'xiangji_v6_1_rev5_2_$stamp.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(snapshot));
    if (mounted) setState(() => _lastExportPath = file.path);
    return file.path;
  }

  Future<void> _exportFromUi() async {
    setState(() => _working = true);
    try {
      final path = await _export();
      if (mounted) xiangjiShowMessage(context, '已导出：$path');
    } catch (error) {
      if (mounted) xiangjiShowMessage(context, error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _reset() async {
    final values = await showXiangjiFormDialog(
      context,
      title: '删除向己·未来军师数据',
      note: '系统会先自动导出 JSON 备份，再删除本模块的用户记录。Todo 本体、全局 AI 设置与其他模块不会删除。K0 硬规则会恢复。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'confirm',
          label: '输入“删除向己数据”确认',
          required: true,
        ),
      ],
      submitLabel: '导出后删除',
    );
    if (values == null) return;
    if (values['confirm'] != '删除向己数据') {
      xiangjiShowMessage(context, '确认文字不匹配，未删除任何数据。');
      return;
    }
    setState(() => _working = true);
    try {
      final path = await _export();
      await widget.dao.resetUserData();
      if (mounted) {
        xiangjiShowMessage(context, '已删除本模块用户数据；备份位于 $path');
      }
    } catch (error) {
      if (mounted) xiangjiShowMessage(context, error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _runMonitor() async {
    final values = await showXiangjiFormDialog(
      context,
      title: '主动监督输入',
      note: '红色预警会冻结行动与战役推进；橙色要求停止加码；蓝色只表示机会条件满足，仍需核查。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(keyName: 'unknowns', label: '关键未知项数量', initialValue: '0', required: true, keyboardType: TextInputType.number),
        XiangjiFormFieldSpec(keyName: 'misses', label: '连续预测失误次数', initialValue: '0', required: true, keyboardType: TextInputType.number),
        XiangjiFormFieldSpec(keyName: 'waste', label: '投入上升但无结果周期', initialValue: '0', required: true, keyboardType: TextInputType.number),
        XiangjiFormFieldSpec(keyName: 'fronts', label: '并行高负荷战役数', initialValue: '0', required: true, keyboardType: TextInputType.number),
        XiangjiFormFieldSpec(keyName: 'risk', label: '是否高风险不可逆（是/否）', initialValue: '否', required: true),
        XiangjiFormFieldSpec(keyName: 'debt', label: '是否有会改变决定的关键未知（是/否）', initialValue: '否', required: true),
        XiangjiFormFieldSpec(keyName: 'opportunity_met', label: '已满足机会条件数', initialValue: '0', required: true, keyboardType: TextInputType.number),
        XiangjiFormFieldSpec(keyName: 'opportunity_total', label: '机会条件总数', initialValue: '0', required: true, keyboardType: TextInputType.number),
      ],
      submitLabel: '运行监督',
    );
    if (values == null) return;
    bool yes(String key) =>
        values[key]!.toLowerCase() == 'yes' || values[key] == '是';
    try {
      final result = await widget.repository.runMonitor(
        input: XiangjiMonitorInput(
          criticalUnknownCount: int.tryParse(values['unknowns']!) ?? 0,
          consecutivePredictionMisses: int.tryParse(values['misses']!) ?? 0,
          investmentRisingWithoutResultCycles:
              int.tryParse(values['waste']!) ?? 0,
          parallelHighLoadCampaigns: int.tryParse(values['fronts']!) ?? 0,
          highRiskIrreversible: yes('risk'),
          highEpistemicDebt: yes('debt'),
          opportunityConditionsMet:
              int.tryParse(values['opportunity_met']!) ?? 0,
          opportunityConditionTotal:
              int.tryParse(values['opportunity_total']!) ?? 0,
        ),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${result.state.label}预警'),
          content: Text('${result.reason}\n\n默认行为：${result.defaultAction}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) xiangjiShowMessage(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XiangjiPalette.mist,
      appBar: AppBar(
        title: const Text('设置 · AI · 数据治理'),
        backgroundColor: XiangjiPalette.mist,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                XiangjiSectionCard(
                  title: '呈现与监督',
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _plainLanguage,
                        onChanged: (value) async {
                          await _set(_plainLanguageKey, value);
                          if (mounted) setState(() => _plainLanguage = value);
                        },
                        title: const Text('使用日常语言'),
                        subtitle: const Text('首页将“指挥部/战役/出征”等标签替换为普通表达；数据状态名不变。'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _monitorEnabled,
                        onChanged: (value) async {
                          await _set(_monitorKey, value);
                          await XiangjiStrategistMonitorService.syncSchedule();
                          if (mounted) setState(() => _monitorEnabled = value);
                        },
                        title: const Text('开启主动监督'),
                        subtitle: const Text('按五色状态提示偏离、机会、战线过多和不可逆风险。'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _methodTrainingEnabled,
                        onChanged: (value) async {
                          await _set(_methodTrainingKey, value);
                          if (mounted) {
                            setState(() => _methodTrainingEnabled = value);
                          }
                        },
                        title: const Text('开启可选的方法训练'),
                        subtitle: const Text('在“为什么”中加入与当前真实问题相关的一步练习；不会弹出课程墙，也不会阻塞行动。'),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.monitor_heart_outlined),
                        title: const Text('立即运行一次五色监督'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _runMonitor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                XiangjiSectionCard(
                  title: 'AI 与敏感数据',
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _sensitiveCloudAuthorized,
                        onChanged: (value) async {
                          await _set(_cloudSensitiveKey, value);
                          if (mounted) {
                            setState(() => _sensitiveCloudAuthorized = value);
                          }
                        },
                        title: const Text('允许把敏感上下文发送给已配置 AI'),
                        subtitle: const Text('默认关闭。关闭时知识路由只使用离线 K0 与本地材料。'),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.settings_suggest_outlined),
                        title: const Text('打开全局 AI 服务设置'),
                        subtitle: const Text('API Key 仍由全局设置管理，不写入向己数据库或导出文件。'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsPage()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                XiangjiSectionCard(
                  title: '数据治理',
                  subtitle: '只操作 xf_ 前缀的向己模块数据。Todo、日记和其他模块不受影响。',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _working ? null : _exportFromUi,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('导出完整 JSON 快照'),
                      ),
                      if (_lastExportPath.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SelectableText(
                          _lastExportPath,
                          style: const TextStyle(
                            color: XiangjiPalette.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const Divider(height: 28),
                      OutlinedButton.icon(
                        onPressed: _working ? null : _reset,
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: const Text('导出后删除本模块用户数据'),
                      ),
                      if (_working) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
    );
  }
}

class XiangjiDisplayPreferences {
  const XiangjiDisplayPreferences._();

  static Future<bool> plainLanguage() async =>
      await KeyValueDao().getString('xiangji_plain_language_v1') == '1';
}
