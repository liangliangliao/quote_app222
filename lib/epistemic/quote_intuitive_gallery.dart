import 'dart:io';
import 'package:flutter/material.dart';
import '../services/quote_frame_ai_service.dart';
import '../services/quote_frame_theme.dart';

/// Reads existing artwork without an API call. Generation is an explicit action
/// and uses the app's configured image provider, not an unrelated stock scene.
class QuoteIntuitiveGallery extends StatefulWidget {
  final String topic, quote, note;
  final String? imagePath;
  final QuoteFrameAiService? service;
  final VoidCallback? onGenerated;
  const QuoteIntuitiveGallery({
    super.key,
    required this.topic,
    required this.quote,
    this.note = '',
    this.imagePath,
    this.service,
    this.onGenerated,
  });
  @override
  State<QuoteIntuitiveGallery> createState() => _QuoteIntuitiveGalleryState();
}

class _QuoteIntuitiveGalleryState extends State<QuoteIntuitiveGallery> {
  late final _service = widget.service ?? QuoteFrameAiService();
  String? _path, _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(QuoteIntuitiveGallery old) {
    super.didUpdateWidget(old);
    if (old.topic != widget.topic ||
        old.quote != widget.quote ||
        old.imagePath != widget.imagePath) _load();
  }

  Future<void> _load() async {
    final quote = widget.quote, topic = widget.topic;
    String? path = widget.imagePath;
    try {
      if (path == null || !await File(path).exists()) {
        path = await _service.findCached(topic, quote);
      }
    } catch (_) {
      path = null;
    }
    if (mounted && widget.quote == quote && widget.topic == topic)
      setState(() => _path = path);
  }

  Future<void> _generate({bool force = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final path = await _service.generate(
        topic: widget.topic,
        quote: widget.quote,
        note: widget.note,
        force: force,
        theme: QuoteFrameTheme.resolve(
          topic: widget.topic,
          quote: widget.quote,
          note: widget.note,
        ),
      );
      if (mounted) {
        setState(() => _path = path);
        widget.onGenerated?.call();
      }
    } catch (_) {
      if (mounted) setState(() => _error = '配画暂未生成，请检查设置中的图片模型后重试。原句和例子仍可阅读。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('quote-intuitive-gallery'),
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          color: const Color(0xfff7f0e4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffe5d9c5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_path != null)
              InkWell(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => Dialog(
                    child: Stack(
                      children: [
                        InteractiveViewer(
                          child: Image.file(
                            File(_path!),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('图片暂不可读'),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            tooltip: '关闭配画',
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                child: Semantics(
                  label: '名言的视觉类比，轻触放大',
                  button: true,
                  child: Image.file(
                    File(_path!),
                    height: 240,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('缓存配画暂不可读，可重新检查图片设置。'),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.landscape_outlined, color: Color(0xff956d35)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '直观表象 · 具体场景',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _path == null
                        ? '把原句中的动作、关系与情境转为可看的画面，再回到概念中核对。'
                        : '先看发生了什么，再辨认画面保留了原句的哪些关系。',
                    style: const TextStyle(height: 1.6),
                  ),
                  const SizedBox(height: 8),
                  if (_busy)
                    const LinearProgressIndicator()
                  else if (_path == null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const ValueKey('generate-intuitive-art'),
                        onPressed: _generate,
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('为这句名言配画'),
                      ),
                    ),
                  if (_path == null)
                    const Text(
                      '点击后使用已配置的图片 AI，可能产生接口费用。',
                      style: TextStyle(fontSize: 12, color: Color(0xff746b5d)),
                    ),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(height: 1.5)),
                  if (_path != null && !_busy)
                    Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                            onPressed: () => _generate(force: true),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('重新配画（使用图片 AI）'))),
                  if (_path != null)
                    const Text(
                      'AI 视觉类比 · 不是事件证据，也不穷尽概念含义。',
                      style: TextStyle(fontSize: 12, color: Color(0xff746b5d)),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}
