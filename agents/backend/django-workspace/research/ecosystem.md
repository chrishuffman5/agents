# Django Ecosystem Research

Target audience: Production Django deployments. Last updated: 2026-04-09.

---

## 1. Django REST Framework (DRF)

### Serializers

**ModelSerializer** — Auto-generates fields from a model. The most common starting point.

```python
from rest_framework import serializers
from .models import Article, Tag

class ArticleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Article
        fields = ['id', 'title', 'body', 'author', 'created_at']
        read_only_fields = ['id', 'created_at']
```

**Nested serializers (read-only)** — Embed related objects inline.

```python
class AuthorSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email']

class ArticleSerializer(serializers.ModelSerializer):
    author = AuthorSerializer(read_only=True)

    class Meta:
        model = Article
        fields = ['id', 'title', 'author']
```

**Writable nested serializers** — Require overriding `create` and `update` because DRF does not handle nested writes automatically.

```python
class TagSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tag
        fields = ['id', 'name']

class ArticleSerializer(serializers.ModelSerializer):
    tags = TagSerializer(many=True)

    class Meta:
        model = Article
        fields = ['id', 'title', 'tags']

    def create(self, validated_data):
        tags_data = validated_data.pop('tags', [])
        article = Article.objects.create(**validated_data)
        for tag_data in tags_data:
            tag, _ = Tag.objects.get_or_create(**tag_data)
            article.tags.add(tag)
        return article

    def update(self, instance, validated_data):
        tags_data = validated_data.pop('tags', [])
        instance = super().update(instance, validated_data)
        instance.tags.clear()
        for tag_data in tags_data:
            tag, _ = Tag.objects.get_or_create(**tag_data)
            instance.tags.add(tag)
        return instance
```

For complex writable nesting at scale, consider **drf-writable-nested** package.

**Custom field-level validation:**

```python
class ArticleSerializer(serializers.ModelSerializer):
    def validate_title(self, value):
        if len(value) < 5:
            raise serializers.ValidationError("Title must be at least 5 characters.")
        return value

    def validate(self, data):
        # Cross-field validation
        if data['publish_date'] < data['created_at']:
            raise serializers.ValidationError("Publish date cannot be before creation.")
        return data
```

---

### ViewSets + Routers

ViewSets combine related views into a single class. Routers auto-generate URL patterns.

```python
# views.py
from rest_framework import viewsets, permissions
from .models import Article
from .serializers import ArticleSerializer

class ArticleViewSet(viewsets.ModelViewSet):
    queryset = Article.objects.select_related('author').all()
    serializer_class = ArticleSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_queryset(self):
        # Scope queryset per user if needed
        qs = super().get_queryset()
        if self.action in ['list', 'retrieve']:
            return qs.filter(published=True)
        return qs.filter(author=self.request.user)

    def perform_create(self, serializer):
        serializer.save(author=self.request.user)
```

```python
# urls.py
from rest_framework.routers import DefaultRouter
from .views import ArticleViewSet

router = DefaultRouter()
router.register(r'articles', ArticleViewSet, basename='article')

urlpatterns = router.urls
# Generates: GET/POST /articles/, GET/PUT/PATCH/DELETE /articles/{pk}/
```

**ReadOnlyModelViewSet** — For endpoints that should never mutate:

```python
class CategoryViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
```

**Custom actions with `@action`:**

```python
from rest_framework.decorators import action
from rest_framework.response import Response

class ArticleViewSet(viewsets.ModelViewSet):
    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def publish(self, request, pk=None):
        article = self.get_object()
        article.published = True
        article.save()
        return Response({'status': 'published'})
    # URL: POST /articles/{pk}/publish/
```

---

### APIView

Lower-level than ViewSets; gives full control per HTTP method.

```python
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

class ArticleListView(APIView):
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get(self, request):
        articles = Article.objects.filter(published=True)
        serializer = ArticleSerializer(articles, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = ArticleSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(author=request.user)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
```

---

### Permissions

**Built-in:**
- `AllowAny` — No restriction
- `IsAuthenticated` — Must be logged in
- `IsAdminUser` — Must be staff
- `IsAuthenticatedOrReadOnly` — Read-only for anonymous

**Custom permissions:**

```python
from rest_framework.permissions import BasePermission

class IsOwnerOrReadOnly(BasePermission):
    """Allow write access only to the object's owner."""

    def has_object_permission(self, request, view, obj):
        if request.method in ('GET', 'HEAD', 'OPTIONS'):
            return True
        return obj.author == request.user

class IsVerifiedUser(BasePermission):
    message = "Email verification required."

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.profile.email_verified
        )
```

Apply per-view or globally in settings:

```python
# settings.py
REST_FRAMEWORK = {
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ]
}
```

---

### Throttling

Prevent abuse by rate-limiting requests.

```python
# settings.py
REST_FRAMEWORK = {
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '100/day',
        'user': '1000/day',
    }
}
```

**Custom throttle scope:**

```python
class BurstRateThrottle(UserRateThrottle):
    scope = 'burst'

class SustainedRateThrottle(UserRateThrottle):
    scope = 'sustained'

# settings.py
'DEFAULT_THROTTLE_RATES': {
    'burst': '60/min',
    'sustained': '1000/day',
}
```

---

### Pagination

