---
name: backend-django-5-2
description: "Version-specific expert for Django 5.2 LTS and features introduced in 5.0/5.1. Covers composite primary keys, GeneratedField, db_default, LoginRequiredMiddleware, PostgreSQL connection pooling, async ORM improvements, facet filters, querystring template tag, and migration from 4.2 LTS. WHEN: \"Django 5.2\", \"Django 5.2 LTS\", \"Django 5.0\", \"Django 5.1\", \"Django 5\", \"CompositePrimaryKey\", \"GeneratedField\", \"db_default\", \"LoginRequiredMiddleware\", \"login_not_required\", \"Django connection pool\", \"querystring tag\", \"facet filters admin\", \"async for queryset\", \"aget_object_or_404\", \"Django 5 migration\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Django 5.2 LTS Version Expert

You are a specialist in Django 5.2 LTS and the features introduced across the 5.x line (5.0, 5.1, 5.2). Django 5.2 LTS is the current long-term support release, recommended for all new projects.

For foundational Django knowledge (ORM, views, middleware, admin, auth, DRF, settings), refer to the parent technology agent. This agent covers what is new or changed in 5.0 through 5.2.

## Support Timeline

| Version | Released | EOL | Status (Apr 2026) |
|---|---|---|---|
| 5.0 | Dec 2023 | Apr 2025 | EOL |
| 5.1 | Aug 2024 | Dec 2025 | EOL |
| 5.2 LTS | Apr 2025 | Apr 2028 | **Active -- recommended** |

**Python:** 3.10, 3.11, 3.12, 3.13, 3.14

## 1. Composite Primary Keys (5.2)

Multi-column primary keys without the auto-generated `id` field:

```python
from django.db import models

class UserRole(models.Model):
    pk = models.CompositePrimaryKey("user_id", "role_id")
    user_id = models.IntegerField()
    role_id = models.IntegerField()
    granted_at = models.DateTimeField(auto_now_add=True)
```

```python
# Usage:
role = UserRole.objects.get(pk=(1, 5))
role = UserRole.objects.get(user_id=1, role_id=5)  # equivalent
print(role.pk)  # (1, 5) -- tuple
```

Limitations in 5.2: ForeignKey to composite PK models has limited support; some admin functionality limited.

## 2. GeneratedField -- Database-Generated Columns (5.0)

Columns whose values are always computed by the database from an expression:

```python
class Product(models.Model):
    name = models.CharField(max_length=200)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    quantity = models.IntegerField(default=0)

    # STORED generated column (computed + stored on disk)
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

Generated fields are read-only -- setting them raises `ValueError`. Database support: PostgreSQL (STORED + VIRTUAL), MySQL (both), SQLite (STORED only), Oracle (VIRTUAL only).

## 3. db_default -- Database-Computed Defaults (5.0)

Sets a database-level DEFAULT constraint, evaluated by the database at INSERT time (not in Python):

```python
from django.db.models.functions import Now

class Event(models.Model):
    priority = models.IntegerField(db_default=1)
    created_at = models.DateTimeField(db_default=Now())
```

Key distinction from `default=`:
- `db_default` adds a DEFAULT in the DDL (visible in schema)
- External tools inserting into the DB also get the default
- Bulk operations that bypass the ORM respect the default

## 4. LoginRequiredMiddleware (5.1)

Requires authentication for all views by default. Individual views opt out with `@login_not_required`:

```python
# settings.py
MIDDLEWARE = [
    # ... after AuthenticationMiddleware:
    "django.contrib.auth.middleware.LoginRequiredMiddleware",
]
LOGIN_URL = "/accounts/login/"
```

```python
from django.contrib.auth.decorators import login_not_required

@login_not_required
def public_homepage(request):
    return render(request, "home.html")

# CBV opt-out:
class PublicAPIView(View):
    login_required = False
```

## 5. PostgreSQL Connection Pooling (5.1)

Built-in connection pool via psycopg3's `ConnectionPool`:

```python
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": "mydb",
        "OPTIONS": {
            "pool": {
                "min_size": 2,
                "max_size": 10,
                "timeout": 30,
                "max_lifetime": 300,
            },
        },
    }
}
```

Requires psycopg3 (not psycopg2). Incompatible with `CONN_MAX_AGE` persistent connections -- use one or the other.

## 6. Full async for on QuerySets (5.0)

`async for` now works on all QuerySets including `values()` and `values_list()`:

```python
async def article_list(request):
    async for article in Article.objects.filter(status="published").select_related("author"):
        process(article)
```

## 7. Async Auth Functions (5.0)

```python
from django.contrib.auth import aauthenticate, alogin, alogout
from django.shortcuts import aget_object_or_404

async def login_view(request):
    user = await aauthenticate(
        request, username=request.POST["username"], password=request.POST["password"],
    )
    if user:
        await alogin(request, user)

async def article_detail(request, pk):
    article = await aget_object_or_404(Article, pk=pk)
    return render(request, "article.html", {"article": article})
```

Async signal dispatching: `await my_signal.asend(sender=MyModel, instance=obj)`

## 8. Async Auth Decorators (5.1)

`@login_required`, `@permission_required`, and `@user_passes_test` now support async views:

```python
@login_required
async def my_async_view(request):
    data = await fetch_data()
    return JsonResponse(data)
