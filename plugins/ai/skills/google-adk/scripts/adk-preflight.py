#!/usr/bin/env python3
"""Read-only Google ADK environment preflight.

Reports what an ADK agent project would actually see at load/deploy time:
Python version, installed google-adk version, `adk` CLI presence, whether the
target agent directory defines a module-level `root_agent`, whether MCP
toolsets are defined synchronously (a documented Cloud Run / GKE requirement),
and which ADK-relevant environment variables are set.

Reads only. Never imports the agent module, never executes agent code, never
prints a secret value -- only whether a variable is set and its length.

Usage:
    python adk-preflight.py [agent_dir]

`agent_dir` defaults to the current directory. Exit code is always 0; this is a
report, not a gate.

Sources for the checks performed:
  https://adk.dev/get-started/installation/
  https://adk.dev/get-started/python/
  https://adk.dev/tools-custom/mcp-tools/
  https://adk.dev/deploy/cloud-run/
  https://adk.dev/evaluate/
Fetched: 2026-08-05
"""

import os
import re
import shutil
import sys
from pathlib import Path

# Env vars that appear in the fetched ADK docs. Secret-bearing names are masked.
SECRET_ENV = ("GOOGLE_API_KEY",)
PLAIN_ENV = (
    "GOOGLE_CLOUD_PROJECT",
    "GOOGLE_CLOUD_PROJECT_NUMBER",
    "GOOGLE_CLOUD_LOCATION",
    "AGENT_PATH",
    "SERVICE_NAME",
)


def line(label, value):
    print(f"  {label:<34} {value}")


def section(title):
    print(f"\n== {title} ==")


def check_python():
    section("Runtime")
    v = sys.version_info
    line("python", f"{v.major}.{v.minor}.{v.micro}  ({sys.executable})")


def check_package():
    section("ADK package")
    try:
        from importlib import metadata
    except ImportError:  # pragma: no cover - Python < 3.8
        line("google-adk", "cannot check (importlib.metadata unavailable)")
        return
    for pkg in ("google-adk", "google-genai", "vertexai"):
        try:
            line(pkg, metadata.version(pkg))
        except metadata.PackageNotFoundError:
            line(pkg, "NOT INSTALLED")
    adk_cli = shutil.which("adk")
    line("adk CLI on PATH", adk_cli or "NOT FOUND (pip install google-adk)")


def read_text(path):
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def check_agent_dir(agent_dir):
    section(f"Agent project: {agent_dir}")
    if not agent_dir.is_dir():
        line("directory", "MISSING")
        return

    init_py = agent_dir / "__init__.py"
    agent_py = agent_dir / "agent.py"
    line("__init__.py", "present" if init_py.is_file() else "MISSING")
    line("agent.py", "present" if agent_py.is_file() else "MISSING")

    # `adk run` / `adk eval` resolve the agent through a module-level root_agent.
    py_files = sorted(agent_dir.glob("*.py"))
    root_agent_files = []
    for f in py_files:
        if re.search(r"^\s*root_agent\s*(?::[^=]+)?=", read_text(f), re.M):
            root_agent_files.append(f.name)
    line(
        "root_agent defined in",
        ", ".join(root_agent_files) if root_agent_files else "NOT FOUND (adk run/eval will fail)",
    )

    # MCP toolsets must be defined synchronously for Cloud Run / GKE.
    mcp_files, async_mcp_files = [], []
    for f in py_files:
        text = read_text(f)
        if re.search(r"\bMcp(?:Toolset)?\b|\bMCPToolset\b", text):
            mcp_files.append(f.name)
            if re.search(r"async\s+def[^\n]*\n(?:.*\n)*?.*Mcp(?:Toolset)?\(", text):
                async_mcp_files.append(f.name)
    if mcp_files:
        line("MCP toolset referenced in", ", ".join(mcp_files))
        line(
            "possible async definition",
            ", ".join(async_mcp_files) + "  <-- review: Cloud Run/GKE need sync"
            if async_mcp_files
            else "none detected",
        )

    dotenv = agent_dir / ".env"
    if dotenv.is_file():
        names = []
        for raw in read_text(dotenv).splitlines():
            raw = raw.strip()
            if raw and not raw.startswith("#") and "=" in raw:
                names.append(raw.split("=", 1)[0].strip())
        line(".env keys (names only)", ", ".join(names) if names else "(empty)")
    else:
        line(".env", "not present")

    evalsets = sorted(str(p.relative_to(agent_dir)) for p in agent_dir.rglob("*.test.json"))
    line("*.test.json evalsets", ", ".join(evalsets) if evalsets else "none found")

    cfg = agent_dir / "test_config.json"
    line("test_config.json", "present" if cfg.is_file() else "absent (adk eval uses defaults: tool_trajectory_avg_score=1.0, response_match_score=0.8)")


def check_env():
    section("Environment variables")
    for name in SECRET_ENV:
        val = os.environ.get(name)
        line(name, f"set (length {len(val)})" if val else "not set")
    for name in PLAIN_ENV:
        line(name, os.environ.get(name) or "not set")
    line("gcloud on PATH", shutil.which("gcloud") or "NOT FOUND")


def main():
    agent_dir = Path(sys.argv[1]).expanduser().resolve() if len(sys.argv) > 1 else Path.cwd()
    print("Google ADK preflight (read-only)")
    check_python()
    check_package()
    check_agent_dir(agent_dir)
    check_env()
    print("\nNothing was modified. Docs: https://adk.dev/")
    return 0


if __name__ == "__main__":
    sys.exit(main())

# ## Sources
#
# - https://adk.dev/get-started/installation/
# - https://adk.dev/get-started/python/
# - https://adk.dev/tools-custom/mcp-tools/
# - https://adk.dev/deploy/cloud-run/
# - https://adk.dev/evaluate/
#
# Fetched: 2026-08-05
