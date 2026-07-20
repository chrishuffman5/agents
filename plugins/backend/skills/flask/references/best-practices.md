# Flask Best Practices Reference

## Project Structure

### Functional Layout (Small/Medium Apps)

```
myproject/
    myapp/
        __init__.py          # create_app()
        extensions.py        # db, migrate, login_manager, etc.
        config.py            # Config classes
        models.py            # All models (or models/)
        views.py             # All views (or split by blueprint)
        forms.py
        utils.py
        cli.py
        templates/
            base.html
            users/
            auth/
        static/
            css/
            js/
    instance/
        config.py            # Secrets (git-ignored)
    migrations/
    tests/
        conftest.py
        test_auth.py
        test_users.py
    wsgi.py
    requirements.txt
    .env
    Dockerfile
```

### Divisional Layout (Large Apps, Recommended)

```
myproject/
    myapp/
        __init__.py          # create_app()
        extensions.py
        config.py
        auth/
            __init__.py      # Blueprint definition
            routes.py
            forms.py
            models.py
            templates/
                auth/
                    login.html
        api/
            __init__.py
            v1/
                __init__.py  # API v1 blueprint
                users.py
                posts.py
                schemas.py   # Marshmallow schemas
        admin/
            __init__.py
            routes.py
            templates/
                admin/
        core/
            __init__.py
            models.py        # Shared base models
            utils.py
        templates/           # App-level templates
            base.html
            errors/
        static/
    instance/
    migrations/
    tests/
    wsgi.py
```

**Rule of thumb:** Start functional, refactor to divisional when any module exceeds ~300 lines or two developers are working on the same file.

---

## Extensions Integration

### Flask-SQLAlchemy

```python
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.orm import DeclarativeBase

class Base(DeclarativeBase):
    pass

db = SQLAlchemy(model_class=Base)
```

```python
# myapp/models/user.py
from datetime import datetime
from myapp.extensions import db

class User(db.Model):
    __tablename__ = "users"

    id: db.Mapped[int] = db.mapped_column(db.Integer, primary_key=True)
    email: db.Mapped[str] = db.mapped_column(db.String(255), unique=True, nullable=False)
    password_hash: db.Mapped[str] = db.mapped_column(db.String(255), nullable=False)
    created_at: db.Mapped[datetime] = db.mapped_column(
        db.DateTime, default=datetime.utcnow, nullable=False
    )
    posts: db.Mapped[list["Post"]] = db.relationship("Post", back_populates="author")

    def to_dict(self) -> dict:
        return {"id": self.id, "email": self.email}
```

### Session Management

Flask-SQLAlchemy provides a scoped session tied to the request lifecycle. The session is committed or rolled back and removed at request teardown.

```python
# Explicit commit pattern (recommended over autocommit)
@app.route("/users", methods=["POST"])
def create_user():
    try:
        user = User(email=request.json["email"])
        user.set_password(request.json["password"])
        db.session.add(user)
        db.session.commit()
        return jsonify(user.to_dict()), 201
    except IntegrityError:
        db.session.rollback()
        return jsonify(error="Email already exists"), 409
```

### Repository Pattern

```python
# myapp/repositories/user_repo.py
from sqlalchemy import select, func
from myapp.extensions import db
from myapp.models import User

class UserRepository:
    def get_by_id(self, user_id: int) -> User | None:
        return db.session.get(User, user_id)

    def get_by_email(self, email: str) -> User | None:
        return db.session.scalar(select(User).where(User.email == email))

    def list_paginated(self, page: int, per_page: int = 20) -> tuple[list[User], int]:
        stmt = select(User).order_by(User.created_at.desc())
        paginated = db.paginate(stmt, page=page, per_page=per_page)
        return paginated.items, paginated.total

    def create(self, email: str, password: str) -> User:
        user = User(email=email)
        user.set_password(password)
        db.session.add(user)
        db.session.flush()
        return user
```

