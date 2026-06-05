import 'package:flutter/material.dart';

import 'sport_detail_page.dart';
import '../meditation_module/meditation_home_page.dart';
import '../health_diet/pages/health_diet_home_page.dart';
import 'touch_mystify_wallpaper_page.dart';

/// 生理赋能详情页面
///
/// 此页负责展示马斯洛需求层次理论相关的引言，并按照模块罗列
/// 身体层面的赋能项：运动、冥想、触摸、睡眠、饮食。点击各模块
/// 导航至对应详情页。为了与原有项目保持一致，这个页面使用
/// Material 样式而非 Cupertino 样式。
class PhysicalEnhancementPage extends StatelessWidget {
  const PhysicalEnhancementPage({super.key});

  // 引言文本：马斯洛需求层次理论相关名言及注释
  Widget _buildHeader() {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Text(
              '人的行为由需求驱动。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              '—— 马斯洛',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 8),
            Text(
              '满足生理需求是迈向更高层次自我实现的基础。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('生理赋能'),
      ),
      body: ListView(
        children: [
          _buildHeader(),
          // 运动
          ListTile(
            leading: const Icon(Icons.directions_walk, color: Colors.green),
            title: const Text('运动'),
            subtitle: const Text('用步伐激活身体能量'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SportDetailPage()),
              );
            },
          ),
          const Divider(height: 1),
          // 冥想
          ListTile(
            leading: const Icon(Icons.self_improvement, color: Colors.blue),
            title: const Text('冥想'),
            subtitle: const Text('平静大脑，修复身心'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MeditationModulePage()),
              );
            },
          ),
          const Divider(height: 1),
          // 触摸
          ListTile(
            // hands_clapping 图标在部分 Flutter 版本中不存在，改用 pan_tool 代替
            leading: const Icon(Icons.pan_tool, color: Colors.orange),
            title: const Text('触摸'),
            subtitle: const Text('触摸 · V167 可见七十二变光弦版：修复黑底下变身层过暗不可见'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TouchMystifyWallpaperPage()),
              );
            },
          ),
          const Divider(height: 1),
          // 睡眠
          ListTile(
            leading: const Icon(Icons.bedtime, color: Colors.purple),
            title: const Text('睡眠'),
            subtitle: const Text('高质量睡眠，白天更有力'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SleepModulePage()),
              );
            },
          ),
          const Divider(height: 1),
          // 饮食
          ListTile(
            leading: const Icon(Icons.restaurant, color: Colors.red),
            title: const Text('饮食'),
            subtitle: const Text('好好吃饭，给身体高质量“燃料”'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HealthDietHomePage()),
              );
            },
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

/// Placeholder page for sleep module
class SleepModulePage extends StatelessWidget {
  const SleepModulePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('睡眠')),
      body: const Center(child: Text('睡眠模块即将上线')), // Placeholder content
    );
  }
}
