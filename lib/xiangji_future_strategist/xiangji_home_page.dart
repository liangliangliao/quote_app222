import 'package:flutter/material.dart';

import 'xiangji_campaign_action_pages.dart';
import 'xiangji_database.dart';
import 'xiangji_insight_pages.dart';
import 'xiangji_knowledge_pages.dart';
import 'xiangji_models.dart';
import 'xiangji_problem_pages.dart';
import 'xiangji_repository.dart';
import 'xiangji_ui_support.dart';

class XiangjiFutureStrategistHomePage extends StatefulWidget {
  const XiangjiFutureStrategistHomePage({super.key});

  @override
  State<XiangjiFutureStrategistHomePage> createState() =>
      _XiangjiFutureStrategistHomePageState();
}

class _XiangjiFutureStrategistHomePageState
    extends State<XiangjiFutureStrategistHomePage> {
  late final XiangjiDao _dao;
  late final XiangjiRepository _repository;
  final TextEditingController _firstQuestion = TextEditingController();
  bool _loading = true;
  bool _working = false;
  bool _plainLanguage = false;
  Object? _loadError;
  XiangjiDashboardSnapshot _dashboard = const XiangjiDashboardSnapshot();
  List<XiangjiProblemRecord> _problems = const <XiangjiProblemRecord>[];
  List<XiangjiCampaignRecord> _campaigns = const <XiangjiCampaignRecord>[];
  List<XiangjiActionRecord> _actions = const <XiangjiActionRecord>[];

  @override
  void initState() {
    super.initState();
    _dao = XiangjiDao();
    _repository = XiangjiRepository(dao: _dao);
    _load();
  }

  @override
  void dispose() {
    _firstQuestion.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _repository.initialize();
      final values = await Future.wait<Object?>(<Future<Object?>>[
        _repository.dashboard(),
        _repository.problems(),
        _repository.campaigns(),
        _repository.currentActions(),
        XiangjiDisplayPreferences.plainLanguage(),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard = values[0] as XiangjiDashboardSnapshot;
        _problems = values[1] as List<XiangjiProblemRecord>;
        _campaigns = values[2] as List<XiangjiCampaignRecord>;
        _actions = values[3] as List<XiangjiActionRecord>;
        _plainLanguage = values[4] as bool;
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _captureFirstProblem() async {
    final question = _firstQuestion.text.trim();
    if (question.isEmpty) {
      xiangjiShowMessage(context, '请先写下一个真实问题。');
      return;
    }
    setState(() => _working = true);
    try {
      final id = await _repository.createProblem(
        rawQuestion: question,
        rawContext: question,
      );
      _firstQuestion.clear();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => XiangjiProblemWorkspacePage(
            problemId: id,
            repository: _repository,
            dao: _dao,
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) xiangjiShowMessage(context, error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    await _load();
  }

  String _word(String military, String plain) =>
      _plainLanguage ? plain : military;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XiangjiPalette.mist,
      appBar: AppBar(
        title: Text(_word('向己 · 未来军师', '向己 · 未来决策助手')),
        backgroundColor: XiangjiPalette.mist,
        actions: [
          IconButton(
            tooltip: '此次知识来源',
            onPressed: () => _open(XiangjiRetrievalTracePage(dao: _dao)),
            icon: const Icon(Icons.route_outlined),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? XiangjiEmptyState(
                  title: '初始化失败',
                  message: _loadError.toString(),
                  icon: Icons.error_outline,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('重试'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                    children: [
                      _hero(),
                      const SizedBox(height: 12),
                      XiangjiAlertBanner(
                        state: _dashboard.alertState,
                        reason: _dashboard.alertReason,
                      ),
                      const SizedBox(height: 12),
                      _commandCenter(),
                      if (_problems.isEmpty) ...[
                        const SizedBox(height: 12),
                        _firstProblemCard(),
                      ],
                      const SizedBox(height: 12),
                      _navigation(),
                    ],
                  ),
                ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: XiangjiPalette.pine,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _word('今日指挥部', '今日概览'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            '从认识事实，到定义真问题，再到一个可验算的行动。',
            style: TextStyle(color: Color(0xFFDDECE6), height: 1.4),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metric('${_problems.length}', '进行中问题'),
              _metric('${_campaigns.length}', _word('战役', '重要项目')),
              _metric('${_actions.length}', '当前行动'),
              _metric('${_dashboard.unresolvedDebtCount}', '关键认识债务'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$value $label',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _commandCenter() {
    final campaign = _dashboard.primaryCampaign;
    final action = _dashboard.currentAction;
    return XiangjiSectionCard(
      title: _word('当前战略与唯一行动', '当前重点与下一步'),
      subtitle: '这里只显示最需要注意的内容；完整分析默认收起在对应工作页。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          XiangjiLabeledValue(
            label: '北极星',
            value: _dashboard.northStar,
          ),
          if (campaign != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: XiangjiPalette.mist,
                child: Icon(Icons.flag_outlined, color: XiangjiPalette.pine),
              ),
              title: Text(campaign.title),
              subtitle: Text(
                '${_word('战役', '项目')}状态：${campaign.state.label}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(XiangjiCampaignWorkspacePage(
                campaignId: campaign.id,
                repository: _repository,
                dao: _dao,
              )),
            )
          else
            const XiangjiLabeledValue(
              label: '当前主战役',
              value: '',
            ),
          if (_dashboard.keyGap.isNotEmpty)
            XiangjiLabeledValue(
              label: '关键缺口',
              value: _dashboard.keyGap,
            ),
          if (_dashboard.strategistJudgment.isNotEmpty)
            XiangjiLabeledValue(
              label: '当前候选判断（不是事实）',
              value: _dashboard.strategistJudgment,
            ),
          if (_dashboard.contingency.isNotEmpty)
            XiangjiLabeledValue(
              label: '预案触发条件',
              value: _dashboard.contingency,
            ),
          if (_dashboard.nextReviewAtMs > 0)
            XiangjiLabeledValue(
              label: '下次复核',
              value: xiangjiDateTime(_dashboard.nextReviewAtMs),
            ),
          const Divider(height: 24),
          if (action == null)
            const Text(
              '当前没有已选定行动。请先完成一个问题的认识与概念审查。',
              style: TextStyle(color: XiangjiPalette.muted, height: 1.4),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: XiangjiPalette.mist,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline,
                      color: XiangjiPalette.pine),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${action.state.label} · 预计 ${action.expectedMinutes} 分钟',
                          style: const TextStyle(
                            color: XiangjiPalette.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => _open(XiangjiActionModePage(
                      actionId: action.id,
                      repository: _repository,
                      dao: _dao,
                    )),
                    child: Text(_word('出征', '打开')),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _firstProblemCard() {
    return XiangjiSectionCard(
      title: '第一次使用：带一个真实问题来',
      subtitle: '不需要先整理成完美表达。系统先保留原话，再带你分开事实、解释和未知项。',
      child: Column(
        children: [
          TextField(
            controller: _firstQuestion,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '最近哪个问题最消耗你，而且现实结果很重要？',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _working ? null : _captureFirstProblem,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('保存原话并开始'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navigation() {
    final entries = <_XiangjiNavEntry>[
      _XiangjiNavEntry(
        icon: Icons.flag_outlined,
        title: _word('战役作战室', '重要项目'),
        subtitle: '值得一战、情报、战略、红队、决断',
        open: () => _open(XiangjiCampaignListPage(
          repository: _repository,
          dao: _dao,
        )),
      ),
      _XiangjiNavEntry(
        icon: Icons.account_tree_outlined,
        title: _word('人生问题解题纸', '问题工作页'),
        subtitle: '认识审查、真问题、算子与现实验算',
        open: () => _open(XiangjiProblemListPage(
          repository: _repository,
          dao: _dao,
        )),
      ),
      _XiangjiNavEntry(
        icon: Icons.hub_outlined,
        title: '我的认识世界',
        subtitle: '直接经验、候选判断、认识债务、概念版本',
        open: () => _open(XiangjiEpistemicWorldPage(dao: _dao)),
      ),
      _XiangjiNavEntry(
        icon: Icons.play_circle_outline,
        title: _word('出征行动', '当前行动'),
        subtitle: '一次只做一件事；完成后回填现实',
        open: () => _open(XiangjiActionListPage(
          repository: _repository,
          dao: _dao,
        )),
      ),
      _XiangjiNavEntry(
        icon: Icons.history_edu_outlined,
        title: _word('战史与个人兵法', '复盘与个人经验'),
        subtitle: '预测—现实、转折点、教训与 AI 失误',
        open: () => _open(XiangjiHistoryPage(dao: _dao)),
      ),
      _XiangjiNavEntry(
        icon: Icons.library_books_outlined,
        title: '我的知识库',
        subtitle: '原文、规则、来源、Provider 与检索追踪',
        open: () => _open(XiangjiKnowledgeCenterPage(dao: _dao)),
      ),
      _XiangjiNavEntry(
        icon: Icons.settings_outlined,
        title: '设置 · AI · 数据治理',
        subtitle: '五色监督、敏感数据、导出与模块删除',
        open: () => _open(XiangjiSettingsPage(
          dao: _dao,
          repository: _repository,
        )),
      ),
    ];
    return XiangjiSectionCard(
      title: '工作区',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 680 ? 2 : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: 92,
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return InkWell(
                onTap: entry.open,
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: XiangjiPalette.mist,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      Icon(entry.icon, color: XiangjiPalette.pine),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: XiangjiPalette.muted,
                                fontSize: 11,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _XiangjiNavEntry {
  const _XiangjiNavEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.open,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback open;
}
