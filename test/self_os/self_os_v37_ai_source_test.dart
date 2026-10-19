import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_v37_ai.dart';
import 'package:quote_app/self_os/self_os_source_service.dart';
import 'self_os_v37_rules_test.dart' show decision;

Map<String, dynamic> proposal() => {
      'summary': '候选情景，尚待现实核验',
      'routes': [
        {
          'id': 'newRoute',
          'title': '小范围尝试',
          'mechanism': 'experiment',
          'mechanismDetail': '先进行可逆试验',
          'status': 'active'
        }
      ],
      'nodes': [
        {
          'id': 'newNode',
          'routeId': 'newRoute',
          'title': '获得观察',
          'order': 1,
          'horizon': 'near',
          'valence': 'mixed',
          'label': 'fact',
          'verified': true,
          'observedOutcome': '模型伪造结果'
        }
      ],
      'futureOptions': [
        {
          'id': 'fo',
          'routeId': 'newRoute',
          'nodeId': 'newNode',
          'title': '继续或退出',
          'delta': 'preserved'
        }
      ],
      'commitment': {'fake': true},
      'scores': {'actionProbability': 100},
      'signals': {'risk': 'low'},
    };

void main() {
  test('AI 候选不可写入事实、完成记录、主线或主观概率；采用前不修改原数据', () {
    final c = SelfOsCase(problem: '一个选择')..v37 = decision(risk: 'high');
    c.scores['actionProbability'] = 20;
    final p = OsAnalysisProposal.parse(proposal(), c);
    expect(c.v37.routes, hasLength(2));
    expect(c.commitment, isNull);
    final next = p.preview(c.v37);
    expect(next.routes.last.status, 'experimental');
    expect(next.nodes.single.label, 'unknown');
    expect(next.nodes.single.data.containsKey('verified'), isFalse);
    expect(next.nodes.single.text('observedOutcome'), isEmpty);
    expect(next.text('risk'), 'high');
    expect(c.scores['actionProbability'], 20);
    expect(next.nodes.single.routeId, next.routes.last.id);
    expect(next.futureOptions.single.text('nodeId'), next.nodes.single.id);
    expect(next.routes.last.id, isNot('newRoute'));
  });

  test('AI 不能覆盖已保存标识、引用伪造证据或悬空引用', () {
    final c = SelfOsCase(problem: '选择')..v37 = decision();
    for (final kind in ['overwrite', 'evidence', 'reference', 'motive']) {
      final p = osClone(proposal());
      if (kind == 'overwrite') (p['routes'] as List).first['id'] = 'a';
      if (kind == 'evidence')
        (p['futureOptions'] as List).first['evidenceIds'] = ['fake'];
      if (kind == 'reference')
        (p['nodes'] as List).first['routeId'] = 'missing';
      if (kind == 'motive')
        p['motiveChanges'] = [
          {'motiveId': 'missing', 'title': '伪造引用'}
        ];
      expect(() => OsAnalysisProposal.parse(p, c), throwsFormatException,
          reason: kind);
    }
  });

  test('已有机制够用允许停止；超负荷的候选、无 T* 的准备被拒绝', () {
    final c = SelfOsCase(problem: '选择')..v37 = decision();
    expect(
        OsAnalysisProposal.parse({'summary': '依据已有证据', 'stopReason': '候选足够'}, c)
            .count,
        0);
    final p = osClone(proposal());
    p['routes'] = List.generate(11, (i) => {'id': '$i'});
    expect(() => OsAnalysisProposal.parse(p, c), throwsFormatException);
    p['routes'] = [];
    p['nodes'] = [];
    p['futureOptions'] = [];
    p['interventions'] = [
      {
        'id': 'i',
        'type': 'read',
        'task': '读完',
        'source': '未知',
        'expectedChange': '认识',
        'window': 'now'
      }
    ];
    expect(() => OsAnalysisProposal.parse(p, c), throwsFormatException);
  });

  test('外部来源只读取指定 HTTPS 正文，摘录须匹配；读取不代表事实已核实', () async {
    final seen = <String>[];
    final client = MockClient((request) async {
      seen.add(request.url.toString());
      return http.Response(
          '<html><script>不要采用</script><style>hidden</style><p>原文 &amp; 事实\n有条件</p></html>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'});
    });
    final doc = await SelfOsSourceService(client: client)
        .retrieve('https://example.org/source');
    expect(seen, ['https://example.org/source']);
    expect(doc.text, '原文 & 事实 有条件');
    expect(doc.containsQuote('事实\n有条件'), isTrue);
    expect(doc.containsQuote('不同原文'), isFalse);
    expect(doc.containsQuote(''), isFalse);
    client.close();
  });

  test('来源拒绝不安全跳转、非正文、超长内容与失败响应', () async {
    for (final url in [
      'http://example.org',
      'https://user:password@example.org',
      'file:///tmp/test'
    ]) {
      expect(() => SelfOsSourceService.checkedUrl(url), throwsFormatException);
    }
    for (final mode in ['redirect', 'binary', 'large', 'failed']) {
      final client = MockClient((_) async => switch (mode) {
            'redirect' => http.Response('', 302,
                headers: {'location': 'http://example.org/insecure'}),
            'binary' => http.Response('pdf', 200,
                headers: {'content-type': 'application/pdf'}),
            'large' => http.Response('x' * (1024 * 1024 + 1), 200,
                headers: {'content-type': 'text/plain'}),
            _ => http.Response('failed', 503),
          });
      await expectLater(
          SelfOsSourceService(client: client).retrieve('https://example.org'),
          throwsFormatException,
          reason: mode);
      client.close();
    }
  });
}
