import 'dart:math' as math;

import 'package:flutter/material.dart';

const settingsInk = Color(0xff292934);
const settingsAccent = Color(0xff6860bd);
const settingsPaper = Color(0xfff7f8fb);

enum SettingsSection {
  ai,
  voice,
  prompts,
  parameters,
  semantic,
  modules,
  movies,
  media,
  data,
  appearance,
  logs,
  engine,
  experience,
  sport,
  reminders,
  location;

  String get title => switch (this) {
    ai => 'AI 提供方与模型',
    voice => '语音与声音',
    prompts => '提示词模板',
    parameters => '全局 AI 参数',
    semantic => '语义一致性精判',
    modules => '功能模块配置',
    movies => '电影角色实验室',
    media => '音乐与视频服务',
    data => '文件与数据',
    appearance => '显示与书法',
    logs => '运行日志',
    engine => '概念实践引擎',
    experience => '心情与自尊问答',
    sport => '运动与音乐',
    reminders => '提醒设置',
    location => '地图与位置服务',
  };

  bool get hasSaveAction => const {
    ai,
    parameters,
    media,
    appearance,
    engine,
    experience,
  }.contains(this);
}

class SettingsAiSummary {
  const SettingsAiSummary({
    this.provider = '—',
    this.model = '—',
    this.configured = false,
    this.loading = false,
  });
  final String provider;
  final String model;
  final bool configured;
  final bool loading;
}

