# PATCH_TOUCH_MYSTIFY_V56_STANDARD_VIDEO_LIVING_RIBBON

## 目标

回退到 V47 基线，重新对齐用户标准视频中的主体：不是叶片、不是固定丝带、不是单纯漂移，而是开放式彩色光膜在黑场中连续随机运动，并实时改变膜宽、折脊、尾钩、肋线和颜色。

## 修改范围

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
  - 替换主体阶段 `drawObservedVideoMembrane(...)` 的实现。
  - 新增 V56 参考视频式 `drawReferenceLivingRibbonAtTime(...)`、`drawLivingRibbonGeometry(...)`、`livingPalette(...)` 等辅助函数。
  - 释放阶段和余韵阶段未改动。
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

## 与 V55/V54 的关键差异

1. V55 仍偏“单条绿色物体沿路径移动”，V56 改为“开放式光膜主体 + 控制点实时变化”。
2. V56 不再把主体简化为封闭叶片轮廓；膜面只从折脊向一侧展开，保持开放边界。
3. V56 的随机运动不是质心大漂移，而是：
   - 每轮随机舞台偏移、旋向、尺度；
   - 每帧对中心脊线、膜宽、卷曲、尾钩叠加低频活体扰动；
   - 通过关键动作序列实现细流线、暖色小钩、紫色卷幕、绿色大折翼、细茎回收。
4. V56 使用短历史回声层模拟 Windows Ribbons/Mystify 类屏保的拖尾感，但仍每帧清底，不恢复 FBO 长残影，避免白带/黄带/脏影。
5. V56 增强扇形肋线：绿色/紫色展开阶段会从外缘汇向尾茎，接近标准视频中“丝绸/折扇光膜”的观感。

## 验证

已用本地 Android/OpenGL/EGL 轻量桩类对核心 Java 文件执行 `javac` 语法级编译检查，通过。
完整 Gradle 构建仍受源码包缺少 `android/gradle/wrapper/gradle-wrapper.jar` 限制。
