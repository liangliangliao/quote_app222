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
  '哲学与思想': <String>[
    '孔子', '苏格拉底', '尼采', '王阳明', '老子', '庄子', '孟子', '柏拉图',
    '亚里士多德', '笛卡尔', '斯宾诺莎', '康德', '黑格尔', '叔本华',
    '克尔凯郭尔', '萨特', '西蒙娜·德·波伏娃', '汉娜·阿伦特', '维特根斯坦', '马可·奥勒留',
    '休谟', '朱熹', '张载', '列维纳斯',
  ],
  '科学与探索': <String>[
    '爱因斯坦', '牛顿', '居里夫人', '达尔文', '伽利略', '哥白尼',
    '开普勒', '麦克斯韦', '法拉第', '理查德·费曼', '尼尔斯·玻尔',
    '艾伦·图灵', '阿达·洛夫莱斯', '卡尔·萨根', '史蒂芬·霍金',
    '珍妮·古道尔', '屠呦呦', '袁隆平', '钱学森', '吴健雄',
    '罗莎琳德·富兰克林', '埃米·诺特', '弗朗西斯·克里克', '薛定谔',
  ],
  '文学与写作': <String>[
    '莎士比亚', '鲁迅', '泰戈尔', '托尔斯泰', '莫言', '加西亚·马尔克斯',
    '欧内斯特·海明威', '阿尔贝·加缪', '托妮·莫里森', '托马斯·曼',
    '赫尔曼·黑塞', '奥尔加·托卡尔丘克', '石黑一雄', '爱丽丝·门罗',
    '奥尔罕·帕慕克', '马里奥·巴尔加斯·略萨', '帕布罗·聂鲁达',
    '川端康成', '大江健三郎', '高行健', '安妮·埃尔诺', '路易丝·格丽克',
    '弗吉尼亚·伍尔夫', '陀思妥耶夫斯基', '阿卜杜勒拉扎克·古尔纳',
    '韩江', '约恩·福瑟', '奥克塔维奥·帕斯',
  ],
  '心理学与意义': <String>[
    '威廉·詹姆斯', '卡尔·荣格', '维克多·弗兰克尔', '马丁·塞利格曼',
    '西格蒙德·弗洛伊德', '阿尔弗雷德·阿德勒', '阿尔伯特·班杜拉',
    '塔尔·本-沙哈尔（Tal Ben-Shahar）', '卡尔·罗杰斯', '亚伯拉罕·马斯洛',
    '埃里克·埃里克森', '让·皮亚杰', '列夫·维果茨基', '丹尼尔·卡尼曼',
    '阿龙·贝克', '阿尔伯特·埃利斯', '约翰·鲍尔比', '玛丽·安斯沃斯',
    '米哈里·契克森米哈赖', '卡罗尔·德韦克', '罗洛·梅', '安娜·弗洛伊德',
    '凯伦·霍妮', '奥利弗·萨克斯',
  ],
  '管理与创造': <String>[
    '彼得·德鲁克', '稻盛和夫', '史蒂夫·乔布斯', '沃伦·巴菲特',
    '本杰明·格雷厄姆', '查理·芒格', '安德鲁·格罗夫', '彼得·圣吉',
    '克莱顿·克里斯坦森', '赫伯特·西蒙', '埃莉诺·奥斯特罗姆',
    '亨利·明茨伯格', '玛丽·帕克·福莱特', 'W·爱德华兹·戴明',
    '英格瓦·坎普拉德', '松下幸之助', '张瑞敏', '黄仁勋', '杰森·弗里德',
    '简·雅各布斯', '雷·达里奥', '乔治·伊斯曼', '英迪拉·努伊', '张忠谋',
  ],
  '社会与公共生活': <String>[
    '林肯', '甘地', '马丁·路德·金', '纳尔逊·曼德拉', '埃莉诺·罗斯福',
    '罗莎·帕克斯', '苏珊·安东尼', '弗雷德里克·道格拉斯', '德斯蒙德·图图',
    '瓦茨拉夫·哈维尔', '马拉拉·优素福扎伊', '简·亚当斯', '海伦·凯勒',
    '南丁格尔', '特蕾莎修女', '蔡元培', '宋庆龄', '费孝通', '阿马蒂亚·森', '西蒙娜·韦伊',
    '弗朗西斯·帕金斯', '凯撒·查韦斯', '艾达·B·韦尔斯', '鲁斯·巴德·金斯伯格',
  ],
  '艺术与审美': <String>[
    '达·芬奇', '贝多芬', '毕加索', '宫崎骏', '米开朗基罗', '伦勃朗',
    '莫奈', '梵高', '弗里达·卡罗', '保罗·克利', '乔治娅·欧姬芙',
    '齐白石', '徐悲鸿', '张大千', '巴赫', '莫扎特', '肖邦', '德彪西',
    '黑泽明', '安德烈·塔可夫斯基', '古斯塔夫·克里姆特', '罗丹', '王羲之', '坂本龙一',
  ],
  '体育与竞技': <String>[
    '穆罕默德·阿里', '迈克尔·乔丹', '科比·布莱恩特', '比利·简·金',
    '塞雷娜·威廉姆斯', '罗杰·费德勒', '拉斐尔·纳达尔', '诺瓦克·德约科维奇',
    '西蒙·拜尔斯', '迈克尔·菲尔普斯', '尤塞恩·博尔特', '杰西·欧文斯',
    '贝利', '梅西', '克里斯蒂亚诺·罗纳尔多', '郎平', '姚明', '李娜',
    '刘翔', '谷爱凌', '费尔南多·阿隆索', '斯特芬·库里', '纳迪娅·科马内奇', '埃鲁德·基普乔格',
  ],
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
      userDescription: (values['user_description'] ??
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

class QuotePracticeActivity {
  final String title;
  final String conceptToExperience;
  final String duration;
  final String setting;
  final List<String> steps;
  final String experienceFocus;
  final List<String> reflectionQuestions;
  final String inspiration;

  const QuotePracticeActivity({
    required this.title,
    required this.conceptToExperience,
    required this.duration,
    required this.setting,
    required this.steps,
    required this.experienceFocus,
    required this.reflectionQuestions,
    required this.inspiration,
  });

  String formatForReading(int index) {
    final lines = <String>[
      '活动 $index｜${title.isEmpty ? '把概念带回现实' : title}',
    ];
    if (conceptToExperience.isNotEmpty) {
      lines.add('要体验的概念：$conceptToExperience');
    }
    if (duration.isNotEmpty) lines.add('建议时长：$duration');
    if (setting.isNotEmpty) lines.add('场景与准备：$setting');
    if (steps.isNotEmpty) {
      lines.add('行动步骤：');
      for (var stepIndex = 0; stepIndex < steps.length; stepIndex++) {
        lines.add('${stepIndex + 1}. ${steps[stepIndex]}');
      }
    }
    if (experienceFocus.isNotEmpty) {
      lines.add('体验时重点观察：$experienceFocus');
    }
    if (inspiration.isNotEmpty) {
      lines.add('借鉴或类比：$inspiration');
    }
    if (reflectionQuestions.isNotEmpty) {
      lines.add('完成后复盘：');
      for (final question in reflectionQuestions) {
        lines.add('• $question');
      }
    }
    return lines.join('\n');
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
  final List<QuotePracticeActivity> practiceActivities;
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
    required this.practiceActivities,
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
    if (practiceActivities.isNotEmpty) {
      final activities = practiceActivities
          .asMap()
          .entries
          .map((entry) => entry.value.formatForReading(entry.key + 1))
          .join('\n\n');
      sections.add('现实实践：把抽象概念变成亲身经验\n$activities');
    }
    if (sourceConfidence.isNotEmpty) sections.add('出处可信度：$sourceConfidence');
    return sections.join('\n\n');
  }

  GeneratedQuote withAvatar(DownloadedQuoteAvatar? avatar) {
    if (avatar == null) return this;
    return withAvatarPath(avatar.path, sourceUrl: avatar.sourceUrl);
  }

  GeneratedQuote withAvatarPath(String path, {String sourceUrl = ''}) {
    if (path.trim().isEmpty) return this;
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
      practiceActivities: practiceActivities,
      sourceConfidence: sourceConfidence,
      avatarSearchQuery: avatarSearchQuery,
      avatarSourceUrl:
          sourceUrl.trim().isEmpty ? avatarSourceUrl : sourceUrl.trim(),
      avatarPath: path.trim(),
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
  })  : _ai = ai ?? UnifiedAiService(),
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
          '你是严谨的名言研究、思想分析与现实实践设计助手。只返回一个合法 JSON 对象；不得编造名言、作者、具体出处或历史事实，不确定时必须明确标注“出处待考”。实践活动必须安全、具体、可自愿停止。',
      maxTokens: 3200,
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
        if (avatar != null) {
          result = result.withAvatar(avatar);
        } else {
          final bundled = QuoteAvatarAssetResolver.forAuthor(result.author);
          if (bundled.isNotEmpty) {
            result = result.withAvatarPath(bundled);
            await DLog.i('QUOTE_AI', '网络头像暂不可用，已使用内置人物头像：${result.author}');
          } else {
            await DLog.w('QUOTE_AI', '未找到可用人物头像：${result.author}；名言正文仍会保存');
          }
        }
      } catch (error) {
        final bundled = QuoteAvatarAssetResolver.forAuthor(result.author);
        if (bundled.isNotEmpty) result = result.withAvatarPath(bundled);
        await DLog.w(
          'QUOTE_AI',
          '人物头像下载失败${bundled.isEmpty ? '' : '，已使用内置头像'}；名言仍会保存：$error',
        );
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
7. practice_activities 必须包含 1 至 3 个实践活动，把这句名言中的抽象概念转化为用户能在现实中亲自完成、观察和感受的经验。至少一个活动应当今天就能开始，通常可在 5 至 30 分钟内完成。不要只给建议、观点或阅读清单；必须给出有先后顺序、可以观察到是否完成的动作，以及体验重点和复盘问题。
8. 实践活动可以准确借鉴古今历史事件或典故，也可以借用电影人物、小说、文学、新闻、神话或艺术作品进行类比、角色模拟与情境想象；必须明确它是史实、作品情节、神话还是虚构模拟，不得把虚构当史实。没有可靠或真正相关的素材时，inspiration 留空，不要硬凑。
9. 活动应让用户在感受、选择、行动及结果中理解概念，而不是要求用户证明名言必然正确。活动必须低风险、尊重本人和他人同意，不得包含违法、危险、自伤、羞辱、强迫公开隐私、冒充医疗治疗或故意诱发创伤的内容；用户应可随时暂停。
10. avatar_search_query 返回适合在维基百科检索人物肖像的名称（优先通行中文名，可附原文名）。avatar_url 只有在确信是 Wikimedia/Wikipedia 的人物肖像直链时才填写，否则留空。
11. 只返回 JSON，不要 Markdown、代码围栏或额外说明。

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
  "practice_activities": [
    {
      "title": "实践活动名称",
      "concept_to_experience": "希望用户亲身体验的抽象概念或内在张力",
      "duration": "预计时长",
      "setting": "适合的场景、材料或准备；不需要时写无",
      "steps": ["具体步骤1", "具体步骤2", "具体步骤3"],
      "experience_focus": "过程中要留意的身体感受、念头、选择或现实变化",
      "reflection_questions": ["完成后的复盘问题1", "复盘问题2"],
      "inspiration": "可选：史实/典故/电影/小说/新闻/神话/艺术/类比/原创情境，并明确类型；无则留空"
    }
  ],
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
      throw FormatException('AI 返回作者“$author”与本轮指定人物“$expectedAuthor”不一致');
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
    final practiceActivities = _readPracticeActivities(map);
    if (practiceActivities.isEmpty) {
      throw const FormatException('AI 返回缺少可执行的 practice_activities');
    }

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
      practiceActivities: practiceActivities,
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

  static List<QuotePracticeActivity> _readPracticeActivities(
    Map<String, dynamic> map,
  ) {
    dynamic raw;
    for (final key in const <String>[
      'practice_activities',
      'practiceActivities',
      'practice_activity',
      'practice',
      'activities',
      '实践活动',
      '现实实践',
    ]) {
      if (map[key] != null) {
        raw = map[key];
        break;
      }
    }
    if (raw is String) {
      final encoded = raw.trim();
      if (encoded.startsWith('[') || encoded.startsWith('{')) {
        try {
          final decoded = jsonDecode(encoded);
          if (decoded is List || decoded is Map) raw = decoded;
        } catch (_) {
          // Keep a normal string as a single executable activity.
        }
      }
    }
    if (raw is Map && raw['activities'] != null) raw = raw['activities'];
    final values = raw is List ? raw : <dynamic>[raw];
    final result = <QuotePracticeActivity>[];
    for (final value in values) {
      if (result.length >= 3) break;
      if (value is String) {
        final step = value.trim();
        if (step.isEmpty) continue;
        result.add(
          QuotePracticeActivity(
            title: '把概念带回现实',
            conceptToExperience: '',
            duration: '',
            setting: '',
            steps: <String>[step],
            experienceFocus: '',
            reflectionQuestions: const <String>[],
            inspiration: '',
          ),
        );
        continue;
      }
      if (value is! Map) continue;
      final activity = Map<String, dynamic>.from(value);
      var steps = _readTextList(
        _firstValue(activity, const <String>[
          'steps',
          'actions',
          'activity_steps',
          '行动步骤',
          '活动步骤',
          '步骤',
        ]),
      );
      if (steps.isEmpty) {
        final singleAction = _readString(activity, const <String>[
          'activity',
          'action',
          'exercise',
          '实践内容',
          '实践方式',
        ]);
        if (singleAction.isNotEmpty) steps = <String>[singleAction];
      }
      if (steps.isEmpty) continue;
      result.add(
        QuotePracticeActivity(
          title: _readString(activity, const <String>[
            'title',
            'name',
            '活动名称',
            '标题',
          ]),
          conceptToExperience: _readString(activity, const <String>[
            'concept_to_experience',
            'conceptToExperience',
            'concept',
            'purpose',
            '体验概念',
            '体验目标',
          ]),
          duration: _readString(activity, const <String>[
            'duration',
            'time',
            '预计时长',
            '时长',
          ]),
          setting: _readString(activity, const <String>[
            'setting',
            'context',
            'materials',
            '场景与准备',
            '场景',
            '准备',
          ]),
          steps: steps.take(8).toList(growable: false),
          experienceFocus: _readString(activity, const <String>[
            'experience_focus',
            'experienceFocus',
            'observation',
            '体验重点',
            '观察重点',
          ]),
          reflectionQuestions: _readTextList(
            _firstValue(activity, const <String>[
              'reflection_questions',
              'reflectionQuestions',
              'reflection',
              '复盘问题',
              '反思问题',
            ]),
          ).take(4).toList(growable: false),
          inspiration: _readString(activity, const <String>[
            'inspiration',
            'reference',
            'analogy',
            'story',
            '借鉴与类比',
            '灵感来源',
            '参考素材',
          ]),
        ),
      );
    }
    return List<QuotePracticeActivity>.unmodifiable(result);
  }

  static dynamic _firstValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map[key] != null) return map[key];
    }
    return null;
  }

  static List<String> _readTextList(dynamic value) {
    final result = <String>[];
    void addItem(dynamic item) {
      if (item == null) return;
      if (item is List) {
        for (final nested in item) {
          addItem(nested);
        }
        return;
      }
      final text = item is Map
          ? _readString(Map<String, dynamic>.from(item), const <String>[
              'text',
              'step',
              'action',
              'question',
              '内容',
              '步骤',
              '问题',
            ])
          : item.toString().trim();
      if (text.isEmpty || text.toLowerCase() == 'null') return;
      final lines =
          text.contains('\n') ? text.split(RegExp(r'\r?\n+')) : <String>[text];
      for (final line in lines) {
        final cleaned =
            line.replaceFirst(RegExp(r'^\s*(?:[-*•]|\d+[.)、])\s*'), '').trim();
        if (cleaned.isNotEmpty && !result.contains(cleaned)) {
          result.add(cleaned);
        }
      }
    }

    addItem(value);
    return result;
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
    String normalize(String value) => value.toLowerCase().replaceAll(
          RegExp(r'[\s·•・\-_.，,。；;：:（）()《》〈〉]'),
          '',
        );

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

/// Resolves packaged portraits without depending on the network. These aliases
/// also bridge Chinese author names returned by the quote task with the English
/// filenames already shipped in assets/avatars.
class QuoteAvatarAssetResolver {
  static const Map<String, String> _assetsByAlias = <String, String>{
    'talbenshahar': 'assets/avatars/talbenshahar .jpeg',
    '泰勒本沙哈尔': 'assets/avatars/talbenshahar .jpeg',
    '泰尔本沙哈尔': 'assets/avatars/talbenshahar .jpeg',
    '本沙哈尔': 'assets/avatars/talbenshahar .jpeg',
    'albertcamus': 'assets/avatars/Albert_Camus_1945_(cropped).jpg',
    '阿尔贝加缪': 'assets/avatars/Albert_Camus_1945_(cropped).jpg',
    '加缪': 'assets/avatars/Albert_Camus_1945_(cropped).jpg',
    '卡缪': 'assets/avatars/Albert_Camus_1945_(cropped).jpg',
    'friedrichnietzsche': 'assets/avatars/Friedrich Nietzsche.jpg',
    '弗里德里希尼采': 'assets/avatars/Friedrich Nietzsche.jpg',
    '尼采': 'assets/avatars/Friedrich Nietzsche.jpg',
    'williamjames': 'assets/avatars/250px-William_James_b1842c.jpg',
    '威廉詹姆斯': 'assets/avatars/250px-William_James_b1842c.jpg',
    'immanuelkant': 'assets/avatars/Immanuel Kant.jpg',
    '伊曼努尔康德': 'assets/avatars/Immanuel Kant.jpg',
    '康德': 'assets/avatars/Immanuel Kant.jpg',
    'arthurschopenhauer': 'assets/avatars/schopenhauer.jpg',
    '亚瑟叔本华': 'assets/avatars/schopenhauer.jpg',
    '叔本华': 'assets/avatars/schopenhauer.jpg',
    'wangyangming': 'assets/avatars/wangyangming.jpeg',
    '王阳明': 'assets/avatars/wangyangming.jpeg',
    'eckharttolle': 'assets/avatars/eckhart tolle.jpg',
    '埃克哈特托利': 'assets/avatars/eckhart tolle.jpg',
    '艾克哈特托利': 'assets/avatars/eckhart tolle.jpg',
  };

  static String forAuthor(String author) {
    final normalized = _normalize(author);
    if (normalized.isEmpty) return '';
    for (final entry in _assetsByAlias.entries) {
      final alias = _normalize(entry.key);
      if (normalized == alias ||
          normalized.contains(alias) ||
          (normalized.length >= 4 && alias.contains(normalized))) {
        return entry.value;
      }
    }
    return '';
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), '');
}

