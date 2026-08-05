# Agent SDK Options Reference

Read this when you need the exact name, type, or default of a configuration field, the method surface of `Query`/`ClaudeSDKClient`, or the session-management module functions.

## TypeScript core functions

> Source: https://code.claude.com/docs/en/agent-sdk/typescript

```typescript
function query({ prompt, options }: {
  prompt: string | AsyncIterable<SDKUserMessage>;
  options?: Options;
}): Query;

interface Query extends AsyncGenerator<SDKMessage, void> {
  interrupt(): Promise<SDKControlInterruptResponse | undefined>;
  rewindFiles(userMessageId: string, options?: { dryRun?: boolean }): Promise<RewindFilesResult>;
  setPermissionMode(mode: PermissionMode): Promise<void>;
  setModel(model?: string): Promise<void>;
  setMaxThinkingTokens(maxThinkingTokens: number | null): Promise<void>;
  applyFlagSettings(settings: { [K in keyof Settings]?: Settings[K] | null }): Promise<void>;
  initializationResult(): Promise<SDKControlInitializeResponse>;
  reinitialize(): Promise<SDKControlInitializeResponse>;
  supportedCommands(): Promise<SlashCommand[]>;
  supportedModels(): Promise<ModelInfo[]>;
  supportedAgents(): Promise<AgentInfo[]>;
  mcpServerStatus(): Promise<McpServerStatus[]>;
  getContextUsage(): Promise<SDKControlGetContextUsageResponse>;
  accountInfo(): Promise<AccountInfo>;
  reconnectMcpServer(serverName: string): Promise<void>;
  toggleMcpServer(serverName: string, enabled: boolean): Promise<void>;
  setMcpServers(servers: Record<string, McpServerConfig>): Promise<McpSetServersResult>;
  streamInput(stream: AsyncIterable<SDKUserMessage>): Promise<void>;
  stopTask(taskId: string): Promise<void>;
  close(): void;
}

// Pre-warm subprocesses ahead of traffic (long-running / hosted patterns)
function startup(params?: { options?: Options; initializeTimeoutMs?: number }): Promise<WarmQuery>;

interface WarmQuery extends AsyncDisposable {
  query(prompt: string | AsyncIterable<SDKUserMessage>): Query;
  close(): void;
}
```

## TypeScript `Options` fields

> Source: https://code.claude.com/docs/en/agent-sdk/typescript

