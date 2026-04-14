# FastAPI Best Practices Reference

## Project Structure

### Flat (Small APIs, <10 Routes)

```
app/
  main.py
  models.py
  schemas.py
  database.py
  config.py
```

### Layered (Medium, 10-50 Routes)

```
app/
  api/
    v1/
      routes/
        users.py
        items.py
      __init__.py
    deps.py
  core/
    config.py
    security.py
    logging.py
  db/
    base.py
    session.py
  models/
    user.py
    item.py
  schemas/
    user.py
    item.py
  services/
    user_service.py
  repositories/
    user_repo.py
  main.py
```

### Domain-Driven (Large, 50+ Routes)

```
app/
  domains/
    users/
      router.py
      models.py
      schemas.py
      service.py
      repository.py
      exceptions.py
    orders/
      router.py
      ...
  shared/
    database.py
    security.py
    exceptions.py
    pagination.py
  core/
    config.py
    events.py
  main.py
```

**Rule of thumb:** Start layered, migrate to domain-driven when a single domain file exceeds ~300 lines or teams need to own separate areas.

---

## Repository Pattern

Abstracts database access; enables swapping storage backends and simplifies testing via dependency injection.

```python
# app/repositories/base.py
from typing import Generic, TypeVar, Type, Optional, Sequence
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.base import Base

ModelT = TypeVar("ModelT", bound=Base)

class BaseRepository(Generic[ModelT]):
    def __init__(self, model: Type[ModelT], session: AsyncSession) -> None:
        self.model = model
        self.session = session

    async def get(self, id: int) -> Optional[ModelT]:
        result = await self.session.execute(select(self.model).where(self.model.id == id))
        return result.scalar_one_or_none()

    async def list(self, *, offset: int = 0, limit: int = 20) -> Sequence[ModelT]:
        result = await self.session.execute(
            select(self.model).offset(offset).limit(limit)
        )
        return result.scalars().all()

    async def create(self, **kwargs) -> ModelT:
        obj = self.model(**kwargs)
        self.session.add(obj)
        await self.session.flush()
        await self.session.refresh(obj)
        return obj

    async def delete(self, obj: ModelT) -> None:
        await self.session.delete(obj)
        await self.session.flush()


# app/repositories/user_repo.py
class UserRepository(BaseRepository[User]):
    def __init__(self, session: AsyncSession) -> None:
        super().__init__(User, session)

    async def get_by_email(self, email: str) -> Optional[User]:
        result = await self.session.execute(
            select(User).where(User.email == email)
        )
        return result.scalar_one_or_none()


# app/api/deps.py -- inject via Depends
def get_user_repo(session: AsyncSession = Depends(get_session)) -> UserRepository:
    return UserRepository(session)
```

---

## Service Layer Pattern

Business logic lives in services, not routes. Routes handle HTTP concerns only.

```python
# app/services/user_service.py
class UserService:
    def __init__(self, repo: UserRepository) -> None:
        self.repo = repo

    async def register(self, data: UserCreate) -> UserOut:
        existing = await self.repo.get_by_email(data.email)
        if existing:
            raise EmailAlreadyExists(data.email)
        user = await self.repo.create(
            email=data.email,
            hashed_password=hash_password(data.password),
            is_active=True,
        )
        return UserOut.model_validate(user)

    async def get_or_404(self, user_id: int) -> UserOut:
        user = await self.repo.get(user_id)
        if not user:
            raise UserNotFound(user_id)
        return UserOut.model_validate(user)


# app/api/v1/routes/users.py
router = APIRouter(prefix="/users", tags=["users"])

def get_user_service(repo=Depends(get_user_repo)) -> UserService:
    return UserService(repo)

@router.post("/", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def create_user(data: UserCreate, service: UserService = Depends(get_user_service)):
    return await service.register(data)
```

---

## Authentication Flows

### JWT Access + Refresh Tokens

