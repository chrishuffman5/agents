# Jenkins Best Practices

## Pipeline Design

### Use Declarative Pipeline

```groovy
// Prefer Declarative for new pipelines
pipeline {
    agent { label 'linux' }
    stages {
        stage('Build') {
            steps {
                sh 'make build'
            }
        }
    }
}

// Use script {} blocks for complex logic within Declarative
stage('Conditional Deploy') {
    steps {
        script {
            def version = sh(returnStdout: true, script: 'cat VERSION').trim()
            if (version.startsWith('v')) {
                sh "deploy.sh ${version}"
            }
        }
    }
}
```

### No Builds on the Controller

```yaml
# JCasC: Set controller executors to 0
jenkins:
  numExecutors: 0    # All builds run on agents
```

Building on the controller is a security risk (build code runs with controller permissions) and a stability risk (runaway builds can crash the controller).

### Shared Libraries for Reuse

```groovy
// vars/standardPipeline.groovy
def call(Map config) {
    pipeline {
        agent { label config.agent ?: 'linux' }
        stages {
            stage('Checkout') {
                steps { checkout scm }
            }
            stage('Build') {
                steps { sh config.buildCmd }
            }
            stage('Test') {
                steps { sh config.testCmd }
            }
            stage('Deploy') {
                when { branch 'main' }
                steps { sh config.deployCmd }
            }
        }
        post {
            always {
                junit config.testResults ?: '**/test-results/*.xml'
                cleanWs()
            }
        }
    }
}
```

### Pipeline Durability

```groovy
pipeline {
    options {
        durabilityHint('PERFORMANCE_OPTIMIZED')  // Faster, less durable
        // Other options: 'MAX_SURVIVABILITY' (default), 'SURVIVABLE_NONATOMIC'
    }
}
```

## Security

### Harden the Controller

1. **Enable CSRF protection**: Manage Jenkins > Security > CSRF Protection (default since 2.x)
2. **Disable CLI over Remoting**: Manage Jenkins > Security > enable Agent → Controller Access Control
3. **Use HTTPS**: Configure reverse proxy (Nginx, Apache) with TLS termination
4. **Restrict script approval**: Review every script approval carefully
5. **Disable signup**: Use external auth (LDAP, SAML, OIDC)

### Credential Best Practices

```groovy
// GOOD: Credentials bound to specific scope
withCredentials([string(credentialsId: 'api-key', variable: 'API_KEY')]) {
    sh 'curl -H "Authorization: Bearer $API_KEY" https://api.example.com'
}

// BAD: Printing credentials (even indirectly)
echo "Key is: ${env.API_KEY}"    // NEVER do this
```

- Use **Folder-level credentials** to limit scope
- Use **Domain-restricted credentials** where possible
- Rotate credentials regularly
- Use external secret managers (Vault, AWS Secrets Manager) via plugins

### Plugin Security

1. **Minimize plugins** — Every plugin is attack surface. Remove unused plugins.
2. **Update regularly** — Check Manage Jenkins > Manage Plugins > Updates weekly
3. **Security advisories** — Subscribe to Jenkins security mailing list
4. **Audit** — Review installed plugins quarterly, remove deprecated ones
5. **Pin trusted versions** — Use `.jpi.pinned` files in `$JENKINS_HOME/plugins/`

## Administration

### Backup Strategy

```bash
# Backup JENKINS_HOME (excluding builds and workspace)
rsync -avz --exclude='jobs/*/builds' \
            --exclude='jobs/*/workspace' \
            --exclude='.cache' \
            $JENKINS_HOME/ /backup/jenkins/

# Critical files to always back up:
# - config.xml (global config)
# - credentials.xml (encrypted credentials)
# - secrets/ (encryption keys — without these, credentials are unrecoverable)
# - jobs/*/config.xml (job definitions)
# - users/ (user configs)
# - nodes/ (agent configs)
```

### Upgrade Strategy

1. **Read changelog** — Check for breaking changes and security fixes
2. **Backup first** — Full JENKINS_HOME backup
3. **Test in staging** — Run a staging Jenkins with production config
4. **Update plugins first** — Update plugins to compatible versions before core upgrade
5. **LTS track** — Use LTS releases for stability (update every ~3 months)

### Configuration as Code (JCasC)

```yaml
# jenkins.yaml — version-controlled, reproducible configuration
jenkins:
  numExecutors: 0
  clouds:
    - kubernetes:
        name: "k8s"
        serverUrl: "https://kubernetes.default"
        namespace: "jenkins"
        podTemplates:
          - name: "default"
            containers:
              - name: "jnlp"
                image: "jenkins/inbound-agent:latest"

credentials:
  system:
    domainCredentials:
      - credentials:
          - string:
              scope: GLOBAL
              id: "github-token"
              secret: "${GITHUB_TOKEN}"    # From environment variable

unclassified:
  location:
    url: "https://jenkins.example.com/"
```

### Performance Tuning

```bash
# JVM options for the controller
JAVA_OPTS="-Xms2g -Xmx4g \
           -XX:+UseG1GC \
           -XX:+ParallelRefProcEnabled \
           -Dhudson.model.LoadStatistics.clock=5000"
```

| Setting | Recommendation |
|---|---|
| **Heap** | 2-4 GB for small, 4-8 GB for large installations |
| **GC** | G1GC (default in modern JVMs) |
| **Build rotation** | Keep last 10-20 builds (`buildDiscarder`) |
| **Workspace cleanup** | Always use `cleanWs()` in post |
| **Executors** | Match to CPU cores on agents |

## Common Mistakes

1. **Building on the controller** — Set controller executors to 0. Always use agents.
2. **Not using Jenkinsfile** — Pipeline-as-code (Jenkinsfile in SCM) over UI-configured jobs.
3. **Too many plugins** — Each plugin adds memory, startup time, and attack surface. Less is more.
4. **No shared libraries** — Copy-pasting Jenkinsfiles across repos leads to drift and maintenance burden.
5. **Ignoring Groovy sandbox** — Approving arbitrary script methods without review is a security risk.
6. **No backup of secrets/** — Without the `secrets/` directory, all encrypted credentials are permanently lost.
