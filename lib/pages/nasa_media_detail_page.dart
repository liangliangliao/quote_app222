import 'package:flutter/material.dart';
import '../services/nasa_api_service.dart';
import '../services/translation_service.dart';
import '../utils/image_downloader.dart';

/// Displays a single item from the NASA Image and Video Library.
///
/// We translate asynchronously inside the detail page to avoid blocking
/// navigation on tap.
class NasaMediaDetailPage extends StatefulWidget {
  const NasaMediaDetailPage({
    super.key,
    required this.item,
    this.translator,
    this.targetLang = 'en',
    this.translatedTitle,
    this.translatedDescription,
  });

  final NasaMediaItem item;
  final TranslationService? translator;
  final String targetLang;

  // Backward-compatible optional pre-translated strings.
  final String? translatedTitle;
  final String? translatedDescription;

  @override
  State<NasaMediaDetailPage> createState() => _NasaMediaDetailPageState();
}

class _NasaMediaDetailPageState extends State<NasaMediaDetailPage> {
  late String _title;
  late String _desc;
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
        : widget.item.title;
    _desc = (widget.translatedDescription?.trim().isNotEmpty ?? false)
        ? widget.translatedDescription!
        : (widget.item.description.isNotEmpty ? widget.item.description : '无描述');

    // Load cached translation if available (no network call).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCachedTranslation();
    });
  }

  Future<void> _loadCachedTranslation() async {
    if (widget.translator == null) return;
    if (widget.targetLang == 'en') return;
    final t = widget.targetLang;

    final rawDesc = widget.item.description.trim();
    final descInput = rawDesc.isEmpty ? '' : (rawDesc.length > 1800 ? rawDesc.substring(0, 1800) : rawDesc);

    final cachedTitle = await widget.translator!.getCachedTranslation(text: widget.item.title, target: t);
    final cachedDesc = descInput.isEmpty ? null : await widget.translator!.getCachedTranslation(text: descInput, target: t);

    if (!mounted) return;
    if ((cachedTitle == null || cachedTitle.trim().isEmpty) && (cachedDesc == null || cachedDesc.trim().isEmpty)) {
      return;
    }
    setState(() {
      if (cachedTitle != null && cachedTitle.trim().isNotEmpty) _title = cachedTitle;
      if (cachedDesc != null && cachedDesc.trim().isNotEmpty) _desc = cachedDesc;
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
      final title = await widget.translator!.translateOne(text: widget.item.title, target: t);

      final rawDesc = widget.item.description.trim();
      final descInput = rawDesc.isEmpty
          ? ''
          : (rawDesc.length > 1800 ? rawDesc.substring(0, 1800) : rawDesc);
      final desc = descInput.isEmpty
          ? '无描述'
          : await widget.translator!.translateOne(text: descInput, target: t);

      if (!mounted) return;
      final bool changed = title.trim() != widget.item.title.trim() ||
          (descInput.isNotEmpty && desc.trim() != descInput.trim());
      setState(() {
        _title = title;
        _desc = desc;
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
            if (widget.item.mediaUrl.isNotEmpty)
            GestureDetector(
                onLongPress: () => _promptDownload(widget.item.mediaUrl),
                child: Image.network(
                  widget.item.mediaUrl,
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
                  child: Icon(Icons.broken_image, size: 48),
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
                        widget.item.date,
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
                    _desc,
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
