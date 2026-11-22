import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'artwork.dart';
import 'editor_dialogs.dart' show askForName;
import 'feedback_platform.dart';

typedef RuleTrial = Future<void> Function(
    ImageRegion region, List<FeedbackStep> steps);

Future<ImageRegion?> editRegionRules(BuildContext context, Artwork artwork,
        ImageRegion region, FeedbackSettings settings, RuleTrial tryChain) =>
    showModalBottomSheet<ImageRegion>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) =>
          _RegionFeedbackEditor(artwork, region, settings, tryChain),
    );

class _RegionFeedbackEditor extends StatefulWidget {
  const _RegionFeedbackEditor(
      this.artwork, this.region, this.settings, this.tryChain);

  final Artwork artwork;
  final ImageRegion region;
  final FeedbackSettings settings;
  final RuleTrial tryChain;

  @override
  State<_RegionFeedbackEditor> createState() => _RegionFeedbackEditorState();
}

class _RegionFeedbackEditorState extends State<_RegionFeedbackEditor> {
  late ImageRegion _region = widget.region;
  late final _name = TextEditingController(text: _region.label);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<List<FeedbackStep>?> _openChain(
          String trigger, List<FeedbackStep> steps) =>
      Navigator.of(context).push<List<FeedbackStep>>(MaterialPageRoute(
          builder: (_) => _FeedbackChainEditor(
                artwork: widget.artwork,
                trigger: trigger,
                steps: steps,
                trial: (preview) => widget.tryChain(_region, preview),
              )));

  Future<void> _editGesture(TouchGesture gesture) async {
    final steps =
        await _openChain(gesture.label, _region.rules[gesture] ?? const []);
    if (!mounted || steps == null) return;
    final rules = Map.of(_region.rules);
    if (steps.isEmpty) {
      rules.remove(gesture);
    } else {
      rules[gesture] = steps;
    }
    setState(() => _region = _region.copyWith(rules: rules));
  }

  Future<String?> _askForPhrase({int? index}) async {
    final name = await askForName(context,
        title: index == null ? '添加语音口令' : '更改语音口令',
        field: '口令（例如：播放视频）',
        initial: index == null ? '' : _region.voiceRules[index].phrase);
    if (!mounted || name == null) return null;
    final normalized = normalizeCommand(name);
    final duplicate = _region.voiceRules.indexed.any((entry) =>
        entry.$1 != index && normalizeCommand(entry.$2.phrase) == normalized);
    if (normalized.isEmpty ||
        normalized == normalizeCommand(widget.settings.wakePhrase) ||
        duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入有效的口令，口令需区别于唤醒词和已有口令。')));
      return null;
    }
    return name;
  }

  Future<void> _editVoice({int? index}) async {
    final phrase = index == null
        ? await _askForPhrase()
        : _region.voiceRules[index].phrase;
    if (!mounted || phrase == null) return;
    final steps = await _openChain(
        phrase, index == null ? const [] : _region.voiceRules[index].steps);
    if (!mounted || steps == null) return;
    final rules = List.of(_region.voiceRules);
    if (index != null) rules.removeAt(index);
    if (steps.isNotEmpty)
      rules.insert(index ?? rules.length, VoiceFeedback(phrase, steps));
    setState(() => _region = _region.copyWith(voiceRules: rules));
  }

