# PATCH_TOUCH_MYSTIFY_VIDEO_MATCH_V28_ART_DIRECTOR

本补丁针对用户反馈“运动的点或线组成整体形状几乎雷同、创意不够丰富、艺术感不足、局部散乱”进行二次升级。

## 重新观察视频后的视觉拆解

视频不是单一曲线反复漂移，而是多种形态家族交替出现：

- 花瓣钩弧：黄绿竖向细茎上卷出粉紫/橙色小花瓣。
- 叶片藤蔓：绿黄色半透明薄叶从黑场中斜向伸出，边缘有亮白细线。
- 电子纱扇：粉紫、蓝紫、蓝绿弧线从隐形焦点展开，形成贝壳/折扇般平行肋纹。
- 银白折刃：极细白色核心线带出半透明三角薄面，像金属纸片或月光刀锋。
- 菱形框片：短暂出现的倾斜几何框架，边缘由霓虹点线组成。
- 长弓光桥：横跨黑场的洋红/蓝绿大弧线，上方或侧边有一条淡淡幽灵平行线。
- 点线喷洒：不是随机雪花，而是贴着主笔触头部与边缘分布的微点、短线、碎屑。

## V28 核心改造

### 1. 增加 Art Director 形态调度器

Android 原生动态壁纸新增 `chooseArtMotif(...)` 与 `motifControlCount(...)`，不再让所有 StrokeEvent 由同一种全屏曲线生成。

母型包括：

1. comet arc / 稀疏长弧
2. veil ribbon / 半透明丝带
3. electronic fan / 电子纱扇
4. silver blade / 银白折刃
5. petal hook / 花瓣钩弧
6. prism polygon / 菱形框片
7. falling leaf / 叶片藤蔓
8. long bridge / 长弓光桥

不同阶段使用不同概率：

- 分离：稀疏长弧、叶片、薄刃、长桥，保持黑场留白。
- 吸引：花瓣、藤蔓、棱镜框、轻丝带。
- 同步：电子纱扇、花瓣、菱形框片、两主体差异化轨迹。
- 临界：扇面、折刃、菱形框片集中出现。
- 释放：银白折刃、电子扇面、长弓桥短促出现。
- 余韵：叶片、长弧、薄刃低亮度退场。

### 2. Android OpenGL 渲染升级

文件：`android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

- 渲染线程名升级为 `IntimacyMystifyGLRendererV28ArtDirector`。
- `StrokeEvent` 新增 `motif` 与 `motifStrength`。
- 新增 `initStrokeByArtMotif(...)`，每类母型用不同控制点生成逻辑：
  - 扇面用隐藏 pivot + sweep angle + radius growth。
  - 花瓣用 stem + quadratic curl。
  - 折刃用 diagonal line + crease normal。
  - 菱形框用 rotated diamond/corners。
  - 叶片用 S-curve + sinusoidal leaf body。
  - 长桥用 corner-to-opposite long bow。
- 新增 `drawArtMotifAccent(...)`：
  - 折刃增加白色切边与淡三角面。
  - 花瓣/藤蔓增加侧向卷边。
  - 菱形框增加偏移复写，形成透明几何纸片。
  - 长弓增加幽灵平行线。
  - 扇面增加焦点微光，使结构更有意图。

### 3. Flutter 设置页预览同步升级

文件：`lib/pages/touch_mystify_wallpaper_page.dart`

- 默认参数调整为更接近视频：
  - randomness: 0.72
  - trail: 0.88
  - strokeDensity: 0.32
- 预览母型从 6 类扩展到 10 类。
- 新增 `_controlCountForMode(...)`。
- `_basePointForMode(...)` 增加花瓣钩弧、扇形贝壳、银白折刃、菱形框片等几何生成方式。
- 新增 `_drawArtMotifAccents(...)`，让预览不仅是线条，还能看到花瓣、折刃、框片、长桥、扇面焦点等结构。

### 4. UI 文案同步

- 「发现之旅」提示升级为：Windows Mystify 式艺术导演光迹壁纸。
- 「生理赋能 / 触摸」副标题升级为：扇面、花瓣、折刃、残影。
- 视觉风格第一项改为「艺术导演自动轮换」。

## 设计原则

- 不追求烟花式多而乱，而是“少量母型 + 强烈黑场 + 有起势的笔触”。
- 形态丰富但仍遵守视频气质：暗、慢、克制、拖尾、荧光、留白。
- 点线喷洒必须依附主笔触，不能变成随机噪点。
- 扇面/折刃/花瓣/框片只在合适阶段高频出现，避免屏幕持续堆满。

