# PATCH_TOUCH_MYSTIFY_V153_FLOW_FIELD_ARTIST_BRUSH

本次继续优化“发现之旅 / 生理赋能 / 触摸”动画主体。

## 一、为什么 V152 几乎没效果

V152 虽然声称“主体几何自身变形”，但实际仍然是：

- 一条中心曲线；
- 通过局部模式让中心曲线弯曲；
- 再在曲线旁边附加场线、肋线、膜面。

所以视觉上仍然容易变成：

- 一根线；
- 线两侧挂着条纹；
- 没有真正从主体内部生成丰富形态。

这不是自由创作，而是中心线加装饰。

## 二、V153 的核心改造

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 当前主路径改成流场生成画笔
将当前主路径从：

- `drawMetamorphicCreativeBrush(...)`

改为：

- `drawFlowFieldArtistCreationV153(...)`

即：不再用一条中心曲线承载所有形态。

### 2. 使用统一创作场中的粒子笔迹
V153 的主体由多个共享同一中心、同一构图、同一生命周期的粒子笔迹组成。

每条粒子笔迹有自己的：

- 出生时间；
- 当前年龄；
- 轨迹尾迹；
- 淡出节奏；
- 局部风格状态。

这些粒子不是多个独立主体，而是一个统一创作场的内部笔迹。

### 3. 形态由流场生成，不再是模板替换
新增：

- `flowFieldParticleLocalPoint(...)`
- `flowFieldPointForMode(...)`
- `flowFieldStyleIndex(...)`
- `flowFieldNextStyleIndex(...)`
- `flowFieldStyleMix(...)`

这些方法让笔迹在不同时间与位置连续流经：

- 书写线；
- 扇面流；
- 场线/网纱；
- 旋涡/星芒；
- 飘带；
- 花瓣回扫。

这些形态不是直接画出完整模板，而是由粒子运动连续生成。

### 4. 先画内容边画边消失
每条粒子笔迹都有短尾迹。

旧部分不是等全部画完后一起消失，而是：

- 粒子出生；
- 留下短尾迹；
- 继续运动变形；
- 尾迹逐步淡去；
- 新粒子继续补充主体。

## 三、参考方向

本次参考的是开源艺术屏保的生成式思路：Flurry 类型的粒子流、Flux / Fieldlines 类型的场线运动、Solarwinds 类型的光粒尾迹。

## 四、同步更新

更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本文案升级为 V153。
