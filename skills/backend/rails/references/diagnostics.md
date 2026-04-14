# Rails Diagnostics Reference

Common errors, debugging techniques, and troubleshooting guides for Rails 7.2-8.1. Load this file when answering questions about error resolution, query debugging, deployment issues, or performance profiling.

---

## Common ActiveRecord Errors

### ActiveRecord::RecordNotFound

```
ActiveRecord::RecordNotFound: Couldn't find Article with 'id'=42
```

**Cause:** `find` raises when the record does not exist.

**Fix:**

```ruby
# Option 1: Use find_by (returns nil)
article = Article.find_by(id: params[:id])
return render json: { error: "Not found" }, status: :not_found unless article

# Option 2: Rescue globally
class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound do |e|
    render json: { error: e.message }, status: :not_found
  end
end

# Option 3: Use find_by! when you want the exception for flow control
article = Article.find_by!(slug: params[:slug])
```

### ActiveRecord::RecordInvalid

```
ActiveRecord::RecordInvalid: Validation failed: Email can't be blank
```

**Cause:** Calling `save!`, `create!`, or `update!` when validations fail.

**Fix:**

```ruby
# Option 1: Use non-bang methods and check return value
if @user.save
  # success
else
  render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
end

# Option 2: Rescue explicitly
begin
  @user.save!
rescue ActiveRecord::RecordInvalid => e
  render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
end
```

### ActiveRecord::RecordNotUnique

```
ActiveRecord::RecordNotUnique: PG::UniqueViolation: ERROR: duplicate key value violates unique constraint
```

**Cause:** Database-level uniqueness constraint violation. Model validation alone is not sufficient due to race conditions.

**Fix:**

```ruby
# Always pair model validation with database constraint
validates :email, uniqueness: true  # application-level check
# + migration:
add_index :users, :email, unique: true  # database-level enforcement

# Handle the race condition
begin
  User.create!(email: params[:email])
rescue ActiveRecord::RecordNotUnique
  user = User.find_by!(email: params[:email])
end

# Or use find_or_create_by
user = User.find_or_create_by!(email: params[:email])
```

### ActiveRecord::StatementInvalid

```
ActiveRecord::StatementInvalid: PG::UndefinedColumn: ERROR: column users.foo does not exist
```

**Cause:** Query references a column that does not exist in the database.

**Fix:**
- Check for pending migrations: `rails db:migrate:status`
- Run migrations: `rails db:migrate`
- Verify column exists: `rails runner "puts User.column_names"`
- If the column was recently added and you are in a console, reload: `User.reset_column_information`

### ActiveRecord::PendingMigrationError

```
ActiveRecord::PendingMigrationError: Migrations are pending. To resolve this issue, run: bin/rails db:migrate
```

**Fix:**

```bash
# Run pending migrations
bin/rails db:migrate

# Check migration status
bin/rails db:migrate:status

# If stuck, check for failed migrations
bin/rails db:migrate:redo STEP=1  # redo last migration
```

---

## Migration Issues

### Migration Stuck or Failed Halfway

```bash
# Check status
bin/rails db:migrate:status

# If a migration shows "down" but tables partially exist:
# Option 1: Fix and re-run
bin/rails db:migrate

# Option 2: Roll back and re-run
bin/rails db:rollback STEP=1
bin/rails db:migrate

# Option 3: Mark as applied without running (dangerous)
bin/rails db:migrate:up VERSION=20240101000000
```

### Cannot Drop Database (Active Connections)

```bash
# Disconnect all sessions (PostgreSQL)
rails runner "ActiveRecord::Base.connection.execute('SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = current_database() AND pid != pg_backend_pid()')"

# Then drop
bin/rails db:drop
```

### Strong Migrations Errors

```
=== Dangerous operation detected ===
Adding a column with a non-null default blocks reads and writes while the default is set.
```

**Fix:** Follow strong_migrations guidance. Typical pattern for adding NOT NULL columns:

```ruby
# Step 1: Add nullable column
add_column :users, :status, :string

# Step 2: Backfill (separate migration or job)
User.in_batches.update_all(status: "active")

# Step 3: Add NOT NULL constraint
change_column_null :users, :status, false
```

### Concurrent Index Creation

```ruby
class AddIndexToUsersOnEmail < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!  # Required for CONCURRENTLY

  def change
    add_index :users, :email, algorithm: :concurrently
  end
end
```

---

## Routing Errors

### ActionController::RoutingError

```
ActionController::RoutingError: No route matches [GET] "/articles/foo"
```

**Debug:**

```bash
# List all routes
bin/rails routes

# Search for specific routes
bin/rails routes -g articles
bin/rails routes -c articles  # by controller

# Check route in console
Rails.application.routes.recognize_path("/articles/42")
Rails.application.routes.recognize_path("/articles/42", method: :patch)
```

### Route Order Matters

Routes are matched top-down. A catch-all route defined early will swallow later routes:

```ruby
# BAD -- catch-all swallows specific routes
get "*path", to: "pages#show"
resources :articles  # never reached

# GOOD -- specific routes first
resources :articles
get "*path", to: "pages#show"  # catch-all last
```

