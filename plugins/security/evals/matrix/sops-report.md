# sops — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sops-dek-encryption | stable | In Mozilla SOPS, is each encrypted file protected by a single shared master key, or by a unique per-file data encryption key that is itself wrapped by each configured master key? Name the cipher used for that per-file key. Answer concisely. | contains_all: `AES-256-GCM``, ``DEK` |
| sops-updatekeys-ciphertext | recent | When you run the sops updatekeys command on an already-encrypted file, does the actual encrypted ciphertext of the values change, or does it only re-wrap the data encryption key for the new set of keys? Answer concisely. | regex: `(?i)\b(no|not|unchanged)\b` |
| sops-exec-file-placeholder | recent | In the SOPS exec-file command, what two-character placeholder appears in the command string and gets replaced with the path to a temporary decrypted file? Answer concisely. | contains_all: `{}` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `sops-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
