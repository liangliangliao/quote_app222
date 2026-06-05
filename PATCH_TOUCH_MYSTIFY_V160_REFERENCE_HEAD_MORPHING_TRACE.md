# PATCH_TOUCH_MYSTIFY_V160_REFERENCE_HEAD_MORPHING_TRACE

本次继续主动对比标准参考视频，对 V159 做进一步修正。

## 主要差距

V159 虽然比之前更清楚，但它仍然偏向“一个短句选择一个固定光形家族，然后让它成熟”。
参考视频更像：

- 旧部分保持刚才画出的笔法并逐渐退隐；
- 头部继续向前创造，并开始试探下一种形态；
- 同一主体内部发生连续的头部变形，而不是整段一起替换形状。

## V160 改造重点

### 1. 新增 V160 主入口

- `drawReferenceVideoTimePainterV160(...)`

当前主渲染路径已经从 V159 切换到 V160。

### 2. 头部连续变形，而不是整段切换

新增：

- `v160FamilyA(...)`
- `v160FamilyB(...)`
- `v160HeadFamilyBlend(...)`
- `v160Point(...)`

同一段主体先由 familyA 生成，后续头部逐渐进入 familyB；尾部仍保持旧形态并退隐。

### 3. 保持参考视频式克制

- 单一主体；
- 单一中心；
- 极淡同源回声；
- 克制白芯；
- 只在叶片/环网类主体中生成极少量内部纹理。

### 4. 降低“固定 motif 展示感”

V160 不再只是“一段=一个 motif”，而是“一段=一个光形短句，其头部可以继续成熟为下一种形态”。

## 修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`
