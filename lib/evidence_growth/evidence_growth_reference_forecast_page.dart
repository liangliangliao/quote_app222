import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'evidence_growth_dao.dart';
import 'evidence_growth_forecast_science.dart';
import 'evidence_growth_journey_models.dart';
import 'evidence_growth_reference_forecast.dart';
import 'evidence_growth_reference_defaults.dart';
import 'evidence_growth_reference_report.dart';

class EvidenceGrowthReferenceForecastPage extends StatefulWidget {
  const EvidenceGrowthReferenceForecastPage({
    super.key,
    required this.dao,
    required this.jevApiKey,
    this.action = '',
    this.eventContract = const {},
    this.service,
  });
  final EvidenceGrowthDao dao;
  final String jevApiKey;
  final String action;
  final GrowthData eventContract;
  final EvidenceGrowthReferenceForecast? service;
  @override
  State<EvidenceGrowthReferenceForecastPage> createState() =>
      _ReferenceForecastPageState();
}

class _ReferenceForecastPageState
    extends State<EvidenceGrowthReferenceForecastPage> {
  late final EvidenceGrowthReferenceForecast service;
  final action = TextEditingController();
  final criterion = TextEditingController();
  final window = TextEditingController();
  final contextFacts = TextEditingController();
  final population = TextEditingController();
  GrowthData lastDefaults = {};
  final identity = TextEditingController();
  final evidence = TextEditingController();
  String mode = 'WORLD';
  String personType = 'PUBLIC';
  String language = 'zh';
  bool identityConfirmed = false;
  bool busy = false;
  String status = '';
  List<GrowthData> candidates = [];
  GrowthData selectedSource = {};
  GrowthData result = {};
  List<GrowthData> history = [];

  @override
  void initState() {
    super.initState();
    service =
        widget.service ?? EvidenceGrowthReferenceForecast(dao: widget.dao);
    action.text = widget.action;
    criterion.text = '${widget.eventContract['success_criterion'] ?? ''}';
    window.text = '${widget.eventContract['observation_window'] ?? ''}';
    _fillDefaults();
    _reload();
  }

  Map<String, TextEditingController> get defaultControllers => {
        'success_criterion': criterion,
        'observation_window': window,
        'fixed_external_context': contextFacts,
        'population_definition': population,
      };

  void _fillDefaults({GrowthData? draft, bool preserveExisting = false}) {
    final proposed = draft ?? ReferenceForecastDefaults.forAction(action.text);
    if (proposed.isEmpty) return;
    final emptyFields = defaultControllers.entries
        .where((e) => e.value.text.trim().isEmpty)
        .map((e) => e.key)
        .toSet();
    final merged = ReferenceForecastDefaults.merge(
      current: {
        for (final e in defaultControllers.entries) e.key: e.value.text
      },
      previousDefaults: preserveExisting ? {} : lastDefaults,
      proposed: proposed,
    );
    for (final e in defaultControllers.entries) {
      e.value.text = '${merged[e.key] ?? ''}';
    }
    lastDefaults = preserveExisting
        ? {...lastDefaults, for (final key in emptyFields) key: proposed[key]}
        : proposed;
  }

  Future<void> _refineDefaults() async {
    setState(() {
      busy = true;
      status = 'AI正在把行动整理成更具体的默认条件；你手动修改过的内容会保留…';
    });
    try {
      final draft = await service.draftDefaults(action.text);
      if (mounted)
        setState(() {
          _fillDefaults(draft: draft);
          result = {};
          status = '已优化默认内容，请核对；各项均可修改。';
        });
    } catch (_) {
      if (mounted) setState(() => status = 'AI优化暂未完成，已保留可直接使用的默认内容。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _reload() async {
    final rows = await service.history();
    if (mounted) setState(() => history = rows);
  }

  @override
  void dispose() {
    for (final c in [
      action,
      criterion,
      window,
      contextFacts,
      population,
      identity,
      evidence,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      busy = true;
      status = '正在检索公开人物，请从结果中确认身份…';
      candidates = [];
      selectedSource = {};
      identityConfirmed = false;
      result = {};
    });
    try {
      final rows = await service.searchPublicPerson(
        identity.text,
        language: language,
      );
      if (mounted)
        setState(() {
          candidates = rows;
          status = rows.isEmpty
              ? '没有找到匹配人物，可改用英文名或补充已知资料。'
              : '请选择准确的人物条目，不会自动选择同名人物。';
        });
    } catch (e) {
      if (mounted) setState(() => status = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _select(GrowthData candidate) async {
    setState(() {
      busy = true;
      identityConfirmed = false;
      selectedSource = {};
      result = {};
      status = '正在读取选定条目…';
    });
    try {
      final source = await service.readPublicPerson(candidate);
      if (mounted)
        setState(() {
          selectedSource = source;
          identityConfirmed = true;
          status = '已采用你选定的 ${source['title']} 资料，可展开核对。';
        });
    } catch (e) {
      if (mounted) setState(() => status = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  GrowthData get input => {
        'reference_mode': mode,
        'person_type': personType,
        'action': action.text.trim(),
        'event_contract': EvidenceForecastScience.contract({
          'success_criterion': criterion.text,
          'observation_window': window.text,
          'confirmed': true,
        }),
        'fixed_external_context': contextFacts.text.trim(),
        'population_definition': mode == 'WORLD' ? population.text.trim() : '',
        'person_identity': mode == 'PERSON' ? identity.text.trim() : '',
        'identity_confirmed': mode == 'PERSON' && identityConfirmed,
        'reference_evidence': evidence.text.trim(),
      };
  Future<void> _predict() async {
    _fillDefaults(preserveExisting: true);
    setState(() {
      busy = true;
      result = {};
      status = '正在准备资料与可编辑的默认条件…';
    });
    try {
      final output = await service.predict(
        input: input,
        jevApiKey: widget.jevApiKey,
        onProgress: (message) {
          if (mounted) setState(() => status = message);
        },
        retrievedSources: mode == 'PERSON' && selectedSource.isNotEmpty
            ? [selectedSource]
            : [],
      );
      if (mounted)
        setState(() {
          result = output;
          status = output['estimate_available'] == true
              ? '粗估报告已生成。可修改条件、补充资料后重新判断。'
              : '${output['unavailable_reason']}';
        });
      await _reload();
    } catch (e) {
      if (mounted)
        setState(() => status = '未完成：${'$e'.replaceFirst('Bad state: ', '')}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int lines = 2,
    int max = 3000,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          controller: controller,
          enabled: !busy,
          minLines: lines,
          maxLines: lines + 2,
          maxLength: max,
          onChanged: (_) => setState(() {
            result = {};
            if (controller == action) _fillDefaults();
          }),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Future<void> _retryPrediction() async {
    if (busy || result.isEmpty) return;
    setState(() { busy = true; status = '正在接续原参考报告…'; });
    try {
      final output = await service.resumePrediction('${result['id']}',
        jevApiKey: widget.jevApiKey,
        onProgress: (message) { if (mounted) setState(() => status = message); });
      if (mounted) setState(() {
        result = output;
        status = output['prediction_complete'] == true ? '参考预测已完成。' : '${output['unavailable_reason']}';
      });
      await _reload();
    } catch (error) {
      if (mounted) setState(() => status = '$error'.replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('同情境下，其他人会怎样？')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
                '输入行动并选择参照对象，即可粗估。标准、期限和情境会自动补齐，均可修改；公开人物资料会在生成时自动联网检索。'),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'WORLD', label: Text('全世界人群')),
                ButtonSegment(value: 'PERSON', label: Text('指定人物')),
              ],
              selected: {mode},
              onSelectionChanged: busy
                  ? null
                  : (s) => setState(() {
                        mode = s.first;
                        result = {};
                      }),
            ),
            _field(action, '要执行的行动', max: 2000),
            const Text('下列默认内容用于明确这次比较。修改行动时，只更新尚未被你手动改动的默认项。'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed:
                    busy || action.text.trim().isEmpty ? null : _refineDefaults,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('AI细化默认内容（保留手动修改）'),
              ),
            ),
            _field(criterion, '可观察的成功标准', lines: 1, max: 600),
            _field(window, '相同的观察窗口／期限', lines: 1, max: 300),
            _field(
              contextFacts,
              '必须保持相同的外部情境',
              hint: '时间、地点、费用、可用资源、权限、任务难度、他人配合等；不要把你的情绪当成对方的事实。',
              max: 4000,
            ),
            if (mode == 'WORLD') ...[
              _field(population, '比较范围与资格条件', max: 2000),
              const Text('全世界所有人差异极大。没有代表性样本时，只能给出明确假设下的粗估，不能声称全球统计概率。'),
            ] else ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: personType,
                decoration: const InputDecoration(labelText: '人物类型'),
                items: const [
                  DropdownMenuItem(value: 'PUBLIC', child: Text('公开人物／历史人物')),
                  DropdownMenuItem(value: 'KNOWN', child: Text('自己认识的人')),
                  DropdownMenuItem(value: 'FICTIONAL', child: Text('虚构人物／角色')),
                ],
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                          personType = v!;
                          selectedSource = {};
                          candidates = [];
                          identityConfirmed = false;
                          result = {};
                        }),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: identity,
                  enabled: !busy,
                  maxLength: 200,
                  onChanged: (_) => setState(() {
                    selectedSource = {};
                    candidates = [];
                    identityConfirmed = false;
                    result = {};
                  }),
                  decoration: const InputDecoration(
                    labelText: '姓名＋身份／时代／作品，避免同名混淆',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              if (personType == 'PUBLIC') ...[
                const Text('只填姓名也可以生成。将自动查找相关经历、兴趣与态度；有同名歧义时可在这里手动检索并选择。'),
                Wrap(
                  spacing: 8,
                  children: [
                    DropdownButton<String>(
                      value: language,
                      items: const [
                        DropdownMenuItem(value: 'zh', child: Text('中文资料')),
                        DropdownMenuItem(value: 'en', child: Text('英文资料')),
                      ],
                      onChanged:
                          busy ? null : (v) => setState(() => language = v!),
                    ),
                    OutlinedButton(
                      onPressed: busy ? null : _search,
                      child: const Text('手动选定资料（可选）'),
                    ),
                  ],
                ),
                for (final row in candidates)
                  ListTile(
                    title: Text('${row['title']}'),
                    subtitle: Text('${row['snippet']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: busy ? null : () => _select(row),
                  ),
                if (selectedSource.isNotEmpty)
                  ExpansionTile(
                    title: Text('已选：${selectedSource['title']}'),
                    subtitle: const Text('查看原始资料并核对身份'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText('${selectedSource['content']}'),
                      ),
                      TextButton(
                        onPressed: () => launchUrl(
                          Uri.parse('${selectedSource['url']}'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('打开原始页面'),
                      ),
                    ],
                  ),
              ],
            ],
            _field(
              evidence,
              mode == 'PERSON' ? '相关著作、观点、经历或行为资料（可选）' : '已有群体资料／统计及来源（可选）',
              hint: '公开人物会自动检索相关资料。可补充作品片段或实际经历，并注明出处。',
              max: 8000,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('点击生成即按当前可见条件估计；默认内容是假设，不代表已经核实。'),
            ),
            FilledButton(
              onPressed: busy ? null : _predict,
              child: const Text('联网分析＋JEV生成粗估报告'),
            ),
            if (status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(status),
              ),
            if (busy) const LinearProgressIndicator(),
            if (result.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '粗略可能性：${ReferenceForecastReport.percent(result['estimate'])}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (result['prediction_complete'] == false)
                        TextButton.icon(onPressed: busy ? null : _retryPrediction,
                          icon: const Icon(Icons.refresh), label: const Text('继续完成参考预测')),
                      SelectableText(
                        ReferenceForecastReport.markdown(result, includeSources: false),
                        style: const TextStyle(height: 1.5),
                      ),
                      if (growthRows(result['sources']).isNotEmpty)
                        ExpansionTile(title: const Text('查看著作与资料出处'), children: [
                          Padding(padding: const EdgeInsets.all(12),
                            child: SelectableText(ReferenceForecastReport.sourcesMarkdown(result))),
                        ]),
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(
                                text: ReferenceForecastReport.markdown(result)),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('复制参考报告'),
                      ),
                    ],
                  ),
                ),
              ),
            ExpansionTile(
              title: Text('参考历史（${history.length}）'),
              children: [
                for (final row in history)
                  ListTile(
                    title:
                        Text('${growthMap(row['input_snapshot'])['action']}'),
                    subtitle: Text(
                      '${growthMap(row['input_snapshot'])['person_identity'] ?? ''} ${ReferenceForecastReport.percent(row['estimate'])}',
                    ),
                    onTap: busy
                        ? null
                        : () => setState(() {
                              result = row;
                              status = '正在查看历史快照，输入表单保持当前内容。';
                            }),
                  ),
                if (history.isNotEmpty)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('清空参考历史？'),
                                content: const Text('将删除本机保存的人物资料与参考报告。'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('清空'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await service.clearHistory();
                              if (mounted) setState(() => result = {});
                              await _reload();
                            }
                          },
                    child: const Text('清空参考资料与历史'),
                  ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      );
}
