# PATCH_TOUCH_MYSTIFY_V106_ZERO_HOLD_SHRINK

本次继续针对“发现之旅 / 生理赋能 / 触摸”主体动画优化，重点响应：

- 用户反馈：**还是存在画好后主体停留并展示的问题**。

因此本次不再优先扩展风格，而是继续围绕这个问题进行更强的行为收缩修复。

## 一、修复方向：继续压缩“完成态尾巴”

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

V106 的核心目标是：
- 让主体在接近完成之前就开始明显退隐；
- 尽量避免进入“已经画好、还可以被观看”的完成态展示区间；
- 进一步接近“零停留”。

## 二、具体调整

### 1. 停顿进一步接近于无
调整：
- `continuousPenBaseDrawForFade()`
- `continuousPenBasePauseForFade()`
- `drawContinuousPenDrawingSubject(...)` 内的 `baseDraw/basePause`

本次将停顿时间进一步压缩到极低：
- `basePause` 从 V105 的 `0.60 ~ 0.24` 再压到 `0.18 ~ 0.05`；
- 让主体周期几乎都落在“正在生成 / 正在退隐”区间，而不是停在完成态。

### 2. 更早开始后段衰减
调整：
- `subjectPhaseFeedbackFade(...)`

本次让：
- `late` 提前从更早阶段开始生效；
- 主体一旦进入后段，就更快融入黑场；
- 停顿期的 FBO 保留也进一步降低；

从而继续削弱“后段还可见”的尾巴。

### 3. 后段作画窗口主动塌缩
在 `drawContinuousPenDrawingSubject(...)` 中：
- 新增 `tailCollapse`；
- 它会在主体进入后段后主动缩短 `windowLen`；

效果是：
- 主体不是画到最后还保持原有可见宽度；
- 而是越到后段，窗口越收缩；
- 看起来更像“收掉 / 消散掉”，而不是“完成并停留”。

### 4. 主体接近末段时提前退出
新增逻辑：
- `if (raw > 0.94f) return;`

这意味着：
- 主体在极后段不会再继续绘制；
- 避免最后一小段仍以“几乎完成”的状态停在那儿。

### 5. 可见度公式进一步改为“溶解式”
调整：
- `birth`
- `dissolve`
- `endFade`
- 最终 `a`

本次新增 `dissolve`，让主体从中后段开始就持续走向溶解，而不是只在非常靠后的阶段才衰减。

### 6. 降低主体末段整体存在感
调整：
- `drawVideoReferenceRandomGlyph(...)` 的 alpha 系数

从 V105 的 `a * 1.78f` 继续压低到 `a * 1.55f`，
进一步减少后段完整主体被看见的机会。

## 三、同步文案
更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V106。
