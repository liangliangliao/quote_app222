# PATCH_TOUCH_MYSTIFY_V135_VISIBLE_CREATION_PROCESS

本次继续优化“发现之旅 / 生理赋能 / 触摸”的 Mystify 动态壁纸主体。

## 一、问题复盘

用户反馈的关键问题不是“主体数量不够”或“形状种类不够”，而是：

- 看不到它正在画；
- 看不到内容如何从无到有；
- 看不到中间发展变化；
- 看不到旧内容如何退隐；
- 因此画面仍然像成品主体在移动，而不像 Windows7 Mystify 那种现场即兴绘画。

## 二、技术分析

公开资料可确认 Windows7 Mystify 的核心是：

- 一条或多条弯曲光线在黑底上移动；
- 光线持续改变形状并循环颜色；
- 留下与当前光线同色同形的短暂残影；
- 残影会快速淡去；
- CameraFOV / LineWidth / NumLines / Blur 影响视场、线宽、数量和残影淡化。

因此，本次重点不是再堆更多图形，而是让每段短句具有明确的时间过程：

起笔显现 → 沿曲线逐段绘制 → 短暂发展 → 快速淡去。

## 三、主要修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

## 四、核心改造

### 1. 重写 `drawWindows7MystifyGenerativeCreation(...)`

原逻辑每个时间点直接绘制完整曲线，导致看起来像“主体已经存在并漂移”。

V135 改为：

- 每个短句根据 `generativePhraseReveal(...)` 计算绘制进度；
- 只绘制当前已经被画出来的曲线段；
- 历史残影也只保留当时已经绘制出来的段落；
- 当前笔尖增加亮核提示。

### 2. 新增绘制进度控制

新增：

- `generativePhraseReveal(...)`
- `generativePhrasePhase(...)`

用于控制每段短句从 0 到 1 的绘制进度。

### 3. 新增曲线切片

新增：

- `sliceCurveForDrawingProgress(...)`

它会根据 reveal 只截取当前曲线的一部分，从而让观众能看见“正在被画出来”。

### 4. 新增笔尖亮核

新增：

- `drawGenerativeDrawingTip(...)`

用于强化当前绘制位置，让画面更像有一支光笔正在现场作画。

### 5. 调整短句生命周期

改造：

- `generativePhraseDuration(...)`
- `generativePhraseMorphMix(...)`
- `generativePhraseLife(...)`
- `generativePhrasePulse(...)`

让每段光弦短句更清楚地经历：

- 出现；
- 绘制；
- 发展；
- 消散。

## 五、同步更新

更新：

- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本文案升级为 V135。
