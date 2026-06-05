# PATCH_TOUCH_MYSTIFY_V147_PURE_IMPROVISATION_BRUSH

本次继续优化“发现之旅 / 生理赋能 / 触摸”动画主体。

## 一、问题判断

V146 实拍后仍然出现：

- 连续脊线；
- 两侧膜面；
- 肋线；
- 类似爬行动物身躯在屏幕上爬行；
- 缺少真正的自由艺术创作感。

这说明问题不是局部参数，而是视觉语法错误。
只要仍然存在“一条贯穿全场的身体 + 两侧膜面 + 肋线”，视觉上就必然像一个身体在移动。

## 二、V147 的核心目标

V147 不再继续优化旧身体结构，而是彻底切断它：

- 不再用连续脊线作为主体；
- 不再画两侧膜面；
- 不再画附着肋线；
- 不再让一个主体拖着全场移动；
- 改为独立短笔触事件组成的即兴创作。

## 三、主要源码改造

文件：

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 重写当前主渲染路径
`drawFreeArtistScreensaverBrush(...)` 不再进入旧的短脊线 + 膜面渲染逻辑，而是直接调用：

- `drawPureImprovisationScreensaverBrush(...)`

### 2. 新增纯即兴笔触系统
新增：

- `drawPureImprovisationScreensaverBrush(...)`
- `drawPureMark(...)`
- `drawPureCalligraphyStroke(...)`
- `drawPureFanBurst(...)`
- `drawPureFieldLines(...)`
- `drawPureRibbonThreads(...)`
- `drawPurePetalSketch(...)`
- `drawPureSparkBloom(...)`

这些方法不再构造一条完整身体，而是构造一组独立的短笔触事件。

### 3. 独立笔触类型
当前包含：

1. 书写式短线；
2. 扇形光束；
3. 场线；
4. 多丝带线束；
5. 花瓣轮廓；
6. 光点爆发。

每一笔都有自己的：

- 位置；
- 角度；
- 尺度；
- 生命周期；
- 生长进度；
- 消失节奏。

### 4. 删除当前主路径中的身体化表面表达
V147 当前主路径中不再调用旧的 `drawFreeBrushRibbon(...)` / `drawFreeBrushMesh(...)` 作为主体渲染入口，避免重新生成：

- 两侧膜面；
- 肋线；
- 类似躯体的长形主体。

## 四、预期视觉变化

相比 V146，V147 的目标是：

- 更少“爬行动物”；
- 更少“身体”；
- 更少“膜面包裹”；
- 更多短笔触、光束、场线、轮廓和爆发；
- 更像黑色舞台上的即兴笔触事件。

## 五、同步更新

更新：

- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本文案升级为 V147。
