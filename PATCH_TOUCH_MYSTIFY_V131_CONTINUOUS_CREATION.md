# PATCH_TOUCH_MYSTIFY_V131_CONTINUOUS_CREATION

本次继续针对“发现之旅 / 生理赋能 / 触摸”动画主体优化。

## 一、问题判断

用户反馈指出：Windows7 Mystify 的关键不是“先有一个主体，然后主体四处移动”，而是像一位艺术家在屏幕上持续即兴作画：

- 不断产生新形态；
- 每一次都可能画出不同内容；
- 此起彼伏；
- 颜色、残影、速度、远近和线条形态持续变化；
- 让人不知道下一秒会出现什么。

V130 虽然已经增加了 10 类控制点形态和多条光弦，但仍可能表现得像“同一主体在移动”。

因此 V131 的目标是继续把算法从“形体移动”推进到“持续创造”。

## 二、核心参考机制

根据 Windows7 Mystify 可确认资料，其核心行为更接近：

- 一条或多条弯曲光线在黑底上运动；
- 光线持续改变形状；
- 颜色循环；
- 残影同色同形，并短暂淡去；
- CameraFOV 影响远近与视场；
- LineWidth 影响线条亮度和厚度；
- NumLines 影响光弦数量；
- Blur 影响残影淡化方式。

## 三、V131 主要改造

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 光弦不只是换拓扑，也换中心和尺度
新增：
- `mystifyPhraseCenterOffset(...)`
- `mystifyPhraseStageScale(...)`

每段短句不再只改变控制点形状，也会改变：
- 舞台中心；
- 光弦尺度；
- 远近感；
- 形态展开范围。

这样主体不再只是固定中心附近的小幅变形。

### 2. 形态语法从 10 类扩展到 14 类
新增控制点形态倾向：
- 星芒压缩 / 爆发；
- 长藤卷曲；
- 云门式开合；
- 羽化波束。

这些并不是外加图形，而是 Mystify 光弦控制点拓扑的变化。

### 3. 每条光弦拥有生命相位
新增：
- `mystifyStringLife(...)`

不同光弦不再一直等强度存在，而是有：
- 出现；
- 增强；
- 减弱；
- 退场；

形成更明显的此起彼伏。

### 4. 短句切换更快、更有创造感
调整：
- `mystifyPhraseDuration(...)`
- `mystifyPhraseMorphMix(...)`

让形态变化更频繁，但仍然保持平滑过渡。

### 5. 控制点能量更强
增强：
- lateral；
- depth；
- local flicker；
- bounce；
- surge；

目标是让光弦真正改写自身，而不是只平移。

### 6. CameraFOV 呼吸更明显
调整：
- `mystifyCameraFov(...)`

增强远近变化，让主体有更明显的靠近、远离、扩张、收缩感。

## 四、同步更新

更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V131。
