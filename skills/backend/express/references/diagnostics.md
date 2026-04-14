# Express.js Diagnostics Reference

## Common Errors and Fixes

### Middleware Ordering Issues

**Symptom:** Route handlers not receiving parsed body, CORS errors on preflight, security headers missing, 404 for valid routes.

**Root cause:** Middleware registered in wrong order.

```js
// WRONG: routes before body parsing
app.use('/api', apiRouter);        // req.body is undefined here
app.use(express.json());           // too late

// CORRECT: body parsing before routes
app.use(express.json());
app.use('/api', apiRouter);        // req.body is populated
```

**Common ordering mistakes:**

| Symptom | Cause | Fix |
|---|---|---|
| `req.body` is `undefined` | Body parser registered after routes | Move `express.json()` before routes |
| CORS preflight fails | CORS middleware after routes or after auth | Move `cors()` before auth middleware |
| Security headers missing | Helmet after routes | Move `helmet()` to first middleware |
| 404 errors not caught | 404 handler before routes | Move 404 handler after all routes |
| Error handler not triggered | Error handler not last, or has wrong signature | Ensure 4-argument signature, register last |

### Error Handler Not Triggering

**Symptom:** Errors cause unhandled crashes instead of returning JSON error responses.

**Cause 1:** Error handler does not have exactly 4 parameters.

```js
// WRONG: 3 params -- Express treats this as normal middleware
app.use((err, req, res) => { ... });

// WRONG: destructured params -- function.length is wrong
app.use(({ message }, req, res, next) => { ... });

// CORRECT: exactly 4 named parameters
app.use((err, req, res, next) => {
  res.status(err.status ?? 500).json({ error: err.message });
});
```

**Cause 2:** Error handler registered before routes.

```js
// WRONG
app.use(errorHandler);
app.use('/api', router);

// CORRECT
app.use('/api', router);
app.use(errorHandler);  // must be last
```

**Cause 3:** (Express 4 only) Async errors not forwarded with `next(err)`.

```js
// Express 4 -- async error lost
app.get('/users/:id', async (req, res) => {
  const user = await User.findById(req.params.id); // rejection unhandled
  res.json(user);
});

// Express 4 fix
app.get('/users/:id', async (req, res, next) => {
  try {
    const user = await User.findById(req.params.id);
    res.json(user);
  } catch (err) {
    next(err);
  }
});

// Express 5 -- automatic, no fix needed
app.get('/users/:id', async (req, res) => {
  const user = await User.findById(req.params.id); // auto-forwarded to error handler
  res.json(user);
});
```

### Unhandled Promise Rejections (Express 4)

**Symptom:** App crashes with `UnhandledPromiseRejectionWarning` or `unhandledRejection`.

**Root cause:** Async route handlers without `try/catch` in Express 4.

**Fixes (from best to worst):**

1. **Upgrade to Express 5** -- automatic async error forwarding
2. **Use `express-async-errors`** -- patches Express 4 to forward rejections

```js
import 'express-async-errors'; // import before routes
```

3. **Wrapper function** -- manually wraps async handlers

```js
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

app.get('/users/:id', asyncHandler(async (req, res) => {
  const user = await User.findById(req.params.id);
  res.json(user);
}));
```

4. **Global safety net** (not a fix, just crash prevention):

```js
process.on('unhandledRejection', (err) => {
  console.error('Unhandled rejection:', err);
  process.exit(1); // crash cleanly rather than running in unknown state
});
```

### CORS Errors

**Symptom:** Browser shows `Access-Control-Allow-Origin` errors. Preflight OPTIONS requests fail with 404 or 500.

**Cause 1:** CORS middleware not registered or registered after routes.

```js
// WRONG
app.use('/api', router);
app.use(cors());

// CORRECT
app.use(cors(corsOptions));
app.use('/api', router);
```

**Cause 2:** Credentials requested but CORS not configured for credentials.

```js
// Frontend sends credentials (cookies)
fetch('/api/data', { credentials: 'include' });

// Backend must enable credentials AND cannot use wildcard origin
app.use(cors({
  origin: 'https://app.example.com', // specific origin, not '*'
  credentials: true,
}));
```

**Cause 3:** Missing preflight handler for custom headers.

```js
app.use(cors({
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Custom-Header'],
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
}));
```

**Cause 4:** Error thrown in CORS origin callback.

```js
// WRONG: throwing in origin callback crashes
origin: (origin, callback) => {
  if (!allowed.includes(origin)) throw new Error('Not allowed');
}

// CORRECT: use callback
origin: (origin, callback) => {
  if (!origin || allowed.includes(origin)) {
    callback(null, true);
  } else {
    callback(new Error('Not allowed by CORS'));
  }
}
```

### Body Parsing Issues

**Symptom:** `req.body` is `undefined`, empty, or has wrong type.

