#!/usr/bin/env bash
# ============================================================================
# Google Compute Engine - Instance Health Dashboard
#
# Purpose : Comprehensive GCE health report including instance inventory,
#           disk health, firewall rules audit, unattached resources,
#           and static IP usage.
# Version : 1.0.0
# Targets : gcloud CLI with authenticated project
# Safety  : Read-only. No modifications to GCP resources.
#
# Sections:
#   1. Project and Identity
#   2. Instance Inventory
#   3. Persistent Disk Health
#   4. Unattached Disks
#   5. Firewall Rules Audit
#   6. Static IP Usage
#   7. Snapshot Inventory
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

PROJECT=$(gcloud config get-value project 2>/dev/null || echo "unknown")

# ── Section 1: Project and Identity ────────────────────────────────────────
section "SECTION 1 - Project and Identity"

ACCOUNT=$(gcloud config get-value account 2>/dev/null || echo "unknown")
ZONE=$(gcloud config get-value compute/zone 2>/dev/null || echo "not set")
REGION=$(gcloud config get-value compute/region 2>/dev/null || echo "not set")

echo "  Project  : $PROJECT"
echo "  Account  : $ACCOUNT"
echo "  Zone     : $ZONE"
echo "  Region   : $REGION"

# ── Section 2: Instance Inventory ──────────────────────────────────────────
section "SECTION 2 - Instance Inventory"

echo "  Name                          | Zone                  | Machine Type         | Status     | External IP"
echo "  ------------------------------|----------------------|---------------------|------------|----------------"

gcloud compute instances list \
  --format="csv[no-heading](name,zone.basename(),machineType.basename(),status,networkInterfaces[0].accessConfigs[0].natIP)" \
  2>/dev/null | \
  while IFS=',' read -r name zone mtype status extip; do
    printf "  %-31s | %-20s | %-19s | %-10s | %s\n" \
      "$name" "$zone" "$mtype" "$status" "${extip:-none}"
  done || echo "  [ERROR] Unable to list instances"

echo ""
running=$(gcloud compute instances list --filter="status=RUNNING" --format="value(name)" 2>/dev/null | wc -l || echo "0")
terminated=$(gcloud compute instances list --filter="status=TERMINATED" --format="value(name)" 2>/dev/null | wc -l || echo "0")
echo "  Running: $running | Terminated (stopped): $terminated"

# ── Section 3: Persistent Disk Health ──────────────────────────────────────
section "SECTION 3 - Persistent Disk Health"

gcloud compute disks list \
  --format="csv[no-heading](name,zone.basename(),sizeGb,type.basename(),status,users.basename())" \
  2>/dev/null | \
  while IFS=',' read -r name zone size dtype status users; do
    printf "  %-30s | %-15s | %5s GB | %-12s | %-8s | %s\n" \
      "$name" "$zone" "$size" "$dtype" "$status" "${users:-unattached}"
  done || echo "  [ERROR] Unable to list disks"

# ── Section 4: Unattached Disks ────────────────────────────────────────────
section "SECTION 4 - Unattached Disks (Cost Review)"

unattached=$(gcloud compute disks list \
  --filter="NOT users:*" \
  --format="csv[no-heading](name,zone.basename(),sizeGb,type.basename())" \
  2>/dev/null)

if [[ -n "$unattached" ]]; then
    echo "$unattached" | while IFS=',' read -r name zone size dtype; do
        printf "  [WARN] %-30s | %-15s | %5s GB | %s\n" "$name" "$zone" "$size" "$dtype"
    done
else
    echo "  [OK] No unattached disks found"
fi

# ── Section 5: Firewall Rules Audit ────────────────────────────────────────
section "SECTION 5 - Firewall Rules with 0.0.0.0/0 Source"

gcloud compute firewall-rules list \
  --filter="sourceRanges=0.0.0.0/0 AND direction=INGRESS" \
  --format="csv[no-heading](name,network.basename(),allowed[].map().firewall_rule().list(),priority,targetTags.list())" \
  2>/dev/null | \
  while IFS=',' read -r name network allowed priority tags; do
    printf "  [REVIEW] %-25s | Network: %-15s | Allowed: %-20s | Priority: %-5s | Tags: %s\n" \
      "$name" "$network" "$allowed" "$priority" "${tags:-all}"
  done || echo "  [OK] No firewall rules with 0.0.0.0/0 source found"

# ── Section 6: Static IP Usage ─────────────────────────────────────────────
section "SECTION 6 - Static IP Usage"

gcloud compute addresses list \
  --format="csv[no-heading](name,region.basename(),address,status)" \
  2>/dev/null | \
  while IFS=',' read -r name region addr status; do
    warning=""
    [[ "$status" == "RESERVED" ]] && warning=" (billing -- not in use)"
    printf "  %-25s | %-15s | %-15s | %s%s\n" \
      "$name" "${region:-global}" "$addr" "$status" "$warning"
  done || echo "  [INFO] No static addresses found"

# ── Section 7: Snapshot Inventory ──────────────────────────────────────────
section "SECTION 7 - Snapshot Inventory"

snap_count=$(gcloud compute snapshots list --format="value(name)" 2>/dev/null | wc -l || echo "0")
echo "  Total snapshots: $snap_count"

if [[ "$snap_count" -gt 0 ]]; then
    echo ""
    echo "  Recent snapshots (last 10):"
    gcloud compute snapshots list \
      --sort-by=~creationTimestamp \
      --limit=10 \
      --format="csv[no-heading](name,diskSizeGb,status,creationTimestamp)" \
      2>/dev/null | \
      while IFS=',' read -r name size status created; do
        printf "    %-35s | %5s GB | %-8s | %s\n" "$name" "$size" "$status" "$created"
      done || true
fi

echo ""
echo "$SEP"
echo "  GCE Health Check Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
