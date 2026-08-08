# Skills across surfaces: Claude API, claude.ai, and the open-source repo

Contents:
- Surface matrix and cross-surface limitations
- Pre-built Skills
- Using Skills via the Messages API (`container.skills`)
- Listing Anthropic-managed Skills
- Downloading generated files
- Managing custom Skills (Skills API)
- Multi-turn container reuse and `pause_turn`
- Security considerations for third-party Skills
- The anthropics/skills repository
- Skills vs MCP vs custom tools (what is and isn't documented)

## Surface matrix and cross-surface limitations

> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview

Claude Platform on AWS and Microsoft Foundry inherit the same Skills behavior as the Claude API.

**Claude API** — requires the code execution tool (Skills run in its container) plus the `skills-2025-10-02` beta header; add `files-api-2025-04-14` when uploading/downloading files via the Files API. Reference pre-built Skills by `skill_id` (`pptx`, `xlsx`, `docx`, `pdf`) or upload custom Skills via `/v1/skills`. Custom Skills are shared workspace-wide. API Skills run in a sandboxed container with **no network access and no runtime package installation**.

**Claude Code** — custom Skills only (pre-built document Skills are not available, though the open-source Claude API skill ships bundled). Filesystem-based, no upload: `~/.claude/skills/` (personal) or `.claude/skills/` (project).

**claude.ai** — both pre-built and custom Skills. Pre-built Skills activate automatically for document creation. Custom Skills are uploaded as zip files via Settings > Features, on Pro/Max/Team/Enterprise with code execution enabled. Custom Skills on claude.ai are **individual to each user** — not shared org-wide, not centrally manageable by admins.

Cross-surface limitations:
- Custom Skills **do not sync across surfaces**. Uploaded to claude.ai ≠ available on the API; uploaded via the API ≠ available on claude.ai; Claude Code skills are filesystem-based and separate from both.
- Sharing scope: claude.ai = individual user; Claude API = workspace-wide; Claude Code = personal/project (or via plugins).

Runtime environment constraints:

| Surface | Network access | Package installation |
|---|---|---|
| claude.ai | Full, partial, or none depending on user/admin settings | — |
| Claude API | **No network access** | **No runtime package installation** — pre-installed packages only |
| Claude Code | Full network access (same as any local program) | Local installs allowed; global installs discouraged |

## Pre-built Skills

> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview

As of 2026-08-05: **PowerPoint (`pptx`)** — create presentations, edit slides, analyze presentation content; **Excel (`xlsx`)** — create spreadsheets, analyze data, generate reports with charts; **Word (`docx`)** — create documents, edit content, format text; **PDF (`pdf`)** — generate formatted PDF documents and reports.

Available on claude.ai, the Claude API, Claude Platform on AWS, and Microsoft Foundry (Hosted on Anthropic deployment only).

## Using Skills via the Messages API

> Source: https://docs.claude.com/en/docs/build-with-claude/skills-guide
> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/quickstart

Specify Skills via `container.skills` — up to **8 Skills per request**, mixing `anthropic` and `custom` types (e.g. `xlsx` + `pptx` + a custom skill for "Analyze sales data and create a presentation").

```json
{
  "model": "claude-opus-5",
  "max_tokens": 4096,
  "container": {
    "skills": [
      {"type": "anthropic", "skill_id": "pptx", "version": "latest"}
    ]
  },
  "messages": [{"role": "user", "content": "Create a presentation"}],
  "tools": [{"type": "code_execution_20250825", "name": "code_execution"}]
}
```

Quickstart curl (using the GA `code_execution_20260521` tool as of 2026-08-05):

```bash
curl --fail-with-body -sS https://api.anthropic.com/v1/messages \
  -H "content-type: application/json" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: skills-2025-10-02" \
  -d '{
    "model": "claude-opus-5",
    "max_tokens": 16000,
    "container": {
      "skills": [{"type": "anthropic", "skill_id": "pptx", "version": "latest"}]
    },
    "messages": [
      {"role": "user", "content": "Create a presentation about renewable energy with 5 slides"}
    ],
    "tools": [{"type": "code_execution_20260521", "name": "code_execution"}]
  }'
```

Anthropic-managed vs custom Skills:

| Aspect | Anthropic Skills | Custom Skills |
|---|---|---|
| `type` value | `anthropic` | `custom` |
| Skill IDs | Short names: `pptx`, `xlsx`, `docx`, `pdf` | Generated: `skill_01AbCdEfGhIjKlMnOpQrStUv` |
| Version format | Date-based: `20251013` or `latest` | Epoch timestamp: `1759178010641129` or `latest` |
| Management | Pre-built by Anthropic | Upload via Skills API |
| Availability | All users | Private to workspace |

## Listing Anthropic-managed Skills

> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/quickstart

Level-1 progressive disclosure over the wire — metadata only:

```bash
curl --fail-with-body -sS "https://api.anthropic.com/v1/skills?source=anthropic" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: skills-2025-10-02" |
  jq -r '.data[] | "\(.id): \(.display_title)"'
```

```python
skills = client.beta.skills.list(source="anthropic")
for skill in skills.data:
    print(f"{skill.id}: {skill.display_title}")
```

Returns `pptx`, `xlsx`, `docx`, `pdf`.

## Downloading generated files

> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/quickstart

Generated files appear as `bash_code_execution_output` items inside a `bash_code_execution_tool_result` block. Extract `file_id`, then download via the Files API (needs the `files-api-2025-04-14` beta):

```python
file_id = None
for block in response.content:
    if block.type == "bash_code_execution_tool_result":
        if block.content.type == "bash_code_execution_result":
            for output in block.content.content:
                file_id = output.file_id

if file_id:
    output_path = Path(tempfile.gettempdir()) / "renewable_energy.pptx"
    file_content = client.beta.files.download(file_id=file_id)
    file_content.write_to_file(output_path)
```

```bash
curl --fail-with-body -sS "https://api.anthropic.com/v1/files/$file_id/content" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: files-api-2025-04-14" \
  -o "$output_path"
```

## Managing custom Skills (Skills API)

> Source: https://docs.claude.com/en/docs/build-with-claude/skills-guide

Upload requirements: must include `SKILL.md` at the top level; all files share a common root directory; the top-level directory name matches SKILL.md's `name` (case/underscore insensitive); `name` ≤64 chars lowercase/numbers/hyphens; `description` non-empty and ≤1024 chars; **max upload size 30 MB uncompressed**.

```python
from anthropic.lib import files_from_dir
client = anthropic.Anthropic()

# Option 1: zip archive
skill = client.beta.skills.create(files=[open("financial_skill.zip", "rb")])

# Option 2: individual files
skill = client.beta.skills.create(files=files_from_dir("financial_skill"))

print(f"Created skill: {skill.id}")
print(f"Latest version: {skill.latest_version}")
```

List, version, and delete:

```python
for skill in client.beta.skills.list():
    print(f"{skill.id}: {skill.display_title} (source: {skill.source})")

custom_skills = client.beta.skills.list(source="custom")

new_version = client.beta.skills.versions.create(
    skill_id="skill_01AbCdEfGhIjKlMnOpQrStUv",
    files=files_from_dir("financial_skill"),
)

# Deleting a skill requires deleting all versions first
for version in client.beta.skills.versions.list(skill_id="skill_01AbCdEfGhIjKlMnOpQrStUv"):
    client.beta.skills.versions.delete(skill_id="skill_01AbCdEfGhIjKlMnOpQrStUv", version=version.version)
client.beta.skills.delete(skill_id="skill_01AbCdEfGhIjKlMnOpQrStUv")
```

| Operation | Endpoint | Method |
|---|---|---|
| Create Skill | `/v1/skills` | POST |
| List Skills | `/v1/skills` | GET |
| Retrieve Skill | `/v1/skills/{skill_id}` | GET |
| Delete Skill | `/v1/skills/{skill_id}` | DELETE |
| Create Version | `/v1/skills/{skill_id}/versions` | POST |
| List Versions | `/v1/skills/{skill_id}/versions` | GET |
| Delete Version | `/v1/skills/{skill_id}/versions/{version}` | DELETE |
| Send Messages | `/v1/messages` | POST |

## Multi-turn container reuse and pause_turn

> Source: https://docs.claude.com/en/docs/build-with-claude/skills-guide

Reuse `container.id` from a prior response to keep execution state across turns:

```python
response2 = client.beta.messages.create(
    ...,
    container={
        "id": response1.container.id,
        "skills": [{"type": "anthropic", "skill_id": "xlsx", "version": "latest"}],
    },
    messages=[..., {"role": "assistant", "content": response1.content},
              {"role": "user", "content": "What was the total revenue?"}],
)
```

Long-running Skill operations can return `stop_reason == "pause_turn"`. Loop, re-sending the assistant content and reusing `container.id`, until `stop_reason` is something else:

```python
for _ in range(max_retries):
    if response.stop_reason != "pause_turn":
        break
    messages.append({"role": "assistant", "content": response.content})
    response = client.beta.messages.create(
        ..., container={"id": response.container.id, "skills": [...]}, messages=messages
    )
```

## Security considerations for third-party Skills

> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview
> Source: https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills

Use Skills only from trusted sources — those you created yourself or obtained from Anthropic. Skills give Claude new capabilities through instructions and code, and a malicious Skill can direct Claude to invoke tools or execute code in ways that do not match its stated purpose. If you must use a Skill from an unknown source, audit it thoroughly first; depending on Claude's access, malicious Skills can lead to data exfiltration or unauthorized system access.

- **Audit thoroughly** — review every bundled file (SKILL.md, scripts, images, resources) for unusual network calls, file access patterns, or operations mismatched to the stated purpose.
- **External sources are risky** — Skills that fetch data from external URLs are particularly risky since fetched content may contain malicious instructions, and even trustworthy Skills can be compromised when external dependencies change.
- **Tool misuse** — malicious Skills can invoke file operations, bash, and code execution harmfully.
- **Data exposure** — Skills with access to sensitive data can be designed to leak it.
- **Treat like installing software** — be especially careful in production systems with sensitive data or critical operations.

Agent Skills is **not** covered by Zero Data Retention arrangements as of 2026-08-05; skill definitions and execution data are retained under Anthropic's standard data retention policy.

Organization-scale governance/vetting/deployment is covered by a separate "Skills for enterprise" doc linked from the overview page; it was not fetched for this corpus, so its contents are unverified here.

## The anthropics/skills repository

> Source: https://github.com/anthropics/skills
> Source: https://github.com/anthropics/skills/tree/main/skills
> Source: https://github.com/anthropics/skills/tree/main/skills/skill-creator
> Source: https://github.com/anthropics/skills/blob/main/template/SKILL.md

Anthropic's public repository of Agent Skills — folders of instructions, scripts, and resources Claude loads dynamically. The repo disclaims that skills there are for demonstration/educational purposes and behavior may differ from what Claude provides in product.

```
.
├── skills/                    # Skill examples organized by category
├── spec/                      # Agent Skills specification
├── template/                  # Skill template for creating new skills
├── .claude-plugin/            # Claude Code plugin configuration
├── .gitignore
├── README.md
└── THIRD_PARTY_NOTICES.md
```

Examples present as of 2026-08-05 (non-exhaustive; the repo evolves): `algorithmic-art`, `brand-guidelines`, `canvas-design`, `claude-api` (bundled with Claude Code), `doc-coauthoring`, `docx`, `frontend-design`, `internal-comms`, `mcp-builder`, `pdf`, `pptx`, `skill-creator`, `slack-gif-creator`, `theme-factory`, `web-artifacts-builder`, `webapp-testing`, `xlsx`.

The document-creation skills powering Claude's built-in document capabilities (`docx`, `pdf`, `pptx`, `xlsx`) are **source-available, not open source**; most other skills in the repo are Apache 2.0.

`skill-creator` layout — the same skill behind `/plugin install skill-creator@claude-plugins-official`:

```
skill-creator/
├── agents/         # agent-related implementations/examples
├── assets/         # supporting assets
├── eval-viewer/    # HTML evaluation viewer component
├── references/     # reference materials/documentation
├── scripts/        # utility scripts for skill development/testing
├── SKILL.md        # main instructions
└── LICENSE.txt
```

The repo's `template/SKILL.md` is intentionally minimal:

```markdown
---
name: template-skill
description: Replace with description of the skill and when Claude should use it.
---

Insert instructions below
```

Integration points: Claude Code (`/plugin marketplace add anthropics/skills`, then install/enable individual skills as plugins); claude.ai (paid plans, upload via Settings > Features); Claude API (pre-built Skills or custom uploads through the Skills API).

## Skills vs MCP vs custom tools

> Source: https://code.claude.com/docs/en/skills

The only first-party guidance found in the fetched official docs is at the integration boundary: **skills can reference and invoke MCP tools**, but must use fully qualified `ServerName:tool_name` names (e.g. `BigQuery:bigquery_schema`, `GitHub:create_issue`) — without the server prefix Claude may fail to locate the tool when multiple MCP servers are configured.

The implied architectural split — MCP servers expose live external tools and data over a standard protocol, while Skills package procedural knowledge (instructions, scripts, reference docs) that Claude loads on demand and can call MCP tools from — is an inference, not a documented claim. **A dedicated first-party "Skills vs MCP vs custom tools" comparison page was not found among official sources as of 2026-08-05; treat any stronger comparison as unverified.**

## Sources

- https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview
- https://docs.claude.com/en/docs/agents-and-tools/agent-skills/quickstart
- https://docs.claude.com/en/docs/build-with-claude/skills-guide
- https://code.claude.com/docs/en/skills
- https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- https://github.com/anthropics/skills
- https://github.com/anthropics/skills/tree/main/skills
- https://github.com/anthropics/skills/tree/main/skills/skill-creator
- https://github.com/anthropics/skills/blob/main/template/SKILL.md

Fetched: 2026-08-05
