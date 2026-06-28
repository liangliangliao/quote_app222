# 非实时语音 VAD、裁剪与 AI 提交修复

本补丁针对日志中暴露的两个主要问题继续修复：

1. **转写内容不正确 / 只转出短片段**
   - 发现旧裁剪逻辑会把 18 秒左右的录音裁成 1~2 秒片段，导致讯飞只返回“就现在已经”“现在已经那个”等错误短文本。
   - 新增保守音频选择：当本地裁剪结果明显短于原始语音段时，丢弃裁剪结果，改用完整语音段提交。
   - 新增低质量结果过滤：长音频只返回少量泛化词、填充词或短片段时，不再作为有效用户输入进入 AI。
   - 非实时 STT 的 AI 纠错默认关闭；即使用户开启，纠错结果如果明显改写或缩短原文，也会被丢弃。

2. **用户说完 5 秒后没有自动提交 / AI 没返回**
   - 正式“用户说话”门限再次收紧，避免 rms≈200~300、peak≈600~900 的环境声持续刷新静音倒计时。
   - 滚动分段只在最近仍检测到真实 speech 帧时触发；如果用户已经停顿，则交给 5 秒静音端点提交。
   - 如果已有有效转写长期被后续空片段/失败片段卡住，超过保护时间会强制放行给 AI，避免一直显示“等待后续分段完成”。

新增关键日志：

- `batch.trim.discardDestructive`
- `batch.trim.keepFullForShort`
- `batch.record.discardShortTrim`
- `batch.correct.discardRewrite`
- `batch.aiHold.forceRelease`

修改文件：

- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`
- `lib/voice_alarm/voice_alarm_page.dart`
