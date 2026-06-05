# PATCH_TOUCH_MYSTIFY_V144_NO_DIRECT_STATIC_LINE

本次继续优化“发现之旅 / 生理赋能 / 触摸”动画主体。

## 一、用户反馈

用户指出：

- 源码中仍然存在直接呈现主体而没有任何创作过程的问题；
- 例如屏幕中突然直接出现一条线；
- 这条线一动不动等待几秒；
- 随后又消失；
- 这不是屏保式“现场绘制”，而是成品直接摆出来。

## 二、真实原因

排查后，核心原因不是单纯线宽或速度问题，而是生成短句的时间相位逻辑存在问题：

```java
return fract(time / generativePhraseDuration(gesture) + stableHash01(gesture, 14021) * 0.73f);
```

旧逻辑给每个短句的 phase 加了随机 offset，并且使用全局时间 `drawSec` 直接驱动。

这会导致：

- 新一轮创作刚开始时，短句 phase 可能已经在 0.3、0.5、0.7 等中段；
- 于是屏幕上会直接出现一段已经存在的线或形体；
- 用户看不到它从无到有的起笔过程；
- 再加上历史切片主动重画，就更容易出现“突然出现、静止等待、然后消失”的错觉。

## 三、本次修复

文件：

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 当前手势 raw 进度映射到短句局部时间
旧逻辑：

```java
time = drawSec - k * localGap;
```

新逻辑：

```java
float phraseDuration = generativePhraseDuration(sg);
float localCreativeTime = clamp(raw, 0f, 0.999f) * phraseDuration;
float time = localCreativeTime - k * localGap - s * 0.10f;
```

这样每次手势开始时，短句必然从 phase=0 开始，而不是随机落在中段。

### 2. 移除 generativePhrasePhase 中的随机相位偏移
旧逻辑：

```java
return fract(time / generativePhraseDuration(gesture) + stableHash01(gesture, 14021) * 0.73f);
```

新逻辑：

```java
return fract(Math.max(0f, time) / generativePhraseDuration(gesture));
```

### 3. 起笔阶段不再画静态线段
重写：

- `generativeCreationSegments(...)`

现在 phase < 0.05 时不画线，只做蓄势；随后长度、宽度、亮度同步渐进增长。

### 4. 取消主动多层历史切片
将：

```java
int trails = cfg.powerSave ? 3 : 5;
```

改为：

```java
int trails = 1;
```

旧笔痕只依赖 FBO feedback 自然退场，避免主动重画历史切片导致“复制、分身、突然呈现”的观感。

### 5. 起点和笔尖光也改为阶段性出现
- `drawGenerativeDrawingSeed(...)` 只在早期出现；
- `drawGenerativeDrawingTip(...)` 也绑定到起笔阶段，不再在 phase=0 时突然出现亮点或线段。

## 四、预期改善

V144 的目标是：

- 不再突然直接显示静态线条；
- 每段创作都从无开始；
- 用户能看到起笔、生长、展开、退隐；
- 旧内容自然淡出，而不是主动复制成多层；
- 减少“成品摆出来等待几秒”的观感。

## 五、同步更新

已更新：

- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本文案升级为 V144。
