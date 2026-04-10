# CircleCI Best Practices

## Config Organization

### Use Orbs for Common Tasks

```yaml
orbs:
  node: circleci/node@6.0    # Don't reinvent npm caching

jobs:
  build:
    executor: node/default
    steps:
      - checkout
      - node/install-packages    # Orb handles caching correctly
      - run: npm run build
```

### Use Executors for Consistency

```yaml
executors:
  app-executor:
    docker:
      - image: cimg/node:22.0
      - image: cimg/postgres:16.0    # Service container
        environment:
          POSTGRES_USER: test
          POSTGRES_DB: test
    resource_class: medium
    environment:
      NODE_ENV: test
```

## Caching Strategy

```yaml
# Effective cache key — invalidates when dependencies change
- restore_cache:
    keys:
      - v2-deps-{{ .Branch }}-{{ checksum "package-lock.json" }}
      - v2-deps-{{ .Branch }}-
      - v2-deps-

# Version prefix (v2-) lets you bust all caches when needed
```

### What to Cache

| Cache | Impact | Key |
|---|---|---|
| `node_modules` | High | `checksum("package-lock.json")` |
| `.pip/cache` | High | `checksum("requirements.txt")` |
| `.m2/repository` | High | `checksum("pom.xml")` |
| Docker layers | High | DLC feature (premium) |
| Build output | Medium | `checksum("src/**")` |

## Cost Optimization

1. **Right-size resource classes** — Don't use `xlarge` for `npm install`
2. **Parallelize tests** — 4x `small` is often cheaper and faster than 1x `xlarge`
3. **Cache aggressively** — Every cache miss costs build minutes
4. **Use DLC** — Docker Layer Caching saves significant time for image builds
5. **Filter branches** — Don't run full pipelines on every branch

```yaml
workflows:
  main:
    jobs:
      - build        # Always
      - test:
          requires: [build]
      - deploy:
          requires: [test]
          filters:
            branches:
              only: main    # Only deploy from main
```

## Security

1. **Use contexts** for shared secrets, restrict by security groups
2. **Never echo secrets** — even `$VARIABLE` in logs
3. **Use OIDC** for cloud auth where supported
4. **Restrict SSH access** — disable "Rerun with SSH" for production contexts
5. **Pin orb versions** — `circleci/node@6.0.1` not `circleci/node@volatile`

## Common Mistakes

1. **Not using `store_test_results`** — Without it, test splitting by timings can't optimize
2. **Workspace for dependencies** — Use cache for dependencies, workspace for build artifacts
3. **Not validating config** — Run `circleci config validate` before committing
4. **Ignoring resource classes** — Default `medium` is wasteful for small jobs, insufficient for large ones
5. **Missing fallback cache keys** — Always include partial match keys for cache restoration
