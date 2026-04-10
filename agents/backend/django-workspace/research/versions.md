# Django Version Reference: 4.2 LTS through 6.0

Last updated: April 2026  
Covers: Django 4.2 LTS, 5.0, 5.1, 5.2 LTS, 6.0

---

## Version Overview

| Version | Type | Released | EOL / Security Support |
|---------|------|----------|------------------------|
| 4.2 | LTS | Apr 3, 2023 | Apr 30, 2026 (EOL — now ended) |
| 5.0 | Feature | Dec 4, 2023 | Apr 2, 2025 (EOL) |
| 5.1 | Feature | Aug 7, 2024 | Dec 3, 2025 (EOL) |
| 5.2 | LTS | Apr 2, 2025 | Apr 30, 2028 |
| 6.0 | Feature | Dec 3, 2025 | Apr 30, 2027 |

Python support summary:
- 4.2 LTS: Python 3.8 – 3.12
- 5.0: Python 3.10 – 3.12
- 5.1: Python 3.10 – 3.13
- 5.2 LTS: Python 3.10 – 3.14
- 6.0: Python 3.12 – 3.14 (drops 3.10 and 3.11)

---

## Django 4.2 LTS

**Released:** April 3, 2023  
**EOL:** April 30, 2026 (security support ended — migrate to 5.2 LTS now)  
**Python:** 3.8, 3.9, 3.10, 3.11, 3.12

### Psycopg 3 Support

Django 4.2 adds support for psycopg version 3.1.8+ as a PostgreSQL database adapter. The engine string does not change — the same `django.db.backends.postgresql` engine works with both psycopg2 and psycopg3.

```python
# Install psycopg3
# pip install "psycopg[binary]>=3.1.8"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": "mydb",
        "USER": "myuser",
        "PASSWORD": "mypassword",
        "HOST": "localhost",
        "PORT": "5432",
        # psycopg3-specific option: server-side parameter binding
        "OPTIONS": {
            "server_side_binding": True,  # psycopg3 only
        },
    }
}
```