/// Resolves a public portrait through Wikipedia's pageimages API and stores a
/// bounded image file in the app documents directory. Search candidates must
/// match the author name and be verified by Wikidata as a human (Q5).
class QuoteAvatarDownloader {
  static const int _maximumBytes = 6 * 1024 * 1024;

  final http.Client Function() _clientFactory;
  final Future<Directory> Function() _documentsDirectory;

  QuoteAvatarDownloader({
    http.Client Function()? clientFactory,
    Future<Directory> Function()? documentsDirectory,
  })  : _clientFactory = clientFactory ?? http.Client.new,
        _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  Future<DownloadedQuoteAvatar?> resolveAndDownload({
    required String author,
    required String searchQuery,
    required String preferredUrl,
  }) async {
    final client = _clientFactory();
    try {
      final attemptedUrls = <String>{};
      final humanEntityCache = <String, bool>{};
      Future<DownloadedQuoteAvatar?> tryUrl(String value) async {
        final url = value.trim();
        if (!QuoteAiService._trustedWikimediaUrl(url) ||
            !attemptedUrls.add(url)) {
          return null;
        }
        try {
          return await _download(client, author: author, url: url);
        } catch (_) {
          return null;
        }
      }

      // Do not download an AI-provided URL before independently resolving the
      // author. A syntactically valid Wikimedia URL may still point at a book,
      // institution, memorial, or another person.
      final identityAliases = _identityAliases(author, searchQuery);
      final queries = <String>[];
      for (final value in <String>[
        author,
        ...identityAliases,
        searchQuery,
      ]) {
        final query = value.trim();
        if (query.isNotEmpty && !queries.contains(query)) queries.add(query);
      }
      for (final query in queries) {
        for (final language in const <String>['zh', 'en']) {
          final urls = await _resolveWikipediaImages(
            client,
            query,
            language: language,
            identityAliases: identityAliases,
            humanEntityCache: humanEntityCache,
          );
          for (final url in urls) {
            final downloaded = await tryUrl(url);
            if (downloaded != null) return downloaded;
          }
        }
      }
      return null;
    } finally {
      client.close();
    }
  }

