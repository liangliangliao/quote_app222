# 语音调试日志查看页编译修复

## 问题

GitHub Actions 编译日志显示：

- `VoiceAlarmActivity.kt:957:60 Syntax error: Expecting '"'`
- 后续 958-965 行出现一串 `Expecting '"' / Expecting ')' / Unresolved reference`。

原因是 `showVoiceDebugLogDialog()` 中 `buildString` 里的换行字符串被写成了真实换行：

```kotlin
append("日志目录：").append(dir.ifBlank { "未知" }).append("
")
```

Kotlin 普通双引号字符串不能跨行，因此编译器从第 957 行开始把后面的中文内容都误判成代码。

## 修复

将日志弹窗文本拼接中的真实换行全部改成转义换行 `\n`：

```kotlin
append("日志目录：").append(dir.ifBlank { "未知" }).append("\n")
append("当前日志：").append(path.ifBlank { "未知" }).append("\n")
append("也可用：adb logcat -s VoiceAlarmDebug 查看实时日志。\n")
append("\n—— 最近日志内容 ——\n")
```

## 修改文件

- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`
