import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/prp_plugin/src/engine.dart';
import 'package:quote_app/prp_plugin/src/lesson_validator.dart';
import 'package:quote_app/prp_plugin/src/models.dart';

import 'fakes.dart';

Future<PrpLesson> sealOne(
  Rig r, {
  String key = 'commitment:1',
  String expected = '每天晨读20分钟',
  LessonDraft draft = goodDraft,
  int? parentId,
}) async {
  final sig = enemySignal(key: key, expected: expected);
  final offer = await r.engine.createSession(sig);
  final res = await r.engine.seal(
    offer!.sessionId,
    sig,
    draft,
    parentId: parentId,
  );
  expect(res.ok, isTrue);
  return res.lesson!;
}

void main() {
  group('会话与盖印', () {
    test('创建会话：敌人入口用敌人口吻，并写入会话记录', () async {
      final r = Rig();
      final offer = await r.engine.createSession(enemySignal());
      expect(offer, isNotNull);
      expect(offer!.voice, PrpVoice.enemy);
      expect(await r.store.sessionCount(), 1);
      final s = await r.store.session(offer.sessionId);
      expect(s!.step, PrpStep.pause);
      expect(s.outcome, 'open');
    });

    test('盖印成功：状态 sealed、成色 5、镜像到宿主、会话关联教训', () async {
      final r = Rig();
      final sig = enemySignal();
      final offer = await r.engine.createSession(sig);
      final res = await r.engine.seal(
        offer!.sessionId,
        sig,
        goodDraft,
        userFacts: <String>['昨晚熬夜'],
      );
      expect(res.ok, isTrue);
      expect(res.lesson!.state, PrpLessonState.sealed);
      expect(res.lesson!.quality, 5);
      expect(res.lesson!.evidenceRefs, <String>['07:30 提醒已响，未打卡', '昨晚熬夜']);
      expect(res.lesson!.subjectText, '每天晨读20分钟');
      expect(r.host.mirrored.length, 1);
      final s = await r.store.session(offer.sessionId);
      expect(s!.lessonId, res.lesson!.id);
    });

    test('盖印被拒：不落库', () async {
      final r = Rig();
      final sig = enemySignal();
      final offer = await r.engine.createSession(sig);
      final res = await r.engine.seal(
        offer!.sessionId,
        sig,
        goodDraft.copyWith(worked: <String>[]),
      );
      expect(res.ok, isFalse);
      expect(await r.store.lessonCount(PrpLessonState.sealed), 0);
      expect(r.host.mirrored, isEmpty);
    });

    test('镜像失败不影响盖印', () async {
      final r = Rig();
      r.host.mirrorThrows = true;
      final l = await sealOne(r);
      expect(l.state, PrpLessonState.sealed);
    });

    test('草稿：可保存不完整的内容，重复保存只更新同一条', () async {
      final r = Rig();
      final sig = enemySignal();
      final offer = await r.engine.createSession(sig);
      final d1 = await r.engine.saveDraft(
        offer!.sessionId,
        sig,
        const LessonDraft(worked: <String>['设了提醒']),
      );
      expect(d1!.state, PrpLessonState.draft);
      await r.engine.saveDraft(offer.sessionId, sig, goodDraft);
      expect(await r.store.lessonCount(PrpLessonState.draft), 1);
    });

    test('草稿：空内容、身份判断、危机词都不保存', () async {
      final r = Rig();
      final sig = enemySignal();
      final offer = await r.engine.createSession(sig);
      expect(
        await r.engine.saveDraft(offer!.sessionId, sig, const LessonDraft()),
        isNull,
      );
      expect(
        await r.engine.saveDraft(
          offer.sessionId,
          sig,
          const LessonDraft(worked: <String>['我就是个废物']),
        ),
        isNull,
      );
      expect(
        await r.engine.saveDraft(
          offer.sessionId,
          sig,
          const LessonDraft(failed: <String>['我想死']),
        ),
        isNull,
      );
      expect(await r.store.lessonCount(PrpLessonState.draft), 0);
    });

    test('改写：旧教训退役，新教训记录 parentId，并带入旧内容', () async {
      final r = Rig();
      final a = await sealOne(r);
      final sig = enemySignal(rewriteOf: a.id);
      final offer = await r.engine.createSession(sig);
      expect(offer!.prefill!.id, a.id);
      final res = await r.engine.seal(
        offer.sessionId,
        sig,
        goodDraft.copyWith(thenAction: '把手机放到另一个房间'),
        parentId: a.id,
      );
      expect(res.ok, isTrue);
      expect(res.lesson!.parentId, a.id);
      final old = await r.store.lesson(a.id!);
      expect(old!.state, PrpLessonState.retired);
    });

    test('进行中的步骤与结束会被记录', () async {
      final r = Rig();
      final offer = await r.engine.createSession(enemySignal());
      await r.engine.setStep(
        offer!.sessionId,
        PrpStep.ledger,
        pauseSec: 45,
        emotionBefore: 7,
      );
      var s = await r.store.session(offer.sessionId);
      expect(s!.step, PrpStep.ledger);
      expect(s.pauseSec, 45);
      expect(s.emotionBefore, 7);
      await r.engine.finish(
        offer.sessionId,
        emotionAfter: 4,
        outcome: 'sealed',
      );
      s = await r.store.session(offer.sessionId);
      expect(s!.step, PrpStep.done);
      expect(s.emotionAfter, 4);
      expect(s.outcome, 'sealed');
      expect(s.endedMs, isNotNull);
    });

    test('危机退出会记为 crisis_exit', () async {
      final r = Rig();
      final offer = await r.engine.createSession(enemySignal());
      await r.engine.crisisExit(offer!.sessionId);
      final s = await r.store.session(offer.sessionId);
      expect(s!.outcome, 'crisis_exit');
    });
  });

  group('补盖印草稿', () {
    test('完整的草稿可以补盖印，并镜像到宿主', () async {
      final r = Rig();
      final sig = enemySignal();
      final offer = await r.engine.createSession(sig);
      final d = await r.engine.saveDraft(offer!.sessionId, sig, goodDraft);
      final res = await r.engine.sealExisting(d!.id!);
      expect(res.ok, isTrue);
      expect(res.lesson!.state, PrpLessonState.sealed);
      expect(r.host.mirrored.length, 1);
    });

    test('不完整的草稿补盖印被拒，仍是草稿', () async {
      final r = Rig();
      final sig = enemySignal();
      final offer = await r.engine.createSession(sig);
      final d = await r.engine.saveDraft(
        offer!.sessionId,
        sig,
        const LessonDraft(worked: <String>['设了提醒']),
      );
      final res = await r.engine.sealExisting(d!.id!);
      expect(res.ok, isFalse);
      expect((await r.store.lesson(d.id!))!.state, PrpLessonState.draft);
    });

    test('不存在或已盖印的不能再盖', () async {
      final r = Rig();
      expect((await r.engine.sealExisting(999)).ok, isFalse);
      final a = await sealOne(r);
      expect((await r.engine.sealExisting(a.id!)).ok, isFalse);
    });
  });

  group('相似度', () {
    test('数字和套话不影响：不同事情不会因为“每天…20 分钟”被当成同一件事', () {
      expect(PrpEngine.similarity('每天跑步20分钟', '每天晨读20分钟'), 0);
    });
    test('同一件事换个说法仍能匹配', () {
      expect(PrpEngine.similarity('晨读20分钟', '每天晨读半小时'), greaterThan(0.9));
    });
    test('太短返回 0', () {
      expect(PrpEngine.similarity('a', '每天晨读'), 0);
    });
  });

  group('回访', () {
    test('按 subjectKey、类别、文本都能命中，不相关不命中', () async {
      final r = Rig();
      await sealOne(r);
      expect(
        (await r.engine.peekMatches(
          const PrpContext(
            surface: PrpSurface.enemy,
            subjectKey: 'commitment:1',
          ),
        )).length,
        1,
      );
      expect(
        (await r.engine.peekMatches(
          const PrpContext(surface: PrpSurface.enemy, category: '拖延'),
        )).length,
        1,
      );
      expect(
        (await r.engine.peekMatches(
          const PrpContext(surface: PrpSurface.enemy, text: '晨读20分钟'),
        )).length,
        1,
      );
      expect(
        await r.engine.peekMatches(
          const PrpContext(surface: PrpSurface.enemy, text: '每天跑步20分钟'),
        ),
        isEmpty,
      );
      expect(
        await r.engine.peekMatches(
          const PrpContext(surface: PrpSurface.enemy, category: '回避'),
        ),
        isEmpty,
      );
    });

    test('草稿和退役的教训不会被回访，但退役的计入“第 N 次”', () async {
      final r = Rig();
      final a = await sealOne(r);
      final sig = enemySignal(key: 'commitment:2');
      final offer = await r.engine.createSession(sig);
      await r.engine.saveDraft(offer!.sessionId, sig, goodDraft);
      var hits = await r.engine.peekMatches(
        const PrpContext(surface: PrpSurface.enemy, category: '拖延'),
      );
      expect(hits.length, 1);
      expect(hits.first.lesson.id, a.id);
      expect(hits.first.nth, 2);
      await r.store.updateLesson(a.copyWith(state: PrpLessonState.retired));
      hits = await r.engine.peekMatches(
        const PrpContext(surface: PrpSurface.enemy, category: '拖延'),
      );
      expect(hits, isEmpty);
    });

    test('第 N 次：两条相似教训时是第 3 次', () async {
      final r = Rig();
      await sealOne(r, key: 'commitment:1');
      await sealOne(r, key: 'commitment:2');
      final hits = await r.engine.peekMatches(
        const PrpContext(surface: PrpSurface.enemy, category: '拖延'),
      );
      expect(hits.first.nth, 3);
    });

    test('recallFor 记录待验证的回访；做到了记 helped，又没做到记 repeated，没结果保持待验证', () async {
      final r = Rig();
      final a = await sealOne(r);
      final h1 = await r.engine.recallFor(
        const PrpContext(
          surface: PrpSurface.enemy,
          text: '晨读20分钟',
          subjectKey: 'commitment:7',
        ),
      );
      expect(h1.length, 1);
      expect(await r.engine.reconcile(), 0);
      r.host.refs['commitment:7'] = 'done';
      expect(await r.engine.reconcile(), 1);
      expect(await r.engine.reconcile(), 0);
      var l = await r.store.lesson(a.id!);
      expect(l!.verifiedCnt, 1);
      expect(l.repeatedCnt, 0);

      r.host.now += 24 * 3600 * 1000;
      await r.engine.recallFor(
        const PrpContext(
          surface: PrpSurface.enemy,
          text: '晨读20分钟',
          subjectKey: 'commitment:8',
        ),
      );
      r.host.refs['commitment:8'] = 'missed';
      expect(await r.engine.reconcile(), 1);
      l = await r.store.lesson(a.id!);
      expect(l!.repeatedCnt, 1);
    });

    test('每天的回访预算：第二次不回访，用户主动查看（pull）不受限', () async {
      final r = Rig();
      await sealOne(r);
      const c = PrpContext(
        surface: PrpSurface.enemy,
        text: '晨读20分钟',
        subjectKey: 'commitment:7',
      );
      expect((await r.engine.recallFor(c)).length, 1);
      expect(await r.engine.recallFor(c), isEmpty);
      const p = PrpContext(
        surface: PrpSurface.enemy,
        text: '晨读20分钟',
        kind: 'playbook',
        pull: true,
      );
      expect((await r.engine.recallFor(p)).length, 1);
    });

    test('hintFor 受预算限制但不写数据', () async {
      final r = Rig();
      await sealOne(r);
      final before = r.mem.writeCount;
      const c = PrpContext(surface: PrpSurface.enemy, text: '晨读20分钟');
      expect((await r.engine.hintFor(c)).length, 1);
      expect(r.mem.writeCount, before);
    });

    test('repeat_detected 只是提示：不留待验证记录', () async {
      final r = Rig();
      await sealOne(r);
      final hits = await r.engine.recallFor(
        const PrpContext(
          surface: PrpSurface.enemy,
          text: '晨读20分钟',
          subjectKey: 'commitment:9',
          kind: 'repeat_detected',
          pull: true,
        ),
      );
      expect(hits.length, 1);
      expect((await r.store.recalls(outcome: PrpOutcome.pending)), isEmpty);
    });

    test('没挡住 2 次后建议改写', () async {
      final r = Rig();
      final a = await sealOne(r);
      for (int i = 0; i < 2; i++) {
        r.host.now += 24 * 3600 * 1000;
        await r.engine.recallFor(
          PrpContext(
            surface: PrpSurface.enemy,
            text: '晨读20分钟',
            subjectKey: 'commitment:${10 + i}',
          ),
        );
        r.host.refs['commitment:${10 + i}'] = 'missed';
        await r.engine.reconcile();
      }
      final hits = await r.engine.peekMatches(
        const PrpContext(surface: PrpSurface.enemy, text: '晨读20分钟'),
      );
      expect(hits.first.suggestRewrite, isTrue);
      expect((await r.store.lesson(a.id!))!.repeatedCnt, 2);
    });

    test('手动记账只对待验证的回访生效一次', () async {
      final r = Rig();
      final a = await sealOne(r);
      final h = await r.engine.recallFor(
        const PrpContext(
          surface: PrpSurface.enemy,
          text: '晨读20分钟',
          subjectKey: 'commitment:7',
        ),
      );
      await r.engine.reportOutcome(h.first.recallId!, PrpOutcome.repeated);
      await r.engine.reportOutcome(h.first.recallId!, PrpOutcome.repeated);
      expect((await r.store.lesson(a.id!))!.repeatedCnt, 1);
    });
  });

  group('自己的名言', () {
    test('没有教训时没有名言', () async {
      final r = Rig();
      expect(await r.engine.ownQuoteRow(), isNull);
    });

    test('有教训时给一条，24 小时内不再给，也不重复正在显示的那条', () async {
      final r = Rig();
      await sealOne(r);
      final q = await r.engine.ownQuoteRow();
      expect(q, isNotNull);
      expect(q!['content'], '如果打开别的 App，我就先放下手机 2 分钟再做第一步。');
      expect(q['theme'], '我的教训');
      expect(q['author'], '');
      expect(q['source_from'].toString().contains('盖印于 2026-11-04'), isTrue);
      expect(await r.engine.ownQuoteRow(), isNull);
      r.host.now += 25 * 3600 * 1000;
      expect(
        await r.engine.ownQuoteRow(excludeContent: q['content'] as String),
        isNull,
      );
      expect(await r.engine.ownQuoteRow(), isNotNull);
    });

    test('草稿不会变成名言', () async {
      final r = Rig();
      final sig = enemySignal();
      final offer = await r.engine.createSession(sig);
      await r.engine.saveDraft(offer!.sessionId, sig, goodDraft);
      expect(await r.engine.ownQuoteRow(), isNull);
    });
  });
}
