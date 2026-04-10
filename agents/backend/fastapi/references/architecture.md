# FastAPI Architecture Reference

## ASGI Internals

FastAPI is built on Starlette, an ASGI framework. Every `FastAPI` instance is a Starlette application. ASGI (Asynchronous Server Gateway Interface) replaces WSGI by supporting long-lived connections and first-class async.

### The ASGI Contract

An ASGI app is a callable with this signature:

```python
async def app(scope: dict, receive: Callable, send: Callable) -> None:
    ...
```

- `scope`: connection metadata (type, path, headers, query string)
- `receive`: coroutine returning incoming messages
- `send`: coroutine for outgoing messages

FastAPI -> Starlette -> Uvicorn handles this contract transparently. Understanding it matters when writing custom ASGI middleware.

### Starlette Primitives Exposed by FastAPI

| Starlette Class | FastAPI Usage |
|---|---|
| `Router` | `APIRouter` |
| `Request` / `Response` | Injected directly or via response parameter |
| `BackgroundTasks` | Same class, injected via DI |
| `WebSocket` | Same class |
| `StaticFiles` | Mounted via `app.mount()` |
| `TestClient` | Used in tests (wraps httpx) |

FastAPI adds: decorator-based route registration, automatic parameter extraction from path/query/body, and Pydantic-powered validation and serialization.

```python
from fastapi import FastAPI, Request
from starlette.responses import Response

app = FastAPI()

@app.get("/raw")
async def raw_access(request: Request) -> dict:
    return {
        "method": request.method,
        "headers": dict(request.headers),
        "client": request.client,
        "scope_type": request.scope["type"],
    }
```

---

## Pydantic v2 Integration

FastAPI uses Pydantic v2 for all validation and serialization. The v2 engine is Rust-based (`pydantic-core`), making validation 5-50x faster than v1.

### BaseModel and Field

```python
from pydantic import BaseModel, Field, field_validator, model_validator, computed_field
from pydantic import EmailStr, AnyHttpUrl
from typing import Annotated

class UserCreate(BaseModel):
    model_config = {"str_strip_whitespace": True, "str_to_lower": False}

    username: Annotated[str, Field(min_length=3, max_length=50, pattern=r"^[a-z0-9_]+$")]
    email: EmailStr
    age: Annotated[int, Field(ge=18, le=120, description="Must be an adult")]
    website: AnyHttpUrl | None = None
    tags: list[str] = Field(default_factory=list, max_length=10)
```

### model_config (ConfigDict)

`model_config` replaces the inner `Config` class from v1:

```python
from pydantic import BaseModel, ConfigDict

class OrmModel(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,       # replaces orm_mode=True
        populate_by_name=True,      # allow field name AND alias
        str_strip_whitespace=True,
        validate_default=True,
        revalidate_instances="always",
        json_schema_extra={"examples": [{"id": 1, "name": "Alice"}]},
    )
```

### Field Validators (v2 Style)

```python
from pydantic import field_validator, model_validator
from typing import Self

class OrderCreate(BaseModel):
    quantity: int
    unit_price: float
    total: float

    @field_validator("quantity")
    @classmethod
    def quantity_positive(cls, v: int) -> int:
        if v <= 0:
            raise ValueError("quantity must be positive")
        return v

    @model_validator(mode="after")
    def check_total(self) -> Self:
        expected = self.quantity * self.unit_price
        if abs(self.total - expected) > 0.01:
            raise ValueError(f"total {self.total} does not match {expected:.2f}")
        return self
```

### Computed Fields

```python
from pydantic import computed_field
import math

class Circle(BaseModel):
    radius: float

    @computed_field
    @property
    def area(self) -> float:
        return math.pi * self.radius ** 2

    @computed_field(repr=False)
    @property
    def circumference(self) -> float:
        return 2 * math.pi * self.radius
```

### Discriminated Unions

When a field can be one of several model types, discriminated unions avoid trying every schema:

```python
from typing import Literal, Union, Annotated
from pydantic import BaseModel, Field

class Cat(BaseModel):
    pet_type: Literal["cat"]
    indoor: bool

class Dog(BaseModel):
    pet_type: Literal["dog"]
    breed: str

Pet = Annotated[Union[Cat, Dog], Field(discriminator="pet_type")]

class Owner(BaseModel):
    name: str
    pet: Pet  # FastAPI generates a clean oneOf schema
```

### Serialization Control

```python
from pydantic import BaseModel, Field, ConfigDict
from datetime import datetime

class UserRead(BaseModel):
    id: int
    username: str
    email: str
    created_at: datetime
    hashed_password: str = Field(exclude=True)  # never serialized

    model_config = ConfigDict(from_attributes=True)

# model_dump() options:
user.model_dump(include={"id", "username"})
user.model_dump(exclude_none=True)
user.model_dump(mode="json")          # serializes datetime to ISO string
user.model_dump_json()                # returns JSON bytes
```

---

## Dependency Injection

FastAPI's DI system uses `Depends()`. Dependencies are resolved per-request, cached within the same request by default, and support async.

### Basic Dependencies

```python
from fastapi import FastAPI, Depends, Query
from typing import Annotated

app = FastAPI()

class PaginationParams:
    def __init__(
        self,
        page: int = Query(1, ge=1),
        size: int = Query(20, ge=1, le=100),
    ):
        self.page = page
        self.size = size
        self.offset = (page - 1) * size

# Annotated style is preferred (cleaner signatures)
Pagination = Annotated[PaginationParams, Depends()]

@app.get("/items")
async def list_items(pagination: Pagination) -> dict:
    return {"page": pagination.page, "size": pagination.size}
```

### Sub-Dependencies

Dependencies can depend on other dependencies. FastAPI builds the full graph and resolves from the leaves inward:

```python
from fastapi import Header, HTTPException

async def get_api_key(x_api_key: str = Header(...)) -> str:
    if x_api_key != "secret":
        raise HTTPException(status_code=403)
    return x_api_key

async def get_current_user(
    api_key: Annotated[str, Depends(get_api_key)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> User:
    user = await db.execute(select(User).where(User.api_key == api_key))
    return user.scalar_one_or_none()

CurrentUser = Annotated[User, Depends(get_current_user)]
```

### Yield Dependencies (Resource Management)

`yield` transforms a dependency into a context manager -- ideal for database sessions:

```python
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker

engine = create_async_engine("postgresql+asyncpg://...", pool_size=20, max_overflow=10)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise

DB = Annotated[AsyncSession, Depends(get_db)]

@app.post("/users")
async def create_user(user_in: UserCreate, db: DB) -> UserRead:
    user = User(**user_in.model_dump())
    db.add(user)
    await db.flush()
    return UserRead.model_validate(user)
```

### Dependency Caching

Within a single request, the same dependency function (by identity) is called only once:

```python
# get_db() is called once even if used in 3 different injected dependencies
# To disable caching for a specific dependency:
Depends(get_db, use_cache=False)
```

### Dependencies on APIRouter

Apply dependencies to every route in a router:

```python
from fastapi import APIRouter

router = APIRouter(
    prefix="/admin",
    tags=["admin"],
    dependencies=[Depends(require_admin)],  # applied to ALL routes
)
```

### Dependency Override (Testing)

```python
# Override any dependency for testing
app.dependency_overrides[get_db] = lambda: test_session
app.dependency_overrides[get_current_user] = lambda: mock_user

# Clear after test
app.dependency_overrides.clear()
```

---

## Path Operations

### Decorator Patterns

