# PATCH_TOUCH_MYSTIFY_V11_CYCLE_ART_REWRITE

本次针对用户提出的两个核心问题继续改造：

## 1. 周期与阶段占比算法重写

旧逻辑：
- 直接把分离、吸引、同步、临界、释放、余韵按比例平铺到整个周期。
- 如果周期是 24 小时，释放和余韵也会按比例持续很久，不符合“每周期只出现一次释放/余韵”的要求。

新逻辑：
- 每轮先随机生成完整周期：默认 1～365 天，可配置。
- 每轮只随机生成一次释放时刻。
- 释放持续时间在用户配置的秒级范围内随机生成。
- 余韵紧跟释放，只出现一次，持续时间也在用户配置的秒级范围内随机生成。
- 临界紧贴释放之前，持续时间同样支持秒级范围配置。
- 分离、吸引、同步按占比填充释放之前的前置发展过程；余韵结束后回到分离直到下一轮。

默认短阶段范围：
- 临界：30～180 秒
- 释放：8～24 秒
- 余韵：20～90 秒

## 2. Mystify 画面艺术性改造

旧问题：
- 线条像虫子，形态杂乱。
- 多条线同时出现，缺少 Windows Mystify/Ribbons 的高级留白。
- 线条以均匀粗细衰减，像“死去消失”。

新改造：
- 降低同时存在的线条数量，默认更接近黑底、大留白、少量主线。
- 缩短 Stroke 生命周期，减少懒洋洋的长虫感。
- 提高运动速度，让线条更像自然喷洒/飞掠。
- OpenGL 渲染加入 tapered ribbon：线条两端尖细，中部丰盈，形成更接近 Windows 屏保的点线面质感。
- 预览页同步使用 tapered ribbon，不再只用等宽圆头线。
- 残影更克制，线条离开方式更像“背影缓缓消失”，而不是软塌塌衰亡。

## 修改文件

- android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java
- android/app/src/main/kotlin/com/example/quote_app/IntimacyWallpaperChannel.kt
- lib/platform/intimacy_wallpaper_bridge.dart
- lib/pages/touch_mystify_wallpaper_page.dart

## 测试建议

1. 打开：发现之旅 → 生理赋能 → 触摸。
2. 开启壁纸加速演示模式，周期设为 1～3 分钟。
3. 把线条出现密度先设为 35%～50%，残影长度 50%～70%。
4. 观察是否满足：黑场多、线条少、每次出现形态不同、释放/余韵只在一轮中短暂出现一次。
