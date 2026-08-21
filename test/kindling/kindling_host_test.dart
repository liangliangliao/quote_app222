import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/kindling/kindling.dart';
import 'package:quote_app/kindling/src/copy.dart';
import 'package:quote_app/kindling_host/kindling_ai_oracle.dart';
import 'package:quote_app/kindling_host/kindling_host_reminder.dart';

/// 宿主侧装配层的测试：AI 追问器必须在任何异常下退回本地实现。
/// 答过第一问之后的 history。空 history 会短路成本地问题梯，验不到模型校验。
const List<({String q, String? a})> _afterFirstAnswer = <({String q, String? a})>[
  (q: KCopy.resistance1, a: '怕做砸了被看见'),
];

void main() {
  KindlingAiOracle oracle({
    required bool available,
    Future<String> Function()? reply,
  }) {
    return KindlingAiOracle(
      isAvailable: () async => available,
      call: ({
        required String prompt,
        required String systemPrompt,
        required String purpose,
      }) async {
        if (reply == null) throw StateError('no reply configured');
        return reply();
      },
    );
  }

  group('候选切分', () {
    test('AI 不可用时用本地规则', () async {
      final List<String> out = await oracle(available: false)
          .extractCandidates(<String, String>{'itch': '译完第九节。改渲染管线'});
      expect(out, <String>['译完第九节', '改渲染管线']);
    });

    test('AI 抛错时用本地规则', () async {
      final KindlingAiOracle ai = KindlingAiOracle(
        isAvailable: () async => true,
        call: ({
          required String prompt,
          required String systemPrompt,
          required String purpose,
        }) async =>
            throw Exception('network down'),
      );
      final List<String> out =
          await ai.extractCandidates(<String, String>{'itch': '译完第九节'});
      expect(out, <String>['译完第九节']);
    });

    test('AI 返回空内容时用本地规则', () async {
      final List<String> out =
          await oracle(available: true, reply: () async => '   ')
              .extractCandidates(<String, String>{'itch': '译完第九节'});
      expect(out, <String>['译完第九节']);
    });

    test('AI 的切分同样受 2–40 字与去重约束', () async {
      final String long = '啊' * 60;
      final List<String> out = await oracle(
        available: true,
        reply: () async => '好\n$long\n译完第九节\n译完第九节',
      ).extractCandidates(<String, String>{'itch': '原话'});
      expect(out, <String>['译完第九节']);
    });
  });

  group('阻抗追问', () {
    test('第一问不碰网络，进场就有内容', () async {
      bool called = false;
      final KindlingAiOracle ai = KindlingAiOracle(
        isAvailable: () async {
          called = true;
          return true;
        },
        call: ({
          required String prompt,
          required String systemPrompt,
          required String purpose,
        }) async {
          called = true;
          return '模型的问句？';
        },
      );

      final String? q =
          await ai.nextResistanceQuestion(<({String q, String? a})>[]);

      expect(q, KCopy.resistance1);
      expect(called, isFalse, reason: '空 history 时模型没有上下文，不该等它');
    });

    test('模型太慢就用本地问题梯，不干等', () async {
      final KindlingAiOracle ai = KindlingAiOracle(
        isAvailable: () async => true,
        call: ({
          required String prompt,
          required String systemPrompt,
          required String purpose,
        }) => Future<String>.delayed(
          KindlingAiOracle.questionTimeout * 4,
          () => '来晚了的问句？',
        ),
      );

      final Stopwatch watch = Stopwatch()..start();
      final String? q = await ai.nextResistanceQuestion(
        <({String q, String? a})>[(q: KCopy.resistance1, a: '怕做砸')],
      );
      watch.stop();

      expect(q, KCopy.resistance2);
      expect(
        watch.elapsed,
        lessThan(KindlingAiOracle.questionTimeout * 3),
        reason: '超过时限就该落回本地，不该等满',
      );
    });

    test('AI 不可用时走本地问题梯', () async {
      final String? q =
          await oracle(available: false).nextResistanceQuestion(_afterFirstAnswer);
      expect(q, KCopy.resistance2);
    });

    test('问句超过 25 字就不采用', () async {
      final String tooLong = '${'那' * 30}？';
      final String? q = await oracle(available: true, reply: () async => tooLong)
          .nextResistanceQuestion(_afterFirstAnswer);
      expect(q, KCopy.resistance2);
    });

    test('出现禁用词就不采用', () async {
      for (final String banned in KindlingAiOracle.bannedWords) {
        final String? q = await oracle(
          available: true,
          reply: () async => '$banned，接着说说？',
        ).nextResistanceQuestion(_afterFirstAnswer);
        expect(q, KCopy.resistance2, reason: '「$banned」不该出现在追问里');
      }
    });

    test('不是问句就不采用', () async {
      final String? q =
          await oracle(available: true, reply: () async => '你在防着谁。')
              .nextResistanceQuestion(_afterFirstAnswer);
      expect(q, KCopy.resistance2);
    });

    test('合规的问句照用', () async {
      final String? q =
          await oracle(available: true, reply: () async => '那件事里谁在看着你？')
              .nextResistanceQuestion(_afterFirstAnswer);
      expect(q, '那件事里谁在看着你？');
    });

    test('问满四步就结束，不无限追问', () async {
      final List<({String q, String? a})> history = <({String q, String? a})>[
        for (int i = 0; i < KindlingAiOracle.maxResistanceSteps; i++)
          (q: 'q$i', a: null),
      ];
      final String? q = await oracle(available: true, reply: () async => '还想问？')
          .nextResistanceQuestion(history);
      expect(q, isNull);
    });

    test('system prompt 与方案 §7 逐字一致', () {
      expect(
        KindlingAiOracle.systemPrompt,
        '你只提问，不给建议、不安慰、不总结、不鼓励。\n'
        '每次只输出一个问句，不超过 25 字。\n'
        '禁止出现：加油、相信自己、你可以、建议、不妨、试试看。',
      );
    });
  });

  group('复问提醒', () {
    test('默认实现什么都不做，也就是默认关', () async {
      const NoopKindlingReminder noop = NoopKindlingReminder();
      await noop.onUnsureRecorded(
        itemId: 1,
        title: 'x',
        askAgainAt: DateTime.now(),
      );
      await noop.onReaskResolved(itemId: 1);
    });

    test('通知文案与模块内的文案逐字一致', () {
      // 宿主拿不到 library private 的 copy.dart，只能各留一份，这里守住同步。
      expect(KindlingCopy.title, KCopy.title);
      expect(KindlingCopy.verdictQuestion, KCopy.verdictQ);
    });

    test('宿主实现挂得上模块的接口', () {
      const KindlingHostReminder reminder = KindlingHostReminder();
      expect(reminder, isA<KindlingReminder>());
    });
  });
}
