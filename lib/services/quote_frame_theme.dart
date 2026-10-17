/// 依据主题、名言正文和解读选择视觉隐喻。
/// 本地规则即时生效，不依赖网络或付费模型；AI 配画是可选增强。
enum QuoteScene {
  growth,
  courage,
  resilience,
  serenity,
  time,
  affection,
  reflection,
  freedom,
  hope,
  journey,
}

class QuoteFrameTheme {
  const QuoteFrameTheme(this.scene);

  final QuoteScene scene;

  static QuoteFrameTheme resolve({
    required String topic,
    required String quote,
    String note = '',
  }) {
    final title = topic.toLowerCase();
    final body = quote.toLowerCase();
    final explanation = note.toLowerCase();

    const tags = <QuoteScene, List<String>>{
      QuoteScene.growth: ['成长', '学习', '进步', '积累', '树', '生长', '改变', '蜕变', '习惯', '努力', 'growth', 'learn'],
      QuoteScene.courage: ['勇气', '勇敢', '冒险', '挑战', '恐惧', '大胆', '风险', '直面', '面对', 'courage', 'brave', 'fear'],
      QuoteScene.resilience: ['失败', '挫折', '逆境', '困难', '痛苦', '障碍', '坚持', '坚韧', '磨难', '跌倒', '苦难', 'resilience', 'failure'],
      QuoteScene.serenity: ['平静', '宁静', '内心', '接纳', '安宁', '冥想', '专注', '平和', '静心', '心灵', 'peace', 'calm'],
      QuoteScene.time: ['时间', '当下', '现在', '今天', '明天', '昨天', '岁月', '青春', '生命短暂', '及时', 'time', 'moment'],
      QuoteScene.affection: ['爱', '亲情', '友情', '家人', '伴侣', '亲密', '温暖', '善良', '关怀', 'love', 'family'],
      QuoteScene.reflection: ['哲学', '真理', '思考', '智慧', '认识', '理性', '思想', '知识', '灵魂', '自我', 'truth', 'wisdom'],
      QuoteScene.freedom: ['自由', '独立', '选择', '自主', '束缚', '解放', '飞翔', 'freedom', 'liberty'],
      QuoteScene.hope: ['希望', '光明', '未来', '梦想', '信念', '黎明', '太阳', '可能', '理想', 'hope', 'dream'],
      QuoteScene.journey: ['行动', '开始', '第一步', '千里', '道路', '出发', '旅程', '实践', '脚步', '目标', 'action', 'journey'],
    };

    QuoteScene best = QuoteScene.reflection;
    var bestScore = 0;
    for (final entry in tags.entries) {
      int score = 0;
      for (final keyword in entry.value) {
        if (title.contains(keyword)) score += 6;
        if (body.contains(keyword)) score += 3;
        if (explanation.contains(keyword)) score += 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = entry.key;
      }
    }
    return QuoteFrameTheme(best);
  }

  String get label {
    switch (scene) {
      case QuoteScene.growth: return '破土新生';
      case QuoteScene.courage: return '高山远征';
      case QuoteScene.resilience: return '风雨劲松';
      case QuoteScene.serenity: return '静水竹影';
      case QuoteScene.time: return '流沙岁月';
      case QuoteScene.affection: return '春日花枝';
      case QuoteScene.reflection: return '星空求索';
      case QuoteScene.freedom: return '飞鸟旷野';
      case QuoteScene.hope: return '日出地平线';
      case QuoteScene.journey: return '山间小径';
    }
  }

  /// 提供给图片生成模型的场景核心；不要让模型绘制文字。
  String get imageScene {
    switch (scene) {
      case QuoteScene.growth: return 'A young flourishing tree pushing through rocks toward soft sunlight, visual metaphor for growth.';
      case QuoteScene.courage: return 'A majestic mountain ridge with a brave winding ascent, vast sky and strong dramatic light.';
      case QuoteScene.resilience: return 'A pine tree standing through wind and rain, clouds opening to warm light, dignified and hopeful.';
      case QuoteScene.serenity: return 'Still lake, quiet distant mountains, sparse bamboo leaves, peaceful reflections.';
      case QuoteScene.time: return 'Beautiful old hourglass beside a river at dusk, gentle passage of time, contemplative.';
      case QuoteScene.affection: return 'Tender flowering branches in morning sunlight, warmth, care and connection.';
      case QuoteScene.reflection: return 'A distant observatory under constellations and a luminous night sky, philosophical wonder.';
      case QuoteScene.freedom: return 'Birds spreading their wings over an immense open landscape, unobstructed horizon.';
      case QuoteScene.hope: return 'The first golden sunlight rising beyond a distant horizon, soft radiant dawn.';
      case QuoteScene.journey: return 'A small winding trail leading from the foreground into distant luminous mountains.';
    }
  }
}
