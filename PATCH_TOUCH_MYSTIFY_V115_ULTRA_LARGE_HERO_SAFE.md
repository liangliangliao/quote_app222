# PATCH_TOUCH_MYSTIFY_V115_ULTRA_LARGE_HERO_SAFE

本次继续针对“发现之旅 / 生理赋能 / 触摸”主体动画优化，重点开发 V115：

- 在 V114 大幅放大基础上继续提高主体占屏比例；
- 同时避免超大主体出现严重裁切、贴边或压到底部图标区。

## 一、核心目标

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

V115 的目标是：
- 主体进一步成为桌面主视觉；
- 不再只是在屏幕中间形成小光团；
- 继续放大，但要兼顾超大主体的锚点、边界和安全区。

## 二、核心调整

### 1. 继续扩展动态壁纸舞台

调整 `wallpaperViewportProfile(...)`：

- 进一步缩小左右安全边距；
- 进一步缩小顶部安全边距；
- 底部仍保留 Dock / 图标区保护；
- 焦点区上下左右约束继续放宽。

这样主体拥有更大的手机桌面可用空间。

### 2. 进一步提高主体 scale

调整 `continuousPenAdaptiveScale(...)`：

- 提高基础尺寸 `base`；
- 提高 `widthFit` 和 `heightFit`；
- 提高 `scale` 对屏幕可用区域的跟随程度；
- 提高 `minScale` 和 `maxScale`。

这样主体会比 V114 更大，更接近满屏主视觉。

### 3. 超大主体防裁切锚点

调整 `continuousPenAnchor(...)`：

- 超大主体更容易被裁切，因此锚点随机范围略收回到桌面焦点区附近；
- 减少过分贴边；
- 在焦点区内仍保留随机性。

### 4. 放宽最终边界 clamp

调整 `continuousPenPoint(...)` 的最终边界：

- `edgeInsetX / edgeInsetY` 继续缩小；
- 避免最终点位再次被过度压缩。

### 5. 增强主体视觉体量

调整 `drawCoherentFlowCreation(...)`：

- 增加 `widthUpper / widthLower`；
- 增强薄膜层和内层光纱透明度；
- 增强上下边界高光；
- 当前可见作画段进一步拉长；
- `sampleCount` 与最终 alpha 略提高。

## 三、同步文案

更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V115。
