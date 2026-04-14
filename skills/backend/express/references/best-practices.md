# Express.js Best Practices Reference

## Project Structure

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

Separating app creation from server startup is essential for testability with Supertest:

```ts
// app.ts -- no listen()
import express, { Application } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { usersRouter } from './features/users/users.router.js';
import { notFoundHandler } from './middleware/notFound.js';
import { errorHandler } from './middleware/errorHandler.js';

export function createApp(): Application {
  const app = express();
  app.use(helmet());
  app.use(cors());
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));
  app.use('/api/v1/users', usersRouter);
  app.get('/health', (req, res) => res.json({ status: 'ok' }));
  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}

// server.ts -- starts listening
import { createApp } from './app.js';
import { config } from './config/index.js';

const app = createApp();
app.listen(config.PORT, () => {
  console.log(`Server running on port ${config.PORT}`);
});
```

### Configuration with Validation

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

## Security

### Helmet

```ts
import helmet from 'helmet';

// Sensible defaults -- recommended starting point
app.use(helmet());

// Custom configuration
app.use(helmet({
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
  hsts: { maxAge: 31536000, includeSubDomains: true, preload: true },
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  crossOriginEmbedderPolicy: false,
  crossOriginOpenerPolicy: { policy: 'same-origin' },
}));
```

### CORS

```ts
import cors from 'cors';

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
  credentials: true,
  maxAge: 86400,
}));

// Per-route CORS (override global policy)
app.get('/public', cors({ origin: '*' }), (req, res) => res.json({ ok: true }));
```

### Rate Limiting

```ts
import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';
import { createClient } from 'redis';

const redisClient = createClient({ url: process.env.REDIS_URL });

// Global limiter
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  store: new RedisStore({ sendCommand: (...args) => redisClient.sendCommand(args) }),
  message: { error: 'Too many requests, please try again later.' },
});
app.use('/api/', globalLimiter);

// Strict limiter for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  skipSuccessfulRequests: true,
  keyGenerator: (req) => req.ip + ':' + req.body?.email,
});
app.use('/auth/login', authLimiter);
```

### Additional Security Middleware

- `express-mongo-sanitize` -- prevent NoSQL injection
- `hpp` -- HTTP Parameter Pollution protection
- Cookie flags: `httpOnly`, `secure`, `sameSite: 'strict'`
- `__Host-` cookie prefix to prevent subdomain hijacking

---

## Validation

### express-validator

```ts
import { body, param, query, validationResult, matchedData } from 'express-validator';

const validate = (validations) => async (req, res, next) => {
  await Promise.all(validations.map((v) => v.run(req)));
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(422).json({ errors: errors.array() });
  }
  next();
};

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
  const data = matchedData(req);
  const user = await User.create(data);
  res.status(201).json(user);
});
```

### Zod-based Validation (Alternative)

```ts
import { z, ZodSchema } from 'zod';

const validateBody = (schema: ZodSchema) => (req, res, next) => {
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

## Authentication

### Passport.js (Local + JWT)

```ts
import passport from 'passport';
import { Strategy as LocalStrategy } from 'passport-local';
import { Strategy as JwtStrategy, ExtractJwt } from 'passport-jwt';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

// Local strategy
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

// JWT strategy
passport.use(new JwtStrategy({
  jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
  secretOrKey: process.env.JWT_SECRET,
  issuer: 'api.example.com',
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
    { expiresIn: '15m', issuer: 'api.example.com' }
  );
}

// Protect routes
const requireAuth = passport.authenticate('jwt', { session: false });
app.get('/api/profile', requireAuth, (req, res) => res.json(req.user));
```

### Lightweight JWT (without Passport)

```ts
function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing bearer token' });
  }
  try {
    req.user = jwt.verify(authHeader.slice(7), process.env.JWT_SECRET);
    next();
  } catch (err) {
    next(err);
  }
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user) return res.status(401).json({ error: 'Unauthenticated' });
    if (!roles.some((r) => req.user.roles?.includes(r))) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
}

app.delete('/users/:id', requireAuth, requireRole('admin'), controller.remove);
```

### OAuth2 (Google)

```ts
import { Strategy as GoogleStrategy } from 'passport-google-oauth20';

passport.use(new GoogleStrategy({
  clientID: process.env.GOOGLE_CLIENT_ID,
  clientSecret: process.env.GOOGLE_CLIENT_SECRET,
  callbackURL: '/auth/google/callback',
  scope: ['profile', 'email'],
}, async (accessToken, refreshToken, profile, done) => {
  let user = await User.findOne({ where: { googleId: profile.id } });
  if (!user) {
    user = await User.create({
      googleId: profile.id,
      email: profile.emails[0].value,
      name: profile.displayName,
    });
  }
  return done(null, user);
}));

