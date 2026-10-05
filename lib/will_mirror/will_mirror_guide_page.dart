import 'package:flutter/material.dart';

import 'will_mirror_capability_catalog.dart';
import 'will_mirror_example_repository.dart';
import 'will_mirror_practice_models.dart';
import 'will_mirror_widgets.dart';

class WillMirrorGuidePage extends StatelessWidget {
  const WillMirrorGuidePage({super.key});

  static const Key flowKey = ValueKey<String>('will_mirror_v5_flow');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      appBar: AppBar(
        title: const Text('怎么用 · 每一步为什么'),
        backgroundColor: const Color(0xFFFAFBF9),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        children: <Widget>[
          const WillMirrorSectionCard(
            color: WillMirrorPalette.sage,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '先产出，再理解得更深',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  '你不需要先学会任何哲学术语。只要说出目标或问题，系统会把思想转换成下一步，并在每一步旁边标明依据。',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '关键业务流程',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const _FlowMap(key: flowKey),
          const SizedBox(height: 20),
          const Text(
            '逐功能说明与理论依据',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...WillMirrorCapabilityCatalog.all.map(
            (capability) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CapabilityCard(capability: capability),
            ),
          ),
          const SizedBox(height: 8),
          const WillMirrorGuardrail(),
        ],
      ),
    );
  }
}

class _FlowMap extends StatelessWidget {
  const _FlowMap({super.key});

  static const List<(String, String, String)> steps =
      <(String, String, String)>[
    ('1', '说出目标或问题', '输入一句真实需要，不要求写得完整'),
    ('2', '选择适合今天的方式', '按兴趣、引导风格和 2/5/15 分钟精力生成方案'),
    ('3', 'AI + 知识库生成', '单次授权；显示模型、知识记录或本地接管原因'),
    ('4', '得到三个现实方案', '每个方案都写清动作、完成信号、产出和思想怎样落地'),
    ('5', '只做今天的一小步', '不靠意志硬撑，到点就停'),
    ('6', '把结果变成证据', '做成和没做成都记录，区分欲望与现实限制'),
    ('7', '七天后修正', '输出支持、反证/限制，并保留、缩小、换路或停止'),
  ];

  @override
  Widget build(BuildContext context) {
    return WillMirrorSectionCard(
      child: Column(
        children: <Widget>[
          for (var index = 0; index < steps.length; index++) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: WillMirrorPalette.forest,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    steps[index].$1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        steps[index].$2,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        steps[index].$3,
                        style: const TextStyle(
                          color: WillMirrorPalette.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (index != steps.length - 1)
              Container(
                width: 2,
                height: 16,
                margin: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                color: WillMirrorPalette.line,
              ),
          ],
        ],
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.capability});

  final WillMirrorCapability capability;

  @override
  Widget build(BuildContext context) {
    return WillMirrorSectionCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        title: Text(
          capability.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          capability.problemSolved,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          _LabelBody(label: '这是什么', body: capability.whatItIs),
          _LabelBody(label: '填写什么', body: capability.input),
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('怎么做', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 5),
          for (var index = 0; index < capability.howTo.length; index++)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('${index + 1}. ${capability.howTo[index]}'),
            ),
          _LabelBody(label: '会得到什么', body: capability.output),
          _LabelBody(label: '为什么这样做', body: capability.why),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: capability.theoryIds.map((id) {
                final ref = WillMirrorTheoryCatalog.find(id);
                return WillMirrorBadge(
                  label: ref?.shortLabel ?? id,
                  icon: Icons.menu_book_outlined,
                );
              }).toList(growable: false),
            ),
          ),
          const SizedBox(height: 8),
          for (final id in capability.theoryIds)
            if (WillMirrorTheoryCatalog.find(id) != null)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${WillMirrorTheoryCatalog.find(id)!.shortLabel}：${WillMirrorTheoryCatalog.find(id)!.plainMeaning}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: WillMirrorPalette.muted,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _LabelBody extends StatelessWidget {
  const _LabelBody({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: '$label：',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: body),
            ],
          ),
        ),
      ),
    );
  }
}

class WillMirrorExamplesPage extends StatefulWidget {
  const WillMirrorExamplesPage({
    super.key,
    this.selectable = false,
    this.repository,
  });

  final bool selectable;
  final WillMirrorExampleRepository? repository;

  @override
  State<WillMirrorExamplesPage> createState() => _WillMirrorExamplesPageState();
}

class _WillMirrorExamplesPageState extends State<WillMirrorExamplesPage> {
  late final WillMirrorExampleRepository _repository =
      widget.repository ?? WillMirrorExampleRepository();
  late final Future<List<WillMirrorExampleCase>> _cases = _repository.load();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      appBar: AppBar(
        title: Text(widget.selectable ? '选一个案例作为起点' : '完整测试案例'),
        backgroundColor: const Color(0xFFFAFBF9),
      ),
      body: FutureBuilder<List<WillMirrorExampleCase>>(
        future: _cases,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('案例数据校验失败：${snapshot.error}'));
          }
          final cases = snapshot.data ?? const <WillMirrorExampleCase>[];
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
            itemCount: cases.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    '这些不是宣传文案，而是按完整流程保存的测试数据：输入、个性化选择、行动、做成/没做成、证据、结果和下一轮修订都在。',
                    style: TextStyle(height: 1.5),
                  ),
                );
              }
              final item = cases[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ExampleCard(
                  item: item,
                  selectable: widget.selectable,
                  onSelect: () => Navigator.pop(context, item),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.item,
    required this.selectable,
    required this.onSelect,
  });

  final WillMirrorExampleCase item;
  final bool selectable;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return WillMirrorSectionCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${item.needType.shortLabel} · ${item.profile.energyMinutes} 分钟方案'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          _LabelBody(label: '用户输入', body: item.need),
          _LabelBody(label: '希望的变化', body: item.desiredOutcome),
          _LabelBody(label: '当前障碍', body: item.obstacle),
          _LabelBody(label: '生成行动', body: item.generatedAction),
          _LabelBody(label: '完成信号', body: item.successSignal),
          _LabelBody(label: '为什么这样做', body: item.whyItWorks),
          _LabelBody(label: '生成凭证', body: item.generationReceipt),
          for (final application in item.theoryApplications)
            _LabelBody(
              label: application.concept,
              body: '${application.application}\n为什么：${application.reason}',
            ),
          const SizedBox(height: 10),
          for (final day in item.days)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '第 ${day.day} 天 · ${day.didAct ? '做了' : '没做成'}：${day.evidence}\n调整：${day.adjustment}',
                  style: const TextStyle(height: 1.4),
                ),
              ),
            ),
          _LabelBody(label: '七日结果', body: item.result),
          _LabelBody(label: '下一轮', body: item.nextRevision),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.theoryIds.map((id) {
                return WillMirrorBadge(
                  label: WillMirrorTheoryCatalog.find(id)?.shortLabel ?? id,
                );
              }).toList(growable: false),
            ),
          ),
          if (selectable) ...<Widget>[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onSelect,
                child: const Text('用这个案例的填写方式开始'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
