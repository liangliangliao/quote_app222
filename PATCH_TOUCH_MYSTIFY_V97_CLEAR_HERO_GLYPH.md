# PATCH_TOUCH_MYSTIFY_V97_CLEAR_HERO_GLYPH

本次针对用户截图反馈继续修复“触摸 / Mystify 亲密艺术壁纸”主体动画：

- V96 出现的问题：形体过小、碎片过多，像一堆杂乱无章的小光片，看不清楚是什么；
- V97 的目标：每次只生成一个更大、更清楚、更完整的主艺术光形，避免小碎片堆叠。

## 主要修改

### 1. 关闭微型伴生光形

关闭 `drawAestheticMicroAccents(...)` 的调用。

原因：
- 微型伴生光形会让主体周围出现 2 到 4 个小碎片；
- 在手机桌面实际尺寸下，这些小碎片会变成一团杂乱光点；
- 用户截图中“看不清楚是什么”的问题主要来自这种堆叠。

### 2. 关闭多层羽线叠加

主体阶段不再叠加 `drawLivingSilkFeatherVeils(...)`。

原因：
- 多层羽线在预览中有细节，但在桌面壁纸实际观看距离下容易变成杂乱纹理；
- V97 改为只保留清晰的主艺术光形。

### 3. 放大主光形

提高 `drawVideoReferenceRandomGlyph(...)` 的主形体 scale：

- 从较小的精致光形，调整为更清楚的主形体尺寸；
- 保持细线、低填充，避免回到 V94/V95 中的大块厚重色带问题。

### 4. 继续避免底部桌面指示点区域

`continuousPenAnchor(...)` 继续保留底部安全区，避免形体贴着桌面分页点和导航栏出现。

### 5. 保留高美感母题白名单

继续只保留更适合参考视频风格的母题：

- 扇翼
- 花瓣 / 新月瓣
- 环扣 / 羽眼
- 晶体细片
- 光幕
- 丝带 / 书法钩

## 修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`
