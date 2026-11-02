import 'models.dart';

/// A stored category is counted once. Depth starts at 1 for roots; quote
/// membership counts and concept abstraction depth are separate measurements.
class CategoryHierarchyStatistics {
  final List<QuoteCategory> categories;
  late final byId = {for (final c in categories) c.id: c};
  late final children = <String, List<QuoteCategory>>{};
  final depth = <String, int>{}, descendants = <String, int>{};
  final levels = <int, int>{};
  CategoryHierarchyStatistics(List<QuoteCategory> all,
      {bool occupiedOnly = false})
      : categories =
            all.where((c) => !occupiedOnly || c.quoteCount > 0).toList() {
    for (final c in categories) {
      children.putIfAbsent(c.parentId, () => []).add(c);
    }
    final queue = [...(children[''] ?? <QuoteCategory>[])];
    for (final c in queue) {
      depth[c.id] = 1;
    }
    for (var i = 0; i < queue.length; i++) {
      final c = queue[i], level = depth[c.id]!;
      levels[level] = (levels[level] ?? 0) + 1;
      for (final child in children[c.id] ?? <QuoteCategory>[]) {
        if (depth.containsKey(child.id)) continue;
        depth[child.id] = level + 1;
        queue.add(child);
      }
    }
    for (final c in queue.reversed) {
      descendants[c.id] = (children[c.id] ?? <QuoteCategory>[])
          .fold(0, (n, child) => n + 1 + (descendants[child.id] ?? 0));
    }
  }
  int get maxDepth => levels.keys.fold(0, (a, b) => a > b ? a : b);
  int get roots => (children[''] ?? []).length;
  int get parents =>
      categories.where((c) => (children[c.id] ?? []).isNotEmpty).length;
  int get subcategories => categories
      .where((c) => c.parentId.isNotEmpty && byId.containsKey(c.parentId))
      .length;
  int get leaves => categories.length - parents;
  int get invalid => categories.length - depth.length;
}
