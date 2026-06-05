import 'package:flutter/material.dart';

class HealthDietDataSourceBanner extends StatelessWidget {
  const HealthDietDataSourceBanner({
    super.key,
    required this.sources,
    this.updatedAt,
    this.note,
    this.compact = false,
  });

  final List<String> sources;
  final DateTime? updatedAt;
  final String? note;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visible = sources.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    final timeText = updatedAt == null ? _minuteText(DateTime.now()) : _minuteText(updatedAt!);
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 8 : 12),
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dataset_outlined, size: 17, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '动态数据源 · 获取时间 $timeText',
                  style: TextStyle(fontSize: compact ? 12 : 13, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                ),
              ),
            ],
          ),
          if (!compact || visible.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: visible.isEmpty
                  ? const [HealthDietSourceChip(label: '本地静态说明')]
                  : visible.map((e) => HealthDietSourceChip(label: e)).toList(),
            ),
          ],
          if ((note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(note!.trim(), style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF64748B))),
          ],
        ],
      ),
    );
  }

  static String _minuteText(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}

class HealthDietSourceChip extends StatelessWidget {
  const HealthDietSourceChip({super.key, required this.label, this.important = false});

  final String label;
  final bool important;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: important ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: important ? const Color(0xFFFBBF24) : const Color(0xFFBFDBFE)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: important ? const Color(0xFF92400E) : const Color(0xFF1D4ED8)),
      ),
    );
  }
}
