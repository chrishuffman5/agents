#!/usr/bin/env node
// ============================================================================
// Node.js - Complete CLI Tool
//
// Purpose : Full CLI tool with parseArgs, subcommands, colors, spinner,
//           interactive prompts, and structured output.
// Version : 1.0.0
// Targets : Node.js 20+
// Safety  : Read-only scanning. No modifications to system configuration.
//
// Dependencies (optional, graceful degradation):
//   npm install chalk ora @inquirer/prompts
//
// Usage:
//   node 04-cli-tool.mjs scan --dir . --ext .js,.mjs
//   node 04-cli-tool.mjs report --json
//   node 04-cli-tool.mjs interactive
//
// Sections:
//   1. Lazy-Loaded Optional Dependencies
//   2. Subcommand: scan (directory file scanning)
//   3. Subcommand: report (system info)
//   4. Subcommand: interactive (guided prompts)
//   5. Entry Point and Help
// ============================================================================
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { parseArgs } from 'node:util';

// -- Section 1: Lazy-Load Optional Packages -----------------------------------
async function tryImport(pkg, fallback) {
  try { return await import(pkg); } catch { return fallback; }
}

const chalkMod    = await tryImport('chalk', null);
const oraMod      = await tryImport('ora', null);
const inquirerMod = await tryImport('@inquirer/prompts', null);

const chalk = chalkMod?.default ?? {
  green: s => s, red: s => s, yellow: s => s, blue: s => s,
  bold: s => s, gray: s => s, cyan: s => s, white: s => s,
};
const ora = oraMod?.default ?? ((opts) => ({
  start() { process.stdout.write((opts.text ?? opts) + '...\n'); return this; },
  succeed(t) { console.log('[OK]', t); },
  fail(t) { console.error('[FAIL]', t); },
  stop() {},
}));

// -- Utilities ----------------------------------------------------------------
function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 ** 2) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 ** 2).toFixed(2)} MB`;
}

function log(level, msg) {
  const sym = { info: chalk.blue('i'), ok: chalk.green('+'), warn: chalk.yellow('!'), err: chalk.red('x') };
  console.log(`${sym[level] ?? '.'} ${msg}`);
}

// -- Section 2: Subcommand: scan ----------------------------------------------
async function scanCommand(args) {
  const { values } = parseArgs({
    args,
    options: {
      dir:  { type: 'string', default: '.' },
      ext:  { type: 'string', default: '.js,.mjs,.ts' },
      json: { type: 'boolean', default: false },
    },
  });

  const exts    = values.ext.split(',').map(e => e.trim());
  const spinner = ora(`Scanning ${chalk.cyan(values.dir)} for ${exts.join(', ')} files`).start();

  try {
    const allFiles = await fs.readdir(values.dir, { recursive: true, withFileTypes: true });
    const matches  = allFiles
      .filter(d => d.isFile() && exts.includes(path.extname(d.name)))
      .map(d => path.join(d.parentPath ?? d.path ?? values.dir, d.name));

    const fileStats = await Promise.all(
      matches.map(async (f) => {
        const stat = await fs.stat(f);
        return { path: f, size: stat.size, mtime: stat.mtime };
      })
    );

    spinner.succeed(`Found ${chalk.bold(String(fileStats.length))} files`);

    if (values.json) {
      console.log(JSON.stringify(fileStats, null, 2));
    } else {
      const totalSize = fileStats.reduce((s, f) => s + f.size, 0);
      fileStats.sort((a, b) => b.size - a.size);
      console.log('');
      fileStats.slice(0, 20).forEach(f => {
        const rel  = path.relative(process.cwd(), f.path);
        const size = chalk.gray(formatBytes(f.size).padStart(10));
        console.log(`  ${size}  ${rel}`);
      });
      if (fileStats.length > 20) {
        console.log(chalk.gray(`  ... and ${fileStats.length - 20} more`));
      }
      console.log('');
      log('info', `Total: ${chalk.bold(formatBytes(totalSize))} across ${fileStats.length} files`);
    }
  } catch (err) {
    spinner.fail(`Scan failed: ${err.message}`);
    process.exit(1);
  }
}

// -- Section 3: Subcommand: report --------------------------------------------
async function reportCommand(args) {
  const { values } = parseArgs({
    args,
    options: { json: { type: 'boolean', default: false } },
  });

  const info = {
    host:     os.hostname(),
    platform: os.platform(),
    arch:     os.arch(),
    node:     process.version,
    memory:   { total: formatBytes(os.totalmem()), free: formatBytes(os.freemem()) },
    cwd:      process.cwd(),
    uptime:   `${Math.floor(os.uptime() / 60)} minutes`,
  };

  if (values.json) {
    console.log(JSON.stringify(info, null, 2));
    return;
  }

  console.log('');
  console.log(chalk.bold('  System Report'));
  console.log(chalk.gray('  ' + '-'.repeat(30)));
  Object.entries(info).forEach(([k, v]) => {
    const key = chalk.gray(k.padEnd(10));
    const val = typeof v === 'object' ? JSON.stringify(v) : v;
    console.log(`  ${key} ${chalk.white(val)}`);
  });
  console.log('');
}

// -- Section 4: Subcommand: interactive ---------------------------------------
async function interactiveCommand() {
  if (!inquirerMod) {
    console.error(chalk.red('Install @inquirer/prompts to use interactive mode'));
    console.error('  npm install @inquirer/prompts');
    process.exit(1);
  }
  const { input, confirm, select, checkbox } = inquirerMod;

  console.log('\n' + chalk.bold('  Interactive CLI Demo') + '\n');

  const name     = await input({ message: 'Your name:' });
  const format   = await select({
    message: 'Output format:',
    choices: ['JSON', 'CSV', 'YAML'].map(v => ({ name: v, value: v.toLowerCase() })),
  });
  const features = await checkbox({
    message: 'Enable features:',
    choices: [
      { name: 'Verbose logging', value: 'verbose' },
      { name: 'Dry run mode',    value: 'dryrun'  },
      { name: 'Auto backup',     value: 'backup'  },
    ],
  });
  const proceed  = await confirm({ message: 'Confirm settings?', default: true });

  if (!proceed) { log('warn', 'Cancelled by user.'); return; }

  console.log('');
  log('ok', `Hello, ${chalk.bold(name)}!`);
  log('info', `Format: ${chalk.cyan(format)}`);
  log('info', `Features: ${features.length ? features.join(', ') : 'none'}`);
  console.log('');
}

// -- Section 5: Entry Point ---------------------------------------------------
const [command, ...restArgs] = process.argv.slice(2);

const commands = {
  scan:        scanCommand,
  report:      reportCommand,
  interactive: interactiveCommand,
};

if (!command || command === '--help' || command === '-h') {
  console.log(`
${chalk.bold('Usage:')} node 04-cli-tool.mjs <command> [options]

${chalk.bold('Commands:')}
  scan         Scan directory for files
               ${chalk.gray('--dir <path>     directory to scan (default: .)')}
               ${chalk.gray('--ext <exts>     extensions to match (default: .js,.mjs,.ts)')}
               ${chalk.gray('--json           output JSON')}

  report       Show system report
               ${chalk.gray('--json           output JSON')}

  interactive  Guided interactive prompts demo

${chalk.bold('Examples:')}
  node 04-cli-tool.mjs scan --dir src --ext .ts
  node 04-cli-tool.mjs report --json
  node 04-cli-tool.mjs interactive
`);
  process.exit(0);
}

if (!commands[command]) {
  log('err', `Unknown command: ${chalk.bold(command)}`);
  process.exit(1);
}

await commands[command](restArgs);
