import 'package:flutter/material.dart';

import '../services/tmdb_service.dart';
import 'movie_role_lab_models.dart';
import 'movie_role_lab_role_page.dart';
import 'movie_role_lab_service.dart';

class MovieRoleLabSearchHistoryPage extends StatefulWidget {
  const MovieRoleLabSearchHistoryPage({super.key});

  @override
  State<MovieRoleLabSearchHistoryPage> createState() => _MovieRoleLabSearchHistoryPageState();
}

class _MovieRoleLabSearchHistoryPageState extends State<MovieRoleLabSearchHistoryPage> {
  final MovieRoleLabService _service = MovieRoleLabService();
  bool _loading = true;
  String? _error;
  List<MovieRoleLabSearchHistoryItem> _items = <MovieRoleLabSearchHistoryItem>[];

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
      final list = await _service.loadSearchHistory(limit: 120);
      if (!mounted) return;
      setState(() {
        _items = list;
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

  Future<void> _showRaw(MovieRoleLabSearchHistoryItem item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('TMDb 原始数据：${item.movie.title}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(item.rawJson.isEmpty ? '无原始数据' : item.rawJson),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('关闭')),
        ],
      ),
    );
  }

  Widget _buildItem(MovieRoleLabSearchHistoryItem item) {
    final poster = TMDbService.buildPosterUrl(item.movie.posterPath, size: 'w342');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 56,
                    height: 82,
                    color: const Color(0xFFF3F4F6),
                    child: poster == null ? const Icon(Icons.movie_outlined) : Image.network(poster, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.movie.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('搜索词：${item.query}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      const SizedBox(height: 3),
                      Text('${item.movie.releaseDate.isEmpty ? '未知年份' : item.movie.releaseDate} · 评分 ${item.movie.voteAverage.toStringAsFixed(1)} · ${item.searchedAtLabel}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      if (item.movie.overview.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(item.movie.overview, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.35)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(item.movie),
                  icon: const Icon(Icons.subtitles_outlined, size: 18),
                  label: const Text('查看/导入字幕'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MovieRoleLabRolePage(movie: item.movie))),
                  icon: const Icon(Icons.person_search_outlined, size: 18),
                  label: const Text('选择角色'),
                ),
                TextButton.icon(
                  onPressed: () => _showRaw(item),
                  icon: const Icon(Icons.data_object_outlined, size: 18),
                  label: const Text('查看原始数据'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('电影搜索历史')),
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: const Text(
                '这里自动保存每次搜索返回的电影数据，包括搜索词、电影基础信息、海报路径、简介、评分、时间以及 TMDb 原始 JSON。点击“查看/导入字幕”可回到首页读取或导入本地字幕。',
                style: TextStyle(color: Color(0xFF6B7280), height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(14)),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFBE123C))),
              )
            else if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: const Text('暂无搜索历史。先回到电影角色实验室搜索一部电影。', style: TextStyle(color: Color(0xFF6B7280))),
              )
            else
              ..._items.map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildItem(e))),
          ],
        ),
      ),
    );
  }
}
