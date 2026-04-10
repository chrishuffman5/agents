# Rails Ecosystem Research — Production Reference

> Target: Rails 7.1–8.x, Ruby 3.2+, production deployments

---

## 1. API Mode

### rails new --api

API-only applications strip the middleware stack down to essentials: no cookies, sessions, flash, asset pipeline, or browser-specific middleware.

```bash
rails new my_api --api --database=postgresql
rails new my_api --api -d postgresql --skip-test  # if using RSpec
```

Key differences from full-stack Rails:
- `ApplicationController` inherits from `ActionController::API` (not `Base`)
- No view layer, no asset pipeline
- Slimmer middleware stack (~12 vs ~20+ middleware)
- No session/cookie support by default
- Faster request/response cycle

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  before_action :authenticate_api_token!

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

  private

  def authenticate_api_token!
    authenticate_with_http_token do |token, _options|
      @current_user = User.find_by(api_token: token)
    end
    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  end

  def not_found(exception)
    render json: { error: exception.message }, status: :not_found
  end

  def unprocessable_entity(exception)
    render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_entity
  end
end
```

### CORS — rack-cors

```ruby
# Gemfile
gem "rack-cors"
```

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("CORS_ORIGINS", "http://localhost:3000").split(",")

    resource "/api/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      max_age: 86400

    resource "/health",
      headers: :any,
      methods: [:get]
  end
end
```

For production, always use explicit origin lists, not `"*"` with credentials.

### JSON Serialization

#### jbuilder (Ships with Rails, view-based)

```ruby
# app/views/api/v1/users/show.json.jbuilder
json.extract! @user, :id, :email, :name, :created_at
json.avatar_url url_for(@user.avatar) if @user.avatar.attached?
json.posts @user.posts do |post|
  json.extract! post, :id, :title, :published_at
end
```

Best for: view-heavy APIs, complex conditional rendering. Slowest of the options.

#### ActiveModel::Serializer (AMS)

```ruby
# Gemfile
gem "active_model_serializers"

# app/serializers/user_serializer.rb
class UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :name, :created_at
  has_many :posts, serializer: PostSerializer
  belongs_to :organization

  attribute :full_name do
    "#{object.first_name} #{object.last_name}"
  end
end

# Controller usage
render json: @user, serializer: UserSerializer
render json: @users, each_serializer: UserSerializer
```

AMS has had maintenance issues; consider Blueprinter or Alba for new projects.

#### Blueprinter (Fast, explicit)

```ruby
# Gemfile
gem "blueprinter"

# app/blueprints/user_blueprint.rb
class UserBlueprint < Blueprinter::Base
  identifier :id

  view :default do
    fields :email, :name, :created_at
    field :full_name do |user, _options|
      "#{user.first_name} #{user.last_name}"
    end
  end

  view :extended do
    include_view :default
    association :posts, blueprint: PostBlueprint
    field :organization_name do |user, _options|
      user.organization&.name
    end
  end
end

# Controller
render json: UserBlueprint.render(@user, view: :extended)
render json: UserBlueprint.render(@users, view: :default, root: :users)
```

#### Alba (Fastest Ruby serializer, ~10-30x faster than AMS)

```ruby
# Gemfile
gem "alba"

# config/initializers/alba.rb
Alba.inflector = :active_support
Alba.backend = :oj  # optional, uses Oj for speed

# app/resources/user_resource.rb
class UserResource
  include Alba::Resource

  root_key :user, :users

  attributes :id, :email, :name

  attribute :full_name do |user|
    "#{user.first_name} #{user.last_name}"
  end

  many :posts, resource: PostResource
  one :organization, resource: OrganizationResource

  nested :meta do
    attribute :created_at
    attribute :updated_at
  end
end

# Controller
render json: UserResource.new(@user).serialize
render json: UserResource.new(@users).serialize
```

Recommendation: **Alba** for pure performance; **Blueprinter** for readability; avoid AMS for new projects.

### API Versioning Patterns

#### URL Namespace Versioning (Most common)

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :users
      resources :posts, only: [:index, :show, :create]
    end

    namespace :v2 do
      resources :users
    end
  end
end

# app/controllers/api/v1/users_controller.rb
module Api
  module V1
    class UsersController < ApplicationController
      def index
        @users = User.page(params[:page]).per(params[:per_page] || 25)
        render json: UserBlueprint.render(@users, view: :default)
      end
    end
  end
end
```

#### Header-Based Versioning

```ruby
# config/routes.rb — uses constraints
module ApiVersionConstraint
  def self.matches?(request)
    request.headers["Accept"].include?("application/vnd.myapi.v1")
  end
end

# app/controllers/concerns/api_version.rb
module ApiVersion
  extend ActiveSupport::Concern

  included do
    before_action :set_api_version
  end

  private

  def set_api_version
    @api_version = request.headers["API-Version"] || "1"
  end
end
```

URL versioning is simpler to cache, test, and document. Prefer it for most APIs.

---

## 2. Authentication

### Devise (Full-featured, sessions-based)

```ruby
# Gemfile
gem "devise"

# Setup
rails generate devise:install
rails generate devise User
rails generate devise:views  # if customizing

# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :trackable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  # Custom validation
  validates :username, presence: true, uniqueness: { case_sensitive: false }
end
```

For API use with Devise, use `devise-jwt` or roll your own token approach:

```ruby
# Gemfile
gem "devise-jwt"

# config/initializers/devise.rb
Devise.setup do |config|
  config.jwt do |jwt|
    jwt.secret = Rails.application.credentials.devise_jwt_secret_key!
    jwt.dispatch_requests = [
      ["POST", %r{^/api/v1/sign_in$}]
    ]
    jwt.revocation_requests = [
      ["DELETE", %r{^/api/v1/sign_out$}]
    ]
    jwt.expiration_time = 1.day.to_i
  end
end

# app/models/user.rb — add revocation strategy
class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher
  devise :database_authenticatable, :jwt_authenticatable,
         jwt_revocation_strategy: self
end
```

### Rails 8 Authentication Generator

Rails 8 ships a built-in, minimal authentication generator — no gem required:

```bash
rails generate authentication
# Creates: User model, Session model, migrations,
#          SessionsController, PasswordsController,
#          authentication concern, password mailer
```

```ruby
# Generated app/controllers/concerns/authentication.rb
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

  def find_session_by_cookie
    Session.find_by(id: cookies.signed[:session_id])
  end

  def request_authentication
    session[:return_to_after_authenticating] = request.url
    redirect_to new_session_url
  end

  def after_authentication_url
    session.delete(:return_to_after_authenticating) || root_url
  end

  def start_new_session_for(user)
    user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
      Current.session = session
      cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
    end
  end

  def terminate_session
    Current.session.destroy
    cookies.delete(:session_id)
  end
