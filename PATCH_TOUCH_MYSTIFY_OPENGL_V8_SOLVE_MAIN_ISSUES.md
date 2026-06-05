# PATCH_TOUCH_MYSTIFY_OPENGL_V8_SOLVE_MAIN_ISSUES

本次补丁直接处理用户指出的三个主要问题，停止继续在 Canvas/Bitmap 方案上小修，改为 OpenGL ES + FBO 残影版。

## 1. Mystify 线条不再是预设曲线移动

文件：

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

核心改动：

- 动态壁纸渲染线程从 Canvas/Bitmap 改为 OpenGL ES。
- 新增 ping-pong FBO：每帧把上一帧纹理衰减写入新 FBO，再即时绘制当前线条。
- 旧线条历史不再由对象保存，而是由 FBO 残影自然留下。
- 每条 Stroke 是随机控制点即时生成，不是预先画好一条线再移动。

## 2. 随机运动点覆盖手机可见范围任意位置

核心改动：

- 新增全屏 Stroke Event Generator。
- 每条线支持：
  - 任意边缘切入
  - 任意角落/对角切入
  - 屏幕任意两点生成
  - 长距离扫线
- 新增 6 x 10 热区采样器，优先从最近较少出现线条的屏幕区域生成新线，避免一直集中在一小块区域。
- 双线阶段不再共享同一个小活动框，只共享节奏/相位，起点仍来自全屏不同热区。

## 3. 阶段比例与天级周期继续保留并实际驱动渲染

默认比例：

- 分离：46%
- 吸引：22%
- 同步：22%
- 临界：6%
- 释放：2%
- 余韵：2%

周期配置：

- 默认随机周期：1～365 天
- 支持固定周期
- 支持演示加速模式，用几分钟观察完整周期
- 所有比例和周期仍从 Flutter 设置页保存到 SharedPreferences，壁纸服务实时读取

## 技术路线

- Android `WallpaperService`
- EGL/OpenGL ES 2.0
- Ping-pong FBO 残影
- GPU triangle strip 光带绘制
- Shader 纹理衰减与颜色渲染
- 全屏随机 Stroke 生成器
- 天级宏观周期 + 秒级随机线条发生器

## 注意

当前环境无法完成 Android 真机编译和运行验证。请在本地执行：

```bash
flutter clean
flutter pub get
flutter build apk
```

如出现编译报错，请发送完整日志。
