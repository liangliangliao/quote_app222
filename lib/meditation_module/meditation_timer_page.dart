import 'package:flutter/material.dart';

import 'meditation_models.dart';
import 'meditation_player_page.dart';

class MeditationTimerPage extends StatefulWidget {
  const MeditationTimerPage({super.key});

  @override
  State<MeditationTimerPage> createState() => _MeditationTimerPageState();
}

class _MeditationTimerPageState extends State<MeditationTimerPage> {
  int _minutes = 5;
  bool _hideCountdown = false;

  Future<void> _start() async {
    final session = MeditationSessionTemplate(
      key: 'silent_timer_${_minutes}m',
      title: '安静坐一会儿',
      type: '无引导冥想',
      category: '计时器',
      description: '无引导计时器，只保留呼吸动画和结束记录。',
      durationSeconds: _minutes * 60,
      steps: const [
        MeditationStep(startSecond: 0, text: '安静坐一会儿。分心时，知道分心，然后回来。'),
      ],
      endingReflection: '安静坐下本身，就是把注意力交还给自己的动作。',
    );
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MeditationPlayerPage(session: session, currentState: '无引导冥想', timerOnly: true)),
    );
    if (changed == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final options = [1, 3, 5, 10, 20];
    return Scaffold(
      appBar: AppBar(title: const Text('安静坐一会儿')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFFF0F7F4), borderRadius: BorderRadius.circular(22)),
            child: const Text(
              '无引导冥想适合已经熟悉基本练习的用户。你不需要听任何讲解，只需要坐下来，发现分心，然后回来。',
              style: TextStyle(height: 1.6),
            ),
          ),
          const SizedBox(height: 24),
          const Text('选择时长', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.map((m) {
              return ChoiceChip(
                label: Text('$m 分钟'),
                selected: _minutes == m,
                onSelected: (_) => setState(() => _minutes = m),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('隐藏倒计时'),
            subtitle: const Text('MVP1 播放页仍显示进度；后续可加入真正隐藏模式'),
            trailing: Switch(value: _hideCountdown, onChanged: (v) => setState(() => _hideCountdown = v)),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow),
            label: Text('开始 $_minutes 分钟'),
          ),
          const SizedBox(height: 16),
          const Text(
            '下一版可继续扩展：开始铃声、结束铃声、间隔铃声、背景音、屏幕常亮、震动提醒。',
            style: TextStyle(fontSize: 12, color: Colors.black45, height: 1.5),
          ),
        ],
      ),
    );
  }
}
