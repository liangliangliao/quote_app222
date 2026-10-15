import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../application/controller.dart';
import '../domain/model.dart';
import '../integration/runtime.dart';
import '../integration/reminders.dart';
import 'design.dart';
import 'me_page.dart';
import 'settings_page.dart';
import 'sheets.dart';
import 'tide.dart';
import 'workbench.dart';

class WillMirrorDiscoverEntry extends StatelessWidget {
  const WillMirrorDiscoverEntry({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: const Color(0xffeaf1eb),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: mirrorInk,
                        borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.waves, color: Color(0xffe0e5c6))),
                const SizedBox(width: 14),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('意志之镜',
                          style: TextStyle(
                              color: mirrorInk,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('从一件现实课题，逐渐认识自己',
                          style:
                              TextStyle(color: Color(0xff58716c), fontSize: 12))
                    ])),
                const Icon(Icons.chevron_right, color: mirrorTeal)
              ]))));
}

class WillMirrorModulePage extends StatefulWidget {
  const WillMirrorModulePage({super.key, this.controller, this.initialLink});
  final MirrorController? controller;
  final MirrorLink? initialLink;
  @override
  State<WillMirrorModulePage> createState() => _WillMirrorModulePageState();
}

class _WillMirrorModulePageState extends State<WillMirrorModulePage> {
  MirrorController? _controller;
  String? _error;
  String? _errorCode;
  final _navigator = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _errorCode = null;
    });
    try {
      final controller = widget.controller ?? await MirrorRuntime.acquire();
      if (!controller.initialized) await controller.initialize();
      if (!mounted) {
        if (widget.controller == null) {
          await MirrorRuntime.release(controller);
        }
        return;
      }
      setState(() => _controller = controller);
      final link = widget.initialLink;
      if (link != null) {
        final valid = await controller.openNotification(link);
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final current = controller.file(link.caseId);
          if (current != null)
            _navigator.currentState?.push(
              MaterialPageRoute<void>(
                builder: (_) => CaseWorkbench(
                  controller: controller,
                  caseId: current.id,
                  initialStep: valid ? link.step : null,
                  notificationStale: !valid,
                  focusNodeId: valid ? link.principleId : null,
                ),
              ),
            );
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is MirrorProblem
              ? error.message
              : '模块暂时无法打开，请重试。原资料已保留，请勿清除应用数据。';
          const safeCodes = {
            'database_open_failed',
            'database_service_unavailable',
            'storage_version_unsupported',
            'vault_key_missing',
            'vault_authentication_failed',
            'vault_invalid_payload',
            'vault_unavailable',
          };
          _errorCode = error is MirrorProblem && safeCodes.contains(error.code)
              ? error.code
              : 'module_startup_failed';
        });
      }
    }
  }

  @override
  void dispose() {
    final c = _controller;
    if (widget.controller == null && c != null) {
      MirrorRuntime.release(c);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null)
      return Scaffold(
        appBar: AppBar(title: const Text('意志之镜')),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: MirrorEmpty(
                      title: '资料暂时无法打开',
                      body: _error!,
                      action: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text('重试'),
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            '问题代码：$_errorCode',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      );
    return AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Theme(
            data: mirrorTheme(switch (controller.preferences.darkMode) {
              'dark' => Brightness.dark,
              'light' => Brightness.light,
              _ => MediaQuery.platformBrightnessOf(context)
            }),
            child: NavigatorPopHandler(
                onPopWithResult: (_) => _navigator.currentState?.maybePop(),
                child: Navigator(
                    key: _navigator,
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (_) => _MirrorShell(
                            controller: controller,
                            onExit: () => Navigator.of(context).pop()))))));
  }
}

class _MirrorShell extends StatefulWidget {
  const _MirrorShell({required this.controller, required this.onExit});
  final MirrorController controller;
  final VoidCallback onExit;
  @override
  State<_MirrorShell> createState() => _MirrorShellState();
}

class _MirrorShellState extends State<_MirrorShell> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          leading: IconButton(
              tooltip: '返回发现之旅',
              onPressed: widget.onExit,
              icon: const Icon(Icons.arrow_back)),
          title: Text(_tab == 0
              ? '意志之镜'
              : _tab == 1
                  ? '逐渐认识的我'
                  : '设置'),
          actions: [
            if (_tab == 0)
              IconButton(
                  tooltip: '查看全部课题',
                  icon: const Icon(Icons.history),
                  onPressed: () => _allCases(context))
          ]),
      body: IndexedStack(index: _tab, children: [
        _CasesHome(controller: widget.controller),
        MirrorMePage(controller: widget.controller),
        MirrorSettingsPage(controller: widget.controller)
      ]),
      bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.waves_outlined),
                selectedIcon: Icon(Icons.waves),
                label: '课题'),
            NavigationDestination(
                icon: Icon(Icons.account_tree_outlined),
                selectedIcon: Icon(Icons.account_tree),
                label: '逐渐认识的我'),
            NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: '设置'),
          ]));
  Future<void> _allCases(BuildContext context) => mirrorSheet<void>(context,
      title: '我的课题',
      child: Column(children: [
        if (widget.controller.files.isEmpty) const Text('还没有课题。从一件具体的事开始就可以。'),
        for (final file in widget.controller.files)
          CaseTile(
              file: file,
              onTap: () {
                Navigator.pop(context);
                Navigator.of(this.context).push(MaterialPageRoute<void>(
                    builder: (_) => CaseWorkbench(
                        controller: widget.controller, caseId: file.id)));
              }),
      ]));
}

class _CasesHome extends StatefulWidget {
  const _CasesHome({required this.controller});
  final MirrorController controller;
  @override
  State<_CasesHome> createState() => _CasesHomeState();
}

