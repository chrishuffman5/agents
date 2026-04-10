# Flask Architecture Reference

## Application Factory Pattern

The application factory is the cornerstone of production Flask applications. Instead of creating a global `app` instance at module level, a `create_app` function constructs and configures the application.

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

    # Initialize extensions (order matters -- db before migrate)
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
# wsgi.py -- entry point for Gunicorn/Waitress
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

## Context Stacks

Flask uses two context stacks pushed around each request and CLI command. Understanding contexts is critical for avoiding `RuntimeError: Working outside of application context`.

### Context Objects

| Object | Context | Purpose |
|---|---|---|
| `current_app` | App context | Proxy to the active Flask application |
| `g` | App context (per-request) | Request-scoped scratch space |
| `request` | Request context | Incoming HTTP request data |
| `session` | Request context | Signed cookie-based session |

### How Contexts Work

When a request arrives, Flask pushes both an application context and a request context. They are popped when the request ends.

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

Useful in scripts, Celery tasks, or tests where there is no HTTP request:

```python
# Push app context manually
with app.app_context():
    db.create_all()
    User.query.all()

# Push contexts in CLI commands or background tasks
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

## Werkzeug Foundation

Flask is built on Werkzeug, which provides:

- **Routing:** URL map, converters, rule matching
- **Request/Response:** `Request` and `Response` wrapper classes around WSGI environ
- **Exceptions:** HTTP exception classes (`NotFound`, `Forbidden`, `BadRequest`, etc.)
- **Security:** Password hashing (`generate_password_hash`, `check_password_hash`), `SecureCookieSession`
- **Development server:** Auto-reloader, debugger (never use in production)
- **Proxy support:** `ProxyFix` middleware for apps behind reverse proxies

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

Built-in converters: `string` (default), `int`, `float`, `path`, `uuid`.

---

## Routing Internals

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

### url_for

```python
from flask import url_for

# Always use url_for -- never hardcode URLs
url_for("auth.login")                         # /auth/login
url_for("auth.login", _external=True)         # https://example.com/auth/login
url_for("get_user", user_id=42)               # /users/42
url_for("static", filename="css/main.css")    # /static/css/main.css
```

### Class-Based Views (MethodView)

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

## Blueprints

Blueprints record operations to be executed on the application once registered. They carry their own routes, templates, static files, error handlers, and before/after request hooks.

### Basic Registration

```python
# myapp/auth/__init__.py
from flask import Blueprint

auth_bp = Blueprint(
    "auth",
    __name__,
    template_folder="templates",
    static_folder="static",
    url_prefix="/auth",
)

from . import routes  # noqa: E402, F401


# myapp/auth/routes.py
from flask import render_template, redirect, url_for, flash
from flask_login import login_user, logout_user
from . import auth_bp

@auth_bp.route("/login", methods=["GET", "POST"])
def login():
    return render_template("auth/login.html")

@auth_bp.route("/logout")
def logout():
    logout_user()
    return redirect(url_for("auth.login"))  # blueprint_name.view_name
```

### Nesting Blueprints (Flask 2.0+)

```python
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

## Request and Response

### The Request Object

```python
from flask import request

# Routing metadata
request.method          # "GET", "POST", etc.
request.url             # Full URL
request.path            # Path component
request.endpoint        # Matched endpoint name

# Incoming data
request.args            # ImmutableMultiDict -- query string params
request.form            # ImmutableMultiDict -- form data
request.files           # ImmutableMultiDict -- uploaded files (FileStorage)
request.json            # Parsed JSON body (or None)
request.get_json(force=True, silent=True)
request.data            # Raw body bytes
request.headers         # EnvironHeaders -- case-insensitive dict
request.cookies         # Dict of cookies
request.remote_addr     # Client IP

# File upload
file = request.files["avatar"]
if file and allowed_file(file.filename):
    filename = secure_filename(file.filename)
    file.save(os.path.join(app.config["UPLOAD_FOLDER"], filename))
```

### Response Helpers

```python
from flask import jsonify, make_response, redirect, url_for, send_file, abort

return jsonify({"status": "ok", "data": result}), 200

resp = make_response(jsonify({"error": "not found"}), 404)
resp.headers["X-Custom"] = "value"
resp.set_cookie("session_id", "abc123", httponly=True, samesite="Lax")
return resp

return redirect(url_for("auth.login"), 302)
return send_file("path/to/file.pdf", as_attachment=True, download_name="report.pdf")
abort(404)
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

## Jinja2 Template Engine

Flask uses Jinja2 with autoescaping enabled for `.html`, `.xml`, `.svg`, and `.xhtml` by default.

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
{% block title %}Users -- {{ super() }}{% endblock %}
{% block content %}
  <ul>
    {% for user in users %}
      <li>{{ user.name | title }} -- {{ user.email | lower }}</li>
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
    <input type="{{ type }}" id="{{ name }}" name="{{ name }}" value="{{ value | e }}"
           {% if required %}required{% endif %}>
  </div>
{% endmacro %}
```

