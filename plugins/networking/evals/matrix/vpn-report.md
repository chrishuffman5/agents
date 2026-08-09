# vpn — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| vpn-cnsa2-deadline | recent | By what year does CNSA 2.0 guidance require full transition to post-quantum algorithms like ML-KEM-1024 for VPN key exchange? Answer concisely. | contains_all: `2033``, ``ML-KEM` |
| vpn-wireguard-loc | recent | Roughly how many lines of kernel code make up the WireGuard implementation, according to the simplicity comparison used when evaluating VPN technologies? Answer concisely. | regex: `(?i)4,?000` |
| vpn-weak-dh-groups | stable | Should you use Diffie-Hellman Groups 1, 2, or 5 for a new IPsec/IKE VPN configuration today? Answer in one sentence. | regex: `(?i)(\bno\b|avoid|weak|broken|should not)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 5.2s | 236 | $0.5798 | $0.1933 |
| no-skill | 9 | **33.3%** | 4.9s | 142 | $0.1762 | $0.0587 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 5.2s | 4.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.9s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.7s | rates n/c |
| claude-opus-5 | skill | 50% | 6.6s | $0.1933 |
| claude-opus-5 | no-skill | 50% | 5s | $0.0587 |

_Full per-cell aggregates (harness × model × effort × mode) in `vpn-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
