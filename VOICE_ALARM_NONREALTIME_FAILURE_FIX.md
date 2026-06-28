# 语音闹钟非实时语音模式失败修复

## 背景

用户反馈非实时语音模式仍然无法稳定识别和转文字，表现为：说了话但不自动提交、手动提交后仍返回空、页面只显示“未得到有效文字”而无法判断是没录音还是服务商失败。

## 核心修复

1. **AudioRecord 录音源降级修复**
   - 旧实现默认依赖 `VOICE_RECOGNITION` / `VOICE_COMMUNICATION`。
   - 部分 Android 设备在闹钟、TTS、音频焦点或系统语音增强开启时，会让这些 source 初始化失败或过度抑制用户声音。
   - 新实现按顺序尝试：`VOICE_COMMUNICATION -> VOICE_RECOGNITION -> MIC` 或 `VOICE_RECOGNITION -> MIC`。
   - 普通非实时录音不再默认开启 AEC/NS/AGC，避免噪声抑制把用户说话也压掉。

2. **配置缺失时不再假装进入非实时模式**
   - 旧实现：选择非实时 + 云服务商配置缺失时，界面还是非实时，但内部可能回退到系统实时识别，造成“按钮无效/无结果”的错觉。
   - 新实现：非实时服务商配置缺失时，直接在页面显示配置错误，不启动伪模式。

3. **xAI language 参数修复**
   - xAI STT 的 `language` 参数主要用于支持语言的格式化。
   - 旧实现会把 `zh-CN` 等不在 xAI STT 格式化支持列表里的值直接传给接口，可能导致请求失败。
   - 新实现只在 language 属于 xAI 官方支持列表时发送 `language + format=true`；不支持时省略该参数，让服务端自动识别。

4. **服务商失败原因可见**
   - Microsoft 解析 `NBest.Display / Lexical / ITN`，并在 `RecognitionStatus != Success` 时显示状态。
   - 讯飞 WebSocket 非 0 code / 连接失败会把错误带回页面。
   - 空文本时页面会显示已提交音频秒数、peak、rms 和服务商错误摘要，方便判断是录音无声还是接口失败。

5. **手动提交诊断增强**
   - 手动点击会显示当前缓存录音秒数。
   - 麦克风初始化失败、权限/系统占用会明确显示，而不是只提示“未检测到有效声音”。

## 修改文件

- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`

## 验证建议

1. 先使用 Microsoft 或讯飞非实时模式测试中文长句。
2. 点击手动提交后观察页面：
   - 如果 peak/rms 很低，说明录音链路仍未收到声音。
   - 如果有服务商 HTTP/code 错误，说明录音已经提交，问题在服务商配置/接口参数/权限/额度。
3. xAI 对中文支持需要以 xAI 当前 STT 能力为准；本修复避免发送不被支持的 language 参数。
