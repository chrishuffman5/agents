---
name: model-selection
description: "Cross-vendor frontier-model catalog and capability-tier choice as of 2026-08-05 — exact model IDs, per-MTok pricing, context/output limits, knowledge cutoffs, deprecation and retirement schedules, and Bedrock/Vertex/Foundry availability across Anthropic Claude, OpenAI GPT, and Google Gemini. WHEN: \"which model should I use\", \"Opus vs Sonnet vs Haiku\", \"GPT-5.6 Sol vs Terra vs Luna\", \"Gemini Pro vs Flash vs Flash-Lite\", \"what is the model ID for\", \"model pricing\", \"cost per million tokens\", \"context window\", \"knowledge cutoff\", \"model deprecation\", \"retirement date\", \"downgrade the model to cut cost\", \"Claude on Bedrock\", \"Claude on Vertex\", \"cheaper model that still works\". Do NOT use for: Anthropic-only API mechanics — request params, tool_use/tool_result, streaming, cache_control breakpoints, batches, token counting — even when cost is the subject; that is `claude-api` (come here instead when the question compares models, tiers, or vendors, or asks about deprecation and cloud availability). Also not for: building agents on the Agent SDK — `agent-sdk`; the Claude Code harness and its model setting — `claude-code`; choosing an overall architecture (harness vs SDK vs raw API, workflow vs agent) — `overview`; training or LoRA-tuning a model — `fine-tuning`; measuring which model actually wins on your task — `evals`."
license: MIT
---

# Model Selection (cross-vendor)

Picking the model ID, capability tier, and hosting platform for a workload across Anthropic, OpenAI, and Google — and knowing when the answer has expired.

## Freshness contract — read first

**This catalog is a snapshot of 2026-08-05. Treat every number in it as stale until re-verified.** Model IDs, prices, context limits, and retirement dates change monthly.

- Always re-fetch the vendor page cited at the bottom of the relevant reference file before quoting a price, an ID, or a retirement date to a user who will act on it. Cheap to check, expensive to get wrong.
- Always state the as-of date alongside any figure you give ("as of 2026-08-05, per Anthropic's pricing page"). A price without a date is a bug.
- Never invent or "remember" a model ID. Model IDs are string literals — a wrong one is a hard 404/400, and plausible-looking guesses (`claude-opus-5-20260601`, `gpt-5.6-codex`, `gemini-3.6-pro`) are the most common failure. Take IDs only from the reference tables here or from a live vendor page.
- Programmatic ground truth for Claude: `GET /v1/models` returns `max_input_tokens`, `max_tokens`, and a `capabilities` object per model. Run `scripts/list-claude-models.sh` instead of asserting from memory.
- Items the source docs did not publish are marked **UNVERIFIED** in the references. Repeat that marker; never launder it into a fact.

## Default picks (when the user gives you no constraints)

| Need | Pick | Why |
|---|---|---|
| Complex agentic coding, enterprise work (Claude) | `claude-opus-5` | Anthropic's own default recommendation |
| Highest available Claude capability | `claude-fable-5` | Most capable widely released Claude; $10/$50 per MTok |
| Most production Claude workloads | `claude-sonnet-5` | Speed/intelligence balance; $2/$10 through Aug 31 2026, $3/$15 after |
| High-volume cheap Claude work | `claude-haiku-4-5` | $1/$5, fastest, 200k context |
| Frontier OpenAI | `gpt-5.6-sol` | $5/$30, 1.05M context |
| Balanced OpenAI | `gpt-5.6-terra` | $2/$12, same context/cutoff as Sol |
| High-volume OpenAI | `gpt-5.6-luna` | $0.20/$1.20, same context/cutoff as Sol |
| Frontier Google | `gemini-3.1-pro-preview` | Pro tier is preview-only in the 3.x line — accept preview risk or use `gemini-2.5-pro` |
| Balanced/agentic Google | `gemini-3.6-flash` | $1.50/$7.50, GA, default model for Antigravity |
| Cheapest Google | `gemini-3.5-flash-lite` or `gemini-2.5-flash-lite` | $0.30/$2.50 and $0.10/$0.40 |

