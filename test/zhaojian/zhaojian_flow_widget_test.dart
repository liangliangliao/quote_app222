import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/zhaojian/zhaojian.dart';
import 'package:quote_app/zhaojian/src/data/models.dart';
import 'package:quote_app/zhaojian/src/data/zhaojian_dao.dart';
import 'package:quote_app/zhaojian/src/domain/analysis.dart';
import 'package:quote_app/zhaojian/src/domain/controller.dart';
import 'package:quote_app/zhaojian/src/ui/nav.dart';
import 'package:quote_app/zhaojian/src/zhaojian_oracle.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 一个只靠脚本回答的 AI 引擎，用来验证界面对 AI 结果的接入，不碰网络。
class _AiFake extends ZhaojianOracle {
  @override
  String get label => 'fake-ai';

  @override
  bool get sendsData => true;

  @override
  Future<List<ZMotive>> completeMotives({
    required String question,
    required String optionA,
    required String optionB,
    required String profile,
  }) async =>
      <ZMotive>[];

  @override
  Future<ZScoreResult> scoreMotives({
    required String situation,
    required List<ZMotive> motives,
  }) async {
    return ZScoreResult(
      pulls: <int, double>{for (int i = 0; i < motives.length; i++) i: i < 5 ? 4.0 - i * 0.5 : 0.5},
      confidences: <int, double>{for (int i = 0; i < motives.length; i++) i: 0.8},
      source: 'fake-source',
    );
  }

  @override
  Future<String> generate({
    required String prompt,
    required String purpose,
    int maxTokens = 2500,
  }) async {
    if (purpose == 'zhaojian.options') {
      final StringBuffer b = StringBuffer('[');
      for (int i = 0; i < 10; i++) {
        if (i > 0) b.write(',');
        b.write('{"t":"选项$i","gain":"保护$i","cost":"付出$i","fit":${90 - 5 * i},"feas":50}');
      }
      b.write(']');
      return b.toString();
    }
    if (purpose == 'zhaojian.verdict') {
      return '{"choice":{"a":0.62},"score":{"conflict":2.5,"flip":0.3},"noul":["他当天的状态"],"note":"直观动机略占上风"}';
    }
    return '';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  final List<Directory> tempDirs = <Directory>[];

  // 每个用例一份独立的临时库文件：与 Kindling 的组件测试同样的理由——
  // 页面进场时发出的查询走真实事件循环，提前关库会报 database_closed。
  setUp(() async {
    final Directory dir = await Directory.systemTemp.createTemp('zhaojian_widget_test_');
    tempDirs.add(dir);
    db = await databaseFactoryFfi.openDatabase('${dir.path}/zhaojian.db');
    await ZhaojianSchema.createAll(db);
  });

  tearDownAll(() async {
    for (final Directory dir in tempDirs) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  });

  /// 手机尺寸（360×780 逻辑像素）：页面里的横排在窄屏上溢出，用例会直接失败。
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  /// 数据库走真实事件循环，pumpAndSettle 单独驱动不到，需要交替放行。
  Future<void> settle(WidgetTester tester, {Finder? until}) async {
    for (int i = 0; i < 60; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pumpAndSettle();
      if (until != null && until.evaluate().isNotEmpty) return;
      if (until == null && i >= 5) return;
    }
    if (until != null) fail('等不到 $until，界面没有到达预期状态');
  }

  Finder fieldHint(String hint) => find.byWidgetPredicate(
      (Widget w) => w is TextField && w.decoration?.hintText == hint);

  /// 列表是懒构建的：不在屏幕附近的控件要先滚到才存在。
  Future<void> reveal(WidgetTester tester, Finder f) async {
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(f, 250.0,
          scrollable: find.byType(Scrollable).first, maxScrolls: 120);
    } else {
      await tester.ensureVisible(f.first);
    }
    await tester.pump();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final Finder f = find.text(text);
    await reveal(tester, f);
    await tester.tap(f.first);
    await settle(tester);
  }

  Future<void> typeInto(WidgetTester tester, String hint, String text) async {
    final Finder f = fieldHint(hint);
    await reveal(tester, f);
    await tester.enterText(f.first, text);
    await tester.pump();
  }

  Future<void> pumpEntry(WidgetTester tester, {ZhaojianOracle? oracle}) async {
    await tester.pumpWidget(MaterialApp(
      home: oracle == null
          ? ZhaojianEntry.build(db: db)
          : ZhaojianEntry.build(db: db, oracle: oracle),
    ));
    await settle(tester);
  }

