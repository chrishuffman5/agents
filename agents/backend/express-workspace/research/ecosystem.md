# Express.js Middleware Ecosystem & Patterns

## Overview

Express.js middleware is composed in a pipeline: each function receives `(req, res, next)` and either responds or calls `next()` to pass control downstream. This document covers the most important middleware packages, integration patterns, and architectural conventions used in production Express applications.

---

## Security: Helmet

Helmet sets HTTP response headers to protect against common web vulnerabilities.

```js
const helmet = require('helmet');

app.use(helmet());
// Equivalent to enabling all defaults:
// Content-Security-Policy, X-DNS-Prefetch-Control, X-Frame-Options,
// X-Permitted-Cross-Domain-Policies, Referrer-Policy, HSTS, etc.

// Custom configuration
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'", 'cdn.example.com'],
      styleSrc: ["'self'", 'fonts.googleapis.com'],
      imgSrc: ["'self'", 'data:', 'cdn.example.com'],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true,
  },
  frameguard: { action: 'deny' },
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
}));
```

Key headers set by helmet: `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Strict-Transport-Security`, `X-XSS-Protection` (disabled in modern browsers, CSP preferred).

---

## CORS

```js
const cors = require('cors');

// Simple: allow all origins (development only)
app.use(cors());

// Production: whitelist origins
const allowedOrigins = ['https://app.example.com', 'https://admin.example.com'];
app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('CORS policy violation'));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-ID'],
  exposedHeaders: ['X-Total-Count', 'X-RateLimit-Remaining'],
  credentials: true,       // allow cookies
  maxAge: 86400,           // preflight cache duration in seconds
}));

// Per-route CORS (override global policy)
app.get('/public', cors({ origin: '*' }), (req, res) => res.json({ ok: true }));
```

---

## Logging: Morgan

Morgan is an HTTP request logger middleware.

```js
const morgan = require('morgan');

// Predefined formats: combined, common, dev, short, tiny
app.use(morgan('combined'));  // Apache Combined Log Format

// Custom token + format
morgan.token('request-id', (req) => req.headers['x-request-id'] || 'none');
morgan.token('user-id', (req) => req.user?.id || 'anonymous');

app.use(morgan(':request-id :method :url :status :res[content-length] - :response-time ms :user-id'));

// JSON structured logging (pairs well with Winston/Pino)
const logger = require('pino')();
app.use(morgan('combined', {
  stream: { write: (msg) => logger.info(msg.trim()) },
  skip: (req) => req.url === '/health',  // skip health checks
}));
```

---

## Cookie Parser & Session

```js
const cookieParser = require('cookie-parser');
const session = require('express-session');
const RedisStore = require('connect-redis').default;
const { createClient } = require('redis');

// Cookie parser — must come before session
app.use(cookieParser(process.env.COOKIE_SECRET));

// Redis-backed sessions (production pattern)
const redisClient = createClient({ url: process.env.REDIS_URL });
await redisClient.connect();

app.use(session({
  store: new RedisStore({ client: redisClient }),
  secret: process.env.SESSION_SECRET,
  name: '__Host-sid',          // __Host prefix prevents subdomain hijacking
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    sameSite: 'lax',
    maxAge: 7 * 24 * 60 * 60 * 1000,  // 7 days
  },
}));
```

---

## Authentication: Passport.js

Passport uses "strategies" for different auth mechanisms. All strategies populate `req.user`.

### Local Strategy (username/password)

```js
const passport = require('passport');
const LocalStrategy = require('passport-local').Strategy;
const bcrypt = require('bcryptjs');

passport.use(new LocalStrategy(
  { usernameField: 'email' },
  async (email, password, done) => {
    try {
      const user = await User.findOne({ where: { email } });
      if (!user) return done(null, false, { message: 'User not found' });
      const valid = await bcrypt.compare(password, user.passwordHash);
      if (!valid) return done(null, false, { message: 'Wrong password' });
      return done(null, user);
    } catch (err) {
      return done(err);
    }
  }
));

passport.serializeUser((user, done) => done(null, user.id));
passport.deserializeUser(async (id, done) => {
  try {
    const user = await User.findByPk(id);
    done(null, user);
  } catch (err) {
    done(err);
  }
});

app.use(passport.initialize());
app.use(passport.session());  // requires express-session

app.post('/auth/login',
  passport.authenticate('local', { failureRedirect: '/login', failureFlash: true }),
  (req, res) => res.redirect('/dashboard')
);
```

