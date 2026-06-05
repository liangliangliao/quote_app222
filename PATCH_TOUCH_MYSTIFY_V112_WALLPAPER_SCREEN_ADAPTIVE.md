# PATCH_TOUCH_MYSTIFY_V112_WALLPAPER_SCREEN_ADAPTIVE

本次继续针对“发现之旅 / 生理赋能 / 触摸”主体动画优化，重点响应：

- 用户要求：继续 V112；
- 同时需要：**作为动态壁纸适应手机屏幕效果**。

## 一、核心目标

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

V112 的目标是：
- 延续 V111 的“流动光雕”方向；
- 进一步适配动态壁纸在手机桌面上的真实显示场景；
- 让主体在不同手机屏幕、不同桌面偏移、预览模式 / 正式壁纸模式下都更稳定。

## 二、核心调整

### 1. 新增壁纸偏移监听
在 `MystifyEngine` 中新增：
- `onOffsetsChanged(...)`

并把壁纸页面偏移传给渲染线程：
- `renderThread.setWallpaperOffsets(xOffset, yOffset)`

这样后续主体的焦点区域可以随桌面页面偏移做有限适配，而不是完全忽略真实壁纸环境。

### 2. 渲染线程新增壁纸偏移状态
在 `GLRenderThread` 中新增：
- `wallpaperXOffset`
- `wallpaperYOffset`
- `setWallpaperOffsets(...)`

用于保存当前桌面壁纸的偏移信息。

### 3. 新增 `wallpaperViewportProfile(...)`
新增方法：
- `wallpaperViewportProfile(float w, float h, float padX, float padTop, float padBottom)`

该方法综合考虑：
- 手机纵向长宽比
- 桌面底部图标 / Dock 区域
- 预览模式与正式壁纸模式差异
- 桌面页面偏移 `xOffset / yOffset`

最终给主体生成一组：
- `safeLeft / safeRight / safeTop / safeBottom`
- `focusX / focusY`

即“可视安全区 + 桌面焦点区”。

### 4. `drawContinuousPenDrawingSubject(...)` 改为围绕壁纸安全区生成
原来主体更多是围绕整张画布工作；
V112 改为：
- 先通过 `wallpaperViewportProfile(...)` 计算桌面可视安全区；
- 再把 `safeLeft / safeRight / safeTop / safeBottom / focusX / focusY` 传给主体点生成；

使主体更像是“为手机桌面构图”，而不是只是在画布中央随机生成。

### 5. `continuousPenAdaptiveScale(...)` 改为直接基于壁纸安全区计算大小
原来主体尺寸虽然已做屏幕适配，但更多依赖整个画布；
现在改成：
- 直接根据 `safeLeft / safeRight / safeTop / safeBottom` 计算 `usableW / usableH`；
- 主体大小基于动态壁纸真实可视区域，而不是整个绘制表面；

从而减少：
- 作为壁纸时主体过大被裁切；
- 主体过小显得不明显；
- 主体在不同桌面布局下比例不稳。

### 6. `continuousPenAnchor(...)` 改为围绕焦点区稳定落点
重写：
- `continuousPenAnchor(...)`

新逻辑会：
- 让主体落点围绕 `focusX / focusY` 分布；
- 结合安全区与主体尺寸留出额外 margin；
- 保留适度随机性，但不再过于靠边；

让主体更适合做桌面主体，而不是贴边生成。

### 7. `continuousPenPoint(...)` 改为使用壁纸安全区与焦点区
重写了参数传递：
- 不再传 `padX / padTop / padBottom`；
- 改为传 `safeLeft / safeRight / safeTop / safeBottom / focusX / focusY`；
- 最终 clamp 也直接围绕壁纸安全区进行。

这样主体每个点的生成和边界约束都直接服从动态壁纸桌面视图逻辑。

## 三、同步文案
更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V112。
