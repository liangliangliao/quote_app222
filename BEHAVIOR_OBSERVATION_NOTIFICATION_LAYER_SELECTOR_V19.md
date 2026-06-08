# V19 行为观察通知选择式表单优化

## 问题
V16/V18 的通知提醒为了解决 Android 单条通知按钮数量限制，采用“1 条总通知 + 7 条层面子通知”的通知组方案。实际体验中会出现：

- 通知栏被七层提醒刷屏；
- 用户并不想在通知中心看到七个层面同时展开；
- 通知内 RemoteInput 只能输入一段文本，无法承载完整字段表单；
- 用户真正需要的是：先选择一个层面，再填写该层对应字段。

## 本次改造

### 1. 通知栏只保留一条提醒

`NotifyHelper.sendBehaviorObservationReminder()` 已改为只发送一条“行为观察提醒”。

通知内容说明：

> 点击后先选择观察层面，再填写对应字段表单。

通知按钮只有一个：

> 选择层面填写

不再发送 7 条子通知，不再在通知栏堆叠七层记录方式。

### 2. 点击通知打开层面选择页

通知 payload 固定转换为：

```json
{
  "module": "behavior_tracking",
  "route": "/behavior_tracking",
  "templateKey": "notification_layer_select",
  "entryMode": "notification_layer_selector"
}
```

Flutter 收到后会进入行为观察模块，并打开“通知层面选择记录”表单。

### 3. App 内用下拉框选择七层之一

表单顶部新增“选择观察层面”：

- 时间层面
- 行为层面
- 情绪层面
- 认知层面
- 结果层面
- 环境层面
- 身体状态

选择后，下方只显示该层对应字段。

### 4. 选择后动态切换对应字段

例如：

- 选择“时间层面” → 显示开始、结束、项目、专注度；
- 选择“环境层面” → 显示环境因素、地点、在场人、手机距离、噪音、杂乱、线索标签；
- 选择“身体状态” → 显示身体状态、睡眠、睡眠质量、精力、步数、运动分钟。

这样保持了完整字段表单，但不会在通知栏中强行展示复杂 UI。

## 修改文件

- `android/app/src/main/kotlin/com/example/quote_app/NotifyHelper.kt`
- `lib/behavior_tracking/behavior_tracking_home_page.dart`
- `lib/behavior_tracking/behavior_tracking_external_sources.dart`

## 说明
Android 系统通知不支持真正的下拉选择框和复杂动态表单。正确产品实现是：通知只负责提醒与唤起；完整的下拉选择和字段表单在 App 内完成。
