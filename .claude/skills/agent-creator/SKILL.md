---
name: agent-creator
description: "Create specialized IT domain agents following Anthropic's agent design patterns with domain/technology/version hierarchy (e.g., database > SQL Server > SQL Server 2022). WHEN: \"create agent\", \"new agent\", \"build agent\", \"database agent\", \"SQL Server agent\", \"agent for postgres\", \"domain expert\", \"specialist agent\", \"scaffold agent\", \"version-specific agent\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Agent Creator

Create specialized IT domain agents that follow Anthropic's effective agent design patterns and are organized in a hierarchical domain/technology/version structure.

The core idea: rather than building one monolithic agent that tries to know everything, you build narrowly focused agents that are genuine experts in their specific domain. A SQL Server 2022 agent knows the quirks of that exact version — its query optimizer behaviors, new features, deprecated syntax, and common pitfalls — in a way that a generic "database agent" never could.

## The Domain Specialization Hierarchy

Agents are organized in three layers, each inheriting from and extending its parent:

```
domain/                        # Broad IT domain (database, networking, security, cloud...)
├── AGENT.md                   # Domain-level expertise shared by all children
├── references/                # Cross-technology knowledge
│   └── concepts.md            # Foundational concepts for the domain
│
├── technology/                # Specific technology (sql-server, postgresql, oracle...)
│   ├── AGENT.md               # Technology-level expertise
│   ├── references/            # Technology-wide documentation
│   │   ├── architecture.md    # How this technology works internally
│   │   └── best-practices.md  # Cross-version best practices
│   │
│   └── version/               # Specific version (2019, 2022, 2025...)
│       ├── AGENT.md           # Version-specific expertise
│       └── references/        # Version-specific documentation
│           ├── features.md    # New/changed features in this version
│           ├── migration.md   # Migration guide from previous version
│           └── known-issues.md# Known bugs, limitations, workarounds
```

### Why this hierarchy matters

Each layer serves a distinct purpose:

- **Domain layer** — Concepts that transcend any single technology. For databases: normalization theory, indexing strategies, transaction isolation levels, backup/recovery principles. An agent at this layer can reason about trade-offs between technologies and recommend the right tool for the job.

- **Technology layer** — How a specific technology implements those concepts. For PostgreSQL: MVCC implementation details, VACUUM behavior, extension ecosystem, pg_stat views for diagnostics. An agent at this layer is your go-to expert for that technology across all its versions.

- **Version layer** — What changed in this exact release. For PostgreSQL 17: incremental backup support, new JSON_TABLE function, improved MERGE command. An agent at this layer catches version-specific gotchas that even experienced engineers miss.

When a user asks a question, the version agent draws on all three layers — foundational concepts from the domain, technology-specific implementation details, and version-specific behaviors. The instructions in AGENT.md at each level tell the agent how to compose this knowledge.

## How to Use This Skill

Your job is to figure out where the user is in the agent creation process and help them progress. Maybe they want a new agent from scratch, or they want to add version-specific knowledge to an existing technology agent. Be flexible.

The high-level workflow:

1. **Capture intent** — What domain, technology, and version?
2. **Research** — Gather deep domain knowledge
3. **Draft the agent** — Write AGENT.md and supporting files
4. **Test** — Run realistic scenarios against the agent
5. **Evaluate and iterate** — Improve based on test results
6. **Deploy** — Install the agent into the project

---

## Step 1: Capture Intent

Start by understanding what the user needs. Key questions:

1. **What domain?** (database, networking, security, cloud, DevOps, monitoring, etc.)
2. **What technology?** (SQL Server, PostgreSQL, Oracle, Cisco IOS, AWS, etc.)
3. **What version(s)?** (SQL Server 2022, PostgreSQL 17, Oracle 19c, etc.)
4. **What's the primary use case?** (troubleshooting, migration, optimization, administration, development)
5. **What expertise level should the agent target?** (junior DBA guidance, senior engineer peer, architect-level analysis)

If the user already specified these in the conversation, extract answers and confirm. Don't re-ask what's already been stated.

Also determine which **layer** to create:
- **Just the domain?** — When creating a new domain from scratch
- **A technology within an existing domain?** — When adding a new technology
- **A version within an existing technology?** — When adding version specificity
- **The full stack?** — Domain + technology + version in one go

---

## Step 2: Research

Before writing agent instructions, you need deep domain knowledge. This is where the quality of your agent is determined — shallow research produces shallow agents.

### Research checklist

For the **domain layer**:
- Core concepts and terminology
- Common architectural patterns
- Industry standards and compliance requirements
- Cross-technology evaluation criteria

For the **technology layer**:
- Internal architecture and execution model
- Configuration and tuning parameters
- Diagnostic and monitoring capabilities
- Ecosystem (extensions, tools, integrations)
- Common failure modes and troubleshooting approaches
- Security model and hardening practices

For the **version layer**:
- New features introduced in this version
- Breaking changes from the previous version
- Deprecated features and migration paths
- Known issues and workarounds
- Performance characteristics vs. previous versions
- End-of-life / support lifecycle status

