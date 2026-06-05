# PATCH_TOUCH_MYSTIFY_LONG_CYCLE_V4

本次补丁根据最新需求调整“发现之旅/触摸/Mystify 亲密艺术动态壁纸”的阶段占比与周期系统。

## 核心变化

1. 阶段结构由旧版的“吸引/靠近/同步/升高/临界/释放/余韵”调整为：
   - 分离
   - 吸引
   - 同步
   - 临界
   - 释放
   - 余韵

2. 默认阶段占比改为：
   - 分离：42%
   - 吸引：22%
   - 同步：23%
   - 临界：7%
   - 释放：2.5%
   - 余韵：3.5%

   运行时会对用户配置的占比进行归一化，确保总和为 100%。

3. 完整周期改为真实天级别：
   - 默认开启“每轮随机生成周期”
   - 默认随机范围：1～365 天
   - 每完成一轮后重新随机生成下一轮周期
   - 支持关闭随机周期，改用固定周期天数

4. Android 原生壁纸服务新增持久化周期状态：
   - cycleStartWallMs
   - cycleDurationSec
   - cycleConfigSignature

   这样动态壁纸重启后仍然能够按照真实时间推进，而不是每次重启都从头播放。

5. Flutter 设置页新增：
   - 完整周期设置区
   - 周期随机开关
   - 随机天数范围 RangeSlider
   - 固定周期天数 Slider
   - 阶段出现频率配置区
   - 阶段占比归一化摘要

## 修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
- `android/app/src/main/kotlin/com/example/quote_app/IntimacyWallpaperChannel.kt`
- `lib/platform/intimacy_wallpaper_bridge.dart`
- `lib/pages/touch_mystify_wallpaper_page.dart`

## 注意

本页预览仍然使用加速演示，方便用户在设置页快速看到阶段变化；真实动态壁纸按配置的天数推进。
