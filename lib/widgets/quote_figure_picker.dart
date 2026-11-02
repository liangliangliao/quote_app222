import 'package:flutter/material.dart';

import '../services/quote_ai_service.dart';

/// Browse one field at a time or search across the entire built-in catalog.
class QuoteFigurePicker extends StatefulWidget {
  const QuoteFigurePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<QuoteFigurePicker> createState() => _QuoteFigurePickerState();
}

class _QuoteFigurePickerState extends State<QuoteFigurePicker> {
  String _category = quoteFigureCatalog.keys.first;
  String _query = '';

  void _setSelected(String name, bool selected) {
    final next = <String>{...widget.selected};
    if (selected) {
      next.add(name);
    } else {
      next.remove(name);
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final figures = query.isEmpty
        ? quoteFigureCatalog[_category]!
        : quoteFigureCatalog.values
              .expand((group) => group)
              .where((name) => name.toLowerCase().contains(query))
              .toSet()
              .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '代表人物',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xff293e35),
                ),
              ),
            ),
            Text(
              '已选 ${widget.selected.length}',
              style: const TextStyle(color: Color(0xff758579), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '按选择顺序轮流获取，也可以在下方添加自定义人物。',
          style: TextStyle(color: Color(0xff758579), fontSize: 12, height: 1.4),
        ),
        if (widget.selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final name in widget.selected)
                InputChip(
                  label: Text(name),
                  onDeleted: () => _setSelected(name, false),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('quote-figure-search'),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, size: 20),
            hintText: '搜索人物',
            isDense: true,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        if (query.isEmpty) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in quoteFigureCatalog.keys)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: category == _category,
                      onSelected: (_) => setState(() => _category = category),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (figures.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              '没有找到人物，可在下方自定义。',
              style: TextStyle(color: Color(0xff758579)),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final figure in figures)
                FilterChip(
                  label: Text(figure),
                  selected: widget.selected.contains(figure),
                  onSelected: (value) => _setSelected(figure, value),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
      ],
    );
  }
}
