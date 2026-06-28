# 语音闹钟 xAI + 非实时语音识别升级说明

## 改造范围

- Flutter 配置页：`lib/voice_alarm/voice_alarm_page.dart`
- Android 全屏语音闹钟执行层：`android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`

## 已完成能力

1. 增加 xAI 语音识别转文字服务。
   - 实时模式：通过 `wss://api.x.ai/v1/stt` WebSocket 发送 16kHz PCM 原始音频帧，接收 partial/final 文本。
   - 非实时模式：录音完成后将 WAV 文件提交到 `https://api.x.ai/v1/stt`，取返回的最佳文本。
   - API Key 复用全局 xGrok/xAI 配置。

2. 微软和讯飞新增非实时语音识别转文字。
   - Microsoft：完整录音转 WAV 后调用 Azure Speech REST detailed 识别，优先取 `DisplayText` / `NBest[0].Display`。
   - 讯飞：完整录音按 IAT WebSocket 帧发送，复用动态修正逻辑，整段结束后返回最终文本。

3. 语音闹钟设置页新增识别模式选择。
   - `实时识别`：沿用连续/流式听写链路。
   - `非实时录音识别`：先录音，再发送给选定服务商返回最佳结果。

4. 非实时模式新增提交策略。
   - 默认 5 秒无人声自动提交，可在页面配置。
   - 全屏闹钟页显示“发送当前录音转文字”按钮，可手动提交当前录音。
   - 可配置单次最长录音时长。
   - 可开启自动纠错：当全局 AI 配置可用时，对非实时识别结果进行错别字、同音字、断句和标点纠正；闹钟控制指令（关闭/延迟）不会被改写。

## 配置字段

闹钟 payload 新增：

```json
{
  "sttMode": "realtime | batch",
  "batchStt": {
    "mode": "batch",
    "autoSubmit": true,
    "autoSubmitSilenceMs": 5000,
    "manualSubmit": true,
    "maxRecordMs": 60000,
    "autoCorrect": true,
    "bestResult": true
  },
  "sttConfig": {
    "xai": {
      "apiKey": "...",
      "endpoint": "https://api.x.ai/v1/stt",
      "streamingEndpoint": "wss://api.x.ai/v1/stt",
      "language": "",
      "sampleRate": 16000,
      "encoding": "pcm",
      "interimResults": true
    }
  }
}
```

## 验证说明

- 已完成源码级括号/结构检查。
- 当前运行环境缺少 Gradle Wrapper JAR 且无法访问 `raw.githubusercontent.com` 下载，因此未能在沙箱内完成 Android Gradle 编译。请在本地有网络或已缓存 Gradle 的环境执行：

```bash
cd android
./gradlew :app:compileDebugKotlin
```
