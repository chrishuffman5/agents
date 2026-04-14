# Rails Architecture Reference

Deep architecture internals for Rails 7.2-8.1. Load this file when answering questions about ActiveRecord internals, middleware, routing, Action Cable, Turbo/Hotwire, Active Storage, or engines.

---

## ActiveRecord Internals

### Associations

Rails associations are macros that generate helper methods and manage foreign-key conventions.

#### belongs_to

```ruby
class Comment < ApplicationRecord
  belongs_to :article                                    # required by default (Rails 5+)
  belongs_to :author, class_name: "User", optional: true # optional skips presence validation
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

Join through an intermediate model -- access join record data directly.

```ruby
class Physician < ApplicationRecord
  has_many :appointments
  has_many :patients, through: :appointments
end

class Appointment < ApplicationRecord
  belongs_to :physician
  belongs_to :patient
  # Extra columns: scheduled_at, notes
end

class Patient < ApplicationRecord
  has_many :appointments
  has_many :physicians, through: :appointments
end
```

#### Polymorphic Associations

One model belongs to multiple others via a type/id pair.

```ruby
class Picture < ApplicationRecord
  belongs_to :imageable, polymorphic: true
end

class Employee < ApplicationRecord
  has_many :pictures, as: :imageable
end

class Product < ApplicationRecord
  has_many :pictures, as: :imageable
end
```

Migration:

```ruby
create_table :pictures do |t|
  t.string  :imageable_type, null: false
  t.integer :imageable_id,   null: false
  t.timestamps
  t.index [:imageable_type, :imageable_id]
end
```

#### Self-Referential

```ruby
class Employee < ApplicationRecord
  belongs_to :manager,  class_name: "Employee", optional: true
  has_many   :reports,  class_name: "Employee", foreign_key: :manager_id
end
```

#### Key Association Options

| Option | Purpose |
|---|---|
| `dependent: :destroy` | Destroy associated records via callbacks |
| `dependent: :delete_all` | SQL DELETE without callbacks |
| `dependent: :nullify` | Set FK to NULL |
| `dependent: :restrict_with_error` | Error if children exist |
| `counter_cache: true` | Maintain count column on parent |
| `touch: true` | Update parent's `updated_at` |
| `inverse_of:` | Bi-directional in-memory linking |
| `strict_loading:` | Raise on N+1 at association access |

### Query Interface

ActiveRecord returns lazy, chainable `ActiveRecord::Relation` objects.

```ruby
# where -- multiple forms
User.where(active: true)
User.where("created_at > ?", 1.week.ago)
User.where(role: [:admin, :moderator])   # IN clause
User.where.not(banned: true)
User.where(age: 18..65)                  # BETWEEN

# Aggregation
Order.group(:status).count
Order.where(status: :completed).average(:total_cents)

# Plucking (no model instantiation)
User.where(active: true).pluck(:id, :email)

# Batch processing (memory-efficient)
User.find_each(batch_size: 500) { |user| user.reindex }
User.in_batches(of: 1000).each_record { |u| u.update(verified: true) }
```

#### joins vs includes vs eager_load vs preload

```ruby
# INNER JOIN -- filters work but N+1 on association access
Post.joins(:comments).where(comments: { approved: true })

# LEFT OUTER JOIN -- filtering + loading associations together
Post.eager_load(:comments).where(comments: { approved: true })

# Two-query preloading -- no JOIN, no cross-product bloat
Post.preload(:comments, :author)

# includes -- Rails decides (preload for basic, eager_load when where references association)
Post.includes(:author).where(users: { active: true })  # triggers eager_load
Post.includes(:comments)                                # triggers preload
```

### Arel (SQL AST)

Use Arel when the query DSL falls short.

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

# Named functions
User.select(Arel::Nodes::NamedFunction.new("COALESCE", [users[:display_name], users[:email]]))
```

### Callbacks Lifecycle

**Create:** `before_validation` -> `after_validation` -> `before_save` -> `around_save` -> `before_create` -> `around_create` -> `after_create` -> `after_save` -> `after_commit/after_rollback`

**Update:** `before_validation` -> `after_validation` -> `before_save` -> `around_save` -> `before_update` -> `around_update` -> `after_update` -> `after_save` -> `after_commit/after_rollback`

**Destroy:** `before_destroy` -> `around_destroy` -> `after_destroy` -> `after_commit/after_rollback`

```ruby
class Order < ApplicationRecord
  before_validation :normalize_email
  after_create      :send_confirmation_email
  before_save       :set_status_timestamp
  after_commit      :sync_to_crm, on: [:create, :update]

  private

  def set_status_timestamp
    self.status_changed_at = Time.current if status_changed?
  end
end
```

**Halting the chain:** `throw :abort` in any before callback stops the operation.

**after_commit vs after_save:** Use `after_commit` for side effects (emails, jobs, external APIs) -- ensures the database transaction has fully committed.

