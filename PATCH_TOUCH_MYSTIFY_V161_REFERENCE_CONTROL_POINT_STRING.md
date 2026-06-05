# PATCH_TOUCH_MYSTIFY_V161_REFERENCE_CONTROL_POINT_STRING

本次继续主动检查最新动画源码，并对照标准参考视频继续修复。

## 一、V160 与标准参考视频的主要重大差距

V160 虽然比早期版本更清楚，但仍然存在一个主要结构性差距：

- V160 仍然主要依赖固定光形家族：丝带、叶片、薄翼、钩形、环弧等；
- 每一段虽然有头部变形，但本质仍偏向“familyA 逐渐进入 familyB”；
- 参考视频则更像少数控制点形成的光弦持续运动、弯曲、透视变化，并留下极淡时间切片；
- 也就是说，参考视频更接近“运动控制点光弦”，不是“模板家族变体”。

因此，当前还不能说非常接近。

## 二、参考技术方向

继续参考：

- Windows Mystify：弯曲光线持续改变形状、颜色循环、留下短暂淡去的同色同形残影；CameraFOV / LineWidth / NumLines / Blur 影响远近、线宽、数量和残影。
- XScreenSaver：graphics hack 的基本结构是初始化状态后，每一帧推进并绘制当前状态，而不是一次性画好静态图。
- rss-glx / Really Slick Screensavers：Flux、Euphoria、Fieldlines、Solarwinds 等强调光带、场线、粒子、流动状态的生成式视觉机制。

## 三、V161 改造重点

文件：
`android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 新增 V161 主入口

新增并启用：

```java
 drawReferenceVideoTimePainterV161(...)
```

当前主路径已从 V160 切换到 V161。

### 2. 从“固定光形家族”转向“运动控制点光弦”

新增：

```java
buildV161ProjectedCurve(...)
v161ControlPoint(...)
```

V161 不再主要调用 v159TargetPoint 作为主形态，而是通过 6 个控制点在 3D 空间中持续变化，再经透视投影成屏幕光弦。

### 3. 保留单一主体与大留白

仍然保持：

- 单一主体；
- 单一创作中心；
- 黑底大留白；
- 克制白色芯线；
- 不主动生成多个独立主体。

### 4. 同源时间切片表达“旧笔痕退隐”

V161 保留 1～2 层非常淡的历史切片：

- 旧切片与当前光弦同源；
- 不重画完整复杂主体；
- 不制造多个主体分身；
- 用来表达旧笔痕正在退隐。

### 5. 先画内容边画边消失

继续通过：

```java
v161Head(...)
v161Tail(...)
```

让头部继续创造，尾部追赶淡出。

## 四、预期改善

V161 目标不是增加更多花样，而是把主体生成方式从“光形模板”推进到更接近参考视频的：

- 一条清晰光弦；
- 控制点持续运动；
- 透视呼吸；
- 当前切片清楚；
- 旧切片淡退；
- 主体不乱、不复制、不分身。
