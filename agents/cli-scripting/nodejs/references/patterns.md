# Node.js Scripting Patterns Reference

Dense reference for file system, process/OS, HTTP/fetch, JSON/data, async patterns, and stream processing.

---

## File System (node:fs/promises)

### Read / Write / Append

```js
import fs from 'node:fs/promises';
import path from 'node:path';

// Read entire file
const text = await fs.readFile('/path/to/file.txt', 'utf8');
const buf  = await fs.readFile('/path/to/image.png');           // Buffer

// Write string (creates or overwrites)
await fs.writeFile('out.txt', 'hello world\n', 'utf8');

// Write JSON with pretty-printing
await fs.writeFile('config.json', JSON.stringify(data, null, 2) + '\n');

// Append
await fs.appendFile('log.txt', `${new Date().toISOString()} - event\n`);
```

### Directory Operations

```js
// List directory (string[])
const entries = await fs.readdir('/path/to/dir');

// List with file types (Dirent[])
const dirents = await fs.readdir('/path/to/dir', { withFileTypes: true });
const files = dirents.filter(d => d.isFile()).map(d => d.name);
const dirs  = dirents.filter(d => d.isDirectory()).map(d => d.name);

// Recursive listing (Node 18.17+)
const all = await fs.readdir('/path/to/dir', { recursive: true });

// stat — file metadata
const stat = await fs.stat('file.txt');
console.log(stat.size, stat.mtime, stat.isDirectory());

// mkdir recursive (won't throw if exists)
await fs.mkdir('/path/to/new/nested/dir', { recursive: true });

// Remove file
await fs.unlink('/path/to/file.txt');

// Remove directory tree (like rm -rf)
await fs.rm('/path/to/dir', { recursive: true, force: true });

// Copy file
await fs.copyFile('/src/file.txt', '/dst/file.txt');

// Copy directory tree (Node 16.7+)
await fs.cp('/src/dir', '/dst/dir', { recursive: true });

// Rename / move
await fs.rename('/old/path.txt', '/new/path.txt');
```

### Path Utilities

```js
import path from 'node:path';

path.join('/base', 'sub', 'file.txt');       // /base/sub/file.txt
path.resolve('relative', 'file.txt');        // absolute path from cwd
path.dirname('/base/sub/file.txt');          // /base/sub
path.basename('/base/sub/file.txt');         // file.txt
path.basename('/base/sub/file.txt', '.txt'); // file
path.extname('/base/sub/file.txt');          // .txt
path.parse('/base/sub/file.txt');
// { root: '/', dir: '/base/sub', base: 'file.txt', ext: '.txt', name: 'file' }

// ESM __dirname / __filename
import { fileURLToPath } from 'node:url';
const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);

// Or use import.meta.dirname (Node 21.2+)
const dir = import.meta.dirname;
```

### Glob Patterns

```js
// Node 22+ — built-in glob
import { glob } from 'node:fs/promises';
const jsFiles = await Array.fromAsync(glob('**/*.js', { cwd: '/project' }));

// fast-glob (all versions)
import fg from 'fast-glob';
const files = await fg(['src/**/*.ts', '!**/*.test.ts'], { cwd: process.cwd() });

// globby (ESM wrapper with extras)
import { globby } from 'globby';
const matches = await globby(['**/*.json', '!node_modules'], { gitignore: true });
```

### Watch for Changes

```js
// Node 19+ — recursive file watcher
const watcher = fs.watch('/path/to/dir', { recursive: true });
for await (const event of watcher) {
  console.log(event.eventType, event.filename);
}
```

---

## Process and OS

### process Globals

```js
// Command-line arguments
const args = process.argv.slice(2); // [0]=node, [1]=script

// Environment
const port   = process.env.PORT ?? '3000';
const isProd = process.env.NODE_ENV === 'production';

// Directories
const cwd       = process.cwd();
const scriptDir = import.meta.dirname; // Node 21.2+

// Exit
process.exit(0); // success
process.exit(1); // failure

// Streams
process.stdin.setEncoding('utf8');
process.stdout.write('output ');
process.stderr.write('error\n');

// Node executable
process.execPath;  // /usr/local/bin/node
process.version;   // v20.12.0
process.versions;  // { node, v8, openssl, ... }
```

### Signal Handling

```js
process.on('SIGINT',  () => { console.log('Interrupted'); process.exit(0); });
process.on('SIGTERM', () => { cleanup(); process.exit(0); });
process.on('uncaughtException', (err) => { console.error(err); process.exit(1); });
process.on('unhandledRejection', (reason) => { console.error(reason); process.exit(1); });
```

### child_process — When to Use Each

