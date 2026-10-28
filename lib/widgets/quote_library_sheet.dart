import 'dart:async';
import 'package:flutter/material.dart';
import '../services/quote_library_store.dart';
import '../services/native_guard.dart';
import '../utils/quote_change_bus.dart';
import 'journey_design.dart';

class QuoteLibrarySheet extends StatefulWidget {
  const QuoteLibrarySheet({
    super.key,
    this.autofocus = false,
    this.favoritesOnly = false,
  });
  final bool autofocus, favoritesOnly;

  @override
  State<QuoteLibrarySheet> createState() => _QuoteLibrarySheetState();
}

class _QuoteLibrarySheetState extends State<QuoteLibrarySheet> {
  final _store = QuoteLibraryStore();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<Map<String, dynamic>> _rows = [], _bundled = [];
  List<String> _themes = [];
  String _theme = '';
  bool _favoritesOnly = false,
      _loading = true,
      _failed = false,
      _hasMore = false;
  int _generation = 0, _offset = 0;

  @override
  void initState() {
    super.initState();
    _favoritesOnly = widget.favoritesOnly;
    _scroll.addListener(_onScroll);
    SimpleBus.homeTick.addListener(_onQuoteChange);
    QuoteChangeBus.changes.addListener(_onQuoteChange);
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      _bundled = await _store.bundledQuotes();
      final savedThemes = await _store.themes();
      if (!mounted) return;
      _themes = {
        ...savedThemes,
        ..._bundled
            .map((row) => row['theme'].toString())
            .where((value) => value.trim().isNotEmpty),
      }.toList()..sort();
      await _reload();
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _failed = true;
        });
    }
  }

  void _onQuoteChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () => _reload());
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 250 &&
        _hasMore &&
        !_loading)
      unawaited(_reload(append: true));
  }

  bool _matches(Map<String, dynamic> row) {
    final query = _search.text.trim().toLowerCase();
    return (_theme.isEmpty || row['theme'] == _theme) &&
        (query.isEmpty ||
            '${row['content']} ${row['author_name']} ${row['theme']}'
                .toLowerCase()
                .contains(query));
  }

  Future<void> _reload({bool append = false, bool reset = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final offset = append ? _offset : 0;
      final limit = !append && !reset && _offset > 60 ? _offset : 60;
      final rows = _favoritesOnly
          ? (await _store.favorites()).where(_matches).toList()
          : await _store.page(
              query: _search.text,
              theme: _theme,
              offset: offset,
              limit: limit,
            );
      if (!mounted || generation != _generation) return;
      final hasMore = !_favoritesOnly && rows.length == limit;
      final nextRows = <Map<String, dynamic>>[if (append) ..._rows, ...rows];
      if (!_favoritesOnly && !hasMore)
        nextRows.addAll(_bundled.where(_matches));
      final seen = <String>{};
      setState(() {
        _rows = nextRows
            .where((row) => seen.add(QuoteLibraryStore.identity(row)))
            .toList();
        _offset = offset + rows.length;
        _hasMore = hasMore;
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    SimpleBus.homeTick.removeListener(_onQuoteChange);
    QuoteChangeBus.changes.removeListener(_onQuoteChange);
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 0, 22, 8),
              child: Text(
                '名言书房',
                style: TextStyle(
                  fontFamily: 'QuoteKaiShu',
                  color: journeyInk,
                  fontSize: 26,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                key: const ValueKey('quote-library-search'),
                controller: _search,
                focusNode: _focus,
                autofocus: widget.autofocus,
                style: const TextStyle(fontSize: 14, color: journeyInk),
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 220),
                    () => _reload(reset: true),
                  );
                },
                decoration: InputDecoration(
                  hintText: '搜索名言、人物或主题',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: journeyGreen,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (final favorites in [false, true])
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: JourneyFilterChip(
                        label: favorites ? '收藏' : '全部',
                        selected: _favoritesOnly == favorites,
                        onTap: () {
                          _debounce?.cancel();
                          setState(() => _favoritesOnly = favorites);
                          unawaited(_reload(reset: true));
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            if (_themes.isNotEmpty)
              SizedBox(
                height: 45,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  children: [
                    for (final theme in ['', ..._themes])
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: FilterChip(
                          label: Text(
                            theme.isEmpty ? '全部主题' : theme,
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: _theme == theme,
                          showCheckmark: false,
                          selectedColor: const Color(0xffe0eadd),
                          side: BorderSide.none,
                          onSelected: (_) {
                            _debounce?.cancel();
                            setState(() => _theme = theme);
                            unawaited(_reload(reset: true));
                          },
                        ),
                      ),
                  ],
                ),
              ),
            SizedBox(
              height: 2,
              child: _loading
                  ? const LinearProgressIndicator(
                      color: journeyGreen,
                      backgroundColor: Color(0xffe9ede4),
                      minHeight: 1.5,
                    )
                  : null,
            ),
            Expanded(
              child: _rows.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(25),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _loading
                                  ? '正在整理书房…'
                                  : _failed
                                  ? '名言暂时未能读取'
                                  : _favoritesOnly
                                  ? '把喜欢的思想收藏在这里。'
                                  : '还没有找到这句话，试试其他关键词。',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: journeyMuted,
                                height: 1.6,
                              ),
                            ),
                            if (_failed)
                              TextButton(
                                onPressed: _prepare,
                                child: const Text('重新读取'),
                              ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                      itemCount: _rows.length + (_hasMore || _failed ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _rows.length)
                          return Center(
                            child: TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => _reload(append: true),
                              child: Text(_failed ? '重新读取下一页' : '继续读更多名言'),
                            ),
                          );
                        final row = _rows[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: JourneySurface(
                            key: ValueKey(
                              'library-quote-${QuoteLibraryStore.identity(row)}',
                            ),
                            onTap: () => Navigator.pop(context, row),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    row['content'].toString(),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: journeyInk,
                                      fontSize: 15,
                                      height: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  Text(
                                    [row['author_name'], row['theme']]
                                        .map((v) => (v ?? '').toString())
                                        .where((v) => v.isNotEmpty)
                                        .join(' · '),
                                    style: const TextStyle(
                                      color: journeyMuted,
                                      fontSize: 11,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
