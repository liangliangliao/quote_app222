import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/global_ai_settings.dart';
import 'belief_lab_home_page.dart';
import 'belief_mentor_ai_service.dart';
import 'belief_mentor_dao.dart';
import 'belief_mentor_models.dart';
import 'belief_mentor_onboarding_page.dart';
import 'belief_mentor_reminder_service.dart';

class BeliefMentorHomePage extends StatefulWidget {
  const BeliefMentorHomePage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<BeliefMentorHomePage> createState() => _BeliefMentorHomePageState();
}

class _BeliefMentorHomePageState extends State<BeliefMentorHomePage> {
  final BeliefMentorDao _dao = BeliefMentorDao();
  late final BeliefMentorAiService _ai = BeliefMentorAiService(dao: _dao);
  late final BeliefMentorReminderService _reminders =
      BeliefMentorReminderService(dao: _dao);
  final TextEditingController _mentorInput = TextEditingController();
  final List<_MentorMessage> _messages = <_MentorMessage>[
    const _MentorMessage(
      text: '带来一个具体时刻就好。我会先区分事实与解释，再帮你找到一个可以在现实里检验的小动作。',
      isUser: false,
      source: '本地引导',
    ),
  ];

  BeliefMentorProfile? _profile;
  Future<BeliefMentorTodaySnapshot>? _todayFuture;
  Future<List<BeliefMentorBelief>>? _beliefsFuture;
  Future<List<BeliefMentorEvidence>>? _evidenceFuture;
  Future<BeliefMentorWeeklyReport>? _reportFuture;
  bool _loading = true;
  bool _mentorBusy = false;
  late int _tab = widget.initialTab.clamp(0, 4);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _mentorInput.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await _dao.profile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
      _todayFuture = _dao.today();
      _beliefsFuture = _dao.beliefs();
      _evidenceFuture = _dao.evidence();
      _reportFuture = _dao.weeklyReport();
    });
  }

  void _refreshData() {
    if (!mounted) return;
    setState(() {
      _todayFuture = _dao.today();
      _beliefsFuture = _dao.beliefs();
      _evidenceFuture = _dao.evidence();
      _reportFuture = _dao.weeklyReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_profile!.onboardingCompleted) {
      return BeliefMentorOnboardingPage(dao: _dao, ai: _ai, onCompleted: _load);
    }

    const titles = <String>['今天', '导师', '信念地图', '证据库', '设置'];
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F4ED),
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Belief Mentor'),
            Text(titles[_tab], style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: <Widget>[
          _todayTab(),
          _mentorTab(),
          _beliefsTab(),
          _evidenceTab(),
          _settingsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Mentor',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree),
            label: 'Beliefs',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Evidence',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _todayTab() => FutureBuilder<BeliefMentorTodaySnapshot>(
    future: _todayFuture,
    builder: (context, snapshot) {
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final value = snapshot.data!;
      if (value.belief == null) {
        return _emptyState(
          icon: Icons.psychology_alt_outlined,
          title: '先确认一个工作假设',
          text: '从最近一个具体时刻开始，提取候选信念，再由你确认。',
          action: '开始分析',
          onPressed: _addBeliefFromEvent,
        );
      }
      return RefreshIndicator(
        onRefresh: () async {
          _refreshData();
          await _todayFuture;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _todayHeader(value),
            const SizedBox(height: 14),
            _beliefCard(value.belief!),
            const SizedBox(height: 14),
            _experimentCard(value),
            const SizedBox(height: 14),
            if (value.openFailure != null) _recoveryCard(value.openFailure!),
            if (value.openFailure != null) const SizedBox(height: 14),
            if (value.nextReminder != null) _reminderCard(value.nextReminder!),
            if (value.nextReminder != null) const SizedBox(height: 14),
            if (value.latestEvidence != null)
              _latestEvidenceCard(value.latestEvidence!),
            if (value.latestEvidence != null) const SizedBox(height: 14),
            if (value.story != null) _storyCard(value.story!, value.belief!),
          ],
        ),
      );
    },
  );

  Widget _todayHeader(BeliefMentorTodaySnapshot value) {
    final now = DateTime.now();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${now.month}月${now.day}日',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 3),
              Text(
                value.experiment == null ? '今天，取得一条现实证据' : '今天，只推进下一个可见动作',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF315B4A),
          child: Text(
            '${value.belief?.strength ?? 0}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _beliefCard(BeliefMentorBelief belief) => Card(
    color: const Color(0xFFE4EFE8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar_outlined, color: Color(0xFF315B4A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '当前工作假设',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Chip(
                label: Text(belief.state.label),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '“${belief.statement}”',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800, height: 1.35),
          ),
          const SizedBox(height: 12),
          Text(
            '替代信念：${belief.alternativeStatement}',
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${belief.type.label} · 强度 ${belief.strength}/100'),
              const Spacer(),
              TextButton(
                onPressed: () => _rescoreBelief(belief),
                child: const Text('重新评分'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _experimentCard(BeliefMentorTodaySnapshot snapshot) {
    final experiment = snapshot.experiment;
    if (experiment == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.science_outlined,
                size: 30,
                color: Color(0xFF9A5A31),
              ),
              const SizedBox(height: 10),
              Text(
                '设计一个 24 小时微实验',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text('不是证明自己，而是用低风险行动取得一条可核验的新信息。'),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _createExperiment(snapshot.belief!),
                icon: const Icon(Icons.add_rounded),
                label: const Text('生成并审阅实验'),
              ),
            ],
          ),
        ),
      );
    }
    final scheduled = DateTime.fromMillisecondsSinceEpoch(
      experiment.scheduledAtMs,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science_outlined, color: Color(0xFF9A5A31)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '当前微实验',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Chip(
                  label: Text(experiment.state.label),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              experiment.action,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 10),
            _detailLine(
              Icons.schedule_outlined,
              '${scheduled.month}月${scheduled.day}日 ${_hm(scheduled)}',
            ),
            _detailLine(
              Icons.compress_outlined,
              '最小版本：${experiment.minimumVersion}',
            ),
            _detailLine(
              Icons.alt_route_outlined,
              '备用动作：${experiment.fallbackAction}',
            ),
            _detailLine(
              Icons.speed_outlined,
              '难度 ${experiment.difficulty}/10 · 预计完成 ${experiment.completionProbability}%',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (experiment.state == BeliefMentorExperimentState.scheduled ||
                    experiment.state == BeliefMentorExperimentState.draft)
                  FilledButton(
                    onPressed: () => _startExperiment(experiment),
                    child: const Text('现在开始'),
                  ),
                if (experiment.state == BeliefMentorExperimentState.started)
                  FilledButton(
                    onPressed: () => _completeExperiment(experiment),
                    child: const Text('完成行动'),
                  ),
                if (experiment.state == BeliefMentorExperimentState.completed)
                  FilledButton.icon(
                    onPressed: () => _captureEvidence(experiment),
                    icon: const Icon(Icons.add_task),
                    label: const Text('记录证据'),
                  ),
                if (experiment.state !=
                    BeliefMentorExperimentState.evidenceCreated)
                  OutlinedButton(
                    onPressed: () => _logFailure(experiment),
                    child: const Text('没有按计划进行'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reminderCard(BeliefMentorReminder reminder) {
    final time = DateTime.fromMillisecondsSinceEpoch(reminder.scheduledAtMs);
    return Card(
      color: const Color(0xFFFFF5DA),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFE5A7),
          child: Icon(Icons.notifications_active_outlined),
        ),
        title: Text('${reminder.type.label} · ${_hm(time)}'),
        subtitle: Text(
          reminder.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: TextButton(
          onPressed: () => _snoozeReminder(reminder),
          child: const Text('延后10分'),
        ),
      ),
    );
  }

  Widget _recoveryCard(BeliefMentorFailure failure) => Card(
    color: const Color(0xFFFFE7E2),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.healing_outlined, color: Color(0xFF8C3F32)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '恢复协议 · ${failure.stage}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (failure.facts.isNotEmpty) Text('事实：${failure.facts}'),
          if (failure.interpretation.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text('旧解释：${failure.interpretation}'),
          ],
          const SizedBox(height: 8),
          Text('最小恢复动作：${failure.nextStep}'),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => _closeRecovery(failure),
            child: const Text('我已重新行动'),
          ),
        ],
      ),
    ),
  );

  Widget _latestEvidenceCard(BeliefMentorEvidence evidence) => Card(
    color: const Color(0xFFE9EEF7),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined),
              const SizedBox(width: 8),
              Text(
                '最新现实证据 · ${evidence.strength.label}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(evidence.statement, style: const TextStyle(height: 1.5)),
          if (evidence.learning.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('学习：${evidence.learning}'),
          ],
        ],
      ),
    ),
  );

  Widget _storyCard(BeliefMentorStory story, BeliefMentorBelief belief) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showStory(story, belief),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFF0E5DA),
              child: Icon(Icons.auto_stories_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '研究与案例',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(story.title),
                  const SizedBox(height: 3),
                  Text(
                    '${story.evidenceGrade} · ${story.reviewStatus}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );

  Widget _mentorTab() => Column(
    children: [
      Container(
        width: double.infinity,
        color: const Color(0xFFE4EFE8),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: const Row(
          children: [
            Icon(Icons.shield_outlined, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '事实优先 · 推断可修改 · 行动要可验证',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _messages.length,
          itemBuilder: (context, index) => _messageBubble(_messages[index]),
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _mentorInput,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: '发生了什么？你当时怎么想？',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _mentorBusy ? null : _sendMentorMessage,
                icon: _mentorBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _messageBubble(_MentorMessage message) => Align(
    alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 560),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: message.isUser ? const Color(0xFF315B4A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: TextStyle(
              color: message.isUser ? Colors.white : Colors.black87,
              height: 1.5,
            ),
          ),
          if (!message.isUser && message.source.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              message.source,
              style: TextStyle(
                fontSize: 11,
                color: message.isUser ? Colors.white70 : Colors.black45,
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _beliefsTab() => FutureBuilder<List<BeliefMentorBelief>>(
    future: _beliefsFuture,
    builder: (context, snapshot) {
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final beliefs = snapshot.data!;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '你的信念不是标签，而是可更新的模型。',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: _addBeliefFromEvent,
                icon: const Icon(Icons.add),
                label: const Text('新增'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (beliefs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('还没有已确认信念。'),
              ),
            ),
          ...beliefs.map((belief) => _beliefMapCard(belief)),
          const SizedBox(height: 10),
          const Card(
            color: Color(0xFFF2F0E8),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('状态如何变化', style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text(
                    '确认 → 替代信念 → 现实检验 → 证据积累 → 转变 → 内化。每一步都需要用户确认、时间、行为、证据数量与自评分，AI 不能直接跳级。',
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _beliefMapCard(BeliefMentorBelief belief) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  belief.statement,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Chip(
                label: Text(belief.state.label),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${belief.type.label} · 触发：${belief.trigger.isEmpty ? '尚未补充' : belief.trigger}',
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: belief.strength / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
            color: const Color(0xFF9A5A31),
            backgroundColor: const Color(0xFFEAE4DB),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('当前强度 ${belief.strength}/100'),
              const Spacer(),
              TextButton(
                onPressed: () => _rescoreBelief(belief),
                child: const Text('更新'),
              ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text(
              '3M 与替代信念',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            children: [
              ListTile(
                dense: true,
                leading: const Text('Meaning'),
                title: Text(belief.statement),
              ),
              ListTile(
                dense: true,
                leading: const Text('Mindset'),
                title: Text(
                  '强度从 ${belief.initialStrength} 到 ${belief.strength}',
                ),
              ),
              const ListTile(
                dense: true,
                leading: Text('Motion'),
                title: Text('以实验启动、完成和证据记录为准，不以聊天次数为准'),
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.swap_horiz),
                title: Text(belief.alternativeStatement),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _evidenceTab() => FutureBuilder<List<BeliefMentorEvidence>>(
    future: _evidenceFuture,
    builder: (context, snapshot) {
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final items = snapshot.data!;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _weeklyReportCard(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '证据银行',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _captureManualEvidence,
                icon: const Icon(Icons.add),
                label: const Text('补记'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('记录预测—行动—结果—学习。单次证据只适用于这次情境，不自动推广到身份或未来。'),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('行动之后，把结果留下。第一条证据不需要“成功”，只需要真实。'),
              ),
            ),
          ...items.map(_evidenceCard),
        ],
      );
    },
  );

  Widget _weeklyReportCard() => FutureBuilder<BeliefMentorWeeklyReport>(
    future: _reportFuture,
    builder: (context, snapshot) {
      final report = snapshot.data;
      if (report == null)
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: LinearProgressIndicator(),
          ),
        );
      return Card(
        color: const Color(0xFF263D36),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '近 7 天现实检验',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _metric(
                    '启动率',
                    '${(report.actionInitiationRate * 100).round()}%',
                  ),
                  _metric('完成率', '${(report.completionRate * 100).round()}%'),
                  _metric(
                    '证据转化',
                    '${(report.evidenceConversion * 100).round()}%',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '自主启动 ${report.autonomousStarts} 次 · 恢复行动 ${report.recoveryActions} 次 · 每次启动平均提醒 ${report.averageReminderCount.toStringAsFixed(1)} 次',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _metric(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _evidenceCard(BeliefMentorEvidence item) {
    final date = DateTime.fromMillisecondsSinceEpoch(item.createdAtMs);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE9EEF7),
          child: Text(item.strength.label),
        ),
        title: Text(
          item.statement,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${date.month}月${date.day}日 · 情绪 ${item.emotionBefore} → ${item.emotionAfter}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _evidenceLine('预测', item.prediction),
          _evidenceLine('行动', item.action),
          _evidenceLine('结果', item.outcome),
          _evidenceLine('学习', item.learning),
          const SizedBox(height: 6),
          const Text(
            '边界：这条证据只说明本次条件下发生的结果。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _settingsTab() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
    children: [
      _aiSettingsCard(),
      const SizedBox(height: 12),
      Card(
        child: Column(
          children: [
            SwitchListTile.adaptive(
              title: const Text('主动提醒'),
              subtitle: Text(
                '安静时段 ${_profile!.quietStart}–${_profile!.quietEnd} · 每日注意力预算生效',
              ),
              value: _profile!.remindersEnabled,
              onChanged: _toggleReminders,
            ),
            const Divider(height: 1),
            SwitchListTile.adaptive(
              title: const Text('暂停所有主动干预'),
              subtitle: const Text('保留数据，不再新发提醒'),
              value: _profile!.notificationsPaused,
              onChanged: _setNotificationsPaused,
            ),
            ListTile(
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('安静时段'),
              subtitle: Text('${_profile!.quietStart}–${_profile!.quietEnd}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _editQuietHours,
            ),
            ListTile(
              leading: const Icon(Icons.self_improvement_outlined),
              title: const Text('我现在需要空间'),
              subtitle: Text(
                _profile!.needsSpaceAt(DateTime.now())
                    ? '已降低主动干预，24 小时后恢复'
                    : '暂停非恢复类提醒 24 小时',
              ),
              trailing: _profile!.needsSpaceAt(DateTime.now())
                  ? const Icon(Icons.check_circle, color: Color(0xFF315B4A))
                  : const Icon(Icons.chevron_right),
              onTap: _requestSpace,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('打开信念工坊课程库'),
              subtitle: const Text('保留原有课程、练习与案例内容'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BeliefLabHomePage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: const Text('导出我的数据'),
              subtitle: const Text('复制结构化 JSON 到剪贴板'),
              onTap: _exportData,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Card(
        color: Color(0xFFFFF5DA),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('安全边界', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 7),
              Text(
                'Belief Mentor 不提供医疗诊断或紧急援助。涉及自伤/伤人、妄想或偏执现实判断、躁狂式高风险行为、危险或违法计划时，普通教练流程会停止并建议寻求即时支持。',
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
        onPressed: _deleteAllData,
        icon: const Icon(Icons.delete_outline),
        label: const Text('删除全部 Belief Mentor 数据'),
      ),
    ],
  );

  Widget _aiSettingsCard() => FutureBuilder<Map<String, String>>(
    future: GlobalAiSettings().getState(),
    builder: (context, snapshot) {
      final state = snapshot.data;
      final available = state?['available'] == '1';
      return Card(
        color: available ? const Color(0xFFE4EFE8) : const Color(0xFFF2F0E8),
        child: ListTile(
          leading: Icon(
            available
                ? Icons.cloud_done_outlined
                : Icons.phone_android_outlined,
          ),
          title: Text(
            available ? '复用全局 AI：${state?['label'] ?? ''}' : '当前使用本地规则引擎',
          ),
          subtitle: Text(
            available
                ? '密钥与模型只由应用设置统一管理；本模块不保存新密钥。'
                : '在全局 AI 设置配置服务商后会自动启用；本地结果会明确标注。',
          ),
        ),
      );
    },
  );

  Future<void> _createExperiment(BeliefMentorBelief belief) async {
    _showBusy('正在生成可审阅的微实验…');
    final result = await _ai.generateExperiment(belief: belief);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    final draft = result.value;
    final action = TextEditingController(text: draft.action);
    final minimum = TextEditingController(text: draft.minimumVersion);
    final fallback = TextEditingController(text: draft.fallbackAction);
    var scheduledAt = DateTime.now().add(const Duration(hours: 2));
    var difficulty = draft.difficulty.toDouble();
    var probability = draft.completionProbability.toDouble();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '审阅微实验',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Chip(label: Text(result.usedCloudAi ? 'AI 辅助' : '本地建议')),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  draft.rationale,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: action,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '24 小时内行动',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minimum,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '最小版本',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fallback,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '备用动作',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('计划行动时间'),
                  subtitle: Text(
                    '${scheduledAt.month}月${scheduledAt.day}日 ${_hm(scheduledAt)}',
                  ),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                      initialDate: scheduledAt,
                    );
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(scheduledAt),
                    );
                    if (time == null) return;
                    setSheetState(
                      () => scheduledAt = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      ),
                    );
                  },
                ),
                Text('难度 ${difficulty.round()}/10'),
                Slider(
                  value: difficulty,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: (value) => setSheetState(() => difficulty = value),
                ),
                Text(
                  '预计完成概率 ${probability.round()}%${probability < 50 ? ' · 建议继续缩小' : ''}',
                ),
                Slider(
                  value: probability,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: (value) =>
                      setSheetState(() => probability = value),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('确认并安排'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final actionText = action.text;
    final minimumText = minimum.text;
    final fallbackText = fallback.text;
    action.dispose();
    minimum.dispose();
    fallback.dispose();
    if (confirmed != true) return;
    if (scheduledAt.isBefore(DateTime.now()))
      scheduledAt = DateTime.now().add(const Duration(minutes: 5));
    try {
      final experiment = await _dao.createExperiment(
        beliefId: belief.id,
        draft: BeliefMentorExperimentDraft(
          action: actionText,
          minimumVersion: minimumText,
          fallbackAction: fallbackText,
          difficulty: difficulty.round(),
          completionProbability: probability.round(),
          rationale: draft.rationale,
        ),
        scheduledAt: scheduledAt,
      );
      await _reminders.scheduleExperimentPlan(experiment);
      _refreshData();
      _show('实验已创建；提醒会按你的权限、安静时段与注意力预算安排。');
    } catch (error) {
      _show('无法创建实验：$error');
    }
  }

  Future<void> _startExperiment(BeliefMentorExperiment experiment) async {
    await _dao.startExperiment(experiment.id, source: 'self');
    _refreshData();
  }

  Future<void> _completeExperiment(BeliefMentorExperiment experiment) async {
    await _reminders.completeExperiment(experiment.id);
    _refreshData();
    if (mounted) await _captureEvidence(experiment);
  }

  Future<void> _captureEvidence(BeliefMentorExperiment experiment) =>
      _evidenceDialog(
        beliefId: experiment.beliefId,
        experimentId: experiment.id,
        prediction: '如果我执行这个动作，我原本预期会发生什么？',
        action: experiment.action,
      );

  Future<void> _captureManualEvidence() async {
    final beliefs = await _dao.beliefs();
    final confirmed = beliefs.where((item) => item.userConfirmed).toList();
    if (confirmed.isEmpty) {
      _show('请先确认一个信念');
      return;
    }
    await _evidenceDialog(
      beliefId: confirmed.first.id,
      experimentId: '',
      prediction: '',
      action: '',
    );
  }

  Future<void> _evidenceDialog({
    required String beliefId,
    required String experimentId,
    required String prediction,
    required String action,
  }) async {
    final predictionController = TextEditingController(text: prediction);
    final actionController = TextEditingController(text: action);
    final outcome = TextEditingController();
    final learning = TextEditingController();
    final statement = TextEditingController();
    var before = 6.0;
    var after = 4.0;
    var strength = BeliefMentorEvidenceStrength.medium;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('捕捉现实证据'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: predictionController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: '行动前预测'),
                  ),
                  TextField(
                    controller: actionController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: '实际行动'),
                  ),
                  TextField(
                    controller: outcome,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: '可观察结果'),
                  ),
                  TextField(
                    controller: learning,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: '从中学到什么'),
                  ),
                  TextField(
                    controller: statement,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '这条证据支持怎样的更准确表述',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('情绪强度：${before.round()} → ${after.round()}'),
                  Row(
                    children: [
                      const Text('前'),
                      Expanded(
                        child: Slider(
                          value: before,
                          min: 0,
                          max: 10,
                          divisions: 10,
                          onChanged: (value) =>
                              setDialogState(() => before = value),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('后'),
                      Expanded(
                        child: Slider(
                          value: after,
                          min: 0,
                          max: 10,
                          divisions: 10,
                          onChanged: (value) =>
                              setDialogState(() => after = value),
                        ),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<BeliefMentorEvidenceStrength>(
                    value: strength,
                    decoration: const InputDecoration(labelText: '证据强度'),
                    items: BeliefMentorEvidenceStrength.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) =>
                        setDialogState(() => strength = value ?? strength),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '防止过度概括：这次结果只适用于当时的对象、条件与行动。',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (actionController.text.trim().isEmpty ||
                    outcome.text.trim().isEmpty ||
                    statement.text.trim().isEmpty)
                  return;
                Navigator.pop(context, true);
              },
              child: const Text('保存证据'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _dao.saveEvidence(
        BeliefMentorEvidence(
          id: 'evidence_${DateTime.now().microsecondsSinceEpoch}',
          beliefId: beliefId,
          experimentId: experimentId,
          prediction: predictionController.text.trim(),
          action: actionController.text.trim(),
          outcome: outcome.text.trim(),
          emotionBefore: before.round(),
          emotionAfter: after.round(),
          learning: learning.text.trim(),
          statement: statement.text.trim(),
          strength: strength,
          createdAtMs: now,
        ),
      );
      _refreshData();
      _show('证据已保存。它不会被自动概括成身份结论。');
    }
    predictionController.dispose();
    actionController.dispose();
    outcome.dispose();
    learning.dispose();
    statement.dispose();
  }

  Future<void> _logFailure(BeliefMentorExperiment experiment) async {
    final facts = TextEditingController();
    final interpretation = TextEditingController();
    final emotion = TextEditingController();
    final next = TextEditingController(text: experiment.fallbackAction);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('T+0 · 先恢复，不审判'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('一次没按计划进行，不等于信念被证实。先把事实、解释与下一步分开。'),
                TextField(
                  controller: facts,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '事实：具体发生了什么'),
                ),
                TextField(
                  controller: interpretation,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '解释：你对它下了什么结论'),
                ),
                TextField(
                  controller: emotion,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '情绪与身体感受'),
                ),
                TextField(
                  controller: next,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '最小恢复动作'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('开始恢复'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await _dao.abandonExperiment(experiment.id);
      final failure = await _dao.createFailure(
        beliefId: experiment.beliefId,
        experimentId: experiment.id,
        facts: facts.text,
        interpretation: interpretation.text,
        emotion: emotion.text,
        nextStep: next.text,
      );
      await _reminders.scheduleRecoveryPlan(failure);
      _refreshData();
      _show('已进入恢复协议；同一次失败只会有一条恢复链。');
    }
    facts.dispose();
    interpretation.dispose();
    emotion.dispose();
    next.dispose();
  }

  Future<void> _snoozeReminder(BeliefMentorReminder reminder) async {
    await _reminders.snooze(reminder.id);
    _refreshData();
  }

  Future<void> _closeRecovery(BeliefMentorFailure failure) async {
    await _reminders.closeRecovery(failure);
    _refreshData();
    _show('恢复协议已完成。保留这次经验，然后从更小的一步继续。');
  }

  Future<void> _sendMentorMessage() async {
    final text = _mentorInput.text.trim();
    if (text.isEmpty) return;
    _mentorInput.clear();
    setState(() {
      _messages.add(_MentorMessage(text: text, isUser: true));
      _mentorBusy = true;
    });
    final beliefs = await _dao.beliefs();
    final active = beliefs.where((item) => item.userConfirmed).firstOrNull;
    final result = await _ai.mentorReply(message: text, belief: active);
    if (!mounted) return;
    setState(() {
      _mentorBusy = false;
      _messages.add(
        _MentorMessage(
          text: result.value.displayText,
          isUser: false,
          source: result.usedCloudAi
              ? '${result.provider} · ${result.model}'
              : '本地规则 · ${result.runStatus}',
        ),
      );
    });
  }

  Future<void> _addBeliefFromEvent() async {
    final event = TextEditingController();
    final thought = TextEditingController();
    final action = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从具体时刻提取候选信念'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: event,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '发生了什么'),
                ),
                TextField(
                  controller: thought,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '当时脑中的原话'),
                ),
                TextField(
                  controller: action,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '采取或回避的行动'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('分析'),
          ),
        ],
      ),
    );
    if (submitted != true) {
      event.dispose();
      thought.dispose();
      action.dispose();
      return;
    }
    _showBusy('正在区分事实、解释与候选信念…');
    final result = await _ai.diagnose(
      event: event.text,
      thought: thought.text,
      action: action.text,
    );
    event.dispose();
    thought.dispose();
    action.dispose();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (result.value.blocksNormalFlow) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('先确保安全'),
          content: Text(result.value.safetyMessage),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }
    var selected = 0;
    var strength = 70.0;
    final candidate = await showDialog<BeliefMentorCandidateBelief>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('由你确认候选信念'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...List<Widget>.generate(result.value.candidates.length, (
                    index,
                  ) {
                    final item = result.value.candidates[index];
                    return RadioListTile<int>(
                      value: index,
                      groupValue: selected,
                      onChanged: (value) =>
                          setDialogState(() => selected = value ?? 0),
                      title: Text(item.statement),
                      subtitle: Text('替代：${item.alternative}'),
                    );
                  }),
                  Text('当前强度 ${strength.round()}/100'),
                  Slider(
                    value: strength,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: (value) =>
                        setDialogState(() => strength = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, result.value.candidates[selected]),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );
    if (candidate == null) return;
    final now = DateTime.now();
    await _dao.saveBelief(
      BeliefMentorBelief(
        id: 'belief_${now.microsecondsSinceEpoch}',
        statement: candidate.statement,
        type: candidate.type,
        strength: strength.round(),
        initialStrength: strength.round(),
        trigger: candidate.trigger,
        alternativeStatement: candidate.alternative,
        state: BeliefMentorBeliefState.alternativeFormed,
        userConfirmed: true,
        createdAtMs: now.millisecondsSinceEpoch,
        updatedAtMs: now.millisecondsSinceEpoch,
      ),
    );
    _refreshData();
  }

  Future<void> _rescoreBelief(BeliefMentorBelief belief) async {
    var value = belief.strength.toDouble();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('现在这条信念有多强？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${value.round()}/100',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Slider(
                value: value,
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: (next) => setDialogState(() => value = next),
              ),
              const Text('状态不会仅因一次评分自动跳级；还会检查时间、行动与证据。'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _dao.rescoreBelief(belief.id, value.round());
      _refreshData();
    }
  }

  Future<void> _showStory(
    BeliefMentorStory story,
    BeliefMentorBelief belief,
  ) async {
    final started = DateTime.now();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.55,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              story.title,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(story.evidenceGrade)),
                Chip(label: Text(story.reviewStatus)),
                Chip(label: Text(story.sourceLabel)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              story.hook,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(story.story, style: const TextStyle(height: 1.6)),
            const SizedBox(height: 18),
            _storySection('可能机制', story.mechanism),
            _storySection('适用边界', story.boundary),
            _storySection('反思问题', story.reflection),
            _storySection('可尝试实验', story.experiment),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _createExperiment(belief);
              },
              child: const Text('把启发变成微实验'),
            ),
          ],
        ),
      ),
    );
    await _dao.recordStoryView(
      story.id,
      belief.id,
      durationSeconds: DateTime.now().difference(started).inSeconds,
    );
  }

  Future<void> _toggleReminders(bool value) async {
    if (value) {
      final granted = await _reminders.requestPermission();
      if (!granted) {
        _show('未获得通知权限，提醒仍保持关闭');
        return;
      }
    } else {
      await _reminders.cancelAll();
    }
    await _saveProfile(_profile!.copyWith(remindersEnabled: value));
    if (value) {
      await _resumeReminderPlan();
    }
  }

  Future<void> _setNotificationsPaused(bool value) async {
    if (value) await _reminders.cancelAll();
    await _saveProfile(_profile!.copyWith(notificationsPaused: value));
    if (!value && _profile!.remindersEnabled) await _resumeReminderPlan();
  }

  Future<void> _requestSpace() async {
    await _reminders.pauseNonRecovery();
    await _saveProfile(
      _profile!.copyWith(
        needsSpaceUntilMs: DateTime.now()
            .add(const Duration(hours: 24))
            .millisecondsSinceEpoch,
      ),
    );
    _refreshData();
  }

  Future<void> _resumeReminderPlan() async {
    final today = await _dao.today();
    if (today.belief != null) {
      await _reminders.scheduleMorningPrime(belief: today.belief!);
    }
    if (today.experiment != null) {
      await _reminders.scheduleExperimentPlan(today.experiment!);
    }
    _refreshData();
  }

  Future<void> _editQuietHours() async {
    TimeOfDay parse(String value) {
      final parts = value.split(':');
      return TimeOfDay(
        hour: int.tryParse(parts.first) ?? 22,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      );
    }

    final start = await showTimePicker(
      context: context,
      initialTime: parse(_profile!.quietStart),
      helpText: '安静时段开始',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: parse(_profile!.quietEnd),
      helpText: '安静时段结束',
    );
    if (end == null) return;
    await _saveProfile(
      _profile!.copyWith(
        quietStart: _timeString(start),
        quietEnd: _timeString(end),
      ),
    );
    if (_profile!.remindersEnabled && !_profile!.notificationsPaused) {
      await _reminders.rescheduleActiveForCurrentProfile();
      _refreshData();
    }
  }

  Future<void> _saveProfile(BeliefMentorProfile value) async {
    await _dao.saveProfile(value);
    if (!mounted) return;
    setState(() => _profile = value);
  }

  Future<void> _exportData() async {
    final data = await _dao.exportData();
    await Clipboard.setData(ClipboardData(text: data));
    _show('数据已复制到剪贴板');
  }

  Future<void> _deleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除全部数据？'),
        content: const Text('这会删除信念、实验、证据、提醒、导师运行记录与偏好。此操作不能在应用内撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _reminders.cancelAll();
    await _dao.deleteAllUserData();
    await _load();
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String text,
    required String action,
    required VoidCallback onPressed,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 58, color: const Color(0xFF315B4A)),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton(onPressed: onPressed, child: Text(action)),
        ],
      ),
    ),
  );

  Widget _detailLine(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Widget _evidenceLine(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _storySection(String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(height: 1.55)),
      ],
    ),
  );

  void _showBusy(String text) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 18),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static String _hm(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  static String _timeString(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class _MentorMessage {
  const _MentorMessage({
    required this.text,
    required this.isUser,
    this.source = '',
  });

  final String text;
  final bool isUser;
  final String source;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
