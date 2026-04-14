---
name: cli-nodejs-20
description: "Node.js 20 LTS version-specific expertise. Stable test runner (node --test), stable fetch API, permission model (experimental), Single Executable Applications (SEA), watch mode, V8 11.3, Array.fromAsync(). WHEN: \"Node 20\", \"Node.js 20\", \"node --test\", \"permission model\", \"--allow-fs-read\", \"SEA\", \"Single Executable\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Node.js 20 LTS Version Expert

Node 20 LTS (codename Iron). Released April 2023, EOL April 2026. This is the widest-deployed LTS version.

## Key Features

| Feature | Status |
|---|---|
| `node:test` built-in test runner | **Stable** |
| `fetch` / `Request` / `Response` | **Stable** |
| Permission model (`--allow-fs-read`, etc.) | Experimental |
| Single Executable Applications (SEA) | Experimental |
| `--watch` mode | **Stable** |
| `import.meta.resolve()` | Stable |
| V8 11.3, `Array.fromAsync()` | Included |

## Built-in Test Runner (node:test)

```js
import { test, describe, it, before, after, mock } from 'node:test';
import assert from 'node:assert/strict';

// Simple test
test('addition works', () => {
  assert.strictEqual(1 + 1, 2);
});

// Async test
test('fetch returns data', async () => {
  const res = await fetch('https://jsonplaceholder.typicode.com/todos/1');
  assert.ok(res.ok);
  const data = await res.json();
  assert.equal(data.id, 1);
});

// Test suite with describe/it
describe('Array', () => {
  it('should support map', () => {
    assert.deepStrictEqual([1, 2, 3].map(x => x * 2), [2, 4, 6]);
  });

  it('should support filter', () => {
    assert.deepStrictEqual([1, 2, 3, 4].filter(x => x > 2), [3, 4]);
  });
});

// Mocking
test('mocked function', () => {
  const fn = mock.fn(() => 42);
  assert.equal(fn(), 42);
  assert.equal(fn.mock.calls.length, 1);
});
```

```bash
# Run tests
node --test                              # find and run **/*.test.{js,mjs}
node --test src/                         # test files in directory
node --test --watch                      # watch mode
node --test --test-reporter=spec         # spec reporter
node --test --test-reporter=tap          # TAP output
node --test --test-concurrency=4         # parallel
```

## Permission Model

```bash
# Sandbox: restrict file system, network, child_process
node --experimental-permission --allow-fs-read=/data --allow-fs-write=/tmp script.mjs
node --experimental-permission --allow-child-process --allow-net script.mjs

# No flags = deny all (when --experimental-permission is set)
node --experimental-permission script.mjs  # all restricted
```

Permission flags: `--allow-fs-read`, `--allow-fs-write`, `--allow-child-process`, `--allow-worker`, `--allow-net`.

## Watch Mode

```bash
node --watch server.mjs              # restart on file changes
node --watch-path=./src server.mjs   # watch specific directory
node --watch --test                   # rerun tests on changes
```

## Stable fetch API

`fetch`, `Request`, `Response`, `Headers`, `FormData` are all globally available without import.

```js
const res = await fetch('https://api.example.com/data');
const data = await res.json();
```

## Single Executable Applications (SEA)

```bash
# 1. Create SEA config
echo '{"main":"app.js","output":"sea-prep.blob"}' > sea-config.json

# 2. Generate the blob
node --experimental-sea-config sea-config.json

# 3. Copy node binary and inject
cp $(which node) my-app
npx postject my-app NODE_SEA_BLOB sea-prep.blob --sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2

# 4. Run standalone
./my-app
```

## V8 11.3 Highlights

- `Array.fromAsync()` -- async version of `Array.from()`
- `ArrayBuffer.prototype.transfer()` -- zero-copy transfer
- String `.isWellFormed()` and `.toWellFormed()` -- Unicode validation

## Migration Notes

When migrating from Node 18 to Node 20:
- `fetch` moves from experimental to stable
- `node:test` moves from experimental to stable
- `--watch` moves from experimental to stable
- `import.meta.resolve()` becomes synchronous
- Default OpenSSL updated to 3.0.x
