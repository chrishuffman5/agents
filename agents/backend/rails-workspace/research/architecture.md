# Ruby on Rails Architecture — Cross-Version Fundamentals

> Target audience: Senior Rails developers. Examples reflect Rails 7.x/8.x idioms unless noted.
> Last updated: 2026-04-09

---

## Table of Contents

1. [ActiveRecord](#1-activerecord)
2. [Action Pack — Controllers & Routing](#2-action-pack)
3. [Action View](#3-action-view)
4. [Active Job](#4-active-job)
5. [Action Cable](#5-action-cable)
6. [Action Mailer](#6-action-mailer)
7. [Turbo / Hotwire](#7-turbohotwire)
8. [Active Storage](#8-active-storage)
9. [Middleware Stack](#9-middleware-stack)
10. [Configuration](#10-configuration)
11. [Testing](#11-testing)
12. [Engines](#12-engines)

---

## 1. ActiveRecord

ActiveRecord is Rails' ORM layer implementing the Active Record pattern: each class maps to a database table, each instance to a row. It sits atop Arel (the query AST) and exposes a chainable query interface.

### 1.1 Models

```ruby
# Minimal model — convention drives everything
class Article < ApplicationRecord
  # Table: articles
  # Columns inferred from schema at boot
end
```

`ApplicationRecord` inherits from `ActiveRecord::Base` and serves as the shared base for application models (added in Rails 5). This is where you'd add global concerns, default scopes you want everywhere, or shared plugins.

```ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Example: global soft-delete concern
  include SoftDeletable
end
```

### 1.2 Associations

Rails associations are macros that generate helper methods and manage foreign-key conventions.

#### belongs_to

```ruby
class Comment < ApplicationRecord
  # Adds comment.article, comment.article=, comment.build_article, etc.
  # Rails 5+: required by default (validates presence of article_id)
  belongs_to :article
  belongs_to :author, class_name: "User", optional: true
end
```

#### has_many / has_one

```ruby
class Article < ApplicationRecord
  has_many :comments, dependent: :destroy
  has_many :approved_comments, -> { where(approved: true) }, class_name: "Comment"
  has_one  :featured_image, class_name: "Attachment", dependent: :destroy
end
```

#### has_many :through

Join through an intermediate model, giving you access to the join record itself.

```ruby
class Physician < ApplicationRecord
  has_many :appointments
  has_many :patients, through: :appointments
end

class Appointment < ApplicationRecord
  belongs_to :physician
  belongs_to :patient
  # Extra columns on the join: scheduled_at, notes
end

class Patient < ApplicationRecord
  has_many :appointments
  has_many :physicians, through: :appointments
end

# Usage
physician.patients           # SELECT patients via appointments
physician.appointments.first.scheduled_at  # join record data
```

#### has_and_belongs_to_many (HABTM)

Use only when you have no data on the join record. Prefer `has_many :through` otherwise.

```ruby
class Assembly < ApplicationRecord
  has_and_belongs_to_many :parts
end
# Requires assemblies_parts join table (no primary key, no timestamps by default)
```

#### Polymorphic Associations

One model belongs to multiple other models via a type/id pair.

```ruby
class Picture < ApplicationRecord
  belongs_to :imageable, polymorphic: true
  # imageable_type: "Employee" | "Product"
  # imageable_id: integer
end

class Employee < ApplicationRecord
  has_many :pictures, as: :imageable
end

class Product < ApplicationRecord
  has_many :pictures, as: :imageable
end
```

Migration for the polymorphic side:

```ruby
create_table :pictures do |t|
  t.string  :imageable_type, null: false
  t.integer :imageable_id,   null: false
  t.string  :name
  t.timestamps
  t.index [:imageable_type, :imageable_id]
end
```

#### Self-Referential Associations

```ruby
class Employee < ApplicationRecord
  belongs_to :manager,  class_name: "Employee", optional: true
  has_many   :reports,  class_name: "Employee", foreign_key: :manager_id
end
```

#### Association Options Worth Knowing

| Option | Purpose |
|--------|---------|
| `dependent: :destroy` | Destroy associated records |
| `dependent: :delete_all` | SQL DELETE without callbacks |
| `dependent: :nullify` | Set FK to NULL |
| `dependent: :restrict_with_error` | Error if children exist |
| `counter_cache: true` | Maintain count column on parent |
| `touch: true` | Update parent's `updated_at` |
| `inverse_of:` | Bi-directional in-memory linking |
| `strict_loading:` | Raise on N+1 at association access |

### 1.3 Scopes

Scopes are chainable query fragments defined on the model class.

```ruby
class Article < ApplicationRecord
  scope :published,  -> { where(published: true) }
  scope :recent,     -> { order(created_at: :desc) }
  scope :by_author,  ->(user) { where(author: user) }
  scope :within,     ->(days) { where("created_at > ?", days.days.ago) }

  # Default scope (use sparingly — causes subtle bugs)
  default_scope { order(:title) }
end

# Chaining
Article.published.recent.by_author(current_user).limit(10)

# Unscoping
Article.unscoped.all
Article.published.unscope(where: :published)
```

`scope` is syntactic sugar for a class method returning an `ActiveRecord::Relation`. The lambda form is required to ensure the proc is evaluated at call time (critical for date scopes).

### 1.4 Callbacks

Callbacks hook into the lifecycle of Active Record objects. They run in a defined order and can halt the chain by `throw :abort`.

#### Lifecycle Sequence

**Create:**
`before_validation` → `after_validation` → `before_save` → `around_save` → `before_create` → `around_create` → `after_create` → `after_save` → `after_commit/after_rollback`

**Update:**
`before_validation` → `after_validation` → `before_save` → `around_save` → `before_update` → `around_update` → `after_update` → `after_save` → `after_commit/after_rollback`

**Destroy:**
`before_destroy` → `around_destroy` → `after_destroy` → `after_commit/after_rollback`

```ruby
class Order < ApplicationRecord
  before_validation :normalize_email
  after_create      :send_confirmation_email
  before_save       :set_status_timestamp
  around_save       :log_save_duration
  after_commit      :sync_to_crm, on: [:create, :update]
  after_rollback    :notify_failure

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end

  def set_status_timestamp
    self.status_changed_at = Time.current if status_changed?
  end

  def around_save
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    Rails.logger.info "Order #{id} saved in #{duration.round(3)}s"
  end

  def send_confirmation_email
    OrderMailer.confirmation(self).deliver_later
  end

  def sync_to_crm
    CrmSyncJob.perform_later(id)
  end
end
```

**Halting the chain:**

```ruby
before_save :check_fraud

def check_fraud
  throw :abort if FraudDetector.flagged?(self)
end
```

**after_commit vs after_save:** Use `after_commit` for side effects (emails, jobs, external API calls) to ensure the database transaction has fully committed before triggering them.

### 1.5 Validations

```ruby
class User < ApplicationRecord
  validates :email,    presence: true,
                       uniqueness: { case_sensitive: false, scope: :tenant_id },
                       format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :age,      numericality: { greater_than_or_equal_to: 18,
                                       only_integer: true },
                       allow_nil: true

  validates :username, length: { minimum: 3, maximum: 50 },
                       format: { with: /\A[a-z0-9_]+\z/, message: "only lowercase letters, numbers, underscores" }

  validates :terms,    acceptance: true, on: :create
  validates :password, confirmation: true

  validate  :password_complexity
  validate  :email_not_blocklisted, on: :create

  # Conditional validation
  validates :company_name, presence: true, if: :business_account?

  private

  def password_complexity
    return if password.blank?
    unless password.match?(/\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
      errors.add(:password, "must include uppercase, lowercase, and a digit")
    end
  end

  def email_not_blocklisted
    errors.add(:email, "domain is not allowed") if BlocklistedDomain.covers?(email)
  end
end
```

**Custom validators (reusable):**

```ruby
class PhoneValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    unless value =~ /\A\+?[\d\s\-().]{7,20}\z/
      record.errors.add(attribute, options[:message] || "is not a valid phone number")
    end
  end
end

class Contact < ApplicationRecord
  validates :phone, phone: true
end
```

### 1.6 Migrations

Migrations are versioned, reversible database schema changes.

```ruby
class CreateArticles < ActiveRecord::Migration[7.2]
  def change
    create_table :articles do |t|
      t.string     :title,       null: false
      t.text       :body
      t.integer    :status,      default: 0, null: false   # enum backing
      t.references :author,      null: false, foreign_key: { to_table: :users }
      t.references :category,    null: true,  foreign_key: true
      t.boolean    :published,   default: false, null: false
      t.datetime   :published_at
      t.jsonb      :metadata,    default: {}   # Postgres-specific
      t.timestamps
    end

    add_index :articles, :published_at
    add_index :articles, [:author_id, :status]
    add_index :articles, :title, unique: true
  end
end
```

**Irreversible migrations with up/down:**

```ruby
class BackfillArticleStatus < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!   # for concurrent index creation

  def up
    Article.in_batches(of: 1000) do |batch|
      batch.update_all(status: :draft)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

**Adding columns safely (large tables):**

```ruby
class AddVerifiedToUsers < ActiveRecord::Migration[7.2]
  def change
    # Avoid table lock on Postgres: add nullable first, backfill, then add constraint
    add_column :users, :verified, :boolean
    add_index  :users, :verified, algorithm: :concurrently
  end
end
```

**Schema format:** `config/application.rb` — prefer `:sql` for databases using views, triggers, or extensions:

```ruby
config.active_record.schema_format = :sql  # dumps structure.sql instead of schema.rb
```

### 1.7 Query Interface

ActiveRecord returns `ActiveRecord::Relation` objects (lazy, chainable) from most query methods.

```ruby
# Basic querying
User.all
User.first / User.last / User.find(1)
User.find_by(email: "alice@example.com")  # returns nil if not found
User.find_by!(email: "alice@example.com") # raises if not found

# where — multiple forms
User.where(active: true)
User.where("created_at > ?", 1.week.ago)
User.where("name LIKE ?", "%alice%")
User.where(role: [:admin, :moderator])   # IN clause
User.where.not(banned: true)
User.where(age: 18..65)                  # BETWEEN

# Ordering, limiting, offsetting
User.order(created_at: :desc).limit(20).offset(40)
User.order(Arel.sql("RANDOM()")).limit(5)  # raw SQL in order

# Selecting specific columns
User.select(:id, :email, :created_at)

# Distinct
User.select(:country).distinct

# Grouping and aggregation
Order.group(:status).count
Order.group(:user_id).sum(:total_cents)
Order.where(status: :completed).average(:total_cents)

# Plucking (returns array, no model instantiation)
User.where(active: true).pluck(:id)
User.pluck(:id, :email)  # returns array of arrays

# Existence checks
User.where(active: true).exists?
User.exists?(email: "alice@example.com")

# Counting
Article.published.count
Article.count(:author_id)   # COUNT(author_id) — excludes NULLs
Article.published.size      # uses COUNT or length depending on loaded state

# Batch processing (memory-efficient)
User.find_each(batch_size: 500) { |user| user.reindex }
User.find_in_batches(of: 1000) { |group| BulkMailer.send(group) }
User.in_batches(of: 500).each_record { |u| u.update(verified: true) }
```

#### joins vs includes vs eager_load vs preload

```ruby
# INNER JOIN — filters work, but N+1 on association access
Post.joins(:comments).where(comments: { approved: true })

# LEFT OUTER JOIN — use for filtering + loading associations together
Post.eager_load(:comments).where(comments: { approved: true })

# Two-query preloading — no JOIN, no cross-product bloat
Post.preload(:comments, :author)

# includes — Rails decides (preload for basic, eager_load when where references association)
Post.includes(:author).where(users: { active: true })  # triggers eager_load
Post.includes(:comments)                                # triggers preload
```

**Strict loading (N+1 detection):**

```ruby
# Raise on any lazy association load
Post.strict_loading.first.comments  # => StrictLoadingViolationError

# Per-record
post = Post.strict_loading.find(1)

# Application-wide (development/test)
config.active_record.strict_loading_by_default = true
```

#### Arel

Arel is the SQL AST underlying ActiveRecord queries. Use it when the query DSL falls short.

```ruby
users  = User.arel_table
orders = Order.arel_table

# Complex conditions
User.where(
  users[:age].gt(18).and(
    users[:country].eq("US").or(users[:country].eq("CA"))
  )
)

# Subqueries
recent_order_ids = Order.where("created_at > ?", 30.days.ago).select(:user_id).arel
User.where(User.arel_table[:id].in(recent_order_ids))

# Custom joins
User.joins(
  User.arel_table.join(orders, Arel::Nodes::OuterJoin)
    .on(users[:id].eq(orders[:user_id]))
    .join_sources
)

# Named functions
User.select(Arel::Nodes::NamedFunction.new("COALESCE", [users[:display_name], users[:email]]))
```

### 1.8 Enums

```ruby
class Article < ApplicationRecord
  enum :status, { draft: 0, published: 1, archived: 2 }, prefix: true

  # Generates:
  #   status_draft?, status_published?, status_archived?
  #   status_draft!, status_published!, status_archived!
  #   Article.status_draft, Article.status_published, ...
end

Article.status_published.recent
article.status_published!
article.status_published?
```

### 1.9 Virtual Attributes & store_accessor

```ruby
class Profile < ApplicationRecord
  store :settings, accessors: [:theme, :notifications_enabled], coder: JSON

  attribute :full_name, :string  # virtual, not persisted
  attribute :priority,  :integer, default: 0
end
```

---

## 2. Action Pack

Action Pack encompasses Action Controller (request handling) and Action Dispatch (routing).

### 2.1 Controllers

```ruby
class ArticlesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_article,  only: [:show, :edit, :update, :destroy]
  before_action :authorize!,   only: [:edit, :update, :destroy]
  after_action  :track_view,   only: :show
  around_action :set_locale

  # GET /articles
  def index
    @articles = Article.published.includes(:author).page(params[:page]).per(20)
  end

  # GET /articles/:id
  def show
    @comments = @article.comments.approved.includes(:author)
  end

  # POST /articles
  def create
    @article = current_user.articles.build(article_params)
    if @article.save
      redirect_to @article, notice: "Article created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH /articles/:id
  def update
    if @article.update(article_params)
      redirect_to @article, notice: "Updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /articles/:id
  def destroy
    @article.destroy!
    redirect_to articles_path, status: :see_other, notice: "Deleted."
  end

  private

  def set_article
    @article = Article.find(params[:id])
  end

  def authorize!
    redirect_to root_path, alert: "Not authorized." unless @article.author == current_user
  end

  def article_params
    params.require(:article).permit(:title, :body, :status, tag_ids: [], metadata: {})
  end

  def track_view
    @article.increment!(:views_count) unless current_user == @article.author
  end

  def set_locale(&action)
    I18n.with_locale(params[:locale] || I18n.default_locale, &action)
  end
end
```

#### Strong Parameters

Strong parameters prevent mass assignment vulnerabilities. `require` asserts presence; `permit` allowlists keys.

```ruby
# Nested attributes
def post_params
  params.require(:post).permit(
    :title, :body,
    :published,
    tags: [],                        # array of scalars
    author_attributes: [:name, :bio], # nested model
    images_attributes: [:id, :url, :_destroy]  # nested with deletion
  )
end

# Conditional permitting
def user_params
  permitted = [:email, :name]
  permitted << :role if current_user.admin?
  params.require(:user).permit(*permitted)
end

# Fetch raw params (no strong params)
params.to_unsafe_h   # avoid in production
```

#### respond_to / respond_with

```ruby
def show
  @article = Article.find(params[:id])

  respond_to do |format|
    format.html                                   # renders show.html.erb
    format.json { render json: @article }
    format.pdf  { render pdf: ArticlePdf.new(@article) }
    format.turbo_stream                           # renders show.turbo_stream.erb
  end
end
```

#### Filters/Callbacks Reference

| Callback | Runs |
|----------|------|
| `before_action` | Before action method |
| `after_action` | After action method |
| `around_action` | Wraps action method |
| `skip_before_action` | Excludes inherited callback |
| `prepend_before_action` | Runs before other before_actions |

#### Concerns (Controller Mixins)

```ruby
# app/controllers/concerns/authenticatable.rb
module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
    helper_method :current_user, :user_signed_in?
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def user_signed_in?
    current_user.present?
  end

  def authenticate_user!
    redirect_to login_path unless user_signed_in?
  end
end
```

### 2.2 Routing

```ruby
# config/routes.rb
Rails.application.routes.draw do

  # Root
  root "home#index"

  # RESTful resource (7 standard routes)
  resources :articles

  # Singular resource (no :id — one per user)
  resource :profile

  # Nested resources (keep to 1-2 levels)
  resources :articles do
    resources :comments, only: [:create, :destroy]
  end

  # Shallow nesting (reduces URL depth)
  resources :articles, shallow: true do
    resources :comments   # index/new/create on /articles/:article_id/comments
                          # show/edit/update/destroy on /comments/:id
  end

  # Member and collection routes
  resources :articles do
    member do
      post   :publish
      delete :unpublish
      get    :preview
    end
    collection do
      get  :search
      post :bulk_destroy
    end
  end

  # Concerns — shared route fragments
  concern :commentable do
    resources :comments
  end
  concern :taggable do
    resources :tags, only: [:index, :create, :destroy]
  end

  resources :articles,  concerns: [:commentable, :taggable]
  resources :photos,    concerns: [:commentable]

  # Constraints
  constraints(host: /api\./) do
    namespace :api do
      namespace :v1 do
        resources :users
      end
    end
  end

  constraints(lambda { |req| req.env["warden"].authenticated? }) do
    resources :dashboard
  end

  # Custom constraints class
  class AdminSubdomain
    def matches?(request)
      request.subdomain == "admin"
    end
  end
  constraints AdminSubdomain.new do
    resources :admin_panel
  end

  # Non-resourceful routes
  get  "/about", to: "pages#about", as: :about
  post "/webhooks/stripe", to: "webhooks#stripe"

  # Redirect
  get "/old-path", to: redirect("/new-path", status: 301)
  get "/users/:id", to: redirect { |params, req| "/profiles/#{params[:id]}" }

  # Scope, namespace, module
  scope "/admin" do           # URL prefix only
    resources :users
  end
  namespace :admin do         # URL prefix + module prefix + helper prefix
    resources :users
  end
  scope module: :api do       # module only, no URL prefix
    resources :users
  end

  # Direct route (generates URL helper without a controller)
  direct :homepage do
    "https://example.com"
  end

  # Mount engines / Rack apps
  mount Sidekiq::Web, at: "/sidekiq", constraints: AdminConstraint
  mount ActionCable.server, at: "/cable"
end
```

**Route helpers cheat sheet:**

```ruby
articles_path          # /articles
article_path(@article) # /articles/42
new_article_path       # /articles/new
edit_article_path(42)  # /articles/42/edit

articles_url           # https://example.com/articles (absolute)
```

---

## 3. Action View

### 3.1 Templates

ERB is the default template engine. Haml is a popular alternative.

**ERB:**

```erb
<%# app/views/articles/show.html.erb %>
<% content_for :title, @article.title %>

<article class="prose">
  <h1><%= @article.title %></h1>
  <p class="byline">
    By <%= link_to @article.author.name, @article.author %> &middot;
    <%= time_tag @article.published_at, @article.published_at.strftime("%B %-d, %Y") %>
  </p>
  <%= @article.body_html.html_safe %>
</article>

<%= render "comments/list", comments: @comments %>
```

**Haml (gem required):**

```haml
-# app/views/articles/show.html.haml
- content_for :title, @article.title

%article.prose
  %h1= @article.title
  %p.byline
    By
    = link_to @article.author.name, @article.author
    = time_tag @article.published_at

= render "comments/list", comments: @comments
```

### 3.2 Layouts

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html lang="<%= I18n.locale %>">
  <head>
    <title><%= content_for?(:title) ? yield(:title) : "MyApp" %></title>
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>
  <body class="<%= controller_name %> <%= action_name %>">
    <%= render "shared/flash" %>
    <%= yield %>
    <%= yield :modal %>
  </body>
</html>
```

**Controller layout selection:**

```ruby
class AdminController < ApplicationController
  layout "admin"
end

class ReportsController < ApplicationController
  layout :determine_layout

  private

  def determine_layout
    current_user.admin? ? "admin" : "application"
  end
end
```

### 3.3 Partials

Partials begin with underscore by convention.

```erb
<%# Render with local variable %>
<%= render partial: "articles/card", locals: { article: @article, compact: true } %>

<%# Shorthand (infers partial name from object class) %>
<%= render @article %>

<%# Collection rendering (single DB query, efficient) %>
<%= render partial: "articles/card", collection: @articles, as: :article %>
<%# or shorthand: %>
<%= render @articles %>

<%# With spacer %>
<%= render partial: "item", collection: @items, spacer_template: "item_divider" %>

<%# With layout %>
<%= render partial: "article", layout: "box", locals: { article: @article } %>
```

### 3.4 Helpers

```ruby
# app/helpers/articles_helper.rb
module ArticlesHelper
  def status_badge(article)
    color = { draft: "gray", published: "green", archived: "red" }[article.status.to_sym]
    content_tag :span, article.status.humanize, class: "badge badge-#{color}"
  end

  def article_reading_time(article)
    words  = article.body.to_s.split.size
    minutes = [(words / 200).ceil, 1].max
    "#{minutes} min read"
  end
end

# Auto-included into views and available in controllers via helper_method
```

### 3.5 Form Helpers — form_with

`form_with` (Rails 5.1+) unified `form_for` and `form_tag`.

```erb
<%# Model-backed form %>
<%= form_with model: @article, class: "article-form" do |f| %>
  <%= f.label :title %>
  <%= f.text_field :title, autofocus: true, required: true %>
  <%= render "shared/field_errors", field: :title, object: @article %>

  <%= f.label :status %>
  <%= f.select :status, Article.statuses.keys.map { |s| [s.humanize, s] },
               { prompt: "Select status" }, { class: "select" } %>

  <%= f.label :body %>
  <%= f.text_area :body, rows: 10 %>

  <%= f.label :tag_ids, "Tags" %>
  <%= f.collection_check_boxes :tag_ids, Tag.all, :id, :name do |b| %>
    <%= b.label { b.check_box + b.text } %>
  <% end %>

  <%= f.label :cover_image %>
  <%= f.file_field :cover_image, accept: "image/*", direct_upload: true %>

  <%= f.fields_for :address do |af| %>
    <%= af.text_field :street %>
    <%= af.text_field :city %>
  <% end %>

  <%= f.submit "Save Article", class: "btn btn-primary" %>
<% end %>

<%# Non-model form %>
<%= form_with url: search_path, method: :get do |f| %>
  <%= f.search_field :q, placeholder: "Search articles..." %>
  <%= f.submit "Search" %>
<% end %>
```

### 3.6 View Components

ViewComponent (gem by GitHub) provides testable, encapsulated view objects.

```ruby
# app/components/alert_component.rb
class AlertComponent < ViewComponent::Base
  VARIANTS = %w[info success warning error].freeze

  def initialize(message:, variant: "info", dismissible: true)
    @message    = message
    @variant    = variant.in?(VARIANTS) ? variant : "info"
    @dismissible = dismissible
  end

  private

  attr_reader :message, :variant, :dismissible
end
```

```erb
<%# app/components/alert_component.html.erb %>
<div class="alert alert-<%= variant %>" role="alert">
  <%= message %>
  <% if dismissible %>
    <button type="button" data-action="click->alert#dismiss">×</button>
  <% end %>
</div>
```

```erb
<%# Usage in any view %>
<%= render AlertComponent.new(message: "Saved!", variant: "success") %>
```

```ruby
# Test
class AlertComponentTest < ViewComponent::TestCase
  def test_renders_message
    render_inline(AlertComponent.new(message: "Hello"))
    assert_selector ".alert", text: "Hello"
  end
end
```

---

## 4. Active Job

Active Job provides a unified interface to background job adapters, abstracting away adapter-specific APIs.

### 4.1 Job Definition

```ruby
# app/jobs/invoice_generation_job.rb
class InvoiceGenerationJob < ApplicationJob
  queue_as :billing

  # Retry configuration (adapter-specific behaviour when retries_on not used)
  retry_on Stripe::RateLimitError, wait: :polynomially_longer, attempts: 5
  retry_on Net::ReadTimeout,        wait: 30.seconds,           attempts: 3
  discard_on ActiveJob::DeserializationError

  # Callbacks
  before_enqueue :validate_customer
  before_perform :log_start
  after_perform  :log_finish
  around_perform :set_locale

  def perform(order_id, send_email: true)
    order = Order.find(order_id)
    invoice = InvoiceService.generate(order)
    InvoiceMailer.send_invoice(order, invoice).deliver_later if send_email
    invoice
  end

  private

  def validate_customer
    # throw :abort to cancel enqueue
  end

  def set_locale(&block)
    I18n.with_locale(I18n.default_locale, &block)
  end
end
```

### 4.2 Enqueueing

```ruby
# Async (recommended for production)
InvoiceGenerationJob.perform_later(order.id)
InvoiceGenerationJob.perform_later(order.id, send_email: false)

# Scheduled
InvoiceGenerationJob.set(wait: 5.minutes).perform_later(order.id)
InvoiceGenerationJob.set(wait_until: Date.tomorrow.noon).perform_later(order.id)

# Queue selection at enqueue time
InvoiceGenerationJob.set(queue: :critical).perform_later(order.id)

# Priority (adapter-dependent)
InvoiceGenerationJob.set(priority: 10).perform_later(order.id)

# Synchronous (test/development)
InvoiceGenerationJob.perform_now(order.id)
```

### 4.3 Adapters

| Adapter | Gem | Persistence | Notes |
|---------|-----|-------------|-------|
| Async | built-in | In-process | Dev/test only |
| Solid Queue | solid_queue | DB (SQLite/PG/MySQL) | Rails 8 default |
| Sidekiq | sidekiq | Redis | High throughput, web UI |
| GoodJob | good_job | PostgreSQL | LISTEN/NOTIFY, no Redis |
| Resque | resque | Redis | Older, less maintained |
| Delayed::Job | delayed_job | DB | Legacy |

**Solid Queue configuration (Rails 8 default):**

```ruby
# config/environments/production.rb
config.active_job.queue_adapter = :solid_queue
```

```yaml
# config/solid_queue.yml
production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "critical,default,billing"
      threads: 5
      processes: 3
```

**Sidekiq configuration:**

```ruby
# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: ENV["REDIS_URL"], pool_size: 10 }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV["REDIS_URL"] }
end
```

```yaml
# config/sidekiq.yml
:concurrency: 10
:queues:
  - [critical, 3]
  - [default, 2]
  - [mailers, 1]
  - [billing, 2]
```

### 4.4 Serialization

Active Job uses GlobalID for model serialization. Models included via `GlobalID::Identification` are automatically serialized/deserialized.

```ruby
# GlobalID is included in ActiveRecord::Base
InvoiceJob.perform_later(@order)  # serializes as gid://app/Order/42
                                   # deserialized to Order.find(42) at perform time
```

Custom serializers:

```ruby
class MoneySerializer < ActiveJob::Serializers::ObjectSerializer
  def serialize(money)
    super("amount" => money.fractional, "currency" => money.currency.iso_code)
  end

  def deserialize(hash)
    Money.new(hash["amount"], hash["currency"])
  end

  private

  def klass
    Money
  end
end

Rails.application.config.active_job.custom_serializers << MoneySerializer
```

---

## 5. Action Cable

Action Cable integrates WebSockets into Rails using channels — a server-side abstraction mirroring controllers.

### 5.1 Connection

Establishes identity for the WebSocket session.

```ruby
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      logger.add_tags "ActionCable", current_user.id
    end

    def disconnect
      # Cleanup when WebSocket closes
    end

    private

    def find_verified_user
      if (user_id = cookies.encrypted[:user_id])
        User.find_by(id: user_id) || reject_unauthorized_connection
      else
        reject_unauthorized_connection
      end
    end
  end
end
```

### 5.2 Channels

```ruby
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  def subscribed
    room = Room.find(params[:room_id])
    reject unless current_user.member_of?(room)
    stream_for room                    # streams from Room-specific topic
    # or: stream_from "chat_#{params[:room_id]}"
  end

  def unsubscribed
    # any cleanup needed when channel is unsubscribed
  end

  def speak(data)
    room    = Room.find(params[:room_id])
    message = room.messages.create!(
      content: data["message"],
      user:    current_user
    )
    # Broadcast triggers after_create_commit in Message model
  end

  def typing(data)
    ActionCable.server.broadcast(
      "chat_#{params[:room_id]}",
      { type: "typing", user: current_user.name }
    )
  end
end
```

### 5.3 Broadcasting

```ruby
# From a model callback
class Message < ApplicationRecord
  after_create_commit do
    ChatChannel.broadcast_to(
      room,
      { type: "message", html: ApplicationController.render(partial: "messages/message", locals: { message: self }) }
    )
  end
end

# From anywhere
ActionCable.server.broadcast("notifications_#{user.id}", { type: "alert", text: "New order!" })

# From a job
class NotificationBroadcastJob < ApplicationJob
  def perform(notification)
    ActionCable.server.broadcast(
      "user_#{notification.user_id}",
      NotificationSerializer.new(notification).as_json
    )
  end
end
```

### 5.4 JavaScript Client

```javascript
// app/javascript/channels/chat_channel.js
import consumer from "channels/consumer"

const chatChannel = consumer.subscriptions.create(
  { channel: "ChatChannel", room_id: roomId },
  {
    connected()    { console.log("Connected") },
    disconnected() { console.log("Disconnected") },
    received(data) {
      if (data.type === "message") {
        document.getElementById("messages").insertAdjacentHTML("beforeend", data.html)
      }
    },
    speak(message) {
      this.perform("speak", { message })
    },
    typing() {
      this.perform("typing")
    }
  }
)
```

### 5.5 Turbo Streams over Action Cable

Rails 7+ Turbo Streams can broadcast DOM updates over Action Cable natively.

```ruby
class Message < ApplicationRecord
  belongs_to :room

  after_create_commit  -> { broadcast_append_to room }
  after_update_commit  -> { broadcast_replace_to room }
  after_destroy_commit -> { broadcast_remove_to room }

  # Or combined:
  broadcasts_to :room
end
```

```erb
<%# app/views/rooms/show.html.erb %>
<%= turbo_stream_from @room %>

<div id="messages">
  <%= render @room.messages %>
</div>
```

---

## 6. Action Mailer

### 6.1 Mailer Class

```ruby
# app/mailers/order_mailer.rb
class OrderMailer < ApplicationMailer
  default from: "orders@example.com",
          reply_to: "support@example.com"

  layout "mailer"

  before_action :set_order

  def confirmation
    @tracking_url = track_order_url(@order)
    mail(
      to:      @order.user.email,
      subject: "Order ##{@order.number} Confirmed"
    )
  end

  def shipped(tracking_number)
    @tracking_number = tracking_number
    attachments["packing_slip.pdf"] = OrderPdf.new(@order).render
    mail(
      to:      @order.user.email,
      subject: "Your order has shipped!"
    )
  end

  private

  def set_order
    @order = params[:order]
  end
end
```

```ruby
# Parameterized mailer (Rails 5.1+)
OrderMailer.with(order: @order).confirmation.deliver_later
OrderMailer.with(order: @order).shipped("TRACK123").deliver_later
OrderMailer.with(order: @order).confirmation.deliver_now
```

### 6.2 Previews

```ruby
# test/mailers/previews/order_mailer_preview.rb
class OrderMailerPreview < ActionMailer::Preview
  def confirmation
    order = Order.last
    OrderMailer.with(order: order).confirmation
  end

  def shipped
    OrderMailer.with(order: Order.last).shipped("TRACK123")
  end
end

# Visit: http://localhost:3000/rails/mailers/order_mailer/confirmation
```

### 6.3 Interceptors and Observers

```ruby
# Interceptor — modifies message before delivery
class DevelopmentMailInterceptor
  def self.delivering_email(message)
    message.subject = "[DEV] #{message.subject}"
    message.to      = ["dev@example.com"]
  end
end

# Observer — notified after delivery
class MailDeliveryObserver
  def self.delivered_email(message)
    Rails.logger.info "Email delivered to #{message.to.join(", ")}: #{message.subject}"
    MailLog.create!(
      to: message.to.join(", "),
      subject: message.subject,
      delivered_at: Time.current
    )
  end
end

# config/initializers/mailer.rb
ActionMailer::Base.register_interceptor(DevelopmentMailInterceptor) if Rails.env.development?
ActionMailer::Base.register_observer(MailDeliveryObserver)
```

### 6.4 Delivery Configuration

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address:              "smtp.sendgrid.net",
  port:                 587,
  authentication:       :plain,
  user_name:            Rails.application.credentials.sendgrid.username,
  password:             Rails.application.credentials.sendgrid.api_key,
  enable_starttls_auto: true
}

# Catch-all for development
config.action_mailer.delivery_method = :letter_opener   # gem
# or
config.action_mailer.delivery_method = :test             # stores in ActionMailer::Base.deliveries
```

---

## 7. Turbo/Hotwire

Hotwire (HTML Over the Wire) is Rails' default front-end paradigm from Rails 7+. It sends HTML, not JSON, reducing the need for a separate SPA.

### 7.1 Turbo Drive

Turbo Drive intercepts link clicks and form submissions, replacing only the `<body>`, preserving `<head>` (and thus JS/CSS). This gives SPA-like navigation without writing JavaScript.

```erb
<%# Opt-out specific link %>
<%= link_to "Download PDF", report_path(@report), data: { turbo: false } %>

<%# Opt-out entire form %>
<%= form_with model: @upload, data: { turbo: false } do |f| %>
```

**Handling Turbo in controllers:** Return `status: :see_other` on `DELETE` redirects (303) to avoid browser caching issues:

```ruby
def destroy
  @article.destroy!
  redirect_to articles_path, status: :see_other
end
```

### 7.2 Turbo Frames

Turbo Frames scope navigation to a portion of the page. Clicking a link or submitting a form inside a frame only updates that frame.

```erb
<%# app/views/articles/index.html.erb %>
<%= turbo_frame_tag "new-article" do %>
  <%= link_to "New Article", new_article_path %>
<% end %>

<%# app/views/articles/new.html.erb %>
<%= turbo_frame_tag "new-article" do %>
  <%= form_with model: @article do |f| %>
    ...
  <% end %>
<% end %>
```

Lazy loading:

```erb
<%= turbo_frame_tag "comments", src: article_comments_path(@article), loading: :lazy do %>
  <p>Loading comments...</p>
<% end %>
```

Breaking out of a frame:

```erb
<%= link_to "Full Page", article_path(@article), data: { turbo_frame: "_top" } %>
```

### 7.3 Turbo Streams

Turbo Streams update any number of elements on the page simultaneously, via seven actions: `append`, `prepend`, `replace`, `update`, `remove`, `before`, `after`.

**From a controller action:**

```ruby
def create
  @article = current_user.articles.build(article_params)
  if @article.save
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.prepend("articles", partial: "articles/article", locals: { article: @article }),
          turbo_stream.replace("article-count", partial: "shared/article_count"),
          turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Created!" })
        ]
      end
      format.html { redirect_to @article }
    end
  end
end
```

**From a model (broadcast):**

```ruby
class Article < ApplicationRecord
  after_create_commit  -> { broadcast_prepend_to "articles" }
  after_update_commit  -> { broadcast_replace_to "articles" }
  after_destroy_commit -> { broadcast_remove_to "articles" }
end
```

### 7.4 Morphing (Rails 8 / Turbo 8)

Turbo 8 introduced page morphing — instead of replacing the entire body, it diffs and patches just what changed. This preserves scroll position, form state, and focus.

```ruby
# Controller can trigger a full page refresh with morphing
def update
  @article.update!(article_params)
  redirect_to @article, notice: "Updated"  # Turbo 8 morphs instead of replaces
end
```

```javascript
// Opt out of morphing for a specific element
// data-turbo-permanent preserves the element across navigations
<div id="sidebar" data-turbo-permanent>...</div>
```

### 7.5 Stimulus

Stimulus is a modest JavaScript framework that connects HTML attributes to controller classes.

```javascript
// app/javascript/controllers/character_counter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "counter"]
  static values  = { max: { type: Number, default: 280 } }

  connect() {
    this.update()
  }

  update() {
    const remaining = this.maxValue - this.inputTarget.value.length
    this.counterTarget.textContent = `${remaining} characters remaining`
    this.counterTarget.classList.toggle("text-red-500", remaining < 20)
  }
}
```

```erb
<div data-controller="character-counter" data-character-counter-max-value="280">
  <%= f.text_area :bio, data: { character_counter_target: "input",
                                 action: "input->character-counter#update" } %>
  <span data-character-counter-target="counter"></span>
</div>
```

### 7.6 Turbo Native

Turbo Native wraps the Rails web app in native iOS/Android shell apps, with hybrid navigation. Rails controllers can detect Turbo Native requests:

```ruby
class ApplicationController < ActionController::Base
  def turbo_native_app?
    request.user_agent.include?("Turbo Native")
  end
  helper_method :turbo_native_app?
end
```

---

## 8. Active Storage

Active Storage handles file uploads to cloud services (S3, GCS, Azure) or local disk, with variants for image processing.

### 8.1 Setup

```bash
rails active_storage:install
rails db:migrate
```

```yaml
# config/storage.yml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

amazon:
  service: S3
  access_key_id:     <%= Rails.application.credentials.aws.access_key_id %>
  secret_access_key: <%= Rails.application.credentials.aws.secret_access_key %>
  region: us-east-1
  bucket: my-app-production

mirror_service:
  service: Mirror
  primary: amazon
  mirrors:
    - local
```

```ruby
# config/environments/production.rb
config.active_storage.service = :amazon
```

### 8.2 Attachments

```ruby
class User < ApplicationRecord
  has_one_attached  :avatar
  has_many_attached :documents
end

class Article < ApplicationRecord
  has_one_attached :cover_image do |attachable|
    attachable.variant :thumb,  resize_to_limit: [100, 100]
    attachable.variant :medium, resize_to_limit: [400, 400], format: :webp
    attachable.variant :large,  resize_to_limit: [1200, nil]
  end
end
```

### 8.3 Variants

```ruby
# In views
<%= image_tag user.avatar.variant(resize_to_limit: [150, 150]) %>
<%= image_tag article.cover_image.variant(:medium) %>

# Processed variant (eager processing)
article.cover_image.variant(:thumb).processed.url
```

```ruby
# config/initializers/active_storage.rb
Rails.application.config.active_storage.variant_processor = :vips  # faster than ImageMagick
```

### 8.4 Direct Uploads

```erb
<%= form_with model: @article do |f| %>
  <%= f.file_field :cover_image, direct_upload: true %>
<% end %>
```

Direct uploads bypass the Rails server — the browser uploads directly to the storage service and returns a signed blob ID. Include the JS:

```javascript
// app/javascript/application.js
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
```

### 8.5 Analyzing and Purging

```ruby
# Metadata (populated after upload via ActiveStorage::AnalyzeJob)
user.avatar.blob.metadata           # { "width" => 800, "height" => 600 }
user.avatar.blob.content_type       # "image/jpeg"
user.avatar.blob.byte_size          # 204800

# Checking
user.avatar.attached?
user.avatar.blank?

# Purging
user.avatar.purge                   # synchronous
user.avatar.purge_later             # via ActiveStorage::PurgeJob
```

---

## 9. Middleware Stack

### 9.1 Rack Basics

Every Rails app is a Rack application. Middleware are Rack-compatible classes that wrap the inner app in an onion model.

```ruby
# Minimal Rack middleware
class TimingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    start  = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status, headers, response = @app.call(env)
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

    headers["X-Request-Duration"] = duration.round(4).to_s
    [status, headers, response]
  end
end
```

### 9.2 Default Rails Middleware Stack

```bash
rails middleware
```

Key middleware in order:

| Middleware | Purpose |
|-----------|---------|
| `ActionDispatch::HostAuthorization` | Blocks DNS rebinding |
| `Rack::Sendfile` | X-Sendfile header for web server |
| `ActionDispatch::Static` | Serves public/ assets |
| `ActionDispatch::Executor` | Per-request thread isolation (reloader) |
| `ActiveSupport::Cache::Strategy::LocalCache` | Per-request memory cache |
| `Rack::Runtime` | X-Runtime header |
| `Rack::MethodOverride` | `_method` param spoofing for PUT/PATCH/DELETE |
| `ActionDispatch::RequestId` | X-Request-Id header |
| `Rails::Rack::Logger` | Request logging |
| `ActionDispatch::ShowExceptions` | Error page rendering |
| `ActionDispatch::DebugExceptions` | Detailed error pages (dev) |
| `ActionDispatch::ActionableExceptions` | Clickable error actions (dev) |
| `ActionDispatch::Reloader` | Code reloading (dev) |
| `ActionDispatch::Callbacks` | Before/after callbacks |
| `ActiveRecord::Migration::CheckPending` | Pending migrations check |
| `ActionDispatch::Cookies` | Cookie jar |
| `ActionDispatch::Session::CookieStore` | Session handling |
| `ActionDispatch::Flash` | Flash messages |
| `ActionDispatch::ContentSecurityPolicy::Middleware` | CSP headers |
| `Rack::Head` | Converts HEAD to GET |
| `Rack::ConditionalGet` | Conditional GET (ETags) |
| `Rack::ETag` | ETag headers |

### 9.3 Custom Middleware

```ruby
# config/application.rb
module MyApp
  class Application < Rails::Application
    # Add at the end of the stack
    config.middleware.use TimingMiddleware

    # Add at the beginning
    config.middleware.insert_before 0, TimingMiddleware

    # Add before a specific middleware
    config.middleware.insert_before ActionDispatch::Static, TimingMiddleware

    # Add after a specific middleware
    config.middleware.insert_after ActionDispatch::Flash, TimingMiddleware

    # Replace a middleware
    config.middleware.swap ActionDispatch::Session::CookieStore,
                          ActionDispatch::Session::MemCacheStore,
                          expire_after: 2.hours

    # Delete a middleware
    config.middleware.delete Rack::Runtime
  end
end
```

**Practical middleware example — Maintenance Mode:**

```ruby
class MaintenanceMiddleware
  MAINTENANCE_FILE = Rails.root.join("tmp/maintenance.txt")

  def initialize(app)
    @app = app
  end

  def call(env)
    if maintenance? && !bypass?(env)
      [503, { "Content-Type" => "text/html" },
       [File.read(Rails.root.join("public/503.html"))]]
    else
      @app.call(env)
    end
  end

  private

  def maintenance?
    MAINTENANCE_FILE.exist?
  end

  def bypass?(env)
    env["REMOTE_ADDR"].in?(Rails.configuration.maintenance_bypass_ips)
  end
end
```

---

## 10. Configuration

### 10.1 Initializers

Initializers run once at boot, in alphabetical order, after the framework is loaded.

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins Rails.application.credentials.allowed_origins
    resource "*", headers: :any, methods: [:get, :post, :put, :patch, :delete, :options]
  end
end

# config/initializers/sidekiq.rb
Sidekiq.configure_server { |c| c.redis = { url: ENV["REDIS_URL"] } }
Sidekiq.configure_client { |c| c.redis = { url: ENV["REDIS_URL"] } }

# config/initializers/inflections.rb
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "person",  "people"
  inflect.uncountable "equipment"
  inflect.acronym "API"
end

# config/initializers/content_security_policy.rb
Rails.application.config.content_security_policy do |policy|
  policy.default_src :self, :https
  policy.font_src    :self, :https, :data
  policy.img_src     :self, :https, :data
  policy.script_src  :self, :https
  policy.connect_src :self, :https, "wss://#{Rails.application.credentials.host}"
end
```

### 10.2 Credentials

Credentials replaced `secrets.yml` in Rails 5.2. They are encrypted at rest in `config/credentials.yml.enc`, decrypted with `config/master.key` (never commit).

```bash
rails credentials:edit                          # uses EDITOR env var
rails credentials:edit --environment production  # environment-specific
```

```yaml
# credentials.yml.enc (decrypted view)
secret_key_base: abc123...

aws:
  access_key_id: AKIA...
  secret_access_key: xyz...
  bucket: my-app-prod

sendgrid:
  api_key: SG.xxx

stripe:
  public_key: pk_live_...
  secret_key: sk_live_...
  webhook_secret: whsec_...
```

```ruby
# Accessing credentials
Rails.application.credentials.secret_key_base
Rails.application.credentials.aws.access_key_id
Rails.application.credentials.dig(:stripe, :secret_key)

# With fallback
Rails.application.credentials.stripe&.secret_key || ENV["STRIPE_SECRET_KEY"]
```

### 10.3 Environment Configurations

```ruby
# config/application.rb — shared across all environments
module MyApp
  class Application < Rails::Application
    config.load_defaults 7.2
    config.time_zone = "UTC"
    config.i18n.default_locale = :en
    config.i18n.available_locales = [:en, :es, :fr]
    config.active_record.encryption.primary_key = credentials.db_encryption_primary_key
    config.active_record.encryption.deterministic_key = credentials.db_encryption_deterministic_key
    config.active_record.encryption.key_derivation_salt = credentials.db_encryption_salt
    config.generators do |g|
      g.orm             :active_record
      g.test_framework  :rspec, fixture: false
      g.view_specs      false
      g.helper_specs    false
    end
  end
end

# config/environments/production.rb
Rails.application.configure do
  config.cache_classes       = true
  config.eager_load           = true
  config.log_level            = :info
  config.log_tags             = [:request_id]
  config.cache_store          = :redis_cache_store, { url: ENV["REDIS_URL"] }
  config.action_mailer.perform_caching = false
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
  config.force_ssl            = true
  config.active_job.queue_adapter = :sidekiq
end
```

### 10.4 Custom Configuration

```ruby
# config/application.rb
config.x.payment.provider     = "stripe"
config.x.payment.currency     = "USD"
config.x.features.dark_mode   = true

# Access anywhere
Rails.configuration.x.payment.provider
Rails.configuration.x.features.dark_mode

# Typed config object (Rails 7.1+)
config.payment = ActiveSupport::OrderedOptions.new
config.payment.provider  = "stripe"
config.payment.currency  = "USD"
```

**Configuration from YAML:**

```yaml
# config/app_config.yml
shared: &shared
  rate_limit_per_minute: 60
  max_file_size_mb: 50

development:
  <<: *shared

production:
  <<: *shared
  rate_limit_per_minute: 200
```

```ruby
# config/initializers/app_config.rb
app_config = config_for(:app_config)
Rails.application.config.rate_limit = app_config[:rate_limit_per_minute]
```

---

## 11. Testing

### 11.1 Minitest (Default)

Rails ships with Minitest and provides wrappers for each layer.

```ruby
# test/models/article_test.rb
require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  setup do
    @user    = users(:alice)
    @article = Article.new(title: "Hello", body: "World", author: @user)
  end

  test "is valid with valid attributes" do
    assert @article.valid?
  end

  test "requires title" do
    @article.title = ""
    assert_not @article.valid?
    assert_includes @article.errors[:title], "can't be blank"
  end

  test "published scope returns only published articles" do
    published = articles(:published_one)
    draft     = articles(:draft_one)

    assert_includes     Article.published, published
    assert_not_includes Article.published, draft
  end

  test "calculates reading time" do
    @article.body = "word " * 400  # 400 words
    assert_equal 2, @article.reading_time_minutes
  end
end
```

**Controller tests:**

```ruby
# test/controllers/articles_controller_test.rb
class ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user    = users(:alice)
    @article = articles(:published_one)
    sign_in @user   # test helper
  end

  test "GET #index returns 200" do
    get articles_path
    assert_response :success
    assert_select "article.card", count: Article.published.count
  end

  test "POST #create creates article" do
    assert_difference "Article.count" do
      post articles_path, params: {
        article: { title: "New Article", body: "Content", status: "draft" }
      }
    end
    assert_redirected_to article_path(Article.last)
  end

  test "DELETE #destroy redirects to index" do
    assert_difference "Article.count", -1 do
      delete article_path(@article)
    end
    assert_redirected_to articles_path
  end

  test "POST #create with invalid params renders new" do
    post articles_path, params: { article: { title: "", body: "" } }
    assert_response :unprocessable_entity
    assert_select ".field_error"
  end
end
```

**Mailer tests:**

```ruby
class OrderMailerTest < ActionMailer::TestCase
  test "confirmation email" do
    order = orders(:completed)
    email = OrderMailer.with(order: order).confirmation

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ["orders@example.com"], email.from
    assert_equal [order.user.email],     email.to
    assert_match "Order ##{order.number}", email.subject
    assert_match order.number,            email.body.encoded
  end
end
```

**Job tests:**

```ruby
class InvoiceGenerationJobTest < ActiveJob::TestCase
  test "enqueues and performs" do
    order = orders(:completed)

    assert_enqueued_with(job: InvoiceGenerationJob, args: [order.id]) do
      InvoiceGenerationJob.perform_later(order.id)
    end

    perform_enqueued_jobs do
      InvoiceGenerationJob.perform_later(order.id)
    end
  end
end
```

### 11.2 Fixtures

Fixtures are YAML files that populate test data. They participate in transactions and are fast.

```yaml
# test/fixtures/articles.yml
published_one:
  title: "My Published Article"
  body:  "Content here"
  status: published
  author: alice   # references users.yml fixture

draft_one:
  title: "My Draft"
  status: draft
  author: alice
```

Fixtures support ERB and helper methods:

```yaml
alice:
  email: alice@example.com
  password_digest: <%= BCrypt::Password.create("password") %>
  created_at: <%= 3.days.ago.iso8601 %>
```

### 11.3 RSpec

RSpec is the dominant alternative test framework.

```ruby
# spec/models/article_spec.rb
RSpec.describe Article, type: :model do
  subject(:article) { build(:article) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(255) }
    it { is_expected.to belong_to(:author).class_name("User") }
    it { is_expected.to have_many(:comments).dependent(:destroy) }
  end

  describe "#publish!" do
    let(:draft_article) { create(:article, :draft) }

    it "transitions to published" do
      expect { draft_article.publish! }.to change(draft_article, :status).to("published")
    end

    it "sets published_at" do
      freeze_time do
        draft_article.publish!
        expect(draft_article.published_at).to eq(Time.current)
      end
    end
  end

  describe ".recent" do
    it "returns articles ordered by created_at desc" do
      old_article = create(:article, created_at: 2.days.ago)
      new_article = create(:article, created_at: 1.hour.ago)
      expect(Article.recent).to eq([new_article, old_article])
    end
  end
end
```

**Request specs (preferred over controller specs):**

```ruby
RSpec.describe "Articles", type: :request do
  let(:user) { create(:user) }
  let(:article) { create(:article, author: user) }

  before { sign_in user }

  describe "GET /articles" do
    it "returns http success" do
      get articles_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /articles" do
    let(:valid_params) { { article: attributes_for(:article) } }
    let(:invalid_params) { { article: { title: "" } } }

    it "creates an article" do
      expect { post articles_path, params: valid_params }.to change(Article, :count).by(1)
      expect(response).to redirect_to(Article.last)
    end

    it "renders errors on failure" do
      post articles_path, params: invalid_params
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
```

### 11.4 FactoryBot

```ruby
# spec/factories/articles.rb
FactoryBot.define do
  factory :article do
    title  { Faker::Lorem.sentence }
    body   { Faker::Lorem.paragraphs(number: 3).join("\n") }
    status { :draft }

    association :author, factory: :user

    trait :published do
      status       { :published }
      published_at { Time.current }
    end

    trait :with_cover_image do
      after(:create) do |article|
        article.cover_image.attach(
          io: Rails.root.join("spec/fixtures/files/cover.jpg").open,
          filename: "cover.jpg",
          content_type: "image/jpeg"
        )
      end
    end

    trait :with_comments do
      after(:create) do |article|
        create_list(:comment, 3, article: article)
      end
    end
  end
end

# Usage
build(:article)                           # unsaved instance
create(:article, :published)              # persisted
create(:article, :with_comments)
build_stubbed(:article)                   # stubbed (no DB hit)
attributes_for(:article)                  # hash of attributes
create_list(:article, 5, :published)
```

### 11.5 System Tests (Capybara)

```ruby
# test/system/articles_test.rb
class ArticlesTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  setup do
    @user    = users(:alice)
    @article = articles(:published_one)
    sign_in_as @user
  end

  test "creating an article" do
    visit new_article_path

    fill_in "Title", with: "My New Article"
    fill_in "Body",  with: "This is the body content."
    select  "Published", from: "Status"
    click_button "Save Article"

    assert_text "Article created"
    assert_text "My New Article"
  end

  test "editing inline with Turbo Frames" do
    visit article_path(@article)
    click_link "Edit"

    # Turbo Frame loads the edit form inline
    within_frame "article-edit" do
      fill_in "Title", with: "Updated Title"
      click_button "Save"
    end

    assert_text "Updated Title"
    assert_no_selector "form"   # form replaced by updated content
  end
end
```

**RSpec system spec:**

```ruby
RSpec.describe "Article creation", type: :system do
  let(:user) { create(:user) }

  before { driven_by(:selenium_chrome_headless) }
  before { sign_in user }

  it "creates an article with turbo stream response" do
    visit articles_path
    click_link "New Article"

    fill_in "Title", with: "Turbo Article"
    fill_in "Body",  with: "Content"
    click_button "Save"

    expect(page).to have_text("Turbo Article")
    expect(page).to have_current_path(article_path(Article.last))
  end
end
```

### 11.6 Parallel Testing

```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)

  parallelize_setup do |worker|
    ActiveStorage::Blob.service.root = "#{ActiveStorage::Blob.service.root}-#{worker}"
  end

  parallelize_teardown do |worker|
    FileUtils.rm_rf("#{ActiveStorage::Blob.service.root}-#{worker}")
  end
end
```

### 11.7 Test Helpers

```ruby
# test/test_helper.rb
module SignInHelper
  def sign_in_as(user)
    post sessions_path, params: { email: user.email, password: "password" }
  end
end

# For RSpec
module AuthHelpers
  def sign_in(user)
    session[:user_id] = user.id
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers
end
```

---

## 12. Engines

Rails Engines are miniature Rails applications that can be mounted inside a host app. They follow the same MVC conventions.

### 12.1 Types

| Type | Description |
|------|-------------|
| **Mountable** | Fully namespaced — routes, models, controllers isolated |
| **Full** | Not namespaced — shares host app namespace |

### 12.2 Generating an Engine

```bash
rails plugin new billing --mountable --full=false --skip-git
rails plugin new admin_ui --full
```

Structure:

```
billing/
├── app/
│   ├── controllers/billing/
│   │   └── application_controller.rb
│   ├── models/billing/
│   ├── views/billing/
│   └── jobs/billing/
├── config/
│   └── routes.rb
├── db/
│   └── migrate/
├── lib/
│   ├── billing.rb
│   ├── billing/engine.rb
│   └── billing/version.rb
└── billing.gemspec
```

### 12.3 Engine Definition

```ruby
# lib/billing/engine.rb
module Billing
  class Engine < ::Rails::Engine
    isolate_namespace Billing

    initializer "billing.load_config" do |app|
      # Access to host app config
    end

    initializer "billing.assets" do |app|
      app.config.assets.paths  << root.join("app/assets")
      app.config.assets.precompile += %w[billing/application.css billing/application.js]
    end

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot
    end
  end
end
```

### 12.4 Engine Routes

```ruby
# config/routes.rb (inside engine)
Billing::Engine.routes.draw do
  resources :invoices
  resources :subscriptions
  root to: "invoices#index"
end
```

### 12.5 Mounting in Host App

```ruby
# Host app config/routes.rb
Rails.application.routes.draw do
  mount Billing::Engine, at: "/billing", as: "billing"
  mount Sidekiq::Web,    at: "/sidekiq"
end
```

Route helpers are accessed via the engine's routes proxy:

```ruby
billing.invoices_path            # /billing/invoices
billing.invoice_path(invoice)    # /billing/invoices/42
main_app.root_path               # back to host app root
```

### 12.6 Sharing Models and Configuration

```ruby
# Engine accessing host app models (configured via railtie)
module Billing
  class Engine < ::Rails::Engine
    isolate_namespace Billing

    # Configurable user class
    mattr_accessor :user_class
    self.user_class = "User"
  end
end

# Resolved at runtime
def user_class
  Billing.user_class.constantize
end
```

```ruby
# config/initializers/billing.rb (in host app)
Billing.user_class = "Account"
```

### 12.7 Engine Migrations

```bash
# Engines keep migrations in their own db/migrate/
# Host app copies them with:
rails billing:install:migrations
rails db:migrate
```

Or in Rails 6+ with `railties_order` and `db:migrate:engines`:

```ruby
# Host config/application.rb
config.paths["db/migrate"] << Billing::Engine.root.join("db/migrate")
```

---

## Cross-Cutting Patterns

### Service Objects

```ruby
# app/services/article_publisher.rb
class ArticlePublisher
  Result = Data.define(:success, :article, :error)

  def initialize(article, published_by:)
    @article      = article
    @published_by = published_by
  end

  def call
    validate!
    publish!
    notify!
    Result.new(success: true, article: @article, error: nil)
  rescue StandardError => e
    Result.new(success: false, article: @article, error: e.message)
  end

  private

  def validate!
    raise "Not authorized" unless @published_by.can_publish?(@article)
    raise "Already published" if @article.published?
  end

  def publish!
    @article.update!(status: :published, published_at: Time.current, published_by: @published_by)
  end

  def notify!
    @article.subscribers.find_each do |subscriber|
      ArticleMailer.new_article_notification(@article, subscriber).deliver_later
    end
  end
end

# Controller usage
result = ArticlePublisher.new(@article, published_by: current_user).call
if result.success
  redirect_to result.article
else
  redirect_to @article, alert: result.error
end
```

### Query Objects

```ruby
class ArticleSearchQuery
  def initialize(relation = Article.all)
    @relation = relation
  end

  def call(params)
    scope = @relation
    scope = scope.where("title ILIKE ?", "%#{params[:q]}%") if params[:q].present?
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(author_id: params[:author_id]) if params[:author_id].present?
    scope = scope.where("published_at >= ?", params[:from].to_date) if params[:from].present?
    scope = scope.order(sort_column(params[:sort]) => sort_direction(params[:direction]))
    scope
  end

  private

  SORTABLE = %w[title published_at views_count].freeze

  def sort_column(col)
    SORTABLE.include?(col) ? col : "published_at"
  end

  def sort_direction(dir)
    dir == "asc" ? :asc : :desc
  end
end
```

### Concerns (Model Mixins)

```ruby
# app/models/concerns/searchable.rb
module Searchable
  extend ActiveSupport::Concern

  included do
    after_commit :sync_to_search_index, on: [:create, :update]
    after_commit :remove_from_search_index, on: :destroy
  end

  class_methods do
    def search(query)
      SearchService.search(query, index: search_index_name)
    end

    def search_index_name
      model_name.plural
    end
  end

  private

  def sync_to_search_index
    SearchIndexJob.perform_later(self.class.name, id)
  end

  def remove_from_search_index
    SearchRemoveJob.perform_later(self.class.name, id)
  end
end

class Article < ApplicationRecord
  include Searchable
end
```

---

## Version Compatibility Notes

| Feature | Introduced |
|---------|-----------|
| `ApplicationRecord` | Rails 5.0 |
| `form_with` | Rails 5.1 |
| Credentials | Rails 5.2 |
| `belongs_to` required by default | Rails 5.0 |
| Multiple databases | Rails 6.0 |
| Action Mailbox / Action Text | Rails 6.0 |
| Hotwire/Turbo default | Rails 7.0 |
| Encrypted attributes (`encrypts`) | Rails 7.0 |
| Importmap default | Rails 7.0 |
| `load_async` / async queries | Rails 7.0 |
| Solid Queue default adapter | Rails 8.0 |
| Turbo 8 Morphing | Rails 8.0 |
| `Data.define` | Ruby 3.2 |
| `enum :field, {}` keyword syntax | Rails 7.0 |
| `strict_loading_by_default` | Rails 6.1 |
| `in_batches` | Rails 5.0 |
