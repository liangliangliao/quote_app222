# V65 Kinetic Flow Creature

本补丁针对反馈：“主体朝着屏幕随机运动和形体持续千变万化没体现出来”。

## 核心修复

1. **取消一次性 reveal 后停住的观感**
   - V64 的 `head` 主要依赖 episode 进度，episode 后段容易接近静止。
   - V65 改为 `rollingPhase` 持续循环推进，每 4～5 秒重新写入一次可见光弦窗口。

2. **增强屏幕空间随机游走**
   - 喉口/能量核不再只做小幅慢速呼吸。
   - 叠加多频平滑运动，X/Y 方向都有明显位移，并限制在屏幕安全区域内，避免跳出或压到边缘。

3. **增强形体持续重构**
   - `flowStringPoint()` 中控制点、远端展开、负空间、旋涡和微扰频率全面增强。
   - 曲线族每帧都在改变，不再像一张固定线网。

4. **持续作画感**
   - 可见窗口随书写相位滚动，旧线由 FBO 短湿迹保留后淡出。
   - 当前笔尖高光、喉口短骨、光弦网同步移动。

5. **释放和余韵阶段未改动**
   - 仅优化主体阶段。

## 修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

## 验证

已执行 Java 语法级编译检查。完整 Gradle 构建仍受源码包缺少 `android/gradle/wrapper/gradle-wrapper.jar` 限制。
