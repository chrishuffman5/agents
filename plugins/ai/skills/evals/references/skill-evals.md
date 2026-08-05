# Evaluating Agent Skills

Read when the artifact under test is a Skill (`SKILL.md` + bundled files) rather than a prompt or an agent loop.

## Build evaluations before writing documentation

> Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices

Anthropic's explicit directive: **"Create evaluations BEFORE writing extensive documentation."** This ensures a Skill solves real problems instead of documenting imagined ones.

Evaluation-driven development loop:

1. **Identify gaps** — run Claude on representative tasks *without* the Skill; document specific failures or missing context.
2. **Create evaluations** — build at least three scenarios testing those gaps.
3. **Establish a baseline** — measure performance without the Skill.
4. **Write minimal instructions** — just enough content to address the gaps and pass the evals.
5. **Iterate** — run the evals, compare against baseline, refine.

There is **no built-in eval runner** for Skills; you build your own harness. "Evaluations are your source of truth for measuring Skill effectiveness."

### Evaluation case JSON structure

```json
{
  "skills": ["pdf-processing"],
  "query": "Extract all text from this PDF file and save it to output.txt",
  "files": ["test-files/document.pdf"],
  "expected_behavior": [
    "Successfully reads the PDF file using an appropriate PDF processing library or command-line tool",
    "Extracts text content from all pages in the document without missing any pages",
    "Saves the extracted text to a file named output.txt in a clear, readable format"
  ]
}
```

The `expected_behavior` list doubles as the grading rubric.

### Two-instance ("Claude A / Claude B") refinement pattern

Work with one instance ("Claude A") to author and refine the Skill; test it with a fresh instance ("Claude B") on real tasks; bring observed failures back to Claude A. Repeat observe → refine → test.

Observation signals while Claude B runs the Skill:

- **Unexpected exploration paths** — files read out of the anticipated order means the structure isn't intuitive.
- **Missed connections** — failing to follow a reference to an important file means the link isn't explicit or prominent enough.
- **Overreliance on one section** — repeatedly re-reading the same file means that content belongs in the main SKILL.md.
- **Ignored content** — a bundled file never accessed is unnecessary or poorly signaled.

### Test across models

Test every Skill with **Haiku, Sonnet, and Opus**, since effectiveness varies by model: does Haiku get enough guidance, is it clear and efficient for Sonnet, does it avoid over-explaining for Opus. Instructions that work perfectly for Opus may need more detail for Haiku.

Author's checklist — testing section:

- [ ] At least three evaluations created
- [ ] Tested with Haiku, Sonnet, and Opus
- [ ] Tested with real usage scenarios
- [ ] Team feedback incorporated (if applicable)

### Trigger testing

Test automatic invocation by phrasing a request that matches the Skill's `description` **in your own words**, not the description's exact wording. The combined description + `when_to_use` text is truncated at 1,536 characters in the skill listing shown to Claude, so put the key trigger case first in the description.

### Frontmatter validation rules (malformed-skill eval failures)

- `name`: max 64 chars; lowercase letters, numbers, hyphens only; no XML tags; cannot contain the reserved words "anthropic" or "claude".
- `description`: non-empty; max 1,024 characters; no XML tags.
- Recommended SKILL.md body: **under 500 lines** — split overflow into reference files.

## Enterprise-scale Skill evaluation governance

> Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/enterprise

### Five evaluation dimensions required before production

| Dimension | What it measures | Example failure |
|---|---|---|
| Triggering accuracy | Activates for right queries, stays inactive for unrelated ones | Skill triggers on every spreadsheet mention, even off-topic discussion |
| Isolation behavior | Works correctly on its own | Skill references files that don't exist in its directory |
| Coexistence | Doesn't degrade other Skills when added | Overly broad description steals triggers from existing Skills |
| Instruction following | Claude follows the Skill's instructions accurately | Claude skips validation steps or uses the wrong library |
| Output quality | Produces correct, useful results | Generated reports have formatting errors or missing data |

### Submission requirement for Skill authors

Require authors to submit **evaluation suites with 3–5 representative queries per Skill**, covering (a) cases where the Skill should trigger, (b) cases where it should not trigger, and (c) ambiguous edge cases. Require testing across every model the org uses.

### Lifecycle stages: Plan → Create/Review → Test → Deploy → Monitor → Iterate/Deprecate

- **Create and review** — require a security review (risk-tier checklist covering code execution, instruction manipulation, MCP references, network access, hardcoded credentials, filesystem scope) *and* an evaluation suite before approval. Authors must not review their own Skill.
- **Test** — evaluate **in isolation** (Skill alone) *and* with **coexistence testing** (alongside the active Skill set); verify triggering accuracy, output quality, and absence of regressions before promoting to production.
- **Monitor** — rerun evaluations periodically to detect drift and regression as workflows and models evolve. The Skills API does not expose usage analytics, so usage tracking needs application-level logging.
- **Iterate / Deprecate** — require the full evaluation suite to pass before promoting any new version; treat every version bump as a new deployment requiring a full security re-review.

### Using eval results for lifecycle decisions

