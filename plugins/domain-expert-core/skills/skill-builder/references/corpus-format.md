# Corpus Format

Layout and schemas for the research workspace at `research/<skill-name>/`. The corpus is a durable asset: it survives the build, feeds every future refresh, and lets an interrupted session resume from disk. `research/` must be gitignored — it is intermediate material, never shipped.

## Layout

```
research/<skill-name>/
├── BRIEF.md                      ← Phase 0 scope; every agent's first input
├── INDEX.md                      ← manifest log; the orchestrator's only window into the corpus
├── core-concepts/                ← one directory per dimension (kebab-case)
│   ├── architecture.md
│   └── terminology.md
├── versions/
│   ├── v16.md                    ← one artifact per version in scope
│   └── v17.md
├── operations/ …  pitfalls/ …  security/ …  ecosystem/ …
└── curation-notes.md             ← Phase 3 curator: what was cut, why, distrusted material
```

## BRIEF.md schema

Written by the orchestrator in Phase 0. Keep it under a page — it is re-read by every agent.

```markdown
# Brief: <skill-name>
- Technology: <name + one-line what it is>
- Target: plugins/<domain>/skills/<skill-name>/   (new | refresh of existing)
- Version range in scope: <e.g. 16–18; which get references/versions/ files>
- Dimensions: <list, with merges/splits from the default set and why>
- Overlaps: <other plugin skills covering this tech, and the angle each owns>
  → required NOT-clauses: <what this skill's description must route away>
- Out of scope: <declared exclusions, appended as gap-audit findings are waived>
- Refresh inputs: <path of existing skill whose ## Sources seeds the researchers, if refresh>
- User decisions: <anything the user pinned: paid tiers, cloud vs self-hosted, etc.>
```

## INDEX.md schema

Append-only. The orchestrator pastes each agent's returned manifest verbatim, newest last, prefixed with a timestamp line. Never rewrite or summarize old entries — a resuming session reconstructs the run state from this file.

```markdown
# Index: <skill-name>

## <YYYY-MM-DD HH:MM> — researcher: core-concepts
MANIFEST: core-concepts
- core-concepts/architecture.md — process model, shared memory, WAL pipeline
- sources: 9 (7 official / 2 vendor)
- coverage: architecture + terminology through v17
- gaps: v18 changes not yet in released docs

## <YYYY-MM-DD HH:MM> — gap audit #1
AUDIT: GAPS
- gap: versions — v18 beta release notes exist but unfetched — spawn versions researcher
```

## Artifact format

Every research artifact is markdown with citations dense enough that the curator never needs the web:

```markdown
# <Topic>

## <Section heading>
> Source: https://example.org/docs/exact-page  (official)

Facts, defaults, limits, commands, config keys. Version-qualify every claim that varies
("since 16", "removed in 17"). Quote exact values — "checkpoint_timeout default 5min" —
not characterizations ("a reasonably short default").

## <Another section>
> Source: https://example.org/blog/deep-dive  (vendor)

CONFLICT: <a> says X (link), <b> says Y (link); trusting <a> because <reason>.
UNSOURCED: docs do not state <thing>; do not claim it downstream.

## Sources
- https://example.org/docs/exact-page  (official)
- https://example.org/blog/deep-dive   (vendor)

Fetched: 2026-08-07
```

Rules the format encodes:

- **`> Source:` sits directly under the heading it supports** — per-section, not per-file. A file-level source list alone is a citation hole the gap audit flags.
- **Only fetched URLs appear.** WebSearch discovers; WebFetch retrieves; citation requires retrieval. Redirects are cited at their final URL with the redirect noted.
- **Tier every source**: `(official)`, `(vendor)`, `(community)`.
- **Uncertainty is data.** `UNSOURCED:` and `CONFLICT:` markers are how a researcher stops the curator from laundering a guess into a directive.
- **Fetch dates are per-file**, set the day the fetches actually ran — they are what a future refresh run diffs against.

## Retention

Keep the corpus after shipping. A refresh run re-fetches the shipped skill's `## Sources`, diffs against these artifacts, and appends new manifests to the same `INDEX.md` — the history of what was known when is part of the asset.

## Sources

Derived from this repository's conventions (CLAUDE.md, the ai-plugin corpus runs of 2026-08); no external documents fetched.
