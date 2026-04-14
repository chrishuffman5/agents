# GraphQL Comprehensive Research Document

**Prepared for:** Writer Agent — Technology Skill Files  
**Date:** 2026-04-13  
**Scope:** GraphQL architecture, ecosystem, features, best practices, diagnostics, and version-specific details

---

## 1. GraphQL Specification Versions

### Spec History Timeline
- **June 2018** — First ratified release by the GraphQL Foundation; 35+ contributors, ~100 changes. Established error handling rule: additional data on errors must be in `extensions` field.
- **October 2021** — Current stable release. Comprehensive refinement: 30 contributors, 100+ changes. Added clearer null handling rules for variables and arguments, new capabilities for default values.
- **Draft (ongoing)** — Incremental delivery (`@defer`/`@stream`) at Stage 2; `@oneOf` input type proposal; client-controlled nullability.

### graphql-js Reference Implementation Versions
- `graphql` npm package tracks spec; v16.x implements October 2021 spec.
- v17 (in progress) targets Draft spec features.

### Spec URL
- Stable: `https://spec.graphql.org/October2021/`
- Draft: `https://spec.graphql.org/draft/`

---

## 2. Type System

### Six Named Type Kinds

#### Scalars
Built-in scalars: `Int`, `Float`, `String`, `Boolean`, `ID`.

Custom scalars must define serialization, parsing, and validation:
```graphql
scalar DateTime
scalar URL
scalar JSON
```

Server-side registration (graphql-js):
```js
const DateTimeScalar = new GraphQLScalarType({
  name: 'DateTime',
  description: 'ISO 8601 date-time string',
  serialize(value) { return value.toISOString(); },
  parseValue(value) { return new Date(value); },
  parseLiteral(ast) {
    if (ast.kind === Kind.STRING) return new Date(ast.value);
    return null;
  },
});
```

Community library: `graphql-scalars` provides 50+ production-ready scalars (EmailAddress, PhoneNumber, UUID, NonNegativeInt, etc.).

#### Object Types
```graphql
type User {
  id: ID!
  name: String!
  email: String!
  posts(first: Int, after: String): PostConnection!
  createdAt: DateTime!
}
```

Fields may have arguments. Arguments are typed and can have defaults:
```graphql
type Query {
  users(role: UserRole = MEMBER, limit: Int = 10): [User!]!
}
```

#### Interfaces
```graphql
interface Node {
  id: ID!
}

interface Timestamped {
  createdAt: DateTime!
  updatedAt: DateTime!
}

type Post implements Node & Timestamped {
  id: ID!
  title: String!
  createdAt: DateTime!
  updatedAt: DateTime!
}
```

Interfaces can implement other interfaces (added in October 2021 spec).

#### Unions
```graphql
union SearchResult = Post | User | Comment

type Query {
  search(query: String!): [SearchResult!]!
}
```

Unions cannot define shared fields; use interfaces for that. Fields on a union type require inline fragments:
```graphql
query Search($q: String!) {
  search(query: $q) {
    ... on User { id name }
    ... on Post { id title }
    ... on Comment { id body }
  }
}
```

#### Enums
```graphql
enum UserRole {
  ADMIN
  MODERATOR
  MEMBER
}

enum PostStatus {
  DRAFT
  PUBLISHED
  ARCHIVED
}
```

Enums are serialized as strings. Internal values can differ from external names in most implementations.

#### Input Types
Input types are exclusively for arguments and variables (write-only side):
```graphql
input CreatePostInput {
  title: String!
  body: String!
  tags: [String!]!
  status: PostStatus = DRAFT
}

type Mutation {
  createPost(input: CreatePostInput!): CreatePostPayload!
}
```

Input types cannot contain interfaces, unions, or output-only types. They can reference other input types. Circular input types are not allowed.

### Wrapping Types
- `[Type]` — nullable list of nullable items
- `[Type!]` — nullable list of non-null items
- `[Type]!` — non-null list of nullable items
- `[Type!]!` — non-null list of non-null items

### Type Modifiers for Arguments vs Fields
Non-null (`!`) on arguments means the field is required. Omitting a nullable argument means the default applies (or the value is `undefined` in JS resolvers).

---

## 3. Schema Design: Schema-First vs Code-First

### Schema-First (SDL-First)
Define schema in `.graphql` files, implement resolvers separately.

**Advantages:**
- SDL is the source of truth; readable by all stakeholders
- Better compatibility with federation and stitching tools
- Easier to share schema with frontend teams
- Third-party tooling (codegen, linting) works directly on SDL

**Disadvantages:**
- Risk of resolver-schema drift if not validated
- Code duplication between SDL and type definitions

**Tooling:** graphql-tools `makeExecutableSchema`, GraphQL Code Generator, eslint-plugin-graphql

```js
const { makeExecutableSchema } = require('@graphql-tools/schema');
const typeDefs = /* GraphQL */ `
  type Query { user(id: ID!): User }
  type User { id: ID! name: String! }
`;
const resolvers = {
  Query: { user: (_, { id }, ctx) => ctx.db.users.findById(id) }
};
const schema = makeExecutableSchema({ typeDefs, resolvers });
```

### Code-First
Programmatically build the schema; SDL is a derived artifact.

**Advantages:**
- Single source of truth in code
- Better IDE support (autocomplete, type checking)
- Easier to share logic between types
- Type safety by default (TypeScript)

**Disadvantages:**
- Schema is only visible at runtime
- Less readable for non-developers

**Libraries:**
- **TypeGraphQL** (TypeScript decorators)
- **Pothos** (TypeScript, plugin-based, type-safe)
- **Nexus** (TypeScript, functional API)
- **Strawberry** (Python, type hints)
- **Hot Chocolate** (.NET, attribute-based)

