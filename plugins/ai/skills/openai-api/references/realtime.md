# Realtime API

Read when building voice agents, live translation, or streaming transcription. This is an overview — the corpus behind it is thin, and the gaps section matters more than usual.

## Connection methods

> Source: https://developers.openai.com/api/docs/guides/realtime

| Transport | Use for |
|---|---|
| **WebRTC** | Browser and mobile clients that capture or play audio directly |
| **WebSocket** | Server-side audio pipelines, call systems, worker processes |
| **SIP** | Telephony voice agents |

Pick by where the audio physically lives. WebRTC handles jitter, packet loss, and echo control for client-captured audio; a WebSocket carrying raw audio from a browser makes those your problem. SIP model support "requires confirmation per model" — verify before committing to a telephony design.

## Model IDs

> Source: https://developers.openai.com/api/docs/guides/realtime

| Model | Purpose |
|---|---|
| `gpt-realtime-2.1` | Low-latency voice agents with reasoning capabilities |
| `gpt-realtime-translate` | Continuous live speech translation |
| `gpt-live-transcribe` | Streaming transcription with controllable latency |

Pricing for `gpt-realtime-2.1` and `gpt-realtime-2.1-mini` is in `models-and-pricing.md` (from the pricing page — the `-mini` variant was not independently confirmed as a distinct entry on the realtime guide).

Audio tokens run $32/MTok in and $64/MTok out on `gpt-realtime-2.1`. Estimate realtime cost from expected audio minutes, then convert — reasoning about it in text-token terms will understate it badly.

## Session types

> Source: https://developers.openai.com/api/docs/guides/realtime

1. **Voice-agent sessions** — connect to `/v1/realtime`; support full conversational tool-calling.
2. **Translation sessions** — `/v1/realtime/translations`; continuous speech translation with no turn-based lifecycle.
3. **Transcription sessions** — stream transcript deltas only, with no model-generated responses.

The three are not interchangeable configurations of one session — they are separate paths with different lifecycles. A translation session has no turn structure to hook tool calls into.

## Session configuration

> Source: https://developers.openai.com/api/docs/guides/realtime

- **Reasoning effort** is configurable; **start at `"low"` in production**. Latency is the product in a voice interface, and higher effort spends it.
- **Safety identifiers** are passed via the `OpenAI-Safety-Identifier` header.

## Event types

> Source: https://developers.openai.com/api/docs/guides/realtime

Confirmed from the guide: `response.output_text.delta`, `response.output_audio.delta`, and `response.output_audio_transcript.delta`.

Note that audio and its transcript arrive as **separate delta streams** — rendering captions means consuming `response.output_audio_transcript.delta`, not deriving text from the audio stream.

## Gaps — do not fill from memory

- **The complete Realtime event catalog was not captured.** Names such as `session.created`, `session.updated`, `input_audio_buffer.*`, and `conversation.item.*` were not enumerated on the fetched page. Do not assert event names beyond the three confirmed above — direct users to a Realtime event reference.
- No pricing appeared on the realtime guide page itself; figures came from the separate pricing page.
- SIP telephony model support was described as "requiring confirmation" and never resolved to a concrete model list.

## Sources

- https://developers.openai.com/api/docs/guides/realtime
- https://developers.openai.com/api/docs/pricing

Fetched: 2026-08-05
