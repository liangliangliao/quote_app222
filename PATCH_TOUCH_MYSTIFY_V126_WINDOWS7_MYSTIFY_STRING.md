# PATCH_TOUCH_MYSTIFY_V126_WINDOWS7_MYSTIFY_STRING

本次继续优化“发现之旅 / 生理赋能 / 触摸”动态壁纸主体。

## 一、问题复盘

用户反馈当前效果仍然不佳：

- 主体看起来像一团光雾 / 光网；
- 缺少 Windows 7 Mystify 那种清晰、优雅、持续变形的弯曲光弦；
- 虽然具备一些生命感，但控制点和侧向膜面混在一起后，主体不够清楚。

## 二、技术判断

Windows 7 Mystify 的关键不是“越复杂越好”，而是：

- 一条或少数几条弯曲光弦；
- 光弦自身不断变形；
- 色彩缓慢循环；
- 历史切片短暂残留并淡去；
- 速度慢时残影更密，速度快时残影间距更大；
- 当前光弦比残影更清晰。

因此本次继续回到“弯曲光弦 + 短历史切片”的核心机制。

## 三、主要改造

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 重写 `drawScreensaverArtistBrush(...)`

V126 将主体拆成三层：

1. 淡历史切片；
2. 清晰当前光弦；
3. 极少量贴附于当前光弦的生命性侧闪。

历史切片不再绘制宽面，只绘制完整曲线残影，避免重新变成光雾。

### 2. 重写 `buildScreensaverControlCurve(...)`

上一版控制点仍可能互相折叠。
V126 改为：

- 控制点沿主轴保持严格有序；
- 只在法向做连续弯曲、呼吸和轻微反弹；
- 使用更低幅度的局部转折；
- 避免形成自交、乱团、毛球。

### 3. 调整残影机制

- 减少 trails；
- 残影只作为历史记忆，不参与大面积膜面叠加；
- 当前主弦始终最清楚；
- trailGap 仍随 speedPulse 变化，保留速度与距离感。

### 4. 新增当前光弦绘制方法

新增：
- `drawMystifyCurrentString(...)`
- `drawMystifyAttachedAccent(...)`

当前光弦由 cyan 主线 + 白色核心构成；
少量侧闪必须贴附在当前曲线上，不再独立漂移。

### 5. 保留但克制生命感

保留：
- FOV 式呼吸；
- 控制点节奏变化；
- 色彩循环；
- 少量侧向生命闪光；

但不再让生命感牺牲主体清晰度。

## 四、同步更新

已同步更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本文案升级为 V126。
