# Anti-Template & Method-Effect Validator

Fail and rerun if any of the following occurs:
- SCK produces only explanation text and no downstream state/decision change where a change is warranted.
- Different gaps/hypotheses produce near-identical next actions without case-specific mechanisms.
- “Why this step” cannot trace Goal -> KeyGap -> SubGoal -> OperatorMechanism.
- Strategy options are only labels such as scout/push/wait without resources, risks, switch signals, and stop-loss.
- Reality contradicts prediction but only wording changes.
- The user is asked to fill analysis fields AI could derive.

- A required MEC gate fired but no MethodEvent/state effect was recorded.
- UI shows a method/philosophy card that has no relationship to current ProblemState, decision, or reality test.
- More method cards are shown than necessary, causing feature-sprawl instead of a single problem-solving chain.
