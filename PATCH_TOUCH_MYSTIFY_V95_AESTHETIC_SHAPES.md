# PATCH_TOUCH_MYSTIFY_V95_AESTHETIC_SHAPES

本次继续针对“发现之旅 / 生理赋能 / 触摸”主体动画优化，重点响应：

- 不要再画出截图里那种肥厚、单块、缺乏美感的大色带形状；
- 画笔不要只局限于单一线条；
- 需要像参考视频那样画出千变万化、纤细优雅、具有艺术美感的各种光形。

## 本次核心处理

### 1. 压掉“厚重色带感”
文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

本次显著降低了：
- 主膜面 `drawRuledSurface(...)` 的透明度；
- 主笔迹的宽度和亮度；
- 主体开放宽度 `continuousPenOpenAmount(...)`；
- 独立 glyph 的整体尺寸。

目的就是避免再出现截图里那种像“粗厚月牙 / 大块弯条”的笨重形状。

### 2. 精选更美观的母题池
调整 `continuousPenMotifRaw(...)`：
- 移除更容易长成厚重大卷、大色带感的母题；
- 精选并强化更接近参考视频的母题：
  - 扇翼
  - 花瓣 / 新月瓣
  - 开放环 / 环扣 / 羽眼
  - 光幕
  - 丝带 / 书法钩
  - 晶体切面

### 3. 让光形更纤细、轻盈、优雅
调整：
- `continuousPenHasMembrane(...)`
- `continuousPenOpenAmount(...)`
- `continuousPenPoint(...)`
- `drawVideoReferenceRandomGlyph(...)`
- `drawVideoSoftBreathingAura(...)`

使每次生成的主体形状更小、更灵动、更有留白，而不再是一大片厚重填充。

### 4. 弱化结构框架，强化艺术光形主体
- 降低基础结构层和脊线的权重；
- 提高 `drawLivingSilkFeatherVeils(...)` 的比重；
- 提高 `drawVideoReferenceRandomGlyph(...)` 的比重；

这样观感更偏“艺术形体”而不是“程序性骨架 + 一条大色带”。

## 同步文案
更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V95。
