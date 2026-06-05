# V17：头部游走显现 + 尾部同步缓缓消失

本版只处理用户指出的核心视觉问题：Windows Mystify 不是整条线出现后再整体衰亡，而是点线面组成的光迹一边向前游走显现，一边尾部同步缓慢淡出。

## Android 原生动态壁纸

修改文件：

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

主要改动：

1. `drawStroke()` 重写为多层时间切片渲染：
   - 同一条 Stroke 不再只画当前一段；
   - 根据 `progress - layer * step` 绘制多个历史可见窗口；
   - 越靠近当前头部越亮，越靠尾部越淡；
   - 旧尾迹继续交给 OpenGL FBO 衰减。

2. 新增 `drawStrokeLayer()`：
   - 每个时间切片都由“面、线、点、短线、核心亮线”组成；
   - 点线喷洒只在较新的层出现，避免杂乱；
   - 旧层只保留淡淡面和线，模拟 Windows 屏保中的慢退场背影。

3. 新增 `visibleSegmentAt()`：
   - 允许按任意历史进度取得移动窗口；
   - head 继续写出，tail 同步跟进；
   - 不再画完整曲线再整体消失。

4. FBO 残影参数调整：
   - 提高最低 fade，从而让尾部缓慢、淡淡退场；
   - 释放和余韵阶段保留更长背影。

## Flutter 触摸页预览

修改文件：

- `lib/pages/touch_mystify_wallpaper_page.dart`

主要改动：

1. 预览层增加更多历史时间切片。
2. 每个 Stroke 同时绘制多个过去窗口，形成头部显现、尾部同步消失。
3. 减小单个可见窗口长度，减少“整条虫子”感。
4. 预览提示文案改为“头部显现，尾部同步慢淡出”。

