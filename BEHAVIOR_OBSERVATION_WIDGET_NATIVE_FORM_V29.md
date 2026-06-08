# V29 桌面小组件原生表单与添加入口增强

## 背景

用户反馈：

1. 桌面小组件点击某个层面后，不希望再打开 App 首页后跳转表单。
2. 不希望再弹通知输入，而是希望直接出现对应层面的记录表单。
3. 长按 App 图标仍未显示“添加行为观察小组件”。

## 本次调整

### 1. 小组件按钮直达原生轻量表单

新增 Android 原生 Activity：

- `BehaviorObservationWidgetFormActivity.kt`

小组件点击逻辑从：

- 桌面小组件 → Flutter MainActivity → 行为观察页 → 表单
- 或 桌面小组件 → 通知输入

调整为：

- 桌面小组件 → 原生轻量表单 → 保存后关闭

该 Activity 使用 Dialog 样式，不进入行为观察首页，也不再弹通知。

### 2. 七层对应字段

小组件中的七个按钮分别打开对应层面表单：

- 行为：具体做了什么、为什么做、实际值、单位、备注
- 时间：项目、开始时间、结束时间、专注度、备注
- 情绪：事件、情绪、强度、反应
- 认知：情境、自动想法、后续行为
- 结果：行为、短期结果、长期影响
- 环境：地点、身边人、物品/手机/环境线索、影响
- 身体：睡眠、精力、疲劳、步数、运动分钟

保存后由原生侧直接写入 `behavior_tracking_records`，不依赖 Flutter 页面。

### 3. 原生落库增强

修改：

- `BehaviorObservationNativeRecorder.kt`

新增：

- `saveFromNativeForm(...)`

并增强数据库打开逻辑：如果用户在第一次打开 App 之前就点击桌面小组件，原生侧会尝试创建 `app_flutter/quotes.db` 并创建行为观察表，避免保存失败。

### 4. 长按 App 图标入口增强

新增：

- `BehaviorObservationWidgetPinActivity.kt`
- `res/xml/behavior_observation_shortcuts.xml`

在支持 App Shortcuts 的桌面上，长按 App 图标会出现：

- 添加行为观察小组件

点击后调用 `requestPinAppWidget` 请求系统添加桌面小组件。

注意：是否在长按 App 图标中展示“小组件”或“快捷方式”由手机桌面启动器决定，App 无法强制所有桌面都显示。稳定入口仍然是：

- 行为观察 → 数据源 → 桌面小组件快速记录 → 添加桌面小组件
- 或长按桌面空白处 → 小组件 → 名人名言 → 行为观察

## 修改文件

- `android/app/src/main/kotlin/com/example/quote_app/BehaviorObservationWidgetProvider.kt`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorObservationWidgetFormActivity.kt`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorObservationWidgetPinActivity.kt`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorObservationNativeRecorder.kt`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/layout/behavior_observation_widget.xml`
- `android/app/src/main/res/xml/behavior_observation_shortcuts.xml`
- `android/app/src/main/res/values/styles.xml`
- `android/app/src/main/res/values/strings.xml`

## 验证说明

当前环境没有 Android 真机与完整 Flutter/Gradle 构建链，无法完成桌面小组件真机验证。源码层面已完成跳转链路、原生表单和落库逻辑，需要在真机上确认：

1. 小组件按钮是否直接弹出对应原生表单；
2. 保存后行为观察记录列表是否出现新记录；
3. 目标桌面是否支持长按 App 图标显示快捷方式或小组件入口。
