# Quote App (Flutter)

- 设置页统一保存：API Key、提示词、计划时间（每日/每周/自定义）。
- 首页：显示最新名言；每 15 秒更新一次。
- 历史页：分页（100/批）+ 模糊搜索。
- 后台任务：按计划拉取，触发通知与角标（平台受限下为本地原型）。
- 首次启动会插入一条默认名言（尼采）便于测试。

## 本地运行
```bash
flutter pub get
# 如首次拉取，生成平台目录
flutter create . --platforms=android
flutter run -d chrome   # 或者 -d android
```

## GitHub Actions 构建 APK
- 已提供工作流：`.github/workflows/flutter-android.yml`。
- 推送到 GitHub 后，工作流会自动：安装 Flutter → `flutter create` 生成 Android 平台 → 打包 APK → 上传构建产物。


## CI 故障排查
- 如果你的仓库里还有其它会在根目录执行 `gradle assembleDebug` 的工作流，请在 Actions 中将其 **Disable** 或删除。
- 若需纯 Gradle 方式，可手动触发 `Build Android APK (Gradle compat)`，它会在 `android/` 目录使用 `./gradlew` 构建。
