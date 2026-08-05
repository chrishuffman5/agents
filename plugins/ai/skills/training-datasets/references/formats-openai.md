# OpenAI hosted fine-tuning: dataset formats and guidance

Read when producing JSONL for an OpenAI fine-tuning job (SFT or DPO), or when deciding how many examples to collect.

> Sourcing note: as of 2026-08-05 `platform.openai.com/docs/guides/*` 301-redirects to
> `developers.openai.com/api/docs/guides/*`. Both URLs are cited per section; the redirect target is
> where content was retrieved, and `platform.openai.com` is OpenAI's canonical pointer to it.

## Supervised fine-tuning (SFT) JSONL

> Source: https://platform.openai.com/docs/guides/supervised-fine-tuning
> Source: https://developers.openai.com/api/docs/guides/supervised-fine-tuning

One training example per line, using the chat-completions `messages` schema.

Per-line fields:

- `messages` — array of message objects, each with `role` (`user` / `assistant`, plus tool-calling roles) and `content`, or `tool_calls` on assistant messages.
- `tools` — optional array of tool/function definitions available to the model for that example.
- `parallel_tool_calls` — optional boolean controlling whether concurrent function calls are modeled.

Tool-calling example line:

```json
{
  "messages": [
    {"role": "user", "content": "What is the weather in San Francisco?"},
    {
      "role": "assistant",
      "tool_calls": [
        {
          "id": "call_id",
          "type": "function",
          "function": {"name": "get_current_weather", "arguments": "..."}
        }
      ]
    }
  ],
  "parallel_tool_calls": false,
  "tools": []
}
```

Multi-turn conversations are trained by putting multiple user/assistant pairs inside the `messages` array of a **single** example line — not by splitting turns across lines.

Upload the file with purpose `"fine-tune"`.

### Documented size guidance (SFT)

- Minimum: **10 examples** — a hard floor for submitting a job.
- Recommended starting point: **50** well-crafted examples. OpenAI notes visible improvements are achievable with as few as 50–100 examples, though the ideal number varies by use case.

## Direct Preference Optimization (DPO) JSONL

> Source: https://platform.openai.com/docs/guides/direct-preference-optimization
> Source: https://developers.openai.com/api/docs/guides/direct-preference-optimization

Three top-level fields per line — this is **not** the SFT shape:

- `input` — object containing `messages` (the prompt, a normal messages array), `tools` (array, may be empty), and `parallel_tool_calls` (boolean).
- `preferred_output` — the ideal assistant response, as a one-element array holding a single assistant message object.
- `non_preferred_output` — the suboptimal response, same shape.

```json
{
  "input": {
    "messages": [{"role": "user", "content": "..."}],
    "tools": [],
    "parallel_tool_calls": true
  },
  "preferred_output": [{"role": "assistant", "content": "..."}],
  "non_preferred_output": [{"role": "assistant", "content": "..."}]
}
```

### Constraints

- Only one-turn conversations per example: the preferred and non-preferred messages must be the **last** assistant message. Prior turns go in `input.messages`; the two output fields hold only the final differing assistant turn.
- Best-suited tasks per the docs: summarization that emphasizes particular relevant content, and generating conversational responses matching a desired tone/style.

### `beta` hyperparameter

Set via the `method` field when creating the DPO job. Float in `[0, 2]`. Higher → more conservative (stays closer to the reference model); lower → more aggressive alignment to the preference data. Default `auto` (platform-selected).

No explicit minimum dataset size is documented for DPO as of 2026-08-05. Treat the SFT minimum (10) as a practical floor and prefer far more, given DPO's higher noise sensitivity.

## Dataset-focused best practices

> Source: https://platform.openai.com/docs/guides/fine-tuning-best-practices
> Source: https://developers.openai.com/api/docs/guides/fine-tuning-best-practices

- **Quality over quantity.** A smaller amount of high-quality data outperforms a larger amount of low-quality data.
- **Estimating dataset size.** Fine-tune on the full dataset and on half of it, then compare eval performance. If the full-data run is meaningfully better, doubling the dataset again is likely to keep helping.
- **Consistency check.** Verify inter-annotator / inter-example agreement. If multiple people would write different "correct" completions for the same prompt, achievable model performance is capped accordingly.
- **Format alignment.** Every training example must be in the exact format expected at inference time — same structure, same system-prompt conventions.
- **Content sufficiency.** Each example must contain all information needed to produce its target output. The model cannot infer missing context, and gaps here cause hallucination.
- **Review for propagated errors.** Grammar, logic, or style problems in examples get learned and reproduced. Proofread before training.
- **Class balance must match inference-time distribution.** If training data is 60% refusals but only ~5% of real queries should be refused, expect over-refusal.
- **Split data into train/test early.** Submitting both a training and a held-out validation/test file lets the platform report per-step statistics comparing training vs test performance during the job — the main signal for judging convergence and overfitting.
- **Hyperparameter iteration guided by dataset behavior.** Increase epochs by 1–2 if the model isn't sufficiently following the training data (especially classification-style tasks); decrease epochs if output diversity drops too much. Increase learning rate if convergence stalls. Larger batch size trades slower training for more stable gradient estimates.
- **Full instructions in every example.** Don't rely on the model to generalize a shortened instruction from many examples — write the complete instruction/context in each example so it learns from direct demonstration.

## Sources

- https://platform.openai.com/docs/guides/supervised-fine-tuning
- https://developers.openai.com/api/docs/guides/supervised-fine-tuning
- https://platform.openai.com/docs/guides/direct-preference-optimization
- https://developers.openai.com/api/docs/guides/direct-preference-optimization
- https://platform.openai.com/docs/guides/fine-tuning-best-practices
- https://developers.openai.com/api/docs/guides/fine-tuning-best-practices

Fetched: 2026-08-05
