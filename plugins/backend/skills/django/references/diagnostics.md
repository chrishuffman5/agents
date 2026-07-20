# Django Diagnostics Reference

## Common Errors

### ImproperlyConfigured

**Cause:** Django cannot find a required setting, app, or module.

```
django.core.exceptions.ImproperlyConfigured: Requested setting DEFAULT_INDEX_TABLESPACE, but settings are not configured.
```

**Fix:** Ensure `DJANGO_SETTINGS_MODULE` is set:

```bash
export DJANGO_SETTINGS_MODULE=config.settings.development
```

Or in `manage.py` / `wsgi.py`:

```python
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.development")
```

**Common variants:**
- "Application labels aren't unique" -- duplicate app in `INSTALLED_APPS`
- "No installed app with label 'X'" -- app not in `INSTALLED_APPS` or wrong `AppConfig.name`
- "AUTH_USER_MODEL refers to model 'X' that has not been installed" -- custom user app not in `INSTALLED_APPS`

### FieldError

```
django.core.exceptions.FieldError: Cannot resolve keyword 'author_name' into field
```

**Fix:** Check the actual field name. Use `__` for related field lookups:

```python
# Wrong:
Article.objects.filter(author_name="Alice")

# Correct:
Article.objects.filter(author__name="Alice")
```

### FieldDoesNotExist

**Cause:** Referencing a field that does not exist on the model.

**Fix:** Check `model._meta.get_fields()` for available fields. Common when using `values()`, `only()`, or `defer()` with misspelled field names.

### Migration Conflicts

```
django.db.migrations.exceptions.InconsistentMigrationHistory
```

**Causes and fixes:**

1. **Two developers created migrations independently:**
   ```bash
   python manage.py makemigrations --merge
   ```

2. **Squashed migration applied out of order:**
   ```bash
   python manage.py showmigrations  # inspect state
   python manage.py migrate myapp 0005  # migrate to specific point
   ```

3. **Migration references deleted model:**
   Edit migration file to fix dependency or use `SeparateDatabaseAndState`.

4. **Fake a migration when DB is already correct:**
   ```bash
   python manage.py migrate myapp 0003 --fake
   ```

### Circular Imports

**Symptom:** `ImportError` or `AppRegistryNotReady` at startup.

**Common patterns and fixes:**

```python
# Problem: models.py imports from views.py which imports from models.py
# Fix: Use string references for ForeignKey:
author = models.ForeignKey("users.User", on_delete=models.CASCADE)

# Problem: Signal imports at module level
# Fix: Import in AppConfig.ready():
class MyAppConfig(AppConfig):
    def ready(self):
        import myapp.signals  # noqa: F401

# Problem: Importing models before apps are loaded
# Fix: Use lazy imports or django.apps.apps.get_model():
from django.apps import apps
User = apps.get_model("auth", "User")
```

### DoesNotExist / MultipleObjectsReturned

```python
# DoesNotExist -- .get() found no rows
try:
    article = Article.objects.get(slug="nonexistent")
except Article.DoesNotExist:
    raise Http404("Article not found")

# Or use the shortcut:
article = get_object_or_404(Article, slug="nonexistent")

# MultipleObjectsReturned -- .get() found more than one row
# Fix: Add unique constraint or use .filter().first()
```

### OperationalError -- Database Issues

```
django.db.utils.OperationalError: connection to server at "localhost" (127.0.0.1), port 5432 failed
```

**Checklist:**
1. Is the database server running?
2. Are credentials correct in `DATABASES` setting?
3. Does the database exist? (`createdb myapp`)
4. For Docker: is the db service healthy before web starts?
5. For connection pooling: is PgBouncer running?

### IntegrityError

```
django.db.utils.IntegrityError: duplicate key value violates unique constraint
```

**Fix:** Use `get_or_create()`, `update_or_create()`, or handle the exception:

```python
from django.db import IntegrityError

try:
    Article.objects.create(slug="existing-slug", ...)
except IntegrityError:
    # Handle duplicate
    pass

# Or:
article, created = Article.objects.get_or_create(
    slug="my-slug",
    defaults={"title": "My Article", "body": "Content"},
)
```

### DisallowedHost

