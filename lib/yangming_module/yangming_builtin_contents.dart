import 'package:flutter/foundation.dart' show FlutterError, debugPrint;
import 'package:flutter/services.dart' show rootBundle;

import 'yangming_models.dart';

Map<String, YangmingLessonContent>? _builtInCache;
Future<Map<String, YangmingLessonContent>>? _builtInLoading;

Future<Map<String, YangmingLessonContent>> loadBuiltInYangmingLessonContents() {
  if (_builtInCache != null) return Future.value(_builtInCache!);
  return _builtInLoading ??= _loadBuiltInYangmingLessonContentsInternal();
}

Future<Map<String, YangmingLessonContent>> _loadBuiltInYangmingLessonContentsInternal() async {
  final Map<String, YangmingLessonContent> all = <String, YangmingLessonContent>{};
  all.addAll(await _loadSectionSafely(
    assetPath: 'assets/yangming_module/zhixing15_content.txt',
    lessonIds: const <String>[
      'ZX-01','ZX-02','ZX-03','ZX-04','ZX-05','ZX-06','ZX-07','ZX-08','ZX-09','ZX-10','ZX-11','ZX-12','ZX-13','ZX-14','ZX-15',
    ],
  ));
  all.addAll(await _loadSectionSafely(
    assetPath: 'assets/yangming_module/lizhi12_content.txt',
    lessonIds: const <String>[
      'LZ-01','LZ-02','LZ-03','LZ-04','LZ-05','LZ-06','LZ-07','LZ-08','LZ-09','LZ-10','LZ-11','LZ-12',
    ],
  ));
  _builtInCache = Map<String, YangmingLessonContent>.unmodifiable(all);
  _builtInLoading = null;
  return _builtInCache!;
}

Future<Map<String, YangmingLessonContent>> _loadSectionSafely({required String assetPath, required List<String> lessonIds}) async {
  try {
    return await _loadSection(assetPath: assetPath, lessonIds: lessonIds);
  } on FlutterError catch (e) {
    debugPrint('Yangming built-in content asset error ($assetPath): $e');
    return <String, YangmingLessonContent>{};
  } catch (e) {
    debugPrint('Yangming built-in content parse error ($assetPath): $e');
    return <String, YangmingLessonContent>{};
  }
}

Future<Map<String, YangmingLessonContent>> _loadSection({required String assetPath, required List<String> lessonIds}) async {
  final raw = await rootBundle.loadString(assetPath);
  final entries = _splitLessonChunks(raw);
  final Map<String, YangmingLessonContent> result = <String, YangmingLessonContent>{};
  for (var i = 0; i < entries.length && i < lessonIds.length; i++) {
    final chunk = entries[i].trim();
    final originalIndex = chunk.indexOf('原文');
    final explanationIndex = chunk.indexOf('详细解释');
    if (originalIndex < 0 || explanationIndex < 0 || explanationIndex <= originalIndex) {
      continue;
    }
    final original = _stripQuotes(chunk.substring(originalIndex + 2, explanationIndex)).trim();
    final explanation = chunk.substring(explanationIndex + 4).trim();
    if (original.isEmpty && explanation.isEmpty) continue;
    result[lessonIds[i]] = YangmingLessonContent(
      lessonId: lessonIds[i],
      originalText: original,
      detailedExplanation: explanation,
      source: 'builtin_v32_real_content',
      updatedAt: '',
    );
  }
  return result;
}

List<String> _splitLessonChunks(String raw) {
  final matches = RegExp(r'^\d+）《', multiLine: true).allMatches(raw).toList();
  if (matches.isEmpty) {
    return <String>[];
  }
  final List<String> chunks = <String>[];
  for (var i = 0; i < matches.length; i++) {
    final start = matches[i].start;
    final end = i + 1 < matches.length ? matches[i + 1].start : raw.length;
    chunks.add(raw.substring(start, end));
  }
  return chunks;
}

String _stripQuotes(String text) {
  return text
      .split('\n')
      .map((line) => line.replaceFirst(RegExp(r'^\s*>\s?'), '').trimRight())
      .join('\n')
      .trim();
}