```ts
// Pothos example
const builder = new SchemaBuilder<{ Context: { db: DB } }>({});

builder.queryType({
  fields: (t) => ({
    user: t.field({
      type: UserRef,
      args: { id: t.arg.id({ required: true }) },
      resolve: (root, { id }, ctx) => ctx.db.users.findById(id),
    }),
  }),
});
```

### Hybrid Approach (Expedia/GraphQLConf 2024)
Schema-first design thinking with code-first implementation — define the SDL contract first, then implement with code-first tools. Increasingly popular for large organizations.

---

## 4. Execution Model

### Phases of Execution

#### Phase 1: Lexing / Tokenization
The query string is tokenized into the GraphQL token grammar: punctuators, names, integer values, float values, string values, block strings, comments.

#### Phase 2: Parsing (AST Generation)
Tokens are parsed into an Abstract Syntax Tree (AST). The AST nodes represent: Document, OperationDefinition, VariableDefinition, SelectionSet, Field, Argument, FragmentSpread, InlineFragment, FragmentDefinition, Value nodes (Variable, IntValue, FloatValue, StringValue, BooleanValue, NullValue, EnumValue, ListValue, ObjectValue), Directives.

```js
const { parse } = require('graphql');
const ast = parse(`query GetUser($id: ID!) { user(id: $id) { name } }`);
```

#### Phase 3: Validation
The AST is validated against the schema. Validation checks include:
- All fields exist on their parent types
- Arguments match the expected type signatures
- Variables are used consistently (type compatibility)
- Fragment spreads don't create cycles
- Required arguments are provided
- Unique operation names, variable names, fragment names

Validation errors are returned as request-level errors before any execution begins — no partial data is returned.

Common validation error messages:
```
Cannot query field "nonExistentField" on type "User".
Variable "$id" of required type "ID!" was not provided.
Fragment "UserFragment" is never used.
Unknown argument "foo" on field "Query.user".
```

#### Phase 4: Execution
- The executor traverses the selection set starting from the root type (Query/Mutation/Subscription).
- Each field is resolved by its resolver function.
- Resolvers execute concurrently for sibling fields (for queries).
- For mutations, root fields execute **serially** (in document order).
- List fields resolve each item; object fields recurse into sub-selections.
- Null propagation: if a non-null field returns null, the null propagates up to the nearest nullable parent.

#### Resolver Signature
```js
function resolver(parent, args, context, info) {
  // parent: the resolved value of the parent field
  // args: the arguments for this field
  // context: shared across all resolvers in a request
  // info: field name, path, schema, returnType, parentType, fragments, etc.
}
```

`info` object key properties:
- `info.fieldName` — current field name
- `info.path` — path from root to current field
- `info.returnType` — the GraphQL type of this field
- `info.schema` — the full schema object
- `info.fragments` — all named fragments in the document
- `info.operation` — the operation definition AST node

### Default Resolver
If no resolver is defined, the default resolver returns `parent[fieldName]` (property access). This handles the common case of mapping object properties.

### Subscription Execution
Subscriptions use an event source (pub/sub system). The execution model:
1. `subscribe()` is called instead of `execute()`.
2. Returns an async iterator.
3. Each event triggers a full `execute()` call on the operation.
4. Results are pushed to the client via the transport (WebSocket, SSE).

---

## 5. Operations: Queries, Mutations, Subscriptions

### Queries
```graphql
query GetUser($id: ID!, $postsFirst: Int = 10) {
  user(id: $id) {
    id
    name
    email
    posts(first: $postsFirst) {
      edges {
        node { id title }
        cursor
      }
      pageInfo { hasNextPage endCursor }
    }
  }
}
```

### Mutations
```graphql
mutation CreatePost($input: CreatePostInput!) {
  createPost(input: $input) {
    ... on Post {
      id
      title
      createdAt
    }
    ... on ValidationError {
      field
      message
    }
  }
}
```

Root mutation fields execute serially to avoid race conditions.

### Subscriptions
```graphql
subscription OnCommentAdded($postId: ID!) {
  commentAdded(postId: $postId) {
    id
    body
    author { name }
    createdAt
  }
}
```

### Fragments
Named fragments for reuse:
```graphql
fragment UserBasic on User {
  id
  name
  avatarUrl
}

query GetUsers {
  activeUsers { ...UserBasic }
  recentUsers { ...UserBasic }
}
```

Inline fragments for type conditions:
```graphql
query Feed {
  feed {
    ... on Post { id title body }
    ... on Video { id title duration }
    __typename
  }
}
```

### Variables
Variables are declared at the operation level and passed separately from the query string (never interpolated):
```json
{
  "query": "query GetUser($id: ID!) { user(id: $id) { name } }",
  "variables": { "id": "123" }
}
```

Variable types must be input types. Default values are specified in the declaration:
```graphql
query GetUsers($role: UserRole = MEMBER) { ... }
```

### Directives

Built-in executable directives:
- `@include(if: Boolean!)` — include field/fragment if true
- `@skip(if: Boolean!)` — skip field/fragment if true
- `@deprecated(reason: String)` — marks field or enum value as deprecated
- `@specifiedBy(url: String!)` — provides a URL for a custom scalar specification

Experimental/draft directives:
- `@defer(label: String, if: Boolean)` — defer fragment delivery
- `@stream(label: String, initialCount: Int, if: Boolean)` — stream list items

Custom directives (schema-level):
```graphql
directive @auth(requires: UserRole!) on FIELD_DEFINITION
directive @cacheControl(maxAge: Int, scope: CacheScope) on FIELD_DEFINITION | OBJECT | INTERFACE
```

