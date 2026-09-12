import 'package:flutter/material.dart';

class EvidenceGrowthDiscoverEntry extends StatelessWidget {
  const EvidenceGrowthDiscoverEntry({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE6F4F0), Color(0xFFF2EEE4)]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFC8DDD7)),
          ),
          child: const Row(
            children: [
              _GrowthMark(),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('六模块证据成长', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    SizedBox(height: 5),
                    Text('把信念带进现实：行动 → 结果 → 复盘 → 改变', style: TextStyle(fontSize: 12.5, color: Color(0xFF506762), height: 1.35)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Color(0xFF24766C)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrowthMark extends StatelessWidget {
  const _GrowthMark();
  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: const Color(0xFF24766C), borderRadius: BorderRadius.circular(17)),
        child: const Icon(Icons.route_rounded, color: Colors.white, size: 29),
      );
}
