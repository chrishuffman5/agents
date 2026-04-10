---
name: cli-nodejs-22
description: "Node.js 22 LTS version-specific expertise. require() for ESM (experimental), built-in WebSocket client, built-in glob in node:fs, snapshot testing in node:test, util.parseEnv(), V8 12.4, Promise.withResolvers(). WHEN: \"Node 22\", \"Node.js 22\", \"require ESM\", \"built-in WebSocket\", \"node:fs glob\", \"snapshot testing\", \"parseEnv\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Node.js 22 LTS Version Expert

Node 22 LTS (codename Jod). Released April 2024, EOL April 2027. Second-latest LTS.

## Key Features

| Feature | Status |
|---|---|
| `require()` for ES modules | Experimental (no flag needed from 22.12+) |
| WebSocket client built-in | **Stable** |
| `glob` / `globSync` in `node:fs` | **Stable** |
| `--watch` mode improvements | **Stable** |
| `node:test` snapshot testing | Added |
| V8 12.4, `Promise.withResolvers()` | Included |
| `util.parseEnv()` | Added |

## Built-in WebSocket Client

No need to install the `ws` package for basic WebSocket usage.

```js
// Built-in WebSocket (no import needed, global)
const socket = new WebSocket('wss://echo.websocket.org');

socket.addEventListener('open', () => {
  console.log('Connected');
  socket.send('Hello from Node 22!');
});

socket.addEventListener('message', (event) => {
  console.log('Received:', event.data);
  socket.close();
});

socket.addEventListener('close', () => {
  console.log('Disconnected');
});

socket.addEventListener('error', (event) => {
  console.error('WebSocket error:', event);
});
```

## Built-in Glob (node:fs)

```js
import { glob, globSync } from 'node:fs/promises';

// Async glob (returns AsyncIterable)
const jsFiles = await Array.fromAsync(glob('**/*.js'));
console.log(jsFiles);

// With options
const tsFiles = await Array.fromAsync(glob('**/*.ts', {
  cwd: '/project/src',
  exclude: (name) => name.includes('node_modules'),
}));

// For-await iteration (memory efficient for large trees)
for await (const file of glob('**/*.json', { cwd: '/data' })) {
  console.log(file);
}

// Sync version (for startup/config loading)
import { globSync as globSyncFs } from 'node:fs';
const configs = globSyncFs('*.config.{js,ts,json}');
```

## require() for ESM (Experimental)

CJS code can now `require()` ES modules that meet certain constraints (no top-level await, synchronous).

```js
// In a CJS file (no flag needed from Node 22.12+):
const { helper } = require('./esm-module.mjs');

// Restrictions:
// - The ESM module must not use top-level await
// - Works for most pure-function ESM libraries
// - Enables gradual ESM migration
```

## Snapshot Testing (node:test)

```js
import { test } from 'node:test';

test('snapshot test', (t) => {
  const result = generateReport();
  // First run: creates snapshot. Subsequent runs: compares.
  t.assert.snapshot(result);
});

test('named snapshot', (t) => {
  t.assert.snapshot(JSON.stringify(data, null, 2), 'report-data');
});
```

```bash
# Update snapshots
node --test --test-update-snapshots
```

## util.parseEnv()

```js
import { parseEnv } from 'node:util';

const envContent = `
DB_HOST=localhost
DB_PORT=5432
# This is a comment
SECRET="my secret value"
`;

const parsed = parseEnv(envContent);
// { DB_HOST: 'localhost', DB_PORT: '5432', SECRET: 'my secret value' }
```

## V8 12.4 Highlights

- `Promise.withResolvers()` -- returns `{ promise, resolve, reject }` in one call
- `Object.groupBy()` / `Map.groupBy()` -- native grouping
- `ArrayBuffer.prototype.transfer()` stable

```js
// Promise.withResolvers
const { promise, resolve, reject } = Promise.withResolvers();
setTimeout(() => resolve('done'), 1000);
const result = await promise;

// Object.groupBy
const people = [{ name: 'Alice', dept: 'eng' }, { name: 'Bob', dept: 'sales' }];
const byDept = Object.groupBy(people, p => p.dept);
// { eng: [{ name: 'Alice', ... }], sales: [{ name: 'Bob', ... }] }
```

## Migration Notes

When migrating from Node 20 to Node 22:
- Built-in `glob` eliminates need for `fast-glob`/`globby` in many cases
- Built-in `WebSocket` eliminates need for `ws` package (basic usage)
- `require()` ESM support enables gradual migration of CJS codebases
- `parseEnv()` can replace `dotenv` for simple .env parsing
- Snapshot testing reduces need for external snapshot libraries
