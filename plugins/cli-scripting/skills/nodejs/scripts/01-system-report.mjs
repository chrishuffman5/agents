#!/usr/bin/env node
// ============================================================================
// Node.js - System Information Report
//
// Purpose : Generate a system info report using node:os, node:fs, process
// Version : 1.0.0
// Targets : Node.js 20+
// Safety  : Read-only. No modifications to system configuration.
//
// Usage:
//   node 01-system-report.mjs [--json] [--output report.txt]
//
// Sections:
//   1. OS Identity and Version
//   2. CPU and Memory
//   3. Network Interfaces
//   4. Node.js Environment
//   5. Directory Info
// ============================================================================
import os from 'node:os';
import fs from 'node:fs/promises';
import path from 'node:path';
import { parseArgs } from 'node:util';

const { values } = parseArgs({
  args: process.argv.slice(2),
  options: {
    json:   { type: 'boolean', default: false },
    output: { type: 'string',  short: 'o' },
  },
});

function formatBytes(bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let val = bytes, unit = 0;
  while (val >= 1024 && unit < units.length - 1) { val /= 1024; unit++; }
  return `${val.toFixed(1)} ${units[unit]}`;
}

function formatUptime(seconds) {
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return `${d}d ${h}h ${m}m`;
}

async function gatherInfo() {
  const cpus = os.cpus();
  const nets = os.networkInterfaces();
  const interfaces = Object.entries(nets).flatMap(([name, addrs]) =>
    (addrs ?? []).filter(a => !a.internal).map(a => ({ name, address: a.address, family: a.family }))
  );

  return {
    timestamp:   new Date().toISOString(),
    hostname:    os.hostname(),
    platform:    os.platform(),
    arch:        os.arch(),
    release:     os.release(),
    nodeVersion: process.version,
    uptime:      { seconds: os.uptime(), human: formatUptime(os.uptime()) },
    cpu: {
      model:     cpus[0]?.model ?? 'unknown',
      cores:     cpus.length,
      speed_mhz: cpus[0]?.speed ?? 0,
      loadavg:   os.loadavg(),
    },
    memory: {
      total: formatBytes(os.totalmem()),
      free:  formatBytes(os.freemem()),
      used:  formatBytes(os.totalmem() - os.freemem()),
      pct:   `${(((os.totalmem() - os.freemem()) / os.totalmem()) * 100).toFixed(1)}%`,
    },
    dirs: {
      home:   os.homedir(),
      tmp:    os.tmpdir(),
      cwd:    process.cwd(),
      script: import.meta.dirname ?? path.dirname(new URL(import.meta.url).pathname),
    },
    network: interfaces,
    env: {
      NODE_ENV:  process.env.NODE_ENV ?? '(unset)',
      PATH_dirs: (process.env.PATH ?? '').split(path.delimiter).length,
    },
  };
}

function formatText(info) {
  const sep = '='.repeat(60);
  return [
    sep,
    `  SYSTEM REPORT - ${info.timestamp}`,
    sep,
    `  Host:     ${info.hostname}  (${info.platform}/${info.arch})`,
    `  OS:       ${info.release}`,
    `  Node.js:  ${info.nodeVersion}`,
    `  Uptime:   ${info.uptime.human}`,
    '',
    `  CPU:      ${info.cpu.model}`,
    `            ${info.cpu.cores} cores @ ${info.cpu.speed_mhz} MHz`,
    `            Load: ${info.cpu.loadavg.map(l => l.toFixed(2)).join(', ')}`,
    '',
    `  Memory:   ${info.memory.used} used / ${info.memory.total} total (${info.memory.pct})`,
    `            ${info.memory.free} free`,
    '',
    `  Dirs:     home=${info.dirs.home}`,
    `            tmp=${info.dirs.tmp}`,
    `            cwd=${info.dirs.cwd}`,
    '',
    `  Network:`,
    ...info.network.map(n => `            ${n.name}: ${n.address} (${n.family})`),
    '',
    `  Env:      NODE_ENV=${info.env.NODE_ENV}`,
    `            PATH dirs: ${info.env.PATH_dirs}`,
    sep,
  ].join('\n');
}

const info = await gatherInfo();
const output = values.json ? JSON.stringify(info, null, 2) : formatText(info);

if (values.output) {
  await fs.writeFile(values.output, output + '\n', 'utf8');
  console.log(`Report written to: ${values.output}`);
} else {
  console.log(output);
}