### Validations

```ruby
class User < ApplicationRecord
  validates :email,    presence: true,
                       uniqueness: { case_sensitive: false, scope: :tenant_id },
                       format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :age,      numericality: { greater_than_or_equal_to: 18, only_integer: true },
                       allow_nil: true
  validates :username, length: { minimum: 3, maximum: 50 },
                       format: { with: /\A[a-z0-9_]+\z/ }
  validates :terms,    acceptance: true, on: :create
  validate  :password_complexity
end
```

**Custom reusable validators:**

```ruby
class PhoneValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    unless value =~ /\A\+?[\d\s\-().]{7,20}\z/
      record.errors.add(attribute, options[:message] || "is not a valid phone number")
    end
  end
end
```

### Migrations

```ruby
class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      t.string     :title,       null: false
      t.text       :body
      t.integer    :status,      default: 0, null: false
      t.references :author,      null: false, foreign_key: { to_table: :users }
      t.boolean    :published,   default: false, null: false
      t.jsonb      :metadata,    default: {}   # Postgres-specific
      t.timestamps
    end
    add_index :articles, [:author_id, :status]
  end
end
```

**Safe column additions (large tables):**

```ruby
class AddVerifiedToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :verified, :boolean
    add_index  :users, :verified, algorithm: :concurrently
  end
end
```

### Enums

```ruby
class Article < ApplicationRecord
  enum :status, { draft: 0, published: 1, archived: 2 }, prefix: true
  # Generates: status_draft?, status_published!, Article.status_published
end
```

---

## Rack Middleware Stack

Every Rails app is a Rack application. Middleware wraps the inner app in an onion model.

```bash
rails middleware  # lists the full stack
```

Key middleware in order:

| Middleware | Purpose |
|---|---|
| `ActionDispatch::HostAuthorization` | Blocks DNS rebinding |
| `Rack::Sendfile` | X-Sendfile for web server |
| `ActionDispatch::Static` | Serves public/ assets |
| `ActionDispatch::Executor` | Per-request thread isolation |
| `Rack::MethodOverride` | `_method` param for PUT/PATCH/DELETE |
| `ActionDispatch::RequestId` | X-Request-Id header |
| `ActionDispatch::ShowExceptions` | Error page rendering |
| `ActionDispatch::Cookies` | Cookie jar |
| `ActionDispatch::Session::CookieStore` | Session handling |
| `ActionDispatch::Flash` | Flash messages |
| `ActionDispatch::ContentSecurityPolicy::Middleware` | CSP headers |
| `Rack::ETag` | ETag headers |

**Custom middleware:**

```ruby
class TimingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status, headers, response = @app.call(env)
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    headers["X-Request-Duration"] = duration.round(4).to_s
    [status, headers, response]
  end
end

# config/application.rb
config.middleware.insert_before ActionDispatch::Static, TimingMiddleware
```

---

## Routing Engine

```ruby
Rails.application.routes.draw do
  root "home#index"

  # RESTful resources (7 standard routes)
  resources :articles

  # Nested resources (keep to 1-2 levels)
  resources :articles do
    resources :comments, only: [:create, :destroy]
  end

  # Shallow nesting
  resources :articles, shallow: true do
    resources :comments
  end

  # Member and collection routes
  resources :articles do
    member { post :publish; get :preview }
    collection { get :search }
  end

  # Route concerns
  concern :commentable do
    resources :comments
  end
  resources :articles, concerns: [:commentable]

  # Namespace (URL + module + helper prefix)
  namespace :api do
    namespace :v1 do
      resources :users
    end
  end

  # Constraints
  constraints(host: /api\./) do
    namespace :api { resources :users }
  end

  # Redirect
  get "/old-path", to: redirect("/new-path", status: 301)

  # Mount engines / Rack apps
  mount Sidekiq::Web, at: "/sidekiq"
  mount ActionCable.server, at: "/cable"
end
```

---

## Action Cable

### Connection

```ruby
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
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

### Channels

```ruby
class ChatChannel < ApplicationCable::Channel
  def subscribed
    room = Room.find(params[:room_id])
    reject unless current_user.member_of?(room)
    stream_for room
  end

  def speak(data)
    room = Room.find(params[:room_id])
    room.messages.create!(content: data["message"], user: current_user)
  end
end
```

### Broadcasting

```ruby
# From a model
class Message < ApplicationRecord
  after_create_commit do
    ChatChannel.broadcast_to(room, {
      type: "message",
      html: ApplicationController.render(partial: "messages/message", locals: { message: self })
    })
  end
end

# From anywhere
ActionCable.server.broadcast("notifications_#{user.id}", { type: "alert", text: "New order!" })
```

### JavaScript Client

```javascript
import consumer from "channels/consumer"

