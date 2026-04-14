# Express.js Architecture Reference

## Middleware Internals

### How the Middleware Chain Works

Express maintains an ordered stack of middleware layers. When a request arrives, Express iterates through the stack sequentially. Each middleware is a function with the signature `(req, res, next)`. The middleware must either:

1. Terminate the response (`res.json()`, `res.send()`, `res.end()`, etc.)
2. Call `next()` to pass control to the next middleware
3. Call `next(err)` to skip to the next error-handling middleware

Failing to do any of these causes the request to hang indefinitely.

```js
// Registration order IS execution order
app.use((req, res, next) => {
  req.startTime = Date.now();
  next(); // pass downstream
});

app.get('/users', (req, res) => {
  res.json({ elapsed: Date.now() - req.startTime });
  // Response terminated -- no next() needed
});

// Never reached for GET /users because the route above terminated
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});
```

### Path-Scoped Middleware

`app.use('/prefix', fn)` only runs for requests whose URL starts with `/prefix`. The prefix is stripped from `req.url` before passing to the handler:

```js
app.use('/api', (req, res, next) => {
  // For request to /api/users, req.url is '/users' here
  // For request to /api/users/123, req.url is '/users/123'
  next();
});
```

### Error Middleware: The 4-Argument Signature

Error-handling middleware is identified by Express through `function.length === 4`. The signature is `(err, req, res, next)`. Express skips error handlers during normal flow and only invokes them when `next(err)` is called with a truthy argument.

```js
// Normal middleware -- 3 params
app.use((req, res, next) => {
  next(new Error('Something broke')); // triggers error handlers
});

// Error handler -- MUST have exactly 4 params
app.use((err, req, res, next) => {
  console.error(err.stack);
  const status = err.status ?? err.statusCode ?? 500;
  res.status(status).json({
    error: err.message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
});
```

Multiple error handlers can be chained. Call `next(err)` inside an error handler to delegate to the next one.

**Important:** Arrow functions and destructured parameters can break the 4-argument detection. Always use standard function parameters.

### Recommended Middleware Order

```js
app.use(requestId);                          // 1. Attach X-Request-ID first
app.use(helmet());                           // 2. Security headers
app.use(cors(corsOptions));                  // 3. CORS -- before routes, after helmet
app.use(rateLimit(limiterOpts));             // 4. Rate limiting -- before body parsing
app.use(morgan('combined', { stream }));     // 5. Request logging
app.use(compression());                      // 6. Compression -- before routes, after logging
app.use(express.json({ limit: '10mb' }));   // 7. JSON body parsing
app.use(express.urlencoded({ extended: true })); // 8. URL-encoded body parsing
app.use(cookieParser(secret));               // 9. Cookie parsing
app.use(session(sessionOptions));            // 10. Session (if needed)
app.use(passport.initialize());              // 11. Passport init (if needed)
app.use(passport.session());                 // 12. Passport session (if needed)

app.use('/api/v1', v1Router);               // 13. Routes
app.use('/api/v2', v2Router);
app.get('/health', healthHandler);

app.use(notFoundHandler);                    // 14. 404 -- after all routes
app.use(errorHandler);                       // 15. Error handler -- always last
```

---

## Routing Engine

### Express Router

`express.Router()` creates a mini-app with its own middleware stack and routes. Routers mount onto the parent app:

```js
// routes/users.js
import { Router } from 'express';

const router = Router();

// Router-level middleware
router.use(authenticate);

router.get('/', userController.list);
router.post('/', validate(createUserSchema), userController.create);
router.get('/:id', userController.findById);
router.put('/:id', validate(updateSchema), userController.update);
router.delete('/:id', authorize('admin'), userController.remove);

export default router;

// app.js
app.use('/api/v1/users', usersRouter);
```

### Route Parameters

```js
// Named params -- always strings
router.get('/orgs/:orgId/repos/:repoId', (req, res) => {
  const { orgId, repoId } = req.params;
  res.json({ orgId, repoId });
});

// Optional param (Express 5 syntax)
router.get('/users/:id?', (req, res) => {
  if (!req.params.id) return res.json({ users: [] });
  res.json({ userId: req.params.id });
});

// Wildcard (Express 5 uses :name* instead of bare *)
router.get('/files/:filepath*', (req, res) => {
  res.json({ path: req.params.filepath });
});

// router.param -- middleware that runs for a specific param
router.param('id', async (req, res, next, id) => {
  try {
    req.user = await User.findById(id);
    if (!req.user) return res.status(404).json({ error: 'Not found' });
    next();
  } catch (err) {
    next(err);
  }
});
```

