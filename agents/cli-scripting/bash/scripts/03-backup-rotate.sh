#!/usr/bin/env bash
# ============================================================================
# Bash - Backup with Rotation
#
# Purpose : Create compressed backups of a directory with date-stamped names.
#           Automatically rotates old backups based on retention policy.
# Version : 1.0.0
# Targets : Bash 4.0+, Linux/macOS
# Safety  : Only deletes old backups matching the naming pattern.
#
# Usage:
#   ./03-backup-rotate.sh /var/www/html /backups
#   ./03-backup-rotate.sh -r 14 -c bzip2 /data /mnt/backup
# ============================================================================
set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
RETENTION_DAYS=7
COMPRESS="gzip"
DRY_RUN=false
VERBOSE=false

# ── Colors ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; RESET=''
fi

log()   { printf "${GREEN}[INFO]${RESET}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${RESET}  %s\n" "$*" >&2; }
error() { printf "${RED}[ERROR]${RESET} %s\n" "$*" >&2; }
die()   { error "$1"; exit "${2:-1}"; }

# ── Usage ────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] <source-dir> <backup-dir>

Create compressed backup of source-dir and rotate old backups.

Options:
  -r, --retention DAYS   Keep backups for N days (default: $RETENTION_DAYS)
  -c, --compress TYPE    Compression: gzip, bzip2, xz, none (default: gzip)
  -n, --dry-run          Show what would happen
  -v, --verbose          Verbose output
  -h, --help             Show help

Examples:
  $(basename "$0") /var/www/html /backups
  $(basename "$0") -r 14 -c bzip2 /data /mnt/backup
  $(basename "$0") --dry-run /etc /tmp/backups
EOF
  exit "${1:-0}"
}

# ── Parse args ───────────────────────────────────────────────────────────────
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -r|--retention) RETENTION_DAYS="$2"; shift 2 ;;
    -c|--compress)  COMPRESS="$2"; shift 2 ;;
    -n|--dry-run)   DRY_RUN=true; shift ;;
    -v|--verbose)   VERBOSE=true; shift ;;
    -h|--help)      usage 0 ;;
    -*)             die "Unknown option: $1" ;;
    *)              POSITIONAL+=("$1"); shift ;;
  esac
done

[[ ${#POSITIONAL[@]} -ge 2 ]] || die "Need source and backup directories. Use -h for help."
SOURCE_DIR="${POSITIONAL[0]}"
BACKUP_DIR="${POSITIONAL[1]}"

[[ -d "$SOURCE_DIR" ]] || die "Source not found: $SOURCE_DIR"

# ── Determine extension ─────────────────────────────────────────────────────
case "$COMPRESS" in
  gzip)  EXT=".tar.gz";  TAR_FLAG="z" ;;
  bzip2) EXT=".tar.bz2"; TAR_FLAG="j" ;;
  xz)    EXT=".tar.xz";  TAR_FLAG="J" ;;
  none)  EXT=".tar";     TAR_FLAG="" ;;
  *)     die "Unknown compression: $COMPRESS. Use gzip, bzip2, xz, or none." ;;
esac

# ── Create backup ────────────────────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASENAME=$(basename "$SOURCE_DIR")
BACKUP_FILE="${BACKUP_DIR}/${BASENAME}_${TIMESTAMP}${EXT}"

log "Source:      $SOURCE_DIR"
log "Destination: $BACKUP_FILE"
log "Compression: $COMPRESS"
log "Retention:   $RETENTION_DAYS days"

if $DRY_RUN; then
  log "[DRY RUN] Would create: $BACKUP_FILE"
else
  mkdir -p "$BACKUP_DIR"

  log "Creating backup..."
  tar -c${TAR_FLAG}f "$BACKUP_FILE" -C "$(dirname "$SOURCE_DIR")" "$BASENAME"

  SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
  log "Backup complete: $BACKUP_FILE ($SIZE)"
fi

# ── Rotate old backups ───────────────────────────────────────────────────────
log "Checking for old backups (older than $RETENTION_DAYS days)..."
PATTERN="${BASENAME}_[0-9]*${EXT}"
OLD_COUNT=0

while IFS= read -r old_backup; do
  [[ -n "$old_backup" ]] || continue
  OLD_COUNT=$((OLD_COUNT + 1))
  if $DRY_RUN; then
    log "[DRY RUN] Would delete: $old_backup"
  else
    $VERBOSE && log "Deleting: $old_backup"
    rm -f "$old_backup"
  fi
done < <(find "$BACKUP_DIR" -maxdepth 1 -name "$PATTERN" -mtime +"$RETENTION_DAYS" -type f 2>/dev/null)

if [[ $OLD_COUNT -eq 0 ]]; then
  log "No old backups to remove."
else
  log "Removed $OLD_COUNT old backup(s)."
fi

# ── Summary ──────────────────────────────────────────────────────────────────
REMAINING=$(find "$BACKUP_DIR" -maxdepth 1 -name "$PATTERN" -type f 2>/dev/null | wc -l)
log "Current backups in $BACKUP_DIR: $REMAINING"

if $VERBOSE; then
  find "$BACKUP_DIR" -maxdepth 1 -name "$PATTERN" -type f -printf "  %T+ %s %f\n" 2>/dev/null | sort -r
fi

log "Done."