### Introspection
```graphql
# Get all types
query { __schema { types { name kind description } } }

# Inspect a specific type
query { __type(name: "User") { fields { name type { name kind } } } }

# Get available queries
query { __schema { queryType { fields { name description } } } }
```

Introspection fields: `__schema`, `__type`, `__typename`.  
`__typename` is always available on any object type and returns the concrete type name (important for union/interface resolution on the client).

Security consideration: disable introspection in production unless required:
```js
// Apollo Server
new ApolloServer({
  introspection: process.env.NODE_ENV !== 'production',
});
```

---

## 6. DataLoader Pattern and the N+1 Problem

### The N+1 Problem
When a list resolver returns N items and each item's field triggers an individual database query:

```js
// Naive resolver — causes N+1
const resolvers = {
  Post: {
    author: (post) => db.users.findById(post.authorId), // called N times
  },
};
// Result: 1 query for posts + N queries for authors = N+1 queries
```

### DataLoader Solution
DataLoader batches multiple `.load(key)` calls that occur within a single event loop tick into one batched call:

```js
const DataLoader = require('dataloader');

// Create per-request (critical for correctness and security)
function createLoaders(db) {
  return {
    users: new DataLoader(async (ids) => {
      const users = await db.users.findByIds(ids);
      // Must return in same order as input keys
      return ids.map(id => users.find(u => u.id === id) || null);
    }),
    postsByAuthor: new DataLoader(async (authorIds) => {
      const posts = await db.posts.findByAuthorIds(authorIds);
      return authorIds.map(id => posts.filter(p => p.authorId === id));
    }),
  };
}

// In resolver
const resolvers = {
  Post: {
    author: (post, _, ctx) => ctx.loaders.users.load(post.authorId),
  },
};
```

### DataLoader Key Rules
- Batch function receives an array of keys, must return array of same length in same order.
- Missing records must return `null` (not omit) — a mismatch causes all loads in the batch to fail.
- Cache is per-DataLoader instance (scoped to the request).

### Per-Request DataLoader Pattern
```js
// Apollo Server context function
const server = new ApolloServer({
  typeDefs,
  resolvers,
  context: ({ req }) => ({
    db,
    loaders: createLoaders(db),
    user: verifyToken(req.headers.authorization),
  }),
});
```

Never share DataLoader instances across requests — cached stale data and security risks.

### DataLoader Options
```js
new DataLoader(batchFn, {
  cache: true,          // default true; set false for write-heavy scenarios
  maxBatchSize: 100,    // limit batch size
  batchScheduleFn: (cb) => setTimeout(cb, 10), // custom scheduling
});
```

### Breadth-First DataLoader (WunderGraph 2024)
A newer algorithm (DataLoader 3.0 concept) loads data breadth-first instead of depth-first, reducing concurrency from O(N²) to O(1) and improving performance by up to 5x for deeply nested queries.

---

## 7. Apollo Server (v4 and v5)

### Apollo Server 4 (EOL January 26, 2026)

Minimal standalone setup:
```js
import { ApolloServer } from '@apollo/server';
import { startStandaloneServer } from '@apollo/server/standalone';

const server = new ApolloServer({
  typeDefs,
  resolvers,
  introspection: true,
  plugins: [ApolloServerPluginLandingPageLocalDefault()],
});

const { url } = await startStandaloneServer(server, {
  context: async ({ req }) => ({
    token: req.headers.authorization,
    db,
    loaders: createLoaders(db),
  }),
  listen: { port: 4000 },
});
```

Express integration (v4):
```js
import { expressMiddleware } from '@apollo/server/express4';

const app = express();
await server.start();
app.use('/graphql', express.json(), expressMiddleware(server, {
  context: async ({ req }) => ({ ... }),
}));
```

### Apollo Server 5 (Current, 2025+)

Key changes from v4:
- **Node.js 20+** required.
- `startStandaloneServer` now built on Node's built-in HTTP server (no Express dependency).
- Built-in fetch (Node.js native) instead of `node-fetch`.
- `status400ForVariableCoercionErrors` defaults to `true` (breaking change from v4).
- `maxCoercionErrors` configurable.
- Compiled to ES2023 (requires modern runtime).
- Improved CSRF resistance (v5.5.0+ mitigates a known vulnerability).

Migration from v4 to v5 is typically a few minutes:
```bash
npm install @apollo/server@latest
```

### Apollo Server Plugins
```js
import { ApolloServerPluginDrainHttpServer } from '@apollo/server/plugin/drainHttpServer';
import { ApolloServerPluginInlineTrace } from '@apollo/server/plugin/inlineTrace';

const server = new ApolloServer({
  typeDefs,
  resolvers,
  plugins: [
    ApolloServerPluginDrainHttpServer({ httpServer }),
    ApolloServerPluginInlineTrace(), // for federation trace reporting
  ],
});
```

Custom plugin lifecycle hooks:
```js
const myPlugin = {
  async requestDidStart(requestContext) {
    return {
      async parsingDidStart() { /* ... */ },
      async validationDidStart() { /* ... */ },
      async executionDidStart() { /* ... */ },
      async willSendResponse(requestContext) { /* ... */ },
      async didEncounterErrors(requestContext) { /* ... */ },
    };
  },
};
```

---

## 8. Apollo Client and Normalized Cache

### InMemoryCache Architecture
Apollo Client stores data in a normalized, flat store. Each object is stored by a cache key (default: `__typename:id`). Queries read from the cache by following references.

```js
import { ApolloClient, InMemoryCache } from '@apollo/client';

const client = new ApolloClient({
  uri: 'https://api.example.com/graphql',
  cache: new InMemoryCache({
    typePolicies: {
      Query: {
        fields: {
          user: {
            // Merge strategy for paginated fields
            keyArgs: ['id'],
          },
        },
      },
      User: {
        keyFields: ['id'],    // Default key field
      },
      Post: {
        keyFields: ['id', 'version'], // Composite key
      },
    },
  }),
});
```