| Property | Type | Default | Description |
|---|---|---|---|
| `prompt` | `string \| AsyncIterable<SDKUserMessage>` | required | Input prompt or streaming messages |
| `abortController` | `AbortController` | `new AbortController()` | Cancel operations |
| `additionalDirectories` | `string[]` | `[]` | Additional directories Claude can access |
| `agent` | `string` | `undefined` | Agent name for main thread |
| `agents` | `Record<string, AgentDefinition>` | `undefined` | Programmatically define subagents |
| `agentProgressSummaries` | `boolean` | `false` | Generate progress summaries for subagents |
| `allowDangerouslySkipPermissions` | `boolean` | `false` | Enable bypassing permissions |
| `allowedTools` | `string[]` | `[]` | Tools auto-approved without prompting |
| `betas` | `SdkBeta[]` | `[]` | Enable beta features |
| `canUseTool` | `CanUseTool` | `undefined` | Custom permission function |
| `continue` | `boolean` | `false` | Continue most recent conversation |
| `cwd` | `string` | `process.cwd()` | Working directory |
| `debug` | `boolean` | `false` | Enable debug mode |
| `debugFile` | `string` | `undefined` | Write debug logs to file |
| `disallowedTools` | `string[]` | `[]` | Tools to deny |
| `effort` | `'low'\|'medium'\|'high'\|'xhigh'\|'max'` | model default | Effort/reasoning level |
| `enableFileCheckpointing` | `boolean` | `false` | Enable file change tracking |
| `env` | `Record<string, string\|undefined>` | `process.env` | Replaces subprocess env — spread `...process.env` to keep inherited vars |
| `executable` | `'bun'\|'deno'\|'node'` | auto-detected | JS runtime |
| `executableArgs` | `string[]` | `[]` | Args to executable |
| `extraArgs` | `Record<string, string\|null>` | `{}` | Additional CLI args |
| `fallbackModel` | `string` | `undefined` | Model if primary fails |
| `forkSession` | `boolean` | `false` | Fork to new session ID on resume |
| `forwardSubagentText` | `boolean` | `false` | Forward subagent messages as transcript |
| `hooks` | `Partial<Record<HookEvent, HookCallbackMatcher[]>>` | `{}` | Hook callbacks |
| `includeHookEvents` | `boolean` | `false` | Include hook lifecycle events in message stream |
| `includePartialMessages` | `boolean` | `false` | Include partial/stream message events |
| `loadTimeoutMs` | `number` | `60000` | Timeout for `sessionStore.load()` |
| `managedSettings` | `Settings` | `undefined` | Policy-tier settings |
| `maxBudgetUsd` | `number` | `undefined` | Stop at USD cost threshold |
| `maxThinkingTokens` | `number` | `undefined` | **Deprecated**: use `thinking` |
| `maxTurns` | `number` | `undefined` | Max agentic turns |
| `mcpServers` | `Record<string, McpServerConfig>` | `{}` | MCP server configs |
| `model` | `string` | CLI default | Model alias or full name |
| `onElicitation` | `(request, options: {signal}) => Promise<ElicitationResult>` | `undefined` | MCP elicitation handler |
| `outputFormat` | `{ type: 'json_schema', schema: JSONSchema }` | `undefined` | Structured outputs |
| `pathToClaudeCodeExecutable` | `string` | auto-resolved | Path to Claude Code binary |
| `permissionMode` | `PermissionMode` | `'default'` | Permission mode |
| `permissionPromptToolName` | `string` | `undefined` | MCP tool used for permission prompts |
| `persistSession` | `boolean` | `true` | Persist session to disk (TS-only field; Python always persists) |
| `planModeInstructions` | `string` | `undefined` | Custom plan-mode workflow text |
| `plugins` | `SdkPluginConfig[]` | `[]` | Custom plugins from local paths |
| `promptSuggestions` | `boolean` | `false` | Enable prompt suggestions |
| `resume` | `string` | `undefined` | Session ID to resume |
| `resumeSessionAt` | `string` | `undefined` | Resume at specific message UUID |
| `sandbox` | `SandboxSettings` | `undefined` | Sandbox configuration |
| `sessionId` | `string` | auto-generated | Use a specific UUID for the session |
| `sessionStore` | `SessionStore` | `undefined` | External session storage backend (mirrors transcripts) |
| `sessionStoreFlush` | `'batched'\|'eager'` | `'batched'` | Flush mode for `sessionStore` |
| `settings` | `string \| Settings` | `undefined` | Inline settings object or file path |
| `settingSources` | `SettingSource[]` | CLI defaults (all) | Which filesystem settings load |
| `skills` | `string[] \| 'all'` | `undefined` | Available skills |
| `spawnClaudeCodeProcess` | `(options: SpawnOptions) => SpawnedProcess` | `undefined` | Custom spawn function |
| `stderr` | `(data: string) => void` | `undefined` | Stderr callback |
| `strictMcpConfig` | `boolean` | `false` | Use only specified MCP servers |
| `systemPrompt` | `string \| { type:'preset', preset:'claude_code', append?, excludeDynamicSections? }` | `undefined` | System prompt config |
| `taskBudget` | `{ total: number }` | `undefined` | *Alpha:* API-side task budget |
| `thinking` | `ThinkingConfig` | `{ type: 'adaptive' }` | Thinking/reasoning behavior |
| `title` | `string` | `undefined` | Display title for session |
| `toolAliases` | `Record<string,string>` | `undefined` | Map built-in tools to MCP tools |
| `toolConfig` | `ToolConfig` | `undefined` | Built-in tool behavior config |
| `tools` | `string[] \| { type:'preset', preset:'claude_code' }` | `undefined` | Tool availability configuration |

### Related TypeScript types

