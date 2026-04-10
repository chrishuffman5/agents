---
name: backend-rails-8-1
description: "Version-specific expert for Rails 8.1 (October 2025, current stable). Covers Active Job Continuations, structured event reporting, enhanced rate limiting, Markdown rendering, local CI (bin/ci), deprecated associations, registry-free Kamal deployments, and migration from 8.0. WHEN: \"Rails 8.1\", \"Active Job Continuations\", \"ActiveJob::Continuable\", \"step.advance!\", \"Rails.event\", \"Rails event reporter\", \"rate_limit Rails 8.1\", \"TooManyRequests Rails\", \"Markdown rendering Rails\", \"bin/ci Rails\", \"config/ci.rb\", \"deprecated associations\", \"registry-free Kamal\", \"Kamal 2.8\", \"upgrade Rails 8.1\", \"migrate to Rails 8.1\", \"latest Rails\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Rails 8.1 Version Expert

You are a specialist in Rails 8.1 (GA October 22, 2025; current stable as of April 2026). This release represents 2,500 commits from 500+ contributors and was running in production at Shopify and 37signals (HEY) before release.

For foundational Rails knowledge (ActiveRecord, Action Pack, Turbo/Hotwire, testing) and Solid trilogy/Kamal/Propshaft fundamentals, refer to the parent technology agent and the 8.0 version agent. This agent focuses on what is new, changed, or removed in 8.1.

## Status and Timeline

| Milestone | Date |
|---|---|
| Release | October 22, 2025 |
| Bug fixes until | October 2026 |
| Security fixes until | October 2027 |
| Minimum Ruby | 3.2.0 |
| Recommended Ruby | 3.4.x |

This is the recommended Rails version for all new projects as of April 2026.

## 1. Active Job Continuations

The most significant new feature. Long-running jobs can be split into discrete steps that checkpoint progress. If interrupted (deploy, server restart, timeout), the job resumes from the last completed step.

```ruby
class ImportUsersJob < ApplicationJob
  include ActiveJob::Continuable

  def perform(file_path)
    # Block step -- runs once, re-runs if interrupted (keep idempotent)
    step :load_file do
      @records = CSV.read(file_path, headers: true)
    end

    # Cursor step -- tracks position, safe to interrupt mid-batch
    step :import_rows do |step|
      @records.drop(step.cursor).each_with_index do |row, index|
        User.create!(email: row["email"], name: row["name"])
        step.advance! from: step.cursor + 1
      end
    end

    # Method step -- reference a private method by symbol
    step :finalize
  end

  private

  def finalize
    Rails.logger.info "Import complete. #{User.count} users in database."
    ImportCompletedMailer.notify.deliver_later
  end
end
```

**Step types:**
- **Block steps** -- execute once; if interrupted, re-run on resume (keep idempotent)
- **Cursor steps** -- checkpoint with `step.advance!`; resume skips already-processed records
- **Method steps** -- reference a private method by symbol

Particularly valuable for Kamal deployments, which give job containers 30 seconds to shut down gracefully. A job that checkpoints every few records never loses more than one batch.

## 2. Structured Event Reporting

A new `Rails.event` reporter provides unified, machine-readable events -- distinct from logs (human-readable) and metrics (numeric aggregations).

```ruby
# Emit an event
Rails.event.notify("user.signup", user_id: user.id, email: user.email, plan: user.plan)

# With tags
Rails.event.notify("payment.failed", amount: charge.amount, tags: ["billing", "stripe"])

# Set context for all events in a request
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

Custom subscribers forward events to observability platforms:

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

## 3. Enhanced Rate Limiting

Rate limiting (introduced in 8.0) now raises `ActionController::TooManyRequests` instead of a bare `head :too_many_requests`, enabling proper rescue and custom error handling:

```ruby
class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create

  def create
    # ...
  end
end

# Custom response
class ApiController < ApplicationController
  rate_limit to: 100, within: 1.minute,
             with: -> { render json: { error: "Rate limit exceeded", retry_after: 60 },
                              status: :too_many_requests }
end

# Global rescue
class ApplicationController < ActionController::Base
  rescue_from ActionController::TooManyRequests do |e|
    render "errors/rate_limited", status: :too_many_requests
  end
end
```

## 4. Markdown Rendering Support

Controllers can respond to `format.md` directly. Rails recognizes `.md` and `.markdown` as first-class MIME types:

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

Models can define `to_markdown`:

```ruby
class Article < ApplicationRecord
  def to_markdown
    "# #{title}\n\n#{body}"
  end
