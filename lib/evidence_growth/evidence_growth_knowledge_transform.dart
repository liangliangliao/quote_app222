import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/unified_ai_service.dart';
import 'evidence_growth_ai_cache.dart';
import 'evidence_growth_ai_json.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_knowledge_transform_history.dart';
import 'evidence_growth_knowledge_transform_model.dart';
import 'evidence_growth_knowledge_transform_store.dart';
import 'evidence_growth_models.dart';
import 'evidence_growth_read_aloud.dart';

export 'evidence_growth_knowledge_transform_model.dart';
export 'evidence_growth_knowledge_transform_store.dart';

class KnowledgeTransformException implements Exception {
  const KnowledgeTransformException(this.message);
  final String message;
  @override
  String toString() => message;
}

class EvidenceGrowthKnowledgeTransform {
  EvidenceGrowthKnowledgeTransform(
      {required this.dao,
      UnifiedAiService? ai,
      EvidenceGrowthKnowledgeTransformStore? store})
      : _ai = ai ?? UnifiedAiService(),
        store = store ?? EvidenceGrowthKnowledgeTransformStore(dao);
  final EvidenceGrowthDao dao;
  final UnifiedAiService _ai;

  /// 转换成功后自动写入的本地历史（只增不改）。
  final EvidenceGrowthKnowledgeTransformStore store;

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

  /// 「大标题 + 原案例」的指纹；原卡片改动后可据此提示历史记录基于旧版本。
  static String sourceHash(EvidenceKNode node) => GrowthAiCache.fingerprint(
      [node.title.trim(), node.storyOrStudy.trim()]);

  /// 调 AI 转换一次；成功后自动追加保存为一条新的历史记录。
  /// 不读取、不改动已有历史，所以重新转换永远不会覆盖旧内容。
  /// 失败（含超时、结构不完整）直接抛出，不写入任何东西。
  Future<KnowledgeTransformEntry> convertAndSave(EvidenceKNode node) async {
    UnifiedAiResolvedConfig cfg;
    try {
      cfg = await _ai.resolveGlobalConfig();
    } catch (_) {
      throw const KnowledgeTransformException('读取 AI 配置失败，请检查统一 AI 设置。');
    }
    if (!cfg.available) {
      throw const KnowledgeTransformException('还没有可用的 AI 配置，请先配置统一 AI 服务。');
    }
    final KnowledgeTransform parsed;
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
      parsed = KnowledgeTransform.fromJson(GrowthAiJson.decode(raw));
    } catch (e) {
      throw KnowledgeTransformException(reason(e));
    }
    final hash = sourceHash(node);
    try {
      return await store.save(
        nodeId: node.id,
        nodeTitle: node.title,
        transform: parsed,
        provider: cfg.provider,
        model: cfg.model,
        promptVersion: promptVersion,
        sourceHash: hash,
      );
    } catch (_) {
      // AI 已经成功：不丢结果，交给界面提示“未保存”，让用户先复制留存。
      return KnowledgeTransformEntry(
        nodeId: node.id,
        nodeTitle: node.title,
        transform: parsed,
        provider: cfg.provider,
        model: cfg.model,
        promptVersion: promptVersion,
        sourceHash: hash,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    }
  }
}

