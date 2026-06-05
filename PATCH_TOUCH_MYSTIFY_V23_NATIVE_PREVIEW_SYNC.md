# V23 - 原生预览与真实壁纸渲染器对齐

## 解决的问题

1. App 顶部预览和真实手机壁纸效果差别很大。
   - 原因：App 预览使用 Flutter `CustomPainter`，真实壁纸使用 Android 原生 OpenGL/FBO。
   - 修复：新增 Android PlatformView `com.example.quote_app/intimacy_mystify_preview`，触摸页顶部预览改为原生 `AndroidView`，复用动态壁纸同一套 `GLRenderThread`。

2. 设置参数后真实壁纸不一定立刻同步。
   - 原因：以前只有点击“保存参数”才写入配置。
   - 修复：触摸页滑块/开关变更后增加 650ms debounce 自动保存配置；真实壁纸和原生预览均通过 SharedPreferences listener 重新读取配置。
   - 自动同步时不重置 seed，避免每次拖动滑块都强行重启构图；点击“随机新构图”或“保存参数”仍会刷新 seed。

## 新增文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/MystifyPreviewSurfaceView.java`
- `android/app/src/main/kotlin/com/example/quote_app/wallpaper/MystifyPreviewPlatformViewFactory.kt`

## 修改文件

- `android/app/src/main/kotlin/com/example/quote_app/MainActivity.kt`
- `android/app/src/main/kotlin/com/example/quote_app/IntimacyWallpaperChannel.kt`
- `lib/platform/intimacy_wallpaper_bridge.dart`
- `lib/pages/touch_mystify_wallpaper_page.dart`

## 注意

Flutter 预览代码仍保留为非 Android 平台 fallback；Android 真机默认使用原生 OpenGL 预览。
