# Voice Alarm batch STT strict VAD / iFlytek low-quality transcript fix

根据用户日志继续修复非实时语音识别失败问题。

## 根因

日志显示 App 不是完全没录音，而是：

- 低能量环境声也被判定为“已检测到用户说话”；
- `softSpeech` 会启动/刷新自动提交端点，导致非实时录音从很早的底噪开始累计；
- 提交给讯飞的音频前面包含较长静音/噪声，讯飞 IAT WebSocket 可能先返回 `嗯。` 并结束，后面的真实语音没有形成有效文本；
- 讯飞返回 `ls=true`/错误后，客户端仍继续发送音频帧，会出现 `invalid handle` / `Broken pipe`；
- `嗯。` 这类 filler 文本被当成有效用户输入进入 AI，造成用户感觉“没有正常转文字”。

## 修复

1. 正式“用户说话”门限提高：
   - speech RMS: `max(220, noiseRms * 6.0)`
   - speech peak: `max(1400, noiseRms * 28.0)`

2. `softSpeech` 不再确认用户说话，也不再刷新静音倒计时。
   - 软声音只用于页面提示“检测到声音输入，尚未确认是用户说话”。
   - 自动提交只由正式 speech 触发。

3. 静音端点只看正式 speech 的最后时间。
   - 低能量底噪不会继续把倒计时重置到 5 秒。

4. 提交前裁剪音频更严格。
   - trim RMS: `max(180, floor * 5.5)`
   - trim peak: `max(1100, floor * 24)`
   - 避免把长时间前导底噪送给讯飞。

5. 讯飞 WebSocket 收到 `ls=true` 或错误后停止继续发送帧。
   - 避免 `invalid handle` / `Broken pipe` 风暴。

6. 低质量短文本过滤。
   - 长音频只返回 `嗯`、`啊`、`哦` 等 filler 时，不再当作有效用户输入进入 AI。
   - 会尝试原始音频重试；仍是 filler 则显示为无有效转写并保留重试。

## 修改文件

- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`
