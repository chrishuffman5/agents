# OWASP MCP Top 10 — Version 0.1 (Beta Release, Phase 3)

Read before reviewing any MCP server deployment, evaluating a third-party server, or citing an `MCP0x` identifier.

## Status caveat — state this whenever you cite it

> Source: https://owasp.org/www-project-mcp-top-10/

As of **2026-08-05** this project is at **Beta Release (Phase 3), Version 0.1**. It is OWASP's first dedicated Top 10 for Model Context Protocol implementations. Identifiers, names, and ordering may change before a stable release — never present `MCP0x` numbering to an auditor as a settled standard the way you would the LLM Top 10. Re-check the live project page before publishing a report that depends on the exact list.

## The ten categories

> Source: https://owasp.org/www-project-mcp-top-10/

| ID | Name | Description | Mitigation |
|---|---|---|---|
| MCP01 | Token Mismanagement & Secret Exposure | Hard-coded credentials, long-lived tokens, and secrets stored in model memory or protocol logs expose systems to unauthorized access. | Short-lived, scoped credentials; secret-scanning controls. |
| MCP02 | Privilege Escalation via Scope Creep | Loose permission boundaries expand over time, enabling agents to perform unintended actions such as data exfiltration. | Least-privilege design with automated scope expiry and strict access reviews. |
| MCP03 | Tool Poisoning | Adversaries compromise tools/plugins or their outputs by injecting malicious, misleading, or biased context that manipulates model behavior. | Validate tool authenticity, monitor for schema poisoning, detect fake tools. |
| MCP04 | Software Supply Chain Attacks & Dependency Tampering | Compromised dependencies introduce backdoors and alter agent behavior. | Signed components, dependency monitoring, provenance tracking. |
| MCP05 | Command Injection & Execution | Agents construct and execute system commands from untrusted input without proper validation. | Sanitize all inputs, sandbox execution, validate command construction. |
| MCP06 | Intent Flow Subversion | Malicious instructions embedded in context hijack the "Intent Flow," steering the agent toward attacker goals — the MCP framing of confused-deputy attacks. | Separate critical instructions from retrieved context; implement intent verification. |
| MCP07 | Insufficient Authentication & Authorization | Weak identity verification and access controls across multi-agent ecosystems expose attack paths. | Strong authentication, role-based access control, identity validation. |
| MCP08 | Lack of Audit and Telemetry | Limited logging prevents detection and investigation of unauthorized activity. | Detailed logs of tool invocations, context changes, and user-agent interactions. |
| MCP09 | Shadow MCP Servers | Unapproved MCP server deployments operate outside formal security governance, often with weak credentials. | Discovery controls, governance policies, secure baseline configurations. |
| MCP10 | Context Injection & Over-Sharing | Shared context windows expose sensitive information across agents or sessions, creating liability. | Strict context scoping, access controls, session isolation. |

## MCP03 sub-techniques

> Source: https://owasp.org/www-project-mcp-top-10/

- **Rug pulls** — malicious updates to previously-trusted tools. The tool you audited is not the tool you are running; re-review on every version change and pin what you can.
- **Schema poisoning** — corrupting the interface or tool definition itself so the description misleads the model into unsafe calls. The tool schema is prompt-adjacent content and must be treated as attack surface.
- **Tool shadowing** — fake or duplicate tools that intercept or alter interactions intended for a legitimate tool. Name collisions across servers are the enabling condition.

## CVE concentration

> Source: https://owasp.org/www-project-mcp-top-10/

Community analysis referenced alongside the official project holds that **tool poisoning, supply-chain compromise, and command injection** together account for the majority of disclosed MCP CVEs. Because this is a Beta and evolving document, verify current CVE statistics against the live OWASP page before quoting numbers — treat the specific proportion as unverified.

## Cross-framework mapping

> Source: https://owasp.org/www-project-mcp-top-10/

- MCP06 (Intent Flow Subversion) is OWASP's MCP-specific naming for the classical confused-deputy pattern; see `../agent-threat-patterns.md`.
- The lethal trifecta maps onto **MCP02 × MCP06** in MCP deployments, and onto **LLM01 × LLM06** at the application layer.

## Sources

- https://owasp.org/www-project-mcp-top-10/

Fetched: 2026-08-05