```
django.core.exceptions.DisallowedHost: Invalid HTTP_HOST header: 'evil.com'
```

**Fix:** Add the hostname to `ALLOWED_HOSTS`:

```python
ALLOWED_HOSTS = ["example.com", "www.example.com", "localhost"]
```

### CSRF Verification Failed

**Causes:**
1. Missing `{% csrf_token %}` in form template
2. AJAX request missing `X-CSRFToken` header
3. `CSRF_COOKIE_DOMAIN` mismatch
4. Cross-origin request without proper CORS + CSRF setup

**Fix for AJAX:**

```javascript
fetch("/api/endpoint/", {
    method: "POST",
    headers: {"X-CSRFToken": getCookie("csrftoken")},
    body: JSON.stringify(data),
});
```

**Fix for DRF:** Use token/JWT auth instead of session auth for API clients.

---

## ORM Debugging

### django-debug-toolbar

```python
# pip install django-debug-toolbar

# settings/development.py
INSTALLED_APPS = [..., "debug_toolbar"]
MIDDLEWARE = ["debug_toolbar.middleware.DebugToolbarMiddleware", *MIDDLEWARE]
INTERNAL_IPS = ["127.0.0.1"]

# urls.py
if settings.DEBUG:
    import debug_toolbar
    urlpatterns = [path("__debug__/", include(debug_toolbar.urls))] + urlpatterns
```

Key panels: SQL queries (count, time, duplicates), cache hits, template rendering, signals.

### Query Logging

```python
# settings/development.py -- log all SQL queries
LOGGING = {
    "version": 1,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "loggers": {
        "django.db.backends": {
            "level": "DEBUG",
            "handlers": ["console"],
        },
    },
}
```

### Inspecting QuerySet SQL

```python
# Print the SQL without executing:
qs = Article.objects.filter(status="published").select_related("author")
print(qs.query)

# With EXPLAIN ANALYZE (PostgreSQL):
print(qs.explain(analyze=True))

# Or via raw cursor:
from django.db import connection
with connection.cursor() as cursor:
    cursor.execute("EXPLAIN ANALYZE " + str(qs.query))
    for row in cursor.fetchall():
        print(row[0])
```

### Counting Queries in Tests

```python
from django.test.utils import override_settings

class QueryCountTest(TestCase):
    def test_article_list_query_count(self):
        ArticleFactory.create_batch(20)
        with self.assertNumQueries(2):  # 1 for articles + 1 for prefetch
            list(Article.objects.prefetch_related("tags"))
```

### Detecting N+1 Queries

**Symptoms:** Query count scales linearly with result set size. The debug toolbar SQL panel shows many nearly-identical queries.

**Detection pattern:**

```python
# Bad -- N+1:
for article in Article.objects.all():
    print(article.author.name)  # SELECT on auth_user for EACH article

# Good -- 1 query:
for article in Article.objects.select_related("author"):
    print(article.author.name)
```

**Automated detection with nplusone:**

```python
# pip install nplusone
MIDDLEWARE = [..., "nplusone.ext.django.NPlusOneMiddleware"]
NPLUSONE_RAISE = True  # raise exception on N+1 (dev only)
```

---

## Performance Profiling

### Django Silk

```python
# pip install django-silk
INSTALLED_APPS = [..., "silk"]
MIDDLEWARE = [..., "silk.middleware.SilkyMiddleware"]

# urls.py
urlpatterns = [path("silk/", include("silk.urls", namespace="silk")), ...]
```

Silk records request/response data, SQL queries, and profiling data. Access at `/silk/`.

### cProfile Integration

```python
# Profile a management command:
python -m cProfile -o output.prof manage.py my_command

# Analyze:
import pstats
stats = pstats.Stats("output.prof")
stats.sort_stats("cumulative")
stats.print_stats(20)
```

### Slow Query Detection

```python
# Log queries over threshold:
LOGGING = {
    "version": 1,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "loggers": {
        "django.db.backends": {
            "level": "DEBUG",
            "handlers": ["console"],
        },
    },
}

# In production, use database-level slow query logging:
# PostgreSQL: log_min_duration_statement = 200  (ms)
```

### Memory Profiling

