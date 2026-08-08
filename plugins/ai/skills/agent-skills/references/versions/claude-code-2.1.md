# Claude Code 2.1.x — skill feature version gates

Read before relying on any Claude-Code-specific skill feature: behavior below is gated on the minimum Claude Code version shown. Check the running version with `claude --version` (or `/doctor`).

## Version gate table

> Source: https://code.claude.com/docs/en/skills

| Minimum version | Behavior gated |
|---|---|
| v2.1.129+ | `${CLAUDE_SKILL_DIR}` substitution inside `allowed-tools` Bash rules (substitution in skill markdown itself is not gated to this version) |
| v2.1.145+ | The `/run`, `/verify`, and `/run-skill-generator` bundled skills |
| v2.1.196+ | `${CLAUDE_PROJECT_DIR}` substitution in skills; `disable-model-invocation: true` also blocking scheduled-task firing |
| v2.1.202+ | Re-invoking a skill with identical rendered content adds a short "already loaded" note instead of duplicating the content in context |
| v2.1.215+ | `/verify` and `/code-review` run only on explicit invocation, not automatically |
| v2.1.218+ | Boolean frontmatter fields accept `yes`/`no`/`on`/`off`/`1`/`0` in any case (earlier: `true`/`false` only); `background: false` with `context: fork` to wait for the result in the invoking turn |

## Practical guidance

- Write boolean frontmatter as `true`/`false` unless you control the fleet's Claude Code version — that form works on every version.
- Before shipping a skill that relies on `${CLAUDE_PROJECT_DIR}` or `${CLAUDE_SKILL_DIR}`-in-`allowed-tools`, state the minimum version in the skill body; there is no frontmatter enforcement of Claude Code version (`compatibility` is accepted but unused by Claude Code).
- `background: false` silently has no effect on pre-v2.1.218 clients, so a forked skill you expect to block will instead run in the background there. Design the skill so background execution is still correct, or document the requirement.

## Sources

- https://code.claude.com/docs/en/skills

Fetched: 2026-08-05
