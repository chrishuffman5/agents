#!/usr/bin/env python3
"""Read-only linter for a plugin's evals/trigger-evals.json trigger-eval suite.

Checks the coverage invariants that Anthropic's Skill-governance guidance calls for:
every Skill needs cases where it SHOULD trigger and cases where it should NOT, and
the negative cases must be genuine near-misses rather than restatements.

Usage:
    python lint-trigger-evals.py <path-to-plugin-dir>

Exit codes: 0 = clean, 1 = findings, 2 = could not run (bad path / bad JSON).
Writes nothing; only reads the plugin directory.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

# Anthropic's enterprise guidance: 3-5 representative queries per Skill covering
# should-trigger, should-not-trigger, and ambiguous edge cases. This marketplace's
# floor is one of each; warn above 5 as over-specified.
MIN_POSITIVE = 1
MIN_NEGATIVE = 1
RECOMMENDED_MAX_PER_SKILL = 5

# Two prompts sharing this fraction of content words are treated as duplicates:
# they cannot be measuring different routing behavior.
NEAR_DUPLICATE_JACCARD = 0.8

STOPWORDS = {
    "a", "an", "and", "are", "as", "at", "be", "but", "by", "can", "do", "does",
    "for", "from", "how", "i", "in", "is", "it", "me", "my", "of", "on", "or",
    "our", "should", "so", "that", "the", "then", "there", "this", "to", "us",
    "we", "what", "when", "where", "which", "why", "with", "you", "your",
}


def tokenize(text: str) -> set[str]:
    words = re.findall(r"[a-z0-9]+", text.lower())
    return {w for w in words if w not in STOPWORDS and len(w) > 2}


def jaccard(a: set[str], b: set[str]) -> float:
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__.strip())
        return 2

    plugin_dir = Path(argv[1]).resolve()
    evals_path = plugin_dir / "evals" / "trigger-evals.json"
    skills_dir = plugin_dir / "skills"

    if not evals_path.is_file():
        print(f"ERROR: no trigger-eval file at {evals_path}")
        return 2

    try:
        suite = json.loads(evals_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"ERROR: {evals_path} is not valid JSON: {exc}")
        return 2

    cases = suite.get("cases")
    if not isinstance(cases, list) or not cases:
        print(f"ERROR: {evals_path} has no non-empty 'cases' array")
        return 2

    on_disk = (
        {p.name for p in skills_dir.iterdir() if (p / "SKILL.md").is_file()}
        if skills_dir.is_dir()
        else set()
    )

    findings: list[str] = []
    positives: dict[str, int] = {}
    negatives: dict[str, int] = {}
    seen_ids: set[str] = set()
    prompts: list[tuple[str, str, set[str]]] = []  # (case id, skill, tokens)

    for index, case in enumerate(cases):
        label = case.get("id") or f"cases[{index}]"

        skill = case.get("skill")
        if not skill:
            findings.append(f"{label}: missing 'skill'")
        elif on_disk and skill not in on_disk:
            findings.append(f"{label}: references skill '{skill}' with no skills/{skill}/SKILL.md")

        if label in seen_ids:
            findings.append(f"{label}: duplicate case id")
        seen_ids.add(label)

        prompt = case.get("prompt", "")
        if not isinstance(prompt, str) or len(prompt.strip()) < 20:
            findings.append(f"{label}: prompt missing or too short to be a realistic request")
            continue

        should = case.get("should_trigger")
        if not isinstance(should, bool):
            findings.append(f"{label}: 'should_trigger' must be true or false")
        elif skill:
            bucket = positives if should else negatives
            bucket[skill] = bucket.get(skill, 0) + 1

        tokens = tokenize(prompt)
        for other_label, other_skill, other_tokens in prompts:
            score = jaccard(tokens, other_tokens)
            if score >= NEAR_DUPLICATE_JACCARD:
                findings.append(
                    f"{label}: prompt is {score:.0%} identical to {other_label} "
                    f"(skill '{other_skill}') -- not an independent test case"
                )
        prompts.append((label, skill or "?", tokens))

    covered = set(positives) | set(negatives)
    for skill in sorted(covered | on_disk):
        pos = positives.get(skill, 0)
        neg = negatives.get(skill, 0)
        if skill in on_disk and skill not in covered:
            findings.append(f"skill '{skill}': on disk but has no trigger-eval cases")
            continue
        if pos < MIN_POSITIVE:
            findings.append(f"skill '{skill}': no positive (should_trigger=true) case")
        if neg < MIN_NEGATIVE:
            findings.append(
                f"skill '{skill}': no near-miss negative case -- nothing detects an over-broad description"
            )
        if pos + neg > RECOMMENDED_MAX_PER_SKILL:
            findings.append(
                f"skill '{skill}': {pos + neg} cases exceeds the recommended 3-5 per skill"
            )

    print(f"plugin:  {plugin_dir.name}")
    print(f"suite:   {evals_path}")
    print(f"cases:   {len(cases)}  skills covered: {len(covered)}  skills on disk: {len(on_disk)}")
    print()

    if not findings:
        print("OK - every skill has at least one positive and one near-miss negative case.")
        return 0

    print(f"{len(findings)} finding(s):")
    for finding in findings:
        print(f"  - {finding}")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))

# Sources
# - https://platform.claude.com/docs/en/agents-and-tools/agent-skills/enterprise
#   (3-5 representative queries per Skill: should-trigger, should-not-trigger, ambiguous)
# - https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
#   (phrase trigger tests in your own words, not the description's wording)
# - https://developers.openai.com/blog/eval-skills
#   (prompt-set construction: explicit / implicit / contextual invocation + negative controls)
# Fetched: 2026-08-05