```python
from fastapi import APIRouter, Path, Query, Body, status
from typing import Annotated

router = APIRouter(prefix="/items", tags=["items"])

@router.get(
    "/{item_id}",
    response_model=ItemRead,
    status_code=status.HTTP_200_OK,
    summary="Retrieve a single item",
    description="Fetches item by its UUID. Returns 404 if not found.",
    response_description="The found item",
    deprecated=False,
)
async def get_item(
    item_id: Annotated[int, Path(ge=1, description="The item's database ID")],
    include_deleted: Annotated[bool, Query()] = False,
) -> ItemRead:
    ...
```

### Parameter Types

```python
from fastapi import Header, Cookie, Form, File, UploadFile

@router.post("/")
async def create_item(
    q: str | None = None,                              # Query param
    item: ItemCreate,                                   # Body (Pydantic model)
    metadata: Annotated[dict, Body(embed=True)] = {},   # Embedded body field
    user_agent: str | None = Header(None),              # Header (auto underscore-to-hyphen)
    session_id: str | None = Cookie(None),              # Cookie
) -> ItemRead:
    ...
```

### Response Models vs Return Type Annotations

```python
# Approach 1: response_model parameter (explicit, allows type narrowing)
@app.get("/users/{id}", response_model=UserRead)
async def get_user(id: int) -> Any:
    return await db.get(User, id)  # ORM model filtered by response_model

# Approach 2: Return type annotation (modern, cleaner)
@app.get("/users/{id}")
async def get_user(id: int) -> UserRead:
    user = await db.get(User, id)
    return UserRead.model_validate(user)  # explicit validation
```

Key difference: `response_model` causes FastAPI to run `jsonable_encoder()` + model validation on the return value (filtering extra fields). Return type annotation skips this automatic validation.

### Multiple Response Types

```python
from fastapi.responses import JSONResponse

@app.get(
    "/items/{id}",
    responses={
        200: {"model": ItemRead},
        404: {"model": ErrorResponse},
        410: {"description": "Item was permanently deleted"},
    },
)
async def get_item(id: int) -> ItemRead | JSONResponse:
    item = await db.get(Item, id)
    if not item:
        return JSONResponse(status_code=404, content={"detail": "Not found"})
    return ItemRead.model_validate(item)
```

---

## OpenAPI Generation

FastAPI auto-generates OpenAPI 3.1 spec from your code. Docs at `/docs` (Swagger UI) and `/redoc`.

### Customizing App Metadata

```python
app = FastAPI(
    title="My API",
    summary="Short one-liner",
    description="Detailed markdown description shown in Swagger UI.",
    version="1.0.0",
    contact={"name": "Team", "email": "api@example.com"},
    license_info={"name": "MIT"},
    openapi_tags=[
        {"name": "users", "description": "User management"},
        {"name": "items", "description": "Item CRUD"},
    ],
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
)
```

### Custom OpenAPI Schema

```python
from fastapi.openapi.utils import get_openapi

def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    schema = get_openapi(title=app.title, version=app.version,
                         description=app.description, routes=app.routes)
    schema["components"]["securitySchemes"] = {
        "BearerAuth": {"type": "http", "scheme": "bearer", "bearerFormat": "JWT"}
    }
    schema["security"] = [{"BearerAuth": []}]
    app.openapi_schema = schema
    return schema

app.openapi = custom_openapi
```

### Hiding Endpoints

```python
@app.get("/internal/metrics", include_in_schema=False)
async def metrics() -> dict: ...

# Disable docs entirely in production
app = FastAPI(docs_url=None, redoc_url=None) if ENV == "prod" else FastAPI()
```

---

## Request Lifecycle

1. ASGI server (Uvicorn) receives connection, creates `scope`
2. Middleware stack processes request (outermost first)
3. Router matches path and method to a path operation
4. Dependency graph is resolved (leaves first, cached per-request)
5. Request body is parsed and validated via Pydantic
6. Path operation function executes
7. Response is serialized (via `response_model` or return type)
8. Middleware stack processes response (innermost first)
9. Yield dependencies execute cleanup (after response is sent)

---

## Async/Await Patterns

