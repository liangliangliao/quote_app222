# Touch Mystify V47：主体阶段直接视频薄膜化

本版只针对“发现之旅 / 生理赋能 / 触摸”的主体阶段继续修正：分离、吸引、同步、临界。

## 目标

上一版仍可能出现与参考视频差距很大的旧主体残留：

- 粗白斜带、宽黄带、宽灰白扇面
- 多个大形体交叉叠成 X 或十字
- 旧 Mystify 光迹拖尾造成的残影堆叠
- 沿中心线扩宽的飘带，而不是视频里的单侧卷曲薄膜

## 本版做法

- 主体阶段不再生成和更新旧随机 StrokeEvent。
- 主体阶段每帧清底，直接绘制一枚参考视频风格的程序化卷曲薄膜。
- 主体由四层构成：暗色半透明膜面、彩色外缘、贴面等高线肋纹、极细尾茎/尖端。
- 颜色锁定为绿、青、紫色族，避免黄色/橙色宽带再次成为主体。
- 肋纹改为沿膜面方向的等高线，不再是放射网、点阵或横向粗线。

## 保持不变

- 释放阶段仍调用原 `drawReleaseEruption`。
- 余韵阶段仍调用原 `drawAfterglowBubbleAquarium` 和气泡渲染。
- 释放 / 余韵的绘制函数没有改造。

## 修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
