#!/usr/bin/env python3
"""Read-only lint for an Agent Skill directory.

Usage:
    python3 validate-skill.py path/to/my-skill [more/skills ...]

Checks only what Anthropic's docs state explicitly (see the skill's references/):
frontmatter presence and field constraints, name/folder agreement, description
limits and third-person phrasing, SKILL.md body length, Windows-style paths,
reference-depth and orphaned bundled files, portable-frontmatter compliance for
claude.ai / Skills API packaging, and the 30 MB upload ceiling.

Never writes, never edits. Exit code 1 if any ERROR was reported, else 0.
"""

import os
import re
import sys

# --- Constraints from the Agent Skills docs -------------------------------
NAME_MAX = 64                  # overview: name max 64 chars
DESC_MAX = 1024                # overview: description max 1024 chars
LISTING_MAX = 1536             # Claude Code: description + when_to_use listing cap
BODY_SOFT_MAX = 500            # best-practices: keep SKILL.md body under 500 lines
UPLOAD_MAX_BYTES = 30 * 1024 * 1024   # skills-guide: 30 MB uncompressed upload limit

NAME_RE = re.compile(r"^[a-z0-9-]+$")
RESERVED = ("anthropic", "claude")
XML_TAG_RE = re.compile(r"<[a-zA-Z/][^>\n]*>")
# Fields accepted by claude.ai uploads / Skills API / package_skill.py
PORTABLE_FIELDS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
FIRST_PERSON_RE = re.compile(r"^\s*(i |i'|you |your |we )", re.IGNORECASE)
# Backslash between two path-ish word chars, e.g. scripts\helper.py
WINPATH_RE = re.compile(r"[\w.)\]]\\[\w.]")


class Report:
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.notes = []

    def error(self, msg):
        self.errors.append(msg)

    def warn(self, msg):
        self.warnings.append(msg)

    def note(self, msg):
        self.notes.append(msg)

    def emit(self, skill_path):
        print(f"\n== {skill_path}")
        for m in self.errors:
            print(f"  ERROR   {m}")
        for m in self.warnings:
            print(f"  WARN    {m}")
        for m in self.notes:
            print(f"  NOTE    {m}")
        if not (self.errors or self.warnings or self.notes):
            print("  OK      no findings")


