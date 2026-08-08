---
name: training-datasets
description: "Building the dataset that a fine-tune or preference-optimization run consumes: exact JSONL/chat-template shapes (OpenAI SFT + DPO, Hugging Face TRL type/format matrix, Unsloth Alpaca/ShareGPT/ChatML, Gemini/Vertex contents-parts), dataset types (instruction, conversational, preference, unpaired preference, stepwise/PRM), documented size floors, quality and split practices, synthetic-data generation, dedup/decontamination pipeline construction, PII taxonomies, and dataset licensing metadata. WHEN: \"training data format\", \"fine-tuning JSONL\", \"chat template for training\", \"ShareGPT vs ChatML\", \"Alpaca format\", \"preference dataset\", \"DPO pairs\", \"chosen/rejected\", \"KTO labels\", \"PRM stepwise labels\", \"how many training examples\", \"dataset too small\", \"deduplicate training data\", \"decontaminate eval overlap\", \"synthetic training data\", \"scrub PII from dataset\", \"dataset card license\", \"train/test split for fine-tuning\". Do NOT use for actually running the training job — LoRA/QLoRA/GRPO configs, hyperparameters, hardware, adapter merging, hosted tuning-job APIs belong to the `fine-tuning` skill. Do NOT use for measuring a model/agent/skill after training (graders, LLM-as-judge, agentic evals, regression suites) — that's `evals`. Do NOT use for choosing which base model to tune (`model-selection`) or for prompt-injection/data-poisoning threat modeling (`ai-security`)."
license: MIT
---

# Training Datasets

Building the corpus a tuning run reads: exact on-disk shapes, dataset types, sizing, quality gates, synthetic generation, and the license/PII metadata that has to travel with it.

**Scope boundary.** This skill stops at the file you hand the trainer. Everything downstream of `train_dataset=` — LoRA rank, epochs, GPU memory, adapter export — is the `fine-tuning` skill. Everything that measures the result is `evals`.

## Decide the dataset type first

The type dictates column names, and column names are not negotiable per trainer. Always fix the type before writing a single row; reshaping a 50k-row corpus after the fact is pure waste.

| Goal | Type | Canonical columns |
|---|---|---|
| Teach style/behavior from demonstrations | Prompt-completion (SFT) | `prompt` + `completion`, or `messages` |
| Continued pretraining on raw domain text | Language modeling | `text` (or `messages`) |
| Prompts only, rewards computed online (GRPO/RLOO) | Prompt-only | `prompt` |
| "A is better than B" | Preference | `prompt`, `chosen`, `rejected` |
| "This one response was good/bad" (KTO) | Unpaired preference | `prompt`, `completion`, `label` (bool) |
| Score each reasoning step (PRM) | Stepwise supervision | `prompt`, `completions[]`, `labels[]` |

TRL's trainer→type mapping (`SFTTrainer`, `DPOTrainer`, `GRPOTrainer`, `KTOTrainer`, `RewardTrainer`, `PRMTrainer`, …) is tabulated in `references/formats-trl.md` — read it before picking columns for any Hugging Face-based run.

Orthogonal to type is **format**: `standard` (plain strings) vs `conversational` (list of `{"role","content"}` messages). Prefer conversational for anything an instruct model will serve, because the trainer applies the model's chat template for you and inference-time shape then matches training-time shape.

## Format alignment is the single highest-leverage rule

Always make every training example byte-identical in structure to what the model will see at inference: same system-prompt convention, same tool schemas, same message roles. Format drift between training and serving is the most common cause of a tune that "works in eval, fails in prod."

Always write the **complete** instruction into every example. Never rely on the model to induce a shortened instruction from many examples — OpenAI's best-practices guidance is explicit that the model learns from direct demonstration, not from inference across the corpus.

Always ensure each example contains all information needed to produce its target output. An example whose answer depends on context you did not include teaches the model to hallucinate that context.

## Pick the vendor shape

Read the matching reference before generating rows — the shapes differ in ways that silently fail validation.

