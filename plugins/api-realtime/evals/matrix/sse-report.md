# sse — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `api-realtime` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sse-204-close | stable | What HTTP status code can a Server-Sent Events endpoint return to tell the browser to permanently stop trying to reconnect the stream? Answer concisely. | contains_all: `204` |
| sse-nginx-buffering-header | stable | For a Server-Sent Events endpoint running behind Nginx, which response header must be set to stop Nginx from buffering the stream? Answer concisely. | contains_all: `X-Accel-Buffering` |
| sse-keepalive-interval | recent | To stop proxies from killing an idle Server-Sent Events connection after 60 to 120 seconds of inactivity, roughly how often should the server send a keepalive comment line? Answer concisely with the recommended interval. | regex: `(?i)15.{0,6}30` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `sse-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
