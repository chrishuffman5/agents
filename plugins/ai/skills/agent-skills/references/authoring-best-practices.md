# Anthropic's Agent Skill authoring best practices

Contents:
- Core principles (conciseness, degrees of freedom, model testing)
- Progressive disclosure patterns
- Workflows and feedback loops
- Content guidelines
- Common patterns
- Anti-patterns
- Skills with executable code
- Evaluation and iteration
- Pre-share checklist

## Core principles

> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices

### Concise is key

The context window is a public good, shared with the system prompt, conversation history, other skills' metadata, and the actual request. Default assumption: **Claude is already very smart** — add only context Claude does not already have. Challenge each piece of information: "Does Claude really need this explanation? Can I assume Claude knows this? Does this paragraph justify its token cost?"

Good (concise, ~50 tokens):

```markdown
## Extract PDF text

Use pdfplumber for text extraction:

​```python
import pdfplumber

with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()
​```
```

Bad (verbose, ~150 tokens): explaining what a PDF is, why pdfplumber is recommended, general library concepts.

### Set appropriate degrees of freedom

Match specificity to the task's fragility:

- **High freedom** (text instructions) — multiple approaches are valid, decisions depend on context, heuristics guide the approach. E.g. a numbered code-review checklist.
- **Medium freedom** (pseudocode / parameterized scripts) — a preferred pattern exists but variation is acceptable.
- **Low freedom** (exact scripts, no parameters) — operations are fragile/error-prone and consistency is critical: "Run exactly this script: `python scripts/migrate.py --verify --backup`. Do not modify the command or add additional flags."

Analogy from the docs: narrow bridge with cliffs → low freedom, exact guardrails; open field with no hazards → high freedom, general direction.

### Test with all models you plan to use

- **Haiku** (fast/economical): does the skill provide enough guidance?
- **Sonnet** (balanced): is it clear and efficient?
- **Opus** (powerful reasoning): does it avoid over-explaining?

## Progressive disclosure patterns

> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices

Keep the SKILL.md body **under 500 lines**; split content into separate files when approaching this limit.

**Pattern 1 — High-level guide with references.** SKILL.md gives a quick start and links to FORMS.md / REFERENCE.md / EXAMPLES.md, loaded only as needed.

**Pattern 2 — Domain-specific organization.** Split reference material by domain so unrelated domains never load:

```text
bigquery-skill/
├── SKILL.md (overview and navigation)
└── reference/
    ├── finance.md (revenue, billing metrics)
    ├── sales.md (opportunities, pipeline)
    ├── product.md (API usage, features)
    └── marketing.md (campaigns, attribution)
```

**Pattern 3 — Conditional details.** Show basic content inline; link out to advanced content (REDLINING.md, OOXML.md) only when needed.

**Avoid deeply nested references.** Claude may partially read (e.g. `head -100`) files referenced from other referenced files, producing incomplete information. Keep references **one level deep from SKILL.md** — every reference file should link directly from SKILL.md.

**Table of contents for long reference files.** For reference files over 100 lines, put a ToC at the top so Claude sees the full scope even during a partial read.

## Workflows and feedback loops

> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices

Break complex tasks into clear sequential steps; for very complex workflows provide a copyable checklist:

```
Task Progress:
- [ ] Step 1: Analyze the form (run analyze_form.py)
- [ ] Step 2: Create field mapping (edit fields.json)
- [ ] Step 3: Validate mapping (run validate_fields.py)
- [ ] Step 4: Fill the form (run fill_form.py)
- [ ] Step 5: Verify output (run verify_output.py)
```

Implement feedback loops — the common pattern is run validator → fix errors → repeat. Example: edit XML → `python ooxml/scripts/validate.py unpacked_dir/` → fix on failure → re-validate → proceed only when it passes → rebuild → test.

## Content guidelines

> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices

**Avoid time-sensitive information.** Do not write "before August 2025 use X, after use Y". Keep a "Current method" section plus a collapsed `<details>` block for deprecated patterns.

**Use consistent terminology.** Pick one term and stick to it throughout — always "API endpoint", never a mix of "URL" / "API route" / "path".

## Common patterns

> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices

- **Template pattern** — provide exact templates for strict output formats ("ALWAYS use this exact template structure"), or a "sensible default, use your best judgment" template where flexibility is fine.
- **Examples pattern** — input/output pairs convey style and level of detail better than descriptions alone.
- **Conditional workflow pattern** — branch instructions at the decision point ("Creating new content? → … / Editing existing content? → …").

