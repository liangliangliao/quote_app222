# PATCH_TOUCH_MYSTIFY_V139_CONTINUOUS_GROWTH_PHRASE

本次继续优化“发现之旅 / 生理赋能 / 触摸”动画主体，重点响应：

- 用户反馈仍然看到“先绘制，然后分身变化”；
- 屏幕上会先出现一个网状，再复制出一个或多个几乎一样的网状；
- 仍然看不到“缓缓、渐进、丝滑、流畅、连贯”的创作过程。

## 一、问题判断

V138 的“多窗口同步显影”虽然避免了单端蛇形截取，但多个窗口在同一时间显影，视觉上仍可能被看成：

- 一个形状被复制；
- 一个网状分裂出多个副本；
- 绘画与变形仍然是两个阶段。

因此 V139 不再继续增加窗口数量，而是反向收敛：

> 一个短句只允许一个核心创作区域，从一个种子点缓慢向两端生长。

这样更接近“先画头，再画身体，再画尾部”的连贯理解方式。

## 二、核心改造

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 禁用多副本光弦
将当前生成模式收敛为：
- `int strings = 1;`

目的：
- 避免屏幕上同时出现多个相似主体；
- 避免用户看到“复制 / 分身”的错觉。

### 2. 删除独立附加 ribbon / rib / accent 的视觉叠加
在 `drawGenerativeMystifyCurrent(...)` 中取消对 `drawGenerativeAttachedRibbon(...)` 的调用。

目的：
- 避免“先出现一条线，然后旁边又跟出一个形状”；
- 让当前显示内容只来自同一条正在生长的光弦。

### 3. 重写 `generativeCreationSegments(...)`
V139 不再返回多个显影窗口。

新逻辑是：
- 先根据 phrase hash 选择一个种子点；
- 初始阶段只显示一小段；
- 发展阶段向左、向右扩张；
- 尾段继续延展但同时开始淡出；
- 始终只返回一个连续 segment。

这比多窗口同步显影更适合表现“初始—发展—变形—消失”的连续创作过程。

### 4. 放慢短句节奏
调整：
- `generativePhraseDuration(...)`
- `generativePhraseMorphMix(...)`
- `generativePhraseReveal(...)`
- `generativePhraseLife(...)`

目标：
- 让观众有足够时间看清每段短句如何开始、发展、变化、退隐；
- 避免刚出现就完成、刚完成就分裂或消失。

### 5. 双端提示而非蛇头提示
更新：
- `drawGenerativeSegmentTips(...)`
- 新增 `drawGenerativeDrawingSeed(...)`

当前创作段有“种子端”和“发展端”的微弱提示，避免只看见一个蛇头在跑。

## 三、本版目标

V139 的目标不是让画面更复杂，而是让过程更可理解：

1. 不再复制多个网状主体；
2. 不再多处同时分身；
3. 不再先线条后形状；
4. 一个短句从种子点开始，缓慢扩张成一个主体；
5. 主体在生长过程中持续变形，最后以残影方式退隐。

## 四、同步更新

已同步更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本文案升级为 V139。