end
```

Best for: new Rails 8+ apps that don't need the full Devise feature set.

### OmniAuth (OAuth SSO)

```ruby
# Gemfile
gem "omniauth"
gem "omniauth-google-oauth2"
gem "omniauth-github"
gem "omniauth-rails_csrf_protection"  # Required for CSRF protection

# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    Rails.application.credentials.google[:client_id],
    Rails.application.credentials.google[:client_secret],
    scope: "email,profile"

  provider :github,
    Rails.application.credentials.github[:client_id],
    Rails.application.credentials.github[:client_secret],
    scope: "user:email"
end

# app/controllers/omniauth_callbacks_controller.rb
class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])
    if @user.persisted?
      sign_in_and_redirect @user
    else
      session["devise.google_data"] = request.env["omniauth.auth"].except("extra")
      redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
    end
  end

  # app/models/user.rb
  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.name = auth.info.name
      user.password = Devise.friendly_token[0, 20]
      user.skip_confirmation!
    end
  end
end
```

### Doorkeeper (OAuth2 Provider)

When your Rails app is the authorization server:

```ruby
# Gemfile
gem "doorkeeper"

rails generate doorkeeper:install
rails generate doorkeeper:migration

# config/initializers/doorkeeper.rb
Doorkeeper.configure do
  orm :active_record
  resource_owner_authenticator do
    current_user || warden.authenticate!(scope: :user)
  end

  grant_flows %w[authorization_code client_credentials refresh_token]
  access_token_expires_in 2.hours
  refresh_token_enabled true
  reuse_access_token false
  skip_authorization { |resource_owner, client| client.superapp? }
end

# config/routes.rb
use_doorkeeper do
  skip_controllers :applications, :authorized_applications  # optional
end

# Protect API endpoints
class Api::V1::BaseController < ApplicationController
  before_action :doorkeeper_authorize!

  private

  def current_user
    User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
  end
end
```

### JWT (ruby-jwt) — Stateless API Auth

```ruby
# Gemfile
gem "jwt"

# app/services/jwt_service.rb
class JwtService
  ALGORITHM = "HS256".freeze
  EXPIRY = 24.hours

  def self.encode(payload)
    payload[:exp] = EXPIRY.from_now.to_i
    payload[:iat] = Time.current.to_i
    JWT.encode(payload, secret_key, ALGORITHM)
  end

  def self.decode(token)
    decoded = JWT.decode(token, secret_key, true, algorithm: ALGORITHM)
    HashWithIndifferentAccess.new(decoded.first)
  rescue JWT::ExpiredSignature
    raise AuthenticationError, "Token has expired"
  rescue JWT::DecodeError => e
    raise AuthenticationError, "Invalid token: #{e.message}"
  end

  def self.secret_key
    Rails.application.credentials.jwt_secret_key!
  end
end

# app/controllers/concerns/jwt_authenticatable.rb
module JwtAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user_from_token!
  end

  private

  def authenticate_user_from_token!
    token = extract_token_from_header
    return render_unauthorized unless token

    payload = JwtService.decode(token)
    @current_user = User.find(payload[:user_id])
  rescue AuthenticationError, ActiveRecord::RecordNotFound
    render_unauthorized
  end

  def extract_token_from_header
    auth_header = request.headers["Authorization"]
    auth_header&.split(" ")&.last
  end

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end
```

### API Token Auth Pattern (Simple & Secure)

```ruby
# db/migrate/..._add_api_token_to_users.rb
add_column :users, :api_token, :string
add_index :users, :api_token, unique: true

# app/models/user.rb
class User < ApplicationRecord
  has_secure_token :api_token

  def regenerate_api_token!
    update!(api_token: SecureRandom.hex(32))
  end
end

# app/controllers/concerns/api_token_authenticatable.rb
module ApiTokenAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_with_api_token!
  end

  private

  def authenticate_with_api_token!
    authenticate_with_http_token do |token, _options|
      @current_user = User.find_by(api_token: token)
    end
    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  end

  def current_user
    @current_user
  end
end
```

---

## 3. Background Jobs

### Adapter Comparison

| Feature | Solid Queue | Sidekiq | GoodJob |
|---|---|---|---|
| Backend | PostgreSQL/SQLite/MySQL | Redis | PostgreSQL |
| Rails default (8.x) | Yes | No | No |
| Concurrency model | Multi-process/thread | Multi-thread | Thread/async |
| Web UI | Yes (Mission Control) | Yes (Sidekiq Web) | Yes (built-in) |
| Cron/recurring | Yes | Yes (Sidekiq Pro/OSS gems) | Yes |
| Dead letter queue | Yes | Yes | Yes |
| Batches | No | Yes (Pro) | No |
| Licensing | MIT | OSS (LGPL) + Pro ($) | MIT |
| Memory usage | Low (no Redis) | Low | Low |
| Throughput | Good | Excellent | Good |

**Solid Queue** — Ships with Rails 8, zero extra infrastructure, production-ready:

```yaml
# config/queue.yml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: 2
      polling_interval: 0.1

production:
  <<: *default
  workers:
    - queues: "critical,high"
      threads: 5
      processes: 4
    - queues: "default,low"
      threads: 3
      processes: 2
```

**Sidekiq** — Best throughput for high-volume Redis shops:

```ruby
# config/sidekiq.yml
---
:concurrency: 10
:queues:
  - [critical, 3]
  - [default, 2]
  - [low, 1]
:max_retries: 5
```

**GoodJob** — Best for teams already on PostgreSQL who want simplicity:

```ruby
# config/initializers/good_job.rb
GoodJob.configure do |config|
  config.execution_mode = :external
  config.queues = "critical:4;default:2;low:1"
  config.poll_interval = 1
  config.shutdown_timeout = 25
  config.cleanup_preserved_jobs_before_seconds_ago = 7.days.to_i
end
```

### Job Patterns

#### Basic Job with Retries

```ruby
# app/jobs/process_payment_job.rb
class ProcessPaymentJob < ApplicationJob
  queue_as :critical

  # Sidekiq-style options (works with Sidekiq adapter)
  sidekiq_options retry: 5, dead: true, backtrace: 10

  # ActiveJob retry DSL (adapter-agnostic)
  retry_on Stripe::RateLimitError, wait: :polynomially_longer, attempts: 5
  retry_on Stripe::APIConnectionError, wait: 5.seconds, attempts: 3
  discard_on Stripe::InvalidRequestError

  def perform(order_id)
    order = Order.find(order_id)
    PaymentService.new(order).process!
    OrderMailer.payment_confirmation(order).deliver_later
  rescue ActiveRecord::RecordNotFound
    # Order deleted, discard silently
    Rails.logger.warn("ProcessPaymentJob: Order #{order_id} not found, discarding")
  end
