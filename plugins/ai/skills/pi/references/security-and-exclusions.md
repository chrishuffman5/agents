# pi: Security Model, Containment, and Design Exclusions

Read this before answering any enterprise-readiness, isolation, or "how do I restrict pi" question. pi's security posture is deliberately minimal and explicitly documented as such; represent it accurately rather than mapping other harnesses' features onto it.

Scope note: this file covers what pi's own docs say. Isolation architecture, egress control, and multi-tenant sandbox design belong to the `sandboxing` sibling skill; prompt injection and agent threat modeling belong to `ai-security`.

## Permission model

> Source: https://pi.dev/docs/latest/security

pi runs with the **same access level as the user who starts it** — a normal user-account process, not a privileged one. Any file writable by that user is inside the same trust boundary as pi itself.

There is no documented permission-rule syntax, no allow/deny policy file, and no admin-enforced managed-settings equivalent anywhere in the fetched documentation. The available controls are: which tools are enabled, whether project-local resources load, and what the OS/container permits.

Tool-surface controls (see `modes-and-cli.md`): `--tools`/`-t` allowlist, `--exclude-tools`/`-xt`, `--no-builtin-tools`/`-nbt`, `--no-tools`/`-nt`. An extension may also call `pi.setActiveTools()` at runtime.

## No built-in sandbox

> Source: https://pi.dev/docs/latest/security

pi deliberately excludes in-process sandboxing. The rationale, quoted: "A partial in-process sandbox would be easy to misunderstand as a security boundary while still depending on the host shell, filesystem, package managers, credentials, and extension code."

pi is built to integrate with existing project toolchains and the developer's environment — goals the docs describe as fundamentally incompatible with restrictive in-process isolation.

## No permission popups

> Source: https://pi.dev/docs/latest/security
> Source: https://github.com/earendil-works/pi/tree/main/packages/coding-agent

pi has no permission-confirmation dialogs. The documented reasoning: pi assumes the OS already governs file and process access through normal user permissions, and pop-up dialogs "would create a false sense of security without actual isolation."

The README lists the same item as **"No permission popups"**, with two alternatives: run pi in containers, or build a custom confirmation flow integrated with your own environment via an extension — `pi.registerTool`'s `execute` callback plus `ctx.ui.confirm`, or a blocking `tool_call` handler (see `extensions.md`).

An extension-built gate is real but is your code, in-process, and inert in `print`/`json`/`rpc` modes where no human can answer. Design it to fail closed if it is meant to be a control.

## Project trust is an input guard, not a boundary

> Source: https://pi.dev/docs/latest/security

Project trust controls whether pi loads local configuration and extensions from a repository. It prevents a repo from silently modifying settings before the user has approved it. Quoted directly: "It does not make untrusted code, untrusted prompts, or untrusted model output safe."

Mechanics (see also the context-files section of the main SKILL.md): decisions are saved in `~/.pi/agent/trust.json`; `/trust` saves interactively; `-a`/`--approve` trusts project-local files for one invocation; `-na`/`--no-approve` ignores them.

Trust gates `.pi/settings.json` plus project-local skills, prompts, themes, and extensions. It does **not** gate what the model does with repository *content* it reads.

## Recommended containment for untrusted code

> Source: https://pi.dev/docs/latest/security

Use OS-level isolation:

- Containers or VMs with minimal mounted paths
- Read-only mounts where possible
- Restricted API keys and network access
- Review outputs before copying results back to trusted systems

## Containerization patterns

> Source: https://pi.dev/docs/latest/containerization

### Gondolin (micro-VM)

```bash
cp -R packages/coding-agent/examples/extensions/gondolin ~/.pi/agent/extensions/gondolin
cd ~/.pi/agent/extensions/gondolin
npm install --ignore-scripts
```

```bash
cd /path/to/project
pi -e ~/.pi/agent/extensions/gondolin
```

Key behavior: "The extension mounts the host cwd at `/workspace` in the VM and overrides `read`, `write`, `edit`, `bash`, `grep`, `find`, and `ls`." Requirements: Node.js ≥ 23.6.0 and QEMU.

