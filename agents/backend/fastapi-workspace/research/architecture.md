# FastAPI Architecture & Patterns

**Target:** Senior Python developers  
**FastAPI version:** 0.111+ / Pydantic v2 / Python 3.11+

---

## Table of Contents

1. [ASGI and Starlette Foundation](#1-asgi-and-starlette-foundation)
2. [Pydantic v2 Integration](#2-pydantic-v2-integration)
3. [Dependency Injection](#3-dependency-injection)
4. [Path Operations](#4-path-operations)
5. [OpenAPI / Swagger Generation](#5-openapi--swagger-generation)
6. [Async / Await Patterns](#6-asyncawait-patterns)
7. [Middleware](#7-middleware)
8. [Exception Handling](#8-exception-handling)
9. [Security](#9-security)
10. [Background Tasks](#10-background-tasks)
11. [WebSockets and Server-Sent Events](#11-websockets-and-server-sent-events)
12. [File Uploads](#12-file-uploads)
13. [Response Classes and Encoding](#13-response-classes-and-encoding)
14. [Lifespan Events and Sub-Applications](#14-lifespan-events-and-sub-applications)
15. [Database Integration](#15-database-integration)
16. [Project Structure](#16-project-structure)
17. [Testing](#17-testing)
18. [Deployment and Performance](#18-deployment-and-performance)

---

## 1. ASGI and Starlette Foundation

FastAPI is built directly on top of **Starlette**, an ASGI (Asynchronous Server Gateway Interface) framework. Every `FastAPI` instance is a Starlette application. ASGI replaces WSGI by allowing long-lived connections (WebSockets, SSE) and first-class async support.

### The ASGI Interface

An ASGI app is a callable with this signature:

```python
async def app(scope: dict, receive: Callable, send: Callable) -> None:
    ...
```

- `scope`: connection metadata (type, path, headers, query string)
- `receive`: coroutine that returns incoming messages
- `send`: coroutine that sends outgoing messages

FastAPI → Starlette → Uvicorn handles this contract transparently. Understanding it matters when writing custom ASGI middleware.

### Starlette Primitives FastAPI Exposes

| Starlette Class | FastAPI Usage |
|---|---|
| `Router` | `APIRouter` |
| `Request` / `Response` | Injected directly or via response parameter |
| `BackgroundTasks` | Same class, injected via DI |
| `WebSocket` | Same class |
| `StaticFiles` | Mounted via `app.mount()` |
| `TestClient` | Used in tests |

FastAPI adds the layer of: decorator-based route registration, automatic parameter extraction from path/query/body, and Pydantic-powered validation and serialization.

```python
from fastapi import FastAPI, Request
from starlette.responses import Response

app = FastAPI()

# Direct access to the raw ASGI scope when needed
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

## 2. Pydantic v2 Integration

FastAPI uses Pydantic v2 for all validation and serialization. The migration from v1 to v2 is significant — the internal engine is Rust-based (via `pydantic-core`), making validation 5-50x faster.

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

### model_config

`model_config` (a `ConfigDict`) replaces the inner `Config` class from v1:

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

### Field Validators (v2 style)

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

    @computed_field  # included in serialization
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
    pet: Pet  # FastAPI generates a clean oneOf schema for this

# POST body: {"name": "Alice", "pet": {"pet_type": "cat", "indoor": true}}
```

### Serialization Control

```python
from pydantic import BaseModel, Field
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

## 3. Dependency Injection

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
    db: Annotated["AsyncSession", Depends(get_db)],
) -> User:
    user = await db.execute(select(User).where(User.api_key == api_key))
    return user.scalar_one_or_none() or raise HTTPException(404)

CurrentUser = Annotated[User, Depends(get_current_user)]
```

### Yield Dependencies (Resource Management)

`yield` transforms a dependency into a context manager — ideal for database sessions:

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
    await db.flush()  # get ID without committing
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
    dependencies=[Depends(require_admin)],  # applied to ALL routes here
)
```

---

## 4. Path Operations

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
    # Path params: declared in the path string and function signature
    # Query params: all other simple types not in the path
    q: str | None = None,
    # Body: Pydantic models, or Body() for explicit control
    item: ItemCreate,
    # Multiple body fields with Body(embed=True)
    metadata: Annotated[dict, Body(embed=True)] = {},
    # Headers (underscore ↔ hyphen automatic conversion)
    user_agent: str | None = Header(None),
    # Cookies
    session_id: str | None = Cookie(None),
) -> ItemRead:
    ...
```

### Response Models vs Return Type Annotations

FastAPI supports two approaches:

```python
# Approach 1: response_model parameter (explicit, allows type narrowing)
@app.get("/users/{id}", response_model=UserRead)
async def get_user(id: int) -> Any:  # return type ignored for docs
    return await db.get(User, id)

# Approach 2: Return type annotation (modern, cleaner)
@app.get("/users/{id}")
async def get_user(id: int) -> UserRead:  # FastAPI uses this for OpenAPI
    user = await db.get(User, id)
    return UserRead.model_validate(user)  # explicit validation
```

Key difference: `response_model` causes FastAPI to run `jsonable_encoder()` + model validation on the return value (filtering extra fields). Return type annotation skips this automatic validation — you must return the correct type yourself.

```python
# response_model_exclude / response_model_include for field filtering
@app.get("/users/{id}", response_model=UserRead, response_model_exclude={"hashed_password"})
async def get_user(id: int) -> User: ...  # ORM model, filtered by response_model
```

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

## 5. OpenAPI / Swagger Generation

FastAPI auto-generates OpenAPI 3.1 spec from your code. Docs available at `/docs` (Swagger UI) and `/redoc`.

### Customizing the App Metadata

```python
app = FastAPI(
    title="My API",
    summary="Short one-liner",
    description="""
## Overview
Detailed markdown description shown in Swagger UI.
    """,
    version="1.0.0",
    contact={"name": "Team", "email": "api@example.com"},
    license_info={"name": "MIT", "url": "https://opensource.org/licenses/MIT"},
    openapi_tags=[
        {"name": "users", "description": "User management"},
        {"name": "items", "description": "Item CRUD", "externalDocs": {"url": "..."}},
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
    schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        routes=app.routes,
    )
    # Inject security schemes, x-extensions, etc.
    schema["components"]["securitySchemes"] = {
        "BearerAuth": {"type": "http", "scheme": "bearer", "bearerFormat": "JWT"}
    }
    schema["security"] = [{"BearerAuth": []}]
    app.openapi_schema = schema
    return schema

app.openapi = custom_openapi
```

### Hiding Endpoints / Conditional Docs

```python
@app.get("/internal/metrics", include_in_schema=False)
async def metrics() -> dict: ...

# Disable docs entirely in production
app = FastAPI(docs_url=None, redoc_url=None) if ENV == "prod" else FastAPI()
```

---

## 6. Async/Await Patterns

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
    # Blocking I/O here won't block the event loop
    data = requests.get("https://external.api/data").json()
    return data
```

**Rule of thumb:**
- Use `async def` when you have awaitable I/O (async DB, httpx, aiofiles)
- Use `def` for sync libraries (requests, psycopg2, boto3) — FastAPI uses `anyio.to_thread.run_sync()` automatically
- Never use blocking I/O in `async def` without wrapping in a threadpool

### Running Sync Code from Async Context

```python
import asyncio
from concurrent.futures import ProcessPoolExecutor
import anyio

# For CPU-bound work in an async endpoint:
async def cpu_heavy_endpoint() -> dict:
    loop = asyncio.get_running_loop()
    with ProcessPoolExecutor() as pool:
        result = await loop.run_in_executor(pool, cpu_intensive_function, arg1, arg2)
    return {"result": result}

# anyio approach (used internally by FastAPI/Starlette):
async def call_sync_in_thread(blocking_func, *args):
    return await anyio.to_thread.run_sync(blocking_func, *args)
```

### Async Context Managers in Endpoints

```python
import httpx

# Share a client across requests via lifespan (see section 14)
@app.get("/proxy")
async def proxy(request: Request) -> dict:
    client: httpx.AsyncClient = request.app.state.http_client
    response = await client.get("https://external.api/data")
    response.raise_for_status()
    return response.json()
```

---

## 7. Middleware

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

### Custom Starlette-style Middleware

```python
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
import time
import uuid

class RequestIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
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

`BaseHTTPMiddleware` buffers responses and has overhead. For high-throughput scenarios, write pure ASGI:

```python
from typing import Callable

class RawASGIMiddleware:
    def __init__(self, app: Callable) -> None:
        self.app = app

    async def __call__(self, scope: dict, receive: Callable, send: Callable) -> None:
        if scope["type"] == "http":
            # Intercept only HTTP, pass WebSocket through
            async def send_wrapper(message: dict) -> None:
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

## 8. Exception Handling

### HTTPException

```python
from fastapi import HTTPException, status

@app.get("/items/{id}")
async def get_item(id: int, db: DB) -> ItemRead:
    item = await db.get(Item, id)
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"message": "Item not found", "item_id": id},
            headers={"X-Error": "item-not-found"},
        )
    return ItemRead.model_validate(item)
```

### Custom Exception Handlers

```python
from fastapi import Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from pydantic import ValidationError

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    errors = []
    for error in exc.errors():
        errors.append({
            "field": " -> ".join(str(loc) for loc in error["loc"]),
            "message": error["msg"],
            "type": error["type"],
        })
    return JSONResponse(
        status_code=422,
        content={"errors": errors, "body": exc.body},
    )

# Custom domain exception
class ItemNotFoundError(Exception):
    def __init__(self, item_id: int):
        self.item_id = item_id

@app.exception_handler(ItemNotFoundError)
async def item_not_found_handler(request: Request, exc: ItemNotFoundError) -> JSONResponse:
    return JSONResponse(
        status_code=404,
        content={"detail": f"Item {exc.item_id} not found"},
    )
```

### Global Error Handling with Middleware

```python
import logging

logger = logging.getLogger(__name__)

class ErrorLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        try:
            return await call_next(request)
        except Exception as exc:
            logger.exception(
                "Unhandled exception",
                extra={"path": request.url.path, "method": request.method},
            )
            return JSONResponse(status_code=500, content={"detail": "Internal server error"})
```

---

## 9. Security

### OAuth2 Password Flow with JWT

```python
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi import Depends, HTTPException, status
import jwt  # PyJWT
from datetime import datetime, timedelta, timezone

SECRET_KEY = "..."
ALGORITHM = "HS256"
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")

def create_access_token(subject: str, expires_delta: timedelta = timedelta(minutes=30)) -> str:
    payload = {
        "sub": subject,
        "exp": datetime.now(timezone.utc) + expires_delta,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],
    db: DB,
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise credentials_exception
    
    user = await db.get(User, int(user_id))
    if not user:
        raise credentials_exception
    return user

CurrentUser = Annotated[User, Depends(get_current_user)]

@auth_router.post("/token")
async def login(form: Annotated[OAuth2PasswordRequestForm, Depends()], db: DB) -> dict:
    user = await authenticate_user(db, form.username, form.password)
    if not user:
        raise HTTPException(status_code=400, detail="Incorrect username or password")
    token = create_access_token(str(user.id))
    return {"access_token": token, "token_type": "bearer"}
```

### OAuth2 Scopes

```python
from fastapi.security import SecurityScopes

async def get_current_user_with_scopes(
    security_scopes: SecurityScopes,
    token: Annotated[str, Depends(oauth2_scheme)],
    db: DB,
) -> User:
    if security_scopes.scopes:
        authenticate_value = f'Bearer scope="{security_scopes.scope_str}"'
    else:
        authenticate_value = "Bearer"
    
    payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    token_scopes = payload.get("scopes", [])
    
    for scope in security_scopes.scopes:
        if scope not in token_scopes:
            raise HTTPException(
                status_code=403,
                detail=f"Missing scope: {scope}",
                headers={"WWW-Authenticate": authenticate_value},
            )
    return await db.get(User, int(payload["sub"]))

from fastapi import Security

@app.get("/admin/users", dependencies=[Security(get_current_user_with_scopes, scopes=["admin"])])
async def list_users(db: DB) -> list[UserRead]: ...
```

### API Key Authentication

```python
from fastapi.security import APIKeyHeader, APIKeyQuery, APIKeyCookie

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

### Password Hashing

```python
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)

def hash_password(plain: str) -> str:
    return pwd_context.hash(plain)
```

---

## 10. Background Tasks

Background tasks run after the response is sent. They share the same process but not the same thread (async tasks share the event loop).

```python
from fastapi import BackgroundTasks
import smtplib

async def send_welcome_email(email: str, username: str) -> None:
    # Non-blocking async email sending
    await email_client.send(to=email, subject="Welcome!", body=f"Hi {username}!")

async def audit_log(action: str, user_id: int, details: dict) -> None:
    await db_write("audit_logs", {"action": action, "user_id": user_id, **details})

@app.post("/users", status_code=201)
async def create_user(
    user_in: UserCreate,
    background_tasks: BackgroundTasks,
    db: DB,
) -> UserRead:
    user = User(**user_in.model_dump(exclude={"password"}), hashed_password=hash_password(user_in.password))
    db.add(user)
    await db.flush()
    
    background_tasks.add_task(send_welcome_email, user.email, user.username)
    background_tasks.add_task(audit_log, "user_created", user.id, {"email": user.email})
    
    return UserRead.model_validate(user)
```

For heavy workloads, background tasks in FastAPI are not a substitute for a real task queue (Celery, ARQ, Dramatiq). They run in the same process and die with the request worker.

---

## 11. WebSockets and Server-Sent Events

### WebSockets

```python
from fastapi import WebSocket, WebSocketDisconnect
from typing import Any

class ConnectionManager:
    def __init__(self):
        self.active: dict[str, WebSocket] = {}

    async def connect(self, ws: WebSocket, client_id: str) -> None:
        await ws.accept()
        self.active[client_id] = ws

    def disconnect(self, client_id: str) -> None:
        self.active.pop(client_id, None)

    async def broadcast(self, message: Any) -> None:
        disconnected = []
        for client_id, ws in self.active.items():
            try:
                await ws.send_json(message)
            except Exception:
                disconnected.append(client_id)
        for cid in disconnected:
            self.disconnect(cid)

manager = ConnectionManager()

@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str) -> None:
    await manager.connect(websocket, client_id)
    try:
        while True:
            data = await websocket.receive_json()
            await manager.broadcast({"from": client_id, "data": data})
    except WebSocketDisconnect:
        manager.disconnect(client_id)
        await manager.broadcast({"system": f"{client_id} disconnected"})
```

### Server-Sent Events (SSE)

```python
from fastapi.responses import StreamingResponse
import asyncio
import json

async def event_generator(topic: str):
    """Yields SSE-formatted events."""
    async for message in subscribe_to_topic(topic):
        # SSE format: "data: ...\n\n"
        yield f"data: {json.dumps(message)}\n\n"
        await asyncio.sleep(0)  # yield control to event loop

@app.get("/events/{topic}")
async def sse_endpoint(topic: str) -> StreamingResponse:
    return StreamingResponse(
        event_generator(topic),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",  # disable nginx buffering
        },
    )
```

---

## 12. File Uploads

```python
from fastapi import File, UploadFile, Form
from typing import Annotated
import aiofiles
import hashlib

MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB

@app.post("/upload")
async def upload_file(
    file: UploadFile,
    description: Annotated[str, Form()],
    tags: Annotated[list[str], Form()] = [],
) -> dict:
    # Validate content type
    if file.content_type not in {"image/jpeg", "image/png", "image/webp"}:
        raise HTTPException(400, "Only JPEG, PNG, WebP allowed")

    # Stream file to disk to avoid loading into memory
    sha256 = hashlib.sha256()
    size = 0
    dest = f"/uploads/{file.filename}"
    
    async with aiofiles.open(dest, "wb") as f:
        while chunk := await file.read(65536):  # 64 KB chunks
            size += len(chunk)
            if size > MAX_FILE_SIZE:
                raise HTTPException(413, "File too large")
            sha256.update(chunk)
            await f.write(chunk)

    return {
        "filename": file.filename,
        "size": size,
        "sha256": sha256.hexdigest(),
        "description": description,
    }

# Multiple files
@app.post("/upload/batch")
async def upload_batch(files: list[UploadFile] = File(...)) -> list[dict]:
    return [{"filename": f.filename, "size": f.size} for f in files]
```

---

## 13. Response Classes and Encoding

### JSONResponse and jsonable_encoder

```python
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse, Response
from datetime import datetime
from decimal import Decimal

# jsonable_encoder converts non-JSON-serializable types
data = {"created_at": datetime.now(), "price": Decimal("9.99")}
json_compatible = jsonable_encoder(data)  # {"created_at": "2024-...", "price": 9.99}

# Explicit JSONResponse (bypasses automatic response_model filtering)
@app.get("/custom")
async def custom_response() -> JSONResponse:
    return JSONResponse(
        content=jsonable_encoder({"key": "value"}),
        status_code=200,
        headers={"X-Custom": "header"},
    )
```

### StreamingResponse

```python
from fastapi.responses import StreamingResponse
import io
import csv

@app.get("/export/csv")
async def export_csv(db: DB) -> StreamingResponse:
    async def generate():
        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(["id", "name", "email"])
        yield output.getvalue()
        output.seek(0)
        output.truncate(0)
        
        async for user in stream_all_users(db):
            writer.writerow([user.id, user.name, user.email])
            yield output.getvalue()
            output.seek(0)
            output.truncate(0)

    return StreamingResponse(
        generate(),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=users.csv"},
    )
```

### FileResponse

```python
from fastapi.responses import FileResponse
from pathlib import Path

@app.get("/download/{filename}")
async def download_file(filename: str) -> FileResponse:
    file_path = Path("/files") / filename
    if not file_path.exists():
        raise HTTPException(404)
    return FileResponse(
        path=file_path,
        filename=filename,              # sets Content-Disposition
        media_type="application/octet-stream",
        background=BackgroundTask(cleanup, file_path),  # optional cleanup
    )
```

### Other Response Classes

```python
from fastapi.responses import HTMLResponse, PlainTextResponse, RedirectResponse, ORJSONResponse

# ORJSONResponse: faster JSON using orjson library (handles datetime, UUID natively)
@app.get("/fast-json", response_class=ORJSONResponse)
async def fast_json() -> dict:
    return {"ts": datetime.now(), "id": uuid4()}  # orjson handles these

# RedirectResponse
@app.get("/old-path")
async def redirect() -> RedirectResponse:
    return RedirectResponse(url="/new-path", status_code=301)

# Set default response class for all routes
app = FastAPI(default_response_class=ORJSONResponse)
```

---

## 14. Lifespan Events and Sub-Applications

### Lifespan Context Manager (modern approach)

```python
from contextlib import asynccontextmanager
from typing import AsyncGenerator
import httpx

@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    # Startup: initialize shared resources
    engine = create_async_engine(DATABASE_URL, pool_size=20)
    app.state.db_engine = engine
    app.state.http_client = httpx.AsyncClient(timeout=30.0)
    
    # Optional: run migrations
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    yield  # Application runs here
    
    # Shutdown: clean up resources
    await app.state.http_client.aclose()
    await engine.dispose()

app = FastAPI(lifespan=lifespan)
```

### Sub-Applications and Mounting

```python
from fastapi import FastAPI

main_app = FastAPI(lifespan=lifespan)
v1_app = FastAPI(prefix="/v1")
v2_app = FastAPI(prefix="/v2")

# Mount sub-apps (each has its own OpenAPI schema)
main_app.mount("/v1", v1_app)
main_app.mount("/v2", v2_app)

# Mount static files
from starlette.staticfiles import StaticFiles
main_app.mount("/static", StaticFiles(directory="static"), name="static")

# APIRouter (NOT a sub-app — shares the same OpenAPI schema)
from fastapi import APIRouter

users_router = APIRouter(prefix="/users", tags=["users"])
items_router = APIRouter(prefix="/items", tags=["items"])

@users_router.get("/")
async def list_users() -> list[UserRead]: ...

main_app.include_router(users_router)
main_app.include_router(items_router, prefix="/api/v1")  # override prefix
```

### APIRouter Best Practices

```python
# routers/users.py
router = APIRouter(
    prefix="/users",
    tags=["users"],
    dependencies=[Depends(get_current_user)],   # auth on all routes
    responses={401: {"description": "Not authenticated"}},
)

# main.py
from app.routers import users, items, auth

app.include_router(auth.router)
app.include_router(users.router, prefix="/api/v1")
app.include_router(items.router, prefix="/api/v1")
```

---

## 15. Database Integration

### SQLAlchemy Async (asyncpg)

```python
from sqlalchemy.ext.asyncio import (
    AsyncSession, AsyncEngine,
    create_async_engine, async_sessionmaker
)
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

# Engine setup with connection pool tuning
engine = create_async_engine(
    "postgresql+asyncpg://user:pass@localhost/db",
    pool_size=20,           # concurrent connections
    max_overflow=10,        # extra connections above pool_size
    pool_timeout=30,        # seconds to wait for connection
    pool_recycle=1800,      # recycle connections after 30 min
    echo=False,             # SQL logging
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,  # avoid lazy-load errors post-commit
)

# Repository pattern
class UserRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_by_id(self, user_id: int) -> User | None:
        return await self.session.get(User, user_id)

    async def list_paginated(self, offset: int, limit: int) -> tuple[list[User], int]:
        count_q = select(func.count()).select_from(User)
        items_q = select(User).offset(offset).limit(limit).order_by(User.id)
        
        total = (await self.session.execute(count_q)).scalar_one()
        items = (await self.session.execute(items_q)).scalars().all()
        return list(items), total
```

### SQLModel (Pydantic + SQLAlchemy hybrid)

```python
from sqlmodel import SQLModel, Field, Session, create_engine, select, Relationship
from typing import Optional

class UserBase(SQLModel):
    username: str = Field(index=True, max_length=50)
    email: str = Field(unique=True)

class User(UserBase, table=True):  # table=True makes it a DB model
    id: Optional[int] = Field(default=None, primary_key=True)
    hashed_password: str
    items: list["Item"] = Relationship(back_populates="owner")

class UserCreate(UserBase):  # Pydantic-only (no table)
    password: str

class UserRead(UserBase):
    id: int

# SQLModel with async
from sqlmodel.ext.asyncio.session import AsyncSession as SQLModelAsyncSession
```

### Alembic Migrations

```bash
# alembic.ini: set sqlalchemy.url = postgresql+asyncpg://...
alembic init -t async migrations/

# Generate migration from model changes
alembic revision --autogenerate -m "add users table"

# Apply migrations
alembic upgrade head

# Rollback one step
alembic downgrade -1
```

```python
# migrations/env.py — async migration support
from alembic import context
from sqlalchemy.ext.asyncio import create_async_engine

async def run_async_migrations():
    engine = create_async_engine(DATABASE_URL)
    async with engine.connect() as conn:
        await conn.run_sync(do_run_migrations)
    await engine.dispose()

def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=Base.metadata)
    with context.begin_transaction():
        context.run_migrations()
```

---

## 16. Project Structure

### Router-Based (Small to Medium APIs)

```
app/
├── main.py                 # FastAPI app, lifespan, middleware, router includes
├── config.py               # Settings via pydantic-settings
├── database.py             # Engine, sessionmaker, Base
├── models.py               # SQLAlchemy ORM models
├── schemas/                # Pydantic schemas (request/response)
│   ├── user.py
│   └── item.py
├── routers/                # APIRouter per resource
│   ├── auth.py
│   ├── users.py
│   └── items.py
├── dependencies.py         # Shared Depends() functions
├── security.py             # JWT, password hashing
└── services/               # Business logic layer
    ├── user_service.py
    └── item_service.py
```

### Domain-Driven (Large APIs)

```
app/
├── main.py
├── core/
│   ├── config.py           # pydantic-settings BaseSettings
│   ├── database.py
│   ├── security.py
│   └── dependencies.py
├── users/
│   ├── router.py           # APIRouter
│   ├── models.py           # ORM models
│   ├── schemas.py          # Pydantic schemas
│   ├── service.py          # Business logic
│   └── repository.py      # DB access layer
├── items/
│   └── ...
└── shared/
    ├── exceptions.py
    └── pagination.py
```

### Configuration with pydantic-settings

```python
from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    database_url: str
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    environment: str = "development"
    debug: bool = False
    allowed_hosts: list[str] = ["*"]

@lru_cache
def get_settings() -> Settings:
    return Settings()

Settings = Annotated[Settings, Depends(get_settings)]
```

---

## 17. Testing

### TestClient (Sync)

```python
from fastapi.testclient import TestClient
from app.main import app
from app.database import get_db
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Test database
TEST_DB_URL = "postgresql://user:pass@localhost/test_db"
test_engine = create_engine(TEST_DB_URL)
TestSession = sessionmaker(test_engine)

def override_get_db():
    db = TestSession()
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

client = TestClient(app)

def test_create_user():
    response = client.post(
        "/users",
        json={"username": "alice", "email": "alice@example.com", "password": "secure123"},
    )
    assert response.status_code == 201
    data = response.json()
    assert data["username"] == "alice"
    assert "id" in data
```

### Async Testing with pytest-asyncio

```python
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

@pytest.fixture
async def async_client():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        yield client

@pytest.mark.asyncio
async def test_create_item(async_client: AsyncClient):
    response = await async_client.post(
        "/items",
        json={"name": "Widget", "price": 9.99},
        headers={"Authorization": "Bearer test-token"},
    )
    assert response.status_code == 201

# pytest.ini or pyproject.toml
# [tool.pytest.ini_options]
# asyncio_mode = "auto"
```

### Dependency Overrides for Testing

```python
from app.security import get_current_user
from app.models import User

def make_mock_user(user_id: int = 1, role: str = "user") -> User:
    return User(id=user_id, username="testuser", email="test@example.com", role=role)

@pytest.fixture
def authenticated_client(client: TestClient):
    app.dependency_overrides[get_current_user] = lambda: make_mock_user()
    yield client
    app.dependency_overrides.clear()

@pytest.fixture
def admin_client(client: TestClient):
    app.dependency_overrides[get_current_user] = lambda: make_mock_user(role="admin")
    yield client
    app.dependency_overrides.clear()
```

---

## 18. Deployment and Performance

### Uvicorn

```bash
# Development
uvicorn app.main:app --reload --port 8000

# Production (single process)
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1 \
  --log-level warning --access-log --no-server-header
```

### Gunicorn + Uvicorn Workers

For multi-core production deployments, Gunicorn manages worker processes, each running Uvicorn:

```bash
gunicorn app.main:app \
  --worker-class uvicorn.workers.UvicornWorker \
  --workers 4 \               # typically 2 * CPU_COUNT + 1
  --bind 0.0.0.0:8000 \
  --timeout 120 \
  --keepalive 5 \
  --max-requests 1000 \       # restart worker after N requests (prevent memory leaks)
  --max-requests-jitter 50 \  # randomize restart to avoid thundering herd
  --preload                   # load app before forking workers
```

### Docker

```dockerfile
FROM python:3.12-slim

WORKDIR /app

# Install dependencies first (layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Non-root user
RUN adduser --disabled-password --no-create-home appuser
USER appuser

EXPOSE 8000
CMD ["gunicorn", "app.main:app", \
     "--worker-class", "uvicorn.workers.UvicornWorker", \
     "--bind", "0.0.0.0:8000", \
     "--workers", "4"]
```

```yaml
# docker-compose.yml
services:
  api:
    build: .
    ports: ["8000:8000"]
    environment:
      DATABASE_URL: postgresql+asyncpg://user:pass@db/mydb
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16
    environment:
      POSTGRES_DB: mydb
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 5s
      retries: 5
```

### Async Database Drivers and Connection Pooling

```python
# asyncpg (PostgreSQL) — fastest async PostgreSQL driver
engine = create_async_engine(
    "postgresql+asyncpg://user:pass@localhost/db",
    pool_size=20,
    max_overflow=0,         # no overflow for production (predictable load)
    pool_pre_ping=True,     # test connections before checkout
    pool_recycle=3600,
)

# aiomysql (MySQL/MariaDB)
engine = create_async_engine(
    "mysql+aiomysql://user:pass@localhost/db",
    pool_size=10,
    max_overflow=5,
)

# aiosqlite (SQLite for development/testing only)
engine = create_async_engine("sqlite+aiosqlite:///./test.db")
```

### Performance Patterns

```python
# 1. Use ORJSONResponse for faster JSON serialization
from fastapi.responses import ORJSONResponse
app = FastAPI(default_response_class=ORJSONResponse)

# 2. Select only needed columns
result = await db.execute(select(User.id, User.username).where(User.active == True))

# 3. Batch loading with selectin loading to avoid N+1
from sqlalchemy.orm import selectinload
result = await db.execute(
    select(User).options(selectinload(User.items)).where(User.active == True)
)

# 4. Use asyncio.gather for concurrent independent queries
user, items = await asyncio.gather(
    db.get(User, user_id),
    db.execute(select(Item).where(Item.user_id == user_id)),
)

# 5. Response caching with custom middleware
from functools import lru_cache
import hashlib

class CacheMiddleware(BaseHTTPMiddleware):
    cache: dict[str, tuple[bytes, str]] = {}

    async def dispatch(self, request: Request, call_next) -> Response:
        if request.method != "GET":
            return await call_next(request)
        
        key = hashlib.md5(str(request.url).encode()).hexdigest()
        if key in self.cache:
            content, media_type = self.cache[key]
            return Response(content=content, media_type=media_type)
        
        response = await call_next(request)
        # Only cache small responses
        body = b"".join([chunk async for chunk in response.body_iterator])
        self.cache[key] = (body, response.media_type)
        return Response(content=body, media_type=response.media_type,
                       headers=dict(response.headers))
```

---

## Key Architectural Decisions Summary

| Concern | Recommended Approach |
|---|---|
| Validation | Pydantic v2 `BaseModel` with `model_config` |
| DB sessions | `yield` dependency with async context manager |
| Auth | OAuth2PasswordBearer + PyJWT, scopes for RBAC |
| Response serialization | Return type annotation + explicit `model_validate()` |
| Async I/O | `async def` + asyncpg/aiomysql; sync libs in `def` |
| Background work | FastAPI `BackgroundTasks` (light) or ARQ/Celery (heavy) |
| Middleware | Pure ASGI for perf-critical; `BaseHTTPMiddleware` for convenience |
| JSON performance | `ORJSONResponse` as default response class |
| Testing | `dependency_overrides` + `AsyncClient` with `ASGITransport` |
| Deployment | Gunicorn + UvicornWorker, `pool_pre_ping=True`, non-root Docker user |
| Project layout | Domain-driven for >3 resource types |
| Config | `pydantic-settings` `BaseSettings` + `.env` file |
| Migrations | Alembic with async engine in `env.py` |
