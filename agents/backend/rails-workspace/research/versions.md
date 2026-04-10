# Rails Version Reference: 7.2, 8.0, 8.1

> **Coverage:** Rails 7.2 (maintenance until Aug 2026), Rails 8.0 (Nov 2024), Rails 8.1 (Oct 2025, current)
> **Last updated:** April 2026

---

## Ruby Version Requirements

| Rails Version | Minimum Ruby | Recommended Ruby | Status |
|---|---|---|---|
| 7.2.x | Ruby 3.1.0 | Ruby 3.4.x | Security fixes only; EOL Aug 2026 |
| 8.0.x | Ruby 3.2.0 | Ruby 3.4.x | Security fixes until Nov 2026 |
| 8.1.x | Ruby 3.2.0 | Ruby 3.4.x | Current; bug fixes until Oct 2026 |

Rails 7.2 dropped support for Ruby 2.x and any Ruby 3.0 installations. Rails 8.0 raised the bar to 3.2, which is required to take advantage of YJIT improvements that 8.0 relies on.

---

## Rails 7.2

Released: August 2024 | Maintenance end: August 2026 (security only)

### Dev Containers

Rails 7.2 ships with built-in dev container support via Docker Dev Containers specification. Generate on a new app or retrofit an existing one:

```bash
# New app with dev container
rails new myapp --devcontainer

# Add to existing app
rails devcontainer
```

The generated `.devcontainer/` directory includes Redis, your chosen database (SQLite/Postgres/MySQL/MariaDB), Headless Chrome for system tests, and Active Storage preview support. Teams using VS Code or GitHub Codespaces get a fully reproducible development environment without local dependency installation.

### Default Health Check Endpoint

New apps get a `/up` endpoint automatically. It returns HTTP 200 if the application is booted and able to respond, HTTP 500 otherwise. No controller code required — it is wired into the router automatically.

```ruby
# config/routes.rb (generated)
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  # ...
end
```

Kamal and load balancers use this endpoint for zero-downtime deployment readiness checks.

### Browser Version Guard

A new `allow_browser` class-level macro lets controllers enforce minimum browser versions. Unknown browsers are permitted; only browsers matching the hash with versions below the threshold receive a 406.

```ruby
class ApplicationController < ActionController::Base
  # Block browsers that don't support modern CSS/JS
  allow_browser versions: :modern
end

class AdminController < ApplicationController
  # More granular per-browser control
  allow_browser versions: { safari: 16.4, chrome: 110, firefox: 121, ie: false }
end
```

Blocked browsers receive a 406 response served from `public/406-unsupported-browser.html` — a static file you can customize.

### Brakeman Security Scanner (Default)

Brakeman, the static analysis security scanner for Rails, is now included in generated GitHub Actions CI workflows by default. It scans for SQL injection, XSS, mass assignment issues, and other common vulnerabilities on every push.

```yaml
# .github/workflows/ci.yml (generated)
jobs:
  scan_ruby:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true
      - run: bin/brakeman --no-pager
```

`brakeman` is added to the `Gemfile` in the `development` group.

### Improved `bin/setup`

The generated `bin/setup` script now includes guidance for `puma-dev`, the recommended approach for running multiple local Rails apps without port conflicts or Docker overhead.

```bash
# bin/setup (excerpt)
echo "== Installing dependencies =="
bundle install

echo "== Preparing database =="
bin/rails db:prepare

echo "== Removing old logs and tempfiles =="
bin/rails log:clear tmp:clear

echo "== Restarting application server =="
bin/rails restart

# Puma-dev suggestion added in 7.2
echo "Consider using puma-dev for zero-config local SSL and multi-app routing:"
echo "  brew install puma/puma/puma-dev && sudo puma-dev -setup && puma-dev -install"
```

### YJIT Enabled by Default

Ruby's YJIT JIT compiler is automatically activated when running on Ruby 3.3+. Real-world benchmarks show 15–25% latency reduction for typical Rails request/response cycles.

