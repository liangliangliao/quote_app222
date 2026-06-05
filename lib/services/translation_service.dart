import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../data/dao.dart';
import 'global_ai_settings.dart';
import 'unified_ai_service.dart';

/// Translation helper for the Space module.
///
/// It now follows the unified global AI provider/model setting.
/// If the selected provider is unavailable, it returns the original text.
class TranslationService {
  TranslationService();

  final LogDao _logDao = LogDao();
  final TranslationCacheDao _translationCacheDao = TranslationCacheDao();
  final GlobalAiSettings _globalAiSettings = GlobalAiSettings();
  final UnifiedAiService _unifiedAiService = UnifiedAiService();

  final Map<String, String> _cache = <String, String>{};

  static const int _longTextThreshold = 800;
  static const int _chunkMaxLen = 650;

  String? _provider;
  String? _model;
  bool _loaded = false;

  void clearCache() => _cache.clear();

  Future<void> _ensureConfig() async {
    if (_loaded && (_provider ?? '').isNotEmpty && (_model ?? '').isNotEmpty) return;
    try {
      final state = await _globalAiSettings.getState();
      _provider = (state['provider'] ?? 'deepseek').trim();
      _model = (state['model'] ?? '').trim();
    } catch (_) {
      _provider = 'deepseek';
      _model = 'deepseek-reasoner';
    }
    _loaded = true;
  }

  Future<String?> getCachedTranslation({required String text, required String target}) async {
    if (target == 'en' || text.trim().isEmpty) return null;
    final memKey = '$target|$text';
    final mem = _cache[memKey];
    if (mem != null && mem.trim().isNotEmpty && mem.trim() != text.trim()) {
      return mem;
    }

    await _ensureConfig();
    final cacheKey = _hashKey(model: '${_provider ?? 'deepseek'}:${_model ?? 'deepseek-reasoner'}', target: target, sourceText: text);
    try {
      final dbCached = await _translationCacheDao.getTranslatedText(cacheKey);
      if (dbCached != null && dbCached.trim().isNotEmpty && dbCached.trim() != text.trim()) {
        _cache[memKey] = dbCached;
        return dbCached;
      }
    } catch (_) {}
    return null;
  }

  List<String> _splitTextIntoChunks(String text) {
    if (text.length <= _chunkMaxLen) return <String>[text];
    final chunks = <String>[];
    String buf = '';

    void flush() {
      if (buf.isEmpty) return;
      chunks.add(buf);
      buf = '';
    }

    final lines = text.split(RegExp(r'\n+'));
    for (final line in lines) {
      if (line.isEmpty) {
        if (buf.length + 1 > _chunkMaxLen) flush();
        buf += '\n';
        continue;
      }
      if (line.length > _chunkMaxLen) {
        final parts = line.split(RegExp(r'(?<=[。！？.!?；;])'));
        for (final p in parts) {
          if (p.trim().isEmpty) continue;
          if (buf.length + p.length > _chunkMaxLen) flush();
          buf += p;
        }
        if (buf.length + 1 > _chunkMaxLen) flush();
        buf += '\n';
        continue;
      }
      if (buf.length + line.length + 1 > _chunkMaxLen) flush();
      buf += line;
      buf += '\n';
    }
    flush();
    return chunks;
  }

  String _languageName(String target) {
    switch (target) {
      case 'zh':
        return 'Chinese';
      case 'ja':
        return 'Japanese';
      case 'ko':
        return 'Korean';
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'ru':
        return 'Russian';
      case 'ar':
        return 'Arabic';
      case 'pt':
        return 'Portuguese';
      default:
        return target;
    }
  }

  Future<String?> _translateChunkOnce({required String chunk, required String target, required int attempt}) async {
    await _ensureConfig();
    final provider = _provider ?? 'deepseek';
    final model = _model ?? 'deepseek-reasoner';
    final prompt = 'Translate the following text into ${_languageName(target)}. Return only the translation without explanation:\n$chunk';
    final translated = await _unifiedAiService.generateText(
      prompt: prompt,
      purpose: 'translation.attempt_$attempt',
      systemPrompt: 'You are a precise translation assistant. Return only the translated text.',
      maxTokens: chunk.length > 1200 ? 2200 : 1200,
      expectJson: false,
      forcedProvider: provider,
      forcedModel: model,
      temperature: 0,
    );
    final value = translated.trim();
    return value.isEmpty ? null : value;
  }

