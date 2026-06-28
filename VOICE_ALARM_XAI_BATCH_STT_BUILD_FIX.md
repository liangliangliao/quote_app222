# VOICE_ALARM_XAI_BATCH_STT_BUILD_FIX

## 修复内容

根据 release 构建日志：

```
android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt:1074:68:
'fun of(array: ByteArray, offset: Int, byteCount: Int): ByteString' is deprecated. moved to extension function.
```

项目 release Kotlin 编译将该 Okio 废弃 API 提示作为编译失败处理。已将 `ByteString.of(frame, 0, frame.size)` 改为 Okio Kotlin 扩展函数：

```kotlin
import okio.ByteString.Companion.toByteString

fun sendFrame(frame: ByteArray) { webSocket?.send(frame.toByteString(0, frame.size)) }
```

## 涉及文件

- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`

## 影响范围

仅修复 xAI 实时语音识别 WebSocket 音频帧发送处的 ByteString 构造方式，不改变实时/非实时识别逻辑。
