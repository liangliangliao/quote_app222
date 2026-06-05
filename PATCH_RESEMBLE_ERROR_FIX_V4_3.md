# PATCH_RESEMBLE_ERROR_FIX_V4_3

修复 Resemble AI 测试连接与 TTS 生成报错。

## 修复点

1. **测试连接 HTTP 400：page 参数错误**
   - 原逻辑调用 `GET https://app.resemble.ai/api/v2/voices` 时未显式传 `page`。
   - Resemble 当前接口要求分页页码从 1 开始；某些情况下服务端会把缺省值解析为 0，返回：
     `Expected page to be a value >= 1, got 0`。
   - 已改为：
     `GET /api/v2/voices?page=1&page_size=1`。

2. **TTS 生成 HTTP 500：参数组合不兼容**
   - 原逻辑可能把 `precision` 与 `mp3` 一起发送；`precision` 只适用于 WAV。
   - 原逻辑可能显式发送不兼容/旧模型值，例如 `chatterbox`。
   - 原逻辑在 Resemble Chatterbox 上使用 `<prosody>` 模拟语速；当前 Chatterbox 对 `<prosody>` 支持不稳定，容易触发服务端错误。

3. **Resemble TTS 请求体更保守**
   - MP3 输出时不再发送 `precision`。
   - 模型默认留空，让 Resemble 按 voice_uuid 自动选择兼容模型。
   - 只有 `chatterbox-turbo` 会作为显式模型发送；`chatterbox` / `tts-v4` 自动转为留空。
   - `use_hd` 和 `apply_custom_pronunciations` 仅在开启时发送。

4. **Resemble 冥想文本预处理修正**
   - 不再用 `<prosody rate="slow">` 包裹文本。
   - 冥想模式仅使用 `<break time="...s"/>` 和 `<speak prompt="...">`。
   - 避免因为不兼容 SSML 标签导致 HTTP 500。

5. **失败自动降级重试**
   - 如果 Resemble 返回 HTTP 500，自动用最小请求体重试一次：
     `voice_uuid + 原始纯文本 + output_format`。
   - 这样可以避免因高级参数不兼容导致完全无法生成。

## 修改文件

- `lib/voice_lab/multi_provider_tts_service.dart`

