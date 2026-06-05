# 触摸 · Mystify 亲密艺术壁纸 V10 重写说明

本次不再继续修补固定曲线预览，而是把触摸页预览重写为接近 Mystify 的随机 Stroke 发生器。

## 重点修复

1. 删除原先预览中的“两条固定曲线对象”效果。
2. 预览改为随机 Stroke Event：每条线从全屏可见范围内随机出生、伸展、衰减、消失。
3. 支持多种出生形态：边缘切入、上下扫线、对角线、任意两点、角落切入、全屏任意局部短弧。
4. 每个事件都有独立生命周期，不再是事先画好然后整体移动。
5. 用多层延迟绘制模拟 Mystify 残影。
6. 保留阶段占比：分离最大，吸引和同步为主要部分，临界较少，释放和余韵最少。
7. 原生动态壁纸保留 OpenGL ES + FBO 残影渲染版本。

## 修改文件

- `lib/pages/touch_mystify_wallpaper_page.dart`
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

## 重要说明

这版重点修正你截图中看到的错误：触摸页面预览不应再显示两条固定曲线。
