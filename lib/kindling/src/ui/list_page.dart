import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/controller.dart';
import 'burn_page.dart';
import 'recall_page.dart';
import 'probe_sheet.dart';
import 'released_page.dart';
import 'resistance_page.dart';
import 'verdict_sheet.dart';

/// 火种清单（主页）。
///
/// 列表项只有标题：无标签、无分数、无最后活动时间。顶部没有「新建目标」按钮，
/// 新增火种只能经由「回溯」产生；清单为空时才给一行灰字「直接写一个」。
class KindlingListPage extends StatefulWidget {
  const KindlingListPage({super.key, required this.controller});

  static const Key listKey = ValueKey<String>('kindling_list');
  static const Key emptyKey = ValueKey<String>('kindling_list_empty');
  static const Key directKey = ValueKey<String>('kindling_list_direct');
  static const Key recallKey = ValueKey<String>('kindling_list_recall');
  static const Key burnKey = ValueKey<String>('kindling_list_burn');
  static const Key releasedKey = ValueKey<String>('kindling_list_released');
  static const Key noteKey = ValueKey<String>('kindling_list_note');

  final KindlingController controller;

  @override
  State<KindlingListPage> createState() => _KindlingListPageState();
}

class _KindlingListPageState extends State<KindlingListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  KindlingController get _c => widget.controller;

  Future<void> _boot() async {
    await _c.load();
    if (!mounted) return;
    // 答过「说不准」的火种，7 天后再问一次。每次会话至多一条。
    final KItem? due = await _c.takeReaskCandidate();
    if (due == null || !mounted) return;
    await KindlingVerdictSheet.show(
      context,
      controller: _c,
      itemId: due.id,
      title: due.title,
    );
  }

  // ---------------------------------------------------------------- 动作

  Future<void> _openRecall() async {
    final List<KindlingCreatedItem>? created =
        await Navigator.of(context).push<List<KindlingCreatedItem>>(
      MaterialPageRoute<List<KindlingCreatedItem>>(
        builder: (_) => KindlingRecallPage(controller: _c),
      ),
    );
    await _c.load();
    if (created == null) return;
    // 新建火种后强制问一次判别式，逐条问。
    for (final KindlingCreatedItem item in created) {
      if (!mounted) return;
      await KindlingVerdictSheet.show(
        context,
        controller: _c,
        itemId: item.id,
        title: item.title,
      );
    }
  }

  Future<void> _openReleased() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KindlingReleasedPage(controller: _c),
      ),
    );
    await _c.load();
  }

  Future<void> _openBurn(KItemView view) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KindlingBurnPage(
          controller: _c,
          itemId: view.id,
          title: view.title,
        ),
      ),
    );
    await _c.load();
  }

  /// 底部「十五分钟」：清单只有一条时直接进入，否则先选一个。
  Future<void> _startBurn() async {
    final List<KItemView> items = _c.items;
    if (items.isEmpty) return;
    if (items.length == 1) {
      await _openBurn(items.first);
      return;
    }
    final KItemView? picked = await showModalBottomSheet<KItemView>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Text(
                  KCopy.pickBurnItem,
                  style: TextStyle(fontSize: 15, color: Color(0xFF8A8A8A)),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (BuildContext context, int i) => ListTile(
                    title: Text(
                      items[i].title,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF2B2B2B),
                      ),
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(items[i]),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    await _openBurn(picked);
  }

  Future<void> _openResistance(KItemView view) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KindlingResistancePage(
          controller: _c,
          itemId: view.id,
          title: view.title,
        ),
      ),
    );
    await _c.load();
  }

  Future<void> _rename(KItemView view) async {
    final ({String title, String note})? next = await _promptText(
      initial: view.title,
      initialNote: view.item.note,
      withNote: true,
    );
    if (next == null || next.title.trim().isEmpty) return;
    await _c.rename(view.id, next.title, note: next.note);
  }

  /// 清单为空时的入口：写完立刻弹判别式。
  Future<void> _writeDirect() async {
    final ({String title, String note})? text = await _promptText(
      fieldKey: KindlingListPage.directKey,
    );
    final String title = (text?.title ?? '').trim();
    if (title.isEmpty || !mounted) return;
    final int id = await _c.addItem(title);
    if (!mounted) return;
    await KindlingVerdictSheet.show(
      context,
      controller: _c,
      itemId: id,
      title: title,
    );
  }

  /// 一行输入（换个说法时多一行可选备注）。
  /// 对话框自己持有 TextEditingController，随路由一起销毁。
  Future<({String title, String note})?> _promptText({
    String? initial,
    String? initialNote,
    Key? fieldKey,
    bool withNote = false,
  }) {
    return showDialog<({String title, String note})>(
      context: context,
      builder: (BuildContext dialogContext) => _TextPromptDialog(
        initial: initial,
        initialNote: initialNote,
        fieldKey: fieldKey,
        withNote: withNote,
      ),
    );
  }

  /// 长按菜单。连续 3 次「不想」时把「放掉」置顶，不主动弹窗劝退。
  Future<void> _openMenu(KItemView view) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (BuildContext sheetContext) {
        ListTile tile(String label, VoidCallback action) {
          return ListTile(
            title: Text(
              label,
              style: const TextStyle(fontSize: 16, color: Color(0xFF2B2B2B)),
            ),
            onTap: () {
              Navigator.of(sheetContext).pop();
              action();
            },
          );
        }

        final ListTile release = tile(
          KCopy.menuRelease,
          () => _c.release(view.id),
        );
        final List<Widget> rest = <Widget>[
          tile(
            KCopy.menuProbe,
            () => KindlingProbeSheet.show(
              context,
              controller: _c,
              itemId: view.id,
              title: view.title,
            ),
          ),
          tile(KCopy.menuRename, () => _rename(view)),
          tile(
            KCopy.menuVerdict,
            () => KindlingVerdictSheet.show(
              context,
              controller: _c,
              itemId: view.id,
              title: view.title,
            ),
          ),
          tile(KCopy.menuResistance, () => _openResistance(view)),
        ];

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: view.suggestRelease
                ? <Widget>[release, ...rest]
                : <Widget>[...rest, release],
          ),
        );
      },
    );
    await _c.load();
  }

  // ---------------------------------------------------------------- 渲染

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF2B2B2B),
        title: const Text(KCopy.title, style: TextStyle(fontSize: 17)),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _c,
          builder: (BuildContext context, Widget? _) {
            final List<KItemView> items = _c.items;
            return Column(
              children: <Widget>[
                Expanded(
                  child: items.isEmpty ? _buildEmpty() : _buildList(items),
                ),
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Color(0xFFF0F0F0),
                ),
                _buildReleasedRow(),
                _buildBottomBar(items.isNotEmpty),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      key: KindlingListPage.emptyKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            KCopy.emptyList,
            style: TextStyle(fontSize: 15, color: Color(0xFFAAAAAA)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _writeDirect,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFAAAAAA),
            ),
            child: const Text(
              KCopy.emptyDirect,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<KItemView> items) {
    return ListView.builder(
      key: KindlingListPage.listKey,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int i) {
        final KItemView view = items[i];
        return InkWell(
          onTap: () => _openBurn(view),
          onLongPress: () => _openMenu(view),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFCFCFCF)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    view.title,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReleasedRow() {
    return InkWell(
      key: KindlingListPage.releasedKey,
      onTap: _openReleased,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: <Widget>[
            Text(
              KCopy.releasedWithCount(_c.releasedCount),
              style: const TextStyle(fontSize: 15, color: Color(0xFF9A9A9A)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool hasItems) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(
              key: KindlingListPage.recallKey,
              onPressed: _openRecall,
              style: _barStyle,
              child: const Text(KCopy.recall, style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              key: KindlingListPage.burnKey,
              onPressed: hasItems ? _startBurn : null,
              style: _barStyle,
              child: const Text(KCopy.burn, style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle get _barStyle => OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2B2B2B),
        side: const BorderSide(color: Color(0xFFDDDDDD)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
}

/// 只做一件事：拿一行文字。放在这里是为了让 controller 的生命周期跟着对话框走。
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    this.initial,
    this.initialNote,
    this.fieldKey,
    this.withNote = false,
  });

  final String? initial;
  final String? initialNote;
  final Key? fieldKey;
  final bool withNote;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _input =
      TextEditingController(text: widget.initial);
  late final TextEditingController _note =
      TextEditingController(text: widget.initialNote);

  @override
  void dispose() {
    _input.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            key: widget.fieldKey,
            controller: _input,
            autofocus: true,
            maxLines: null,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(
              hintText: KCopy.titleHint,
              hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
            ),
          ),
          if (widget.withNote)
            TextField(
              key: KindlingListPage.noteKey,
              controller: _note,
              maxLines: null,
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                hintText: KCopy.noteHint,
                hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
              ),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(KCopy.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            (title: _input.text, note: _note.text),
          ),
          child: const Text(KCopy.save),
        ),
      ],
    );
  }
}