```python
# app/core/security.py
from passlib.context import CryptContext
from jose import jwt, JWTError
from datetime import datetime, timedelta, timezone

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(plain: str) -> str:
    return pwd_context.hash(plain)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)

def create_token(subject: str, expires_delta: timedelta, secret: str) -> str:
    expire = datetime.now(timezone.utc) + expires_delta
    payload = {"sub": subject, "exp": expire, "iat": datetime.now(timezone.utc)}
    return jwt.encode(payload, secret, algorithm="HS256")

def create_access_token(subject: str) -> str:
    return create_token(subject, timedelta(minutes=15), settings.JWT_SECRET)

def create_refresh_token(subject: str) -> str:
    return create_token(subject, timedelta(days=7), settings.JWT_REFRESH_SECRET)


# app/api/deps.py -- current user dependency
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

bearer = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    repo=Depends(get_user_repo),
):
    try:
        payload = decode_token(credentials.credentials, settings.JWT_SECRET)
        user_id = int(payload["sub"])
    except (JWTError, KeyError, ValueError):
        raise HTTPException(status_code=401, detail="Invalid token")
    user = await repo.get(user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="Inactive user")
    return user
```

### OAuth2 with Scopes

```python
from fastapi.security import OAuth2PasswordBearer, SecurityScopes
from fastapi import Security

oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/auth/token",
    scopes={"read:users": "Read users", "write:users": "Modify users"},
)

async def get_current_user_scoped(
    security_scopes: SecurityScopes,
    token: str = Depends(oauth2_scheme),
):
    payload = decode_token(token, settings.JWT_SECRET)
    token_scopes = payload.get("scopes", [])
    for scope in security_scopes.scopes:
        if scope not in token_scopes:
            raise HTTPException(
                status_code=403,
                detail=f"Scope required: {scope}",
                headers={"WWW-Authenticate": f'Bearer scope="{security_scopes.scope_str}"'},
            )
    return payload

# Usage
@router.get("/admin", dependencies=[Security(get_current_user_scoped, scopes=["write:users"])])
async def admin_endpoint(): ...
```

### API Key Middleware

```python
from starlette.middleware.base import BaseHTTPMiddleware

EXEMPT_PATHS = {"/health", "/docs", "/openapi.json"}

class APIKeyMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        if request.url.path in EXEMPT_PATHS:
            return await call_next(request)
        api_key = request.headers.get("X-API-Key")
        if api_key not in settings.VALID_API_KEYS:
            raise HTTPException(status_code=403, detail="Invalid API key")
        return await call_next(request)

app.add_middleware(APIKeyMiddleware)
```

---

## Database Patterns

### Async SQLAlchemy 2.0 Session Management

```python
# app/db/session.py
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

engine = create_async_engine(
    settings.DATABASE_URL,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,      # detect stale connections
    pool_recycle=3600,        # recycle after 1 hour
    echo=settings.SQL_ECHO,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    expire_on_commit=False,  # avoid lazy-load errors after commit
    autoflush=False,
)

async def get_session() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

### Base Model with Timestamps

```python
# app/db/base.py
from sqlalchemy.orm import DeclarativeBase, mapped_column, Mapped
from sqlalchemy import func, DateTime
from datetime import datetime

class Base(DeclarativeBase):
    pass

class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
```

### Connection Pool Tuning

| Setting | Default | Recommendation |
|---|---|---|
| `pool_size` | 5 | CPU count * 2 |
| `max_overflow` | 10 | pool_size * 2 |
| `pool_timeout` | 30s | 10s for APIs |
| `pool_recycle` | -1 | 3600 (match DB timeout) |
| `pool_pre_ping` | False | True (prevents broken pipe) |

---

## Alembic Migration Workflows

```bash
# Initialize (once)
alembic init -t async alembic

# Generate migration
alembic revision --autogenerate -m "add users table"

# Apply
alembic upgrade head

# Rollback one step
alembic downgrade -1

# Show history
alembic history --verbose
```

```python
# alembic/env.py -- async setup
from app.db.base import Base
from app.db.session import engine

target_metadata = Base.metadata

async def run_migrations_online():
    async with engine.connect() as connection:
        await connection.run_sync(do_run_migrations)
```

### CI/CD Migration Pattern

```python
# app/core/events.py -- run on startup (dev/staging only)
from alembic import command
from alembic.config import Config

async def run_migrations() -> None:
    if settings.RUN_MIGRATIONS_ON_STARTUP:
        alembic_cfg = Config("alembic.ini")
        command.upgrade(alembic_cfg, "head")
```

---

## Testing Patterns

### Async Test Setup with pytest-asyncio

```python
# tests/conftest.py
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.main import app
from app.db.base import Base
from app.db.session import get_session

TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

@pytest_asyncio.fixture(scope="session")
async def engine():
    engine = create_async_engine(TEST_DATABASE_URL)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()

@pytest_asyncio.fixture
async def session(engine):
    async with engine.connect() as conn:
        await conn.begin_nested()
        async_session = async_sessionmaker(conn, expire_on_commit=False)
        async with async_session() as session:
            yield session
        await conn.rollback()

