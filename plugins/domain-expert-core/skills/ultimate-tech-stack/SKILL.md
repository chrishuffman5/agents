---
name: ultimate-tech-stack
description: "Security-first, open-source-preferred defaults for new applications and greenfield platforms. Applies a security hard gate before license and popularity, starts with Django/PostgreSQL/rootless Podman, and adds FastAPI, Next.js, Keycloak, OpenBao, RabbitMQ, Kubernetes, Forgejo/Woodpecker, OpenTofu, Argo CD, Prometheus/Grafana, Airflow/dbt, Superset, or Ceph only when requirements earn them. WHEN: \"new app idea\", \"what stack should we use\", \"default tech stack\", \"secure open-source stack\", \"security-first architecture\", \"greenfield project\", \"just pick a database / framework / broker / orchestrator\", \"standard stack\". Do NOT use for depth on an already-selected technology, existing-environment hardening/compliance, replatforming, incident response, or a bespoke proprietary/managed-service bake-off; use the relevant domain skill, security-expert, migration-expert, troubleshooting-agent, or architecture-consultant."
license: MIT
---

# Security-First Open-Source Tech Stack

Choose the smallest stack the team can patch, isolate, observe, back up, and restore. **Security is the hard gate. Open source is the preference among candidates that clear it.** Popularity, feature count, and ideological purity never compensate for an unsafe deployment model or an operating burden the team cannot carry.

If no open-source candidate clears the security floor for the stated threat model and operating capacity, return **no safe default**. Recommend a narrowly scoped managed or proprietary exception, document the exit path, and route the decision to `architecture-consultant`. Do not silently lower the security bar to preserve an all-open-source answer.

## Apply the Stack

1. **Classify before selecting.** Establish internet exposure, data sensitivity and tenancy, regulatory obligations, identity boundaries, untrusted-code paths, RTO/RPO, and the team's patch/on-call capacity. Do not infer “low risk” from “MVP.”
2. **Run the Security Gate.** Reject any candidate that cannot meet every hard requirement below in this deployment. A secure product operated badly does not pass.
3. **Prefer open source among survivors.** Use the weighted decision model for close calls. Record open-core boundaries and any managed exception.
4. **Start with the Minimum Viable Secure Stack.** Every additional service adds identities, ports, images, secrets, backups, alerts, and upgrades.
5. **State conditions, not absolutes.** Give the default, why it fits, its mandatory controls, and the condition that earns the next component.
6. **Route implementation depth.** Use the named domain skill. If it is unavailable, continue from general knowledge and disclose that the guidance was not grounded in that plugin.

For regulated, high-impact, hostile multi-tenant, safety-critical, or untrusted-code systems, seed the recommendation from this skill but require `architecture-consultant` and `security-expert` review before implementation.

## Security Gate

A candidate passes only when the proposed deployment can satisfy all of these:

1. **Supported and patchable:** supported release, public security process, actionable advisories, predictable updates, and an owner with a patch-time objective.
2. **Least privilege and isolation:** non-root where possible, deny-by-default access, scoped service identities, separated control/data planes, and no shared privileged execution for untrusted work.
3. **Safe exposure model:** authenticated administration, TLS for every untrusted hop, private management/metrics endpoints, bounded input and resource use, and no default credentials.
4. **Supply-chain integrity:** pinned dependencies and images, secret and vulnerability scanning, an SBOM, trusted build provenance, artifact signing, and policy enforcement before production.
5. **Data and key protection:** data classification drives the at-rest/field-level decision; encryption keys have explicit custody, decryption boundaries, rotation, revocation, backup, and recovery procedures.
6. **Detection and response:** protected security audit events, synchronized time, actionable alerts, a named response owner, and rehearsed investigation/containment paths.
7. **Recoverability:** encrypted and access-controlled backups, tested restores, upgrade/rollback procedures, and failure domains aligned to RTO/RPO.
8. **Operational fit:** the team can monitor, patch, rotate credentials, investigate, and recover the component without relying on undocumented heroics.

