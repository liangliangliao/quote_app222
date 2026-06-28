# VOICE_ALARM_CHAT_PIPELINE_V10_AUTO_ARM_STRICT_START

- Version marker: chat_input_v10_auto_armed_strict_start_20260628
- Fixes false auto-start when nobody speaks.
- Auto-armed microphone still opens automatically, but it does not create/upload an utterance until strong speech evidence is seen for multiple consecutive frames and at least a short start window.
- Adds VAD logs: autoStart, startHits, requiredHits.
- Prevents low-level background/echo/noise from setting speechStarted=true and creating long empty recordings.
