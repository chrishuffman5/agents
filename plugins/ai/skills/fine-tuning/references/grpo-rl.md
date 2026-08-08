# GRPO and Reinforcement Learning with Unsloth

Read when training a reasoning model with GRPO, configuring `GRPOConfig`, writing reward functions, or sizing hardware for an RL run. Facts as of 2026-08-05.

## What GRPO is and when to use it

> Source: https://docs.unsloth.ai/get-started/reinforcement-learning-rl-guide/tutorial-train-your-own-reasoning-model-with-grpo

GRPO (Group Relative Policy Optimization) is the RL technique DeepSeek used to train R1-style reasoning models. It scores each generation in a batch relative to its peer generations for the same prompt, so it needs no separate value/critic model — unlike PPO.

### VRAM and prerequisites

- VRAM scales with parameter count. Unsloth's free Colab tier (16 GB VRAM) is enough for GRPO on models up to roughly 16B parameters.
- Prerequisite reading: the general fine-tuning guide, plus understanding how to write reward functions before starting a run.

## `GRPOConfig` core parameters

> Source: https://docs.unsloth.ai/get-started/reinforcement-learning-rl-guide/tutorial-train-your-own-reasoning-model-with-grpo

```python
loss_type = 'grpo',      # standard GRPO
# loss_type = 'dr_grpo', # Dr. GRPO variant
# loss_type = 'dapo',    # DAPO variant
# loss_type = 'bnpo',    # BNPO variant
epsilon = 0.2,
epsilon_high = 0.28,     # one-sided clipping constraint
delta = 1.5,             # two-sided clipping constraint
mask_truncated_completions = True
```

Other key fields: `use_vllm` (enable vLLM for fast rollout/inference during training), `learning_rate`, `num_generations` (completions sampled per prompt), `max_steps` (recommended minimum: 300).

## Reward functions and verifiers

> Source: https://docs.unsloth.ai/get-started/reinforcement-learning-rl-guide/tutorial-train-your-own-reasoning-model-with-grpo

Reward functions score each generation so the policy learns which outputs are better. Unsloth ships pre-built reward functions for GSM8K-style math reasoning, with five evaluation methods included. Custom reward functions are plain Python — for example "+1 for containing a required keyword," "−1 for excessive length."

## Data format

> Source: https://docs.unsloth.ai/get-started/reinforcement-learning-rl-guide/tutorial-train-your-own-reasoning-model-with-grpo

Datasets are question/answer pairs. A system prompt instructs the model to emit structured reasoning, typically via XML-style tags:

```
SYSTEM_PROMPT = """
Respond in the following format:
<reasoning>
...
</reasoning>
<answer>
...
</answer>
"""
```

The tutorial's worked example uses OpenAI's GSM8K grade-school-math dataset.

## Saving a GRPO-trained model

> Source: https://docs.unsloth.ai/get-started/reinforcement-learning-rl-guide/tutorial-train-your-own-reasoning-model-with-grpo

Same save paths as standard fine-tunes:

```python
model.save_pretrained_merged("dir", tokenizer)     # 16-bit merged
model.push_to_hub_merged("hf/repo", tokenizer)     # push merged to HF Hub
model.push_to_hub_gguf("hf/repo", tokenizer)       # GGUF for llama.cpp / Ollama
```

## Sources

- https://docs.unsloth.ai/get-started/reinforcement-learning-rl-guide/tutorial-train-your-own-reasoning-model-with-grpo

Fetched: 2026-08-05
