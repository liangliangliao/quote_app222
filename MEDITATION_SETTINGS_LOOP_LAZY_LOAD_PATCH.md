# 静心实验室：设置开关、循环结束与 ElevenLabs 下拉懒加载补丁

本补丁在逐句同步语音缓存版基础上继续调整：

1. ElevenLabs 普通声音 voice_id 和 TTS 模型 model_id 下拉框不再进入弹窗时自动加载，改为点击下拉框时按需加载/刷新。
2. 新增“冥想设置”统一入口，可控制：
   - 本周 AI 静心总结显示/隐藏
   - 完成后是否显示完成记录页
   - 完成页反馈文案、评分项、一句觉察输入、AI 练习后反馈显示/隐藏
   - 循环重复当前冥想
   - 定时自动结束并退出冥想
3. 播放页支持循环重复：达到脚本结尾后回到第一句继续播放，同步重新触发逐句语音。
4. 播放页支持全局定时自动结束：达到设置分钟数后自动保存完成记录并退出。
5. 若关闭完成记录页，冥想完成后自动保存基础练习记录，不再展示评分、觉察和 AI 反馈页。

主要新增文件：
- lib/meditation_module/meditation_settings_service.dart
- lib/meditation_module/meditation_settings_page.dart

主要修改文件：
- lib/meditation_module/meditation_player_page.dart
- lib/meditation_module/meditation_home_page.dart
- lib/meditation_module/meditation_record_page.dart
