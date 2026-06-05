import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'behavior_tracking_dao.dart';
import 'behavior_tracking_models.dart';

class BehaviorTrackingHomePage extends StatefulWidget {
  const BehaviorTrackingHomePage({super.key});

  @override
  State<BehaviorTrackingHomePage> createState() => _BehaviorTrackingHomePageState();
}

class _BehaviorTrackingHomePageState extends State<BehaviorTrackingHomePage> {
  final BehaviorTrackingDao _dao = BehaviorTrackingDao();
  List<BehaviorTrackingRecord> _records = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final records = await _dao.recent(limit: 260);
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<BehaviorTrackingRecord> get _todayRecords {
    final now = DateTime.now();
    return _records.where((r) {
      final d = r.recordDate;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();
  }

  int get _todayTrackedMinutes => _todayRecords.fold<int>(0, (sum, r) => sum + (r.durationMinutes ?? 0));


  Future<void> _openQuickCapture() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _QuickCaptureSheet(),
    );
    if (saved == true) _load();
  }

  Future<void> _openExportDialog() async {
    final format = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('导出与本地备份', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('导出在本地生成。情绪、认知、健康与位置线索可能属于敏感信息，请只保存到可信位置。', style: TextStyle(color: Color(0xFF6B7280), height: 1.5)),
            const SizedBox(height: 12),
            ListTile(leading: const Icon(Icons.data_object_outlined), title: const Text('JSON 完整迁移包'), subtitle: const Text('含 schema_version、模板与记录'), onTap: () => Navigator.pop(ctx, 'json')),
            ListTile(leading: const Icon(Icons.table_chart_outlined), title: const Text('CSV 表格分析'), subtitle: const Text('适合 Excel / Numbers'), onTap: () => Navigator.pop(ctx, 'csv')),
            ListTile(leading: const Icon(Icons.article_outlined), title: const Text('Markdown 复盘归档'), subtitle: const Text('适合长期日记归档'), onTap: () => Navigator.pop(ctx, 'md')),
          ]),
        ),
      ),
    );
    if (format == null) return;
    String text;
    if (format == 'json') {
      text = await _dao.exportJson(days: 90);
    } else if (format == 'csv') {
      text = await _dao.exportCsv(days: 90);
    } else {
      text = await _dao.exportMarkdown(days: 30);
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${format.toUpperCase()} 已复制到剪贴板，可粘贴保存为文件')));
  }

  Future<void> _openEditor({BehaviorTrackingRecord? record, String? mode, String? layer}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BehaviorTrackingEditPage(
          initial: record ?? BehaviorTrackingRecord.blank(mode: mode ?? 'full_observation', primaryLayer: layer ?? '时间层面'),
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _openReview() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BehaviorTrackingReviewPage()));
    _load();
  }

  Future<void> _deleteRecord(BehaviorTrackingRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条行为记录？'),
        content: Text(record.title.isEmpty ? record.oneLineSummary : record.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true && record.id != null) {
      await _dao.delete(record.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('行为跟踪', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _openExportDialog, icon: const Icon(Icons.ios_share_outlined), tooltip: '导出'),
          IconButton(onPressed: _openReview, icon: const Icon(Icons.insights_outlined), tooltip: '复盘'),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: '刷新'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openQuickCapture,
        icon: const Icon(Icons.flash_on_outlined),
        label: const Text('快速记录'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                children: [
                  _HeroCard(
                    todayCount: _todayRecords.length,
                    todayMinutes: _todayTrackedMinutes,
                    onQuick: _openQuickCapture,
                    onDaily: () => _openEditor(mode: 'daily_template', layer: '每日6项'),
                    onTbr: () => _openEditor(mode: 'trigger_behavior_result', layer: '触发—行为—结果'),
                    onReview: _openReview,
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle(title: '七个可跟踪层面', actionText: '从一个层面开始即可'),
                  const SizedBox(height: 8),
                  _LayerGrid(onTap: (layer) => _openEditor(mode: layer.mode, layer: layer.name)),
                  const SizedBox(height: 14),
                  _SectionTitle(title: '统一模板系统', actionText: '模板 = 字段组合 + 入口 + 补全规则'),
                  const SizedBox(height: 8),
                  const _TemplateSystemCard(),
                  const SizedBox(height: 14),
                  _SectionTitle(title: '常用记录方法', actionText: '日记 / 打卡 / 时间块 / TBR / 数据工具'),
                  const SizedBox(height: 8),
                  _MethodCards(onSelect: (mode, layer) => _openEditor(mode: mode, layer: layer)),
                  const SizedBox(height: 14),
                  _SectionTitle(title: '最近记录', actionText: _records.isEmpty ? '暂无' : '${_records.length} 条'),
                  const SizedBox(height: 8),
                  if (_records.isEmpty) const _EmptyRecordsCard(),
                  for (final record in _records.take(30))
                    _BehaviorRecordCard(
                      record: record,
                      onTap: () => _openEditor(record: record),
                      onDelete: () => _deleteRecord(record),
                    ),
                ],
              ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final int todayCount;
  final int todayMinutes;
  final VoidCallback onQuick;
  final VoidCallback onDaily;
  final VoidCallback onTbr;
  final VoidCallback onReview;

  const _HeroCard({required this.todayCount, required this.todayMinutes, required this.onQuick, required this.onDaily, required this.onTbr, required this.onReview});

  @override
  Widget build(BuildContext context) {
    final hours = todayMinutes ~/ 60;
    final mins = todayMinutes % 60;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF111827), Color(0xFF4F46E5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x22111827), blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.route_outlined, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('本地优先的行为证据系统', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text('秒级快记、标准记录、晚间复盘：先留下事实，再逐层补全。', style: TextStyle(color: Color(0xFFE0E7FF), height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _HeroMetric(label: '今日记录', value: '$todayCount 条')),
              const SizedBox(width: 10),
              Expanded(child: _HeroMetric(label: '已标记时间', value: todayMinutes == 0 ? '未开始' : '${hours}h ${mins}m')),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroAction(label: '秒级快记', icon: Icons.flash_on_outlined, onTap: onQuick),
              _HeroAction(label: '每日6项', icon: Icons.today_outlined, onTap: onDaily),
              _HeroAction(label: '触发链', icon: Icons.account_tree_outlined, onTap: onTbr),
              _HeroAction(label: '复盘', icon: Icons.insights_outlined, onTap: onReview),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  const _HeroMetric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.13), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.18))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Color(0xFFC7D2FE), fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _HeroAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _HeroAction({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 17, color: const Color(0xFF4338CA)), const SizedBox(width: 6), Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4338CA)))]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String actionText;
  const _SectionTitle({required this.title, required this.actionText});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF111827)))),
        Text(actionText, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _LayerGrid extends StatelessWidget {
  final ValueChanged<BehaviorLayerInfo> onTap;
  const _LayerGrid({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final twoColumns = constraints.maxWidth > 520;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: behaviorLayerInfos.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: twoColumns ? 2 : 1,
          mainAxisExtent: 108,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (_, i) {
          final layer = behaviorLayerInfos[i];
          return InkWell(
            onTap: () => onTap(layer),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: const Color(0xFFEEF2FF), child: Text('${i + 1}', style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w900))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(layer.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(layer.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(layer.example, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}

class _MethodCards extends StatelessWidget {
  final void Function(String mode, String layer) onSelect;
  const _MethodCards({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final methods = <({String title, String sub, IconData icon, String mode, String layer})>[
      (title: '日记法', sub: '今天做了什么？哪个行为要保留？明天只改一点。', icon: Icons.edit_note_outlined, mode: 'daily_template', layer: '每日6项'),
      (title: '时间块记录', sub: '按 8:00–9:00 这样的时间段看清时间流向。', icon: Icons.view_timeline_outlined, mode: 'time_block', layer: '时间层面'),
      (title: '触发—行为—结果', sub: '特别适合拖延、熬夜、刷手机、冲动消费。', icon: Icons.account_tree_outlined, mode: 'trigger_behavior_result', layer: '触发—行为—结果'),
      (title: '打卡法', sub: '用简单记录观察早起、运动、阅读、少刷手机。', icon: Icons.check_circle_outline, mode: 'behavior', layer: '行为层面'),
      (title: '数据工具法', sub: '睡眠、步数、番茄钟等先给摘要，确认后再入库。', icon: Icons.health_and_safety_outlined, mode: 'body', layer: '身体状态'),
    ];
    return Column(
      children: methods.map((m) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => onSelect(m.mode, m.layer),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)), child: Icon(m.icon, color: const Color(0xFF111827))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(m.sub, style: const TextStyle(color: Color(0xFF6B7280), height: 1.35))])),
                const Icon(Icons.add_circle_outline, color: Color(0xFF4F46E5)),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}


class _TemplateSystemCard extends StatelessWidget {
  const _TemplateSystemCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('一个核心记录对象 + 七层可选快照', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('所有入口最终写入同一套本地记录：时间、行为、情绪、认知、结果、环境、身体状态。拒绝非必要权限也不影响手工记录。', style: TextStyle(color: Color(0xFF4B5563), height: 1.5)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: behaviorTrackingTemplates.map((template) => Tooltip(
            message: template.description,
            child: Chip(
              label: Text(template.name),
              avatar: const Icon(Icons.schema_outlined, size: 16),
              backgroundColor: const Color(0xFFF8FAFC),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          )).toList(),
        ),
      ]),
    );
  }
}

class _QuickCaptureSheet extends StatefulWidget {
  const _QuickCaptureSheet();

  @override
  State<_QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends State<_QuickCaptureSheet> {
  final BehaviorTrackingDao _dao = BehaviorTrackingDao();
  final TextEditingController _behavior = TextEditingController();
  final TextEditingController _minutes = TextEditingController(text: '25');
  final TextEditingController _note = TextEditingController();
  String _mode = 'behavior';
  String _emotion = '';
  String _trigger = '';
  int _intensity = 5;
  bool _saving = false;

  @override
  void dispose() {
    _behavior.dispose();
    _minutes.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save({bool openFull = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final minutes = int.tryParse(_minutes.text.trim());
    final layer = _mode == 'emotion' ? '情绪层面' : _mode == 'trigger_behavior_result' ? '触发—行为—结果' : _mode == 'time_block' ? '时间层面' : '行为层面';
    final record = BehaviorTrackingRecord.blank(mode: _mode, primaryLayer: layer).copyWith(
      title: _behavior.text.trim().ifBlank(layer),
      behavior: _behavior.text.trim(),
      emotion: _emotion,
      emotionIntensity: _emotion.isEmpty ? null : _intensity,
      clearEmotionIntensity: _emotion.isEmpty,
      trigger: _trigger,
      notes: _note.text.trim(),
      category: _mode == 'time_block' ? '工作/学习' : '',
      startMinute: minutes == null ? null : ((now.hour * 60 + now.minute - minutes) % (24 * 60)),
      endMinute: minutes == null ? null : now.hour * 60 + now.minute,
      clearStartMinute: minutes == null,
      clearEndMinute: minutes == null,
      entryMode: 'quick_capture',
      source: 'manual',
      privacyLevel: _emotion.isEmpty ? 'local_first' : 'sensitive_local_first',
      tags: [_trigger, _emotion, layer].where((e) => e.trim().isNotEmpty).toList(),
    );
    try {
      await _dao.save(record);
      if (!mounted) return;
      Navigator.pop(context, true);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 14),
              const Text('记录一下', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('5–15 秒先留下事实，今晚或明天再补原因和长期影响。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _QuickChoice(label: '时间块', selected: _mode == 'time_block', onTap: () => setState(() => _mode = 'time_block')),
                _QuickChoice(label: '行为', selected: _mode == 'behavior', onTap: () => setState(() => _mode = 'behavior')),
                _QuickChoice(label: '情绪', selected: _mode == 'emotion', onTap: () => setState(() => _mode = 'emotion')),
                _QuickChoice(label: '失控了', selected: _mode == 'trigger_behavior_result', onTap: () => setState(() => _mode = 'trigger_behavior_result')),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _behavior, decoration: const InputDecoration(labelText: '我刚刚', hintText: '例如：刷短视频 / 完成报告 / 焦虑回避', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: _minutes, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '时长 min', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: DropdownButtonFormField<String>(value: _emotion.isEmpty ? null : _emotion, decoration: const InputDecoration(labelText: '情绪', border: OutlineInputBorder()), items: const ['焦虑', '平静', '疲惫', '开心', '沮丧', '愤怒'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _emotion = v ?? ''))),
              ]),
              if (_emotion.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [const Text('强度'), Expanded(child: Slider(value: _intensity.toDouble(), min: 0, max: 10, divisions: 10, label: '$_intensity/10', onChanged: (v) => setState(() => _intensity = v.round())))]),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: ['任务太大', '无聊', '睡前', '疲劳', '被打断', '手机在手边'].map((tag) => _QuickChoice(label: tag, selected: _trigger == tag, onTap: () => setState(() => _trigger = _trigger == tag ? '' : tag))).toList()),
              const SizedBox(height: 10),
              TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: '可选备注', hintText: '只写一句也可以', border: OutlineInputBorder())),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: _saving ? null : () => _save(openFull: true), child: const Text('保存并补充更多'))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? '保存中...' : '保存'))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _QuickChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _QuickChoice({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
  }
}

class _EmptyRecordsCard extends StatelessWidget {
  const _EmptyRecordsCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.inbox_outlined, color: Color(0xFF9CA3AF), size: 34),
        SizedBox(height: 10),
        Text('还没有行为记录', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        SizedBox(height: 6),
        Text('建议先从三个问题开始：今天我做了什么？当时为什么这么做？这个行为让我变好还是变差？', style: TextStyle(color: Color(0xFF6B7280), height: 1.55)),
      ]),
    );
  }
}

