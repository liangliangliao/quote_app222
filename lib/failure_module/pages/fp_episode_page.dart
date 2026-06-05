import 'package:flutter/material.dart';
import '../fp_dao.dart';
import '../fp_models.dart';
import 'fp_segment_page.dart';

class FpEpisodePage extends StatefulWidget {
  final FpEpisode episode;
  const FpEpisodePage({super.key, required this.episode});

  @override
  State<FpEpisodePage> createState() => _FpEpisodePageState();
}

class _FpEpisodePageState extends State<FpEpisodePage> {
  final _dao = FpDao();
  final Map<String, int> _segStatus = {};
  bool _loading = true;
  String? _err;
  List<FpBigSection> _sections = const [];
  final Map<String, List<FpSegment>> _segs = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bss = await _dao.listBigSections(widget.episode.episodeNo);
      final segStatus = <String, int>{};
      final segs = <String, List<FpSegment>>{};
      for (final bs in bss) {
        final xs = await _dao.listSegmentsForBigSection(bs.id);
        segs[bs.id] = xs;
        for (final s in xs) {
          segStatus[s.segmentId] = await _dao.getProgressStatus('seg:${s.segmentId}');
        }
      }
      if (!mounted) return;
      setState(() {
        _sections = bss;
        _segs.clear();
        _segs.addAll(segs);
        _segStatus.clear();
        _segStatus.addAll(segStatus);
        _loading = false;
        _err = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.episode.titleZh)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(child: Text(_err!))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                  children: [
                    for (final bs in _sections) ...[
                      _BigSectionCard(
                        title: '第${bs.sectionIndex}段',
                        subtitle: '${bs.id} · ${(_segs[bs.id] ?? const []).length}小段',
                        children: [
                          for (final s in (_segs[bs.id] ?? const []))
                            _SegmentTile(
                              segment: s,
                              status: _segStatus[s.segmentId] ?? 0,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => FpSegmentPage(segmentId: s.segmentId)),
                                );
                                // refresh only this status
                                final st = await _dao.getProgressStatus('seg:${s.segmentId}');
                                if (!mounted) return;
                                setState(() => _segStatus[s.segmentId] = st);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
    );
  }
}

class _BigSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _BigSectionCard({required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: Colors.black.withOpacity(0.6))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  final FpSegment segment;
  final int status;
  final VoidCallback onTap;
  const _SegmentTile({required this.segment, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = status >= 1;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      leading: Icon(done ? Icons.check_circle : Icons.circle_outlined, color: done ? Colors.green : null),
      title: Text(
        segment.summaryZh,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: done ? FontWeight.w700 : FontWeight.w600),
      ),
      subtitle: Text(
        '${segment.segmentId} · 关联概念：${segment.primaryNode}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}
