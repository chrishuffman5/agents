#!/usr/bin/env python3
"""Read-only validator for fine-tuning JSONL datasets.

Checks a JSONL file against the documented shapes for:
  openai-sft   {"messages": [...], "tools"?: [...], "parallel_tool_calls"?: bool}
  openai-dpo   {"input": {...}, "preferred_output": [...], "non_preferred_output": [...]}
  trl-pref     {"prompt": ..., "chosen": ..., "rejected": ...}
  trl-unpaired {"prompt": ..., "completion": ..., "label": bool}
  trl-stepwise {"prompt": ..., "completions": [...], "labels": [...]}
  trl-pc       {"prompt": ..., "completion": ...}
  trl-lm       {"text": ...} or {"messages": [...]}

Reports shape errors, exact duplicate rows, prompt collisions with differing
targets, and length distributions. Never writes or modifies anything.

Usage:
  python validate-training-jsonl.py DATA.jsonl [--schema NAME] [--max-errors N]

Exit code 0 when every row is clean, 1 when any row has an issue, 2 when the
file cannot be read. Nothing is ever written.

Schema sources: see references/formats-openai.md and references/formats-trl.md.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from collections import Counter, defaultdict

SCHEMAS = (
    "openai-sft",
    "openai-dpo",
    "trl-pref",
    "trl-unpaired",
    "trl-stepwise",
    "trl-pc",
    "trl-lm",
)

VALID_ROLES = {"system", "developer", "user", "assistant", "tool"}


def detect_schema(row: dict) -> str | None:
    keys = set(row)
    if {"input", "preferred_output", "non_preferred_output"} <= keys:
        return "openai-dpo"
    if {"prompt", "chosen", "rejected"} <= keys or {"chosen", "rejected"} <= keys:
        return "trl-pref"
    if {"prompt", "completions", "labels"} <= keys:
        return "trl-stepwise"
    if {"prompt", "completion", "label"} <= keys:
        return "trl-unpaired"
    if {"prompt", "completion"} <= keys:
        return "trl-pc"
    if "messages" in keys:
        return "openai-sft"
    if "text" in keys:
        return "trl-lm"
    return None


def check_messages(value, field: str, errs: list) -> None:
    if not isinstance(value, list):
        errs.append(f"{field}: expected a list of message objects")
        return
    if not value:
        errs.append(f"{field}: empty message list")
        return
    roles = []
    for i, msg in enumerate(value):
        if not isinstance(msg, dict):
            errs.append(f"{field}[{i}]: not an object")
            continue
        role = msg.get("role")
        if role is None:
            errs.append(f"{field}[{i}]: missing 'role'")
        elif role not in VALID_ROLES:
            errs.append(f"{field}[{i}]: unrecognized role {role!r}")
        else:
            roles.append(role)
        has_content = msg.get("content") not in (None, "")
        has_calls = bool(msg.get("tool_calls"))
        if not has_content and not has_calls:
            errs.append(f"{field}[{i}]: no 'content' and no 'tool_calls'")
    convo = [r for r in roles if r in ("user", "assistant")]
    for i in range(1, len(convo)):
        if convo[i] == convo[i - 1]:
            errs.append(f"{field}: consecutive {convo[i]!r} turns (non-alternating)")
            break


def check_single_assistant(value, field: str, errs: list) -> None:
    if not isinstance(value, list) or len(value) != 1:
        errs.append(f"{field}: expected a one-element list holding one assistant message")
        return
    msg = value[0]
    if not isinstance(msg, dict) or msg.get("role") != "assistant":
        errs.append(f"{field}[0]: expected role 'assistant'")
    elif msg.get("content") in (None, "") and not msg.get("tool_calls"):
        errs.append(f"{field}[0]: empty assistant response")


def text_of(value) -> str:
    """Flatten a string or message list into comparable text."""
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        parts = []
        for m in value:
            if isinstance(m, dict):
                c = m.get("content")
                parts.append(c if isinstance(c, str) else json.dumps(c, sort_keys=True))
            else:
                parts.append(json.dumps(m, sort_keys=True))
        return "\n".join(parts)
    return json.dumps(value, sort_keys=True)


def validate_row(row: dict, schema: str) -> list:
    errs: list = []
    if schema == "openai-sft":
        if "messages" not in row:
            errs.append("missing 'messages'")
        else:
            check_messages(row["messages"], "messages", errs)
        if "tools" in row and not isinstance(row["tools"], list):
            errs.append("'tools' must be a list")
        if "parallel_tool_calls" in row and not isinstance(row["parallel_tool_calls"], bool):
            errs.append("'parallel_tool_calls' must be a boolean")
    elif schema == "openai-dpo":
        inp = row.get("input")
        if not isinstance(inp, dict):
            errs.append("'input' must be an object with 'messages'")
        else:
            check_messages(inp.get("messages"), "input.messages", errs)
            if "tools" in inp and not isinstance(inp["tools"], list):
                errs.append("input.tools must be a list")
            last = [m for m in (inp.get("messages") or []) if isinstance(m, dict)]
            if last and last[-1].get("role") == "assistant":
                errs.append(
                    "input.messages ends with an assistant turn; the differing final "
                    "assistant turn belongs in preferred_output/non_preferred_output"
                )
        check_single_assistant(row.get("preferred_output"), "preferred_output", errs)
        check_single_assistant(row.get("non_preferred_output"), "non_preferred_output", errs)
        if text_of(row.get("preferred_output")) == text_of(row.get("non_preferred_output")):
            errs.append("preferred_output identical to non_preferred_output (no signal)")
    elif schema == "trl-pref":
        for field in ("chosen", "rejected"):
            if field not in row:
                errs.append(f"missing '{field}'")
            elif isinstance(row[field], list):
                check_messages(row[field], field, errs)
            elif not isinstance(row[field], str):
                errs.append(f"'{field}' must be a string or message list")
        if "prompt" not in row:
            errs.append("implicit-prompt preference row; explicit 'prompt' is recommended")
        if text_of(row.get("chosen")) == text_of(row.get("rejected")):
            errs.append("chosen identical to rejected (no signal)")
    elif schema == "trl-unpaired":
        if not isinstance(row.get("label"), bool):
            errs.append("'label' must be a boolean")
        if "completion" not in row:
            errs.append("missing 'completion'")
    elif schema == "trl-stepwise":
        comps, labels = row.get("completions"), row.get("labels")
        if not isinstance(comps, list) or not comps:
            errs.append("'completions' must be a non-empty list")
        if not isinstance(labels, list) or not labels:
            errs.append("'labels' must be a non-empty list")
        if isinstance(comps, list) and isinstance(labels, list) and len(comps) != len(labels):
            errs.append(f"len(completions)={len(comps)} != len(labels)={len(labels)}")
        if isinstance(labels, list) and any(not isinstance(x, bool) for x in labels):
            errs.append("'labels' must contain booleans only")
    elif schema == "trl-pc":
        for field in ("prompt", "completion"):
            if field not in row:
                errs.append(f"missing '{field}'")
            elif isinstance(row[field], list):
                check_messages(row[field], field, errs)
    elif schema == "trl-lm":
        if "messages" in row:
            check_messages(row["messages"], "messages", errs)
        elif not isinstance(row.get("text"), str) or not row["text"].strip():
            errs.append("'text' must be a non-empty string")
    return errs


def prompt_target(row: dict, schema: str):
    if schema == "openai-sft":
        msgs = [m for m in row.get("messages", []) if isinstance(m, dict)]
        prompt = text_of([m for m in msgs if m.get("role") != "assistant"])
        target = text_of([m for m in msgs if m.get("role") == "assistant"])
        return prompt, target
    if schema == "openai-dpo":
        return text_of((row.get("input") or {}).get("messages")), text_of(row.get("preferred_output"))
    if schema in ("trl-pref",):
        return text_of(row.get("prompt")), text_of(row.get("chosen"))
    if schema in ("trl-pc", "trl-unpaired"):
        return text_of(row.get("prompt")), text_of(row.get("completion"))
    if schema == "trl-stepwise":
        return text_of(row.get("prompt")), text_of(row.get("completions"))
    return text_of(row.get("text") or row.get("messages")), ""


def percentile(values, pct):
    if not values:
        return 0
    ordered = sorted(values)
    idx = min(len(ordered) - 1, int(round((pct / 100.0) * (len(ordered) - 1))))
    return ordered[idx]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("path", help="path to the JSONL file (read-only)")
    ap.add_argument("--schema", choices=SCHEMAS, help="force a schema instead of auto-detecting")
    ap.add_argument("--max-errors", type=int, default=25, help="max error lines to print (default 25)")
    args = ap.parse_args()

    total = 0
    parse_errors = 0
    error_rows = 0
    printed = 0
    schema_counts: Counter = Counter()
    row_hashes: dict = {}
    prompts: dict = defaultdict(set)
    prompt_first_line: dict = {}
    char_lengths: list = []

    try:
        fh = open(args.path, "r", encoding="utf-8")
    except OSError as exc:
        print(f"cannot read {args.path}: {exc}", file=sys.stderr)
        return 2

    with fh:
        for lineno, raw in enumerate(fh, 1):
            if not raw.strip():
                continue
            total += 1
            try:
                row = json.loads(raw)
            except json.JSONDecodeError as exc:
                parse_errors += 1
                if printed < args.max_errors:
                    print(f"line {lineno}: invalid JSON - {exc}")
                    printed += 1
                continue
            if not isinstance(row, dict):
                error_rows += 1
                if printed < args.max_errors:
                    print(f"line {lineno}: top-level value is not an object")
                    printed += 1
                continue

            schema = args.schema or detect_schema(row)
            if schema is None:
                error_rows += 1
                schema_counts["<unrecognized>"] += 1
                if printed < args.max_errors:
                    print(f"line {lineno}: no known schema matches keys {sorted(row)}")
                    printed += 1
                continue
            schema_counts[schema] += 1

            errs = validate_row(row, schema)
            if errs:
                error_rows += 1
                for msg in errs:
                    if printed < args.max_errors:
                        print(f"line {lineno} [{schema}]: {msg}")
                        printed += 1

            digest = hashlib.sha256(
                json.dumps(row, sort_keys=True, ensure_ascii=False).encode("utf-8")
            ).hexdigest()
            if digest in row_hashes:
                if printed < args.max_errors:
                    print(f"line {lineno}: exact duplicate of line {row_hashes[digest]}")
                    printed += 1
                error_rows += 1
            else:
                row_hashes[digest] = lineno

            prompt, target = prompt_target(row, schema)
            key = " ".join(prompt.split()).lower()
            if key:
                prompts[key].add(target)
                prompt_first_line.setdefault(key, lineno)
            char_lengths.append(len(raw))

    conflicts = [k for k, targets in prompts.items() if len(targets) > 1]

    print()
    print(f"file:            {args.path}")
    print(f"rows parsed:     {total}")
    print(f"json errors:     {parse_errors}")
    print(f"rows with issues:{error_rows}")
    if printed >= args.max_errors:
        print(f"(output truncated at --max-errors={args.max_errors})")
    print("schemas seen:    " + (", ".join(f"{k}={v}" for k, v in schema_counts.most_common()) or "none"))
    print(f"unique rows:     {len(row_hashes)}  (exact duplicates: {total - parse_errors - len(row_hashes)})")
    print(f"unique prompts:  {len(prompts)}")
    print(f"prompt collisions with differing targets: {len(conflicts)}")
    for key in conflicts[:5]:
        print(f"  first seen line {prompt_first_line[key]}: {key[:90]!r}")
    if char_lengths:
        print(
            "row chars:       "
            f"min={min(char_lengths)} p50={percentile(char_lengths, 50)} "
            f"p95={percentile(char_lengths, 95)} max={max(char_lengths)}"
        )

    print()
    print("Shape validated only. Consistency, class balance vs inference distribution,")
    print("and eval decontamination remain human checks - see SKILL.md.")

    return 1 if (parse_errors or error_rows) else 0


if __name__ == "__main__":
    sys.exit(main())
