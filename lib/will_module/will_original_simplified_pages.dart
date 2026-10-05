
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/read_aloud_service.dart';
import 'will_models.dart';
import 'will_unit_index_seed.dart';
import 'will_original_precise_segments.dart';

class WillOriginalSimplifiedReaderPage extends StatefulWidget {
  final String? initialUnitId;
  final ValueChanged<WillUnitIndex>? onOpenUnit;

  const WillOriginalSimplifiedReaderPage({
    super.key,
    this.initialUnitId,
    this.onOpenUnit,
  });

  @override
  State<WillOriginalSimplifiedReaderPage> createState() => _WillOriginalSimplifiedReaderPageState();
}

class _WillOriginalSimplifiedReaderPageState extends State<WillOriginalSimplifiedReaderPage> {
  late Future<String> _future;
  late String _selectedModuleCode;
  final TextEditingController _searchController = TextEditingController();
  final ReadAloudService _readAloudService = ReadAloudService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<void>? _playerCompleteSubscription;
  List<String> _audioQueue = const [];
  int _audioQueueIndex = 0;
  int _readRequestId = 0;
  String? _activeReadSectionCode;
  bool _preparingAudio = false;
  String _search = '';
  bool _onlyPrecise = false;

  static const List<_ReaderSection> _sections = [
    _ReaderSection(code: 'D', title: '导论', marker: 'Chapter 26 意志｜导论'),
    _ReaderSection(code: 'I', title: '观念—运动作用', marker: '小节1：Ideo-Motor Action'),
    _ReaderSection(code: 'A', title: '审议/权衡后的行动', marker: '小节2：Action After Deliberation'),
    _ReaderSection(code: 'T', title: '决定的五种类型', marker: '小节3：Five Types of Decision'),
    _ReaderSection(code: 'E', title: '努力感', marker: '小节4：The Feeling of Effort'),
    _ReaderSection(code: 'X', title: '爆发型意志', marker: '小节5：The Explosive Will'),
    _ReaderSection(code: 'O', title: '阻塞型意志', marker: 'The Obstructed Will'),
    _ReaderSection(code: 'P', title: '快乐与痛苦作为行动的动力', marker: '小节6：Pleasure and Pain as Springs of Action'),
    _ReaderSection(code: 'R', title: '意志是心灵与其“观念”之间的关系', marker: '小节7：Will is a Relation Between the Mind and its “Ideas”'),
    _ReaderSection(code: 'F', title: '自由意志问题', marker: '小节8：The Question of “Free-Will.”'),
    _ReaderSection(code: 'W', title: '意志的教育', marker: '小节9：The Education of the Will'),
  ];