### Cache Operations
```js
// Direct cache write
client.cache.writeQuery({
  query: GET_USER,
  variables: { id: '1' },
  data: { user: { __typename: 'User', id: '1', name: 'Alice' } },
});

// Read from cache (no network)
const data = client.cache.readQuery({ query: GET_USER, variables: { id: '1' } });

// Modify cached object
client.cache.modify({
  id: client.cache.identify({ __typename: 'User', id: '1' }),
  fields: {
    name: () => 'Alice Updated',
    posts: (existing, { readField }) => [...existing, newPostRef],
  },
});

// Evict from cache
client.cache.evict({ id: client.cache.identify({ __typename: 'Post', id: '5' }) });
client.cache.gc(); // Garbage collect unreachable objects
```

### Optimistic UI
```js
const [updateUser] = useMutation(UPDATE_USER, {
  optimisticResponse: {
    updateUser: {
      __typename: 'User',
      id: userId,
      name: newName, // Show immediately
    },
  },
});
```

### Fetch Policies
- `cache-first` (default): serve from cache, only fetch if cache miss
- `cache-and-network`: serve cache immediately, also fetch to update
- `network-only`: always fetch, write to cache
- `no-cache`: always fetch, don't write to cache
- `cache-only`: never fetch, throw if cache miss
- `standby`: same as cache-first but doesn't subscribe to updates

---

## 9. Relay

### Relay Server Specification Requirements
A Relay-compatible server must implement:
1. **Node interface** — any object with a globally unique `id: ID!`
2. **node root query** — `query { node(id: ID!): Node }`
3. **Connections specification** — paginated lists

### Relay Connections Pattern
```graphql
type UserConnection {
  edges: [UserEdge]
  pageInfo: PageInfo!
  totalCount: Int
}

type UserEdge {
  node: User
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}

type Query {
  users(
    first: Int
    after: String
    last: Int
    before: String
  ): UserConnection!
}
```

Forward pagination: `first` + `after`. Backward pagination: `last` + `before`.

Cursor-based pagination advantages over offset:
- Stable results as items are added/removed
- Can be implemented on any ordered key (not just row offset)
- Opaque cursors can change implementation without client changes

### Relay Directives (Client-Side)
```graphql
# Inline fragments with type refinement
fragment UserCard on User {
  id
  name
  ... on AdminUser @include(if: $isAdmin) {
    adminSince
  }
}
```

Key Relay directives: `@relay`, `@connection`, `@refetchable`, `@argumentDefinitions`, `@arguments`.

### Relay 17+
- Full TypeScript support
- Rust-based compiler (relay-compiler) for fast builds
- `useLazyLoadQuery` and `useFragment` hooks
- Live queries via subscriptions
- Client schema extensions

---

## 10. GraphQL Federation 2.x

### Architecture
Federation splits a single supergraph across multiple independently deployable subgraphs. The Apollo Router (Rust-based) handles query planning and request distribution.

```
Client → Apollo Router (Supergraph) → Subgraph A (Users)
                                    → Subgraph B (Products)
                                    → Subgraph C (Orders)
```

### Subgraph Schema (Federation 2)
```graphql
extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.3", import: ["@key", "@external", "@requires", "@provides", "@shareable"])

type User @key(fields: "id") {
  id: ID!
  name: String!
  email: String!
}

type Query {
  me: User
}
```

### Entity Resolution
```js
const resolvers = {
  User: {
    __resolveReference(reference, ctx) {
      return ctx.db.users.findById(reference.id);
    },
  },
};
```

### Federation 2 Key Directives
- `@key(fields: "id")` — marks entity type with primary key
- `@external` — field defined in another subgraph
- `@requires(fields: "...")` — requires fields from another subgraph before resolving
- `@provides(fields: "...")` — declares fields this subgraph can provide for its entities
- `@shareable` — type/field can be resolved by multiple subgraphs
- `@inaccessible` — hide field from supergraph schema
- `@override(from: "SubgraphName")` — migrate field ownership

### Rover CLI (Federation Tooling)
```bash
# Install Rover
curl -sSL https://rover.apollo.dev/nix/latest | sh

# Publish subgraph schema
rover subgraph publish my-graph@current \
  --schema ./schema.graphql \
  --name users \
  --routing-url http://users-service/graphql

# Compose supergraph locally
rover supergraph compose --config supergraph.yaml

# Check for breaking changes
rover subgraph check my-graph@current \
  --schema ./schema.graphql \
  --name users
```

### Supergraph Config (supergraph.yaml)
```yaml
federation_version: =2.3.0
subgraphs:
  users:
    routing_url: http://localhost:4001/graphql
    schema:
      file: ./users.graphql
  products:
    routing_url: http://localhost:4002/graphql
    schema:
      file: ./products.graphql
```

### Schema Stitching vs Federation

| Aspect | Schema Stitching | Apollo Federation |
|--------|-----------------|-------------------|
| Governance | Decentralized (any service owns any type) | Centralized (each type has one origin) |
| Complexity | Simple to start, complex at scale | More upfront, cleaner at scale |
| Team knowledge required | Gateway team owns stitching logic | All teams must know federation |
| Tool support | graphql-tools, The Guild | Apollo Router, Rover, GraphOS |
| Best for | Few services, shared types | Many teams, independent services |

---

## 11. Other Server Libraries

### graphql-yoga (The Guild)
Full-featured, framework-agnostic, built on Fetch API. Runs on Node.js, Deno, Bun, Cloudflare Workers, AWS Lambda.