  Future<void> _manageVoice(int index, String action) async {
    final rules = List.of(_region.voiceRules);
    if (action == 'delete') {
      rules.removeAt(index);
    } else {
      final name = await _askForPhrase(index: index);
      if (!mounted || name == null) return;
      rules[index] = VoiceFeedback(name, rules[index].steps);
    }
    setState(() => _region = _region.copyWith(voiceRules: rules));
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final changed = _region.source.isAutomatic &&
        (name != widget.region.label || _region.group != widget.region.group);
    Navigator.pop(
        context,
        _region.copyWith(
            label: name, source: changed ? RegionSource.manual : null));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('区域与反馈', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
                controller: _name,
                maxLength: 60,
                decoration: const InputDecoration(
                    labelText: '区域名称', border: OutlineInputBorder())),
            DropdownButtonFormField<RegionGroup>(
              initialValue: _region.group,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: '部位分类', border: OutlineInputBorder()),
              items: [
                for (final group in RegionGroup.values)
                  DropdownMenuItem(value: group, child: Text(group.label))
              ],
              onChanged: (group) =>
                  setState(() => _region = _region.copyWith(group: group)),
            ),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启用互动'),
                value: _region.enabled,
                onChanged: (enabled) => setState(
                    () => _region = _region.copyWith(enabled: enabled))),
            Row(children: [
              Expanded(child: Text('触摸优先级  ${_region.priority}')),
              IconButton(
                  tooltip: '降低优先级',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _region.priority <= -10
                      ? null
                      : () => setState(() => _region =
                          _region.copyWith(priority: _region.priority - 1))),
              IconButton(
                  tooltip: '提高优先级',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _region.priority >= 10
                      ? null
                      : () => setState(() => _region =
                          _region.copyWith(priority: _region.priority + 1))),
            ]),
            const Divider(),
            for (final gesture in TouchGesture.values)
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.touch_app_outlined),
                  title: Text(gesture.label),
                  subtitle: Text(_chainSummary(_region.rules[gesture])),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editGesture(gesture)),
            const Divider(),
            for (final (index, rule) in _region.voiceRules.indexed)
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mic_none),
                  title: Text(rule.phrase),
                  subtitle: Text(_chainSummary(rule.steps)),
                  onTap: () => _editVoice(index: index),
                  trailing: PopupMenuButton<String>(
                      tooltip: '口令选项',
                      onSelected: (choice) => _manageVoice(index, choice),
                      itemBuilder: (_) => const [
                            PopupMenuItem(value: 'rename', child: Text('更改口令')),
                            PopupMenuItem(value: 'delete', child: Text('删除口令')),
                          ])),
            OutlinedButton.icon(
                onPressed: _editVoice,
                icon: const Icon(Icons.mic_none),
                label: const Text('添加语音口令')),
            const SizedBox(height: 12),
            ListenableBuilder(
                listenable: _name,
                builder: (context, _) => FilledButton(
                    onPressed: _name.text.trim().isEmpty ? null : _save,
                    child: const Text('保存规则'))),
          ]),
        ),
      );

  String _chainSummary(List<FeedbackStep>? steps) {
    if (steps == null || steps.isEmpty) return '未设置反馈';
    return '${steps.length} 步 · ${steps.map((step) => step.action.label).join(' → ')}';
  }
}

class _FeedbackChainEditor extends StatefulWidget {
  const _FeedbackChainEditor(
      {required this.artwork,
      required this.trigger,
      required this.steps,
      required this.trial});

  final Artwork artwork;
  final String trigger;
  final List<FeedbackStep> steps;
  final Future<void> Function(List<FeedbackStep>) trial;

  @override
  State<_FeedbackChainEditor> createState() => _FeedbackChainEditorState();
}

class _FeedbackChainEditorState extends State<_FeedbackChainEditor> {
  late final _steps = [
    for (final step in widget.steps)
      FeedbackStep(step.action, value: step.value, name: step.name),
  ];
  bool _busy = false;

