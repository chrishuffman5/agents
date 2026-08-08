#!/usr/bin/env python3
"""Deterministic census of Claude Code assets in a repository.

Usage:  python inventory_repo.py <repo-root> [--summary]

Finds skills, commands, agents, hooks, MCP/LSP configs, monitors, plugin and
marketplace manifests; reports per-skill vitals and structural issues
(components inside .claude-plugin/, nested SKILL.md files, malformed JSON,
agent-override collisions, missing descriptions/versions). Read-only; stdlib only.

Full markdown report to stdout — redirect into remodel/<target>/INVENTORY.md.
--summary prints only the counts table and ISSUE lines (what the orchestrator
reads); the full report is for auditor agents.
"""

import json
import re
import sys
from pathlib import Path

SKIP_DIRS = {".git", "node_modules", ".venv", "venv", "__pycache__",
             "remodel", "research", "dist", "build", ".next"}


def parse_frontmatter(text):
    m = re.match(r"\A---\r?\n(.*?)\r?\n---\r?\n(.*)\Z", text, re.S)
    if not m:
        return {}, text
    fields, key = {}, None
    for line in m.group(1).splitlines():
        km = re.match(r"^([A-Za-z_-]+):\s*(.*)$", line)
        if km:
            key = km.group(1)
            fields[key] = km.group(2).strip()
        elif key and line.startswith((" ", "\t")):
            fields[key] += " " + line.strip()
    for k, v in fields.items():
        if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
            fields[k] = v[1:-1].replace('\\"', '"')
    return fields, m.group(2)


def walk(root):
    for p in sorted(root.rglob("*")):
        if any(part in SKIP_DIRS for part in p.parts):
            continue
        yield p


def load_json(path, issues):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as e:
        issues.append(f"{path}: malformed JSON ({e.__class__.__name__}) -- "
                      "a malformed hooks.json blocks its entire plugin from loading")
        return None


def classify_skill(rel):
    parts = rel.parts
    if ".claude" in parts:
        return "standalone (.claude)"
    if "skills" in parts:
        return "plugin skill" if ".claude-plugin" not in parts else "MISPLACED"
    if "commands" in parts:
        return "command-adjacent"
    return "stray"


def inventory(root):
    root = Path(root).resolve()
    issues, skills, agents, commands = [], [], [], []
    manifests, marketplaces, hook_files, server_files, monitor_files, bins = [], [], [], [], [], []

    for p in walk(root):
        rel = p.relative_to(root)
        parts = rel.parts

        if ".claude-plugin" in parts and p.is_dir() and p.name != ".claude-plugin":
            issues.append(f"{rel}: component directory inside .claude-plugin/ -- "
                          "only plugin.json belongs there; everything else silently fails to load")

        if p.name == "SKILL.md":
            fields, body = parse_frontmatter(p.read_text(encoding="utf-8", errors="replace"))
            folder = p.parent.name
            name = fields.get("name", "")
            desc = fields.get("description", "")
            skills.append({
                "path": rel, "folder": folder, "name": name,
                "desc_len": len(desc), "body_lines": len(body.splitlines()),
                "refs": (p.parent / "references").is_dir(),
                "scripts": (p.parent / "scripts").is_dir(),
                "not_clause": bool(re.search(r"\bNOT\b|[Dd]o not use", desc)),
                "kind": classify_skill(rel),
            })
            if name and name != folder:
                issues.append(f"{rel}: frontmatter name `{name}` != folder `{folder}`")
            if not desc:
                issues.append(f"{rel}: missing frontmatter description (skill cannot trigger)")
            for nested in p.parent.rglob("SKILL.md"):
                if nested != p:
                    issues.append(f"{rel}: nested SKILL.md at "
                                  f"{nested.relative_to(p.parent)} -- belongs in references/")
        elif p.name == "plugin.json" and p.parent.name == ".claude-plugin":
            data = load_json(p, issues)
            if data is not None:
                manifests.append({"path": rel, "name": data.get("name", "?"),
                                  "version": data.get("version")})
                if not data.get("name"):
                    issues.append(f"{rel}: plugin.json missing `name` (the only required field)")
        elif p.name == "marketplace.json" and p.parent.name == ".claude-plugin":
            data = load_json(p, issues)
            if data is not None:
                marketplaces.append({"path": rel,
                                     "plugins": len(data.get("plugins", [])),
                                     "renames": len(data.get("renames", {}))})
                if (data.get("metadata") or {}).get("pluginRoot"):
                    issues.append(f"{rel}: metadata.pluginRoot is set -- hosts that honor it "
                                  "double-resolve plugin paths; use full ./ sources instead")
        elif p.suffix == ".md" and "agents" in parts and p.is_file():
            fields, _ = parse_frontmatter(p.read_text(encoding="utf-8", errors="replace"))
            agents.append({"path": rel, "name": fields.get("name", p.stem),
                           "scope": ".claude" if ".claude" in parts else "plugin"})
        elif p.suffix == ".md" and "commands" in parts and p.is_file() and "skills" not in parts:
            commands.append(rel)
        elif p.name == "hooks.json":
            load_json(p, issues)
            hook_files.append(rel)
        elif p.name == "settings.json" and ".claude" in parts:
            data = load_json(p, issues)
            if data and data.get("hooks"):
                hook_files.append(rel)
        elif p.name in (".mcp.json", ".lsp.json"):
            load_json(p, issues)
            server_files.append(rel)
        elif p.name == "monitors.json":
            load_json(p, issues)
            monitor_files.append(rel)
        elif "bin" in parts and p.is_file():
            bins.append(rel)

    by_name = {}
    for a in agents:
        by_name.setdefault(a["name"], set()).add(a["scope"])
    for name, scopes in sorted(by_name.items()):
        if {"plugin", ".claude"} <= scopes:
            issues.append(f"agent `{name}` exists in both .claude/agents/ and a plugin -- "
                          "the .claude copy overrides; the plugin copy is dead code until it is removed")

    if not (root / ".git").exists():
        issues.append(f"{root}: not a git repository -- require version control before restructuring")

    return {"root": root, "skills": skills, "agents": agents, "commands": commands,
            "manifests": manifests, "marketplaces": marketplaces, "hooks": hook_files,
            "servers": server_files, "monitors": monitor_files, "bins": bins, "issues": issues}


