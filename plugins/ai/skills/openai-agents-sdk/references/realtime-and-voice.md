# Realtime agents and voice pipelines

Read this when the agent talks: a live low-latency voice session (realtime) or a turn-based speech pipeline (voice). These are two different products with different transports, languages, and security models — do not mix their APIs.

| | Realtime agents | Voice pipeline |
|---|---|---|
| Shape | persistent session over WebRTC/WebSocket | batch: STT → text agent → TTS |
| Python | `RealtimeAgent` + `RealtimeRunner`, **server WebSocket only** | `VoicePipeline`, `pip install 'openai-agents[voice]'` |
| TypeScript | `RealtimeAgent` + `RealtimeSession`, WebRTC in browser, WebSocket in Node | not documented in the fetched corpus |

## Realtime agents — Python

> Source: https://openai.github.io/openai-agents-python/realtime/quickstart/

Core components: `RealtimeAgent` and `RealtimeRunner`. Install is the same base package (`pip install openai-agents`). Recommended model: **`gpt-realtime-2.1`**.

Configuration uses nested `audio.input` / `audio.output` settings; legacy flat aliases such as `input_audio_format` are still supported. Documented settings: audio input as PCM16 with `gpt-4o-mini-transcribe` for transcription plus semantic VAD; audio output as PCM16 with a selectable voice (for example `"ash"`); turn detection via semantic VAD with interrupt-response enabled.

Session workflow (async): create a runner, `await runner.run()` returns a `RealtimeSession`; inside an async context use `session.send_message()` for text or `session.send_audio()` for raw audio. The session streams events — audio chunks, history updates, agent-completion signals, errors.

Transport: the Python SDK provides **server-side WebSocket transport only**. There is no browser WebRTC path in Python. For telephony, the realtime guide documents SIP attachment flows. Microphone capture and speaker playback are the application's responsibility; examples live in the repo's `examples/realtime` directory.

## Realtime agents — TypeScript

> Source: https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/voice-agents/quickstart.mdx

`@openai/agents` (recommended for most apps) includes realtime support via `@openai/agents/realtime`. A standalone `@openai/agents-realtime` package exists for projects that do not want the full package.

```bash
npm install @openai/agents zod   # Zod v4
```

Browser sessions must authenticate with an **ephemeral client secret minted server-side** — never an API key:

```bash
export OPENAI_API_KEY="sk-proj-..."
curl -X POST https://api.openai.com/v1/realtime/client_secrets \
   -H "Authorization: Bearer $OPENAI_API_KEY" \
   -H "Content-Type: application/json" \
   -d '{
     "session": {
       "type": "realtime",
       "model": "gpt-realtime-2.1"
     }
   }'
```

The response carries a top-level `value` field prefixed `ek_...` plus the effective `session` object; the token is short-lived. If browser hosted-MCP tools need `authorization` or `headers`, configure them **server-side** in the `session` payload sent to this endpoint — those credentials must never appear in browser code.

```typescript
import { RealtimeAgent, RealtimeSession } from '@openai/agents/realtime';

const agent = new RealtimeAgent({
  name: 'Assistant',
  instructions: 'You are a helpful assistant.',
});

const session = new RealtimeSession(agent, { model: 'gpt-realtime-2.1' });
await session.connect({ apiKey: 'ek_...' });
```

Transport differences that affect connect-time logic:

- **Browser** — `connect()` uses WebRTC and auto-configures microphone capture and audio playback. The SDK sends initial session config as soon as the data channel opens and tries to wait for `session.updated` before resolving, with a timeout fallback.
- **Server runtimes (Node)** — the SDK falls back to WebSocket automatically. `connect()` resolves once the socket opens and initial config is sent, so `session.updated` may arrive slightly later on that path. Do not assume the session is fully configured the instant `connect()` resolves.

## Voice pipelines (Python)

> Source: https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/voice/quickstart.md

Distinct from realtime agents: a batch/turn-based pipeline, not a persistent WebSocket session.

```bash
pip install 'openai-agents[voice]'
```

Three stages: transcribe (speech-to-text) → run your agent(s) → text-to-speech.

Documented pattern: build agents (for example a main assistant plus a Spanish-language handoff agent with a weather tool), wrap them with `VoicePipeline` + `SingleAgentVoiceWorkflow`, pass audio as `AudioInput`, run the pipeline async, and stream output audio events through a player such as `sounddevice`. In production you feed real microphone data rather than a generated silence buffer; a fuller example lives in the project's `examples` directory.

Tracing note: audio spans include base64 PCM by default. Disable with `VoicePipelineConfig.trace_include_sensitive_audio_data` before recording anything sensitive.

## Gaps

- The full realtime session config schema (all `audio.input` / `audio.output` sub-fields and VAD tuning parameters) was only partially captured; the fetched Python quickstart page did not enumerate every field. Do not assert field names beyond those listed above.
- No TypeScript equivalent of the Python `VoicePipeline` was present in the fetched corpus; treat its existence as unverified.

## Sources

- https://openai.github.io/openai-agents-python/realtime/quickstart/
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/voice/quickstart.md
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/voice-agents/quickstart.mdx

Fetched: 2026-08-05
