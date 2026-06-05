# PATCH V34 — Release Eruption Upgrade

目标：根据最新参考视频文字描述中“强光爆发、粗大黄色/金白光柱、红橙升温、碎光/星屑洪流、短暂满屏白化”的视觉语言，升级性交动画的「释放」阶段，但不复制视频中的女性角色、武器、道具、金币或任何具象元素。

## 改造重点

1. **释放阶段从圆形脉冲升级为抽象能量爆发**
   - 新增白金光心。
   - 新增暖金、橙红、玫红的短暂全屏辉光。
   - 新增粗大放射光束，中心近白、边缘金橙。
   - 新增热浪扇弧，表现能量向外推开空气的感觉。
   - 新增高速碎光粒子洪流，使用小光瓣、碎晶片、椭圆光滴和微白核，而不是金币、角色或物品。

2. **减少释放阶段的线条干扰**
   - 释放开始后，原先的抽象线条只保留早期承接，随后让白金爆发成为主视觉。
   - 避免释放阶段继续被细线、网格、奇怪线团主导。

3. **清洁退场**
   - 进入释放时重置释放特效种子并清理前段 FBO 残影。
   - 释放阶段的 FBO 反馈衰减调低，减少强光消失后留下灰黑痕迹。
   - 进入余韵阶段仍会清理释放残影，然后进入水晶气泡余韵。

4. **随机性与生命感**
   - 每次释放都会重新随机光束角度、长度、弯曲、碎光粒子出生时间、速度、大小和形态。
   - 整体表达为抽象亲密节律中的能量释放，不出现具象身体或露骨画面。

## 修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
  - 渲染线程名升级：`IntimacyMystifyGLRendererV34ReleaseEruption`
  - 新增 `releaseSeed`
  - 新增 `drawReleaseEruption(...)`
  - 新增 `drawReleaseParticleFlood(...)`
  - 释放阶段降低 FBO 残影保留，减少烙印痕迹

- `lib/pages/touch_mystify_wallpaper_page.dart`
  - Flutter 预览同步新增释放爆发效果
  - 样式文案改为“白金释放爆发 / 金橙生命洪流”

- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`
  - 更新入口文案

## 本地建议验证

```bash
flutter clean
flutter pub get
flutter analyze
flutter build apk --debug
```