### JWT Strategy

```js
const JwtStrategy = require('passport-jwt').Strategy;
const { ExtractJwt } = require('passport-jwt');
const jwt = require('jsonwebtoken');

passport.use(new JwtStrategy({
  jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
  secretOrKey: process.env.JWT_SECRET,
  issuer: 'api.example.com',
  audience: 'example.com',
}, async (payload, done) => {
  try {
    const user = await User.findByPk(payload.sub);
    return user ? done(null, user) : done(null, false);
  } catch (err) {
    return done(err);
  }
}));

// Issue tokens
function signToken(user) {
  return jwt.sign(
    { sub: user.id, email: user.email, roles: user.roles },
    process.env.JWT_SECRET,
    { expiresIn: '15m', issuer: 'api.example.com', audience: 'example.com' }
  );
}

// Protect routes
const requireAuth = passport.authenticate('jwt', { session: false });
app.get('/api/profile', requireAuth, (req, res) => res.json(req.user));
```

### OAuth2 / Google Strategy

```js
const GoogleStrategy = require('passport-google-oauth20').Strategy;

passport.use(new GoogleStrategy({
  clientID: process.env.GOOGLE_CLIENT_ID,
  clientSecret: process.env.GOOGLE_CLIENT_SECRET,
  callbackURL: '/auth/google/callback',
  scope: ['profile', 'email'],
}, async (accessToken, refreshToken, profile, done) => {
  try {
    let user = await User.findOne({ where: { googleId: profile.id } });
    if (!user) {
      user = await User.create({
        googleId: profile.id,
        email: profile.emails[0].value,
        name: profile.displayName,
        avatarUrl: profile.photos[0]?.value,
      });
    }
    return done(null, user);
  } catch (err) {
    return done(err);
  }
}));

app.get('/auth/google', passport.authenticate('google'));
app.get('/auth/google/callback',
  passport.authenticate('google', { failureRedirect: '/login' }),
  (req, res) => res.redirect('/dashboard')
);
```

### GitHub Strategy

```js
const GitHubStrategy = require('passport-github2').Strategy;

passport.use(new GitHubStrategy({
  clientID: process.env.GITHUB_CLIENT_ID,
  clientSecret: process.env.GITHUB_CLIENT_SECRET,
  callbackURL: '/auth/github/callback',
  scope: ['user:email'],
}, async (accessToken, refreshToken, profile, done) => {
  const email = profile.emails?.[0]?.value;
  let user = await User.findOne({ where: { githubId: profile.id } });
  if (!user) {
    user = await User.create({ githubId: profile.id, email, name: profile.displayName });
  }
  return done(null, user);
}));

app.get('/auth/github', passport.authenticate('github'));
app.get('/auth/github/callback',
  passport.authenticate('github', { failureRedirect: '/login' }),
  (req, res) => res.redirect('/dashboard')
);
```

---

## Rate Limiting: express-rate-limit

```js
const rateLimit = require('express-rate-limit');
const RedisStore = require('rate-limit-redis');
const { createClient } = require('redis');

const redisClient = createClient({ url: process.env.REDIS_URL });

// Global limiter
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 100,
  standardHeaders: true,     // Return rate limit info in `RateLimit-*` headers
  legacyHeaders: false,
  store: new RedisStore({ sendCommand: (...args) => redisClient.sendCommand(args) }),
  message: { error: 'Too many requests, please try again later.' },
});
app.use('/api/', globalLimiter);

// Strict limiter for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  skipSuccessfulRequests: true,  // only count failed attempts
  keyGenerator: (req) => req.ip + ':' + req.body?.email,
});
app.use('/auth/login', authLimiter);
```

---

## Validation: express-validator