Full tables with cloud IDs, cutoffs, and cache/batch rates: `references/claude-catalog.md`, `references/openai-catalog.md`, `references/gemini-catalog.md`.

## Cross-vendor tier map (2026-08-05)

Use for "what is the equivalent of X on vendor Y" and for cost comparison at equal capability tier. Prices are per million tokens, input/output, standard (non-batch, non-cached, non-long-context) first-party rates.

| Tier | Anthropic | OpenAI | Google |
|---|---|---|---|
| Above-frontier / limited | `claude-mythos-5` $10/$50 (invite-only) | `gpt-5.5-pro` $30/$180 | — |
| Frontier | `claude-fable-5` $10/$50 | `gpt-5.6-sol` $5/$30 | `gemini-3.1-pro-preview` $2–4/$12–18 (preview) |
| Workhorse-high | `claude-opus-5` $5/$25 | `gpt-5.6-terra` $2/$12 | `gemini-3.6-flash` $1.50/$7.50 |
| Balanced | `claude-sonnet-5` $2/$10 (→$3/$15 Sep 1 2026) | `gpt-5.4` $2.50/$15 | `gemini-3.5-flash` $1.50/$9 |
| Cheap/high-volume | `claude-haiku-4-5` $1/$5 | `gpt-5.6-luna` $0.20/$1.20 | `gemini-3.5-flash-lite` $0.30/$2.50 |
| Floor | — | `gpt-4o-mini` $0.15/$0.60 (legacy) | `gemini-2.5-flash-lite` $0.10/$0.40 |

Rows align on *positioning*, not on measured capability — vendors do not benchmark identically and tier names are marketing. Treat the map as a shortlist generator, then decide with your own evals.

Two structural asymmetries worth stating out loud to users:

- **Google has no GA Pro-tier model in the 3.x line.** Pro is preview (`gemini-3.1-pro-preview`) or a generation back (`gemini-2.5-pro`). A Google-only stack that needs GA frontier reasoning is constrained today.
- **OpenAI's cheap tier is unusually cheap relative to its frontier tier** (Luna is 1/25th of Sol on input, and shares Sol's 1.05M context and Feb 16 2026 cutoff), which makes tier-routing inside GPT-5.6 especially effective.

## How to choose

