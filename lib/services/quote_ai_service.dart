import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/debug_logger.dart';
import 'unified_ai_service.dart';

/// Built-in representatives are intentionally grouped by field so the task
/// editor can offer meaningful multi-select choices without tying generation
/// to a single hard-coded author.
const Map<String, List<String>> quoteFigureCatalog = <String, List<String>>{
  '哲学与思想': <String>['孔子', '苏格拉底', '尼采', '王阳明'],
  '科学与探索': <String>['爱因斯坦', '牛顿', '居里夫人', '达尔文'],
  '文学与写作': <String>['莎士比亚', '鲁迅', '泰戈尔', '托尔斯泰'],
  '心理学与意义': <String>['威廉·詹姆斯', '卡尔·荣格', '维克多·弗兰克尔', '马丁·塞利格曼'],
  '管理与创造': <String>['彼得·德鲁克', '稻盛和夫', '史蒂夫·乔布斯', '沃伦·巴菲特'],
  '社会与公共生活': <String>['林肯', '甘地', '马丁·路德·金', '纳尔逊·曼德拉'],
  '艺术与审美': <String>['达·芬奇', '贝多芬', '毕加索', '宫崎骏'],
  '体育与竞技': <String>['穆罕默德·阿里', '迈克尔·乔丹', '科比·布莱恩特', '比利·简·金'],
};

const List<String> quoteThemeOptions = <String>[
  '不限主题',
  '人生智慧',
  '成长与改变',
  '勇气与行动',
  '自律与习惯',
  '挫折与韧性',
  '爱与关系',
  '事业与领导',
  '创造力',
  '科学与真理',
  '幸福与内在平静',
  '自定义主题',
];

/// Settings persisted in tasks.freq_custom. Keeping these fields in one JSON
/// document makes the feature backward-compatible with existing task rows.
class QuoteAiTaskConfig {
  static const int currentVersion = 2;

  final bool autoEnabled;
  final bool saveLocally;
  final bool downloadAvatar;
  final List<String> selectedFigures;
  final List<String> customFigures;
  final String theme;
  final String userDescription;
  final int intervalMinutes;

  const QuoteAiTaskConfig({
    this.autoEnabled = true,
    this.saveLocally = true,
    this.downloadAvatar = true,
    this.selectedFigures = const <String>[],
    this.customFigures = const <String>[],
    this.theme = '',
    this.userDescription = '',
    this.intervalMinutes = 60,
  });

  factory QuoteAiTaskConfig.fromTask(Map<String, dynamic> task) {
    Map<String, dynamic> values = <String, dynamic>{};
    final raw = (task['freq_custom'] ?? '').toString().trim();
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          values = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Older versions used this column as a free-form reserved value.
      }
    }

    final legacyPrompt = (task['prompt'] ?? '').toString().trim();
    final interval = _readInt(
      values['interval_minutes'] ?? values['intervalMinutes'],
      fallback: 60,
    ).clamp(15, 24 * 60).toInt();

    return QuoteAiTaskConfig(
      autoEnabled: _readBool(
        values['auto_enabled'] ?? values['autoEnabled'],
        fallback: true,
      ),
      saveLocally: _readBool(
        values['save_locally'] ?? values['saveLocally'],
        fallback: true,
      ),
      downloadAvatar: _readBool(
        values['download_avatar'] ?? values['downloadAvatar'],
        fallback: true,
      ),
      selectedFigures: normalizeFigures(
        _readStringList(
          values['selected_figures'] ?? values['selectedFigures'],
        ),
      ),
      customFigures: normalizeFigures(
        _readStringList(values['custom_figures'] ?? values['customFigures']),
      ),
      theme: (values['theme'] ?? '').toString().trim(),
      userDescription:
          (values['user_description'] ??
                  values['userDescription'] ??
                  legacyPrompt)
              .toString()
              .trim(),
      intervalMinutes: interval,
    );
  }

  List<String> get figures =>
      normalizeFigures(<String>[...selectedFigures, ...customFigures]);

  String figureForCursor(int cursor) {
    final all = figures;
    if (all.isEmpty) return '';
    final safeCursor = cursor < 0 ? 0 : cursor;
    return all[safeCursor % all.length];
  }

  String encode() => jsonEncode(<String, dynamic>{
    'version': currentVersion,
    'auto_enabled': autoEnabled,
    'save_locally': saveLocally,
    'download_avatar': downloadAvatar,
    'selected_figures': selectedFigures,
    'custom_figures': customFigures,
    'theme': theme,
    'user_description': userDescription,
    'interval_minutes': intervalMinutes.clamp(15, 24 * 60),
  });

  static List<String> parseFigureInput(String value) {
    return normalizeFigures(value.split(RegExp(r'[,，、;；\n]+')));
  }

  static List<String> normalizeFigures(Iterable<String> values) {
    final result = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final cleaned = value.trim();
      if (cleaned.isEmpty) continue;
      final key = cleaned.toLowerCase();
      if (seen.add(key)) result.add(cleaned);
    }
    return result;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    if (value is String) return parseFigureInput(value);
    return const <String>[];
  }

  static bool _readBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = (value ?? '').toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes' || text == 'on')
      return true;
    if (text == 'false' || text == '0' || text == 'no' || text == 'off')
      return false;
    return fallback;
  }

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }
}

