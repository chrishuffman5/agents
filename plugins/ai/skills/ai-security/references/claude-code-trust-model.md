# Claude Code trust and security model

Read when answering enterprise approval questions about Claude Code: what it can touch by default, where trust decisions happen, and what governance levers exist. Configuration syntax for permissions, hooks, and settings files belongs to the `claude-code` skill.

## Security foundation

> Source: https://code.claude.com/docs/en/security

Claude Code is developed according to Anthropic's security program. The SOC 2 Type 2 report and ISO 27001 certificate are available via the Anthropic Trust Center (`trust.anthropic.com`).

## Permission-based architecture

> Source: https://code.claude.com/docs/en/security

- **Strict read-only permissions by default.** Additional actions — editing files, running tests or commands — require explicit approval; users choose to approve once or allow automatically.
- Bash commands that can modify the system require approval. A built-in set of **read-only commands** (`ls`, `cat`, `git status`, and similar) runs without a prompt.
- Permissions are configured directly by users or organizations.

## Built-in protections

> Source: https://code.claude.com/docs/en/security

- **Sandboxed bash tool** — filesystem and network isolation for bash commands, reducing prompts while maintaining security. Boundaries configured via `/sandbox`.
- **Working directory boundary** — Claude Code can only *write* to the folder it was started in and its subfolders; it cannot modify parent-directory files without explicit permission. *Reading* paths outside the boundary via Read/Grep/Glob is possible after an approval prompt. Extend the writable boundary with additional-directories config to skip prompts, or restrict read access further with sandbox `denyRead` rules (which apply only when sandboxing is enabled).
- **Prompt fatigue mitigation** — allowlisting of frequently used safe commands per user, per codebase, or per organization.
- **Accept Edits mode** — auto-approves file edits and a fixed set of filesystem bash commands (`mkdir`, `touch`, `rm`, `mv`, `cp`, `sed`) scoped to the working directory; other bash commands and out-of-scope paths still prompt.
- **User responsibility** — Claude Code only has the permissions granted to it; users are responsible for reviewing proposed code and commands before approval.

## Prompt-injection-specific protections

> Source: https://code.claude.com/docs/en/security

- **Permission system** — sensitive operations require explicit approval.
- **Context-aware analysis** — detects potentially harmful instructions by analyzing the full request rather than matching keywords.
- **Input sanitization** — processes user inputs to prevent command injection.
- **Network command approval** — `curl`/`wget`-style commands are not auto-approved by default; they prompt like any other non-read-only bash command. Can be allow-listed (`Bash(curl *)`) or blocked entirely via `permissions.deny`.
- **Isolated context windows** — web fetch uses a separate context window so fetched content cannot inject prompts into the main agent context.
- **Trust verification** — first-time codebase runs and new MCP servers require trust verification. Disabled when running non-interactively with `-p`. When started directly in the home directory, trust acceptance is session-only and not persisted.
- **Command injection detection** — suspicious bash commands require manual approval even if previously allow-listed.
- **Fail-closed matching** — unmatched commands default to requiring manual approval.
- **Natural-language command explanations** — complex bash commands include plain-language explanations for user review.
- **Secure credential storage** — API keys and tokens are stored in the macOS Keychain where available and protected by file permissions on Windows and Linux.

### Windows-specific warning

> Source: https://code.claude.com/docs/en/security

Avoid enabling WebDAV or allowing access to paths like `\\*` that may contain WebDAV subdirectories. WebDAV is deprecated by Microsoft for security reasons, and enabling it may let Claude Code trigger network requests to remote hosts, **bypassing the permission system**.

### Official recommendations for untrusted content

> Source: https://code.claude.com/docs/en/security

1. Review suggested commands before approval.
2. Avoid piping untrusted content directly to Claude.
3. Verify proposed changes to critical files.
4. Use VMs to run scripts and make tool calls, especially against external web services.
5. Report suspicious behavior with `/feedback`.

Explicit caveat from the documentation: "While these protections significantly reduce risk, no system is completely immune to all attacks. Always maintain good security practices when working with any AI tool."

## MCP security

> Source: https://code.claude.com/docs/en/security

- Allowed MCP servers are configured in source-controlled Claude Code settings — a reviewable, auditable artifact.
- Anthropic recommends writing your own MCP servers or using only servers from trusted providers.
- Permissions for MCP servers are independently configurable.
- Anthropic reviews connectors against listing criteria before adding them to the Anthropic Directory (`claude.ai/directory`) but does **not** security-audit or manage any MCP server.

## Cloud execution security (Claude Code on the web)

> Source: https://code.claude.com/docs/en/security

- **Isolated VMs** — each cloud session runs in an isolated, Anthropic-managed VM.
- **Network access controls** — limited by default; configurable to disable entirely or allow only specific domains.
- **Credential protection** — authentication via a secure proxy using a scoped credential inside the sandbox, translated to the real GitHub token; the real token never enters the sandbox.
- **Branch restrictions** — git push is restricted to the current working branch.
- **Audit logging** — all cloud-session operations are logged for compliance and audit.
- **Automatic cleanup** — session VMs are reclaimed after inactivity.

**Remote Control** (a web UI driving a locally-running Claude Code process) works differently: code execution and file access stay local; session traffic travels over the Anthropic API via TLS; the session transcript is stored on Anthropic servers to sync across devices. No cloud VMs or sandboxing are involved. It uses multiple short-lived, narrowly-scoped credentials, each limited to a specific purpose and expiring independently, to limit blast radius from any single compromised credential.

## Security best practices

> Source: https://code.claude.com/docs/en/security

**Working with sensitive code**
- Review all suggested changes before approval.
- Use project-specific permission settings for sensitive repos.
- Use dev containers for additional isolation.
- Regularly audit permission settings with `/permissions`.

**Team security**
- Use managed settings to enforce organizational standards.
- Share approved permission configurations through version control.
- Train team members on security best practices.
- Monitor usage via OpenTelemetry metrics.
- Audit or block settings changes during sessions with `ConfigChange` hooks.

**Reporting vulnerabilities** — do not disclose publicly. Report via the Claude Code HackerOne program (`hackerone.com/4f1f16ba-10d3-4d09-9ecc-c721aad90f24/embedded_submissions/new`) with detailed reproduction steps, and allow time for a fix before public disclosure.

## Related first-party resources

> Source: https://code.claude.com/docs/en/security

- Security guidance plugin — has Claude review and fix vulnerabilities in its own changes during a session.
- `/security-review` — on-demand security pass over current-branch changes.
- Sandbox environments doc — compares isolation approaches by threat model.
- Sandboxing doc — filesystem and network isolation mechanics for the bash tool.
- Permissions doc — full permission and access-control configuration reference.
- CISO's guide to agentic AI (`claude.com/blog/ciso-guide-to-agentic-ai`).

## Sources

- https://code.claude.com/docs/en/security

Fetched: 2026-08-05
