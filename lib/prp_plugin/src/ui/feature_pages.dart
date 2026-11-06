import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../prp_plugin.dart';
import '../runtime.dart';
import '../enhancement_models.dart';
import 'presentation.dart';

Future<void> showPrpSupport(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
            title: const Text('先照顾此刻的安全'),
            content: const Text('刚才的输入不会保存。可以联系一个信任的人陪你一会儿。\n\n'
                '中国大陆心理援助：12356\n如有即时危险：120 / 110\n其它地区请联系当地紧急服务。'),
            actions: [
              TextButton.icon(
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: '12356')),
                  icon: const Icon(Icons.phone_outlined),
                  label: const Text('拨打 12356'))
            ]));

/// Removes its own route on disable, preserving a support dialog above it.
class PrpActivePage extends StatefulWidget {
  const PrpActivePage({super.key, required this.active, required this.child});
  final bool Function() active;
  final Widget child;
  @override
  State<PrpActivePage> createState() => _PrpActivePageState();
}

class _PrpActivePageState extends State<PrpActivePage> {
  @override
  void initState() {
    super.initState();
    PrpPlugin.changes.addListener(_changed);
  }

  void _changed() {
    if (widget.active()) return;
    if (mounted) setState(() {});
    final route = ModalRoute.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && route != null && route.isActive && !route.isFirst)
        Navigator.of(context).removeRoute(route);
    });
  }

  @override
  void dispose() {
    PrpPlugin.changes.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.active() ? widget.child : const SizedBox.shrink();
}

class PrpForecastPage extends StatefulWidget {
  const PrpForecastPage({super.key, required this.runtime});
  final PrpRuntime runtime;
  @override
  State<PrpForecastPage> createState() => _PrpForecastPageState();
}

class _PrpForecastPageState extends State<PrpForecastPage> {
  List<PrpForecast> _items = [];
  String _error = '';
  int _generation = 0;
  bool _saving = false;
  PrpRuntime get r => widget.runtime;
  bool get _canEdit => r.enabled && r.preferences.forecasts;
  @override
  void initState() {
    super.initState();
    PrpPlugin.changes.addListener(_reload);
    _reload();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    try {
      final items = await r.forecasts();
      if (mounted && generation == _generation)
        setState(() {
          _items = items;
          _error = '';
        });
    } catch (_) {
      if (mounted) setState(() => _error = '暂时读不到对照记录，请重试。');
    }
  }

  @override
  void dispose() {
    PrpPlugin.changes.removeListener(_reload);
    super.dispose();
  }

