# Docker Best Practices

## Dockerfile Patterns

### Base Image Selection

| Use Case | Base Image | Size | Security |
|---|---|---|---|
| Go, Rust (static binaries) | `scratch` | ~0 MB | Minimal attack surface |
| Static binaries with TLS/DNS | `gcr.io/distroless/static-debian12` | ~2 MB | No shell, no package manager |
| Java, Python, Node.js | `gcr.io/distroless/java21-debian12` etc. | ~50-200 MB | Runtime only, no shell |
| General purpose (minimal) | `debian:bookworm-slim` | ~75 MB | Smaller than full Debian |
| Alpine (smallest general) | `alpine:3.20` | ~8 MB | musl libc (may cause compatibility issues) |
| RHEL-compatible | `registry.access.redhat.com/ubi9-minimal` | ~35 MB | Red Hat Universal Base Image |

**Alpine caution**: Alpine uses musl libc instead of glibc. This causes issues with some C extensions (Python, Ruby, Node.js native modules). DNS resolution also differs. Use `-slim` Debian variants if you encounter musl compatibility problems.

### Multi-Stage Build Patterns

**Builder pattern (compiled languages):**
```dockerfile
FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o server .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /app/server /server
ENTRYPOINT ["/server"]
```

**Dependencies-first pattern (interpreted languages):**
```dockerfile
FROM node:22-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --production

FROM node:22-slim
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
USER node
EXPOSE 3000
CMD ["node", "server.js"]
```

**Test stage pattern:**
```dockerfile
FROM builder AS test
RUN go test -v ./...

FROM builder AS production
# Only builds if tests pass (when using --target=production or default)
```

### Layer Optimization

1. **Order by change frequency** (least to most):
   - System packages (rarely change)
   - Dependency manifests (change occasionally)
   - Application source (changes frequently)

2. **Combine related RUN commands:**
```dockerfile
# Good: single layer for all apt packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Bad: multiple layers, apt cache in layer
RUN apt-get update
RUN apt-get install curl
RUN apt-get install ca-certificates
```

3. **Use BuildKit cache mounts instead of manual cleanup:**
```dockerfile
# Better than rm -rf /var/lib/apt/lists/*
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends curl ca-certificates
```

### ARG and ENV Patterns

```dockerfile
# Build-time argument with default
ARG APP_VERSION=1.0.0

# Persist ARG value as ENV (ARGs reset after FROM)
FROM base AS final
ARG APP_VERSION
ENV APP_VERSION=${APP_VERSION}

# Runtime-only environment (not baked into image)
# Set via docker run -e or compose environment
```

**Important**: `ARG` values before `FROM` are only available for `FROM` instructions. After `FROM`, re-declare them.

### ENTRYPOINT + CMD Pattern

```dockerfile
# ENTRYPOINT: the executable
# CMD: default arguments (overridable at runtime)
ENTRYPOINT ["python", "manage.py"]
CMD ["runserver", "0.0.0.0:8000"]

# User can override CMD:
# docker run myapp migrate        --> python manage.py migrate
# docker run myapp shell           --> python manage.py shell
```

Use exec form (`["cmd", "arg"]`) not shell form (`cmd arg`) to ensure proper signal handling (PID 1, SIGTERM).

## Security Best Practices

### Image Security Checklist

1. **Pin base image versions**: `FROM node:22.5.1-slim` not `FROM node:latest`
2. **Scan images**: `docker scout cves myimage:latest` in CI/CD pipeline
3. **Use non-root user**: Always add `USER` instruction
4. **Minimize packages**: `--no-install-recommends`, remove docs and man pages
5. **No secrets in image**: Use `--secret` mounts for build, env/secrets for runtime
6. **Read-only rootfs**: `--read-only` with tmpfs for writable paths
7. **Drop capabilities**: `--cap-drop ALL --cap-add <needed>`
8. **Sign images**: `cosign sign` for supply chain verification

### Secrets Management

**Build-time secrets (never in layers):**
```dockerfile
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm install
RUN --mount=type=secret,id=ssh_key,target=/root/.ssh/id_rsa,mode=0600 \
    git clone git@github.com:private/repo.git
```

```bash
docker buildx build \
  --secret id=npmrc,src=$HOME/.npmrc \
  --secret id=ssh_key,src=$HOME/.ssh/id_rsa .
```

**Runtime secrets (Compose):**
```yaml
services:
  app:
    secrets:
      - db_password
    environment:
      DB_PASSWORD_FILE: /run/secrets/db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

### Content Trust and Signing

```bash
# Sign with cosign (keyless, uses OIDC)
cosign sign --yes registry.example.com/myapp:v1.0

# Verify signature
cosign verify registry.example.com/myapp:v1.0 \
  --certificate-identity=ci@example.com \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com

