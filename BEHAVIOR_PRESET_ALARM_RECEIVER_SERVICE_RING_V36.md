# V36 行为预设闹钟后台响铃修复

## 修复背景
V35 直接把 `AlarmManager.setAlarmClock` 的触发 PendingIntent 指向全屏 Activity。部分 Android 10+ / 国产 ROM 在 App 后台或进程不在时会拦截后台 Activity 拉起，导致：

- 到点看不到闹钟提醒表单；
- Activity 没有执行，铃声和震动代码也不会执行；
- 看起来像“后台/没运行时闹钟完全没触发”。

## V36 核心改动

1. **闹钟触发入口改为 BroadcastReceiver**
   - 新增 `BehaviorPresetAlarmFireReceiver.kt`。
   - `NativeSchedulerK.scheduleAlarmClockAt()` 现在使用 `setAlarmClock(Receiver + RingingService)`。
   - 到点后先进入 Receiver，而不是直接依赖 Activity 被系统拉起。

2. **新增前台响铃服务**
   - 新增 `BehaviorPresetAlarmRingingService.kt`。
   - Receiver 到点后立即启动前台服务。
   - 服务独立执行：
     - 系统闹钟音量提升；
     - 用户选择的系统铃声播放；
     - MediaPlayer 失败时改用 RingtoneManager 播放；
     - 循环震动；
     - 10 分钟自动停止兜底；
     - 持有短时 PARTIAL_WAKE_LOCK，避免刚触发就休眠。

3. **全屏表单变为 UI 层兜底**
   - 服务负责响铃/震动。
   - 服务通知和 `NotifyHelper` 都带全屏 Intent 打开 `BehaviorPresetAlarmFormActivity`。
   - 即使 Activity 被拦截，铃声和震动仍然会发生。
   - Activity 如果是从服务通知打开，会复用服务响铃，不再重复播放两路声音。

4. **旧版闹钟兼容**
   - 旧 Java `am.AlarmReceiver` 收到行为预设闹钟时，也会启动新的前台响铃服务。
   - 避免升级后还残留的旧 PendingIntent 触发时仍然无声无震。

5. **Manifest 增加组件**
   - `BehaviorPresetAlarmFireReceiver`
   - `BehaviorPresetAlarmRingingService`，`foregroundServiceType="mediaPlayback"`

## 已知系统限制

- 如果用户在系统设置里“强行停止”App，Android 会清除/阻止该应用的闹钟，任何普通 App 都不能像系统时钟一样绕过强行停止。
- 部分国产 ROM 仍可能需要用户允许：自启动、后台弹出界面、锁屏显示、通知/全屏通知权限。V36 已把响铃震动从 Activity 中移到前台服务，以降低这些权限对“声音/震动”的影响。

## 修改文件

- `android/app/src/main/kotlin/com/example/quote_app/NativeSchedulerK.kt`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorPresetAlarmFireReceiver.kt`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorPresetAlarmRingingService.kt`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorPresetAlarmFormActivity.kt`
- `android/app/src/main/kotlin/com/example/quote_app/NotifyHelper.kt`
- `android/app/src/main/java/com/example/quote_app/am/AlarmReceiver.java`
- `android/app/src/main/AndroidManifest.xml`
