import 'package:flutter/material.dart';

import '../services/movie_analysis_service.dart';
import '../services/movie_external_watch_service.dart';
import '../services/tmdb_service.dart';
import 'movie_overview_box.dart';

/// A reusable movie card used by:
/// - Movie ranking list tabs
/// - Movie search results
/// - Movie favourites list
///
/// Requirements implemented here:
/// - Overview shows 4 lines by default; if it overflows, show a “查看” button.
/// - “查看” is placed in the right action column and vertically aligned with
///   the favourite button (so it never covers text).
/// - “分析” calls the global AI provider and opens a readable analysis dialog.
class MovieCardItem extends StatefulWidget {
  final Map<String, dynamic> movie;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  /// Whether to show the favourite button.
  final bool showFavorite;

  const MovieCardItem({
    super.key,
    required this.movie,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.showFavorite = true,
  });

  @override
  State<MovieCardItem> createState() => _MovieCardItemState();
}

class _MovieCardItemState extends State<MovieCardItem> {
  final MovieAnalysisService _analysisService = MovieAnalysisService();
  final MovieExternalWatchService _externalWatchService = const MovieExternalWatchService();
  bool _overviewOverflow = false;
  bool _analyzing = false;

  void _showFullOverview(String title, String overview) {
    final content = overview.trim().isEmpty ? '暂无简介' : overview.trim();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title.isEmpty ? '电影简介' : title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              content,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  String _formatSavedAt(Object? value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _showAnalysisDialog({
    required String title,
    required String text,
    String? savedAt,
    bool saved = false,
    bool allowReanalyze = false,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title.isEmpty ? '电影深度分析' : '《$title》深度分析'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (saved) ...[
                  Text(
                    savedAt == null || savedAt.isEmpty ? '本地已保存最近一次分析结果' : '本地已保存最近一次分析结果：$savedAt',
                    style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                ],
                SelectableText(
                  text,
                  style: const TextStyle(fontSize: 14, height: 1.55),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (allowReanalyze)
            TextButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _runMovieAnalysis(title, forceReanalyze: true);
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重新分析并覆盖'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _runMovieAnalysis(String title, {bool forceReanalyze = false}) async {
    if (_analyzing) return;
    if (!forceReanalyze) {
      try {
        final saved = await _analysisService.getSavedAnalysis(widget.movie);
        final savedText = (saved?['analysis_text'] ?? '').toString().trim();
        if (savedText.isNotEmpty) {
          if (!mounted) return;
          await _showAnalysisDialog(
            title: title,
            text: savedText,
            saved: true,
            savedAt: _formatSavedAt(saved?['updated_at'] ?? saved?['created_at']),
            allowReanalyze: true,
          );
          return;
        }
      } catch (_) {
        // If reading the local cache fails, fall through to a fresh AI analysis.
      }
    }

    setState(() => _analyzing = true);
    try {
      final text = await _analysisService.analyzeMovie(widget.movie);
      if (!mounted) return;
      await _showAnalysisDialog(
        title: title,
        text: text,
        saved: true,
        savedAt: _formatSavedAt(DateTime.now().toIso8601String()),
        allowReanalyze: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('电影分析失败：$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }


  Future<void> _openExternalSite({
    required MovieExternalWatchSite site,
    required String title,
    String? originalTitle,
    String? releaseDate,
  }) async {
    try {
      await _externalWatchService.openExternalSearch(
        site: site,
        title: title,
        originalTitle: originalTitle,
        releaseDate: releaseDate,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('打开${site.label}失败：$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showExternalWatchSheet({
    required String title,
    String? originalTitle,
    String? releaseDate,
  }) {
    final safeTitle = title.trim().isEmpty ? '这部电影' : title.trim();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '外部网站搜索观看入口',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '《$safeTitle》将通过外部浏览器打开；本 App 不解析、不存储、不内嵌播放第三方影片资源。',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                for (final site in MovieExternalWatchSite.values)
                  ListTile(
                    leading: const Icon(Icons.open_in_browser),
                    title: Text('在${site.label}搜索'),
                    subtitle: Text('${site.domain} · 外部浏览器打开'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _openExternalSite(
                        site: site,
                        title: title,
                        originalTitle: originalTitle,
                        releaseDate: releaseDate,
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final title = (movie['title'] ?? movie['name'] ?? '').toString();
    final originalTitle = (movie['original_title'] ?? movie['original_name'] ?? '').toString();
    final overview = (movie['overview'] ?? '').toString();
    final releaseDate = (movie['release_date'] ?? movie['first_air_date'] ?? '').toString();
    final voteAverage = movie['vote_average'];
    final voteCount = movie['vote_count'];

    final posterPath = movie['poster_path'];
    final posterUrl = TMDbService.buildPosterUrl(posterPath?.toString(), size: 'w342');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _showExternalWatchSheet(
          title: title,
          originalTitle: originalTitle,
          releaseDate: releaseDate,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster image
              if (posterUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    posterUrl,
                    width: 80,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 120,
                  color: Colors.grey.shade300,
                  alignment: Alignment.center,
                  child: const Icon(Icons.movie, size: 40, color: Colors.grey),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    MovieOverviewBox(
                      text: overview,
                      maxLines: 4,
                      onOverflowChanged: (v) {
                        if (!mounted) return;
                        if (v != _overviewOverflow) {
                          setState(() => _overviewOverflow = v);
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        if (releaseDate.isNotEmpty) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: Colors.black45),
                              const SizedBox(width: 4),
                              Text(releaseDate, style: const TextStyle(fontSize: 12, color: Colors.black45)),
                            ],
                          ),
                        ],
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              (voteAverage != null ? (voteAverage as num).toStringAsFixed(1) : '-') +
                                  ' (${voteCount ?? '-'})',
                              style: const TextStyle(fontSize: 12, color: Colors.black45),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Right-side action column (favourite + 查看 + 观看 + 分析)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showFavorite)
                    IconButton(
                      icon: Icon(
                        widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: widget.isFavorite ? Colors.red : Colors.grey,
                      ),
                      onPressed: widget.onToggleFavorite,
                    ),
                  if (_overviewOverflow)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _showFullOverview(title, overview),
                      child: const Text(
                        '查看',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _showExternalWatchSheet(
                      title: title,
                      originalTitle: originalTitle,
                      releaseDate: releaseDate,
                    ),
                    icon: const Icon(Icons.play_circle_outline, size: 14),
                    label: const Text(
                      '观看',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _analyzing ? null : () => _runMovieAnalysis(title),
                    icon: _analyzing
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, size: 14),
                    label: Text(
                      _analyzing ? '分析中' : '分析',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
}
