import 'package:flutter/material.dart';

import 'belief_mentor_dao.dart';
import 'belief_mentor_models.dart';

class BeliefMentorDiscoverEntry extends StatefulWidget {
  const BeliefMentorDiscoverEntry({super.key, required this.onTap, this.dao});

  static const Key entryKey = ValueKey<String>('belief_mentor_discover_entry');

  final VoidCallback onTap;
  final BeliefMentorDao? dao;

  @override
  State<BeliefMentorDiscoverEntry> createState() =>
      _BeliefMentorDiscoverEntryState();
}

class _BeliefMentorDiscoverEntryState extends State<BeliefMentorDiscoverEntry> {
  late Future<_BeliefMentorEntrySnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BeliefMentorEntrySnapshot> _load() async {
    final dao = widget.dao ?? BeliefMentorDao();
    final profile = await dao.profile();
    final today = await dao.today();
    final evidence = await dao.evidence();
    return _BeliefMentorEntrySnapshot(
      profile: profile,
      today: today,
      evidenceCount: evidence.length,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<_BeliefMentorEntrySnapshot>(
    future: _future,
    builder: (context, snapshot) {
      final value = snapshot.data;
      final onboarded = value?.profile.onboardingCompleted ?? false;
      final experiment = value?.today.experiment;
      final subtitle = !onboarded
          ? '识别限制性信念 → 设计微实验 → 用现实证据更新'
          : experiment == null
          ? '已建立信念地图 · 下一步：安排一个 24 小时微实验'
          : '${experiment.state.label} · 已积累 ${value?.evidenceCount ?? 0} 条现实证据';
      return Material(
        key: BeliefMentorDiscoverEntry.entryKey,
        color: const Color(0xFF263D36),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 25,
                  backgroundColor: Color(0xFFE4EFE8),
                  child: Icon(
                    Icons.psychology_alt_outlined,
                    color: Color(0xFF263D36),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'Belief Mentor',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 8),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xFFE5B567),
                              borderRadius: BorderRadius.all(
                                Radius.circular(99),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              child: Text(
                                '现实检验',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _BeliefMentorEntrySnapshot {
  const _BeliefMentorEntrySnapshot({
    required this.profile,
    required this.today,
    required this.evidenceCount,
  });

  final BeliefMentorProfile profile;
  final BeliefMentorTodaySnapshot today;
  final int evidenceCount;
}