### Model Patterns (SQLAlchemy 2.x Mapped)

```python
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, ForeignKey, Text

class Post(db.Model):
    __tablename__ = "posts"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    body: Mapped[str] = mapped_column(Text)
    published: Mapped[bool] = mapped_column(default=False)
    author_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    created_at: Mapped[datetime] = mapped_column(default=datetime.utcnow)

    author: Mapped["User"] = relationship(back_populates="posts")
```

### Eager Loading to Avoid N+1

```python
from sqlalchemy.orm import selectinload, joinedload

# Bad: N+1 queries
posts = Post.query.all()
for post in posts:
    print(post.author.email)  # triggers a query per post

# Good: eager load
posts = db.session.scalars(
    select(Post).options(selectinload(Post.author))
).all()

# joinedload for single objects; selectinload for collections
user = db.session.scalar(
    select(User).options(joinedload(User.posts)).where(User.id == user_id)
)
```

### Flask-Migrate (Alembic)

```bash
flask db init       # Creates migrations/ directory
flask db migrate -m "add users table"
flask db upgrade    # Apply pending migrations
flask db downgrade  # Roll back one revision
flask db history    # Show migration history
```

### Flask-Login

```python
from flask_login import UserMixin, login_required, current_user

class User(UserMixin, db.Model):
    # UserMixin provides: is_authenticated, is_active, is_anonymous, get_id()
    ...

@login_manager.user_loader
def load_user(user_id: str) -> User | None:
    return db.session.get(User, int(user_id))

login_manager.login_view = "auth.login"
login_manager.login_message_category = "info"

@app.route("/dashboard")
@login_required
def dashboard():
    return f"Hello, {current_user.email}"
```

### Flask-WTF

```python
from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, SubmitField
from wtforms.validators import DataRequired, Email, Length

class LoginForm(FlaskForm):
    email = StringField("Email", validators=[DataRequired(), Email()])
    password = PasswordField("Password", validators=[DataRequired(), Length(min=8)])
    submit = SubmitField("Log In")
```

```html
<!-- Renders CSRF token automatically -->
<form method="POST">
    {{ form.hidden_tag() }}
    {{ form.email.label }} {{ form.email() }}
    {{ form.password.label }} {{ form.password() }}
    {{ form.submit() }}
</form>
```

### Flask-CORS

```python
from flask_cors import CORS

# Allow all origins (development only)
CORS(app)

# Production: restrict to specific origins
CORS(app, resources={
    r"/api/*": {
        "origins": ["https://app.example.com"],
        "methods": ["GET", "POST", "PUT", "DELETE"],
        "allow_headers": ["Content-Type", "Authorization"],
    }
})
```

### Flask-JWT-Extended

```python
from flask_jwt_extended import (
    JWTManager, create_access_token, create_refresh_token,
    jwt_required, get_jwt_identity, get_jwt,
)

jwt = JWTManager(app)

@app.route("/login", methods=["POST"])
def login():
    user = authenticate(request.json["email"], request.json["password"])
    access_token = create_access_token(identity=user.id, additional_claims={"role": user.role})
    refresh_token = create_refresh_token(identity=user.id)
    return jsonify(access_token=access_token, refresh_token=refresh_token)

@app.route("/protected")
@jwt_required()
def protected():
    user_id = get_jwt_identity()
    claims = get_jwt()
    return jsonify(user_id=user_id, role=claims["role"])

@app.route("/refresh", methods=["POST"])
@jwt_required(refresh=True)
def refresh():
    identity = get_jwt_identity()
    return jsonify(access_token=create_access_token(identity=identity))
```

### Flask-Caching

```python
from flask_caching import Cache

cache = Cache()

# config: CACHE_TYPE = "RedisCache", CACHE_REDIS_URL = "redis://localhost:6379/0"

@app.route("/expensive")
@cache.cached(timeout=300, key_prefix="expensive_view")
def expensive():
    return jsonify(compute_expensive_thing())

@cache.memoize(timeout=60)
def get_user_data(user_id: int) -> dict:
    return User.query.get(user_id).to_dict()

cache.delete_memoized(get_user_data, user_id)
cache.clear()
```

