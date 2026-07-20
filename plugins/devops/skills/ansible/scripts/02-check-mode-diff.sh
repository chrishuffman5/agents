#!/usr/bin/env bash
# Purpose:        Dry-run a playbook with per-change diffs - see exactly what WOULD change before letting it change anything
# Applies to:     Ansible 2.15+ / ansible-core
# Read-only:      yes (--check executes no changes; note below on modules that cannot predict)
# Inputs:         __PLAYBOOK__ and __INVENTORY__ (plus any -e/-l flags you normally pass)
# Interpretation: changed=N per host is the blast-radius number - unexpected changes on hosts you thought were
#                 converged = config drift or a non-idempotent task (command/shell without creates/changed_when is
#                 the classic). The diff blocks show file-level edits line by line. Caveats: command/shell tasks
#                 always show changed in check mode unless guarded, and some modules skip in check mode
#                 (check_mode: false tasks) - absence from this output is not proof of no change for those.
# Next step:      Fix non-idempotent tasks (creates:, changed_when:); run for real only after the diff reads as intended

set -euo pipefail
PLAYBOOK="__PLAYBOOK__"
INV="__INVENTORY__"

ansible-playbook -i "$INV" "$PLAYBOOK" --check --diff "$@" | tee /tmp/ansible-check-$$.log

echo
echo "== Change summary"
grep -E '^(PLAY RECAP|.*: ok=)' /tmp/ansible-check-$$.log | tail -20
rm -f /tmp/ansible-check-$$.log