end
```

#### Dead Letter Queue Pattern

```ruby
# Sidekiq dead letter queue
class DeadJobProcessor
  include Sidekiq::Worker

  def self.process_dead_jobs(limit: 100)
    dead = Sidekiq::DeadSet.new
    dead.take(limit).each do |job|
      # Inspect and potentially retry
      if retriable?(job)
        job.retry
      else
        job.delete
        DeadJobMailer.notify(job.item).deliver_later
      end
    end
  end

  def self.retriable?(job)
    job.item["error_class"] != "Stripe::InvalidRequestError"
  end
end
```

#### Rate Limiting (with Sidekiq throttled gem)

```ruby
# Gemfile — for Sidekiq
gem "sidekiq-throttled"

# app/jobs/email_campaign_job.rb
class EmailCampaignJob < ApplicationJob
  include Sidekiq::Throttled::Worker

  sidekiq_throttle(
    concurrency: { limit: 5 },
    threshold: { limit: 100, period: 1.minute }
  )

  def perform(user_id, campaign_id)
    user = User.find(user_id)
    CampaignMailer.send_campaign(user, Campaign.find(campaign_id)).deliver_now
  end
end
```

#### Bulk Enqueue

```ruby
# Efficient bulk enqueue — avoid N database calls
class BulkNotificationJob < ApplicationJob
  def perform(user_ids)
    User.where(id: user_ids).find_each do |user|
      UserNotificationJob.perform_later(user.id)
    end
  end
end

# Enqueue in batches
class NotificationService
  def self.notify_all_users
    User.active.in_batches(of: 1000) do |batch|
      BulkNotificationJob.perform_later(batch.pluck(:id))
    end
  end
end

# Sidekiq bulk push (ultra-efficient)
class SidekiqBulkEnqueuer
  def self.enqueue(user_ids)
    payloads = user_ids.map { |id| ["UserNotificationJob", [id]] }
    Sidekiq::Client.push_bulk("class" => "UserNotificationJob",
                              "args" => user_ids.map { |id| [id] })
  end
end
```

#### Recurring Jobs / Cron

```ruby
# GoodJob recurring jobs (config/initializers/good_job.rb)
GoodJob.configure do |config|
  config.cron = {
    cleanup_expired_sessions: {
      cron: "0 2 * * *",  # 2am daily
      class: "CleanupExpiredSessionsJob",
      description: "Remove sessions older than 30 days"
    },
    send_digest_emails: {
      cron: "0 9 * * 1",  # Monday 9am
      class: "WeeklyDigestJob",
      set: { queue: "low" }
    }
  }
end

# Solid Queue recurring (config/recurring.yml)
# production:
#   cleanup_sessions:
#     class: CleanupExpiredSessionsJob
#     schedule: every day at 2am
#
# Sidekiq cron (via sidekiq-cron gem)
# config/sidekiq_cron.yml
# cleanup_sessions:
#   class: CleanupExpiredSessionsJob
#   cron: "0 2 * * *"
```

---

## 4. Deployment

### Kamal 2

Kamal 2 uses Docker to deploy to any VPS/bare metal. Ships as Rails default in Rails 8.

#### deploy.yml Structure

```yaml
# config/deploy.yml
service: myapp
image: user/myapp

servers:
  web:
    hosts:
      - 192.168.1.1
      - 192.168.1.2
    labels:
      traefik.http.routers.myapp.rule: Host(`myapp.com`)
      traefik.http.routers.myapp-secure.entrypoints: websecure
    options:
      network: "private"

  workers:
    hosts:
      - 192.168.1.3
    cmd: bundle exec sidekiq

proxy:
  ssl: true
  host: myapp.com

registry:
  server: ghcr.io
  username: user
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  clear:
    RAILS_ENV: production
    RAILS_LOG_TO_STDOUT: true
    RAILS_SERVE_STATIC_FILES: true
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL
    - REDIS_URL

accessories:
  db:
    image: postgres:16
    host: 192.168.1.4
    port: 5432
    env:
      secret:
        - POSTGRES_PASSWORD
      clear:
        POSTGRES_USER: myapp
        POSTGRES_DB: myapp_production
    volumes:
      - /var/lib/postgresql/data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    host: 192.168.1.4
    port: 6379
    volumes:
      - /var/lib/redis:/data

volumes:
  - /storage:/rails/storage

asset_path: /rails/public/assets

healthcheck:
  path: /health
  port: 3000
  interval: 3s
  timeout: 10s
  max_attempts: 10
```

#### Kamal Hooks

```bash
# .kamal/hooks/pre-deploy  (runs before deploy on your machine)
#!/bin/bash
set -e
echo "Running pre-deploy checks..."
bundle exec rspec --tag smoke
bundle exec brakeman -q

# .kamal/hooks/post-deploy  (runs after deploy on your machine)
#!/bin/bash
echo "Notifying Slack..."
curl -X POST "$SLACK_WEBHOOK" -d '{"text":"Deployed '$KAMAL_VERSION' to production"}'

# .kamal/hooks/pre-connect  (before SSH connection)
# .kamal/hooks/docker-setup  (after Docker installed on host)
```

#### Kamal Commands

```bash
kamal setup           # First-time: install Docker, pull image, start app
kamal deploy          # Deploy new version (zero-downtime)
kamal rollback        # Roll back to previous version
kamal app logs        # Tail application logs
kamal app exec "rails db:migrate"   # Run one-off commands
kamal secrets print   # Verify secrets
kamal accessory reboot db  # Restart accessory
kamal lock acquire    # Lock deployments (maintenance)
```

#### Secrets Management

```bash
# .kamal/secrets (gitignored)
KAMAL_REGISTRY_PASSWORD=ghp_xxxxx
RAILS_MASTER_KEY=$(cat config/master.key)
DATABASE_URL=postgres://user:pass@host/db
```

### Docker Multi-Stage Build

```dockerfile
# syntax = docker/dockerfile:1

ARG RUBY_VERSION=3.3.0
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Build stage
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential git libpq-dev libvips pkg-config curl

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY . .

# Precompile assets
RUN bundle exec bootsnap precompile --gemfile && \
    bundle exec bootsnap precompile app/ lib/

RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Final stage — production image
FROM base

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl libvips postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp

USER rails:rails

EXPOSE 3000
CMD ["./bin/rails", "server"]
```

### Capistrano (Legacy)

```ruby
# Gemfile (development)
gem "capistrano", require: false
gem "capistrano-rails", require: false
gem "capistrano-bundler", require: false
gem "capistrano-rbenv", require: false

# Capfile
require "capistrano/setup"
require "capistrano/deploy"
require "capistrano/rbenv"
require "capistrano/bundler"
require "capistrano/rails/assets"
require "capistrano/rails/migrations"