| Symptom | Cause | Fix |
|---|---|---|
| `req.body` is `undefined` | No body parser middleware | Add `app.use(express.json())` |
| `req.body` is empty `{}` | Wrong `Content-Type` header | Client must send `Content-Type: application/json` |
| `req.body` is a string | `express.text()` registered instead of `express.json()` | Use `express.json()` |
| `req.body` is a Buffer | `express.raw()` registered | Use `express.json()` for JSON |
| Large body rejected | Body exceeds default 100kb limit | `express.json({ limit: '10mb' })` |
| Nested objects not parsed | `extended: false` on urlencoded | Use `extended: true` or switch to JSON |

**Webhook signature verification pattern:**

```js
// Problem: need raw body for signature verification but parsed body for handlers
// Solution: raw body on webhook routes, JSON on everything else

app.use('/webhooks', express.raw({ type: 'application/json' }));
app.use(express.json()); // this won't re-parse already-parsed bodies

app.post('/webhooks/stripe', (req, res) => {
  const sig = req.headers['stripe-signature'];
  const event = stripe.webhooks.constructEvent(req.body, sig, webhookSecret);
  // req.body is a Buffer here
});
```

### Request Hanging (No Response)

**Symptom:** Client times out, request never completes.

**Root cause:** Middleware or handler fails to call `next()` or send a response.

```js
// WRONG: conditional path doesn't call next() or send response
app.use((req, res, next) => {
  if (req.headers['x-api-key']) {
    req.authenticated = true;
    next();
  }
  // Missing else: request hangs when no API key
});

// CORRECT
app.use((req, res, next) => {
  if (req.headers['x-api-key']) {
    req.authenticated = true;
  }
  next(); // always called
});
```

**Debugging:** Add timeout middleware to detect hanging requests:

```js
app.use((req, res, next) => {
  const timeout = setTimeout(() => {
    console.error(`Request hanging: ${req.method} ${req.url}`);
  }, 30_000);
  res.on('finish', () => clearTimeout(timeout));
  next();
});
```

### Headers Already Sent

**Symptom:** `Error: Cannot set headers after they are sent to the client`

**Root cause:** Attempting to send a response after one has already been sent.

```js
// WRONG: double response
app.get('/users/:id', async (req, res) => {
  const user = await User.findById(req.params.id);
  if (!user) {
    res.status(404).json({ error: 'Not found' });
    // Missing return -- falls through
  }
  res.json(user); // ERROR: headers already sent
});

// CORRECT: return after sending
app.get('/users/:id', async (req, res) => {
  const user = await User.findById(req.params.id);
  if (!user) {
    return res.status(404).json({ error: 'Not found' });
  }
  res.json(user);
});
```

Guard against this in error handlers:

```js
app.use((err, req, res, next) => {
  if (res.headersSent) {
    return next(err); // delegate to default handler
  }
  res.status(500).json({ error: err.message });
});
```

---

## Express 5 Migration Errors

### path-to-regexp v8 Startup Errors

**Symptom:** App fails to start with `TypeError: Invalid path` or `Unexpected character`.

**Root cause:** Express 5 uses path-to-regexp v8 which is stricter.

```js
// These cause startup errors in Express 5
app.get('/users/*', handler);          // bare wildcard
app.get('/files/(.*)', handler);       // unnamed regex group
app.get('/a(b)?c', handler);           // inline regex

// Fixed for Express 5
app.get('/users/:splat*', handler);    // named wildcard
app.get('/files/:path(.*)', handler);  // named group
app.get('/a{b}c', handler);           // optional segment
```

**Debugging:** Express 5 surfaces these at startup, not at request time. Check all route definitions.

### Removed API Errors

**Symptom:** `TypeError: res.send is not a function` or `req.param is not a function`.

**Fix:** Replace deprecated APIs:

```js
// Before (Express 4)          // After (Express 5)
res.send(200, data)         => res.status(200).send(data)
res.json(200, data)         => res.status(200).json(data)
res.sendfile(path)          => res.sendFile(path)
req.param('name')           => req.params.name || req.query.name
app.del('/path', fn)        => app.delete('/path', fn)
res.redirect('/url', 301)   => res.redirect(301, '/url')
```

---

## Debugging

### Debug Module

Express uses the `debug` module internally. Enable it to see routing and middleware execution:

```bash
# See all Express debug output
DEBUG=express:* node server.js

# Only routing
DEBUG=express:router node server.js

# Only view engine
DEBUG=express:view node server.js

# Multiple
DEBUG=express:router,express:application node server.js
```

### Request Tracing Middleware

```js
app.use((req, res, next) => {
  req.requestId = req.headers['x-request-id'] || crypto.randomUUID();
  res.set('X-Request-ID', req.requestId);

  const start = Date.now();
  res.on('finish', () => {
    console.log(JSON.stringify({
      requestId: req.requestId,
      method: req.method,
      url: req.originalUrl,
      status: res.statusCode,
      duration: Date.now() - start,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
    }));
  });
  next();
});
```

### Inspecting Registered Routes

