# Building MCP Servers with the Official SDKs

Read this when writing a server, choosing an SDK, wiring a server into a host's config, or debugging with MCP Inspector.

## Capability types and SDK availability

> Source: https://modelcontextprotocol.io/quickstart/server

MCP servers can provide three capability types: **Resources** (file-like readable data), **Tools** (callable functions, subject to user approval), and **Prompts** (pre-written task templates). Official SDKs exist for Python, TypeScript, Java (Spring AI), Kotlin, C#, and Ruby, among others listed on modelcontextprotocol.io. The official quickstart builds a weather server exposing `get_alerts` and `get_forecast` tools and connects it to Claude Desktop.

## CRITICAL: stdout is reserved for protocol messages

> Source: https://modelcontextprotocol.io/quickstart/server

**For stdio-based servers, never write to stdout for logging.** Writing to stdout corrupts the JSON-RPC message stream and breaks the server. This applies in every language:

| Language | Forbidden (stdout) | Correct (stderr / logging) |
|---|---|---|
| Python | `print()` | `logging` module (writes to stderr); `logging.getLogger(__name__)` per module |
| TypeScript/JS | `console.log()` | `console.error()` or a stderr/file logging library |
| Java | `System.out.println()` / `print()` | logging library writing to stderr or files |
| Kotlin | `println()` | logging library writing to stderr or files |
| C# | `Console.WriteLine()` / `Write()` | logging library writing to stderr or files; also use `Host.CreateEmptyApplicationBuilder` (not `CreateDefaultBuilder`) so the host itself does not print banners |
| Ruby | `puts` / `print` | `Logger.new($stderr)` |

**For HTTP-based servers**, standard output logging is fine — it does not interfere with the HTTP response stream.

## Python SDK quickstart

> Source: https://modelcontextprotocol.io/quickstart/server

**Requirements:** Python 3.10+, MCP Python SDK **2.0.0+**.

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh   # macOS/Linux
# powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"   # Windows

uv init weather && cd weather
uv venv
source .venv/bin/activate      # or .venv\Scripts\activate on Windows
uv add "mcp[cli]"
touch weather.py
```

```python
from typing import Any
from mcp.server import MCPServer

mcp = MCPServer("weather")

NWS_API_BASE = "https://api.weather.gov"
USER_AGENT = "weather-app/1.0"

async def make_nws_request(url: str) -> dict[str, Any] | None:
    headers = {"User-Agent": USER_AGENT, "Accept": "application/geo+json"}
    # async HTTP GET with a timeout; return response.json() or None on failure
    ...

@mcp.tool()
async def get_alerts(state: str) -> str:
    """Get weather alerts for a US state.

    Args:
        state: Two-letter US state code (e.g. CA, NY)
    """
    url = f"{NWS_API_BASE}/alerts/active/area/{state}"
    data = await make_nws_request(url)
    if not data or "features" not in data:
        return "Unable to fetch alerts or no alerts found."
    if not data["features"]:
        return "No active alerts for this state."
    # ... format and return

if __name__ == "__main__":
    mcp.run(transport="stdio")
```

Key pattern: `MCPServer` uses Python **type hints and docstrings** to auto-generate the tool's `inputSchema` and description; the `@mcp.tool()` decorator registers the function. Run with `uv run weather.py`.

## TypeScript SDK quickstart

> Source: https://modelcontextprotocol.io/quickstart/server

**Requirements:** Node.js 20+.

```bash
mkdir weather && cd weather
npm init -y
npm install @modelcontextprotocol/server zod
npm install -D @types/node typescript
mkdir src && touch src/index.ts
```

`package.json` additions: `"type": "module"`, `"bin": {"weather": "./build/index.js"}`, `"scripts": {"build": "tsc && chmod 755 build/index.js"}`.

```typescript
import { McpServer } from "@modelcontextprotocol/server";
import { StdioServerTransport } from "@modelcontextprotocol/server/stdio";
import { z } from "zod";

const server = new McpServer({ name: "weather", version: "1.0.0" });