```js
const { body, param, query, validationResult, matchedData } = require('express-validator');

// Reusable validation middleware factory
const validate = (validations) => async (req, res, next) => {
  await Promise.all(validations.map((v) => v.run(req)));
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(422).json({ errors: errors.array() });
  }
  next();
};

// User creation validation chain
const createUserRules = [
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
  body('password')
    .isLength({ min: 8 })
    .matches(/[A-Z]/).withMessage('Password needs uppercase')
    .matches(/[0-9]/).withMessage('Password needs a digit'),
  body('name').trim().isLength({ min: 2, max: 100 }).escape(),
  body('role').optional().isIn(['user', 'admin', 'moderator']),
];

app.post('/users', validate(createUserRules), async (req, res) => {
  const data = matchedData(req);  // only validated & sanitized fields
  const user = await User.create(data);
  res.status(201).json(user);
});

// Query validation
const listUsersRules = [
  query('page').optional().isInt({ min: 1 }).toInt().default(1),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt().default(20),
  query('sort').optional().isIn(['name', 'email', 'createdAt']),
];
```

---

## File Uploads: Multer

```js
const multer = require('multer');
const path = require('path');
const crypto = require('crypto');

// Disk storage with unique filenames
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, '/tmp/uploads'),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const name = crypto.randomBytes(16).toString('hex');
    cb(null, `${name}${ext}`);
  },
});

// File type filtering
const fileFilter = (req, file, cb) => {
  const allowed = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
  cb(null, allowed.includes(file.mimetype));
};

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024, files: 5 },  // 5MB max, 5 files max
});

// Single file
app.post('/upload/avatar', upload.single('avatar'), async (req, res) => {
  // req.file: { fieldname, originalname, mimetype, size, path }
  const url = await uploadToS3(req.file);
  res.json({ url });
});

// Multiple fields
app.post('/upload/product',
  upload.fields([{ name: 'images', maxCount: 5 }, { name: 'spec', maxCount: 1 }]),
  async (req, res) => {
    // req.files: { images: [...], spec: [...] }
    res.json({ ok: true });
  }
);

// Memory storage (for direct processing/streaming)
const memStorage = multer({ storage: multer.memoryStorage(), limits: { fileSize: 1024 * 1024 } });
```

---

## Compression

```js
const compression = require('compression');

app.use(compression({
  level: 6,                     // zlib compression level 0-9
  threshold: 1024,              // only compress responses > 1KB
  filter: (req, res) => {
    if (req.headers['x-no-compression']) return false;
    return compression.filter(req, res);  // default filter
  },
}));
```

Note: In production behind a reverse proxy (Nginx/Caddy), prefer handling compression at the proxy layer.

---

## HTTP Proxy Middleware

```js
const { createProxyMiddleware } = require('http-proxy-middleware');

// Forward /api/legacy/* to a legacy service
app.use('/api/legacy', createProxyMiddleware({
  target: 'http://legacy-service:3001',
  changeOrigin: true,
  pathRewrite: { '^/api/legacy': '' },
  on: {
    proxyReq: (proxyReq, req) => {
      proxyReq.setHeader('X-Forwarded-User', req.user?.id || '');
    },
    error: (err, req, res) => {
      res.status(502).json({ error: 'Upstream service unavailable' });
    },
  },
}));

// Microservice gateway pattern
const services = { users: 'http://users:3001', orders: 'http://orders:3002' };
Object.entries(services).forEach(([name, target]) => {
  app.use(`/api/${name}`, createProxyMiddleware({ target, changeOrigin: true,
    pathRewrite: { [`^/api/${name}`]: '' } }));
});
```

---

## API Documentation: Swagger / OpenAPI

```js
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

const options = {
  definition: {
    openapi: '3.0.0',
    info: { title: 'My API', version: '1.0.0', description: 'REST API documentation' },
    servers: [{ url: '/api/v1' }],
    components: {
      securitySchemes: {
        bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      },
    },
    security: [{ bearerAuth: [] }],
  },
  apis: ['./src/routes/**/*.js', './src/models/**/*.js'],  // JSDoc comment sources
};

const swaggerSpec = swaggerJsdoc(options);
app.use('/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
  explorer: true,
  customSiteTitle: 'API Docs',
}));
app.get('/openapi.json', (req, res) => res.json(swaggerSpec));

// JSDoc annotation example (in route files):
/**
 * @swagger
 * /users/{id}:
 *   get:
 *     summary: Get user by ID
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: User found
 *         content:
 *           application/json:
 *             schema: { $ref: '#/components/schemas/User' }
 *       404:
 *         description: User not found
 */
```

---

