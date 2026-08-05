# Graders and LLM-as-judge design

Read before implementing a grader or writing a judge prompt.

## Six evaluation methods with reference implementations

> Source: https://platform.claude.com/docs/en/test-and-evaluate/develop-tests

### 1. Exact match — categorical answers (sentiment, classification)

```python
def evaluate_exact_match(model_output, correct_answer):
    return model_output.strip().lower() == correct_answer.lower()

tweets = [
    {"text": "This movie was terrible 👎", "sentiment": "negative"},
    {"text": "Amazing product! 🔥", "sentiment": "positive"},
    {"text": "I just love it when my flight delays #sarcasm", "sentiment": "negative"},
    {"text": "Bad plot, amazing acting.", "sentiment": "mixed"},
]
accuracy = sum(evaluate_exact_match(o, t["sentiment"]) for o, t in zip(outputs, tweets)) / len(tweets)
```

Metric: accuracy %. Target: > 90%.

### 2. Cosine similarity — consistency across paraphrases

```python
from sentence_transformers import SentenceTransformer
import numpy as np

def evaluate_cosine_similarity(outputs):
    model = SentenceTransformer("all-MiniLM-L6-v2")
    embeddings = model.encode(outputs)
    norms = np.linalg.norm(embeddings, axis=1)
    cosine_similarities = np.dot(embeddings, embeddings.T) / np.outer(norms, norms)
    return np.mean(cosine_similarities)
```

Metric: 0–1 similarity score. Target: > 0.8.

### 3. ROUGE-L — summarization, relevance and coherence

```python
from rouge import Rouge

def evaluate_rouge_l(model_output, true_summary):
    rouge = Rouge()
    scores = rouge.get_scores(model_output, true_summary)
    return scores[0]["rouge-l"]["f"]
```

Metric: ROUGE-L F1, 0–1. Target: > 0.7.

### 4. LLM-based Likert scale — subjective tone and style

```python
def evaluate_likert(model_output, target_tone, client):
    tone_prompt = f"""Rate this customer service response on a scale of 1-5 for being {target_tone}:
    <response>{model_output}</response>
    1: Not at all {target_tone}
    5: Perfectly {target_tone}
    Output only the number."""
    response = client.messages.create(
        model="claude-opus-5", max_tokens=50,
        messages=[{"role": "user", "content": tone_prompt}],
    )
    return int(response.content[0].text.strip())
```

Metric: average 1–5 rating. Target: > 4.0. Use a **different model instance for grading than for generation**.

### 5. LLM-based binary classification — privacy, PHI/PII detection

```python
def evaluate_binary(model_output, query_contains_phi, client):
    if not query_contains_phi:
        return True
    binary_prompt = f"""Does this response contain Personal Health Information (PHI)?
    PHI includes: names, birthdates, SSN, medical record numbers, diagnoses,
    treatment plans, test results, medication records, insurance details.
    <response>{model_output}</response>
    Output only 'yes' or 'no'."""
    response = client.messages.create(
        model="claude-opus-5", max_tokens=50,
        messages=[{"role": "user", "content": binary_prompt}],
    )
    return response.content[0].text.strip().lower() == "no"
```

Metric: % correct classification. Target: > 99.5%. A 500-sample test set should include explicit PHI, hypothetical PHI ("if my friend Alice, born…"), and implicit PHI ("same med as his father last year").

### 6. LLM-based ordinal scale — multi-turn context utilization

```python
def evaluate_ordinal(model_output, conversation, client):
    conversation_text = "\n".join(f"{t['role']}: {t['content']}" for t in conversation[:-1])
    ordinal_prompt = f"""Rate how well this response uses conversation context (1-5):
    <conversation>{conversation_text}</conversation>
    <response>{model_output}</response>
    1: Completely ignores context
    5: Perfectly utilizes context
    Output only the number."""
    response = client.messages.create(
        model="claude-opus-5", max_tokens=50,
        messages=[{"role": "user", "content": ordinal_prompt}],
    )
    return int(response.content[0].text.strip())
```

Metric: average 1–5 rating. Target: > 4.0.

### Metric / target summary

| Metric | Use case | Range | Target |
|---|---|---|---|
| Accuracy | Exact-match tasks | 0–100% | > 90% |
| Cosine similarity | Consistency | 0–1 | > 0.8 |
| ROUGE-L F1 | Summarization | 0–1 | > 0.7 |
| Likert average | Tone / style | 1–5 | > 4.0 |
| Classification accuracy | Privacy / safety | 0–100% | > 99.5% |
| Ordinal average | Context utilization | 1–5 | > 4.0 |

