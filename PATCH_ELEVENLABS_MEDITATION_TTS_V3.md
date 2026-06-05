# PATCH_ELEVENLABS_MEDITATION_TTS_V3

本次在上一版 `ElevenLabs 免费额度普通声音 + 克隆声音 TTS` 基础上，继续落地“冥想模式文字转语音参数详细配置”。

## 主要变更

### 1. 新增表达场景：冥想放松

在 `lib/voice_lab/eleven_labs_service.dart` 中新增：

- `scene = meditation_relax`
- 名称：`冥想放松`
- 推荐参数：
  - `speed = 0.82`
  - `stability = 0.78`
  - `similarity_boost = 0.76`
  - `style = 0.12`
  - `use_speaker_boost = true`
  - `pauseMode = long`

该场景适合：

- 冥想引导
- 睡前放松
- 正念呼吸
- 身体扫描
- 温柔祝福

### 2. 新增冥想专用停顿参数

新增持久化配置项：

- `elevenlabs.meditation_auto_pauses`
- `elevenlabs.meditation_pause_profile`
- `elevenlabs.meditation_sentence_break_sec`
- `elevenlabs.meditation_paragraph_break_sec`
- `elevenlabs.meditation_breath_break_sec`
- `elevenlabs.meditation_tone`
- `elevenlabs.meditation_auto_breath_pauses`

界面中新增“冥想模式专用参数”区域，仅当表达场景选择“冥想放松”时显示。

### 3. UI 可配置内容

在 `语音与美好的祝福配置` 页新增：

- 启用冥想自动停顿
- 留白深度：轻留白 / 标准留白 / 深留白 / 自定义
- 句间停顿秒数
- 段落停顿秒数
- 呼吸提示停顿秒数
- 自动识别呼吸提示词
- 冥想语气标签：calm / soft / whisper / warm / healing
- 一键填入冥想测试文本
- 一键恢复冥想推荐参数

### 4. 文本预处理逻辑

在 `ElevenLabsService._prepareTextForGeneration` 中新增冥想预处理：

- `eleven_multilingual_v2` 等非 v3 模型：插入 `<break time="...s" />`
- `eleven_v3` 模型：插入 `[short pause]` / `[pause]` / `[long pause]`
- 自动识别 `吸气`、`呼气`、`闭上眼睛`、`放松肩膀` 等词并加入更长停顿
- v3 模型根据语气选择 `[calm]` / `[softly]` / `[whispering]` / `[warmly]`

### 5. 语音文件库记录冥想参数

`tts_audio_file` 新增字段：

- `meditation_auto_pauses`
- `meditation_pause_profile`
- `meditation_sentence_break_sec`
- `meditation_paragraph_break_sec`
- `meditation_breath_break_sec`
- `meditation_tone`
- `meditation_auto_breath_pauses`

语音文件库中，如果音频是冥想场景，会显示：

- 留白深度
- 句间停顿秒数
- 段落停顿秒数
- 呼吸停顿秒数
- 语气模式

### 6. 美好的祝福对话同步支持冥想参数

`VirtualTeacherPage` 已读取并传递冥想配置。若用户把表达场景设置为“冥想放松”，美好的祝福语音回复也会使用对应冥想参数。

### 7. 冥想模块同步使用冥想参数

`lib/meditation_module/meditation_audio_service.dart` 中的 ElevenLabs 引导音频生成已默认使用：

- `scene = meditation_relax`
- `speed = 0.82`
- `pauseMode = long`
- 自动冥想停顿开启
- 深留白预设

## 说明

当前运行环境没有 Flutter/Dart SDK，因此未执行 `flutter analyze` 或 `flutter build apk`。如本地编译出现错误，请提供完整错误日志继续修复。
