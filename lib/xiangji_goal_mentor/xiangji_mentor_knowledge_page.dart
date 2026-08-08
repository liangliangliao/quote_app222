import 'package:flutter/material.dart';

import 'xiangji_knowledge_repository.dart';

class XiangjiMentorKnowledgePage extends StatefulWidget {
  const XiangjiMentorKnowledgePage({
    super.key,
    required this.catalog,
    this.selectedMentorId = '',
    this.onSelect,
    this.onEvent,
  });

  final XiangjiKnowledgeCatalog catalog;
  final String selectedMentorId;
  final Future<void> Function(String thinkerId)? onSelect;
  final Future<void> Function(
    String eventName,
    Map<String, Object?> properties,
  )? onEvent;

  @override
  State<XiangjiMentorKnowledgePage> createState() =>
      _XiangjiMentorKnowledgePageState();
}

class _XiangjiMentorKnowledgePageState
    extends State<XiangjiMentorKnowledgePage> {
  late String _mentorId;
  bool _showConcise = false;
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    _mentorId = widget.catalog.system(widget.selectedMentorId)?.id ??
        widget.catalog.systems.first.id;
  }

  XiangjiKnowledgeSystem get _mentor =>
      widget.catalog.system(_mentorId) ?? widget.catalog.systems.first;

  Future<void> _selectMentor() async {
    final callback = widget.onSelect;
    if (callback == null) return;
    setState(() => _selecting = true);
    try {
      await callback(_mentorId);
      if (!mounted) return;
      Navigator.pop(context, _mentorId);
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mentor = _mentor;
    final profile = mentor.profile!;
    final isCurrent = widget.selectedMentorId == mentor.id;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EB),
      appBar: AppBar(
        title: const Text('目标导师与知识路径'),
        backgroundColor: const Color(0xFFF6F3EB),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          Card(
            color: const Color(0xFFE6EFE9),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '选择一位导师，保持一条判断路径',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '导师不只是语气：选择会改变价值标准、目标设定步骤、每日实践和校准问题。',
                    style: TextStyle(height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: mentor.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '当前查看',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.catalog.systems
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(item.displayName),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _mentorId = value;
                        _showConcise = false;
                      });
                    },
                  ),
                  if (widget.onSelect != null) ...<Widget>[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _selecting || isCurrent ? null : _selectMentor,
                        icon: Icon(
                          isCurrent
                              ? Icons.check_circle_outline
                              : Icons.person_pin_outlined,
                        ),
                        label: Text(isCurrent ? '已是当前导师' : '选择这位导师'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _LevelCard(
            level: 'L0',
            title: profile.mentorTitle,
            initiallyExpanded: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _LabelledText(label: '核心问题', text: profile.centralQuestion),
                _LabelledText(label: '核心回答', text: profile.centralAnswer),
                _LabelledText(label: '为什么目标重要', text: profile.whyGoalMatters),
                _LabelledText(
                  label: '从迷茫到方向',
                  text: profile.fromConfusionToDirection,
                ),
                _LabelledText(
                  label: '现实转译原则',
                  text: profile.realityTranslation,
                ),
                const _ContentBadge(text: '原典基础上的知识库综合'),
                const SizedBox(height: 8),
                Text(
                  profile.sourceBasis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _journeyCard(mentor),
          const SizedBox(height: 10),
          const _LayerHeading(
            text: 'L1 · 4 个目标核心主题（默认展开）',
          ),
          ...mentor.primaryThemes.map(
            (theme) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _themeCard(mentor, theme, initiallyExpanded: true),
            ),
          ),
          const SizedBox(height: 18),
          const _LayerHeading(text: 'L2 · 3 个补充主题（按需展开）'),
          ...mentor.secondaryThemes.map(
            (theme) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _themeCard(mentor, theme),
            ),
          ),
          const SizedBox(height: 18),
          _modulesCard(mentor),
          const SizedBox(height: 10),
          _settingStepsCard(mentor),
          const SizedBox(height: 10),
          _practicesCard(mentor),
          const SizedBox(height: 10),
          _routesCard(mentor),
          const SizedBox(height: 10),
          _casesCard(mentor),
          const SizedBox(height: 18),
          _conciseCard(mentor),
        ],
      ),
    );
  }

  Widget _journeyCard(XiangjiKnowledgeSystem mentor) {
    final journey = mentor.journey!;
    return _LevelCard(
      level: '路径',
      title: journey.title,
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _LabelledText(label: '第一次提问', text: journey.firstPrompt),
          ...journey.stages.indexed.map(
            (entry) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFD9E9E1),
                child: Text('${entry.$1 + 1}'),
              ),
              title: Text(entry.$2),
            ),
          ),
          _LabelledText(label: '完成定义', text: journey.successDefinition),
        ],
      ),
    );
  }

  Widget _themeCard(
    XiangjiKnowledgeSystem mentor,
    XiangjiGoalTheme theme, {
    bool initiallyExpanded = false,
  }) {
    final evidence = mentor.evidence
        .where((item) => item.themeId == theme.id)
        .take(3)
        .toList(growable: false);
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text(
          theme.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          theme.coreQuestion,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _LabelledText(label: '核心回答', text: theme.coreAnswer),
                _LabelledText(label: '深层分析', text: theme.deepAnalysis),
                _LabelledText(
                  label: '目标设定转译',
                  text: theme.targetTranslation,
                ),
                _LabelledText(
                  label: '现实应用',
                  text: theme.realLifeApplication,
                ),
                _LabelledText(
                  label: '迷茫时如何问',
                  text: theme.confusionGuidance,
                ),
                _LabelledText(label: '边界', text: theme.boundaries),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('L4 · 原典依据 ${evidence.length} 条'),
                  subtitle: const Text('只显示短摘录与可回定位位置'),
                  children: evidence
                      .map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            widget.catalog.book(item.sourceId)?.title ??
                                item.sourceId,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${item.locator}\n${_clip(item.summary)}',
                          ),
                          isThreeLine: true,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modulesCard(XiangjiKnowledgeSystem mentor) {
    return _LevelCard(
      level: 'L3',
      title: '16 个深层知识模块',
      child: Column(
        children: mentor.modules
            .map(
              (module) => ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(module.title),
                subtitle: Text(module.category),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: <Widget>[
                  _LabelledText(label: '核心主张', text: module.coreClaim),
                  _LabelledText(label: '深层解释', text: module.explanation),
                  _LabelledText(label: '关键区分', text: module.distinctions),
                  _LabelledText(label: '应用', text: module.application),
                  if (module.questions.isNotEmpty)
                    _LabelledText(
                      label: '导师问题',
                      text: module.questions.join('；'),
                    ),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _settingStepsCard(XiangjiKnowledgeSystem mentor) {
    return _LevelCard(
      level: '设定',
      title: '8 步目标设定法',
      child: Column(
        children: mentor.settingSteps.indexed
            .map(
              (entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 14,
                  child: Text('${entry.$1 + 1}'),
                ),
                title: Text(entry.$2.title),
                subtitle: Text(
                  '${entry.$2.mentorQuestion}\n产出：${entry.$2.outputArtifact}',
                ),
                isThreeLine: true,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _practicesCard(XiangjiKnowledgeSystem mentor) {
    return _LevelCard(
      level: '实践',
      title: '6 个生活实践',
      child: Column(
        children: mentor.practices
            .map(
              (practice) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(practice.title),
                subtitle: Text(
                  '${practice.instruction}\n复盘：${practice.reflectionQuestion}',
                ),
                isThreeLine: true,
                trailing: Text(practice.cadence),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _routesCard(XiangjiKnowledgeSystem mentor) {
    return _LevelCard(
      level: '诊断',
      title: '6 条困境路由',
      child: Column(
        children: mentor.diagnosticRoutes
            .map(
              (route) => ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(route.problemType),
                subtitle: Text(route.userSignals.join(' · ')),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: <Widget>[
                  _LabelledText(label: '导师判断', text: route.interpretation),
                  _LabelledText(
                    label: '关键问题',
                    text: route.keyQuestions.join('；'),
                  ),
                  _LabelledText(
                    label: '引导顺序',
                    text: route.guidanceSequence.join(' → '),
                  ),
                  _LabelledText(label: '边界', text: route.caution),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _casesCard(XiangjiKnowledgeSystem mentor) {
    return _LevelCard(
      level: '案例',
      title: '4 个边界化案例',
      child: Column(
        children: mentor.cases
            .map(
              (item) => ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(item.title),
                subtitle: Text(item.userStatement),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: <Widget>[
                  _LabelledText(label: '诊断', text: item.diagnosis),
                  _LabelledText(label: '目标重写', text: item.targetReframe),
                  _LabelledText(label: '下一步', text: item.nextStep),
                  _LabelledText(label: '边界', text: item.caution),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _conciseCard(XiangjiKnowledgeSystem mentor) {
    final concise = widget.catalog.conciseProfile(mentor.id);
    if (concise == null) return const SizedBox.shrink();
    return Card(
      color: const Color(0xFFF0EEE7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '辅助短画像（默认隐藏）',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              '只有明确展开才显示；它是知识库综合，不是作者原话，也不会成为对用户的永久标签。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () async {
                final visible = !_showConcise;
                setState(() => _showConcise = visible);
                final callback = widget.onEvent;
                if (callback != null) {
                  await callback(
                    visible
                        ? 'thinker_concise_opened'
                        : 'thinker_concise_closed',
                    <String, Object?>{'mentor_id': mentor.id},
                  );
                }
              },
              child: Text(_showConcise ? '收起辅助短画像' : '明确展开辅助短画像'),
            ),
            if (_showConcise) ...<Widget>[
              const Divider(height: 24),
              const _ContentBadge(text: '知识库辅助综合 · 非作者原话'),
              const SizedBox(height: 8),
              Text(concise.oneSentenceSummary),
              const SizedBox(height: 8),
              Text(
                concise.differenceFocus,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String level;
  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFD9E9E1),
          child: Text(level, style: const TextStyle(fontSize: 11)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[Align(alignment: Alignment.centerLeft, child: child)],
      ),
    );
  }
}

class _LayerHeading extends StatelessWidget {
  const _LayerHeading({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800));
  }
}

class _LabelledText extends StatelessWidget {
  const _LabelledText({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label：',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: text),
          ],
        ),
        style: const TextStyle(height: 1.5),
      ),
    );
  }
}

class _ContentBadge extends StatelessWidget {
  const _ContentBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE6EFE9),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(text, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}

String _clip(String value, {int maxRunes = 160}) {
  final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  final runes = text.runes.toList(growable: false);
  if (runes.length <= maxRunes) return text;
  return '${String.fromCharCodes(runes.take(maxRunes))}…';
}