server.registerTool(
  "get_alerts",
  {
    description: "Get weather alerts for a state",
    inputSchema: z.object({
      state: z.string().length(2).describe("Two-letter state code (e.g. CA, NY)"),
    }),
  },
  async ({ state }) => {
    const stateCode = state.toUpperCase();
    // ... fetch and format
    return { content: [{ type: "text", text: alertsText }] };
  },
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Weather MCP Server running on stdio");
}
main().catch((error) => {
  console.error("Fatal error in main():", error);
  process.exit(1);
});
```

Tool input schemas are defined with **Zod** (`z.object({...})`), not raw JSON Schema — the SDK converts. **Build with `npm run build` before connecting a client**; un-built code will not connect.

Note the package split: the quickstart's server-side package is `@modelcontextprotocol/server`, while the Claude SDK's client-side MCP helpers documentation installs `@modelcontextprotocol/sdk` alongside `@anthropic-ai/sdk` (see `consuming-mcp.md`). Match the package to the side of the connection you are writing.

## Testing with Claude Desktop

> Source: https://modelcontextprotocol.io/quickstart/server

Edit `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) or `%AppData%\Claude\claude_desktop_config.json` (Windows), creating the file if missing. The MCP UI only appears in Claude Desktop once at least one server is configured.

```json
{
  "mcpServers": {
    "weather": {
      "command": "uv",
      "args": ["--directory", "/ABSOLUTE/PATH/TO/PARENT/FOLDER/weather", "run", "weather.py"]
    }
  }
}
```

```json
{
  "mcpServers": {
    "weather": { "command": "node", "args": ["/ABSOLUTE/PATH/TO/PARENT/FOLDER/weather/build/index.js"] }
  }
}
```

You may need the full path to the `uv` executable — get it with `which uv` / `where uv`. **Restart Claude Desktop** after saving for the new server to load.

## Other language SDKs

> Source: https://modelcontextprotocol.io/quickstart/server

- **Java** — via Spring AI MCP auto-configuration and boot starters (`spring-ai-starter-mcp-server`); tools are defined with `@Tool` / `@ToolParam` annotations on a `@Service` class, wired via `MethodToolCallbackProvider`. For HTTP transport set `spring.ai.mcp.server.protocol=STREAMABLE`. Manual, non-Spring server/client construction is documented at https://java.sdk.modelcontextprotocol.io/
- **Kotlin** — `io.modelcontextprotocol:kotlin-sdk` Gradle dependency; server built with `Server(Implementation(...), ServerOptions(capabilities=...))`, tools registered via `server.addTool(name, description, inputSchema) { request -> ... }`, run over `StdioServerTransport`.
- **C#** — NuGet packages `ModelContextProtocol` (prerelease) plus `Microsoft.Extensions.Hosting`; `builder.Services.AddMcpServer().WithStdioServerTransport().WithToolsFromAssembly()`; tools are static methods annotated `[McpServerTool]` inside an `[McpServerToolType]` class, with `[Description(...)]` on parameters. **Use `Host.CreateEmptyApplicationBuilder`, not `CreateDefaultBuilder`**, so the host does not print console output that would corrupt stdio.
- **Ruby** — Ruby 2.7+; log via `Logger.new($stderr)`, never `puts` / `print`.

Full example repositories linked from the quickstart: `modelcontextprotocol/quickstart-resources` (Python, TypeScript, Ruby weather servers), `spring-projects/spring-ai-examples` (Java stdio plus WebFlux/Streamable-HTTP servers), `modelcontextprotocol/kotlin-sdk` samples, `modelcontextprotocol/csharp-sdk` samples.

## Development tooling — MCP Inspector

> Source: https://modelcontextprotocol.io/specification/2025-11-25

Use the MCP Inspector to develop and debug servers interactively, and to obtain OAuth access tokens for testing remote/authenticated servers:

```bash
npx @modelcontextprotocol/inspector
```

In the Inspector UI: pick the transport type ("SSE" or "Streamable HTTP"), enter the server URL, then use **Open Auth Settings → Quick OAuth Flow** to complete an OAuth login and retrieve an `access_token` for manual testing (for example to paste into a Claude API `authorization_token` field — see `consuming-mcp.md`).

Inspector repository: https://github.com/modelcontextprotocol/inspector
Reference server implementations: https://github.com/modelcontextprotocol/servers

## Sources

- https://modelcontextprotocol.io/quickstart/server
- https://modelcontextprotocol.io/specification/2025-11-25
- https://modelcontextprotocol.io/docs/learn/architecture
- https://github.com/modelcontextprotocol/inspector
- https://github.com/modelcontextprotocol/servers
- https://java.sdk.modelcontextprotocol.io/

Fetched: 2026-08-05
