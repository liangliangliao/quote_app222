# Voice Alarm Chat Pipeline V9 — Auto-Armed Single-Utterance Mode

目标：采用“模式 A”的语义，但保留自动能力。

也就是：用户不需要手动点击开始录音；非实时模式空闲时自动打开麦克风待命。但它不再像后台连续监听器那样无限缓存空白音频，而是更接近 ChatGPT/Grok/Claude 语音输入框：

1. 空闲时自动待命。
2. 确认用户开始说话后，才创建本轮 `user_utterance` 缓冲。
3. 开口前只保留短 pre-roll，避免漏掉第一个字。
4. 用户说完后，静音 5 秒自动提交。
5. 上传给 STT 的只有这一条完整 utterance。
6. 识别、AI 回复、App 自己播报期间暂停录音，不排队、不合并、不把播报声写进 STT。

## Pipeline marker

```text
chat_input_v9_auto_armed_single_utterance_20260628
```

## Expected logs

```text
batch.start | Non-realtime STT started | pipeline=chat_input_v9_auto_armed_single_utterance_20260628
batch.vad.speechStart | confirmed user speech start | mode=auto_armed_manual_send_semantics
batch.record.autoSubmit | user speech silence timeout reached
batch.record.segment | complete utterance segment ready | pipeline=chat_input_v9_auto_armed_single_utterance_20260628
batch.singleUpload.start | upload one complete utterance audio to STT
```

## What should not happen

```text
batch.record.rollingSubmit
batch.chunk.retry.*
录音分段正在识别/排队
```

## Important behavior change from V8

V8 still cached audio from microphone-open time and later sliced from speech start. V9 changes the model:

- Before confirmed speech: keep only short pre-roll, no long empty draft is stored.
- At confirmed speech: reset the utterance buffer, copy pre-roll into it, then write current and later frames.
- At silence endpoint/manual send: optionally compact long silent spans, then upload once.

This better matches an auto-armed chat voice input box rather than a continuous background listener.