Because Gondolin works by overriding the built-in tools, a custom tool registered by another extension is **not** automatically routed into the VM. Audit the loaded extension set when relying on it.

### Plain Docker

```dockerfile
FROM node:24-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates git ripgrep \
  && rm -rf /var/lib/apt/lists/*
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent

WORKDIR /workspace
ENTRYPOINT ["pi"]
```

```bash
docker build -t pi-sandbox -f Dockerfile.pi .

docker run --rm -it \
  -e ANTHROPIC_API_KEY \
  -v "$PWD:/workspace" \
  -v pi-agent-home:/root/.pi/agent \
  pi-sandbox
```

The named `pi-agent-home` volume persists `~/.pi/agent` — settings, `auth.json`, sessions, and installed packages — across container runs. Note that this also persists credentials inside the container image's data volume; scope the API key accordingly.

### OpenShell (policy-controlled)

```bash
openshell gateway add <gateway-url> --name <name>
openshell gateway select <name>
openshell sandbox create --name pi-sandbox --from pi -- pi
```

## Deliberate design exclusions

> Source: https://github.com/earendil-works/pi/tree/main/packages/coding-agent

pi's philosophy per the README: aggressive extensibility over baked-in features, so the harness does not dictate a workflow. Six documented exclusions and their offered alternatives:

| Excluded | Documented alternatives |
|---|---|
| **MCP** | "Build CLI tools with READMEs (see Skills), or build an extension that adds MCP support" |
| **Sub-agents** | Spawn separate pi instances via tmux; build sub-agent orchestration in an extension; or install a community package that already does this |
| **Plan mode** | Write plans to files (e.g. a PLAN.md); build a custom plan mode via an extension; or install an existing community package |
| **Permission popups** | Run in containers; or build a custom confirmation flow via an extension |
| **Built-in to-dos** | Use a `TODO.md` file, or build a custom solution via an extension. Rationale: avoids confusing the model with a redundant built-in mechanism |
| **No background bash** | Use tmux instead, for full observability and direct interaction with long-running processes, rather than pi managing detached background shells |

How to present this to an evaluator, without editorializing beyond the sources:

- The exclusions are principled and stated up front, not oversights.
- Every alternative shifts work and risk to the operator. "Build an extension" means shipping in-process code with full user privileges; "install a community package" means executing third-party code that the docs explicitly say is unsandboxed.
- The controls an enterprise usually asks for — centrally enforced policy, an audited denylist, a review gate that cannot be turned off locally — have no documented equivalent in pi. The containment story is external: containers, VMs, restricted credentials, network policy.
- Conversely, the small surface is itself a security property: fewer built-in integrations, no MCP client, no background processes, an explicit `--ignore-scripts` install, and a plain JSONL session file that is trivially auditable.

## Package execution risk

> Source: https://pi.dev/docs/latest/packages

"Packages execute with full system access; review source code before installing." There is no sandboxing of package code. Pin versioned specs (`pi install npm:@scope/pkg@1.2.3` is pinned and skips auto-updates) and prefer package entries that exclude the `extensions` category (`"extensions": []`) when you only want its skills or prompts. See `resources-and-packages.md`.

## Documented gaps

- No dedicated long-form design-philosophy page exists under `/docs/latest/` (a `/docs/latest/design`-style URL returned 404). The exclusions list above comes from the GitHub README rendering, the most detailed documented source found as of 2026-08-05.
- The README was retrieved via markdown conversion rather than a raw file read, so exact literal wording beyond the quoted phrases is not independently verified.
- No audit-logging, telemetry-schema, or centrally-managed-policy documentation was found; `PI_TELEMETRY` is described only as "override telemetry settings".

## Sources

- https://pi.dev/docs/latest/security
- https://pi.dev/docs/latest/containerization
- https://pi.dev/docs/latest/packages
- https://pi.dev/docs/latest/usage
- https://pi.dev/docs/latest/environment-variables
- https://github.com/earendil-works/pi/tree/main/packages/coding-agent

Fetched: 2026-08-05
