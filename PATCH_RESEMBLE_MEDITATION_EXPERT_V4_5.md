# PATCH_RESEMBLE_MEDITATION_EXPERT_V4_5

本次继续加强 Resemble AI 的冥想场景文字转语音效果，目标是让其更接近“冥想语音引导专家”。

## 主要改动

1. 在 `语音与美好的祝福配置` 的冥想模式中新增 `Resemble AI 冥想专家参数` 面板：
   - Resemble 冥想合成模式：
     - 专家 SSML + Prompt（推荐）
     - 安全 SSML + Prompt
     - 只插入停顿，不加 prompt
     - 只加 prompt，不插入停顿
   - 是否使用 Resemble 冥想导演 prompt
   - 自定义 Resemble 冥想 prompt
   - Resemble 单个 `<break>` 最大秒数
   - 长停顿是否拆分为多个 `<break>`
   - 一键恢复 Resemble 冥想专家参数

2. 新增 Resemble 配置持久化 Key：
   - `resemble.meditation_mode`
   - `resemble.meditation_use_prompt`
   - `resemble.meditation_prompt`
   - `resemble.meditation_max_break_sec`
   - `resemble.meditation_split_long_breaks`

3. 增强 Resemble TTS 文本预处理：
   - 冥想场景下可自动插入 SSML `<break time="...s" />`。
   - 长留白会拆成多个短 break，例如 12 秒可拆为 3+3+3+3 秒，避免一次性超长停顿导致服务端异常。
   - 支持 `<speak prompt="...">` 的冥想导演提示。
   - 避免默认使用 `<prosody>`，降低 Resemble Chatterbox/不同声音模型出现 500 的概率。

4. 美好的祝福对话页同步读取并使用 Resemble 冥想专家参数。

5. Resemble API 配置处新增“一键套用 Resemble 冥想音质推荐”：
   - mp3
   - 48000 sample_rate
   - use_hd = true
   - model 留空，让 Resemble 按 voice_uuid 自动选择兼容模型

## 设计原则

- Resemble 的冥想效果不硬套 ElevenLabs 的 stability/style 等参数。
- 以 voice_uuid、SSML break、prompt、HD 合成、采样率共同控制冥想效果。
- 长停顿优先拆分，避免直接发送巨大 break，减少服务端失败和音频伪影概率。
