#!/usr/bin/env bash
# Purpose:        Drill into one application's sync failure - operation state, failing resources, and recent history
# Applies to:     ArgoCD 2.8+ (argocd CLI, logged in)
# Read-only:      yes
# Inputs:         __APP_NAME__ (from 01-app-health.sh)
# Interpretation: operationState message names the failure: ComparisonError = repo/chart unreachable (creds, tag
#                 deleted); hook failures = a PreSync/PostSync job failed (its pod logs have the truth); field-manager
#                 conflicts = something else owns the resource (another controller or a kubectl apply - resolve
#                 ownership, don't force). History shows whether this revision EVER synced - a first-time failure is
#                 the new commit's fault; a previously-green revision failing now is environmental.
# Next step:      Fix the named cause; 'argocd app diff' before any manual sync to see exactly what will change

set -euo pipefail
APP="__APP_NAME__"

echo "== Conditions and operation state"
argocd app get "$APP" -o json |
    python3 -c "
import json, sys
a = json.load(sys.stdin)
for c in a['status'].get('conditions', []):
    print('condition:', c['type'], '-', c.get('message', '')[:150])
op = a['status'].get('operationState', {})
print('phase:', op.get('phase'), '-', op.get('message', '')[:200])
for r in (op.get('syncResult') or {}).get('resources', []):
    if r.get('status') not in ('Synced', None):
        print('resource:', r['kind'] + '/' + r['name'], r.get('status'), '-', r.get('message', '')[:120])
"

echo
echo "== Recent sync history"
argocd app history "$APP" 2>/dev/null | tail -8