```ts
import { createYoga } from 'graphql-yoga';
import { createServer } from 'http';

const yoga = createYoga({
  typeDefs: /* GraphQL */ `
    type Query { hello: String! }
  `,
  resolvers: {
    Query: { hello: () => 'Hello from Yoga!' },
  },
  graphiql: true,
  cors: { origin: 'https://myapp.com' },
});

createServer(yoga).listen(4000);
```

Supports: subscriptions (SSE by default, graphql-ws optional), defer/stream (experimental), persisted operations, response caching, rate limiting plugins.

Benchmark: ~10,941 req/s (without JIT).

### Mercurius (Fastify)
Highest-performance Node.js GraphQL server using Fastify + JIT compilation.

```js
const fastify = require('fastify')();
const mercurius = require('mercurius');

fastify.register(mercurius, {
  schema: `type Query { add(x: Int, y: Int): Int }`,
  resolvers: { Query: { add: (_, { x, y }) => x + y } },
  graphiql: true,
  jit: 1, // Enable JIT after 1st request
});

fastify.listen({ port: 4000 });
```

Benchmark: 70,000+ req/s with JIT. Best choice for high-throughput APIs.
Supports: subscriptions, federation, loaders (DataLoader built-in), caching.

### Strawberry (Python)
Code-first Python library using type hints and dataclasses:

```python
import strawberry
from typing import Optional

@strawberry.type
class User:
    id: strawberry.ID
    name: str
    email: str

@strawberry.type
class Query:
    @strawberry.field
    def user(self, id: strawberry.ID) -> Optional[User]:
        return User(id=id, name="Alice", email="alice@example.com")

schema = strawberry.Schema(query=Query)
```

ASGI integration:
```python
from strawberry.fastapi import GraphQLRouter
import fastapi

app = fastapi.FastAPI()
graphql_app = GraphQLRouter(schema)
app.include_router(graphql_app, prefix="/graphql")
```

DataLoader support built-in. Supports subscriptions via async generators.

### Hot Chocolate (.NET)
Code-first and annotation-first (attribute-based) .NET GraphQL server, compliant with October 2021 spec + drafts.

```csharp
// Annotation-based approach
[QueryType]
public class Query
{
    public User? GetUser(int id, [Service] IUserRepository repo)
        => repo.GetById(id);
}

[ObjectType]
public class User
{
    public int Id { get; set; }
    public string Name { get; set; } = "";

    [UseProjection]
    [UseFiltering]
    [UseSorting]
    public IQueryable<Post> GetPosts([Service] AppDbContext db)
        => db.Posts.Where(p => p.AuthorId == Id);
}
```

Program setup:
```csharp
builder.Services
    .AddGraphQLServer()
    .AddQueryType<Query>()
    .AddMutationType<Mutation>()
    .AddSubscriptionType<Subscription>()
    .AddFiltering()
    .AddSorting()
    .AddProjections()
    .AddInMemorySubscriptions();
```

Hot Chocolate features: Banana Cake Pop IDE, Nitro (cloud IDE), built-in DataLoader, EF Core integration with projections.

---

## 12. Persisted Queries and APQ

### Automatic Persisted Queries (APQ)
Client sends hash first; server returns `PersistedQueryNotFound` if unknown; client resends full query with hash; server stores mapping.

```
# Request 1 (hash only)
POST /graphql
{ "extensions": { "persistedQuery": { "version": 1, "sha256Hash": "abc123..." } } }

# Response (cache miss)
{ "errors": [{ "message": "PersistedQueryNotFound", "extensions": { "code": "PERSISTED_QUERY_NOT_FOUND" } }] }

# Request 2 (hash + full query)
POST /graphql
{ "query": "query GetUser { ... }", "extensions": { "persistedQuery": { "version": 1, "sha256Hash": "abc123..." } } }
```

APQ benefit: reduces request payload size; subsequent requests use only the hash (GET-able, CDN-cacheable).

Apollo Server APQ setup:
```js
import { ApolloServerPluginCacheControl } from '@apollo/server/plugin/cacheControl';
import responseCachePlugin from '@apollo/server-plugin-response-cache';

const server = new ApolloServer({
  typeDefs,
  resolvers,
  plugins: [responseCachePlugin()],
  cache: new KeyvAdapter(new Keyv({ store: new KeyvRedis(redisClient) })),
});
```

### Persisted Query Lists (PQL) — Security Mode
Unlike APQ, a PQL is a pre-registered allowlist of operations. Only registered operations execute; arbitrary queries are rejected. Provides security (no ad-hoc query injection) plus performance.

```bash
# Generate and publish persisted queries with Rover
rover persisted-queries publish my-graph@current \
  --manifest ./persisted-query-manifest.json
```

---

## 13. Subscriptions

### Transport Options

**graphql-ws** (recommended, replaces deprecated `subscriptions-transport-ws`):
```bash
npm install graphql-ws ws
```

Server setup with Apollo Server:
```js
import { WebSocketServer } from 'ws';
import { useServer } from 'graphql-ws/lib/use/ws';
import { makeExecutableSchema } from '@graphql-tools/schema';

const schema = makeExecutableSchema({ typeDefs, resolvers });
const wsServer = new WebSocketServer({ server: httpServer, path: '/graphql' });
const serverCleanup = useServer({ schema }, wsServer);
```

**Server-Sent Events (SSE)** — alternative transport (GraphQL Yoga default):
- Unidirectional (server to client only), but simpler than WebSocket
- Automatically reconnects
- Works through HTTP/1.1 proxies without special config
- Lower overhead for uni-directional streams

