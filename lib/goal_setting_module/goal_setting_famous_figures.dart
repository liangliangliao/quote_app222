class GoalSettingFamousFigureCatalog {
  static const String noneCategory = '不指定';

  static const Map<String, List<String>> categories = <String, List<String>>{
    '哲学': <String>[
      '苏格拉底', '柏拉图', '亚里士多德', '孔子', '老子', '墨子', '庄子', '笛卡尔', '斯宾诺莎', '洛克',
      '休谟', '卢梭', '康德', '黑格尔', '叔本华', '尼采', '基尔凯郭尔', '马克思', '胡塞尔', '海德格尔',
      '萨特', '梅洛-庞蒂', '维特根斯坦', '汉娜·阿伦特', '福柯', '德勒兹', '哈贝马斯', '罗尔斯', '波普尔', '西蒙娜·德·波伏娃'
    ],
    '心理学': <String>[
      '威廉·詹姆斯', '威廉·冯特', '西格蒙德·弗洛伊德', '卡尔·荣格', '阿尔弗雷德·阿德勒', '伊万·巴甫洛夫', '约翰·华生', 'B.F.斯金纳', '让·皮亚杰', '列夫·维果茨基',
      '卡尔·罗杰斯', '亚伯拉罕·马斯洛', '阿尔伯特·班杜拉', '埃里克·埃里克森', '库尔特·勒温', '阿龙·贝克', '阿尔伯特·埃利斯', '丹尼尔·卡尼曼', '约翰·鲍尔比', '玛丽·安斯沃斯',
      '凯伦·霍妮', '梅兰妮·克莱因', '唐纳德·温尼科特', '维克多·弗兰克尔', '米哈里·契克森米哈赖', '马丁·塞利格曼', '戈登·奥尔波特', '所罗门·阿希', '斯坦利·米尔格拉姆', '菲利普·津巴多'
    ],
    '文学': <String>[
      '荷马', '但丁', '塞万提斯', '莎士比亚', '曹雪芹', '歌德', '简·奥斯汀', '巴尔扎克', '狄更斯', '福楼拜',
      '维克多·雨果', '陀思妥耶夫斯基', '列夫·托尔斯泰', '契诃夫', '亨利·詹姆斯', '普鲁斯特', '卡夫卡', '乔伊斯', '弗吉尼亚·伍尔夫', '威廉·福克纳',
      '博尔赫斯', '加西亚·马尔克斯', '托马斯·曼', '卡缪', '海明威', '莫言', '鲁迅', '巴尔加斯·略萨', '托妮·莫里森', '纳博科夫'
    ],
    '诗人': <String>[
      '屈原', '陶渊明', '王维', '李白', '杜甫', '白居易', '苏轼', '辛弃疾', '但丁', '莎士比亚',
      '歌德', '威廉·华兹华斯', '拜伦', '雪莱', '济慈', '波德莱尔', '惠特曼', '艾米莉·狄金森', '叶芝', 'T.S.艾略特',
      '里尔克', '泰戈尔', '聂鲁达', '保罗·策兰', '安娜·阿赫玛托娃', '兰波', '米沃什', '海子', '北岛', '顾城'
    ],
  };

  static List<String> get categoryNames => <String>[noneCategory, ...categories.keys];

  static List<String> figuresFor(String category) {
    if (category.trim().isEmpty || category == noneCategory) return const <String>[];
    return categories[category] ?? const <String>[];
  }
}


extension GoalSettingFamousFigureCatalogX on GoalSettingFamousFigureCatalog {
  static List<String> figuresForCategories(Iterable<String> categoriesInput) {
    final out = <String>[];
    final seen = <String>{};
    for (final category in categoriesInput) {
      for (final figure in GoalSettingFamousFigureCatalog.figuresFor(category)) {
        if (seen.add(figure)) out.add(figure);
      }
    }
    return out;
  }
}
