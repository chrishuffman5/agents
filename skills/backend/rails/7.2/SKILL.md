---
name: backend-rails-7-2
description: "Version-specific expert for Rails 7.2 (August 2024, maintenance mode ending August 2026). Covers dev containers, default health check endpoint, YJIT auto-enabled, Brakeman default, PWA support, browser version guard, Active Job transaction safety, transaction callbacks, and migration to 8.0. WHEN: \"Rails 7.2\", \"Rails 7.2 features\", \"dev containers Rails\", \"devcontainer Rails\", \"YJIT Rails\", \"Brakeman default\", \"allow_browser\", \"PWA Rails\", \"upgrade Rails 7.2 to 8.0\", \"Rails health check\", \"transaction callbacks Rails\", \"puma-dev\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Rails 7.2 Version Expert

You are a specialist in Rails 7.2 (GA August 2024, security-only maintenance ending August 2026). This version is in end-of-life countdown -- recommend upgrading to Rails 8.0 or 8.1 for new development.

For foundational Rails knowledge (ActiveRecord, Action Pack, Turbo/Hotwire, Active Job, testing), refer to the parent technology agent. This agent focuses on what is new or changed in 7.2.

## Status and Timeline

| Milestone | Date |
|---|---|
| Release | August 2024 |
| Bug fixes ended | February 2025 |
| Security fixes end | **August 2026** |
| Minimum Ruby | 3.1.0 |
| Recommended Ruby | 3.4.x |

**Action required:** Upgrade to Rails 8.0+ before August 2026.

## Ruby Requirements

Rails 7.2 requires Ruby 3.1.0 minimum. Ruby 2.x and 3.0 are not supported. Ruby 3.4.x is recommended for YJIT performance gains.

## 1. Dev Containers

Rails 7.2 ships with built-in Docker Dev Container support. Generate on a new app or retrofit an existing one:

```bash
# New app with dev container
rails new myapp --devcontainer

# Add to existing app
rails devcontainer
```

The generated `.devcontainer/` directory includes Redis, your chosen database, Headless Chrome for system tests, and Active Storage preview support. Teams using VS Code or GitHub Codespaces get a fully reproducible development environment.

## 2. Default Health Check Endpoint

New apps get a `/up` endpoint automatically. Returns HTTP 200 if booted, HTTP 500 otherwise. No controller code required.

```ruby
# config/routes.rb (generated)
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
end
```

Kamal and load balancers use this endpoint for readiness checks and zero-downtime deployments.

## 3. YJIT Enabled by Default

Ruby's YJIT JIT compiler is automatically activated when running on Ruby 3.3+. Real-world benchmarks show 15-25% latency reduction for typical Rails request/response cycles.

```ruby
# config/application.rb (default in 7.2)
# YJIT is enabled automatically on Ruby 3.3+ -- nothing to configure.
# To explicitly disable:
Rails.application.config.yjit = false
```

## 4. Brakeman Security Scanner (Default)

Brakeman is now included in generated GitHub Actions CI workflows. It scans for SQL injection, XSS, mass assignment, and other vulnerabilities on every push.

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

## 5. Browser Version Guard

A new `allow_browser` macro lets controllers enforce minimum browser versions:

```ruby
class ApplicationController < ActionController::Base
  allow_browser versions: :modern
end

class AdminController < ApplicationController
  allow_browser versions: { safari: 16.4, chrome: 110, firefox: 121, ie: false }
end
```

Blocked browsers receive a 406 response from `public/406-unsupported-browser.html`.

## 6. PWA Support

New apps include scaffold files for Progressive Web App functionality:

```
app/views/pwa/
  manifest.json.erb   # Web app manifest
  service_worker.js   # Offline caching strategy
```

Routes are wired automatically:

```ruby
get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
```

## 7. Active Job Transaction Safety

Jobs enqueued inside a transaction now automatically defer until after the transaction commits:

```ruby
ActiveRecord::Base.transaction do
  user = User.create!(name: "Alice")
  WelcomeEmailJob.perform_later(user.id)  # held until after commit
end
```

No code change needed -- this is the safe default in 7.2.

## 8. Transaction Callbacks

Active Record transactions now yield an `ActiveRecord::Transaction` object supporting `after_commit` callbacks outside of models:

```ruby
ActiveRecord::Base.transaction do |tx|
  user = User.create!(name: "Alice")
  tx.after_commit { AuditLog.record("user_created", user.id) }
end

# Global variant
ActiveRecord.after_all_transactions_commit { PushNotifier.flush }
```

## 9. Puma Thread Count Default

Default Puma thread count dropped from 5 to 3 per worker process, reducing memory usage and database connection pool saturation:

```ruby
# config/puma.rb (new default)
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count
```

## 10. Other Changes

- **RuboCop configured by default** using `rubocop-rails-omakase`
- **GitHub Actions CI** workflow generated automatically
- **Dockerfile optimization**: includes `jemalloc` for reduced memory fragmentation
- **Improved `bin/setup`**: includes puma-dev guidance for multi-app local development

## Migration to Rails 8.0

### Recommended Path

```bash
# 1. Upgrade to latest 7.2 patch
bundle update rails  # pin to ~> 7.2

# 2. Fix all deprecation warnings
# Run tests, watch logs for "[DEPRECATION]" messages

# 3. Upgrade to 8.0
# Gemfile: gem "rails", "~> 8.0"
bundle update rails

# 4. Run update task
bin/rails app:update
# Review each diff -- do not blindly accept

# 5. Fix removed APIs, run tests
bin/rails test && bin/rails test:system
```

### Key Checklist

```ruby
# Ruby version must be >= 3.2.0

# Remove config.read_encrypted_secrets if present
# config.read_encrypted_secrets = true  # DELETE THIS

# Fix enum keyword argument syntax
# Old (removed in 8.0):
enum status: { active: 0, archived: 1 }
# New:
enum :status, active: 0, archived: 1

# Remove deprecated Active Record configs:
# config.active_record.commit_transaction_on_non_local_return
# config.active_record.allow_deprecated_singular_associations_name
# config.active_record.warn_on_records_fetched_greater_than

# Replace ActiveSupport::ProxyObject with BasicObject or SimpleDelegator

# Check gem compatibility
# Visit railsbump.org or check individual gem changelogs
```
