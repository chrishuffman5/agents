#!/usr/bin/env python3
"""Validate a Claude Code subagent .md file for common mistakes."""

import sys
import re
from pathlib import Path

VALID_TOOLS = {
    "Read", "Write", "Edit", "MultiEdit", "Glob", "Grep", "Bash",
    "Agent", "WebFetch", "TodoRead", "TodoWrite", "AskUserQuestion", "Skill"
}

VALID_MODELS = {"sonnet", "opus", "haiku", "inherit"}

VALID_PERMISSION_MODES = {
    "default", "acceptEdits", "auto", "dontAsk", "bypassPermissions", "plan"
}

VALID_MEMORY = {"user", "project", "local"}

VALID_COLORS = {"red", "blue", "green", "yellow", "purple", "orange", "pink", "cyan"}

VALID_EFFORT = {"low", "medium", "high", "max"}

SUPPORTED_FIELDS = {
    "name", "description", "tools", "disallowedTools", "model",
    "permissionMode", "maxTurns", "skills", "mcpServers", "hooks",
    "memory", "background", "effort", "isolation", "color", "initialPrompt"
}

INVALID_FIELDS = {
    "type", "capabilities", "workflow", "domains", "persona", "license",
    "metadata", "version", "author", "role"
}


def validate_agent(filepath: str) -> tuple[bool, list[str]]:
    """Validate an agent file. Returns (is_valid, list_of_issues)."""
    path = Path(filepath)
    issues = []
    warnings = []

    # Check file exists and extension
    if not path.exists():
        return False, [f"File not found: {filepath}"]

    if path.suffix != ".md":
        issues.append(f"File extension should be .md, got: {path.suffix}")

    # Check location
    parts = path.parts
    if "skills" in parts:
        issues.append("Agent file is inside a 'skills' directory. Agents belong in .claude/agents/ not .claude/skills/")

    if path.name == "ROLE.md":
        issues.append("ROLE.md is not a Claude Code convention. Use {agent-name}.md")

    if path.name == "AGENT.md":
        warnings.append("AGENT.md works but the convention is just {agent-name}.md")

    content = path.read_text(encoding="utf-8")

    # Check frontmatter exists
    fm_match = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
    if not fm_match:
        issues.append("Missing YAML frontmatter (must start with --- and end with ---)")
        return len(issues) == 0, issues + warnings

    frontmatter = fm_match.group(1)
    body = content[fm_match.end():]

    # Check required fields
    if not re.search(r'^name\s*:', frontmatter, re.MULTILINE):
        issues.append("Missing required field: name")

    if not re.search(r'^description\s*:', frontmatter, re.MULTILINE):
        issues.append("Missing required field: description")

    # Check name format
    name_match = re.search(r'^name\s*:\s*(.+)$', frontmatter, re.MULTILINE)
    if name_match:
        name = name_match.group(1).strip().strip('"').strip("'")
        if not re.match(r'^[a-z][a-z0-9-]*$', name):
            issues.append(f"name '{name}' should be lowercase letters, numbers, and hyphens only")

    # Check for invalid/invented fields
    field_names = re.findall(r'^([a-zA-Z_]+)\s*:', frontmatter, re.MULTILINE)
    for field in field_names:
        if field in INVALID_FIELDS:
            issues.append(f"'{field}' is not a valid subagent frontmatter field. Supported: {', '.join(sorted(SUPPORTED_FIELDS))}")
        elif field not in SUPPORTED_FIELDS:
            warnings.append(f"Unknown field '{field}' — verify it's supported. Known fields: {', '.join(sorted(SUPPORTED_FIELDS))}")

    # Check model value
    model_match = re.search(r'^model\s*:\s*(.+)$', frontmatter, re.MULTILINE)
    if model_match:
        model = model_match.group(1).strip().strip('"').strip("'")
        if model not in VALID_MODELS and not model.startswith("claude-"):
            warnings.append(f"model '{model}' — expected one of: {', '.join(sorted(VALID_MODELS))}, or a full model ID like 'claude-sonnet-4-6'")

    # Check memory value
    memory_match = re.search(r'^memory\s*:\s*(.+)$', frontmatter, re.MULTILINE)
    if memory_match:
        memory = memory_match.group(1).strip().strip('"').strip("'")
        if memory not in VALID_MEMORY:
            issues.append(f"memory '{memory}' is invalid. Must be one of: {', '.join(sorted(VALID_MEMORY))}")

    # Check effort value
    effort_match = re.search(r'^effort\s*:\s*(.+)$', frontmatter, re.MULTILINE)
    if effort_match:
        effort = effort_match.group(1).strip().strip('"').strip("'")
        if effort not in VALID_EFFORT:
            issues.append(f"effort '{effort}' is invalid. Must be one of: {', '.join(sorted(VALID_EFFORT))}")

    # Check color value
    color_match = re.search(r'^color\s*:\s*(.+)$', frontmatter, re.MULTILINE)
    if color_match:
        color = color_match.group(1).strip().strip('"').strip("'")
        if color not in VALID_COLORS:
            issues.append(f"color '{color}' is invalid. Must be one of: {', '.join(sorted(VALID_COLORS))}")

    # Check tools for valid names
    tools_match = re.search(r'^tools\s*:\s*(.+)$', frontmatter, re.MULTILINE)
    if tools_match:
        tools_str = tools_match.group(1).strip()
        tools = [t.strip() for t in tools_str.split(",")]
        for tool in tools:
            base_tool = re.match(r'^(\w+)', tool)
            if base_tool and base_tool.group(1) not in VALID_TOOLS and not tool.startswith("mcp__"):
                warnings.append(f"Tool '{tool}' not in known built-in tools. If it's an MCP tool, prefix with mcp__")

    # Check body has content
    if len(body.strip()) < 20:
        warnings.append("System prompt body is very short. The agent receives ONLY this as its instructions.")

    # Check description quality
    desc_match = re.search(r'^description\s*:\s*["\']?(.*?)["\']?\s*$', frontmatter, re.MULTILINE)
    if desc_match:
        desc = desc_match.group(1)
        if len(desc) < 20:
            warnings.append("Description is very short. Claude uses this to decide when to delegate — be specific about trigger conditions.")

    # Format output
    all_issues = []
    for issue in issues:
        all_issues.append(f"ERROR: {issue}")
    for warning in warnings:
        all_issues.append(f"WARNING: {warning}")

    if not issues and not warnings:
        all_issues.append("PASS: Agent file is valid")
    elif not issues:
        all_issues.insert(0, "PASS with warnings:")
    else:
        all_issues.insert(0, "FAIL:")

    return len(issues) == 0, all_issues


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python validate_agent.py <path-to-agent.md>")
        sys.exit(1)

    is_valid, messages = validate_agent(sys.argv[1])
    for msg in messages:
        print(msg)
    sys.exit(0 if is_valid else 1)
