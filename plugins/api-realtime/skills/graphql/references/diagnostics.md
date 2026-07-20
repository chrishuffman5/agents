# GraphQL Diagnostics

## N+1 Query Detection

### Symptoms

- Slow GraphQL queries that return nested data
- Database query count scales linearly with list size
- High database connection pool usage during list queries

### Diagnostic Steps

1. Enable query logging on the database to count queries per GraphQL request
2. Check resolvers for direct database calls without DataLoader
3. Look for list fields that resolve related objects individually
4. Monitor resolver execution time via Apollo tracing or custom plugins

### Common Patterns

```js
// BAD: N+1
Post: { author: (post) => db.users.findById(post.authorId) }

// GOOD: DataLoader batching
Post: { author: (post, _, ctx) => ctx.loaders.users.load(post.authorId) }
```

### DataLoader Debugging

- **Wrong batch function return order**: batch must return results in same order as input keys. Mismatch causes all loads in batch to fail.
- **Shared DataLoader across requests**: causes stale data. Create new loaders per request in context function.
- **Missing null for absent records**: if a key has no result, return `null` at that position, not `undefined` or omission.

## Validation Errors

### Common Error Messages

```
Cannot query field "nonExistentField" on type "User".
```
**Fix:** Field does not exist on the type. Check spelling and schema.

```
Variable "$id" of required type "ID!" was not provided.
```
**Fix:** Pass the required variable in the variables object.

```
Fragment "UserFragment" is never used.
```
**Fix:** Remove unused fragments or spread them in a selection set.

```
Unknown argument "foo" on field "Query.user".
```
**Fix:** Check argument name against schema. Arguments are case-sensitive.

```
Variable "$status" of type "String" used in position expecting type "PostStatus".
```
**Fix:** Variable type must match argument type. Use the enum type, not String.

## Null Propagation Issues

### Symptoms

- Entire response sections return null unexpectedly
- `errors` array shows null for a non-null field

### How Null Propagation Works

If a non-null field (`!`) returns null, the null propagates up to the nearest nullable parent:

```graphql
type Query {
  user(id: ID!): User  # nullable - stops propagation here
}
type User {
  id: ID!
  name: String!  # non-null - if null, propagates to parent
  email: String  # nullable - null stays here
}
```

If `name` resolver returns null, the entire `user` field becomes null.

### Debugging

1. Check the `errors` array in the response for the specific field that failed
2. Look at the `path` in the error to identify which field caused null propagation
3. Review the resolver for the failing field -- is it returning null unexpectedly?
4. Consider making the field nullable if null is a valid business case

### Prevention

- Only mark fields non-null when the server can guarantee a value
- Use nullable fields for data from external services (may fail)
- Default resolvers return `parent[fieldName]` -- check parent object has the property

## Cache Issues

### Apollo Client Cache Not Updating After Mutation

**Symptom:** Mutation succeeds but UI does not reflect the change.

**Diagnostic steps:**
1. Check that the mutation response includes `__typename` and `id` for affected objects
2. Verify `keyFields` in `typePolicies` match the fields returned
3. Check fetch policy -- `cache-first` may serve stale data
4. For list additions, use `update` or `refetchQueries`

**Solutions:**
```js
// Refetch affected queries
const [createPost] = useMutation(CREATE_POST, {
  refetchQueries: [{ query: GET_POSTS }],
});

// Manual cache update
const [createPost] = useMutation(CREATE_POST, {
  update(cache, { data: { createPost } }) {
    cache.modify({
      fields: {
        posts(existing = []) { return [...existing, cache.writeFragment({ data: createPost, fragment: POST_FRAGMENT })]; },
      },
    });
  },
});
```

### Stale Data After Navigation

**Fix:** Use `cache-and-network` fetch policy for queries where freshness matters:
```js
const { data } = useQuery(GET_USER, { fetchPolicy: 'cache-and-network' });
```

### Cache Key Conflicts

**Symptom:** Objects of different types overwrite each other in cache.

**Fix:** Ensure unique `keyFields` per type. For types without `id`, configure custom key fields:
```js
typePolicies: { Product: { keyFields: ['sku'] } }
```

## Subscription Issues

### Subscription Not Receiving Events

**Diagnostic steps:**
1. Verify WebSocket connection is established (check browser DevTools WS tab)
2. Check that the subscription resolver's `subscribe` function returns an async iterator
3. Verify the pub/sub system is publishing events with matching topic names
4. Check that the filter function (if any) matches the subscription variables

### Subscription Connection Drops

**Common causes:**
- WebSocket timeout: configure server keep-alive (ping/pong)
- Load balancer terminating idle connections: increase timeout or enable WebSocket ping
- Authentication token expiry: implement token refresh for long-lived subscriptions

### Transport Mismatch

GraphQL subscriptions can use two transports:
- `graphql-ws` protocol (newer, recommended)
- `subscriptions-transport-ws` (legacy, deprecated)

Client and server must agree on the same protocol. Apollo Server 4+ uses `graphql-ws` by default.

## Federation Composition Errors

### "Type X has no fields"

**Fix:** The type has `@key` but no fields. Add at least the key field and one additional field.

### "Entity type X requires __resolveReference"

**Fix:** Add `__resolveReference` to the type's resolvers:
```js
User: { __resolveReference: (ref, ctx) => ctx.loaders.users.load(ref.id) }
```

### Schema Check Breaking Changes

```bash
rover subgraph check my-graph@current --schema ./new-schema.graphql --name users
```

Common breaking changes detected:
- Removed field that clients are using
- Changed field type
- Removed type from union
- Changed argument from optional to required

## Performance Diagnostics

### Slow Queries

**Diagnostic steps:**
1. Enable Apollo tracing to see per-resolver timing
2. Identify the slowest resolver in the trace
3. Check for missing DataLoader (N+1 pattern)
4. Check for unbounded list queries (no pagination limits)
5. Profile the database query being executed

### Query Complexity Issues

**Symptom:** Server becomes unresponsive during certain queries.

**Diagnostic:**
```js
const myPlugin = {
  async requestDidStart(ctx) {
    console.log('Query:', ctx.request.query);
    console.log('Variables:', ctx.request.variables);
  },
};
```

**Fix:** Add depth limiting and complexity analysis:
```js
import depthLimit from 'graphql-depth-limit';
new ApolloServer({ validationRules: [depthLimit(10)] });
```

### Memory Leaks

**Symptom:** Server memory grows unboundedly over time.

**Common causes:**
- DataLoader instances not being garbage collected (shared across requests)
- In-memory subscription pub/sub not cleaning up disconnected subscribers
- Apollo Server plugin holding references to resolved data

**Fix:** Ensure DataLoader is per-request (created in context function, not globally).

## Common Error Patterns

| Error | Cause | Fix |
|---|---|---|
| `GRAPHQL_PARSE_FAILED` | Invalid query syntax | Check query string for typos, missing braces |
| `GRAPHQL_VALIDATION_FAILED` | Query does not match schema | Check field names, argument types, fragment types |
| `BAD_USER_INPUT` | Invalid variable values | Validate variables match expected types |
| `PERSISTED_QUERY_NOT_FOUND` | APQ hash not registered | Client should resend full query with hash |
| `UNAUTHENTICATED` | Missing or invalid auth token | Check Authorization header, token expiry |
| `INTERNAL_SERVER_ERROR` | Unhandled resolver exception | Check server logs, add error handling in resolver |