@pytest_asyncio.fixture
async def client(session: AsyncSession):
    def override_get_session():
        yield session

    app.dependency_overrides[get_session] = override_get_session
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        yield client
    app.dependency_overrides.clear()
```

### Factory Fixtures

```python
# tests/factories.py
import factory
from app.models.user import User
from app.core.security import hash_password

class UserFactory(factory.Factory):
    class Meta:
        model = User

    email = factory.Sequence(lambda n: f"user{n}@example.com")
    hashed_password = factory.LazyFunction(lambda: hash_password("testpass123"))
    is_active = True
    is_superuser = False
```

### Dependency Override Patterns

```python
# Override auth for route testing
@pytest_asyncio.fixture
async def authenticated_client(client: AsyncClient, user):
    from app.core.security import create_access_token
    token = create_access_token(str(user.id))
    client.headers["Authorization"] = f"Bearer {token}"
    return client

# Override a service with a mock
from unittest.mock import AsyncMock

@pytest.fixture
def mock_email_service():
    mock = AsyncMock()
    app.dependency_overrides[get_email_service] = lambda: mock
    yield mock
    app.dependency_overrides.pop(get_email_service, None)
```

### Example Tests

```python
import pytest

@pytest.mark.asyncio
async def test_create_user(client: AsyncClient):
    response = await client.post("/users/", json={
        "email": "new@example.com",
        "password": "strongpass123",
    })
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "new@example.com"
    assert "password" not in data

@pytest.mark.asyncio
async def test_duplicate_email_rejected(client: AsyncClient, user):
    response = await client.post("/users/", json={
        "email": user.email,
        "password": "anything",
    })
    assert response.status_code == 409
```

---

## Error Handling

### Custom Exception Classes

```python
# app/shared/exceptions.py
class AppException(Exception):
    status_code: int = 500
    code: str = "internal_error"
    detail: str = "An unexpected error occurred"

    def __init__(self, detail: str | None = None):
        self.detail = detail or self.__class__.detail
        super().__init__(self.detail)

class NotFoundError(AppException):
    status_code = 404
    code = "not_found"
    detail = "Resource not found"

class ConflictError(AppException):
    status_code = 409
    code = "conflict"
    detail = "Resource already exists"

class UnauthorizedError(AppException):
    status_code = 401
    code = "unauthorized"

class ForbiddenError(AppException):
    status_code = 403
    code = "forbidden"
```

### Problem Details Format (RFC 7807)

```python
# app/core/exception_handlers.py
def problem_response(status_code, title, detail, instance=None, **extra):
    body = {
        "type": f"https://api.example.com/errors/{title.lower().replace(' ', '-')}",
        "title": title,
        "status": status_code,
        "detail": detail,
    }
    if instance:
        body["instance"] = instance
    body.update(extra)
    return JSONResponse(status_code=status_code, content=body, media_type="application/problem+json")

async def app_exception_handler(request, exc):
    return problem_response(
        status_code=exc.status_code,
        title=exc.code.replace("_", " ").title(),
        detail=exc.detail,
        instance=str(request.url),
    )

# Register
app.add_exception_handler(AppException, app_exception_handler)
app.add_exception_handler(RequestValidationError, validation_exception_handler)
```

---

## Logging and Observability

### structlog Setup

```python
import structlog, logging

def configure_logging() -> None:
    shared_processors = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
    ]
    if settings.LOG_FORMAT == "json":
        processors = shared_processors + [structlog.processors.JSONRenderer()]
    else:
        processors = shared_processors + [structlog.dev.ConsoleRenderer()]

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.make_filtering_bound_logger(getattr(logging, settings.LOG_LEVEL)),
        logger_factory=structlog.PrintLoggerFactory(),
    )
```

### Correlation ID Middleware

```python
import uuid, structlog
from starlette.middleware.base import BaseHTTPMiddleware

class CorrelationIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        correlation_id = request.headers.get("X-Correlation-ID", str(uuid.uuid4()))
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(
            correlation_id=correlation_id,
            method=request.method,
            path=request.url.path,
        )
        response = await call_next(request)
        response.headers["X-Correlation-ID"] = correlation_id
        return response
```

### OpenTelemetry

```python
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor

FastAPIInstrumentor.instrument_app(app)
SQLAlchemyInstrumentor().instrument(engine=engine.sync_engine)
```

---

## Caching

### Redis with redis-py async

```python
import json, redis.asyncio as aioredis

