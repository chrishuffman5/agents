---
name: cli-python-3.14
description: "Python 3.14 version agent. Key features: template strings (t'...' returning Template objects for safe interpolation), deferred annotation evaluation (PEP 749, annotations stored as strings and evaluated lazily)."
license: MIT
metadata:
  version: "1.0.0"
---

# Python 3.14 Features

## Template Strings (PEP 750)

Unlike f-strings which produce `str`, t-strings produce a `Template` object. This allows frameworks to process interpolated parts safely (SQL injection prevention, HTML escaping, structured logging).

```python
# t-strings return Template, not str
greeting = t"Hello, {name}!"
# greeting.strings = ("Hello, ", "!")
# greeting.interpolations = [Interpolation(name, "name", None, "")]

# Safe HTML rendering
def safe_html(template) -> str:
    import html
    parts = []
    for item in template:
        if isinstance(item, str):
            parts.append(item)
        else:
            parts.append(html.escape(str(item.value)))
    return "".join(parts)

user_input = "<script>alert('xss')</script>"
output = safe_html(t"<p>Hello, {user_input}!</p>")
# "<p>Hello, &lt;script&gt;alert(&#x27;xss&#x27;)&lt;/script&gt;!</p>"

# SQL safety pattern
def sql_query(template) -> tuple[str, list]:
    query_parts, params = [], []
    for item in template:
        if isinstance(item, str):
            query_parts.append(item)
        else:
            query_parts.append("?")
            params.append(item.value)
    return "".join(query_parts), params

name = "Alice"
query, params = sql_query(t"SELECT * FROM users WHERE name = {name}")
# query = "SELECT * FROM users WHERE name = ?"
# params = ["Alice"]
```

## Deferred Annotation Evaluation (PEP 749)

Annotations are stored as strings by default in 3.14 and evaluated lazily only when `inspect.get_annotations()` is called. This replaces the `from __future__ import annotations` approach.

```python
class Config:
    host: str          # stored as string "str", not evaluated at class creation
    port: int
    tags: list[str]

import inspect
hints = inspect.get_annotations(Config, eval_str=True)
# {"host": str, "port": int, "tags": list[str]}
```

Benefits:
- Forward references work without quotes or `__future__` import
- Faster class creation (no annotation evaluation)
- Reduced import-time overhead
