import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'evidence_growth_dao.dart';
import 'evidence_growth_forecast_report_page.dart';
import 'evidence_growth_forecast_science.dart';
import 'evidence_growth_journey_models.dart';
import 'evidence_growth_reference_forecast.dart';

class EvidenceGrowthReferenceForecastPage extends StatefulWidget {
  const EvidenceGrowthReferenceForecastPage({
    super.key,
    required this.dao,
    required this.jevApiKey,
    this.action = '',
    this.eventContract = const {},
  });
  final EvidenceGrowthDao dao;
  final String jevApiKey;
  final String action;
  final GrowthData eventContract;
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
  final population = TextEditingController(
    text: '全世界所有人；需说明行为资格与能力限制，不能把不具备资格的人默认为具备。',
  );
  final identity = TextEditingController();
  final evidence = TextEditingController();
  String mode = 'WORLD';
  String personType = 'PUBLIC';
  String language = 'zh';
  bool identityConfirmed = false;
  bool contractConfirmed = false;
  bool busy = false;
  String status = '';
  List<GrowthData> candidates = [];
  GrowthData selectedSource = {};
  GrowthData result = {};
  List<GrowthData> history = [];

  @override
  void initState() {
    super.initState();
    service = EvidenceGrowthReferenceForecast(dao: widget.dao);
    action.text = widget.action;
    criterion.text = '${widget.eventContract['success_criterion'] ?? ''}';
    window.text = '${widget.eventContract['observation_window'] ?? ''}';
    _reload();
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
          status = '已读取 ${source['title']}，请核对资料并确认身份。';
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
          'confirmed': contractConfirmed,
        }),
        'fixed_external_context': contextFacts.text.trim(),
        'population_definition': mode == 'WORLD' ? population.text.trim() : '',
        'person_identity': mode == 'PERSON' ? identity.text.trim() : '',
        'identity_confirmed': mode == 'PERSON' && identityConfirmed,
        'reference_evidence': evidence.text.trim(),
      };
  Future<void> _predict() async {
    setState(() {
      busy = true;
      result = {};
      status = 'LLM正在梳理人物／群体证据，随后交给JEV独立判断…';
    });
    try {
      final output = await service.predict(
        input: input,
        jevApiKey: widget.jevApiKey,
        retrievedSources: mode == 'PERSON' && selectedSource.isNotEmpty
            ? [selectedSource]
            : [],
      );
      if (mounted)
        setState(() {
          result = output;
          status = output['estimate_available'] == true
              ? '参考报告已生成。'
              : '证据不足，已保留分析与缺口，不显示伪精确概率。';
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
            if (controller == criterion ||
                controller == window ||
                controller == contextFacts ||
                controller == action) contractConfirmed = false;
          }),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  String _reportText(GrowthData r) {
    final profile = growthMap(r['profile']);
    final snapshot = growthMap(r['input_snapshot']);
    final range = growthMap(r['assumption_range']);
    final answers = growthMap(growthMap(r['jev'])['answers']);
    return [
      '同情境参考报告 · ${snapshot['reference_mode'] == 'PERSON' ? snapshot['person_identity'] : '全世界人群'}',
      '行动：${snapshot['action']}\n标准：${growthMap(snapshot['event_contract'])['success_criterion']}\n窗口：${growthMap(snapshot['event_contract'])['observation_window']}',
      '固定外部情境：${snapshot['fixed_external_context']}',
      if (snapshot['reference_mode'] == 'WORLD')
        '比较范围：${snapshot['population_definition']}',
      '估计：${r['estimate_available'] == true ? forecastPercent(r['estimate']) : '证据不足，暂不估计'}',
      '${r['note']}\n${r['same_situation_rule']}',
      'AI身份理解：${profile['identity_summary']}',
      'LLM：${r['llm_model']}；JEV：${growthMap(r['jev'])['model'] ?? '未完成'}。',
      'JEV证据判断：${const {
            'adequate_for_rough_estimate': '支持粗略估计',
            'insufficient': '证据不足',
            'contradictory': '证据冲突'
          }[growthMap(answers['evidence_quality'])['choice']] ?? '未完成'}；主要维度：${const {
            'capability': '能力',
            'opportunity': '机会与资源',
            'motivation': '动机与态度',
            'habit': '习惯与相似历史',
            'planning': '计划与自我调节',
            'unknown': '不明确'
          }[growthMap(answers['dominant_dimension'])['choice']] ?? '未判断'}。',
      for (final row in growthRows(profile['claims']))
        '${row['dimension']} · ${row['evidence_status'] == 'SOURCE_LINKED' ? '有资料对应，待核实解释' : '模型假设，不能当事实'}\n${row['claim']}\n${row['relevance']}${row['source_id'] == '' ? '' : '\n依据 ${row['source_id']}：“${row['quote']}”'}',
      '过往行为：${profile['past_behavior_analysis']}',
      '态度与性格假设：${profile['attitude_and_personality_hypotheses']}',
      '理论综合：${profile['theory_explanation']}',
      '外推限制：${profile['transfer_limits']}',
      '需要补充：${growthStrings(profile['unknowns']).join('；')}',
      for (final row in growthRows(r['scenarios']))
        '${row['label']}：${growthStrings(row['assumptions']).join('；')}\n${forecastPercent(row['probability'])}',
      if (range.isNotEmpty)
        '假设情景范围：${forecastPercent(range['low'])}—${forecastPercent(range['high'])}。${r['range_note']}',
      '来源：',
      for (final source in growthRows(r['sources']))
        '${source['id']} · ${source['title']}\n${source['url'] ?? '用户提供，未独立核实'}\n${source['retrieved_at'] ?? ''}',
    ].join('\n\n');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('同情境下，其他人会怎样？')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('这是独立的参考功能。固定外部条件，比较不同主体的可能反应；不会把人物推测混入你的个人执行历史。'),
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
                        contractConfirmed = false;
                      }),
            ),
            _field(action, '要执行的行动', max: 2000),
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
                      child: const Text('检索公开人物资料'),
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
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: identityConfirmed,
                title: const Text('确认这就是我要分析的人物；资料不足的部分保持未知'),
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                          identityConfirmed = v == true;
                          result = {};
                        }),
              ),
            ],
            _field(
              evidence,
              mode == 'PERSON' ? '人物相关资料与过去相似行为（可粘贴出处与原文）' : '已有群体资料／统计及来源（可选）',
              hint: '经历、实际行为、态度表达、习惯、能力，以及事实发生的时间。资料不足也可以提交，报告会指出缺口。',
              max: 8000,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: contractConfirmed,
              title: const Text('确认行为标准、观察窗口和固定外部情境'),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                        contractConfirmed = v == true;
                        result = {};
                      }),
            ),
            FilledButton(
              onPressed: busy ? null : _predict,
              child: const Text('LLM＋JEV生成参考报告'),
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
                        '参考结果：${forecastPercent(result['estimate'])}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        _reportText(result),
                        style: const TextStyle(height: 1.5),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _reportText(result)),
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
                      '${growthMap(row['input_snapshot'])['person_identity'] ?? ''} ${forecastPercent(row['estimate'])}',
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
