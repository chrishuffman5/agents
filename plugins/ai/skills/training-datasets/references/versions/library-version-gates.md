# Library version gates affecting dataset shapes

Read when a documented column, kwarg, or dataset shape fails on an installed library version, or when pinning versions for a data-prep environment. Every entry below is a behavior that changes with the library or platform revision — nothing here is a general format rule.

## `datasets` >= 4.7.0 — mixed-type tool arguments

> Source: https://huggingface.co/docs/trl/en/dataset_formats

Tool-calling rows carry arbitrary JSON in `function.arguments`, which breaks Arrow's type inference when building a `Dataset` from Python objects.

- On `datasets >= 4.7.0`: `Dataset.from_list(data, on_mixed_types="use_json")`.
- On older versions: store the `tools` column as a JSON string via `json.dumps([...])`.

## `transformers` >= 4.57.0 — mixing text-only and vision rows

> Source: https://huggingface.co/docs/trl/en/dataset_formats

Mixing text-only and vision-language rows within one dataset requires `transformers>=4.57.0`. Below that, keep text-only and image-bearing rows in separate datasets.

## TRL truncation mode — `keep_end` deprecated

> Source: https://huggingface.co/docs/trl/en/sft_trainer
> Source: https://huggingface.co/docs/trl/en/dpo_trainer

`truncation_mode="keep_start"` is the only supported value for both `SFTTrainer` and `DPOTrainer` configs; `"keep_end"` is deprecated. Datasets whose important content sits at the end of the sequence must be restructured or chunked rather than relying on end-preserving truncation.

## Chat-template Jinja keywords for assistant-only loss

> Source: https://huggingface.co/docs/trl/en/sft_trainer

`assistant_only_loss=True` requires the model's chat template to contain `{% generation %}` / `{% endgeneration %}` keywords. TRL auto-patches known model families (Qwen3 named in the docs); custom or older templates must add the keywords manually or the option has no valid effect.

## Tokenizer/EOS mismatch on specific base models

> Source: https://huggingface.co/docs/trl/en/sft_trainer

Some base models ship a tokenizer chat template whose end token differs from the tokenizer's default EOS. Documented example: for `Qwen/Qwen2.5-1.5B`, set `eos_token="<|im_end|>"`. Symptom is a tuned model that never stops generating.

## Gemini API / AI Studio fine-tuning removed (May 2025)

> Source: https://ai.google.dev/gemini-api/docs/model-tuning

With the deprecation of Gemini 1.5 Flash-001 in May 2025, no model supporting fine-tuning remains in the Gemini API or AI Studio. Gemini tuning moved to the Gemini Enterprise Agent Platform / Vertex AI tuning surface. Any older guide describing `tunedModels` creation through the Gemini API no longer applies.

## Documentation URL redirects (as of 2026-08-05)

> Source: https://developers.openai.com/api/docs/guides/supervised-fine-tuning
> Source: https://unsloth.ai/docs/get-started/fine-tuning-llms-guide/datasets-guide

- `platform.openai.com/docs/guides/*` 301-redirects to `developers.openai.com/api/docs/guides/*`.
- `docs.unsloth.ai/*` 301-redirects to the equivalent path under `unsloth.ai/docs/*`.

Both redirect targets are the vendors' own current canonical locations; cite either form.

## Sources

- https://huggingface.co/docs/trl/en/dataset_formats
- https://huggingface.co/docs/trl/en/sft_trainer
- https://huggingface.co/docs/trl/en/dpo_trainer
- https://ai.google.dev/gemini-api/docs/model-tuning
- https://developers.openai.com/api/docs/guides/supervised-fine-tuning
- https://platform.openai.com/docs/guides/supervised-fine-tuning
- https://unsloth.ai/docs/get-started/fine-tuning-llms-guide/datasets-guide
- https://docs.unsloth.ai/basics/datasets-guide

Fetched: 2026-08-05
