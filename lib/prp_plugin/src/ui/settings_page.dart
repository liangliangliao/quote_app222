import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../prp_plugin.dart';
import '../build_info.dart';
import '../runtime.dart';
import 'presentation.dart';
import 'feature_pages.dart';
import 'experiments.dart';

class PrpSettingsPage extends StatefulWidget {
  const PrpSettingsPage({super.key, required this.runtime});
  final PrpRuntime runtime;
  @override
  State<PrpSettingsPage> createState() => _PrpSettingsPageState();
}

class _PrpSettingsPageState extends State<PrpSettingsPage> {
  bool _loading = true;
  bool _saving = false;
  bool _opening = false;
  int _eligibilityGeneration = 0;
  int? _sealedCount;
  int _quotedCount = 0;
  bool _eligibilityFailed = false;
  PrpRuntime get r => widget.runtime;
  @override
  void initState() {
    super.initState();
    r.initialize().then((_) {
      if (mounted) {
        setState(() => _loading = false);
        _refreshEligibility();
      }
    });
    PrpPlugin.changes.addListener(_changed);
  }

  void _changed() {
    if (mounted) {
      setState(() {});
      _refreshEligibility();
    }
  }

  Future<void> _refreshEligibility() async {
    final generation = ++_eligibilityGeneration;
    if (!r.preferences.enabled) return;
    try {
      final lessons = await r.store.lessons(sealedOnly: true);
      if (!mounted || generation != _eligibilityGeneration) return;
      setState(() {
        _sealedCount = lessons.length;
        _quotedCount = lessons.where((lesson) => lesson.quoteAllowed).length;
        _eligibilityFailed = false;
      });
    } catch (_) {
      if (mounted && generation == _eligibilityGeneration) {
        setState(() => _eligibilityFailed = true);
      }
    }
  }

  @override
  void dispose() {
    PrpPlugin.changes.removeListener(_changed);
    super.dispose();
  }

