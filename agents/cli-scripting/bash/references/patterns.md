# Bash Patterns Reference

> Script template, argument parsing, logging, file locking, parallel execution.

---

## 1. Script Template

```bash
#!/usr/bin/env bash
# ==============================================================================
# script-name.sh -- Short description
# Usage: script-name.sh [options] <required-arg>
# ==============================================================================
set -euo pipefail
IFS=$'\n\t'

# Constants
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
readonly LOG_FILE="${LOG_FILE:-/tmp/${SCRIPT_NAME%.sh}_${TIMESTAMP}.log}"

VERBOSE=${VERBOSE:-false}
DRY_RUN=false
OUTPUT_DIR="."

# Colors (disable if not terminal)
if [[ -t 1 ]]; then
  RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; YELLOW=''; GREEN=''; CYAN=''; BOLD=''; RESET=''
fi

# Logging
log()   { printf '%s [INFO]  %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG_FILE"; }
warn()  { printf "${YELLOW}%s [WARN]  %s${RESET}\n" "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG_FILE" >&2; }
error() { printf "${RED}%s [ERROR] %s${RESET}\n" "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG_FILE" >&2; }
debug() { $VERBOSE && printf "${CYAN}%s [DEBUG] %s${RESET}\n" "$(date '+%H:%M:%S')" "$*" >&2 || true; }
die()   { error "$1"; exit "${2:-1}"; }

# Cleanup
TMPDIR_WORK=""
cleanup() {
  local exit_code=$?
  debug "Cleanup (exit code: $exit_code)"
  [[ -d "$TMPDIR_WORK" ]] && rm -rf "$TMPDIR_WORK"
  exit $exit_code
}
trap cleanup EXIT
trap 'die "Interrupted" 130' INT
trap 'die "Terminated" 143' TERM

# Usage
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] <required-arg>

Options:
  -h, --help          Show this help
  -v, --verbose       Verbose output
  -n, --dry-run       Dry run
  -o, --output DIR    Output directory (default: .)

Examples:
  $SCRIPT_NAME -v myarg
  $SCRIPT_NAME --dry-run --output /tmp myarg
EOF
  exit "${1:-0}"
}

# Argument parsing
parse_args() {
  POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)     usage 0 ;;
      -v|--verbose)  VERBOSE=true; shift ;;
      -n|--dry-run)  DRY_RUN=true; shift ;;
      -o|--output)   OUTPUT_DIR="$2"; shift 2 ;;
      --output=*)    OUTPUT_DIR="${1#*=}"; shift ;;
      --)            shift; POSITIONAL+=("$@"); break ;;
      -*)            die "Unknown option: $1" ;;
      *)             POSITIONAL+=("$1"); shift ;;
    esac
  done
  [[ ${#POSITIONAL[@]} -ge 1 ]] || die "Missing argument. Use -h for help."
  REQUIRED_ARG="${POSITIONAL[0]}"
}

# Prerequisites
check_prereqs() {
  local missing=()
  for cmd in curl jq awk; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  [[ ${#missing[@]} -eq 0 ]] || die "Missing: ${missing[*]}"
}

# Main
main() {
  parse_args "$@"
  check_prereqs
  TMPDIR_WORK=$(mktemp -d)
  log "Starting $SCRIPT_NAME"
  mkdir -p "$OUTPUT_DIR"

  if $DRY_RUN; then
    log "[DRY RUN] Would process: $REQUIRED_ARG"
  else
    log "Processing: $REQUIRED_ARG"
  fi

  log "Done."
}

main "$@"
```

---

## 2. Argument Parsing

### getopts (Short Options)

```bash
usage() { echo "Usage: $0 [-v] [-o output] [-n count] arg"; exit 1; }

VERBOSE=false; OUTPUT=""; COUNT=1

while getopts ':vo:n:h' opt; do
  case $opt in
    v) VERBOSE=true ;;
    o) OUTPUT="$OPTARG" ;;
    n) COUNT="$OPTARG"
       [[ "$COUNT" =~ ^[0-9]+$ ]] || { echo "-n must be integer"; exit 1; }
       ;;
    h) usage ;;
    :) echo "Option -$OPTARG requires argument"; exit 1 ;;
    ?) echo "Unknown: -$OPTARG"; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
```

### Subcommands Pattern

