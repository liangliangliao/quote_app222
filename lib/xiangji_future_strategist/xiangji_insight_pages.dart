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
import 'xiangji_state_machine.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object?>(<Future<Object?>>[
        widget.dao.allExperiences(),
        widget.dao.allClaims(),
        widget.dao.debts(openOnly: false),
        widget.dao.conceptVersions(),
      ]);
      if (!mounted) return;
      setState(() {
        _experiences = values[0] as List<Map<String, Object?>>;
        _claims = values[1] as List<Map<String, Object?>>;
        _debts = values[2] as List<Map<String, Object?>>;
        _concepts = values[3] as List<Map<String, Object?>>;
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
              Tab(text: '直接经验'),
              Tab(text: '候选判断'),
              Tab(text: '认识债务'),
              Tab(text: '概念版本'),
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
                  _rows(
                    _experiences,
                    emptyTitle: '暂无直接经验',
                    emptyMessage: '问题捕捉和事实分层后，用户原话与可观察经验会出现在这里。',
                    title: (row) => (row['content'] ?? '').toString(),
                    subtitle: (row) =>
                        '${row['experience_type']} · ${row['is_user_wording'] == 1 ? '用户原话' : '派生材料'}',
                    icon: Icons.visibility_outlined,
                  ),
                  _rows(
                    _claims,
                    emptyTitle: '暂无候选判断',
                    emptyMessage: '解释、预测和 AI 判断必须显示认识状态，不能伪装成事实。',
                    title: (row) => (row['text'] ?? '').toString(),
                    subtitle: (row) =>
                        '${row['claim_type']} · 确定性 ${row['epistemic_status']} · 系统性 ${row['systematicity']}',
                    icon: Icons.psychology_alt_outlined,
                  ),
                  _rows(
                    _debts,
                    emptyTitle: '暂无认识债务',
                    emptyMessage: '会改变决定但暂时无法清偿的未知项，会被显式登记。',
                    title: (row) => (row['description'] ?? '').toString(),
                    subtitle: (row) =>
                        '影响 ${row['decision_impact']} · ${row['status']} · ${row['grounding_gap']}',
                    icon: Icons.report_problem_outlined,
                  ),
                  _rows(
                    _concepts,
                    emptyTitle: '暂无概念版本',
                    emptyMessage: '概念的定义、适用范围与版本变化会保留历史，不静默覆盖。',
                    title: (row) => (row['name'] ?? row['concept_id'] ?? '').toString(),
                    subtitle: (row) =>
                        'v${row['version_no']} · ${row['definition']} · 范围 ${row['scope']} · 变更原因 ${row['change_reason']}',
                    icon: Icons.schema_outlined,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _rows(
    List<Map<String, Object?>> rows, {
    required String emptyTitle,
    required String emptyMessage,
    required String Function(Map<String, Object?> row) title,
    required String Function(Map<String, Object?> row) subtitle,
    required IconData icon,
  }) {
    if (rows.isEmpty) {
      return XiangjiEmptyState(
        title: emptyTitle,
        message: emptyMessage,
        icon: icon,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = rows[index];
        return ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(icon, color: XiangjiPalette.pine),
          title: Text(title(row)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(subtitle(row)),
          ),
        );
      },
    );
  }
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
  List<Map<String, Object?>> _runs = const <Map<String, Object?>>[];

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
        widget.dao.modelRuns(),
      ]);
      if (!mounted) return;
      setState(() {
        _reviews = values[0] as List<Map<String, Object?>>;
        _rules = values[1] as List<Map<String, Object?>>;
        _aiErrors = values[2] as List<Map<String, Object?>>;
        _runs = values[3] as List<Map<String, Object?>>;
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
              Tab(text: 'AI 失误'),
              Tab(text: '模型运行'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _jsonRows(
                    _reviews,
                    titleKey: 'id',
                    empty: '战役关闭时必须先形成复盘，之后会出现在这里。',
                  ),
                  _jsonRows(
                    _rules,
                    titleKey: 'rule_text',
                    empty: '多事件支持、反例检查和明确确认后，个人规律才会稳定化。',
                  ),
                  _jsonRows(
                    _aiErrors,
                    titleKey: 'impact',
                    empty: '被现实结果反驳的 AI 判断会留下可追溯失误记录。',
                  ),
                  _jsonRows(
                    _runs,
                    titleKey: 'agent_id',
                    empty: '军师尚未运行。',
                  ),
                ],
              ),
      ),
    );
  }

  Widget _jsonRows(
    List<Map<String, Object?>> rows, {
    required String titleKey,
    required String empty,
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
            (row[titleKey] ?? '记录 ${index + 1}').toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(row),
              ),
            ),
          ],
        );
      },
    );
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
  static const String _cloudSensitiveKey =
      'xiangji_sensitive_cloud_authorized_v1';

  final KeyValueDao _kv = KeyValueDao();
  bool _plainLanguage = false;
  bool _monitorEnabled = true;
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
    ]);
    if (!mounted) return;
    setState(() {
      _plainLanguage = values[0] == '1';
      _monitorEnabled = values[1] != '0';
      _sensitiveCloudAuthorized = values[2] == '1';
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
    final file = File(p.join(directory.path, 'xiangji_v6_1_rev2_$stamp.json'));
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
        XiangjiFormFieldSpec(keyName: 'risk', label: '是否高风险不可逆（yes/no）', initialValue: 'no', required: true),
        XiangjiFormFieldSpec(keyName: 'debt', label: '是否有高认识债务（yes/no）', initialValue: 'no', required: true),
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
                          if (mounted) setState(() => _monitorEnabled = value);
                        },
                        title: const Text('开启主动监督'),
                        subtitle: const Text('按五色状态提示偏离、机会、战线过多和不可逆风险。'),
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
                        title: const Text('打开全局 AI Provider 设置'),
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
