import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/unified_ai_service.dart';
import 'evidence_growth_ai_cache.dart';
import 'evidence_growth_ai_json.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_journey_models.dart';
import 'evidence_growth_models.dart';
import 'evidence_growth_read_aloud.dart';

/// 「抽象知识 → 直观 → 理解 → 行动」6 步转换。
///
/// 输入只有两样：知识卡的【大标题】和【原案例 / 研究依据】。
/// 输出固定 6 步：还原问题 / 三正一反 / 类比或画图 / 用自己的话讲一遍 /
/// 压缩成行动规则 / 马上小实验。

class KnowledgeTransformRule {
  const KnowledgeTransformRule(this.trigger, this.action);
  final String trigger;
  final String action;
}

class KnowledgeTransform {
  const KnowledgeTransform({
    required this.core,
    required this.problem,
    required this.examples,
    required this.counter,
    required this.analogy,
    required this.differs,
    required this.diagram,
    required this.explain,
    required this.selfCheck,
    required this.rules,
    required this.action,
    required this.predict,
    required this.check,
    required this.safety,
    this.fromCache = false,
  });

  static const String defaultSelfCheck = '合上这张卡，用一两句话把它讲给一个外行听；讲不顺的地方，就是还没真懂的地方。';
  static const String defaultSafety =
      '如果做的时候明显不适、会影响到别人，或事情无法挽回，就停下；需要时请找信任的人或专业人士。';

  final String core;
  final String problem;
  final List<String> examples;
  final String counter;
  final String analogy;
  final String differs;
  final String diagram;
  final String explain;
  final String selfCheck;
  final List<KnowledgeTransformRule> rules;
  final String action;
  final String predict;
  final String check;
  final String safety;
  final bool fromCache;

  /// 解析模型返回；缺少任何一步的必要内容都视为失败，不做本地编造。
  factory KnowledgeTransform.fromJson(GrowthData json,
      {bool fromCache = false}) {
    String s(Object? v) => '${v ?? ''}'.trim();
    final experiment = growthMap(json['experiment']);
    final examples = growthStrings(json['examples'])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final rules = growthRows(json['rules'])
        .map((r) => KnowledgeTransformRule(s(r['trigger']), s(r['action'])))
        .where((r) => r.trigger.isNotEmpty && r.action.isNotEmpty)
        .toList();
    final selfCheck = s(json['selfCheck']);
    final safety = s(experiment['safety']);
    final result = KnowledgeTransform(
      core: s(json['core']),
      problem: s(json['problem']),
      examples: examples.take(3).toList(),
      counter: s(json['counter']),
      analogy: s(json['analogy']),
      differs: s(json['differs']),
      diagram: s(json['diagram']),
      explain: s(json['explain']),
      selfCheck: selfCheck.isEmpty ? defaultSelfCheck : selfCheck,
      rules: rules.take(3).toList(),
      action: s(experiment['action']),
      predict: s(experiment['predict']),
      check: s(experiment['check']),
      safety: safety.isEmpty ? defaultSafety : safety,
      fromCache: fromCache,
    );
    if (!result.isComplete) throw const FormatException('TRANSFORM_INCOMPLETE');
    return result;
  }

  bool get isComplete =>
      core.isNotEmpty &&
      problem.isNotEmpty &&
      examples.length == 3 &&
      counter.isNotEmpty &&
      analogy.isNotEmpty &&
      differs.isNotEmpty &&
      explain.isNotEmpty &&
      rules.isNotEmpty &&
      action.isNotEmpty &&
      predict.isNotEmpty &&
      check.isNotEmpty;

  GrowthData toJson() => {
        'core': core,
        'problem': problem,
        'examples': examples,
        'counter': counter,
        'analogy': analogy,
        'differs': differs,
        'diagram': diagram,
        'explain': explain,
        'selfCheck': selfCheck,
        'rules': [
          for (final r in rules) {'trigger': r.trigger, 'action': r.action}
        ],
        'experiment': {
          'action': action,
          'predict': predict,
          'check': check,
          'safety': safety,
        },
      };

  /// 复制与朗读共用的纯文本。
  String toPlainText(String title) {
    final b = StringBuffer()
      ..writeln(title)
      ..writeln('核心：$core')
      ..writeln()
      ..writeln('1 还原问题')
      ..writeln(problem)
      ..writeln()
      ..writeln('2 三正一反');
    for (var i = 0; i < examples.length; i++) {
      b.writeln('正例${i + 1}：${examples[i]}');
    }
    b
      ..writeln('反例：$counter')
      ..writeln()
      ..writeln('3 类比或画图')
      ..writeln('类比：$analogy')
      ..writeln('不像的地方：$differs');
    if (diagram.isNotEmpty) b.writeln(diagram);
    b
      ..writeln()
      ..writeln('4 用自己的话讲一遍')
      ..writeln(explain)
      ..writeln('自测：$selfCheck')
      ..writeln()
      ..writeln('5 压缩成行动规则');
    for (final r in rules) {
      b.writeln('${r.trigger}，${r.action}');
    }
    b
      ..writeln()
      ..writeln('6 马上小实验（24 小时内）')
      ..writeln('做什么：$action')
      ..writeln('事前预期：$predict')
      ..writeln('事后对照：$check')
      ..writeln('边界：$safety');
    return b.toString().trim();
  }
}

