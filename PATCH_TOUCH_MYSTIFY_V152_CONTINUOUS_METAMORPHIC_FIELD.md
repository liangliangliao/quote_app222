# PATCH_TOUCH_MYSTIFY_V152_CONTINUOUS_METAMORPHIC_FIELD

本次继续优化“发现之旅 / 生理赋能 / 触摸”动画主体。

## 一、问题复盘

用户指出：

- 主体不能固定为线条或某个固定形状；
- 需要实时变化成为多种甚至任意形态；
- 需要体现变化过程，例如初始是一根线，头部逐渐演变成其他形状；
- 不能是完整形状之间直接替换；
- 当前画笔相关源码仍完全不符合自由创作艺术程序的要求。

经检查，V151 的主路径虽然取消了一部分预制模板，但仍存在核心问题：

1. 主体仍以一条中心曲线为主；
2. 扇形、网纱、丝带、花瓣主要由附着层表达；
3. 几何主体本身变化不够强；
4. 局部变化更像“线条旁边挂装饰”，而不是“主体自己在变形”。

## 二、V152 的核心改造

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 重写当前画笔主路径
`drawPureImprovisationScreensaverBrush(...)` 不再调用 V151 的 `drawContinuousEvolvingArtBrush(...)`。

改为新的：
- `drawMetamorphicCreativeBrush(...)`
- `drawMetamorphicCreativeSlice(...)`

### 2. 主体几何自身连续演变
新增：
- `metamorphicPoint(...)`
- `metamorphicPointForStyle(...)`
- `metamorphicStyleAt(...)`
- `metamorphicNextStyleAt(...)`
- `metamorphicStyleMix(...)`

这次不是先画线再附着装饰，也不是预制模板直接替换。
每个点会根据它在创作进度中的“出生时间”获得不同的笔法状态。
因此同一个主体内部会自然出现：

- 起笔线条
- 扇形展开
- 场线 / 网纱
- 丝带漂浮
- 花瓣回扫
- 星芒喷泉

这些变化属于同一条正在生长的主体，不是不同主体或不同模板依次出现。

### 3. 旧笔迹持续淡出
新增：
- `metamorphicHead(...)`
- `metamorphicTail(...)`

头部继续推进，尾部持续追赶，先画出的部分会在后续创作中逐渐淡出。
同时保留少量同源时间切片，但它们共享同一中心和同一主体逻辑，不再生成多个独立主体。

### 4. 附着层降级为辅助
新增：
- `drawMetamorphicBody(...)`
- `drawMetamorphicMorphAccents(...)`

附着层只增强当前主形态，不再承担主体变化本身。
主体变化由 `metamorphicPointForStyle(...)` 的几何场直接决定。

## 三、参考方向

本次继续借鉴开源艺术屏保的生成式思路：

- XScreenSaver：大量独立图形 hack/graphics demo 持续运行，不是播放一张预制图；
- rss-glx / Really Slick Screensavers：Flux、Euphoria、Fieldlines、Solarwinds 等通过光带、场线、粒子和流动结构形成持续生成的视觉艺术。

V152 将这些思想转译为当前 Java Canvas 动态壁纸中的“连续变形创作场”。

## 四、预期变化

相比 V151，V152 的目标是：

- 不再长期固定为一条线；
- 不再靠两侧条纹假装变化；
- 不再直接呈现完整预制形状；
- 同一主体的头部和局部会持续变成不同形态；
- 先画出的部分会在后续创作中逐渐消失；
- 更接近“主体从无到有、发展变化、逐渐消失”的艺术创作过程。
