# Moderation and guardrail options

Read when selecting or building content controls: what each vendor actually ships, what it classifies, and where the gaps are.

## OpenAI Moderation API

> Source: https://developers.openai.com/api/docs/guides/moderation

(Redirected from `platform.openai.com/docs/guides/moderation` — same official OpenAI documentation, now canonically hosted at `developers.openai.com`.)

### Model (as of 2026-08-05)

**`omni-moderation-latest`** — accepts text and image inputs (image files up to 20 MB). Does **not** classify audio.

### Input types

- Text
- Image URLs, including base64-encoded images
- Mixed text + image arrays in a single request

### Categories

| Category | Input type(s) | Notes |
|---|---|---|
| `harassment` | Text only | Harassing language toward any target |
| `harassment/threatening` | Text only | Harassment including violence or serious harm |
| `hate` | Text only | Hate based on protected characteristics |
| `hate/threatening` | Text only | Hate with violence toward targeted groups |
| `illicit` | Text only | Instructions on how to commit illicit acts |
| `illicit/violent` | Text only | Illicit content involving violence or weapons |
| `self-harm` | Text & images | Acts of self-harm |
| `self-harm/intent` | Text & images | Speaker expressing intent to self-harm |
| `self-harm/instructions` | Text & images | Instructions or advice on self-harm |
| `sexual` | Text & images | Content arousing sexual excitement |
| `sexual/minors` | Text only | Sexual content involving minors |
| `violence` | Text & images | Death, violence, or physical injury |
| `violence/graphic` | Text & images | Graphic depictions of violence or injury |

### Response schema

```json
{
  "id": "modr-...",
  "model": "omni-moderation-latest",
  "results": [{
    "flagged": true,
    "categories": { "...": "boolean per category" },
    "category_scores": { "...": "confidence 0-1 per category" },
    "category_applied_input_types": { "...": "which input types triggered each category" }
  }]
}
```

- `flagged` (bool) — whether the content is potentially harmful overall.
- `categories` (object) — per-category boolean flags.
- `category_scores` (object) — per-category confidence scores, 0–1.
- `category_applied_input_types` (object) — which input types (text/image) contributed to each category flag.

### Pricing and limits

- **Free to use.**
- Image files up to 20 MB.
- No explicit rate limit documented on the fetched page.

### Code

Standalone text moderation (JavaScript):

```javascript
const moderation = await openai.moderations.create({
  model: "omni-moderation-latest",
  input: "...text to classify goes here...",
});
```

Mixed text + image moderation (Python):

```python
response = client.moderations.create(
    model="omni-moderation-latest",
    input=[
        {"type": "text", "text": "..."},
        {"type": "image_url", "image_url": {"url": "..."}}
    ],
)
```

Moderation attached to generation — `moderation` param on `responses.create` (Python):

```python
response = client.responses.create(
    model="gpt-5.6",
    input=[{"role": "user", "content": "..."}],
    moderation={"model": "omni-moderation-latest"},
)
```

The model id `gpt-5.6` is what the fetched page showed as of 2026-08-05; verify the current generation model id against `developers.openai.com` before relying on it in code. Cross-vendor model choice is the `model-selection` skill's job.

### Limitations

- Image-only requests return 0 scores for text-only categories (e.g. `illicit`, `sexual/minors`).
- Streaming responses include moderation scores only after full output generation completes, not incrementally.
- Tool-calling moderation covers arguments and outputs, **not tool metadata or schemas** — which is exactly where MCP03 schema poisoning lives.
- Model upgrades may require recalibration of custom policies that rely on fixed score thresholds.

## Anthropic guardrails — pattern, not product

> Source: https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/mitigate-jailbreaks
> Source: https://code.claude.com/docs/en/security

Anthropic does not ship a separate "Moderation API" product analogous to OpenAI's. The guardrails documentation prescribes a **build-your-own moderation pattern using Claude itself**:

- **Harmlessness screen** — call a lightweight model (Claude Haiku 4.5) with the content to classify and constrain its response to a JSON schema (e.g. `{"is_harmful": boolean}`) via `output_config`. This is the documented pattern both for screening end-user input before it reaches the main conversation and for screening tool output before Claude acts on it (`injection_suspected: boolean`).
- Anthropic's security docs reference running "a moderation API against all end-user prompts before they are sent to Claude to ensure they are not harmful" as an API Safeguards Tool pattern — implemented via this Haiku-classifier approach rather than a dedicated moderation endpoint.
- **Computer-use tool** — Anthropic runs additional first-party classifiers on screenshots specifically to detect prompt injection and steers Claude toward asking for user confirmation before acting. These are not callable as a separate API.
- **Claude Code** — uses context-aware analysis and input sanitization built into the product itself (see `claude-code-trust-model.md`) rather than exposing a standalone moderation API for third-party use.

**Gap:** no dedicated Anthropic moderation endpoint comparable to OpenAI's free `/moderations` API was found in the fetched official docs. The documented approach is a thin classification call on top of the standard Messages API. If such a product exists, it was not surfaced by the pages fetched for this corpus — do not assert one exists.

## Google Cloud Model Armor

> Source: https://cloud.google.com/security/products/model-armor

A model-agnostic AI security service that screens prompts and responses from LLMs and AI agents in real time. As of 2026-08-05:

- Detects and blocks **prompt injection and jailbreak** attempts designed to manipulate or compromise LLMs and agents.
- Also detects **sensitive data leakage**, **malicious URLs** embedded in prompts or responses before they can cause harm, and **unsafe or unwanted content** (hate speech, harassment, sexually explicit material, dangerous topics) with fine-grained controls.
- **Model-agnostic** — protects Gemini, OpenAI, Anthropic, Llama, and other models via a REST API, usable with any cloud or infrastructure.
- Offers no-code in-line protection integrated with Google Cloud services including the Gemini Enterprise Agent Platform, acting as an "AI firewall."
- Has a free tier.

**Gap:** pricing details and the per-endpoint API schema were not retrievable from the fetched summary page. Treat the detailed API reference as unverified and consult `cloud.google.com/security/products/model-armor` documentation subpages for exact schema.

## Selection guidance

- A harmful-content classifier is not an injection defense. Deploy content moderation and injection screening as separate controls with separate test sets.
- Prefer controls you can recalibrate: score-threshold policies drift on every model upgrade.
- Screen both directions — input before the model, and tool output before the model acts on it. See `prompt-injection-defense.md` for the tool-output screening loop.

## Sources

- https://developers.openai.com/api/docs/guides/moderation
- https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/mitigate-jailbreaks
- https://code.claude.com/docs/en/security
- https://cloud.google.com/security/products/model-armor

Fetched: 2026-08-05