# config/deploy.rb
set :application, "myapp"
set :repo_url, "git@github.com:user/myapp.git"
set :deploy_to, "/var/www/myapp"
set :linked_files, %w[config/master.key config/database.yml]
set :linked_dirs, %w[log tmp/pids tmp/cache tmp/sockets public/system storage]
set :keep_releases, 5
set :migration_role, :db
```

Capistrano is considered legacy. Use Kamal 2 for new deployments.

### Heroku

```bash
# Procfile
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq
release: bundle exec rails db:migrate

# heroku.yml (container deploy)
build:
  docker:
    web: Dockerfile
run:
  web: bundle exec rails server
```

Key Heroku considerations:
- Ephemeral filesystem — use ActiveStorage with S3/GCS
- Use `DATABASE_URL` env var (Heroku sets this automatically)
- `WEB_CONCURRENCY` controls Puma worker processes
- `RAILS_MAX_THREADS` controls Puma thread count

### Fly.io

```toml
# fly.toml
app = "myapp"
primary_region = "iad"

[build]

[env]
  RAILS_ENV = "production"
  RAILS_LOG_TO_STDOUT = "true"

[deploy]
  release_command = "bundle exec rails db:migrate"

[[services]]
  internal_port = 3000
  protocol = "tcp"
  [[services.ports]]
    handlers = ["http"]
    port = 80
  [[services.ports]]
    handlers = ["tls", "http"]
    port = 443
  [[services.http_checks]]
    path = "/health"

[[mounts]]
  source = "myapp_storage"
  destination = "/rails/storage"
```

### Render

```yaml
# render.yaml
services:
  - type: web
    name: myapp
    env: ruby
    buildCommand: bundle install && bundle exec rails assets:precompile
    startCommand: bundle exec rails server -b 0.0.0.0
    envVars:
      - key: RAILS_MASTER_KEY
        sync: false
      - key: DATABASE_URL
        fromDatabase:
          name: myapp-db
          property: connectionString

databases:
  - name: myapp-db
    plan: standard
```

---

## 5. Performance

### N+1 Detection — Bullet Gem

```ruby
# Gemfile
gem "bullet", group: :development

# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true
  Bullet.rails_logger = true
  Bullet.add_footer = true
  Bullet.bullet_logger = true
  Bullet.unused_eager_loading_enable = true
  Bullet.counter_cache_enable = true
end
```

Fix N+1 with eager loading:

```ruby
# Bad — N+1
@posts = Post.all
@posts.each { |p| puts p.author.name }  # N queries for authors

# Good — includes
@posts = Post.includes(:author, :tags, comments: :author).all

# Good — references (needed for WHERE on included tables)
@posts = Post.includes(:author).references(:authors).where(authors: { active: true })

# preload vs eager_load vs includes
Post.preload(:comments)      # Always uses separate query
Post.eager_load(:comments)   # Always uses LEFT JOIN
Post.includes(:comments)     # Rails decides (usually separate unless referenced in WHERE/ORDER)
```

### counter_cache

```ruby
# db/migrate/..._add_comments_count_to_posts.rb
add_column :posts, :comments_count, :integer, default: 0, null: false

# app/models/comment.rb
class Comment < ApplicationRecord
  belongs_to :post, counter_cache: true
  # Automatically increments/decrements post.comments_count
end

# Backfill existing counts
Post.find_each { |post| Post.reset_counters(post.id, :comments) }

# Usage — no query needed
post.comments_count  # reads column, not a query
```

### Database Indexes

```ruby
# db/migrate/..._add_indexes.rb
class AddIndexes < ActiveRecord::Migration[8.0]
  def change
    # Basic index
    add_index :users, :email, unique: true

    # Composite index — order matters for query optimizer
    add_index :posts, [:user_id, :published_at]

    # Partial index — index only rows matching condition
    add_index :users, :email, where: "confirmed_at IS NOT NULL", name: "index_users_on_confirmed_email"

    # Covering index (PostgreSQL) — includes extra columns
    add_index :posts, :user_id, include: [:title, :published_at]

    # Expression index
    add_index :users, "lower(email)", name: "index_users_on_lower_email"
  end
end
```

Use `EXPLAIN ANALYZE` in PostgreSQL to verify index usage:

```ruby
# In Rails console
ActiveRecord::Base.connection.execute(
  "EXPLAIN ANALYZE #{User.where(email: 'test@example.com').to_sql}"
).to_a
```

### Caching

#### Russian Doll / Fragment Caching

```ruby
# app/views/posts/index.html.erb
<% cache ["posts-v1", @posts.cache_key_with_version] do %>
  <% @posts.each do |post| %>
    <%= render post %>  <%# renders app/views/posts/_post.html.erb %>
  <% end %>
<% end %>

# app/views/posts/_post.html.erb
<% cache ["post-v1", post] do %>
  <div class="post">
    <h2><%= post.title %></h2>
    <%= render post.author %>  <%# nested cache %>
  </div>
<% end %>
```

#### Low-Level Caching

```ruby
# app/models/product.rb
class Product < ApplicationRecord
  def expensive_calculation
    Rails.cache.fetch("product-#{id}-calculation-v1", expires_in: 1.hour) do
      # Expensive computation
      compute_analytics
    end
  end

  def self.featured
    Rails.cache.fetch("products-featured-v1", expires_in: 15.minutes) do
      includes(:category, :images).where(featured: true).to_a
    end
  end
end

# Invalidate on update
after_commit -> { Rails.cache.delete("product-#{id}-calculation-v1") }, on: [:update, :destroy]
```

#### Solid Cache (Rails 8 Default)

```ruby
# Gemfile
gem "solid_cache"

# config/environments/production.rb
config.cache_store = :solid_cache_store

# config/solid_cache.yml
default: &default
  database: cache
  store_options:
    max_age: <%= 7.days.to_i %>
    max_size: <%= 256.megabytes %>

production:
  <<: *default
```

Solid Cache uses the database as cache backend — no Redis required.

#### Redis Cache Store

```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, {
  url: ENV["REDIS_URL"],
  pool_size: ENV.fetch("RAILS_MAX_THREADS") { 5 },
  pool_timeout: 5,
  expires_in: 1.hour,
  error_handler: ->(method:, returning:, exception:) {
    Sentry.capture_exception(exception, extra: { method:, returning: })
  }
}
```

### Pagination

#### Kaminari

```ruby
# Gemfile
gem "kaminari"

# Controller
@posts = Post.page(params[:page]).per(25)

# View
= paginate @posts  # Haml / erb equivalent: <%= paginate @posts %>

