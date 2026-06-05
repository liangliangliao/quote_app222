# PATCH_RESEMBLE_ERROR_FIX_V4_4

本次修复 Resemble AI 两类报错：

## 1. 测试连接 page_size 报错

错误：

```text
Expected page_size to be a value between 10 to 1000 (inclusive), got 1
```

修改：

- `testResembleConnection()` 改为请求 `page=1&page_size=10`
- `listResembleVoices()` 的 `pageSize` 限制改为 `10..1000`

## 2. 生成语音返回裸 base64 导致解析失败

错误：

```text
FormatException: Invalid character ... SUQzBAAAAA...
```

原因：

- Resemble 同步 TTS 正常文档响应为 JSON：`{ success: true, audio_content: "base64..." }`
- 但实际某些账号/网关/模型组合会直接返回裸 base64 音频字符串，或返回原始音频 bytes。
- 旧代码固定 `jsonDecode(resp.body)`，因此遇到裸 base64 或音频 bytes 会失败。

修改：

- 新增 `_extractResembleAudioBytes(http.Response resp)`
- 支持以下响应格式：
  - JSON map: `audio_content` / `audioContent` / `audio` / `data` / `base64`
  - JSON string: `"SUQz..."`
  - 裸 base64 字符串: `SUQz...`
  - data URL: `data:audio/mpeg;base64,...`
  - 原始音频 bytes: MP3/ID3、MP3 frame、WAV/RIFF、FLAC、OGG
- base64 自动移除空白、补齐 padding，并兼容 URL-safe base64。

## 主要修改文件

```text
lib/voice_lab/multi_provider_tts_service.dart
```
