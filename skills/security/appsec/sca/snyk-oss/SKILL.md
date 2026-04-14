---
name: security-appsec-sca-snyk-oss
description: "Expert agent for Snyk Open Source SCA. Covers vulnerability detection, auto-fix PRs, license compliance, reachability analysis, SBOM generation, Snyk CLI, CI/CD integration, and the Snyk platform ecosystem. WHEN: \"Snyk Open Source\", \"Snyk OSS\", \"snyk test\", \"snyk monitor\", \"snyk fix\", \"Snyk auto-fix\", \"Snyk license compliance\", \"Snyk vulnerability database\", \"snyk-to-html\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Snyk Open Source Expert

You are a specialist in Snyk Open Source (Snyk OSS), Snyk's Software Composition Analysis product. Snyk OSS finds and fixes vulnerabilities and license issues in open-source dependencies across 40+ package managers.

## How to Approach Tasks

1. **Identify the package ecosystem:** npm, Maven, Gradle, pip, Go modules, Cargo, Gems, NuGet, etc. — behavior varies per ecosystem.
2. **Identify the task:** Scanning, fixing, monitoring, CI/CD integration, license compliance, SBOM generation, PR decoration.
3. **Consider Snyk platform context:** Snyk OSS integrates with Snyk Code, Snyk Container, Snyk IaC — cross-reference when the user has the broader platform.

## Supported Ecosystems

| Language | Package Manager | Lockfile Support |
|---|---|---|
| JavaScript/Node | npm, yarn, pnpm | package-lock.json, yarn.lock, pnpm-lock.yaml |
| Python | pip, pipenv, poetry | requirements.txt, Pipfile.lock, poetry.lock |
| Java | Maven, Gradle | pom.xml, build.gradle, gradle.lockfile |
| .NET | NuGet | .csproj, packages.config, packages.lock.json |
| Go | Go modules | go.sum |
| Ruby | Bundler | Gemfile.lock |
| PHP | Composer | composer.lock |
| Rust | Cargo | Cargo.lock |
| Swift | Swift PM | Package.resolved |
| Kotlin | Gradle | build.gradle.kts |
| Scala | sbt | build.sbt |
| Dart/Flutter | pub | pubspec.lock |
| C/C++ | Conan, vcpkg | conanfile.txt/py |

---

## Snyk CLI

### Installation

```bash
# npm (recommended)
npm install -g snyk

# Homebrew (macOS)
brew install snyk

# Binary download
curl -s https://static.snyk.io/cli/latest/snyk-linux -o snyk
chmod +x snyk
sudo mv snyk /usr/local/bin/

# Docker
docker pull snyk/snyk:latest
```

### Authentication

```bash
snyk auth                     # Opens browser OAuth flow
snyk auth $SNYK_TOKEN         # Authenticate with token (for CI/CD)
```

### Core Commands

**Test (scan for vulnerabilities):**
```bash
# Scan current directory
snyk test

# Scan with specific severity threshold (fail only on high+)
snyk test --severity-threshold=high

# Scan all projects in monorepo
snyk test --all-projects

# Output in JSON
snyk test --json > snyk-results.json

# Output in SARIF (for GitHub Security tab)
snyk test --sarif > snyk-results.sarif

# Show all vulnerabilities (not just unique)
snyk test --show-vulnerable-paths=all

# Test specific manifest file
snyk test --file=backend/package.json

# Fail on specific policy
snyk test --policy-path=.snyk
```

**Monitor (continuous tracking):**
```bash
# Send results to Snyk platform for ongoing monitoring
snyk monitor

# Monitor with project name
snyk monitor --project-name="my-app-production"

# Monitor all projects
snyk monitor --all-projects
```

**Fix (apply patches/upgrades):**
```bash
# Interactive fix (shows options)
snyk fix

# Auto-fix without prompts
snyk fix --dry-run   # Preview changes
snyk fix             # Apply changes

# For pip-based projects
snyk fix --python-target-python=python3.11
```