## Error Handling Middleware

Error handlers take four arguments: `(err, req, res, next)`. Register them last.

```js
// Custom error class
class AppError extends Error {
  constructor(message, statusCode, code) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }
}

// 404 handler — place after all routes
app.use((req, res, next) => {
  next(new AppError(`Route ${req.method} ${req.path} not found`, 404, 'NOT_FOUND'));
});

// Central error handler — place last
app.use((err, req, res, next) => {
  const logger = req.app.locals.logger;

  // Known operational errors (thrown by app code)
  if (err.isOperational) {
    logger.warn({ err, path: req.path }, 'Operational error');
    return res.status(err.statusCode).json({
      error: { code: err.code, message: err.message },
    });
  }

  // Prisma / Sequelize / Mongoose errors
  if (err.code === 'P2002') {  // Prisma unique constraint
    return res.status(409).json({ error: { code: 'CONFLICT', message: 'Record already exists' } });
  }
  if (err.name === 'ValidationError') {  // Mongoose
    return res.status(422).json({ error: { code: 'VALIDATION', message: err.message } });
  }
  if (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError') {
    return res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Invalid or expired token' } });
  }

  // Unknown / programming errors — do not leak internals
  logger.error({ err, path: req.path }, 'Unhandled error');
  res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Internal server error' } });
});
```

---

## Request Validation Patterns

### Zod-based validation (alternative to express-validator)

```js
const { z } = require('zod');

const validateBody = (schema) => (req, res, next) => {
  const result = schema.safeParse(req.body);
  if (!result.success) {
    return res.status(422).json({
      errors: result.error.issues.map((i) => ({ path: i.path.join('.'), message: i.message })),
    });
  }
  req.validatedBody = result.data;
  next();
};

const createUserSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).regex(/[A-Z]/).regex(/[0-9]/),
  name: z.string().min(2).max(100),
  role: z.enum(['user', 'admin']).default('user'),
});

app.post('/users', validateBody(createUserSchema), async (req, res) => {
  const user = await User.create(req.validatedBody);
  res.status(201).json(user);
});
```

---

## Authentication Middleware Patterns

```js
// JWT middleware without Passport (lightweight)
const jwt = require('jsonwebtoken');

function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing bearer token' });
  }
  try {
    const token = authHeader.slice(7);
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch (err) {
    next(err);  // let error handler classify TokenExpiredError, etc.
  }
}

// Role-based access control middleware
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user) return res.status(401).json({ error: 'Unauthenticated' });
    if (!roles.some((r) => req.user.roles?.includes(r))) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
}

// Usage
app.delete('/users/:id', requireAuth, requireRole('admin'), async (req, res) => {
  await User.destroy({ where: { id: req.params.id } });
  res.status(204).send();
});
```

---

## API Versioning Patterns

### URL prefix versioning (most common)

```js
const v1Router = require('./routes/v1');
const v2Router = require('./routes/v2');

app.use('/api/v1', v1Router);
app.use('/api/v2', v2Router);
```

### Header-based versioning

```js
function versionRouter(req, res, next) {
  const version = req.headers['api-version'] || req.headers['accept-version'] || '1';
  req.apiVersion = parseInt(version, 10);
  next();
}

app.use(versionRouter);
app.use('/api/users', (req, res, next) => {
  if (req.apiVersion >= 2) return usersV2Router(req, res, next);
  return usersV1Router(req, res, next);
});
```

### Router factory pattern

```js
// src/routes/index.js
function createRouter(version) {
  const router = express.Router();
  const controllers = require(`./v${version}/controllers`);
  router.get('/users', controllers.listUsers);
  router.post('/users', controllers.createUser);
  return router;
}

app.use('/api/v1', createRouter(1));
app.use('/api/v2', createRouter(2));
```

---

## Health Checks

```js
// Basic health endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Deep health check (database + redis connectivity)
app.get('/health/ready', async (req, res) => {
  const checks = {};
  let healthy = true;

  try {
    await db.authenticate();   // Sequelize
    checks.database = 'ok';
  } catch (err) {
    checks.database = 'error';
    healthy = false;
  }

  try {
    await redisClient.ping();
    checks.redis = 'ok';
  } catch (err) {
    checks.redis = 'error';
    healthy = false;
  }

  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'ok' : 'degraded',
    checks,
    uptime: process.uptime(),
    memory: process.memoryUsage(),
  });
});

// Kubernetes liveness probe (is the process alive?)
app.get('/health/live', (req, res) => res.status(200).send('OK'));
```

