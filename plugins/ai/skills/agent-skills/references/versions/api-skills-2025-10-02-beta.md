# Skills API — `skills-2025-10-02` beta, headers and version formats

State as of 2026-08-05. Read before writing API calls that use Skills.

## Required headers and prerequisites

> Source: https://docs.claude.com/en/docs/build-with-claude/skills-guide
> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/quickstart

Using Skills via the API requires:

1. A Claude API key
2. The **code execution tool** enabled — Skills run inside its container
3. Beta headers:
   - `skills-2025-10-02` — enables the Skills API/feature
   - `code-execution-2025-08-25` — enables code execution. A newer code-execution tool version, `code_execution_20260521`, is GA and needs only `skills-2025-10-02`.
   - `files-api-2025-04-14` — required only when uploading/downloading files via the Files API

Every request also sends `x-api-key: $ANTHROPIC_API_KEY`, `anthropic-version: 2023-06-01`, and `anthropic-beta: <comma-separated betas>`.

## Code execution tool version pinning

> Source: https://docs.claude.com/en/docs/build-with-claude/skills-guide
> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/quickstart

| Tool `type` value | Beta headers needed |
|---|---|
| `code_execution_20250825` | `skills-2025-10-02` + `code-execution-2025-08-25` |
| `code_execution_20260521` (GA) | `skills-2025-10-02` only |

Prefer the GA `code_execution_20260521` for new integrations — one fewer beta header to track.

## Skill ID and version formats

> Source: https://docs.claude.com/en/docs/build-with-claude/skills-guide

| | Anthropic-managed | Custom |
|---|---|---|
| `type` | `anthropic` | `custom` |
| ID form | `pptx`, `xlsx`, `docx`, `pdf` | `skill_01AbCdEfGhIjKlMnOpQrStUv` |
| Version form | date-based, e.g. `20251013`, or `latest` | epoch timestamp, e.g. `1759178010641129`, or `latest` |

Pin an explicit version rather than `latest` in production: `latest` moves under you when Anthropic ships a new pre-built Skill revision or a teammate pushes a new custom version via `/v1/skills/{skill_id}/versions`.

## Container limits

> Source: https://docs.claude.com/en/docs/build-with-claude/skills-guide
> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview

- Up to **8 Skills per request** in `container.skills`, mixing `anthropic` and `custom` types.
- Upload limit **30 MB uncompressed** per custom Skill.
- Container has **no network access** and **no runtime package installation** — pre-installed packages only.
- Custom Skills are private to the workspace and do not sync to claude.ai or Claude Code.

## Sources

- https://docs.claude.com/en/docs/build-with-claude/skills-guide
- https://docs.claude.com/en/docs/agents-and-tools/agent-skills/quickstart
- https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview

Fetched: 2026-08-05
