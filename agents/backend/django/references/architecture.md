# Django Architecture Deep Reference

## ORM Internals

### QuerySet Evaluation

QuerySets are **lazy** -- they accumulate filters without hitting the database until evaluated. Evaluation triggers include: iteration, slicing with a step, `list()`, `bool()`, `len()`, `repr()`, pickling, and `str()` on the query.

```python
# This builds SQL but does NOT execute it:
qs = Article.objects.filter(status="published").order_by("-published_at")[:20]

# Evaluation happens here:
articles = list(qs)         # forces evaluation
exists = bool(qs)           # SELECT 1 ... LIMIT 1
count = qs.count()          # SELECT COUNT(*)
first = qs.first()          # ORDER BY pk LIMIT 1
```

QuerySets cache their results after the first evaluation. Iterating a second time uses the cached results. However, chaining a new method on an evaluated QuerySet creates a new unevaluated QuerySet.

### select_related vs prefetch_related

**select_related** -- SQL JOIN, single query. Works for ForeignKey and OneToOneField (forward relations only).

```python
# One query with JOIN:
articles = Article.objects.select_related("author", "category").all()
for article in articles:
    print(article.author.name)  # No extra query -- already loaded via JOIN
```

**prefetch_related** -- Separate query per relation, joined in Python. Works for ManyToManyField, reverse ForeignKey, and GenericRelation.

```python
# Two queries: articles + tags
articles = Article.objects.prefetch_related("tags").all()

# Custom prefetch with filtering:
from django.db.models import Prefetch

articles = Article.objects.prefetch_related(
    Prefetch(
        "comments",
        queryset=Comment.objects.filter(approved=True).select_related("author"),
    )
)
```

**Rule of thumb:** `select_related` for FK/O2O (forward), `prefetch_related` for M2M and reverse FK.

### Lazy Loading and the N+1 Problem

Accessing a related object that was not fetched triggers an individual query per object:

```python
# N+1 problem -- 1 query for articles + N queries for authors:
for article in Article.objects.all():
    print(article.author.name)  # Each access triggers SELECT on authors

# Fix with select_related:
for article in Article.objects.select_related("author"):
    print(article.author.name)  # No extra queries
```

### Deferred Fields -- only() and defer()

```python
# only() -- fetch only specified fields; others loaded on access (lazy)
Article.objects.only("id", "title", "slug")

# defer() -- fetch all except specified fields
Article.objects.defer("body", "rendered_html")

# values() -- returns dicts, not model instances (no methods, no __str__)
Article.objects.values("id", "title", "author__username")

# values_list() -- returns tuples or flat list
Article.objects.values_list("slug", flat=True)
```

### Aggregation and Annotation

```python
from django.db.models import Count, Avg, Sum, Subquery, OuterRef, Exists
from django.db.models.functions import TruncMonth

# Whole-queryset aggregation (returns dict):
Article.objects.aggregate(total=Count("id"), avg_words=Avg("word_count"))

# Per-object annotation:
authors = Author.objects.annotate(
    article_count=Count("articles"),
    avg_word_count=Avg("articles__word_count"),
).filter(article_count__gt=5)

# Grouping with values + annotate:
Article.objects.annotate(
    month=TruncMonth("published_at")
).values("month").annotate(count=Count("id")).order_by("month")

# Subquery:
latest = Article.objects.filter(
    author=OuterRef("pk"), status="published"
).order_by("-published_at").values("title")[:1]

Author.objects.annotate(latest_article=Subquery(latest))

# Exists subquery:
has_published = Article.objects.filter(author=OuterRef("pk"), status="published")
Author.objects.filter(Exists(has_published))
```

### Custom Managers and QuerySets

```python
class ArticleQuerySet(models.QuerySet):
    def published(self):
        return self.filter(status=Article.Status.PUBLISHED)

    def by_author(self, author):
        return self.filter(author=author)

    def with_stats(self):
        return self.annotate(
            comment_count=Count("comments"),
        ).select_related("author").prefetch_related("tags")


class ArticleManager(models.Manager):
    def get_queryset(self):
        return ArticleQuerySet(self.model, using=self._db).exclude(
            status=Article.Status.ARCHIVED
        )


class Article(models.Model):
    objects = ArticleManager()          # filtered default
    all_objects = models.Manager()      # unfiltered escape hatch
    # OR: objects = ArticleQuerySet.as_manager()
```

### Migrations Internals

Migration files live in each app's `migrations/` package. The `django_migrations` table tracks applied migrations. Each migration declares `dependencies` and `operations`.

**Migration file anatomy:**

```python
class Migration(migrations.Migration):
    dependencies = [("myapp", "0001_initial")]
    operations = [
        migrations.AddField(
            model_name="article", name="slug",
            field=models.SlugField(default=""), preserve_default=False,
        ),
        migrations.RunPython(populate_slugs, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="article", name="slug",
            field=models.SlugField(unique=True),
        ),
    ]
```

