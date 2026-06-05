import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/background_music_player.dart';
import '../services/open_music_service.dart';
import '../services/youtube_music_service.dart';
import 'settings_page.dart';

enum _MusicMode { youtube, open }

class GlobalMusicPage extends StatefulWidget {
  const GlobalMusicPage({super.key});

  @override
  State<GlobalMusicPage> createState() => _GlobalMusicPageState();
}

class _GlobalMusicPageState extends State<GlobalMusicPage> with WidgetsBindingObserver {
  final YoutubeMusicService _youtubeService = YoutubeMusicService();
  final OpenMusicService _openMusicService = OpenMusicService();
  final BackgroundMusicPlayer _backgroundPlayer = BackgroundMusicPlayer.instance;
  final TextEditingController _queryCtrl = TextEditingController();
  final FocusNode _queryFocus = FocusNode();

  _MusicMode _mode = _MusicMode.youtube;

  bool _loading = false;
  bool _checkingKey = true;
  bool _hasApiKey = false;
  bool _hasJamendoClientId = false;
  String? _error;

  YoutubeMusicTrack? _currentYoutube;
  WebViewController? _playerController;
  List<YoutubeMusicTrack> _youtubeTracks = <YoutubeMusicTrack>[];
  List<OpenMusicTrack> _openTracks = <OpenMusicTrack>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshKeyState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _queryCtrl.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // YouTube is only allowed through the visible official player. When the app
    // leaves the foreground, stop the embedded player. Open/licensed audio keeps
    // playing through BackgroundMusicPlayer.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopYoutubePlayer(updateUi: false);
    }
  }

  Future<void> _refreshKeyState() async {
    final youtubeOk = await _youtubeService.hasApiKey();
    final jamendoOk = (await _openMusicService.getJamendoClientId()).isNotEmpty;
    if (!mounted) return;
    setState(() {
      _hasApiKey = youtubeOk;
      _hasJamendoClientId = jamendoOk;
      _checkingKey = false;
    });
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const SettingsPage()),
    );
    await _refreshKeyState();
  }

  Future<void> _search([String? keyword]) async {
    final q = (keyword ?? _queryCtrl.text).trim();
    if (q.isEmpty) return;
    _queryCtrl.text = q;
    _queryFocus.unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });

    if (_mode == _MusicMode.youtube) {
      await _searchYoutube(q);
    } else {
      await _searchOpenMusic(q);
    }
  }

  Future<void> _searchYoutube(String q) async {
    try {
      final results = await _youtubeService.search(q, maxResults: 15);
      if (!mounted) return;
      setState(() {
        _youtubeTracks = results;
        _loading = false;
        if (results.isEmpty) {
          _error = '没有找到相关音乐视频，请换一个关键词试试';
        }
      });
    } on YoutubeMusicException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
      await _refreshKeyState();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '搜索失败：$e';
      });
    }
  }

  Future<void> _searchOpenMusic(String q) async {
    try {
      final results = await _openMusicService.search(q, maxResults: 15);
      if (!mounted) return;
      setState(() {
        _openTracks = results;
        _loading = false;
        if (results.isEmpty) {
          _error = '开放音乐源没有找到可播放音频，请换“民乐 / 古筝 / world music / classical”等关键词试试';
        }
      });
    } on OpenMusicException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '开放音乐搜索失败：$e';
      });
    }
  }

  Future<void> _playYoutube(YoutubeMusicTrack track) async {
    // YouTube embeds are increasingly unstable inside Android WebView and may
    // show 152-4/153 even for normal videos. Make the primary action use the
    // official YouTube app/browser instead of the embedded WebView.
    await _backgroundPlayer.pause();
    await _stopYoutubePlayer(updateUi: false);
    if (mounted) {
      setState(() {
        _currentYoutube = track;
        _error = null;
      });
    }
    final opened = await launchUrl(track.watchUri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() {
        _error = '无法打开 YouTube，请检查设备是否安装浏览器或 YouTube App';
      });
    }
  }

  Future<void> _previewYoutubeEmbedded(YoutubeMusicTrack track) async {
    await _backgroundPlayer.pause();
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            final host = uri.host.toLowerCase();
            final allowed = host == 'youtube.com' ||
                host == 'www.youtube.com' ||
                host == 'm.youtube.com' ||
                host == 'youtu.be' ||
                host == 'youtube-nocookie.com' ||
                host == 'www.youtube-nocookie.com' ||
                host.endsWith('.youtube.com') ||
                host.endsWith('.youtube-nocookie.com') ||
                host.endsWith('.google.com') ||
                host.endsWith('.googlevideo.com') ||
                host.endsWith('.ytimg.com') ||
                host.endsWith('.gstatic.com');
            return allowed ? NavigationDecision.navigate : NavigationDecision.prevent;
          },
        ),
      )
      ..loadHtmlString(_buildYoutubeEmbedHtml(track), baseUrl: 'https://www.youtube.com/');

    setState(() {
      _currentYoutube = track;
      _playerController = controller;
      _error = null;
    });
  }

  String _buildYoutubeEmbedHtml(YoutubeMusicTrack track) {
    final src = track.embedUri.toString();
    return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <style>
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: #000; overflow: hidden; }
    iframe { width: 100%; height: 100%; border: 0; }
  </style>
</head>
<body>
  <iframe
    src="$src"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
    allowfullscreen>
  </iframe>
</body>
</html>
''';
  }

  Future<void> _stopYoutubePlayer({bool updateUi = true}) async {
    final controller = _playerController;
    _playerController = null;
    _currentYoutube = null;
    try {
      await controller?.loadHtmlString('<html><body style="background:#000"></body></html>');
    } catch (_) {}
    if (updateUi && mounted) setState(() {});
  }

  Future<void> _playOpenTrack(OpenMusicTrack track) async {
    await _stopYoutubePlayer(updateUi: false);
    try {
      await _backgroundPlayer.playTrack(track);
      if (!mounted) return;
      setState(() {
        _mode = _MusicMode.open;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '播放失败：$e';
      });
    }
  }

  Future<void> _openInYouTube(YoutubeMusicTrack track) async {
    await launchUrl(track.watchUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openSource(OpenMusicTrack track) async {
    await launchUrl(track.sourceUri, mode: LaunchMode.externalApplication);
  }

  Widget _buildApiKeyNotice() {
    if (_mode != _MusicMode.youtube || _checkingKey || _hasApiKey) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD591)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.vpn_key_outlined, size: 20, color: Color(0xFFAD6800)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '需要先配置 YouTube Data API Key',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '进入设置页，点击左上角编辑按钮，在“YouTube Data API Key”处粘贴你申请好的 Google API Key，然后保存。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('去设置'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenMusicNotice() {
    if (_mode != _MusicMode.open) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FFED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB7EB8F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.headphones_outlined, color: Color(0xFF389E0D)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _hasJamendoClientId
                  ? '开放音乐源支持切后台继续播放、切后台继续播放。当前包含 Internet Archive 和 Jamendo。'
                  : '开放音乐源支持切后台继续播放。当前无需密钥即可搜索 Internet Archive；设置 Jamendo Client ID 后可增加独立音乐结果。',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          IconButton(
            tooltip: '设置 Jamendo',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitch() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<_MusicMode>(
        groupValue: _mode,
        children: const <_MusicMode, Widget>{
          _MusicMode.youtube: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('YouTube'),
          ),
          _MusicMode.open: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('开放音乐'),
          ),
        },
        onValueChanged: (value) {
          if (value == null || value == _mode) return;
          setState(() {
            _mode = value;
            _error = null;
          });
          if (value == _MusicMode.open) {
            _stopYoutubePlayer(updateUi: false);
          }
        },
      ),
    );
  }

  Widget _buildPlayer() {
    if (_mode == _MusicMode.open) return _buildOpenAudioPlayer();
    return _buildYoutubePlayer();
  }

  Widget _buildYoutubePlayer() {
    final current = _currentYoutube;
    final controller = _playerController;
    if (current == null) {
      return Container(
        height: 190,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_video_outlined, size: 38, color: Colors.black45),
            SizedBox(height: 8),
            Text('搜索后点击“打开播放”，将使用 YouTube 官方 App / 浏览器'),
            SizedBox(height: 4),
            Text('YouTube 源不支持后台播放', style: TextStyle(fontSize: 12, color: Colors.black45)),
          ],
        ),
      );
    }

    if (controller == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: current.thumbnailUrl.isEmpty
                  ? Container(
                      width: 92,
                      height: 64,
                      color: Colors.black12,
                      child: const Icon(Icons.music_video_outlined),
                    )
                  : Image.network(
                      current.thumbnailUrl,
                      width: 92,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 92,
                        height: 64,
                        color: Colors.black12,
                        child: const Icon(Icons.music_video_outlined),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    current.channelTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _openInYouTube(current),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('在 YouTube 播放'),
                      ),
                      TextButton(
                        onPressed: () => _previewYoutubeEmbedded(current),
                        child: const Text('内嵌试播'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: WebViewWidget(controller: controller),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    current.channelTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _openInYouTube(current),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('YouTube'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOpenAudioPlayer() {
    final current = _backgroundPlayer.currentTrack;
    if (current == null) {
      return Container(
        height: 168,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.album_outlined, size: 38, color: Colors.black45),
            SizedBox(height: 8),
            Text('搜索开放音乐后点击“后台播放”'),
            SizedBox(height: 4),
            Text('支持切后台继续播放', style: TextStyle(fontSize: 12, color: Colors.black45)),
          ],
        ),
      );
    }

    return StreamBuilder<PlayerState>(
      stream: _backgroundPlayer.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = (state ?? _backgroundPlayer.player.state) == PlayerState.playing;
        const loading = false;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: current.thumbnailUrl.isEmpty
                        ? Container(
                            width: 74,
                            height: 74,
                            color: Colors.black12,
                            child: const Icon(Icons.music_note),
                          )
                        : Image.network(
                            current.thumbnailUrl,
                            width: 74,
                            height: 74,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 74,
                              height: 74,
                              color: Colors.black12,
                              child: const Icon(Icons.music_note),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          current.creator,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          current.providerName,
                          style: const TextStyle(color: Colors.black45, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildProgressBar(),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: loading
                        ? null
                        : () async {
                            if (playing) {
                              await _backgroundPlayer.pause();
                            } else {
                              await _backgroundPlayer.resume();
                            }
                          },
                    icon: loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(playing ? Icons.pause : Icons.play_arrow, size: 18),
                    label: Text(playing ? '暂停' : '继续'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _openSource(current),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('来源'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      await _backgroundPlayer.stop();
                      if (mounted) setState(() {});
                    },
                    child: const Text('停止'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressBar() {
    return StreamBuilder<Duration?>(
      stream: _backgroundPlayer.durationStream.map((d) => d as Duration?),
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: _backgroundPlayer.positionStream,
          builder: (context, positionSnapshot) {
            final rawPosition = positionSnapshot.data ?? Duration.zero;
            final position = duration > Duration.zero && rawPosition > duration ? duration : rawPosition;
            final max = duration.inMilliseconds <= 0 ? 1.0 : duration.inMilliseconds.toDouble();
            final value = position.inMilliseconds.clamp(0, max.toInt()).toDouble();
            return Column(
              children: [
                Slider(
                  value: value,
                  max: max,
                  onChanged: duration.inMilliseconds <= 0
                      ? null
                      : (v) => _backgroundPlayer.seek(Duration(milliseconds: v.round())),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmtDuration(position), style: const TextStyle(fontSize: 11, color: Colors.black45)),
                    Text(duration == Duration.zero ? '--:--' : _fmtDuration(duration), style: const TextStyle(fontSize: 11, color: Colors.black45)),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _fmtDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = d.inHours;
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _queryCtrl,
            focusNode: _queryFocus,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: _mode == _MusicMode.youtube ? '搜索歌曲、歌手、MV、现场版…' : '搜索开放音乐：民乐、古典、world music…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _loading ? null : () => _search(),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('搜索'),
        ),
      ],
    );
  }

  Widget _buildQuickSearchChips() {
    final keywords = _mode == _MusicMode.youtube
        ? const <String>['周杰伦 晴天', 'Taylor Swift', 'lofi music', '古典音乐', '世界音乐']
        : const <String>['中国民乐', '古筝', 'Chinese folk music', 'world music', 'classical piano'];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: keywords
          .map(
            (k) => ActionChip(
              label: Text(k),
              onPressed: _loading ? null : () => _search(k),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildYoutubeTrackTile(YoutubeMusicTrack track) {
    final selected = _currentYoutube?.videoId == track.videoId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE6F4FF) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(14),
        border: selected ? Border.all(color: const Color(0xFF91CAFF)) : null,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: track.thumbnailUrl.isEmpty
                ? Container(
                    width: 96,
                    height: 64,
                    color: Colors.black12,
                    child: const Icon(Icons.music_note),
                  )
                : Image.network(
                    track.thumbnailUrl,
                    width: 96,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 96,
                      height: 64,
                      color: Colors.black12,
                      child: const Icon(Icons.music_note),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  track.channelTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _playYoutube(track),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('打开播放'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _previewYoutubeEmbedded(track),
                      child: const Text('内嵌试播'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenTrackTile(OpenMusicTrack track) {
    final selected = _backgroundPlayer.currentTrack?.audioUrl == track.audioUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE6F4FF) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(14),
        border: selected ? Border.all(color: const Color(0xFF91CAFF)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: track.thumbnailUrl.isEmpty
                ? Container(
                    width: 82,
                    height: 82,
                    color: Colors.black12,
                    child: const Icon(Icons.music_note),
                  )
                : Image.network(
                    track.thumbnailUrl,
                    width: 82,
                    height: 82,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 82,
                      height: 82,
                      color: Colors.black12,
                      child: const Icon(Icons.music_note),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6FFFB),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFF87E8DE)),
                      ),
                      child: const Text('后台', style: TextStyle(fontSize: 10, color: Color(0xFF006D75))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  track.creator,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  track.providerName,
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
                if (track.shortDescription.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    track.shortDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _playOpenTrack(track),
                      icon: const Icon(Icons.headphones, size: 18),
                      label: const Text('后台播放'),
                    ),
                    TextButton(
                      onPressed: () => _openSource(track),
                      child: const Text('来源'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeDescription() {
    final text = _mode == _MusicMode.youtube
        ? 'YouTube 默认使用官方 App / 浏览器播放，避免 Android WebView 常见的 152-4 / 153 内嵌错误。应用不会解析、下载、缓存或分离音频；YouTube 源不支持后台播放。'
        : '开放音乐来自 Internet Archive / Jamendo 等可公开流式播放源，用系统音频播放器播放，支持切后台继续播放。请按来源页面的授权说明使用音乐。';
    return Text(text, style: const TextStyle(fontSize: 12, color: Colors.black54));
  }

  List<Widget> _buildResults() {
    if (_mode == _MusicMode.youtube) {
      return <Widget>[
        if (_youtubeTracks.isNotEmpty)
          const Text('搜索结果', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ..._youtubeTracks.map(_buildYoutubeTrackTile),
      ];
    }
    return <Widget>[
      if (_openTracks.isNotEmpty)
        const Text('开放音乐结果', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      ..._openTracks.map(_buildOpenTrackTile),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('全球音乐搜索'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'API Key 设置',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshKeyState,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _buildModeSwitch(),
              const SizedBox(height: 12),
              _buildApiKeyNotice(),
              _buildOpenMusicNotice(),
              _buildPlayer(),
              const SizedBox(height: 16),
              _buildSearchBar(),
              const SizedBox(height: 10),
              _buildQuickSearchChips(),
              const SizedBox(height: 12),
              _buildModeDescription(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCCC7)),
                  ),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFA8071A))),
                ),
              ],
              const SizedBox(height: 16),
              ..._buildResults(),
            ],
          ),
        ),
      ),
    );
  }
}
