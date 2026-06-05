import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/tmdb_service.dart';
import 'movie_role_lab_entry_page.dart';
import 'movie_role_lab_models.dart';
import 'movie_role_lab_service.dart';

class _ImportedTxtFile {
  final String name;
  final String content;

  const _ImportedTxtFile({required this.name, required this.content});
}

class MovieRoleLabRolePage extends StatefulWidget {
  final MovieRoleLabMovie movie;

  const MovieRoleLabRolePage({super.key, required this.movie});

  @override
  State<MovieRoleLabRolePage> createState() => _MovieRoleLabRolePageState();
}

class _MovieRoleLabRolePageState extends State<MovieRoleLabRolePage> {
  final MovieRoleLabService _service = MovieRoleLabService();
  bool _loading = true;
  bool _working = false;
  String? _error;
  List<MovieRoleLabCharacter> _characters = <MovieRoleLabCharacter>[];
  List<MovieRoleLabEpisode> _episodes = <MovieRoleLabEpisode>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final characters = await _service.fetchMovieCharacters(widget.movie.id);
      final episodes = await _service.loadEpisodes(widget.movie);
      if (!mounted) return;
      setState(() {
        _characters = characters;
        _episodes = episodes;
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

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认')),
        ],
      ),
    );
    return result == true;
  }

  Future<int?> _askStartIndex() async {
    final controller = TextEditingController(text: '1');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('指定导入剧本序列'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '从第几集开始保存',
            helperText: '例如填 1，则导入的第一个文件/片段保存为第1集。',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim()) ?? 1;
              Navigator.pop(context, value <= 0 ? 1 : value);
            },
            child: const Text('继续选择TXT'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _runAiEpisodeGeneration() async {
    final ok = await _confirm(
      _episodes.isEmpty ? '调用 AI 配角色并分集？' : '重新调用 AI 配角色并分集？',
      _episodes.isEmpty
          ? '本操作会把完整字幕和演员表发送给已配置的 AI 模型处理，可能消耗较多 token。普通 SRT 没有说话人字段，建议优先使用非深度思考、稳定输出 JSON 的模型；如果使用 OpenRouter 深度推理模型，可能出现长时间推理后正文为空。'
          : '本电影当前已有 ${_episodes.length} 集分集剧本。继续后会先自动清空已有分集，再重新调用 AI 配角色并分集。此操作不可撤销，并可能消耗较多 token。普通 SRT 没有说话人字段，建议优先使用非深度思考、稳定输出 JSON 的模型。',
    );
    if (!ok) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final episodes = await _service.generateOrLoadEpisodes(
        movie: widget.movie,
        ensemble: _characters,
        replaceExisting: _episodes.isNotEmpty,
      );
      if (!mounted) return;
      setState(() {
        _episodes = episodes;
        _working = false;
      });
      _toast('AI 配角色并分集完成，已保存到本地数据库。');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _working = false;
      });
    }
  }

  Future<void> _importTxtEpisodes() async {
    final startIndex = await _askStartIndex();
    if (startIndex == null) return;
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '批量选择 TXT 分集剧本',
      type: FileType.custom,
      allowedExtensions: const ['txt'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final importedFiles = <_ImportedTxtFile>[];
    for (final f in result.files) {
      final name = f.name.trim().isEmpty ? '未命名TXT' : f.name.trim();
      String content = '';
      if (f.bytes != null) {
        content = utf8.decode(f.bytes!, allowMalformed: true);
      } else if (f.path != null && f.path!.trim().isNotEmpty) {
        content = await File(f.path!).readAsString();
      }
      if (content.trim().isNotEmpty) {
        importedFiles.add(_ImportedTxtFile(name: name, content: content));
      }
    }

    if (importedFiles.isEmpty) {
      _toast('没有读取到有效 TXT 内容。');
      return;
    }

    importedFiles.sort((a, b) => _compareFileNameNaturally(a.name, b.name));
    final ok = await _confirmBatchImport(startIndex: startIndex, files: importedFiles);
    if (!ok) return;

    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final episodes = await _service.importEpisodesFromTxtContents(
        movie: widget.movie,
        ensemble: _characters,
        contents: importedFiles.map((e) => e.content).toList(),
        startEpisodeIndex: startIndex,
      );
      if (!mounted) return;
      setState(() {
        _episodes = episodes;
        _working = false;
      });
      _toast('已批量导入 ${importedFiles.length} 个 TXT 文件，并保存到本地数据库。');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _working = false;
      });
    }
  }

  Future<bool> _confirmBatchImport({
    required int startIndex,
    required List<_ImportedTxtFile> files,
  }) async {
    final previewNames = files.take(12).map((e) => '• ${e.name}').join('\n');
    final more = files.length > 12 ? '\n……另有 ${files.length - 12} 个文件' : '';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认批量导入 ${files.length} 个 TXT？'),
        content: SingleChildScrollView(
          child: Text(
            '将按文件名自然排序后依次导入，从第 $startIndex 集开始保存。\n\n'
            '导入前会自动检查：分集序号重复、TXT 之间内容重复、与本地已有分集内容重复。\n\n'
            '$previewNames$more',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('开始导入')),
        ],
      ),
    );
    return result == true;
  }

  int _compareFileNameNaturally(String a, String b) {
    final ax = _splitNameForNaturalSort(a);
    final bx = _splitNameForNaturalSort(b);
    final n = ax.length < bx.length ? ax.length : bx.length;
    for (var i = 0; i < n; i++) {
      final av = ax[i];
      final bv = bx[i];
      final ai = int.tryParse(av);
      final bi = int.tryParse(bv);
      final c = ai != null && bi != null ? ai.compareTo(bi) : av.toLowerCase().compareTo(bv.toLowerCase());
      if (c != 0) return c;
    }
    return ax.length.compareTo(bx.length);
  }

  List<String> _splitNameForNaturalSort(String value) {
    return RegExp(r'\d+|\D+').allMatches(value).map((m) => m.group(0) ?? '').where((e) => e.isNotEmpty).toList();
  }

  Future<void> _clearAllEpisodes() async {
    if (_episodes.isEmpty) {
      _toast('当前没有可清空的分集剧本。');
      return;
    }
    final ok = await _confirm('全部清空分集剧本？', '这会删除《${widget.movie.title}》已保存的所有分集、角色和台词数据，但不会删除完整字幕。');
    if (!ok) return;
    setState(() => _working = true);
    try {
      await _service.clearEpisodes(widget.movie);
      if (!mounted) return;
      setState(() {
        _episodes = <MovieRoleLabEpisode>[];
        _working = false;
      });
      _toast('已清空该电影全部分集剧本。');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _working = false;
      });
    }
  }

  Future<void> _deleteEpisode(MovieRoleLabEpisode episode) async {
    final ok = await _confirm('删除本集剧本？', '确认删除“第${episode.episodeIndex}集：${episode.title}”？');
    if (!ok) return;
    setState(() => _working = true);
    try {
      await _service.deleteEpisode(episode.id);
      final episodes = await _service.loadEpisodes(widget.movie);
      if (!mounted) return;
      setState(() {
        _episodes = episodes;
        _working = false;
      });
      _toast('已删除本集剧本。');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _working = false;
      });
    }
  }

  MovieRoleLabCharacter _characterForRole(MovieRoleLabEpisodeRole role) {
    String norm(String v) => v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), '');
    final candidates = [role.name, role.nameEn, role.nameZh].map(norm).where((e) => e.isNotEmpty).toList();
    for (final c in _characters) {
      final cn = norm(c.name);
      if (candidates.any((e) => e == cn || e.contains(cn) || cn.contains(e))) return c;
    }
    return MovieRoleLabCharacter(
      id: 0,
      name: role.nameEn.trim().isNotEmpty ? role.nameEn : (role.name.trim().isNotEmpty ? role.name : role.displayName),
      actorName: role.actorName,
      profilePath: role.profilePath,
      order: 9999,
      department: '',
    );
  }

  void _showCastList() {
    final cast = List<MovieRoleLabCharacter>.from(_characters)
      ..sort((a, b) => a.order.compareTo(b.order));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            minChildSize: 0.35,
            maxChildSize: 0.94,
            builder: (context, controller) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('全部参演人员', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text('《${widget.movie.title}》 · ${cast.length} 位', style: const TextStyle(color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: cast.isEmpty
                      ? const Center(child: Text('暂无演员表数据，请先确认 TMDb 配置是否可用。'))
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: cast.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                          itemBuilder: (context, index) {
                            final c = cast[index];
                            final imageUrl = TMDbService.buildPosterUrl(c.profilePath, size: 'w185');
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 23,
                                backgroundImage: imageUrl == null ? null : NetworkImage(imageUrl),
                                child: imageUrl == null ? const Icon(Icons.person_outline) : null,
                              ),
                              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('饰演者：${c.actorName.isEmpty ? '未知' : c.actorName}'),
                              trailing: Text('#${index + 1}', style: const TextStyle(color: Color(0xFF9CA3AF))),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCharacter(MovieRoleLabEpisode episode, MovieRoleLabEpisodeRole role) async {
    final character = _characterForRole(role);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MovieRoleLabEntryPage(
          movie: widget.movie,
          character: character,
          ensemble: _characters,
          episode: episode,
        ),
      ),
    );
  }

  Widget _roleChip(MovieRoleLabEpisode episode, MovieRoleLabEpisodeRole role) {
    final character = _characterForRole(role);
    final imageUrl = TMDbService.buildPosterUrl(character.profilePath, size: 'w185');
    return ActionChip(
      avatar: CircleAvatar(
        backgroundImage: imageUrl == null ? null : NetworkImage(imageUrl),
        child: imageUrl == null ? const Icon(Icons.person_outline, size: 16) : null,
      ),
      label: Text(role.displayName),
      onPressed: _working ? null : () => _openCharacter(episode, role),
    );
  }

  Widget _episodeCard(MovieRoleLabEpisode episode) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Text('第${episode.episodeIndex}集：${episode.title}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '${episode.timeRangeLabel} · ${episode.roles.length} 个角色 · ${episode.lines.length} 句台词',
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        trailing: IconButton(
          tooltip: '删除本集',
          onPressed: _working ? null : () => _deleteEpisode(episode),
          icon: const Icon(Icons.delete_outline),
        ),
        children: [
          if (episode.previousContext.trim().isNotEmpty) ...[
            const Align(alignment: Alignment.centerLeft, child: Text('前情提示', style: TextStyle(fontWeight: FontWeight.w800))),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerLeft, child: Text(episode.previousContext, style: const TextStyle(height: 1.5, color: Color(0xFF4B5563)))),
            const SizedBox(height: 10),
          ],
          if (episode.summary.trim().isNotEmpty) ...[
            const Align(alignment: Alignment.centerLeft, child: Text('剧情内容', style: TextStyle(fontWeight: FontWeight.w800))),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerLeft, child: Text(episode.summary, style: const TextStyle(height: 1.5, color: Color(0xFF4B5563)))),
            const SizedBox(height: 10),
          ],
          const Align(alignment: Alignment.centerLeft, child: Text('本集参演角色', style: TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: episode.roles.map((role) => _roleChip(episode, role)).toList(),
            ),
          ),
          const SizedBox(height: 10),
          const Align(alignment: Alignment.centerLeft, child: Text('剧本预览', style: TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
            child: Text(
              episode.lines.take(12).map((e) => '[${e.timeRangeLabel}] ${e.displaySpeaker}：${e.text}').join('\n\n'),
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionPanel() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('分集剧本操作', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            _episodes.isEmpty
                ? '进入本页默认只读取本地已有分集，不会自动调用 AI。你可以手动调用 AI，或一次性批量导入本地已经配好角色的多个 TXT 分集剧本。'
                : '该电影已存在分集剧本。批量导入 TXT 时会按文件名自然排序，并自动检查分集序号和剧本内容是否重复；重新 AI 分集前会先弹窗确认并自动清空旧分集。',
            style: const TextStyle(color: Color(0xFF6B7280), height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _working ? null : _runAiEpisodeGeneration,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('AI配角色并分集'),
              ),
              OutlinedButton.icon(
                onPressed: _working ? null : _importTxtEpisodes,
                icon: const Icon(Icons.upload_file),
                label: const Text('批量导入TXT分集剧本'),
              ),
              OutlinedButton.icon(
                onPressed: (_working || _episodes.isEmpty) ? null : _clearAllEpisodes,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('全部清空'),
              ),
            ],
          ),
          if (_working) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 6),
            const Text('正在处理，请勿重复点击。', style: TextStyle(color: Color(0xFF6B7280))),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final poster = TMDbService.buildPosterUrl(widget.movie.posterPath, size: 'w500');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.movie.title),
        actions: [
          IconButton(
            tooltip: '刷新本地分集',
            onPressed: _loading || _working ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '全部清空分集剧本',
            onPressed: _loading || _working || _episodes.isEmpty ? null : _clearAllEpisodes,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _showCastList,
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.all(14),
              child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 74,
                    height: 104,
                    color: const Color(0xFFF3F4F6),
                    child: poster == null ? const Icon(Icons.movie_outlined) : Image.network(poster, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.movie.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(widget.movie.overview.isEmpty ? '系统会基于完整字幕和演员表进行 AI 配角色与分集。' : widget.movie.overview, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6B7280), height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.people_alt_outlined, color: Color(0xFF9CA3AF)),
              ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _actionPanel(),
          const SizedBox(height: 16),
          const Text('剧情片段 / 分集剧本', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('正在加载本地分集剧本…'),
                ],
              ),
            )
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(14)),
              child: Text(_error!, style: const TextStyle(color: Color(0xFFBE123C))),
            )
          else if (_episodes.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Text('尚未保存分集剧本。请点击上方按钮调用 AI 配角色并分集，或导入本地 TXT 分集剧本。'),
            )
          else
            ..._episodes.map(_episodeCard),
        ],
      ),
    );
  }
}
