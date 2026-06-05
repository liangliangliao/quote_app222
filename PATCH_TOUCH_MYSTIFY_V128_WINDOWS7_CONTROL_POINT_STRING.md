# PATCH_TOUCH_MYSTIFY_V128_WINDOWS7_CONTROL_POINT_STRING

本次继续针对“发现之旅 / 生理赋能 / 触摸”动画主体优化，重点响应：

- 当前效果与 Windows 7 Mystify screensaver 的即兴绘画艺术理念仍存在巨大差距；
- 需要继续深度分析 Windows 7 Mystify 的技术方案，并对当前源码做深度完善。

## 一、关键判断

前一版 V127 虽然加入了 3D、CameraFOV 与同形残影概念，但核心曲线仍然偏“参数化正弦曲线”。
这会导致它看起来像自定义的 2D/3D 光带，而不够像 Windows 7 Mystify 那种由少数控制点共同变形的光弦。

Windows 7 Mystify 更接近：

- 少数控制点在三维空间中运动；
- 控制点保持顺序，但各自具有独立速度、相位和反弹；
- 控制点通过曲线插值生成一条弯曲光弦；
- 当前光弦清晰，历史切片短暂淡去；
- CameraFOV 决定远近感；
- LineWidth 决定亮核与外线厚度；
- NumLines 决定光弦数量。

## 二、核心改造

主要修改文件：

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 重写 `buildWindows7MystifyString(...)`

V128 不再使用正弦参数曲线作为主体。

新的逻辑：

- 构造 5~6 个 3D 控制点；
- 每个控制点具有独立的：
  - `x/y/z` 运动相位；
  - 反弹速度；
  - 空间扰动；
- 点序沿主轴保持有序；
- 用 Catmull-Rom 将控制点串成一条柔和光弦；
- 再通过 yaw / roll / pitch 与 CameraFOV 进行投影。

### 2. 新增 `catmullRomPoint3(...)`

新增三维 Catmull-Rom 插值函数：

- 保证控制点之间的曲线连续；
- 减少折线感；
- 让主体更像一条整体在变形的光弦。

### 3. 新增 `projectMystify3dPoint(...)`

将三维控制点曲线投影到屏幕：

- 支持 yaw；
- 支持 roll；
- 支持 pitch；
- 支持 CameraFOV 透视比例。

### 4. 残影继续保持同形切片

残影仍然不是拖尾、不是网面、不是宽膜，而是：

- 过去时间点的一整条光弦；
- 越旧越淡；
- 速度快时切片间距更大；
- 速度慢时切片更密。

### 5. 进一步抑制光雾与自定义网感

调整：

- `strings` 在正式模式下先收敛为 1 条；
- 历史切片略收缩；
- 当前光弦外线与亮核略变薄；
- 控制点运动更像独立反弹而不是同一正弦函数。

## 三、同步更新

更新：

- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本文案升级为 V128。
