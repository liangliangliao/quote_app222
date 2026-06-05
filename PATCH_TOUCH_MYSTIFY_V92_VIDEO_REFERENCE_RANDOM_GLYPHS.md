# PATCH_TOUCH_MYSTIFY_V92_VIDEO_REFERENCE_RANDOM_GLYPHS

本次在 V91 的基础上继续推进“触摸 / Mystify 亲密艺术壁纸”的主体动画，使其更接近参考视频：每次出现的不是一条主线，而是一个独立的随机艺术光形。

## 用户反馈目标

- 继续减少“画线条”的感觉；
- 每次应直接生成随机艺术形体；
- 参考视频中常见的是扇翼、花瓣、弧钩、光幕、环扣、折面、丝带，而不是连续线条；
- 作画之间需要自然停顿。

## 主要修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

## 核心升级

### 1. 新增独立随机光形层
新增方法：

- `drawVideoReferenceRandomGlyph(...)`
- `drawVideoFanGlyph(...)`
- `drawVideoPetalGlyph(...)`
- `drawVideoLoopGlyph(...)`
- `drawVideoCrystalGlyph(...)`
- `drawVideoAuroraGlyph(...)`
- `drawVideoRibbonGlyph(...)`
- `localArtPoint(...)`

这些方法不再只是沿着一条路径加粗，而是在落笔位置直接生成一个局部坐标系下的完整光形。

### 2. 更接近参考视频的形状类型
V92 新增/强化以下形体：

- 扇翼 / 折扇：外弧、薄膜、肋纹从根部展开；
- 花瓣 / 新月瓣：上下轮廓夹出半透明瓣面；
- 开放环 / 回旋结：开放式环扣，末端有光点；
- 晶体切面：半透明多边形折面和内部射线；
- 极光幕：多条平行幕线逐层展开；
- 丝带 / 书法钩：宽窄变化的透明带面。

### 3. 进一步弱化主线存在感
V92 降低了主脊线的亮度、宽度和透明度，让主线只作为“落笔痕迹”，而不是视觉主体。视觉主体改由独立光形层、膜面、边缘高光和肋纹承担。

### 4. 保留 V91 的随机母题与自然停顿
继续保留：

- 取消固定长线起笔；
- 形体 family 去重，避免连续出现太相近的形状；
- 作画 → 停顿 → 下一形体；
- 秒级显形，避免刚安装后长时间黑屏。

