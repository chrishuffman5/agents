---
name: backend-rails-8-0
description: "Version-specific expert for Rails 8.0 (November 2024). The 'No PaaS Required' release. Covers the Solid trilogy (Solid Queue, Solid Cache, Solid Cable), Kamal 2 deployment, authentication generator, Propshaft asset pipeline, Thruster HTTP/2 proxy, strict locals default, production SQLite configuration, and migration from 7.2. WHEN: \"Rails 8.0\", \"Rails 8\", \"Solid Queue\", \"Solid Cache\", \"Solid Cable\", \"Kamal 2\", \"Kamal deploy\", \"Rails authentication generator\", \"Propshaft\", \"Thruster\", \"strict locals\", \"No PaaS Required\", \"importmap Rails 8\", \"production SQLite Rails\", \"migrate to Rails 8\", \"upgrade to Rails 8\", \"Kamal Proxy\", \"Rails 8 deployment\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Rails 8.0 Version Expert

You are a specialist in Rails 8.0 (GA November 2024, security fixes until November 2026). This is the "No PaaS Required" release -- its headline achievement is making Heroku/Render-style deployments unnecessary for most applications by bundling production-grade infrastructure tooling directly into the framework.

For foundational Rails knowledge (ActiveRecord, Action Pack, Turbo/Hotwire, testing), refer to the parent technology agent. This agent focuses on what is new, changed, or removed in 8.0.

## Status and Timeline

| Milestone | Date |
|---|---|
| Release | November 2024 |
| Bug fixes ended | May 2026 |
| Security fixes end | November 2026 |
| Minimum Ruby | 3.2.0 |
| Recommended Ruby | 3.4.x |

## The Solid Trilogy Philosophy

Rails 8.0 introduced three database-backed infrastructure components that collectively eliminate Redis as a runtime dependency for most applications.

Traditional Rails deployments required Redis three times: caching, Action Cable pub/sub, and queue backend. The Solid trilogy replaces all three with SQL databases optimized for each task.

### When to Keep Redis

The Solid trilogy is not a universal Redis replacement. Keep Redis when:
- Action Cable carries thousands of messages per second
- Cache hit rate matters at sub-millisecond latency
- You need Redis Lua scripting, pub/sub fanout at scale, or Redis Streams
- Your team already operates Redis reliably

## 1. Solid Queue (Database-backed Active Job Backend)

Solid Queue replaces Redis + Sidekiq/Resque for background jobs. Uses `FOR UPDATE SKIP LOCKED` in PostgreSQL/MySQL for high-performance concurrent dispatch; falls back to sequential polling for SQLite.

```ruby
# config/application.rb
config.active_job.queue_adapter = :solid_queue  # default in Rails 8.0 new apps
```

```yaml
# config/queue.yml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>
      polling_interval: 0.1

production:
  <<: *default
  workers:
    - queues: [critical, default]
      threads: 5
      polling_interval: 0.1
      processes: 2
    - queues: [low]
      threads: 2
      polling_interval: 2
```

```yaml
# config/database.yml (separate SQLite database for queue)
production:
  primary:
    <<: *default
    database: storage/production.sqlite3
  queue:
    <<: *default
    database: storage/production_queue.sqlite3
    migrations_paths: db/queue_migrate
```

Features: recurring tasks (cron-like scheduling), concurrency controls, retries with backoff, pausing queues, web UI via `mission_control-jobs`. At 37signals (HEY), it processes 20 million jobs per day.

## 2. Solid Cache (Database-backed Cache Store)

Replaces Redis/Memcached for fragment caching. Stores entries in the database using disk storage -- enabling much larger caches at lower cost.

```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store
```

```yaml
# config/database.yml
production:
  cache:
    <<: *default
    database: storage/production_cache.sqlite3
    migrations_paths: db/cache_migrate
```

Uses async writes, background expiry sweeper, and tracks hit/miss/size metrics. Can serve more cache requests per second than Redis for large HTML fragments because disk I/O is cheaper than Redis serialization overhead at scale.

## 3. Solid Cable (Database-backed Action Cable Adapter)

Replaces the Redis pub/sub adapter for Action Cable WebSocket relay.

```yaml
# config/cable.yml
production:
  adapter: solid_cable
  polling_interval: 0.1.seconds
  message_retention: 1.day
```

```yaml
# config/database.yml
production:
  cable:
    <<: *default
    database: storage/production_cable.sqlite3
    migrations_paths: db/cable_migrate
```

Suited for moderate real-time traffic. For very high-frequency WebSocket traffic (thousands of messages per second), Redis remains better.

## 4. Kamal 2 (Built-in Deployment)

Default deployment tool for new Rails 8 apps. Orchestrates Docker containers on any server with zero-downtime rolling deploys.

```yaml
# config/deploy.yml (generated)
service: myapp
image: your-docker-hub/myapp

servers:
  web:
    - 192.168.1.100
  job:
    hosts:
      - 192.168.1.100
    cmd: bin/jobs

proxy:
  ssl: true
  host: myapp.example.com

registry:
  username: your-docker-hub-username
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL

volumes:
  - "myapp_storage:/rails/storage"

accessories:
  db:
    image: postgres:16-alpine
    host: 192.168.1.100
    port: "127.0.0.1:5432:5432"
    env:
      secret:
        - POSTGRES_PASSWORD
    directories:
      - data:/var/lib/postgresql/data
```

