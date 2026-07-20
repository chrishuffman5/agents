# Rails Best Practices Reference

Production patterns for Rails 7.2-8.1. Load this file when answering questions about API mode, authentication, background jobs, deployment, performance, testing, security, common gems, or project conventions.

---

## API Mode

### rails new --api

API-only applications strip the middleware stack to essentials: no cookies, sessions, flash, or asset pipeline.

```bash
rails new my_api --api --database=postgresql
```

`ApplicationController` inherits from `ActionController::API` (not `Base`). Slimmer middleware stack (~12 vs ~20+), faster request/response cycle.

```ruby
class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

  private

  def not_found(exception)
    render json: { error: exception.message }, status: :not_found
  end

  def unprocessable_entity(exception)
    render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_entity
  end
end
```

### CORS

```ruby
# Gemfile
gem "rack-cors"

# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("CORS_ORIGINS", "http://localhost:3000").split(",")
    resource "/api/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      max_age: 86400
  end
end
```

### JSON Serialization

| Library | Speed | Style | Recommendation |
|---|---|---|---|
| jbuilder | Slowest | View-based templates | Ships with Rails; complex conditional rendering |
| ActiveModel::Serializer | Slow | Class-based | Legacy -- avoid for new projects |
| Blueprinter | Fast | Explicit views | Good readability, multiple views |
| Alba | Fastest (10-30x AMS) | Resource classes | Best performance choice |

**Alba (recommended for performance):**

```ruby
class UserResource
  include Alba::Resource
  root_key :user, :users
  attributes :id, :email, :name

  attribute :full_name do |user|
    "#{user.first_name} #{user.last_name}"
  end

  many :posts, resource: PostResource
end

render json: UserResource.new(@user).serialize
```

**Blueprinter (recommended for readability):**

```ruby
class UserBlueprint < Blueprinter::Base
  identifier :id
  view :default do
    fields :email, :name, :created_at
  end
  view :extended do
    include_view :default
    association :posts, blueprint: PostBlueprint
  end
end

render json: UserBlueprint.render(@user, view: :extended)
```

### API Versioning

URL namespace versioning is simplest to cache, test, and document:

```ruby
namespace :api do
  namespace :v1 do
    resources :users
  end
  namespace :v2 do
    resources :users
  end
end
```

---

## Authentication

### Devise (Full-featured)

```ruby
gem "devise"

rails generate devise:install
rails generate devise User

class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable
end
```

For API use, add `devise-jwt`:

```ruby
gem "devise-jwt"

# config/initializers/devise.rb
Devise.setup do |config|
  config.jwt do |jwt|
    jwt.secret = Rails.application.credentials.devise_jwt_secret_key!
    jwt.expiration_time = 1.day.to_i
  end
end
```

### Rails 8 Authentication Generator

No gem required -- session-based, password-resettable, metadata-tracking:

```bash
bin/rails generate authentication
# Creates: User model, Session model, migrations,
#          SessionsController, PasswordsController,
#          authentication concern, password mailer
```

Best for new Rails 8+ apps that do not need the full Devise feature set.

### JWT (Stateless API Auth)

```ruby
gem "jwt"

class JwtService
  ALGORITHM = "HS256".freeze

  def self.encode(payload)
    payload[:exp] = 24.hours.from_now.to_i
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
```

### OmniAuth (OAuth SSO)

```ruby
gem "omniauth"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection"
```

### Authorization -- Pundit vs CanCanCan

**Pundit** (preferred for complex, context-dependent rules):

```ruby
class PostPolicy < ApplicationPolicy
  def update?
    user.admin? || record.user == user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user.admin?
      scope.where(user: user).or(scope.where(published: true))
    end
  end
end
```

**CanCanCan** (simpler role-based systems):

```ruby
class Ability
  include CanCan::Ability
  def initialize(user)
    if user.admin?
      can :manage, :all
    else
      can :read, Post, published: true
      can [:create, :update, :destroy], Post, user_id: user.id
    end
  end
end
```

