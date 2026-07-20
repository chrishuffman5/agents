---
name: overview
description: "Cross-language CLI and scripting guidance for IT automation, system administration, and DevOps workflows: language selection (Bash vs PowerShell vs Python vs Node.js), pipes, exit codes, environment variables, argument parsing, error handling, and cross-platform scripting best practices. WHEN: \"which scripting language\", \"Bash vs PowerShell\", \"Bash vs Python\", \"CLI\", \"command line\", \"scripting\", \"shell script\", \"automation script\", \"cron\", \"task scheduler\", \"shell\", \"terminal\", \"pipe\", \"redirect\", \"stdin\", \"stdout\", \"stderr\", \"exit code\", \"shebang\". Do NOT use for single-technology syntax, commands, or debugging — read that technology's skill directly (e.g. `powershell`, `bash`, `python`, `nodejs`, `aws-cli`, `azure-cli`, `kubectl`)."
license: MIT
---

# CLI & Scripting Domain Overview

This skill covers cross-language guidance for command-line interfaces and scripting languages used in IT automation, system administration, and DevOps: language selection, and the patterns (exit codes, streams, env vars, argument parsing, error handling) that recur across every shell/language. Read it for language-selection and cross-language questions; read a technology skill directly for implementation depth.

## When to Use This Skill vs. a Technology Skill

**Use this skill when the question is cross-language or about picking a tool:**
- "Should I write this in Bash or Python?"
- "What's the PowerShell equivalent of Bash's `set -euo pipefail`?"
- "How do exit codes work across shells?"
- "General scripting best practices for a new automation project"

**Read a technology skill directly when the question is technology-specific:**
- "PowerShell pipeline / advanced function / remoting question" -> `powershell` skill
- "Bash quoting / sed / awk / jq question" -> `bash` skill
- "Python argparse / pathlib / subprocess question" -> `python` skill
- "Node.js CLI tool / fetch / stream question" -> `nodejs` skill
- "AWS CLI command / JMESPath query" -> `aws-cli` skill
- "Azure CLI (`az`) command" -> `azure-cli` skill
- "kubectl command / debugging a pod" -> `kubectl` skill

## How to Approach Tasks

1. **Identify the language** -- Look for file extensions, shebang lines, syntax patterns, or explicit mentions. If unclear, ask or recommend based on the task.

2. **Route to a technology skill** -- Read the matching skill above for deep expertise.

3. **Apply cross-language principles** -- The concepts below apply regardless of language.

4. **Recommend** -- Provide actionable, tested guidance.

## Language Selection Guide

Choose the right tool for the job:

### Use Bash When
- Running on Linux/macOS and the task is gluing existing CLI tools together
- Processing text streams with grep, sed, awk, jq
- Writing cron jobs, systemd timers, CI/CD pipeline steps
- Task requires < 100 lines and involves mostly command orchestration
- You need maximum portability across Unix systems (POSIX sh subset)
- File manipulation with find, rsync, tar, chmod

### Use PowerShell When
- Managing Windows systems (Active Directory, Registry, IIS, Windows Services)
- Working with structured data (objects, not text) through pipelines
- Need cross-platform scripting with rich type system
- Interacting with .NET APIs, COM objects, WMI/CIM
- Building tools that need `-WhatIf`, `-Confirm`, `-Verbose` support
- Azure/M365 administration (Az module, Microsoft Graph)

### Use Python When
- Task exceeds ~100 lines or involves complex logic
- Need third-party libraries (requests, pandas, paramiko, boto3)
- Building reusable tools with proper argument parsing
- Data processing, API integration, or report generation
- Cross-platform scripts that need to handle binary data, encoding, or complex I/O
- When maintainability matters more than brevity

### Decision Matrix

| Factor | Bash | PowerShell | Python |
|--------|------|------------|--------|
| Text stream processing | Best | Good | Good |
| Structured data / objects | Poor | Best | Good |
| Windows administration | Poor | Best | Fair |
| Linux administration | Best | Good | Good |
| API interaction | Fair | Good | Best |
| Complex logic (>100 LOC) | Poor | Good | Best |
| Third-party ecosystem | Fair | Good | Best |
| Startup time | Fastest | Slow | Fast |
| Learning curve | Medium | Medium | Low |

## Cross-Language Concepts

### Exit Codes

Every process returns an integer exit code. Zero means success; non-zero means failure.

```bash
# Bash: $? holds last exit code
command
echo $?                    # 0 = success
```

```powershell
# PowerShell: $LASTEXITCODE for native commands, $? for cmdlets
git status
$LASTEXITCODE              # 0 = success
Get-Item missing.txt
$?                         # $false = cmdlet failed
```

```python
# Python: subprocess.run returns CompletedProcess with .returncode
import subprocess
result = subprocess.run(["git", "status"], capture_output=True)
result.returncode          # 0 = success
```

### Standard Streams (stdin, stdout, stderr)

All three languages work with three standard streams: stdin (fd 0), stdout (fd 1), stderr (fd 2).

