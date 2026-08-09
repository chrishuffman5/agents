# svelte — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `frontend` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| svelte-no-virtual-dom | stable | Does Svelte 5 use a virtual DOM at runtime to apply updates, or does it compile components into direct DOM mutation code? Answer concisely. | regex: `(?i)(no virtual dom|compil)` |
| svelte-static-adapter-spa-fallback | recent | To support SPA-style client-side routing with SvelteKit's static adapter and avoid 404s on direct URL access, what fallback file name do you configure? Answer concisely. | contains_all: `200.html` |
| svelte-bindable-prop-rune | recent | In Svelte 5 runes mode, which rune must a child component use to declare a prop that the parent can bind to two-way? Answer concisely. | contains_all: `bindable` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `svelte-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