**Optimize accuracy first, cost second.** Iterate on prompt and architecture until the task hits its accuracy target; only then hunt for the cheapest model that holds that accuracy. Reversing the order produces a cheap model that is wrong, which costs more than the expensive model. (OpenAI's published framework; it generalizes.)

**Derive the accuracy target from money, not from a round number.** Compare the value of a correct output against the remediation cost of a wrong one. OpenAI's worked classifier example — $50 saved per correct call, $300 lost per wrong one — yields a break-even threshold of 85.8%, not "95% because that sounds good."

**Move down the tier ladder, not across vendors, when cost hurts.** Within a family the tiers share the API surface, so a tier swap is a one-line change and an eval re-run. Ladders as of 2026-08-05:

- Claude: Fable 5 → Opus 5 → Sonnet 5 → Haiku 4.5
- OpenAI: `gpt-5.6-sol` → `gpt-5.6-terra` → `gpt-5.6-luna`
- Gemini: Pro → Flash → Flash-Lite (Google's own heuristic; Flash is claimed to cover 80–90% of production workloads at ~1/10 Pro cost)

**Never pick a model on price alone.** Cheaper-per-token frequently loses on total cost: a weak model retries, produces longer outputs, and burns more agent turns. Compare cost *per successfully completed task*, measured on your own eval set (see the `evals` skill), not $/MTok.

**Route by task, not by one global default.** A production system usually wants two or three models: a frontier tier for planning/hard reasoning, a mid tier for the main loop, a cheap tier for classification, extraction, routing, and subagent fan-out. Anthropic's guidance is the same shape — Haiku for simple tasks, Sonnet for most production, Opus for the hardest reasoning.

**Consider a small fine-tune before a bigger model.** OpenAI's published comparison: GPT-4o few-shot hit 91.5% for $11.92 per 1,000 articles; a fine-tuned GPT-4o-mini hit the same 91.5% for $0.21. When the task is narrow, repeated, and has labeled data, tuning a small model beats renting a big one — hand off to `fine-tuning` and `training-datasets`.

## Constraints that eliminate candidates before price does

Check these first; they are hard filters, not preferences.

- **Knowledge cutoff.** If the task depends on post-cutoff facts, no amount of intelligence saves it — add retrieval or web search. Claude Opus 5 has the latest reliable cutoff in the Claude line (May 2026); Haiku 4.5 is Feb 2025. GPT-5.6 tiers are Feb 16 2026. Gemini 2.5 is Jan 2025; **Gemini 3.x cutoffs are UNVERIFIED — not published on the fetched docs pages.**
- **Context window.** Claude Fable 5 / Opus 5 / Sonnet 5 are 1M; Haiku 4.5 is 200k. GPT-5.6 tiers are 1.05M; `gpt-5.5`/`gpt-5.4` are capped at 272k. Gemini 2.5 Pro/Flash and 3.1 Pro Preview are 1,048,576 input.
- **Max output.** Claude frontier tiers 128k, Haiku 4.5 64k; OpenAI GPT-5.6 128k; Gemini 65,536 (3.6 Flash: 64,000). A 200k-token report is not one request on any of them. Claude's Message Batches API reaches 300k output on Opus 5 / 4.8 / 4.7 / 4.6 / Sonnet 5 / Sonnet 4.6 via the `output-300k-2026-03-24` beta header.
- **Thinking mode.** On Claude, adaptive thinking is always on for Fable 5 and available on Opus 5 / Sonnet 5; explicit `thinking.type: "enabled"` extended thinking survives only on Haiku 4.5 and older models. Do not write `thinking` blocks for Fable/Opus 5/Sonnet 5.
- **Deprecated sampling params.** `temperature`, `top_p`, `top_k` return **400** on Claude Opus 4.7 and later. Porting an older Claude integration forward means deleting them and moving the intent into the prompt.
- **Tokenizer change.** Claude 4.7+ (including Fable 5) uses a newer tokenizer: the same text yields roughly **30% more tokens** than Sonnet 4.6 and earlier. Re-baseline cost and context-fit estimates when migrating across that line — a prompt that fit before may not, and a budget forecast built on old counts under-reports by ~30%.
- **Platform feature gaps.** Bedrock and Google Cloud both lack Files API, server-side tools, Agent Skills, MCP connector, and Batches on Claude. If the design depends on those, it must run first-party. Details: `references/cloud-availability.md`.

## Cost levers that beat model downgrades

Apply these before dropping a tier — they often deliver a bigger saving with zero accuracy loss.

- **Prompt caching.** Claude cache reads cost 0.1x base input; a 5-minute cache write costs 1.25x and pays for itself after one hit, a 1-hour write costs 2x and pays off after two. OpenAI cached input is ~10x cheaper than fresh input (Sol $0.50 vs $5.00). Vertex gives a 90% discount on cached tokens. Any repeated system prompt, tool schema, or document should be cached.
- **Batch.** 50% off input and output on all three vendors (Anthropic Message Batches, OpenAI Batch API, Gemini Batch). Free money for anything not user-facing.
- **Long-context meters differ, and this is a trap.** Claude 4.6+ charges the **same rate across the full 1M window** — a 900k-token request is priced like a 9k one. OpenAI charges a **separate higher long-context rate** (Sol $5/$30 → $10/$45; Terra $2/$12 → $4/$18; Luna $0.20/$1.20 → $0.40/$1.80). Gemini Pro tiers **step up past 200k input** (2.5 Pro $1.25 → $2.50; 3.1 Pro Preview $2.00 → $4.00), while Gemini Flash/Flash-Lite are flat. A huge-context design that is cheap on Claude can be double-priced on OpenAI or Gemini Pro.
- **Multipliers stack against you.** Claude `inference_geo: "us"` = 1.1x on all token categories; Bedrock/Vertex regional and multi-region endpoints = +10% over global; Vertex priority tier = 1.8x; OpenAI fast mode = 2x and regional residency = +10% for models released after 2026-03-05; Claude fast mode (research preview, Opus 5 / 4.8 only, first-party only) reprices to $10/$50. Compute the effective rate, not the headline rate.
- **Tool-use overhead is real but small.** Claude tool definitions add a system-prompt surcharge that varies sharply by model — Opus 5 `auto` is 286 tokens vs Opus 4.7's 675. Server tools bill separately: web search $10/1,000 searches, web fetch free beyond tokens.

## Estimating spend before committing

Give users a number, not a vibe. The estimate needs four inputs and one multiplier pass.

1. **Tokens per unit of work** — input (system + tools + context + user) and output separately. Count with the vendor's token-counting endpoint on a real sample; do not estimate from characters, especially on Claude 4.7+ where the tokenizer shift adds ~30%.
2. **Units per period** — requests/day, or agent turns/session × sessions/day. Agents multiply: one user task can be 20+ model calls.
3. **Cache hit fraction** — what share of input tokens are repeated system prompt, tool schemas, or pinned documents. This is usually the largest single lever.
4. **Batch-eligible fraction** — anything not blocking a human.

Then apply multipliers in order: cache read rate on the cached share, batch 0.5x on the batch share, long-context meter if requests exceed the vendor's threshold, then residency/priority/fast-mode multipliers.

Anthropic's published worked examples anchor the scale: an Opus 5 agent session of 50k input + 15k output tokens costs $0.25 + $0.375 plus $0.08/hour session runtime = **$0.705**; moving 40k of those input tokens to cache reads drops it to **$0.525**. A ~3,700-token support-ticket conversation on Haiku 4.5 runs **~$37 per 10,000 tickets**. If a proposed design lands orders of magnitude above these, the token budget is the problem, not the model choice.

## Facts to establish before recommending

If the user has not stated these, ask — a recommendation made without them is a guess:

- **Latency budget.** Interactive chat, agent background loop, and overnight batch have three different answers. Claude comparative latency runs Fastest (Haiku 4.5) → Fast (Sonnet 5) → Moderate (Opus 5) → Slower (Fable 5); capability and latency trade directly.
- **Context size per request.** Under 200k opens the whole catalog including Haiku 4.5 and Claude/Gemini 2.5 tiers; above 200k narrows it and triggers long-context meters on OpenAI and Gemini Pro.
- **Cutoff sensitivity.** Does the task need facts newer than the model's cutoff, and is retrieval or web search already in the design?
- **Hosting constraint.** First-party, Bedrock, Vertex, Foundry, or "must be in EU/US region" — this can eliminate models and features before price matters.
- **Volume and burstiness.** Decides whether batch and caching apply, and whether Bedrock's 2M-input-TPM default quota (raisable to 4M) is enough.
- **Existing evals.** If none exist, the honest answer is "start on the mid tier and build an eval" — hand to `evals` — rather than a confident tier pick.

## Non-text modalities

Text-tier reasoning quality does not carry over to audio, image, or video — those are separate model families with separate IDs and radically different unit economics. Pick them independently.

- **All current Claude models** take text and image input and emit text only. No Anthropic audio, image-generation, or video model appears in the current catalog — a multimodal-output requirement forces OpenAI or Google (or a specialist vendor) for that leg of the system.
- **Audio/realtime (OpenAI):** `gpt-realtime-2.1` bills audio at $32 in / $64 out per MTok — roughly 6x its own text rate ($4/$24); `gpt-realtime-2.1-mini` is $10/$20 audio. Realtime is the most expensive thing in the catalog per minute of use; budget it separately.
- **Image generation:** OpenAI `gpt-image-2` / `gpt-image-1.5` bill image tokens at $8 in / $30–32 out per MTok. Google's line is `gemini-3.1-flash-image` ("Nano Banana 2", ~$0.045–$0.151/image), `gemini-3.1-flash-lite-image`, `gemini-3-pro-image` (4K), and `gemini-2.5-flash-image` ($0.039/image standard, $0.0195 batch). Price per *image*, not per token, when comparing.
- **Video:** OpenAI Sora 2 at $0.10/sec (720p) and Sora 2 Pro at $0.30–$0.70/sec; Google Veo 3.1 at $0.05–$0.60/sec. Seconds-based billing makes long clips expensive fast.
- **Embeddings:** OpenAI `text-embedding-3-small` $0.02 and `text-embedding-3-large` $0.13 per MTok; Google `gemini-embedding-001` $0.15 text, `gemini-embedding-2-preview` $0.20 text / $0.45 image / $6.50 audio / $12.00 video. Embedding cost is usually noise next to generation cost — optimize recall quality first.
- **Grounding/search is metered on top of tokens.** Claude web search $10/1,000 searches (web fetch free); Gemini Google Search grounding 5,000 free requests/month then $14/1,000 on 3.x models, 1,500 RPD free then $35/1,000 on 2.5; Vertex custom-data grounding $2.50/1,000 prompts.

## Lifecycle and migration

- **Every Claude model ID is a pinned snapshot, including the dateless ones.** From the 4.6 generation on, IDs like `claude-opus-5` look evergreen but are fixed releases. Do not assume they auto-upgrade, and do not assume they never retire.
- **Gemini `-latest` suffixes are the opposite: floating pointers.** `gemini-flash-latest` moves under you. Never pin production to `-latest`; pin the snapshot and upgrade deliberately.
- **Notice periods differ by an order of magnitude.** Anthropic: ≥60 days for publicly released models. OpenAI: ≥6 months GA, ≥3 months for specialized variants (Codex, deep research, chat variants), ~2 weeks for previews. Google: ≥2 weeks for preview models. Build the migration budget around the shortest-notice model you depend on.
- **Preview models are a production risk you accept explicitly.** `gemini-3-pro-preview` was shut down 2026-03-09 with migration to `gemini-3.1-pro-preview` — that is the real-world precedent for the 2-week policy. Choosing `gemini-3.1-pro-preview` for Pro-tier Gemini means signing up for the same risk.
- **Cloud retirement dates are not the vendor's dates.** Anthropic's deprecation page governs Anthropic-operated platforms only (Claude API, Claude Platform on AWS, Microsoft Foundry). **Amazon Bedrock and Google Cloud set their own schedules.** Check the cloud's page for a workload running there.
- **Audit before you migrate.** Claude Console → Usage → Export gives CSV by API key and model; that is how you find who is still calling a retiring ID. OpenAI notifies affected customers by email plus dashboard notices.
- **Fine-tunes survive their base model's deprecation on OpenAI** — existing fine-tuned models keep serving, but you can no longer create new fine-tunes from that base. Plan re-tuning onto a supported base ahead of shutdown.

Retirement tables, full deprecation history, and replacement mappings: `references/lifecycle-and-deprecations.md`.

## Which platform to run on

First-party API is the default: it is the only surface with the full feature set on every vendor. Choose a cloud when procurement, data residency, or an existing commit forces it — then verify the feature you depend on actually exists there.

- **Amazon Bedrock (Claude):** `anthropic.`-prefixed IDs, Messages API at `/anthropic/v1/messages`, global endpoint with no premium or regional endpoints at +10%. Default quota 2M input TPM, raisable to 4M. Missing: Files API, server tools, Agent Skills, MCP connector, Batches, Admin/Usage APIs, server-side fallback.
- **Google Cloud Agent Platform / Vertex (Claude):** model goes in the URL, not the body; `anthropic_version: "vertex-2023-10-16"` is a body field. Global endpoint recommended; multi-region and regional cost +10% and **regional endpoints only serve Sonnet 4.6 and earlier** — newer models are global/multi-region only. 30 MB request payload cap can bite before the token limit does.
- **Claude Platform on AWS / Microsoft Foundry:** Anthropic-operated, marketplace-billed in Claude Consumption Units at $0.01/CCU, postpaid only.
- **Vertex for Gemini:** same model IDs as the Gemini API with Vertex-specific tiering (priority 1.8x, flex/batch 0.5x, 90% cached-token discount).

Endpoint types, region lists, auth paths, and the full gap list: `references/cloud-availability.md`.

## Anti-patterns

- Quoting a price or ID from memory instead of the reference tables or a live fetch. Highest-frequency, highest-damage error in this skill.
- Recommending a retired model. `claude-opus-4-1-20250805` retired **2026-08-05** — today. `gpt-5`, `gpt-5-mini`, and `o3-2025-04-16` shut down 2026-12-11; `gpt-3.5-turbo`, `gpt-4`, `gpt-4-turbo`, `o1`, `o3-mini` on 2026-10-23.
- Naming a model that does not exist. There is **no verified `gpt-5.6-codex`**; `gpt-5-codex` is the real Codex model ID and is Responses-API-only with a Sep 30 2024 cutoff. Codex CLI/IDE run on the general GPT-5.6 tiers.
- Recommending `claude-mythos-5` as if it were orderable. It is limited availability, invitation-only via Project Glasswing, and needs an Anthropic/AWS/Google account-team conversation.
- Treating Mythos/Fable pricing as an Opus alternative without saying so: Fable 5 is **2x Opus 5** on both input and output.
- Assuming Sonnet 5 stays at $2/$10. Introductory pricing ends **2026-08-31**; from 2026-09-01 it is $3/$15. Any TCO model spanning that date needs both rates.
- Setting `temperature` on Opus 4.7+ and blaming the model for the 400.
- Sizing a 1M-context design without checking the per-vendor long-context meter and the 30 MB Vertex payload cap.
- Answering "which model" without asking about latency budget, context size, and cutoff sensitivity. Those three eliminate more candidates than price does.

## Reference files

Load on demand — do not read all of them for a single-model question.

- `references/claude-catalog.md` — Read for any Anthropic question: current and legacy model IDs across API/Bedrock/Google Cloud, full pricing incl. cache write/read and batch rates, context/output/cutoffs, thinking support, tool-use token overhead, long-context and data-residency and fast-mode pricing mechanics, worked cost examples.
- `references/openai-catalog.md` — Read for any OpenAI question: GPT-5.6 tier table, full current pricing incl. legacy and o-series, long-context meter, `gpt-5-codex` specs, realtime/image/video/embedding families, pricing modifiers.
- `references/gemini-catalog.md` — Read for any Google question: Gemini 3.x and 2.5 model IDs (stable vs preview), per-model limits and thinking support, AI Studio paid-tier and Vertex pricing tables, tier-selection heuristics, image/embedding families.
- `references/lifecycle-and-deprecations.md` — Read when the question is about retirement dates, notice periods, migration targets, `-latest` vs pinned IDs, or auditing usage of a dying model.
- `references/cloud-availability.md` — Read when the workload runs on Bedrock, Vertex/Agent Platform, Claude Platform on AWS, or Microsoft Foundry, or when a feature might not exist off the first-party API.

## Diagnostic scripts

- `scripts/list-claude-models.sh` — Read-only `GET /v1/models` against the Claude API using `ANTHROPIC_API_KEY`; prints IDs, display names, and per-model limits actually available to the caller's org. Run this instead of trusting the tables when the answer must be exact.

## Sources

- https://platform.claude.com/docs/en/about-claude/models/overview
- https://platform.claude.com/docs/en/about-claude/pricing
- https://platform.claude.com/docs/en/about-claude/model-deprecations
- https://platform.claude.com/docs/en/build-with-claude/claude-in-amazon-bedrock
- https://platform.claude.com/docs/en/build-with-claude/claude-on-vertex-ai
- https://developers.openai.com/api/docs/models
- https://developers.openai.com/api/docs/pricing
- https://developers.openai.com/api/docs/models/gpt-5-codex
- https://developers.openai.com/api/docs/deprecations
- https://developers.openai.com/api/docs/guides/model-selection
- https://ai.google.dev/gemini-api/docs/models
- https://ai.google.dev/gemini-api/docs/latest-model
- https://ai.google.dev/gemini-api/docs/models/gemini-2.5-pro
- https://ai.google.dev/gemini-api/docs/models/gemini-2.5-flash
- https://ai.google.dev/gemini-api/docs/models/gemini-3.1-pro-preview
- https://ai.google.dev/gemini-api/docs/models/gemini-3-pro-preview
- https://ai.google.dev/gemini-api/docs/pricing
- https://cloud.google.com/vertex-ai/generative-ai/pricing

Fetched: 2026-08-05