  Future<List<String>> _resolveWikipediaImages(
    http.Client client,
    String query, {
    required String language,
    required List<String> identityAliases,
    required Map<String, bool> humanEntityCache,
  }) async {
    final result = <String>[];
    void addCandidate(dynamic value) {
      final candidate = (value ?? '').toString().trim();
      if (QuoteAiService._trustedWikimediaUrl(candidate) &&
          !result.contains(candidate)) {
        result.add(candidate);
      }
    }

    final uri =
        Uri.https('$language.wikipedia.org', '/w/api.php', <String, String>{
      'action': 'query',
      'generator': 'search',
      'gsrsearch': query,
      'gsrnamespace': '0',
      'gsrlimit': '5',
      'prop': 'pageimages|pageprops',
      'piprop': 'thumbnail|original',
      'pithumbsize': '640',
      'redirects': '1',
      'format': 'json',
      'formatversion': '2',
    });
    try {
      final response = await client.get(
        uri,
        headers: const <String, String>{
          'Accept': 'application/json',
          'User-Agent': 'quote_app/0.1 (portrait lookup)',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return result;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return result;
      final queryMap = decoded['query'];
      if (queryMap is! Map || queryMap['pages'] is! List) return result;
      final pages = (queryMap['pages'] as List).whereType<Map>().toList()
        ..sort((left, right) {
          final leftIndex = int.tryParse('${left['index'] ?? 9999}') ?? 9999;
          final rightIndex = int.tryParse('${right['index'] ?? 9999}') ?? 9999;
          return leftIndex.compareTo(rightIndex);
        });
      for (final page in pages) {
        final title = (page['title'] ?? '').toString();
        if (!_titleMatchesIdentity(title, identityAliases)) continue;
        final pageProperties = page['pageprops'];
        final wikidataId = pageProperties is Map
            ? (pageProperties['wikibase_item'] ?? '').toString()
            : '';
        if (!await _isHumanEntity(
          client,
          wikidataId,
          humanEntityCache,
        )) {
          continue;
        }
        final thumbnail = page['thumbnail'];
        final original = page['original'];
        if (thumbnail is Map) addCandidate(thumbnail['source']);
        if (original is Map) addCandidate(original['source']);
      }
    } catch (_) {
      // The caller will try the next language or author query.
    }
    return result;
  }

  Future<bool> _isHumanEntity(
    http.Client client,
    String wikidataId,
    Map<String, bool> cache,
  ) async {
    if (!RegExp(r'^Q\d+$').hasMatch(wikidataId)) return false;
    final cached = cache[wikidataId];
    if (cached != null) return cached;
    final uri = Uri.https('www.wikidata.org', '/w/api.php', <String, String>{
      'action': 'wbgetclaims',
      'entity': wikidataId,
      'property': 'P31',
      'format': 'json',
      'formatversion': '2',
    });
    var isHuman = false;
    try {
      final response = await client.get(
        uri,
        headers: const <String, String>{
          'Accept': 'application/json',
          'User-Agent': 'quote_app/0.1 (portrait identity verification)',
        },
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final claims = decoded is Map ? decoded['claims'] : null;
        final instances = claims is Map ? claims['P31'] : null;
        if (instances is List) {
          isHuman = instances.any((claim) {
            if (claim is! Map) return false;
            final mainSnak = claim['mainsnak'];
            final dataValue = mainSnak is Map ? mainSnak['datavalue'] : null;
            final value = dataValue is Map ? dataValue['value'] : null;
            return value is Map && value['id'] == 'Q5';
          });
        }
      }
    } catch (_) {
      // Fail closed: a missing portrait is safer than an unrelated image.
    }
    cache[wikidataId] = isHuman;
    return isHuman;
  }

  static List<String> _identityAliases(String author, String searchQuery) {
    final result = <String>[];
    void add(String value) {
      final candidate = value.trim();
      if (candidate.isNotEmpty && !result.contains(candidate)) {
        result.add(candidate);
      }
    }

    add(author);
    for (final source in <String>[author, searchQuery]) {
      for (final match in RegExp(
        r'[\u3400-\u9fff](?:[\u3400-\u9fff·•・\s]*[\u3400-\u9fff])?',
      ).allMatches(source)) {
        add(match.group(0) ?? '');
      }
      for (final match in RegExp(
        r"[A-Za-zÀ-ÖØ-öø-ÿ](?:[A-Za-zÀ-ÖØ-öø-ÿ.'’\-\s]*[A-Za-zÀ-ÖØ-öø-ÿ])?",
      ).allMatches(source)) {
        add(match.group(0) ?? '');
      }
    }
    return result;
  }

  static bool _titleMatchesIdentity(String title, List<String> aliases) {
    final normalizedTitle = _normalizeIdentity(title);
    if (normalizedTitle.isEmpty) return false;
    for (final alias in aliases) {
      final normalizedAlias = _normalizeIdentity(alias);
      if (normalizedAlias.length < 2) continue;
      if (normalizedTitle == normalizedAlias) return true;
      final lengthDifference =
          (normalizedTitle.length - normalizedAlias.length).abs();
      if (normalizedAlias.length >= 4 &&
          lengthDifference <= 2 &&
          (normalizedTitle.contains(normalizedAlias) ||
              normalizedAlias.contains(normalizedTitle))) {
        return true;
      }
      final longest = normalizedTitle.length > normalizedAlias.length
          ? normalizedTitle.length
          : normalizedAlias.length;
      if (longest >= 5 &&
          1 - (_editDistance(normalizedTitle, normalizedAlias) / longest) >=
              0.80) {
        return true;
      }
    }
    return false;
  }

  static String _normalizeIdentity(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u3400-\u9fff]+'), '');

  static int _editDistance(String left, String right) {
    if (left == right) return 0;
    if (left.isEmpty) return right.length;
    if (right.isEmpty) return left.length;
    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var leftIndex = 0; leftIndex < left.length; leftIndex++) {
      final current = List<int>.filled(right.length + 1, 0);
      current[0] = leftIndex + 1;
      for (var rightIndex = 0; rightIndex < right.length; rightIndex++) {
        final substitution = previous[rightIndex] +
            (left.codeUnitAt(leftIndex) == right.codeUnitAt(rightIndex)
                ? 0
                : 1);
        final insertion = current[rightIndex] + 1;
        final deletion = previous[rightIndex + 1] + 1;
        current[rightIndex + 1] = substitution < insertion
            ? (substitution < deletion ? substitution : deletion)
            : (insertion < deletion ? insertion : deletion);
      }
      previous = current;
    }
    return previous.last;
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
    final response =
        await client.send(request).timeout(const Duration(seconds: 20));
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
    final documents = await _documentsDirectory();
    final directory = Directory(p.join(documents.path, 'quote_avatars'));
    if (!await directory.exists()) await directory.create(recursive: true);
    final file = File(
      p.join(directory.path, 'quote_avatar_v2_$digest$extension'),
    );
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

  static bool isIdentityVerifiedLocalPath(String value) {
    final path = value.trim();
    if (path.isEmpty || path.startsWith('assets/')) return false;
    return p.basename(path).startsWith('quote_avatar_v2_');
  }
}
