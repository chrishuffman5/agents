# Tools and MCP reference

Read when defining a tool, wiring an MCP server, generating tools from an OpenAPI spec, or answering a grounding question.

## Function tools

> Source: https://adk.dev/tools-custom/function-tools/

Any Python function assigned to an agent's `tools` list becomes a tool. ADK inspects the function's **name, docstring, parameters, type hints, and defaults** to generate the schema sent to the LLM. The docstring is the tool description the model sees — write full purpose, parameter meanings, and return description using standard `Args:`/`Returns:` sections.

**Required parameters** — type hint, no default:

```python
def get_weather(city: str, unit: str):
    """
    Retrieves the weather for a city in the specified unit.

    Args:
        city (str): The city name.
        unit (str): The temperature unit, either 'Celsius' or 'Fahrenheit'.
    """
    return {"status": "success", "report": f"Weather for {city} is sunny."}
```

**Optional parameters** — provide a default:

```python
def search_flights(destination: str, departure_date: str, flexible_days: int = 0):
    """
    Searches for flights.

    Args:
        destination (str): The destination city.
        departure_date (str): The desired departure date.
        flexible_days (int, optional): Number of flexible days. Defaults to 0.
    """
```

**Nullable parameters** — `typing.Optional[SomeType]` or `SomeType | None` (Python 3.10+):

```python
from typing import Optional

def create_user_profile(username: str, bio: Optional[str] = None):
    """Creates a new user profile."""
    if bio:
        return {"status": "success", "message": f"Profile for {username} created with bio."}
```

**Context injection** — a parameter typed `ToolContext` is auto-injected by ADK and hidden from the LLM. Only the *type annotation* matters, not the parameter name:

```python
from google.adk.tools import ToolContext

def my_tool(arg1: str, tool_context: ToolContext):
    user_id = tool_context.state.get("user_id")
    # tool_context.actions.transfer_to_agent = "secondary_agent"
```

**Return conventions** — prefer a `dict`; non-dict returns are auto-wrapped as `{"result": value}`. Include a `"status"` key (`success` / `error` / `pending`) so the LLM understands the outcome:

```python
return {"status": "success", "price": 123.45, "currency": "USD"}
```

**Passing data between tools within one turn** — tools inside a single agent turn share the invocation context, so use the `temp:` prefix:

```python
tool_context.state["temp:stock_data"] = {"GOOG": 300.6}   # tool 1 writes
data = tool_context.state.get("temp:stock_data")          # tool 2 reads
```

**Best practices**: minimize parameter count; favor primitive types (`str`, `int`) over custom classes; use meaningful non-generic names (avoid `do_stuff()`); design for async/parallel execution where appropriate.

Full example — the function is automatically wrapped as a `FunctionTool`:

```python
def get_stock_price(symbol: str):
    """
    Retrieves the current stock price for a given symbol.

    Args:
        symbol (str): The stock symbol (e.g., "AAPL", "GOOG").
    """
    try:
        stock = yf.Ticker(symbol)
        historical_data = stock.history(period="1d")
        if not historical_data.empty:
            return historical_data['Close'].iloc[-1]
    except Exception as e:
        print(f"Error retrieving stock price for {symbol}: {e}")
        return None

agent = Agent(model='gemini-2.0-flash', tools=[get_stock_price])
```

## MCP tools

> Source: https://adk.dev/tools-custom/mcp-tools/

ADK describes MCP as "an open standard designed to standardize how Large Language Models (LLMs) like Gemini and Claude communicate with external applications," and supports two directions:

1. **ADK as MCP client** — use external MCP servers' tools inside your agents.
2. **ADK as MCP server** — expose ADK tools through a custom MCP server.

`MCPToolset` (`McpToolset` in code samples) establishes connections, discovers tools via the MCP protocol, converts MCP tool schemas to ADK tool schemas, and proxies calls between the agent and server.

**Stdio (local subprocess)**:

```python
McpToolset(
    connection_params=StdioConnectionParams(
        server_params=StdioServerParameters(
            command='npx',
            args=['-y', '@modelcontextprotocol/server-filesystem', '/path/to/folder']
        )
    )
)
```

**Streamable HTTP (remote server)**:

```python
McpToolset(
    connection_params=StreamableHTTPConnectionParams(
        url="https://mapstools.googleapis.com/mcp",
        headers={'X-Goog-Api-Key': api_key}
    )
)
```

Configuration options: `tool_filter` (restrict which MCP tools reach the agent), `timeout` (connection timeout), `progress_callback` (real-time updates for long-running operations).

**Deployment constraint**: for production environments like Cloud Run and GKE, agents using MCP tools must define the toolset **synchronously** in `agent.py`, not asynchronously. Documented connection-pattern guidance: stdio for self-contained servers, HTTP for scalable remote services, Kubernetes sidecars for containerized MCP servers.

For the protocol itself — spec, transports, OAuth, authoring servers — use the `mcp` sibling skill.

## OpenAPI tools

> Source: https://adk.dev/tools-custom/openapi-tools/

`OpenAPIToolset` auto-generates callable tools from an OpenAPI v3.x spec: it parses the spec (Python dict, JSON string, or YAML string), discovers all operations, creates one `RestApiTool` per operation, and applies authentication across all generated tools.

```python
from google.adk.tools.openapi_tool.openapi_spec_parser.openapi_toolset import OpenAPIToolset

toolset = OpenAPIToolset(spec_str=openapi_spec_json, spec_str_type="json")
toolset = OpenAPIToolset(spec_dict=openapi_spec_dict)
```

Authentication: set `auth_scheme` and `auth_credential` at instantiation; they apply globally to every generated `RestApiTool`.

The docs include a full Pet Store example (using httpbin.org as a mock server) where an agent drives list/create/retrieve pet operations through the generated tools.

## Built-in tools and grounding

> Source: https://adk.dev/tools-custom/
> Source: https://adk.dev/grounding/

`/tools-custom/` names built-in tools but defers the detail: "**Built-in Tools**: Ready-to-use tools provided by the framework for common tasks. Examples: Google Search, Code Execution, Retrieval-Augmented Generation (RAG)." Implementation details, import paths, and code samples live in the separate `/integrations/` catalog page, which is **not in this corpus**.

The `/grounding/` page covers three grounding approaches:

- **Google Search Grounding** — connect agents to real-time, authoritative web information.
- **Grounding with [Vertex AI] Search** — connect agents to indexed enterprise documents and private data repositories.
- **Agentic RAG** — agents that reason about how to search, constructing queries and filters dynamically rather than using static retrieval.

**Do not invent import paths for these.** Describe the capability, then point the user at the integrations catalog on `https://adk.dev/`.

## Sources

- https://adk.dev/tools-custom/
- https://adk.dev/tools-custom/function-tools/
- https://adk.dev/tools-custom/mcp-tools/
- https://adk.dev/tools-custom/openapi-tools/
- https://adk.dev/grounding/

Fetched: 2026-08-05
