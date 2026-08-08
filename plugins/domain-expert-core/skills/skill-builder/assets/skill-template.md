---
name: {skill-name}
description: "{WHAT: dense noun-phrase inventory of coverage — technology, versions, the angle this skill owns}. WHEN: \"{trigger term}\", \"{trigger term}\", \"{command or error a user would actually type}\". Do NOT use for {overlapping concern} — {overlapping-skill name}{; repeat per overlap from the brief}."
license: MIT
---

# {Technology Name}

{One or two sentences: what this technology is and the angle this skill owns. No history lesson, no marketing.}

## Routing

| Request | Load |
|---|---|
| {request type, e.g. "wire-format / config detail"} | `references/{file}.md` |
| {request type} | `references/{file}.md` |
| "what changed in version X" | `references/versions/<v>.md` |

## {Core section — mental model / architecture}

{Directives over essays. "Always X. Never Y." with a one-line why. Version-qualify anything that varies: "since {v}", "removed in {v}". Exact values — defaults, limits, flags — not characterizations.}

## {Core section — the decisions users actually face}

{Outcomes and constraints, not rigid step lists. Tables for enumerable facts; prose for judgment.}

## {Pitfalls / operational directives}

{The failure modes the docs bury. Each entry: symptom → cause → fix.}

## Scripts

- `scripts/{name}` — {what it diagnoses or demonstrates; when to run it}. {Delete this section if no script earned its place.}

## References

- `references/{file}.md` — {what depth lives there; when to read it}
- `references/versions/<v>.md` — {per-version deltas: new, changed, deprecated}

## Sources

- {every load-bearing URL, one per line — these seed the next refresh run}

Fetched: {YYYY-MM-DD}
