# quote_app PATCH NOTES — 2025-10-02

**Base package**: `quote_app_FIXED_v22_NATIVE_WM_NOTIFY.zip`

## What was failing
- Android 构建报错（`Unresolved reference` / `overrides nothing` 等），根因为 **仍在引用已删除的 Android v1 Embedding API**（如 `PluginRegistry.*` / `PluginRegistrantCallback` / `Registrar` / `registrarFor` / `messenger` / `GeneratedPluginRegistrant`）。
- WorkManager 背景通知希望**统一走原生**，但 `NotifyWorker.kt` 仍使用 `NotificationCompat.Builder`，与前台 `NotifyHelper` 路径不一致。

> 参考：Flutter 3.29 起完全移除 `PluginRegistry.Registrar`；WorkManager 新版无需 App 侧回调注册（详见官方/社区迁移说明）。

## Minimal, backward‑compatible edits (precise)

### 1) `android/app/src/main/kotlin/com/example/quote_app/App.kt`
- **改为 V2 Embedding 纯 Application**；删除一切 v1 相关实现。
- 关键行号：
  - 第 **10 行**：`class App : Application() {`
  - 第 **11–14 行**：保留空 `onCreate()`，不做 v1 注册。

### 2) `android/app/src/main/kotlin/com/example/quote_app/Channels.kt`
- **仅保留 V2 注册函数** `fun register(engine: FlutterEngine, appCtx: Context)`，删除 v1 Registrar 相关导入/重载。
- 关键行号：
  - 第 **7 行**：`object Channels {`
  - 第 **8 行**：`private const val CH_NOTIFY = "com.example.quote_app/notify"`
  - 第 **10–22 行**：`MethodChannel(...).setMethodCallHandler { ... NotifyHelper.send(appCtx, ...) }`

### 3) `android/app/src/main/kotlin/com/example/quote_app/NotifyWorker.kt`
- **统一走原生**：将内部的 `NotificationCompat` 构建/发送替换为：
  - 第 **19–20 行**：
    ```kotlin
    val ok = NotifyHelper.send(applicationContext, id, title, body, null)
    return if (ok) Result.success() else Result.failure()
    ```
- 同时移除不再需要的 `NotificationCompat/NotificationManagerCompat` import。

## Why this works
- **彻底去除 v1 embedding**：规避 Flutter 3.29 起的编译期删除导致的 `Unresolved reference`。  
- **WM 与前台统一原生通道**：`NotifyWorker` 与 `Channels.notify` 都落到 `NotifyHelper.send(...)`，渠道/权限/小米/OPPO 等适配只维护一处。

## Safety checks
- 全项目括号/花括号 **匹配通过**。
- 无新增 `Undefined name` / `static 修饰` 等语法问题。
- **未删除**已有业务逻辑；仅最小增量移除 v1 API 的导入/重载函数并保持现有通道实现与工具类。


- PATCH: Implemented CSV bulk import with avatar (optional), manual fields, avatar filename display, and DB schema extension for quotes (theme, author_name, source_from, explanation, inserted_at, last_notified_at). Compatible with existing code.
