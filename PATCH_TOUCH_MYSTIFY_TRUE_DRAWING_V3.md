# PATCH_TOUCH_MYSTIFY_TRUE_DRAWING_V3

本补丁按用户上传的 Windows Mystify 参考视频重新修正动态壁纸算法。

## 核心修复

此前版本的问题：
- 把曲线预先生成后整体移动，视觉上像“物体在移动”，不像 Windows Mystify 的“线条正在随机画出来”。
- 活动范围仍偏中心化，随机性不足。
- 临界、释放、余韵比例过高，导致性交过程结构喧宾夺主。

本版改为：
- 每个 Beam 从任意边缘/角落/局部区域随机出生。
- 每帧只绘制当前随机控制点形成的即时线条，残影由 framebuffer 衰减自然留下。
- 控制点在每个 Beam 的随机 bounds 中反弹、转向、变形，不再使用固定中心轨道。
- 大部分周期分配给吸引、同步、升高；临界/释放/余韵只短促出现。
- 支持单线、双线、少量扇形线，避免杂乱。

## 修改文件

- android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java
