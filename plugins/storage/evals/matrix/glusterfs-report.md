# glusterfs — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `storage` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| glusterfs-stable-version | recent | As of the latest guidance, what is the current stable release version number of GlusterFS? Answer concisely. | contains_all: `11.2` |
| glusterfs-rhgs-eol | recent | When did Red Hat Gluster Storage reach end of life? Answer concisely. | contains_all: `December``, ``2024` |
| glusterfs-xfs-isize | stable | When formatting GlusterFS bricks with XFS, what isize value is required to properly store extended attributes? Answer concisely. | contains_all: `512` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 11.7s | 380 | $1.0902 | $0.109 |
| no-skill | 12 | **66.7%** | 11s | 458 | $0.6236 | $0.078 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 66.7% | +16.6pp | 11.7s | 11s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 14.6s | $0.0742 |
| claude-haiku-4-5 | no-skill | 33.3% | 8.6s | $0.0624 |
| claude-opus-5 | skill | 100% | 8.8s | $0.1322 |
| claude-opus-5 | no-skill | 100% | 13.5s | $0.0832 |

_Full per-cell aggregates (harness × model × effort × mode) in `glusterfs-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
