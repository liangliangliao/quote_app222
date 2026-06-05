# PATCH_TOUCH_MYSTIFY_V143_LIVE_MORPHING_BRUSH

本次继续优化“发现之旅 / 生理赋能 / 触摸”动画主体。

## 一、问题复盘

用户反馈当前效果仍然存在两个核心问题：

1. 画笔一直沿着固定形状画下去，缺少实时灵活变化；
2. 先画出的内容没有在创作过程中按合适节奏逐渐消失，而是容易等全部画完后再统一淡出。

这会导致动画看起来不像 Windows7 Mystify 或其他艺术屏保那样持续即兴创造，而更像固定模式的重复作画。

## 二、参考方向

本次继续参考以下公开/开源艺术屏保思路：

- Windows7 Mystify：弯曲光线持续变形、颜色循环、短暂同形残影；
- XScreenSaver：大量独立图形 demo / hack 持续绘制；
- rss-glx / Really Slick Screensavers：Flux、Euphoria、Fieldlines、Solarwinds 等偏光带、场线、粒子和流体结构的屏保；
- Flurry：粒子/流场式连续运动。

本次不是复制第三方源码，而是借鉴其“持续生成 + 实时变化 + 历史痕迹渐隐”的机制。

## 三、核心改造

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 同一短句内实时切换笔法
新增/改造：

- `generativeBrushShapeStyleLive(...)`
- `generativeBrushStyleFromOrder(...)`
- `generativeBrushStyleChangePulse(...)`

原先一个短句只选择一种风格，例如整段都是丝带或整段都是扇形。

V143 改成一个短句内部按阶段切换：

- 线条
- 扇形 / 波束
- 网纱 / 场线
- 飘带 / 钩形
- 花瓣 / 羽翼

每个短句会根据不同顺序组合这些笔法，避免一直沿着固定形状画下去。

### 2. 局部笔法也随曲线位置变化
在 `drawGenerativeGrowingForm(...)` 中，不再只使用单个 `brushStyle` 控制整段形体。

现在每个局部点都会根据：

- 当前短句阶段；
- 曲线局部位置 `u`；
- 当前时间；

计算自己的 `localStyle`。

这样同一条连续笔触中，前段可能已经变成扇形，中段可能正在过渡成网纱，尾段仍保留线条或丝带特征。

### 3. 增加网纱笔法
新增 `localStyle == 4` 的网纱 / 场线模式：

- 更宽、更轻；
- 肋线更多；
- 视觉上更接近场线/网纱类屏保，而不是一直线性书写。

### 4. 边画边淡去
重写 `generativeCreationSegments(...)`。

原来更接近：

- 从起点到当前点逐渐增长；
- 旧内容容易保留过久；
- 最后一起淡出。

现在改成：

- 一个连续创作窗口向前推进；
- 窗口先扩张，再逐渐缩短；
- 尾端会跟上前端，形成边画边消失的过程。

这样更接近屏保中的短暂残影，而不是等待整段完成后统一消失。

### 5. 恢复少量历史残影，但不制造分身
`trails` 从 1 提升为：

- 省电模式：3
- 普通模式：5

但旧切片只画更窄、更淡的轨迹，不再重画完整主体，避免重新出现“复制/分身”的问题。

## 四、同步更新

更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本文案升级为 V143。
