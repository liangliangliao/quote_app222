# PATCH_TOUCH_MYSTIFY_V114_MASSIVE_HERO_SCALE

本次继续针对“发现之旅 / 生理赋能 / 触摸”主体动画优化，重点响应：

- 用户要求：继续 V114；
- 并且需要：**大幅度放大主体**。

## 一、核心目标

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

V114 的目标是：
- 不再只是“主体稍微变大”；
- 而是显著提高主体在手机桌面中的占比；
- 让流动光雕更接近“桌面主角”的构图。

## 二、核心调整

### 1. 进一步压缩桌面安全边距
重写：
- `wallpaperViewportProfile(...)`

调整方向：
- 左右安全边距进一步缩小；
- 顶部安全边距进一步缩小；
- 底部仍保留对桌面图标区的避让，但明显不再保守；
- 焦点区可用范围继续扩大；

结果：
- 给主体让出更大的手机桌面舞台。

### 2. 大幅提高主体尺度计算
重写：
- `continuousPenAdaptiveScale(...)`

调整方向：
- 明显提高 `base`；
- 明显提高 `widthFit`；
- 明显提高 `heightFit`；
- 进一步提高 `scale` 对 fit 的跟随程度；
- 提高 `minScale`；
- 提高 `maxScale`；

结果：
- 主体在手机桌面上会以明显更大的比例展开。

### 3. 显著放宽主体活动范围
重写：
- `continuousPenAnchor(...)`

调整方向：
- 继续减小 `marginX / marginY`；
- 继续放大 `focusSpanX / focusSpanY`；

结果：
- 主体不会再被过度束缚在中间一小块区域，而会更充分占据桌面舞台。

### 4. 最终边界 clamp 继续放宽
在 `continuousPenPoint(...)` 中：
- 继续缩小 `edgeInsetX / edgeInsetY`；

结果：
- 主体不会因为最终边界收口太严而再次被压缩。

### 5. 主体膜面宽度继续增大
在 `drawCoherentFlowCreation(...)` 中：
- 进一步增大 `widthUpper`；
- 进一步增大 `widthLower`；
- 提高表面层与边缘层的可见强度；

结果：
- 即便主体轨迹不变，视觉体量也会明显更大、更有存在感。

### 6. 当前可见创作段继续拉长
在 `drawContinuousPenDrawingSubject(...)` 中：
- 继续增大 `windowLen`；
- 提高 `sampleCount`；
- 略增最终渲染 alpha 系数；

结果：
- 主体在桌面上的可见长度更长，存在感更强。

## 三、同步文案
更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V114。
