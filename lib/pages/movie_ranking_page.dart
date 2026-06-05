import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/tmdb_service.dart';
import '../data/dao.dart';
import '../data/movie_favorite_dao.dart';
import 'movie_favorites_page.dart';
import '../widgets/movie_card_item.dart';

/// A page displaying multiple movie lists from TMDb as tabs. Each tab
/// corresponds to a different endpoint: high‑score (discover with vote
/// threshold), Top Rated, Popular, Now Playing and Upcoming. Lists are
/// loaded lazily and support infinite scrolling. Users can favourite
/// movies locally; favourites are indicated with a filled heart icon.
class MovieRankingPage extends StatefulWidget {
  const MovieRankingPage({super.key});

  @override
  State<MovieRankingPage> createState() => _MovieRankingPageState();
}

/// State for [MovieRankingPage]. Handles tab navigation, performing
/// keyword searches against TMDb and displaying either search results
/// or the standard category tabs. A search box is presented in the
/// app bar allowing users to search for any movie title. The page title
/// has been shortened to “电影榜” and aligned to the left to free up
/// horizontal space for the search box.
class _MovieRankingPageState extends State<MovieRankingPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  // Controller for the search text field.
  final TextEditingController _searchController = TextEditingController();
  // The current list of search results. When empty or null the
  // TabBarView is displayed instead.
  List<Map<String, dynamic>> _searchResults = [];
  bool _searchLoading = false;
  String _token = '';

  // Favourites for search results (and used to render heart state).
  final MovieFavoriteDao _favDao = MovieFavoriteDao();
  Set<int> _favIds = <int>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    // Load TMDb token and favourites once for search.
    _initSearchDeps();
  }

  Future<void> _initSearchDeps() async {
    await _loadToken();
    try {
      final ids = await _favDao.allFavoriteIds();
      if (mounted) {
        setState(() => _favIds = ids);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadToken() async {
    final cfgDao = ConfigDao();
    try {
      final token = await cfgDao.getMovieToken();
      setState(() {
        _token = token;
      });
    } catch (_) {
      // leave token empty on error; search will return no results
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Performs a search query against TMDb. When [query] is empty the
  /// search results are cleared and the tab view is shown. Otherwise
  /// results are fetched from the API using the configured token. Any
  /// errors result in an empty list of results.
  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    setState(() {
      _searchLoading = true;
    });
    try {
      final service = TMDbService(token: _token);
      final data = await service.searchMovies(query: trimmed, page: 1);
      final results = data['results'];
      if (results is List) {
        setState(() {
          _searchResults = results.cast<Map<String, dynamic>>();
        });
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    } catch (_) {
      setState(() {
        _searchResults = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _searchLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFavoriteForSearch(Map<String, dynamic> movie) async {
    final id = movie['id'];
    if (id is! int) return;
    final isFav = _favIds.contains(id);
    if (isFav) {
      await _favDao.deleteByTmdbId(id);
      if (mounted) {
        setState(() => _favIds.remove(id));
      }
    } else {
      final data = {
        'tmdb_id': id,
        'title': (movie['title'] ?? movie['name'] ?? '').toString(),
        'overview': (movie['overview'] ?? '').toString(),
        'poster_path': movie['poster_path'],
        'backdrop_path': movie['backdrop_path'],
        'vote_average': movie['vote_average'],
        'vote_count': movie['vote_count'],
        'release_date': (movie['release_date'] ?? movie['first_air_date'] ?? '').toString(),
        'raw_json': jsonEncode(movie),
      };
      await _favDao.insert(data);
      if (mounted) {
        setState(() => _favIds.add(id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine whether we are in search mode. We show search results if
    // the search box is non‑empty and results have been loaded.
    final bool inSearch = _searchController.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        // Align the title to the start and shorten it. Set zero spacing
        // to push it flush to the left.
        centerTitle: false,
        titleSpacing: 0.0,
        title: const Text('电影榜', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        // Put the search field and favourites icon in the actions slot. The
        // search field uses a fixed width so that the favourites icon
        // remains visible on the far right.
        actions: [
          // Search box
          Container(
            width: 200,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索电影',
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (value) {
                // Debounce could be added here for performance; for now we
                // issue a search for every change.
                _performSearch(value);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_outline),
            onPressed: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const MovieFavoritesPage(),
                ),
              );
            },
          ),
        ],
        // Put the tab bar in the bottom of the app bar. Wrap it in a
        // PreferredSize + Align so that the tabs are left aligned even
        // when they are scrollable. Without this wrapper the TabBar
        // defaults to centring its tabs leaving excess space on the
        // right.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: const Offset(-35, 0),
              child: TabBar(
              controller: _tabController,
              isScrollable: true,
              // Tabs: left outer/inner padding = 0, and reduce spacing between
              // tabs by ~3dp compared to previous.
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.only(left: 0, right: 9),
              indicatorPadding: EdgeInsets.zero,
              // Align tabs to the start when supported. The `tabAlignment`
              // property may not exist on all Flutter versions, so it's
              // commented out for compatibility.
              // tabAlignment: TabAlignment.start,
              labelColor: Colors.black87,
              indicatorColor: Colors.black87,
              tabs: const [
                Tab(text: '高分榜'),
                Tab(text: 'Top Rated'),
                Tab(text: '热门'),
                Tab(text: '上映中'),
                Tab(text: '中国榜'),
                Tab(text: '即将上映'),
              ],
              ),
            ),
          ),
        ),
      ),
      body: inSearch
          ? _buildSearchResults()
          : TabBarView(
              controller: _tabController,
              children: const [
                _MovieListTab(category: _MovieCategory.highScore),
                _MovieListTab(category: _MovieCategory.topRated),
                _MovieListTab(category: _MovieCategory.popular),
                _MovieListTab(category: _MovieCategory.nowPlaying),
                _MovieListTab(category: _MovieCategory.chinaNowPopular),
                _MovieListTab(category: _MovieCategory.upcoming),
              ],
            ),
    );
  }

  /// Builds the widget displaying search results. If results are loading
  /// a progress indicator is shown. Otherwise each result is rendered
  /// similarly to the cards used in the tab views. Results do not
  /// support pagination; only the first page of TMDb search results is
  /// displayed.
  Widget _buildSearchResults() {
    if (_searchLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return const Center(child: Text('没有搜索结果'));
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final movie = _searchResults[index];
        final id = movie['id'];
        final isFav = (id is int) && _favIds.contains(id);
        return MovieCardItem(
          movie: movie,
          isFavorite: isFav,
          onToggleFavorite: () => _toggleFavoriteForSearch(movie),
        );
      },
    );
  }
}

/// Enum describing the different movie list categories.
enum _MovieCategory {
  highScore,
  topRated,
  popular,
  nowPlaying,
  chinaNowPopular,
  upcoming,
}

/// A list widget that loads and displays movies for a specific
/// [_MovieCategory]. The first tab uses a vote count threshold of 5000 to
/// approximate a high‑score ranking; other tabs call TMDb endpoints
/// directly. Movies are fetched page by page; when the user scrolls to
/// the bottom of the list the next page is loaded.
class _MovieListTab extends StatefulWidget {
  final _MovieCategory category;
  const _MovieListTab({required this.category});

  @override
  State<_MovieListTab> createState() => _MovieListTabState();
}

class _MovieListTabState extends State<_MovieListTab> {
  final List<Map<String, dynamic>> _movies = [];
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _initialised = false;
  late MovieFavoriteDao _favDao;
  Set<int> _favIds = {};
  String _token = '';

  @override
  void initState() {
    super.initState();
    _favDao = MovieFavoriteDao();
    _scrollController.addListener(_onScroll);
    _init();
  }

  Future<void> _init() async {
    // Load the TMDb token and initial favourite ids once.
    final cfgDao = ConfigDao();
    try {
      final token = await cfgDao.getMovieToken();
      _token = token;
    } catch (_) {
      _token = '';
    }
    try {
      _favIds = await _favDao.allFavoriteIds();
    } catch (_) {
      _favIds = {};
    }
    // Load the first page of movies.
    await _loadMore();
    _initialised = true;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loading && _currentPage < _totalPages) {
        _loadMore();
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    setState(() {
      _loading = true;
    });
    try {
      final service = TMDbService(token: _token);
      Map<String, dynamic> data;
      switch (widget.category) {
        case _MovieCategory.highScore:
          data = await service.discoverMovies(page: _currentPage, voteCount: 5000);
          break;
        case _MovieCategory.topRated:
          data = await service.topRatedMovies(page: _currentPage);
          break;
        case _MovieCategory.popular:
          data = await service.popularMovies(page: _currentPage);
          break;
        case _MovieCategory.nowPlaying:
          data = await service.nowPlayingMovies(page: _currentPage);
          break;
        case _MovieCategory.chinaNowPopular:
          // “中国榜”：热门上映中的中国电影。
          // 先拉取中国地区上映中的影片，再在客户端过滤 original_language=zh 并按 popularity 倒序。
          data = await service.nowPlayingMovies(page: _currentPage, region: 'CN');
          break;
        case _MovieCategory.upcoming:
          data = await service.upcomingMovies(page: _currentPage);
          break;
      }
      final results = data['results'];
      if (results is List) {
        var list = results.cast<Map<String, dynamic>>();
        if (widget.category == _MovieCategory.chinaNowPopular) {
          final filtered = list.where((m) => (m['original_language']?.toString() ?? '') == 'zh').toList();
          filtered.sort((a, b) {
            final pa = (a['popularity'] is num) ? (a['popularity'] as num).toDouble() : 0.0;
            final pb = (b['popularity'] is num) ? (b['popularity'] as num).toDouble() : 0.0;
            return pb.compareTo(pa);
          });
          list = filtered;
        }
        setState(() {
          _movies.addAll(list);
          _currentPage = (data['page'] as int?) ?? _currentPage;
          _totalPages = (data['total_pages'] as int?) ?? _totalPages;
        });
        _currentPage += 1;
      }
    } catch (e) {
      // ignore or show error
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> movie) async {
    final id = movie['id'];
    if (id is! int) return;
    final isFav = _favIds.contains(id);
    if (isFav) {
      await _favDao.deleteByTmdbId(id);
      setState(() {
        _favIds.remove(id);
      });
    } else {
      // Build map for insertion
      final data = {
        'tmdb_id': id,
        'title': (movie['title'] ?? movie['name'] ?? '').toString(),
        'overview': (movie['overview'] ?? '').toString(),
        'poster_path': movie['poster_path'],
        'backdrop_path': movie['backdrop_path'],
        'vote_average': movie['vote_average'],
        'vote_count': movie['vote_count'],
        'release_date': (movie['release_date'] ?? movie['first_air_date'] ?? '').toString(),
        'raw_json': jsonEncode(movie),
      };
      await _favDao.insert(data);
      setState(() {
        _favIds.add(id);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialised) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () async {
        // Reset pagination and reload
        setState(() {
          _movies.clear();
          _currentPage = 1;
          _totalPages = 1;
        });
        await _init();
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _movies.length + (_loading && _currentPage <= _totalPages ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _movies.length) {
            // loading indicator at bottom
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final movie = _movies[index];
          final id = movie['id'] as int?;
          final fav = id != null && _favIds.contains(id);
          return MovieCardItem(
            movie: movie,
            isFavorite: fav,
            onToggleFavorite: () => _toggleFavorite(movie),
          );
        },
      ),
    );
  }
}
