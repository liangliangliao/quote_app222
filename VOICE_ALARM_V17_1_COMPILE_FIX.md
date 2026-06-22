# VOICE_ALARM_V17_1_COMPILE_FIX

## 修复内容

修复 GitHub Actions 编译报错：

```text
VoiceAlarmActivity.kt:900:29 Unsupported escape sequence.
```

## 原因

v17 中为兼容讯飞 `rg` 字段字符串形式，新增了正则：

```kotlin
Regex("-?\d+")
```

但 Kotlin 普通字符串中 `\d` 不是合法转义序列，因此编译器报 `Unsupported escape sequence`。

## 修复

改为 Kotlin 原始字符串：

```kotlin
Regex("""-?\d+""")
```

这样正则仍然匹配正负整数，同时不会触发 Kotlin 字符串转义错误。

## 检查

- `VoiceAlarmActivity.kt` 括号数量检查通过；
- `AndroidManifest.xml` XML 解析通过；
- zip 根目录直接包含 `android/`、`lib/` 等项目文件，没有多级目录嵌套。

完整 Gradle 编译仍受当前源码包缺少 `android/gradle/wrapper/gradle-wrapper.jar` 限制，无法在当前环境离线生成 APK 实测。
