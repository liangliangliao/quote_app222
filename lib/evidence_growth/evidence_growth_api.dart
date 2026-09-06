import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'evidence_growth_dao.dart';
import 'evidence_growth_kb_store.dart';
import 'evidence_growth_knowledge.dart';
import 'evidence_growth_models.dart';
import 'evidence_growth_review_engine.dart';
import 'evidence_growth_router.dart';
import 'evidence_growth_search.dart';

class EvidenceGrowthApiError implements Exception {
  const EvidenceGrowthApiError(this.status,this.code);
  final int status;
  final String code;
}

/// Auth is resolved before DAO creation. Each user receives an isolated database;
/// all mutations execute the same domain and SQLite invariants as Android.
class EvidenceGrowthApi {
  EvidenceGrowthApi({required this.daoForUser,required this.userForTokenDigest});
  final Future<EvidenceGrowthDao> Function(String userId) daoForUser;
  final Map<String,String> userForTokenDigest;
  final _queues=<String,Future<void>>{};

  Future<void> serve(HttpRequest request) async {
    request.response.headers.contentType=ContentType.json;
    request.response.headers.set('Cache-Control','no-store');
    try {
      final authorization=request.headers.value(HttpHeaders.authorizationHeader) ?? '';
      if(!authorization.startsWith('Bearer ')) throw const EvidenceGrowthApiError(401,'AUTH_REQUIRED');
      final digest=sha256.convert(utf8.encode(authorization.substring(7))).toString();
      final userId=userForTokenDigest[digest];
      if(userId==null) throw const EvidenceGrowthApiError(401,'INVALID_TOKEN');
      final bytes=<int>[];
      await for(final chunk in request) {
        bytes.addAll(chunk);
        if(bytes.length>2000000) throw const EvidenceGrowthApiError(413,'BODY_TOO_LARGE');
      }
      final decoded=bytes.isEmpty ? <String,dynamic>{} : jsonDecode(utf8.decode(bytes));
      if(decoded is! Map) throw const FormatException('JSON object required');
      final body=Map<String,dynamic>.from(decoded);
      final previous=_queues[userId] ?? Future<void>.value();
      final operation=previous.then((_) async {
        final dao=await daoForUser(userId);
        await dao.ensureTables();
        final key=request.headers.value('Idempotency-Key');
        final fingerprint=sha256.convert(utf8.encode('${request.method}:${request.uri.path}:${jsonEncode(body)}')).toString();
        if(key!=null) {
          if(key.length>150 || key.isEmpty) throw const EvidenceGrowthApiError(400,'INVALID_IDEMPOTENCY_KEY');
          final cached=await dao.apiReceipt(key);
          if(cached!=null) {
            if(cached['fingerprint']!=fingerprint) throw const EvidenceGrowthApiError(409,'IDEMPOTENCY_CONFLICT');
            return Map<String,Object?>.from(jsonDecode(cached['response'] as String) as Map);
          }
        }
        final result=await dispatch(dao,request.method,request.uri,body,requestKey:key??'');
        if(key!=null) await dao.saveApiReceipt(key,fingerprint,jsonEncode(result));
        return result;
      });
      _queues[userId]=operation.then<void>((_) {},onError:(Object _,StackTrace __) {});
      request.response.write(jsonEncode(await operation));
    } on EvidenceGrowthApiError catch(e) {
      request.response.statusCode=e.status; request.response.write(jsonEncode({'error':e.code}));
    } on FormatException {
      request.response.statusCode=400; request.response.write('{"error":"INVALID_PAYLOAD"}');
    } on ArgumentError {
      request.response.statusCode=422; request.response.write('{"error":"INVALID_FIELDS"}');
    } on TypeError {
      request.response.statusCode=400; request.response.write('{"error":"INVALID_PAYLOAD_TYPES"}');
    } on StateError {
      request.response.statusCode=409; request.response.write('{"error":"STATE_CONFLICT"}');
    } catch(_) {
      request.response.statusCode=500; request.response.write('{"error":"INTERNAL_ERROR"}');
    } finally { await request.response.close(); }
  }