  Future<void> _edit([PrpForecast? original]) async {
    if (!_canEdit || _saving) return;
    var label = '';
    var days = '';
    var intensity = 5;
    var message = '';
    var unsafe = false;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => StatefulBuilder(
            builder: (ctx, update) => AlertDialog(
                    title: Text(original == null ? '事前预测' : '补记实际感受'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      if (original == null)
                        TextFormField(
                            key: const ValueKey('prp_forecast_label'),
                            initialValue: label,
                            maxLength: 200,
                            decoration:
                                const InputDecoration(labelText: '有点怕的具体事情'),
                            onChanged: (text) {
                              label = text;
                              final guard = r.host.guardText(text);
                              if (!unsafe && (guard.crisis || guard.truce)) {
                                unsafe = true;
                                Navigator.of(dialog).pop(false);
                                unawaited(showPrpSupport(context));
                                unawaited(
                                    r.crisisExit(null, crisis: guard.crisis));
                              }
                            })
                      else
                        Text(original.label),
                      Text(
                          '${original == null ? '预测' : '实际'}强度：$intensity / 10'),
                      Slider(
                          key: const ValueKey('prp_forecast_intensity'),
                          value: intensity.toDouble(),
                          min: 0,
                          max: 10,
                          divisions: 10,
                          onChanged: (v) =>
                              update(() => intensity = v.round())),
                      TextFormField(
                          key: const ValueKey('prp_forecast_days'),
                          initialValue: days,
                          onChanged: (v) => days = v,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                              labelText: original == null ? '预计持续几天' : '实际持续几天',
                              hintText: '可填 0 或小数，最多 365 天')),
                      if (message.isNotEmpty)
                        Text(message,
                            style: const TextStyle(color: prpVermilion)),
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      FilledButton(
                          key: const ValueKey('prp_forecast_save'),
                          onPressed: () {
                            final number = double.tryParse(days);
                            if (number == null ||
                                !number.isFinite ||
                                number < 0 ||
                                number > 365 ||
                                (original == null &&
                                    (label.trim().length < 3 ||
                                        !r.host.guardText(label).allowed))) {
                              update(
                                  () => message = '写清具体事情，并填写 0–365 天之间的数字。');
                              return;
                            }
                            Navigator.pop(ctx, true);
                          },
                          child: const Text('保存'))
                    ])));
    if (!mounted || confirmed != true || unsafe || !_canEdit) return;
    setState(() => _saving = true);
    final number = double.parse(days);
    final ok = original == null
        ? await r.predict(label: label, intensity: intensity, days: number) !=
            null
        : await r.closeForecast(original.id,
            intensity: intensity, days: number);
    if (mounted)
      setState(() {
        _saving = false;
        _error = ok ? '' : '未保存，请检查开关或记录状态。';
      });
    await _reload();
  }

  String ratio(double? value) => value == null ? '—' : value.toStringAsFixed(2);
  @override
  Widget build(BuildContext context) => Theme(
      data: prpPaperTheme(context),
      child: Scaffold(
          appBar: AppBar(title: const Text('痛感预测与实际对照')),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            const Text('事前记下猜测，事后再记实际。它是一份个人观察，不替代诊断，也不证明以后一定如此。'),
            const SizedBox(height: 12),
            if (!_canEdit) const Text('记录已保留。开启插件和“痛感对照”后可新增或补记。'),
            FilledButton.icon(
                key: const ValueKey('prp_forecast_new'),
                onPressed: _canEdit && !_saving ? () => _edit() : null,
                icon: const Icon(Icons.add),
                label: const Text('记录一次预测')),
            if (_error.isNotEmpty) Text(_error),
            if (_items.isEmpty)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('还没有记录。选一件具体的小事，先记下自己的预测。')),
            _summary(),
            for (final item in _items)
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(
                                '预测：${item.predictedIntensity}/10 · ${item.predictedDays} 天'),
                            if (item.closed) ...[
                              Text(
                                  '实际：${item.actualIntensity}/10 · ${item.actualDays} 天'),
                              Text(
                                  '预测 / 实际：强度 ${ratio(item.intensityRatio)} · 持续时间 ${ratio(item.durationRatio)}'),
                              if (item.actualIntensity == 0 ||
                                  item.actualDays == 0)
                                const Text('实际为 0 的维度不计算倍数。'),
                            ] else
                              TextButton(
                                  onPressed: _canEdit && !_saving
                                      ? () => _edit(item)
                                      : null,
                                  child: const Text('事情过去了，补记实际')),
                          ]))),
          ])));
  Widget _summary() {
    final closed = _items.where((i) => i.closed).toList();
    final intensity =
        closed.map((i) => i.intensityRatio).whereType<double>().toList();
    final duration =
        closed.map((i) => i.durationRatio).whereType<double>().toList();
    double? mean(List<double> values) =>
        values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (closed.isNotEmpty) ...[
            const Text('最近 10 次强度对照：靛色为预测，青色为实际。'),
            SizedBox(
                height: 140,
                width: double.infinity,
                child: Semantics(
                    label: '每次预测与实际强度，逐条数值在下方',
                    child: CustomPaint(
                        painter: _ForecastPlot(
                            closed.take(10).toList().reversed.toList())))),
          ],
          Text(
              '已完成 ${closed.length} 次对照\n个人预测 / 实际均值：强度 ${ratio(mean(intensity))} · 时间 ${ratio(mean(duration))}\n'
              '${closed.length < 3 ? '记录还少，先不下结论。' : '大于 1 表示这些记录中预测偏高，小于 1 表示偏低。'}')
        ]));
  }
}

class _ForecastPlot extends CustomPainter {
  const _ForecastPlot(this.items);
  final List<PrpForecast> items;
  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()..color = Colors.grey.shade300;
    canvas.drawLine(Offset(12, 8), Offset(12, size.height - 12), axis);
    canvas.drawLine(Offset(12, size.height - 12),
        Offset(size.width - 12, size.height - 12), axis);
    for (final actual in [false, true]) {
      final paint = Paint()
        ..color = actual ? prpTeal : prpIndigo
        ..strokeWidth = 2;
      Offset? previous;
      for (var i = 0; i < items.length; i++) {
        final value =
            actual ? items[i].actualIntensity! : items[i].predictedIntensity;
        final point = Offset(
            items.length == 1
                ? size.width / 2
                : 16 + i * (size.width - 32) / (items.length - 1),
            size.height - 16 - value * (size.height - 32) / 10);
        if (previous != null) canvas.drawLine(previous, point, paint);
        canvas.drawCircle(point, 4, paint);
        previous = point;
      }
    }
  }

  @override
  bool shouldRepaint(_ForecastPlot old) => old.items != items;
}

class PrpObservationPage extends StatefulWidget {
  const PrpObservationPage({super.key, required this.runtime});
  final PrpRuntime runtime;
  @override
  State<PrpObservationPage> createState() => _PrpObservationPageState();
}

class _PrpObservationPageState extends State<PrpObservationPage> {
  late Future<PrpObservation> _data;
  @override
  void initState() {
    super.initState();
    PrpPlugin.changes.addListener(_reload);
    _data = widget.runtime.observations();
  }

