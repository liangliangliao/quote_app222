# Minimal System State Schema

```json
{
  "problem_id": "...",
  "state_version": 12,
  "need": "...",
  "current_state": [],
  "goal_state": {"statement":"...","success_criteria":[],"termination":[]},
  "facts": [],
  "unknowns": [],
  "hypotheses": [],
  "constraints": [],
  "gaps": [],
  "key_gap": "...",
  "subgoals": [],
  "active_subgoal": "...",
  "candidate_operators": [],
  "active_operator": {"target_gap":"...","mechanism":"...","preconditions":[],"prediction":"..."},
  "campaign": {"id":"...","resources":{},"fog":[],"strategy_options":[],"preferred_strategy":"..."},
  "epistemic_profile": {},
  "last_reality_result": null,
  "backtrack_history": [],
  "active_method_events": [],
  "prompt_version": "rev5.2"
}
```
