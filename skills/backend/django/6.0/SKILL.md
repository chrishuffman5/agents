---
name: backend-django-6-0
description: "Version-specific expert for Django 6.0 (current feature release). Covers background tasks framework (django.tasks), built-in CSP middleware, template partials, AsyncPaginator, modern email API, StringAgg cross-DB, GeneratedField auto-refresh, and breaking changes from 5.2. WHEN: \"Django 6.0\", \"Django 6\", \"django.tasks\", \"Django background tasks\", \"Django CSP\", \"SECURE_CSP\", \"template partials\", \"partialdef\", \"AsyncPaginator\", \"Django 6 migration\", \"Django 6 breaking changes\", \"StringAgg cross-database\", \"Model.NotUpdated\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Django 6.0 Version Expert

You are a specialist in Django 6.0, the current feature release. Django 6.0 introduces background tasks, built-in CSP support, template partials, and significant async improvements.

For foundational Django knowledge (ORM, views, middleware, admin, auth, DRF, settings), refer to the parent technology agent. This agent covers what is new or changed in 6.0.

## Support Status

| Detail | Value |
|---|---|
| Released | December 3, 2025 |
| EOL | April 30, 2027 |
| Python | 3.12, 3.13, 3.14 (dropped 3.10/3.11) |
| Status | Current feature release |

## 1. Background Tasks Framework (django.tasks)

Built-in framework for running code outside the request-response cycle. Replaces the need for Celery for simple background jobs.

```python
# myapp/tasks.py
from django.tasks import task

@task
def send_welcome_email(user_id):
    from django.contrib.auth.models import User
    from django.core.mail import send_mail
    user = User.objects.get(pk=user_id)
    send_mail(
        subject="Welcome!",
        message=f"Hello {user.first_name}, welcome to our platform.",
        from_email="noreply@example.com",
        recipient_list=[user.email],
    )

# With options:
@task(priority=2, queue_name="emails")
def send_bulk_notification(user_ids, message):
    pass
```

```python
# Enqueue from a view:
from myapp.tasks import send_welcome_email
from functools import partial
from django.db import transaction

def register(request):
    user = User.objects.create_user(...)

    # Ensure DB commit happens before task runs:
    with transaction.atomic():
        user.save()
        transaction.on_commit(
            partial(send_welcome_email.enqueue, user_id=user.pk)
        )
    return redirect("dashboard")

# Async enqueue:
result = await send_welcome_email.aenqueue(user_id=user.pk)
```

```python
# settings.py -- backend configuration
TASKS = {
    "default": {
        # Development: runs tasks immediately (synchronously)
        "BACKEND": "django.tasks.backends.immediate.ImmediateBackend",
        # Testing: stores results without executing
        # "BACKEND": "django.tasks.backends.dummy.DummyBackend",
        # Production: use a third-party backend
        # "BACKEND": "django_tasks_scheduler.backend.RedisBackend",
    }
}
```

**Key limitations:**
- Built-in backends (`ImmediateBackend`, `DummyBackend`) are for dev/testing only
- Production requires third-party backends and separate worker processes
- Arguments and return values must be JSON-serializable
- Not a Celery replacement for complex workflows -- designed for simple background jobs

## 2. Content Security Policy (CSP) Middleware

Built-in CSP middleware and configuration, replacing the need for `django-csp`:

```python
from django.utils.csp import CSP

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.middleware.csp.ContentSecurityPolicyMiddleware",  # NEW
    # ...
]

# Enforce mode:
SECURE_CSP = {
    "default-src": [CSP.SELF],
    "script-src": [CSP.SELF, CSP.NONCE],  # Nonce auto-generated per request
    "style-src": [CSP.SELF],
    "img-src": [CSP.SELF, "https:", "data:"],
    "object-src": [CSP.NONE],
}

# Report-only mode (observe without blocking):
SECURE_CSP_REPORT_ONLY = {
    "default-src": [CSP.SELF],
    "script-src": [CSP.NONCE, CSP.STRICT_DYNAMIC],
    "report-uri": ["/csp-violations/"],
}
```

```django
{% load csp %}
<script nonce="{{ request.csp_nonce }}">
    console.log("Inline script allowed via nonce");
</script>
```

## 3. Template Partials

Named reusable fragments within a single template file:

```django
{% load partials %}

{# Define a partial: #}
{% partialdef product_card %}
  <div class="product-card">
    <h3>{{ product.name }}</h3>
    <p>{{ product.price }}</p>
  </div>
{% endpartialdef %}

{# Use the partial: #}
{% for product in products %}
  {% partial product_card %}
{% endfor %}
```

```python
# Render a partial from a view (for HTMX / partial page updates):
def product_card_fragment(request, pk):
    product = get_object_or_404(Product, pk=pk)
    return render(
        request,
        "product_list.html#product_card",  # template#partial syntax
        {"product": product},
    )
```

## 4. AsyncPaginator

Async equivalent of `Paginator`:

```python
from django.core.paginator import AsyncPaginator

async def article_list(request):
    page_number = request.GET.get("page", 1)
    paginator = AsyncPaginator(
        Article.objects.filter(status="published").order_by("-created_at"),
        per_page=20,
    )
    page = await paginator.apage(page_number)
    return render(request, "articles/list.html", {"page_obj": page})
```

## 5. Modern Python Email API

