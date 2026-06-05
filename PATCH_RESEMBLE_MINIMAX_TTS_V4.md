# PATCH_RESEMBLE_MINIMAX_TTS_V4

本次在“语音与美好的祝福配置”中新增 Resemble AI 与 MiniMax 两个文字转语音服务商，和原有 ElevenLabs 一起作为可切换 Provider。

## 主要变更

1. 新增多服务商配置
   - `ElevenLabs`
   - `Resemble AI`
   - `MiniMax`

2. 新增 `lib/voice_lab/multi_provider_tts_service.dart`
   - 统一保存 Resemble / MiniMax 配置
   - 支持 Resemble TTS 合成并保存到语音文件库
   - 支持 MiniMax T2A v2 合成并保存到语音文件库
   - 支持 Resemble voice_uuid / MiniMax voice_id 手动档案保存
   - 支持 Resemble 克隆声音创建流程
   - 支持 MiniMax 克隆声音创建流程
   - 继续复用原有 TTS 缓存、自动保存、语音文件库、下载、删除能力

3. 语音配置页增强
   - 新增“文字转语音服务商”选择卡片
   - Resemble 参数：API Token、模型、输出格式、WAV 精度、采样率、HD、custom pronunciations、voice_uuid、克隆类型
   - MiniMax 参数：API Key、Group ID、Endpoint、模型、格式、采样率、码率、声道、音量、音调、情绪、language_boost、文本规范化、音效
   - 表达场景与冥想参数对三个 Provider 共用

4. 声音克隆页增强
   - 同一页面支持 ElevenLabs / Resemble AI / MiniMax
   - Resemble：Rapid / Professional clone、样本文本 transcript
   - MiniMax：上传 clone 样本、可选 prompt_audio、prompt_text、自定义 voice_id、预览文本
   - 三者都支持手动粘贴已有 voice_id / voice_uuid

5. 冥想场景适配
   - ElevenLabs：沿用 break / v3 标签逻辑
   - Resemble：使用 SSML break、prosody rate、speak prompt 做慢速冥想引导
   - MiniMax：使用 `<#秒数#>` 固定停顿标签，支持更长冥想留白

6. 美好的祝福对话页增强
   - 对话语音回复会按当前 Provider 自动走 ElevenLabs / Resemble / MiniMax
   - 生成音频继续进入语音文件库

## 注意事项

- Resemble AI 的克隆 API 可能需要对应套餐权限；如果返回 401/403/plan error，需要在 Resemble 后台确认权限。
- MiniMax 克隆声音要求上传有效音频样本；voice_id 需要符合 MiniMax 账号规则。
- 当前运行环境没有 Flutter/Dart SDK，因此未执行 `flutter analyze` 或 `flutter build apk`。
