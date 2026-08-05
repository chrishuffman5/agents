# Codex models, reasoning effort, plans, and credits

Read when choosing a model or effort level for Codex, or when explaining rate limits and overage. **Everything here is time-sensitive** — model IDs, retirement dates, plan prices, and credit rates change; re-verify against the live pages before quoting figures. Facts as of 2026-08-05. For cross-vendor model comparison, use the `model-selection` sibling skill.

## Model IDs

> Source: https://learn.chatgpt.com/docs/models

| Model | Model ID | Description (verbatim from the docs) |
|---|---|---|
| 5.6 Sol | `gpt-5.6-sol` | "Flagship GPT-5.6 model with the strongest capability for complex coding, computer use, research, and cybersecurity." |
| 5.6 Terra | `gpt-5.6-terra` | "Balanced GPT-5.6 model for everyday work, with performance competitive with GPT-5.5 at a lower cost." |
| 5.6 Luna | `gpt-5.6-luna` | "Fast and affordable GPT-5.6 model that delivers strong capability at the lowest cost in the family." |
| 5.3 Codex Spark | `gpt-5.3-codex-spark` | "Text-only research preview model optimized for near-instant, real-time coding iteration. Available to ChatGPT Pro users." |

Legacy GPT-5.5, GPT-5.4, and GPT-5.4 Mini remain available. **GPT-5.4 variants are scheduled to retire 2026-08-31** — raise this proactively whenever a user's `config.toml` or CI job pins one.

Selection strategy from the docs: **Sol** for ambiguous or complex work, **Terra** for everyday tasks, **Luna** for repetitive structured work. Increase reasoning effort only when needed, to optimize cost and speed.

## Reasoning effort

> Source: https://learn.chatgpt.com/docs/models

Five CLI effort levels plus a parallel-subagent mode, set with `model_reasoning_effort` in `config.toml`:

| Level | Docs description |
|---|---|
| Low | "Fast responses with lighter reasoning." |
| Medium (default) | "Balances speed and reasoning depth for everyday tasks." |
| High | "Greater reasoning depth for complex problems." |
| Extra high | "Extra high reasoning depth for complex problems." |
| Max | "Maximum reasoning depth for the hardest problems." |
| Ultra | "Maximum reasoning with automatic task delegation" — uses subagents for parallel task delegation |

`ultra` is the only level that changes the execution shape rather than just depth; it depends on the multi-agent capability (`[features].multi_agent` in `config.toml`).

Order of levers when a task is too slow or too expensive: drop effort first, then drop model tier. Order when quality is short: raise effort first, then raise model tier — effort is the cheaper of the two adjustments.

## Switching models

> Source: https://learn.chatgpt.com/docs/models

| Where | How |
|---|---|
| CLI, interactive | `/model` |
| CLI, flags | `codex --model gpt-5.6`, `codex exec -m gpt-5.6-sol "task"` |
| Config | `model = "gpt-5.6"` in `config.toml` |
| GUI | Model selector beneath the composer in the desktop app, web, or IDE extension |

`review_model` sets a separate model for `/review` — see `ide-and-review.md`.

## Plans

> Source: https://learn.chatgpt.com/docs/pricing

| Plan | Price | Positioning |
|---|---|---|
| Free | $0/month | Basic Codex capabilities for quick coding tasks |
| Go | $8/month | Lightweight coding tasks |
| Plus | $20/month | Focused coding sessions weekly |
| Pro | from $100/month | 5x or 20x higher rate limits than Plus |
| Business | $20/user/month | Requires 2+ users, billed annually |
| Enterprise / Edu | Custom | Enterprise-grade features |

"ChatGPT Work and Codex share usage" across these subscription plans — a heavy ChatGPT user and a heavy Codex user on the same seat draw from the same budget.

Enterprise/Edu numeric pricing is **not published** on the fetched page; it is stated as custom.

## Usage limits

> Source: https://learn.chatgpt.com/docs/pricing

Limits are **rolling 5-hour windows**. Plus-plan examples:

| Model | Messages per 5-hour window |
|---|---|
| GPT-5.6 Sol | 10–100 |
| GPT-5.6 Luna | 250–2,000 |
| GPT-5.4 mini | 60–350 |

Pro 5x (5× Plus): 50–500 Sol; 1,250–10,000 Luna. Pro 20x (20× Plus): 200–2,000 Sol; 5,000–40,000 Luna. **Business has the same limits as Plus.**

The wide ranges are the docs' own — actual allowance varies within them. Do not quote a single number as a guarantee.

## API-key billing

> Source: https://learn.chatgpt.com/docs/pricing

Using an API key instead of a ChatGPT subscription: "Pay only for the tokens Codex uses, based on API pricing," at usage-based per-model rates.

This path does **not** include cloud-based features — GitHub reviews and Slack integration are named explicitly. Anyone whose workflow depends on `@codex review` on pull requests needs subscription auth, not an API key.

## Credits (overage)

> Source: https://learn.chatgpt.com/docs/pricing

Once included plan limits are exceeded, additional usage is purchased as credits:

| Model | Credits / 1M input tokens | Credits / 1M output tokens |
|---|---|---|
| GPT-5.6 Sol | 125 | 750 |
| GPT-5.6 Terra | 50 | 300 |
| GPT-5.6 Luna | 5 | 30 |

"GPT-5.6 usage averages 5–40 credits per message."

Note the ratios: Sol costs 25× Luna on input and 25× on output. Routing structured, repetitive work to Luna is the largest available saving, ahead of any prompt optimization.

The **USD-to-credit conversion rate is not stated** on the fetched page — credits-per-token figures alone cannot be turned into a dollar estimate. Do not compute one.

## Sources

- https://learn.chatgpt.com/docs/models
- https://learn.chatgpt.com/docs/pricing
- https://learn.chatgpt.com/docs/config-file/config-basic

Fetched: 2026-08-05
