# vpn — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `vpn-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
