# FastAPI Best Practices, Testing, and Deployment Patterns

## Table of Contents
1. [Project Structure Patterns](#1-project-structure-patterns)
2. [Repository Pattern](#2-repository-pattern)
3. [Service Layer Pattern](#3-service-layer-pattern)
4. [Authentication Flows](#4-authentication-flows)
5. [Database Patterns](#5-database-patterns)
6. [Alembic Migration Workflows](#6-alembic-migration-workflows)
7. [Testing Patterns](#7-testing-patterns)
8. [Error Handling](#8-error-handling)
9. [Logging and Observability](#9-logging-and-observability)
10. [Caching](#10-caching)
11. [Background Tasks vs Celery vs ARQ](#11-background-tasks-vs-celery-vs-arq)
12. [Rate Limiting](#12-rate-limiting)
13. [Pagination](#13-pagination)
14. [File Handling](#14-file-handling)
15. [Environment Management](#15-environment-management)
16. [Docker Multi-Stage Builds](#16-docker-multi-stage-builds)
17. [Gunicorn + Uvicorn Configuration](#17-gunicorn--uvicorn-configuration)
18. [Health Checks and Readiness Probes](#18-health-checks-and-readiness-probes)
19. [API Versioning Strategies](#19-api-versioning-strategies)

---

## 1. Project Structure Patterns

### Flat (small APIs, <10 routes)
```
app/
  main.py
  models.py
  schemas.py
  database.py
  config.py
```

### Layered (medium, 10-50 routes)
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

### Domain-Driven (large, 50+ routes)
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

**Rule of thumb:** start layered, migrate to domain-driven when a single domain file exceeds ~300 lines or teams need to own separate areas.

---

## 2. Repository Pattern

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
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User
from app.repositories.base import BaseRepository

class UserRepository(BaseRepository[User]):
    def __init__(self, session: AsyncSession) -> None:
        super().__init__(User, session)

    async def get_by_email(self, email: str) -> Optional[User]:
        result = await self.session.execute(
            select(User).where(User.email == email)
        )
        return result.scalar_one_or_none()

    async def get_active_users(self) -> list[User]:
        result = await self.session.execute(
            select(User).where(User.is_active == True)
        )
        return list(result.scalars().all())


# app/api/deps.py — inject via Depends
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_session
from app.repositories.user_repo import UserRepository

def get_user_repo(session: AsyncSession = Depends(get_session)) -> UserRepository:
    return UserRepository(session)
```

---

## 3. Service Layer Pattern

Business logic lives in services, not routes. Routes handle HTTP concerns only.

```python
# app/services/user_service.py
from app.repositories.user_repo import UserRepository
from app.schemas.user import UserCreate, UserOut
from app.core.security import hash_password
from app.domains.users.exceptions import EmailAlreadyExists, UserNotFound

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
from fastapi import APIRouter, Depends, status
from app.api.deps import get_user_repo
from app.services.user_service import UserService
from app.schemas.user import UserCreate, UserOut

router = APIRouter(prefix="/users", tags=["users"])

def get_user_service(repo=Depends(get_user_repo)) -> UserService:
    return UserService(repo)

@router.post("/", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def create_user(
    data: UserCreate,
    service: UserService = Depends(get_user_service),
):
    return await service.register(data)
```

---

## 4. Authentication Flows

### JWT Access + Refresh Tokens

```python
# app/core/security.py
from datetime import datetime, timedelta, timezone
from jose import jwt, JWTError
from passlib.context import CryptContext
from app.core.config import settings

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

def decode_token(token: str, secret: str) -> dict:
    try:
        return jwt.decode(token, secret, algorithms=["HS256"])
    except JWTError:
        raise


# app/api/deps.py — current user dependency
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError
from app.core.security import decode_token
from app.core.config import settings

bearer = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    repo=Depends(get_user_repo),
):
    try:
        payload = decode_token(credentials.credentials, settings.JWT_SECRET)
        user_id = int(payload["sub"])
    except (JWTError, KeyError, ValueError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    user = await repo.get(user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Inactive user")
    return user


# Refresh endpoint
@router.post("/refresh")
async def refresh(refresh_token: str, repo=Depends(get_user_repo)):
    try:
        payload = decode_token(refresh_token, settings.JWT_REFRESH_SECRET)
        user_id = int(payload["sub"])
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    user = await repo.get(user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return {
        "access_token": create_access_token(str(user.id)),
        "refresh_token": create_refresh_token(str(user.id)),
    }
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
# app/middleware/api_key.py
from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from app.core.config import settings

EXEMPT_PATHS = {"/health", "/docs", "/openapi.json"}

class APIKeyMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.url.path in EXEMPT_PATHS:
            return await call_next(request)
        api_key = request.headers.get("X-API-Key")
        if api_key not in settings.VALID_API_KEYS:
            raise HTTPException(status_code=403, detail="Invalid API key")
        return await call_next(request)

# Register in main.py
app.add_middleware(APIKeyMiddleware)
```

---

## 5. Database Patterns

### Async SQLAlchemy 2.0 Session Management

```python
# app/db/session.py
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.core.config import settings

engine = create_async_engine(
    settings.DATABASE_URL,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,      # detect stale connections
    pool_recycle=3600,       # recycle after 1 hour
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

## 6. Alembic Migration Workflows

```bash
# Initialize (once)
alembic init -t async alembic

# alembic/env.py — async setup
from app.db.base import Base
from app.db.session import engine

target_metadata = Base.metadata

async def run_migrations_online():
    async with engine.connect() as connection:
        await connection.run_sync(do_run_migrations)
```

```python
# Generate migration
# alembic revision --autogenerate -m "add users table"

# Apply
# alembic upgrade head

# Rollback one step
# alembic downgrade -1

# Show history
# alembic history --verbose

# Squash migrations (manual)
# alembic merge -m "squash" <rev1> <rev2>
```

### CI/CD Migration Pattern

```python
# app/core/events.py — run on startup (dev/staging only)
from alembic import command
from alembic.config import Config
from app.core.config import settings

async def run_migrations() -> None:
    if settings.RUN_MIGRATIONS_ON_STARTUP:
        alembic_cfg = Config("alembic.ini")
        command.upgrade(alembic_cfg, "head")
```

---

## 7. Testing Patterns

### TestClient and Async Tests

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
    # Each test gets a rolled-back transaction — database isolation per test
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
from factory import LazyFunction
from app.models.user import User
from app.core.security import hash_password

class UserFactory(factory.Factory):
    class Meta:
        model = User

    email = factory.Sequence(lambda n: f"user{n}@example.com")
    hashed_password = LazyFunction(lambda: hash_password("testpass123"))
    is_active = True
    is_superuser = False


# tests/conftest.py
@pytest_asyncio.fixture
async def user(session: AsyncSession):
    u = UserFactory.build()
    session.add(u)
    await session.flush()
    return u

@pytest_asyncio.fixture
async def superuser(session: AsyncSession):
    u = UserFactory.build(is_superuser=True)
    session.add(u)
    await session.flush()
    return u
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
# tests/test_users.py
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

## 8. Error Handling

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
    detail = "Authentication required"

class ForbiddenError(AppException):
    status_code = 403
    code = "forbidden"
    detail = "Insufficient permissions"
```

### Problem Details Format (RFC 7807)

```python
# app/core/exception_handlers.py
from fastapi import Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from app.shared.exceptions import AppException

def problem_response(
    status_code: int,
    title: str,
    detail: str,
    instance: str | None = None,
    **extra,
) -> JSONResponse:
    body = {
        "type": f"https://api.example.com/errors/{title.lower().replace(' ', '-')}",
        "title": title,
        "status": status_code,
        "detail": detail,
    }
    if instance:
        body["instance"] = instance
    body.update(extra)
    return JSONResponse(
        status_code=status_code,
        content=body,
        media_type="application/problem+json",
    )

async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
    return problem_response(
        status_code=exc.status_code,
        title=exc.code.replace("_", " ").title(),
        detail=exc.detail,
        instance=str(request.url),
    )

async def validation_exception_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    errors = [
        {"field": ".".join(str(l) for l in err["loc"]), "message": err["msg"]}
        for err in exc.errors()
    ]
    return problem_response(
        status_code=422,
        title="Validation Error",
        detail="Request body failed validation",
        instance=str(request.url),
        errors=errors,
    )

# Register in main.py
app.add_exception_handler(AppException, app_exception_handler)
app.add_exception_handler(RequestValidationError, validation_exception_handler)
```

---

## 9. Logging and Observability

### structlog Setup

```python
# app/core/logging.py
import structlog
import logging
from app.core.config import settings

def configure_logging() -> None:
    shared_processors = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
    ]

    if settings.LOG_FORMAT == "json":
        processors = shared_processors + [structlog.processors.JSONRenderer()]
    else:
        processors = shared_processors + [structlog.dev.ConsoleRenderer()]

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.make_filtering_bound_logger(
            getattr(logging, settings.LOG_LEVEL)
        ),
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(),
    )

logger = structlog.get_logger()
```

### Correlation ID Middleware + OpenTelemetry

```python
# app/middleware/correlation.py
import uuid
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
import structlog

class CorrelationIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
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


# OpenTelemetry (install: opentelemetry-instrumentation-fastapi)
# app/core/telemetry.py
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor

def setup_telemetry(app, engine) -> None:
    provider = TracerProvider()
    provider.add_span_processor(
        BatchSpanProcessor(OTLPSpanExporter(endpoint="http://otel-collector:4317"))
    )
    trace.set_tracer_provider(provider)
    FastAPIInstrumentor.instrument_app(app)
    SQLAlchemyInstrumentor().instrument(engine=engine.sync_engine)
```

---

## 10. Caching

### Redis with aioredis / redis-py async

```python
# app/core/cache.py
import json
import functools
from typing import Callable, Any
import redis.asyncio as aioredis
from app.core.config import settings

redis_client: aioredis.Redis | None = None

async def get_redis() -> aioredis.Redis:
    global redis_client
    if redis_client is None:
        redis_client = aioredis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True,
            max_connections=20,
        )
    return redis_client

async def cache_get(key: str) -> Any | None:
    r = await get_redis()
    value = await r.get(key)
    return json.loads(value) if value else None

async def cache_set(key: str, value: Any, ttl: int = 300) -> None:
    r = await get_redis()
    await r.set(key, json.dumps(value), ex=ttl)

async def cache_delete(key: str) -> None:
    r = await get_redis()
    await r.delete(key)

async def cache_delete_pattern(pattern: str) -> None:
    r = await get_redis()
    keys = await r.keys(pattern)
    if keys:
        await r.delete(*keys)


# Cache decorator for service methods
def cached(key_template: str, ttl: int = 300):
    def decorator(func: Callable):
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

# Usage
class UserService:
    @cached("user:{1}", ttl=60)
    async def get_user(self, user_id: int) -> dict:
        ...
```

---

## 11. Background Tasks vs Celery vs ARQ

### FastAPI BackgroundTasks (simple, same process)

```python
from fastapi import BackgroundTasks

async def send_welcome_email(email: str) -> None:
    # runs after response is sent; shares event loop
    await some_email_client.send(email, subject="Welcome!")

@router.post("/register")
async def register(data: UserCreate, background_tasks: BackgroundTasks, ...):
    user = await service.register(data)
    background_tasks.add_task(send_welcome_email, user.email)
    return user
```

Use when: fire-and-forget, fast tasks, no retry needed, no persistence.

### Celery (battle-tested, complex workflows)

```python
# app/worker/celery_app.py
from celery import Celery
from app.core.config import settings

celery_app = Celery(
    "tasks",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
)
celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    task_acks_late=True,
    task_reject_on_worker_lost=True,
    worker_prefetch_multiplier=1,
)

@celery_app.task(bind=True, max_retries=3, default_retry_delay=60)
def send_email_task(self, email: str, subject: str, body: str):
    try:
        email_client.send(email, subject, body)
    except Exception as exc:
        raise self.retry(exc=exc)
```

### ARQ (async-native, Redis-backed, simpler than Celery)

```python
# app/worker/arq_worker.py
from arq import create_pool
from arq.connections import RedisSettings

async def send_email(ctx, email: str, subject: str):
    await ctx["email_client"].send(email, subject)

class WorkerSettings:
    functions = [send_email]
    redis_settings = RedisSettings(host="redis", port=6379)
    max_jobs = 10
    job_timeout = 300
    retry_jobs = True
    max_tries = 3

# Enqueue from FastAPI
async def get_arq_pool():
    return await create_pool(RedisSettings(host="redis"))

@router.post("/notify")
async def notify(email: str, pool=Depends(get_arq_pool)):
    await pool.enqueue_job("send_email", email, "Hello!")
```

**Decision guide:**
- BackgroundTasks: simple notifications, no retry
- ARQ: async-first, moderate complexity, Redis available
- Celery: complex chains/chords, existing Celery infra, large teams

---

## 12. Rate Limiting

```python
# Using slowapi (Limits-compatible, integrates with FastAPI)
# pip install slowapi

from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address, default_limits=["100/minute"])

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

@router.get("/items")
@limiter.limit("30/minute")
async def list_items(request: Request): ...

# Per-user rate limiting
def get_user_key(request: Request) -> str:
    user_id = request.state.user_id  # set by auth middleware
    return f"user:{user_id}"

@router.post("/messages")
@limiter.limit("10/minute", key_func=get_user_key)
async def send_message(request: Request): ...
```

---

## 13. Pagination

### Offset Pagination

```python
# app/shared/pagination.py
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
    def create(cls, items: Sequence[T], total: int, params: PageParams) -> "Page[T]":
        return cls(
            items=items,
            total=total,
            offset=params.offset,
            limit=params.limit,
            has_more=params.offset + params.limit < total,
        )

# Route
@router.get("/items", response_model=Page[ItemOut])
async def list_items(params: PageParams = Depends()):
    items = await repo.list(offset=params.offset, limit=params.limit)
    total = await repo.count()
    return Page.create(items, total, params)
```

### Cursor Pagination (efficient for large datasets)

```python
import base64
import json

def encode_cursor(value: int, field: str = "id") -> str:
    payload = json.dumps({"field": field, "value": value})
    return base64.urlsafe_b64encode(payload.encode()).decode()

def decode_cursor(cursor: str) -> dict:
    try:
        payload = base64.urlsafe_b64decode(cursor.encode()).decode()
        return json.loads(payload)
    except Exception:
        raise ValueError("Invalid cursor")

class CursorPage(BaseModel, Generic[T]):
    items: Sequence[T]
    next_cursor: str | None
    has_more: bool

# Repository
async def list_after_cursor(self, cursor: str | None, limit: int = 20) -> list:
    query = select(self.model).order_by(self.model.id).limit(limit + 1)
    if cursor:
        cursor_data = decode_cursor(cursor)
        query = query.where(self.model.id > cursor_data["value"])
    result = await self.session.execute(query)
    items = list(result.scalars().all())
    has_more = len(items) > limit
    items = items[:limit]
    next_cursor = encode_cursor(items[-1].id) if has_more and items else None
    return items, next_cursor, has_more
```

---

## 14. File Handling

### Upload

```python
from fastapi import UploadFile, File, HTTPException
import aiofiles
import hashlib

ALLOWED_TYPES = {"image/jpeg", "image/png", "application/pdf"}
MAX_SIZE = 10 * 1024 * 1024  # 10 MB

@router.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(400, "Unsupported file type")
    content = await file.read()
    if len(content) > MAX_SIZE:
        raise HTTPException(413, "File too large")
    digest = hashlib.sha256(content).hexdigest()
    filename = f"{digest}{Path(file.filename).suffix}"
    async with aiofiles.open(f"uploads/{filename}", "wb") as f:
        await f.write(content)
    return {"filename": filename, "size": len(content)}
```

### Streaming Download

```python
from fastapi.responses import StreamingResponse
import aiofiles

@router.get("/download/{filename}")
async def download_file(filename: str):
    filepath = Path("uploads") / filename
    if not filepath.exists():
        raise HTTPException(404, "File not found")

    async def file_generator():
        async with aiofiles.open(filepath, "rb") as f:
            while chunk := await f.read(65536):  # 64 KB chunks
                yield chunk

    return StreamingResponse(
        file_generator(),
        media_type="application/octet-stream",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
```

---

## 15. Environment Management

### pydantic-settings

```python
# app/core/config.py
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import PostgresDsn, RedisDsn, field_validator
from functools import lru_cache
from typing import Literal

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # App
    APP_NAME: str = "MyAPI"
    ENVIRONMENT: Literal["development", "staging", "production"] = "development"
    DEBUG: bool = False

    # Database
    DATABASE_URL: PostgresDsn
    SQL_ECHO: bool = False

    # Security
    JWT_SECRET: str
    JWT_REFRESH_SECRET: str

    # Redis
    REDIS_URL: RedisDsn = "redis://localhost:6379/0"

    # Logging
    LOG_LEVEL: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = "INFO"
    LOG_FORMAT: Literal["json", "text"] = "json"

    # Migrations
    RUN_MIGRATIONS_ON_STARTUP: bool = False

    # API keys (comma-separated in .env)
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

```ini
# .env
DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/mydb
JWT_SECRET=supersecret-change-in-production
JWT_REFRESH_SECRET=refresh-secret-change-in-production
REDIS_URL=redis://localhost:6379/0
VALID_API_KEYS=key1,key2
LOG_LEVEL=INFO
```

---

## 16. Docker Multi-Stage Builds

```dockerfile
# Dockerfile
FROM python:3.12-slim AS base
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# ---- Dependencies ----
FROM base AS deps
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

# ---- Development ----
FROM deps AS development
COPY requirements-dev.txt .
RUN pip install -r requirements-dev.txt
COPY . .
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

# ---- Test runner ----
FROM development AS test
RUN pytest --tb=short -q

# ---- Production ----
FROM deps AS production
COPY app/ ./app/
COPY alembic/ ./alembic/
COPY alembic.ini .
RUN adduser --disabled-password --no-create-home appuser
USER appuser
EXPOSE 8000
CMD ["gunicorn", "app.main:app", \
     "--worker-class", "uvicorn.workers.UvicornWorker", \
     "--workers", "4", \
     "--bind", "0.0.0.0:8000", \
     "--timeout", "30", \
     "--graceful-timeout", "10", \
     "--access-logfile", "-", \
     "--error-logfile", "-"]
```

```yaml
# docker-compose.yml (development)
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

## 17. Gunicorn + Uvicorn Configuration

```python
# gunicorn.conf.py
import multiprocessing
import os

# Workers: (2 * CPU) + 1 is a good starting point for I/O-bound async apps
workers = int(os.getenv("GUNICORN_WORKERS", multiprocessing.cpu_count() * 2 + 1))
worker_class = "uvicorn.workers.UvicornWorker"
bind = f"0.0.0.0:{os.getenv('PORT', '8000')}"
timeout = 30
graceful_timeout = 10
keepalive = 5

# Logging
accesslog = "-"
errorlog = "-"
loglevel = os.getenv("LOG_LEVEL", "info").lower()
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s'

# Worker lifecycle hooks for resource cleanup
def worker_exit(server, worker):
    import asyncio
    from app.db.session import engine
    asyncio.get_event_loop().run_until_complete(engine.dispose())
```

```bash
# Start with config file
gunicorn app.main:app -c gunicorn.conf.py

# Or inline (container CMD)
gunicorn app.main:app \
  --worker-class uvicorn.workers.UvicornWorker \
  --workers 4 \
  --bind 0.0.0.0:8000 \
  --timeout 30
```

**Async note:** With `UvicornWorker`, each Gunicorn worker runs its own uvicorn event loop. Do not share connection pools or globals across workers — use per-worker initialization in lifespan events.

---

## 18. Health Checks and Readiness Probes

```python
# app/api/health.py
from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_session
from app.core.cache import get_redis
import time

router = APIRouter(tags=["health"])

START_TIME = time.time()

@router.get("/health")
async def liveness():
    """Liveness: is the process alive? No dependencies checked."""
    return {"status": "ok", "uptime_seconds": int(time.time() - START_TIME)}

@router.get("/ready")
async def readiness(session: AsyncSession = Depends(get_session)):
    """Readiness: can the app serve traffic? Check DB and cache."""
    checks: dict[str, str] = {}

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
        status_code=status.HTTP_200_OK if all_ok else status.HTTP_503_SERVICE_UNAVAILABLE,
        content={"status": "ready" if all_ok else "degraded", "checks": checks},
    )
```

```yaml
# Kubernetes probe config
livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 15
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 3
```

---

## 19. API Versioning Strategies

### URL Path Versioning (most common)

```python
# app/main.py
from fastapi import FastAPI
from app.api.v1.router import api_v1_router
from app.api.v2.router import api_v2_router

app = FastAPI()
app.include_router(api_v1_router, prefix="/api/v1")
app.include_router(api_v2_router, prefix="/api/v2")

# app/api/v1/router.py
from fastapi import APIRouter
from app.api.v1.routes import users, items

api_v1_router = APIRouter()
api_v1_router.include_router(users.router)
api_v1_router.include_router(items.router)
```

### Header Versioning

```python
from fastapi import Header, HTTPException

async def get_api_version(accept_version: str = Header(default="1")) -> str:
    if accept_version not in {"1", "2"}:
        raise HTTPException(400, f"Unknown API version: {accept_version}")
    return accept_version

@router.get("/items")
async def list_items(version: str = Depends(get_api_version)):
    if version == "2":
        return await service.list_items_v2()
    return await service.list_items_v1()
```

### Deprecation Response Headers

```python
from starlette.middleware.base import BaseHTTPMiddleware

DEPRECATED_PATHS = {"/api/v1"}

class DeprecationMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        for path in DEPRECATED_PATHS:
            if request.url.path.startswith(path):
                response.headers["Deprecation"] = "true"
                response.headers["Sunset"] = "Sat, 01 Jan 2027 00:00:00 GMT"
                response.headers["Link"] = '</api/v2>; rel="successor-version"'
        return response
```

### Lifespan Events (startup/shutdown)

```python
# app/main.py
from contextlib import asynccontextmanager
from fastapi import FastAPI
from app.core.cache import get_redis
from app.core.logging import configure_logging
from app.core.telemetry import setup_telemetry

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    configure_logging()
    app.state.redis = await get_redis()
    yield
    # Shutdown
    await app.state.redis.aclose()

app = FastAPI(
    title="My API",
    version="2.0.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.ENVIRONMENT != "production" else None,
    redoc_url=None,
)
```

---

## Quick Reference: Dependency Injection Cheat Sheet

```python
# Session
session: AsyncSession = Depends(get_session)

# Repos
user_repo: UserRepository = Depends(get_user_repo)

# Auth
current_user: User = Depends(get_current_user)

# Pagination
params: PageParams = Depends()

# Settings (no DB needed, use directly)
from app.core.config import settings  # import directly, not via Depends

# Redis
redis: aioredis.Redis = Depends(get_redis)

# Test override pattern
app.dependency_overrides[get_session] = lambda: test_session
app.dependency_overrides[get_current_user] = lambda: fake_user
```
