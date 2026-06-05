import 'package:flutter/material.dart';

import '../services/tmdb_service.dart';
import 'movie_role_lab_models.dart';
import 'movie_role_lab_role_page.dart';
import 'movie_role_lab_settings_page.dart';
import 'movie_role_lab_service.dart';
import 'movie_role_lab_search_history_page.dart';

class MovieRoleLabHomePage extends StatefulWidget {
  const MovieRoleLabHomePage({super.key});

  @override
  State<MovieRoleLabHomePage> createState() => _MovieRoleLabHomePageState();
}

class _MovieRoleLabHomePageState extends State<MovieRoleLabHomePage> {
  final MovieRoleLabService _service = MovieRoleLabService();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = false;
  bool _subtitleLoading = false;
  List<MovieRoleLabMovie> _results = <MovieRoleLabMovie>[];
  List<MovieRoleLabRecentExperience> _recent = <MovieRoleLabRecentExperience>[];
  List<MovieRoleLabSearchHistoryItem> _searchHistory = <MovieRoleLabSearchHistoryItem>[];
  String? _error;
  String? _subtitleError;
  MovieRoleLabMovie? _selectedMovie;
  MovieRoleLabStoredSubtitle? _storedSubtitle;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final list = await _service.loadRecent();
    final history = await _service.loadSearchHistory(limit: 5);
    if (!mounted) return;
    setState(() {
      _recent = list;
      _searchHistory = history;
    });
  }

  Future<void> _openSearchHistory() async {
    final movie = await Navigator.of(context).push<MovieRoleLabMovie>(
      MaterialPageRoute(builder: (_) => const MovieRoleLabSearchHistoryPage()),
    );
    await _loadRecent();
    if (movie != null) {
      setState(() {
        _results = <MovieRoleLabMovie>[movie];
        _selectedMovie = movie;
      });
      await _prepareSubtitle(movie);
    }
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _subtitleError = null;
      _selectedMovie = null;
      _storedSubtitle = null;
    });
    try {
      final list = await _service.searchMovies(q);
      if (!mounted) return;
      setState(() => _results = list);
      await _loadRecent();
      if (list.isNotEmpty) {
        await _prepareSubtitle(list.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _prepareSubtitle(MovieRoleLabMovie movie) async {
    setState(() {
      _selectedMovie = movie;
      _subtitleLoading = true;
      _subtitleError = null;
      _storedSubtitle = null;
    });
    try {
      final stored = await _service.importOrLoadFullSubtitle(movie);
      if (!mounted) return;
      setState(() => _storedSubtitle = stored);
    } catch (e) {
      if (!mounted) return;
      setState(() => _subtitleError = e.toString());
    } finally {
      if (mounted) setState(() => _subtitleLoading = false);
    }
  }

  Future<void> _openMovie(MovieRoleLabMovie movie) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MovieRoleLabRolePage(movie: movie)),
    );
    _loadRecent();
  }

  Future<void> _exportSubtitle() async {
    final subtitle = _storedSubtitle;
    if (subtitle == null) return;
    try {
      final path = await _service.exportSubtitleTxt(subtitle);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('字幕 TXT 已导出'),
          content: SelectableText(path),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('知道了')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  Widget _buildMovieTile(MovieRoleLabMovie movie) {
    final poster = TMDbService.buildPosterUrl(movie.posterPath, size: 'w342');
    final selected = _selectedMovie?.id == movie.id;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: selected ? 5 : 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _prepareSubtitle(movie),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 58,
                      height: 84,
                      color: const Color(0xFFF3F4F6),
                      child: poster == null
                          ? const Icon(Icons.movie_outlined, color: Color(0xFF6B7280))
                          : Image.network(poster, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(movie.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          '${movie.releaseDate.isEmpty ? '未知年份' : movie.releaseDate} · 评分 ${movie.voteAverage.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          movie.overview.isEmpty ? '暂无剧情简介' : movie.overview,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _subtitleLoading ? null : () => _prepareSubtitle(movie),
                      icon: const Icon(Icons.subtitles_outlined, size: 18),
                      label: const Text('导入/查看完整字幕'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openMovie(movie),
                      icon: const Icon(Icons.person_search_outlined, size: 18),
                      label: const Text('选择角色'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTile(MovieRoleLabRecentExperience item) {
    final poster = TMDbService.buildPosterUrl(item.movie.posterPath, size: 'w342');
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openMovie(item.movie),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 40,
                  height: 58,
                  color: const Color(0xFFF3F4F6),
                  child: poster == null ? const Icon(Icons.movie) : Image.network(poster, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.movie.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('上次扮演：${item.character.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitlePanel() {
    final movie = _selectedMovie;
    if (movie == null && !_subtitleLoading && _subtitleError == null && _storedSubtitle == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('完整电影字幕${movie == null ? '' : '：${movie.title}'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_subtitleLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Expanded(child: Text('正在从本地数据库读取；如果本地没有，则本次会从 OpenSubtitles 下载一次并保存到本地数据库……')),
                ],
              ),
            )
          else if (_subtitleError != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(14)),
              child: Text(_subtitleError!, style: const TextStyle(color: Color(0xFFBE123C), height: 1.45)),
            )
          else if (_storedSubtitle != null) ...[
            Text(
              '已保存到本地数据库：${_storedSubtitle!.cues.length} 条字幕 · ${_storedSubtitle!.language} · ${_storedSubtitle!.subtitleName} · ${_storedSubtitle!.importedAtLabel}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.45),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openMovie(movie!),
                    icon: const Icon(Icons.person_search_outlined),
                    label: const Text('用本地字幕进入角色选择'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _exportSubtitle,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('导出 TXT'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 420,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: SelectableText(
                    _storedSubtitle!.toDisplayText(),
                    style: const TextStyle(fontSize: 13, height: 1.55, color: Color(0xFF111827)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('电影角色实验室'),
        actions: [
          IconButton(
            tooltip: '搜索历史',
            icon: const Icon(Icons.history_outlined),
            onPressed: _openSearchHistory,
          ),
          IconButton(
            tooltip: '配置 OpenSubtitles / TMDb',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MovieRoleLabSettingsPage())),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('进入电影角色的人生', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('搜索电影后，先导入并显示完整字幕；字幕会保存到本地数据库。后续角色进入仪式只读取本地字幕，不再重复从 OpenSubtitles 下载。', style: TextStyle(color: Color(0xFF6B7280), height: 1.5)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        decoration: InputDecoration(
                          hintText: '输入电影名，例如：无间道 / 教父 / 花样年华',
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(onPressed: _loading ? null : _search, child: const Text('搜索')),
                  ],
                ),
              ],
            ),
          ),
          if (_recent.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('最近体验', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ..._recent.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildRecentTile(e))),
          ],
          if (_searchHistory.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                const Text('搜索历史', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _openSearchHistory,
                  icon: const Icon(Icons.history_outlined, size: 18),
                  label: const Text('查看全部'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, i) {
                  final item = _searchHistory[i];
                  return ActionChip(
                    avatar: const Icon(Icons.movie_filter_outlined, size: 18),
                    label: Text(item.movie.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onPressed: () => _prepareSubtitle(item.movie),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: _searchHistory.length,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              const Text('搜索结果', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              if (_loading) ...[
                const SizedBox(width: 10),
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(14)),
              child: Text(_error!, style: const TextStyle(color: Color(0xFFBE123C))),
            )
          else if (_results.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: const Text('先搜索一部电影，然后点击“导入/查看完整字幕”。', style: TextStyle(color: Color(0xFF6B7280))),
            )
          else
            ..._results.map((m) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildMovieTile(m))),
          _buildSubtitlePanel(),
        ],
      ),
    );
  }
}
