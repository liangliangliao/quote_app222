import '../services/global_ai_request_settings.dart';
import 'dart:convert';
import '../data/kv_dao.dart';
import '../models/quote_insight.dart';
import '../services/ai_request_audit.dart';
import '../services/semantic_json_transport.dart';
import '../services/unified_ai_service.dart';
import 'semantic_scope.dart';
import 'semantic_scope_service.dart';
import 'schopenhauer_guidance.dart';

class PhilosophyCase {
  final String id, title, boundary, forbidden;
  final List<ScopeSource> sources;
  final List<String> requiredViews;
  const PhilosophyCase(
      this.id, this.title, this.sources, this.boundary, this.forbidden, {this.requiredViews = const []});
}

const philosophyCases = [
  PhilosophyCase(
      'A',
      '正方形与长方形',
      [ScopeSource('A', '在欧氏平面中，正方形是四边相等且四角为直角的四边形；长方形是四角为直角的四边形。')],
      '按定义确定正方形包含于长方形，给内部成员及非正方形长方形；短而充分即可。',
      '不能反转包含方向，不能为了四层而添加同义节点或虚构生活场景。'),
  PhilosophyCase(
      'B',
      '旅行、健康与幸福',
      [
        ScopeSource('A', '旅行可能增广见闻，也可能耗费金钱、增加欲望或影响健康。职业成就与幸福是否一致，须结合目的和具体条件判断。')
      ],
      '区分概念外延、事件顺序、动机与因果假设；有明确成员才画圈。',
      '不能因共现或相近词就证明交集、因果或旅行必然幸福。'),
  PhilosophyCase(
      'C',
      '山上的树 · 文学隐喻',
      [
        ScopeSource('A', '人如同树一样。他愈求向上升，向光明，他的根便愈深入泥土，向下，向黑暗，向深处——向恶。',
            title: '尼采“山上的树”教学译写，非版本核定引文')
      ],
      '解释隐喻中的对应、差异和边界，标明本测试译写尚未核定版本。',
      '不能作为植物学定律，不能把“恶”直接解释成肌肉酸痛。'),
  PhilosophyCase(
      'D',
      '判断力与目的',
      [
        ScopeSource('A',
            '判断力须在局部相同中辨认决定性差异，也在局部不同中辨认共同规定。比较两个方案，目的从效率改为安全时，相关差异及结论可能随之改变。',
            origin: 'teaching_text')
      ],
      '明确目的、同异、哪项差异决定结论以及为何；保留条件与改判依据。',
      '不能只写都追求成长，不能在缺少方案材料时声称某方案一定更安全。'),
  PhilosophyCase(
      'E',
      '时间、空间与概念根据',
      [
        ScopeSource('A',
            '时间中的继起、空间中的位置、物质变化的因果条件以及概念判断的认识根据，须分别考察。记录发生的时间与地点，并不等于证明时间空间的先验形式。',
            origin: 'teaching_text')
      ],
      '区分存在、生成、认识和行动根据，以及纯粹直观与经验直观。',
      '不能把时间戳当先验形式的证明，不能由继起直接推出因果。'),
  PhilosophyCase(
      'F',
      '日记事实、解释与预测',
      [
        ScopeSource('A', '今天下午买了一本书。我感到安心。我猜购买让我不再焦虑，也担心以后每次焦虑都要购物。',
            origin: 'user_report')
      ],
      '区分报告事件、感受、因果解释、一般判断与预测，给能区分替代解释的观察。',
      '不能从一次报告推出普遍因果、诊断潜意识或声称已直接观察用户。'),
  PhilosophyCase(
      'G',
      '隆冬与内在的夏天 · 欲求与虚无',
      [
        ScopeSource('A', '在隆冬，我终于知道，我身上有一个不可战胜的夏天。',
            title: '用户反馈用例：加缪名言，译文与出处待核对'),
        ScopeSource('B', '人宁愿意欲虚无，也不愿不欲。', title: '用户反馈用例：尼采名言，译文与出处待核对'),
      ],
      '解释季节意象及内在力量的可能对应，用标注连线区分隐喻与类属；比较韧性与欲求、经验发现与偏好结构，保留各自根据。',
      '不能只写都涉及内在或A没说B；不能把夏天的同义改写当下位类，不能把欲求虚无等同没有欲求或伪造外延相交。'),
  PhilosophyCase('H', '持志如心痛 · 类属、内容与含义范围',
      [ScopeSource('A', '“持志如心痛。一心在痛上，岂有工夫说闲话、管闲事？”\n“初学工夫如此用亦好。……若只死死守着，恐于工夫上又发病。”', title: '用户提供的王阳明原文；省略处与版本待核对')],
      '分别建立同一论域的逐层限定与交叉分类、概念经中介返回直观的内容链、由定义支持的包含和交叠区域；分析性定义与教学情境均须明示。初学是阶段、专注是方式，可交叉而非直接上下位；命名交集位于共同区域。保留若、只、恐。',
      '不能将心痛与持志视为外延同一，不能把条件或隐喻箭头冒充树/圈；不能把专注等同持志的道德目标或把发病断言为确定医学因果；不要求固定层数/圈数，不以原文没列实例放弃合理的定义分析。',
      requiredViews: ['hierarchy', 'circles']),
];

