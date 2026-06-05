# 健康饮食模块：API 日志与摄像头条码扫描升级

本次升级基于 `quote_app_health_diet_core_pipeline_buildfix1`。

## 1. 饮食相关外部 API 日志增强

已升级 `lib/health_diet/services/health_diet_external_api_service.dart`。

现在以下外部数据源调用都会写入 App 日志表，并以“请求/响应/异常”结构展示：

- USDA FoodData Central 食物搜索
- Open Food Facts 食物搜索
- Open Food Facts 条形码产品查询
- Spoonacular 菜谱搜索
- Edamam Recipe Search v2 菜谱搜索

日志内容包括：

- Provider
- Model / API 功能名
- Method
- URL
- Headers
- Query parameters
- Response status
- Response headers
- Response body / body preview
- Error 与 StackTrace

敏感字段已隐藏：

- api_key
- app_key
- app_id
- token
- Authorization

这样用户在日志页可以直接看到健康饮食模块到底有没有真实发送请求、请求参数是什么、接口返回了什么、失败原因是什么。

## 2. 条码支持摄像头扫描

已新增：

- `mobile_scanner: ^5.2.3`
- `lib/health_diet/daily_share/diet_barcode_scanner_page.dart`

修改页面：

- `lib/health_diet/daily_share/daily_diet_share_page.dart`

现在“每日饮食分享 / 条形码查询”支持：

1. 手动输入条码；
2. 点击输入框右侧扫码图标；
3. 点击“摄像头扫码”；
4. 摄像头识别成功后自动返回，并把条码填入文本框；
5. 用户点击“查询并确认”后调用 Open Food Facts 查询包装食品。

## 3. 权限

Android 已已有：

- `android.permission.CAMERA`

iOS 已补充：

- `NSCameraUsageDescription`

## 4. 构建提示

需要重新执行：

```bash
flutter clean
flutter pub get
flutter build apk --release
```

如果构建环境首次拉取 `mobile_scanner`，请确保网络可访问 pub.dev。