### Flask-Mail

```python
from flask_mail import Mail, Message

mail = Mail()

def send_welcome_email(user: User) -> None:
    msg = Message(
        subject="Welcome!",
        sender=app.config["MAIL_DEFAULT_SENDER"],
        recipients=[user.email],
    )
    msg.body = f"Hello {user.email}, welcome to MyApp."
    msg.html = render_template("email/welcome.html", user=user)
    mail.send(msg)
```

### Flask-Smorest / APIFlask (OpenAPI-First REST APIs)

```python
from flask_smorest import Api, Blueprint
from marshmallow import Schema, fields

api = Api(app)  # Serves /api/swagger-ui and /api/openapi.json

class UserSchema(Schema):
    id = fields.Int(dump_only=True)
    email = fields.Email(required=True)

users_bp = Blueprint("users", __name__, url_prefix="/users", description="User operations")

@users_bp.route("/")
class UserList(MethodView):
    @users_bp.response(200, UserSchema(many=True))
    def get(self):
        return User.query.all()

    @users_bp.arguments(UserSchema)
    @users_bp.response(201, UserSchema)
    def post(self, new_data):
        user = User(**new_data)
        db.session.add(user)
        db.session.commit()
        return user

api.register_blueprint(users_bp)
```

---

## Testing

### pytest Fixtures

```python
# tests/conftest.py
import pytest
from myapp import create_app
from myapp.extensions import db as _db

@pytest.fixture(scope="session")
def app():
    app = create_app("testing")
    with app.app_context():
        _db.create_all()
        yield app
        _db.drop_all()

@pytest.fixture(scope="function")
def db(app):
    """Provide a clean DB transaction per test -- rollback after each test."""
    connection = _db.engine.connect()
    transaction = connection.begin()
    _db.session.bind = connection
    yield _db
    _db.session.remove()
    transaction.rollback()
    connection.close()

@pytest.fixture
def client(app):
    return app.test_client()

@pytest.fixture
def cli_runner(app):
    return app.test_cli_runner()

@pytest.fixture
def auth_headers(client, db):
    """Return headers with a valid JWT."""
    resp = client.post("/auth/login", json={"email": "test@example.com", "password": "password"})
    token = resp.json["access_token"]
    return {"Authorization": f"Bearer {token}"}
```

### Writing Tests

```python
def test_get_user_list(client):
    resp = client.get("/api/v1/users/")
    assert resp.status_code == 200
    assert isinstance(resp.json, list)

def test_create_user(client, db):
    payload = {"email": "new@example.com", "password": "strongpass"}
    resp = client.post("/api/v1/users/", json=payload)
    assert resp.status_code == 201
    assert resp.json["email"] == payload["email"]

def test_protected_route_requires_auth(client):
    resp = client.get("/api/v1/protected")
    assert resp.status_code == 401

def test_protected_route_with_auth(client, auth_headers):
    resp = client.get("/api/v1/protected", headers=auth_headers)
    assert resp.status_code == 200

def test_seed_command(cli_runner):
    result = cli_runner.invoke(args=["db-tools", "seed", "--count", "5"])
    assert result.exit_code == 0
    assert "Seeded 5 users" in result.output
```

### Testing Request Context Directly

```python
def test_url_for(app):
    with app.test_request_context("/"):
        from flask import url_for
        assert url_for("auth.login") == "/auth/login"
```

---

## Security

### CSRF with Flask-WTF

Flask-WTF enables CSRF protection by default for form submissions. For API endpoints using JWT instead of cookies, disable per-view or exempt blueprints.