class GeneratedQuote {
  final String content;
  final String author;
  final String source;
  final String theme;
  final String coreMatch;
  final String analysis;
  final String problemAddressed;
  final String relatedPerson;
  final String relatedThought;
  final String sourceConfidence;
  final String avatarSearchQuery;
  final String avatarSourceUrl;
  final String avatarPath;
  final String selectedFigure;
  final int nextCursor;

  const GeneratedQuote({
    required this.content,
    required this.author,
    required this.source,
    required this.theme,
    required this.coreMatch,
    required this.analysis,
    required this.problemAddressed,
    required this.relatedPerson,
    required this.relatedThought,
    required this.sourceConfidence,
    required this.avatarSearchQuery,
    required this.avatarSourceUrl,
    required this.avatarPath,
    required this.selectedFigure,
    required this.nextCursor,
  });

  String get explanation {
    final sections = <String>[];
    if (coreMatch.isNotEmpty) sections.add('核心思想匹配：$coreMatch');
    if (analysis.isNotEmpty) sections.add('深度解读：$analysis');
    if (problemAddressed.isNotEmpty) sections.add('它试图回应的问题：$problemAddressed');
    if (relatedThought.isNotEmpty) {
      final prefix = relatedPerson.isEmpty ? '高度相关的思想' : '关联思想（$relatedPerson）';
      sections.add('$prefix：$relatedThought');
    }
    if (sourceConfidence.isNotEmpty) sections.add('出处可信度：$sourceConfidence');
    return sections.join('\n\n');
  }

  GeneratedQuote withAvatar(DownloadedQuoteAvatar? avatar) {
    if (avatar == null) return this;
    return GeneratedQuote(
      content: content,
      author: author,
      source: source,
      theme: theme,
      coreMatch: coreMatch,
      analysis: analysis,
      problemAddressed: problemAddressed,
      relatedPerson: relatedPerson,
      relatedThought: relatedThought,
      sourceConfidence: sourceConfidence,
      avatarSearchQuery: avatarSearchQuery,
      avatarSourceUrl: avatar.sourceUrl,
      avatarPath: avatar.path,
      selectedFigure: selectedFigure,
      nextCursor: nextCursor,
    );
  }
}

class QuoteAiService {
  final UnifiedAiService _ai;
  final QuoteAvatarDownloader _avatarDownloader;

  QuoteAiService({
    UnifiedAiService? ai,
    QuoteAvatarDownloader? avatarDownloader,
  }) : _ai = ai ?? UnifiedAiService(),
       _avatarDownloader = avatarDownloader ?? QuoteAvatarDownloader();

  Future<GeneratedQuote> generate(Map<String, dynamic> task) async {
    final config = QuoteAiTaskConfig.fromTask(task);
    if (!config.autoEnabled) {
      throw StateError('AI 自动获取已关闭');
    }

    final cursor = int.tryParse((task['cursor'] ?? '0').toString()) ?? 0;
    final selectedFigure = config.figureForCursor(cursor);
    final prompt = buildPrompt(
      taskUid: (task['task_uid'] ?? '').toString(),
      config: config,
      selectedFigure: selectedFigure,
      cursor: cursor,
    );

    final raw = await _ai.generateText(
      prompt: prompt,
      purpose: 'quote_ai.structured_generation',
      systemPrompt:
          '你是严谨的名言研究与思想分析助手。只返回一个合法 JSON 对象；不得编造名言、作者或具体出处，不确定时必须明确标注“出处待考”。',
      maxTokens: 2200,
      expectJson: true,
      temperature: 0.55,
    );
    if (raw.trim().isEmpty) {
      throw StateError('全局 AI 当前不可用或未完成配置');
    }

    var result = parseResponse(
      raw,
      selectedFigure: selectedFigure,
      fallbackTheme: config.theme,
      nextCursor: cursor + 1,
    );

    if (config.downloadAvatar) {
      try {
        final avatar = await _avatarDownloader.resolveAndDownload(
          author: result.author,
          searchQuery: result.avatarSearchQuery,
          preferredUrl: result.avatarSourceUrl,
        );
        result = result.withAvatar(avatar);
      } catch (error) {
        await DLog.w('QUOTE_AI', '人物头像下载失败，名言仍会保存：$error');
      }
    }
    return result;
  }