  Future<String> _translateViaUnified({required String text, required String target}) async {
    await _ensureConfig();
    final provider = _provider ?? 'deepseek';
    final model = _model ?? 'deepseek-reasoner';

    final resolved = await _unifiedAiService.resolveGlobalConfig(forcedProvider: provider, forcedModel: model);
    if (!resolved.available) return text;

    try {
      await _logDao.add(taskUid: 'system', detail: '统一AI翻译开始：provider=$provider，model=$model，目标语言=$target，输入长度=${text.length}');
    } catch (_) {}

    if (text.length > _longTextThreshold) {
      final chunks = _splitTextIntoChunks(text);
      final translatedChunks = <String>[];
      for (var i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        String? translated;
        for (var attempt = 1; attempt <= 2; attempt++) {
          translated = await _translateChunkOnce(chunk: chunk, target: target, attempt: attempt);
          if (translated != null && translated.trim().isNotEmpty) break;
        }
        if (translated == null || translated.trim().isEmpty) {
          try {
            await _logDao.add(taskUid: 'system', detail: '统一AI翻译分段失败：第${i + 1}/${chunks.length}段，整体回退原文');
          } catch (_) {}
          return text;
        }
        translatedChunks.add(translated);
      }
      final joined = translatedChunks.join();
      return joined.trim().isEmpty ? text : joined;
    }

    for (var attempt = 1; attempt <= 2; attempt++) {
      final translated = await _translateChunkOnce(chunk: text, target: target, attempt: attempt);
      if (translated != null && translated.trim().isNotEmpty) {
        return translated;
      }
    }
    return text;
  }

  Future<String> translateOne({required String text, required String target}) async {
    if (target == 'en' || text.trim().isEmpty) return text;
    final memKey = '$target|$text';
    final cached = _cache[memKey];
    if (cached != null) return cached;

    await _ensureConfig();
    final cacheKey = _hashKey(model: '${_provider ?? 'deepseek'}:${_model ?? 'deepseek-reasoner'}', target: target, sourceText: text);
    try {
      final dbCached = await _translationCacheDao.getTranslatedText(cacheKey);
      if (dbCached != null && dbCached.trim().isNotEmpty) {
        _cache[memKey] = dbCached;
        return dbCached;
      }
    } catch (_) {}

    final translated = await _translateViaUnified(text: text, target: target);
    if (translated.trim().isNotEmpty && translated.trim() != text.trim()) {
      _cache[memKey] = translated;
      try {
        await _translationCacheDao.put(
          cacheKey: cacheKey,
          model: '${_provider ?? 'deepseek'}:${_model ?? 'deepseek-reasoner'}',
          target: target,
          sourceText: text,
          translatedText: translated,
        );
      } catch (_) {}
      return translated;
    }
    return text;
  }

  String _hashKey({required String model, required String target, required String sourceText}) {
    final bytes = utf8.encode('$model|$target|$sourceText');
    return sha1.convert(bytes).toString();
  }

  Future<List<String>> translateTexts(List<String> texts, {required String targetLang}) async {
    return translateMany(texts: texts, target: targetLang);
  }

  Future<List<String>> translateMany({required List<String> texts, required String target}) async {
    if (target == 'en' || texts.isEmpty) return texts;
    final out = List<String>.filled(texts.length, '');
    final toTranslate = <int, String>{};
    for (var i = 0; i < texts.length; i++) {
      final t = texts[i];
      if (t.trim().isEmpty) {
        out[i] = t;
        continue;
      }
      final cacheKey = '$target|$t';
      final cached = _cache[cacheKey];
      if (cached != null) {
        out[i] = cached;
      } else {
        toTranslate[i] = t;
      }
    }
    if (toTranslate.isEmpty) return out;
    for (final entry in toTranslate.entries) {
      out[entry.key] = await translateOne(text: entry.value, target: target);
    }
    return out;
  }
}
