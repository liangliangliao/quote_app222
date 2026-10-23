part of 'self_os_guide_page.dart';

extension _GuideLearningPanel on _SelfOsGuidePageState {
  Future<bool> _saveRepresentationFeedback(
      String reviewId, Map<String, String> notes) async {
    if (_locked) return false;
    _draftTimer?.cancel();
    final draft = _c.copy();
    SelfOsRepresentationLearning.saveFeedback(
        draft.reviews.firstWhere((r) => r.id == reviewId), notes);
    _redraw(() => _saving = true);
    try {
      if (!await _persist(draft) || !mounted) return false;
      _redraw(() => _c = draft);
      return true;
    } finally {
      if (mounted) _redraw(() => _saving = false);
    }
  }

  Future<bool> _saveStrengthFeedback(
      String reviewId, Map<String, String> notes) async {
    if (_locked) return false;
    _draftTimer?.cancel();
    final draft = _c.copy();
    final profile = SelfOsProfile.fromJson(_profile.toJson());
    final review = draft.reviews.firstWhere((r) => r.id == reviewId);
    review.notes.addAll(notes);
    SelfOsStrengthLearning.applyFeedback(review, profile);
    _redraw(() => _saving = true);
    try {
      if (!await _persist(draft, profile: profile) || !mounted) return false;
      _redraw(() {
        _c = draft;
        _profile = profile;
      });
      return true;
    } finally {
      if (mounted) _redraw(() => _saving = false);
    }
  }

