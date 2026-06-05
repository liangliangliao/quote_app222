# PATCH_TOUCH_MYSTIFY_V113_LARGER_HERO

本次继续针对“发现之旅 / 生理赋能 / 触摸”主体动画优化，重点响应：

- 用户反馈：**主体这么小，没适应手机屏幕**。

## 一、核心目标

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

V113 的目标是：
- 继续保留动态壁纸屏幕适配；
- 但进一步修复“适配后主体仍然太小”的问题；
- 让流动光雕在手机桌面上能更充分展开，而不是缩成中间一小团。

## 二、核心调整

### 1. 收回过于保守的桌面安全边距
重写：
- `wallpaperViewportProfile(...)`

调整方向：
- 左右安全边距从原先偏大的比例，改为更小；
- 顶部安全边距更小；
- 底部仍保留对桌面图标区的避让，但不再过度保守；
- 焦点区约束也进一步放宽；

结果：
- 主体可用舞台明显变大。

### 2. 明显放大主体尺度计算
重写：
- `continuousPenAdaptiveScale(...)`

调整方向：
- 提高 `base` 比例；
- 提高 `widthFit`；
- 提高 `heightFit`；
- 增大 `scale` 对 fit 的跟随程度；
- 提高 `minScale`；
- 提高 `maxScale`；

结果：
- 主体不再只在桌面上占很小一块区域，而会以更明显的尺寸显示。

### 3. 放宽主体落点的活动范围
重写：
- `continuousPenAnchor(...)`

调整方向：
- 明显减小 `marginX / marginY`；
- 放大 `focusSpanX / focusSpanY`；

结果：
- 主体不会被过度挤压在中心极小的活动区；
- 在手机屏幕上的视觉展开更自然。

### 4. 最终边界收口也略微放宽
在 `continuousPenPoint(...)` 中：
- 减小 `edgeInsetX / edgeInsetY`；

结果：
- 主体不会因为边界 clamp 过严而再次被压小。

### 5. 主体膜面宽度略增
在 `drawCoherentFlowCreation(...)` 中：
- 增大 `widthUpper`；
- 增大 `widthLower`；

结果：
- 即使同样是一个主体，也会显得更有展开感，不会过薄、过小。

### 6. 连续作画窗口略放宽
在 `drawContinuousPenDrawingSubject(...)` 中：
- 略微增加 `windowLen`；

结果：
- 当前正在生成的可见段更长一些，主体更容易在桌面上呈现出完整存在感。

## 三、同步文案
更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V113。
