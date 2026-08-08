# Evaluation reference (`adk eval`)

Read when writing an evalset, tuning thresholds, or wiring ADK evaluation into CI.

## CLI

> Source: https://adk.dev/evaluate/

```
adk eval <AGENT_MODULE_FILE_PATH> <EVAL_SET_FILE_PATH> [--config_file_path=<PATH>] [--print_detailed_results]
```

- `AGENT_MODULE_FILE_PATH` should point to the `__init__.py` containing a `root_agent`.
- Multiple eval-set files can be specified.
- Filter to specific evaluations with colon syntax: `file.json:eval_1,eval_2`.

## Evalset file format

> Source: https://adk.dev/evaluate/

An evalset file contains multiple evaluation cases, each representing a distinct session:

- `eval_id` — unique session identifier
- `conversation` — array of multi-turn interactions with user content and expected responses
- `session_input` — initial state config (`app_name`, `user_id`, `state`)
- `intermediate_data` — expected tool trajectories and sub-agent responses

The docs reference the Pydantic-backed `EvalSet` schema at
`https://github.com/google/adk-python/blob/main/src/google/adk/evaluation/eval_set.py`.

## `.test.json` structure

> Source: https://adk.dev/evaluate/

```json
{
  "eval_set_id": "identifier",
  "eval_cases": [{
    "eval_id": "case_id",
    "conversation": [{
      "invocation_id": "uuid",
      "user_content": { "parts": [{"text": "query"}], "role": "user" },
      "final_response": { "parts": [{"text": "response"}], "role": "model" },
      "intermediate_data": {
        "tool_uses": [{"name": "tool", "args": {}}],
        "intermediate_responses": []
      }
    }],
    "session_input": { "app_name": "name", "user_id": "id", "state": {} }
  }]
}
```

`session_input.state` is how you seed prefixed state (`user:`, `app:`) for a case — use it instead of adding setup turns to the conversation.

## Metrics

> Source: https://adk.dev/evaluate/

**Defaults, applied when no criteria are specified**:

| Metric | Default threshold | Meaning |
|---|---|---|
| `tool_trajectory_avg_score` | **1.0** | Requires 100% tool-trajectory match |
| `response_match_score` | **0.8** | Allows a margin of error in responses |

The 1.0 trajectory default is strict — a single extra or reordered tool call fails the case. Lower it deliberately when the agent legitimately has multiple valid paths, rather than loosening the response threshold.

**Additional / LLM-judged criteria**: `final_response_match_v2`, `hallucinations_v1`, `safety_v1`, with multi-turn variants available for conversations.

## Threshold configuration

> Source: https://adk.dev/evaluate/

`test_config.json`:

```json
{
  "criteria": {
    "tool_trajectory_avg_score": 1.0,
    "response_match_score": 0.8
  }
}
```

Thresholds can also be adjusted interactively via sliders in the web UI when running evaluations — useful for finding a workable threshold before committing it to `test_config.json`.

## Programmatic evaluation (pytest)

> Source: https://adk.dev/evaluate/

```python
from google.adk.evaluation.agent_evaluator import AgentEvaluator
import pytest

@pytest.mark.asyncio
async def test_agent():
    await AgentEvaluator.evaluate(
        agent_module="agent_name",
        eval_dataset_file_path_or_dir="tests/eval_file.test.json"
    )
```

`eval_dataset_file_path_or_dir` accepts a directory, so a suite can grow file-by-file without changing the test.

For eval methodology that is not ADK-specific — suite design, judge prompts, regression gating, statistical confidence — use the `evals` sibling skill.

## Sources

- https://adk.dev/evaluate/

Fetched: 2026-08-05
