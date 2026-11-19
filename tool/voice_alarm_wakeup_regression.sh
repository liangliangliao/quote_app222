#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
voice_test_dir="$(mktemp -d)"
trap 'rm -rf "$voice_test_dir"' EXIT
voice_deps="${VOICE_TEST_DEPS:-$voice_test_dir/deps}"
mkdir -p "$voice_deps"
download() {
  local name="$1" path="$2" digest="$3"
  if [ ! -f "$voice_deps/$name.jar" ]; then
    curl --fail --silent --show-error --location --retry 2 "https://repo.maven.apache.org/maven2/$path" -o "$voice_deps/$name.jar"
  fi
  echo "$digest  $voice_deps/$name.jar" | sha256sum --check --status
}
download okhttp com/squareup/okhttp3/okhttp/4.12.0/okhttp-4.12.0.jar b1050081b14bb7a3a7e55a4d3ef01b5dcfabc453b4573a4fc019767191d5f4e0
download okio com/squareup/okio/okio-jvm/3.6.0/okio-jvm-3.6.0.jar 67543f0736fc422ae927ed0e504b98bc5e269fda0d3500579337cb713da28412
download json org/json/json/20240303/json-20240303.jar 3cf6cd6892e32e2b4c1c39e0f52f5248a2f5b37646fdfbb79a66b46b618414ed
voice_classpath="$voice_deps/okhttp.jar:$voice_deps/okio.jar:$voice_deps/json.jar"
"${KOTLINC:-kotlinc}" \
  android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmWakeupClient.kt \
  android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmSpeechPolicy.kt \
  android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmTextChunks.kt \
  android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmCommands.kt \
  android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmPlaybackQueue.kt \
  android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmTurnBuffer.kt \
  android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmWebSearch.kt \
  android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmXaiTranscript.kt \
  android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmIflytekTranscript.kt \
  android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmNativeTurn.kt \
  android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmAiClient.kt \
  android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmWakeSession.kt \
  tool/tests/VoiceAlarmAdaptiveTest.kt \
  tool/tests/VoiceAlarmLiveTest.kt \
  tool/tests/VoiceAlarmWakeupTest.kt \
  -classpath "$voice_classpath" -include-runtime -d "$voice_test_dir/wakeup-tests.jar"
java -cp "$voice_test_dir/wakeup-tests.jar:$voice_classpath" com.example.quote_app.VoiceAlarmWakeupTestKt

java -cp "$voice_test_dir/wakeup-tests.jar:$voice_classpath" com.example.quote_app.VoiceAlarmLiveTestKt

java -cp "$voice_test_dir/wakeup-tests.jar:$voice_classpath" com.example.quote_app.VoiceAlarmAdaptiveTestKt