class _BehaviorRecordCard extends StatelessWidget {
  final BehaviorTrackingRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _BehaviorRecordCard({required this.record, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MM/dd').format(record.recordDate);
    final title = record.title.trim().isEmpty ? record.category.ifBlank('行为记录') : record.title.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              PopupMenuButton<String>(
                onSelected: (v) { if (v == 'delete') onDelete(); },
                itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('删除'))],
              ),
            ]),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _TinyChip(text: date),
              if (record.timeRangeLabel.isNotEmpty) _TinyChip(text: record.timeRangeLabel),
              if (record.primaryLayer.trim().isNotEmpty) _TinyChip(text: record.primaryLayer),
              if (record.category.trim().isNotEmpty) _TinyChip(text: record.category),
              if (record.emotionIntensity != null) _TinyChip(text: '情绪 ${record.emotionIntensity}/10'),
            ]),
            const SizedBox(height: 10),
            Text(record.oneLineSummary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
            if (record.shortTermResult.isNotEmpty || record.longTermImpact.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
                child: Text('结果：${record.shortTermResult.ifBlank('短期未填')}｜${record.longTermImpact.ifBlank('长期未填')}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF475569), fontSize: 12, height: 1.4)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  final String text;
  const _TinyChip({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF4338CA), fontWeight: FontWeight.w800)),
    );
  }
}