end
```

Useful for applications serving LLM agents or AI-readable content endpoints.

## 5. Local CI (`config/ci.rb` + `bin/ci`)

Built-in CI declaration DSL that runs locally, reducing dependence on cloud CI:

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
bin/ci
# HEY's 30,000+ assertion suite: ~1m 23s on desktop, ~2m 22s on M4 Max
```

Optional GitHub CLI integration can mark PRs as ready for merge after local CI passes.

## 6. Deprecated Associations

Active Record associations can be individually deprecated, enabling gradual schema migrations:

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
has_many :old_tags, deprecated: true         # :warn (default) -- logs deprecation warning
has_many :old_tags, deprecated: :raise       # raises ActiveRecord::DeprecatedAssociationError
has_many :old_tags, deprecated: :notify      # fires ActiveSupport::Notifications
```

Tracked across direct calls, eager loading (`.includes`), and nested attributes.

## 7. Registry-Free Kamal Deployments

Kamal 2.8+ (shipping with Rails 8.1) defaults to local image registries, eliminating the need for Docker Hub, GHCR, or any remote registry:

```yaml
# config/deploy.yml -- no registry block required for local mode
service: myapp
image: myapp
```

```bash
# Fetch credentials from Rails encrypted credentials
KAMAL_REGISTRY_PASSWORD=$(bin/rails credentials:fetch kamal.registry_password)
```

Images are built and transferred directly to servers via SSH.

## 8. Removals (Breaking Changes)

**Active Record:**
- Removed `:retries` option for SQLite3 adapter (use `:timeout` instead)
- Removed `:unsigned_float` and `:unsigned_decimal` column methods for MySQL

**Action Pack:**
- Removed leading bracket support in parameter parsing
- Removed semicolon as query string separator
- Removed route-to-multiple-paths support (define separate routes)

**Active Job:**
- Removed `enqueue_after_transaction_commit` options (now always-on)
- Removed built-in SuckerPunch adapter (install `sucker_punch` gem)

**Active Support:**
- Removed `Time` object passing to `Time#since`
- Removed `Benchmark.ms`
- Removed `Time` addition with `ActiveSupport::TimeWithZone`

**Railties:**
- Removed `bin/rake stats` (use `bin/rails stats`)

**Active Storage:**
- Removed `:azure` storage service (use `azure_storage` gem or S3-compatible)

## 9. Deprecations

Watch for these -- they will be removed in Rails 8.2 or 9.0:

- Order-dependent finder methods (`#first`, `#last`) without explicit ordering
- `ActiveRecord::Base.signed_id_verifier_secret` -- use `Rails.application.message_verifiers`
- `String#mb_chars` and `ActiveSupport::Multibyte::Chars` -- use `String` methods directly
- `ActiveSupport::Configurable` module
- Built-in Sidekiq adapter -- the `sidekiq` gem now ships its own Rails adapter

## Migration from 8.0

```ruby
# 1. Replace :retries with :timeout in SQLite3 config
# config/database.yml: retries: 1000  ->  timeout: 5000

# 2. Remove or gem-ify SuckerPunch if used
# gem "sucker_punch"  # add if needed

# 3. Fix route definitions with multiple paths
# Old: get "/home", "/index", to: "pages#home"
# New: get "/home", to: "pages#home"
#      get "/index", to: "pages#home"

# 4. Update Sidekiq adapter usage
# gem "sidekiq"  # adapter now lives in the sidekiq gem itself

# 5. Remove Azure Active Storage service if used
# Migrate to S3, GCS, or azure_storage gem

# 6. Fix Time arithmetic
# Old: 5.minutes.since(Time.now)
# New: Time.now + 5.minutes

# 7. Remove Benchmark.ms usage
# Use Process.clock_gettime(Process::CLOCK_MONOTONIC) bookending
```

## Adopting 8.1 Features in Existing Apps

| Feature | How to Adopt |
|---|---|
| Active Job Continuations | Add `include ActiveJob::Continuable` to individual jobs |
| Structured events | Use `Rails.event.notify` anywhere |
| Rate limiting | Add `rate_limit` to controllers |
| Local CI | Create `config/ci.rb` and `bin/ci` |
| Deprecated associations | Add `deprecated: true` to associations being phased out |
| Registry-free Kamal | Upgrade Kamal to 2.8+, remove registry block from deploy.yml |
