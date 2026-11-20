import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'artwork.dart';
import 'artwork_canvas.dart';
import 'artwork_repository.dart';
import 'editor_dialogs.dart';
import 'interaction_player.dart';
import 'local_recognition.dart';
import 'region_geometry.dart';

class RegionEditorPage extends StatefulWidget {
  const RegionEditorPage({
    super.key,
    required this.artwork,
    required this.folder,
    required this.repository,
    required this.edits,
    required this.settings,
    required this.openPage,
  });

  final Artwork artwork;
  final Directory folder;
  final ArtworkRepository repository;
  final ArtworkEdits edits;
  final FeedbackSettings settings;
  final OpenInteractionPage openPage;

  @override
  State<RegionEditorPage> createState() => _RegionEditorPageState();
}

class _RegionEditorPageState extends State<RegionEditorPage> {
  final _transform = TransformationController();
  final _undo = <ArtworkEdits>[];
  final _redo = <ArtworkEdits>[];
  final _pointers = <int>{};
  late ArtworkEdits _edits = widget.edits;
  late final File _preview = widget.repository.previewFile(widget.folder);
  ArtworkEdits? _pending;
  Future<void>? _saveTask;
  bool _saveError = false;
  bool _leaving = false;
  bool _moving = false;
  bool _collapsed = false;
  String? _selectedId;
  String? _run;
  String? _status;
  int? _pointer;
  int? _activePoint;
  Offset? _down;
  List<Offset>? _dragPoints;

  List<ImageRegion> get _regions => _edits.visibleRegions;
  ImageRegion? get _selected =>
      _regions.where((region) => region.id == _selectedId).firstOrNull;

  @override
  void dispose() {
    final run = _run;
    if (run != null)
      unawaited(const LocalRecognition().cancel(run).catchError((Object _) {}));
    _transform.dispose();
    super.dispose();
  }

  void _change(ArtworkEdits next) {
    _undo.add(_edits);
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
    _replaceEdits(next);
  }

  void _replaceEdits(ArtworkEdits next) {
    setState(() {
      _edits = next;
      _activePoint = null;
      _saveError = false;
      _pending = next;
    });
    _saveTask ??= _saveEdits();
  }

  Future<void> _saveEdits() async {
    while (_pending != null) {
      final edits = _pending!;
      _pending = null;
      try {
        await widget.repository.saveEdits(widget.folder, edits);
      } catch (_) {
        if (_pending == null) {
          _pending = edits;
          _saveError = true;
          break;
        }
      }
    }
    _saveTask = null;
    if (mounted) setState(() {});
  }