### Subscription Resolver Pattern
```js
const { PubSub } = require('graphql-subscriptions');
const pubsub = new PubSub();

const resolvers = {
  Mutation: {
    createComment: async (_, { input }, ctx) => {
      const comment = await ctx.db.comments.create(input);
      await pubsub.publish('COMMENT_ADDED', {
        commentAdded: comment,
        postId: input.postId,
      });
      return comment;
    },
  },
  Subscription: {
    commentAdded: {
      subscribe: (_, { postId }) =>
        pubsub.asyncIterableIterator('COMMENT_ADDED'),
      resolve: (payload) => payload.commentAdded,
    },
  },
};
```

For production, replace in-memory PubSub with Redis-backed pubsub (`graphql-redis-subscriptions`):
```js
const { RedisPubSub } = require('graphql-redis-subscriptions');
const pubsub = new RedisPubSub({
  publisher: new Redis({ host: 'redis', port: 6379 }),
  subscriber: new Redis({ host: 'redis', port: 6379 }),
});
```

---

## 14. @defer and @stream (Incremental Delivery)

### Status (as of 2026)
Stage 2 proposal. Implemented experimentally in GraphQL Yoga, graphql-js v17+, Apollo Client, Altair. Not yet in the stable spec. Protocol not finalized.

### @defer
Allows de-prioritizing fragments — server sends initial response immediately, deferred fragments arrive later as separate payloads via multipart HTTP response.

```graphql
query GetUserWithPosts($id: ID!) {
  user(id: $id) {
    id
    name
    # Fast fields in initial response
    ... @defer(label: "userPosts") {
      posts { id title }
    }
    ... @defer(label: "userAnalytics") {
      analytics { views clicks }
    }
  }
}
```

### @stream
Streams individual list items as they resolve:
```graphql
query GetFeed {
  feed @stream(initialCount: 3) {
    id
    title
    body
  }
}
```

`initialCount: 3` delivers first 3 items in initial response; remaining stream separately.

### Response Format (Multipart)
```
Content-Type: multipart/mixed; boundary="-"

---
{"data":{"user":{"id":"1","name":"Alice"}},"hasNext":true}
---
{"incremental":[{"data":{"posts":[...]},"label":"userPosts","path":["user"]}],"hasNext":false}
-----
```

---

## 15. Best Practices: Schema Design

### Input Types for All Mutations
```graphql
# Good — extensible input type
mutation UpdateUser($input: UpdateUserInput!) { ... }
input UpdateUserInput { name: String email: String avatarUrl: String }

# Avoid — positional args are brittle as schema evolves
mutation UpdateUser($name: String, $email: String) { ... }
```

### Relay-Style Connections Everywhere for Lists
```graphql
# Good
users(first: Int, after: String): UserConnection!

# Avoid for paginated data
users: [User!]!
```

### Nullable vs Non-Null Choices
- Prefer nullable return types on query fields that might not exist — avoids null propagation cascades.
- Use `!` (non-null) aggressively on input types to catch missing required data at schema validation level.
- Rule of thumb: "nullable by default in queries, non-null in inputs."

### Single Responsibility for Types
Avoid "god types" that combine unrelated concerns. Use interfaces to share common fields.

### Error Handling Patterns

**Pattern 1: Top-level errors array** (spec default)
```json
{
  "data": { "user": null },
  "errors": [{ "message": "Not found", "locations": [...], "path": ["user"], "extensions": { "code": "NOT_FOUND" } }]
}
```

**Pattern 2: Typed error unions** (recommended for mutations)
```graphql
type Mutation {
  login(input: LoginInput!): LoginPayload!
}

union LoginPayload = LoginSuccess | InvalidCredentialsError | UserSuspendedError

type LoginSuccess { token: String! user: User! }
type InvalidCredentialsError { message: String! }
type UserSuspendedError { message: String! suspendedUntil: DateTime }
```

Client query:
```graphql
mutation Login($input: LoginInput!) {
  login(input: $input) {
    ... on LoginSuccess { token user { id name } }
    ... on InvalidCredentialsError { message }
    ... on UserSuspendedError { message suspendedUntil }
  }
}
```

Pattern 2 advantages: errors are typed (no string matching), full type safety, explicit client handling.

### Schema Documentation
```graphql
"""
A user account in the system.
Implements the Node interface for Relay compatibility.
"""
type User implements Node {
  """Globally unique identifier."""
  id: ID!

  """Display name, max 100 characters."""
  name: String!

  """
  Email address. Returned only for the authenticated user or admins.
  @auth(requires: ADMIN)
  """
  email: String
}
```

---

## 16. Security

### Query Depth Limiting
```bash
npm install graphql-depth-limit
```

```js
import depthLimit from 'graphql-depth-limit';

const server = new ApolloServer({
  validationRules: [depthLimit(7)],
});
```

Error: `'GetUsers' exceeds maximum operation depth of 7`

### Query Complexity Analysis
```bash
npm install graphql-query-complexity
```

```js
import { createComplexityLimitRule } from 'graphql-query-complexity';

const ComplexityLimit = createComplexityLimitRule(1000, {
  scalarCost: 1,
  objectCost: 2,
  listFactor: 10,
  introspectionListFactor: 2,
});

const server = new ApolloServer({
  validationRules: [ComplexityLimit],
});
```

Per-field complexity using directives or estimators:
```js
fieldExtensionsEstimator(), // uses extensions.complexity on type defs
simpleEstimator({ defaultComplexity: 1 }),
```

### Rate Limiting
GraphQL-aware rate limiting considers operation complexity rather than just request count.

```js
// Using graphql-shield for field-level rate limiting
import { allow, shield } from 'graphql-shield';

const permissions = shield({
  Query: {
    search: rateLimit({ window: '1s', max: 10 }),
  },
});
```

### Authentication and Authorization

**Context-based auth (recommended):**
```js
context: async ({ req }) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  const user = token ? await verifyJWT(token) : null;
  return { user, db, loaders };
},
```