/// The settings landing page contains destinations, never editable credentials.
class SettingsDashboard extends StatelessWidget {
  const SettingsDashboard({
    super.key,
    required this.summary,
    required this.onOpen,
  });
  final SettingsAiSummary summary;
  final ValueChanged<SettingsSection> onOpen;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: settingsPaper,
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xfff5f0e9), Color(0xfff8f8fc), Color(0xfff9fafb)],
          stops: [0, .38, 1],
        ),
      ),
      child: CustomScrollView(
        key: const PageStorageKey('settings-dashboard-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: _SettingsHeader(topInset: MediaQuery.paddingOf(context).top),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AiSettingsCard(
                        summary: summary,
                        onTap: () => onOpen(SettingsSection.ai),
                      ),
                      const SizedBox(height: 9),
                      _pair(
                        _SettingsTile(
                          section: SettingsSection.voice,
                          icon: Icons.mic_rounded,
                          subtitle: 'TTS / ASR 配置',
                          detail: 'ElevenLabs、Azure、\n讯飞等语音服务',
                          art: _SettingsArt.waves,
                          onOpen: onOpen,
                        ),
                        _SettingsTile(
                          section: SettingsSection.prompts,
                          icon: Icons.description_rounded,
                          subtitle: '默认模板 / 自定义模板',
                          detail: '管理与编辑 Prompt，\n让表达更贴近自己',
                          art: _SettingsArt.note,
                          onOpen: onOpen,
                        ),
                      ),
                      const SizedBox(height: 9),
                      _SettingsWideTile(
                        section: SettingsSection.parameters,
                        icon: Icons.tune_rounded,
                        subtitle:
                            '请求超时、最大输出 Tokens、Temperature、\nTop P 与重试等通用参数',
                        art: _SettingsArt.gears,
                        onOpen: onOpen,
                      ),
                      const SizedBox(height: 9),
                      _pair(
                        _SettingsTile(
                          section: SettingsSection.semantic,
                          icon: Icons.find_in_page_rounded,
                          subtitle: 'Embedding、LLM Judge',
                          detail: '事实抽取、标题忠实性\n与 Reranker 精排',
                          art: _SettingsArt.books,
                          onOpen: onOpen,
                        ),
                        _SettingsTile(
                          section: SettingsSection.modules,
                          icon: Icons.grid_view_rounded,
                          subtitle: '让每一处都适合你',
                          detail: '健康饮食、心情问答、\n运动与提醒等模块',
                          art: _SettingsArt.mountains,
                          onOpen: onOpen,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(5, 16, 5, 9),
                        child: Text(
                          '内容与多媒体服务',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xff96929c),
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                      _SettingsWideTile(
                        section: SettingsSection.movies,
                        icon: Icons.theaters_outlined,
                        subtitle: 'OpenSubtitles / TMDb 密钥，\n字幕语言与模块配置',
                        art: _SettingsArt.film,
                        warm: true,
                        onOpen: onOpen,
                      ),
                      const SizedBox(height: 7),
                      _SettingsWideTile(
                        section: SettingsSection.media,
                        icon: Icons.music_note_rounded,
                        subtitle: 'YouTube Data API、Jamendo、酷狗开放组件\n等音乐搜索与播放配置',
                        art: _SettingsArt.record,
                        warm: true,
                        onOpen: onOpen,
                      ),
                      const SizedBox(height: 7),
                      _SettingsWideTile(
                        section: SettingsSection.data,
                        icon: Icons.folder_open_rounded,
                        subtitle: '量表模板上传、名言导入\n与提示词备份恢复',
                        art: _SettingsArt.journal,
                        warm: true,
                        onOpen: onOpen,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _QuietSettingsLink(
                              section: SettingsSection.appearance,
                              icon: Icons.gesture_rounded,
                              onOpen: onOpen,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _QuietSettingsLink(
                              section: SettingsSection.logs,
                              icon: Icons.receipt_long_outlined,
                              onOpen: onOpen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      const Center(
                        child: Text(
                          '把日常，调成喜欢的模样。',
                          style: TextStyle(
                            fontFamily: 'QuoteKaiShu',
                            color: Color(0xffaaa1a0),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _pair(Widget first, Widget second) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: first),
        const SizedBox(width: 9),
        Expanded(child: second),
      ],
    ),
  );
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.topInset});
  final double topInset;
  @override
  Widget build(BuildContext context) => SizedBox(
    height:
        topInset +
        102 +
        (MediaQuery.textScalerOf(context).scale(35) - 35).clamp(0, 55),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/settings/reading_room_header.png',
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
          excludeFromSemantics: true,
          filterQuality: FilterQuality.medium,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x44fffdf9), Color(0x00fffdf9)],
              stops: [0, .62],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 28,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00f7f8fb), Color(0xfff7f8fb)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          top: topInset + 16,
          right: MediaQuery.sizeOf(context).width < 360 ? 100 : 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '设置',
                style: TextStyle(
                  fontFamily: 'QuoteKaiShu',
                  fontSize: 35,
                  height: 1.15,
                  color: Color(0xff28251f),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '打造属于你的专属体验',
                style: TextStyle(
                  fontFamily: 'QuoteKaiShu',
                  fontSize: 13,
                  letterSpacing: 1,
                  height: 1.4,
                  color: const Color(0xff6b635a).withValues(alpha: .92),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingsSurface extends StatelessWidget {
  const _SettingsSurface({
    required this.child,
    required this.onTap,
    required this.entryKey,
    this.tint = const Color(0xfffbfbff),
  });
  final Widget child;
  final VoidCallback onTap;
  final Key entryKey;
  final Color tint;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x048276a2),
          blurRadius: 18,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Material(
      key: entryKey,
      color: tint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xccffffff)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: child),
    ),
  );
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon(this.icon, {this.warm = false, this.size = 35});
  final IconData icon;
  final bool warm;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: warm
            ? const [Color(0xfffbf7ee), Color(0xfff0ece5)]
            : const [Color(0xfff5f5ff), Color(0xffe9eafb)],
      ),
    ),
    child: Icon(
      icon,
      size: size * .55,
      color: warm ? const Color(0xff99846d) : settingsAccent,
    ),
  );
}