---

## Background Jobs

### Adapter Comparison

| Feature | Solid Queue | Sidekiq | GoodJob |
|---|---|---|---|
| Backend | PostgreSQL/SQLite/MySQL | Redis | PostgreSQL |
| Rails default (8.x) | Yes | No | No |
| Web UI | Mission Control | Sidekiq Web | Built-in |
| Cron/recurring | Yes | Yes (Pro/gems) | Yes |
| Licensing | MIT | LGPL + Pro ($) | MIT |
| Throughput | Good | Excellent | Good |

**Solid Queue** -- Ships with Rails 8, zero extra infrastructure:

```yaml
# config/queue.yml
production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "critical,default"
      threads: 5
      processes: 2
    - queues: "low"
      threads: 2
      polling_interval: 2
```

**Sidekiq** -- Best throughput for high-volume Redis shops:

```yaml
# config/sidekiq.yml
:concurrency: 10
:queues:
  - [critical, 3]
  - [default, 2]
  - [low, 1]
```

### Job Patterns

```ruby
class ProcessPaymentJob < ApplicationJob
  queue_as :critical
  retry_on Stripe::RateLimitError, wait: :polynomially_longer, attempts: 5
  retry_on Net::ReadTimeout, wait: 5.seconds, attempts: 3
  discard_on Stripe::InvalidRequestError

  def perform(order_id)
    order = Order.find(order_id)
    PaymentService.new(order).process!
  end
end
```

### Recurring Jobs

```yaml
# config/recurring.yml (Solid Queue)
production:
  cleanup_sessions:
    class: CleanupExpiredSessionsJob
    schedule: every day at 2am
```

---

## Deployment

### Kamal 2 (Default in Rails 8)

Docker-based deployment to any VPS/bare metal with zero-downtime rolling deploys.

```yaml
# config/deploy.yml
service: myapp
image: your-registry/myapp

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
  username: your-username
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL
```

```bash
kamal setup          # First-time server provisioning
kamal deploy         # Zero-downtime deploy
kamal rollback       # Roll back to previous version
kamal app logs       # Tail logs
kamal app exec -i --reuse "bin/rails console"
```

**Kamal Proxy** replaces Traefik -- automatic SSL via Let's Encrypt, health check awareness, zero-downtime drain.

### Docker Multi-Stage Build

```dockerfile
ARG RUBY_VERSION=3.4.0
FROM ruby:$RUBY_VERSION-slim AS base
WORKDIR /rails
ENV RAILS_ENV="production" BUNDLE_DEPLOYMENT="1" BUNDLE_WITHOUT="development"

FROM base AS build
RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    build-essential git libpq-dev libvips pkg-config curl
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .
RUN bundle exec bootsnap precompile --gemfile && bundle exec bootsnap precompile app/ lib/
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

FROM base
RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    curl libvips postgresql-client && rm -rf /var/lib/apt/lists
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails
RUN useradd rails --create-home --shell /bin/bash && chown -R rails:rails db log storage tmp
USER rails:rails
EXPOSE 3000
CMD ["./bin/rails", "server"]
```

### Kamal Hooks

```bash
# .kamal/hooks/pre-deploy
#!/bin/bash
set -e
bundle exec rspec --tag smoke
bundle exec brakeman -q
```

### Platform Alternatives

- **Heroku**: Ephemeral filesystem -- use Active Storage with S3. Set `DATABASE_URL`, `WEB_CONCURRENCY`, `RAILS_MAX_THREADS`.
- **Fly.io**: Good for global distribution. Use `fly.toml` with release command for migrations.
- **Render**: Simple PaaS with `render.yaml` configuration.
- **Capistrano**: Legacy. Use Kamal 2 for new deployments.

---

## Performance

### N+1 Detection -- Bullet Gem

```ruby
gem "bullet", group: :development

# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true
  Bullet.rails_logger = true
  Bullet.add_footer = true
end
```

