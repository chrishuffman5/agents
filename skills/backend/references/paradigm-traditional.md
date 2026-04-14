# Batteries-Included & MVC Framework Patterns

## The Full-Stack Philosophy

Batteries-included frameworks (Django, Rails, Spring Boot, ASP.NET Core) make a fundamental trade: they give up flexibility for velocity. Everything you need is included, pre-configured, and designed to work together. The framework makes decisions so you don't have to — and those decisions are usually good ones.

### What "Batteries-Included" Actually Means

| Component | Django | Rails | Spring Boot | ASP.NET Core |
|---|---|---|---|---|
| **ORM** | Django ORM | ActiveRecord | Spring Data JPA | Entity Framework Core |
| **Migrations** | `manage.py migrate` | `rails db:migrate` | Flyway / Liquibase | EF Migrations |
| **Auth** | `django.contrib.auth` | Devise (gem) | Spring Security | ASP.NET Identity |
| **Admin** | Built-in admin panel | ActiveAdmin (gem) | Spring Boot Admin | No built-in (Hangfire dashboard) |
| **Background Jobs** | Celery, django-q2 | Active Job + Solid Queue | `@Async`, Spring Batch | Hangfire, hosted services |
| **WebSockets** | Django Channels | Action Cable | Spring WebSocket | SignalR |
| **Templates** | Django templates / Jinja2 | ERB / Haml | Thymeleaf / Freemarker | Razor Pages / Blazor |
| **File Uploads** | Django Storage | Active Storage | Spring Content | IFormFile + storage providers |
| **Testing** | `django.test` | Minitest / RSpec | JUnit + MockMvc | xUnit + WebApplicationFactory |
| **CLI** | `manage.py` commands | `rails` CLI + generators | Spring Boot CLI | `dotnet` CLI |

### Request Lifecycle (MVC Pattern)

All batteries-included frameworks follow the same request flow:

```
HTTP Request
    │
    ▼
┌──────────────┐
│  Middleware   │  Logging, auth, CORS, compression, rate limiting
│  Pipeline     │  (Django: middleware classes, Rails: Rack middleware,
│               │   Spring: filters, ASP.NET: middleware)
└──────┬───────┘
       │
┌──────▼───────┐
│  Router      │  Map URL pattern to controller/view
│              │  (Django: urls.py, Rails: routes.rb,
│              │   Spring: @RequestMapping, ASP.NET: routing)
└──────┬───────┘
       │
┌──────▼───────┐
│  Controller  │  Business logic, call services/models
│  / View      │  (Django: views.py, Rails: controllers,
│              │   Spring: @Controller, ASP.NET: Controllers)
└──────┬───────┘
       │
┌──────▼───────┐
│  Model/ORM   │  Database operations
│              │  (Django: models.py, Rails: models,
│              │   Spring: @Entity, ASP.NET: DbContext)
└──────┬───────┘
       │
┌──────▼───────┐
│  Serializer  │  Transform to JSON/HTML response
│  / Template  │  (DRF serializers, Rails JBuilder,
│              │   Jackson, System.Text.Json)
└──────────────┘
```

### ORM Patterns

#### N+1 Query Problem

The single most common performance issue in batteries-included frameworks:

```python
# Django — BAD: N+1 queries (1 for orders, N for customers)
orders = Order.objects.all()
for order in orders:
    print(order.customer.name)  # Each access hits the DB

# Django — GOOD: Eager loading
orders = Order.objects.select_related('customer').all()
```

```ruby
# Rails — BAD: N+1
orders = Order.all
orders.each { |o| puts o.customer.name }

# Rails — GOOD: Eager loading
orders = Order.includes(:customer).all
```

```java
// Spring/JPA — BAD: Lazy loading triggers N+1
@Entity
class Order {
    @ManyToOne(fetch = FetchType.LAZY)  // Default
    private Customer customer;
}

// Spring/JPA — GOOD: JPQL join fetch
@Query("SELECT o FROM Order o JOIN FETCH o.customer")
List<Order> findAllWithCustomer();
```

#### Migration Strategy

All four frameworks support schema migrations, but strategies differ:

| Aspect | Django | Rails | Spring Boot | ASP.NET Core |
|---|---|---|---|---|
| **Generation** | Auto from model changes | Manual (generators help) | Manual (Flyway/Liquibase) | Auto from model changes |
| **Reversibility** | Manual `RunPython` for data | Automatic `down` methods | Manual rollback SQL | Manual |
| **Data migrations** | Supported (`RunPython`) | Supported (Ruby code) | Supported (SQL/Java) | Not built-in (seed data) |
| **Zero-downtime** | Careful column add/remove | Strong Opinions (strong_migrations gem) | Manual | Manual |

### When to Choose Full-Stack

**Choose batteries-included when:**
- Building a CRUD-heavy application with an admin interface
- Team values convention over configuration
- Project needs auth, ORM, admin, templates, and background jobs
- Rapid prototyping with a path to production
- Compliance requirements favor established, audited frameworks

**Avoid batteries-included when:**
- Building a pure API gateway or proxy
- Deploying to serverless (Lambda, Cloud Functions) — too heavy
- Microservice with < 5 endpoints
- Maximum throughput is the primary requirement

## Micro-Framework Patterns

### Express.js Pattern

```javascript
const express = require('express');
const app = express();

// Middleware — manually composed stack
app.use(express.json());
app.use(cors());
app.use(helmet());
app.use(morgan('combined'));

// Routes — flat or organized into routers
app.get('/users/:id', async (req, res) => {
  const user = await db.users.findById(req.params.id);
  res.json(user);
});

// Error handler — must be last
app.use((err, req, res, next) => {
  res.status(500).json({ error: err.message });
});
```

### Flask Pattern

```python
from flask import Flask, jsonify, request

app = Flask(__name__)

@app.route('/users/<int:user_id>')
def get_user(user_id):
    user = db.session.get(User, user_id)
    return jsonify(user.to_dict())

@app.errorhandler(404)
def not_found(e):
    return jsonify(error="Not found"), 404
```

### The Assembly Problem

Micro-frameworks require you to choose and integrate:
- ORM (SQLAlchemy, Sequelize, Prisma, GORM)
- Auth (Passport.js, Flask-Login, jwt middleware)
- Validation (Joi, Marshmallow, validator)
- Migrations (Alembic, Knex, goose)
- Background jobs (Bull, Celery, Machinery)
- Testing (Jest, pytest, testify)

This provides maximum flexibility but also maximum decision fatigue. If you find yourself installing 15 packages to build a CRUD app, you might want a batteries-included framework instead.
