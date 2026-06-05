# PATCH_TOUCH_MYSTIFY_V110_VIDEO_STYLE_REBUILD

本次继续针对“发现之旅 / 生理赋能 / 触摸”主体动画优化，重点响应：

- 用户要求继续 V110；
- 方向为：按视频中的创作感继续重构，而不是只做零散小修补。

## 一、核心目标

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

V110 的目标是：
- 让主体更像视频里那样，是一支笔在连续创作；
- 减少“随机换一个形状”的感觉；
- 强化“起笔—展开—分化—收束”的过程性；
- 继续保持边画边退隐，而不是进入完整成品展示。

## 二、核心重构点

### 1. 主体不再只依赖离散母题，而是增加“相邻母题连续变形”
在 `drawContinuousPenDrawingSubject(...)` 中：
- 不再只取一个 `motif`；
- 改为同时计算 `motifA` 与 `motifB`；
- 新增 `motifMix`；
- 主体会在一次创作过程中，从一个流线母题平滑过渡到相邻母题。

这样可以减少：
- A 形状画完后突然跳成 B 形状的感觉；
- 更接近视频里那种“同一个形体在演化”的观感。

### 2. 新增“创作句法”参数
在 `drawContinuousPenDrawingSubject(...)` 中新增：
- `formOpen`

它用于控制主体在一次创作中的：
- 起笔时逐渐打开；
- 中段充分展开；
- 后段轻微收束；

使主体更像一个连续的创作过程，而不是单纯画出一个固定图形。

### 3. 重写 `drawCoherentFlowCreation(...)`
这次继续重写主体的可视生成逻辑，使其更接近视频中的：
- 线
- 纱
- 网
- 边缘高光

具体调整：
- 保留主脊线 `spine`；
- 重新生成 `upper/lower` 两侧光纱边界；
- 重新组织中间的网状 lanes；
- 减少原先偏静态、偏骨架化的结构；
- 保留少量 ribs，但不再显得僵硬；
- 额外增加一条 `guide` 流向线，强化“正在创作中的流动感”。

### 4. 缩窄可用母题池
重写：
- `continuousPenMotifRaw(...)`
- `continuousPenShapeFamily(...)`

V110 不再保留过多离散差异太大的母题，而是只保留更适合连续创作与连续变形的少数流线母题，例如：
- `13, 14, 15, 17, 22, 23, 10, 12`

并同步收缩形态家族分类，使它们更利于平滑过渡。

### 5. 新增 `continuousPenLocalByFamily(...)`
新增方法：
- `continuousPenMotifVariant(...)`
- `continuousPenLocalByFamily(...)`

作用：
- 不再在 `continuousPenPoint(...)` 里维持庞大而跳跃的 case 分支；
- 改为先映射到更少量的“流线家族”；
- 再基于家族生成局部形态；
- 并用 motif variant 保留轻微差异；

使主体更像“同一种生成语法下的变化”，而不是不同图形库之间的跳换。

### 6. 重写 `continuousPenPoint(...)`
这次重写了 `continuousPenPoint(...)`：
- 新签名接收 `motifA / motifB / motifMix / formOpen`；
- 先生成两组家族局部形态；
- 再按 `motifMix` 平滑插值；
- 再叠加轻微呼吸、句法式展开与收束；

从而使主体更像：
- 同一支笔的连续创作
- 同一生命体的连续变形

### 7. 删除当前路线下已经无用的旧函数
本次删除了在当前 V110 连续创作路线下已不再使用的连续笔旧函数：
- `continuousPenHasMembrane(...)`
- `continuousPenNormal(...)`
- `continuousPenOpenAmount(...)`

这些函数在当前 V110 路线下已经无实际调用，保留只会增加代码噪声。

## 三、同步文案
更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V110。
