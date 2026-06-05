# Touch Mystify V44 - Video-observed curled membrane subject

本次只继续优化“发现之旅 / 生理赋能 / 触摸”动态壁纸的主体阶段形体，不改释放阶段和余韵阶段函数。

## 对视频主体的重新抽象

视频中的主体不是截图中那种相互交叉的粗白/黄/粉色光带，也不是中心线两侧等宽展开的飘带，而是：

- 一条弯曲折脊牵引的单侧薄膜；
- 宽肩主要在前半段，末端快速收束成细钩或细茎；
- 大部分时间黑场占比很高，只有一片主体或极少暗回声；
- 颜色以绿、青、紫为主，暖色只作为很细的早期折线，不应该形成宽黄色带；
- 贴面肋纹是从外缘收束到折脊的细线，不是沿中心线平行铺成第二条粗带；
- 形体随阶段变化：分离偏细 S 线，吸引略展开，同步出现紫色月牙/卷帘，临界变成更明显的绿色卷曲薄膜和细茎。

## 主要源码改动

- Android 原生壁纸：`IntimacyMystifyWallpaperService.java`
  - `initVideoSilkBladeSubject(...)` 改为接收 `Phase`，按阶段生成局部卷曲骨架。
  - `drawVideoSilkBladeSubject(...)` 改为接收 `Phase`，按阶段控制膜面宽度、色相、肋纹密度和亮度。
  - 主体阶段 FBO 残留继续压短，避免多片旧膜叠成彩色大 X。
  - 主体阶段单次生成间隔略放长，保留视频里的黑场和单主体感。
  - 主体阶段 `baseWidth` 不再放大成大色带，只作为极细折脊/边线宽度。

- Flutter 预览：`touch_mystify_wallpaper_page.dart`
  - `_drawVideoSubjectPreview(...)` 同步改成卷曲单侧薄膜。
  - `_videoSubjectBasePoint(...)` 同步按阶段生成局部骨架。

## 保持不变

以下 Android 原生函数与 V43 完全一致：

- `drawReleaseEruption`
- `drawAfterglowBubbleAquarium`
- `drawIridescentBubble`

