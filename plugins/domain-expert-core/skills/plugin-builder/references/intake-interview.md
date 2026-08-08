# Intake Interview

The question bank and mechanics for Phase 0. The interview exists to capture intent the repo cannot reveal — read this before asking the user anything, and do not restructure a single file until the interview is written down.

## Mechanics

- Use **AskUserQuestion**: up to 4 questions per call, 2–4 concrete options each, `multiSelect` where choices genuinely coexist. The tool provides a free-text "Other" escape automatically — never add your own.
- Order matters: ask **engagement shape first**. Its answer prunes half the bank, and every later question can reference it.
- Aim for ≤ 2 rounds. Round 1 is the universal set; round 2 is conditioned on round 1's answers. A targeted follow-up at the moment a decision is needed beats a speculative question up front.
- Never ask what the Phase 1 inventory can answer (what exists, how big, what overlaps, what is stale). Never offer an option you would refuse to build.
- If you can confidently infer an answer from the request or the repo, state the inference as a default inside the question's option descriptions rather than asking open-ended — confirmation is cheap, interrogation is not.
- Record everything in `INTERVIEW.md` (schema below): answers verbatim, inferences the user confirmed, and questions deliberately deferred.

## Round 1 — universal (always ask)

1. **Engagement shape.** "What are we doing with this repo?"
   - Remodel: existing loose skills/`.claude/` assets → structured plugin(s)
   - Restructure: existing plugin(s) → marketplace of plugins
   - Greenfield: plan and build a new plugin from scratch
   - Audit-only: propose the architecture, build nothing yet
2. **Audience.** "Who consumes the result?" personal | team | community/public | enterprise-managed. This drives namespacing tolerance, versioning ceremony, and lockdown considerations.
3. **Distribution.** "How does it ship?" marketplace repo | direct git install | skills-dir plugin (no install step) | undecided — recommend from the audience answer and say why.
4. **Definition of done** (multiSelect). reorganized structure only | research-grade content rebuilds where the audit demands | enforcement hooks | external integrations (MCP) | agents per domain.

## Round 2 — conditioned on round 1

**Remodel / restructure engagements:**

- Which parts are sacred (do not touch), and which are expendable? Name candidates from the inventory once it exists; before it exists, ask only if the user hinted at attachments.
- Invocation-name stability: migrating to a plugin renames every skill from `/foo` to `/plugin:foo`. Is breaking muscle memory acceptable, or does anything need a compatibility note in the release?
- Merge appetite: when two skills cover one technology, default to merging with angle-split NOT-clauses, or keep both and disambiguate?

**Marketplace engagements:**

- Domain boundaries: what does the user consider one domain? Offer a draft split as options, not a blank question.
- Per-plugin ownership and versioning: who bumps what, and is a `renames` history needed for anything already published?

**Greenfield engagements:**

- Domain scope and the first 3–5 skills worth shipping (name candidates; multiSelect).
- What exists elsewhere (other repos, gists, docs) that should seed content rather than researching from scratch?

**If "enforcement hooks" was selected:**

- Which behaviors must ALWAYS happen (lint after edit, changelog on release, block a path)? Each named behavior becomes a hook candidate; guidance the model may weigh stays a skill. Frame the distinction in the question so the user self-sorts.

**If "external integrations" was selected:**

- Which systems, and how are credentials handled — `userConfig` prompts at enable time vs environment variables? Check whether an official marketplace integration already covers the system before committing to build one.

## Sizing consent

Research-grade builds are multi-hour skill-builder engagements each. Before the architecture proposes N of them:

- State the count and the expected wall-clock honestly.
- Offer tiers: full rebuild list | top-priority subset now, rest deferred | reorganize-only.
- Record the chosen tier in `INTERVIEW.md`; the Phase 2 proposal must not exceed it without a fresh question.

## When to re-interview

- The user amends scope at sign-off in a way that contradicts a recorded answer → reopen only the affected questions, append a dated delta section.
- Inventory reveals something that invalidates an answer's premise (e.g. "keep everything" but half the skills are abandoned) → present the evidence and re-ask that one question.
- A new repo or asset source appears mid-engagement → run round 1's shape question against it before folding it in.

## INTERVIEW.md schema

```markdown
# Interview: <target>
Date: <YYYY-MM-DD>

## Round 1
Q: <question as asked>
A: <answer verbatim, including Other free-text>

## Round 2 — <engagement shape>
Q: ...
A: ...

## Inferred and confirmed
- <fact> (inferred from <source>, confirmed <date>)

## Sizing consent
- <tier chosen>: <N> full builds, <M> refreshes, rest deferred

## Deferred
- <question> — ask before Phase <n>

## Deltas
- <date>: <question reopened> — <new answer> (reason)
```

## Sources

Derived from this repository's conventions (CLAUDE.md, the skill-builder pipeline, the marketplace restructuring of 2026-07/08) and the AskUserQuestion tool contract; no external documents fetched.
