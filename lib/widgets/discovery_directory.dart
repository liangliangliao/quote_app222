import 'package:flutter/material.dart';
import 'journey_design.dart';

class DiscoveryDestination {
  const DiscoveryDestination({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.categories,
    required this.onTap,
    this.recommended = false,
    this.key,
    this.cardBuilder,
    this.artwork = JourneyArt.mountains,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Set<String> categories;
  final VoidCallback onTap;
  final bool recommended;
  final Key? key;
  final Widget Function(VoidCallback onTap)? cardBuilder;
  final JourneyArt artwork;
}

/// A compact, searchable directory; each destination retains its own route.
class DiscoveryDirectory extends StatefulWidget {
  const DiscoveryDirectory({
    super.key,
    required this.destinations,
    required this.onRefresh,
  });
  final List<DiscoveryDestination> destinations;
  final Future<void> Function() onRefresh;

  @override
  State<DiscoveryDirectory> createState() => _DiscoveryDirectoryState();
}

class _DiscoveryDirectoryState extends State<DiscoveryDirectory> {
  static const _categories = ['推荐', '认识自己', '行动成长', '身心关怀', '灵感天地'];
  final _searchController = TextEditingController();
  String _category = '推荐';
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _chooseCategory(String category) {
    setState(() {
      _category = category;
      _query = '';
      _searchController.clear();
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _showIndex() async {
    final category = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: journeyPaper,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '从哪里开始？',
                style: TextStyle(
                  fontFamily: 'QuoteKaiShu',
                  color: journeyInk,
                  fontSize: 25,
                ),
              ),
              const SizedBox(height: 8),
              for (final category in _categories)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: JourneyIcon(_categoryIcons[category]!, size: 37),
                  title: Text(
                    category,
                    style: const TextStyle(color: journeyInk, fontSize: 14),
                  ),
                  trailing: Text(
                    '${widget.destinations.where((entry) => category == '推荐' ? entry.recommended : entry.categories.contains(category)).length} 个入口',
                    style: const TextStyle(color: journeyMuted, fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(context, category),
                ),
            ],
          ),
        ),
      ),
    );
    if (category != null && mounted) _chooseCategory(category);
  }

  static const _categoryIcons = {
    '推荐': Icons.eco_outlined,
    '认识自己': Icons.person_outline_rounded,
    '行动成长': Icons.bar_chart_rounded,
    '身心关怀': Icons.favorite_border_rounded,
    '灵感天地': Icons.lightbulb_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = widget.destinations.where((item) {
      if (query.isNotEmpty)
        return '${item.title} ${item.subtitle} ${item.categories.join(' ')}'
            .toLowerCase()
            .contains(query);
      return _category == '推荐'
          ? item.recommended
          : item.categories.contains(_category);
    }).toList();
    final inset = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: inset + 188,
          child: const JourneyHeaderBackdrop(discovery: true, opacity: .55),
        ),
        RefreshIndicator(
          color: journeyGreen,
          onRefresh: widget.onRefresh,
          child: ListView(
            key: const PageStorageKey('discover-directory'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, inset + 16, 16, 20),
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 11, right: 58),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A LITTLE CLOSER TO YOU',
                      style: TextStyle(
                        color: Color(0xff7e9083),
                        fontSize: 9,
                        height: 1.4,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      '发现之旅',
                      style: TextStyle(
                        fontFamily: 'QuoteKaiShu',
                        color: journeyInk,
                        fontSize: 34,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      '从此刻出发，探索属于你的可能。',
                      style: TextStyle(
                        color: Color(0xff829086),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(21),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x085f6c50),
                      blurRadius: 18,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: TextField(
                  key: const ValueKey('discover-search'),
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  style: const TextStyle(color: journeyInk, fontSize: 13),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xff7b9280),
                      size: 23,
                    ),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            tooltip: '清除搜索',
                            icon: const Icon(Icons.close_rounded, size: 19),
                            onPressed: () => setState(() {
                              _query = '';
                              _searchController.clear();
                            }),
                          )
                        : IconButton(
                            key: const ValueKey('discover-index'),
                            tooltip: '浏览入口索引',
                            icon: const Icon(
                              Icons.grid_view_rounded,
                              color: Color(0xff7b9280),
                              size: 21,
                            ),
                            onPressed: _showIndex,
                          ),
                    hintText: '搜索你想探索的内容',
                    hintStyle: const TextStyle(
                      color: Color(0xffa0aaa0),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xf5ffffff),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(21),
                      borderSide: const BorderSide(color: Color(0xeaffffff)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(21),
                      borderSide: const BorderSide(color: Color(0xeaffffff)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(21),
                      borderSide: const BorderSide(color: Color(0xffa4b79e)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 11),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final category in _categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: JourneyFilterChip(
                          key: ValueKey('discover-category-$category'),
                          label: category,
                          icon: _categoryIcons[category],
                          dense:
                              MediaQuery.sizeOf(context).width >= 360 &&
                              MediaQuery.textScalerOf(context).scale(12) <=
                                  13.2,
                          selected: _category == category,
                          onTap: () => _chooseCategory(category),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  children: [
                    Flexible(
                      flex: 4,
                      child: Text(
                        query.isEmpty
                            ? (_category == '推荐' ? '为你打开一扇门' : _category)
                            : '搜索结果',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'QuoteKaiShu',
                          color: journeyInk,
                          fontSize: 21,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (_category == '推荐' && query.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(left: 5),
                        child: Icon(
                          Icons.eco_rounded,
                          size: 15,
                          color: Color(0xff97ab79),
                        ),
                      ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Divider(color: Color(0xffe4e7de), height: 1),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${visible.length} 个入口',
                      style: const TextStyle(
                        color: Color(0xff9aa095),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      '没有找到相关内容，试试其他关键词。',
                      style: TextStyle(color: journeyMuted, fontSize: 12),
                    ),
                  ),
                )
              else
                for (final item in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: item.cardBuilder != null
                        ? item.cardBuilder!(item.onTap)
                        : _destinationCard(item),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _destinationCard(DiscoveryDestination item) => JourneySurface(
    key: item.key,
    onTap: item.onTap,
    child: Stack(
      children: [
        Positioned(
          right: -4,
          top: -4,
          bottom: -4,
          width: 152,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.transparent, Colors.white],
              stops: [0, .7],
            ).createShader(bounds),
            child: JourneyIllustration(item.artwork, opacity: .52),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              JourneyIcon(item.icon),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Color(0xff1d3329),
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff7d897c),
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xff50694e),
                size: 21,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