class BehaviorTrackingEditPage extends StatefulWidget {
  final BehaviorTrackingRecord initial;
  const BehaviorTrackingEditPage({super.key, required this.initial});

  @override
  State<BehaviorTrackingEditPage> createState() => _BehaviorTrackingEditPageState();
}

class _BehaviorTrackingEditPageState extends State<BehaviorTrackingEditPage> {
  final BehaviorTrackingDao _dao = BehaviorTrackingDao();
  late BehaviorTrackingRecord _record;
  late DateTime _date;
  bool _saving = false;
  final Map<String, TextEditingController> _c = {};

  TextEditingController c(String key) => _c.putIfAbsent(key, () => TextEditingController());

  @override
  void initState() {
    super.initState();
    _record = widget.initial;
    _date = _record.recordDate;
    _fillControllers();
  }

  void _fillControllers() {
    c('title').text = _record.title;
    c('category').text = _record.category;
    c('start').text = _minuteLabel(_record.startMinute);
    c('end').text = _minuteLabel(_record.endMinute);
    c('behavior').text = _record.behavior;
    c('reason').text = _record.reason;
    c('outcome').text = _record.outcome;
    c('emotion').text = _record.emotion;
    c('intensity').text = _record.emotionIntensity?.toString() ?? '';
    c('trigger').text = _record.trigger;
    c('cognition').text = _record.cognition;
    c('reaction').text = _record.reaction;
    c('environment').text = _record.environment;
    c('body').text = _record.bodyState;
    c('short').text = _record.shortTermResult;
    c('long').text = _record.longTermImpact;
    c('alternative').text = _record.alternative;
    c('sleep').text = _record.sleep;
    c('important').text = _record.importantBehaviors;
    c('waste').text = _record.timeWaste;
    c('mood').text = _record.mood;
    c('tomorrow').text = _record.tomorrowAdjustment;
    c('notes').text = _record.notes;
  }