Among candidates that pass, score with evidence rather than intuition:

| Criterion | Weight |
|---|---:|
| Security architecture and secure defaults | 30% |
| Vulnerability response and supported lifecycle | 20% |
| Supply-chain integrity and release provenance | 15% |
| Operability, recoverability, and blast-radius control | 15% |
| Open governance and license durability | 10% |
| Portability and credible exit path | 10% |

The table below is a starting hypothesis, not a deployment certification. A candidate is not verified for a real deployment until its evidence record is completed against that topology and threat model. Read [references/security-verification.md](references/security-verification.md) before adoption, when refreshing a default, when evaluating a challenger, or for any high-risk recommendation.

## Defaults at a Glance

| Domain | Security-first default | Add or change when | Mandatory condition |
|---|---|---|---|
| Application | Supported Django LTS + server-rendered templates/htmx | FastAPI for API/AI services; Next.js for a proven SPA/SSR/RSC need | Framework security middleware retained; dependencies pinned and patched |
| Database | PostgreSQL | A measured workload requires a specialist | Private network, TLS, scoped roles, PITR, tested restore |
| API | REST + OpenAPI | gRPC/SSE/WebSocket/GraphQL only for the interface need below | Object-level authorization, schemas, limits, timeouts, abuse controls |
| Jobs/messaging | PostgreSQL job table | RabbitMQ for durable queueing/fan-out; Kafka for retained event streams | Idempotency, bounded retries, DLQ/replay controls |
| Data workflows | SQL/dbt Core | Airflow only when orchestration complexity is real | DAG authors are trusted code authors; control plane is private |
| Analytics | SQL and reviewed exports | Superset for recurring governed self-service BI | SSO, least-privilege read-only data roles, private/admin-protected UI |
| Runtime | Rootless Podman + Compose/Quadlet | Kubernetes only for multi-node scheduling/platform needs | No privileged containers or host socket; immutable images |
| Delivery | Existing trusted Git/CI with enforced review | Forgejo + Woodpecker when self-hosting is justified; GitLab CE only with compensating controls; Argo CD when Kubernetes exists | Required review; ephemeral isolated runners; scoped deploy identity |
| Infrastructure | OpenTofu + Ansible | Argo CD for cluster delivery | Remote encrypted state, review, policy, drift detection |
| Identity | Framework sessions plus verified MFA/throttling controls | Keycloak at second client, federation, SSO, or delegated administration | MFA for privileged access; secure cookies; throttled login/recovery; session revocation |
| Secrets | sops + age for deployment config | OpenBao for dynamic/high-assurance secrets; Infisical for simpler team workflows | No plaintext in Git/images/logs; rotation and break-glass tested |
| Observability | Structured logs + health/metrics endpoints | OpenTelemetry + Prometheus/Grafana at first SLO or multiple services | Telemetry private, authenticated, redacted, and retention-limited |
| Edge | Caddy | Nginx/HAProxy for specialized routing, tuning, or existing expertise | Automatic/managed TLS, admin endpoint private, explicit trust proxies |
| Storage | Local filesystem/OpenZFS + restic or BorgBackup | Ceph for multi-node block/file/object scale with dedicated operators | Encryption/access controls, integrity checks, off-site copy, restore test |
| Virtualization | None for an app already on trusted infrastructure | Proxmox VE for an operated on-prem virtualization platform | Separate management network, MFA, patching, backup, quorum design |
| OS | Ubuntu Server LTS minimal install | Debian or RHEL-compatible family for policy/estate fit | Verify repository security coverage; unattended updates are controlled |
| Automation | Python; Bash only for small glue | PowerShell for Windows; Node.js in a TypeScript estate | Locked dependencies, tests, safe subprocess/secrets handling |
| Mail | Postfix as internal relay | Managed delivery for internet reputation/abuse handling | Authenticated relay, TLS, SPF/DKIM/DMARC, no open relay |
| Cloud | No universal provider default | Select by threat model, jurisdiction, service controls, and team skill | Treat provider choice and shared-responsibility controls as architecture decisions |

