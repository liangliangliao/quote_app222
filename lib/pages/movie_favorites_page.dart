import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../data/movie_favorite_dao.dart';
import '../widgets/movie_card_item.dart';

/// A page displaying the user's favourited movies stored locally. Users can
/// search by title via a simple text field. Each item uses the same card
/// layout as the ranking/search pages (favourite heart + “查看”).
class MovieFavoritesPage extends StatefulWidget {
  const MovieFavoritesPage({super.key});

  @override
  State<MovieFavoritesPage> createState() => _MovieFavoritesPageState();
}

class _MovieFavoritesPageState extends State<MovieFavoritesPage> {
  final MovieFavoriteDao _dao = MovieFavoriteDao();
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _movies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      _load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final query = _searchCtrl.text.trim();
      final rows = await _dao.listFavorites(query: query.isEmpty ? null : query);
      setState(() {
        _movies = rows;
      });
    } catch (_) {
      setState(() {
        _movies = [];
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _remove(Map<String, dynamic> movie) async {
    final id = movie['tmdb_id'];
    if (id is! int) return;
    await _dao.deleteByTmdbId(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏电影', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜索收藏的电影',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _movies.isEmpty
                    ? const Center(child: Text('暂无收藏'))
                    : ListView.builder(
                        itemCount: _movies.length,
                        itemBuilder: (context, index) {
                          final movie = _movies[index];
                          // Normalize db row to TMDb-like map expected by MovieCardItem.
                          final normalized = <String, dynamic>{
                            'id': movie['tmdb_id'],
                            'title': movie['title'],
                            'overview': movie['overview'],
                            'poster_path': movie['poster_path'],
                            'backdrop_path': movie['backdrop_path'],
                            'vote_average': movie['vote_average'],
                            'vote_count': movie['vote_count'],
                            'release_date': movie['release_date'],
                          };
                          return MovieCardItem(
                            movie: normalized,
                            isFavorite: true,
                            onToggleFavorite: () => _remove(movie),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}