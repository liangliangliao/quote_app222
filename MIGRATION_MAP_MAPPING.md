# 迁移对照清单（函数 → 源码文件/行号 + 委托路径）

> 基线：Dart（FIX12_bracefix） vs 原生（FIX18_mapping）。  
> 行号基于本包源码快照，可能因你后续编辑略有偏移。

## 1. 精准能力 / 授权

- **Dart** `PermHelper.hasExactAlarmPermission()` → `lib/platform/perm_helper.dart:12`
  - 通道：**MainActivity** `"hasExactAlarmPermission"` → `android/app/src/main/kotlin/com/example/quote_app/MainActivity.kt:45`
  - 实现：`AlarmManager.canScheduleExactAlarms()` → `MainActivity.kt:48`

- **Dart** `NativeScheduler.requestExact()` → `lib/platform/native_scheduler.dart:7`
  - 通道：**MainActivity** `"requestExactPermission"` → `MainActivity.kt:72`
  - 原生实现：`NativeSchedulerK.requestExactPermission(ctx)` → `android/app/src/main/kotlin/com/example/quote_app/NativeSchedulerK.kt:115`

## 2. 精准注册 / 兜底 WM

- **Dart 调度入口**（单任务续排与注册发生在此方法中）  
  `SchedulerService.scheduleNextForTask(uid)` → `lib/services/scheduler_service.dart:123`  
  - 内部调用 **精准注册**：`await NativeScheduler.scheduleExactAt(...)` → `scheduler_service.dart:175`  
  - 内部调用 **WM 兜底**：`await NativeScheduler.scheduleWmFallback(...)` → `scheduler_service.dart:188-193`

- **原生精准注册**  
  `NativeSchedulerK.scheduleExactAt(ctx, id, epochMs, payload)` → `android/app/src/main/kotlin/com/example/quote_app/NativeSchedulerK.kt:38`

- **原生 WM 兜底注册**  
  `NativeSchedulerK.scheduleWmFallback(ctx, id, epochMs, payload)` → `NativeSchedulerK.kt:94`  
  - Worker 执行体：`WmFallbackWorker.doWork()` → `android/app/src/main/kotlin/com/example/quote_app/WmFallbackWorker.kt:17`

## 3. 取消

- **Dart** `SchedulerService.cancelNextForTask(uid)` → `lib/services/scheduler_service.dart:232`  
  - 内部取消 AM：`NativeScheduler.cancel(id)` → `scheduler_service.dart:240`  
  - 内部取消 WM 兜底/正常：`_cancelWmFallback/_cancelWmNormal` → `scheduler_service.dart:115-121`

- **原生**  
  - `NativeSchedulerK.cancel(ctx, id)` → `android/app/src/main/kotlin/com/example/quote_app/NativeSchedulerK.kt:84`  
  - `NativeSchedulerK.cancelAll(ctx)` → `NativeSchedulerK.kt:133`  
    - 依赖：`DbRepository.listScheduledTasks(ctx)` → `android/app/src/main/java/com/example/quote_app/data/DbRepository.java:517`

## 4. WM 入口 / 兼容旧 Dart 回调

- **Dart 旧回调** `wm_dispatcher.workmanagerCallbackDispatcher()` → `lib/services/wm_dispatcher.dart:12`（仅保留）  
- **原生替代入口**  
  - 兜底：`WmFallbackWorker.doWork()` → `android/app/src/main/kotlin/com/example/quote_app/WmFallbackWorker.kt:17`  
  - 正常：`NotifyWorker.doWork()` → `android/app/src/main/kotlin/com/example/quote_app/NotifyWorker.kt:29`

## 5. 业务执行（Alarm → Biz.run）