- Declining trigger accuracy → update the Skill's description or instructions.
- Coexistence conflicts → consolidate overlapping Skills or narrow descriptions.
- Consistently low output quality → rewrite instructions or add validation steps.
- Persistent failures across updates → deprecate the Skill.

### Recall limits as Skill count grows

API requests support a **maximum of 8 Skills per request**. As more Skills are simultaneously available, each Skill's `name` + `description` metadata competes for attention in the system prompt and recall accuracy degrades. Use the evaluation suite to measure recall accuracy as you add Skills, and stop adding once performance degrades. Use evaluation results, not intuition, to decide when to consolidate: "merge narrow Skills into a broader one only when the consolidated Skill's evaluations confirm equivalent performance to the individual Skills it replaces."

### Versioning and rollback policy

- Production: pin Skills to specific versions; run the full evaluation suite before promoting any new version.
- Rollback: keep the previous version as fallback; if a new version fails evaluations in production, revert immediately to the last known-good version.

## OpenAI's `codex exec` skill-eval methodology

> Source: https://developers.openai.com/blog/eval-skills

A methodology for evaluating Codex-style agent skills (the `SKILL.md` kind), independent of any hosted eval product. Pipeline: define success criteria → build the skill → manually validate → run automated evals → grade with deterministic checks → apply model-assisted rubrics.

### Phase 1 — define success before development

- **Outcome goals** — did the task complete.
- **Process goals** — correct tool invocation.
- **Style goals** — convention adherence.
- **Efficiency goals** — avoided unnecessary steps.

"Keep this list small and focused on must-pass checks."

### Phase 2 — manual triggering

Before automating, explicitly invoke the skill in real repositories to expose hidden assumptions about triggering behavior, environment requirements (package managers, dependencies), and execution order.

### Phase 3 — prompt-set construction

A small CSV of 10–20 test cases covering explicit invocation (skill named directly), implicit invocation (contextual match), contextual invocation (realistic noisy prompts), and negative controls (should not trigger).

```
id,should_trigger,prompt
test-01,true,"Create a demo app named demo-app using the $setup-demo-app skill"
test-04,false,"Add Tailwind styling to my existing React app"
```

This is the same shape as this marketplace's per-plugin `evals/trigger-evals.json`.

### Running the eval

```shell
codex exec --json --full-auto "<prompt>"
```

- `--json` — emits a JSONL stream of structured events to stdout.
- `--full-auto` — enables filesystem modifications; apply least privilege.
- `--output-schema` — constrains the response to a JSON Schema for consistent grading.

### Deterministic grading over the JSONL trace

```javascript
const { spawnSync } = require("child_process");
const { writeFileSync, existsSync } = require("fs");
const path = require("path");

function runCodex(prompt, outJsonlPath) {
  const res = spawnSync("codex", ["exec", "--json", "--full-auto", prompt], { encoding: "utf8" });
  writeFileSync(outJsonlPath, res.stdout, "utf8");
  return { exitCode: res.status ?? 1, stderr: res.stderr };
}

function parseJsonl(jsonlText) {
  return jsonlText.split("\n").filter(Boolean).map((line) => JSON.parse(line));
}

function checkRanNpmInstall(events) {
  return events.some(
    (e) =>
      (e.type === "item.started" || e.type === "item.completed") &&
      e.item?.type === "command_execution" &&
      e.item?.command?.includes("npm install")
  );
}

function checkPackageJsonExists(projectDir) {
  return existsSync(path.join(projectDir, "package.json"));
}
```

Rationale quoted: "everything is deterministic and debuggable" because every command appears in order in the JSONL trace.

### Model-assisted rubric grading

Define a JSON Schema for qualitative checks:

```json
{
  "type": "object",
  "properties": {
    "overall_pass": { "type": "boolean" },
    "score": { "type": "integer", "minimum": 0, "maximum": 100 },
    "checks": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "pass": { "type": "boolean" },
          "notes": { "type": "string" }
        },
        "required": ["id", "pass", "notes"]
      }
    }
  },
  "required": ["overall_pass", "score", "checks"]
}
```

```shell
codex exec \
  "Evaluate the demo-app repository against requirements:
   - Vite + React + TypeScript project exists
   - Tailwind configured via @tailwindcss/vite
   - src/components contains Header.tsx and Card.tsx
   Return rubric result as JSON" \
  --output-schema ./evals/style-rubric.schema.json \
  -o ./evals/artifacts/test-01.style.json
```

Stable fields (`overall_pass`, `score`, per-check results) can be diffed and tracked over time.

### Progressive expansion as a skill matures

- Command-thrashing detection — count `command_execution` events to spot looping.
- Token efficiency — track `usage.input_tokens` / `usage.output_tokens` from `turn.completed` events.
- Build verification — run `npm run build` post-completion.
- Runtime validation — run `npm run dev` with a smoke test.
- Repository cleanliness — verify `git status --porcelain` matches expectations.
- Permission regression — confirm the skill works without privilege escalation.

Core principle: "measure what matters" — establish checkable success definitions before development; "Run the agent, record what happened, and grade it with a small set of checks."

## Sources

- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/enterprise
- https://developers.openai.com/blog/eval-skills

Fetched: 2026-08-05
