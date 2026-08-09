# lets-encrypt — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| lets-encrypt-6day-cert-lifetime | recent | Let's Encrypt offers a short-lived certificate profile in addition to the standard 90-day certificates. How many days is that short-lived certificate valid for, and roughly when did this profile launch? Answer concisely. | contains_all: `6-day``, ``2025` |
| lets-encrypt-domain-rate-limit | recent | Under Let's Encrypt's issuance rate limits, how many certificates can be issued per registered domain within a rolling week, the domain limit as distinct from the duplicate certificate limit? Answer concisely. | contains_all: `50/week` |
| lets-encrypt-cert-file-paths | stable | On a server using certbot, under what directory path prefix are a domain's certificate files stored, and which specific file in that directory should be referenced as the certificate file in a web server config instead of the bare certificate-only file? Answer concisely. | contains_all: `/etc/letsencrypt/live``, ``fullchain.pem` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **8.3%** | 5.1s | 174 | $0.6309 | $0.6309 |
| no-skill | 9 | **11.1%** | 5.2s | 113 | $0.1747 | $0.1747 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 8.3% | 11.1% | +-2.8pp | 5.1s | 5.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 5.2s | rates n/c |
| claude-opus-5 | skill | 16.7% | 5.8s | $0.6309 |
| claude-opus-5 | no-skill | 16.7% | 5.2s | $0.1747 |

_Full per-cell aggregates (harness × model × effort × mode) in `lets-encrypt-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
