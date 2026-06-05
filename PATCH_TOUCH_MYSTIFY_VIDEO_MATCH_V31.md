# PATCH_TOUCH_MYSTIFY_VIDEO_MATCH_V31

本次升级基于 V30 最新源码，重点改造“释放后的余韵阶段”。

## 目标

将余韵从简单的点线/小气泡，升级为接近参考视频的水域气泡动画：

- 深蓝、钴蓝、青蓝交融的水下玻璃背景。
- 左下到右上的青绿色斜向光束。
- 多颗完整透明圆泡缓慢漂移、上升、错位。
- 每颗泡泡拥有彩色肥皂膜边缘：粉紫、青蓝、湖绿、淡黄、蓝紫。
- 每颗泡泡拥有白色椭圆高光，增强透明球体的立体感。
- 前段仍以抽象光迹表达分离、吸引、同步、临界、释放；余韵阶段表达亲密交融后的温柔、松弛与余温，不出现具象身体或露骨画面。

## Android 原生动态壁纸

文件：`android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

- 渲染线程命名升级为 `IntimacyMystifyGLRendererV31AfterglowBubbles`。
- 新增 `drawAfterglowBubbleAquarium(...)`：
  - 只在 `余韵` 阶段绘制。
  - 绘制深蓝水域底雾、暖色远处雾光、左下斜向青绿光束。
  - 使用确定性 hash 生成气泡群，气泡从释放中心附近散开，再进入全屏慢漂。
- 新增 `drawIridescentBubble(...)`：
  - 绘制透明暗蓝内腔。
  - 多段彩色 arc 组成肥皂膜边缘。
  - 绘制白色椭圆高光和淡青内反光。
- 新增 `hash01(...)` 用于稳定生成不同气泡位置、大小、出生时间和漂移速度。
- `bubbles` 默认值改为 `true`。
- 余韵阶段旧光迹透明度进一步降低，让气泡成为主视觉，不再被点线网格抢占。

## Flutter 预览

文件：`lib/pages/touch_mystify_wallpaper_page.dart`

- `_bubbles` 默认改为 `true`。
- 风格第一项改为 `余韵水域气泡`。
- 开关文案改为 `余韵水域气泡`。
- 新增 `_drawAfterglowBubbleAquarium(...)`：
  - 绘制蓝色水域渐变、斜向光束、漂浮泡泡群。
- 新增 `_drawIridescentBubble(...)`：
  - 绘制透明圆泡、彩膜弧边、白色椭圆高光。
- 预览中余韵阶段会压低残余线条，使泡泡、水域、光束成为主要观感。

## UI 文案

- 生理赋能/触摸入口改为：`触摸 · 余韵水域气泡：透明圆泡、彩膜边缘、白色高光`。
- 发现之旅提示改为：`触摸入口已升级为余韵水域气泡壁纸：深蓝水域、透明圆泡、彩膜高光`。

## 构建建议

```bash
flutter clean
flutter pub get
flutter analyze
flutter build apk --debug
```

当前沙盒环境没有 Flutter / Android SDK，因此无法在这里执行真实构建。
