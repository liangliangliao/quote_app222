import 'dart:convert';
import 'package:quote_app/will_mirror/domain/model.dart';
import 'package:quote_app/will_mirror/domain/rules.dart';
import 'package:quote_app/will_mirror/data/store.dart';
import 'package:quote_app/will_mirror/ai/protocol.dart';
import 'package:quote_app/will_mirror/integration/reminders.dart';

final time = DateTime.utc(2025, 10, 14, 8);
final commands = CaseCommands(clock: () => time);
CaseFile newCase([String text = '我明天要确认岗位条件，也希望保留休息时间。']) =>
    commands.create(text);
MirrorNode route(CaseFile f,
        {String safety = 'clear', bool protective = false, String? id}) =>
    MirrorNode(
        id: id ?? newId('route'),
        caseId: f.id,
        episodeId: f.episodeId,
        kind: NodeKind.route,
        origin: EvidenceOrigin.aiHypothesis,
        phase: f.phase,
        recordedAt: time,
        knownAt: time,
        evidenceIds: [f.nodes.first.id],
        status: NodeStatus.draft,
        body: {
          'title': '先向招聘方核实条件',
          'description': '询问职责和时间安排',
          'firstStep': '发出问题',
          'family': 'verify',
          'wantIds': <String>[],
          'conditions': ['对方愿意说明'],
          'constraints': ['答复尚未取得'],
          'reversibility': 'reversible',
          'safety': safety,
          'feasibility': 'conditional',
          'verify': '取得书面答复',
          'protective': protective,
          'dailyProcess': ['收集信息'],
          'expectedBenefits': ['减少未知'],
          'expectedCosts': ['花费时间'],
          'explorationState': 'considered'
        });
MirrorNode motive(CaseFile f, int i,
        {String? semanticKey,
        String basis = 'explicit',
        String relation = 'supports',
        String horizon = 'now',
        bool critical = false,
        List<String>? refs}) =>
    commands.record(
        f,
        NodeKind.motive,
        {
          'summary': '理由 $i 的不同内容 ${String.fromCharCode(0x4e00 + i)}',
          'wantIds': <String>[],
          'beliefIds': <String>[],
          'representation': i.isEven ? 'intuitive' : 'abstract',
          'approach': 'approach',
          'horizon': horizon,
          'semanticKey': semanticKey ?? 'cause$i',
          'factStatus': 'hypothesized',
          'personalBasis': basis,
          'materiality': critical ? 'critical' : 'important',
          'riskWarning': critical,
          'unknowns': ['尚待具体检验'],
          'falsifier': '真实条件与预测不同',
          'counterReason': '也有相反考虑',
          'directionByRoute': [
            for (final r in f.current(NodeKind.route))
              {'routeId': r.id, 'relation': relation, 'reason': '当前条件下的可能作用'}
          ],
        },
        evidenceIds: refs ?? [f.nodes.first.id],
        origin: EvidenceOrigin.aiHypothesis,
        status: NodeStatus.draft);
Json planBody(CaseFile f) => {
      'routeId': f.selectedRouteId,
      'motiveIds': f.selectedMotiveIds,
      'sceneId': null,
      'principleId': null,
      'triggerSignal': '收到招聘方回复',
      'verifyFirst': ['确认实际职责'],
      'ifThen': '如果已获得答复，就先对照自己的条件',
      'fallback': '资料不足时继续核实',
      'safetyException': '有安全限制就暂停',
      'forecast': '可能还需要补充信息',
      'interventionIds': <String>[],
      'intention': 'conditional',
      'remindAt': null,
      'expiresAt': null,
      'userConfirmed': true
    };
CaseFile prepared() {
  var f = newCase();
  final r = route(f);
  f = commands.append(f, [r]);
  return commands.chooseRoute(f, r.id);
}

Json observationBody(CaseFile f,
        {String state = 'completed', String outcome = 'unknown'}) =>
    {
      'routeId': f.selectedRouteId,
      'attemptId': null,
      'actionState': state,
      'action': '发出了关于职责的询问',
      'externalOutcome': '尚未收到答复',
      'outcomeState': outcome,
      'feeling': '有些紧张',
      'noticedMotiveIds': <String>[],
      'context': '工作日白天',
      'domains': ['工作'],
      'opportunityId': null
    };

/// Repository tests substitute an authenticated opaque cipher. Android AES-GCM
/// itself is exercised by the native implementation/device checklist, not this fake.
class TestCipher implements VaultCipher {
  final Map<String, (String, String)> _values = {};
  int _next = 0;
  @override
  Future<String> encrypt(String cleartext, String context) async {
    final token = 'opaque-${_next++}';
    _values[token] = (context, cleartext);
    return token;
  }

  @override
  Future<String> decrypt(String ciphertext, String context) async {
    final pair = _values[ciphertext];
    if (pair == null || pair.$1 != context)
      throw const MirrorProblem('authentication failed');
    return pair.$2;
  }
}

class MemoryStore implements MirrorStore {
  final Map<String, CaseFile> data = {};
  final Map<String, List<CaseFile>> versions = {};
  MirrorSettings config = const MirrorSettings(animations: false);
  @override
  Future<List<CaseFile>> list() async => data.values.toList();
  @override
  Future<CaseFile?> load(String id) async => data[id];
  @override
  Future<void> save(CaseFile f, {required int expectedRevision}) async {
    if ((data[f.id]?.revision ?? 0) != expectedRevision)
      throw const VersionConflict();
    data[f.id] = f;
    versions.putIfAbsent(f.id, () => []).add(f);
  }

  @override
  Future<List<CaseFile>> history(String id) async => versions[id] ?? [];
  @override
  Future<Set<String>> retractEvidence(Set<String> ids) async {
    final affected = EvidenceRules.invalidationClosure(
        data.values.expand((f) => f.nodes), ids);
    final changed = <String>{};
    for (final f in data.values.toList()) {
      if (f.nodes.any((n) => affected.contains(n.id))) {
        data[f.id] = commands.retract(f, ids, affected: affected);
        changed.add(f.id);
      }
    }
    return changed;
  }

  @override
  Future<Set<String>> revokeCrossCase(String sourceCaseId) async {
    final original = data[sourceCaseId]!;
    final result =
        await retractEvidence(original.nodes.map((n) => n.id).toSet());
    data[sourceCaseId] = original;
    result.remove(sourceCaseId);
    return result;
  }

  @override
  Future<void> deleteCase(String id) async {
    await revokeCrossCase(id);
    data.remove(id);
    versions.remove(id);
  }

  @override
  Future<MirrorSettings> settings() async => config;
  @override
  Future<void> saveSettings(MirrorSettings settings) async {
    config = settings;
  }

  @override
  Future<String> exportJson() async =>
      jsonEncode(data.values.map((f) => f.toJson()).toList());
  @override
  Future<void> close() async {}
}

class TestReminders implements MirrorReminders {
  final Map<int, MirrorLink> jobs = {};
  final List<int> cancelled = [];
  bool permitted = true;
  @override
  Future<bool> requestPermission() async => permitted;
  @override
  Future<bool> schedule(int id, DateTime at, MirrorLink link) async {
    jobs[id] = link;
    return true;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    jobs.remove(id);
  }

  @override
  Future<Set<int>> pending() async => jobs.keys.toSet();
}

class OfflineModel implements StructuredModel {
  @override
  Future<bool> available() async => false;
  @override
  Future<String> label() async => '测试：未配置远程服务';
  @override
  Future<Json> complete(
          {required AnalysisStage stage,
          required String system,
          required String prompt,
          required Json schema,
          required CancelToken cancel}) async =>
      throw StateError('must never call');
}
