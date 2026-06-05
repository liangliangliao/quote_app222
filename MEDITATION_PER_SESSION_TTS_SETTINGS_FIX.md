# 静心实验室：单个冥想 TTS 参数隔离修复

## 修复问题

之前在某一个冥想播放页修改 ElevenLabs 文字转语音参数后，会写入全局 ElevenLabs 配置。其他冥想再次进入时，会使用新的全局参数计算缓存 key，导致原本已经生成并缓存的逐句语音无法命中，从而重新调用 ElevenLabs 准备语音。

## 本次修复

1. 播放页中的 ElevenLabs 声音、模型、语速、稳定性、相似度、风格、Speaker Boost、语言、文本规范化、冥想停顿等 TTS 参数改为按 `sessionKey` 单独保存。
2. “逐句同步语音”“进入播放页自动准备语音”“缓存上限”“AI 缓存保留天数”等通用开关仍保留为全局设置。
3. 某个冥想修改 TTS 参数后，只影响该冥想自身的逐句语音缓存与后续生成，不再影响其他冥想。
4. 进入其他冥想时，仍会优先命中该冥想原本已经存在的完整语音缓存，避免重复调用 ElevenLabs。
5. 设置弹窗新增说明：声音、模型、语速等参数只保存到当前冥想。

## 修改文件

- `lib/meditation_module/meditation_audio_service.dart`
- `lib/meditation_module/meditation_player_page.dart`

## 技术要点

- 新增按 `sessionKey` 哈希存储的 per-session TTS 参数：
  `meditation.tts.session_voice_settings.<sha256(sessionKey)>`
- `loadTtsRuntimeSettings(sessionKey: ...)` 会先加载全局通用配置，再叠加当前冥想独立的 TTS 参数。
- `saveTtsRuntimeSettings(settings, sessionKey: ...)` 在播放页保存时只写入当前冥想的 TTS 参数，不改写其他冥想使用的全局声音参数。
- 兼容历史缓存：当当前冥想没有独立 TTS 参数，但已有完整缓存时，优先沿用该冥想自己的历史缓存。
