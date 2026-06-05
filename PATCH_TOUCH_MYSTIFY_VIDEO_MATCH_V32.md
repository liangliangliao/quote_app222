# PATCH_TOUCH_MYSTIFY_VIDEO_MATCH_V32

本版根据主屏截图反馈继续修正余韵阶段：V31 的大面积蓝色/暖色圆盘会在动态壁纸上变成几个抢眼的大圆；释放中心旧版小气泡也会残留。V32 将余韵改成“气泡爆散 + 透明彩膜边缘 + 白色高光”的主视觉。

## 关键修正

1. 删除余韵阶段大面积圆盘背景
   - Android 原生动态壁纸删除 `drawAfterglowBubbleAquarium(...)` 中的大蓝圆、大暖色圆和左下大蓝圆。
   - Flutter 预览余韵阶段不再绘制大色块 soft field。
   - 背景只保留极薄、低透明度、窄宽度的斜向水光，避免形成截图中的巨大彩色圆或巨大白色斜面。

2. 删除旧版小气泡
   - 移除 `drawReleasePulse(...)` 中 afterglow 阶段围绕释放中心慢转的 3 个小 ring。
   - 这些正是截图 2 圈出的残留小泡来源。

3. 气泡从释放中心迅速向四周散开
   - `born` 压缩到 0.18，气泡几乎同时出现。
   - 使用 radial burst：先从 pulse center 朝 360° 快速爆散，再叠加轻微上浮/斜漂。
   - 数量提升到 38 个（省电模式 20 个），但半径严格控制，避免变成占屏大圆。

4. 气泡更像视频里的透明肥皂泡
   - 内部填充极淡，仅保留玻璃感。
   - 强化彩色薄膜边缘：粉紫、青蓝、湖绿、淡黄、蓝紫分段 arc。
   - 强化白色椭圆高光。
   - 以边缘和高光为主体，不再用实心圆面占视觉。

5. 清除余韵阶段旧残影
   - 余韵前段降低 FBO feedback fade，快速洗掉释放阶段的大光片/大色块。
   - `drawStroke(...)` 在余韵气泡阶段进一步压低旧光迹 alpha，让气泡成为主角。

## 修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
- `lib/pages/touch_mystify_wallpaper_page.dart`
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

## 本版目标

在动态壁纸实际主屏上避免出现：

- 几个大面积五颜六色圆盘
- 旧版残留小气泡
- 大白色斜面抢占画面
- 余韵阶段仍被前段雕塑光体/点线残影主导

让余韵更接近参考视频：

- 透明小中型气泡群
- 彩色薄膜圆边
- 白色椭圆高光
- 从中心向四周快速散开
- 后续轻柔慢漂
