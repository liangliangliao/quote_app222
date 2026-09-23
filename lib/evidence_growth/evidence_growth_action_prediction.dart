import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_jev.dart';
import 'evidence_growth_journey_models.dart';

/// AI + JEV action execution forecasting.
///
/// The headline value remains a model estimate until enough personal outcomes
/// are collected. Unknown evidence is kept neutral instead of being converted
/// into a negative signal.
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

  /// Every score means "how much this factor supports execution".
  static const factorLabels = <String, String>{
    'history': '过去相似行为支持度',
    'specificity': '计划具体度',
    'trigger': '时间／情境触发清晰度',
    'emotion': '临场情绪支持度',
    'friction': '现实阻力可克服性',
    'alternatives': '替代行为不抢占',
    'self_efficacy': '自我效能',
    'external_commitment': '外部约束／承诺',
    'decision_stability': '决策稳定性（不临场反悔）',
  };

  Future<GrowthData> predict({
    required String plan,
    DateTime? scheduledAt,
    String context = '',
    String similarHistory = '',
    GrowthData structuredContext = const {},
    GrowthJourney? journey,
    String jevApiKey = '',
  }) async {
    final action = plan.trim();
    if (action.isEmpty) throw ArgumentError('请先写清楚接下来准备做什么');
    if (action.length > 2000 ||
        context.length > 6000 ||
        similarHistory.length > 4000) {
      throw ArgumentError('输入过长，请保留真正会影响这次行动的事实');
    }

    final records = await history();
    final resolved = records
        .where((r) =>
            const {'ON_TIME', 'LATE', 'NOT_DONE'}.contains(r['outcome']))
        .toList();
    final onTime = resolved.where((r) => r['outcome'] == 'ON_TIME').length;
    final baseline =
        resolved.isEmpty ? null : (onTime + 1) / (resolved.length + 2);

    final state = <String, dynamic>{
      'plan': action,
      'scheduled_at': scheduledAt?.toIso8601String() ?? '',
      'user_reported_conditions': structuredContext,
      'additional_notes': context.trim(),
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
      jev = await _jev.assessAction({
        ...state,
        'ai_structured_extraction': {
          'factors': ai['factors'],
          'missing_information': ai['missing_information'],
          'failure_modes': ai['failure_modes'],
        }
      }, apiKey: jevApiKey.trim());
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
      historyWeight =
          (resolved.length / 30 * .30).clamp(0, .30).toDouble();
      estimate = estimate * (1 - historyWeight) + baseline * historyWeight;
    } else if (estimate == null && baseline != null && resolved.length >= 5) {
      estimate = baseline;
      historyWeight = 1;
    }

    final factors = <String, GrowthData>{};
    final aiFactors = growthMap(ai['factors']);
    final jevFactors = growthMap(jev['factors']);
    for (final key in factorLabels.keys) {
      final aiRow = growthMap(aiFactors[key]);
      final aiStatus = '${aiRow['status'] ?? 'UNKNOWN'}';
      final aiConfidence = _prob(aiRow['confidence']);
      final a = _prob(aiRow['score']);
      final j = _prob(jevFactors[key]);
      final values = <double>[
        if (a != null) a,
        if (j != null) j,
      ];
      final unknown =
          aiStatus == 'UNKNOWN' && (aiConfidence == null || aiConfidence < .5);
      final combined = values.isEmpty
          ? null
          : values.reduce((x, y) => x + y) / values.length;
      factors[key] = {
        'label': factorLabels[key],
        'ai': a,
        'jev': j,
        'score': combined,
        'display_score': unknown ? null : combined,
        'status': aiStatus,
        'unknown': unknown,
        'evidence': _humanEvidence(
            key, '${aiRow['evidence'] ?? ''}', state, resolved.length),
        'confidence': aiConfidence,
      };
    }

    final riskRows = factors.entries
        .where((e) {
          final row = e.value;
          if (row['unknown'] == true) return false;
          if (row['status'] == 'RISK') return true;
          final score = row['score'];
          final confidence = row['confidence'];
          return score is num &&
              score < .5 &&
              (confidence == null ||
                  (confidence is num && confidence.toDouble() >= .45));
        })
        .toList()
      ..sort((a, b) =>
          ((a.value['score'] as num?) ?? 1)
              .compareTo((b.value['score'] as num?) ?? 1));

    final disagreement = aiEstimate != null &&
        jevEstimate != null &&
        (aiEstimate - jevEstimate).abs() >= .20;

    final improvement = growthMap(ai['improvement_scenario']);
    final improvementChanges =
        growthStrings(improvement['changes']).take(4).toList();
    final improvementAi = _prob(improvement['execution_likelihood']);
    GrowthData improvementJev = {
      'status': 'LOCAL',
      'reason': 'JEV_NOT_CONFIGURED'
    };
    if (improvementChanges.isNotEmpty &&
        jevApiKey.trim().isNotEmpty &&
        improvementAi != null) {
      improvementJev = await _jev.assessAction({
        ...state,
        'plan': '${improvement['revised_plan'] ?? action}',
        'hypothetical': true,
        'hypothetical_changes': improvementChanges,
      }, apiKey: jevApiKey.trim());
    }
    final improvementJevEstimate = _prob(improvementJev['overall']);
    final improvementModels = <double>[
      if (improvementAi != null) improvementAi,
      if (improvementJevEstimate != null) improvementJevEstimate,
    ];
    final improvementEstimate = improvementModels.isEmpty
        ? null
        : improvementModels.reduce((a, b) => a + b) /
            improvementModels.length;
    final improvementGain =
        improvementEstimate != null && estimate != null
            ? improvementEstimate - estimate
            : null;

    final id = 'ap_${DateTime.now().microsecondsSinceEpoch}';

    return {
      'id': id,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      'plan': action,
      'scheduled_at_ms': scheduledAt?.millisecondsSinceEpoch ?? 0,
      'context': context.trim(),
      'structured_context': structuredContext,
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
      'headline': '${ai['summary'] ?? ''}'.trim(),
      'headline_reason': '${ai['headline_reason'] ?? ''}'.trim(),
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
        for (final e in riskRows.take(3))
          {
            'key': e.key,
            'label': factorLabels[e.key],
            'score': e.value['score'],
            'evidence': e.value['evidence'],
          }
      ],
      'missing_information':
          growthStrings(ai['missing_information']).take(4).toList(),
      'failure_modes': growthStrings(ai['failure_modes']).take(4).toList(),
      'protective_actions':
          growthStrings(ai['protective_actions']).take(3).toList(),
      'improvement_scenario': {
        'revised_plan': '${improvement['revised_plan'] ?? ''}'.trim(),
        'changes': improvementChanges,
        'explanation': '${improvement['explanation'] ?? ''}'.trim(),
        'ai_estimate': improvementAi,
        'jev_estimate': improvementJevEstimate,
        'estimate': improvementEstimate,
        'gain': improvementGain,
        'is_hypothetical': true,
      },
      'calibration_note': resolved.length < 5
          ? '你还没有足够的个人结果记录，所以当前主要依赖 AI/JEV 的模型判断。记录真实结果后，个人基线会逐渐参与校准。'
          : '已经加入你的个人历史基线进行有限校准；它仍然是预测，不是保证。',
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
      final raw = await _ai
          .generateText(
            purpose: 'evidence_growth.action_prediction',
            systemPrompt: '''
你是“行动发生可能性预测器”的结构化分析器。目标是帮助用户判断一个具体行动能否按计划发生，并找到最值得修改的执行条件；不替用户做价值判断。

规则：
1. 只根据 state 的事实分析。未知就是未知，绝不能把“没有提供信息”当成负面事实。
2. 九个因素 score 范围 0-1，1 表示更支持“行动按计划发生”，0 表示更阻碍。
3. 每个因素必须给 status：SUPPORT / RISK / UNKNOWN。信息不足时 status=UNKNOWN、score 接近 0.5、confidence 较低。
4. evidence、summary、headline_reason、failure_modes、protective_actions、missing_information 必须是自然中文，面向普通用户。绝对不要输出字段名、JSON key、null、[]、resolved_count、similar_history_report、personal_history_summary 等内部实现细节。
5. 不要因为没有个人历史而降低 history 分数；应标记 UNKNOWN。只有明确提供了相似行为记录，才判断其支持或阻碍。
6. protective_actions 必须具体到马上能做的物理动作或可设置条件，最多3条，不说“提高动力”“坚持一下”之类空话。
7. improvement_scenario 是“假设这些改变真的完成之后”的情景模拟，不是保证。只改变最关键的1-3个可控因素，不改变外部世界中未知事实。
8. execution_likelihood 和 improvement_scenario.execution_likelihood 都是模型估计，不得声称具有统计保证。
9. 不输出推理过程，只输出 JSON。
''',
            prompt: '''STATE:
${jsonEncode(state)}
返回：
{
  "summary":"一句话结论，例如：这一步目前把握偏低，主要卡在触发不清和临场重新决策。",
  "headline_reason":"用1-2句人话解释为什么，不得出现内部字段名。",
  "execution_likelihood":0.0,
  "overall_confidence":0.0,
  "factors":{
    "history":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "specificity":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "trigger":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "emotion":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "friction":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "alternatives":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "self_efficacy":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "external_commitment":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "decision_stability":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""}
  },
  "missing_information":["最多4个真正会改变预测、且用户容易回答的问题"],
  "failure_modes":["最多3条具体失败路径"],
  "protective_actions":["最多3条现在就能执行的具体动作"],
  "improvement_scenario":{
    "revised_plan":"把原计划改写成更可执行的一句话",
    "changes":["最多3条假设已经完成的改变"],
    "execution_likelihood":0.0,
    "explanation":"为什么这些改变可能提高执行机会，明确这是情景模拟"
  }
}''',
            expectJson: true,
            temperature: .1,
            maxTokens: 2200,
          )
          .timeout(const Duration(seconds: 25));

      final decoded = _decode(raw);
      final likelihood = _prob(decoded['execution_likelihood']);
      if (likelihood == null) {
        throw const FormatException('INVALID_LIKELIHOOD');
      }

      final output = <String, dynamic>{};
      final inputFactors = growthMap(decoded['factors']);
      for (final key in factorLabels.keys) {
        final row = growthMap(inputFactors[key]);
        final score = _prob(row['score']);
        final confidence = _prob(row['confidence']);
        final status = '${row['status'] ?? 'UNKNOWN'}'.toUpperCase();
        if (score == null ||
            confidence == null ||
            !const {'SUPPORT', 'RISK', 'UNKNOWN'}.contains(status)) {
          throw FormatException('INVALID_FACTOR_$key');
        }
        output[key] = {
          'score': score,
          'confidence': confidence,
          'status': status,
          'evidence': '${row['evidence'] ?? ''}'.trim(),
        };
      }

      final scenario = growthMap(decoded['improvement_scenario']);
      final scenarioLikelihood = _prob(scenario['execution_likelihood']);

      return {
        'status': 'AI',
        'model': config.displayModel,
        'summary': _cleanUserText('${decoded['summary'] ?? ''}'),
        'headline_reason':
            _cleanUserText('${decoded['headline_reason'] ?? ''}'),
        'execution_likelihood': likelihood,
        'overall_confidence': _prob(decoded['overall_confidence']),
        'factors': output,
        'missing_information': growthStrings(decoded['missing_information'])
            .map(_cleanUserText)
            .where((e) => e.isNotEmpty)
            .toList(),
        'failure_modes': growthStrings(decoded['failure_modes'])
            .map(_cleanUserText)
            .where((e) => e.isNotEmpty)
            .toList(),
        'protective_actions': growthStrings(decoded['protective_actions'])
            .map(_cleanUserText)
            .where((e) => e.isNotEmpty)
            .toList(),
        'improvement_scenario': {
          'revised_plan':
              _cleanUserText('${scenario['revised_plan'] ?? ''}'),
          'changes': growthStrings(scenario['changes'])
              .map(_cleanUserText)
              .where((e) => e.isNotEmpty)
              .toList(),
          'execution_likelihood': scenarioLikelihood,
          'explanation':
              _cleanUserText('${scenario['explanation'] ?? ''}'),
        },
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
    if (value >= .85) return '很可能按计划发生';
    if (value >= .70) return '把握较高';
    if (value >= .55) return '有一定把握，但仍可能被打断';
    if (value >= .40) return '把握偏低，先修关键阻力';
    return '当前执行条件较弱，容易拖延或不执行';
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

  static String _cleanUserText(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    if (_looksTechnical(text)) return '';
    return text;
  }

  static bool _looksTechnical(String text) {
    const tokens = [
      'similar_history_report',
      'personal_history_summary',
      'resolved_count',
      'on_time_count',
      'smoothed_on_time_rate',
      'current_context',
      'structured_context',
      'recent=[]',
      'null',
    ];
    return tokens.any(text.contains) ||
        RegExp(r'\b[a-z]+_[a-z_]+\b').hasMatch(text);
  }

  static String _humanEvidence(
      String key, String raw, GrowthData state, int resolvedCount) {
    final cleaned = _cleanUserText(raw);
    if (cleaned.isNotEmpty) return cleaned;

    final structured = growthMap(state['user_reported_conditions']);
    final list = (String name) => growthStrings(structured[name]);
    final history = '${state['similar_history_report'] ?? ''}'.trim();

    switch (key) {
      case 'history':
        if (history.isNotEmpty) {
          return '你提供了过去相似行动的实际经历，可作为这次判断的参考。';
        }
        if (resolvedCount == 0) {
          return '还没有足够的相似行动结果记录，这一项暂时保持未知，不算负面证据。';
        }
        return '已经有 $resolvedCount 次真实行动结果，可用于个人基线校准。';
      case 'emotion':
        final values = list('emotions');
        return values.isEmpty
            ? '尚未说明临近行动时最可能出现的情绪。'
            : '你当前选择的情绪：${values.join('、')}。';
      case 'friction':
        final values = list('frictions');
        return values.isEmpty
            ? '尚未记录明显的时间、距离、疲劳或流程阻力。'
            : '目前记录的现实阻力：${values.join('、')}。';
      case 'alternatives':
        final values = list('alternatives');
        return values.isEmpty
            ? '尚未记录会和目标行动竞争的更舒服替代行为。'
            : '可能抢走行动的替代选择：${values.join('、')}。';
      case 'external_commitment':
        final values = list('commitments');
        return values.isEmpty
            ? '目前没有记录到明确的打卡、截止时间、他人等待或即时损失等外部约束。'
            : '当前外部约束：${values.join('、')}。';
      case 'trigger':
        final values = list('execution_support');
        final scheduled = '${state['scheduled_at'] ?? ''}'.trim();
        if (values.isNotEmpty) {
          return '已经设置的启动条件：${values.join('、')}。';
        }
        return scheduled.isEmpty
            ? '还没有明确到“什么一发生就立即开始”的启动触发。'
            : '已经指定开始时间，但还没有记录更具体的启动动作或提前准备。';
      case 'self_efficacy':
        final value = '${structured['self_efficacy'] ?? ''}'.trim();
        return value.isEmpty
            ? '尚未说明你对自己完成这一步的把握。'
            : '你对完成这一步的判断：$value。';
      case 'decision_stability':
        final value = '${structured['decision_stability'] ?? ''}'.trim();
        return value.isEmpty
            ? '尚未说明到行动时会直接执行，还是会重新考虑去不去。'
            : '你对临场决策的描述：$value。';
      case 'specificity':
        return '系统会根据行动内容、开始时间和启动步骤判断计划是否足够具体。';
      default:
        return '这一项目前还需要更多现实信息。';
    }
  }
}