  Future<void> _save(PrpPreferences next) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await r.updatePreferences(next);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('设置未能保存，插件已保持关闭。请重试。')));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _enable(bool enabled) async {
    var next = r.preferences.copyWith(enabled: enabled);
    if (enabled && !r.preferences.onboarded) {
      final selected = Map<PrpSurface, bool>.from(next.surfaces);
      bool ai = false;
      final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
              builder: (ctx, update) => AlertDialog(
                    title: const Text('先了解一下 PRP'),
                    content: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text(
                              '从一件真实经历开始，可以只记录，也可以选择一个行动计划。新计划需你另行同意才在下次同类行动处回访；已有完整练习仍需亲手盖印。\n\n所有反思字段可跳过，PRP 三步骤可往返。随时可关闭，关闭后记录仍保留。它不是心理治疗工具，也不承诺疗效。'),
                          const SizedBox(height: 12),
                          for (final s in PrpSurface.values)
                            CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(s.label),
                                value: selected[s],
                                onChanged: (v) =>
                                    update(() => selected[s] = v == true)),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('允许把复盘文字发给 AI'),
                              subtitle:
                                  const Text('默认关闭。使用 App 已有的 AI 配置；离线引导同样可用。'),
                              value: ai,
                              onChanged: (v) => update(() => ai = v)),
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('先不开启')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('按这些选择开启'))
                    ],
                  )));
      if (go != true) return;
      next = next.copyWith(onboarded: true, surfaces: selected, aiConsent: ai);
    }
    await _save(next);
  }

  Future<void> _number(String title, int current, List<int> choices,
      void Function(int) save, String unit) async {
    final value = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(
            title: Text(title),
            children: choices
                .map((n) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, n),
                    child: Text('$n $unit${n == current ? ' · 当前' : ''}')))
                .toList()));
    if (value != null) save(value);
  }

  Future<void> _beginReflection() async {
    if (_saving || _opening || !r.enabledFor(PrpSurface.failureModule)) return;
    setState(() => _opening = true);
    try {
      final now = r.nowMs;
      final offer = await r.signal(PrpSignal(
          surface: PrpSurface.failureModule,
          kind: 'manual',
          subjectKey: 'free',
          expected: '',
          tsMs: now,
          reference: 'settings:manual:$now'));
      if (!mounted) return;
      if (offer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前未能开始。请在诊断中查看静默、静音或安全退场状态。')));
        return;
      }
      await r.showOffer(context, offer, fullScreen: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('暂时无法打开复盘，请稍后重试。')));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _openExtra(String feature) async {
    final p = r.preferences;
    if (!r.enabled) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先开启插件。')));
      return;
    }
    final selected = switch (feature) {
      'forecast' => p.forecasts,
      'particles' => p.particles,
      _ => p.draftQuotes
    };
    if (!selected) {
      final yes = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: Text(switch (feature) {
                    'forecast' => '开启痛感对照？',
                    'particles' => '开启光迹实验？',
                    _ => '开启废稿短句？'
                  }),
                  content: const Text('只在本机使用，不会自动开启 AI 或发送通知。可随时在设置关闭。'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('先不开启')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('开启并进入'))
                  ]));
      if (yes != true || !mounted) return;
      await _save(r.preferences.copyWith(
          forecasts: feature == 'forecast' ? true : null,
          particles: feature == 'particles' ? true : null,
          draftQuotes: feature == 'quotes' ? true : null));
    }
    if (!mounted || !r.enabled) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => switch (feature) {
              'forecast' => PrpForecastPage(runtime: r),
              'particles' => PrpParticlesPage(runtime: r),
              _ => PrpDraftQuotesPage(runtime: r)
            }));
  }

  Future<void> _export() async {
    try {
      final json = await r.exportData();
      final path = await r.host.exportJson(json);
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已导出：$path')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('导出失败，可使用“复制数据”重试。')));
    }
  }

  Future<void> _clear() async {
    final first = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('清除 PRP 手册数据？'),
              content: const Text('将清除完整 PRP 练习的教训、会话、回访及本地录音。此操作不可恢复，你可以先导出。简短复盘与行动反馈保存在“失败与完美主义 → 学习卡”，可在那里逐条导出或删除。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('继续清除'))
              ],
            ));
    if (first != true || !mounted) return;
    final second = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('最后确认'),
              content: const Text('确定永久清除 PRP 数据？其它模块的历史记录和插件开关会保留。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('保留数据')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('永久清除'))
              ],
            ));
    if (second != true) return;
    try {
      await r.clearData();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('PRP 数据已清除。')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('未能完整清除，请重试。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: prpPaperTheme(context), child: Builder(builder: _content));
  }

  Widget _content(BuildContext context) {
    final p = r.preferences;
    return Scaffold(
        backgroundColor: const Color(0xfff7f8fb),
        appBar: AppBar(title: const Text('PRP 插件 · 失败成长')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(children: [
                const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('没做到的时候，先缓一缓，再对一次账，留下一条真的教训。',
                        style: TextStyle(fontSize: 18, height: 1.6))),
                SwitchListTile(
                    key: const ValueKey('prp_master_switch'),
                    title: const Text('启用插件'),
                    subtitle: const Text('关闭后，相关提示和界面都会消失，已保存的教训保留。'),
                    value: p.enabled,
                    onChanged: _saving ? null : _enable),
                Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      ActionChip(
                          key: const ValueKey('prp_quick_forecast'),
                          label: const Text('痛感对照'),
                          onPressed:
                              _saving ? null : () => _openExtra('forecast')),
                      ActionChip(
                          key: const ValueKey('prp_quick_particles'),
                          label: const Text('光迹实验'),
                          onPressed:
                              _saving ? null : () => _openExtra('particles')),
                      ActionChip(
                          key: const ValueKey('prp_quick_quotes'),
                          label: const Text('废稿短句'),
                          onPressed:
                              _saving ? null : () => _openExtra('quotes')),
                      ActionChip(
                          label: const Text('本地观察'),
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      PrpObservationPage(runtime: r)))),
                    ])),
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: FilledButton.icon(
                        key: const ValueKey('prp_begin_reflection'),
                        icon: const Icon(Icons.edit_note),
                        label: Text(_opening ? '复盘进行中' : '开始一次复盘'),
                        onPressed: _saving ||
                                _opening ||
                                !r.enabledFor(PrpSurface.failureModule)
                            ? null
                            : _beginReflection)),
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text(!p.enabled
                        ? '先开启插件，就能从这里开始。AI 不会自动开启。'
                        : p.surfaces[PrpSurface.failureModule] != true
                            ? '开启下方“失败与完美主义”，即可从这里开始。'
                            : '从一件真实的经历开始；这是手动复盘，不占自动提议额度。')),
                const ExpansionTile(
                    title: Text('功能会出现在哪里？'),
                    childrenPadding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('美丽的敌人：字据确认没做到后，显示会话卡片。\n'
                          '行为追踪：标记未完成时打开会话，每日确认处回访。\n'
                          '失败与完美主义：3P 急救与失败复盘入口。'),
                      SizedBox(height: 10),
                      Text('火种：开启调用点后，在“回溯”的候选步骤复用已盖印的有效做法。'),
                      SizedBox(height: 10),
                      Text('名言首页：开启首页调用点和“自己的名言混入首页”，并逐条同意教训后，'
                          '点击“换一条”按每日限额展示。普通首页和火种清单不会自动改变。'),
                    ]),
                if (p.enabled)
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Text(
                          _eligibilityFailed
                              ? '教训状态暂时无法读取，请稍后重试。'
                              : _sealedCount == null
                                  ? '正在读取教训状态…'
                                  : '已盖印 $_sealedCount 条 · 已同意作为自己的名言 $_quotedCount 条\n'
                                      '火种：${p.surfaces[PrpSurface.kindling] != true ? '调用点未开启' : _sealedCount == 0 ? '尚无盖印教训，先完成一次复盘' : '可在回溯的候选步骤选择有效做法'}\n'
                                      '首页：${p.surfaces[PrpSurface.quoteHome] != true ? '首页调用点未开启' : !p.quoteStream ? '自己的名言流未开启' : !p.recalls ? '回访开关未开启' : _quotedCount == 0 ? '尚无逐条同意的盖印教训' : '候选已准备好；点击换一条，仍受静默与每日限额约束'}',
                          key: const ValueKey('prp_surface_readiness'))),
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: SelectableText(PrpBuildInfo.label,
                        key: const ValueKey('prp_build_identity'),
                        style: const TextStyle(fontSize: 12))),
                if (r.circuitOpen || r.crisisUntilMs > r.nowMs)
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('插件当前静默中，可在诊断页查看状态。')),
                _heading('在这些功能里使用'),
                for (final s in PrpSurface.values)
                  SwitchListTile(
                      title: Text(s.label),
                      subtitle: Text(switch (s) {
                        PrpSurface.enemy => '字据明确没做到后，进入同一会话',
                        PrpSurface.behavior => '标记未完成时；每日确认处回访',
                        PrpSurface.failureModule => '3P 急救与失败复盘使用统一会话',
                        PrpSurface.kindling => '只读有效做法，不触发失败提示',
                        PrpSurface.quoteHome => '经逐条同意后，作为自己的名言',
                      }),
                      value: p.surfaces[s] == true,
                      onChanged: _saving
                          ? null
                          : (v) => _save(
                              p.copyWith(surfaces: {...p.surfaces, s: v}))),
                _heading('体验'),
                ListTile(
                    title: const Text('缓一缓时长'),
                    trailing: Text('${p.pauseSeconds} 秒'),
                    onTap: _saving
                        ? null
                        : () => _number(
                            '缓一缓时长',
                            p.pauseSeconds,
                            [30, 60, 90, 120, 180],
                            (n) => _save(p.copyWith(pauseSeconds: n)),
                            '秒')),
                ListTile(
                    title: const Text('每日提议上限'),
                    trailing: Text('${p.offerCap} 次'),
                    onTap: _saving
                        ? null
                        : () => _number('每日提议上限', p.offerCap, [0, 1, 2, 3],
                            (n) => _save(p.copyWith(offerCap: n)), '次')),
                ListTile(
                    title: const Text('每日回访上限'),
                    trailing: Text('${p.recallCap} 次'),
                    onTap: _saving
                        ? null
                        : () => _number('每日回访上限', p.recallCap, [0, 1, 2, 3],
                            (n) => _save(p.copyWith(recallCap: n)), '次')),
                SwitchListTile(
                    title: const Text('缓一缓与盖印体验'),
                    subtitle: const Text('关闭后仍需确认教训；跳过的草稿不会回访。'),
                    value: p.sessions,
                    onChanged:
                        _saving ? null : (v) => _save(p.copyWith(sessions: v))),
                SwitchListTile(
                    title: const Text('在下一次回访教训'),
                    value: p.recalls,
                    onChanged:
                        _saving ? null : (v) => _save(p.copyWith(recalls: v))),
                SwitchListTile(
                    title: const Text('自己的名言混入首页'),
                    subtitle: const Text('还需开启首页调用点，并逐条同意。每天最多一次，至少相隔 24 小时。'),
                    value: p.quoteStream,
                    onChanged: _saving
                        ? null
                        : (v) => _save(p.copyWith(quoteStream: v))),
                SwitchListTile(
                    title: const Text('书法与涂改手稿'),
                    value: p.manuscript,
                    onChanged: _saving
                        ? null
                        : (v) => _save(p.copyWith(manuscript: v))),
                SwitchListTile(
                    title: const Text('自己的声音'),
                    subtitle: const Text('每段最多 15 秒，仅保存在本机；原生闹钟播放需另外开启。'),
                    value: p.voice,
                    onChanged:
                        _saving ? null : (v) => _save(p.copyWith(voice: v))),
                _heading('对照与提醒'),
                SwitchListTile(
                    title: const Text('痛感对照'),
                    subtitle: const Text('先记预测，再补实际；只作本地自我观察。'),
                    value: p.forecasts,
                    onChanged: _saving
                        ? null
                        : (v) => _save(p.copyWith(forecasts: v))),
                ListTile(
                    key: const ValueKey('prp_forecast_entry'),
                    title: const Text('预测与实际记录'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => PrpForecastPage(runtime: r)))),
                SwitchListTile(
                    title: const Text('原生闹钟显示教训'),
                    subtitle: const Text('行为预设闹钟中显示一条匹配的盖印教训，沿用每日回访限额。'),
                    value: p.nativeReminders,
                    onChanged: _saving
                        ? null
                        : (v) => _save(p.copyWith(nativeReminders: v))),
                SwitchListTile(
                    title: const Text('原生闹钟播放自己的提示'),
                    subtitle: Text(!p.nativeReminders
                        ? '先开启“原生闹钟显示教训”。'
                        : p.voice
                            ? '到点时播放已保存的本地录音，最多 15 秒；可在表单手动重播。'
                            : '先开启“自己的声音”并保存一段录音。'),
                    value: p.nativeVoice,
                    onChanged: _saving || !p.voice || !p.nativeReminders
                        ? null
                        : (v) => _save(p.copyWith(nativeVoice: v))),
                _heading('小实验与练习句'),
                SwitchListTile(
                    title: const Text('潮汐光迹'),
                    subtitle: const Text('按住时散开，松手后回落；不计分，不记失败。'),
                    value: p.particles,
                    onChanged: _saving
                        ? null
                        : (v) => _save(p.copyWith(particles: v))),
                ListTile(
                    key: const ValueKey('prp_particles_entry'),
                    title: const Text('打开光迹实验'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: r.enabled && p.particles
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => PrpParticlesPage(runtime: r)))
                        : null),
                SwitchListTile(
                    title: const Text('废稿短句内容包'),
                    subtitle: const Text('本地创作的练习句，非名人引言，不自动进入名言库或教训。'),
                    value: p.draftQuotes,
                    onChanged: _saving
                        ? null
                        : (v) => _save(p.copyWith(draftQuotes: v))),
                ListTile(
                    key: const ValueKey('prp_draft_quotes_entry'),
                    title: const Text('浏览废稿短句'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: r.enabled && p.draftQuotes
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => PrpDraftQuotesPage(runtime: r)))
                        : null),
                _heading('AI'),
                SwitchListTile(
                    title: const Text('允许把复盘文字发给 AI'),
                    subtitle: const Text(
                        '只用于事实分类与教训起草，沿用 App 的统一 AI 配置。默认关闭，关闭时使用离线引导。'),
                    value: p.aiConsent,
                    onChanged: _saving
                        ? null
                        : (v) => _save(p.copyWith(aiConsent: v))),
                _heading('我的数据'),
                ListTile(
                    key: const ValueKey('prp_observation_entry'),
                    leading: const Icon(Icons.insights_outlined),
                    title: const Text('我的本地观察'),
                    subtitle: const Text('会话、盖印、采纳、验证与情绪配对评分；不上传'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => PrpObservationPage(runtime: r)))),
                ListTile(
                    leading: const Icon(Icons.auto_stories_outlined),
                    title: const Text('我的教训手册'),
                    subtitle: const Text('插件关闭时仍可查看'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                                appBar: AppBar(title: const Text('我的教训手册')),
                                body: SingleChildScrollView(
                                    child: r.playbook(management: true)))))),
                ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: const Text('导出教训数据（JSON）'),
                    subtitle: const Text('完整 PRP 练习；简短复盘可在学习卡内导出'),
                    onTap: _export),
                ListTile(
                    leading: const Icon(Icons.copy_outlined),
                    title: const Text('复制数据'),
                    onTap: () async {
                      try {
                        final json = await r.exportData();
                        await Clipboard.setData(ClipboardData(text: json));
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('教训数据已复制。')));
                      } catch (_) {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('数据暂时无法复制，请稍后重试。')));
                      }
                    }),
                ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('清除 PRP 数据'),
                    subtitle: const Text('管理完整 PRP 手册与录音；学习卡在失败模块中管理'),
                    onTap: _clear),
                ListTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: const Text('诊断（开发者）'),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => PrpDiagnosticsPage(runtime: r)))),
                const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                        '本插件不替代心理治疗，也不承诺疗效。观察指标只存本地。原生教训和录音需单独开启；收到提醒或退出火种都不算失败。',
                        style: TextStyle(fontSize: 12, color: Colors.grey))),
              ]));
  }

  Widget _heading(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xff6860bd))));
}