# API pagination
render json: {
  posts: PostBlueprint.render_as_json(@posts),
  meta: {
    current_page: @posts.current_page,
    total_pages: @posts.total_pages,
    total_count: @posts.total_count
  }
}
```

#### Pagy (10-100x faster than Kaminari/will_paginate)

```ruby
# Gemfile
gem "pagy"

# config/initializers/pagy.rb
require "pagy/extras/metadata"
require "pagy/extras/items"      # allow per-page via params
require "pagy/extras/overflow"   # handle page > last_page

Pagy::DEFAULT[:items] = 25
Pagy::DEFAULT[:max_items] = 100

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pagy::Backend
end

# app/helpers/application_helper.rb
module ApplicationHelper
  include Pagy::Frontend
end

# Controller
def index
  @pagy, @posts = pagy(Post.published.order(created_at: :desc),
                        items: params.fetch(:per_page, 25))
end

# API response
render json: {
  posts: PostBlueprint.render_as_json(@posts),
  pagination: pagy_metadata(@pagy)
}
```

Pagy is the recommended choice for any performance-sensitive pagination.

### Database Connection Pooling

```ruby
# config/database.yml
production:
  adapter: postgresql
  url: <%= ENV["DATABASE_URL"] %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000
  checkout_timeout: 5
  idle_timeout: 300
  reconnect: true

# config/puma.rb — pool must match threads
max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# Verify pool in console
ActiveRecord::Base.connection_pool.stat
# => {:size=>5, :connections=>2, :busy=>1, :dead=>0, :idle=>1, :waiting=>0, :checkout_timeout=>5.0}
```

For high concurrency, consider PgBouncer as a connection pooler between Rails and PostgreSQL.

---

## 6. Security

### Strong Parameters

```ruby
# app/controllers/users_controller.rb
class UsersController < ApplicationController
  def create
    @user = User.new(user_params)
    if @user.save
      render json: @user, status: :created
    else
      render json: { errors: @user.errors }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(
      :email, :name, :password, :password_confirmation,
      :role,  # Only if user can set role — validate separately
      address_attributes: [:street, :city, :state, :zip],
      tag_ids: []
    )
  end
end
```

Never use `params.permit!` in production. Never pass `params` directly to model methods.

### CSRF Protection

```ruby
# Full-stack Rails — enabled by default
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  # For API + SPA on same domain (cookie-based session)
  protect_from_forgery with: :exception, unless: -> { request.format.json? }
end

# API mode — CSRF not relevant for token-based auth
# But for cookie-based API auth (same origin):
protect_from_forgery with: :null_session
```

For SPAs using Rails API, use `X-CSRF-Token` header:

```javascript
// Fetch the CSRF token from meta tag (if using session cookies)
const token = document.querySelector('meta[name="csrf-token"]')?.content;
fetch('/api/v1/posts', {
  method: 'POST',
  headers: { 'X-CSRF-Token': token, 'Content-Type': 'application/json' }
});
```

### SQL Injection Prevention

```ruby
# VULNERABLE — never do this
User.where("email = '#{params[:email]}'")
User.where("name LIKE '%#{params[:query]}%'")

# SAFE — parameterized queries
User.where(email: params[:email])
User.where("email = ?", params[:email])
User.where("name LIKE ?", "%#{params[:query]}%")
User.where("name LIKE :query", query: "%#{params[:query]}%")

# SAFE — sanitize_sql for dynamic column names
column = ActiveRecord::Base.connection.quote_column_name(params[:sort_column])
User.order(Arel.sql("#{column} #{params[:direction] == 'asc' ? 'ASC' : 'DESC'}"))
```

### XSS Prevention

```erb
<%# Rails auto-escapes — safe %>
<%= user.name %>

<%# Explicitly unescaped — only with sanitized/trusted content %>
<%= raw user.bio %>
<%= user.bio.html_safe %>  # Only safe if bio is sanitized

<%# Use ActionView::Helpers::SanitizeHelper %>
<%= sanitize user.bio, tags: %w[p b i em strong], attributes: %w[href] %>
```

### Mass Assignment Protection

```ruby
# app/models/user.rb — attr_readonly for critical fields
class User < ApplicationRecord
  attr_readonly :role, :admin

  # Use before_validation for derived fields
  before_validation :downcase_email

  private

  def downcase_email
    self.email = email&.downcase
  end
end
```

### Credentials Management

```bash
# Edit encrypted credentials (Rails 6+)
rails credentials:edit

# Per-environment credentials (Rails 6+)
rails credentials:edit --environment production

# Access in code
Rails.application.credentials.aws[:access_key_id]
Rails.application.credentials.dig(:aws, :secret_access_key)
Rails.application.credentials.secret_key_base!  # Raises if missing
```

```yaml
# config/credentials/production.yml.enc (decrypted view)
secret_key_base: abc123...
database:
  password: secret
aws:
  access_key_id: AKIAIOSFODNN7EXAMPLE
  secret_access_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
stripe:
  secret_key: sk_live_xxx
  webhook_secret: whsec_xxx
```

### Brakeman — Static Analysis

```bash
# Gemfile (development)
gem "brakeman", require: false

# Run
bundle exec brakeman
bundle exec brakeman -o output.html   # HTML report
bundle exec brakeman --no-pager -q    # CI-friendly
bundle exec brakeman --format json | jq .warnings[].warning_type | sort | uniq -c
```

Common Brakeman warnings and fixes:
- **SQL Injection** — use parameterized queries
- **Mass Assignment** — use `permit` whitelist
- **Dynamic Render** — avoid `render params[:template]`
- **Redirect** — use `redirect_back(fallback_location: root_path)` not `redirect_to params[:url]`

Integrate into CI:

```yaml
# .github/workflows/security.yml
- name: Brakeman Security Scan
  run: bundle exec brakeman -q --no-pager
```

### Content Security Policy

```ruby
# config/initializers/content_security_policy.rb
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, "*.amazonaws.com"
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https, :unsafe_inline  # Avoid unsafe-inline in production
    policy.connect_src :self, :https, "wss://myapp.com"
    policy.frame_ancestors :none  # Prevent clickjacking

    # Report violations
    policy.report_uri "/csp_reports"
  end

  # Report-Only mode for testing
  # config.content_security_policy_report_only = true

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
```

---

## 7. Testing

### RSpec Patterns

```ruby
# spec/rails_helper.rb (key config)
RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.filter_rails_from_backtrace!
  config.include FactoryBot::Syntax::Methods
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include ActionMailer::TestHelper
end

