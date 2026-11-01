import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/epistemic/concept_analysis.dart';
import 'package:quote_app/epistemic/concept_meaning_diagram.dart';
import 'package:quote_app/epistemic/cognitive_models.dart';
import 'package:quote_app/epistemic/cognitive_service.dart';
import 'package:quote_app/epistemic/diary_cognition_panel.dart';
import 'package:quote_app/epistemic/quote_intuitive_gallery.dart';
import 'package:quote_app/epistemic/schopenhauer_guidance.dart';
import 'package:quote_app/models/quote_insight.dart';
import 'package:quote_app/services/quote_frame_ai_service.dart';
import 'package:quote_app/services/quote_frame_theme.dart';

Map<String, dynamic> scope({String type = 'overlap'}) => {
      'relation_type': type,
      'relation_scope': 'extension',
      'universe': '本次模拟中的应对情境',
      'set_a': '关注益处',
      'set_b': '处理问题',
      'criterion_a': '记录至少一项实际益处',
      'criterion_b': '对一个具体问题采取措施',
      'basis': '感恩也可以伴随问题解决',
      'justification': '两项判准可同时满足，也可各自满足；此分类不证明感恩导致成功。',
      'intersection': '记录同事帮助，同时为沟通失误安排澄清',
      'only_a': '记录同事帮助，但没有处理沟通问题',
      'only_b': '只澄清沟通问题，未记录益处',
      'illustration': true,
    };

class FrameFake extends QuoteFrameAiService {
  int finds = 0, generates = 0;
  @override
  Future<String?> findCached(String topic, String quote) async {
    finds++;
    return null;
  }

  @override
  Future<String> generate(
      {required String topic,
      required String quote,
      required QuoteFrameTheme theme,
      String note = '',
      bool force = false}) async {
    generates++;
    throw StateError('image provider unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final file = File('/tmp/quote-preview-cjk.otf');
    if (file.existsSync())
      await (FontLoader('PreviewCJK')
            ..addFont(
                Future.value(ByteData.sublistView(file.readAsBytesSync()))))
          .load();
  });

  test(
      'set models reject feature similarity, unknown relations and invented evidence',
      () {
    expect(ConceptScope.parse({...scope(), 'relation_scope': 'features'}, ''),
        isNull);
    expect(ConceptScope.parse(scope(type: 'cause'), ''), isNull);
    expect(ConceptScope.parse({...scope(), 'illustration': false}, '不同的原文'),
        isNull);
    expect(ConceptScope.parse({...scope(), 'criterion_a': ''}, ''), isNull);
    expect(
        ConceptScope.parse({...scope(), 'illustration': false}, '感恩也可以伴随问题解决'),
        isNotNull);
    expect(ConceptScope.parse(scope(), '')!.illustration, isTrue);
  });

  test('all five sphere patterns and both inclusion directions round trip', () {
    for (final type in [
      'equal',
      'subset',
      'superset',
      'partition',
      'overlap',
      'siblings',
      'disjoint'
    ]) {
      final parsed = ConceptScope.parse(scope(type: type), '')!;
      expect(ConceptScope.parse(parsed.toJson(), '')!.relation.name, type);
    }
    final analysis = CognitiveAnalysis.fromJson({
      'concept_scopes': [scope()],
      'abstractions': [
        {
          'term': '感恩',
          'definition': '对实际益处的注意与回应',
          'observed': '模拟中记录同事帮助',
          'retained': '注意益处',
          'omitted': '未解决的问题',
          'counter_example': '否认问题并不等于感恩'
        }
      ]
    }, '原文');
    final restored = CognitiveAnalysis.fromJson(
        jsonEncode(analysis.withSpans([]).toJson()), '原文');
    expect(restored.scopes.single.illustration, isTrue);
    expect(restored.abstractions.single.omitted, '未解决的问题');
    final addon =
        QuoteAnalysisAddon.fromModelJson({'cognition': analysis.toJson()});
    expect(
        QuoteAnalysisAddon.fromStoredJson(addon.toJson())
            .cognition['abstractions'],
        isNotEmpty);
  });