**Key operations:** `CreateModel`, `DeleteModel`, `AddField`, `RemoveField`, `AlterField`, `RenameField`, `AddIndex`, `RemoveIndex`, `AddConstraint`, `RemoveConstraint`, `RunPython`, `RunSQL`, `SeparateDatabaseAndState`.

**Data migrations with RunPython:**

```python
def populate_slugs(apps, schema_editor):
    Article = apps.get_model("myapp", "Article")
    for article in Article.objects.all():
        article.slug = slugify(article.title)
        article.save(update_fields=["slug"])
```

Always use `apps.get_model()` inside data migrations (not direct model imports) to get the model state at that point in migration history.

### Multi-Database Routing

```python
DATABASES = {
    "default": {"ENGINE": "django.db.backends.postgresql", ...},
    "replica": {"ENGINE": "django.db.backends.postgresql", ...},
}
DATABASE_ROUTERS = ["myapp.routers.PrimaryReplicaRouter"]

class PrimaryReplicaRouter:
    def db_for_read(self, model, **hints):
        return "replica"

    def db_for_write(self, model, **hints):
        return "default"

    def allow_relation(self, obj1, obj2, **hints):
        return True

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        return db == "default"
```

Manual selection: `Article.objects.using("replica").filter(...)`.

---

## Middleware Pipeline

Middleware wraps the request/response cycle in layers. Request flows top-down through `MIDDLEWARE`; response flows bottom-up.

### Hook Methods

```python
class AdvancedMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Before view
        response = self.get_response(request)
        # After view
        return response

    def process_view(self, request, view_func, view_args, view_kwargs):
        """Called just before the view. Return None to continue, HttpResponse to short-circuit."""
        return None

    def process_exception(self, request, exception):
        """Called when view raises. Return None to re-raise, HttpResponse to handle."""
        return None

    def process_template_response(self, request, response):
        """Called when view returns TemplateResponse. Can alter context."""
        return response
```

### Async Middleware

```python
class AsyncMiddleware:
    async_capable = True
    sync_capable = False

    def __init__(self, get_response):
        self.get_response = get_response

    async def __call__(self, request):
        request.tenant = await fetch_tenant(request.get_host())
        response = await self.get_response(request)
        return response
```

### Ordering Dependencies

Middleware that depends on `request.user` must come after `AuthenticationMiddleware`. `SecurityMiddleware` should be first. `CorsMiddleware` should come before `CommonMiddleware`. WhiteNoise should be second (right after SecurityMiddleware).

---

## Template Engine

### Django Template Language (DTL)

DTL is deliberately limited -- complex logic belongs in views, not templates.

```html
{% extends "base.html" %}
{% load blog_tags humanize %}

{% block content %}
<h1>{{ page_title|default:"Latest Articles" }}</h1>

{% for article in articles %}
    <article>
        <h2><a href="{% url 'blog:detail' slug=article.slug %}">{{ article.title }}</a></h2>
        <p>By {{ article.author.name }} on {{ article.published_at|date:"N j, Y" }}</p>
        <p>{{ article.body|truncatewords:50 }}</p>
    </article>
{% empty %}
    <p>No articles found.</p>
{% endfor %}

{% include "pagination.html" with page_obj=page_obj %}
{% endblock %}
```

### Custom Template Tags and Filters

```python
# blog/templatetags/blog_tags.py
from django import template
register = template.Library()

@register.filter(name="truncate_chars", is_safe=True)
def truncate_chars(value, max_length):
    if len(value) > max_length:
        return value[:max_length].rstrip() + "..."
    return value

@register.simple_tag
def get_popular_tags(count=5):
    return Tag.objects.annotate(count=Count("articles")).order_by("-count")[:count]

@register.inclusion_tag("blog/_sidebar.html", takes_context=True)
def sidebar(context):
    return {"recent": Article.objects.published().recent(5), "request": context["request"]}
```

### Context Processors

Context processors add variables to every template context:

```python
# myapp/context_processors.py
def site_settings(request):
    return {"SITE_NAME": "My Blog", "SUPPORT_EMAIL": "support@example.com"}

# settings.py -- add to TEMPLATES[0]["OPTIONS"]["context_processors"]
```

### Jinja2 Backend

Django supports Jinja2 alongside DTL. Configure via `TEMPLATES` with `django.template.backends.jinja2.Jinja2`. Create an `environment()` function to register Django's `static` and `url` helpers.

---

## Admin Internals

### ModelAdmin Customization

```python
@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    list_display = ["title", "author_link", "status", "published_at", "word_count"]
    list_filter = ["status", "tags", ("published_at", admin.DateFieldListFilter)]
    search_fields = ["title", "body", "author__name"]
    prepopulated_fields = {"slug": ("title",)}
    readonly_fields = ["word_count", "created_at"]
    raw_id_fields = ["author"]
    filter_horizontal = ["tags"]
    date_hierarchy = "published_at"
    list_per_page = 50
    save_on_top = True

    fieldsets = [
        (None, {"fields": ["title", "slug", "status", "author"]}),
        ("Content", {"fields": ["body"], "classes": ["wide"]}),
        ("Publication", {"fields": ["published_at", "tags"], "classes": ["collapse"]}),
    ]

    @admin.display(description="Author", ordering="author__name")
    def author_link(self, obj):
        url = reverse("admin:blog_author_change", args=[obj.author_id])
        return format_html('<a href="{}">{}</a>', url, obj.author.name)

    def get_queryset(self, request):
        return super().get_queryset(request).select_related("author")
```

