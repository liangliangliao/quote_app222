import 'package:flutter/material.dart';
import 'hierarchy_statistics.dart';
import 'models.dart';

class CategoryHierarchyStatisticsView extends StatefulWidget {
  final List<QuoteCategory> categories;
  const CategoryHierarchyStatisticsView({super.key, required this.categories});
  @override
  State<CategoryHierarchyStatisticsView> createState() =>
      _CategoryHierarchyStatisticsViewState();
}

class _CategoryHierarchyStatisticsViewState
    extends State<CategoryHierarchyStatisticsView> {
  bool _occupied = false, _tree = false;
  int? _level;
  String? _focus;
  @override
  Widget build(BuildContext context) {
    final s =
        CategoryHierarchyStatistics(widget.categories, occupiedOnly: _occupied);
    final maximum = s.levels.values.fold(1, (a, b) => a > b ? a : b);
    final roots = _focus == null
        ? (s.children[''] ?? <QuoteCategory>[])
        : s.children[_focus] ?? <QuoteCategory>[];
    return Card(
        margin: const EdgeInsets.symmetric(vertical: 12),
        color: const Color(0xfffaf6ec),
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('概念分类结构',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final item in [
                      ('总层数', s.maxDepth),
                      ('根类别', s.roots),
                      ('父类别', s.parents),
                      ('子类别', s.subcategories),
                      ('叶类别', s.leaves)
                    ])
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10)),
                          child: Text('${item.$1} ${item.$2}',
                              style: const TextStyle(color: Color(0xff514631))))
                  ]),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('只统计已收录名言的类别',
                          style: TextStyle(fontSize: 12)),
                      value: _occupied,
                      onChanged: (v) => setState(() {
                            _occupied = v;
                            _focus = null;
                            _level = null;
                          })),
                  Text('共 ${s.categories.length} 个类别；根类别为第1层。父类别指有直接子类的类别。',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black54)),
                  if (s.invalid > 0) Text('另有 ${s.invalid} 个类别的上位关系异常，未计入层级。'),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(
                        label: const Text('层级分布'),
                        selected: !_tree,
                        onSelected: (_) => setState(() => _tree = false)),
                    ChoiceChip(
                        label: const Text('父子结构图'),
                        selected: _tree,
                        onSelected: (_) => setState(() => _tree = true))
                  ]),
                  if (!_tree) ...[
                    for (final level in s.levels.keys.toList()..sort())
                      Semantics(
                          label: '第$level层，${s.levels[level]}个类别',
                          button: true,
                          child: InkWell(
                              onTap: () => setState(() =>
                                  _level = _level == level ? null : level),
                              child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 7),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                            '第 $level 层 · ${s.levels[level]} 个类别',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: _level == level
                                                    ? FontWeight.w700
                                                    : FontWeight.normal)),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                            height: 15,
                                            child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: FractionallySizedBox(
                                                    widthFactor:
                                                        s.levels[level]! /
                                                            maximum,
                                                    child: DecoratedBox(
                                                        decoration: BoxDecoration(
                                                            color: _level ==
                                                                    level
                                                                ? const Color(
                                                                    0xffb48d4f)
                                                                : const Color(
                                                                    0xff99b4b5),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        5)),
                                                        child: const SizedBox
                                                            .expand())))),
                                      ])))),
                    if (_level != null)
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        for (final c in s.categories
                            .where((c) => s.depth[c.id] == _level))
                          ActionChip(
                              label: Text(c.name),
                              onPressed: () => setState(() {
                                    _tree = true;
                                    _focus =
                                        c.parentId.isEmpty ? null : c.parentId;
                                  }))
                      ]),
                  ] else ...[
                    if (_focus != null)
                      Row(children: [
                        IconButton(
                            tooltip: '返回上位类别',
                            onPressed: () => setState(() => _focus =
                                s.byId[_focus]?.parentId.isEmpty == true
                                    ? null
                                    : s.byId[_focus]?.parentId),
                            icon: const Icon(Icons.arrow_upward, size: 18)),
                        Expanded(child: Text(s.byId[_focus]?.name ?? '分类结构'))
                      ]),
                    for (final c in roots) _node(c, s, 0),
                    if (roots.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('此范围没有下位类别。')),
                  ],
                  const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('统计读取本地分类库，不调用 AI。类别层级表示主题组织，不等同于哲学上的抽象深度。',
                          style:
                              TextStyle(fontSize: 10, color: Colors.black54))),
                ])));
  }

  Widget _node(QuoteCategory c, CategoryHierarchyStatistics s, int depth) {
    final children = s.children[c.id] ?? <QuoteCategory>[];
    return Container(
        margin: EdgeInsets.only(left: depth == 0 ? 0 : 12),
        padding: const EdgeInsets.only(left: 6),
        decoration: depth == 0
            ? null
            : const BoxDecoration(
                border: Border(
                    left: BorderSide(color: Color(0xffbacbca), width: 1.5))),
        child: ExpansionTile(
            key: ValueKey('stats-node-${c.id}'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(
                children.isEmpty
                    ? Icons.circle_outlined
                    : Icons.account_tree_outlined,
                size: 18,
                color: const Color(0xff789599)),
            title: Text(c.name, style: const TextStyle(fontSize: 13)),
            subtitle: Text(
                '直属子类 ${children.length} · 全部下位类 ${s.descendants[c.id] ?? 0}',
                style: const TextStyle(fontSize: 11)),
            children: [
              if (depth >= 3 && children.isNotEmpty)
                TextButton(
                    onPressed: () => setState(() => _focus = c.id),
                    child: const Text('进入此分支继续查看'))
              else
                for (final child in children) _node(child, s, depth + 1)
            ]));
  }
}
