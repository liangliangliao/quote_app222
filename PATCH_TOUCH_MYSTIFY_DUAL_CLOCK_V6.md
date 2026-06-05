# PATCH_TOUCH_MYSTIFY_DUAL_CLOCK_V6

本次继续针对“效果仍不像 Windows Mystify、长周期导致实际看不到效果、随机线条仍有中心化倾向”进行结构性改造。

## 1. 渲染核心改动

修改文件：

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

关键变化：

1. **双时钟系统**
   - 默认真实模式仍按 `1～365 天`随机生成完整性交过程周期。
   - 新增可选“加速演示模式”，用于几分钟内观察完整过程。
   - 解决真实天级周期下用户短时间内几乎只能看到某一阶段的问题。

2. **随机线条发生器强化**
   - 每条 Beam 仍由随机控制点即时生成。
   - 增加每条线自己的随机吸引点 `attractX/attractY`。
   - 不再用 activityRect 的中心作为吸引点，避免全屏轨迹被拉回屏幕中央。

3. **全屏任意位置出生与运动**
   - 保留 V5 的全屏活动范围逻辑。
   - 控制点可在可见屏幕任意位置、边缘、角落、对角线方向出生。
   - 每条线的活动范围、初始点、速度、颜色、生命周期均随机。

4. **线条出现密度可控**
   - 新增 `strokeDensity` 参数。
   - 用于控制随机即时线条发生器的出生频率。
   - 默认保持克制，避免画面杂乱。

5. **线条质感更接近 Mystify**
   - 主线宽度缩窄。
   - 速度略提高。
   - 残影仍由黑色半透明覆盖形成，而非保存完整路径。

## 2. 设置页改动

修改文件：

- `lib/pages/touch_mystify_wallpaper_page.dart`
- `lib/platform/intimacy_wallpaper_bridge.dart`
- `android/app/src/main/kotlin/com/example/quote_app/IntimacyWallpaperChannel.kt`

新增配置：

- `线条出现密度 strokeDensity`
- `壁纸加速演示模式 previewAccelerated`
- `演示周期 previewCycleMinutes`

修复：

- 删除阶段配置里重复出现的“吸引”滑块。

## 3. 默认设计思想

- 分离占最大比例；吸引、同步占主要比例；临界较少；释放、余韵最少。
- 真实动态壁纸按天推进，但用户可临时开启加速演示模式检查效果。
- Mystify 不再被理解为“预设曲线移动”，而是“随机运动点即时绘制 + framebuffer 残影衰减”。

## 4. 建议测试方式

1. 进入 `发现之旅 → 生理赋能 → 触摸`。
2. 开启“壁纸加速演示模式”。
3. 设置演示周期 1～3 分钟。
4. 点击保存参数。
5. 打开动态壁纸预览页观察完整过程。
6. 满意后关闭“壁纸加速演示模式”，再正式设置为主屏/锁屏动态壁纸。

