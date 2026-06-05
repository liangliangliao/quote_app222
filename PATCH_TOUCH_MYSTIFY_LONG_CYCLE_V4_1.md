# PATCH_TOUCH_MYSTIFY_LONG_CYCLE_V4_1

本补丁针对“发现之旅/触摸 · Mystify 亲密艺术动态壁纸”继续改造：

## 本次新增/修复

1. 新增完整性交过程长周期状态机：
   - 分离
   - 吸引
   - 同步
   - 临界
   - 释放
   - 余韵

2. 默认阶段出现频率：
   - 分离：0.42，最大比例
   - 吸引：0.22，主要比例
   - 同步：0.23，主要比例
   - 临界：0.07，小比例
   - 释放：0.025，最小比例
   - 余韵：0.035，最小比例

3. 所有阶段占比均可在 Flutter 设置页中配置，保存后 Android 动态壁纸服务会读取 SharedPreferences 并动态归一化。

4. 完整周期改为以“天”为单位：
   - 默认随机周期范围：1～365 天
   - 可关闭随机周期，使用固定周期
   - 周期参数可配置：最小天数、最大天数、固定天数
   - 每轮完成后自动重新随机下一轮周期

5. 修复上一版 normalizeRatios 中 `ratioSeparation` 被重复除以总和的问题，避免阶段比例被错误压缩。

## 主要修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
- `android/app/src/main/kotlin/com/example/quote_app/IntimacyWallpaperChannel.kt`
- `lib/platform/intimacy_wallpaper_bridge.dart`
- `lib/pages/touch_mystify_wallpaper_page.dart`

## 设计说明

本功能不具象描绘性行为，而是用 Windows Mystify 式随机即时绘制的发光轨迹表达：两个生命从长时间分离、偶然吸引、逐渐同步、短促临界、极短释放到微弱余韵的完整结构。
