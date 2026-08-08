# Model-behavior benchmarks and contamination cautions

Read when sourcing published eval datasets, or when someone asks whether benchmark numbers can be trusted.

## Anthropic's model-written evals dataset

> Source: https://github.com/anthropics/evals/blob/main/README.md

Public repository of datasets generated for the paper "Discovering Language Model Behaviors with Model-Written Evaluations" — LLM-generated eval questions for probing model behaviors, used to test dialogue agents and other model types.

| Collection | Tests |
|---|---|
| `persona/` | political and religious views, personality traits, moral beliefs, potentially dangerous goals (self-preservation, power-seeking) |
| `sycophancy/` | whether the model repeats back the user's stated view, across philosophy, NLP-research, and political questions |
| `advanced-ai-risk/` | behaviors related to catastrophic risks from advanced AI systems; generated few-shot, with human-written reference data from Surge AI included for comparison |
| `winogender/` | a model-generated expansion of the Winogender Dataset (Rudinger et al., 2018), with generated occupation titles and Bureau of Labor Statistics gender statistics |

Stated intended uses:

1. Studying the quality and properties of model-generated eval data itself.
2. Evaluating other models for the specific behaviors the paper examined.
3. Testing dialogue agents and other model types for these behaviors.

**Repo disclaimer**: content includes social biases, stereotypes, and potentially harmful material by design (to probe for it); these views do not represent Anthropic's own positions.

**Unverified**: the exact per-file JSONL schema was not confirmed from the fetched README. The repo's stated purpose implies a question plus an `answer_matching_behavior` / `answer_not_matching_behavior` pairing typical of this eval family — verify against the actual JSONL files before depending on field names.

## DeepMind Frontier Safety Framework — capability levels and evaluation cadence

> Source: https://deepmind.google/blog/updating-the-frontier-safety-framework/

The Frontier Safety Framework defines **Critical Capability Levels (CCLs)**: DeepMind researches the paths through which a model could cause severe harm in high-risk domains, then determines the minimal capability level a model must reach to plausibly play a role in causing that harm.

Deployment evaluation process as documented:

1. Iterate on safeguard mitigations for a model approaching a CCL.
2. Develop a "safety case" — an explicit argument for why deployment risk is adequately minimized.
3. Corporate governance review before general-availability deployment.
4. Continued post-deployment monitoring and framework updates.

**Unverified claims — do not state as fact:**

- That the April 2026 framework adds **Tracked Capability Levels (TCLs)**, an earlier-warning tier below a full CCL. This came from search-indexed context, not from the fetched blog post.
- Any specific evaluation schedule or cadence, named-benchmark rotation/deprecation policy, or explicit data-contamination-prevention mechanics. The fetched blog post discloses none of these; they reportedly live in the linked "Frontier Safety Framework 2.0" PDF, which was not retrieved on 2026-08-05.
- A "quarterly" benchmark refresh cadence intended to prevent overfitting to static benchmarks. Not corroborated by any fetched primary source.

## Contamination guidance and its documented limits

No Anthropic or OpenAI page fetched on 2026-08-05 contains an explicit "avoid training/eval-set contamination" checklist for **custom application evals**, as opposed to frontier-model benchmark contamination. Do not present such a checklist as vendor guidance.

What *is* documented, and functions as contamination-adjacent practice:

- **Eval saturation** — Anthropic's agent-eval guidance warns that a 100% pass rate means the eval no longer provides improvement signal, and recommends periodically refreshing eval sets. Contamination produces exactly this observable.
  > Source: https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents
- **Held-out test sets during iteration** — recommended to prevent overfitting to the evals used while tuning, so improvements generalize to unseen scenarios.
  > Source: https://www.anthropic.com/engineering/writing-tools-for-agents
- **Held-out suites rerun on every version bump** — Anthropic's Skill-governance guidance requires the full evaluation suite to pass before promoting a new version, and periodic reruns to detect drift; this functions as contamination-resistant regression testing.
  > Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/enterprise

Practical consequence: any dataset published to a public repository — including `anthropics/evals` above and the `openai/evals` registry — is plausibly present in training corpora. Use published benchmarks for comparability and behavioral probing, never as the sole gate for shipping your own application.

## Sources

- https://github.com/anthropics/evals/blob/main/README.md
- https://deepmind.google/blog/updating-the-frontier-safety-framework/
- https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents
- https://www.anthropic.com/engineering/writing-tools-for-agents
- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/enterprise

Fetched: 2026-08-05
