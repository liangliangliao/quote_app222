# Voice Alarm Chat Pipeline v12 - Balanced Auto Arm

目标：修复 v11 过度收紧导致“用户明明说话但检测不到”的问题，同时保留自动待命模式。

关键变化：
- pipeline 标记：chat_input_v12_balanced_auto_arm_20260628
- 自动待命仍然不从打开麦克风时无限缓存；确认开口后才建立待提交录音。
- 将 v11 过高的自动开口能量门槛改为中等能量 + 声音形态 + 持续时间联合确认。
- requiredHits 从 22/28 调整为 14/20；最短确认窗口从 1100/1400ms 调整为 720/1000ms。
- 声音形态判断放宽到正常距离/偏小音量人声可通过，但仍要求 zcr/crest/voicedScore 的组合线索，避免单帧碰撞或白噪声直接确认。

预期日志：
- 用户说话时：batch.vad.speechStart，mode=auto_armed_balanced_manual_send_semantics
- 无人说话但有环境声时：自动监听待命/尚未确认是用户说话，speechStarted=false，cachedSeconds=0.0