### Inlines

```python
class CommentInline(admin.TabularInline):  # or StackedInline
    model = Comment
    extra = 1
    fields = ["user", "body", "is_approved"]
    readonly_fields = ["created_at"]
    show_change_link = True
```

### Custom AdminSite

```python
class MyAdminSite(admin.AdminSite):
    site_header = "My Blog Administration"
    site_title = "My Blog Admin"
    index_title = "Dashboard"

my_admin_site = MyAdminSite(name="myadmin")
my_admin_site.register(Article, ArticleAdmin)
```

---

## Authentication System

### Custom User Models

**AbstractUser** -- keeps all built-in fields, extend with your own:

```python
class User(AbstractUser):
    bio = models.TextField(blank=True)
    avatar = models.ImageField(upload_to="avatars/", blank=True)
```

**AbstractBaseUser** -- full control, implement everything:

```python
class User(AbstractBaseUser, PermissionsMixin):
    email = models.EmailField(unique=True)
    name = models.CharField(max_length=200)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["name"]
    objects = UserManager()
```

### Authentication Backends

```python
class EmailBackend(ModelBackend):
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

# settings.py
AUTHENTICATION_BACKENDS = [
    "myapp.auth_backends.EmailBackend",
    "django.contrib.auth.backends.ModelBackend",
]
```

### Permissions and Groups

```python
user.has_perm("blog.add_article")
user.has_perm("blog.change_article", obj)  # object-level

# Custom model-level permissions
class Article(models.Model):
    class Meta:
        permissions = [
            ("publish_article", "Can publish articles"),
            ("feature_article", "Can feature articles on homepage"),
        ]
```

---

## Signals

Signals allow decoupled components to react to events.

### Core Signals

- `pre_save` / `post_save` -- before/after `Model.save()`
- `pre_delete` / `post_delete` -- before/after `Model.delete()`
- `m2m_changed` -- when M2M relations change
- `request_started` / `request_finished` -- HTTP lifecycle

### Connecting Receivers

```python
from django.db.models.signals import post_save
from django.dispatch import receiver

@receiver(post_save, sender=User)
def create_author_profile(sender, instance, created, **kwargs):
    if created:
        Author.objects.create(user=instance, name=instance.get_full_name())
```

### Best Practices

- Always accept `**kwargs` in receivers.
- Connect signals in `AppConfig.ready()` to avoid import side effects.
- Prefer `dispatch_uid` to prevent duplicate receivers.
- Avoid heavy operations in receivers -- offload to background tasks.

---

## Forms

### ModelForm

```python
class ArticleForm(forms.ModelForm):
    class Meta:
        model = Article
        fields = ["title", "slug", "body", "status"]
        widgets = {"body": forms.Textarea(attrs={"rows": 20})}

    def clean_slug(self):
        slug = self.cleaned_data["slug"]
        qs = Article.objects.filter(slug=slug)
        if self.instance.pk:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise ValidationError("Slug already exists.")
        return slug

    def clean(self):
        cleaned = super().clean()
        if cleaned.get("status") == "published" and not cleaned.get("body"):
            raise ValidationError("Published articles must have a body.")
        return cleaned
```

### Formsets

```python
from django.forms import inlineformset_factory

CommentFormSet = inlineformset_factory(
    Article, Comment,
    fields=["body", "is_approved"],
    extra=1, can_delete=True,
)
```

---

## Management Commands

### Custom Commands

```python
# myapp/management/commands/cleanup_articles.py
from django.core.management.base import BaseCommand

class Command(BaseCommand):
    help = "Archive articles older than N days"

    def add_arguments(self, parser):
        parser.add_argument("days", type=int)
        parser.add_argument("--dry-run", action="store_true")

    def handle(self, *args, **options):
        cutoff = timezone.now() - timedelta(days=options["days"])
        qs = Article.objects.filter(published_at__lt=cutoff, status="published")
        count = qs.count()
        if not options["dry_run"]:
            qs.update(status="archived")
        self.stdout.write(self.style.SUCCESS(f"{'Would archive' if options['dry_run'] else 'Archived'} {count} articles"))
```

### Essential Built-in Commands

```bash
python manage.py migrate                      # apply migrations
python manage.py makemigrations               # generate migrations
python manage.py createsuperuser              # create admin user
python manage.py collectstatic --noinput      # gather static files
python manage.py shell                        # Django-aware Python REPL
python manage.py dbshell                      # database shell
python manage.py check --deploy               # production audit
python manage.py test                         # run tests
python manage.py dumpdata myapp --indent 2    # export data as JSON
python manage.py loaddata fixtures.json       # import data
python manage.py inspectdb                    # reverse-engineer models from DB
```
