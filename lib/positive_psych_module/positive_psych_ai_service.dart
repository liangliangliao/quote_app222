
import '../services/global_ai_settings.dart';
import 'positive_psych_models.dart';
import 'positive_psych_seed.dart';

class PositivePsychAiResult {
  final List<PositivePsychAction> actions;
  final String provider;
  final String modelLabel;
  const PositivePsychAiResult({required this.actions, required this.provider, required this.modelLabel});
}

class PositivePsychAiService {
  final GlobalAiSettings _globalAiSettings = GlobalAiSettings();

  List<PositivePsychAction> previewActionOptions({
    required PositivePsychSegment segment,
    String userConcern = '',
  }) {
    return _buildLocalActions(segment: segment, userConcern: userConcern);
  }

  Future<Map<String, String>> getGlobalAiState() async {
    try {
      return await _globalAiSettings.getState();
    } catch (_) {
      return {'provider': 'none', 'model': 'none', 'label': '未配置（当前先用内置策略）', 'available': '0'};
    }
  }

  Future<PositivePsychAiResult> generateActionOptions({
    required PositivePsychSegment segment,
    required String userConcern,
  }) async {
    final state = await getGlobalAiState();
    final actions = _buildLocalActions(segment: segment, userConcern: userConcern);
    return PositivePsychAiResult(actions: actions, provider: state['provider'] ?? 'local', modelLabel: state['label'] ?? '内置策略');
  }

  String buildReviewSummary({
    required PositivePsychSegment segment,
    required String fact,
    required String thought,
    required String feeling,
    required String action,
    required String result,
  }) {
    final biasTags = detectBiasTags(thought);
    final alt = buildAlternativeInterpretation(segment: segment, fact: fact, thought: thought, feeling: feeling);
    final biasHint = biasTags.isEmpty ? '' : '其中最值得注意的思维偏差线索是：${biasTags.join('、')}。';
    return '你这次围绕「${segment.title}」做了一次现实练习。事实层面：$fact。想法层面：$thought。情绪层面：$feeling。行动层面：$action。结果层面：$result。$biasHint 更完整的替代解释可以是：$alt。下一步建议：保留这次已经更贴近现实的部分，再把行动缩小一点、重复一次，让理解真正进入日常。';
  }


  List<String> buildReviewQuestions({
    required PositivePsychSegment segment,
    required String fact,
    required String thought,
  }) {
    final tags = detectBiasTags(thought);
    return <String>[
      '这次事情里，最靠近客观事实的一句话是什么？',
      '你最先跳出来的解释是什么？它和事实是同一回事吗？',
      if (tags.contains('Magnifying')) '你是不是把一次具体事件夸大成了对整个人或整段未来的判断？',
      if (tags.contains('Minimizing')) '你是不是忽略了已经存在的资源、进展或积极面？',
      if (tags.contains('Making up')) '你是不是从感受直接跳到了结论，中间少了证据检查？',
      '如果要把这次经历讲得更完整，你会怎样重写它？',
      '下一次再遇到类似情境时，你最想保留的一个动作是什么？',
    ];
  }

  String buildCoachNote(PositivePsychSegment segment) {
    if (segment.id == 'pp_l7_7' || segment.id == 'pp_l7_8') {
      return '这段最适合在你已经被自动想法带跑时使用：先停下来，检查 3M，再补一个更贴近证据的解释。';
    }
    if (segment.id == 'pp_l8_9' || segment.id == 'pp_l9_4') {
      return '这段最适合在你已经把某个人、某段关系或某个片刻视为理所当然时使用：把感谢说具体，而不是只说谢谢。';
    }
    if (segment.id == 'pp_l9_6' || segment.id == 'pp_l9_7') {
      return '这段最适合在你既有痛苦又有美好体验时使用：负面用理解，积极用重温，不要混用。';
    }
    if (segment.lecture == 7) {
      return '这段更适合用在失败、自责、过度担心和卡在解释层的时刻。';
    }
    if (segment.lecture == 8) {
      return '这段更适合用在忽略资源、把已有关系与美好视为理所当然的时刻。';
    }
    return '这段更适合用在需要表达、整合体验和把一次经历沉淀成长期成长线索的时候。';
  }

  List<String> detectBiasTags(String text) {
    final t = text.trim();
    final tags = <String>[];
    if (t.isEmpty) return tags;
    if (t.contains('总是') || t.contains('彻底') || t.contains('永远') || t.contains('完了')) tags.add('Magnifying');
    if (t.contains('没什么') || t.contains('不算') || t.contains('都不重要') || t.contains('只是小事')) tags.add('Minimizing');
    if (t.contains('一定是我不好') || t.contains('肯定没人会') || t.contains('因为我感觉') || t.contains('说明我就是')) tags.add('Making up');
    return tags;
  }

