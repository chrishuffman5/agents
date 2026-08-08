#!/usr/bin/env node
/**
 * Claude Agent SDK preflight — READ ONLY.
 *
 * Reports, without making any network call or writing any file:
 *   1. Node / Python runtime versions vs the documented SDK minimums (Node 18+, Python 3.10+).
 *   2. Which authentication / provider environment variables are set (values are masked).
 *   3. Whether an Agent SDK package and a resolvable `claude` binary are present.
 *   4. The session transcript directory the SDK will use for THIS cwd, and how many
 *      transcripts are there — the single most common cause of "resume silently
 *      started a fresh session".
 *   5. Which SDK-relevant tuning environment variables are currently set.
 *
 * Usage: node scripts/sdk-preflight.mjs [--cwd <dir>]
 *
 * Facts checked here are documented at:
 *   https://code.claude.com/docs/en/agent-sdk/quickstart
 *   https://code.claude.com/docs/en/agent-sdk/sessions
 *   https://code.claude.com/docs/en/agent-sdk/hosting
 */

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

const argv = process.argv.slice(2);
const cwdFlag = argv.indexOf("--cwd");
const targetCwd = path.resolve(cwdFlag !== -1 && argv[cwdFlag + 1] ? argv[cwdFlag + 1] : process.cwd());

const ok = (s) => `  [ok]   ${s}`;
const warn = (s) => `  [warn] ${s}`;
const info = (s) => `  [info] ${s}`;
const section = (s) => `\n== ${s} ==`;

function tryExec(cmd, args) {
  try {
    return execFileSync(cmd, args, { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
  } catch {
    return null;
  }
}

function mask(value) {
  if (!value) return "";
  return value.length <= 8 ? "***" : `${value.slice(0, 4)}…${value.slice(-4)} (len ${value.length})`;
}

/* 1. Runtimes ------------------------------------------------------------- */
console.log(section("Runtimes (SDK minimums: Node 18+, Python 3.10+)"));

const nodeMajor = Number(process.versions.node.split(".")[0]);
console.log(nodeMajor >= 18
  ? ok(`Node ${process.versions.node}`)
  : warn(`Node ${process.versions.node} — TypeScript Agent SDK requires Node 18+`));

const pyOut = tryExec("python3", ["--version"]) ?? tryExec("python", ["--version"]);
if (!pyOut) {
  console.log(info("No python3/python on PATH (fine if you only use the TypeScript SDK)"));
} else {
  const m = pyOut.match(/(\d+)\.(\d+)/);
  const okPy = m && (Number(m[1]) > 3 || (Number(m[1]) === 3 && Number(m[2]) >= 10));
  console.log(okPy ? ok(pyOut) : warn(`${pyOut} — Python Agent SDK requires Python 3.10+`));
}

/* 2. Auth / provider ------------------------------------------------------ */
console.log(section("Authentication and provider selection"));

const apiKey = process.env.ANTHROPIC_API_KEY;
console.log(apiKey
  ? ok(`ANTHROPIC_API_KEY set — ${mask(apiKey)}`)
  : warn("ANTHROPIC_API_KEY not set in this process env. The SDK does NOT read .env files; load dotenv yourself."));

if (process.env.ANTHROPIC_BASE_URL) console.log(info(`ANTHROPIC_BASE_URL=${process.env.ANTHROPIC_BASE_URL}`));

const providers = [
  ["CLAUDE_CODE_USE_BEDROCK", "Amazon Bedrock"],
  ["CLAUDE_CODE_USE_ANTHROPIC_AWS", "Claude Platform on AWS (also needs ANTHROPIC_AWS_WORKSPACE_ID)"],
  ["CLAUDE_CODE_USE_VERTEX", "Google Cloud Agent Platform (Vertex)"],
  ["CLAUDE_CODE_USE_FOUNDRY", "Microsoft Foundry"],
];
const active = providers.filter(([v]) => process.env[v]);
if (active.length === 0) console.log(info("No third-party provider flag set — using the Anthropic API directly"));
for (const [v, label] of active) console.log(info(`${v}=1 → ${label}`));
if (active.length > 1) console.log(warn("More than one provider flag is set — expect ambiguous routing"));
if (process.env.CLAUDE_CODE_USE_ANTHROPIC_AWS && !process.env.ANTHROPIC_AWS_WORKSPACE_ID) {
  console.log(warn("CLAUDE_CODE_USE_ANTHROPIC_AWS is set but ANTHROPIC_AWS_WORKSPACE_ID is missing"));
}

/* 3. SDK package + bundled CLI binary ------------------------------------- */
console.log(section("SDK package and Claude Code binary"));

const tsPkg = path.join(targetCwd, "node_modules", "@anthropic-ai", "claude-agent-sdk", "package.json");
if (fs.existsSync(tsPkg)) {
  try {
    const { version } = JSON.parse(fs.readFileSync(tsPkg, "utf8"));
    console.log(ok(`@anthropic-ai/claude-agent-sdk ${version} installed in ${targetCwd}`));
  } catch {
    console.log(warn(`@anthropic-ai/claude-agent-sdk present but package.json unreadable at ${tsPkg}`));
  }
} else {
  console.log(info("No @anthropic-ai/claude-agent-sdk in this project's node_modules (Python-only project?)"));
}

const pyShow = tryExec("python3", ["-m", "pip", "show", "claude-agent-sdk"]) ??
               tryExec("python", ["-m", "pip", "show", "claude-agent-sdk"]);
if (pyShow) {
  const v = pyShow.split("\n").find((l) => l.startsWith("Version:"));
  console.log(ok(`claude-agent-sdk (Python) installed — ${v ?? "version unknown"}`));
}

const claudeOnPath = tryExec("claude", ["--version"]);
console.log(claudeOnPath
  ? ok(`claude binary on PATH — ${claudeOnPath}`)
  : info("No `claude` on PATH. Normally fine: both SDKs bundle a native binary. " +
         "It is NOT fine after a pip source-dist install or `npm ci --omit=optional` — " +
         "install Claude Code natively and set pathToClaudeCodeExecutable / cli_path."));

/* 4. Session transcript directory for this cwd ---------------------------- */
console.log(section("Session transcripts for this working directory"));

const configDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), ".claude");
const encodedCwd = targetCwd.replace(/[^a-zA-Z0-9]/g, "-");
const projectDir = path.join(configDir, "projects", encodedCwd);

