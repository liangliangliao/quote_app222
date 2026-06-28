# Voice Alarm chat pipeline v11 - auto-arm voice-shape gate

## Problem proven by device log

The user did not speak, but v10 still logged:

- `batch.vad.speechStart`
- `autoStart=true`
- `startHits=12`
- `startWindowMs=439`
- `rms=1768`, `peak=4282`

That proves v10 still used energy-only VAD to confirm a user turn. Energy-only VAD cannot distinguish room noise / mechanical taps / residual echo from a real user utterance.

## v11 fix

Pipeline marker:

```text
chat_input_v11_auto_arm_voice_shape_20260628
```

Changes:

1. Auto listening still opens the microphone automatically.
2. Before confirmation, frames stay as short pre-roll only; no submit-ready user utterance is created.
3. Auto start now requires three gates:
   - higher energy floor,
   - longer continuous start window,
   - voice-shape check: zero-crossing range, crest factor, and short-term voiced periodicity.
4. Candidate/activity frames no longer set `batchHasSpeech` and no longer enable manual submit as if there is user audio.
5. UI now says `自动监听待命：检测到声音输入，尚未确认是用户说话；尚未建立待提交录音...` until the gate is passed.
6. VAD logs include diagnostic fields:
   - `autoStartEnergy`
   - `autoStartVoiceLike`
   - `voiceLikeHits`
   - `strongVoiceLikeHits`
   - `rejectedHits`
   - `zcr`
   - `voicedScore`

## Expected behavior

When nobody speaks, logs should remain:

```text
speechStarted=false
cachedSeconds=0.0
autoStartVoiceLike=false
```

A real start should only appear as:

```text
batch.vad.speechStart | confirmed user speech start | mode=auto_armed_voice_shape_manual_send_semantics
```

## Important limitation

No single-microphone energy/VAD implementation can identify "the owner/user" versus another person, a TV, or a speaker producing speech-like sound. v11 reduces false starts from non-speech energy, but if the environment contains actual speech-like audio, the only reliable product solution is a tap/hold/manual trigger, wake phrase, or server-side speech confirmation.