  test(
      'new AI output must explain abstraction and purpose relevant distinctions',
      () {
    expect(
        () => CognitiveService.validateDepth(const CognitiveAnalysis(
            summary: '一段泛泛的分析', boundary: '需要验证', questions: ['为什么'])),
        throwsFormatException);
    expect(
        SchopenhauerGuidance.forPurpose('movie_analysis.deep_analysis', 'JSON'),
        contains('§14'));
    expect(
        SchopenhauerGuidance.forPurpose(
            'xiangji_future_strategist.epistemic_auditor', ''),
        contains('存在根据'));
    expect(SchopenhauerGuidance.forPurpose('translation', '原有翻译指令'), '原有翻译指令');
  });

  Future<void> mount(WidgetTester tester, Widget body,
      {double scale = 1}) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('v3-preview'),
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                fontFamily: 'PreviewCJK',
                colorSchemeSeed: const Color(0xff97703c)),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                backgroundColor: const Color(0xfffaf6ee),
                body: SafeArea(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(18), child: body))))));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('v3-preview')));
      final picture = await boundary.toImage(pixelRatio: 2);
      final data = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/cognitive-preview/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      picture.dispose();
    });
  }

  testWidgets(
      'circle regions are interactive and remain readable with enlarged text',
      (tester) async {
    await mount(
        tester,
        const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('名言解读',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
          SizedBox(height: 14),
          Text('When we appreciate the good, the good appreciates.',
              style: TextStyle(fontSize: 23, height: 1.5)),
          SizedBox(height: 24),
          ConceptMeaningDiagram(
              relation: QuoteRelation.overlap,
              setA: '关注益处的情境',
              setB: '处理问题的情境',
              onlyA: '记录益处但未处理问题',
              intersection: '记录帮助，同时安排澄清',
              onlyB: '处理问题但未记录益处'),
        ]));
    await tester.tap(find.text('共同范围'));
    await tester.pumpAndSettle();
    expect(find.text('共同：记录帮助，同时安排澄清'), findsOneWidget);
    await capture(tester, 'v3-concept-circles');
    for (final type in [
      QuoteRelation.equal,
      QuoteRelation.subset,
      QuoteRelation.superset,
      QuoteRelation.partition,
      QuoteRelation.siblings,
      QuoteRelation.disjoint
    ]) {
      await mount(
          tester,
          ConceptMeaningDiagram(
              relation: type,
              setA: 'A的较长成员定义',
              setB: 'B的较长成员定义',
              universe: '一个明确的共同论域'),
          scale: 2);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('diary exposes all five lenses without sending anything on mount',
      (tester) async {
    final requested = <GroundLens>[];
    var analyses = 0;
    await mount(
        tester,
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('写日记',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const Text('今天没有去参加面试。我很失落。',
              style: TextStyle(fontSize: 18, height: 1.7)),
          DiaryCognitionPanel(
              onAnalyze: () => analyses++,
              onNotes: () {},
              onLens: requested.add),
        ]));
    expect(requested, isEmpty);
    expect(analyses, 0);
    await capture(tester, 'v3-diary-lenses');
    await tester.tap(find.text(GroundLens.cause.label));
    expect(requested, [GroundLens.cause]);
    await tester.tap(find.byKey(const ValueKey('diary-classification-0')));
    expect(analyses, 1);
  });

  testWidgets(
      'reading without cached art offers explicit generation and survives provider failure',
      (tester) async {
    final service = FrameFake();
    await mount(tester,
        QuoteIntuitiveGallery(topic: '感恩', quote: '留意具体益处', service: service));
    expect(service.finds, 1);
    expect(service.generates, 0);
    await tester.tap(find.byKey(const ValueKey('generate-intuitive-art')));
    await tester.pumpAndSettle();
    expect(service.generates, 1);
    expect(find.textContaining('配画暂未生成'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