Catalog gaps are explicit: Forgejo, Woodpecker, Caddy, OpenBao, OpenZFS, restic, BorgBackup, OpenStack, and Apache CloudStack may not yet have dedicated domain skills. Their absence from the catalog is not a security or license verdict; route implementation details through the closest overview skill and flag the gap.

## Minimum Viable Secure Stack

For a typical internet-facing application with moderate sensitivity and no unusual regulatory constraint, begin here:

| Layer | Start with | Required from day one |
|---|---|---|
| App | Django LTS + templates/htmx | CSRF/XSS/clickjacking protections, secure cookies, validation, authorization and cross-tenant tests |
| Data | PostgreSQL | Private access, tenant-isolation model, classified at-rest decision, separate roles, PITR and restore test |
| Identity | Django sessions plus a verified MFA/throttling add-on, or an IdP | MFA for administrators, rate-limited login/recovery, password hashing, session revocation |
| Edge | Caddy, or hardened Nginx where Caddy is not supportable | HTTPS redirect, modern TLS, bounded requests, protected admin/diagnostic routes |
| Runtime | Rootless Podman on supported Ubuntu LTS | Non-root UID, read-only filesystem where possible, dropped capabilities, resource limits |
| Delivery | Existing trusted Git/CI platform | Required branch review, protected tags, isolated ephemeral runners, signed release artifacts |
| Observability | Structured redacted logs, health/metrics, protected security audit events | Time synchronization; alert on auth/privilege/config/deploy/backup/update failures; defined retention |
| Response | Named security incident owner and contact path | Tested triage, containment, evidence-preservation, credential-rotation, and recovery runbook |
| Recovery | Encrypted versioned backup in a separate failure domain | Immutable/append-only copy, separate deletion identity, key recovery, automated verification, timed restore rehearsal |

Add a component only when a written requirement earns it:

- Add **FastAPI** when the product is primarily an API, async I/O, or Python AI/ML service and Django's integrated surface is unnecessary.
- Add **Next.js** when rich client state, React ecosystem requirements, or SSR/RSC materially improve the product. Its server is another backend: patch it promptly, constrain server-side fetches, validate authorization at the data boundary, and never treat UI checks as authorization.
- Add **Keycloak** for multiple clients, federation, SSO, delegated identity administration, or centralized policy. Keep it patched and highly available; identity is a critical dependency.
- Add **RabbitMQ** for durable broker semantics, routing, or fan-out. Add **Kafka** only for retained replayable event streams and an operations team prepared to run it.
- Add **Kubernetes** for multi-node scheduling, platform tenancy, or ecosystem integration—not merely because deployment uses containers.
- Add **Airflow**, **Superset**, **Ceph**, and a service mesh only after their security boundary and operating owner are explicit.

## Application and Data Decisions

### Django first; FastAPI and Next.js by requirement

Django's integrated ORM, migrations, authentication, sessions, CSRF protection, security middleware, and admin reduce the number of independent security decisions for a conventional business application. Use server-rendered templates with htmx until client complexity proves a SPA is warranted.

Django core does not provide MFA or login throttling. Select and verify maintained add-ons for both controls, or use Keycloak/a managed IdP when the team cannot support those dependencies. Test enrollment, recovery, lockout/abuse resistance, administrator step-up, and session revocation.

For multi-tenant systems, choose and document the isolation model—separate database, schema, or rigorously enforced row scope—before schema design. Centralize tenant context, deny unscoped access, and add negative cross-tenant tests for HTTP handlers, ORM queries, background jobs, caches, search, exports, support tools, and administrator paths.

