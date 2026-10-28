import 'package:flutter/material.dart';

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
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Set<String> categories;
  final VoidCallback onTap;
  final bool recommended;
  final Key? key;
  final Widget Function(VoidCallback onTap)? cardBuilder;
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

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = widget.destinations.where((item) {
      if (query.isNotEmpty) {
        return '${item.title} ${item.subtitle} ${item.categories.join(' ')}'
            .toLowerCase()
            .contains(query);
      }
      return _category == '推荐'
          ? item.recommended
          : item.categories.contains(_category);
    }).toList();
    const ink = Color(0xff263d35);
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        key: const PageStorageKey('discover-directory'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 90),
        children: [
          const Text(
            'A LITTLE CLOSER TO YOU',
            style: TextStyle(
              color: Color(0xff819287),
              fontSize: 10,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '发现之旅',
            style: TextStyle(
              color: ink,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            '从此刻出发，探索属于你的可能。',
            style: TextStyle(color: Color(0xff75857a), fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('discover-search'),
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Color(0xff819287)),
              hintText: '搜索你想探索的内容',
              hintStyle: const TextStyle(
                color: Color(0xffa0aaa2),
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      key: ValueKey('discover-category-$category'),
                      label: Text(category),
                      selected: _category == category,
                      showCheckmark: false,
                      side: BorderSide.none,
                      selectedColor: const Color(0xffdce9df),
                      backgroundColor: const Color(0xffeeefea),
                      labelStyle: TextStyle(
                        color: _category == category
                            ? ink
                            : const Color(0xff748178),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() {
                        _category = category;
                        _query = '';
                        _searchController.clear();
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  query.isEmpty
                      ? (_category == '推荐' ? '为你打开一扇门' : _category)
                      : '搜索结果',
                  style: const TextStyle(
                    color: ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${visible.length} 个入口',
                style: const TextStyle(color: Color(0xff94a197), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  '没有找到相关内容，试试其他关键词。',
                  style: TextStyle(color: Color(0xff819287)),
                ),
              ),
            )
          else
            for (final item in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: item.cardBuilder != null
                    ? item.cardBuilder!(item.onTap)
                    : Material(
                        key: item.key,
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: item.onTap,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xffeaf1ea),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    color: const Color(0xff5f7e68),
                                    size: 21,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: const TextStyle(
                                          color: ink,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        item.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xff8a988e),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 13,
                                  color: Color(0xffa2afa5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
        ],
      ),
    );
  }
}
