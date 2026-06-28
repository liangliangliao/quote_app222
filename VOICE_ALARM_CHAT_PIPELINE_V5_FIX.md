# 语音闹钟非实时识别 v5 修复说明

本版继续修复非实时语音识别与聊天 App 语音输入逻辑不一致的问题。

## 修复目标

目标流程改为：

1. 闹钟/AI 播报期间的扬声器声音不写入 STT 音频。
2. 用户插话时先停止/延后播报，再从干净音频重新开始录当前用户 utterance。
3. 一次用户 utterance 录完后，只提交这一整段音频给 STT。
4. STT 最终文字返回后，再发送给 AI。
5. 页面不再显示“录音分段/排队”类旧文案。

## 新版本标记

日志中应出现：

```text
pipeline=chat_input_v5_chat_app_strict_20260627
```

如果仍然出现 v3/v4 标记，说明手机上运行的不是本版 APK。

## 关键修复

- Service 播报开始/结束广播现在携带播报文本，Activity 可以用它做文本级回声过滤。
- 新增 `lastAlarmSpokenText`，用于识别并过滤闹钟播报被 STT 转写出的文字。
- 新增常见闹钟提示词模式过滤，避免“早安/早上好/新的一天/慢慢起身/喝口水/整理好心情”等播报内容被作为用户输入发送给 AI。
- 删除用户可见的“录音分段/排队”文案，统一为“当前完整录音/最终文字”。
- 保留完整录音单次上传，不恢复本地 chunk retry 或 rolling submit。

## 期望日志

正常应看到：

```text
batch.record.segment | complete utterance segment ready | pipeline=chat_input_v5_chat_app_strict_20260627
batch.singleUpload.start | upload one complete utterance audio to STT
batch.result | batch STT text returned
```

不应再看到：

```text
batch.capture.reopenForEchoGuardSubmit
batch.record.rollingSubmit
batch.chunk.retry.error
录音分段正在识别/排队
```
