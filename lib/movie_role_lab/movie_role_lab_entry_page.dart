import 'package:flutter/material.dart';

import 'movie_role_lab_models.dart';
import 'movie_role_lab_service.dart';
import 'movie_role_lab_session_page.dart';

class MovieRoleLabEntryPage extends StatefulWidget {
  final MovieRoleLabMovie movie;
  final MovieRoleLabCharacter character;
  final List<MovieRoleLabCharacter> ensemble;
  final MovieRoleLabEpisode? episode;

  const MovieRoleLabEntryPage({
    super.key,
    required this.movie,
    required this.character,
    required this.ensemble,
    this.episode,
  });

  @override
  State<MovieRoleLabEntryPage> createState() => _MovieRoleLabEntryPageState();
}

class _MovieRoleLabEntryPageState extends State<MovieRoleLabEntryPage> {
  final MovieRoleLabService _service = MovieRoleLabService();
  bool _loading = true;
  String? _error;
  MovieRoleLabEntryBrief? _brief;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final brief = await _service.buildEntryBrief(
        movie: widget.movie,
        character: widget.character,
        ensemble: widget.ensemble,
        episode: widget.episode,
      );
      if (!mounted) return;
      setState(() {
        _brief = brief;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _start() async {
    await _service.saveRecent(widget.movie, widget.character);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MovieRoleLabSessionPage(
          movie: widget.movie,
          character: widget.character,
          ensemble: widget.ensemble,
          brief: _brief!,
          episode: widget.episode,
        ),
      ),
    );
  }

  Widget _infoCard(String title, String body) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: Color(0xFF4B5563), height: 1.55)),
        ],
      ),
    );
  }


  Widget _subtitleEvidenceCard() {
    final evidence = _brief!.subtitleEvidence;
    final cues = evidence.cues.take(8).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: evidence.available ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: evidence.available ? const Color(0xFFA7F3D0) : const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(evidence.available ? Icons.verified_outlined : Icons.warning_amber_rounded, size: 18),
              const SizedBox(width: 6),
              const Expanded(child: Text('真实字幕依据', style: TextStyle(fontWeight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 6),
          Text(evidence.status, style: const TextStyle(height: 1.45, color: Color(0xFF374151))),
          if (evidence.subtitleName.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('字幕：${evidence.subtitleName} · ${evidence.language}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
          if (evidence.warning.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(evidence.warning, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4)),
          ],
          if (cues.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...cues.map((cue) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('[${cue.timeRangeLabel}] ${cue.text}', style: const TextStyle(fontSize: 13, height: 1.45)),
                )),
          ],
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('角色进入仪式')),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_brief!.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(_brief!.scene, style: const TextStyle(color: Color(0xFFE5E7EB), height: 1.6)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _infoCard('你是谁', _brief!.whoYouAre),
                    const SizedBox(height: 10),
                    _infoCard('你想得到什么', _brief!.whatYouWant),
                    const SizedBox(height: 10),
                    _infoCard('你最怕什么', _brief!.whatYouFear),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('角色原则', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _brief!.principles
                                .map((e) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(e),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _subtitleEvidenceCard(),
                    if (widget.episode != null) ...[
                      const SizedBox(height: 10),
                      _infoCard('当前片段剧本', widget.episode!.toScriptText()),
                    ],
                    const SizedBox(height: 10),
                    _infoCard('导演提示', _brief!.directorHint),
                    const SizedBox(height: 10),
                    _infoCard('对手角色的开场台词', _brief!.openingLine),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _brief == null ? null : _start,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('开始进入场景'),
                    ),
                  ],
                ),
    );
  }
}
