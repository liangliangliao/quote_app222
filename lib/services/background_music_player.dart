import 'package:audioplayers/audioplayers.dart';

import 'open_music_service.dart';

/// Audio player for open/licensed music streams.
///
/// YouTube playback is intentionally separated from this player. YouTube must
/// remain inside the official visible player and is not used for background
/// audio. This class uses the app's existing `audioplayers` dependency to avoid
/// introducing extra native plugins that broke Android release compilation in CI.
class BackgroundMusicPlayer {
  BackgroundMusicPlayer._();

  static final BackgroundMusicPlayer instance = BackgroundMusicPlayer._();

  final AudioPlayer player = AudioPlayer();
  OpenMusicTrack? currentTrack;

  Stream<PlayerState> get playerStateStream => player.onPlayerStateChanged;
  Stream<Duration> get positionStream => player.onPositionChanged;
  Stream<Duration> get durationStream => player.onDurationChanged;

  bool get isPlaying => player.state == PlayerState.playing;

  Future<void> playTrack(OpenMusicTrack track) async {
    currentTrack = track;
    await player.stop();
    await player.setReleaseMode(ReleaseMode.stop);
    await player.play(UrlSource(track.audioUrl));
  }

  Future<void> resume() => player.resume();
  Future<void> pause() => player.pause();

  Future<void> stop() async {
    await player.stop();
    currentTrack = null;
  }

  Future<void> seek(Duration position) => player.seek(position);
}