```typescript
type PermissionMode = 'default' | 'plan' | 'dontAsk' | 'bypassPermissions';
// 'acceptEdits' and 'auto' are documented on the permissions page for both languages —
// see the cross-language discrepancy note below.

type CanUseTool = (request: PermissionRequest, options: { signal: AbortSignal }) => Promise<PermissionResponse>;

type ThinkingConfig =
  | { type: 'adaptive' }
  | { type: 'enabled'; maxTokens?: number }
  | { type: 'disabled' };

interface OutputFormatConfig { type: 'json_schema'; schema: JSONSchema; }

type SDKControlInitializeResponse = {
  commands: SlashCommand[];
  agents: AgentInfo[];
  output_style: string;
  available_output_styles: string[];
  models: ModelInfo[];
  account: AccountInfo;
  fast_mode_state?: "off" | "cooldown" | "on";
  fast_mode_disabled_reason?: FastModeDisabledReason;
};
```

### Environment variables commonly set via `env`

```typescript
const options = {
  env: {
    ...process.env,
    API_TIMEOUT_MS: "120000",
    CLAUDE_CODE_MAX_RETRIES: "2",
    CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS: "120000",
    CLAUDE_ENABLE_STREAM_WATCHDOG: "1",
    CLAUDE_STREAM_IDLE_TIMEOUT_MS: "300000",
  },
};
```

### Settings resolution (TypeScript)

```typescript
function resolveSettings(options?: {
  cwd?: string; settingSources?: SettingSource[];
  managedSettings?: Settings; serverManagedSettings?: Settings;
}): Promise<ResolvedSettings>;

type SettingSource = 'user' | 'project' | 'local';

interface ResolvedSettings {
  effective: Settings;
  provenance: Partial<Record<keyof Settings, ProvenanceEntry>>;
  sources: Array<{ source; settings; path?; policyOrigin? }>;
}
```

## Python `query()` and `ClaudeAgentOptions`

> Source: https://code.claude.com/docs/en/agent-sdk/python

```python
async def query(
    *,
    prompt: str | AsyncIterable[dict[str, Any]],
    options: ClaudeAgentOptions | None = None,
    transport: Transport | None = None
) -> AsyncIterator[Message]
```

```python
@dataclass
class ClaudeAgentOptions:
    tools: list[str] | ToolsPreset | None = None
    allowed_tools: list[str] = field(default_factory=list)
    system_prompt: str | SystemPromptPreset | SystemPromptFile | None = None
    mcp_servers: dict[str, McpServerConfig] | str | Path = field(default_factory=dict)
    strict_mcp_config: bool = False
    permission_mode: PermissionMode | None = None
    continue_conversation: bool = False
    resume: str | None = None
    session_id: str | None = None
    max_turns: int | None = None
    max_budget_usd: float | None = None
    disallowed_tools: list[str] = field(default_factory=list)
    model: str | None = None
    fallback_model: str | None = None
    betas: list[SdkBeta] = field(default_factory=list)
    output_format: dict[str, Any] | None = None
    permission_prompt_tool_name: str | None = None
    cwd: str | Path | None = None
    cli_path: str | Path | None = None
    settings: str | None = None
    add_dirs: list[str | Path] = field(default_factory=list)
    env: dict[str, str] = field(default_factory=dict)
    extra_args: dict[str, str | None] = field(default_factory=dict)
    max_buffer_size: int | None = None
    debug_stderr: Any = sys.stderr  # Deprecated
    stderr: Callable[[str], None] | None = None
    can_use_tool: CanUseTool | None = None
    hooks: dict[HookEvent, list[HookMatcher]] | None = None
    user: str | None = None
    include_partial_messages: bool = False
    include_hook_events: bool = False
    fork_session: bool = False
    agents: dict[str, AgentDefinition] | None = None
    setting_sources: list[SettingSource] | None = None
    skills: list[str] | Literal["all"] | None = None
    sandbox: SandboxSettings | None = None
    plugins: list[SdkPluginConfig] = field(default_factory=list)
    max_thinking_tokens: int | None = None  # Deprecated: use thinking
    thinking: ThinkingConfig | None = None
    effort: EffortLevel | None = None
    enable_file_checkpointing: bool = False
    session_store: SessionStore | None = None
    session_store_flush: SessionStoreFlushMode = "batched"
    load_timeout_ms: int = 60_000
    task_budget: TaskBudget | None = None
```

