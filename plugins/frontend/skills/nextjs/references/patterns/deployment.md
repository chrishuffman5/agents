# Deployment Patterns

Deployment strategies for Next.js applications: Vercel, self-hosting, Docker, and custom platforms.

---

## Vercel (Zero-Config)

Vercel is the reference deployment platform for Next.js. No `next.config.ts` changes needed.

### Features

- **Automatic ISR** with shared cache across deployments
- **Edge Functions** for Middleware (v15) and Proxy (v16)
- **Image Optimization CDN** -- `next/image` works out of the box
- **Web Vitals analytics** -- Core Web Vitals dashboard
- **Preview deployments** per pull request
- **`NEXT_PUBLIC_*` env vars** automatically available at build time

### Deployment

```bash
# Install Vercel CLI
npm install -g vercel

# Deploy (auto-detects Next.js)
vercel

# Production deployment
vercel --prod
```

Or connect a Git repository for automatic deployments on push.

### Environment Variables

Set via Vercel dashboard or CLI:

```bash
vercel env add DATABASE_URL production
vercel env add NEXT_PUBLIC_API_URL production preview development
```

- `NEXT_PUBLIC_*` -- available in both server and client code
- All others -- server-side only

---

## Self-Hosting with standalone Output

### Configuration

```ts
// next.config.ts
output: "standalone"
```

Produces `/.next/standalone/` -- a minimal Node.js server with only required dependencies. You must copy `public/` and `.next/static/` alongside it.

### Deployment Steps

```bash
# Build
npm run build

# Copy static assets
cp -r public .next/standalone/public
cp -r .next/static .next/standalone/.next/static

# Run
cd .next/standalone
node server.js
```

The server listens on port 3000 by default. Configure with `PORT` and `HOSTNAME` environment variables.

---

## Docker

### Production Dockerfile

```dockerfile
# Stage 1: Dependencies
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Stage 2: Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# Set build-time env vars
# ARG DATABASE_URL
# ENV DATABASE_URL=$DATABASE_URL
RUN npm run build

# Stage 3: Production
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
# Disable Next.js telemetry
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy standalone output
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

# sharp for image optimization (Linux-specific binary)
RUN npm install --platform=linux --arch=x64 sharp

USER nextjs

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
```

### Docker Compose

```yaml
version: "3.8"
services:
  nextjs:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/mydb
      - JWT_SECRET=your-secret-here
    depends_on:
      - db
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: mydb
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

---

## ISR on Self-Hosted

### Default Behavior

ISR works out of the box with file-system caching. Cached pages are stored in `.next/server/app/` and revalidated based on `revalidate` config.

### ISR expireTime (v15+)

```ts
// next.config.ts
expireTime: 3600, // ISR pages expire after 1 hour (default: 1 year)
```

### Custom Cache Handler

Replace the default file-system cache with Redis, S3, or another backend for multi-instance deployments:

```ts
// next.config.ts
cacheHandler: require.resolve("./cache-handler.js"),
cacheMaxMemorySize: 0, // Disable in-memory caching
```

```ts
// cache-handler.js
const { createClient } = require("redis");

const client = createClient({ url: process.env.REDIS_URL });
client.connect();

module.exports = class CacheHandler {
  async get(key) {
    const data = await client.get(key);
    return data ? JSON.parse(data) : null;
  }

  async set(key, data, ctx) {
    const ttl = ctx.revalidate ?? 3600;
    await client.set(key, JSON.stringify(data), { EX: ttl });
  }

  async revalidateTag(tags) {
    // Implement tag-based invalidation
    for (const tag of tags) {
      const keys = await client.keys(`*:tag:${tag}`);
      if (keys.length) await client.del(keys);
    }
  }
};
```

### Multi-Instance Considerations

- File-system cache is local to each instance -- use a shared cache handler
- Session storage should be external (Redis, database) for horizontal scaling
- Image optimization cache is per-instance by default -- consider a CDN

---

## Build Adapters (v16 Alpha)

A new low-level API for building deployment adapters. Allows platforms to intercept the Next.js build output and transform it for their infrastructure.

### Target Platforms

- Cloudflare Workers
- Deno Deploy
- Custom edge platforms
- Any serverless environment

### Configuration

```ts
// next.config.ts
experimental: {
  buildAdapter: require("./my-platform-adapter"),
}
```

### Adapter API (Simplified)

```ts
// my-platform-adapter.js
module.exports = {
  name: "my-platform",
  async adapt(buildOutput) {
    // Transform Next.js build output for your platform
    // buildOutput contains routes, assets, server functions
    await transformForPlatform(buildOutput);
  },
};
```

---

## Deployment Comparison

| Feature | Vercel | Self-Hosted | Docker |
|---|---|---|---|
| ISR | Automatic, shared cache | File-system or custom handler | Custom handler recommended |
| Image optimization | CDN, zero-config | sharp (auto-detected) | Install sharp for Linux |
| Edge Functions | Built-in | Not available | Not available |
| Preview deploys | Per PR, automatic | Manual setup | Manual setup |
| Environment vars | Dashboard + CLI | `.env` files | Docker env / secrets |
| Scaling | Automatic | Manual (PM2, k8s, etc.) | Container orchestration |
| Cost | Usage-based | Infrastructure cost | Infrastructure cost |
| Custom domains | Dashboard | DNS + reverse proxy | DNS + reverse proxy |

### When to Choose Each

- **Vercel**: Fastest path to production, best DX, automatic scaling. Ideal for most projects.
- **Self-hosted**: Full control, compliance requirements, existing infrastructure, cost optimization at scale.
- **Docker**: Consistent environments, Kubernetes deployment, CI/CD pipelines, multi-service architectures.