redis_client: aioredis.Redis | None = None

async def get_redis() -> aioredis.Redis:
    global redis_client
    if redis_client is None:
        redis_client = aioredis.from_url(settings.REDIS_URL, decode_responses=True, max_connections=20)
    return redis_client

async def cache_get(key: str):
    r = await get_redis()
    value = await r.get(key)
    return json.loads(value) if value else None

async def cache_set(key: str, value, ttl: int = 300):
    r = await get_redis()
    await r.set(key, json.dumps(value), ex=ttl)

# Decorator
def cached(key_template: str, ttl: int = 300):
    def decorator(func):
        @functools.wraps(func)
        async def wrapper(*args, **kwargs):
            key = key_template.format(*args, **kwargs)
            cached_value = await cache_get(key)
            if cached_value is not None:
                return cached_value
            result = await func(*args, **kwargs)
            await cache_set(key, result, ttl=ttl)
            return result
        return wrapper
    return decorator
```

---

## Background Tasks vs Celery vs ARQ

### FastAPI BackgroundTasks (Simple, Same Process)

```python
from fastapi import BackgroundTasks

@router.post("/register")
async def register(data: UserCreate, background_tasks: BackgroundTasks):
    user = await service.register(data)
    background_tasks.add_task(send_welcome_email, user.email)
    return user
```

Use when: fire-and-forget, fast tasks, no retry needed, no persistence.

### Celery (Battle-Tested, Complex Workflows)

```python
from celery import Celery

celery_app = Celery("tasks", broker=settings.CELERY_BROKER_URL, backend=settings.CELERY_RESULT_BACKEND)

@celery_app.task(bind=True, max_retries=3, default_retry_delay=60)
def send_email_task(self, email: str, subject: str, body: str):
    try:
        email_client.send(email, subject, body)
    except Exception as exc:
        raise self.retry(exc=exc)
```

### ARQ (Async-Native, Redis-Backed)

```python
from arq import create_pool
from arq.connections import RedisSettings

async def send_email(ctx, email: str, subject: str):
    await ctx["email_client"].send(email, subject)

class WorkerSettings:
    functions = [send_email]
    redis_settings = RedisSettings(host="redis", port=6379)
    max_jobs = 10
```

**Decision guide:**
- BackgroundTasks: simple notifications, no retry
- ARQ: async-first, moderate complexity, Redis available
- Celery: complex chains/chords, existing Celery infra, large teams

---

## Rate Limiting

```python
# Using slowapi (pip install slowapi)
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address, default_limits=["100/minute"])
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

@router.get("/items")
@limiter.limit("30/minute")
async def list_items(request: Request): ...
```

---

## Pagination

### Offset Pagination

```python
from pydantic import BaseModel, Field
from typing import TypeVar, Generic, Sequence

T = TypeVar("T")

class PageParams(BaseModel):
    offset: int = Field(default=0, ge=0)
    limit: int = Field(default=20, ge=1, le=100)

class Page(BaseModel, Generic[T]):
    items: Sequence[T]
    total: int
    offset: int
    limit: int
    has_more: bool

    @classmethod
    def create(cls, items, total, params):
        return cls(items=items, total=total, offset=params.offset,
                   limit=params.limit, has_more=params.offset + params.limit < total)

@router.get("/items", response_model=Page[ItemOut])
async def list_items(params: PageParams = Depends()):
    items = await repo.list(offset=params.offset, limit=params.limit)
    total = await repo.count()
    return Page.create(items, total, params)
```

### Cursor Pagination (Large Datasets)

```python
import base64, json

def encode_cursor(value: int) -> str:
    return base64.urlsafe_b64encode(json.dumps({"value": value}).encode()).decode()

def decode_cursor(cursor: str) -> dict:
    return json.loads(base64.urlsafe_b64decode(cursor.encode()).decode())

class CursorPage(BaseModel, Generic[T]):
    items: Sequence[T]
    next_cursor: str | None
    has_more: bool