  @override
  void initState() {
    super.initState();
    _future = rootBundle.loadString('assets/will/ch26_simplified_full.txt');
    _selectedModuleCode = _unitById(widget.initialUnitId)?.moduleCode ?? 'D';
    _searchController.addListener(() {
      if (_search != _searchController.text.trim()) {
        setState(() => _search = _searchController.text.trim());
      }
    });
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      _playNextAudioChunk();
    });
  }

  @override
  void dispose() {
    _readRequestId++;
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _readSection(String fullText, _ReaderSection section) async {
    if (_activeReadSectionCode == section.code) {
      await _stopReading();
      return;
    }
    final requestId = ++_readRequestId;
    await _audioPlayer.stop();
    if (!mounted) return;
    setState(() {
      _activeReadSectionCode = section.code;
      _preparingAudio = true;
      _audioQueue = const [];
      _audioQueueIndex = 0;
    });
    try {
      final availability = await _readAloudService.availability();
      if (!availability.available) throw StateError(availability.reason);
      final files = await _readAloudService.synthesize(
        text: _excerptForModule(fullText, section.code),
        moduleName: 'will_original_${section.code.toLowerCase()}',
      );
      if (!mounted || requestId != _readRequestId) return;
      setState(() {
        _preparingAudio = false;
        _audioQueue = files;
        _audioQueueIndex = 0;
      });
      if (files.isNotEmpty) await _audioPlayer.play(DeviceFileSource(files.first));
    } catch (e) {
      if (!mounted || requestId != _readRequestId) return;
      setState(() {
        _preparingAudio = false;
        _activeReadSectionCode = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyReadError(e))),
      );
    }
  }

  Future<void> _playNextAudioChunk() async {
    if (!mounted || _activeReadSectionCode == null) return;
    final next = _audioQueueIndex + 1;
    if (next >= _audioQueue.length) {
      setState(() {
        _activeReadSectionCode = null;
        _audioQueue = const [];
        _audioQueueIndex = 0;
      });
      return;
    }
    setState(() => _audioQueueIndex = next);
    await _audioPlayer.play(DeviceFileSource(_audioQueue[next]));
  }

  Future<void> _stopReading() async {
    _readRequestId++;
    await _audioPlayer.stop();
    if (!mounted) return;
    setState(() {
      _activeReadSectionCode = null;
      _preparingAudio = false;
      _audioQueue = const [];
      _audioQueueIndex = 0;
    });
  }

  String _friendlyReadError(Object error) {
    final value = error.toString();
    return value.startsWith('Bad state: ') ? value.substring('Bad state: '.length) : '朗读失败：$value';
  }

  WillUnitIndex? _unitById(String? id) {
    if (id == null) return null;
    for (final unit in kWillUnitIndexSeed) {
      if (unit.id == id) return unit;
    }
    return null;
  }

  String? _preciseSegmentForUnit(String? id) => id == null ? null : kWillOriginalPreciseSegments[id];

  List<WillUnitIndex> _preciseUnitsForModule(String code) {
    final ids = kWillOriginalPreciseSegments.keys.toSet();
    return _moduleUnits(code).where((u) => ids.contains(u.id)).toList();
  }


  Future<void> _copyAll(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制这份原文简化版全文。')),
    );
  }

  Future<void> _copyExcerpt(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制当前模块正文节选。')),
    );
  }

  String _excerptForModule(String text, String code) {
    final index = _sections.indexWhere((e) => e.code == code);
    if (index < 0) return text;
    final start = text.indexOf(_sections[index].marker);
    if (start < 0) return text;
    int end = text.length;
    for (int i = index + 1; i < _sections.length; i++) {
      final p = text.indexOf(_sections[i].marker, start + 1);
      if (p > start) {
        end = p;
        break;
      }
    }
    return text.substring(start, end).trim();
  }

  List<WillUnitIndex> _moduleUnits(String code) {
    return kWillUnitIndexSeed.where((u) => u.moduleCode == code).toList();
  }

  List<WillUnitIndex> _nearbyUnits(String code, String? focusId) {
    final units = _moduleUnits(code);
    if (focusId == null) {
      return units.take(8).toList();
    }
    final idx = units.indexWhere((u) => u.id == focusId);
    if (idx < 0) return units.take(8).toList();
    final start = (idx - 3).clamp(0, units.length);
    final end = (idx + 5).clamp(0, units.length);
    return units.sublist(start, end);
  }

  List<WillUnitIndex> _filteredUnits(List<WillUnitIndex> units) {
    final q = _search.trim().toLowerCase();
    return units.where((u) {
      final preciseOk = !_onlyPrecise || kWillOriginalPreciseSegments.containsKey(u.id);
      final queryOk = q.isEmpty ||
          u.id.toLowerCase().contains(q) ||
          u.title.toLowerCase().contains(q) ||
          u.oneLiner.toLowerCase().contains(q) ||
          u.tags.any((t) => t.toLowerCase().contains(q));
      return preciseOk && queryOk;
    }).toList();
  }

  void _openUnit(WillUnitIndex unit) {
    if (widget.onOpenUnit != null) {
      widget.onOpenUnit!(unit);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已选中 ${unit.id}，当前入口未提供跳转处理。')),
    );
  }

  int _moduleIndex(String code) => _sections.indexWhere((e) => e.code == code);

  void _moveModule(int offset) {
    final idx = _moduleIndex(_selectedModuleCode);
    final next = idx + offset;
    if (next >= 0 && next < _sections.length) {
      setState(() => _selectedModuleCode = _sections[next].code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final focusUnit = _unitById(widget.initialUnitId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('原文简化版全文'),
        actions: [
          if (_activeReadSectionCode != null)
            IconButton(
              tooltip: _preparingAudio ? '正在生成语音，点击取消' : '停止朗读',
              onPressed: _stopReading,
              icon: Icon(_preparingAudio ? Icons.hourglass_top_rounded : Icons.stop_circle_outlined),
            ),
          FutureBuilder<String>(
            future: _future,
            builder: (context, snapshot) {
              final text = snapshot.data;
              return IconButton(
                tooltip: '复制全文',
                onPressed: text == null ? null : () => _copyAll(text),
                icon: const Icon(Icons.copy_all_outlined),
              );
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: FutureBuilder<String>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('加载失败：${snapshot.error}'),
              ),
            );
          }
          final text = snapshot.data ?? '';
          final excerpt = _excerptForModule(text, _selectedModuleCode);
          final moduleUnits = _moduleUnits(_selectedModuleCode);
          final preciseFocusExcerpt = _preciseSegmentForUnit(widget.initialUnitId);
          final preciseModuleUnits = _preciseUnitsForModule(_selectedModuleCode);
          final nearby = _nearbyUnits(_selectedModuleCode, widget.initialUnitId);
          final relatedUnits = _filteredUnits(nearby);
          final allModuleUnits = _filteredUnits(moduleUnits);
          final section = _sections.firstWhere((e) => e.code == _selectedModuleCode, orElse: () => _sections.first);
          final idx = _moduleIndex(_selectedModuleCode);
          final prevSection = idx > 0 ? _sections[idx - 1] : null;
          final nextSection = idx < _sections.length - 1 ? _sections[idx + 1] : null;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Card(
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '按你提供的版本原样整合',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '这一页保留你前面发来的《The Principles of Psychology》第26章〈Will〉中文简化版正文，并把它与 209 单元详情页做了双向联动：你可以从单元跳到对应模块正文，也可以从正文跳回相关单元。',
                      style: TextStyle(height: 1.6, color: Color(0xFF5F6673)),
                    ),
                  ],
                ),
              ),
              if (focusUnit != null) ...[
                const SizedBox(height: 12),
                _TintCard(
                  color: const Color(0xFFEFF6FF),
                  borderColor: const Color(0xFFBFDBFE),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.push_pin_outlined, size: 18, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Text('当前对应知识单元', style: TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${focusUnit.id} · ${focusUnit.title}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(focusUnit.oneLiner, style: const TextStyle(height: 1.6, color: Color(0xFF334155))),
                      const SizedBox(height: 8),
                      Text('已为你定位到「${section.title}」对应正文段；下面的相关单元列表也会优先高亮当前单元。', style: const TextStyle(height: 1.6, color: Color(0xFF475569))),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: () => _openUnit(focusUnit),
                          icon: const Icon(Icons.undo_outlined),
                          label: const Text('回到单元'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (focusUnit != null && preciseFocusExcerpt != null) ...[
                const SizedBox(height: 12),
                _TintCard(
                  color: const Color(0xFFFFF7ED),
                  borderColor: const Color(0xFFFED7AA),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('该知识单元对应的精细正文片段', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text('${focusUnit.id} · ${focusUnit.title}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      SelectableText(
                        preciseFocusExcerpt,
                        style: const TextStyle(fontSize: 14.5, height: 1.7, color: Color(0xFF7C2D12)),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _copyExcerpt(preciseFocusExcerpt),
                            icon: const Icon(Icons.copy_outlined),
                            label: const Text('复制该单元片段'),
                          ),
                          TextButton.icon(
                            onPressed: () => setState(() => _selectedModuleCode = focusUnit.moduleCode),
                            icon: const Icon(Icons.anchor_outlined),
                            label: Text('定位到 ${focusUnit.moduleCode} 模块正文'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('正文模块目录', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              showDragHandle: true,
                              builder: (context) => SafeArea(
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _sections.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final s = _sections[i];
                                    final selected = s.code == _selectedModuleCode;
                                    return ListTile(
                                      title: Text('${s.code} · ${s.title}'),
                                      subtitle: Text('相关单元：${_moduleUnits(s.code).length}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (selected) const Icon(Icons.check_circle, color: Color(0xFF2563EB)),
                                          IconButton(
                                            tooltip: _activeReadSectionCode == s.code ? '停止朗读' : '朗读“${s.title}”',
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _readSection(text, s);
                                            },
                                            icon: Icon(
                                              _activeReadSectionCode == s.code ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                                              color: _activeReadSectionCode == s.code ? const Color(0xFFDC2626) : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        setState(() => _selectedModuleCode = s.code);
                                      },
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.menu_book_outlined),
                          label: const Text('目录'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _sections.map((s) {
                          final selected = s.code == _selectedModuleCode;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('${s.code} · ${s.title}'),
                              selected: selected,
                              onSelected: (_) => setState(() => _selectedModuleCode = s.code),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ReaderModuleTile(
                      section: section,
                      unitCount: moduleUnits.length,
                      preciseCount: preciseModuleUnits.length,
                      isCurrent: true,
                    ),
                    const SizedBox(height: 8),
                    if (prevSection != null || nextSection != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (prevSection != null)
                            OutlinedButton.icon(
                              onPressed: () => _moveModule(-1),
                              icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                              label: Text('上一模块 · ${prevSection.title}'),
                            ),
                          if (nextSection != null)
                            OutlinedButton.icon(
                              onPressed: () => _moveModule(1),
                              icon: const Icon(Icons.arrow_forward_ios, size: 16),
                              label: Text('下一模块 · ${nextSection.title}'),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('当前模块正文节选 · ${section.title}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        ),
                        TextButton.icon(
                          onPressed: () => _readSection(text, section),
                          icon: _preparingAudio && _activeReadSectionCode == section.code
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(_activeReadSectionCode == section.code ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
                          label: Text(_activeReadSectionCode == section.code ? '停止' : '朗读'),
                        ),
                        TextButton.icon(
                          onPressed: () => _copyExcerpt(excerpt),
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('复制节选'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('锚点：${section.marker}', style: const TextStyle(color: Color(0xFF6B7280))),
                    const SizedBox(height: 12),
                    SelectableText(
                      excerpt,
                      style: const TextStyle(fontSize: 14.5, height: 1.7),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('从正文跳回相关单元', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text(
                      '先展示当前模块的相关单元。若你是从某个单元跳转而来，会优先展示它附近的单元；你也可以输入关键词筛选当前模块全部单元。',
                      style: TextStyle(height: 1.6, color: Color(0xFF5F6673)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '搜索单元 ID / 标题 / 关键词',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => _searchController.clear(),
                                icon: const Icon(Icons.close),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilterChip(
                          label: const Text('只看有精细片段'),
                          selected: _onlyPrecise,
                          onSelected: (v) => setState(() => _onlyPrecise = v),
                        ),
                        const SizedBox(width: 8),
                        Text('本模块已有精细片段单元：${preciseModuleUnits.length}', style: const TextStyle(color: Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (preciseModuleUnits.isNotEmpty) ...[
                      const Text('本模块精细片段锚点', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: preciseModuleUnits.take(12).map((u) => ActionChip(
                          avatar: const Icon(Icons.bookmark_added_outlined, size: 18),
                          label: Text('${u.id} ${u.title}'),
                          onPressed: () => _openUnit(u),
                        )).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (relatedUnits.isNotEmpty) ...[
                      const Text('优先相关单元', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: relatedUnits.map((u) {
                          final focus = u.id == widget.initialUnitId;
                          final precise = kWillOriginalPreciseSegments.containsKey(u.id);
                          return ActionChip(
                            avatar: focus
                                ? const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF2563EB))
                                : (precise ? const Icon(Icons.bookmark_added_outlined, size: 16, color: Color(0xFFEA580C)) : null),
                            backgroundColor: focus ? const Color(0xFFEFF6FF) : (precise ? const Color(0xFFFFF7ED) : null),
                            side: BorderSide(color: focus ? const Color(0xFFBFDBFE) : (precise ? const Color(0xFFFED7AA) : const Color(0xFFE5E7EB))),
                            label: Text('${u.id} ${u.title}', style: TextStyle(fontWeight: focus ? FontWeight.w800 : FontWeight.w600, color: focus ? const Color(0xFF1D4ED8) : null)),
                            onPressed: () => _openUnit(u),
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      const Text('没有命中优先相关单元，可以看下面的全部模块单元。', style: TextStyle(color: Color(0xFF6B7280))),
                    ],
                    const SizedBox(height: 12),
                    Text('本模块全部相关单元（${allModuleUnits.length} / ${moduleUnits.length}）', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: allModuleUnits.take(12).length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final u = allModuleUnits[index];
                          final focus = u.id == widget.initialUnitId;
                          final precise = kWillOriginalPreciseSegments.containsKey(u.id);
                          return Container(
                            decoration: BoxDecoration(
                              color: focus ? const Color(0xFFEFF6FF) : null,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: focus ? const Color(0xFFBFDBFE) : Colors.transparent),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              title: Row(children: [
                                if (focus) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF2563EB))),
                                Expanded(child: Text('${u.id} · ${u.title}', style: TextStyle(fontWeight: focus ? FontWeight.w800 : FontWeight.w600, color: focus ? const Color(0xFF1D4ED8) : null))),
                                if (precise) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.bookmark_added_outlined, size: 16, color: Color(0xFFEA580C)))
                              ]),
                              subtitle: Text(focus ? '当前对应单元 · ${u.oneLiner}' : u.oneLiner, maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openUnit(u),
                            ),
                          );
                        },
                      ),
                    ),
                    if (allModuleUnits.length > 12) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              showDragHandle: true,
                              builder: (context) => SafeArea(
                                child: DraggableScrollableSheet(
                                  expand: false,
                                  initialChildSize: 0.75,
                                  maxChildSize: 0.95,
                                  minChildSize: 0.4,
                                  builder: (context, controller) => ListView.separated(
                                    controller: controller,
                                    padding: const EdgeInsets.all(16),
                                    itemCount: allModuleUnits.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final u = allModuleUnits[index];
                                      final focus = u.id == widget.initialUnitId;
                                      return ListTile(
                                        tileColor: focus ? const Color(0xFFEFF6FF) : null,
                                        title: Row(children: [
                                          if (focus) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF2563EB))),
                                          Expanded(child: Text('${u.id} · ${u.title}', style: TextStyle(fontWeight: focus ? FontWeight.w800 : FontWeight.w600, color: focus ? const Color(0xFF1D4ED8) : null))),
                                          if (kWillOriginalPreciseSegments.containsKey(u.id)) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.bookmark_added_outlined, size: 16, color: Color(0xFFEA580C)))
                                        ]),
                                        subtitle: Text(focus ? '当前对应单元 · ${u.oneLiner}' : u.oneLiner),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _openUnit(u);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.list_alt_outlined),
                          label: const Text('展开本模块全部单元'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('查看整章全文（原样保留）', style: TextStyle(fontWeight: FontWeight.w800)),
                childrenPadding: EdgeInsets.zero,
                children: [
                  _Card(
                    child: SelectableText(
                      text,
                      style: const TextStyle(fontSize: 14.5, height: 1.7),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReaderSection {
  final String code;
  final String title;
  final String marker;

  const _ReaderSection({
    required this.code,
    required this.title,
    required this.marker,
  });
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: child,
    );
  }
}

class _TintCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color borderColor;

  const _TintCard({
    required this.child,
    required this.color,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _ReaderModuleTile extends StatelessWidget {
  final _ReaderSection section;
  final int unitCount;
  final int preciseCount;
  final bool isCurrent;

  const _ReaderModuleTile({
    required this.section,
    required this.unitCount,
    required this.preciseCount,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isCurrent ? const Color(0xFFBFDBFE) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              section.code,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('锚点：${section.marker}\n相关单元：$unitCount · 精细片段：$preciseCount', style: const TextStyle(height: 1.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