app.get('/auth/google', passport.authenticate('google'));
app.get('/auth/google/callback',
  passport.authenticate('google', { failureRedirect: '/login' }),
  (req, res) => res.redirect('/dashboard')
);
```

---

## File Uploads (Multer)

```ts
import multer from 'multer';
import crypto from 'crypto';
import path from 'path';

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, '/tmp/uploads'),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const name = crypto.randomBytes(16).toString('hex');
    cb(null, `${name}${ext}`);
  },
});

const upload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    cb(null, ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'].includes(file.mimetype));
  },
  limits: { fileSize: 5 * 1024 * 1024, files: 5 },
});

// Single file
app.post('/upload/avatar', upload.single('avatar'), async (req, res) => {
  const url = await uploadToS3(req.file);
  res.json({ url });
});

// Multiple fields
app.post('/upload/product',
  upload.fields([{ name: 'images', maxCount: 5 }, { name: 'spec', maxCount: 1 }]),
  async (req, res) => {
    res.json({ ok: true });
  }
);

// Memory storage for direct processing
const memUpload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 1024 * 1024 } });
```

---

## Testing with Supertest

Supertest drives your Express app over HTTP without binding to a port:

```ts
import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { db } from '../../shared/database.js';

const app = createApp();

beforeAll(async () => { await db.connect(process.env.TEST_DATABASE_URL); });
afterAll(async () => { await db.disconnect(); });
beforeEach(async () => { await db.clearCollections(['users']); });

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
    const res = await request(app)
      .post('/api/v1/users')
      .send({ name: 'Alice', email: 'alice@example.com', password: 'pass1234' })
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

// Mocking services
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

### Jest Configuration

```ts
// jest.config.ts
export default {
  preset: 'ts-jest/presets/default-esm',
  testEnvironment: 'node',
  extensionsToTreatAsEsm: ['.ts'],
  moduleNameMapper: { '^(\\.{1,2}/.*)\\.js$': '$1' },
  coverageProvider: 'v8',
  collectCoverageFrom: ['src/**/*.ts', '!src/**/*.d.ts'],
};
```

---

## Deployment

### Cluster Mode

```ts
import cluster from 'cluster';
import { cpus } from 'os';
import { createApp } from './app.js';

if (cluster.isPrimary) {
  const numCPUs = cpus().length;
  console.log(`Primary ${process.pid}: forking ${numCPUs} workers`);
  for (let i = 0; i < numCPUs; i++) cluster.fork();
  cluster.on('exit', (worker, code, signal) => {
    console.log(`Worker ${worker.process.pid} died. Respawning...`);
    cluster.fork();
  });
} else {
  const app = createApp();
  app.listen(config.PORT);
}
```

### PM2

```javascript
// ecosystem.config.js
module.exports = {
  apps: [{
    name: 'api',
    script: 'dist/server.js',
    instances: 'max',
    exec_mode: 'cluster',
    max_memory_restart: '500M',
    env_production: { NODE_ENV: 'production' },
  }],
};
```

### Docker

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine AS production
ENV NODE_ENV=production
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=builder /app/dist ./dist
USER node
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

### Reverse Proxy (Nginx)

```nginx
upstream express_app {
  server 127.0.0.1:3000;
  keepalive 64;
}

server {
  listen 443 ssl http2;
  server_name api.example.com;

  gzip on;
  gzip_types application/json text/plain;

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
    proxy_read_timeout 60s;
  }
}
```

### Graceful Shutdown

```ts
const server = app.listen(PORT);

let connections = new Set();
server.on('connection', (conn) => {
  connections.add(conn);
  conn.on('close', () => connections.delete(conn));
});

async function shutdown(signal: string) {
  console.log(`${signal} received -- starting graceful shutdown`);
  server.close(async () => {
    try {
      await db.close();
      await redisClient.quit();
      process.exit(0);
    } catch (err) {
      process.exit(1);
    }
  });
  setTimeout(() => {
    connections.forEach((c) => c.destroy());
  }, 10_000);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('uncaughtException', (err) => { console.error(err); process.exit(1); });
process.on('unhandledRejection', (err) => { console.error(err); process.exit(1); });
```

---

## Performance

### Compression

```ts
import compression from 'compression';

app.use(compression({
  level: 6,
  threshold: 1024,
  filter: (req, res) => {
    if (req.headers['x-no-compression']) return false;
    return compression.filter(req, res);
  },
}));
```

In production behind Nginx, offload compression to Nginx.

### Trust Proxy

```ts
// Behind a reverse proxy -- enables correct req.ip, req.protocol, req.hostname
app.set('trust proxy', 1);
// For multiple known proxies:
app.set('trust proxy', ['loopback', '10.0.0.0/8']);
```

### Keep-Alive Tuning

```ts
import http from 'http';
const server = http.createServer(app);
server.keepAliveTimeout = 65000;   // must exceed load balancer timeout
server.headersTimeout = 66000;     // must exceed keepAliveTimeout
```

### ETag Support

```ts
app.set('etag', 'strong'); // default; 'weak' or false
```

---

## Database Integration

