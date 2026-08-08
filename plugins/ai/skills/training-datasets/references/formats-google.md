# Google: Gemini tuning availability and the Content/Part row schema

Read when building supervised-tuning JSONL for a Gemini model on Vertex AI, or when asked whether Gemini API fine-tuning is available.

## Gemini API fine-tuning status (as of 2026-08-05)

> Source: https://ai.google.dev/gemini-api/docs/model-tuning

Fine-tuning is **no longer available directly through the Gemini API or Google AI Studio**. The docs state: "With the deprecation of Gemini 1.5 Flash-001 in May 2025, we no longer have a model available which supports fine-tuning in the Gemini API or AI Studio."

Fine-tuning of Gemini models is instead supported through the **Gemini Enterprise Agent Platform** / Vertex AI generative AI tuning surface on `cloud.google.com`, not the consumer Gemini API.

## Content/Part JSON schema — the building block of tuning rows

> Source: https://ai.google.dev/api/generate-content
> Source: https://ai.google.dev/api/caching

Every Gemini API request/response — and by extension every supervised-tuning training row — is built from `Content` objects:

- `Content.role`: `"user"`, `"model"`, or (for the top-level `systemInstruction` field) `"system"`.
- `Content.parts[]`: array of `Part` objects. A `Part` may carry `text` (plain string), `inlineData` (`{"mimeType": ..., "data": <base64>}`), `fileData` (`{"mimeType": ..., "file_uri": ...}`), `functionCall`, or `executionResult`.
- `systemInstruction`: optional top-level field, itself a `Content` object, currently **text-only**.

Example request shape combining these:
```json
{
  "contents": [{
    "role": "user",
    "parts": [
      {"text": "Describe this image"},
      {"fileData": {"mimeType": "image/jpeg", "file_uri": "files/..."}}
    ]
  }],
  "systemInstruction": {
    "parts": {"text": "You are an expert analyst."}
  }
}
```

Google's supervised-tuning JSONL format for Gemini models follows this same `contents` / `role` / `parts` convention — one JSON object per line, each with a `contents` array of alternating `user` / `model` turns plus an optional `systemInstruction`. It is the same schema used for ordinary `generateContent` calls, not a separate tuning-specific format.

## Vertex AI supervised fine-tuning: launching a job

> Source: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/samples/generativeaionvertexai-tuning-basic

Training data is a JSONL file referenced by a `gs://` Cloud Storage URI. Minimal Python launch flow:

```python
import time
import vertexai
from vertexai.tuning import sft

PROJECT_ID = "your-project-id"
vertexai.init(project=PROJECT_ID, location="us-central1")

sft_tuning_job = sft.train(
    source_model="gemini-2.0-flash-001",
    train_dataset="gs://cloud-samples-data/ai-platform/generative_ai/gemini-1_5/text/sft_train_data.jsonl",
)

while not sft_tuning_job.has_ended:
    time.sleep(60)
    sft_tuning_job.refresh()

print(sft_tuning_job.tuned_model_name)
print(sft_tuning_job.tuned_model_endpoint_name)
print(sft_tuning_job.experiment)
```

Note that the sample dataset path is named for the "gemini-1_5" generation but is used to tune `gemini-2.0-flash-001` — Google's own sample treats the JSONL schema as stable across Gemini model generations. `train_dataset` accepts a Cloud Storage (`gs://`) path to the JSONL file; the job is driven via `vertexai.tuning.sft.train()` and polled through `sft_tuning_job.refresh()` until `has_ended`.

## Unverified

The corpus behind this reference does not contain vendor-documented minimum/maximum example counts, per-row token limits, or validation-dataset requirements for Vertex AI supervised tuning. Do not state such numbers from memory — check the Vertex AI tuning documentation directly.

## Sources

- https://ai.google.dev/gemini-api/docs/model-tuning
- https://ai.google.dev/api/generate-content
- https://ai.google.dev/api/caching
- https://docs.cloud.google.com/vertex-ai/generative-ai/docs/samples/generativeaionvertexai-tuning-basic

Fetched: 2026-08-05
