# Jenkins Architecture

## Controller/Agent Model

```
┌─────────────────────────────────────┐
│         Jenkins Controller          │
│                                     │
│  ┌──────────┐  ┌────────────────┐  │
│  │  Web UI   │  │  REST API     │  │
│  └──────────┘  └────────────────┘  │
│                                     │
│  ┌──────────┐  ┌────────────────┐  │
│  │  Plugin   │  │  Job Queue    │  │
│  │  Manager  │  │  & Scheduler  │  │
│  └──────────┘  └────────┬───────┘  │
│                          │         │
│  ┌──────────┐  ┌────────▼───────┐  │
│  │  SCM      │  │  Build        │  │
│  │  Polling  │  │  Dispatcher   │  │
│  └──────────┘  └────────┬───────┘  │
│                          │         │
│  ┌──────────────────────▼────────┐ │
│  │     JENKINS_HOME              │ │
│  │  (jobs, plugins, configs)     │ │
│  └───────────────────────────────┘ │
└──────────────┬──────────────────────┘
               │ (JNLP, SSH, or WebSocket)
    ┌──────────┼──────────┐
    │          │          │
┌───▼──┐  ┌───▼──┐  ┌───▼──┐
│Agent │  │Agent │  │Agent │
│  1   │  │  2   │  │  3   │
└──────┘  └──────┘  └──────┘
```

### Controller Responsibilities

| Component | Purpose |
|---|---|
| **Web UI / API** | User interface and REST API |
| **Job configuration** | Store and manage job definitions |
| **Build queue** | Queue pending builds, match to agents |
| **Plugin management** | Load, configure, and update plugins |
| **Security** | Authentication, authorization, CSRF protection |
| **SCM polling** | Check repositories for changes |
| **Build history** | Store build results, logs, artifacts |

### Agent Communication

| Protocol | Setup | Use Case |
|---|---|---|
| **JNLP (Inbound)** | Agent connects to controller | Agents behind firewall |
| **SSH (Outbound)** | Controller connects to agent via SSH | Linux agents with SSH access |
| **WebSocket** | Agent connects via WebSocket | Modern, through load balancers |

### Agent Executors

Each agent has a configurable number of executors (concurrent build slots):

- **1 executor**: Isolation between builds, simpler resource management
- **N executors**: Better utilization, but builds share workspace and resources
- **Best practice**: 1 executor per agent for isolation (especially with Docker/K8s agents that auto-scale)

## Plugin System

### Plugin Architecture

```
Jenkins Core
    │
    ├── Extension Points (interfaces)
    │   ├── Builder
    │   ├── Publisher
    │   ├── SCM
    │   ├── Trigger
    │   ├── Agent
    │   └── 200+ more
    │
    └── Plugin Manager
        ├── Plugin A (implements Builder, Publisher)
        ├── Plugin B (implements SCM)
        └── Plugin C (depends on Plugin A)
```

### Plugin Storage

```
$JENKINS_HOME/
├── plugins/
│   ├── git.jpi           # Plugin archive
│   ├── git/              # Extracted plugin
│   └── git.jpi.pinned    # Prevent auto-update
├── jobs/
│   └── my-job/
│       ├── config.xml    # Job configuration
│       └── builds/       # Build history
├── config.xml            # Global configuration
├── credentials.xml       # Encrypted credentials
└── secrets/              # Encryption keys
```

### Plugin Dependency Management

- Plugins declare dependencies in their `pom.xml`
- Jenkins automatically resolves and installs dependencies
- **Conflict risk**: Two plugins requiring different versions of a shared dependency
- **Mitigation**: Keep plugins updated, remove unused plugins, test upgrades in staging

## Pipeline Engine

### Pipeline Steps

Pipeline steps are the atomic units of execution:

| Category | Examples |
|---|---|
| **SCM** | `checkout`, `git` |
| **Build** | `sh`, `bat`, `powershell` |
| **Flow** | `parallel`, `retry`, `timeout`, `waitUntil` |
| **Input** | `input`, `milestone` |
| **Artifacts** | `archiveArtifacts`, `stash`, `unstash` |
| **Notifications** | `mail`, `slackSend` |
| **Credentials** | `withCredentials` |
| **Docker** | `docker.build`, `docker.image` |
| **Utilities** | `readJSON`, `writeFile`, `sh(returnStdout)` |

### Groovy CPS (Continuation-Passing Style)

Pipeline scripts run in a CPS-transformed Groovy environment:

- **Serializable**: Pipeline state can be persisted and resumed (survive controller restart)
- **Limitations**: Some Groovy/Java constructs don't work in CPS mode (try-with-resources, some closures)
- **`@NonCPS`**: Annotate methods that should run outside CPS (faster, but not resumable)

```groovy
// This method runs outside CPS — faster but cannot be paused/resumed
@NonCPS
def parseJson(String json) {
    new groovy.json.JsonSlurper().parseText(json)
}
```

### Groovy Sandbox

- Pipeline scripts run in a Groovy sandbox by default
- Unapproved method calls require administrator approval (Manage Jenkins > In-process Script Approval)
- Shared library code can be trusted (runs outside sandbox) or untrusted (sandboxed)
- **Security implication**: Be careful about which shared libraries are trusted — they can run arbitrary code

## Distributed Builds

### Kubernetes Plugin Architecture

```
Jenkins Controller
    │
    ├── Kubernetes Plugin
    │   ├── Pod Template definitions
    │   └── Cloud configuration (K8s API endpoint)
    │
    └── When build starts:
        1. Plugin creates a Pod in K8s with JNLP agent container
        2. Agent connects to controller via WebSocket/JNLP
        3. Build executes in the pod
        4. Pod is destroyed after build completes
```

### Docker Plugin Architecture

```
Jenkins Controller
    │
    ├── Docker Plugin
    │   └── Docker host configuration
    │
    └── When build starts:
        1. Plugin creates a Docker container with Jenkins agent
        2. Agent connects to controller
        3. Build executes in the container
        4. Container is removed after build
```

## High Availability

Jenkins does not natively support active-active HA. Strategies:

| Strategy | How | Limitations |
|---|---|---|
| **Active-passive** | Standby controller with shared storage | Manual failover, JENKINS_HOME on shared FS |
| **CloudBees HA** | Commercial HA with automatic failover | Requires CloudBees license |
| **Stateless controller** | Configuration as Code, ephemeral controller | Build history not preserved on failover |
| **Multiple controllers** | Separate controllers per team/project | No shared state, duplicate config |

### Jenkins Configuration as Code (JCasC)

```yaml
# jenkins.yaml
jenkins:
  systemMessage: "Jenkins configured via JCasC"
  numExecutors: 0    # No builds on controller
  securityRealm:
    ldap:
      configurations:
        - server: ldap.example.com
  authorizationStrategy:
    roleBased:
      roles:
        global:
          - name: admin
            permissions: [Overall/Administer]

unclassified:
  location:
    url: https://jenkins.example.com/
```