  Future<void> _configure({int? index}) async {
    if (_busy) return;
    final old = index == null ? null : _steps[index];
    setState(() => _busy = true);
    try {
      final type = old?.action ??
          await showModalBottomSheet<TouchAction>(
              context: context,
              useSafeArea: true,
              showDragHandle: true,
              builder: (context) => ListView(shrinkWrap: true, children: [
                    for (final action in TouchAction.values)
                      ListTile(
                          title: Text(action.label),
                          onTap: () => Navigator.pop(context, action)),
                  ]));
      if (type == null || !mounted) return;
      final step = await _editStep(type, old);
      if (!mounted || step == null) return;
      setState(() {
        if (index == null) {
          _steps.add(step);
        } else {
          _steps[index] = step;
        }
      });
    } on PlatformException catch (error) {
      _notice(switch (error.code) {
        'media_too_large' => '音频最大 30 MB，视频最大 150 MB。',
        'invalid_media' => '无法读取该媒体格式，请换一个文件。',
        _ => '无法读取所选媒体。',
      });
    } on MissingPluginException {
      _notice('当前平台暂不支持该反馈。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<FeedbackStep?> _editStep(TouchAction type, FeedbackStep? old) async {
    switch (type) {
      case TouchAction.link:
        final value = await showDialog<String>(
            context: context, builder: (_) => _LinkDialog(old?.value));
        return value == null ? null : FeedbackStep(type, value: value);
      case TouchAction.app:
        return showModalBottomSheet<FeedbackStep>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            builder: (_) => _AppPicker(old?.name));
      case TouchAction.audio:
        return const FeedbackPlatform()
            .pickMedia(widget.artwork.id, type, gallery: false);
      case TouchAction.video:
        final fromGallery = await showModalBottomSheet<bool>(
            context: context,
            useSafeArea: true,
            showDragHandle: true,
            builder: (context) =>
                Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(
                      leading: const Icon(Icons.video_library_outlined),
                      title: const Text('从手机相册选择'),
                      onTap: () => Navigator.pop(context, true)),
                  ListTile(
                      leading: const Icon(Icons.folder_open_outlined),
                      title: const Text('从文件导入'),
                      onTap: () => Navigator.pop(context, false)),
                ]));
        if (fromGallery == null) return null;
        return const FeedbackPlatform()
            .pickMedia(widget.artwork.id, type, gallery: fromGallery);
      case TouchAction.speak:
        final value = await showDialog<String>(
            context: context,
            builder: (_) => _LinkDialog(old?.value, speech: true));
        return value == null
            ? null
            : FeedbackStep(type, value: value, name: value);
      case TouchAction.systemSound:
        return showModalBottomSheet<FeedbackStep>(
            context: context,
            useSafeArea: true,
            showDragHandle: true,
            builder: (context) =>
                Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final (key, name) in [
                    ('notification', '默认通知音'),
                    ('ringtone', '默认来电铃声'),
                    ('alarm', '默认闹钟铃声')
                  ])
                    ListTile(
                        title: Text(name),
                        onTap: () => Navigator.pop(context,
                            FeedbackStep(type, value: key, name: name))),
                ]));
      default:
        return FeedbackStep(type);
    }
  }

  bool _hasOptions(FeedbackStep step) =>
      step.action.isFile ||
      const {
        TouchAction.app,
        TouchAction.link,
        TouchAction.systemSound,
        TouchAction.speak
      }.contains(step.action);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('${widget.trigger} · 反馈链'), actions: [
          IconButton(
              tooltip: '试播反馈链',
              icon: const Icon(Icons.play_circle_outline),
              onPressed: _busy || _steps.isEmpty
                  ? null
                  : () => widget.trial(List.of(_steps))),
          TextButton(
              onPressed:
                  _busy ? null : () => Navigator.pop(context, List.of(_steps)),
              child: const Text('保存顺序')),
        ]),
        body: SafeArea(
            child: Column(children: [
          Expanded(
              child: _steps.isEmpty
                  ? const Center(child: Text('添加反馈后，触发时会按顺序执行。'))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      buildDefaultDragHandles: false,
                      itemCount: _steps.length,
                      onReorder: (from, to) {
                        if (_busy) return;
                        setState(() => _steps.insert(
                            to > from ? to - 1 : to, _steps.removeAt(from)));
                      },
                      itemBuilder: (context, index) {
                        final step = _steps[index];
                        return ListTile(
                          key: ObjectKey(step),
                          leading: ReorderableDragStartListener(
                              index: index,
                              enabled: !_busy,
                              child: Semantics(
                                  label: '拖动调整顺序',
                                  child: const Icon(Icons.drag_handle))),
                          title: Text(step.title,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: step.title == step.action.label
                              ? null
                              : Text(step.action.label),
                          onTap: _busy || !_hasOptions(step)
                              ? null
                              : () => _configure(index: index),
                          trailing: PopupMenuButton<String>(
                              tooltip: '反馈步骤选项',
                              enabled: !_busy,
                              onSelected: (choice) {
                                if (choice == 'edit') {
                                  _configure(index: index);
                                } else {
                                  setState(() {
                                    final removed = _steps.removeAt(index);
                                    if (choice != 'delete')
                                      _steps.insert(
                                          index + (choice == 'up' ? -1 : 1),
                                          removed);
                                  });
                                }
                              },
                              itemBuilder: (_) => [
                                    if (_hasOptions(step))
                                      const PopupMenuItem(
                                          value: 'edit', child: Text('编辑')),
                                    if (index > 0)
                                      const PopupMenuItem(
                                          value: 'up', child: Text('上移')),
                                    if (index < _steps.length - 1)
                                      const PopupMenuItem(
                                          value: 'down', child: Text('下移')),
                                    const PopupMenuItem(
                                        value: 'delete', child: Text('删除步骤')),
                                  ]),
                        );
                      },
                    )),
          Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                  onPressed: _busy ? null : _configure,
                  icon: const Icon(Icons.add),
                  label: Text(_busy ? '正在配置…' : '添加反馈'))),
        ])),
      );
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog(this.initial, {this.speech = false});
  final String? initial;
  final bool speech;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final _text = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    if (widget.speech) {
      final text = _text.text.trim();
      if (text.isEmpty || text.length > 300) {
        setState(() => _error = '请输入 1 至 300 字的朗读文字。');
      } else {
        Navigator.pop(context, text);
      }
      return;
    }
    final uri = feedbackLink(_text.text);
    if (uri == null) {
      setState(() => _error = '请输入有效的 HTTP 或 HTTPS 链接。');
    } else {
      Navigator.pop(context, uri.toString());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.speech ? '系统语音朗读' : '打开链接'),
        content: TextField(
            controller: _text,
            autofocus: true,
            keyboardType:
                widget.speech ? TextInputType.multiline : TextInputType.url,
            maxLines: widget.speech ? 4 : 1,
            maxLength: widget.speech ? 300 : null,
            decoration: InputDecoration(
                labelText: widget.speech ? '朗读文字' : '链接地址', errorText: _error),
            onSubmitted: (_) => _save()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: _save, child: const Text('保存'))
        ],
      );
}

