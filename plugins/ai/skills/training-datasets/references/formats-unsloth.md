# Unsloth dataset formats, chat templates, and sizing

Read when preparing data for an Unsloth run, converting ShareGPT-style corpora, or choosing a named chat template.

> Sourcing note: as of 2026-08-05, `docs.unsloth.ai/*` 301-redirects to the equivalent path under
> `unsloth.ai/docs/*` (Unsloth's docs moved under their main domain). Both the original
> `docs.unsloth.ai` URL and the redirect target are cited per section; content was retrieved from the
> redirect target, Unsloth's current canonical location for the same page.

## Dataset format types supported

> Source: https://docs.unsloth.ai/basics/datasets-guide
> Source: https://unsloth.ai/docs/get-started/fine-tuning-llms-guide/datasets-guide

**Instruction format (Alpaca style)** — single-turn, for base-model instruction tuning:
```json
{
  "Instruction": "Task we want the model to perform.",
  "Input": "Optional user query",
  "Output": "Expected result"
}
```

**Conversational format (ShareGPT)** — multi-turn, `from`/`value` keys:
```json
{
  "conversations": [
    {"from": "human", "value": "User message"},
    {"from": "gpt", "value": "Assistant response"}
  ]
}
```

**Multi-turn format (ChatML / OpenAI-style)** — `role`/`content` keys:
```json
{
  "messages": [
    {"role": "user", "content": "Question"},
    {"role": "assistant", "content": "Answer"}
  ]
}
```

**Continued pretraining (raw text)**:
```json
{"text": "Unstructured raw text data..."}
```

**Model compatibility.** Instruct models work with conversational templates (ChatML, ShareGPT). Base models are compatible with instruction-style templates (Alpaca, Vicuna) but generally do not support conversational chat templates out of the box.

## Chat templates and format conversion

> Source: https://docs.unsloth.ai/basics/chat-templates
> Source: https://unsloth.ai/docs/basics/chat-templates

Raw ShareGPT-format conversations are a list of turn dicts:
```python
[
    [{'from': 'human', 'value': 'Hi there!'},
     {'from': 'gpt', 'value': 'Hi how can I help?'},
     {'from': 'human', 'value': 'What is 2+2?'}],
    [{'from': 'human', 'value': "What's your name?"},
     {'from': 'gpt', 'value': "I'm Daniel!"}],
]
```

`standardize_sharegpt()` converts ShareGPT `from`/`value` keys into ChatML `role`/`content`:
```python
from unsloth.chat_templates import standardize_sharegpt
dataset = standardize_sharegpt(dataset)
```

`get_chat_template()` applies a named template to a tokenizer, with an optional `mapping` to remap role/content and human/gpt/assistant naming without standardizing first:
```python
from unsloth.chat_templates import get_chat_template

tokenizer = get_chat_template(
    tokenizer,
    chat_template = "chatml",
    mapping = {"role": "from", "content": "value",
               "user": "human", "assistant": "gpt"}
)
```

**Supported chat template names** (as of 2026-08-05): `zephyr`, `chatml`, `mistral`, `llama`, `alpaca`, `vicuna`, `vicuna_old`, `unsloth`, `gemma`, `gemma2`, `phi-3`, `phi-4`, `qwen-2.5`, and Llama variants (`llama-3`, `3.1`, `3.2`, `3.3`).

## End-to-end formatting workflow

> Source: https://docs.unsloth.ai/basics/datasets-guide
> Source: https://unsloth.ai/docs/get-started/fine-tuning-llms-guide/datasets-guide

```python
from unsloth.chat_templates import get_chat_template
from datasets import load_dataset

tokenizer = get_chat_template(tokenizer, chat_template="gemma-3")

def formatting_prompts_func(examples):
    texts = [tokenizer.apply_chat_template(c, tokenize=False)
             for c in examples["conversations"]]
    return {"text": texts}

dataset = load_dataset("repo/dataset")
dataset = dataset.map(formatting_prompts_func, batched=True)
```

Steps: (1) load with `datasets.load_dataset()`; (2) run `standardize_sharegpt()` if the source is ShareGPT-format; (3) define a formatting function calling `tokenizer.apply_chat_template()`; (4) `.map()` it across the dataset with `batched=True`.

## Dataset size and quality guidance

> Source: https://docs.unsloth.ai/basics/datasets-guide
> Source: https://unsloth.ai/docs/get-started/fine-tuning-llms-guide/datasets-guide

- **Minimum for reasonable results**: at least 100 rows.
- **Preferred**: over 1,000 rows. More data usually improves outcomes, but quality (thorough cleaning and preparation) matters more than raw row count.
- **Quality loop**: review generated/collected data and remove or improve irrelevant or poor-quality responses. For imbalanced datasets, feed the cleaned set back into an LLM to regenerate additional examples with more explicit guidance.

## Synthetic data generation guidance

> Source: https://docs.unsloth.ai/basics/datasets-guide
> Source: https://unsloth.ai/docs/get-started/fine-tuning-llms-guide/datasets-guide

Three stated goals for synthetic data in this workflow:

1. Generate entirely new data, either from scratch or by extending an existing dataset.
2. Diversify examples to prevent overfitting.
3. Augment/reformat existing data into the correct target format.

Approach: use a local LLM (example given: Llama 3.3 70B) or a hosted model (example given: ChatGPT) with structured prompts to generate candidates, then apply the quality loop above. Guidance: have at least 10 real examples of the target data already in hand before generating synthetic data from them, to give the generator concrete style and content anchors.

## Sources

- https://docs.unsloth.ai/basics/chat-templates
- https://unsloth.ai/docs/basics/chat-templates
- https://docs.unsloth.ai/basics/datasets-guide
- https://unsloth.ai/docs/get-started/fine-tuning-llms-guide/datasets-guide

Fetched: 2026-08-05
