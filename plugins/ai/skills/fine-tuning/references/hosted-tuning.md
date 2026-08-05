# Hosted Tuning: OpenAI and Vertex AI

Read when evaluating managed fine-tuning instead of self-hosted Unsloth, or when writing against the OpenAI fine-tuning API or Vertex AI Gemini supervised tuning. Facts as of 2026-08-05. Gaps are listed at the bottom and must not be filled from memory.

## OpenAI fine-tuning API

> Source: https://platform.openai.com/docs/guides/supervised-fine-tuning

**Platform status (2026-08-05):** OpenAI's fine-tuning platform is being wound down. It is "no longer accessible to new users"; existing users can still create training jobs "for the coming months," and already fine-tuned models remain servable for inference until their base model is deprecated. State this before recommending it for a new project.

`platform.openai.com/docs/guides/supervised-fine-tuning` and `platform.openai.com/docs/pricing` now 301-redirect to `developers.openai.com/api/docs/...` — same publisher and content, cited here under the original `platform.openai.com` paths.

### JSONL training-data schema

Upload a JSONL file where each line is one training example in chat format:

```json
{
  "messages": [
    { "role": "user", "content": "..." },
    { "role": "assistant", "content": "..." }
  ],
  "tools": [ ],
  "parallel_tool_calls": false
}
```

- One complete JSON object per line.
- Minimum 10 lines (the dashboard/API hard floor). Best-practices guidance separately recommends 50+ examples as a realistic starting point for meaningful results.
- Supports the full chat-completions structure: optional `tools` definitions and function/tool calls embedded in the conversation, not just plain user/assistant text.

### API workflow

1. Upload the dataset file — `POST https://api.openai.com/v1/files` with `purpose="fine-tune"` and the JSONL attached.
2. Create the job — `POST https://api.openai.com/v1/fine_tuning/jobs`. Required parameters:
   - `training_file` — the file ID from step 1.
   - `model` — base model ID to tune (e.g. `gpt-4.1-nano-2025-04-14`).
   - `method` — defaults to supervised fine-tuning (SFT); other methods (e.g. reinforcement/preference-based) are configured through this same field.
3. Poll status — `GET https://api.openai.com/v1/fine_tuning/jobs/{job_id}`.
4. List checkpoints produced during training — `GET https://api.openai.com/v1/fine_tuning/jobs/{job_id}/checkpoints`.
5. On completion, read `fine_tuned_model` off the job object and call it via Chat Completions or the Responses API like any other model ID.

### Hyperparameters

Illustrative standard configuration referenced in the guide:

- `n_epochs`: 10
- `batch_size`: 1
- `learning_rate_multiplier`: 1.0

These are illustrative walkthrough values, not universal minimums. OpenAI auto-selects hyperparameters per job unless overridden. Best-practices guidance: raise epochs if the model isn't matching the training data closely; lower epochs if output diversity collapses; raise the LR multiplier if the run isn't converging.

### Pricing (per 1M tokens)

> Source: https://platform.openai.com/docs/pricing

| Model | Training | Input (standard) | Cached input | Output (standard) |
|---|---|---|---|---|
| o4-mini-2025-04-16 | $100/hour | $4.00 | $1.00 | $16.00 |
| o4-mini (data sharing enabled) | $100/hour | $2.00 | $0.50 | $8.00 |
| gpt-4.1-2025-04-14 | $25.00 | $3.00 | $0.75 | $12.00 |
| gpt-4.1-mini-2025-04-14 | $5.00 | $0.80 | $0.20 | $3.20 |
| gpt-4.1-nano-2025-04-14 | $1.50 | $0.20 | $0.05 | $0.80 |
| gpt-4o-2024-08-06 | $25.00 | $3.75 | $1.875 | $15.00 |
| gpt-4o-mini-2024-07-18 | $3.00 | $0.30 | $0.15 | $1.20 |

- o4-mini training is metered by wall-clock compute time ($/hour); all other listed models bill per token for training.
- Inference discounts are available when data sharing is enabled at job creation — the o4-mini row shows the concrete shape (roughly half price on input and output).
- Reinforcement fine-tuning: tokens consumed for model-graded scoring during RFT bill at the grading model's normal per-token rate, on top of the job's own cost.

## Vertex AI supervised tuning for Gemini

> Source: https://cloud.google.com/vertex-ai/generative-ai/docs/models/gemini-supervised-tuning

Google's Vertex AI generative-AI docs 301-redirect from `cloud.google.com/vertex-ai/generative-ai/docs/...` to `docs.cloud.google.com/vertex-ai/generative-ai/docs/...` — same publisher and content, cited here under the original `cloud.google.com` paths.

- Supervised fine-tuning (SFT) adapts Gemini model behavior with a labeled dataset, for tasks such as classification, summarization, and chat/instruction-following.
- Tuning-data modalities go beyond plain text: text, document, image, audio, video, and function-calling tuning each have separate modality guides.
- Three surfaces: the Vertex AI Studio / Agent Platform console UI, the Python GenAI Client SDK, and the REST API (`projects.locations.tuningJobs` resource, with `create`, `get`, `list`, `cancel`, `rebaseTunedModel` methods).

### Training data format

> Source: https://cloud.google.com/vertex-ai/generative-ai/docs/models/gemini-use-supervised-tuning

JSONL, one training example per line, using a Gemini-style `messages`/`role` schema. Role values are `user` and `model` — not OpenAI's `assistant`:

```json
{
  "messages": [
    { "role": "user", "content": "input text or prompt" },
    { "role": "model", "content": "expected model response" }
  ]
}
```

Both Gemini 1.5- and 2.0-generation models were confirmed to share this JSONL structure.

### Hyperparameters

> Source: https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/tuning

Tuning-job configuration knobs referenced by the docs: `epochs` (passes over the training set), `learning_rate_multiplier` (scales the base LR), and `adapter_size` (the parameter-efficient adapter's capacity — Vertex's equivalent of LoRA rank).

### Pricing

> Source: https://cloud.google.com/vertex-ai/generative-ai/pricing

- Training tokens are computed as `(total tokens in the training dataset) × (number of epochs)`, billed per 1M training tokens processed rather than per wall-clock hour.
- Example per-1M-training-token rates from the docs: Gemini 2.0 Flash — $3.00; Gemini 2.0 Flash Lite — $1.00.
- Inference pricing for a tuned model endpoint is identical to the base model's: "Tuned model endpoint has the same prediction price as the base model." There is no inference premium for calling a fine-tuned Gemini endpoint.

## Gaps — unverified, check live before relying on these

- **Vertex hyperparameter defaults and ranges** for `epochs`, `learning_rate_multiplier`, and `adapter_size` were not present in the fetched page content.
- **Vertex dataset limits** — exact minimum/maximum example counts and maximum file size were not resolved from the fetched pages.
- **Vertex rates for Gemini 2.5 Pro/Flash and 3.x-generation models** — figures of $5.00/1M for a Pro-tier model and $1.00/1M for a Lite-tier model appeared in search-summarized results but were not confirmed against the fetched pricing page. Treat as unverified.

## Sources

- https://platform.openai.com/docs/guides/supervised-fine-tuning
- https://platform.openai.com/docs/pricing
- https://cloud.google.com/vertex-ai/generative-ai/docs/models/gemini-supervised-tuning
- https://cloud.google.com/vertex-ai/generative-ai/docs/models/gemini-use-supervised-tuning
- https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/tuning
- https://cloud.google.com/vertex-ai/generative-ai/pricing

Fetched: 2026-08-05
