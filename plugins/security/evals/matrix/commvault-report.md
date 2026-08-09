# commvault — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| commvault-ransomware-detection | recent | Does Commvault Cloud include a built-in ML-based anomaly detection engine for ransomware, comparable to what Rubrik or Cohesity offer natively? Answer in one sentence. | regex: `(?i)\bno\b` |
| commvault-hyperscale-nodes | recent | For a Commvault HyperScale X cluster, what is the minimum node count range needed to start, before you begin scaling out by adding more nodes? Answer concisely. | regex: `(?i)2\s*(-|to)\s*4` |
| commvault-cloud-rewind-aws | stable | Besides restoring EC2 instance data, name two categories of AWS infrastructure configuration that Commvault Cloud Rewind can rebuild during a full-stack recovery. Answer concisely. | contains_all: `Route 53``, ``Elastic Load Balancers` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **8.3%** | 4.7s | 206 | $0.6311 | $0.6311 |
| no-skill | 9 | **0%** | 5.7s | 194 | $0.2109 | rates n/c |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 8.3% | 0% | +8.3pp | 4.7s | 5.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 7.6s | rates n/c |
| claude-opus-5 | skill | 16.7% | 6.1s | $0.6311 |
| claude-opus-5 | no-skill | 0% | 4.7s | rates n/c |

_Full per-cell aggregates (harness × model × effort × mode) in `commvault-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