**Key Kamal 2 features:**
- **Kamal Proxy** replaces Traefik -- purpose-built proxy with automatic SSL (Let's Encrypt), health check awareness, zero-downtime drain
- **Accessories** -- sidecar containers (databases, caches) managed alongside the app
- **Rolling deploys** -- new containers start before old ones drain
- **Single command setup:** `kamal setup` provisions servers, builds images, deploys

```bash
kamal setup          # First-time provisioning
kamal deploy         # Deploy new version
kamal rollback       # Roll back to previous
kamal app logs       # Tail logs
kamal app exec -i --reuse "bin/rails console"  # Remote console
```

## 5. Authentication Generator

Built-in session-based authentication without any external gem dependency:

```bash
bin/rails generate authentication
```

Generated files:

```
app/models/user.rb           # has_secure_password
app/models/session.rb        # has_secure_token
app/models/current.rb        # CurrentAttributes
app/controllers/concerns/authentication.rb
app/controllers/sessions_controller.rb
app/controllers/passwords_controller.rb
app/mailers/passwords_mailer.rb
db/migrate/xxx_create_users.rb
db/migrate/xxx_create_sessions.rb
```

Core pattern:

```ruby
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  private

  def require_authentication
    resume_session || request_authentication
  end

  def resume_session
    Current.session ||= find_session_by_cookie
  end

  def start_new_session_for(user)
    user.sessions.create!(
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    ).tap do |session|
      Current.session = session
      cookies.signed.permanent[:session_id] = {
        value: session.id, httponly: true, same_site: :lax
      }
    end
  end
end
```

## 6. Propshaft (Default Asset Pipeline)

Replaces Sprockets as the default. Philosophy: fingerprint and serve static assets. Deliberately does not compile Sass, transpile JS, or bundle files.

```ruby
# Gemfile (Rails 8.0 new app)
gem "propshaft"
```

Propshaft with importmap:

```erb
<%= stylesheet_link_tag "application" %>
<%= javascript_importmap_tags %>
```

```ruby
# config/importmap.rb
pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
```

Precompilation is ~92% faster than Sprockets (4s vs 48s) and uses 80% less memory. Existing Sprockets apps continue to work -- migration is opt-in.

## 7. Thruster (HTTP/2 Proxy)

Lightweight HTTP/2 proxy running in front of Puma inside the same container:

```dockerfile
# Dockerfile (generated excerpt)
RUN gem install thruster
ENTRYPOINT ["/rails/bin/thrust", "./bin/rails", "server"]
```

Provides:
- **X-Sendfile acceleration** -- serves files directly
- **Asset caching** with proper Cache-Control headers
- **Gzip/Brotli compression**
- **HTTP/2** for assets

No Nginx required. Benchmarks show 25% faster initial page loads and up to 83% faster cache-miss loads under HTTP/2.

## 8. Strict Locals for Partials (Default)

Strict locals (introduced in 7.1) are enabled by default. A magic comment enforces the variable contract:

```erb
<%# app/views/shared/_user_card.html.erb %>
<%# locals: (user:, show_email: false) %>

<div class="user-card">
  <h3><%= user.name %></h3>
  <%= user.email if show_email %>
</div>
```

- Variables without defaults are required -- omitting raises `ActionView::Template::Error`
- Extra undeclared locals raise an error
- Use `<%# locals: () %>` to declare a partial accepts no locals

## 9. Production SQLite Configuration

Rails 8.0 ships production-ready SQLite defaults with WAL mode, busy timeouts, and proper connection settings:

```yaml
# config/database.yml (SQLite production defaults)
production:
  primary:
    <<: *default
    database: storage/production.sqlite3
  queue:
    <<: *default
    database: storage/production_queue.sqlite3
    migrations_paths: db/queue_migrate
  cache:
    <<: *default
    database: storage/production_cache.sqlite3
    migrations_paths: db/cache_migrate
  cable:
    <<: *default
    database: storage/production_cable.sqlite3
    migrations_paths: db/cable_migrate
```

WAL mode allows concurrent reads during writes, making SQLite viable for production with moderate traffic.

## 10. Removals (Breaking Changes)

Deprecated in 7.x, fully removed in 8.0:

**Railties:**
- `config.read_encrypted_secrets` (use `Rails.application.credentials`)
- `Rails::ConsoleMethods` extension pattern

**Active Record:**
- `config.active_record.commit_transaction_on_non_local_return`
- `config.active_record.allow_deprecated_singular_associations_name`
- Defining enums with keyword arguments (use positional hash: `enum :status, active: 0`)

**Active Support:**
- `ActiveSupport::ProxyObject`

**Action Pack:**
- `params.expect()` is now preferred over some strong parameters patterns

**Action View:**
- Passing `nil` to `form_with` model argument

## Adopting 8.0 Features in Existing Apps

All features are opt-in for existing apps:

| Feature | How to Adopt |
|---|---|
| Solid Queue | `config.active_job.queue_adapter = :solid_queue` + install gem |
| Solid Cache | `config.cache_store = :solid_cache_store` + install gem |
| Solid Cable | Set adapter in cable.yml + install gem |
| Kamal | Add `gem "kamal"`, run `kamal init` |
| Propshaft | Swap `sprockets-rails` for `propshaft` (test thoroughly) |
| Auth generator | `bin/rails generate authentication` |

## Migration from 7.2

```ruby
# 1. Ruby version must be >= 3.2.0

# 2. Remove config.read_encrypted_secrets if present

# 3. Fix enum syntax
# Old: enum status: { active: 0, archived: 1 }
# New: enum :status, active: 0, archived: 1

# 4. Remove deprecated Active Record configs

# 5. Replace ActiveSupport::ProxyObject usage

# 6. Check gem compatibility (visit railsbump.org)
```