### Route Chaining

```js
// Multiple handler callbacks on one route
router.get('/:id', authenticate, authorize('admin'), cacheMiddleware(300), controller.findById);

// .route() -- chain HTTP methods on one path
router.route('/:id')
  .get(controller.findById)
  .put(validate(updateSchema), controller.update)
  .patch(validate(patchSchema), controller.patch)
  .delete(authorize('admin'), controller.remove);
```

---

## Request/Response Lifecycle

### Request Object

```js
// req.params -- parsed URL segments (always strings)
// Route: GET /products/:category/items/:id
req.params  // { category: 'shirts', id: '42' }

// req.query -- parsed query string
// ?color=red&size=L
req.query   // { color: 'red', size: 'L' }
// ?tags[]=a&tags[]=b
req.query   // { tags: ['a', 'b'] }

// req.body -- requires body-parsing middleware
// POST with JSON body { "name": "Alice" }
req.body    // { name: 'Alice' }

// Other properties
req.ip           // client IP (respects trust proxy)
req.ips          // array when trust proxy set
req.method       // 'GET', 'POST', etc.
req.path         // pathname only, no query string
req.hostname     // host without port
req.protocol     // 'http' or 'https'
req.secure       // true if HTTPS
req.get('Authorization')    // read header
req.is('application/json')  // check Content-Type
```

### Response Object

```js
// res.json -- sets Content-Type: application/json
res.json({ success: true, data: [] });

// res.status -- sets status code, chainable
res.status(201).json({ id: 'new-id' });

// res.send -- infers Content-Type from argument type
res.send('<h1>Hello</h1>');           // text/html
res.send(Buffer.from('binary'));      // application/octet-stream
res.send({ key: 'value' });          // application/json

// res.redirect -- default 302
res.redirect('/new-path');
res.redirect(301, 'https://new.example.com');
res.redirect('back');                 // redirect to Referer

// res.sendFile -- serve a file
res.sendFile('/absolute/path/to/file.pdf');
res.sendFile('report.pdf', { root: __dirname });

// res.download -- force download with Content-Disposition
res.download('/path/to/file.pdf', 'report.pdf');

// res.set -- manipulate response headers
res.set('X-Request-Id', req.id);
res.set({ 'Cache-Control': 'no-store', 'Pragma': 'no-cache' });

// res.cookie / res.clearCookie
res.cookie('session', token, {
  httpOnly: true, secure: true, sameSite: 'strict',
  maxAge: 7 * 24 * 60 * 60 * 1000,
});

// res.locals -- data scoped to this request/response cycle
res.locals.user = req.user;
```

---

## Express 5 Breaking Changes

### path-to-regexp v8

Express 5 upgrades from path-to-regexp v0.x to v8. This tightens path syntax considerably:

```js
// Express 4 -- these patterns were valid
app.get('/users/*', handler);             // bare wildcard
app.get('/files/(.*)', handler);          // unnamed regex group

// Express 5 equivalents
app.get('/users/:splat*', handler);       // named wildcard required
app.get('/files/:filepath(.*)', handler); // named capture group
```

**Breaking implications:**
- Wildcard `*` routes must become named wildcard params (`:name*`)
- Regex-like patterns in paths require named groups
- Path validation errors surface at app startup (not at runtime)
- Unescaped special regex chars in paths cause startup errors

### Removed Deprecated Methods

```js
// Express 4 deprecated -- removed in Express 5
app.del('/resource', handler);         // use app.delete()
res.send(status, body);                // use res.status(status).send(body)
res.json(status, body);                // use res.status(status).json(body)
res.sendfile();                        // use res.sendFile()
req.param('name');                     // use req.params.name / req.query.name
res.redirect(url, status);            // use res.redirect(status, url)
```

### Promise Rejection Handling

The most impactful Express 5 change: rejected promises and thrown errors in route handlers are automatically forwarded to `next(err)`.

