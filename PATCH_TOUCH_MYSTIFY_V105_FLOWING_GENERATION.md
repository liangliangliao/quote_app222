# PATCH_TOUCH_MYSTIFY_V105_FLOWING_GENERATION

本次继续针对“发现之旅 / 生理赋能 / 触摸”主体动画优化，重点开发：

- **V105，方向 A：更强的“边画边消散的流动感”**

目标不是进一步强调“完整成品感”，而是进一步强化：
- 过程流动感
- 前沿生成感
- 后方同步退隐
- 动态书写 / 动态雕塑生成的过程美

## 一、主体行为继续朝“过程本身”推进

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 缩短停顿、缩短残留
调整：
- `continuousPenBaseDrawForFade()`
- `continuousPenBasePauseForFade()`
- `subjectPhaseFeedbackFade(...)`

本次进一步：
- 缩短停顿时间；
- 提高停顿期退隐速度；
- 提高主体中后段的衰减力度；

这样主体不容易滞留成“完成后还在展示”的状态。

### 2. 缩短作画窗口，增强前沿生成感
在 `drawContinuousPenDrawingSubject(...)` 中：
- 将移动作画窗口进一步缩短；
- 并给窗口长度增加轻微动态变化；
- 新增 `flowLag`，让后沿更容易被抛下；

结果是：
- 当前画面重心更集中在“正在生成的前沿”；
- 后方已画过部分更快退隐；
- 更像连续发生的艺术过程，而不是主体逐步堆完整。

### 3. 主体阶段几乎总在“画+退”状态
调整：
- `basePause`
- `drawBudget`
- `birth/endFade`

使得主体阶段：
- 停顿极短；
- 大部分时间都在持续作画；
- 同时又持续退隐；

整体更接近：
- 边画边消散
- 边生成边消失
- 始终处于动态过程之中

## 二、视觉结构也同步减弱“完成态骨架感”

### 1. 调整 `drawVideoMeshGlyph(...)`
虽然继续保留 V103/V104 的高级丝网 / 光纱骨架基础，但这次不再强调过强的“展品骨架陈列感”，而是增强流动过程美。

具体调整：
- 降低 `drawRuledSurface(...)` 的薄面承托强度；
- 将主纱线数量从 12 调整为 9；
- 将主肋骨数量从 14 调整为 10；
- 保留但强化少量流向线，从 2 条调整为 3 条；
- 增强流向线的斜向行进感；

这样视觉上会：
- 更轻
- 更流动
- 更不像一个已经搭建完成的静态骨架
- 更像正在生成、正在流动中的作品

### 2. 母题说明同步调整
在 `continuousPenMotifRaw(...)` 附近的注释说明中同步更新为：
- 继续保留高级母题基础；
- 但整体更偏向更流线、连续游动、过程性更强的组合

## 三、同步文案
更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V105。
