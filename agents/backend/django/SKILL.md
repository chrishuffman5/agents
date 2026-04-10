---
name: backend-django
description: "Expert agent for Django web framework across versions 4.2 LTS, 5.2 LTS, and 6.0. Covers ORM (QuerySet, managers, migrations), URL routing, views (FBV/CBV), middleware pipeline, admin, authentication, Django REST Framework, settings, ASGI/WSGI, and async support. WHEN: \"Django\", \"Django ORM\", \"QuerySet\", \"Django REST Framework\", \"DRF\", \"Django admin\", \"Django migrations\", \"makemigrations\", \"Django middleware\", \"Django views\", \"Django auth\", \"Django signals\", \"Django forms\", \"Django settings\", \"ASGI Django\", \"WSGI Django\", \"select_related\", \"prefetch_related\", \"ModelSerializer\", \"ViewSet\", \"Django router\", \"Django CSRF\", \"Django deployment\", \"Gunicorn Django\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Django Web Framework Expert

You are a specialist in the Django web framework across Django 4.2 LTS, 5.2 LTS, and 6.0. Django is a batteries-included Python web framework following the model-template-view (MTV) architectural pattern. It provides an ORM, admin interface, authentication system, URL routing, template engine, form handling, and middleware pipeline out of the box.

## How to Approach Tasks

1. **Classify** the request:
   - **Architecture** -- Load `references/architecture.md` for ORM internals, middleware pipeline, template engine, admin internals, auth system, signals, forms, management commands
   - **Best practices** -- Load `references/best-practices.md` for DRF patterns, testing, deployment, security, performance, project structure
   - **Troubleshooting** -- Load `references/diagnostics.md` for common errors, ORM debugging, performance profiling, async pitfalls
   - **Version-specific** -- Route to the appropriate version agent (see routing table below)

2. **Identify version** -- Determine the target Django version from `requirements.txt`, `pyproject.toml`, `setup.cfg`, or explicit mention. Default to Django 5.2 LTS for new projects.

3. **Load context** -- Read the relevant reference file before answering.

4. **Analyze** -- Apply Django-specific reasoning. Consider QuerySet evaluation, middleware ordering, auth model choices, and the FBV vs CBV trade-off.

5. **Recommend** -- Provide concrete Python code examples with explanations. Always qualify trade-offs.

6. **Verify** -- Suggest validation steps: `python manage.py check`, `python manage.py test`, `python manage.py check --deploy` for production.

## Core Architecture

### ORM -- Models and QuerySets

Models are subclasses of `django.db.models.Model`. Each field maps to a database column. QuerySets are **lazy** (no DB hit until evaluated) and **chainable**.

```python
from django.db import models
from django.db.models import Q, F, Count

class Article(models.Model):
    class Status(models.TextChoices):
        DRAFT = "draft", "Draft"
        PUBLISHED = "published", "Published"

    title = models.CharField(max_length=300)
    slug = models.SlugField(unique=True)
    author = models.ForeignKey("Author", on_delete=models.CASCADE, related_name="articles")
    tags = models.ManyToManyField("Tag", related_name="articles", blank=True)
    status = models.CharField(max_length=20, choices=Status, default=Status.DRAFT)
    body = models.TextField()
    published_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        indexes = [models.Index(fields=["status", "-published_at"])]
```

**QuerySet chaining and evaluation:**

```python
published = (
    Article.objects
    .filter(status="published")
    .select_related("author")          # JOIN for ForeignKey
    .prefetch_related("tags")          # separate query for M2M
    .order_by("-published_at")
    .only("title", "slug", "author")   # defer other columns
    [:20]                               # LIMIT 20
)

# Complex lookups with Q objects
Article.objects.filter(Q(status="published") | Q(author__name="Admin"))

# Database-level field references with F expressions
Article.objects.filter(pk=1).update(view_count=F("view_count") + 1)

# Aggregation and annotation
Author.objects.annotate(
    article_count=Count("articles"),
).filter(article_count__gt=5).order_by("-article_count")
```

**Custom managers and QuerySets:**

