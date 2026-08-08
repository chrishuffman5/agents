#!/usr/bin/env python3
"""Read-only preflight for the OpenAI Agents SDK (Python).

Reports the interpreter version, installed package versions against the
dependency floors documented in pyproject.toml on main (2026-08-05), and which
SDK-relevant environment variables are set. Values of secrets are NEVER printed
-- only whether the variable is present.

Makes no network calls, imports nothing from the SDK, and writes no files.

Usage:  python agents-sdk-preflight.py
"""

import os
import sys

try:
    from importlib.metadata import PackageNotFoundError, version
except ImportError:  # pragma: no cover - Python < 3.8
    print("importlib.metadata unavailable; Python 3.10+ is required by openai-agents")
    sys.exit(0)

# (distribution name, documented floor, note)
DEPENDENCIES = [
    ("openai-agents", "0.19.4 pinned on main 2026-08-05", "the SDK itself"),
    ("openai", ">=2.45.0,<3", "Responses API client"),
    ("pydantic", ">=2.12.2,<3", "tool schemas and output_type"),
    ("griffelib", ">=2,<3", "docstring parsing for tool descriptions"),
    ("typing-extensions", ">=4.12.2,<5", ""),
    ("requests", ">=2.0,<3", ""),
    ("websockets", ">=15.0,<17", "realtime WebSocket transport"),
    ("mcp", ">=1.19.0,<3", "MCP client transports"),
]

OPTIONAL_EXTRAS = [
    ("redis", "openai-agents[redis] -> RedisSession"),
    ("litellm", "openai-agents[litellm] -> LitellmModel"),
    ("any-llm-sdk", "openai-agents[any-llm] -> AnyLLMModel (distribution name may vary)"),
    ("aiosqlite", "AsyncSQLiteSession driver"),
    ("sqlalchemy", "SQLAlchemySession backend"),
    ("pymongo", "MongoDBSession backend"),
]

ENV_VARS = [
    ("OPENAI_API_KEY", "required for text and sandbox agents"),
    ("OPENAI_DEFAULT_MODEL", "overrides the default model globally"),
    ("OPENAI_BASE_URL", "custom endpoint"),
    ("OPENAI_WEBSOCKET_BASE_URL", "custom realtime endpoint"),
    ("OPENAI_ORG_ID", ""),
    ("OPENAI_PROJECT_ID", ""),
    ("OPENAI_AGENTS_DISABLE_TRACING", "1 disables tracing entirely"),
    ("OPENAI_AGENTS_TRACE_INCLUDE_SENSITIVE_DATA", "0 strips span I/O"),
    ("OPENAI_AGENTS_DONT_LOG_MODEL_DATA", "1 redacts model data from logs"),
    ("OPENAI_AGENTS_DONT_LOG_TOOL_DATA", "1 redacts tool data from logs"),
]


def installed(dist):
    try:
        return version(dist)
    except PackageNotFoundError:
        return None


def main():
    print("== Interpreter ==")
    v = sys.version_info
    ok = (v.major, v.minor) >= (3, 10)
    print(f"  python {v.major}.{v.minor}.{v.micro}  (requires-python >=3.10: {'ok' if ok else 'TOO OLD'})")
    print(f"  executable: {sys.executable}")

    print("\n== Core packages (documented floors, 2026-08-05) ==")
    for dist, floor, note in DEPENDENCIES:
        got = installed(dist)
        suffix = f"  # {note}" if note else ""
        if got is None:
            print(f"  {dist:<20} NOT INSTALLED       expected {floor}{suffix}")
        else:
            print(f"  {dist:<20} {got:<18}  expected {floor}{suffix}")

    print("\n== Optional extras / session backends ==")
    for dist, note in OPTIONAL_EXTRAS:
        got = installed(dist)
        print(f"  {dist:<20} {(got or '-'):<18}  {note}")

    print("\n== Environment (presence only, values never printed) ==")
    for name, note in ENV_VARS:
        state = "set" if os.environ.get(name) else "unset"
        suffix = f"  # {note}" if note else ""
        print(f"  {name:<45} {state}{suffix}")

    print("\nReminder: tracing is ON by default and exports spans, including tool I/O,")
    print("to OpenAI. For non-OpenAI providers this also causes 401s on trace export.")


if __name__ == "__main__":
    main()

# Sources
# - https://raw.githubusercontent.com/openai/openai-agents-python/main/pyproject.toml
# - https://openai.github.io/openai-agents-python/quickstart/
# - https://openai.github.io/openai-agents-python/sessions/
# - https://openai.github.io/openai-agents-python/models/
# - https://openai.github.io/openai-agents-python/tracing/
# - https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/config.md
# Fetched: 2026-08-05
