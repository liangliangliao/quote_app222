import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_jev.dart';
import 'evidence_growth_journey_models.dart';

/// AI + JEV action execution forecasting.
///
/// The headline value is an uncalibrated model estimate until enough personal
/// outcomes are collected. It must never be presented as a guaranteed
/// probability or as a substitute for the user's decision.
class EvidenceGrowthActionPredictionService {
  EvidenceGrowthActionPredictionService({
    required EvidenceGrowthDao dao,
    UnifiedAiService? ai,
    EvidenceGrowthJev? jev,
  })  : _dao = dao,
        _ai = ai ?? UnifiedAiService(),
        _jev = jev ?? EvidenceGrowthJev();

  final EvidenceGrowthDao _dao;
  final UnifiedAiService _ai;
  final EvidenceGrowthJev _jev;

  static const historySetting = 'action_prediction_history_v1';
  static const factorLabels = <String, String>{
    'history': '过去相似行为',
    'specificity': '计划具体度',
    'trigger': '时间／情境触发',
    'emotion': '临场情绪驱动力',
    'friction': '现实阻力',
    'alternatives': '替代行为竞争',
    'self_efficacy': '自我效能',
    'external_commitment': '外部约束／承诺',
    'decision_stability': '临场重新决策风险',
  };

  Future<GrowthData> predict({
    required String plan,
    DateTime? scheduledAt,
    String context = '',
    String similarHistory = '',
    GrowthJourney? journey,
    String jevApiKey = '',
  }) async {
    final action = plan.trim();
    if (action.isEmpty) throw ArgumentError('请先写清楚接下来准备做什么');
    if (action.length > 2000 || context.length > 6000 || similarHistory.length > 4000) {
      throw ArgumentError('输入过长，请保留真正会影响这次行动的事实');
    }

    final records = await history();
    final resolved = records
        .where((r) => const {'ON_TIME', 'LATE', 'NOT_DONE'}.contains(r['outcome']))
        .toList();
    final onTime = resolved.where((r) => r['outcome'] == 'ON_TIME').length;
    final baseline = resolved.isEmpty ? null : (onTime + 1) / (resolved.length + 2);

    final state = <String, dynamic>{
      'plan': action,
      'scheduled_at': scheduledAt?.toIso8601String() ?? '',
      'current_context': context.trim(),
      'similar_history_report': similarHistory.trim(),
      if (journey != null)
        'journey': {
          'goal': journey.title,
          'node': journey.node,
          'status': journey.status,
          'current_facts': journey.data['current'],
          'belief': journey.data['belief'],
          'plan': journey.plan,
          'next_change': journey.data['next_change'],
        },
      'personal_history_summary': {
        'resolved_count': resolved.length,
        'on_time_count': onTime,
        'smoothed_on_time_rate': baseline,
        'recent': [
          for (final r in resolved.take(12))
            {
              'plan': r['plan'],
              'scheduled_at_ms': r['scheduled_at_ms'],
              'forecast': r['estimate'],
              'outcome': r['outcome'],
            }
        ]
      },
    };

    final ai = await _aiAssessment(state);
    GrowthData jev = {'status': 'LOCAL', 'reason': 'JEV_NOT_CONFIGURED'};
    if (jevApiKey.trim().isNotEmpty) {
      final jevState = {
        ...state,
        'ai_structured_extraction': {
          'factors': ai['factors'],
          'missing_information': ai['missing_information'],
          'failure_modes': ai['failure_modes'],
        }
      };
      jev = await _jev.assessAction(jevState, apiKey: jevApiKey.trim());
    }

    final aiEstimate = _prob(ai['execution_likelihood']);
    final jevEstimate = _prob(jev['overall']);
    final modelEstimates = <double>[
      if (aiEstimate != null) aiEstimate,
      if (jevEstimate != null) jevEstimate,
    ];
    final modelCenter = modelEstimates.isEmpty
        ? null
        : modelEstimates.reduce((a, b) => a + b) / modelEstimates.length;

    double? estimate = modelCenter;
    double historyWeight = 0;
    if (estimate != null && baseline != null && resolved.length >= 3) {
      historyWeight = (resolved.length / 30 * .30).clamp(0, .30).toDouble();
      estimate = estimate * (1 - historyWeight) + baseline * historyWeight;
    } else if (estimate == null && baseline != null && resolved.length >= 5) {
      estimate = baseline;
      historyWeight = 1;
    }

    final factors = <String, GrowthData>{};
    final aiFactors = growthMap(ai['factors']);
    final jevFactors = growthMap(jev['factors']);
    for (final key in factorLabels.keys) {
      final a = _prob(growthMap(aiFactors[key])['score']);
      final j = _prob(jevFactors[key]);
      final values = <double>[if (a != null) a, if (j != null) j];
      factors[key] = {
        'label': factorLabels[key],
        'ai': a,
        'jev': j,
        'score': values.isEmpty
            ? null
            : values.reduce((x, y) => x + y) / values.length,
        'evidence': growthMap(aiFactors[key])['evidence'] ?? '',
        'confidence': _prob(growthMap(aiFactors[key])['confidence']),
      };
    }

    final ranked = factors.entries
        .where((e) => e.value['score'] is num)
        .toList()
      ..sort((a, b) =>
          (a.value['score'] as num).compareTo(b.value['score'] as num));

    final disagreement = aiEstimate != null &&
        jevEstimate != null &&
        (aiEstimate - jevEstimate).abs() >= .20;
    final id = 'ap_${DateTime.now().microsecondsSinceEpoch}';

    return {
      'id': id,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      'plan': action,
      'scheduled_at_ms': scheduledAt?.millisecondsSinceEpoch ?? 0,
      'context': context.trim(),
      'similar_history': similarHistory.trim(),
      'journey_id': journey?.id ?? '',
      'estimate_available': estimate != null,
      'estimate': estimate,
      'band': estimate == null ? '信息不足' : band(estimate),
      'agreement': disagreement
          ? 'MODEL_DISAGREEMENT'
          : modelEstimates.length >= 2
              ? 'MODEL_AGREEMENT'
              : 'SINGLE_MODEL',
      'ai': ai,
      'jev': jev,
      'history_baseline': {
        'resolved_count': resolved.length,
        'on_time_count': onTime,
        'rate': baseline,
        'weight': historyWeight,
      },
      'factors': factors,
      'top_risks': [
        for (final e in ranked.take(3))
          {
            'key': e.key,
            'label': factorLabels[e.key],
            'score': e.value['score'],
            'evidence': e.value['evidence'],
          }
      ],
      'missing_information': growthStrings(ai['missing_information']).take(5).toList(),
      'failure_modes': growthStrings(ai['failure_modes']).take(5).toList(),
      'protective_actions': growthStrings(ai['protective_actions']).take(5).toList(),
      'calibration_note': resolved.length < 5
          ? '当前主要是 AI/JEV 的未校准估计；记录真实结果后，个人基线才会逐步参与校准。'
          : '已使用个人历史基线做有限校准；样本仍只代表你的历史记录，不保证未来结果。',
      'outcome': 'PENDING',
    };
  }