  Widget _calibrationCard(SelfOsReview review) {
    if (SelfOsLearning.calibrated(review)) {
      return OsSection(title: '认识已回到原问题', children: [
        _line(
            '这次怎样修正预期',
            SelfOsLearning.verdicts[review.notes['calibrationVerdict']] ??
                '保留未知'),
        _line('现在的认识', review.notes['calibrationConclusion'] ?? ''),
        _line('只用于这些情境', review.notes['calibrationScope'] ?? ''),
        _line(
            '对选择的影响',
            SelfOsLearning.influences[review.notes['calibrationInfluence']] ??
                ''),
        const Text('原先的预期和真实记录都保留，新的认识会用于下一步分析。',
            style: TextStyle(fontSize: 12, height: 1.5)),
      ]);
    }
    final d = g.draft.putIfAbsent(
        'calibrationDraft',
        () => <String, dynamic>{
              'conclusion': review.learning,
              'scope': review.context,
              if (review.outcome == 'notDone') 'verdict': 'unobserved',
            }) as Map<String, dynamic>;
    final experiment = osMap(review.snapshot['experiment']);
    final gap =
        _c.v37.gaps.where((v) => v.id == experiment['gapId']).firstOrNull;
    final canResolve = gap != null &&
        gap.text('access') != 'public' &&
        ['supported', 'weakened', 'mixed'].contains(d['verdict']);
    void change(String key, dynamic value) {
      _redraw(() {
        d[key] = value;
        if (key == 'verdict') d['resolveGap'] = false;
      });
      _draftChanged();
    }

    return OsSection(
        title: '让这次反馈真正改变下一步',
        subtitle: '对照原来的预期，确认这次多知道了什么，以及它怎样影响下一步。',
        children: [
          _line('要回答的原问题', osText(experiment['question'])),
          RadioGroup<String>(
            groupValue: osText(d['verdict']),
            onChanged: (v) {
              if (!_locked) change('verdict', v);
            },
            child: Column(children: [
              for (final e in SelfOsLearning.verdicts.entries)
                if (review.outcome != 'notDone' || e.key == 'unobserved')
                  RadioListTile<String>(
                    key: ValueKey('guide_calibration_${e.key}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.value, style: const TextStyle(fontSize: 14)),
                    value: e.key,
                    enabled: !_locked,
                  ),
            ]),
          ),
          _input('conclusion', '我现在怎样回答这个问题？', d),
          _input('scope', '这条认识只适用于哪些条件？', d,
              hint: '例如：只适用于这次小任务，不能代表所有岗位或长期授权'),
          const SizedBox(height: 8),
          const Text('这对接下来的选择有什么影响？'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final e in SelfOsLearning.influences.entries)
              ChoiceChip(
                  label: Text(e.value),
                  selected: d['influence'] == e.key,
                  onSelected:
                      _locked ? null : (_) => change('influence', e.key)),
          ]),
          if (canResolve)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('这个范围内的问题，已经足够清楚了吗？'),
              children: [
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('已对照现有材料，没有遗漏尚未解释的冲突'),
                    value: d['conflictsChecked'] == true,
                    onChanged:
                        _locked ? null : (v) => change('conflictsChecked', v)),
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    key: const ValueKey('guide_resolve_gap'),
                    title: const Text('这些观察足以回答本次范围内的问题，停止重复验证'),
                    value: d['resolveGap'] == true,
                    onChanged: _locked ? null : (v) => change('resolveGap', v)),
              ],
            ),
          const SizedBox(height: 12),
          _primary('把这条认识用到下一步', () async {
            if (await _transition((c) => SelfOsLearning.calibrate(
                  c,
                  reviewId: review.id,
                  verdict: osText(d['verdict']),
                  conclusion: osText(d['conclusion']),
                  scope: osText(d['scope']),
                  influence: osText(d['influence']),
                  resolveGap: d['resolveGap'] == true,
                  conflictsChecked: d['conflictsChecked'] == true,
                ))) _top();
          }, key: 'guide_calibrate'),
        ]);
  }

  Widget _nextStepCard() {
    var next = SelfOsProgress.next(_c);
    if (g.phase == 'explore' && _frame?.question['access'] == 'public') {
      next = OsNextStep(
          'retrieve', '这个问题需要可追溯的来源', osText(_frame!.question['text']),
          workspace: 1);
    }
    if (['explore', 'calibrate', 'act', 'plan', 'review'].contains(next.kind)) {
      return const SizedBox.shrink();
    }
    return OsSection(title: next.title, subtitle: next.reason, children: [
      if (next.workspace != null)
        OutlinedButton.icon(
            key: const ValueKey('guide_next_step'),
            onPressed: _locked ? null : () => _details(next.workspace),
            icon: const Icon(Icons.arrow_forward, size: 17),
            label: Text(switch (next.kind) {
              'retrieve' => '读取或核验相关来源',
              'verify' => '查看证据与修订依据',
              'prepare' => '继续这项准备',
              'decide' => '比较路径与真实取舍',
              'reentry' => '校准受影响的动机',
              'horizon' => '展开后续状态与未来路径',
              'alignment' => '查看本性、技能与可用力量',
              'conflict' => '看看两边为什么都重要',
              'routes' => '比较适合我的几种走法',
              _ => '补上当前需要的认识',
            })),
      if (next.engine != null)
        OutlinedButton.icon(
            key: const ValueKey('guide_next_engine'),
            onPressed: _locked
                ? null
                : () => _details(
                    5 + next.engine!.index,
                    switch (next.engine!) {
                      SelfOsEngine.desire => 'desires',
                      SelfOsEngine.motivation => 'motives',
                      SelfOsEngine.cognition => 'cognition',
                      SelfOsEngine.action => 'action',
                      _ => null,
                    }),
            icon: const Icon(Icons.arrow_forward, size: 17),
            label: Text('继续到${next.engine!.label}')),
      if (next.kind == 'assess' || next.analysisTask != null)
        TextButton.icon(
            key: const ValueKey('guide_analyse_next'),
            onPressed: _locked
                ? null
                : () => _analyseDecision(
                    next.analysisTask ?? 'gmrc', next.workspace ?? 1),
            icon: const Icon(Icons.auto_awesome_outlined, size: 17),
            label: const Text('结合我的记录，帮我继续分析')),
    ]);
  }

  Future<void> _analyseDecision(String task, int workspace) async {
    if (_locked) return;
    final ticket = ++_ticket;
    _draftTimer?.cancel();
    _redraw(() {
      _busy = true;
      _error = null;
      _progress = '正在对照实际反馈、竞争路径与尚未解决的未知…';
    });
    var saved = false;
    try {
      if (!await _persist(_c) || !mounted || ticket != _ticket) return;
      final proposal = await widget.ai.analyseV37(_c.copy(),
          [..._history.where((c) => c.id != _c.id), _c], _profile, task);
      if (!mounted || ticket != _ticket) return;
      final draft = _c.copy()..v37.pendingProposal = osClone(proposal.data);
      _redraw(() => _saving = true);
      if (!await _persist(draft) || !mounted || ticket != _ticket) return;
      _redraw(() => _c = draft);
      saved = true;
    } catch (e) {
      if (mounted && ticket == _ticket)
        _redraw(() => _error =
            e is FormatException ? e.message : '暂时无法继续分析，已有反馈已保存，可以先查看证据与路径。');
    } finally {
      if (mounted && ticket == _ticket)
        _redraw(() {
          _busy = false;
          _saving = false;
        });
    }
    if (saved && mounted) await _details(workspace);
  }
}
