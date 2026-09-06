import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quote_app/evidence_growth/evidence_growth_ai_service.dart';
import 'package:quote_app/evidence_growth/evidence_growth_api.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_kb_store.dart';
import 'package:quote_app/evidence_growth/evidence_growth_knowledge.dart';
import 'package:quote_app/evidence_growth/evidence_growth_models.dart';
import 'package:quote_app/evidence_growth/evidence_growth_review_engine.dart';
import 'package:quote_app/evidence_growth/evidence_growth_router.dart';
import 'package:quote_app/evidence_growth/evidence_growth_search.dart';
import 'package:quote_app/evidence_growth/evidence_growth_sync_service.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Provider extends UnifiedAiService {
  _Provider(this.output);
  final String Function(String purpose) output;
  int calls=0;
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig({String? forcedProvider,String? forcedModel}) async =>
    const UnifiedAiResolvedConfig(provider:'fake',apiKey:'test',model:'fake',endpoint:'',label:'fake',displayModel:'fake',available:true);
  @override
  Future<String> generateText({required String prompt,required String purpose,String? systemPrompt,int maxTokens=1800,
      bool expectJson=false,String? forcedProvider,String? forcedModel,double? temperature}) async { calls++;return output(purpose); }
}

void main() {
  late Database db,remoteDb;
  late EvidenceGrowthDao dao,remote;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    EvidenceGrowthKnowledge.activate(EvidenceGrowthKnowledge.bundledVersion,EvidenceGrowthKnowledge.bundledNodes);
    db=await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,options:OpenDatabaseOptions(singleInstance:false));
    remoteDb=await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,options:OpenDatabaseOptions(singleInstance:false));
    dao=EvidenceGrowthDao(database:()async=>db); remote=EvidenceGrowthDao(database:()async=>remoteDb);
    await dao.ensureTables();await remote.ensureTables();
  });
  tearDown(() async { await db.close();await remoteDb.close();
    EvidenceGrowthKnowledge.activate(EvidenceGrowthKnowledge.bundledVersion,EvidenceGrowthKnowledge.bundledNodes); });
  Future<RealityTrial> start({String prediction='我会被拒绝'}) async => dao.startTrial(await dao.createTrial(
    const EvidenceGrowthRouter().route('求职投简历，拖延没开始'),prediction:prediction,probability:.8,
    reviewAt:DateTime.now().add(const Duration(hours:1)),riskConfirmed:true));

  test('a negative prediction occurring is not a positive outcome',() async {
    var trial=await start();
    trial=await dao.captureResult(trial,didAction:true,actualOutcome:'投递后被拒绝',unexpected:'',
      resultMeasurements:{'prediction_occurred':'true','outcome_helpful':'false'});
    trial=await dao.saveReview(trial,const EvidenceGrowthReviewEngine().review(trial));
    await dao.decide(trial,decision:'ADJUST',reason:'样本没有推进目标',nextAction:'只调整投递对象');
    expect((await db.query('evidence_growth_personal_node_stats')).single['positive_outcome_count'],0);
    expect((await dao.summary()).calibrationError,closeTo(.04,.0001));
  });
  test('observe cycles never double count completion or outcome',() async {
    var trial=await start();
    for(var i=0;i<2;i++) {
      trial=await dao.captureResult(trial,didAction:true,actualOutcome:'已完成动作，仍需观察',unexpected:'',resultStatus:'DONE',
        resultMeasurements:{'outcome_helpful':'true'});
      trial=await dao.saveReview(trial,const EvidenceGrowthReviewEngine().review(trial));
      trial=await dao.decide(trial,decision:i==0?'OBSERVE':'ACT',reason:'继续核对结果',nextAction:'再取样');
    }
    final stats=(await db.query('evidence_growth_personal_node_stats')).single;
    expect(stats['used_count'],1);expect(stats['completed_count'],1);expect(stats['positive_outcome_count'],1);
    expect((await dao.summary()).activationRate,lessThanOrEqualTo(1));
  });
  test('result measurements cannot overwrite setup or use invalid scales',() async {
    final trial=await start();
    for(final measurements in [{'scheduled_start_ms':'0'},{'actual_anxiety':'11'},{'recovery_hours':'-1'}]) {
      await expectLater(dao.captureResult(trial,didAction:true,actualOutcome:'记录',unexpected:'',resultMeasurements:measurements),throwsArgumentError);
    }
  });
  test('bounded retry rejects fabricated citations and rewritten predictions',() async {
    final provider=_Provider((_)=>'invalid JSON');
    final service=EvidenceGrowthAiService(dao:dao,ai:provider);
    final route=const EvidenceGrowthRouter().route('拖延，没开始');
    expect((await service.enrichRoute(route)).operator,route.operator);expect(provider.calls,2);
    var trial=await start();
    trial=await dao.captureResult(trial,didAction:true,actualOutcome:'得到一个答复',unexpected:'');
    final malicious=_Provider((_)=>jsonEncode({'prediction_original':'事后改写的预测','knowledge_nodes_used':trial.nodeIds}));
    final review=await EvidenceGrowthAiService(dao:dao,ai:malicious).review(trial);
    expect(review.predictionOriginal,trial.prediction);expect(malicious.calls,2);
    final logs=await db.query('evidence_growth_prompt_runs');
    expect(logs,hasLength(4));expect(logs.every((r)=>r['valid_structure']==0),isTrue);
  });
  test('ADJUST carries the chosen variable into a linked next trial',() async {
    var trial=await start();
    trial=await dao.captureResult(trial,didAction:false,actualOutcome:'任务尺度太大',unexpected:'');
    trial=await dao.saveReview(trial,const EvidenceGrowthReviewEngine().review(trial));
    trial=await dao.decide(trial,decision:'ADJUST',reason:'缩小尺度',nextAction:'只把投递数量改为一份');
    final next=const EvidenceGrowthRouter().nextTrial(trial);
    expect(next.actionInstruction,contains('投递数量改为一份'));expect(next.operator,trial.operator);
    final created=await dao.createTrial(next,prediction:'完成一份',probability:.7,reviewAt:DateTime.now().add(const Duration(hours:1)),
      riskConfirmed:true,previousTrialId:trial.id);
    expect((await dao.byId(trial.id))!.nextTrialId,created.id);
  });
  test('Bennett and Five-Minute are searchable with physical sources',() async {
    final search=EvidenceGrowthSearch.current;
    expect(search.search('Bennett').first.node.locator.pages,[124]);
    expect(search.search('Five-Minute'),isNotEmpty);
    final store=EvidenceGrowthKbStore(()async=>db);await store.initialize();
    expect(await store.exactSearch('Bennett'),contains('KB35-F-CASE-BENNETT'));
  });
  test('manifest integrity failure retains stable KB; rollback preserves trial snapshot',() async {
    final store=EvidenceGrowthKbStore(()async=>db);await store.initialize();
    final trial=await start();final before=await dao.evidenceSnapshots(trial.id);
    final stable=EvidenceGrowthKnowledge.kbVersion;
    final updated=EvidenceGrowthKbStore.manifest('test-next',EvidenceGrowthKnowledge.nodes);
    await store.install(updated);expect(EvidenceGrowthKnowledge.kbVersion,'test-next');
    final bad=Map<String,dynamic>.from(updated)..['sha256']='invalid';
    await expectLater(store.install(bad),throwsFormatException);expect(EvidenceGrowthKnowledge.kbVersion,'test-next');
    expect(await store.rollback(),isTrue);expect(EvidenceGrowthKnowledge.kbVersion,stable);
    expect(await dao.evidenceSnapshots(trial.id),before);
  });
  test('sync retry is idempotent and conflicting observations are preserved',() async {
    var trial=await start();
    final initial=await dao.trialBundle(trial.id);
    final digest=await remote.importTrialBundle(initial,baseDigest:'');
    expect(await remote.importTrialBundle(initial,baseDigest:''),digest);
    final remoteTrial=(await remote.byId(trial.id))!;
    await remote.captureResult(remoteTrial,didAction:false,actualOutcome:'另一设备：未做',unexpected:'');
    trial=await dao.captureResult(trial,didAction:true,actualOutcome:'本机：完成投递',unexpected:'');
    await expectLater(remote.importTrialBundle(await dao.trialBundle(trial.id),baseDigest:digest),throwsStateError);
    expect((await remote.byId(trial.id))!.actualOutcome,'另一设备：未做');
    expect((await dao.byId(trial.id))!.actualOutcome,'本机：完成投递');
  });
  test('network failure leaves trial pending and a successful retry acknowledges it',() async {
    final trial=await start();await dao.setSetting('sync_enabled','true');
    final api=EvidenceGrowthApi(daoForUser:(_)async=>remote,userForTokenDigest:{});
    final failed=EvidenceGrowthSyncClient(dao:dao,endpoint:Uri.parse('https://test.invalid'),token:'test',
      client:MockClient((_)async=>throw const SocketException('offline')));
    await expectLater(failed.sync(),throwsA(isA<SocketException>()));failed.close();
    expect(await dao.syncState(),isEmpty);expect(await dao.byId(trial.id),isNotNull);
    final online=EvidenceGrowthSyncClient(dao:dao,endpoint:Uri.parse('https://test.invalid'),token:'test',
      client:MockClient((request) async=>http.Response(jsonEncode(await api.dispatch(remote,request.method,request.url,
        Map<String,dynamic>.from(jsonDecode(request.body) as Map))),200)));
    final result=await online.sync();online.close();
    expect(result.uploaded,1);expect(result.conflicts,isEmpty);expect((await dao.syncState()).containsKey(trial.id),isTrue);
  });
  test('core API creates, records, reviews and decides with user isolation',() async {
    final api=EvidenceGrowthApi(daoForUser:(_)async=>dao,userForTokenDigest:{});
    Future<Map<String,Object?>> call(String path,Map<String,dynamic> body)=>api.dispatch(dao,'POST',Uri.parse(path),body);
    final created=await call('/v1/trials',{'text':'拖延，没开始','prediction':'会开始','probability':.6,
      'review_at_ms':DateTime.now().add(const Duration(hours:1)).millisecondsSinceEpoch,'risk_confirmed':true});
    final id=(created['trial'] as Map)['trial_id'];
    await call('/v1/trials/$id/start',{});
    await call('/v1/trials/$id/result',{'did_action':true,'actual_outcome':'做了五分钟','result_status':'DONE'});
    await call('/v1/trials/$id/review',{});
    final result=await call('/v1/trials/$id/decision',{'decision':'EXIT','reason':'保存学习','next_action':'结束本轮'});
    expect((result['trial'] as Map)['decision'],'EXIT');expect(await remote.byId(id as String),isNull);
  });
  test('HTTP API rejects missing auth and replays an idempotent creation',() async {
    final api=EvidenceGrowthApi(daoForUser:(_)async=>dao,
      userForTokenDigest:{sha256.convert(utf8.encode('secret-test-token')).toString():'one'});
    final server=await HttpServer.bind(InternetAddress.loopbackIPv4,0);
    final subscription=server.listen(api.serve);
    final client=HttpClient();
    final uri=Uri.parse('http://127.0.0.1:${server.port}/v1/trials');
    try {
      final unauthorized=await (await client.getUrl(uri)).close();expect(unauthorized.statusCode,401);await unauthorized.drain<void>();
      Future<String> create() async {
        final request=await client.postUrl(uri);
        request.headers.set('Authorization','Bearer secret-test-token');request.headers.set('Idempotency-Key','create-one');
        request.write(jsonEncode({'text':'拖延，没开始','prediction':'会开始','probability':.6,'review_at_ms':2000000000000,'risk_confirmed':true}));
        final response=await request.close();expect(response.statusCode,200);return utf8.decoder.bind(response).join();
      }
      expect(await create(),await create());expect(await dao.recentTrials(),hasLength(1));
    } finally {client.close(force:true);await subscription.cancel();await server.close(force:true);}
  });
}
