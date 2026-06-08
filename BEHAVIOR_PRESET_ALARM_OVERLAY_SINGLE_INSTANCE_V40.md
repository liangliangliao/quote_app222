# 行为预设闹钟 v40 修复说明

本次修复针对 v39 后仍存在的两个问题：

1. App 后台运行或进程不在后台时，全屏表单不能稳定弹出，只能响铃。
2. App 在前台时，同一个闹钟时刻可能弹出多个表单。

## 核心改动

- 移除 v39 的“Receiver + 延迟 Activity setAlarmClock + exact Activity fallback + 多次 startActivity 重试”链路。
- 同一闹钟时刻只保留一个 `AlarmManager.setAlarmClock`，到点进入 `BehaviorPresetAlarmFireReceiver`。
- Receiver 只启动 `BehaviorPresetAlarmRingingService`，由前台响铃服务统一负责铃声、震动、前台通知、全屏 UI。
- 新增 `BehaviorPresetAlarmUiGate`，对同一闹钟时刻做 90 秒 UI 去重，避免前台重复弹多个表单。
- 将 `BehaviorPresetAlarmFormActivity` 改为 `singleTask`，进一步保证同一表单只复用一个实例。
- 新增 `BehaviorPresetAlarmOverlay`：如果用户授予“显示在其他应用上层/悬浮窗”权限，响铃服务会直接绘制全屏覆盖表单，不依赖后台 Activity 启动权限。
- Flutter 注册闹钟前新增悬浮窗权限检查；未授权时会打开系统授权页，授权后需要返回 App 重新注册闹钟。
- 通知渠道升级到 v40，避免系统继续沿用 v39 旧渠道设置。

## 测试建议

安装 v40 后进入：行为观察 → 预设 → 闹钟提醒。

1. 重新选择铃声并确认通知/音频权限。
2. 允许“全屏提醒/全屏通知”。
3. 允许“显示在其他应用上层/悬浮窗”。
4. 返回 App 后点击“重新注册已开启提醒”。

说明：Android/国产 ROM 对后台直接启动 Activity 有严格限制，v40 的稳定全屏兜底依赖悬浮窗权限；未授予该权限时，只能继续走系统 full-screen notification 和一次 Activity 尝试，仍可能被 ROM 拦截。
