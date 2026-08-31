import 'package:flutter/material.dart';

import 'xiangji_campaign_action_pages.dart';
import 'xiangji_database.dart';
import 'xiangji_guidance_pages.dart';
import 'xiangji_insight_pages.dart';
import 'xiangji_knowledge_pages.dart';
import 'xiangji_models.dart';
import 'xiangji_practical_product.dart';
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
  int _section = 0;
  Object? _loadError;
  XiangjiDashboardSnapshot _dashboard = const XiangjiDashboardSnapshot();
  List<XiangjiProblemRecord> _problems = const <XiangjiProblemRecord>[];
  List<XiangjiCampaignRecord> _campaigns = const <XiangjiCampaignRecord>[];
  List<XiangjiActionRecord> _actions = const <XiangjiActionRecord>[];
  XiangjiUserPreferenceProfile _profile =
      const XiangjiUserPreferenceProfile();
  List<XiangjiGuidedCase> _guidedCases = const <XiangjiGuidedCase>[];
  int _practiceRounds = 0;
  int _conversationRevision = 0;
  String _conversationStarter = '';

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
        _repository.userPreferenceProfile(),
        _repository.guidedCases(),
        _repository.completedRealityRoundCount(),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard = values[0] as XiangjiDashboardSnapshot;
        _problems = values[1] as List<XiangjiProblemRecord>;
        _campaigns = values[2] as List<XiangjiCampaignRecord>;
        _actions = values[3] as List<XiangjiActionRecord>;
        _profile = values[4] as XiangjiUserPreferenceProfile;
        _guidedCases = values[5] as List<XiangjiGuidedCase>;
        _practiceRounds = values[6] as int;
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

  void _startConversation([String prompt = '']) {
    setState(() {
      _section = 1;
      _conversationStarter = prompt;
      _conversationRevision++;
    });
  }

  Future<void> _openUsageAssistant() async {
    final answer = await Navigator.of(context).push<XiangjiUsageAssistantAnswer>(
      MaterialPageRoute(builder: (_) => const XiangjiUsageAssistantPage()),
    );
    if (!mounted || answer == null) return;
    await _handleGuideDestination(answer.destination, answer.startPrompt);
  }

  Future<void> _openGuidedCases() async {
    final starter = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => XiangjiGuidedCasesPage(cases: _guidedCases),
      ),
    );
    if (!mounted || starter == null) return;
    _startConversation(starter);
  }

  Future<void> _openPreferences() async {
    final profile = await Navigator.of(context).push<XiangjiUserPreferenceProfile>(
      MaterialPageRoute(
        builder: (_) => XiangjiPreferenceSetupPage(
          repository: _repository,
          initialProfile: _profile,
        ),
      ),
    );
    if (!mounted || profile == null) return;
    setState(() {
      _profile = profile;
      _conversationRevision++;
    });
  }

  Future<void> _handleGuideDestination(
    String destination,
    String prompt,
  ) async {
    switch (destination) {
      case 'conversation':
        _startConversation(prompt);
        return;
      case 'examples':
        await _openGuidedCases();
        return;
      case 'current_action':
        if (_dashboard.currentAction != null) {
          await _open(XiangjiActionModePage(
            actionId: _dashboard.currentAction!.id,
            repository: _repository,
            dao: _dao,
          ));
        } else {
          _startConversation('我知道自己想做什么，但还没有形成一个可以开始的行动：');
        }
        return;
      case 'problem_workspace':
        if (_dashboard.currentProblem != null) {
          await _open(XiangjiProblemWorkspacePage(
            problemId: _dashboard.currentProblem!.id,
            repository: _repository,
            dao: _dao,
          ));
        } else {
          _startConversation(prompt);
        }
        return;
      case 'epistemic_world':
        await _open(XiangjiEpistemicWorldPage(
          dao: _dao,
          repository: _repository,
        ));
        return;
      case 'history':
        await _open(XiangjiHistoryPage(dao: _dao));
        return;
      case 'knowledge':
        await _open(XiangjiKnowledgeCenterPage(dao: _dao));
        return;
      case 'preferences':
        await _openPreferences();
        return;
      case 'settings':
        await _open(XiangjiSettingsPage(
          dao: _dao,
          repository: _repository,
        ));
        return;
      default:
        _startConversation(prompt);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XiangjiPalette.mist,
      appBar: AppBar(
        title: Text(
          _section == 0
              ? '向己·未来军师'
              : '说出问题或目标',
        ),
        backgroundColor: XiangjiPalette.mist,
        actions: [
          IconButton(
            tooltip: '不知道怎么用？问使用助手',
            onPressed: _openUsageAssistant,
            icon: const Icon(Icons.help_outline),
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
                  label: '现在',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome),
                  label: '说出需要',
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
                          _commandCenter(),
                          const SizedBox(height: 12),
                          _howItWorks(),
                          const SizedBox(height: 12),
                          _helpAndExamples(),
                          const SizedBox(height: 12),
                          _navigation(),
                        ],
                      ),
                    )
                  : XiangjiStrategistConversationPanel(
                      key: ValueKey<int>(_conversationRevision),
                      repository: _repository,
                      dao: _dao,
                      onDataChanged: _load,
                      initialText: _conversationStarter,
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
          const Text(
            '你现在想解决什么？',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            '只说一句问题、目标或卡点。军师负责分析，你只需要选择一个办法、做一步、回来告诉我实际发生了什么。',
            style: TextStyle(color: Color(0xFFDDECE6), height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: XiangjiPalette.pine,
            ),
            onPressed: () => _startConversation(),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('说出一个问题或目标'),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _starterChip('我有个目标', '我想实现一个目标：'),
              _starterChip('我卡住了', '我知道该做但就是没行动：'),
              _starterChip('我不知道怎么办', '我遇到一个问题，不知道下一步怎么办：'),
              _starterChip('我回来反馈', '我回来反馈上一步：实际发生的是……'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _starterChip(String label, String prompt) => ActionChip(
        backgroundColor: Colors.white.withValues(alpha: 0.13),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
        labelStyle: const TextStyle(color: Colors.white),
        avatar: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
        label: Text(label),
        onPressed: () => _startConversation(prompt),
      );

  Widget _commandCenter() {
    final action = _dashboard.currentAction;
    final awaitingReality = action?.state == XiangjiActionState.done;
    return XiangjiSectionCard(
      title: action == null ? '当前最值得做的事' : '现在只做这一件事',
      subtitle: _practiceRounds == 0
          ? '完成行动并回填现实，才算真正完成一轮。'
          : '你已经在现实中完成了 $_practiceRounds 轮练习；这里不统计阅读或打卡。',
      icon: action == null
          ? Icons.track_changes_outlined
          : awaitingReality
              ? Icons.fact_check_outlined
              : Icons.play_circle_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (action == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dashboard.currentProblem == null
                      ? '还没有正在处理的问题。你不需要先建立项目、填写表格或学习概念。'
                      : '当前问题还没有形成你已确认的行动；继续告诉军师新事实或修改理解。',
                  style: const TextStyle(
                    color: XiangjiPalette.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => _startConversation(
                    _dashboard.currentProblem == null
                        ? ''
                        : '继续这个问题，我现在补充：',
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(
                    _dashboard.currentProblem == null
                        ? '说出一个真实需要'
                        : '继续形成下一步',
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: awaitingReality
                    ? const Color(0xFFFFF1D6)
                    : XiangjiPalette.mist,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Icon(
                    awaitingReality
                        ? Icons.fact_check_outlined
                        : Icons.play_circle_outline,
                    color: awaitingReality
                        ? const Color(0xFFC8641B)
                        : XiangjiPalette.pine,
                  ),
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
                          awaitingReality
                              ? '行动已经结束；现在只需告诉军师实际发生了什么'
                              : '预计 ${action.expectedMinutes} 分钟；进入后只显示行动所需内容',
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
                    child: Text(awaitingReality ? '回填现实' : '现在开始'),
                  ),
                ],
              ),
            ),
          if (_dashboard.alertState != XiangjiAlertState.green) ...[
            const SizedBox(height: 10),
            XiangjiAlertBanner(
              state: _dashboard.alertState,
              reason: _dashboard.alertReason,
              defaultAction: _dashboard.alertDefaultAction,
            ),
          ],
          if (_dashboard.currentProblem != null) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('查看军师当前理解与依据'),
              childrenPadding: EdgeInsets.zero,
              children: [
                XiangjiLabeledValue(
                  label: '当前关键差距',
                  value: _dashboard.keyGap,
                  empty: '尚待现实信息确定',
                ),
                XiangjiLabeledValue(
                  label: '当前判断（可修订）',
                  value: _dashboard.strategistJudgment,
                  empty: '尚未形成',
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _open(
                      XiangjiProblemWorkspacePage(
                        problemId: _dashboard.currentProblem!.id,
                        repository: _repository,
                        dao: _dao,
                      ),
                    ),
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('打开完整解题台'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _howItWorks() => XiangjiSectionCard(
        title: '不用先学功能，只循环这四步',
        subtitle: '知识库在后台工作；每轮必须产生现实动作或现实修订。',
        child: Column(
          children: [
            for (final step in XiangjiPracticalProductContract.coreLoop)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: XiangjiPalette.mist,
                      child: Text(
                        '${XiangjiPracticalProductContract.coreLoop.indexOf(step) + 1}',
                        style: const TextStyle(
                          color: XiangjiPalette.pine,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step.title.substring(3),
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(step.userAction,
                              style: const TextStyle(
                                color: XiangjiPalette.muted,
                                height: 1.4,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _helpAndExamples() => XiangjiSectionCard(
        title: '第一次使用也能看懂',
        subtitle: '先看完整案例，或直接问“我现在该怎么做”。',
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: XiangjiPalette.mist,
                child: Icon(Icons.support_agent_outlined,
                    color: XiangjiPalette.pine),
              ),
              title: const Text('问使用助手',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('回答功能是什么、填什么、为什么，并带你到正确入口'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openUsageAssistant,
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: XiangjiPalette.mist,
                child: Icon(Icons.menu_book_outlined,
                    color: XiangjiPalette.pine),
              ),
              title: Text('查看 ${_guidedCases.length} 个完整案例',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('从原话、三种办法，到现实结果、改判和下一步'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openGuidedCases,
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: XiangjiPalette.mist,
                child: Icon(Icons.tune_outlined,
                    color: XiangjiPalette.pine),
              ),
              title: const Text('选择我的使用方式',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${_profile.energyLabel} · ${_profile.supportStyleLabel} · 偏好 ${_profile.preferredMinutes} 分钟',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openPreferences,
            ),
          ],
        ),
      );

  Widget _navigation() {
    final entries = <_XiangjiNavEntry>[
      _XiangjiNavEntry(
        icon: Icons.flag_outlined,
        title: '长期重要决定',
        subtitle: '只在高影响、多路线问题中查看资源、后手和退出条件',
        open: () => _open(XiangjiCampaignListPage(
          repository: _repository,
          dao: _dao,
        )),
      ),
      _XiangjiNavEntry(
        icon: Icons.account_tree_outlined,
        title: '完整问题记录',
        subtitle: '核对事实、解释、原因、根据、差距、办法与版本',
        open: () => _open(XiangjiProblemListPage(
          repository: _repository,
          dao: _dao,
        )),
      ),
      _XiangjiNavEntry(
        icon: Icons.hub_outlined,
        title: '我的认识变化',
        subtitle: '哪些是经验世界 I，哪些是概念世界 C，现实怎样改判',
        open: () => _open(XiangjiEpistemicWorldPage(
          dao: _dao,
          repository: _repository,
        )),
      ),
      _XiangjiNavEntry(
        icon: Icons.play_circle_outline,
        title: '全部行动',
        subtitle: '查看进行中、受阻以及等待现实反馈的行动',
        open: () => _open(XiangjiActionListPage(
          repository: _repository,
          dao: _dao,
        )),
      ),
      _XiangjiNavEntry(
        icon: Icons.history_edu_outlined,
        title: '复盘与个人经验',
        subtitle: '预测—现实、转折点、反例和可证伪的个人规律',
        open: () => _open(XiangjiHistoryPage(dao: _dao)),
      ),
      _XiangjiNavEntry(
        icon: Icons.library_books_outlined,
        title: '思想与知识依据',
        subtitle: '叔本华 L0、求解方法、来源和它们如何约束功能',
        open: () => _open(XiangjiKnowledgeCenterPage(dao: _dao)),
      ),
      _XiangjiNavEntry(
        icon: Icons.settings_outlined,
        title: '设置、AI 与数据',
        subtitle: 'AI 服务、主动提醒、敏感数据、导出和模块删除',
        open: () => _open(XiangjiSettingsPage(
          dao: _dao,
          repository: _repository,
        )),
      ),
    ];
    return XiangjiSectionCard(
      title: '更多工具（通常不需要打开）',
      subtitle:
          '${_problems.length} 个问题 · ${_campaigns.length} 个长期决定 · ${_actions.length} 个当前行动；默认入口已经能完成完整闭环。',
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('按需展开高级工作区'),
        subtitle: const Text('用于核对完整模型、来源、历史或设置'),
        childrenPadding: const EdgeInsets.only(top: 8),
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