class _CasesHomeState extends State<_CasesHome> {
  final _input = TextEditingController();
  final _speech = SpeechToText();
  bool _past = false, _creating = false, _listening = false;
  @override
  void dispose() {
    _input.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _voice() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final ready = await _speech.initialize(onStatus: (status) {
      if (mounted && status != 'listening') setState(() => _listening = false);
    }, onError: (_) {
      if (mounted) setState(() => _listening = false);
    });
    if (!mounted) return;
    if (!ready) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('语音输入暂不可用，可以继续输入文字')));
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
        listenOptions: SpeechListenOptions(localeId: 'zh_CN'),
        onResult: (result) {
          if (mounted) _input.text = result.recognizedWords;
        });
  }

  Future<void> _create() async {
    if (_creating) return;
    setState(() => _creating = true);
    await runUiAction(context, () async {
      final file =
          await widget.controller.create(_input.text, retrospective: _past);
      _input.clear();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => CaseWorkbench(
              controller: widget.controller,
              caseId: file.id,
              startAnalysis: true)));
    });
    if (mounted) setState(() => _creating = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = Theme.of(context);
    final waiting = c.files
        .where((f) => {CaseStage.waiting, CaseStage.sealed}.contains(f.stage))
        .toList();
    final recent = c.files.take(3).toList();
    return ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        children: [
          if (c.notice != null) ...[
            MirrorCard(child: Text(c.notice!)),
            const SizedBox(height: 12),
          ],
          Text('把眼前的事，\n慢慢看清楚。', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 12),
          Text('从真实处境出发，看见理由与走法，\n再用自己的经历检验。',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          MirrorCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Text('你现在遇到了什么？', style: theme.textTheme.titleLarge),
                const SizedBox(height: 5),
                const Text('或者，哪一个未来时刻令你犹豫？'),
                const SizedBox(height: 16),
                TextField(
                    key: const ValueKey('mirror-case-input'),
                    controller: _input,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 16000,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                        hintText: '写下这件事，以及此刻最让你拿不定主意的地方……', counterText: '')),
                Row(children: [
                  Expanded(
                      child: TextButton.icon(
                          onPressed: _voice,
                          icon: Icon(_listening
                              ? Icons.stop_circle_outlined
                              : Icons.mic_none),
                          label: Text(_listening ? '停止语音' : '用语音描述'))),
                  TextButton(onPressed: _examples, child: const Text('看一个例子'))
                ]),
                SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('这件事已经发生'),
                    subtitle: const Text('可以直接回望，不补造事前预测'),
                    value: _past,
                    onChanged: (v) => setState(() => _past = v)),
                const SizedBox(height: 10),
                FilledButton.icon(
                    key: const ValueKey('mirror-create-case'),
                    onPressed: _creating ? null : _create,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('开始看清这件事')),
                const SizedBox(height: 10),
                Text('默认保存在本机。开始 AI 分析前，你会看到本次使用的资料。',
                    style: theme.textTheme.bodySmall),
              ])),
          const SizedBox(height: 22),
          MotiveTide(
              caption: '还未发生的留作可能，真正经历的才被点亮。',
              animate: c.preferences.animations,
              height: 140),
          if (waiting.isNotEmpty) ...[
            const SizedBox(height: 26),
            Text('还在等待的条件', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final f in waiting.take(2))
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MirrorCard(
                      onTap: () => _open(f),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const MirrorTag('预案已保存 · 现实条件仍需核实',
                                icon: Icons.hourglass_bottom),
                            const SizedBox(height: 10),
                            Text(
                                f.latest(NodeKind.trigger)?.text('signal') ??
                                    f.issue,
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 8),
                            const Text('查看当时的理由与可以现在做的准备 →')
                          ]))),
          ],
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 26),
            Row(children: [
              Expanded(child: Text('继续上一次', style: theme.textTheme.titleLarge)),
              Text('${c.files.length} 个课题', style: theme.textTheme.bodySmall)
            ]),
            const SizedBox(height: 10),
            for (final f in recent) CaseTile(file: f, onTap: () => _open(f))
          ],
        ]);
  }

  void _open(CaseFile f) => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          CaseWorkbench(controller: widget.controller, caseId: f.id)));
  Future<void> _examples() async {
    final value = await chooseOption(context,
        title: '借一个开头，写你自己的情况',
        explanation: '这些是虚构的输入例子，选择后可以修改。分析不会预设答案。',
        options: const {
          '我明天可能要参加一次面试，但岗位的具体条件还没弄清楚。我想争取机会，也担心到了现场又想退出。': '工作与现实条件',
          '我最近学习一项新技能，几次练习都卡住了。我还想学，但开始怀疑是不是方法或条件不合适。': '学习受挫',
          '我想照顾家人，也需要保留自己的休息时间。这周两边的安排可能冲突，我不知道怎样开口协调。': '家庭照护与取舍',
          '朋友的一个举动让我难受，我不知道该先澄清、设定边界，还是暂缓联系。': '关系中的认识与边界',
          '我有一份稳定的工作，最近又想尝试创作，但从没真正做过。我想找一个可以撤回的小尝试。': '保留新兴趣',
        });
    if (value != null) _input.text = value;
  }
}

class CaseTile extends StatelessWidget {
  const CaseTile({super.key, required this.file, required this.onTap});
  final CaseFile file;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MirrorCard(
          onTap: onTap,
          padding: const EdgeInsets.all(17),
          child: Row(children: [
            Container(
                width: 5,
                height: 44,
                decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(5))),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(file.issue,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                      '${file.phaseLabel} · 第 ${file.cycle} 轮 · ${timeLabel(file.updatedAt)}',
                      style: Theme.of(context).textTheme.bodySmall)
                ])),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18)
          ])));
}