Fix N+1 with eager loading:

```ruby
# Bad
@posts = Post.all
@posts.each { |p| puts p.author.name }  # N queries

# Good
@posts = Post.includes(:author, :tags, comments: :author).all
```

### counter_cache

```ruby
# Migration
add_column :posts, :comments_count, :integer, default: 0, null: false

# Model
class Comment < ApplicationRecord
  belongs_to :post, counter_cache: true
end

# Backfill
Post.find_each { |post| Post.reset_counters(post.id, :comments) }
```

### Caching

**Fragment caching (Russian doll):**

```erb
<% cache ["post-v1", post] do %>
  <div class="post">
    <h2><%= post.title %></h2>
    <%= render post.author %>
  </div>
<% end %>
```

**Low-level caching:**

```ruby
def expensive_calculation
  Rails.cache.fetch("product-#{id}-calc-v1", expires_in: 1.hour) do
    compute_analytics
  end
end
```

### Database Indexes

```ruby
add_index :users, :email, unique: true
add_index :posts, [:user_id, :published_at]                          # composite
add_index :users, :email, where: "confirmed_at IS NOT NULL"          # partial
add_index :posts, :user_id, include: [:title, :published_at]         # covering (PG)
```

Verify with `EXPLAIN ANALYZE`:

```ruby
ActiveRecord::Base.connection.execute(
  "EXPLAIN ANALYZE #{User.where(email: 'test@example.com').to_sql}"
).to_a
```

### Database Connection Pooling

```yaml
# config/database.yml
production:
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000
  checkout_timeout: 5
```

Pool must match Puma thread count. For high concurrency, use PgBouncer between Rails and PostgreSQL.

---

## Testing

### RSpec + FactoryBot

```ruby
# spec/models/user_spec.rb
RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  end

  describe "associations" do
    it { is_expected.to have_many(:posts).dependent(:destroy) }
  end
end
```

### FactoryBot

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    trait :admin do
      role { :admin }
    end
    trait :with_posts do
      transient { posts_count { 3 } }
      after(:create) { |user, e| create_list(:post, e.posts_count, user: user) }
    end
  end
end

create(:user, :admin, :with_posts, posts_count: 5)
build_stubbed(:user)  # no DB hit -- fastest
```

### Request Specs

```ruby
RSpec.describe "Api::V1::Posts", type: :request do
  let(:user) { create(:user) }
  let(:headers) { { "Authorization" => "Bearer #{JwtService.encode(user_id: user.id)}" } }

  describe "GET /api/v1/posts" do
    let!(:posts) { create_list(:post, 3, :published) }

    it "returns published posts" do
      get "/api/v1/posts", headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["posts"].length).to eq(3)
    end
  end
end
```

### System Tests

```ruby
gem "capybara"
gem "cuprite", group: :test  # Chrome CDP driver, faster than Selenium

RSpec.describe "User Registration", type: :system do
  before { driven_by(:cuprite) }

  it "allows a new user to register" do
    visit new_user_registration_path
    fill_in "Email", with: "new@example.com"
    fill_in "Password", with: "password123"
    click_button "Sign Up"
    expect(page).to have_text("Welcome!")
  end
end
```

### VCR + WebMock

```ruby
VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data("<STRIPE_KEY>") { Rails.application.credentials.stripe[:secret_key] }
end

it "creates a customer", :vcr do
  customer = StripeService.new.create_customer(email: "test@example.com")
  expect(customer.id).to start_with("cus_")
end
```

### Minitest (Default)

```ruby
class ArticleTest < ActiveSupport::TestCase
  test "is valid with valid attributes" do
    article = Article.new(title: "Hello", body: "World", author: users(:alice))
    assert article.valid?
  end
end
```

---

## Security

### Strong Parameters

```ruby
def user_params
  params.require(:user).permit(:email, :name, :password, address_attributes: [:street, :city])
