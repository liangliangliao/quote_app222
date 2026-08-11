import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'xiangji_dao.dart';
import 'xiangji_goal_mentor_page.dart';
import 'xiangji_models.dart';

class XiangjiDiscoverCard extends StatefulWidget {
  const XiangjiDiscoverCard({super.key});

  @override
  State<XiangjiDiscoverCard> createState() => _XiangjiDiscoverCardState();
}

class _XiangjiDiscoverCardState extends State<XiangjiDiscoverCard> {
  XiangjiGoal? _goal;
  XiangjiDailyStep? _step;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dao = XiangjiGoalMentorDao();
      final goal = await dao.activeGoal();
      final step = goal == null ? null : await dao.currentStep(goal.id);
      if (!mounted) return;
      setState(() {
        _goal = goal;
        _step = step;
      });
    } catch (_) {}
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const XiangjiGoalMentorPage(),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final goal = _goal;
    final step = _step;
    final subtitle = goal == null
        ? '从一句真实的话开始，找回方向并走出一个可控行动'
        : step != null && (step.status == 'ready' || step.status == 'in_progress')
            ? '今日一步：${step.actionText}'
            : '记得你重视的方向：${goal.originalText}';
    return Semantics(
      button: true,
      label: '向己智能目标导师，$subtitle',
      child: Material(
        color: const Color(0xFFF4F0E6),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _open,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF315D4D),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.north_east_rounded, color: Colors.white, size: 25),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Text(
                            '向己 · 智能目标导师',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF20342D)),
                          ),
                          if (goal != null) ...<Widget>[
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDDE9E1),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                goal.state.label,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF3D725D), fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF5D6F66)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF3D725D)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