  Future<GrowthData> _aiAssessment(GrowthData state) async {
    UnifiedAiResolvedConfig config;
    try {
      config = await _ai.resolveGlobalConfig();
    } catch (_) {
      return {'status': 'LOCAL', 'reason': 'AI_CONFIG_UNAVAILABLE'};
    }
    if (!config.available) {
      return {'status': 'LOCAL', 'reason': 'AI_NOT_CONFIGURED'};
    }

    try {
      final raw = await _ai.generateText(
        purpose: 'evidence_growth.action_prediction',
        systemPrompt: '''
你是“行动发生可能性预测器”的结构化分析器。目标是帮助用户检验计划是否可能如期发生，不替用户做决定。
只根据提供的事实分析；未知就是未知，禁止补写人格、动机、诊断或历史。
九个因素的 score 范围 0-1，1 表示更支持“该行动会按计划发生”，0 表示更阻碍。
history=过去相似行为；specificity=计划具体度；trigger=时间/情境触发；
emotion=临场情绪总体是否推动；friction=现实阻力是否低且可克服；
alternatives=替代行为是否不容易抢走行动；self_efficacy=用户是否相信能完成；
external_commitment=预约、他人等待、损失、截止等外部约束；
decision_stability=临场是否不容易重新开放“去不去”的决定。
execution_likelihood 是综合模型估计，不得声称是统计学保证。
evidence 只能引用或忠实概括 state 中的事实。信息不足时 score 可给 0.5，但 confidence 必须低，并把问题写入 missing_information。
protective_actions 只针对最关键的 1-3 个可改变因素，优先具体触发、降低摩擦、预先决定、准备环境，不说空泛鸡汤。
只输出 JSON，不输出思维过程。
''',
        prompt: '''STATE:
${jsonEncode(state)}
返回：
{
  "summary":"一句话概括",
  "execution_likelihood":0.0,
  "factors":{
    "history":{"score":0.0,"confidence":0.0,"evidence":""},
    "specificity":{"score":0.0,"confidence":0.0,"evidence":""},
    "trigger":{"score":0.0,"confidence":0.0,"evidence":""},
    "emotion":{"score":0.0,"confidence":0.0,"evidence":""},
    "friction":{"score":0.0,"confidence":0.0,"evidence":""},
    "alternatives":{"score":0.0,"confidence":0.0,"evidence":""},
    "self_efficacy":{"score":0.0,"confidence":0.0,"evidence":""},
    "external_commitment":{"score":0.0,"confidence":0.0,"evidence":""},
    "decision_stability":{"score":0.0,"confidence":0.0,"evidence":""}
  },
  "missing_information":["最多5个真正会改变预测的问题"],
  "failure_modes":["最可能的具体失败路径"],
  "protective_actions":["最值得立刻修改的行动条件"]
}''',
        expectJson: true,
        temperature: .1,
        maxTokens: 1800,
      ).timeout(const Duration(seconds: 25));
      final decoded = _decode(raw);
      final likelihood = _prob(decoded['execution_likelihood']);
      if (likelihood == null) throw const FormatException('INVALID_LIKELIHOOD');
      final output = <String, dynamic>{};
      final inputFactors = growthMap(decoded['factors']);
      for (final key in factorLabels.keys) {
        final row = growthMap(inputFactors[key]);
        final score = _prob(row['score']);
        final confidence = _prob(row['confidence']);
        if (score == null || confidence == null) {
          throw FormatException('INVALID_FACTOR_$key');
        }
        output[key] = {
          'score': score,
          'confidence': confidence,
          'evidence': '${row['evidence'] ?? ''}'.trim(),
        };
      }
      return {
        'status': 'AI',
        'model': config.displayModel,
        'summary': '${decoded['summary'] ?? ''}'.trim(),
        'execution_likelihood': likelihood,
        'factors': output,
        'missing_information': growthStrings(decoded['missing_information']),
        'failure_modes': growthStrings(decoded['failure_modes']),
        'protective_actions': growthStrings(decoded['protective_actions']),
      };
    } catch (e) {
      return {
        'status': 'LOCAL',
        'reason': e is FormatException ? e.message : 'AI_REQUEST_FAILED'
      };
    }
  }

