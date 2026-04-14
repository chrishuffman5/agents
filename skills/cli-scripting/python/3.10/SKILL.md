---
name: cli-python-3.10
description: "Python 3.10 version agent. Key features: structural pattern matching (match/case with value, type, sequence, and mapping patterns), type union syntax (X | Y replacing Union[X, Y]), parenthesized context managers, better error messages."
license: MIT
metadata:
  version: "1.0.0"
---

# Python 3.10 Features

## Structural Pattern Matching (match/case)

Not a switch statement -- true structural matching with deconstruction.

```python
# Match on value
def http_status(status: int) -> str:
    match status:
        case 200: return "OK"
        case 404: return "Not Found"
        case 500 | 502 | 503: return "Server Error"
        case _: return "Unknown"

# Match on type + structure
def handle_event(event: dict) -> None:
    match event:
        case {"type": "click", "x": x, "y": y}:
            print(f"Click at ({x}, {y})")
        case {"type": "key", "key": str(k)} if k.isalpha():
            print(f"Key: {k}")
        case {"type": "error", "code": int(code)}:
            print(f"Error: {code}")
        case _:
            print(f"Unknown: {event}")

# Match on class instances
from dataclasses import dataclass

@dataclass
class Point:
    x: float
    y: float

def describe(shape) -> str:
    match shape:
        case Point(x=0, y=0): return "Origin"
        case Point(x=x, y=0): return f"X-axis at {x}"
        case _: return "Unknown"

# Sequence patterns
def process_args(args: list[str]) -> None:
    match args:
        case []: print("No args")
        case [cmd]: print(f"Single: {cmd}")
        case ["--verbose", *rest] | ["-v", *rest]:
            print(f"Verbose, rest: {rest}")
        case ["--output", filename, *rest]:
            print(f"Output to {filename}")
```

## Type Union Syntax

```python
# New: X | Y replaces Union[X, Y]
def process(value: int | str | None) -> str:
    if value is None: return "nothing"
    return str(value)

# Works in isinstance too
isinstance(x, int | str)
```

## Parenthesized Context Managers

```python
with (open("input.txt") as f_in,
      open("output.txt", "w") as f_out):
    f_out.write(f_in.read().upper())
```
