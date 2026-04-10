#!/usr/bin/env python3
"""
============================================================================
Python - CSV/JSON File Processor

Purpose : Import CSV/JSON files, filter, transform, and export to
          multiple formats with argparse-driven CLI.
Version : 1.0.0
Targets : Python 3.10+
Safety  : Read-only on input. Creates new output files.

Usage:
  python3 03-csv-processor.py data.csv --filter 'score>80' --format json
  python3 03-csv-processor.py data.csv --select id,name --sort score --desc
============================================================================
"""

import argparse
import csv
import json
import logging
import operator
import sys
from pathlib import Path
from typing import Any, Callable

log = logging.getLogger("csv_processor")


def auto_type(value: str) -> Any:
    if value.lower() in ("true", "yes"):
        return True
    if value.lower() in ("false", "no"):
        return False
    try:
        return int(value)
    except ValueError:
        pass
    try:
        return float(value)
    except ValueError:
        pass
    return value


OPS = {
    ">=": operator.ge, "<=": operator.le, "!=": operator.ne,
    ">": operator.gt, "<": operator.lt, "=": operator.eq,
}


def parse_filter(expr: str) -> Callable[[dict], bool]:
    for op_str, op_fn in OPS.items():
        if op_str in expr:
            field, _, raw_val = expr.partition(op_str)
            field = field.strip()
            value = auto_type(raw_val.strip())

            def predicate(row, f=field, fn=op_fn, v=value):
                rv = row.get(f)
                if rv is None:
                    return False
                try:
                    return fn(auto_type(str(rv)), v)
                except TypeError:
                    return False
            return predicate
    raise ValueError(f"Cannot parse filter: {expr!r}")


def read_input(path: Path) -> list[dict[str, Any]]:
    suffix = path.suffix.lower()
    if suffix == ".json":
        data = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(data, list):
            return [{k: auto_type(str(v)) for k, v in r.items()} for r in data]
        raise ValueError("JSON must be a list of objects")
    delimiter = "\t" if suffix == ".tsv" else ","
    with path.open(newline="", encoding="utf-8") as f:
        return [{k: auto_type(v) for k, v in row.items()} for row in csv.DictReader(f, delimiter=delimiter)]


def write_csv(rows: list[dict], dest: Path) -> None:
    if not rows:
        dest.write_text("", encoding="utf-8")
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    with dest.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def write_json(rows: list[dict], dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(rows, indent=2, default=str), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="CSV/JSON processor: filter, transform, convert",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Examples:\n"
               "  python3 03-csv-processor.py data.csv --filter 'score>80' --format json\n"
               "  python3 03-csv-processor.py data.csv --select id,name --sort score --desc\n",
    )
    parser.add_argument("input", type=Path, help="Input file (CSV/TSV/JSON)")
    parser.add_argument("-o", "--output", type=Path, default=None)
    parser.add_argument("-f", "--format", choices=["csv", "json", "tsv"], default="csv")
    parser.add_argument("--filter", action="append", dest="filters", metavar="EXPR")
    parser.add_argument("--select", metavar="FIELDS", help="Comma-separated fields")
    parser.add_argument("--rename", action="append", dest="renames", metavar="OLD=NEW")
    parser.add_argument("--sort", metavar="FIELD")
    parser.add_argument("--desc", action="store_true")
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO,
                        format="%(levelname)-8s %(message)s")

    if not args.input.exists():
        log.error("Not found: %s", args.input)
        sys.exit(1)

    log.info("Reading %s", args.input)
    rows = read_input(args.input)
    log.info("Loaded %d rows", len(rows))

    if args.filters:
        for expr in args.filters:
            pred = parse_filter(expr)
            before = len(rows)
            rows = [r for r in rows if pred(r)]
            log.info("Filter '%s': %d -> %d rows", expr, before, len(rows))

    if args.select:
        fields = [f.strip() for f in args.select.split(",")]
        rows = [{f: row.get(f) for f in fields} for row in rows]

    if args.renames:
        for m in args.renames:
            old, _, new = m.partition("=")
            rows = [{(new.strip() if k == old.strip() else k): v for k, v in row.items()} for row in rows]

    if args.sort:
        rows = sorted(rows, key=lambda r: (r.get(args.sort) is None, r.get(args.sort)),
                       reverse=args.desc)

    if args.limit is not None:
        rows = rows[:args.limit]

    log.info("Output: %d rows", len(rows))

    if args.dry_run:
        print(f"Dry run: {len(rows)} rows as {args.format}")
        if rows:
            print(f"Columns: {list(rows[0].keys())}")
        return

    if args.output is None:
        if args.format == "json":
            print(json.dumps(rows, indent=2, default=str))
        else:
            if rows:
                writer = csv.DictWriter(sys.stdout, fieldnames=list(rows[0].keys()))
                writer.writeheader()
                writer.writerows(rows)
        return

    out_path = args.output
    if out_path.suffix == "":
        out_path.mkdir(parents=True, exist_ok=True)
        out_path = out_path / (args.input.stem + f"_processed.{args.format}")

    if args.format == "json":
        write_json(rows, out_path)
    else:
        write_csv(rows, out_path)
    log.info("Written %d rows to %s", len(rows), out_path)


if __name__ == "__main__":
    main()
