import 'todo_failure_growth_models.dart';

class TodoFailureGrowthEngine {
  const TodoFailureGrowthEngine();

  TodoFailureGrowthDraft build({
    required String event,
    required String emotion,
    required String automaticThought,
    required String fearedOutcome,
  }) {
    final combined = '$event $emotion $automaticThought $fearedOutcome'.toLowerCase();
    final pattern = _detectPattern(combined);
    final cleanEvent = event.trim().isEmpty ? '这次行动没有达到预期' : event.trim();
    final fear = fearedOutcome.trim().isEmpty ? '结果不如预期' : fearedOutcome.trim();

    return TodoFailureGrowthDraft(
      patternCode: pattern.$1,
      patternLabel: pattern.$2,
      factStatement: '已知事实：$cleanEvent。尚未被证实的是：这件事足以定义你的能力、价值或未来。',
      growthReframe: _reframe(pattern.$1, fear),
      learningSignal: _learning(pattern.$1),
      recoveryPlan: '即使“$fear”发生，你仍可以先稳定情绪、获得一条具体反馈，再修改一个变量继续尝试。',
      experimentTitle: _experiment(event, pattern.$1),
      minimumStandard: _minimumStandard(pattern.$1),
      reflectionQuestion: '完成后只回答：我获得了什么反馈？下一版只改哪一个变量？',
      valueStatement: '今天的目标不是证明自己，而是创造一个可用于学习的反馈样本。',
    );
  }

  (String, String) _detectPattern(String text) {
    if (_hasAny(text, const ['我完了', '完蛋', '没希望', '最坏', '毁了'])) return ('catastrophizing', '灾难化想象');
    if (_hasAny(text, const ['我就是不行', '我不行', '废物', '失败者', '不适合'])) return ('identity_failure', '身份化失败');
    if (_hasAny(text, const ['别人会', '看不起', '笑我', '丢脸', '评价', '被拒'])) return ('evaluation_fear', '评价与拒绝恐惧');
    if (_hasAny(text, const ['没准备好', '不够完美', '再准备', '必须做到', '完美'])) return ('perfectionism', '完美主义拖延');
    if (_hasAny(text, const ['总是', '从来', '一次都', '要么', '算了'])) return ('black_white', '非黑即白');
    if (_hasAny(text, const ['自责', '讨厌自己', '恨自己', '羞耻'])) return ('self_attack', '自我攻击');
    return ('feedback_gap', '反馈缺口');
  }

  bool _hasAny(String text, List<String> words) => words.any(text.contains);

  String _reframe(String pattern, String fear) {
    switch (pattern) {
      case 'catastrophizing':
        return '“$fear”是一个需要准备的风险，不是已经发生的人生结论。把最坏结果改写为可应对步骤。';
      case 'identity_failure':
        return '这次结果描述的是某个行为、策略或情境，不是“你是谁”。身份判断要退回到可修改的行动反馈。';
      case 'evaluation_fear':
        return '他人的一次反馈只说明当前匹配度或表达效果，不等于对你整个人的终审。';
      case 'perfectionism':
        return '先交付一个 70 分、可被反馈的版本，比在脑中等待 100 分更接近卓越。';
      case 'black_white':
        return '成长允许部分完成、暂停和重启；一次未完成不取消此前积累，也不决定下一次。';
      case 'self_attack':
        return '先像支持朋友一样支持自己：你可以失望，但不需要靠攻击自己来换取进步。';
      default:
        return '现在缺少的不是人格结论，而是一条更具体的现实反馈。先用小实验补齐信息。';
    }
  }

  String _learning(String pattern) {
    switch (pattern) {
      case 'evaluation_fear':
        return '需要验证的是：对方真正反馈了什么、哪些只是你的推测，以及怎样降低下一次暴露的风险。';
      case 'perfectionism':
        return '需要验证的是：最小可提交版本是什么，以及真实反馈是否比继续准备更有价值。';
      case 'catastrophizing':
        return '需要验证的是：最坏结果的真实概率、可恢复性和你已有的应对资源。';
      case 'self_attack':
        return '需要验证的是：在减少自我攻击后，你是否反而更容易恢复并采取下一步。';
      default:
        return '需要识别本次结果中可调整的一个变量：准备、结构、技能、环境、节奏或反馈渠道。';
    }
  }

  String _experiment(String event, String pattern) {
    if (pattern == 'perfectionism') return '制作并提交一个 70 分版本';
    if (pattern == 'evaluation_fear') return '完成一次低风险反馈暴露';
    if (pattern == 'catastrophizing') return '做一次可撤回的小规模尝试';
    if (pattern == 'self_attack') return '先完成 3 分钟自我慈悲，再推进一个微动作';
    final short = event.trim().replaceAll(RegExp(r'\s+'), ' ');
    return short.isEmpty ? '完成一个 5–30 分钟反馈实验' : '围绕“${short.length > 22 ? '${short.substring(0, 22)}…' : short}”做一个最小实验';
  }

  String _minimumStandard(String pattern) {
    if (pattern == 'perfectionism') return '在 30 分钟内留下一个可展示、可发送或可测试的粗版本，不继续润色。';
    if (pattern == 'evaluation_fear') return '只向一个低风险对象表达、发送或询问一次，并记录真实回应。';
    if (pattern == 'self_attack') return '写下对朋友会说的三句话，然后完成 5 分钟行动。';
    return '投入 5–30 分钟，留下一个可观察产出或一条真实反馈；不要求成功。';
  }
}