```js
// Express 4 -- required explicit try/catch
app.get('/users/:id', async (req, res, next) => {
  try {
    const user = await User.findById(req.params.id);
    res.json(user);
  } catch (err) {
    next(err); // manual forwarding required
  }
});

// Express 5 -- automatic async error forwarding
app.get('/users/:id', async (req, res) => {
  const user = await User.findById(req.params.id); // rejection caught automatically
  if (!user) throw Object.assign(new Error('Not found'), { status: 404 });
  res.json(user);
});
```

This eliminates the need for `express-async-errors` or `asyncHandler` wrapper patterns.

### req.host Behavior

In Express 5, `req.host` preserves the port number if present in the Host header. Use `req.hostname` for just the hostname without port:

```js
app.set('trust proxy', 1);
// Host: example.com:3000
// req.host     = 'example.com:3000'
// req.hostname = 'example.com'
```

### Bun and Deno Compatibility

Express 5 works with Bun and Deno without modification:

```js
// Bun -- bun run server.js
import express from 'express';
const app = express();
app.listen(3000);

// Deno -- deno run --allow-net server.ts
import express from 'npm:express@5';
const app = express();
app.listen(3000);
```

---

## Error Handling Patterns

### Centralized Error Class Hierarchy

```ts
class AppError extends Error {
  constructor(
    public message: string,
    public status: number = 500,
    public code?: string,
    public isOperational: boolean = true,
  ) {
    super(message);
    Object.setPrototypeOf(this, AppError.prototype);
    Error.captureStackTrace(this, this.constructor);
  }
}

class NotFoundError extends AppError {
  constructor(resource = 'Resource') {
    super(`${resource} not found`, 404, 'NOT_FOUND');
  }
}

class ValidationError extends AppError {
  constructor(public fields: Record<string, string>) {
    super('Validation failed', 422, 'VALIDATION_FAILED');
  }
}

class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized') {
    super(message, 401, 'UNAUTHORIZED');
  }
}
```

### Error Handler Middleware

```ts
export function errorHandler(err: unknown, req: Request, res: Response, next: NextFunction): void {
  if (res.headersSent) {
    next(err);
    return;
  }

  if (err instanceof AppError && err.isOperational) {
    res.status(err.status).json({
      error: { message: err.message, code: err.code },
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
// Register after all routes, before error handler
export function notFoundHandler(req: Request, res: Response): void {
  throw new NotFoundError(`Route ${req.method} ${req.path}`);
}
```

### Registration Order

```ts
app.use('/api/v1/users', usersRouter);
app.use('/api/v1/posts', postsRouter);
app.use(notFoundHandler);    // catches unmatched routes
app.use(errorHandler);       // handles all errors -- always last
```

---

## Template Engines

Express's template engine contract: a view engine is a function `(filePath, options, callback)`.

```js
app.set('view engine', 'pug');      // or 'ejs', 'hbs'
app.set('views', './src/views');
```

### Pug

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

```html
<!-- views/home.ejs -->
<h1>Welcome, <%= user.name %></h1>
<%- include('partials/nav') %>
```

### Handlebars

```js
import { engine } from 'express-handlebars';
app.engine('handlebars', engine({
  defaultLayout: 'main',
  helpers: { formatDate: (date) => new Date(date).toLocaleDateString() },
}));
app.set('view engine', 'handlebars');
```

**Production note:** For APIs, skip template engines. For SSR, consider Next.js, Remix, or Astro before raw Express templating.

---

## Static Files

```js
// Basic
app.use(express.static(path.join(__dirname, 'public')));

// With options
app.use('/assets', express.static(path.join(__dirname, 'public'), {
  maxAge: '1d',          // Cache-Control: max-age=86400
  etag: true,
  dotfiles: 'ignore',
  fallthrough: true,
}));

// SPA fallback
app.use('/app', express.static(path.join(__dirname, 'dist')));
app.get('/app/*', (req, res) => {
  res.sendFile(path.join(__dirname, 'dist', 'index.html'));
});
```

For high-traffic deployments, offload static file serving to Nginx or a CDN.

---

## Body Parsing

Express 4.16+ ships built-in body parsers:

```ts
// JSON bodies
app.use(express.json({
  limit: '10mb',
  strict: true,      // only accept arrays/objects at top level
  type: ['application/json', 'application/vnd.api+json'],
}));

// URL-encoded form bodies
app.use(express.urlencoded({
  extended: true,    // use qs library for nested objects
  limit: '1mb',
}));

// Raw buffer (for webhook signature verification)
app.use('/webhooks', express.raw({ type: 'application/json' }));

// Text bodies
app.use('/text-endpoint', express.text({ type: 'text/plain' }));
```

