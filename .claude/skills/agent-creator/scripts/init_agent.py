#!/usr/bin/env python3
"""Scaffold a new Claude Code subagent .md file with valid frontmatter."""

import argparse
import sys
from pathlib import Path


TEMPLATE = '''---
name: {name}
description: "{description}"
tools: {tools}
model: {model}
---

{body}
'''

TEMPLATE_MINIMAL = '''---
name: {name}
description: "{description}"
---

{body}
'''


def init_agent(
    name: str,
    description: str = "",
    scope: str = "project",
    tools: str = "",
    model: str = "",
    body: str = "",
) -> Path:
    """Create a new agent .md file in the appropriate directory."""

    # Determine output directory
    if scope == "user":
        base = Path.home() / ".claude" / "agents"
    else:
        base = Path(".claude") / "agents"

    base.mkdir(parents=True, exist_ok=True)
    filepath = base / f"{name}.md"

    if filepath.exists():
        print(f"Agent file already exists: {filepath}")
        print("Use --force to overwrite")
        return filepath

    # Use minimal template if no optional fields
    if not tools and not model:
        content = TEMPLATE_MINIMAL.format(
            name=name,
            description=description or f"Specialist for {name.replace('-', ' ')} tasks.",
            body=body or f"You are a {name.replace('-', ' ')} specialist.\n\nWhen invoked:\n1. Understand the task\n2. Gather relevant context\n3. Produce a clear, actionable result\n",
        )
    else:
        content = TEMPLATE.format(
            name=name,
            description=description or f"Specialist for {name.replace('-', ' ')} tasks.",
            tools=tools or "Read, Grep, Glob, Bash",
            model=model or "sonnet",
            body=body or f"You are a {name.replace('-', ' ')} specialist.\n\nWhen invoked:\n1. Understand the task\n2. Gather relevant context\n3. Produce a clear, actionable result\n",
        )

    filepath.write_text(content, encoding="utf-8")
    print(f"Created agent: {filepath}")
    print(f"  Name: {name}")
    print(f"  Scope: {scope}")
    print(f"  Next: Edit the file to customize the system prompt, then run /agents in Claude Code")
    return filepath


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Scaffold a Claude Code subagent")
    parser.add_argument("name", help="Agent name (lowercase-kebab-case)")
    parser.add_argument("--description", "-d", default="", help="When to use this agent")
    parser.add_argument("--scope", "-s", choices=["project", "user"], default="project", help="project (.claude/agents/) or user (~/.claude/agents/)")
    parser.add_argument("--tools", "-t", default="", help="Comma-separated tool list")
    parser.add_argument("--model", "-m", default="", help="Model: sonnet, opus, haiku, inherit")
    parser.add_argument("--force", "-f", action="store_true", help="Overwrite existing file")

    args = parser.parse_args()
    init_agent(args.name, args.description, args.scope, args.tools, args.model)