const philosophyReviewDimensions = [
  '忠实原文',
  '概念准确',
  '关系恰当',
  '判断有效',
  '证据层级',
  '视图适合'
];

class PhilosophyBenchmarkService {
  final UnifiedAiService ai;
  final KeyValueDao storage;
  PhilosophyBenchmarkService({UnifiedAiService? ai, KeyValueDao? storage})
      : ai = ai ?? UnifiedAiService(),
        storage = storage ?? KeyValueDao();
  static const key = 'cognition.philosophy_benchmark.v1';
  Future<List<Map<String, dynamic>>> history() async {
    final raw = jsonDecode(await storage.getString(key) ?? '[]');
    return raw is List
        ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : [];
  }

  Future<void> save(Map<String, dynamic> run) async {
    final rows = await history();
    rows.removeWhere((r) => r['id'] == run['id']);
    rows.insert(0, run);
    await storage.setString(key, jsonEncode(rows.take(60).toList()));
  }

  Future<Map<String, dynamic>> run(
      PhilosophyCase item, AiOperation operation) async {
    final config = await ai.resolveGlobalConfig();
    if (!config.available) throw StateError('请先配置可用的文字 AI');
    final requestSettings = await GlobalAiRequestSettings().getConfig();
    final context = SemanticContext(requestedViews: item.requiredViews);
    final prompt = SemanticScopeService.buildPrompt(item.sources, item.title, context: context);
    final result = <String, dynamic>{
      'id': operation.id,
      'case': item.id,
      'title': item.title,
      'at': DateTime.now().toIso8601String(),
      'input': item.sources.map((s) => s.toJson()).toList(),
      'boundary': item.boundary,
      'forbidden': item.forbidden,
      'request_config': {
        'temperature': requestSettings.resolveTemperature(.2),
        'top_p': requestSettings.resolveTopP(),
        'timeout_seconds': requestSettings.timeoutSeconds,
        'global_output_ceiling': requestSettings.maxOutputTokens,
        'automatic_retries': 0
      },
      'model_config': {
        'provider': config.provider,
        'model': config.model,
        'deployment': config.deployment,
        'endpoint_hash': insightHash(config.endpoint)
      },
      'prompt_snapshot':
          prompt,
      'system_prompt_snapshot':
          '${SchopenhauerGuidance.basic}\n${SchopenhauerGuidance.core}',
      'provider_model_version': '以本次请求返回信息为准；未返回时未知',
      'prompt_version': SemanticScopeService.promptVersion,
      'policy_version': SchopenhauerGuidance.version,
      'schema_version': SemanticScope.version,
      'review_status': 'pending',
      'review': {
        for (final dimension in philosophyReviewDimensions) dimension: 'pending'
      },
    };
    await AiRequestAudit.runOperation(operation, () async {
      try {
        final raw = await ai.generateText(
            prompt: prompt,
            purpose: SemanticScopeService.requestPurpose,
            expectJson: true,
            maxTokens: 10000,
            temperature: .2,
            forcedProvider: config.provider,
            forcedModel: config.model);
        result['raw_json'] = raw;
        final parsed = await SemanticScopeService(ai: ai).validateResponse(raw, item.sources, item.title, config, context: context);
        result['local_issues'] = parsed.issues.map((i) => i.toJson()).toList();
        result['generation_status'] =
            parsed.needsRepair ? 'contract_issue' : 'received';
      } catch (error) {
        result['generation_status'] = operation.cancellation.cancelled
            ? 'cancelled'
            : error is SemanticRequestException
                ? (error.message.contains('额度') ? 'output_limit' : 'transport')
                : error is FormatException
                    ? 'format'
                    : 'request_error';
        result['error'] = error is SemanticRequestException
            ? error.message
            : error is FormatException
                ? error.message
                : '请求未完成，请结合本次请求日志检查';
      }
    });
    result['attempts'] = operation.attempts;
    await save(result);
    return result;
  }

  static String reviewStatus(Map<String, dynamic> run) {
    final review = run['review'];
    if (review is! Map ||
        philosophyReviewDimensions.any(
            (d) => !['pass', 'issue'].contains(review[d]))) return 'pending';
    if (philosophyReviewDimensions.any((d) => review[d] == 'issue'))
      return 'issues';
    return run['generation_status'] == 'received' ? 'passed' : 'issues';
  }
}
