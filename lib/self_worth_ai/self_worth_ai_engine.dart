/// Product-level engine and coverage registry for “真实自尊 SelfWorth AI”.
///
/// This file intentionally stays inside the standalone self_worth_ai module. It
/// turns the product design into explicit source-code capability definitions so
/// UI, prompt settings, AI calls, audits, and future persistence can all refer to
/// the same catalog instead of relying on scattered static copy.
class SelfWorthAiEngine {
  const SelfWorthAiEngine();

  static const String evidenceLoop = '现实事件触发 → 记录感受 → 识别自尊模式 → 事实与解释分离 → 价值重构 → 具体行动 → 执行 → 复盘 → 稳定自尊证据库';

  String sceneForFeature(SelfWorthFeatureSpec feature) {
    final text = '${feature.title}${feature.outputs.join()}${feature.moduleId}';
    if (text.contains('失败') || text.contains('人格保护')) return 'failure';
    if (text.contains('关系') || text.contains('冲突') || text.contains('Love') || text.contains('建设性回应')) return 'relationship_conflict';
    if (text.contains('比较') || text.contains('嫉妒')) return 'comparison';
    if (text.contains('身体') || text.contains('外貌') || text.contains('媒体')) return 'body_shame';
    if (text.contains('边界') || text.contains('说“不”') || text.contains('自我主张')) return 'boundary';
    if (text.contains('目标') || text.contains('拖延')) return 'goal_delay';
    if (text.contains('接纳') || text.contains('负面情绪') || text.contains('允许自己是人')) return 'self_acceptance';
    if (text.contains('主动建设性')) return 'active_constructive';
    if (text.contains('诚信') || text.contains('真实表达')) return 'integrity';
    if (text.contains('批评')) return 'criticism';
    if (text.contains('责任') || text.contains('抱怨')) return 'responsibility_review';
    return 'external_validation';
  }

  String outputModeForScene(String scene) {
    switch (scene) {
      case 'failure':
        return 'failure';
      case 'relationship_conflict':
        return 'relationship';
      case 'comparison':
        return 'comparison';
      case 'body_shame':
        return 'body';
      case 'boundary':
      case 'integrity':
        return 'expression';
      default:
        return 'common';
    }
  }