  @override
  void dispose() {
    for (final controller in _c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _minuteLabel(int? minute) {
    if (minute == null) return '';
    return '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
  }

  int? _parseMinute(String text) {
    final match = RegExp(r'^(\d{1,2})[:：](\d{1,2})$').firstMatch(text.trim());
    if (match == null) return null;
    final h = int.tryParse(match.group(1) ?? '');
    final m = int.tryParse(match.group(2) ?? '');
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return h * 60 + m;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final title = c('title').text.trim();
    final category = c('category').text.trim();
    final behavior = c('behavior').text.trim();
    final generatedTitle = title.ifBlank(behavior.ifBlank(category.ifBlank(_record.primaryLayer)));
    final intensity = int.tryParse(c('intensity').text.trim());
    final day = DateTime(_date.year, _date.month, _date.day);
    final updated = _record.copyWith(
      recordDateMs: day.millisecondsSinceEpoch,
      title: generatedTitle,
      category: category,
      startMinute: _parseMinute(c('start').text),
      endMinute: _parseMinute(c('end').text),
      clearStartMinute: _parseMinute(c('start').text) == null,
      clearEndMinute: _parseMinute(c('end').text) == null,
      behavior: behavior,
      reason: c('reason').text.trim(),
      outcome: c('outcome').text.trim(),
      emotion: c('emotion').text.trim(),
      emotionIntensity: intensity,
      clearEmotionIntensity: intensity == null,
      trigger: c('trigger').text.trim(),
      cognition: c('cognition').text.trim(),
      reaction: c('reaction').text.trim(),
      environment: c('environment').text.trim(),
      bodyState: c('body').text.trim(),
      shortTermResult: c('short').text.trim(),
      longTermImpact: c('long').text.trim(),
      alternative: c('alternative').text.trim(),
      sleep: c('sleep').text.trim(),
      importantBehaviors: c('important').text.trim(),
      timeWaste: c('waste').text.trim(),
      mood: c('mood').text.trim(),
      tomorrowAdjustment: c('tomorrow').text.trim(),
      notes: c('notes').text.trim(),
      templateKey: BehaviorTrackingTemplate.keyForMode(_record.mode),
      entryMode: _record.entryMode.isEmpty ? _record.mode : _record.entryMode,
      source: _record.source.isEmpty ? 'manual' : _record.source,
      privacyLevel: _privacyLevelFor(c('emotion').text, c('cognition').text, c('body').text, c('environment').text),
      syncState: 'local_pending',
      tags: _buildTags(category, _record.primaryLayer, c('emotion').text),
    );
    try {
      await _dao.save(updated);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
      setState(() => _saving = false);
    }
  }

  String _privacyLevelFor(String emotion, String cognition, String body, String environment) {
    if (body.trim().isNotEmpty) return 'health_sensitive_local_first';
    if (environment.trim().contains('坐标') || environment.trim().contains('定位')) return 'location_sensitive_off_by_default';
    if (emotion.trim().isNotEmpty || cognition.trim().isNotEmpty) return 'personal_sensitive_local_first';
    return 'local_first';
  }

  List<String> _buildTags(String category, String layer, String emotion) {
    return [category, layer, emotion].map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDaily = _record.mode == 'daily_template';
    final isTbr = _record.mode == 'trigger_behavior_result';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.initial.id == null ? '新增行为记录' : '编辑行为记录', style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [TextButton(onPressed: _saving ? null : _save, child: Text(_saving ? '保存中' : '保存'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        children: [
          _EditHeader(record: _record, date: _date, onPickDate: _pickDate),
          const SizedBox(height: 12),
          const _PrivacyPrincipleCard(),
          const SizedBox(height: 12),
          _InputCard(
            title: '基础信息',
            subtitle: '先把模糊感受转成可观察证据',
            children: [
              _TextFieldBox(controller: c('title'), label: '标题', hint: '例如：晚上刷短视频 3 小时 / 完成报告初稿'),
              const SizedBox(height: 10),
              _CategoryPicker(controller: c('category')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _TextFieldBox(controller: c('start'), label: '开始时间', hint: '22:00')),
                const SizedBox(width: 10),
                Expanded(child: _TextFieldBox(controller: c('end'), label: '结束时间', hint: '01:00')),
              ]),
            ],
          ),
          if (isDaily) ...[
            const SizedBox(height: 12),
            _InputCard(title: '每日6项模板', subtitle: '每天只记录这 6 项，降低坚持成本', children: [
              _TextFieldBox(controller: c('sleep'), label: '睡眠', hint: '例如：1:00–8:00，睡眠质量一般'),
              const SizedBox(height: 10),
              _TextFieldBox(controller: c('important'), label: '重要行为 1–3 件', hint: '例如：完成报告初稿；运动20分钟', maxLines: 3),
              const SizedBox(height: 10),
              _TextFieldBox(controller: c('waste'), label: '时间浪费/失控片段', hint: '例如：晚上刷视频 1.5 小时', maxLines: 2),
              const SizedBox(height: 10),
              _TextFieldBox(controller: c('mood'), label: '主要情绪', hint: '例如：下午焦虑，晚上逃避'),
              const SizedBox(height: 10),
              _TextFieldBox(controller: c('trigger'), label: '触发点', hint: '例如：任务太大，不知道从哪开始', maxLines: 2),
              const SizedBox(height: 10),
              _TextFieldBox(controller: c('tomorrow'), label: '明日调整', hint: '例如：把任务拆成 25 分钟小块', maxLines: 2),
            ]),
          ],
          if (isTbr) ...[
            const SizedBox(height: 12),
            _InputCard(title: '触发—行为—结果', subtitle: '专门分析坏习惯与替代方案', children: [
              _TextFieldBox(controller: c('trigger'), label: '触发', hint: '例如：晚上一个人无聊', maxLines: 2),
              const SizedBox(height: 10),
              _TextFieldBox(controller: c('behavior'), label: '行为', hint: '例如：刷短视频 2 小时', maxLines: 2),
              const SizedBox(height: 10),
              _TextFieldBox(controller: c('short'), label: '短期结果', hint: '例如：当下轻松', maxLines: 2),
              const SizedBox(height: 10),
              _TextFieldBox(controller: c('long'), label: '长期影响', hint: '例如：睡前后悔，第二天晚起', maxLines: 2),
              const SizedBox(height: 10),
              _TextFieldBox(controller: c('alternative'), label: '替代方案', hint: '例如：无聊时先洗澡或散步10分钟', maxLines: 2),
            ]),
          ],
          if (!isDaily && !isTbr) ...[
            const SizedBox(height: 12),
            _InputCard(title: '行为层面', subtitle: '重点不是感受，而是可观察行为', children: [
              _TextFieldBox(controller: c('behavior'), label: '我具体做了什么', hint: '例如：原计划复习1小时，实际刷短视频3小时', maxLines: 3),
              const SizedBox(height: 10),
              _TextFieldBox(controller: c('reason'), label: '我为什么这么做', hint: '例如：任务太难、想逃避、无聊、想奖励自己', maxLines: 3),
              const SizedBox(height: 10),
              _TextFieldBox(controller: c('outcome'), label: '产生了什么结果', hint: '例如：当下放松，但睡前后悔，第二天疲惫', maxLines: 3),
            ]),
            const SizedBox(height: 12),
            _InputCard(title: '情绪与认知', subtitle: '找到行为背后的触发与自动想法', children: [
              _TextFieldBox(controller: c('trigger'), label: '事件/触发点', hint: '例如：被批评 / 任务太难 / 看到任务很多', maxLines: 2),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _TextFieldBox(controller: c('emotion'), label: '情绪', hint: '焦虑/委屈/生气')),
                const SizedBox(width: 10),
                Expanded(child: _TextFieldBox(controller: c('intensity'), label: '强度0-10', hint: '8', keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              _TextFieldBox(controller: c('cognition'), label: '自动想法', hint: '例如：反正做不完 / 我肯定学不会 / 明天再说', maxLines: 3),
              const SizedBox(height: 10),
              _TextFieldBox(controller: c('reaction'), label: '反应/后续行为', hint: '例如：回避、刷手机、放弃、继续努力', maxLines: 2),
            ]),
            const SizedBox(height: 12),
            _InputCard(title: '结果、环境、身体', subtitle: '分清当下舒服与长期收益/亏损', children: [
              _TextFieldBox(controller: c('short'), label: '短期结果', hint: '例如：当下舒服、暂时逃避压力、完成后满足', maxLines: 2),
              const SizedBox(height: 10),
              _TextFieldBox(controller: c('long'), label: '长期影响', hint: '例如：第二天疲惫 / 截止前更焦虑 / 精力更好', maxLines: 2),
              const SizedBox(height: 10),
              _TextFieldBox(controller: c('environment'), label: '环境因素', hint: '例如：手机放手边、房间杂乱、身边人熬夜', maxLines: 3),
              const SizedBox(height: 10),
              _TextFieldBox(controller: c('body'), label: '身体状态', hint: '例如：睡眠不足、咖啡因多、头痛、上午精力低', maxLines: 3),
              const SizedBox(height: 10),
              _TextFieldBox(controller: c('alternative'), label: '下一次替代方案', hint: '例如：先做25分钟；手机放到另一个房间', maxLines: 2),
            ]),
          ],
          const SizedBox(height: 12),
          _InputCard(title: '补充备注', subtitle: '任何你不想丢掉的线索', children: [
            _TextFieldBox(controller: c('notes'), label: '备注', hint: '可以记录复盘想法、证据、例外情况', maxLines: 4),
          ]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
          child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? '保存中...' : '保存行为记录')),
        ),
      ),
    );
  }
}


class _PrivacyPrincipleCard extends StatelessWidget {
  const _PrivacyPrincipleCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFA7F3D0))),
      child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.lock_outline, color: Color(0xFF047857)),
        SizedBox(width: 10),
        Expanded(child: Text('本地优先：手工记录不依赖网络；健康、情绪、认知和位置线索按敏感字段处理，未来同步前需要单独确认。', style: TextStyle(color: Color(0xFF065F46), height: 1.45, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _EditHeader extends StatelessWidget {
  final BehaviorTrackingRecord record;
  final DateTime date;
  final VoidCallback onPickDate;
  const _EditHeader({required this.record, required this.date, required this.onPickDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.route_outlined, color: Color(0xFF4F46E5))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(record.primaryLayer, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('把模糊判断变成可复盘的事实证据', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ])),
        TextButton.icon(onPressed: onPickDate, icon: const Icon(Icons.calendar_today_outlined, size: 16), label: Text(DateFormat('MM/dd').format(date))),
      ]),
    );
  }
}

