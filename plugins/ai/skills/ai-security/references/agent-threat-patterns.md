# Agent threat patterns and containment

Read when threat-modeling an agent architecture: which execution paths are exploitable, which containment tier fits, and what has already gone wrong in production systems.

## Confused deputy in agent systems

> Source: https://owasp.org/www-project-mcp-top-10/

The classical confused-deputy problem — a program holding more privilege than the entity it acts for, tricked into misusing that privilege — is weaponized in agent architectures. The agent holds tools (call this API, query that database, send this email); a prompt injection causes it to invoke a tool on behalf of an attacker rather than the legitimate user. **MCP06 (Intent Flow Subversion)** is OWASP's naming for this pattern in MCP deployments.

Design implication: authorization must be evaluated against the *requesting principal*, not against the agent's own service identity. An agent that can do anything its service account can do is a standing confused deputy.

## The lethal trifecta

> Source: https://owasp.org/www-project-mcp-top-10/
> Source: https://www.anthropic.com/engineering/how-we-contain-claude

The commonly cited framing: **private data access + exposure to untrusted content + ability to communicate externally = exfiltration risk with no code exploit required.**

Mapping:
- Application layer: **LLM01 (Prompt Injection) × LLM06 (Excessive Agency)**.
- MCP deployments: **MCP02 (Privilege Escalation via Scope Creep) × MCP06 (Intent Flow Subversion)**.

Anthropic's own agent-containment writing describes the identical risk chain in practice — an attacker exfiltrating credentials via a phished prompt when an agent has data access, processes untrusted content, and retains network egress — **without using the term "lethal trifecta."** Attribute the term to community usage, not to Anthropic.

**The control implied by all these sources is the same:** ensure no single execution path grants an agent all three properties simultaneously. Where it must, enforce human approval at that path or apply environmental egress controls.

## Anthropic's containment model

> Source: https://www.anthropic.com/engineering/how-we-contain-claude

### Three layers

1. **Environmental isolation (primary)** — sandboxes, VMs, filesystem boundaries, egress controls.
2. **Model-layer defenses (secondary)** — system prompts, classifiers, probes, training modifications.
3. **External content controls (tertiary)** — tool permissions, connector auditing, input inspection.

Stated principles: "Defenses should overlap and complement each other. When environmental defenses aren't available, the model layer has to pick up the slack." And: **"Design for containment at the environment layer first"** — probabilistic model-layer defenses fail when the attacker controls user input directly.

### Product architectures as reference designs

| Product | Isolation | Threat model / trade-off |
|---|---|---|
| Claude.ai | Ephemeral **gVisor** containers on isolated infrastructure, per-session ephemeral filesystems | Protects Anthropic infrastructure and multi-tenant isolation; minimal blast radius, limited agent capability |
| Claude Code | Human-in-the-loop sandbox on the user's machine; OS-level sandboxing — **Seatbelt on macOS, bubblewrap on Linux** — enforcing "reads allowed, writes confined to workspace, network denied by default" | Targets developers who can evaluate bash commands. Auto-mode classifier catches ~83% of problematic commands, reducing approval fatigue while keeping a 93% manual-approval rate for the remainder |
| Claude Cowork | Sealed VM; workspace mounted read-only, read-write, or read-write-no-delete; agent loop runs outside the VM while code execution stays inside; local MCP servers run on the host, not the guest | Full isolation for non-technical users; host-side MCP keeps auditability and dependency management out of the guest |

Isolation *mechanics* (how to configure gVisor, Seatbelt, bubblewrap, egress proxies) belong to the `sandboxing` skill — this table is for choosing a tier.

### Vulnerabilities Anthropic found internally, and the fixes

- **Pre-trust execution risk** — configuration files were parsed before user consent, allowing untrusted code execution. Fix: defer all project-local config parsing until after the trust prompt is accepted. *Generalize:* anything your product parses before the trust decision is inside the attacker's reach.
- **Direct prompt injection** — an internal red team exfiltrated AWS credentials via a phished prompt in **24 of 25 attempts** when the attacker directly controlled the input. Model-layer defenses were ineffective; only environmental egress controls prevented data loss.
- **Approved-domain exfiltration** — an attacker uploaded workspace files to their own account through legitimate `api.anthropic.com` calls using an injected API key, abusing an allow-listed domain. Fix: a man-in-the-middle proxy inside the VM intercepts requests and validates that only VM-provisioned tokens are used. *Generalize:* domain allowlists do not constrain credentials; bind egress to environment-provisioned identity.
- **EDR visibility loss** — VM isolation prevented endpoint detection and response software from monitoring guest activity, creating compliance gaps for enterprise deployments. Budget for agent-native telemetry rather than assuming existing tooling sees inside.

### Stated principles

- Match isolation strength to the level of user oversight available.
- Custom or proprietary isolation components are the highest-risk element; battle-tested primitives (hypervisors, seccomp, gVisor) are more reliable than bespoke layers.

### Emerging threats flagged

- Persistent memory poisoning across sessions.
- Multi-agent trust escalation exploits.
- Agent identity and cross-platform authorization — "who is this agent acting as, across which systems."

## MCP trust model in Claude Code

> Source: https://code.claude.com/docs/en/security

- The list of allowed MCP servers is configured in source code as part of Claude Code settings checked into version control — MCP trust is a reviewable, auditable artifact, not a runtime prompt users click through blind.
- Anthropic's guidance: write your own MCP servers, or use only servers from providers you trust.
- Anthropic reviews connectors against its listing criteria (`https://claude.com/docs/connectors/building/review-criteria`) before adding them to the Anthropic Directory (`claude.ai/directory`) — but explicitly **does not security-audit or manage any MCP server** listed there.
- First-time codebase runs and first-time use of a new MCP server require **trust verification**. Trust verification is disabled when running non-interactively with the `-p` flag. Started directly in the home directory, trust acceptance is session-only and is not persisted to disk — start from a project subdirectory for persisted trust.
- Network-fetching commands (`curl`, `wget`) are not auto-approved by default even when other Bash commands are allow-listed; they prompt individually unless an explicit `Bash(curl *)` allow rule is added, or can be blocked entirely via `permissions.deny`.
- Web fetch uses an **isolated context window** specifically so potentially malicious prompts in fetched content do not enter the main agent context.

## Sources

- https://owasp.org/www-project-mcp-top-10/
- https://www.anthropic.com/engineering/how-we-contain-claude
- https://code.claude.com/docs/en/security

Fetched: 2026-08-05