class _AiSettingsCard extends StatelessWidget {
  const _AiSettingsCard({required this.summary, required this.onTap});
  final SettingsAiSummary summary;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _SettingsSurface(
    onTap: onTap,
    entryKey: const ValueKey('settings-entry-ai'),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsIcon(Icons.view_in_ar_rounded, size: 39),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 提供方与模型',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: settingsInk,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '统一配置 OpenAI、DeepSeek、Gemini、\nAzure、OpenRouter 等模型与 API。',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: Color(0xff85818d),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Color(0xff77717d),
                size: 21,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xfff3f3f9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 10,
                    child: _summaryCell('当前提供方', summary.provider),
                  ),
                  _divider(),
                  Expanded(
                    flex: 12,
                    child: _summaryCell('当前模型', summary.model),
                  ),
                  _divider(),
                  Expanded(
                    flex: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '状态',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xff9a96a1),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: summary.loading
                                    ? const Color(0xffc4bece)
                                    : summary.configured
                                    ? const Color(0xff51ae82)
                                    : const Color(0xffc5ab7d),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                summary.loading
                                    ? '读取中'
                                    : summary.configured
                                    ? '已配置'
                                    : '待配置',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xff65616e),
                                ),
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _summaryCell(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: Color(0xff9a96a1)),
      ),
      const SizedBox(height: 5),
      Text(
        summary.loading
            ? '—'
            : value.isEmpty
            ? '未选择'
            : value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          height: 1.25,
          color: Color(0xff565260),
        ),
      ),
    ],
  );
  Widget _divider() => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    color: const Color(0xffe4e2ec),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.section,
    required this.icon,
    required this.subtitle,
    required this.detail,
    required this.art,
    required this.onOpen,
  });
  final SettingsSection section;
  final IconData icon;
  final String subtitle;
  final String detail;
  final _SettingsArt art;
  final ValueChanged<SettingsSection> onOpen;
  @override
  Widget build(BuildContext context) => _SettingsSurface(
    onTap: () => onOpen(section),
    entryKey: ValueKey('settings-entry-${section.name}'),
    tint: art == _SettingsArt.waves
        ? const Color(0xfffbf8ff)
        : const Color(0xfffdfcfa),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 106),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 60,
            child: ExcludeSemantics(
              child: CustomPaint(painter: _SettingsArtPainter(art)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _SettingsIcon(icon, size: 31),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        section.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: settingsInk,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: Color(0xff817b88),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: Color(0xff77727e),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.5,
                    color: Color(0xff9a949d),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SettingsWideTile extends StatelessWidget {
  const _SettingsWideTile({
    required this.section,
    required this.icon,
    required this.subtitle,
    required this.art,
    required this.onOpen,
    this.warm = false,
  });
  final SettingsSection section;
  final IconData icon;
  final String subtitle;
  final _SettingsArt art;
  final bool warm;
  final ValueChanged<SettingsSection> onOpen;
  @override
  Widget build(BuildContext context) => _SettingsSurface(
    entryKey: ValueKey('settings-entry-${section.name}'),
    onTap: () => onOpen(section),
    tint: warm ? const Color(0xfffdfbf9) : const Color(0xfffcfcff),
    child: Stack(
      children: [
        Positioned(
          right: 0,
          bottom: 0,
          width: 110,
          height: 85,
          child: ExcludeSemantics(
            child: CustomPaint(painter: _SettingsArtPainter(art)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 51, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsIcon(icon, warm: warm, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: settingsInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: Color(0xff8c858b),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Positioned(
          right: 12,
          top: 13,
          child: Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Color(0xff807781),
          ),
        ),
      ],
    ),
  );
}

class _QuietSettingsLink extends StatelessWidget {
  const _QuietSettingsLink({
    required this.section,
    required this.icon,
    required this.onOpen,
  });
  final SettingsSection section;
  final IconData icon;
  final ValueChanged<SettingsSection> onOpen;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xddffffff),
    borderRadius: BorderRadius.circular(13),
    child: InkWell(
      key: ValueKey('settings-entry-${section.name}'),
      borderRadius: BorderRadius.circular(13),
      onTap: () => onOpen(section),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 17, color: const Color(0xff9185a5)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                section.title,
                style: const TextStyle(fontSize: 12, color: Color(0xff7c7385)),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 15,
              color: Color(0xffaaa1b2),
            ),
          ],
        ),
      ),
    ),
  );
}

