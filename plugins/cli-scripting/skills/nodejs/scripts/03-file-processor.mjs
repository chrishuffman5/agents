#!/usr/bin/env node
// ============================================================================
// Node.js - Stream-Based File Processor
//
// Purpose : CSV-to-JSON transformer with streaming, filtering, and statistics.
//           Creates a sample CSV if the input file does not exist.
// Version : 1.0.0
// Targets : Node.js 20+
// Safety  : Creates sample.csv only if missing. Writes to --output path.
//
// Usage:
//   node 03-file-processor.mjs --input data.csv --output out.json
//   node 03-file-processor.mjs --input data.csv --output out.json --filter "age>25"
//
// Sections:
//   1. Sample CSV Generation
//   2. CSV Line Parser
//   3. Transform Streams (CSV -> Object, Filter, Stats, JSON Writer)
//   4. Pipeline Execution
// ============================================================================
import fs from 'node:fs/promises';
import { createReadStream, createWriteStream, existsSync } from 'node:fs';
import { pipeline, Transform } from 'node:stream';
import { promisify, parseArgs } from 'node:util';

const pipelineAsync = promisify(pipeline);

const { values } = parseArgs({
  args: process.argv.slice(2),
  options: {
    input:  { type: 'string', short: 'i', default: 'sample.csv' },
    output: { type: 'string', short: 'o', default: 'output.json' },
    filter: { type: 'string', short: 'f' },
  },
});

// -- Section 1: Create Sample CSV If Needed -----------------------------------
async function ensureSampleCsv(filePath) {
  if (existsSync(filePath)) return;
  const rows = [
    'id,name,age,department,salary',
    '1,Alice,32,Engineering,95000',
    '2,Bob,28,Marketing,72000',
    '3,Carol,41,Engineering,115000',
    '4,Dave,24,Design,68000',
    '5,Eve,35,Engineering,98000',
    '6,Frank,29,Marketing,74000',
    '7,Grace,38,Design,82000',
    '8,Henry,31,Engineering,89000',
  ];
  await fs.writeFile(filePath, rows.join('\n') + '\n');
  console.log(`Created sample CSV: ${filePath}`);
}

// -- Section 2: CSV Line Parser -----------------------------------------------
function parseCsvLine(line) {
  const fields = [];
  let current = '', inQuotes = false;
  for (const ch of line) {
    if (ch === '"') { inQuotes = !inQuotes; continue; }
    if (ch === ',' && !inQuotes) { fields.push(current); current = ''; continue; }
    current += ch;
  }
  fields.push(current);
  return fields;
}

// -- Section 3: Transform Streams ---------------------------------------------
function csvToObjectTransform(headers) {
  let headersParsed = false;
  return new Transform({
    readableObjectMode: true,
    transform(chunk, _enc, cb) {
      const lines = chunk.toString().split('\n').filter(l => l.trim());
      for (const line of lines) {
        if (!headersParsed) { headersParsed = true; continue; }
        const vals = parseCsvLine(line);
        if (vals.length !== headers.length) continue;
        const obj = Object.fromEntries(headers.map((h, i) => [h, vals[i]]));
        if (obj.id)     obj.id     = Number(obj.id);
        if (obj.age)    obj.age    = Number(obj.age);
        if (obj.salary) obj.salary = Number(obj.salary);
        this.push(obj);
      }
      cb();
    },
  });
}

function filterTransform(filterExpr) {
  if (!filterExpr) return new Transform({ objectMode: true, transform(c, _, cb) { cb(null, c); } });
  const match = filterExpr.match(/^(\w+)([><=!]+)(.+)$/);
  if (!match) throw new Error(`Invalid filter: ${filterExpr}`);
  const [, field, op, rawVal] = match;
  const val = isNaN(rawVal) ? rawVal : Number(rawVal);
  const ops = { '>': (a, b) => a > b, '<': (a, b) => a < b, '=': (a, b) => a === b, '>=': (a, b) => a >= b, '<=': (a, b) => a <= b };
  const cmp = ops[op] ?? ((a, b) => String(a).includes(String(b)));
  return new Transform({
    objectMode: true,
    transform(obj, _enc, cb) {
      if (cmp(obj[field], val)) cb(null, obj);
      else cb();
    },
  });
}

function statsTransform() {
  const stats = { count: 0, totalSalary: 0, departments: {} };
  return {
    transform: new Transform({
      objectMode: true,
      transform(obj, _enc, cb) {
        stats.count++;
        stats.totalSalary += obj.salary ?? 0;
        stats.departments[obj.department] = (stats.departments[obj.department] ?? 0) + 1;
        cb(null, obj);
      },
    }),
    getStats: () => ({
      ...stats,
      avgSalary: stats.count ? Math.round(stats.totalSalary / stats.count) : 0,
    }),
  };
}

function jsonArrayWriteStream(destPath) {
  const out = createWriteStream(destPath);
  let first = true;
  out.write('[\n');
  const transform = new Transform({
    objectMode: true,
    transform(obj, _enc, cb) {
      const comma = first ? '' : ',\n';
      first = false;
      out.write(comma + '  ' + JSON.stringify(obj));
      cb();
    },
    flush(cb) { out.write('\n]\n'); out.end(); cb(); },
  });
  return { transform, writable: out };
}

// -- Section 4: Pipeline Execution --------------------------------------------
await ensureSampleCsv(values.input);

const headerLine = (await fs.readFile(values.input, 'utf8')).split('\n')[0];
const headers = parseCsvLine(headerLine);
console.log(`Headers: ${headers.join(', ')}`);
if (values.filter) console.log(`Filter:  ${values.filter}`);

const { transform: statsT, getStats } = statsTransform();
const { transform: jsonT } = jsonArrayWriteStream(values.output);

await pipelineAsync(
  createReadStream(values.input),
  csvToObjectTransform(headers),
  filterTransform(values.filter),
  statsT,
  jsonT,
);

const stats = getStats();
console.log(`\nResults:`);
console.log(`  Records processed : ${stats.count}`);
console.log(`  Avg salary        : $${stats.avgSalary.toLocaleString()}`);
console.log(`  By department     :`, stats.departments);
console.log(`  Output written to : ${values.output}`);
