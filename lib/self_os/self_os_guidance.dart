import 'self_os_models.dart';
import 'self_os_progress.dart';

/// Translates user-confirmed guidance into the same V3.7 evidence model used by
/// the detailed workbenches. AI output alone never advances these transitions.
class SelfOsGuidance {
  static String next(SelfOsCase c) {
    final step = SelfOsProgress.next(c);
    if (step.kind != 'explore') return '${step.title}。${step.reason}';
    final frame = c.guide.frame;
    if (frame != null) {
      final question = osText(osMap(frame['question'])['text']);
      return question.isEmpty ? '确认这份理解是否符合你，再选择怎么验证。' : question;
    }
    return step.reason;
  }

  static Map<String, String> sources(SelfOsCase c) => {
        'problem': c.problem,
        for (final t in c.guide.turns.where((t) => t['role'] == 'user'))
          osText(t['id']): osText(t['text']),
      };
  static String latestSource(SelfOsCase c) =>
      c.guide.turns.where((t) => t['role'] == 'user').lastOrNull?['id'] ??
      'problem';

  static void answer(SelfOsCase c, String text, {bool correction = false}) {
    if (text.trim().isEmpty || text.length > 6000) {
      throw const FormatException('写下一点具体情况即可（最多 6000 字）');
    }
    final g = c.guide;
    g.turns.add({
      'id': selfOsId(),
      'role': 'user',
      'text': text.trim(),
      'kind': correction ? 'correction' : 'answer',
      'round': c.round,
      'createdAt': DateTime.now().toIso8601String(),
    });
    g.revision++;
    g.confirmedRevision = null;
    g.frame = null;
    g.phase = 'explore';
    g.compose = '';
    g.draft.clear();
    c.v37.settings['understandingReviewed'] = false;
    if (c.committedAt != null) {
      c.fields['newInformation'] = text.trim();
      c.v37.settings['newInformationReviewed'] = false;
      c.v37.settings['requiresReconsideration'] = true;
    }
  }

  static void receive(SelfOsCase c, OsGuideFrame frame, int revision) {
    if (c.guide.revision != revision) {
      throw const FormatException('你的输入已更新，旧分析未采用');
    }
    c.guide.frame = osClone(frame.data);
    c.guide.turns.add({
      'id': selfOsId(),
      'role': 'assistant',
      'round': c.round,
      'text': frame.text('understanding'),
      'question': osText(frame.question['text']),
      'frame': osClone(frame.data),
      'createdAt': DateTime.now().toIso8601String(),
    });
    // A risk suggestion may make review stricter; it cannot lower assessed risk.
    if (frame.text('risk') == 'high') {
      c.v37.settings['riskSuggestion'] = 'high';
      c.v37.settings['riskSuggestionReviewed'] = false;
    }
  }

  static const influences = {
    'toward': '尝试的理由更清楚了',
    'protect': '我更看重需要保护的东西',
    'unchanged': '理解更清楚，但暂不改变决定',
  };