### Missing CSRF Token (422 Unprocessable Entity)

```
ActionController::InvalidAuthenticityToken
```

**Cause:** Form submitted without a CSRF token, or token expired.

**Fix for full-stack Rails:**

```erb
<%# Ensure meta tags in layout %>
<%= csrf_meta_tags %>

<%# Ensure form_with is used (includes token automatically) %>
<%= form_with model: @article do |f| %>
```

**Fix for SPA/API calling Rails with sessions:**

```javascript
const token = document.querySelector('meta[name="csrf-token"]')?.content;
fetch('/api/resource', {
  method: 'POST',
  headers: { 'X-CSRF-Token': token, 'Content-Type': 'application/json' }
});
```

**Fix for pure API mode (token-based auth):** CSRF protection is not needed -- remove or use `:null_session`:

```ruby
class ApiController < ActionController::API
  # No CSRF protection needed for token-based auth
end
```

---

## Asset Pipeline Issues

### Propshaft Asset Not Found

```
ActionView::Template::Error: The asset "application.css" is not present in the asset pipeline.
```

**Fix:**

```bash
# Precompile assets
bin/rails assets:precompile

# Clear and rebuild
bin/rails assets:clobber
bin/rails assets:precompile

# Check asset paths
bin/rails runner "puts Rails.application.config.assets.paths"
```

### Sprockets to Propshaft Migration Issues

When switching from Sprockets to Propshaft:
- Remove `//= require` directives (Propshaft does not use the asset directive system)
- Remove Sass compilation (Propshaft does not compile -- use standalone tools like `dartsass-rails`)
- Importmap replaces Webpack/Webpacker for JavaScript

---

## N+1 Query Detection and Debugging

### Using Bullet Gem

```ruby
# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true          # Browser alert
  Bullet.rails_logger = true   # Log to rails log
  Bullet.add_footer = true     # Footer badge on pages
end
```

### Using strict_loading

```ruby
# Per-query
posts = Post.strict_loading.includes(:author)
posts.first.comments  # raises StrictLoadingViolationError if not preloaded

# Per-model default (development/test)
config.active_record.strict_loading_by_default = true

# Per-association
has_many :comments, strict_loading: true
```

### Manual Query Debugging

```ruby
# See the SQL being generated
User.where(active: true).to_sql
# => "SELECT \"users\".* FROM \"users\" WHERE \"users\".\"active\" = TRUE"

# Log all SQL to console
ActiveRecord::Base.logger = Logger.new(STDOUT)

# EXPLAIN ANALYZE (PostgreSQL)
User.where(active: true).explain
# or
ActiveRecord::Base.connection.execute(
  "EXPLAIN ANALYZE #{User.where(active: true).to_sql}"
).to_a

# Count queries in a block
query_count = 0
counter = ->(_name, _start, _finish, _id, payload) {
  query_count += 1 unless payload[:name] == "SCHEMA"
}
ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
  # your code here
end
puts "Executed #{query_count} queries"
```

### Common N+1 Fixes

```ruby
# includes -- let Rails decide (preload or eager_load)
Post.includes(:author, :tags)

# preload -- always separate queries (good for has_many)
Post.preload(:comments)

# eager_load -- always LEFT JOIN (needed for WHERE on association)
Post.eager_load(:author).where(users: { active: true })

# Nested eager loading
Post.includes(comments: :author)
Post.includes(:author, comments: [:author, :likes])
```

---

## Kamal Deployment Troubleshooting

### Deploy Fails on Health Check

```
ERROR: container unhealthy after 10 attempts
```

**Causes and fixes:**
1. **No health check endpoint:** Ensure `/up` route exists (Rails 7.2+ generates it):
   ```ruby
   get "up" => "rails/health#show", as: :rails_health_check
   ```
2. **Database not migrated:** Add a pre-deploy hook:
   ```bash
   # .kamal/hooks/pre-deploy
   kamal app exec "bin/rails db:migrate"
   ```
3. **Missing RAILS_MASTER_KEY:** Verify secrets:
   ```bash
   kamal secrets print
   ```
4. **Port mismatch:** Ensure container exposes port 3000 (or match deploy.yml healthcheck port).

### SSH Connection Refused

```bash
# Verify SSH access
ssh root@192.168.1.100

# Check Docker is installed
kamal server bootstrap

# Check Kamal lock
kamal lock status
kamal lock release  # if stuck
```

### Container Cannot Connect to Database

```bash
# Check accessory is running
kamal accessory details db

# Verify DATABASE_URL
kamal app exec "echo $DATABASE_URL"

# Check network
kamal app exec "pg_isready -h 192.168.1.100 -p 5432"
```

### Image Push Fails

```bash
# Verify registry credentials
kamal registry login

# Test manually
docker login ghcr.io

# For Kamal 2.8+ (registry-free local mode)
# Remove registry block from deploy.yml to use direct transfer
```

### Rolling Back

```bash
# Roll back to previous version
kamal rollback

# List available versions
kamal app images

# Deploy a specific version
kamal deploy --version=abc123
```

---

## Action Cable Debugging