```ruby
# config/application.rb (default in 7.2)
# YJIT is enabled automatically on Ruby 3.3+ — nothing to configure.
# To explicitly disable:
Rails.application.config.yjit = false
```

YJIT works best for code with diverse execution paths (typical of Rails apps) and is most impactful in production where GC pressure from many short-lived objects is high.

### Progressive Web App (PWA) Support

New apps include scaffold files for PWA functionality:

```
app/views/pwa/
├── manifest.json.erb   # Web app manifest (name, icons, theme color)
└── service_worker.js   # Offline caching strategy
```

Both files are served via ERB so you can inject dynamic values (app name, version, etc.). Routes are wired automatically:

```ruby
# config/routes.rb (generated)
get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
```

### Puma Thread Count Default Change

The default Puma thread count dropped from 5 to 3 per worker process. This reduces memory usage and avoids database connection pool saturation on typical hardware:

```ruby
# config/puma.rb
# Old default (pre-7.2)
threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)

# New default (7.2+)
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count
```

The 3-thread default is based on production data from 37signals and the broader community. Increase it only after profiling your specific workload.

### Active Job Transaction Safety (7.2)

Jobs enqueued inside an Active Record transaction now automatically defer until after the transaction commits. This prevents the race condition where a background worker picks up a job before the database write is visible.

```ruby
# Before 7.2: job could be processed before the transaction committed
ActiveRecord::Base.transaction do
  user = User.create!(name: "Alice")
  WelcomeEmailJob.perform_later(user.id)  # risky: worker might run before commit
end

# In 7.2: job is held until after commit automatically
# No code change needed — behavior is now the safe default
```

### Transaction Callbacks (7.2)

Active Record transactions now yield an `ActiveRecord::Transaction` object that supports `after_commit` callbacks outside of models:

```ruby
ActiveRecord::Base.transaction do |tx|
  user = User.create!(name: "Alice")
  tx.after_commit { AuditLog.record("user_created", user.id) }
end

# Also available globally:
ActiveRecord.after_all_transactions_commit { PushNotifier.flush }
```

### Other 7.2 Changes

- **RuboCop configured by default** using `rubocop-rails-omakase` for consistent style
- **GitHub Actions CI** workflow generated automatically (Ruby scanning, linting, tests)
- **Dockerfile optimization**: includes `jemalloc` to reduce memory fragmentation for multi-threaded Puma

---

## Rails 8.0

Released: November 2024 | Security fixes until: November 2026

The 8.0 release is branded "No PaaS Required" — its headline achievement is making Heroku/Render-style deployments unnecessary for most applications by bundling production-grade infrastructure tooling directly into the framework.

### Kamal 2 (Built-in Deployment)

Kamal 2 is the default deployment tool for new Rails 8 apps. It orchestrates Docker containers on any server (cloud VM, VPS, bare metal) with zero-downtime rolling deploys. The `kamal` gem is added to the `Gemfile`, and `config/deploy.yml` is generated with sensible defaults.

```yaml
# config/deploy.yml (generated, simplified)
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
  # Kamal Proxy handles SSL via Let's Encrypt automatically

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

Key Kamal 2 features:
- **Kamal Proxy** replaces Traefik — a purpose-built proxy with automatic SSL (Let's Encrypt), health check awareness, and zero-downtime drain behavior
- **Accessories** are sidecar services (databases, caches, queues) managed alongside your app
- **Rolling deploys** spin up new containers before draining old ones — no downtime
- **Single command** setup: `kamal setup` provisions servers, builds images, and deploys

```bash
# Common Kamal commands
kamal setup          # First-time server provisioning
kamal deploy         # Deploy a new version
kamal rollback       # Roll back to the previous version
kamal app logs       # Tail application logs
kamal app exec -i --reuse "bin/rails console"  # Remote Rails console
```

### Solid Queue (Database-backed Active Job Backend)

Solid Queue replaces Redis + Sidekiq/Resque for background job processing. It uses `FOR UPDATE SKIP LOCKED` in PostgreSQL/MySQL for high-performance concurrent job dispatch, and falls back to sequential polling for SQLite.

```ruby
# config/application.rb
config.active_job.queue_adapter = :solid_queue  # default in Rails 8.0 new apps