# Kubernetes admission control: use Kyverno or OPA/Gatekeeper to enforce signatures
```

## Compose Best Practices

### Service Dependencies

```yaml
services:
  api:
    depends_on:
      db:
        condition: service_healthy    # wait for health check
      redis:
        condition: service_started    # just wait for container start
```

Always use `service_healthy` when the dependency needs initialization time (databases, message brokers).

### Resource Limits

```yaml
services:
  api:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 256M
```

### Environment Variable Precedence

1. `docker compose run -e` (highest)
2. `environment:` in compose.yaml
3. `env_file:` in compose.yaml
4. `.env` file in project root (variable substitution only)

### Named Volumes for Data Persistence

```yaml
volumes:
  postgres-data:
    driver: local
    # Optional: NFS mount
    driver_opts:
      type: nfs
      o: addr=192.168.1.100,rw,nfsvers=4.1
      device: ":/exports/postgres"
```

Never use bind mounts for database data in production -- use named volumes for portability and Docker management.

### Profile-Based Services

```yaml
services:
  app:
    image: myapp
    # Always started (no profile)

  debug-tools:
    image: nicolaka/netshoot
    profiles: [debug]
    network_mode: "service:app"

  load-test:
    image: grafana/k6
    profiles: [testing]
```

## Image Optimization

### Size Reduction Techniques

1. **Multi-stage builds**: Build tools not in final image
2. **Distroless / scratch**: Minimal base images
3. **Combined RUN**: Fewer layers = smaller image (metadata overhead per layer)
4. **Cache mounts**: Don't store package manager cache in layers
5. **Strip binaries**: `go build -ldflags="-s -w"`, `strip --strip-all binary`
6. **.dockerignore**: Reduce build context, prevent accidental inclusion

### Analyzing Image Size

```bash
# Show image layer sizes
docker history myimage:latest

# Show compressed/uncompressed sizes
docker image inspect myimage:latest --format '{{.Size}}'

# Use dive for interactive layer analysis
dive myimage:latest

# Docker Scout shows recommendations for smaller base images
docker scout recommendations myimage:latest
```

### Registry Optimization

```bash
# Multi-platform images push once, shared layers across architectures
docker buildx build --platform linux/amd64,linux/arm64 --push -t myapp:v1 .

# Use registry cache for CI/CD
docker buildx build \
  --cache-from type=registry,ref=registry.example.com/myapp:cache \
  --cache-to type=registry,ref=registry.example.com/myapp:cache,mode=max \
  --push -t myapp:latest .
```

## Development Workflow

### Compose Watch (Hot Reload)

```yaml
services:
  app:
    build: .
    develop:
      watch:
        - action: sync           # live sync (interpreted languages)
          path: ./src
          target: /app/src
          ignore:
            - node_modules/
        - action: rebuild         # full rebuild (dependency changes)
          path: package.json
        - action: sync+restart    # sync then restart process
          path: ./config
          target: /app/config
```

```bash
docker compose watch
```

### Development vs Production Compose

```yaml
# compose.yaml (base)
services:
  app:
    image: myapp:latest
    environment:
      NODE_ENV: production

# compose.override.yaml (auto-loaded in dev)
services:
  app:
    build: .
    volumes:
      - ./src:/app/src
    environment:
      NODE_ENV: development
      DEBUG: "true"
    ports:
      - "9229:9229"  # debugger
```

`docker compose up` automatically merges `compose.yaml` + `compose.override.yaml`.

For production: `docker compose -f compose.yaml -f compose.prod.yaml up` (explicitly skip override).

## Networking Best Practices

1. **Always use custom bridge networks** (not default `docker0`): enables DNS resolution by container name
2. **Disable userland proxy**: `"userland-proxy": false` in daemon.json for better performance
3. **Avoid `--network host`** unless benchmarking or truly needed: breaks container isolation
4. **Segment networks**: Put frontend, backend, and database on separate networks; only connect services that need to communicate
5. **Use IPAM configuration** to avoid subnet conflicts with your LAN/VPN

## Upgrade and Migration

### Docker Engine Upgrade Procedure

1. Check release notes for breaking changes (API minimum version, removed features)
2. Back up `/var/lib/docker/` and `/etc/docker/daemon.json`
3. Stop running containers or enable `live-restore`
4. Update packages: `apt-get update && apt-get install docker-ce docker-ce-cli containerd.io`
5. Verify: `docker version`, `docker info`, `docker ps`
6. Test critical workloads before production rollout

### Docker Engine v29 Migration Notes

- **containerd image store** is now default: existing images may need re-pull if switching from legacy graphdriver
- **API minimum 1.44**: Clients using older API versions must upgrade
- **devicemapper and aufs removed**: Migrate to overlay2 before upgrading
- **nftables**: Still experimental, opt-in via daemon.json
