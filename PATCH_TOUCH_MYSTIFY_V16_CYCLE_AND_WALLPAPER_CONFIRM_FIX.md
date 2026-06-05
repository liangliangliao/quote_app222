# V16：周期重复与壁纸设置流程修复

## 1. 周期问题

问题：用户在短时间内看到多次释放/余韵，原因是 `previewAccelerated` 被保存后，真实桌面动态壁纸也可能按几分钟演示周期运行。

修复：

- `previewAccelerated` 只在 Android 系统动态壁纸预览引擎 `Engine.isPreview() == true` 时生效。
- 一旦壁纸真正应用到桌面/锁屏，强制使用真实周期：默认 1～365 天。
- 真实桌面壁纸中，每个周期只会出现一次临界、一次释放、一次余韵。
- `previewAccelerated` 和 `previewCycleMinutes` 不再参与真实周期签名，避免仅修改预览参数就重置真实周期。

## 2. 壁纸设置问题

问题：很多系统不允许第三方应用静默直接替换动态壁纸，之前先尝试 direct set 会显示“失败”，让用户误以为功能未生效。

修复：

- App 不再默认走 direct set。
- 点击按钮后直接打开系统动态壁纸预览页。
- 用户需要在系统预览页点击“设置壁纸/应用”。这是 Android 对动态壁纸最兼容的流程。
- 文案已改为“打开系统动态壁纸预览并应用”，不再误导为 App 能静默替换。

## 主要修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
- `lib/pages/touch_mystify_wallpaper_page.dart`
