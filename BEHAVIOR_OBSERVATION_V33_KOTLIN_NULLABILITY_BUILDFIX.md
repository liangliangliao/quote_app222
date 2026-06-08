# V33 Kotlin 空安全编译修复

## 问题

Release 编译时报错：

```text
BehaviorPresetAlarmFormActivity.kt:206:64 Only safe (?.) or non-null asserted (!!.) calls are allowed on a nullable receiver of type String?.
```

原因是下面代码中 `text?.toString()?.trim()` 的结果类型仍是 `String?`，但随后直接调用了 `ifBlank`：

```kotlin
presetCategoryInput.text?.toString()?.trim().ifBlank { "工作/学习" }
```

## 修复

将其改为先通过 `orEmpty()` 转成非空字符串，再调用 `ifBlank`：

```kotlin
presetCategoryInput.text?.toString()?.trim().orEmpty().ifBlank { "工作/学习" }
```

## 修改文件

- `android/app/src/main/kotlin/com/example/quote_app/BehaviorPresetAlarmFormActivity.kt`