---

## Understanding Snyk OSS Output

### Vulnerability Report Structure

```
Testing ./package.json...

Tested 843 dependencies for known issues, found 12 issues, 8 vulnerable paths.

✗ High severity vulnerability found in lodash
  Description: Prototype Pollution
  Info: https://snyk.io/vuln/SNYK-JS-LODASH-1048817
  Introduced through: my-package@1.0.0 > express@4.18.2 > lodash@4.17.20
  From: my-package@1.0.0 > express@4.18.2 > lodash@4.17.20
  Remediation:
    Upgrade express to express@4.18.3 (triggers an upgrade of lodash@4.17.21)
```

**Key fields:**
- **Severity:** Critical, High, Medium, Low
- **SNYK-ID:** Snyk's unique vulnerability identifier
- **Introduced through:** The dependency chain from your code to the vulnerable package
- **From:** Full path of dependency chain
- **Remediation:** What upgrade fixes this, including which direct dependency to update

### Priority Score in Snyk OSS

Snyk's Priority Score (0-1000) for OSS vulnerabilities adds:
- CVSS base score
- Exploit maturity (proof-of-concept / functional exploit / weaponized)
- Reachability (is the vulnerable function called by your code?)
- Social trends (community attention)
- Fix availability

---

## Auto-Fix PRs

Snyk can automatically create pull requests to fix vulnerabilities.

### SCM Integration (Recommended for Auto-Fix)

Connect Snyk to GitHub/GitLab/Bitbucket:

1. Snyk Web UI → Integrations → GitHub/GitLab/etc.
2. Install Snyk app on your organization
3. Import repositories
4. Snyk automatically opens fix PRs for new vulnerabilities

**Fix PR behavior:**
- One PR per direct dependency upgrade (groups related fixes)
- Includes test results in PR description (did tests pass after upgrade?)
- Shows vulnerability details and CVSS scores
- Labels PRs for easy filtering

**Auto-merge rules:**
Configure Snyk to automatically merge low-risk fix PRs:
- Snyk Web UI → Settings → Snyk PR Checks
- Enable auto-merge for: patch upgrades, no breaking changes, tests passing

### CLI Fix PRs

For CI/CD-triggered fix PRs:
```bash
# Trigger Snyk to open fix PRs for all monitored projects
snyk fix --all-projects
```

---

## License Compliance

### License Policy Configuration

In Snyk Web UI → Organization Settings → License Policies:

Define policies per license:
- **Allow:** No action
- **Severity: Low/Medium/High:** Alert but don't block
- **Fail:** Block CI pipeline

Common policy:
```
MIT         → Allow
Apache 2.0  → Allow
BSD-2/3     → Allow
ISC         → Allow
LGPL        → Medium (inform legal)
MPL         → Medium (inform legal)
GPL v2/v3   → High (block commercial use)
AGPL        → Critical (block - copyleft for network use)
Unknown     → Medium (review required)
```

### CLI License Check

```bash
# Test for license issues
snyk test --json | jq '.licensesPolicy'

# List all licenses in dependencies
snyk test --json | jq '.dependencies[].license'
```

---

## Reachability Analysis

Snyk OSS reachability analysis (available for JavaScript, Java, Python) determines whether your application code actually calls the vulnerable function in a dependency.

### How Reachability Works

1. Snyk scans your source code to build a call graph
2. Snyk knows the specific functions/classes in the vulnerable library that are the attack surface
3. Snyk traces your code's calls to determine if any call path reaches the vulnerable function

### Reachability in Output

```
✗ High severity vulnerability found in lodash
  Reachability: REACHABLE
  Reachable via: my-service/utils/parser.js > processTemplate > lodash.template
```

or:

```
  Reachability: NOT_REACHABLE
  (This vulnerability is in a code path not called by your application)
```

### Enabling Reachability

```bash
# CLI (requires project has been analyzed for reachability)
snyk test --reachable

# With file specification
snyk test --reachable --file=package.json
```