  void _stepHistory(List<ArtworkEdits> from, List<ArtworkEdits> to) {
    to.add(_edits);
    _replaceEdits(from.removeLast());
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    try {
      await _cancelRecognition();
      if (_pending != null) _saveTask ??= _saveEdits();
      await _saveTask;
      if (!mounted) return;
      if (_saveError) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('还有更改未保存'),
            content: const Text('本次更改无法写入。退出后会恢复到上次保存的版本。'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('继续编辑')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('退出')),
            ],
          ),
        );
        if (confirmed != true) return;
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      _leaving = false;
    }
  }

  Future<void> _cancelRecognition({bool announce = false}) async {
    final run = _run;
    if (run == null) return;
    setState(() {
      _run = null;
      if (announce) _status = '已取消本次识别，可继续手动标注。';
    });
    try {
      await const LocalRecognition().cancel(run);
    } on PlatformException {
      // The editor ignores results from requests that have been cancelled.
    } on MissingPluginException {
      // The editor can continue without a detector on other platforms.
    }
  }

  Future<void> _recognize() async {
    if (_run != null || _edits.draft != null) return;
    final id = newArtworkId();
    setState(() {
      _run = id;
      _status = null;
      _collapsed = false;
    });
    try {
      final result = await const LocalRecognition()
          .detect(_preview.path, id, widget.artwork.aspectRatio);
      if (!mounted || _run != id) return;
      await widget.repository.saveAnalysis(widget.folder, id, result.raw);
      if (!mounted || _run != id) return;
      setState(() => _run = null);
      if (result.people.isEmpty) {
        _showStatus('没有找到可靠的可见区域。可以换一张更清晰的图片，或选择手动画区域。');
        return;
      }
      await _applyAnalysis(result);
    } on MissingPluginException {
      if (mounted && _run == id) _showStatus('此平台暂不支持本机识别。你仍可手动画区域。');
    } on PlatformException catch (error) {
      if (mounted && _run == id) {
        _showStatus(error.code == 'low_memory'
            ? '设备内存不足。可关闭其他应用后重试，或手动画区域。'
            : '本机模型暂时无法识别。请重试，或手动画区域。');
      }
    } catch (_) {
      if (mounted && _run == id) _showStatus('无法保存或读取本次识别结果。请重试，或手动画区域。');
    } finally {
      if (mounted && _run == id) setState(() => _run = null);
    }
  }

  Future<void> _applyAnalysis(RecognitionResult result) async {
    final target = result.people.length == 1
        ? result.people.single
        : await chooseRecognitionTarget(
            context,
            _preview,
            widget.artwork.aspectRatio,
            result.people,
          );
    if (!mounted || target == null) return;
    _change(_edits.withTarget(target.id, result.id, target.regions));
    final generated = _regions.where(
        (region) => region.targetId == target.id && region.source.isAutomatic);
    final review = generated
        .where((region) => region.source == RegionSource.proposed)
        .length;
    _showStatus(
        '已标出 ${generated.length} 个候选区域，$review 个待确认。${result.partial ? '部分本机模型暂不可用。' : ''}');
  }

  Future<void> _chooseAnotherTarget() async {
    final id = _edits.lastAnalysisId;
    if (id == null) return;
    try {
      final raw = await widget.repository.loadAnalysis(widget.folder, id);
      if (mounted)
        await _applyAnalysis(
            RecognitionResult.fromJson(raw, widget.artwork.aspectRatio));
    } catch (_) {
      if (mounted) _showStatus('上次识别结果无法读取，请重新识别。');
    }
  }

  void _showStatus(String text) => setState(() => _status = text);

  void _startPolygon(ImageRegion? region) {
    setState(() {
      _moving = false;
      _collapsed = false;
    });
    _change(_edits
        .withDraft(PolygonDraft(region?.id, region?.polygon ?? const [])));
  }

  Future<void> _savePolygon() async {
    final draft = _edits.draft!;
    if (!validPolygon(draft.points)) {
      _showStatus('区域需要至少三个不同的顶点，边线不能交叉。');
      return;
    }
    final region =
        _regions.where((region) => region.id == draft.regionId).firstOrNull;
    if (region != null) {
      _change(_edits.withDraft(null).withRegions([
        for (final entry in _edits.regions)
          if (entry.id == region.id)
            entry.copyWith(polygon: draft.points, source: RegionSource.manual)
          else
            entry,
      ]));
    } else {
      final name = await askForName(context,
          title: '新增区域', field: '区域名称', initial: '自定义区域');
      if (!mounted || name == null) return;
      final region = ImageRegion(
          id: newArtworkId(),
          label: name,
          group: RegionGroup.object,
          polygon: draft.points);
      _selectedId = region.id;
      _change(_edits.withDraft(null).withRegions([..._edits.regions, region]));
    }
    _showStatus('区域已更新，可为它设置手势。');
  }

  void _setRegion(ImageRegion region) {
    _change(_edits.withRegions([
      for (final entry in _edits.regions)
        if (entry.id == region.id) region else entry
    ]));
  }

  void _deleteRegion(ImageRegion region) {
    _change(_edits.withRegions(
      _edits.regions.where((entry) => entry.id != region.id).toList(),
      dismissed: {..._edits.dismissed, region.id},
    ));
    _showStatus('已删除「${region.label}」，可撤销。');
  }

  Future<void> _previewInteraction({(ImageRegion, TouchAction)? trial}) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (context) => InteractionPlayer(
              artwork: widget.artwork,
              file: _preview,
              regions: _regions,
              settings: widget.settings,
              openPage: widget.openPage,
              trial: trial,
            )));
  }

  Future<void> _editRules(ImageRegion region) async {
    final updated = await editRegionRules(context, region,
        (region, action) => _previewInteraction(trial: (region, action)));
    if (mounted && updated != null) {
      // Preserve rule edits on a candidate even if recognition is run again.
      _setRegion(updated.copyWith(edited: true));
    }
  }

  void _onDown(PointerEvent event, ArtworkCoordinates coordinates) {
    _pointers.add(event.pointer);
    if (_pointers.length > 1) {
      _clearPointer();
      return;
    }
    if (_moving ||
        _run != null ||
        coordinates.pointAt(event.localPosition) == null) return;
    _pointer = event.pointer;
    _down = event.localPosition;
    final draft = _edits.draft;
    if (draft == null) return;
    int? index;
    var best = 16.0;
    for (final (i, point) in draft.points.indexed) {
      final distance =
          (coordinates.viewPoint(point) - event.localPosition).distance;
      if (distance < best) {
        best = distance;
        index = i;
      }
    }
    setState(() => _activePoint = index);
  }

  void _onMove(PointerEvent event, ArtworkCoordinates coordinates) {
    final draft = _edits.draft;
    final index = _activePoint;
    if (_pointer != event.pointer || draft == null || index == null) return;
    if (_dragPoints == null && (event.localPosition - _down!).distance < 4)
      return;
    final point = coordinates.pointAt(event.localPosition, clamp: true);
    if (point == null) return;
    final points = List<Offset>.of(draft.points);
    points[index] = point;
    setState(() => _dragPoints = points);
  }

  void _onUp(PointerEvent event, ArtworkCoordinates coordinates) {
    _pointers.remove(event.pointer);
    if (_pointer != event.pointer) return;
    final point = coordinates.pointAt(event.localPosition);
    final isTap = (event.localPosition - _down!).distance < 12;
    final drag = _dragPoints;
    final index = _activePoint;
    _clearPointer();
    final draft = _edits.draft;
    if (draft != null && drag != null) {
      _change(_edits.withDraft(PolygonDraft(draft.regionId, drag)));
      setState(() => _activePoint = index);
    } else if (point != null && isTap) {
      if (draft == null) {
        final hit = hitRegion(_regions, point, editing: true);
        setState(() {
          _selectedId = hit?.id;
          if (hit != null) _collapsed = false;
        });
      } else if (index == null && draft.points.length < 48) {
        _change(_edits
            .withDraft(PolygonDraft(draft.regionId, [...draft.points, point])));
      }
    }
  }

  void _clearPointer() {
    _pointer = null;
    _down = null;
    if (_dragPoints != null) setState(() => _dragPoints = null);
  }

  void _removePoint() {
    final draft = _edits.draft!;
    final points = List.of(draft.points)
      ..removeAt(_activePoint ?? draft.points.length - 1);
    _change(_edits.withDraft(PolygonDraft(draft.regionId, points)));
  }

  @override
  Widget build(BuildContext context) {
    final draft = _edits.draft;
    return PopScope(
      canPop: _run == null && _saveTask == null && !_saveError,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.artwork.title,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
                tooltip: '撤销',
                onPressed: _undo.isEmpty || _run != null
                    ? null
                    : () => _stepHistory(_undo, _redo),
                icon: const Icon(Icons.undo)),
            IconButton(
                tooltip: '重做',
                onPressed: _redo.isEmpty || _run != null
                    ? null
                    : () => _stepHistory(_redo, _undo),
                icon: const Icon(Icons.redo)),
            IconButton(
                tooltip: '交互预览',
                onPressed: _run != null ? null : _previewInteraction,
                icon: const Icon(Icons.play_circle_outline)),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            final landscape =
                box.maxWidth > box.maxHeight && box.maxWidth >= 640;
            final canvas = _buildCanvas(draft);
            final panel = _buildPanel(draft, landscape: landscape);
            if (landscape) {
              return Row(children: [
                Expanded(child: canvas),
                SizedBox(width: 328, child: panel)
              ]);
            }
            return Column(children: [
              Expanded(flex: 5, child: canvas),
              if (_collapsed && draft == null && _run == null && !_saveError)
                _panelHeader('编辑面板', collapsed: true)
              else
                Expanded(flex: 4, child: panel),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _buildCanvas(PolygonDraft? draft) => Stack(
        children: [
          Positioned.fill(
              child: ArtworkCanvas(
            file: _preview,
            aspectRatio: widget.artwork.aspectRatio,
            transform: _transform,
            panEnabled: _moving,
            regions: _regions,
            selectedId: _selectedId,
            draft: _dragPoints == null
                ? draft
                : PolygonDraft(draft?.regionId, _dragPoints!),
            activePoint: _activePoint,
            onDown: _onDown,
            onMove: _onMove,
            onUp: _onUp,
            onCancel: () {
              _pointers.clear();
              _clearPointer();
            },
          )),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: const Color(0xE6262A42),
              borderRadius: BorderRadius.circular(24),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: _moving ? '恢复标注' : '单指移动画布',
                  color: Colors.white,
                  isSelected: _moving,
                  selectedIcon: const Icon(Icons.pan_tool),
                  onPressed: () {
                    _clearPointer();
                    setState(() => _moving = !_moving);
                  },
                  icon: const Icon(Icons.pan_tool_outlined),
                ),
                IconButton(
                  tooltip: '重置缩放',
                  color: Colors.white,
                  onPressed: () => _transform.value = Matrix4.identity(),
                  icon: const Icon(Icons.fit_screen),
                ),
              ]),
            ),
          ),
        ],
      );

  Widget _panelHeader(String title,
          {required bool collapsed, bool landscape = false}) =>
      ListTile(
        dense: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: landscape
            ? null
            : IconButton(
                tooltip: collapsed ? '展开编辑面板' : '收起编辑面板',
                onPressed: () => setState(() => _collapsed = !collapsed),
                icon: Icon(collapsed ? Icons.expand_less : Icons.expand_more),
              ),
      );

  Widget _buildPanel(PolygonDraft? draft, {required bool landscape}) {
    final selected = _selected;
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _panelHeader(draft == null ? '编辑面板' : '绘制区域',
            collapsed: false, landscape: landscape),
        if (_saveError)
          ListTile(
            title: const Text('无法保存更改'),
            trailing: TextButton(
                onPressed: () {
                  setState(() => _saveError = false);
                  _saveTask ??= _saveEdits();
                },
                child: const Text('重试')),
          ),
        if (_run != null)
          ListTile(
            leading: const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2)),
            title: const Text('正在设备上识别…'),
            trailing: TextButton(
                onPressed: () => _cancelRecognition(announce: true),
                child: const Text('取消')),
          ),
        if (_status case final status?)
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Semantics(liveRegion: true, child: Text(status))),
        if (draft != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_moving
                ? '移动模式已开启，关闭后可继续绘制。'
                : '轻点添加顶点，拖动顶点调整轮廓。已添加 ${draft.points.length} 个。'),
          ),
          _buttons([
            FilledButton(
                onPressed: draft.points.length < 3 ? null : _savePolygon,
                child: const Text('保存轮廓')),
            OutlinedButton(
                onPressed: draft.points.isEmpty ? null : _removePoint,
                child: Text(_activePoint == null ? '删除最后一点' : '删除所选点')),
            TextButton(
                onPressed: () => _change(_edits.withDraft(null)),
                child: const Text('取消绘制')),
          ]),
        ] else ...[
          _buttons([
            FilledButton.tonalIcon(
                onPressed: _run == null ? _recognize : null,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('本机 AI 识别')),
            OutlinedButton.icon(
                onPressed: _run == null ? () => _startPolygon(null) : null,
                icon: const Icon(Icons.add),
                label: const Text('手动画区域')),
            if (_edits.lastAnalysisId != null)
              PopupMenuButton<String>(
                tooltip: '识别结果选项',
                enabled: _run == null,
                onSelected: (choice) {
                  if (choice == 'target') {
                    _chooseAnotherTarget();
                  } else {
                    _change(_edits.resetRecognition());
                    _showStatus('已重置未编辑的 AI 候选。');
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'target', child: Text('重新选择目标')),
                  PopupMenuItem(value: 'reset', child: Text('重置 AI 候选')),
                ],
              ),
          ]),
          if (_regions.isEmpty && _run == null)
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('先识别可见人体部位，或手动画出人物、物品的位置。')),
          if (selected != null && _run == null) ...[
            ListTile(
              title: Text(selected.label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(_regionDetails(selected)),
            ),
            _buttons([
              FilledButton.tonal(
                  onPressed: () => _editRules(selected),
                  child: const Text('手势与反馈')),
              OutlinedButton(
                  onPressed: () => _startPolygon(selected),
                  child: const Text('调整轮廓')),
              if (selected.source.isAutomatic)
                TextButton(
                    onPressed: () => _setRegion(
                        selected.copyWith(source: RegionSource.confirmed)),
                    child: const Text('确认区域')),
              TextButton(
                  onPressed: () => _deleteRegion(selected),
                  child: const Text('删除区域')),
            ]),
          ],
          for (final group in RegionGroup.values)
            if (_regions.any((region) => region.group == group))
              ExpansionTile(
                initiallyExpanded: true,
                title: Text(group.label),
                children: [
                  for (final region
                      in _regions.where((region) => region.group == group))
                    ListTile(
                      selected: region.id == _selectedId,
                      contentPadding: EdgeInsets.only(
                          left: region.parentId == null ? 22 : 36, right: 16),
                      title: Text(region.label),
                      subtitle: Text(_regionDetails(region)),
                      onTap: _run != null
                          ? null
                          : () => setState(() => _selectedId = region.id),
                    ),
                ],
              ),
        ],
      ],
    );
  }

  Widget _buttons(List<Widget> children) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Wrap(spacing: 8, runSpacing: 4, children: children),
      );

  String _regionDetails(ImageRegion region) => [
        region.source.label,
        if (region.confidence case final score?)
          '置信度 ${(score * 100).round()}%',
        if (region.confidence == null && region.source.isAutomatic)
          '模型未提供部位置信度',
        if (!region.enabled)
          '已停用'
        else if (region.rules.isNotEmpty)
          '${region.rules.length} 个手势',
      ].join(' · ');
}
