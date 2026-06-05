# PATCH_TOUCH_MYSTIFY_V122_MYSTIFY_CONTROL_POINTS

本次继续针对“发现之旅 / 生理赋能 / 触摸”动画主体优化，重点响应：

- 深度分析 Windows Mystify 类屏保的实现技术方案；
- 在当前源码上继续完善和优化画笔生成方式；
- 进一步避免“贪吃蛇 / 蛇头拖尾 / 一条线拖着形状”的观感。

## 一、技术分析结论

Windows Mystify 的关键并不是“画一条蛇”。
它更像：

1. 多个控制点各自运动；
2. 控制点反射/弹跳；
3. 一组控制点形成一条曲线或多边形光弦；
4. 不同时刻的历史曲线形成残影；
5. 残影颜色与透明度随时间衰减；
6. 速度和距离感有轻微不均匀变化。

所以如果只做一个头部沿轨迹前进，再拖出一条尾巴，就很容易变成“贪吃蛇”。
真正应该模拟的是：

- 整条光弦在变形；
- 不是一个点拖着一条线；
- 每个控制点都参与创造当前形状。

## 二、本次核心改造

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 重写 `drawScreensaverArtistBrush(...)`
V122 不再把历史残影理解为“当前线条的尾巴”。

改成：
- 当前时刻是一条完整光弦；
- 过去若干时刻也是同一组控制点生成的光弦；
- 多条时间切片共同形成残影、丝带与光场。

### 2. 重写 `buildScreensaverControlCurve(...)`
这是本次最核心的技术变化。

原先控制曲线仍较依赖 sourceStroke 的形状，容易保留“蛇形主线”的感觉。

V122 改为：
- 以 sourceStroke 只提供中心与方向；
- 真正曲线形态由 7 个独立运动控制点决定；
- 每个控制点都有自己的速度、相位、局部反射运动；
- 再用 Catmull-Rom 曲线串联为柔和光弦。

### 3. 新增 `mystifyBounce(...)`
用于模拟类似屏保控制点的反射/弹跳运动。

它不是简单正弦摆动，而是三角反射波：
- 到边界后折返；
- 不产生突然断裂；
- 适合模拟 Windows Mystify 风格的控制点运动。

### 4. 新增 sourceStroke 中心与方向提取
新增：
- `mystifySourceCenter(...)`
- `mystifySourceAxis(...)`

sourceStroke 现在不再直接充当最终绘制形状，而只用于：
- 确定当前创作舞台中心；
- 确定大致方向轴；

这样可以减少“原来的蛇形主线直接进入最终画面”的问题。

### 5. 新增 `mystifyPaletteFromHue(...)`
用于让残影颜色轻微循环变化，更接近 Mystify 类屏保中颜色流动的特征。

### 6. 残影逻辑升级
V122 的残影具有：
- 更丰富的 trail 数量；
- 更自然的间距变化；
- 根据速度感调整的 trailGap；
- 远近感 proximity；
- 多 lane 的曲线偏移；
- 主体与残影不同亮度层次。

## 三、预期效果

V122 相比 V121，目标是：

1. 减少贪吃蛇感；
2. 减少“头部拖尾”感；
3. 增强整条光弦同时变形的感觉；
4. 更接近 Windows Mystify 的控制点曲线与残影机制；
5. 保持手机动态壁纸的大主体和屏幕适配逻辑。

## 四、同步更新页面文案

已同步更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本文案升级为 V122。