class _InputCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _InputCard({required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, height: 1.4)),
        const SizedBox(height: 14),
        ...children,
      ]),
    );
  }
}

class _TextFieldBox extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  const _TextFieldBox({required this.controller, required this.label, required this.hint, this.maxLines = 1, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  final TextEditingController controller;
  const _CategoryPicker({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _TextFieldBox(controller: controller, label: '类别', hint: '工作/学习、娱乐、生活事务、休息、人际、健康、自律、消费'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: behaviorCategories.map((category) => ActionChip(label: Text(category), onPressed: () => controller.text = category)).toList(),
      ),
    ]);
  }
}

class BehaviorTrackingReviewPage extends StatefulWidget {
  const BehaviorTrackingReviewPage({super.key});

  @override
  State<BehaviorTrackingReviewPage> createState() => _BehaviorTrackingReviewPageState();
}

class _BehaviorTrackingReviewPageState extends State<BehaviorTrackingReviewPage> {
  final BehaviorTrackingDao _dao = BehaviorTrackingDao();
  List<BehaviorTrackingRecord> _records = const [];
  int _days = 7;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final start = end.subtract(Duration(days: _days));
    final records = await _dao.between(start, end);
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Map<String, int> get _minutesByCategory {
    final map = <String, int>{};
    for (final r in _records) {
      final key = r.category.ifBlank('未分类');
      map[key] = (map[key] ?? 0) + (r.durationMinutes ?? 0);
    }
    return map;
  }

