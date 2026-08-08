# Model lifecycle, deprecation, and retirement (as of 2026-08-05)

Read when the question is about retirement dates, notice periods, migration targets, pinned vs floating model IDs, or auditing usage of a dying model. All dates below are snapshots — re-verify against the source URLs.

## Anthropic — policy and lifecycle terms

> Source: https://platform.claude.com/docs/en/about-claude/model-deprecations

Lifecycle states:

- **Active** — fully supported and recommended.
- **Legacy** — no longer receives updates; may be deprecated in future.
- **Deprecated** — still functional but not recommended; Anthropic assigns a recommended replacement and a retirement date.
- **Retired** — no longer available; requests fail.

**Notice period:** at least **60 days** before retirement for publicly released models, delivered by email to customers with active deployments plus documentation updates.

**Scope caveat:** dates on Anthropic's deprecations page apply to **Anthropic-operated platforms only** — Claude API, Claude Platform on AWS, Microsoft Foundry. **Amazon Bedrock and Google Cloud set their own retirement schedules**, which can differ.

**Auditing usage:** Claude Console → Usage → Export produces a CSV broken down by API key and model — use it to find deprecated-model traffic before retirement.

Anthropic has committed to long-term preservation of model weights ("Commitments on Model Deprecation and Preservation"), with stated intent to eventually make past models available again.

### Current model status

| API model name | State | Deprecated | Tentative retirement |
|---|---|---|---|
| `claude-fable-5` | Active | N/A | Not sooner than June 9, 2027 |
| `claude-opus-5` | Active | N/A | Not sooner than July 24, 2027 |
| `claude-opus-4-8` | Active | N/A | Not sooner than May 28, 2027 |
| `claude-opus-4-7` | Active | N/A | Not sooner than April 16, 2027 |
| `claude-opus-4-6` | Active | N/A | Not sooner than February 5, 2027 |
| `claude-opus-4-5-20251101` | Active | N/A | Not sooner than November 24, 2026 |
| `claude-opus-4-1-20250805` | **Retired** | June 5, 2026 | August 5, 2026 |
| `claude-opus-4-20250514` | **Retired** | April 14, 2026 | June 15, 2026 |
| `claude-sonnet-5` | Active | N/A | Not sooner than June 30, 2027 |
| `claude-sonnet-4-6` | Active | N/A | Not sooner than February 17, 2027 |
| `claude-sonnet-4-5-20250929` | Active | N/A | Not sooner than September 29, 2026 |
| `claude-sonnet-4-20250514` | **Retired** | April 14, 2026 | June 15, 2026 |
| `claude-3-7-sonnet-20250219` | **Retired** | October 28, 2025 | February 19, 2026 |
| `claude-haiku-4-5-20251001` | Active | N/A | Not sooner than October 15, 2026 |
| `claude-3-5-haiku-20241022` | **Retired** | December 19, 2025 | February 19, 2026 |
| `claude-3-haiku-20240307` | **Retired** | February 19, 2026 | April 20, 2026 |

`claude-opus-4-1-20250805` retires **exactly on 2026-08-05** — the snapshot date. Any workload still calling it is failing now.

`claude-mythos-preview` is deprecated; migrate to `claude-mythos-5`.

Note the near-term cluster: `claude-sonnet-4-5-20250929` (not sooner than Sep 29, 2026), `claude-haiku-4-5-20251001` (not sooner than Oct 15, 2026), and `claude-opus-4-5-20251101` (not sooner than Nov 24, 2026) are the next Claude IDs to age out. Anything pinned to them needs a migration plan inside 2026.

### Deprecation history and replacements

| Retirement date | Deprecated model | Replacement |
|---|---|---|
| Aug 5, 2026 | `claude-opus-4-1-20250805` | `claude-opus-4-8` |
| Jun 15, 2026 | `claude-sonnet-4-20250514` | `claude-sonnet-4-6` |
| Jun 15, 2026 | `claude-opus-4-20250514` | `claude-opus-4-8` |
| Apr 20, 2026 | `claude-3-haiku-20240307` | `claude-haiku-4-5-20251001` |
| Feb 19, 2026 | `claude-3-5-haiku-20241022` | `claude-haiku-4-5-20251001` |
| Feb 19, 2026 | `claude-3-7-sonnet-20250219` | `claude-sonnet-4-6` |
| Jan 5, 2026 | `claude-3-opus-20240229` | `claude-opus-4-8` |
| Oct 28, 2025 | `claude-3-5-sonnet-20240620` | `claude-sonnet-4-6` |
| Oct 28, 2025 | `claude-3-5-sonnet-20241022` | `claude-sonnet-4-6` |
| Jul 21, 2025 | `claude-2.0`, `claude-2.1`, `claude-3-sonnet-20240229` | `claude-opus-4-8` / `claude-sonnet-4-6` |
| Nov 6, 2024 | `claude-1.x`, `claude-instant-1.x` | `claude-haiku-4-5-20251001` |