/// 打开时先看本地历史：有记录就直接显示最新一条（不花 AI 调用）；
/// 一条都没有才自动转换。之后“重新转换”只会新增记录，不覆盖旧的。
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
  late final EvidenceGrowthKnowledgeTransform _service;
  KnowledgeTransformEntry? current;
  List<KnowledgeTransformEntry> history = const [];
  String? error;
  bool loadingHistory = true;
  bool busy = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _service = EvidenceGrowthKnowledgeTransform(dao: widget.dao);
    unawaited(_init());
  }

  @override
  void dispose() {
    _request++;
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final saved = await _service.store.list(widget.node.id);
      if (!mounted) return;
      setState(() {
        history = saved;
        current = saved.isEmpty ? null : saved.first;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => error = '读取本地历史失败，仍可点“重试”重新转换。');
    }
    if (!mounted) return;
    setState(() => loadingHistory = false);
    if (current == null && error == null) await _convert();
  }

  Future<void> _convert() async {
    final ticket = ++_request;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final entry = await _service.convertAndSave(widget.node);
      if (!mounted || ticket != _request) return;
      setState(() {
        current = entry;
        if (entry.saved) history = [entry, ...history];
        if (!entry.saved) {
          error = '已生成，但保存到本地失败；请先点“复制全文”留存。';
        }
      });
    } catch (e) {
      if (!mounted || ticket != _request) return;
      // 失败时保留正在显示的内容，历史一条不动。
      setState(() => error = e is KnowledgeTransformException
          ? e.message
          : '生成失败，请稍后重试。');
    } finally {
      if (mounted && ticket == _request) setState(() => busy = false);
    }
  }

  Future<void> _openHistory() async {
    final picked = await EvidenceGrowthKnowledgeTransformHistorySheet.show(
        context,
        entries: history,
        currentId: current?.id);
    if (picked == null || !mounted) return;
    setState(() {
      current = picked;
      error = null;
    });
  }

  Future<void> _copy(KnowledgeTransformEntry entry) async {
    await Clipboard.setData(ClipboardData(
        text: entry.transform.toPlainText(widget.node.title)));
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

  /// 记录信息：时间、模型、是否最新、原卡片是否已更新。
  String _meta(KnowledgeTransformEntry entry) {
    final parts = <String>[
      entry.saved ? '已保存 ${entry.timeLabel}' : '未保存 ${entry.timeLabel}',
      if (entry.model.isNotEmpty) entry.model,
      if (history.length > 1) '共 ${history.length} 条历史',
    ];
    if (entry.saved && history.isNotEmpty && entry.id != history.first.id) {
      parts.add('正在查看较早的记录');
    }
    return parts.join(' · ');
  }

  bool _sourceChanged(KnowledgeTransformEntry entry) =>
      entry.sourceHash.isNotEmpty &&
      entry.sourceHash != EvidenceGrowthKnowledgeTransform.sourceHash(widget.node);

  @override
  Widget build(BuildContext context) {
    final entry = current;
    final theme = Theme.of(context);
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(widget.node.title,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text('知识转换 · 6 步', style: theme.textTheme.labelMedium),
      if (entry != null) ...[
        Text(_meta(entry), style: theme.textTheme.bodySmall),
        EvidenceGrowthReadAloud(
            key: ValueKey(entry.id ?? entry.createdAtMs),
            text: entry.transform.toPlainText(widget.node.title)),
      ],
      if (busy && entry != null)
        const Padding(
            padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      if (loadingHistory)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Column(children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('正在读取本地记录…'),
            ])),
      if (!loadingHistory && busy && entry == null)
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
            child: Text(error!, style: TextStyle(color: theme.colorScheme.error))),
      if (entry != null && _sourceChanged(entry))
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('原卡片内容在这条记录之后有更新，可点“重新转换”生成基于新内容的一条（旧记录会保留）。',
                style: theme.textTheme.bodySmall)),
      if (entry != null) ..._body(entry.transform),
      const SizedBox(height: 20),
      if (entry != null)
        Text('由 AI 依据「大标题 + 原案例/研究依据」生成。例子、类比和实验都是假设性示例，不是原文，也不是你的经历；请对照原卡核对。'
            '“重新转换”会新增一条历史记录，不会覆盖已成功保存的内容。',
            style: theme.textTheme.bodySmall),
      const SizedBox(height: 12),
      if (!loadingHistory)
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(
              onPressed: busy ? null : _convert,
              icon: const Icon(Icons.refresh),
              label: Text(entry == null ? '重试' : '重新转换')),
          if (history.isNotEmpty)
            OutlinedButton.icon(
                onPressed: busy ? null : _openHistory,
                icon: const Icon(Icons.history),
                label: Text('历史记录（${history.length}）')),
          if (entry != null)
            OutlinedButton.icon(
                onPressed: () => _copy(entry),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('复制全文')),
        ]),
    ]);
  }
}