  double? get _avgEmotion {
    final values = _records.map((e) => e.emotionIntensity).whereType<int>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  @override
  Widget build(BuildContext context) {
    final totalMinutes = _minutesByCategory.values.fold<int>(0, (a, b) => a + b);
    final sorted = _minutesByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('行为复盘', style: TextStyle(fontWeight: FontWeight.w900)), backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                children: [
                  Row(children: [
                    ChoiceChip(label: const Text('近7天'), selected: _days == 7, onSelected: (_) { setState(() => _days = 7); _load(); }),
                    const SizedBox(width: 8),
                    ChoiceChip(label: const Text('近30天'), selected: _days == 30, onSelected: (_) { setState(() => _days = 30); _load(); }),
                    const SizedBox(width: 8),
                    ChoiceChip(label: const Text('近90天'), selected: _days == 90, onSelected: (_) { setState(() => _days = 90); _load(); }),
                  ]),
                  const SizedBox(height: 12),
                  _ReviewSummaryCard(records: _records, totalMinutes: totalMinutes, avgEmotion: _avgEmotion),
                  const SizedBox(height: 12),
                  _ReviewInsightCard(records: _records),
                  const SizedBox(height: 12),
                  _InputCard(title: '时间花在哪里', subtitle: '按类别汇总已填写开始/结束时间的记录', children: [
                    if (sorted.isEmpty) const Text('还没有可统计的时间块。', style: TextStyle(color: Color(0xFF6B7280))),
                    for (final e in sorted) _StatBar(label: e.key, value: e.value, total: totalMinutes),
                  ]),
                  const SizedBox(height: 12),
                  _InputCard(title: '长期效果与触发热力图口径', subtitle: '趋势先于评价，相关性不代表因果', children: [
                    _EffectCompareHint(records: _records),
                  ]),
                  const SizedBox(height: 12),
                  _InputCard(title: '复盘追问', subtitle: '围绕时间、行为、情绪/触发先改一个点', children: const [
                    _PromptLine(text: '1. 哪些行为是“当下舒服，长期亏损”？'),
                    _PromptLine(text: '2. 哪些行为是“当下费力，长期收益”？'),
                    _PromptLine(text: '3. 我最容易在什么时间、地点、身体状态下失控？'),
                    _PromptLine(text: '4. 明天只改一个最小动作，是什么？'),
                  ]),
                  const SizedBox(height: 12),
                  _InputCard(title: '原始记录', subtitle: '按日期保留行为证据，避免只靠感觉评价自己', children: [
                    if (_records.isEmpty) const Text('当前周期内暂无记录。', style: TextStyle(color: Color(0xFF6B7280))),
                    for (final r in _records) Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ReviewRecordTile(record: r),
                    ),
                  ]),
                ],
              ),
            ),
    );
  }
}