def report(inv, summary_only=False):
    out = []
    out.append(f"# Inventory: {inv['root'].name}\n")
    out.append("## Summary\n")
    out.append("| Asset | Count |\n|---|---|")
    for label, key in [("Skills (SKILL.md)", "skills"), ("Agents", "agents"),
                       ("Commands (flat .md)", "commands"), ("Plugin manifests", "manifests"),
                       ("Marketplace catalogs", "marketplaces"), ("Hook configs", "hooks"),
                       ("MCP/LSP configs", "servers"), ("Monitor configs", "monitors"),
                       ("bin/ executables", "bins")]:
        out.append(f"| {label} | {len(inv[key])} |")
    out.append("")

    if inv["issues"]:
        out.append("## Issues\n")
        out.extend(f"- ISSUE: {i}" for i in inv["issues"])
        out.append("")
    else:
        out.append("## Issues\n\nnone found\n")

    if summary_only:
        return "\n".join(out)

    if inv["skills"]:
        out.append("## Skills\n")
        out.append("| Path | Kind | Body lines | Desc chars | NOT-clause | refs/ | scripts/ |")
        out.append("|---|---|---|---|---|---|---|")
        for s in inv["skills"]:
            out.append(f"| {s['path']} | {s['kind']} | {s['body_lines']} | {s['desc_len']} | "
                       f"{'yes' if s['not_clause'] else 'no'} | "
                       f"{'yes' if s['refs'] else 'no'} | {'yes' if s['scripts'] else 'no'} |")
        out.append("")
    if inv["agents"]:
        out.append("## Agents\n")
        out.extend(f"- {a['path']}  (name: {a['name']}, scope: {a['scope']})" for a in inv["agents"])
        out.append("")
    if inv["commands"]:
        out.append("## Commands (migrate to skills/ during remodel)\n")
        out.extend(f"- {c}" for c in inv["commands"])
        out.append("")
    for label, key, fmt in [("Plugin manifests", "manifests", None),
                            ("Marketplace catalogs", "marketplaces", None)]:
        if inv[key]:
            out.append(f"## {label}\n")
            for m in inv[key]:
                if key == "manifests":
                    v = m["version"] or "(unversioned -- commit-SHA flow)"
                    out.append(f"- {m['path']}  name={m['name']}  version={v}")
                else:
                    out.append(f"- {m['path']}  plugins={m['plugins']}  renames={m['renames']}")
            out.append("")
    for label, key in [("Hook configs", "hooks"), ("MCP/LSP configs", "servers"),
                       ("Monitor configs", "monitors"), ("bin/ executables", "bins")]:
        if inv[key]:
            out.append(f"## {label}\n")
            out.extend(f"- {p}" for p in inv[key])
            out.append("")
    return "\n".join(out)


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    if not args:
        print(__doc__)
        return 1
    inv = inventory(args[0])
    print(report(inv, summary_only="--summary" in argv))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
