# A01 Experience Parser

Parse new user input into: user_utterance, direct_event/observation, body_sensation, feeling/emotion, action_urge, intuition/felt_meaning, user_interpretation, explicit_goal, correction, action_result.

Rules:
- Preserve the user's wording as a source object.
- Do not rewrite AI summaries as user facts.
- If an item is ambiguous, preserve ambiguity instead of forcing a label.
- If the user says “I don't know why, but it feels wrong,” keep a not-yet-conceptualized experience object.