- **原生 AM 触发链**：  
  `AlarmReceiver.onReceive(...)` → `android/app/src/main/java/com/example/quote_app/am/AlarmReceiver.java:17`  
  - 执行业务：`Biz.run(ctx, uid)` → `AlarmReceiver.java:55` 与 `android/app/src/main/java/com/example/quote_app/biz/Biz.java:20`  
  - 成功记账：`DbRepository.markLatestSuccess` → `AlarmReceiver.java:58`  
  - 精准续排：`NativeSchedulerK.scheduleExactWmCompat(...)` → `AlarmReceiver.java:66`  
  - 失败记账：`DbRepository.insertFail` → `AlarmReceiver.java:73, 79`

- **原生 WM 触发链**：  
  `NotifyWorker.doWork()` → `android/app/src/main/kotlin/com/example/quote_app/NotifyWorker.kt:29`  
  - 业务：`Biz.run(...)`（同上）  
  - 成功记账：`NotifyWorker.kt:31`  
  - 续排：`NotifyWorker.kt:36`  
  - 失败两次兜底（由 `scheduleWmFallback` 再约 2 分钟）

## 6. 续排（下一次时间计算）

- **原生** `NextTriggerCalculator.compute(ctx, uid)` → `android/app/src/main/java/com/example/quote_app/schedule/NextTriggerCalculator.java:20`  
- **调度** `NativeSchedulerK.scheduleExactWmCompat(...)` → `NativeSchedulerK.kt:98`

## 7. 自检（注册与补发）

- **Dart 入口** `SchedulerService.scheduleSelfCheck()` → `lib/services/scheduler_service.dart:400`  
  - 改为走 **原生**：`NativeScheduler.scheduleSelfCheck(minutes)`（Dart） → `lib/platform/native_scheduler.dart:13`  
- **原生注册** `NativeSchedulerK.scheduleSelfCheck(ctx, minutes)` → `android/app/src/main/kotlin/com/example/quote_app/NativeSchedulerK.kt:102`  
- **原生执行** `SelfCheckWorker.doWork()` → `android/app/src/main/kotlin/com/example/quote_app/SelfCheckWorker.kt:11`  
  - `DbRepository.failsOfToday()` → `android/app/src/main/java/com/example/quote_app/data/DbRepository.java:495`  
  - 对每个失败 `uid` 立即补发：`NativeSchedulerK.scheduleWmFallback(...)` → `SelfCheckWorker.kt:21`

## 8. 失败/幂等/列补齐（与 Dart 侧 DAO 对齐）

- **失败统计**（等价 Dart `FailureStatDao`）  
  - `DbRepository.ensureNotifyFailures` → `:465`  
  - `DbRepository.insertFail` → `:472`  
  - `DbRepository.markLatestSuccess` → `:483`  
  - `DbRepository.failsOfToday` → `:495`

- **幂等**（等价 Dart `NotifyGuardDao`）  
  - `DbRepository.ensureNotifyGuard` → `:404`  
  - `DbRepository.alreadySent` → `:428`  
  - `DbRepository.markSent` → `:414`

- **列补齐**  
  - `DbRepository.setScheduledRunKey`（缺列自动 `ALTER TABLE`）→ `:442`

## 9. Dart 函数级对齐（可选入口，便于函数名一一匹配）

- `compat/DartParity.java`  
  - `alarmId(...)` → `android/app/src/main/java/com/example/quote_app/compat/DartParity.java:22`  
  - `scheduleExactAt(...)` → `:29`（委托 `NativeSchedulerK.scheduleExactAt` + `scheduleWmFallback` + `DbRepository.setScheduledRunKey`）  
  - `cancel(...)` → `:42`（委托 `NativeSchedulerK.cancel`）  
  - `scheduleSelfCheck(...)` → `:48`（委托 `NativeSchedulerK.scheduleSelfCheck`）  
  - `selfCheckTodayFailures(...)` → `:53`（委托 `DbRepository.failsOfToday` + `NativeSchedulerK.scheduleWmFallback`）  
  - `wmRunTask(...)` → `:69`（完整复制 Dart 语义：幂等→Biz→成功取消兜底+续排→失败两次兜底→中文日志与失败记账）

---

> 备注：若你需要把此清单随代码一起分发，我可把本文件保存为 `MIGRATION_MAP_MAPPING.md`（已保存到仓库根）。