**PageNumberPagination:**

```python
from rest_framework.pagination import PageNumberPagination

class StandardPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100

# settings.py
REST_FRAMEWORK = {
    'DEFAULT_PAGINATION_CLASS': 'myapp.pagination.StandardPagination',
    'PAGE_SIZE': 20,
}
```

Response: `{"count": 500, "next": "...", "previous": "...", "results": [...]}`

**CursorPagination** — Stable for real-time feeds; no offset drift:

```python
from rest_framework.pagination import CursorPagination

class ArticleCursorPagination(CursorPagination):
    page_size = 20
    ordering = '-created_at'  # Must be an indexed field
```

**LimitOffsetPagination** — Flexible but has the offset drift problem at scale:

```python
from rest_framework.pagination import LimitOffsetPagination

class FlexiblePagination(LimitOffsetPagination):
    default_limit = 20
    max_limit = 100
# Query params: ?limit=20&offset=40
```

---

### Filtering

**django-filter integration:**

```python
# Install: pip install django-filter

# filters.py
import django_filters
from .models import Article

class ArticleFilter(django_filters.FilterSet):
    title = django_filters.CharFilter(lookup_expr='icontains')
    author = django_filters.CharFilter(field_name='author__username')
    created_after = django_filters.DateFilter(field_name='created_at', lookup_expr='gte')
    tags = django_filters.ModelMultipleChoiceFilter(queryset=Tag.objects.all())

    class Meta:
        model = Article
        fields = ['published', 'category']

# views.py
from django_filters.rest_framework import DjangoFilterBackend

class ArticleViewSet(viewsets.ModelViewSet):
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_class = ArticleFilter
    search_fields = ['title', 'body', 'author__username']  # ?search=term
    ordering_fields = ['created_at', 'title']             # ?ordering=-created_at
    ordering = ['-created_at']                            # Default ordering
```

```python
# settings.py
INSTALLED_APPS = ['django_filters']
REST_FRAMEWORK = {
    'DEFAULT_FILTER_BACKENDS': ['django_filters.rest_framework.DjangoFilterBackend']
}
```

---

### Authentication

**Token Authentication (DRF built-in):**

```python
# settings.py
INSTALLED_APPS = ['rest_framework.authtoken']
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.TokenAuthentication',
    ]
}

# Create token on user creation
from rest_framework.authtoken.models import Token
from django.db.models.signals import post_save

@receiver(post_save, sender=User)
def create_auth_token(sender, instance=None, created=False, **kwargs):
    if created:
        Token.objects.create(user=instance)
```

Client sends: `Authorization: Token <token>`

**JWT via djangorestframework-simplejwt:**

```python
# pip install djangorestframework-simplejwt

# settings.py
from datetime import timedelta

INSTALLED_APPS = ['rest_framework_simplejwt']
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ]
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=15),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'ALGORITHM': 'HS256',
    'AUTH_HEADER_TYPES': ('Bearer',),
}

# urls.py
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

urlpatterns = [
    path('api/token/', TokenObtainPairView.as_view()),
    path('api/token/refresh/', TokenRefreshView.as_view()),
]
```

**Session Authentication** — Default for browser-based DRF browsable API; uses Django's session framework. Requires CSRF token for non-safe methods.

---

## 2. Testing

### Test Class Types

| Class | DB Wrapping | Use Case |
|---|---|---|
| `SimpleTestCase` | No DB | Pure logic, forms, URL resolution |
| `TestCase` | Transaction per test (rollback) | Most unit/integration tests |
| `TransactionTestCase` | Flushes DB between tests | Tests involving `on_commit`, signals, raw transactions |

```python
from django.test import TestCase, Client
from django.contrib.auth import get_user_model

User = get_user_model()

class ArticleModelTest(TestCase):
    @classmethod
    def setUpTestData(cls):
        # Runs once per class — fast
        cls.user = User.objects.create_user('testuser', password='testpass')

    def test_str_representation(self):
        from .models import Article
        article = Article(title="Test Article", author=self.user)
        self.assertEqual(str(article), "Test Article")

    def test_publish_sets_flag(self):
        article = Article.objects.create(title="Draft", author=self.user)
        article.publish()
        article.refresh_from_db()
        self.assertTrue(article.published)
```

### Client and RequestFactory

**Client** — Full request/response cycle including middleware:

```python
class ArticleViewTest(TestCase):
    def setUp(self):
        self.client = Client()
        self.user = User.objects.create_user('testuser', password='testpass')

    def test_article_list_requires_login(self):
        response = self.client.get('/api/articles/')
        self.assertEqual(response.status_code, 403)

    def test_authenticated_list(self):
        self.client.login(username='testuser', password='testpass')
        response = self.client.get('/api/articles/')
        self.assertEqual(response.status_code, 200)
```

**RequestFactory** — Creates requests without middleware; faster for testing views in isolation:

```python
from django.test import RequestFactory

class ArticleViewUnitTest(TestCase):
    def setUp(self):
        self.factory = RequestFactory()
        self.user = User.objects.create_user('testuser', password='testpass')

    def test_view_returns_200(self):
        request = self.factory.get('/api/articles/')
        request.user = self.user
        view = ArticleListView.as_view()
        response = view(request)
        self.assertEqual(response.status_code, 200)
```

