#!/usr/bin/env python3
"""
============================================================================
Python - File Organizer

Purpose : Organize files by type, date, year, or size into subdirectories.
          Supports dry-run mode and undo via JSON log.
Version : 1.0.0
Targets : Python 3.10+
Safety  : Dry-run by default when --dry-run flag is used.

Usage:
  python3 04-file-organizer.py ~/Downloads --by type --dry-run
  python3 04-file-organizer.py ~/Downloads --by type --undo-log undo.json
  python3 04-file-organizer.py ~/Downloads --undo undo.json
============================================================================
"""

import argparse
import json
import logging
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

log = logging.getLogger("organizer")

CATEGORIES = {
    "images":     {".jpg", ".jpeg", ".png", ".gif", ".bmp", ".svg", ".webp", ".heic"},
    "documents":  {".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".odt"},
    "text":       {".txt", ".md", ".rst", ".log", ".csv", ".tsv", ".json", ".yaml", ".toml", ".xml"},
    "archives":   {".zip", ".tar", ".gz", ".bz2", ".xz", ".7z", ".rar", ".tgz"},
    "code":       {".py", ".js", ".ts", ".sh", ".ps1", ".go", ".rs", ".java", ".c", ".cpp", ".h"},
    "audio":      {".mp3", ".wav", ".flac", ".aac", ".ogg", ".m4a"},
    "video":      {".mp4", ".mkv", ".avi", ".mov", ".wmv", ".webm"},
    "executables": {".exe", ".msi", ".dmg", ".pkg", ".deb", ".rpm", ".appimage"},
}


def ext_to_category(ext: str) -> str:
    ext = ext.lower()
    for cat, exts in CATEGORIES.items():
        if ext in exts:
            return cat
    return "misc"


def by_type(f: Path) -> str:
    return ext_to_category(f.suffix)


def by_date(f: Path) -> str:
    mtime = datetime.fromtimestamp(f.stat().st_mtime, tz=timezone.utc)
    return mtime.strftime("%Y/%m")


def by_year(f: Path) -> str:
    mtime = datetime.fromtimestamp(f.stat().st_mtime, tz=timezone.utc)
    return mtime.strftime("%Y")


def by_size(f: Path) -> str:
    size = f.stat().st_size
    if size < 10_000:
        return "tiny"
    elif size < 1_000_000:
        return "small"
    elif size < 100_000_000:
        return "medium"
    else:
        return "large"


STRATEGIES: dict[str, Callable[[Path], str]] = {
    "type": by_type, "date": by_date, "year": by_year, "size": by_size,
}


class FileOrganizer:
    def __init__(self, source: Path, dest: Path, strategy: Callable[[Path], str],
                 dry_run: bool = False, recursive: bool = False,
                 undo_log: Path | None = None) -> None:
        self.source = source.resolve()
        self.dest = dest.resolve()
        self.strategy = strategy
        self.dry_run = dry_run
        self.recursive = recursive
        self.undo_log = undo_log
        self._moves: list[dict] = []
        self._stats = {"moved": 0, "skipped": 0, "errors": 0}

    def _collect(self) -> list[Path]:
        if self.recursive:
            return [p for p in self.source.rglob("*") if p.is_file()]
        return [p for p in self.source.iterdir() if p.is_file()]

    def _safe_dest(self, subdir: str, filename: str) -> Path:
        candidate = self.dest / subdir / filename
        if not candidate.exists():
            return candidate
        stem, suffix = Path(filename).stem, Path(filename).suffix
        counter = 1
        while True:
            candidate = self.dest / subdir / f"{stem}_{counter}{suffix}"
            if not candidate.exists():
                return candidate
            counter += 1

    def run(self) -> dict:
        files = self._collect()
        log.info("Found %d files in %s", len(files), self.source)

        for f in files:
            try:
                subdir = self.strategy(f)
                dest_path = self._safe_dest(subdir, f.name)

                if self.dry_run:
                    log.info("[DRY-RUN] %s -> %s", f.name, dest_path.relative_to(self.dest))
                else:
                    dest_path.parent.mkdir(parents=True, exist_ok=True)
                    shutil.move(str(f), str(dest_path))
                    log.info("Moved %s -> %s", f.name, dest_path.relative_to(self.dest))
                self._stats["moved"] += 1
                self._moves.append({"src": str(f), "dst": str(dest_path)})
            except Exception as e:
                log.error("Error: %s: %s", f, e)
                self._stats["errors"] += 1

        if not self.dry_run and self.undo_log and self._moves:
            self.undo_log.parent.mkdir(parents=True, exist_ok=True)
            self.undo_log.write_text(json.dumps(self._moves, indent=2), encoding="utf-8")
            log.info("Undo log: %s", self.undo_log)

        return self._stats


def undo_from_log(undo_log: Path, dry_run: bool = False) -> None:
    if not undo_log.exists():
        log.error("Undo log not found: %s", undo_log)
        sys.exit(1)

    moves = json.loads(undo_log.read_text(encoding="utf-8"))
    log.info("Undoing %d moves", len(moves))

    for entry in reversed(moves):
        src, dst = Path(entry["dst"]), Path(entry["src"])
        if not src.exists():
            log.warning("Missing: %s", src)
            continue
        if dry_run:
            log.info("[DRY-RUN] Undo: %s -> %s", src.name, dst)
        else:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(src), str(dst))
            log.info("Restored: %s", dst)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Organize files by type, date, year, or size",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Examples:\n"
               "  python3 04-file-organizer.py ~/Downloads --by type --dry-run\n"
               "  python3 04-file-organizer.py ~/Downloads --by date -o ~/sorted -r\n"
               "  python3 04-file-organizer.py ~/Downloads --undo undo.json\n",
    )
    parser.add_argument("source", type=Path, help="Source directory")
    parser.add_argument("-o", "--output", type=Path, default=None)
    parser.add_argument("--by", choices=list(STRATEGIES), default="type")
    parser.add_argument("-r", "--recursive", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--undo-log", type=Path, default=None)
    parser.add_argument("--undo", type=Path, default=None)
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO,
                        format="%(levelname)-8s %(message)s")

    if args.undo:
        undo_from_log(args.undo, dry_run=args.dry_run)
        return

    if not args.source.is_dir():
        log.error("Not a directory: %s", args.source)
        sys.exit(1)

    organizer = FileOrganizer(
        source=args.source, dest=args.output or args.source,
        strategy=STRATEGIES[args.by], dry_run=args.dry_run,
        recursive=args.recursive, undo_log=args.undo_log,
    )

    stats = organizer.run()
    print(f"\nDone: {stats['moved']} moved, {stats['errors']} errors")
    if args.dry_run:
        print("(Dry run -- no changes made)")


if __name__ == "__main__":
    main()