### Prisma

```ts
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['query', 'warn', 'error'] : ['error'],
});

app.get('/users', async (req, res, next) => {
  const users = await prisma.user.findMany({
    where: { active: true },
    select: { id: true, email: true, name: true },
    orderBy: { createdAt: 'desc' },
    take: 20,
  });
  res.json(users);
});
```

### Sequelize

```ts
const sequelize = new Sequelize(process.env.DATABASE_URL, {
  dialect: 'postgres',
  pool: { min: 2, max: 10, acquire: 30000, idle: 10000 },
});
```

### Mongoose

```ts
mongoose.connect(process.env.MONGODB_URI, {
  maxPoolSize: 10,
  serverSelectionTimeoutMS: 5000,
});
```

---

## Logging

### Morgan (HTTP Logging)

```ts
import morgan from 'morgan';

// Custom tokens
morgan.token('request-id', (req) => req.headers['x-request-id'] || 'none');
morgan.token('user-id', (req) => req.user?.id || 'anonymous');

app.use(morgan(':request-id :method :url :status :response-time ms :user-id'));

// Structured logging with Pino
import pino from 'pino';
const logger = pino();
app.use(morgan('combined', {
  stream: { write: (msg) => logger.info(msg.trim()) },
  skip: (req) => req.url === '/health',
}));
```

---

## Session Management

```ts
import session from 'express-session';
import RedisStore from 'connect-redis';
import { createClient } from 'redis';

const redisClient = createClient({ url: process.env.REDIS_URL });
await redisClient.connect();

app.use(session({
  store: new RedisStore({ client: redisClient }),
  secret: process.env.SESSION_SECRET,
  name: '__Host-sid',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    sameSite: 'lax',
    maxAge: 7 * 24 * 60 * 60 * 1000,
  },
}));
```

---

## WebSocket Integration

### Socket.IO with Express

```ts
import http from 'http';
import { Server } from 'socket.io';

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: process.env.CLIENT_URL, credentials: true },
  transports: ['websocket', 'polling'],
});

// Auth middleware for Socket.IO
io.use((socket, next) => {
  const token = socket.handshake.auth.token;
  if (!token) return next(new Error('Unauthorized'));
  try {
    socket.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch { next(new Error('Invalid token')); }
});

io.on('connection', (socket) => {
  socket.join(`user:${socket.user.sub}`);
  socket.on('disconnect', () => {});
});

// Emit from REST endpoint
app.post('/api/notifications', requireAuth, async (req, res) => {
  const note = await Notification.create(req.body);
  io.to(`user:${req.body.userId}`).emit('notification', note);
  res.status(201).json(note);
});

server.listen(PORT);
```

---

## API Versioning

### URL Prefix (Most Common)

```ts
app.use('/api/v1', v1Router);
app.use('/api/v2', v2Router);
```

### Header-Based

```ts
app.use((req, res, next) => {
  req.apiVersion = parseInt(req.headers['api-version'] || '1', 10);
  next();
});
```

---

## Health Checks

```ts
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/health/ready', async (req, res) => {
  const checks = {};
  let healthy = true;
  try { await db.authenticate(); checks.database = 'ok'; }
  catch { checks.database = 'error'; healthy = false; }
  try { await redisClient.ping(); checks.redis = 'ok'; }
  catch { checks.redis = 'error'; healthy = false; }
  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'ok' : 'degraded',
    checks, uptime: process.uptime(), memory: process.memoryUsage(),
  });
});
```

---

## API Documentation (Swagger / OpenAPI)

```ts
import swaggerJsdoc from 'swagger-jsdoc';
import swaggerUi from 'swagger-ui-express';

const options = {
  definition: {
    openapi: '3.0.0',
    info: { title: 'My API', version: '1.0.0' },
    components: {
      securitySchemes: {
        bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      },
    },
    security: [{ bearerAuth: [] }],
  },
  apis: ['./src/routes/**/*.js', './src/models/**/*.js'],
};

const swaggerSpec = swaggerJsdoc(options);
app.use('/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));
app.get('/openapi.json', (req, res) => res.json(swaggerSpec));
```

---

## Key Version Reference (mid-2025)

| Package | Version | Notes |
|---|---|---|
| express | 4.21 / 5.x | v5 auto async error propagation |
| helmet | 8.x | CSP defaults tightened in v7 |
| cors | 2.x | Stable, minimal API |
| passport | 0.7.x | v0.6+ drops deprecated sync `req.logout()` |
| express-rate-limit | 7.x | `rate-limit-redis` v4 for Redis |
| express-validator | 7.x | Tree-shakeable chain API |
| multer | 1.4.5-lts.1 | v2 rewrite in progress |
| express-session | 1.18 | |
| connect-redis | 7.x | ESM default export |
| socket.io | 4.x | |
| swagger-jsdoc | 6.x | |
| swagger-ui-express | 5.x | |
| compression | 1.x | |
| morgan | 1.x | |
