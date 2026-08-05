# OpenAI eval surfaces: Evals API, Datasets, and the `openai/evals` framework

Read when choosing or operating an OpenAI-side eval harness. Check `versions/openai-hosted-evals-2026.md` first — the hosted Evals platform has a published sunset.

## Evals API — creating and running an eval

> Source: https://developers.openai.com/api/docs/guides/evals

The Evals API enables programmatic testing of model outputs against specified style and content criteria — useful for building reliable LLM applications and for regression-testing model upgrades.

Three-step core process:

1. Describe the task as an eval configuration (`data_source_config` + `testing_criteria`).
2. Run the eval against test inputs.
3. Analyze results and iterate.

### `data_source_config`

Defines the schema for test data using JSON Schema:

- `type` — `"custom"` for programmatic evals.
- `item_schema` — JSON Schema describing each test item's structure.
- `include_sample_schema` — set `true` to reference the model's output via `{{ sample.* }}` in graders.

```json
{
  "type": "object",
  "properties": {
    "ticket_text": { "type": "string" },
    "correct_label": { "type": "string" }
  },
  "required": ["ticket_text", "correct_label"]
}
```

### `testing_criteria` (graders)

Template syntax: `{{ item.* }}` references test-data properties; `{{ sample.output_text }}` references the model-generated output. Grader type documented on this page: **`string_check`**, which compares output against a reference and supports the `eq` operation.

```json
{
  "type": "string_check",
  "name": "Match output to human label",
  "input": "{{ sample.output_text }}",
  "operation": "eq",
  "reference": "{{ item.correct_label }}"
}
```

### Full create-eval request

```bash
curl https://api.openai.com/v1/evals \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "IT Ticket Categorization",
    "data_source_config": {
      "type": "custom",
      "item_schema": {
        "type": "object",
        "properties": {
          "ticket_text": { "type": "string" },
          "correct_label": { "type": "string" }
        },
        "required": ["ticket_text", "correct_label"]
      },
      "include_sample_schema": true
    },
    "testing_criteria": [{
      "type": "string_check",
      "name": "Match output to human label",
      "input": "{{ sample.output_text }}",
      "operation": "eq",
      "reference": "{{ item.correct_label }}"
    }]
  }'
```

### Run configuration and test-data format

A run executes a prompt against the test data. Configuration includes `model` (e.g. `"gpt-5.6"`), `input_messages` (template-based developer/user messages referencing `{{ item.* }}`), and `source` (an uploaded test-data file `file_id`).

Test data is JSONL, one item per line wrapped in an `item` key:

```json
{ "item": { "ticket_text": "My monitor won't turn on!", "correct_label": "Hardware" } }
{ "item": { "ticket_text": "I'm in vim and I can't quit!", "correct_label": "Software" } }
```

### Run response fields

- `status` — `"queued"`, `"completed"`, etc.
- `result_counts` — total / errored / failed / passed.
- `per_testing_criteria_results` — pass/fail broken out per grader.
- `per_model_usage` — token consumption and invocation metrics.
- `report_url` — dashboard link for visual result exploration.

## Datasets — the recommended entry point

> Source: https://developers.openai.com/api/docs/guides/evaluation-getting-started

Datasets is positioned ahead of Evals in the recommended learning path given the Evals sunset timeline. It does not fully replace Evals; it is the recommended starting point, with Evals used to scale once a workflow is proven.

1. **Create a Dataset** — evaluation page (`platform.openai.com/evaluation`) → Datasets tab → Create → name it → add data via the visual interface or CSV upload. Treat a Dataset as "a dynamic space, expanding your set of evaluation data over time."
2. **Build a Prompt** — "Add prompt" to create or select a prompt; configure temperature/top_p; add variables (e.g. `company`) referencing dataset columns; attach tools (web search, MCP, etc.).
3. **Generate and annotate outputs** — "Generate output" populates results; annotate via the output / rating / output_feedback columns to provide ground truth.
4. **Add graders** — Grade → New grader → select a grader type; graders can reference dataset columns for validation.

Data format is CSV with input and ground-truth columns, accessible to both prompts and graders. Grader types available here: string check, text similarity (embeddings), score model grader, label model grader, Python code execution.

## `openai/evals` open-source framework

> Source: https://github.com/openai/evals
> Source: https://github.com/openai/evals/blob/main/README.md

"Evals is a framework for evaluating large language models (LLMs) or systems built using LLMs." It ships a registry of pre-built benchmarks (distributed via Git-LFS) plus tooling for building custom evals. MIT licensed. Private evals against your own data are supported without public exposure; results can integrate with Weights & Biases.

### Setup

```bash
pip install evals              # to run evals
pip install -e .               # development install, for creating evals
pip install -e .[formatters]   # optional formatting/linting
pre-commit install
```

- Python 3.9 minimum.
- `OPENAI_API_KEY` environment variable.
- Git-LFS to pull registry data. Optional Snowflake credentials (`SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_DATABASE`, `SNOWFLAKE_USERNAME`, `SNOWFLAKE_PASSWORD`) for logging.

```bash
cd evals
git lfs fetch --all && git lfs pull
# or, for one eval:
git lfs fetch --include=evals/registry/data/${your_eval} && git lfs pull
```

Directory layout: `/evals` (framework code), `/evals/registry/data` (Git-LFS benchmark data), `/docs`, `/examples`, `/scripts`, `/tests/unit/evals`.

**Contribution constraint, stated explicitly:** "we are currently not accepting evals with custom code!" Public-registry contributions must be model-graded evals defined via YAML, or evals following the existing templates.

### Data format

> Source: https://github.com/openai/evals/blob/main/docs/build-eval.md

