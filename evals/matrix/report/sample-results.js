// SYNTHETIC SAMPLE DATA — design preview only. Nothing here is a measurement.
// Deterministic generator (fixed seed) shaped like the hypothesis so the report's
// layout can be reviewed before a real sweep. build-report.ps1 writes results.js
// with real aggregates; when that file reports completed runs, this sample is ignored.
(function () {
  let seed = 42;
  const rnd = () => (seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648;

  const lanes = [
    { harness: "claude", provider: "anthropic", lane: "cloud",
      models: ["claude-opus-5", "claude-sonnet-5", "claude-haiku-4-5"], efforts: ["E1", "E2", "E3"] },
    { harness: "codex", provider: "openai", lane: "cloud",
      models: ["gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna"], efforts: ["E1", "E2", "E3"] },
    { harness: "pi", provider: "anthropic", lane: "cloud",
      models: ["anthropic/claude-opus-5", "anthropic/claude-sonnet-5", "anthropic/claude-haiku-4-5"], efforts: ["E1", "E2", "E3"] },
    { harness: "pi", provider: "openai", lane: "cloud",
      models: ["openai/gpt-5.6-sol", "openai/gpt-5.6-terra", "openai/gpt-5.6-luna"], efforts: ["E1", "E2", "E3"] },
    { harness: "codex", provider: "ollama", lane: "local",
      models: ["gemma4:12b", "glm-4.7-flash:q4_K_M-32k", "qwen3.6:27b"], efforts: ["E1", "E2"] },
    { harness: "pi", provider: "ollama", lane: "local",
      models: ["ollama/gemma4:12b", "ollama/glm-4.7-flash:q4_K_M-32k", "ollama/qwen3.6:27b"], efforts: ["E1", "E2"] }
  ];
  const TASKS = 12;
  const tierOf = m => /opus|sol/.test(m) ? 0 : /sonnet|terra/.test(m) ? 1 : /haiku|luna/.test(m) ? 2 : 3;

  const cells = [];
  for (const l of lanes) {
    for (const m of l.models) {
      const tier = tierOf(m);
      for (const e of l.efforts) {
        const ei = { E1: 0, E2: 1, E3: 2 }[e];
        for (const mode of ["skill", "no-skill"]) {
          // Hypothesis-shaped synthetic accuracy: skill flattens the effort curve and lifts small models.
          let p = mode === "skill"
            ? 0.88 - tier * 0.05 + ei * 0.015
            : 0.42 - tier * 0.08 + ei * 0.13;
          p = Math.max(0.05, Math.min(0.98, p + (rnd() - 0.5) * 0.06));
          const pass = Math.round(p * TASKS);
          const baseMs = (l.lane === "local" ? 22000 : tier === 0 ? 9000 : tier === 1 ? 6000 : 4200);
          const thinkMs = (ei + 1) * (mode === "skill" ? 1400 : 3600);
          const wallMs = Math.round(baseMs + thinkMs + rnd() * 1500);
          const tokensOut = Math.round((mode === "skill" ? 260 : 700) * (1 + ei * (mode === "skill" ? 0.15 : 0.55)) + rnd() * 80);
          cells.push({ harness: l.harness, provider: l.provider, model: m, lane: l.lane,
                       effort: e, mode, runs: TASKS, done: TASKS, pass,
                       wallMs, tokensOut, cost: l.lane === "local" ? null : +(tokensOut * (tier === 0 ? 0.00006 : 0.00002)).toFixed(3) });
        }
      }
    }
  }

  const taskIds = [
    ["awscli-login-version", "aws-cli", "recent"], ["awscli-role-chaining", "aws-cli", "stable"],
    ["awscli-presign-max", "aws-cli", "stable"], ["awscli-text-none", "aws-cli", "recent"],
    ["awscli-sso-logout", "aws-cli", "recent"], ["awscli-cred-precedence", "aws-cli", "stable"],
    ["aws-scp-mgmt", "aws", "stable"], ["aws-tag-limits", "aws", "stable"],
    ["aws-cost-tag-backfill", "aws", "recent"], ["aws-ou-depth", "aws", "stable"],
    ["aws-enforced-for", "aws", "recent"], ["aws-migrationhub-status", "aws", "recent"]
  ];
  const tasks = taskIds.map(([id, skill, knowledge]) => {
    const n = 96; // runs per task per mode across all cells
    const base = knowledge === "recent" ? 0.18 : 0.55;
    return { id, skill, knowledge,
      nSkill: n, passSkill: Math.round(n * Math.min(0.97, 0.86 + rnd() * 0.08)),
      nNoSkill: n, passNoSkill: Math.round(n * Math.max(0.03, base + (rnd() - 0.5) * 0.1)) };
  });

  window.MATRIX_SAMPLE = {
    sample: true,
    generated: "SYNTHETIC — not a measurement",
    suite: "aws (12 tasks: 6 aws-cli + 6 aws)",
    status: { queued: 0, running: 0, done: 1152, error: 0 },
    lanes: lanes.map(l => ({ lane: l.lane, harness: l.harness,
      total: l.models.length * l.efforts.length * 2 * TASKS,
      done:  l.models.length * l.efforts.length * 2 * TASKS })),
    cells, tasks
  };
})();
