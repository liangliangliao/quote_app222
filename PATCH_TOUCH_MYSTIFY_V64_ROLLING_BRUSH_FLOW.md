# V64 Rolling Brush Living Flow Field

本补丁针对 V63 反馈：“跟参考视频相比，当前主体几乎不会运动和变化”。

## 核心修复

1. 主体不再是 reveal 完后停住的静态光弦网。
2. 新增滚动时间窗口：当前帧只绘制随笔尖推进的局部窗口，旧窗口交给 FBO 湿迹短暂保留并淡出。
3. 笔尖不再只在入场阶段推进，而是在主体阶段全程推进、提按、停顿、再推进。
4. 喉口/能量核位置、旋涡强度、展开角、主流线控制点、微扰场每帧持续重构。
5. 主体舞台继续放大，避免过小、过暗、像静态小线束。
6. 线条仍然主导，膜面只做极淡连接，避免退回叶片/布片。
7. 增加当前笔尖高光和短骨，让用户能明确看到“正在画”的位置。
8. 释放和余韵阶段未改动。

## 主要修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

## 验证

已使用本地 Android/OpenGL/EGL 轻量桩类对核心 Java 文件执行 `javac` 语法级检查，通过。

完整 Gradle/Flutter 构建仍受源码包缺少 `android/gradle/wrapper/gradle-wrapper.jar` 限制。
