#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
voice_test_dir="$(mktemp -d)"
trap 'rm -rf "$voice_test_dir"' EXIT
"${KOTLINC:-kotlinc}" \
  android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmSpeechPolicy.kt \
  android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmPcmPump.kt \
  android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmCommands.kt \
  tool/tests/VoiceAlarmSpeechTest.kt \
  -include-runtime -d "$voice_test_dir/voice-tests.jar"
java -jar "$voice_test_dir/voice-tests.jar"
