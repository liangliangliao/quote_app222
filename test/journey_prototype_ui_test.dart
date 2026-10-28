import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/pages/tasks_page.dart';
import 'package:quote_app/widgets/discovery_directory.dart';
import 'package:quote_app/widgets/journey_design.dart';
import 'package:quote_app/widgets/quote_adaptive_frame.dart';
import 'package:quote_app/widgets/quote_home_scene.dart';
import 'package:quote_app/widgets/poster_pure_flutter.dart';

const _export = bool.fromEnvironment('JOURNEY_PREVIEW');

Widget _scene({VoidCallback? next}) => QuoteHomeScene(
  poster: const PosterPureFlutter(
    topic: '不可战胜的夏天',
    quote: '在隆冬之中，我终于在自己内心发现了一个不可战胜的夏天。',
    author: '—— 阿尔贝·加缪《重返提帕萨》',
    note: '在承认困难之后，仍然选择热爱、行动与承担。',
    avatar: 'assets/avatars/Albert_Camus_1945_(cropped).jpg',
  ),
  moreMenu: IconButton(
    tooltip: '更多操作',
    onPressed: () {},
    icon: const Icon(Icons.more_vert_rounded),
  ),
  onMenu: () {},
  onSearch: () {},
  onPin: () {},
  onNext: next ?? () {},
  onFavorite: () {},
  onCategories: () {},
  onShare: () {},
  onPinnedQuotes: () {},
  onHistory: (_) {},
);

List<DiscoveryDestination> _destinations() => [
  for (final entry in [
    ('当下心情与情绪分析', '看见此刻的自己', Icons.spa_outlined, JourneyArt.mountains),
    ('写日记', '为感受留一页空间', Icons.edit_note_outlined, JourneyArt.book),
    (
      '成为自己 · Self OS',
      '看见可能性，在行动中认识自己',
      Icons.explore_outlined,
      JourneyArt.path,
    ),
    ('六模块证据成长', '行动、结果与复盘', Icons.route_outlined, JourneyArt.sprout),
    ('向己 · 智能目标导师', '一个目标，一步行动', Icons.flag_outlined, JourneyArt.doorway),
    ('生理赋能', '运动、冥想、睡眠、饮食与触摸', Icons.spa_outlined, JourneyArt.stones),
  ])
    DiscoveryDestination(
      title: entry.$1,
      subtitle: entry.$2,
      icon: entry.$3,
      artwork: entry.$4,
      categories: const {'认识自己'},
      recommended: true,
      onTap: () {},
    ),
];

