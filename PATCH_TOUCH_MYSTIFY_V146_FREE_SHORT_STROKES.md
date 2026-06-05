# PATCH_TOUCH_MYSTIFY_V146_FREE_SHORT_STROKES

本次基于 V145 实际运行视频继续修复“像爬行类动物”的问题。

## 观察结论

用户提供的 V145 运行视频中，主体仍然表现为：

- 一个类似有身体的发光形体在屏幕中爬行；
- 形态变化主要发生在“身躯局部”；
- 视觉上仍然不是自由画笔的即兴创作；
- 不像 Windows Mystify / Flurry / Flux 类屏保那样由多个短生命光迹此起彼伏地生成、展开、退隐。

根因是：源码虽然做了实时换笔法，但底层仍然使用“一条连续脊线 + 两侧膜面/肋线”的结构。
只要这个结构不变，视觉上就很容易被理解成一条有身体的生物在爬。

## 核心改造

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 暂时跳过旧蛇形主体算法
在 `drawWindows7MystifyGenerativeCreation(...)` 中新增 V146 分支：

- 不再进入旧的连续身躯算法；
- 改为调用 `drawFreeArtistScreensaverBrush(...)`；
- 旧算法保留在源码中，但当前不作为主渲染路径。

### 2. 新增自由短笔触生成器
新增：

- `drawFreeArtistScreensaverBrush(...)`
- `freeBrushEventStyle(...)`
- `freeBrushEventCenter(...)`
- `freeBrushEventAngle(...)`
- `buildFreeBrushSpine(...)`
- `freeBrushSubCurve(...)`
- `sampleCurveUnit(...)`

它们把一个大主体拆成多个“短生命笔触事件”。
每个事件拥有自己的：

- 位置
- 方向
- 生命周期
- 生长进度
- 笔触风格
- 淡出节奏

这样画面不再依赖一个持续爬行的身体。

### 3. 新增多种短笔触风格
新增：

- `drawFreeBrushLine(...)`
- `drawFreeBrushRibbon(...)`
- `drawFreeBrushPetal(...)`
- `drawFreeBrushFan(...)`
- `drawFreeBrushMesh(...)`

同一段创作里会按短生命事件依次出现：

- 线条
- 扇形
- 网纱
- 丝带
- 花瓣

目标是让画面更像“多笔即兴创作”，而不是“一个身体继续爬行”。

## 技术意图

这次不是继续给旧主体增加特效，而是改变视觉语法：

- 从“长身体”改为“短笔触事件”；
- 从“爬行”改为“此起彼伏的绘制”；
- 从“身体局部变化”改为“每一笔各自生成、展开、消失”。

## 同步更新

更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本文案同步升级为 V146。
