# 静心实验室 Resemble AI 逐句 TTS 集成补丁

本补丁在冥想模块“语音与背景音”设置中增加 Resemble AI 文字转语音平台支持。

## 已实现

1. **TTS 平台可切换**
   - 当前冥想可在 ElevenLabs 与 Resemble AI 之间切换。
   - 平台选择、声音、模型和相关参数按当前冥想独立保存，不影响其他冥想已有缓存。

2. **Resemble AI 声音设置**
   - 支持账号已有 voice_uuid。
   - 支持 App 内 Resemble 克隆声音档案。
   - 声音列表按需加载：只有点击 Resemble 下拉框时才请求 API。

3. **Resemble AI 模型设置**
   - 支持自动选择 / Chatterbox。
   - 支持 Chatterbox Turbo。
   - 模型列表按需加载，避免频繁请求。

4. **Resemble 冥想专家参数**
   - 输出格式：mp3 / wav。
   - precision：MULAW / PCM_16 / PCM_24 / PCM_32。
   - sample rate、HD、自定义发音。
   - 冥想合成模式：专家 SSML + Prompt / 仅 SSML 停顿 / 仅 Prompt。
   - Resemble 冥想导演 Prompt。
   - 单个 break 最大秒数。
   - 长停顿拆分。

5. **逐句同步语音支持 Resemble**
   - 当前句子出现时播放该句 Resemble 生成的语音片段。
   - 缓存 key 已包含 provider、voice_uuid、model、output_format、precision、HD、Prompt、SSML break 等 Resemble 参数。
   - 同一冥想同一参数会命中缓存，避免重复调用接口。

## 修改文件

- `lib/meditation_module/meditation_audio_service.dart`
- `lib/meditation_module/meditation_player_page.dart`