Field notes:

- `session_id` cannot be combined with `continue_conversation` or `resume` unless `fork_session=True`.
- `disallowed_tools`: bare names (`"Bash"`) remove the tool from context entirely; scoped rules (`"Bash(rm *)"`) deny only matching calls.
- `strict_mcp_config`: use only servers passed in `mcp_servers`, ignoring project/user settings and plugins.
- `setting_sources`: omitted/`None` loads `user`, `project`, and `local` (CLI default). `"user"` = `~/.claude/settings.json`; `"project"` = `.claude/settings.json` (VCS-shared); `"local"` = `.claude/settings.json` (gitignored).
- `output_format`: `{"type": "json_schema", "schema": {...}}`.

## Python `ClaudeSDKClient`

> Source: https://code.claude.com/docs/en/agent-sdk/python

```python
class ClaudeSDKClient:
    def __init__(self, options: ClaudeAgentOptions | None = None, transport: Transport | None = None)
    async def connect(self, prompt: str | AsyncIterable[dict] | None = None) -> None
    async def query(self, prompt: str | AsyncIterable[dict], session_id: str = "default") -> None
    async def receive_messages(self) -> AsyncIterator[Message]
    async def receive_response(self) -> AsyncIterator[Message]   # until & including ResultMessage
    async def interrupt(self) -> None                            # streaming mode only
    async def set_permission_mode(self, mode: str) -> None
    async def set_model(self, model: str | None = None) -> None
    async def rewind_files(self, user_message_id: str) -> None   # requires enable_file_checkpointing=True
    async def get_mcp_status(self) -> McpStatusResponse
    async def reconnect_mcp_server(self, server_name: str) -> None
    async def toggle_mcp_server(self, server_name: str, enabled: bool) -> None
    async def stop_task(self, task_id: str) -> None
    async def get_server_info(self) -> dict[str, Any] | None
    async def disconnect(self) -> None
```

Supports `async with ClaudeSDKClient() as client: ...`.

## Cross-language `PermissionMode` discrepancy

> Source: https://code.claude.com/docs/en/agent-sdk/python and https://code.claude.com/docs/en/agent-sdk/typescript and https://code.claude.com/docs/en/agent-sdk/permissions

Python declares six literals:

```python
PermissionMode = Literal["default", "acceptEdits", "plan", "dontAsk", "bypassPermissions", "auto"]
```

The TypeScript reference page declares four: `'default' | 'plan' | 'dontAsk' | 'bypassPermissions'`.

The permissions page documents all six modes without language qualification, and the TypeScript quickstart passes `permissionMode: "acceptEdits"`. Treat all six as runtime-valid in both languages and the narrower TS union as documentation lag. Whether a specific TypeScript SDK build type-errors on `"acceptEdits"`/`"auto"` is **unverified**; if a build rejects them, set the mode at runtime with `query.setPermissionMode(mode)`.

## Thinking and effort (Python)

> Source: https://code.claude.com/docs/en/agent-sdk/python

```python
EffortLevel = Literal["low", "medium", "high", "xhigh", "max"]  # xhigh falls back to "high" if unsupported

ThinkingDisplay = Literal["summarized", "omitted"]
class ThinkingConfigAdaptive(TypedDict):
    type: Literal["adaptive"]; display: NotRequired[ThinkingDisplay]
class ThinkingConfigEnabled(TypedDict):
    type: Literal["enabled"]; budget_tokens: int; display: NotRequired[ThinkingDisplay]
class ThinkingConfigDisabled(TypedDict):
    type: Literal["disabled"]
ThinkingConfig = ThinkingConfigAdaptive | ThinkingConfigEnabled | ThinkingConfigDisabled

options = ClaudeAgentOptions(thinking={"type": "enabled", "budget_tokens": 10000, "display": "summarized"})
```

Note the field-name difference: TypeScript's `ThinkingConfig` enabled variant uses `maxTokens`; Python uses `budget_tokens`.

## System prompt configuration (Python)