end
```

Never use `params.permit!` in production. Never pass `params` directly to model methods.

### SQL Injection Prevention

```ruby
# VULNERABLE
User.where("email = '#{params[:email]}'")

# SAFE
User.where(email: params[:email])
User.where("email = ?", params[:email])
```

### CSRF Protection

```ruby
# Full-stack (default)
protect_from_forgery with: :exception

# API mode with cookie-based auth
protect_from_forgery with: :null_session
```

### Credentials Management

```bash
rails credentials:edit --environment production
```

### Brakeman (Static Analysis)

```bash
bundle exec brakeman -q --no-pager  # CI-friendly
```

### Content Security Policy

```ruby
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.script_src  :self, :https
    policy.style_src   :self, :https
    policy.connect_src :self, :https, "wss://myapp.com"
    policy.frame_ancestors :none
  end
end
```

---

## Common Gems

| Need | Recommended | Notes |
|---|---|---|
| JSON serialization | Alba or Blueprinter | AMS is legacy |
| Auth (web) | Rails 8 generator or Devise | |
| Auth (API) | JWT + ruby-jwt | Or API token with has_secure_token |
| OAuth provider | Doorkeeper | |
| Background jobs | Solid Queue | Sidekiq for high volume |
| Deployment | Kamal 2 | Capistrano is legacy |
| Caching | Solid Cache | Redis if already using Redis |
| Pagination | Pagy | 100x faster than Kaminari |
| N+1 detection | Bullet | Dev only |
| Security scanning | Brakeman | CI integration |
| Authorization | Pundit | CanCanCan for simple roles |
| Search | pg_search (PG) | Ransack for filter/sort UI |
| Audit trail | paper_trail | |
| DB views | Scenic | |
| Safe migrations | strong_migrations | |
| Friendly URLs | friendly_id | |
| Schema annotation | annotate | |
| System tests | Cuprite (CDP) | Faster than Selenium |

---

## Project Conventions

### Service Objects

Encapsulate complex business logic outside models and controllers:

```ruby
class OrderService
  Result = Struct.new(:success?, :order, :errors, keyword_init: true)

  def initialize(user:, cart:, payment_params:)
    @user = user
    @cart = cart
    @payment_params = payment_params
  end

  def call
    ActiveRecord::Base.transaction do
      order = Order.create!(user: @user, items: @cart.items, total: @cart.total)
      PaymentGateway.charge!(order: order, **@payment_params)
      OrderMailer.confirmation(order).deliver_later
      Result.new(success?: true, order: order, errors: [])
    end
  rescue PaymentError => e
    Result.new(success?: false, order: nil, errors: [e.message])
  end
end
```

### Form Objects

Handle complex multi-model forms:

```ruby
class RegistrationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :email, :string
  attribute :password, :string
  attribute :company_name, :string

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 8 }

  def save
    return false unless valid?
    ActiveRecord::Base.transaction do
      org = Organization.create!(name: company_name)
      User.create!(email: email, password: password, organization: org, role: :owner)
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.merge!(e.record.errors)
    false
  end
end
```

### Query Objects

```ruby
class PostsQuery
  def initialize(scope = Post.all)
    @scope = scope
  end

  def published
    @scope = @scope.where(published: true)
    self
  end

  def by_author(user)
    @scope = @scope.where(user: user)
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

posts = PostsQuery.new.published.by_author(user).recent(limit: 5).call
```

### Concerns

Extract reusable modules (use sparingly -- prefer service objects for complex logic):

```ruby
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    scope :active,  -> { where(deleted_at: nil) }
    scope :deleted, -> { where.not(deleted_at: nil) }
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end
end
```

### ViewComponent (by GitHub)

Testable, encapsulated view objects:

```ruby
class AlertComponent < ViewComponent::Base
  def initialize(message:, variant: "info")
    @message = message
    @variant = variant
  end
end
```

```erb
<%# app/components/alert_component.html.erb %>
<div class="alert alert-<%= @variant %>"><%= @message %></div>
```