  String localActionCard({
    required String scene,
    required String userInput,
    SelfWorthFeatureSpec? feature,
  }) {
    final title = feature == null ? '自尊行动卡' : feature.title;
    final action = _actionForScene(scene);
    if (scene == 'failure') {
      return '''## 失败事件\n$userInput\n\n## 情绪命名\n你可能感到失望、羞耻、焦虑或无力。\n\n## 事实\n实际发生的是一个结果或行为问题，不是整个人格的判决。\n\n## 不应得出的结论\n这件事不能证明“我没有价值”或“我是失败者”。\n\n## 可以学习的部分\n复盘策略、准备、沟通、资源和下一次实验。\n\n## 人格价值保护句\n我可以为行为负责，但不需要摧毁自我价值。\n\n## 下一步最小行动\n$action\n\n## 复盘问题\n下次我可以怎样准备得更好？''';
    }
    if (scene == 'relationship_conflict') {
      return '''## 当前冲突\n$userInput\n\n## 你真正的需求\n你可能需要被了解、被尊重、被看见、被认真回应或被允许表达边界。\n\n## 你可能在寻求\n被认可 / 被了解 / 被安抚 / 被尊重 / 被看见。\n\n## 不建议的表达\n“你从来不在乎我”“算了我没事”“都是我的错”。\n\n## 更真实的表达\n我想更真实地说：这件事让我有些失落/紧张，我需要的是……我希望我们能……\n\n## 修复行动\n$action\n\n## 关系提醒\n有冲突不等于关系失败，关键是是否能真实表达与修复。''';
    }
    if (scene == 'comparison') {
      return '''## 我在比较什么\n$userInput\n\n## 我把对方成功解释成了什么\n可能解释成：他成功 = 我失败 / 他被爱 = 我不值得 / 他领先 = 我落后。\n\n## 更真实的解释\n对方成功不减少我的价值，它可能暴露了我尚未承认的愿望。\n\n## 这个嫉妒暴露的愿望\n我也想拥有某种成长、自由、关系、能力、安全或表达。\n\n## 转化为我的行动\n$action\n\n## 祝福练习\n我可以承认对方在某一点上确实努力或幸运。\n\n## 回到自己\n我下一步回到自己的价值、节奏和行动。''';
    }
    if (scene == 'body_shame') {
      return '''## 触发来源\n$userInput\n\n## 我把身体等同于了什么\n可能等同于价值、被爱资格、社交资格或自信资格。\n\n## 重新区分\n身体外貌 ≠ 人格价值；身体状态 ≠ 是否值得被爱。\n\n## 身体照顾行动\n$action\n\n## 媒体标准拆解\n这个标准可能来自修图、滤镜、商业营销、稀有样本、年龄焦虑、身材羞耻或消费主义承诺。\n\n## 自我接纳句\n我的身体值得被照顾，不是因为它符合标准，而是因为它承载我的生命。''';
    }
    if (scene == 'boundary' || scene == 'integrity') {
      return '''## 我原本想说\n$userInput\n\n## 这句话可能隐藏了什么\n真实情绪、真实需求、害怕冲突、害怕让人失望或想被喜欢。\n\n## 更诚实但不攻击的表达\n我刚才/我原本想说得更清楚一点：我真实的想法是……我希望……\n\n## 边界或请求\n$action\n\n## 发送前检查\n这句话是否真实？是否尊重自己？是否攻击对方？是否表达了具体请求？''';
    }
    return '''## $title\n$userInput\n\n## 你现在可能正在经历什么\n一个现实事件触发了外部认可、比较、关系、目标、身体或责任层面的自尊波动。\n\n## 事实与解释分离\n事实：发生了一个有限事件。\n解释：我可能把它扩大为“我不够好/不值得/失败了”。\n\n## 自尊模式识别\n当前可能是依赖型自尊被触发，正在练习转向独立型自尊或无条件自尊。\n\n## 价值重构\n我的价值不等于这次评价、结果、关系反应或比较。我可以为行为负责，但不否定人格。\n\n## 今天的一个具体行动\n$action\n\n## 一句话练习\n我愿意把价值从外界评价中收回，放回真实、责任和行动里。\n\n## 复盘问题\n我今天哪里更真实？哪里更负责？哪里更少依赖外界认可？''';
  }

  String _actionForScene(String scene) {
    switch (scene) {
      case 'external_validation':
        return '24小时不主动索要评价、不反复查看点赞；做一件符合价值但无人知道的事。';
      case 'failure':
        return '用10分钟写下事实、可改进行为和下一次策略。';
      case 'relationship_conflict':
        return '发送一句真实但不攻击的话，并提出一个具体修复请求。';
      case 'comparison':
        return '写下羡慕暴露的愿望，祝福对方一点，然后为自己的愿望行动15分钟。';
      case 'body_shame':
        return '做一次身体照顾：散步、拉伸、喝水、睡眠准备或认真吃饭。';
      case 'boundary':
        return '练习一句温和边界：谢谢你想到我，但我这次不能接。';
      case 'goal_delay':
        return '把目标降到5分钟能开始的一步，先行动再复盘。';
      case 'self_acceptance':
        return '命名情绪，允许它存在，然后做一个温和行动。';
      case 'active_constructive':
        return '追问对方好消息的一个细节，并提出一个小庆祝。';
      case 'integrity':
        return '修复一句不真实表达：我刚才说都可以，其实我更希望……';
      case 'criticism':
        return '把批评分成有效反馈、情绪攻击、模糊评价、投射/偏见，只接收可行动部分。';
      case 'responsibility_review':
        return '把一个抱怨转成具体请求、可负责行动和清晰边界。';
      default:
        return '选择一个5-30分钟内能完成的小行动。';
    }
  }
}