```bash
cmd_start() {
  local port=8080
  while [[ $# -gt 0 ]]; do
    case $1 in
      -p|--port) port=$2; shift 2 ;;
      *) echo "Unknown: $1"; exit 1 ;;
    esac
  done
  echo "Starting on port $port"
}

cmd_stop()   { echo "Stopping..."; }
cmd_status() { echo "Status..."; }

[[ $# -ge 1 ]] || { echo "Usage: $0 {start|stop|status}"; exit 1; }
subcommand=$1; shift
case $subcommand in
  start)  cmd_start "$@" ;;
  stop)   cmd_stop "$@" ;;
  status) cmd_status "$@" ;;
  *) echo "Unknown: $subcommand"; exit 1 ;;
esac
```

---

## 3. Logging with Colors

```bash
LOG_LEVEL=${LOG_LEVEL:-INFO}
declare -A LEVEL_NUM=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)
CURRENT_LEVEL=${LEVEL_NUM[$LOG_LEVEL]:-1}

_log() {
  local level=$1; shift
  [[ ${LEVEL_NUM[$level]:-0} -ge $CURRENT_LEVEL ]] || return 0
  local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
  local color
  case $level in
    DEBUG) color=$CYAN ;; INFO) color=$GREEN ;;
    WARN) color=$YELLOW ;; ERROR) color=$RED ;;
  esac
  printf "${color}${ts} [%-5s]${RESET} %s\n" "$level" "$*" >&2
  printf "${ts} [%-5s] %s\n" "$level" "$*" >> "${LOG_FILE:-/dev/null}"
}

log_debug() { _log DEBUG "$@"; }
log_info()  { _log INFO  "$@"; }
log_warn()  { _log WARN  "$@"; }
log_error() { _log ERROR "$@"; }

# Progress bar
progress_bar() {
  local current=$1 total=$2 width=${3:-50}
  local pct=$((current * 100 / total))
  local filled=$((current * width / total))
  local empty=$((width - filled))
  printf "\r[%s%s] %d%%" \
    "$(printf '#%.0s' $(seq 1 $filled))" \
    "$(printf ' %.0s' $(seq 1 $empty))" "$pct"
}
```

---

## 4. File Locking

```bash
# flock — script-level mutex
(
  flock -x 200
  echo "Exclusive work..."
  sleep 5
) 200>/var/lock/myscript.lock

# Non-blocking
(
  flock -n 200 || { echo "Already running"; exit 1; }
  echo "Got the lock"
) 200>/var/lock/myscript.lock

# Lock entire script
LOCKFILE="/var/lock/${0##*/}.lock"
exec 9>"$LOCKFILE"
flock -n 9 || { echo "Script already running"; exit 1; }

# PID file pattern
PIDFILE="/var/run/myscript.pid"
check_already_running() {
  if [[ -f "$PIDFILE" ]]; then
    local old_pid; old_pid=$(cat "$PIDFILE")
    if kill -0 "$old_pid" 2>/dev/null; then
      echo "Already running as PID $old_pid"; exit 1
    fi
    rm -f "$PIDFILE"
  fi
}
trap 'rm -f "$PIDFILE"' EXIT
check_already_running
echo $$ > "$PIDFILE"
```

---

## 5. Parallel Execution

### xargs -P

```bash
find . -name "*.jpg" | xargs -P 4 -I{} convert {} {}.png
find . -name "*.log" -print0 | xargs -0 -P 8 gzip
cat urls.txt | xargs -P 5 -I{} curl -s -o /dev/null -w "%{http_code} {}\n" {}

# With exported function
process_file() { gzip "$1"; echo "Compressed: $1"; }
export -f process_file
find . -name "*.log" | xargs -P 4 -I{} bash -c 'process_file "$@"' _ {}
```

### Background Jobs with wait

```bash
pids=()
for host in host1 host2 host3; do
  ssh "$host" 'uptime' &
  pids+=($!)
done

failed=0
for pid in "${pids[@]}"; do
  wait "$pid" || ((failed++))
done
echo "Failed: $failed"

# Job pool (limit concurrency)
MAX_JOBS=4
run_with_pool() {
  local func=$1; shift
  while [[ $(jobs -r | wc -l) -ge $MAX_JOBS ]]; do sleep 0.1; done
  "$func" "$@" &
}
```

### GNU parallel

```bash
parallel -j4 gzip {} ::: *.log
parallel -j8 process_item :::: items.txt
cat urls.txt | parallel -j10 curl -s -o /dev/null -w "%{http_code} {}\n" {}
parallel --progress --retries 3 -j4 command {} ::: items
```