  static void confirm(SelfOsCase c, String influence) {
    final g = c.guide;
    if (g.frame == null || !influences.containsKey(influence)) {
      throw const FormatException('先确认这份理解对你的影响');
    }
    if (g.confirmed) return;
    final f = OsGuideFrame.saved(g.frame!);
    if (!f.ready) throw const FormatException('先回答眼前最关键的问题');
    c.beginCognition();
    if (c.text('k1').isEmpty) {
      c.fields['k1'] = osText(f.insight['before']);
      // The endorsed original view belongs to the before snapshot.
      c.v37.knowledgeBefore!['knowledge'] = c.text('k1');
    }
    c.fields['k2'] = osText(f.insight['after']);
    c.fields['knowledgeSource'] = '引导中的用户确认（解释，尚待现实验证）';
    final desire =
        c.desires.where((d) => d.title == f.text('toward')).firstOrNull;
    final accepted = desire ??
        SelfOsDesire(
            title: f.text('toward'),
            source: '引导候选，经用户认可',
            support: f.text('understanding'),
            counter: f.text('protect'));
    accepted.verdict = 'accepted';
    if (desire == null) c.desires.add(accepted);
    for (final side in ['for', 'against']) {
      final id = 'guide_${c.id}_$side';
      final previous = c.motives.where((m) => m.id == id).firstOrNull;
      final m = previous ?? SelfOsMotive(id: id, side: side);
      m.title = f.text(side == 'for' ? 'toward' : 'protect');
      m.source = '引导候选，经用户认可';
      m.reason = osText(f.insight['reason']);
      m.kind = '概率推断';
      m.type = side == 'for' ? '长期目标' : '损失避免';
      m.selected = true;
      m.desireId = accepted.id;
      m.endorsement = 'believed';
      // Explicit user choice, never an invented strength or percentage.
      m.attention = (influence == 'toward' && side == 'for') ||
              (influence == 'protect' && side == 'against')
          ? 'foreground'
          : 'midground';
      if (previous == null) c.motives.add(m);
    }
    c.completeCognition(
      '${osText(f.insight['reason'])}\n我的确认：${influences[influence]}',
      noChangeReason: influence == 'unchanged' ? influences[influence]! : '',
    );
    // Keep alternatives symmetric. Their effects are hypotheses, not evidence.
    for (final r in f.routes) {
      final existing =
          c.v37.routes.where((v) => v.title == r['title']).firstOrNull;
      if (existing != null) continue;
      final route = OsRoute({
        'title': r['title'],
        'mechanism': r['mechanism'],
        'mechanismDetail': r['title'],
        'desire': accepted.title,
        'cost': r['cost'],
        'reality': '待核验：${r['unknown']}',
        'source': '引导中的待验证候选',
        'status': 'secondary',
      });
      c.v37.routes.add(route);
      for (final valence in ['benefit', 'cost']) {
        c.v37.nodes.add(OsConsequence({
          'routeId': route.id,
          'title': r[valence],
          'concrete': r[valence],
          'order': 1,
          'horizon': 'near',
          'valence': valence,
          'label': 'inference',
          'condition': r['unknown'],
          'source': '用户认可的解释，尚待现实检验',
        }));
      }
    }
    final priorGap =
        c.v37.gaps.where((g) => g.id == f.experiment['gapId']).firstOrNull;
    final gap = priorGap ??
        OsGap({
          'question': f.experiment['question'],
          'kind': 'fact',
          'access': 'experience',
          'source': '引导中确认的待验证问题',
        });
    if (priorGap == null) c.v37.gaps.add(gap);
    final route = c.v37.routes
        .where((r) => r.title == f.experiment['routeTitle'])
        .firstOrNull;
    g.draft.addAll({
      ...f.experiment,
      'gapId': gap.id,
      if (route != null) 'routeId': route.id,
      'influence': influence,
      'trigger': '',
      'costAccepted': false,
      'reversible': false,
      'cueAccepted': false,
    });
    g.confirmedRevision = g.revision;
    g.phase = 'plan';
    c.v37.settings['phase'] = 'filter';
    g.confirmations.add({
      'id': selfOsId(),
      'round': c.round,
      'revision': g.revision,
      'frame': osClone(f.data),
      'influence': influence,
      'createdAt': DateTime.now().toIso8601String(),
    });
    // This confirms an interpretation, not completeness of the large decision.
    c.v37.settings['understandingSummary'] = c.text('k2');
  }