  Future<T> dbCall<T>(WidgetTester tester, Future<T> Function() f) async {
    final T? r = await tester.runAsync(f);
    return r as T;
  }

  group('main flows through the real screens', () {
    testWidgets('home lists the groups and guides a new user to the first decision', (WidgetTester tester) async {
      phone(tester);
      await pumpEntry(tester);
      expect(find.text('照见'), findsWidgets);
      expect(find.textContaining('走一遍「决策」'), findsOneWidget);
      expect(find.text('决策'), findsOneWidget);
      for (final String g in ZNav.groups) {
        await reveal(tester, find.text(g)); // 列表是懒构建的，屏幕外的分组要滚到才存在
        expect(find.text(g), findsWidgets, reason: '首页缺少分组 $g');
      }
    });

    testWidgets('logging a behavior stores it with the chosen reaction', (WidgetTester tester) async {
      phone(tester);
      await pumpEntry(tester);
      await tapText(tester, '行为记录');
      await typeInto(tester, '我实际做了什么？', '我借了钱');
      await tapText(tester, '松了口气');
      await tapText(tester, '记下');
      final List<ZLog> logs = await dbCall(tester, () => ZhaojianDao(db).allLogs());
      expect(logs.length, 1);
      expect(logs.single.what, '我借了钱');
      expect(logs.single.reaction, '松了口气');
      expect(find.text('我借了钱'), findsOneWidget, reason: '提交后输入框清空，列表里出现这条');
    });

    testWidgets('a hypothesis becomes supported after three supports', (WidgetTester tester) async {
      phone(tester);
      await pumpEntry(tester);
      await tapText(tester, '主线与假设');
      await typeInto(tester, '例：我在人情面前容易心软', '我在人情面前容易心软');
      await tapText(tester, '加入检验');
      expect(find.textContaining('待验证'), findsOneWidget);
      await tapText(tester, '＋支持一次');
      await tapText(tester, '＋支持一次');
      expect(find.textContaining('待验证'), findsOneWidget);
      await tapText(tester, '＋支持一次');
      expect(find.textContaining('被行为支持'), findsWidgets);
      final List<ZHypothesis> hs = await dbCall(tester, () => ZhaojianDao(db).allHypotheses());
      expect(hs.single.status, 1);
      expect(hs.single.sup.length, 3);
    });

    testWidgets('decision wizard: from a question to a sealed card, then the reveal', (WidgetTester tester) async {
      phone(tester);
      await pumpEntry(tester);
      await tapText(tester, '决策');
      await typeInto(tester, '你的处境或问题，如：他开口借钱，我怎么办？', '他开口借钱');
      await typeInto(tester, '选项 A，如：借', '借');
      await typeInto(tester, '选项 B，如：不借', '不借');
      await tapText(tester, '下一步：补全动机');
      await tapText(tester, '用内置动机库（61 条，离线可用）');
      expect(find.text('看到他为难就心软'), findsOneWidget);
      await tapText(tester, '5');
      await tapText(tester, 'A：借');
      await tapText(tester, '够了，看天平');
      expect(find.text('动机的天平'), findsOneWidget);
      await tapText(tester, '下一步：下注');
      expect(find.textContaining('一致度与难度：哪个选择更通向你要的？'), findsOneWidget);
      await tapText(tester, '下一步：下注');
      expect(find.text('下注：封存你的预测'), findsOneWidget);
      await tapText(tester, '我会选 A：借');
      await tapText(tester, '封存预测');

      final List<ZDecision> ds = await dbCall(tester, () => ZhaojianDao(db).allDecisions());
      expect(ds.length, 1);
      expect(ds.single.question, '他开口借钱');
      expect(ds.single.pred, 'a');
      expect(ds.single.stake, 3);
      expect(ds.single.revealed, isFalse);
      final ZMotive rated = ds.single.motives.firstWhere((ZMotive m) => m.text == '看到他为难就心软');
      expect(rated.weight, 5);
      expect(rated.side, 'a');

      // 开牌：实际选了 B，预测落空，自知分 −3。
      await tapText(tester, '未开的牌');
      expect(find.textContaining('预测已封存'), findsOneWidget);
      await tapText(tester, '开牌');
      await tapText(tester, '不借');
      await tapText(tester, '松了口气');
      await tapText(tester, '翻牌');
      // 稳定等待会把弹窗里的三段计时一并走完，所以直接等最后一段出现。
      await settle(tester, until: find.text('关闭'));
      expect(find.textContaining('落空，−3 自知分'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
      await tapText(tester, '关闭');

      final List<ZDecision> after = await dbCall(tester, () => ZhaojianDao(db).allDecisions());
      expect(after.single.actual, 'b');
      expect(after.single.reaction, '松了口气');
      expect(selfScoreOf(after.single), -3);
      final List<ZLog> logs = await dbCall(tester, () => ZhaojianDao(db).allLogs());
      expect(logs.single.what, '决定：不借', reason: '开牌同时记一条行为记录');
    });

    testWidgets('a rope is created from a template and its result is counted', (WidgetTester tester) async {
      phone(tester);
      await pumpEntry(tester);
      await tapText(tester, '绳子');
      await tapText(tester, '起床');
      await tapText(tester, '系上');
      expect(find.text('歌声：闹钟响了，想再躺一会儿'), findsOneWidget);
      await tapText(tester, '这次守住了');
      expect(find.textContaining('● 守住 1 次'), findsOneWidget);
      final List<ZEntry> ropes = await dbCall(tester, () async =>
          (await ZhaojianDao(db).allItems()).where((ZEntry e) => e.kind == 'rope').toList());
      expect(ropes.single.list('seq'), <String>['y']);
      expect(ropes.single.s('ok'), 'y');
    });

    testWidgets('acceptance only comforts after a bypass is written and fixedness confirmed', (WidgetTester tester) async {
      phone(tester);
      await pumpEntry(tester);
      await tapText(tester, '接受');
      await typeInto(tester, '这件事是…', '领导的决定');
      await tapText(tester, '不可控');
      await tapText(tester, '放进去');
      await reveal(tester, find.textContaining('写过绕开办法并勾选确认之后'));
      expect(find.textContaining('写过绕开办法并勾选确认之后'), findsOneWidget);
      expect(find.textContaining('现在放下的不是责任'), findsNothing);
      await typeInto(tester, '绕开办法', '换个部门');
      await settle(tester);
      expect(find.textContaining('现在放下的不是责任'), findsNothing, reason: '只写了办法还不够，要确认');
      await reveal(tester, find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile).first);
      await settle(tester);
      await reveal(tester, find.textContaining('现在放下的不是责任'));
      expect(find.textContaining('现在放下的不是责任'), findsOneWidget);
    });

    testWidgets('cognitive reframing stops and points to help when despair shows up', (WidgetTester tester) async {
      phone(tester);
      await pumpEntry(tester);
      await tapText(tester, '认知重构');
      await typeInto(tester, '情境：发生了什么', '我真的不想活了');
      await settle(tester);
      expect(find.textContaining('我先停在这里'), findsOneWidget);
      FilledButton next = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '下一步'));
      expect(next.onPressed, isNull, reason: '出现绝望迹象时不能继续练习');
      await typeInto(tester, '情境：发生了什么', '被同事当面批评了');
      await settle(tester);
      expect(find.textContaining('我先停在这里'), findsNothing);
      next = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '下一步'));
      expect(next.onPressed, isNotNull);
    });

    testWidgets('the change engine walks four steps and saves a running plan', (WidgetTester tester) async {
      phone(tester);
      await pumpEntry(tester);
      await tapText(tester, '改变引擎');
      await typeInto(tester, '我想改变的是…', '早点睡');
      await tapText(tester, '下一步：分诊');
      await tapText(tester, '环境');
      await tapText(tester, '下一步：三处设计');
      await tapText(tester, '下一步：最小动作');
      await typeInto(tester, '最小动作：我现在就能做的一件小事', '十点把手机放到客厅');
      await tapText(tester, '存成计划');
      final List<ZEntry> plans = await dbCall(tester, () async =>
          (await ZhaojianDao(db).allItems()).where((ZEntry e) => e.kind == 'plan').toList());
      expect(plans.length, 1);
      expect(plans.single.s('goal'), '早点睡');
      expect(plans.single.s('layer'), '环境');
      expect(plans.single.s('st'), '进行中');
      expect(plans.single.s('act'), '十点把手机放到客厅');
    });
  });

  group('AI features through the screens (scripted engine)', () {
    testWidgets('AI lists ten options, keeps the best five by the stated weighting, and fills A', (WidgetTester tester) async {
      phone(tester);
      await pumpEntry(tester, oracle: _AiFake());
      await tapText(tester, '决策');
      await typeInto(tester, '你的处境或问题，如：他开口借钱，我怎么办？', '要不要辞职');
      expect(find.textContaining('fake-ai'), findsWidgets, reason: '点击前披露会发给谁');
      await tapText(tester, '让 AI 列出候选选项');
      for (int i = 0; i < 5; i++) {
        expect(find.text('选项$i'), findsOneWidget);
      }
      expect(find.text('选项5'), findsNothing);
      expect(find.text('选项9'), findsNothing);
      await tapText(tester, '设为 A');
      final TextField a = tester.widget<TextField>(fieldHint('选项 A，如：借'));
      expect(a.controller!.text, '选项0', reason: '综合分最高的排第一：0.65×90 + 0.35×50 = 76');
    });

    testWidgets('top-five motives show the engine pulls and the source', (WidgetTester tester) async {
      phone(tester);
      await pumpEntry(tester, oracle: _AiFake());
      await tapText(tester, '决策');
      await typeInto(tester, '选项 A，如：借', '借');
      await typeInto(tester, '选项 B，如：不借', '不借');
      await tapText(tester, '下一步：补全动机');
      await tapText(tester, '用内置动机库（61 条，离线可用）');
      await tapText(tester, '为全部动机打分，推荐前 5');
      expect(find.textContaining('打分来源：fake-source'), findsOneWidget);
      expect(find.textContaining('拉力 4.0/4'), findsWidgets);
      expect(find.text('只评这 5 个，然后看天平'), findsOneWidget);
    });

    testWidgets('the verdict card shows choice, score and noul separately', (WidgetTester tester) async {
      phone(tester);
      await pumpEntry(tester, oracle: _AiFake());
      await tapText(tester, '决策');
      await typeInto(tester, '选项 A，如：借', '借');
      await typeInto(tester, '选项 B，如：不借', '不借');
      await tapText(tester, '下一步：补全动机');
      await tapText(tester, '用内置动机库（61 条，离线可用）');
      await tapText(tester, '5');
      await tapText(tester, '够了，看天平');
      await tapText(tester, '让 AI 研判这架天平');
      expect(find.textContaining('Choice：到现场选 A 的概率 62%'), findsOneWidget);
      expect(find.textContaining('Score：冲突强度 2.5 / 4'), findsOneWidget);
      expect(find.textContaining('Score：到现场翻盘的可能 30%'), findsOneWidget);
      expect(find.textContaining('Noul：还不知道的'), findsOneWidget);
      expect(find.text('· 他当天的状态'), findsOneWidget);
    });
  });

  group('every page renders on a phone screen', () {
    Future<ZhaojianController> loaded(WidgetTester tester, {bool seeded = false}) async {
      final ZhaojianController c = ZhaojianController(db: db, oracle: const LocalZhaojianOracle());
      await tester.runAsync(() async {
        await c.load();
        if (seeded) await _seed(c);
      });
      return c;
    }

    Future<void> open(WidgetTester tester, ZhaojianController c, ZDest d) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (BuildContext ctx) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => ZNav.open(ctx, c, d),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await settle(tester);
    }

    for (final ZDest d in ZDest.values) {
      testWidgets('${d.name}: empty state has no layout errors', (WidgetTester tester) async {
        phone(tester);
        final ZhaojianController c = await loaded(tester);
        await open(tester, c, d);
        expect(find.byType(Scaffold), findsWidgets);
        expect(find.text(ZNav.info[d]!.title), findsWidgets, reason: '${d.name} 的标题没有显示');
      });

      testWidgets('${d.name}: with data has no layout errors', (WidgetTester tester) async {
        phone(tester);
        final ZhaojianController c = await loaded(tester, seeded: true);
        await open(tester, c, d);
        expect(find.byType(Scaffold), findsWidgets);
      });
    }

    testWidgets('home with data shows hints and every registered page', (WidgetTester tester) async {
      phone(tester);
      await loaded(tester, seeded: true);
      await tester.pumpWidget(MaterialApp(home: ZhaojianEntry.build(db: db)));
      await settle(tester);
      for (final String g in ZNav.groups) {
        await reveal(tester, find.text(g));
        expect(find.text(g), findsWidgets);
      }
    });
  });
}