class KnowledgeTransformException implements Exception {
  const KnowledgeTransformException(this.message);
  final String message;
  @override
  String toString() => message;
}

class EvidenceGrowthKnowledgeTransform {
  EvidenceGrowthKnowledgeTransform({required this.dao, UnifiedAiService? ai})
      : _ai = ai ?? UnifiedAiService();
  final EvidenceGrowthDao dao;
  final UnifiedAiService _ai;

  /// 改动提示词或输出结构时递增，让旧缓存自动失效。
  static const String promptVersion = 'eg-transform.1';

  static const String systemPrompt = '''
你是「抽象知识 → 直观理解 → 实践行动」的转换教练。
唯一的知识来源是用户给出的【大标题】与【原案例 / 研究依据】。不得编造研究、数据、人名或原话；原文没有的细节不要当作原文。
严格按下面 6 步产出，只输出 JSON，不输出思考过程。
1 还原问题：这个知识是为了解决什么困境才被提出的？脱离问题场景的定义是死的。
2 三正一反：3 个具体、贴近日常的正例；再给 1 个反例（看起来像、但不适用），反例要划清边界，并体现原案例里已经提到的边界。
3 类比或画图：映射到常人熟悉的结构；类比必须保留“关系”而不是表面相似，并写明“哪里不像”。可选：用箭头和换行画一个不超过 4 行的文字简图。
4 用自己的话讲一遍：假设听众是外行，用大白话讲清楚；再给一个自测问题（卡住的地方就是没真懂的地方）。
5 压缩成行动规则：写成“当出现 X 时，我就做 Y”。X 必须是可观察的触发条件，Y 必须是具体动作。1 到 3 条。
6 马上小实验：24 小时内能做完、成本低的一次尝试；先写事前预期，事后对照差在哪，再回头修正理解。
硬性要求：
- 例子、类比、实验都是“假设性示例”，不能写成用户的真实经历。
- 简体中文，口语、具体，不说空话。
- 涉及痛苦、创伤、恐慌，或借债、辞职、押上全部积蓄这类重大不可逆决定时，实验只能是低风险的小步，并在 safety 里写明何时应停下、何时找专业人士。
- 不劝人硬撑；知识本身有适用边界时，如实写出来。
''';

  /// 只把大标题和原案例 / 研究依据交给模型，其他卡片字段不参与。
  static String buildPrompt(EvidenceKNode node) {
    final story = node.storyOrStudy.trim();
    return '【大标题】${node.title.trim()}\n'
        '【原案例 / 研究依据】${story.isEmpty ? '（卡片未提供原案例，只能依据大标题，并在 problem 中说明依据有限）' : story}\n'
        '只输出如下 JSON，字段都要有（diagram 没有就给空字符串）：\n'
        '{"core":"一句话核心，40字内",'
        '"problem":"还原问题，120字内",'
        '"examples":["正例1","正例2","正例3"],'
        '"counter":"反例与边界，120字内",'
        '"analogy":"类比，100字内",'
        '"differs":"类比哪里不像，60字内",'
        '"diagram":"可选文字简图，最多4行",'
        '"explain":"给外行的大白话，150字内",'
        '"selfCheck":"一个自测问题",'
        '"rules":[{"trigger":"当出现……","action":"我就……"}],'
        '"experiment":{"action":"24小时内做什么","predict":"事前先写下的预期","check":"事后对照什么、差多少怎么修正理解","safety":"何时不做或停下"}}';
  }

  static String reason(Object error) {
    if (error is TimeoutException) return '模型响应超时，请稍后重试或更换响应更快的文本模型。';
    if (error is FormatException) {
      if (error.message == 'INVALID_JSON') {
        return '模型没有返回完整的结构化内容，请点“重新分析”。';
      }
      if (error.message == 'TRANSFORM_INCOMPLETE') {
        return '模型返回的 6 步内容不完整，已拒绝采用，请点“重新分析”。';
      }
    }
    return '模型服务请求失败，请检查统一 AI 配置后重试。';
  }

  Future<KnowledgeTransform> transform(EvidenceKNode node,
      {bool refresh = false}) async {
    UnifiedAiResolvedConfig cfg;
    try {
      cfg = await _ai.resolveGlobalConfig();
    } catch (_) {
      throw const KnowledgeTransformException('读取 AI 配置失败，请检查统一 AI 设置。');
    }
    if (!cfg.available) {
      throw const KnowledgeTransformException('还没有可用的 AI 配置，请先配置统一 AI 服务。');
    }
    final data = await GrowthAiCache(dao).run(
      'knowledge_transform',
      [
        node.id,
        node.title,
        node.storyOrStudy,
        cfg.provider,
        cfg.model,
        cfg.endpoint,
        promptVersion,
      ],
      () async {
        try {
          final raw = await _ai
              .generateText(
                systemPrompt: systemPrompt,
                purpose: 'evidence_growth.knowledge_transform',
                expectJson: true,
                prompt: buildPrompt(node),
                maxTokens: 1800,
                temperature: .3,
              )
              .timeout(const Duration(seconds: 120));
          final parsed = KnowledgeTransform.fromJson(GrowthAiJson.decode(raw));
          return {'origin': 'AI', 'data': parsed.toJson()};
        } catch (e) {
          // 失败不进缓存，下次点开会重新请求。
          return {'origin': 'FAILED', 'reason': reason(e)};
        }
      },
      refresh: refresh,
    );
    if (data['origin'] != 'AI') {
      throw KnowledgeTransformException(
          '${data['reason'] ?? '生成失败，请稍后重试。'}');
    }
    return KnowledgeTransform.fromJson(growthMap(data['data']),
        fromCache: data['cache_hit'] == true);
  }
}

