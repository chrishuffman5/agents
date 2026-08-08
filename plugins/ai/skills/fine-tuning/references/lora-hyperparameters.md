# LoRA, QLoRA, and Hyperparameters

Read when choosing between LoRA/QLoRA/full fine-tuning, setting or debugging hyperparameters (rank, alpha, learning rate, epochs, batch size), or diagnosing under-/over-fitting. Facts as of 2026-08-05.

## LoRA vs QLoRA vs full fine-tuning

> Source: https://docs.unsloth.ai/get-started/fine-tuning-llms-guide

- **Full fine-tuning (FFT)** updates all model weights and needs significantly more VRAM and compute. The docs state FFT is "usually unnecessary" — a correctly-tuned LoRA can match it.
- **LoRA** freezes the base weights (kept in 16-bit) and trains small added low-rank adapter matrices. "LoRA can match full fine-tuning performance while using 4× less VRAM."
- **QLoRA** is LoRA on top of a 4-bit-quantized base. Cuts memory roughly 75% versus 16-bit LoRA. With Unsloth's dynamic 4-bit quants, the accuracy loss versus standard 16-bit LoRA is described as negligible / now recovered.
- **Unsloth's recommendation:** start with QLoRA — the most accessible and cheapest entry point. LoRA/QLoRA runs are typically low-cost.

## End-to-end workflow

> Source: https://docs.unsloth.ai/get-started/fine-tuning-llms-guide

1. Understand what fine-tuning does: customizes behavior, injects domain knowledge, optimizes for a specific task.
2. Choose model and method — beginners start with a small instruct model, e.g. Llama 3.1 (8B).
3. Prepare the dataset: curated question/answer (instruction/response) pairs. Dataset quality directly drives output quality.
4. Study hyperparameters before training.
5. Install requirements — notebook (Colab/Kaggle) or local pip/Docker install.
6. Train and evaluate: monitor training loss, validate on held-out data.
7. Deploy: save as a LoRA adapter (~100 MB) or export to Ollama, vLLM, or another inference engine.
8. Model is production-ready.

## Recommended hyperparameter values

> Source: https://docs.unsloth.ai/get-started/fine-tuning-llms-guide/lora-hyperparameters-guide

| Hyperparameter | Recommended | Notes / range |
|---|---|---|
| Learning rate | `2e-4` | Range `2e-4` to `5e-6`; use `5e-6` for RL tasks |
| Epochs | 1–3 | Avoid >3 — overfitting risk climbs sharply |
| LoRA rank `r` | 16 or 32 | Common set: 8, 16, 32, 64, 128. Bigger models / simpler data → smaller rank is fine; smaller models / more complex data → bigger rank needed. Rank should be ≥ what alpha implies |
| LoRA alpha `α` | `r` or `2r` | Equal to rank, or double it |
| LoRA dropout | 0 | Range 0–0.1; 0 is what Unsloth's kernels are optimized for |
| Weight decay | 0.01 | Range 0.01–0.1 |
| Warmup steps | 5–10% of total steps | Gradual LR ramp-up |
| Batch size | 2 | Primary VRAM driver — increase cautiously |
| Gradient accumulation steps | 8 | Multiplies effective batch size without extra VRAM |
| Effective batch size | 16 (batch × accum) | `bs=2, accum=8` ≡ `bs=32, accum=1` ≡ `bs=16, accum=2` in weight-update quality |
| `bias` | `"none"` | Skipping bias params cuts trainable count with minimal quality impact |
| `target_modules` | `q_proj, k_proj, v_proj, o_proj, gate_proj, up_proj, down_proj` | Apply LoRA to all major linear layers — targeting fewer gives only "minimal" memory savings at a real quality cost |
| LR scheduler | linear or cosine | |
| Seed | any int (42, 3407) | Reproducibility |

### Formulas

- Standard LoRA update: `W' = W + (α/rank) × A·B` — keep `α/rank ≥ 1`.
- Rank-Stabilized LoRA (RSLoRA): `W' = W + (α/√rank) × A·B` — enable with `use_rslora=True`.

### Learning-rate heuristics

- Short training runs: if convergence is too slow, raising LR helps.
- Longer runs: prefer lowering LR rather than raising it.
- A high LR on a short run commonly causes overfitting; on long runs a higher LR can work better. The docs explicitly say to experiment with both.

### Practical signals

- Training only on completions (masking prompt/input tokens out of the loss) "increases accuracy by quite a bit."
- Training loss below 0.2 is a signal the run is likely overfitting.

## Data-quality checks for an in-flight tuning run

> Source: https://platform.openai.com/docs/guides/fine-tuning-best-practices

This page is scoped to optimizing a fine-tuning run already underway; it does not compare fine-tuning against prompt engineering or RAG.

- "A smaller amount of high-quality data is generally more effective than a larger amount of low-quality data." Quality before quantity.
- To test whether more data will help: fine-tune on the full dataset versus half of it and compare. Expect a similar magnitude of improvement each time the training set doubles (roughly logarithmic returns).
- Fix these before adding data:
  - **Targeted examples** — add rows addressing the model's observed weak spots.
  - **Consistency** — scrub grammar/logic/style errors; the model replicates them.
  - **Balance** — match label/class distribution to real production frequency; don't over-represent rare cases such as refusals.
  - **Completeness** — give each example all the context it needs, so the model isn't forced to hallucinate the missing parts.
  - **Rater agreement** — model quality is capped by how consistent human annotators are with each other.
- Hyperparameter adjustment from defaults: increase epochs if the model isn't following the training data closely enough (common for classification/extraction); decrease epochs if output diversity unexpectedly drops (overfitting / mode collapse); increase learning rate if the model fails to converge.

## Sources

- https://docs.unsloth.ai/get-started/fine-tuning-llms-guide
- https://docs.unsloth.ai/get-started/fine-tuning-llms-guide/lora-hyperparameters-guide
- https://platform.openai.com/docs/guides/fine-tuning-best-practices

Fetched: 2026-08-05