Key psycopg3 advantages over psycopg2:
- Server-side parameter binding (better performance, prevents SQL injection at driver level)
- Native async connection support (used by Django's async ORM path)
- Better memory efficiency for large result sets

### Comments on Columns and Tables

Database-level documentation comments via `db_comment` and `db_table_comment` (all backends except SQLite).

```python
from django.db import models

class Order(models.Model):
    customer_id = models.IntegerField(
        db_comment="FK to customers table — not enforced at DB level"
    )
    total = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        db_comment="Order total in USD. Stored as decimal, not cents."
    )
    status = models.CharField(
        max_length=20,
        db_comment="Allowed values: pending, confirmed, shipped, cancelled"
    )

    class Meta:
        db_table_comment = "Customer orders. Partitioned monthly in production."
```

New migration operation: `AlterModelTableComment` for changing table comments post-creation.

### Custom File Storage API (STORAGES Setting)

The `STORAGES` dictionary setting replaces the deprecated `DEFAULT_FILE_STORAGE` and `STATICFILES_STORAGE` settings. It also allows defining multiple named storage backends.

```python
# Old way (deprecated in 4.2, removed in 5.1):
DEFAULT_FILE_STORAGE = "myapp.storage.S3Storage"
STATICFILES_STORAGE = "django.contrib.staticfiles.storage.ManifestStaticFilesStorage"

# New way (Django 4.2+):
STORAGES = {
    "default": {
        "BACKEND": "myapp.storage.S3Storage",
        "OPTIONS": {
            "bucket_name": "my-media-bucket",
            "region_name": "us-east-1",
        },
    },
    "staticfiles": {
        "BACKEND": "django.contrib.staticfiles.storage.ManifestStaticFilesStorage",
    },
    # Multiple named backends supported:
    "private": {
        "BACKEND": "myapp.storage.PrivateS3Storage",
        "OPTIONS": {
            "bucket_name": "my-private-bucket",
        },
    },
}
```

New in-memory storage class for tests:

```python
from django.core.files.storage import InMemoryStorage

# In tests — avoids disk I/O entirely
storage = InMemoryStorage()
```

### on_delete and Database-Level Constraints

Note: Django's `on_delete` options (`CASCADE`, `PROTECT`, `SET_NULL`, `SET_DEFAULT`, `RESTRICT`, `DO_NOTHING`) have been available since Django 2.x. Django enforces these **in Python**, not at the database level — the actual FK constraint in the database is typically just a reference without cascade behavior. Django 4.2 did not change this behavior. If you need true database-level cascade, use `SET DEFAULT` directly in migrations with `RunSQL`.

```python
# on_delete options available across all versions:
class Article(models.Model):
    author = models.ForeignKey(
        "Author",
        on_delete=models.SET_DEFAULT,
        default=1,  # required when using SET_DEFAULT
        db_comment="Defaults to 'Unknown Author' (id=1) when author deleted"
    )
```

### Template-Based Form Rendering

Django 4.1 introduced `as_div()` and `DjangoDivFormRenderer`; Django 4.2 continued this transitional period. The new div-based templates became the **default in Django 5.0**.

```python
# settings.py — opt in early during 4.2 (will be default in 5.0):
FORM_RENDERER = "django.forms.renderers.DjangoDivFormRenderer"
```

```django
{# In templates — new as_div() method available since 4.1: #}
{{ form.as_div }}

{# Renders as: #}
<div>
  <label for="id_name">Name:</label>
  <input type="text" name="name" id="id_name">
</div>
```

### Async Streaming Responses (ASGI)

`StreamingHttpResponse` now accepts async iterators when served via ASGI.

```python
import asyncio
from django.http import StreamingHttpResponse

async def stream_data(request):
    async def generate():
        for i in range(100):
            yield f"data: chunk {i}\n\n"
            await asyncio.sleep(0.1)

    return StreamingHttpResponse(
        generate(),
        content_type="text/event-stream",
    )
```

### Async Model Methods (New in 4.2)

```python
# Model instance async methods added in 4.2:
article = await Article.objects.aget(pk=1)
await article.asave()
await article.adelete()
await article.arefresh_from_db()

# Related manager async methods:
await author.articles.aadd(article)
await author.articles.aclear()
await author.articles.aremove(article)
await author.articles.aset([article1, article2])
```

### Other Notable 4.2 Features

- `makemigrations --update` merges changes into the most recent migration instead of creating a new one
- Window function filtering: filter QuerySets against window function annotations
- `KT()` expression for `JSONField` key transforms
- Test client `headers` parameter: `client.get("/", headers={"accept": "application/json"})`
- Admin dark mode toggle
- PBKDF2 iteration count increased from 390,000 to 600,000

### Deprecations Introduced in 4.2 (removed in 5.1)

- `DEFAULT_FILE_STORAGE` setting
- `STATICFILES_STORAGE` setting
- `django.core.files.storage.get_storage_class()`
- `Meta.index_together` (use `Meta.indexes`)
- `BaseUserManager.make_random_password()`
- `length_is` template filter
- PostgreSQL CI fields: `CICharField`, `CIEmailField`, `CITextField`, `CIText`
- `SHA1PasswordHasher`, `UnsaltedSHA1PasswordHasher`, `UnsaltedMD5PasswordHasher`
- `SimpleTestCase.assertFormsetError()`
- `TransactionTestCase.assertQuerysetEqual()`

---

## Django 5.0

**Released:** December 4, 2023  
**EOL:** April 2, 2025 (no longer supported)  
**Python:** 3.10, 3.11, 3.12

### GeneratedField (Database-Generated Columns)

`GeneratedField` creates a column whose value is always computed by the database from an expression. The database maintains the value automatically.

```python
from django.db import models
from django.db.models import F
from django.db.models.functions import Upper, Coalesce

class Product(models.Model):
    name = models.CharField(max_length=200)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    quantity = models.IntegerField(default=0)

    # db_persist=True = STORED generated column (computed + stored on disk)
    # db_persist=False = VIRTUAL generated column (computed on read, not stored)
    # Note: SQLite and MySQL only support db_persist=True
    inventory_value = models.GeneratedField(
        expression=F("price") * F("quantity"),
        output_field=models.DecimalField(max_digits=12, decimal_places=2),
        db_persist=True,
    )

    # Generated field using a function
    name_upper = models.GeneratedField(
        expression=Upper(F("name")),
        output_field=models.CharField(max_length=200),
        db_persist=True,
    )
```

```python
# GeneratedField values are read-only — attempting to set them raises ValueError
product = Product.objects.get(pk=1)
print(product.inventory_value)  # Computed by DB
# product.inventory_value = 500  # ValueError: cannot set generated field
```

Database support:
- PostgreSQL: STORED and VIRTUAL
- MySQL 5.7.6+: STORED and VIRTUAL
- SQLite 3.31.0+: STORED only
- Oracle 12.1+: VIRTUAL only (db_persist must be False)

### db_default — Database-Computed Defaults

`db_default` sets a database-level DEFAULT constraint, evaluated by the database at INSERT time (not in Python). This is different from `default=` which is applied in Python before the INSERT.

```python
from django.db import models
from django.db.models.functions import Now, Pi, Upper

class Event(models.Model):
    # Static db_default — literal value stored in DB schema
    priority = models.IntegerField(db_default=1)

    # Dynamic db_default — evaluated at INSERT time by the database
    created_at = models.DateTimeField(db_default=Now())

    # Expression-based db_default
    slug = models.CharField(max_length=100, db_default=Upper("title"))
```

Key distinction:

```python
# default= (Python-level): evaluated when Django creates the object
# db_default= (DB-level): evaluated by the database at INSERT time

# db_default means:
# 1. The column has a DEFAULT in the DDL (visible in schema)
# 2. External tools inserting into the DB also get the default
# 3. Bulk operations that bypass Django ORM respect the default
```

### Facet Filters in Django Admin

The admin changelist now shows filter counts (facets) when `show_facets` is enabled on a `ModelAdmin`.

```python
from django.contrib import admin
from django.contrib.admin import ShowFacets

@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_filter = ["status", "category", "is_active"]

    # Options:
    # ShowFacets.ALWAYS — always show facet counts
    # ShowFacets.ALLOW — show when URL has ?_facets=True (user-toggled, default)
    # ShowFacets.NEVER — never show facet counts
    show_facets = ShowFacets.ALWAYS
```

The admin UI adds count badges to each filter option (e.g., "Active (24)").

### Field.choices Simplification

`choices` now accepts mappings (dicts), callables, and enum types directly without `.choices`.

```python
from django.db import models

# Before Django 5.0: had to use .choices on TextChoices
class Status(models.TextChoices):
    ACTIVE = "active", "Active"
    INACTIVE = "inactive", "Inactive"

class MyModel(models.Model):
    # Old: status = models.CharField(choices=Status.choices)
    # New: .choices not needed
    status = models.CharField(choices=Status)

# Dict-based choices (grouped choices supported):
SPORT_CHOICES = {
    "Martial Arts": {"judo": "Judo", "karate": "Karate"},
    "Racket": {"badminton": "Badminton", "tennis": "Tennis"},
    "other": "Other",
}

# Callable choices (evaluated at runtime):
def get_year_choices():
    from datetime import date
    current_year = date.today().year
    return [(y, str(y)) for y in range(2000, current_year + 1)]

class Registration(models.Model):
    sport = models.CharField(max_length=20, choices=SPORT_CHOICES)
    year = models.IntegerField(choices=get_year_choices)
```

### Async Features Added in 5.0

```python
from django.contrib.auth import aauthenticate, alogin, alogout, aupdate_session_auth_hash
from django.shortcuts import aget_object_or_404, aget_list_or_404

# Async auth functions
async def login_view(request):
    user = await aauthenticate(
        request,
        username=request.POST["username"],
        password=request.POST["password"],
    )
    if user:
        await alogin(request, user)

# Async shortcuts
async def article_detail(request, pk):
    article = await aget_object_or_404(Article, pk=pk)
    return render(request, "article.html", {"article": article})

# Async signals (NEW in 5.0)
from django.dispatch import Signal

my_signal = Signal()

# Send signal asynchronously
await my_signal.asend(sender=MyModel, instance=obj)
await my_signal.asend_robust(sender=MyModel, instance=obj)
```

Note: `async for` on QuerySets introduced in 5.0 (previously `alist()` was needed):

```python
async def process_all():
    async for article in Article.objects.filter(status="published"):
        await process_article(article)
```

### Other Notable 5.0 Features

- Div-based form rendering is now the **default** (`DjangoDivFormRenderer` is now the default renderer)
- `as_field_group()` replaces verbose label/help/error/widget rendering patterns
- `update_or_create()` gains `create_defaults` argument (separate defaults for create vs update)
- MariaDB: `UUIDField` now uses native UUID columns (MariaDB 10.7+)
- Python 3.8 and 3.9 support dropped

### Deprecations Introduced in 5.0 (removed in 6.0)

- Positional `BaseConstraint` arguments
- `DjangoDivFormRenderer` and `Jinja2DivFormRenderer` transitional renderers
- `BaseDatabaseOperations.field_cast_sql()`
- `cx_Oracle` database driver support
- `ChoicesMeta` alias
- `format_html()` called without args/kwargs
- `forms.URLField` default scheme (HTTP → HTTPS)
- `get_joining_columns()` methods
- `Prefetch.get_current_queryset()`

---

## Django 5.1

**Released:** August 7, 2024  
**EOL:** December 3, 2025 (no longer supported)  
**Python:** 3.10, 3.11, 3.12, 3.13

### LoginRequiredMiddleware

A new middleware that requires authentication for all views by default. Individual views can opt out with the `@login_not_required` decorator.

```python
# settings.py
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.auth.middleware.LoginRequiredMiddleware",  # Add after AuthenticationMiddleware
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

# Unauthenticated users are redirected to LOGIN_URL (default: /accounts/login/)
LOGIN_URL = "/accounts/login/"
```

```python
from django.contrib.auth.decorators import login_not_required
from django.views import View

# Function-based view — opt out
@login_not_required
def public_homepage(request):
    return render(request, "home.html")

# Class-based view — opt out
class PublicAPIView(View):
    login_required = False

    def get(self, request):
        return JsonResponse({"status": "ok"})
```

### Async Auth Decorators

The `@login_required`, `@permission_required`, and `@user_passes_test` decorators now support async views.

```python
from django.contrib.auth.decorators import login_required, permission_required

# Works with both sync and async views in Django 5.1+
@login_required
async def my_async_view(request):
    data = await fetch_data()
    return JsonResponse(data)

@permission_required("myapp.view_report")
async def report_view(request):
    report = await generate_report()
    return render(request, "report.html", {"report": report})
```

### Async Session API

```python
# Session backends now have async equivalents
async def my_view(request):
    # Async session access
    value = await request.session.aget("key", default=None)
    keys = await request.session.akeys()
    await request.session.acycle_key()  # Rotate session key (security)
```

### PostgreSQL Connection Pooling

Connection pool support via psycopg3's `ConnectionPool`. Reduces connection overhead in high-throughput applications.

```python
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": "mydb",
        "USER": "myuser",
        "OPTIONS": {
            # Pool configuration via psycopg3 ConnectionPool options:
            "pool": {
                "min_size": 2,       # Minimum connections kept open
                "max_size": 10,      # Maximum connections allowed
                "timeout": 30,       # Seconds to wait for a connection
                "max_waiting": 5,    # Max requests waiting for a connection
                "max_lifetime": 300, # Max connection age in seconds
            },
            # Or use defaults:
            # "pool": True,
        },
    }
}
```

Important: Connection pooling requires psycopg3 (not psycopg2). Incompatible with `CONN_MAX_AGE` persistent connections — use one or the other.

Note on `CONN_HEALTH_CHECKS`: This setting (introduced in Django 4.1) works independently of the pool and checks whether a persistent connection is still alive before reusing it. With pooling enabled, the pool itself manages connection health.

### {% querystring %} Template Tag

New built-in template tag for modifying URL query parameters without rebuilding the entire query string.

```django
{# Pagination — preserve all existing params, just update 'page' #}
<a href="{% querystring page=page.next_page_number %}">Next</a>

{# Remove a parameter by setting to None #}
<a href="{% querystring search=None %}">Clear search</a>

{# Multiple parameters at once #}
<a href="{% querystring page=1 sort='name' direction='asc' %}">Sort by name</a>
```

### Admin Enhancements

```python
# list_display now supports __ lookups for related fields
@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    list_display = [
        "title",
        "author__first_name",  # Direct lookup — NEW in 5.1
        "author__last_name",
        "category__name",
    ]
```

Accessibility improvements: Admin filter uses `<nav>`, footer uses `<footer>`, fieldsets use native `<details>` and `<summary>` HTML elements.

### Other Notable 5.1 Features

- `F()` expression string slicing: `F("name")[:5]` on CharField/TextField
- `Model.refresh_from_db(from_queryset=...)` for customizing reload behavior
- `DomainNameValidator` including internationalized domain support
- `FileSystemStorage.allow_overwrite` attribute
- Test client `query_params` parameter: `self.client.get("/items/", query_params={"page": 2})`
- SQLite `init_command` and `transaction_mode` options
- PBKDF2 iteration count: 720,000 → 870,000

### Features Removed in 5.1 (from 4.2 deprecations)

- `DEFAULT_FILE_STORAGE` and `STATICFILES_STORAGE` settings
- `django.core.files.storage.get_storage_class()`
- `Meta.index_together` option
- `BaseUserManager.make_random_password()`
- `length_is` template filter
- `CICharField`, `CIEmailField`, `CITextField`, `CIText` PostgreSQL CI fields
- `SHA1PasswordHasher`, `UnsaltedSHA1PasswordHasher`, `UnsaltedMD5PasswordHasher`
- Positional arguments to `Signer` and `TimestampSigner`
- Encoded JSON string literals passed to `JSONField`
- `map_width` and `map_height` on `BaseGeometryWidget`

### Deprecations Introduced in 5.1 (removed in 6.0)

- `django.urls.register_converter()` when overriding existing converters
- `ModelAdmin.log_deletion()` / `LogEntryManager.log_action()` signatures
- `django.utils.itercompat.is_iterable()`
- `GeoIP2.coords()` / `GeoIP2.open()` methods
- Positional arguments to `Model.save()` / `Model.asave()`
- `OGRGeometry.coord_dim` setter
- `CheckConstraint.check` keyword argument
- `FieldCacheMixin.get_cache_name()`
- `FileSystemStorage.OS_OPEN_FLAGS` attribute

---

## Django 5.2 LTS

**Released:** April 2, 2025  
**EOL:** April 30, 2028  
**Python:** 3.10, 3.11, 3.12, 3.13, 3.14  
**Support:** Security fixes for 3 years

### Composite Primary Keys

Long-awaited feature: `CompositePrimaryKey` creates multi-column primary keys without the auto-generated `id` field.

```python
from django.db import models

class Release(models.Model):
    pk = models.CompositePrimaryKey("version", "name")
    version = models.IntegerField()
    name = models.CharField(max_length=20)

class UserRole(models.Model):
    pk = models.CompositePrimaryKey("user_id", "role_id")
    user_id = models.IntegerField()
    role_id = models.IntegerField()
    granted_at = models.DateTimeField(auto_now_add=True)
```

```python
# Usage with composite PKs:
release = Release.objects.get(pk=(5, "final"))
release = Release.objects.get(version=5, name="final")  # Equivalent

# The pk is a tuple:
print(release.pk)  # (5, 'final')

# Check if PK is set:
r = Release(version=5, name="beta")
print(r._is_pk_set())  # True — all PK fields are assigned
```

Limitations in 5.2:
- ForeignKey to models with composite PKs has limited support
- `QuerySet.raw()` supports composite PKs
- Some admin functionality limited with composite PKs

### Automatic Model Imports in Django Shell

`python manage.py shell` now auto-imports models from all installed apps.

```bash
$ python -Wall manage.py shell --verbosity=2
6 objects imported automatically, including:
  from django.contrib.admin.models import LogEntry
  from django.contrib.auth.models import Group, Permission, User
  from django.contrib.contenttypes.models import ContentType
  from myapp.models import Article, Author, Category

# Immediately available — no import needed:
>>> User.objects.count()
42
>>> Article.objects.filter(status="published").count()
17
```

Customizable via `AppConfig.get_models()` overrides.

### Async Auth Backend Improvements

Full async implementations added to `ModelBackend` and `RemoteUserBackend`, reducing sync-to-async context switching.

```python
# django.contrib.auth.backends now has async methods:
# ModelBackend.aauthenticate()
# ModelBackend.aget_user_permissions()
# ModelBackend.aget_group_permissions()
# ModelBackend.aget_all_permissions()
# ModelBackend.ahas_perm()
# ModelBackend.ahas_module_perms()
# RemoteUserBackend.aauthenticate()
# RemoteUserBackend.aconfigure_user()

# Custom async auth backend:
class MyAsyncBackend:
    async def aauthenticate(self, request, username=None, password=None):
        try:
            user = await User.objects.aget(username=username)
        except User.DoesNotExist:
            return None
        if await sync_to_async(user.check_password)(password):
            return user
        return None

    async def aget_user(self, user_id):
        try:
            return await User.objects.aget(pk=user_id)
        except User.DoesNotExist:
            return None
```

### Async UserManager Methods

```python
# UserManager now has async equivalents:
user = await User.objects.acreate_user(
    username="alice",
    email="alice@example.com",
    password="secret",
)

superuser = await User.objects.acreate_superuser(
    username="admin",
    email="admin@example.com",
    password="adminpass",
)

# Async permission checks:
has_perm = await user.ahas_perm("myapp.view_article")
has_perms = await user.ahas_perms(["myapp.view_article", "myapp.add_article"])
perms = await user.aget_all_permissions()
```

### New Form Widgets

```python
from django import forms

class ContactForm(forms.Form):
    phone = forms.CharField(widget=forms.TelInput())
    color = forms.CharField(widget=forms.ColorInput())
    search_query = forms.CharField(widget=forms.SearchInput())
```

Renders as `<input type="tel">`, `<input type="color">`, `<input type="search">` respectively.

### URL Reversing with Query and Fragment

```python
from django.urls import reverse

# Before: had to manually construct query strings
url = reverse("article-list") + "?page=2&sort=date#results"

# Django 5.2:
url = reverse(
    "article-list",
    query={"page": "2", "sort": "date"},
    fragment="results",
)
# Result: /articles/?page=2&sort=date#results
```

Also works with `reverse_lazy()`.

### BoundField Class Customization

```python
from django import forms

class AnnotatedBoundField(forms.BoundField):
    """Custom BoundField adding extra context for rendering."""

    @property
    def data_attributes(self):
        attrs = {}
        if self.help_text:
            attrs["data-has-help"] = "true"
        if self.errors:
            attrs["data-has-errors"] = "true"
        return attrs

class MyForm(forms.Form):
    bound_field_class = AnnotatedBoundField  # Form-level override
    name = forms.CharField()
    email = forms.EmailField()
```

Can also be set at project level via `BaseRenderer.bound_field_class` or per-field via `Field.bound_field_class`.

### AlterConstraint Migration Operation

New `AlterConstraint` operation modifies constraints without dropping and recreating the database constraint (where supported by the backend).

```python
# In a migration:
from django.db import migrations, models

class Migration(migrations.Migration):
    operations = [
        migrations.AlterConstraint(
            model_name="product",
            name="price_positive",
            constraint=models.CheckConstraint(
                condition=models.Q(price__gte=0),
                name="price_positive",
                violation_error_message="Price must be non-negative",
            ),
        ),
    ]
```

### Database Functions Added in 5.2

```python
from django.db.models.functions import JSONArray

# JSONArray: build a JSON array from field values
queryset = Author.objects.annotate(
    books_info=JSONArray("first_name", "last_name", "birth_year")
)
# Produces: ["Alice", "Smith", 1985]
```

### Testing Improvements

- `TransactionTestCase.setUpClass()` can now use fixture data
- Django assertion stack frames hidden in test output for cleaner failure messages

### Other Notable 5.2 Features

- `HttpResponse.text` property for string content
- `HttpRequest.get_preferred_type()` for content negotiation
- `QuerySet.values()` and `values_list()` now preserve specified expression order
- MySQL default character set changed from `utf8` to `utf8mb4`
- `CharField.max_length` no longer required on SQLite (SQLite has no enforced column size)
- PBKDF2 iteration count: 870,000 → 1,000,000
- `simple_block_tag()` decorator for template tags that accept content blocks
- `EmailMessage.attachments` now uses named tuples
- `body_contains()` method on email messages for checking content in alternatives

---

## Django 6.0

**Released:** December 3, 2025  
**EOL:** April 30, 2027  
**Python:** 3.12, 3.13, 3.14 (dropped 3.10 and 3.11)

### Background Tasks Framework (django.tasks)

Built-in framework for running code outside the request-response cycle. Replaces the common need for Celery or other third-party task queues for basic use cases.

```python
# myapp/tasks.py
from django.core.mail import send_mail
from django.tasks import task

@task
def send_welcome_email(user_id):
    from django.contrib.auth.models import User
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
    # Task arguments must be JSON-serializable
    pass
```

```python
# views.py
from myapp.tasks import send_welcome_email
from functools import partial
from django.db import transaction

def register(request):
    user = User.objects.create_user(...)

    # Enqueue: returns a TaskResult object
    result = send_welcome_email.enqueue(user_id=user.pk)

    # Ensure DB commit happens before task runs:
    with transaction.atomic():
        user.save()
        transaction.on_commit(
            partial(send_welcome_email.enqueue, user_id=user.pk)
        )

    # Async variant:
    # result = await send_welcome_email.aenqueue(user_id=user.pk)

    return redirect("dashboard")
```

```python
# settings.py — backend configuration
TASKS = {
    "default": {
        # Development: runs tasks immediately (synchronously)
        "BACKEND": "django.tasks.backends.immediate.ImmediateBackend",
        # Testing: stores results without executing
        # "BACKEND": "django.tasks.backends.dummy.DummyBackend",
        # Production: use a third-party backend (e.g., django-tasks-scheduler)
        # "BACKEND": "django_tasks_scheduler.backend.RedisBackend",
        # "OPTIONS": {"redis_url": "redis://localhost:6379/0"},
    }
}
```

Key limitations:
- Built-in backends (`ImmediateBackend`, `DummyBackend`) are for development/testing only
- Production deployments require third-party backends and separate worker processes
- Arguments and return values must be JSON-serializable
- Not a Celery replacement for complex workflows — designed for simple background jobs

### Content Security Policy (CSP) Support

Built-in CSP middleware and configuration, protecting against XSS and content injection attacks.

```python
# settings.py
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
    "font-src": [CSP.SELF],
    "connect-src": [CSP.SELF],
    "object-src": [CSP.NONE],
}

# Report-only mode (observe without blocking):
SECURE_CSP_REPORT_ONLY = {
    "default-src": [CSP.SELF],
    "script-src": [CSP.NONCE, CSP.STRICT_DYNAMIC],
    "object-src": [CSP.NONE],
    "report-uri": ["/csp-violations/"],
}
```

```django
{# In templates — access the nonce for inline scripts: #}
{% load csp %}
<script nonce="{{ request.csp_nonce }}">
    // Inline script allowed via nonce
    console.log("Page loaded");
</script>
```

### Template Partials

Named reusable fragments within a single template file.

```django
{# myapp/templates/product_list.html #}
{% load partials %}

{# Define a partial #}
{% partialdef product_card %}
  <div class="product-card">
    <h3>{{ product.name }}</h3>
    <p>{{ product.price }}</p>
    <a href="{{ product.get_absolute_url }}">View</a>
  </div>
{% endpartialdef %}

{# Use the partial #}
{% for product in products %}
  {% partial product_card %}
{% endfor %}

{# Reference from another view (renders partial in isolation): #}
{# template_name = "product_list.html#product_card" #}
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

### Modern Python Email API

Django 6.0 migrates email internals from legacy MIME classes to Python's modern `email.message.EmailMessage` API.

```python
from django.core.mail import EmailMessage

msg = EmailMessage(
    subject="Hello",
    body="Message body",
    from_email="sender@example.com",
    to=["recipient@example.com"],
)

# message() now returns email.message.EmailMessage (not MIMEMultipart):
raw_message = msg.message()
# isinstance(raw_message, email.message.EmailMessage)  # True

# All optional parameters now require keyword arguments (deprecation in 6.0):
# send_mail("Subject", "Body", "from@", ["to@"])  # OK — first 4 positional args
# send_mail("Subject", "Body", "from@", ["to@"], fail_silently=True)  # OK
```

### DEFAULT_AUTO_FIELD Changed to BigAutoField

**Breaking change:** New projects created with `startproject` now default to `BigAutoField` (64-bit integer) instead of `AutoField` (32-bit integer).

```python
# If you need the old 32-bit AutoField behavior (e.g., existing DB compatibility):
# settings.py
DEFAULT_AUTO_FIELD = "django.db.models.AutoField"

# Or per app:
# apps.py
class MyAppConfig(AppConfig):
    name = "myapp"
    default_auto_field = "django.db.models.AutoField"
```

Impact: Only affects newly created projects without explicit `DEFAULT_AUTO_FIELD`. Existing projects with the setting explicitly configured are unaffected.

### AsyncPaginator

```python
from django.core.paginator import AsyncPaginator

async def article_list(request):
    page_number = request.GET.get("page", 1)

    # AsyncPaginator — async equivalent of Paginator
    paginator = AsyncPaginator(
        Article.objects.filter(status="published").order_by("-created_at"),
        per_page=20,
    )

    page = await paginator.apage(page_number)

    return render(request, "articles/list.html", {
        "page_obj": page,
        "paginator": paginator,
    })
```

### StringAgg Now Available on All Databases

Previously PostgreSQL-only, `StringAgg` is now available across all database backends.

```python
from django.db.models import StringAgg, Value

# Works on PostgreSQL, MySQL, MariaDB, SQLite, Oracle in Django 6.0+
result = Author.objects.aggregate(
    all_names=StringAgg("last_name", delimiter=Value(", "))
)
print(result["all_names"])  # "Smith, Jones, Williams"
```

### GeneratedField Refresh After Save

Generated fields and expression-assigned fields now auto-refresh after `save()` using `RETURNING` SQL (PostgreSQL, SQLite, Oracle). No need for manual `refresh_from_db()`.

```python
class Product(models.Model):
    price = models.DecimalField(max_digits=10, decimal_places=2)
    quantity = models.IntegerField()
    total_value = models.GeneratedField(
        expression=F("price") * F("quantity"),
        output_field=models.DecimalField(max_digits=12, decimal_places=2),
        db_persist=True,
    )

product = Product(price=Decimal("9.99"), quantity=5)
product.save()
print(product.total_value)  # Decimal("49.95") — available immediately after save
# No need to call product.refresh_from_db()
```

### Other Notable 6.0 Features

```python
# forloop.length in templates:
{% for item in items %}
    {{ forloop.counter }} of {{ forloop.length }}
{% endfor %}

# Model.NotUpdated exception for forced updates with no rows affected:
try:
    obj.save(force_update=True)
except obj.NotUpdated:
    # Object no longer exists in database
    pass

# Shell auto-imports extended to include:
# settings, connection, reset_queries(), models, functions, timezone

# AnyValue aggregate (SQLite, MySQL, Oracle, PostgreSQL 16+):
from django.db.models import AnyValue
result = Product.objects.aggregate(sample_name=AnyValue("name"))
```

### Breaking Changes in 6.0

1. **Python 3.10 and 3.11 dropped** — minimum is now Python 3.12
2. **MariaDB 10.5 dropped** — minimum is now MariaDB 10.6
3. **DEFAULT_AUTO_FIELD defaults to BigAutoField** (see above)
4. **`as_sql()` must return tuple, not list:**
   ```python
   # Custom ORM expressions must return params as tuple:
   def as_sql(self, compiler, connection) -> tuple[str, tuple]:
       return "CUSTOM_FUNC(%s)", (self.value,)  # tuple, not list
   ```
5. **JSON serializer adds trailing newline** even without `indent`
6. **asgiref minimum:** 3.8.1 → 3.9.1
7. **Email API:** Legacy `MIMEBase` in `EmailMessage.attach()` deprecated
8. **No CASCADE on column drops** (PostgreSQL/schema editor)

### Features Removed in 6.0 (from 5.0 and 5.1 deprecation cycles)

From Django 5.0 deprecations:
- `DjangoDivFormRenderer` / `Jinja2DivFormRenderer` transitional renderers
- Positional `BaseConstraint` arguments
- `cx_Oracle` database driver support
- `ChoicesMeta` alias
- `format_html()` without args/kwargs
- `forms.URLField` default scheme (HTTP → HTTPS; now always HTTPS)
- `FORMS_URLFIELD_ASSUME_HTTPS` setting
- `get_joining_columns()` methods
- `ForeignObject.get_reverse_joining_columns()`
- `Prefetch.get_current_queryset()`
- `get_prefetch_queryset()` method

From Django 5.1 deprecations:
- `django.urls.register_converter()` overriding existing converters
- `ModelAdmin.log_deletion()` / `LogEntryManager.log_action()` old signatures
- `django.utils.itercompat.is_iterable()`
- `GeoIP2.coords()` / `GeoIP2.open()` methods
- Positional arguments to `Model.save()` / `Model.asave()`
- `OGRGeometry.coord_dim` setter
- `CheckConstraint.check` keyword argument
- `FieldCacheMixin.get_cache_name()`
- `FileSystemStorage.OS_OPEN_FLAGS`

### Deprecations Introduced in 6.0 (will be removed in 6.2/7.0)

- All optional `send_mail()`, `get_connection()`, `mail_admins()`, `mail_managers()` params require keyword arguments
- `EmailMessage` / `EmailMultiAlternatives` constructors: only first 4 positional args allowed going forward
- `django.contrib.postgres.aggregates.StringAgg` (use the cross-DB `django.db.models.StringAgg`)
- `OrderableAggMixin` (use `Aggregate.order_by`)
- `ADMINS` / `MANAGERS` as list of tuples (use email strings instead)
- `BadHeaderError` exception
- `SafeMIMEText` / `SafeMIMEMultipart` classes
- `forbid_multi_line_headers()` and `sanitize_address()` functions
- `urlize` / `urlizetrunc` HTTP default protocol (add `URLIZE_ASSUME_HTTPS=True` now)

---

## Async Support Progression

Django's async support has been built incrementally across multiple releases. Here is what each version adds:

### Django 3.0 (baseline)
- ASGI support added (`asgi.py` entry point)
- Async views: view functions can be `async def`
- Async middleware: middleware can be `async def`

### Django 3.1
- Async class-based views (CBVs support async `get()`, `post()`, etc.)
- Async middleware chain

### Django 4.1
- **ORM async interface**: all QuerySet methods gain `a`-prefixed async equivalents
  - `aget()`, `acreate()`, `aupdate()`, `adelete()`, `aexists()`, `acount()`, etc.
  - `async for` on QuerySets (partial — became full in 5.0)
  - Note: underlying DB calls still wrapped in `sync_to_async` internally

### Django 4.2
- **Async streaming responses**: `StreamingHttpResponse` accepts async iterators (ASGI)
- **Async model methods**: `asave()`, `adelete()`, `arefresh_from_db()`
- **Async related managers**: `aadd()`, `aclear()`, `aremove()`, `aset()`
- psycopg3 support (enables true async PostgreSQL connections at driver level)

### Django 5.0
- **Full `async for` on QuerySets**: `values()` and `values_list()` results also support `async for`
- **Async auth functions**: `aauthenticate()`, `alogin()`, `alogout()`, `aupdate_session_auth_hash()`
- **Async shortcuts**: `aget_object_or_404()`, `aget_list_or_404()`
- **Async signal dispatching**: `Signal.asend()`, `Signal.asend_robust()`

### Django 5.1
- **Auth decorators support async views**: `@login_required`, `@permission_required`, `@user_passes_test`
- **`LoginRequiredMiddleware`** works with async views
- **Async session API**: `aget()`, `akeys()`, `acycle_key()` on session backends
- **PostgreSQL connection pooling** (psycopg3 pool — reduces connection overhead for async workloads)
- `Model.arefresh_from_db(from_queryset=...)` customization

### Django 5.2
- **Async auth backends**: `ModelBackend.aauthenticate()`, permission check async methods
- **Async UserManager**: `acreate_user()`, `acreate_superuser()`, `aget_by_natural_key()`
- **Async User permission methods**: `ahas_perm()`, `aget_all_permissions()`, etc.

### Django 6.0
- **AsyncPaginator**: `AsyncPaginator` and `AsyncPage` classes
- **Async task enqueueing**: `task.aenqueue()` for background task framework
- **`RETURNING` clause**: generated fields refresh without extra DB round-trip after save

### Async Usage Patterns by Version

```python
# Pattern 1: Fully async view with async ORM (5.0+)
async def article_list(request):
    articles = []
    async for article in Article.objects.filter(
        status="published"
    ).select_related("author"):
        articles.append(article)
    return render(request, "list.html", {"articles": articles})

# Pattern 2: Connection pool + async (5.1+ with psycopg3)
# Configure pool in DATABASES.OPTIONS.pool
# Django handles pool management automatically

# Pattern 3: Background task from async view (6.0+)
async def submit_form(request):
    form = SubmissionForm(request.POST)
    if await sync_to_async(form.is_valid)():
        submission = await Submission.objects.acreate(**form.cleaned_data)
        await process_submission.aenqueue(submission_id=submission.pk)
        return redirect("success")
```

---

## Migration Path: 4.2 LTS → 5.2 LTS → 6.0

### Step 1: Audit Before Migrating from 4.2 to 5.2

The recommended enterprise path skips 5.0 and 5.1 (both now EOL) and moves directly from 4.2 LTS to 5.2 LTS.

```bash
# Check for deprecation warnings — run with -Wall to see all warnings
python -Wall manage.py runserver
python -Wall manage.py test

# Or in settings for development:
# import warnings
# warnings.filterwarnings("error", category=DeprecationWarning)
```

### Step 2: Fix 4.2 Deprecations Before Upgrading

Items deprecated in 4.2 that are **removed in 5.1** (which 5.2 builds on):

```python
# 1. Replace DEFAULT_FILE_STORAGE / STATICFILES_STORAGE with STORAGES:
# BEFORE:
DEFAULT_FILE_STORAGE = "storages.backends.s3boto3.S3Boto3Storage"
STATICFILES_STORAGE = "django.contrib.staticfiles.storage.ManifestStaticFilesStorage"

# AFTER:
STORAGES = {
    "default": {"BACKEND": "storages.backends.s3boto3.S3Boto3Storage"},
    "staticfiles": {
        "BACKEND": "django.contrib.staticfiles.storage.ManifestStaticFilesStorage"
    },
}

# 2. Replace index_together with indexes:
class Meta:
    # BEFORE:
    # index_together = [("user", "created_at")]
    # AFTER:
    indexes = [models.Index(fields=["user", "created_at"])]

# 3. Replace PostgreSQL CI fields:
# BEFORE:
# from django.contrib.postgres.fields import CICharField
# name = CICharField(max_length=100)
# AFTER:
name = models.CharField(max_length=100, db_collation="case_insensitive")
```

### Step 3: Handle 5.0 Changes (also in 5.2)

```python
# 1. FORM_RENDERER — div-based is now default, remove DjangoDivFormRenderer:
# BEFORE (4.2 opt-in):
FORM_RENDERER = "django.forms.renderers.DjangoDivFormRenderer"
# AFTER (5.2 — div is default, this setting line can be removed):
# (no setting needed — div is the default)

# 2. Update choices usage to use enum directly:
# BEFORE:
status = models.CharField(choices=Status.choices)
# AFTER:
status = models.CharField(choices=Status)

# 3. URL field now defaults to HTTPS:
# Add to settings if you have tests expecting http:// URLs from URLField:
FORMS_URLFIELD_ASSUME_HTTPS = True  # Should have been True already
```

### Step 4: Handle Features Removed in 6.0

```python
# 1. Remove all cx_Oracle usage — migrate to python-oracledb:
# settings.py
DATABASES = {
    "default": {
        # BEFORE: "ENGINE": "django.db.backends.oracle"  # used cx_Oracle
        "ENGINE": "django.db.backends.oracle",  # now uses python-oracledb
        # No change to ENGINE name, but install python-oracledb instead of cx_Oracle
    }
}

# 2. Ensure custom as_sql() returns tuple, not list:
class MyExpression(Func):
    def as_sql(self, compiler, connection):
        # BEFORE:
        # return "MY_FUNC(%s)", [self.value]  # list
        # AFTER:
        return "MY_FUNC(%s)", (self.value,)  # tuple

# 3. Update Model.save() calls that use positional arguments:
# BEFORE:
instance.save(False, False, None, None)
# AFTER:
instance.save(
    force_insert=False,
    force_update=False,
    using=None,
    update_fields=None,
)
```

### Step 5: Upgrade Python Version

```
4.2 LTS: Python 3.8 – 3.12
5.2 LTS: Python 3.10 – 3.14  ← must be on 3.10+
6.0:     Python 3.12 – 3.14  ← must be on 3.12+
```

Recommended upgrade sequence: Python 3.10 → 3.12 → 3.13

### Step 6: Database Compatibility

| DB | 4.2 Minimum | 5.2 Minimum | 6.0 Minimum |
|----|-------------|-------------|-------------|
| PostgreSQL | 12 | 14 | 14 |
| MariaDB | 10.4 | 10.5 | 10.6 |
| MySQL | 8.0 | 8.0 | 8.0 |
| Oracle | 19c | 19c | 19c |
| SQLite | 3.27 | 3.31 | 3.31 |

### Step 7: Testing Strategy

```bash
# 1. Install new Django version in a virtual environment
pip install "django>=5.2,<6.0"

# 2. Run migrations check
python manage.py migrate --check

# 3. Run full test suite with deprecation warnings as errors
python -W error::DeprecationWarning -m pytest

# 4. Run with 6.0 before upgrading:
pip install "django>=6.0,<7.0"
python -W error::DeprecationWarning -m pytest
```

---

## Deprecation Timeline Summary

| Feature | Deprecated In | Removed In |
|---------|--------------|------------|
| `DEFAULT_FILE_STORAGE` | 4.2 | 5.1 |
| `STATICFILES_STORAGE` | 4.2 | 5.1 |
| `Meta.index_together` | 4.2 | 5.1 |
| `CICharField`, `CIEmailField`, `CITextField` | 4.2 | 5.1 |
| SHA1/MD5 password hashers | 4.2 | 5.1 |
| `length_is` template filter | 4.2 | 5.1 |
| `BaseUserManager.make_random_password()` | 4.2 | 5.1 |
| `DjangoDivFormRenderer`, `Jinja2DivFormRenderer` | 5.0 | 6.0 |
| `cx_Oracle` support | 5.0 | 6.0 |
| `ChoicesMeta` alias | 5.0 | 6.0 |
| `FORMS_URLFIELD_ASSUME_HTTPS` setting | 5.0 | 6.0 |
| `get_joining_columns()` | 5.0 | 6.0 |
| `Prefetch.get_current_queryset()` | 5.0 | 6.0 |
| Positional `Model.save()` args | 5.1 | 6.0 |
| `CheckConstraint.check` kwarg | 5.1 | 6.0 |
| `FieldCacheMixin.get_cache_name()` | 5.1 | 6.0 |
| `GeoIP2.coords()`, `GeoIP2.open()` | 5.1 | 6.0 |
| `FileSystemStorage.OS_OPEN_FLAGS` | 5.1 | 6.0 |
| `django.utils.itercompat.is_iterable()` | 5.1 | 6.0 |
| `postgres.StringAgg` (use db-agnostic version) | 6.0 | 6.2/7.0 |
| `OrderableAggMixin` | 6.0 | 6.2/7.0 |
| Email positional params | 6.0 | 6.2/7.0 |
| `BadHeaderError` | 6.0 | 6.2/7.0 |
| `SafeMIMEText`, `SafeMIMEMultipart` | 6.0 | 6.2/7.0 |
| `ADMINS`/`MANAGERS` as tuples | 6.0 | 6.2/7.0 |

---

## Quick Feature Reference

| Feature | Version Introduced |
|---------|-------------------|
| ASGI support | 3.0 |
| Async views | 3.1 |
| Async ORM interface (`aget`, `acreate`, etc.) | 4.1 |
| psycopg3 support | 4.2 |
| `db_comment`, `db_table_comment` | 4.2 |
| `STORAGES` setting | 4.2 |
| Async `asave()`, `adelete()`, `arefresh_from_db()` | 4.2 |
| Async streaming responses (ASGI) | 4.2 |
| `GeneratedField` | 5.0 |
| `db_default` | 5.0 |
| Facet filters in admin | 5.0 |
| `choices=Enum` (no `.choices`) | 5.0 |
| `Signal.asend()`, `Signal.asend_robust()` | 5.0 |
| `aauthenticate()`, `alogin()`, `alogout()` | 5.0 |
| `aget_object_or_404()` | 5.0 |
| `async for` on all QuerySets | 5.0 |
| `LoginRequiredMiddleware` | 5.1 |
| `@login_required` on async views | 5.1 |
| PostgreSQL connection pool | 5.1 |
| `{% querystring %}` template tag | 5.1 |
| Async session API (`aget`, `akeys`, etc.) | 5.1 |
| `CompositePrimaryKey` | 5.2 |
| Shell auto-imports | 5.2 |
| `ModelBackend.aauthenticate()` | 5.2 |
| `TelInput`, `ColorInput`, `SearchInput` widgets | 5.2 |
| `reverse()` with `query` and `fragment` | 5.2 |
| `AlterConstraint` migration op | 5.2 |
| `JSONArray` function | 5.2 |
| Background tasks (`django.tasks`) | 6.0 |
| CSP middleware and `SECURE_CSP` | 6.0 |
| Template partials (`{% partialdef %}`) | 6.0 |
| Modern Python email API | 6.0 |
| `AsyncPaginator` / `AsyncPage` | 6.0 |
| `DEFAULT_AUTO_FIELD = BigAutoField` (default) | 6.0 |
| `StringAgg` on all databases | 6.0 |
| `GeneratedField` refresh after `save()` | 6.0 |
| `forloop.length` | 6.0 |
| `Model.NotUpdated` exception | 6.0 |
