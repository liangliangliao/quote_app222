# PATCH_TOUCH_MYSTIFY_VIDEO_MATCH_V33

本版针对主屏截图与参考气泡视频继续修正余韵阶段。

## 修正目标

1. 气泡不能像白边黑珠或普通小圆圈，要呈现透明、晶莹、薄膜折射感。
2. 余韵开始后应从释放中心快速向四周爆散，而不是停留在中心附近几个固定小泡。
3. 不再出现几个五颜六色的大圆盘，也不再保留旧版固定小残泡。
4. 动画元素消失后不能长期留下灰黑网状痕迹。
5. 整体视觉继续减少奇怪线条，更多使用有轮廓、有生命力的光膜、花瓣、晶片、泡泡等形体。

## Android 原生动态壁纸

文件：`android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

- 渲染线程名升级为 `IntimacyMystifyGLRendererV33CrystalBubbleClean`。
- 新增 `afterglowSeed`：每次进入余韵都生成新随机种子，气泡数量、方向、半径、漂移、高光和彩膜弧每轮不同。
- 进入余韵时执行：
  - `strokes.clear()`
  - `resetSpawnHeat()`
  - `clearFbos()`
  - 关闭余韵期间的新线条生成
- 余韵结束进入分离时再次清理 FBO，避免桌面出现旧线条残影。
- FBO 反馈衰减从 v32 的偏长尾改成更清洁的衰减：余韵阶段 `fade` 约 0.82 → 0.93，常规阶段也降低最高残留。
- shader 扣黑强度从 `0.00135` 提升到 `0.00235`，让微弱痕迹更快被黑场吞没。
- 新增 `drawSolidRect(...)`，用整屏极薄深蓝水域承托透明泡泡，避免黑底上气泡变成黑珠。
- 重写 `drawAfterglowBubbleAquarium(...)`：
  - 删除大圆盘背景；
  - 保留细的青绿斜向水光；
  - 30 个左右透明泡泡从释放中心快速 360° 爆散；
  - 后半段进入斜向上浮与慢漂。
- 重写 `drawIridescentBubble(...)`：
  - 极淡蓝色透明内部；
  - 双层白蓝薄膜轮廓；
  - 粉紫、青蓝、湖绿、淡黄的局部彩虹弧；
  - 白色椭圆高光与内侧薄高光；
  - 限制半径，避免恢复成大彩色圆盘。

## Flutter 预览

文件：`lib/pages/touch_mystify_wallpaper_page.dart`

- 视觉风格名改为“水晶气泡余韵”。
- 余韵阶段跳过旧线条绘制，只显示水域、斜向光束和水晶气泡。
- 预览气泡使用 `seed/currentIndex/i` 混合随机，确保每次启动/每轮余韵不同。
- 气泡绘制逻辑同步 Android：透明蓝色内部、双层薄膜边缘、局部彩虹弧和白色椭圆高光。

## UI 文案

- 发现之旅入口改为：深蓝水域、透明薄膜气泡、随机爆散与清洁退场。
- 生理赋能入口改为：透明薄膜、蓝色水域、无残影清洁退场。
