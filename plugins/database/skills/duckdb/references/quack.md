# DuckDB Quack Remote Protocol Reference

> **Beta feature.** Quack ships as a core extension starting in **DuckDB v1.5.3** (released 2026-05-20)
> and is explicitly in **beta** until the production release planned for **DuckDB v2.0.0 (fall 2026)**.
> The official docs warn: *"Quack is under active development and the protocol, function names,
> settings, and defaults are still subject to change."* Treat function names, settings, and defaults
> below as a snapshot -- verify volatile details against the current docs before relying on them in
> production. Official sources: <https://duckdb.org/quack/> and
> <https://duckdb.org/docs/current/core_extensions/quack>.

## What Quack Is

Quack is a Remote Procedure Call (RPC) protocol that turns two DuckDB processes into a **client and a
server**, effectively giving DuckDB an optional client-server mode without abandoning its in-process
roots. The Quack extension is loaded on both sides: a server process exposes its full SQL surface over
HTTP, and client processes query it remotely as if the remote tables were local.

It directly addresses DuckDB's traditional single-writer / in-process limitation -- the case where you
want multiple processes to read and write the *same* database concurrently (for example, many
collectors inserting telemetry while a dashboard queries the same tables). Quack is **not** a
distributed query engine; it is point-to-point client/server access.

**Transport and wire format:**

- Built on **HTTP (HTTP/2)** -- works through firewalls, load balancers, and reverse proxies.
- **Client-driven:** every interaction is initiated by the client; the server never pushes.
- Serializes results with the custom `application/duckdb` MIME type using DuckDB's internal
  serialization primitives, so complex/nested types cross the wire losslessly. After the handshake,
  a query can complete in a single round trip.

## Installation

Quack is autoinstalled and autoloaded on first use in v1.5.3+, so no setup is normally required. The
explicit forms still work:

```sql
INSTALL quack;
LOAD quack;

-- Pre-release / nightly builds:
INSTALL quack FROM core_nightly;
```

## Server Setup

Start a server with `quack_serve`. If no token is supplied, DuckDB generates a random one at startup
and returns it (along with the listen URI) -- capture it, the client needs it.

```sql
-- Local server on the default port (9494), auto-generated token
CALL quack_serve('quack:localhost');

-- Local server with an explicit token (minimum 4 characters)
CALL quack_serve('quack:localhost', token = 'super_secret');

-- Stop the server
CALL quack_stop('quack:localhost');
```

The URI uses the `quack:` scheme with an optional host and port:

| URI | Meaning |
|---|---|
| `quack:localhost` | localhost, default port 9494 |
| `quack:myhost:9000` | named host, custom port |
| `quack:0.0.0.0:9494` | bind all interfaces (requires explicit opt-in) |
| `quack:[::1]:1234` | IPv6 loopback, custom port |

**Default port: `9494`.**

By default the server binds to **localhost only**. Binding to any non-local address is a deliberate
opt-in to avoid accidentally exposing the database to a network:

```sql
-- Bind to all interfaces -- only do this behind a reverse proxy / firewall
CALL quack_serve('quack:0.0.0.0:9494', allow_other_hostname => true);
```

A typical server session also creates the data the client will read:

```sql
LOAD quack;
CALL quack_serve('quack:localhost', token = 'super_secret');
CREATE TABLE hello AS FROM VALUES ('world') v(s);
```

## Client Setup

There are three ways to reach a Quack server, from most ad-hoc to most integrated.

### 1. Stateless one-off query -- `quack_query`

```sql
FROM quack_query(
    'quack:localhost',
    'SELECT 42',
    token = 'super_secret'
);
```

### 2. Persistent attachment -- `ATTACH`

Once attached, remote tables look and behave like local ones (DDL, DML, transactions, and queries
with remote filter execution all work):

```sql
-- Inline token
ATTACH 'quack:localhost' AS remote_db (TOKEN 'super_secret');

FROM remote_db.hello;                         -- read
CREATE TABLE remote_db.hello2 AS FROM VALUES ('world2') v(s);   -- write
FROM remote_db.query('SELECT s FROM hello');  -- run SQL remotely
```

### 3. Secret-based auth (recommended -- keeps tokens out of SQL)

Store the token once as a DuckDB secret and `ATTACH` without an inline token. The secret applies
automatically to every connection matching its scope:

```sql
CREATE SECRET (
    TYPE quack,
    TOKEN 'super_secret',
    SCOPE 'quack:localhost'   -- limit the secret to a specific server
);

ATTACH 'quack:localhost' AS remote;
FROM remote.hello;
```

An inline `TOKEN`/`token =` parameter always overrides a matching secret.

## Security

A Quack server exposes the **full SQL surface** of the underlying DuckDB instance -- read and write
access to every table the server's session can see. Treat standing up a server as publishing a
database endpoint and secure it accordingly.

### Transport: HTTP for local, HTTPS for remote

The client chooses the transport automatically based on the URI:

> *"The client picks plain HTTP automatically for local URIs (`localhost`, `127.0.0.1`, `::1`) and
> HTTPS otherwise."*