/// 给每一类页面都造一点数据，用来检查页面碰到真实数据时不会出错。
Future<void> _seed(ZhaojianController c) async {
  final int h1 = await c.addHypothesis('在人情面前心软', '先答应');
  final int h2 = await c.addHypothesis('怕被看不起', '');
  for (int i = 0; i < 3; i++) {
    await c.bumpHypothesis(h1, 'sup');
  }
  final ZDecision d = ZDecision(
    question: '他开口借钱',
    optionA: '借',
    optionB: '不借',
    importance: '大',
    motives: <ZMotive>[
      ZMotive(text: '怕被说小气', cat: 1, kind: 'int', side: 'a', weight: 4, rated: true, imagery: <String>['看到']),
      ZMotive(text: '风险', cat: 2, kind: 'abs', side: 'b', weight: 5, rated: true),
    ],
    pred: 'a',
    stake: 3,
    feltFreedom: 6,
    condition: '他当面开口',
    jtPred: 1,
    conflictType: 3,
    sealedAt: DateTime(2026, 10, 1),
    imageryDepth: 1.0,
    align: const ZAlignSummary(yearA: 40, yearB: 70, diffA: '易', diffB: '难'),
  );
  final int id = await c.seal(d);
  await c.reveal(decisionId: id, actual: 'b', reaction: '像在演', jtActual: 2, body: <String>['胃沉'], hypId: h1, hypKind: 'sup');
  await c.seal(ZDecision(
    question: '换工作',
    optionA: '换',
    optionB: '留',
    motives: <ZMotive>[ZMotive(text: '想要自由', cat: 4, kind: 'int', side: 'a', weight: 3, rated: true)],
    pred: 'b',
    stake: 2,
    sealedAt: DateTime(2026, 10, 2),
  ));
  await c.addMiss(cat: 1, text: '怕议论', decisionId: id);
  await c.addLog(ZLog(what: '答应了借钱', reaction: '怅然若失', deliberate: '一时冲动', typical: '大多数人也会', body: <String>['胸口发紧'], hypId: h2, hypKind: 'ref', createdAt: DateTime(2026, 10, 3)));
  await c.addItem('arch', <String, dynamic>{'ph': '高中', 'w': '借了同学的钱', 'c': '没还上', 'm': '怕他难堪', 'r': '后悔', 'dl': '一时冲动', 'ty': '大多数人也会', 'bs': <String>['胃沉'], 'th': h1, 'tk': 'sup'});
  await c.addItem('obs', <String, dynamic>{'who': '妻子', 'saw': '总是先答应', 'guess': '怕拒绝', 'real': '想帮忙'});
  await c.addItem('prin', <String, dynamic>{'t': '借钱前先过一夜', 'src': '那次没还上'});
  await c.addItem('rope', <String, dynamic>{'s': '有人借钱', 'r': '先答我想想', 'w': '回家商量', 'c': '次日', 'seq': <String>['y', 'n', 'y'], 'ok': 'y'});
  await c.addItem('wall', <String, dynamic>{'h': '如果我先拖一天，那么没那么难受', 't': '下次借钱先拖一天', 'e': '更从容', 'r': '符合预期'});
  await c.addItem('asif', <String, dynamic>{'role': '从容拒绝的人', 'acts': '拒绝一次小请求', 'pred': '别扭', 'r': '别扭', 'nb': '没成真', 'al': '更靠近'});
  await c.addItem('asif', <String, dynamic>{'role': '先问再答的人', 'acts': '先问一句', 'pred': '', 'r': '', 'nb': '', 'al': ''});
  await c.addItem('acc', <String, dynamic>{'t': '领导的决定', 'c': 2, 'by': '换部门', 'fx': true});
  await c.addItem('acc', <String, dynamic>{'t': '作息', 'c': 0, 'by': '', 'fx': false});
  await c.addItem('acc', <String, dynamic>{'t': '同事的态度', 'c': 1, 'by': '', 'fx': false});
  await c.addItem('plan', <String, dynamic>{'goal': '早点睡', 'cur': <String>['十二点睡', '十一点睡', '试过闹钟'], 'layer': '环境', 'lv': <String>['查睡眠影响', '加一个画面', '手机放客厅'], 'env': <String>['清除诱因'], 'act': '十点放下手机', 'chk': '每晚', 'st': '没做到', 'fz': '他人的因素', 'fzw': '请家人帮忙', 'rd': 2, 'rev': '换成十点半'});
  await c.addItem('cog', <String, dynamic>{'sit': '被批评', 'bel': '我什么都做不好', 'pre': 80, 'dis': <String>['非黑即白'], 'evf': '错了一次', 'eva': '做对过很多', 'exp': '问一个同事', 'how': '本周', 'alt': '这次没做好', 'post': 30, 'res': '想法不等于事实'});
  await c.addItem('nian', <String, dynamic>{'t': '学会拒绝', 'st': 0, 'cost': '', 'alt': '', 'r': ''});
  await c.addItem('nian', <String, dynamic>{'t': '早起', 'st': 1, 'cost': '少睡', 'alt': '午休', 'r': ''});
  await c.addItem('nian', <String, dynamic>{'t': '写作', 'st': 2, 'cost': '娱乐', 'alt': '周末', 'r': '松了口气'});
  await c.addItem('xc', <String, dynamic>{'t': '想炫耀', 'src': '别人的话', 'act': '放下'});
  await c.addItem('reg', <String, dynamic>{'w': '当初没问清楚', 'k': 1, 'c': 1, 'n': ''});
  await c.addItem('mc', <String, dynamic>{'d': '被认可', 'm': '总是答应', 'svc': 30, 'why': '背离', 'alts': <String>['先问再答'], 'src': 'AI'});
  await c.addItem('bill', <String, dynamic>{'t': '付出就有回报', 'term': '', 'ev': '', 'cost': '三年', 'end': '', 'nev': '', 'q': '有什么反例？'});
  await c.addItem('goal', <String, dynamic>{'top': '被尊重', 'chain': <String>['想被认可', '想安心'], 'pic': '一个安静的下午', 'own': '是我自己要的', 'done': true});
  await c.addItem('goal', <String, dynamic>{'top': '赚钱', 'chain': <String>['想安全'], 'pic': '', 'own': '', 'done': false});
  await c.addItem('linehist', <String, dynamic>{'t': '写作', 'to': '做产品', 'why': '写不出来', 'at': 1700000000000});
  await c.addItem('envy', <String, dynamic>{'what': '同事的自由', 'guess': '想自己做主', 'cost': '收入不稳'});
  await c.addItem('forgo', <String, dynamic>{'t': '刷短视频', 'pred': 8, 'days': 3, 'log': <Map<String, dynamic>>[<String, dynamic>{'v': 3, 'n': '还好'}, <String, dynamic>{'v': 2, 'n': ''}]});
  await c.addItem('probe', <String, dynamic>{'t': '做一个小产品', 'why': '想试试', 'mini': '本周做原型', 'done': true, 'want': 5, 'able': 4});
  await c.addItem('probe', <String, dynamic>{'t': '写专栏', 'why': '', 'mini': '写一篇', 'done': false, 'want': 0, 'able': 0});
  await c.addItem('shift', <String, dynamic>{'bf': '总是拖延', 'af': '提前做', 'mot': '被罚过一次', 'ch': 0});
  await c.addItem('sig', <String, dynamic>{'ifc': '被当面请求', 'then': '先答应', 'conf': true, 'log': <Map<String, dynamic>>[<String, dynamic>{'ctx': '会议', 'hit': true}, <String, dynamic>{'ctx': '饭局', 'hit': true}, <String, dynamic>{'ctx': '电话', 'hit': true}]});
  await c.addItem('sig', <String, dynamic>{'ifc': '被批评', 'then': '沉默', 'conf': false, 'log': <Map<String, dynamic>>[]});
  await c.addItem('ana', <String, dynamic>{
    'patterns': <Map<String, dynamic>>[<String, dynamic>{'t': '被当面请求时先答应', 'ev': '三次', 'tier': '强', 'phase': '高中和现在'}],
    'untested': <Map<String, dynamic>>[<String, dynamic>{'sit': '被上司否定', 'rope': '先答我想想'}],
    'compare': '拖延的证据变弱',
    'n': 6,
    'at': 1700000000000,
  });
  await c.setKv('ab.s', '耐心');
  await c.setKv('ab.l', '不碰赌');
  await c.setKv('exp.0', '看书');
  await c.setKv('line.pick', '做产品');
  await c.setKv('line.drop', '写专栏');
  await c.setKv('zx.$id', '1');
  await c.setKv('eng.$id', '0.7');
}
