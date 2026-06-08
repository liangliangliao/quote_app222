# V30 Android 资源编译修复

## 问题

Release 构建在 `:app:processReleaseResources` 阶段失败：

- `style attribute 'android:attr/windowShowWhenLocked' not found`
- `style attribute 'android:attr/windowTurnScreenOn' not found`

原因是 `android:windowShowWhenLocked` 和 `android:windowTurnScreenOn` 是较高 Android API 才支持的样式属性；当前工程的编译 SDK / 资源链接环境无法识别这两个属性，导致 Android resource linking failed。

## 修复

从 `android/app/src/main/res/values/styles.xml` 的 `BehaviorObservationPresetAlarmTheme` 中移除这两个样式属性。

全屏闹钟表单的锁屏显示和点亮屏幕能力已经在代码中实现：

- Android 8.1+：`setShowWhenLocked(true)`、`setTurnScreenOn(true)`
- 旧版本：`FLAG_SHOW_WHEN_LOCKED`、`FLAG_TURN_SCREEN_ON`、`FLAG_DISMISS_KEYGUARD`

对应文件：

- `android/app/src/main/kotlin/com/example/quote_app/BehaviorPresetAlarmFormActivity.kt`

因此移除 XML 样式属性不会影响 V30 的预设行为系统闹钟全屏表单能力，反而提升了不同 compileSdk 环境下的兼容性。