## Anti-patterns

> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices

- **Windows-style paths** — always forward slashes (`scripts/helper.py`), even on Windows; backslashes break on Unix systems.
- **Too many options** — do not offer "you can use pypdf, or pdfplumber, or PyMuPDF, or…". Give one default plus an explicit escape hatch for edge cases.

## Skills with executable code

> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices

**Solve, don't defer.** Scripts should handle error conditions explicitly rather than leaving Claude to interpret a raw exception.

**Justify configuration constants** (no "voodoo constants"):

```python
# HTTP requests typically complete within 30 seconds
# Longer timeout accounts for slow connections
REQUEST_TIMEOUT = 30
```

not `TIMEOUT = 47  # Why 47?`

**Provide utility scripts** even when Claude could generate equivalent code — more reliable, saves tokens (source never enters context, only output does), saves generation time, ensures consistency. State explicitly whether Claude should **execute** the script ("Run `analyze_form.py`…") or **read it as reference** ("See `analyze_form.py` for the algorithm").

**Use visual analysis** — when inputs can be rendered as images (PDF pages → PNGs), have Claude analyze them visually for layout and structure.

**Create verifiable intermediate outputs** — the plan-validate-execute pattern: analyze → write a plan file (e.g. `changes.json`) → validate the plan with a script → execute → verify. Catches errors before they are applied, especially for batch, destructive, or high-stakes operations. Make validation errors verbose: "Field 'signature_date' not found. Available fields: customer_name, order_total, signature_date_signed".

**Package dependencies** — claude.ai can install from npm/PyPI/GitHub at runtime; the **Claude API has no network access and no runtime package installation**. List required packages in SKILL.md and verify availability against the code execution tool docs.

**MCP tool references** — use fully qualified names `ServerName:tool_name` (e.g. `BigQuery:bigquery_schema`, `GitHub:create_issue`). Without the server prefix, Claude may fail to locate the tool when multiple MCP servers are active.

**Don't assume tools are installed** — state install commands explicitly ("Install required package: `pip install pypdf`").

## Evaluation and iteration

> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices

**Build evaluations BEFORE writing extensive documentation.** Evaluation-driven development: (1) run Claude on representative tasks *without* the skill and document gaps, (2) build ~3 test scenarios covering those gaps, (3) establish baseline performance, (4) write minimal instructions to pass the evals, (5) iterate.

Example eval structure (Anthropic provides no built-in runner — teams build their own):

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

**Develop iteratively with two Claude roles.** "Claude A" helps design and refine the skill; "Claude B" is a fresh instance that tests it on real tasks. Cycle: complete a task without a skill → identify the reusable pattern → ask Claude A to draft the skill → review for conciseness → improve information architecture → test with Claude B → bring specific failure observations back to Claude A → repeat.

**Observe how Claude navigates the skill** — watch for unexpected exploration paths, missed file references, overreliance on one section (move it into SKILL.md), or ignored bundled files (remove them or signal them better).

## Pre-share checklist

> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices

**Core quality**
- [ ] Description is specific and includes key terms
- [ ] Description includes both what the skill does and when to use it
- [ ] SKILL.md body is under 500 lines
- [ ] Additional details are in separate files (if needed)
- [ ] No time-sensitive information (or confined to an "old patterns" section)
- [ ] Consistent terminology throughout
- [ ] Examples are concrete, not abstract
- [ ] File references are one level deep
- [ ] Progressive disclosure used appropriately
- [ ] Workflows have clear steps

**Code and scripts**
- [ ] Scripts solve problems rather than defer to Claude
- [ ] Error handling is explicit and helpful
- [ ] No voodoo constants (all values justified)
- [ ] Required packages listed in instructions and verified as available
- [ ] Scripts have clear documentation
- [ ] No Windows-style paths (all forward slashes)
- [ ] Validation/verification steps for critical operations
- [ ] Feedback loops included for quality-critical tasks

**Testing**
- [ ] At least three evaluations created
- [ ] Tested with Haiku, Sonnet, and Opus
- [ ] Tested with real usage scenarios
- [ ] Team feedback incorporated (if applicable)

## Sources

- https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices

Fetched: 2026-08-05
