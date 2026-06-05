# PATCH_TOUCH_MYSTIFY_V163_REFERENCE_CONTOUR_STRING

## 本次主动对比结论

对照标准参考视频后，V162 还不能说“非常接近”。主要差距不是缺少更多形状，而是：

1. V162 仍然有明显的“光形家族模板插值”感；
2. V162 仍会在宽形态里用 ruled surface 填充面，容易变成预制形体或膜面；
3. V162 的可见窗口偏长，容易一次性呈现太多成熟形状，而不是参考视频里的短促、清楚、正在生成的光短句；
4. 参考视频的高级感来自黑底大留白、少量清晰轮廓、极淡同源时间切片，而不是大量填充、肋线或并行笔毛。

## V163 改造方向

V163 将主渲染路径切换为：

- `drawReferenceVideoTimePainterV163(...)`

并把 V162 的“家族模板形体”进一步改为“轮廓光弦状态机”：

- 单一主体；
- 短绘制窗口；
- 不再用填充面作为主体；
- 只画少量细轮廓线；
- 极淡同源历史切片；
- 头部继续变形，尾部退隐；
- 保留 CameraFOV 式透视呼吸和 3D 控制点投影。

## 关键新增方法

- `drawReferenceVideoTimePainterV163(...)`
- `drawV163ContourString(...)`
- `buildV163ProjectedCurve(...)`
- `v163ControlPoint(...)`
- `v163BrushTip(...)`
- `v163Head(...)`
- `v163Tail(...)`

## 解决的问题

V163 重点解决：

- V162 的模板感；
- 填充膜面导致的预制形体感；
- 可见窗口过长导致的“成品展示”感；
- 轮廓不够克制；
- 历史回声不够像参考视频中的淡时间切片。

## 修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`
