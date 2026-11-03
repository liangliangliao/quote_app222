import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/epistemic/concept_circle_preview.dart';
import 'package:quote_app/epistemic/concept_connections.dart';
import 'package:quote_app/epistemic/concept_hierarchy_view.dart';
import 'package:quote_app/epistemic/concept_meaning_network.dart';
import 'package:quote_app/epistemic/grounding_path_view.dart';
import 'package:quote_app/epistemic/reading_map_quality.dart';
import 'package:quote_app/epistemic/semantic_scope.dart';
import 'package:quote_app/epistemic/semantic_contract.dart';
import 'package:quote_app/epistemic/semantic_scope_service.dart';
import 'package:quote_app/epistemic/semantic_scope_view.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'fixtures/schopenhauer_forms.dart';
import 'fixtures/meaning_relations.dart';

const sources=[ScopeSource('A',wangQuote)];
const config=UnifiedAiResolvedConfig(provider:'test',apiKey:'',model:'offline',endpoint:'https://example.invalid',
    label:'离线',displayModel:'分析性定义测试样例 · 非真实模型',available:true);
SemanticScope model([Map<String,dynamic>? map])=>SemanticScope.parse(map??wangForms(),sources);
SemanticContext expansionContext(SemanticScope value)=>SemanticContext(conceptId:'J',
    conceptLabel:value.concepts.singleWhere((n)=>n.id=='J').label,
    conceptDefinition:value.concepts.singleWhere((n)=>n.id=='J').definition,
    existingConcepts:value.concepts,existingHierarchy:value.hierarchy,existingRelations:value.relations);
