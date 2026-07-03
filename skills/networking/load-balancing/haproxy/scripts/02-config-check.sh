#!/usr/bin/env bash
# Purpose:        Validate HAProxy configuration and show what would change - the gate before any reload
# Applies to:     HAProxy 2.4+
# Read-only:      yes
# Inputs:         __CONFIG__ - config path (default /etc/haproxy/haproxy.cfg)
# Interpretation: '-c' failing = a reload right now would keep the OLD config running (HAProxy refuses bad configs)
#                 but a RESTART would kill the service entirely - fix before any systemctl restart. Warnings about
#                 deprecated directives are your upgrade to-do list. Diff your pending config against the running
#                 process's file (ps shows -f path) - drift between the file and the running process is a classic
#                 "who edited what" incident.
# Next step:      Fix errors, then 'systemctl reload haproxy' (never restart when reload suffices - reload is hitless)

set -euo pipefail
CONFIG="${1:-__CONFIG__}"

echo "== Syntax check"
haproxy -c -f "$CONFIG" && echo "config: VALID"

echo
echo "== Version and build"
haproxy -v

echo
echo "== Running process config path (compare against $CONFIG)"
ps -eo args | grep '[h]aproxy' | head -3
