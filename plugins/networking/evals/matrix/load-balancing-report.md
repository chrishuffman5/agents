# load-balancing — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| load-balancing-tls13-ssl-session-persistence | recent | Does SSL Session ID based load balancer persistence remain fully reliable under TLS 1.3, or does something about it change? Answer in one or two sentences. | regex: `(?i)(less reliable|session ticket)` |
| load-balancing-power-of-two-choices | recent | What load balancing algorithm picks two servers at random and then routes the request to whichever of the two currently has fewer active connections? Answer concisely. | regex: `(?i)two\s*choices` |
| load-balancing-dsr-response-path | stable | In Direct Server Return (DSR) load balancing, does the response traffic flow back through the load balancer, or does it go directly from the server to the client? Answer concisely. | regex: `(?i)directly` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **33.3%** | 7.1s | 269 | $1.2498 | $0.3124 |
| no-skill | 9 | **22.2%** | 4.5s | 164 | $0.1648 | $0.0824 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 33.3% | 22.2% | +11.1pp | 7.1s | 4.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.4s | rates n/c |
| claude-opus-5 | skill | 66.7% | 9.8s | $0.3124 |
| claude-opus-5 | no-skill | 33.3% | 5s | $0.0824 |

_Full per-cell aggregates (harness × model × effort × mode) in `load-balancing-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