### When to Use `async def` vs `def`

```python
# async def: anything that uses await (DB queries, HTTP calls, file I/O)
@app.get("/async")
async def async_endpoint(db: DB) -> list[ItemRead]:
    result = await db.execute(select(Item))
    return result.scalars().all()

# def: CPU-bound or blocking sync code
# FastAPI runs sync route handlers in a threadpool automatically
@app.get("/sync")
def sync_endpoint() -> dict:
    data = requests.get("https://external.api/data").json()
    return data
```

**Rules:**
- Use `async def` when you have awaitable I/O (async DB, httpx, aiofiles)
- Use `def` for sync libraries (requests, psycopg2, boto3) -- FastAPI uses `anyio.to_thread.run_sync()` automatically
- Never use blocking I/O in `async def` without wrapping in a threadpool

### Running Sync Code from Async Context

```python
import asyncio
from concurrent.futures import ProcessPoolExecutor
import anyio

# CPU-bound work in an async endpoint:
async def cpu_heavy_endpoint() -> dict:
    loop = asyncio.get_running_loop()
    with ProcessPoolExecutor() as pool:
        result = await loop.run_in_executor(pool, cpu_intensive_function, arg1)
    return {"result": result}

# anyio approach (used internally by FastAPI/Starlette):
async def call_sync_in_thread(blocking_func, *args):
    return await anyio.to_thread.run_sync(blocking_func, *args)
```

---

## Middleware

Middleware wraps every request/response. FastAPI/Starlette middleware runs in the order added (outermost first for requests, innermost first for responses).

### Built-in Middleware

```python
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.middleware.gzip import GZipMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://app.example.com"],
    allow_origin_regex=r"https://.*\.example\.com",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Request-ID"],
    max_age=600,
)

app.add_middleware(TrustedHostMiddleware, allowed_hosts=["example.com", "*.example.com"])
app.add_middleware(GZipMiddleware, minimum_size=1024)
```

### Custom BaseHTTPMiddleware

```python
from starlette.middleware.base import BaseHTTPMiddleware
import time, uuid

class RequestIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        request_id = str(uuid.uuid4())
        request.state.request_id = request_id
        start = time.perf_counter()
        response = await call_next(request)
        duration = time.perf_counter() - start
        response.headers["X-Request-ID"] = request_id
        response.headers["X-Process-Time"] = f"{duration:.4f}"
        return response

app.add_middleware(RequestIDMiddleware)
```

### Pure ASGI Middleware (Maximum Performance)

`BaseHTTPMiddleware` buffers responses and has overhead. For high-throughput:

```python
class RawASGIMiddleware:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] == "http":
            async def send_wrapper(message):
                if message["type"] == "http.response.start":
                    headers = list(message.get("headers", []))
                    headers.append((b"x-served-by", b"my-service"))
                    message = {**message, "headers": headers}
                await send(message)
            await self.app(scope, receive, send_wrapper)
        else:
            await self.app(scope, receive, send)

app.add_middleware(RawASGIMiddleware)
```

---

## Exception Handling

### HTTPException

```python
from fastapi import HTTPException, status

raise HTTPException(
    status_code=status.HTTP_404_NOT_FOUND,
    detail={"message": "Item not found", "item_id": id},
    headers={"X-Error": "item-not-found"},
)
```

### Custom Exception Handlers

```python
from fastapi.exceptions import RequestValidationError

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request, exc):
    errors = [
        {"field": " -> ".join(str(loc) for loc in e["loc"]), "message": e["msg"], "type": e["type"]}
        for e in exc.errors()
    ]
    return JSONResponse(status_code=422, content={"errors": errors, "body": exc.body})

# Custom domain exception
class ItemNotFoundError(Exception):
    def __init__(self, item_id: int):
        self.item_id = item_id

@app.exception_handler(ItemNotFoundError)
async def item_not_found_handler(request, exc):
    return JSONResponse(status_code=404, content={"detail": f"Item {exc.item_id} not found"})
```

