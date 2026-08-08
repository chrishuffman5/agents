#!/usr/bin/env python3
"""cache-prefix-diff.py - show exactly where two request bodies stop sharing a prefix.

Why: prompt caching matches on a byte-identical prefix. When `cached_tokens` is 0,
the cause is almost always a small difference high up in the prompt - a timestamp in
the system message, a reordered tools array, non-deterministic key ordering. This
prints the divergence point and the surrounding context so you can see it.

Usage:
    python cache-prefix-diff.py request-a.json request-b.json
    python cache-prefix-diff.py a.json b.json --sort-keys   # test key-order sensitivity

Read-only: reads two files, makes no network calls, needs no API key.
Exit codes: 0 = identical, 1 = divergence found, 2 = usage/read error.

IMPORTANT: this is a *character* proxy for a *token* rule. The documented thresholds
are token-based (routing hashes roughly the first 256 tokens; caching needs a 1,024-token
minimum on GPT-5.6+). No tokenizer ships with this script, so treat the character
offsets as relative evidence, not as a token count.
"""

import json
import sys


def load(path, sort_keys):
    with open(path, "r", encoding="utf-8") as fh:
        raw = fh.read()
    try:
        obj = json.loads(raw)
    except json.JSONDecodeError:
        return raw, False
    return json.dumps(obj, ensure_ascii=False, sort_keys=sort_keys, separators=(",", ":")), True


def common_prefix_len(a, b):
    n = min(len(a), len(b))
    for i in range(n):
        if a[i] != b[i]:
            return i
    return n


def snippet(s, start, end):
    return repr(s[max(0, start):end])


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    sort_keys = "--sort-keys" in argv
    if len(args) != 2:
        print(__doc__)
        return 2

    try:
        a, a_json = load(args[0], sort_keys)
        b, b_json = load(args[1], sort_keys)
    except OSError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    for path, is_json in ((args[0], a_json), (args[1], b_json)):
        if not is_json:
            print(f"note: {path} is not valid JSON - compared as raw text")

    shared = common_prefix_len(a, b)
    print(f"a: {len(a)} chars ({args[0]})")
    print(f"b: {len(b)} chars ({args[1]})")
    print(f"shared prefix: {shared} chars "
          f"({shared / max(len(a), 1):.1%} of a, {shared / max(len(b), 1):.1%} of b)")

    if shared == len(a) == len(b):
        print("\nBodies are byte-identical. Any cache miss is not caused by prefix drift.")
        return 0

    print(f"\nfirst divergence at char {shared}")
    print(f"  context before : {snippet(a, shared - 80, shared)}")
    print(f"  a continues    : {snippet(a, shared, shared + 80)}")
    print(f"  b continues    : {snippet(b, shared, shared + 80)}")

    if not sort_keys and a_json and b_json:
        a2, _ = load(args[0], True)
        b2, _ = load(args[1], True)
        shared2 = common_prefix_len(a2, b2)
        if shared2 > shared:
            print(
                f"\nWith keys sorted the shared prefix grows to {shared2} chars - the difference is at "
                "least partly JSON key ordering. Serialize request bodies deterministically."
            )

    print(
        "\nFix order: move static content (instructions, examples, tool definitions) to the front, "
        "keep it byte-identical, and set prompt_cache_key on requests that share a prefix. "
        "See references/prompt-caching.md."
    )
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))

# ## Sources
# - https://developers.openai.com/api/docs/guides/prompt-caching
# Fetched: 2026-08-05