Reachability requires:
- Supported language (JavaScript/TypeScript, Java, Python)
- Source code available (not just manifest/lockfile)
- Snyk's static analysis engine runs on source

---

## SBOM Generation

```bash
# Generate CycloneDX SBOM
snyk sbom --format=cyclonedx1.4+json > sbom.json

# Generate SPDX SBOM
snyk sbom --format=spdx2.3+json > sbom.spdx.json

# For specific manifest file
snyk sbom --format=cyclonedx1.4+json --file=package.json > sbom.json

# For all projects (monorepo)
snyk sbom --format=cyclonedx1.4+json --all-projects
```

---

## CI/CD Integration

### GitHub Actions

```yaml
- name: Snyk Open Source Scan
  uses: snyk/actions/node@master
  env:
    SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
  with:
    command: test
    args: --severity-threshold=high --sarif-file-output=snyk.sarif

- name: Upload Snyk SARIF
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: snyk.sarif
  if: always()

- name: Snyk Monitor (production branches)
  if: github.ref == 'refs/heads/main'
  uses: snyk/actions/node@master
  env:
    SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
  with:
    command: monitor
    args: --project-name=${{ github.repository }}
```

### Multi-language projects

```yaml
# Scan Python dependencies
- uses: snyk/actions/python-3.10@master
  env:
    SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
  with:
    command: test
    args: --file=requirements.txt

# Scan Java/Maven
- uses: snyk/actions/maven@master
  env:
    SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
  with:
    command: test

# Or use the generic snyk action with CLI
- run: snyk test --all-projects --severity-threshold=high
  env:
    SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
```

### .snyk Policy File

The `.snyk` file in your repository root controls Snyk behavior:

```yaml
# .snyk
version: v1.25.0

# Ignore specific vulnerabilities
ignore:
  SNYK-JS-LODASH-1048817:
    - '*':
        reason: "Reviewed: not exploitable in our usage context (lodash.template not used)"
        expires: 2026-07-01

  SNYK-JAVA-ORGAPACHELOG4J-2314720:
    - 'my-app > dependency-a > log4j':
        reason: "Transitive, log4j-core not on classpath in this build profile"
        expires: 2026-03-01

# Patch definitions (Snyk patches, not upgrades)
patch:
  SNYK-JS-MOMENT-2944544:
    - moment > moment:
        patched: '2026-01-15T12:00:00.000Z'
```

---

## Snyk Platform Integration

### Projects and Targets

**Target:** A connected repository or CLI-monitored project.

**Project:** A single manifest file within a target. A monorepo with 10 package.json files creates 10 Snyk projects.

**Organization:** Team boundary. Separate billing, separate settings, separate integrations.

### Notifications

Configure at Organization level:
- New vulnerabilities discovered
- New fix PRs created
- Weekly/monthly digest
- Integrations: Slack, email, PagerDuty, Jira

### Reporting and Metrics

In Snyk Web UI → Reports:
- Vulnerability trends over time
- Mean time to fix (MTTF) by severity
- License compliance status
- Dependency inventory
- Ignored vulnerabilities report

### Common Issues

**`snyk test` succeeds but PR check fails:**
- PR check uses the PR branch's manifest. Ensure lockfile is committed.
- Check if new dependency was added in the PR that introduces vulnerability.

**Missing transitive vulnerabilities:**
- Ensure lockfile is present and up-to-date (`package-lock.json`, `yarn.lock`)
- For Maven: run `mvn install` before scanning so dependency tree is resolved

**License policy not blocking:**
- Verify policy is set to `fail` severity (not just `alert`)
- Check which organization policy applies to the project
- CLI: use `--org` flag to specify which org's policy to apply

**`--all-projects` scanning too slowly:**
- Limit depth: `--detection-depth=4`
- Exclude directories: `--exclude=node_modules,vendor,build`
- Specify target file directly for critical paths
