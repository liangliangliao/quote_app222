# PATCH_TOUCH_MYSTIFY_V151_LIVE_FORM_FIELD

本次针对用户截图中的问题继续修复：

- 主体仍然只像一条线；
- 线条两侧出现不明细密条纹；
- 没有明显突然演变成扇形、网状、丝带、花瓣等形态；
- 先画出的部分没有明显按节奏逐渐消失。

## 核心原因

V150 虽然不再直接调用预制模板，但仍然以“核心线条”为主，扇形、网状、丝带、花瓣只是附着在小片段上的装饰。
因此视觉上仍会被看作：

> 一条线 + 两侧条纹

而不是：

> 同一主体实时演变成不同形态。

## V151 修复

### 1. 新增实时形态场
新增：
- `evolvingBrushLiveMode(...)`
- `evolvingBrushNextMode(...)`
- `evolvingBrushModeMix(...)`
- `evolvingPathPointForMode(...)`

当前主体会在同一轮创作中经历：

- 线条
- 扇形
- 场线/网纱
- 丝带
- 花瓣/回扫

这些不再只是附着装饰，而是直接改变整条主体曲线的几何形态。

### 2. 重写主曲线生成
重写：
- `buildEvolvingArtBrushPath(...)`

现在主曲线本身会在不同形态之间 morph，不再只是固定弯线。

### 3. 重写主体绘制层
重写：
- `drawEvolvingArtBrushForm(...)`

新增：
- `drawEvolvingFanBody(...)`
- `drawEvolvingFieldBody(...)`
- `drawEvolvingRibbonBody(...)`
- `drawEvolvingPetalBody(...)`
- `offsetVisibleCurve(...)`

这些层会根据当前主体形态绘制对应结构，避免线条两侧出现不明条纹。

### 4. 旧笔痕更早、更明显淡出
调整：
- `evolvingArtBrushTail(...)`
- 旧段 `drawAgeFadedStrip(...)` 透明度

让先画出的内容在新内容继续生成时更明显退隐。

## 主要修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
