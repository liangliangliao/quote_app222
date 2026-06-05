# 静心实验室逐句语音自动准备补丁

本补丁针对冥想播放页的逐句同步语音做了以下强化：

1. “进入播放页自动准备语音”默认开启。
2. 开启逐句同步语音且自动准备开启时，播放页会先检查当前冥想每个脚本片段的缓存音频。
3. 如果缓存完整，直接从缓存加载并开始冥想，不重新调用 ElevenLabs。
4. 如果缓存不存在或片段数量不完整，页面进入等待准备状态：不计时、不显示冥想脚本文字。
5. 准备阶段会优先复用已有缓存，只对缺失片段调用 ElevenLabs TTS。
6. 所有逐句语音准备完成后，才正式开始倒计时，并同步显示脚本文字与播放对应语音。
7. “普通声音 voice_id”和“TTS 模型 model_id”改为下拉选择，进入语音设置页后会从 ElevenLabs 拉取普通声音列表与模型列表；拉取失败时保留默认/当前配置兜底。

主要修改文件：

- lib/meditation_module/meditation_player_page.dart
- lib/meditation_module/meditation_audio_service.dart
- lib/voice_lab/eleven_labs_service.dart
- lib/voice_lab/voice_lab_models.dart
