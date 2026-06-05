# PATCH_TOUCH_MYSTIFY_V164_AUTONOMOUS_CONTROL_STRING

本次继续主动检查最新动画源码，并和标准参考视频进行对比。

## 一、V163 仍然存在的主要重大差距

V163 已经把主体收束为“细轮廓光弦 + 极淡时间切片”，比之前的乱线团、多个主体、膜面主体更克制。
但它仍然存在一个主要重大差距：

> V163 仍然借用 `familyA / familyB` 的光形家族模板，并在两种家族之间做插值。

这会导致动画看起来仍然像：

- 某个模板形体正在变成另一个模板形体；
- 而不是少数控制点组成的光弦自己在时间中连续弯曲、呼吸、生成、退隐。

标准参考视频的关键不是“模板切换”，而是更像：

- 一条或少数几条光弦在黑色空间中由控制点驱动；
- 光弦自己不断改变曲率、开合、深度和方向；
- 旧形态作为极淡时间切片退隐；
- 主体保持清楚、克制、大留白。

## 二、V164 的核心改造

主要修改文件：

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

新增并启用：

- `drawReferenceVideoTimePainterV164(...)`
- `drawV164AutonomousString(...)`
- `buildV164ProjectedCurve(...)`
- `v164AutonomousControlPoint(...)`
- `drawV164SparseFieldThreads(...)`
- `drawV164BrushTip(...)`

## 三、关键变化

### 1. 不再使用 familyA/familyB 模板插值作为当前主路径

V164 当前主路径不再依赖：

- `v162Family(...)`
- `v162ControlPointForFamily(...)`

作为主体变形来源。

### 2. 改为连续形变力场驱动

V164 的控制点由连续变化的形变系数驱动：

- curl：弯曲 / S 型曲率
- spread：展开 / 扇形感
- loop：回环 / 空间弧
- wing：翼面 / 花瓣感
- field：少量场线纹理

这些系数连续变化，而不是离散模板之间切换。

### 3. 继续保留参考视频式克制结构

- 单一主体
- 黑底大留白
- 少量轮廓光弦
- 细白芯线
- 极淡同源历史切片
- 不恢复多主体、粗膜面、肋线堆叠、乱线团

### 4. 保留边画边退隐逻辑

V164 继续使用：

- `v164Head(...)`
- `v164Tail(...)`

让头部继续创造，尾部逐渐追赶，先画出的部分逐渐退隐。

## 四、同步更新

同步更新：

- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本文案升级为 V164。
