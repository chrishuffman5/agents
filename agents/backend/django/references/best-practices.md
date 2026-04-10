# Django Best Practices Reference

## Django REST Framework Patterns

### Serializers

**ModelSerializer** -- auto-generates fields from a model:

```python
class ArticleSerializer(serializers.ModelSerializer):
    author = AuthorSerializer(read_only=True)
    author_id = serializers.PrimaryKeyRelatedField(
        queryset=Author.objects.all(), source="author", write_only=True,
    )
    tags = TagSerializer(many=True, read_only=True)
    tag_ids = serializers.PrimaryKeyRelatedField(
        queryset=Tag.objects.all(), source="tags", many=True,
        write_only=True, required=False,
    )

    class Meta:
        model = Article
        fields = ["id", "title", "slug", "author", "author_id", "tags", "tag_ids", "status", "body"]
        read_only_fields = ["id"]

    def validate_slug(self, value):
        qs = Article.objects.filter(slug=value)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError("Slug must be unique.")
        return value

    def validate(self, attrs):
        if attrs.get("status") == "published" and not attrs.get("body"):
            raise serializers.ValidationError({"body": "Required for published articles."})
        return attrs

    def create(self, validated_data):
        tags = validated_data.pop("tags", [])
        article = Article.objects.create(**validated_data)
        article.tags.set(tags)
        return article
```

**Writable nested serializers** require overriding `create()` and `update()` because DRF does not handle nested writes automatically. For complex cases, consider `drf-writable-nested`.

### ViewSets and Routers

```python
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
        return Article.objects.select_related("author").prefetch_related("tags")

    def perform_create(self, serializer):
        serializer.save(author=self.request.user.author)

    @action(detail=True, methods=["post"], permission_classes=[permissions.IsAdminUser])
    def publish(self, request, slug=None):
        article = self.get_object()
        article.status = Article.Status.PUBLISHED
        article.save(update_fields=["status"])
        return Response(ArticleSerializer(article, context={"request": request}).data)
```

**ReadOnlyModelViewSet** for endpoints that should never mutate:

```python
class CategoryViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
```

### Permissions

```python
class IsOwnerOrReadOnly(BasePermission):
    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True
        return obj.author.user == request.user

class IsVerifiedUser(BasePermission):
    message = "Email verification required."

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.profile.email_verified)
```

Apply globally or per-view:

```python
REST_FRAMEWORK = {
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
}
```

### Authentication

**JWT via djangorestframework-simplejwt:**

```python
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=15),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
}

# urls.py
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
urlpatterns = [
    path("api/token/", TokenObtainPairView.as_view()),
    path("api/token/refresh/", TokenRefreshView.as_view()),
]
```

### Throttling

```python
REST_FRAMEWORK = {
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {"anon": "100/day", "user": "1000/day"},
}
```

### Pagination

```python
class StandardPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100

# CursorPagination for real-time feeds (no offset drift):
class ArticleCursorPagination(CursorPagination):
    page_size = 20
    ordering = "-created_at"  # must be an indexed field
```

### Filtering with django-filter

```python
class ArticleFilter(django_filters.FilterSet):
    title = django_filters.CharFilter(lookup_expr="icontains")
    author = django_filters.CharFilter(field_name="author__username")
    created_after = django_filters.DateFilter(field_name="created_at", lookup_expr="gte")

    class Meta:
        model = Article
        fields = ["published", "category"]
```

---

## Testing

### Test Class Types

| Class | DB Behavior | Use Case |
|---|---|---|
| `SimpleTestCase` | No DB access | Pure logic, forms, URL resolution |
| `TestCase` | Transaction per test (rollback) | Most unit/integration tests |
| `TransactionTestCase` | Flushes DB between tests | `on_commit` hooks, signals, raw transactions |

### Django TestCase

```python
class ArticleModelTest(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = User.objects.create_user("testuser", password="testpass")

    def test_str_representation(self):
        article = Article(title="Test Article", author=self.user)
        self.assertEqual(str(article), "Test Article")
```

### DRF APITestCase

```python
class ArticleAPITest(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user("testuser", password="testpass")
        self.token = Token.objects.create(user=self.user)
        self.client = APIClient()
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {self.token.key}")

    def test_create_article(self):
        response = self.client.post("/api/articles/", {"title": "New", "body": "Content"}, format="json")
        self.assertEqual(response.status_code, 201)
```

