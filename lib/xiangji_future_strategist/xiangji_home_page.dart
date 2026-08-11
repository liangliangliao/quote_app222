import 'package:flutter/material.dart';

import 'xiangji_campaign_action_pages.dart';
import 'xiangji_database.dart';
import 'xiangji_insight_pages.dart';
import 'xiangji_knowledge_pages.dart';
import 'xiangji_models.dart';
import 'xiangji_problem_pages.dart';
import 'xiangji_repository.dart';
import 'xiangji_strategist_conversation.dart';
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
  bool _loading = true;
  bool _plainLanguage = false;
  int _section = 0;
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
        title: Text(
          _section == 0
              ? _word('今日指挥部', '今日概览')
              : _word('与军师对话', '与决策助手对话'),
        ),
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
      bottomNavigationBar: _loadError == null && !_loading
          ? NavigationBar(
              selectedIndex: _section,
              onDestinationSelected: (value) => setState(() => _section = value),
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: '今日指挥部',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome),
                  label: '与军师对话',
                ),
              ],
            )
          : null,
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
              : _section == 0
                  ? RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                        children: [
                          _hero(),
                          const SizedBox(height: 12),
                          XiangjiAlertBanner(
                            state: _dashboard.alertState,
                            reason: _dashboard.alertReason,
                            defaultAction: _dashboard.alertDefaultAction,
                          ),
                          const SizedBox(height: 12),
                          _commandCenter(),
                          if (_problems.isEmpty) ...[
                            const SizedBox(height: 12),
                            XiangjiSectionCard(
                              title: '带一个真实问题来',
                              subtitle: '不需要先整理或填表，军师会自动完成认识建模、求解与红队。',
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FilledButton.icon(
                                  onPressed: () => setState(() => _section = 1),
                                  icon: const Icon(Icons.chat_outlined),
                                  label: const Text('与军师对话'),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _navigation(),
                        ],
                      ),
                    )
                  : XiangjiStrategistConversationPanel(
                      repository: _repository,
                      dao: _dao,
                      onDataChanged: _load,
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
            '军师在后台完成认识建模、判断、求解与红队；这里只保留真正重要的决定和行动。',
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
              value: '尚未建立需要长期投入的主战役',
            ),
          XiangjiLabeledValue(
            label: '目前最关键的差距',
            value: _dashboard.keyGap,
            empty: '尚未从当前问题中选出唯一关键差距',
          ),
          XiangjiLabeledValue(
            label:
                '军师一句判断（${_dashboard.strategistEpistemicStatus.isEmpty ? '可修订' : _dashboard.strategistEpistemicStatus}）',
            value: _dashboard.strategistJudgment,
            empty: '等你带来一个真实问题后形成',
            maxLines: 3,
          ),
          XiangjiLabeledValue(
            label: '出现什么就换路 / 停止 / 加码',
            value: _dashboard.contingency,
            empty: '尚未形成条件式后手',
          ),
          XiangjiLabeledValue(
            label: '下一次验算 / 军议',
            value: _dashboard.nextReviewAtMs > 0
                ? xiangjiDateTime(_dashboard.nextReviewAtMs)
                : '',
            empty: '形成当前行动后自动设定',
          ),
          if (_dashboard.currentProblem != null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _open(
                  XiangjiProblemWorkspacePage(
                    problemId: _dashboard.currentProblem!.id,
                    repository: _repository,
                    dao: _dao,
                  ),
                ),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('打开当前军师解题台'),
              ),
            ),
          const Divider(height: 24),
          const Text(
            '今日战斗',
            style: TextStyle(
              color: XiangjiPalette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (action == null)
            const Text(
              '当前没有已选定行动。直接告诉军师真实处境，系统会自动形成可确认的下一步。',
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
        subtitle: '认识审查、真问题、当前办法与现实验算',
        open: () => _open(XiangjiProblemListPage(
          repository: _repository,
          dao: _dao,
        )),
      ),
      _XiangjiNavEntry(
        icon: Icons.hub_outlined,
        title: '我的认识世界',
        subtitle: '直接经验、候选判断、认识债务、概念版本',
        open: () => _open(XiangjiEpistemicWorldPage(
          dao: _dao,
          repository: _repository,
        )),
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
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            Semantics(
              button: true,
              label: '${entries[index].title}，${entries[index].subtitle}',
              child: InkWell(
                onTap: entries[index].open,
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: XiangjiPalette.mist,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      Icon(entries[index].icon, color: XiangjiPalette.pine),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entries[index].title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entries[index].subtitle,
                              style: const TextStyle(
                                color: XiangjiPalette.muted,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            if (index != entries.length - 1) const SizedBox(height: 9),
          ],
        ],
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
