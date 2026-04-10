# Django Web Framework Architecture — Cross-Version Fundamentals

> Target audience: Senior Django developers. Covers stable architecture across Django 3.x–5.x.
> Last updated: 2026-04-09

---

## Table of Contents

1. [ORM](#1-orm)
2. [URL Routing](#2-url-routing)
3. [Views](#3-views)
4. [Middleware](#4-middleware)
5. [Template Engine](#5-template-engine)
6. [Admin](#6-admin)
7. [Authentication](#7-authentication)
8. [Signals](#8-signals)
9. [Forms](#9-forms)
10. [Django REST Framework](#10-django-rest-framework)
11. [Settings](#11-settings)
12. [Management Commands](#12-management-commands)
13. [ASGI/WSGI](#13-asgiwsgi)

---

## 1. ORM

### Model Definition

Models are subclasses of `django.db.models.Model`. Each field maps to a database column. Field types carry validation, database type affinity, and form widget hints.

```python
from django.db import models
from django.utils import timezone


class Author(models.Model):
    name = models.CharField(max_length=200)
    email = models.EmailField(unique=True)
    bio = models.TextField(blank=True)
    created_at = models.DateTimeField(default=timezone.now)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["name"]
        verbose_name = "author"
        verbose_name_plural = "authors"
        indexes = [
            models.Index(fields=["email"], name="author_email_idx"),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=["name", "email"], name="unique_author_name_email"
            )
        ]

    def __str__(self):
        return self.name


class Article(models.Model):
    class Status(models.TextChoices):
        DRAFT = "draft", "Draft"
        PUBLISHED = "published", "Published"
        ARCHIVED = "archived", "Archived"

    title = models.CharField(max_length=300)
    slug = models.SlugField(unique=True)
    author = models.ForeignKey(
        Author,
        on_delete=models.CASCADE,
        related_name="articles",
    )
    tags = models.ManyToManyField("Tag", related_name="articles", blank=True)
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.DRAFT,
    )
    published_at = models.DateTimeField(null=True, blank=True)
    word_count = models.PositiveIntegerField(default=0)
    body = models.TextField()

    class Meta:
        indexes = [
            models.Index(fields=["status", "-published_at"]),
        ]

    def save(self, *args, **kwargs):
        self.word_count = len(self.body.split())
        super().save(*args, **kwargs)
```

**Key field options:** `null`, `blank`, `default`, `unique`, `db_index`, `editable`, `choices`, `validators`, `related_name`, `on_delete` (CASCADE, PROTECT, SET_NULL, SET_DEFAULT, DO_NOTHING, RESTRICT).

**Relationship fields:**
- `ForeignKey(to, on_delete)` — many-to-one
- `ManyToManyField(to)` — many-to-many; Django creates a junction table automatically
- `OneToOneField(to, on_delete)` — one-to-one; often used for profile extension
- `GenericForeignKey` + `ContentType` — generic relations

---

### QuerySet API

QuerySets are **lazy**: they don't hit the database until evaluated (iteration, slicing, `list()`, `bool()`, `len()`, `repr()`). They are also **chainable** — each method returns a new QuerySet.

```python
from django.db.models import Q, F, Count, Avg, Sum, Subquery, OuterRef, Exists, Value
from django.db.models.functions import Coalesce, TruncMonth

# Basic retrieval
qs = Article.objects.all()                        # <QuerySet []> — not yet evaluated
qs = Article.objects.filter(status="published")   # adds WHERE clause
qs = Article.objects.exclude(status="archived")   # NOT
qs = Article.objects.get(slug="my-post")          # raises DoesNotExist or MultipleObjectsReturned

# Field lookups
Article.objects.filter(title__icontains="django")
Article.objects.filter(published_at__date=datetime.date.today())
Article.objects.filter(word_count__gte=500, word_count__lte=5000)
Article.objects.filter(author__name__startswith="A")  # JOIN via __ traversal

# Chaining
published = (
    Article.objects
    .filter(status="published")
    .select_related("author")          # single JOIN for ForeignKey
    .prefetch_related("tags")          # separate query, cached in Python
    .order_by("-published_at")
    .only("title", "slug", "author")   # defer all other columns
    [:20]                               # LIMIT 20
)

# Evaluation methods
list(qs)
qs.count()           # SELECT COUNT(*)
qs.exists()          # SELECT 1 ... LIMIT 1
qs.first()           # ORDER BY pk LIMIT 1
qs.last()
qs.values("title", "status")          # returns dicts
qs.values_list("slug", flat=True)     # returns flat list of slugs
qs.distinct()

# Bulk operations
Article.objects.bulk_create([Article(...), Article(...)])
Article.objects.bulk_update(articles, fields=["status"])
Article.objects.filter(status="draft").update(status="archived")
Article.objects.filter(created_at__year=2020).delete()
```

#### Q Objects — Complex Lookups

`Q` objects allow OR, NOT, and nested boolean logic.

```python
from django.db.models import Q

# OR query
Article.objects.filter(
    Q(status="published") | Q(author__name="Admin")
)

# NOT
Article.objects.filter(~Q(status="archived"))

# Combined with AND
Article.objects.filter(
    Q(status="published") & ~Q(word_count=0)
)

# Dynamic query building
conditions = Q()
if search_term:
    conditions &= Q(title__icontains=search_term)
if author_id:
    conditions &= Q(author_id=author_id)
Article.objects.filter(conditions)
```

#### F Expressions — Database-Level Field References

`F()` references a field value at the database level, avoiding a round-trip.

```python
from django.db.models import F

# Increment without fetching the object
Article.objects.filter(pk=1).update(word_count=F("word_count") + 100)

# Compare two fields on the same row
Article.objects.filter(updated_at__gt=F("published_at"))

# Annotate with arithmetic
Article.objects.annotate(
    title_len=models.ExpressionWrapper(
        models.Func(F("title"), function="CHAR_LENGTH"),
        output_field=models.IntegerField(),
    )
)
```

#### Aggregation

```python
from django.db.models import Count, Avg, Sum, Max, Min

# Whole queryset aggregation (returns dict)
Article.objects.aggregate(
    total=Count("id"),
    avg_words=Avg("word_count"),
    total_words=Sum("word_count"),
)

# Per-object annotation
authors = Author.objects.annotate(
    article_count=Count("articles"),
    avg_word_count=Avg("articles__word_count"),
).filter(article_count__gt=5).order_by("-article_count")

# Grouping with values + annotate
Author.objects.values("name").annotate(
    published=Count("articles", filter=Q(articles__status="published"))
)

# Date truncation
Article.objects.annotate(
    month=TruncMonth("published_at")
).values("month").annotate(count=Count("id")).order_by("month")
```

#### Subquery and Exists

```python
from django.db.models import Subquery, OuterRef, Exists

# Latest article per author as a subquery
latest_articles = Article.objects.filter(
    author=OuterRef("pk"),
    status="published",
).order_by("-published_at").values("title")[:1]

authors_with_latest = Author.objects.annotate(
    latest_article_title=Subquery(latest_articles)
)

# Exists subquery
has_published = Article.objects.filter(
    author=OuterRef("pk"), status="published"
)
active_authors = Author.objects.filter(Exists(has_published))
```

---

### Managers and Custom QuerySets

The default manager is `objects` (an instance of `Manager`). Custom managers and querysets move reusable query logic into the model layer.

```python
class ArticleQuerySet(models.QuerySet):
    def published(self):
        return self.filter(status=Article.Status.PUBLISHED)

    def by_author(self, author):
        return self.filter(author=author)

    def recent(self, n=10):
        return self.published().order_by("-published_at")[:n]

    def with_stats(self):
        return self.annotate(
            comment_count=Count("comments"),
        ).select_related("author").prefetch_related("tags")


class ArticleManager(models.Manager):
    def get_queryset(self):
        # All queries through this manager exclude archived by default
        return ArticleQuerySet(self.model, using=self._db).exclude(
            status=Article.Status.ARCHIVED
        )

    def published(self):
        return self.get_queryset().published()


class Article(models.Model):
    # ...
    objects = ArticleManager()          # replaces default manager
    all_objects = models.Manager()      # unfiltered escape hatch

    # Using `as_manager()` shortcut
    # objects = ArticleQuerySet.as_manager()
```

---

### Migrations System

Migrations track model changes as Python files in a `migrations/` package. The `django_migrations` table stores applied migrations.

**Core workflow:**

```bash
python manage.py makemigrations          # detect model changes, write migration files
python manage.py makemigrations --name add_slug_to_article
python manage.py migrate                 # apply pending migrations
python manage.py migrate myapp 0003      # migrate to specific state
python manage.py migrate myapp zero      # roll back all migrations for app
python manage.py showmigrations          # list applied/unapplied
python manage.py sqlmigrate myapp 0002   # show raw SQL for a migration
python manage.py squashmigrations myapp 0001 0010  # compress history
```

**Migration file anatomy:**

```python
# myapp/migrations/0002_article_slug.py
from django.db import migrations, models
import django.utils.text


def populate_slugs(apps, schema_editor):
    Article = apps.get_model("myapp", "Article")
    for article in Article.objects.all():
        article.slug = django.utils.text.slugify(article.title)
        article.save(update_fields=["slug"])


class Migration(migrations.Migration):
    dependencies = [
        ("myapp", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="article",
            name="slug",
            field=models.SlugField(default=""),
            preserve_default=False,
        ),
        migrations.RunPython(populate_slugs, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="article",
            name="slug",
            field=models.SlugField(unique=True),
        ),
    ]
```

**Key migration operations:** `CreateModel`, `DeleteModel`, `AddField`, `RemoveField`, `AlterField`, `RenameField`, `RenameModel`, `AddIndex`, `RemoveIndex`, `AddConstraint`, `RemoveConstraint`, `RunPython`, `RunSQL`, `SeparateDatabaseAndState`.

---

### Multi-Database Routing

```python
# settings.py
DATABASES = {
    "default": {"ENGINE": "django.db.backends.postgresql", ...},
    "analytics": {"ENGINE": "django.db.backends.postgresql", ...},
    "replica": {"ENGINE": "django.db.backends.postgresql", ...},
}
DATABASE_ROUTERS = ["myapp.routers.PrimaryReplicaRouter"]
```

```python
# myapp/routers.py
class PrimaryReplicaRouter:
    def db_for_read(self, model, **hints):
        """Direct reads to replica."""
        return "replica"

    def db_for_write(self, model, **hints):
        return "default"

    def allow_relation(self, obj1, obj2, **hints):
        return True

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        return db == "default"


class AnalyticsRouter:
    analytics_apps = {"analytics"}

    def db_for_read(self, model, **hints):
        if model._meta.app_label in self.analytics_apps:
            return "analytics"

    def db_for_write(self, model, **hints):
        if model._meta.app_label in self.analytics_apps:
            return "analytics"

    def allow_migrate(self, db, app_label, **hints):
        if app_label in self.analytics_apps:
            return db == "analytics"
        return db == "default"
```

Manual database selection with `using()`:

```python
Article.objects.using("replica").filter(status="published")
Article.objects.using("analytics").create(...)

# In views or tasks:
with transaction.atomic(using="analytics"):
    ...
```

---

## 2. URL Routing

### urlpatterns, path(), re_path()

URL configuration lives in `urls.py` modules. The root URLconf is set by `ROOT_URLCONF` in settings.

```python
# project/urls.py
from django.urls import path, re_path, include
from django.contrib import admin

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include("api.urls", namespace="api")),
    path("blog/", include("blog.urls", namespace="blog")),
    path("", include("pages.urls")),
]
```

`path()` uses simple converters. `re_path()` uses raw regex with named groups.

```python
# blog/urls.py
from django.urls import path, re_path
from . import views

app_name = "blog"  # sets the namespace when included

urlpatterns = [
    path("", views.ArticleListView.as_view(), name="list"),
    path("<int:pk>/", views.ArticleDetailView.as_view(), name="detail"),
    path("<slug:slug>/", views.ArticleBySlugView.as_view(), name="detail-slug"),
    path("<int:year>/<int:month>/", views.ArchiveView.as_view(), name="archive"),
    re_path(
        r"^(?P<year>[0-9]{4})/(?P<slug>[-\w]+)/$",
        views.ArticleDetailView.as_view(),
        name="year-detail",
    ),
]
```

### Built-in Path Converters

| Converter | Regex | Python type |
|-----------|-------|-------------|
| `str` | `[^/]+` | `str` |
| `int` | `[0-9]+` | `int` |
| `slug` | `[-a-zA-Z0-9_]+` | `str` |
| `uuid` | UUID pattern | `uuid.UUID` |
| `path` | `.+` (including slashes) | `str` |

### Custom Path Converters

```python
class FourDigitYearConverter:
    regex = r"[0-9]{4}"

    def to_python(self, value):
        return int(value)

    def to_url(self, value):
        return f"{value:04d}"


# Register and use
from django.urls import register_converter
register_converter(FourDigitYearConverter, "yyyy")

urlpatterns = [
    path("<yyyy:year>/", views.YearView.as_view(), name="year"),
]
```

### URL Namespaces

Namespaces prevent name collisions across apps. Two levels: **application** (`app_name`) and **instance** (`namespace` in `include()`).

```python
# Reversing namespaced URLs
from django.urls import reverse

reverse("blog:detail", kwargs={"slug": "my-post"})
reverse("api:v2:article-list")  # nested namespaces

# In templates
{% url "blog:detail" slug=article.slug %}
```

### URL Resolving

```python
from django.urls import resolve, Resolver404

try:
    match = resolve("/blog/my-post/")
    match.func          # view callable
    match.args          # positional args
    match.kwargs        # {"slug": "my-post"}
    match.url_name      # "detail-slug"
    match.app_name      # "blog"
    match.namespace     # "blog"
except Resolver404:
    pass
```

---

## 3. Views

### Function-Based Views (FBV)

```python
from django.shortcuts import render, get_object_or_404, redirect
from django.http import HttpResponse, JsonResponse, Http404
from django.views.decorators.http import require_http_methods, require_POST
from django.contrib.auth.decorators import login_required
from django.views.decorators.cache import cache_page
from django.views.decorators.vary import vary_on_headers


@login_required
@require_http_methods(["GET", "POST"])
@cache_page(60 * 15)
def article_detail(request, slug):
    article = get_object_or_404(
        Article.objects.select_related("author").prefetch_related("tags"),
        slug=slug,
        status=Article.Status.PUBLISHED,
    )
    if request.method == "POST":
        form = CommentForm(request.POST)
        if form.is_valid():
            comment = form.save(commit=False)
            comment.article = article
            comment.user = request.user
            comment.save()
            return redirect("blog:detail", slug=slug)
    else:
        form = CommentForm()

    return render(request, "blog/article_detail.html", {
        "article": article,
        "form": form,
    })
```

### Class-Based Views (CBV)

CBVs use method dispatch (`get()`, `post()`, etc.) and a `dispatch()` entry point. `View.as_view()` returns a callable suitable for `urlpatterns`.

```python
from django.views import View
from django.views.generic import (
    ListView, DetailView, CreateView, UpdateView, DeleteView,
    TemplateView, RedirectView, FormView,
)
from django.contrib.auth.mixins import LoginRequiredMixin, PermissionRequiredMixin
from django.urls import reverse_lazy


class ArticleListView(LoginRequiredMixin, ListView):
    model = Article
    template_name = "blog/article_list.html"
    context_object_name = "articles"
    paginate_by = 20
    ordering = ["-published_at"]

    def get_queryset(self):
        qs = super().get_queryset().filter(status=Article.Status.PUBLISHED)
        tag = self.request.GET.get("tag")
        if tag:
            qs = qs.filter(tags__slug=tag)
        return qs

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        ctx["popular_tags"] = Tag.objects.annotate(
            count=Count("articles")
        ).order_by("-count")[:10]
        return ctx


class ArticleDetailView(DetailView):
    model = Article
    template_name = "blog/article_detail.html"
    slug_field = "slug"
    slug_url_kwarg = "slug"
    queryset = Article.objects.select_related("author").prefetch_related("tags")


class ArticleCreateView(LoginRequiredMixin, PermissionRequiredMixin, CreateView):
    model = Article
    form_class = ArticleForm
    template_name = "blog/article_form.html"
    permission_required = "blog.add_article"
    success_url = reverse_lazy("blog:list")

    def form_valid(self, form):
        form.instance.author = self.request.user.author
        return super().form_valid(form)


class ArticleDeleteView(LoginRequiredMixin, DeleteView):
    model = Article
    success_url = reverse_lazy("blog:list")

    def get_queryset(self):
        # Authors can only delete their own articles
        return super().get_queryset().filter(author=self.request.user.author)
```

### Mixins

Mixins are single-purpose base classes composed via Python MRO. Common patterns:

```python
class OwnershipMixin:
    """Restrict queryset to objects owned by the current user."""
    owner_field = "author"

    def get_queryset(self):
        qs = super().get_queryset()
        return qs.filter(**{f"{self.owner_field}__user": self.request.user})


class AjaxResponseMixin:
    """Return JSON for AJAX requests, HTML otherwise."""
    def form_valid(self, form):
        obj = form.save()
        if self.request.headers.get("X-Requested-With") == "XMLHttpRequest":
            return JsonResponse({"id": obj.pk, "status": "created"})
        return super().form_valid(form)


class MultipleFormsView(TemplateView):
    """Handle multiple forms in one view."""
    form_classes = {}

    def get_forms(self):
        kwargs = {}
        if self.request.method in ("POST", "PUT"):
            kwargs["data"] = self.request.POST
            kwargs["files"] = self.request.FILES
        return {name: cls(**kwargs) for name, cls in self.form_classes.items()}
```

### Async Views (Django 3.1+)

```python
import asyncio
from django.http import JsonResponse
from asgiref.sync import sync_to_async


async def async_article_list(request):
    # ORM is synchronous; wrap with sync_to_async
    articles = await sync_to_async(
        lambda: list(Article.objects.filter(status="published").values("title", "slug"))
    )()
    return JsonResponse({"articles": articles})


async def async_external_fetch(request, pk):
    import aiohttp

    article = await sync_to_async(Article.objects.get)(pk=pk)

    async with aiohttp.ClientSession() as session:
        async with session.get(f"https://api.example.com/enrich/{pk}") as resp:
            data = await resp.json()

    return JsonResponse({"article": article.title, "enrichment": data})


# Async CBV — mark the handler methods as async
class AsyncDashboardView(LoginRequiredMixin, View):
    async def get(self, request):
        stats = await sync_to_async(self._compute_stats)()
        return render(request, "dashboard.html", stats)

    def _compute_stats(self):
        return {
            "article_count": Article.objects.count(),
            "author_count": Author.objects.count(),
        }
```

---

## 4. Middleware

Middleware is a hook framework layered around the request/response cycle. Execution order is **top-down for request, bottom-up for response** (like an onion).

### Middleware Class Structure

```python
class TimingMiddleware:
    def __init__(self, get_response):
        # Called once at startup; store get_response callable
        self.get_response = get_response
        # One-time initialization here

    def __call__(self, request):
        # Before the view (and later middleware)
        import time
        start = time.monotonic()

        response = self.get_response(request)

        # After the view
        elapsed = time.monotonic() - start
        response["X-Request-Duration"] = f"{elapsed:.4f}s"
        return response
```

### process_* Hook Methods (old-style, still supported)

For more granular hooks, implement named methods. Django calls these if present.

```python
class AdvancedMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        return response

    def process_view(self, request, view_func, view_args, view_kwargs):
        """Called just before Django calls the view. Return None to continue."""
        if not request.user.is_authenticated and view_func.login_required:
            return redirect("login")
        return None

    def process_exception(self, request, exception):
        """Called when a view raises an exception. Return None to re-raise."""
        if isinstance(exception, RateLimitExceeded):
            return HttpResponse("Rate limit exceeded", status=429)
        return None

    def process_template_response(self, request, response):
        """Called when a view returns TemplateResponse. Can alter context."""
        if hasattr(response, "context_data"):
            response.context_data["site_name"] = "My Blog"
        return response
```

### Async Middleware (Django 3.1+)

```python
import asyncio


class AsyncMiddleware:
    async_capable = True
    sync_capable = False

    def __init__(self, get_response):
        self.get_response = get_response
        if asyncio.iscoroutinefunction(self.get_response):
            self._is_coroutine = asyncio.coroutines._is_coroutine

    async def __call__(self, request):
        # Do async work before view
        request.tenant = await fetch_tenant(request.get_host())

        response = await self.get_response(request)

        return response
```

### Middleware Ordering in MIDDLEWARE Setting

```python
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",       # 1st: security headers
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    # Custom middleware goes here
    "myapp.middleware.TimingMiddleware",
]
```

Request flows top to bottom; response flows bottom to top. Middleware that depends on `request.user` must come after `AuthenticationMiddleware`.

---

## 5. Template Engine

### Django Template Language (DTL)

DTL is a deliberately limited language; logic belongs in views, not templates.

```html
<!-- base.html -->
<!DOCTYPE html>
<html lang="en">
<head>
    <title>{% block title %}My Site{% endblock %}</title>
</head>
<body>
    {% block content %}{% endblock %}
</body>
</html>

<!-- blog/article_list.html -->
{% extends "base.html" %}
{% load blog_tags humanize %}

{% block title %}Articles — {{ block.super }}{% endblock %}

{% block content %}
<h1>{{ page_title|default:"Latest Articles" }}</h1>

{% if articles %}
    {% for article in articles %}
        <article>
            <h2><a href="{% url 'blog:detail' slug=article.slug %}">{{ article.title }}</a></h2>
            <p>By {{ article.author.name }} on {{ article.published_at|date:"N j, Y" }}</p>
            <p>{{ article.body|truncatewords:50|linebreaks }}</p>
        </article>
    {% empty %}
        <p>No articles found.</p>
    {% endfor %}

    {% include "pagination.html" with page_obj=page_obj %}
{% else %}
    <p>No articles available.</p>
{% endif %}

{% with total=articles|length %}
    <p>Showing {{ total }} article{{ total|pluralize }}.</p>
{% endwith %}
{% endblock %}
```

### Custom Template Tags and Filters

```python
# blog/templatetags/blog_tags.py
from django import template
from django.utils.html import format_html
from blog.models import Article, Tag

register = template.Library()


# Simple filter
@register.filter(name="truncate_chars", is_safe=True)
def truncate_chars(value, max_length):
    if len(value) > max_length:
        return value[:max_length].rstrip() + "…"
    return value


# Simple tag
@register.simple_tag
def get_popular_tags(count=5):
    from django.db.models import Count
    return Tag.objects.annotate(
        article_count=Count("articles")
    ).order_by("-article_count")[:count]


# Inclusion tag — renders a sub-template
@register.inclusion_tag("blog/_sidebar.html", takes_context=True)
def sidebar(context):
    return {
        "recent": Article.objects.published().recent(5),
        "request": context["request"],
    }


# Block tag (advanced) — full parser control
@register.tag("verbatim_block")
def do_verbatim_block(parser, token):
    nodelist = parser.parse(("endverbatim_block",))
    parser.delete_first_token()
    return VerbatimNode(nodelist)


class VerbatimNode(template.Node):
    def __init__(self, nodelist):
        self.nodelist = nodelist

    def render(self, context):
        return self.nodelist.render(context)
```

### Context Processors

Context processors add variables to every template context.

```python
# myapp/context_processors.py
def site_settings(request):
    return {
        "SITE_NAME": "My Blog",
        "SUPPORT_EMAIL": "support@example.com",
    }

def cart_info(request):
    if request.user.is_authenticated:
        count = request.user.cart_items.count()
    else:
        count = 0
    return {"cart_count": count}
```

```python
# settings.py
TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
                "myapp.context_processors.site_settings",
                "myapp.context_processors.cart_info",
            ],
        },
    },
]
```

### Jinja2 Backend

```python
TEMPLATES = [
    {
        "BACKEND": "django.template.backends.jinja2.Jinja2",
        "DIRS": [BASE_DIR / "jinja2"],
        "APP_DIRS": True,
        "OPTIONS": {
            "environment": "myapp.jinja2.environment",
        },
    },
]
```

```python
# myapp/jinja2.py
from jinja2 import Environment
from django.contrib.staticfiles.storage import staticfiles_storage
from django.urls import reverse


def environment(**options):
    env = Environment(**options)
    env.globals.update({
        "static": staticfiles_storage.url,
        "url": reverse,
    })
    return env
```

---

## 6. Admin

### ModelAdmin Registration

```python
# blog/admin.py
from django.contrib import admin
from django.utils.html import format_html
from .models import Article, Author, Tag, Comment


@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    list_display = ["title", "author_link", "status", "published_at", "word_count"]
    list_display_links = ["title"]
    list_filter = ["status", "tags", ("published_at", admin.DateFieldListFilter)]
    search_fields = ["title", "body", "author__name", "author__email"]
    prepopulated_fields = {"slug": ("title",)}
    readonly_fields = ["word_count", "created_at"]
    date_hierarchy = "published_at"
    ordering = ["-published_at"]
    list_per_page = 50
    save_on_top = True
    raw_id_fields = ["author"]       # use popup instead of dropdown for FK
    filter_horizontal = ["tags"]     # M2M widget with two columns

    fieldsets = [
        (None, {"fields": ["title", "slug", "status", "author"]}),
        ("Content", {"fields": ["body"], "classes": ["wide"]}),
        ("Publication", {
            "fields": ["published_at", "tags"],
            "classes": ["collapse"],
        }),
        ("Metadata", {
            "fields": ["word_count", "created_at"],
            "classes": ["collapse"],
        }),
    ]

    # Custom column with HTML
    @admin.display(description="Author", ordering="author__name")
    def author_link(self, obj):
        url = reverse("admin:blog_author_change", args=[obj.author_id])
        return format_html('<a href="{}">{}</a>', url, obj.author.name)

    # Custom action
    @admin.action(description="Publish selected articles")
    def make_published(self, request, queryset):
        from django.utils import timezone
        updated = queryset.update(
            status=Article.Status.PUBLISHED,
            published_at=timezone.now(),
        )
        self.message_user(request, f"{updated} articles published.")

    actions = ["make_published"]

    def get_queryset(self, request):
        return super().get_queryset(request).select_related("author")

    def save_model(self, request, obj, form, change):
        if not change:
            obj.created_by = request.user
        super().save_model(request, obj, form, change)
```

### Inlines

```python
class CommentInline(admin.TabularInline):   # or StackedInline
    model = Comment
    extra = 1
    fields = ["user", "body", "is_approved"]
    readonly_fields = ["created_at"]
    show_change_link = True


@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    inlines = [CommentInline]
```

### Admin Site Customization

```python
# Create a custom AdminSite
class MyAdminSite(admin.AdminSite):
    site_header = "My Blog Administration"
    site_title = "My Blog Admin"
    index_title = "Dashboard"

    def has_permission(self, request):
        return request.user.is_active and request.user.is_staff


my_admin_site = MyAdminSite(name="myadmin")
my_admin_site.register(Article, ArticleAdmin)
my_admin_site.register(Author)

# urls.py
urlpatterns = [
    path("myadmin/", my_admin_site.urls),
]
```

---

## 7. Authentication

### Built-in User Model

`django.contrib.auth.models.User` provides `username`, `email`, `password` (hashed), `first_name`, `last_name`, `is_active`, `is_staff`, `is_superuser`, `last_login`, `date_joined`.

### Custom User Models

**Always set AUTH_USER_MODEL before the first migration.** Two base classes:

```python
# users/models.py

# Option A: AbstractUser — keeps all built-in fields, add your own
from django.contrib.auth.models import AbstractUser

class User(AbstractUser):
    bio = models.TextField(blank=True)
    avatar = models.ImageField(upload_to="avatars/", blank=True)
    timezone = models.CharField(max_length=50, default="UTC")

    class Meta(AbstractUser.Meta):
        db_table = "users"
```

```python
# Option B: AbstractBaseUser — full control, implement everything yourself
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.contrib.auth.validators import UnicodeUsernameValidator


class UserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError("Email is required")
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        return self.create_user(email, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    email = models.EmailField(unique=True)
    name = models.CharField(max_length=200)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(default=timezone.now)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["name"]

    objects = UserManager()

    def __str__(self):
        return self.email
```

```python
# settings.py
AUTH_USER_MODEL = "users.User"
```

### Permissions and Groups

```python
from django.contrib.auth.models import Permission
from django.contrib.contenttypes.models import ContentType

# Programmatic permission check
user.has_perm("blog.add_article")          # app_label.codename
user.has_perm("blog.change_article", obj)  # object-level
user.has_perms(["blog.add_article", "blog.change_article"])

# Assign permissions
content_type = ContentType.objects.get_for_model(Article)
perm = Permission.objects.get(content_type=content_type, codename="publish_article")
user.user_permissions.add(perm)

# Groups
from django.contrib.auth.models import Group
editors = Group.objects.get(name="Editors")
user.groups.add(editors)

# Custom model-level permissions via Meta
class Article(models.Model):
    class Meta:
        permissions = [
            ("publish_article", "Can publish articles"),
            ("feature_article", "Can feature articles on homepage"),
        ]
```

### Authentication Backends

```python
# myapp/auth_backends.py
from django.contrib.auth.backends import ModelBackend
from django.contrib.auth import get_user_model

User = get_user_model()


class EmailBackend(ModelBackend):
    """Authenticate using email instead of username."""

    def authenticate(self, request, username=None, password=None, **kwargs):
        email = kwargs.get("email", username)
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            User().set_password(password)  # Timing attack mitigation
            return None
        if user.check_password(password) and self.user_can_authenticate(user):
            return user
        return None


class TokenBackend:
    """API token authentication."""

    def authenticate(self, request, token=None):
        if token is None:
            return None
        try:
            from myapp.models import APIToken
            token_obj = APIToken.objects.select_related("user").get(
                key=token, is_active=True
            )
            return token_obj.user
        except APIToken.DoesNotExist:
            return None

    def get_user(self, user_id):
        try:
            return User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return None
```

```python
# settings.py
AUTHENTICATION_BACKENDS = [
    "myapp.auth_backends.EmailBackend",
    "django.contrib.auth.backends.ModelBackend",  # fallback
]
```

### Login/Logout Views

Django provides `django.contrib.auth.views.LoginView`, `LogoutView`, `PasswordChangeView`, `PasswordResetView`, `PasswordResetConfirmView`.

```python
# urls.py
from django.contrib.auth import views as auth_views

urlpatterns = [
    path("login/", auth_views.LoginView.as_view(
        template_name="auth/login.html",
        redirect_authenticated_user=True,
    ), name="login"),
    path("logout/", auth_views.LogoutView.as_view(
        next_page="/"
    ), name="logout"),
    path("password/change/", auth_views.PasswordChangeView.as_view(
        template_name="auth/password_change.html",
        success_url=reverse_lazy("password_change_done"),
    ), name="password_change"),
]
```

---

## 8. Signals

Signals allow decoupled components to react to events. A sender fires a signal; registered receivers execute.

### Core Signals

```python
from django.db.models.signals import (
    pre_save, post_save,
    pre_delete, post_delete,
    m2m_changed,
    pre_init, post_init,
)
from django.core.signals import request_started, request_finished, got_request_exception
from django.db import reset_queries
```

### Connecting Receivers

```python
from django.db.models.signals import post_save, pre_delete
from django.dispatch import receiver
from django.contrib.auth import get_user_model
from blog.models import Article, Author

User = get_user_model()


# Decorator style (preferred)
@receiver(post_save, sender=User)
def create_author_profile(sender, instance, created, **kwargs):
    if created:
        Author.objects.create(user=instance, name=instance.get_full_name())


@receiver(post_save, sender=User)
def save_author_profile(sender, instance, **kwargs):
    instance.author.save()


@receiver(pre_delete, sender=Article)
def cleanup_article_files(sender, instance, **kwargs):
    # Delete S3 assets before the DB row is removed
    if instance.cover_image:
        instance.cover_image.delete(save=False)


# m2m_changed — fires on add/remove/clear on M2M relations
@receiver(m2m_changed, sender=Article.tags.through)
def article_tags_changed(sender, instance, action, pk_set, **kwargs):
    if action in ("post_add", "post_remove", "post_clear"):
        instance.tag_count = instance.tags.count()
        instance.save(update_fields=["tag_count"])
```

### Custom Signals

```python
from django.dispatch import Signal

article_published = Signal()  # provides_args removed in Django 4.0+

# Sending
def publish(self):
    self.status = Article.Status.PUBLISHED
    self.save()
    article_published.send(sender=self.__class__, article=self)

# Receiving
@receiver(article_published)
def notify_subscribers(sender, article, **kwargs):
    from notifications.tasks import send_publication_email
    send_publication_email.delay(article.pk)
```

### Signal Best Practices

- Always accept `**kwargs` — signals may pass additional arguments.
- Prefer `dispatch_uid` to prevent duplicate receivers on import.
- Avoid heavy operations in receivers; offload to Celery tasks.
- Use `AppConfig.ready()` as the canonical place to connect receivers.

```python
# myapp/apps.py
class BlogConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "blog"

    def ready(self):
        import blog.signals  # noqa: F401 — side-effect import
```

---

## 9. Forms

### Form and ModelForm

```python
from django import forms
from django.core.exceptions import ValidationError
from .models import Article


class ArticleForm(forms.ModelForm):
    tags_input = forms.CharField(
        required=False,
        help_text="Comma-separated tag names",
        widget=forms.TextInput(attrs={"placeholder": "django, python, web"}),
    )

    class Meta:
        model = Article
        fields = ["title", "slug", "body", "status"]
        widgets = {
            "body": forms.Textarea(attrs={"rows": 20, "class": "markdown-editor"}),
            "status": forms.RadioSelect,
        }
        labels = {"slug": "URL slug"}

    def clean_slug(self):
        slug = self.cleaned_data["slug"]
        qs = Article.objects.filter(slug=slug)
        if self.instance.pk:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise ValidationError("An article with this slug already exists.")
        return slug

    def clean(self):
        cleaned_data = super().clean()
        status = cleaned_data.get("status")
        body = cleaned_data.get("body")
        if status == Article.Status.PUBLISHED and not body:
            raise ValidationError("Published articles must have a body.")
        return cleaned_data

    def save(self, commit=True):
        article = super().save(commit=False)
        # Process tags_input
        if commit:
            article.save()
            self._process_tags(article)
        return article

    def _process_tags(self, article):
        raw = self.cleaned_data.get("tags_input", "")
        names = [t.strip() for t in raw.split(",") if t.strip()]
        tags = [Tag.objects.get_or_create(name=n, defaults={"slug": slugify(n)})[0]
                for n in names]
        article.tags.set(tags)
```

### Formsets

```python
from django.forms import formset_factory, modelformset_factory, inlineformset_factory

# Model formset for multiple article edits
ArticleFormSet = modelformset_factory(
    Article,
    fields=["title", "status"],
    extra=0,
    can_delete=True,
    max_num=20,
)

# Inline formset (parent-child relationship)
CommentInlineFormSet = inlineformset_factory(
    Article, Comment,
    fields=["body", "is_approved"],
    extra=1,
    can_delete=True,
)

# In a view
def manage_comments(request, article_pk):
    article = get_object_or_404(Article, pk=article_pk)
    if request.method == "POST":
        formset = CommentInlineFormSet(request.POST, instance=article)
        if formset.is_valid():
            formset.save()
            return redirect("blog:detail", slug=article.slug)
    else:
        formset = CommentInlineFormSet(instance=article)
    return render(request, "blog/manage_comments.html", {
        "article": article,
        "formset": formset,
    })
```

### Widgets

```python
from django.forms import widgets

class DateRangeWidget(widgets.MultiWidget):
    def __init__(self, attrs=None):
        sub_widgets = [
            widgets.DateInput(attrs={"type": "date"}),
            widgets.DateInput(attrs={"type": "date"}),
        ]
        super().__init__(sub_widgets, attrs)

    def decompress(self, value):
        if value:
            return [value.start, value.end]
        return [None, None]
```

### Crispy Forms Integration

```python
# forms.py — with django-crispy-forms
from crispy_forms.helper import FormHelper
from crispy_forms.layout import Layout, Row, Column, Field, Submit, HTML


class ArticleForm(forms.ModelForm):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.form_method = "post"
        self.helper.layout = Layout(
            Row(
                Column(Field("title", css_class="form-control"), css_class="col-md-8"),
                Column(Field("status", css_class="form-select"), css_class="col-md-4"),
            ),
            Field("slug", css_class="form-control font-monospace"),
            Field("body", css_class="form-control"),
            HTML("<hr>"),
            Submit("submit", "Save Article", css_class="btn btn-primary"),
        )
```

---

## 10. Django REST Framework

### Serializers

```python
from rest_framework import serializers
from .models import Article, Author, Tag


class TagSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tag
        fields = ["id", "name", "slug"]


class AuthorSerializer(serializers.ModelSerializer):
    class Meta:
        model = Author
        fields = ["id", "name", "email"]


class ArticleSerializer(serializers.ModelSerializer):
    author = AuthorSerializer(read_only=True)
    author_id = serializers.PrimaryKeyRelatedField(
        queryset=Author.objects.all(),
        source="author",
        write_only=True,
    )
    tags = TagSerializer(many=True, read_only=True)
    tag_ids = serializers.PrimaryKeyRelatedField(
        queryset=Tag.objects.all(),
        source="tags",
        many=True,
        write_only=True,
        required=False,
    )
    word_count = serializers.IntegerField(read_only=True)
    url = serializers.HyperlinkedIdentityField(
        view_name="api:article-detail",
        lookup_field="slug",
    )

    class Meta:
        model = Article
        fields = [
            "id", "url", "title", "slug", "author", "author_id",
            "tags", "tag_ids", "status", "published_at", "word_count", "body",
        ]
        read_only_fields = ["word_count", "published_at"]

    def validate_slug(self, value):
        qs = Article.objects.filter(slug=value)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError("Slug must be unique.")
        return value

    def validate(self, attrs):
        if attrs.get("status") == "published" and not attrs.get("body"):
            raise serializers.ValidationError({"body": "Body required for published articles."})
        return attrs

    def create(self, validated_data):
        tags = validated_data.pop("tags", [])
        article = Article.objects.create(**validated_data)
        article.tags.set(tags)
        return article

    def update(self, instance, validated_data):
        tags = validated_data.pop("tags", None)
        instance = super().update(instance, validated_data)
        if tags is not None:
            instance.tags.set(tags)
        return instance
```

### ViewSets and Routers

```python
from rest_framework import viewsets, mixins, permissions, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend


class ArticleViewSet(viewsets.ModelViewSet):
    serializer_class = ArticleSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ["status", "author"]
    search_fields = ["title", "body", "author__name"]
    ordering_fields = ["published_at", "word_count"]
    ordering = ["-published_at"]
    lookup_field = "slug"

    def get_queryset(self):
        return (
            Article.objects
            .select_related("author")
            .prefetch_related("tags")
            .filter(status="published")
        )

    def perform_create(self, serializer):
        serializer.save(author=self.request.user.author)

    @action(detail=True, methods=["post"], permission_classes=[permissions.IsAdminUser])
    def publish(self, request, slug=None):
        article = self.get_object()
        article.status = Article.Status.PUBLISHED
        article.published_at = timezone.now()
        article.save(update_fields=["status", "published_at"])
        return Response(ArticleSerializer(article, context={"request": request}).data)

    @action(detail=False, methods=["get"])
    def my_articles(self, request):
        qs = Article.objects.filter(author__user=request.user)
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)


# Read-only viewset example
class TagViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    queryset = Tag.objects.all()
    serializer_class = TagSerializer
    permission_classes = [permissions.AllowAny]
```

```python
# api/urls.py
from rest_framework.routers import DefaultRouter

router = DefaultRouter()
router.register("articles", ArticleViewSet, basename="article")
router.register("tags", TagViewSet, basename="tag")

urlpatterns = router.urls
```

### Permissions

```python
from rest_framework.permissions import BasePermission, SAFE_METHODS


class IsOwnerOrReadOnly(BasePermission):
    def has_permission(self, request, view):
        return bool(
            request.method in SAFE_METHODS
            or request.user and request.user.is_authenticated
        )

    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True
        return obj.author.user == request.user


class IsAdminOrReadOnly(BasePermission):
    def has_permission(self, request, view):
        if request.method in SAFE_METHODS:
            return True
        return request.user and request.user.is_staff
```

### Throttling

```python
# settings.py
REST_FRAMEWORK = {
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {
        "anon": "100/day",
        "user": "1000/day",
        "burst": "60/minute",
    },
}

# Custom throttle
from rest_framework.throttling import SimpleRateThrottle

class PublishThrottle(SimpleRateThrottle):
    scope = "publish"

    def get_cache_key(self, request, view):
        if not request.user.is_authenticated:
            return None
        return self.cache_format % {
            "scope": self.scope,
            "ident": request.user.pk,
        }
```

### Pagination

```python
from rest_framework.pagination import PageNumberPagination, CursorPagination


class StandardPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100
    page_query_param = "page"


class ArticleCursorPagination(CursorPagination):
    page_size = 20
    ordering = "-published_at"
    cursor_query_param = "cursor"
```

---

## 11. Settings

### Core Settings Anatomy

```python
# settings/base.py
from pathlib import Path
import environ

BASE_DIR = Path(__file__).resolve().parent.parent.parent

env = environ.Env(DEBUG=(bool, False))
environ.Env.read_env(BASE_DIR / ".env")

SECRET_KEY = env("SECRET_KEY")
DEBUG = env("DEBUG")
ALLOWED_HOSTS = env.list("ALLOWED_HOSTS", default=["localhost"])

INSTALLED_APPS = [
    # Django core
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Third-party
    "rest_framework",
    "corsheaders",
    "django_filters",
    # Project apps
    "users",
    "blog",
    "api",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "project.urls"
WSGI_APPLICATION = "project.wsgi.application"
ASGI_APPLICATION = "project.asgi.application"

DATABASES = {
    "default": env.db("DATABASE_URL", default="sqlite:///db.sqlite3"),
}

AUTH_USER_MODEL = "users.User"

AUTHENTICATION_BACKENDS = [
    "users.backends.EmailBackend",
    "django.contrib.auth.backends.ModelBackend",
]

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
     "OPTIONS": {"min_length": 12}},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_DIRS = [BASE_DIR / "static"]
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

LOGIN_URL = "login"
LOGIN_REDIRECT_URL = "/"
LOGOUT_REDIRECT_URL = "/"

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.SessionAuthentication",
        "rest_framework.authentication.TokenAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "DEFAULT_PAGINATION_CLASS": "api.pagination.StandardPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_FILTER_BACKENDS": [
        "django_filters.rest_framework.DjangoFilterBackend",
        "rest_framework.filters.SearchFilter",
        "rest_framework.filters.OrderingFilter",
    ],
}

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": env("REDIS_URL", default="redis://localhost:6379/0"),
    }
}

CELERY_BROKER_URL = env("REDIS_URL", default="redis://localhost:6379/1")
CELERY_RESULT_BACKEND = env("REDIS_URL", default="redis://localhost:6379/2")
```

### Settings Module Pattern

```
project/
  settings/
    __init__.py      # empty or: from .base import *
    base.py          # shared settings
    development.py   # DEBUG=True, console email, sqlite
    production.py    # security headers, S3, gunicorn
    test.py          # fast password hasher, in-memory cache
```

```bash
# Select via environment variable
DJANGO_SETTINGS_MODULE=project.settings.production python manage.py runserver

# Or in manage.py / wsgi.py
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "project.settings.development")
```

```python
# settings/production.py
from .base import *

DEBUG = False
SECURE_SSL_REDIRECT = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_CONTENT_TYPE_NOSNIFF = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
X_FRAME_OPTIONS = "DENY"

DEFAULT_FILE_STORAGE = "storages.backends.s3boto3.S3Boto3Storage"
STATICFILES_STORAGE = "storages.backends.s3boto3.S3StaticStorage"
AWS_STORAGE_BUCKET_NAME = env("AWS_STORAGE_BUCKET_NAME")
AWS_S3_REGION_NAME = env("AWS_S3_REGION_NAME")
```

---

## 12. Management Commands

### Built-in Commands

```bash
# Database
python manage.py migrate [app_label] [migration_name]
python manage.py makemigrations [app_label] [--name NAME] [--empty] [--merge]
python manage.py showmigrations [--list] [--plan]
python manage.py sqlmigrate app_label 0002
python manage.py dbshell                  # opens psql/mysql/sqlite3 shell

# Static files
python manage.py collectstatic [--noinput] [--clear]
python manage.py findstatic myfile.css

# Shell
python manage.py shell                    # Python REPL with Django loaded
python manage.py shell_plus               # django-extensions: auto-imports models
python manage.py shell -c "from blog.models import Article; print(Article.objects.count())"

# Data
python manage.py dumpdata blog.Article --indent 2 > articles.json
python manage.py loaddata articles.json
python manage.py flush [--noinput]
python manage.py inspectdb                # reverse-engineer models from existing DB

# Users
python manage.py createsuperuser
python manage.py changepassword [username]

# Checks
python manage.py check [--deploy]         # system checks, --deploy for production settings
python manage.py validate_templates
```

### Custom Management Commands

```python
# blog/management/commands/publish_scheduled.py
from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone
from blog.models import Article


class Command(BaseCommand):
    help = "Publish articles whose scheduled_at time has passed"

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Show what would be published without actually publishing",
        )
        parser.add_argument(
            "--limit",
            type=int,
            default=100,
            help="Maximum number of articles to publish in one run",
        )
        parser.add_argument(
            "app_labels",
            nargs="*",
            type=str,
        )

    def handle(self, *args, **options):
        dry_run = options["dry_run"]
        limit = options["limit"]
        verbosity = options["verbosity"]

        now = timezone.now()
        qs = Article.objects.filter(
            status=Article.Status.DRAFT,
            scheduled_at__lte=now,
        ).select_related("author")[:limit]

        count = qs.count()

        if verbosity >= 1:
            self.stdout.write(f"Found {count} articles to publish.")

        if dry_run:
            for article in qs:
                self.stdout.write(
                    self.style.WARNING(f"  [DRY RUN] Would publish: {article.title}")
                )
            return

        published = 0
        errors = 0
        for article in qs:
            try:
                article.status = Article.Status.PUBLISHED
                article.published_at = now
                article.save(update_fields=["status", "published_at"])
                published += 1
                if verbosity >= 2:
                    self.stdout.write(f"  Published: {article.title}")
            except Exception as e:
                errors += 1
                self.stderr.write(
                    self.style.ERROR(f"  Failed to publish '{article.title}': {e}")
                )

        self.stdout.write(
            self.style.SUCCESS(
                f"Published {published} articles. Errors: {errors}."
            )
        )
```

```bash
python manage.py publish_scheduled
python manage.py publish_scheduled --dry-run --verbosity 2
python manage.py publish_scheduled --limit 10
```

---

## 13. ASGI/WSGI

### WSGI (Traditional Synchronous)

WSGI is the Python standard for synchronous web apps (PEP 3333). Django generates a `wsgi.py` module at project creation.

```python
# project/wsgi.py
import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "project.settings.production")
application = get_wsgi_application()
```

**Gunicorn** (most common WSGI server):

```bash
gunicorn project.wsgi:application \
    --workers 4 \
    --worker-class sync \
    --bind 0.0.0.0:8000 \
    --timeout 120 \
    --keep-alive 5 \
    --max-requests 1000 \
    --max-requests-jitter 100 \
    --access-logfile - \
    --error-logfile -
```

Worker count rule of thumb: `2 * CPU_CORES + 1`. For I/O-heavy workloads use `gevent` or `eventlet` worker classes.

### ASGI (Async Support, Django 3.0+)

ASGI supports HTTP/1.1, HTTP/2, WebSockets, and long-polling. Django generates `asgi.py` at project creation.

```python
# project/asgi.py
import os
from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "project.settings.production")

# Pure Django ASGI app (HTTP only)
application = get_asgi_application()
```

For WebSocket support, layer Django Channels or route different protocols:

```python
# project/asgi.py (with Channels)
import os
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
import chat.routing

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "project.settings.production")

django_asgi_app = get_asgi_application()

application = ProtocolTypeRouter({
    "http": django_asgi_app,
    "websocket": AuthMiddlewareStack(
        URLRouter(chat.routing.websocket_urlpatterns)
    ),
})
```

**Uvicorn** (ASGI server, single process):

```bash
uvicorn project.asgi:application \
    --host 0.0.0.0 \
    --port 8000 \
    --workers 4 \
    --log-level info \
    --loop uvloop \
    --http h11
```

**Gunicorn + Uvicorn workers** (production-preferred: process management + async):

```bash
gunicorn project.asgi:application \
    --workers 4 \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:8000 \
    --timeout 120
```

**Daphne** (Channels' reference ASGI server):

```bash
daphne -b 0.0.0.0 -p 8000 project.asgi:application
```

### Async Support Progression

| Django version | Async capability |
|---|---|
| 3.0 | ASGI server support, async views |
| 3.1 | Async middleware, async tests, `sync_to_async` / `async_to_sync` in `asgiref` |
| 4.1 | Async ORM interface (`aget()`, `acreate()`, `acount()`, `aiterator()`, `abulk_create()`, etc.) |
| 4.2 | Async `ModelAdmin`, async template rendering |
| 5.0 | Full async `QuerySet` API (`afilter()` not needed — regular methods work in async context via `__aiter__`) |

**Async ORM (Django 4.1+):**

```python
# Django 4.1+ native async ORM methods
async def async_article_view(request, slug):
    article = await Article.objects.select_related("author").aget(
        slug=slug, status="published"
    )
    tags = [tag async for tag in article.tags.all()]
    comment_count = await article.comments.acount()

    return render(request, "blog/article_detail.html", {
        "article": article,
        "tags": tags,
        "comment_count": comment_count,
    })


# aiterator for large querysets
async def export_articles(request):
    lines = ["title,author,word_count\n"]
    async for article in Article.objects.filter(status="published").aiterator():
        lines.append(f"{article.title},{article.author_id},{article.word_count}\n")
    return HttpResponse("".join(lines), content_type="text/csv")
```

### Sync-Async Interop with asgiref

```python
from asgiref.sync import sync_to_async, async_to_sync


# Wrap a sync function for use in async context
get_articles = sync_to_async(
    lambda: list(Article.objects.filter(status="published")),
    thread_sensitive=True,  # run in main thread (default True for ORM)
)

# Wrap an async function for use in sync context (e.g., Celery tasks)
result = async_to_sync(some_async_function)(arg1, arg2)
```

---

## Cross-Cutting Patterns

### Request Lifecycle Summary

```
Browser
  └─> ASGI/WSGI server (Gunicorn/Uvicorn)
        └─> Django application
              ├─ MIDDLEWARE (top-down for request)
              │    SecurityMiddleware, SessionMiddleware, AuthMiddleware, ...
              ├─ URL routing (ROOT_URLCONF → include() chains)
              ├─ View dispatch (FBV/CBV)
              │    ├─ Form processing / ORM queries
              │    └─ Template rendering / JSON serialization
              └─ MIDDLEWARE (bottom-up for response)
                   Response headers, cookies, compression
```

### Key Integration Points

- **Signals + Celery:** `post_save` fires `task.delay()` — never do heavy I/O synchronously in signals.
- **Custom managers + DRF:** Set `serializer_class` but override `get_queryset()` in ViewSet to leverage manager methods (`Article.objects.published().with_stats()`).
- **Middleware + Authentication:** `request.user` is set by `AuthenticationMiddleware`; all middleware below it can rely on it.
- **Migrations + multi-DB:** `allow_migrate()` in routers controls which migrations apply to which database. Migrations themselves can call `schema_editor.connection.alias` to branch logic.
- **`AppConfig.ready()`:** The only safe place to import models and connect signals; avoids circular imports and double-import issues.