  static String buildPrompt({
    required String taskUid,
    required QuoteAiTaskConfig config,
    required String selectedFigure,
    required int cursor,
  }) {
    final stableTaskSeed = taskUid.codeUnits.fold<int>(
      17,
      (value, unit) => (value * 31 + unit) & 0x7fffffff,
    );
    final explorationLane =
        (stableTaskSeed + (cursor < 0 ? 0 : cursor) * 37) % 97;
    final theme = config.theme.trim().isEmpty || config.theme == '不限主题'
        ? '不限，由内容决定'
        : config.theme.trim();
    final description = config.userDescription.trim().isEmpty
        ? '无额外描述'
        : config.userDescription.trim();
    final figure = selectedFigure.trim().isEmpty
        ? '不限人物，请选择与主题最契合且出处可靠的人物'
        : selectedFigure.trim();

    return '''
请为名人名言应用检索并分析一条真实、可归属的名言。

本轮指定人物：$figure
主题或类别：$theme
用户描述：$description
探索路线编号：$explorationLane

选择规则：
1. 用户描述代表用户真正想表达的核心思想，语义匹配优先级最高；不要只做关键词匹配。
2. 若指定了人物，名言必须确实归属于该人物，不得改选其他作者，并在 author 字段原样返回“本轮指定人物”的名称。多人物轮换由应用负责，本轮只处理当前人物。
3. 将本轮视为同一任务的连续自动获取：不要重复近期轮次中你通常会给出的名言，也不要选同类请求中最常输出、最泛滥的前三句；结合探索路线编号选择可靠但相对不重复的内容。应用不会发送历史名言正文，也不要求你执行历史列表比对。
4. 必须忠于可核验的原意。出处不确定时 source 写“出处待考”，source_confidence 写明原因；禁止为了显得完整而编造书名、演讲、年份或章节。
5. analysis 要解释作者为何这样说及其思想语境；problem_addressed 要说明它试图解决、纠正或应对什么问题。
6. related_person 与 related_thought 要给出最容易由此联想到的另一位人物及其高度相关思想，并说明关键联系或差异。
7. avatar_search_query 返回适合在维基百科检索人物肖像的名称（优先通行中文名，可附原文名）。avatar_url 只有在确信是 Wikimedia/Wikipedia 的人物肖像直链时才填写，否则留空。
8. 只返回 JSON，不要 Markdown、代码围栏或额外说明。

JSON 字段必须完整：
{
  "quote": "名言正文",
  "author": "署名",
  "source": "出处或出处待考",
  "theme": "主题",
  "core_match": "它与用户描述核心思想的匹配依据",
  "analysis": "深入分析",
  "problem_addressed": "试图解决或应对的问题",
  "related_person": "相关人物",
  "related_thought": "相关人物的思想及联系",
  "source_confidence": "高/中/低及简短理由",
  "avatar_search_query": "人物肖像搜索词",
  "avatar_url": "可信的 Wikimedia/Wikipedia 图片直链或空字符串"
}
'''
        .trim();
  }

