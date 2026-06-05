# PATCH_TOUCH_MYSTIFY_V165_RHYTHMIC_BRANCHING_STRING

本次继续针对“发现之旅 / 生理赋能 / 触摸”动画主体进行修正。

## 一、用户指出的主要问题

V164 与标准参考视频仍存在明显差距：

1. 主体一直像单一固定形状；
2. 没有分叉、突然重大变异；
3. 缺少顿挫的艺术感；
4. 主体整体运动不够流畅、不自然、不丝滑，像“寸步难行”。

## 二、原因分析

V164 虽然已经从家族模板转向了自主控制点光弦，但控制点变化仍偏连续和温和。
这会导致视觉上变成：

- 一条光弦缓慢弯曲；
- 很少有明显开合；
- 很少有局部突变；
- 缺少参考视频中的突然灵感、顿挫和局部分叉。

## 三、V165 的核心改造

主要修改文件：

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 新增 V165 主入口

新增并启用：

- `drawReferenceVideoTimePainterV165(...)`

当前主渲染路径已从 V164 切换到 V165。

### 2. 新增 beat pulse 节奏脉冲

新增：

- `v165BeatPulse(...)`
- `v165PulseAt(...)`

作用：

- 在同一段创作中设置 3 个顿挫点；
- 每个顿挫点会造成平滑但明显的加速、展开、转向、收束；
- 不是硬跳，而是“蓄势—突然展开—柔和退回”。

### 3. 控制点增加突变力场

新增：

- `v165AutonomousControlPoint(...)`

在 V164 的连续控制点基础上加入：

- 更强的 curl；
- 更强的 spread；
- loop / wing 在脉冲时增幅；
- head 端局部 split；
- depth 方向增强。

目标是让主体不再只是单一光弦缓慢弯曲，而是能在局部出现明显变异。

### 4. 新增贴附式分叉

新增：

- `drawV165BranchFlares(...)`

它会在节奏脉冲期间，从当前主光弦局部生成 1~2 条贴附式分叉。

注意：

- 分叉不是独立主体；
- 分叉锚定在当前主光弦上；
- 分叉会随当前主体显现与退隐；
- 避免回到多主体或复制分身问题。

### 5. 改善运动丝滑度

新增/改造：

- `v165Center(...)`
- `v165Angle(...)`
- `v165CameraFov(...)`

中心漂移、角度变化、透视呼吸都改成更低频、更连续的缓动。
这样避免主体整体运动像卡住或寸步难行。

### 6. 保留克制特征

V165 仍然保持：

- 单一主体；
- 黑底大留白；
- 少量轮廓光弦；
- 克制白芯线；
- 极淡同源时间切片；
- 不恢复多主体、粗膜面、乱线团。

## 四、参考的技术方向

继续参考：

- Windows Mystify：弯曲光线、颜色循环、短暂同形残影、CameraFOV / LineWidth / NumLines / Blur；
- XScreenSaver：每个 graphics hack 是持续推进状态机，而不是静态图展示；
- rss-glx / Really Slick Screensavers：Flux、Euphoria、Fieldlines、Solarwinds 等强调光带、场线和生成式流动结构。

## 五、本版定位

V165 不是简单增加线条数量，而是解决 V164 的“太单一、太固定、无顿挫、无分叉、运动不自然”问题。
