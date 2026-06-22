# 语音闹钟可靠性第五轮审计与补充修复 V5

本轮基于 v4 继续排查“App 进程不在、清理最近任务、锁屏/重启、语音播报被打断”这些真实设备问题，新增修复如下。

## 1. 通知渠道被旧版本/用户降级后无法全屏弹出

Android 8+ 的通知渠道一旦创建，应用后续不能再把同一个渠道的重要性提升回来。如果旧版本的 `voice_alarm_ringing_v4` 渠道被降级，重新 create 同名渠道也不会恢复高优先级，表现为：服务响了、通知有了，但锁屏全屏界面不弹，用户感觉“没提醒”。

处理：
- 将语音闹钟响铃渠道升级为 `voice_alarm_ringing_v5`；
- 新增 `VoiceAlarmRingingService.ensureAlarmChannel()`；
- 新增 `VoiceAlarmRingingService.isAlarmChannelImportantEnough()`；
- 保存闹钟前由 Flutter 调用 `isAlarmNotificationChannelImportant`，若渠道重要性不足，跳转到该通知类别设置页。

## 2. AlarmManager 设置异常时可能直接抛出，导致没有持久化

v4 在 `setAlarmClock()` 失败时会尝试兜底，但部分系统/ROM 上如果精确闹钟权限、后台策略或异常状态导致 fallback 也失败，可能抛出到 Flutter，最终 native 持久化没有执行。

处理：
- 新增 `scheduleBestEffortInexact()`；
- `setAlarmClock()`、精确 fallback、非精确 fallback 全部包裹为不向外抛出；
- 即使 exact 权限失败，也至少注册 best-effort `setAndAllowWhileIdle/set` 广播、服务、Activity 三路兜底；
- 保证 payload 仍持久化，后续开机、授权变化、App 启动可恢复调度。

## 3. 只有 BootReceiver 恢复仍不够

部分 ROM 会限制开机广播、自启动或包更新广播。v4 依赖 BootReceiver 恢复，但用户打开 App 后也应该轻量恢复语音闹钟。

处理：
- 在 `App.onCreate()` 主进程启动时调用 `VoiceAlarmScheduler.restore(applicationContext)`；
- 覆盖用户授权“闹钟和提醒”后返回 App、ROM 清理 PendingIntent、BootReceiver 未投递等场景。

## 4. 自定义重复日期为空会导致逻辑不明确

如果用户自定义重复日期但全部取消选择，Dart 的 `_nextTime()` 会因 guard 上限返回一个并不真正匹配的日期；native `scheduleNextDaily()` 又会把空集合兜底成每天，导致用户以为“不响/乱响”。

处理：
- 保存前检查 `_effectiveWeekdays().isEmpty`；
- 没有任何可触发日期时禁止保存并提示用户至少选一天。

## 5. 语音播报仍可能被其他音频焦点影响

v4 已避免“播报开始广播把自己打断”，但没有主动请求 alarm audio focus。部分设备上其他音乐、导航、语音助手、系统音频焦点变化可能使闹钟播报被 duck 或中断。

处理：
- `startSignals()` 前请求 `AUDIOFOCUS_GAIN_TRANSIENT`；
- 停止闹钟时释放 audio focus；
- MediaPlayer 增加 wake mode，降低休眠中播放被挂起的概率；
- `MediaPlayer.start()` 异常时及时发送 playback end，避免 Activity 状态机长期认为“闹钟语音还在播放”。

## 6. 仍无法规避的系统边界

- 用户在系统设置点“强行停止/Force stop”后，普通 App 不能自动复活。
- Android 14+ 全屏 Intent 权限如果被系统/用户关闭，只能退化为通知横幅/锁屏通知。
- Android 13+ 通知权限被拒绝时，前台通知和全屏提醒可靠性会显著下降。
- 部分国产 ROM 仍需用户手动打开自启动、后台运行、锁屏显示、后台弹出界面、电池无限制。
- Android 对后台麦克风前台服务有限制，所以 AI 语音识别仍以全屏 Activity 可见后运行为主。

## 修改文件

- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmRingingService.kt`
- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmScheduler.kt`
- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmChannel.kt`
- `android/app/src/main/kotlin/com/example/quote_app/App.kt`
- `lib/voice_alarm/voice_alarm_page.dart`