  static GeneratedQuote parseResponse(
    String raw, {
    required String selectedFigure,
    required String fallbackTheme,
    required int nextCursor,
  }) {
    final map = _decodeObject(raw);
    final content = _readString(map, const <String>[
      'quote',
      'content',
      '名言',
      '名人名言正文',
    ]);
    if (content.isEmpty) {
      throw const FormatException('AI 返回缺少 quote 字段');
    }
    final parsedAuthor = _readString(map, const <String>[
      'author',
      'author_name',
      '署名',
      '作者',
    ]);
    final expectedAuthor = selectedFigure.trim();
    final author = parsedAuthor.isEmpty ? expectedAuthor : parsedAuthor;
    if (author.isEmpty) {
      throw const FormatException('AI 返回缺少 author 字段');
    }
    if (expectedAuthor.isNotEmpty &&
        !_sameSelectedAuthor(expectedAuthor, author)) {
      throw FormatException(
        'AI 返回作者“$author”与本轮指定人物“$expectedAuthor”不一致',
      );
    }
    var source = _readString(map, const <String>[
      'source',
      'source_from',
      '出处',
    ]);
    if (source.isEmpty) source = '出处待考';

    var theme = _readString(map, const <String>['theme', 'topic', '主题', '类别']);
    if (theme.isEmpty || theme == '不限主题') theme = fallbackTheme.trim();
    if (theme.isEmpty || theme == '不限主题') theme = '人生智慧';

    final avatarUrl = _readString(map, const <String>[
      'avatar_url',
      'avatarUrl',
      '头像',
    ]);
    final avatarQuery = _readString(map, const <String>[
      'avatar_search_query',
      'avatarSearchQuery',
      '头像搜索词',
    ]);

    return GeneratedQuote(
      content: content,
      author: author,
      source: source,
      theme: theme,
      coreMatch: _readString(map, const <String>[
        'core_match',
        'coreMatch',
        '核心匹配',
      ]),
      analysis: _readString(map, const <String>[
        'analysis',
        'explanation',
        '深度分析',
        '解释',
      ]),
      problemAddressed: _readString(map, const <String>[
        'problem_addressed',
        'problemAddressed',
        '应对问题',
      ]),
      relatedPerson: _readString(map, const <String>[
        'related_person',
        'relatedPerson',
        '相关人物',
      ]),
      relatedThought: _readString(map, const <String>[
        'related_thought',
        'relatedThought',
        '相关思想',
      ]),
      sourceConfidence: _readString(map, const <String>[
        'source_confidence',
        'sourceConfidence',
        '出处可信度',
      ]),
      avatarSearchQuery: avatarQuery.isEmpty ? author : avatarQuery,
      avatarSourceUrl: _trustedWikimediaUrl(avatarUrl) ? avatarUrl : '',
      avatarPath: '',
      selectedFigure: selectedFigure,
      nextCursor: nextCursor,
    );
  }

  static Map<String, dynamic> _decodeObject(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(
        RegExp(r'^```(?:json)?\s*', caseSensitive: false),
        '',
      );
      text = text.replaceFirst(RegExp(r'\s*```\s*$'), '');
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        return Map<String, dynamic>.from(decoded.first as Map);
      }
    } catch (_) {
      // Some providers still prepend a short sentence despite JSON mode.
    }

    final start = text.indexOf('{');
    if (start >= 0) {
      var depth = 0;
      var inString = false;
      var escaped = false;
      for (var index = start; index < text.length; index++) {
        final char = text[index];
        if (escaped) {
          escaped = false;
          continue;
        }
        if (char == '\\' && inString) {
          escaped = true;
          continue;
        }
        if (char == '"') {
          inString = !inString;
          continue;
        }
        if (inString) continue;
        if (char == '{') depth++;
        if (char == '}') {
          depth--;
          if (depth == 0) {
            final candidate = text.substring(start, index + 1);
            final decoded = jsonDecode(candidate);
            if (decoded is Map) return Map<String, dynamic>.from(decoded);
            break;
          }
        }
      }
    }
    throw const FormatException('AI 返回的内容不是有效 JSON 对象');
  }

  static String _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      if (value is List) {
        final text = value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .join('；');
        if (text.isNotEmpty) return text;
      } else if (value is Map) {
        final text = jsonEncode(value);
        if (text.isNotEmpty && text != '{}') return text;
      } else {
        final text = value.toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
    }
    return '';
  }

  static bool _trustedWikimediaUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    return host == 'upload.wikimedia.org' ||
        host.endsWith('.wikimedia.org') ||
        host.endsWith('.wikipedia.org');
  }

  static bool _sameSelectedAuthor(String expected, String actual) {
    String normalize(String value) => value
        .toLowerCase()
        .replaceAll(RegExp(r'[\s·•・\-_.，,。；;：:（）()《》〈〉]'), '');

    final expectedKey = normalize(expected);
    final actualKey = normalize(actual);
    if (expectedKey.isEmpty || actualKey.isEmpty) return false;
    return expectedKey == actualKey ||
        expectedKey.contains(actualKey) ||
        actualKey.contains(expectedKey);
  }
}

class DownloadedQuoteAvatar {
  final String path;
  final String sourceUrl;

  const DownloadedQuoteAvatar({required this.path, required this.sourceUrl});
}