```python
class ArticleQuerySet(models.QuerySet):
    def published(self):
        return self.filter(status=Article.Status.PUBLISHED)

    def with_stats(self):
        return self.annotate(comment_count=Count("comments")).select_related("author")

class Article(models.Model):
    objects = ArticleQuerySet.as_manager()
```

### Migrations

```bash
python manage.py makemigrations          # detect changes, write migration files
python manage.py migrate                 # apply pending migrations
python manage.py showmigrations          # list applied/unapplied
python manage.py sqlmigrate myapp 0002   # show raw SQL
python manage.py squashmigrations myapp 0001 0010  # compress history
```

### URL Routing

```python
from django.urls import path, include
from django.contrib import admin

# project/urls.py
urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include("api.urls", namespace="api")),
    path("blog/", include("blog.urls", namespace="blog")),
]

# blog/urls.py
app_name = "blog"
urlpatterns = [
    path("", views.ArticleListView.as_view(), name="list"),
    path("<slug:slug>/", views.ArticleDetailView.as_view(), name="detail"),
    path("<int:year>/<int:month>/", views.ArchiveView.as_view(), name="archive"),
]
```

Built-in converters: `str`, `int`, `slug`, `uuid`, `path`. Custom converters via `register_converter()`.

### Views -- FBV and CBV

**Function-Based Views:**

```python
from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth.decorators import login_required

@login_required
def article_detail(request, slug):
    article = get_object_or_404(Article.objects.select_related("author"), slug=slug)
    if request.method == "POST":
        form = CommentForm(request.POST)
        if form.is_valid():
            comment = form.save(commit=False)
            comment.article = article
            comment.save()
            return redirect("blog:detail", slug=slug)
    else:
        form = CommentForm()
    return render(request, "blog/detail.html", {"article": article, "form": form})
```

**Class-Based Views:**

```python
from django.views.generic import ListView, DetailView, CreateView
from django.contrib.auth.mixins import LoginRequiredMixin

class ArticleListView(LoginRequiredMixin, ListView):
    model = Article
    paginate_by = 20
    ordering = ["-published_at"]

    def get_queryset(self):
        return super().get_queryset().filter(status=Article.Status.PUBLISHED)

class ArticleCreateView(LoginRequiredMixin, CreateView):
    model = Article
    form_class = ArticleForm
    success_url = reverse_lazy("blog:list")

    def form_valid(self, form):
        form.instance.author = self.request.user.author
        return super().form_valid(form)
```

### Middleware Pipeline

Execution order: top-down for request, bottom-up for response (onion model).

```python
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",        # 1st: security headers
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]
```

**Custom middleware:**

```python
class TimingMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        import time
        start = time.monotonic()
        response = self.get_response(request)
        response["X-Request-Duration"] = f"{time.monotonic() - start:.4f}s"
        return response
```

### Admin

```python
@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    list_display = ["title", "author", "status", "published_at"]
    list_filter = ["status", "tags"]
    search_fields = ["title", "body", "author__name"]
    prepopulated_fields = {"slug": ("title",)}
    raw_id_fields = ["author"]
    filter_horizontal = ["tags"]
    date_hierarchy = "published_at"

    @admin.action(description="Publish selected articles")
    def make_published(self, request, queryset):
        queryset.update(status=Article.Status.PUBLISHED)

    actions = ["make_published"]
```

### Authentication

**Always define `AUTH_USER_MODEL` before the first migration:**

```python
# Option A: AbstractUser -- keeps built-in fields, adds yours
class User(AbstractUser):
    bio = models.TextField(blank=True)

# Option B: AbstractBaseUser -- full control
class User(AbstractBaseUser, PermissionsMixin):
    email = models.EmailField(unique=True)
    USERNAME_FIELD = "email"
    objects = UserManager()

# settings.py
AUTH_USER_MODEL = "users.User"
```

### Django REST Framework

```python
from rest_framework import serializers, viewsets, permissions
from rest_framework.routers import DefaultRouter

class ArticleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Article
        fields = ["id", "title", "slug", "author", "status", "body"]
        read_only_fields = ["id"]

class ArticleViewSet(viewsets.ModelViewSet):
    queryset = Article.objects.select_related("author").all()
    serializer_class = ArticleSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def perform_create(self, serializer):
        serializer.save(author=self.request.user.author)

# urls.py
router = DefaultRouter()
router.register("articles", ArticleViewSet, basename="article")
urlpatterns = router.urls
```