class PrpDiagnosticsPage extends StatelessWidget {
  const PrpDiagnosticsPage({super.key, required this.runtime});
  final PrpRuntime runtime;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('PRP 诊断')),
      body: ValueListenableBuilder<int>(
          valueListenable: PrpPlugin.changes,
          builder: (_, __, ___) =>
              ListView(padding: const EdgeInsets.all(20), children: [
                const Text('已注册 · 契约 v1'),
                Text('总开关：${runtime.preferences.enabled ? '开' : '关'}'),
                Text(
                    '当前状态：${runtime.circuitOpen ? '已熔断，本次启动静默' : runtime.crisisUntilMs > runtime.nowMs ? '安全退场，暂停 24 小时' : runtime.enabled ? '运行中' : '关闭'}'),
                Text('连续内部异常：${runtime.consecutiveErrors} / 3'),
                Text(
                    '最近信号：${runtime.diagnostics.where((e) => e['event'] == 'signal').length} 个'),
                const Text('无后台任务 · 无独立通知通道 · 日志不含复盘正文'),
                const Divider(),
                for (final row in runtime.diagnostics.reversed)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${row['event']} · ${row['detail']}'),
                      subtitle: Text(
                          DateTime.fromMillisecondsSinceEpoch(row['ts'] as int)
                              .toString())),
              ])));
}
