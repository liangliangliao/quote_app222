# PATCH_TOUCH_MYSTIFY_V13_POINT_LINE_SPRAY_FADE

本次针对用户上传的 Windows Mystify 参考图片和视频继续改造：

1. 参考底层 Mystify 思路：不是移动预设曲线，而是即时绘制当前线条，历史画面靠反馈缓慢衰减。
2. 参考视频观察：屏保画面不是单根线，而是“点 + 短线 + 面状光带”的组合，类似墨/光喷洒在黑纸上的效果。
3. 修改 Android OpenGL 壁纸：
   - 去掉周期性 hard clear。
   - FBO 残影衰减改为更慢的 fade，余韵和释放阶段保留更长。
   - 新增 drawPointLineSpray：沿主光带生成颗粒点、微短线和稀疏飞溅，避免“蚯蚓线”。
4. 修改 Flutter 预览：
   - 增加历史事件残影数量，模拟更慢淡出。
   - 新增 _drawPointLineSpray，让预览也呈现点线组成的喷洒笔触。

重点目标：更接近 Windows Mystify/Ribbons 的“黑底、大留白、少量高级光迹、点线面组成、缓慢消失”的视觉，而不是单条懒散曲线。
