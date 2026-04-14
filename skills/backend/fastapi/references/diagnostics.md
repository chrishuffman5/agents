# FastAPI Diagnostics Reference

## 422 Validation Errors

The most common FastAPI error. Returned when Pydantic validation fails on request data.

### Reading 422 Error Responses

```json
{
  "detail": [
    {
      "type": "missing",
      "loc": ["body", "email"],
      "msg": "Field required",
      "input": {"username": "alice"}
    },
    {
      "type": "int_parsing",
      "loc": ["query", "page"],
      "msg": "Input should be a valid integer, unable to parse string as an integer",
      "input": "abc"
    }
  ]
}
```

- `loc[0]` tells you the source: `body`, `query`, `path`, `header`, `cookie`
- `loc[1:]` tells you the field path (nested for complex models)
- `type` is the Pydantic error type (useful for programmatic handling)

### Common Causes

| Symptom | Cause | Fix |
|---|---|---|
| 422 on POST with correct JSON | Missing `Content-Type: application/json` header | Set header, or use `Body(media_type=...)` |
| 422 on GET with query params | Query param type mismatch (string sent, int expected) | Check param types in function signature |
| 422 "field required" on optional field | Missing `= None` default | Use `field: str \| None = None` |
| 422 on nested model | Inner model validation failed | Check nested error `loc` path |
| 422 with `Body(embed=True)` | Client sending flat JSON instead of wrapped | Body must be `{"field_name": {...}}` |
| 422 on file upload | Using `Body` instead of `Form`/`File` | Use `UploadFile` with `File(...)` |

### Debugging 422 Errors

```python
# Custom handler that logs the full error for debugging
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    import logging
    logger = logging.getLogger(__name__)
    logger.error(
        "Validation error on %s %s: %s\nBody: %s",
        request.method, request.url.path, exc.errors(), exc.body
    )
    return JSONResponse(status_code=422, content={"detail": exc.errors()})
```

---

## Pydantic v1 to v2 Migration

### Breaking Changes

| v1 | v2 | Notes |
|---|---|---|
| `class Config:` inner class | `model_config = ConfigDict(...)` | Class-level dict |
| `orm_mode = True` | `from_attributes = True` | In `ConfigDict` |
| `.dict()` | `.model_dump()` | Method rename |
| `.json()` | `.model_dump_json()` | Method rename |
| `.parse_obj()` | `.model_validate()` | Method rename |
| `.parse_raw()` | `.model_validate_json()` | Method rename |
| `@validator("field")` | `@field_validator("field")` | Must add `@classmethod` |
| `@root_validator` | `@model_validator(mode="before"\|"after")` | Different signature |
| `Field(regex=...)` | `Field(pattern=...)` | Param rename |
| `Optional[str]` for nullable | `str \| None = None` | PEP 604 preferred |
| `update_forward_refs()` | `model_rebuild()` | For circular references |
| `schema_extra` | `json_schema_extra` | In `ConfigDict` |
| `__fields__` | `model_fields` | Class attribute |

### Migration Errors

**Error: `PydanticUserError: 'model_config' must be a dict`**
- Cause: Using `class Config:` syntax with Pydantic v2
- Fix: Replace with `model_config = ConfigDict(...)`

**Error: `ConfigError: 'orm_mode' is not valid`**
- Cause: Using v1 config key
- Fix: Use `from_attributes=True` in `ConfigDict`

**Error: `AttributeError: 'UserCreate' object has no attribute 'dict'`**
- Cause: Calling v1 `.dict()` method
- Fix: Use `.model_dump()`

**Error: `TypeError: validator 'name' should be a class method`**
- Cause: `@field_validator` without `@classmethod`
- Fix: Add `@classmethod` decorator below `@field_validator`

### Compatibility Mode

For gradual migration, use the v1-v2 compatibility shim:

```python
# pip install pydantic[v1]
# Temporary: import from v1 namespace
from pydantic.v1 import BaseModel as BaseModelV1
```

---

## Async Pitfalls

### Blocking the Event Loop

**Symptom:** All requests slow down, timeouts, unresponsive server.

**Cause:** Calling blocking I/O inside `async def`:

```python
# BAD: blocks the event loop
@app.get("/bad")
async def bad_endpoint():
    result = requests.get("https://api.example.com/data")  # BLOCKING
    return result.json()

# GOOD: use def (runs in threadpool automatically)
@app.get("/good")
def good_endpoint():
    result = requests.get("https://api.example.com/data")
    return result.json()

# GOOD: use async HTTP client
@app.get("/best")
async def best_endpoint():
    async with httpx.AsyncClient() as client:
        result = await client.get("https://api.example.com/data")
    return result.json()
```