# spec/models/user_spec.rb — describe/context/it/let pattern
RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_length_of(:password).is_at_least(8) }
  end

  describe "associations" do
    it { is_expected.to have_many(:posts).dependent(:destroy) }
    it { is_expected.to belong_to(:organization).optional }
  end

  describe "#full_name" do
    let(:user) { build(:user, first_name: "Jane", last_name: "Doe") }

    it "returns first and last name combined" do
      expect(user.full_name).to eq("Jane Doe")
    end
  end

  context "when confirmed" do
    let(:user) { create(:user, :confirmed) }

    it "allows sign in" do
      expect(user.active_for_authentication?).to be true
    end
  end

  context "when locked" do
    let!(:user) { create(:user, locked_at: Time.current) }

    it "prevents sign in" do
      expect(user.access_locked?).to be true
    end
  end
end
```

### let vs let! vs subject

```ruby
RSpec.describe Order do
  # let — lazy, evaluated on first call
  let(:user) { create(:user) }
  let(:order) { create(:order, user: user) }

  # let! — eager, evaluated before each example (use sparingly)
  let!(:existing_order) { create(:order, :pending) }

  # subject — the primary object under test
  subject(:order) { described_class.new(user: user, total: 100) }

  # One-liner expectations use subject implicitly
  it { is_expected.to be_valid }
  it { is_expected.to respond_to(:total) }
end
```

### Shared Examples

```ruby
# spec/support/shared_examples/authenticatable.rb
RSpec.shared_examples "requires authentication" do
  it "returns 401 for unauthenticated requests" do
    subject
    expect(response).to have_http_status(:unauthorized)
  end
end

RSpec.shared_examples "paginatable resource" do |resource_name|
  it "returns pagination metadata" do
    subject
    json = response.parsed_body
    expect(json["meta"]).to include("current_page", "total_pages", "total_count")
  end
end

# Usage
RSpec.describe Api::V1::PostsController, type: :request do
  describe "GET /api/v1/posts" do
    subject { get "/api/v1/posts" }

    it_behaves_like "requires authentication"
    it_behaves_like "paginatable resource", "posts"
  end
end
```

### FactoryBot

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { Faker::Name.first_name }
    last_name  { Faker::Name.last_name }
    password   { "password123" }
    role       { :member }

    # Traits
    trait :admin do
      role { :admin }
    end

    trait :confirmed do
      confirmed_at { Time.current }
    end

    trait :with_avatar do
      after(:build) do |user|
        user.avatar.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/avatar.png")),
          filename: "avatar.png"
        )
      end
    end

    trait :with_posts do
      transient do
        posts_count { 3 }
      end

      after(:create) do |user, evaluator|
        create_list(:post, evaluator.posts_count, user: user)
      end
    end

    # Associations
    organization  # creates associated organization
    # Or explicitly:
    # association :organization, factory: [:organization, :active]
  end
end

# Usage
create(:user, :admin, :confirmed)
create(:user, :with_posts, posts_count: 5)
build_stubbed(:user)  # Does not hit DB — fastest
```

### Request Specs (Integration Tests)

```ruby
# spec/requests/api/v1/posts_spec.rb
RSpec.describe "Api::V1::Posts", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:headers) { { "Authorization" => "Bearer #{JwtService.encode(user_id: user.id)}" } }

  describe "GET /api/v1/posts" do
    let!(:posts) { create_list(:post, 3, :published, user: user) }
    let!(:draft)  { create(:post, :draft, user: user) }

    it "returns published posts" do
      get "/api/v1/posts", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["posts"].length).to eq(3)
      expect(json["posts"].map { |p| p["id"] }).not_to include(draft.id)
    end

    it "paginates results" do
      get "/api/v1/posts", params: { page: 1, per_page: 2 }, headers: headers

      json = response.parsed_body
      expect(json["posts"].length).to eq(2)
      expect(json["meta"]["total_count"]).to eq(3)
    end
  end

  describe "POST /api/v1/posts" do
    let(:valid_params) { { post: { title: "New Post", body: "Content", tag_ids: [] } } }

    context "with valid params" do
      it "creates a post" do
        expect {
          post "/api/v1/posts", params: valid_params, headers: headers
        }.to change(Post, :count).by(1)

        expect(response).to have_http_status(:created)
      end
    end

    context "with invalid params" do
      it "returns errors" do
        post "/api/v1/posts", params: { post: { title: "" } }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]).to include("Title can't be blank")
      end
    end
  end
end
```

### System Tests with Capybara

```ruby
# Gemfile
gem "capybara"
gem "selenium-webdriver"
gem "cuprite", group: :test  # Chrome CDP driver, faster than Selenium

# spec/support/capybara.rb
require "capybara/cuprite"

Capybara.default_driver = :rack_test
Capybara.javascript_driver = :cuprite

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app,
    window_size: [1200, 800],
    browser_options: { "no-sandbox": nil },
    headless: ENV.fetch("HEADLESS", "true") == "true",
    slowmo: ENV.fetch("SLOWMO", 0).to_f)
end

# spec/system/user_registration_spec.rb
RSpec.describe "User Registration", type: :system do
  before { driven_by(:cuprite) }

  it "allows a new user to register" do
    visit new_user_registration_path

    fill_in "Email", with: "newuser@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"
    click_button "Sign Up"

    expect(page).to have_text("Welcome! You have signed up successfully.")
    expect(page).to have_current_path(root_path)
  end

  it "shows errors for invalid data" do
    visit new_user_registration_path
    click_button "Sign Up"

    expect(page).to have_text("Email can't be blank")
    expect(page).to have_text("Password can't be blank")
  end
end
```

### VCR / WebMock for HTTP Mocking

```ruby
# Gemfile
gem "vcr", group: :test
gem "webmock", group: :test

# spec/support/vcr.rb
require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data("<STRIPE_KEY>") { Rails.application.credentials.stripe[:secret_key] }
  config.default_cassette_options = {
    record: :once,
    match_requests_on: [:method, :uri, :body]
  }
end

# Usage with RSpec metadata tag
RSpec.describe StripeService, type: :service do
  describe "#create_customer" do
    it "creates a Stripe customer", :vcr do
      # First run: records real HTTP. Subsequent: replays.
      customer = StripeService.new.create_customer(email: "test@example.com")
      expect(customer.id).to start_with("cus_")
    end
  end
end

# Manual WebMock stubbing
RSpec.describe WeatherService do
  before do
    stub_request(:get, "https://api.weather.com/v1/current")
      .with(query: { city: "Portland", apikey: /.*/ })
      .to_return(
        status: 200,
        body: { temperature: 65, condition: "cloudy" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  it "returns weather data" do
    result = WeatherService.current_weather("Portland")
    expect(result[:temperature]).to eq(65)
  end
end
```

### Parallel Tests

```ruby
# Gemfile
gem "parallel_tests", group: :development

# Run in parallel (uses CPU cores)
bundle exec parallel_rspec spec/

# Setup parallel databases
bundle exec rake parallel:create
bundle exec rake parallel:migrate
bundle exec rake parallel:seed

# config/database.yml — TEST_ENV_NUMBER auto-set
test:
  database: myapp_test<%= ENV["TEST_ENV_NUMBER"] %>
```

