# 健康饮食语音输入识别稳定性修复

本次修复针对每日饮食分享语音输入页在部分 Android/国产 ROM 上出现的：

- 说完一句后继续说无法识别；
- `error_client` 后界面仍显示正在听，但实际上不再续听；
- `error_speech_timeout` / `error_timeout` 后只保留一句；
- 系统语音识别长时间占用导致下一轮启动失败。

## 主要修改

文件：`lib/health_diet/daily_share/diet_voice_input_page.dart`

### 1. 识别轮次由“长时间连续听写”改为“短句分段 + 自动重开麦克风”

- 单轮 `listenFor` 改为 12 秒；
- `pauseFor` 改为 1.5 秒；
- 临时识别结果稳定后主动保存为片段；
- 保存后主动 `stop()` 当前 SpeechRecognizer，再延迟重开下一轮；
- 更接近聊天软件“一句一条语音消息”的实际工作方式。

### 2. `error_client` / timeout 不再直接卡死

将以下错误视为可恢复错误：

- `error_client`
- `error_timeout`
- `error_speech_timeout`
- `error_no_match`
- `error_busy`
- `recognizer_busy`

遇到这些错误时：

1. 先保存当前已经听到的片段；
2. 主动停止系统识别器；
3. 延迟后重新打开麦克风；
4. 连续多次失败后才停止自动续听并提示手动补充。

### 3. 避免系统识别器半占用

下一轮开始前会检测 `_speech.isListening`，如果仍处于占用状态，会先 `stop()` 并延迟一小段时间，再调用 `listen()`。

### 4. 用户提示优化

新增黄色提示卡，说明部分手机系统语音识别不支持长时间连续听写，建议一句一停，漏字可继续补一句或手动编辑。

## 注意

当前仍然基于 Android 系统 SpeechRecognizer / speech_to_text 插件。它不是微信那种“录音文件 + 云端 ASR”的完整语音消息方案，所以不同 ROM、Google 服务状态、系统语音服务版本会影响识别质量。

如果后续要做到真正聊天软件级稳定，建议新增：

- 录音插件；
- 本地保存音频片段；
- 云端 ASR，如讯飞、百度、腾讯云、阿里云、Whisper/OpenAI-compatible ASR；
- 返回逐句文本后再进入当前饮食确认页。