---

## Security

### OAuth2 Password Flow with JWT

```python
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
import jwt

SECRET_KEY = "..."
ALGORITHM = "HS256"
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")

def create_access_token(subject: str, expires_delta: timedelta = timedelta(minutes=30)) -> str:
    payload = {"sub": subject, "exp": datetime.now(timezone.utc) + expires_delta, "iat": datetime.now(timezone.utc)}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user(token: Annotated[str, Depends(oauth2_scheme)], db: DB) -> User:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user = await db.get(User, int(payload["sub"]))
        if not user:
            raise HTTPException(status_code=401, headers={"WWW-Authenticate": "Bearer"})
        return user
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

CurrentUser = Annotated[User, Depends(get_current_user)]
```

### OAuth2 Scopes

```python
from fastapi.security import SecurityScopes
from fastapi import Security

async def get_current_user_with_scopes(security_scopes: SecurityScopes, token: Annotated[str, Depends(oauth2_scheme)], db: DB) -> User:
    payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    token_scopes = payload.get("scopes", [])
    for scope in security_scopes.scopes:
        if scope not in token_scopes:
            raise HTTPException(status_code=403, detail=f"Missing scope: {scope}")
    return await db.get(User, int(payload["sub"]))

@app.get("/admin/users", dependencies=[Security(get_current_user_with_scopes, scopes=["admin"])])
async def list_users(db: DB) -> list[UserRead]: ...
```

### API Key Authentication

```python
from fastapi.security import APIKeyHeader, APIKeyQuery

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)
api_key_query = APIKeyQuery(name="api_key", auto_error=False)

async def get_api_key(
    header_key: str | None = Security(api_key_header),
    query_key: str | None = Security(api_key_query),
) -> str:
    key = header_key or query_key
    if not key or not await validate_api_key(key):
        raise HTTPException(status_code=403, detail="Invalid API key")
    return key
```

---

## Response Classes

```python
from fastapi.responses import (
    JSONResponse, StreamingResponse, FileResponse,
    HTMLResponse, PlainTextResponse, RedirectResponse, ORJSONResponse
)
from fastapi.encoders import jsonable_encoder

# ORJSONResponse: faster JSON using orjson (handles datetime, UUID natively)
@app.get("/fast", response_class=ORJSONResponse)
async def fast_json() -> dict:
    return {"ts": datetime.now(), "id": uuid4()}

# StreamingResponse for large data
@app.get("/export/csv")
async def export_csv(db: DB) -> StreamingResponse:
    async def generate():
        yield "id,name,email\n"
        async for user in stream_all_users(db):
            yield f"{user.id},{user.name},{user.email}\n"
    return StreamingResponse(generate(), media_type="text/csv",
                             headers={"Content-Disposition": "attachment; filename=users.csv"})

# FileResponse
@app.get("/download/{filename}")
async def download(filename: str) -> FileResponse:
    return FileResponse(path=f"/files/{filename}", filename=filename)

# Set default response class for entire app
app = FastAPI(default_response_class=ORJSONResponse)
```

---

## Lifespan Events and Sub-Applications

### Lifespan Context Manager

```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    engine = create_async_engine(DATABASE_URL, pool_size=20)
    app.state.db_engine = engine
    app.state.http_client = httpx.AsyncClient(timeout=30.0)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    # Shutdown
    await app.state.http_client.aclose()
    await engine.dispose()

app = FastAPI(lifespan=lifespan)
```

### Sub-Applications and Mounting

```python
main_app = FastAPI(lifespan=lifespan)
v1_app = FastAPI(prefix="/v1")
v2_app = FastAPI(prefix="/v2")

# Mount sub-apps (each has its own OpenAPI schema)
main_app.mount("/v1", v1_app)
main_app.mount("/v2", v2_app)

# Mount static files
from starlette.staticfiles import StaticFiles
main_app.mount("/static", StaticFiles(directory="static"), name="static")

# APIRouter (NOT a sub-app -- shares the same OpenAPI schema)
main_app.include_router(users_router, prefix="/api/v1")
```

