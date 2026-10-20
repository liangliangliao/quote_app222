import 'dart:io';

import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../ai_assistant/ai_assistant_media_service.dart';
import 'quote_frame_theme.dart';
import 'quote_visual_script_service.dart';

/// AI 配画仅通过显式用户操作或用户开启的自动模式触发，避免静默 API 扣费。
/// 每条名言只保存一幅背景，用户主动“重新生成”才会覆盖它。
class QuoteFrameAiService {
  QuoteFrameAiService({
    AiAssistantMediaService? mediaService,
    QuoteVisualScriptService? visualScriptService,
  }) : _mediaService = mediaService ?? AiAssistantMediaService(),
       _visualScripts = visualScriptService ?? QuoteVisualScriptService();

  final AiAssistantMediaService _mediaService;
  final QuoteVisualScriptService _visualScripts;

  Future<QuoteVisualScript?> readCachedScript(String topic, String quote) =>
      _visualScripts.readCached(topic: topic, quote: quote);

  String cacheKey(String topic, String quote) =>
      sha256.convert(utf8.encode('v3-visual-thesis-20261020|${topic.trim()}|${quote.trim()}')).toString();

  Future<Directory> _framesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'quote_semantic_frames'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _targetFile(String topic, String quote) async {
    final dir = await _framesDir();
    return File(p.join(dir.path, '${cacheKey(topic, quote)}.png'));
  }

  Future<String?> findCached(String topic, String quote) async {
    if (quote.trim().isEmpty) return null;
    final target = await _targetFile(topic, quote);
    for (final ext in const ['.png', '.jpg', '.jpeg', '.webp']) {
      final f = File(p.join(target.parent.path, '${cacheKey(topic,quote)}$ext'));
      if (await f.exists() && await f.length() > 0) return f.path;
    }
    return null;
  }

  Future<bool> get autoEnabled async {
    final dir = await _framesDir();
    final flag = File(p.join(dir.path, 'auto_enabled.txt'));
    return await flag.exists() && (await flag.readAsString()).trim() == 'true';
  }

  Future<void> setAutoEnabled(bool enabled) async {
    final dir = await _framesDir();
    await File(p.join(dir.path, 'auto_enabled.txt')).writeAsString(enabled.toString(), flush: true);
  }

  Future<String> generate({
    required String topic,
    required String quote,
    required QuoteFrameTheme theme,
    String note = '',
    bool force = false,
  }) async {
    if (quote.trim().isEmpty) throw StateError('名言为空，无法生成画框');
    final target = await _targetFile(topic, quote);
    if (!force) {
      final existing = await findCached(topic, quote);
      if (existing != null) return existing;
    }
    // 先提炼“原句命题 → 可见关系 → 决定性瞬间”，再生成框内配画。
    // 原句仍会直接交给图片模型作最终语义校验；中文由 Flutter 独立渲染。
    final script = await _visualScripts.create(
      topic: topic,
      quote: quote,
      note: note,
      theme: theme,
      force: force,
    );
    // 文字 AI 与绘图 AI 可以是不同服务：文字模型未配置/解析失败时，
    // 仍把原文直接交给文生图模型，要求它按原句作具体视觉转译。
    // 这不会伪称“文字 AI 已理解”；缓存脚本仍记录 isThemeOnly。
    final prompt = script.imagePrompt(
      quoteCharacters: quote.runes.length,
      originalQuote: quote,
      topic: topic,
      note: note,
    );
    final generated = await _mediaService.generateImage(prompt);
    final source = File(generated.path);
    if (!await source.exists() || await source.length() == 0) {
      throw StateError('图像接口未返回有效图片');
    }
    // 生成器可能返回 JPEG/WebP，保留真实扩展名以便 Flutter Image.file 解码。
    final extension = p.extension(source.path).toLowerCase();
    final actualExt = const ['.png','.jpg','.jpeg','.webp'].contains(extension) ? extension : '.png';
    final actualTarget = File(p.join(target.parent.path, '${cacheKey(topic,quote)}$actualExt'));
    for (final ext in const ['.png', '.jpg', '.jpeg', '.webp']) {
      final old = File(p.join(target.parent.path, '${cacheKey(topic,quote)}$ext'));
      if (await old.exists()) await old.delete();
    }
    await source.copy(actualTarget.path);
    return actualTarget.path;
  }
}
