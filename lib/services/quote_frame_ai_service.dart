import 'dart:io';

import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../ai_assistant/ai_assistant_media_service.dart';
import 'quote_frame_theme.dart';

/// AI 配画仅通过显式用户操作或用户开启的自动模式触发，避免静默 API 扣费。
/// 每条名言只保存一幅背景，用户主动“重新生成”才会覆盖它。
class QuoteFrameAiService {
  QuoteFrameAiService({AiAssistantMediaService? mediaService})
      : _mediaService = mediaService ?? AiAssistantMediaService();

  final AiAssistantMediaService _mediaService;

  String cacheKey(String topic, String quote) =>
      sha256.convert(utf8.encode('${topic.trim()}|盘|${quote.trim()}')).toString();

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
    return await target.exists() && await target.length() > 0 ? target.path : null;
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
    bool force = false,
  }) async {
    if (quote.trim().isEmpty) throw StateError('名言为空，无法生成画框');
    final target = await _targetFile(topic, quote);
    if (!force && await target.exists() && await target.length() > 0) return target.path;
    // 不让 AI 写名言，中文由 Flutter 原生绘制，确保字形及出处正确。
    final cleanedTopic = topic.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    final cleanedQuote = quote.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    final prompt = '''
Create an exquisite VERTICAL 2:3 background artwork for a framed Chinese quotation poster.
Visual concept: ${theme.imageScene}
Topic (semantic reference only): ${cleanedTopic.length > 100 ? cleanedTopic.substring(0,100) : cleanedTopic}
Quotation meaning (semantic reference only): ${cleanedQuote.length > 260 ? cleanedQuote.substring(0,260) : cleanedQuote}
Mood: ${theme.label}. Build the scene from the meaning and emotional tone, not generic decoration.
Art style: elegant contemporary ink-wash illustration combined with fine-art watercolor,
subtle natural pigments and tactile handmade paper, refined gallery quality.
Layout: keep the TOP 70% exceptionally light and uncluttered for legible overlaid
Chinese text and a small author portrait. Put distinctive subject/details mainly in
the BOTTOM 30%, with delicate motifs near the corners only.
A narrow margin should remain free of focal objects for a wooden mat/frame.
The image must contain ABSOLUTELY NO writing, letters, Chinese characters,
typography, watermarks, logos, borders, poster mockups, frames, or text.
''';
    final generated = await _mediaService.generateImage(prompt);
    final source = File(generated.path);
    if (!await source.exists() || await source.length() == 0) {
      throw StateError('图像接口未返回有效图片');
    }
    // 生成器可能返回 JPEG/WebP，保留真实扩展名以便 Flutter Image.file 解码。
    final extension = p.extension(source.path).toLowerCase();
    final actualExt = const ['.png','.jpg','.jpeg','.webp'].contains(extension) ? extension : '.png';
    final actualTarget = File(p.join(target.parent.path, '${cacheKey(topic,quote)}$actualExt'));
    if (await actualTarget.exists()) await actualTarget.delete();
    await source.copy(actualTarget.path);
    return actualTarget.path;
  }
}
