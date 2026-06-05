# PATCH_TOUCH_MYSTIFY_V140_OPEN_SOURCE_SCREENSAVER_FLOW

本次继续优化“发现之旅 / 生理赋能 / 触摸”动画主体。

## 一、问题复盘

用户反馈：

- 当前效果仍像蛇一样在屏幕上乱串；
- 仍看不到缓慢、渐进、丝滑、连贯的创作过程；
- 容易出现先画出一个网状，再复制或分身出多个相似网状；
- 绘画和变形仍有分离感。

因此 V140 的核心目标不是继续增加复杂图形，而是回到开源艺术 screensaver 的基本动画原则：

- 一个 autonomous display hack 自己持续作画；
- 不要把历史副本重画成分身；
- 让当前笔触本身逐步生成；
- 旧画面由帧缓冲残影自然消退。

## 二、借鉴方向

参考公开资料中的 XScreenSaver / Flurry 等开源艺术屏保思想：

- XScreenSaver 是由大量独立图形 demo/hack 组成的屏保系统；
- Flurry 这类屏保更像连续流式生成，而不是让一个图片主体漂移；
- Electric Sheep 的启发是生成系统需要持续变异，而不是重复同一主体。

本次没有复制第三方源码，而是借鉴其生成结构原则，避免许可证与平台不兼容问题。

## 三、核心修改

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 禁止主动重画大量历史副本
在 `drawWindows7MystifyGenerativeCreation(...)` 中：

- `trails` 改为 1；
- 不再主动绘制很多历史曲线切片；
- 避免用户看到多个相似网状“分身”；
- 旧痕迹交给原有 FBO/反馈残影自然消退。

### 2. 固定当前短句构图，避免像旧主体漂移
在 `buildGenerativeMystifyCurve(...)` 中：

- 当前短句 92% 之前不 morph 到下一短句；
- 中心、尺度、控制点模式都保持属于当前短句；
- 只做内部控制点展开；
- 让观众看到的是“这一笔被慢慢画出来”，不是一个主体到处跑。

### 3. 让控制点随绘制进度逐步打开
在 `generativeControlPoint(...)` 中：

- x / y / z 不再一开始就完整展开；
- 控制点横向、纵向、深度维度都随短句进度逐步打开；
- 绘制和变形绑定为同一个过程。

### 4. 改成单一连续短句
重写 `generativeCreationSegments(...)`：

- 不再中心向多方向同时扩张；
- 不再多窗口显影；
- 不再后段补完整主体；
- 一个短句只返回一个从 0 到 reveal 的连续片段；
- 视觉上更接近“先头、再身、再尾”的连贯创作过程。

### 5. 进一步放慢短句节奏
调整：

- `generativePhraseDuration(...)`
- `generativePhraseMorphMix(...)`
- `generativePhraseLife(...)`
- `generativePhraseReveal(...)`

让短句拥有更长的起笔、展开、完成和退隐时间。

## 四、同步更新

更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V140。