### DRF APIClient

```python
from rest_framework.test import APITestCase, APIClient
from rest_framework.authtoken.models import Token

class ArticleAPITest(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user('testuser', password='testpass')
        self.token = Token.objects.create(user=self.user)
        self.client = APIClient()
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')

    def test_create_article(self):
        data = {'title': 'New Article', 'body': 'Content here.'}
        response = self.client.post('/api/articles/', data, format='json')
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['title'], 'New Article')

    def test_list_articles(self):
        response = self.client.get('/api/articles/')
        self.assertEqual(response.status_code, 200)
        self.assertIn('results', response.data)  # Paginated
```

### Fixtures

JSON fixtures for static reference data:

```bash
python manage.py dumpdata myapp.Category --indent 2 > fixtures/categories.json
python manage.py loaddata fixtures/categories.json
```

```python
class ArticleTest(TestCase):
    fixtures = ['categories.json', 'users.json']

    def test_category_exists(self):
        from .models import Category
        self.assertTrue(Category.objects.filter(slug='tech').exists())
```

Fixtures are brittle for complex relationships. Prefer **factory_boy** for dynamic test data.

### factory_boy

```python
# pip install factory-boy

import factory
from factory.django import DjangoModelFactory
from django.contrib.auth import get_user_model
from .models import Article

class UserFactory(DjangoModelFactory):
    class Meta:
        model = get_user_model()

    username = factory.Sequence(lambda n: f'user{n}')
    email = factory.LazyAttribute(lambda o: f'{o.username}@example.com')
    password = factory.PostGenerationMethodCall('set_password', 'testpass123')

class ArticleFactory(DjangoModelFactory):
    class Meta:
        model = Article

    title = factory.Faker('sentence', nb_words=4)
    body = factory.Faker('paragraphs', nb=3, ext_word_list=None)
    author = factory.SubFactory(UserFactory)
    published = True

# Usage in tests:
class ArticleTest(TestCase):
    def test_author_can_see_own_drafts(self):
        user = UserFactory()
        published = ArticleFactory(author=user, published=True)
        draft = ArticleFactory(author=user, published=False)
        # Assert draft visible only to author...
```

### pytest-django

```python
# pip install pytest-django

# pytest.ini or pyproject.toml
[pytest]
DJANGO_SETTINGS_MODULE = config.settings.test
python_files = tests.py test_*.py *_test.py

# conftest.py
import pytest
from .factories import UserFactory, ArticleFactory

@pytest.fixture
def user(db):
    return UserFactory()

@pytest.fixture
def auth_client(user):
    from rest_framework.test import APIClient
    from rest_framework.authtoken.models import Token
    client = APIClient()
    token = Token.objects.create(user=user)
    client.credentials(HTTP_AUTHORIZATION=f'Token {token.key}')
    return client

# test_articles.py
@pytest.mark.django_db
def test_article_creation(auth_client):
    response = auth_client.post('/api/articles/', {'title': 'Test', 'body': 'Content'})
    assert response.status_code == 201
    assert response.data['title'] == 'Test'

@pytest.mark.django_db(transaction=True)
def test_article_signal_fires(user):
    # Use transaction=True for on_commit hooks
    article = ArticleFactory(author=user)
    # assert signal side effect...
```

### Coverage

```bash
pip install coverage pytest-cov

# Run with coverage
pytest --cov=myapp --cov-report=html --cov-report=term-missing

# .coveragerc
[run]
source = .
omit =
    */migrations/*
    */tests/*
    manage.py
    */settings/*

[report]
fail_under = 85
```

### Test Database

Django creates a test database automatically (prefix `test_`). Key options:

```python
# settings/test.py
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': ':memory:',  # Fast in-memory DB for tests
    }
}
```

For PostgreSQL-specific features in tests, use a real Postgres test DB:

```bash
pytest --reuse-db  # pytest-django: reuse schema across runs (faster)
```

---

## 3. Deployment

### Gunicorn + Nginx

**Gunicorn** serves the WSGI app; Nginx handles SSL termination, static files, and proxying.

```bash
# Install
pip install gunicorn

# Run (production)
gunicorn config.wsgi:application \
    --workers 4 \
    --threads 2 \
    --worker-class gthread \
    --bind 0.0.0.0:8000 \
    --timeout 30 \
    --max-requests 1000 \
    --max-requests-jitter 100 \
    --access-logfile - \
    --error-logfile -
```

Worker count rule of thumb: `2 * CPU_cores + 1`

**Nginx config:**

```nginx
upstream django {
    server 127.0.0.1:8000;
}

server {
    listen 80;
    server_name example.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    client_max_body_size 20M;

    location /static/ {
        alias /app/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias /app/media/;
    }

    location / {
        proxy_pass http://django;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Uvicorn for Async (ASGI)

Use with Django 3.1+ ASGI support or Django Channels:

```bash
pip install uvicorn[standard]

uvicorn config.asgi:application \
    --workers 4 \
    --host 0.0.0.0 \
    --port 8000

# Or with gunicorn managing uvicorn workers:
gunicorn config.asgi:application \
    --workers 4 \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:8000
```

**config/asgi.py:**

```python
import os
from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.production')
application = get_asgi_application()
```

### Docker Patterns

**Dockerfile (multi-stage):**

```dockerfile
# Stage 1: Build dependencies
FROM python:3.12-slim AS builder

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