```bash
# pip install memory-profiler
python -m memory_profiler manage.py my_command
```

For long-running processes (Celery workers, management commands), watch for:
- Uncollected QuerySets holding large result sets
- Growing `connection.queries` list (disable `DEBUG` in production)
- Signals accumulating listeners without cleanup

---

## Async Pitfalls

### ORM in Async Views

The Django ORM is synchronous internally. In async views, wrap ORM calls with `sync_to_async`:

```python
from asgiref.sync import sync_to_async

async def async_view(request):
    # Wrong -- will raise SynchronousOnlyOperation:
    # articles = list(Article.objects.all())

    # Correct option 1 -- sync_to_async wrapper:
    articles = await sync_to_async(lambda: list(Article.objects.all()))()

    # Correct option 2 -- async ORM methods (Django 4.1+):
    articles = await Article.objects.filter(status="published").alist()

    # Correct option 3 -- async for (Django 5.0+):
    articles = []
    async for article in Article.objects.filter(status="published"):
        articles.append(article)

    return JsonResponse({"count": len(articles)})
```

### SynchronousOnlyOperation

```
django.core.exceptions.SynchronousOnlyOperation: You cannot call this from an async context - use a thread or sync_to_async.
```

**Cause:** Calling synchronous code (ORM, cache, file I/O) from an async context without wrapping.

**Fix:** Use `sync_to_async` or the `a`-prefixed async ORM methods.

### Mixed Sync/Async Middleware

If you have both sync and async views, middleware must handle both. Django auto-wraps, but there is overhead. Set `async_capable = True` and `sync_capable = True` for dual-mode middleware.

### Thread Safety with sync_to_async

`sync_to_async` runs code in a thread pool. Be careful with:
- Thread-local storage (use `contextvars` instead)
- Connection state (each thread gets its own DB connection)
- `thread_sensitive=True` (default) runs all calls in the same thread -- safe but serialized

```python
# For independent operations, use thread_sensitive=False for parallelism:
result = await sync_to_async(heavy_computation, thread_sensitive=False)()
```

### ASGI Server Considerations

- Use Uvicorn or Daphne for ASGI deployment
- `DEBUG = True` with ASGI leaks memory (connection.queries accumulates)
- Async views do not speed up CPU-bound work -- they help with I/O-bound operations
- Connection pooling is critical with ASGI (many concurrent connections)

---

## Common Configuration Issues

### Middleware Ordering Bugs

**CORS failing:** `CorsMiddleware` must come before `CommonMiddleware`.

**Auth not working:** Custom middleware depending on `request.user` must come after `AuthenticationMiddleware`.

**Static files 404 in production:** WhiteNoise must come right after `SecurityMiddleware`.

### Database Connection Issues

**"Too many connections":**
- Use connection pooling (PgBouncer or Django 5.1+ built-in pool)
- Set `CONN_MAX_AGE` for persistent connections
- Never set `CONN_MAX_AGE = None` (infinite) without a connection pooler

**"Connection already closed":**
- Stale persistent connections. Enable `CONN_HEALTH_CHECKS = True` (Django 4.1+)

### Static Files Not Found

```bash
# Verify collectstatic ran:
python manage.py collectstatic --noinput

# Check STATIC_ROOT:
python -c "from django.conf import settings; print(settings.STATIC_ROOT)"

# Check STATICFILES_DIRS does not include STATIC_ROOT:
# STATIC_ROOT is the destination, STATICFILES_DIRS are sources
```

### Template Not Found

```
django.template.exceptions.TemplateDoesNotExist: blog/article_list.html
```

**Checklist:**
1. `APP_DIRS = True` in `TEMPLATES` setting
2. Template is in `<app>/templates/<app>/` (with app namespace)
3. App is in `INSTALLED_APPS`
4. Or template is in a directory listed in `TEMPLATES[0]["DIRS"]`

### Migrations Out of Sync

```bash
# Check for ungenerated migrations:
python manage.py makemigrations --check --dry-run

# Recreate migrations from scratch (nuclear option, dev only):
# 1. Delete all migration files except __init__.py
# 2. python manage.py makemigrations
# 3. python manage.py migrate --fake-initial
```
