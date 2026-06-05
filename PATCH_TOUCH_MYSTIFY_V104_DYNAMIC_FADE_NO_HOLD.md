# PATCH_TOUCH_MYSTIFY_V104_DYNAMIC_FADE_NO_HOLD

本次继续针对“发现之旅 / 生理赋能 / 触摸”主体动画优化，重点响应：

1. 继续开发 V104；
2. 修复主体需要具备“边画边消失”的能力；
3. 不要刻意让已画好的主体停留并展示。

## 一、核心行为改变：从“完整展示”改为“动态退隐作画”

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 引入移动作画窗口
在 `drawContinuousPenDrawingSubject(...)` 中，本次不再使用：
- `startU = 0`
- `endU = progress`

这种“从起点一路累计到当前进度”的完整呈现方式。

改为：
- 当前笔势只显示一个 **移动中的作画窗口**；
- 窗口前端是当前笔势位置；
- 窗口尾部会随着作画推进被抛下；
- 被抛下的部分交给 FBO 残影迅速退隐。

这样实现了真正意义上的：
- 边画
- 边消失
- 持续流动

而不是“画完整再停住展示”。

### 2. 取消完整主体停驻
V104 不再保留 V94~V103 中那种：
- 先逐步完成主体；
- 再让完整主体轻微呼吸或停驻；
- 然后才退场；

的逻辑。

具体移除：
- 不再使用“前 84% 完成主体，后 16% 停驻”的节奏；
- 不再使用 `livingHold` 来增强完成态存在感；
- 停顿期直接不再额外绘制主体。

### 3. 缩短停顿感
调整：
- `baseDraw`
- `basePause`

使得：
- 单次作画仍然完整；
- 但停顿更短；
- 不会让已画好主体长时间被展示。

## 二、FBO 残影逻辑进一步收紧

### 1. 更新 `continuousPenBaseDrawForFade()` / `continuousPenBasePauseForFade()`
这两个辅助函数同步改为 V104 节奏，使 FBO 衰减逻辑与新的作画节奏匹配。

### 2. 强化 `subjectPhaseFeedbackFade(...)`
这次进一步加强：
- 主体绘制中后段的衰减；
- 停顿期的快速退尽；

目标是：
- 主体前段已经画过的痕迹更快被黑场吞没；
- 不会形成“整块主体完成后还停留在屏幕上”的效果；
- 不会让旧主体在下一轮落笔时继续凸显。

## 三、视觉方向
V104 继续保留：
- 相对高级的主体气质；
- 较统一的展品风格基础；

但重点已从“完整展品展示”切换到：
- 更流动
- 更动态
- 更像持续作画中的艺术生成过程

## 四、同步文案
更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V104。
