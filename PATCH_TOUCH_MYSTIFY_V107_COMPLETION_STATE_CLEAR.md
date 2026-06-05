# PATCH_TOUCH_MYSTIFY_V107_COMPLETION_STATE_CLEAR

本次继续针对“发现之旅 / 生理赋能 / 触摸”主体动画优化，重点响应：

- 用户反馈：仍然存在画好后主体停留并展示的问题。

因此 V107 继续不优先扩展风格，而是进一步做“完成态清除”专项修复。

## 一、核心方向

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

V107 的目标是：
- 继续压缩主体进入“完成态展示区间”的机会；
- 让主体更像始终处于生成与撤退之间的过程；
- 不给“画好后还停留可看”的空间。

## 二、具体调整

### 1. 停顿继续压到接近没有
调整：
- `continuousPenBaseDrawForFade()`
- `continuousPenBasePauseForFade()`
- `drawContinuousPenDrawingSubject(...)` 中的 `baseDraw/basePause`

这次将 `basePause` 继续从 V106 的 `0.18 ~ 0.05` 压低到：
- `0.08 ~ 0.00`

使主体周期几乎完全被“生成 / 退隐”过程占据。

### 2. 主体后段更早、更狠地衰减
调整：
- `subjectPhaseFeedbackFade(...)`

本次让：
- `late` 更早开始起作用；
- 后段 FBO 保留继续降低；
- 停顿期残留继续减弱；

从而进一步削弱“完成态尾巴”。

### 3. 作画窗口继续变短，并更早塌缩
在 `drawContinuousPenDrawingSubject(...)` 中：
- `windowLen` 从 V106 的 `0.28 ~ 0.14` 压到 `0.22 ~ 0.10`；
- `tailCollapse` 更早开始起作用；
- `revealTail` 与 `flowLag` 进一步向“更快抛下后沿”方向调整；

让主体更难维持一个相对完整的可见轮廓。

### 4. 更早直接停止末段绘制
将主体的提前退出条件继续提前：
- 从 V106 的 `if (raw > 0.94f) return;`
- 收紧为 `if (raw > 0.88f) return;`

这意味着更靠前就直接不再绘制末段，进一步减少“几乎完成态”出现。

### 5. 可见度继续前移为“更早溶解”
调整：
- `birth`
- `dissolve`
- `endFade`
- `a`

让主体：
- 更早开始 dissolve；
- 更早进入尾段淡出；
- 末段整体存在感进一步降低。

### 6. 最终绘制强度再次降低
将：
- `drawVideoReferenceRandomGlyph(...)` 的最终系数

从 V106 的：
- `a * 1.55f`

继续压低到：
- `a * 1.32f`

进一步减少“主体完成态仍然显眼”的问题。

## 三、同步文案
更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V107。
