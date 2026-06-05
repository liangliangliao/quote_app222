# PATCH_TOUCH_MYSTIFY_VIDEO_MATCH_V27

## 目标

将「发现之旅 → 生理赋能 → 触摸」中的 Mystify 亲密艺术壁纸，升级为更接近 Windows Mystify screensaver 视频观感的黑场光迹系统：

- 极黑背景。
- 彩色发光点线在空间中滑行、折叠、旋转。
- 头部清晰、尾部拖影逐渐失彩变细。
- 纤维丝带、点线喷洒、扇形光网、银白折刃交替出现。
- Flutter 页面预览与 Android 原生动态壁纸尽量保持同一视觉语言。

## 核心改造

### 1. Android Live Wallpaper：V27 Phosphor Fan Renderer

文件：`android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

- 渲染线程命名升级为 `IntimacyMystifyGLRendererV27PhosphorFan`。
- 默认参数调向参考视频：
  - randomness: `0.68`
  - ribbonWidth: `0.48`
  - trail: `0.84`
  - strokeDensity: `0.36`
- 保留已有 OpenGL ES 2.0 + FBO ping-pong 残影架构。
- 新增 `drawMystifyFanLattice(...)`：
  - 将同一条光迹沿法线复制为 4-18 条渐开肋纹。
  - 在同步、临界、释放阶段展开为粉紫/蓝绿/银白扇形光网。
  - 额外绘制极淡横向折线，形成电子纱、贝壳肋纹、激光折扇的网感。
- 调整残影 shader：不再只是简单乘 fade，而是每帧轻微扣黑并做极小 gamma 压缩，让尾迹先失彩、再变细、最终被黑场吞没。

### 2. Flutter 页面预览：同步视觉升级

文件：`lib/pages/touch_mystify_wallpaper_page.dart`

- 默认参数与原生壁纸同步。
- 风格名升级为：
  - Mystify 经典黑底
  - 深海蓝绿光丝
  - 紫粉扇形光网
  - 银白冷光折刃
  - 金色余韵
- Intro 与滑杆说明重写，明确“加色光迹、FBO 式残影、纤维丝带、点线喷洒和扇形光网”。
- 新增 `_drawFanLattice(...)`，让页面 Hero Preview 中也能出现与原生壁纸一致的扇形光网/电子纱肋纹。

### 3. 导航入口提示

文件：

- `lib/pages/discover_page.dart`
- `lib/pages/physical_enhancement_page.dart`

改造内容：

- 「发现之旅」中的「生理赋能」入口增加说明：触摸入口已升级为 Windows Mystify 式黑场光迹壁纸。
- 「生理赋能」中的「触摸」卡片副标题更新为：黑场、丝带、残影、余韵。

### 4. Flutter ↔ Android 配置默认值

文件：`android/app/src/main/kotlin/com/example/quote_app/IntimacyWallpaperChannel.kt`

- 默认传递给 Android Live Wallpaper 的设置值同步为 V27 视觉参数。

## 视觉验收点

进入「发现之旅 → 生理赋能 → 触摸」后，预期看到：

1. 黑色背景不是灰底或渐变底，而是明显黑场。
2. 主光迹由亮核、半透明面、细纤维、点线喷洒共同组成。
3. 局部会出现扇形/贝壳肋纹/电子纱状光网。
4. 旧尾迹不硬切消失，而是逐渐变暗、变窄、变冷，最后融入黑色背景。
5. 真实 Android 动态壁纸比 Flutter 预览更接近视频，因为它使用 FBO ping-pong 残影。

## 本地构建说明

当前执行环境缺少 Flutter/Dart SDK，且 Gradle wrapper 需要联网下载依赖，因此没有在沙盒内完成 `flutter analyze` 或 APK 构建。建议在本地项目根目录执行：

```bash
flutter clean
flutter pub get
flutter analyze
flutter build apk --debug
```

