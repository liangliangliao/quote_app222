# PATCH V15：Mystify 游走显现 + 尾部同步缓慢消失 + 动态壁纸真正设置修复

## 1. 视觉逻辑修复

本次重点修复“当前光迹一边游走显现，同时尾部又在缓慢消失”的动态结构。

旧逻辑问题：
- 可见曲线更像整条线出现后再整体衰老消失；
- 尾部退场不够像 Windows Mystify 的残影离场；
- 设置页预览和真实壁纸都容易出现“虫子逐渐死掉”的观感。

新逻辑：
- 每个 Stroke 不再作为完整曲线一直显示；
- 使用沿曲线滑动的可见窗口：`head` 向前推进，`tail = head - visibleWindow` 同时向前推进；
- 当前对象只负责画“正在出现的那一段”；
- 已离开的尾迹交给 OpenGL FBO 残影慢慢衰减；
- 设置页 Flutter 预览同步采用移动窗口逻辑。

## 2. 真实壁纸设置修复

旧逻辑：
- 只调用 `ACTION_CHANGE_LIVE_WALLPAPER` 打开系统预览页；
- 如果用户没有在系统页点击“设置壁纸/应用”，手机壁纸不会真正替换。

新逻辑：
- 新增 `setLiveWallpaperDirect` MethodChannel 方法；
- 优先调用 `WallpaperManager.setWallpaperComponent(...)` 直接设置当前动态壁纸；
- 如果厂商系统/权限拦截，则回退到系统动态壁纸预览页；
- Manifest 新增 `android.permission.SET_WALLPAPER`；
- Flutter 按钮文案改为“直接设置/打开系统动态壁纸”。

## 3. 修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
- `android/app/src/main/kotlin/com/example/quote_app/IntimacyWallpaperChannel.kt`
- `android/app/src/main/AndroidManifest.xml`
- `lib/platform/intimacy_wallpaper_bridge.dart`
- `lib/pages/touch_mystify_wallpaper_page.dart`

## 4. 测试重点

1. 观察光迹是否变成：头部游走显现，尾部同时逐渐淡出。
2. 点击“直接设置/打开系统动态壁纸”后，查看是否能直接替换当前动态壁纸。
3. 如果直接设置失败，是否能自动打开系统动态壁纸预览页，并提示用户手动点击设置。
