# sandboxing — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `ai` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sandboxing-governing-rule | stable | What two kinds of isolation does effective agent sandboxing require together, per the governing rule stated for coding agent sandboxing? Answer concisely. | contains_all: `filesystem``, ``network` |
| sandboxing-firecracker-boot-time | recent | How quickly do Firecracker microVMs boot, and roughly how much memory overhead do they add? Answer concisely with both figures. | regex: `(?i)125\s*ms.{0,60}5\s*mi?b` |
| sandboxing-gvisor-io-overhead | recent | What is gVisor's documented performance overhead range for heavy file I/O workloads, compared to near-zero overhead for CPU-bound work? Answer concisely. | regex: `(?i)10.{0,5}200x` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `sandboxing-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