### Research sources

Use available tools to gather information:
- **Web search** for official documentation, release notes, changelogs
- **Existing project files** for patterns and conventions already in use
- **The user** — they often have deep tacit knowledge. Ask targeted questions.

Save raw research to `{workspace}/research/` for reference during drafting.

---

## Step 3: Draft the Agent

### Agent File Structure

Each agent is implemented as a skill (SKILL.md). Here is the anatomy:

```
agent-name/
├── SKILL.md                    # Main agent instructions (required)
├── references/                 # Deep knowledge files (loaded as needed)
│   ├── architecture.md         # How the technology works
│   ├── diagnostics.md          # Troubleshooting playbook
│   ├── features.md             # Feature reference
│   ├── best-practices.md       # Do's and don'ts
│   └── migration.md            # Migration/upgrade guidance
├── scripts/                    # Deterministic utilities (optional)
│   ├── health_check.py         # Automated health assessment
│   └── config_validator.py     # Configuration validation
└── playbooks/                  # Step-by-step task guides (optional)
    ├── backup-restore.md       # Backup and recovery procedures
    └── performance-tuning.md   # Performance optimization workflow
```

### Writing the AGENT.md (SKILL.md)

The AGENT.md file is a SKILL.md — it uses the same YAML frontmatter and markdown body that all Claude Code skills use. The structure:

#### Frontmatter

```yaml
---
name: {domain}-{technology}-{version}
description: "Expert agent for {Technology} {Version}. Provides deep expertise in {key capabilities}. Use when working with {Technology} {Version} for {primary use cases}. WHEN: \"{technology} {version}\", \"{common task phrases}\", \"{diagnostic phrases}\"."
---
```

Naming convention: `{domain}-{technology}-{version}`, all lowercase, hyphens for separators.
Examples: `database-sql-server-2022`, `database-postgresql-17`, `networking-cisco-ios-xe-17`

#### Body Structure

Write the body following these principles from Anthropic's agent design guidance:

**1. Start with identity and scope**

Tell the agent who it is and what it knows. This grounds its responses:

```markdown
# {Technology} {Version} Expert

You are a specialist in {Technology} {Version}. You have deep knowledge of:
- {key area 1}
- {key area 2}
- {key area 3}

Your expertise covers {Technology} {Version} specifically. When questions
involve features or behaviors from other versions, note the version
differences explicitly.
```

**2. Define the agent's approach using Anthropic patterns**

Choose the right pattern based on what the agent does. See `references/anthropic-patterns.md` for the full catalog. Common choices for IT domain agents:

- **Routing** — When the agent handles diverse request types (troubleshooting vs. optimization vs. migration). Route to the right playbook or reference.
- **Prompt chaining** — When tasks have natural sequential steps (diagnose → analyze → recommend → implement).
- **Orchestrator-worker** — When the agent coordinates multiple sub-tasks (check configs, review logs, assess performance, synthesize findings).

```markdown
## How to approach tasks

When you receive a request:

1. **Classify** — Is this troubleshooting, optimization, migration,
   administration, or development guidance?
2. **Load context** — Read the relevant reference file for deep knowledge
   (see Reference Files section below)
3. **Analyze** — Apply {Technology}-specific reasoning, not generic advice
4. **Recommend** — Provide version-specific, actionable guidance
5. **Verify** — When possible, suggest validation steps
```

**3. Encode domain expertise directly**

The most valuable part of a domain agent is the expertise it carries in its instructions. Don't just say "optimize queries" — explain *how* this technology's optimizer works and what it responds to:

```markdown
## Query Optimization (SQL Server 2022)

SQL Server 2022 introduced Parameter Sensitive Plan Optimization (PSP),
which creates multiple plans for queries with parameter sniffing issues.
When diagnosing slow queries:

1. Check if PSP is creating multiple plan variants:
   `SELECT * FROM sys.query_store_plan WHERE plan_type = 2`
2. If PSP isn't activating, verify the database compatibility level is 160
3. For queries that PSP can't help, consider...
```

**4. Reference deeper knowledge files**

Keep SKILL.md under 500 lines. Put deep reference material in `references/`:

```markdown
## Reference Files

Load these when you need deep knowledge for a specific area:

- `references/architecture.md` — Internal architecture, storage engine,
  memory management. Read when answering "how does X work" questions.
- `references/diagnostics.md` — DMVs, wait stats, execution plans,
  extended events. Read when troubleshooting performance or errors.
- `references/features.md` — Complete feature reference for this version.
  Read when answering "does it support X" or "how do I do X" questions.
- `references/migration.md` — Upgrade path, compatibility levels,
  breaking changes. Read when planning version upgrades.
```

**5. Include guardrails and version awareness**

Version-specific agents must know their boundaries:

```markdown
## Version Boundaries

- This agent covers {Technology} {Version} specifically
- Features introduced in {Next Version} are NOT available here
- If the user's environment runs a different version, note compatibility
  differences before proceeding
- When referencing deprecated features, always mention the replacement
```

### Inheritance Between Layers

