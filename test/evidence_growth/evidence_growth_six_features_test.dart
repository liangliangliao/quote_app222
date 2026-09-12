import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/evidence_growth/evidence_growth_ai_service.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_decision_engine.dart';
import 'package:quote_app/evidence_growth/evidence_growth_embeddings.dart';
import 'package:quote_app/evidence_growth/evidence_growth_knowledge.dart';
import 'package:quote_app/evidence_growth/evidence_growth_models.dart';
import 'package:quote_app/evidence_growth/evidence_growth_review_engine.dart';
import 'package:quote_app/evidence_growth/evidence_growth_router.dart';
import 'package:quote_app/evidence_growth/evidence_growth_workflows.dart';
import 'package:quote_app/services/unified_ai_service.dart';

class _Ai extends UnifiedAiService {
  _Ai(this.respond);
  final String Function(String,String) respond;
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig({String? forcedProvider,String? forcedModel}) async => config;
  @override
  Future<String> generateText({required String prompt,required String purpose,String? systemPrompt,int maxTokens=1800,
    bool expectJson=false,String? forcedProvider,String? forcedModel,double? temperature}) async=>respond(purpose,prompt);
}
const config=UnifiedAiResolvedConfig(provider:'openai',apiKey:'test-only',model:'chat',
  endpoint:'https://example.test/v1/responses',label:'test',displayModel:'chat',available:true);
Map<String,dynamic> systemPlan()=>{'scans':{for(final k in EvidenceGrowthWorkflows.layers.keys)k:'已核查该层'},
  'layer':'friction','controllable':true,'owner':'自己','baseline':'材料收在柜中',
  'change':'只把材料放桌上','metric':'每天是否进入任务','next_action':'现在把材料放桌上','window_days':7};
Map<String,dynamic> premortem()=>{'horizon_days':30,'analysis_finished_ms':1,'selected_count':2,
  'risks':List.generate(5,(i)=>{'id':i,'reason':'风险原因 $i','probability':20+i*10,'loss':i+1,
    'prevention':'准备一份备用材料 $i','signal':'材料是否齐全 $i','backup':'使用备用材料 $i'})};