# Gemfile (auto-included)
gem "solid_queue"
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
# config/database.yml (separate SQLite database for queue in SQLite setups)
production:
  primary:
    <<: *default
    database: storage/production.sqlite3
  queue:
    <<: *default
    database: storage/production_queue.sqlite3
    migrations_paths: db/queue_migrate
```

Solid Queue provides recurring tasks (cron-like scheduling), concurrency controls, retries with backoff, and pausing queues — the full feature set needed by most applications. At 37signals (HEY), it processes 20 million jobs per day.

### Solid Cache (Database-backed Cache Store)

Solid Cache replaces Redis or Memcached for fragment caching. It stores cache entries in the database (typically a dedicated SQLite file or table) using disk storage instead of RAM — enabling much larger caches at lower cost.

```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store

# Gemfile
gem "solid_cache"
```

```yaml
# config/database.yml
production:
  cache:
    <<: *default
    database: storage/production_cache.sqlite3
    migrations_paths: db/cache_migrate
```

Solid Cache is tuned for cache workloads: it uses async writes, a background expiry sweeper, and tracks hit/miss/size metrics. Benchmarks show it can serve more cache requests per second than Redis at the same hardware cost because disk I/O is less expensive than the Redis serialization overhead for large HTML fragments.

### Solid Cable (Database-backed Action Cable Adapter)

Solid Cable replaces the Redis pub/sub adapter for Action Cable WebSocket message relay. Messages are stored in the database and delivered via fast polling.

```ruby
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

Solid Cable is suited for applications with moderate real-time traffic. For very high-frequency WebSocket traffic (thousands of messages per second), Redis remains the better option.

### Propshaft (Default Asset Pipeline)

Propshaft replaces Sprockets as the default asset pipeline for new Rails 8 apps. Its philosophy: do one thing perfectly — fingerprint and serve static assets. It deliberately does not compile Sass, transpile JavaScript, or bundle files.

```ruby
# Gemfile (Rails 8.0 new app)
gem "propshaft"  # replaces sprockets

# app/assets/images/logo.png is served at:
# /assets/logo-[fingerprint].png
```

Propshaft integration with importmap:

```html
<!-- app/views/layouts/application.html.erb -->
<%= stylesheet_link_tag "application" %>
<%= javascript_importmap_tags %>
```

```js
// config/importmap.rb
pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
```

Propshaft asset precompilation is approximately 92% faster than Sprockets (48 seconds vs. 4 seconds in benchmarks) and uses 80% less memory. Existing apps using Sprockets continue to work — migration is opt-in.

### Authentication Generator

Rails 8.0 ships a built-in authentication generator that creates a session-based, password-resettable, metadata-tracking authentication system without any external gem dependency.

```bash
bin/rails generate authentication
```

Generated files:

```
app/
├── models/
│   ├── user.rb
│   ├── session.rb
│   └── current.rb        # CurrentAttributes — Current.user
├── controllers/
│   ├── concerns/
│   │   └── authentication.rb   # require_authentication before_action
│   ├── sessions_controller.rb
│   └── passwords_controller.rb
├── mailers/
│   └── passwords_mailer.rb
└── views/
    ├── sessions/
    └── passwords/
db/migrate/
├── xxx_create_users.rb
└── xxx_create_sessions.rb
```

Core authentication concern:

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  private

  def authenticated?
    resume_session
  end

  def require_authentication
    resume_session || request_authentication
  end

  def resume_session
    Current.session ||= find_session_by_cookie
  end

  def start_new_session_for(user)
    user.sessions.create!(
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    ).tap { |session| cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax } }
  end
