# Python Scripting Patterns Reference

> File ops, subprocess, HTTP/API, logging, argparse, regex. Dense with examples.

---

## 1. File Operations

### pathlib (Preferred Path API)

```python
from pathlib import Path

p = Path("/etc/hosts")
p = Path.home() / ".config" / "myapp" / "settings.json"
p.exists(); p.is_file(); p.is_dir()
p.stat().st_size; p.stat().st_mtime
p.stem; p.suffix; p.name; p.parent; p.parts; p.resolve()

text = p.read_text(encoding="utf-8")
p.write_text("hello\n", encoding="utf-8")
p.mkdir(parents=True, exist_ok=True)

for csv_file in Path("./data").glob("*.csv"): print(csv_file)
for py_file in Path(".").rglob("**/*.py"): print(py_file)
for item in Path(".").iterdir():
    if item.is_file(): print(item.name, item.stat().st_size)

p.rename(p.parent / (p.stem + "_backup" + p.suffix))
p.unlink(missing_ok=True)
```

### shutil (High-Level File Ops)

```python
import shutil
shutil.copy2(src / "data.csv", dst / "data.csv")
shutil.copytree(src, dst, dirs_exist_ok=True)
shutil.move(str(old), str(new))
shutil.rmtree(dst, ignore_errors=True)

usage = shutil.disk_usage("/")
print(f"Free: {usage.free / 1e9:.1f} GB")

shutil.make_archive("backup", "zip", root_dir="./data")
shutil.unpack_archive("backup.zip", extract_dir="./restored")
```

### tempfile

```python
import tempfile
with tempfile.NamedTemporaryFile(suffix=".csv", mode="w", delete=True) as f:
    f.write("id,name\n1,Alice\n")
with tempfile.TemporaryDirectory(prefix="scratch_") as tmpdir:
    work = Path(tmpdir)
    (work / "step1.json").write_text('{"ok": true}')
```

### CSV

```python
import csv
with Path("data.csv").open(newline="", encoding="utf-8") as f:
    for record in csv.DictReader(f):
        print(record["name"], record["department"])

fields = ["id", "name", "department"]
records = [{"id": 1, "name": "Alice", "department": "Eng"}]
with Path("out.csv").open("w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=fields)
    writer.writeheader()
    writer.writerows(records)
```

### JSON

```python
import json
config = json.loads(Path("config.json").read_text(encoding="utf-8"))
Path("out.json").write_text(json.dumps(data, indent=2, sort_keys=True), encoding="utf-8")

# Custom serializer
def json_default(obj):
    if isinstance(obj, (datetime, date)): return obj.isoformat()
    if isinstance(obj, Path): return str(obj)
    raise TypeError(f"Not serializable: {type(obj)}")
```

### YAML / TOML

```python
# YAML: pip install pyyaml
import yaml
config = yaml.safe_load(Path("config.yaml").read_text(encoding="utf-8"))
yaml.dump(data, default_flow_style=False)

# TOML: stdlib 3.11+ (read-only)
import tomllib
with open("pyproject.toml", "rb") as f:
    config = tomllib.load(f)
```

---

## 2. Subprocess

```python
import subprocess, shlex

result = subprocess.run(
    ["git", "status", "--short"],
    capture_output=True, text=True, check=True, cwd="/path/to/repo", timeout=30,
)
print(result.stdout)

# Custom environment
import os
env = os.environ.copy()
env["GIT_AUTHOR_NAME"] = "CI Bot"
subprocess.run(["git", "commit", "--allow-empty", "-m", "ci"], env=env, check=True)

# shell=True — avoid; required for shell builtins
result = subprocess.run("df -h | grep /dev/sd", shell=True, capture_output=True, text=True)

# Safe command building
cmd = shlex.split('find /var/log -name "*.log" -mtime +7')
subprocess.run(cmd, check=True)

# Error handling
try:
    result = subprocess.run(["systemctl", "status", "svc"], capture_output=True, text=True, check=True)
except subprocess.CalledProcessError as e:
    print(f"Exit {e.returncode}: {e.stderr}")
except subprocess.TimeoutExpired:
    print("Timed out")
except FileNotFoundError:
    print("Command not found")

# Streaming with Popen
with subprocess.Popen(["tail", "-f", "/var/log/syslog"], stdout=subprocess.PIPE, text=True, bufsize=1) as proc:
    for line in proc.stdout:
        if "ERROR" in line:
            print("Alert:", line.strip())
            proc.terminate()
            break
```

---

## 3. HTTP / API

```python
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# Session with retry
session = requests.Session()
session.headers.update({"Authorization": f"Bearer {TOKEN}", "Accept": "application/json"})
retry = Retry(total=3, backoff_factor=1, status_forcelist=[429, 500, 502, 503, 504])
session.mount("https://", HTTPAdapter(max_retries=retry))
session.mount("http://",  HTTPAdapter(max_retries=retry))

# GET with params
resp = session.get("https://api.example.com/users", params={"page": 1, "active": "true"}, timeout=10)
resp.raise_for_status()
data = resp.json()

# POST with JSON
resp = session.post(url, json={"username": "alice"}, timeout=10)

# Pagination pattern
def get_all_pages(session, url):
    results, params = [], {"page": 1, "per_page": 100}
    while True:
        resp = session.get(url, params=params, timeout=15)
        resp.raise_for_status()
        page = resp.json()
        if not page: break
        results.extend(page)
        params["page"] += 1
    return results

# API client class pattern
class APIClient:
    def __init__(self, base_url, token=None):
        self.base_url = base_url.rstrip("/")
        self._session = requests.Session()
        if token: self._session.headers["Authorization"] = f"Bearer {token}"
        retry = Retry(total=3, backoff_factor=0.5, status_forcelist=[429, 500, 503])
        self._session.mount("https://", HTTPAdapter(max_retries=retry))

    def get(self, path, **params):
        resp = self._session.get(f"{self.base_url}{path}", params=params, timeout=15)
        resp.raise_for_status()
        return resp.json()

    def post(self, path, body):
        resp = self._session.post(f"{self.base_url}{path}", json=body, timeout=15)
        resp.raise_for_status()
        return resp.json()

    def close(self): self._session.close()
    def __enter__(self): return self
    def __exit__(self, *_): self.close()
```

