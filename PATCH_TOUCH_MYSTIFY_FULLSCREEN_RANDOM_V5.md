# PATCH_TOUCH_MYSTIFY_FULLSCREEN_RANDOM_V5

本补丁解决用户指出的关键问题：Mystify 随机运动点即时生成线条必须覆盖手机屏幕可见范围的任意位置，而不是局限在中心或一小块区域。

## 核心修复

1. `IntimacyMystifyWallpaperService.java`
   - 将随机活动范围 `randomBounds()` 改为默认全屏/近全屏范围。
   - 新增 `fullScreenCoverage` 配置，默认 `0.92`。
   - 线条不再以中心区域为默认生成区；控制点可从屏幕边缘、角落、可见屏幕任意两点、对角长扫线出生。
   - 新增最小距离保护，避免随机点过近导致看起来只在小区域活动。
   - 保留少量局部线段，但局部区域也提升到屏幕 40% 左右，避免“局部小块”观感。
   - 默认阶段占比改为：分离 46%、吸引 22%、同步 22%、临界 6%、释放 2%、余韵 2%。

2. `touch_mystify_wallpaper_page.dart`
   - 新增“全屏活动范围”滑杆。
   - 保存配置时传入 `fullScreenCoverage`。
   - 说明文案明确：随机运动点默认覆盖手机可见屏幕任意位置。

3. `intimacy_wallpaper_bridge.dart` 与 `IntimacyWallpaperChannel.kt`
   - 新增 `fullScreenCoverage` 参数透传与持久化。

## 设计原则

真正的 Mystify 不是预设曲线移动，而是随机控制点在屏幕范围内即时生成线条，上一帧通过残影衰减留下轨迹。因此，本次重点不是增加元素，而是扩大随机控制点的出生范围、活动范围和线条跨度。

## 未验证项

当前环境无法完成 Flutter/Gradle 真机编译验证。请在本地或 CI 执行 `flutter clean && flutter pub get && flutter build apk`。如仍有编译日志，可继续按日志修复。
