import 'package:flutter/material.dart';

import 'zhixing_productization.dart';

class ZhixingUserGuidePage extends StatelessWidget {
  const ZhixingUserGuidePage({super.key});

  static const Color _green = Color(0xFF2F7550);
  static const Color _ink = Color(0xFF17362A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('知行树使用说明')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        children: <Widget>[
          Card(
            color: const Color(0xFFE7F2EA),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '你只负责说出真实目标并反馈结果',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '系统负责识别当下卡点、匹配思想、给出唯一主动作、记录现实证据、自动复盘并安排下一步。你不必先读完理论，也不必填写长问卷。',
                    style: TextStyle(height: 1.55),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle('主业务流程图'),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: _FlowDiagram(),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('可直接试跑的案例'),
          const SizedBox(height: 8),
          ...zxStarterCases.map(
            (item) => Card(
              child: ExpansionTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.play_arrow_rounded),
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(item.goal),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: <Widget>[
                  _detail('输入', item.nextStep),
                  _detail('卡点与方式', item.block.label + ' · ' + item.mode.label),
                  _detail('为什么值得做', item.valueReason),
                  _detail('预期产出', item.expectedOutput),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('回到“现在做”，点击同名案例即可自动填入。'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('每个功能是什么、怎么用、为什么'),
          const SizedBox(height: 8),
          ...zxFeatureGuides.map(_featureCard),
          const SizedBox(height: 16),
          _sectionTitle('一次完整验收应该留下什么'),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  _CheckLine('有一个来自真实生活或三路导入的目标'),
                  _CheckLine('系统给出唯一主动作、完成标准和降级动作'),
                  _CheckLine('行动卡显示本轮思想，但理论细节按需展开'),
                  _CheckLine('用户反馈完成/未完成及难度'),
                  _CheckLine('自动报告指出障碍、思想建议与下一步'),
                  _CheckLine('行动、复盘、奖励和思想调整均保存为可追溯记录'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          color: _ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      );

  static Widget _featureCard(ZxFeatureGuide guide) => Card(
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: _green.withValues(alpha: 0.12),
            child: Icon(_iconFor(guide.area), color: _green),
          ),
          title: Text(
            guide.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(guide.summary),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: <Widget>[
            _detail('它是什么', guide.what),
            _detail('填写/操作什么', guide.input),
            _detail('会产出什么', guide.output),
            _detail('为什么这样设计', guide.why),
            _detail('知识与思想依据', guide.theory),
            _detail('具体案例', guide.example),
          ],
        ),
      );

  static Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: label + '：',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      );

  static IconData _iconFor(ZxProductArea area) => switch (area) {
        ZxProductArea.action => Icons.play_circle_outline,
        ZxProductArea.thought => Icons.account_tree_outlined,
        ZxProductArea.growth => Icons.park_outlined,
        ZxProductArea.mentor => Icons.support_agent_outlined,
        ZxProductArea.more => Icons.fact_check_outlined,
      };
}

class _FlowDiagram extends StatelessWidget {
  const _FlowDiagram();

  static const List<(String, String)> _steps = <(String, String)>[
    ('1 · 目标/问题', '用户只说现在想推进或解决什么'),
    ('2 · 现实卡点', '点选不知道、没启动、害怕、低能量或环境阻碍'),
    ('3 · 一个行动', '系统匹配思想并给出主动作、完成线和降级动作'),
    ('4 · 当场执行', '开始记录；只保留当前唯一主动作'),
    ('5 · 现实反馈', '反馈结果、难度和可选关键发现'),
    ('6 · 自动复盘', '生成报告，继续/切换/融合思想并形成下一步'),
    ('7 · 重复内化', '提醒回到现场，经验逐步沉淀为能力和习惯'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var index = 0; index < _steps.length; index++) ...<Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: ZhixingUserGuidePage._green,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  (index + 1).toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _steps[index].$1,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(_steps[index].$2),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (index != _steps.length - 1)
            Container(
              width: 2,
              height: 22,
              margin: const EdgeInsets.only(left: 14, top: 4, bottom: 4),
              color: const Color(0xFFB7D0BE),
            ),
        ],
      ],
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.check_circle, size: 19, color: Color(0xFF2F7550)),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
