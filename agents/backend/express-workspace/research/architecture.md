# Express.js Architecture Research
**Target:** Senior Node.js developers  
**Scope:** Express 4/5, middleware, routing, APIs, testing, performance, TypeScript  
**Date:** 2026-04-09

---

## Table of Contents

1. [Middleware Chain](#1-middleware-chain)
2. [Routing](#2-routing)
3. [Express 5 Changes](#3-express-5-changes)
4. [Request and Response API](#4-request-and-response-api)
5. [Template Engines](#5-template-engines)
6. [Error Handling Patterns](#6-error-handling-patterns)
7. [Static Files](#7-static-files)
8. [CORS](#8-cors)
9. [Security with Helmet](#9-security-with-helmet)
10. [Body Parsing](#10-body-parsing)
11. [Project Structure Patterns](#11-project-structure-patterns)
12. [Testing with Supertest](#12-testing-with-supertest)
13. [Performance](#13-performance)
14. [TypeScript Setup](#14-typescript-setup)
15. [Express vs Fastify vs Koa](#15-express-vs-fastify-vs-koa)

---

## 1. Middleware Chain

### How `app.use` Ordering Works

Express middleware executes in the order it is registered. Each middleware receives `(req, res, next)` and must either terminate the request (by calling `res.send`, `res.json`, etc.) or pass control to the next middleware by calling `next()`. Failing to call `next()` or terminate the response will cause the request to hang.

```js
import express from 'express';
const app = express();

// Middleware 1 — runs first
app.use((req, res, next) => {
  console.log('Middleware 1:', req.method, req.url);
  next(); // pass to next
});

// Middleware 2 — runs second
app.use((req, res, next) => {
  req.startTime = Date.now();
  next();
});

// Route handler — runs third (only when path matches)
app.get('/users', (req, res) => {
  res.json({ elapsed: Date.now() - req.startTime });
});

// This never runs for GET /users because the route above terminated the response
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});
```

**Key ordering rules:**
- Middleware registered before a route runs before that route handler.
- `app.use('/prefix', fn)` only runs for requests whose URL starts with `/prefix`.
- Path-scoped `app.use` strips the prefix before passing `req.url` to the handler.

### Error Middleware: The 4-Argument Signature

Error-handling middleware is distinguished from normal middleware solely by the 4-parameter signature `(err, req, res, next)`. Express skips error handlers during normal flow and only invokes them when `next(err)` is called with a truthy argument or when an async error is caught (Express 5).

```js
// Normal middleware — 3 params
app.use((req, res, next) => {
  throw new Error('Something broke'); // Express 5 catches this automatically
  // Express 4: must call next(new Error('...'))
});

// Error handler — MUST have exactly 4 params; Express checks function.length
app.use((err, req, res, next) => {
  console.error(err.stack);
  const status = err.status ?? err.statusCode ?? 500;
  res.status(status).json({
    error: err.message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
});
```

Multiple error handlers can be chained. Call `next(err)` inside an error handler to delegate to the next one (e.g., a generic fallback logger).

### Third-Party Middleware

Common middleware and their registration order conventions:

```js
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';

const app = express();

// Security headers — register first
app.use(helmet());

// CORS — before routes, after helmet
app.use(cors({ origin: process.env.ALLOWED_ORIGINS?.split(',') }));

// Rate limiting — before body parsing to fail fast
app.use('/api', rateLimit({ windowMs: 15 * 60 * 1000, max: 100 }));

// Request logging
app.use(morgan('combined'));

// Compression — before routes, after logging
app.use(compression());

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/api/v1', apiRouter);

// Error handler — last
app.use(errorHandler);
```

---

## 2. Routing

### Express Router

`express.Router()` creates a mini-app with its own middleware stack and routes. It mounts cleanly onto the parent app, enabling modular route organization.

```js
// routes/users.js
import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { createUserSchema } from '../schemas/user.js';
import * as userController from '../controllers/users.js';

const router = Router();

// Router-level middleware — applies to all routes in this router
router.use(authenticate);

router.get('/', userController.list);
router.post('/', validate(createUserSchema), userController.create);
router.get('/:id', userController.findById);
router.put('/:id', validate(createUserSchema), userController.update);
router.delete('/:id', userController.remove);

export default router;

// app.js
import usersRouter from './routes/users.js';
app.use('/api/v1/users', usersRouter);
// Requests to /api/v1/users/:id will have req.params.id available
```

### Route Parameters

Route parameters are named URL segments prefixed with `:`. They are available on `req.params`.

```js
// Named params
router.get('/orgs/:orgId/repos/:repoId', (req, res) => {
  const { orgId, repoId } = req.params; // strings, always
  res.json({ orgId, repoId });
});

// Optional param (Express 5 syntax — trailing ?)
router.get('/users/:id?', (req, res) => {
  if (!req.params.id) return res.json({ users: [] });
  res.json({ userId: req.params.id });
});

// Wildcard (Express 5 uses :name* instead of *)
router.get('/files/:filepath*', (req, res) => {
  res.json({ path: req.params.filepath }); // captures full path segments
});

// router.param — middleware that runs whenever a param appears
router.param('id', async (req, res, next, id) => {
  try {
    req.user = await User.findById(id);
    if (!req.user) return res.status(404).json({ error: 'User not found' });
    next();
  } catch (err) {
    next(err);
  }
});

// Now all routes using :id have req.user pre-populated
router.get('/:id', (req, res) => res.json(req.user));
router.delete('/:id', (req, res) => deleteUser(req.user));
```

### Route Handlers and Chaining

Route handlers can be stacked as multiple callbacks or using `.route()` for DRY path definitions.

```js
// Multiple handler callbacks on one route
router.get(
  '/:id',
  authenticate,          // middleware
  authorize('admin'),    // middleware factory
  cacheMiddleware(300),  // cache for 5 min
  userController.findById // final handler
);

// .route() — chain HTTP methods on one path declaration
router
  .route('/:id')
  .get(userController.findById)
  .put(validate(updateSchema), userController.update)
  .patch(validate(patchSchema), userController.patch)
  .delete(authorize('admin'), userController.remove);

// Array of handlers
const authMiddlewares = [authenticate, authorize('editor')];
router.post('/publish', ...authMiddlewares, postController.publish);
```

---

## 3. Express 5 Changes

Express 5 (stable as of late 2024) introduces significant breaking changes. It targets Node.js 18+.

### path-to-regexp v8

Express 5 upgrades from `path-to-regexp` v0.x to v8, which tightens path syntax considerably.

```js
// Express 4 — these patterns were valid
app.get('/users/*', handler);           // wildcard
app.get('/files/(.*)', handler);        // regex group
app.get('/a/:optional?', handler);      // optional param (still works)

// Express 5 equivalents
app.get('/users/:splat*', handler);     // named wildcard required
app.get('/files/:filepath(.*)', handler); // named capture group
app.get('/a/:optional?', handler);      // optional still supported

// Express 5 — stricter character rules
// Parentheses in paths must now be part of named groups
// Unescaped special regex chars cause errors at startup, not at runtime
app.get('/items/{:id}', handler);       // braces now delimit optional segments
```

**Breaking implications:**
- Wildcard `*` routes must become named wildcard params (`:name*`).
- Regex-like patterns in paths require named groups or will throw.
- Path validation errors surface at app startup.

### Removed Deprecated Methods

```js
// Express 4 deprecated — removed in Express 5
app.del('/resource', handler);     // use app.delete()
res.send(status, body);            // use res.status(status).send(body)
res.json(status, body);            // use res.status(status).json(body)
res.sendfile();                    // use res.sendFile()
req.param('name');                 // use req.params.name / req.query.name
res.redirect(url, status);        // argument order flipped; use res.redirect(status, url)

// Express 5 correct forms
app.delete('/resource', handler);
res.status(200).send(body);
res.status(200).json(body);
res.sendFile(path);
res.redirect(301, url);
```

### `req.host` Behavior

In Express 4, `req.hostname` returned the hostname without port. In Express 5, `req.host` (not `req.hostname`) is more nuanced:

```js
// Express 5 — trust proxy matters
app.set('trust proxy', 1); // trust first hop (load balancer)

app.use((req, res, next) => {
  // req.hostname — still strips port, reads X-Forwarded-Host when trust proxy set
  console.log(req.hostname); // 'example.com'

  // req.host in Express 5 preserves port number if present in Host header
  // e.g., Host: example.com:3000 → req.host = 'example.com:3000'
  // Use req.hostname for just the host name (no port)
  next();
});
```

### Promise Rejection Handling

The most impactful Express 5 change for async code: rejected promises and thrown errors in route handlers are automatically forwarded to `next(err)`.

```js
// Express 4 — required explicit try/catch or wrapper
app.get('/users/:id', async (req, res, next) => {
  try {
    const user = await User.findById(req.params.id);
    res.json(user);
  } catch (err) {
    next(err); // manual forwarding required
  }
});

// Express 5 — automatic async error forwarding
app.get('/users/:id', async (req, res) => {
  const user = await User.findById(req.params.id); // rejection caught automatically
  if (!user) throw Object.assign(new Error('Not found'), { status: 404 });
  res.json(user);
});

// Thrown errors in sync handlers also forwarded automatically in Express 5
app.get('/risky', (req, res) => {
  throw new Error('Sync error'); // forwarded to error middleware
});
```

This eliminates the need for `express-async-errors` or `asyncHandler` wrapper patterns that were required in Express 4.

### Bun and Deno Compatibility

Express 5 is compatible with Bun (v1.0+) and Deno (via `npm:` specifier) without modification:

```js
// Bun — bun run server.js
import express from 'express';
const app = express();
app.get('/', (req, res) => res.send('Running on Bun'));
app.listen(3000);

// Deno — deno run --allow-net --allow-env server.ts
import express from 'npm:express@5';
const app = express();
app.get('/', (req: any, res: any) => res.send('Running on Deno'));
app.listen(3000);
```

The core compatibility relies on Express's use of Node.js built-in `http` module, which both runtimes implement.

---

## 4. Request and Response API

### `req.params`, `req.query`, `req.body`

```js
// Route: GET /products/:category/items/:id?color=red&size=L
app.get('/products/:category/items/:id', (req, res) => {
  // req.params — parsed URL segments, always strings
  const { category, id } = req.params;
  // { category: 'shirts', id: '42' }

  // req.query — parsed query string, strings or arrays/objects
  const { color, size } = req.query;
  // { color: 'red', size: 'L' }

  // req.body — parsed request body (requires body-parsing middleware)
  // Available after express.json() or express.urlencoded()
  const { name, price } = req.body;

  // Type coercion is the caller's responsibility
  const numericId = parseInt(id, 10);

  res.json({ category, id: numericId, color, size });
});

// req.query edge cases
// ?tags[]=a&tags[]=b → req.query.tags = ['a', 'b']
// ?filter[name]=foo → req.query.filter = { name: 'foo' }
// ?sort=asc&sort=desc → req.query.sort = ['asc', 'desc']

// Other useful req properties
app.use((req, res, next) => {
  req.ip;           // client IP (respects trust proxy)
  req.ips;          // array when trust proxy set
  req.method;       // 'GET', 'POST', etc.
  req.path;         // pathname only, no query string
  req.hostname;     // host without port
  req.protocol;     // 'http' or 'https'
  req.secure;       // true if HTTPS
  req.get('Authorization'); // read header
  req.is('application/json'); // check Content-Type
  next();
});
```

### `res.json`, `res.status`, `res.send`, `res.redirect`

```js
app.get('/demo', (req, res) => {
  // res.json — sets Content-Type: application/json, serializes body
  res.json({ success: true, data: [] });

  // res.status — sets status code, chainable
  res.status(201).json({ id: 'new-id' });

  // res.send — sends string/Buffer/object; infers Content-Type
  res.send('<h1>Hello</h1>');           // text/html
  res.send(Buffer.from('binary'));      // application/octet-stream
  res.send({ key: 'value' });           // application/json (same as res.json)

  // res.redirect — default 302, supports 301, 307, 308
  res.redirect('/new-path');
  res.redirect(301, 'https://new.example.com');
  res.redirect('back');                 // redirect to Referer header

  // res.sendFile — serve a file
  res.sendFile('/absolute/path/to/file.pdf');
  res.sendFile('report.pdf', { root: __dirname });

  // res.download — force download with Content-Disposition
  res.download('/path/to/file.pdf', 'report.pdf');

  // res.set / res.get — manipulate response headers
  res.set('X-Request-Id', req.id);
  res.set({ 'Cache-Control': 'no-store', 'Pragma': 'no-cache' });

  // res.cookie / res.clearCookie
  res.cookie('session', token, {
    httpOnly: true,
    secure: true,
    sameSite: 'strict',
    maxAge: 7 * 24 * 60 * 60 * 1000,
  });

  // res.locals — data scoped to this request/response cycle
  res.locals.user = req.user;
  // Accessible in templates as `user`
});
```

---

## 5. Template Engines

Express's template engine contract: a view engine is a function `(filePath, options, callback)`.

```js
app.set('view engine', 'pug');      // or 'ejs', 'hbs'
app.set('views', './src/views');    // directory for templates
```

### Pug

```js
// package: pug
app.set('view engine', 'pug');

app.get('/home', (req, res) => {
  res.render('home', {
    title: 'Dashboard',
    user: req.user,
    items: ['Alpha', 'Beta', 'Gamma'],
  });
});
```

```pug
//- views/home.pug
extends layout

block content
  h1 Welcome, #{user.name}
  ul
    each item in items
      li= item
```

### EJS

```js
// package: ejs
app.set('view engine', 'ejs');

app.get('/home', (req, res) => {
  res.render('home', { title: 'Dashboard', user: req.user });
});
```

```html
<!-- views/home.ejs -->
<!DOCTYPE html>
<html>
<head><title><%= title %></title></head>
<body>
  <h1>Welcome, <%= user.name %></h1>
  <%- include('partials/nav') %>
</body>
</html>
```

### Handlebars (express-handlebars)

```js
import { engine } from 'express-handlebars';

app.engine('handlebars', engine({
  defaultLayout: 'main',
  layoutsDir: './views/layouts',
  partialsDir: './views/partials',
  helpers: {
    formatDate: (date) => new Date(date).toLocaleDateString(),
    eq: (a, b) => a === b,
  },
}));
app.set('view engine', 'handlebars');
```

```handlebars
<!-- views/home.handlebars -->
<h1>Welcome, {{user.name}}</h1>
{{#if user.isAdmin}}
  <a href="/admin">Admin Panel</a>
{{/if}}
<p>Joined: {{formatDate user.createdAt}}</p>
```

**Production note:** For APIs, skip template engines entirely. For SSR, consider frameworks (Next.js, Remix, Astro) before choosing a raw Express template engine.

---

## 6. Error Handling Patterns

### Centralized Error Class

```ts
// errors/AppError.ts
export class AppError extends Error {
  constructor(
    public message: string,
    public status: number = 500,
    public code?: string,
    public isOperational: boolean = true
  ) {
    super(message);
    Object.setPrototypeOf(this, AppError.prototype);
    Error.captureStackTrace(this, this.constructor);
  }
}

export class NotFoundError extends AppError {
  constructor(resource = 'Resource') {
    super(`${resource} not found`, 404, 'NOT_FOUND');
  }
}

export class ValidationError extends AppError {
  constructor(public fields: Record<string, string>) {
    super('Validation failed', 422, 'VALIDATION_FAILED');
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized') {
    super(message, 401, 'UNAUTHORIZED');
  }
}
```

### Error Handler Middleware

```ts
// middleware/errorHandler.ts
import { Request, Response, NextFunction } from 'express';
import { AppError } from '../errors/AppError.js';

export function errorHandler(
  err: unknown,
  req: Request,
  res: Response,
  next: NextFunction
): void {
  // Already sent a response
  if (res.headersSent) {
    next(err);
    return;
  }

  if (err instanceof AppError && err.isOperational) {
    res.status(err.status).json({
      error: {
        message: err.message,
        code: err.code,
        ...(err instanceof ValidationError && { fields: err.fields }),
      },
    });
    return;
  }

  // Unexpected / programming errors
  console.error('Unhandled error:', err);
  res.status(500).json({
    error: {
      message: 'Internal server error',
      code: 'INTERNAL_ERROR',
      ...(process.env.NODE_ENV === 'development' && {
        detail: err instanceof Error ? err.message : String(err),
      }),
    },
  });
}
```

### 404 Handler

```ts
// middleware/notFound.ts
import { Request, Response } from 'express';
import { NotFoundError } from '../errors/AppError.js';

// Register before errorHandler but after all routes
export function notFoundHandler(req: Request, res: Response): void {
  throw new NotFoundError(`Route ${req.method} ${req.path}`);
}
```

### Registration Order

```ts
// app.ts — the correct order
app.use(helmet());
app.use(cors());
app.use(express.json());

app.use('/api/v1/users', usersRouter);
app.use('/api/v1/posts', postsRouter);

// After all routes
app.use(notFoundHandler);    // catches unmatched routes
app.use(errorHandler);       // handles all errors
```

---

## 7. Static Files

```js
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Basic static file serving
app.use(express.static(path.join(__dirname, 'public')));

// With options
app.use('/assets', express.static(path.join(__dirname, 'public'), {
  maxAge: '1d',              // Cache-Control: max-age=86400
  etag: true,               // ETag header for conditional GETs
  lastModified: true,
  index: 'index.html',      // directory index
  dotfiles: 'ignore',       // 'allow' | 'deny' | 'ignore'
  fallthrough: true,        // pass to next() if file not found
}));

// SPA fallback — serve index.html for unmatched routes
app.use('/app', express.static(path.join(__dirname, 'dist')));
app.get('/app/*', (req, res) => {
  res.sendFile(path.join(__dirname, 'dist', 'index.html'));
});
```

**Production note:** For high-traffic deployments, offload static file serving to Nginx or a CDN. Express's static middleware is not optimized for heavy throughput.

---

## 8. CORS

```ts
import cors, { CorsOptions } from 'cors';

const allowedOrigins = ['https://app.example.com', 'https://admin.example.com'];

const corsOptions: CorsOptions = {
  origin: (origin, callback) => {
    // Allow requests with no origin (curl, Postman)
    if (!origin) return callback(null, true);
    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error(`Origin ${origin} not allowed by CORS`));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-ID'],
  credentials: true,         // allow cookies
  maxAge: 86400,             // preflight cache: 24h
};

// Apply to all routes
app.use(cors(corsOptions));

// Or per-route (e.g., public endpoint with open CORS)
app.get('/api/public', cors(), publicHandler);

// Explicit OPTIONS handling (some load balancers need this)
app.options('*', cors(corsOptions));
```

---

## 9. Security with Helmet

Helmet sets various HTTP headers to mitigate common web vulnerabilities.

```ts
import helmet from 'helmet';

// Sensible defaults — recommended starting point
app.use(helmet());

// Custom configuration
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", 'cdn.example.com'],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", 'data:', 'https:'],
        connectSrc: ["'self'", 'https://api.example.com'],
        upgradeInsecureRequests: [],
      },
    },
    hsts: {
      maxAge: 31536000,          // 1 year
      includeSubDomains: true,
      preload: true,
    },
    referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
    crossOriginEmbedderPolicy: false, // disable if embedding third-party content
    crossOriginOpenerPolicy: { policy: 'same-origin' },
  })
);

// Helmet headers set by default:
// X-DNS-Prefetch-Control: off
// X-Frame-Options: SAMEORIGIN
// X-Content-Type-Options: nosniff
// X-XSS-Protection: 0 (disabled — modern browsers handle this)
// Strict-Transport-Security (HSTS)
// Content-Security-Policy
// Referrer-Policy
// Cross-Origin-* headers
```

**Additional security middleware to consider:**
- `express-rate-limit` — prevent brute-force
- `express-mongo-sanitize` — prevent NoSQL injection
- `hpp` — HTTP Parameter Pollution protection
- `express-validator` / `zod` — input validation

---

## 10. Body Parsing

Express 4.16+ ships with `express.json()` and `express.urlencoded()` built in (wrapping `body-parser`).

```ts
// JSON bodies
app.use(express.json({
  limit: '10mb',
  strict: true,      // only accept arrays/objects at top level
  type: ['application/json', 'application/vnd.api+json'],
  reviver: (key, value) => {
    // Custom JSON deserialization (e.g., date strings to Date objects)
    if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(value)) {
      return new Date(value);
    }
    return value;
  },
}));

// URL-encoded form bodies
app.use(express.urlencoded({
  extended: true,    // use qs library (nested objects); false = querystring
  limit: '1mb',
}));

// Raw buffer (for webhooks with signature verification)
app.use('/webhooks', express.raw({ type: 'application/json' }));

// Text bodies
app.use('/text-endpoint', express.text({ type: 'text/plain' }));

// Multipart (file uploads) — not built-in, use multer
import multer from 'multer';

const upload = multer({
  storage: multer.diskStorage({
    destination: './uploads',
    filename: (req, file, cb) => cb(null, `${Date.now()}-${file.originalname}`),
  }),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp'];
    cb(null, allowed.includes(file.mimetype));
  },
});

app.post('/upload', upload.single('avatar'), (req, res) => {
  res.json({ file: req.file });
});
```

---

## 11. Project Structure Patterns

### Feature-Sliced (Recommended for Medium-Large Apps)

```
src/
├── app.ts                  # Express app factory (no listen())
├── server.ts               # Entry: creates app, calls app.listen()
├── config/
│   ├── index.ts            # Env validation (zod/envalid)
│   └── database.ts
├── features/
│   ├── users/
│   │   ├── users.router.ts
│   │   ├── users.controller.ts
│   │   ├── users.service.ts
│   │   ├── users.repository.ts
│   │   ├── users.schema.ts   # zod schemas
│   │   └── users.test.ts
│   └── posts/
│       └── ...
├── middleware/
│   ├── authenticate.ts
│   ├── authorize.ts
│   ├── validate.ts
│   ├── errorHandler.ts
│   └── notFound.ts
├── errors/
│   └── AppError.ts
├── shared/
│   ├── logger.ts           # pino/winston
│   └── database.ts
└── types/
    └── express.d.ts        # augment Request/Response
```

### App Factory Pattern

Separating app creation from server startup is essential for testability:

```ts
// app.ts
import express, { Application } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { usersRouter } from './features/users/users.router.js';
import { postsRouter } from './features/posts/posts.router.js';
import { notFoundHandler } from './middleware/notFound.js';
import { errorHandler } from './middleware/errorHandler.js';

export function createApp(): Application {
  const app = express();

  app.use(helmet());
  app.use(cors());
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  app.use('/api/v1/users', usersRouter);
  app.use('/api/v1/posts', postsRouter);

  app.get('/health', (req, res) => res.json({ status: 'ok' }));

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

// server.ts
import { createApp } from './app.js';
import { config } from './config/index.js';

const app = createApp();
app.listen(config.PORT, () => {
  console.log(`Server running on port ${config.PORT}`);
});
```

### Config with Validation

```ts
// config/index.ts
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  ALLOWED_ORIGINS: z.string().transform((v) => v.split(',')),
});

const parsed = envSchema.safeParse(process.env);
if (!parsed.success) {
  console.error('Invalid environment:', parsed.error.flatten());
  process.exit(1);
}

export const config = parsed.data;
```

---

## 12. Testing with Supertest

Supertest drives your Express app over HTTP without binding to a port, making tests fast and isolated.

```ts
// features/users/users.test.ts
import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { db } from '../../shared/database.js';

const app = createApp();

beforeAll(async () => {
  await db.connect(process.env.TEST_DATABASE_URL);
});

afterAll(async () => {
  await db.disconnect();
});

beforeEach(async () => {
  await db.clearCollections(['users']);
});

describe('GET /api/v1/users', () => {
  it('returns empty array when no users exist', async () => {
    const res = await request(app)
      .get('/api/v1/users')
      .set('Authorization', `Bearer ${testToken}`)
      .expect(200)
      .expect('Content-Type', /json/);

    expect(res.body).toEqual({ data: [], total: 0 });
  });

  it('paginates results', async () => {
    await seedUsers(15);
    const res = await request(app)
      .get('/api/v1/users?page=2&limit=10')
      .set('Authorization', `Bearer ${testToken}`)
      .expect(200);

    expect(res.body.data).toHaveLength(5);
    expect(res.body.total).toBe(15);
  });
});

describe('POST /api/v1/users', () => {
  it('creates a user with valid data', async () => {
    const payload = { name: 'Alice', email: 'alice@example.com', password: 'pass1234' };

    const res = await request(app)
      .post('/api/v1/users')
      .send(payload)
      .expect(201);

    expect(res.body).toMatchObject({ name: 'Alice', email: 'alice@example.com' });
    expect(res.body).not.toHaveProperty('password');
  });

  it('returns 422 for invalid email', async () => {
    const res = await request(app)
      .post('/api/v1/users')
      .send({ name: 'Bob', email: 'not-an-email', password: 'pass1234' })
      .expect(422);

    expect(res.body.error.code).toBe('VALIDATION_FAILED');
  });
});

// Testing with mocked services
import { vi } from 'vitest';
import * as userService from './users.service.js';

it('handles service errors gracefully', async () => {
  vi.spyOn(userService, 'findById').mockRejectedValueOnce(new Error('DB connection lost'));

  const res = await request(app)
    .get('/api/v1/users/123')
    .set('Authorization', `Bearer ${testToken}`)
    .expect(500);

  expect(res.body.error.code).toBe('INTERNAL_ERROR');
});
```

### Jest Configuration (alternative to Vitest)

```ts
// jest.config.ts
export default {
  preset: 'ts-jest/presets/default-esm',
  testEnvironment: 'node',
  extensionsToTreatAsEsm: ['.ts'],
  moduleNameMapper: { '^(\\.{1,2}/.*)\\.js$': '$1' },
  setupFilesAfterFramework: ['./test/setup.ts'],
  coverageProvider: 'v8',
  collectCoverageFrom: ['src/**/*.ts', '!src/**/*.d.ts'],
};
```

---

## 13. Performance

### Cluster Mode

Node.js is single-threaded; cluster mode spawns one worker per CPU core.

```ts
// cluster.ts
import cluster from 'cluster';
import { cpus } from 'os';
import { createApp } from './app.js';
import { config } from './config/index.js';

if (cluster.isPrimary) {
  const numCPUs = cpus().length;
  console.log(`Primary ${process.pid}: forking ${numCPUs} workers`);

  for (let i = 0; i < numCPUs; i++) {
    cluster.fork();
  }

  cluster.on('exit', (worker, code, signal) => {
    console.log(`Worker ${worker.process.pid} died (${signal ?? code}). Respawning...`);
    cluster.fork();
  });
} else {
  const app = createApp();
  app.listen(config.PORT, () => {
    console.log(`Worker ${process.pid} listening on port ${config.PORT}`);
  });
}
```

**Production alternative:** Use PM2 with cluster mode (`pm2 start server.js -i max`) — handles zero-downtime restarts, monitoring, and log aggregation without managing cluster logic manually.

### Compression

```ts
import compression from 'compression';

app.use(compression({
  level: 6,          // zlib level 1-9; 6 is the sweet spot
  threshold: 1024,   // don't compress responses < 1KB
  filter: (req, res) => {
    if (req.headers['x-no-compression']) return false;
    return compression.filter(req, res);
  },
}));
```

**Note:** In production behind Nginx, offload compression to Nginx and skip this middleware to avoid double-compressing.

### Reverse Proxy Configuration

When behind Nginx or a load balancer:

```ts
// Trust the first proxy hop — enables correct req.ip, req.protocol, req.hostname
app.set('trust proxy', 1);

// For multiple known proxies:
app.set('trust proxy', ['loopback', '10.0.0.0/8']);

// Disable for direct-to-internet deployments (default)
app.set('trust proxy', false);
```

```nginx
# nginx.conf — recommended Express config
upstream express_app {
  server 127.0.0.1:3000;
  keepalive 64;
}

server {
  listen 443 ssl http2;
  server_name api.example.com;

  # Compression at Nginx level
  gzip on;
  gzip_types application/json text/plain;

  # Static files served directly
  location /assets/ {
    root /var/www/public;
    expires 1y;
    add_header Cache-Control "public, immutable";
  }

  location / {
    proxy_pass http://express_app;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_cache_bypass $http_upgrade;
    proxy_read_timeout 60s;
  }
}
```

### Additional Performance Considerations

```ts
// Disable x-powered-by header (minor: removes Express fingerprinting)
app.disable('x-powered-by'); // or use helmet() which does this too

// ETag support (automatic conditional GET support)
app.set('etag', 'strong'); // default; 'weak' or false

// Keep-alive for persistent connections (Node.js default varies)
import http from 'http';
const server = http.createServer(app);
server.keepAliveTimeout = 65000;       // must exceed load balancer timeout
server.headersTimeout = 66000;         // must exceed keepAliveTimeout
```

---

## 14. TypeScript Setup

### Installation

```bash
npm install express
npm install -D typescript @types/express @types/node tsx
npx tsc --init
```

### `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "sourceMap": true,
    "declaration": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

### Augmenting Request and Response

```ts
// src/types/express.d.ts
import { User } from '../features/users/users.model.js';

declare global {
  namespace Express {
    interface Request {
      user?: User;
      requestId: string;
      startTime: number;
    }
    interface Response {
      // Custom response methods if needed
    }
    interface Locals {
      correlationId: string;
    }
  }
}

export {};
```

### Typed Route Handlers

```ts
// Typed request handler with generics
import { Request, Response, NextFunction, RequestHandler } from 'express';

// Strongly-typed handler
type AsyncHandler<
  P = Record<string, string>,
  ResBody = unknown,
  ReqBody = unknown,
  ReqQuery = Record<string, string>,
> = (
  req: Request<P, ResBody, ReqBody, ReqQuery>,
  res: Response<ResBody>,
  next: NextFunction
) => Promise<void>;

// Usage
interface UserParams { id: string }
interface UserBody { name: string; email: string }

const getUser: AsyncHandler<UserParams> = async (req, res) => {
  const user = await userService.findById(req.params.id);
  res.json(user);
};

// Middleware factory with typing
function authorize(role: 'admin' | 'editor' | 'viewer'): RequestHandler {
  return (req, res, next) => {
    if (!req.user?.roles.includes(role)) {
      return next(new UnauthorizedError('Insufficient permissions'));
    }
    next();
  };
}
```

### `package.json` Scripts

```json
{
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js",
    "test": "vitest",
    "test:coverage": "vitest run --coverage",
    "lint": "eslint src --ext .ts",
    "typecheck": "tsc --noEmit"
  }
}
```

---

## 15. Express vs Fastify vs Koa

### Summary Table

| Dimension            | Express 5              | Fastify 4/5            | Koa 2                  |
|----------------------|------------------------|------------------------|------------------------|
| **Requests/sec**     | ~45k (baseline)        | ~75k (+60%)            | ~50k (+10%)            |
| **Middleware model** | `(req, res, next)`     | Hooks + plugins        | `(ctx, next)` async    |
| **Async errors**     | Auto (v5)              | Native                 | Native                 |
| **Schema/validation**| Manual (zod, joi)      | Built-in (ajv JSON Schema)| Manual               |
| **TypeScript**       | Good (via @types)      | Excellent (generics)   | Good (via @types)      |
| **Ecosystem size**   | Largest                | Large, growing         | Moderate               |
| **Learning curve**   | Lowest                 | Moderate               | Low                    |
| **Plugin system**    | None (middleware only) | Formal (encapsulated)  | None                   |
| **Body parsing**     | Built-in               | Built-in               | External (koa-body)    |
| **OpenAPI**          | Manual or libs         | `@fastify/swagger`     | Manual or libs         |

### Express 5 — When to Choose

- Existing Express 4 codebases migrating forward.
- Teams with strong existing Express expertise.
- Projects that value maximum ecosystem compatibility.
- Applications where raw throughput is not the primary constraint.
- When a minimal core with selective middleware is preferred.

```ts
// Express 5 strength: simplicity, familiarity
app.get('/users/:id', async (req, res) => {
  const user = await userService.findById(req.params.id);
  res.json(user); // async errors auto-forwarded
});
```

### Fastify — When to Choose

- High-throughput APIs (microservices, real-time data endpoints).
- Projects that benefit from built-in JSON schema validation and serialization.
- Teams that want TypeScript generics throughout the request lifecycle.
- Projects where OpenAPI documentation is a first-class requirement.

```ts
// Fastify: schema-validated, serialized handler
fastify.get<{
  Params: { id: string };
  Reply: { id: string; name: string };
}>(
  '/users/:id',
  {
    schema: {
      params: { type: 'object', properties: { id: { type: 'string' } } },
      response: {
        200: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            name: { type: 'string' },
          },
        },
      },
    },
  },
  async (request, reply) => {
    return userService.findById(request.params.id);
  }
);
```

### Koa — When to Choose

- Small teams that prefer a minimal, composable core without Express's legacy baggage.
- Projects where `async/await` middleware composition (`ctx, next`) feels more natural.
- When building a custom framework on top of a minimal base.

```ts
// Koa: context-based middleware
app.use(async (ctx, next) => {
  const start = Date.now();
  await next();
  ctx.set('X-Response-Time', `${Date.now() - start}ms`);
});

app.use(async (ctx) => {
  const user = await userService.findById(ctx.params.id);
  ctx.body = user; // sets res body and 200 status
});
```

### Migration Path: Express 4 → Express 5

```bash
npm install express@5
```

**Checklist for migration:**
1. Replace `app.del()` with `app.delete()`.
2. Fix `res.send(status, body)` → `res.status(status).send(body)`.
3. Update wildcard routes: `*` → `:name*` or specific named params.
4. Remove `express-async-errors` package — no longer needed.
5. Remove manual `try/catch` wrapping in async route handlers.
6. Audit `req.param()` usages → replace with `req.params`, `req.query`, or `req.body`.
7. Fix `res.redirect(url, status)` → `res.redirect(status, url)`.
8. Audit any regex or parenthesis patterns in route paths.
9. Test all routes with updated `path-to-regexp` — startup-time errors will surface any invalid paths.

---

## Key Takeaways for Senior Developers

- **Express 5's async error forwarding** is the single biggest quality-of-life improvement. Remove `asyncHandler` wrappers and bare `try/catch` blocks wrapping `next(err)`.
- **path-to-regexp v8 strictness** will break wildcard routes silently in Express 4 but loudly (at startup) in Express 5 — fix before upgrading.
- **App factory pattern** (`createApp()`) is non-negotiable for testability with Supertest.
- **Middleware ordering** is semantic; security headers (helmet) and CORS must precede body parsing, which must precede routes.
- **4-argument error handlers** are the only error boundary in Express — always register one as the last `app.use` call.
- **`trust proxy`** must be configured correctly when behind a load balancer or reverse proxy — it affects `req.ip`, `req.hostname`, and `req.protocol`.
- For **high-throughput** scenarios, measure before optimizing; cluster mode or PM2 horizontal scaling often provides more benefit than switching frameworks.
- **TypeScript augmentation** of `Express.Request` (`src/types/express.d.ts`) enables type-safe request extensions (e.g., `req.user`) without casting throughout the codebase.
