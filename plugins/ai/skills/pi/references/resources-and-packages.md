# pi: Skills, Prompt Templates, Themes, and Packages

Read this when adding reusable resources to pi or distributing them to a team.

## Skills

> Source: https://pi.dev/docs/latest/skills

A skill is a directory containing `SKILL.md`: "Everything else is freeform." Typical layout:

```
my-skill/
├── SKILL.md              # Required: frontmatter + instructions
├── scripts/              # Helper scripts
├── references/           # Detailed documentation
└── assets/               # Resources like templates
```

Frontmatter:

| Field | Required | Notes |
|---|---|---|
| `name` | yes | 1–64 chars, lowercase a–z, 0–9, hyphens |
| `description` | yes | Max 1024 chars, states when to use the skill |
| `license` | no | |
| `compatibility` | no | Environment requirements |
| `metadata` | no | Arbitrary key-value pairs |
| `allowed-tools` | no | Space-delimited pre-approved tools |
| `disable-model-invocation` | no | Hides the skill from the system prompt |

Discovery and distribution locations:

1. npm packages — a `skills/` directory or `pi.skills` entries in `package.json`
2. Git repositories — standardized directory structures
3. Project-local: `.pi/skills/` or `.agents/skills/`
4. Global: `~/.pi/agent/skills/` or `~/.agents/skills/`

CLI: `--skill <path>` (repeatable) loads a skill for one invocation; `--no-skills` disables skill loading.

The docs cite community examples: Anthropic Skills (document processing, web development) and Pi Skills (web search, browser automation, Google APIs).

Because pi has no MCP client, a **CLI tool plus a skill describing it** is the documented pattern for giving the agent new external capability without writing an extension. For authoring high-quality SKILL.md content, use the `agent-skills` sibling skill.

## Prompt templates

> Source: https://pi.dev/docs/latest/prompt-templates

Discovery:

- Global: `~/.pi/agent/prompts/*.md`
- Project: `.pi/prompts/*.md` (**requires project trust**)
- Packages: `prompts/` directories or `pi.prompts` in `package.json`
- Settings: a `prompts` array listing files or directories
- CLI: `--prompt-template <path>`

The filename without `.md` becomes the command name — `review.md` → `/review`.

```yaml
---
description: Review staged git changes
argument-hint: "<PR-URL>"
---
```

`description` is optional and defaults to the first non-empty line of the file. `argument-hint` drives autocomplete: `<angle brackets>` for required args, `[square brackets]` for optional.

Argument expansion:

| Syntax | Meaning |
|---|---|
| `$1`, `$2`, … | Positional arguments |
| `$@` or `$ARGUMENTS` | All arguments joined |
| `${1:-default}` | Fallback value |
| `${@:N}`, `${@:N:L}` | Argument-range slicing |

```
/review
/component Button
/component Button "click handler"
```

**Discovery is non-recursive.** Templates in a subdirectory of `prompts/` are not found; list them explicitly in settings or a package manifest. This is the most common "my template doesn't show up" cause. `--no-prompt-templates` disables loading.

## Themes

> Source: https://pi.dev/docs/latest/themes

Locations: built-in `dark` and `light`; global `~/.pi/agent/themes/*.json`; project `.pi/themes/*.json` (trust required); package `themes/` directories or `pi.themes` entries; a `themes` array in settings; `--theme <path>` (repeatable). `--no-themes` disables loading.

```json
{
  "$schema": "[theme-schema-url]",
  "name": "theme-name",
  "vars": { "colorName": "#hexvalue or index" },
  "colors": { "token": "colorReference" }
}
```

Requirements: `name` is required, unique, and must not contain forward slashes. `vars` is an optional block of reusable color definitions. `colors` must include **51 required tokens**, with 2 optional extras (`thinkingMax`, `scrollbarThumb`) — a theme missing required tokens is incomplete.

Color value formats: hex RGB (`"#ff0000"`), 256-color palette index (`39`, range 0–255), a variable reference resolved from `vars` (`"primary"`), or empty string `""` for the default terminal color.

## Packages

> Source: https://pi.dev/docs/latest/packages

A package bundles extensions, skills, prompt templates, and themes for distribution via npm or git.

```json
{
  "name": "my-package",
  "keywords": ["pi-package"],
  "pi": {
    "extensions": ["./extensions"],
    "skills": ["./skills"],
    "prompts": ["./prompts"],
    "themes": ["./themes"]
  }
}
```

Omit the `pi` key and pi auto-discovers the conventional directories `extensions/`, `skills/`, `prompts/`, `themes/`.

Install:

```bash
pi install npm:@scope/pkg@1.2.3       # versioned specs are pinned and skip auto-updates
pi install git:github.com/user/repo@v1 # SSH and HTTPS both supported
pi install ./relative/path            # absolute or relative filesystem paths
```

Git clones land in `~/.pi/agent/git/` (global) or `.pi/git/` (project-local).

**Pin versions for team or CI use.** A versioned npm spec is pinned and skips auto-updates; an unpinned or branch-tracking git source can change what executes on the next run without review.

Declaration in settings, global or project:

```json
{
  "packages": [
    "npm:simple-pkg",
    {
      "source": "npm:my-package",
      "extensions": ["extensions/*.ts", "!extensions/legacy.ts"],
      "skills": [],
      "prompts": ["prompts/review.md"]
    }
  ]
}
```

Resource filtering supports glob patterns, exclusions (`!pattern`), and forced inclusion/exclusion prefixes (`+` / `-`). An empty array (`"skills": []`) excludes that whole resource category from the package — the way to consume a package's prompts while refusing its executable extensions.

Dependencies: list third-party npm packages the extension code needs in `dependencies`; bundle non-core pi packages the package itself depends on in `bundledDependencies`.

**Security, from the docs:** "Packages execute with full system access; review source code before installing." There is no sandboxing of package code — consistent with pi's no-built-in-sandbox stance in `security-and-exclusions.md`.

Deduplication: when the same package is declared in both global and project settings, the **project entry wins — unless it specifies `"autoload": false`**, in which case the global entry is used instead.

## Sources

- https://pi.dev/docs/latest/skills
- https://pi.dev/docs/latest/prompt-templates
- https://pi.dev/docs/latest/themes
- https://pi.dev/docs/latest/packages

Fetched: 2026-08-05
