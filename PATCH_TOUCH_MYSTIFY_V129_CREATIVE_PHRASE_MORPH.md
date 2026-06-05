# PATCH_TOUCH_MYSTIFY_V129_CREATIVE_PHRASE_MORPH

本次继续针对“发现之旅 / 生理赋能 / 触摸”动态壁纸动画优化，重点响应：

- 用户反馈：当前主体几乎没有变化和随机创造；
- 当前效果像单一主体四处移动；
- 与 Windows7 Mystify screensaver 那种随机即兴、千变万化的主体存在差距。

## 一、核心问题

V128 虽然使用了 3D 控制点和 Catmull-Rom 光弦，但控制点的基础形态仍然相对固定。
因此视觉上会出现：

1. 主体像一个固定形态在屏幕上移动；
2. 形态变化幅度不足；
3. 随机创造感不强；
4. 不像 Windows7 Mystify 中整条光弦不断改变自身形状。

## 二、技术判断

根据 Windows7 Mystify 的公开行为描述，它的核心不是单一物体移动，而是：

- 一条或多条 curved strings of light；
- 光弦不断改变形状；
- 颜色持续循环；
- 历史残影保持同色同形并短暂淡去；
- 速度和远近不均匀变化；
- CameraFOV / LineWidth / NumLines / Blur 影响整体效果。

因此 V129 不再只是让控制点移动，而是让控制点进入“形态短句”系统。

## 三、主要改造

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 控制点从“固定反弹”升级为“创作短句”
重写：
- `buildWindows7MystifyString(...)`

新增：
- `mystifyPhraseDuration(...)`
- `mystifyPhraseMode(...)`
- `mystifyPhraseControlPoint(...)`
- `mystifyPhraseHash(...)`
- `mystifyCreativePhrasePulse(...)`

现在每隔数秒会生成新的控制点形态倾向，然后在相邻短句之间平滑 morph。

### 2. 新增六类控制点形态倾向
`mystifyPhraseControlPoint(...)` 中加入 6 类形态模式：

1. 弓形展开；
2. S 形扭转；
3. 钩形短句；
4. 扇形开合；
5. 波浪即兴；
6. 折返 / 花冠式开合。

这些并不是外加图形，而是同一条 Mystify 光弦的控制点拓扑变化。

### 3. 相邻形态短句丝滑插值
在 `buildWindows7MystifyString(...)` 中：

- `phraseA` 表示当前短句；
- `phraseB` 表示下一短句；
- `phraseMix` 负责平滑插值；

这样主体不会突然跳变，但会持续产生新的形态。

### 4. 保留 Windows7 Mystify 的核心结构
仍然保留：

- 3D 控制点；
- Catmull-Rom 光弦；
- CameraFOV 式透视；
- LineWidth 式高光；
- 颜色循环；
- 同形历史切片残影；
- Blur 式快速淡去；
- 动态壁纸屏幕适配。

### 5. 增加第二条弱光弦
非省电模式下，V129 启用第二条较弱的同步光弦：

- 增强随机创造感；
- 但保持主光弦清晰；
- 避免重新堆成光雾。

## 四、同步更新

更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本文案升级为 V129。

## 五、检查

- 已检查 Java 大括号平衡；
- 已确认源码中没有继续引用此前导致编译失败的 `cfg.intensity`。