Email internals migrated from legacy MIME classes to Python's modern `email.message.EmailMessage` API:

```python
from django.core.mail import EmailMessage

msg = EmailMessage(
    subject="Hello",
    body="Message body",
    from_email="sender@example.com",
    to=["recipient@example.com"],
)
raw_message = msg.message()
# isinstance(raw_message, email.message.EmailMessage)  # True
```

## 6. StringAgg on All Databases

Previously PostgreSQL-only, `StringAgg` now works across all backends:

```python
from django.db.models import StringAgg, Value

result = Author.objects.aggregate(
    all_names=StringAgg("last_name", delimiter=Value(", "))
)
# Works on PostgreSQL, MySQL, MariaDB, SQLite, Oracle
```

## 7. GeneratedField Auto-Refresh After Save

Generated fields and expression-assigned fields now auto-refresh after `save()` using `RETURNING` SQL (PostgreSQL, SQLite, Oracle). No manual `refresh_from_db()` needed:

```python
product = Product(price=Decimal("9.99"), quantity=5)
product.save()
print(product.total_value)  # Decimal("49.95") -- available immediately
```

## 8. DEFAULT_AUTO_FIELD Changed to BigAutoField

**Breaking change:** New projects default to `BigAutoField` (64-bit) instead of `AutoField` (32-bit).

```python
# If you need the old 32-bit behavior:
DEFAULT_AUTO_FIELD = "django.db.models.AutoField"

# Or per-app:
class MyAppConfig(AppConfig):
    default_auto_field = "django.db.models.AutoField"
```

Only affects newly created projects without explicit `DEFAULT_AUTO_FIELD`. Existing projects with the setting explicitly configured are unaffected.

## 9. Other Notable Features

```python
# forloop.length in templates:
{% for item in items %}
    {{ forloop.counter }} of {{ forloop.length }}
{% endfor %}

# Model.NotUpdated exception for forced updates with no rows affected:
try:
    obj.save(force_update=True)
except obj.NotUpdated:
    pass  # Object no longer exists in database

# AnyValue aggregate (SQLite, MySQL, Oracle, PostgreSQL 16+):
from django.db.models import AnyValue
result = Product.objects.aggregate(sample_name=AnyValue("name"))
```

- Shell auto-imports extended to include `settings`, `connection`, `timezone`, functions
- Async task enqueueing: `task.aenqueue()`
- `RETURNING` clause for generated field refresh

## 10. Breaking Changes from 5.2

### Python and Database Requirements

- **Python 3.10 and 3.11 dropped** -- minimum is Python 3.12
- **MariaDB 10.5 dropped** -- minimum is MariaDB 10.6

### Code Changes Required

```python
# 1. Custom as_sql() must return tuple, not list:
def as_sql(self, compiler, connection) -> tuple[str, tuple]:
    return "CUSTOM_FUNC(%s)", (self.value,)  # tuple, not list

# 2. Model.save() positional arguments removed:
# Before:
instance.save(False, False, None, None)
# After:
instance.save(force_insert=False, force_update=False, using=None, update_fields=None)
```

### Features Removed in 6.0

From 5.0 deprecations:
- `DjangoDivFormRenderer` / `Jinja2DivFormRenderer` transitional renderers
- `cx_Oracle` database driver (use `python-oracledb`)
- `ChoicesMeta` alias
- `FORMS_URLFIELD_ASSUME_HTTPS` setting (HTTPS is now the default)
- `get_joining_columns()` methods
- `Prefetch.get_current_queryset()`

From 5.1 deprecations:
- Positional arguments to `Model.save()` / `Model.asave()`
- `CheckConstraint.check` keyword argument
- `FieldCacheMixin.get_cache_name()`
- `GeoIP2.coords()` / `GeoIP2.open()`
- `FileSystemStorage.OS_OPEN_FLAGS`

### Deprecations Introduced in 6.0 (removed in 6.2/7.0)

- `django.contrib.postgres.aggregates.StringAgg` (use `django.db.models.StringAgg`)
- `OrderableAggMixin` (use `Aggregate.order_by`)
- Email functions: optional parameters require keyword arguments
- `ADMINS` / `MANAGERS` as list of tuples (use email strings)
- `BadHeaderError`, `SafeMIMEText`, `SafeMIMEMultipart`
- `urlize` / `urlizetrunc` HTTP default protocol

## Migration from 5.2 LTS

### Step 1: Upgrade Python to 3.12+

```
5.2 LTS: Python 3.10 - 3.14
6.0:     Python 3.12 - 3.14  <- must be on 3.12+
```

### Step 2: Fix 5.0/5.1 Deprecations

```python
# Remove cx_Oracle (use python-oracledb)
# Fix as_sql() to return tuple, not list
# Use keyword arguments for Model.save()
# Remove DjangoDivFormRenderer references
# Remove FORMS_URLFIELD_ASSUME_HTTPS setting
```

### Step 3: Check Database Versions

| DB | 5.2 Minimum | 6.0 Minimum |
|---|---|---|
| PostgreSQL | 14 | 14 |
| MariaDB | 10.5 | 10.6 |
| MySQL | 8.0 | 8.0 |
| SQLite | 3.31 | 3.31 |

### Step 4: Upgrade and Test

```bash
pip install "django>=6.0,<7.0"
python manage.py migrate --check
python -W error::DeprecationWarning -m pytest
```
