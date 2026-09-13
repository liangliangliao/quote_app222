import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/evidence_growth/evidence_growth_ai_service.dart';
import 'package:quote_app/evidence_growth/evidence_growth_cycle.dart';
import 'package:quote_app/evidence_growth/evidence_growth_cycle_card.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_decision_engine.dart';
import 'package:quote_app/evidence_growth/evidence_growth_models.dart';
import 'package:quote_app/evidence_growth/evidence_growth_review_engine.dart';
import 'package:quote_app/evidence_growth/evidence_growth_router.dart';
import 'package:quote_app/services/unified_ai_service.dart';

class _Ai extends UnifiedAiService {
  _Ai(this.reply);
  final String Function(String,String) reply;
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig({String? forcedProvider,String? forcedModel}) async =>
    const UnifiedAiResolvedConfig(provider:'openai',apiKey:'test-only',model:'chat',endpoint:'https://example.test/v1/chat/completions',
      label:'test',displayModel:'chat',available:true);
  @override
  Future<String> generateText({required String prompt,required String purpose,String? systemPrompt,int maxTokens=1800,
    bool expectJson=false,String? forcedProvider,String? forcedModel,double? temperature}) async=>reply(purpose,prompt);
}
Map<String,String> plan()=>{'goal':'把作品发给一位可信的人，获得具体建议','current':'作品已经完成，还没有发送',
  'gap':'从准备进入一次现实反馈','belief':'不完美的作品会让别人否定我','belief_basis':'待用户核对的候选判断',
  'expected_signal':'对方会指出一处可以修改的地方','why_action':'先用一次小范围反馈检验预期','learning_applied':''};
Map<String,String> update()=>{'belief_after':'还没有发送，尚不能判断别人如何回应','belief_reason':'本次未发送，没有实际检验他人回应',
  'goal_progress':'尚未获得目标反馈，识别到害怕被评价的障碍','next_goal':'','next_gap':'让不完美也能安全地被看见',
  'change_target':'belief','change_reason':'启动障碍与能力证据需要分开','carry_forward':'先区分事实与自我判断，再向可信的人询问一条建议'};

