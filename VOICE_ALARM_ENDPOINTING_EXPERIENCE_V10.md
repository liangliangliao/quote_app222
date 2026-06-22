# VOICE_ALARM_ENDPOINTING_EXPERIENCE_V10

本次修复针对“分段语音转文字太碎、用户一段话没说完就提交给 AI”的体验问题。

## 核心改造

1. 新增 `voiceEndpointing` 参数并随闹钟 payload 保存。
2. Android 全屏语音闹钟页不再把每个 STT final/partial 片段立即发给 AI，而是先写入本地 `speechBuffer`。
3. 使用“句段端点检测”判断一段话是否可能已经说完：
   - 完整静音时长 `completeSilenceMs`
   - 可能完成静音时长 `possiblyCompleteSilenceMs`
   - 最短说话时长 `minUtteranceMs`
   - AI 提交等待 `finalCommitDelayMs`
   - partial 兜底等待 `partialFallbackDelayMs`
   - 语义完整度二次等待 `semanticExtraWaitMs`
   - 单段最长等待 `maxUtteranceMs`
   - 最少提交字数 `minCommitChars`
   - 是否启用语义端点复核 `semanticEndpointing`
4. 增加语义完整度复核：如果识别文本以“因为/然后/但是/我想/关于/如果”等明显未完成表达结尾，先不提交给 AI，而是继续等待新的语音片段。
5. Android `SpeechRecognizer` 的三个静音参数改为从用户设置读取：
   - `EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS`
   - `EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS`
   - `EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS`
6. Microsoft/讯飞云识别的本地录音 VAD 也改为读取同一套 endpointing 参数，减少过短录音片段。
7. 设置页新增“语音句段提交策略”卡片，提供四个预设：
   - 快速响应
   - 均衡体验
   - 完整句段
   - 长语音
8. 设置页开放可调节参数：说完判定静音、AI 提交等待、最短说话时长、单段最长等待、最少提交字数、语义完整度复核。

## 设计参考

成熟语音交互系统通常不会把每个识别片段立即作为最终用户意图提交，而是结合 VAD、尾部静音、最短语音长度、最大等待时长和语义完整度判断。Azure Speech 的语义分段也强调，不只依赖静音，而是结合句子结束标点等语义信号，减少过度分段和文本墙问题。Deepgram endpointing 也采用基于 VAD 的静音端点检测。

## 修改文件

- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`
- `lib/voice_alarm/voice_alarm_page.dart`

## 注意

不同手机系统的 `SpeechRecognizer` 可能不完全遵守静音参数，所以本次修复不只依赖系统识别参数，还在 App 层增加了二次缓冲和语义提交策略。
