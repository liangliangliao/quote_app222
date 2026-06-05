import 'package:flutter/material.dart';
import '../services/nasa_api_service.dart';
import '../services/translation_service.dart';
import '../utils/image_downloader.dart';

/// Detail page for a single APOD item.
///
/// Notes:
/// - We translate asynchronously (non-blocking) to avoid the "tap -> wait" lag.
/// - If translation fails, we fall back to the original English text.
class ApodDetailPage extends StatefulWidget {
  const ApodDetailPage({
    super.key,
    required this.apod,
    this.translator,
    this.targetLang = 'en',
    this.translatedTitle,
    this.translatedExplanation,
  });

  final Apod apod;
  final TranslationService? translator;
  final String targetLang;

  // Backward-compatible optional pre-translated strings.
  final String? translatedTitle;
  final String? translatedExplanation;

  @override
  State<ApodDetailPage> createState() => _ApodDetailPageState();
}

class _ApodDetailPageState extends State<ApodDetailPage> {
  late String _title;
  late String _explanation;
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
    _title = (widget.translatedTitle?.trim().isNotEmpty ?? false)
        ? widget.translatedTitle!
        : widget.apod.title;
    _explanation = (widget.translatedExplanation?.trim().isNotEmpty ?? false)
        ? widget.translatedExplanation!
        : widget.apod.explanation;

    // Load cached translation if available. This does NOT call the current unified AI provider.
    // It only reads from the local cache and helps the page remember the
    // translated text when the user re-enters.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCachedTranslation();
    });
  }

  Future<void> _loadCachedTranslation() async {
    if (widget.translator == null) return;
    if (widget.targetLang == 'en') return;
    final t = widget.targetLang;

    final rawExp = widget.apod.explanation;
    final expInput = rawExp.length > 2000 ? rawExp.substring(0, 2000) : rawExp;

    final cachedTitle = await widget.translator!.getCachedTranslation(text: widget.apod.title, target: t);
    final cachedExp = await widget.translator!.getCachedTranslation(text: expInput, target: t);

    if (!mounted) return;
    if ((cachedTitle == null || cachedTitle.trim().isEmpty) && (cachedExp == null || cachedExp.trim().isEmpty)) {
      return;
    }
    setState(() {
      if (cachedTitle != null && cachedTitle.trim().isNotEmpty) _title = cachedTitle;
      if (cachedExp != null && cachedExp.trim().isNotEmpty) _explanation = cachedExp;
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
      final t = widget.targetLang;
      final title = await widget.translator!.translateOne(text: widget.apod.title, target: t);

      // Explanations can be long; keep it within a reasonable size for free endpoints.
      final rawExp = widget.apod.explanation;
      final expInput = rawExp.length > 2000 ? rawExp.substring(0, 2000) : rawExp;
      final exp = await widget.translator!.translateOne(text: expInput, target: t);

      if (!mounted) return;
      final bool changed = title.trim() != widget.apod.title.trim() || exp.trim() != expInput.trim();
      setState(() {
        _title = title;
        _explanation = exp;
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
    final imageUrl = widget.apod.hdUrl ?? widget.apod.url;
    final showTranslateHint = widget.targetLang != 'en' && widget.translator != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          IconButton(
            onPressed: (_translating)
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
                    // If translation did not change content, treat as "not translated".
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
            if (widget.apod.mediaType == 'image')
              GestureDetector(
                onLongPress: () => _promptDownload(imageUrl),
                child: Image.network(
                  imageUrl,
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
              )
            else
              const SizedBox(
                height: 200,
                child: Center(
                  child: Icon(Icons.videocam_outlined, size: 48),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        widget.apod.date,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (showTranslateHint && (_translating || _translationFailed || _translated)) ...[
                        const SizedBox(width: 10),
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
                  const SizedBox(height: 16),
                  Text(
                    _explanation,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
