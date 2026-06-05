# V37 可见硬震屏释放升级

本版基于 V36，专门针对“释放阶段颤抖不明显、肉眼没看出震动效果”的反馈进行增强。

## 主要目标

- 让释放开始前 0.5 秒出现明确可见的硬震屏错位感。
- 不再只做柔和的内部光效偏移，而是通过全屏白闪、橙红热闪、斜向撕裂光带、多重错帧核心和大幅跳变偏移表现“突然颤抖”。
- 保持抽象艺术化表达，不复制参考视频中的人物、武器、道具、金币等具象内容。

## Android 原生壁纸

修改文件：

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

关键变化：

1. 渲染线程标识升级为 `IntimacyMystifyGLRendererV37VisibleImpactQuake`。
2. 释放阶段的震颤按真实秒数驱动，而不是按归一化释放进度驱动。这样无论释放阶段设置为多少秒，开头都会有稳定、可见的强震窗口。
3. 新增 `drawQuakeTearBands(...)`，在释放开头绘制斜向撕裂光带和白金断裂线。
4. 释放开头新增多重错帧核心，核心光点会以较大幅度跳变偏移，形成“画面被猛撞几下”的视觉。
5. 释放阶段即使 `release` 曲线刚开始很小，也会立即绘制震颤层，避免开头被平滑曲线削弱。

## Flutter 预览

修改文件：

- `lib/pages/touch_mystify_wallpaper_page.dart`

同步升级：

1. `_drawReleaseEruption(...)` 使用更明显的硬震屏错位逻辑。
2. 新增 `_drawQuakeTearBands(...)`。
3. 释放开始不再依赖 `release > 0` 才绘制，保证预览中也能看到开头硬震。
4. UI 文案更新为“可见硬震屏释放”。

## 注意

动态壁纸无法真正移动桌面图标或系统 UI；本版模拟的是壁纸层内部的硬震屏错位、撕裂白闪和光效冲击。
