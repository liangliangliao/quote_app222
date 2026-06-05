import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../widgets/health_diet_data_source_banner.dart';

class DietVoiceInputPage extends StatefulWidget {
  const DietVoiceInputPage({super.key});

  @override
  State<DietVoiceInputPage> createState() => _DietVoiceInputPageState();
}

class _VoiceSegment {
  _VoiceSegment({required this.text, required this.createdAt});

  String text;
  final DateTime createdAt;
}

class _DietVoiceInputPageState extends State<DietVoiceInputPage> {
  final _textCtrl = TextEditingController();
  final _textFocus = FocusNode();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _available = false;
  bool _listening = false;
  bool _initializing = true;
  bool _keepContinuousListening = false;
  bool _restarting = false;
  bool _manualEditMode = false;
  String _status = '准备语音识别中...';
  String _confirmedText = '';
  String _currentPartialText = '';
  Timer? _restartTimer;
  Timer? _elapsedTimer;
  Timer? _stablePartialTimer;
  Timer? _forceCommitTimer;
  int _elapsedSeconds = 0;
  int _roundIndex = 0;
  int _busyRetryCount = 0;
  int _transientErrorRetryCount = 0;
  bool _stopRequestedByApp = false;
  DateTime? _lastRoundStartedAt;
  DateTime? _lastPartialAt;
  String _lastErrorMsg = '';
  final List<_VoiceSegment> _segments = <_VoiceSegment>[];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _restartTimer?.cancel();
    _elapsedTimer?.cancel();
    _stablePartialTimer?.cancel();
    _forceCommitTimer?.cancel();
    _speech.stop();
    _textCtrl.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) {
        if (!mounted) return;
        setState(() {
          _available = false;
          _initializing = false;
          _status = '没有麦克风权限。你仍然可以手动输入语音转写内容。';
        });
        return;
      }
      final ok = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (error) {
          if (!mounted) return;
          _handleSpeechError(error.errorMsg, permanent: error.permanent);
        },
      );
      if (!mounted) return;
      setState(() {
        _available = ok;
        _initializing = false;
        _status = ok
            ? '点击开始“聊天式分段听写”。每停顿一句，系统会先保存这一句，再自动续听下一句。'
            : '当前设备语音识别不可用。你仍然可以手动输入。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _available = false;
        _initializing = false;
        _status = _friendlySpeechError(e);
      });
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    setState(() {
      _status = _statusText(status);
      _listening = _speech.isListening;
    });

    // Android 系统 SpeechRecognizer 不是长录音服务，经常在一句话后自动 done/notListening。
    // 这里采用聊天软件式“多条语音消息”策略：一句结束就保存为一段，然后自动开启下一段。
    if (_keepContinuousListening && (status == 'done' || status == 'notListening')) {
      _commitCurrentPartial(reason: 'status:$status');
      _syncDisplayedText();
      _scheduleRestart(delay: const Duration(milliseconds: 850));
    }
  }

  String _statusText(String raw) {
    if (_keepContinuousListening && (raw == 'done' || raw == 'notListening')) {
      return '上一句已保存，正在开启下一段；听到继续提示后再说下一句。';
    }
    if (raw == 'listening') return '正在听第 ${_roundIndex + 1} 段。说完一句停顿，系统会保存并自动续听下一段。';
    return '状态：$raw';
  }

  String _friendlySpeechError(Object error) {
    final text = error.toString();
    if (text.contains('recognizerNotAvailable') || text.contains('Speech recognition not available')) {
      return '当前系统没有可用的语音识别服务，或 Android 11+ 未发现系统识别服务。可安装/启用系统语音识别服务，或直接手动输入。';
    }
    return '语音识别初始化失败：$text。你仍然可以手动输入。';
  }

  Future<void> _retryInitSpeech() async {
    if (!mounted) return;
    setState(() {
      _initializing = true;
      _status = '正在重新检测系统语音识别服务...';
    });
    await _initSpeech();
  }

  void _focusManualInput() {
    _textFocus.requestFocus();
  }

  Future<void> _toggleListen() async {
    if (!_available || _initializing) return;
    try {
      if (_keepContinuousListening || _speech.isListening) {
        await _stopContinuousListening();
        return;
      }
      _manualEditMode = false;
      _keepContinuousListening = true;
      _elapsedSeconds = 0;
      _busyRetryCount = 0;
      _transientErrorRetryCount = 0;
      _lastErrorMsg = '';
      _confirmedText = _textCtrl.text.trim();
      _currentPartialText = '';
      if (_confirmedText.isNotEmpty && _segments.isEmpty) {
        _segments.add(_VoiceSegment(text: _confirmedText, createdAt: DateTime.now()));
      }
      await _startListenRound();
    } catch (e) {
      if (!mounted) return;
      final busy = _isBusyError(e.toString());
      setState(() {
        _available = busy ? _available : false;
        _listening = false;
        _keepContinuousListening = busy;
        _status = busy ? '系统语音服务正忙，已保存当前内容，正在自动重试；也可以直接手动编辑。' : _friendlySpeechError(e);
      });
      if (busy) _scheduleRestart(delay: const Duration(milliseconds: 1500));
    }
  }

  Future<void> _stopContinuousListening() async {
    _keepContinuousListening = false;
    _restartTimer?.cancel();
    _elapsedTimer?.cancel();
    _stablePartialTimer?.cancel();
    _forceCommitTimer?.cancel();
    _commitCurrentPartial(reason: 'manual_stop');
    _stopRequestedByApp = true;
    await _speech.stop();
    _stopRequestedByApp = false;
    if (!mounted) return;
    setState(() {
      _listening = false;
      _status = '已停止识别。已把每段听到的内容合并到输入框，你可以继续手动编辑后进入确认页。';
      _syncDisplayedText();
    });
  }

  Future<void> _startListenRound() async {
    if (!_available || _restarting || !_keepContinuousListening) return;
    _restarting = true;
    try {
      _restartTimer?.cancel();
      _stablePartialTimer?.cancel();
      _forceCommitTimer?.cancel();

      // Android SpeechRecognizer 经常在 error_client / error_busy 后仍处于“半占用”状态。
      // 启动下一轮前先温和 stop，并保证两轮之间至少间隔一小段时间。
      if (_speech.isListening) {
        _stopRequestedByApp = true;
        await _speech.stop();
        await Future<void>.delayed(const Duration(milliseconds: 320));
        _stopRequestedByApp = false;
      }
      final last = _lastRoundStartedAt;
      if (last != null) {
        final since = DateTime.now().difference(last);
        if (since < const Duration(milliseconds: 900)) {
          await Future<void>.delayed(const Duration(milliseconds: 900) - since);
        }
      }

      _roundIndex++;
      _currentPartialText = '';
      _lastRoundStartedAt = DateTime.now();
      _lastPartialAt = null;

      await _speech.listen(
        localeId: 'zh_CN',
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        // 不再把一轮拉得很长。国内 Android 的系统识别长听写容易 error_client / timeout。
        // 用“短句分段 + 自动续听”更接近聊天语音消息，也更稳定。
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(milliseconds: 1500),
        cancelOnError: false,
        onResult: (result) {
          if (!mounted) return;
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;
          _busyRetryCount = 0;
          _transientErrorRetryCount = 0;
          _lastPartialAt = DateTime.now();
          setState(() {
            _currentPartialText = words;
            _syncDisplayedText();
          });
          if (result.finalResult) {
            _stablePartialTimer?.cancel();
            _forceCommitTimer?.cancel();
            setState(() {
              _commitCurrentPartial(reason: 'final');
              _syncDisplayedText();
            });
            _restartCurrentRoundAfterCommit();
          } else {
            _scheduleStablePartialCommit();
            _scheduleForceCommit();
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _listening = true;
        _status = '正在听第 $_roundIndex 段。说一句停顿一下，系统会保存当前段并自动续听。';
        _startElapsedTimer();
      });
    } catch (e) {
      if (!mounted) return;
      _handleSpeechError(e.toString(), permanent: false);
    } finally {
      _restarting = false;
    }
  }

  void _scheduleStablePartialCommit() {
    // 若片段在一段时间内没有变化，主动把这一句收束成一条“语音消息”，
    // 然后 stop 当前系统识别并重启下一轮。继续在同一轮里听，很多国产 ROM 会丢后一句。
    _stablePartialTimer?.cancel();
    _stablePartialTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted || !_keepContinuousListening) return;
      final part = _currentPartialText.trim();
      if (part.isEmpty) return;
      final lastPartialAt = _lastPartialAt;
      if (lastPartialAt != null && DateTime.now().difference(lastPartialAt) < const Duration(milliseconds: 1200)) {
        _scheduleStablePartialCommit();
        return;
      }
      setState(() {
        _commitCurrentPartial(reason: 'stable_partial');
        _syncDisplayedText();
        _status = '已保存一段，正在续听下一段。';
      });
      _restartCurrentRoundAfterCommit();
    });
  }

  void _scheduleForceCommit() {
    // 防止系统一直不给 finalResult。4.5 秒仍有临时文本，就先保存、重启下一轮。
    _forceCommitTimer?.cancel();
    _forceCommitTimer = Timer(const Duration(milliseconds: 4500), () {
      if (!mounted || !_keepContinuousListening) return;
      final part = _currentPartialText.trim();
      if (part.isEmpty) return;
      setState(() {
        _commitCurrentPartial(reason: 'force');
        _syncDisplayedText();
        _status = '已保存当前听到的一段，正在续听下一段。';
      });
      _restartCurrentRoundAfterCommit();
    });
  }

  Future<void> _restartCurrentRoundAfterCommit() async {
    if (!_keepContinuousListening || !mounted) return;
    _stablePartialTimer?.cancel();
    _forceCommitTimer?.cancel();
    try {
      if (_speech.isListening) {
        _stopRequestedByApp = true;
        await _speech.stop();
        _stopRequestedByApp = false;
      }
    } catch (_) {
      _stopRequestedByApp = false;
    }
    _scheduleRestart(delay: const Duration(milliseconds: 650));
  }

  void _handleSpeechError(String msg, {required bool permanent}) {
    if (!mounted) return;
    final normalized = msg.toLowerCase();
    final busy = _isBusyError(msg);
    final transient = busy ||
        normalized.contains('timeout') ||
        normalized.contains('speech_timeout') ||
        normalized.contains('no_match') ||
        normalized.contains('error_client') ||
        normalized.contains('client');
    _lastErrorMsg = msg;
    _commitCurrentPartial(reason: 'error:$msg');
    _stopElapsedTimer();
    setState(() {
      _listening = false;
      _syncDisplayedText();
      _status = transient
          ? '语音识别短暂中断：$msg。已保存听到的内容，正在重新打开麦克风；也可以直接手动编辑。'
          : '语音识别错误：$msg。已保存已听到内容，可手动编辑。';
    });

    if (!_keepContinuousListening) return;
    if (transient && _transientErrorRetryCount < 8) {
      _transientErrorRetryCount++;
      if (busy) _busyRetryCount++;
      _scheduleRestart(
        delay: Duration(milliseconds: 900 + 350 * (_transientErrorRetryCount > 5 ? 5 : _transientErrorRetryCount)),
        forceStopBeforeStart: true,
      );
      return;
    }

    // 连续失败过多时，不再假装还能持续听；保留文本，让用户手动补充。
    _keepContinuousListening = false;
    _restartTimer?.cancel();
    if (mounted) {
      setState(() {
        _status = permanent
            ? '系统语音识别服务暂时不可用（$msg）。已保留本次内容，请手动补充或稍后重试。'
            : '连续多次识别中断，已停止自动续听。已保留本次内容，请手动补充或重新开始。';
      });
    }
  }

  void _scheduleRestart({Duration delay = const Duration(milliseconds: 850), bool forceStopBeforeStart = false}) {
    if (!_keepContinuousListening || _restarting || !mounted) return;
    _restartTimer?.cancel();
    _elapsedTimer?.cancel();
    _stablePartialTimer?.cancel();
    _forceCommitTimer?.cancel();
    _restartTimer = Timer(delay, () async {
      if (!_keepContinuousListening || !mounted) return;
      try {
        if (forceStopBeforeStart || _speech.isListening) {
          _stopRequestedByApp = true;
          try {
            await _speech.stop();
          } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 350));
          _stopRequestedByApp = false;
        }
        if (!_keepContinuousListening || !mounted) return;
        await _startListenRound();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _keepContinuousListening = false;
          _listening = false;
          _status = '系统语音服务暂时不可用。本次识别内容已保留，你可以手动编辑后进入确认页。';
          _stopElapsedTimer();
        });
      }
    });
  }

  void _commitCurrentPartial({String reason = ''}) {
    final part = _currentPartialText.trim();
    if (part.isEmpty) return;
    final normalizedPart = _normalizeSpeechText(part);
    if (normalizedPart.isEmpty) return;

    if (_segments.isEmpty && _confirmedText.trim().isNotEmpty) {
      _segments.add(_VoiceSegment(text: _confirmedText.trim(), createdAt: DateTime.now()));
    }

    final merged = _mergeSpeechText(_confirmedText, part);
    final normalizedMerged = _normalizeSpeechText(merged);
    final normalizedConfirmed = _normalizeSpeechText(_confirmedText);

    if (normalizedMerged != normalizedConfirmed) {
      _appendOrMergeSegment(part);
      _confirmedText = _segments.map((e) => e.text).where((e) => e.trim().isNotEmpty).join('，');
    }
    _currentPartialText = '';
  }

  void _appendOrMergeSegment(String text) {
    final part = text.trim();
    if (part.isEmpty) return;
    if (_segments.isEmpty) {
      _segments.add(_VoiceSegment(text: part, createdAt: DateTime.now()));
      return;
    }
    final last = _segments.last.text.trim();
    final mergedLast = _mergeSpeechText(last, part);
    final nLast = _normalizeSpeechText(last);
    final nPart = _normalizeSpeechText(part);
    final nMergedLast = _normalizeSpeechText(mergedLast);
    if (nLast.contains(nPart) || nPart.contains(nLast) || nMergedLast.length <= nLast.length + nPart.length - 2) {
      _segments.last.text = mergedLast;
    } else {
      _segments.add(_VoiceSegment(text: part, createdAt: DateTime.now()));
    }
  }

  void _syncDisplayedText() {
    final segmentText = _segments.map((e) => e.text.trim()).where((e) => e.isNotEmpty).join('，');
    final base = segmentText.isNotEmpty ? segmentText : _confirmedText;
    final full = _joinSpeechText(base, _currentPartialText).trim();
    if (_textCtrl.text != full) {
      _textCtrl.text = full;
      _textCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _textCtrl.text.length));
    }
  }

  String _joinSpeechText(String a, String b) => _mergeSpeechText(a, b);

  String _mergeSpeechText(String a, String b) {
    final left = a.trim();
    final right = b.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;
    final nl = _normalizeSpeechText(left);
    final nr = _normalizeSpeechText(right);
    if (nr.isEmpty) return left;
    if (nl.endsWith(nr) || nl.contains(nr)) return left;
    if (nr.contains(nl) && nr.length > nl.length) return right;
    var overlap = 0;
    final max = nl.length < nr.length ? nl.length : nr.length;
    for (var k = 1; k <= max; k++) {
      if (nl.endsWith(nr.substring(0, k))) overlap = k;
    }
    if (overlap >= 2 && overlap < right.length) {
      final tail = right.substring(overlap).trim();
      return tail.isEmpty ? left : '$left，$tail';
    }
    return '$left，$right';
  }

  String _normalizeSpeechText(String value) {
    return value.replaceAll(RegExp(r'[\s，,。.!！?？；;：:、]+'), '').trim();
  }

  bool _isBusyError(String msg) {
    final m = msg.toLowerCase();
    return m.contains('busy') || m.contains('error_busy') || m.contains('recognizer_busy');
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_keepContinuousListening) return;
      setState(() => _elapsedSeconds++);
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  void _appendExample(String text) {
    final current = _textCtrl.text.trim();
    final next = current.isEmpty ? text : '$current，$text';
    _textCtrl.text = next;
    _textCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _textCtrl.text.length));
    _confirmedText = next;
    _segments.clear();
    _segments.add(_VoiceSegment(text: next, createdAt: DateTime.now()));
  }

  void _removeSegment(int index) {
    if (index < 0 || index >= _segments.length) return;
    setState(() {
      _segments.removeAt(index);
      _confirmedText = _segments.map((e) => e.text).join('，');
      _currentPartialText = '';
      _syncDisplayedText();
    });
  }

  void _clearText() {
    setState(() {
      _textCtrl.clear();
      _segments.clear();
      _confirmedText = '';
      _currentPartialText = '';
      _elapsedSeconds = 0;
      _roundIndex = 0;
      _manualEditMode = false;
      _transientErrorRetryCount = 0;
      _lastErrorMsg = '';
      _status = '已清空。可以重新分段说，或直接手动输入。';
    });
  }

  void _finish() {
    _commitCurrentPartial(reason: 'finish');
    _syncDisplayedText();
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先说出或输入今天吃了什么')));
      return;
    }
    Navigator.of(context).pop(text);
  }

  Widget _voiceControlPanel() {
    final seconds = _elapsedSeconds;
    final time = '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Column(
      children: [
        GestureDetector(
          onTap: _available ? _toggleListen : null,
          onLongPressStart: _available && !_keepContinuousListening ? (_) => _toggleListen() : null,
          onLongPressEnd: _available && _keepContinuousListening ? (_) => _stopContinuousListening() : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: _keepContinuousListening ? 122 : 104,
            height: _keepContinuousListening ? 122 : 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _keepContinuousListening ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
              border: Border.all(color: _keepContinuousListening ? const Color(0xFF6366F1) : const Color(0xFFCBD5E1), width: 2.4),
              boxShadow: _keepContinuousListening ? const [BoxShadow(color: Color(0x336366F1), blurRadius: 22, spreadRadius: 3)] : const [],
            ),
            child: Icon(_keepContinuousListening ? Icons.stop_circle_outlined : Icons.mic_none, size: 50, color: const Color(0xFF4F46E5)),
          ),
        ),
        const SizedBox(height: 10),
        Text(_keepContinuousListening ? '聊天式分段听写 · $time' : '点击开始分段说饮食', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          _keepContinuousListening
              ? '像微信/聊天语音一样：说一句停一下，系统会保存一段并重开麦克风续听。若某句漏了，可继续补一句或手动编辑。'
              : '推荐按“早餐… / 中午… / 下午… / 晚上…”分段说；比一次说很长更稳定。',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
        ),
      ],
    );
  }

  Widget _quickExamples() {
    const examples = ['早餐两个包子一杯豆浆', '中午黄焖鸡米饭', '下午一杯奶茶', '晚上泡面加火腿肠'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: examples.map((e) => ActionChip(label: Text(e), onPressed: () => _appendExample(e))).toList(),
    );
  }

  Widget _segmentsPreview() {
    if (_segments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('已保存语音片段', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_segments.length, (index) {
            final text = _segments[index].text;
            return InputChip(
              label: Text('${index + 1}. $text'),
              onDeleted: () => _removeSegment(index),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('语音转文字记录')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          HealthDietDataSourceBanner(
            sources: const ['系统语音识别服务', '聊天式分段续听', '手动编辑', '后续全局 AI 饮食解析'],
            updatedAt: DateTime.now(),
            note: '系统语音识别对长句连续听写不稳定，本页改为“分段语音消息”设计：一句一存、自动续听、可删除片段，最终仍以你确认的文字为准。',
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Text(
              '推荐这样说：“早餐两个包子一杯豆浆。”停顿一下，再说：“中午黄焖鸡米饭。”系统会像聊天语音一样分段保存，避免只识别第一句或最后一句。',
              style: TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 18),
          _voiceControlPanel(),
          if (!_available && !_initializing) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: _retryInitSpeech, icon: const Icon(Icons.refresh), label: const Text('重新检测'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: _focusManualInput, icon: const Icon(Icons.edit_note), label: const Text('手动输入'))),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Center(child: Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, height: 1.4))),
          if (_lastErrorMsg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFDE68A))),
              child: const Text('提示：部分手机系统自带语音识别不支持长时间连续听写。系统会尽量自动续听；若仍漏字，建议一句一停，或直接在下方补文字。', style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.35)),
            ),
          ],
          const SizedBox(height: 12),
          _quickExamples(),
          const SizedBox(height: 14),
          _segmentsPreview(),
          if (_segments.isNotEmpty) const SizedBox(height: 14),
          TextField(
            controller: _textCtrl,
            focusNode: _textFocus,
            onChanged: (value) {
              _manualEditMode = true;
              _confirmedText = value.trim();
              _currentPartialText = '';
              _segments.clear();
              if (_confirmedText.isNotEmpty) {
                _segments.add(_VoiceSegment(text: _confirmedText, createdAt: DateTime.now()));
              }
            },
            minLines: 6,
            maxLines: 10,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: '语音转写结果 / 手动输入',
              hintText: '也可以直接在这里手动输入饮食描述',
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _clearText, icon: const Icon(Icons.delete_outline), label: const Text('清空重说'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(onPressed: _finish, icon: const Icon(Icons.fact_check_outlined), label: const Text('进入确认页'))),
          ]),
        ],
      ),
    );
  }
}
