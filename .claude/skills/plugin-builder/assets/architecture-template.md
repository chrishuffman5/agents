# Plugin Architecture Proposal: {target}

- Engagement: {remodel | restructure → marketplace | greenfield | audit-only}   (INTERVIEW.md round 1)
- Audience / distribution: {who} via {marketplace | git | skills-dir}
- Source material: {repo path; one line on what exists, from INVENTORY.md}
- Sizing consent: {N} full builds, {M} refreshes, rest deferred   (INTERVIEW.md § Sizing)

## Shape

{Single plugin `<name>` | Marketplace with plugins: `<a>`, `<b>`, … | Bundle `<name>` over existing plugins}

{One sentence: why this shape follows from the interview, not from the file layout that happens to exist.}

## Plugin: {name}

- Purpose / domain boundary: {what belongs here; what is explicitly out}
- Namespace impact: {`/old` → `/{name}:old` renames users will feel; compatibility notes needed}
- Version strategy: {explicit semver, starting at v… | commit-SHA}

### Skills

| Skill | Angle it owns | Source material | Verdict | NOT-clauses required |
|---|---|---|---|---|
| {kebab-name} | {one phrase} | {existing path | none} | keep / refresh / rebuild / new / merge-into:{x} / drop | {overlapping skill → route} |

### Agents

| Agent | Role | Notes |
|---|---|---|
| {name}-specialist | knowledge map of this plugin's skills/ | via agent-creator; no hooks/mcpServers/permissionMode |

### Hooks

| Event | Behavior | Why a hook (must ALWAYS happen) |
|---|---|---|

### MCP / LSP / monitors / bin

| Component | What | Official alternative checked? |
|---|---|---|

### Evals

{trigger-evals.json: one positive + one near-miss negative per skill; near-misses come from the overlap audit}

{Repeat the "## Plugin:" section per plugin for marketplace shapes.}

## Migrations and renames

- {move/merge/delete, in execution order; destructive steps marked ⚠ for checkpoint-3 confirmation}
- renames history: {`old` → `new` entries, or "none"}

## Deferred / out of scope

- {item} — {why; who decided (interview | sizing consent | sign-off amendment)}

## Risks and open questions

- {risk} — {mitigation or the question to ask before it bites}

## Sign-off

- {date} — proposed by {session}
- {date} — approved by user {as-is | with amendments: …}
- Amendments log: {dated entries; scope changes reference the INTERVIEW.md delta that authorized them}
