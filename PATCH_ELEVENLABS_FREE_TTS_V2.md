# PATCH_ELEVENLABS_FREE_TTS_V2

本次补丁在“语音与美好的祝福配置”模块中新增 ElevenLabs 免费额度普通声音 TTS，并保留原有克隆声音 TTS。

## 新增能力

1. **文字转语音声音来源切换**
   - 使用免费额度普通声音：直接填写/选择 ElevenLabs 普通声音 `voice_id`。
   - 使用克隆声音档案：继续复用原来的声音克隆档案。

2. **ElevenLabs 声音列表获取**
   - 新增 `ElevenLabsService.listVoices()`。
   - 调用 `GET /v2/voices`。
   - 支持 `voice_type`、`category`、`search` 筛选。
   - 默认筛选 `voice_type=default`、`category=premade`，更适合免费额度普通 TTS 测试。

3. **TTS 高级参数配置**
   - `speed`
   - `stability`
   - `similarity_boost`
   - `style`
   - `use_speaker_boost`
   - `language_code`
   - `apply_text_normalization`
   - `seed`
   - `previous_text`
   - `next_text`
   - 段落停顿风格：通过换行/标点增强自然停顿。

4. **表达场景预设**
   - 稳定朗读
   - 自然对话
   - 鼓励激励
   - 严厉督促
   - 温和安慰
   - 苏格拉底式追问
   - 长文课程讲解
   - 低延迟快速回复

5. **语音文件库增强**
   - 记录并展示声音来源：普通声音 / 克隆声音。
   - 记录并展示 speed、stability、style、scene 等生成参数。

6. **美好的祝福对话同步支持普通声音**
   - 如果配置为普通声音，美好的祝福语音回复将使用普通声音 `voice_id`。
   - 如果配置为克隆声音，美好的祝福语音回复将继续使用克隆声音档案。

## 修改文件

- `lib/voice_lab/eleven_labs_service.dart`
- `lib/voice_lab/voice_lab_home_page.dart`
- `lib/voice_lab/virtual_teacher_page.dart`
- `lib/voice_lab/voice_lab_models.dart`
- `lib/voice_lab/voice_lab_dao.dart`
- `lib/voice_lab/tts_audio_library_page.dart`

## 注意

ElevenLabs TTS API 当前没有“固定毫秒停顿”这样的直接参数。本补丁中的“段落停顿风格”是通过换行和标点对输入文本做轻处理，让模型更自然地产生停顿。`previous_text` / `next_text` 用于长文本分段生成时保持上下文连续性。

当前环境没有 Flutter/Dart SDK，未能执行 `flutter analyze` 或 `flutter build apk`。如果本地编译出现报错，请把完整错误日志发回继续修复。
