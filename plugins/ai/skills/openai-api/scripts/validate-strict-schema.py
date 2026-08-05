#!/usr/bin/env python3
"""validate-strict-schema.py - offline check of a JSON Schema against OpenAI's
Structured Outputs / strict-tool constraints.

Why: strict-mode schemas fail at request time with terse errors. Every rule checked
here is documented, so catching violations locally is faster than a round trip.

Usage:
    python validate-strict-schema.py schema.json
    python validate-strict-schema.py tool-definition.json

Accepts a bare JSON Schema, a `{"type":"json_schema","schema":{...}}` wrapper, a
`{"text":{"format":{...}}}` request fragment, or a function tool definition with
`parameters`. Read-only: opens one file, makes no network calls, needs no API key.

Exit codes: 0 = no violations, 1 = violations found, 2 = usage/parse error.

Rules enforced (all from the Structured Outputs guide, fetched 2026-08-05):
  - root schema must be an object type, not anyOf
  - additionalProperties: false required on every object
  - every property must appear in `required`
  - unsupported keywords: allOf, not, dependentRequired, if/then/else
  - max 5000 total object properties
  - max 10 nesting levels
  - schema string size <= 120000 characters
  - max 1000 enum values across all properties combined
"""

import json
import sys

MAX_PROPERTIES = 5000
MAX_DEPTH = 10
MAX_SCHEMA_CHARS = 120_000
MAX_ENUM_VALUES = 1000
UNSUPPORTED = ("allOf", "not", "dependentRequired", "if", "then", "else")


def unwrap(doc):
    """Find the actual JSON Schema inside common wrapper shapes."""
    seen = []
    cur = doc
    for _ in range(5):
        if not isinstance(cur, dict):
            break
        if "text" in cur and isinstance(cur.get("text"), dict) and "format" in cur["text"]:
            cur = cur["text"]["format"]
            seen.append("text.format")
            continue
        if "format" in cur and isinstance(cur.get("format"), dict) and "schema" in cur["format"]:
            cur = cur["format"]
            seen.append("format")
            continue
        if "schema" in cur and isinstance(cur.get("schema"), dict):
            cur = cur["schema"]
            seen.append("schema")
            continue
        if "parameters" in cur and isinstance(cur.get("parameters"), dict):
            cur = cur["parameters"]
            seen.append("parameters")
            continue
        break
    return cur, seen


class Walker:
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.property_count = 0
        self.enum_count = 0
        self.max_depth_seen = 0

    def err(self, path, msg):
        self.errors.append((path or "<root>", msg))

    def warn(self, path, msg):
        self.warnings.append((path or "<root>", msg))

    def walk(self, node, path="", depth=1):
        if not isinstance(node, dict):
            return
        self.max_depth_seen = max(self.max_depth_seen, depth)
        if depth > MAX_DEPTH:
            self.err(path, f"nesting depth {depth} exceeds the {MAX_DEPTH}-level limit")

        for kw in UNSUPPORTED:
            if kw in node:
                self.err(path, f"unsupported keyword `{kw}` (rejected, not degraded)")

        if "enum" in node and isinstance(node["enum"], list):
            self.enum_count += len(node["enum"])

        node_type = node.get("type")
        types = node_type if isinstance(node_type, list) else [node_type]

        if "object" in types or "properties" in node:
            props = node.get("properties")
            if isinstance(props, dict):
                self.property_count += len(props)
                if node.get("additionalProperties") is not False:
                    self.err(path, "object is missing `additionalProperties: false`")
                required = node.get("required")
                if not isinstance(required, list):
                    self.err(path, "object is missing a `required` array")
                    required = []
                missing = [k for k in props if k not in required]
                if missing:
                    self.err(
                        path,
                        "every property must be in `required`; missing: "
                        + ", ".join(sorted(missing))
                        + " (model optionality as a nullable union, e.g. [\"string\",\"null\"])",
                    )
                extra = [k for k in required if k not in props]
                if extra:
                    self.warn(path, "`required` names undefined properties: " + ", ".join(sorted(extra)))
                for name, sub in props.items():
                    self.walk(sub, f"{path}.{name}" if path else name, depth + 1)

        if "items" in node:
            items = node["items"]
            if isinstance(items, dict):
                self.walk(items, f"{path}[]", depth + 1)
            elif isinstance(items, list):
                for i, sub in enumerate(items):
                    self.walk(sub, f"{path}[{i}]", depth + 1)

        if isinstance(node.get("anyOf"), list):
            for i, sub in enumerate(node["anyOf"]):
                self.walk(sub, f"{path}|anyOf[{i}]", depth)

        for key in ("$defs", "definitions"):
            if isinstance(node.get(key), dict):
                for name, sub in node[key].items():
                    self.walk(sub, f"{key}.{name}", depth)


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    try:
        with open(argv[1], "r", encoding="utf-8") as fh:
            raw = fh.read()
        doc = json.loads(raw)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"error: could not read {argv[1]}: {exc}", file=sys.stderr)
        return 2

    schema, wrappers = unwrap(doc)
    if wrappers:
        print(f"unwrapped via: {' -> '.join(wrappers)}")

    w = Walker()

    root_type = schema.get("type")
    if root_type != "object":
        w.err("", f"root schema type must be \"object\" (found {root_type!r})")
    if "anyOf" in schema:
        w.err("", "root schema must not be `anyOf`")

    w.walk(schema)

    schema_chars = len(json.dumps(schema, separators=(",", ":"), ensure_ascii=False))
    if schema_chars > MAX_SCHEMA_CHARS:
        w.err("", f"schema serializes to {schema_chars} chars, over the {MAX_SCHEMA_CHARS} limit")
    if w.property_count > MAX_PROPERTIES:
        w.err("", f"{w.property_count} total properties, over the {MAX_PROPERTIES} limit")
    if w.enum_count > MAX_ENUM_VALUES:
        w.err("", f"{w.enum_count} enum values combined, over the {MAX_ENUM_VALUES} limit")

    print(
        f"properties={w.property_count}  enum_values={w.enum_count}  "
        f"max_depth={w.max_depth_seen}  serialized_chars={schema_chars}"
    )

    for path, msg in w.warnings:
        print(f"WARN  {path}: {msg}")
    for path, msg in w.errors:
        print(f"FAIL  {path}: {msg}")

    if w.errors:
        print(f"\n{len(w.errors)} violation(s). See references/structured-outputs.md.")
        return 1
    print("\nNo strict-mode violations found.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

# ## Sources
# - https://developers.openai.com/api/docs/guides/structured-outputs
# - https://developers.openai.com/api/docs/guides/function-calling
# Fetched: 2026-08-05
