import 'package:flutter/material.dart';
import 'fp_dao.dart';
import 'fp_ui.dart';
import 'pages/fp_concepts_page.dart';
import 'pages/fp_learn_page.dart';
import 'pages/fp_practice_page.dart';
import 'pages/fp_journal_page.dart';
import 'tal/tal_failure_change.dart';

class FailureModuleHomePage extends StatefulWidget {
  const FailureModuleHomePage({super.key});

  @override
  State<FailureModuleHomePage> createState() => _FailureModuleHomePageState();
}

class _FailureModuleHomePageState extends State<FailureModuleHomePage> {
  bool _ready = false;
  String? _err;
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await FpDao().seedIfNeeded();
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
    if (_err != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('失败与完美主义')),
        body: FpEmptyState(title: '初始化失败', subtitle: _err!),
      );
    }
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = [
      const _FpDashboardPage(),
      const FpLearnPage(),
      const FpConceptsPage(),
      const FpPracticePage(),
      const FpJournalPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('失败与完美主义'),
      ),
      body: pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: '概览'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: '课程'),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: '概念'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), label: '行动'),
          NavigationDestination(icon: Icon(Icons.note_alt_outlined), label: '学习卡'),
        ],
      ),
    );
  }
}

class _FpDashboardPage extends StatelessWidget {
  const _FpDashboardPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        const Text('从一次真实经历，到下一次可观察的改变。', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          '可以先记事实，也可以暂不分析。认识、计划、执行与有效分别记录。',
          style: TextStyle(color: Colors.black.withOpacity(0.7)),
        ),
        const SizedBox(height: 14),
        FpSectionCard(
          title: '今天一件没有按计划发生的事',
          subtitle: '1–3 分钟 · 可跳过、可离线 · 继续、调整或退出由你决定。',
          icon: Icons.edit_note_outlined,
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TalReflectionPage())),
        ),
        const SizedBox(height: 12),
        FpSectionCard(
          title: '我刚失败了：3P急救',
          subtitle: '保留已有 App 模板；塔尔原著 PRP 三步骤可往返，行动与盖印为 App 扩展。',
          icon: Icons.health_and_safety_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FpPracticePage(openQuick3P: true)),
          ),
        ),
        const SizedBox(height: 12),
        FpSectionCard(
          title: '从一段课程开始',
          subtitle: '第14-16集按“概念-逻辑-行动”拆解，支持标记已学。',
          icon: Icons.menu_book_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FpLearnPage()),
          ),
        ),
        const SizedBox(height: 12),
        FpSectionCard(
          title: '直接练：失败复盘（AAR）',
          subtitle: '把一次失败写成可复用规则：目标→事实→原因→学习→下一步实验。',
          icon: Icons.edit_note_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FpPracticePage(openTaskId: 'TASK_A01')),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            '提示：这不是“积极鸡汤”。每个概念都对应一个现实动作：上场、粗稿、够好标准、暴露阶梯、复盘。',
            style: TextStyle(color: Colors.black.withOpacity(0.75)),
          ),
        ),
      ],
    );
  }
}
