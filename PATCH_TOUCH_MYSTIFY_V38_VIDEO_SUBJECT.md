# PATCH_TOUCH_MYSTIFY_V38_VIDEO_SUBJECT

## 范围
- 发现之旅 / 生理赋能 / 触摸
- Android 原生动态壁纸与页面原生预览共用的 OpenGL 渲染器：`android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
- 入口文案：`lib/pages/touch_mystify_wallpaper_page.dart`、`lib/pages/physical_enhancement_page.dart`、`lib/pages/discover_page.dart`

## 参考视频主体特征提炼
- 主体不是散点或网格，而是黑场中滑行的一整块抽象光面。
- 轮廓像丝绸、刃翼、弯月与薄片之间的复合体：一侧厚而宽，另一侧薄而锋利。
- 中央有银白/珍珠质内辉，外缘带青绿、紫色或蓝紫光晕。
- 尖端明显收束成细亮钩/针尖。
- 宽面上有贴着表面走向的细密等高线/肋纹，但这些纹理不能变成独立网状点线。

## 实现变化
1. 将主形体母型权重向 `luminous wing`、`silk banner`、`crystal shard` 倾斜，降低圆泡、花冠、轨道环、电子网和星座点链出现概率。
2. 新增 `initVideoSilkBladeSubject`：生成跨屏长弧脊线、非对称宽翼、尾端回钩与尖端收束。
3. 新增 `drawVideoSilkBladeSubject`：绘制半透明单侧宽翼、薄刃白边、珍珠内辉、贴面肋纹、尖端高光。
4. 对 V38 主体禁用旧版对称粗条兜底面，只保留克制脊线，避免把单侧厚翼抹圆。
5. 保留原有硬震屏释放、扫屏爆光与余韵水晶泡机制。

## 构建说明
本补丁保持 Java/Dart 源码级修改。当前沙箱没有可用的 `gradle-wrapper.jar` 且无法联网下载 Gradle Wrapper，因此未执行完整 Android Gradle 构建；已用 `javac` 触发解析阶段，未出现语法解析错误，剩余报错来自缺失 Android SDK 类。
