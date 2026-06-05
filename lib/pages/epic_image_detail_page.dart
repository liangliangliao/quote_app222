import 'package:flutter/material.dart';
import '../services/nasa_api_service.dart';
import '../services/translation_service.dart';
import '../utils/image_downloader.dart';

/// Displays a single EPIC (Earth Polychromatic Imaging Camera) image.
///
/// Per performance requirements:
/// - Entering the detail page does NOT translate.
/// - Translation is only triggered when the user taps the translate icon.
/// - If the current unified AI provider is not configured or invalid, keep the original text.
class EpicImageDetailPage extends StatefulWidget {
  const EpicImageDetailPage({
    super.key,
    required this.image,
    this.translator,
    this.targetLang = 'en',
  });

  final EpicImage image;
  final TranslationService? translator;
  final String targetLang;

  @override
  State<EpicImageDetailPage> createState() => _EpicImageDetailPageState();
}

class _EpicImageDetailPageState extends State<EpicImageDetailPage> {
  late String _caption;
  bool _translating = false;
  bool _translationFailed = false;
  bool _translated = false;

  Future<void> _promptDownload(String url) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('下载并保存到系统相册'),
                subtitle: const Text('下载完成后，可在相册/图库中查看'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  _showSnack('开始下载…');
                  try {
                    final saved = await ImageDownloader.saveImageToGallery(url);
                    _showSnack('已保存到相册: $saved');
                  } catch (e) {
                    _showSnack('下载/保存失败: $e');
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _caption = widget.image.caption.isNotEmpty ? widget.image.caption : '无描述';

    // Load cached translation (no network call) so that re-entering the page
    // shows previously translated text.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCachedTranslation();
    });
  }

  Future<void> _loadCachedTranslation() async {
    if (widget.translator == null) return;
    if (widget.targetLang == 'en') return;
    final raw = widget.image.caption.trim();
    if (raw.isEmpty) return;
    final cached = await widget.translator!.getCachedTranslation(text: raw, target: widget.targetLang);
    if (!mounted) return;
    if (cached == null || cached.trim().isEmpty) return;
    setState(() {
      _caption = cached;
      _translated = true;
      _translationFailed = false;
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _translateAsync() async {
    setState(() {
      _translating = true;
      _translationFailed = false;
      _translated = false;
    });
    try {
      final raw = widget.image.caption.trim();
      if (raw.isEmpty) {
        if (!mounted) return;
        setState(() {
          _caption = '无描述';
          _translating = false;
          _translationFailed = false;
          _translated = false;
        });
        return;
      }

      final out = await widget.translator!.translateOne(text: raw, target: widget.targetLang);
      if (!mounted) return;
      final bool changed = out.trim() != raw.trim();
      setState(() {
        _caption = out;
        _translating = false;
        _translationFailed = !changed;
        _translated = changed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _translating = false;
        _translationFailed = true;
        _translated = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showTranslateHint = widget.targetLang != 'en' && widget.translator != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EPIC 图像', style: TextStyle(color: Colors.black87)),
        actions: [
          IconButton(
            onPressed: _translating
                ? null
                : () async {
                    if (widget.translator == null) {
                      _showSnack('未配置全局 AI，无法翻译');
                      return;
                    }
                    if (widget.targetLang == 'en') {
                      _showSnack('目标语言为英文，无需翻译');
                      return;
                    }
                    await _translateAsync();
                    if (_translationFailed) {
                      _showSnack('当前全局 AI 无效或翻译失败，已保持原文');
                    }
                  },
            tooltip: '翻译',
            icon: const Icon(Icons.translate, color: Colors.black87),
          ),
        ],
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onLongPress: () => _promptDownload(widget.image.url),
              child: Image.network(
                widget.image.url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              (loadingProgress.expectedTotalBytes ?? 1)
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: Icon(Icons.broken_image)),
                );
              },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.image.date,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _caption,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  if (showTranslateHint && (_translating || _translationFailed || _translated)) ...[
                    const SizedBox(height: 8),
                    if (_translating)
                      Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '翻译中…',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      )
                    else if (_translationFailed)
                      Text(
                        '翻译失败，已显示原文',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      )
                    else if (_translated)
                      Text(
                        '已翻译',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