```js
import { exec, execFile, spawn, fork } from 'node:child_process';
import { promisify } from 'node:util';
const execAsync = promisify(exec);

// exec — shell command, buffered output (small commands)
const { stdout, stderr } = await execAsync('ls -la');
// WARNING: uses shell — avoid untrusted input

// execFile — binary directly, no shell (safer)
const { stdout: out } = await promisify(execFile)('git', ['log', '--oneline', '-10']);

// spawn — streaming I/O (large output, real-time display)
const child = spawn('ffmpeg', ['-i', 'input.mp4', 'output.mp3']);
child.stdout.pipe(process.stdout);
child.stderr.pipe(process.stderr);
await new Promise((res, rej) =>
  child.on('close', code => code === 0 ? res() : rej(new Error(`Exit ${code}`)))
);

// fork — another Node.js script with IPC
const worker = fork('./worker.mjs');
worker.send({ task: 'process', data: [1, 2, 3] });
worker.on('message', (result) => console.log(result));
```

### node:os

```js
import os from 'node:os';

os.hostname();              // 'my-laptop'
os.platform();              // 'linux' | 'darwin' | 'win32'
os.arch();                  // 'x64' | 'arm64'
os.cpus();                  // array of CPU core info
os.cpus().length;           // number of cores
os.totalmem();              // total RAM bytes
os.freemem();               // free RAM bytes
os.homedir();               // '/home/user'
os.tmpdir();                // '/tmp'
os.networkInterfaces();     // { eth0: [...], lo: [...] }
os.uptime();                // seconds since boot
os.loadavg();               // [1min, 5min, 15min] (Unix only)
os.EOL;                     // '\n' or '\r\n'
```

---

## HTTP / API Clients

### Built-in fetch (stable Node 21+, available Node 18+)

```js
// Simple GET
const res = await fetch('https://api.example.com/users');
if (!res.ok) throw new Error(`HTTP ${res.status}`);
const data = await res.json();

// POST with JSON
const res2 = await fetch('https://api.example.com/users', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
  body: JSON.stringify({ name: 'Alice' }),
});

// Timeout with AbortController
const ac = new AbortController();
const timer = setTimeout(() => ac.abort(), 5000);
try {
  const res3 = await fetch('https://slow-api.com/data', { signal: ac.signal });
  const text = await res3.text();
} finally {
  clearTimeout(timer);
}

// Stream download to file
import { createWriteStream } from 'node:fs';
import { pipeline } from 'node:stream/promises';
const res4 = await fetch('https://example.com/large-file.csv');
await pipeline(res4.body, createWriteStream('large-file.csv'));

// FormData multipart upload
const form = new FormData();
form.append('file', new Blob([await fs.readFile('data.csv')]), 'data.csv');
await fetch('https://api.example.com/upload', { method: 'POST', body: form });
```

### Retry with Exponential Back-off

```js
async function fetchWithRetry(url, options = {}, maxRetries = 3) {
  let lastError;
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const res = await fetch(url, options);
      if (res.status === 429 || res.status >= 500) {
        const delay = Math.min(1000 * 2 ** attempt + Math.random() * 100, 30_000);
        await new Promise(r => setTimeout(r, delay));
        continue;
      }
      return res;
    } catch (err) {
      lastError = err;
      if (attempt < maxRetries) {
        await new Promise(r => setTimeout(r, 1000 * 2 ** attempt));
      }
    }
  }
  throw lastError ?? new Error('Max retries exceeded');
}
```

### Pagination with Async Generator

```js
async function* paginate(baseUrl, token) {
  let url = baseUrl;
  while (url) {
    const res = await fetchWithRetry(url, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const { data, next_page_url } = await res.json();
    yield* data;
    url = next_page_url;
  }
}

for await (const item of paginate('https://api.example.com/items', myToken)) {
  console.log(item.id, item.name);
}
```

### undici — Connection Pooling

```js
import { Pool } from 'undici';

const pool = new Pool('https://api.example.com', { connections: 10 });
const { statusCode, body } = await pool.request({
  path: '/users?page=1',
  method: 'GET',
  headers: { Authorization: `Bearer ${token}` },
});
const users = await body.json();
await pool.close();
```

---

## JSON and Data Formats

### JSON

```js
// Safe parse
function safeJsonParse(text) {
  try { return { ok: true, data: JSON.parse(text) }; }
  catch (err) { return { ok: false, error: err.message }; }
}

// Pretty-print
const pretty = JSON.stringify(obj, null, 2);

// Replacer — omit sensitive keys
const safe = JSON.stringify(obj, (key, val) => key === 'password' ? undefined : val);

// Read package.json (ESM)
const pkg = JSON.parse(await fs.readFile('package.json', 'utf8'));
```

### Streaming JSON (Large Files)

```js
import { createReadStream } from 'node:fs';
import { chain } from 'stream-chain';
import { parser } from 'stream-json';
import { streamArray } from 'stream-json/streamers/StreamArray.js';

const pipeline2 = chain([
  createReadStream('large.json'),
  parser(),
  streamArray(),
]);

for await (const { key, value } of pipeline2) {
  console.log(key, value.name);
}
```

