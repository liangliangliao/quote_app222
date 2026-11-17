package com.example.quote_app

object VoiceAlarmCommands {
  enum class Music { PLAY, STOP }
  fun music(text: String): Music? {
    val value = clean(text)
    if (Regex("不要关闭|不要关掉|别关闭|别关掉|不用关闭|不要停止|别停止|为什么|如何|怎么|能不能|是否|如果").containsMatchIn(value)) return null
    val target = "(?:这个)?(?:背景音乐|背景音|音乐)"
    return when {
      Regex("^(?:关闭|关掉|停止播放|停止|暂停播放|暂停|停掉|不要播放|别放|不要放)$target$").matches(value) ||
        Regex("^把${target}(?:关闭|关掉|暂停|停掉)$").matches(value) ||
        Regex("^${target}(?:关闭|关掉|停止|暂停)$").matches(value) -> Music.STOP
      Regex("^(?:播放|打开|开启|开始播放|继续播放|恢复播放|放)$target$").matches(value) ||
        Regex("^把${target}(?:打开|开启)$").matches(value) -> Music.PLAY
      else -> null
    }
  }

  private fun clean(text: String) = VoiceAlarmSpeechPolicy.normalized(text)
    .replace(Regex("^(请帮我|麻烦帮我|请|麻烦|帮我|现在|立即|给我)+"), "")
    .replace(Regex("(一下|吧|谢谢)$"), "")

  fun isStop(text: String): Boolean = clean(text) in setOf(
    "关闭闹钟", "关掉闹钟", "停止闹钟", "结束闹钟", "停掉闹钟", "取消闹钟",
    "关闭这个闹钟", "关掉这个闹钟", "停止这个闹钟", "闹钟关闭", "闹钟停止",
    "不响了", "不要响", "别响了", "别再响", "别再响了", "不要再响了",
    "关闭", "停止", "关掉", "停掉", "别响", "不响",
  )

  fun discussesOrNegatesSnooze(text: String): Boolean =
    Regex("不要|不想|不能|不需要|不用|无需|别|为什么|怎么|如何|什么是|解释|介绍")
      .containsMatchIn(clean(text))

  fun snoozeMinutes(text: String): Int? {
    val value = Regex("([0-9零〇一两二三四五六七八九十百]+)(分钟|分种|分|小时)")
      .find(clean(text)) ?: return 5
    val token = value.groupValues[1]
    val digits = mapOf('零' to 0, '〇' to 0, '一' to 1, '两' to 2, '二' to 2,
      '三' to 3, '四' to 4, '五' to 5, '六' to 6, '七' to 7, '八' to 8, '九' to 9)
    val number = token.toIntOrNull() ?: run {
      var total = 0
      var digit = 0
      for (c in token) when (c) {
        '十' -> { total += (if (digit == 0) 1 else digit) * 10; digit = 0 }
        '百' -> { total += (if (digit == 0) 1 else digit) * 100; digit = 0 }
        else -> digit = digits[c] ?: return null
      }
      total + digit
    }
    val minutes = number.toLong() * if (value.groupValues[2] == "小时") 60L else 1L
    return minutes.takeIf { it in 1L..180L }?.toInt()
  }
}
