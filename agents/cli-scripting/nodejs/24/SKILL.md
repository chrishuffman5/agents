---
name: cli-nodejs-24
description: "Node.js 24 (Current) version-specific expertise. node:sqlite built-in stable, require() ESM stable, URLPattern built-in, V8 13.6 (RegExp.escape, Float16Array), npm 11, improved fetch streaming, improved permission model. WHEN: \"Node 24\", \"Node.js 24\", \"node:sqlite\", \"DatabaseSync\", \"URLPattern\", \"RegExp.escape\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Node.js 24 (Current) Version Expert

Node 24 Current. Released May 2025. Will become LTS October 2025, EOL April 2028.

## Key Features

| Feature | Status |
|---|---|
| `require()` for ES modules | **Stable** (no longer experimental) |
| `URLPattern` built-in | Added |
| V8 13.6 (`RegExp.escape()`, `Float16Array`) | Included |
| `node:sqlite` built-in SQLite | **Stable** |
| `node:test` full coverage reporting | Improved |
| npm 11 bundled | Updated |
| `fetch` streaming improvements | Improved |
| Permission model | Improved stability |

## node:sqlite -- Built-in SQLite

No need for `better-sqlite3` or `sql.js` for simple use cases. Synchronous API.

```js
import { DatabaseSync } from 'node:sqlite';

// In-memory database
const db = new DatabaseSync(':memory:');

// Create table
db.exec(`
  CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    created_at TEXT DEFAULT (datetime('now'))
  )
`);

// Insert with prepared statement
const insert = db.prepare('INSERT INTO users (name, email) VALUES (?, ?)');
insert.run('Alice', 'alice@example.com');
insert.run('Bob', 'bob@example.com');
insert.run('Carol', 'carol@example.com');

// Query all rows
const all = db.prepare('SELECT * FROM users').all();
console.log(all);
// [{ id: 1, name: 'Alice', ... }, { id: 2, name: 'Bob', ... }, ...]

// Query single row
const alice = db.prepare('SELECT * FROM users WHERE name = ?').get('Alice');
console.log(alice); // { id: 1, name: 'Alice', email: 'alice@example.com', ... }

// Named parameters
const byEmail = db.prepare('SELECT * FROM users WHERE email = $email');
const user = byEmail.get({ $email: 'bob@example.com' });

// Update and get changes count
const update = db.prepare('UPDATE users SET name = ? WHERE id = ?');
const info = update.run('Robert', 2);
console.log(info.changes); // 1

// Delete
db.prepare('DELETE FROM users WHERE id = ?').run(3);

// Transaction (manual)
db.exec('BEGIN');
try {
  insert.run('Dave', 'dave@example.com');
  insert.run('Eve', 'eve@example.com');
  db.exec('COMMIT');
} catch (err) {
  db.exec('ROLLBACK');
  throw err;
}

// File-based database
const fileDb = new DatabaseSync('/path/to/database.sqlite');
fileDb.exec('CREATE TABLE IF NOT EXISTS config (key TEXT PRIMARY KEY, value TEXT)');
fileDb.prepare('INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)').run('version', '1.0.0');
fileDb.close();
```

### CLI Tool with SQLite Storage

```js
#!/usr/bin/env node
import { DatabaseSync } from 'node:sqlite';
import { parseArgs } from 'node:util';
import path from 'node:path';
import os from 'node:os';

const DB_PATH = path.join(os.homedir(), '.mytool', 'data.sqlite');

const db = new DatabaseSync(DB_PATH);
db.exec(`CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY, title TEXT, done INTEGER DEFAULT 0
)`);

const { values, positionals } = parseArgs({
  args: process.argv.slice(2),
  options: { done: { type: 'boolean', short: 'd' } },
  allowPositionals: true,
});

const [cmd, ...rest] = positionals;

if (cmd === 'add') {
  db.prepare('INSERT INTO tasks (title) VALUES (?)').run(rest.join(' '));
  console.log('Task added.');
} else if (cmd === 'list') {
  const tasks = db.prepare('SELECT * FROM tasks ORDER BY id').all();
  tasks.forEach(t => console.log(`  ${t.done ? '[x]' : '[ ]'} ${t.id}: ${t.title}`));
} else if (cmd === 'done') {
  db.prepare('UPDATE tasks SET done = 1 WHERE id = ?').run(Number(rest[0]));
  console.log('Marked done.');
} else {
  console.log('Usage: mytool <add|list|done> [args]');
}

db.close();
```

## require() ESM -- Now Stable

```js
// In a CJS file — no flag or warning needed in Node 24:
const { helper } = require('./esm-module.mjs');
const chalk = require('chalk');  // ESM-only packages now work in CJS

// This enables full interop between CJS and ESM codebases
// No more "ERR_REQUIRE_ESM" errors for most packages
```

## URLPattern

```js
// Built-in URLPattern (previously web-only)
const pattern = new URLPattern({ pathname: '/users/:id' });
const match = pattern.exec('https://example.com/users/42');
console.log(match.pathname.groups.id); // '42'

const apiPattern = new URLPattern({ pathname: '/api/:version/:resource' });
const result = apiPattern.exec('https://api.example.com/api/v2/orders');
console.log(result.pathname.groups); // { version: 'v2', resource: 'orders' }
```

## V8 13.6 Highlights

```js
// RegExp.escape() — safely escape user input for RegExp
const userInput = 'hello.world?';
const safe = new RegExp(RegExp.escape(userInput)); // escapes . and ?
console.log(safe.test('hello.world?')); // true
console.log(safe.test('helloXworldX')); // false

// Float16Array — half-precision floating point
const f16 = new Float16Array([1.5, 2.5, 3.5]);
console.log(f16); // Float16Array [1.5, 2.5, 3.5]
```

## npm 11

- Faster install times
- Improved lockfile resolution
- Better workspace support
- Stricter peer dependency enforcement by default

## Migration Notes

When migrating from Node 22 to Node 24:
- `require()` ESM is now stable -- remove `--experimental-require-module` flag
- `node:sqlite` is stable -- evaluate replacing `better-sqlite3` for simple use cases
- `URLPattern` is available -- can replace path-matching regex
- `RegExp.escape()` is available -- replace manual escaping helpers
- npm 11 may require updating peer dependency declarations