class ExpansionService extends SemanticScopeService {
  int calls=0;
  SemanticScope? saved;
  @override
  Future<void> remember(List<ScopeSource> sources,String focus,SemanticScope value,{SemanticContext context=const SemanticContext()}) async {saved=value;}
  @override
  Future<SemanticScope?> cached(List<ScopeSource> sources,String focus,{SemanticContext context=const SemanticContext()}) async=>null;
  @override
  Future<SemanticScope> analyze(List<ScopeSource> sources,String focus,{bool force=false,SemanticContext context=const SemanticContext()}) async {
    calls++;
    return validateResponse(wangExpansion(),sources,focus,config,context:context);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final font=File('/tmp/quote-preview-cjk.otf');
    if(font.existsSync()) await (FontLoader('PreviewCJK')..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())))).load();
  });
  test('Wang model distinguishes class, content, analogy and canonical intersection',() {
    final value=model();
    expect(value.issues,isEmpty);
    expect(value.classEdges.length,6);
    expect(value.classEdges.where((e)=>e.child=='J').map((e)=>e.parent),['F','B']);
    expect(value.hierarchy.singleWhere((e)=>e.kind=='mediation').child,'M');
    expect(value.meaningLinks.single.kind,'analogy');
    expect(value.classEdges.any((e)=>e.parent=='pain'||e.child=='pain'),isFalse);
    expect(value.scopeRelations.singleWhere((r)=>r.intersectionId=='J').nodeIds,['F','B']);
    final restored=model(value.toJson());
    expect(restored.issues,isEmpty);
    expect(restored.scopeRelations.singleWhere((r)=>r.intersectionId=='J').scope!.basisKind,'analytic_definition');
    expect(restored.propositions.single.condition,'若只死死守着');
    expect(restored.propositions.single.modality,contains('可能性'));
    expect(restored.classEdges.every((e)=>e.differentia.isNotEmpty),isTrue);
  });
  test('nested inclusion and non-transitive overlaps coexist in actual circle geometry',() {
    final value=model(),cluster=ConceptCircleLayout.build(model()).single;
    expect(cluster.geometryConsistent,isTrue);
    expect(cluster.circles.length,5);
    expect(cluster.circles.any((c)=>c.ids.contains('J')),isFalse,reason:'命名交集是区域，不是独立圆');
    MeaningCircle circle(String id)=>cluster.circles.singleWhere((c)=>c.ids.contains(id));
    for(final r in value.scopeRelations) {
      final a=circle(r.nodeIds[0]),b=circle(r.nodeIds[1]),d=(a.center-b.center).distance;
      if(r.scope!.relation.name=='subset') expect(d+a.radius,lessThan(b.radius));
      if(r.scope!.relation.name=='overlap') {
        expect(d,greaterThan((a.radius-b.radius).abs()));
        expect(d,lessThan(a.radius+b.radius));
      }
    }
  });
  test('v5 rejects missing differentia, unlike universes and untyped basis',() {
    for(final mutate in <void Function(Map<String,dynamic>)>[
      (m)=>(m['hierarchy'] as List).first.remove('differentia'),
      (m)=>(m['concepts'] as List).first['universe']='另一论域',
      (m)=>(m['hierarchy'] as List).first['basis_kind']='unknown',
    ]) {
      final map=wangForms();mutate(map);
      expect(model(map).issues.any((i)=>i.path.startsWith('hierarchy')),isTrue);
    }
  });
  test('analytic definitions cannot masquerade as source proof or change intersection identity',() {
    final wrongStatus=wangForms();(wrongStatus['relations'] as List).first['status']='text_claim';
    expect(model(wrongStatus).issues.any((i)=>i.message.contains('分析性范围')),isTrue);
    final wrongUniverse=wangForms();(wrongUniverse['relations'] as List).first['scope']['universe']='另一种对象';
    expect(model(wrongUniverse).issues.any((i)=>i.message.contains('同一论域')),isTrue);
    final wrongIntersection=wangForms();(wrongIntersection['relations'] as List)[5]['intersection_id']='R';
    expect(model(wrongIntersection).issues.any((i)=>i.message.contains('两个上位')),isTrue);
    final conflicting=wangForms();(conflicting['relations'] as List)[0]['scope']['relation_type']='overlap';
    (conflicting['relations'] as List)[0]['scope']['only_a']='假设内部类独有成员';
    expect(model(conflicting).issues.any((i)=>i.message.contains('类属限定冲突')),isTrue);
  });
  test('semantic-only reply fails explicit projections without starting a paid repair',() async {
    final parsed=await SemanticScopeService().validateResponse(winterMap(),const[ScopeSource('A',winterQuote)],'反馈',config,context:readingMapContext);
    expect(parsed.issues.map((i)=>i.path),containsAll(['reading.class_structure','reading.meaning_spheres','reading.schema']));
    expect(parsed.needsRepair,isTrue);expect(parsed.meaningLinks,hasLength(3));
    final good=await SemanticScopeService().validateResponse(wangForms(),sources,'持志',config,context:readingMapContext);
    expect(good.needsRepair,isFalse);
    final prompt=SemanticScopeService.buildPrompt(sources,'持志',context:readingMapContext);
    expect(prompt,contains('requested_views'));expect(prompt,contains('intersection_id'));expect(prompt,contains('A 类属投影'));
  });
  test('retaining the condition cannot justify strengthening fear into necessity',() {
    final result=PropositionConsistency.check('若只死死守着，必然于工夫上发病。',
        '若只死死守着，恐于工夫上又发病。',condition:'若只死死守着');
    expect(result.status,VerificationStatus.unknown);expect(result.reason,contains('强化'));
  });
  test('incremental expansion reconnects old classes and rewrites named-region IDs together',() async {
    final original=model();
    final parsed=await SemanticScopeService().validateResponse(wangExpansion(),sources,'展开',config,context:expansionContext(original));
    expect(parsed.needsRepair,isFalse);
    expect(parsed.hierarchy.map((e)=>e.child),everyElement('J/new-common'));
    expect(parsed.scopeRelations.single.intersectionId,'J/new-common');
    final merged=model(original.merge(parsed).toJson());
    expect(merged.classEdges,hasLength(8));expect(merged.scopeRelations,hasLength(7));
    expect(merged.scopeRelations.map((r)=>r.intersectionId),containsAll(['J','J/new-common']));
    expect(ConceptCircleLayout.build(merged).single.geometryConsistent,isTrue);
  });
  Future<void> mount(WidgetTester tester,Widget child,{double width=500,double scale=1}) async {
    await tester.pumpWidget(const SizedBox.shrink());await tester.binding.setSurfaceSize(Size(width,1100));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(key:const ValueKey('s9-preview'),child:MaterialApp(
      debugShowCheckedModeBanner:false,theme:ThemeData(fontFamily:'PreviewCJK',colorSchemeSeed:const Color(0xff8d79ac)),
      builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(scale)),child:child!),
      home:Scaffold(backgroundColor:const Color(0xfffaf6ee),body:SingleChildScrollView(padding:const EdgeInsets.all(16),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('离线分析性模型预览 · 非真实 AI 输出',style:TextStyle(fontSize:12)),const SizedBox(height:12),child,
        ]))))));
    await tester.pumpAndSettle();
  }
  Future<void> capture(WidgetTester tester,String name) async {
    expect(tester.takeException(),isNull);
    await tester.runAsync(() async {
      final image=await tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('s9-preview'))).toImage(pixelRatio:2);
      final bytes=await image.toByteData(format:ui.ImageByteFormat.png);final file=File('build/cognitive-preview/v11-$name.png');
      await file.parent.create(recursive:true);await file.writeAsBytes(bytes!.buffer.asUint8List());image.dispose();
    });
  }
  List<ConceptConnectionPainter> painters(WidgetTester tester)=>tester.widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w)=>w.painter).whereType<ConceptConnectionPainter>().toList();
  testWidgets('tree draws true subtype DAG with terminal examples and no analogy',(tester) async {
    await mount(tester,ConceptHierarchyView(value:model(),traceGrounding:true));
    final edges=painters(tester).single.connections;
    expect(edges.where((e)=>e.to=='J').map((e)=>e.from),containsAll(['F','B']));
    expect(edges.any((e)=>e.kind=='analogy'||e.kind=='mediation'),isFalse);
    expect(edges.any((e)=>e.to=='E'&&e.kind=='instance'),isTrue);
    expect(find.byType(ConceptCirclePreview),findsNothing);expect(edges.first.label,'以持志为目标');
    await capture(tester,'wang-class-tree');
    await tester.ensureVisible(find.text('追踪概念的直观链路'));await tester.tap(find.text('追踪概念的直观链路'));await tester.pumpAndSettle();
    expect(find.byType(GroundingPathView),findsOneWidget);expect(find.textContaining('教学情境：'),findsWidgets);
    await capture(tester,'wang-content-trace');
  });
  testWidgets('meaning canvas uses real regions, canonical selection and analytic status',(tester) async {
    await mount(tester,ConceptMeaningNetwork(value:model()));
    expect(painters(tester),isEmpty);expect(find.byType(ConceptCirclePreview),findsNothing);
    expect(find.textContaining('分析性重构'),findsOneWidget);expect(find.byType(ConceptCanvas),findsOneWidget);
    await capture(tester,'wang-meaning-spheres');
    final chip=find.widgetWithText(ActionChip,'初学中的专注持志');
    await tester.ensureVisible(chip);await tester.tap(chip);await tester.pumpAndSettle();
    expect(find.widgetWithText(ConceptDetails,'初学中的专注持志'),findsOneWidget);
  });
  testWidgets('missing requested forms report incompleteness; semantic view remains separate',(tester) async {
    final value=SemanticScope.parse(winterMap(),const[ScopeSource('A',winterQuote)]);
    for(final view in [EpistemicViewKind.hierarchy,EpistemicViewKind.circles]) {
      await mount(tester,SemanticScopeView(value:value,sources:const[ScopeSource('A',winterQuote)],preferredView:view));
      expect(find.byType(ConceptCirclePreview),findsNothing);expect(painters(tester),isEmpty);
      expect(find.textContaining(view==EpistemicViewKind.circles?'尚未建立含义范围图':'尚未建立类属层级'),findsOneWidget);
    }
    await mount(tester,SemanticScopeView(value:value,sources:const[ScopeSource('A',winterQuote)],preferredView:EpistemicViewKind.connections));
    expect(find.byType(ConceptCirclePreview),findsOneWidget);
    expect(painters(tester).single.connections.any((e)=>e.kind=='metaphor'),isTrue);
  });
  testWidgets('small screen with double text keeps both projections free of overflow',(tester) async {
    await mount(tester,ConceptMeaningNetwork(value:model()),width:320,scale:2);await capture(tester,'wang-spheres-large-text');
    await mount(tester,ConceptHierarchyView(value:model()),width:320,scale:2);await capture(tester,'wang-tree-large-text');
  });
  testWidgets('real expansion button updates class edges and meaning regions with one request',(tester) async {
    final service=ExpansionService();SemanticScope? shown;
    await mount(tester,SemanticScopePanel(sources:sources,initial:model(),service:service,
        preferredView:EpistemicViewKind.hierarchy,onResult:(value)=>shown=value));
    expect(service.calls,0);
    final select=find.widgetWithText(ActionChip,'初学中的专注持志');
    await tester.ensureVisible(select);await tester.tap(select);await tester.pumpAndSettle();
    final expand=find.text('展开相关概念');
    await tester.ensureVisible(expand);await tester.tap(expand);await tester.pumpAndSettle();
    expect(service.calls,1);expect(shown!.classEdges,hasLength(8));
    expect(service.saved!.scopeRelations.map((r)=>r.intersectionId),containsAll(['J','J/new-common']));
    expect(painters(tester).single.connections.where((e)=>e.to=='J/new-common').map((e)=>e.from),containsAll(['R','B']));
    final circles=find.widgetWithText(ChoiceChip,'含义圈');
    await tester.ensureVisible(circles);await tester.tap(circles);await tester.pumpAndSettle();
    expect(find.byType(ConceptMeaningNetwork),findsOneWidget);
    expect(find.byType(ConceptCirclePreview),findsNothing);
    expect(find.widgetWithText(ActionChip,'初学中的固着专注持志'),findsOneWidget);
    expect(service.calls,1);await capture(tester,'wang-expanded-regions');
  });
}