end
```

The `Session` model uses `has_secure_token` for tamper-proof session tokens. The `User` model uses `has_secure_password` (bcrypt). No Devise, no third-party gem required.

### Thruster (HTTP/2 Proxy)

The generated `Dockerfile` includes Thruster, a lightweight HTTP/2 proxy that runs in front of Puma inside the same container:

```dockerfile
# Dockerfile (Rails 8.0 generated, excerpt)
# Install Thruster
RUN gem install thruster

# Start via Thruster → Puma
ENTRYPOINT ["/rails/bin/thrust", "./bin/rails", "server"]
```

Thruster provides:
- **X-Sendfile acceleration** — serves files directly without routing through Rails
- **Asset caching** with proper Cache-Control headers
- **Gzip/Brotli compression** of responses
- **HTTP/2 push** for assets

No Nginx required in front of the container. Community benchmarks show 25% faster initial page loads and up to 83% faster cache-miss loads under HTTP/2 compared to HTTP/1.1 Puma alone.

### Strict Locals for Partials (On by Default)

Strict locals were introduced in Rails 7.1; Rails 8.0 enables them by default for all new apps. A magic comment at the top of a partial enforces its variable contract:

```erb
<%# app/views/shared/_user_card.html.erb %>
<%# locals: (user:, show_email: false) %>

<div class="user-card">
  <h3><%= user.name %></h3>
  <%= user.email if show_email %>
</div>
```

- Variables without defaults are required — omitting them raises `ActionView::Template::Error`
- Extra undeclared locals raise an error instead of being silently ignored
- Use `<%# locals: () %>` to explicitly declare a partial accepts no locals

```erb
<%# Partial that accepts no locals %>
<%# locals: () %>
<footer>© <%= Time.current.year %></footer>
```

### New Default SQLite Configuration for Production

Rails 8.0 ships with a production-ready SQLite configuration that enables WAL mode, busy timeouts, and proper connection settings:

```yaml
# config/database.yml (SQLite production defaults in Rails 8.0)
default: &default
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>
  timeout: 5000

production:
  primary:
    <<: *default
    database: storage/production.sqlite3
    # WAL mode enabled by default via sqlite3_adapter_strict_strings_by_default
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

WAL mode allows concurrent reads while a write is in progress, making SQLite viable for production applications with moderate traffic. `storage/` is a Docker volume in the generated Dockerfile.

### Rails 8.0 Removals (Breaking Changes)

The following were deprecated in 7.x and fully removed in 8.0:

**Railties:**
- `config.read_encrypted_secrets` (use `Rails.application.credentials` instead)
- `rails/console/app` and `rails/console/helpers` file extensions
- `Rails::ConsoleMethods` extension pattern

**Active Record:**
- `config.active_record.commit_transaction_on_non_local_return`
- `config.active_record.allow_deprecated_singular_associations_name`
- `config.active_record.warn_on_records_fetched_greater_than`
- `config.active_record.sqlite3_deprecated_warning`
- `ENV["SCHEMA_CACHE"]` environment variable
- Defining enums with keyword arguments (use positional hash syntax)

**Active Support:**
- `ActiveSupport::ProxyObject`
- `attr_internal_naming_format` with `@` prefix

**Action Pack:**
- `config.action_controller.allow_deprecated_parameters_hash_equality`
- `params.expect()` is now the preferred alternative to strong parameters patterns

**Action View:**
- Passing `nil` to `form_with` model argument
- Passing content to void tag elements via tag builder

---

## Rails 8.1

Released: October 22, 2025 | Current stable | Bug fixes until Oct 2026

Rails 8.1 represents 2500 commits from 500+ contributors. It was already running in production at Shopify and 37signals (HEY) before release.

### Active Job Continuations

The most significant new feature in 8.1. Long-running jobs can now be split into discrete steps that checkpoint progress. If a job is interrupted (deploy, server restart, timeout), it resumes from the last completed step rather than restarting from zero.

Include `ActiveJob::Continuable` and define steps using the `step` method:

```ruby
class ImportUsersJob < ApplicationJob
  include ActiveJob::Continuable

  def perform(file_path)
    # Block steps run once and do not checkpoint within themselves
    step :load_file do
      @records = CSV.read(file_path, headers: true)
    end

    # Cursor steps track position — safe to interrupt mid-batch
    step :import_rows do |step|
      @records.drop(step.cursor).each_with_index do |row, index|
        User.create!(
          email: row["email"],
          name: row["name"]
        )
        # Persist cursor after each record
        step.advance! from: step.cursor + 1
      end
    end

    step :finalize
  end

  private

  def finalize
    Rails.logger.info "Import complete. #{User.count} users in database."
    ImportCompletedMailer.notify.deliver_later
  end