void main(){
  late Database db;late EvidenceGrowthDao dao;
  setUpAll(sqfliteFfiInit);
  setUp(()async{db=await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);dao=EvidenceGrowthDao(database:()async=>db);await dao.ensureTables();});
  tearDown(()=>db.close());
  Future<RealityTrial> first({bool future=false}) async {
    final p=plan();
    final r=const EvidenceGrowthRouter().route('作品已准备，拖延没开始').copyWith(cyclePlan:p,
      goalState:p['goal'],currentState:p['current'],topGap:p['gap']);
    return dao.startTrial(await dao.createTrial(r,prediction:p['expected_signal']!,probability:.5,
      reviewAt:DateTime.now().add(Duration(hours:future?1:-1)),riskConfirmed:true));
  }
  Future<RealityTrial> notDone({bool future=false}) async =>dao.captureResult(await first(future:future),didAction:false,
    actualOutcome:'没有发送作品，我担心失败说明我天生不适合',unexpected:'其实作品已经准备好',resultStatus:'NOT_DONE');
  TrialReviewResult review(RealityTrial t)=>TrialReviewResult(predictionOriginal:t.prediction,actualFacts:[t.actualOutcome],
    predictionError:'尚未检验原预测',failureClass:'NO_ACTION',learning:'害怕失败妨碍暴露，未做不代表能力不足',
    ruleUpdate:'把未行动与能力判断分开',decision:'ADJUST',nextChangeOneVariable:'区分失败与身份后，询问一条具体建议',
    knowledgeNodeIds:t.nodeIds,cycleUpdate:update());

  test('confirmed learning versions the belief and links a re-diagnosed next round',() async {
    var t=await notDone();final prediction=t.prediction;
    t=await dao.saveReview(t,review(t));
    expect(EvidenceGrowthCycle.confirmed(t),isEmpty);
    t=await dao.decide(t,decision:'ADJUST',reason:t.learning,nextAction:t.nextAction,cycleUpdate:update());
    final restored=(await dao.byId(t.id))!;
    expect(EvidenceGrowthCycle.plan(restored)['belief'],plan()['belief']);
    final fresh=const EvidenceGrowthRouter().nextTrial(restored);
    expect(fresh.primaryModule,GrowthModule.failure);expect(fresh.operator,isNot(t.operator));
    expect(fresh.cyclePlan['belief'],update()['belief_after']);
    expect(fresh.cyclePlan['gap'],update()['next_gap']);expect(fresh.inputDrafts['prediction'],'');
    final child=await dao.createTrial(fresh,prediction:'能够询问一条建议',probability:.6,
      reviewAt:DateTime.now().add(const Duration(hours:1)),riskConfirmed:true,previousTrialId:t.id);
    expect(child.operatorInputs['cycle_root'],t.id);expect(EvidenceGrowthCycle.round(child),2);
    expect(child.operatorInputs['hypothesis_id'],isNot(t.operatorInputs['hypothesis_id']));
    expect((await dao.byId(t.id))!.prediction,prediction);
    expect((await dao.cycleHistory(child)).map((e)=>e.id),[t.id,child.id]);
    expect((await dao.cycleHistory((await dao.byId(t.id))!)).map((e)=>e.id),[t.id,child.id]);
    await expectLater(dao.createTrial(fresh,prediction:'重复创建',probability:.5,reviewAt:DateTime.now(),
      riskConfirmed:true,previousTrialId:t.id),throwsStateError);
    expect(await dao.recentTrials(),hasLength(2));
  });
  test('unconfirmed AI belief is not inherited as a user conclusion',() async {
    var t=await notDone();t=await dao.saveReview(t,review(t));
    t=await dao.decide(t,decision:'ADJUST',reason:'只采纳启动调整',nextAction:'缩小第一步');
    expect(EvidenceGrowthCycle.nextPlan(t)['belief'],plan()['belief']);
    expect(EvidenceGrowthCycle.confirmed(t),isEmpty);
  });
  test('ended unstarted attempt adjusts now without fabricating a failed experiment',() async {
    final t=await notDone(future:true);
    final r=const EvidenceGrowthReviewEngine().review(t);
    expect(r.decision,'ADJUST');expect(r.failureClass,'NO_ACTION');expect(r.cycleUpdate['belief_after'],'');
  });
  test('exit closes a route and cannot silently become its next trial',() async {
    var t=await notDone();t=await dao.saveReview(t,review(t));
    t=await dao.decide(t,decision:'EXIT',reason:'用户选择结束此路线',nextAction:'保留学习再明确其他方向');
    expect(const EvidenceGrowthRouter().nextTrial(t).canAct,isFalse);
    await expectLater(dao.createTrial(const EvidenceGrowthRouter().route('拖延没开始'),prediction:'再试',probability:.5,
      reviewAt:DateTime.now(),riskConfirmed:true,previousTrialId:t.id),throwsStateError);
  });
  test('AI continuation receives actuals and confirmed learning and may switch modules',() async {
    var t=await notDone();t=await dao.saveReview(t,review(t));
    t=await dao.decide(t,decision:'ADJUST',reason:t.learning,nextAction:t.nextAction,cycleUpdate:update());
    final purposes=<String>[];
    final ai=_Ai((purpose,prompt){
      purposes.add(purpose);expect(prompt,contains('没有发送作品'));expect(prompt,contains('还没有发送，尚不能判断别人如何回应'));
      if(purpose=='evidence_growth.evidence_router')return jsonEncode({'facts':['没有发送作品'],'supported':true,
        'tal_node':'KB35-F03','tal_sufficient':true,'extension_node':'','reason':'把失败或未做与身份判断分开'});
      return jsonEncode({'selected_nodes':[{'node_id':'KB35-F03'}],'inference':'本轮先处理从未做到否定自己的跳跃',
        'confidence':.6,'operator':'FAILURE_REFRAME','action_instruction':'写下已经发生的事实，向可信的人询问一条建议',
        'completion_definition':'留下问题及实际回应','risk_gate':'PASS','review_trigger':'收到回复后','evidence_status':'E1',
        'cycle_plan':{...plan(),'current':t.actualOutcome,'gap':update()['next_gap'],'belief':update()['belief_after'],
          'learning_applied':'上次未做没有检验能力，本次先将事实与身份判断分开'}});
    });
    final fresh=await EvidenceGrowthAiService(dao:dao,ai:ai).continueCycle(t);
    expect(purposes,['evidence_growth.evidence_router','evidence_growth.route']);
    expect(fresh.operator,'FAILURE_REFRAME');expect(fresh.primaryModule,GrowthModule.failure);
    expect(fresh.cyclePlan['learning_applied'],contains('上次未做'));expect(fresh.cycleContext,hasLength(1));
    expect(fresh.facts,['没有发送作品']);
  });
  test('AI can interpret plain feedback without requiring manual outcome labels',() async {
    var t=await first();
    t=await dao.captureResult(t,didAction:true,actualOutcome:'对方指出了两处可修改的地方',unexpected:'回复很具体',resultStatus:'DONE');
    expect(EvidenceGrowthDecisionEngine.evaluate(t).type,'OBSERVE');
    final ai=_Ai((_,__)=>jsonEncode({'prediction_original':t.prediction,'actual_facts':[t.actualOutcome],
      'prediction_error':'出现了预期的具体修改意见','failure_class':'NO_FAILURE','learning':'反馈带来了可用修改信息，可再取样，不能概括所有人',
      'rule_update':'保留小范围具体提问','decision':'ACT','next_change_one_variable':'保持相同提问方式，再获取一条具体意见',
      'knowledge_nodes_used':t.nodeIds,'decision_fact_quote':'指出了两处可修改的地方',
      'cycle_update':{...update(),'belief_after':'这次小范围提问获得了具体反馈','change_target':'retain',
        'belief_reason':'本次回应提供了修改意见，不能推及所有人','goal_progress':'获得可用于改作品的信息'}}));
    final result=await EvidenceGrowthAiService(dao:dao,ai:ai).review(t);
    expect(result.decision,'ACT');
    final saved=await dao.saveReview(t,result);expect(EvidenceGrowthCycle.confirmed(saved),isEmpty);
  });
  test('fabricated decision quote cannot promote uncertain feedback into ACT',() async {
    var t=await first();t=await dao.captureResult(t,didAction:true,actualOutcome:'只打开了聊天窗口',unexpected:'',resultStatus:'DONE');
    final ai=_Ai((_,__)=>jsonEncode({'prediction_original':t.prediction,'actual_facts':[t.actualOutcome],
      'prediction_error':'成功','failure_class':'NO_FAILURE','learning':'对方赞美','rule_update':'重复','decision':'ACT',
      'next_change_one_variable':'重复','knowledge_nodes_used':t.nodeIds,'decision_fact_quote':'对方赞美'}));
    expect((await EvidenceGrowthAiService(dao:dao,ai:ai).review(t)).decision,'OBSERVE');
  });
  testWidgets('cycle presents the pending reality instead of six false completion badges',(tester) async {
    final t=await first();
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:EvidenceGrowthCycleCard(trial:t)))));
    await tester.tap(find.text('第 1 轮 · 同一个现实问题'));await tester.pumpAndSettle();
    expect(find.text('信念 · 本轮检验'),findsOneWidget);
    expect(find.text('等待现实记录，未开始也可以如实反馈。'),findsOneWidget);
    expect(find.text('改变 · 返回下一轮'),findsOneWidget);
  });
}
