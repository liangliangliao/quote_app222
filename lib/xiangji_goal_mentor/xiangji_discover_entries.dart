import 'package:flutter/material.dart';

/// Keeps the two Xiangji products independently visible in Discover.
///
/// The goal mentor is the lightweight daily-goal loop. The future strategist
/// remains a separate deep problem-solving workspace and must not be hidden
/// behind goal-mentor initialization or data migrations.
class XiangjiDiscoverEntries extends StatelessWidget {
  const XiangjiDiscoverEntries({
    super.key,
    required this.onGoalMentorTap,
    required this.onFutureStrategistTap,
  });

  static const Key goalMentorKey =
      ValueKey<String>('discover_xiangji_goal_mentor');
  static const Key futureStrategistKey =
      ValueKey<String>('discover_xiangji_future_strategist');

  final VoidCallback onGoalMentorTap;
  final VoidCallback onFutureStrategistTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _XiangjiEntry(
          key: goalMentorKey,
          color: const Color(0xFFEEF5F1),
          iconBackground: const Color(0xFFD9E9E1),
          iconColor: const Color(0xFF245C4A),
          icon: Icons.explore_outlined,
          title: '向己 · 智能目标导师',
          subtitle: '一位导师 · 一个目标 · 一个行动 · 提醒 · 校准',
          onTap: onGoalMentorTap,
        ),
        const SizedBox(height: 12),
        _XiangjiEntry(
          key: futureStrategistKey,
          color: const Color(0xFFF4F1EA),
          iconBackground: const Color(0xFFE8E0CF),
          iconColor: const Color(0xFF705A2D),
          icon: Icons.hub_outlined,
          title: '向己 · 未来军师',
          subtitle: 'AI 总军师 · 自然语言求解 · 自动战略红队 · 现实验算',
          onTap: onFutureStrategistTap,
        ),
      ],
    );
  }
}

class _XiangjiEntry extends StatelessWidget {
  const _XiangjiEntry({
    super.key,
    required this.color,
    required this.iconBackground,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color color;
  final Color iconBackground;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title，$subtitle',
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: iconBackground,
                  child: Icon(icon, size: 21, color: iconColor),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF557064),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
