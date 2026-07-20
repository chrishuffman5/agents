#!/usr/bin/env bash
# ============================================================================
# Bash - System Health Report
#
# Purpose : Comprehensive system health overview including OS, CPU, memory,
#           disk usage, network interfaces, and top processes.
# Version : 1.0.0
# Targets : Bash 4.0+, Linux
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Operating System
#   2. CPU
#   3. Memory
#   4. Disk Usage
#   5. Network
#   6. Top Processes
# ============================================================================
set -euo pipefail

REPORT_FILE="/tmp/sysreport_$(date +%Y%m%d_%H%M%S).txt"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

section() { printf "\n${BOLD}${CYAN}=== %s ===${RESET}\n" "$1" | tee -a "$REPORT_FILE"; }
info()    { printf "${GREEN}%-20s${RESET} %s\n" "$1:" "$2" | tee -a "$REPORT_FILE"; }
warn()    { printf "${YELLOW}%-20s${RESET} %s\n" "$1:" "$2" | tee -a "$REPORT_FILE"; }
alert()   { printf "${RED}%-20s${RESET} %s\n" "$1:" "$2" | tee -a "$REPORT_FILE"; }

header() {
  local sep; sep=$(printf '=%.0s' {1..60})
  printf "${BOLD}%s${RESET}\n" "$sep" | tee -a "$REPORT_FILE"
  printf "${BOLD}  SYSTEM HEALTH REPORT -- %s${RESET}\n" "$(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$REPORT_FILE"
  printf "${BOLD}%s${RESET}\n" "$sep" | tee -a "$REPORT_FILE"
}

os_info() {
  section "OPERATING SYSTEM"
  info "Hostname" "$(hostname -f 2>/dev/null || hostname)"
  info "OS"       "$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -s)"
  info "Kernel"   "$(uname -r)"
  info "Arch"     "$(uname -m)"
  info "Uptime"   "$(uptime -p 2>/dev/null || uptime)"
}

cpu_info() {
  section "CPU"
  local cores model load1 load5 load15
  cores=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "?")
  model=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ //' || echo "unknown")
  read -r load1 load5 load15 _ < /proc/loadavg 2>/dev/null || load1="?"

  info "Model"    "$model"
  info "Cores"    "$cores"
  info "Load 1m"  "$load1"
  info "Load 5m"  "$load5"
  info "Load 15m" "$load15"

  if [[ "$cores" != "?" && "$load1" != "?" ]]; then
    local load_pct; load_pct=$(awk "BEGIN{printf \"%.0f\", ($load1/$cores)*100}")
    if ((load_pct > 90)); then alert "Load %" "$load_pct% (CRITICAL)"
    elif ((load_pct > 70)); then warn "Load %" "$load_pct% (WARNING)"
    else info "Load %" "$load_pct% (OK)"
    fi
  fi
}

memory_info() {
  section "MEMORY"
  if [[ -f /proc/meminfo ]]; then
    local total avail used used_pct cached
    total=$(awk '/MemTotal/{print $2}' /proc/meminfo)
    avail=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
    cached=$(awk '/^Cached/{print $2}' /proc/meminfo)
    used=$((total - avail))
    used_pct=$((used * 100 / total))

    info "Total"     "$((total / 1024 / 1024)) GB"
    info "Used"      "$((used / 1024 / 1024)) GB (${used_pct}%)"
    info "Available" "$((avail / 1024 / 1024)) GB"
    info "Cached"    "$((cached / 1024)) MB"

    if ((used_pct > 90)); then alert "Status" "CRITICAL"
    elif ((used_pct > 75)); then warn "Status" "WARNING"
    else info "Status" "OK"
    fi
  fi
}

disk_info() {
  section "DISK USAGE"
  printf "%-30s %8s %8s %8s %6s  %s\n" "Filesystem" "Size" "Used" "Avail" "Use%" "Mount" | tee -a "$REPORT_FILE"

  df -h --output=source,size,used,avail,pcent,target 2>/dev/null | tail -n +2 | while read -r fs size used avail pct mount; do
    local pct_num="${pct//%/}"
    if ((pct_num > 90)); then
      printf "${RED}%-30s %8s %8s %8s %6s  %s${RESET}\n" "$fs" "$size" "$used" "$avail" "$pct" "$mount"
    elif ((pct_num > 75)); then
      printf "${YELLOW}%-30s %8s %8s %8s %6s  %s${RESET}\n" "$fs" "$size" "$used" "$avail" "$pct" "$mount"
    else
      printf "%-30s %8s %8s %8s %6s  %s\n" "$fs" "$size" "$used" "$avail" "$pct" "$mount"
    fi
  done | tee -a "$REPORT_FILE"
}

network_info() {
  section "NETWORK"
  if command -v ip &>/dev/null; then
    ip -4 addr show | awk '/inet /{print $NF, $2}' | while read -r iface addr; do
      info "$iface" "$addr"
    done
  fi
  local gw; gw=$(ip route 2>/dev/null | awk '/^default/{print $3; exit}' || echo "unknown")
  info "Gateway" "$gw"
}

top_processes() {
  section "TOP PROCESSES (by CPU)"
  printf "%-8s %-12s %6s %6s %s\n" "PID" "USER" "CPU%" "MEM%" "CMD" | tee -a "$REPORT_FILE"
  ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=11{printf "%-8s %-12s %6s %6s %s\n",$2,$1,$3,$4,$11}' | tee -a "$REPORT_FILE"
}

main() {
  header
  os_info
  cpu_info
  memory_info
  disk_info
  network_info
  top_processes
  printf "\n${GREEN}Report saved: %s${RESET}\n" "$REPORT_FILE"
}

main "$@"