- **OpenAI hosted fine-tuning (SFT and DPO JSONL)** → `references/formats-openai.md`. SFT is one `{"messages": [...]}` object per line with optional `tools` / `parallel_tool_calls`, uploaded with purpose `"fine-tune"`. DPO is a different three-field shape (`input`, `preferred_output`, `non_preferred_output`) and supports only one-turn preference deltas.
- **Hugging Face TRL (any local trainer, including Unsloth-driven runs)** → `references/formats-trl.md`. Full type×format matrix, trainer table, tool-calling rows, Harmony/gpt-oss channels, vision rows, and the `extract_prompt` / `unpair_preference_dataset` conversion helpers.
- **Unsloth chat templates (Alpaca / ShareGPT / ChatML)** → `references/formats-unsloth.md`. `standardize_sharegpt()`, `get_chat_template()` with role mapping, and the supported template-name list.
- **Gemini / Vertex AI supervised tuning** → `references/formats-google.md`. Rows are built from `contents[]` with `role: user|model` and `parts[]`; JSONL is referenced by a `gs://` URI. Note that fine-tuning is no longer offered through the Gemini API or AI Studio.

Version-gated shapes (`datasets>=4.7.0` for mixed-type tool arguments, `transformers>=4.57.0` for mixing text-only and vision rows, deprecated truncation modes) live in `references/versions/library-version-gates.md`. Read it whenever a documented column or kwarg errors out on an older install.

### Canonical rows at a glance

Enough to start writing rows without opening a reference; open the reference for tool calling, vision, Harmony, and every trainer kwarg.

OpenAI SFT — one line per example, purpose `"fine-tune"`:
```json
{"messages": [{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]}
```

OpenAI DPO — three top-level fields, single-turn delta only:
```json
{"input": {"messages": [{"role": "user", "content": "..."}], "tools": [], "parallel_tool_calls": true},
 "preferred_output": [{"role": "assistant", "content": "..."}],
 "non_preferred_output": [{"role": "assistant", "content": "..."}]}
```

TRL prompt-completion, conversational (SFT):
```json
{"prompt": [{"role": "user", "content": "..."}],
 "completion": [{"role": "assistant", "content": "..."}]}
```

TRL preference with explicit prompt (DPO — explicit is recommended over implicit):
```json
{"prompt": [{"role": "user", "content": "..."}],
 "chosen": [{"role": "assistant", "content": "..."}],
 "rejected": [{"role": "assistant", "content": "..."}]}
```

TRL unpaired preference (KTO) and stepwise supervision (PRM):
```json
{"prompt": "...", "completion": "...", "label": true}
{"prompt": "...", "completions": ["step 1", "step 2"], "labels": [true, false]}
```

Unsloth ShareGPT (`from`/`value`) — normalize with `standardize_sharegpt()` before templating:
```json
{"conversations": [{"from": "human", "value": "..."}, {"from": "gpt", "value": "..."}]}
```

Gemini / Vertex supervised tuning — `contents` with `user`/`model` roles and `parts`:
```json
{"systemInstruction": {"parts": {"text": "..."}},
 "contents": [{"role": "user", "parts": [{"text": "..."}]},
              {"role": "model", "parts": [{"text": "..."}]}]}
```

### Base model vs instruct model

Never hand a conversational chat template to a base model expecting it to work out of the box. Unsloth's guidance: instruct models take conversational templates (ChatML, ShareGPT); base models take instruction-style templates (Alpaca, Vicuna). Continued pretraining takes raw `{"text": ...}`.

## Converting between types

Reuse an existing corpus rather than recollecting when the target type is reachable by projection. TRL documents these conversions:

- Implicit-prompt preference → explicit prompt: `dataset.map(extract_prompt)`.
- Paired preference → unpaired preference: `unpair_preference_dataset(dataset)`, one row per completion with a boolean `label`.
- Preference → prompt-completion: drop `rejected`, rename `chosen` to `completion`.
- Prompt-completion → language modeling: concatenate into a single `text` field.
- Unpaired preference → prompt-completion: filter on `label`, drop `label`.
- Stepwise supervision → unpaired preference: join `completions`, reduce `labels` with logical AND.

Never unpair a preference dataset without first confirming that `chosen` is uniformly good and `rejected` uniformly bad — pairwise data routinely contains pairs that are both mediocre or both fine, and unpairing converts that into wrong absolute labels. Verify with an absolute reward-model score or a sampled human pass.

Projection loses information in one direction only. Preference → SFT is safe; SFT → preference is fabrication unless you actually generate and rank a second response.

## Size the dataset with documented floors, then measure

Only these numbers are vendor-documented — use them as floors, not targets.

| Source | Floor | Recommendation |
|---|---|---|
| OpenAI SFT | 10 examples (hard minimum to submit a job) | Start at 50; visible improvement reported at 50–100 |
| OpenAI DPO | No documented minimum | Treat the SFT floor as a practical floor; prefer far more, DPO is noise-sensitive |
| Unsloth | 100 rows for reasonable results | Over 1,000 preferred |