  /// A bounded experiment has its own approval. It does not grant PASS to the
  /// underlying life decision or permit promotion to the global life line.
  static void commitExperiment(SelfOsCase c) {
    final g = c.guide, d = c.guide.draft;
    if (c.reviewed || !g.confirmed || g.phase != 'plan') {
      throw const FormatException('先确认当前理解，再安排验证动作');
    }
    for (final key in [
      'action',
      'question',
      'prediction',
      'observe',
      'boundary',
      'stopWhen',
      'trigger',
      'gapId'
    ]) {
      if (osText(d[key]).trim().isEmpty) {
        throw const FormatException('请补充动作、触发、观察与停止边界');
      }
    }
    if (d['costAccepted'] != true || d['reversible'] != true) {
      throw const FormatException('这个入口只安排你确认可承受、可撤回的小实验');
    }
    if (!c.v37.gaps.any((gap) => gap.id == d['gapId'])) {
      throw const FormatException('待验证的问题已改变，请重新梳理');
    }
    final moment = DateTime.tryParse(osText(d['moment']));
    if (moment != null && !moment.isAfter(DateTime.now())) {
      throw const FormatException('约定时刻已过去，请更新或清除该时间');
    }
    final gap = c.v37.gaps.singleWhere((gap) => gap.id == d['gapId']);
    if (gap.text('question') != osText(d['question'])) {
      gap.data.addAll({
        'question': osText(d['question']),
        'resolutionConfirmed': false,
        'sensitivityReviewed': false
      });
    }
    final route = c.v37.routes.where((r) => r.id == d['routeId']).firstOrNull;
    if (osText(d['routeId']).isNotEmpty && route == null) {
      throw const FormatException('关联的路径已改变，请重新选择');
    }
    if (route != null) {
      final prediction = OsConsequence({
        'routeId': route.id,
        'title': d['prediction'],
        'concrete': d['observe'],
        'order': 1,
        'horizon': 'near',
        'valence': 'mixed',
        'label': 'inference',
        'source': '第 ${c.round} 轮实验事前预期',
        'relevance': 'high',
        'gapId': gap.id,
      });
      c.v37.nodes.add(prediction);
      d['nodeId'] = prediction.id;
    }
    if (c.commitment != null)
      c.v37.priorCommitments.add(osClone(c.commitment!));
    c.fields.addAll({
      'firstAction': osText(d['action']),
      'trigger': osText(d['trigger']),
      'experiment': osText(d['question']),
      'experimentPrediction': osText(d['prediction']),
      'reconsiderWhen': osText(d['stopWhen']),
      'ritual': '',
    });
    for (final key in ['planProbability', 'actionProbability']) {
      final n = osNumber(d[key]);
      if (n == null) {
        c.scores.remove(key);
      } else {
        c.scores[key] = n;
      }
    }
    c.v37.settings['holdCue'] =
        d['cueAccepted'] == true ? osText(d['cue']) : '';
    c.v37.settings['holdSeconds'] = 15;
    // Only the user-confirmed revision can supersede an interrupted protocol.
    if (c.text('newInformation').isNotEmpty) {
      c.v37.settings['newInformationReviewed'] = true;
      c.v37.settings['requiresReconsideration'] = false;
    }
    if (moment != null) {
      c.v37.settings['futureMoment'] = moment.toIso8601String();
      final intervention = OsIntervention({
        'gapId': d['gapId'],
        'type': 'experiment',
        'window': 'now',
        'task': d['action'],
        'source': '本人实际观察：${d['observe']}',
        'expectedChange': d['question'],
        'dueAt': moment.toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      });
      c.v37.interventions.add(intervention);
      c.startIntervention(intervention);
      d['interventionId'] = intervention.id;
    }
    c.committedAt = DateTime.now();
    c.v37.settings['phase'] = 'experiment';
    c.commitment = osClone({
      ...c.evidenceSnapshot(),
      'commitmentScope': 'experiment',
      'experiment': osClone(d),
    });
    g.phase = 'act';
  }

  static void review(
    SelfOsCase c, {
    required String outcome,
    required String result,
    required String learning,
    required String context,
    String actualCost = '',
  }) {
    final snapshot = c.commitment ?? c.evidenceSnapshot();
    final review = SelfOsReview(
      round: c.round,
      outcome: outcome,
      result: result.trim(),
      learning: learning.trim(),
      context: context.trim(),
      snapshot: osClone(snapshot),
      notes: {
        'evidenceUse': 'usable',
        'actualCost': actualCost.trim(),
        'cognitionFeedback': 'unknown',
        'attribution': '未作因果归因'
      },
    );
    // Validate before changing any evidence or intervention state.
    c.addReview(review);
    final experiment = osMap(snapshot['experiment']);
    final i = c.v37.interventions
        .where((i) =>
            i.id == experiment['interventionId'] && i.started && !i.completed)
        .firstOrNull;
    c.fields['k3'] = review.learning;
    if (i != null) {
      c.completeIntervention(i, result);
      i.data['reviewId'] = review.id;
      i.data['actualOutcome'] = outcome;
    }
    c.v37.evidence.add(OsEvidence({
      'claim': result.trim(),
      'label': 'personal',
      'source': '本人第 ${c.round} 轮实际复盘 · ${review.id}',
      'quote': result.trim(),
      'verified': true,
      'observedAt': review.createdAt.toIso8601String(),
      'contradiction': 'unknown',
      'reviewId': review.id,
    }));
    // Observing once does not automatically resolve the gap or prove a cause.
    c.guide.phase = 'learn';
    c.guide.draft.remove('reviewDraft');
  }

  static void nextRound(SelfOsCase c) {
    c.nextRound();
  }
}