class _EffectCompareHint extends StatelessWidget {
  final List<BehaviorTrackingRecord> records;
  const _EffectCompareHint({required this.records});

  @override
  Widget build(BuildContext context) {
    final stats = BehaviorTrackingStats.fromRecords(records);
    final topTrigger = stats.triggerCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final loopRate = stats.recordCount == 0 ? 0 : (stats.loopClosureCount / stats.recordCount * 100).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _PromptLine(text: '• 复盘闭环率：$loopRate%（同时记录长期影响与替代方案的条目占比）'),
      _PromptLine(text: '• 高频触发：${topTrigger.isEmpty ? '暂无' : topTrigger.take(3).map((e) => '${e.key}×${e.value}').join(' / ')}'),
      const _PromptLine(text: '• 下一阶段可将睡眠、步数、屏幕时间等自动摘要作为“待确认记录”，用户确认后才入库。'),
      const _PromptLine(text: '• 所有身体/情绪解释只做模式发现，不做诊断；图表文案避免羞辱式评价。'),
    ]);
  }
}

class _ReviewSummaryCard extends StatelessWidget {
  final List<BehaviorTrackingRecord> records;
  final int totalMinutes;
  final double? avgEmotion;
  const _ReviewSummaryCard({required this.records, required this.totalMinutes, required this.avgEmotion});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(children: [
        Expanded(child: _ReviewMetric(label: '记录数', value: '${records.length} 条')),
        Expanded(child: _ReviewMetric(label: '时间块', value: '${totalMinutes ~/ 60}h ${totalMinutes % 60}m')),
        Expanded(child: _ReviewMetric(label: '平均情绪', value: avgEmotion == null ? '未填' : avgEmotion!.toStringAsFixed(1))),
      ]),
    );
  }
}

