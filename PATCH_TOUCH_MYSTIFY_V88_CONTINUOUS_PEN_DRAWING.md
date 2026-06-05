# PATCH_TOUCH_MYSTIFY_V88_CONTINUOUS_PEN_DRAWING

目标：完善“发现之旅 / 生理赋能 / 触摸”的主体动画过程，使其更像一支光笔在黑场中持续作画。

## 修改点

1. 主体阶段改为单支光笔连续作画
   - 不再每帧反复重绘一个已经完整存在的主体。
   - 当前帧只绘制笔尖附近的新鲜轨迹。
   - 旧轨迹交给 OpenGL FBO 残影自然衰减，形成“画出 → 留痕 → 渐隐”的过程。

2. 起笔先画出长线
   - 每组手势第一笔强制为长线起势，视觉上更像“笔在纸上画出一条长线”。
   - 长线之后继续接上更多形体，而不是停在点、短线或固定形态。

3. 后续持续接连画出多种艺术形体
   - 新增连续手势库：大 S 弧、折线、花瓣/叶片外缘、半环、折扇弧、螺旋开放线、菱形切面、水母伞缘、开放环扣、丝带大摆、不规则软光形。
   - 每段手势的终点衔接下一段起点，避免主体突然跳变。

4. 痕迹渐渐消失
   - 主体阶段 FBO 衰减从短湿迹改为更适合“作画留痕”的慢衰减。
   - 已画部分不被重复补满，只通过残影保留，因此会自然变淡。

5. 保持手机全屏适配
   - 光笔落点、终点、运动路径继续使用真实 Surface 宽高和 `fullScreenCoverage` 安全区。
   - 适配竖屏手机，避免主体只停在中心或被裁切。

## 主要文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`
- `lib/pages/touch_mystify_wallpaper_page.dart`