consumer.subscriptions.create(
  { channel: "ChatChannel", room_id: roomId },
  {
    received(data) {
      document.getElementById("messages").insertAdjacentHTML("beforeend", data.html)
    },
    speak(message) {
      this.perform("speak", { message })
    }
  }
)
```

### Turbo Streams over Action Cable

```ruby
class Message < ApplicationRecord
  broadcasts_to :room  # shorthand for append/replace/remove callbacks
end
```

```erb
<%= turbo_stream_from @room %>
<div id="messages"><%= render @room.messages %></div>
```

---

## Turbo/Hotwire

### Turbo Drive

Intercepts link clicks and form submissions, replacing only the `<body>`. Gives SPA-like navigation without JavaScript.

```erb
<%# Opt-out %>
<%= link_to "Download", report_path(@report), data: { turbo: false } %>
```

Return `status: :see_other` on DELETE redirects (303) for Turbo compatibility.

### Turbo Frames

Scope navigation to a portion of the page.

```erb
<%= turbo_frame_tag "new-article" do %>
  <%= link_to "New Article", new_article_path %>
<% end %>

<%# Lazy loading %>
<%= turbo_frame_tag "comments", src: comments_path(@article), loading: :lazy do %>
  <p>Loading...</p>
<% end %>

<%# Break out of frame %>
<%= link_to "Full Page", article_path(@a), data: { turbo_frame: "_top" } %>
```

### Turbo Streams

Seven actions: `append`, `prepend`, `replace`, `update`, `remove`, `before`, `after`.

```ruby
# From controller
def create
  @article = current_user.articles.build(article_params)
  if @article.save
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.prepend("articles", partial: "articles/article", locals: { article: @article }),
          turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Created!" })
        ]
      end
      format.html { redirect_to @article }
    end
  end
end
```

### Morphing (Turbo 8)

Page morphing diffs and patches only what changed, preserving scroll position, form state, and focus.

```html
<!-- Preserve element across navigations -->
<div id="sidebar" data-turbo-permanent>...</div>
```

### Stimulus

```javascript
import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = ["input", "counter"]
  static values  = { max: { type: Number, default: 280 } }

  connect() { this.update() }

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

---

## Active Storage

### Setup

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
```

### Attachments and Variants

```ruby
class Article < ApplicationRecord
  has_one_attached :cover_image do |attachable|
    attachable.variant :thumb,  resize_to_limit: [100, 100]
    attachable.variant :medium, resize_to_limit: [400, 400], format: :webp
  end
end
```

```erb
<%= image_tag article.cover_image.variant(:medium) %>
```

### Direct Uploads

```erb
<%= f.file_field :cover_image, direct_upload: true %>
```

```javascript
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
```

---

## Engines

Rails Engines are miniature Rails applications mounted inside a host app.

### Generating

```bash
rails plugin new billing --mountable
```

### Engine Definition

```ruby
module Billing
  class Engine < ::Rails::Engine
    isolate_namespace Billing

    initializer "billing.assets" do |app|
      app.config.assets.paths << root.join("app/assets")
    end
  end
end
```

### Mounting

```ruby
# Host app routes
Rails.application.routes.draw do
  mount Billing::Engine, at: "/billing", as: "billing"
end

# Route helpers
billing.invoices_path            # /billing/invoices
main_app.root_path               # back to host app
```

### Sharing Models

```ruby
module Billing
  class Engine < ::Rails::Engine
    isolate_namespace Billing
    mattr_accessor :user_class
    self.user_class = "User"
  end
end

# Host initializer
Billing.user_class = "Account"
```

---

## Action Mailer

```ruby
class OrderMailer < ApplicationMailer
  def confirmation
    @order = params[:order]
    @tracking_url = track_order_url(@order)
    mail(to: @order.user.email, subject: "Order ##{@order.number} Confirmed")
  end

  def shipped(tracking_number)
    @tracking_number = tracking_number
    attachments["slip.pdf"] = OrderPdf.new(params[:order]).render
    mail(to: params[:order].user.email, subject: "Your order has shipped!")
  end
end

# Deliver
OrderMailer.with(order: @order).confirmation.deliver_later

# Previews (visit /rails/mailers/order_mailer/confirmation)
class OrderMailerPreview < ActionMailer::Preview
  def confirmation
    OrderMailer.with(order: Order.last).confirmation
  end
end
```

---

## Configuration

### Credentials

```bash
rails credentials:edit                          # edit encrypted credentials
rails credentials:edit --environment production  # per-environment
```

```ruby
Rails.application.credentials.aws.access_key_id
Rails.application.credentials.dig(:stripe, :secret_key)
Rails.application.credentials.secret_key_base!  # raises if missing
```

### Custom Configuration

```ruby
# config/application.rb
config.x.payment.provider = "stripe"
config.x.features.dark_mode = true

# Access
Rails.configuration.x.payment.provider
```