JSONL, one data point per line:

- `"input"` — the prompt, preferably in chat format (list of role/content messages).
- `"ideal"` — for basic template evals (Match/Includes/FuzzyMatch), a string or list of correct reference answers.
- Additional keys as needed; model-graded evals require extra fields to fill prompt variables not covered by the template's `args`.

Registry filenames seen: `match.jsonl` (basic templates), `samples.jsonl` (model-graded).

### Registry YAML

```yaml
<eval_name>:
  id: <eval_name>.<split>.<version>
  description: <description>
  metrics: [accuracy]

<eval_name>.<split>.<version>:
  class: evals.elsuite.basic.match:Match
  args:
    samples_jsonl: <eval_name>/samples.jsonl
```

Naming: `eval_name` groups comparable scores, `split` is the data partition (dev/test/val), `version` is a free-form descriptive identifier.

Model-graded workflow: create or customize a YAML in `evals/registry/modelgraded/` → build the dataset and register the eval with an `eval_type` → execute → (recommended) add a meta-eval with choice labels to validate the grader's own quality.

Contribution bar for a strong eval: thematic consistency across related prompts; appropriate difficulty (challenging but achievable); clear signal via quality reference answers or rubrics; careful engineering with prompt optimization and spot-checked results.

### Built-in templates

> Source: https://github.com/openai/evals/blob/main/docs/eval-templates.md

| Template | Logic |
|---|---|
| `Match` | completion **starts with** any reference answer — `any([a.startswith(b) for b in B])` |
| `Includes` | any reference answer **appears within** the completion — `any([(b in a) for b in B])` |
| `FuzzyMatch` | bidirectional substring match — `any([(a in b or b in a) for b in B])` |
| `JsonMatch` | JSON structural/value equality, ignoring key order and whitespace |

**`ModelBasedClassify`** is the LLM-as-judge template: it obtains the completion, wraps it in an evaluation prompt, and parses the grader's response into a metric. Parameters:

- `prompt` — evaluation instruction with `{key}` placeholders filled from the data row.
- `input_outputs` — mapping of inputs to the completions being evaluated.
- `choice_strings` — allowed response options, e.g. `"ABCDE"` or `["Yes", "No"]`.
- `choice_scores` *(optional)* — numeric score per choice for metric aggregation.
- `eval_type` *(optional)* — `"cot_classify"` (reasoning then answer, **recommended**), `"classify_cot"` (answer then reasoning), `"classify"` (answer only).
- `output_template` *(optional)* — formatting spec for the model's output.

Pre-built configs referenced: `fact.yaml` (factual consistency), `closedqa.yaml` (relevance/conciseness/correctness for QA), `battle.yaml` (head-to-head comparison).

### Running evals — `oaieval`

> Source: https://github.com/openai/evals/blob/main/docs/run-evals.md

```
oaieval [model] [eval_name]
oaieval gpt-3.5-turbo test-match
```

- `--no-local-run` — log to a Snowflake database instead of local storage.
- `--record_path` — custom log directory (default `tmp/evallogs`).
- `oaieval --help` — full flag list.

The model argument accepts any OpenAI-API model name or a custom `CompletionFn` registered under `evals/registry/completion_fns`. Events are recorded to local JSONL logs by default.

### Completion functions — pointing the harness at an agent

> Source: https://github.com/openai/evals/blob/main/docs/completion-fns.md

A Completion Function generalizes "get a completion" beyond a raw model call: it can wrap browsing, tool use, or any other operation before producing final text. Contract: input is a text string or chat-format conversation; output is a list of text strings. This is how you evaluate an **agent or harness** rather than a bare model through the same eval runner.

```yaml
langchain/llm/flan-t5-xl:
  class: evals.completion_fns.langchain_llm:LangChainLLMCompletionFn
  args:
    llm: HuggingFaceHub
    llm_kwargs:
      repo_id: google/flan-t5-xl
```

For external or private completion functions, pass `--registry_path` to `oaieval` instead of modifying the core codebase.

### Fully custom evals

> Source: https://github.com/openai/evals/blob/main/docs/custom-eval.md

Subclass `evals.Eval` and override two methods:

- **`run()`** — CLI entry point. Load datasets with `evals.get_jsonl()`, call `self.eval_all_samples(recorder, test_samples)`, then aggregate and return metrics, e.g. `{"accuracy": evals.metrics.get_accuracy(...)}`.
- **`eval_sample()`** — processes one test case: build a prompt with the task statement, few-shot examples, and the test question; call `self.completion_fn(prompt=..., temperature=0.0, max_tokens=1)`; check correctness via `evals.record_and_check_match()`. Receives an `rng` for reproducibility. Do not pass the recorder manually — `eval_all_samples` sets it as the default.

Register the custom eval the same way as a basic one (YAML `class:` path + `args:` matching the `__init__` signature), then `oaieval gpt-3.5-turbo arithmetic`.

Key modules: `evals/api.py` (sampling utilities), `evals/record.py` (result logging), `evals/metrics.py` (aggregation, e.g. `get_accuracy`).

## Sources

- https://developers.openai.com/api/docs/guides/evals
- https://developers.openai.com/api/docs/guides/evaluation-getting-started
- https://github.com/openai/evals
- https://github.com/openai/evals/blob/main/README.md
- https://github.com/openai/evals/blob/main/docs/build-eval.md
- https://github.com/openai/evals/blob/main/docs/eval-templates.md
- https://github.com/openai/evals/blob/main/docs/run-evals.md
- https://github.com/openai/evals/blob/main/docs/custom-eval.md
- https://github.com/openai/evals/blob/main/docs/completion-fns.md

Fetched: 2026-08-05
