# PATCH_TOUCH_MYSTIFY_V57_PAINTERLY_LIVING_SUBJECT

## 目标

针对 V56 仍像“完整主体在运动/换形”，而不是参考视频中“像画家现场作画一样逐渐画出生命光膜”的问题，只重做主体阶段。

释放阶段和余韵阶段保持 V47/V56 逻辑不动。

## 核心变化

1. 主体不再由完整形状模板直接生成。
2. 当前主体改为由“正在移动的笔尖”和其身后的短时间历史轨迹生成。
3. 每个顶点采样自不同历史时间点，因此中心折脊、外缘、膜宽、肋纹都会随笔尖推进连续变化。
4. 入场阶段从一小段发光曲线开始，历史长度逐渐增长，形成“现场书写/现场绘画”的过程。
5. 轨迹使用中部小舞台内的稳定随机控制点 + Catmull-Rom 插值，避免整片漂移，同时保证随机和连贯。
6. 颜色在绿色、紫色、暖色之间缓慢流动，避免突然换色。
7. 增加笔尖高光、湿光膜底色、外缘线、中心折脊、贴面线、短肋线，让主体从“静态叶片”改为“正在被画出的开放光膜”。

## 修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`
- `lib/pages/touch_mystify_wallpaper_page.dart`

## 验证

已用本地 Android/OpenGL/EGL 轻量桩类执行 Java 语法级编译检查，通过。

完整 Gradle/Flutter 构建仍受源码包缺少 `android/gradle/wrapper/gradle-wrapper.jar` 限制，离线环境无法完成 APK 构建。
