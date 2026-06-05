# 健康饮食模块第四阶段实现说明

本阶段在第三阶段基础上继续落地两类修改：

## 1. 语音识别连续识别修复

问题：部分 Android 系统语音识别器在用户停顿后会自动返回 `done/notListening`，导致页面看起来只能识别第一句话。

本次修复：

- 将“开始语音识别”升级为“开始连续识别”。
- 增加 `_keepContinuousListening` 状态。
- 当系统识别器自动结束一轮后，如果用户没有主动停止，则自动重启下一轮识别。
- 不再用新一轮识别结果覆盖旧文本，而是把每一轮结果追加到文本框。
- 用户仍然可以手动编辑识别结果后再进入确认页。

修改文件：

- `lib/health_diet/daily_share/diet_voice_input_page.dart`

## 2. 第四阶段：Health Connect 身体状态联动

新增能力：

- 新增页面：`饮食 / Health Connect 身体状态`
- 新增原生 Android MethodChannel：`health_diet/health_connect`
- 支持读取用户授权后的今日摘要：
  - 步数
  - 睡眠分钟数
  - 运动分钟数
  - 活动消耗 kcal
  - 体重 kg
- 将同步结果保存到本地 SQLite：`health_connect_daily_summary`
- 今日饮食复盘会读取该摘要，并结合饮食记录生成更贴近身体状态的建议：
  - 睡眠不足 + 甜饮：提示不要主要靠糖硬撑疲劳
  - 步数低 + 高盐/高油/加工食品：提示晚餐和夜宵更清淡
  - 活动量高 + 蛋白质不足：提示运动后补充优质蛋白

新增/修改文件：

- `lib/health_diet/models/health_connect_daily_summary.dart`
- `lib/health_diet/repositories/health_connect_summary_repository.dart`
- `lib/health_diet/services/health_connect_diet_context_service.dart`
- `lib/health_diet/pages/health_connect_diet_page.dart`
- `lib/health_diet/daily_share/daily_diet_review_page.dart`
- `lib/health_diet/services/daily_diet_review_service.dart`
- `lib/health_diet/pages/health_diet_home_page.dart`
- `lib/health_diet/pages/health_diet_settings_page.dart`
- `android/app/src/main/kotlin/com/example/quote_app/HealthDietHealthConnectChannel.kt`
- `android/app/src/main/kotlin/com/example/quote_app/MainActivity.kt`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/build.gradle`
- `lib/data/db.dart`

## Android 原生接入

新增依赖：

```gradle
implementation "androidx.health.connect:connect-client:1.1.0"
implementation "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1"
```

新增 Health Connect 权限：

```xml
<uses-permission android:name="android.permission.health.READ_STEPS" />
<uses-permission android:name="android.permission.health.READ_SLEEP" />
<uses-permission android:name="android.permission.health.READ_EXERCISE" />
<uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED" />
<uses-permission android:name="android.permission.health.READ_WEIGHT" />
```

说明：用户仍需在 Health Connect 权限页显式授权，声明权限本身不会自动授予数据读取能力。

## 本地数据表

第三阶段已创建 `health_connect_daily_summary`，本阶段补充：

- `status`
- `message`

用于保存读取状态、设备不可用、权限不足、无数据等原因。

## 使用路径

```text
发现之旅 / 生理赋能 / 饮食 / Health Connect 身体状态
```

使用流程：

```text
1. 点击“申请/重新授权读取权限”
2. 在 Health Connect 权限页授权步数、睡眠、运动、活动消耗和体重
3. 返回 App 后点击“同步今日身体状态”
4. 打开“今日饮食复盘”，身体状态会参与复盘建议
```

## 注意事项

- 如果设备不支持 Health Connect，页面会显示不可用原因。
- 如果已授权但没有今日数据，页面会显示“已授权，但今天暂未读取到数据”。
- 本阶段只读取用户授权后的前台数据摘要，不做后台持续读取。