  String buildAlternativeInterpretation({
    required PositivePsychSegment segment,
    required String fact,
    required String thought,
    required String feeling,
  }) {
    final biases = detectBiasTags(thought);
    final factText = fact.trim().isEmpty ? '这次事情里有一部分事实还需要先写清楚' : fact.trim();
    if (biases.contains('Magnifying')) {
      return '先回到事实：$factText。这更像是一次具体事件，而不是对整个人下结论。你现在感到${feeling.trim().isEmpty ? '不舒服' : feeling.trim()}，但这并不等于未来会一直如此。下一步是处理这一次，而不是宣布全部失败。';
    }
    if (biases.contains('Minimizing')) {
      return '先承认事实：$factText。这里既有值得看见的积极部分，也有不能忽略的真实困难。更完整的做法不是一笔带过，而是同时把资源和问题都写下来。';
    }
    if (biases.contains('Making up')) {
      return '先区分事实和推断：$factText。你现在的想法更像从感受直接跳到了结论。更完整的解释是：我现在有这种感觉，但还需要更多证据，才能判断它到底说明什么。';
    }
    return '先把事实说清楚：$factText。再把想法、情绪和下一步行动分开看。更完整的解释不是自我安慰，而是在承认现实的同时，保留行动空间。';
  }

  String _guessBias(String text) {
    final t = text.trim();
    if (t.isEmpty) return '';
    if (t.contains('总是') || t.contains('彻底') || t.contains('永远') || t.contains('完了')) return '可能有夸大（Magnifying）';
    if (t.contains('没什么') || t.contains('不算') || t.contains('都不重要')) return '可能有缩小积极面（Minimizing）';
    if (t.contains('一定是我不好') || t.contains('肯定没人会') || t.contains('因为我感觉')) return '可能有编造式推断（Making up）';
    return '';
  }

  List<PositivePsychAction> _buildLocalActions({required PositivePsychSegment segment, required String userConcern}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final concern = userConcern.trim().isEmpty ? '当前先按课程默认动作来练。' : userConcern.trim();
    final baseSteps = _buildSegmentSpecificSteps(segment);
    return <PositivePsychAction>[
      PositivePsychAction(
        id: 'ppa_${segment.id}_min_$now',
        segmentId: segment.id,
        segmentTitle: segment.title,
        level: 'min',
        source: 'local',
        title: '最小动作｜${segment.defaultActionTitle}',
        body: '围绕你的困扰「$concern」，先做一个最小版本：${segment.defaultActionBody}',
        steps: <String>[baseSteps.first, if (baseSteps.length > 1) baseSteps[1]],
        successCriteria: '今天能真正开始，并留下 1 条事实记录。',
        fallbackAction: '如果做不完整，就只完成第一步。',
        reviewQuestion: segment.reflectionQuestion,
        createdAt: now,
      ),
      PositivePsychAction(
        id: 'ppa_${segment.id}_std_$now',
        segmentId: segment.id,
        segmentTitle: segment.title,
        level: 'standard',
        source: 'local',
        title: '标准动作｜${segment.defaultActionTitle}',
        body: '${segment.defaultActionBody}\n\n请把它明确地关联到你的现实困扰：$concern',
        steps: baseSteps,
        successCriteria: '完成一次完整练习，并能写出一个新的理解。',
        fallbackAction: '如果遇到阻碍，把动作压缩到 10 分钟。',
        reviewQuestion: segment.reflectionQuestion,
        createdAt: now + 1,
      ),
      PositivePsychAction(
        id: 'ppa_${segment.id}_cha_$now',
        segmentId: segment.id,
        segmentTitle: segment.title,
        level: 'challenge',
        source: 'local',
        title: '挑战动作｜把它带入真实场景',
        body: '把这段课程真正带进一个现实场景：$concern。不是只写下来，而是在事情发生时当场使用。',
        steps: <String>[...baseSteps, '在真实场景里用一次新做法', '结束后写复盘'],
        successCriteria: '在现实场景里完成一次迁移应用。',
        fallbackAction: '如果真实场景难度太大，就先在脑中预演后再做。',
        reviewQuestion: segment.reflectionQuestion,
        createdAt: now + 2,
      ),
    ];
  }