  Future<List<GrowthData>> history() async {
    final raw = await _dao.getSetting(historySetting);
    if (raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map(growthMap).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePrediction(GrowthData result) async {
    final rows = await history();
    rows.insert(0, result);
    if (rows.length > 100) rows.removeRange(100, rows.length);
    await _dao.setSetting(historySetting, jsonEncode(rows));
  }

  Future<void> recordOutcome(String id, String outcome) async {
    if (!const {'ON_TIME', 'LATE', 'NOT_DONE'}.contains(outcome)) {
      throw ArgumentError('未知结果');
    }
    final rows = await history();
    final index = rows.indexWhere((r) => r['id'] == id);
    if (index < 0) throw StateError('预测记录不存在');
    rows[index] = {
      ...rows[index],
      'outcome': outcome,
      'outcome_at_ms': DateTime.now().millisecondsSinceEpoch,
    };
    await _dao.setSetting(historySetting, jsonEncode(rows));
  }

  Future<void> clearHistory() => _dao.setSetting(historySetting, '');

  static String band(double value) {
    if (value >= .85) return '执行条件很强';
    if (value >= .70) return '执行条件较强';
    if (value >= .55) return '中等，仍有明显变数';
    if (value >= .40) return '偏低，需要先修关键阻力';
    return '较低，计划结构容易失效';
  }

  static GrowthData _decode(String raw) {
    var text = raw.trim();
    final fence = String.fromCharCodes([96, 96, 96]);
    if (text.startsWith(fence)) {
      text = text.replaceFirst(RegExp(r'^...(?:json)?\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*...$'), '');
    }
    final value = jsonDecode(text);
    if (value is! Map) throw const FormatException('INVALID_JSON_OBJECT');
    return growthMap(value);
  }

  static double? _prob(Object? value) {
    if (value is! num || !value.isFinite) return null;
    final p = value.toDouble();
    if (p < 0 || p > 1) return null;
    return p;
  }
}
