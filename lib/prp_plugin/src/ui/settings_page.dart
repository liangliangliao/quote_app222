import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core.dart';
import '../models.dart';
import 'playbook.dart';
import 'seal_stamp.dart';

const Map<PrpSurface, String> _surfaceNotes = <PrpSurface, String>{
  PrpSurface.enemy: '字据失效后，在对话里带你走一遍',
  PrpSurface.behavior: '标记未完成时；提醒处显示上次教训',
  PrpSurface.failureModule: '“我刚失败了”等入口改用统一会话',
  PrpSurface.kindling: '只读“有效”的做法作为候选',
  PrpSurface.quoteHome: '把盖印的教训作为“自己的名言”',
};

/// 设置 → 功能模块 → PRP 插件 · 失败成长。
/// [core] 为 null 表示插件尚未接入（main.dart 没有注册）。
class PrpSettingsPage extends StatefulWidget {
  const PrpSettingsPage({super.key, required this.core});

  final PrpCore? core;

  @override
  State<PrpSettingsPage> createState() => _PrpSettingsPageState();
}

class _PrpSettingsPageState extends State<PrpSettingsPage> {
  PrpConfig? _cfg;
  PrpDiagnostics _diag = PrpDiagnostics.empty;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final PrpCore? core = widget.core;
    if (core == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final PrpConfig cfg = await core.config();
    final PrpDiagnostics diag = await core.diagnostics();
    if (!mounted) return;
    setState(() {
      _cfg = cfg;
      _diag = diag;
      _loading = false;
    });
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _showIntro() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('开启 PRP 插件'),
        content: const SingleChildScrollView(
          child: Text(
            '它做什么：没做到的时候，带你缓一缓、对一次账、留下一条真的教训，并在下一次类似的事出现时提醒你。\n\n'
            '它不做什么：不评价你这个人；不自动发送任何内容；不新增后台任务和通知。\n\n'
            '随时可以关：关闭后所有相关提示和界面都会消失，已保存的教训保留。\n\n'
            '它不是心理治疗工具。如果你现在很难受，请先找身边信得过的人聊聊。',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('先不开'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('开启'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _toggleEnabled(bool v) async {
    final PrpCore core = widget.core!;
    if (v && !await core.settings.introSeen()) {
      final bool ok = await _showIntro();
      if (!ok) return;
      await core.settings.setIntroSeen(true);
    }
    await core.settings.setEnabled(v);
    await _reload();
  }

  Future<void> _export() async {
    final String json = await widget.core!.exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) _snack('已复制到剪贴板');
  }

  Future<void> _clear() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('清除全部教训数据？'),
        content: const Text('此操作不可恢复。你可以先导出。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.core!.clearAll();
    await _reload();
    if (mounted) _snack('已清除');
  }

  void _openPlaybook() {
    final PrpCore core = widget.core!;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => Scaffold(
          appBar: AppBar(title: const Text('我的教训手册')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: PrpPlaybook(core: core, viewAlways: true),
          ),
        ),
      ),
    );
  }

  Widget _header(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
    child: Text(
      t,
      style: const TextStyle(color: kPrpSeal, fontWeight: FontWeight.w700),
    ),
  );

  Widget _choices<T>({
    required String title,
    required List<T> options,
    required T current,
    required String Function(T) label,
    required Future<void> Function(T) onPick,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: options
                .map(
                  (T o) => ChoiceChip(
                    label: Text(label(o)),
                    selected: o == current,
                    onSelected: (_) async {
                      await onPick(o);
                      await _reload();
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PrpCore? core = widget.core;
    final PrpConfig? cfg = _cfg;
    return Scaffold(
      appBar: AppBar(title: const Text('PRP 插件 · 失败成长')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (core == null || cfg == null)
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('插件尚未接入。需要在启动时注册（installPrpPlugin）。'),
            )
          : ListView(
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text('没做到的时候，先缓一缓，再对一次账，留下一条真的教训。'),
                ),
                Card(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: SwitchListTile(
                    title: const Text(
                      '① 启用插件',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('关闭后，相关提示和界面都会消失，已保存的教训保留'),
                    value: cfg.enabled,
                    onChanged: _toggleEnabled,
                  ),
                ),
                _header('② 在这些功能里使用'),
                for (final PrpSurface s in PrpSurface.values)
                  SwitchListTile(
                    title: Text(s.label),
                    subtitle: Text(
                      s.wiredInThisVersion
                          ? (_surfaceNotes[s] ?? '')
                          : '本版本尚未接入',
                    ),
                    value: s.wiredInThisVersion && (cfg.surfaces[s] ?? false),
                    onChanged: s.wiredInThisVersion
                        ? (bool v) async {
                            await core.settings.setSurface(s, v);
                            await _reload();
                          }
                        : null,
                  ),
                _header('③ 体验'),
                _choices<int>(
                  title: '缓一缓时长',
                  options: const <int>[30, 60, 90, 120],
                  current: cfg.pauseSec,
                  label: (int v) => '$v 秒',
                  onPick: core.settings.setPauseSec,
                ),
                _choices<int>(
                  title: '每天最多主动提议',
                  options: const <int>[0, 1, 2],
                  current: cfg.offerCap,
                  label: (int v) => v == 0 ? '不主动提议' : '$v 次',
                  onPick: core.settings.setOfferCap,
                ),
                _choices<int>(
                  title: '每天最多回访',
                  options: const <int>[0, 1, 2],
                  current: cfg.recallCap,
                  label: (int v) => v == 0 ? '不回访' : '$v 次',
                  onPick: core.settings.setRecallCap,
                ),
                _header('④ AI'),
                const SwitchListTile(
                  title: Text('允许把复盘文字发给 AI'),
                  subtitle: Text('本版本使用离线模板，AI 起草暂未接入'),
                  value: false,
                  onChanged: null,
                ),
                _header('⑤ ⑥ 我的数据'),
                ListTile(
                  title: const Text('⑤ 我的教训手册'),
                  subtitle: Text(
                    '已盖印 ${_diag.sealedLessons} 条 · 待盖印 ${_diag.draftLessons} 条',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openPlaybook,
                ),
                ListTile(
                  title: const Text('⑥ 导出教训数据'),
                  subtitle: const Text('复制为 JSON 到剪贴板'),
                  onTap: _export,
                ),
                ListTile(
                  title: const Text(
                    '清除全部教训数据',
                    style: TextStyle(color: kPrpSeal),
                  ),
                  onTap: _clear,
                ),
                ExpansionTile(
                  title: const Text('诊断（开发者）'),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_diagText()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  String _diagText() {
    final PrpDiagnostics d = _diag;
    final List<String> lines = <String>[
      '已接入：${d.installed ? '是' : '否'}　启用：${d.enabled ? '是' : '否'}　熔断：${d.tripped ? '是（重启后恢复）' : '否'}',
      '会话 ${d.sessions} · 已盖印 ${d.sealedLessons} · 草稿 ${d.draftLessons} · 回访 ${d.recalls} · 异常 ${d.failures}',
      if (d.log.isEmpty) '（暂无日志）' else ...d.log,
    ];
    return lines.join('\n');
  }
}
