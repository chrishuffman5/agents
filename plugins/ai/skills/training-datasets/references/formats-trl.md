# Hugging Face TRL: dataset formats and types

Read when preparing data for any TRL-based trainer (including Unsloth runs, which drive TRL trainers underneath): choosing columns, adding tool calls or images, or converting between dataset types.

## Format vs type

> Source: https://huggingface.co/docs/trl/en/dataset_formats

TRL separates two axes:

- **Format** — how a sample is structured: `standard` (plain strings) or `conversational` (list of `{"role": ..., "content": ...}` messages).
- **Type** — the task the dataset serves (language modeling, prompt-only, prompt-completion, preference, unpaired preference, stepwise supervision). Each type has fixed column names.

### Type × format matrix

Language modeling:
```python
# Standard
{"text": "The sky is blue."}
# Conversational
{"messages": [{"role": "user", "content": "What color is the sky?"},
              {"role": "assistant", "content": "It is blue."}]}
```

Prompt-only:
```python
# Standard
{"prompt": "The sky is"}
# Conversational
{"prompt": [{"role": "user", "content": "What color is the sky?"}]}
```

Prompt-completion:
```python
# Standard
{"prompt": "The sky is", "completion": " blue."}
# Conversational
{"prompt": [{"role": "user", "content": "What color is the sky?"}],
 "completion": [{"role": "assistant", "content": "It is blue."}]}
```

Preference (DPO and related trainers):
```python
# Standard, explicit prompt (recommended)
{"prompt": "The sky is", "chosen": " blue.", "rejected": " green."}
# Standard, implicit prompt
{"chosen": "The sky is blue.", "rejected": "The sky is green."}

# Conversational, explicit prompt (recommended)
{"prompt": [{"role": "user", "content": "What color is the sky?"}],
 "chosen": [{"role": "assistant", "content": "It is blue."}],
 "rejected": [{"role": "assistant", "content": "It is green."}]}
# Conversational, implicit prompt
{"chosen": [{"role": "user", "content": "What color is the sky?"},
            {"role": "assistant", "content": "It is blue."}],
 "rejected": [{"role": "user", "content": "What color is the sky?"},
              {"role": "assistant", "content": "It is green."}]}
```
Explicit prompts are recommended over implicit ones.

Unpaired preference (single completion + boolean label, e.g. KTO):
```python
# Standard
{"prompt": "The sky is", "completion": " blue.", "label": True}
# Conversational
{"prompt": [{"role": "user", "content": "What color is the sky?"}],
 "completion": [{"role": "assistant", "content": "It is green."}],
 "label": False}
```

Stepwise supervision (process reward / PRM data — per-step completions with per-step labels):
```python
{
  "prompt": "Which number is larger, 9.8 or 9.11?",
  "completions": ["The fractional part of 9.8 is 0.8.",
                  "The fractional part of 9.11 is 0.11.",
                  "0.11 is greater than 0.8.",
                  "Hence, 9.11 > 9.8."],
  "labels": [True, True, False, False]
}
```

### Trainer → expected type

| Trainer | Expected dataset type |
| --- | --- |
| `SFTTrainer` | Language modeling or Prompt-completion |
| `DPOTrainer` | Preference (explicit prompt recommended) |
| `GRPOTrainer` | Prompt-only |
| `KTOTrainer` | Unpaired preference or Preference |
| `RewardTrainer` | Preference (implicit prompt recommended) |
| `RLOOTrainer` | Prompt-only |
| `experimental.bco.BCOTrainer` | Unpaired preference or Preference |
| `experimental.cpo.CPOTrainer` | Preference |
| `experimental.gkd.GKDTrainer` | Prompt-completion |
| `experimental.online_dpo.OnlineDPOTrainer` | Prompt-only (both formats; auto-applies chat template) |
| `experimental.orpo.ORPOTrainer` | Preference |
| `experimental.ppo.PPOTrainer` | Tokenized language modeling |
| `experimental.prm.PRMTrainer` | Stepwise supervision |

## Tool calling in datasets

> Source: https://huggingface.co/docs/trl/en/dataset_formats

Conversational datasets can carry `tool_calls` on assistant messages and `tool`-role messages for tool output:

```python
messages = [
    {"role": "user", "content": "Turn on the living room lights."},
    {"role": "assistant", "tool_calls": [
        {"type": "function", "function": {
            "name": "control_light",
            "arguments": {"room": "living room", "state": "on"}
        }}]
    },
    {"role": "tool", "name": "control_light", "content": "The lights in the living room are now on."},
    {"role": "assistant", "content": "Done!"}
]
```

For SFT with tool calling, add a `tools` column of JSON-schema tool definitions, typically consumed by the chat template to build the system prompt. Generate schemas from Python functions with `transformers.utils.get_json_schema`. A full SFT row is `{"messages": messages, "tools": [json_schema]}`.

Because tool arguments are arbitrary JSON, build the `Dataset` with `Dataset.from_list(data, on_mixed_types="use_json")` (requires `datasets>=4.7.0`), or store `tools` as a JSON string via `json.dumps([...])` on older versions.

### Harmony format (OpenAI gpt-oss models)

Extends conversational format with a `developer` role, output channels (`analysis` = internal reasoning from a `"thinking"` key, `final` = user-facing answer from `"content"`, `commentary` = tool calls/meta), and a `reasoning_effort` control (`"low"` / `"medium"` / `"high"`):

```python
messages = [
    {"role": "developer", "content": "Use a friendly tone."},
    {"role": "user", "content": "What is the meaning of life?"},
    {"role": "assistant", "thinking": "Deep reflection...", "content": "The final answer is..."},
]
tokenizer.apply_chat_template(messages, tokenize=False, reasoning_effort="low",
                              model_identity="You are HuggingGPT...")
```