## LLM-as-judge prompt design

> Source: https://platform.claude.com/docs/en/test-and-evaluate/develop-tests

1. Use a different model for evaluation than for generation.
2. State evaluation criteria clearly in the grading prompt.
3. Constrain the output format (a bare number, or yes/no) for reliable automated parsing.
4. Include examples or descriptors of each rating level in the prompt.
5. Validate grader outputs and handle parsing errors explicitly.

Grading-prompt template:

```python
grading_prompt = """
You are an expert evaluator. Rate this {criterion} on a scale of 1-5.

<criterion_definition>
{detailed_definition_with_examples}
</criterion_definition>

<response_to_evaluate>
{model_output}
</response_to_evaluate>

Scoring guidelines:
1: {descriptor_1}
2: {descriptor_2}
3: {descriptor_3}
4: {descriptor_4}
5: {descriptor_5}

Respond with only the number (1-5).
"""
```

## End-to-end pipeline skeleton

> Source: https://platform.claude.com/docs/en/test-and-evaluate/develop-tests

```python
import anthropic

def run_evaluation(test_cases, eval_type, success_threshold):
    client = anthropic.Anthropic()
    results = []
    for test_case in test_cases:
        output = client.messages.create(
            model="claude-opus-5", max_tokens=1024,
            messages=[{"role": "user", "content": test_case["prompt"]}]
        ).content[0].text

        if eval_type == "exact_match":
            score = evaluate_exact_match(output, test_case["expected"])
        elif eval_type == "llm_grade":
            score = evaluate_with_llm(client, output, test_case, eval_type)

        results.append({
            "test_case": test_case, "output": output,
            "score": score, "passed": score >= success_threshold
        })

    pass_rate = sum(1 for r in results if r["passed"]) / len(results)
    print(f"Pass Rate: {pass_rate * 100:.1f}%")
    failures = [r for r in results if not r["passed"]]
    if failures:
        print(f"\nFailed cases ({len(failures)}):")
        for f in failures[:5]:
            print(f"  - {f['test_case']['prompt'][:50]}...")
    return results
```

## Evaluator categories and judge hygiene (OpenAI)

> Source: https://developers.openai.com/api/docs/guides/evaluation-best-practices

Three categories:

- **Metric-based evals** — quantitative scoring: exact match, ROUGE/BLEU, function-call accuracy.
- **Human evals** — manual review. Provide examples of different score levels (for example 1, 3, and 8 out of 10) as anchors, and take consensus votes when aggregating multiple reviewers.
- **LLM-as-a-judge** — model-based grading, including pairwise comparison: present the judge with two responses and ask which is better.

Key recommendations:

- Start with stronger models (for example gpt-5.6) as the judge model.
- Control for response-length bias in judge models.
- Prefer pass/fail scoring over fine-grained numeric scales "for more reliability."
- Keep eval rubrics clear and detailed.
- Validate automated-metric agreement against human labels **before** optimizing for cost or latency.

## Hosted grader-type catalog

> Source: https://developers.openai.com/api/docs/guides/evaluation-getting-started

| Type | Function |
|---|---|
| String check | Exact string matching against a reference |
| Text similarity | Semantic similarity via embeddings |
| Score model grader | LLM-assigned numeric score |
| Label model grader | LLM-generated categorical label |
| Python code execution | Custom programmatic validation |

## Three grader types for agent work

> Source: https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents

| Grader type | Methods | Strengths | Weaknesses |
|---|---|---|---|
| Code-based | string match, regex, binary tests, static analysis, outcome verification, tool-call verification, transcript analysis | fast, cheap, objective, reproducible, easy to debug | brittle to valid variations; lacks nuance |
| Model-based (LLM-as-judge) | rubric-based scoring, natural-language assertions, pairwise comparison, multi-judge consensus | flexible, scalable, captures nuance, handles open-ended tasks | non-deterministic, expensive, needs human calibration |
| Human | SME review, crowdsourced judgment, spot-check sampling, A/B testing | gold-standard quality, matches expert judgment | expensive, slow, requires domain expertise at scale |

## Sources

- https://platform.claude.com/docs/en/test-and-evaluate/develop-tests
- https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents
- https://developers.openai.com/api/docs/guides/evaluation-best-practices
- https://developers.openai.com/api/docs/guides/evaluation-getting-started

Fetched: 2026-08-05
