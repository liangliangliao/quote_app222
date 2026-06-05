# PATCH_TOUCH_MYSTIFY_V136_SLOW_VISIBLE_PROCESS

本次继续优化“发现之旅 / 生理赋能 / 触摸”动态壁纸动画。

## 一、用户反馈

当前问题不是单纯“形状不像”，而是：

- 看不清内容的初始生成；
- 看不清中间如何发展变化；
- 看不清最后如何消失；
- 整体节奏仍然过快，导致像成品一闪而过。

## 二、核心判断

参考 Windows7 Mystify screensaver 的公开行为描述，它的关键并不是复杂形状堆叠，而是：

- 弯曲光线持续改变形状；
- 颜色循环；
- 旧形态以同色、同形、短暂残影方式退隐；
- 慢时残影更密，快时残影更疏；
- CameraFOV、LineWidth、NumLines、Blur 共同影响远近、亮度、数量和残影。

因此，本版重点不是继续增加花样，而是让“创作过程”被眼睛捕捉到。

## 三、主要修改

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 明显拉长创作短句时长
`generativePhraseDuration(...)` 从约 1.8~3.25 秒提升为约 5.6~8 秒。

目的：
- 让起笔、发展、完成、退隐都有足够可见时间。

### 2. 拉长绘制阶段
`generativePhraseReveal(...)` 的绘制阶段从约 58% 延长到约 70%。

目的：
- 让用户能看到光弦被一段段画出来，而不是瞬间完成。

### 3. 调整生命周期
`generativePhraseLife(...)` 改为：
- 更快进入可见；
- 更长时间保持；
- 末尾再逐渐淡出。

目的：
- 不让内容还没看清就消失。

### 4. 历史残影跨越更长时间
`baseGap` 从几十毫秒提高到更长时间切片，并增加 trails 数量。

目的：
- 让残影展示更完整的时间绘画过程，而不是只显示当前附近几帧。

### 5. 增强过程残影可见性
提高旧切片 alpha，但保持快速衰减，避免重新堆成光雾。

### 6. 画笔尖持续更久
`drawGenerativeDrawingTip(...)` 的笔尖亮核延迟到后段才消失。

目的：
- 让观众明确看到“正在画到哪里”。

## 四、同步更新

更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本文案升级为 V136。
