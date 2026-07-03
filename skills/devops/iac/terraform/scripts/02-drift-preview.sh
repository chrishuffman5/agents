#!/usr/bin/env bash
# Purpose:        Detect infrastructure drift - what changed in reality that state does not know about (read-only refresh plan)
# Applies to:     Terraform 1.5+ / OpenTofu (needs backend/provider credentials, read-only cloud permissions suffice)
# Read-only:      yes (-refresh-only plan computes drift without applying; no resources touched, state not written)
# Inputs:         run from the initialized Terraform working directory; add -var-file as your setup requires
# Interpretation: Exit code 2 = drift found - the plan output lists what changed OUTSIDE Terraform (console edits,
#                 autoscaling, another pipeline). Each drifted attribute is a decision: accept reality
#                 (apply the refresh / update code to match) or revert reality (normal apply). Exit 0 = no drift.
#                 Recurring drift on the same resource = something else manages it - add lifecycle ignore_changes or
#                 remove it from this configuration, don't fight a control loop.
# Next step:      Reconcile per attribute with the resource owner; wire this into CI on a schedule for standing drift detection

set -euo pipefail

terraform plan -refresh-only -detailed-exitcode -input=false -lock=false "$@" && rc=0 || rc=$?

case $rc in
    0) echo "RESULT: no drift - state matches reality" ;;
    2) echo "RESULT: DRIFT DETECTED - review the plan above; reconcile before the next normal apply" ;;
    *) echo "RESULT: plan errored (rc=$rc) - fix credentials/config first"; exit $rc ;;
esac