  List<String> _buildSegmentSpecificSteps(PositivePsychSegment segment) {
    final defaults = segment.howSteps.isNotEmpty ? segment.howSteps : <String>['写下事实', '尝试一个新解释', '把它带回现实'];
    if (segment.id == 'pp_l7_1') {
      return <String>['先把这次事件的客观事实写清楚', '写出你的自动解释，再补一个更完整解释', '比较三种解释带来的情绪与行动差异'];
    }
    if (segment.id == 'pp_l7_7' || segment.id == 'pp_l7_8') {
      return <String>['先圈出你这次最强的自动想法', '检查它是否属于 Magnifying、Minimizing 或 Making up', '补一个更贴近证据与现实的解释，并决定下一步'];
    }
    if (segment.id == 'pp_l8_4') {
      return <String>['选一个你常常只盯着问题的关系或合作对象', '补写对方正在发挥作用的一个具体部分', '做一次具体欣赏表达，并观察关系气氛是否变化'];
    }
    if (segment.id == 'pp_l8_8') {
      return <String>['先做一次“如果暂时失去它会怎样”的反向想象', '把你当前已拥有却常忽略的价值写下来', '当天就做一个珍惜动作，而不是只停在感慨'];
    }
    if (segment.id == 'pp_l8_9' || segment.id == 'pp_l9_4') {
      return <String>['明确一个你原本视为理所当然的人或对象', '写出具体感谢内容，而不是泛泛表示谢谢', '完成一次表达或重温，并记录前后状态'];
    }
    if (segment.id == 'pp_l9_2') {
      return <String>['把今天的练习缩小到一定能完成的程度', '连续做一次，不追求完美', '把这次持续而非爆发的经验记录下来'];
    }
    if (segment.id == 'pp_l9_9') {
      return <String>['选一个你每天都会看到的提醒物', '把它和一次感恩停顿绑定', '连续使用几天，再看它是否改变了你的注意力'];
    }
    if (segment.id == 'pp_l7_13' || segment.id == 'pp_l7_14') {
      return <String>['先把当前危机或受限处境写成事实', '补写它正在逼你练习什么能力', '决定一个你仍然能主动改变的小地方'];
    }
    if (segment.id == 'pp_l7_15') {
      return <String>['先按“找错者”版本重写这段经历', '再按“找益者”版本重写一遍', '最后写一个更完整、更真实的第三版叙事'];
    }
    if (segment.id == 'pp_l9_6' || segment.id == 'pp_l9_7') {
      return <String>['对负面经历做理解和书写', '对积极经历做重温和回放', '比较两种处理方式给你带来的不同效果'];
    }
    if (segment.lecture == 7) {
      if (segment.title.contains('行动')) {
        return <String>['选一个轻微有挑战但可执行的现实任务', '只做第一步并留下事实记录', '记录完成后自我效能感的变化'];
      }
      if (segment.title.contains('失败')) {
        return <String>['写下这次失败的客观事实', '写出它训练了你什么心理免疫力', '补一个下次可尝试的更小行动'];
      }
      if (segment.title.contains('想象') || segment.title.contains('可视化')) {
        return <String>['先想象成功结果', '再想象你一步步如何做到', '把第一步立刻带回现实'];
      }
      if (segment.title.contains('认知')) {
        return <String>['把事件、解释、情绪、行动分开写', '检查有没有 3M 偏差', '写一个更完整解释并执行一个新动作'];
      }
    }
    if (segment.lecture == 8) {
      if (segment.title.contains('感恩') || segment.scene.contains('感恩')) {
        return <String>['写下一个原本视为理所当然的对象', '具体写出你为何感激它', '尝试表达或重温这份积极体验'];
      }
      if (segment.title.contains('负面') || segment.title.contains('注意力')) {
        return <String>['先标记你今天盯住了什么负面点', '补写同一情境里的资源与有效部分', '决定一个更平衡的下一步'];
      }
    }
    if (segment.lecture == 9) {
      if (segment.title.contains('表达') || segment.title.contains('拜访')) {
        return <String>['明确一个你想感谢的人', '写出具体感谢内容而不是泛泛说谢谢', '通过文字、电话或当面完成表达'];
      }
      if (segment.title.contains('积极体验') || segment.title.contains('消极体验')) {
        return <String>['对负面经历做理解与书写', '对积极经历做重温与回放', '比较两种处理方式带来的效果'];
      }
    }
    return defaults;
  }

  PositivePsychSegment recommendTodaySegment({required Set<String> completedSegments, required List<PositivePsychReview> reviews}) {
    if (reviews.isNotEmpty) {
      final latest = reviews.first.segmentId;
      final idx = positivePsychSegments.indexWhere((e) => e.id == latest);
      if (idx >= 0 && idx + 1 < positivePsychSegments.length) return positivePsychSegments[idx + 1];
    }
    for (final seg in positivePsychSegments) {
      if (!completedSegments.contains(seg.id)) return seg;
    }
    return positivePsychSegments[DateTime.now().day % positivePsychSegments.length];
  }
}
