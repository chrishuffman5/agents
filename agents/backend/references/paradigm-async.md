# Async-First Framework Patterns

## Async Runtime Models

### Node.js Event Loop (Express, NestJS)

```
┌───────────────────────────────┐
│         Call Stack             │  Single-threaded JavaScript execution
└──────────┬────────────────────┘
           │
┌──────────▼────────────────────┐
│        Event Loop              │  Polls for completed I/O, timers, callbacks
│  ┌─────────────────────────┐  │
│  │  Microtask Queue        │  │  Promise callbacks, queueMicrotask
│  │  (processed after each  │  │
│  │   macrotask)            │  │
│  └─────────────────────────┘  │
│  ┌─────────────────────────┐  │
│  │  Macrotask Queue        │  │  setTimeout, setInterval, I/O callbacks
│  └─────────────────────────┘  │
└───────────────────────────────┘
           │
┌──────────▼────────────────────┐
│     libuv Thread Pool          │  File I/O, DNS, crypto (4 threads default)
└───────────────────────────────┘
```

**Key insight**: Node.js is single-threaded for JavaScript execution but uses OS-level async I/O (epoll, kqueue) for network operations and a thread pool for file I/O. One blocked synchronous call blocks the entire event loop.

### Python asyncio (FastAPI)

```python
import asyncio
from fastapi import FastAPI

app = FastAPI()

@app.get("/users/{user_id}")
async def get_user(user_id: int):
    # This releases the event loop while waiting for the DB
    user = await db.fetch_one("SELECT * FROM users WHERE id = $1", user_id)
    # Other requests can be handled during the await
    return user
```

**asyncio event loop**: Single-threaded coroutine scheduler. `await` suspends the coroutine, returns control to the event loop, which can run other coroutines. Not true parallelism — cooperative multitasking.

**The GIL problem**: Python's Global Interpreter Lock means CPU-bound work blocks the event loop even in async code. Mitigations:
- `asyncio.to_thread()` — offload to a thread (bypasses GIL for I/O, not CPU)
- `ProcessPoolExecutor` — true parallelism for CPU work
- Use Rust/C extensions for CPU-heavy operations

### Tokio (Actix Web, Axum)

```rust
use axum::{Router, routing::get, Json};

async fn get_user(Path(id): Path<u32>) -> Json<User> {
    // Tokio manages a thread pool of async workers
    // .await yields the thread back to Tokio's scheduler
    let user = db.fetch_user(id).await;
    Json(user)
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/users/:id", get(get_user));
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

**Tokio runtime**: Multi-threaded async executor. Work-stealing scheduler distributes tasks across OS threads. No GIL — true parallelism for both I/O and CPU-bound async tasks. `spawn_blocking()` for synchronous code that would block the executor.

### Go Goroutines (net/http, Gin)

```go
func getUser(w http.ResponseWriter, r *http.Request) {
    // Each request gets its own goroutine (lightweight green thread)
    // Goroutines are multiplexed onto OS threads by the Go scheduler
    user, err := db.QueryRow("SELECT * FROM users WHERE id = $1", id)
    json.NewEncoder(w).Encode(user)
}
```

**Go's model is different**: Not async/await. Goroutines look synchronous but the runtime handles scheduling. `net/http` spawns a goroutine per request automatically. No explicit async/await syntax — blocking calls yield to the scheduler implicitly.

### .NET async/await (ASP.NET Core)

```csharp
[HttpGet("{id}")]
public async Task<ActionResult<User>> GetUser(int id)
{
    // .NET's async is thread pool-based
    // await releases the thread back to the pool
    var user = await _context.Users.FindAsync(id);
    return Ok(user);
}
```

**ThreadPool-based**: .NET uses `SynchronizationContext` and a managed thread pool. `await` doesn't create new threads — it returns the current thread to the pool. When the I/O completes, any available thread continues the work. Excellent for I/O-bound server workloads.

## When Async Helps vs Hurts

### Async Wins

| Scenario | Why Async Helps |
|---|---|
| API gateway/proxy | Mostly waiting for upstream responses — release threads |
| Database-heavy CRUD | DB queries are I/O — release threads during query |
| External API calls | HTTP client calls are pure I/O |
| WebSocket connections | Many idle connections, minimal CPU per message |
| File uploads/downloads | Stream data without holding threads |
| Chat / real-time | Thousands of mostly-idle connections |

### Async Doesn't Help (or Hurts)

| Scenario | Why |
|---|---|
| CPU-heavy computation | The CPU is busy regardless of async — no thread to release |
| Simple in-memory operations | Async overhead exceeds the I/O wait time |
| Single-user CLI tool | No concurrent requests to benefit from |
| Complex business logic | Async makes debugging harder with no I/O benefit |

### The Async Tax

Async code has real costs:
- **Debugging is harder** — stack traces are fragmented across await points
- **Error handling is different** — unhandled promise rejections, task cancellation semantics
- **Libraries must be async-compatible** — mixing sync and async is a common source of bugs
- **Testing requires async test runners** — `pytest-asyncio`, `async` test methods
- **Deadlocks from sync-in-async** — calling sync I/O inside async context blocks the event loop

### Framework Performance Context

Benchmarks (TechEmpower, techempower.com) show relative framework performance, but context matters:

| Tier | Frameworks | RPS (JSON serialization) | Note |
|---|---|---|---|
| **Top** | Actix, Axum, Drogon, h2o | 500K-1M+ | Highly optimized, systems languages |
| **High** | Go net/http, Gin, ASP.NET Core | 200K-500K | Great performance with productive languages |
| **Good** | FastAPI, NestJS, Express | 50K-150K | Good enough for most workloads |
| **Moderate** | Django, Rails, Flask | 10K-50K | Framework overhead, but DB is usually the bottleneck |

**The uncomfortable truth**: The difference between 50K and 500K RPS almost never matters. Your database caps out at 10K QPS long before your framework becomes the bottleneck. Optimize the database layer and architecture first.

## Structured Concurrency

### NestJS Approach (Angular-Inspired DI)

NestJS applies structure to Node.js with modules, providers, and dependency injection:

```typescript
@Module({
  imports: [TypeOrmModule.forFeature([User])],
  controllers: [UsersController],
  providers: [UsersService],
})
export class UsersModule {}

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  async findOne(id: number): Promise<User> {
    return this.usersRepository.findOneBy({ id });
  }
}
```

This sacrifices Express's simplicity for enterprise-grade organization. Good for large teams — each module is self-contained with clear boundaries.

### FastAPI Approach (Type-Driven)

FastAPI uses Python type hints as the single source of truth for validation, serialization, and documentation:

```python
from fastapi import FastAPI, Depends
from pydantic import BaseModel

class UserCreate(BaseModel):
    name: str
    email: EmailStr
    age: int = Field(ge=0, le=150)

@app.post("/users", response_model=UserResponse, status_code=201)
async def create_user(user: UserCreate, db: Session = Depends(get_db)):
    # user is already validated by Pydantic
    # OpenAPI docs are auto-generated from the type hints
    # Response is auto-serialized to match UserResponse schema
    ...
```

This eliminates the class of bugs where validation, serialization, and documentation diverge. The schema IS the code.