---

## Graceful Shutdown

```js
const server = app.listen(PORT, () => logger.info(`Listening on ${PORT}`));

// Track open connections
let connections = new Set();
server.on('connection', (conn) => {
  connections.add(conn);
  conn.on('close', () => connections.delete(conn));
});

async function shutdown(signal) {
  logger.info(`${signal} received — starting graceful shutdown`);

  // Stop accepting new connections
  server.close(async () => {
    logger.info('HTTP server closed');

    try {
      await db.close();           // close DB pool
      await redisClient.quit();   // close Redis
      logger.info('Connections closed — exiting cleanly');
      process.exit(0);
    } catch (err) {
      logger.error(err, 'Error during shutdown');
      process.exit(1);
    }
  });

  // Force close lingering connections after timeout
  setTimeout(() => {
    logger.warn('Forcing connection teardown after timeout');
    connections.forEach((c) => c.destroy());
  }, 10_000);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT',  () => shutdown('SIGINT'));
process.on('uncaughtException',  (err) => { logger.fatal(err, 'uncaughtException');  process.exit(1); });
process.on('unhandledRejection', (err) => { logger.fatal(err, 'unhandledRejection'); process.exit(1); });
```

---

## Database Integration

### Prisma

```js
// src/db/prisma.js — singleton client
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['query', 'warn', 'error'] : ['error'],
});
module.exports = prisma;

// Usage in a route handler
const prisma = require('../db/prisma');

app.get('/users', async (req, res, next) => {
  try {
    const users = await prisma.user.findMany({
      where: { active: true },
      select: { id: true, email: true, name: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
      take: 20, skip: 0,
    });
    res.json(users);
  } catch (err) {
    next(err);
  }
});
```

### Sequelize

```js
const { Sequelize, DataTypes } = require('sequelize');
const sequelize = new Sequelize(process.env.DATABASE_URL, {
  dialect: 'postgres',
  pool: { min: 2, max: 10, acquire: 30000, idle: 10000 },
  logging: process.env.NODE_ENV === 'development' ? console.log : false,
});

const User = sequelize.define('User', {
  email: { type: DataTypes.STRING, unique: true, allowNull: false, validate: { isEmail: true } },
  passwordHash: { type: DataTypes.STRING, allowNull: false },
  role: { type: DataTypes.ENUM('user', 'admin'), defaultValue: 'user' },
}, { tableName: 'users', underscored: true });

// Attach to app for access in routes
app.locals.db = sequelize;
app.locals.models = { User };
```

### Knex (query builder)

```js
const knex = require('knex')({
  client: 'pg',
  connection: process.env.DATABASE_URL,
  pool: { min: 2, max: 10 },
  migrations: { tableName: 'knex_migrations', directory: './migrations' },
});

// Paginated query pattern
async function getUsers({ page = 1, limit = 20, sort = 'created_at' }) {
  const offset = (page - 1) * limit;
  const [rows, [{ count }]] = await Promise.all([
    knex('users').select('id','email','name','created_at').orderBy(sort, 'desc').limit(limit).offset(offset),
    knex('users').count('id as count'),
  ]);
  return { data: rows, total: parseInt(count), page, limit };
}
```

### Mongoose (MongoDB)

```js
const mongoose = require('mongoose');

mongoose.connect(process.env.MONGODB_URI, {
  maxPoolSize: 10,
  serverSelectionTimeoutMS: 5000,
});

const UserSchema = new mongoose.Schema({
  email:    { type: String, required: true, unique: true, lowercase: true, trim: true },
  name:     { type: String, required: true, maxlength: 100 },
  role:     { type: String, enum: ['user', 'admin'], default: 'user' },
}, { timestamps: true });

UserSchema.index({ email: 1 });
const User = mongoose.model('User', UserSchema);
```

---

## WebSocket Integration

### ws (native WebSocket server)

