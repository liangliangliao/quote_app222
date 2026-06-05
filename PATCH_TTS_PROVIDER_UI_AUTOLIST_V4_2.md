# PATCH_TTS_PROVIDER_UI_AUTOLIST_V4_2

## 目标

优化“语音与美好的祝福配置”页面中 ElevenLabs / Resemble AI / MiniMax 多服务商显示混乱的问题。

## 本次修改

1. **服务商配置按当前选择显示**
   - 用户选择 ElevenLabs 时，只显示 ElevenLabs API Key、模型、输出格式、普通/克隆声音。
   - 用户选择 Resemble AI 时，只显示 Resemble API Token、voice_uuid、Resemble 模型/输出/HD/发音参数。
   - 用户选择 MiniMax 时，只显示 MiniMax API Key、Endpoint、模型、voice_id、格式、采样率、码率、情绪等。
   - 其他无关平台的配置项自动隐藏，避免用户误填。

2. **新增模型查询**
   - ElevenLabs：调用 `/v1/models` 查询当前 API Key 可用 TTS 模型。
   - MiniMax：调用 `/v1/models` 查询账号可用模型；如果接口不可用，则回退到官方推荐 Speech 模型列表。
   - Resemble AI：根据官方机制提供“自动选择 / Chatterbox / Chatterbox Turbo”建议项，因为 Resemble 克隆声音默认使用 Chatterbox，可留空让平台按声音自动选择。

3. **新增声音查询**
   - ElevenLabs：继续使用 `/v2/voices` 查询可用 voices。
   - Resemble AI：新增 `GET https://app.resemble.ai/api/v2/voices` 查询账号可访问 voice_uuid。
   - MiniMax：新增 `POST https://api.minimax.io/v1/get_voice` 查询 system / voice_cloning / voice_generation 下当前账号可用 voice_id。

4. **声音选择体验优化**
   - 查询到的 voice_id / voice_uuid 会显示为可点击列表。
   - 点击后自动填入对应输入框，并切换到当前服务商的“手动/账号声音”来源。
   - 克隆声音档案仍按当前服务商过滤显示，避免不同平台声音混用。

5. **TTS 参数按服务商精简**
   - ElevenLabs 显示 stability / similarity_boost / style / speaker_boost / language_code / seed / previous_text / next_text。
   - Resemble AI 隐藏 ElevenLabs 专用参数，仅保留 speed、SSML/HD、采样率、冥想停顿等有效参数。
   - MiniMax 显示 speed / volume / pitch / emotion / language_boost / text normalization / sound effects 等相关参数。

## 修改文件

- `lib/voice_lab/voice_lab_home_page.dart`
- `lib/voice_lab/multi_provider_tts_service.dart`
- `lib/voice_lab/voice_lab_models.dart`

## 说明

当前环境没有 Flutter/Dart SDK，无法执行 `flutter analyze` 或 `flutter build apk`。已做括号/结构完整性检查。
