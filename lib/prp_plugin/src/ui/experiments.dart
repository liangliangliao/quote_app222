import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../runtime.dart';
import '../enhancement_models.dart';
import 'feature_pages.dart';
import 'presentation.dart';

class PrpParticlesPage extends StatefulWidget {
  const PrpParticlesPage({super.key, required this.runtime});
  final PrpRuntime runtime;
  @override
  State<PrpParticlesPage> createState() => _PrpParticlesPageState();
}

class _PrpParticlesPageState extends State<PrpParticlesPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker =
      AnimationController(vsync: this, duration: const Duration(seconds: 12));
  bool _pressed = false;
  Offset? _touch;
  int? _pointer;
  double _energy = 0;
  @override
  void initState() {
    super.initState();
    _ticker.addListener(_tick);
  }

  void _tick() {
    if (!_pressed) {
      _energy *= .955;
      if (_energy < .005) {
        _energy = 0;
        _ticker.stop();
      }
    } else
      _energy = (_energy + .035).clamp(0, 1);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PrpActivePage(
      active: () =>
          widget.runtime.enabled && widget.runtime.preferences.particles,
      child: Theme(
          data: prpPaperTheme(context),
          child: Scaffold(
              appBar: AppBar(title: const Text('潮汐光迹')),
              body: Column(children: [
                const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('在光点上按住，再松开。只是一个小实验，不计分，也不记录失败。')),
                Text(_pressed ? '按住时：粒子散开' : '松手后：粒子缓缓回落',
                    key: const ValueKey('prp_particle_state')),
                Expanded(
                    child: Listener(
                        key: const ValueKey('prp_particle_canvas'),
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) {
                          if (_pointer != null) return;
                          setState(() {
                            _pointer = e.pointer;
                            _pressed = true;
                            _touch = e.localPosition;
                          });
                          if (!_ticker.isAnimating) _ticker.repeat();
                        },
                        onPointerMove: (e) {
                          if (_pointer == e.pointer) _touch = e.localPosition;
                        },
                        onPointerUp: (e) {
                          if (_pointer == e.pointer)
                            setState(() {
                              _pointer = null;
                              _pressed = false;
                            });
                        },
                        onPointerCancel: (e) {
                          if (_pointer == e.pointer)
                            setState(() {
                              _pointer = null;
                              _pressed = false;
                            });
                        },
                        child: AnimatedBuilder(
                            animation: _ticker,
                            builder: (_, __) => CustomPaint(
                                painter: _TidePainter(
                                    _ticker.value, _energy, _touch),
                                child: const SizedBox.expand())))),
                const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('不用把每一个光点按回原处。松开后，它们会自己慢下来。')),
              ]))));
}

class _TidePainter extends CustomPainter {
  const _TidePainter(this.time, this.energy, this.touch);
  final double time, energy;
  final Offset? touch;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final scale = math.min(size.width, size.height) * .33;
    final paint = Paint();
    for (var i = 0; i < 80; i++) {
      final angle = i * 2.399963 + time * math.pi * 2 * energy;
      final radius = math.sqrt((i + 1) / 80) * scale;
      var point = center +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius * .72);
      final away = point - (touch ?? center);
      final length = away.distance.clamp(1.0, 10000.0);
      point += away / length * energy * (45 + 30 * math.sin(i + time * 50));
      point +=
          Offset(math.sin(i * 13 + time * 60), math.cos(i * 7 - time * 45)) *
              energy *
              35;
      paint.color = (i.isEven ? prpTeal : prpIndigo)
          .withValues(alpha: .35 + .45 * (1 - energy));
      canvas.drawCircle(point, 2.5 + (i % 4) * .6, paint);
    }
  }

  @override
  bool shouldRepaint(_TidePainter old) =>
      old.time != time || old.energy != energy || old.touch != touch;
}

class PrpDraftQuotesPage extends StatelessWidget {
  const PrpDraftQuotesPage({super.key, required this.runtime});
  final PrpRuntime runtime;
  @override
  Widget build(BuildContext context) => PrpActivePage(
      active: () => runtime.enabled && runtime.preferences.draftQuotes,
      child: Theme(
          data: prpPaperTheme(context),
          child: Scaffold(
              appBar: AppBar(title: const Text('废稿短句')),
              body: ListView(padding: const EdgeInsets.all(20), children: [
                const Text('本地创作的练习句，不是名人引言，也不是你的经历或已盖印教训。可从一句话起草，再换成自己的真实经验。'),
                for (final entry in PrpDraftQuote.entries)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                Text(entry.text,
                                    style: const TextStyle(
                                        fontSize: 19, height: 1.6)),
                                Wrap(children: [
                                  TextButton.icon(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                            ClipboardData(text: entry.text));
                                        if (context.mounted)
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text('练习句已复制。')));
                                      },
                                      icon: const Icon(Icons.copy_outlined),
                                      label: const Text('复制练习句')),
                                  TextButton(
                                      onPressed: () async {
                                        final offer = await runtime
                                            .reviewDraftQuote(entry);
                                        if (!context.mounted) return;
                                        if (offer == null) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      '请开启“失败与完美主义”，并检查静默或安全退场状态。')));
                                          return;
                                        }
                                        await runtime.showOffer(context, offer,
                                            fullScreen: true);
                                      },
                                      child: const Text('从这句开始起草'))
                                ]),
                              ]))),
              ]))));
}