class SelfWorthModuleSpec {
  final String id;
  final String title;
  final String purpose;
  final List<String> featureIds;
  const SelfWorthModuleSpec({required this.id, required this.title, required this.purpose, required this.featureIds});
}

class SelfWorthFeatureSpec {
  final String id;
  final String moduleId;
  final String title;
  final String goal;
  final List<String> inputs;
  final List<String> aiSteps;
  final List<String> outputs;
  final List<String> actions;
  const SelfWorthFeatureSpec({required this.id, required this.moduleId, required this.title, required this.goal, required this.inputs, required this.aiSteps, required this.outputs, required this.actions});
}

class SelfWorthProductRegistry {
  static const modules = <SelfWorthModuleSpec>[
    SelfWorthModuleSpec(id: 'map', title: '自尊地图', purpose: '认识我的自尊结构', featureIds: ['source_scan', 'stability_log', 'dependency_triggers', 'portrait_report']),
    SelfWorthModuleSpec(id: 'three_layers', title: '三层自尊训练', purpose: '依赖型、独立型、无条件自尊递进训练', featureIds: ['applause_dependency', 'comparison_chain', 'validation_detox_24h', 'inner_standard_card', 'weekly_progress_review', 'process_win_log', 'non_comparison', 'failure_personhood_protection', 'movie_lens']),
    SelfWorthModuleSpec(id: 'relationship_lab', title: '真实关系实验室', purpose: '被了解，而不是只求被认可', featureIds: ['authentic_expression_editor', 'relationship_self_worth_check', 'response_type_classifier', 'active_constructive_generator', 'positive_interaction_ratio', 'conflict_repair', 'beautiful_enemy', 'love_boosters']),
    SelfWorthModuleSpec(id: 'six_practices', title: '六项自尊实践', purpose: '把自尊做出来', featureIds: ['integrity_check', 'one_sentence_repair', 'emotion_need_value', 'trigger_map', 'self_concordant_goal', 'value_action_roadmap', 'no_one_is_coming', 'complaint_to_action', 'permission_to_be_human', 'depersonalize_failure', 'say_no', 'say_yes']),
    SelfWorthModuleSpec(id: 'detox', title: '外部认可与比较戒断', purpose: '从掌声、排名、外貌中拿回自我', featureIds: ['applause_addiction_scan', 'comparison_object_breakdown', 'success_transformer', 'body_shame_reframe', 'media_standard_deconstruction']),
    SelfWorthModuleSpec(id: 'resilience', title: '心理免疫与复原力', purpose: '面对失败、焦虑和批评', featureIds: ['criticism_processor', 'failure_recovery_flow', 'body_action_walk', 'stretch_sleep_breath', 'post_exercise_self_worth']),
    SelfWorthModuleSpec(id: 'responsibility', title: '价值目标与责任系统', purpose: '没人会替我活我的人生', featureIds: ['life_responsibility_wheel', 'goal_fourfold_review', 'weekly_responsibility_review']),
    SelfWorthModuleSpec(id: 'scenario_coach', title: 'AI 场景教练', purpose: '把课程价值应用到每日现实问题', featureIds: ['intimacy_scene', 'friend_scene', 'family_scene', 'work_scene', 'study_scene', 'social_media_scene', 'appearance_scene', 'failure_scene', 'repair_scene', 'procrastination_scene', 'self_attack_scene', 'jealousy_scene', 'boundary_scene', 'opportunity_scene']),
  ];

