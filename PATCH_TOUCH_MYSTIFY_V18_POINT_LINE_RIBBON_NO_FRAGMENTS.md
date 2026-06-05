# V18 点线面光迹 + 消除短残片 + 慢淡出优化

## 解决的问题

1. 不再出现很短、残缺的点线形状
   - 真实壁纸和触摸页预览均加入最小可见长度过滤。
   - 光迹窗口扩大，短小残片直接不绘制，交给 FBO 残影自然退场。

2. 不再把 Mystify/Ribbons 理解成单根线
   - 新增多层 `fiber veil`：同一笔由多条细纤维、半透明光面、光尘、短微线和核心亮线组成。
   - 参考 Windows Mystify/Ribbons 中“点 + 线 + 面”的喷洒/飞掠结构。

3. 尾部淡出方式保持同步进行
   - 头部继续游走显现；尾部同步跟进并由 FBO 慢衰减缓缓消失。
   - 不再让整条笔触整体衰老，也避免短小残留片段停在屏幕上。

4. 默认关闭余韵气泡
   - 避免默认出现圆圈/残缺形状干扰 Mystify 主体效果。
   - 用户仍可在设置页手动开启余韵气泡。

## 修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
- `android/app/src/main/kotlin/com/example/quote_app/IntimacyWallpaperChannel.kt`
- `lib/pages/touch_mystify_wallpaper_page.dart`

## 技术要点

- 继续使用 OpenGL ES + ping-pong FBO 残影。
- 可见段使用滑动窗口，但窗口扩大并增加最短长度判断。
- 新增 `drawFiberVeil()` / `_drawFiberVeil()` 生成多纤维光幕。
- 降低孤立点和短微线强度，减少“残缺短线”观感。
