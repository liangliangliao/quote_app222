import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'artwork.dart';
import 'artwork_repository.dart';
import 'editor_dialogs.dart';
import 'effort_tuning_dialog.dart';
import 'local_recognition.dart';
import 'original_artwork_image.dart';
import 'region_editor_page.dart';

class InteractiveImageHomePage extends StatefulWidget {
  const InteractiveImageHomePage(
      {super.key, required this.learningPage, required this.booksPage});

  final WidgetBuilder learningPage;
  final WidgetBuilder booksPage;

  @override
  State<InteractiveImageHomePage> createState() =>
      _InteractiveImageHomePageState();
}

enum _LibraryAction { rename, duplicate, delete }

class _InteractiveImageHomePageState extends State<InteractiveImageHomePage> {
  final _repository = ArtworkRepository();
  List<(Artwork, Directory)>? _works;
  bool _busy = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final works = await _repository.list();
      final entries = await Future.wait(works.map(
          (artwork) async => (artwork, await _repository.folderFor(artwork))));
      if (mounted)
        setState(() {
          _works = entries;
          _loadFailed = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    File? temporary;
    Artwork? imported;
    try {
      if (Platform.isAndroid) {
        final selection = await interactiveImageChannel
            .invokeMapMethod<String, String>('pickImage');
        if (selection == null) return;
        temporary = File(selection['path']!);
        imported = await _repository.importImage(
            temporary, selection['name'] ?? '未命名作品');
      } else {
        final selection =
            await ImagePicker().pickImage(source: ImageSource.gallery);
        if (selection == null) return;
        imported =
            await _repository.importImage(File(selection.path), selection.name);
      }
      await _reload();
    } on ArtworkImportException catch (error) {
      if (mounted) _message(error.message);
    } on PlatformException catch (error) {
      if (mounted)
        _message(switch (error.code) {
          'image_too_large' => '图片超过 25 MB，请选择较小的图片。',
          'picker_unavailable' => '无法打开系统图片选择器。',
          _ => '无法读取选中的图片。请检查访问权限并重试。',
        });
    } catch (_) {
      if (mounted) _message('无法导入这张图片，请检查图片格式和可用存储空间。');
    } finally {
      if (temporary != null) {
        try {
          await temporary.delete();
        } on FileSystemException {
          /* Cleared by the import cache on next launch. */
        }
      }
      if (mounted) setState(() => _busy = false);
    }
    if (imported != null && mounted) await _open(imported);
  }

  Future<void> _open(Artwork artwork) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final folder = await _repository.folderFor(artwork);
      final edits = await _repository.loadEdits(folder);
      final settings = await _repository.loadSettings();
      if (!mounted) return;
      await Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (context) => RegionEditorPage(
                artwork: artwork,
                folder: folder,
                repository: _repository,
                edits: edits,
                settings: settings,
                openPage: _openMappedPage,
              )));
      try {
        await _repository.cleanUnusedMedia(
            folder, await _repository.loadEdits(folder));
      } on FileSystemException {
        // Keep the last saved rules and retry cleanup when the work is opened again.
      }
    } catch (_) {
      if (mounted) _message('无法打开这件作品，或读取交互设置。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMappedPage(TouchAction action) async {
    final builder = switch (action) {
      TouchAction.learning => widget.learningPage,
      TouchAction.books => widget.booksPage,
      _ => null
    };
    if (builder != null && mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: builder));
    }
  }

  Future<void> _manage(Artwork artwork, _LibraryAction action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      switch (action) {
        case _LibraryAction.rename:
          final title = await askForName(context,
              title: '重命名作品', field: '作品名称', initial: artwork.title);
          if (title == null) return;
          await _repository.rename(artwork, title);
        case _LibraryAction.duplicate:
          await _repository.duplicate(artwork);
          if (mounted) _message('作品已复制。');
        case _LibraryAction.delete:
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('删除作品？'),
              content: Text('「${artwork.title}」的应用内图片、区域和规则会被删除。相册中的图片会保留。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('删除')),
              ],
            ),
          );
          if (confirmed != true) return;
          await _repository.delete(artwork);
      }
    } catch (_) {
      if (mounted) _message('操作未完成，请重试。');
    } finally {
      await _reload();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSettings() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final settings = await _repository.loadSettings();
      if (!mounted) return;
      final updated = await showModalBottomSheet<FeedbackSettings>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) =>
            _SettingsSheet(initial: settings, clearCache: _clearCache),
      );
      if (updated != null) await _repository.saveSettings(updated);
    } catch (_) {
      if (mounted) _message('无法读取或保存交互设置。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearCache() async {
    if (Platform.isAndroid)
      await interactiveImageChannel.invokeMethod<void>('clearImportCache');
    for (final (artwork, folder) in _works ?? const <(Artwork, Directory)>[]) {
      await OriginalArtworkImage(_repository.originalFile(folder, artwork))
          .evict();
      await FileImage(_repository.previewFile(folder)).evict();
      await FileImage(_repository.thumbnailFile(folder)).evict();
    }
  }

  @override
  Widget build(BuildContext context) {
    final works = _works;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 智能图片交互'),
        actions: [
          IconButton(
              tooltip: '交互设置',
              onPressed: _busy ? null : _openSettings,
              icon: const Icon(Icons.tune))
        ],
      ),
      floatingActionButton: works != null && works.isNotEmpty && !_loadFailed
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _import,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('导入图片'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
                child: switch ((works, _loadFailed)) {
              (_, true) => Center(
                  child: TextButton(
                      onPressed: _reload, child: const Text('无法读取作品库，点此重试'))),
              (null, _) => const Center(child: CircularProgressIndicator()),
              (final items?, _) when items.isEmpty => Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircleAvatar(
                          radius: 38,
                          backgroundColor: colors.primaryContainer,
                          child: Icon(Icons.touch_app_outlined,
                              size: 37, color: colors.onPrimaryContainer)),
                      const SizedBox(height: 20),
                      Text('让图片可以触摸互动',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      const Text(
                          '导入一张 JPG、PNG 或 WebP 图片。标出图片中的人物或物品，为不同手势设置反馈。',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                          onPressed: _busy ? null : _import,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('导入图片')),
                      const SizedBox(height: 14),
                      Text('私密作品 · 仅保存在此设备',
                          style: TextStyle(color: colors.onSurfaceVariant)),
                    ]),
                  ),
                ),
              (final items?, _) => CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                        child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Text('最近作品 · 缩略图已模糊',
                          style: Theme.of(context).textTheme.titleSmall),
                    )),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 245,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent:
                              114 + MediaQuery.textScalerOf(context).scale(60),
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            _card(items[index].$1, items[index].$2),
                      ),
                    ),
                  ],
                ),
            }),
          ],
        ),
      ),
    );
  }

  Widget _card(Artwork artwork, Directory folder) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: _busy ? null : () => _open(artwork),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
              child: Stack(fit: StackFit.expand, children: [
            ColoredBox(color: colors.primaryContainer),
            Image.file(_repository.thumbnailFile(folder),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink()),
            Center(
                child: Semantics(
              label: '私密作品',
              child: DecoratedBox(
                decoration: const BoxDecoration(
                    color: Color(0xB935384D), shape: BoxShape.circle),
                child: const Padding(
                    padding: EdgeInsets.all(9),
                    child: Icon(Icons.lock_outline,
                        size: 19, color: Colors.white)),
              ),
            )),
          ])),
          Row(children: [
            Expanded(
                child: Padding(
              padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
              child: Text(artwork.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall),
            )),
            PopupMenuButton<_LibraryAction>(
              enabled: !_busy,
              tooltip: '作品选项',
              onSelected: (action) => _manage(artwork, action),
              itemBuilder: (context) => const [
                PopupMenuItem(value: _LibraryAction.rename, child: Text('重命名')),
                PopupMenuItem(
                    value: _LibraryAction.duplicate, child: Text('复制作品')),
                PopupMenuItem(
                    value: _LibraryAction.delete, child: Text('删除作品')),
              ],
            ),
          ]),
        ]),
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.initial, required this.clearCache});
  final FeedbackSettings initial;
  final Future<void> Function() clearCache;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late FeedbackSettings _settings = widget.initial;
  bool _clearing = false;
  String? _status;

  Future<void> _clear() async {
    setState(() => _clearing = true);
    var message = '临时缓存已清理。';
    try {
      await widget.clearCache();
    } catch (_) {
      message = '临时缓存无法清理，请重试。';
    }
    if (mounted)
      setState(() {
        _status = message;
        _clearing = false;
      });
  }

  Future<void> _changeWakePhrase() async {
    final value = await askForName(context,
        title: '更改唤醒提示词', field: '唤醒提示词', initial: _settings.wakePhrase);
    if (mounted && value != null && normalizeCommand(value).isNotEmpty) {
      setState(() => _settings = _settings.copyWith(wakePhrase: value));
    }
  }

  Future<void> _changeEffortTuning() async {
    final result = await editEffortTuning(
        context, _settings.effortDifficulty, _settings.effortTuning);
    if (mounted && result != null) {
      setState(() => _settings = _settings.withEffortTuning(result.value));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('交互设置', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.lock_outline),
                title: Text('设备端识别'),
                subtitle: Text('原图、区域和规则仅保存在此设备。作品库显示模糊缩略图。')),
            const Divider(),
            DropdownButtonFormField<EffortDifficulty>(
              initialValue: _settings.effortDifficulty,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '触屏努力难度',
                helperText: '努力值达到 100% 后执行反馈链',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final difficulty in EffortDifficulty.values)
                  DropdownMenuItem(
                      value: difficulty, child: Text(difficulty.label)),
              ],
              onChanged: (difficulty) => setState(() =>
                  _settings = _settings.copyWith(effortDifficulty: difficulty)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('手动调节当前档位'),
              subtitle: Text(
                  '${_settings.effortTuning.taps} 次连点 · 滑动 ${_settings.effortTuning.swipeDistance} · 长按 ${effortHoldLabel(_settings.effortTuning.holdTime)}'),
              trailing: const Icon(Icons.tune),
              onTap: _changeEffortTuning,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('视觉反馈'),
                value: _settings.visual,
                onChanged: (value) => setState(
                    () => _settings = _settings.copyWith(visual: value))),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('声音反馈'),
                value: _settings.sound,
                onChanged: (value) => setState(
                    () => _settings = _settings.copyWith(sound: value))),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('震动反馈'),
                value: _settings.vibration,
                onChanged: (value) => setState(
                    () => _settings = _settings.copyWith(vibration: value))),
            const Divider(),
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mic_none),
                title: const Text('语音唤醒提示词'),
                subtitle: Text(_settings.wakePhrase),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _changeWakePhrase),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('允许系统语音识别'),
                subtitle: const Text('端侧识别不可用时，允许系统服务识别预览中的语音，服务可能联网。'),
                value: _settings.allowSystemSpeech,
                onChanged: (value) => setState(() =>
                    _settings = _settings.copyWith(allowSystemSpeech: value))),
            Wrap(spacing: 8, children: [
              TextButton(
                  onPressed: () => setState(() => _settings = _settings
                      .copyWith(visual: false, sound: false, vibration: false)),
                  child: const Text('关闭全部反馈')),
              TextButton(
                  onPressed: () =>
                      setState(() => _settings = const FeedbackSettings()),
                  child: const Text('恢复默认')),
              TextButton(
                  onPressed: _clearing ? null : _clear,
                  child: const Text('清理临时缓存')),
            ]),
            if (_status case final status?)
              Semantics(liveRegion: true, child: Text(status)),
            const SizedBox(height: 8),
            FilledButton(
                onPressed: () => Navigator.pop(context, _settings),
                child: const Text('保存设置')),
          ]),
        ),
      );
}
