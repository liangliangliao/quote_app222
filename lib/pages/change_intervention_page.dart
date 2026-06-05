import 'package:flutter/material.dart';

/// Simple intervention suggestions based on the current zone.
///
/// This page is intentionally lightweight and offline.
class ChangeInterventionPage extends StatelessWidget {
  const ChangeInterventionPage({super.key, required this.zone, required this.arousal0To10});

  final String zone;
  final double arousal0To10;

  @override
  Widget build(BuildContext context) {
    final blocks = _blocksForZone(zone);
    return Scaffold(
      appBar: AppBar(title: const Text('干预建议')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('当前：$zone', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('综合唤醒：${arousal0To10.toStringAsFixed(1)}/10', style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  const Text('提示：以下为自助建议，不替代医疗/心理治疗。', style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final b in blocks) ...[
            _card(title: b.title, items: b.items),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _card({required String title, required List<String> items}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final it in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $it', style: const TextStyle(height: 1.4)),
              ),
          ],
        ),
      ),
    );
  }

  List<_Block> _blocksForZone(String zone) {
    if (zone.contains('恐慌')) {
      return const [
        _Block(
          title: '先“降唤醒”',
          items: [
            '做 2 分钟呼吸：吸气 4 秒—呼气 6 秒，缓慢而浅。',
            '放下任务 3 分钟，把注意力放回身体：脚底、手心、肩颈。',
            '如果你刚运动/爬楼，请先休息 5–10 分钟再复测。',
          ],
        ),
        _Block(
          title: '再“收拢范围”',
          items: [
            '把当前问题缩小到“下一步最小动作”（<=5 分钟能完成）。',
            '写下：我现在最担心的是什么？它最坏会怎样？我能做什么？',
            '减少刺激源：亮度、声音、信息流；喝水。',
          ],
        ),
        _Block(
          title: '必要时求助',
          items: [
            '若出现持续强烈不适、惊恐发作、或自伤想法，请尽快联系专业机构或紧急电话。',
          ],
        ),
      ];
    }

    if (zone.contains('舒适')) {
      return const [
        _Block(
          title: '适度“加挑战”',
          items: [
            '选择一个很小的改变：把任务难度提高 5%（例如多做 10 分钟）。',
            '设定一个可控的“开始条件”：只要坐下+打开文件即可。',
            '记录你想要的成长方向：今天练习什么？',
          ],
        ),
        _Block(
          title: '提高“资源感”',
          items: [
            '把任务拆成 3 步，并写下每步的开始时间。',
            '提前准备资源：资料、场地、伙伴、音乐/计时器。',
          ],
        ),
      ];
    }

    // Learning zone (default)
    return const [
      _Block(
        title: '保持在“学习区”',
        items: [
          '把目标设为“略有难度但可控”：需求≈资源+一点点。',
          '如果唤醒偏高：做 1 分钟慢呼吸；如果偏低：站起来走动 1 分钟。',
          '用番茄钟 25/5：25 分钟专注 + 5 分钟休息。',
        ],
      ),
      _Block(
        title: '复盘与调整',
        items: [
          '结束后记录：做到了什么？最耗能的点是什么？下次如何降低摩擦？',
          '如果连续多次进入恐慌区：考虑下调需求或增加资源（睡眠、时间、人）。',
        ],
      ),
    ];
  }
}

class _Block {
  const _Block({required this.title, required this.items});

  final String title;
  final List<String> items;
}
