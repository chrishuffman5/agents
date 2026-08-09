-- Cross-harness eval matrix: queue + ledger schema.
-- One row in runs = one planned CLI invocation (the pre-rendered "training command").
CREATE TABLE IF NOT EXISTS runs (
  run_id            TEXT PRIMARY KEY,
  harness           TEXT NOT NULL,             -- claude | codex | pi
  provider          TEXT NOT NULL,             -- anthropic | openai | ollama
  model             TEXT NOT NULL,             -- literal model id passed to the CLI
  effort_norm       TEXT NOT NULL,             -- E1 | E2 | E3
  effort_literal    TEXT NOT NULL,             -- what the harness actually receives
  skill_mode        TEXT NOT NULL,             -- skill | no-skill
  lane              TEXT NOT NULL,             -- cloud | local
  sandbox           TEXT,                      -- codex -s value, NULL for other harnesses
  suite             TEXT NOT NULL,
  task_id           TEXT NOT NULL,
  skill             TEXT NOT NULL,             -- aws-cli | aws (which skill the task targets)
  knowledge         TEXT,                      -- recent | stable (task discriminator class)
  attempt           INTEGER NOT NULL,
  command           TEXT NOT NULL,             -- fully rendered CLI string
  env_json          TEXT NOT NULL DEFAULT '{}',-- per-run env map; @secret: tokens resolved at dispatch
  workspace         TEXT NOT NULL,             -- per-run dir (parallel runs never share files)
  status            TEXT NOT NULL DEFAULT 'queued',  -- queued | running | done | error
  claimed_by        TEXT,
  started_at        TEXT,
  finished_at       TEXT,
  exit_code         INTEGER,
  wall_ms           INTEGER,
  tokens_in         INTEGER,
  tokens_out        INTEGER,
  tokens_cache_read INTEGER,
  cost_usd          REAL,
  output_path       TEXT,
  answer            TEXT,
  grade             TEXT,                      -- pass | fail | ungraded
  graded_by         TEXT                       -- expected-spec | judge:<model>
);
CREATE INDEX IF NOT EXISTS idx_runs_status_lane ON runs(status, lane);
CREATE INDEX IF NOT EXISTS idx_runs_cell ON runs(harness, model, effort_norm, skill_mode);

-- Serial timing confirmation pass: N repeats per headline run; medians quoted, sweep numbers never.
CREATE TABLE IF NOT EXISTS timing_samples (
  run_id  TEXT NOT NULL,
  rep     INTEGER NOT NULL,
  wall_ms INTEGER NOT NULL,
  PRIMARY KEY (run_id, rep)
);
