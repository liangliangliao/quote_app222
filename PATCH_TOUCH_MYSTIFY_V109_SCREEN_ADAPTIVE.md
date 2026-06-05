# PATCH_TOUCH_MYSTIFY_V109_SCREEN_ADAPTIVE

本次继续针对“发现之旅 / 生理赋能 / 触摸”主体动画优化，重点响应：

- 用户反馈：**主体显示需要适应手机屏幕大小**。

## 一、核心目标

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

V109 的目标是：
- 让主体在不同手机屏幕上都能以更合适的尺度显示；
- 兼顾纵向长屏、不同分辨率、不同可用可视区域；
- 尽量减少主体过大被裁切、过小不清晰、落点过偏导致主体不完整的问题。

## 二、具体调整

### 1. 新增 `continuousPenAdaptiveScale(...)`
新增方法：
- `continuousPenAdaptiveScale(int gesture, int motif, float w, float h, float padX, float padTop, float padBottom, float minDim)`

这个方法不再只用 `minDim * 固定比例` 决定主体大小，而是同时参考：
- 可用宽度 `usableW`
- 可用高度 `usableH`
- 手机纵横比 `aspect`
- 纵向长屏偏置 `portraitBias`
- 当前 motif 的轻微尺寸偏置

这样主体会在不同手机屏幕上更接近“看起来合适”的大小。

### 2. 改造 `continuousPenAnchor(...)`
原来的落点只考虑普通安全区；
现在改为：
- 接收 `scale` 与 `angle`；
- 根据主体当前尺寸和朝向，动态计算左右/上下安全边距；
- 主体越大，落点就越向安全区域内收；

从而减少主体因为过靠边而被裁切。

### 3. `continuousPenPoint(...)` 改为使用自适应尺寸与落点
在 `continuousPenPoint(...)` 中：
- 先计算 `angle`
- 再调用 `continuousPenAdaptiveScale(...)`
- 再调用新的 `continuousPenAnchor(...)`

不再直接使用固定的：
- `minDim * (0.130f + 0.090f * stableHash...)`

### 4. 最终边界 clamp 也改为随长屏自适应
原来最终边界裁切比较固定；
现在新增：
- `aspect`
- `portraitBias`
- `edgeInsetX`
- `edgeInsetTop`
- `edgeInsetBottom`

使得：
- 在更长的竖屏手机上，主体不会过贴边；
- 保留更合理的上下/左右安全可视边界。

## 三、同步文案
更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V109。