### CSV

```js
// csv-parse (streaming, robust)
import { parse } from 'csv-parse';
import { createReadStream } from 'node:fs';

const parser2 = createReadStream('data.csv').pipe(
  parse({ columns: true, trim: true, skip_empty_lines: true }),
);
for await (const row of parser2) {
  console.log(row); // { Name: 'Alice', Age: '30' }
}

// csv-stringify — write CSV
import { stringify } from 'csv-stringify/sync';
const csvText = stringify([{ name: 'Alice', age: 30 }], { header: true });
await fs.writeFile('out.csv', csvText);
```

### YAML

```js
import yaml from 'js-yaml';

const config = yaml.load(await fs.readFile('config.yaml', 'utf8'));
const yamlText = yaml.dump({ host: 'localhost', port: 5432 });
await fs.writeFile('config.yaml', yamlText);
```

---

## Async Patterns

### Promise Combinators

```js
// Parallel — fail fast on first rejection
const [users, posts, tags] = await Promise.all([
  fetchUsers(), fetchPosts(), fetchTags(),
]);

// Parallel — wait for all, collect errors
const results = await Promise.allSettled([fetchA(), fetchB(), fetchC()]);
results.forEach(r => {
  if (r.status === 'fulfilled') console.log(r.value);
  else console.error(r.reason);
});

// Race — first to settle wins
const winner = await Promise.race([fetchFast(), fetchSlow()]);

// Any — first to fulfill (ignores rejections unless all reject)
const first = await Promise.any([fetchA(), fetchB()]);
```

### Concurrency Limiting

```js
// Chunked concurrency (zero deps)
async function mapConcurrent(items, fn, concurrency = 5) {
  const results = [];
  for (let i = 0; i < items.length; i += concurrency) {
    results.push(...await Promise.all(items.slice(i, i + concurrency).map(fn)));
  }
  return results;
}

// p-limit (popular, precise)
import pLimit from 'p-limit';
const limit = pLimit(5);
const tasks = urls.map(url => limit(() => fetch(url).then(r => r.json())));
const data  = await Promise.all(tasks);
```

### Async Generators

```js
async function* readLines(filePath) {
  const content = await fs.readFile(filePath, 'utf8');
  for (const line of content.split('\n')) {
    if (line.trim()) yield line;
  }
}

for await (const line of readLines('data.txt')) {
  console.log(line);
}
```

### Timers from timers/promises

```js
import { setTimeout as sleep, setInterval as tick } from 'node:timers/promises';

await sleep(1000);                                    // 1 second delay
const val = await sleep(500, 'done');                 // delay + value

const interval = tick(1000, undefined, { signal: controller.signal });
for await (const _ of interval) {
  await pollSomething();
}
```

### AbortController for Cancellation

```js
const controller = new AbortController();
const { signal } = controller;

setTimeout(() => controller.abort(new Error('Timeout')), 10_000);

try {
  const res = await fetch('https://example.com/large', { signal });
} catch (err) {
  if (err.name === 'AbortError') console.error('Request aborted');
  else throw err;
}

// Combine signals (Node 20+)
const combined = AbortSignal.any([signal1, signal2]);
```

---

## Stream Processing

### Transform Pipeline

```js
import { createReadStream, createWriteStream } from 'node:fs';
import { pipeline } from 'node:stream/promises';
import { Transform } from 'node:stream';

const upperCase = new Transform({
  transform(chunk, enc, cb) { cb(null, chunk.toString().toUpperCase()); },
});

await pipeline(
  createReadStream('input.txt'),
  upperCase,
  createWriteStream('output.txt'),
);
```

### Async Generator as Stream Source

```js
async function* generateLines() {
  for (let i = 0; i < 100; i++) {
    yield `line ${i}\n`;
  }
}
await pipeline(generateLines, createWriteStream('lines.txt'));
```

### Object Mode Streams

```js
const filter = new Transform({
  objectMode: true,
  transform(obj, _enc, cb) {
    if (obj.age > 25) cb(null, obj);
    else cb();  // skip
  },
});

const toJson = new Transform({
  objectMode: true,
  writableObjectMode: true,
  transform(obj, _enc, cb) {
    cb(null, JSON.stringify(obj) + '\n');
  },
});
```

---

## Key Package Summary

| Purpose | Package | Notes |
|---|---|---|
| Glob patterns | `fast-glob`, `globby` | Node 22+ has built-in `fs/promises.glob` |
| CSV | `csv-parse`, `csv-stringify` | Streaming, robust |
| YAML | `js-yaml` | Standard YAML parser |
| Streaming JSON | `stream-json` | Process huge JSON files |
| HTTP advanced | `undici` | Connection pooling, built into Node |
| Concurrency | `p-limit`, `p-queue` | Precise concurrency control |
| SQLite (24+) | `node:sqlite` | Built-in, no install |