/// 点开后自动分析；同一张卡的成功结果会缓存，再次打开秒出。
class EvidenceGrowthKnowledgeTransformSheet extends StatefulWidget {
  const EvidenceGrowthKnowledgeTransformSheet(
      {super.key, required this.node, required this.dao});
  final EvidenceKNode node;
  final EvidenceGrowthDao dao;

  static Future<void> show(BuildContext context,
          {required EvidenceKNode node, required EvidenceGrowthDao dao}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) =>
            EvidenceGrowthKnowledgeTransformSheet(node: node, dao: dao),
      );

  @override
  State<EvidenceGrowthKnowledgeTransformSheet> createState() =>
      _KnowledgeTransformSheetState();
}

class _KnowledgeTransformSheetState
    extends State<EvidenceGrowthKnowledgeTransformSheet> {
  KnowledgeTransform? result;
  String? error;
  bool loading = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _request++;
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    final current = ++_request;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await EvidenceGrowthKnowledgeTransform(dao: widget.dao)
          .transform(widget.node, refresh: refresh);
      if (!mounted || current != _request) return;
      setState(() => result = r);
    } catch (e) {
      if (!mounted || current != _request) return;
      setState(() => error = e is KnowledgeTransformException
          ? e.message
          : '生成失败，请稍后重试。');
    } finally {
      if (mounted && current == _request) setState(() => loading = false);
    }
  }

  Future<void> _copy(KnowledgeTransform r) async {
    await Clipboard.setData(
        ClipboardData(text: r.toPlainText(widget.node.title)));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已复制全文')));
  }

  Widget _section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 6),
          ...children,
        ]),
      );

  Widget _text(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SelectableText(text, style: const TextStyle(height: 1.5)));

  Widget _tagged(String label, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SelectableText.rich(
          TextSpan(children: [
            TextSpan(
                text: '$label ',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: text),
          ]),
          style: const TextStyle(height: 1.5)));

  Widget _diagram(String text) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(8)),
      child: SelectableText(text,
          style: const TextStyle(fontFamily: 'monospace', height: 1.4)));

  List<Widget> _body(KnowledgeTransform r) => [
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SelectableText('核心：${r.core}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, height: 1.45))),
        _section('1 还原问题', [_text(r.problem)]),
        _section('2 三正一反', [
          for (var i = 0; i < r.examples.length; i++)
            _tagged('正例${i + 1}', r.examples[i]),
          _tagged('反例', r.counter),
        ]),
        _section('3 类比或画图', [
          _tagged('类比', r.analogy),
          _tagged('不像的地方', r.differs),
          if (r.diagram.isNotEmpty) _diagram(r.diagram),
        ]),
        _section('4 用自己的话讲一遍', [
          _text(r.explain),
          _tagged('自测', r.selfCheck),
        ]),
        _section('5 压缩成行动规则', [
          for (final rule in r.rules) _text('${rule.trigger}，${rule.action}'),
        ]),
        _section('6 马上小实验（24 小时内）', [
          _tagged('做什么', r.action),
          _tagged('事前预期', r.predict),
          _tagged('事后对照', r.check),
          _tagged('边界', r.safety),
        ]),
      ];

  @override
  Widget build(BuildContext context) {
    final r = result;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(widget.node.title,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text('知识转换 · 6 步', style: Theme.of(context).textTheme.labelMedium),
      if (r != null) EvidenceGrowthReadAloud(text: r.toPlainText(widget.node.title)),
      if (loading && r != null)
        const Padding(
            padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      if (loading && r == null)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Column(children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('正在把这条知识转成直观与行动…'),
            ])),
      if (error != null)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error))),
      if (r != null) ..._body(r),
      const SizedBox(height: 20),
      if (r != null)
        Text(
            '由 AI 依据「大标题 + 原案例/研究依据」生成${r.fromCache ? '（已缓存）' : ''}。例子、类比和实验都是假设性示例，不是原文，也不是你的经历；请对照原卡核对。',
            style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(
            onPressed: loading ? null : () => _load(refresh: true),
            icon: const Icon(Icons.refresh),
            label: Text(r == null ? '重试' : '重新分析')),
        if (r != null)
          OutlinedButton.icon(
              onPressed: () => _copy(r),
              icon: const Icon(Icons.copy_outlined),
              label: const Text('复制全文')),
      ]),
    ]);
  }
}
