# 健康饮食模块 Stage6 修复：Health Connect 授权与 API Key 隐藏

## 1. Health Connect 授权失败修复

截图中的错误：

```text
No Activity found to handle Intent { act=androidx.activity.result.contract.action.REQUEST_PERMISSIONS }
```

原因是上一版把 AndroidX Activity Result Contract 生成的内部权限请求 Intent 直接通过 `startActivityForResult` 启动。该 Intent 需要由 Activity Result API 注册/启动，不能作为普通 Activity Intent 直接启动，因此部分设备会出现 `No Activity found`。

本次修复：

- `requestPermissions` 不再直接启动 `androidx.activity.result.contract.action.REQUEST_PERMISSIONS`。
- 改为打开 Health Connect 授权/管理访问页面：
  - 优先使用 `HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS`。
  - 失败时回退到独立 Health Connect App 包名 `com.google.android.apps.healthdata`。
  - 再失败时回退到当前 App 的系统详情页，避免用户停在错误页面。
- 返回 App 后，Health Connect 页面会自动刷新权限状态。
- 按钮文案改为“打开 Health Connect 授权/管理访问”。

用户操作流程：

1. 点击“打开 Health Connect 授权/管理访问”。
2. 在系统 Health Connect 页面允许本 App 读取步数、睡眠、运动、活动消耗和体重。
3. 返回 App 后点击“同步今日身体状态”。

## 2. API Key 明文显示修复

健康饮食配置页中，所有敏感凭证默认隐藏：

- USDA FoodData Central API Key
- 薄荷健康 API Key
- Edamam App ID
- Edamam App Key
- Spoonacular API Key

新增：

- “临时显示密钥内容”开关。
- 每个密钥输入框右侧显示/隐藏按钮。
- 密钥输入框关闭输入建议和自动纠错，减少泄露风险。

Open Food Facts User-Agent 不是 API Key，仍保持明文显示，方便用户编辑 App 名称/版本。

## 3. 修改文件

```text
android/app/src/main/kotlin/com/example/quote_app/HealthDietHealthConnectChannel.kt
android/app/src/main/AndroidManifest.xml
lib/health_diet/pages/health_connect_diet_page.dart
lib/health_diet/pages/health_diet_settings_page.dart
```