/// Resolves a public portrait through Wikipedia's pageimages API and stores a
/// bounded image file in the app documents directory. AI-provided URLs are
/// accepted only from Wikimedia/Wikipedia hosts.
class QuoteAvatarDownloader {
  static const int _maximumBytes = 6 * 1024 * 1024;

  Future<DownloadedQuoteAvatar?> resolveAndDownload({
    required String author,
    required String searchQuery,
    required String preferredUrl,
  }) async {
    final client = http.Client();
    try {
      String url = '';
      if (QuoteAiService._trustedWikimediaUrl(preferredUrl)) {
        url = preferredUrl.trim();
      }
      if (url.isEmpty) {
        final query = searchQuery.trim().isEmpty
            ? author.trim()
            : searchQuery.trim();
        if (query.isEmpty) return null;
        url = await _resolveWikipediaImage(client, query);
      }
      if (url.isEmpty || !QuoteAiService._trustedWikimediaUrl(url)) return null;
      return _download(client, author: author, url: url);
    } finally {
      client.close();
    }
  }

  Future<String> _resolveWikipediaImage(
    http.Client client,
    String query,
  ) async {
    for (final language in const <String>['zh', 'en']) {
      final uri = Uri.https(
        '$language.wikipedia.org',
        '/w/api.php',
        <String, String>{
          'action': 'query',
          'generator': 'search',
          'gsrsearch': query,
          'gsrnamespace': '0',
          'gsrlimit': '3',
          'prop': 'pageimages',
          'piprop': 'thumbnail|original',
          'pithumbsize': '640',
          'redirects': '1',
          'format': 'json',
          'formatversion': '2',
        },
      );
      try {
        final response = await client
            .get(
              uri,
              headers: const <String, String>{
                'Accept': 'application/json',
                'User-Agent': 'quote_app/0.1 (portrait lookup)',
              },
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) continue;
        final queryMap = decoded['query'];
        if (queryMap is! Map || queryMap['pages'] is! List) continue;
        for (final page in queryMap['pages'] as List) {
          if (page is! Map) continue;
          final thumbnail = page['thumbnail'];
          final original = page['original'];
          var candidate = thumbnail is Map
              ? (thumbnail['source'] ?? '').toString()
              : '';
          if (candidate.isEmpty && original is Map) {
            candidate = (original['source'] ?? '').toString();
          }
          if (QuoteAiService._trustedWikimediaUrl(candidate)) return candidate;
        }
      } catch (_) {
        // Try the English Wikipedia fallback before giving up.
      }
    }
    return '';
  }

  Future<DownloadedQuoteAvatar?> _download(
    http.Client client, {
    required String author,
    required String url,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    request.headers.addAll(const <String, String>{
      'Accept': 'image/*',
      'User-Agent': 'quote_app/0.1 (portrait download)',
    });
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    if ((response.contentLength ?? 0) > _maximumBytes) return null;

    final contentType = (response.headers['content-type'] ?? '')
        .split(';')
        .first
        .trim()
        .toLowerCase();
    if (contentType.isNotEmpty && !contentType.startsWith('image/'))
      return null;
    final extension = _extensionFor(contentType, url);
    final digest = sha256
        .convert(utf8.encode('${author.trim()}|$url'))
        .toString()
        .substring(0, 24);
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'quote_avatars'));
    if (!await directory.exists()) await directory.create(recursive: true);
    final file = File(p.join(directory.path, 'quote_avatar_$digest$extension'));
    if (await file.exists() && await file.length() > 0) {
      return DownloadedQuoteAvatar(path: file.path, sourceUrl: url);
    }

    final bytes = BytesBuilder(copy: false);
    var byteCount = 0;
    await for (final chunk in response.stream) {
      byteCount += chunk.length;
      if (byteCount > _maximumBytes) return null;
      bytes.add(chunk);
    }
    if (byteCount == 0) return null;
    await file.writeAsBytes(bytes.takeBytes(), flush: true);
    return DownloadedQuoteAvatar(path: file.path, sourceUrl: url);
  }

  static String _extensionFor(String contentType, String url) {
    if (contentType == 'image/jpeg') return '.jpg';
    if (contentType == 'image/png') return '.png';
    if (contentType == 'image/webp') return '.webp';
    if (contentType == 'image/gif') return '.gif';
    final lowerPath = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    for (final extension in const <String>[
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.gif',
    ]) {
      if (lowerPath.endsWith(extension))
        return extension == '.jpeg' ? '.jpg' : extension;
    }
    return '.jpg';
  }
}
