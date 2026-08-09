# postgresql — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| postgresql-pgupgrade-swap-flag | recent | Which pg_upgrade flag introduced in PostgreSQL 18 swaps data directories instead of copying them, dramatically speeding up major version upgrades of large databases? Answer with the exact flag. | contains_all: `--swap` |
| postgresql-17-vacuum-tidstore-memory | recent | PostgreSQL 17 introduced a TID store, a radix tree that VACUUM uses to track dead tuple IDs. Compared to the previous flat array approach, it reduces VACUUM memory consumption on large tables by up to how many times? Answer with the exact number. | regex: `(?i)(20\s*x\b|20\s*times)` |
| postgresql-autovacuum-scale-factor-default | stable | What is the default value of the autovacuum_vacuum_scale_factor parameter in PostgreSQL? Answer with the exact number. | contains_all: `0.2` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **75%** | 64.7s | 545 | $2.1155 | $0.2351 |
| no-skill | 12 | **66.7%** | 27s | 265 | $0.6836 | $0.0854 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 75% | 66.7% | +8.3pp | 64.7s | 27s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 114.7s | $0.3087 |
| claude-haiku-4-5 | no-skill | 33.3% | 47.1s | $0.1677 |
| claude-opus-5 | skill | 100% | 14.7s | $0.1982 |
| claude-opus-5 | no-skill | 100% | 7s | $0.058 |

_Full per-cell aggregates (harness × model × effort × mode) in `postgresql-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