Always determine "enough data" empirically rather than by rule of thumb: train on the full dataset and on half of it, compare eval performance, and if the full run is meaningfully better, doubling again is likely to keep helping. This halving experiment is the only documented sizing method and it beats any guessed row count.

Quality dominates quantity. A smaller high-quality set outperforms a larger low-quality one — both OpenAI and Unsloth state this directly.

## Quality gates that are actually documented

Apply these before training; each maps to a specific documented failure mode.

- **Consistency check.** If two competent annotators would write different "correct" completions for the same prompt, achievable model performance is capped there. Resolve the ambiguity in the spec, not in the model.
- **Proofread for propagated errors.** Grammar, logic, and style defects in examples get learned and reproduced.
- **Match class balance to inference-time distribution.** Training that is 60% refusals when ~5% of production traffic warrants refusal produces an over-refusing model. Sample to the serving distribution, not to what was easy to collect.
- **Split train/held-out early.** Submit both a training and a validation file so the platform reports per-step train-vs-test statistics — that comparison is the primary convergence/overfitting signal. `dataset.train_test_split(test_size=0.1)` for local sets.
- **Review-and-regenerate loop.** Remove or rewrite irrelevant and poor-quality responses; for an imbalanced set, feed the cleaned data back to an LLM with more explicit guidance to generate the missing slices.

When a dataset behaves badly in training, prefer a dataset fix over a hyperparameter fix. The documented hyperparameter responses are narrow: raise epochs by 1–2 if the model under-follows the data (classification-style tasks especially), lower them if output diversity collapses, raise learning rate on stalled convergence, raise batch size for gradient stability at the cost of speed.

## Deduplication and decontamination

**Documented:** the `datasets` library exposes no single built-in "deduplicate" call. Build the pass yourself from the two primitives it does document — `map()` to compute a normalized hash or n-gram signature as a new column, then `filter()` to drop rows whose signature was already seen or that match an eval-benchmark signature. Use `num_proc=N` for parallelism and `flatten_indices()` afterwards, because a dataset carrying a non-contiguous indices mapping (the result of filter/shuffle/select) can be ~10x slower to read row-wise.

**Unverified — do not state as fact:** the corpus behind this skill contains no vendor-documented algorithm for near-duplicate detection or eval decontamination (no documented MinHash/LSH parameters, shingle sizes, similarity thresholds, or n-gram overlap cutoffs for benchmark contamination). Recommend the mechanism (hash column + filter) as documented; flag any specific threshold or algorithm you propose as an engineering judgment call, not vendor guidance, and validate it against your own held-out set.

Always decontaminate against the exact eval sets you will report on, before the halving experiment above — otherwise the size signal is measuring memorization.

## Synthetic data

Use synthetic generation for three documented purposes: creating new data from scratch or extending an existing set; diversifying examples to prevent overfitting; and reformatting existing data into the target shape.

Always have at least ~10 real examples of the target data in hand before generating from them — the generator needs concrete style and content anchors. Generate with a local model or a hosted one, then run the review-and-regenerate loop above; never ship generated rows unreviewed.

Always check the generator model's output-use terms before shipping. Llama and Gemma community licenses attach conditions to model outputs, which propagate to a dataset built from them — see the licensing section below.

## PII and licensing metadata

Ship the dataset with a card. On the Hugging Face Hub the card is `README.md` with a YAML block carrying `license`, `language`, `task_categories`, `tags`, `pretty_name`; a recognized SPDX-style identifier is what makes the license badge render. Identifier list and card fields: `references/tooling-quality-licensing.md`.

Set the license to whichever is **more restrictive** of (a) the source data's license and (b) the generator model's output-use terms. When neither standard identifier fits the combination, use `license: other`, add `license_name`, and include the full text in a `LICENSE` file.

For PII scrubbing, reuse the BigCode PII taxonomy as a starting entity set — Names, Usernames, Emails, IP addresses, Keys, Passwords, IDs, plus an Ambiguous catch-all. Always carry the `_EXAMPLE` / `_LICENSE` sub-tags: a name or email appearing in a license header or a documentation snippet is not personal data, and redacting it uniformly destroys legitimate content. Detection in that dataset combined regex plus `detect-secrets` pre-filtering with a deliberately unfiltered random sample to avoid pre-filter bias — mirror that split when building your own annotation set, or your recall estimate will be biased upward.

Some PII corpora are themselves gated with use restrictions (PII-removal training/eval only, no redistribution). Always check the upstream terms before folding such a corpus into a training set.