end
```

Step types:
- **Block steps** — execute once; if interrupted they re-run on resume (keep them idempotent)
- **Cursor steps** — checkpoint with `step.advance!`; resume skips already-processed records
- **Method steps** — reference a private method by symbol: `step :finalize`

This is particularly valuable for Kamal deployments, which give job containers 30 seconds to shut down gracefully. A job that checkpoints every few records never loses more than one batch.

### Structured Event Reporting

A new `Rails.event` reporter provides a unified interface for structured, machine-readable events — distinct from logs (human-readable) and metrics (numeric aggregations).

```ruby
# Basic event
Rails.event.notify("user.signup", user_id: user.id, email: user.email, plan: user.plan)

# With tags
Rails.event.notify("payment.failed", amount: charge.amount, tags: ["billing", "stripe"])

# Setting context for all events in a request
class ApplicationController < ActionController::Base
  before_action :set_event_context

  private

  def set_event_context
    Rails.event.set_context(
      request_id: request.request_id,
      user_id: current_user&.id,
      tenant: current_tenant&.slug
    )
  end
end
```

Custom subscribers implement `#emit` to forward events to your observability platform:

```ruby
class DatadogEventSubscriber
  def emit(event)
    Datadog::Statsd.new.event(
      event[:name],
      event[:payload].to_json,
      tags: event[:tags]
    )
  end
end

Rails.event.subscribe(DatadogEventSubscriber.new)
```

### Rate Limiting — `ActionController::TooManyRequests`

Rate limiting (introduced in Rails 8.0) was enhanced in 8.1 to raise `ActionController::TooManyRequests` instead of issuing a bare `head :too_many_requests`. This enables proper rescue and custom error handling:

```ruby
class SessionsController < ApplicationController
  # 10 login attempts per 3 minutes per IP
  rate_limit to: 10, within: 3.minutes, only: :create

  def create
    # ...
  end
end

# Custom response via with:
class ApiController < ApplicationController
  rate_limit to: 100, within: 1.minute,
             with: -> { render json: { error: "Rate limit exceeded", retry_after: 60 }, status: :too_many_requests }
end

# Global rescue in ApplicationController
class ApplicationController < ActionController::Base
  rescue_from ActionController::TooManyRequests do |e|
    render "errors/rate_limited", status: :too_many_requests
  end
end
```

### Markdown Rendering Support

Controllers can now respond to `format.md` directly. Rails recognizes `.md` and `.markdown` as first-class MIME types:

```ruby
class DocumentsController < ApplicationController
  def show
    @document = Document.find(params[:id])

    respond_to do |format|
      format.html
      format.md { render markdown: @document.body }
      format.json { render json: @document }
    end
  end
end
```

Models can define `to_markdown` for serialization:

```ruby
class Article < ApplicationRecord
  def to_markdown
    "# #{title}\n\n#{body}"
  end
end
```

This reflects Rails' embrace of Markdown as the lingua franca of AI — particularly useful for applications serving LLM agents or AI-readable content endpoints.

### Local CI (`config/ci.rb` + `bin/ci`)

Rails 8.1 adds a built-in CI declaration DSL that runs locally, reducing dependence on cloud CI for feedback during development:

```ruby
# config/ci.rb
ci do
  step "lint" do
    run "bin/rubocop"
  end

  step "security" do
    run "bin/brakeman --no-pager"
  end

  step "test" do
    run "bin/rails test"
    run "bin/rails test:system"
  end
end
```