## Vision (image-text) datasets

> Source: https://huggingface.co/docs/trl/en/dataset_formats

Use conversational format, with two differences from text-only rows:

1. The dataset needs an `images` column (list of PIL images) or `image` column (single PIL image).
2. Each message's `"content"` is a list of typed dicts:

```python
"content": [
    {"type": "image"},
    {"type": "text", "text": "What color is the sky in the image?"}
]
```

Mixing text-only and vision-language rows in one dataset requires `transformers>=4.57.0`.

## SFT-specific dataset behavior

> Source: https://huggingface.co/docs/trl/en/sft_trainer

- `SFTTrainer` accepts both `standard` and `conversational` formats, and both `language modeling` and `prompt-completion` types; conversational datasets get the chat template auto-applied.
- Supports **pre-tokenized** datasets (an `input_ids` column). An optional `labels` column (`-100` marks tokens excluded from loss) is used as-is if present; otherwise labels are built from `assistant_masks` / `completion_mask` columns, else default to a copy of `input_ids`.
- `dataset_text_field` (default `"text"`) — column holding text for the standard/language-modeling path.
- `packing` (default `False`) — pack multiple examples into fixed-length blocks. `packing_strategy` is `"bfd"` (best-fit decreasing, default), `"bfd_split"`, or `"wrapped"`.
- `completion_only_loss` — for prompt-completion datasets, loss is computed on completion tokens only by default (`True`); set `False` to train on the full sequence.
- `assistant_only_loss` (default `False`) — for conversational datasets, restrict loss to assistant turns. Requires the chat template to include `{% generation %}` / `{% endgeneration %}` Jinja keywords (TRL auto-patches known families like Qwen3; custom templates must add them manually).
- `max_length` (default `1024`) — tokenized sequences are truncated (`truncation_mode="keep_start"` is the only supported mode; `"keep_end"` is deprecated). Set `max_length=None` for VLMs so truncation doesn't strip image tokens.
- `eos_token` — override when a base model's tokenizer chat template doesn't match its default EOS (e.g. for `Qwen/Qwen2.5-1.5B`, set `eos_token="<|im_end|>"`).

Example preprocessing (arbitrary dataset → prompt-completion, reasoning wrapped in `<think>` tags):
```python
def preprocess_function(example):
    return {
        "prompt": [{"role": "user", "content": example["Question"]}],
        "completion": [
            {"role": "assistant", "content": f"<think>{example['Complex_CoT']}</think>{example['Response']}"}
        ],
    }
dataset = dataset.map(preprocess_function, remove_columns=["Question", "Response", "Complex_CoT"])
```

## DPO-specific dataset behavior

> Source: https://huggingface.co/docs/trl/en/dpo_trainer

- `DPOTrainer` accepts standard or conversational **preference** datasets; conversational gets the chat template auto-applied.
- Preprocessing a non-standard source into DPO shape:
```python
def preprocess_function(example):
    return {
        "prompt": [{"role": "user", "content": example["input"]}],
        "chosen": [{"role": "assistant", "content": example["accepted"]}],
        "rejected": [{"role": "assistant", "content": example["rejected"]}],
    }
dataset = dataset.map(preprocess_function, remove_columns=["instruction", "input", "accepted", "ID"])
```
- Key `DPOConfig` fields: `beta` (default `0.1`; controls deviation from the reference model — higher beta = less deviation), `loss_type` (default `["sigmoid"]`; also `hinge`, `ipo`, `exo_pair`, `nca_pair`, `robust`, `bco_pair`, `sppo_hard`, `aot` / `aot_unpaired`, `apo_zero` / `apo_down`, `discopop`, `sft`, `sigmoid_norm` — combinable via `loss_weights`), `label_smoothing` (default `0.0`; Robust DPO expects `[0.0, 0.5)`, EXO recommends `1e-3`), `max_length` (default `1024`), `truncation_mode="keep_start"` (only supported value).
- Vision preference datasets: provide `image` / `images`, same as SFT; set `max_length=None` to avoid truncating image tokens.
- Tool calling with DPO: `prompt` / `chosen` / `rejected` conversations may include `tool_calls` and `tool`-role messages, plus a `tools` column of JSON schemas — same shape as SFT tool calling.

## Converting between dataset types

> Source: https://huggingface.co/docs/trl/en/dataset_formats

TRL provides `extract_prompt()` (splits an implicit-prompt preference dataset into explicit prompt + chosen/rejected) and `unpair_preference_dataset()` (turns paired preference data into unpaired rows, one per completion with a boolean `label`):

```python
from trl import extract_prompt, unpair_preference_dataset
dataset = dataset.map(extract_prompt)
dataset = unpair_preference_dataset(dataset)
# -> {'prompt': [...], 'completion': [...], 'label': True}
```

Warning: before unpairing, confirm `chosen` really is uniformly "good" and `rejected` uniformly "bad" (e.g. via an absolute reward-model score) — pairwise preference data can contain pairs that are both mediocre or both good.

Other documented conversions: prompt-completion → language modeling (concatenate prompt + completion into `text`); preference → prompt-completion (drop `rejected`, rename `chosen` to `completion`); preference → language modeling; unpaired preference → prompt-completion (filter on `label`, drop `label`); stepwise supervision → unpaired preference (join completions, reduce per-step `labels` with logical AND).

## Sources

- https://huggingface.co/docs/trl/en/dataset_formats
- https://huggingface.co/docs/trl/en/sft_trainer
- https://huggingface.co/docs/trl/en/dpo_trainer

Fetched: 2026-08-05
