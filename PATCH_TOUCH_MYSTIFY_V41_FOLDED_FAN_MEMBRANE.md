# PATCH_TOUCH_MYSTIFY_V41_FOLDED_FAN_MEMBRANE

本补丁继续完善“发现之旅 / 生理赋能 / 触摸”动态壁纸主体阶段的参考视频形体。

## 范围

- 只改主体阶段：分离、吸引、同步、临界。
- 释放阶段保持现有函数 `drawReleaseEruption` 不变。
- 余韵阶段保持现有函数 `drawAfterglowBubbleAquarium` / `drawIridescentBubble` 不变。

## V41 形体变化

1. 将主体从“沿中心线加宽的飘带”改为“单侧扇形薄膜 / 折叠光幕”。
2. 生成方式改为：宽端从屏幕边缘或暗处展开，沿弯曲折脊收束到尖钩。
3. 膜面宽度使用屏幕尺寸比例控制，不再由中心线粗细膨胀成白色/灰色长带。
4. 肋纹按照膜面宽端到尖端的剖面贴面收束，模拟参考视频中的密集百叶/丝绸纹理。
5. 白光只保留在短折脊和尖端高光处，不再作为贯穿主体的长条。

## 修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
- `lib/pages/touch_mystify_wallpaper_page.dart`
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`
