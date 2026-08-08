#!/usr/bin/env node
// Read-only preflight for the OpenAI Agents SDK (TypeScript/JavaScript).
//
// Reports the Node version against the documented floor, resolved versions of
// @openai/agents and its peers, the installed Zod major (v4 is required), and
// which SDK-relevant environment variables are set. Values of secrets are NEVER
// printed -- only whether the variable is present.
//
// Makes no network calls, imports nothing from the SDK, and writes no files.
//
// Usage:  node agents-sdk-preflight.mjs      (run from your project root)

import { createRequire } from 'node:module';

const require = createRequire(`${process.cwd()}/`);

const PACKAGES = [
  ['@openai/agents', 'the SDK'],
  ['@openai/agents-core', 'core primitives (transitive)'],
  ['@openai/agents-realtime', 'standalone realtime package, optional'],
  ['zod', 'REQUIRED at v4 for tool schemas and structured outputs'],
  ['openai', 'underlying platform client'],
];

const ENV_VARS = [
  ['OPENAI_API_KEY', 'required for text and sandbox agents'],
  ['OPENAI_DEFAULT_MODEL', 'overrides the default model globally'],
  ['OPENAI_BASE_URL', 'custom endpoint'],
  ['OPENAI_ORG_ID', ''],
  ['OPENAI_PROJECT_ID', ''],
];

function resolveVersion(name) {
  try {
    return require(`${name}/package.json`).version;
  } catch {
    try {
      // Some packages restrict subpath exports; fall back to main resolution.
      const entry = require.resolve(name);
      return entry ? 'installed (version not readable via package.json export)' : null;
    } catch {
      return null;
    }
  }
}

const major = Number(process.versions.node.split('.')[0]);
console.log('== Runtime ==');
console.log(`  node ${process.versions.node}  (documented floor: Node.js 22+ -> ${major >= 22 ? 'ok' : 'TOO OLD'})`);
console.log(`  cwd: ${process.cwd()}`);
console.log('  Deno and Bun are also supported; Cloudflare Workers is experimental and needs nodejs_compat.');

console.log('\n== Packages ==');
for (const [name, note] of PACKAGES) {
  const v = resolveVersion(name);
  console.log(`  ${name.padEnd(26)} ${(v ?? 'NOT RESOLVED').padEnd(28)} ${note}`);
}

const zod = resolveVersion('zod');
if (zod && /^\d/.test(zod)) {
  const zodMajor = Number(zod.split('.')[0]);
  console.log(
    `\n  zod major = ${zodMajor} -> ${zodMajor === 4 ? 'ok' : 'MISMATCH: @openai/agents documents Zod v4'}`,
  );
}

console.log('\n== Environment (presence only, values never printed) ==');
for (const [name, note] of ENV_VARS) {
  const state = process.env[name] ? 'set' : 'unset';
  console.log(`  ${name.padEnd(24)} ${state}${note ? `  # ${note}` : ''}`);
}

console.log('\nReminder: tracing is ON by default in Node/Deno/Bun and exports spans,');
console.log('including tool I/O, to OpenAI. In Cloudflare Workers call');
console.log('getGlobalTraceProvider().forceFlush() before the runtime tears down.');

// Sources
// - https://github.com/openai/openai-agents-js
// - https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/quickstart.mdx
// - https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/tracing.mdx
// - https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/voice-agents/quickstart.mdx
// Fetched: 2026-08-05
