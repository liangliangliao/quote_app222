import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'artwork.dart';
import 'artwork_canvas.dart';
import 'region_geometry.dart';

typedef OpenInteractionPage = Future<void> Function(TouchAction action);

class InteractionPlayer extends StatefulWidget {
  const InteractionPlayer({
    super.key,
    required this.artwork,
    required this.file,
    required this.regions,
    required this.settings,
    required this.openPage,
    this.trial,
  });

  final Artwork artwork;
  final File file;
  final List<ImageRegion> regions;
  final FeedbackSettings settings;
  final OpenInteractionPage openPage;
  final (ImageRegion, TouchAction)? trial;

  @override
  State<InteractionPlayer> createState() => _InteractionPlayerState();
}

class _InteractionPlayerState extends State<InteractionPlayer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _transform = TransformationController();
  final _pointers = <int>{};
  late final _animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 530));
  static const _holdTime = Duration(milliseconds: 500);
  AudioPlayer? _audio;
  Timer? _hold;
  int? _primary;
  Offset? _start;
  Offset? _imageStart;
  Duration? _downAt;
  bool _sliding = false;
  bool _longPressed = false;
  bool _paused = false;
  bool _showRegions = false;
  bool _moving = false;
  bool _navigating = false;
  bool _pulse = false;
  ImageRegion? _feedback;
  Future<void> _audioQueue = Future.value();
  int _audioRevision = 0;

  bool get _canInteract => !_paused && !_moving && !_navigating;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final trial = widget.trial;
    if (trial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play(trial.$1, trial.$2);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _cancelInteraction();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hold?.cancel();
    _audioRevision++;
    final player = _audio;
    if (player != null)
      unawaited(
          _audioQueue.then((_) => player.dispose()).catchError((Object _) {}));
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _onDown(PointerEvent event, ArtworkCoordinates coordinates) {
    _pointers.add(event.pointer);
    if (_pointers.length > 1) {
      _clearGesture();
      _stopFeedback();
      return;
    }
    if (!_canInteract) return;
    final point = coordinates.pointAt(event.localPosition);
    if (point == null) return;
    _primary = event.pointer;
    _start = event.localPosition;
    _downAt = event.timeStamp;
    _imageStart = point;
    final region = hitRegion(widget.regions, point, gesture: TouchGesture.hold);
    if (region != null) {
      _hold = Timer(_holdTime, () {
        _longPressed = true;
        _play(region, region.rules[TouchGesture.hold]!);
      });
    }
  }

  void _onMove(PointerEvent event, ArtworkCoordinates coordinates) {
    if (event.pointer != _primary) return;
    if (coordinates.pointAt(event.localPosition) == null) {
      _clearGesture();
      _stopFeedback();
      return;
    }
    if ((event.localPosition - _start!).distance >= 18) {
      _hold?.cancel();
      _sliding = true;
    }
  }

  void _onUp(PointerEvent event, ArtworkCoordinates coordinates) {
    _pointers.remove(event.pointer);
    if (event.pointer != _primary) return;
    final start = _imageStart!;
    final gesture = _sliding ? TouchGesture.swipe : TouchGesture.tap;
    final trigger = !_longPressed &&
        (_sliding || event.timeStamp - _downAt! < _holdTime) &&
        coordinates.pointAt(event.localPosition) != null;
    _clearGesture();
    if (trigger) {
      final region = hitRegion(widget.regions, start, gesture: gesture);
      if (region != null) _play(region, region.rules[gesture]!);
    }
  }

  void _clearGesture() {
    _hold?.cancel();
    _primary = null;
    _start = null;
    _imageStart = null;
    _downAt = null;
    _sliding = false;
    _longPressed = false;
  }

  void _cancelInteraction() {
    _pointers.clear();
    _clearGesture();
    _stopFeedback();
  }

  void _stopFeedback() {
    _audioRevision++;
    _animation.value = 1;
    final player = _audio;
    if (player != null) {
      _audioQueue =
          _audioQueue.then((_) => player.stop()).catchError((Object _) {});
    }
  }

  void _play(ImageRegion region, TouchAction action) {
    if (!_canInteract) return;
    final settings = widget.settings;
    switch (action) {
      case TouchAction.highlight:
      case TouchAction.pulse:
        if (!settings.visual) return;
        setState(() {
          _feedback = region;
          _pulse = action == TouchAction.pulse &&
              !MediaQuery.disableAnimationsOf(context);
        });
        _animation.forward(from: 0);
      case TouchAction.sound:
        if (!settings.sound) return;
        final revision = ++_audioRevision;
        _audioQueue = _audioQueue.then((_) async {
          if (!mounted || revision != _audioRevision) return;
          final player = _audio ??= AudioPlayer();
          await player.stop();
          if (!mounted || revision != _audioRevision) return;
          await player.play(
            AssetSource('interactive_image/touch.wav'),
            volume: 0.45,
            ctx: const AudioContext(
                android:
                    AudioContextAndroid(audioFocus: AndroidAudioFocus.none)),
          );
        }).catchError((Object _) {});
      case TouchAction.vibration:
        if (settings.vibration) {
          unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
        }
      case TouchAction.learning:
      case TouchAction.books:
        _cancelInteraction();
        setState(() => _navigating = true);
        unawaited(_openPage(action));
    }
  }

  Future<void> _openPage(TouchAction action) async {
    try {
      await widget.openPage(action);
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRules = widget.regions
        .any((region) => region.enabled && region.rules.isNotEmpty);
    return Scaffold(
      backgroundColor: const Color(0xFF131621),
      appBar: AppBar(
        title: Text(widget.trial == null ? '交互预览' : '试播反馈'),
        actions: [
          IconButton(
            tooltip: _paused ? '恢复互动' : '暂停互动',
            onPressed: () {
              _cancelInteraction();
              setState(() => _paused = !_paused);
            },
            icon:
                Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: '画布选项',
            onSelected: (choice) {
              _cancelInteraction();
              setState(() {
                switch (choice) {
                  case 'regions':
                    _showRegions = !_showRegions;
                  case 'pan':
                    _moving = !_moving;
                  case 'reset':
                    _transform.value = Matrix4.identity();
                }
              });
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                  value: 'regions',
                  checked: _showRegions,
                  child: const Text('显示区域')),
              CheckedPopupMenuItem(
                  value: 'pan', checked: _moving, child: const Text('单指移动画布')),
              const PopupMenuItem(value: 'reset', child: Text('重置缩放')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ArtworkCanvas(
                file: widget.file,
                aspectRatio: widget.artwork.aspectRatio,
                transform: _transform,
                panEnabled: _moving,
                regions: _showRegions ? widget.regions : const [],
                feedback: _feedback,
                pulse: _pulse,
                animation: _animation,
                onDown: _onDown,
                onMove: _onMove,
                onUp: _onUp,
                onCancel: _cancelInteraction,
              ),
            ),
            if (_paused || _moving || !hasRules)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _paused
                      ? '互动已暂停'
                      : _moving
                          ? '单指移动已开启 · 请从画布选项恢复互动'
                          : '还没有启用的手势。返回编辑区为区域绑定反馈。',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
