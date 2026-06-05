# PATCH_TOUCH_MYSTIFY_V150_CONTINUOUS_EVOLVING_BRUSH

本次继续修复“发现之旅 / 生理赋能 / 触摸”动画模块。

## 一、确认存在的问题

当前 V149 源码中确实仍然存在类似“先画好某些形状，然后依次直接呈现出来”的逻辑。

关键原因是当前主路径中的：

- `drawLiveChangingPureMark(...)`
- `drawPureMark(...)`
- `drawPureFanBurst(...)`
- `drawPureFieldLines(...)`
- `drawPureRibbonThreads(...)`
- `drawPurePetalSketch(...)`

这些方法实际上是把完整的扇形、网纱、丝带、花瓣等模板先构造出来，再根据 reveal 显示其中一部分，甚至在风格过渡时同时调用两个完整模板。

这会造成用户看到的效果像：

- 预制形状突然出现；
- 形状之间切换，而不是同一主体连续演化；
- 看起来像“展示效果库”，而不是自由画笔正在创作。

## 二、本次核心修复

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 当前主路径不再调用完整模板切换
V150 中，`drawPureImprovisationScreensaverBrush(...)` 不再调用：

- `drawLiveChangingPureMark(...)`

而是改为：

- `drawContinuousEvolvingArtBrush(...)`

### 2. 新增连续演化主笔迹
新增：

- `buildEvolvingArtBrushPath(...)`
- `evolvingArtBrushHead(...)`
- `evolvingArtBrushTail(...)`
- `subCurveUnit(...)`

现在主体不是直接完整出现，而是有：

- 起笔；
- 头部推进；
- 尾部追赶；
- 旧笔迹逐步淡去。

### 3. 新增局部笔法场
新增：

- `drawEvolvingArtBrushForm(...)`
- `evolvingLocalStylePhase(...)`
- `drawEvolvingAttachedStroke(...)`
- `drawEvolvingArtBrushTip(...)`

扇形、网状、丝带、花瓣、光点不再作为完整主体突然出现，而是在当前主笔迹的局部小片段上即时生成。

也就是说，现在是：

> 同一条正在生长的笔迹，在不同局部实时改变笔法。

而不是：

> 一张预制扇形、一个预制网状、一个预制花瓣依次呈现。

## 三、保留但不再作为当前主路径的旧代码

旧的 `drawLiveChangingPureMark(...)` 等函数暂时保留在源码中，避免误删导致其它引用异常。
但当前主渲染路径已经不再调用它们。

后续如果 V150 效果确认正常，可以在下一版彻底删除这些旧模板函数，减少代码干扰。

## 四、同步更新

更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本文案升级为 V150。
