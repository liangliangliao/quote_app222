import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'artwork.dart';
import 'artwork_canvas.dart';
import 'effort_meter.dart';
import 'feedback_platform.dart';
import 'region_geometry.dart';
import 'touch_effort.dart' show TouchEffort;

typedef OpenInteractionPage = Future<void> Function(TouchAction action);

class InteractionPlayer extends StatefulWidget {
  const InteractionPlayer({
    super.key,
    required this.artwork,
    required this.file,
    required this.regions,
    required this.settings,
    required this.openPage,
    this.fallback,
    this.trial,
  });

  final Artwork artwork;
  final File file;
  final File? fallback;
  final List<ImageRegion> regions;
  final FeedbackSettings settings;
  final OpenInteractionPage openPage;
  final (ImageRegion, List<FeedbackStep>)? trial;

  @override
  State<InteractionPlayer> createState() => _InteractionPlayerState();
}

class _InteractionPlayerState extends State<InteractionPlayer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _platform = FeedbackPlatform();
  static const _holdIntentTime = Duration(milliseconds: 240);
  static const _swipeSlop = 18.0;
  static const _minimumSwipeStep = 2.0;
  static const _unlockTime = Duration(milliseconds: 180);
  final _transform = TransformationController();
  final _pointers = <int>{};
  late final _animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 530));
  late final _effort = TouchEffort(widget.settings.effortDifficulty, this);
  late final _wake = WakePhraseMatcher(widget.settings.wakePhrase);
  late final _commands = _voiceCommands();
  AudioPlayer? _audio;
  Completer<void>? _run;
  Completer<void>? _externalReturn;
  StreamSubscription<dynamic>? _voiceEvents;
  Future<void> _voiceQueue = Future.value();
  Timer? _wakeTimer;
  Timer? _holdIntent;
  int? _primary;
  Offset? _start;
  Offset? _imageStart;
  Offset? _lastSwipePosition;
  ImageRegion? _tapRegion;
  ImageRegion? _swipeRegion;
  Duration? _downAt;
  bool _sliding = false;
  bool _holding = false;
  bool _paused = false;
  bool _showRegions = false;
  bool _moving = false;
  bool _pulse = false;
  bool _voiceEnabled = false;
  bool _voiceStarted = false;
  bool _foreground = true;
  bool _outside = false;
  bool _appPage = false;
  bool _nativeMedia = false;
  ImageRegion? _feedback;
  String? _notice;

  bool get _canInteract => _foreground && !_paused && !_moving && _run == null;

  Map<String, (ImageRegion, List<FeedbackStep>)> _voiceCommands() {
    final regions = widget.regions.where((region) => region.enabled).toList()
      ..sort((a, b) {
        final order = b.priority.compareTo(a.priority);
        return order != 0
            ? order
            : polygonArea(a.polygon).compareTo(polygonArea(b.polygon));
      });
    final commands = <String, (ImageRegion, List<FeedbackStep>)>{};
    for (final region in regions) {
      for (final rule in region.voiceRules) {
        if (rule.steps.isNotEmpty)
          commands.putIfAbsent(
              normalizeCommand(rule.phrase), () => (region, rule.steps));
      }
    }
    return commands;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_immersion(true));
      final trial = widget.trial;
      if (trial != null) unawaited(_runChain(trial.$1, trial.$2));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      if (_outside) {
        _outside = false;
        final waiting = _externalReturn;
        if (waiting != null && !waiting.isCompleted) waiting.complete();
      }
      if (!_appPage) unawaited(_immersion(true));
    } else {
      _clearPointers();
      if (_externalReturn != null) {
        _outside = true;
      } else if (state != AppLifecycleState.inactive) {
        _cancelRun();
      }
    }
    unawaited(_syncVoice());
  }

  Future<void> _immersion(bool enabled) =>
      _platform.setImmersive(enabled).catchError((Object _) {});

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wakeTimer?.cancel();
    _clearPointers();
    _cancelRun();
    _voiceEnabled = false;
    unawaited(_voiceQueue
        .then((_) => _platform.stopVoice())
        .catchError((Object _) {}));
    unawaited(_voiceEvents?.cancel());
    final audio = _audio;
    if (audio != null) unawaited(audio.dispose().catchError((Object _) {}));
    unawaited(_immersion(false));
    _animation.dispose();
    _effort.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _onDown(PointerEvent event, ArtworkCoordinates coordinates) {
    _pointers.add(event.pointer);
    if (_pointers.length > 1) {
      _clearGesture();
      _effort.reset();
      _cancelRun();
      return;
    }
    if (!_canInteract) return;
    final point = coordinates.pointAt(event.localPosition);
    if (point == null) {
      _effort.reset();
      return;
    }
    _primary = event.pointer;
    _start = event.localPosition;
    _downAt = event.timeStamp;
    _imageStart = point;
    _tapRegion = hitRegion(widget.regions, point, gesture: TouchGesture.tap);
    _effort.beginPointer(_tapRegion?.id);
    final region = hitRegion(widget.regions, point, gesture: TouchGesture.hold);
    if (region != null) {
      _holdIntent = Timer(_holdIntentTime, () {
        if (!_canInteract || _primary != event.pointer) return;
        _holding = true;
        _effort.hold(
            _holdIntentTime, () => _completeTouch(region, TouchGesture.hold));
      });
    }
  }

  void _onMove(PointerEvent event, ArtworkCoordinates coordinates) {
    if (event.pointer != _primary) return;
    final position = event.localPosition;
    if (coordinates.pointAt(position) == null) {
      _clearGesture();
      _effort.reset();
      return;
    }
    if (!_sliding) {
      if ((position - _start!).distance < _swipeSlop) return;
      _holdIntent?.cancel();
      _effort.reset();
      _sliding = true;
      _lastSwipePosition = _start;
      _swipeRegion =
          hitRegion(widget.regions, _imageStart!, gesture: TouchGesture.swipe);
    }
    final region = _swipeRegion;
    if (region == null) return;
    final distance = (position - _lastSwipePosition!).distance;
    if (distance < _minimumSwipeStep) return;
    _lastSwipePosition = position;
    if (_effort.swipe(distance)) _completeTouch(region, TouchGesture.swipe);
  }

  void _onUp(PointerEvent event, ArtworkCoordinates coordinates) {
    _pointers.remove(event.pointer);
    if (event.pointer != _primary) return;
    final tap = _tapRegion;
    final isQuickTap = !_sliding &&
        !_holding &&
        event.timeStamp - _downAt! < _holdIntentTime &&
        (event.localPosition - _start!).distance < _swipeSlop &&
        coordinates.pointAt(event.localPosition) != null;
    _clearGesture();
    if (!_canInteract || tap == null || !isQuickTap) {
      _effort.reset();
      return;
    }
    if (_effort.tap(tap.id)) _completeTouch(tap, TouchGesture.tap);
  }

  void _completeTouch(ImageRegion region, TouchGesture gesture) {
    _clearGesture();
    if (!_canInteract) {
      _effort.reset();
      return;
    }
    unawaited(_runChain(region, region.rules[gesture]!, fromTouch: true));
  }

  void _clearGesture() {
    _holdIntent?.cancel();
    _primary = null;
    _start = null;
    _imageStart = null;
    _lastSwipePosition = null;
    _tapRegion = null;
    _swipeRegion = null;
    _downAt = null;
    _sliding = false;
    _holding = false;
  }

  void _clearPointers() {
    _pointers.clear();
    _clearGesture();
    _effort.reset();
  }

  void _cancelRun() {
    final run = _run;
    if (run != null && !run.isCompleted) run.complete();
    _animation.value = 1;
    final player = _audio;
    if (player != null) unawaited(player.stop().catchError((Object _) {}));
    if (_nativeMedia)
      unawaited(_platform.stopMedia().catchError((Object _) {}));
  }

  Future<void> _runChain(ImageRegion region, List<FeedbackStep> steps,
      {bool fromTouch = false}) async {
    if (!_canInteract || steps.isEmpty) return;
    if (!fromTouch) _clearPointers();
    final run = Completer<void>();
    setState(() {
      _run = run;
      _notice = null;
    });
    _wake.reset();
    await _syncVoice();
    try {
      if (fromTouch) {
        await Future.any([run.future, Future<void>.delayed(_unlockTime)]);
        if (!_foreground) return;
      }
      for (final step in steps) {
        if (!mounted || run.isCompleted) break;
        try {
          if (!await _execute(region, step, run)) break;
        } on TickerCanceled {
          break;
        } on PlatformException catch (error) {
          if (!run.isCompleted) _showNotice(_errorText(error.code));
        } on MissingPluginException {
          if (!run.isCompleted) _showNotice('当前平台暂不支持此反馈。');
        } catch (_) {
          if (!run.isCompleted) _showNotice('此反馈暂时无法执行。');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _run = null);
        unawaited(_syncVoice());
      }
    }
  }

  Future<bool> _execute(
      ImageRegion region, FeedbackStep step, Completer<void> run) async {
    final settings = widget.settings;
    switch (step.action) {
      case TouchAction.highlight:
      case TouchAction.pulse:
        if (!settings.visual) break;
        setState(() {
          _feedback = region;
          _pulse = step.action == TouchAction.pulse &&
              !MediaQuery.disableAnimationsOf(context);
        });
        await _animation.forward(from: 0).orCancel;
      case TouchAction.sound:
        if (settings.sound) await _playCue(run);
      case TouchAction.vibration:
        if (settings.vibration) await HapticFeedback.lightImpact();
      case TouchAction.learning:
      case TouchAction.books:
        _appPage = true;
        try {
          await _immersion(false);
          if (!run.isCompleted) await widget.openPage(step.action);
        } finally {
          _appPage = false;
          if (mounted && _foreground) await _immersion(true);
        }
      case TouchAction.link:
        final uri = feedbackLink(step.value ?? '');
        if (uri == null) throw PlatformException(code: 'invalid_link');
        await _launchOutside(() => _platform.openLink(uri), run);
      case TouchAction.app:
        await _launchOutside(() => _platform.openApp(step), run);
      case TouchAction.video:
      case TouchAction.audio:
      case TouchAction.systemSound:
      case TouchAction.speak:
        final video = step.action == TouchAction.video;
        if (video ? !settings.visual : !settings.sound) break;
        _nativeMedia = true;
        try {
          return await _platform.playMedia(widget.artwork.id, step,
              muted: !settings.sound);
        } finally {
          _nativeMedia = false;
          if (mounted && _foreground && video) await _immersion(true);
        }
    }
    return true;
  }

  Future<void> _playCue(Completer<void> run) async {
    final player = _audio ??= AudioPlayer();
    final ended = Completer<void>();
    final sub = player.onPlayerComplete.listen((_) {
      if (!ended.isCompleted) ended.complete();
    });
    try {
      if (run.isCompleted) return;
      await player.play(AssetSource('interactive_image/touch.wav'),
          volume: 0.45,
          ctx: const AudioContext(
              android:
                  AudioContextAndroid(audioFocus: AndroidAudioFocus.none)));
      if (run.isCompleted) await player.stop();
      await Future.any([
        ended.future,
        run.future,
        Future<void>.delayed(const Duration(seconds: 3))
      ]);
    } finally {
      await sub.cancel();
    }
  }

  Future<void> _launchOutside(
      Future<void> Function() launch, Completer<void> run) async {
    final returned = Completer<void>();
    _externalReturn = returned;
    try {
      await launch();
      // Wait briefly for Android to switch activities, then resume the chain on return.
      await Future.any([
        returned.future,
        run.future,
        Future<void>.delayed(const Duration(milliseconds: 450))
      ]);
      if (_outside) await Future.any([returned.future, run.future]);
    } finally {
      _externalReturn = null;
      _outside = false;
    }
  }

  Future<void> _toggleVoice() async {
    if (_voiceEnabled) {
      setState(() {
        _voiceEnabled = false;
        _notice = null;
      });
      await _syncVoice();
      return;
    }
    if (!Platform.isAndroid) {
      _showNotice('语音操作目前支持 Android。');
      return;
    }
    final permission = await Permission.microphone.request();
    if (!mounted) return;
    if (!permission.isGranted) {
      _showNotice('请允许麦克风访问后使用语音操作。');
      return;
    }
    _voiceEvents ??= _platform.voiceEvents.listen(_handleVoiceEvent,
        onError: (Object error) => _voiceFailed('speech_unavailable'));
    setState(() {
      _voiceEnabled = true;
      _notice = null;
    });
    await _syncVoice();
  }

  Future<void> _syncVoice() {
    if (!_voiceEnabled && !_voiceStarted) return _voiceQueue;
    _voiceQueue = _voiceQueue.then((_) async {
      final listen = mounted && _voiceEnabled && _canInteract;
      if (listen == _voiceStarted) return;
      _voiceStarted = listen;
      if (listen) {
        await _platform.startVoice(
            allowSystemSpeech: widget.settings.allowSystemSpeech);
      } else {
        _wake.reset();
        _wakeTimer?.cancel();
        await _platform.stopVoice();
      }
    }).catchError((Object error) {
      if (mounted)
        _voiceFailed(
            error is PlatformException ? error.code : 'speech_unavailable');
    });
    return _voiceQueue;
  }

  void _handleVoiceEvent(Object? event) {
    if (event is! Map ||
        !mounted ||
        !_voiceEnabled ||
        !_voiceStarted ||
        !_canInteract) return;
    if (event['kind'] == 'error') {
      _voiceFailed(event['code'] as String? ?? 'speech_unavailable');
    } else if (event['kind'] == 'result') {
      final words = (event['words'] as List? ?? const []).whereType<String>();
      final now = DateTime.now();
      final command = _wake.commandFor(words, now, _commands.keys.toSet());
      final feedback = _commands[command];
      if (feedback != null) {
        unawaited(_runChain(feedback.$1, feedback.$2));
      } else if (_wake.armedAt(now)) {
        _wakeTimer?.cancel();
        setState(() => _notice = null);
        _wakeTimer = Timer(_wake.window, () {
          if (mounted) setState(() {});
        });
      }
    }
  }

  void _voiceFailed(String code) {
    if (!mounted) return;
    _wake.reset();
    _wakeTimer?.cancel();
    setState(() {
      _voiceEnabled = false;
      _voiceStarted = false;
      _notice = _errorText(code);
    });
    unawaited(_platform.stopVoice().catchError((Object _) {}));
  }

  void _showNotice(String text) {
    if (mounted) setState(() => _notice = text);
  }

  String _errorText(String code) => switch (code) {
        'offline_unavailable' ||
        'language_unavailable' =>
          '本机语音识别不可用。可在交互设置中启用系统语音识别。',
        'speech_busy' => '麦克风正被占用，请稍后重试。',
        'speech_unavailable' => '语音识别服务不可用。',
        'microphone_denied' => '语音操作需要麦克风权限。',
        'app_missing' => '找不到该应用，请核对名称或安装应用。',
        'app_ambiguous' => '存在多个同名应用，请在编辑器中指定一个。',
        'browser_missing' => '找不到能打开该链接的浏览器。',
        'media_play_failed' => '设备无法播放该媒体。',
        'tts_unavailable' => '设备暂时无法离线朗读。',
        _ => '此反馈暂时无法执行，请检查设置。',
      };

  @override
  Widget build(BuildContext context) {
    final hasRules = widget.regions.any(
        (r) => r.enabled && (r.rules.isNotEmpty || r.voiceRules.isNotEmpty));
    final showEffort = widget.trial == null &&
        !_paused &&
        !_moving &&
        widget.regions
            .any((region) => region.enabled && region.rules.isNotEmpty);
    final hint = _notice ??
        (_paused
            ? '互动已暂停'
            : _moving
                ? '单指移动画布已开启'
                : _voiceEnabled && _run == null
                    ? (_wake.armedAt(DateTime.now())
                        ? '已唤醒，请说口令'
                        : '请说「${widget.settings.wakePhrase}」再说口令')
                    : !hasRules && widget.trial == null
                        ? '返回编辑器，为区域设置手势或语音反馈。'
                        : null);
    final screen = Scaffold(
      backgroundColor: const Color(0xFF131621),
      body: Stack(fit: StackFit.expand, children: [
        ArtworkCanvas(
            file: widget.file,
            fallbackFile: widget.fallback,
            original: true,
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
            onCancel: () {
              _clearPointers();
              _cancelRun();
            }),
        Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
                bottom: false,
                minimum: const EdgeInsets.all(8),
                child: Material(
                    color: const Color(0xB5212435),
                    borderRadius: BorderRadius.circular(25),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          tooltip: '退出预览',
                          color: Colors.white,
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).maybePop()),
                      IconButton(
                          tooltip: _paused ? '恢复互动' : '暂停互动',
                          color: Colors.white,
                          icon: Icon(_paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded),
                          onPressed: () {
                            _clearPointers();
                            _cancelRun();
                            setState(() => _paused = !_paused);
                            unawaited(_syncVoice());
                          }),
                      if (widget.trial == null && _commands.isNotEmpty)
                        IconButton(
                            tooltip: _voiceEnabled ? '关闭语音操作' : '开启语音操作',
                            color: Colors.white,
                            isSelected: _voiceEnabled,
                            selectedIcon: const Icon(Icons.mic),
                            icon: const Icon(Icons.mic_off_outlined),
                            onPressed: _toggleVoice),
                      PopupMenuButton<String>(
                          tooltip: '画布选项',
                          icon:
                              const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (choice) {
                            _clearPointers();
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
                            unawaited(_syncVoice());
                          },
                          itemBuilder: (_) => [
                                CheckedPopupMenuItem(
                                    value: 'regions',
                                    checked: _showRegions,
                                    child: const Text('显示区域')),
                                CheckedPopupMenuItem(
                                    value: 'pan',
                                    checked: _moving,
                                    child: const Text('单指移动画布')),
                                const PopupMenuItem(
                                    value: 'reset', child: Text('重置缩放')),
                              ]),
                    ])))),
        if (hint != null || showEffort)
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.all(12),
              child: IgnorePointer(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (hint != null)
                  Semantics(
                      liveRegion: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: const Color(0xBD212435),
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            child: Text(hint,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white))),
                      )),
                if (hint != null && showEffort) const SizedBox(height: 8),
                if (showEffort) EffortMeter(effort: _effort),
              ])),
            ),
          ),
      ]),
    );
    return PopScope<void>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _clearPointers();
          _cancelRun();
        }
      },
      child: screen,
    );
  }
}
