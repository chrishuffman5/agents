# GraphQL Architecture Deep Dive

## Type System

### Scalars

Built-in: `Int`, `Float`, `String`, `Boolean`, `ID`. Custom scalars must define serialization, parsing, and validation:

```graphql
scalar DateTime
scalar URL
scalar JSON
```

```js
const DateTimeScalar = new GraphQLScalarType({
  name: 'DateTime',
  serialize(value) { return value.toISOString(); },
  parseValue(value) { return new Date(value); },
  parseLiteral(ast) { return ast.kind === Kind.STRING ? new Date(ast.value) : null; },
});
```

Community library `graphql-scalars` provides 50+ production-ready scalars.

### Object Types and Field Arguments

```graphql
type User {
  id: ID!
  name: String!
  email: String!
  posts(first: Int, after: String): PostConnection!
  createdAt: DateTime!
}
```

### Interfaces

```graphql
interface Node { id: ID! }
interface Timestamped { createdAt: DateTime!; updatedAt: DateTime! }

type Post implements Node & Timestamped {
  id: ID!
  title: String!
  createdAt: DateTime!
  updatedAt: DateTime!
}
```

Interfaces can implement other interfaces (October 2021 spec).

### Unions

```graphql
union SearchResult = Post | User | Comment
```

Unions cannot define shared fields (use interfaces). Query via inline fragments:
```graphql
{ search(query: "test") { ... on User { name } ... on Post { title } __typename } }
```

### Input Types

Exclusively for arguments (write-side):
```graphql
input CreatePostInput {
  title: String!
  body: String!
  tags: [String!]!
  status: PostStatus = DRAFT
}
```

Cannot contain interfaces, unions, or output types. No circular references.

### Wrapping Types

- `[Type]` -- nullable list of nullable items
- `[Type!]` -- nullable list of non-null items
- `[Type!]!` -- non-null list of non-null items

## Execution Model

### Four Phases

1. **Lexing**: tokenize query string
2. **Parsing**: build AST
3. **Validation**: check against schema (field existence, argument types, fragment validity)
4. **Execution**: traverse selection set, call resolvers

### Resolver Execution

```js
function resolver(parent, args, context, info) {
  // parent: result of parent resolver
  // args: field arguments
  // context: per-request shared state (db, loaders, user)
  // info: fieldName, returnType, schema, path, fragments
}
```

**Default resolver**: if none defined, returns `parent[fieldName]` (property access).

**Sibling field resolution**: Query fields resolve concurrently. Mutation root fields execute serially (in document order).

### Null Propagation

If a non-null field (`!`) returns null, the null propagates up to the nearest nullable parent. This can cascade and null out entire sections of the response. Design non-null carefully -- only mark fields non-null when the server can guarantee a value.

## Operations

### Queries
```graphql
query GetUser($id: ID!) {
  user(id: $id) { id name posts(first: 10) { edges { node { title } cursor } pageInfo { hasNextPage endCursor } } }
}
```

### Mutations
```graphql
mutation CreatePost($input: CreatePostInput!) {
  createPost(input: $input) { id title createdAt }
}
```

### Subscriptions
```graphql
subscription OnCommentAdded($postId: ID!) {
  commentAdded(postId: $postId) { id body author { name } }
}
```

Subscriptions use an async iterator pattern. Each event triggers a full execute cycle.

### Fragments and Directives

```graphql
fragment UserBasic on User { id name avatarUrl }
query { activeUsers { ...UserBasic } }
```

Built-in directives: `@include(if:)`, `@skip(if:)`, `@deprecated(reason:)`, `@specifiedBy(url:)`.
Draft: `@defer`, `@stream` for incremental delivery.

## Relay Specification

### Requirements

1. **Node interface**: any object with globally unique `id: ID!`
2. **node root query**: `query { node(id: ID!): Node }`
3. **Connections specification**: paginated lists

### Connection Pattern

```graphql
type UserConnection {
  edges: [UserEdge]
  pageInfo: PageInfo!
}
type UserEdge { node: User; cursor: String! }
type PageInfo { hasNextPage: Boolean!; hasPreviousPage: Boolean!; startCursor: String; endCursor: String }
```

Forward pagination: `first` + `after`. Backward: `last` + `before`.

## Federation 2.x

### Architecture

```
Client -> Apollo Router (Supergraph) -> Subgraph A (Users)
                                     -> Subgraph B (Products)
                                     -> Subgraph C (Orders)
```

### Subgraph Schema

```graphql
extend schema @link(url: "https://specs.apollo.dev/federation/v2.3", import: ["@key", "@external", "@requires", "@provides", "@shareable"])

type User @key(fields: "id") { id: ID!; name: String!; email: String! }
```

### Entity Resolution

```js
const resolvers = {
  User: { __resolveReference(ref, ctx) { return ctx.db.users.findById(ref.id); } },
};
```

### Key Directives

- `@key(fields: "id")` -- entity primary key
- `@external` -- field defined in another subgraph
- `@requires(fields: "...")` -- requires fields from other subgraph before resolving
- `@provides(fields: "...")` -- subgraph can provide fields for its entities
- `@shareable` -- type/field resolvable by multiple subgraphs
- `@override(from: "SubgraphName")` -- migrate field ownership

### Rover CLI

```bash
rover subgraph publish my-graph@current --schema ./schema.graphql --name users --routing-url http://users/graphql
rover subgraph check my-graph@current --schema ./schema.graphql --name users
rover supergraph compose --config supergraph.yaml
```

## Server Implementations

### Apollo Server 5

```js
import { ApolloServer } from '@apollo/server';
const server = new ApolloServer({ typeDefs, resolvers, introspection: process.env.NODE_ENV !== 'production' });
```

Changes from v4: Node.js 20+ required, `status400ForVariableCoercionErrors` defaults to true, compiled to ES2023.

### Mercurius (Fastify)

```js
fastify.register(mercurius, { schema, resolvers, graphiql: true, jit: 1 });
```

70,000+ req/s with JIT. Highest-performance Node.js GraphQL server.

### Strawberry (Python)

```python
@strawberry.type
class Query:
    @strawberry.field
    def user(self, id: strawberry.ID) -> Optional[User]:
        return User(id=id, name="Alice", email="alice@example.com")
```

### Hot Chocolate (.NET)

```csharp
builder.Services.AddGraphQLServer()
    .AddQueryType<Query>()
    .AddFiltering().AddSorting().AddProjections();
```

Annotation-based with `[QueryType]`, `[UseProjection]`, `[UseFiltering]`.
