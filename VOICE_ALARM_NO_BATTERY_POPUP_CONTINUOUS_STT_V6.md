# Voice Alarm V6：取消保存时电量页弹窗 + 连续语音不丢段修复

## 1. 保存闹钟时不要弹出系统电量页面

### 问题
V5 在 `_schedule()` 保存闹钟时，如果发现应用未忽略电池优化，会立即调用：

```dart
requestIgnoreBatteryOptimizations
```

在部分国产 ROM 上，这会直接跳转到“耗电详情/省电策略”页面，打断保存流程。用户只是保存闹钟，不应该被强制带到系统电量页面。

### 修复
文件：`lib/voice_alarm/voice_alarm_page.dart`

已移除保存闹钟时的强制跳转：

- 不再调用 `requestIgnoreBatteryOptimizations()`；
- 只做非阻断状态检查；
- 未设置“无限制/允许后台运行”时仅 toast 提醒；
- 闹钟仍继续保存和注册。

这样保存闹钟不会再自动弹出系统电量页。

## 2. 连续说一大段话时，分段识别可能漏内容

### 根因
原 Microsoft STT 是串行结构：

```text
录一段音频 -> 停止录音 -> 请求云识别 -> 等返回 -> 再开始录下一段
```

如果用户连续说话，HTTP 请求期间麦克风其实是停止的，所以这段时间说的话会被漏掉。

### 修复
文件：`android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`

将 Microsoft STT 改为双线程队列模型：

```text
录音线程：持续录音 -> 切成 PCM 片段 -> 放入本地队列
识别线程：从队列按顺序取片段 -> 请求 Microsoft STT -> 得到文本 -> 进入统一文本缓冲
```

关键变化：

- 新增 `LinkedBlockingDeque<ByteArray>(16)` 作为本地音频队列；
- 网络识别慢时，录音线程仍继续工作；
- 队列满时尽量合并队尾片段，而不是静默丢弃最新语音；
- 识别结果仍进入统一 `speechBuffer`，通过重叠合并去重。

## 3. 分段文本如何避免漏字/乱拼

继续保留并增强原有文本合并机制：

- partial/final 片段都先进入 `speechBuffer`；
- 新片段与旧片段做包含关系判断；
- 判断首尾重叠，避免重复拼接；
- 云 STT final 片段等待时间从 `1400ms` 增加到 `2600ms`；
- 原生 STT final 片段等待时间从 `900ms` 增加到 `1800ms`；
- 非 final 片段等待时间增加到 `2200ms`。

这样用户连续表达时，不会太早把半句话提交给 AI。

## 4. 用户打断闹钟播报/AI 播报时避免丢内容

V5 为避免回声，`speaking=true` 时云 STT 会直接暂停录音，导致用户正在 AI 播报时插话容易丢。

V6 改为：

- 闹钟播报或 AI 播报期间仍允许短窗口收音；
- 录音能量阈值提高，降低扬声器回声误触发；
- 新增 `lastAssistantSpokenText`，AI 播报文本也参与回声过滤；
- 真正用户语音会被暂存，播报结束后继续处理。

## 5. 仍需注意

- 系统原生 `SpeechRecognizer` 本身不是可靠的真正连续流式识别，长句仍可能由系统切段；
- Microsoft REST STT 不是 WebSocket 实时流式接口，本次通过“录音队列 + 识别线程”尽量避免网络等待期间漏录；
- 若要进一步提升极限场景，可后续接入 Microsoft Speech SDK/流式 WebSocket 或本地 VAD + 长音频滚动窗口。

## 修改文件

- `lib/voice_alarm/voice_alarm_page.dart`
- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`

## 静态检查

- `AndroidManifest.xml` XML 解析通过；
- `VoiceAlarmActivity.kt` 括号数量检查通过；
- `voice_alarm_page.dart` 括号数量检查通过；
- 输出 zip 为非多级目录结构。