Multipart (file uploads) requires `multer`:

```ts
import multer from 'multer';
const upload = multer({
  storage: multer.diskStorage({
    destination: './uploads',
    filename: (req, file, cb) => cb(null, `${Date.now()}-${file.originalname}`),
  }),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    cb(null, ['image/jpeg', 'image/png', 'image/webp'].includes(file.mimetype));
  },
});

app.post('/upload', upload.single('avatar'), (req, res) => {
  res.json({ file: req.file });
});
```

---

## CORS Configuration

```ts
import cors, { CorsOptions } from 'cors';

const allowedOrigins = ['https://app.example.com', 'https://admin.example.com'];

const corsOptions: CorsOptions = {
  origin: (origin, callback) => {
    if (!origin) return callback(null, true); // allow curl/Postman
    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error(`Origin ${origin} not allowed by CORS`));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-ID'],
  credentials: true,
  maxAge: 86400,
};

app.use(cors(corsOptions));

// Per-route CORS override
app.get('/api/public', cors(), publicHandler);
```

---

## Security with Helmet

```ts
import helmet from 'helmet';

app.use(helmet());

// Custom configuration
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", 'cdn.example.com'],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", 'data:', 'https:'],
    },
  },
  hsts: { maxAge: 31536000, includeSubDomains: true, preload: true },
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
}));
```

Headers set by default: `X-DNS-Prefetch-Control`, `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`, `Strict-Transport-Security`, `Content-Security-Policy`, `Referrer-Policy`.

---

## TypeScript Setup

### Installation and Config

```bash
npm install express
npm install -D typescript @types/express @types/node tsx
```

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
    "declaration": true
  },
  "include": ["src/**/*"]
}
```

### Augmenting Request

```ts
// src/types/express.d.ts
declare global {
  namespace Express {
    interface Request {
      user?: User;
      requestId: string;
      startTime: number;
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
type AsyncHandler<
  P = Record<string, string>,
  ResBody = unknown,
  ReqBody = unknown,
> = (req: Request<P, ResBody, ReqBody>, res: Response<ResBody>, next: NextFunction) => Promise<void>;

interface UserParams { id: string }
interface UserBody { name: string; email: string }

const getUser: AsyncHandler<UserParams> = async (req, res) => {
  const user = await userService.findById(req.params.id);
  res.json(user);
};
```

### Package.json Scripts

```json
{
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js",
    "test": "vitest",
    "lint": "eslint src --ext .ts",
    "typecheck": "tsc --noEmit"
  }
}
```

---

## Migration Path: Express 4 to Express 5

```bash
npm install express@5
```

**Migration checklist:**
1. Replace `app.del()` with `app.delete()`
2. Fix `res.send(status, body)` to `res.status(status).send(body)`
3. Update wildcard routes: `*` to `:name*` or specific named params
4. Remove `express-async-errors` package -- no longer needed
5. Remove manual `try/catch` wrapping in async route handlers
6. Replace `req.param()` with `req.params`, `req.query`, or `req.body`
7. Fix `res.redirect(url, status)` to `res.redirect(status, url)`
8. Audit regex or parenthesis patterns in route paths
9. Test all routes -- startup-time errors surface invalid paths

---

## Express vs Fastify vs Koa

| Dimension | Express 5 | Fastify 5 | Koa 2 |
|---|---|---|---|
| Requests/sec | ~45k (baseline) | ~75k (+60%) | ~50k (+10%) |
| Middleware model | `(req, res, next)` | Hooks + plugins | `(ctx, next)` async |
| Async errors | Auto (v5) | Native | Native |
| Schema/validation | Manual (zod, joi) | Built-in (ajv) | Manual |
| TypeScript | Good (via @types) | Excellent (generics) | Good (via @types) |
| Ecosystem | Largest | Large, growing | Moderate |
| Plugin system | None (middleware) | Formal (encapsulated) | None |
| Body parsing | Built-in | Built-in | External |

**Choose Express** for maximum ecosystem compatibility, lowest learning curve, existing codebases.
**Choose Fastify** for throughput-critical APIs, built-in validation, TypeScript-first generics.
**Choose Koa** for minimal async-native core, teams preferring `ctx` over `req/res`.