> Source: https://code.claude.com/docs/en/agent-sdk/python

```python
class SystemPromptPreset(TypedDict):
    type: Literal["preset"]
    preset: Literal["claude_code"]
    append: NotRequired[str]
    exclude_dynamic_sections: NotRequired[bool]  # moves cwd/git-repo/auto-memory into the first user msg, for cache reuse

class SystemPromptFile(TypedDict):
    type: Literal["file"]
    path: str
```

Use the file form for large prompts to avoid OS command-line length limits (~128 KB single-arg on Linux; ~32 KB total on Windows).

## Session-management module functions

> Source: https://code.claude.com/docs/en/agent-sdk/typescript and https://code.claude.com/docs/en/agent-sdk/python

TypeScript (async):

```typescript
function listSessions(options?: { dir?: string; limit?: number; includeWorktrees?: boolean }): Promise<SDKSessionInfo[]>;
function getSessionMessages(sessionId: string, options?: { dir?: string; limit?: number; offset?: number }): Promise<SessionMessage[]>;
function getSessionInfo(sessionId: string, options?: { dir?: string }): Promise<SDKSessionInfo | undefined>;
function renameSession(sessionId: string, title: string, options?: { dir?: string }): Promise<void>;
function tagSession(sessionId: string, tag: string | null, options?: { dir?: string }): Promise<void>;

interface SDKSessionInfo {
  sessionId: string; summary: string; lastModified: number; fileSize?: number;
  customTitle?: string; firstPrompt?: string; gitBranch?: string; cwd?: string;
  tag?: string; createdAt?: number;
}
```

Python (synchronous):

```python
def list_sessions(directory=None, limit=None, offset=0, include_worktrees=True) -> list[SDKSessionInfo]
def get_session_messages(session_id, directory=None, limit=None, offset=0) -> list[SessionMessage]
def get_session_info(session_id, directory=None) -> SDKSessionInfo | None
def rename_session(session_id, title, directory=None) -> None   # ValueError / FileNotFoundError on bad input
def tag_session(session_id, tag: str | None, directory=None) -> None  # None clears tag
```

## Quick usage patterns (Python)

> Source: https://code.claude.com/docs/en/agent-sdk/python

```python
# One-off query
options = ClaudeAgentOptions(system_prompt="You are an expert Python developer", permission_mode="acceptEdits")
async for message in query(prompt="Create a Python web server", options=options):
    print(message)

# Resume / fork
options = ClaudeAgentOptions(resume="550e8400-e29b-41d4-a716-446655440000")
options = ClaudeAgentOptions(resume="550e8400-e29b-41d4-a716-446655440000", fork_session=True)

# Streaming input
async def message_stream():
    yield {"type": "user", "message": {"role": "user", "content": "Analyze:"}}
    await asyncio.sleep(0.5)
    yield {"type": "user", "message": {"role": "user", "content": "Temperature: 25°C"}}
async for message in query(prompt=message_stream()):
    print(message)

# Interrupt (streaming mode only)
async with ClaudeSDKClient(options=options) as client:
    await client.query("Long running task...")
    await asyncio.sleep(2)
    await client.interrupt()
    async for message in client.receive_response():
        if isinstance(message, ResultMessage):
            print(f"terminal_reason={message.terminal_reason}")
    await client.query("New command")
```

## Custom Transport (Python, low-level, may change)

> Source: https://code.claude.com/docs/en/agent-sdk/python

```python
class Transport(ABC):
    @abstractmethod
    async def connect(self) -> None: ...
    @abstractmethod
    async def write(self, data: str) -> None: ...
    @abstractmethod
    def read_messages(self) -> AsyncIterator[dict[str, Any]]: ...
    @abstractmethod
    async def close(self) -> None: ...
    @abstractmethod
    def is_ready(self) -> bool: ...
    @abstractmethod
    async def end_input(self) -> None: ...
```

## Sources

- https://code.claude.com/docs/en/agent-sdk/typescript
- https://code.claude.com/docs/en/agent-sdk/python
- https://code.claude.com/docs/en/agent-sdk/permissions

Fetched: 2026-08-05
