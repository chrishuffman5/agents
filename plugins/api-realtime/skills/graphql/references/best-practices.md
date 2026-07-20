# GraphQL Best Practices

## DataLoader Pattern

### The N+1 Problem

When a list resolver returns N items and each item's field triggers an individual database query:
```js
// Naive — N+1 queries
const resolvers = { Post: { author: (post) => db.users.findById(post.authorId) } };
```

### DataLoader Solution

DataLoader batches multiple `.load(key)` calls within a single event loop tick:
```js
const DataLoader = require('dataloader');

function createLoaders(db) {
  return {
    users: new DataLoader(async (ids) => {
      const users = await db.users.findByIds(ids);
      return ids.map(id => users.find(u => u.id === id) || null);
    }),
  };
}
```

### DataLoader Rules

- Batch function receives array of keys, must return array of same length in same order
- Missing records must return `null` (not omit) -- mismatch fails entire batch
- Cache is per-DataLoader instance (per-request scoped)
- Never share DataLoader across requests -- stale data and security risks

### Per-Request Pattern

```js
const server = new ApolloServer({
  typeDefs, resolvers,
  context: ({ req }) => ({
    db,
    loaders: createLoaders(db),
    user: verifyToken(req.headers.authorization),
  }),
});
```

### DataLoader Options

```js
new DataLoader(batchFn, {
  cache: true,        // default; set false for write-heavy scenarios
  maxBatchSize: 100,  // limit batch size
});
```

## Caching

### Automatic Persisted Queries (APQ)

Client sends hash first; server returns `PersistedQueryNotFound` if unknown; client resends full query with hash; server stores mapping.

```json
{"extensions": {"persistedQuery": {"version": 1, "sha256Hash": "abc123..."}}}
```

Benefits: reduced request payload; subsequent requests use hash via GET (CDN-cacheable).

### Persisted Query Lists (PQL)

Pre-registered allowlist of operations. Only registered operations execute. Provides security (no ad-hoc injection) plus performance.

### Apollo Client Normalized Cache

Objects stored by `__typename:id`. Queries read from cache by following references:

```js
const client = new ApolloClient({
  cache: new InMemoryCache({
    typePolicies: {
      User: { keyFields: ['id'] },
      Post: { keyFields: ['id', 'version'] },
    },
  }),
});
```

### Fetch Policies

- `cache-first` (default): serve from cache, fetch on miss
- `cache-and-network`: serve cache immediately, also fetch to update
- `network-only`: always fetch, write to cache
- `no-cache`: always fetch, do not write to cache
- `cache-only`: never fetch, throw on miss

### Optimistic UI

```js
const [updateUser] = useMutation(UPDATE_USER, {
  optimisticResponse: { updateUser: { __typename: 'User', id: userId, name: newName } },
});
```

## Federation Best Practices

### Subgraph Ownership

Each entity type should have one owning subgraph that defines `@key`. Other subgraphs extend it with `@external` and `@requires`.

### Schema Checks in CI

```bash
rover subgraph check my-graph@current --schema ./schema.graphql --name users
```

Detects breaking changes before deployment. Run on every PR.

### Entity Resolution Performance

Keep `__resolveReference` lightweight. If it requires multiple DB queries, use DataLoader:
```js
User: {
  __resolveReference(ref, ctx) { return ctx.loaders.users.load(ref.id); },
}
```

### Composition Configuration

```yaml
federation_version: =2.3.0
subgraphs:
  users:
    routing_url: http://users-service/graphql
    schema:
      file: ./users.graphql
```

## Security Hardening

### Disable Introspection in Production

```js
new ApolloServer({ introspection: process.env.NODE_ENV !== 'production' });
```

### Query Depth Limiting

```js
import depthLimit from 'graphql-depth-limit';
const server = new ApolloServer({ validationRules: [depthLimit(10)] });
```

### Query Complexity Analysis

Assign cost to each field. Reject queries exceeding threshold:
```js
import { createComplexityLimitRule } from 'graphql-validation-complexity';
const rule = createComplexityLimitRule(1000);
```

### Input Validation

Validate arguments in resolvers. Use custom scalars for type enforcement (`EmailAddress`, `NonNegativeInt`).

### Rate Limiting

Request count alone is insufficient for GraphQL. Use complexity-based rate limiting: parse query, calculate complexity score per field, reject above threshold.

## Error Handling

### Error Response Format

```json
{
  "data": {"user": null},
  "errors": [{
    "message": "User not found",
    "locations": [{"line": 2, "column": 3}],
    "path": ["user"],
    "extensions": {"code": "USER_NOT_FOUND", "status": 404}
  }]
}
```

### Error Classification with extensions.code

Use `extensions.code` for machine-readable error types: `BAD_USER_INPUT`, `UNAUTHENTICATED`, `FORBIDDEN`, `NOT_FOUND`, `INTERNAL_SERVER_ERROR`.

### Partial Data Return

GraphQL can return both `data` and `errors` simultaneously. A failed field returns null while other fields succeed. Design schemas to handle this gracefully.

### Never Expose Internal Errors

```js
const server = new ApolloServer({
  formatError: (err) => {
    if (err.extensions?.code === 'INTERNAL_SERVER_ERROR') {
      return { message: 'Internal server error', extensions: { code: 'INTERNAL_SERVER_ERROR' } };
    }
    return err;
  },
});
```

## Schema Evolution

### Non-Breaking Changes

- Adding fields, types, enum values
- Making required arguments optional
- Adding optional arguments

### Breaking Changes (Avoid or Deprecate)

- Removing fields: use `@deprecated(reason: "Use newField instead")` for 90-180 days
- Changing field types
- Changing argument types
- Making optional arguments required

### Deprecation Tracking

Monitor deprecated field usage:
```js
const myPlugin = {
  async requestDidStart() {
    return {
      async executionDidStart() {
        return { willResolveField({ info }) {
          if (info.parentType.getFields()[info.fieldName]?.deprecationReason) {
            trackDeprecatedUsage(info.parentType.name, info.fieldName);
          }
        }};
      },
    };
  },
};
```

## Performance Tuning

### JIT Compilation (Mercurius)

```js
fastify.register(mercurius, { jit: 1 }); // enable after 1st request
```

10-30x improvement in execution speed for hot paths.

### Response Caching

```js
import responseCachePlugin from '@apollo/server-plugin-response-cache';
const server = new ApolloServer({ plugins: [responseCachePlugin()] });
```

### Field-Level Cache Hints

```graphql
type User @cacheControl(maxAge: 3600) {
  id: ID!
  name: String! @cacheControl(maxAge: 86400)
  email: String! @cacheControl(maxAge: 0)
}
```

### Batched Queries

Apollo Client supports query batching -- multiple queries in one HTTP request. Reduces connection overhead but increases response latency (waits for slowest query).

### Projection and Filtering (Hot Chocolate)

```csharp
[UseProjection]
[UseFiltering]
[UseSorting]
public IQueryable<Post> GetPosts([Service] AppDbContext db) => db.Posts;
```

Translates GraphQL queries to efficient SQL (only selects requested columns).