FastAPI remains the default for focused API and AI/ML services. Define authentication and authorization architecture explicitly; generated OpenAPI is not an access-control system. Next.js remains a qualified frontend choice, not the universal application baseline. Self-host it in a minimal container and follow its security advisories like any other internet-facing server.

Use established team skill as a security input: a well-supported Spring Boot or ASP.NET Core team can be safer than a first-time Django team. Route a language-estate override to `architecture-consultant` rather than forcing consistency with this table.

**Deeper:** `backend:django`, `backend:fastapi`, `frontend:htmx`, `frontend:nextjs`, `frontend:react`.

### Interface defaults

| Interface | Default | Security note |
|---|---|---|
| Public/partner | REST + OpenAPI | Authenticate clients; authorize every object/action; rate-limit and version contracts |
| Internal service | REST first; gRPC when typed streaming/performance is measured | “Internal” is not trusted; use workload identity and authenticated encryption |
| One-way server push | SSE | Bound connections, authorize subscriptions, prevent cross-tenant event leakage |
| True bidirectional | WebSocket | Authenticate upgrades and messages; enforce size/rate/time limits |
| Divergent client query shapes | GraphQL | Depth/cost limits, persisted queries where useful, resolver-level authorization |

### PostgreSQL until a measured limit

PostgreSQL is the durable system-of-record default. JSONB, full-text search, PostGIS, and extensions cover many early specialist needs without another networked service. Use distinct owner, migration, runtime, read-only, and backup roles; disallow public exposure; monitor connection exhaustion and replica/backup health.

Escalate only with evidence: Valkey/Redis for ephemeral cache and rate limits, OpenSearch for search/log analytics, ClickHouse for large analytical workloads, and DuckDB for embedded or single-node analytics. Never promote a cache to an unplanned system of record.

**Deeper:** `database:postgresql`, `database:redis`, `database:opensearch`, `database:clickhouse`, `database:duckdb`.

### Data platforms are privileged execution environments

- **Airflow DAG authors can execute code.** Limit authoring to trusted users, separate environments, keep the web/control plane private, use a secrets backend, and isolate task credentials and networks.
- **dbt Core** should use environment-specific least-privilege warehouse roles; review generated SQL and packages like application code.
- **Superset** belongs behind SSO and an authenticated proxy. Disable public examples/debug features, use read-only datasource credentials, restrict SQL Lab and exports, and apply row-level controls at the database when the boundary matters.

**Deeper:** `etl:airflow`, `etl:dbt-core`, `analytics:superset`.

## Delivery, Runtime, and Observability

### Rootless containers before Kubernetes

Use rootless Podman with Compose or Quadlet for local development and a small single-host deployment. Do not mount the host container socket into application or CI containers. Pin images by digest for releases, use minimal bases, drop capabilities, set resource limits, and keep secrets out of layers and environment dumps.

When Kubernetes is earned, require at minimum:

- supported releases and rapid patch ownership;
- Pod Security Admission at `restricted` where workloads permit;
- default-deny ingress and egress with explicit NetworkPolicy allowances;
- non-root workloads, `allowPrivilegeEscalation: false`, `seccompProfile: RuntimeDefault`, dropped capabilities, and read-only roots where possible;
- tightly scoped RBAC/service accounts, encrypted secrets at rest, protected audit logs, and isolated administrative access;
- admission policy (for example Kyverno) for image provenance and workload controls;
- tested control-plane/data backup and restore.

Use Istio only when written mTLS/traffic-policy requirements justify a mesh. Linkerd remains Apache-2.0 and open source; availability/support of current stable community artifacts is an operational evaluation, not a license disqualification.

**Deeper:** `containers:podman`, `containers:kubernetes`, `containers:helm`, `containers:istio`.

### CI/CD is an untrusted-code boundary

