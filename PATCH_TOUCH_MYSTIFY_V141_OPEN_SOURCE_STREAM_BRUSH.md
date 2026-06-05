# PATCH_TOUCH_MYSTIFY_V141_OPEN_SOURCE_STREAM_BRUSH

本次继续优化“发现之旅 / 生理赋能 / 触摸”动态壁纸动画。

## 一、问题复盘

用户反馈：当前效果仍然看不到逐渐连续发展变化的形体与创作过程，屏幕上大多只出现一条很细的线，仍然像蛇形轨迹。

这说明 V140 虽然避免了大量历史副本和分身，但又过度收缩为“单线绘制”，导致艺术屏保应有的光带、流场、体量、显影层次没有出来。

## 二、参考方向

继续参考开源艺术屏保的机制：

- Flurry：彩色粒子系统/流式生成；
- Really Slick Screensavers：开源 3D CGI 屏保集合，强调光带、粒子、物理式动态；
- XScreenSaver：大量独立生成器持续渲染，而不是移动静态图片。

因此 V141 的重点不是继续增加形状种类，而是把“单线”升级为“流式画笔”：一条轨迹在生长时，应该同步出现膜面、边缘高光、主体亮核和少量结构肋线。

## 三、核心修改

文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 加粗基础光弦

将 `lineWidth` 从过细的像素级细线提高到更容易看清的光笔宽度，避免主体长期像一根蛇线。

### 2. 新增流式画笔主体

新增：
- `drawGenerativeGrowingFormSegments(...)`
- `drawGenerativeGrowingForm(...)`

新的绘制方式会基于当前已经生长出来的同一条曲线，同时生成：

- 内侧笔触线；
- 外侧膜面；
- 主体青色光核；
- 白色高光脊线；
- 边缘彩色高光；
- 少量结构肋线。

这样观众看到的不再是一条细线在屏幕上走，而是一支光笔在逐步展开成一个可见光形。

### 3. 让主体更早进入发展阶段

调整 `generativeCreationSegments(...)`：

- 更早出现可辨认主体；
- 更快进入身体发展阶段；
- 保留逐步起笔、发展、尾段完成；
- 不恢复多窗口/复制/分身逻辑。

### 4. 调整短句时长

将短句节奏从过慢的“长期只有一根线”调整为更适合观察的缓慢生成节奏：

- 仍然足够慢，可以看清初始、发展、完成、消失；
- 但不会慢到几秒钟只看到一根未展开的线。

## 四、同步更新

已同步：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本升级为 V141。