### pytest-django

```python
# conftest.py
import pytest
from .factories import UserFactory, ArticleFactory

@pytest.fixture
def user(db):
    return UserFactory()

@pytest.fixture
def auth_client(user):
    client = APIClient()
    token = Token.objects.create(user=user)
    client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
    return client

# test_articles.py
@pytest.mark.django_db
def test_article_creation(auth_client):
    response = auth_client.post("/api/articles/", {"title": "Test", "body": "Content"})
    assert response.status_code == 201
```

### factory_boy

```python
class UserFactory(DjangoModelFactory):
    class Meta:
        model = get_user_model()
    username = factory.Sequence(lambda n: f"user{n}")
    email = factory.LazyAttribute(lambda o: f"{o.username}@example.com")
    password = factory.PostGenerationMethodCall("set_password", "testpass123")

class ArticleFactory(DjangoModelFactory):
    class Meta:
        model = Article
    title = factory.Faker("sentence", nb_words=4)
    body = factory.Faker("paragraphs", nb=3)
    author = factory.SubFactory(UserFactory)
    published = True
```

### Coverage

```bash
pytest --cov=myapp --cov-report=html --cov-report=term-missing

# .coveragerc
[run]
source = .
omit = */migrations/*, */tests/*, manage.py, */settings/*

[report]
fail_under = 85
```

---

## Deployment

### Gunicorn + Nginx (WSGI)

```bash
gunicorn config.wsgi:application \
    --workers 4 \
    --threads 2 \
    --worker-class gthread \
    --bind 0.0.0.0:8000 \
    --timeout 30 \
    --max-requests 1000 \
    --max-requests-jitter 100
```

Worker count rule of thumb: `2 * CPU_cores + 1`.

```nginx
upstream django {
    server 127.0.0.1:8000;
}
server {
    listen 443 ssl http2;
    location /static/ { alias /app/staticfiles/; expires 1y; }
    location /media/ { alias /app/media/; }
    location / {
        proxy_pass http://django;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Uvicorn (ASGI)

```bash
# Standalone:
uvicorn config.asgi:application --workers 4 --host 0.0.0.0 --port 8000

# Managed by Gunicorn:
gunicorn config.asgi:application \
    --workers 4 \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:8000
```

### Static Files with WhiteNoise

```python
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",  # Must be second
    # ...
]