```bash
# Run the full suite locally
bin/ci

# HEY's 30,000+ assertion suite completes in:
# - 1m 23s on Framework Desktop 16
# - 2m 22s on M4 Max MacBook Pro
```

Optional GitHub CLI integration can mark PRs as ready for merge after local CI passes.

### Deprecated Associations

Active Record associations can now be individually deprecated, enabling gradual schema migrations without breaking existing code:

```ruby
class Post < ApplicationRecord
  belongs_to :author

  # Mark old association as deprecated
  has_many :comments, deprecated: true
  has_many :feedback_items  # the replacement
end
```

Three reporting modes:

```ruby
# :warn (default) — logs a deprecation warning
has_many :old_tags, deprecated: true

# :raise — raises ActiveRecord::DeprecatedAssociationError
has_many :old_tags, deprecated: :raise

# :notify — fires a notification via ActiveSupport::Notifications
has_many :old_tags, deprecated: :notify
```

Deprecation is tracked across direct calls (`post.comments`), eager loading (`.includes(:comments)`), and nested attributes.

### Registry-Free Kamal Deployments (8.1 + Kamal 2.8+)

Kamal 2.8 defaults to local image registries, eliminating the requirement for Docker Hub, GHCR, or any remote registry for basic deployments. Images are built and transferred directly to servers.

```yaml
# config/deploy.yml — no registry block required for local mode
service: myapp
image: myapp

# Kamal credentials can now pull from Rails encrypted credentials
# rails credentials:fetch kamal.registry_password
```

```bash
# Fetch a specific credential for Kamal secrets
KAMAL_REGISTRY_PASSWORD=$(bin/rails credentials:fetch kamal.registry_password)
```

### Rails 8.1 Removals (Breaking Changes)

**Active Record:**
- Removed `:retries` option for SQLite3 adapter (use `:timeout` instead)
- Removed `:unsigned_float` and `:unsigned_decimal` column methods for MySQL

**Action Pack:**
- Removed leading bracket support in parameter parsing
- Removed semicolon as query string separator
- Removed route-to-multiple-paths support (define separate routes)

**Active Job:**
- Removed support for `enqueue_after_transaction_commit` options (now always-on behavior)
- Removed built-in SuckerPunch adapter (install `sucker_punch` gem for adapter)

**Active Support:**
- Removed `Time` object passing to `Time#since`
- Removed `Benchmark.ms` method
- Removed `Time` addition with `ActiveSupport::TimeWithZone`

**Railties:**
- Removed `bin/rake stats` (use `bin/rails stats`)
- Removed `rails/console/methods.rb` file

**Active Storage:**
- Removed `:azure` storage service (use `azure_storage` gem or S3-compatible alternatives)

### Rails 8.1 Deprecations

- Order-dependent finder methods (`#first`, `#last`) without explicit ordering on the relation
- `ActiveRecord::Base.signed_id_verifier_secret` — use `Rails.application.message_verifiers` instead
- `String#mb_chars` and `ActiveSupport::Multibyte::Chars` — use `String` methods directly
- `ActiveSupport::Configurable` module
- Built-in Sidekiq adapter — the `sidekiq` gem now ships its own Rails adapter

---

## The "Solid" Trilogy Philosophy

Rails 8.0 introduced three database-backed infrastructure components that collectively eliminate Redis as a runtime dependency for most applications.

### The Problem They Solve

Traditional Rails deployments required:
- **Redis** for caching (fragment caches, session stores)
- **Redis** again for Action Cable pub/sub
- **Redis** a third time for Sidekiq/Resque queue backend
- Operational complexity: Redis clustering, persistence config, memory management

The Solid trilogy replaces all three use cases with SQL databases — specifically optimized for the task.

### Solid Queue (Jobs)

```
Database → FOR UPDATE SKIP LOCKED → Dispatched to Workers → Executed
```

- PostgreSQL and MySQL use `FOR UPDATE SKIP LOCKED` — no polling contention
- SQLite uses sequential polling (fine for single-server deployments)
- Ships with supervisor, dispatcher, scheduler (recurring tasks), and web UI via `mission_control-jobs`