  static const features = <SelfWorthFeatureSpec>[
    SelfWorthFeatureSpec(id: 'source_scan', moduleId: 'map', title: '自尊来源扫描', goal: '识别自尊来源', inputs: ['认可', '成就', '关系', '外貌', '比较', '内在标准', '无条件接纳'], aiSteps: ['计算来源权重', '指出依赖风险', '给出训练重点'], outputs: ['来源雷达', '主导模式'], actions: ['完成一次来源滑块自评']),
    SelfWorthFeatureSpec(id: 'stability_log', moduleId: 'map', title: '自尊稳定度记录', goal: '记录自尊波动而非排名', inputs: ['评价波动', '成就否定', '比较焦虑', '价值行动', '真实表达'], aiSteps: ['生成稳定曲线', '识别波动场景'], outputs: ['自尊稳定度', '行动一致度'], actions: ['每日复盘3问']),
    SelfWorthFeatureSpec(id: 'dependency_triggers', moduleId: 'map', title: '依赖型触发器', goal: '总结最易操控自我价值的触发器', inputs: ['人', '场景', '比较', '失败', '赞美'], aiSteps: ['归类触发器', '生成替代解释'], outputs: ['触发器地图'], actions: ['为一个触发器设计替代行动']),
    SelfWorthFeatureSpec(id: 'portrait_report', moduleId: 'map', title: '自尊画像报告', goal: '输出主导模式、风险、优势、下周重点', inputs: ['来源扫描', '证据库', '复盘'], aiSteps: ['判定依赖型/独立型/转化中/无条件萌芽'], outputs: ['周画像报告'], actions: ['选择下周训练重点']),
    SelfWorthFeatureSpec(id: 'applause_dependency', moduleId: 'three_layers', title: '外界掌声依赖检测', goal: '识别我把价值交给了谁', inputs: ['事件事实', '我的解释', '期待的认可'], aiSteps: ['事实解释分离', '识别价值托付对象', '给独立解释'], outputs: ['掌声依赖卡'], actions: ['做一件无人知道但有价值的事']),
    SelfWorthFeatureSpec(id: 'comparison_chain', moduleId: 'three_layers', title: '比较链拆解', goal: '拆解他人成功=我失败', inputs: ['比较对象', '比较维度', '羡慕愿望'], aiSteps: ['识别愿望', '转成目标', '生成行动'], outputs: ['比较转行动卡'], actions: ['祝福别人一点并行动15分钟']),
    SelfWorthFeatureSpec(id: 'validation_detox_24h', moduleId: 'three_layers', title: '24小时认可戒断', goal: '减少对反馈的即时依赖', inputs: ['点赞检查', '索要评价', '炫耀冲动'], aiSteps: ['识别成瘾循环', '设计替代行为'], outputs: ['戒断任务'], actions: ['24小时不查反馈']),
    SelfWorthFeatureSpec(id: 'inner_standard_card', moduleId: 'three_layers', title: '内在标准卡片', goal: '建立内在评价标准', inputs: ['诚实', '责任', '成长', '身体尊重', '真实需求'], aiSteps: ['把价值转行为'], outputs: ['标准卡'], actions: ['选择一个今日标准']),
    SelfWorthFeatureSpec(id: 'weekly_progress_review', moduleId: 'three_layers', title: '自我进步复盘', goal: '从赢过谁转向比上周更真实', inputs: ['真实', '稳定', '负责', '自由'], aiSteps: ['纵向比较', '证据沉淀'], outputs: ['周复盘'], actions: ['写一条成长证据']),
    SelfWorthFeatureSpec(id: 'process_win_log', moduleId: 'three_layers', title: '过程胜利日志', goal: '记录不依赖结果的胜利', inputs: ['没讨好', '说真话', '运动', '拒绝不合理要求'], aiSteps: ['提取身份+', '沉淀证据'], outputs: ['过程胜利'], actions: ['记录一个过程胜利']),
    SelfWorthFeatureSpec(id: 'non_comparison', moduleId: 'three_layers', title: '不比较练习', goal: '把成功看作可能性而非威胁', inputs: ['嫉妒', '羡慕', '威胁感'], aiSteps: ['祝福', '愿望识别', '行动'], outputs: ['不比较练习卡'], actions: ['祝福+行动']),
    SelfWorthFeatureSpec(id: 'failure_personhood_protection', moduleId: 'three_layers', title: '失败后人格保护', goal: '区分事实/行为/能力/人格/价值', inputs: ['失败事件'], aiSteps: ['层级拆分', '人格保护'], outputs: ['失败去人格化卡'], actions: ['调整一个行为']),
    SelfWorthFeatureSpec(id: 'movie_lens', moduleId: 'three_layers', title: '电影视角练习', goal: '像看电影一样共情自己', inputs: ['主角经历', '害怕', '需要理解'], aiSteps: ['旁观者共情', '下一幕行动'], outputs: ['电影视角卡'], actions: ['写下一幕小行动']),
    SelfWorthFeatureSpec(id: 'authentic_expression_editor', moduleId: 'relationship_lab', title: '真实表达编辑器', goal: '把讨好型表达改为真实表达', inputs: ['原句', '隐藏情绪', '具体请求'], aiSteps: ['识别讨好', '重写表达'], outputs: ['真实话术'], actions: ['发送或演练一次']),
    SelfWorthFeatureSpec(id: 'relationship_self_worth_check', moduleId: 'relationship_lab', title: '关系中的自尊检查', goal: '识别是否用关系证明价值', inputs: ['隐藏感受', '害怕冲突', '把反对当不爱'], aiSteps: ['自尊模式识别'], outputs: ['关系自尊检查'], actions: ['表达一个真实需求']),
    SelfWorthFeatureSpec(id: 'response_type_classifier', moduleId: 'relationship_lab', title: '四类回应识别', goal: '判断回应是破坏还是建设', inputs: ['我的回应', '对方好消息'], aiSteps: ['分类'], outputs: ['回应类型'], actions: ['改写为主动建设性回应']),
    SelfWorthFeatureSpec(id: 'active_constructive_generator', moduleId: 'relationship_lab', title: '主动建设性回应生成器', goal: '放大对方的积极事件', inputs: ['好消息'], aiSteps: ['生成追问', '庆祝行动'], outputs: ['回应话术'], actions: ['追问一个细节']),
    SelfWorthFeatureSpec(id: 'positive_interaction_ratio', moduleId: 'relationship_lab', title: '关系积极互动比例', goal: '记录欣赏、修复和微亲密行为', inputs: ['积极回应', '欣赏', '修复', '微亲密'], aiSteps: ['关系投入复盘'], outputs: ['互动记录'], actions: ['做一个微亲密动作']),
    SelfWorthFeatureSpec(id: 'conflict_repair', moduleId: 'relationship_lab', title: '冲突修复训练', goal: '冲突后修复而非判死刑', inputs: ['冲突事件', '真实需求'], aiSteps: ['修复话术', '边界判断'], outputs: ['修复卡'], actions: ['提出一个修复请求']),
    SelfWorthFeatureSpec(id: 'beautiful_enemy', moduleId: 'relationship_lab', title: '美丽的敌人练习', goal: '区分攻击、否定、挑战、帮助成长、不同需求', inputs: ['对方挑战'], aiSteps: ['关系辨析'], outputs: ['挑战转成长卡'], actions: ['问一个澄清问题']),
    SelfWorthFeatureSpec(id: 'love_boosters', moduleId: 'relationship_lab', title: '日常 Love Boosters', goal: '30秒关系行动', inputs: ['感谢', '拥抱', '短信', '认真听', '庆祝'], aiSteps: ['生成今日动作'], outputs: ['Love Booster'], actions: ['30秒关系投入']),
    SelfWorthFeatureSpec(id: 'integrity_check', moduleId: 'six_practices', title: '今日真实度检查', goal: '减少小谎、表演、讨好、夸大', inputs: ['不真实话', '夸大', '隐藏需求'], aiSteps: ['诚信复盘'], outputs: ['真实度报告'], actions: ['修复一句话']),
    SelfWorthFeatureSpec(id: 'one_sentence_repair', moduleId: 'six_practices', title: '一句话修复', goal: '生成真实但不攻击的表达', inputs: ['刚才的话', '真实偏好'], aiSteps: ['话术重写'], outputs: ['修复话术'], actions: ['表达真实偏好']),
    SelfWorthFeatureSpec(id: 'emotion_need_value', moduleId: 'six_practices', title: '情绪—需求—价值三段式', goal: '从情绪看到需求和价值', inputs: ['困扰'], aiSteps: ['情绪命名', '需求识别', '价值连接'], outputs: ['觉察卡'], actions: ['诚实表达一个需求']),
    SelfWorthFeatureSpec(id: 'trigger_map', moduleId: 'six_practices', title: '触发器地图', goal: '长期总结触发人、评价、场景、失败', inputs: ['触发记录'], aiSteps: ['模式总结'], outputs: ['触发地图'], actions: ['选择一个替代回应']),
    SelfWorthFeatureSpec(id: 'self_concordant_goal', moduleId: 'six_practices', title: '自我一致目标设计', goal: '区分自己的目标和别人期待', inputs: ['目标', '价值', '无人知道仍愿意吗'], aiSteps: ['目标审查'], outputs: ['自我一致目标'], actions: ['今日最小行动']),
    SelfWorthFeatureSpec(id: 'value_action_roadmap', moduleId: 'six_practices', title: '价值—行动路线图', goal: '长期价值→90天→每周→今日→复盘', inputs: ['长期价值', '90天目标'], aiSteps: ['拆解路线'], outputs: ['行动路线图'], actions: ['完成今日最小行动']),
    SelfWorthFeatureSpec(id: 'no_one_is_coming', moduleId: 'six_practices', title: 'No one is coming 责任卡', goal: '别人可支持但不能替我生活', inputs: ['等待被拯救处'], aiSteps: ['责任温和提醒'], outputs: ['责任卡'], actions: ['负责一个小选择']),
    SelfWorthFeatureSpec(id: 'complaint_to_action', moduleId: 'six_practices', title: '抱怨转行动转换器', goal: '把抱怨转为控制/负责/表达/请求/边界', inputs: ['抱怨'], aiSteps: ['控制圈拆分'], outputs: ['行动转换卡'], actions: ['提出一个具体请求']),
    SelfWorthFeatureSpec(id: 'permission_to_be_human', moduleId: 'six_practices', title: '允许自己是人', goal: '接纳情绪而不放任行为', inputs: ['羞愧', '焦虑', '失败'], aiSteps: ['人类共同体验', '温和行动'], outputs: ['接纳卡'], actions: ['做一个温和行动']),
    SelfWorthFeatureSpec(id: 'depersonalize_failure', moduleId: 'six_practices', title: '失败去人格化', goal: '把“我是废物”改为行为可调整', inputs: ['自我攻击句'], aiSteps: ['事实行为人格价值拆分'], outputs: ['去人格化话术'], actions: ['调整一个策略']),
    SelfWorthFeatureSpec(id: 'say_no', moduleId: 'six_practices', title: '说“不”训练', goal: '温和清楚地设边界', inputs: ['请求', '资源限制'], aiSteps: ['边界话术'], outputs: ['拒绝话术'], actions: ['练习一次小拒绝']),
    SelfWorthFeatureSpec(id: 'say_yes', moduleId: 'six_practices', title: '说“是”训练', goal: '承认渴望和争取机会', inputs: ['机会', '愿望'], aiSteps: ['争取话术'], outputs: ['说是话术'], actions: ['表达一个愿望']),
    SelfWorthFeatureSpec(id: 'applause_addiction_scan', moduleId: 'detox', title: '掌声成瘾识别', goal: '识别反馈检查和确认依赖', inputs: ['消息检查', '点赞', '冷淡后自否'], aiSteps: ['成瘾循环识别'], outputs: ['掌声成瘾报告'], actions: ['24小时反馈戒断']),
    SelfWorthFeatureSpec(id: 'comparison_object_breakdown', moduleId: 'detox', title: '比较对象拆解', goal: '拆解同辈压力和高光比较', inputs: ['买房结婚升职等比较'], aiSteps: ['幕后/高光区分'], outputs: ['比较拆解卡'], actions: ['转化为一个目标']),
    SelfWorthFeatureSpec(id: 'success_transformer', moduleId: 'detox', title: '他人成功转化器', goal: '把嫉妒转成信息、灵感、愿望、行动、祝福', inputs: ['他人成功'], aiSteps: ['五步转化'], outputs: ['成功转化卡'], actions: ['祝福+行动']),
    SelfWorthFeatureSpec(id: 'body_shame_reframe', moduleId: 'detox', title: '身体羞耻重构', goal: '身体值得照顾而非惩罚', inputs: ['身体羞耻句'], aiSteps: ['标准来源', '价值区分'], outputs: ['身体重构卡'], actions: ['身体照顾行动']),
    SelfWorthFeatureSpec(id: 'media_standard_deconstruction', moduleId: 'detox', title: '媒体标准拆解', goal: '识别修图、滤镜、商业营销、稀有样本、年龄焦虑、消费主义', inputs: ['媒体触发'], aiSteps: ['标准拆解'], outputs: ['媒体免疫卡'], actions: ['清理一个触发源']),
    SelfWorthFeatureSpec(id: 'criticism_processor', moduleId: 'resilience', title: '批评处理器', goal: '区分有效反馈、情绪攻击、模糊评价、投射偏见', inputs: ['批评内容'], aiSteps: ['四类归因'], outputs: ['批评处理卡'], actions: ['提取一个可行动建议']),
    SelfWorthFeatureSpec(id: 'failure_recovery_flow', moduleId: 'resilience', title: '失败复原流程', goal: '事实、情绪、行为、价值、下一步', inputs: ['失败事件'], aiSteps: ['五步复原'], outputs: ['复原卡'], actions: ['下一步最小行动']),
    SelfWorthFeatureSpec(id: 'body_action_walk', moduleId: 'resilience', title: '10分钟走路', goal: '通过照顾身体确认值得健康', inputs: ['身体状态'], aiSteps: ['运动后自尊记录'], outputs: ['身体行动记录'], actions: ['走路10分钟']),
    SelfWorthFeatureSpec(id: 'stretch_sleep_breath', moduleId: 'resilience', title: '拉伸/睡眠/呼吸', goal: '恢复心理免疫', inputs: ['疲劳', '睡眠', '呼吸'], aiSteps: ['身体照顾计划'], outputs: ['恢复计划'], actions: ['拉伸或呼吸3分钟']),
    SelfWorthFeatureSpec(id: 'post_exercise_self_worth', moduleId: 'resilience', title: '运动后自尊记录', goal: '记录身体照顾带来的自尊变化', inputs: ['运动后感受'], aiSteps: ['证据沉淀'], outputs: ['身体照顾证据'], actions: ['保存证据']),
    SelfWorthFeatureSpec(id: 'life_responsibility_wheel', moduleId: 'responsibility', title: '人生责任盘', goal: '九领域责任扫描', inputs: ['身体', '关系', '学习', '工作', '财务', '创造', '精神成长', '休息', '贡献'], aiSteps: ['逃避识别', '最小行动'], outputs: ['责任盘'], actions: ['选择一个领域行动']),
    SelfWorthFeatureSpec(id: 'goal_fourfold_review', moduleId: 'responsibility', title: '自我一致目标四重审查', goal: '检查真实价值、证明自己、无人知道、生命力', inputs: ['目标'], aiSteps: ['四重审查'], outputs: ['目标审查'], actions: ['保留/调整/放下']),
    SelfWorthFeatureSpec(id: 'weekly_responsibility_review', moduleId: 'responsibility', title: '每周责任复盘', goal: '承担责任、等待拯救、痛苦转行动、边界、下周一步', inputs: ['一周记录'], aiSteps: ['周复盘'], outputs: ['责任周报'], actions: ['下周最小一步']),
    SelfWorthFeatureSpec(id: 'intimacy_scene', moduleId: 'scenario_coach', title: '亲密关系场景', goal: '真实表达与修复', inputs: ['伴侣事件'], aiSteps: ['关系场景Prompt'], outputs: ['关系行动卡'], actions: ['修复请求']),
    SelfWorthFeatureSpec(id: 'friend_scene', moduleId: 'scenario_coach', title: '朋友关系场景', goal: '互依与边界', inputs: ['朋友事件'], aiSteps: ['场景Prompt'], outputs: ['朋友关系卡'], actions: ['真实表达']),
    SelfWorthFeatureSpec(id: 'family_scene', moduleId: 'scenario_coach', title: '家庭关系场景', goal: '边界与被了解', inputs: ['家庭事件'], aiSteps: ['场景Prompt'], outputs: ['家庭边界卡'], actions: ['边界表达']),
    SelfWorthFeatureSpec(id: 'work_scene', moduleId: 'scenario_coach', title: '职场场景', goal: '反馈与价值分离', inputs: ['职场事件'], aiSteps: ['场景Prompt'], outputs: ['职场行动卡'], actions: ['提取反馈']),
    SelfWorthFeatureSpec(id: 'study_scene', moduleId: 'scenario_coach', title: '学业场景', goal: '失败复盘与目标行动', inputs: ['学业事件'], aiSteps: ['场景Prompt'], outputs: ['学习行动卡'], actions: ['最小学习行动']),
    SelfWorthFeatureSpec(id: 'social_media_scene', moduleId: 'scenario_coach', title: '社交媒体场景', goal: '点赞与外部认可戒断', inputs: ['社媒触发'], aiSteps: ['场景Prompt'], outputs: ['戒断卡'], actions: ['24小时不查反馈']),
    SelfWorthFeatureSpec(id: 'appearance_scene', moduleId: 'scenario_coach', title: '外貌焦虑场景', goal: '身体照顾与媒体免疫', inputs: ['外貌触发'], aiSteps: ['场景Prompt'], outputs: ['身体照顾卡'], actions: ['身体照顾']),
    SelfWorthFeatureSpec(id: 'failure_scene', moduleId: 'scenario_coach', title: '失败复盘场景', goal: '行为负责人格不否定', inputs: ['失败'], aiSteps: ['场景Prompt'], outputs: ['失败卡'], actions: ['复盘行为']),
    SelfWorthFeatureSpec(id: 'repair_scene', moduleId: 'scenario_coach', title: '冲突修复场景', goal: '关系修复', inputs: ['冲突'], aiSteps: ['场景Prompt'], outputs: ['修复卡'], actions: ['修复动作']),
    SelfWorthFeatureSpec(id: 'procrastination_scene', moduleId: 'scenario_coach', title: '目标拖延场景', goal: '今日最小行动', inputs: ['拖延'], aiSteps: ['场景Prompt'], outputs: ['启动卡'], actions: ['5分钟启动']),
    SelfWorthFeatureSpec(id: 'self_attack_scene', moduleId: 'scenario_coach', title: '自我否定场景', goal: '去人格化', inputs: ['自我攻击'], aiSteps: ['场景Prompt'], outputs: ['人格保护卡'], actions: ['改写自我攻击']),
    SelfWorthFeatureSpec(id: 'jealousy_scene', moduleId: 'scenario_coach', title: '嫉妒比较场景', goal: '祝福别人并回到自己', inputs: ['嫉妒'], aiSteps: ['场景Prompt'], outputs: ['比较卡'], actions: ['祝福+行动']),
    SelfWorthFeatureSpec(id: 'boundary_scene', moduleId: 'scenario_coach', title: '需要说“不”场景', goal: '边界表达', inputs: ['请求'], aiSteps: ['场景Prompt'], outputs: ['边界卡'], actions: ['说不练习']),
    SelfWorthFeatureSpec(id: 'opportunity_scene', moduleId: 'scenario_coach', title: '想争取机会场景', goal: '说“是”训练', inputs: ['机会'], aiSteps: ['场景Prompt'], outputs: ['争取卡'], actions: ['表达愿望']),
  ];

  static Map<String, int> coverageByModule() {
    final result = <String, int>{};
    for (final feature in features) {
      result[feature.moduleId] = (result[feature.moduleId] ?? 0) + 1;
    }
    return result;
  }

  static List<String> coverageGaps() {
    final featureIds = features.map((e) => e.id).toSet();
    final gaps = <String>[];
    for (final module in modules) {
      for (final id in module.featureIds) {
        if (!featureIds.contains(id)) gaps.add('${module.title}:$id');
      }
    }
    return gaps;
  }
}