```python
from flask_wtf.csrf import CSRFProtect

csrf = CSRFProtect(app)

# Exempt API blueprint from CSRF (JWT-protected instead)
@csrf.exempt
@api_bp.route("/webhook", methods=["POST"])
def webhook():
    ...

# Ajax: include CSRF token in request header
# X-CSRFToken: {{ csrf_token() }}
```

### Secure Cookie Configuration

```python
app.config.update(
    SECRET_KEY=os.environ["SECRET_KEY"],
    SESSION_COOKIE_SECURE=True,        # HTTPS only
    SESSION_COOKIE_HTTPONLY=True,       # Not accessible via JS
    SESSION_COOKIE_SAMESITE="Lax",     # CSRF mitigation
    REMEMBER_COOKIE_SECURE=True,
    REMEMBER_COOKIE_HTTPONLY=True,
    WTF_CSRF_TIME_LIMIT=3600,          # CSRF token expiry (seconds)
)
```

### Password Hashing

```python
from werkzeug.security import generate_password_hash, check_password_hash

class User(db.Model):
    password_hash: db.Mapped[str] = db.mapped_column(db.String(255))

    def set_password(self, password: str) -> None:
        self.password_hash = generate_password_hash(password, method="scrypt")

    def check_password(self, password: str) -> bool:
        return check_password_hash(self.password_hash, password)
```

### Security Headers with Flask-Talisman

```python
from flask_talisman import Talisman

Talisman(
    app,
    force_https=True,
    strict_transport_security=True,
    content_security_policy={
        "default-src": "'self'",
        "script-src": ["'self'", "cdn.example.com"],
    },
)
```

---

## Error Handling

### Application-Level Error Handlers

```python
from werkzeug.exceptions import HTTPException

@app.errorhandler(404)
def not_found(e):
    if request.accept_mimetypes.accept_json:
        return jsonify(error=str(e), code=404), 404
    return render_template("errors/404.html"), 404

@app.errorhandler(500)
def internal_error(e):
    db.session.rollback()  # Ensure DB session is clean
    app.logger.exception("Internal server error")
    return jsonify(error="Internal server error"), 500

@app.errorhandler(HTTPException)
def handle_http_exception(e: HTTPException):
    return jsonify(code=e.code, name=e.name, description=e.description), e.code
```

### Custom Exceptions

```python
class ResourceNotFound(Exception):
    def __init__(self, resource: str, id: int):
        self.resource = resource
        self.id = id
        super().__init__(f"{resource} {id} not found")

@app.errorhandler(ResourceNotFound)
def handle_not_found(e):
    return jsonify(error=str(e), resource=e.resource, id=e.id), 404
```

---

## Deployment

### Gunicorn (Linux/Mac)

```bash
pip install gunicorn

# Sync workers
gunicorn "myapp:create_app('production')" \
    --workers 4 \
    --bind 0.0.0.0:8000 \
    --timeout 30 \
    --access-logfile - \
    --error-logfile -

# Async workers (install gevent first)
gunicorn "myapp:create_app()" \
    --worker-class gevent \
    --workers 2 \
    --worker-connections 1000
```

### Waitress (Windows / Cross-Platform)

```python
from waitress import serve
from myapp import create_app

app = create_app("production")

if __name__ == "__main__":
    serve(app, host="0.0.0.0", port=8000, threads=8)
```

### Nginx Reverse Proxy

```nginx
server {
    listen 443 ssl;
    server_name example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    client_max_body_size 16M;

    location /static/ {
        alias /app/myapp/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```python
# When behind a proxy, use ProxyFix middleware
from werkzeug.middleware.proxy_fix import ProxyFix
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_prefix=1)
```

### Docker

```dockerfile
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

ENV FLASK_ENV=production
EXPOSE 8000

CMD ["gunicorn", "wsgi:app", "--workers", "4", "--bind", "0.0.0.0:8000"]
```

```yaml
# docker-compose.yml
services:
  web:
    build: .
    env_file: .env
    ports: ["8000:8000"]
    depends_on: [db, redis]

  db:
    image: postgres:16
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: myapp
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes: [pgdata:/var/lib/postgresql/data]

  redis:
    image: redis:7-alpine

