# PATCH_TOUCH_MYSTIFY_V145_LIVE_BRUSH_SWITCHING

本次继续优化“发现之旅 / 生理赋能 / 触摸”动画主体。

## 一、为什么前面问题没解决

V144 主要修复的是：

- 主体突然直接呈现一条静态线；
- 起笔阶段没有从 0 开始；
- 随机相位导致短句直接落在中段。

但 V144 为了避免“复制 / 分身 / 直接出现”，把历史切片收缩得太狠，并且仍然存在两个问题：

1. 同一段创作内部换笔法不够明显；
2. 旧笔痕主要依赖 FBO 自然淡出，节奏不够可控。

因此用户会继续看到：

- 画笔一直沿固定形状画下去；
- 不会实时从线条切换成扇形、网状、丝带、花瓣；
- 先画内容没有明显按合适节奏逐渐淡去。

## 二、本次参考方向

公开资料能确认 Windows Mystify 的核心是：

- 一条或多条弯曲光线在黑底上移动；
- 光线持续改变形状并循环颜色；
- 残影继承当时的颜色和形状，并在短时间内淡去；
- 慢时残影更密，快时残影间距更大。

XScreenSaver / rss-glx / Really Slick Screensavers 这类开源屏保集合也提供了一个重要思路：

- 不要把动画做成“主体漂移”；
- 而要让绘制器每一帧都在生成、改变、衰减；
- 屏幕上的内容是过程，而不是静态成品。

## 三、V145 核心改造

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 重新启用少量过程切片
把 V144 的：

```java
int trails = 1;
```

改为：

```java
int trails = cfg.powerSave ? 3 : 5;
```

但注意：旧切片不再重画完整主体，而是只画窄而淡的时间切片。
目标是让先画内容边画边淡去，而不是重新出现多个相同分身。

### 2. 旧笔痕透明度改为节奏化衰减
旧笔痕现在根据：

- remain
- processBand
- generativePhrasePulse

共同控制透明度。

这样它不是等整段画完后一起消失，而是边创作边衰减。

### 3. 同一短句内笔法阶段从 5 段扩展到 7 段
改造：
- `generativeBrushShapeStyleLive(...)`
- `generativeBrushStyleFromOrder(...)`
- `generativeBrushStyleChangePulse(...)`

新的 7 段序列会在同一短句中更明显经历：

- 线条
- 扇形
- 网状
- 丝带
- 花瓣
- 再次网状 / 扇形 / 丝带回扫

### 4. 局部位置也参与换笔法
在 `drawGenerativeGrowingForm(...)` 中，局部样式不再只是：

```java
phase + u * 0.13f
```

而是改为更明显的局部变化：

```java
fract(phase + u * 0.38f)
```

并给 gesture/time 加入局部扰动。

这样同一条正在绘制的曲线，不同位置也可能表现为不同笔法。

### 5. 明显拉开不同形态的差异
本次增强了：

- 细线阶段的收束感；
- 扇形阶段的铺开感；
- 网纱阶段的宽度和肋线感；
- 丝带阶段的飘起感；
- 花瓣阶段的中段张力。

让它不再只是“同一个形状的轻微变宽”。

## 四、同步更新

更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V145。
