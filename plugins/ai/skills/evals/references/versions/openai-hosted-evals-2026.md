# OpenAI hosted Evals platform — 2026 lifecycle

Read before recommending or building on the OpenAI hosted Evals product.

## Sunset dates (confirmed 2026-08-05)

> Source: https://developers.openai.com/api/docs/guides/evals
> Source: https://developers.openai.com/api/docs/guides/evaluation-best-practices
> Source: https://developers.openai.com/api/docs/guides/evaluation-getting-started

The three OpenAI API guide pages above state, verbatim and identically:

- "Evals will become read-only for existing users on **October 31, 2026**."
- The platform "is scheduled to shut down on **November 30, 2026**."

The `developers.openai.com/learn/evals` overview page does **not** carry the notice — only the three technical guide pages do. Treat the dates as authoritative because they appear consistently across those guides.

## What this means in practice

- **Do not start new work on the hosted Evals API** if the project will still be running past 2026-11-30. The `evaluation-getting-started` guidance explicitly recommends **Datasets** as the entry point for new evaluation work, with Evals positioned for scaling once a workflow is proven. It does not say Datasets fully replaces Evals — only that Datasets is the recommended starting point given the shutdown timeline.
- **Existing hosted evals need an exit plan before 2026-10-31**, since read-only mode blocks creating or updating eval configurations after that date.
- **Portable alternatives**: the open-source `openai/evals` GitHub framework (JSONL data + registry YAML + `oaieval`), or a self-hosted harness of the kind described in `../agent-and-trajectory-evals.md` and `../skill-evals.md` — a loop that runs the system, records the trace, and applies code and rubric graders.

## Scope of the deprecation

The open-source `openai/evals` framework and registry is a **separate project** from the hosted platform and API. Its README was fetched on 2026-08-05 and makes no mention of the hosted-platform sunset either way; nothing fetched states that the OSS framework is affected. Treat "the OSS framework is unaffected" as *inferred from separateness, not explicitly documented* — re-verify against the repo before betting a migration on it.

## Sources

- https://developers.openai.com/api/docs/guides/evals
- https://developers.openai.com/api/docs/guides/evaluation-best-practices
- https://developers.openai.com/api/docs/guides/evaluation-getting-started
- https://developers.openai.com/learn/evals
- https://github.com/openai/evals

Fetched: 2026-08-05