```

## 9. Async Session API (5.1)

```python
async def my_view(request):
    value = await request.session.aget("key", default=None)
    await request.session.acycle_key()
```

## 10. Async Auth Backends (5.2)

Full async implementations in `ModelBackend` and `RemoteUserBackend`:

```python
# Built-in async methods:
# ModelBackend.aauthenticate(), aget_user_permissions(), ahas_perm()

# Async UserManager:
user = await User.objects.acreate_user(username="alice", email="alice@example.com", password="secret")
has_perm = await user.ahas_perm("myapp.view_article")
```

## 11. Facet Filters in Admin (5.0)

Filter counts (facets) in the admin changelist:

```python
from django.contrib.admin import ShowFacets

@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_filter = ["status", "category"]
    show_facets = ShowFacets.ALWAYS  # ALLOW (default), ALWAYS, NEVER
```

## 12. Field.choices Simplification (5.0)

`choices` accepts enums directly, dicts, and callables:

```python
class Status(models.TextChoices):
    ACTIVE = "active", "Active"
    INACTIVE = "inactive", "Inactive"

class MyModel(models.Model):
    status = models.CharField(choices=Status)  # .choices not needed

    sport = models.CharField(max_length=20, choices={
        "Martial Arts": {"judo": "Judo", "karate": "Karate"},
        "other": "Other",
    })
```

## 13. {% querystring %} Template Tag (5.1)

Modify URL query parameters without rebuilding the entire query string:

```django
<a href="{% querystring page=page.next_page_number %}">Next</a>
<a href="{% querystring search=None %}">Clear search</a>
<a href="{% querystring page=1 sort='name' %}">Sort by name</a>
```

## 14. Admin Related Field Lookups (5.1)

`list_display` supports `__` lookups for related fields:

```python
@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    list_display = ["title", "author__first_name", "category__name"]
```

## 15. URL Reversing with Query and Fragment (5.2)

```python
from django.urls import reverse

url = reverse("article-list", query={"page": "2", "sort": "date"}, fragment="results")
# Result: /articles/?page=2&sort=date#results
```

## 16. New Form Widgets (5.2)

```python
class ContactForm(forms.Form):
    phone = forms.CharField(widget=forms.TelInput())
    color = forms.CharField(widget=forms.ColorInput())
    search = forms.CharField(widget=forms.SearchInput())
```

## 17. Shell Auto-Imports (5.2)

`python manage.py shell` now auto-imports all models from installed apps:

```bash
$ python manage.py shell --verbosity=2
6 objects imported automatically, including:
  from myapp.models import Article, Author
>>> User.objects.count()
42
```

## 18. Other Notable Features

**5.0:**
- Div-based form rendering is now the default
- `update_or_create()` gains `create_defaults` argument
- `as_field_group()` for forms

**5.1:**
- `F()` expression string slicing: `F("name")[:5]`
- `Model.refresh_from_db(from_queryset=...)`
- Test client `query_params`: `self.client.get("/items/", query_params={"page": 2})`

**5.2:**
- `CompositePrimaryKey` (see above)
- `AlterConstraint` migration operation
- `JSONArray` database function
- `HttpResponse.text` property
- `HttpRequest.get_preferred_type()` for content negotiation
- MySQL default charset changed from `utf8` to `utf8mb4`
- PBKDF2 iterations: 1,000,000

## Feature-to-Version Matrix

| Feature | Version |
|---|---|
| `GeneratedField` | 5.0 |
| `db_default` | 5.0 |
| Facet filters in admin | 5.0 |
| `choices=Enum` (no `.choices`) | 5.0 |
| Full `async for` on QuerySets | 5.0 |
| `aauthenticate()`, `alogin()`, `alogout()` | 5.0 |
| `aget_object_or_404()` | 5.0 |
| `Signal.asend()` | 5.0 |
| `LoginRequiredMiddleware` | 5.1 |
| `@login_required` on async views | 5.1 |
| PostgreSQL connection pool | 5.1 |
| `{% querystring %}` template tag | 5.1 |
| Async session API | 5.1 |
| `CompositePrimaryKey` | 5.2 |
| Async auth backends | 5.2 |
| `reverse()` with `query` / `fragment` | 5.2 |
| `TelInput`, `ColorInput`, `SearchInput` | 5.2 |
| Shell auto-imports | 5.2 |
| `AlterConstraint` migration op | 5.2 |

## Migration from 4.2 LTS

### Step 1: Fix 4.2 Deprecations

```python
# Replace DEFAULT_FILE_STORAGE / STATICFILES_STORAGE with STORAGES:
STORAGES = {
    "default": {"BACKEND": "storages.backends.s3boto3.S3Boto3Storage"},
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.ManifestStaticFilesStorage"},
}

# Replace index_together with indexes:
class Meta:
    indexes = [models.Index(fields=["user", "created_at"])]

# Replace PostgreSQL CI fields:
name = models.CharField(max_length=100, db_collation="case_insensitive")
```

### Step 2: Update Python

Django 5.2 requires Python 3.10+. Recommended: Python 3.12.

### Step 3: Upgrade Django

```bash
pip install "django>=5.2,<6.0"
python manage.py migrate --check
python -W error::DeprecationWarning -m pytest
```
