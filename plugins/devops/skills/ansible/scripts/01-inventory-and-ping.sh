#!/usr/bin/env bash
# Purpose:        Inventory structure review plus connectivity sweep - is Ansible's world view correct and reachable?
# Applies to:     Ansible 2.15+ / ansible-core (run from the project directory with its ansible.cfg)
# Read-only:      yes (ping module executes no changes; it verifies auth + Python)
# Inputs:         __INVENTORY__ - inventory path or leave to ansible.cfg default
# Interpretation: UNREACHABLE = SSH/WinRM/auth layer (key, bastion, firewall) - nothing Ansible-specific. FAILED on
#                 ping = connected but no usable Python interpreter (interpreter discovery). Hosts missing from the
#                 graph = inventory source problem (dynamic inventory plugin auth is the classic). Fix reachability
#                 before debugging any playbook - half of "playbook is broken" is inventory drift.
# Next step:      02-check-mode-diff.sh to preview a playbook against the now-verified inventory

set -euo pipefail
INV="${1:-__INVENTORY__}"

echo "== Inventory graph"
ansible-inventory -i "$INV" --graph

echo
echo "== Connectivity sweep"
ansible all -i "$INV" -m ping -o | sort | awk '{print} /UNREACHABLE|FAILED/ {bad++} END {print "---"; print "problem hosts: " (bad+0)}'
