# V35 行为预设闹钟后台/进程死亡触发与铃声震动修复

## 现象
- App 在后台或进程不在运行时，到点后没有弹出预设行为闹钟表单。
- 已设置系统铃声与震动，但实际没有铃声和震动。

## 根因
V34 使用 `AlarmManager.setAlarmClock` 注册了闹钟，但到点后的实际 `operation` 仍然是 `BroadcastReceiver`，再由接收器尝试从后台启动全屏 Activity。Android 10+ 以及部分国产 ROM 会限制这种后台 Activity 拉起，因此接收器虽然可能被触发，但表单、响铃和震动无法稳定出现。

## 修复
1. `NativeSchedulerK.scheduleAlarmClockAt` 改为使用 Activity PendingIntent 作为真正的 `setAlarmClock` operation：
   - 到点时系统直接启动 `BehaviorPresetAlarmFormActivity`。
   - 不再依赖“广播接收器 -> 后台拉起 Activity”的链路。
   - 即使 App 进程不在，系统闹钟也会拉起闹钟表单。

2. `AlarmClockInfo.showIntent` 不再指向响铃表单：
   - 防止用户提前点击系统“即将响铃”入口时误触发铃声/震动。
   - 改为打开 App 主入口。

3. `BehaviorPresetAlarmFormActivity` 自身负责完整响铃流程：
   - Activity 被系统闹钟直接拉起后，先合并/刷新当前时刻预设行为 payload。
   - 立即播放统一设置的系统铃声。
   - 立即执行循环震动。
   - 同时安排下一次未来闹钟。

4. 铃声播放增强：
   - 先尝试用户选择的系统铃声。
   - 如果该 URI 失败，自动回退系统默认闹钟铃声、来电铃声、通知铃声。
   - 根据 App 内“声音大小”临时提升 `STREAM_ALARM` 音量，避免系统闹钟音量为 0 导致无声。
   - 关闭/确认表单后恢复原系统闹钟音量。

5. 震动增强：
   - 明确使用 `VibratorManager` / `Vibrator` 循环震动。
   - 保留统一震动开关。
   - Manifest 增加 `MODIFY_AUDIO_SETTINGS`，保留 `VIBRATE`。

6. 升级兼容：
   - App 主进程启动时会重新恢复未来预设闹钟。
   - 重新调度时会取消旧版本按单个预设注册的遗留闹钟，避免同一时刻重复触发。
   - `BootReceiver` / 应用更新后继续恢复未来预设闹钟。

## 重要说明
- Android 系统级“勿扰模式”、厂商自启动/后台弹窗限制仍可能影响最终表现；但本版本已避开最主要的后台广播拉起限制。
- 当前环境缺少 Gradle wrapper jar 且无法联网下载，因此未能完成完整 Android 编译；已完成源码级修复与 XML 解析检查。
