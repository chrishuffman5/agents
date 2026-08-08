# Rate limits and usage tiers

Read when planning capacity, diagnosing a 429, or explaining why an account cannot reach expected throughput.

## Tier structure

> Source: https://developers.openai.com/api/docs/guides/rate-limits

Six tiers, auto-assigned by cumulative spend:

| Tier | Spend threshold to qualify | Monthly usage limit |
|---|---|---|
| Free | none (geography-based eligibility) | $100 |
| Tier 1 | $5 paid | $100 |
| Tier 2 | $50 paid | $500 |
| Tier 3 | $100 paid | $1,000 |
| Tier 4 | $250 paid | $5,000 |
| Tier 5 | $1,000 paid | $200,000 |

Rate limits increase automatically as an organization graduates, across most models.

The thresholds are cheap relative to the headroom they unlock — $1,000 of cumulative spend separates a $1,000/month cap from a $200,000/month cap. When a team is throttled, checking their tier is the first move, well before optimizing prompts.

## Limit dimensions

> Source: https://developers.openai.com/api/docs/guides/rate-limits

- **RPM** — requests per minute
- **TPM** — tokens per minute
- **RPD** — requests per day
- **TPD** — tokens per day
- **IPM** — images per minute
- **Audio minutes per minute** — streaming/realtime models

**Whichever limit is hit first applies.** OpenAI's own example: 20 requests of 100 tokens each will exhaust a 20-RPM limit even though the 2,000 total tokens sent are far under any TPM ceiling. High-frequency, small-payload workloads hit RPM long before TPM — batching several logical items into one request is often the fix, not a bigger token budget.

## Checking current limits

> Source: https://developers.openai.com/api/docs/guides/rate-limits

Response headers:

| Header | Meaning |
|---|---|
| `x-ratelimit-remaining-requests` | Requests left in the current window |
| `x-ratelimit-remaining-tokens` | Tokens left in the current window |
| `x-ratelimit-reset-requests` | When the request allowance resets |
| `x-ratelimit-reset-tokens` | When the token allowance resets |
| `x-ratelimit-limit-project-tokens` | Project-level token ceiling |
| `x-ratelimit-remaining-project-tokens` | Project-level tokens remaining |

`Retry-After`, in seconds, is present on 429 responses — honor it rather than applying your own backoff guess.

Note the project-level headers are distinct from the organization-level ones. A 429 on a project ceiling looks identical to an org-level throttle unless you read both. Limits are viewable in account settings at both levels.

## Batch as a pressure valve

> Source: https://developers.openai.com/api/docs/guides/batch

Batch requests draw from a **separate, substantially higher rate-limit pool**, so moving bulk work to Batch leaves synchronous limits untouched. This is usually a larger throughput win than a tier bump. See `batch.md`.

## Gaps — do not fill from memory

**Exact numeric RPM/TPM/RPD/TPD values per tier per model were not shown** on the fetched rate-limits page — only the tier-to-spend-to-monthly-cap table. Do not quote a specific RPM or TPM number for a model. Direct users to the account dashboard or the live rate-limits page.

## Sources

- https://developers.openai.com/api/docs/guides/rate-limits
- https://developers.openai.com/api/docs/guides/batch

Fetched: 2026-08-05
