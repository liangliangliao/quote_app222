# PATCH_TOUCH_MYSTIFY_V93_LIVING_RANDOM_BRUSH

本次继续针对“发现之旅 / 生理赋能 / 触摸”动态壁纸主体阶段优化，重点对齐用户新增要求：

- 画笔作画时需要更加流畅、丝滑；
- 需要表现灵活、富有生命力的艺术美感；
- 每次出现的位置必须随机，不能接着前一次位置继续画；
- 效果应更接近参考视频中“随机位置突然出现一支活的光笔”。

## 主要修改

### 1. 取消前后笔位置衔接
文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

本次不再让每次笔画沿用前一笔的路径连续性：
- 移除了主体阶段的段首交接调用；
- 新增 `continuousPenAnchor(...)`；
- 每个 gesture 都会独立计算自己的随机落笔 anchor。

这使得每次光笔都会在屏幕随机位置独立出现，而不是从上一次终点接着往下画。

### 2. 重写主笔路径生成方式
重写 `continuousPenPoint(...)`：
- 从原先依赖相邻 knot 的连续 Catmull-Rom 轨迹，调整为“以单次随机 anchor 为中心”的独立局部轨迹；
- 每一笔拥有独立朝向、尺度、弯曲和生命律动；
- 保留花瓣、扇翼、环扣、极光幕、丝带、书法钩、海浪、羽眼等 motif，但全部变成单次独立生成。

### 3. 提升流畅度、丝滑感和生命力
对主笔路径内部做以下增强：
- 提高采样密度，让曲线更平滑；
- 降低宽度脉冲的突兀感，让节奏更柔和；
- 新增 `breath` 与 `flutter` 微动，使画笔内部更像“活的光线”，而不是机械几何线段。

### 4. 保留现有优点
继续保留：
- 秒级显形，避免刚安装后长时间黑屏；
- 自然停顿；
- 独立随机艺术光形层；
- 原有释放与余韵阶段逻辑。

## 同步文案
更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V93。
