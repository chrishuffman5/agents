# Flask 3.1 Framework Architecture and Patterns

> Target audience: Senior Python developers. Flask 3.1 with Python 3.10+.

---

## Table of Contents

1. [Application Factory Pattern](#1-application-factory-pattern)
2. [Blueprints](#2-blueprints)
3. [Routing](#3-routing)
4. [Request and Response](#4-request-and-response)
5. [Jinja2 Templates](#5-jinja2-templates)
6. [Application and Request Context](#6-application-and-request-context)
7. [Configuration](#7-configuration)
8. [Extensions Ecosystem](#8-extensions-ecosystem)
9. [Error Handling](#9-error-handling)
10. [Signals (Blinker)](#10-signals-blinker)
11. [CLI Commands](#11-cli-commands)
12. [Testing](#12-testing)
13. [Deployment](#13-deployment)
14. [Security](#14-security)
15. [Async Support](#15-async-support)
16. [SQLAlchemy Integration Patterns](#16-sqlalchemy-integration-patterns)
17. [Project Structure](#17-project-structure)
18. [Flask vs FastAPI](#18-flask-vs-fastapi)

---

## 1. Application Factory Pattern

The application factory pattern is the cornerstone of production Flask applications. Instead of creating a global `app` instance at module level, a `create_app` function constructs and configures the application. This enables multiple instances (testing, staging, production), deferred initialization, and clean import graphs.

```python
# myapp/__init__.py
from flask import Flask
from .extensions import db, migrate, login_manager, cache
from .config import config_by_name


def create_app(config_name: str = "production") -> Flask:
    app = Flask(__name__, instance_relative_config=True)

    # Load configuration
    app.config.from_object(config_by_name[config_name])
    app.config.from_pyfile("config.py", silent=True)  # instance override

    # Initialize extensions (order matters — db before migrate)
    db.init_app(app)
    migrate.init_app(app, db)
    login_manager.init_app(app)
    cache.init_app(app)

    # Register blueprints
    from .api.v1 import api_v1_bp
    from .auth import auth_bp
    from .admin import admin_bp

    app.register_blueprint(auth_bp, url_prefix="/auth")
    app.register_blueprint(api_v1_bp, url_prefix="/api/v1")
    app.register_blueprint(admin_bp, url_prefix="/admin")

    # Register error handlers, shell context, CLI commands
    register_error_handlers(app)
    register_shell_context(app)
    register_cli(app)

    return app


def register_shell_context(app: Flask) -> None:
    from .models import User, Post

    @app.shell_context_processor
    def make_shell_context():
        return {"db": db, "User": User, "Post": Post}


def register_cli(app: Flask) -> None:
    from .cli import create_db_cmd, seed_cmd

    app.cli.add_command(create_db_cmd)
    app.cli.add_command(seed_cmd)
```

```python
# wsgi.py — entry point for Gunicorn/Waitress
import os
from myapp import create_app

app = create_app(os.environ.get("FLASK_ENV", "production"))
```

**Key benefits:**
- Extension objects are created once in `extensions.py` without an app bound, then `.init_app(app)` is called inside the factory.
- Each test can call `create_app("testing")` for an isolated app with an in-memory database.
- Avoids circular imports: blueprints import from `extensions`, not from `myapp`.

```python
# myapp/extensions.py
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_login import LoginManager
from flask_caching import Cache

db = SQLAlchemy()
migrate = Migrate()
login_manager = LoginManager()
cache = Cache()
```

---

## 2. Blueprints

Blueprints are Flask's modular unit. They record operations to be executed on the application once registered, and carry their own routes, templates, static files, error handlers, and before/after request hooks.

### Basic Registration

```python
# myapp/auth/__init__.py
from flask import Blueprint

auth_bp = Blueprint(
    "auth",
    __name__,
    template_folder="templates",   # myapp/auth/templates/
    static_folder="static",
    url_prefix="/auth",            # can be set here or at register time
)

from . import routes  # noqa: E402, F401 — import routes after blueprint creation
```

```python
# myapp/auth/routes.py
from flask import render_template, redirect, url_for, flash
from flask_login import login_user, logout_user
from . import auth_bp
from ..models import User


@auth_bp.route("/login", methods=["GET", "POST"])
def login():
    # ...
    return render_template("auth/login.html")


@auth_bp.route("/logout")
def logout():
    logout_user()
    return redirect(url_for("auth.login"))  # blueprint_name.view_name
```

### Nesting Blueprints (Flask 2.0+)

```python
# A parent blueprint can register child blueprints
parent_bp = Blueprint("parent", __name__, url_prefix="/parent")
child_bp = Blueprint("child", __name__)

parent_bp.register_blueprint(child_bp, url_prefix="/child")
# Resulting URL: /parent/child/...

app.register_blueprint(parent_bp)
```

### Blueprint-Scoped Error Handlers

```python
@auth_bp.app_errorhandler(403)
def forbidden(e):
    return render_template("errors/403.html"), 403


@auth_bp.errorhandler(404)
def not_found(e):
    # Only catches 404s raised within this blueprint's views
    return render_template("errors/404.html"), 404
```

### Blueprint Before/After Request Hooks

```python
@auth_bp.before_request
def require_json_content_type():
    if request.method in ("POST", "PUT", "PATCH"):
        if not request.is_json:
            abort(415)
```

---

## 3. Routing

### Basic Routing

```python
@app.route("/")
def index():
    return "Hello, World!"


@app.route("/about", methods=["GET"])
def about():
    return render_template("about.html")


@app.route("/submit", methods=["POST"])
def submit():
    data = request.get_json()
    return jsonify(data), 201
```

### Variable Rules and Converters

```python
# Built-in converters: string (default), int, float, path, uuid
@app.route("/users/<int:user_id>")
def get_user(user_id: int):
    user = User.query.get_or_404(user_id)
    return jsonify(user.to_dict())


@app.route("/files/<path:filename>")
def serve_file(filename: str):
    return send_from_directory(app.config["UPLOAD_FOLDER"], filename)


@app.route("/items/<uuid:item_id>")
def get_item(item_id):  # item_id is a uuid.UUID object
    ...
```

### Custom URL Converters

```python
from werkzeug.routing import BaseConverter


class ListConverter(BaseConverter):
    def to_python(self, value: str) -> list[str]:
        return value.split("+")

    def to_url(self, values: list[str]) -> str:
        return "+".join(super().to_url(v) for v in values)


app.url_map.converters["list"] = ListConverter


@app.route("/tags/<list:tags>")
def tagged(tags: list[str]):
    return jsonify(tags)
```

### url_for

```python
from flask import url_for

# Always use url_for — never hardcode URLs
url_for("auth.login")                         # /auth/login
url_for("auth.login", _external=True)         # https://example.com/auth/login
url_for("get_user", user_id=42)               # /users/42
url_for("static", filename="css/main.css")    # /static/css/main.css
url_for("auth.static", filename="auth.css")   # Blueprint static
```

### Class-Based Views

```python
from flask.views import MethodView


class UserResource(MethodView):
    def get(self, user_id: int | None = None):
        if user_id is None:
            return jsonify([u.to_dict() for u in User.query.all()])
        return jsonify(User.query.get_or_404(user_id).to_dict())

    def post(self):
        data = request.get_json(force=True)
        user = User(**data)
        db.session.add(user)
        db.session.commit()
        return jsonify(user.to_dict()), 201

    def delete(self, user_id: int):
        user = User.query.get_or_404(user_id)
        db.session.delete(user)
        db.session.commit()
        return "", 204


user_view = UserResource.as_view("user_resource")
app.add_url_rule("/users/", view_func=user_view, methods=["GET", "POST"])
app.add_url_rule("/users/<int:user_id>", view_func=user_view, methods=["GET", "DELETE"])
```

---

## 4. Request and Response

### The Request Object

```python
from flask import request

# Routing metadata
request.method          # "GET", "POST", etc.
request.url             # Full URL
request.base_url        # URL without query string
request.path            # Path component
request.host            # Hostname
request.endpoint        # Matched endpoint name

# Incoming data
request.args            # ImmutableMultiDict — query string params
request.form            # ImmutableMultiDict — form data (application/x-www-form-urlencoded)
request.files           # ImmutableMultiDict — uploaded files (FileStorage objects)
request.json            # Parsed JSON body (or None if Content-Type wrong)
request.get_json(
    force=True,         # Ignore Content-Type header
    silent=True,        # Return None on parse error instead of raising
)
request.data            # Raw body bytes
request.headers         # EnvironHeaders — case-insensitive dict
request.cookies         # Dict of cookies
request.remote_addr     # Client IP (use with caution behind proxies)

# File upload
file = request.files["avatar"]
if file and allowed_file(file.filename):
    filename = secure_filename(file.filename)
    file.save(os.path.join(app.config["UPLOAD_FOLDER"], filename))
```

### Response Helpers

```python
from flask import jsonify, make_response, redirect, url_for, send_file, abort

# jsonify — sets Content-Type: application/json
return jsonify({"status": "ok", "data": result}), 200

# make_response — full control
resp = make_response(jsonify({"error": "not found"}), 404)
resp.headers["X-Custom"] = "value"
resp.set_cookie("session_id", "abc123", httponly=True, samesite="Lax")
return resp

# Redirect
return redirect(url_for("auth.login"), 302)
return redirect("https://example.com", 301)

# Send a file
return send_file("path/to/file.pdf", as_attachment=True, download_name="report.pdf")

# abort — raises HTTPException immediately
abort(404)          # Not Found
abort(403)          # Forbidden
abort(400, "Invalid request body")

# Return a tuple (body, status, headers)
return "Created", 201, {"Location": url_for("get_user", user_id=new_id)}
```

### Streaming Responses

```python
from flask import stream_with_context, Response
import time


def generate_events():
    for i in range(10):
        yield f"data: {i}\n\n"
        time.sleep(0.5)


@app.route("/stream")
def stream():
    return Response(
        stream_with_context(generate_events()),
        mimetype="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
```

---

## 5. Jinja2 Templates

Flask uses Jinja2 with autoescaping enabled for `.html`, `.xml`, `.svg`, and `.xhtml` by default in Flask 3.x.

### Template Inheritance

```html
<!-- templates/base.html -->
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>{% block title %}My App{% endblock %}</title>
    {% block head %}{% endblock %}
</head>
<body>
    {% include "partials/_nav.html" %}
    <main>{% block content %}{% endblock %}</main>
    {% block scripts %}{% endblock %}
</body>
</html>
```

```html
<!-- templates/users/list.html -->
{% extends "base.html" %}

{% block title %}Users — {{ super() }}{% endblock %}

{% block content %}
  <ul>
    {% for user in users %}
      <li>{{ user.name | title }} — {{ user.email | lower }}</li>
    {% else %}
      <li>No users found.</li>
    {% endfor %}
  </ul>
{% endblock %}
```

### Macros

```html
<!-- templates/macros/forms.html -->
{% macro input(name, label, type="text", value="", required=False) %}
  <div class="form-group">
    <label for="{{ name }}">{{ label }}</label>
    <input
      type="{{ type }}"
      id="{{ name }}"
      name="{{ name }}"
      value="{{ value | e }}"
      {% if required %}required{% endif %}
    >
  </div>
{% endmacro %}
```

```html
{% from "macros/forms.html" import input %}
{{ input("email", "Email Address", type="email", required=True) }}
```

### Custom Filters and Context Processors

```python
# myapp/template_filters.py
from datetime import datetime


def register_template_filters(app):
    @app.template_filter("datetimeformat")
    def datetimeformat(value: datetime, fmt: str = "%Y-%m-%d") -> str:
        return value.strftime(fmt) if value else ""

    @app.template_filter("pluralize")
    def pluralize(count: int, singular: str, plural: str | None = None) -> str:
        plural = plural or singular + "s"
        return singular if count == 1 else plural

    @app.context_processor
    def inject_globals():
        return {
            "app_name": app.config["APP_NAME"],
            "current_year": datetime.utcnow().year,
        }
```

### Autoescaping and Markup

```python
from markupsafe import Markup, escape

# In a view: pass pre-rendered HTML safely
safe_html = Markup("<strong>Bold</strong>")
user_input = escape("<script>alert('xss')</script>")  # &lt;script&gt;...
```

---

## 6. Application and Request Context

Flask uses two context stacks pushed around each request and CLI command.

### Context Objects

| Object | Context | Purpose |
|---|---|---|
| `current_app` | App context | Proxy to the active Flask application |
| `g` | App context (per-request) | Request-scoped scratch space |
| `request` | Request context | Incoming HTTP request data |
| `session` | Request context | Signed cookie-based session |

```python
from flask import g, current_app, session, request


@app.before_request
def load_logged_in_user():
    user_id = session.get("user_id")
    g.user = User.query.get(user_id) if user_id else None


@app.route("/profile")
def profile():
    if g.user is None:
        abort(401)
    current_app.logger.info("Profile accessed by %s", g.user.email)
    return render_template("profile.html", user=g.user)
```

### Manual Context Management

```python
# Useful in scripts, Celery tasks, or tests
with app.app_context():
    db.create_all()
    User.query.all()

# Push contexts manually in CLI commands or background tasks
ctx = app.app_context()
ctx.push()
try:
    do_work()
finally:
    ctx.pop()
```

### Session

```python
from flask import session

# Session is a signed, client-side cookie (Werkzeug's SecureCookieSession)
# SECRET_KEY must be set; tamper detection is cryptographic
session["user_id"] = user.id
session.permanent = True  # Respect PERMANENT_SESSION_LIFETIME

# Clear
session.clear()
session.pop("user_id", None)
```

For server-side sessions, use `Flask-Session` (Redis, filesystem, SQLAlchemy backends).

---

## 7. Configuration

### Config Class Hierarchy

```python
# myapp/config.py
import os
from datetime import timedelta


class BaseConfig:
    SECRET_KEY: str = os.environ["SECRET_KEY"]
    SQLALCHEMY_TRACK_MODIFICATIONS: bool = False
    PERMANENT_SESSION_LIFETIME: timedelta = timedelta(days=7)
    MAX_CONTENT_LENGTH: int = 16 * 1024 * 1024  # 16 MB upload limit
    APP_NAME: str = "MyApp"


class DevelopmentConfig(BaseConfig):
    DEBUG: bool = True
    SQLALCHEMY_DATABASE_URI: str = "sqlite:///dev.db"
    SQLALCHEMY_ECHO: bool = True


class TestingConfig(BaseConfig):
    TESTING: bool = True
    SQLALCHEMY_DATABASE_URI: str = "sqlite:///:memory:"
    WTF_CSRF_ENABLED: bool = False
    SECRET_KEY: str = "test-secret"


class ProductionConfig(BaseConfig):
    SQLALCHEMY_DATABASE_URI: str = os.environ["DATABASE_URL"]
    SESSION_COOKIE_SECURE: bool = True
    SESSION_COOKIE_HTTPONLY: bool = True
    SESSION_COOKIE_SAMESITE: str = "Lax"


config_by_name = {
    "development": DevelopmentConfig,
    "testing": TestingConfig,
    "production": ProductionConfig,
}
```

### Loading Methods

```python
# from_object: load from a class or module
app.config.from_object("myapp.config.ProductionConfig")
app.config.from_object(ProductionConfig)

# from_envvar: path to a .cfg file in environment variable
app.config.from_envvar("APP_CONFIG_FILE", silent=True)

# from_mapping: direct dict
app.config.from_mapping({"DEBUG": True, "TESTING": True})

# from_pyfile: load a Python file (instance folder by default)
app.config.from_pyfile("config.py", silent=True)

# from_prefixed_env (Flask 2.1+): load env vars with a prefix
app.config.from_prefixed_env("FLASK")  # FLASK_SECRET_KEY -> SECRET_KEY
```

### Instance Folder

The instance folder (`instance/`) sits outside the package, is git-ignored, and holds secrets and machine-specific config.

```
myproject/
    myapp/
        __init__.py
    instance/
        config.py       # SECRET_KEY, DATABASE_URL — not in VCS
    wsgi.py
```

```python
# In create_app:
app = Flask(__name__, instance_relative_config=True)
app.config.from_pyfile("config.py", silent=True)
```

---

## 8. Extensions Ecosystem

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

### Flask-Smorest / APIFlask

For OpenAPI-first REST APIs, Flask-Smorest is the modern choice over Flask-RESTful:

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

## 9. Error Handling

### Application-Level Error Handlers

```python
from flask import jsonify, render_template
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
    """Catch all HTTP exceptions and return JSON for API requests."""
    return jsonify(code=e.code, name=e.name, description=e.description), e.code


# Custom exception with handler
class ResourceNotFound(Exception):
    def __init__(self, resource: str, id: int):
        self.resource = resource
        self.id = id
        super().__init__(f"{resource} {id} not found")


@app.errorhandler(ResourceNotFound)
def handle_not_found(e: ResourceNotFound):
    return jsonify(error=str(e), resource=e.resource, id=e.id), 404
```

### abort()

```python
from flask import abort
from werkzeug.exceptions import NotFound

# Raise an HTTP exception immediately
abort(403)
abort(400, description="Email is required")

# abort() raises a werkzeug HTTPException subclass
# It can be caught by @app.errorhandler
```

---

## 10. Signals (Blinker)

Flask emits signals for major lifecycle events via Blinker. Signals are synchronous and primarily useful for decoupled side-effects (audit logging, metrics, cache invalidation).

```python
from flask import request_started, request_finished, got_request_exception
from flask.signals import appcontext_pushed

# Connect to a signal
def log_request(sender, **extra):
    sender.logger.info("Request: %s %s", request.method, request.path)

request_started.connect(log_request, app)

# Context manager approach (temporary connection)
with request_finished.connected_to(my_handler, sender=app):
    client.get("/")

# Custom signals
from blinker import Namespace
_signals = Namespace()
user_registered = _signals.signal("user-registered")

# Emit
user_registered.send(app, user=new_user)

# Receive
@user_registered.connect_via(app)
def on_user_registered(sender, user, **kwargs):
    send_welcome_email(user)
```

**Built-in signals:** `request_started`, `request_finished`, `request_tearing_down`, `got_request_exception`, `appcontext_pushed`, `appcontext_popped`, `appcontext_tearing_down`, `message_flashed`, `template_rendered`.

---

## 11. CLI Commands

Flask integrates with Click for CLI commands, accessible via `flask <command>`.

```python
# myapp/cli.py
import click
from flask import current_app
from flask.cli import with_appcontext, AppGroup
from .extensions import db
from .models import User

db_cli = AppGroup("db-tools", help="Database management commands.")


@db_cli.command("seed")
@click.option("--count", default=10, help="Number of users to seed.")
@with_appcontext
def seed_cmd(count: int):
    """Seed the database with sample data."""
    for i in range(count):
        user = User(email=f"user{i}@example.com", password_hash="hash")
        db.session.add(user)
    db.session.commit()
    click.echo(f"Seeded {count} users.")


@db_cli.command("drop")
@click.confirmation_option(prompt="Drop all tables?")
@with_appcontext
def drop_cmd():
    db.drop_all()
    click.echo("All tables dropped.")


# In create_app:
app.cli.add_command(db_cli)
```

```bash
flask db-tools seed --count 50
flask db-tools drop
flask --help
```

---

## 12. Testing

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
    """Provide a clean DB transaction per test — rollback after each test."""
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
# tests/test_users.py
import pytest


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

## 13. Deployment

### Gunicorn (Linux/Mac)

```bash
# Install
pip install gunicorn

# Run with sync workers
gunicorn "myapp:create_app('production')" \
    --workers 4 \
    --bind 0.0.0.0:8000 \
    --timeout 30 \
    --access-logfile - \
    --error-logfile -

# Async workers (install eventlet or gevent first)
gunicorn "myapp:create_app()" \
    --worker-class gevent \
    --workers 2 \
    --worker-connections 1000
```

### Waitress (Windows / Cross-platform)

```python
# serve.py
from waitress import serve
from myapp import create_app

app = create_app("production")

if __name__ == "__main__":
    serve(app, host="0.0.0.0", port=8000, threads=8)
```

### Nginx Reverse Proxy

```nginx
server {
    listen 80;
    server_name example.com;
    return 301 https://$host$request_uri;
}

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
# Dockerfile
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

## 14. Security

### CSRF with Flask-WTF

Flask-WTF enables CSRF protection by default for all form submissions. For API endpoints using JWT instead of cookies, disable per-view or use `csrf.exempt(blueprint)`.

```python
from flask_wtf.csrf import CSRFProtect, csrf_exempt

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
# Production must-haves
app.config.update(
    SECRET_KEY=os.environ["SECRET_KEY"],          # Long, random, kept secret
    SESSION_COOKIE_SECURE=True,                   # HTTPS only
    SESSION_COOKIE_HTTPONLY=True,                 # Not accessible via JS
    SESSION_COOKIE_SAMESITE="Lax",               # CSRF mitigation
    REMEMBER_COOKIE_SECURE=True,
    REMEMBER_COOKIE_HTTPONLY=True,
    WTF_CSRF_TIME_LIMIT=3600,                     # CSRF token expiry (seconds)
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

### Security Headers

```python
# Use flask-talisman for automatic security headers
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

## 15. Async Support

Flask 2.0+ supports `async def` view functions natively via `asgiref`. Flask remains a WSGI framework — async views run in a thread pool, not on an event loop.

```python
# Install: pip install flask[async]
import asyncio
import httpx


@app.route("/async-view")
async def async_view():
    async with httpx.AsyncClient() as client:
        resp = await client.get("https://api.example.com/data")
    return jsonify(resp.json())


# Async before_request, error handlers, and signal receivers are supported
@app.before_request
async def load_data():
    g.data = await fetch_some_data()
```

### Limitations

- Flask is still synchronous at the server level. One request per thread.
- True concurrency requires an ASGI server (Uvicorn/Hypercorn) with a compatible framework like FastAPI or Quart.
- `asyncio.run()` inside a sync Flask view blocks the thread — avoid it.
- For CPU-bound work, use `concurrent.futures.ProcessPoolExecutor`.
- For truly concurrent I/O, migrate to FastAPI or use Celery for background tasks.

```python
# Celery for true async background tasks (the standard Flask pattern)
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


@celery.task
def send_email_task(user_id: int) -> None:
    user = db.session.get(User, user_id)
    send_welcome_email(user)

# In view:
send_email_task.delay(user.id)
```

---

## 16. SQLAlchemy Integration Patterns

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
        db.session.flush()  # Get ID without committing
        return user
```

### Model Patterns (SQLAlchemy 2.x Mapped)

```python
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, ForeignKey, Text
from datetime import datetime


class Post(db.Model):
    __tablename__ = "posts"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    body: Mapped[str] = mapped_column(Text)
    published: Mapped[bool] = mapped_column(default=False)
    author_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    created_at: Mapped[datetime] = mapped_column(default=datetime.utcnow)

    author: Mapped["User"] = relationship(back_populates="posts")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "title": self.title,
            "body": self.body,
            "published": self.published,
            "author_id": self.author_id,
        }
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

---

## 17. Project Structure

### Functional Layout (small/medium apps)

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

### Divisional Layout (large apps, recommended)

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

## 18. Flask vs FastAPI

### Side-by-Side Comparison

| Dimension | Flask 3.1 | FastAPI |
|---|---|---|
| **Paradigm** | WSGI, sync-first | ASGI, async-first |
| **Routing** | Decorator-based | Decorator-based (similar syntax) |
| **Validation** | Manual / WTForms / Marshmallow | Pydantic v2 built-in |
| **OpenAPI** | Via Flask-Smorest / APIFlask | Automatic (Swagger UI + ReDoc) |
| **Performance** | Good (Gunicorn + gevent) | Excellent (Uvicorn + async I/O) |
| **Learning curve** | Gentle; huge ecosystem | Moderate; requires Pydantic knowledge |
| **Type hints** | Optional, no runtime enforcement | Core — type hints drive validation |
| **WebSockets** | Via Flask-SocketIO (gevent) | Native (Starlette) |
| **Maturity** | Very mature (2010) | Mature (2018), fast-growing |
| **Extensions** | Massive ecosystem | Smaller, often use Starlette/anyio |
| **Testing** | test_client, pytest | TestClient (httpx-based) |

### When to Use Flask

- You need a traditional web application with server-rendered Jinja2 templates.
- Your team knows Flask and the project scope doesn't justify migration.
- You rely on specific Flask extensions (Flask-Admin, Flask-Login, Flask-WTF).
- The app is sync-dominant (CRUD, background tasks via Celery, no high-concurrency I/O).
- You're building internal tooling or prototypes where velocity > performance.
- You need fine-grained control over request/response without framework magic.

### When to Use FastAPI (or Consider Migrating)

- You're building a pure JSON REST or GraphQL API — not rendering HTML.
- You need automatic OpenAPI documentation with response validation.
- High-concurrency I/O (thousands of simultaneous WebSocket connections, streaming).
- You want Python type hints to enforce request/response contracts at runtime.
- Your team is comfortable with `async/await` and ASGI throughout the stack.
- You need built-in dependency injection (FastAPI's `Depends`).

### Migration Path: Flask → FastAPI

For greenfield API services, prefer FastAPI. For hybrid apps (API + templates), Flask remains pragmatic. A common pattern: keep Flask for the web frontend, build new microservices in FastAPI.

```python
# Flask (classic)
@app.route("/users/<int:user_id>", methods=["GET"])
def get_user(user_id):
    user = User.query.get_or_404(user_id)
    return jsonify(user.to_dict())

# FastAPI equivalent
from fastapi import FastAPI, Depends, HTTPException
from pydantic import BaseModel

app = FastAPI()

class UserResponse(BaseModel):
    id: int
    email: str

@app.get("/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: int, db: AsyncSession = Depends(get_db)):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
```

---

## Quick Reference

### Flask 3.1 Key Changes from 2.x

- `flask.cli` `with_appcontext` is implicit for commands registered via `@app.cli.command` — explicit `@with_appcontext` still supported.
- SQLAlchemy 2.x `Mapped` / `mapped_column` syntax is the default with Flask-SQLAlchemy 3.x.
- `app.config.from_prefixed_env()` is stable.
- Autoescaping extended to `.svg` and `.xhtml` by default.
- `app.json` attribute replaces direct `app.config["JSON_*"]` settings for JSON provider customization.

### Essential pip installs

```text
Flask==3.1.*
Flask-SQLAlchemy==3.*
Flask-Migrate
Flask-Login
Flask-WTF
Flask-CORS
Flask-JWT-Extended
Flask-Caching
Flask-Mail
flask-smorest
marshmallow
gunicorn        # or waitress on Windows
python-dotenv
blinker         # Signals (Flask dependency, usually auto-installed)
```
