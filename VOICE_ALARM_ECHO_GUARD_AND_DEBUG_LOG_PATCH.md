# Voice Alarm Echo Guard and Debug Log Patch

本次修复重点：不再把非实时模式当作“边播报边收音”的场景处理。

## 核心变更

1. 非实时模式在闹钟播报 / AI TTS 播报期间硬暂停麦克风：
   - 释放 `AudioRecord`
   - 清空当前缓存
   - 不提交任何播报期间录到的音频
   - 播报结束并冷却后重新开始录用户语音

2. 增加初始闹钟播报保护窗口：
   - 在服务广播到达前，先进入非实时麦克风保护状态
   - 避免 Activity 刚打开时抢先录下第一句闹钟播报

3. 增加统一调试日志：
   - 新增 `VoiceAlarmDebugLog.kt`
   - Activity 和 Service 都写入同一个日志文件
   - 日志路径：`Android/data/<package>/files/voice_alarm_logs/voice_alarm_YYYYMMDD.log`
   - 同时写入 Logcat：tag 为 `VoiceAlarmDebug`

## 已记录的关键事件

- 闹钟服务启动、闹钟语音播报开始/结束
- 实时/非实时 STT 启动、录音源初始化、AudioRecord 释放
- 非实时录音分段、手动提交、自动提交、队列提交
- Microsoft / xAI / 讯飞识别请求、HTTP / WebSocket 结果、空文本、异常
- 识别结果是否被判定为播报回声
- 用户语音进入 AI 前的文本
- AI 请求开始、HTTP 结果、AI 返回文本
- AI TTS 开始/结束

## 调试建议

复现一次后拉取日志：

```bash
adb shell run-as com.example.quote_app ls files/voice_alarm_logs
adb shell run-as com.example.quote_app cat files/voice_alarm_logs/voice_alarm_$(date +%Y%m%d).log
```

部分设备不允许 `run-as` 时，可查看外部 app 文件目录：

```bash
adb shell ls /sdcard/Android/data/com.example.quote_app/files/voice_alarm_logs/
adb shell cat /sdcard/Android/data/com.example.quote_app/files/voice_alarm_logs/voice_alarm_$(date +%Y%m%d).log
```

Logcat：

```bash
adb logcat -s VoiceAlarmDebug
```