### Solid Cache (Caching)

```
Fragment render → Cache write (async) → DB row with key/value/expiry
Background sweeper → Prune expired entries
```

- Stores entries as binary blobs, supports any cacheable Ruby object
- Async writes mean cache misses don't add latency to the request path
- Disk-based storage allows caches 10x–100x larger than RAM-constrained Redis

### Solid Cable (WebSockets)

```
ActionCable broadcast → DB insert → Fast polling by subscribers → WebSocket push
```

- Default polling interval: 0.1 seconds (configurable)
- Messages retained for 1 day (configurable)
- Suitable for real-time features with moderate message rates (< ~1000/sec per server)

### When to Keep Redis

The Solid trilogy is not a universal Redis replacement. Keep Redis when:
- Action Cable carries thousands of messages per second
- Cache hit rate matters at millisecond latency (Redis is faster than disk I/O for tiny values)
- You need Redis Lua scripting, pub/sub fanout at scale, or Redis Streams
- Your team already operates Redis reliably and gains nothing from consolidation

---

## Kamal Deployment Model

Kamal is a Docker-based deployment orchestrator built by 37signals. It is the answer to "how do I deploy Rails without Heroku?"

### Architecture

```
Developer Machine
  → docker build
  → push image to registry (or local transfer in Kamal 2.8+)

Kamal CLI (your machine)
  → SSH into servers
  → docker pull new image
  → Start new container (health check waits for /up 200)
  → Kamal Proxy begins routing to new container
  → Old container drains (SIGTERM, 30-second window)
  → Old container stops
```

### Key Concepts

**Kamal Proxy** — Replaces Traefik. A purpose-built HTTP/HTTPS proxy that:
- Manages TLS via Let's Encrypt automatically
- Routes between old/new containers during deploys
- Provides health-check-aware zero-downtime transitions

**Accessories** — Sidecar containers (databases, caches, etc.) managed alongside the app:

```yaml
# config/deploy.yml
accessories:
  db:
    image: postgres:16-alpine
    host: 192.168.1.100
    port: "127.0.0.1:5432:5432"
    env:
      secret: [POSTGRES_PASSWORD]
    directories:
      - data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    host: 192.168.1.100
    port: "127.0.0.1:6379:6379"

  litestream:
    image: litestream/litestream
    host: 192.168.1.100
    volumes:
      - "./litestream.yml:/etc/litestream.yml"
      - "myapp_storage:/rails/storage"
```

**Roles** — Different server types can run different commands:

```yaml
servers:
  web:
    hosts:
      - 192.168.1.100
      - 192.168.1.101
  job:
    hosts:
      - 192.168.1.102
    cmd: bin/jobs       # runs Solid Queue supervisor
```

### Zero-Downtime Deploy Flow

```bash
kamal deploy
# 1. Build Docker image locally
# 2. Push to registry
# 3. SSH to each server
# 4. Pull new image
# 5. Start new container on alternate port
# 6. Wait for /up health check → 200
# 7. Kamal Proxy switches traffic to new container
# 8. Send SIGTERM to old container
# 9. Wait up to 30 seconds for graceful shutdown
# 10. Stop old container
```

---

## Migration Path: 7.2 → 8.0 → 8.1

### General Approach

Always upgrade one minor version at a time. Never jump from 7.2 directly to 8.1. Deprecation warnings in each version tell you what to fix before the next version removes it.

```bash
# Step 1: Upgrade to latest 7.2 patch
bundle update rails  # pin to ~> 7.2

# Step 2: Eliminate all deprecation warnings in 7.2
# Run test suite, watch logs for "[DEPRECATION]" messages

# Step 3: Upgrade to 8.0
# Change Gemfile: gem "rails", "~> 8.0"
bundle update rails

# Step 4: Run the update task
bin/rails app:update
# Review each diff — do not blindly accept overwrites

# Step 5: Fix removed APIs, run tests
bin/rails test && bin/rails test:system

# Step 6: Upgrade to 8.1
# Change Gemfile: gem "rails", "~> 8.1"
bundle update rails
bin/rails app:update
```