```js
const http = require('http');
const WebSocket = require('ws');

const server = http.createServer(app);
const wss = new WebSocket.Server({ server, path: '/ws' });

// Heartbeat pattern to detect stale connections
function heartbeat() { this.isAlive = true; }

wss.on('connection', (ws, req) => {
  ws.isAlive = true;
  ws.on('pong', heartbeat);
  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data);
      // handle message
      ws.send(JSON.stringify({ type: 'ack', id: msg.id }));
    } catch { ws.close(1003, 'Invalid JSON'); }
  });
});

const pingInterval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (!ws.isAlive) return ws.terminate();
    ws.isAlive = false;
    ws.ping();
  });
}, 30_000);

wss.on('close', () => clearInterval(pingInterval));
server.listen(PORT);
```

### Socket.IO with Express

```js
const http = require('http');
const { Server } = require('socket.io');

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: process.env.CLIENT_URL, methods: ['GET', 'POST'], credentials: true },
  pingTimeout: 60000,
  pingInterval: 25000,
  transports: ['websocket', 'polling'],
});

// Auth middleware for Socket.IO
const jwt = require('jsonwebtoken');
io.use((socket, next) => {
  const token = socket.handshake.auth.token;
  if (!token) return next(new Error('Unauthorized'));
  try {
    socket.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch (err) {
    next(new Error('Invalid token'));
  }
});

io.on('connection', (socket) => {
  console.log(`Connected: ${socket.user.sub}`);
  socket.join(`user:${socket.user.sub}`);  // personal room

  socket.on('chat:message', async (data) => {
    const msg = await Message.create({ userId: socket.user.sub, text: data.text });
    io.to(`room:${data.roomId}`).emit('chat:message', msg);
  });

  socket.on('disconnect', (reason) => {
    console.log(`Disconnected (${reason}): ${socket.user.sub}`);
  });
});

// Emit from REST endpoint (real-time + REST bridge)
app.post('/api/notifications', requireAuth, async (req, res) => {
  const note = await Notification.create(req.body);
  io.to(`user:${req.body.userId}`).emit('notification', note);
  res.status(201).json(note);
});

server.listen(PORT);
```

---

## Putting It Together: Production App Structure

```
src/
  app.js            # Express app setup (no listen())
  server.js         # http.createServer + listen + graceful shutdown
  config/           # env validation (zod/joi), constants
  middleware/
    auth.js         # requireAuth, requireRole
    validate.js     # validate() factory
    rateLimiter.js  # named limiters
    requestId.js    # attach X-Request-ID to req + res
  routes/
    v1/
      users.js
      orders.js
    v2/
      users.js
  controllers/      # thin handlers calling services
  services/         # business logic
  db/
    prisma.js       # or sequelize.js / knex.js / mongoose.js
  errors/
    AppError.js
    errorHandler.js
```

Typical middleware order in `app.js`:

```js
app.use(requestId);          // attach X-Request-ID first
app.use(helmet());
app.use(cors(corsOptions));
app.use(compression());
app.use(morgan('combined', { stream }));
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser(secret));
app.use(session(sessionOptions));
app.use(passport.initialize());
app.use(passport.session());

app.use('/api/v1', v1Router);
app.use('/api/v2', v2Router);
app.get('/health', healthHandler);
app.get('/docs', swaggerUi.serve, swaggerUi.setup(spec));

app.use(notFoundHandler);    // 404 — after all routes
app.use(errorHandler);       // error — always last
```

---

## Key Version Reference (as of mid-2025)

| Package | Version | Notes |
|---|---|---|
| express | 4.21 / 5.x beta | v5 uses async error propagation natively |
| helmet | 8.x | CSP defaults tightened in v7 |
| cors | 2.x | Stable, minimal API |
| passport | 0.7.x | v0.6+ drops deprecated `req.logout()` sync form |
| passport-jwt | 4.x | |
| passport-google-oauth20 | 2.x | |
| express-rate-limit | 7.x | `rate-limit-redis` v4 for Redis store |
| express-validator | 7.x | Tree-shakeable chain API |
| multer | 1.4.5-lts.1 | v2 rewrite in progress (breaking) |
| express-session | 1.18 | |
| connect-redis | 7.x | ESM default export in v7 |
| socket.io | 4.x | |
| swagger-jsdoc | 6.x | |
| swagger-ui-express | 5.x | |
| compression | 1.x | |
| morgan | 1.x | |
