# TypeScript Agent SDK 0.3.x package-version changes

Read this when TypeScript SDK code references an API that no longer exists, or when pinning a minimum `@anthropic-ai/claude-agent-sdk` version for a feature.

Only the changes documented on the Agent SDK doc pages fetched 2026-08-05 appear here. For the full history consult the changelogs listed under Sources.

## Removed: experimental V2 session API

> Source: https://code.claude.com/docs/en/agent-sdk/sessions

- **0.3.142** — the experimental V2 session API (`createSession()` with send/stream) was **removed**. Migrate to `query()` plus the session options (`continue`, `resume`, `forkSession`, `sessionId`, `persistSession`).

Code written against `createSession()` will fail to resolve the export on 0.3.142 and later. There is no compatibility shim documented.

## Added: `Workflow` tool

> Source: https://code.claude.com/docs/en/agent-sdk/subagents

- **0.3.149+** — the `Workflow` tool is available for coordinating dozens-to-hundreds of agents. It moves orchestration into a script executed outside the conversation context instead of turn-by-turn delegation. Include `"Workflow"` in `allowedTools` to use it.

## Version-pinning implication for the bundled CLI

> Source: https://code.claude.com/docs/en/agent-sdk/hosting

The native Claude Code binary bundled with the SDK is **pinned to the SDK package version** — updating the CLI means updating the SDK package. Follow semver: take patches continuously and review the changelog before taking minors. Consequently, any Claude Code v2.1.x gate documented in `claude-code-2.1.md` is reached by upgrading the SDK package, not by upgrading Claude Code separately.

## Sources

- https://code.claude.com/docs/en/agent-sdk/sessions
- https://code.claude.com/docs/en/agent-sdk/subagents
- https://code.claude.com/docs/en/agent-sdk/hosting
- https://code.claude.com/docs/en/agent-sdk/overview
- https://github.com/anthropics/claude-agent-sdk-typescript/blob/main/CHANGELOG.md
- https://github.com/anthropics/claude-agent-sdk-python/blob/main/CHANGELOG.md

Fetched: 2026-08-05
