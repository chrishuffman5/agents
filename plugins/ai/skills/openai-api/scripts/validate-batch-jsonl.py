#!/usr/bin/env python3
"""validate-batch-jsonl.py - offline validation of an OpenAI Batch API input file.

Why: a single malformed line fails the whole batch, and you only find out after the
upload plus a validation cycle. Every rule here is documented in the Batch guide.

Usage:
    python validate-batch-jsonl.py input.jsonl
    python validate-batch-jsonl.py input.jsonl --max-errors 50

Read-only: reads one file, makes no network calls, needs no API key.
Exit codes: 0 = valid, 1 = problems found, 2 = usage/read error.

Rules enforced (Batch guide, fetched 2026-08-05):
  - file must be .jsonl and <= 200 MB
  - <= 50,000 requests per batch
  - each line: a JSON object with custom_id, method "POST", url, body
  - custom_id must be unique (results are matched by it; output order is not preserved)
  - url must be one of the supported batch endpoints
"""

import json
import sys

MAX_REQUESTS = 50_000
MAX_BYTES = 200 * 1024 * 1024
SUPPORTED_URLS = {
    "/v1/chat/completions",
    "/v1/completions",
    "/v1/embeddings",
    "/v1/responses",
    "/v1/moderations",
    "/v1/images/generations",
    "/v1/images/edits",
    "/v1/videos",
}


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    path = argv[1]
    max_errors = 25
    if "--max-errors" in argv:
        try:
            max_errors = int(argv[argv.index("--max-errors") + 1])
        except (IndexError, ValueError):
            print("error: --max-errors needs an integer", file=sys.stderr)
            return 2

    errors = []
    warnings = []

    if not path.endswith(".jsonl"):
        warnings.append(f"file does not end in .jsonl; the Batch API accepts .jsonl only ({path})")

    try:
        with open(path, "rb") as fh:
            size = len(fh.read())
    except OSError as exc:
        print(f"error: could not read {path}: {exc}", file=sys.stderr)
        return 2

    if size > MAX_BYTES:
        errors.append(f"file is {size / 1024 / 1024:.1f} MB, over the 200 MB batch input limit")

    seen_ids = {}
    urls = {}
    count = 0

    try:
        with open(path, "r", encoding="utf-8") as fh:
            for lineno, line in enumerate(fh, 1):
                stripped = line.strip()
                if not stripped:
                    warnings.append(f"line {lineno}: blank line")
                    continue
                count += 1
                try:
                    obj = json.loads(stripped)
                except json.JSONDecodeError as exc:
                    errors.append(f"line {lineno}: invalid JSON ({exc.msg} at col {exc.colno})")
                    continue
                if not isinstance(obj, dict):
                    errors.append(f"line {lineno}: top-level value is {type(obj).__name__}, expected an object")
                    continue

                cid = obj.get("custom_id")
                if not isinstance(cid, str) or not cid:
                    errors.append(f"line {lineno}: missing or non-string `custom_id`")
                elif cid in seen_ids:
                    errors.append(f"line {lineno}: duplicate custom_id {cid!r} (first seen line {seen_ids[cid]})")
                else:
                    seen_ids[cid] = lineno

                method = obj.get("method")
                if method != "POST":
                    errors.append(f"line {lineno}: `method` is {method!r}, expected \"POST\"")

                url = obj.get("url")
                if not isinstance(url, str):
                    errors.append(f"line {lineno}: missing or non-string `url`")
                else:
                    urls[url] = urls.get(url, 0) + 1
                    if url not in SUPPORTED_URLS:
                        errors.append(
                            f"line {lineno}: url {url!r} is not a supported batch endpoint "
                            f"({', '.join(sorted(SUPPORTED_URLS))})"
                        )

                if not isinstance(obj.get("body"), dict):
                    errors.append(f"line {lineno}: missing or non-object `body`")
    except OSError as exc:
        print(f"error: could not read {path}: {exc}", file=sys.stderr)
        return 2

    if count > MAX_REQUESTS:
        errors.append(f"{count} requests, over the {MAX_REQUESTS} per-batch limit")
    if count == 0:
        errors.append("file contains no requests")

    print(f"requests={count}  bytes={size}  unique_custom_ids={len(seen_ids)}")
    if len(urls) > 1:
        print("note: multiple target urls in one file -> " + ", ".join(f"{u} x{n}" for u, n in sorted(urls.items())))

    for msg in warnings[:max_errors]:
        print(f"WARN  {msg}")
    for msg in errors[:max_errors]:
        print(f"FAIL  {msg}")
    if len(errors) > max_errors:
        print(f"... and {len(errors) - max_errors} more (raise --max-errors to see them)")

    if errors:
        print(f"\n{len(errors)} problem(s). See references/batch.md.")
        return 1
    print("\nBatch input file looks valid. Remember: join results on custom_id, not position.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

# ## Sources
# - https://developers.openai.com/api/docs/guides/batch
# Fetched: 2026-08-05