enum _SettingsArt {
  waves,
  note,
  gears,
  books,
  mountains,
  film,
  record,
  journal,
}

/// Quiet, static illustrations keep the cards readable at every text scale.
class _SettingsArtPainter extends CustomPainter {
  const _SettingsArtPainter(this.art);
  final _SettingsArt art;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    switch (art) {
      case _SettingsArt.waves:
        _waves(canvas, size);
      case _SettingsArt.mountains:
        _mountains(canvas, size);
      case _SettingsArt.gears:
        _gear(canvas, Offset(size.width * .78, size.height * .77), 30, -.2);
        _gear(canvas, Offset(size.width * 1.03, size.height * .31), 25, .2);
      case _SettingsArt.books:
        _books(canvas, size);
      case _SettingsArt.film:
        _film(canvas, size);
      case _SettingsArt.record:
        _record(canvas, size);
      case _SettingsArt.note:
        _notebook(canvas, size, false);
      case _SettingsArt.journal:
        _notebook(canvas, size, true);
    }
    canvas.restore();
  }

  void _waves(Canvas c, Size s) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6;
    for (var i = 0; i < 27; i++) {
      final y = s.height * .26 + i * 1.4;
      paint.color = Color.lerp(
        const Color(0xffb6a1ec),
        const Color(0xffd4d0f0),
        i / 27,
      )!.withValues(alpha: .30);
      c.drawPath(
        Path()
          ..moveTo(-10, y + 10)
          ..cubicTo(
            s.width * .2,
            y - 40,
            s.width * .3,
            y + 65,
            s.width * .59,
            y + 28,
          )
          ..cubicTo(
            s.width * .76,
            y + 6,
            s.width * .9,
            y + 13,
            s.width + 10,
            y - 10,
          ),
        paint,
      );
    }
  }

  void _mountains(Canvas c, Size s) {
    for (var layer = 0; layer < 4; layer++) {
      final path = Path()..moveTo(0, s.height);
      for (var x = 0; x <= 24; x++) {
        final y =
            s.height * (.54 + layer * .12) -
            math.sin(x * .47 + layer * 2) * (11 - layer * 1.5) -
            math.sin(x * .23 + layer) * 7;
        path.lineTo(s.width * x / 24, y);
      }
      path.lineTo(s.width, s.height);
      path.close();
      c.drawPath(
        path,
        Paint()
          ..color = Color.lerp(
            const Color(0xffd9dbe1),
            const Color(0xff8997a6),
            layer / 4,
          )!.withValues(alpha: .35),
      );
    }
  }

  void _gear(Canvas c, Offset center, double radius, double angle) {
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(angle);
    final path = Path()..fillType = PathFillType.evenOdd;
    for (var i = 0; i < 48; i++) {
      final a = i * math.pi * 2 / 48;
      final r = (i % 4 == 1 || i % 4 == 2) ? radius : radius * .83;
      if (i == 0) {
        path.moveTo(math.cos(a) * r, math.sin(a) * r);
      } else {
        path.lineTo(math.cos(a) * r, math.sin(a) * r);
      }
    }
    path.close();
    path.addOval(Rect.fromCircle(center: Offset.zero, radius: radius * .43));
    c.drawShadow(path, const Color(0xff6a5a48), 2, false);
    c.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xffe3ded9), Color(0xffa39991), Color(0xffeeeae4)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xffbbb1a8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6,
    );
    c.restore();
  }

  void _books(Canvas c, Size s) {
    c.save();
    c.translate(-9, s.height - 30);
    c.rotate(-.08);
    for (double i = 0; i < 3; i++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * -2, i * 10, 53 + i * 5, 9),
        const Radius.circular(1.5),
      );
      c.drawRRect(rect, Paint()..color = const Color(0xffd9c8b5));
      c.drawRect(
        Rect.fromLTWH(2, i * 10 + 2, 47 + i * 5, 4),
        Paint()..color = const Color(0xfff0e9df),
      );
      c.drawLine(
        Offset(2, i * 10 + 5),
        Offset(47 + i * 5, i * 10 + 5),
        Paint()
          ..color = const Color(0xffc9b9a6)
          ..strokeWidth = .4,
      );
    }
    c.restore();
  }

  void _film(Canvas c, Size s) {
    c.save();
    c.translate(s.width * .62, s.height * .82);
    c.rotate(-.28);
    final rect = Rect.fromLTWH(-22, -13, 82, 37);
    c.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xffd9cfc4), Color(0xff998c84), Color(0xffe3d9cc)],
        ).createShader(rect),
    );
    for (double i = 0; i < 5; i++) {
      c.drawRect(
        Rect.fromLTWH(-18 + i * 16, -6, 12, 22),
        Paint()..color = const Color(0xfff9f4ee).withValues(alpha: .7),
      );
      c.drawRect(
        Rect.fromLTWH(-18 + i * 16, -11, 3, 3),
        Paint()..color = const Color(0xfffdfbf9),
      );
      c.drawRect(
        Rect.fromLTWH(-18 + i * 16, 19, 3, 3),
        Paint()..color = const Color(0xfffdfbf9),
      );
    }
    c.restore();
  }

  void _record(Canvas c, Size s) {
    c.save();
    c.translate(s.width * .88, s.height * .75);
    c.rotate(-.27);
    c.scale(1, .62);
    c.drawCircle(
      Offset.zero,
      43,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xffc4b3a4), Color(0xff504c4a), Color(0xff79706c)],
        ).createShader(const Rect.fromLTWH(-43, -43, 86, 86)),
    );
    for (var i = 17; i < 40; i += 3) {
      c.drawCircle(
        Offset.zero,
        i.toDouble(),
        Paint()
          ..color = const Color(0x33dbd0c6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .6,
      );
    }
    c.drawCircle(Offset.zero, 12, Paint()..color = const Color(0xffd6c5b2));
    c.drawCircle(Offset.zero, 1.5, Paint()..color = const Color(0xff76635b));
    c.restore();
    c.drawLine(
      Offset(s.width * .4, s.height * .4),
      Offset(s.width * .64, s.height * .88),
      Paint()
        ..color = const Color(0xffb6a08e)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _notebook(Canvas c, Size s, bool journal) {
    c.save();
    c.translate(s.width * (journal ? .82 : .84), s.height * .94);
    c.rotate(journal ? -.3 : -.54);
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-29, -34, 65, 54),
      const Radius.circular(2),
    );
    c.drawShadow(Path()..addRRect(rect), const Color(0xffaaa096), 3, false);
    c.drawRRect(rect, Paint()..color = const Color(0xfff5f1eb));
    for (double i = 0; i < 6; i++) {
      c.drawLine(
        Offset(-18, -20 + i * 5),
        Offset(25, -20 + i * 5),
        Paint()
          ..color = const Color(0xffd8d1ca)
          ..strokeWidth = .6,
      );
    }
    if (journal) {
      for (double i = 0; i < 7; i++) {
        c.drawOval(
          Rect.fromLTWH(-32, -30 + i * 7, 7, 4),
          Paint()
            ..color = const Color(0xffb7a38c)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
    c.drawLine(
      const Offset(29, -33),
      const Offset(40, 11),
      Paint()
        ..color = const Color(0xffa4917c)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _SettingsArtPainter oldDelegate) =>
      oldDelegate.art != art;
}
