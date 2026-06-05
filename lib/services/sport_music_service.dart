import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';

/// Global background music service for sport running.
/// It is intentionally decoupled from page lifecycle so music can continue
/// when user leaves SportRunningPage and returns later.
class SportMusicService {
  SportMusicService._();
  static final SportMusicService instance = SportMusicService._();

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _completeSub;

  List<String> _playlist = <String>[];
  String _mode = 'order'; // order / random
  int _index = 0;
  bool _started = false;
  bool _paused = false;
  bool _pendingRestartOnResume = false;
  final Random _rand = Random();

  // Track the currently playing file path so we can attempt to preserve it when
  // the playlist is updated.  Null when no song is playing.
  String? _currentPath;


final StreamController<void> _changeCtl = StreamController<void>.broadcast();
Stream<void> get onChanged => _changeCtl.stream;
void _notifyChanged() { try { _changeCtl.add(null); } catch (_) {} }

  /// Apply playlist/mode updates dynamically from Settings.  This method
  /// attempts to preserve the currently playing track if it still exists in
  /// the new playlist.  It will **not** automatically start playback if
  /// nothing is currently playing.  When playing, it updates the current
  /// index and restarts the track if necessary.
  Future<void> applySettings({List<String>? playlist, String? mode}) async {
    // Remember the current file path so we can attempt to align indices.
    final String? currentPath = _currentPath;

    // Detect playlist changes. Distinguish between content changes and order-only changes
    // so we don't restart playback unnecessarily (better performance & battery).
    bool contentChanged = false;

    if (playlist != null) {
      final newList = List<String>.from(playlist);
      if (!_listEquals(_playlist, newList)) {
        // Content changed if the set of items differs OR lengths differ (covers duplicates).
        final oldSet = _playlist.toSet();
        final newSet = newList.toSet();
        contentChanged = (_playlist.length != newList.length) || (oldSet.length != newSet.length) || !oldSet.containsAll(newSet) || !newSet.containsAll(oldSet);
      }
      _playlist = newList;
    }

    if (mode != null) {
      _mode = (mode == 'random') ? 'random' : 'order';
    }

    // Empty playlist: stop immediately.
    if (_playlist.isEmpty) {
      await stop();
      _notifyChanged();
      return;
    }

    // Align current index to the current playing path when possible.
    if (currentPath != null) {
      final newIdx = _playlist.indexOf(currentPath);
      if (newIdx >= 0) {
        _index = newIdx;
      } else {
        // Current track removed from playlist.
        _index = 0;
        if (_started) {
          if (_paused) {
            // Defer restart until resume so we don't auto-play while workout is paused.
            _pendingRestartOnResume = true;
          } else {
            // Need to restart to a valid track.
            await _playAt(_index);
          }
        }
        _notifyChanged();
        return;
      }
    } else if (_index >= _playlist.length) {
      _index = 0;
    }

    if (_started) {
      // Only restart when playlist content changes in a way that invalidates the current track.
      // Order-only changes should not restart (preserve progress).
      if (contentChanged && currentPath == null) {
        // No current track information; safest is to restart.
        if (_paused) {
          _pendingRestartOnResume = true;
        } else {
          await _playAt(_index);
        }
      }
      // If only order changed, we already adjusted _index to currentPath; no restart.
    }

    _notifyChanged();
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }



  Future<void> configure({required List<String> playlist, required String mode}) async {
    _playlist = List<String>.from(playlist);
    _mode = (mode == 'random') ? 'random' : 'order';
    // Setup completion callback once.
    _completeSub ??= _player.onPlayerComplete.listen((_) {
      // ignore: discarded_futures
      playNext();
    });
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
    } catch (_) {}
  }

  bool get isStarted => _started;
  String? get currentPath => _currentPath;

  Future<void> startIfNeeded() async {
    if (_playlist.isEmpty) return;

    if (_started) {
      // If we deferred a restart while paused (playlist changed), apply it on resume.
      if (_pendingRestartOnResume) {
        _pendingRestartOnResume = false;
        _paused = false;
        await _playAt(_index);
        return;
      }
      // Only resume when we are actually paused; otherwise do nothing.
      if (_paused) {
        try {
          await _player.resume();
        } catch (_) {}
        _paused = false;
      }
      return;
    }

    _started = true;
    _paused = false;
    if (_mode == 'random') {
      _index = _rand.nextInt(_playlist.length);
    } else {
      _index = 0;
    }
    await _playAt(_index);
  }

  Future<void> playAt(int idx) async {
    if (_playlist.isEmpty) return;
    _started = true;
    _index = idx.clamp(0, _playlist.length - 1);
    await _playAt(_index);
  }

  Future<void> playNext() async {
    if (!_started) return;
    if (_playlist.isEmpty) return;
    if (_playlist.length == 1) {
      await _playAt(0);
      return;
    }
    int next = _index;
    if (_mode == 'random') {
      next = _rand.nextInt(_playlist.length);
      if (next == _index) next = (next + 1) % _playlist.length;
    } else {
      next = (_index + 1) % _playlist.length;
    }
    _index = next;
    await _playAt(_index);
  }

  Future<void> pause() async {
    _paused = true;
    try {
      await _player.pause();
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    _started = false;
    _paused = false;
    _pendingRestartOnResume = false;
    _currentPath = null;
    _notifyChanged();
  }

  Future<void> _playAt(int idx) async {
    if (_playlist.isEmpty) return;
    final p = _playlist[idx];
    if (p.trim().isEmpty) return;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      // Keep track of the currently playing path.
      _currentPath = p;
      _paused = false;
      await _player.play(DeviceFileSource(p));
      _notifyChanged();
    } catch (_) {}
  }
}
