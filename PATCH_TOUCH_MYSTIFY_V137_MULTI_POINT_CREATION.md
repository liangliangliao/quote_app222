# PATCH_TOUCH_MYSTIFY_V137_MULTI_POINT_CREATION

本次继续优化“发现之旅 / 生理赋能 / 触摸”动画主体。

## 一、问题判断

用户指出两个关键问题：

1. 当前效果仍然像一条蛇形主体在屏幕上乱串；
2. 绘画和变形似乎是分开的。

这说明 V136 虽然放慢了节奏，但“可见创作过程”的实现方式仍然不对：
它主要是从完整曲线的一端开始截取已绘制部分，所以视觉上仍然像“蛇头拖尾”。

## 二、本次核心改造

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 不再从曲线一端单向截取
旧逻辑：
- `sliceCurveForDrawingProgress(...)`
- 从曲线开头到当前 reveal 位置截取；
- 容易形成“蛇在爬”的观感。

V137 改为：
- `generativeCreationSegments(...)`
- 在同一条 Mystify 光弦上同时生成多个短笔触；
- 每个短笔触逐渐变长、扩张、相互汇合；
- 接近完成时才用一条淡整体光弦统一结构。

### 2. 绘画和变形合并为同一过程
新增的短笔触不是额外图形，而是从当前变形中的光弦本身截取出来。
因此：
- 变形决定短笔触的位置和方向；
- 短笔触的生长过程就是绘画过程；
- 绘画和变形不再分开。

### 3. 新增多种创作过程模式
新增：
- `generativePaintProcessMode(...)`

支持：
- 起笔式：由主笔触带出副笔触；
- 中心开花式：从曲线中段向两端扩张；
- 多点即兴式：多个位置同时被点亮；
- 全局扫描式：多段扫亮，而不是蛇头拖尾。

### 4. 新增分段绘制工具
新增：
- `subCurveByUnit(...)`
- `drawGenerativeMystifyCurrentSegments(...)`
- `drawGenerativeTrailSegments(...)`
- `drawGenerativeSegmentTips(...)`

这些方法共同负责：
- 多段绘制；
- 多笔尖亮核；
- 分段残影；
- 后期整体统一。

## 三、节奏调整

V137 进一步拉长短句周期与绘制进度：
- 短句时长从 V136 的 5.6~8 秒调整为约 6.2~9 秒；
- 绘制阶段从约 70% 拉长到约 82%；

目的是让“起笔—生长—发展—汇合—退隐”更清楚。

## 四、同步更新

已同步更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案升级为 V137。