  void _reload() {
    if (mounted) setState(() => _data = widget.runtime.observations());
  }

  @override
  void dispose() {
    PrpPlugin.changes.removeListener(_reload);
    super.dispose();
  }

  String rate(double? n) =>
      n == null ? '暂无数据' : '${(n * 100).toStringAsFixed(0)}%';
  @override
  Widget build(BuildContext context) => Theme(
      data: prpPaperTheme(context),
      child: Scaffold(
          appBar: AppBar(title: const Text('我的本地观察')),
          body: FutureBuilder<PrpObservation>(
              future: _data,
              builder: (ctx, s) {
                if (s.hasError) return const Center(child: Text('暂时无法读取观察记录。'));
                if (!s.hasData)
                  return const Center(child: CircularProgressIndicator());
                final d = s.data!;
                return ListView(padding: const EdgeInsets.all(20), children: [
                  const Text('最近 30 天 · 只在本机计算，不上传。情绪变化不作为疗效结论；没有反馈的回访保持未验证。'),
                  const SizedBox(height: 20),
                  for (final row in <(String, String)>[
                    ('开始的会话', '${d.sessions} 次'),
                    ('完成到最后一步', rate(d.completionRate)),
                    ('盖印率', rate(d.sealRate)),
                    ('跳过率', rate(d.skipRate)),
                    ('实际暂停累计', '${d.pauseSeconds} 秒'),
                    ('回访曝光', '${d.recalls} 次'),
                    ('回访点击/反馈', rate(d.clickRate)),
                    ('选择试一试', rate(d.adoptionRate)),
                    ('试过并报告有帮助', rate(d.verificationRate)),
                    ('明确报告再次未完成', '${d.repeated} 次'),
                    (
                      '同条教训再次未完成的平均间隔',
                      d.meanRepeatDays == null
                          ? '暂无足够记录'
                          : '${d.meanRepeatDays!.toStringAsFixed(1)} 天'
                    ),
                    (
                      '情绪后减情绪前的均值',
                      d.meanEmotionChange == null
                          ? '暂无配对评分'
                          : d.meanEmotionChange!.toStringAsFixed(1)
                    ),
                  ])
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(row.$1),
                        trailing: Text(row.$2)),
                  const Text(
                      '完成率与盖印率以实际开始的会话为分母，导入草稿不计入。验证率以“试过”的明确结果为分母，忽略和未反馈不算失败。'),
                  const SizedBox(height: 16),
                  const Text('会话停在哪一步'),
                  for (final step in <(String, String)>[
                    ('pause', '缓一缓'),
                    ('ledger', '对账'),
                    ('columns', '有效/无效'),
                    ('signal', '预警与动作'),
                    ('seal', '确认教训'),
                    ('zoom', '拉远'),
                    ('done', '已结束')
                  ])
                    Text('${step.$2}：${d.stepCounts[step.$1] ?? 0} 次'),
                  const SizedBox(height: 16),
                  const Text('同条教训的复犯间隔变化（含改写版本）'),
                  if (d.repeatGaps.isEmpty) const Text('还没有两次明确复犯的记录，暂不推断间隔。'),
                  for (final entry in d.repeatGaps.entries)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                            '教训 #${entry.key}：${entry.value.map((v) => '${v.toStringAsFixed(1)} 天').join(' → ')}'
                            '${entry.value.length < 2 ? ' · 还需更多记录观察变化' : ' · 最近变化 ${(entry.value.last - entry.value[entry.value.length - 2]) >= 0 ? '+' : ''}${(entry.value.last - entry.value[entry.value.length - 2]).toStringAsFixed(1)} 天'}')),
                ]);
              })));
}

class PrpAdoptionButton extends StatefulWidget {
  const PrpAdoptionButton(
      {super.key, required this.runtime, required this.recall});
  final PrpRuntime runtime;
  final PrpRecall recall;
  @override
  State<PrpAdoptionButton> createState() => _PrpAdoptionButtonState();
}

class _PrpAdoptionButtonState extends State<PrpAdoptionButton> {
  bool _adopted = false, _busy = false;
  @override
  void initState() {
    super.initState();
    widget.runtime.recallAdopted(widget.recall.id).then((v) {
      if (mounted) setState(() => _adopted = v);
    });
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
      onPressed: _adopted || _busy
          ? null
          : () async {
              setState(() => _busy = true);
              final ok = await widget.runtime.adoptRecall(widget.recall);
              if (mounted)
                setState(() {
                  _adopted = ok;
                  _busy = false;
                });
            },
      icon: Icon(_adopted ? Icons.check : Icons.play_arrow),
      label: Text(_adopted ? '已选择试一试，等结果再记账' : '这次试试'));
}
