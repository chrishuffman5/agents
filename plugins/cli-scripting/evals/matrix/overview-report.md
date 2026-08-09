# overview — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `cli-scripting` · runs: **928 / 1633** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| overview-slowest-startup | recent | Among Bash, PowerShell, and Python as scripting languages for CLI automation, which one has the slowest startup time when you launch a new script? Answer concisely. | contains_all: `PowerShell` |
| overview-lowest-learning-curve | recent | Among Bash, PowerShell, and Python as scripting languages for CLI automation, which one is rated as having the lowest learning curve? Answer concisely. | contains_all: `Python` |
| overview-exit-code-zero | stable | Across Bash, PowerShell, and Python scripts, what does an exit code of zero from a completed process conventionally indicate? Answer concisely. | regex: `(?i)\bsuccess\b` |
| overview-python-returncode | stable | In Python, when you call subprocess.run to run an external command and want to check its exit code, which attribute on the returned CompletedProcess object holds that code? Answer with the exact attribute name. | contains_all: `returncode` |
| overview-migration-r-count | stable | In cloud migration planning, application portfolios are typically assessed against a set of standard strategies often nicknamed by a letter, covering options such as retire, rehost, and refactor. How many distinct strategies does this framework include in total? Answer with just the number. | regex: `(?i)\b(seven|7)\b` |
| overview-relocate-vmware | recent | In the cloud migration strategy framework, one strategy called Relocate refers specifically to moving workloads without changing the underlying hypervisor platform. Which specific virtualization technology does Relocate usually refer to moving between cloud provider environments? Answer concisely. | contains_all: `VMware` |
| overview-finops-phases | stable | The FinOps Foundation framework breaks cloud financial management into three iterative phases that organizations cycle through continuously rather than complete once. Name all three phases in order. Answer concisely. | contains_all: `Inform``, ``Optimize``, ``Operate` |
| overview-gcp-labels-tags | recent | When applying consistent cost allocation tagging across a multi cloud environment that includes Google Cloud, practitioners sometimes get tripped up because GCP uses two different terms for similar sounding concepts. Which term does GCP reserve specifically for the key value metadata used in billing and cost allocation: labels or tags? Answer concisely with just the correct term. | regex: `(?i)\blabels\b` |
| overview-containerd-no-build | stable | Among Docker, Podman, and containerd, which container runtime has no built-in image build capability, requiring BuildKit to be run separately? Answer concisely. | contains_all: `containerd` |
| overview-immutable-infra | stable | Under the immutable infrastructure principle for container platforms, when an application needs to change, should you patch the running container in place or build and deploy a new image? Answer in one sentence. | regex: `(?i)(new image|never patch)` |
| overview-compose-anti-pattern | stable | For a small project running on a single host with no scaling requirements, is Docker Compose considered a fine choice rather than always defaulting to Kubernetes? Answer in one sentence. | regex: `(?i)compose.{0,20}(fine|acceptable|sufficient|works)` |
| overview-rocky-alma-path | recent | We need a RHEL compatible Linux distribution that requires no paid subscription but still tracks RHEL's binary compatibility guarantees for regulatory workloads. Per cross platform OS selection guidance, what is this no subscription path usually called? Answer concisely. | contains_all: `Rocky``, ``Alma` |
| overview-selinux-family | stable | Across the RHEL family of distributions and SLES, which mandatory access control mechanism handles security enforcement, as opposed to AppArmor on Ubuntu and Debian? Answer concisely. | regex: `(?i)\bSELinux\b` |
| overview-test-first | stable | Across every platform covered, Linux mandatory access control, Windows Group Policy, macOS MDM profiles, what universal hyphenated testing principle should precede switching any hardening control into full enforcement? Give the term used. | regex: `(?i)test[- ]first` |
| overview-cap-cassandra-classification | stable | Under CAP theorem classification, are Cassandra and DynamoDB typically categorized as CP systems or AP systems during a network partition? Answer with the two-letter classification. | regex: `(?i)\bap\b` |
| overview-denormalization-ratio | stable | In general database design guidance, denormalization becomes worth considering once the read to write ratio exceeds what threshold? Answer with the exact ratio. | regex: `100\s*:\s*1` |
| overview-mongodb-doc-size-limit | stable | When deciding whether to embed or reference child data in a document database such as MongoDB, what document size limit is commonly cited as the threshold favoring embedding? Answer with the exact size. | regex: `(?i)\b16\s*mb\b` |
| overview-ci-pipeline-speed | recent | According to DevOps pipeline design guidance, roughly how fast should a CI pipeline run so it does not reduce merge frequency and increase batch sizes? Answer concisely with a number. | contains_all: `10``, ``minute` |
| overview-trunk-branch-lifespan | recent | In the trunk-based development guidance here, how short should feature branches ideally be kept before merging back to trunk? Answer concisely. | regex: `(?i)(1\s*day|one\s*day|24\s*hours)` |
| overview-iac-state-anti-pattern | stable | What DevOps anti-pattern is named for running Terraform without remote state and locking on a team, and what does the guidance say results from it? | contains_all: `corruption` |
| overview-exactly-once-practicality | stable | For event-driven architectures spanning a message broker and external systems, is achieving true exactly-once delivery generally considered practical? Answer in one sentence. | regex: `(?i)(impractical|not\s*practical)` |
| overview-gcp-native-queue | recent | Among the major cloud providers, does Google Cloud offer a distinct native point-to-point queue service separate from its pub/sub offering? Answer in one sentence. | regex: `(?i)\bno\b` |
| overview-latency-nats-core | stable | For a workload that needs sub-millisecond, fire-and-forget message delivery, which messaging technology is typically recommended? Answer concisely. | contains_all: `NATS` |
| overview-quorum-min-nodes | stable | For a Proxmox or a KVM and libvirt cluster to support HA without adding a QDevice, how many physical nodes are recommended as the minimum? Answer concisely with a number. | regex: `\b3\b|\bthree\b` |
| overview-cpu-vendor-migration | stable | Across major hypervisor platforms, is live migration of a running VM directly between an Intel based host and an AMD based host supported? Answer in one sentence. | regex: `(?i)(\bno\b|not\s+supported|cannot)` |
| overview-gpu-partitioning | recent | General virtualization platform comparisons note a VMware feature introduced in 2025 for partitioning a single physical GPU across multiple VMs, alongside vGPU and DDA. What is that feature called? Answer concisely. | contains_all: `GPU-P` |
| overview-object-storage-db | stable | For database or VM storage workloads that need block access, should a team choose object storage such as S3 or MinIO instead? Answer with yes or no and a brief reason. | regex: `(?i)\b(no|avoid)\b` |
| overview-scale-out-threshold | stable | At what data scale does storage architecture guidance recommend moving to scale-out platforms like Ceph or cloud object storage instead of traditional enterprise arrays? Answer concisely. | regex: `(?i)\b1\s?pb\b` |
| overview-minio-licensing-change | recent | According to current guidance comparing software-defined object storage options, what changed about MinIO licensing as of February 2026? Answer concisely. | contains_all: `commercial` |
| overview-use-method-creator | stable | Who is credited with creating the USE method (Utilization, Saturation, Errors) for monitoring system resources? Answer concisely. | contains_all: `Gregg` |
| overview-red-method-creator | recent | Who created the RED method (Rate, Errors, Duration) for monitoring services? Answer concisely. | contains_all: `Wilkie` |
| overview-obs-spend-pct | recent | Observability spend can reach what percentage of total infrastructure cost, according to general cost guidance? Answer concisely. | regex: `\b30\b` |
| overview-large-scale-stack | stable | For data platforms handling more than 10 terabytes with a dedicated platform team, which combination of technologies does cross-platform ETL guidance recommend? Answer concisely. | contains_all: `Spark``, ``Kafka``, ``Airflow` |
| overview-small-scale-stack | stable | For a small team working with under 10 gigabytes of data, which lightweight technology combination does cross-platform ETL guidance recommend? Answer concisely. | contains_all: `DuckDB` |
| overview-first-principle | stable | Among the core data integration principles for building ETL pipelines, which property is described as non-negotiable, requiring every pipeline to produce the same result no matter how many times it is rerun with the same input? Answer with the single term used. | regex: `(?i)\bidempoten` |
| overview-hybrid-mailbox-threshold | stable | When migrating an on-premises Exchange organization to Exchange Online, at what mailbox count does a full hybrid deployment become the recommended approach instead of a simple cutover migration? Answer concisely. | regex: `\b150\b` |
| overview-mx-ttl | stable | Ahead of a mail platform cutover, what TTL value in seconds should you lower your MX records to, so DNS changes propagate quickly during the transition? Answer concisely. | regex: `\b300\b` |
| overview-e3-pricing | recent | Roughly what is the list price per user per month for Microsoft 365 E3, in US dollars, based on current enterprise pricing benchmarks? Answer concisely with an approximate figure. | regex: `\b36\b` |
| overview-sse-autoreconnect | stable | Comparing WebSocket and Server-Sent Events, which of the two provides automatic reconnection built in, without the application writing its own reconnect logic? Answer concisely. | regex: `(?i)\bsse\b|server.sent` |
| overview-ws-latency-range | recent | For sub-10ms message delivery requirements handled over WebSocket after the handshake completes, what typical latency range in milliseconds is cited for it? Answer concisely. | regex: `(?i)0\.5.{0,5}10\s*ms` |
| overview-microservice-graphql-overkill | stable | For internal microservice-to-service communication, which protocol is called out as overkill compared to gRPC or REST: GraphQL or OData? Answer concisely. | regex: `(?i)graphql` |
| overview-workflow-patterns | stable | Name the five workflow patterns for agentic system design, listed in ascending order of autonomy, per the building-effective-agents framework. Answer concisely. | contains_all: `chaining``, ``orchestrator``, ``evaluator` |
| overview-three-failure-modes | stable | What are the three documented failure modes that justify splitting a single AI agent into multiple agents with separate context windows? Answer concisely. | contains_all: `laziness``, ``preferential``, ``drift` |
| overview-enterprise-rollout-shape | recent | What rollout timeframe does vendor guidance suggest for a phased deployment of a platform like Claude Cowork, instead of an enterprise-wide big-bang? Answer concisely. | regex: `(?i)six.month` |
| overview-mixing-grains-mistake | stable | In dimensional modeling, what is described as the number-one mistake a team can make when defining a fact table? Answer concisely. | regex: `(?i)mix(ing)?\s+grains?` |
| overview-galaxy-schema | stable | What term describes a dimensional model with multiple fact tables that share conformed dimensions? Answer concisely. | regex: `(?i)(galaxy schema|fact constellation)` |
| overview-adhoc-sql-tools | recent | For a data team doing ad-hoc SQL querying directly against warehouses, which three analytics tools are named as strong candidates? Answer concisely. | contains_all: `DuckDB``, ``Superset``, ``Metabase` |
| overview-islands-model | stable | Which rendering model, used primarily by Astro, serves static HTML by default and hydrates only the components that need interactivity? Answer concisely. | regex: `(?i)island` |
| overview-vue-reactivity-model | stable | Per general frontend guidance, which framework uses a proxy-based reactivity system that tracks property access on reactive objects, as distinct from virtual DOM diffing or a compiler-driven approach? Answer concisely. | regex: `(?i)\bvue\b` |
| overview-rsc-requirements | recent | Per general frontend guidance, which specific React version paired with which routing system is currently needed to run React Server Components in a production app? Answer concisely with both. | contains_all: `19``, ``Next.js` |
| overview-rps-threshold | recent | At roughly what requests-per-second range do Go, Rust, or ASP.NET Core start to show a meaningful edge over other backend frameworks? Answer concisely. | regex: `(?i)(10\s*k|10,000).{0,20}(100\s*k|100,000)` |
| overview-techempower-benchmark | stable | Do TechEmpower framework benchmarks actually measure real application performance, or do they measure hello world request throughput? Answer concisely. | regex: `(?i)hello.?world` |
| overview-bottleneck-database | stable | When choosing a backend framework, what single component is repeatedly identified as the real performance bottleneck rather than the framework itself? Answer concisely. | regex: `(?i)\bdatabase\b` |
| overview-three-tier-endpoints | recent | Up to roughly how many endpoints is a traditional three-tier core/distribution/access network architecture generally considered a good fit for, before other designs become more appropriate? Answer concisely. | regex: `(?i)(10,?000|10k)` |
| overview-spine-leaf-dc | stable | For a data center fabric with heavy east-west traffic between servers, is a three-tier architecture or a spine-leaf Clos fabric generally the better fit? Answer concisely. | regex: `(?i)spine-?leaf` |
| overview-rfc1918 | stable | Which three IP address ranges are reserved by RFC 1918 for private, internal network addressing? Answer concisely. | contains_all: `10.0.0.0``, ``172.16.0.0``, ``192.168.0.0` |
| overview-exfiltration-mitigations | recent | In a defense-in-depth mapping of MITRE ATT&CK tactics to key mitigations, what four categories of controls are listed as key mitigations for the Exfiltration tactic? Answer concisely. | contains_all: `CASB``, ``network monitoring` |
| overview-nist-csf-functions | stable | What are the six core functions of NIST Cybersecurity Framework 2.0 that organize a security program? Answer concisely, listing all six. | contains_all: `Govern``, ``Identify``, ``Protect``, ``Detect``, ``Respond``, ``Recover` |
| overview-identity-layer-tools | recent | In a defense-in-depth layered controls table covering MFA, SSO, PAM, and conditional access, which three example identity security tools are listed for the Identity layer? Answer concisely. | contains_all: `Entra``, ``Okta``, ``CyberArk` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 471 | **75.8%** | 12.6s | 372 | $36.0978 | $0.1011 |
| no-skill | 457 | **68.5%** | 11.9s | 295 | $17.6779 | $0.0565 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 78.2% | 69.3% | +8.9pp | 12.4s | 12s |
| codex | 83.6% | 78.8% | +4.8pp | 11.2s | 7.9s |
| pi | 40.4% | 39.6% | +0.8pp | 16.9s | 20.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 60.3% | 10.6s | $0.035 |
| claude-haiku-4-5 | no-skill | 61.4% | 9.2s | $0.0244 |
| claude-opus-5 | skill | 92.9% | 11.2s | $0.1838 |
| claude-opus-5 | no-skill | 74.6% | 12.6s | $0.0874 |
| claude-sonnet-5 | skill | 87.5% | 6.7s | $0.1061 |
| claude-sonnet-5 | no-skill | 70.8% | 5s | $0.0743 |
| gemma4:12b | skill | 84.4% | 25.6s | $0.1205 |
| gemma4:12b | no-skill | 75% | 22.6s | $0.0974 |
| glm-4.7-flash:q4_K_M-32k | skill | 75% | 12.5s | $0.1388 |
| glm-4.7-flash:q4_K_M-32k | no-skill | 75% | 11.3s | $0.1439 |
| gpt-5.6-luna | skill | 91.7% | 10.4s | $0.002 |
| gpt-5.6-luna | no-skill | 75% | 5.7s | $0.0006 |
| gpt-5.6-sol | skill | 83.3% | 13.4s | $0.0864 |
| gpt-5.6-sol | no-skill | 78.8% | 8.1s | $0.0219 |
| gpt-5.6-terra | skill | 87.5% | 10.8s | $0.0228 |
| gpt-5.6-terra | no-skill | 87.5% | 9.2s | $0.0059 |
| ollama/gemma4:12b | skill | 43.8% | 5.7s | $0 |
| ollama/gemma4:12b | no-skill | 37.5% | 6s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | skill | 31.2% | 2.7s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | no-skill | 31.2% | 2.3s | $0 |
| ollama/qwen3.6:27b | skill | 46.7% | 44.1s | $0 |
| ollama/qwen3.6:27b | no-skill | 50% | 52.6s | $0 |

_Full per-cell aggregates (harness × model × effort × mode) in `overview-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