```

---

## Environment Management with pydantic-settings

```python
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import PostgresDsn, field_validator
from functools import lru_cache
from typing import Literal

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", case_sensitive=False, extra="ignore",
    )

    APP_NAME: str = "MyAPI"
    ENVIRONMENT: Literal["development", "staging", "production"] = "development"
    DEBUG: bool = False
    DATABASE_URL: PostgresDsn
    JWT_SECRET: str
    JWT_REFRESH_SECRET: str
    REDIS_URL: str = "redis://localhost:6379/0"
    LOG_LEVEL: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = "INFO"
    LOG_FORMAT: Literal["json", "text"] = "json"
    VALID_API_KEYS: list[str] = []

    @field_validator("VALID_API_KEYS", mode="before")
    @classmethod
    def split_api_keys(cls, v):
        if isinstance(v, str):
            return [k.strip() for k in v.split(",") if k.strip()]
        return v

@lru_cache
def get_settings() -> Settings:
    return Settings()

settings = get_settings()
```

---

## Deployment

### Docker Multi-Stage Build

```dockerfile
FROM python:3.12-slim AS base
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1

FROM base AS deps
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

FROM deps AS development
COPY requirements-dev.txt .
RUN pip install -r requirements-dev.txt
COPY . .
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

FROM deps AS production
COPY app/ ./app/
COPY alembic/ ./alembic/
COPY alembic.ini .
RUN adduser --disabled-password --no-create-home appuser
USER appuser
EXPOSE 8000
CMD ["gunicorn", "app.main:app", \
     "--worker-class", "uvicorn.workers.UvicornWorker", \
     "--workers", "4", "--bind", "0.0.0.0:8000", "--timeout", "30"]
```

### Gunicorn + Uvicorn Configuration

```python
# gunicorn.conf.py
import multiprocessing, os

workers = int(os.getenv("GUNICORN_WORKERS", multiprocessing.cpu_count() * 2 + 1))
worker_class = "uvicorn.workers.UvicornWorker"
bind = f"0.0.0.0:{os.getenv('PORT', '8000')}"
timeout = 30
graceful_timeout = 10
keepalive = 5
accesslog = "-"
errorlog = "-"
loglevel = os.getenv("LOG_LEVEL", "info").lower()
```

**Async note:** With `UvicornWorker`, each Gunicorn worker runs its own uvicorn event loop. Do not share connection pools or globals across workers -- use per-worker initialization in lifespan events.

### docker-compose.yml (Development)

```yaml
services:
  api:
    build:
      context: .
      target: development
    volumes:
      - .:/app
    ports:
      - "8000:8000"
    env_file: .env
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: mydb
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
```

---

## Health Checks and Readiness Probes

```python
from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse
from sqlalchemy import text
import time

router = APIRouter(tags=["health"])
START_TIME = time.time()

@router.get("/health")
async def liveness():
    return {"status": "ok", "uptime_seconds": int(time.time() - START_TIME)}

@router.get("/ready")
async def readiness(session=Depends(get_session)):
    checks = {}
    try:
        await session.execute(text("SELECT 1"))
        checks["database"] = "ok"
    except Exception as e:
        checks["database"] = f"error: {e}"

    try:
        r = await get_redis()
        await r.ping()
        checks["redis"] = "ok"
    except Exception as e:
        checks["redis"] = f"error: {e}"

    all_ok = all(v == "ok" for v in checks.values())
    return JSONResponse(
        status_code=200 if all_ok else 503,
        content={"status": "ready" if all_ok else "degraded", "checks": checks},
    )
```

---

## API Versioning Strategies

### URL Path Versioning (Most Common)

```python
app = FastAPI()
app.include_router(api_v1_router, prefix="/api/v1")
app.include_router(api_v2_router, prefix="/api/v2")
```

### Header Versioning

```python
async def get_api_version(accept_version: str = Header(default="1")) -> str:
    if accept_version not in {"1", "2"}:
        raise HTTPException(400, f"Unknown API version: {accept_version}")
    return accept_version
```

### Deprecation Response Headers

```python
class DeprecationMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        if request.url.path.startswith("/api/v1"):
            response.headers["Deprecation"] = "true"
            response.headers["Sunset"] = "Sat, 01 Jan 2027 00:00:00 GMT"
            response.headers["Link"] = '</api/v2>; rel="successor-version"'
        return response
```

---

## DI Cheat Sheet

```python
# Session
session: AsyncSession = Depends(get_session)

# Repos
user_repo: UserRepository = Depends(get_user_repo)

# Auth
current_user: User = Depends(get_current_user)

# Pagination
params: PageParams = Depends()

# Settings (import directly, not via Depends)
from app.core.config import settings

# Redis
redis: aioredis.Redis = Depends(get_redis)

# Test override
app.dependency_overrides[get_session] = lambda: test_session
app.dependency_overrides[get_current_user] = lambda: fake_user
```
