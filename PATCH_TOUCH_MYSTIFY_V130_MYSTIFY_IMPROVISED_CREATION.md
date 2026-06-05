# PATCH_TOUCH_MYSTIFY_V130_MYSTIFY_IMPROVISED_CREATION

本次继续优化“发现之旅 / 生理赋能 / 触摸”动态壁纸动画，重点响应：

- 当前主体仍像单一形体四处移动；
- 缺乏 Windows7 Mystify 那种即兴随机创造、千变万化、此起彼伏的主体变化；
- 用户希望更接近 Windows7 Mystify screensaver 的持续随机创造感。

## 一、技术判断

Windows7 Mystify 的公开源码并不公开，但公开资料能确认其行为特征与隐藏参数：

- 一条或多条弯曲光线在黑色背景上运动；
- 光线会不断改变形状；
- 光线会循环颜色；
- 光线会留下短暂淡去的同色同形残影；
- CameraFOV / LineWidth / NumLines / Blur 影响视场远近、线条厚度、光弦数量和残影淡化。

因此，V130 不再把重点放在外部附加形状，而是继续改造“控制点光弦”本身，让其不断随机重写自己的形态语法。

## 二、主要改造

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 非省电模式从 2 条光弦扩展为 3 条
在 `drawScreensaverArtistBrush(...)` 中：

- `strings` 从非省电 2 条提升为 3 条；
- 每条光弦使用不同 `sg` 种子、相位、透明度；
- 每条光弦拥有自己的短句变化与残影节奏。

目的：
- 避免“只有一个主体在移动”；
- 增加 Windows7 Mystify 那种多线条同场运动的层次感；
- 但仍保持主光弦最清晰，避免重新堆成光雾。

### 2. 控制点短句形态从 6 类扩展为 10 类
重写 `mystifyPhraseControlPoint(...)`，新增并扩展为 10 类控制点形态语法：

1. 大弓形展开；
2. 双 S 扭转；
3. 钩形短句；
4. 扇形开合；
5. 多频波浪即兴；
6. 折返 / 花冠式开合；
7. 蝴蝶翼式双瓣；
8. 螺旋绞索；
9. 闪电式折线但保持曲线插值；
10. 喷泉式扩散。

这些不是外部图形，而是同一条 Mystify 光弦的 3D 控制点拓扑变化。

目的：
- 让光弦“自身”持续改写形状；
- 避免单一主体一直移动；
- 让每隔几秒出现新的不可预期形态。

### 3. phrase duration 缩短并扩大随机差异
调整：
- `mystifyPhraseDuration(...)`

从较稳定的几秒短句，改为更短、更随机的区间。

目的：
- 提高“下一秒不知道会变成什么”的即兴感；
- 增强主体此起彼伏、不断变化的节奏。

### 4. 控制点能量、跨度和深度变化增强
在 `buildWindows7MystifyString(...)` 与 `mystifyPhraseControlPoint(...)` 中：

- 扩大 `span` 变化范围；
- 增强 `lateral` 侧向变化；
- 增强 `depth` 深度变化；
- 加入更明显的局部 flicker；
- 增强 yaw / roll / pitch 的短句驱动变化。

目的：
- 让光弦不只是移动，而是明显变形；
- 让主体的“创造”发生在控制点层面。

### 5. CameraFOV 呼吸更明显
调整：
- `mystifyCameraFov(...)`

让近远变化更明显。

目的：
- 加强 Windows7 Mystify 那种忽远忽近、此起彼伏的空间感。

### 6. 修复潜在 Java 编译错误
修复：
- `projectMystify3dPoint(...)` 中重复声明 `float z2 = z1;` 的问题。

同时确认：
- 源码中没有继续引用此前导致编译失败的 `cfg.intensity`。

## 三、同步更新

更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V130。