console.log(info(`cwd            ${targetCwd}`));
console.log(info(`encoded as     ${encodedCwd}`));
console.log(info(`transcript dir ${projectDir}`));

if (!fs.existsSync(projectDir)) {
  console.log(info("Directory does not exist yet — no sessions recorded for this cwd."));
  console.log(warn("`resume` / `continue` run from a DIFFERENT cwd will look here, find nothing, " +
                   "and silently start a fresh session instead of erroring."));
} else {
  const transcripts = fs.readdirSync(projectDir).filter((f) => f.endsWith(".jsonl"));
  console.log(ok(`${transcripts.length} transcript file(s) present`));
  const recent = transcripts
    .map((f) => ({ f, m: fs.statSync(path.join(projectDir, f)).mtimeMs }))
    .sort((a, b) => b.m - a.m)
    .slice(0, 5);
  for (const { f, m } of recent) {
    console.log(info(`  ${path.basename(f, ".jsonl")}  (modified ${new Date(m).toISOString()})`));
  }
  console.log(info("`continue` resumes the most recent of these; `resume` needs the session id (the filename stem)."));
}

/* 5. Tuning environment variables ----------------------------------------- */
console.log(section("SDK-relevant environment variables currently set"));

const tuning = [
  "MCP_TIMEOUT", "MCP_CONNECTION_NONBLOCKING", "MCP_CONNECT_TIMEOUT_MS", "MAX_MCP_OUTPUT_TOKENS",
  "CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH", "CLAUDE_CODE_DISABLE_AUTO_MEMORY", "CLAUDE_CONFIG_DIR",
  "ENABLE_PROMPT_CACHING_1H", "API_TIMEOUT_MS", "CLAUDE_CODE_MAX_RETRIES",
  "CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS", "CLAUDE_ENABLE_STREAM_WATCHDOG", "CLAUDE_STREAM_IDLE_TIMEOUT_MS",
  "CLAUDE_CODE_ENABLE_TELEMETRY", "CLAUDE_CODE_ENHANCED_TELEMETRY_BETA", "OTEL_EXPORTER_OTLP_ENDPOINT",
];
const set = tuning.filter((v) => process.env[v] !== undefined);
if (set.length === 0) console.log(info("None set — all defaults in effect"));
for (const v of set) console.log(info(`${v}=${process.env[v]}`));

console.log("\nPreflight complete. Nothing was written and no network request was made.\n");

/* ## Sources
 * - https://code.claude.com/docs/en/agent-sdk/quickstart   (Node 18+/Python 3.10+, ANTHROPIC_API_KEY,
 *   no .env loading, provider env vars, bundled-binary caveats)
 * - https://code.claude.com/docs/en/agent-sdk/sessions     (~/.claude/projects/<encoded-cwd>/*.jsonl,
 *   CLAUDE_CONFIG_DIR, non-alphanumeric → "-", continue vs resume)
 * - https://code.claude.com/docs/en/agent-sdk/hosting      (CLAUDE_CONFIG_DIR, CLAUDE_CODE_DISABLE_AUTO_MEMORY,
 *   telemetry env vars, bundled binary pinned to SDK version)
 * - https://code.claude.com/docs/en/agent-sdk/mcp          (MCP_TIMEOUT, MCP_CONNECTION_NONBLOCKING,
 *   MCP_CONNECT_TIMEOUT_MS, MAX_MCP_OUTPUT_TOKENS)
 * - https://code.claude.com/docs/en/agent-sdk/subagents    (CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH)
 * - https://code.claude.com/docs/en/agent-sdk/typescript   (API_TIMEOUT_MS, CLAUDE_CODE_MAX_RETRIES,
 *   CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS, CLAUDE_ENABLE_STREAM_WATCHDOG, CLAUDE_STREAM_IDLE_TIMEOUT_MS)
 * - https://code.claude.com/docs/en/agent-sdk/cost-tracking (ENABLE_PROMPT_CACHING_1H)
 *
 * Fetched: 2026-08-05
 */