void main(){
  late Database db;late EvidenceGrowthDao dao;
  setUpAll(sqfliteFfiInit);
  setUp(() async {db=await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);dao=EvidenceGrowthDao(database:()async=>db);await dao.ensureTables();});
  tearDown(()=>db.close());
  Future<RealityTrial> trial({String text='没开始，拖延',Map<String,String> inputs=const {},String parent=''}) async {
    final route=const EvidenceGrowthRouter().route(text);
    return dao.startTrial(await dao.createTrial(route,prediction:'会得到一条具体回应',probability:.5,
      reviewAt:DateTime.now().subtract(const Duration(minutes:1)),riskConfirmed:true,operatorInputs:inputs,previousTrialId:parent));
  }
  test('AI recognizes a non-keyword situation using recalled knowledge and exact user facts',() async {
    const text='启动阻力很大，材料已摆好';
    final local=const EvidenceGrowthRouter().route(text);
    expect(local.canAct,isFalse);
    final ai=_Ai((purpose,prompt)=>purpose=='evidence_growth.evidence_router'?jsonEncode({
      'facts':['启动阻力很大'],'supported':true,'tal_node':'KB35-A02','tal_sufficient':true,
      'extension_node':'','reason':'当前材料具备但进入任务存在阻力',
    }):jsonEncode({'selected_nodes':[{'node_id':'KB35-A02'}],'inference':'先用短时行动取得反馈',
      'confidence':.7,'operator':'START_5_MIN','action_instruction':'打开材料，写一行申请内容',
      'completion_definition':'留下这一行内容','risk_gate':'PASS','review_trigger':'动作后','evidence_status':'E1'}));
    final result=await EvidenceGrowthAiService(dao:dao,ai:ai).enrichRoute(local);
    expect(result.canAct,isTrue);expect(result.facts,['启动阻力很大']);expect(result.operator,'START_5_MIN');
    final t=await dao.createTrial(result,prediction:'能写下一行',probability:.6,reviewAt:DateTime.now(),riskConfirmed:true);
    expect(t.facts,['启动阻力很大']);expect(await dao.evidenceSnapshots(t.id),isNotEmpty);
  });
  test('semantic score cannot bypass source sufficiency or a risk stop',(){
    const router=EvidenceGrowthRouter();
    final recall=router.retrieve('五分钟启动',semantic:{'KB35-A-EXT2-01':1});
    expect(recall.any((r)=>r.node.id=='KB35-A-EXT2-01'),isTrue);
    expect(router.route('五分钟启动').selectedNodes.every((n)=>n.isTal),isTrue);
    expect(router.retrieve('借债押上全部积蓄',semantic:{'KB35-A02':1}),isEmpty);
  });
  test('invented facts do not turn unsupported input into a formal action',() async {
    final local=const EvidenceGrowthRouter().route('quux xyz');
    final ai=_Ai((_,__)=>jsonEncode({'facts':['我已经投了十份简历'],'supported':true,'tal_node':'KB35-A02','tal_sufficient':true,'reason':'编造事实'}));
    expect((await EvidenceGrowthAiService(dao:dao,ai:ai).enrichRoute(local)).canAct,isFalse);
  });
  test('provider vectors persist, resume, retrieve and invalidate changed knowledge',() async {
    var requests=0;
    final client=MockClient((r) async {
      requests++;expect(r.url.path,'/v1/embeddings');expect(r.headers['Authorization'],'Bearer test-only');
      final body=jsonDecode(r.body) as Map;expect(body['model'],'test-embed');
      return http.Response(jsonEncode({'data':List.generate((body['input'] as List).length,(i)=>{'index':i,'embedding':[1.0,i+.2,.1]})}),200);
    });
    final service=EvidenceGrowthEmbeddings(()async=>db,config,model:'test-embed',client:client);
    final nodes=EvidenceGrowthKnowledge.nodes.take(2).toList();
    expect(await service.build(nodes),2);expect(await service.build(nodes),2);expect(requests,1);
    expect((await service.similarities('行动',nodes)).length,2);
    final newer=EvidenceKNode.fromJson({...nodes.first.toJson(),'version':999});
    expect((await service.load([newer,nodes.last])).length,1);
    service.close();
  });
  test('embedding service rejects corrupt dimensions and HTTP errors without a fake vector',() async {
    for(final response in [http.Response('{"data":[{"index":0,"embedding":[0,0]}]}',200),http.Response('error',403)]) {
      final service=EvidenceGrowthEmbeddings(()async=>db,config,model:'test-embed',client:MockClient((_)async=>response));
      await expectLater(service.embed(['text']),throwsA(anything));service.close();
    }
  });
  test('all seven commitment levels have executable saved conditions and legacy mappings',() async {
    expect(EvidenceGrowthWorkflows.commitments.length,7);
    expect(EvidenceGrowthWorkflows.normalizeCommitment('WITNESS'),'L4');
    for(final level in EvidenceGrowthWorkflows.commitments.keys) {
      final t=await dao.createTrial(const EvidenceGrowthRouter().route('公开目标，背包过墙承诺'),
        prediction:'产生现实交付',probability:.5,reviewAt:DateTime.now(),riskConfirmed:true,commitmentLevel:level,
        operatorInputs:{'承诺内容与日期':'明天交一份草稿','退出方式':'可取消','损失上限':'一小时','目标已基本验证':'true'});
      expect(t.commitmentLevel,level);expect(t.operatorInputs['退出方式'],'可取消');
    }
    await expectLater(dao.createTrial(const EvidenceGrowthRouter().route('承诺'),prediction:'交付',probability:.5,
      reviewAt:DateTime.now(),riskConfirmed:true,commitmentLevel:'L7'),throwsArgumentError);
  });
  test('premortem ranks risks and cannot omit a selected contingency',() {
    final plan=premortem();expect(EvidenceGrowthWorkflows.rankedRisks(plan).first['id'],4);
    EvidenceGrowthWorkflows.validate('PREMORTEM',{'advanced_json':jsonEncode(plan)});
    (plan['risks'] as List).last['backup']='';
    expect(()=>EvidenceGrowthWorkflows.validate('PREMORTEM',{'advanced_json':jsonEncode(plan)}),throwsArgumentError);
  });
  test('advanced workflows produce persisted real actions, feedback, review and a next decision',() async {
    for(final pair in [('重要项目，事前复盘',premortem()),('换很多方法还是反复，系统结构',systemPlan())]) {
      var t=await trial(text:pair.$1,inputs:{'advanced_json':jsonEncode(pair.$2)});
      expect(t.actionInstruction,contains(pair.$2.containsKey('risks')?'预防：':'放桌上'));
      t=await dao.captureResult(t,didAction:true,actualOutcome:'实际调整后按时进入任务',unexpected:'',
        resultMeasurements:{'outcome_helpful':'true','signal_final':'true'});
      final review=const EvidenceGrowthReviewEngine().review(t);
      expect(review.decision,'ACT');t=await dao.saveReview(t,review);
      t=await dao.decide(t,decision:review.decision,reason:review.learning,nextAction:review.nextChangeOneVariable);
      expect(t.isClosed,isTrue);expect((await dao.byId(t.id))!.operatorInputs['advanced_json'],isNotEmpty);
    }
  });
  test('system scan requires all eight layers and a controllable single experiment',(){
    final p=systemPlan();EvidenceGrowthWorkflows.validate('SYSTEM_SCAN',{'advanced_json':jsonEncode(p)});
    p['controllable']=false;
    expect(()=>EvidenceGrowthWorkflows.validate('SYSTEM_SCAN',{'advanced_json':jsonEncode(p)}),throwsArgumentError);
    p['controllable']=true;(p['scans'] as Map).remove('delay');
    expect(()=>EvidenceGrowthWorkflows.validate('SYSTEM_SCAN',{'advanced_json':jsonEncode(p)}),throwsArgumentError);
  });
  test('no action and a single negative result do not prove a hypothesis false',() async {
    var t=await trial();t=await dao.captureResult(t,didAction:false,actualOutcome:'没有实际发送',unexpected:'',resultStatus:'NOT_DONE');
    expect(EvidenceGrowthDecisionEngine.evaluate(t).type,'ADJUST');
    expect(EvidenceGrowthDecisionEngine.evaluate(t.copyWith(didAction:true,operatorInputs:{...t.operatorInputs,
      'hypothesis_support':'refuted','decision_evidence':'本轮没有回应','outcome_helpful':'false'})).type,'ADJUST');
  });
  test('only linked repeated refutations after a real strategy change support EXIT',() async {
    var first=await trial();
    first=await dao.captureResult(first,didAction:true,actualOutcome:'已尝试但关键假设被反驳',unexpected:'',resultMeasurements:{
      'hypothesis_support':'refuted','decision_evidence':'实际回应与核心假设相反','signal_final':'true','method_changed':'true'});
    final r=const EvidenceGrowthReviewEngine().review(first);
    first=await dao.saveReview(first,r);first=await dao.decide(first,decision:'ADJUST',reason:r.learning,nextAction:'只改变提交对象');
    var second=await trial(parent:first.id);
    second=await dao.captureResult(second,didAction:true,actualOutcome:'新策略仍反驳同一假设',unexpected:'',resultMeasurements:{
      'hypothesis_support':'refuted','decision_evidence':'不同对象提供同一反证','signal_final':'true'});
    expect(EvidenceGrowthDecisionEngine.evaluate(second,history:await dao.decisionHistory(second)).type,'EXIT');
    expect(EvidenceGrowthDecisionEngine.evaluate(second.copyWith(operatorInputs:{...second.operatorInputs,'hypothesis_id':'another'}),history:[first]).type,'ADJUST');
  });
  test('budget and next-round protection override premature encouragement',() async {
    final t=await trial(inputs:{'cost_limit':'10'});
    expect(EvidenceGrowthDecisionEngine.evaluate(t.copyWith(operatorInputs:{...t.operatorInputs,
      'cost_spent':'10','decision_evidence':'累计已投入十小时'})).type,'EXIT');
    expect(EvidenceGrowthDecisionEngine.evaluate(t.copyWith(operatorInputs:{'next_round_safe':'false'})).protective,isTrue);
    await expectLater(dao.captureResult(t,didAction:true,actualOutcome:'结果',unexpected:'',resultMeasurements:{'cost_limit':'999'}),throwsArgumentError);
  });
  test('future observation remains OBSERVE unless the agreed signal is confirmed final',() async {
    final t=(await trial()).copyWith(reviewAtMs:DateTime.now().add(const Duration(days:7)).millisecondsSinceEpoch,
      didAction:true,actualOutcome:'已提交，等待回应',operatorInputs:{'outcome_helpful':'true'});
    expect(EvidenceGrowthDecisionEngine.evaluate(t).type,'OBSERVE');
    expect(EvidenceGrowthDecisionEngine.evaluate(t.copyWith(operatorInputs:{...t.operatorInputs,'signal_final':'true'})).type,'ACT');
  });
}