def split_frontmatter(text):
    """Return (frontmatter_lines, body_lines). Frontmatter is None if absent."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None, lines
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            return lines[1:i], lines[i + 1:]
    return None, lines


def parse_frontmatter(fm_lines):
    """Minimal top-level `key: value` parse. Good enough for lint purposes:
    nested/list values are recorded as present with their raw first-line value."""
    fields = {}
    key = None
    for raw in fm_lines:
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if raw[0] not in " \t-" and ":" in raw:
            key, _, value = raw.partition(":")
            key = key.strip()
            fields[key] = value.strip()
        elif key is not None:
            fields[key] = (fields.get(key, "") + " " + raw.strip()).strip()
    for k, v in list(fields.items()):
        if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
            fields[k] = v[1:-1]
    return fields


def normalize(s):
    """Folder/name comparison is case- and underscore-insensitive per the Skills API."""
    return s.strip().lower().replace("_", "-")


def dir_size(path):
    total = 0
    for root, _dirs, files in os.walk(path):
        for f in files:
            try:
                total += os.path.getsize(os.path.join(root, f))
            except OSError:
                pass
    return total


def check_skill(skill_path, rep):
    skill_md = os.path.join(skill_path, "SKILL.md")
    if not os.path.isfile(skill_md):
        rep.error("no SKILL.md at the top level of the skill directory")
        return

    with open(skill_md, encoding="utf-8") as fh:
        text = fh.read()

    fm_lines, body_lines = split_frontmatter(text)
    if fm_lines is None:
        rep.error("SKILL.md has no YAML frontmatter delimited by --- ... ---")
        return
    fields = parse_frontmatter(fm_lines)

    # --- name ---
    name = fields.get("name")
    folder = os.path.basename(os.path.abspath(skill_path))
    if not name:
        rep.warn("no `name` field; Claude Code defaults to the directory name, "
                 "but the Skills API and claude.ai uploads require it")
        name = ""
    else:
        if len(name) > NAME_MAX:
            rep.error(f"name is {len(name)} chars (max {NAME_MAX})")
        if not NAME_RE.match(name):
            rep.error(f"name '{name}' must be lowercase letters, numbers and hyphens only")
        for word in RESERVED:
            if word in name.lower():
                rep.error(f"name contains the reserved word '{word}'")
        if XML_TAG_RE.search(name):
            rep.error("name contains an XML tag")
        if normalize(name) != normalize(folder):
            rep.error(f"name '{name}' does not match folder '{folder}' "
                      "(Skills API upload requires a match)")

    # --- description ---
    desc = fields.get("description", "")
    if not desc.strip():
        rep.error("description is empty; it is the only text Claude sees before triggering")
    else:
        if len(desc) > DESC_MAX:
            rep.error(f"description is {len(desc)} chars (max {DESC_MAX})")
        if XML_TAG_RE.search(desc):
            rep.error("description contains an XML tag")
        if FIRST_PERSON_RE.match(desc):
            rep.warn("description appears to be first/second person; descriptions are "
                     "injected into the system prompt and must be third person")
        listing_len = len(desc) + len(fields.get("when_to_use", ""))
        if listing_len > LISTING_MAX:
            rep.warn(f"description + when_to_use is {listing_len} chars; the Claude Code "
                     f"skill listing truncates at {LISTING_MAX}")
        if not re.search(r"\b(use|when|trigger)\b", desc, re.IGNORECASE):
            rep.warn("description may not say WHEN to use the skill "
                     "(no 'use'/'when' wording found)")

    # --- portability ---
    extra = sorted(set(fields) - PORTABLE_FIELDS)
    if extra:
        rep.note("Claude-Code-only frontmatter present: " + ", ".join(extra) +
                 " -- claude.ai uploads and the Skills API reject these fields")

    # --- body ---
    n_body = len(body_lines)
    if n_body > BODY_SOFT_MAX:
        rep.warn(f"SKILL.md body is {n_body} lines; keep it under {BODY_SOFT_MAX} "
                 "and push detail into reference files")

    for idx, line in enumerate(body_lines, start=1):
        if line.lstrip().startswith(("|", ">")):
            continue
        if WINPATH_RE.search(line):
            rep.warn(f"line {idx}: possible Windows-style path "
                     "(always use forward slashes)")
            break

    # --- bundled files and reference depth ---
    bundled = []
    for root, _dirs, files in os.walk(skill_path):
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), skill_path).replace(os.sep, "/")
            if rel != "SKILL.md":
                bundled.append(rel)

    body_text = "\n".join(body_lines)
    for rel in bundled:
        if not rel.lower().endswith((".md", ".py", ".sh", ".ps1", ".json", ".yaml", ".yml")):
            continue
        base = os.path.basename(rel)
        if rel not in body_text and base not in body_text:
            rep.warn(f"'{rel}' is not referenced from SKILL.md — keep references one level "
                     "deep and remove or signal unused files")

    size = dir_size(skill_path)
    if size > UPLOAD_MAX_BYTES:
        rep.error(f"skill directory is {size / 1048576:.1f} MB; the Skills API upload "
                  "limit is 30 MB uncompressed")


def main(argv):
    paths = argv[1:]
    if not paths:
        print(__doc__)
        return 2
    failed = False
    for p in paths:
        rep = Report()
        if not os.path.isdir(p):
            rep.error("not a directory")
        else:
            check_skill(p, rep)
        rep.emit(p)
        failed = failed or bool(rep.errors)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

# Sources for every constraint enforced above:
# - https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview
# - https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices
# - https://docs.claude.com/en/docs/build-with-claude/skills-guide
# - https://code.claude.com/docs/en/skills
# Fetched: 2026-08-05
