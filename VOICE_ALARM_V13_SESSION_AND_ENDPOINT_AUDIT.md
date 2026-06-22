# V13 语音会话与端点检测补充审计

本轮继续检查 v12 后的真实语音体验，重点修复以下遗漏：

1. 云识别模式下误设置 `listening=true`
- 问题：Microsoft/讯飞云识别使用独立录音线程，不依赖 Android `SpeechRecognizer`。但 TTS 结束、barge-in 恢复等路径仍会调用 `listenAgain()`。
- 旧逻辑在 `recognizer == null` 时仍可能把 `listening=true` 置上，形成一个“假监听状态”，从而阻塞后续恢复逻辑。
- 修复：`listenAgain()` 现在会先判断是否为云 STT 配置；云模式只检查/恢复云识别线程，不再创建假 native listening 状态。

2. 云识别线程重启存在旧线程复活风险
- 问题：`cloudSttActive` 是全局布尔值。旧云识别线程被 stop 后，如果新线程快速启动并把 `cloudSttActive=true`，旧线程可能继续跑一轮，导致重复录音/重复识别。
- 修复：新增 `cloudSttSession` 会话代号。每次 stop/start 都递增，录音线程和识别线程只处理自己所属会话的数据，旧线程即使晚返回也会被丢弃。

3. AI 请求卡死时，暂存语音可能长期不处理
- 问题：用户在 AI 思考时继续说话会进入 `pendingAiUserText`。如果 AI 请求超时、网络卡死或回调异常，暂存语音可能一直等不到处理时机。
- 修复：新增 AI 请求 watchdog。超过约 70 秒自动释放 `aiBusy`，恢复语音识别，并尝试处理暂存语音；迟到的旧 AI 响应会被 requestSeq 忽略。

4. 暂存语音缺少独立兜底处理
- 问题：`pendingAiUserText` 主要依赖 AI 播报结束后处理。如果 TTS 异常、播报状态异常或没有进入播报阶段，仍可能滞留。
- 修复：新增 `pendingAiWatchdogRunnable`，18 秒后若系统已空闲，会自动继续处理暂存语音。

5. 本地 VAD 太容易被单帧噪声触发
- 问题：只要一帧能量超过阈值就启动云识别，容易把碰撞声、环境尖峰或外放尾音当作用户开口。
- 修复：常规场景要求连续 2 个 speech hit 才确认真人语音；播报结束交接窗口仍允许 1 个 hit，避免截掉用户刚接话的第一个字。pre-roll 会保留开头音频。

6. 设置页暴露的端点参数不完整
- 问题：v10 已保存 `possiblyCompleteSilenceMs`、`partialFallbackDelayMs`、`semanticExtraWaitMs`，但 UI 只暴露部分参数，用户无法调优“可能说完”“partial 兜底”“语义额外等待”。
- 修复：语音句段提交策略卡片新增：
  - 可能说完静音
  - Partial 兜底等待
  - 语义额外等待
  并加入和完整静音/最终提交等待的联动约束。

受限说明：当前源码包仍缺少 `android/gradle/wrapper/gradle-wrapper.jar`，因此无法在本环境完成完整 Gradle APK 编译。已完成关键 Kotlin/Dart 括号结构、Manifest XML 和 zip 根目录结构检查。