**Field-level authorization:**
```js
// graphql-shield
const permissions = shield({
  Query: {
    adminStats: isAuthenticated && hasRole('ADMIN'),
    me: isAuthenticated,
    publicFeed: allow,
  },
  User: {
    email: isOwnerOrAdmin,
  },
});
```

**Directive-based authorization:**
```graphql
directive @auth(requires: Role = MEMBER) on FIELD_DEFINITION

type Query {
  publicFeed: [Post!]!
  adminReport: Report! @auth(requires: ADMIN)
}
```

```js
// Custom directive transformer
function authDirectiveTransformer(schema) {
  return mapSchema(schema, {
    [MapperKind.OBJECT_FIELD](fieldConfig) {
      const authDirective = getDirective(schema, fieldConfig, 'auth')?.[0];
      if (authDirective) {
        const { resolve = defaultFieldResolver } = fieldConfig;
        fieldConfig.resolve = async (source, args, context, info) => {
          if (!context.user?.roles.includes(authDirective.requires)) {
            throw new GraphQLError('Unauthorized', {
              extensions: { code: 'FORBIDDEN' },
            });
          }
          return resolve(source, args, context, info);
        };
      }
      return fieldConfig;
    },
  });
}
```

---

## 17. Schema Evolution and Versioning

### GraphQL's Versionless Philosophy
GraphQL APIs are designed to evolve without versioning. The recommended approach:
1. Add new fields (always backward compatible).
2. Deprecate old fields with `@deprecated(reason: "Use newField instead")`.
3. Monitor usage with observability tooling.
4. Remove field only when usage reaches zero.

### @deprecated Directive
```graphql
type User {
  name: String!
  fullName: String! @deprecated(reason: "Use `name` instead")
  # New split fields
  firstName: String!
  lastName: String!
}
```

Introspection exposes deprecated fields; clients can suppress them. Tools like GraphOS Studio track which clients query deprecated fields.

### Breaking vs Non-Breaking Changes

**Non-breaking (safe):**
- Adding new types, fields, arguments with defaults
- Adding new enum values (can break exhaustive switches on clients)
- Adding new optional input fields
- Implementing new interfaces

**Breaking (dangerous):**
- Removing or renaming fields/types/arguments
- Changing field types (nullable → non-null, or scalar type change)
- Adding required (non-null) arguments
- Removing enum values
- Changing argument types

### Schema Linting and CI Validation
```bash
# Using graphql-inspector
npx @graphql-inspector/cli diff \
  old-schema.graphql new-schema.graphql

# Rover check in CI
rover subgraph check my-graph@current \
  --schema ./schema.graphql --name users
```

---

## 18. Performance Profiling and Tracing

### Apollo Tracing (Legacy)
The `apollo-tracing` extension format reported resolver execution times. Now superseded by Apollo inline trace (for federation) and OpenTelemetry.

### OpenTelemetry Integration
```bash
npm install @opentelemetry/sdk-node @opentelemetry/instrumentation-graphql
```

```js
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { GraphQLInstrumentation } = require('@opentelemetry/instrumentation-graphql');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({ url: 'http://jaeger:4318/v1/traces' }),
  instrumentations: [
    new GraphQLInstrumentation({
      allowValues: true,      // include variable values in traces
      depth: 3,               // max depth to trace
    }),
  ],
});
sdk.start();
```

OpenTelemetry adds ~3-5% latency/CPU overhead. Use sampling for production:
```js
new TraceIdRatioBasedSampler(0.1) // trace 10% of requests
```

Note: GraphOS Studio does not consume OpenTelemetry format. Use Jaeger, Zipkin, or Datadog for OTel data.

### Apollo GraphOS Studio Metrics
Apollo Router emits telemetry in OTLP format. Studio tracks:
- Operation counts and error rates
- P50/P95/P99 latencies per operation
- Field-level usage (essential for deprecation decisions)
- Client identification (which clients query which fields)

### Query Plan Analysis (Federation)
Apollo Router exposes query plan via `Apollo-Require-Preflight` header or the Router's `queryPlanExperimentalDeferredNodes` config. Debug query plans:
```bash
# Enable query plan debugging in Apollo Router config (router.yaml)
telemetry:
  tracing:
    propagation:
      request:
        enabled: true
```

---

## 19. Common Errors and Diagnostics

### Schema Validation Errors (Startup)

```
Error: Unknown type: "User". Did you mean "Users"?
Error: Field "Query.user" can only be defined once.
Error: Type "User" must define one or more fields.
Error: The type of "Mutation.createPost(input:)" must be Input Type but got: Post.
```

### Query Validation Errors (Request-time)
```json
{
  "errors": [{
    "message": "Cannot query field \"nonExistentField\" on type \"User\".",
    "locations": [{ "line": 3, "column": 5 }]
  }]
}
```

```json
{
  "errors": [{
    "message": "Variable \"$id\" of required type \"ID!\" was not provided.",
    "locations": [{ "line": 1, "column": 16 }]
  }]
}
```

### Resolver Errors (Execution-time)
```json
{
  "data": { "user": null },
  "errors": [{
    "message": "Cannot read properties of undefined (reading 'name')",
    "locations": [{ "line": 3, "column": 5 }],
    "path": ["user", "name"],
    "extensions": { "code": "INTERNAL_SERVER_ERROR" }
  }]
}
```

### Circular Reference Issues
```
Error: Schema must contain uniquely named types but contains multiple types named "X".
RangeError: Maximum call stack size exceeded  // when resolving circular refs without depth limiting
```

Fix: Use `graphql-depth-limit` + lazy type resolvers:
```js
// Use thunk (function) to break circular reference at definition time
const UserType = new GraphQLObjectType({
  name: 'User',
  fields: () => ({  // thunk avoids circular reference at module load
    posts: { type: new GraphQLList(PostType) },
  }),
});
```

