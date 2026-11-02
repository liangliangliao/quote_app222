import 'package:flutter/material.dart';
import 'cognitive_models.dart';
import 'cognitive_preferences.dart';
import 'cognitive_sheet.dart';
import 'cognitive_recap.dart';
import 'cognitive_mode.dart';

class JudgmentExercise {
  final String title, subtitle, situation, changedSituation;
  final List<String> choices, feedback;
  final int preferred, changedPreferred;
  final IconData icon;
  const JudgmentExercise(
      this.title,
      this.subtitle,
      this.situation,
      this.changedSituation,
      this.choices,
      this.feedback,
      this.preferred,
      this.changedPreferred,
      this.icon);
}

const judgmentExercises = [
  JudgmentExercise(
      '识别共同点',
      '发现相似中的边界',
      '甲每天短跑，乙每天读书。他们都按计划反复练习。现在要理解“坚持”。',
      '如果目标改成改善心肺功能，能否把两种练习视为相同？',
      ['两者都有持续投入，但具体活动和效果不同', '两者对心肺的效果相同', '活动不同，所以毫无共同点'],
      ['共同规定是持续投入；这不推出效果相同。', '需要运动强度等证据，共同的习惯不能证明共同效果。', '具体差异与抽象共同点可以同时存在。'],
      0,
      0,
      Icons.filter_center_focus),
  JudgmentExercise(
      '寻找差异',
      '识别影响结论的条件',
      '两条路线都能到达终点。甲路用时短、坡度陡；乙路平坦、耗时长。此刻目标是尽快抵达，且体力充足。',
      '目标改为让膝伤恢复期的同行者安全抵达，哪项差异变得决定性？',
      ['用时短，暂选甲路', '坡度与身体条件，暂选乙路', '都能到终点，所以完全等同'],
      ['时间目标下有理由优先考虑；仍须确认路况与体力。', '身体条件改变时，坡度与安全会改变选择。', '共同终点不能抹去时间与风险的区别。'],
      0,
      1,
      Icons.compare_arrows),
  JudgmentExercise(
      '避免概念混淆',
      '相邻、相关与因果有别',
      '小林喝了茶之后完成报告。只有这一条记录。可以说什么？',
      '补充：那天也延长了工作时间，且没有观察不喝茶时的情况。',
      ['完成发生在喝茶之后；原因尚不能确定', '喝茶必然提高效率', '茶与效率必定无关'],
      ['先后只是时间关系；还需比较条件并排除其他解释。', '先后与单次共现不足以证明因果。', '缺少因果证据，也不等于证明完全无关。'],
      0,
      0,
      Icons.hub_outlined),
  JudgmentExercise(
      '情境判断',
      '根据目的调整适用范围',
      '团队每天试验一种方案。目前试验成本低、结果可回退，要找到有效方案。',
      '情境改为不可逆且后果重大的操作，证据仍不足。',
      ['先做可回退的小试验并记录结果', '暂停重大操作，补充关键证据', '只要坚持，任何方案都会成功'],
      ['在成本低且可回退时，小试验可提供新材料。', '不可逆后果下，证据与风险会改变行动判断。', '坚持是行为特征，不能保证任意条件下的结果。'],
      0,
      1,
      Icons.fact_check_outlined),
];