```bash
# Bash: redirect with >, 2>, &>, |
command > out.txt 2> err.txt    # separate stdout/stderr
command 2>&1 | tee log.txt      # combine and tee
command < input.txt              # pipe file to stdin
```

```powershell
# PowerShell: streams are numbered (1=output, 2=error, 3=warning, etc.)
command > out.txt 2> err.txt
command *> all.txt               # all streams
Write-Error "problem" 2> Variable:errs
```

```python
# Python: subprocess handles streams explicitly
result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
print(result.stdout)
print(result.stderr)
```

### Environment Variables

```bash
# Bash: export for child processes
export API_KEY="secret"
echo "$API_KEY"
API_KEY=val command             # set for single command only
```

```powershell
# PowerShell: $env: drive
$env:API_KEY = 'secret'
[System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
```

```python
# Python: os.environ dict
import os
key = os.environ.get("API_KEY", "default")
os.environ["NEW_VAR"] = "value"  # for child processes
```

### Argument Parsing Patterns

```bash
# Bash: getopts (short) or manual while/case (long options)
while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose) VERBOSE=true; shift ;;
    -o|--output)  OUTPUT="$2"; shift 2 ;;
    *)            ARGS+=("$1"); shift ;;
  esac
done
```

```powershell
# PowerShell: param() block with attributes
param(
    [Parameter(Mandatory)][string]$Path,
    [ValidateSet('csv','json')][string]$Format = 'csv',
    [switch]$Verbose
)
```

```python
# Python: argparse module
import argparse
parser = argparse.ArgumentParser(description="My tool")
parser.add_argument("path", help="Input file")
parser.add_argument("-f", "--format", choices=["csv","json"], default="csv")
parser.add_argument("-v", "--verbose", action="store_true")
args = parser.parse_args()
```

### Error Handling Patterns

```bash
# Bash: set -euo pipefail + trap
set -euo pipefail
trap 'echo "Error at line $LINENO"; exit 1' ERR
```

```powershell
# PowerShell: try/catch + $ErrorActionPreference
$ErrorActionPreference = 'Stop'
try { risky_operation } catch { Write-Error $_.Exception.Message }
```

```python
# Python: try/except with specific exceptions
try:
    risky_operation()
except FileNotFoundError as e:
    logging.error("File missing: %s", e)
    sys.exit(1)
```

### Pipe / Pipeline Patterns

Pipes connect commands. Each language handles them differently:

- **Bash**: Text streams. Each stage processes lines of text. `cmd1 | cmd2 | cmd3`
- **PowerShell**: Object pipelines. Each stage processes .NET objects with properties. `Get-Process | Where-Object CPU -gt 50 | Select-Object Name, CPU`
- **Python**: No built-in pipe operator. Chain via function calls, generators, or subprocess pipes.

### Signal Handling

```bash
# Bash: trap for signals
trap 'cleanup; exit' INT TERM HUP
trap cleanup EXIT
```

```powershell
# PowerShell: Register-EngineEvent or try/finally
try { long_operation } finally { cleanup }
```

```python
# Python: signal module
import signal
signal.signal(signal.SIGTERM, lambda sig, frame: cleanup())
```

## Common Pitfalls

**1. Forgetting to quote variables in Bash**
Unquoted variables undergo word splitting and glob expansion. Always use `"$var"`, never bare `$var`.

**2. Ignoring exit codes**
Always check `$?` (Bash), `$LASTEXITCODE` (PowerShell), or `.returncode` (Python subprocess). Unchecked failures cascade silently.

**3. Using shell=True in Python subprocess**
`subprocess.run(cmd, shell=True)` is a command injection risk. Pass a list of arguments instead: `subprocess.run(["git", "status"])`.

**4. Hardcoding paths with wrong separators**
Use `os.path.join()` or `pathlib.Path` in Python, `Join-Path` in PowerShell, and `"$dir/$file"` in Bash. Never hardcode `\` or `/`.

**5. Not handling encoding**
Specify `encoding="utf-8"` explicitly in Python file operations. In PowerShell, use `-Encoding UTF8`. In Bash, ensure `LANG` or `LC_ALL` is set.

**6. Running destructive operations without dry-run mode**
Always implement `--dry-run` / `-WhatIf` for scripts that modify, delete, or move files.

## Technology Skills

For deep expertise in a specific technology, read:

- `powershell` skill -- PowerShell 7.4/7.6 LTS: pipelines, modules, remoting, parallel execution
- `bash` skill -- Bash 5.x: variables, text processing (grep/sed/awk/jq), process management, networking
- `python` skill -- Python 3.10-3.14: file ops, subprocess, HTTP/API, argparse, system automation
- `nodejs` skill -- Node.js 20/22/24/26: file system, child_process, fetch, CLI tool building, npm
- `aws-cli` skill -- AWS CLI v2: authentication, JMESPath, IAM, S3, Lambda, CloudFormation, and more
- `azure-cli` skill -- Azure CLI (`az`): authentication, resource groups, VMs, AKS, Key Vault, and more
- `kubectl` skill -- kubectl: kubeconfig, output formats, workload/networking/RBAC commands, debugging
