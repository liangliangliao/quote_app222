# PATCH_TOUCH_MYSTIFY_V12_CYCLE_AND_ART_REWRITE

本次继续针对两个核心问题改造：

## 1. 周期与占比算法

完整过程仍然按真实周期推进：

- 每轮周期默认从 1～365 天之间随机生成；
- 每个周期内只安排一次完整过程；
- 释放只在该周期中的某个随机时刻出现一次；
- 余韵只紧跟释放出现一次；
- 临界紧贴释放之前；
- 分离、吸引、同步按占比填充释放前的发展过程；
- 余韵结束后回到分离直到下一轮周期；
- 临界、释放、余韵的持续时间继续由用户设置的秒级范围随机生成。

## 2. Mystify 线条艺术感

继续减少“虫子感”和杂乱感：

- 同屏主线默认压缩到 1 条；同步/临界才偶尔允许第 2 条；
- 大幅降低线条出生密度，恢复黑场和留白；
- 线条不再围绕一个小中心弯曲，而是从全屏任意位置飞掠到另一处；
- 生成控制点时按“长势能飞掠曲线”建立方向、起笔和收笔；
- 控制点只做轻微形变，避免各自乱跑；
- 可见线段改成向前滑过整条曲线，来时像喷洒，离开像背影远去；
- Taper 轮廓变尖，减少等宽圆头蚯蚓感；
- 默认线条密度降低、光带宽度降低、残影略拉长。

主要修改：

- android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java
- lib/pages/touch_mystify_wallpaper_page.dart
- android/app/src/main/kotlin/com/example/quote_app/IntimacyWallpaperChannel.kt

