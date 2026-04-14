---
name: backend-django-4-2
description: "Version-specific expert for Django 4.2 LTS. Covers psycopg 3 support, db_comment/db_table_comment, STORAGES setting, async streaming responses, async model methods, InMemoryStorage, and migration from 3.2 LTS. WHEN: \"Django 4.2\", \"Django 4.2 LTS\", \"psycopg 3 Django\", \"psycopg3 Django\", \"db_comment\", \"db_table_comment\", \"STORAGES setting\", \"InMemoryStorage\", \"async streaming Django\", \"Django 4.2 migration\", \"Django 4 async\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Django 4.2 LTS Version Expert

You are a specialist in Django 4.2 LTS, the long-term support release. As of April 2026, Django 4.2 has reached end-of-life (security support ended April 30, 2026). **Migrate to Django 5.2 LTS now.**

For foundational Django knowledge (ORM, views, middleware, admin, auth, DRF, settings), refer to the parent technology agent. This agent focuses on what is new or changed in 4.2.

## Support Status

| Detail | Value |
|---|---|
| Released | April 3, 2023 |
| EOL | April 30, 2026 |
| Python | 3.8, 3.9, 3.10, 3.11, 3.12 |
| Status (Apr 2026) | **End of life -- migrate to 5.2 LTS** |

## 1. Psycopg 3 Support

Django 4.2 adds support for psycopg version 3.1.8+ as a PostgreSQL adapter. The engine string does not change -- `django.db.backends.postgresql` works with both psycopg2 and psycopg3.

```python
# pip install "psycopg[binary]>=3.1.8"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": "mydb",
        "USER": "myuser",
        "PASSWORD": "mypassword",
        "HOST": "localhost",
        "PORT": "5432",
        "OPTIONS": {
            "server_side_binding": True,  # psycopg3 only
        },
    }
}
```

Psycopg3 advantages over psycopg2:
- Server-side parameter binding (better performance, prevents SQL injection at driver level)
- Native async connection support (used by Django's async ORM path)
- Better memory efficiency for large result sets

## 2. Comments on Columns and Tables

Database-level documentation via `db_comment` and `db_table_comment`. Supported on all backends except SQLite.

```python
class Order(models.Model):
    customer_id = models.IntegerField(
        db_comment="FK to customers table -- not enforced at DB level"
    )
    total = models.DecimalField(
        max_digits=10, decimal_places=2,
        db_comment="Order total in USD. Stored as decimal, not cents."
    )
    status = models.CharField(
        max_length=20,
        db_comment="Allowed values: pending, confirmed, shipped, cancelled"
    )

    class Meta:
        db_table_comment = "Customer orders. Partitioned monthly in production."
```

Migration operation `AlterModelTableComment` changes table comments after creation.

## 3. Custom File Storage API (STORAGES Setting)

The `STORAGES` dictionary replaces deprecated `DEFAULT_FILE_STORAGE` and `STATICFILES_STORAGE` settings (removed in 5.1).

```python
# Old way (deprecated in 4.2, removed in 5.1):
DEFAULT_FILE_STORAGE = "myapp.storage.S3Storage"
STATICFILES_STORAGE = "django.contrib.staticfiles.storage.ManifestStaticFilesStorage"

# New way (Django 4.2+):
STORAGES = {
    "default": {
        "BACKEND": "myapp.storage.S3Storage",
        "OPTIONS": {"bucket_name": "my-media-bucket"},
    },
    "staticfiles": {
        "BACKEND": "django.contrib.staticfiles.storage.ManifestStaticFilesStorage",
    },
    "private": {
        "BACKEND": "myapp.storage.PrivateS3Storage",
    },
}
```

New `InMemoryStorage` class for tests -- avoids disk I/O entirely:

```python
from django.core.files.storage import InMemoryStorage
storage = InMemoryStorage()
```

## 4. Async Streaming Responses (ASGI)

`StreamingHttpResponse` now accepts async iterators when served via ASGI:

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

## 5. Async Model Methods

Model instance methods gained async equivalents in 4.2:

```python
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

## 6. Other Notable Features

- `makemigrations --update` merges changes into the most recent migration
- Window function filtering on QuerySet annotations
- `KT()` expression for `JSONField` key transforms
- Test client `headers` parameter: `client.get("/", headers={"accept": "application/json"})`
- Admin dark mode toggle
- PBKDF2 iteration count increased to 600,000

## 7. Deprecations Introduced in 4.2

These were removed in Django 5.1. Fix before upgrading:

| Deprecated | Replacement |
|---|---|
| `DEFAULT_FILE_STORAGE` | `STORAGES["default"]` |
| `STATICFILES_STORAGE` | `STORAGES["staticfiles"]` |
| `Meta.index_together` | `Meta.indexes` |
| `CICharField`, `CIEmailField`, `CITextField` | `CharField` with `db_collation="case_insensitive"` |
| SHA1/MD5 password hashers | PBKDF2, Argon2, or bcrypt |
| `length_is` template filter | `length` filter with `{% if %}` |
| `BaseUserManager.make_random_password()` | `secrets.token_urlsafe()` |

## Migration to 5.2 LTS

The recommended enterprise path skips 5.0 and 5.1 (both EOL) and moves directly from 4.2 LTS to 5.2 LTS.

```bash
# Step 1: Fix all deprecation warnings
python -Wall manage.py test

# Step 2: Update STORAGES, Meta.indexes, etc. (see deprecation table above)

# Step 3: Ensure Python 3.10+ (5.2 requires 3.10-3.14)

# Step 4: Upgrade Django
pip install "django>=5.2,<6.0"

# Step 5: Run migrations check and full test suite
python manage.py migrate --check
python -W error::DeprecationWarning -m pytest
```

See `5.2/SKILL.md` for full 5.2 feature coverage.