### N+1 Detection
```
# Symptom: Database logs show repeated identical queries with different IDs
SELECT * FROM users WHERE id = '1'
SELECT * FROM users WHERE id = '2'
SELECT * FROM users WHERE id = '3'
# Solution: DataLoader batches to:
SELECT * FROM users WHERE id IN ('1', '2', '3')
```

### Null Propagation Errors
```json
{
  "data": null,
  "errors": [{ "message": "...", "path": ["user", "profile", "name"] }]
}
```

When a non-null field returns null, null propagates up. If the root query field is non-null and it propagates to null, `data` becomes `null`. Make deeply nested fields nullable to contain the error.

### Extension Error Codes (Recommended Standard)
```json
{
  "errors": [{
    "message": "User not found",
    "extensions": {
      "code": "NOT_FOUND",
      "http": { "status": 404 }
    }
  }]
}
```

Standard codes: `UNAUTHENTICATED`, `FORBIDDEN`, `NOT_FOUND`, `BAD_USER_INPUT`, `INTERNAL_SERVER_ERROR`, `PERSISTED_QUERY_NOT_FOUND`.

---

## 20. CLI Commands Reference

```bash
# graphql-js / npm ecosystem
npm install graphql                         # Core library
npm install @apollo/server                  # Apollo Server 5
npm install graphql-ws ws                   # WebSocket transport
npm install dataloader                      # DataLoader
npm install graphql-depth-limit             # Depth limiting
npm install graphql-query-complexity        # Complexity analysis
npm install @graphql-tools/schema           # Schema utilities
npm install graphql-scalars                 # Custom scalars library
npm install graphql-shield                  # Auth middleware

# Apollo Rover CLI
curl -sSL https://rover.apollo.dev/nix/latest | sh
rover graph check my-graph@current --schema ./schema.graphql
rover subgraph publish my-graph@current --schema ./schema.graphql --name users --routing-url http://users/graphql
rover supergraph compose --config supergraph.yaml > supergraph.graphql
rover dev --supergraph-config supergraph.yaml  # Local federation dev

# GraphQL Code Generator
npm install -D @graphql-codegen/cli @graphql-codegen/typescript
npx graphql-codegen --config codegen.yml

# graphql-inspector
npx @graphql-inspector/cli validate ./schema.graphql
npx @graphql-inspector/cli diff ./old.graphql ./new.graphql
npx @graphql-inspector/cli coverage ./schema.graphql --documents './src/**/*.graphql'

# Python (Strawberry)
pip install strawberry-graphql[debug-server]
strawberry server schema:schema              # Dev server
strawberry export-schema schema:schema      # Export SDL

# .NET (Hot Chocolate)
dotnet add package HotChocolate.AspNetCore
dotnet add package HotChocolate.Data.EntityFramework
```

---

## Sources and References

- [GraphQL October 2021 Specification](https://spec.graphql.org/October2021/)
- [GraphQL Draft Specification](https://spec.graphql.org/draft/)
- [GraphQL Learn — Execution](https://graphql.org/learn/execution/)
- [GraphQL Learn — Schema and Types](https://graphql.org/learn/schema/)
- [GraphQL Learn — Subscriptions](https://graphql.org/learn/subscriptions/)
- [GraphQL Learn — Security](https://graphql.org/learn/security/)
- [Apollo Server Docs](https://www.apollographql.com/docs/apollo-server)
- [Apollo Server Migration Guide (v4→v5)](https://www.apollographql.com/docs/apollo-server/migration)
- [Apollo Federation — Federated Schemas](https://www.apollographql.com/docs/graphos/schema-design/federated-schemas/)
- [Apollo Client — Caching Overview](https://www.apollographql.com/docs/react/caching/overview)
- [Apollo Client — @defer Directive](https://www.apollographql.com/docs/react/data/defer)
- [Relay Cursor Connections Specification](https://relay.dev/graphql/connections.htm)
- [Relay GraphQL Server Specification](https://relay.dev/docs/guides/graphql-server-specification/)
- [GraphQL.js — DataLoader and N+1](https://www.graphql-js.org/docs/n1-dataloader/)
- [WunderGraph — DataLoader 3.0](https://wundergraph.com/blog/dataloader_3_0_breadth_first_data_loading)
- [GraphQL Yoga Documentation](https://the-guild.dev/graphql/yoga-server/docs/comparison)
- [Mercurius (Fastify GraphQL)](https://mercurius.dev)
- [Strawberry Python GraphQL](https://strawberry.rocks)
- [Hot Chocolate .NET](https://chillicream.com/docs/hotchocolate/v13/)
- [GraphQL over WebSockets — The Guild](https://the-guild.dev/graphql/hive/blog/graphql-over-websockets)
- [APQ — Apollo Docs](https://www.apollographql.com/docs/apollo-server/performance/apq)
- [GraphQL Defer/Stream RFC](https://github.com/graphql/graphql-wg/blob/main/rfcs/DeferStream.md)
- [GraphQL Schema Deprecations — Apollo](https://www.apollographql.com/docs/graphos/schema-design/guides/deprecations)
- [OpenTelemetry for Apollo Federation](https://www.apollographql.com/docs/graphos/routing/observability/otel)
- [Schema Stitching vs Federation — Hygraph](https://hygraph.com/blog/schema-stitching-vs-graphql-federation-vs-content-federation)
- [Better GraphQL Error Handling with Unions — DEV](https://dev.to/mnove/better-graphql-error-handling-with-typed-union-responses-1e1n)
- [Code-First vs Schema-First — LogRocket](https://blog.logrocket.com/code-first-vs-schema-first-development-graphql/)