# Django 4.2+ STORAGES syntax:
STORAGES = {
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
}
```

```bash
python manage.py collectstatic --noinput
```

### Docker (Multi-Stage)

```dockerfile
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends libpq5 && rm -rf /var/lib/apt/lists/*
COPY --from=builder /wheels /wheels
RUN pip install --no-cache /wheels/*
COPY . .
RUN python manage.py collectstatic --noinput
EXPOSE 8000
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "4"]
```

### Environment Variables

```python
# pip install django-environ
import environ
env = environ.Env(DEBUG=(bool, False))
environ.Env.read_env(BASE_DIR / ".env")

SECRET_KEY = env("SECRET_KEY")
DATABASES = {"default": env.db("DATABASE_URL")}
CACHES = {"default": env.cache("REDIS_URL")}
```

### Health Checks

```python
def health_check(request):
    checks = {}
    status_code = 200
    try:
        connection.ensure_connection()
        checks["database"] = "ok"
    except Exception as e:
        checks["database"] = str(e)
        status_code = 503
    return JsonResponse({"status": "ok" if status_code == 200 else "error", "checks": checks}, status=status_code)
```

---

## Security

### CSRF Protection

Django's `CsrfViewMiddleware` is enabled by default. For AJAX:

```javascript
fetch("/api/articles/", {
    method: "POST",
    headers: {"X-CSRFToken": getCookie("csrftoken")},
    body: JSON.stringify(data),
});
```

For DRF APIs with JWT or Token auth, CSRF is not required (non-session auth).

### HTTPS and HSTS

```python
# settings/production.py
SECURE_SSL_REDIRECT = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_CONTENT_TYPE_NOSNIFF = True
```

### Content-Security-Policy (Pre-6.0)

```python
# pip install django-csp
MIDDLEWARE = [..., "csp.middleware.CSPMiddleware"]

CSP_DEFAULT_SRC = ("'none'",)
CSP_SCRIPT_SRC = ("'self'",)
CSP_STYLE_SRC = ("'self'",)
CSP_IMG_SRC = ("'self'", "data:", "https://cdn.example.com")
CSP_FRAME_ANCESTORS = ("'none'",)
```

Django 6.0 adds built-in CSP middleware -- see `6.0/SKILL.md`.

### Password Hashing

```python
# pip install argon2-cffi
PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.Argon2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",  # fallback
]
```

Existing passwords are transparently upgraded on next login.

### SQL Injection Prevention

The ORM parameterizes all queries. For raw SQL, always use parameterized queries:

```python
# Safe:
cursor.execute("SELECT * FROM articles WHERE title = %s", [user_input])

# DANGEROUS -- never do this:
cursor.execute(f"SELECT * FROM articles WHERE title = '{user_input}'")
```

### Production Security Audit

```bash
python manage.py check --deploy
```

---

## Performance

### N+1 Fixes

```python
# select_related for FK/O2O (SQL JOIN):
Article.objects.select_related("author", "category")

# prefetch_related for M2M and reverse FK (separate query):
Article.objects.prefetch_related("tags", "comments")

# Custom prefetch with filtering:
Article.objects.prefetch_related(
    Prefetch("comments", queryset=Comment.objects.filter(approved=True))
)
```

### Database Indexes

```python
class Meta:
    indexes = [
        models.Index(fields=["status", "published_at"]),
        models.Index(
            fields=["published_at"],
            condition=Q(status="published"),  # partial index (PostgreSQL)
            name="published_articles_idx",
        ),
    ]
```

### Caching

```python
# Per-view:
@cache_page(60 * 15)
def article_list(request): ...

# Template fragment:
{% cache 900 article_sidebar user.id %}...{% endcache %}

# Low-level API:
from django.core.cache import cache
articles = cache.get_or_set("popular", get_from_db, timeout=300)

# Redis backend:
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": "redis://127.0.0.1:6379/1",
        "KEY_PREFIX": "myapp",
    }
}
```

### Connection Pooling

**PgBouncer** (external, preferred for production):

```ini
[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
```

**Django 5.1+ psycopg3 pool** (built-in):

```python
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "OPTIONS": {
            "pool": {"min_size": 2, "max_size": 10, "timeout": 30},
        },
    }
}
```

### Query Optimization

```python
# only() / defer() for field selection:
Article.objects.only("id", "title", "slug")
Article.objects.defer("body", "rendered_html")

# values() for lightweight dict results:
Article.objects.values("id", "title", "author__username")

# Aggregation instead of Python loops:
Author.objects.annotate(article_count=Count("articles")).filter(article_count__gt=0)
```

---

## Project Structure

### Recommended Layout

```
myproject/
    config/
        __init__.py
        asgi.py, wsgi.py, celery.py
        urls.py
        settings/
            base.py, development.py, production.py, test.py
    apps/
        accounts/           # Custom user model, auth
        articles/           # Domain logic
        common/             # Abstract models, shared utils, pagination
            models.py       # TimeStampedModel, UUIDModel
            pagination.py
            permissions.py
    static/
    templates/
    requirements/
        base.txt, development.txt, production.txt
    Dockerfile, docker-compose.yml
    manage.py, pyproject.toml, pytest.ini
```

### Abstract Base Models

```python
# apps/common/models.py
class TimeStampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True
```

### Production Checklist

| Category | Item | Setting |
|---|---|---|
| Security | Debug off | `DEBUG = False` |
| Security | Secret from env | `SECRET_KEY = env("SECRET_KEY")` |
| Security | HTTPS redirect | `SECURE_SSL_REDIRECT = True` |
| Security | HSTS | `SECURE_HSTS_SECONDS = 31536000` |
| Security | Secure cookies | `SESSION_COOKIE_SECURE = CSRF_COOKIE_SECURE = True` |
| Performance | DB pooling | PgBouncer or `conn_max_age=600` |
| Performance | Redis cache | `CACHES = {"default": env.cache("REDIS_URL")}` |
| Performance | Static files | `collectstatic` + WhiteNoise or CDN |
| Observability | Health endpoint | `/health/` with DB + cache checks |
| Deployment | Gunicorn workers | `2 * CPUs + 1` |
| Testing | Coverage gate | `fail_under = 85` |
