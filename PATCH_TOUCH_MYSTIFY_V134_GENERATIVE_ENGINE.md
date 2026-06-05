# PATCH_TOUCH_MYSTIFY_V134_GENERATIVE_ENGINE

本次继续针对“发现之旅 / 生理赋能 / 触摸”动态壁纸动画进行深度改造。

## 一、问题判断

用户指出：即使前面做成“时间绘画版”，效果仍然与 Windows7 Mystify screensaver 差距很大。
核心问题在于：

- 动画仍然容易表现成一个已有主体在屏幕上移动；
- 主体生成没有足够强的“随机创造”感；
- 控制点短句虽然存在，但主体结构仍然可能过度依赖旧笔迹或旧构图；
- 缺少 Windows7 Mystify 那种不断出现新光弦、新构图、新形态、新节奏的“不可预期感”。

根据公开资料可确认的 Windows7 Mystify 行为机制：

- 一条或多条弯曲光线在黑底运动；
- 光线持续改变自身形状；
- 颜色循环；
- 留下同色同形、短暂淡去的残影；
- 速度、远近、残影间距变化不一致；
- CameraFOV / LineWidth / NumLines / Blur 影响视场、线宽、线数量和残影。

本次 V134 的核心是把算法从“旧主体改造”进一步推向“自主生成引擎”。

---

## 二、主要修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

---

## 三、核心改造

### 1. 改造主体入口
在 `drawCoherentFlowCreation(...)` 中：

- 不再调用旧的 `drawScreensaverArtistBrush(...)`；
- 改为调用新的 `drawWindows7MystifyGenerativeCreation(...)`。

这样渲染不再把旧笔迹当成最终主体，而是由新的生成引擎直接生成 Mystify 光弦。

### 2. 新增自主生成引擎
新增：

- `drawWindows7MystifyGenerativeCreation(...)`

该方法负责：

- 多条光弦；
- 每条光弦独立生命周期；
- 同形历史切片残影；
- 颜色循环；
- 速度影响残影间距；
- 当前亮核与历史残影分层。

### 3. 新增自主控制点曲线生成
新增：

- `buildGenerativeMystifyCurve(...)`

该方法每个短句都会重新决定：

- 构图中心；
- 舞台尺度；
- 控制点数量；
- 拓扑模式；
- CameraFOV；
- 三维旋转；
- Catmull-Rom 曲线插值。

### 4. 新增十类控制点语法
新增：

- `generativeControlPoint(...)`

支持的模式包括：

1. 经典弓形光弦
2. 双 S 变形
3. 扇形喷出
4. 钩形折返
5. 蝶翼 / 双瓣
6. 螺旋扭结
7. 星芒爆发
8. 长藤卷曲
9. 羽化波束
10. 云门开合

这些不是外加图形，而是同一条 Mystify 光弦的控制点拓扑变化。

### 5. 新增短句与生命周期函数
新增：

- `generativePhraseMode(...)`
- `generativeControlCount(...)`
- `generativePhraseDuration(...)`
- `generativePhraseMorphMix(...)`
- `generativePhraseLife(...)`
- `generativePhrasePulse(...)`
- `generativePhraseCenter(...)`
- `generativePhraseScale(...)`
- `generativeCameraFov(...)`
- `generativeStringLife(...)`
- `generativePhraseHash(...)`

这些方法共同实现：

- 每段短句变化；
- 每段不同构图；
- 每段不同尺度；
- 每段不同强弱；
- 每段之间平滑过渡；
- 每条光弦此起彼伏。

### 6. 新增贴附式当前光弦表现
新增：

- `drawGenerativeMystifyCurrent(...)`
- `drawGenerativeAttachedRibbon(...)`

当前光弦仍以清晰高光为主，但根据模式少量生成贴附式丝带、肋线或局部高光，避免再次变成线与形状分离。

---

## 四、同步更新

已同步更新：

- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本文案升级为 V134。
