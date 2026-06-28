# Voice Alarm chat_pipeline_v13_reference_vad_gate

## 用户反馈
v12 仍然在用户没有说话时触发 `batch.vad.speechStart`，截图中可以看到：

- `rms=673`
- `peak=1759`
- `speechStarted=true`
- `cachedSeconds=8.5`
- 当前帧 `zcr=0` / `voicedScore=0`

这说明上一版仍把能量型输入当成了“用户说话”。

## v13 修复

v13 改为参考聊天 App / WebRTC / 服务端 VAD 的分层思路：

1. **能量只作为候选，不再直接确认开口**。
2. **自动开口需要多帧人声形态确认**：过零率、峰均比、短时周期性必须共同满足。
3. **speechStarted=true 之后不再用纯 RMS/peak 刷新静音倒计时**，避免持续环境声让倒计时永远归零。
4. **自动提交前做二次校验**：如果缓存音频里没有足够 speech-like frames，整段丢弃并回到自动待命。
5. 新增日志：
   - `pipeline=chat_input_v13_reference_vad_gate_20260628`
   - `endpointVoiceLikeHits`
   - `batch.vad.falseStartDiscarded`

## 预期日志

无人说话时：

```text
speechStarted=false
cachedSeconds=0.0
state=检测到声音输入，尚未确认是用户说话
```

若环境声误触发了候选但不像完整人声，应看到：

```text
batch.vad.falseStartDiscarded
```

用户真实说话时：

```text
batch.vad.speechStart
mode=auto_armed_reference_vad_gate_manual_send_semantics
endpointVoiceLikeHits>=5
```