  Future<Map<String,Object?>> dispatch(EvidenceGrowthDao dao,String method,Uri uri,Map<String,dynamic> body,{String requestKey=''}) async {
    final path=uri.path;
    if(method=='GET' && path=='/v1/kb/manifest') return EvidenceGrowthKbStore.manifest(EvidenceGrowthKnowledge.kbVersion,EvidenceGrowthKnowledge.nodes);
    if(method=='GET' && path=='/v1/kb/modules') return {'kb_version':EvidenceGrowthKnowledge.kbVersion,
      'modules':GrowthModule.values.map((m)=>{'module':m.key,'label':m.label,
        'nodes':EvidenceGrowthKnowledge.forModule(m).map((n)=>n.toJson()).toList()}).toList()};
    if(method=='GET' && path=='/v1/kb/search') return {'matches':EvidenceGrowthSearch.current.search(uri.queryParameters['q']??'')
      .map((r)=>{'node':r.node.toJson(),'score':r.score}).toList()};
    if(method=='GET' && path.startsWith('/v1/kb/nodes/')) {
      final node=EvidenceGrowthKnowledge.byId(uri.pathSegments.last);
      if(node==null) throw const EvidenceGrowthApiError(404,'NODE_NOT_FOUND');
      return node.toJson();
    }
    if(method=='POST' && path=='/v1/runtime/route') {
      final route=await _route(dao,_text(body,'text'));
      await dao.recordRoute(route);
      return routeJson(route);
    }
    if(method=='POST' && path=='/v1/trials') {
      final route=await _route(dao,_text(body,'text'));
      final trial=await dao.createTrial(route,prediction:_text(body,'prediction'),
        probability:(body['probability'] as num).toDouble(),reviewAt:DateTime.fromMillisecondsSinceEpoch((body['review_at_ms'] as num).toInt()),
        riskConfirmed:body['risk_confirmed']==true,operatorInputs:_strings(body['operator_inputs']),
        worstCase:_text(body,'worst_case'),commitmentLevel:_text(body,'commitment_level'),
        stretchLevel:body['stretch_level'] as String? ?? 'STRETCH',goalState:_text(body,'goal_state'),
        currentState:_text(body,'current_state'),topGap:_text(body,'top_gap'),stableContext:_text(body,'stable_context'),
        previousTrialId:_text(body,'previous_trial_id'),requestKey:requestKey);
      return {'trial':trial.toRow(),'why':await dao.evidenceSnapshots(trial.id)};
    }
    if(method=='GET' && path=='/v1/evidence/summary') {
      final s=await dao.summary();
      return {'learned_nodes':s.learnedNodes,'activated_nodes':s.activatedNodes,'activation_rate':s.activationRate,
        'started_trials':s.startedTrials,'completed_actions':s.completedActions,'partial_actions':s.partialActions,
        'not_done_actions':s.notDoneActions,'aborted_actions':s.abortedActions,'failure_samples':s.failureSamples,
        'strategy_changes':s.strategyChanges,'exits':s.exits,'exposure_count':s.exposureCount,
        'average_recovery_hours':s.averageRecoveryHours,'calibration_error':s.calibrationError,
        'node_fit':await dao.nodeFitScores(),'rule_changes':s.ruleChanges};
    }
    if(method=='DELETE' && path=='/v1/evidence') { await dao.deletePersonalEvidence(); return {'deleted':true}; }
    if(method=='POST' && path=='/v1/sync') {
      final acknowledged=<String,String>{}, conflicts=<String>[];
      final changes=body['changes'] as List? ?? [];
      if(changes.length>30) throw ArgumentError('sync batch too large');
      for(final change in changes) {
        final bundle=Map<String,dynamic>.from(change['bundle'] as Map);
        final id=(bundle['trial'] as Map)['trial_id'] as String;
        try { acknowledged[id]=await dao.importTrialBundle(bundle,baseDigest:change['base_digest'] as String? ?? ''); }
        on StateError { conflicts.add(id); }
      }
      final known=_strings(body['known']);
      final outgoing=<Map<String,dynamic>>[];
      for(final trial in await dao.recentTrials(limit:10000)) {
        if(conflicts.contains(trial.id)) continue;
        final bundle=await dao.trialBundle(trial.id), digest=EvidenceGrowthDao.bundleDigest(await dao.trialBundle(trial.id));
        if(known[trial.id]!=digest && acknowledged[trial.id]!=digest) outgoing.add({'digest':digest,'bundle':bundle});
        if(outgoing.length>=30) break;
      }
      return {'acknowledged':acknowledged,'conflicts':conflicts,'changes':outgoing};
    }
    if(method=='POST' && path=='/v1/feedback/evidence') {
      await dao.submitEvidenceFeedback(trialId:_text(body,'trial_id'),nodeId:_text(body,'node_id'),
        category:_text(body,'category'),detail:_text(body,'detail'));
      return {'saved':true};
    }
    final match=RegExp(r'^/v1/trials/([^/]+)/(start|result|review|decision|why)$').firstMatch(path);
    if(match==null) throw const EvidenceGrowthApiError(404,'NOT_FOUND');
    final trial=await dao.byId(match[1]!);
    if(trial==null) throw const EvidenceGrowthApiError(404,'TRIAL_NOT_FOUND');
    final action=match[2];
    if(method=='GET' && action=='why') return {'trial_id':trial.id,'kb_version':trial.kbVersion,
      'evidence':await dao.evidenceSnapshots(trial.id),'events':await dao.timeline(trial.id)};
    if(method!='POST') throw const EvidenceGrowthApiError(405,'METHOD_NOT_ALLOWED');
    if(action=='start') return {'trial':(await dao.startTrial(trial)).toRow()};
    if(action=='result') {
      final captured=await dao.captureResult(trial,didAction:body['did_action']==true,actualOutcome:_text(body,'actual_outcome'),
        unexpected:_text(body,'unexpected'),resultStatus:_text(body,'result_status'),resultMeasurements:_strings(body['measurements']),
        shameSignal:body['shame_signal']==true,imageExposureSignal:body['image_exposure_signal']==true);
      return {'trial':captured.toRow(),'review':const EvidenceGrowthReviewEngine().review(captured).toJson()};
    }
    if(action=='review') {
      final review=const EvidenceGrowthReviewEngine().review(trial);
      return {'trial':(await dao.saveReview(trial,review)).toRow(),'review':review.toJson()};
    }
    if(action=='decision') return {'trial':(await dao.decide(trial,decision:_text(body,'decision'),
      reason:_text(body,'reason'),nextAction:_text(body,'next_action'),
      nextReviewAt:body['next_review_at_ms'] is num ? DateTime.fromMillisecondsSinceEpoch((body['next_review_at_ms'] as num).toInt()) : null)).toRow()};
    throw const EvidenceGrowthApiError(404,'NOT_FOUND');
  }