When creating a version agent that has domain and technology parents:

- **Don't duplicate** content from parent layers. Instead, reference it:
  ```markdown
  For foundational database concepts (normalization, indexing theory,
  transaction isolation), see the domain agent at `../../../SKILL.md`.
  ```
- **Do override** when the version differs from the general technology behavior
- **Do add** version-specific features, quirks, and known issues
- **Do note** when inherited advice doesn't apply to this version

### Writing Quality Checklist

Before finalizing, verify the agent:

- [ ] Has specific, actionable instructions (not generic platitudes)
- [ ] Includes version-specific details that differentiate it from a generic agent
- [ ] References deeper knowledge files with clear guidance on when to load them
- [ ] Defines its scope and boundaries
- [ ] Uses the imperative form in instructions
- [ ] Explains *why* behind important recommendations
- [ ] Keeps SKILL.md under 500 lines with overflow in references/
- [ ] Has a description that triggers on relevant user queries

---

## Step 4: Test the Agent

After drafting, create 2-3 realistic test prompts — things a real user would ask this specific agent. Focus on scenarios that require version-specific knowledge, because that's where generic agents fail and specialized agents shine.

### Good test scenarios for domain agents

- **Troubleshooting**: "My PostgreSQL 17 database is showing high WAL generation after upgrading from 16. What changed and how do I investigate?"
- **Migration**: "We're planning to move from SQL Server 2019 to 2022. What breaking changes should I watch for?"
- **Optimization**: "This Oracle 19c query is doing a full table scan despite having an index. Here's the execution plan..."
- **Architecture**: "Should I use logical replication or streaming replication for my PostgreSQL 17 read replicas?"

### Running tests

For each test case, spawn a subagent with the agent skill loaded:

```
Execute this task:
- Skill path: <path-to-agent-skill>
- Task: <test prompt>
- Save outputs to: <workspace>/iteration-<N>/eval-<ID>/with_agent/outputs/
```

Also run a baseline (same prompt, no agent skill) to measure the value the agent adds.

Save test cases to `evals/evals.json` using the schema from the skill-creator (see `references/schemas.md`).

---

## Step 5: Evaluate and Iterate

After running tests, evaluate the agent's responses:

### What to look for

1. **Specificity** — Did the agent give version-specific advice, or generic platitudes? A PostgreSQL 17 agent should mention `pg_stat_io` (new in PG 16+), not just "check your stats views."

2. **Accuracy** — Did the agent get version-specific details right? Wrong version information is worse than no version information.

3. **Depth** — Did the agent use its reference files to provide deep analysis, or did it stay shallow?

4. **Boundaries** — Did the agent correctly identify when a question falls outside its version scope?

5. **Actionability** — Could a user actually follow the agent's advice? Are there specific commands, queries, or configuration changes?

### Improvement patterns

Common issues and fixes:

| Problem | Fix |
|---------|-----|
| Generic advice, not version-specific | Add more version-specific details to SKILL.md and reference files |
| Incorrect version details | Research and correct the reference material |
| Didn't use reference files | Make the "when to read" guidance clearer in SKILL.md |
| Too verbose, slow responses | Move deep content to reference files, keep SKILL.md lean |
| Missed edge cases | Add a "Common Pitfalls" section with specific gotchas |

### Iteration loop

1. Improve the agent based on evaluation
2. Rerun test cases
3. Compare results with previous iteration
4. Repeat until the agent consistently provides expert-level, version-specific guidance

---

## Step 6: Deploy

Install the finished agent as a skill in the project:

```
project-root/
├── .claude/
│   └── skills/
│       └── database-sql-server-2022/
│           ├── SKILL.md
│           ├── references/
│           └── scripts/
```

For agents that will be shared across projects, install to `~/.claude/skills/`.

---

## Creating Multiple Agents at Once

When building out a full domain (e.g., all supported database engines), work systematically:

1. **Start with the domain layer** — Write the foundational agent first
2. **Pick one technology** — Build it end-to-end (domain → technology → version) as a template
3. **Expand horizontally** — Use the first technology agent as a pattern for siblings
4. **Add versions** — Fill in version agents where needed

This approach avoids the trap of building broad-but-shallow. Get one vertical slice working well before expanding.

---

## Reference Files

This skill includes reference material for deep dives. Load these as needed:

- `references/anthropic-patterns.md` — Anthropic's effective agent design patterns (routing, chaining, parallelization, orchestrator-worker, evaluator-optimizer). Read when choosing the right architecture for an agent.
- `references/domain-taxonomy.md` — Catalog of IT domains, common technologies, and version examples. Read when scoping a new agent or exploring what agents to build.
- `references/schemas.md` — JSON schemas for agent configuration, evals, and test results.

## Agents

Subagent definitions for specialized tasks within the agent creation workflow:

- `agents/domain-researcher.md` — Gathers deep domain knowledge for a specific technology/version. Spawn when you need to research before drafting.
- `agents/agent-reviewer.md` — Reviews a drafted agent for quality, specificity, and adherence to Anthropic patterns. Spawn to get a second opinion on your draft.
