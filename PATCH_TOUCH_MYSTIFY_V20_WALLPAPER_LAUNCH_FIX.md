# V20 壁纸系统入口修复

## 修复目标

解决点击“打开系统动态壁纸预览并应用”后只显示提示、但没有真正跳转系统壁纸页面的问题。

## 原因

上一版直接从 FlutterActivity 调用 `ACTION_CHANGE_LIVE_WALLPAPER`。部分 Android/OEM 系统会出现 `startActivity()` 没抛异常、但界面没有可见跳转的情况，导致 App 误提示“已跳转”。

## 本次改法

1. 新增原生 `WallpaperApplyActivity`。
2. Flutter 通道不再直接启动系统壁纸 Intent，而是先启动这个原生中转 Activity。
3. 中转 Activity 按顺序尝试多个系统入口：
   - 指定本动态壁纸的 `ACTION_CHANGE_LIVE_WALLPAPER`
   - 字符串兜底版 `android.service.wallpaper.CHANGE_LIVE_WALLPAPER`
   - `ACTION_LIVE_WALLPAPER_CHOOSER`
   - `Settings.ACTION_WALLPAPER_SETTINGS`
   - `Intent.ACTION_SET_WALLPAPER`
4. 修改提示文案，不再说“已跳转”，而是提示“正在打开系统壁纸页面”。
5. 如果所有入口失败，原生层会弹出失败 Toast。

## 修改文件

- `android/app/src/main/kotlin/com/example/quote_app/WallpaperApplyActivity.kt`
- `android/app/src/main/kotlin/com/example/quote_app/IntimacyWallpaperChannel.kt`
- `android/app/src/main/AndroidManifest.xml`
- `lib/pages/touch_mystify_wallpaper_page.dart`

## 验收方式

点击触摸页底部按钮后，应出现系统壁纸相关页面。如果设备不支持直接指定动态壁纸预览，应至少进入系统壁纸设置/动态壁纸选择器，而不是停留在 App 当前页面只显示提示。
