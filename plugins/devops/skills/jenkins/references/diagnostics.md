# Jenkins Diagnostics

## Pipeline Failures

### Groovy Sandbox Violations

```
org.jenkinsci.plugins.scriptsecurity.sandbox.RejectedAccessException:
Scripts not permitted to use method groovy.json.JsonSlurper parseText java.lang.String
```

**Cause**: Pipeline script called a method not whitelisted in the Groovy sandbox.

**Resolution:**
1. Manage Jenkins > In-process Script Approval > Approve the method
2. Or move the code to a shared library (trusted, runs outside sandbox)
3. Or use `@NonCPS` annotation (but only for non-serializable operations)
4. Or use Pipeline Utility Steps plugin (`readJSON`, `readYaml`) instead of raw Groovy

### CPS Serialization Errors

```
java.io.NotSerializableException: java.util.regex.Matcher
```

**Cause**: CPS pipeline tried to serialize a non-serializable object across a step boundary.

**Resolution:**
```groovy
// Move non-serializable code to @NonCPS method
@NonCPS
def extractVersion(String text) {
    def matcher = (text =~ /version: (\d+\.\d+\.\d+)/)
    return matcher[0][1]
}
```

### Declarative Pipeline Validation Errors

```
WorkflowScript: 15: Expected a stage @ line 15, column 5
```

**Resolution:**
- Use the **Pipeline Syntax** generator: `<jenkins-url>/pipeline-syntax/`
- Use the **Declarative Directive Generator**: `<jenkins-url>/directive-generator/`
- Check indentation and Declarative structure requirements

## Agent Issues

### Agent Offline

```
Agent 'linux-01' is offline
```

**Diagnosis:**
1. Check agent process: `ps aux | grep remoting.jar` (SSH), `ps aux | grep agent.jar` (JNLP)
2. Check network connectivity between controller and agent
3. Check agent logs: `$JENKINS_HOME/logs/slaves/<agent-name>/`
4. Check controller logs: Manage Jenkins > System Log

**Resolution:**
```bash
# SSH agent: controller initiates connection
# Verify SSH access manually
ssh -i /path/to/key jenkins@agent-host

# JNLP agent: agent initiates connection
# Restart agent process
java -jar agent.jar -url https://jenkins.example.com -secret <SECRET> -name <AGENT_NAME>

# WebSocket agent
java -jar agent.jar -url https://jenkins.example.com -secret <SECRET> -name <AGENT_NAME> -webSocket
```

### Agent Disk Full

```
java.io.IOException: No space left on device
```

**Resolution:**
1. Clean workspaces: Manage Jenkins > Manage Nodes > Configure > set workspace retention
2. Clean old builds: Configure build rotation on each job
3. Clean Docker images: `docker system prune -a` (if using Docker)
4. Add `cleanWs()` to post-always in all pipelines

```groovy
post {
    always {
        cleanWs()
    }
}
```

### Docker Agent Issues

```
docker: Error response from daemon: driver failed programming external connectivity
```

**Diagnosis:**
1. Docker daemon running? `systemctl status docker`
2. Docker socket accessible? `ls -la /var/run/docker.sock`
3. Jenkins user in docker group? `groups jenkins`
4. Port conflicts? Check if the requested port is already in use

## Plugin Issues

### Plugin Dependency Conflicts

```
Failed to load: Some Plugin v2.0 - Plugin is disabled
  - Required plugin: other-plugin 3.0 (protocol)
  - Available: other-plugin 2.5
```

**Resolution:**
1. Update the dependency: Manage Jenkins > Manage Plugins > Updates
2. If the required version doesn't exist: check plugin compatibility matrix
3. Consider removing the problematic plugin if not essential

### Plugin After Update Issues

**Symptoms**: Jenkins fails to start or behaves differently after plugin update.

**Resolution:**
1. Check Manage Jenkins > Manage Plugins > Installed for errors
2. Rollback: replace the `.jpi` file in `$JENKINS_HOME/plugins/` with the previous version
3. Pin the version: create `<plugin>.jpi.pinned` file

```bash
# Rollback a plugin
cd $JENKINS_HOME/plugins/
cp git.jpi git.jpi.new
cp git.jpi.bak git.jpi    # Restore backup
touch git.jpi.pinned       # Prevent auto-update
systemctl restart jenkins
```

## Performance Issues

### Slow UI / High CPU

**Diagnosis:**
1. Check Jenkins heap usage: Manage Jenkins > System Information
2. Thread dump: Manage Jenkins > Manage Nodes > Thread Dump (or `kill -3 <pid>`)
3. Check build queue: large queue = not enough agents

**Resolution:**
- Increase heap: `JAVA_OPTS="-Xmx4g"`
- Reduce build retention: `buildDiscarder(logRotator(numToKeepStr: '10'))`
- Remove unused plugins
- Avoid heavy operations on controller (move to agents)

### Slow Pipeline Execution

**Diagnosis:**
1. Add `timestamps()` option to see time per step
2. Check agent provisioning time (K8s pod creation, Docker pull)
3. Check for sequential steps that could be parallel

**Resolution:**
```groovy
pipeline {
    options {
        timestamps()  // Add timestamps to console output
    }
    stages {
        stage('Parallel Tests') {
            parallel {
                stage('Unit') { steps { sh 'npm run test:unit' } }
                stage('E2E')  { steps { sh 'npm run test:e2e' } }
                stage('Lint') { steps { sh 'npm run lint' } }
            }
        }
    }
}
```

## Debugging Techniques

### Replay

1. Navigate to a failed build
2. Click "Replay"
3. Edit the pipeline script
4. Run again (without committing changes)

Useful for iterating on pipeline logic without commits.

### Pipeline Durability (Debug Mode)

```groovy
// Temporarily set for debugging
pipeline {
    options {
        durabilityHint('MAX_SURVIVABILITY')  // More checkpoints, survives restart
    }
}
```

### Console Output Analysis

Key patterns in console output:

```
[Pipeline] Start of Pipeline          // Pipeline begins
[Pipeline] node                       // Agent allocation
[Pipeline] { (Build)                  // Stage entry
+ npm ci                              // Command execution (+ prefix = echoed command)
[Pipeline] }                          // Stage exit
[Pipeline] End of Pipeline            // Pipeline ends
Finished: SUCCESS                     // Final result
```

### Script Console (Admin)

Manage Jenkins > Script Console — run arbitrary Groovy on the controller:

```groovy
// List all jobs
Jenkins.instance.allItems(Job.class).each {
    println "${it.fullName} - ${it.lastBuild?.result}"
}

// Check agent status
Jenkins.instance.computers.each {
    println "${it.name}: ${it.isOnline() ? 'ONLINE' : 'OFFLINE'}"
}

// Check installed plugins
Jenkins.instance.pluginManager.plugins.each {
    println "${it.shortName}: ${it.version}"
}
```

**Warning**: Script Console runs with full Jenkins admin privileges. Use with extreme caution in production.
