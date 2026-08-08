#!/usr/bin/env python3
"""Deterministic audit of a marketplace skill directory.

Usage:  python audit_skill.py <path-to-skill-dir> [more skill dirs...]

Checks the conventions enforced by this repository (CLAUDE.md + skill-builder):
frontmatter fields, name/folder match, body line budget, description budget,
references presence, nested-SKILL.md violations, and Sources/Fetched footers.

Exit code 0 = no failures (warnings allowed), 1 = at least one failure.
Stdlib only; no PyYAML dependency.

Intended for technology skills produced from a fetched-documentation corpus;
process/meta skills derived from repo conventions rather than web research will
legitimately fail the Sources/Fetched checks -- that is a judgment call, not a bug.
"""

import re
import sys
from pathlib import Path

BODY_TARGET = (200, 500)
BODY_HARD_MAX = 1000
DESC_SOFT = 900     # repo p90 is ~890 chars
DESC_CEILING = 1500


def parse_frontmatter(text):
    """Return (dict, body_text) or (None, None) if no frontmatter block."""
    m = re.match(r"\A---\r?\n(.*?)\r?\n---\r?\n(.*)\Z", text, re.S)
    if not m:
        return None, None
    block, body = m.group(1), m.group(2)
    fields = {}
    key = None
    for line in block.splitlines():
        km = re.match(r"^([A-Za-z_-]+):\s*(.*)$", line)
        if km:
            key = km.group(1)
            fields[key] = km.group(2).strip()
        elif key and line.startswith((" ", "\t")):  # folded continuation line
            fields[key] += " " + line.strip()
    for k, v in fields.items():
        if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
            fields[k] = v[1:-1].replace('\\"', '"')
    return fields, body


def audit(skill_dir):
    skill_dir = Path(skill_dir).resolve()
    fails, warns = [], []
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        return [f"no SKILL.md in {skill_dir}"], []

    text = skill_md.read_text(encoding="utf-8")
    fields, body = parse_frontmatter(text)
    if fields is None:
        fails.append("SKILL.md has no ---frontmatter--- block")
        body = text
        fields = {}

    name = fields.get("name")
    if not name:
        fails.append("frontmatter missing `name`")
    elif name != skill_dir.name:
        fails.append(f"frontmatter name `{name}` != folder name `{skill_dir.name}`")
    if fields.get("license") != "MIT":
        fails.append(f"frontmatter license is `{fields.get('license')}`, expected `MIT`")

    desc = fields.get("description", "")
    if not desc:
        fails.append("frontmatter missing `description`")
    else:
        n = len(desc)
        if n > DESC_CEILING:
            warns.append(f"description {n} chars -- over the {DESC_CEILING} ceiling; trim unless overlap disambiguation truly demands it")
        elif n > DESC_SOFT:
            warns.append(f"description {n} chars -- over the ~{DESC_SOFT} soft budget (repo p90)")
        if not re.search(r"\bNOT\b", desc) and not re.search(r"[Dd]o not use", desc):
            warns.append("description has no `Do NOT use` clause -- required if any overlapping skill exists")

    body_lines = len(body.splitlines())
    if body_lines > BODY_HARD_MAX:
        fails.append(f"body is {body_lines} lines -- hard max is {BODY_HARD_MAX}")
    elif not (BODY_TARGET[0] <= body_lines <= BODY_TARGET[1]):
        warns.append(f"body is {body_lines} lines -- target is {BODY_TARGET[0]}-{BODY_TARGET[1]}")

    refs = sorted((skill_dir / "references").glob("**/*.md")) if (skill_dir / "references").is_dir() else []
    if not refs:
        fails.append("no references/*.md -- every skill ships at least one reference file")

    for nested in skill_dir.glob("**/SKILL.md"):
        if nested != skill_md:
            fails.append(f"nested SKILL.md at {nested.relative_to(skill_dir)} -- version/depth content belongs in references/")

    def has_sources_footer(t):
        return re.search(r"^## Sources\b", t, re.M) and re.search(r"^Fetched:\s*\d{4}-\d{2}-\d{2}", t, re.M)

    if not has_sources_footer(text):
        fails.append("SKILL.md missing `## Sources` + `Fetched: YYYY-MM-DD` footer")
    for ref in refs:
        rt = ref.read_text(encoding="utf-8")
        rel = ref.relative_to(skill_dir)
        if not has_sources_footer(rt):
            fails.append(f"{rel} missing `## Sources` + `Fetched: YYYY-MM-DD` footer")
        if "> Source:" not in rt:
            warns.append(f"{rel} has no per-section `> Source:` lines")

    return fails, warns


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    any_fail = False
    for target in argv:
        fails, warns = audit(target)
        print(f"\n=== {target} ===")
        for f in fails:
            print(f"  FAIL  {f}")
        for w in warns:
            print(f"  warn  {w}")
        if not fails and not warns:
            print("  clean")
        any_fail |= bool(fails)
    return 1 if any_fail else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