Prefer an already trusted Git/CI service for a small team; operating source control plus hostile-code runners is a substantial security commitment. Forgejo is the preferred fully open-source self-hosted option when residency, control, or an existing operations team justifies that commitment because its branch protection can require a specific number of pull-request approvals. Pair it with Woodpecker CI only after hardening its permissive edges: require approval for every untrusted pull request, allowlist clone/plugins by immutable digest, provide no secrets to untrusted events, disable privileged/trusted repositories by default, and place agents in disposable VMs or equivalently isolated workers with no production network or credentials. Enable and verify TLS for server-agent gRPC (`WOODPECKER_GRPC_SECURE=true`, `WOODPECKER_GRPC_VERIFY=true`), issue a unique token per agent rather than a system-wide token, and disable user agent registration unless explicitly required.

GitLab CE is a conditional open-core alternative when its integration and existing operational maturity win. GitLab Free approvals are optional and do not prevent an unapproved merge; required approval rules and important audit capabilities are paid-tier boundaries. Do not claim CE enforces review. Add an independently enforced approval/promotion control and external audit trail, or record the paid/managed edition as a security exception.

For every CI engine, never share a privileged runner or host container socket with untrusted branches/forks. Separate build and deployment identities, protect environments/branches/tags, and keep production credentials out of general CI.

OpenTofu is the IaC default. Protect and encrypt remote state, pin providers/modules, plan in CI, require review for apply, and constrain the execution identity. Argo CD becomes useful with Kubernetes, but GitOps does not make auditability or rollback free: protect the source repository, verify artifacts, scope projects/repositories/destinations, restrict cluster credentials, require promotion approval, and test rollback paths.

**Deeper:** `devops:gitlab-ci`, `devops:opentofu`, `devops:argocd`, `devops:ansible`, `devops:gitops`.

### Keep observability off the public attack surface

Instrument with OpenTelemetry and use Prometheus, Alertmanager, and Grafana when SLOs or multiple services justify them. Bind collectors and metrics endpoints to private networks; require TLS and SSO at user-facing gateways; restrict Grafana datasource permissions; redact secrets, tokens, personal data, and high-cardinality identifiers; and treat alert routes/webhooks as credentials.

Prometheus and its exporters generally trust HTTP input and are not designed as hostile multi-tenant boundaries. Do not expose them directly to the internet. Use OpenSearch for logs only when its cluster and dashboards are likewise private, authenticated, and least-privileged.

Keep security audit events distinct from debug telemetry. Send identity, privilege/admin, configuration, deployment, secret/key, and sensitive-data access events to an access-separated, tamper-resistant sink with synchronized timestamps and retention aligned to response/legal needs. Name the response owner and rehearse triage, containment, evidence preservation, credential rotation, and recovery.

**Deeper:** `monitoring:opentelemetry`, `monitoring:prometheus`, `monitoring:grafana`, `monitoring:elk`.

## Security Control Plane and Supply Chain

### Identity and secrets

Framework sessions are safer than introducing an identity platform the team cannot operate for a single application. Keycloak becomes the default identity provider when centralized OIDC/OAuth2/SAML, federation, multiple clients, or delegated administration is required. Separate administrator accounts, require MFA, restrict redirect URIs, rotate signing keys deliberately, and design for outage/recovery.

Use **sops + age** for encrypted deployment configuration. Choose **OpenBao** for dynamic credentials, leases, PKI, audit devices, and a high-assurance open-governance secrets service. Choose **Infisical** when a smaller team needs a simpler UI/workflow and its MIT-licensed core provides every required production control; explicitly inventory features under its proprietary `ee` tree before adoption. Do not call an open-core boundary “fully open source.”

Do not prescribe database transparent encryption universally. Classify the data and threat first, then choose filesystem/volume, database, column, or application-layer protection. For `age`, backup, signing, TLS, and application encryption keys, document custodians, authorized decryption locations, separation from ciphertext, rotation/revocation triggers, escrow/recovery, and the test proving old data remains recoverable when intended.

### Required software-supply-chain controls

Use controls as pipeline gates, not as a pile of dashboards:

| Control | Open-source default | Minimum policy |
|---|---|---|
| Dependency updates | Renovate | Small reviewed updates; urgent security path; lockfiles required |
| Secret detection | Gitleaks | Pre-commit plus CI; revoke leaked credentials, never merely delete them |
| Vulnerability/misconfiguration scan | Trivy | Scan source, IaC, image, and SBOM; defined severity/exception SLA |
| SBOM generation | Syft or an ecosystem-native generator | Emit CycloneDX or SPDX per release; attest, retain, and link to artifact digest |
| Dependency risk inventory | Dependency-Track | Track exploitable exposure and remediation ownership |
| Signing and provenance | Sigstore Cosign | Verify at promotion/deploy; protect signing identity and transparency evidence |
| Repository posture | OpenSSF Scorecard | Investigate high-signal failures; do not use one aggregate score as proof |
| Kubernetes admission (only when Kubernetes is selected) | Kyverno | Enforce trusted registries/signatures and restricted workload settings |

Add Semgrep CE for SAST and OWASP ZAP for DAST where applicable. Falco, Wazuh, and Suricata are detection options after prevention, logs, owners, and response procedures exist. Detection without someone authorized and prepared to respond is theater.

**Deeper:** `security:keycloak`, `security:infisical`, `security:sops`, `security:cert-manager`, `security:semgrep`, `security:zap`, `security:falco`, `security:wazuh`, `security:suricata`.

## Infrastructure Decisions

### Edge and networking

Caddy is the ordinary application-edge default because automatic HTTPS and safe certificate renewal reduce configuration-sensitive failure. Keep its admin API private and restrict trusted proxy ranges. Use Nginx when its mature routing/tuning ecosystem or existing operational expertise wins; use HAProxy for a dedicated high-control L4/L7 load balancer; use Envoy when an application/platform genuinely needs its service-proxy model.

Default-deny at every meaningful boundary. WireGuard is the remote/site tunnel default; CoreDNS is the cluster DNS default; NetBox is the source-of-truth option for a network estate. DNS, VPN, and firewall control planes require separate administrative access and configuration backup.

**Deeper:** `networking:nginx`, `networking:haproxy`, `networking:envoy`, `networking:coredns`, `networking:wireguard`, `networking:opnsense`, `networking:netbox`.

### Storage and backup

Do not deploy Ceph for one application server. Use a local filesystem—OpenZFS where supported—with restic or BorgBackup to an encrypted, access-separated, off-site target. Snapshots are not backups; keep an immutable or append-only copy with a deletion identity unavailable to the protected workload, and test full and granular restores. For the highest-impact tier, add an offline or logically air-gapped copy.

Use Ceph only for multi-node block/file/object requirements, hardware sized for failure and recovery, and operators who can maintain quorum, capacity headroom, upgrades, and repair. An S3-compatible API reduces application changes but does not make migrations automatic: verify authentication, policy, versioning, locking, consistency, metadata, multipart, and lifecycle semantics, then test data integrity.

**Deeper:** `storage:ceph`, `storage:overview`.

### OS, virtualization, mail, and cloud

- **Ubuntu Server LTS:** install minimally and verify which repositories receive the required security coverage. The standard five-year guarantee is not equivalent across every package; use `ubuntu-security-status` and decide whether Ubuntu Pro or a different package source is required.
- **Proxmox VE:** use for a staffed on-prem virtualization platform, not as an automatic application dependency. Separate management, storage, tenant, and backup networks; require MFA and tested cluster/backup recovery.
- **Postfix:** prefer an authenticated internal relay. Internet delivery security includes abuse handling and reputation as well as SPF, DKIM, DMARC, TLS, queue controls, and bounce processing; a managed delivery exception can be safer.
- **Cloud:** there is no universal provider default. OpenStack and Apache CloudStack are qualifying open-source private-IaaS options, but operating a cloud is not automatically safer than consuming one. Containers, OpenTofu, and open formats improve portability only at chosen layers; provider identity, policy, networking, data, and managed services still create migration work.

