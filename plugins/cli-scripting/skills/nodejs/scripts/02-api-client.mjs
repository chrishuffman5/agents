#!/usr/bin/env node
// ============================================================================
// Node.js - Fetch-Based API Client
//
// Purpose : Demonstrate retry with exponential back-off, pagination via async
//           generators, streaming downloads, and concurrent requests.
// Version : 1.0.0
// Targets : Node.js 20+ (uses built-in fetch)
// Safety  : Read-only against public test APIs. No destructive operations.
//
// Usage:
//   node 02-api-client.mjs [--endpoint URL] [--output file.json] [--timeout ms]
//
// Sections:
//   1. Retry with Exponential Back-off
//   2. Paginated Fetch (Async Generator)
//   3. Streaming Download
//   4. Concurrent Requests with Limit
//   5. POST Example
// ============================================================================
import fs from 'node:fs/promises';
import { createWriteStream } from 'node:fs';
import { pipeline } from 'node:stream/promises';
import { Transform } from 'node:stream';
import { parseArgs } from 'node:util';

const { values } = parseArgs({
  args: process.argv.slice(2),
  options: {
    endpoint: { type: 'string', default: 'https://jsonplaceholder.typicode.com' },
    output:   { type: 'string', short: 'o' },
    timeout:  { type: 'string', default: '10000' },
  },
});

const BASE_URL = values.endpoint;
const TIMEOUT  = Number(values.timeout);

// -- Section 1: Retry with Exponential Back-off ------------------------------
async function fetchWithRetry(url, options = {}, maxRetries = 3) {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    const ac    = new AbortController();
    const timer = setTimeout(() => ac.abort(new Error(`Timeout after ${TIMEOUT}ms`)), TIMEOUT);
    try {
      const res = await fetch(url, { ...options, signal: ac.signal });
      clearTimeout(timer);

      if (res.status === 429) {
        const retryAfter = Number(res.headers.get('retry-after') ?? 1) * 1000;
        const delay = Math.max(retryAfter, 1000 * 2 ** attempt);
        console.error(`Rate limited. Waiting ${delay}ms...`);
        await new Promise(r => setTimeout(r, delay));
        continue;
      }
      if (res.status >= 500 && attempt < maxRetries) {
        await new Promise(r => setTimeout(r, 1000 * 2 ** attempt + Math.random() * 100));
        continue;
      }
      return res;
    } catch (err) {
      clearTimeout(timer);
      if (attempt === maxRetries || err.name === 'AbortError') throw err;
      await new Promise(r => setTimeout(r, 1000 * 2 ** attempt));
    }
  }
}

// -- Section 2: Pagination via Async Generator --------------------------------
async function* paginateUsers(baseUrl) {
  let page = 1;
  while (true) {
    const res = await fetchWithRetry(`${baseUrl}/users?_page=${page}&_limit=3`);
    if (!res.ok) throw new Error(`HTTP ${res.status} at page ${page}`);
    const data = await res.json();
    if (!data.length) break;
    yield* data;
    page++;
    if (page > 3) break; // demo limit
  }
}

// -- Section 3: Streaming Download --------------------------------------------
async function streamDownload(url, destPath) {
  console.log(`Streaming ${url} -> ${destPath}`);
  const res = await fetchWithRetry(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const totalBytes = Number(res.headers.get('content-length') ?? 0);
  let received = 0;

  const counting = new Transform({
    transform(chunk, _enc, cb) {
      received += chunk.length;
      if (totalBytes) process.stdout.write(`\r  ${received}/${totalBytes} bytes`);
      cb(null, chunk);
    },
    flush(cb) { process.stdout.write('\n'); cb(); },
  });

  await pipeline(res.body, counting, createWriteStream(destPath));
  console.log(`  Saved ${received} bytes`);
}

// -- Section 4: Concurrent Requests with Limit --------------------------------
async function fetchPostsForUsers(userIds, concurrency = 3) {
  const results = [];
  for (let i = 0; i < userIds.length; i += concurrency) {
    const batch = userIds.slice(i, i + concurrency);
    const batchResults = await Promise.all(
      batch.map(async (id) => {
        const res = await fetchWithRetry(`${BASE_URL}/posts?userId=${id}`);
        return { userId: id, posts: await res.json() };
      })
    );
    results.push(...batchResults);
  }
  return results;
}

// -- Section 5: Main ----------------------------------------------------------
console.log(`\nAPI Client Demo - ${BASE_URL}\n${'='.repeat(40)}`);

// 1. Paginated fetch
console.log('\n[1] Paginated users:');
const userIds = [];
for await (const user of paginateUsers(BASE_URL)) {
  console.log(`  ${user.id}: ${user.name} <${user.email}>`);
  userIds.push(user.id);
}

// 2. Concurrent post fetching
console.log('\n[2] Fetching posts concurrently (3 at a time):');
const postData = await fetchPostsForUsers(userIds.slice(0, 6));
postData.forEach(({ userId, posts }) =>
  console.log(`  User ${userId}: ${posts.length} posts`)
);

// 3. Stream download
if (values.output) {
  console.log('\n[3] Stream download:');
  await streamDownload(`${BASE_URL}/todos`, values.output);
}

// 4. POST example
console.log('\n[4] POST example:');
const newPost = {
  title:  'Hello from Node.js',
  body:   'Created by the API client demo.',
  userId: 1,
};
const createRes = await fetchWithRetry(`${BASE_URL}/posts`, {
  method:  'POST',
  headers: { 'Content-Type': 'application/json' },
  body:    JSON.stringify(newPost),
});
const created = await createRes.json();
console.log(`  Created post ID: ${created.id}`);

console.log('\nDone.\n');