---

## 4. Logging

```python
import logging, logging.handlers, json

# Minimal setup for scripts
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)-8s %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
log = logging.getLogger(__name__)
log.info("Started"); log.warning("Disk 80%%"); log.error("DB down")

# File + console handler
def setup_logging(log_file="app.log", level=logging.INFO):
    logger = logging.getLogger("myapp")
    logger.setLevel(level)
    fmt = logging.Formatter("%(asctime)s %(levelname)-8s [%(name)s] %(message)s")

    ch = logging.StreamHandler(); ch.setLevel(logging.WARNING); ch.setFormatter(fmt)
    fh = logging.handlers.RotatingFileHandler(log_file, maxBytes=10*1024*1024, backupCount=5)
    fh.setLevel(logging.DEBUG); fh.setFormatter(fmt)
    logger.addHandler(ch); logger.addHandler(fh)
    return logger

# JSON formatter
class JsonFormatter(logging.Formatter):
    def format(self, record):
        obj = {"ts": datetime.now(timezone.utc).isoformat(), "level": record.levelname,
               "msg": record.getMessage(), "file": f"{record.filename}:{record.lineno}"}
        if record.exc_info: obj["exc"] = self.formatException(record.exc_info)
        return json.dumps(obj)
```

---

## 5. Argument Parsing

```python
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(
    description="Process files",
    formatter_class=argparse.RawDescriptionHelpFormatter,
    epilog="Examples:\n  %(prog)s --input ./data --format json",
)
parser.add_argument("input_file", type=Path, help="Input file")
parser.add_argument("-o", "--output", type=Path, default=Path("./output"))
parser.add_argument("-f", "--format", choices=["json", "csv", "yaml"], default="json")
parser.add_argument("-n", "--count", type=int, default=10, help="(default: %(default)s)")
parser.add_argument("-v", "--verbose", action="store_true")
parser.add_argument("--dry-run", action="store_true")
parser.add_argument("--tags", nargs="+", metavar="TAG")

# Subcommands
parser2 = argparse.ArgumentParser(prog="mytool")
sub = parser2.add_subparsers(dest="command", required=True)
sync_p = sub.add_parser("sync", help="Sync data")
sync_p.add_argument("--url", required=True)
purge_p = sub.add_parser("purge", help="Purge cache")
purge_p.add_argument("--older-than", type=int, default=30)

# Mutually exclusive
group = parser.add_mutually_exclusive_group()
group.add_argument("--enable", action="store_true")
group.add_argument("--disable", action="store_true")
```

---

## 6. Regular Expressions

```python
import re

IP_PATTERN    = r"\b(?:\d{1,3}\.){3}\d{1,3}\b"
EMAIL_PATTERN = r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}"
LOG_PATTERN   = r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+(\w+)\s+(.+)"

m = re.search(IP_PATTERN, line)
if m: print(m.group(), m.start(), m.end())

ips = re.findall(IP_PATTERN, "Hosts: 10.0.0.1 10.0.0.2")
for m in re.finditer(EMAIL_PATTERN, text): print(m.group())

# Named groups
m = re.match(r"(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})", "2024-03-15")
if m: print(m.groupdict())

# Substitution
sanitized = re.sub(r"[^a-zA-Z0-9_\-]", "_", "my file (2024).csv")
# With function
masked = re.sub(IP_PATTERN, lambda m: "***." + m.group().split(".")[-1], text)

# Compiled pattern (reuse)
log_re = re.compile(LOG_PATTERN)
def parse_log(line):
    m = log_re.match(line)
    return {"timestamp": m.group(1), "level": m.group(2), "message": m.group(3)} if m else None

# Flags
re.findall(r"error", text, re.IGNORECASE)
re.split(r"\s*,\s*", "alice , bob, carol")
```

---

## 7. Error Handling

```python
import contextlib, traceback

# try / except / else / finally
def read_config(path):
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        raise FileNotFoundError(f"Config not found: {path}") from None
    except PermissionError as e:
        raise PermissionError(f"Cannot read {path}: {e}") from e
    else:
        return json.loads(text)
    finally:
        pass  # cleanup

# Custom exceptions
class ConfigError(ValueError): pass
class NetworkError(RuntimeError):
    def __init__(self, url, status):
        super().__init__(f"HTTP {status} for {url}")
        self.url, self.status = url, status

# contextlib.suppress
with contextlib.suppress(FileNotFoundError):
    Path("maybe_missing.lock").unlink()

# Top-level script pattern
def main():
    try:
        run()
    except KeyboardInterrupt:
        print("\nInterrupted"); sys.exit(130)
    except SystemExit:
        raise
    except Exception:
        log.critical("Unhandled exception", exc_info=True); sys.exit(1)
```

---

## 8. Environment and OS

```python
import os, getpass

home = os.environ["HOME"]
editor = os.getenv("EDITOR", "vim")
env = os.environ.copy()
env["MY_DEBUG"] = "1"

cwd = os.getcwd()
os.chmod("/tmp/script.sh", 0o755)
print(os.getpid(), getpass.getuser())
```
