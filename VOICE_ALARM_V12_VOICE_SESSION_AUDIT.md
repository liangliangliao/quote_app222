# V12 语音会话体验与状态机补充审计

## 本轮继续检查到的遗漏

### 1. 云 STT 的本地 VAD 缺少 pre-roll，会截掉开头音节
V11 已经解决了“播报结束后强抑制过长”的问题，但微软/讯飞云识别仍然是在本地 VAD 检测到能量后才开始写入/发送音频。
这会带来一个成熟语音产品常见问题：VAD 触发点通常晚于真实发声起点，用户刚开始说的第一个字/第一个音节可能已经过去了。

修复：
- 微软 PCM 录音增加 420ms 常规 pre-roll；
- 播报交接/回声场景增加 720ms pre-roll；
- VAD 一旦触发，先把触发前缓存的音频一起送去识别；
- 避免“我刚开口第一个字没了”的体验问题。

### 2. 讯飞流式识别也缺少 pre-roll
此前为了避免把 AI/TTS 播报声发给讯飞，代码在 VAD 未触发前不上传音频，这是正确方向；但它也会把真人说话开头切掉。

修复：
- 讯飞流式识别增加同样的 pre-roll 帧缓存；
- 首次检测到真人语音后，先按顺序发送 pre-roll 帧，再发送当前帧；
- 继续保持“不上传环境噪声/播报声”的策略。

### 3. AI 请求进行中时，用户又说话会被反复塞回 speechBuffer
V11 里如果 AI 正在请求中，`handleSpeech()` 会把新语音 append 回 `speechBuffer`，再定时提交。若 AI 请求还没结束，这段话会再次进入 `handleSpeech()`，又 append 回 buffer，可能形成重复等待、重复合并、甚至体验上像“说了但没处理”。

修复：
- 新增 `pendingAiUserText` 独立暂存区；
- AI 正在处理上一句时，用户新说的话不再回塞到 endpoint buffer；
- 当前 AI 播报完成/状态恢复后，自动处理 pending 用户语音；
- 避免“AI 忙时用户追加一句被吞掉或重复等待”。

### 4. 讯飞结束帧对 nullable WebSocket 调用不够稳
修复：
- 结束帧改为安全调用，避免极端连接失败情况下潜在空指针/编译风险。

## 修改文件
- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`

## 验证
- Kotlin 文件括号/括号数量静态检查通过；
- AndroidManifest.xml 解析通过；
- zip 包根目录直接包含项目文件，没有外层多级目录。

完整 Gradle 编译仍受限于源码包缺少 `android/gradle/wrapper/gradle-wrapper.jar`，当前环境无法下载 wrapper。
