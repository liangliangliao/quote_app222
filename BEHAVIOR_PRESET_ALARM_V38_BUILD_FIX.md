# V38 构建修复说明

## 修复内容

针对 GitHub Actions / Flutter release 构建失败：

```text
Android resource linking failed
error: style attribute 'android:attr/windowShowWhenLocked' not found
error: style attribute 'android:attr/windowTurnScreenOn' not found
error: style attribute 'android:attr/windowKeepScreenOn' not found
```

已修复 `android/app/src/main/res/values/styles.xml` 中 `BehaviorObservationPresetAlarmTheme` 的无效 style item：

- 移除 `android:windowShowWhenLocked`
- 移除 `android:windowTurnScreenOn`
- 移除 `android:windowKeepScreenOn`

这些能力不再通过 style 声明，而由 `BehaviorPresetAlarmFormActivity.configureAlarmWindow()` 运行时设置：

- Android 8.1+ 使用 `setShowWhenLocked(true)` / `setTurnScreenOn(true)`
- Android 8.0 及以下使用 `FLAG_SHOW_WHEN_LOCKED` / `FLAG_TURN_SCREEN_ON` / `FLAG_DISMISS_KEYGUARD`
- 保留 `FLAG_KEEP_SCREEN_ON`

## 影响

此修复只解决编译失败，不回退 v37 中行为预设闹钟的 Receiver + 前台响铃服务 + 全屏 Activity 改动。

