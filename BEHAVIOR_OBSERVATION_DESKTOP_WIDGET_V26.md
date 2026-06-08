# V26 行为观察桌面小组件快速记录

## 目标

让用户可以把“行为观察”放到 Android 桌面，从桌面直接发起行为记录，不必先进入完整 App。

## 产品设计

桌面小组件不是一个完整表单容器，Android AppWidget 不适合放多字段输入框。因此本版采用低摩擦闭环：

1. 用户在桌面添加“行为观察”小组件；
2. 小组件展示七个观察层面：行为、时间、情绪、认知、结果、环境、身体；
3. 点击某个层面后，系统弹出一条可直接输入的通知；
4. 用户在通知里输入一句话并保存；
5. 原生侧写入 `behavior_tracking_records`，不打开完整 App。

如果通知权限未开启，小组件点击会回退到打开对应层面的轻量表单页，避免点击无反馈。

## 新增文件

- `android/app/src/main/kotlin/com/example/quote_app/BehaviorObservationWidgetProvider.kt`
- `android/app/src/main/res/layout/behavior_observation_widget.xml`
- `android/app/src/main/res/xml/behavior_observation_widget_info.xml`
- `android/app/src/main/res/drawable/behavior_observation_widget_bg.xml`
- `android/app/src/main/res/drawable/behavior_observation_widget_button.xml`
- `android/app/src/main/res/drawable/behavior_observation_widget_button_primary.xml`

## 修改文件

- `android/app/src/main/AndroidManifest.xml`
  - 注册 `BehaviorObservationWidgetProvider`。
- `android/app/src/main/kotlin/com/example/quote_app/NotifyHelper.kt`
  - 新增 `sendBehaviorObservationWidgetQuickReply`，支持桌面小组件触发通知内输入。
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorTrackingNativeChannel.kt`
  - 新增 `requestPinBehaviorObservationWidget`，支持 App 内请求系统添加桌面小组件。
- `lib/behavior_tracking/behavior_tracking_external_sources.dart`
  - 数据源页新增“桌面小组件快速记录”卡片和“添加桌面小组件”按钮。

## 使用方式

方式一：

行为观察 → 数据源 → 桌面小组件快速记录 → 添加桌面小组件。

方式二：

长按手机桌面空白处 → 小组件 → 名人名言 / 行为观察 → 添加到桌面。

## 注意

- Android 13+ 需要通知权限，否则无法弹出通知输入框。
- 通知内输入是一句话快速记录，不是完整结构化表单。
- 如需完整字段，点击通知本体或在权限不可用时会进入轻量表单页。
