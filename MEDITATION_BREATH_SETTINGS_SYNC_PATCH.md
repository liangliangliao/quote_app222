# Meditation breath animation and settings synchronization patch

This patch adjusts the meditation player and settings UI.

## Changes

1. Slowed the breathing circle animation from 4 seconds to 5 seconds per inhale/exhale phase, producing a calmer meditation rhythm.
2. Changed breathing labels from “深深吸气 / 用力吐气” back to “吸气 / 呼气”.
3. Removed the redundant settings icon from the top-right of the 静心实验室 page. The existing bottom “冥想设置” entry remains.
4. When “完成后显示完成记录页” is turned off, the completion-page content switches now synchronize visually and functionally:
   - 显示完成反馈文案
   - 显示练习前后评分
   - 显示一句觉察输入
   - 显示 AI 练习后反馈

   They are set to off and disabled. Turning the parent switch back on restores all completion-page content switches to on by default.