### Deprecated API parameters

`temperature`, `top_p`, and `top_k` are deprecated on **Claude Opus 4.7 and later** — passing a non-default value returns a **400 error**. Move the intent into the prompt. This is the single most common breakage when migrating an older Claude integration forward.

## OpenAI — policy and shutdown schedule

> Source: https://developers.openai.com/api/docs/deprecations

Terminology: "deprecation" is the retirement process itself. Once announced, a model is immediately deprecated and assigned a **shutdown date**; at shutdown it becomes inaccessible. OpenAI distinguishes **deprecated** (in the retirement pipeline) from **legacy** (no longer updated, will eventually be deprecated).

**Minimum notice periods:**

- **Generally available models** — at least **6 months**.
- **Specialized variants** (chat variants, Codex models, deep research versions) — at least **3 months**.
- **Preview models** — much shorter, e.g. **2 weeks**.
- Safety or compliance concerns can accelerate any of these.

**Announcement channels:** direct email to affected customers, documentation updates, blog posts for major changes, and dashboard notifications.

**Fine-tuned models:** a fine-tune built on a deprecated base is **not** affected by that base's deprecation and keeps serving — but you can no longer create *new* fine-tunes from the deprecated base.

### Current and upcoming shutdowns

| Shutdown date | Models affected | Recommended replacement |
|---|---|---|
| January 20, 2027 | `gpt-realtime`, `gpt-audio`, `gpt-4o-realtime`, `gpt-4o-audio` (legacy audio/realtime/transcription families and snapshots; notified July 20, 2026) | `gpt-realtime-2.1`, `gpt-audio-1.5` |
| December 11, 2026 | `gpt-5-2025-08-07`, `gpt-5-mini-2025-08-07`, `o3-2025-04-16` | `gpt-5.6-sol` |
| December 1, 2026 | Older GPT Image models | Newer image models |
| October 23, 2026 | `gpt-3.5-turbo`, `gpt-4`, `gpt-4-turbo`, `o1`, `o3-mini` | `gpt-5.6` series |

## Google — preview lifecycle

> Source: https://ai.google.dev/gemini-api/docs/models

- **Stable** models point to a specific snapshot and generally do not change under you.
- **Preview** models may be used in production but can be deprecated with **at least 2 weeks' notice**.
- **Experimental** models are not for production.
- **`-latest`** suffixes are floating pointers to the newest release in a family, not pinned snapshots.

**Concrete precedent:** `gemini-3-pro-preview` **was shut down March 9, 2026**, with migration guidance pointing to `gemini-3.1-pro-preview`. Since `gemini-3.1-pro-preview` is itself a preview and is the only Pro-tier option in the 3.x line, any Gemini Pro dependency today carries 2-week-notice risk.

Retirement dates for Claude models on Google Cloud are set by **Google**, not Anthropic — check Google's "Claude models on Agent Platform" documentation for those.

## Migration rules of thumb

- Pin production to snapshot IDs, never to floating pointers; upgrade deliberately behind an eval gate.
- Budget migration windows against the **shortest** notice period in your dependency set — one preview model drags the whole system to 2 weeks.
- Re-run evals on the replacement before switching; replacement recommendations are the vendor's, not a guarantee of behavioral parity.
- Re-baseline token counts and cost when crossing the Claude 4.7 tokenizer boundary (~30% more tokens for the same text).
- Strip `temperature`/`top_p`/`top_k` when moving onto Opus 4.7+.
- On OpenAI, plan re-tuning onto a supported base before a base model's shutdown, since new fine-tunes on a deprecated base are blocked.

## Sources

- https://platform.claude.com/docs/en/about-claude/model-deprecations
- https://platform.claude.com/docs/en/about-claude/models/overview
- https://developers.openai.com/api/docs/deprecations
- https://ai.google.dev/gemini-api/docs/models
- https://ai.google.dev/gemini-api/docs/models/gemini-3-pro-preview
- https://platform.claude.com/docs/en/build-with-claude/claude-on-vertex-ai

Fetched: 2026-08-05