The server itself **does not terminate TLS**. For loopback traffic that is intentional -- *"Involving
TLS for localhost communication only adds dependencies for no real benefit."* For everything else, the
client assumes HTTPS, so a correctly fronted server "just works" from the client side. You can override
the choice with `DISABLE_SSL` (e.g. `ATTACH ... (DISABLE_SSL true)` or `disable_ssl => true` on the
functions), but doing so for non-local traffic sends queries and tokens in clear text -- avoid it.

### Recommended endpoint: standard HTTPS via a TLS-terminating reverse proxy

This is the verdict for any non-local deployment. The docs are explicit:

> *"For any deployment beyond local-only, do not expose Quack directly to the internet. We recommend
> you put a proven HTTP reverse proxy in front of it and let the proxy terminate TLS."*

> *"We do not recommend opening up a DuckDB Quack endpoint directly to the Internet. Instead we
> strongly recommend that you use a common HTTP endpoint like nginx if you should choose to expose
> Quack to the World Wide Web."*

In other words: the recommended production endpoint is **standard HTTPS (443) fronted by nginx (or an
equivalent reverse proxy / load balancer) that terminates TLS** and forwards to the loopback-bound
Quack server. Because Quack rides on plain HTTP/2, any mature HTTP proxy works, and the client's
automatic HTTPS-for-remote behavior lines up with this pattern with no extra client configuration. The
maintained AWS CloudFormation one-click template implements exactly this: an EC2 instance running
DuckDB + Quack behind **nginx with a Let's Encrypt certificate**, with the security group opening only
port 80 (ACME challenge) and 443 (HTTPS).

Recommended deployment shape:

```
client ──HTTPS:443──▶ nginx (TLS termination) ──HTTP──▶ quack server (bound to localhost:9494)
```

### Authentication

- **Token on every request.** A random token is generated at startup if you don't supply one; custom
  tokens must be at least 4 characters. The client must present the matching token.
- **Prefer secrets over inline tokens.** Use `CREATE SECRET (TYPE quack, TOKEN '…', SCOPE 'quack:…')`
  so credentials aren't embedded in query text or logs. Reserve the inline `TOKEN`/`token =` form for
  quick tests; it overrides any matching secret.
- **Pluggable auth/authorization hooks.** The server accepts an authentication callback (fired on the
  connection request, receives the client and server tokens, returns a boolean) and an authorization
  callback (fired per query, receives the SQL text, returns a boolean). These let you enforce custom
  policy -- e.g. rejecting writes or restricting which statements are allowed. Note: Python UDFs cannot
  be used as callbacks (they are connection-scoped); use SQL macros or compatible UDFs.

### Hardening checklist

- Keep the server bound to **localhost** and reach it only through the reverse proxy; require
  `allow_other_hostname => true` consciously, never by habit.
- **Terminate TLS at the proxy** and never set `DISABLE_SSL` for remote clients.
- Use a **strong, unique token** stored as a secret; rotate it; never commit it to source control.
- Firewall the Quack port (9494) so only the proxy/loopback can reach it; expose only 443 publicly.
- Use the **authorization callback** to enforce least privilege (e.g. read-only access) since the
  server otherwise exposes the full read/write SQL surface.
- Because Quack is **beta**, pin your DuckDB version and re-review settings on upgrade -- defaults and
  function names may change before v2.0.0.

## Endpoints and Protocol Summary

| Aspect | Value |
|---|---|
| Transport | HTTP/2 |
| Result encoding | `application/duckdb` MIME type (DuckDB internal serialization) |
| URI scheme | `quack:` |
| Default port | `9494` |
| Local transport | plain HTTP (localhost / 127.0.0.1 / ::1) |
| Remote transport | HTTPS (client default for non-local URIs) |
| Recommended production endpoint | **standard HTTPS via TLS-terminating reverse proxy (e.g. nginx + Let's Encrypt)** |
| TLS termination | external proxy -- the server does not do TLS itself |
| Interaction model | client-driven request/response (no server push) |

## Limitations and Caveats

- **Beta.** Protocol, function names, settings, and defaults may change before v2.0.0 (fall 2026).
- **No distributed query processing** -- Quack is point-to-point client/server, not a cluster engine.
- **Concurrency ceiling.** Small-write throughput scales to roughly 8 parallel threads before hitting
  a current DuckDB limit on concurrent insertions into the same table; the team expects to improve
  this before GA.
- **No built-in TLS** -- production security depends on the reverse proxy you put in front of it.
- **Full SQL surface exposed** -- without an authorization callback, an authenticated client can do
  anything the server session can.

## Official Sources

- Quack Remote Protocol overview -- <https://duckdb.org/quack/>
- Quack core extension docs -- <https://duckdb.org/docs/current/core_extensions/quack>
- Quack security -- <https://duckdb.org/docs/current/quack/security>
- Quack setup / deployment -- <https://duckdb.org/docs/current/quack/setup/deployment>
- Quack FAQ -- <https://duckdb.org/quack/faq>
- Announcement blog -- <https://duckdb.org/2026/05/12/quack-remote-protocol>
- DuckDB 1.5.3 release notes -- <https://duckdb.org/2026/05/20/announcing-duckdb-153>