```html
{% from "macros/forms.html" import input %}
{{ input("email", "Email Address", type="email", required=True) }}
```

### Custom Filters and Context Processors

```python
def register_template_filters(app):
    @app.template_filter("datetimeformat")
    def datetimeformat(value, fmt="%Y-%m-%d"):
        return value.strftime(fmt) if value else ""

    @app.template_filter("pluralize")
    def pluralize(count, singular, plural=None):
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

safe_html = Markup("<strong>Bold</strong>")
user_input = escape("<script>alert('xss')</script>")  # &lt;script&gt;...
```

---

## Signal System (Blinker)

Flask emits signals for major lifecycle events via Blinker. Signals are synchronous and primarily useful for decoupled side-effects (audit logging, metrics, cache invalidation).

```python
from flask import request_started, request_finished, got_request_exception

# Connect to a signal
def log_request(sender, **extra):
    sender.logger.info("Request: %s %s", request.method, request.path)

request_started.connect(log_request, app)

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

## Extension Loading

Flask extensions follow a consistent `init_app()` pattern for deferred initialization:

```python
# 1. Create extension objects without app (extensions.py)
db = SQLAlchemy()
migrate = Migrate()

# 2. Initialize with app inside factory (create_app)
db.init_app(app)
migrate.init_app(app, db)
```

**Extension initialization order matters:**
- `db` (SQLAlchemy) before `migrate` (Flask-Migrate depends on db)
- `login_manager` before blueprints that use `@login_required`
- `csrf` (Flask-WTF CSRFProtect) before blueprint registration

---

## CLI Commands

Flask integrates with Click for CLI commands, accessible via `flask <command>`.

```python
import click
from flask import current_app
from flask.cli import with_appcontext, AppGroup

db_cli = AppGroup("db-tools", help="Database management commands.")

@db_cli.command("seed")
@click.option("--count", default=10, help="Number of users to seed.")
@with_appcontext
def seed_cmd(count: int):
    for i in range(count):
        user = User(email=f"user{i}@example.com", password_hash="hash")
        db.session.add(user)
    db.session.commit()
    click.echo(f"Seeded {count} users.")

# In create_app:
app.cli.add_command(db_cli)
```

```bash
flask db-tools seed --count 50
flask --help
```

---

## WSGI Interface

Flask is a WSGI application. The WSGI contract:

```python
def application(environ: dict, start_response: Callable) -> Iterable[bytes]:
    start_response("200 OK", [("Content-Type", "text/plain")])
    return [b"Hello, World!"]
```

Flask wraps this with Werkzeug's `Request` and `Response` classes. Understanding WSGI matters for:
- Writing WSGI middleware (e.g., `ProxyFix`)
- Integrating with WSGI servers (Gunicorn, Waitress)
- Understanding why Flask is synchronous at the protocol level

```python
# ProxyFix for apps behind a reverse proxy
from werkzeug.middleware.proxy_fix import ProxyFix

app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_prefix=1)
```

---

## Async Support

Flask 2.0+ supports `async def` view functions natively via `asgiref`. Flask remains a WSGI framework -- async views run in a thread pool, not on an event loop.

```python
# Install: pip install flask[async]
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
- True concurrency requires an ASGI server with a compatible framework (FastAPI, Quart).
- `asyncio.run()` inside a sync Flask view blocks the thread -- avoid it.
- For CPU-bound work, use `concurrent.futures.ProcessPoolExecutor`.
- For truly concurrent I/O, migrate to FastAPI or use Celery for background tasks.

### Celery Integration (Standard Flask Background Task Pattern)

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

@celery.task
def send_email_task(user_id: int) -> None:
    user = db.session.get(User, user_id)
    send_welcome_email(user)

# In view:
send_email_task.delay(user.id)
```

---

## Configuration

### Config Class Hierarchy

```python
import os
from datetime import timedelta

class BaseConfig:
    SECRET_KEY: str = os.environ["SECRET_KEY"]
    SQLALCHEMY_TRACK_MODIFICATIONS: bool = False
    PERMANENT_SESSION_LIFETIME: timedelta = timedelta(days=7)
    MAX_CONTENT_LENGTH: int = 16 * 1024 * 1024  # 16 MB

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
app.config.from_object("myapp.config.ProductionConfig")
app.config.from_envvar("APP_CONFIG_FILE", silent=True)
app.config.from_mapping({"DEBUG": True})
app.config.from_pyfile("config.py", silent=True)
app.config.from_prefixed_env("FLASK")  # FLASK_SECRET_KEY -> SECRET_KEY
```

### Instance Folder

The instance folder (`instance/`) sits outside the package, is git-ignored, and holds secrets:

```
myproject/
    myapp/
        __init__.py
    instance/
        config.py       # SECRET_KEY, DATABASE_URL -- not in VCS
    wsgi.py
```

```python
app = Flask(__name__, instance_relative_config=True)
app.config.from_pyfile("config.py", silent=True)
```