---

## WebSockets and Server-Sent Events

### WebSockets

```python
from fastapi import WebSocket, WebSocketDisconnect

class ConnectionManager:
    def __init__(self):
        self.active: dict[str, WebSocket] = {}

    async def connect(self, ws: WebSocket, client_id: str):
        await ws.accept()
        self.active[client_id] = ws

    def disconnect(self, client_id: str):
        self.active.pop(client_id, None)

    async def broadcast(self, message):
        disconnected = []
        for cid, ws in self.active.items():
            try:
                await ws.send_json(message)
            except Exception:
                disconnected.append(cid)
        for cid in disconnected:
            self.disconnect(cid)

manager = ConnectionManager()

@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await manager.connect(websocket, client_id)
    try:
        while True:
            data = await websocket.receive_json()
            await manager.broadcast({"from": client_id, "data": data})
    except WebSocketDisconnect:
        manager.disconnect(client_id)
```

### Server-Sent Events (SSE)

```python
from fastapi.responses import StreamingResponse
import asyncio, json

async def event_generator(topic: str):
    async for message in subscribe_to_topic(topic):
        yield f"data: {json.dumps(message)}\n\n"
        await asyncio.sleep(0)

@app.get("/events/{topic}")
async def sse_endpoint(topic: str) -> StreamingResponse:
    return StreamingResponse(
        event_generator(topic),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
```

---

## File Uploads

```python
from fastapi import File, UploadFile, Form
import aiofiles, hashlib

MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB

@app.post("/upload")
async def upload_file(
    file: UploadFile,
    description: Annotated[str, Form()],
) -> dict:
    if file.content_type not in {"image/jpeg", "image/png", "image/webp"}:
        raise HTTPException(400, "Only JPEG, PNG, WebP allowed")

    sha256 = hashlib.sha256()
    size = 0
    async with aiofiles.open(f"/uploads/{file.filename}", "wb") as f:
        while chunk := await file.read(65536):
            size += len(chunk)
            if size > MAX_FILE_SIZE:
                raise HTTPException(413, "File too large")
            sha256.update(chunk)
            await f.write(chunk)

    return {"filename": file.filename, "size": size, "sha256": sha256.hexdigest()}

# Multiple files
@app.post("/upload/batch")
async def upload_batch(files: list[UploadFile] = File(...)) -> list[dict]:
    return [{"filename": f.filename, "size": f.size} for f in files]
```

---

## Database Integration

### SQLAlchemy Async (asyncpg)

```python
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
from sqlalchemy import String, ForeignKey, select, func

class Base(DeclarativeBase):
    pass

class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True)
    items: Mapped[list["Item"]] = relationship(back_populates="owner", lazy="selectin")

engine = create_async_engine(
    "postgresql+asyncpg://user:pass@localhost/db",
    pool_size=20, max_overflow=10, pool_timeout=30, pool_recycle=1800, echo=False,
)

AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
```

### SQLModel (Pydantic + SQLAlchemy Hybrid)

```python
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional

class UserBase(SQLModel):
    username: str = Field(index=True, max_length=50)
    email: str = Field(unique=True)

class User(UserBase, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    hashed_password: str

class UserCreate(UserBase):
    password: str

class UserRead(UserBase):
    id: int
```

### Alembic Migrations

```bash
alembic init -t async migrations/
alembic revision --autogenerate -m "add users table"
alembic upgrade head
alembic downgrade -1
```

```python
# migrations/env.py -- async migration support
async def run_async_migrations():
    engine = create_async_engine(DATABASE_URL)
    async with engine.connect() as conn:
        await conn.run_sync(do_run_migrations)
    await engine.dispose()
```
