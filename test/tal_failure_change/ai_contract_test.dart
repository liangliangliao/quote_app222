import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/failure_module/tal/tal_ai_contract.dart';
import 'fixtures.dart';

Map<String, dynamic> validResponse() => {
      'version': '1.0',
      'capture': {
        'facts': [
          {'text': '今天没去找工作', 'source_span': '今天没去找工作'}
        ],
        'thoughts': [],
        'emotions': [],
        'unknowns': ['原因尚不清楚']
      },
      'meaning': {
        'tentative_learning': '先记录事实',
        'confidence': 'low',
        'needs_more_evidence': true
      },
      'suggested_methods': [],
      'choice': {'continue_adjust_or_exit': 'undecided', 'user_decides': true},
      'proposed_trial': {
        'action': '',
        'trigger_or_time': '',
        'completion_evidence': '',
        'optional': true
      },
      'next_question': null,
      'safety': {
        'needs_crisis_exit': false,
        'no_diagnosis': true,
        'requires_consent_for_ai': true
      },
    };
void main() {
  final contract = TalAiContract(loadCatalog());
  const text = '今天没去找工作，原因不清楚';
  bool valid(Map<String, dynamic> m, {Set<String> methods = const {}}) =>
      contract.validate(jsonEncode(m),
          original: text, allowedMethods: methods) !=
      null;
  test('valid narrow extraction preserves original spans', () {
    expect(valid(validResponse()), isTrue);
  });
  test(
      'T12 no consent means zero AI calls; network errors keep local route available',
      () async {
    var calls = 0;
    final offline = TalAiAssistant(
        contract: contract,
        consented: () => false,
        call: (_) async {
          calls++;
          return jsonEncode(validResponse());
        });
    expect(await offline.extract(text, {}), isNull);
    expect(calls, 0);
    final failed = TalAiAssistant(
        contract: contract,
        consented: () => true,
        call: (_) async => throw StateError('offline'));
    expect(await failed.extract(text, {}), isNull);
    expect(loadCatalog().methods['explore_failures'], isNotNull);
  });
  test(
      'T13 rejects hidden motives, certainty, fabricated facts and unsupported confidence',
      () {
    for (final claim in ['潜意识自毁百分百确定', '一定成功', '你患有抑郁症', '永久改变']) {
      final m = validResponse();
      m['meaning']['tentative_learning'] = claim;
      expect(valid(m), isFalse, reason: claim);
    }
    final high = validResponse();
    high['meaning']['confidence'] = 'high';
    expect(valid(high), isFalse);
    final invented = validResponse();
    invented['capture']['facts'] = [
      {'text': '童年创伤让你拖延', 'source_span': '童年创伤让你拖延'}
    ];
    expect(valid(invented), isFalse);
  });
  test(
      'T14 rejects unsolicited cases and invented provenance; source limits must be exact',
      () {
    final m = validResponse();
    m['cases'] = [
      {'id': 'C99', 'story': '塔尔内心独白'}
    ];
    expect(valid(m), isFalse);
    final catalog = loadCatalog();
    final method = catalog.methods['three_ms']!;
    final withMethod = validResponse();
    withMethod['suggested_methods'] = [
      {
        'method_id': method.id,
        'why_this_case': '用户提到全盘定性',
        'provenance': method.provenance,
        'limitation': method.limit
      }
    ];
    expect(valid(withMethod, methods: {'three_ms'}), isTrue);
    expect(valid(withMethod), isFalse);
    withMethod['suggested_methods'][0]['provenance'] = 'tal_original_exercise';
    expect(valid(withMethod, methods: {'three_ms'}), isFalse);
  });
  test(
      'AI cannot decide the goal, force action, ask multiple questions or ignore safety',
      () {
    final exit = validResponse();
    exit['choice']['continue_adjust_or_exit'] = 'exit';
    expect(valid(exit), isFalse);
    final force = validResponse();
    force['proposed_trial']['optional'] = false;
    expect(valid(force), isFalse);
    final questions = validResponse();
    questions['next_question'] = '为什么？第一次想什么？';
    expect(valid(questions), isFalse);
    final unsafe = validResponse();
    unsafe['safety']['no_diagnosis'] = false;
    expect(valid(unsafe), isFalse);
    expect(contract.validate('{broken', original: text, allowedMethods: {}),
        isNull);
    expect(contract.validate('[]', original: text, allowedMethods: {}), isNull);
  });
  test('consent revoked while request is in flight discards its response',
      () async {
    var consent = true;
    final pending = Completer<String?>();
    final assistant = TalAiAssistant(
        contract: contract,
        consented: () => consent,
        call: (_) => pending.future);
    final result = assistant.extract(text, {});
    consent = false;
    pending.complete(jsonEncode(validResponse()));
    expect(await result, isNull);
  });
  test('T18 crisis input is refused before contacting the AI Provider',
      () async {
    var calls = 0;
    final assistant = TalAiAssistant(
        contract: contract,
        consented: () => true,
        call: (_) async {
          calls++;
          return jsonEncode(validResponse());
        });
    expect(await assistant.extract('我想伤害自己', {}), isNull);
    expect(calls, 0);
  });
}