  Future<EvidenceRouteResult> _route(EvidenceGrowthDao dao,String text) async {
    if(text.length>10000) throw ArgumentError('input too long');
    var result=const EvidenceGrowthRouter().route(text);
    result=const EvidenceGrowthRouter().route(text,personalFit:await dao.nodeFitScores(contextTags:result.contextTags));
    return result.copyWith(personalEvidence:await dao.personalEvidenceFor(result));
  }
  static String _text(Map<String,dynamic> body,String key) => body[key] as String? ?? '';
  static Map<String,String> _strings(Object? value) => value is Map
      ? value.map((key,value)=>MapEntry(key.toString(),value.toString())) : {};
  static Map<String,Object?> routeJson(EvidenceRouteResult r) => {'facts':r.facts,'primary_module':r.primaryModule.key,
    'secondary_modules':r.secondaryModules.map((m)=>m.key).toList(),'status':r.status,'risk_gate':r.riskGate,
    'candidates':r.candidates.map((c)=>{'node_id':c.node.id,'score':c.score,'reason':c.reason}).toList(),
    'knowledge_evidence':r.selectedNodes.map((n)=>n.toJson()).toList(),'personal_evidence':r.personalEvidence,
    'required_checks':r.requiredChecks,'missing_facts':r.missingFacts,'evidence_level':r.evidenceLevel,
    'inference':r.inference,'action':{'operator':r.operator,'instruction':r.actionInstruction,
      'completion_definition':r.completionDefinition,'review_trigger':r.reviewTrigger}};
}
