# 语音闹钟非实时语音转文字体验优化

## 联网参考

- OpenAI Speech-to-text API 支持把音频文件提交到 `/audio/transcriptions` 做非实时转写，支持 `gpt-4o-transcribe` 等模型，并支持用 `prompt` 提升上下文、专有词、标点和前后段一致性。
- OpenAI 文档提醒长音频需要分块，且不要在句子中间切分，否则可能丢上下文。
- ChatGPT Voice FAQ 中语音对话会在退出后把转写加入文本对话，同时可设置语音主语言，说明聊天式语音输入应该让用户看到/复用转写结果并给语言偏好。
- xAI STT 支持 REST 单次文件转写和 WebSocket 实时转写；REST 返回全文、语言、时长和词级时间戳，支持 `keyterm`、`format`、`filler_words` 等转写增强参数。

## 本次借鉴落地

1. 非实时录音采用“聊天语音输入草稿”模型：录音线程持续保存完整原始 PCM，VAD 只用于自动提交，不再用于决定手动提交资格。
2. 自动提交从严格 VAD 扩展为“正式语音 / 软语音 / 低门限可能语音活动”三级判断，减少说话后 5 秒不提交的问题。
3. 服务商第一次返回空文本时，自动使用未裁剪的原始完整录音重试一次，避免本地首尾裁剪导致有效内容被删。
4. xAI 非实时 REST 请求在配置了受支持语言时自动携带 `format=true`，并继续提交 keyterm 热词，借鉴 xAI 文档推荐的文件转写增强能力。
5. 页面文案明确展示“提交中 / 重试原始录音 / 识别结果”等状态，提交中禁用手动按钮，避免重复提交。

## 主要修改文件

- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`
- `lib/voice_alarm/voice_alarm_page.dart`
