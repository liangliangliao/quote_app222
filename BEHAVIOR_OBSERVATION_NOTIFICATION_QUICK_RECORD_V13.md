# V13 行为观察：通知快捷记录与模块改名

本版本在 V12「纯行为跟踪 + 数据源保留」基础上继续收束为 **行为观察**，并强化提醒通知。

## 1. 模块名称调整

用户可见名称已从「行为跟踪」改为「行为观察」。

保留内部路由与数据库前缀 `behavior_tracking`，避免破坏旧数据、旧表和已注册通知 payload。

## 2. 提醒通知升级

提醒通知不再只是“点击打开 App”。现在 Android 通知会显示为 **可填写快捷记录通知**：

- 下拉通知；
- 选择观察层面；
- 直接输入内容；
- 原生侧保存到 SQLite；
- 用户不需要打开 App 页面。

支持的通知快捷层面：

- 时间
- 行为
- 情绪
- 认知
- 结果
- 环境
- 身体

说明：Android 系统通知区域对可见 Action 数量有限，不同手机系统可能只优先展示部分按钮；完整通知展开后可显示更多 Action，若系统限制仍可点击通知进入完整表单。

## 3. 原生落库

新增：

- `android/app/src/main/kotlin/com/example/quote_app/BehaviorObservationQuickRecordReceiver.kt`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorObservationNativeRecorder.kt`

通知动作通过 `RemoteInput` 接收文字，并写入 `behavior_tracking_records` 表。

写入字段包括：

- `mode = notification_quick`
- `entry_mode = notification_remote_input`
- `method_name = 通知快捷记录`
- `primary_layer = 用户选择的观察层面`
- `source = notification_remote_input`

不同层面的文字会映射到不同字段：

- 行为层面 → `behavior`
- 情绪层面 → `emotion`
- 认知层面 → `automatic_thought / cognition`
- 结果层面 → `short_term_result / outcome`
- 环境层面 → `environment`
- 身体状态层面 → `body_state`
- 时间层面 → `behavior + unit`

## 4. 提醒入口增强

「数据源」页中保留：

- 提醒配置；
- 注册未来 7 天；
- 测试可填写通知。

提醒只服务于行为观察，不涉及行为改变、干预实验或 A/B 替代方案。

## 5. 仍需真机验证

当前容器无法执行 Flutter/Android 真机编译，因此以下能力仍需在手机端验证：

- Android 13+ 通知权限；
- 通知展开后的 RemoteInput 输入体验；
- 不同厂商系统是否展示全部 7 个层面按钮；
- 通知快捷输入后 SQLite 是否即时写入；
- App 打开后记录列表刷新是否能看到通知保存的记录。
