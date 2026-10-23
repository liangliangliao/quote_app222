import 'copy.dart';

/// AI 不可用时仍保持关爱、事实与建设性挑战。
class PersonaLines {
  const PersonaLines._();
  static String _quote(String text) =>
      text.trim().isEmpty ? '这件事' : '「${text.trim()}」';

  static String interject(
      {required String type,
      required String label,
      required String address,
      required int tone,
      int minutes = 0,
      String stake = '',
      int seed = 0}) {
    final String l = _quote(label);
    switch (type) {
      case 'habit_missed':
        return '$address，$l记录为未完成。是什么阻碍了你？我们可以缩小一步，商量补做时间。';
      case 'habit_done':
        return '$address，$l有完成记录，这是一次进步。什么方法帮助你做到了？';
      case 'kindling_completed':
        return '$address，这次火种完成了 $minutes 分钟。记住有效的方法，下一步由你选择。';
      case 'kindling_aborted':
        return '$address，这次火种在 $minutes 分钟时停下了。遇到了什么困难？可以调整时长或先休息。';
      case 'knowledge_converted':
        return '$l已经转成行动步骤。你愿意今天尝试其中哪一小步，怎样知道它完成了？';
      case 'commitment_missed':
        return '$address，$l到期仍记为未完成。这会影响你的计划；先核实原因，再调整下一步。'
            '${stake.isEmpty ? '' : '你曾选的遇阻行动是「$stake」，要保留还是调整？'}';
      case 'commitment_unverified':
        return '$address，$l已标记完成，但账上没有对应的完整火种记录。可能有遗漏，请补充事实。';
      case 'commitment_done':
        return '$address，$l兑现了。这是有记录的进步，值得记住有效的方法。${stake.isEmpty ? '' : '原赌注作废。'}';
      default:
        return '$address，我看到了$l的新记录。它对你选择的目标有什么帮助？';
    }
  }

  static String dueSoon(
          {required String text,
          required String address,
          required int minutes,
          int seed = 0}) =>
      '$address，「$text」距离约定还有 $minutes 分钟。现在可做哪一小步？如有困难，我们可以调整。';

  static String chat(
          {required String address, required int tone, int seed = 0}) =>
      '$address，我愿意了解你的处境。先分清发生了什么、你如何理解它，再选一个力所能及的小行动。';

  static String activity(
          {required String label,
          required String address,
          required String openText,
          int seed = 0}) =>
      '$address，${_quote(label)}有新记录，「$openText」仍在进行。它们的优先级需要调整吗？';

  static String morningBrief(
          {required String address,
          required int open,
          required String nextText,
          required int yesterdayDone,
          required int yesterdayMissed,
          int seed = 0}) =>
      '$address，早。昨天记录完成 $yesterdayDone、未完成 $yesterdayMissed，今天有 $open 条承诺。'
      '${nextText.isEmpty ? '你想优先照顾哪个目标？' : '最近是「$nextText」，先选一小步。'}';

  static String eveningLedger(
          {required String address,
          required int open,
          required String nextText,
          required int doneToday,
          int seed = 0}) =>
      '$address，今晚一起复盘：今天记录完成 $doneToday 件，还有 $open 条字据。'
      '${nextText.isEmpty ? '' : '最近是「$nextText」。'}哪些方法有效，哪些需要调整？也给自己留出休息。';

  static String stall(
          {required String address,
          required int minutes,
          required String openText,
          int seed = 0}) =>
      '$address，App 使用记录为 $minutes 分钟，暂时没有新行动记录。「$openText」有进展或需要帮助吗？';

  static String claimNoRecord(String address) =>
      '$address，你说做完了，但账上最近 24 小时没有一条完成记录。这不代表你没做，愿意补充具体事项和时间吗？';
  static String claimBusy(String address, int minutes) =>
      '$address，你说没时间，今天 App 使用记录是 $minutes 分钟。使用时长不等于可用精力，能一起看看实际限制吗？';
  static String claimConfirmed(String address, int records) =>
      '$address，最近 24 小时有 $records 条完成记录。你指的是哪一条？我们核实后一起看看有效的方法。';

  static String probe(
      {required String type,
      required String address,
      required int tone,
      int n = 0,
      int m = 0,
      int hours = 0,
      int days = 0,
      String label = '',
      String text = '',
      String category = '',
      int seed = 0}) {
    switch (type) {
      case 'no_commitments':
        return '$address，目前没有开放的承诺。你愿意为自己重视的目标选一个小行动吗？也可以先说困难。';
      case 'kindling_absent':
        return '$address，${hours > 0 ? '过去 $hours 小时' : '目前'}账上没有完整的十五分钟火种记录。是没有记录，还是需要调整练习？';
      case 'knowledge_without_action':
        return '$address，知识转化 $n 次，行动记录 0 次。记录可能不全；若还没开始，愿意试哪一步？';
      case 'dormant_module':
        return '$address，「$label」最近 $days 天没有新记录。这个目标仍重要吗，还是需要换一种方法？';
      case 'habit_empty':
        return '$address，过去七天没有预设行为打卡记录。先确认是否遗漏，再选一个适合当前精力的习惯。';
      case 'lesson_repeat':
        return '$address，「$category」记录了 $n 次，之前的经验是「$text」。这次情境有什么不同，要调整哪一步？';
      case 'ignored_verdict':
        return '$address，上一条反馈尚未回应。我可能看漏了事实，你可以补充、不同意，或稍后再谈。';
      case 'reject_pattern':
        return '$address，本周驳回 $n 项建议，兑现 $m 条承诺。拒绝是你的权利，建议是否需要更贴合现实？';
      case 'unanswered_inquiry':
        return '$address，$hours 小时前问过「$text」。没回答不代表认同；你愿意现在谈，还是先暂停？';
      default:
        return '$address，${hours > 0 ? '账上 $hours 小时没有新记录。' : ''}你现在最重视什么？遇到了什么困难，需要怎样的支持？';
    }
  }

  static String motion(
          {required String address,
          required String text,
          required String dueText,
          required int tone,
          int seed = 0}) =>
      '$address，建议：$text，$dueText前。你可以接受、调整或驳回，决定权在你。';
  static String motionAccepted(
          {required String address,
          required String text,
          required String dueText,
          String stake = ''}) =>
      '$address，已按你的选择立下字据：「$text」，$dueText前。到时核对进展，遇到障碍也可以调整。';
  static String rebut(
      {required String address, required String reason, int seed = 0}) {
    final String r =
        reason.length > 30 ? '${reason.substring(0, 30)}…' : reason;
    return '$address，已尊重你的驳回${r.isEmpty ? '' : '：「$r」'}。建议可能不合适，你愿意一起找更可行的替代方案吗？';
  }

  static String concede(String address) =>
      '$address，这一条我看漏了。申辩成立，谢谢你补充事实，我会更正。';
  static String opening(String address) => EnemyCopy.opening(address);
}
