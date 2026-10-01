import 'package:flutter/material.dart';

import '../copy.dart';
import '../domain/enemy_presence.dart';
import '../enemy_reminder.dart';
import '../enemy_talker.dart';
import 'enemy_tabs.dart';
import 'enemy_thread_tab.dart';
import 'ui_helpers.dart';

class EnemyHomePage extends StatelessWidget {
  const EnemyHomePage({
    super.key,
    required this.presence,
    required this.voice,
    required this.reminder,
  });

  final EnemyPresence presence;
  final EnemyVoiceOut voice;
  final EnemyReminder reminder;

  @override
  Widget build(BuildContext context) {
    final ThemeData base = ThemeData.dark();
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: kEnemyBg,
        colorScheme: base.colorScheme.copyWith(
          primary: kEnemyAccent,
          onPrimary: Colors.white,
        ),
        // 按钮文字和开关的滑块都跟着 onPrimary，别落回默认的暗紫色。
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> s) => s.contains(WidgetState.selected) ? Colors.white : kEnemyMuted,
          ),
          trackColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> s) =>
                s.contains(WidgetState.selected) ? kEnemyAccent : const Color(0xFF3A2C2A),
          ),
        ),
      ),
      child: DefaultTabController(
        length: 5,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: kEnemyBg,
            foregroundColor: kEnemyText,
            title: const Text(EnemyCopy.title),
            bottom: const TabBar(
              isScrollable: true,
              indicatorColor: kEnemyAccent,
              tabs: <Tab>[
                Tab(text: '对峙'),
                Tab(text: '字据'),
                Tab(text: '案卷'),
                Tab(text: '教训'),
                Tab(text: '设置'),
              ],
            ),
          ),
          body: TabBarView(
            children: <Widget>[
              ThreadTab(presence: presence, voice: voice),
              CommitmentsTab(engine: presence.engine, presence: presence),
              DossierTab(engine: presence.engine),
              LessonsTab(engine: presence.engine),
              SettingsTab(engine: presence.engine, reminder: reminder, voice: voice),
            ],
          ),
        ),
      ),
    );
  }
}