class _ReviewMetric extends StatelessWidget {
  final String label;
  final String value;
  const _ReviewMetric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
    ]);
  }
}

class _ReviewInsightCard extends StatelessWidget {
  final List<BehaviorTrackingRecord> records;
  const _ReviewInsightCard({required this.records});

  @override
  Widget build(BuildContext context) {
    final triggers = records.map((e) => e.trigger).where((e) => e.trim().isNotEmpty).take(3).toList();
    final alternatives = records.map((e) => e.alternative).where((e) => e.trim().isNotEmpty).take(3).toList();
    return _InputCard(title: '自动复盘线索', subtitle: '根据已填字段生成，不调用外部AI', children: [
      Text(records.isEmpty ? '先记录几条行为，系统会自动整理触发点、替代方案和长期影响。' : '本周期最值得看的不是“我好不好”，而是哪些触发反复出现、哪些替代动作可复用。', style: const TextStyle(color: Color(0xFF4B5563), height: 1.55)),
      if (triggers.isNotEmpty) ...[
        const SizedBox(height: 10),
        const Text('高频触发线索', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        for (final t in triggers) _PromptLine(text: '• $t'),
      ],
      if (alternatives.isNotEmpty) ...[
        const SizedBox(height: 10),
        const Text('可复用替代方案', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        for (final a in alternatives) _PromptLine(text: '• $a'),
      ],
    ]);
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  const _StatBar({required this.label, required this.value, required this.total});
  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : value / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))), Text('${value ~/ 60}h ${value % 60}m', style: const TextStyle(color: Color(0xFF6B7280)))]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: ratio.clamp(0.0, 1.0).toDouble(), minHeight: 10, backgroundColor: const Color(0xFFE5E7EB)),
        ),
      ]),
    );
  }
}

class _PromptLine extends StatelessWidget {
  final String text;
  const _PromptLine({required this.text});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)));
}

class _ReviewRecordTile extends StatelessWidget {
  final BehaviorTrackingRecord record;
  const _ReviewRecordTile({required this.record});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${DateFormat('MM/dd').format(record.recordDate)}  ${record.title.ifBlank(record.primaryLayer)}', style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(record.oneLineSummary, style: const TextStyle(color: Color(0xFF4B5563), height: 1.4)),
      ]),
    );
  }
}

extension _BlankTextExt on String {
  String ifBlank(String fallback) => trim().isEmpty ? fallback : trim();
}
