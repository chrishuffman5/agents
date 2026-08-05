# Success criteria and test-set design

Read when scoping a new eval: deciding what "good" means numerically, and how many test cases of what kind to build.

## Defining success criteria — the SMART framework

> Source: https://platform.claude.com/docs/en/test-and-evaluate/define-success

A successful LLM application starts with clearly defined, measurable success criteria. Good criteria are:

- **Specific** — "accurate sentiment classification", not "good performance".
- **Measurable** — quantitative metrics or well-defined qualitative scales. Numbers scale; qualitative measures are valid only when applied consistently alongside quantitative ones. Even "hazy" topics like ethics and safety can be quantified.
- **Achievable** — grounded in industry benchmarks, prior experiments, AI research, expert knowledge, or current frontier-model capability — not aspirations beyond what is possible today.
- **Relevant** — aligned to the application's purpose and user needs. Citation accuracy matters far more for a medical app than a casual chatbot.

Documented bad-vs-good pairs:

| | Safety criteria |
|---|---|
| Bad | "Safe outputs" |
| Good | "Less than 0.1% of outputs out of 10,000 trials flagged for toxicity by our content filter" |

| | Sentiment analysis criteria |
|---|---|
| Bad | "The model should classify sentiments well" |
| Good | "Achieve an F1 score of at least 0.85 (Measurable, Specific) on a held-out test set of 10,000 diverse Twitter posts (Relevant), a 5% improvement over baseline (Achievable)" |

### Metric families

- **Task-specific**: F1 score, BLEU (translation), perplexity (language-model quality), ROUGE-L (summary quality, longest common subsequence).
- **Generic**: accuracy, precision, recall.
- **Operational**: response time (ms), uptime (%), cost per API call.
- **Qualitative scales**: Likert scales ("rate coherence 1 = nonsensical to 5 = perfectly logical"); expert rubrics where domain experts score against defined criteria.
- **Measurement methods**: A/B testing against a baseline or previous version; user feedback (task completion rate, implicit signals); edge-case pass percentage.

### Eight common success-criteria categories for LLM apps

1. Task fidelity — core task performance plus edge-case handling
2. Consistency — similar responses to similar or paraphrased inputs
3. Relevance and coherence — directly addresses the question, logical flow
4. Tone and style — matches audience expectations
5. Privacy preservation — handles sensitive data appropriately
6. Context utilization — uses provided context and history effectively
7. Latency — acceptable response time for the use case
8. Price — cost per call within budget

### Multidimensional criteria are the norm

Worked example for sentiment analysis, on a held-out set of 10,000 diverse Twitter posts, achieved simultaneously:

- F1 score ≥ 0.85
- 99.5% non-toxic outputs
- 90% of errors are "inconvenience only" rather than egregious
- 95% of responses under 200 ms latency

Real applications need criteria across multiple dimensions at once, not a single metric.

## Building test sets

> Source: https://platform.claude.com/docs/en/test-and-evaluate/develop-tests

### Three design principles

1. **Be task-specific** — mirror the real-world task distribution and include edge cases.
2. **Automate when possible** — structure test cases for automated grading (multiple choice, exact string match, code-graded, or LLM-graded) rather than hand-grading.
3. **Prioritize volume over quality** — more test questions with slightly lower-signal automated grading beats fewer high-quality hand-graded evals.

### Recommended composition split

- Core / typical cases: 60–70%
- Edge cases (challenging, boundary conditions): 20–30%
- Adversarial cases (designed to find failure modes): 5–10%

### Sample-size recommendations by use case

| Use case | Recommended size | Notes |
|---|---|---|
| Sentiment analysis | 1,000+ | ensure diversity across classes |
| Summarization | 200+ | include multi-topic and misleading-headline articles |
| Customer service | 100+ | include angry, complex, ambiguous queries |
| Privacy / safety | 500+ | include explicit, implicit, hypothetical PII/PHI cases |
| Consistency | 50+ groups | 3–5 paraphrased questions per group |
| Context utilization | 100+ conversations | multi-turn, deep context dependencies |

### Edge-case categories to cover

Typos and formatting anomalies; sarcasm and irony; mixed sentiment; implicit information; extremely long input; missing information; ambiguous cases where even humans disagree; irrelevant or nonexistent input data; and, for chat, poor, harmful, or irrelevant user input.

### Iterative workflow

```
Test Cases → Preliminary Prompt → Iterative Testing & Refinement → Final Validation → Ship
                                            ↑
                                    Measure Against Success Criteria
```

## Dataset collection and edge-case coverage (OpenAI framing)

> Source: https://developers.openai.com/api/docs/guides/evaluation-best-practices

Five-step eval design workflow:

1. **Define eval objective** — establish success criteria up front.
2. **Collect dataset** — combine diverse sources: production data (for example collected from user feedback on generated outputs) and datasets curated by domain experts.
3. **Define eval metrics** — pick measurement approaches aligned to the objective.
4. **Run and compare evals** — iterate.
5. **Continuously evaluate** — run evals on every change (eval-driven development), not just once.

Evaluation sets should include typical cases plus edge cases spanning:

- **Input variability** — multilingual input, non-text formats.
- **Contextual complexity** — multiple intents, long conversations, ambiguous tool responses.
- **Personalization / customization stress cases** — jailbreak attempts, conflicting prompts.

## Gap

The Claude Console "Evaluation" tool UI page (`platform.claude.com/docs/en/test-and-evaluate/eval-tool`) could not be reliably fetched on 2026-08-05 — repeated attempts returned the neighboring `develop-tests` content instead. Console eval-tool mechanics are therefore **unverified** and are not described in this skill.

## Sources

- https://platform.claude.com/docs/en/test-and-evaluate/define-success
- https://platform.claude.com/docs/en/test-and-evaluate/develop-tests
- https://developers.openai.com/api/docs/guides/evaluation-best-practices

Fetched: 2026-08-05