```js
// List all registered routes (useful for debugging 404s)
function printRoutes(app) {
  const routes = [];
  app._router.stack.forEach((middleware) => {
    if (middleware.route) {
      routes.push({
        method: Object.keys(middleware.route.methods).join(','),
        path: middleware.route.path,
      });
    } else if (middleware.name === 'router') {
      middleware.handle.stack.forEach((handler) => {
        if (handler.route) {
          const prefix = middleware.regexp.source
            .replace('\\/?(?=\\/|$)', '')
            .replace(/\\\//g, '/');
          routes.push({
            method: Object.keys(handler.route.methods).join(','),
            path: prefix + handler.route.path,
          });
        }
      });
    }
  });
  console.table(routes);
}
```

---

## Memory Leaks

### Common Causes in Express Apps

1. **Growing event listeners:** Not removing listeners on `req` or `res` events.

```js
// WRONG: listener accumulates if not removed
app.use((req, res, next) => {
  process.on('SIGTERM', () => { /* cleanup */ }); // leak!
  next();
});
```

2. **Unclosed database connections:** Not cleaning up in middleware or shutdown.

3. **In-memory session store in production:** The default `MemoryStore` grows unbounded.

```js
// WRONG: leaks memory in production
app.use(session({ secret: 'key' })); // uses MemoryStore

// CORRECT: use Redis/database store
app.use(session({ store: new RedisStore({ client: redisClient }), ... }));
```

4. **Large response caching without eviction:** Custom caching without TTL or size limits.

5. **Multer temp files not cleaned up:** Files stored to disk without cleanup.

### Diagnosing Memory Leaks

```bash
# Start with heap snapshots
node --inspect server.js

# Use clinic.js for profiling
npx clinic doctor -- node server.js
npx clinic flame -- node server.js
npx clinic bubbleprof -- node server.js

# Monitor memory
node -e "setInterval(() => console.log(process.memoryUsage()), 5000)"
```

---

## Performance Diagnostics

### Slow Middleware Detection

```js
// Middleware timing
app.use((req, res, next) => {
  const timings = [];
  const originalNext = next;

  let lastTime = Date.now();
  const trackedNext = (...args) => {
    timings.push({ duration: Date.now() - lastTime });
    lastTime = Date.now();
    originalNext(...args);
  };

  res.on('finish', () => {
    if (timings.some(t => t.duration > 100)) {
      console.warn('Slow middleware detected:', timings);
    }
  });

  trackedNext();
});
```

### Response Time Monitoring

```js
import responseTime from 'response-time';

app.use(responseTime((req, res, time) => {
  if (time > 1000) {
    console.warn(`Slow response: ${req.method} ${req.url} took ${time}ms`);
  }
  // Push to metrics (Prometheus, StatsD, etc.)
  metrics.histogram('http_request_duration_ms', time, {
    method: req.method,
    route: req.route?.path || 'unknown',
    status: res.statusCode,
  });
}));
```

### Database Query Logging

```js
// Prisma
const prisma = new PrismaClient({
  log: [
    { emit: 'event', level: 'query' },
  ],
});

prisma.$on('query', (e) => {
  if (e.duration > 100) {
    console.warn(`Slow query (${e.duration}ms):`, e.query);
  }
});
```

---

## Trust Proxy Issues

**Symptom:** `req.ip` returns proxy IP instead of client IP. `req.protocol` returns `http` when behind HTTPS termination.

**Fix:** Configure `trust proxy` correctly:

```js
// Behind one proxy (most common: ALB, Nginx, Cloudflare)
app.set('trust proxy', 1);

// Behind multiple known proxies
app.set('trust proxy', ['loopback', '10.0.0.0/8']);

// NEVER use true in production (trusts all proxies -- IP spoofing risk)
app.set('trust proxy', true); // DANGEROUS
```

**Verification:**

```js
app.get('/debug/proxy', (req, res) => {
  res.json({
    ip: req.ip,
    ips: req.ips,
    protocol: req.protocol,
    hostname: req.hostname,
    headers: {
      'x-forwarded-for': req.headers['x-forwarded-for'],
      'x-forwarded-proto': req.headers['x-forwarded-proto'],
      'x-forwarded-host': req.headers['x-forwarded-host'],
    },
  });
});
```

---

## Express 4 Async Error Patterns (Legacy)

For Express 4 projects that cannot upgrade to Express 5:

### Pattern 1: express-async-errors (Recommended)

```bash
npm install express-async-errors
```

```js
import 'express-async-errors'; // must be imported before routes

// Now async errors auto-forward to error handler
app.get('/users/:id', async (req, res) => {
  const user = await User.findById(req.params.id);
  res.json(user);
});
```

### Pattern 2: asyncHandler Wrapper

```js
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

app.get('/users/:id', asyncHandler(async (req, res) => {
  const user = await User.findById(req.params.id);
  res.json(user);
}));
```

### Pattern 3: Router-Level Wrapper

```js
function wrapRouter(router) {
  const methods = ['get', 'post', 'put', 'patch', 'delete'];
  methods.forEach((method) => {
    const original = router[method].bind(router);
    router[method] = (path, ...handlers) => {
      const wrapped = handlers.map((h) =>
        typeof h === 'function' && h.constructor.name === 'AsyncFunction'
          ? asyncHandler(h)
          : h
      );
      return original(path, ...wrapped);
    };
  });
  return router;
}
```