Widget _app(
  Widget child, {
  int selected = 0,
  double scale = 1,
  GlobalKey? boundary,
}) => RepaintBoundary(
  key: boundary,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: _export ? 'JourneyPreviewCJK' : null,
      scaffoldBackgroundColor: journeyPaper,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: const EdgeInsets.only(top: 24),
        textScaler: TextScaler.linear(scale),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: child,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 60,
          backgroundColor: Colors.white,
          indicatorColor: Colors.transparent,
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 25,
              color: states.contains(WidgetState.selected)
                  ? journeyGreen
                  : const Color(0xff77757d),
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              color: states.contains(WidgetState.selected)
                  ? journeyGreen
                  : const Color(0xff85818a),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: '首页',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_toggle_off_rounded),
              label: '历史',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore_rounded),
              label: '发现之旅',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note_rounded),
              label: '任务',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              label: '设置',
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'all home actions stay reachable and the heading clears the frame',
    (tester) async {
      for (final viewport in [
        (const Size(320, 640), 1.6),
        (const Size(390, 844), 1.0),
        (const Size(768, 1024), 1.5),
      ]) {
        await tester.binding.setSurfaceSize(viewport.$1);
        var next = false;
        await tester.pumpWidget(
          _app(_scene(next: () => next = true), scale: viewport.$2),
        );
        await tester.pumpAndSettle();
        final photo = tester.getRect(find.byType(QuoteAdaptiveFrame));
        final heading = tester.getRect(
          find.byKey(const ValueKey('home-heading')),
        );
        expect(heading.bottom, lessThan(photo.top + photo.height * .111));
        for (final action in [
          'menu',
          'search',
          'pin',
          'next',
          'favorite',
          'categories',
          'share',
        ]) {
          await tester.ensureVisible(find.byKey(ValueKey('home-$action')));
          await tester.pumpAndSettle();
          expect(find.byKey(ValueKey('home-$action')), findsOneWidget);
        }
        await tester.ensureVisible(find.byKey(const ValueKey('home-next')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('home-next')));
        expect(next, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('the discovery index changes the visible category', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        DiscoveryDirectory(
          destinations: _destinations(),
          onRefresh: () async {},
        ),
        selected: 2,
      ),
    );
    final inspiration = find.byKey(const ValueKey('discover-category-灵感天地'));
    expect(tester.getRect(inspiration).right, lessThanOrEqualTo(390));
    await tester.tap(find.byKey(const ValueKey('discover-index')));
    await tester.pumpAndSettle();
    expect(find.text('从哪里开始？'), findsOneWidget);
    await tester.tap(find.text('认识自己').last);
    await tester.pumpAndSettle();
    expect(find.text('从哪里开始？'), findsNothing);
    final chosen = tester.widget<JourneyFilterChip>(
      find.byKey(const ValueKey('discover-category-认识自己')),
    );
    expect(chosen.selected, isTrue);
  });

  if (_export)
    testWidgets('export three prototype previews', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final entry in {
        'JourneyPreviewCJK':
            '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
        'MaterialIcons':
            '/workspace/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        'QuoteKaiShu': 'assets/fonts/MaShanZheng-Regular.ttf',
        'QuoteXingShu': 'assets/fonts/ZhiMangXing-Regular.ttf',
        'QuoteLiterarySerif': 'assets/fonts/LibreBaskerville-Variable.ttf',
      }.entries) {
        final bytes = File(entry.value).readAsBytesSync();
        final font = FontLoader(entry.key)
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await tester.runAsync(font.load);
      }
      final now = DateTime.now();
      final tasks = [
        {
          'task_uid': 'manual',
          'name': '尼采',
          'type': 'manual',
          'status': 'on',
          'freq_type': 'daily',
          'start_time': '21:36',
          'next_time': now.add(const Duration(hours: 23)).toIso8601String(),
        },
        {
          'task_uid': 'auto',
          'name': 'AI 自动获取名人名言',
          'type': 'auto',
          'status': 'on',
          'freq_type': 'daily',
          'start_time': '07:00',
          'last_run_at': now
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
          'next_time': now.add(const Duration(hours: 9)).toIso8601String(),
        },
        {
          'task_uid': 'goal',
          'name': '向己 · 目标守护',
          'type': 'xiangji_goal',
          'status': 'on',
          'freq_type': 'daily',
          'start_time': '20:00',
          'last_run_at': now
              .subtract(const Duration(hours: 8))
              .toIso8601String(),
          'next_time': now
              .add(const Duration(days: 1, hours: 2))
              .toIso8601String(),
        },
      ];
      for (final entry in <String, (Widget, int)>{
        'home': (_scene(), 0),
        'tasks': (
          TasksPage(
            active: false,
            loadTasks: () async => tasks,
            openEditor: (_) async {},
          ),
          3,
        ),
        'discovery': (
          Stack(
            children: [
              DiscoveryDirectory(
                destinations: _destinations(),
                onRefresh: () async {},
              ),
              const Positioned(top: 65, right: 16, child: JourneyAiOrb()),
            ],
          ),
          2,
        ),
      }.entries) {
        final boundary = GlobalKey();
        await tester.pumpWidget(
          _app(entry.value.$1, selected: entry.value.$2, boundary: boundary),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(Scaffold).first);
        await tester.runAsync(() async {
          for (final asset in [
            'assets/journey/rhythm_header.png',
            'assets/journey/discovery_header.png',
            'assets/journey/vignettes.png',
            'assets/bg-white-gallery.png',
            'assets/avatars/Albert_Camus_1945_(cropped).jpg',
          ])
            await precacheImage(AssetImage(asset), context);
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final rendered =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await rendered.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final folder = Directory('build/journey-preview')
            ..createSync(recursive: true);
          File(
            '${folder.path}/${entry.key}-preview.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
}