**Rule:** If you use `async def`, every I/O call must be `await`-ed. If you use sync libraries, use `def` instead.

### MissingGreenlet Error

**Error:** `sqlalchemy.exc.MissingGreenlet: greenlet_spawn has not been called`

**Cause:** Accessing lazy-loaded relationships or expired attributes after commit in async context.

**Fixes:**
1. Set `expire_on_commit=False` on the sessionmaker
2. Use eager loading: `selectinload()`, `joinedload()`
3. Access all needed attributes before the session closes

```python
# Fix 1: sessionmaker config
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)

# Fix 2: eager loading
from sqlalchemy.orm import selectinload
result = await session.execute(
    select(User).options(selectinload(User.items)).where(User.id == user_id)
)

# Fix 3: explicit refresh
await session.refresh(user, ["items"])
```

### Event Loop Already Running

**Error:** `RuntimeError: This event loop is already running`

**Cause:** Calling `asyncio.run()` or `loop.run_until_complete()` from within an async context.

**Fix:** Use `await` directly, or use `anyio.to_thread.run_sync()` for sync code.

### Async Generator Not Properly Closed

**Symptom:** Resource leaks, database connections not returned to pool.

**Cause:** Exception raised in yield dependency before cleanup.

**Fix:** Always use try/finally in yield dependencies:

```python
async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        # session.__aexit__ handles closing
```

---

## Dependency Resolution Failures

### Circular Dependencies

**Error:** `RecursionError` or infinite loop during startup.

**Cause:** Dependency A depends on B, which depends on A.

**Fix:** Restructure dependencies. Extract shared logic into a third dependency.

### Missing Dependency

**Error:** `TypeError: get_current_user() missing required argument`

**Cause:** Forgetting `Depends()` wrapper.

```python
# BAD: calls the function directly
@app.get("/users")
async def list_users(user: get_current_user):  # WRONG
    ...

# GOOD: use Depends
@app.get("/users")
async def list_users(user: User = Depends(get_current_user)):
    ...

# BEST: use Annotated
@app.get("/users")
async def list_users(user: Annotated[User, Depends(get_current_user)]):
    ...
```

### Dependency Override Not Working in Tests

**Cause:** Override applied after client creation, or cleared too early.

```python
# CORRECT order:
app.dependency_overrides[get_db] = override_get_db  # 1. Override first
client = TestClient(app)                              # 2. Then create client
response = client.get("/items")                       # 3. Then make requests
app.dependency_overrides.clear()                      # 4. Clean up last
```

### Yield Dependency Exceptions Swallowed

**Symptom:** Exception in cleanup code is silently ignored.

**Cause:** Exceptions in the `finally` block of yield dependencies (after yield) are logged but not re-raised to the client. The client already received the response.

**Fix:** Handle cleanup errors gracefully (log them). Critical cleanup should use lifespan events, not per-request dependencies.

---

## Performance Profiling

### Identifying Slow Endpoints

```python
# Timing middleware
import time, logging

logger = logging.getLogger("perf")

class TimingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        start = time.perf_counter()
        response = await call_next(request)
        duration = time.perf_counter() - start
        if duration > 0.5:  # Log slow requests
            logger.warning("Slow request: %s %s took %.3fs",
                         request.method, request.url.path, duration)
        response.headers["X-Process-Time"] = f"{duration:.4f}"
        return response
```

### Database Query Profiling

```python
# Enable SQLAlchemy echo for SQL logging
engine = create_async_engine(DATABASE_URL, echo=True)

# Count queries per request
import contextvars
query_count = contextvars.ContextVar("query_count", default=0)

from sqlalchemy import event

@event.listens_for(engine.sync_engine, "before_cursor_execute")
def count_queries(conn, cursor, statement, parameters, context, executemany):
    query_count.set(query_count.get() + 1)
```

### Common Performance Issues

| Issue | Symptom | Fix |
|---|---|---|
| N+1 queries | Slow list endpoints, many DB queries | Use `selectinload()` / `joinedload()` |
| Missing database indexes | Slow queries on filtered columns | Add indexes to frequently queried columns |
| Sync code in async handler | All requests slow | Use `def` for sync code, `async def` for async |
| Large response payloads | High latency, memory usage | Use pagination, `response_model_include` |
| Connection pool exhaustion | Timeouts, `QueuePool limit reached` | Increase `pool_size`, check for leaked sessions |
| No connection pooling | High latency on first request | Configure `pool_size` and `max_overflow` |
| Serialization overhead | CPU-bound bottleneck | Use `ORJSONResponse` instead of default JSON |
| Missing GZip | Large payloads over network | Add `GZipMiddleware(minimum_size=1024)` |