---

## 8. Common Gems

### devise

```ruby
gem "devise"  # Authentication framework
# Features: registerable, authenticatable, recoverable, rememberable,
#           validatable, confirmable, lockable, trackable, omniauthable
```

### pundit / cancancan

```ruby
gem "pundit"  # Policy objects — explicit, testable

# app/policies/post_policy.rb
class PostPolicy < ApplicationPolicy
  def update?
    user.admin? || record.user == user
  end

  def destroy?
    user.admin? || (record.user == user && record.draft?)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user.admin?
      scope.where(user: user).or(scope.where(published: true))
    end
  end
end

# Controller
class PostsController < ApplicationController
  include Pundit::Authorization
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    @posts = policy_scope(Post)
  end

  def update
    @post = Post.find(params[:id])
    authorize @post
    # ...
  end
end
```

```ruby
gem "cancancan"  # Ability-based authorization — centralized

# app/models/ability.rb
class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    if user.admin?
      can :manage, :all
    else
      can :read, Post, published: true
      can [:create, :update, :destroy], Post, user_id: user.id
      can :read, User, id: user.id
    end
  end
end

# Controller
load_and_authorize_resource  # Automatic authorization
```

Pundit is preferred for complex, context-dependent rules. CanCanCan for simpler role-based auth.

### sidekiq

```ruby
gem "sidekiq"
# Web UI: mount Sidekiq::Web in routes
# Pro features: batches, rate limiting, scheduled jobs UI
```

### ransack

```ruby
gem "ransack"  # Search & sort builder

# Controller
def index
  @q = Product.ransack(params[:q])
  @products = @q.result(distinct: true).includes(:category).page(params[:page])
end

# View
<%= search_form_for @q do |f| %>
  <%= f.label :name_cont %>
  <%= f.search_field :name_cont, placeholder: "Search..." %>
  <%= f.label :price_gteq %>
  <%= f.number_field :price_gteq %>
  <%= f.submit %>
<% end %>

# API usage
@q = Product.ransack(params[:q].permit(:name_cont, :price_gteq, :category_id_eq))
```

Whitelist permitted attributes: `Product.ransackable_attributes` and `ransackable_associations`.

### paper_trail

```ruby
gem "paper_trail"  # Audit trail / versioning

# app/models/product.rb
class Product < ApplicationRecord
  has_paper_trail only: [:name, :price, :description],
                  ignore: [:updated_at],
                  meta: { user_id: :current_user_id }

  def current_user_id
    # Access current user from thread-local or Current model
    Current.user&.id
  end
end

# Querying versions
product.versions          # All versions
product.versions.last     # Most recent
product.paper_trail.previous_version  # Restore to previous
product.paper_trail.version_at(1.hour.ago)  # Point-in-time

# Revert
product.paper_trail.previous_version.save!
```

### friendly_id

```ruby
gem "friendly_id"

# db/migrate
add_column :posts, :slug, :string, null: false
add_index :posts, :slug, unique: true

# app/models/post.rb
class Post < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: [:slugged, :history]  # history tracks old slugs

  def should_generate_new_friendly_id?
    title_changed? || super
  end
end

# Usage
Post.friendly.find("my-post-title")  # Works with old slugs too if :history used
post_path(@post)  # /posts/my-post-title
```

### pg_search

```ruby
gem "pg_search"

# app/models/product.rb
class Product < ApplicationRecord
  include PgSearch::Model

  pg_search_scope :search_by_all,
    against: {
      name: "A",        # Weight A = highest
      description: "B"
    },
    using: {
      tsearch: {
        dictionary: "english",
        prefix: true,
        tsvector_column: "searchable"  # Use materialized tsvector column
      },
      trigram: { threshold: 0.2 }  # Fuzzy matching
    }

  multisearchable against: [:name, :description]  # Global search
end

# Add tsvector column for performance
add_column :products, :searchable, :tsvector
add_index :products, :searchable, using: :gin
```

### scenic

```ruby
gem "scenic"  # Database views with Rails migrations

rails generate scenic:view user_summaries
# Creates db/views/user_summaries_v01.sql and migration

# db/views/user_summaries_v01.sql
SELECT
  users.id,
  users.email,
  COUNT(DISTINCT orders.id) AS orders_count,
  SUM(orders.total_cents) AS total_revenue_cents,
  MAX(orders.created_at) AS last_order_at
FROM users
LEFT JOIN orders ON orders.user_id = users.id AND orders.status = 'completed'
GROUP BY users.id;

# app/models/user_summary.rb
class UserSummary < ApplicationRecord
  self.primary_key = :id

  belongs_to :user
  # Readonly — views are not writable
end

# Materialized views (refreshable)
rails generate scenic:view user_summaries --materialized
UserSummary.refresh  # Refresh the materialized view
```

### strong_migrations

```ruby
gem "strong_migrations"

# Catches unsafe migrations at runtime in development
# Examples of what it catches:
# - Adding a NOT NULL column without a default
# - Adding an index without CONCURRENTLY
# - Changing column types on large tables

# When you need to do something strong_migrations blocks:
class AddStatusToUsers < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!  # Required for CONCURRENTLY

  def change
    add_column :users, :status, :string
    add_index :users, :status, algorithm: :concurrently  # Safe on large tables
  end
end

# For NOT NULL columns on existing tables:
# 1. Add column with default
# 2. Backfill in batches (separate migration or job)
# 3. Add NOT NULL constraint
```

### annotate

```ruby
gem "annotate", group: :development

bundle exec annotate --models  # Adds schema comments to model files
bundle exec annotate --routes  # Annotates routes.rb

# Auto-run after migrations
# In lib/tasks/auto_annotate_models.rake
if Rails.env.development?
  task :annotate do
    puts "Annotating models..."
    system "bundle exec annotate --models --exclude tests,fixtures,factories"
  end
  Rake::Task["db:migrate"].enhance do
    Rake::Task["annotate"].invoke
  end
end
```

---

## 9. Project Conventions

### Service Objects

Encapsulate complex business logic outside models and controllers:

```ruby
# app/services/order_service.rb
class OrderService
  Result = Struct.new(:success?, :order, :errors, keyword_init: true)

  def initialize(user:, cart:, payment_params:)
    @user = user
    @cart = cart
    @payment_params = payment_params
  end

  def call
    ActiveRecord::Base.transaction do
      order = create_order
      charge_payment(order)
      send_confirmation(order)
      Result.new(success?: true, order: order, errors: [])
    end
  rescue PaymentError => e
    Result.new(success?: false, order: nil, errors: [e.message])
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success?: false, order: nil, errors: e.record.errors.full_messages)
  end

  private

  def create_order
    Order.create!(user: @user, items: @cart.items, total: @cart.total)
  end

  def charge_payment(order)
    PaymentGateway.charge!(order: order, **@payment_params)
  rescue Stripe::CardError => e
    raise PaymentError, e.message
  end

  def send_confirmation(order)
    OrderMailer.confirmation(order).deliver_later
  end
end

# Controller — thin, delegates to service
def create
  result = OrderService.new(
    user: current_user,
    cart: current_cart,
    payment_params: payment_params
  ).call

  if result.success?
    render json: OrderBlueprint.render(result.order), status: :created
  else
    render json: { errors: result.errors }, status: :unprocessable_entity
  end
end
```

### Form Objects

Handle complex multi-model forms or parameter objects:

```ruby
# app/forms/registration_form.rb
class RegistrationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :email, :string
  attribute :password, :string
  attribute :company_name, :string
  attribute :plan, :string, default: "starter"

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 8 }
  validates :company_name, presence: true
  validates :plan, inclusion: { in: %w[starter pro enterprise] }

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      org = Organization.create!(name: company_name, plan: plan)
      User.create!(email: email, password: password, organization: org, role: :owner)
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    errors.merge!(e.record.errors)
    false
  end
end

# Controller
def create
  @form = RegistrationForm.new(registration_params)
  if @form.save
    redirect_to dashboard_path, notice: "Welcome!"
  else
    render :new, status: :unprocessable_entity
  end
end

private

def registration_params
  params.require(:registration).permit(:email, :password, :company_name, :plan)
end
```

### Query Objects

Encapsulate complex ActiveRecord queries for reusability and testability:

```ruby
# app/queries/posts_query.rb
class PostsQuery
  def initialize(scope = Post.all)
    @scope = scope
  end

  def published
    @scope = @scope.where(published: true, published_at: ..Time.current)
    self
  end

  def by_author(user)
    @scope = @scope.where(user: user)
    self
  end

  def with_min_views(count)
    @scope = @scope.where("views_count >= ?", count)
    self
  end

  def tagged_with(tag_name)
    @scope = @scope.joins(:tags).where(tags: { name: tag_name })
    self
  end

  def recent(limit: 10)
    @scope = @scope.order(published_at: :desc).limit(limit)
    self
  end

  def call
    @scope.includes(:author, :tags)
  end
end

# Usage
posts = PostsQuery.new
  .published
  .by_author(current_user)
  .tagged_with("rails")
  .recent(limit: 5)
  .call

# In controller
@posts = PostsQuery.new(Post.all).published.recent.call
```

### Presenters / Decorators

Separate view logic from models:

```ruby
# app/presenters/user_presenter.rb
class UserPresenter
  include ActionView::Helpers::NumberHelper
  include Rails.application.routes.url_helpers

  def initialize(user, view_context = nil)
    @user = user
    @view = view_context
  end

  def full_name
    [@user.first_name, @user.last_name].compact.join(" ").presence || "Anonymous"
  end

  def formatted_join_date
    @user.created_at.strftime("%B %Y")
  end

  def avatar_url(size: :medium)
    if @user.avatar.attached?
      Rails.application.routes.url_helpers.rails_representation_url(
        @user.avatar.variant(resize_to_fill: [100, 100]),
        only_path: true
      )
    else
      "/images/default-avatar.png"
    end
  end

  def membership_badge
    case @user.role
    when "admin" then "Admin"
    when "pro"   then "Pro Member"
    else              "Member"
    end
  end

  def total_spent
    number_to_currency(@user.orders.completed.sum(:total_cents) / 100.0)
  end

  def to_model
    @user  # Delegates respond_to?, model_name etc.
  end
end

# app/helpers/application_helper.rb
def present(model, presenter_class = nil)
  presenter_class ||= "#{model.class}Presenter".constantize
  presenter = presenter_class.new(model, self)
  block_given? ? yield(presenter) : presenter
end

# View usage
<% present @user do |user| %>
  <h1><%= user.full_name %></h1>
  <img src="<%= user.avatar_url(size: :large) %>">
  <span class="badge"><%= user.membership_badge %></span>
  <p>Member since <%= user.formatted_join_date %></p>
<% end %>
```

### Concerns Usage

Concerns extract reusable modules. Use them sparingly — prefer service objects for complex logic:

```ruby
# app/models/concerns/searchable.rb
module Searchable
  extend ActiveSupport::Concern

  included do
    scope :search, ->(query) {
      return all if query.blank?
      where("#{table_name}.name ILIKE ?", "%#{query.strip}%")
    }
  end
end

# app/models/concerns/soft_deletable.rb
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    scope :active,   -> { where(deleted_at: nil) }
    scope :deleted,  -> { where.not(deleted_at: nil) }

    before_destroy :soft_delete, prepend: true
  end

  def soft_delete
    throw(:abort) if update_column(:deleted_at, Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end
end

# app/models/product.rb
class Product < ApplicationRecord
  include Searchable
  include SoftDeletable
end
```

Controller concerns:

```ruby
# app/controllers/concerns/paginatable.rb
module Paginatable
  extend ActiveSupport::Concern

  included do
    include Pagy::Backend
  end

  private

  def paginate(scope)
    @pagy, records = pagy(scope, items: per_page)
    [records, pagy_metadata(@pagy)]
  end

  def per_page
    [params.fetch(:per_page, 25).to_i, 100].min
  end
end
```

---

## Quick Reference — Tooling Decisions

| Need | Recommended | Notes |
|---|---|---|
| JSON serialization | Alba or Blueprinter | AMS is legacy |
| Auth (web app) | Rails 8 generator | Simple; Devise for full features |
| Auth (API) | JWT + ruby-jwt | Or API token with has_secure_token |
| OAuth provider | Doorkeeper | |
| Background jobs | Solid Queue | No Redis required; Sidekiq if high volume |
| Cron/recurring | GoodJob or Sidekiq-cron | |
| Deployment | Kamal 2 | Capistrano is legacy |
| Caching | Solid Cache | Redis cache if already using Redis |
| Pagination | Pagy | 100x faster than Kaminari |
| N+1 detection | Bullet | Dev only |
| Security scanning | Brakeman | Integrate into CI |
| Authorization | Pundit | CanCanCan for simple role systems |
| Search | pg_search (PostgreSQL) | Ransack for filter/sort UI |
| Audit trail | paper_trail | |
| DB views | Scenic | |
| Safe migrations | strong_migrations | |
| Testing | RSpec + FactoryBot + Pagy | |
| HTTP mocking | VCR + WebMock | |
| System tests | Cuprite (CDP) | Faster than Selenium |