class CognitiveTrainingPanel extends StatelessWidget {
  const CognitiveTrainingPanel({super.key});
  @override
  Widget build(BuildContext context) {
    CognitivePreferenceStore.instance.load();
    return ValueListenableBuilder<CognitivePreferences>(
        valueListenable: CognitivePreferenceStore.instance,
        builder:
            (context, prefs, _) =>
                !CognitivePreferenceStore.enabledInBuild || !prefs.enabled
                    ? const SizedBox.shrink()
                    : Card(
                        color: const Color(0xfff5f1e7),
                        child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (prefs.prompts) ...[
                                    const Text('在具体情境中练习判断',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 10),
                                    LayoutBuilder(
                                        builder: (context, box) => Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: judgmentExercises
                                                .map((e) => SizedBox(
                                                    width: box.maxWidth > 300
                                                        ? (box.maxWidth - 8) / 2
                                                        : box.maxWidth,
                                                    child: Card(
                                                        margin: EdgeInsets.zero,
                                                        child: InkWell(
                                                            onTap: () => Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                    builder: (_) =>
                                                                        JudgmentExercisePage(
                                                                            exercise:
                                                                                e))),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            child: Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        14),
                                                                child: Column(
                                                                    children: [
                                                                      Icon(e.icon,
                                                                          color:
                                                                              const Color(0xff517469)),
                                                                      const SizedBox(
                                                                          height:
                                                                              8),
                                                                      Text(e.title,
                                                                          style:
                                                                              const TextStyle(fontWeight: FontWeight.w600)),
                                                                      Text(e.subtitle,
                                                                          textAlign: TextAlign
                                                                              .center,
                                                                          style:
                                                                              const TextStyle(fontSize: 12)),
                                                                    ]))))))
                                                .toList())),
                                  ],
                                  TextButton.icon(
                                      icon: const Icon(Icons.history),
                                      label: const Text('选取记录，回顾认识的变化'),
                                      onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const CognitiveRecapPage()))),
                                ]))));
  }
}

class JudgmentExercisePage extends StatefulWidget {
  final JudgmentExercise exercise;
  const JudgmentExercisePage({super.key, required this.exercise});
  @override
  State<JudgmentExercisePage> createState() => _JudgmentExercisePageState();
}

class _JudgmentExercisePageState extends State<JudgmentExercisePage> {
  bool _changed = false;
  int? _choice;
  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    return CognitiveModePage(
        title: e.title,
        child: Scaffold(
            backgroundColor: const Color(0xfffaf6ee),
            appBar: AppBar(title: Text(e.title)),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              const Text('模拟情境 · 用来练习，不是对个人能力的评分'),
              const SizedBox(height: 18),
              Text(e.situation,
                  style: const TextStyle(fontSize: 19, height: 1.7)),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('改变条件，再作判断'),
                  value: _changed,
                  onChanged: (v) => setState(() {
                        _changed = v;
                        _choice = null;
                      })),
              if (_changed)
                Card(
                    color: const Color(0xffe2eee8),
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(e.changedSituation))),
              for (final choice in e.choices.indexed)
                Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: OutlinedButton(
                        onPressed: () => setState(() => _choice = choice.$1),
                        child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(choice.$2)))),
              if (_choice != null) ...[
                const Divider(height: 32),
                Text(
                    _choice == (_changed ? e.changedPreferred : e.preferred)
                        ? '这个判断与当前条件相符，仍可随新材料修订。'
                        : '可以再检查：这一项是否对应当前的目标和条件？',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text(e.feedback[_choice!], style: const TextStyle(height: 1.7)),
                const SizedBox(height: 12),
                const Text('还缺少什么证据？出现怎样的新材料，你会改变判断？'),
              ],
            ])));
  }
}

/// Context menu passes only the exact selected range; no neighboring record.
class CognitiveSelectableText extends StatelessWidget {
  final String text, module, recordId, title;
  final CognitiveTask task;
  const CognitiveSelectableText(
      {super.key,
      required this.text,
      required this.module,
      required this.recordId,
      required this.title,
      this.task = CognitiveTask.calibration});
  @override
  Widget build(BuildContext context) => CognitiveMode(
      fallback: Text(text, style: const TextStyle(fontSize: 15)),
      child: SelectableText(text, contextMenuBuilder: (context, state) {
        final selection = state.textEditingValue.selection;
        final prefs = CognitivePreferenceStore.instance.value;
        return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: state.contextMenuAnchors,
            buttonItems: [
              if (CognitivePreferenceStore.enabledInBuild &&
                  prefs.enabled &&
                  selection.isValid &&
                  !selection.isCollapsed)
                ContextMenuButtonItem(
                    label: '检验适用范围',
                    onPressed: () {
                      state.hideToolbar();
                      showCognitiveAnalysis(context,
                          task: task,
                          selection: CognitiveSelection.fromText(
                              module: module,
                              recordId: recordId,
                              title: title,
                              fullText: text,
                              start: selection.start,
                              end: selection.end),
                          currentText: () => text);
                    }),
              ...state.contextMenuButtonItems,
            ]);
      }));
}