### Connection Pool Exhaustion

**Error:** `sqlalchemy.exc.TimeoutError: QueuePool limit of X overflow Y reached`

**Causes:**
1. Not closing sessions (missing `yield` cleanup)
2. Long-running transactions holding connections
3. `pool_size` too small for concurrent load

**Fixes:**
```python
# Increase pool size
engine = create_async_engine(
    DATABASE_URL,
    pool_size=20,       # was 5
    max_overflow=40,    # was 10
    pool_timeout=10,    # fail fast instead of queueing
    pool_pre_ping=True, # detect dead connections
)

# Ensure sessions are always closed
async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

---

## Async Database Issues

### asyncpg Connection Errors

**Error:** `asyncpg.exceptions.InterfaceError: cannot perform operation: another operation is in progress`

**Cause:** Sharing a single connection across concurrent coroutines.

**Fix:** Use connection pooling (`async_sessionmaker`), never share a single session across tasks.

### aiosqlite Locking

**Error:** `sqlite3.OperationalError: database is locked`

**Cause:** SQLite does not support concurrent writes. Multiple async workers writing simultaneously.

**Fix:** Use PostgreSQL for production. For testing, use `sqlite+aiosqlite:///:memory:` with a single connection.

### Transaction Isolation in Tests

**Problem:** Tests pollute each other's data.

**Fix:** Use nested transactions with rollback:

```python
@pytest_asyncio.fixture
async def session(engine):
    async with engine.connect() as conn:
        await conn.begin_nested()  # SAVEPOINT
        async_session = async_sessionmaker(conn, expire_on_commit=False)
        async with async_session() as session:
            yield session
        await conn.rollback()  # Rolls back everything
```

---

## Startup and Configuration Errors

### ImportError on Startup

**Error:** `ImportError: cannot import name 'app' from 'app.main'`

**Cause:** Circular imports between modules.

**Fix:** Use lazy imports in `create_app()` or factory pattern. Import routers inside the function, not at module level.

### Settings Validation on Startup

**Error:** `pydantic_settings.ValidationError: 1 validation error for Settings`

**Cause:** Missing required environment variable.

**Fix:** Ensure `.env` file exists or environment variables are set. Check `SettingsConfigDict(env_file=".env")` path.

```python
# Debug: print loaded settings
from app.core.config import Settings
try:
    s = Settings()
    print(s.model_dump())
except Exception as e:
    print(f"Config error: {e}")
```

### Uvicorn "Address Already in Use"

**Error:** `OSError: [Errno 98] Address already in use`

**Fix:** Kill the existing process or use a different port:

```bash
# Find and kill the process on port 8000
lsof -ti:8000 | xargs kill -9
# Or use a different port
uvicorn app.main:app --port 8001
```

---

## Common Middleware Ordering Issues

### CORS Not Working

**Symptom:** Browser CORS errors despite `CORSMiddleware` being added.

**Causes:**
1. `CORSMiddleware` added after other middleware that returns early
2. `allow_origins` does not include the requesting origin
3. `allow_credentials=True` with `allow_origins=["*"]` (not allowed by spec)

**Fix:**
```python
# Add CORS middleware FIRST (outermost)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://app.example.com"],  # Not ["*"] with credentials
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
# Then add other middleware
app.add_middleware(RequestIDMiddleware)
```

### Authentication Middleware Blocking Health Checks

**Fix:** Exempt health check paths from auth middleware:

```python
EXEMPT_PATHS = {"/health", "/ready", "/docs", "/openapi.json"}

class AuthMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        if request.url.path in EXEMPT_PATHS:
            return await call_next(request)
        # ... auth logic
```

---

## Debugging Tips

### Enable SQL Logging

```python
engine = create_async_engine(DATABASE_URL, echo=True)
```

### Inspect OpenAPI Schema

Visit `/openapi.json` to see the raw generated schema. Compare against your expected types to find mismatches.

### Debug Dependency Resolution

```python
# Temporarily add logging to dependencies
async def get_db():
    print("get_db called")  # Should only print once per request
    async with AsyncSessionLocal() as session:
        yield session
```

### Test a Single Endpoint in Isolation

```python
from fastapi.testclient import TestClient

# Override all dependencies to remove external concerns
app.dependency_overrides[get_db] = lambda: mock_session
app.dependency_overrides[get_current_user] = lambda: fake_user

client = TestClient(app)
response = client.get("/items/1")
print(response.status_code, response.json())
```
