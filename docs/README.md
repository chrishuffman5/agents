# Evaluation Dashboard

A static dashboard showing the 18 domain specialists, their shipped diagnostic-script coverage, and the latest eval
results (agent vs. no-tools baseline). Built to be served with **GitHub Pages**.

## Files

| File | Purpose |
|------|---------|
| `index.html` | The dashboard page (self-contained; no external resources) |
| `results.js` | `window.DASHBOARD_DATA` — generated from eval CSVs + the script tree |
| `scripts-standard.md` | The shipped-scripts contract and coverage table |

## Regenerating the data

After any eval sweep (new files under `evals/results/`), refresh the numbers:

```bash
DASHBOARD_STAMP="$(date -u +%Y-%m-%d)" python evals/build-dashboard.py
```

This rewrites `docs/results.js` from:
- `evals/results/*-summary.csv` — newest agent + baseline run per suite
- `evals/suites/*.json` — task counts
- `skills/<domain>/**/scripts/*` — live script coverage counts

The page reads `results.js` via a `<script>` tag, so it renders both over `file://` (double-click `index.html`) and
over GitHub Pages — no local server or fetch/CORS needed.

## Enabling GitHub Pages

In the repository: **Settings → Pages → Build and deployment → Source: Deploy from a branch**, then select
branch `main` and folder `/docs`. The dashboard publishes at
`https://<owner>.github.io/domain-expert/`.