## Prep tooling

The `datasets` library is the working surface for everything between raw source and trainer input. All operations return a **new** dataset; nothing is in-place.

- Reshape rows with `map()` (`batched=True`, `num_proc=N`, `remove_columns=[...]`, and `async` functions bounded by an `asyncio.Semaphore` when calling a model API per row).
- Combine sources with `concatenate_datasets()` for identical schemas, `interleave_datasets(probabilities=..., stopping_strategy=...)` for weighted mixing — `first_exhausted` subsamples, `all_exhausted` oversamples.
- Export with `to_parquet()` / `push_to_hub()` for durable storage; `save_to_disk()` is uncompressed Arrow, faster to reload but weaker for long-term storage.

Full operation catalog with parameters: `references/tooling-quality-licensing.md`.

## Validate before you upload

Run `scripts/validate-training-jsonl.py` on any JSONL you are about to submit. It is read-only and stdlib-only: it parses each line, checks the shape against the documented OpenAI SFT / OpenAI DPO / TRL preference / TRL stepwise schemas, flags empty or non-alternating message arrays, reports exact-duplicate rows and prompt collisions with conflicting completions, and prints per-field length distributions.

```bash
python scripts/validate-training-jsonl.py train.jsonl --schema openai-sft
python scripts/validate-training-jsonl.py prefs.jsonl --schema openai-dpo
python scripts/validate-training-jsonl.py data.jsonl   # auto-detect
```

Never treat a clean run as proof of quality — it proves shape, not content. The consistency and balance checks above are human work.

## Failure modes and their dataset cause

| Symptom after tuning | Likely dataset cause |
|---|---|
| Model over-refuses | Refusal class over-represented vs inference distribution |
| Model hallucinates specifics | Examples lacked the context needed to derive their targets |
| Output diversity collapsed | Too many epochs for the dataset size; reduce epochs |
| Model ignores the instruction | Instructions abbreviated across examples instead of written in full |
| Great eval numbers, poor production | Serving format differs from training format, or eval set contaminated |
| Tool calls malformed | Training rows omitted the `tools` column / used a different schema than serving |

## Reference files

- `references/formats-openai.md` — OpenAI SFT and DPO JSONL shapes, `beta`, size floors, dataset-focused best practices.
- `references/formats-trl.md` — TRL type×format matrix, trainer→type table, tool calling, Harmony, vision, SFT/DPO dataset kwargs, conversion helpers.
- `references/formats-unsloth.md` — Alpaca / ShareGPT / ChatML shapes, chat-template application, sizing and synthetic-data guidance.
- `references/formats-google.md` — Gemini `Content`/`Part` schema, Gemini API tuning availability, Vertex AI SFT job launch.
- `references/tooling-quality-licensing.md` — `datasets` operation catalog, dedup/decontamination construction, dataset cards, license identifiers, PII taxonomy.
- `references/versions/library-version-gates.md` — minimum library versions and deprecated options that change documented dataset behavior.

## Sources

- https://platform.openai.com/docs/guides/supervised-fine-tuning
- https://developers.openai.com/api/docs/guides/supervised-fine-tuning
- https://platform.openai.com/docs/guides/direct-preference-optimization
- https://developers.openai.com/api/docs/guides/direct-preference-optimization
- https://platform.openai.com/docs/guides/fine-tuning-best-practices
- https://developers.openai.com/api/docs/guides/fine-tuning-best-practices
- https://huggingface.co/docs/trl/en/dataset_formats
- https://huggingface.co/docs/trl/en/sft_trainer
- https://huggingface.co/docs/trl/en/dpo_trainer
- https://docs.unsloth.ai/basics/chat-templates
- https://unsloth.ai/docs/basics/chat-templates
- https://docs.unsloth.ai/basics/datasets-guide
- https://unsloth.ai/docs/get-started/fine-tuning-llms-guide/datasets-guide
- https://ai.google.dev/gemini-api/docs/model-tuning
- https://ai.google.dev/api/generate-content
- https://ai.google.dev/api/caching
- https://docs.cloud.google.com/vertex-ai/generative-ai/docs/samples/generativeaionvertexai-tuning-basic
- https://huggingface.co/docs/datasets/en/process
- https://huggingface.co/docs/hub/datasets-cards
- https://huggingface.co/docs/hub/repositories-licenses
- https://huggingface.co/datasets/bigcode/bigcode-pii-dataset

Fetched: 2026-08-05
