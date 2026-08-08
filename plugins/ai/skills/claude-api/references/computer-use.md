# Computer Use Tool

Read when wiring screenshot/mouse/keyboard control, or when clicks land in the wrong place.

## Overview and beta headers

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool

Computer use is a **beta** feature as of 2026-08-05 giving Claude screenshot capture, mouse control, and keyboard input. It is schema-less — you never supply an `input_schema`; the schema is built into the model.

Beta header (required only for the computer use tool; other tools in the same request don't need it):

| Header | Models |
|---|---|
| `computer-use-2025-11-24` | Opus 5, Sonnet 5, Opus 4.8, Opus 4.7, Opus 4.6, Sonnet 4.6, Opus 4.5 |
| `computer-use-2025-01-24` | Sonnet 4.5, Haiku 4.5, Opus 4.1, Sonnet 4, Opus 4 (the last three retired except on Bedrock/Google Cloud) |

```json
{
  "model": "claude-opus-5",
  "max_tokens": 1024,
  "tools": [
    {"type": "computer_20251124", "name": "computer", "display_width_px": 1024, "display_height_px": 768, "display_number": 1},
    {"type": "text_editor_20250728", "name": "str_replace_based_edit_tool"},
    {"type": "bash_20250124", "name": "bash"}
  ],
  "messages": [{"role": "user", "content": "Save a picture of a cat to my desktop."}]
}
```

cURL adds `-H "anthropic-beta: computer-use-2025-11-24"`.

Computer use is a **client-side** tool. Your application must run the sandboxed computing environment (virtual X11 display via Xvfb, window manager, pre-installed apps) and implement every action handler — Claude only issues calls. Anthropic's reference implementation (Docker container, web UI, agent loop) is at https://github.com/anthropics/anthropic-quickstarts/tree/main/computer-use-demo.

## Actions

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool

**All versions**: `screenshot`, `left_click`, `type`, `key`, `mouse_move`.

**`computer_20250124` and `computer_20251124`**: `scroll`, `left_click_drag`, `right_click`, `middle_click`, `double_click`, `triple_click`, `left_mouse_down`, `left_mouse_up`, `hold_key`, `wait`.

**`computer_20251124` only** (Opus 5, Sonnet 5, Opus 4.8, Opus 4.7, Opus 4.6, Sonnet 4.6, Opus 4.5): `zoom`, which views a screen region at full resolution. Requires `enable_zoom: true` in the tool definition.

```json
{"action": "zoom", "region": [100, 200, 400, 350]}
```

Modifier keys on click/scroll go in the `text` parameter — `hold_key` is only for holding a key over time without another action:

```json
{"action": "left_click", "coordinate": [500, 300], "text": "shift"}
```

Accepted modifiers: `shift`, `ctrl`, `alt`, `super`.

Tool definition parameters:

| Parameter | Required | Description |
|---|---|---|
| `type` | Yes | `computer_20251124` or `computer_20250124` |
| `name` | Yes | Must be `"computer"` |
| `display_width_px` | Yes | Display width in pixels |
| `display_height_px` | Yes | Display height in pixels |
| `display_number` | No | Display number for X11 environments |
| `enable_zoom` | No | Enables `zoom` (`computer_20251124` only). Default `false` |

## Display sizing and coordinate scaling

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool

Screenshots must fit Claude's image limits. The API **silently downscales** oversized images before Claude sees them — which destroys the scale factor you need to map coordinates back, so downscale yourself. Only images over the API's hard request limits (e.g. more than 8,000 px on a side) are rejected outright.

Per-model long-edge limits:

- Opus 5, Sonnet 5, Opus 4.8, Opus 4.7: up to **2576 px**.
- Earlier models: up to **1568 px** long edge and ~**1.15 megapixels** total.

Resize, set `display_width_px`/`display_height_px` to the **resized** dimensions, and scale returned coordinates back up:

```python
import math

def get_scale_factor(width, height):
    long_edge = max(width, height)
    total_pixels = width * height
    long_edge_scale = 1568 / long_edge
    total_pixels_scale = math.sqrt(1_150_000 / total_pixels)
    return min(1.0, long_edge_scale, total_pixels_scale)

scale = get_scale_factor(screen_width, screen_height)
scaled_width = int(screen_width * scale)
scaled_height = int(screen_height * scale)

def execute_click(x, y):
    perform_click(x / scale, y / scale)
```

Substitute your model's actual limits — the snippet uses the earlier-model 1568px / 1.15MP figures.

**macOS Retina** captures at 2x device pixel ratio: either downscale the screenshot by 2x before sending, or halve Claude's returned coordinates.

Diagnosing click failures:

| Symptom | Likely cause | Fix |
|---|---|---|
| Clicks consistently offset one direction | `display_*_px` don't match the image actually sent | Make display dims exactly match the screenshot |
| Clicks near target but miss | Small target, detail lost in 4K+ downscale, or distorted aspect ratio | `enable_zoom: true`; capture at lower DPI or crop; preserve aspect ratio |
| Wrong element entirely | Ambiguous instruction, similar nearby elements | Positional prompts; smaller steps |
| Consistently poor accuracy | Resolution too low | Try a 1280x720 baseline |

Model choice affects precision: Sonnet 4.6 is mechanically more precise than Opus 4.6, especially when screenshots need heavy downscaling; Opus 4.7 closes the gap and its higher resolution limit needs less downscaling.

Recommended resolutions: 1024x768 or 1280x720 for general desktop, 1280x800 or 1366x768 for web apps. Avoid above 1920x1080.

## System prompt, security, caching, pricing

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool

Requesting an Anthropic-schema computer-use tool auto-generates a computer-use system prompt beginning "You have access to a set of functions you can use to answer the user's question. This includes access to a sandboxed computing environment..." Your own `system` parameter is still respected and combined in.

**Prompt injection defense**: Anthropic runs classifiers that flag potential prompt injection in screenshots and steer Claude to ask for user confirmation. Opt out through support if a no-human-in-the-loop design requires it — and then own the residual risk. Broader injection taxonomy belongs to the `ai-security` skill.

**Recommended precautions**: dedicated VM or container with minimal privileges; no access to sensitive data or login credentials; internet limited to an allowlist; human confirmation for consequential actions (financial transactions, accepting ToS, cookie banners). Isolation mechanics are the `sandboxing` skill.

**Screenshot history and caching**: each screenshot adds ~1,000–1,800 input tokens. Put one `cache_control` breakpoint after the system prompt and tool definitions, plus up to three more on the most recent `tool_result` blocks, advancing each turn. Prune old screenshots in **batches** — e.g. keep the last 3 and prune every 25 turns — so the cached prefix stays byte-identical between prune events. Pruning one screenshot per turn destroys the cache every turn.

**Effort recommendations**: Opus 4.7 — `high` by default, `low` for high-throughput or cost-sensitive workloads. Sonnet 4.6 / Opus 4.6 — `medium` by default for the best accuracy-to-cost ratio; avoid `max` (cost without accuracy gain on UI tasks); `low` consumes *fewer* output tokens than disabling thinking entirely, because fewer mistakes mean fewer retries.

**Pricing**: standard tool-use pricing plus 466–499 tokens of system prompt overhead, 735 input tokens per computer-use tool definition on Claude 4.x, screenshot image tokens, and tool-result tokens. Bash and text editor tools alongside carry their own costs.

**Data retention**: screenshots, actions, and files live in your environment, not Anthropic's — Anthropic processes images and action requests in real time per API call. Computer use is therefore ZDR-eligible.

**Limitations**: latency may be too slow for human-paced interaction; coordinate hallucination is possible; scrolling reliability varies (keyboard alternatives like Page Down help); spreadsheet cell selection needs `left_mouse_down`/`left_mouse_up` plus modifiers; account creation and content generation on social platforms is limited; prompt injection and jailbreak risk persists.

## Sources

- https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool
- https://platform.claude.com/docs/en/about-claude/pricing

Fetched: 2026-08-05