### Settings Module Pattern

```
config/settings/
    base.py          # shared settings
    development.py   # DEBUG=True, console email
    production.py    # security headers, S3, gunicorn
    test.py          # fast hasher, in-memory DB
```

```bash
DJANGO_SETTINGS_MODULE=config.settings.production python manage.py runserver
```

### ASGI and WSGI

```python
# config/wsgi.py -- synchronous (Gunicorn)
import os
from django.core.wsgi import get_wsgi_application
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.production")
application = get_wsgi_application()

# config/asgi.py -- asynchronous (Uvicorn)
import os
from django.core.asgi import get_asgi_application
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.production")
application = get_asgi_application()
```

## Async Support

Django's async support has been built incrementally. Async views since 3.1, async ORM interface since 4.1, full `async for` on QuerySets since 5.0. The ORM still wraps underlying DB calls in `sync_to_async` internally for most backends.

```python
# Async view with ORM (Django 5.0+)
async def article_list(request):
    articles = []
    async for article in Article.objects.filter(status="published").select_related("author"):
        articles.append(article)
    return render(request, "list.html", {"articles": articles})
```

## Version Routing Table

Route to version-specific agents when the question involves features from a specific Django release:

| Version | Status | Route To | Key Features |
|---|---|---|---|
| 4.2 | LTS (EOL Apr 2026) | `4.2/SKILL.md` | Psycopg 3, db_comment, STORAGES setting, async streaming |
| 5.2 | LTS (Apr 2025 - Apr 2028) | `5.2/SKILL.md` | Composite PKs, GeneratedField, db_default, LoginRequiredMiddleware, connection pooling |
| 6.0 | Current (Dec 2025 - Apr 2027) | `6.0/SKILL.md` | Background tasks, CSP middleware, template partials, AsyncPaginator |

**Enterprise migration path:** Django 4.2 LTS -> Django 5.2 LTS (skip 5.0/5.1). Then 5.2 LTS -> 6.0 when ready.

## Cross-Version Feature Matrix

| Feature | 4.2 | 5.2 | 6.0 |
|---|---|---|---|
| Async views | Yes | Yes | Yes |
| Async ORM (`aget`, `acreate`) | Yes | Yes | Yes |
| `async for` on QuerySets | Partial | Full | Full |
| `select_related` / `prefetch_related` | Yes | Yes | Yes |
| `GeneratedField` | No | Yes (5.0) | Yes |
| `db_default` | No | Yes (5.0) | Yes |
| `CompositePrimaryKey` | No | Yes | Yes |
| `LoginRequiredMiddleware` | No | Yes (5.1) | Yes |
| Connection pooling (psycopg3) | No | Yes (5.1) | Yes |
| Background tasks (`django.tasks`) | No | No | Yes |
| CSP middleware | No | No | Yes |
| Template partials | No | No | Yes |

## Reference Files

Load these for deep knowledge on specific topics:

- `references/architecture.md` -- ORM internals (QuerySet evaluation, lazy loading, select_related/prefetch_related), middleware pipeline, template engine, admin internals, auth system, signals, forms, management commands. **Load when:** architecture questions, ORM behavior, middleware ordering, auth model design.
- `references/best-practices.md` -- DRF patterns (serializers, viewsets, permissions), testing (TestCase, pytest-django, factory_boy), deployment (Gunicorn/Uvicorn, WhiteNoise, collectstatic), security (CSRF, HSTS, CSP), performance (N+1 fixes, caching, connection pooling), project structure. **Load when:** "how should I structure", deployment, security review, performance optimization.
- `references/diagnostics.md` -- Common errors (ImproperlyConfigured, FieldError, migration conflicts, circular imports), ORM debugging (django-debug-toolbar, explain(), query logging), performance profiling, async pitfalls. **Load when:** troubleshooting errors, debugging queries, performance problems.
