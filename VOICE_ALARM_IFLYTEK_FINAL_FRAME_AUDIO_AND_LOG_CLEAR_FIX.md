# 语音闹钟非实时识别：讯飞尾帧、调试音频与日志清空修复

本次修复针对用户反馈：非实时模式仍经常返回空文字、怀疑没有录到用户说话，以及日志页面缺少一键清空。

## 关键诊断

截图日志显示本段并不是完全没有录到音频：

- submittedBytes/originalBytes 约 613120 bytes
- duration 约 19.3 秒
- peak=6853
- rms=1015

这说明麦克风链路至少捕获到了有能量的 PCM。空文本更可能出现在“提交给服务商 / 服务商协议收尾 / 返回解析”阶段，尤其是讯飞非实时 WebSocket 批量送音频。

## 修复 1：讯飞非实时最后一帧携带真实音频

旧逻辑：

```text
真实音频：status=0 / status=1 / status=1 / ...
结束帧：status=2 + 空音频
```

这在部分情况下会让讯飞 IAT 返回空文本或收尾异常。

新逻辑：

```text
首帧：status=0 + 真实音频
中间帧：status=1 + 真实音频
最后一帧：status=2 + 最后一段真实音频
```

只有极短音频只有一帧时，才补一个空的 status=2 保证协议闭合。

## 修复 2：保存最近一次提交给 STT 的音频

每次非实时识别提交前，会保存最近一次提交音频：

```text
Android/data/<package>/files/voice_alarm_audio_debug/last_batch_stt.wav
Android/data/<package>/files/voice_alarm_audio_debug/last_batch_stt_original.wav
```

这样可以确认到底是：

- App 没录到用户声音；
- App 录到了但裁剪错误；
- App 录到了且文件可听，但服务商返回空。

日志中会写入 `batch.audio.saved`，包含 WAV 路径、pcmBytes、peak、rms。

## 修复 3：讯飞返回日志更细

新增日志：

- `stt.iflytek.batch.open`
- `stt.iflytek.batch.message`
- `stt.iflytek.batch.failure`
- `stt.iflytek.batch.closed`
- `stt.iflytek.batch.done`

如果仍返回空，会显示：

```text
讯飞未返回文字：messages=..., pieces=..., completed=..., finalWithAudio=...
```

## 修复 4：日志弹窗支持一键清空

“语音闹钟调试日志”弹窗新增按钮：

```text
清空日志
```

会删除当前 app 日志目录下的 `voice_alarm_*.log` 文件。

## 修改文件

- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`
- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmDebugLog.kt`