**Deeper:** `os:ubuntu`, `virtualization:proxmox`, `mail-collab:postfix`, `cloud-platforms:overview`.

## Open-Source Preference Gate

Apply this after the Security Gate:

1. **OSI-approved production license.** Apache-2.0, MIT, BSD, MPL, LGPL, GPL, AGPL, PostgreSQL, and CDDL qualify. BSL, SSPL, ELv2, Commons Clause, and similar source-available terms do not.
2. **Production boundary is explicit.** Record which HA, SSO, policy, backup, audit, and administration features are outside the open-source edition. Open core is a risk to evaluate, not an automatic pass or failure.
3. **Governance and continuity are credible.** Prefer neutral foundations, multiple maintainers/vendors, public security reporting, reproducible releases, and a practical fork or migration path.
4. **Interfaces and data are portable.** Prefer documented standards and export formats, but verify semantics. “Compatible” is not “identical,” and migration is never assumed free.
5. **License obligations are reviewed in context.** AGPL is OSI-approved, but network-interaction and modification/distribution questions are fact-specific. Flag it for legal review; do not reduce it to “running is always fine” or “AGPL is unsafe.”

## Replacements, Exceptions, and Cautions

| Technology | Current treatment | Reason / preferred direction |
|---|---|---|
| Terraform | Do not adopt as an open-source default | BSL-licensed; use OpenTofu |
| HashiCorp Vault | Do not adopt as an open-source default | BSL-licensed; evaluate OpenBao, or Infisical for simpler needs |
| MinIO Community Edition | Do not use as the default | Project distribution/maintenance changes require fresh verification; use local backup storage or evaluate Ceph/managed object storage by scale |
| Linkerd | Eligible, conditional | Apache-2.0; verify current community artifact/support model as an operational constraint |
| GitLab CE | Eligible, conditional open core | Free approvals are not merge-blocking; add independent enforcement/audit or use an approved paid exception; isolate runners regardless of tier |
| Infisical | Eligible, conditional open core | MIT core plus proprietary `ee` code; inventory the exact deployed feature set |
| Grafana / Redis / Metabase / Proxmox | Eligible with AGPL obligations | AGPL is open source; record legal and distribution/network-use analysis where relevant |
| Docker Desktop | Proprietary exception | Docker Engine remains open source; prefer Podman for a fully open local toolchain |
| Public cloud / managed email / managed databases | Managed exception, when justified | Security capability and shared responsibility may outweigh self-hosting; document controls, data path, cost, and exit |

## Recommendation Output

For each greenfield request, return:

1. **Risk classification and assumptions** — exposure, data, tenancy, compliance, trust boundaries, recovery, operator capacity.
2. **Minimum stack** — only components needed now.
3. **Mandatory controls** — identities, network boundaries, supply chain, telemetry, backup/restore, and patch ownership.
4. **Earned escalations** — what requirement would add FastAPI/Next.js, Keycloak, RabbitMQ, Kubernetes, Airflow, Superset, Ceph, or a mesh.
5. **Exceptions and open-core boundaries** — why each is safer than the open-source alternative for this context, its owner, review date, and exit path.
6. **Verification record** — official sources and `verified_at` date for volatile license, lifecycle, security, and artifact claims.

Do not answer a security-first stack request with a long shopping list. A smaller defensible system is the default outcome.

## Keeping This Current

- Re-run the Security Gate before every new adoption and after a critical advisory, end-of-support notice, license change, artifact/distribution change, or major architecture shift.
- Verify single-vendor and open-core projects quarterly; verify all defaults at least twice yearly. This selection was revised in August 2026, but the source record—not this date—is authoritative.
- Update [references/security-verification.md](references/security-verification.md), this skill, trigger evals, and the `domain-expert-core` plugin version together when a default changes.
- A challenger becomes a default only when evidence shows the current default no longer wins for the baseline threat model. Preserve the decision rationale and migration implications.