volumes:
  pgdata:
```

---

## Performance

### Key Recommendations

| Area | Recommendation |
|---|---|
| **Static files** | Serve via Nginx, not Flask (`/static/`) |
| **Database** | Use eager loading, avoid N+1. Index frequently queried columns |
| **Caching** | Use Flask-Caching with Redis for expensive queries |
| **Workers** | Gunicorn: `(2 * CPU) + 1` workers for sync, fewer for gevent |
| **Serialization** | Use `orjson` for faster JSON if needed |
| **Compression** | Enable GZip at Nginx level |
| **Profiling** | Use `flask-debugtoolbar` in dev, `py-spy` in production |

### Celery for Background Tasks

```python
from celery import Celery

def make_celery(app: Flask) -> Celery:
    celery = Celery(app.name)
    celery.conf.update(app.config.get("CELERY", {}))

    class FlaskTask(celery.Task):
        def __call__(self, *args, **kwargs):
            with app.app_context():
                return self.run(*args, **kwargs)

    celery.Task = FlaskTask
    return celery
```

---

## Flask vs FastAPI Decision Guide

### Side-by-Side Comparison

| Dimension | Flask 3.1 | FastAPI |
|---|---|---|
| **Paradigm** | WSGI, sync-first | ASGI, async-first |
| **Routing** | Decorator-based | Decorator-based (similar syntax) |
| **Validation** | Manual / WTForms / Marshmallow | Pydantic v2 built-in |
| **OpenAPI** | Via Flask-Smorest / APIFlask | Automatic (Swagger UI + ReDoc) |
| **Performance** | Good (Gunicorn + gevent) | Excellent (Uvicorn + async I/O) |
| **Learning curve** | Gentle; huge ecosystem | Moderate; requires Pydantic |
| **Type hints** | Optional, no runtime enforcement | Core -- type hints drive validation |
| **WebSockets** | Via Flask-SocketIO (gevent) | Native (Starlette) |
| **Maturity** | Very mature (2010) | Mature (2018), fast-growing |
| **Extensions** | Massive ecosystem | Smaller, often use Starlette/anyio |
| **Testing** | test_client, pytest | TestClient (httpx-based) |

### When to Use Flask

- You need server-rendered Jinja2 templates (full-stack web app).
- Your team knows Flask and the project scope doesn't justify migration.
- You rely on specific Flask extensions (Flask-Admin, Flask-Login, Flask-WTF).
- The app is sync-dominant (CRUD, background tasks via Celery).
- You're building internal tooling or prototypes where velocity > performance.
- You need fine-grained control over request/response without framework magic.

### When to Use FastAPI

- You're building a pure JSON REST or GraphQL API (not rendering HTML).
- You need automatic OpenAPI documentation with response validation.
- High-concurrency I/O (thousands of simultaneous connections, streaming).
- You want Python type hints to enforce request/response contracts at runtime.
- Your team is comfortable with `async/await` and ASGI.
- You need built-in dependency injection.

### Migration Path: Flask to FastAPI

For greenfield API services, prefer FastAPI. For hybrid apps (API + templates), Flask remains pragmatic. Common pattern: keep Flask for the web frontend, build new microservices in FastAPI.

```python
# Flask (classic)
@app.route("/users/<int:user_id>", methods=["GET"])
def get_user(user_id):
    user = User.query.get_or_404(user_id)
    return jsonify(user.to_dict())

# FastAPI equivalent
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

class UserResponse(BaseModel):
    id: int
    email: str
    model_config = ConfigDict(from_attributes=True)

@app.get("/users/{user_id}")
async def get_user(user_id: int) -> UserResponse:
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(404)
    return UserResponse.model_validate(user)
```
