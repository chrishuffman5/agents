---
name: cli-python-3.12
description: "Python 3.12 version agent. Key features: type parameter syntax ([T] generics on functions/classes), 'type' keyword for type aliases, f-string improvements (nested quotes, backslashes, inline comments), per-interpreter GIL (experimental)."
license: MIT
metadata:
  version: "1.0.0"
---

# Python 3.12 Features

## Type Parameter Syntax (PEP 695)

```python
# Old way (verbose):
from typing import TypeVar
T = TypeVar("T")
def first(lst: list[T]) -> T:
    return lst[0]

# New way (3.12):
def first[T](lst: list[T]) -> T:
    return lst[0]

def zip_lists[T, U](a: list[T], b: list[U]) -> list[tuple[T, U]]:
    return list(zip(a, b))

class Stack[T]:
    def __init__(self) -> None:
        self._items: list[T] = []
    def push(self, item: T) -> None:
        self._items.append(item)
    def pop(self) -> T:
        return self._items.pop()
```

## Type Aliases with `type` Keyword

```python
type Vector = list[float]
type Matrix = list[Vector]
type Callback[T] = Callable[[T], None]
```

## f-string Improvements

```python
name = "World"

# Nested quotes now work without escaping
msg = f"{'Hello'!s}"

# Backslash in f-string expressions
msg = f"{'\n'.join(['a', 'b', 'c'])}"

# Complex expressions
msg = f"{[x**2 for x in range(5)]}"

# Inline comments
msg = f"Result: {
    value   # this is a comment
    * 2
}"
```

## Per-Interpreter GIL (Experimental)

Subinterpreters can each have their own GIL, enabling true parallelism. Production-ready in 3.13.
