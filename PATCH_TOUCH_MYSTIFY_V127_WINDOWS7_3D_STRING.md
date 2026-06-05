# PATCH_TOUCH_MYSTIFY_V127_WINDOWS7_3D_STRING

本次继续针对“发现之旅 / 生理赋能 / 触摸”动态壁纸动画优化。

## 一、为什么继续重构

用户反馈：当前效果仍然不佳，可能源码采用的算法与 Windows 7 Mystify screensaver 存在巨大差距。

经过继续分析，之前版本虽然加入了“控制点 + 光弦 + 残影”，但仍然存在一个核心偏差：

- Android 当前笔触仍然过多影响最终图形；
- 控制点虽然有序，但仍偏 2D 平面曲线；
- Mystify 更接近“在三维空间中运动、旋转、透视投影到屏幕上的弯曲光弦”；
- CameraFOV、LineWidth、NumLines 等参数语义也说明它不是普通 2D 拖线，而是带视距、线宽、数量调节的光弦系统。

因此 V127 继续把算法向 Windows 7 Mystify 的“3D 光弦 + 透视 + 同形残影”机制靠近。

## 二、核心修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

## 三、主要改造

### 1. 重写 `drawScreensaverArtistBrush(...)`
V127 中不再让上一层连续笔触直接决定最终形状。

现在上一层 `sourceStroke` 只提供：

- 舞台中心；
- 舞台尺度；
- 大致方向。

真正的主体由新的 Windows7 Mystify 风格 3D 光弦算法生成。

### 2. 新增 `buildWindows7MystifyString(...)`
这是 V127 的核心。

它生成一条有序的三维光弦：

- 主轴方向 `x`；
- 法向摆动 `y`；
- 深度呼吸 `z`；
- `yaw / roll / pitch` 旋转；
- `CameraFOV` 式透视投影。

最后投影成屏幕上的 2D 弯曲光弦。

### 3. 新增 CameraFOV 式距离呼吸
新增：

- `mystifyCameraFov(...)`

模拟 Windows 7 Mystify 中 CameraFOV 的语义：

- 近时主体更大、更包围；
- 远时主体更轻、更靠内；
- 这种距离感随时间缓慢变化。

### 4. 新增 LineWidth 式亮核控制
新增：

- `mystifyLineWidth(...)`

对应 LineWidth 的视觉语义：

- 保持当前光弦清晰；
- 保留亮核；
- 避免再次堆成大面积光雾。

### 5. 残影改为同形历史切片
V127 中历史残影不是宽膜面，不是乱网，而是同一条三维光弦在过去时刻的完整投影切片。

这样更符合 Mystify 的核心：

- 当前是一条明亮弯曲光弦；
- 过去的同形光弦逐渐淡去；
- 慢时切片更密；
- 快时切片更疏。

### 6. 色轮循环重新调整
改造：

- `mystifyPaletteFromHue(...)`

改为更明显的循环色轮，但仍保持冷色主导，避免手机桌面上过于花乱。

### 7. 删除/替换不合适的宽膜面逻辑
V127 的当前光弦不再画宽大 ruled surface，不再加入不稳定侧闪，只保留：

- 彩色外线；
- 青白亮核；
- 少量贴合曲线的局部高光。

目标是防止重新变成光雾或毛团。

## 四、同步更新文案

同步更新：

- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本文案升级为 V127。

## 五、检查项

- 已检查 Java 大括号平衡；
- 已确认不再引用之前导致编译失败的 `cfg.intensity`；
- 当前环境没有 Android SDK，因此未在容器中生成 APK。
