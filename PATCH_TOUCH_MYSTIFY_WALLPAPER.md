# PATCH_TOUCH_MYSTIFY_WALLPAPER

本次正式落地“发现之旅 / 生理赋能 / 触摸”入口下的 Mystify 亲密艺术动态壁纸功能。

## 入口

- 路径：发现之旅 → 生理赋能 → 触摸
- 原触摸占位页已替换为：`TouchMystifyWallpaperPage`

## Flutter 层

新增：

- `lib/pages/touch_mystify_wallpaper_page.dart`
  - 触摸模块正式页面
  - 自带 Flutter 预览动画
  - 支持视觉风格、亲密张力、Mystify 随机性、光带宽度、残影长度、余韵气泡、省电模式
  - 支持“保存参数”“随机新构图”“设置为主屏幕/锁屏动态壁纸”

- `lib/platform/intimacy_wallpaper_bridge.dart`
  - `MethodChannel('com.example.quote_app/intimacy_wallpaper')`
  - 保存动态壁纸参数
  - 打开 Android 系统动态壁纸预览/设置页

修改：

- `lib/pages/physical_enhancement_page.dart`
  - 触摸入口跳转到新动态艺术壁纸页面

## Android 原生层

新增：

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
  - Android Live Wallpaper 原生服务
  - 使用 `WallpaperService + SurfaceHolder + Canvas 离屏残影缓冲` 实现 Mystify 风格动态壁纸
  - 两条主光带表达“两个人”的生命轨迹
  - 七阶段状态机：吸引 → 靠近 → 同步 → 升高 → 临界 → 释放 → 余韵
  - 支持残影、柔光、中心释放脉冲、余韵气泡、随机变形、省电帧率
  - 不绘制任何具象身体或露骨动作，只以抽象艺术表达亲密过程

- `android/app/src/main/kotlin/com/example/quote_app/IntimacyWallpaperChannel.kt`
  - 接收 Flutter 参数并保存到 SharedPreferences
  - 调用 `WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER` 打开系统动态壁纸预览页

- `android/app/src/main/res/xml/intimacy_mystify_wallpaper.xml`
- `android/app/src/main/res/drawable/intimacy_mystify_thumb.xml`
- `android/app/src/main/res/values/strings.xml`

修改：

- `android/app/src/main/kotlin/com/example/quote_app/MainActivity.kt`
  - 注册 `IntimacyWallpaperChannel`

- `android/app/src/main/AndroidManifest.xml`
  - 声明 `android.software.live_wallpaper`
  - 注册 `IntimacyMystifyWallpaperService`

## 说明

当前实现采用 Android 原生 Live Wallpaper。它不是 HTML/SVG，也不是普通 Flutter 页面动画；设置为系统动态壁纸后由 Android 原生服务独立渲染。不同手机厂商对“动态壁纸是否能单独设置锁屏”支持不完全一致，因此入口会打开系统动态壁纸确认页，由系统决定可设置主屏、锁屏或两者。