### 7.2 → 8.0 Key Checklist

```ruby
# 1. Ruby version — must be >= 3.2.0
# Check: ruby --version

# 2. Remove config.read_encrypted_secrets if present
# config/application.rb
config.read_encrypted_secrets = true  # REMOVE THIS

# 3. Fix enum keyword argument syntax
# Old (removed in 8.0):
enum status: { active: 0, archived: 1 }
# New:
enum :status, active: 0, archived: 1

# 4. Update Active Record configs
# Remove from config/application.rb if present:
# config.active_record.commit_transaction_on_non_local_return
# config.active_record.allow_deprecated_singular_associations_name
# config.active_record.warn_on_records_fetched_greater_than
# config.active_record.sqlite3_deprecated_warning

# 5. Replace ActiveSupport::ProxyObject usage
# Use BasicObject or SimpleDelegator instead

# 6. Check gem compatibility — many gems need 8.0-compatible versions
# Use: bundle exec rake rails:update:gems (or check RailsBump)
```

### 8.0 → 8.1 Key Checklist

```ruby
# 1. Remove :retries option from SQLite3 adapter configuration
# Use :timeout instead
# config/database.yml — replace:
#   retries: 1000    →    timeout: 5000

# 2. Remove or gem-ify SuckerPunch if used
# gem "sucker_punch"  # add if needed
# config/application.rb:
# config.active_job.queue_adapter = :sucker_punch  # still works via gem

# 3. Fix route definitions with multiple paths
# Old (removed):
# get "/home", "/index", to: "pages#home"
# New:
# get "/home", to: "pages#home"
# get "/index", to: "pages#home"

# 4. Update Sidekiq adapter usage (if applicable)
# Add to Gemfile (adapter moved to sidekiq gem):
# gem "sidekiq"  # adapter now lives here
# No config change needed — require "sidekiq/rails" is handled by the gem

# 5. Remove Azure Active Storage service if used
# Migrate to S3, GCS, or use azure_storage gem

# 6. Fix Time arithmetic
# Old (removed): 5.minutes.since(Time.now)  when arg is a Time
# New: Time.now + 5.minutes

# 7. Remove Benchmark.ms usage
# Old: Benchmark.ms { some_code }
# New: Process.clock_gettime(Process::CLOCK_MONOTONIC) bookending
```

### Adopting New 8.x Features in Existing Apps

None of the 8.0 or 8.1 features are forced on existing apps. Adoption is opt-in:

| Feature | How to adopt |
|---|---|
| Solid Queue | `config.active_job.queue_adapter = :solid_queue` + install gem |
| Solid Cache | `config.cache_store = :solid_cache_store` + install gem |
| Solid Cable | `config.action_cable.cable = { adapter: :solid_cable }` + install gem |
| Kamal | Add `gem "kamal"`, run `kamal init` |
| Propshaft | Swap `gem "sprockets-rails"` for `gem "propshaft"` (test thoroughly) |
| Authentication generator | `bin/rails generate authentication` (creates files alongside existing auth) |
| Active Job Continuations | Add `include ActiveJob::Continuable` to individual jobs |

---

## Version Support Summary

| Version | Released | Bug Fixes Until | Security Fixes Until | Min Ruby |
|---|---|---|---|---|
| 7.1.x | Oct 2023 | Aug 2024 | Apr 2025 (EOL) | 2.7.0 |
| 7.2.x | Aug 2024 | Feb 2025 | Aug 2026 | 3.1.0 |
| 8.0.x | Nov 2024 | May 2026 | Nov 2026 | 3.2.0 |
| 8.1.x | Oct 2025 | Oct 2026 | Oct 2027 | 3.2.0 |

For production applications: upgrade off 7.2 before August 2026 (end of security patches). Rails 8.1 with Ruby 3.4 is the recommended target as of April 2026.
