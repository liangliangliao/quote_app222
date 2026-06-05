import 'package:flutter/material.dart';
import 'belief_dao.dart';
import 'belief_ui.dart';
import 'belief_concepts_page.dart';
import 'belief_episode_list_page.dart';
import 'belief_mission_list_page.dart';
import 'belief_diagnose_page.dart';
import 'belief_segments_library_page.dart';
import 'belief_stats_page.dart';

class BeliefLabHomePage extends StatefulWidget {
  const BeliefLabHomePage({super.key});

  @override
  State<BeliefLabHomePage> createState() => _BeliefLabHomePageState();
}

class _BeliefLabHomePageState extends State<BeliefLabHomePage> {
  bool _ready = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await BeliefDao().seedIfNeeded();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _err = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _err = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _err != null
        ? BeliefEmptyState(title: '初始化失败', subtitle: _err!)
        : !_ready
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                children: [
                  const Text(
                    '信念实验室',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '把“信念—情境—行动—复盘”做成可练习的关卡：学习 → 重演 → 行动 → 统计。',
                    style: TextStyle(color: Colors.black.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 14),
                  BeliefSectionCard(
                    title: '学习（概念地图）',
                    subtitle: '把 57 段内容按逻辑组织，直接学“能用的那部分”。',
                    icon: Icons.map_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BeliefConceptsPage()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BeliefSectionCard(
                    title: '重演（案例关卡）',
                    subtitle: '复刻 Bannister、Rosenthal、Stockdale、3Ms 等关键链条。',
                    icon: Icons.theaters_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BeliefEpisodeListPage()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BeliefSectionCard(
                    title: '行动（任务与复盘）',
                    subtitle: '把知识落地为 3 天/7 天任务：启动装置、失败日志、两栏计划等。',
                    icon: Icons.checklist_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BeliefMissionListPage()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BeliefSectionCard(
                    title: '诊断（我卡在哪？）',
                    subtitle: '用 10 题快速定位：是“放大/缩小”？是“失调拖延”？还是“情境太差”？',
                    icon: Icons.psychology_alt_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BeliefDiagnosePage()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BeliefSectionCard(
                    title: '资料库（57 段原文简化）',
                    subtitle: '按 Lecture 5/6/7 查看，支持关键词搜索与标签筛选。',
                    icon: Icons.library_books_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BeliefSegmentsLibraryPage()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BeliefSectionCard(
                    title: '统计（进度与复盘）',
                    subtitle: '看你完成了哪些关卡、最近的复盘、以及你的“基线”变化。',
                    icon: Icons.insights_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BeliefStatsPage()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '提示：这里的“信念”不是口号。每个关卡都要求你写下行动、做出一次试验、再做复盘。',
                      style: TextStyle(color: Colors.black.withOpacity(0.75)),
                    ),
                  ),
                ],
              );

    return Scaffold(
      appBar: AppBar(
        title: const Text('信念实验室'),
      ),
      body: content,
    );
  }
}