class _AppPicker extends StatefulWidget {
  const _AppPicker(this.initial);
  final String? initial;

  @override
  State<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<_AppPicker> {
  late final _text = TextEditingController(text: widget.initial);
  late final _apps = const FeedbackPlatform().apps();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.68,
        child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('选择手机应用', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                TextField(
                    controller: _text,
                    decoration: const InputDecoration(labelText: '应用名称'),
                    maxLength: 80,
                    onChanged: (_) => setState(() {})),
                Expanded(
                    child: FutureBuilder<List<InstalledFeedbackApp>>(
                        future: _apps,
                        builder: (context, snapshot) {
                          final query = _text.text.trim().toLowerCase();
                          final matches =
                              (snapshot.data ?? const <InstalledFeedbackApp>[])
                                  .where((app) =>
                                      app.name.toLowerCase().contains(query) ||
                                      app.package.contains(query))
                                  .toList();
                          if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            return const Center(
                                child: CircularProgressIndicator());
                          if (matches.isEmpty)
                            return const Center(child: Text('没有匹配的已安装应用。'));
                          return ListView.builder(
                              itemCount: matches.length,
                              itemBuilder: (context, index) {
                                final app = matches[index];
                                return ListTile(
                                    title: Text(app.name),
                                    subtitle: Text(app.package),
                                    onTap: () => Navigator.pop(
                                        context,
                                        FeedbackStep(TouchAction.app,
                                            value: app.package,
                                            name: app.name)));
                              });
                        })),
                SafeArea(
                    top: false,
                    child: FilledButton(
                        onPressed: _text.text.trim().isEmpty
                            ? null
                            : () => Navigator.pop(
                                context,
                                FeedbackStep(TouchAction.app,
                                    name: _text.text.trim())),
                        child: const Text('按此名称查找'))),
              ],
            )),
      );
}