### Connection Refused / Not Connecting

1. **Check cable.yml adapter:**
   ```yaml
   # config/cable.yml
   production:
     adapter: solid_cable    # or redis, async
     polling_interval: 0.1
   ```

2. **Check Action Cable mount:**
   ```ruby
   # config/routes.rb
   mount ActionCable.server, at: "/cable"
   ```

3. **Check allowed origins:**
   ```ruby
   # config/environments/production.rb
   config.action_cable.allowed_request_origins = [
     "https://myapp.com",
     /https:\/\/.*\.myapp\.com/
   ]
   ```

4. **Check CORS for cross-origin WebSocket:**
   The CORS gem does not handle WebSocket upgrades. Use `allowed_request_origins` instead.

### Messages Not Received

```ruby
# Verify broadcasting works from console
ActionCable.server.broadcast("chat_1", { message: "test" })

# Check subscription in channel
def subscribed
  stream_from "chat_#{params[:room_id]}"
  # or
  stream_for Room.find(params[:room_id])
  Rails.logger.info "Subscribed to chat_#{params[:room_id]}"
end
```

### Redis Connection Issues (if using Redis adapter)

```ruby
# config/cable.yml
production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
  channel_prefix: myapp_production

# Test Redis connection
Redis.new(url: ENV["REDIS_URL"]).ping
```

---

## Performance Profiling

### rack-mini-profiler

```ruby
gem "rack-mini-profiler"

# Adds a speed badge to every page showing:
# - Total request time
# - SQL query count and time
# - View rendering time
# - Memory usage

# Access profiling for API:
# GET /any-endpoint?pp=flamegraph
```

### memory_profiler

```ruby
gem "memory_profiler", group: :development

# Profile a block
report = MemoryProfiler.report do
  100.times { User.all.to_a }
end
report.pretty_print
```

### Identifying Slow Queries

```ruby
# config/environments/development.rb
config.active_record.warn_on_records_fetched_greater_than = 500  # warning threshold

# Log slow queries (PostgreSQL)
# postgresql.conf: log_min_duration_statement = 200  (ms)

# In Rails
ActiveRecord::Base.connection.execute("SET log_min_duration_statement = 200")
```

---

## Common Gem Conflicts

### Bundler Version Mismatch

```
Bundler could not find compatible versions for gem "railties"
```

**Fix:**

```bash
# Update Bundler
gem install bundler
bundle update --bundler

# Clear cache
bundle clean --force
rm Gemfile.lock && bundle install  # nuclear option
```

### Spring Process Issues (pre-8.0)

```bash
# Kill stuck Spring processes
bin/spring stop
pkill -f spring
```

Rails 8.0+ does not include Spring by default.

### Bootsnap Cache Corruption

```
TypeError: no implicit conversion of nil into String (bootsnap)
```

**Fix:**

```bash
rm -rf tmp/cache/bootsnap
bin/rails restart
```

---

## Turbo/Hotwire Debugging

### Turbo Form Submission Returns HTML Instead of Turbo Stream

**Check:** Controller must respond to `turbo_stream` format:

```ruby
respond_to do |format|
  format.turbo_stream
  format.html { redirect_to @article }
end
```

### Turbo Frame Not Updating

1. Frame IDs must match between the source page and target page.
2. Check browser console for errors.
3. Verify the response contains a matching `turbo-frame` tag.

```erb
<%# Source page %>
<%= turbo_frame_tag "article_42" do %>
  ...
<% end %>

<%# Target page must also wrap content in same frame ID %>
<%= turbo_frame_tag "article_42" do %>
  ...
<% end %>
```

### Turbo Drive Disabled Unexpectedly

Check for JavaScript errors -- any uncaught exception during a Turbo visit will cause a full page reload. Check the browser console.

### Flash Messages Not Appearing After Redirect

Turbo Drive follows redirects but reads the flash from the response body, not cookies. Ensure flash is rendered in the layout:

```erb
<%# app/views/layouts/application.html.erb %>
<div id="flash">
  <% flash.each do |type, message| %>
    <div class="flash-<%= type %>"><%= message %></div>
  <% end %>
</div>
```

---

## Environment and Configuration Debugging

### Check Current Configuration

```ruby
# Rails console
Rails.application.config.cache_store
Rails.application.config.active_job.queue_adapter
Rails.application.config.action_mailer.delivery_method
Rails.env
Rails.root
```

### Missing Credentials

```
ActiveSupport::MessageEncryptor::InvalidMessage
```

**Cause:** `config/master.key` does not match the encrypted credentials file, or the key is missing.

**Fix:**

```bash
# Check if master key exists
cat config/master.key

# Set via environment variable
export RAILS_MASTER_KEY=your_key_here

# Re-create credentials (destructive)
rm config/credentials.yml.enc
rails credentials:edit
```

### Log Level and Debugging

```ruby
# Temporarily increase logging
Rails.logger.level = :debug

# Tagged logging
Rails.logger.tagged("PaymentService") { Rails.logger.info "Processing order #{id}" }

# SQL logging in console
ActiveRecord::Base.logger = Logger.new(STDOUT)
```