# Stage 2: Runtime
FROM python:3.12-slim

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /wheels /wheels
RUN pip install --no-cache /wheels/*

COPY . .

RUN python manage.py collectstatic --noinput

EXPOSE 8000

CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "4"]
```

**docker-compose.yml (development):**

```yaml
version: '3.9'

services:
  db:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: myapp
      POSTGRES_PASSWORD: ${DB_PASSWORD}

  redis:
    image: redis:7-alpine

  web:
    build: .
    command: python manage.py runserver 0.0.0.0:8000
    volumes:
      - .:/app
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgres://myapp:${DB_PASSWORD}@db:5432/myapp
      - REDIS_URL=redis://redis:6379/0
      - DJANGO_SETTINGS_MODULE=config.settings.development
    depends_on:
      - db
      - redis

  celery:
    build: .
    command: celery -A config worker -l info
    volumes:
      - .:/app
    environment:
      - DATABASE_URL=postgres://myapp:${DB_PASSWORD}@db:5432/myapp
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis

volumes:
  postgres_data:
```

### Static Files

**collectstatic** gathers all static files into `STATIC_ROOT`:

```python
# settings.py
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_DIRS = [BASE_DIR / 'static']  # App-specific static sources
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'
```

**WhiteNoise** — Serve static files directly from Django/Gunicorn without Nginx (suitable for Heroku/PaaS):

```python
# pip install whitenoise

# settings.py
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',  # Must be second
    # ...
]
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'
```

**CDN Pattern** — Set `STATIC_URL` to CDN base URL after uploading via CI/CD:

```python
# settings/production.py
STATIC_URL = 'https://cdn.example.com/static/'
```

### Media Files

User-uploaded files. Never serve from the same process as static in production.

```python
# settings.py
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'
```

For production, use **django-storages** with S3:

```python
# pip install django-storages[s3] boto3

# settings/production.py
DEFAULT_FILE_STORAGE = 'storages.backends.s3boto3.S3Boto3Storage'
AWS_STORAGE_BUCKET_NAME = 'my-media-bucket'
AWS_S3_REGION_NAME = 'us-east-1'
AWS_S3_FILE_OVERWRITE = False
AWS_DEFAULT_ACL = None  # Use bucket policy
AWS_S3_OBJECT_PARAMETERS = {'CacheControl': 'max-age=86400'}
```

### Environment Variables with django-environ

```python
# pip install django-environ

# settings/base.py
import environ

env = environ.Env(
    DEBUG=(bool, False),
    ALLOWED_HOSTS=(list, []),
)

environ.Env.read_env(BASE_DIR / '.env')

SECRET_KEY = env('SECRET_KEY')
DEBUG = env('DEBUG')
ALLOWED_HOSTS = env('ALLOWED_HOSTS')
DATABASES = {'default': env.db('DATABASE_URL')}
CACHES = {'default': env.cache('REDIS_URL')}
EMAIL_CONFIG = env.email('EMAIL_URL', default='smtp://localhost:25')
```

`.env` file (never commit):

```
SECRET_KEY=your-secret-key-here
DEBUG=False
DATABASE_URL=postgres://user:pass@localhost:5432/mydb
REDIS_URL=redis://localhost:6379/0
ALLOWED_HOSTS=example.com,www.example.com
```

### Health Checks

```python
# apps/health/views.py
from django.http import JsonResponse
from django.db import connection

def health_check(request):
    checks = {}
    status = 200

    # Database
    try:
        connection.ensure_connection()
        checks['database'] = 'ok'
    except Exception as e:
        checks['database'] = str(e)
        status = 503

    # Cache (optional)
    try:
        from django.core.cache import cache
        cache.set('health_check', 'ok', 30)
        assert cache.get('health_check') == 'ok'
        checks['cache'] = 'ok'
    except Exception as e:
        checks['cache'] = str(e)
        status = 503

    return JsonResponse({'status': 'ok' if status == 200 else 'error', 'checks': checks}, status=status)

# urls.py
path('health/', health_check, name='health_check'),
```

For Kubernetes, expose separate `/readyz` (ready) and `/livez` (alive) endpoints.

---

## 4. Security

### CSRF Protection

Django's `CsrfViewMiddleware` is enabled by default. For AJAX requests:

```javascript
// Include CSRF token from cookie in AJAX headers
function getCookie(name) {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) return parts.pop().split(';').shift();
}
fetch('/api/articles/', {
    method: 'POST',
    headers: {'X-CSRFToken': getCookie('csrftoken')},
    body: JSON.stringify(data),
});
```

For DRF APIs used by mobile/SPA clients, use JWT or Token auth (CSRF not required for non-session auth).

### XSS Prevention

Django auto-escapes template variables. Risks:
- `mark_safe()` — only use on truly safe content
- `|safe` filter — avoid with user input
- `format_html()` — safe string interpolation in Python

```python
from django.utils.html import format_html

def render_link(url, text):
    # Correct: format_html escapes arguments
    return format_html('<a href="{}">{}</a>', url, text)
```

Content-Security-Policy header (see Security Headers below) is a second line of defense.

### SQL Injection Prevention

Django's ORM parameterizes all queries automatically:

```python
# Safe — ORM handles parameterization
Article.objects.filter(title=user_input)

# Safe — explicit parameterization
from django.db import connection
with connection.cursor() as cursor:
    cursor.execute("SELECT * FROM articles WHERE title = %s", [user_input])

# DANGEROUS — never do this
cursor.execute(f"SELECT * FROM articles WHERE title = '{user_input}'")
```

Avoid `.raw()` with string interpolation. Use `RawSQL()` only with explicit params.

### Clickjacking (X-Frame-Options)

`XFrameOptionsMiddleware` is enabled by default, sending `X-Frame-Options: DENY`.

```python
# settings.py
X_FRAME_OPTIONS = 'DENY'         # Block all framing (default)
X_FRAME_OPTIONS = 'SAMEORIGIN'   # Allow same origin only
```

Per-view override:

```python
from django.views.decorators.clickjacking import xframe_options_sameorigin

@xframe_options_sameorigin
def embeddable_view(request):
    ...
```

### HTTPS and HSTS

```python
# settings/production.py
SECURE_SSL_REDIRECT = True                    # Redirect HTTP -> HTTPS
SECURE_HSTS_SECONDS = 31536000               # 1 year HSTS
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True                   # Submit to browser preload lists
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')  # Behind proxy
SESSION_COOKIE_SECURE = True                 # HTTPS-only session cookie
CSRF_COOKIE_SECURE = True                    # HTTPS-only CSRF cookie
SECURE_BROWSER_XSS_FILTER = True             # X-XSS-Protection header
SECURE_CONTENT_TYPE_NOSNIFF = True           # X-Content-Type-Options: nosniff
```

### Content-Security-Policy

Django does not set CSP by default. Use **django-csp**:

```python
# pip install django-csp

# settings.py
MIDDLEWARE = [
    # ...
    'csp.middleware.CSPMiddleware',
]

CSP_DEFAULT_SRC = ("'none'",)
CSP_SCRIPT_SRC = ("'self'",)
CSP_STYLE_SRC = ("'self'",)
CSP_IMG_SRC = ("'self'", 'data:', 'https://cdn.example.com')
CSP_FONT_SRC = ("'self'",)
CSP_CONNECT_SRC = ("'self'",)
CSP_FRAME_ANCESTORS = ("'none'",)
CSP_REPORT_URI = '/csp-report/'
```

### Password Hashing

Django defaults to PBKDF2-SHA256. For stronger security, add Argon2 or bcrypt:

```python
# pip install argon2-cffi

# settings.py
PASSWORD_HASHERS = [
    'django.contrib.auth.hashers.Argon2PasswordHasher',  # Primary
    'django.contrib.auth.hashers.PBKDF2PasswordHasher',  # Fallback (existing hashes)
    'django.contrib.auth.hashers.BCryptSHA256PasswordHasher',
]
```

Existing passwords are transparently upgraded to Argon2 on next login.

### Security Middleware Stack

```python
# settings.py — recommended middleware order
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',      # HTTPS redirect, headers
    'whitenoise.middleware.WhiteNoiseMiddleware',         # If using WhiteNoise
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'csp.middleware.CSPMiddleware',                       # If using django-csp
]
```

Run `python manage.py check --deploy` to audit production security settings.

---

## 5. Performance

### N+1 Problem: select_related vs prefetch_related

**N+1 example (bad):**

```python
# Generates 1 query for articles + N queries for each author
articles = Article.objects.all()
for article in articles:
    print(article.author.username)  # Each triggers a query
```

**select_related** — SQL JOIN for ForeignKey and OneToOneField (single query):

```python
# One SQL query with JOIN
articles = Article.objects.select_related('author', 'category').all()
for article in articles:
    print(article.author.username)  # No extra query
```

**prefetch_related** — Separate query + Python-side joining for ManyToMany and reverse FK:

```python
# Two queries: one for articles, one for all related tags
articles = Article.objects.prefetch_related('tags', 'comments').all()

# Custom prefetch with queryset filtering
from django.db.models import Prefetch

articles = Article.objects.prefetch_related(
    Prefetch('comments', queryset=Comment.objects.filter(approved=True).select_related('author'))
)
```

**Rule:** Use `select_related` for FK/O2O (forward), `prefetch_related` for M2M and reverse FK.

### Database Indexes

```python
# models.py
class Article(models.Model):
    title = models.CharField(max_length=200)
    slug = models.SlugField(unique=True)       # Unique creates index automatically
    author = models.ForeignKey(User, ...)      # ForeignKey creates index automatically
    published_at = models.DateTimeField(db_index=True)  # Single column index
    status = models.CharField(max_length=20)

    class Meta:
        indexes = [
            models.Index(fields=['status', 'published_at']),  # Composite index
            models.Index(fields=['-published_at'], name='article_pub_desc_idx'),  # Descending
        ]
        constraints = [
            models.UniqueConstraint(fields=['author', 'slug'], name='unique_author_slug'),
        ]
```

For partial indexes (PostgreSQL):

```python
from django.db.models import Q

class Meta:
    indexes = [
        models.Index(
            fields=['published_at'],
            condition=Q(status='published'),
            name='published_articles_idx',
        )
    ]
```

### Caching

**Per-view caching:**

```python
from django.views.decorators.cache import cache_page

@cache_page(60 * 15)  # Cache for 15 minutes
def article_list(request):
    ...

# DRF ViewSet with cache
from django.utils.decorators import method_decorator

@method_decorator(cache_page(60 * 5), name='list')
class ArticleViewSet(viewsets.ReadOnlyModelViewSet):
    ...
```

**Template fragment caching:**

```django
{% load cache %}
{% cache 900 article_sidebar user.id %}
    {# Expensive sidebar content #}
    {% for article in popular_articles %}
        ...
    {% endfor %}
{% endcache %}
```

**Low-level cache API:**

```python
from django.core.cache import cache

def get_popular_articles():
    cache_key = 'popular_articles'
    articles = cache.get(cache_key)
    if articles is None:
        articles = list(Article.objects.filter(published=True)
                        .order_by('-views')[:10]
                        .select_related('author'))
        cache.set(cache_key, articles, timeout=300)  # 5 minutes
    return articles

# Cache invalidation
cache.delete('popular_articles')
cache.delete_many(['key1', 'key2'])

# Atomic get-or-set
articles = cache.get_or_set('popular_articles', get_from_db, timeout=300)
```

**Redis cache backend:**

```python
# settings.py
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.redis.RedisCache',
        'LOCATION': 'redis://127.0.0.1:6379/1',
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        },
        'KEY_PREFIX': 'myapp',
        'TIMEOUT': 300,
    }
}
```

### Connection Pooling

PostgreSQL creates a new process per connection. Pooling is critical at scale.

**PgBouncer** — External pooler (preferred for production):

```
# pgbouncer.ini
[databases]
myapp = host=127.0.0.1 port=5432 dbname=myapp

[pgbouncer]
pool_mode = transaction          # Best for Django
max_client_conn = 1000
default_pool_size = 25
```

Point Django's `DATABASE_URL` at PgBouncer (port 6432 typically). Do NOT use named cursors or `SET LOCAL` with transaction pooling.

**django-db-connection-pool** — In-process SQLAlchemy pool:

```python
# pip install django-db-connection-pool[postgresql]

# settings.py
DATABASES = {
    'default': {
        'ENGINE': 'dj_db_conn_pool.backends.postgresql',
        'POOL_OPTIONS': {
            'POOL_SIZE': 10,
            'MAX_OVERFLOW': 10,
            'RECYCLE': 24 * 60 * 60,
        },
        # ... rest of DB config
    }
}
```

### Query Optimization

**EXPLAIN ANALYZE via Django:**

```python
from django.db import connection

qs = Article.objects.filter(status='published').select_related('author')
with connection.cursor() as cursor:
    cursor.execute('EXPLAIN ANALYZE ' + str(qs.query))
    print('\n'.join(row[0] for row in cursor.fetchall()))
```

**django-debug-toolbar** — Visual query inspector in development:

```python
# pip install django-debug-toolbar

# settings/development.py
INSTALLED_APPS = ['debug_toolbar']
MIDDLEWARE = ['debug_toolbar.middleware.DebugToolbarMiddleware', *MIDDLEWARE]
INTERNAL_IPS = ['127.0.0.1']

# urls.py
if settings.DEBUG:
    import debug_toolbar
    urlpatterns = [path('__debug__/', include(debug_toolbar.urls))] + urlpatterns
```

**Only retrieve needed fields:**

```python
# values() — returns dicts, not model instances (no __str__, no methods)
Article.objects.values('id', 'title', 'author__username')

# only() — model instances but deferred fields (lazy loaded on access)
Article.objects.only('id', 'title', 'slug')

# defer() — exclude heavy fields
Article.objects.defer('body', 'rendered_html')
```

**Aggregation and annotation:**

```python
from django.db.models import Count, Avg, Q

authors = User.objects.annotate(
    article_count=Count('articles'),
    published_count=Count('articles', filter=Q(articles__published=True)),
).filter(article_count__gt=0).order_by('-article_count')
```

---

## 6. Common Packages

### Celery — Async Task Queue

```python
# pip install celery redis

# config/celery.py
import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.production')
app = Celery('myapp')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()

# config/__init__.py
from .celery import app as celery_app
__all__ = ('celery_app',)

# settings.py
CELERY_BROKER_URL = 'redis://localhost:6379/0'
CELERY_RESULT_BACKEND = 'redis://localhost:6379/0'
CELERY_TASK_SERIALIZER = 'json'
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_TRACK_STARTED = True
CELERY_TASK_TIME_LIMIT = 30 * 60  # 30 minutes hard limit
CELERY_TASK_SOFT_TIME_LIMIT = 25 * 60

# myapp/tasks.py
from celery import shared_task
from django.core.mail import send_mail

@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def send_welcome_email(self, user_id):
    try:
        from django.contrib.auth import get_user_model
        User = get_user_model()
        user = User.objects.get(pk=user_id)
        send_mail('Welcome!', 'Welcome to our platform.', 'noreply@example.com', [user.email])
    except Exception as exc:
        raise self.retry(exc=exc)

# Usage
send_welcome_email.delay(user.id)
send_welcome_email.apply_async(args=[user.id], countdown=60)
```

**Celery Beat** — Periodic tasks:

```python
# settings.py
from celery.schedules import crontab

CELERY_BEAT_SCHEDULE = {
    'cleanup-expired-tokens': {
        'task': 'myapp.tasks.cleanup_expired_tokens',
        'schedule': crontab(hour=3, minute=0),  # Daily at 3 AM
    },
    'send-digest-emails': {
        'task': 'myapp.tasks.send_weekly_digest',
        'schedule': crontab(day_of_week='monday', hour=8),
    },
}
```

### django-allauth — Authentication + Social Login

```python
# pip install django-allauth

INSTALLED_APPS = [
    'django.contrib.sites',
    'allauth',
    'allauth.account',
    'allauth.socialaccount',
    'allauth.socialaccount.providers.google',
    'allauth.socialaccount.providers.github',
]

AUTHENTICATION_BACKENDS = [
    'django.contrib.auth.backends.ModelBackend',
    'allauth.account.auth_backends.AuthenticationBackend',
]

SITE_ID = 1

# Allauth settings
ACCOUNT_EMAIL_REQUIRED = True
ACCOUNT_UNIQUE_EMAIL = True
ACCOUNT_EMAIL_VERIFICATION = 'mandatory'
ACCOUNT_AUTHENTICATION_METHOD = 'email'
ACCOUNT_USERNAME_REQUIRED = False
ACCOUNT_LOGIN_ON_EMAIL_CONFIRMATION = True
LOGIN_REDIRECT_URL = '/dashboard/'
ACCOUNT_LOGOUT_ON_GET = True

SOCIALACCOUNT_PROVIDERS = {
    'google': {
        'SCOPE': ['profile', 'email'],
        'AUTH_PARAMS': {'access_type': 'online'},
    }
}
```

### django-cors-headers

```python
# pip install django-cors-headers

INSTALLED_APPS = ['corsheaders']

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',  # Before CommonMiddleware
    'django.middleware.common.CommonMiddleware',
    # ...
]

# Development
CORS_ALLOW_ALL_ORIGINS = True

# Production
CORS_ALLOWED_ORIGINS = [
    'https://app.example.com',
    'https://www.example.com',
]
CORS_ALLOW_CREDENTIALS = True
CORS_ALLOW_HEADERS = [
    'accept', 'accept-encoding', 'authorization', 'content-type',
    'dnt', 'origin', 'user-agent', 'x-csrftoken', 'x-requested-with',
]
```

### django-storages

Pluggable file storage backends. AWS S3 example covered in Media Files above.

**Azure Blob Storage:**

```python
# pip install django-storages[azure]
DEFAULT_FILE_STORAGE = 'storages.backends.azure_storage.AzureStorage'
AZURE_ACCOUNT_NAME = env('AZURE_ACCOUNT_NAME')
AZURE_ACCOUNT_KEY = env('AZURE_ACCOUNT_KEY')
AZURE_CONTAINER = 'media'
```

**Google Cloud Storage:**

```python
DEFAULT_FILE_STORAGE = 'storages.backends.gcloud.GoogleCloudStorage'
GS_BUCKET_NAME = env('GS_BUCKET_NAME')
GS_DEFAULT_ACL = 'publicRead'
```

### django-extensions

Development utilities:

```bash
python manage.py shell_plus          # Auto-imports all models
python manage.py show_urls           # List all URL routes
python manage.py graph_models -a -o models.png  # ERD diagram
python manage.py runserver_plus      # Werkzeug debugger
python manage.py reset_db            # Drop and recreate DB
python manage.py create_command myapp my_command  # Generate management command boilerplate
```

### django-debug-toolbar

Covered in Performance section. Key panels: SQL queries, cache hits, template rendering time, signal tracking.

### WhiteNoise

Covered in Static Files section. Key benefit: zero-config static serving without Nginx in PaaS environments.

### dj-database-url

Parses DATABASE_URL environment variable:

```python
# pip install dj-database-url

import dj_database_url

DATABASES = {
    'default': dj_database_url.config(
        default='postgres://localhost/mydb',
        conn_max_age=600,
        conn_health_checks=True,  # Django 4.1+
        ssl_require=True,
    )
}
```

---

## 7. Project Structure

### Recommended Layout

```
myproject/
├── config/                     # Project configuration package
│   ├── __init__.py
│   ├── asgi.py
│   ├── wsgi.py
│   ├── celery.py
│   ├── urls.py                 # Root URL conf
│   └── settings/
│       ├── __init__.py
│       ├── base.py             # Shared settings
│       ├── development.py      # Dev overrides
│       ├── production.py       # Prod overrides
│       └── test.py             # Test overrides
├── apps/
│   ├── accounts/               # Custom user model, auth
│   │   ├── migrations/
│   │   ├── tests/
│   │   │   ├── __init__.py
│   │   │   ├── test_models.py
│   │   │   └── test_views.py
│   │   ├── admin.py
│   │   ├── apps.py
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── permissions.py
│   │   ├── tasks.py
│   │   └── factories.py        # factory_boy factories
│   ├── articles/
│   └── common/                 # Shared utilities, base classes
│       ├── models.py           # Abstract base models (timestamps etc.)
│       ├── pagination.py
│       ├── permissions.py
│       └── mixins.py
├── static/                     # Project-level static files
├── media/                      # User uploads (dev only; use S3 in prod)
├── templates/                  # Project-level templates
├── fixtures/
├── requirements/
│   ├── base.txt
│   ├── development.txt
│   └── production.txt
├── docker/
│   ├── nginx/
│   │   └── nginx.conf
│   └── postgres/
├── .env.example
├── .gitignore
├── docker-compose.yml
├── docker-compose.prod.yml
├── Dockerfile
├── manage.py
├── pytest.ini
└── pyproject.toml
```

### Settings Split

```python
# config/settings/base.py
from pathlib import Path
import environ

BASE_DIR = Path(__file__).resolve().parent.parent.parent
env = environ.Env()
environ.Env.read_env(BASE_DIR / '.env')

SECRET_KEY = env('SECRET_KEY')
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    # Third party
    'rest_framework',
    'corsheaders',
    'django_filters',
    # Local
    'apps.accounts',
    'apps.articles',
    'apps.common',
]
AUTH_USER_MODEL = 'accounts.User'  # Custom user model
```

```python
# config/settings/development.py
from .base import *

DEBUG = True
ALLOWED_HOSTS = ['localhost', '127.0.0.1']

INSTALLED_APPS += ['debug_toolbar', 'django_extensions']
MIDDLEWARE = ['debug_toolbar.middleware.DebugToolbarMiddleware'] + MIDDLEWARE
INTERNAL_IPS = ['127.0.0.1']

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'myapp_dev',
        'USER': 'postgres',
        'PASSWORD': env('DB_PASSWORD', default=''),
        'HOST': 'localhost',
        'PORT': '5432',
    }
}

EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
CELERY_TASK_ALWAYS_EAGER = True  # Run tasks synchronously in dev
```

```python
# config/settings/production.py
from .base import *

DEBUG = False
ALLOWED_HOSTS = env.list('ALLOWED_HOSTS')

DATABASES = {'default': env.db('DATABASE_URL', conn_max_age=600, conn_health_checks=True)}
CACHES = {'default': env.cache('REDIS_URL')}

# Security
SECURE_SSL_REDIRECT = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_BROWSER_XSS_FILTER = True

# Static + Media
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'
DEFAULT_FILE_STORAGE = 'storages.backends.s3boto3.S3Boto3Storage'
```

### URL Organization

```python
# config/urls.py
from django.contrib import admin
from django.urls import path, include
from apps.health.views import health_check

urlpatterns = [
    path('admin/', admin.site.urls),
    path('health/', health_check),
    path('api/v1/', include('config.api_urls')),
    path('auth/', include('allauth.urls')),
]

# config/api_urls.py
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from apps.articles.views import ArticleViewSet
from apps.accounts.views import UserViewSet

router = DefaultRouter()
router.register(r'articles', ArticleViewSet, basename='article')
router.register(r'users', UserViewSet, basename='user')

urlpatterns = [
    path('', include(router.urls)),
    path('auth/', include('rest_framework.urls')),          # DRF login/logout
    path('token/', include('rest_framework_simplejwt.urls')),
    path('accounts/', include('apps.accounts.urls')),
]
```

### Reusable Apps

Abstract base model for timestamps:

```python
# apps/common/models.py
from django.db import models

class TimeStampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True

class UUIDModel(models.Model):
    import uuid
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    class Meta:
        abstract = True

# Usage
class Article(TimeStampedModel, UUIDModel):
    title = models.CharField(max_length=200)
    # id is UUID, created_at and updated_at auto-managed
```

Common pagination:

```python
# apps/common/pagination.py
from rest_framework.pagination import PageNumberPagination

class StandardPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100

class LargePagination(PageNumberPagination):
    page_size = 100
    max_page_size = 500
```

Common base ViewSet:

```python
# apps/common/mixins.py
from rest_framework.response import Response
from rest_framework import status

class CreateModelMixin:
    """Override to return 201 with full serialized object."""
    def perform_create(self, serializer):
        return serializer.save()

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        instance = self.perform_create(serializer)
        output = self.get_serializer(instance)
        headers = self.get_success_headers(output.data)
        return Response(output.data, status=status.HTTP_201_CREATED, headers=headers)
```

---

## Quick Reference: Production Checklist

| Category | Item | Setting/Command |
|---|---|---|
| Security | Debug off | `DEBUG = False` |
| Security | Secret key from env | `SECRET_KEY = env('SECRET_KEY')` |
| Security | HTTPS redirect | `SECURE_SSL_REDIRECT = True` |
| Security | HSTS | `SECURE_HSTS_SECONDS = 31536000` |
| Security | Cookie flags | `SESSION_COOKIE_SECURE = CSRF_COOKIE_SECURE = True` |
| Security | Run deploy check | `manage.py check --deploy` |
| Performance | DB connection pooling | PgBouncer or `conn_max_age=600` |
| Performance | Redis cache | `CACHES = {'default': env.cache('REDIS_URL')}` |
| Performance | Static files | `collectstatic` + WhiteNoise or CDN |
| Observability | Health endpoint | `/health/` with DB + cache checks |
| Observability | Structured logging | JSON logs to stdout |
| Deployment | Gunicorn workers | `2 * CPUs + 1` |
| Deployment | Media to S3 | `DEFAULT_FILE_STORAGE = S3Boto3Storage` |
| Testing | Coverage gate | `fail_under = 85` in `.coveragerc` |
